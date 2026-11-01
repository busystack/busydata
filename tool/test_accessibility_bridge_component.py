import unittest

from verify_native_accessibility_component import component_test_counts


class AccessibilityBridgeComponentTest(unittest.TestCase):
    def test_exact_complete_case_set_is_required(self):
        counts = component_test_counts('TAP version 14\n1..2\nok 1 /bridge/a\nok 2 /bridge/b\n',
                                       ['/bridge/a', '/bridge/b'])
        self.assertEqual({'total': 2, 'passed': 2, 'failed': 0, 'skipped': 0,
                          'unrun': 0, 'complete': True}, counts)

    def test_skip_todo_missing_duplicate_or_substituted_cases_cannot_pass(self):
        for text in ('1..2\nok 1 /bridge/a\nok 2 /bridge/b # SKIP unavailable\n',
                     '1..2\nok 1 /bridge/a\nok 2 /bridge/b # TODO not implemented\n',
                     '1..2\nok 1 /bridge/a\n',
                     '1..2\nok 1 /bridge/a\nok 2 /bridge/a\n',
                     '1..2\nok 1 /bridge/a\nok 2 /bridge/other\n',
                     '1..2\nok 2 /bridge/a\nok 1 /bridge/b\n',
                     '1..1\nok 1 /bridge/a\nok 2 /bridge/b\n',
                     '1..2\n1..2\nok 1 /bridge/a\nok 2 /bridge/b\n'):
            with self.subTest(text=text):
                self.assertFalse(component_test_counts(text, ['/bridge/a', '/bridge/b'])['complete'])

    def test_partial_failure_records_actual_pass_fail_and_unrun(self):
        counts = component_test_counts('1..3\nok 1 /bridge/a\nnot ok /bridge/b - ERROR\nBail out!\n',
                                       ['/bridge/a', '/bridge/b', '/bridge/c'])
        self.assertEqual(1, counts['passed'])
        self.assertEqual(1, counts['failed'])
        self.assertEqual(1, counts['unrun'])
        self.assertFalse(counts['complete'])

    def test_no_plan_empty_manifest_or_bail_after_success_cannot_pass(self):
        self.assertFalse(component_test_counts('ok 1 /bridge/a\n', ['/bridge/a'])['complete'])
        self.assertFalse(component_test_counts('1..0\n', [])['complete'])
        self.assertFalse(component_test_counts('1..1\nok 1 /bridge/a\nBail out!\n',
                                              ['/bridge/a'])['complete'])


if __name__ == '__main__':
    unittest.main()
