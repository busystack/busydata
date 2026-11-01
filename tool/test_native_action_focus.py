import types
import unittest
from unittest.mock import patch

from native_workbench_acceptance import focused_native_action


class NativeActionFocusTest(unittest.TestCase):
    def test_focus_transition_requires_the_current_proxy_and_action_index(self):
        focused, reads, activations = set(), [], []

        def control(name):
            return types.SimpleNamespace(name=name, clear_cache=lambda: None,
                get_interfaces=lambda: [], get_state_set=lambda: types.SimpleNamespace(
                    contains=lambda flag: bool(focused)))

        before, after = control('before'), control('after')

        def grab(item):
            focused.add(item.name)
            return True

        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1),
            Component=types.SimpleNamespace(grab_focus=grab))

        def current():
            reads.append(bool(focused))
            return (after, 0) if focused else (before, 1)

        def wait(predicate):
            value = predicate()
            if not value:
                raise TimeoutError('Native focus not acknowledged')
            return value

        item, index = focused_native_action(atspi, current, wait)
        # The caller activates exactly once, using the post-focus lookup.
        activations.append((item.name, index))
        self.assertEqual([('after', 0)], activations)
        self.assertEqual([False, True], reads)

    def test_unavailable_or_unfocused_lookup_waits_without_replaying_focus(self):
        focused = {'initial': False, 'replacement': False}
        calls = []

        def node(name):
            return types.SimpleNamespace(clear_cache=lambda: None, get_interfaces=lambda: [],
                get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: focused[name]))

        initial, replacement = node('initial'), node('replacement')

        def grab(item):
            self.assertIs(initial, item)
            calls.append('focus')
            focused['initial'] = True
            return True

        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1),
            Component=types.SimpleNamespace(grab_focus=grab))
        lookups = iter(((initial, 1), None, (replacement, 0), (replacement, 0)))
        reads = []

        def current():
            value = next(lookups)
            reads.append(value)
            if len(reads) == 4:
                focused['replacement'] = True
            return value

        def wait(predicate):
            for _ in range(3):
                value = predicate()
                if value:
                    return value
            raise TimeoutError('Original native wait exhausted')

        self.assertEqual((replacement, 0), focused_native_action(atspi, current, wait))
        self.assertEqual(['focus'], calls)
        self.assertEqual(4, len(reads))

    def test_owner_failure_after_focus_propagates_without_using_old_action(self):
        initial = object()
        lookups = 0

        def current():
            nonlocal lookups
            lookups += 1
            if lookups == 1:
                return initial, 1
            raise ValueError('Current native owner changed')

        with patch('native_workbench_acceptance.focus_native_control') as focus:
            with self.assertRaisesRegex(ValueError, 'Current native owner changed'):
                focused_native_action(None, current, lambda predicate: predicate())
        focus.assert_called_once_with(None, initial, unittest.mock.ANY)
        self.assertEqual(2, lookups)

    def test_rejected_focus_never_reacquires_or_activates(self):
        initial = object()
        calls = []

        def current():
            calls.append('lookup')
            return initial, 1

        with patch('native_workbench_acceptance.focus_native_control',
                side_effect=RuntimeError('Native focus rejected')):
            with self.assertRaisesRegex(RuntimeError, 'Native focus rejected'):
                focused_native_action(None, current, lambda predicate: predicate())
        self.assertEqual(['lookup'], calls)

    def test_fresh_focus_timeout_does_not_fall_back_to_captured_action(self):
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: False))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1))

        def wait(predicate):
            value = predicate()
            if not value:
                raise TimeoutError('Original native wait exhausted')
            return value

        with patch('native_workbench_acceptance.focus_native_control') as focus:
            with self.assertRaisesRegex(TimeoutError, 'Original native wait exhausted'):
                focused_native_action(atspi, lambda: (item, 1), wait)
        focus.assert_called_once()


if __name__ == '__main__':
    unittest.main()
