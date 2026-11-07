import subprocess
import sys
import tempfile
from pathlib import Path
import unittest
from bounded_process_log import BoundedProcessLog


class ProcessLogTest(unittest.TestCase):
    def test_independent_stderr_pipe_is_drained_with_its_own_bound(self):
        with tempfile.TemporaryDirectory() as directory:
            child = subprocess.Popen([sys.executable, '-c',
                'import os\nfor i in range(256):\n'
                ' os.write(1,b"o"*8192);os.write(2,b"e"*8192)'],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            output = BoundedProcessLog(child, Path(directory) / 'stdout.log', limit=1024)
            errors = BoundedProcessLog(child, Path(directory) / 'stderr.log',
                                       limit=1024, stream=child.stderr)
            try:
                self.assertEqual(0, child.wait(timeout=10))
            finally:
                if child.poll() is None:
                    child.terminate()
                    child.wait(timeout=5)
            for log, value in ((output, b'o'), (errors, b'e')):
                report = log.finish()
                self.assertEqual(2 * 1024 * 1024, report['receivedBytes'])
                self.assertEqual(value * 1024, log.destination.read_bytes())
                self.assertFalse(report['complete'])

    def test_large_output_keeps_draining_but_cannot_pass_as_complete_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            child = subprocess.Popen([sys.executable, '-c',
                'import sys;sys.stdout.buffer.write(b"x"*1048576)'], stdout=subprocess.PIPE)
            log = BoundedProcessLog(child, Path(directory) / 'owned.log', limit=1024)
            self.assertEqual(0, child.wait(timeout=10))
            report = log.finish()
            self.assertEqual(1048576, report['receivedBytes'])
            self.assertEqual(1024, log.destination.stat().st_size)
            self.assertFalse(report['complete'])

    def test_complete_small_output_is_retained_exactly(self):
        with tempfile.TemporaryDirectory() as directory:
            child = subprocess.Popen([sys.executable, '-c', 'print("controlled diagnostic")'],
                                     stdout=subprocess.PIPE)
            log = BoundedProcessLog(child, Path(directory) / 'owned.log', limit=1024)
            self.assertEqual(0, child.wait(timeout=10))
            self.assertTrue(log.finish()['complete'])
            self.assertEqual(b'controlled diagnostic\n', log.destination.read_bytes())
