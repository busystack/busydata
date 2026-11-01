import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

import capture_reference_gallery as gallery


class ReferenceSourcePolicyTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.root = self.base / 'busydata'
        self.reference = self.base / 'busymark'
        self.sibling = self.base / 'busystack_git'
        self.output = self.root / 'build/gallery'
        files = {
            self.root / 'tool/ui_reference_gallery.dart.template': '// @REFERENCE_TAB_PRESENTATION@\n',
            self.root / 'tool/ui_parity_reference_screens.dart.template': '// capture\n',
            self.root / 'lib/main_linux.dart': '// owned application\n',
            self.root / 'lib/src/ui/common/sql_editor_geometry.dart': '// owned geometry\n',
            self.root / 'lib/src/ui/common/sql_editor_view.dart': '// owned editor view\n',
            self.root / 'lib/src/ui/common/editor_shortcuts.dart': '// owned shortcuts\n',
            self.root / 'test/ui_reference_gallery_test.dart': '// own fixture\n',
            self.root / 'test/ui_parity_screen_gallery_test.dart': '// own screens\n',
            self.root / 'pubspec.lock': '# root lock\n',
            self.reference / 'pubspec.yaml': 'name: busymark\ndependencies:\n  busystack_git:\n    path: ../busystack_git\n',
            self.reference / 'pubspec.lock': '# reference lock\n',
            self.reference / 'test/fixture.txt': 'read-only reference fixture\n',
            self.reference / 'lib/src/workspace/presentation/workspace_screen.dart':
                '\n'.join('class ' + name + ' { int value = 1; }' for name in (
                    '_WorkspaceTabButton', '_DiffCompareIcon', '_DiffCompareIconPainter')),
            self.sibling / 'pubspec.yaml': 'name: busystack_git\n',
            self.sibling / 'lib/busystack_git.dart': '// first-party local package\n',
            self.base / 'font.ttf': 'fixture font bytes',
        }
        for path, content in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        config = self.root / '.dart_tool/package_config.json'
        config.parent.mkdir()
        config.write_text(json.dumps({'packages': [
            {'name': 'yaru', 'rootUri': (self.base / 'yaru').as_uri()},
        ]}))
        self.original = self.hashes(self.reference), self.hashes(self.sibling)

    @staticmethod
    def hashes(root):
        return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in root.rglob('*') if p.is_file()}

    def copied_tracked(self, source, destination):
        result = {}
        for path in source.rglob('*'):
            if path.is_file():
                target = destination / path.relative_to(source)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, target)
                result[str(path.relative_to(source))] = hashlib.sha256(target.read_bytes()).hexdigest()
        return result

    def run_main(self, prepare=False):
        args = ['capture_reference_gallery.py', '--reference', str(self.reference),
                '--output', 'build/gallery']
        if prepare:
            args.append('--prepare-only')
        def read_command(args, cwd):
            return str(self.base / 'font.ttf') if args[0] == 'fc-match' else 'fixture-git-identity'
        with patch.object(gallery, '__file__', str(self.root / 'tool/capture_reference_gallery.py')), \
             patch.object(sys, 'argv', args), \
             patch.object(gallery, 'copy_tracked_tree', side_effect=self.copied_tracked), \
             patch.object(gallery, 'command', side_effect=read_command), \
             patch.object(gallery, 'source_hash', return_value='fixture-source-sha'):
            return gallery.main()

    def test_uncertified_reference_never_reaches_pub_get_or_build_even_with_valid_busydata(self):
        with patch.object(gallery.official_sources, 'revalidate_receipt',
                          return_value={'status': 'passed', 'reportSha256': 'a' * 64}) as proof, \
             patch.object(gallery.subprocess, 'run') as sdk:
            with self.assertRaisesRegex(gallery.ReferenceBuildUnavailable, 'hosted and native'):
                self.run_main()
            proof.assert_called_once_with(self.root)
            sdk.assert_not_called()
        availability = json.loads((self.output / 'gallery-build-availability.json').read_text())
        self.assertEqual('unavailable', availability['status'])
        self.assertFalse(availability['referenceBuildExecuted'])
        self.assertEqual('REFERENCE_DEPENDENCY_VERIFICATION_UNAVAILABLE', availability['code'])
        self.assertEqual('passed', availability['busydataOfficialSources']['status'])
        self.assertTrue((self.output / 'busystack_git/lib/busystack_git.dart').is_file())
        self.assertEqual(self.original, (self.hashes(self.reference), self.hashes(self.sibling)))

    def test_invalid_busydata_proof_is_not_misreported_as_a_reference_only_problem(self):
        with patch.object(gallery.official_sources, 'revalidate_receipt',
                          side_effect=gallery.official_sources.IntegrityError('stale proof')) as proof, \
             patch.object(gallery.subprocess, 'run') as sdk:
            with self.assertRaisesRegex(gallery.official_sources.IntegrityError, 'stale proof'):
                self.run_main()
            proof.assert_called_once_with(self.root)
            sdk.assert_not_called()
        self.assertFalse((self.output / 'gallery-build-availability.json').exists())

    def test_prepare_only_preserves_first_party_snapshots_without_execution_or_certification(self):
        with patch.object(gallery.official_sources, 'revalidate_receipt') as proof, \
             patch.object(gallery.subprocess, 'run') as sdk:
            self.run_main(prepare=True)
            proof.assert_not_called()
            sdk.assert_not_called()
        self.assertTrue((self.output / 'gallery-source-identity.json').is_file())
        self.assertTrue((self.output / 'busystack_git/lib/busystack_git.dart').is_file())
        self.assertFalse((self.output / 'gallery-build-availability.json').exists())
        self.assertEqual(self.original, (self.hashes(self.reference), self.hashes(self.sibling)))

    def test_guard_does_not_offer_a_package_whitelist_or_external_verifier_fallback(self):
        self.output.mkdir(parents=True)
        with patch.object(gallery.official_sources, 'revalidate_receipt',
                          return_value={'status': 'passed'}), \
             patch.object(gallery.subprocess, 'run') as sdk:
            with self.assertRaises(gallery.ReferenceBuildUnavailable):
                gallery.require_build_sources(self.root, self.output)
            sdk.assert_not_called()
