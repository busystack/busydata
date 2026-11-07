import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from verify_native_accessibility_component import component_test_counts, run


class AccessibilityBridgeComponentTest(unittest.TestCase):
    def run_stdio_fixture(self, source, output):
        launch = subprocess.Popen
        children = []

        def fixture_launch(*args, **kwargs):
            # This exercises real child pipes on both unit-test platforms. The
            # GTK verifier's Linux core-dump policy is not a Windows fixture.
            if os.name == 'nt':
                kwargs.pop('preexec_fn')
            child = launch(*args, **kwargs)
            children.append(child)
            return child

        try:
            with patch('verify_native_accessibility_component.subprocess.Popen',
                       side_effect=fixture_launch):
                return run([sys.executable, '-c', source], output,
                           timeout=10, environment=os.environ.copy())
        finally:
            for child in children:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=5)

    def test_unterminated_diagnostic_cannot_corrupt_real_tap_stdout(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'component.log'
            report = self.run_stdio_fixture(
                'import os;os.write(2,b"diagnostic without newline");'
                'os.write(1,b"1..1\\nok 1 /bridge/a\\n")', output)
            self.assertTrue(report['passed'])
            self.assertTrue(component_test_counts(output.read_text(), ['/bridge/a'])['complete'])
            self.assertEqual(b'diagnostic without newline',
                             Path(report['stderrLog']['file']).read_bytes())
            self.assertTrue(report['stderrLog']['complete'])

    def test_truncated_stderr_cannot_accept_complete_tap_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'component.log'
            report = self.run_stdio_fixture(
                'import sys;sys.stdout.write("1..1\\nok 1 /bridge/a\\n");'
                'sys.stdout.flush();sys.stderr.buffer.write(b"e"*(2*1024*1024+1))', output)
            self.assertTrue(component_test_counts(output.read_text(), ['/bridge/a'])['complete'])
            self.assertTrue(report['log']['complete'])
            self.assertFalse(report['stderrLog']['complete'])
            self.assertEqual(2 * 1024 * 1024, report['stderrLog']['retainedBytes'])
            self.assertFalse(report['passed'])

    def test_separate_streams_keep_original_combined_byte_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            report = self.run_stdio_fixture(
                'import sys;sys.stdout.buffer.write(b"o"*(1024*1024+1));'
                'sys.stdout.flush();sys.stderr.buffer.write(b"e"*(1024*1024+1))',
                Path(directory) / 'component.log')
            self.assertTrue(report['log']['complete'])
            self.assertTrue(report['stderrLog']['complete'])
            self.assertEqual(2 * 1024 * 1024 + 2, report['combinedReceivedBytes'])
            self.assertFalse(report['passed'])

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
