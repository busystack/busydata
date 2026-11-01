import struct
import unittest
from verify_linux_icon_font import glyph_index


def font_with_cmap(subtable, encoding=1):
    cmap = struct.pack('>HHHHI', 0, 1, 3, encoding, 12) + subtable
    return struct.pack('>IHHHH4sIII', 0x00010000, 1, 0, 0, 0,
                       b'cmap', 0, 28, len(cmap)) + cmap


class LinuxIconFontTest(unittest.TestCase):
    def test_unicode_bmp_subset_and_missing_character(self):
        # One actual character plus the mandatory terminal segment.
        sub = struct.pack('>7H', 4, 32, 0, 4, 4, 1, 0)
        sub += struct.pack('>9H', 0xe123, 0xffff, 0, 0xe123, 0xffff,
                           (7 - 0xe123) & 0xffff, 1, 0, 0)
        data = font_with_cmap(sub)
        self.assertEqual(glyph_index(data, 0xe123), 7)
        self.assertEqual(glyph_index(data, 0xe124), 0)

    def test_full_unicode_group(self):
        sub = struct.pack('>HHIIIII', 12, 0, 28, 0, 1, 0x1f600, 0x1f601)
        sub += struct.pack('>I', 20)
        data = font_with_cmap(sub, 10)
        self.assertEqual(glyph_index(data, 0x1f601), 21)
        self.assertEqual(glyph_index(data, 0xe123), 0)

    def test_truncated_or_unbounded_font_is_rejected(self):
        for data in (b'', b'\0' * 12, b'\0' * (4 * 1024 * 1024 + 1)):
            with self.assertRaises(ValueError):
                glyph_index(data, 0xe123)


if __name__ == '__main__':
    unittest.main()
