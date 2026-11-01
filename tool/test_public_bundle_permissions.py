from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import stat
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import desktop_build_evidence
from public_bundle_permissions import (publish_public_bundle, validate_public_bundle,
                                       validate_public_payload_paths)


@contextmanager
def private_fixture():
    previous = os.umask(0o077)
    try:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'private-input'
            for name in ('busydata', 'lib/libapp.so', 'backend/runtime/bin/java',
                         'backend/runtime/bin/owner-only-tool', 'backend/runtime/lib/modules',
                         'backend/runtime/lib/server/libjvm.so',
                         'backend/runtime/legal/LICENSE',
                         'backend/lib/busydata-backend-0.1.0.jar',
                         'backend/dependency-inventory.json'):
                path = source / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(name.encode())
            (source / 'busydata').chmod(0o755)
            (source / 'backend/runtime/bin/java').chmod(0o711)
            (source / 'backend/runtime/bin/owner-only-tool').chmod(0o700)
            (source / 'backend/runtime/legal/current').symlink_to('LICENSE')
            secret = root / 'private-key'
            secret.write_bytes(b'private fixture key')
            yield root, source, secret
    finally:
        os.umask(previous)


def snapshot(root):
    result = {}
    for path in (root, *root.rglob('*')):
        info = path.lstat()
        value = path.readlink().as_posix() if stat.S_ISLNK(info.st_mode) else (
            path.read_bytes() if stat.S_ISREG(info.st_mode) else None)
        result[path.relative_to(root).as_posix()] = (info.st_mode, value)
    return result


