"""A failed fixture launch must not lose cleanup ownership or claim absence."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from verify_native_accessibility import stop_database_fixture


class NativeFixtureOwnershipTest(unittest.TestCase):
    def test_start_timeout_recovers_created_container_from_docker_receipt(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'fixture.cid'
            identifier = 'a' * 64
            receipt.write_bytes(identifier.encode('ascii') + b'\n')
            with patch('verify_native_accessibility.subprocess.run') as run:
                self.assertTrue(stop_database_fixture(None, receipt, True))
            run.assert_called_once_with(['docker', 'stop', identifier], check=True,
                stdout=subprocess.DEVNULL, timeout=30)

    def test_successful_launch_keeps_its_exact_reported_and_recorded_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'fixture.cid'
            identifier = 'b' * 64
            receipt.write_bytes(identifier.encode('ascii'))
            with patch('verify_native_accessibility.subprocess.run') as run:
                self.assertFalse(stop_database_fixture(identifier, receipt, True))
            self.assertEqual(['docker', 'stop', identifier], run.call_args.args[0])
            with patch('verify_native_accessibility.subprocess.run') as run:
                with self.assertRaisesRegex(RuntimeError, 'identifiers disagree'):
                    stop_database_fixture('c' * 64, receipt, True)
            run.assert_not_called()

    def test_missing_creation_receipt_cannot_certify_cleanup_after_lost_stdout(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch('verify_native_accessibility.subprocess.run') as run:
            receipt = Path(directory) / 'missing.cid'
            with self.assertRaisesRegex(RuntimeError, 'creation outcome is unavailable'):
                stop_database_fixture(None, receipt, True)
            run.assert_not_called()
            self.assertFalse(stop_database_fixture(None, receipt, False))
            run.assert_not_called()

    def test_malformed_oversized_or_linked_receipt_never_selects_a_container(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'fixture.cid'
            for contents in (b'', b'other-container', b'a' * 63,
                             b'A' * 64, b'a' * 64 + b'\n\n', b'a' * 65):
                with self.subTest(contents=contents):
                    receipt.write_bytes(contents)
                    with patch('verify_native_accessibility.subprocess.run') as run:
                        with self.assertRaisesRegex(RuntimeError, 'identifier receipt'):
                            stop_database_fixture(None, receipt, True)
                    run.assert_not_called()
            with patch.object(Path, 'is_symlink', return_value=True), \
                    patch('verify_native_accessibility.subprocess.run') as run:
                with self.assertRaisesRegex(RuntimeError, 'receipt is a link'):
                    stop_database_fixture(None, receipt, True)
            run.assert_not_called()

    def test_stop_timeout_remains_a_cleanup_failure_with_the_same_owner(self):
        with tempfile.TemporaryDirectory() as directory:
            receipt = Path(directory) / 'fixture.cid'
            identifier = 'd' * 64
            receipt.write_bytes(identifier.encode('ascii'))
            failure = subprocess.TimeoutExpired(['docker', 'stop', identifier], 30)
            with patch('verify_native_accessibility.subprocess.run', side_effect=failure) as run:
                with self.assertRaises(subprocess.TimeoutExpired) as raised:
                    stop_database_fixture(None, receipt, True)
            self.assertIs(failure, raised.exception)
            self.assertEqual(1, run.call_count)


if __name__ == '__main__':
    unittest.main()
