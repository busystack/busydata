import hashlib
import fnmatch
import json
import os
from pathlib import Path
import runpy
import subprocess
import socket
import tempfile
import tarfile
import threading
import types
import unittest
from unittest.mock import patch, Mock

from desktop_build_evidence import verify_existing_bundle
from public_bundle_permissions import publish_public_bundle
import build_snap_acceptance
from verify_native_accessibility import configure_reader_receipts, NativeProgressReport, native_speech_ready, native_reader_ready, native_wait
from verify_native_accessibility import catalog_fixture_rows_match
from verify_native_accessibility import native_report_name
from verify_native_accessibility import native_speech_contains
from verify_native_accessibility import native_failure_structure
from verify_native_accessibility import native_ime_composition_active
from native_workbench_acceptance import scoped_grid_menu_caption, native_catalog_labels, palette_rows_ready, source_row_value_label, bounded_native_text, native_tab_name, normalized_native_label, focus_native_control, control_key_until, fresh_accessible_objects, find_live_control, find_live_activation, accessible_ancestors, assert_modal_keyboard_focus, assert_visible_protected_password, focus_profile_password, NativeModalFocusPending, wait_modal_keyboard_focus
from native_workbench_acceptance import wait_native_field_value, native_close_review_label, find_native_close_review, native_catalog_message, native_catalog_text
from native_platform_matrix import CASES, validate_composed_settings
from native_fluent_rendering import validate_composition
from native_workbench_acceptance import assert_native_command_disabled
from native_workbench_acceptance import find_grid_menu_destination, find_execution_output_menu, execution_menu_dismissed
from native_workbench_acceptance import activate_grid_menu_keyboard
from native_workbench_acceptance import find_native_tree_row, native_tree_row_identity, read_native_snapshot, wait_native_inventory, native_tree_navigation_step, native_tree_movement
from native_workbench_acceptance import visible_object_definition
from native_workbench_acceptance import assert_current_grid_owner
from native_workbench_acceptance import native_label_patterns
from native_workbench_acceptance import physical_window_picture
from native_workbench_acceptance import owned_product_window, find_query_tab_activation, native_query_identity, native_tab_has_status, request_owned_x11_window_close
from native_workbench_acceptance import focus_live_native_control, focus_visible_native_field, wait_native_control_visible
from native_workbench_acceptance import native_connection_page_marker
from native_workbench_acceptance import request_native_focus
from native_workbench_acceptance import find_selected_value_control
from native_workbench_acceptance import find_metadata_section_control
from native_workbench_acceptance import paste_native_picker_path
from native_workbench_acceptance import send_native_keycodes
from verify_native_accessibility import catalog_page_scripts
from native_workbench_acceptance import set_native_inline_text, native_readonly_sql_preview
from native_workbench_acceptance import visible_native_bounds
from native_workbench_acceptance import verify_native_sql_lines
from native_workbench_acceptance import wait_native_owned_session_nodes
from native_workbench_acceptance import pointer_at_native_bounds
from native_workbench_acceptance import right_click_native_row
from native_workbench_acceptance import find_new_menu_activation, find_new_selected_query, find_selected_object_document, NativeSnapshotIncomplete, NativeNodeBudgetExceeded
from native_workbench_acceptance import find_visible_grid_cell, find_keyed_grid_cell, wait_native_menu_retired
from native_workbench_acceptance import native_sql_editor_label, native_sql_editor_announcement
from native_workbench_acceptance import verify_multicaret
from native_workbench_acceptance import native_control_absent, find_live_sql_editor, native_startup_editor_state, read_live_native_controls, native_caption_presence, restored_native_sql_editor, native_sql_editor_origin
from native_workbench_acceptance import reveal_native_choice_with_keyboard
from native_workbench_acceptance import native_observe_any, native_observe_none, native_observe_first, native_complete_observation
from native_workbench_acceptance import native_palette_sql_checkpoint, paste_native_palette_command
from native_workbench_acceptance import native_result_cell_identity, native_grid_generation, replaced_native_grid_generation
from native_workbench_acceptance import native_physical_session_identity, native_fresh_browse_generation, native_previous_browse_generation
from native_workbench_acceptance import native_catalog_message, native_control_label
from native_workbench_acceptance import dispatch_native_activation, wait_native_modal_retired
from native_database_explorer_tools import object_fixture_sql


