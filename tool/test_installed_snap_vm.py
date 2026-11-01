import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch, Mock

from canonical_source import source_manifest
from verification_evidence import start, digest
from public_bundle_permissions import publish_public_bundle
from verify_installed_snap_vm import (VmAcceptance, VM_PREPARATION, VM_PRODUCT_PROBE,
                                      VM, request_x11_window_close)


class InstalledSnapVmTest(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.root = Path(self.work.name)
        (self.root / 'lib').mkdir()
        (self.root / 'lib/main.dart').write_text('frozen fixture source')
        with patch('verification_evidence.command_output', return_value={'exitCode': 0}):
            start(self.root)

    def tearDown(self):
        self.work.cleanup()

    def test_only_owned_vm_and_active_frozen_snapshot_are_admitted(self):
        with self.assertRaisesRegex(ValueError, 'owned BusyData'):
            VmAcceptance(self.root, vm='unrelated-host')
        (self.root / 'lib/main.dart').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'active frozen'):
            VmAcceptance(self.root)

    def test_staged_build_source_exactly_reproduces_frozen_archive(self):
        runner = VmAcceptance(self.root)
        staged = runner.materialize_source()
        self.assertEqual(source_manifest(self.root), source_manifest(staged))
        self.assertEqual('frozen fixture source', (staged / 'lib/main.dart').read_text())
        self.assertTrue(staged.is_relative_to(runner.work))

    def test_managed_pack_boundary_keeps_public_archive_modes_under_private_umask(self):
        previous = os.umask(0o077)
        try:
            runner = VmAcceptance(self.root)
            source = runner.materialize_source()
            product = self.root / 'build/linux/x64/release/bundle'
            values = {name: name.encode() for name in (
                'busydata', 'lib/libapp.so', 'backend/runtime/bin/java',
                'backend/lib/application.jar')}
            for name, value in values.items():
                path = product / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(value)
            for name in ('busydata', 'backend/runtime/bin/java'):
                (product / name).chmod(0o755)
            publish_public_bundle(product)
            product_modes = {path.relative_to(product): path.stat().st_mode
                             for path in (product, *product.rglob('*'))}
            (self.root / 'build/linux-release-build.json').write_text('{}')
            private = runner.work / 'private-fixture'
            private.write_bytes(b'private fixture')
            acceptance_source = self.root / 'build/acceptance-fixture'
            shutil.copytree(product, acceptance_source)
            acceptance_values = {**values, 'lib/libapp.so': b'acceptance entrypoint'}
            (acceptance_source / 'lib/libapp.so').write_bytes(acceptance_values['lib/libapp.so'])
            publish_public_bundle(acceptance_source)
            archive = self.root / 'build/busydata-installed-acceptance.tar.gz'
            with tarfile.open(archive, 'w:gz') as output:
                output.add(acceptance_source, arcname='bundle')
            with tarfile.open(archive) as content:
                for member in content:
                    self.assertEqual(0o755 if member.isdir() or member.name in (
                        'bundle/busydata', 'bundle/backend/runtime/bin/java') else 0o644,
                        member.mode)
            acceptance = {'sourceSha256': runner.source, 'archiveSha256': digest(archive)}
            (self.root / 'build/snap-acceptance-build.json').write_text(json.dumps(acceptance))
            destinations, extracted_modes = [], []
            original_extract = tarfile.TarFile.extractall

            def safe_extract(content, destination, **options):
                self.assertEqual('data', options.get('filter'))
                original_extract(content, destination, **options)
                bundle = Path(destination) / 'bundle'
                # Exercise the real data filter: it ignores recorded directory
                # modes, so the controller's unchanged 077 umask wins initially.
                modes = {stat.S_IMODE(path.stat().st_mode)
                         for path in (bundle, *bundle.rglob('*')) if path.is_dir()}
                self.assertEqual({0o700}, modes)
                extracted_modes.append(modes)

            def managed_command(name, command, **options):
                if name.startswith('unpack-'):
                    self.assertEqual(0o022, options['umask'])
                else:
                    self.assertNotIn('umask', options)
                if name.startswith('snap-pack-'):
                    output = Path(command[command.index('--output') + 1])
                    self.assertFalse(output.is_absolute())
                    destination = options['cwd'] / output
                    self.assertTrue(destination.resolve().is_relative_to(source.resolve()))
                    self.assertTrue(destination.is_dir())
                    destinations.append(destination)
                    bundle = source / 'build/linux/x64/release/bundle'
                    expected = acceptance_values if name.endswith('acceptance') else values
                    for path in (bundle, *bundle.rglob('*')):
                        relative = path.relative_to(bundle).as_posix()
                        mode = 0o755 if path.is_dir() or relative in (
                            'busydata', 'backend/runtime/bin/java') else 0o644
                        self.assertEqual(mode, stat.S_IMODE(path.stat().st_mode))
                        if path.is_file():
                            self.assertEqual(expected[relative], path.read_bytes())
                    self.assertEqual(0o700, stat.S_IMODE(bundle.parent.stat().st_mode))
                    self.assertEqual(0o700, stat.S_IMODE(runner.work.stat().st_mode))
                    self.assertEqual(0o600, stat.S_IMODE(private.stat().st_mode))
                    (destination / 'busydata.snap').write_bytes(name.encode())
                elif name.startswith(('payload-', 'inventory-')):
                    Path(command[command.index('--output') + 1]).write_text('{}')
                return ''

            with patch('verify_installed_snap_vm.verify_existing_bundle'), \
                    patch.object(tarfile.TarFile, 'extractall', new=safe_extract), \
                    patch.object(runner, 'run', side_effect=managed_command):
                packages = runner.build_packages(source)
            self.assertEqual([{0o700}], extracted_modes)
            self.assertEqual({'product', 'acceptance'}, set(packages))
            self.assertEqual(2, len(set(destinations)))
            self.assertTrue(all(path.is_file() for path in packages.values()))
            self.assertEqual(source_manifest(self.root), source_manifest(source))
            self.assertEqual(product_modes, {path.relative_to(product): path.stat().st_mode
                                             for path in (product, *product.rglob('*'))})
            for name, value in values.items():
                self.assertEqual(value, (product / name).read_bytes())
            self.assertEqual(b'private fixture', private.read_bytes())
            self.assertEqual(acceptance['archiveSha256'], digest(archive))
            self.assertEqual(0o077, os.umask(0o077))
        finally:
            os.umask(previous)

    def test_nonrunning_or_wrong_type_vm_fails_without_package_build_or_install(self):
        runner = VmAcceptance(self.root)
        called = []
        def fake_run(name, command, **options):
            called.append(command)
            return json.dumps([{'name': VM, 'type': 'container', 'status': 'Running'}])
        with patch('verify_installed_snap_vm.shutil.which', return_value='/owned/tool'), \
                patch.object(runner, 'run', side_effect=fake_run):
            self.assertEqual(1, runner.execute())
        self.assertEqual(1, len(called))
        self.assertFalse(any('install' in command for command in called))
        record = json.loads((self.root / 'build/installed-snap.json').read_text())
        self.assertFalse(record['fullInstalledDatabaseFileSecretSshAcceptance'])
        self.assertEqual([], record['packages'])
        self.assertFalse(record['hostSnapModified'])

    def test_command_failure_retains_hash_bound_bounded_diagnostics(self):
        runner = VmAcceptance(self.root)
        with self.assertRaisesRegex(RuntimeError, 'exit 7'):
            runner.run('controlled-failure', [sys.executable, '-c', 'print("controlled failure");raise SystemExit(7)'], timeout=10)
        self.assertEqual(7, runner.records[-1]['exitCode'])
        self.assertEqual(runner.source, runner.records[-1]['buildSourceSha256'])
        self.assertTrue(runner.logs[-1]['complete'])
        self.assertEqual(8 * 1024 * 1024, runner.logs[-1]['limitBytes'])
        self.assertTrue((self.root / runner.logs[-1]['file']).is_file())

    def test_explicit_child_umask_preserves_private_parent_and_default_inheritance(self):
        original = os.umask(0o077)
        try:
            runner = VmAcceptance(self.root)
            self.assertEqual(0o700, stat.S_IMODE(runner.work.stat().st_mode))
            script = ("import os, sys\n"
                      "descriptor = os.open(sys.argv[1], os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o777)\n"
                      "os.close(descriptor)\n")
            extracted = runner.work / 'explicit-child-executable'
            runner.run('explicit-child-mask', [sys.executable, '-c', script, str(extracted)],
                       timeout=10, umask=0o022)
            self.assertEqual(0o755, stat.S_IMODE(extracted.stat().st_mode))
            self.assertEqual(0o077, os.umask(0o077))
            private = runner.work / 'parent-private-file'
            private.write_text('private fixture')
            self.assertEqual(0o600, stat.S_IMODE(private.stat().st_mode))
            inherited = runner.work / 'inherited-child-executable'
            runner.run('inherited-child-mask', [sys.executable, '-c', script, str(inherited)],
                       timeout=10)
            self.assertEqual(0o700, stat.S_IMODE(inherited.stat().st_mode))
            self.assertEqual(0o077, os.umask(0o077))
            self.assertTrue(all(item['exitCode'] == 0 for item in runner.records))
            self.assertTrue(all(item['complete'] for item in runner.logs))
        finally:
            os.umask(original)

    def test_generated_product_probe_is_readable_without_relaxing_private_paths(self):
        class ProbeReady(Exception):
            pass

        original = os.umask(0o077)
        try:
            runner = VmAcceptance(self.root)
            fixture = runner.work / 'fixture.tar.gz'
            fixture.write_bytes(b'private fixture archive')
            receipt = runner.work / 'fixture-receipt.json'
            receipt.write_text('{}')
            packages = {}
            for kind in ('product', 'acceptance'):
                packages[kind] = runner.work / (kind + '.snap')
                packages[kind].write_bytes(kind.encode())
            operations = []
            pushed = {}

            def push(name, source, remote):
                operations.append(name)
                pushed[name] = (Path(source), remote, stat.S_IMODE(Path(source).stat().st_mode))

            def vm_command(name, command, **options):
                operations.append(name)
                if name == 'vm-owned-directory':
                    self.assertEqual(['install', '-d', '-o', '1001', '-g', '1002',
                                      '-m', '0700', runner.remote], command)
                if name == 'vm-product-package-hash':
                    return digest(packages['product']) + '  product.snap'
                if name == 'vm-package-hash':
                    return digest(packages['acceptance']) + '  acceptance.snap'
                if name == 'vm-install-product':
                    raise ProbeReady()
                return ''

            with patch.object(runner, 'fixture_archive', return_value=(fixture, receipt)), \
                    patch.object(runner, 'push', side_effect=push), \
                    patch.object(runner, 'vm_command', side_effect=vm_command):
                with self.assertRaises(ProbeReady):
                    runner.install_and_run(packages)
            probe, remote, mode = pushed['push-product-probe']
            self.assertEqual(runner.remote + '/product-probe.py', remote)
            self.assertEqual(VM_PRODUCT_PROBE, probe.read_text())
            self.assertEqual(0o644, mode,
                             'The later root-owned push must remain readable by VM user 1001.')
            self.assertLess(operations.index('vm-prepare'), operations.index('push-product-probe'))
            self.assertEqual(0o700, stat.S_IMODE(runner.work.stat().st_mode))
            self.assertEqual(0o600, pushed['push-preparation'][2])
            self.assertEqual(0o600, stat.S_IMODE(fixture.stat().st_mode))
            private = runner.work / 'still-private'
            private.write_text('private fixture')
            self.assertEqual(0o600, stat.S_IMODE(private.stat().st_mode))
            self.assertEqual(0o077, os.umask(0o077))
        finally:
            os.umask(original)

    def test_normal_close_requests_client_consent_without_destroying_its_window(self):
        x11 = Mock()
        x11.XOpenDisplay.return_value = 42
        x11.XInternAtom.side_effect = lambda display, name, exists: {
            b'WM_PROTOCOLS': 100, b'WM_DELETE_WINDOW': 101}[name]
        received = []

        def receive(display, window, propagate, mask, pointer):
            event = pointer._obj.client
            received.append((window, event.type, event.message_type, event.format,
                             list(event.data.l)))
            return 1

        x11.XSendEvent.side_effect = receive
        with patch('ctypes.CDLL', return_value=x11):
            request_x11_window_close('314')
        self.assertEqual([(314, 33, 100, 32, [101, 0, 0, 0, 0])], received)
        x11.XDestroyWindow.assert_not_called()
        x11.XKillClient.assert_not_called()
        x11.XFlush.assert_called_once_with(42)
        x11.XCloseDisplay.assert_called_once_with(42)

    def test_rejected_close_requests_release_display_without_force_close(self):
        for display, atom, sent in ((None, 100, 1), (42, 0, 1), (42, 100, 0)):
            with self.subTest(display=display, atom=atom, sent=sent):
                x11 = Mock()
                x11.XOpenDisplay.return_value = display
                x11.XInternAtom.return_value = atom
                x11.XSendEvent.return_value = sent
                with patch('ctypes.CDLL', return_value=x11):
                    with self.assertRaises(RuntimeError):
                        request_x11_window_close('314')
                x11.XDestroyWindow.assert_not_called()
                x11.XKillClient.assert_not_called()
                if display:
                    x11.XCloseDisplay.assert_called_once_with(display)
                else:
                    x11.XCloseDisplay.assert_not_called()

    def test_remote_preparation_is_valid_python_with_private_owned_paths(self):
        compile(VM_PREPARATION, 'owned-vm-preparation', 'exec')
        compile(VM_PRODUCT_PROBE, 'owned-product-probe', 'exec')
        self.assertIn("source_hash(source)!=expected", VM_PREPARATION)
        self.assertIn("filter='data'", VM_PREPARATION)
        self.assertNotIn('hardcoded-source-hash', VM_PREPARATION)

    def test_approved_vm_cli_directory_is_usable(self):
        executable = self.root / 'opt/busydata-docker/docker/docker'
        executable.parent.mkdir(parents=True)
        executable.write_text('#!' + sys.executable + "\nprint('fixture-cli-executed')\n")
        executable.chmod(0o755)
        runner = VmAcceptance(self.root)
        arguments = runner.fixture_environment()
        environment = dict(os.environ)
        for item in arguments[1:]:
            key, value = item.split('=', 1)
            environment[key] = value.replace('/opt/busydata-docker', str(self.root / 'opt/busydata-docker'))
        self.assertEqual(str(executable), shutil.which('docker', path=environment['PATH']))
        result = subprocess.run(['docker', 'version'], env=environment,
                                capture_output=True, text=True, check=True)
        self.assertEqual('fixture-cli-executed', result.stdout.strip())


if __name__ == '__main__':
    unittest.main()
