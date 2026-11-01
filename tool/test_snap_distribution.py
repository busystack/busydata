import tempfile
from pathlib import Path
import unittest
from verify_snap_distribution import receipts


class SnapReceiptTest(unittest.TestCase):
    def test_actual_versions_and_license_bytes_are_required(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'usr/share/doc/libfixture/copyright'
            path.parent.mkdir(parents=True)
            path.write_text('Fixture license notice')
            report = receipts(root, {'parts': {'client': {'stage-packages': ['libfixture=2.0']}}})
            self.assertEqual('2.0', report[0]['version'])
            self.assertEqual(64, len(report[0]['licenseSha256']))
            with self.assertRaisesRegex(RuntimeError, 'name/version'):
                receipts(root, {'parts': {'client': {'stage-packages': ['libfixture']}}})
            path.unlink()
            with self.assertRaisesRegex(RuntimeError, 'license'):
                receipts(root, {'parts': {'client': {'stage-packages': ['libfixture=2.0']}}})

    def test_license_symlink_cannot_certify_an_external_file(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            outside = root / 'unrelated'
            outside.write_text('Unrelated license')
            prime = root / 'prime'
            path = prime / 'usr/share/doc/libfixture/copyright'
            path.parent.mkdir(parents=True)
            path.symlink_to(outside)
            with self.assertRaisesRegex(RuntimeError, 'external'):
                receipts(prime, {'parts': {'client': {'stage-packages': ['libfixture=2.0']}}})