class NativeAcceptanceTest(unittest.TestCase):
    def x11_close_fixture(self, *, protocols=(101,), advertised=True, sent=True):
        import ctypes
        x11 = Mock()
        x11.XOpenDisplay.return_value = 42
        x11.XInternAtom.side_effect = lambda display, name, exists: {
            b'WM_PROTOCOLS': 100, b'WM_DELETE_WINDOW': 101}[name]
        buffer = (ctypes.c_ulong * len(protocols))(*protocols)
        def get_protocols(display, window, output, count):
            ctypes.cast(output, ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)))[0] = ctypes.cast(buffer, ctypes.POINTER(ctypes.c_ulong))
            count._obj.value = len(protocols)
            return advertised
        x11.XGetWMProtocols.side_effect = get_protocols
        received = []
        def send(display, window, propagate, mask, pointer):
            event = pointer._obj.client
            received.append((display, window, propagate, mask, event.type, event.window,
                event.message_type, event.format, list(event.data.l)))
            return sent
        x11.XSendEvent.side_effect = send
        command = Mock(return_value=types.SimpleNamespace(stdout='8123\n'))
        return x11, command, received

    def test_os_close_sends_one_advertised_public_wm_delete_to_exact_owned_window(self):
        x11, command, received = self.x11_close_fixture()
        with patch('ctypes.CDLL', return_value=x11):
            request_owned_x11_window_close(command, '314', 8123)
        command.assert_called_once_with(['xdotool', 'getwindowpid', '314'], capture_output=True, text=True)
        self.assertEqual([(42, 314, False, 0, 33, 314, 100, 32, [101, 0, 0, 0, 0])], received)
        x11.XGetWMProtocols.assert_called_once()
        x11.XFree.assert_called_once()
        x11.XFlush.assert_called_once_with(42)
        x11.XCloseDisplay.assert_called_once_with(42)
        x11.XDestroyWindow.assert_not_called()
        x11.XKillClient.assert_not_called()

    def test_os_close_rejects_foreign_window_or_malformed_identity_before_opening_display(self):
        for window, pid, actual in [('314', 8123, '9999'), ('0', 8123, '8123'),
                                    ('-314', 8123, '8123'), ('314', True, '1'),
                                    (str(2 ** 32), 8123, '8123')]:
            with self.subTest(window=window, pid=pid):
                command = Mock(return_value=types.SimpleNamespace(stdout=actual))
                with patch('ctypes.CDLL') as load, self.assertRaises((ValueError, RuntimeError)):
                    request_owned_x11_window_close(command, window, pid)
                load.assert_not_called()

    def test_os_close_requires_bounded_advertised_protocol_and_never_retries_rejected_send(self):
        for options, sends in (({'protocols': (99,)}, 0), ({'protocols': ()}, 0),
                               ({'protocols': (101,) * 65}, 0), ({'advertised': False}, 0),
                               ({'sent': False}, 1)):
            with self.subTest(options=options):
                x11, command, received = self.x11_close_fixture(**options)
                with patch('ctypes.CDLL', return_value=x11), self.assertRaises(RuntimeError):
                    request_owned_x11_window_close(command, '314', 8123)
                self.assertEqual(sends, len(received))
                x11.XCloseDisplay.assert_called_once_with(42)
                x11.XDestroyWindow.assert_not_called()
                x11.XKillClient.assert_not_called()
                x11.XFlush.assert_not_called()

    def test_activation_captures_role_before_single_dispatch_retires_control(self):
        events = []
        def role():
            if 'dispatch' in events:
                raise RuntimeError('Retired native control')
            events.append('role')
            return 'button'
        item = types.SimpleNamespace(get_role=role)
        def dispatch(node, index):
            self.assertIs(item, node)
            self.assertEqual(2, index)
            events.append('dispatch')
            return True
        atspi = types.SimpleNamespace(Action=types.SimpleNamespace(do_action=dispatch))
        self.assertEqual('button', dispatch_native_activation(atspi, item, 2))
        self.assertEqual(['role', 'dispatch'], events)

    def test_activation_role_failure_never_dispatches_or_retries(self):
        dispatched = []
        def role(): raise ValueError('Current native getter failed')
        item = types.SimpleNamespace(get_role=role)
        atspi = types.SimpleNamespace(Action=types.SimpleNamespace(
            do_action=lambda *_: dispatched.append(True)))
        with self.assertRaisesRegex(ValueError, 'getter failed'):
            dispatch_native_activation(atspi, item, 0)
        self.assertEqual([], dispatched)

    def test_activation_rejection_and_transport_failure_propagate_once(self):
        for transport_failure in (False, True):
            with self.subTest(transport_failure=transport_failure):
                dispatched = []
                item = types.SimpleNamespace(get_role=lambda: 'button')
                def dispatch(*_):
                    dispatched.append(True)
                    if transport_failure:
                        raise ValueError('Native action transport failed')
                    return False
                atspi = types.SimpleNamespace(Action=types.SimpleNamespace(do_action=dispatch))
                with self.assertRaises(ValueError if transport_failure else RuntimeError):
                    dispatch_native_activation(atspi, item, 0)
                self.assertEqual([True], dispatched)

    def native_retired_observation_fixture(self):
        failure = RuntimeError('Native node retired during observation')
        failure.domain, failure.code = 'atspi_error', 1
        def retired_name(): raise failure
        old = types.SimpleNamespace(get_name=retired_name)
        row = types.SimpleNamespace(get_name=lambda: 'Row 1, n: 漢😀')
        return old, row, failure

    def test_complete_review_verdict_waits_on_retirement_and_preserves_false_before_one_action(self):
        old, row, failure = self.native_retired_observation_fixture()
        review = types.SimpleNamespace(get_name=lambda: 'Review details')
        actions = []
        def observe(nodes, fresh):
            return native_complete_observation(native_observe_any(nodes,
                lambda node: node.get_name() == 'Review details', lambda: fresh))
        pending = observe([review, old], [review])
        self.assertIsNone(pending)  # A prior match cannot hide an incomplete scan.
        self.assertEqual([], actions)
        absent = observe([row], [row])
        self.assertEqual((False,), absent)
        self.assertTrue(absent)  # The bounded wait completes on a proved false.
        if absent[0]: actions.append('Run')
        self.assertEqual([], actions)
        present = observe([review], [review])
        self.assertEqual((True,), present)
        if present[0]: actions.append('Run')
        self.assertEqual(['Run'], actions)
        with self.assertRaises(RuntimeError) as raised:
            observe([old], [old])
        self.assertIs(failure, raised.exception)
        self.assertEqual(['Run'], actions)  # No action is replayed after a getter error.

    def test_complete_snapshot_wrapper_never_publishes_partial_evidence_and_keeps_empty_baselines(self):
        old, row, _ = self.native_retired_observation_fixture()
        evidence = ['previous-complete-record']
        partial = native_complete_observation(read_live_native_controls([row, old],
            lambda node: node.get_name(), lambda: [row]))
        if partial is not None:
            evidence = partial[0]
        self.assertIsNone(partial)
        self.assertEqual(['previous-complete-record'], evidence)
        empty = native_complete_observation(read_live_native_controls([], lambda _: self.fail('No node'), lambda: []))
        self.assertEqual(([],), empty)
        self.assertTrue(empty)
        evidence = empty[0]
        self.assertEqual([], evidence)
        complete = native_complete_observation(read_live_native_controls([row],
            lambda node: node.get_name(), lambda: [row]))
        self.assertEqual((['Row 1, n: 漢😀'],), complete)

    def test_inventory_baseline_waits_for_complete_reads_before_one_new_query(self):
        old, row, _ = self.native_retired_observation_fixture()
        snapshots = iter([[old, row], [row], [row]])
        actions = []
        def wait(predicate):
            self.assertIsNone(predicate())
            self.assertEqual(actions, [])
            return predicate()
        values = wait_native_inventory(lambda: next(snapshots),
            lambda node: node.get_name(), wait)
        self.assertEqual(values, ['Row 1, n: 漢😀'])
        actions.append('New query')
        self.assertEqual(actions, ['New query'])

    def test_inventory_baseline_distinguishes_incomplete_edges_from_complete_empty(self):
        snapshots = iter([NativeSnapshotIncomplete('missing child'), []])
        def current():
            value = next(snapshots)
            if isinstance(value, Exception): raise value
            return value
        def wait(predicate):
            self.assertIsNone(predicate())
            return predicate()
        self.assertEqual(wait_native_inventory(current,
            lambda node: self.fail('Empty snapshot has no node'), wait), [])
        failure = ValueError('Invalid owner')
        with self.assertRaises(ValueError) as raised:
            wait_native_inventory(lambda: [], lambda node: None,
                Mock(side_effect=failure))
        self.assertIs(raised.exception, failure)

    def test_inventory_baseline_keeps_the_existing_deadline_without_dispatch(self):
        clock, actions = [0.0], []
        context = types.SimpleNamespace(pending=lambda: False, iteration=Mock())
        def incomplete(): raise NativeSnapshotIncomplete('missing child')
        with tempfile.TemporaryDirectory() as directory, \
                patch('verify_native_accessibility.time.monotonic', side_effect=lambda: clock[0]), \
                patch('verify_native_accessibility.time.sleep', side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)):
            with self.assertRaisesRegex(TimeoutError, '^Native acceptance condition deadline$'):
                wait_native_inventory(incomplete, lambda node: node,
                    lambda predicate: native_wait(predicate, context,
                        Path(directory) / 'reader.log', .1))
                actions.append('New query')
        self.assertEqual(actions, [])
        self.assertAlmostEqual(clock[0], .12)

    def test_live_row_observation_is_pending_for_retirement_before_or_after_match(self):
        old, row, _ = self.native_retired_observation_fixture()
        for nodes in ([old, row], [row, old]):
            with self.subTest(retiredFirst=nodes[0] is old):
                self.assertIsNone(native_observe_any(nodes,
                    lambda node: node.get_name() == 'Row 1, n: 漢😀', current_nodes=lambda: [row]))
                self.assertIsNone(native_observe_none(nodes,
                    lambda node: node.get_name() == 'No row', current_nodes=lambda: [row]))
        self.assertIs(True, native_observe_any([row], lambda node: node.get_name().startswith('Row 1,'), lambda: [row]))
        self.assertIs(False, native_observe_none([row], lambda node: node.get_name().startswith('Row 1,'), lambda: [row]))
        self.assertIs(True, native_observe_none([], lambda _: self.fail('Empty observation has no node'), lambda: []))

    def test_first_observation_preserves_matched_false_zero_and_none_without_selecting_later(self):
        for expected in (False, 0, None):
            with self.subTest(value=expected):
                nodes = ['unmatched', 'first-match', 'later-match']
                result = native_observe_first(nodes,
                    lambda node: (False, 'ignored') if node == 'unmatched' else
                        (True, expected if node == 'first-match' else 'must-not-be-selected'),
                    current_nodes=lambda: nodes)
                self.assertIs(expected, result)
        old, row, _ = self.native_retired_observation_fixture()
        self.assertIsNone(native_observe_first([row, old],
            lambda node: (True, node.get_name()), current_nodes=lambda: [row]))

    def test_observation_reducers_preserve_live_transport_and_fresh_tree_failures(self):
        old, row, failure = self.native_retired_observation_fixture()
        for domain, code, fresh in (('atspi_error', 1, [old, row]),
                                    ('atspi_error', 0, []), ('g-io-error-quark', 1, [])):
            failure.domain, failure.code = domain, code
            for reducer in (native_observe_any, native_observe_none, native_observe_first):
                with self.subTest(reducer=reducer.__name__, domain=domain, code=code), self.assertRaises(RuntimeError) as raised:
                    reducer([old], lambda node: node.get_name(), current_nodes=lambda: fresh)
                self.assertIs(failure, raised.exception)
        failure.domain, failure.code = 'atspi_error', 1
        def failed_snapshot(): raise ValueError('Whole current application snapshot failed')
        with self.assertRaisesRegex(ValueError, 'Whole current application snapshot failed'):
            native_observe_any([old], lambda node: node.get_name(), failed_snapshot)

    def test_native_action_postmatch_retirement_is_pending_without_dispatch(self):
        atspi, _, _, frame, Node = self.protected_field_fixture()
        old, row, failure = self.native_retired_observation_fixture()
        button = Node('button', (0, 0, 100, 30), frame, ['tap'], 'Run')
        button.get_state_set = lambda: (_ for _ in ()).throw(failure)
        self.assertFalse(native_control_absent(atspi, [button], 'Run', 'Action',
            current_nodes=lambda: [row]))
        with self.assertRaises(RuntimeError):
            find_live_activation(atspi, [button], 'Run', current_nodes=lambda: [button])
        button = Node('button', (0, 0, 100, 30), frame, ['tap'], 'Run')
        calls = []
        def action_count(node):
            calls.append(node)
            if len(calls) == 2: raise failure
            return 1
        atspi.Action.get_n_actions = action_count
        atspi.Action.do_action = lambda *_: self.fail('Observation must not dispatch an action')
        self.assertIsNone(find_live_activation(atspi, [button], 'Run', current_nodes=lambda: [row]))
        self.assertEqual(2, len(calls))

    def test_complete_value_observation_waits_for_count_or_text_retirement_only(self):
        from native_result_editor_acceptance import native_complete_value_matches
        old, row, failure = self.native_retired_observation_fixture()
        for failed_getter in ('count', 'text'):
            with self.subTest(getter=failed_getter):
                def count(_):
                    if failed_getter == 'count': raise failure
                    return 2
                def text(*_): raise failure
                atspi = types.SimpleNamespace(Text=types.SimpleNamespace(
                    get_character_count=count, get_text=text))
                observation = {}
                self.assertIsNone(native_complete_value_matches(atspi, lambda: old,
                    '漢😀', observation, current_nodes=lambda: [row]))
                self.assertEqual({}, observation)
                with self.assertRaises(RuntimeError) as raised:
                    native_complete_value_matches(atspi, lambda: old, '漢😀', observation,
                        current_nodes=lambda: [old])
                self.assertIs(failure, raised.exception)

    def test_complete_value_observation_preserves_modal_owner_rejection(self):
        from native_result_editor_acceptance import native_complete_value_matches
        old, row, failure = self.native_retired_observation_fixture()
        def rejected_owner(): raise failure
        with self.assertRaises(RuntimeError) as raised:
            native_complete_value_matches(None, rejected_owner, '漢😀', {}, current_nodes=lambda: [row])
        self.assertIs(failure, raised.exception)
    def native_choice_keyboard_fixture(self, *, wrong_caption=False, failure=None, named_dialog=False):
        atspi, anchor, viewport, frame, Node = self.protected_field_fixture()
        atspi.Role.DIALOG = 'dialog'
        atspi.CoordType.SCREEN = 'screen'
        route = Node('panel', (0, 0, 1280, 720), frame,
                     name='' if named_dialog else 'Data Sources and Drivers')
        dialog = Node('dialog', route.bounds, route,
                      name='Data Sources and Drivers' if named_dialog else '')
        if failure == 'title': route.name = 'Another manager'
        viewport.parent = dialog
        anchor.role, anchor.name, anchor.actions = 'checkbox', 'Use SSL', ['tap', 'focus']
        anchor.states = {'visible', 'showing', 'sensitive'}
        middle = Node('entry', (345, 260, 600, 40), viewport, ['focus'], 'CA certificate file')
        target = Node('button', (345, 800, 600, 54), viewport, ['tap', 'focus'],
                      'Mode: Full Verification' if wrong_caption else 'Mode: Require')
        target.states = {'sensitive'}
        nodes = [frame, route, dialog, viewport, anchor, middle, target]
        state = {'clock': 0.0, 'tabs': 0, 'focusActions': [], 'waitBudgets': []}
        def focus(item):
            for node in nodes: node.states.discard('focused')
            item.states.update({'focused', 'visible', 'showing', 'sensitive'})
            if item is target: item.bounds = (345, 450, 600, 54)
        def action(item, index):
            self.assertIs(item, anchor)
            self.assertEqual('focus', item.actions[index])
            state['focusActions'].append((item, index))
            focus(item)
            return True
        atspi.Action.do_action = action
        atspi.Text = types.SimpleNamespace(get_text=lambda *_: self.fail('Reveal must never read field values'))
        def command(arguments):
            self.assertEqual(['xdotool', 'key', '--clearmodifiers', 'Tab'], arguments)
            state['tabs'] += 1
            if failure == 'deadline': state['clock'] += 8
            focus(middle if state['tabs'] % 2 else target)
            if failure == 'owner':
                replacement = Node('dialog', dialog.bounds, frame, name=dialog.name)
                nodes.remove(dialog); nodes.append(replacement); middle.parent = replacement
        def wait(predicate, seconds=15):
            state['waitBudgets'].append(seconds)
            for _ in range(4):
                state['clock'] += .001
                result = predicate()
                if result: return result
            raise TimeoutError('Focused native fixture state was not acknowledged')
        return atspi, nodes, anchor, command, wait, state

    def test_choice_keyboard_reveal_uses_one_visible_anchor_and_actual_target_focus(self):
        for named_dialog in (False, True):
            with self.subTest(namedDialog=named_dialog):
                atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture(named_dialog=named_dialog)
                with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']):
                    result = reveal_native_choice_with_keyboard(atspi, object(), lambda _: nodes, wait, command,
                        lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
                self.assertEqual(2, result['forwardTabs'])
                self.assertTrue(result['focused'] and result['showing'] and result['sensitive'] and result['sameDialog'])
                self.assertEqual([345, 450, 600, 54], result['bounds'])
                self.assertEqual(1, len(state['focusActions']))
                self.assertEqual(2, state['tabs'])
                self.assertTrue(all(0 < value <= 15 for value in state['waitBudgets']))

    def test_choice_keyboard_reveal_never_activates_a_wrong_selected_caption(self):
        atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture(wrong_caption=True)
        with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']), \
             self.assertRaisesRegex(RuntimeError, 'keyboard traversal bound'):
            reveal_native_choice_with_keyboard(atspi, object(), lambda _: nodes, wait, command,
                lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
        self.assertEqual(64, state['tabs'])
        self.assertEqual(1, len(state['focusActions']))

    def test_choice_keyboard_reveal_keeps_one_deadline_and_rejects_replaced_modal(self):
        for failure, expected in [('deadline', TimeoutError), ('owner', RuntimeError), ('title', RuntimeError)]:
            with self.subTest(failure=failure):
                atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture(failure=failure)
                with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']), \
                     self.assertRaises(expected):
                    reveal_native_choice_with_keyboard(atspi, object(), lambda _: nodes, wait, command,
                        lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
                self.assertLessEqual(state['tabs'], 2)
                self.assertEqual(0 if failure == 'title' else 1, len(state['focusActions']))
                if failure == 'deadline':
                    self.assertTrue(any(value < 8 for value in state['waitBudgets']))

    def test_choice_keyboard_reveal_carries_acknowledgments_within_one_scan_budget(self):
        atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture()
        def current_nodes(_):
            # A bounded native tree/ancestry observation can take real time.
            # Re-reading every acknowledged stop needlessly exhausts the same
            # deadline before the visible target's geometry can be checked.
            state['clock'] += 2.9
            return nodes
        with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']):
            result = reveal_native_choice_with_keyboard(atspi, object(), current_nodes, wait, command,
                lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
        self.assertEqual(2, result['forwardTabs'])
        self.assertEqual([345, 450, 600, 54], result['bounds'])
        self.assertEqual(2, state['tabs'])
        self.assertEqual(1, len(state['focusActions']))
        self.assertLess(state['clock'], 15)
        self.assertTrue(all(0 < value <= 15 for value in state['waitBudgets']))

    def test_choice_keyboard_reveal_rechecks_target_owner_permissions_and_caption_after_ack(self):
        for failure, expected in [('owner', RuntimeError), ('focus', TimeoutError), ('visible', TimeoutError),
                                  ('showing', RuntimeError), ('sensitive', RuntimeError),
                                  ('caption', TimeoutError)]:
            with self.subTest(failure=failure):
                atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture()
                target = nodes[-1]
                dialog = next(node for node in nodes if node.get_role() == atspi.Role.DIALOG)
                target_reads = 0
                def current_nodes(_):
                    nonlocal target_reads
                    if state['tabs'] == 2:
                        target_reads += 1
                        if target_reads == 2:
                            # The Tab was acknowledged. Final success must use
                            # a fresh observation rather than that carried node.
                            if failure == 'owner': nodes.remove(dialog)
                            elif failure == 'caption': target.name = 'Mode: Full Verification'
                            else: target.states.discard('focused' if failure == 'focus' else failure)
                    return nodes
                with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']), \
                     self.assertRaises(expected):
                    reveal_native_choice_with_keyboard(atspi, object(), current_nodes, wait, command,
                        lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
                self.assertEqual(2, state['tabs'])
                self.assertEqual(1, len(state['focusActions']))
                self.assertGreaterEqual(target_reads, 2)

    def test_choice_keyboard_reveal_never_repeats_an_unacknowledged_tab(self):
        atspi, nodes, anchor, _, wait, state = self.native_choice_keyboard_fixture()
        commands = []
        def command(arguments):
            commands.append(arguments)
            # The actual focus never changes, so this input cannot be retried.
        with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']), \
             self.assertRaises(TimeoutError):
            reveal_native_choice_with_keyboard(atspi, object(), lambda _: nodes, wait, command,
                lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
        self.assertEqual([['xdotool', 'key', '--clearmodifiers', 'Tab']], commands)
        self.assertEqual(1, len(state['focusActions']))

    def test_choice_keyboard_reveal_spends_one_fresh_target_scan_before_stable_geometry(self):
        atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture()
        scans = []
        def current_nodes(_):
            scans.append(state['tabs'])
            state['clock'] += 3.5
            return nodes
        with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']):
            result = reveal_native_choice_with_keyboard(atspi, object(), current_nodes, wait, command,
                lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
        self.assertEqual([0, 1, 2, 2], scans)
        self.assertEqual(2, result['forwardTabs'])
        self.assertEqual([345, 450, 600, 54], result['bounds'])
        self.assertLess(state['clock'], 15)
        self.assertEqual(1, len(state['focusActions']))
        self.assertTrue(all(0 < value <= 15 for value in state['waitBudgets']))

    def test_choice_keyboard_reveal_does_not_adopt_another_target_after_ack(self):
        atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture()
        target = nodes[-1]
        replacement = type(target)(target.role, target.bounds, target.parent, target.actions, target.name)
        target_reads = 0
        def current_nodes(_):
            nonlocal target_reads
            if state['tabs'] == 2:
                target_reads += 1
                if target_reads == 2:
                    target.states.discard('focused')
                    replacement.bounds = target.bounds
                    replacement.states.add('focused')
                    nodes[-1] = replacement
            return nodes
        with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']), \
             self.assertRaisesRegex(RuntimeError, 'target changed'):
            reveal_native_choice_with_keyboard(atspi, object(), current_nodes, wait, command,
                lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
        self.assertEqual(2, target_reads)
        self.assertEqual(2, state['tabs'])
        self.assertEqual(1, len(state['focusActions']))

    def test_choice_keyboard_reveal_revalidates_same_target_during_geometry(self):
        for failure, expected in [('owner', RuntimeError), ('owner-role', RuntimeError),
                                  ('owner-name', RuntimeError), ('target', RuntimeError),
                                  ('target-role', RuntimeError), ('focus', TimeoutError),
                                  ('visible', TimeoutError), ('showing', RuntimeError),
                                  ('sensitive', RuntimeError), ('caption', TimeoutError),
                                  ('interface', TimeoutError)]:
            with self.subTest(failure=failure):
                atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture(named_dialog=True)
                target = nodes[-1]
                dialog = next(node for node in nodes if node.get_role() == atspi.Role.DIALOG)
                geometry_reads = 0
                changed = False
                original_clear = target.clear_cache
                original_extents = atspi.Component.get_extents
                def extents(item, coordinates):
                    nonlocal geometry_reads
                    if item is target:
                        geometry_reads += 1
                    return original_extents(item, coordinates)
                def clear():
                    nonlocal changed
                    original_clear()
                    if geometry_reads != 1 or changed:
                        return
                    changed = True
                    if failure == 'owner': target.parent = dialog.parent
                    elif failure == 'owner-role': dialog.role = 'defunct'
                    elif failure == 'owner-name': dialog.name = 'Another manager'
                    elif failure == 'target': target.parent = None
                    elif failure == 'target-role': target.role = 'defunct'
                    elif failure == 'caption': target.name = 'Mode: Full Verification'
                    elif failure == 'interface': target.interfaces.remove('Action')
                    else: target.states.discard('focused' if failure == 'focus' else failure)
                target.clear_cache = clear
                atspi.Component.get_extents = extents
                with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']), \
                     self.assertRaises(expected):
                    reveal_native_choice_with_keyboard(atspi, object(), lambda _: nodes, wait, command,
                        lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
                self.assertTrue(changed)
                self.assertEqual(1, geometry_reads)
                self.assertEqual(2, state['tabs'])
                self.assertEqual(1, len(state['focusActions']))

    def test_choice_keyboard_reveal_requires_two_current_equal_extents(self):
        atspi, nodes, anchor, command, wait, state = self.native_choice_keyboard_fixture()
        target = nodes[-1]
        bounds = []
        original = atspi.Component.get_extents
        def extents(item, coordinates):
            if item is target:
                if bounds: target.bounds = (345, 420, 600, 54)
                bounds.append(target.bounds)
            return original(item, coordinates)
        atspi.Component.get_extents = extents
        with patch('native_workbench_acceptance.time.monotonic', side_effect=lambda: state['clock']):
            result = reveal_native_choice_with_keyboard(atspi, object(), lambda _: nodes, wait, command,
                lambda: anchor, 'Data Sources and Drivers', 'Mode', 'Require')
        self.assertEqual([(345, 450, 600, 54), (345, 420, 600, 54), (345, 420, 600, 54)], bounds)
        self.assertEqual([345, 420, 600, 54], result['bounds'])
        self.assertEqual(2, state['tabs'])
        self.assertEqual(1, len(state['focusActions']))

    def test_multicaret_waits_for_actual_composition_end_and_ignores_title_fragments(self):
        for language in ('en', 'de', 'ar'):
            with self.subTest(language=language), tempfile.TemporaryDirectory() as temporary:
                settings = Path(temporary) / 'settings.json'
                settings.write_text(json.dumps({'language': language}))
                state = {'text': '', 'caret': 0, 'carets': False, 'composing': False,
                         'pending': False, 'line': 2, 'undo': 0, 'blockedPolls': 0}
                with patch.dict(os.environ, {'BUSYDATA_NATIVE_SETTINGS_INPUT': str(settings)}):
                    composition = native_catalog_text('sqlCompositionActive')
                    carets = native_catalog_text('sqlActiveCarets', count='2')
                    def name():
                        # Both marker phrases in the document title are ordinary
                        # text and must not keep the final restoration wait open.
                        return ('SQL editor ' + composition + ' ' + carets + '.sql\nVisible SQL line' +
                                ('; ' + carets if state['carets'] else '') +
                                ('; ' + composition if state['composing'] else ''))
                    editor = types.SimpleNamespace(clear_cache=lambda: None, get_name=name)
                    def set_text(_editor, value):
                        self.assertEqual('firstxx\nsecondx', value)
                        state.update(text='secondx', caret=7)
                        return True
                    atspi = types.SimpleNamespace(
                        Text=types.SimpleNamespace(get_text=lambda *_: state['text'],
                                                   get_caret_offset=lambda *_: state['caret']),
                        EditableText=types.SimpleNamespace(set_text_contents=set_text))
                    def wait(predicate, seconds=15):
                        for _ in range(3):
                            if predicate():
                                return True
                            if state['pending']:
                                state['blockedPolls'] += 1
                                state.update(pending=False, composing=False)
                        self.fail('Actual native multicaret state was not acknowledged')
                    def command(arguments):
                        kind, key = arguments[1], arguments[-1]
                        if kind in ('keydown', 'keyup'):
                            return
                        if key == 'ctrl+Home': state.update(text='firstxx', line=1, caret=0)
                        elif key == 'End': state['caret'] = 7
                        elif key == 'ctrl+alt+Down': state['carets'] = True
                        elif kind == 'type' and key == 'a': state.update(text='firstxx日', composing=True)
                        elif key == 'space': state['pending'] = True
                        elif key == 'Escape':
                            self.assertFalse(state['composing'], 'Preedit was mistaken for committed input')
                            state['carets'] = False
                        elif key == 'Down': state.update(text='secondx日' if state['undo'] == 0 else 'secondx', line=2)
                        elif key == 'ctrl+z': state.update(text='firstxx', line=1, undo=1)
                        elif key == 'z': state['text'] = ''
                        else: self.fail('Unexpected native command: ' + repr(arguments))
                    report = {}
                    verify_multicaret(atspi, editor, wait, command, report)
                self.assertEqual(1, state['blockedPolls'])
                self.assertTrue(report['nativeMulticaretImeBothLinesAndAtomicUndoVerified'])

    def test_ime_commit_requires_exact_localized_composition_status_to_end(self):
        root = Path(__file__).resolve().parents[1]
        for language in ('en', 'de', 'ar'):
            catalog = json.loads((root / ('lib/l10n/app_' + language + '.arb')).read_text())
            caption = catalog['sqlCompositionActive']
            title = catalog['sqlEditorLabel'].replace('{title}', caption + '.sql')
            detail = catalog['sqlVisibleLine'].replace('{line}', '1').replace('{total}', '1').replace('{column}', '2')
            label = title + '\n' + detail
            self.assertFalse(native_ime_composition_active(label, caption))
            self.assertTrue(native_ime_composition_active(label + '; ' + caption, caption))
            self.assertFalse(native_ime_composition_active(label + '; ' + caption + ' suffix', caption))
        english = json.loads((root / 'lib/l10n/app_en.arb').read_text())['sqlCompositionActive']
        self.assertEqual(english, 'Input composition active')
        self.assertTrue(native_ime_composition_active('SQL editor Query 1\nVisible SQL line; ' + english, english))
        # This was the old false acceptance while real preedit was still active.
        self.assertNotIn('input composition active', 'Visible SQL line; ' + english)
        for label, caption in [(None, english), ('label', None), ('label', ''), ('label', 'x' * 4097)]:
            with self.assertRaises(ValueError):
                native_ime_composition_active(label, caption)

    def test_failure_structure_retains_only_bounded_machine_state(self):
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(PASSWORD_TEXT='password'),
            StateType=types.SimpleNamespace(READ_ONLY='readonly', EDITABLE='editable',
                                           SHOWING='showing', FOCUSED='focused'))

        def node(role, name, interfaces, attributes, states=()):
            return types.SimpleNamespace(
                get_role=lambda: role, get_role_name=lambda: role,
                get_name=lambda: name, get_interfaces=lambda: interfaces,
                get_attributes=lambda: attributes,
                get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state in states))

        protected = node('password', 'private password', ['EditableText', 'Text'], {})
        protected.get_name = lambda: self.fail('Password label must not be inspected')
        protected.get_attributes = lambda: self.fail('Password attributes must not be inspected')
        root = node('panel', 'private root label', [], {
            'busydata-status': 'ok', 'busydata-reason': 'private reason',
            'busydata-action-status': 'stale', 'busydata-action-name': 'setText',
            'busydata-action-stale-count': '2', 'busydata-action-sequence': '7',
            'busydata-action-node-id': 'private identifier', 'untrusted': 'private value'})
        editor = node('entry', 'SQL editor private document\nVisible SQL line 1 of 1, column 1',
                      ['EditableText', 'Text'], {'busydata-geometry-precision': 'glyph-bounds'},
                      ['editable', 'showing'])
        result = native_failure_structure(atspi, [protected, root, editor], {})
        self.assertEqual(result['nodeCount'], 3)
        self.assertFalse(result['scanLimited'])
        self.assertEqual([item['category'] for item in result['nodes']], ['owned-root', 'sql-editor'])
        self.assertEqual(result['nodes'][0]['attributes'], {
            'busydata-status': 'ok', 'busydata-action-status': 'stale',
            'busydata-action-name': 'setText', 'busydata-action-stale-count': '2',
            'busydata-action-sequence': '7'})
        self.assertTrue(result['nodes'][1]['editable'])
        self.assertNotIn('private', json.dumps(result))
        limited = native_failure_structure(atspi, [editor] * 257, {})
        self.assertTrue(limited['scanLimited'])
        self.assertEqual(limited['examinedNodeCount'], 256)
        self.assertEqual(len(limited['nodes']), 256)

    def test_failure_structure_rejects_unrecognized_attribute_payloads(self):
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(PASSWORD_TEXT='password'),
            StateType=types.SimpleNamespace(READ_ONLY='readonly', EDITABLE='editable',
                                           SHOWING='showing', FOCUSED='focused'))
        node = types.SimpleNamespace(
            get_role=lambda: 'panel', get_role_name=lambda: 'panel', get_name=lambda: '',
            get_interfaces=lambda: [],
            get_attributes=lambda: {'busydata-status': 'private',
                'busydata-action-status': 'private', 'busydata-action-name': 'private',
                'busydata-revision': '9' * 21, 'busydata-action-inflight': '1\nprivate',
                'busydata-action-node-id': 42, 'busydata-geometry-precision': 'private'},
            get_state_set=lambda: types.SimpleNamespace(contains=lambda _: False))
        result = native_failure_structure(atspi, [node], {})
        self.assertEqual(result['nodes'][0]['attributes'], {})

    def test_native_p0_message_roles_use_actual_catalog_and_exact_action_lookup(self):
        root = Path(__file__).resolve().parents[1]
        english = json.loads((root / 'lib/l10n/app_en.arb').read_text())
        arabic = json.loads((root / 'lib/l10n/app_ar.arb').read_text())
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(MENU_ITEM='menu', CHECK_MENU_ITEM='check', RADIO_MENU_ITEM='radio'),
            StateType=types.SimpleNamespace(SHOWING='showing', SENSITIVE='sensitive'),
            Action=types.SimpleNamespace(get_n_actions=lambda _: 1, get_action_name=lambda _, __: 'Tap'))
        for language, catalog in [('en', english), ('ar', arabic)]:
            with tempfile.TemporaryDirectory() as folder:
                settings = Path(folder) / 'expected.json'
                settings.write_text(json.dumps({'language': language}))
                with patch.dict('os.environ', {'BUSYDATA_NATIVE_SETTINGS_INPUT': str(settings)}):
                    for key in ['textValueNextPage', 'textValuePreviousPage', 'valueEditorActions',
                                'stageChange', 'resetValueChunks', 'loadValueChunk', 'editCompleteValue']:
                        expected = catalog[key]
                        self.assertEqual(native_catalog_text(key), expected)
                        node = types.SimpleNamespace(get_name=lambda: expected,
                            get_interfaces=lambda: ['Action'], get_role=lambda: 'button',
                            get_state_set=lambda: types.SimpleNamespace(contains=lambda _: True))
                        self.assertIs(find_live_activation(atspi, [node], native_catalog_message(key))[0], node)
                        if key == 'textValueNextPage' and catalog['nextTextPage'] != expected:
                            self.assertIsNone(find_live_activation(atspi, [node], catalog['nextTextPage']))
                        if key == 'textValuePreviousPage' and catalog['previousTextPage'] != expected:
                            self.assertIsNone(find_live_activation(atspi, [node], catalog['previousTextPage']))
                    page = catalog['textValuePage'].replace('{current}', '2').replace('{total}', '2')
                    self.assertEqual(native_catalog_text('textValuePage', current='2', total='2'), page)
                    with self.assertRaises(ValueError): native_catalog_text('textValuePage', current='2')
                    with self.assertRaises(ValueError): native_catalog_text('textValuePage', current='{' , total='2')

    def test_designer_close_review_uses_exact_captured_translated_tab_title(self):
        def node(name, *, showing=True, sensitive=True, role='button', actions=True):
            states = {key for key, included in [('showing', showing), ('sensitive', sensitive)] if included}
            return types.SimpleNamespace(get_name=lambda: name, get_role=lambda: role,
                get_interfaces=lambda: ['Action'] if actions else [],
                get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state in states))
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(PUSH_BUTTON='button'),
            StateType=types.SimpleNamespace(SHOWING='showing', SENSITIVE='sensitive'))
        atspi.Role.MENU_ITEM = 'menuitem'
        atspi.Role.CHECK_MENU_ITEM = 'checkmenuitem'
        atspi.Role.RADIO_MENU_ITEM = 'radiomenuitem'
        atspi.Action = types.SimpleNamespace(get_n_actions=lambda _: 1, get_action_name=lambda _, __: 'Tap')
        for tab, close in [('● native_atspi_fixture — Object designer\nProfile · database', 'Close'),
                           ('● native_atspi_fixture — مصمم الكائنات\nالهدف', 'إغلاق')]:
            expected = close + ' ' + tab.split('\n')[0].removeprefix('● ')
            self.assertEqual(native_close_review_label(tab, close), expected)
            button = node(expected)
            others = [node(expected, role='heading'), node(expected, sensitive=False),
                      node(expected + ' extra'), node(close + ' Object designer · old-owner')]
            self.assertIs(find_native_close_review(atspi, [*others, button], tab, close), button)
            # Native action lookup requires the raw resolved caption. Reversing
            # an embedded translated suffix creates an unrendered mixed label.
            action = find_live_activation(atspi, [button], button.get_name())
            self.assertIs(action[0], button)
            if close != 'Close':
                mixed = normalized_native_label(button.get_name(), {'Object designer': 'مصمم الكائنات'})
                self.assertNotEqual(mixed, button.get_name())
                self.assertIsNone(find_live_activation(atspi, [button], mixed))
            self.assertIsNone(find_native_close_review(atspi, others, tab, close))
            with self.assertRaises(RuntimeError):
                find_native_close_review(atspi, [button, node(expected)], tab, close)
        for invalid in ['', 'x' * 2049, 'name\x00suffix']:
            with self.assertRaises(ValueError): native_close_review_label(invalid, 'Close')

    def test_captured_grid_owner_is_required_before_popup_and_after_return(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.StateType.SELECTED = 'selected'
        owner = Node('button', (0,0,160,36), name='captured table')
        other = Node('button', (160,0,160,36), name='different table')
        owner.states.add('selected')
        self.assertTrue(assert_current_grid_owner(atspi, [owner], owner))
        with self.assertRaisesRegex(RuntimeError, 'Captured grid document changed'):
            assert_current_grid_owner(atspi, [], owner)
        other.states.add('selected')
        with self.assertRaisesRegex(RuntimeError, 'Captured grid document changed'):
            assert_current_grid_owner(atspi, [other], owner, flyout_pending=True)
        owner.states.discard('selected')
        with self.assertRaisesRegex(RuntimeError, 'Captured grid document changed'):
            assert_current_grid_owner(atspi, [owner], owner, flyout_pending=True)

    def test_owned_fluent_flyout_can_hide_tabs_until_it_retires(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.StateType.SELECTED = 'selected'
        owner = Node('button', (0,0,160,36), name='captured table')
        owner.states.add('selected')
        popup = Node('panel', (160,40,160,36), name='Sort', actions=['Tap'])
        self.assertFalse(assert_current_grid_owner(atspi, [popup], owner, flyout_pending=True))
        with self.assertRaisesRegex(RuntimeError, 'Captured grid document changed'):
            assert_current_grid_owner(atspi, [popup], owner)
        self.assertTrue(assert_current_grid_owner(atspi, [owner], owner))

    def test_orca_multiline_utterance_keeps_the_actual_field_and_selected_value(self):
        log = ("10:08:38.152277 - SPEECH OUTPUT: 'Driver\n"
               "                  PostgreSQL' {'established': False}\n"
               "10:08:38.153224 - SPEECH OUTPUT: 'button.' {}\n")
        self.assertTrue(native_speech_contains(log, ['Driver\nPostgreSQL', 'button.']))
        self.assertFalse(native_speech_contains(log, ['Driver\nMySQL']))

    def test_orca_acknowledgement_rejects_non_speech_and_separate_utterances(self):
        log = ("10:08:38.152277 - WARNING: Driver PostgreSQL\n"
               "10:08:38.153224 - SPEECH OUTPUT: 'Driver' {}\n"
               "10:08:38.154224 - SPEECH OUTPUT: 'PostgreSQL' {}\n")
        self.assertFalse(native_speech_contains(log, ['Driver\nPostgreSQL']))
        self.assertTrue(native_speech_contains(log, ['Driver', 'PostgreSQL']))

    def test_selected_value_control_accepts_linux_and_fluent_field_captions(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        for label,caption in [('Driver','Driver: PostgreSQL'),
                              ('Driver','Driver\nPostgreSQL'),
                              ('Choose existing object','Choose existing object\nChoose existing object')]:
            control = Node('button', (0,0,160,36), actions=['Tap','Focus'], name=caption)
            summary = Node('panel', (0,0,160,36), actions=['Focus'], name=caption)
            value_only = Node('button', (0,0,160,36), actions=['Tap'], name='PostgreSQL')
            self.assertIs(control, find_selected_value_control(atspi,
                [summary, value_only, control], label))
            control.states.discard('sensitive')
            self.assertIsNone(find_selected_value_control(atspi,
                [summary, value_only, control], label))

    def test_selected_value_control_rejects_ambiguous_real_selectors(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        first = Node('button', (0,0,160,36), actions=['Tap'], name='Driver: PostgreSQL')
        other = Node('button', (0,40,160,36), actions=['Tap'], name='Driver\nMySQL')
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous selected-value'):
            find_selected_value_control(atspi, [first,other], 'Driver')

    def test_metadata_selector_keeps_field_identity_with_adjacent_representation(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        view = Node('button', (0,0,160,36), actions=['Tap'], name='View\nStructure')
        for caption in ('Structure\nColumns', 'source/db/public/table\nStructure: Columns'):
            control = Node('button', (0,40,160,36), actions=['Tap'], name=caption)
            summary = Node('panel', (0,40,160,36), actions=['Focus'], name=caption)
            self.assertIs(control, find_metadata_section_control(atspi,
                [view,summary,control], 'Structure', ['Columns','Indexes']))
        self.assertIsNone(find_metadata_section_control(atspi, [view],
            'Structure', ['Columns','Indexes']))

    def test_metadata_selector_rejects_ambiguous_actionable_controls(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        controls = [Node('button', (0,y,160,36), actions=['Tap'], name=caption)
            for y,caption in [(0,'Structure\nColumns'),(40,'Structure: Indexes')]]
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous metadata section'):
            find_metadata_section_control(atspi, controls, 'Structure', ['Columns','Indexes'])

    def test_connection_management_scope_cannot_replace_complete_native_receipt(self):
        partial = native_report_name('POSTGRESQL', connection_management_only=True)
        self.assertEqual(partial, 'native-connection-management-linux.json')
        self.assertNotEqual(partial, native_report_name('POSTGRESQL'))
        for arguments in ({'engine': 'MYSQL'}, {'database_explorer': True},
                          {'database_explorer_local': True}, {'database_explorer_tools': True},
                          {'rendering_only': 'platform'}, {'platform_case': 'light'}):
            with self.subTest(arguments=arguments), self.assertRaises(ValueError):
                native_report_name(**dict({'engine': 'POSTGRESQL',
                    'connection_management_only': True}, **arguments))

    def test_integration_boundary_fixtures_really_exceed_pages_and_keep_engine_types(self):
        import re
        for engine in ('POSTGRESQL', 'MYSQL', 'MARIADB'):
            sql = object_fixture_sql(engine)
            self.assertEqual(set(re.findall(r'\bc[0-9]{3}(?= INTEGER DEFAULT 0)', sql)), {f'c{i:03}' for i in range(160)})
            self.assertIn('z_generated INTEGER GENERATED ALWAYS AS (c159+1) STORED', sql)
            self.assertIn('CREATE VIEW native_late_view', sql)
            self.assertLess(len(sql.encode()), 32768)
            if engine == 'POSTGRESQL':
                self.assertEqual(len(re.findall(r'CREATE SCHEMA namespace_page_', sql)), 160)
                self.assertIn('CREATE INDEX native_materialized_late_index', sql)
                self.assertIn('CREATE TABLE audit.native_late_view', sql)
            else:
                self.assertNotIn('CREATE SCHEMA namespace_page_', sql)
                self.assertIn('z_identity INTEGER AUTO_INCREMENT UNIQUE', sql)

    def test_large_catalog_writers_cover_every_real_identity_once_with_bounded_scripts(self):
        scripts = catalog_page_scripts()
        self.assertEqual(len(scripts), 4)
        statements = []
        for script in scripts:
            self.assertLessEqual(len(script.encode()), 32768)
            statements.extend(script.splitlines())
        self.assertEqual(len(statements), 2305)
        self.assertEqual(set(statements), {
            f'CREATE TABLE busydata.page_{number:04d}(id integer);'
            for number in range(2305)})

    def test_physical_key_input_releases_modifiers_when_the_trigger_is_rejected(self):
        for rejected in (None, 76):
            events, lifecycle = [], []
            def event(display, code, pressed, delay):
                events.append((display, code, pressed))
                return not (pressed and code == rejected)
            xlib = types.SimpleNamespace(
                XOpenDisplay=lambda _: 91,
                XSync=lambda *args: lifecycle.append('sync'),
                XCloseDisplay=lambda *args: lifecycle.append('close'))
            xtest = types.SimpleNamespace(XTestFakeKeyEvent=event)
            with patch('ctypes.CDLL', side_effect=[xlib, xtest]):
                if rejected is None:
                    send_native_keycodes([37, 50, 76])
                else:
                    with self.assertRaisesRegex(RuntimeError, 'press rejected'):
                        send_native_keycodes([37, 50, 76])
            expected = [(91, 37, 1), (91, 50, 1), (91, 76, 1)]
            if rejected is None: expected.append((91, 76, 0))
            expected += [(91, 50, 0), (91, 37, 0)]
            self.assertEqual(events, expected)
            self.assertEqual(lifecycle, ['sync', 'close'])

    def test_physical_key_input_rejects_invalid_codes_before_opening_a_display(self):
        for codes in ([], [0], [256], [37, 37], [37, 50, 64, 76, 77]):
            with patch('ctypes.CDLL') as load, self.assertRaises(ValueError):
                send_native_keycodes(codes)
            load.assert_not_called()

    def test_definition_checks_readonly_native_text_values_and_never_protected_or_hidden_input(self):
        roles = types.SimpleNamespace(PASSWORD_TEXT='password')
        states = types.SimpleNamespace(SHOWING='showing', EDITABLE='editable', READ_ONLY='readonly')
        reads = []
        class Node:
            def __init__(self, text, flags=('showing',), role='text', name=''):
                self.text, self.flags, self.role, self.name = text, flags, role, name
            def get_role(self): return self.role
            def get_name(self): return self.name
            def get_interfaces(self): return ['Text']
            def get_state_set(self): return types.SimpleNamespace(contains=lambda state: state in self.flags)
        def text(node, start, end):
            reads.append(node)
            return node.text[start:end]
        atspi = types.SimpleNamespace(Role=roles, StateType=states, Text=types.SimpleNamespace(
            get_character_count=lambda node: len(node.text), get_text=text))
        ddl = 'CREATE TABLE public.customers (id integer);'
        protected = Node(ddl, role='password')
        hidden = Node(ddl, flags=())
        editor = Node(ddl, flags=('showing','editable'))
        browse = Node('SELECT * FROM public.customers;')
        self.assertFalse(visible_object_definition(atspi, [protected, hidden, editor, browse], 'customers'))
        self.assertEqual([browse], reads)
        self.assertTrue(visible_object_definition(atspi, [Node(ddl)], 'customers'))
        # The pinned Linux engine adds EDITABLE for every text-field role,
        # including SelectableText; its independent READ_ONLY flag is decisive.
        self.assertTrue(visible_object_definition(atspi, [Node(ddl, flags=('showing','editable','readonly'))], 'customers'))
        self.assertFalse(visible_object_definition(atspi, [Node(ddl)], 'other_table'))
    def test_inspection_ddl_accepts_native_definers_but_rejects_browse_sql(self):
        from native_database_explorer_tools import is_object_ddl
        for sql in [
            'CREATE OR REPLACE FUNCTION public.native_function(x integer) RETURNS integer AS $$ SELECT x $$ LANGUAGE SQL;',
            'CREATE DEFINER=`root`@`%` FUNCTION `native_function`(x int) RETURNS int RETURN x',
            'CREATE DEFINER=`local``user`@`localhost` PROCEDURE `native_procedure`() SELECT 17',
            'CREATE SEQUENCE `native_sequence` START WITH 41 INCREMENT BY 3',
        ]:
            name = 'native_procedure' if 'PROCEDURE' in sql else 'native_sequence' if 'SEQUENCE' in sql else 'native_function'
            self.assertTrue(is_object_ddl(sql, name), sql)
            self.assertFalse(is_object_ddl(sql, 'unrelated_object'), sql)
        self.assertFalse(is_object_ddl('SELECT * FROM native_function;', 'native_function'))
        self.assertFalse(is_object_ddl('CREATE DEFINER=broken FUNCTION native_function()', 'native_function'))

    def test_native_transition_receipt_preserves_observations_within_existing_byte_budget(self):
        import verify_native_accessibility as native
        parents = [{'path': '/org/a11y/atspi/accessible/' + str(i), 'role': 'panel',
                    'name': 'Commit transaction', 'showing': True, 'focused': False}
                   for i in range(8)]
        node = {'path': '/org/a11y/atspi/accessible/548', 'role': 'button',
                'name': 'المزيد', 'focused': False, 'enabled': True, 'showing': True,
                'bounds': {'x': 13, 'y': 329, 'width': 228, 'height': 52}, 'parents': parents}
        report = {'nativeGridMenuTransitions': [
            {'phase': 'before-activation', 'nodes': [node] * 24} for _ in range(24)]}
        self.assertGreater(len(json.dumps(report, indent=2).encode()), 1024 * 1024)
        serialized = native.native_report_json(report)
        self.assertLessEqual(len(serialized.encode()), 1024 * 1024)
        self.assertEqual(report, json.loads(serialized))
        with self.assertRaisesRegex(RuntimeError, 'byte budget'):
            native.native_report_json({'diagnostic': 'x' * (1024 * 1024)})

    def test_labeled_choice_lookup_reacquires_a_proven_retired_node_and_preserves_errors(self):
        failure = RuntimeError('Native property read failed')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_name(): raise failure
        retired = types.SimpleNamespace(get_name=failed_name)
        self.assertIsNone(find_live_activation(None, [retired], 'PostgreSQL',
            current_nodes=lambda: [], alternate_names={'Driver PostgreSQL'}))
        with self.assertRaises(RuntimeError) as raised:
            find_live_activation(None, [retired], 'PostgreSQL',
                current_nodes=lambda: [retired], alternate_names={'Driver PostgreSQL'})
        self.assertIs(failure, raised.exception)

    def test_labeled_choices_still_require_one_visible_enabled_activation(self):
        atspi, _, _, first, second, _ = self.modal_focus_fixture()
        first.name = 'Driver  PostgreSQL'
        second.name = 'PostgreSQL'
        options = {'Driver PostgreSQL'}
        self.assertIs(first, find_live_activation(atspi, [first], 'PostgreSQL',
            alternate_names=options)[0])
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_live_activation(atspi, [first, second], 'PostgreSQL', alternate_names=options)
        first.states.remove('sensitive')
        self.assertIsNone(find_live_activation(atspi, [first], 'PostgreSQL', alternate_names=options))

    def test_post_connect_modal_retirement_continues_reads_without_replaying_activation(self):
        events, clock = [], [0.0]
        modal = object()
        connect = types.SimpleNamespace(get_role=lambda: 'button')
        def dispatch(item, index):
            self.assertIs(connect, item)
            self.assertEqual(0, index)
            events.append('Connect')
            return True
        atspi = types.SimpleNamespace(Action=types.SimpleNamespace(do_action=dispatch))
        observations = iter([NativeSnapshotIncomplete('missing child'), [modal],
                             NativeSnapshotIncomplete('child count unavailable'), []])
        def current_nodes():
            events.append('read')
            value = next(observations)
            if isinstance(value, Exception): raise value
            return value
        context = types.SimpleNamespace(pending=lambda: False,
            iteration=lambda blocking: self.fail('No pending event'))
        with tempfile.TemporaryDirectory() as directory, \
                patch('verify_native_accessibility.time.monotonic', side_effect=lambda: clock[0]), \
                patch('verify_native_accessibility.time.sleep', side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)):
            self.assertEqual('button', dispatch_native_activation(atspi, connect, 0))
            self.assertTrue(wait_native_modal_retired(modal, current_nodes,
                lambda predicate: native_wait(predicate, context, Path(directory) / 'reader.log', .15)))
        self.assertEqual(['Connect', 'read', 'read', 'read', 'read'], events)
        self.assertAlmostEqual(.09, clock[0])

    def test_persistent_incomplete_post_modal_reads_reach_the_original_wait_deadline(self):
        reads, clock = [], [0.0]
        def incomplete():
            reads.append(True)
            raise NativeSnapshotIncomplete('missing child')
        context = types.SimpleNamespace(pending=lambda: True, iteration=Mock())
        with tempfile.TemporaryDirectory() as directory, \
                patch('verify_native_accessibility.time.monotonic', side_effect=lambda: clock[0]), \
                patch('verify_native_accessibility.time.sleep', side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)):
            with self.assertRaisesRegex(TimeoutError, '^Native acceptance condition deadline$'):
                wait_native_modal_retired(object(), incomplete,
                    lambda predicate: native_wait(predicate, context, Path(directory) / 'reader.log', .1))
        self.assertEqual(4, len(reads))
        self.assertEqual(4 * 32, context.iteration.call_count)
        self.assertAlmostEqual(.12, clock[0])

    def test_post_modal_read_continuation_does_not_hide_other_failures(self):
        failures = [NativeNodeBudgetExceeded(513, 0, 0, 512),
                    RuntimeError('Invalid native child count'),
                    ValueError('Malformed native tree')]
        context = types.SimpleNamespace(pending=lambda: False, iteration=Mock())
        with tempfile.TemporaryDirectory() as directory:
            for failure in failures:
                with self.subTest(failure=type(failure).__name__):
                    read = Mock(side_effect=failure)
                    with patch('verify_native_accessibility.time.sleep') as sleep:
                        with self.assertRaises(type(failure)) as raised:
                            wait_native_modal_retired(object(), read,
                                lambda predicate: native_wait(predicate, context, Path(directory) / 'reader.log'))
                        self.assertIs(failure, raised.exception)
                        read.assert_called_once_with()
                        sleep.assert_not_called()
            with self.assertRaises(TypeError):
                wait_native_modal_retired(object(), lambda: None,
                    lambda predicate: native_wait(predicate, context, Path(directory) / 'reader.log'))

    def test_incomplete_post_modal_read_still_enforces_the_existing_reader_log_bound(self):
        context = types.SimpleNamespace(pending=lambda: False, iteration=Mock())
        read = Mock(side_effect=NativeSnapshotIncomplete('missing child'))
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / 'reader.log'
            log.write_bytes(b'x' * (4 * 1024 * 1024 + 1))
            with patch('verify_native_accessibility.time.sleep') as sleep:
                with self.assertRaisesRegex(RuntimeError, '^Native reader diagnostic byte budget$'):
                    wait_native_modal_retired(object(), read,
                        lambda predicate: native_wait(predicate, context, log))
                read.assert_called_once_with()
                sleep.assert_not_called()

    def test_selected_menu_retirement_uses_its_identity_without_reading_disposed_nodes(self):
        popup, entry = object(), object()
        snapshots = iter([[popup, entry], [popup], []])
        def wait(predicate):
            self.assertFalse(predicate())
            self.assertFalse(predicate())
            return predicate()
        self.assertTrue(wait_native_menu_retired(popup, entry, lambda: next(snapshots), wait))
        with self.assertRaises(TimeoutError):
            wait_native_menu_retired(popup, entry, lambda: [popup],
                lambda predicate: (_ for _ in ()).throw(TimeoutError()) if not predicate() else True)

    def test_sorted_cell_does_not_acknowledge_a_replacing_result_or_another_owner(self):
        atspi, host, modal, cell, owner, Node = self.modal_focus_fixture()
        atspi.StateType.SELECTED = 'selected'
        cell.name = 'Row 1, n: second'
        owner.name = 'native_atspi_fixture · Completed'
        owner.states.add('selected')
        name = lambda node: node.name
        self.assertIsNone(find_visible_grid_cell(atspi, [owner, cell], cell.name, name,
            previous={cell}, owner=owner))
        new_cell = Node('button', (0, 0, 100, 32), host, ['Tap'], cell.name)
        self.assertIsNone(find_visible_grid_cell(atspi, [owner, cell, new_cell], cell.name, name,
            previous={cell}, owner=owner))
        owner.name = 'native_atspi_fixture · Running'
        self.assertIsNone(find_visible_grid_cell(atspi, [owner, new_cell], cell.name, name,
            previous={cell}, owner=owner))
        owner.name = 'native_atspi_fixture · Completed'
        owner.states.remove('selected')
        self.assertIsNone(find_visible_grid_cell(atspi, [owner, new_cell], cell.name, name,
            previous={cell}, owner=owner))
        owner.states.add('selected')
        self.assertIs(new_cell, find_visible_grid_cell(atspi, [owner, new_cell], cell.name, name,
            previous={cell}, owner=owner))

    def test_grid_cell_acknowledgement_refuses_hidden_disabled_or_ambiguous_values(self):
        atspi, _, _, cell, _, Node = self.modal_focus_fixture()
        cell.name = 'Row 1, n: second'
        for state in ('showing', 'sensitive'):
            cell.states.remove(state)
            self.assertIsNone(find_visible_grid_cell(atspi, [cell], cell.name, lambda n: n.name))
            cell.states.add(state)
        other = Node('button', (0, 0, 100, 32), None, ['Tap'], cell.name)
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_visible_grid_cell(atspi, [cell, other], cell.name, lambda n: n.name)

    def test_replaced_grid_completion_uses_title_line_before_actual_localized_provenance(self):
        root = Path(__file__).resolve().parents[1]
        for language in ('en', 'ar'):
            catalog = json.loads((root / ('lib/l10n/app_' + language + '.arb')).read_text())
            atspi, host, _, old_cell, owner, Node = self.modal_focus_fixture()
            atspi.StateType.SELECTED = 'selected'
            owner.states.add('selected')
            cell = Node('button', (0, 0, 100, 32), host, ['Tap'],
                catalog['row'] + ' 1, n: second')
            key = Node('button', (0, 0, 100, 32), host, ['Tap'],
                catalog['row'] + ' 1, id: 2')
            with tempfile.TemporaryDirectory() as folder:
                settings = Path(folder) / 'expected.json'
                settings.write_text(json.dumps({'language': language}))
                with patch.dict('os.environ', {'BUSYDATA_NATIVE_SETTINGS_INPUT': str(settings)}):
                    labels = native_catalog_labels()
                name = lambda node: native_control_label(node, labels)
                owner.name = ('native_atspi_fixture · ' + catalog['completed'] +
                    '\nNative accessibility fixture · busydata / public / native_atspi_fixture')
                self.assertTrue(native_tab_has_status(name(owner), 'Completed'))
                self.assertFalse(native_tab_has_status(name(owner), 'Running'))
                self.assertIs(cell, find_visible_grid_cell(atspi, [owner, key, cell],
                    'Row 1, n: second', name, previous={old_cell}, owner=owner))
                self.assertIs(cell, find_keyed_grid_cell(atspi, [owner, key, cell],
                    'id', '2', 'n', 'second', name, previous={old_cell}, owner=owner))
                # Provenance cannot supply completion while this same owner's
                # title is still running, and its old result must still retire.
                owner.name = ('native_atspi_fixture · ' + catalog['running'] +
                    '\nNative accessibility fixture · ' + catalog['completed'])
                self.assertTrue(native_tab_has_status(name(owner), 'Running'))
                self.assertFalse(native_tab_has_status(name(owner), 'Completed'))
                for lookup in (
                    lambda nodes: find_visible_grid_cell(atspi, nodes, 'Row 1, n: second',
                        name, previous={old_cell}, owner=owner),
                    lambda nodes: find_keyed_grid_cell(atspi, nodes, 'id', '2', 'n',
                        'second', name, previous={old_cell}, owner=owner),
                ):
                    self.assertIsNone(lookup([owner, key, cell]))
                owner.name = ('native_atspi_fixture · ' + catalog['completed'] + '\nProvenance')
                self.assertIsNone(find_visible_grid_cell(atspi, [owner, old_cell, key, cell],
                    'Row 1, n: second', name, previous={old_cell}, owner=owner))
                self.assertIsNone(find_visible_grid_cell(atspi, [key, cell],
                    'Row 1, n: second', name, previous={old_cell}, owner=owner))
                owner.states.remove('selected')
                self.assertIsNone(find_keyed_grid_cell(atspi, [owner, key, cell],
                    'id', '2', 'n', 'second', name, previous={old_cell}, owner=owner))
        self.assertTrue(native_tab_has_status('● owner · Completed · Production · Transaction open\nProfile', 'Completed'))
        for title in ('owner Completed', 'owner\nCompleted', 'owner · Running\nCompleted',
                      'owner · Completed · unknown', 'owner · Completed notes'):
            self.assertFalse(native_tab_has_status(title, 'Completed'))

    def test_keyed_reset_waits_for_retirement_and_its_completed_owner_before_resolving_identity(self):
        atspi, host, _, old_key, owner, Node = self.modal_focus_fixture()
        atspi.StateType.SELECTED = 'selected'
        owner.name = 'native_atspi_fixture · Completed'
        owner.states.add('selected')
        old_key.name = 'Row 1, id: 1'
        key = Node('button', (0, 0, 100, 32), host, ['Tap'], 'Row 2, id: 1')
        value = Node('button', (0, 0, 100, 32), host, ['Tap'], 'Row 2, n: 漢😀')
        name = lambda node: node.name
        def find(nodes, expected='漢😀'):
            return find_keyed_grid_cell(atspi, nodes, 'id', '1', 'n', expected, name,
                                        previous={old_key}, owner=owner)
        self.assertIsNone(find([owner, old_key, key, value]))
        owner.name = 'native_atspi_fixture · Running'
        self.assertIsNone(find([owner, key, value]))
        owner.name = 'native_atspi_fixture · Completed'
        owner.states.remove('selected')
        self.assertIsNone(find([owner, key, value]))
        owner.states.add('selected')
        self.assertIsNone(find([key, value]))
        self.assertIs(value, find([owner, key, value]))
        self.assertIsNone(find([owner, key, value], expected='second'))
        duplicate = Node('button', (0, 0, 100, 32), host, ['Tap'], 'Row 3, id: 1')
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find([owner, key, duplicate, value])
        duplicate.states.remove('showing')
        self.assertIs(value, find([owner, key, duplicate, value]))

    def test_localized_editor_heading_preserves_arbitrary_document_title_and_details(self):
        title = 'public.مخطط-識別子.sql'
        detail = '\nVisible SQL line 1 of 1, column 1'
        for template in ('SQL-Editor {title}', 'محرر SQL {title}', '{title} の SQL エディター'):
            labels = {'SQL editor {title}': template}
            actual = template.replace('{title}', title) + detail
            with self.subTest(template=template):
                self.assertEqual('SQL editor ' + title + detail,
                                 native_sql_editor_label(actual, labels))
                self.assertIsNone(native_sql_editor_label('Find command', labels))
                self.assertIsNone(native_sql_editor_label(template.replace('{title}', ''), labels))
                self.assertIn(native_sql_editor_announcement(labels), actual)
                editor = types.SimpleNamespace(get_name=lambda: actual,
                    get_interfaces=lambda: ['EditableText', 'Text'])
                profile = types.SimpleNamespace(get_name=lambda: actual,
                    get_interfaces=lambda: ['Action'])
                self.assertEqual('SQL editor ' + title + detail, native_control_label(editor, labels))
                self.assertEqual(actual, native_control_label(profile, labels))
        self.assertEqual('SQL editor ' + title + detail,
                         native_sql_editor_label('SQL editor ' + title + detail, {}))
        self.assertEqual('SQL editor', native_sql_editor_announcement({}))
        self.assertEqual('SQL-Editor', native_sql_editor_announcement(
            {'SQL editor {title}': 'SQL-Editor {title}'}))
        with self.assertRaisesRegex(RuntimeError, 'template'):
            native_sql_editor_label(title, {'SQL editor {title}': '{title}'})

    def test_native_message_keys_distinguish_equal_english_labels_and_keep_fallback(self):
        english = {'metadataOptions': 'Options', 'optionsSettings': 'Options',
                   'generalSettings': 'General'}
        translated = {'metadataOptions': 'Optionen', 'generalSettings': 'Allgemein'}
        def contents(path):
            return json.dumps({'app_en.arb': english, 'app_de.arb': translated,
                               'case.json': {'language': 'de'}}[path.name])
        with patch.dict('os.environ', {'BUSYDATA_NATIVE_SETTINGS_INPUT': '/tmp/case.json'}), \
                patch('native_workbench_acceptance.Path.read_text', autospec=True, side_effect=contents):
            self.assertEqual('Optionen', native_catalog_labels()['Options'])
            self.assertEqual('Options', native_catalog_message('optionsSettings'))
            self.assertEqual('Optionen', native_catalog_message('metadataOptions'))
            self.assertEqual('Allgemein', native_catalog_message('generalSettings'))

    def test_grid_menu_keeps_its_header_scope_after_sort_tooltip_updates(self):
        for caption, parents in (
            ('More', ['Row selection']),
            ('Row selection\nMore · id Descending', []),
            ('Row selection\nGrid actions · id Descending\nMore · id Descending', []),
            ('More · id Descending', ['Row selection\nGrid actions · id Descending']),
        ):
            self.assertTrue(scoped_grid_menu_caption(caption, parents))
        self.assertFalse(scoped_grid_menu_caption('More', ['Application menu']))
        self.assertFalse(scoped_grid_menu_caption('Row 1, n: More', ['Row selection']))

    def test_arabic_settings_heading_does_not_replace_connection_menu_identity(self):
        with tempfile.TemporaryDirectory() as root:
            settings = Path(root) / 'settings.json'
            settings.write_text(json.dumps({'language': 'ar'}))
            with patch.dict('os.environ', {'BUSYDATA_NATIVE_SETTINGS_INPUT': str(settings)}):
                labels = native_catalog_labels()
            self.assertEqual('اتصال', labels['Connection'])


    def test_owned_session_inspection_awaits_visible_dialog_rows(self):
        def node(showing):
            return types.SimpleNamespace(
                get_name=lambda: 'Connection management B · 12345678-1234-1234-1234-123456789abc · Development',
                get_state_set=lambda: types.SimpleNamespace(contains=lambda _: showing))
        hidden, visible = node(False), node(True)
        snapshots = iter([[], [hidden], [visible]])
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(SHOWING='showing'))
        def wait(predicate):
            for _ in range(3):
                value = predicate()
                if value: return value
            raise TimeoutError('Dialog rows did not appear')
        self.assertEqual([visible], wait_native_owned_session_nodes(atspi, lambda: next(snapshots), wait))

    def test_owned_session_inspection_does_not_acknowledge_missing_rows(self):
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(SHOWING='showing'))
        def wait(predicate):
            if predicate(): raise AssertionError('Unexpected dialog acknowledgement')
            raise TimeoutError('Dialog rows did not appear')
        with self.assertRaises(TimeoutError):
            wait_native_owned_session_nodes(atspi, lambda: [], wait)

    def test_explorer_context_pointer_uses_revealed_current_row(self):
        focused = [False]

        def row():
            return types.SimpleNamespace(clear_cache=lambda: None,
                get_interfaces=lambda: [],
                get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: flag != 'focused' or focused[0]))

        old, current = row(), row()
        frame = types.SimpleNamespace(get_role=lambda: 'frame')

        def grab_focus(_):
            focused[0] = True

        atspi = types.SimpleNamespace(
            StateType=types.SimpleNamespace(FOCUSED='focused',VISIBLE='visible',SHOWING='showing'),
            Role=types.SimpleNamespace(FRAME='frame'),
            CoordType=types.SimpleNamespace(SCREEN='screen'),
            Component=types.SimpleNamespace(grab_focus=grab_focus,
                get_extents=lambda item, _: types.SimpleNamespace(x=0, y=0, width=1280, height=800)
                    if item is frame else types.SimpleNamespace(
                        x=20, y=200 if item is current else 620, width=100, height=32)))

        def wait(predicate):
            for _ in range(8):
                value = predicate()
                if value:
                    return value
            raise TimeoutError('Row not revealed')

        calls = []
        with patch('native_workbench_acceptance.accessible_ancestors', return_value=[frame]), \
                patch('native_workbench_acceptance.native_display_scale', return_value=1):
            right_click_native_row(atspi, lambda: current if focused[0] else old, wait, calls.append)
        self.assertEqual([['xdotool', 'mousemove', '70', '216', 'click', '3']], calls)

    def test_explorer_context_pointer_refuses_clipped_row(self):
        frame = types.SimpleNamespace(get_role=lambda: 'frame')
        row = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda _: True))
        atspi = types.SimpleNamespace(
            StateType=types.SimpleNamespace(FOCUSED='focused',VISIBLE='visible',SHOWING='showing'),
            Role=types.SimpleNamespace(FRAME='frame'),
            CoordType=types.SimpleNamespace(SCREEN='screen'),
            Component=types.SimpleNamespace(get_extents=lambda item, _: types.SimpleNamespace(
                x=0, y=0, width=1280, height=800) if item is frame else types.SimpleNamespace(
                    x=20, y=-32, width=100, height=32)))

        def wait(predicate):
            for _ in range(4):
                value = predicate()
                if value:
                    return value
            raise TimeoutError('Clipped row')

        calls = []
        with patch('native_workbench_acceptance.accessible_ancestors', return_value=[frame]), \
                patch('native_workbench_acceptance.native_display_scale', return_value=1):
            with self.assertRaises(TimeoutError):
                right_click_native_row(atspi, lambda: row, wait, calls.append)
        self.assertEqual([], calls)

    def test_multiline_sql_inspection_reads_both_bounded_lines_and_rejects_changed_text(self):
        lines = ['-- meaningful offline target', 'SELECT current_database();']
        position = [1]
        atspi = types.SimpleNamespace(Text=types.SimpleNamespace(
            get_text=lambda *args: lines[position[0]]))
        editor = types.SimpleNamespace(get_name=lambda: 'SQL editor Untitled query\nVisible SQL line ' + str(position[0] + 1) + ' of ' + str(len(lines)) + ', column 1')
        calls = []
        def command(argv):
            calls.append(argv[-1])
            position[0] = {'ctrl+Home': 0, 'Down': position[0] + 1,
                           'ctrl+End': len(lines) - 1}[argv[-1]]
        def wait(predicate):
            if not predicate(): raise TimeoutError('SQL line differs')
        expected = '\n'.join(lines)
        verify_native_sql_lines(atspi, lambda: editor, expected, wait, command)
        self.assertEqual(['ctrl+Home', 'Down', 'ctrl+End'], calls)
        self.assertEqual(1, position[0])
        lines[0] = '-- changed offline target'
        with self.assertRaises(TimeoutError):
            verify_native_sql_lines(atspi, lambda: editor, expected, wait, command)
        with self.assertRaises(ValueError):
            verify_native_sql_lines(atspi, lambda: editor, '\n' * 64, wait, command)

    def test_multiline_native_navigation_waits_for_acknowledged_authored_window(self):
        ready = [False]
        position = [0]
        lines = ['-- offline target', 'SELECT 31;']
        editor = types.SimpleNamespace(get_name=lambda: 'SQL editor\nVisible SQL line ' +
            str(position[0] + 1) + ' of ' + ('2' if ready[0] else '1') + ', column 1')
        atspi = types.SimpleNamespace(Text=types.SimpleNamespace(
            get_text=lambda *args: lines[position[0]] if ready[0] else 'old input'))
        def wait(predicate):
            if not predicate(): ready[0] = True
            if not predicate(): raise TimeoutError('Authored line unavailable')
        def command(argv):
            self.assertTrue(ready[0], 'Do not navigate an unacknowledged editor update')
            position[0] = 0 if argv[-1] == 'ctrl+Home' else 1
        verify_native_sql_lines(atspi, lambda: editor, '\n'.join(lines), wait, command)
        self.assertEqual(1, position[0])

    def test_selected_object_document_rejects_the_selected_explorer_row(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.StateType.SELECTED = 'selected'
        tree = Node('button', (0, 0, 40, 30), name='native_atspi_fixture · level 5 · source/db/public')
        document = Node('button', (40, 0, 80, 30), name='native_atspi_fixture · Completed')
        tree.states.add('selected')
        self.assertIsNone(find_selected_object_document(atspi, [tree, document], 'native_atspi_fixture', lambda node: node.get_name()))
        document.states.add('selected')
        self.assertEqual('native_atspi_fixture', find_selected_object_document(atspi, [tree, document], 'native_atspi_fixture', lambda node: node.get_name()))
        document.states.discard('selected')
        child = Node('button', (120, 0, 80, 30), name='native_atspi_child · Completed\nsource · catalog / native_atspi_child')
        child.states.add('selected')
        self.assertIsNone(find_selected_object_document(atspi, [tree, document, child], 'native_atspi_fixture', lambda node: node.get_name()))
        self.assertEqual('native_atspi_child', find_selected_object_document(atspi, [tree, document, child], 'native_atspi_child', lambda node: node.get_name()))

    def test_failed_native_child_read_restarts_without_raising_the_node_budget(self):
        class Node:
            def __init__(self, children=(), failures=0):
                self.children, self.failures, self.reads = list(children), failures, 0
            def clear_cache(self): self.reads += 1
            def get_child_count(self):
                if self.failures:
                    self.failures -= 1
                    return -1
                return len(self.children)
            def get_child_at_index(self, index): return self.children[index]
        child = Node(failures=1)
        application = Node([child])
        self.assertEqual([application, child], fresh_accessible_objects(application))
        self.assertEqual(2, application.reads)
        child.failures = 3
        with self.assertRaises(NativeSnapshotIncomplete): fresh_accessible_objects(application)
        application.children = [child] * 513
        with self.assertRaises(NativeNodeBudgetExceeded) as exceeded:
            fresh_accessible_objects(application)
        self.assertEqual(513, exceeded.exception.child_count)
        self.assertEqual(512, exceeded.exception.limit)
        application.children = [None]
        with self.assertRaises(NativeSnapshotIncomplete): fresh_accessible_objects(application)

    def test_new_console_acknowledgement_rejects_previous_selected_tab(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.StateType.SELECTED = 'selected'
        old = Node('button', (0, 0, 40, 30), name='● Query 3 · Running')
        old.states.add('selected')
        new = Node('button', (40, 0, 40, 30), name='Query 4')
        self.assertIsNone(find_new_selected_query(atspi, [old, new], {'Query 3'}, lambda node: node.get_name()))
        new.states.add('selected')
        self.assertEqual('Query 4', find_new_selected_query(atspi, [old, new], {'Query 3'}, lambda node: node.get_name()))
        new.states.remove('showing')
        self.assertIsNone(find_new_selected_query(atspi, [old, new], {'Query 3'}, lambda node: node.get_name()))

    def test_grid_menu_acknowledgement_requires_the_actual_popup_after_toolbar_reflow(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.Role.MENU = 'menu'
        toolbar = Node('button',(0,0,40,30),actions=['Tap'],name='Filter')
        self.assertIsNone(find_grid_menu_destination(atspi,[toolbar],'Filter',{toolbar}))
        popup = Node('menu',(0,40,80,100))
        self.assertIsNone(find_grid_menu_destination(atspi,[toolbar,popup],'Filter',{toolbar}))
        self.assertIsNone(find_grid_menu_destination(atspi,[toolbar],'Filter',{toolbar},fluent=True))
        entry = Node('menu-item',(0,40,80,30),actions=['click'],name='Filter')
        self.assertEqual('menu',find_grid_menu_destination(atspi,[toolbar,popup,entry],'Filter',{toolbar})[0])

    def keyboard_grid_popup_fixture(self, *, acknowledge_focus=True, selected_count=1,
                                    wrong_selected_child=False, nested=False):
        atspi, _, _, frame, Node = self.protected_field_fixture()
        atspi.Role.MENU = 'menu'
        menu = Node('menu', (10, 20, 100, 120), frame)
        menu.interfaces.append('Selection')
        nodes = [frame, menu]
        if nested:
            outer = Node('menu', (10, 20, 200, 240), frame)
            outer.interfaces.append('Selection')
            menu.parent = outer
            nodes.append(outer)
        entry = Node('menu-item', (10, 30, 100, 24), menu,
                     actions=['focus', 'tap'], name='Filter')
        nodes.append(entry)
        other = Node('menu-item', (10, 60, 100, 24), menu, name='Other')
        state = {'selected': None}
        events = []

        def focus(item, index):
            self.assertIs(entry, item)
            self.assertEqual(0, index)
            events.append('focus request')
            if acknowledge_focus:
                entry.states.add('focused')
            return True

        def count(item):
            self.assertIs(menu, item)
            events.append('selection count')
            return selected_count if state['selected'] is not None else 0

        def selected(item, index):
            self.assertIs(menu, item)
            self.assertEqual(0, index)
            events.append('selected child')
            return state['selected']

        atspi.Action.do_action = focus
        atspi.Selection = types.SimpleNamespace(get_n_selected_children=Mock(side_effect=count),
            get_selected_child=Mock(side_effect=selected))

        def command(arguments):
            key = arguments[-1]
            self.assertEqual(['xdotool', 'key', '--clearmodifiers'], arguments[:-1])
            events.append(key)
            if key == 'Down':
                state['selected'] = other if wrong_selected_child else entry
            elif key == 'Return':
                self.assertTrue('focused' in entry.states or state['selected'] is entry)
                nodes[:] = [frame]
            else:
                self.fail('Unexpected keyboard action: ' + key)

        def wait(predicate):
            for _ in range(4):
                result = predicate()
                if result:
                    return result
            raise TimeoutError('Captured menu did not acknowledge keyboard destination')

        return types.SimpleNamespace(atspi=atspi, entry=entry, menu=menu, nodes=nodes,
            events=events, command=command, wait=wait, current_nodes=lambda: nodes, frame=frame, Node=Node)

    def test_fluent_menu_with_selection_uses_captured_focus_then_return_and_retirement(self):
        fixture = self.keyboard_grid_popup_fixture()
        activate_grid_menu_keyboard(fixture.atspi, fixture.entry, 'Filter', 'Filter', fixture.menu,
            fixture.current_nodes, fixture.wait, fixture.command, fluent=True)
        self.assertEqual(['focus request', 'Return'], fixture.events)
        fixture.atspi.Selection.get_n_selected_children.assert_not_called()
        fixture.atspi.Selection.get_selected_child.assert_not_called()
        self.assertEqual([fixture.frame], fixture.nodes)

    def test_fluent_menu_never_returns_before_actual_focus_acknowledgment(self):
        fixture = self.keyboard_grid_popup_fixture(acknowledge_focus=False)
        with self.assertRaises(TimeoutError):
            activate_grid_menu_keyboard(fixture.atspi, fixture.entry, 'Filter', 'Filter', fixture.menu,
                fixture.current_nodes, fixture.wait, fixture.command, fluent=True)
        self.assertNotIn('Return', fixture.events)
        self.assertNotIn('Down', fixture.events)
        fixture.atspi.Selection.get_n_selected_children.assert_not_called()

    def test_gtk_filter_keeps_down_exact_selected_child_then_return(self):
        fixture = self.keyboard_grid_popup_fixture()
        activate_grid_menu_keyboard(fixture.atspi, fixture.entry, 'Filter', 'Filter', fixture.menu,
            fixture.current_nodes, fixture.wait, fixture.command, fluent=False)
        self.assertEqual('Down', fixture.events[0])
        self.assertEqual('Return', fixture.events[-1])
        self.assertNotIn('focus request', fixture.events)
        fixture.atspi.Selection.get_n_selected_children.assert_called()
        fixture.atspi.Selection.get_selected_child.assert_called()
        self.assertEqual([fixture.frame], fixture.nodes)

    def test_gtk_filter_rejects_wrong_or_multiple_selected_children_without_return(self):
        for options in ({'selected_count': 2}, {'wrong_selected_child': True}):
            with self.subTest(options=options):
                fixture = self.keyboard_grid_popup_fixture(**options)
                with self.assertRaises(TimeoutError):
                    activate_grid_menu_keyboard(fixture.atspi, fixture.entry, 'Filter', 'Filter', fixture.menu,
                        fixture.current_nodes, fixture.wait, fixture.command, fluent=False)
                self.assertEqual(['Down'], [event for event in fixture.events if event in ('Down', 'Return')])
                self.assertNotIn('focus request', fixture.events)

    def test_keyboard_grid_rejects_wrong_caption_and_gtk_menu_ambiguity_before_actions(self):
        for fluent in (False, True):
            fixture = self.keyboard_grid_popup_fixture()
            fixture.entry.name = 'Other'
            with self.subTest(fluent=fluent), self.assertRaisesRegex(RuntimeError, 'caption changed'):
                activate_grid_menu_keyboard(fixture.atspi, fixture.entry, 'Filter', 'Filter', fixture.menu,
                    fixture.current_nodes, fixture.wait, fixture.command, fluent=fluent)
            self.assertEqual([], fixture.events)
        for nested, name in ((True, 'Filter'), (False, 'Sort')):
            fixture = self.keyboard_grid_popup_fixture(nested=nested)
            fixture.entry.name = name
            with self.subTest(nested=nested, name=name), self.assertRaisesRegex(RuntimeError, 'one captured Filter'):
                activate_grid_menu_keyboard(fixture.atspi, fixture.entry, name, name, fixture.menu,
                    fixture.current_nodes, fixture.wait, fixture.command, fluent=False)
            self.assertEqual([], fixture.events)

    def test_keyboard_grid_never_adopts_a_replacement_or_foreign_popup(self):
        for changed_owner in (False, True):
            fixture = self.keyboard_grid_popup_fixture()
            if changed_owner:
                foreign = fixture.Node('menu', (20, 20, 100, 100), fixture.frame)
                fixture.nodes.append(foreign)
                fixture.entry.parent = foreign
            else:
                replacement = fixture.Node('menu-item', (10, 30, 100, 24), fixture.menu,
                    actions=['focus', 'tap'], name='Filter')
                fixture.nodes.remove(fixture.entry)
                fixture.nodes.append(replacement)
            with self.subTest(changed_owner=changed_owner), self.assertRaisesRegex(RuntimeError, 'owner changed|retired'):
                activate_grid_menu_keyboard(fixture.atspi, fixture.entry, 'Filter', 'Filter', fixture.menu,
                    fixture.current_nodes, fixture.wait, fixture.command, fluent=True)
            self.assertEqual([], fixture.events)

    def test_grid_popup_acknowledgement_rejects_the_underlying_toolbar_action(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.Action.do_action = lambda *args: True
        toolbar = Node('button', (0, 0, 40, 30), actions=['Tap'], name='Refresh')
        menu = Node('menu-item', (0, 40, 80, 30), actions=['click'], name='Refresh')
        previous = {toolbar}
        self.assertIsNone(find_new_menu_activation(atspi, [toolbar], 'Refresh', previous))
        self.assertIs(menu, find_new_menu_activation(atspi, [toolbar, menu], 'Refresh', previous)[0])

    def test_fluent_menu_panel_requires_a_new_visible_actionable_entry(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.Action.do_action = lambda *args: True
        toolbar = Node('button', (0, 0, 100, 30), actions=['Tap'], name='New connection')
        entry = Node('panel', (100, 40, 200, 30), actions=['Tap'], name='New connection')
        previous = {toolbar}
        self.assertIsNone(find_new_menu_activation(atspi, [toolbar, entry], 'New connection', previous))
        self.assertIs(entry, find_new_menu_activation(atspi, [toolbar, entry], 'New connection', previous, fluent=True)[0])
        self.assertIsNone(find_new_menu_activation(atspi, [toolbar, entry], 'New connection', {toolbar, entry}, fluent=True))
        entry.states.remove('showing')
        self.assertIsNone(find_new_menu_activation(atspi, [toolbar, entry], 'New connection', previous, fluent=True))

    def test_fluent_menu_shortcut_must_match_the_requested_entry_exactly(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        atspi.Action.do_action = lambda *args: True
        toolbar = Node('button', (0, 0, 100, 30), actions=['Tap'], name='New query')
        entry = Node('panel', (100, 40, 200, 30), actions=['Tap'], name='New query\nCtrl+T')
        wrong = Node('panel', (100, 80, 200, 30), actions=['Tap'], name='New query\nCtrl+X')
        previous = {toolbar}
        self.assertIs(entry, find_new_menu_activation(atspi, [toolbar, entry, wrong], 'New query', previous, fluent=True, shortcut='Ctrl+T')[0])
        self.assertIsNone(find_new_menu_activation(atspi, [toolbar, wrong], 'New query', previous, fluent=True, shortcut='Ctrl+T'))
        self.assertIsNone(find_new_menu_activation(atspi, [toolbar, entry], 'New query', previous, fluent=True))
        self.assertIsNone(find_new_menu_activation(atspi, [toolbar, entry], 'New query', {toolbar, entry}, fluent=True, shortcut='Ctrl+T'))

    def test_native_pointer_converts_logical_bounds_to_physical_pixels_once(self):
        bounds = types.SimpleNamespace(x=40, y=60, width=100, height=30)
        calls = []
        with patch('native_workbench_acceptance.native_display_scale', return_value=2):
            pointer_at_native_bounds(calls.append, bounds, repeat=2)
        self.assertEqual([['xdotool', 'mousemove', '180', '150', 'click',
                          '--repeat', '2', '--delay', '120', '1']], calls)

    def test_supplementary_rendering_cannot_replace_ordinary_acceptance_reports(self):
        self.assertEqual('native-accessibility-linux.json', native_report_name('POSTGRESQL'))
        self.assertEqual('native-accessibility-mysql.json', native_report_name('MYSQL'))
        self.assertEqual('native-accessibility-mariadb.json', native_report_name('MARIADB'))
        ordinary = native_report_name('MYSQL', ordinary_mysql=True)
        self.assertEqual('native-accessibility-mysql-ordinary.json', ordinary)
        self.assertNotEqual(native_report_name('MYSQL'), ordinary)
        for engine in ('POSTGRESQL', 'MARIADB'):
            with self.assertRaises(ValueError):
                native_report_name(engine, ordinary_mysql=True)
        for options in ({'rendering_only': 'fluent'}, {'platform_case': 'light'},
                        {'database_explorer': True}, {'database_explorer_local': True},
                        {'database_explorer_tools': True}, {'connection_management_only': True}):
            with self.assertRaises(ValueError):
                native_report_name('MYSQL', ordinary_mysql=True, **options)
        for engine in ('POSTGRESQL','MYSQL','MARIADB'):
            self.assertEqual('native-database-explorer-' + engine.lower() + '.json',
                native_report_name(engine, database_explorer=True))
            self.assertNotEqual(native_report_name(engine), native_report_name(engine, database_explorer=True))
            local = native_report_name(engine, database_explorer_local=True)
            self.assertEqual('native-database-explorer-local-' + engine.lower() + '.json', local)
            self.assertNotEqual(native_report_name(engine), local)
            self.assertNotEqual(native_report_name(engine, database_explorer=True), local)
        for engine in ('POSTGRESQL', 'MYSQL', 'MARIADB'):
            tools = native_report_name(engine, database_explorer_tools=True)
            self.assertEqual('native-database-explorer-tools-' + engine.lower() + '.json', tools)
            self.assertNotEqual(native_report_name(engine), tools)
            self.assertNotEqual(native_report_name(engine, database_explorer=True), tools)
            self.assertNotEqual(native_report_name(engine, database_explorer_local=True), tools)
        for kwargs in ({'database_explorer': True}, {'database_explorer_local': True}, {'rendering_only': 'fluent'}):
            with self.assertRaises(ValueError): native_report_name('POSTGRESQL', database_explorer_tools=True, **kwargs)
        with self.assertRaises(ValueError): native_report_name('POSTGRESQL', 'fluent', database_explorer_local=True)
        with self.assertRaises(ValueError): native_report_name('POSTGRESQL', database_explorer=True, database_explorer_local=True)
        with self.assertRaises(ValueError): native_report_name('POSTGRESQL', 'fluent', database_explorer=True)
        for scope in ('fluent', 'platform'):
            self.assertNotEqual(native_report_name('POSTGRESQL'), native_report_name('POSTGRESQL', scope))
            with self.assertRaises(ValueError): native_report_name('MYSQL', scope)

    def test_pointer_geometry_waits_for_focused_row_reveal_and_stability(self):
        def box(y): return types.SimpleNamespace(x=20, y=y, width=200, height=32)
        frame = types.SimpleNamespace(get_role=lambda: 'frame')
        row = types.SimpleNamespace(clear_cache=lambda: None)
        positions = iter([box(-32), box(70), box(100), box(100)])
        window = types.SimpleNamespace(x=0, y=0, width=1366, height=768)
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(FRAME='frame'),
            CoordType=types.SimpleNamespace(SCREEN='screen'),
            Component=types.SimpleNamespace(get_extents=lambda item, _: window
                if item is frame else next(positions)))
        def wait(predicate):
            for _ in range(4):
                result = predicate()
                if result is not None: return result
            self.fail('Visible pointer geometry was not acknowledged')
        with patch('native_workbench_acceptance.accessible_ancestors', return_value=[frame]):
            self.assertEqual(100, visible_native_bounds(atspi, lambda: row, wait).y)

    def test_native_menu_viewport_uses_measured_gdk_screen_dimensions(self):
        import native_workbench_acceptance as native
        root = types.SimpleNamespace(get_width=lambda: 1920, get_height=lambda: 1080)
        gdk = types.SimpleNamespace(get_default_root_window=lambda: root)
        gi = types.SimpleNamespace(require_version=lambda *args: None)
        with patch.dict('sys.modules', {'gi': gi,
                'gi.repository': types.SimpleNamespace(Gdk=gdk)}):
            bounds = native.native_menu_screen_bounds()
        self.assertEqual((0, 0, 1920, 1080),
                         (bounds.x, bounds.y, bounds.width, bounds.height))

    def test_nested_gtk_menu_pointer_uses_desktop_not_heading_row_bounds(self):
        # Captured from the ordinary GTK host: the child popup opens to the
        # right of its root menu and inherits the heading as its MENU ancestor.
        heading = types.SimpleNamespace(get_role=lambda: 'menu',
            get_state_set=lambda: types.SimpleNamespace(contains=lambda _: True))
        desktop = types.SimpleNamespace(get_role=lambda: 'desktop')
        entry = types.SimpleNamespace(clear_cache=lambda: None)
        boxes = {id(heading): (1125, 130, 161, 27),
                 id(desktop): (0, 0, 1920, 1080),
                 id(entry): (1284, 131, 393, 27)}
        def extents(item, _):
            x, y, width, height = boxes[id(item)]
            return types.SimpleNamespace(x=x, y=y, width=width, height=height)
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(FRAME='frame', MENU='menu', DESKTOP_FRAME='desktop'),
            StateType=types.SimpleNamespace(SHOWING='showing'),
            CoordType=types.SimpleNamespace(SCREEN='screen'),
            Component=types.SimpleNamespace(get_extents=extents))
        def wait(predicate):
            predicate()
            return predicate()
        with patch('native_workbench_acceptance.accessible_ancestors', return_value=[heading, desktop]), \
                patch('native_workbench_acceptance.native_menu_screen_bounds', return_value=extents(desktop, None)):
            self.assertEqual(1284, visible_native_bounds(atspi, lambda: entry, wait).x)
            boxes[id(entry)] = (1850, 131, 393, 27)
            self.assertIsNone(visible_native_bounds(atspi, lambda: entry, wait))

    def test_catalog_fixture_readiness_checks_stored_unicode_bytes_and_both_rows(self):
        self.assertTrue(catalog_fixture_rows_match('1\tE6BCA2F09F9880\n2\t7365636F6E64\n'))
        for value in ['', '1\tE6BCA2F09F9880\n', '1\tC3A6C2BCC2A2C3B0C5B8CB9CE282AC\n2\t7365636F6E64\n']:
            self.assertFalse(catalog_fixture_rows_match(value))

    def test_native_gtk_menu_pointer_requires_showing_menu_and_screen_bounds(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        atspi.Role.MENU = 'menu'
        atspi.CoordType.SCREEN = 'screen'
        application = Node('application', (0, 0, 0, 0))
        popup = Node('menu', (100, 80, 200, 240), application)
        entry = Node('menu-item', (102, 90, 196, 30), popup, actions=['click'])
        def wait(predicate):
            for _ in range(3):
                result = predicate()
                if result is not None: return result
        screen = types.SimpleNamespace(x=0, y=0, width=1920, height=1080)
        with patch('native_workbench_acceptance.native_menu_screen_bounds', return_value=screen):
            self.assertEqual(90, visible_native_bounds(atspi, lambda: entry, wait).y)
        # A real screen edge still rejects an inaccessible pointer target.
        entry.bounds = (1850, 310, 196, 30)
        with patch('native_workbench_acceptance.native_menu_screen_bounds', return_value=screen):
            self.assertIsNone(visible_native_bounds(atspi, lambda: entry, wait))
        entry.bounds = (102, 90, 196, 30)
        popup.states.remove('showing')
        with self.assertRaisesRegex(RuntimeError, 'visible window or menu viewport'):
            visible_native_bounds(atspi, lambda: entry, wait)

    def test_inline_commit_waits_for_current_native_text_acknowledgement(self):
        def node(name):
            return types.SimpleNamespace(name=name, clear_cache=lambda: None,
                get_role=lambda: 'entry',
                get_interfaces=lambda: ['Text', 'EditableText'],
                get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state != 'read-only'))
        original, live = node('original'), node('live')
        dispatches, reads = [], []
        values = iter(['reviewed native edit', 'reviewed native edit', '漢😀'])
        def text(item, start, end):
            reads.append(item.name)
            return next(values)
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry'),
            StateType=types.SimpleNamespace(FOCUSED='focused', SHOWING='showing',
                SENSITIVE='sensitive', EDITABLE='editable', READ_ONLY='read-only'),
            Text=types.SimpleNamespace(get_text=text),
            EditableText=types.SimpleNamespace(set_text_contents=lambda item, value:
                dispatches.append((item.name, value)) or True))
        def wait(predicate):
            for _ in range(4):
                answer = predicate()
                if answer: return answer
            raise TimeoutError('Native text not acknowledged')
        with patch('native_workbench_acceptance.focus_visible_native_field', return_value=original):
            self.assertIs(live, set_native_inline_text(atspi, lambda: live, '漢😀', wait))
        self.assertEqual([('original', '漢😀')], dispatches)
        self.assertEqual(['live', 'live', 'live'], reads)

    def test_inline_text_timeout_does_not_repeat_the_local_edit(self):
        item = types.SimpleNamespace(clear_cache=lambda: None, get_role=lambda: 'entry',
            get_interfaces=lambda: ['Text', 'EditableText'],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state != 'read-only'))
        dispatches = []
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry'),
            StateType=types.SimpleNamespace(FOCUSED='focused', SHOWING='showing',
                SENSITIVE='sensitive', EDITABLE='editable', READ_ONLY='read-only'),
            Text=types.SimpleNamespace(get_text=lambda *args: 'reviewed native edit'),
            EditableText=types.SimpleNamespace(set_text_contents=lambda node, value:
                dispatches.append(value) or True))
        def wait(predicate):
            for _ in range(4):
                if predicate(): return True
            raise TimeoutError('Native text not acknowledged')
        with patch('native_workbench_acceptance.focus_visible_native_field', return_value=item):
            with self.assertRaises(TimeoutError):
                set_native_inline_text(atspi, lambda: item, '漢😀', wait)
        self.assertEqual(['漢😀'], dispatches)

    def test_rejected_inline_edit_fails_before_commit_acknowledgement(self):
        item = types.SimpleNamespace(get_role=lambda: 'entry', get_interfaces=lambda: ['Text', 'EditableText'],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state != 'read-only'))
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry'),
            StateType=types.SimpleNamespace(FOCUSED='focused', SHOWING='showing',
                SENSITIVE='sensitive', EDITABLE='editable', READ_ONLY='read-only'),
            EditableText=types.SimpleNamespace(set_text_contents=lambda *args: False))
        def wait(predicate): self.fail('Rejected edit must not be acknowledged')
        with patch('native_workbench_acceptance.focus_visible_native_field', return_value=item):
            with self.assertRaisesRegex(RuntimeError, 'rejected its local edit'):
                set_native_inline_text(atspi, lambda: item, '漢😀', wait)

    def test_inline_edit_rejects_legacy_text_and_other_native_roles_before_dispatch(self):
        for role in ('text', 'password-text', 'panel'):
            with self.subTest(role=role):
                item = types.SimpleNamespace(get_role=lambda: role,
                    get_interfaces=lambda: ['Text', 'EditableText'],
                    get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state != 'read-only'))
                dispatched = []
                atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry'),
                    StateType=types.SimpleNamespace(FOCUSED='focused', SHOWING='showing',
                        SENSITIVE='sensitive', EDITABLE='editable', READ_ONLY='read-only'),
                    EditableText=types.SimpleNamespace(set_text_contents=lambda *_: dispatched.append(True)))
                with patch('native_workbench_acceptance.focus_visible_native_field', return_value=item), \
                     self.assertRaisesRegex(RuntimeError, 'native ENTRY'):
                    set_native_inline_text(atspi, lambda: item, '漢😀', lambda _: self.fail('No acknowledgement after rejection'))
                self.assertEqual([], dispatched)

    def test_inline_entry_rejects_missing_interfaces_unfocused_hidden_or_readonly_state(self):
        for missing in ('focused', 'showing', 'sensitive', 'editable', 'Text', 'EditableText', 'read-only'):
            with self.subTest(missing=missing):
                item = types.SimpleNamespace(get_role=lambda: 'entry',
                    get_interfaces=lambda: [name for name in ('Text', 'EditableText') if name != missing],
                    get_state_set=lambda: types.SimpleNamespace(contains=lambda state:
                        (missing == 'read-only') if state == 'read-only' else state != missing))
                dispatched = []
                atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry'),
                    StateType=types.SimpleNamespace(FOCUSED='focused', SHOWING='showing',
                        SENSITIVE='sensitive', EDITABLE='editable', READ_ONLY='read-only'),
                    EditableText=types.SimpleNamespace(set_text_contents=lambda *_: dispatched.append(True)))
                with patch('native_workbench_acceptance.focus_visible_native_field', return_value=item), \
                     self.assertRaisesRegex(RuntimeError, 'native ENTRY'):
                    set_native_inline_text(atspi, lambda: item, '漢😀', lambda _: self.fail('No acknowledgement after rejection'))
                self.assertEqual([], dispatched)

    def test_readonly_sql_preview_requires_owned_entry_and_exact_readonly_text(self):
        text, reads = 'SELECT 漢😀;', []
        values = {'name': 'SQL', 'role': 'entry',
            'states': {'readonly', 'showing', 'visible'}, 'interfaces': ['Text']}
        item = types.SimpleNamespace(get_name=lambda: values['name'], get_role=lambda: values['role'],
            get_interfaces=lambda: values['interfaces'],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state in values['states']))
        def read(_item, start, end):
            reads.append((start, end))
            return text[start:end]
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry', PASSWORD_TEXT='password'),
            StateType=types.SimpleNamespace(READ_ONLY='readonly', SHOWING='showing', VISIBLE='visible', EDITABLE='editable'),
            Text=types.SimpleNamespace(get_character_count=lambda _: len(text), get_text=read))
        for interfaces in (['Text'], ['Text', 'EditableText']):
            values['interfaces'] = interfaces
            self.assertEqual(text, native_readonly_sql_preview(atspi, item, lambda node: node.get_name()))
        self.assertEqual([(0, 10), (0, 10)], reads)
        for change in ({'role': 'text'}, {'role': 'password'}, {'name': 'Other'}, {'interfaces': ['EditableText']},
                       {'states': {'showing', 'visible'}}, {'states': {'readonly', 'visible'}},
                       {'states': {'readonly', 'showing'}}, {'states': {'readonly', 'showing', 'visible', 'editable'}}):
            with self.subTest(change=change):
                previous = dict(values)
                values.update(change)
                self.assertIsNone(native_readonly_sql_preview(atspi, item, lambda node: node.get_name()))
                values.clear(); values.update(previous)
        self.assertEqual(2, len(reads))

    def test_picker_paste_waits_for_the_owned_location_and_clear(self):
        field = object()
        text = ['old filename']
        events = []
        atspi = types.SimpleNamespace(Text=types.SimpleNamespace(
            get_text=lambda *args: text[0]))
        def command(argv):
            events.append(argv)
            if 'BackSpace' in argv:
                text[0] = ''
        def wait(predicate):
            result = predicate()
            self.assertTrue(result)
            return result
        def paste(value, consumed):
            self.assertEqual('', text[0])
            self.assertFalse(consumed())
            text[0] = value
            self.assertTrue(consumed())
            events.append('paste acknowledged')
        with patch('verify_installed_snap.picker_location_field', return_value=field), \
                patch('verify_installed_snap.paste_gtk_text', side_effect=paste):
            self.assertIs(field, paste_native_picker_path(atspi, '101', '/owned/result.csv', wait, command))
        self.assertEqual('paste acknowledged', events[-1])
        self.assertEqual('ctrl+l', events[1][-1])

    def test_picker_paste_cannot_use_an_unfocused_or_other_window_field(self):
        def wait(predicate):
            if not predicate():
                raise TimeoutError('Owned location unavailable')
        with patch('verify_installed_snap.picker_location_field', return_value=None), \
                patch('verify_installed_snap.paste_gtk_text') as paste:
            with self.assertRaises(TimeoutError):
                paste_native_picker_path(None, '101', '/owned/result.csv', wait, lambda _: None)
            paste.assert_not_called()

    def test_focused_clipped_native_field_waits_for_complete_stable_reveal(self):
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: True))
        geometry = iter([(65, 253, 510, 24), (65, 225, 510, 35),
                         (65, 223, 510, 35), (65, 223, 510, 35)])
        observed = []
        def bounds(node, coord):
            values = next(geometry); observed.append(values)
            return types.SimpleNamespace(**dict(zip(('x','y','width','height'), values)))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            CoordType=types.SimpleNamespace(WINDOW=1),
            Component=types.SimpleNamespace(get_extents=bounds),
            Text=types.SimpleNamespace(get_character_count=lambda node: 4,
                                     get_caret_offset=lambda node: 4))
        def wait(predicate):
            for _ in range(5):
                result = predicate()
                if result: return result
            raise TimeoutError('Native field did not reveal')
        with patch('native_workbench_acceptance._native_field_snapshot',
                   return_value=((17, '/owned/root', 1, 2), 1, 0)):
            self.assertIs(item, focus_visible_native_field(atspi, lambda: item, wait, 35))
        self.assertEqual(4, len(observed))

    def test_native_field_reveal_does_not_certify_invalid_editing_state(self):
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: True))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            CoordType=types.SimpleNamespace(WINDOW=1),
            Component=types.SimpleNamespace(get_extents=lambda node, coord:
                types.SimpleNamespace(x=65,y=223,width=510,height=35)),
            Text=types.SimpleNamespace(get_character_count=lambda node: 0,
                                     get_caret_offset=lambda node: -1))
        def wait(predicate):
            for _ in range(5):
                result = predicate()
                if result: return result
            raise TimeoutError('Native field did not reveal')
        with patch('native_workbench_acceptance._native_field_snapshot',
                   return_value=((17, '/owned/root', 1, 2), 1, 0)), self.assertRaises(TimeoutError):
            focus_visible_native_field(atspi, lambda: item, wait, 35)

    def test_hidden_page_marker_is_revealed_without_focus_or_activation(self):
        calls, visible = [], [False]
        node = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: visible[0]))
        def reveal(item, placement):
            calls.append((item, placement)); visible[0] = True; return True
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(VISIBLE=2,SHOWING=3),
            ScrollType=types.SimpleNamespace(ANYWHERE=6),
            Component=types.SimpleNamespace(scroll_to=reveal))
        waits = []
        def wait(predicate):
            waits.append(True)
            self.assertIsNone(predicate())
            return predicate()
        self.assertIs(node, wait_native_control_visible(atspi, lambda: node, wait))
        self.assertEqual([(node, 6)], calls)
        self.assertEqual([True], waits)

    def test_page_visibility_cannot_use_a_hidden_marker_or_repeat_reveal(self):
        calls = []
        node = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: False))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(VISIBLE=2,SHOWING=3),
            ScrollType=types.SimpleNamespace(ANYWHERE=6), Component=types.SimpleNamespace(
                scroll_to=lambda item, placement: calls.append('reveal') or True))
        def wait(predicate):
            for _ in range(4): self.assertIsNone(predicate())
            raise TimeoutError('Original page readiness deadline')
        with self.assertRaisesRegex(TimeoutError, 'Original page readiness deadline'):
            wait_native_control_visible(atspi, lambda: node, wait)
        self.assertEqual(['reveal'], calls)

    def test_page_visibility_preserves_lookup_owner_failures(self):
        def current(): raise ValueError('Connection form owner changed')
        with self.assertRaisesRegex(ValueError, 'Connection form owner changed'):
            wait_native_control_visible(None, current, lambda predicate: predicate())

    def test_connection_page_marker_can_find_its_hidden_eligible_checkbox(self):
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(CHECK_BOX='checkbox'),
            StateType=types.SimpleNamespace(SENSITIVE='sensitive'))
        control = types.SimpleNamespace(get_name=lambda:'Use SSL',
            get_interfaces=lambda:['Component'], get_role=lambda:'checkbox',
            get_state_set=lambda:types.SimpleNamespace(contains=lambda flag:flag=='sensitive'))
        self.assertEqual((True, control), native_connection_page_marker(atspi,
            [control], 'Use SSL', 'Component', lambda:[control]))
        self.assertEqual((True, None), native_connection_page_marker(atspi,
            [], 'Use SSL', 'Component', lambda:[]))

    def test_connection_page_marker_does_not_replace_a_disabled_control_with_absence(self):
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(CHECK_BOX='checkbox'),
            StateType=types.SimpleNamespace(SENSITIVE='sensitive'))
        control = types.SimpleNamespace(get_name=lambda:'Use SSL',
            get_interfaces=lambda:['Component'], get_role=lambda:'checkbox',
            get_state_set=lambda:types.SimpleNamespace(contains=lambda flag:False))
        self.assertEqual((False, None), native_connection_page_marker(atspi,
            [control], 'Use SSL', 'Component', lambda:[control]))

    def test_connection_page_marker_rejects_same_named_text_and_invalid_interfaces(self):
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(CHECK_BOX='checkbox'))
        control = types.SimpleNamespace(get_name=lambda:'Use SSL',
            get_interfaces=lambda:['Component'], get_role=lambda:'text')
        with self.assertRaisesRegex(RuntimeError, 'not its checkbox'):
            native_connection_page_marker(atspi,[control],'Use SSL','Component',lambda:[control])
        with self.assertRaises(ValueError):
            native_connection_page_marker(atspi,[],'Use SSL','Action',lambda:[])

    def test_hidden_control_reveals_once_then_focuses_its_current_visible_node(self):
        calls, state = [], {'focused': False}
        def node(name, visible):
            return types.SimpleNamespace(name=name, clear_cache=lambda: None,
                get_interfaces=lambda: [], get_state_set=lambda: types.SimpleNamespace(
                    contains=lambda flag: state['focused'] if flag == 1 else visible))
        hidden, visible = node('hidden', False), node('visible', True)
        current = iter((hidden, None, visible, visible))
        def focus(item):
            calls.append(('focus', item.name)); state['focused'] = True; return True
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            ScrollType=types.SimpleNamespace(ANYWHERE=6), Component=types.SimpleNamespace(
                scroll_to=lambda item, kind: calls.append(('reveal', item.name, kind)) or True,
                grab_focus=focus))
        def wait(predicate):
            for _ in range(4):
                value = predicate()
                if value: return value
            raise TimeoutError('Current visible focus missing')
        self.assertIs(visible, focus_live_native_control(atspi, lambda: next(current), wait))
        self.assertEqual([('reveal', 'hidden', 6), ('focus', 'visible')], calls)

    def test_reveal_acknowledgement_does_not_grant_focus_or_extend_the_deadline(self):
        calls, waits = [], []
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: False))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            ScrollType=types.SimpleNamespace(ANYWHERE=6), Component=types.SimpleNamespace(
                scroll_to=lambda node, kind: calls.append('reveal') or True,
                grab_focus=lambda node: self.fail('A hidden control cannot be focused')))
        def wait(predicate):
            waits.append(True)
            for _ in range(4): self.assertFalse(predicate())
            raise TimeoutError('Original focus deadline')
        with self.assertRaisesRegex(TimeoutError, 'Original focus deadline'):
            focus_live_native_control(atspi, lambda: item, wait)
        self.assertEqual(['reveal'], calls)
        self.assertEqual([True], waits)

    def test_rejected_reveal_is_not_replayed_or_replaced_with_a_hidden_focus(self):
        calls = []
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: False))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            ScrollType=types.SimpleNamespace(ANYWHERE=6), Component=types.SimpleNamespace(
                scroll_to=lambda node, kind: calls.append('reveal') or False,
                grab_focus=lambda node: self.fail('Rejected reveal cannot grant focus')))
        with self.assertRaisesRegex(RuntimeError, 'Native control reveal rejected'):
            focus_live_native_control(atspi, lambda: item, lambda predicate: predicate())
        self.assertEqual(['reveal'], calls)

    def test_owner_lookup_failure_after_reveal_cannot_focus_a_replacement(self):
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_state_set=lambda: types.SimpleNamespace(contains=lambda flag: False))
        calls = []
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            ScrollType=types.SimpleNamespace(ANYWHERE=6), Component=types.SimpleNamespace(
                scroll_to=lambda node, kind: calls.append('reveal') or True,
                grab_focus=lambda node: self.fail('Foreign owner cannot receive focus')))
        def current():
            if calls: raise ValueError('Captured modal owner changed')
            return item
        def wait(predicate):
            predicate(); return predicate()
        with self.assertRaisesRegex(ValueError, 'Captured modal owner changed'):
            focus_live_native_control(atspi, current, wait)
        self.assertEqual(['reveal'], calls)

    def test_virtualized_cell_focus_is_acknowledged_on_the_current_node(self):
        focused, requests, cache_reads = set(), [], []
        def node(name):
            return types.SimpleNamespace(name=name, clear_cache=lambda: cache_reads.append(name),
                get_interfaces=lambda: [],
                get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state != 1 or name in focused))
        obsolete, live = node('obsolete'), node('live')
        lookups = iter([obsolete, live, live])
        def request(item):
            requests.append(item.name)
            if item is live: focused.add('live')
            return True
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
                                     Component=types.SimpleNamespace(grab_focus=request))
        def wait(predicate):
            for _ in range(4):
                result = predicate()
                if result: return result
            raise TimeoutError('Native focus was not acknowledged')
        self.assertIs(live, focus_live_native_control(atspi, lambda: next(lookups), wait))
        self.assertEqual(['obsolete', 'live'], requests)
        self.assertEqual(['obsolete', 'live', 'live'], cache_reads)

    def test_flutter_focus_uses_explicit_action_without_tapping_or_component_focus(self):
        focused, calls = [False], []
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_interfaces=lambda: ['Action', 'Component'],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state != 1 or focused[0]))
        def action(node, index):
            calls.append(index)
            if index != 1: raise AssertionError('Focus must not activate Tap')
            focused[0] = True
            return True
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            Action=types.SimpleNamespace(get_n_actions=lambda node: 2,
                get_action_name=lambda node, index: ('Tap', 'Focus')[index], do_action=action),
            Component=types.SimpleNamespace(grab_focus=lambda node:
                self.fail('Generic Flutter Component focus is not implemented')))
        def wait(predicate):
            for _ in range(4):
                value = predicate()
                if value: return value
            raise TimeoutError('Native focus was not acknowledged')
        self.assertIs(item, focus_live_native_control(atspi, lambda: item, wait))
        focus_native_control(atspi, item, wait)
        self.assertEqual([1], calls)
        focused[0] = False
        atspi.Action.do_action = lambda node, index: True
        with self.assertRaises(TimeoutError):
            focus_native_control(atspi, item, wait)

    def test_native_focus_rejects_rejected_ambiguous_and_unbounded_actions(self):
        item = types.SimpleNamespace(get_interfaces=lambda: ['Action'])
        atspi = types.SimpleNamespace(Action=types.SimpleNamespace(
            get_n_actions=lambda node: 1,
            get_action_name=lambda node, index: 'Focus',
            do_action=lambda node, index: False))
        with self.assertRaisesRegex(RuntimeError, 'Focus action rejected'):
            request_native_focus(atspi, item)
        atspi.Action.get_n_actions = lambda node: 2
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous native Focus'):
            request_native_focus(atspi, item)
        atspi.Action.get_n_actions = lambda node: 65
        with self.assertRaisesRegex(RuntimeError, 'action-count budget'):
            request_native_focus(atspi, item)

    def test_live_focus_request_does_not_substitute_for_actual_focus_or_hide_failures(self):
        item = types.SimpleNamespace(clear_cache=lambda: None,
            get_interfaces=lambda: [],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state != 1))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED=1,VISIBLE=2,SHOWING=3),
            Component=types.SimpleNamespace(grab_focus=lambda node: True))
        def wait(predicate):
            for _ in range(4):
                if predicate(): return True
            raise TimeoutError('Native focus was not acknowledged')
        with self.assertRaises(TimeoutError):
            focus_live_native_control(atspi, lambda: item, wait)
        def failed_lookup(): raise ValueError('Current native tree unavailable')
        with self.assertRaisesRegex(ValueError, 'Current native tree unavailable'):
            focus_live_native_control(atspi, failed_lookup, wait)

    def test_disposed_native_node_is_reacquired_only_after_a_fresh_tree_proves_removal(self):
        failure = RuntimeError('Native property read failed')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_name(): raise failure
        obsolete = types.SimpleNamespace(get_name=failed_name)
        live = types.SimpleNamespace(get_name=lambda: 'Find command',
                                     get_interfaces=lambda: ['EditableText'])
        reads = []
        def current(): reads.append(True); return [live]
        self.assertIsNone(find_live_control(None, [obsolete], 'Find command',
                                           'EditableText', current_nodes=current))
        self.assertEqual([True], reads)
        self.assertIs(live, find_live_control(None, [live], 'Find command',
                                             'EditableText', current_nodes=current))
        self.assertEqual([True], reads)
        # No native activation can occur on the disappearing snapshot.
        self.assertIsNone(find_live_activation(None, [obsolete], 'Run', current_nodes=current))

    def test_field_acknowledgement_waits_for_the_same_lookup_after_semantics_reflow(self):
        old = types.SimpleNamespace(text='previous')
        current = types.SimpleNamespace(text='native_atspi_child')
        fields = iter([old, None, None, current])
        reads = []
        def text(node, start, end):
            self.assertIsNotNone(node)
            reads.append(node)
            return node.text
        def wait(predicate):
            for _ in range(4):
                if predicate(): return True
            raise TimeoutError('Exact authored field value was not acknowledged')
        atspi = types.SimpleNamespace(Text=types.SimpleNamespace(get_text=text))
        self.assertTrue(wait_native_field_value(atspi, lambda: next(fields),
            'native_atspi_child', wait))
        self.assertEqual([old, current], reads)
        with self.assertRaises(TimeoutError):
            wait_native_field_value(atspi, lambda: old, 'native_atspi_child', wait)
        def failed_lookup(): raise ValueError('Native transport failed')
        with self.assertRaisesRegex(ValueError, 'Native transport failed'):
            wait_native_field_value(atspi, failed_lookup, 'native_atspi_child', wait)

    def test_editor_prefix_lookup_reacquires_only_disposed_nodes_and_rejects_ambiguity(self):
        failure = RuntimeError('Native property read failed')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_name(): raise failure
        obsolete = types.SimpleNamespace(get_name=failed_name)
        live = types.SimpleNamespace(get_name=lambda: 'SQL editor Untitled query\nVisible SQL line 1',
            get_interfaces=lambda: ['EditableText'])
        self.assertIsNone(find_live_control(None, [obsolete], 'SQL editor', 'EditableText',
            current_nodes=lambda: [live], name_prefix=True))
        self.assertIs(live, find_live_control(None, [live], 'SQL editor', 'EditableText',
            current_nodes=lambda: [live], name_prefix=True))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_live_control(None, [live, live], 'SQL editor', 'EditableText', name_prefix=True)
        with self.assertRaises(RuntimeError):
            find_live_control(None, [obsolete], 'SQL editor', 'EditableText',
                current_nodes=lambda: [obsolete], name_prefix=True)

    def test_control_absence_needs_complete_fresh_lookup_after_a_retired_property(self):
        failure = RuntimeError('Retired native property')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_name(): raise failure
        retired = types.SimpleNamespace(get_name=failed_name)
        palette = types.SimpleNamespace(get_name=lambda: 'Search actions…',
            get_interfaces=lambda: ['EditableText'])
        for fresh in ([palette], []):
            with self.subTest(paletteStillPresent=bool(fresh)):
                # A failed unrelated getter made this scan incomplete. Its fresh
                # retirement proof must never stand in for complete absence.
                self.assertFalse(native_control_absent(None, [retired, palette],
                    'Search actions…', 'EditableText', current_nodes=lambda: fresh))
        self.assertFalse(native_control_absent(None, [palette], 'Search actions…',
            'EditableText', current_nodes=lambda: [palette]))
        self.assertTrue(native_control_absent(None, [], 'Search actions…',
            'EditableText', current_nodes=lambda: []))
        for domain, code, fresh in (('atspi_error', 1, [retired]),
                                    ('atspi_error', 2, []), ('g-io-error-quark', 1, [])):
            failure.domain, failure.code = domain, code
            with self.subTest(domain=domain, code=code), self.assertRaises(RuntimeError) as raised:
                native_control_absent(None, [retired], 'Search actions…',
                    'EditableText', current_nodes=lambda: fresh)
            self.assertIs(failure, raised.exception)
        failure.domain, failure.code = 'atspi_error', 1
        def failed_tree(): raise ValueError('Fresh snapshot failed')
        with self.assertRaisesRegex(ValueError, 'Fresh snapshot failed'):
            native_control_absent(None, [retired], 'Search actions…',
                'EditableText', current_nodes=failed_tree)

    def test_startup_verdict_does_not_conflate_an_incomplete_lookup_with_either_surface(self):
        failure = RuntimeError('Retired startup property')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_name(): raise failure
        retired = types.SimpleNamespace(get_name=failed_name)
        editor = types.SimpleNamespace(get_name=lambda: 'SQL editor Query 1\nVisible SQL line',
            get_interfaces=lambda: ['EditableText'])
        for fresh in ([], [editor]):
            with self.subTest(editorPresent=bool(fresh)):
                self.assertIsNone(native_startup_editor_state(None, [retired], {},
                    current_nodes=lambda: fresh))
        self.assertEqual(('welcome', None), native_startup_editor_state(None, [], {}, current_nodes=lambda: []))
        self.assertEqual(('editor', editor), native_startup_editor_state(None, [editor], {}, current_nodes=lambda: [editor]))

    def test_retired_geometry_state_and_action_reads_invalidate_the_whole_poll(self):
        first, retired, last = object(), object(), object()
        failure = RuntimeError('Native observation failed')
        failure.domain, failure.code = 'atspi_error', 1
        reads = []
        def read(item):
            reads.append(item)
            if item is retired: raise failure
            return item
        self.assertIsNone(read_live_native_controls([first, retired, last], read,
            current_nodes=lambda: [first, last]))
        self.assertEqual([first, retired], reads)
        self.assertEqual([first, last], read_live_native_controls([first, last], read,
            current_nodes=lambda: [first, last]))
        for domain, code, fresh in (('atspi_error', 1, [retired]),
                                    ('atspi_error', 2, []), ('g-io-error-quark', 1, [])):
            failure.domain, failure.code = domain, code
            with self.subTest(domain=domain, code=code), self.assertRaises(RuntimeError) as raised:
                read_live_native_controls([retired], read, current_nodes=lambda: fresh)
            self.assertIs(failure, raised.exception)
        failure.domain, failure.code = 'atspi_error', 1
        def failed_tree(): raise ValueError('Fresh observation tree unavailable')
        with self.assertRaisesRegex(ValueError, 'Fresh observation tree unavailable'):
            read_live_native_controls([retired], read, current_nodes=failed_tree)

    def test_duplicate_close_dialog_titles_prove_presence_and_complete_absence_is_distinct(self):
        label = 'Close SQL tab'
        dialog = types.SimpleNamespace(get_name=lambda: label + ' Query 1')
        heading = types.SimpleNamespace(get_name=lambda: label + ' Query 1')
        failure = RuntimeError('Retired modal title')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_name(): raise failure
        retired = types.SimpleNamespace(get_name=failed_name)
        matches = lambda caption: caption.startswith(label)
        self.assertIs(True, native_caption_presence([dialog, heading], matches,
            current_nodes=lambda: [dialog, heading]))
        self.assertIs(True, native_caption_presence([dialog], matches,
            current_nodes=lambda: [dialog]))
        for fresh in ([], [dialog, heading]):
            self.assertIsNone(native_caption_presence([retired, dialog, heading], matches,
                current_nodes=lambda: fresh))
        self.assertIs(False, native_caption_presence([], matches, current_nodes=lambda: []))
        other = types.SimpleNamespace(get_name=lambda: 'Another modal')
        self.assertIs(False, native_caption_presence([other], matches, current_nodes=lambda: [other]))
        with self.assertRaises(RuntimeError) as raised:
            native_caption_presence([retired], matches, current_nodes=lambda: [retired])
        self.assertIs(failure, raised.exception)

    def test_localized_editor_lookup_guards_name_and_interface_without_second_read(self):
        root = Path(__file__).resolve().parents[1]
        failure = RuntimeError('Retired native interface')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_interfaces(): raise failure
        for language in ('en', 'de', 'ar'):
            with self.subTest(language=language):
                catalog = json.loads((root / ('lib/l10n/app_' + language + '.arb')).read_text())
                template = catalog['sqlEditorLabel']
                labels = {'SQL editor {title}': template}
                caption = template.replace('{title}', '日😀.sql') + '\n' + catalog['sqlVisibleLine']
                reads = []
                def read_once():
                    reads.append(1)
                    if len(reads) > 1: raise RuntimeError('Unexpected second native name read')
                    return caption
                live = types.SimpleNamespace(get_name=read_once, get_interfaces=lambda: ['EditableText'])
                self.assertIs(live, find_live_sql_editor(None, [live], labels, current_nodes=lambda: [live]))
                self.assertEqual(1, len(reads))
                retired = types.SimpleNamespace(get_name=lambda: caption, get_interfaces=failed_interfaces)
                self.assertIsNone(find_live_sql_editor(None, [retired], labels, current_nodes=lambda: [live]))
                with self.assertRaises(RuntimeError) as raised:
                    find_live_sql_editor(None, [retired], labels, current_nodes=lambda: [retired])
                self.assertIs(failure, raised.exception)
                malformed = types.SimpleNamespace(get_name=lambda: template.replace('{title}', ''),
                    get_interfaces=lambda: ['EditableText'])
                self.assertIsNone(find_live_sql_editor(None, [malformed], labels, current_nodes=lambda: [malformed]))

    def test_modal_editor_rebind_requires_same_heading_pid_value_focus_and_fresh_tree(self):
        atspi = types.SimpleNamespace(
            StateType=types.SimpleNamespace(FOCUSED='focused'),
            Text=types.SimpleNamespace(get_text=lambda item, *_: item.text))
        root = Path(__file__).resolve().parents[1]
        for language in ('en', 'de', 'ar'):
            with self.subTest(language=language):
                catalog = json.loads((root / ('lib/l10n/app_' + language + '.arb')).read_text())
                labels = {'SQL editor {title}': catalog['sqlEditorLabel']}
                heading = 'SQL editor 日😀.sql'
                def node(title='日😀.sql', text='SELECT 1;', pid=8123, focused=True):
                    return types.SimpleNamespace(
                        get_name=lambda: catalog['sqlEditorLabel'].replace('{title}', title) +
                            '\n' + catalog['sqlVisibleLine'].replace('{column}', '10'),
                        get_interfaces=lambda: ['EditableText', 'Text'],
                        get_process_id=lambda: pid, text=text,
                        get_state_set=lambda: types.SimpleNamespace(contains=lambda _: focused))
                current = node()
                rebind = lambda nodes, fresh: restored_native_sql_editor(atspi, nodes, labels,
                    heading, 'SELECT 1;', 8123, current_nodes=lambda: fresh)
                self.assertIs(current, rebind([current], [current]))
                self.assertIsNone(rebind([], []))
                wrong_value = node(text='Another draft')
                self.assertIsNone(rebind([wrong_value], [wrong_value]))
                unfocused = node(focused=False)
                self.assertIsNone(rebind([unfocused], [unfocused]))
                self.assertIsNone(rebind([current], []))
                with self.assertRaisesRegex(RuntimeError, 'another document'):
                    rebind([node(title='Other query.sql')], [])
                with self.assertRaisesRegex(RuntimeError, 'another application'):
                    rebind([node(pid=9999)], [])
                with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
                    rebind([current, node()], [current])

    def modal_sql_origin_fixture(self, *, title='日😀.sql', selected_title=None,
                                 caret=8, selections=((7, 9),), context=None,
                                 focused=True, text='SELECT 漢😀;', pid=8123):
        session = '00000000-1111-2222-3333-444444444444'
        context = context if context is not None else (
            'Native accessibility fixture · 127.0.0.1:5432/busydata · ' + session)
        states = lambda *values: types.SimpleNamespace(contains=lambda state: state in values)
        editor = types.SimpleNamespace(
            get_name=lambda: 'SQL editor ' + title + '\nVisible line; column 9',
            get_role=lambda: 'entry', get_process_id=lambda: pid,
            get_interfaces=lambda: ['EditableText', 'Text'],
            get_state_set=lambda: states('focused', 'showing') if focused else states('showing'),
            text=text, caret=caret, selections=selections)
        tab = types.SimpleNamespace(get_name=lambda: (selected_title or title) +
            ' · Transaction open · Completed\n' + context,
            get_role=lambda: 'button', get_state_set=lambda: states('showing', 'selected'))
        reads = []
        def read_text(node, start, end):
            reads.append((start, end))
            return node.text[start:end]
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(PUSH_BUTTON='button'),
            StateType=types.SimpleNamespace(SHOWING='showing', SELECTED='selected', FOCUSED='focused'),
            Text=types.SimpleNamespace(get_character_count=lambda node: len(node.text),
                get_text=read_text, get_caret_offset=lambda node: node.caret,
                get_n_selections=lambda node: len(node.selections),
                get_selection=lambda node, index: types.SimpleNamespace(
                    start_offset=node.selections[index][0], end_offset=node.selections[index][1])))
        nodes = [editor, tab]
        return atspi, editor, tab, nodes, reads

    def test_modal_sql_origin_captures_exact_scalar_state_and_required_session_context(self):
        atspi, editor, tab, nodes, reads = self.modal_sql_origin_fixture()
        origin = native_sql_editor_origin(atspi, editor, nodes, {}, lambda: nodes)
        self.assertEqual({'heading': 'SQL editor 日😀.sql', 'pid': 8123,
            'text': 'SELECT 漢😀;', 'caret': 8, 'selections': ((7, 9),),
            'document': '日😀.sql',
            'context': 'Native accessibility fixture · 127.0.0.1:5432/busydata · '
                '00000000-1111-2222-3333-444444444444',
            'sessionId': '00000000-1111-2222-3333-444444444444'}, origin)
        self.assertEqual([(0, 10)], reads)  # AT-SPI offsets are Unicode scalars.
        current = self.modal_sql_origin_fixture()
        self.assertIsNot(editor, current[1])
        self.assertEqual(origin, native_sql_editor_origin(current[0], current[1], current[3], {}, lambda: current[3]))
        for change in ({'caret': 9}, {'selections': ((7, 8),)},
                       {'context': 'Native accessibility fixture · 127.0.0.1:5432/other · '
                           '00000000-1111-2222-3333-444444444444'},
                       {'context': 'Native accessibility fixture · 127.0.0.1:5432/busydata · '
                           '00000000-1111-2222-3333-555555555555'}):
            with self.subTest(change=change):
                changed = self.modal_sql_origin_fixture(**change)
                self.assertNotEqual(origin, native_sql_editor_origin(changed[0], changed[1],
                    changed[3], {}, lambda: changed[3]))
        wrong = self.modal_sql_origin_fixture(selected_title='Other.sql')
        with self.assertRaisesRegex(RuntimeError, 'another selected document'):
            native_sql_editor_origin(wrong[0], wrong[1], wrong[3], {}, lambda: wrong[3])

    def test_modal_sql_origin_requires_complete_unique_selected_session_context(self):
        atspi, editor, tab, nodes, _ = self.modal_sql_origin_fixture()
        self.assertIsNone(native_sql_editor_origin(atspi, editor, [editor], {}, lambda: nodes))
        missing = self.modal_sql_origin_fixture(context='Native accessibility fixture · 127.0.0.1:5432/busydata')
        self.assertIsNone(native_sql_editor_origin(missing[0], missing[1], missing[3], {}, lambda: missing[3]))
        self.assertIsNone(native_sql_editor_origin(atspi, editor, nodes, {}, lambda: [tab]))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            native_sql_editor_origin(atspi, editor, nodes + [tab], {}, lambda: nodes)
        failure = RuntimeError('Selected tab retired')
        failure.domain, failure.code = 'atspi_error', 1
        def retired(): raise failure
        old = types.SimpleNamespace(get_role=retired)
        self.assertIsNone(native_sql_editor_origin(atspi, editor, nodes + [old], {}, lambda: nodes))
        with self.assertRaises(RuntimeError) as raised:
            native_sql_editor_origin(atspi, editor, nodes + [old], {}, lambda: nodes + [old])
        self.assertIs(failure, raised.exception)
        editor.get_name = retired
        with self.assertRaises(RuntimeError) as raised:
            native_sql_editor_origin(atspi, editor, nodes, {}, lambda: [])
        self.assertIs(failure, raised.exception)  # Cached editor reads stay strict.

    def test_modal_sql_origin_rejects_oversized_or_invalid_scalar_state(self):
        for change, error in (({'text': 'x' * 65537}, 'text budget'),
                              ({'caret': -1}, 'scalar editing bounds'),
                              ({'caret': 11}, 'scalar editing bounds'),
                              ({'selections': ((0, 0),) * 65}, 'scalar editing bounds'),
                              ({'selections': ((0, 11),)}, 'selection bounds'),
                              ({'selections': ((9, 7),)}, 'selection bounds')):
            with self.subTest(change=tuple(change)):
                fixture = self.modal_sql_origin_fixture(**change)
                with self.assertRaisesRegex(RuntimeError, error):
                    native_sql_editor_origin(fixture[0], fixture[1], fixture[3], {}, lambda: fixture[3])
        fixture = self.modal_sql_origin_fixture(focused=False)
        self.assertIsNone(native_sql_editor_origin(fixture[0], fixture[1], fixture[3], {}, lambda: fixture[3]))

    def palette_paste_fixture(self, *, sql=False):
        source = self.modal_sql_origin_fixture(focused=False) if sql else None
        atspi = source[0] if source else types.SimpleNamespace()
        atspi.Role = types.SimpleNamespace(PUSH_BUTTON='button')
        atspi.StateType = types.SimpleNamespace(**{name.upper(): name for name in
            ('focused', 'showing', 'visible', 'sensitive', 'editable', 'read_only', 'selected')})
        values = {'text': '', 'caption': 'Search actions…', 'pid': 8123,
            'states': {'focused', 'showing', 'visible', 'sensitive', 'editable'}}
        query = types.SimpleNamespace(clear_cache=lambda: None,
            get_name=lambda: values['caption'], get_process_id=lambda: values['pid'],
            get_role=lambda: 'entry', get_interfaces=lambda: ['EditableText', 'Text'],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state in values['states']))
        atspi.Text = types.SimpleNamespace(
            get_text=lambda node, start, end: values['text'] if node is query else node.text[start:end],
            get_character_count=lambda node: len(values['text']) if node is query else len(node.text),
            get_caret_offset=lambda node: node.caret,
            get_n_selections=lambda node: len(node.selections),
            get_selection=lambda node, index: types.SimpleNamespace(
                start_offset=node.selections[index][0], end_offset=node.selections[index][1]))
        atspi.EditableText = types.SimpleNamespace(set_text_contents=lambda *_: self.fail('Palette retried AT-SPI setText'))
        nodes = [query] + (source[3] if source else [])
        app = types.SimpleNamespace(get_process_id=lambda: 8123)
        events = []
        def wait(predicate):
            for _ in range(3):
                result = predicate()
                if result: return result
            raise TimeoutError('Exact native acknowledgement missing')
        def command(args, **kwargs):
            events.append('return' if args[-1] == 'Return' else 'windowfocus')
        def rows():
            events.append('rows')
            return True
        def paste(value, consumed):
            events.append('paste')
            values['text'] = value
            self.assertTrue(consumed())
            events.append('consumed')
        def window(*args):
            self.assertEqual(8123, args[-1])
            return 'owned-window'
        def run():
            paste_native_palette_command(atspi, app, lambda _: nodes, wait, command, {}, query,
                'Roll back transaction', rows, lambda: events.append('before-submit'))
        return types.SimpleNamespace(atspi=atspi, app=app, query=query, values=values,
            nodes=nodes, source=source, events=events, wait=wait, command=command,
            rows=rows, paste=paste, window=window, run=run)

    def test_palette_uses_one_primary_paste_and_one_return_after_exact_acknowledgements(self):
        for sql in (False, True):
            with self.subTest(sql=sql):
                fixture = self.palette_paste_fixture(sql=sql)
                def pasted(value, consumed):
                    fixture.paste(value, consumed)
                    if sql:
                        caption = fixture.source[2].get_name()
                        fixture.source[2].get_name = lambda: caption.replace('Completed', 'Running')
                with patch('native_workbench_acceptance.owned_product_window', side_effect=fixture.window), \
                     patch('verify_installed_snap.paste_gtk_text', side_effect=pasted) as paste:
                    fixture.run()
                self.assertEqual(1, paste.call_count)
                self.assertEqual(['windowfocus', 'paste', 'consumed', 'rows',
                    'windowfocus', 'before-submit', 'return'], fixture.events)

    def test_palette_never_pastes_into_wrong_nonempty_or_unwritable_owner(self):
        for change in ({'caption': 'Search current SQL…'}, {'pid': 9999}, {'text': 'old command'},
                       {'states': {'showing', 'visible', 'sensitive', 'editable'}},
                       {'states': {'focused', 'showing', 'visible', 'sensitive', 'editable', 'read_only'}}):
            with self.subTest(change=change):
                fixture = self.palette_paste_fixture()
                fixture.values.update(change)
                with patch('native_workbench_acceptance.owned_product_window', side_effect=fixture.window), \
                     patch('verify_installed_snap.paste_gtk_text') as paste, self.assertRaises(RuntimeError):
                    fixture.run()
                paste.assert_not_called()
                self.assertNotIn('return', fixture.events)

    def test_palette_does_not_retry_paste_or_submit_before_text_rows_and_source_are_proven(self):
        for failure in ('text', 'rows', 'source', 'lost-focus'):
            with self.subTest(failure=failure):
                fixture = self.palette_paste_fixture(sql=True)
                def paste(value, consumed):
                    fixture.events.append('paste')
                    fixture.values['text'] = 'partial' if failure == 'text' else value
                    if failure == 'lost-focus':
                        fixture.values['states'].remove('focused')
                    if not consumed():
                        raise TimeoutError('Intended control did not consume exact text')
                    if failure == 'source':
                        fixture.source[1].caret += 1
                def rows():
                    if failure == 'rows': raise TimeoutError('Rows not acknowledged')
                    return True
                with patch('native_workbench_acceptance.owned_product_window', side_effect=fixture.window), \
                     patch('verify_installed_snap.paste_gtk_text', side_effect=paste) as paste_mock:
                    with self.assertRaises((RuntimeError, TimeoutError)):
                        paste_native_palette_command(fixture.atspi, fixture.app, lambda _: fixture.nodes,
                            fixture.wait, fixture.command, {}, fixture.query, 'Roll back transaction',
                            rows, lambda: fixture.events.append('before-submit'))
                self.assertEqual(1, paste_mock.call_count)
                self.assertNotIn('return', fixture.events)
                self.assertNotIn('before-submit', fixture.events)

    def test_palette_sql_checkpoint_keeps_unfocused_selection_and_optional_session_exact(self):
        fixture = self.palette_paste_fixture(sql=True)
        checkpoint = native_palette_sql_checkpoint(fixture.atspi, fixture.nodes, {}, lambda: fixture.nodes)
        self.assertIs(fixture.source[1], checkpoint[0])
        self.assertEqual(('SELECT 漢😀;', 8, ((7, 9),)), checkpoint[3:6])
        self.assertEqual((None,), native_palette_sql_checkpoint(fixture.atspi, [fixture.query], {}, lambda: [fixture.query]))
        offline = self.modal_sql_origin_fixture(focused=False, context='')
        self.assertEqual(('日😀.sql', ''), native_palette_sql_checkpoint(offline[0], offline[3], {}, lambda: offline[3])[-1])
        failure = RuntimeError('Unrelated control retired')
        failure.domain, failure.code = 'atspi_error', 1
        def retired(): raise failure
        old = types.SimpleNamespace(get_name=retired)
        self.assertIsNone(native_palette_sql_checkpoint(fixture.atspi, [old] + fixture.nodes, {}, lambda: fixture.nodes))
        with self.assertRaises(RuntimeError) as raised:
            native_palette_sql_checkpoint(fixture.atspi, [old] + fixture.nodes, {}, lambda: [old] + fixture.nodes)
        self.assertIs(failure, raised.exception)

    def native_result_generation_fixture(self, *, owner='document-owner', source='base-old',
                                         display=None, document='native_atspi_fixture',
                                         context='fixture · catalog/schema · physical-session',
                                         completed=True):
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(PUSH_BUTTON='button'),
            StateType=types.SimpleNamespace(SHOWING='showing', SENSITIVE='sensitive', SELECTED='selected'))
        states = lambda *values: types.SimpleNamespace(contains=lambda state: state in values)
        tab = types.SimpleNamespace(get_name=lambda: document +
            (' · Completed' if completed else ' · Running') + '\n' + context,
            get_role=lambda: 'button', get_state_set=lambda: states('showing', 'sensitive', 'selected'))
        def cell(caption, row, column, *, cell_owner=None, cell_source=None, cell_display=None):
            identifier = 'busydata.result.cell.v1:' + json.dumps([
                cell_owner or owner, cell_source or source, cell_display or display or source, row, column],
                separators=(',', ':'))
            return types.SimpleNamespace(get_name=lambda: caption, get_role=lambda: 'button',
                get_interfaces=lambda: ['Action'], get_state_set=lambda: states('showing', 'sensitive'),
                get_attributes=lambda: {'id': identifier})
        cells = [cell('Row 1, id: 2', 0, 0), cell('Row 1, n: second', 0, 1),
                 cell('Row 2, id: 1', 1, 0), cell('Row 2, n: 漢😀', 1, 1)]
        nodes = [tab] + cells
        def observed():
            return native_grid_generation(atspi, nodes, document, lambda node: node.get_name(), lambda: nodes)
        return types.SimpleNamespace(atspi=atspi, nodes=nodes, cells=cells, tab=tab,
            cell=cell, document=document, context=context, observed=observed)

    def test_native_session_details_reads_only_the_exact_localized_physical_uuid(self):
        owner = '12345678-1234-1234-1234-123456789abc'
        self.assertEqual(owner, native_physical_session_identity(
            'Fixture · Staging\nPhysical session: ' + owner + '\nAuto-commit', 'Physical session'))
        self.assertEqual(owner, native_physical_session_identity(
            'Physische Sitzung: ' + owner, 'Physische Sitzung'))
        self.assertIsNone(native_physical_session_identity('Fixture · ' + owner, 'Physical session'))
        self.assertIsNone(native_physical_session_identity('Physical session: ' + owner, 'Physische Sitzung'))
        for invalid in ('owner-not-a-uuid', owner + ' trailing', owner.upper(),
                        owner + '\nPhysical session: ' + owner):
            with self.subTest(invalid=invalid), self.assertRaises(RuntimeError):
                native_physical_session_identity('Physical session: ' + invalid, 'Physical session')
        with self.assertRaises(ValueError):
            native_physical_session_identity('x' * 4097, 'Physical session')
        with self.assertRaises(ValueError):
            native_physical_session_identity('', 'Physical session\n')

    def test_previous_browse_generation_uses_actual_selected_sql_title_without_query_prefix(self):
        for document in ('Query 2', 'Connection management A', 'workflow.sql', '自定义 😀'):
            with self.subTest(document=document):
                fixture = self.native_result_generation_fixture(document=document)
                checkpoint = (None, 'authored heading', 42, 'SELECT id, n;', 0, (),
                    (document, fixture.context))
                with patch('native_workbench_acceptance.native_palette_sql_checkpoint', return_value=checkpoint):
                    captured = native_previous_browse_generation(fixture.atspi, fixture.nodes, {},
                        lambda node: node.get_name(), lambda: fixture.nodes)
                self.assertEqual(document, captured['document'])
                self.assertEqual('document-owner', captured['owner'])
                self.assertEqual('base-old', captured['source'])
        fixture = self.native_result_generation_fixture(completed=False)
        checkpoint = (None, 'authored heading', 42, 'SELECT id, n;', 0, (),
            (fixture.document, fixture.context))
        for incomplete in (None, checkpoint):
            with patch('native_workbench_acceptance.native_palette_sql_checkpoint', return_value=incomplete):
                self.assertIsNone(native_previous_browse_generation(fixture.atspi, fixture.nodes, {},
                    lambda node: node.get_name(), lambda: fixture.nodes))
        with patch('native_workbench_acceptance.native_palette_sql_checkpoint', return_value=(None,)):
            with self.assertRaises(RuntimeError):
                native_previous_browse_generation(fixture.atspi, fixture.nodes, {},
                    lambda node: node.get_name(), lambda: fixture.nodes)

    def test_fresh_browse_requires_new_completed_owner_source_and_exact_keyed_cells(self):
        previous = self.native_result_generation_fixture(document='Query 2').observed()
        fixture = self.native_result_generation_fixture(owner='new-data-owner', source='new-browse-source')
        current = fixture.observed()
        expected = (('1', '漢😀'), ('2', 'second'))
        self.assertIs(current, native_fresh_browse_generation(previous, current, expected))
        for changes in ({'completed': False}, {'owner': previous['owner']},
                        {'source': previous['source']}, {'cells': current['cells'][:2]}):
            with self.subTest(changes=changes):
                self.assertIsNone(native_fresh_browse_generation(previous, dict(current, **changes), expected))
        self.assertIsNone(native_fresh_browse_generation(previous, None, expected))
        self.assertIsNone(native_fresh_browse_generation(previous, current, (('1', 'other schema'), ('2', 'second'))))
        wrong_coordinates = dict(current, cells=tuple((node, caption, (row, 1 - column))
            for node, caption, (row, column) in current['cells']))
        self.assertIsNone(native_fresh_browse_generation(previous, wrong_coordinates, expected))
        with self.assertRaises(ValueError):
            native_fresh_browse_generation(previous, current, ())

    def test_native_result_identity_has_strict_bounded_versioned_shape(self):
        encode = lambda fields: 'busydata.result.cell.v1:' + json.dumps(fields, separators=(',', ':'))
        self.assertEqual(('owner', 'base', 'view-display', 0, 1),
            native_result_cell_identity(encode(['owner', 'base', 'view-display', 0, 1])))
        self.assertIsNone(native_result_cell_identity(None))
        self.assertIsNone(native_result_cell_identity(''))
        self.assertIsNone(native_result_cell_identity('another-semantic-identifier'))
        malformed = [False, 'busydata.result.cell.v2:[]', 'busydata.result.cell.v1:{',
            encode(['owner', 'base', 'display', 0]), encode(['', 'base', 'display', 0, 1]),
            encode(['owner', 'base', 'display', True, 1]), encode(['owner', 'base', 'display', 0, False]),
            encode(['owner', 'base', 'display', -1, 1]), encode(['owner', 'base', 'display', 0, 2048]),
            encode(['owner', 'base', 'display', 2 ** 63, 1]), encode(['x' * 129, 'base', 'display', 0, 1]),
            encode(['owner\nforged', 'base', 'display', 0, 1]), 'busydata.result.cell.v1:' + ' ' * 2048]
        for identifier in malformed:
            with self.subTest(identifier_type=type(identifier)), self.assertRaises(RuntimeError):
                native_result_cell_identity(identifier)

    def test_unsorted_reset_requires_fresh_generation_and_both_keyed_values(self):
        previous = self.native_result_generation_fixture().observed()
        current = self.native_result_generation_fixture(source='base-new')
        result = replaced_native_grid_generation(current.atspi, current.nodes, previous,
            lambda node: node.get_name(), lambda: current.nodes,
            expected_rows=(('1', '漢😀'), ('2', 'second')))
        self.assertEqual('base-new', result['source'])
        self.assertEqual(('Row 1, id: 2', 'Row 2, id: 1'),
            tuple(caption for _, caption, (_, column) in result['cells'] if column == 0))

    def test_unsorted_reset_cannot_acknowledge_same_source_or_local_view(self):
        previous = self.native_result_generation_fixture().observed()
        current = self.native_result_generation_fixture(display='new-local-view')
        self.assertIsNone(replaced_native_grid_generation(current.atspi, current.nodes, previous,
            lambda node: node.get_name(), lambda: current.nodes,
            expected_rows=(('1', '漢😀'), ('2', 'second'))))

    def test_unsorted_reset_rejects_wrong_values_and_missing_rows(self):
        previous = self.native_result_generation_fixture().observed()
        current = self.native_result_generation_fixture(source='base-new')
        for rows in ((('1', 'wrong'), ('2', 'second')), (('1', '漢😀'),)):
            with self.subTest(rows=rows):
                self.assertIsNone(replaced_native_grid_generation(current.atspi, current.nodes, previous,
                    lambda node: node.get_name(), lambda: current.nodes, expected_rows=rows))

    def test_unsorted_reset_rejects_foreign_generation_before_key_matching(self):
        previous = self.native_result_generation_fixture().observed()
        current = self.native_result_generation_fixture(source='base-new', owner='foreign-owner')
        with self.assertRaises(RuntimeError):
            replaced_native_grid_generation(current.atspi, current.nodes, previous,
                lambda node: node.get_name(), lambda: current.nodes,
                expected_rows=(('1', '漢😀'), ('2', 'second')))

    def test_server_result_generation_survives_modal_replacement_with_exact_owner_and_coordinates(self):
        before = self.native_result_generation_fixture()
        previous = before.observed()
        current = self.native_result_generation_fixture(source='base-new')
        self.assertIsNot(before.tab, current.tab)
        result = replaced_native_grid_generation(current.atspi, current.nodes, previous,
            lambda node: node.get_name(), lambda: current.nodes,
            expected_cells=(('Row 1, id: 2', 0, 0), ('Row 1, n: second', 0, 1)))
        self.assertIs(current.tab, result['tab'])
        self.assertEqual(('document-owner', 'base-new', 'base-new'),
            (result['owner'], result['source'], result['display']))
        self.assertEqual(4, len(result['cells']))
        # A repeated server sort needs another new base even when rows are identical.
        self.assertIsNone(replaced_native_grid_generation(current.atspi, current.nodes, result,
            lambda node: node.get_name(), lambda: current.nodes))
        again = self.native_result_generation_fixture(source='base-next')
        self.assertIsNotNone(replaced_native_grid_generation(again.atspi, again.nodes, result,
            lambda node: node.get_name(), lambda: again.nodes))

    def test_server_refresh_can_reuse_native_controls_but_requires_a_new_retained_source(self):
        fixture = self.native_result_generation_fixture()
        previous = fixture.observed()
        for node in fixture.cells:
            identifier = native_result_cell_identity(node.get_attributes()['id'])
            value = 'busydata.result.cell.v1:' + json.dumps(
                [identifier[0], 'base-new', 'base-new', *identifier[3:]], separators=(',', ':'))
            node.get_attributes = lambda value=value: {'id': value}
        current = replaced_native_grid_generation(fixture.atspi, fixture.nodes, previous,
            lambda node: node.get_name(), lambda: fixture.nodes,
            expected_cells=(('Row 1, n: second', 0, 1),))
        self.assertIs(fixture.tab, current['tab'])
        self.assertTrue(all(before[0] is after[0]
            for before, after in zip(previous['cells'], current['cells'])))
        self.assertEqual(('document-owner', 'base-old', 'base-new'),
            (current['owner'], previous['source'], current['source']))
        self.assertIsNone(replaced_native_grid_generation(fixture.atspi, fixture.nodes, current,
            lambda node: node.get_name(), lambda: fixture.nodes))

    def test_local_view_change_cannot_acknowledge_new_server_result(self):
        previous = self.native_result_generation_fixture().observed()
        for changes in ({'display': 'view-new'}, {'source': 'base-new', 'completed': False},
                        {'source': 'base-new', 'document': 'another-table'}):
            with self.subTest(changes=changes):
                fixture = self.native_result_generation_fixture(**changes)
                self.assertIsNone(replaced_native_grid_generation(fixture.atspi, fixture.nodes, previous,
                    lambda node: node.get_name(), lambda: fixture.nodes))
        for changes in ({'source': 'base-new', 'owner': 'another-document'},
                        {'source': 'base-new', 'context': 'another physical session'}):
            with self.subTest(changes=changes):
                fixture = self.native_result_generation_fixture(**changes)
                with self.assertRaisesRegex(RuntimeError, 'another captured document or target'):
                    replaced_native_grid_generation(fixture.atspi, fixture.nodes, previous,
                        lambda node: node.get_name(), lambda: fixture.nodes)

    def test_result_generation_requires_exact_cell_coordinates_and_complete_filter_absence(self):
        previous = self.native_result_generation_fixture().observed()
        fixture = self.native_result_generation_fixture(source='base-new')
        for expected, absent in (((('Row 1, n: second', 0, 0),), ()),
                                 ((('Row 1, n: missing', 0, 1),), ()),
                                 ((('Row 1, n: second', 0, 1),), ('Row 2, n: 漢😀',))):
            with self.subTest(expected=expected, absent=absent):
                self.assertIsNone(replaced_native_grid_generation(fixture.atspi, fixture.nodes, previous,
                    lambda node: node.get_name(), lambda: fixture.nodes,
                    expected_cells=expected, absent_labels=absent))
        fixture.nodes[:] = fixture.nodes[:3]
        self.assertIsNotNone(replaced_native_grid_generation(fixture.atspi, fixture.nodes, previous,
            lambda node: node.get_name(), lambda: fixture.nodes,
            expected_cells=(('Row 1, n: second', 0, 1),), absent_labels=('Row 2, n: 漢😀',)))

    def test_result_generation_rejects_mixed_groups_duplicate_coordinates_and_missing_ids(self):
        for extra in ('owner', 'source', 'display', 'coordinate', 'document'):
            with self.subTest(extra=extra):
                fixture = self.native_result_generation_fixture()
                if extra == 'document': fixture.nodes.append(fixture.tab)
                else:
                    options = {'cell_' + extra: 'forged'} if extra != 'coordinate' else {}
                    fixture.nodes.append(fixture.cell('Row 3, n: extra', 0 if extra == 'coordinate' else 2,
                        1, **options))
                with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
                    fixture.observed()
        fixture = self.native_result_generation_fixture()
        fixture.cells[0].get_attributes = lambda: {}
        with self.assertRaisesRegex(RuntimeError, 'no versioned native identity'):
            fixture.observed()

    def test_result_generation_incomplete_retired_getter_never_proves_new_base_or_absence(self):
        previous = self.native_result_generation_fixture().observed()
        fixture = self.native_result_generation_fixture(source='base-new')
        failure = RuntimeError('Cell retired during attributes read')
        failure.domain, failure.code = 'atspi_error', 1
        def retired(): raise failure
        old = fixture.cell('Row 3, n: old', 2, 1)
        old.get_attributes = retired
        self.assertIsNone(replaced_native_grid_generation(fixture.atspi, fixture.nodes + [old], previous,
            lambda node: node.get_name(), lambda: fixture.nodes, absent_labels=('Row 9, n: absent',)))
        with self.assertRaises(RuntimeError) as raised:
            native_grid_generation(fixture.atspi, fixture.nodes + [old], fixture.document,
                lambda node: node.get_name(), lambda: fixture.nodes + [old])
        self.assertIs(failure, raised.exception)
        failure.code = 0
        with self.assertRaises(RuntimeError) as raised:
            native_grid_generation(fixture.atspi, fixture.nodes + [old], fixture.document,
                lambda node: node.get_name(), lambda: fixture.nodes)
        self.assertIs(failure, raised.exception)

    def test_live_node_application_and_transport_failures_are_not_hidden_by_reacquisition(self):
        failure = RuntimeError('Native property read failed')
        def failed_name(): raise failure
        node = types.SimpleNamespace(get_name=failed_name)
        for domain, code, current in [('atspi_error', 1, [node]),
                                      ('atspi_error', 2, []),
                                      ('g-io-error-quark', 1, [])]:
            with self.subTest(domain=domain, code=code):
                failure.domain, failure.code = domain, code
                with self.assertRaises(RuntimeError) as raised:
                    find_live_control(None, [node], 'Run', current_nodes=lambda: current)
                self.assertIs(failure, raised.exception)
        with self.assertRaises(RuntimeError):
            find_live_control(None, [node], 'Run')

    def test_a_failed_fresh_tree_still_fails_native_control_lookup(self):
        failure = RuntimeError('Native property read failed')
        failure.domain, failure.code = 'atspi_error', 1
        def failed_name(): raise failure
        def current(): raise ValueError('Fresh application tree unavailable')
        with self.assertRaisesRegex(ValueError, 'Fresh application tree unavailable'):
            find_live_control(None, [types.SimpleNamespace(get_name=failed_name)],
                              'Run', current_nodes=current)

    def test_continuous_native_events_do_not_starve_the_actual_acknowledgement(self):
        events = []
        context = types.SimpleNamespace(pending=lambda: True,
            iteration=lambda blocking: events.append(blocking))
        with tempfile.TemporaryDirectory() as directory:
            acknowledgement = object()
            self.assertIs(acknowledgement, native_wait(lambda: acknowledgement,
                context, Path(directory) / 'reader.log'))
        self.assertEqual([False] * 32, events)

    def test_continuous_native_events_still_fail_an_unacknowledged_deadline(self):
        context = types.SimpleNamespace(pending=lambda: True, iteration=lambda blocking: None)
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(TimeoutError, 'condition deadline'):
                native_wait(lambda: None, context, Path(directory) / 'reader.log', .001)

    def test_reader_readiness_requires_the_actual_activated_event_loop_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'reader.log'
            self.assertFalse(native_reader_ready(path))
            for message in ['INFO: Preparing to launch.\n',
                            "07:00:00 - SPEECH OUTPUT: 'ORCA: Starting Atspi main event loop'\n",
                            '07:00:00 - ORCA: Starting Atspi main event loop later\n']:
                with self.subTest(message=message):
                    path.write_text(message)
                    self.assertFalse(native_reader_ready(path))
            path.write_text('07:00:00 - ORCA: Starting Atspi main event loop\n')
            self.assertTrue(native_reader_ready(path))
            path.write_bytes(b'x' * (4 * 1024 * 1024 + 1))
            with self.assertRaisesRegex(RuntimeError, 'diagnostic byte budget'):
                native_reader_ready(path)

    def test_private_speech_readiness_requires_a_real_protocol_acknowledgement(self):
        with tempfile.TemporaryDirectory(prefix='bdsp-', dir='/tmp') as folder:
            path = Path(folder) / 'speech.sock'
            self.assertFalse(native_speech_ready(path))
            for reply, error in [(b'208 OK CLIENT NAME SET\r\n', None),
                                 (b'', None),
                                 (b'500 COMMAND REJECTED\r\n', 'acknowledgement rejected'),
                                 (b'x' * 512, 'response budget')]:
                with self.subTest(reply=reply[:32]):
                    received, failures = [], []
                    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                        server.bind(str(path))
                        server.listen(1)
                        server.settimeout(1)
                        def accept():
                            try:
                                with server.accept()[0] as peer:
                                    peer.settimeout(1)
                                    received.append(peer.recv(512))
                                    if reply:
                                        peer.sendall(reply)
                            except Exception as failure:
                                failures.append(failure)
                        thread = threading.Thread(target=accept)
                        thread.start()
                        try:
                            if error:
                                with self.assertRaisesRegex(RuntimeError, error):
                                    native_speech_ready(path)
                            else:
                                self.assertEqual(bool(reply), native_speech_ready(path))
                        finally:
                            thread.join(timeout=2)
                        self.assertFalse(thread.is_alive())
                        self.assertEqual([], failures)
                        self.assertEqual([b'SET SELF CLIENT_NAME busydata:readiness:main\r\n'], received)
                    path.unlink()

    def test_photograph_waits_for_only_the_owned_mapped_product_window(self):
        replies = [subprocess.CalledProcessError(1, 'xdotool'), types.SimpleNamespace(stdout='128\n')]
        def command(argv, **options):
            self.assertEqual(argv, ['xdotool', 'search', '--all', '--onlyvisible', '--pid', '41', '--name', '^BusyData$'])
            result = replies.pop(0)
            if isinstance(result, Exception): raise result
            return result
        def wait(ready):
            self.assertIsNone(ready())
            return ready()
        self.assertEqual(owned_product_window(command, wait, 41), '128')

    def test_photograph_distinguishes_a_real_owned_menu_from_its_main_window(self):
        def command(argv, **kwargs):
            if argv[0] == 'xdotool':
                return types.SimpleNamespace(stdout='128\n129\n')
            kind = 'NORMAL' if argv[2] == '128' else 'DROPDOWN_MENU'
            return types.SimpleNamespace(stdout='_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_' + kind)
        self.assertEqual('128', owned_product_window(command, lambda predicate: predicate(), 41))

    def test_photograph_excludes_owned_native_tooltip_beside_menu_and_main_window(self):
        calls = []
        def command(argv, **kwargs):
            calls.append(argv)
            if argv[0] == 'xdotool':
                return types.SimpleNamespace(stdout='128\n129\n130\n')
            kind = {'128': 'NORMAL', '129': 'DROPDOWN_MENU', '130': 'TOOLTIP'}[argv[2]]
            return types.SimpleNamespace(stdout='_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_' + kind)
        self.assertEqual('128', owned_product_window(command, lambda predicate: predicate(), 41))
        self.assertEqual(['xdotool', 'search', '--all', '--onlyvisible', '--pid', '41',
                          '--name', '^BusyData$'], calls[0])
        self.assertEqual({'128', '129', '130'}, {argv[2] for argv in calls[1:]})

    def test_photograph_still_refuses_two_main_windows_or_an_unknown_owned_surface(self):
        for other in ('NORMAL', 'DIALOG'):
            def command(argv, **kwargs):
                if argv[0] == 'xdotool':
                    return types.SimpleNamespace(stdout='128\n129\n')
                kind = 'NORMAL' if argv[2] == '128' else other
                return types.SimpleNamespace(stdout='_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_' + kind)
            with self.subTest(other=other), self.assertRaisesRegex(RuntimeError, 'Exactly one'):
                owned_product_window(command, lambda predicate: predicate(), 41)

    def test_photograph_checks_non_drawable_input_windows_without_accepting_unknown_surfaces(self):
        for window_class in ('InputOnly', 'InputOutput'):
            def command(argv, **kwargs):
                if argv[0] == 'xdotool':
                    return types.SimpleNamespace(stdout='128\n129\n130\n')
                if argv[0] == 'xwininfo':
                    return types.SimpleNamespace(stdout='  Class: ' + window_class + '\n')
                kind = {'128': 'NORMAL', '130': 'DROPDOWN_MENU'}.get(argv[2])
                return types.SimpleNamespace(stdout='_NET_WM_WINDOW_TYPE(ATOM) = _NET_WM_WINDOW_TYPE_' + kind
                    if kind else '_NET_WM_WINDOW_TYPE: not found.')
            if window_class == 'InputOnly':
                self.assertEqual('128', owned_product_window(command, lambda predicate: predicate(), 41))
            else:
                with self.assertRaisesRegex(RuntimeError, 'Exactly one'):
                    owned_product_window(command, lambda predicate: predicate(), 41)

    def test_single_case_diagnostic_receipt_cannot_replace_the_default_matrix_receipt(self):
        self.assertNotEqual(native_report_name('POSTGRESQL', 'platform'),
            native_report_name('POSTGRESQL', 'platform', 'light-125'))
        for engine, scope in [('MYSQL', 'platform'), ('POSTGRESQL', 'fluent'), ('POSTGRESQL', None)]:
            with self.assertRaises(ValueError):
                native_report_name(engine, scope, 'light-125')

    def test_photograph_rejects_ambiguous_windows_and_lookup_errors(self):
        def wait(ready): return ready()
        with self.assertRaisesRegex(RuntimeError, 'Exactly one'):
            owned_product_window(lambda *args, **kwargs: types.SimpleNamespace(stdout='128\n129\n'), wait, 41)
        def failed(*args, **kwargs): raise subprocess.CalledProcessError(2, 'xdotool')
        with self.assertRaises(subprocess.CalledProcessError):
            owned_product_window(failed, wait, 41)

    def test_photograph_uses_logical_coordinates_and_keeps_exact_physical_extent(self):
        for scale in (1, 2):
            calls = []
            def capture(root, x, y, width, height):
                calls.append((x, y, width, height))
                return types.SimpleNamespace(
                    get_width=lambda: width * scale, get_height=lambda: height * scale,
                    new_subpixbuf=lambda *bounds: bounds)
            gdk = types.SimpleNamespace(
                get_default_root_window=lambda: types.SimpleNamespace(get_scale_factor=lambda: scale),
                pixbuf_get_from_window=capture)
            bounds = physical_window_picture(gdk, 3, 5, 1366, 768)
            self.assertEqual(bounds, (3 % scale, 5 % scale, 1366, 768))
            self.assertEqual(calls, [(3 // scale, 5 // scale,
                (1366 + 3 % scale + scale - 1) // scale,
                (768 + 5 % scale + scale - 1) // scale)])

    def test_photograph_rejects_unavailable_or_incorrect_pixel_extent(self):
        root = types.SimpleNamespace(get_scale_factor=lambda: 2)
        for picture in (None, types.SimpleNamespace(get_width=lambda: 683, get_height=lambda: 384)):
            gdk = types.SimpleNamespace(get_default_root_window=lambda: root,
                pixbuf_get_from_window=lambda *args: picture)
            with self.assertRaisesRegex(RuntimeError, 'extent unavailable'):
                physical_window_picture(gdk, 0, 0, 1366, 768)

    def test_native_label_patterns_reuse_a_bounded_catalog_and_refresh_changed_labels(self):
        labels = {'Structure': 'البنية', '{count} updates': '{count} تحديث'}
        native_label_patterns.cache_clear()
        value = 'البنية · public.items · 2 تحديث'
        self.assertEqual(normalized_native_label(value, labels),
                         'Structure · public.items · 2 updates')
        with patch('native_workbench_acceptance.re.compile', side_effect=AssertionError('Repeated catalog compilation')):
            self.assertEqual(normalized_native_label(value, labels),
                             'Structure · public.items · 2 updates')
        labels['Structure'] = 'هيكل'
        self.assertEqual(normalized_native_label('هيكل · public.items', labels),
                         'Structure · public.items')
        for label in range(8):
            normalized_native_label(str(label), {'Structure': str(label)})
        self.assertEqual(native_label_patterns.cache_info().maxsize, 2)
        self.assertLessEqual(native_label_patterns.cache_info().currsize, 2)

    def test_native_progress_is_source_bound_private_and_never_a_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            report = NativeProgressReport(directory, {
                'stage': 'startup', 'sourceSha256': 'source', 'exitCode': 1})
            report['privateFormInput'] = 'private-credential'
            report['stage'] = 'native-object-index-metadata'
            progress = json.loads((directory / 'progress.json').read_text())
            self.assertEqual(progress['sourceSha256'], 'source')
            self.assertEqual(progress['stage'], 'native-object-index-metadata')
            self.assertFalse(progress['stageComplete'])
            self.assertGreaterEqual(progress['elapsedSeconds'], 0)
            self.assertNotIn('private-credential', (directory / 'progress.json').read_text())
            self.assertEqual(report['exitCode'], 1)
            self.assertFalse((directory / 'progress.json.tmp').exists())

    def test_native_progress_bounds_unicode_stage_text(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            report = NativeProgressReport(directory, {
                'stage': 'startup', 'sourceSha256': 'source'})
            report['stage'] = 'العربية' * 1024
            progress = json.loads((directory / 'progress.json').read_text())
            self.assertLessEqual(len(progress['stage'].encode('utf-8')), 512)
            self.assertLess((directory / 'progress.json').stat().st_size, 1024)

    def test_tree_focus_requires_visible_localized_hierarchy(self):
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(PUSH_BUTTON='button'),
            StateType=types.SimpleNamespace(SHOWING='showing', FOCUSED='focused'))
        labels = {'Level': 'المستوى', 'level': 'المستوى', 'Tables': 'الجداول', 'Loading': 'جارٍ التحميل'}
        def node(label, states):
            return types.SimpleNamespace(get_name=lambda: label, get_role=lambda: 'button',
                get_interfaces=lambda: ['Action'],
                get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state in states))
        group = node('الجداول · المستوى 4 · fixture/public', {'showing', 'focused'})
        hidden = node('items · المستوى 5 · fixture/public', {'focused'})
        unrelated = node('items', {'showing', 'focused'})
        rows = [group, hidden, unrelated]
        self.assertIs(find_native_tree_row(atspi, rows, labels, 'Tables', focused=True), group)
        self.assertIsNone(find_native_tree_row(atspi, rows, labels, 'items', focused=True))
        visible = node('items · المستوى 5 · fixture/public', {'showing', 'focused'})
        self.assertIs(find_native_tree_row(atspi, [visible], labels, 'items', focused=True), visible)
        loading = node('الجداول · المستوى 4 · fixture/public · جارٍ التحميل', {'showing', 'focused'})
        self.assertIsNone(find_native_tree_row(atspi, [loading], labels, 'Tables', loaded=True))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_native_tree_row(atspi, [visible, visible], labels, 'items', focused=True)
        self.assertIsNone(find_native_tree_row(
            atspi, [visible, visible], labels, 'items', settling=True))
        self.assertIs(find_native_tree_row(
            atspi, [visible], labels, 'items', settling=True), visible)

    def explorer_identity_fixture(self):
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(TREE_ITEM='tree', PUSH_BUTTON='button'),
            StateType=types.SimpleNamespace(VISIBLE='visible', SHOWING='showing', FOCUSED='focused'))
        class Row:
            def __init__(self, key='a', pid=8123, focused=False):
                self.pid, self.identifier = pid, 'busydata.database.item.4.' + key * 64
                self.states = {'visible', 'showing'} | ({'focused'} if focused else set())
            def clear_cache(self): pass
            def get_attributes(self): return {'id': self.identifier}
            def get_process_id(self): return self.pid
            def get_name(self): return 'Tables · level 4 · fixture/public · Complete'
            def get_role(self): return 'tree'
            def get_interfaces(self): return ['Action', 'Component']
            def get_state_set(self): return types.SimpleNamespace(contains=lambda state: state in self.states)
        return atspi, Row

    def test_explorer_focus_reacquires_the_same_identity_after_subtree_replacement(self):
        atspi, Row = self.explorer_identity_fixture()
        retired, replacement, unrelated = Row(), Row(), Row('b')
        identity = native_tree_row_identity(retired)
        snapshots = iter([[retired], [unrelated, replacement], [unrelated, replacement]])
        focused = []
        def request(api, item):
            self.assertIs(api, atspi)
            focused.append(item)
            item.states.add('focused')
            return True
        def current():
            return find_native_tree_row(atspi, next(snapshots), {}, identity=identity)
        def wait(predicate):
            self.assertIsNone(predicate())
            self.assertIsNone(predicate())
            return predicate()
        with patch('native_workbench_acceptance.request_native_focus', side_effect=request):
            self.assertIs(focus_live_native_control(atspi, current, wait), replacement)
        self.assertEqual(focused, [retired, replacement])

    def test_explorer_identity_does_not_adopt_a_same_label_from_another_owner_or_branch(self):
        atspi, Row = self.explorer_identity_fixture()
        original = Row()
        identity = native_tree_row_identity(original)
        self.assertIsNone(find_native_tree_row(atspi, [Row('b'), Row(pid=9123)], {}, identity=identity))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_native_tree_row(atspi, [Row(), Row()], {}, identity=identity)

    def test_expansion_readiness_rejects_the_collapsed_or_loading_group(self):
        atspi, Row = self.explorer_identity_fixture()
        atspi.StateType.EXPANDED = 'expanded'
        group = Row()
        self.assertIsNone(find_native_tree_row(atspi, [group], {},
            name='Tables', loaded=True, expanded=True))
        group.states.add('expanded')
        self.assertIs(find_native_tree_row(atspi, [group], {},
            name='Tables', loaded=True, expanded=True), group)
        group.get_name = lambda: 'Tables · level 4 · fixture/public · Loading'
        self.assertIsNone(find_native_tree_row(atspi, [group], {},
            name='Tables', loaded=True, expanded=True))

    def test_tree_navigation_requires_a_complete_focused_row_before_any_key_decision(self):
        atspi, Row = self.explorer_identity_fixture()
        group, target = Row(focused=True), Row('b')
        target.get_name = lambda: 'native_atspi_fixture · level 5 · fixture/public · Complete'
        target.identifier = target.identifier.replace('.4.', '.5.')
        nodes = [group, target]
        step = lambda: native_tree_navigation_step(atspi, lambda: nodes, {}, 'native_atspi_fixture')
        self.assertEqual(step(), (group, native_tree_row_identity(group), False))
        group.states.remove('focused')
        self.assertIsNone(step())
        target.states.add('focused')
        self.assertEqual(step(), (target, native_tree_row_identity(target), True))
        def incomplete(): raise NativeSnapshotIncomplete('missing child')
        self.assertIsNone(native_tree_navigation_step(atspi, incomplete, {}, 'native_atspi_fixture'))
        group.states.add('focused')
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            step()

    def test_tree_movement_rejects_label_changes_and_rebuilt_proxies_with_same_identity(self):
        atspi, Row = self.explorer_identity_fixture()
        original = Row(focused=True)
        previous = native_tree_row_identity(original)
        original.get_name = lambda: 'Tables · level 4 · fixture/public · Stale'
        self.assertIsNone(native_tree_movement(atspi, lambda: [original], {},
            'native_atspi_fixture', previous))
        replacement = Row(focused=True)
        replacement.get_name = original.get_name
        self.assertIsNone(native_tree_movement(atspi, lambda: [replacement], {},
            'native_atspi_fixture', previous))

    def test_tree_movement_accepts_distinct_identity_even_when_captions_are_identical(self):
        atspi, Row = self.explorer_identity_fixture()
        original, next_row = Row(), Row('b', focused=True)
        result = native_tree_movement(atspi, lambda: [original, next_row], {},
            'native_atspi_fixture', native_tree_row_identity(original))
        self.assertEqual(result, (next_row, native_tree_row_identity(next_row), False))

    def test_tree_movement_rejects_foreign_process_and_incomplete_or_ambiguous_focus(self):
        atspi, Row = self.explorer_identity_fixture()
        previous = native_tree_row_identity(Row())
        with self.assertRaisesRegex(RuntimeError, 'another application'):
            native_tree_movement(atspi, lambda: [Row('b', pid=9123, focused=True)], {},
                'native_atspi_fixture', previous)
        def incomplete(): raise NativeSnapshotIncomplete('missing child')
        self.assertIsNone(native_tree_movement(atspi, incomplete, {},
            'native_atspi_fixture', previous))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            native_tree_movement(atspi, lambda: [Row('b', focused=True), Row('c', focused=True)], {},
                'native_atspi_fixture', previous)

    def test_explorer_identity_rejects_malformed_or_unowned_identifiers(self):
        _, Row = self.explorer_identity_fixture()
        for identifier in ('Tables', 'busydata.database.item.0.' + 'a' * 64,
                           'busydata.database.item.4.' + 'a' * 65,
                           'busydata.database.item.4.' + 'z' * 64, None):
            row = Row(); row.identifier = identifier
            with self.subTest(identifier=identifier), self.assertRaisesRegex(RuntimeError, 'identity'):
                native_tree_row_identity(row)
        for pid in (True, 0, -1, 2 ** 31, '8123'):
            with self.subTest(pid=pid), self.assertRaisesRegex(RuntimeError, 'identity'):
                native_tree_row_identity(Row(pid=pid))

    def test_incomplete_read_only_snapshot_never_acknowledges_absence_or_a_cell(self):
        reads = []
        def incomplete():
            raise NativeSnapshotIncomplete('missing child')
        self.assertIsNone(read_native_snapshot(incomplete, lambda nodes: reads.append(nodes)))
        self.assertEqual(reads, [])
        self.assertIsNone(read_native_snapshot(lambda: [], lambda nodes: incomplete()))
        self.assertEqual(read_native_snapshot(lambda: [], lambda nodes: (False,)), (False,))
        self.assertEqual(read_native_snapshot(lambda: ['owned-cell'], lambda nodes: nodes[0]), 'owned-cell')

    def test_read_only_snapshot_does_not_hide_limits_or_other_failures(self):
        for error in (NativeNodeBudgetExceeded(513, 0, 0, 512),
                      RuntimeError('Invalid child count'), ValueError('Invalid owner')):
            for phase in ('snapshot', 'projection'):
                with self.subTest(error=type(error).__name__, phase=phase):
                    failing = Mock(side_effect=error)
                    with self.assertRaises(type(error)) as raised:
                        read_native_snapshot(failing if phase == 'snapshot' else lambda: [],
                            failing if phase == 'projection' else lambda nodes: None)
                    self.assertIs(raised.exception, error)

    def test_incomplete_read_only_snapshot_obeys_the_original_wait_deadline(self):
        clock, reads = [0.0], []
        def incomplete():
            reads.append(True)
            raise NativeSnapshotIncomplete('missing child')
        context = types.SimpleNamespace(pending=lambda: False, iteration=Mock())
        with tempfile.TemporaryDirectory() as directory, \
                patch('verify_native_accessibility.time.monotonic', side_effect=lambda: clock[0]), \
                patch('verify_native_accessibility.time.sleep', side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)):
            with self.assertRaisesRegex(TimeoutError, '^Native acceptance condition deadline$'):
                native_wait(lambda: read_native_snapshot(incomplete, lambda nodes: nodes),
                    context, Path(directory) / 'reader.log', .1)
        self.assertEqual(len(reads), 4)
        self.assertAlmostEqual(clock[0], .12)

    def test_execution_dismissal_awaits_fluent_rows_and_restored_trigger_focus(self):
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(MENU='menu'),
            StateType=types.SimpleNamespace(SHOWING='showing', FOCUSED='focused'))
        def node(name, role, states):
            return types.SimpleNamespace(name=name, get_role=lambda: role,
                get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state in states))
        trigger_states, history_states = {'showing'}, {'showing'}
        trigger = node('Results', 'button', trigger_states)
        history = node('1 · Completed · 5 ms', 'button', history_states)
        nodes = [trigger, history]
        names = {history.name}
        closed = lambda: execution_menu_dismissed(atspi, nodes, names, trigger, lambda item: item.name)
        # Fluent menu rows are buttons, so absence of a MENU role is insufficient.
        trigger_states.add('focused')
        self.assertFalse(closed())
        trigger_states.remove('focused')
        history_states.clear()
        self.assertFalse(closed())
        trigger_states.add('focused')
        self.assertTrue(closed())
        nodes.append(node('', 'menu', {'showing'}))
        self.assertFalse(closed())

    def test_execution_menu_rejects_regular_result_tab_during_layout_adoption(self):
        results, first, messages = object(), object(), object()
        nodes = {'Execution options': results, 'Results 1': first, 'Messages': messages}
        self.assertIs(results, find_execution_output_menu(nodes.get))
        del nodes['Execution options']
        self.assertIsNone(find_execution_output_menu(nodes.get))
        del nodes['Messages']
        self.assertIsNone(find_execution_output_menu(nodes.get))
        nodes.clear()
        self.assertIsNone(find_execution_output_menu(nodes.get))

    def test_disabled_fluent_popup_entry_is_new_and_never_a_background_caption(self):
        from native_workbench_acceptance import find_new_menu_entry
        role = types.SimpleNamespace(MENU_ITEM='menu', CHECK_MENU_ITEM='check',
            RADIO_MENU_ITEM='radio', PUSH_BUTTON='button', PANEL='panel')
        atspi = types.SimpleNamespace(Role=role, StateType=types.SimpleNamespace(SHOWING='showing'))
        class Node:
            def __init__(self, kind, name='Deactivate source'): self.kind, self.name = kind, name
            def get_role(self): return self.kind
            def get_name(self): return self.name
            def get_state_set(self): return types.SimpleNamespace(contains=lambda flag: True)
        old = Node('panel')
        panel = Node('panel')
        self.assertIsNone(find_new_menu_entry(atspi, [old], 'Deactivate source', {old}, fluent=True))
        self.assertIs(panel, find_new_menu_entry(atspi, [old, panel], 'Deactivate source', {old}, fluent=True))
        self.assertIsNone(find_new_menu_entry(atspi, [panel], 'Deactivate source', set()))
        self.assertIsNone(find_new_menu_entry(atspi, [Node('panel', 'Deactivate source2')], 'Deactivate source', set(), fluent=True))
        for kind, fluent in [('menu', False), ('button', True)]:
            node = Node(kind)
            self.assertIs(node, find_new_menu_entry(atspi, [node], 'Deactivate source', set(), fluent=fluent))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_new_menu_entry(atspi, [panel, Node('panel')], 'Deactivate source', set(), fluent=True)

    def test_disabled_fluent_panel_without_action_interface_cannot_activate(self):
        item = types.SimpleNamespace(clear_cache=lambda: None, get_interfaces=lambda: [],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda _: False))
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(ENABLED='enabled'),
            Action=types.SimpleNamespace(get_n_actions=lambda _: self.fail('No Action interface')))
        self.assertEqual({'enabled': False, 'activationAvailable': False, 'actions': []},
            assert_native_command_disabled(atspi, item))

    def test_disabled_command_uses_enabled_value_and_rejects_activation(self):
        states = {'sensitive'}
        actions = ['Focus']
        item = types.SimpleNamespace(
            clear_cache=lambda: None, get_interfaces=lambda: ['Action'],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda state: state in states))
        atspi = types.SimpleNamespace(
            StateType=types.SimpleNamespace(ENABLED='enabled'),
            Action=types.SimpleNamespace(
                get_n_actions=lambda _: len(actions),
                get_action_name=lambda _, index: actions[index]))
        self.assertEqual({'enabled': False, 'activationAvailable': False, 'actions': ['Focus']},
                         assert_native_command_disabled(atspi, item))
        states.add('enabled')
        with self.assertRaisesRegex(RuntimeError, 'admits SQL'):
            assert_native_command_disabled(atspi, item)
        states.remove('enabled')
        actions.append('Tap')
        with self.assertRaisesRegex(RuntimeError, 'exposes activation'):
            assert_native_command_disabled(atspi, item)
        actions[:] = ['Focus'] * 65
        with self.assertRaisesRegex(RuntimeError, 'budget'):
            assert_native_command_disabled(atspi, item)

    def test_fluent_rendering_receipt_requires_actual_composition_and_linux_host(self):
        receipt = {'entrypoint': 'integration_test/fluent_composition_linux.dart',
            'composition': 'Linux-host Fluent', 'hostPlatform': 'linux',
            'releaseMode': True, 'actualWindowsWorkspaceShell': True,
            'actualFluentTheme': True, 'actualPinnedBackend': True,
            'windowsNativeAcceptance': False, 'textScale': 1.0, 'direction': 'ltr',
            'workspaceRenderBox': {'width': 800, 'height': 550}}
        self.assertIs(receipt, validate_composition(receipt))
        for key, value in [('hostPlatform', 'windows'), ('windowsNativeAcceptance', True),
                           ('actualPinnedBackend', False), ('actualWindowsWorkspaceShell', False),
                           ('releaseMode', False), ('workspaceRenderBox', {'width': 0, 'height': 1})]:
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate_composition(dict(receipt, **{key: value}))

    def test_palette_requires_filtered_rendered_rows_before_keyboard_activation(self):
        self.assertFalse(palette_rows_ready(['View · Plan', 'Results · Open plan document',
                                            'File · Save SQL   Ctrl+S'], 'Open plan document'))
        self.assertTrue(palette_rows_ready(['Results · Open plan document'], 'Open plan document'))
        self.assertTrue(palette_rows_ready(['View · Plan', 'Results · Open plan document'], 'Plan'))
        self.assertFalse(palette_rows_ready(['View · Plan'], 'Open plan document'))
        self.assertTrue(palette_rows_ready(['Connection · Connect',
                                           'Connection · Connection group',
                                           'Connection · Disconnect'], 'Connect'))
        self.assertFalse(palette_rows_ready(['Connection · Connect',
                                            'File · Save SQL'], 'Connect'))
        self.assertFalse(palette_rows_ready(['Connection · Disconnect'], 'Connect'))
        # Different English roles legitimately share an Arabic translation.
        # Actual localized rows prove the requested command without reversing
        # that non-injective translation or permitting stale unrelated rows.
        labels = {'Connection': 'اتصال', 'Connect': 'اتصال', 'File': 'ملف'}
        self.assertTrue(palette_rows_ready(['اتصال · اتصال',
                                            'اتصال · فصل الاتصال'], 'Connect', labels))
        self.assertFalse(palette_rows_ready(['اتصال · فصل الاتصال'], 'Connect', labels))
        self.assertFalse(palette_rows_ready(['اتصال · اتصال',
                                             'ملف · حفظ SQL'], 'Connect', labels))

    def test_post_change_refresh_tracks_source_key_instead_of_database_order(self):
        names = ['Row 1, id: 2', 'Row 1, n: second', 'Row 2, id: 1',
                 'Row 2, n: reviewed native edit']
        self.assertEqual('Row 2, n: reviewed native edit',
                         source_row_value_label(names, 'id', '1', 'n', 'reviewed native edit'))
        self.assertIsNone(source_row_value_label(names, 'id', '41', 'n', 'second'))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            source_row_value_label([*names, 'Row 3, id: 1'], 'id', '1', 'n', 'second')

    def test_review_reads_bounded_native_text_without_reading_passwords(self):
        calls = []
        text = 'UPDATE public.native_atspi_fixture SET n=? WHERE id=?'
        node = types.SimpleNamespace(
            get_role=lambda: 'text', get_interfaces=lambda: ['Text'],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda _: True))
        atspi = types.SimpleNamespace(
            Role=types.SimpleNamespace(PASSWORD_TEXT='password'),
            StateType=types.SimpleNamespace(SHOWING='showing'),
            Text=types.SimpleNamespace(
                get_character_count=lambda _: len(text),
                get_text=lambda _, first, last: calls.append((first, last)) or text[first:last]))
        self.assertEqual(text, bounded_native_text(atspi, node))
        self.assertEqual([(0, len(text))], calls)
        self.assertEqual('', bounded_native_text(atspi, node, limit=3))
        node.get_role = lambda: 'password'
        self.assertEqual('', bounded_native_text(atspi, node))
        node.get_role = lambda: 'text'
        node.get_state_set = lambda: types.SimpleNamespace(contains=lambda _: False)
        self.assertEqual('', bounded_native_text(atspi, node))
        self.assertEqual([(0, len(text))], calls)

    def test_dirty_document_tab_keeps_its_real_identity(self):
        self.assertEqual('Structure · Object designer · public.items', native_tab_name('● Structure · Object designer · public.items'))
        self.assertEqual('public.● items', native_tab_name('public.● items'))
        self.assertEqual('Query 3', native_query_identity('Query 3 · Completed\nCaptured connection · host:5432/db · session-owner'))
        labels = {'Structure': 'البنية', '{inserts} inserts · {updates} updates · {deletes} deletes': '{inserts} إدراج · {updates} تحديث · {deletes} حذف'}
        self.assertEqual('● Structure · public.items', normalized_native_label('● البنية · public.items', labels))
        self.assertEqual('public.items · 0 inserts · 1 updates · 0 deletes', normalized_native_label('public.items · 0 إدراج · 1 تحديث · 0 حذف', labels))

    def query_activation_fixture(self):
        atspi, _, _, frame, Node = self.protected_field_fixture()
        atspi.Role.PUSH_BUTTON = 'button'
        identity = native_query_identity
        return atspi, frame, Node, identity

    def test_standalone_safety_and_operation_labels_do_not_block_query_owner_resolution(self):
        atspi, frame, Node, identity = self.query_activation_fixture()
        labels = ['Running', 'Completed', 'Failed', 'Cancelled', 'Production',
                  'Transaction open', 'Transaction failed', 'Outcome unknown']
        nodes = [Node('button', (10, 10, 180, 36), frame, ['Tap'], label)
                 for label in labels]
        query = Node('button', (190, 10, 180, 36), frame, ['Tap'],
                     '● Query 3 · Production · Outcome unknown')
        for label in labels:
            self.assertEqual(label, native_query_identity(label))
        self.assertEqual('Query 3', native_query_identity(query.name))
        self.assertIs(query, find_query_tab_activation(atspi, [*nodes, query],
            'Query 3', identity, lambda item: item.get_name())[0])

    def test_query_activation_keeps_owner_when_execution_caption_changes(self):
        atspi, frame, Node, identity = self.query_activation_fixture()
        query = Node('button', (10, 10, 180, 36), frame, ['Focus', 'Tap'],
                     '● Query 3 · Running')
        neighbor = Node('button', (190, 10, 180, 36), frame, ['Tap'], 'Query 30')
        def action_count(item):
            item.name = '● Query 3 · Completed'
            return len(item.actions)
        atspi.Action.get_n_actions = action_count
        result = find_query_tab_activation(atspi, [neighbor, query], 'Query 3', identity,
                                           lambda item: item.get_name())
        self.assertIs(query, result[0])
        self.assertEqual((1, ['Focus', 'Tap']), result[1:])
        self.assertEqual('● Query 3 · Completed', query.name)
        self.assertIsNone(find_query_tab_activation(atspi, [neighbor], 'Query 3', identity,
                                                   lambda item: item.get_name()))

    def test_query_activation_rejects_hidden_disabled_or_focus_only_tabs(self):
        atspi, frame, Node, identity = self.query_activation_fixture()
        query = Node('button', (10, 10, 180, 36), frame, ['Tap'], 'Query 3')
        for state in ('showing', 'sensitive'):
            query.states.remove(state)
            self.assertIsNone(find_query_tab_activation(atspi, [query], 'Query 3', identity,
                                                       lambda item: item.get_name()))
            query.states.add(state)
        query.actions = ['Focus']
        self.assertIsNone(find_query_tab_activation(atspi, [query], 'Query 3', identity,
                                                   lambda item: item.get_name()))
        query.actions = ['Tap']; query.interfaces = ['Component']
        self.assertIsNone(find_query_tab_activation(atspi, [query], 'Query 3', identity,
                                                   lambda item: item.get_name()))

    def test_query_activation_rejects_ambiguous_live_document_owners(self):
        atspi, frame, Node, identity = self.query_activation_fixture()
        nodes = [Node('button', (10, 10, 180, 36), frame, ['Tap'], label)
                 for label in ('Query 3 · Running', '● Query 3 · Completed')]
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous physical query owner'):
            find_query_tab_activation(atspi, nodes, 'Query 3', identity,
                                      lambda item: item.get_name())

    def test_table_activation_preserves_exact_restored_target_identity(self):
        atspi, frame, Node, identity = self.query_activation_fixture()
        prefix = 'native_atspi_fixture · fixture · localhost:5432/busydata · busydata / public / native_atspi_fixture · '
        offline = Node('button', (10, 10, 180, 36), frame, ['Tap'], prefix + '8')
        acquired = Node('button', (190, 10, 180, 36), frame, ['Tap'], prefix + '22bb')
        exact = native_query_identity(acquired.name)
        self.assertIs(acquired, find_query_tab_activation(atspi, [offline, acquired],
            exact, identity, lambda item: item.get_name())[0])
        self.assertIsNone(find_query_tab_activation(atspi, [offline, acquired],
            'native_atspi_fixture', identity, lambda item: item.get_name()))

    def test_query_activation_retains_native_action_count_budget(self):
        atspi, frame, Node, identity = self.query_activation_fixture()
        query = Node('button', (10, 10, 180, 36), frame, ['Tap'], 'Query 3')
        for count in (-1, 65):
            atspi.Action.get_n_actions = lambda _, count=count: count
            with self.assertRaisesRegex(RuntimeError, 'Native action-count budget'):
                find_query_tab_activation(atspi, [query], 'Query 3', identity,
                                          lambda item: item.get_name())

    def modal_focus_fixture(self):
        atspi, _, _, frame, Node = self.protected_field_fixture()
        host = Node('panel', (5, 5, 1280, 720), frame)
        host.interfaces = ['Component']
        host.states.add('focused')
        modal = Node('panel', (5, 5, 1280, 720), host, name='Commit transaction')
        cancel = Node('button', (759, 412, 82, 34), modal, ['Tap', 'Focus'], 'Cancel')
        cancel.states.add('focused')
        approve = Node('button', (850, 412, 94, 34), modal, ['Tap', 'Focus'], 'Approve')
        return atspi, host, modal, cancel, approve, Node

    def test_translated_typed_document_and_provenance_segments_keep_object_identity(self):
        labels = {'Structure': 'البنية', 'Object designer': 'مصمم الكائنات', 'SQL provenance': 'مصدر SQL'}
        self.assertEqual('Structure · Object designer · public.same_name', normalized_native_label('البنية · مصمم الكائنات · public.same_name', labels))
        self.assertEqual('SQL provenance: EXPLAIN SELECT "مصمم الكائنات"', normalized_native_label('مصدر SQL: EXPLAIN SELECT "مصمم الكائنات"', labels))
        self.assertEqual('public.البنية', normalized_native_label('public.البنية', labels))

    def test_translated_palette_label_before_visible_shortcut_keeps_its_binding(self):
        labels = {'File': 'ملف', 'New query': 'استعلام جديد'}
        actual = 'ملف · استعلام جديد   Ctrl+T'
        normalized = normalized_native_label(actual, labels)
        self.assertEqual('File · New query   Ctrl+T', normalized)
        self.assertTrue(palette_rows_ready([normalized], 'New query'))
        self.assertEqual('SELECT "استعلام جديد"',
                         normalized_native_label('SELECT "استعلام جديد"', labels))

    def test_localized_tree_and_plan_state_keep_object_and_engine_evidence(self):
        labels = {'Level': 'المستوى', 'level': 'المستوى',
                  'expanded': 'موسّع', 'collapsed': 'مطوي'}
        self.assertEqual('public.same_name · level 3 · fixture',
                         normalized_native_label('public.same_name · المستوى 3 · fixture', labels))
        self.assertEqual('Level 2, Node Type: Index Scan, expanded',
                         normalized_native_label('المستوى 2, Node Type: Index Scan, موسّع', labels))
        self.assertEqual('SELECT "المستوى"',
                         normalized_native_label('SELECT "المستوى"', labels))

    def test_localized_actionable_grid_row_keeps_value_and_source_identity(self):
        labels = {'Row': 'الصف', 'pending change': 'تغيير معلّق'}
        actual = 'الصف 2, quoted column: 漢😀 · تغيير معلّق'
        self.assertEqual('Row 2, quoted column: 漢😀 · pending change',
                         normalized_native_label(actual, labels))
        self.assertEqual('SELECT "الصف"', normalized_native_label('SELECT "الصف"', labels))

    def test_modal_focus_matches_the_actual_translated_dialog_identity(self):
        atspi, host, modal, cancel, _, _ = self.modal_focus_fixture()
        modal.name = 'تثبيت المعاملة'
        with patch('native_workbench_acceptance.native_catalog_labels',
                   return_value={'Commit transaction': 'تثبيت المعاملة'}):
            self.assertIs(cancel, assert_modal_keyboard_focus(
                atspi, [host, modal, cancel], {'COMMIT'}, 'Commit transaction'))
            modal.name = 'Unrelated dialog'
            with self.assertRaisesRegex(RuntimeError, 'expected dialog'):
                assert_modal_keyboard_focus(atspi, [host, modal, cancel], {'COMMIT'}, 'Commit transaction')

    def test_modal_focus_handoff_during_ancestry_discards_the_mixed_sample(self):
        atspi, host, modal, cancel, approve, _ = self.modal_focus_fixture()
        approve.states.add('focused')
        clear = cancel.clear_cache
        def handoff():
            clear()
            cancel.states.discard('focused')
        cancel.clear_cache = handoff
        with self.assertRaises(NativeModalFocusPending):
            assert_modal_keyboard_focus(atspi, [host, modal, cancel, approve], set(), 'Commit transaction')
        self.assertIs(approve, assert_modal_keyboard_focus(atspi,
            [host, modal, cancel, approve], set(), 'Commit transaction'))

    def test_focused_native_host_ancestor_is_not_a_second_modal_control(self):
        atspi, host, modal, cancel, approve, _ = self.modal_focus_fixture()
        self.assertIs(cancel, assert_modal_keyboard_focus(atspi, [host, modal, cancel, approve],
                                                         {'COMMIT'}, 'Commit transaction'))
        self.assertGreater(host.cache_clears, 0)
        approve.states.add('focused')
        with self.assertRaisesRegex(RuntimeError, 'one focused control'):
            assert_modal_keyboard_focus(atspi, [host, modal, cancel, approve], {'COMMIT'}, 'Commit transaction')
        approve.states.remove('focused')
        # Losing the modal ancestry still rejects the actual control.
        cancel.parent = None
        with self.assertRaisesRegex(RuntimeError, 'expected dialog'):
            assert_modal_keyboard_focus(atspi, [host, modal, cancel], {'COMMIT'}, 'Commit transaction')

    def test_noninteractive_native_host_focus_never_counts_as_a_second_modal_control(self):
        atspi, host, modal, cancel, approve, Node = self.modal_focus_fixture()
        host.parent = None
        unrelated_host = Node('panel', (0, 0, 1280, 720))
        unrelated_host.interfaces = ['Accessible', 'Collection', 'Component']
        unrelated_host.states.add('focused')
        self.assertIs(cancel, assert_modal_keyboard_focus(atspi,
            [unrelated_host, modal, cancel], set(), 'Commit transaction'))
        approve.states.add('focused')
        with self.assertRaisesRegex(RuntimeError, 'one focused control'):
            assert_modal_keyboard_focus(atspi, [unrelated_host, modal, cancel, approve], set(), 'Commit transaction')

    def test_modal_leaf_ancestry_cannot_authorize_other_dialogs_cycles_or_disabled_controls(self):
        atspi, host, modal, cancel, _, Node = self.modal_focus_fixture()
        other = Node('panel', (5, 5, 1280, 720), host, name='Unrelated surface')
        settings = Node('button', (10, 10, 80, 30), other, ['Tap', 'Focus'], 'Settings')
        settings.states.add('focused')
        with self.assertRaisesRegex(RuntimeError, 'expected dialog'):
            assert_modal_keyboard_focus(atspi, [host, settings], set(), 'Commit transaction')
        for state in ('showing', 'sensitive'):
            cancel.states.remove(state)
            with self.subTest(state=state), self.assertRaisesRegex(RuntimeError, 'hidden or disabled'):
                assert_modal_keyboard_focus(atspi, [host, modal, cancel], {'COMMIT'}, 'Commit transaction')
            cancel.states.add(state)
        cancel.name = 'COMMIT'
        with self.assertRaisesRegex(RuntimeError, 'escaped to its workspace'):
            assert_modal_keyboard_focus(atspi, [host, modal, cancel], {'COMMIT'}, 'Commit transaction')
        cancel.name = 'Cancel'
        host.parent = cancel
        with self.assertRaisesRegex(RuntimeError, 'cycle'):
            assert_modal_keyboard_focus(atspi, [host, modal, cancel], {'COMMIT'}, 'Commit transaction')

    def test_zero_or_host_only_focus_needs_bounded_actual_control_acknowledgement(self):
        atspi, host, modal, cancel, _, _ = self.modal_focus_fixture()
        with self.assertRaises(NativeModalFocusPending):
            assert_modal_keyboard_focus(atspi, [], {'COMMIT'}, 'Commit transaction')
        with self.assertRaises(NativeModalFocusPending):
            assert_modal_keyboard_focus(atspi, [host], {'COMMIT'}, 'Commit transaction')
        # A scrollable host with actions is still a container, not a control.
        host.interfaces.append('Action')
        with self.assertRaises(NativeModalFocusPending):
            assert_modal_keyboard_focus(atspi, [host], {'COMMIT'}, 'Commit transaction')
        host.interfaces.remove('Action')
        observations = [[], [host], [host, modal, cancel]]
        calls = []
        def objects(_): return observations.pop(0)
        def wait(predicate, seconds):
            calls.append(seconds)
            self.assertIsNone(predicate())
            self.assertIsNone(predicate())
            return predicate()
        self.assertIs(cancel, wait_modal_keyboard_focus(atspi, object(), objects, wait,
                                                        {'COMMIT'}, 'Commit transaction'))
        self.assertEqual([15], calls)
        original_clear = cancel.clear_cache
        def focus_lost_during_fresh_ancestry():
            original_clear()
            cancel.states.discard('focused')
        cancel.clear_cache = focus_lost_during_fresh_ancestry
        with self.assertRaises(NativeModalFocusPending):
            assert_modal_keyboard_focus(atspi, [host, modal, cancel], {'COMMIT'}, 'Commit transaction')
        cancel.clear_cache = original_clear
        cancel.states.add('focused')
        def timeout(predicate, seconds):
            self.assertEqual(15, seconds)
            self.assertIsNone(predicate())
            raise TimeoutError('Unacknowledged traversal')
        # An unchanged previous leaf cannot acknowledge a later key before its
        # actual focus event. No traversal/text/action retry is dispatched here.
        with self.assertRaises(TimeoutError):
            wait_modal_keyboard_focus(atspi, object(), lambda _: [host, modal, cancel], timeout,
                                      {'COMMIT'}, 'Commit transaction', previous=cancel)

    def protected_field_fixture(self):
        atspi = types.SimpleNamespace(
            StateType=types.SimpleNamespace(**{name: name.lower() for name in
                ('FOCUSED', 'VISIBLE', 'SHOWING', 'SENSITIVE', 'EDITABLE')}),
            Role=types.SimpleNamespace(PASSWORD_TEXT='password', FRAME='frame', PANEL='panel', MENU_ITEM='menu-item', CHECK_MENU_ITEM='check-menu-item', RADIO_MENU_ITEM='radio-menu-item'),
            CoordType=types.SimpleNamespace(WINDOW='window'),
            Component=types.SimpleNamespace(get_extents=lambda item, _: types.SimpleNamespace(
                **dict(zip(('x', 'y', 'width', 'height'), item.bounds)))),
            Action=types.SimpleNamespace(get_n_actions=lambda item: len(item.actions),
                get_action_name=lambda item, index: item.actions[index]))
        class Node:
            def __init__(self, role, bounds, parent=None, actions=(), name=''):
                self.role, self.bounds, self.parent = role, bounds, parent
                self.actions, self.name = list(actions), name
                self.states = {'showing', 'visible', 'sensitive'}
                self.interfaces = ['Component', 'Action']
                self.cache_clears = 0
            def clear_cache(self): self.cache_clears += 1
            def get_parent(self): return self.parent
            def get_role(self): return self.role
            def get_role_name(self): return self.role
            def get_name(self): return self.name
            def get_interfaces(self): return self.interfaces
            def get_state_set(self):
                return types.SimpleNamespace(contains=lambda state: state in self.states)
        frame = Node('frame', (0, 0, 1290, 730))
        viewport = Node('panel', (345, 200, 600, 380), frame,
                        actions=['ScrollUp', 'ScrollDown'])
        field = Node('password', (345, 505, 600, 59), viewport, name='Password')
        field.interfaces.extend(['EditableText', 'Text'])
        field.states = {'focused', 'visible', 'showing', 'sensitive', 'editable'}
        return atspi, field, viewport, frame, Node

    def test_protected_field_requires_actual_showing_focus_and_full_native_clipping(self):
        atspi, field, viewport, frame, _ = self.protected_field_fixture()
        receipt = assert_visible_protected_password(atspi, field)
        self.assertTrue(receipt['showing'])
        self.assertEqual([345, 505, 600, 59], receipt['bounds'])
        self.assertEqual([[345, 200, 600, 380]], receipt['scrollViewportBounds'])
        self.assertTrue(receipt['visible'])
        self.assertGreater(field.cache_clears, 0)
        for state in ('focused', 'visible', 'showing', 'sensitive', 'editable'):
            with self.subTest(state=state):
                field.states.remove(state)
                with self.assertRaisesRegex(RuntimeError, 'not focused, visible, showing and editable'):
                    assert_visible_protected_password(atspi, field)
                field.states.add(state)
        for bounds in ((345, 626, 600, 59), (345, 530, 600, 59),
                       (344, 505, 600, 59), (345, 505, 601, 59)):
            with self.subTest(bounds=bounds):
                field.bounds = bounds
                with self.assertRaisesRegex(RuntimeError, 'offscreen or clipped'):
                    assert_visible_protected_password(atspi, field)
        field.bounds = (345, 505, 600, 59)
        frame.bounds = (0, 0, 900, 730)
        with self.assertRaisesRegex(RuntimeError, 'offscreen or clipped'):
            assert_visible_protected_password(atspi, field)

    def test_protected_geometry_never_accepts_an_unprotected_or_unbounded_node(self):
        for change, expected in (
                (lambda field, viewport, frame: setattr(field, 'role', 'text'), 'protected password role'),
                (lambda field, viewport, frame: field.interfaces.remove('EditableText'), 'editable text geometry'),
                (lambda field, viewport, frame: setattr(field, 'bounds', (345, 505, 0, 59)), 'invalid visible bounds'),
                (lambda field, viewport, frame: setattr(field, 'bounds', (345, 505, float('nan'), 59)), 'invalid visible bounds'),
                (lambda field, viewport, frame: setattr(viewport, 'actions', []), 'scroll viewport or native window'),
                (lambda field, viewport, frame: setattr(frame, 'role', 'panel'), 'scroll viewport or native window'),
                (lambda field, viewport, frame: setattr(viewport, 'actions', ['ScrollDown'] * 65), 'action-count budget')):
            with self.subTest(expected=expected):
                atspi, field, viewport, frame, _ = self.protected_field_fixture()
                change(field, viewport, frame)
                with self.assertRaisesRegex(RuntimeError, expected):
                    assert_visible_protected_password(atspi, field)

    def test_fitting_protected_form_needs_no_scroll_action_but_still_proves_containment(self):
        atspi, field, viewport, frame, _ = self.protected_field_fixture()
        viewport.actions = []
        viewport.name = 'Data Sources and Drivers'
        receipt = assert_visible_protected_password(atspi, field)
        self.assertEqual([], receipt['scrollViewportBounds'])
        self.assertEqual([[345, 200, 600, 380]], receipt['boundedFormBounds'])
        field.bounds = (345, 530, 600, 59)
        with self.assertRaisesRegex(RuntimeError, 'offscreen or clipped'):
            assert_visible_protected_password(atspi, field)

    def test_password_traversal_acknowledges_fresh_focus_once_without_retry_or_text_mutation(self):
        atspi, password, viewport, frame, Node = self.protected_field_fixture()
        names = ['Password']
        fields = [password]
        for field in fields:
            field.interfaces.extend(['EditableText'])
            field.states.discard('focused')
        phase, commands, report = [-1], [], {}
        def command(argv):
            commands.append(argv)
            phase[0] += 1
            for field in fields: field.states.discard('focused')
            fields[phase[0]].states.add('focused')
        def objects(_): return fields
        def wait(predicate):
            result = predicate()
            if not result: raise TimeoutError('Actual focus not acknowledged')
            return result
        self.assertIs(password, focus_profile_password(atspi, object(), objects, wait, command, report))
        self.assertEqual([['xdotool', 'key', '--clearmodifiers', 'Tab']], commands)
        self.assertEqual(names, report['nativePasswordAcknowledgedForwardTabs'])
        self.assertTrue(report['nativeProtectedPasswordVisibility']['focused'])
        commands.clear()
        password.states.discard('focused')
        def stale_command(argv): commands.append(argv)
        with self.assertRaises(TimeoutError):
            focus_profile_password(atspi, object(), objects, wait, stale_command, {})
        self.assertEqual([['xdotool', 'key', '--clearmodifiers', 'Tab']], commands)

    def test_activation_waits_for_a_real_action_and_never_substitutes_focus(self):
        atspi, _, _, _, Node = self.protected_field_fixture()
        button = Node('button', (1, 1, 40, 30), actions=['Focus'], name='Connections')
        self.assertIsNone(find_live_activation(atspi, [button], 'Connections'))
        button.actions = []
        self.assertIsNone(find_live_activation(atspi, [button], 'Connections'))
        disabled = Node('button', (1, 1, 40, 30), actions=['Focus'], name='Connections')
        button.actions = ['Focus', 'Tap']
        self.assertEqual(button, find_live_activation(atspi, [disabled, button], 'Connections')[0])
        self.assertEqual((button, 1, ['Focus', 'Tap']), find_live_activation(atspi, [button], 'Connections'))
        button.states.remove('showing')
        self.assertIsNone(find_live_activation(atspi, [button], 'Connections'))

    def test_actual_composed_settings_must_match_every_native_case_despite_a_pass_flag(self):
        for expected in CASES:
            receipt = {'passed': True, 'releaseMode': True,
                'entrypoint': 'integration_test/platform_settings_linux.dart',
                'platformBrightness': expected['brightness'],
                'composedThemeBrightness': expected['brightness'],
                'textScale': expected['textScale'], 'highContrast': expected['highContrast'],
                'yaruHighContrast': expected['highContrast'],
                'disableAnimations': not expected['animations'],
                'nativeGtkAnimationsEnabled': expected['animations'],
                'direction': expected['direction'], 'resolvedLocale': expected['language'],
                'nativeGtkFont': {'family': 'Sans', 'size': 11},
                'workspaceRenderBox': {'width': 800, 'height': 600},
                'composedFontSize': 14, 'renderedFontSize': 14 * expected['textScale']}
            if 'devicePixelRatio' in expected:
                receipt['devicePixelRatio'] = expected['devicePixelRatio']
            self.assertIs(receipt, validate_composed_settings(expected, receipt))
            changes = {'releaseMode': False, 'passed': False,
                'entrypoint': 'lib/main_linux.dart', 'textScale': expected['textScale'] + .125,
                'highContrast': not expected['highContrast'],
                'yaruHighContrast': not expected['highContrast'],
                'nativeGtkAnimationsEnabled': not expected['animations'],
                'disableAnimations': expected['animations'],
                'composedThemeBrightness': 'other', 'platformBrightness': 'other',
                'direction': 'other', 'resolvedLocale': 'other',
                'nativeGtkFont': {'family': '', 'size': 0},
                'workspaceRenderBox': None, 'renderedFontSize': 1}
            if 'devicePixelRatio' in expected:
                changes['devicePixelRatio'] = 1.0
            for field, wrong in changes.items():
                with self.subTest(case=expected['name'], field=field), self.assertRaises(RuntimeError):
                    validate_composed_settings(expected, dict(receipt, **{field: wrong}))

    def test_native_focus_accepts_existing_receipt_and_requires_new_acknowledgement(self):
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(FOCUSED='focused'))
        class Control:
            focused = True
            def clear_cache(self): pass
            def get_interfaces(self): return []
            def get_state_set(self):
                return types.SimpleNamespace(contains=lambda state: self.focused)
        control = Control()
        calls = []
        def grab(item):
            calls.append(item)
            item.focused = True
            return True
        atspi.Component = types.SimpleNamespace(grab_focus=grab)
        def wait(condition):
            if not condition(): raise TimeoutError('Missing actual focus acknowledgement')
        focus_native_control(atspi, control, wait)
        self.assertEqual(calls, [])
        control.focused = False
        focus_native_control(atspi, control, wait)
        self.assertEqual(calls, [control])
        control.focused = False
        atspi.Component.grab_focus = lambda item: False
        with self.assertRaises(TimeoutError): focus_native_control(atspi, control, wait)

    def test_modal_focus_requires_one_live_enabled_control_and_rejects_workspace_escape(self):
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(
            FOCUSED='focused', SHOWING='showing', SENSITIVE='sensitive'))
        class Control:
            def __init__(self, name, states): self.name, self.states = name, states
            def get_name(self): return self.name
            def clear_cache(self): pass
            def get_parent(self): return None
            def get_interfaces(self): return ['Action']
            def get_state_set(self):
                return types.SimpleNamespace(contains=lambda state: state in self.states)
        cancel = Control('Cancel', {'focused', 'showing', 'sensitive'})
        self.assertIs(cancel, assert_modal_keyboard_focus(atspi, [cancel], {'COMMIT'}))
        cases = [([], 'one focused'),
                 ([cancel, Control('Approve', cancel.states)], 'one focused'),
                 ([Control('COMMIT', cancel.states)], 'escaped'),
                 ([Control('SQL editor · fixture', cancel.states)], 'escaped'),
                 ([Control('Cancel', {'focused', 'showing'})], 'hidden or disabled'),
                 ([Control('Cancel', {'focused', 'sensitive'})], 'hidden or disabled')]
        for nodes, expected in cases:
            with self.subTest(expected=expected), self.assertRaisesRegex(RuntimeError, expected):
                assert_modal_keyboard_focus(atspi, nodes, {'COMMIT'})

    def test_reader_ancestry_is_live_and_rejects_cycles_or_excess_depth(self):
        class Node:
            def __init__(self, parent=None): self.live = self.cached = parent
            def clear_cache(self): self.cached = self.live
            def get_parent(self): return self.cached
        frame = Node()
        socket = Node()
        editor = Node(socket)
        self.assertEqual([socket], accessible_ancestors(editor))
        socket.live = frame
        self.assertEqual([socket, frame], accessible_ancestors(editor))
        with self.assertRaisesRegex(RuntimeError, 'ancestor budget'):
            accessible_ancestors(editor, limit=1)
        frame.live = editor
        with self.assertRaisesRegex(RuntimeError, 'cycle'):
            accessible_ancestors(editor)

    def test_enabled_modal_close_wins_over_disabled_window_close_but_ambiguity_fails(self):
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(SHOWING='showing', SENSITIVE='sensitive'), Role=types.SimpleNamespace(MENU_ITEM='menu-item', CHECK_MENU_ITEM='check-menu-item', RADIO_MENU_ITEM='radio-menu-item'))
        class Control:
            def __init__(self, sensitive): self.sensitive = sensitive
            def get_name(self): return 'Close'
            def get_role(self): return 'button'
            def get_interfaces(self): return ['Action']
            def get_state_set(self): return types.SimpleNamespace(contains=lambda state: state == 'showing' or self.sensitive)
        window, modal = Control(False), Control(True)
        self.assertIs(modal, find_live_control(atspi, [window, modal], 'Close'))
        self.assertIsNone(find_live_control(atspi, [window], 'Close'))
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_live_control(atspi, [window, modal, Control(True)], 'Close')

    def test_native_menu_selection_scopes_shared_action_labels_but_rejects_duplicate_entries(self):
        atspi = types.SimpleNamespace(StateType=types.SimpleNamespace(SHOWING='showing', SENSITIVE='sensitive'), Role=types.SimpleNamespace(MENU_ITEM='menu-item', CHECK_MENU_ITEM='check-menu-item', RADIO_MENU_ITEM='radio-menu-item'))
        def control(role):
            class Control:
                def get_name(self): return 'New query'
                def get_role(self): return role
                def get_interfaces(self): return ['Action']
                def get_state_set(self): return types.SimpleNamespace(contains=lambda _: True)
                def clear_cache(self): pass
                def get_parent(self): return None
            return Control()
        toolbar, entry = control('button'), control('menu-item')
        # A popup is published asynchronously after the context-menu key. Its
        # background toolbar must never satisfy a pending menu-only lookup.
        self.assertIsNone(find_live_control(atspi, [toolbar], 'New query', menu_only=True))
        self.assertIs(find_live_control(atspi, [toolbar, entry], 'New query', menu_only=True), entry)
        self.assertIs(find_live_control(atspi, [toolbar, entry], 'New query'), entry)
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            find_live_control(atspi, [toolbar, entry, control('menu-item')], 'New query')
        atspi.Role.MENU = 'menu'
        toolbar.clear_cache = lambda: None
        toolbar.get_parent = lambda: None
        popup = types.SimpleNamespace(get_name=lambda: '', get_role=lambda: 'menu', get_interfaces=lambda: [],
            get_state_set=lambda: types.SimpleNamespace(contains=lambda _: True))
        self.assertIsNone(find_live_control(atspi, [toolbar, popup], 'New query'))
        self.assertIs(find_live_control(atspi, [toolbar, popup, entry], 'New query'), entry)

    def test_closed_modal_cached_edges_do_not_survive_a_live_tree_snapshot(self):
        class Node:
            def __init__(self, children=()):
                self.live = list(children)
                self.cached = list(children)
            def clear_cache(self): self.cached = list(self.live)
            def get_child_count(self): return len(self.cached)
            def get_child_at_index(self, index): return self.cached[index]
        close = Node()
        modal = Node([close])
        application = Node([modal])
        self.assertEqual([application, modal, close], fresh_accessible_objects(application))
        application.live = []
        self.assertEqual([application], fresh_accessible_objects(application))
        application.live = [modal] * 513
        with self.assertRaisesRegex(RuntimeError, 'node budget'):
            fresh_accessible_objects(application)

    def test_disappearing_native_node_retries_the_complete_bounded_snapshot(self):
        class TransientError(Exception):
            pass
        class Node:
            def __init__(self, children=(), failures=0):
                self.children = list(children)
                self.failures = failures
                self.reads = 0
            def clear_cache(self):
                self.reads += 1
                if self.failures:
                    self.failures -= 1
                    raise TransientError()
            def get_child_count(self): return len(self.children)
            def get_child_at_index(self, index): return self.children[index]
        completion = Node(failures=1)
        application = Node([completion])
        self.assertEqual([application, completion], fresh_accessible_objects(
            application, transient_errors=(TransientError,)))
        self.assertEqual(application.reads, 2)
        completion.failures = 3
        with self.assertRaises(TransientError):
            fresh_accessible_objects(application, transient_errors=(TransientError,))
        application.children = [completion] * 513
        with self.assertRaisesRegex(RuntimeError, 'node budget'):
            fresh_accessible_objects(application, transient_errors=(TransientError,))

    def test_snapshot_retry_dispatches_pending_removal_before_restarting_from_root(self):
        class TransientError(Exception):
            pass
        class Node:
            def __init__(self, children=(), retired=False):
                self.children, self.retired = list(children), retired
                self.reads = 0
            def clear_cache(self): self.reads += 1
            def get_child_count(self):
                if self.retired: raise TransientError()
                return len(self.children)
            def get_child_at_index(self, index): return self.children[index]
        retired, live = Node(retired=True), Node()
        application = Node([live, retired])
        dispatched = []
        def dispatch():
            dispatched.append(True)
            application.children = [live]
        self.assertEqual([application, live], fresh_accessible_objects(application,
            transient_errors=(TransientError,), between_attempts=dispatch))
        self.assertEqual([True], dispatched)
        self.assertEqual(2, application.reads)
        self.assertEqual(2, live.reads)

    def test_snapshot_retry_remains_bounded_and_never_hides_persistent_or_limit_errors(self):
        class TransientError(Exception):
            pass
        class Node:
            def __init__(self): self.reads = 0
            def clear_cache(self): self.reads += 1
            def get_child_count(self): raise TransientError()
        application, dispatched = Node(), []
        with self.assertRaises(TransientError):
            fresh_accessible_objects(application, transient_errors=(TransientError,),
                between_attempts=lambda: dispatched.append(True))
        self.assertEqual(3, application.reads)
        self.assertEqual([True, True], dispatched)
        application.get_child_count = lambda: 513
        with self.assertRaises(NativeNodeBudgetExceeded):
            fresh_accessible_objects(application, transient_errors=(TransientError,),
                between_attempts=lambda: self.fail('Node limit must fail immediately'))
        def invalid(): raise ValueError('Invalid transport')
        application.get_child_count = invalid
        with self.assertRaisesRegex(ValueError, 'Invalid transport'):
            fresh_accessible_objects(application, transient_errors=(TransientError,),
                between_attempts=lambda: self.fail('Unexpected error must propagate'))

    def test_native_chord_is_never_retried_and_releases_its_modifier_on_failure(self):
        for shift in (False, True):
            self.check_native_chord_modifiers(shift)

    def check_native_chord_modifiers(self, shift):
        for failure in ('press', 'acknowledgement', None):
            with self.subTest(failure=failure):
                commands = []
                def command(argv):
                    commands.append(argv)
                    if failure == 'press' and argv == ['xdotool', 'key', 'z']:
                        raise RuntimeError('Synthetic press failure')
                def wait(predicate):
                    if failure == 'acknowledgement':
                        raise TimeoutError('Synthetic acknowledgement timeout')
                    return predicate()
                if failure:
                    with self.assertRaises((RuntimeError, TimeoutError)):
                        control_key_until(command, wait, 'z', lambda: True, shift=shift)
                else:
                    self.assertTrue(control_key_until(command, wait, 'z', lambda: True, shift=shift))
                expected = [['xdotool', 'keydown', 'ctrl']]
                if shift: expected.append(['xdotool', 'keydown', 'shift'])
                expected.append(['xdotool', 'key', 'z'])
                if shift: expected.append(['xdotool', 'keyup', 'shift'])
                expected.append(['xdotool', 'keyup', 'ctrl'])
                self.assertEqual(expected, commands)

    def test_private_snap_build_requires_and_restores_the_exact_ordinary_product(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            bundle = root / 'build/linux/x64/release/bundle'
            report = self.fixture(bundle)
            report['buildId'] = 'ordinary-build'
            (root / 'build/linux-release-build.json').write_text(json.dumps(report))
            app = bundle / 'lib/libapp.so'
            original = app.read_bytes()
            app.write_bytes(b'earlier private performance payload')
            with patch.object(build_snap_acceptance, 'ROOT', root), \
                 patch.object(build_snap_acceptance, 'verify_bundle', return_value='backend'), \
                 patch.object(build_snap_acceptance, 'source_hash', return_value='source'), \
                 patch('sys.argv', ['build_snap_acceptance', '--no-pub']), \
                 patch.object(build_snap_acceptance.subprocess, 'run') as run:
                with self.assertRaisesRegex(RuntimeError, 'contents changed: lib/libapp.so'):
                    build_snap_acceptance.main()
                run.assert_not_called()
                app.write_bytes(original)
                def build(*args, **kwargs):
                    app.write_bytes(b'new private installed acceptance payload')
                run.side_effect = build
                with patch.object(build_snap_acceptance, 'verify_jar', return_value='backend'), \
                     patch.object(build_snap_acceptance, 'command_output', return_value={'actual': 'test SDK'}), \
                     patch.object(build_snap_acceptance, 'revalidate_receipt', return_value={'status': 'passed', 'reportSha256': 'official-source-proof'}):
                    build_snap_acceptance.main()
                self.assertEqual(str(root / 'build/official-dependencies/pub-cache'), run.call_args.kwargs['env']['PUB_CACHE'])
                with patch.object(build_snap_acceptance, 'revalidate_receipt', side_effect=[{'reportSha256': 'before'}, {'reportSha256': 'changed'}]):
                    with self.assertRaisesRegex(RuntimeError, 'dependency proof changed'):
                        build_snap_acceptance.main()
            self.assertEqual(original, app.read_bytes())
            self.assertFalse((bundle / 'installed-acceptance-build.json').exists())
            verify_existing_bundle('linux', report, bundle, 'source')
            manifest = json.loads((root / 'build/snap-acceptance-build.json').read_text())
            self.assertEqual('ordinary-build', manifest['productBuildId'])
            self.assertEqual(hashlib.sha256(original).hexdigest(), manifest['productArtifactHashes']['lib/libapp.so'])
            self.assertNotEqual(manifest['artifacts']['lib/libapp.so'], manifest['productArtifactHashes']['lib/libapp.so'])
            with tarfile.open(root / 'build/busydata-installed-acceptance.tar.gz') as archive:
                self.assertEqual(0o644, archive.getmember('bundle/installed-acceptance-build.json').mode)
                self.assertEqual(0o755, archive.getmember('bundle/backend/runtime').mode)

    def test_ci_native_evidence_retains_reports_but_excludes_private_fixture_material(self):
        workflow = Path(__file__).resolve().parents[1] / '.github/workflows/verify.yml'
        lines = workflow.read_text().splitlines()
        path_blocks = []
        for index, line in enumerate(lines):
            if line.strip() != 'path: |':
                continue
            indentation = len(line) - len(line.lstrip())
            paths = []
            for following in lines[index + 1:]:
                if following.strip() and len(following) - len(following.lstrip()) <= indentation:
                    break
                if following.strip(): paths.append(following.strip())
            path_blocks.append(paths)
        native = [paths for paths in path_blocks if 'build/native-accessibility/' in paths]
        self.assertTrue(native, 'Required underlying native logs must be retained')
        for paths in native:
            excludes = [path[1:] for path in paths if path.startswith('!')]
            for private in ['password', 'fixture.sql', 'selected-key', 'client-certificate.key']:
                sample = 'build/native-accessibility/run-id/private-fixture/' + private
                self.assertTrue(any(fnmatch.fnmatchcase(sample, pattern) for pattern in excludes), sample)
            self.assertFalse(any(fnmatch.fnmatchcase('build/native-accessibility/run-id/report.json', pattern)
                                 for pattern in excludes))

    def fixture(self, root):
        files = []
        for name in ('busydata', 'lib/libapp.so', 'backend/runtime/bin/java',
                     'backend/lib/busydata-backend-0.1.0.jar', 'backend/dependency-inventory.json'):
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(name.encode())
            files.append({'path': name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                          'bytes': path.stat().st_size, 'mode': path.stat().st_mode & 0o777})
        publish_public_bundle(root)
        for item in files:
            item['mode'] = (root / item['path']).stat().st_mode & 0o777
        return {'exitCode': 0, 'buildSourceSha256': 'source', 'entrypoint': 'lib/main_linux.dart', 'files': files}

    def test_unchanged_runner_cannot_authorize_a_private_or_replaced_flutter_payload(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = self.fixture(root)
            verified = verify_existing_bundle('linux', report, root, 'source')
            self.assertEqual(5, len(verified))
            (root / 'lib/libapp.so').write_bytes(b'private acceptance entrypoint')
            with self.assertRaisesRegex(RuntimeError, 'contents changed: lib/libapp.so'):
                verify_existing_bundle('linux', report, root, 'source')
            self.assertEqual(verified['busydata'], hashlib.sha256((root / 'busydata').read_bytes()).hexdigest())

    def test_backend_inventory_modes_extra_files_and_freshness_are_checked(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = self.fixture(root)
            for name in ('backend/runtime/bin/java', 'backend/lib/busydata-backend-0.1.0.jar',
                         'backend/dependency-inventory.json'):
                path = root / name
                before = path.read_bytes()
                path.write_bytes(b'replaced')
                with self.assertRaisesRegex(RuntimeError, 'contents changed'):
                    verify_existing_bundle('linux', report, root, 'source')
                path.write_bytes(before)
            path = root / 'busydata'
            mode = path.stat().st_mode & 0o777
            path.chmod(mode ^ 0o100)
            with self.assertRaisesRegex(RuntimeError, 'contents changed'):
                verify_existing_bundle('linux', report, root, 'source')
            path.chmod(mode)
            (root / 'extra').write_text('unrecorded')
            with self.assertRaisesRegex(RuntimeError, 'inventory differs'):
                verify_existing_bundle('linux', report, root, 'source')
            (root / 'extra').unlink()
            with self.assertRaisesRegex(RuntimeError, 'fresh ordinary'):
                verify_existing_bundle('linux', report, root, 'new source')
            report['entrypoint'] = 'integration_test/private.dart'
            with self.assertRaisesRegex(RuntimeError, 'fresh ordinary'):
                verify_existing_bundle('linux', report, root, 'source')

    def test_private_directory_regression_is_rejected_without_repair(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = self.fixture(root)
            runtime = root / 'backend/runtime'
            runtime.chmod(0o700)
            with self.assertRaisesRegex(RuntimeError, 'Public bundle permissions differ'):
                verify_existing_bundle('linux', report, root, 'source')
            self.assertEqual(0o700, runtime.stat().st_mode & 0o777)

    def test_invalid_duplicate_or_escaping_paths_are_not_read(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            report = self.fixture(root)
            report['files'].append(report['files'][0])
            with self.assertRaisesRegex(RuntimeError, 'inventory path'):
                verify_existing_bundle('linux', report, root, 'source')
            report['files'][-1] = {'path': '../outside'}
            with self.assertRaisesRegex(RuntimeError, 'inventory path'):
                verify_existing_bundle('linux', report, root, 'source')

    def test_bundle_links_remain_contained_and_match_the_recorded_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / 'bundle'
            root.mkdir()
            report = self.fixture(root)
            link = root / 'lib/current.so'
            link.symlink_to('libapp.so')
            report['files'].append({'path': 'lib/current.so', 'linkTarget': 'libapp.so'})
            verify_existing_bundle('linux', report, root, 'source')
            link.unlink()
            outside = Path(directory) / 'outside.so'
            outside.write_bytes(b'unreviewed external payload')
            link.symlink_to('../../outside.so')
            report['files'][-1]['linkTarget'] = '../../outside.so'
            with self.assertRaisesRegex(RuntimeError, 'link escapes'):
                verify_existing_bundle('linux', report, root, 'source')
            link.unlink()
            link.symlink_to('missing.so')
            report['files'][-1]['linkTarget'] = 'missing.so'
            with self.assertRaisesRegex(RuntimeError, 'link changed'):
                verify_existing_bundle('linux', report, root, 'source')

    def test_real_buffered_diagnostic_becomes_visible_before_reader_shutdown(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'reader.log'
            with path.open('w', encoding='utf-8') as stream:
                stream.write("SPEECH OUTPUT: 'already emitted'\n")
                self.assertEqual('', path.read_text())
                debug = types.SimpleNamespace(debugFile=stream, LEVEL_INFO=800, debugLevel=0)
                module = types.ModuleType('orca')
                module.debug = debug
                customization = configure_reader_receipts(root / 'private-data')
                self.assertTrue(customization.is_relative_to(root / 'private-data'))
                self.assertEqual(0o600, customization.stat().st_mode & 0o777)
                with patch.dict('sys.modules', {'orca': module}):
                    runpy.run_path(str(customization))
                stream.write("SPEECH OUTPUT: 'Row 2, n: second'\n")
                self.assertIn("SPEECH OUTPUT: 'Row 2, n: second'", path.read_text())
                self.assertFalse(stream.closed)
                self.assertTrue(stream.line_buffering)
                self.assertEqual(debug.LEVEL_INFO, debug.debugLevel)

    def test_reader_diagnostic_filter_preserves_real_speech_and_failures_with_the_same_byte_budget(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / 'reader.log'
            with path.open('w', encoding='utf-8') as stream:
                debug = types.SimpleNamespace(debugFile=stream, LEVEL_INFO=800, debugLevel=0)
                module = types.ModuleType('orca')
                module.debug = debug
                customization = configure_reader_receipts(root / 'private-data')
                with patch.dict('sys.modules', {'orca': module}):
                    runpy.run_path(str(customization))
                for _ in range(1000):
                    debug.debugFile.writelines(['07:00:00 - GSETTINGS SCHEMA HANDLE: cached lookup', '\n'])
                    debug.debugFile.writelines(['GSETTINGS REGISTRY: cached lookup', '\n'])
                receipts = ["07:00:01 - SPEECH OUTPUT: '日'\n",
                            "07:00:02 - SPEECH OUTPUT: 'GSETTINGS REGISTRY: literal value'\n",
                            '07:00:03 - ERROR: native reader failure\n',
                            '07:00:04 - ORCA: Starting Atspi main event loop\n',
                            '07:00:04 - AXText: actual displayed text\n']
                for receipt in receipts:
                    debug.debugFile.writelines([receipt])
                self.assertEqual(''.join(receipts[:4]), path.read_text())
                self.assertFalse(stream.closed)
                self.assertTrue(stream.line_buffering)


if __name__ == '__main__':
    unittest.main()
