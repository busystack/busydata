import types
import unittest
from unittest.mock import patch

from native_workbench_acceptance import select_native_document_tab


class NativeDocumentTabSelectionTest(unittest.TestCase):
    def fixture(self, *, select=True, remove=False, positions=None):
        class Node:
            def __init__(self, role, parent=None, box=None):
                self.role, self.parent, self.box = role, parent, box
                self.selected = False
            def clear_cache(self):
                pass
            def get_parent(self):
                return self.parent
            def get_role(self):
                return self.role
            def get_state_set(self):
                return types.SimpleNamespace(contains=lambda flag:
                    self.selected if flag == 'selected' else True)
        rectangle = lambda y: types.SimpleNamespace(x=20, y=y, width=200, height=40)
        frame = Node('frame', box=types.SimpleNamespace(x=0, y=0, width=1280, height=800))
        old, current = Node('button', frame, rectangle(30)), Node('button', frame, rectangle(30))
        state = {'node': old, 'geometryReads': 0}
        commands = []
        positions = iter(positions) if positions is not None else None
        def extents(item, _):
            if item is frame:
                return frame.box
            state['geometryReads'] += 1
            if positions is not None:
                item.box = rectangle(next(positions))
            return item.box
        def command(arguments):
            commands.append(arguments)
            current.selected = select
            old.selected = True
            state['node'] = None if remove else current
        def forbidden_semantic_action(*args):
            raise AssertionError('A captured semantic Tap must not replace the one current native pointer click')
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(FRAME='frame', MENU='menu'),
            CoordType=types.SimpleNamespace(SCREEN='screen'),
            StateType=types.SimpleNamespace(SELECTED='selected', SHOWING='showing'),
            Component=types.SimpleNamespace(get_extents=extents),
            Action=types.SimpleNamespace(do_action=forbidden_semantic_action))
        def wait(predicate):
            for _ in range(8):
                result = predicate()
                if result:
                    return result
            raise TimeoutError('Original native condition deadline')
        return types.SimpleNamespace(atspi=atspi, old=old, current=current, state=state,
            command=command, commands=commands, wait=wait,
            current_tab=lambda: state['node'])
    def select(self, model):
        with patch('native_workbench_acceptance.native_display_scale', return_value=2):
            return select_native_document_tab(model.atspi, model.current_tab, model.wait, model.command)
    def test_one_physical_click_and_current_replacement_selection(self):
        model = self.fixture()
        self.assertIs(self.select(model), model.current)
        self.assertEqual([['xdotool','mousemove','240','100','click','1']], model.commands)
        self.assertEqual(2, model.state['geometryReads'])
    def test_moving_geometry_requires_two_equal_current_observations(self):
        model = self.fixture(positions=[-40,10,30,30])
        self.assertIs(self.select(model), model.current)
        self.assertEqual([['xdotool','mousemove','240','100','click','1']], model.commands)
        self.assertEqual(4, model.state['geometryReads'])
    def test_offscreen_tab_never_receives_a_click(self):
        model = self.fixture(positions=[-40]*8)
        with self.assertRaises(TimeoutError):
            self.select(model)
        self.assertEqual([], model.commands)
    def test_removed_current_tab_does_not_acknowledge_with_old_selected_proxy(self):
        model = self.fixture(remove=True)
        with self.assertRaises(TimeoutError):
            self.select(model)
        self.assertEqual(1, len(model.commands))
    def test_selection_timeout_never_replays_pointer_input(self):
        model = self.fixture(select=False)
        with self.assertRaises(TimeoutError):
            self.select(model)
        self.assertEqual(1, len(model.commands))
    def test_owner_lookup_failure_prevents_input(self):
        model = self.fixture()
        def unavailable():
            raise RuntimeError('Current native owner changed')
        model.current_tab = unavailable
        with self.assertRaisesRegex(RuntimeError, 'owner changed'):
            self.select(model)
        self.assertEqual([], model.commands)


if __name__ == '__main__':
    unittest.main()
