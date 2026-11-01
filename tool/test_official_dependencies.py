import gzip
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import time
import unittest
from types import SimpleNamespace
from unittest.mock import patch
import verify_official_dependencies as gate
import desktop_build_evidence


class OfficialDependenciesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.package = self.root / 'package'
        self.package.mkdir()
        self.cache = self.root / 'cache'
        self.cache.mkdir()

    def fixture(self, files=None):
        files = files or {'pubspec.yaml': b'name: sample\nversion: 1.0.0\n',
            'lib/sample.dart': b'const answer = 42;\n', 'README.md': b'official description\n',
            'LICENSE': b'official license\n', 'windows/plugin.cpp': b'void register_plugin() {}\n'}
        archive = self.root / 'official.tar.gz'
        with tarfile.open(archive, 'w:gz') as output:
            for name, content in files.items():
                member = tarfile.TarInfo(name)
                member.size = len(content)
                output.addfile(member, io.BytesIO(content))
                target = self.package / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
        return archive

    def test_all_published_members_including_docs_and_native_are_compared(self):
        archive = self.fixture()
        verified = gate.verify_archive(archive, self.package, time.monotonic() + 5)
        self.assertEqual(5, verified['publishedFilesVerified'])
        self.assertEqual(4, verified['runtimeConfigurationLicenseFiles'])
        (self.package / 'README.md').write_text('modified documentation')
        with self.assertRaisesRegex(gate.IntegrityError, 'differs from official'):
            gate.verify_archive(archive, self.package, time.monotonic() + 5)

    def test_modified_native_and_runtime_and_configuration_bytes_are_rejected(self):
        archive = self.fixture()
        for name in ('lib/sample.dart', 'windows/plugin.cpp', 'pubspec.yaml', 'LICENSE'):
            target = self.package / name
            original = target.read_bytes()
            target.write_bytes(original + b'changed')
            with self.subTest(name=name), self.assertRaises(gate.IntegrityError):
                gate.verify_archive(archive, self.package, time.monotonic() + 5)
            target.write_bytes(original)

    def test_injected_runtime_and_other_package_files_are_rejected(self):
        archive = self.fixture()
        for name in ('lib/injected.dart', 'unexpected-note.txt'):
            target = self.package / name
            target.write_text('not from the published package')
            with self.subTest(name=name), self.assertRaisesRegex(gate.IntegrityError, 'injected'):
                gate.verify_archive(archive, self.package, time.monotonic() + 5)
            target.unlink()

    def test_only_explicit_pub_generated_metadata_is_allowed(self):
        archive = self.fixture()
        target = self.package / '.dart_tool/package_config.json'
        target.parent.mkdir()
        target.write_text('{}')
        self.assertEqual(5, gate.verify_archive(archive, self.package,
            time.monotonic() + 5)['publishedFilesVerified'])

    def test_archive_paths_links_and_oversized_members_are_rejected_without_extraction(self):
        for name, kind in (('../outside', 'regular'), ('lib/link', 'link'), ('huge', 'oversized')):
            archive = self.root / ('bad-' + kind + '.tar.gz')
            member = tarfile.TarInfo(name)
            if kind == 'link':
                member.type = tarfile.SYMTYPE
                member.linkname = '../outside'
            if kind == 'oversized':
                member.size = gate.MAX_MEMBER + 1
            with gzip.open(archive, 'wb') as output:
                output.write(member.tobuf())
                output.write(b'\0' * 1024)
            with self.subTest(kind=kind), self.assertRaises(gate.IntegrityError):
                gate.verify_archive(archive, self.package, time.monotonic() + 5)
        self.assertFalse((self.root / 'outside').exists())

    def test_symlinked_resolved_sources_are_rejected(self):
        archive = self.fixture()
        source = self.package / 'lib/sample.dart'
        external = self.root / 'external.dart'
        external.write_bytes(source.read_bytes())
        source.unlink()
        source.symlink_to(external)
        with self.assertRaises(gate.IntegrityError):
            gate.verify_archive(archive, self.package, time.monotonic() + 5)

    def test_corrupt_or_oversized_cached_archives_are_rejected_without_network(self):
        archive = self.fixture()
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        target = self.cache / (digest + '.tar.gz')
        target.write_bytes(b'corrupt')
        entry = {'name': 'sample', 'version': '1.0.0', 'sha256': digest}
        with patch.object(gate.urllib.request, 'urlopen') as network:
            with self.assertRaises(gate.IntegrityError):
                gate.archive_for(entry, self.cache, time.monotonic() + 5)
            network.assert_not_called()
        with target.open('wb') as oversized:
            oversized.truncate(gate.MAX_ARCHIVE + 1)
        with patch.object(gate.urllib.request, 'urlopen') as network:
            with self.assertRaisesRegex(gate.IntegrityError, 'Cached official archive changed'):
                gate.archive_for(entry, self.cache, time.monotonic() + 5)
            network.assert_not_called()

    def test_oversized_resolved_member_is_rejected_before_hashing_its_bytes(self):
        archive = self.fixture()
        target = self.package / 'lib/sample.dart'
        with target.open('wb') as stream:
            stream.truncate(gate.MAX_MEMBER + 1)
        original = gate.sha
        def bounded_hash(path):
            self.assertNotEqual(target, path)
            return original(path)
        with patch.object(gate, 'sha', side_effect=bounded_hash):
            with self.assertRaisesRegex(gate.IntegrityError, 'differs from official'):
                gate.verify_archive(archive, self.package, time.monotonic() + 5)

    def test_official_primary_metadata_must_match_name_version_archive_and_lock_hash(self):
        entry = {'name': 'sample', 'version': '1.0.0', 'sha256': 'a' * 64}
        official = {'version': '1.0.0', 'pubspec': {'name': 'sample'},
            'archive_sha256': 'a' * 64,
            'archive_url': 'https://pub.dev/api/archives/sample-1.0.0.tar.gz'}
        for key, value in (('version', '2.0.0'), ('archive_sha256', 'b' * 64),
                ('archive_url', 'https://example.invalid/custom.tar.gz'),
                ('pubspec', {'name': 'different'})):
            metadata = {**official, key: value}
            with self.subTest(key=key), patch.object(gate.urllib.request, 'urlopen',
                    return_value=io.BytesIO(json.dumps(metadata).encode())):
                with self.assertRaises(gate.IntegrityError):
                    gate.official_metadata(entry, self.cache, time.monotonic() + 5)
        with patch.object(gate.urllib.request, 'urlopen',
                return_value=io.BytesIO(json.dumps(official).encode())):
            proof = gate.official_metadata(entry, self.cache, time.monotonic() + 5)
        self.assertEqual('https://pub.dev/api/packages/sample/versions/1.0.0',
            proof['officialMetadataUrl'])
        self.assertEqual(hashlib.sha256(json.dumps(official).encode()).hexdigest(),
            proof['officialMetadataSha256'])

    def test_lockfile_rejects_path_git_unpinned_and_wrong_registry_sources(self):
        path = self.root / 'pubspec.lock'
        for source in ('path', 'git'):
            path.write_text('# Generated by pub\npackages:\n  sample:\n'
                '    source: ' + source + '\n    version: "1.0.0"\n')
            with self.subTest(source=source), self.assertRaises(gate.IntegrityError):
                gate.parse_lock(path)
        for digest, url in (('missing', 'https://pub.dev'), ('a' * 64, 'https://example.invalid')):
            path.write_text('# Generated by pub\npackages:\n  sample:\n'
                '    description:\n      name: sample\n      sha256: "' + digest + '"\n'
                '      url: "' + url + '"\n    source: hosted\n    version: "1.0.0"\n')
            with self.subTest(digest=digest, url=url), self.assertRaises(gate.IntegrityError):
                gate.parse_lock(path)

    def graph_fixture(self):
        owned_cache = self.root / 'build/official-dependencies/pub-cache'
        self.package = owned_cache / 'hosted/pub.dev/sample-1.0.0'
        self.package.mkdir(parents=True)
        archive = self.fixture()
        digest = hashlib.sha256(archive.read_bytes()).hexdigest()
        cache = self.root / 'build/official-dependencies/archives'
        cache.mkdir(parents=True)
        (cache / (digest + '.tar.gz')).write_bytes(archive.read_bytes())
        (self.root / 'pubspec.lock').write_text('# Generated by pub\npackages:\n'
            '  sample:\n    description:\n      name: sample\n      sha256: "' + digest + '"\n'
            '      url: "https://pub.dev"\n    source: hosted\n    version: "1.0.0"\n'
            '  flutter:\n    description: flutter\n    source: sdk\n    version: "0.0.0"\n')
        self.sdk = self.root / 'flutter-sdk'
        (self.sdk / 'packages/flutter/lib').mkdir(parents=True)
        (self.sdk / 'packages/flutter/lib/flutter.dart').write_text('const official = true;\n')
        environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
        environment.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1')
        def git(*arguments):
            return subprocess.check_output(['git', '-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid', '-C', str(self.sdk), *arguments], env=environment, stderr=subprocess.DEVNULL, timeout=10)
        git('init', '--template=', '--initial-branch=fixture'); git('add', 'packages'); git('commit', '-m', 'Official source fixture')
        identity = {'frameworkRevision': git('rev-parse', 'HEAD').decode().strip(), 'frameworkVersion': '3.47.5', 'dartSdkVersion': '3.13.4'}
        self.sdk_binary = self.sdk / 'bin/cache/dart-sdk/bin/dart'
        self.sdk_binary.parent.mkdir(parents=True); self.sdk_binary.write_bytes(b'Official compiler fixture')
        (self.sdk / 'bin/cache/flutter.version.json').write_text(json.dumps(identity))
        self.sdk_addition = self.sdk / 'bin/cache/artifacts/engine/fixture-release/runtime'
        sdk_spec = {'identity': identity, 'artifacts': {sys.platform: [
            {'directory': 'bin/cache', 'required': True, 'files': {'dart-sdk/bin/dart': gate.sha(self.sdk_binary)}},
            {'directory': 'bin/cache/artifacts/engine/fixture-release', 'files': {'runtime': hashlib.sha256(b'Official optional fixture').hexdigest()}}]}}
        catalog = self.root / 'tool/upstream_packages.json'
        catalog.parent.mkdir(); catalog.write_text(json.dumps({'schema': 1, 'flutter': sdk_spec, 'packages': [
            {'name': 'sample', 'version': '1.0.0', 'archive_url': 'https://pub.dev/api/archives/sample-1.0.0.tar.gz', 'archive_sha256': digest,
             'files': {p.relative_to(self.package).as_posix(): gate.sha(p) for p in self.package.rglob('*') if p.is_file()}}]}))
        configuration = self.root / '.dart_tool/package_config.json'
        configuration.parent.mkdir()
        configuration.write_text(json.dumps({'generatorVersion': '3.13.4',
            'flutterVersion': '3.47.5', 'pubCache': owned_cache.as_uri(), 'flutterRoot': self.sdk.as_uri(), 'packages': [
                {'name': 'busydata', 'rootUri': '../', 'packageUri': 'lib/'},
                {'name': 'sample', 'rootUri': self.package.as_uri(), 'packageUri': 'lib/'},
                {'name': 'flutter', 'rootUri': (self.sdk / 'packages/flutter').as_uri(), 'packageUri': 'lib/'}]}))
        toolchain = self.root / 'config/toolchain.json'
        toolchain.parent.mkdir()
        toolchain.write_text(json.dumps({'flutter': '3.47.5', 'dart': '3.13.4'}))
        metadata = {'version': '1.0.0', 'pubspec': {'name': 'sample'},
            'archive_sha256': digest, 'archive_url': 'https://pub.dev/api/archives/sample-1.0.0.tar.gz'}
        with patch.object(gate.urllib.request, 'urlopen', return_value=io.BytesIO(json.dumps(metadata).encode())):
            report = gate.verify(self.root, cache, time.monotonic() + 5)
        target = cache.parent / 'verification.json'
        target.write_text(json.dumps(report))
        return target, report

    def test_packaged_inventory_revalidates_exact_official_receipt_and_current_bytes(self):
        self.graph_fixture()
        result = gate.revalidate_receipt(self.root)
        self.assertEqual('passed', result['status'])
        self.assertEqual(5, result['revalidatedPublishedFiles'])
        (self.package / 'lib/sample.dart').write_text('mutated runtime')
        with self.assertRaisesRegex(gate.IntegrityError, 'Upstream package source modified: sample/lib/sample.dart'):
            gate.revalidate_receipt(self.root)

    def test_complete_receipt_requires_actual_sdk_bytes_not_version_labels(self):
        self.graph_fixture()
        self.sdk_binary.write_bytes(b'Modified runtime, unchanged version file')
        with self.assertRaisesRegex(gate.IntegrityError, 'compiler/runtime'):
            gate.revalidate_receipt(self.root)

    def test_sdk_framework_and_reviewed_catalog_are_bound_to_the_full_graph(self):
        self.graph_fixture()
        source = self.sdk / 'packages/flutter/lib/flutter.dart'
        original = source.read_bytes(); source.write_text('const modified = true;\n')
        with self.assertRaisesRegex(gate.IntegrityError, 'source modifications'):
            gate.revalidate_receipt(self.root)
        source.write_bytes(original)
        catalog = self.root / 'tool/upstream_packages.json'
        catalog.write_text(catalog.read_text() + '\n')
        with self.assertRaisesRegex(gate.IntegrityError, 'attestation receipt.*stale'):
            gate.revalidate_receipt(self.root)

    def test_old_hosted_only_receipt_cannot_omit_required_sdk_attestation(self):
        target, report = self.graph_fixture()
        del report['publisherAttestation']; target.write_text(json.dumps(report))
        with self.assertRaisesRegex(gate.IntegrityError, 'attestation receipt.*stale'):
            gate.revalidate_receipt(self.root)

    def test_new_precached_official_mode_is_attested_without_substituting_old_inputs(self):
        self.graph_fixture()
        self.sdk_addition.parent.mkdir(parents=True); self.sdk_addition.write_bytes(b'Official optional fixture')
        result = gate.revalidate_receipt(self.root)
        self.assertEqual(2, result['publisherAttestation']['sdk']['verifiedArtifactFiles'])
        self.sdk_binary.unlink()
        with self.assertRaisesRegex(gate.IntegrityError, 'compiler/runtime'):
            gate.revalidate_receipt(self.root)

    def test_packaged_inventory_rejects_stale_and_forged_archive_provenance(self):
        target, report = self.graph_fixture()
        report['packages'][0]['sha256'] = 'b' * 64
        target.write_text(json.dumps(report))
        with self.assertRaisesRegex(gate.IntegrityError, 'archive identity'):
            gate.revalidate_receipt(self.root)
        (self.root / 'pubspec.lock').write_text('stale lock')
        with self.assertRaisesRegex(gate.IntegrityError, 'stale'):
            gate.revalidate_receipt(self.root)

    def test_internal_official_package_name_is_not_silently_dropped(self):
        path = self.root / 'pubspec.lock'
        path.write_text('# Generated by pub\npackages:\n  _sample:\n'
            '    description:\n      name: _sample\n      sha256: "' + 'a' * 64 + '"\n'
            '      url: "https://pub.dev"\n    source: hosted\n    version: "1.0.0"\n')
        self.assertEqual({'_sample'}, set(gate.parse_lock(path)))

    def test_owned_build_environment_preserves_the_caller_and_rejects_linked_temp(self):
        with patch.dict(gate.os.environ, {'PUB_CACHE': 'caller-cache', 'TMPDIR': 'caller-temp'}):
            environment = gate.owned_build_environment(self.root)
            self.assertEqual('caller-cache', gate.os.environ['PUB_CACHE'])
            self.assertEqual('caller-temp', gate.os.environ['TMPDIR'])
            self.assertEqual(str(self.root / 'build/t'), environment['TMPDIR'])
        temporary = self.root / 'build/t'
        temporary.rmdir()
        temporary.symlink_to(self.package, target_is_directory=True)
        with self.assertRaisesRegex(gate.IntegrityError, 'not owned'):
            gate.owned_build_environment(self.root)

    def test_release_build_cannot_start_without_the_actual_official_dependency_proof(self):
        with patch.object(desktop_build_evidence, 'ROOT', self.root), \
             patch.object(desktop_build_evidence, 'verify_bundle', return_value='backend'), \
             patch.object(desktop_build_evidence.subprocess, 'run') as run:
            with self.assertRaises(gate.IntegrityError):
                desktop_build_evidence.build('windows')
            run.assert_not_called()

    def test_release_build_rejects_dependency_changes_before_certifying_its_output(self):
        with patch.object(desktop_build_evidence, 'ROOT', self.root), \
             patch.object(desktop_build_evidence, 'verify_bundle', return_value='backend'), \
             patch.object(desktop_build_evidence, 'source_hash', return_value='source'), \
             patch.object(desktop_build_evidence, 'revalidate_receipt', side_effect=[{'reportSha256': 'before'}, {'reportSha256': 'changed'}]), \
             patch.object(desktop_build_evidence.subprocess, 'run', return_value=SimpleNamespace(returncode=0)) as run:
            with self.assertRaisesRegex(RuntimeError, 'dependency proof changed'):
                desktop_build_evidence.build('windows')
            self.assertEqual(str(self.root / 'build/official-dependencies/pub-cache'), run.call_args.kwargs['env']['PUB_CACHE'])
            self.assertFalse((self.root / 'build/windows-release-build.json').exists())

    def test_each_invocation_preserves_its_failure_before_a_later_success(self):
        _, passed = self.graph_fixture()
        with patch('sys.argv', ['verify_official_dependencies.py', '--root', str(self.root)]), \
             patch.object(gate, 'verify', side_effect=[gate.IntegrityError('injected package bytes'), passed]):
            self.assertEqual(1, gate.main())
            first = json.loads((self.root / 'build/official-dependencies/verification.json').read_text())
            self.assertEqual(0, gate.main())
        records = [json.loads(path.read_text()) for path in
            (self.root / 'build/official-dependencies/runs').glob('*.json')]
        self.assertEqual(2, len(records))
        failed = next(record for record in records if record['status'] == 'failed')
        self.assertEqual(first, failed)
        self.assertEqual('injected package bytes', failed['detail'])
        self.assertEqual(2, len({record['invocationId'] for record in records}))

    def test_missing_source_and_expired_deadline_never_pass(self):
        archive = self.fixture()
        (self.package / 'LICENSE').unlink()
        with self.assertRaises(gate.IntegrityError):
            gate.verify_archive(archive, self.package, time.monotonic() + 5)
        with self.assertRaisesRegex(gate.IntegrityError, 'timed out'):
            gate.verify_archive(archive, self.package, time.monotonic() - 1)


if __name__ == '__main__':
    unittest.main()
