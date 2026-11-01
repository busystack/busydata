import base64
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import zipfile
from package_ui_comparison import Links, package


class ComparisonBundleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / 'gallery').mkdir()
        image = b'unchanged rendered pixels'
        (self.root / 'gallery/screen.png').write_bytes(image)
        (self.root / 'gallery/index.html').write_text(
            '<img src="screen.png"><a href="../gallery-source-identity.json">Source</a>')
        (self.root / 'gallery/images.json').write_text(json.dumps({'images': [
            {'path': 'screen.png', 'sha256': hashlib.sha256(image).hexdigest()}]}))
        for name in ('gallery-source-identity.json', 'baseline-source-identity.json', 'verification-summary.json'):
            (self.root / name).write_text('{}')
        (self.root / 'receipts').mkdir()
        (self.root / 'receipts/run.json').write_text('{"nativeAccepted":false}')

    def run_package(self):
        return package(self.root, self.root / 'bundle.zip', self.root / 'single.html', [self.root / 'receipts'])

    def test_every_dependency_and_receipt_travels_with_the_bundle(self):
        manifest = self.run_package()
        with zipfile.ZipFile(self.root / 'bundle.zip') as bundle:
            self.assertEqual(bundle.testzip(), None)
            self.assertIn('receipts/run.json', bundle.namelist())
            for path, record in manifest['files'].items():
                self.assertEqual(hashlib.sha256(bundle.read(path)).hexdigest(), record['sha256'])
        targets = Links((self.root / 'single.html').read_text()).targets
        self.assertTrue(all(target.startswith('data:') for target in targets))
        self.assertEqual(base64.b64decode(targets[0].split(',', 1)[1]), b'unchanged rendered pixels')

    def test_missing_image_is_rejected(self):
        (self.root / 'gallery/screen.png').unlink()
        with self.assertRaisesRegex(ValueError, 'Missing comparison'):
            self.run_package()

    def test_modified_image_is_rejected(self):
        (self.root / 'gallery/screen.png').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'does not match'):
            self.run_package()

    def test_links_cannot_include_files_outside_the_evidence(self):
        (self.root / 'gallery/index.html').write_text('<img src="../../outside.png">')
        with self.assertRaisesRegex(ValueError, 'escapes evidence'):
            self.run_package()


if __name__ == '__main__':
    unittest.main()
