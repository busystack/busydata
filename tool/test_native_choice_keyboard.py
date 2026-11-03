import unittest

import test_native_fluent_focus_receipt as focus_fixture
from native_workbench_acceptance import open_native_choice_keyboard


class NativeChoiceKeyboardTest(unittest.TestCase):
    def fixture(self):
        model = focus_fixture.NativeFluentFocusReceiptTest().fixture()
        model.atspi.Role.PUSH_BUTTON = 'button'
        model.initial.role = model.replacement.role = 'button'
        model.initial.name = model.replacement.name = 'Ascending'
        model.menu.name = 'Sort table data'
        model.menu.role = 'panel'
        return model

    def open(self, model):
        return open_native_choice_keyboard(model.atspi, model.current_action,
            'Ascending', model.menu, model.wait, model.command)

    def test_refused_focus_is_reacquired_before_one_return_without_tapping(self):
        model = self.fixture()
        self.assertEqual(1, self.open(model))
        self.assertEqual(['focus-stale', 'focus-current', 'Return'], model.events)

    def test_changed_caption_role_or_modal_never_receives_return(self):
        for field, value in [('name', 'Other choice'), ('role', 'menu-item'), ('parent', None)]:
            with self.subTest(field=field):
                model = self.fixture()
                setattr(model.initial, field, value)
                with self.assertRaisesRegex(RuntimeError, 'destination changed'):
                    self.open(model)
                self.assertEqual([], model.events)

    def test_pending_focus_never_replays_or_sends_return(self):
        model = self.fixture()
        dispatch = model.atspi.Action.do_action
        def pending(item, index):
            result = dispatch(item, index)
            model.state['root_attributes']['busydata-action-status'] = 'pending'
            return result
        model.atspi.Action.do_action = pending
        with self.assertRaises(TimeoutError):
            self.open(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_owner_replacement_cannot_retarget_the_chooser(self):
        model = self.fixture()
        current = model.current_action
        def replaced():
            result = current()
            if model.events:
                model.menu.path = '/different-dialog'
            return result
        model.current_action = replaced
        with self.assertRaisesRegex(RuntimeError, 'destination changed'):
            self.open(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_focus_loss_before_keyboard_input_never_sends_return(self):
        model = self.fixture()
        dispatch = model.atspi.Action.do_action
        def change(item, index):
            result = dispatch(item, index)
            if item is model.replacement:
                reads = iter((True, False))
                from types import SimpleNamespace
                item.get_state_set = lambda: SimpleNamespace(contains=lambda _: next(reads))
            return result
        model.atspi.Action.do_action = change
        with self.assertRaisesRegex(RuntimeError, 'lost focus'):
            self.open(model)
        self.assertEqual(['focus-stale', 'focus-current'], model.events)
