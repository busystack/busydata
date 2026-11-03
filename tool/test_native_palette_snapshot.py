"""Execute the actual nested palette reader at its native snapshot boundary."""
import ast
from pathlib import Path
import unittest
from native_workbench_acceptance import NativeSnapshotIncomplete, NativeNodeBudgetExceeded
from native_workbench_acceptance import read_native_snapshot, read_live_native_controls


class NativePaletteSnapshotTest(unittest.TestCase):
    def reader(self, snapshots):
        source = ast.parse(Path(__file__).with_name('native_workbench_acceptance.py').read_text(encoding='utf-8'))
        verify = next(node for node in source.body if isinstance(node, ast.FunctionDef) and node.name == 'verify')
        reader = next(node for node in verify.body if isinstance(node, ast.FunctionDef) and node.name == 'observed_values')
        def objects(app):
            value = next(snapshots)
            if isinstance(value, Exception):
                raise value
            return value
        namespace = {'objects': objects, 'app': object(),
                     'read_native_snapshot': read_native_snapshot,
                     'read_live_native_controls': read_live_native_controls}
        exec(compile(ast.Module(body=[reader], type_ignores=[]), 'actual-palette-read-boundary', 'exec'), namespace)
        return namespace['observed_values']

    def test_incomplete_palette_tree_remains_pending_before_complete_empty(self):
        read = self.reader(iter([NativeSnapshotIncomplete('retiring palette child'), []]))
        self.assertIsNone(read(lambda node: self.fail('Incomplete tree must not be projected')))
        self.assertEqual([], read(lambda node: self.fail('Complete empty tree has no node')))

    def test_complete_palette_field_values_are_preserved(self):
        read = self.reader(iter([['owned palette field']]))
        self.assertEqual([{'showing': True, 'focused': True}],
                         read(lambda node: {'showing': True, 'focused': True}))

    def test_invalid_owner_and_node_budget_errors_are_not_hidden(self):
        for failure in [ValueError('invalid native owner'), NativeNodeBudgetExceeded(2, 1, 1, 3)]:
            with self.subTest(failure=type(failure).__name__):
                read = self.reader(iter([failure]))
                with self.assertRaises(type(failure)) as raised:
                    read(lambda node: node)
                self.assertIs(failure, raised.exception)


if __name__ == '__main__':
    unittest.main()
