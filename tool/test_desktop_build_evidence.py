"""The recorded Windows inventory must round-trip through its bundle validator."""
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import desktop_build_evidence


class DesktopBuildEvidenceTest(unittest.TestCase):
    def test_windows_inventory_round_trips_native_nested_paths(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = root / 'build/windows/x64/runner/Release'
            names = {
                'busydata.exe', 'flutter_windows.dll', 'data/app.so',
                'backend/runtime/bin/java.exe',
                'backend/lib/busydata-backend-0.1.0.jar',
                'backend/dependency-inventory.json',
                'data/nested directory/資料.txt',
            }
            for name in names:
                file = bundle / name
                file.parent.mkdir(parents=True, exist_ok=True)
                file.write_bytes(('unit inventory fixture: ' + name).encode('utf-8'))
            with patch.object(desktop_build_evidence, 'ROOT', root), \
                 patch.object(desktop_build_evidence, 'verify_bundle', return_value='backend'), \
                 patch.object(desktop_build_evidence, 'verify_jar', return_value='backend'), \
                 patch.object(desktop_build_evidence, 'source_hash', return_value='fixed-source'), \
                 patch.object(desktop_build_evidence, 'revalidate_receipt', return_value={'proof': 'unchanged'}), \
                 patch.object(desktop_build_evidence, 'owned_build_environment', return_value={}), \
                 patch.object(desktop_build_evidence.subprocess, 'run',
                     return_value=SimpleNamespace(returncode=0, stdout='{}')):
                self.assertEqual(0, desktop_build_evidence.build('windows', no_pub=True))
            report = json.loads((root / 'build/windows-release-build.json').read_text())
            self.assertEqual(names, {item['path'] for item in report['files']})
            verified = desktop_build_evidence.verify_existing_bundle(
                'windows', report, bundle, 'fixed-source')
            self.assertEqual(names - {'data/nested directory/資料.txt'}, set(verified))
            (bundle / 'data/app.so').write_bytes(b'changed after the receipt')
            with self.assertRaisesRegex(RuntimeError, 'Product bundle contents changed'):
                desktop_build_evidence.verify_existing_bundle(
                    'windows', report, bundle, 'fixed-source')


if __name__ == '__main__':
    unittest.main()
