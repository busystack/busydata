from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

from native_png import MAX_PIXELS, MAX_PNG_BYTES, save_native_png


class NativePngTest(unittest.TestCase):
    def picture(self, data=b'\x89PNG\r\n\x1a\nfixture', width=1280, height=800):
        self.encodings = []
        def encode(*arguments):
            self.encodings.append(arguments)
            return True, data
        return types.SimpleNamespace(get_width=lambda: width, get_height=lambda: height,
                                     save_to_bufferv=encode)

    def test_exact_encoding_is_atomically_written_to_long_owned_path(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory) / ('a' * 100) / ('b' * 100)
            folder.mkdir(parents=True, mode=0o700)
            path = folder / ('transaction-review-' + 'c' * 90 + '.png')
            picture = self.picture()
            save_native_png(picture, path)
            self.assertEqual(path.read_bytes(), b'\x89PNG\r\n\x1a\nfixture')
            self.assertEqual(self.encodings, [('png', [], [])])
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(list(folder.iterdir()), [path])

    def test_an_owned_previous_capture_is_replaced_only_after_complete_encoding(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'frame.png'
            path.write_bytes(b'previous')
            picture = self.picture()
            picture.save_to_bufferv = lambda *_: (False, b'')
            with self.assertRaises(RuntimeError): save_native_png(picture, path)
            self.assertEqual(path.read_bytes(), b'previous')
            save_native_png(self.picture(), path)
            self.assertTrue(path.read_bytes().startswith(b'\x89PNG'))

    def test_invalid_dimensions_reject_before_encoding(self):
        for width, height in ((0, 800), (True, 800), (-1, 800), (8193, 1),
                              (8192, 8192), (MAX_PIXELS, 1)):
            with self.subTest(width=width, height=height):
                picture = self.picture(width=width, height=height)
                with self.assertRaises(ValueError): save_native_png(picture, '/unused.png')
                self.assertEqual(self.encodings, [])

    def test_invalid_encoded_result_cannot_publish_a_capture(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'frame.png'
            for data in (b'', b'not png', bytearray(b'\x89PNG\r\n\x1a\n')):
                with self.subTest(data=data), self.assertRaises(RuntimeError):
                    save_native_png(self.picture(data), path)
                self.assertFalse(path.exists())

    def test_encoded_size_bound_is_enforced_without_partial_output(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'frame.png'
            with patch('native_png.MAX_PNG_BYTES', 10), self.assertRaises(ValueError):
                save_native_png(self.picture(), path)
            self.assertFalse(path.exists())
            self.assertGreater(MAX_PNG_BYTES, 4 * MAX_PIXELS)

    def test_write_failure_keeps_previous_capture_and_removes_only_owned_temporary(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'frame.png'
            path.write_bytes(b'previous')
            with patch('native_png.os.fsync', side_effect=OSError('write failure')), self.assertRaises(OSError):
                save_native_png(self.picture(), path)
            self.assertEqual(path.read_bytes(), b'previous')
            self.assertEqual(list(path.parent.iterdir()), [path])

    def test_symlink_targets_and_directories_never_follow_or_overwrite_foreign_files(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            original = folder / 'original'
            original.write_bytes(b'preserve')
            link = folder / 'frame.png'
            link.symlink_to(original)
            with self.assertRaises(RuntimeError): save_native_png(self.picture(), link)
            self.assertEqual(original.read_bytes(), b'preserve')
            nested = folder / 'nested'
            nested.mkdir()
            directory_link = folder / 'linked'
            directory_link.symlink_to(nested, target_is_directory=True)
            with self.assertRaises(OSError): save_native_png(self.picture(), directory_link / 'frame.png')
            self.assertEqual(list(nested.iterdir()), [])

    def test_group_writable_evidence_directory_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            folder.chmod(0o770)
            with self.assertRaises(RuntimeError): save_native_png(self.picture(), folder / 'frame.png')
            self.assertEqual(list(folder.iterdir()), [])
