"""Fixture-lock ownership regressions; application acceptance stays real/native."""
import io
import types
import unittest
from unittest.mock import patch

from native_database_explorer_races import hold_fixture_catalog


class FixtureLockTest(unittest.TestCase):
    def exercise(self, acquired=True, body_failure=False):
        events, evidence = [], {}
        process = types.SimpleNamespace(stdin=io.BytesIO(), stdout=types.SimpleNamespace(fileno=lambda: 42), returncode=None)
        process.poll = lambda: process.returncode
        def communicate(value, timeout):
            events.append((value, timeout))
            process.returncode = 0
            return b'', b''
        process.communicate = communicate
        selector = types.SimpleNamespace(register=lambda *args: None,
            select=lambda timeout: [True], close=lambda: events.append('selector-closed'))
        def wait(check, timeout):
            value = check()
            if value is None: raise TimeoutError('No fixture lock acknowledgement')
            return value
        acknowledgement = b'busydata-catalog-lock:1234\n' if acquired else b'not-an-acknowledgement\n'
        with patch('native_database_explorer_races.subprocess.Popen', return_value=process), \
                patch('native_database_explorer_races.selectors.DefaultSelector', return_value=selector), \
                patch('native_database_explorer_races.os.read', return_value=acknowledgement):
            try:
                with hold_fixture_catalog('owned-disposable-fixture', wait, evidence):
                    self.assertTrue(evidence['acquired'])
                    self.assertEqual(1234, evidence['fixtureOwnerPid'])
                    if body_failure: raise ValueError('Native interaction failed')
            except (ValueError, TimeoutError) as error:
                self.assertEqual(ValueError if body_failure else TimeoutError, type(error))
            else:
                self.assertTrue(acquired and not body_failure)
        self.assertEqual(['selector-closed', (b'ROLLBACK;\n\\q\n', 10)], events)
        self.assertTrue(evidence['released'])
        self.assertIn(b"idle_in_transaction_session_timeout='30s'", process.stdin.getvalue())

    def test_release_after_native_success(self):
        self.exercise()

    def test_release_after_native_failure(self):
        self.exercise(body_failure=True)

    def test_release_when_acquisition_is_not_acknowledged(self):
        self.exercise(acquired=False)
