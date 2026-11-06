import unittest

import test_native_fluent_focus_receipt as baseline
from native_workbench_acceptance import clear_native_search


class NativeSearchClearReceiptTest(unittest.TestCase):
    def fixture(self, change=None, *, reject_clear=False):
        model = baseline.NativeFluentFocusReceiptTest().fixture(change)
        for item in (model.initial, model.replacement):
            item.parent = model.frame
            item.role = 'push-button'
            item.name = 'Clear search'
        model.initial.actions = ['focus', 'tap']
        model.replacement.actions = ['focus', 'unrelated', 'tap']
        model.nodes.remove(model.menu)
        focus = model.atspi.Action.do_action

        def dispatch(item, index):
            if item.actions[index] == 'tap':
                self.assertIs(item, model.replacement)
                self.assertIn('focused', item.states)
                self.assertEqual(2, index)
                model.events.append('clear')
                return not reject_clear
            return focus(item, index)

        model.atspi.Action.do_action = dispatch

        def current_clear():
            value = model.current_action()
            if value is None:
                return None
            item = value[0]
            return item, item.actions.index('tap')

        model.current_clear = current_clear
        return model

    def clear(self, model):
        return clear_native_search(model.atspi, model.current_clear, model.wait)

    def test_stale_focus_reacquires_current_clear_proxy_and_action_once(self):
        model = self.fixture()
        self.assertEqual(('Clear search', 1), self.clear(model))
        self.assertEqual(['focus-stale', 'focus-current', 'clear'], model.events)

    def test_pending_focus_is_not_replayed_or_cleared(self):
        model = self.fixture(lambda _, root: root.update(
            {'busydata-action-status': 'pending'}))
        with self.assertRaises(TimeoutError):
            self.clear(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_stale_focus_cannot_cross_application_owner_epoch(self):
        model = self.fixture(lambda _, root: root.update(
            {'busydata-owner-epoch': '3'}))
        with self.assertRaisesRegex(RuntimeError, 'owner changed'):
            self.clear(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_intervening_mutation_is_not_replayed(self):
        model = self.fixture(lambda _, root: root.update(
            {'busydata-action-name': 'tap'}))
        with self.assertRaisesRegex(RuntimeError, 'intervening'):
            self.clear(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_missing_current_clear_never_reuses_the_old_proxy(self):
        model = self.fixture()
        current = model.current_clear
        model.current_clear = lambda: current() if not model.events else None
        with self.assertRaises(TimeoutError):
            self.clear(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_rejected_clear_is_attempted_once(self):
        model = self.fixture(reject_clear=True)
        with self.assertRaisesRegex(RuntimeError, 'clear action rejected'):
            self.clear(model)
        self.assertEqual(['focus-stale', 'focus-current', 'clear'], model.events)


if __name__ == '__main__':
    unittest.main()