class PublicBundlePermissionsTest(unittest.TestCase):
    def test_public_copy_modes_preserve_exact_bytes_exec_bits_and_private_inputs(self):
        with private_fixture() as (root, source, secret):
            original = snapshot(source)
            bundle = root / 'published-copy'
            shutil.copytree(source, bundle, symlinks=True)
            receipt = publish_public_bundle(bundle)
            validate_public_bundle(bundle)
            self.assertEqual(original, snapshot(source))
            self.assertEqual(0o700, stat.S_IMODE(root.stat().st_mode))
            self.assertEqual(0o600, stat.S_IMODE(secret.stat().st_mode))
            self.assertEqual(b'private fixture key', secret.read_bytes())
            self.assertEqual(0o077, os.umask(0o077))
            for path in (bundle, *bundle.rglob('*')):
                info = path.lstat()
                before = original[path.relative_to(bundle).as_posix()]
                if stat.S_ISLNK(info.st_mode):
                    self.assertEqual(before[1], path.readlink().as_posix())
                elif stat.S_ISDIR(info.st_mode):
                    self.assertEqual(0o755, stat.S_IMODE(info.st_mode))
                else:
                    self.assertEqual(0o644 | (before[0] & 0o111), stat.S_IMODE(info.st_mode))
                    self.assertEqual(before[1], path.read_bytes())
            self.assertEqual(0o755, stat.S_IMODE((bundle/'backend/runtime/bin/java').stat().st_mode))
            self.assertEqual(0o744, stat.S_IMODE((bundle/'backend/runtime/bin/owner-only-tool').stat().st_mode))
            self.assertGreater(receipt['directories'], 0)
            self.assertGreater(receipt['files'], 0)

    def test_foreign_links_shared_files_and_special_entries_fail_before_any_chmod(self):
        for fault in ('escape', 'hardlink', 'dangling', 'special', 'indirect-root'):
            with self.subTest(fault=fault), private_fixture() as (root, source, secret):
                original = snapshot(source)
                bundle = root / 'published-copy'
                shutil.copytree(source, bundle, symlinks=True)
                target = bundle
                if fault == 'escape':
                    (bundle/'foreign').symlink_to(source/'backend/runtime/lib/modules')
                elif fault == 'hardlink':
                    os.link(secret, bundle/'foreign')
                elif fault == 'dangling':
                    (bundle/'foreign').symlink_to('missing')
                elif fault == 'special':
                    os.mkfifo(bundle/'foreign')
                else:
                    target = root / 'indirect-copy'
                    target.symlink_to(bundle, target_is_directory=True)
                before = snapshot(bundle)
                with self.assertRaises((RuntimeError, OSError)):
                    publish_public_bundle(target)
                self.assertEqual(before, snapshot(bundle))
                self.assertEqual(original, snapshot(source))
                self.assertEqual(0o600, stat.S_IMODE(secret.stat().st_mode))
                self.assertEqual(b'private fixture key', secret.read_bytes())

    def test_inventory_limit_fails_before_any_mode_change(self):
        with private_fixture() as (root, source, _):
            bundle = root / 'published-copy'
            shutil.copytree(source, bundle, symlinks=True)
            before = snapshot(bundle)
            with patch('public_bundle_permissions.MAX_PUBLIC_BUNDLE_ENTRIES', 3):
                with self.assertRaisesRegex(RuntimeError, 'entry budget'):
                    publish_public_bundle(bundle)
            self.assertEqual(before, snapshot(bundle))

    def test_validation_rejects_permission_regressions_and_never_repairs(self):
        for kind in ('directory', 'file', 'special-bits'):
            with self.subTest(kind=kind), private_fixture() as (root, source, _):
                bundle = root / 'published-copy'
                shutil.copytree(source, bundle, symlinks=True)
                publish_public_bundle(bundle)
                path = bundle / ('backend/runtime' if kind == 'directory' else 'backend/runtime/lib/modules')
                path.chmod({'directory': 0o700, 'file': 0o600, 'special-bits': 0o4644}[kind])
                before = snapshot(bundle)
                with self.assertRaisesRegex(RuntimeError, 'permissions differ'):
                    validate_public_bundle(bundle)
                self.assertEqual(before, snapshot(bundle))

    def test_read_only_packaged_paths_allow_foreign_owner_without_relaxing_publication(self):
        with private_fixture() as (root, source, secret):
            bundle = root / 'packaged-copy'
            shutil.copytree(source, bundle, symlinks=True)
            publish_public_bundle(bundle)
            required = ['busydata', 'lib/libapp.so', 'backend/runtime/bin/java']
            before = snapshot(bundle)
            foreign_uid = os.getuid() + 1
            with patch('public_bundle_permissions.os.getuid', return_value=foreign_uid):
                with self.assertRaisesRegex(RuntimeError, 'different owner'):
                    publish_public_bundle(bundle)
                report = validate_public_payload_paths(bundle, required)
            self.assertEqual(3, report['files'])
            self.assertEqual(before, snapshot(bundle))
            parent = bundle / 'backend/runtime'
            parent.chmod(0o700)
            private = snapshot(bundle)
            with self.assertRaisesRegex(ValueError, 'permissions differ'):
                validate_public_payload_paths(bundle, required)
            self.assertEqual(private, snapshot(bundle))
            self.assertEqual(0o700, stat.S_IMODE(root.stat().st_mode))
            self.assertEqual(0o600, stat.S_IMODE(secret.stat().st_mode))

    def test_read_only_packaged_paths_are_bounded_and_cannot_escape_or_follow_links(self):
        with private_fixture() as (root, source, _):
            bundle = root / 'packaged-copy'
            shutil.copytree(source, bundle, symlinks=True)
            publish_public_bundle(bundle)
            before = snapshot(bundle)
            for names in (['../private-key'], ['/private-key'], ['.'],
                          ['backend/runtime/legal/current'],
                          ['backend/runtime/bin/java', 'backend/runtime']):
                with self.subTest(names=names), self.assertRaises(ValueError):
                    validate_public_payload_paths(bundle, names)
            with patch('public_bundle_permissions.MAX_PUBLIC_BUNDLE_ENTRIES', 3):
                with self.assertRaisesRegex(ValueError, 'entry budget'):
                    validate_public_payload_paths(bundle, ['backend/runtime/bin/java'])
            self.assertEqual(before, snapshot(bundle))

    def test_desktop_build_publishes_generated_copy_before_recording_complete_inventory(self):
        with private_fixture() as (root, source, secret):
            original = snapshot(source)
            bundle = root / 'build/linux/x64/release/bundle'
            bundle.parent.mkdir(parents=True)
            shutil.copytree(source, bundle, symlinks=True)
            with patch.object(desktop_build_evidence, 'ROOT', root), \
                 patch.object(desktop_build_evidence, 'verify_bundle', return_value='backend'), \
                 patch.object(desktop_build_evidence, 'verify_jar', return_value='backend'), \
                 patch.object(desktop_build_evidence, 'source_hash', return_value='fixed-source'), \
                 patch.object(desktop_build_evidence, 'revalidate_receipt', return_value={'proof': 'unchanged'}), \
                 patch.object(desktop_build_evidence, 'owned_build_environment', return_value={}), \
                 patch.object(desktop_build_evidence.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='{}')), \
                 patch('verify_linux_icon_font.verify_linux_icon_font', return_value={}):
                self.assertEqual(0, desktop_build_evidence.build('linux', no_pub=True))
            report = json.loads((root/'build/linux-release-build.json').read_text())
            desktop_build_evidence.verify_existing_bundle('linux', report, bundle, 'fixed-source')
            recorded = {item['path']: item for item in report['files']}
            self.assertEqual(0o644, recorded['backend/runtime/lib/modules']['mode'])
            self.assertEqual(0o755, recorded['backend/runtime/bin/java']['mode'])
            self.assertEqual(original, snapshot(source))
            self.assertEqual(0o600, stat.S_IMODE(secret.stat().st_mode))
