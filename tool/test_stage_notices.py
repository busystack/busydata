import json
from pathlib import Path
import tempfile
import unittest
from preserve_stage_notices import preserve
from verify_snap_distribution import receipts


class StageNoticesTest(unittest.TestCase):
    def test_actual_copyright_survives_gnome_cleanup_and_keeps_its_version_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, prime = root / 'stage', root / 'prime'
            copyright = stage / 'usr/share/doc/libexample/copyright'
            copyright.parent.mkdir(parents=True)
            copyright.write_text('Actual packaged component license 漢')
            sibling = copyright.parent.parent / 'libalias'
            sibling.symlink_to(copyright.parent.name, target_is_directory=True)
            records = preserve(stage, prime)
            self.assertEqual(2, len(records))
            copyright.unlink()  # GNOME removes duplicate libraries and their docs.
            actual = receipts(prime, {'parts': {'native-client': {'stage-packages': ['libexample=1.2.3', 'libalias=1.2.3']}}})
            self.assertEqual(['1.2.3', '1.2.3'], [item['version'] for item in actual])
            self.assertEqual(1, len({item['licenseSha256'] for item in actual}))
            self.assertEqual(2, len(json.loads((prime / 'backend/notices/ubuntu-stage/licenses.json').read_text())['packages']))

    def test_external_symlink_and_oversized_license_fail_before_copy(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage, prime = root / 'stage', root / 'prime'
            copyright = stage / 'usr/share/doc/example/copyright'
            copyright.parent.mkdir(parents=True)
            outside = root / 'unrelated'
            outside.write_text('Outside package stage')
            copyright.symlink_to(outside)
            with self.assertRaisesRegex(RuntimeError, 'path limit'):
                preserve(stage, prime)
            self.assertFalse(prime.exists())
            copyright.unlink()
            with copyright.open('wb') as source:
                source.truncate(2 * 1024 ** 2 + 1)
            with self.assertRaisesRegex(RuntimeError, 'byte budget'):
                preserve(stage, prime)
            self.assertFalse(prime.exists())


if __name__ == '__main__':
    unittest.main()
