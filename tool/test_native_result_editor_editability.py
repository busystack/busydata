"""Read-only native cell readiness; actions never belong in observation polls."""
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

from native_result_editor_acceptance import (native_cell_editability_hint,
    wait_native_selected_cell_editable)
from native_workbench_acceptance import NativeSnapshotIncomplete, NativeNodeBudgetExceeded
from verify_native_accessibility import native_wait


class NativeSelectedCellEditabilityTest(unittest.TestCase):
    generation = ('document-owner', 'retained-source', 'retained-display')

    class Node:
        def __init__(self, *, identity=None, description='TEXT · Read-only cell',
                     name='Row 2, n: second', selected=True):
            self.identity, self.description, self.name = identity, description, name
            self.selected = selected
        def get_state_set(self):
            return types.SimpleNamespace(contains=lambda state:
                state == 'showing' or (state == 'selected' and self.selected))
        def get_interfaces(self): return ['Action']
        def get_attributes(self):
            return {} if self.identity is None else {
                'id': 'busydata.result.cell.v1:' + json.dumps(list(self.identity))}
        def get_name(self): return self.name
        def get_description(self): return self.description

    def atspi(self):
        return types.SimpleNamespace(StateType=types.SimpleNamespace(
            SHOWING='showing', SELECTED='selected'))

    def ready(self, nodes, wait, observed, *, selected=lambda: 'fixture-table',
              navigation=lambda: True):
        return wait_native_selected_cell_editable(self.atspi(), nodes, wait,
            source_owner='fixture-table', selected_owner=selected,
            generation=self.generation, row=1, column=1,
            label='Row 2, n: second', native_name=lambda node: node.get_name(),
            editable_label='Editable cell', readonly_label='Read-only cell',
            navigation_ready=navigation, observation=observed)

    def test_delayed_existing_assessment_and_navigation_precede_one_inspect_dispatch(self):
        grid = self.Node(identity=self.generation + (1, 1))
        record_copy = self.Node(description='Editable cell')
        inspect = Mock()
        state, observed = {'navigation': False}, {}
        def wait(predicate):
            for navigation, hint in ((False, 'TEXT · Editable cell'),
                                     (True, 'TEXT · Read-only cell'),
                                     (True, 'TEXT · Editable cell')):
                state['navigation'], grid.description = navigation, hint
                inspect.assert_not_called()
                value = predicate()
                if value: return value
            raise TimeoutError('No complete readiness acknowledgement')
        result = self.ready(lambda: [record_copy, grid], wait, observed,
                            navigation=lambda: state['navigation'])
        inspect(result)
        inspect.assert_called_once_with(grid)
        self.assertTrue(observed['editableAcknowledged'])
        self.assertEqual(['navigation-pending', 'read-only', 'editable'], observed['history'])
        self.assertEqual(3, observed['observations'])
        self.assertNotIn('second', json.dumps(observed))

    def test_persistent_readonly_keeps_original_timeout_without_inspect_or_reassessment(self):
        grid = self.Node(identity=self.generation + (1, 1))
        clock, observed, inspect = [0.0], {}, Mock()
        context = types.SimpleNamespace(pending=lambda: False, iteration=Mock())
        with tempfile.TemporaryDirectory() as directory, \
                patch('verify_native_accessibility.time.monotonic', side_effect=lambda: clock[0]), \
                patch('verify_native_accessibility.time.sleep', side_effect=lambda seconds: clock.__setitem__(0, clock[0] + seconds)):
            with self.assertRaisesRegex(TimeoutError, '^Native acceptance condition deadline$'):
                result = self.ready(lambda: [grid],
                    lambda predicate: native_wait(predicate, context, Path(directory) / 'reader.log', .1), observed)
                inspect(result)
        inspect.assert_not_called()
        self.assertAlmostEqual(.12, clock[0])
        self.assertEqual(4, observed['observations'])
        self.assertEqual('read-only', observed['lastObservation']['state'])
        self.assertFalse(observed['lastObservation']['centralReasonAvailable'])

    def test_document_owner_or_any_generation_component_change_is_fatal(self):
        for changed in ('document', 'owner', 'source', 'display'):
            with self.subTest(changed=changed):
                identity = list(self.generation)
                if changed != 'document': identity[('owner', 'source', 'display').index(changed)] = 'replacement'
                grid = self.Node(identity=tuple(identity) + (1, 1), description='TEXT · Editable cell')
                observed = {}
                with self.assertRaisesRegex(RuntimeError, 'owner changed|generation changed'):
                    self.ready(lambda: [grid], lambda predicate: predicate(), observed,
                        selected=lambda: 'other-table' if changed == 'document' else 'fixture-table')
                self.assertFalse(observed['editableAcknowledged'])

    def test_owner_change_after_read_cannot_authorize_the_inspector(self):
        grid = self.Node(identity=self.generation + (1, 1), description='TEXT · Editable cell')
        owners = iter(['fixture-table', 'replacement-table'])
        with self.assertRaisesRegex(RuntimeError, 'document owner changed'):
            self.ready(lambda: [grid], lambda predicate: predicate(), {}, selected=lambda: next(owners))

    def test_incomplete_snapshot_stays_pending_and_other_failures_remain_fatal(self):
        grid = self.Node(identity=self.generation + (1, 1), description='TEXT · Editable cell')
        calls, observed = [0], {}
        def nodes():
            calls[0] += 1
            if calls[0] == 1: raise NativeSnapshotIncomplete('missing child')
            return [grid]
        def wait(predicate):
            self.assertIsNone(predicate())
            return predicate()
        self.assertIs(grid, self.ready(nodes, wait, observed))
        self.assertEqual(['incomplete', 'editable'], observed['history'])
        for failure in (NativeNodeBudgetExceeded(513, 0, 0, 512),
                        RuntimeError('Invalid native child count'), ValueError('Transport failure')):
            with self.subTest(failure=type(failure).__name__):
                read = Mock(side_effect=failure)
                with self.assertRaises(type(failure)) as caught:
                    self.ready(read, lambda predicate: predicate(), {})
                self.assertIs(failure, caught.exception)
                read.assert_called_once_with()
        with self.assertRaises(TypeError):
            self.ready(lambda: None, lambda predicate: predicate(), {})

    def test_duplicate_or_malformed_grid_identity_does_not_accept_a_record_copy(self):
        grid = self.Node(identity=self.generation + (1, 1), description='TEXT · Editable cell')
        duplicate = self.Node(identity=self.generation + (1, 1), description='TEXT · Editable cell')
        with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
            self.ready(lambda: [grid, duplicate], lambda predicate: predicate(), {})
        record_copy = self.Node(description='Editable cell')
        self.assertIsNone(self.ready(lambda: [record_copy], lambda predicate: predicate(), {}))
        grid.get_attributes = lambda: {'id': 'busydata.result.cell.v99:[]'}
        with self.assertRaisesRegex(RuntimeError, 'Invalid versioned'):
            self.ready(lambda: [grid], lambda predicate: predicate(), {})

    def test_unknown_hints_are_redacted_and_observation_history_remains_bounded(self):
        grid = self.Node(identity=self.generation + (1, 1))
        observed = {}
        def wait(predicate):
            for index in range(30):
                grid.description = ('TEXT · Read-only cell' if index % 2 else
                                    'secret-value-or-private-reason-' + str(index))
                self.assertIsNone(predicate())
            raise TimeoutError('No readiness')
        with self.assertRaises(TimeoutError): self.ready(lambda: [grid], wait, observed)
        self.assertLessEqual(len(observed['history']), 8)
        self.assertTrue(observed['historyLimited'])
        self.assertNotIn('secret-value', json.dumps(observed))
        hint = native_cell_editability_hint('private reason', 'Editable cell', 'Read-only cell')
        self.assertEqual('unknown', hint['state'])
        self.assertEqual(64, len(hint['descriptionSha256']))
        self.assertNotIn('private reason', json.dumps(hint))
        for malformed in (42, '😀' * 1025):
            with self.subTest(value_type=type(malformed).__name__), self.assertRaises(RuntimeError):
                native_cell_editability_hint(malformed, 'Editable cell', 'Read-only cell')

    def test_actual_localized_hint_is_required_without_substring_guessing(self):
        for editable, readonly in (('Editable cell', 'Read-only cell'),
                                   ('خلية قابلة للتحرير', 'خلية للقراءة فقط')):
            self.assertEqual('editable', native_cell_editability_hint('TEXT · ' + editable, editable, readonly)['state'])
            self.assertEqual('read-only', native_cell_editability_hint('TEXT · ' + readonly, editable, readonly)['state'])
            self.assertEqual('unknown', native_cell_editability_hint('not ' + editable, editable, readonly)['state'])


if __name__ == '__main__':
    unittest.main()