class ReferencePreparationTest(unittest.TestCase):
    def test_prepare_only_records_fonts_and_leaves_reference_unchanged(self):
        for relative in (False, True):
            with self.subTest(relative_package_uri=relative), tempfile.TemporaryDirectory() as folder:
                parent = Path(folder)
                root, reference = parent / 'busydata', parent / 'busymark'

                def write(base, name, content):
                    path = base / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(content)
                    return path

                for repo in (root, reference):
                    write(repo, 'pubspec.yaml', 'name: fixture\n')
                    write(repo, 'pubspec.lock', 'locked fixture\n')
                    write(repo, 'lib/main.dart', 'void main() {}\n')
                    write(repo, 'test/existing_test.dart', 'existing test fixture')
                write(reference, 'lib/src/workspace/presentation/workspace_screen.dart',
                      '\n'.join('class ' + name + ' {}' for name in (
                          '_WorkspaceTabButton', '_DiffCompareIcon', '_DiffCompareIconPainter')))
                write(root, 'tool/ui_reference_gallery.dart.template', '// @REFERENCE_TAB_PRESENTATION@')
                write(root, 'tool/ui_parity_reference_screens.dart.template', 'reference screen fixture')
                for name in ('ui_reference_gallery_test.dart', 'ui_parity_screen_gallery_test.dart'):
                    write(root, 'test/' + name, 'capture fixture')
                yaru = root / 'packages/yaru fonts'
                font = write(yaru, 'assets/fonts/Ubuntu-Regular.ttf', 'font bytes')
                bridge = (
                    'lib/src/ui/common/sql_editor_geometry.dart',
                    'lib/src/ui/common/sql_editor_view.dart',
                    'lib/src/ui/common/editor_shortcuts.dart',
                )
                for name in bridge:
                    write(root, name, 'owned bridge fixture: ' + name)
                configuration = root / '.dart_tool/package_config.json'
                write(root, str(configuration.relative_to(root)), json.dumps({'packages': [
                    {'name': 'yaru', 'rootUri': '../packages/yaru%20fonts/' if relative else yaru.as_uri()},
                ]}))
                before = {str(p.relative_to(reference)): p.read_bytes()
                          for p in reference.rglob('*') if p.is_file()}

                def command(arguments, cwd):
                    if arguments[0] == 'fc-match':
                        return str(font)
                    if 'status' in arguments:
                        return ''
                    return 'fixture-source-identity'

                def copy_tree(source, destination):
                    shutil.copytree(source, destination, dirs_exist_ok=True)

                output = root / 'build/comparison'
                with patch.object(gallery, '__file__', str(root / 'tool/capture_reference_gallery.py')), \
                     patch.object(gallery, 'command', side_effect=command), \
                     patch.object(gallery, 'copy_tracked_tree', side_effect=copy_tree), \
                     patch.object(gallery, 'source_hash', return_value='fixture-source-hash'), \
                     patch('sys.argv', ['capture_reference_gallery.py', '--reference', str(reference),
                                        '--output', str(output), '--prepare-only']), \
                     patch.object(gallery.subprocess, 'run') as run, \
                     patch.object(gallery.official_sources, 'revalidate_receipt') as proof:
                    gallery.main()
                run.assert_not_called()
                proof.assert_not_called()
                identity = json.loads((output / 'gallery-source-identity.json').read_text())
                font_record = identity['fonts']['packages/yaru/Ubuntu-Regular.ttf']
                self.assertEqual(font_record['path'], str(font))
                self.assertEqual(font_record['sha256'], hashlib.sha256(font.read_bytes()).hexdigest())
                self.assertEqual(identity['busydata']['buildSourceSha256'], 'fixture-source-hash')
                self.assertEqual(identity['busydata']['editorBridgeSha256'], {
                    name: hashlib.sha256((root / name).read_bytes()).hexdigest()
                    for name in bridge})
                self.assertNotIn('editorDependencySha256', identity['busydata'])
                self.assertEqual(before, {str(p.relative_to(reference)): p.read_bytes()
                                          for p in reference.rglob('*') if p.is_file()})
                self.assertTrue((output / 'reference-checkout/test/ui_reference_gallery_test.dart').is_file())


if __name__ == '__main__':
    unittest.main()
