from pathlib import Path
import tempfile
import unittest

from verify_native_accessibility import native_reader_line_ready


class NativeReaderLineTest(unittest.TestCase):
    entered = '01:02:03.000001 - FLAT REVIEW PRESENTER: Creating new context. Restrict: False\n'
    spoken = "01:02:03.000002 - SPEECH OUTPUT: '日' {'established': False}\n"

    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.log = Path(self.directory.name) / 'reader.log'

    def test_old_ime_speech_and_review_entry_cannot_acknowledge_new_command(self):
        old = (self.entered + self.spoken).encode('utf-8')
        self.log.write_bytes(old)
        self.assertFalse(native_reader_line_ready(self.log, len(old), '日'))
        self.log.write_bytes(old + self.spoken.encode('utf-8'))
        self.assertFalse(native_reader_line_ready(self.log, len(old), '日'))
        self.log.write_bytes(old + (self.entered + self.spoken).encode('utf-8'))
        self.assertTrue(native_reader_line_ready(self.log, len(old), '日'))

    def test_speech_must_follow_fresh_review_entry(self):
        self.log.write_text(self.spoken + self.entered, encoding='utf-8')
        self.assertFalse(native_reader_line_ready(self.log, 0, '日'))
        self.log.write_text(self.entered + self.spoken, encoding='utf-8')
        self.assertTrue(native_reader_line_ready(self.log, 0, '日'))

    def test_wrong_text_and_inline_context_name_do_not_authorize_receipt(self):
        self.log.write_text(self.entered + self.spoken.replace("'日'", "'日本'"), encoding='utf-8')
        self.assertFalse(native_reader_line_ready(self.log, 0, '日'))
        self.log.write_text("01:02:03.000001 - SPEECH OUTPUT: '" + self.entered + self.spoken,
                            encoding='utf-8')
        self.assertFalse(native_reader_line_ready(self.log, 0, '日'))

    def test_missing_file_and_invalid_byte_fences_fail_closed(self):
        self.assertFalse(native_reader_line_ready(self.log, 0, '日'))
        self.log.write_text(self.entered + self.spoken, encoding='utf-8')
        self.assertFalse(native_reader_line_ready(self.log, -1, '日'))
        self.assertFalse(native_reader_line_ready(self.log, self.log.stat().st_size + 1, '日'))

    def test_reader_output_limit_is_enforced_before_parsing(self):
        self.log.write_bytes(b'x' * (4 * 1024 * 1024 + 1))
        with self.assertRaisesRegex(RuntimeError, 'diagnostic byte budget'):
            native_reader_line_ready(self.log, 0, '日')
