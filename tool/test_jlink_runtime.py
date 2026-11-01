import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sys
from jlink_runtime import build_image


class JlinkRuntimeTest(unittest.TestCase):
    def test_zero_exit_with_native_strip_error_is_rejected_and_retained(self):
        import subprocess
        start = subprocess.Popen
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def child(command, **kwargs):
                self.assertEqual('-J-Djava.io.tmpdir=' + str(root / 'owned temp'), command[1])
                return start([sys.executable, '-c', 'print("Error: strip-native-debug-symbols: failed");raise SystemExit(0)'], **kwargs)
            with patch('jlink_runtime.subprocess.Popen', side_effect=child):
                with self.assertRaisesRegex(RuntimeError, 'verification failed'):
                    build_image('/selected/jlink', ['java.base'], root/'runtime', root/'owned temp', root/'jlink.log')
            report = json.loads((root/'jlink.json').read_text())
            self.assertEqual(0, report['commandExitCode'])
            self.assertFalse(report['passed'])
            self.assertTrue(report['reportedError'])
            self.assertTrue(report['log']['complete'])
            self.assertIn('strip-native', (root/'jlink.log').read_text())

    def test_log_budget_cannot_be_hidden_by_a_zero_exit(self):
        import subprocess
        start = subprocess.Popen
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            with patch('jlink_runtime.subprocess.Popen', side_effect=lambda command, **kwargs:
                       start([sys.executable, '-c', 'print("x"*1048577)'], **kwargs)):
                with self.assertRaisesRegex(RuntimeError, 'verification failed'):
                    build_image('/selected/jlink', ['java.base'], root/'runtime', root/'tmp', root/'jlink.log')
            self.assertEqual(1048576, (root/'jlink.log').stat().st_size)
            self.assertFalse(json.loads((root/'jlink.json').read_text())['log']['complete'])
