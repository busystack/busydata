import unittest
import test_native_fluent_menu_keyboard as baseline


class NativeFluentFocusReceiptTest(unittest.TestCase):
    def fixture(self, change=None):
        model = baseline.NativeFluentMenuKeyboardTest().fixture()
        root = model.state['root_attributes']
        model.replacement.actions = ['focus', 'tap']

        def focus(item, index):
            self.assertEqual(index, 0)
            old_revision = int(root['busydata-revision'])
            root.update({'busydata-revision': str(old_revision + 2),
                'busydata-action-sequence': str(int(root['busydata-action-sequence']) + 1),
                'busydata-action-name': 'focus', 'busydata-action-status': 'stale',
                'busydata-action-request-revision': str(old_revision),
                'busydata-action-reply-revision': str(old_revision + 2)})
            if item is model.initial:
                model.events.append('focus-stale')
                model.nodes.remove(model.initial)
                model.nodes.append(model.replacement)
                model.state['current'] = model.replacement
                if change is not None:
                    change(model, root)
            else:
                self.assertIs(item, model.replacement)
                model.events.append('focus-current')
                root['busydata-action-status'] = 'ok'
                model.replacement.states.add('focused')
            return True

        model.atspi.Action.do_action = focus
        return model

    def activate(self, model):
        return baseline.NativeFluentMenuKeyboardTest().activate(model)

    def test_same_owner_stale_revision_reacquires_focus_then_returns_once(self):
        model = self.fixture()
        self.assertEqual(1, self.activate(model))
        self.assertEqual(['focus-stale', 'focus-current', 'Return'], model.events)

    def test_non_panel_ancestors_never_receive_snapshot_attribute_requests(self):
        model = self.fixture()
        def unsupported():
            raise AssertionError('Menu attributes are outside the owned receipt protocol')
        model.menu.get_attributes = unsupported
        self.assertEqual(1, self.activate(model))
        self.assertEqual(['focus-stale', 'focus-current', 'Return'], model.events)

    def test_pending_reply_does_not_read_the_menu_while_its_proxy_retires(self):
        model = self.fixture(lambda _, root: root.update({'busydata-action-status': 'pending'}))
        original = model.current_action
        def current_action():
            if model.events:
                raise AssertionError('Menu was read before its focus reply completed')
            return original()
        model.current_action = current_action
        with self.assertRaises(TimeoutError):
            self.activate(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_pending_focus_is_never_replayed(self):
        model = self.fixture(lambda _, root: root.update({'busydata-action-status': 'pending'}))
        with self.assertRaises(TimeoutError):
            self.activate(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_stale_focus_cannot_cross_application_owner_epoch(self):
        model = self.fixture(lambda _, root: root.update({'busydata-owner-epoch': '3'}))
        with self.assertRaisesRegex(RuntimeError, 'owner changed'):
            self.activate(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_menu_proxy_replacement_preserves_the_same_application_owner(self):
        model = self.fixture(lambda current, _: setattr(current.menu, 'path', '/org/a11y/atspi/accessible/replacement'))
        self.assertEqual(1, self.activate(model))
        self.assertEqual(['focus-stale', 'focus-current', 'Return'], model.events)

    def test_stale_focus_cannot_cross_application_root_identity(self):
        model = self.fixture(lambda current, _: setattr(current.frame, 'path', '/org/a11y/atspi/accessible/other'))
        with self.assertRaisesRegex(RuntimeError, 'owner changed'):
            self.activate(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_receipt_for_a_mutating_action_is_never_replayed(self):
        model = self.fixture(lambda _, root: root.update({'busydata-action-name': 'tap'}))
        with self.assertRaisesRegex(RuntimeError, 'intervening'):
            self.activate(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_intervening_action_sequence_is_never_replayed(self):
        model = self.fixture(lambda _, root: root.update({'busydata-action-sequence': str(int(root['busydata-action-sequence']) + 1)}))
        with self.assertRaisesRegex(RuntimeError, 'intervening'):
            self.activate(model)
        self.assertEqual(['focus-stale'], model.events)

    def test_stale_without_same_owner_revision_progress_is_not_retryable(self):
        model = self.fixture(lambda _, root: root.update({'busydata-action-reply-revision': root['busydata-action-request-revision']}))
        with self.assertRaisesRegex(RuntimeError, 'revision refusal'):
            self.activate(model)
        self.assertEqual(['focus-stale'], model.events)


if __name__ == '__main__':
    unittest.main()
