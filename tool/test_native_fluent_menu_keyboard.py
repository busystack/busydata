import types
import unittest

import test_native_acceptance
from native_workbench_acceptance import activate_fluent_menu_keyboard


class NativeFluentMenuKeyboardTest(unittest.TestCase):
    def fixture(self, *, current_focused=True, retires=True):
        atspi, _, _, frame, Node = test_native_acceptance.NativeAcceptanceTest().protected_field_fixture()
        atspi.Role.MENU = 'menu'
        menu = Node('menu', (10, 20, 180, 120), frame)
        initial = Node('menu-item', (10, 30, 160, 24), menu,
            actions=['focus', 'tap'], name='Edit complete value')
        replacement = Node('menu-item', (10, 30, 160, 24), menu,
            actions=['tap'], name=initial.name)
        nodes, events = [frame, menu, initial], []
        state = {'current': initial, 'after_focus': None, 'missing_reads': 0}

        def focus(item, index):
            self.assertIs(initial, item)
            self.assertEqual(0, index)
            events.append('focus')
            initial.states.add('focused')
            if current_focused:
                replacement.states.add('focused')
            nodes.remove(initial)
            nodes.append(replacement)
            state['current'] = replacement
            if state['after_focus'] is not None:
                state['after_focus']()
            return True

        atspi.Action.do_action = focus

        def current_action():
            if state['current'] is replacement and state['missing_reads']:
                state['missing_reads'] -= 1
                return None
            item = state['current']
            return item, 0 if item is replacement else 1, item.actions

        def wait(predicate):
            for _ in range(4):
                value = predicate()
                if value:
                    return value
            raise TimeoutError('Original native wait exhausted')

        def command(arguments):
            self.assertEqual(['xdotool', 'key', '--clearmodifiers', 'Return'], arguments)
            self.assertIs(replacement, state['current'])
            self.assertIn('focused', replacement.states)
            events.append('Return')
            if retires:
                nodes[:] = [frame]

        return types.SimpleNamespace(atspi=atspi, initial=initial, replacement=replacement,
            frame=frame, menu=menu, nodes=nodes, events=events, state=state,
            current_action=current_action, wait=wait, command=command)

    def activate(self, fixture):
        activate_fluent_menu_keyboard(fixture.atspi, fixture.current_action,
            'Edit complete value', 'menu-item', fixture.wait, fixture.command,
            lambda: fixture.menu not in fixture.nodes)

    def test_reacquires_after_focus_retires_the_proxy_and_sends_one_return(self):
        fixture = self.fixture()
        fixture.state['missing_reads'] = 2
        self.activate(fixture)
        self.assertEqual(['focus', 'Return'], fixture.events)
        self.assertEqual([fixture.frame], fixture.nodes)

    def test_changed_caption_role_or_menu_owner_never_receives_return(self):
        for field, value in (('name', 'Other command'), ('role', 'button'), ('parent', None)):
            with self.subTest(field=field):
                fixture = self.fixture()
                fixture.state['after_focus'] = lambda: setattr(fixture.replacement, field, value)
                with self.assertRaisesRegex(RuntimeError, 'destination changed'):
                    self.activate(fixture)
                self.assertEqual(['focus'], fixture.events)

    def test_current_proxy_must_acknowledge_actual_focus(self):
        fixture = self.fixture(current_focused=False)
        with self.assertRaises(TimeoutError):
            self.activate(fixture)
        self.assertEqual(['focus'], fixture.events)

    def test_rejected_focus_never_sends_return_or_retries(self):
        fixture = self.fixture()

        def reject(*_):
            fixture.events.append('rejected focus')
            return False

        fixture.atspi.Action.do_action = reject
        with self.assertRaisesRegex(RuntimeError, 'Focus action rejected'):
            self.activate(fixture)
        self.assertEqual(['rejected focus'], fixture.events)

    def test_focus_lost_before_the_key_never_activates(self):
        fixture = self.fixture()
        observations = iter((True, False))

        def state_set():
            focused = next(observations)
            return types.SimpleNamespace(contains=lambda _: focused)

        fixture.replacement.get_state_set = state_set
        with self.assertRaisesRegex(RuntimeError, 'lost focus'):
            self.activate(fixture)
        self.assertEqual(['focus'], fixture.events)

    def test_retirement_timeout_never_replays_the_return(self):
        fixture = self.fixture(retires=False)
        with self.assertRaises(TimeoutError):
            self.activate(fixture)
        self.assertEqual(['focus', 'Return'], fixture.events)

    def test_post_focus_lookup_failure_never_reuses_the_old_action(self):
        fixture = self.fixture()
        before = fixture.current_action

        def current_action():
            if fixture.state['current'] is fixture.replacement:
                raise ValueError('Current owner unavailable')
            return before()

        fixture.current_action = current_action
        with self.assertRaisesRegex(ValueError, 'owner unavailable'):
            self.activate(fixture)
        self.assertEqual(['focus'], fixture.events)


if __name__ == '__main__':
    unittest.main()
