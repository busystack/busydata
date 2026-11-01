import copy
import json
import stat
from pathlib import Path
import tempfile
import unittest
import zipfile
from unittest.mock import patch

from verification_evidence import source_hash
from canonical_source import (source_manifest, intentional_mode, manifest_hash,
                              write_archive, verify_archive, normalized_path,
                              json_bytes, load_manifest)


class SourceIdentityRegressionTest(unittest.TestCase):
    def test_zip_extraction_modes_do_not_change_source_identity(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work) / 'source'
            (root / 'tool').mkdir(parents=True)
            script = root / 'tool/build.sh'
            script.write_text('#!/bin/sh\nexit 0\n')
            script.chmod(0o755)
            expected = source_hash(root)
            archive = Path(work) / 'source.zip'
            with zipfile.ZipFile(archive, 'w') as output:
                output.write(script, 'tool/build.sh')
            extracted = Path(work) / 'extracted'
            with zipfile.ZipFile(archive) as source:
                source.extractall(extracted)
            (extracted / 'tool/build.sh').chmod(0o600)
            self.assertEqual(expected, source_hash(extracted))

    def test_distributed_documentation_is_part_of_frozen_identity(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            (root / 'docs').mkdir()
            file = root / 'docs/security.md'
            file.write_text('verified policy')
            expected = source_hash(root)
            file.write_text('unverified changed policy')
            self.assertNotEqual(expected, source_hash(root))

    def test_historical_documentation_output_is_excluded_without_excluding_tests_or_docs(self):
        with tempfile.TemporaryDirectory() as work:
            root = Path(work)
            (root / 'docs').mkdir()
            (root / 'docs/security.md').write_text('durable product policy')
            (root / 'test/acceptance').mkdir(parents=True)
            (root / 'test/acceptance/fixture.sql').write_text('independent test fixture')
            expected = source_hash(root)
            (root / 'docs/acceptance').mkdir()
            (root / 'docs/acceptance/captured.log').write_text('generated output')
            self.assertEqual(expected, source_hash(root))
            names = {entry['path'] for entry in source_manifest(root)['files']}
            self.assertEqual({'docs/security.md', 'test/acceptance/fixture.sql'}, names)


class SourceArtifactTest(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.root = Path(self.work.name) / 'source'
        (self.root / 'lib').mkdir(parents=True)
        (self.root / 'tool').mkdir()
        (self.root / 'lib/漢😀.dart').write_text('Unicode source 😀', encoding='utf-8')
        (self.root / 'tool/build.sh').write_text('#!/bin/sh\nexit 0\n')
        self.manifest = source_manifest(self.root)
        self.archive = Path(self.work.name) / 'source.zip'

    def tearDown(self):
        self.work.cleanup()

    def zip(self, entries):
        with zipfile.ZipFile(self.archive, 'w') as output:
            for name, value in entries:
                output.writestr(name, value)

    def contents(self):
        return [(entry['path'], (self.root / entry['path']).read_bytes())
                for entry in self.manifest['files']]

    def test_executable_semantics_are_canonical_not_archive_modes(self):
        self.assertEqual('0755', intentional_mode('backend/mvnw'))
        self.assertEqual('0755', intentional_mode('tool/build.sh'))
        self.assertEqual('0644', intentional_mode('tool/test_fixture.py'))
        write_archive(self.root, self.archive, self.manifest)
        with zipfile.ZipFile(self.archive) as archive:
            self.assertEqual(0o755, (archive.getinfo('tool/build.sh').external_attr >> 16) & 0o777)
        self.archive.unlink()
        # Windows ZIP extraction routinely discards POSIX mode metadata.
        self.zip(self.contents())
        self.assertTrue(verify_archive(self.archive, self.manifest)['extractedAndVerified'])

    def test_manifest_and_archive_are_reproducible_across_modes_and_mtimes(self):
        write_archive(self.root, self.archive, self.manifest)
        original = self.archive.read_bytes()
        script = self.root / 'tool/build.sh'
        script.chmod(0o700)
        self.archive.unlink()
        self.assertEqual(self.manifest, source_manifest(self.root))
        write_archive(self.root, self.archive, self.manifest)
        self.assertEqual(original, self.archive.read_bytes())

    def test_mutation_addition_and_removal_change_identity_without_git(self):
        original = manifest_hash(self.manifest)
        file = self.root / 'lib/extra.dart'
        file.write_text('added')
        added = source_hash(self.root)
        self.assertNotEqual(original, added)
        file.write_text('changed')
        self.assertNotEqual(added, source_hash(self.root))
        file.unlink()
        self.assertEqual(original, source_hash(self.root))
        (self.root / 'lib/漢😀.dart').unlink()
        self.assertNotEqual(original, source_hash(self.root))

    def test_incidental_files_are_excluded_but_portable_ide_settings_are_included(self):
        for name in ('tool/__pycache__/cache.pyc', 'backend/target/classes/a',
                     'backend/.mvn/cache/download', '.idea/libraries/SDK.xml',
                     '.idea/busydata.iml', 'build/verification/result.json'):
            file = self.root / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('machine-local generated state')
        self.assertEqual(self.manifest, source_manifest(self.root))
        file = self.root / '.idea/vcs.xml'
        file.write_text('portable setting')
        self.assertNotEqual(self.manifest, source_manifest(self.root))

    def test_normalized_paths_reject_posix_and_windows_traversal(self):
        for name in ('../secret', '/absolute', 'lib/../secret', 'lib//x', './lib/x',
                     'C:/secret', 'lib\\x', 'lib/x/', 'lib/./x'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                normalized_path(name)
        self.assertEqual('lib/漢😀.dart', normalized_path('lib/漢😀.dart'))

    def test_symlink_files_and_ancestors_are_rejected(self):
        link = self.root / 'lib/link.dart'
        link.symlink_to(self.root / 'tool/build.sh')
        with self.assertRaisesRegex(ValueError, 'symbolic'):
            source_manifest(self.root)
        link.unlink()
        (self.root / 'lib/linked').symlink_to(self.root / 'tool', target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symbolic'):
            source_manifest(self.root)

    def test_windows_case_collisions_are_rejected(self):
        (self.root / 'lib/Case.dart').write_text('upper')
        (self.root / 'lib/case.dart').write_text('lower')
        with self.assertRaisesRegex(ValueError, 'case folding'):
            source_manifest(self.root)

    def test_archive_missing_added_or_changed_files_is_rejected(self):
        entries = self.contents()
        for altered in (entries[:-1], [*entries, ('lib/added.dart', 'new')],
                        [(entries[0][0], 'changed'), *entries[1:]]):
            with self.subTest(entries=len(altered)):
                self.zip(altered)
                with self.assertRaises(ValueError):
                    verify_archive(self.archive, self.manifest)

    def test_archive_symlink_and_traversal_are_never_extracted(self):
        for name, kind in (('../outside', stat.S_IFREG), ('lib/link', stat.S_IFLNK)):
            with zipfile.ZipFile(self.archive, 'w') as output:
                info = zipfile.ZipInfo(name)
                info.external_attr = (kind | 0o777) << 16
                output.writestr(info, 'target')
            with self.assertRaises(ValueError):
                verify_archive(self.archive, self.manifest)
            self.assertFalse((Path(self.work.name) / 'outside').exists())

    def test_supplied_manifest_cannot_override_content_or_executable_policy(self):
        self.zip(self.contents())
        altered = copy.deepcopy(self.manifest)
        altered['files'][0]['sha256'] = '0' * 64
        with self.assertRaisesRegex(ValueError, 'reproduce'):
            verify_archive(self.archive, altered)
        altered = copy.deepcopy(self.manifest)
        altered['files'][-1]['mode'] = '0644'
        with self.assertRaisesRegex(ValueError, 'reproduce'):
            verify_archive(self.archive, altered)

    def test_manifest_encoding_is_canonical(self):
        path = Path(self.work.name) / 'manifest.json'
        path.write_bytes(json_bytes(self.manifest))
        self.assertEqual(self.manifest, load_manifest(path))
        path.write_text(json.dumps(self.manifest, indent=2))
        with self.assertRaisesRegex(ValueError, 'canonical JSON'):
            load_manifest(path)

    def test_snapshot_cannot_package_content_changed_after_freezing(self):
        (self.root / 'lib/漢😀.dart').write_text('changed after review')
        with self.assertRaisesRegex(ValueError, 'Source changed'):
            write_archive(self.root, self.archive, self.manifest)
        self.assertFalse(self.archive.exists())
        self.assertFalse(self.archive.with_suffix('.partial').exists())

    def test_existing_artifact_and_abandoned_partial_are_preserved(self):
        self.archive.write_bytes(b'previous artifact')
        with self.assertRaises(FileExistsError):
            write_archive(self.root, self.archive, self.manifest)
        self.assertEqual(b'previous artifact', self.archive.read_bytes())
        partial = self.archive.with_suffix('.partial')
        partial.write_bytes(b'abandoned output from another owner')
        with self.assertRaises(FileExistsError):
            write_archive(self.root, self.archive, self.manifest)
        self.assertEqual(b'abandoned output from another owner', partial.read_bytes())

    def test_unsupported_no_clobber_primitive_never_falls_back_to_replacement(self):
        self.archive.write_bytes(b'original destination')
        with patch('canonical_source.os.link', side_effect=OSError('Unsupported filesystem')):
            with self.assertRaisesRegex(OSError, 'Unsupported filesystem'):
                write_archive(self.root, self.archive, self.manifest)
        self.assertEqual(b'original destination', self.archive.read_bytes())
        self.assertFalse(self.archive.with_suffix('.partial').exists())


if __name__ == '__main__':
    unittest.main()
