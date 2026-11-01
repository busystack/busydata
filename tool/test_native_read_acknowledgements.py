"""Complete post-action observations are required; inputs are never replayed."""
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

from native_workbench_acceptance import (dispatch_native_activation,
    fresh_accessible_objects, record_native_modal_read_unavailable,
    wait_native_modal_retired)
from verify_native_accessibility import native_wait


class NativeReadFailure(Exception):
    def __init__(self, domain='atspi_error', code=1):
        super().__init__('Private native text must not enter read diagnostics')
        self.domain, self.code = domain, code


class ReadNode:
    def __init__(self, children=(), *, failure=None, failures=0, on_last_failure=None):
        self.children, self.failure, self.failures = list(children), failure, failures
        self.on_last_failure, self.reads = on_last_failure, 0

    def clear_cache(self): pass

    def get_child_count(self):
        self.reads += 1
        if self.failures:
            if self.failures > 0:
                self.failures -= 1
            if self.failures == 0 and self.on_last_failure is not None:
                self.on_last_failure()
            raise self.failure
        return len(self.children)

    def get_child_at_index(self, index): return self.children[index]


class NativeReadAcknowledgementTest(unittest.TestCase):
    def wait_for_retirement(self, modal, application, report, clock):
        context = types.SimpleNamespace(pending=lambda: False,
            iteration=lambda blocking: self.fail('No pending native event'))
        with tempfile.TemporaryDirectory() as directory, \
                patch('verify_native_accessibility.time.monotonic', side_effect=lambda: clock[0]), \
                patch('verify_native_accessibility.time.sleep', side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)):
            return wait_native_modal_retired(modal,
                lambda: fresh_accessible_objects(application, transient_errors=(NativeReadFailure,)),
                lambda predicate: native_wait(predicate, context, Path(directory) / 'reader.log', .15),
                on_unavailable=lambda error: record_native_modal_read_unavailable(report, 'Connect', error))

    def test_acknowledged_connect_is_not_replayed_after_unavailable_child_counts(self):
        failure, actions, report, clock = NativeReadFailure(), [], {}, [0.0]
        application = ReadNode()
        modal = ReadNode(failure=failure, failures=3,
            on_last_failure=lambda: application.children.clear())
        application.children = [modal]
        connect = types.SimpleNamespace(get_role=lambda: 'button')
        def dispatch(item, index):
            self.assertIs(connect, item)
            self.assertEqual(0, index)
            actions.append('Connect')
            return True
        atspi = types.SimpleNamespace(Action=types.SimpleNamespace(do_action=dispatch))
        self.assertEqual('button', dispatch_native_activation(atspi, connect, 0))
        self.assertTrue(self.wait_for_retirement(modal, application, report, clock))
        self.assertEqual(['Connect'], actions)
        self.assertEqual(3, modal.reads)
        self.assertGreaterEqual(application.reads, 4)
        self.assertEqual({'domain': 'atspi_error', 'code': 1},
            report['nativeModalReadDiagnostics']['lastUnavailableTransport'])
        self.assertEqual(1, report['nativeModalReadDiagnostics']['unavailableWholeTreeReads'])
        self.assertNotIn(str(failure), json.dumps(report))

    def test_permanent_transport_unavailability_fails_at_original_acknowledgement_deadline(self):
        modal = ReadNode(failure=NativeReadFailure(), failures=-1)
        report, clock = {}, [0.0]
        with self.assertRaisesRegex(TimeoutError, '^Native acceptance condition deadline$'):
            self.wait_for_retirement(modal, ReadNode([modal]), report, clock)
        self.assertGreaterEqual(clock[0], .15)
        self.assertLess(clock[0], .19)
        self.assertGreater(report['nativeModalReadDiagnostics']['unavailableWholeTreeReads'], 1)

    def test_complete_tree_still_containing_modal_cannot_prove_dismissal(self):
        modal = ReadNode(failure=NativeReadFailure(), failures=3)
        report, clock = {}, [0.0]
        with self.assertRaisesRegex(TimeoutError, '^Native acceptance condition deadline$'):
            self.wait_for_retirement(modal, ReadNode([modal]), report, clock)
        self.assertGreaterEqual(clock[0], .15)
        self.assertLess(clock[0], .19)
        self.assertEqual(1, report['nativeModalReadDiagnostics']['unavailableWholeTreeReads'])

    def test_other_native_error_domains_and_codes_are_preserved(self):
        for domain, code in [('atspi_error', 2), ('g-io-error-quark', 1)]:
            with self.subTest(domain=domain, code=code):
                failure, report, clock = NativeReadFailure(domain, code), {}, [0.0]
                modal = ReadNode(failure=failure, failures=-1)
                with self.assertRaises(NativeReadFailure) as raised:
                    self.wait_for_retirement(modal, ReadNode([modal]), report, clock)
                self.assertIs(failure, raised.exception)
                self.assertEqual(0, clock[0])
                self.assertEqual({}, report)

    def test_read_diagnostics_have_explicit_limits_and_no_error_messages(self):
        error = RuntimeError('Private snapshot contents')
        error.__cause__ = NativeReadFailure()
        report = {'nativeModalReadDiagnostics': {
            'unavailableWholeTreeReads': 9999, 'countLimited': False}}
        record_native_modal_read_unavailable(report, 'Connect', error)
        self.assertEqual(10000, report['nativeModalReadDiagnostics']['unavailableWholeTreeReads'])
        self.assertFalse(report['nativeModalReadDiagnostics']['countLimited'])
        record_native_modal_read_unavailable(report, 'Close', error)
        self.assertEqual(10000, report['nativeModalReadDiagnostics']['unavailableWholeTreeReads'])
        self.assertTrue(report['nativeModalReadDiagnostics']['countLimited'])
        self.assertNotIn('Private', json.dumps(report))
        with self.assertRaises(ValueError):
            record_native_modal_read_unavailable(report, 'Unverified action', error)


if __name__ == '__main__': unittest.main()
