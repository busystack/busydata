import unittest

import test_native_acceptance
from native_workbench_acceptance import (
    assert_native_command_disabled, assert_visible_protected_password,
    find_live_activation, request_native_focus,
)


class NativeBridgeActionsTest(unittest.TestCase):
    def fixture(self):
        return test_native_acceptance.NativeAcceptanceTest().protected_field_fixture()

    def test_owned_tap_activates_only_exact_visible_enabled_owner(self):
        atspi, _, _, frame, Node = self.fixture()
        atspi.Role.MENU_ITEM = 'menu-item'
        node = Node('button', (1, 1, 30, 30), frame, ['focus', 'tap'], 'Apply')
        result = find_live_activation(atspi, [node], 'Apply')
        self.assertIs(node, result[0])
        self.assertEqual(1, result[1])
        for state in ('showing', 'sensitive'):
            node.states.remove(state)
            self.assertIsNone(find_live_activation(atspi, [node], 'Apply'))
            node.states.add(state)
        self.assertIsNone(find_live_activation(atspi, [node], 'Apply other owner'))
        node.actions = ['focus']
        self.assertIsNone(find_live_activation(atspi, [node], 'Apply'))
        node.actions = ['TAP']
        self.assertIsNone(find_live_activation(atspi, [node], 'Apply'))

    def test_disabled_owned_tap_cannot_escape_safety_check(self):
        atspi, _, _, frame, Node = self.fixture()
        atspi.StateType.ENABLED = 'enabled'
        node = Node('button', (1, 1, 30, 30), frame, ['focus', 'tap'], 'Run')
        with self.assertRaisesRegex(RuntimeError, 'exposes activation'):
            assert_native_command_disabled(atspi, node)
        node.actions = ['focus']
        self.assertFalse(assert_native_command_disabled(atspi, node)['activationAvailable'])

    def test_owned_focus_dispatches_focus_once_and_rejects_ambiguity(self):
        atspi, _, _, frame, Node = self.fixture()
        node = Node('button', (1, 1, 30, 30), frame, ['tap', 'focus'])
        calls = []
        atspi.Action.do_action = lambda item, index: calls.append((item, index)) or True
        atspi.Component.grab_focus = lambda item: self.fail('Explicit focus must own dispatch')
        self.assertTrue(request_native_focus(atspi, node))
        self.assertEqual([(node, 1)], calls)
        node.actions = ['focus', 'Focus']
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            request_native_focus(atspi, node)
        self.assertEqual([(node, 1)], calls)

    def test_owned_scroll_vocabulary_still_requires_full_password_containment(self):
        atspi, field, viewport, _, _ = self.fixture()
        viewport.actions = ['scrollUp', 'scrollDown']
        self.assertEqual([[345, 200, 600, 380]],
                         assert_visible_protected_password(atspi, field)['scrollViewportBounds'])
        field.bounds = (345, 530, 600, 59)
        with self.assertRaisesRegex(RuntimeError, 'offscreen or clipped'):
            assert_visible_protected_password(atspi, field)


if __name__ == '__main__':
    unittest.main()
