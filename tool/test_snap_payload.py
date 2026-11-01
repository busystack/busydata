from pathlib import Path
import stat
import shutil
import tempfile
import unittest
from verify_snap_payload import verify
from public_bundle_permissions import publish_public_bundle


class SnapPayloadTest(unittest.TestCase):
    def test_recipe_checks_project_source_and_ci_cleans_the_replaced_bundle(self):
        root = Path(__file__).resolve().parents[1]
        recipe = (root / 'snap/snapcraft.yaml').read_text()
        self.assertIn('--source "$CRAFT_PROJECT_DIR/build/linux/x64/release/bundle"', recipe)
        self.assertIn('--prime "$CRAFT_PRIME"', recipe)
        application_part = recipe.split('  native-postgresql-client:', 1)[0]
        self.assertNotIn('--source "$CRAFT_PART_SRC"', application_part)
        marker_reset = application_part.index('rm -f "$CRAFT_PRIME/installed-acceptance-build.json"')
        copying = application_part.index('craftctl default')
        checking = application_part.index('tool/verify_snap_payload.py')
        self.assertLess(marker_reset, copying)
        self.assertLess(copying, checking)
        workflow = (root / '.github/workflows/verify.yml').read_text()
        facilities = workflow.split('Prepare real disposable fixtures and native portal facilities', 1)[1]
        self.assertIn('python3-gi gir1.2-atspi-2.0', facilities.split('Execute confined native', 1)[0])
        replacing = workflow.index('tar -C build/linux/x64/release -xzf build/busydata-installed-acceptance.tar.gz')
        cleaning = workflow.index('SNAPCRAFT_BUILD_ENVIRONMENT=lxd snapcraft clean busydata')
        building = workflow.index('id: acceptance-snap')
        self.assertLess(replacing, cleaning)
        self.assertLess(cleaning, building)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source, self.prime = self.root / 'source', self.root / 'prime'
        for name in ['busydata', 'lib/libapp.so', 'backend/runtime/bin/java',
                     'backend/dependency-inventory.json', 'backend/build-info.json',
                     'backend/lib/application.jar']:
            path = self.source / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
        (self.source / 'busydata').chmod(0o755)
        (self.source / 'backend/runtime/bin/java').chmod(0o755)
        publish_public_bundle(self.source)
        shutil.copytree(self.source, self.prime)

    def tearDown(self):
        self.temporary.cleanup()

    def test_matching_product_and_private_acceptance_payloads(self):
        self.assertFalse(verify(self.source, self.prime)['privateAcceptanceEntrypoint'])
        for root in [self.source, self.prime]:
            manifest = root / 'installed-acceptance-build.json'
            manifest.write_text('{"fixture":"current"}')
            manifest.chmod(0o644)
        self.assertTrue(verify(self.source, self.prime)['privateAcceptanceEntrypoint'])

    def test_changed_bytes_even_with_preserved_size_and_timestamp(self):
        path = self.prime / 'lib/libapp.so'
        path.write_bytes(b'x' * path.stat().st_size)
        with self.assertRaisesRegex(ValueError, 'differs from current source'):
            verify(self.source, self.prime)

    def test_product_cannot_retain_a_previous_private_launcher_manifest(self):
        (self.prime / 'installed-acceptance-build.json').write_text('{"fixture":"old"}')
        with self.assertRaisesRegex(ValueError, 'Stale or missing private'):
            verify(self.source, self.prime)

    def test_older_jars_and_execute_permission_changes_are_rejected(self):
        jar = self.prime / 'backend/lib/old-driver.jar'
        jar.write_bytes(b'old')
        with self.assertRaisesRegex(ValueError, 'JAR catalog differs'):
            verify(self.source, self.prime)
        jar.unlink()
        (self.prime / 'busydata').chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'executable permissions differ'):
            verify(self.source, self.prime)

    def test_matching_unusable_runtime_executable_modes_are_rejected_without_repair(self):
        for name in ('busydata', 'backend/runtime/bin/java'):
            for mode in (0o744, 0o644):
                with self.subTest(name=name, mode=oct(mode)):
                    paths = [root / name for root in (self.source, self.prime)]
                    originals = [(path.stat().st_mode, path.read_bytes()) for path in paths]
                    for path in paths:
                        path.chmod(mode)
                    try:
                        with self.assertRaisesRegex(ValueError, 'Required runtime executable'):
                            verify(self.source, self.prime)
                        for path, (_, value) in zip(paths, originals):
                            self.assertEqual(mode, stat.S_IMODE(path.stat().st_mode))
                            self.assertEqual(value, path.read_bytes())
                    finally:
                        for path, (original, _) in zip(paths, originals):
                            path.chmod(stat.S_IMODE(original))

    def test_private_required_ancestors_or_files_fail_without_repairing_payload(self):
        for root in (self.source, self.prime):
            for name in ('.', 'lib', 'backend/lib', 'backend/runtime/bin',
                         'backend/build-info.json'):
                with self.subTest(root=root.name, name=name):
                    path = root / name
                    mode = stat.S_IMODE(path.stat().st_mode)
                    private = 0o700 if path.is_dir() else 0o600
                    path.chmod(private)
                    try:
                        with self.assertRaisesRegex(ValueError, 'permissions differ'):
                            verify(self.source, self.prime)
                        self.assertEqual(private, stat.S_IMODE(path.stat().st_mode))
                    finally:
                        path.chmod(mode)

    def test_indirect_required_files_are_rejected(self):
        path = self.prime / 'backend/build-info.json'
        path.unlink()
        path.symlink_to(self.source / 'backend/build-info.json')
        with self.assertRaisesRegex(ValueError, 'indirect required'):
            verify(self.source, self.prime)
