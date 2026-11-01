import subprocess
import sys
import tempfile
from pathlib import Path
import unittest
from bounded_process_log import BoundedProcessLog


class ProcessLogTest(unittest.TestCase):
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
