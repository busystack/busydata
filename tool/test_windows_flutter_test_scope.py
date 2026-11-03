import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from windows_flutter_test_scope import LINUX_RENDERER_TESTS, test_scope


class WindowsFlutterTestScopeTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        for name in LINUX_RENDERER_TESTS:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('testWidgets(..., skip: !Platform.isLinux);')

    def scope(self):
        with patch('windows_flutter_test_scope.source_hash', return_value='source-id'):
            return test_scope(self.root)

    def test_every_shared_and_new_windows_file_is_selected(self):
        expected = ['test/new/shared_test.dart', 'test/windows_test.dart']
        for name in expected:
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('testWidgets(...);')
        receipt = self.scope()
        self.assertEqual(expected, receipt['selected'])
        self.assertEqual(LINUX_RENDERER_TESTS, {item['path'] for item in receipt['excluded']})
        self.assertTrue(all(len(item['sha256']) == 64 for item in receipt['excluded']))

    def test_changed_platform_applicability_requires_review(self):
        name = sorted(LINUX_RENDERER_TESTS)[0]
        (self.root / name).write_text('testWidgets(...);')
        with self.assertRaisesRegex(ValueError, 'no longer explicitly Linux-only'):
            self.scope()

    def test_missing_scoped_file_requires_review(self):
        (self.root / sorted(LINUX_RENDERER_TESTS)[0]).unlink()
        with self.assertRaisesRegex(ValueError, 'scope requires review'):
            self.scope()

    def test_empty_windows_suite_is_rejected(self):
        with self.assertRaisesRegex(ValueError, 'cannot be empty'):
            self.scope()
