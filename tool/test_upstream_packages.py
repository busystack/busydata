import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from verify_upstream_packages import verify, verify_sdk


class UpstreamPackagesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.package = self.root / 'official'
        (self.package / 'lib').mkdir(parents=True)
        (self.package / 'pubspec.yaml').write_text('name: selected\nversion: 1.0.0\n')
        (self.package / 'lib/client.dart').write_text('const upstream = true;\n')
        self.configuration = self.root / 'package_config.json'
        self.configuration.write_text(json.dumps({'packages': [{'name': 'selected', 'rootUri': self.package.as_uri()}]}))
        self.manifest = self.root / 'upstream.json'
        self.record = {'name': 'selected', 'version': '1.0.0', 'archive_url': 'https://pub.dev/api/archives/selected-1.0.0.tar.gz', 'archive_sha256': 'a' * 64,
                       'files': {p.relative_to(self.package).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in self.package.rglob('*') if p.is_file()}}
        self.write_manifest()

    def write_manifest(self):
        self.manifest.write_text(json.dumps({'schema': 1, 'packages': [self.record]}))

    def check(self):
        return verify(self.configuration, self.manifest)

    def test_unchanged_publisher_source_and_encoded_paths(self):
        moved = self.root / 'Unicode 漢 package'
        self.package.rename(moved)
        self.configuration.write_text(json.dumps({'packages': [{'name': 'selected', 'rootUri': moved.as_uri()}]}))
        self.assertEqual('selected', self.check()[0]['name'])

    def test_same_version_modified_source_is_rejected(self):
        (self.package / 'lib/client.dart').write_text('const downstream = true;\n')
        with self.assertRaisesRegex(ValueError, 'source modified'): self.check()

    def test_added_source_is_rejected(self):
        (self.package / 'lib/downstream.dart').write_text('unapproved')
        with self.assertRaisesRegex(ValueError, 'source added'): self.check()

    def test_missing_source_is_rejected(self):
        (self.package / 'lib/client.dart').unlink()
        with self.assertRaisesRegex(ValueError, 'missing or substituted'): self.check()

    def test_symlink_escape_is_rejected(self):
        source = self.package / 'lib/client.dart'
        outside = self.root / 'outside.dart'; outside.write_bytes(source.read_bytes()); source.unlink()
        try: source.symlink_to(outside)
        except OSError as failure: self.fail('Native symlink fixture unavailable: ' + str(failure))
        with self.assertRaisesRegex(ValueError, 'substituted'): self.check()

    def test_manifest_path_escape_is_rejected(self):
        self.record['files']['../outside'] = 'a' * 64; self.write_manifest()
        with self.assertRaisesRegex(ValueError, 'escapes'): self.check()

    def test_required_and_retired_dependencies_are_distinct(self):
        self.configuration.write_text('{"packages": []}')
        with self.assertRaisesRegex(ValueError, 'unresolved'): self.check()
        self.record['optional'] = True; self.write_manifest(); self.assertEqual([], self.check())

    def test_generated_output_does_not_exempt_nested_source_directories(self):
        (self.package / 'build').mkdir(); (self.package / 'build/generated').write_text('tool output')
        self.check()
        (self.package / 'lib/build').mkdir(); (self.package / 'lib/build/downstream.dart').write_text('unapproved')
        with self.assertRaisesRegex(ValueError, 'source added'): self.check()

    def test_reviewed_catalog_cannot_downgrade_or_replace_locked_package_identity(self):
        locked = {'selected': {'source': 'hosted', 'version': '1.0.0', 'sha256': 'a' * 64}}
        self.assertEqual('selected', verify(self.configuration, self.manifest, locked)[0]['name'])
        for key, value in (('source', 'git'), ('version', '2.0.0'), ('sha256', 'b' * 64)):
            altered = {'selected': {**locked['selected'], key: value}}
            with self.subTest(key=key), self.assertRaisesRegex(ValueError, 'differs from.*lockfile'):
                verify(self.configuration, self.manifest, altered)


class OfficialSdkTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        self.environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        def git(*args):
            return subprocess.check_output(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-C', str(self.root), *args], env=self.environment, stderr=subprocess.DEVNULL, timeout=10)
        self.git = git
        git('init', '--template=', '--initial-branch=fixture')
        (self.root / 'framework.dart').write_bytes(b'const official = true;\n')
        git('add', 'framework.dart'); git('commit', '-m', 'Official source fixture')
        revision = git('rev-parse', 'HEAD').decode().strip()
        self.identity = {'frameworkRevision': revision, 'frameworkVersion': '3.47.5', 'dartSdkVersion': '3.13.4'}
        cache = self.root / 'bin/cache'; cache.mkdir(parents=True)
        (cache / 'flutter.version.json').write_text(json.dumps(self.identity))
        self.binary = cache / 'dart-sdk/bin/dart'; self.binary.parent.mkdir(parents=True); self.binary.write_bytes(b'Official compiler fixture')
        artifact = {'directory': 'bin/cache', 'required': True, 'files': {'dart-sdk/bin/dart': hashlib.sha256(self.binary.read_bytes()).hexdigest()}}
        self.spec = {'identity': self.identity, 'artifacts': {'fixture-host': [artifact]}}

    def check(self):
        return verify_sdk(self.root, self.spec, 'fixture-host')

    def pin_archive_source(self, records):
        raw = json.dumps(records, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        self.spec['sourceTrees'] = {'fixture-host': {
            'files': len(records), 'sha256': hashlib.sha256(raw).hexdigest()}}

    def source_record(self, name, mode='100644'):
        content = (self.root / name).read_bytes()
        return [name, mode, len(content), hashlib.sha256(content).hexdigest()]

    def test_publisher_crlf_source_requires_its_exact_archive_digest(self):
        source = self.root / 'framework.dart'
        source.write_bytes(b'const official = true;\r\n')
        self.pin_archive_source([self.source_record('framework.dart')])
        self.assertEqual(1, self.check())
        # Canonical Git equality alone must not authorize a different raw SDK.
        source.write_bytes(b'const official = true;\n')
        with self.assertRaisesRegex(ValueError, 'official source archive bytes'):
            self.check()

    def test_raw_archive_digest_cannot_authorize_changed_upstream_source(self):
        (self.root / 'framework.dart').write_bytes(b'const downstream = true;\r\n')
        self.pin_archive_source([self.source_record('framework.dart')])
        with self.assertRaisesRegex(ValueError, 'source modifications'):
            self.check()

    def test_publisher_file_representation_of_git_link_stays_bound_to_target(self):
        target = b'framework.dart'
        (self.root / 'source-link').write_bytes(target)
        blob = subprocess.check_output(['git', '-C', str(self.root), 'hash-object', '-w', '--stdin'],
                                       input=target, env=self.environment).decode().strip()
        self.git('update-index', '--add', '--cacheinfo', '120000,' + blob + ',source-link')
        self.git('commit', '-m', 'Official archive link fixture')
        self.identity['frameworkRevision'] = self.git('rev-parse', 'HEAD').decode().strip()
        (self.root / 'bin/cache/flutter.version.json').write_text(json.dumps(self.identity))
        with self.assertRaisesRegex(ValueError, 'source link was replaced'):
            self.check()
        self.pin_archive_source([self.source_record('framework.dart'),
                                 self.source_record('source-link', '120000')])
        self.assertEqual(1, self.check())
        (self.root / 'source-link').write_bytes(b'elsewhere.dart')
        with self.assertRaisesRegex(ValueError, 'source modifications'):
            self.check()

    def test_archive_profile_preserves_tracked_binary_crlf_bytes(self):
        (self.root / 'binary.bin').write_bytes(b'\x00publisher binary\r\n')
        self.git('add', 'binary.bin'); self.git('commit', '-m', 'Official binary fixture')
        self.identity['frameworkRevision'] = self.git('rev-parse', 'HEAD').decode().strip()
        (self.root / 'bin/cache/flutter.version.json').write_text(json.dumps(self.identity))
        self.pin_archive_source([self.source_record('binary.bin'), self.source_record('framework.dart')])
        self.assertEqual(1, self.check())
        (self.root / 'binary.bin').write_bytes(b'\x00publisher binary\n')
        with self.assertRaisesRegex(ValueError, 'source modifications'):
            self.check()

    def test_archive_file_count_and_digest_cannot_be_missing_or_relabelled(self):
        self.pin_archive_source([self.source_record('framework.dart')])
        for change in ({'files': 2}, {'sha256': '0' * 64}, {'sha256': ''}, {'files': True}):
            original = dict(self.spec['sourceTrees']['fixture-host'])
            self.spec['sourceTrees']['fixture-host'].update(change)
            with self.subTest(change=change), self.assertRaisesRegex(ValueError, 'source archive'):
                self.check()
            self.spec['sourceTrees']['fixture-host'] = original

    def test_windows_requires_the_reviewed_publisher_source_archive(self):
        self.spec['artifacts']['win32'] = self.spec['artifacts']['fixture-host']
        with self.assertRaisesRegex(ValueError, 'No reviewed official Windows SDK source archive'):
            verify_sdk(self.root, self.spec, 'win32')

    def test_official_source_and_binary_are_required_together(self):
        self.assertEqual(1, self.check())
        self.binary.write_bytes(b'Modified compiler with unchanged version')
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'): self.check()

    def test_modified_framework_is_rejected_with_unchanged_version_file(self):
        (self.root / 'framework.dart').write_text('const downstream = true;\n')
        with self.assertRaisesRegex(ValueError, 'source modifications'): self.check()

    def test_changed_version_cannot_relabel_the_runtime(self):
        (self.root / 'bin/cache/flutter.version.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'identity'): self.check()

    def test_missing_required_compiler_is_rejected(self):
        self.binary.unlink()
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'): self.check()

    def test_only_cataloged_publisher_overlay_variants_are_accepted(self):
        files = self.spec['artifacts']['fixture-host'][0]['files']
        original = files['dart-sdk/bin/dart']
        overlay = b'Another official publisher artifact fixture'
        files['dart-sdk/bin/dart'] = [original, hashlib.sha256(overlay).hexdigest()]
        self.binary.write_bytes(overlay); self.assertEqual(1, self.check())
        self.binary.write_bytes(b'Unreviewed downstream artifact')
        with self.assertRaisesRegex(ValueError, 'compiler/runtime'): self.check()

    def test_inherited_git_redirection_cannot_substitute_another_index(self):
        previous = os.environ.get('GIT_INDEX_FILE')
        try:
            os.environ['GIT_INDEX_FILE'] = str(self.root / 'unapproved-index')
            self.assertEqual(1, self.check())
        finally:
            if previous is None: os.environ.pop('GIT_INDEX_FILE', None)
            else: os.environ['GIT_INDEX_FILE'] = previous

    def test_replacement_ref_cannot_substitute_modified_source_behind_pinned_head(self):
        original = self.identity['frameworkRevision']
        (self.root / 'framework.dart').write_text('const downstream = true;\n')
        self.git('add', 'framework.dart'); self.git('commit', '-m', 'Synthetic substituted source')
        substituted = self.git('rev-parse', 'HEAD').decode().strip()
        self.git('update-ref', 'refs/heads/fixture', original)
        self.git('replace', original, substituted)
        self.assertEqual(original, self.git('rev-parse', 'HEAD').decode().strip())
        with self.assertRaisesRegex(ValueError, 'source modifications'):
            self.check()


if __name__ == '__main__': unittest.main()
