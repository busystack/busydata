import math
from types import SimpleNamespace
import unittest

from native_workbench_acceptance import native_character_geometry


class NativeTextGeometryTest(unittest.TestCase):
    def node(self, precision='glyph-bounds'):
        return SimpleNamespace(clear_cache=lambda: None,
                               get_attributes=lambda: {'busydata-geometry-precision': precision})

    def api(self, glyph=None, field=None):
        field = field or SimpleNamespace(x=40, y=50, width=500, height=100)
        glyph = glyph or SimpleNamespace(x=45, y=55, width=18, height=22)
        return SimpleNamespace(
            CoordType=SimpleNamespace(WINDOW=1),
            Component=SimpleNamespace(get_extents=lambda node, kind: field),
            Text=SimpleNamespace(get_range_extents=lambda node, start, end, kind: glyph))

    def test_actual_character_bounds_record_exact_scope(self):
        receipt = native_character_geometry(self.api(), self.node(), 1)
        self.assertEqual({'precision': 'glyph-bounds', 'start': 1, 'end': 2,
                          'field': [40, 50, 500, 100], 'range': [45, 55, 18, 22]}, receipt)

    def test_field_bounds_and_missing_precision_cannot_certify_glyphs(self):
        for precision in ('field-bounds', '', 'guess'):
            with self.subTest(precision=precision), self.assertRaises(RuntimeError):
                native_character_geometry(self.api(), self.node(precision))
        with self.assertRaises(RuntimeError):
            native_character_geometry(self.api(), SimpleNamespace(
                clear_cache=lambda: None, get_attributes=lambda: {}))

    def test_positive_whole_field_substitution_is_rejected(self):
        field = SimpleNamespace(x=40, y=50, width=500, height=100)
        with self.assertRaises(RuntimeError):
            native_character_geometry(self.api(field, field), self.node())

    def test_unavailable_off_field_and_nonfinite_bounds_are_rejected(self):
        for glyph in (
                SimpleNamespace(x=45, y=55, width=0, height=22),
                SimpleNamespace(x=45, y=55, width=18, height=0),
                SimpleNamespace(x=4, y=55, width=18, height=22),
                SimpleNamespace(x=45, y=55, width=600, height=22),
                SimpleNamespace(x=45, y=160, width=18, height=22),
                SimpleNamespace(x=math.nan, y=55, width=18, height=22),
                SimpleNamespace(x=45, y=55, width=math.inf, height=22)):
            with self.subTest(glyph=glyph), self.assertRaises(RuntimeError):
                native_character_geometry(self.api(glyph), self.node())


if __name__ == '__main__':
    unittest.main()
