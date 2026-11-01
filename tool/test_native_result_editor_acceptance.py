import copy
import types
import hashlib
import unittest
from unittest.mock import patch
from native_workbench_acceptance import set_native_inline_text, captured_native_modal_field, NativeSnapshotIncomplete
from native_result_editor_acceptance import exact_native_status_line, has_exact_native_line, native_complete_value_matches, NativeValueModalOwner, validate, native_modal_source_restored, close_native_source_modal, find_native_authored_modal, native_authored_modal_role
from native_result_editor_acceptance import native_fixture_row_positions, native_value_editor_identity


VALUE_INSTANCE = 'busydata.value.editor.v1.63cd655a-5b9f-412b-bd22-98e29b0910b9'
OTHER_INSTANCE = 'busydata.value.editor.v1.f98d688f-1766-48ee-80f5-eae78584e0de'


def value_node(identifier='', role='entry', title='', pid=17):
    return types.SimpleNamespace(get_attributes=lambda: {'id': identifier},
        get_process_id=lambda: pid, get_role=lambda: role, get_name=lambda: title)


def capture_value_owner(state, owner='source'):
    def nodes(): return [state['modal'], state['body'], state['current']] + state.get('extra', [])
    def ancestors(item):
        if item is state['body']: return [state['modal']]
        if item is state['current']: return [state['body'], state['modal']]
        return []
    return NativeValueModalOwner.capture(owner, state['modal'],
        lambda: state['owner'], ancestors, nodes)


class NativeFixtureRowIdentityTest(unittest.TestCase):
    @staticmethod
    def generation(order=('1', '2')):
        values = {'1': '漢😀', '2': 'second'}
        return {'cells': tuple((object(), f'Row {row + 1}, {column}: {value}', (row, index))
            for row, key in enumerate(order)
            for index, (column, value) in enumerate((('id', key), ('n', values[key]))))}

    def test_keys_and_values_bind_to_source_positions_in_both_server_orders(self):
        for order, expected in [(('1', '2'), {'1': 1, '2': 2}),
                                (('2', '1'), {'1': 2, '2': 1})]:
            with self.subTest(order=order):
                generation = self.generation(order)
                self.assertEqual(expected, native_fixture_row_positions(generation))
                generation['cells'] = tuple(reversed(generation['cells']))
                self.assertEqual(expected, native_fixture_row_positions(generation))

    def test_incomplete_snapshots_cannot_acknowledge_a_refreshed_source(self):
        generation = self.generation(('2', '1'))
        for index in range(4):
            with self.subTest(missing=index):
                self.assertIsNone(native_fixture_row_positions({
                    'cells': generation['cells'][:index] + generation['cells'][index + 1:]}))

    def test_wrong_retained_value_cannot_be_accepted_by_key_alone(self):
        generation = self.generation(('2', '1'))
        node, _, coordinate = generation['cells'][-1]
        generation['cells'] = generation['cells'][:-1] + ((node, 'Row 2, n: obsolete draft', coordinate),)
        self.assertIsNone(native_fixture_row_positions(generation))

    def test_caption_row_cannot_substitute_for_a_different_source_coordinate(self):
        generation = self.generation(('2', '1'))
        generation['cells'] = tuple((node, caption, (1 - row, column))
            for node, caption, (row, column) in generation['cells'])
        self.assertIsNone(native_fixture_row_positions(generation))

    def test_duplicate_fixture_keys_are_ambiguous(self):
        with self.assertRaises(RuntimeError):
            native_fixture_row_positions(self.generation(('1', '1')))

    def test_duplicate_or_invalid_coordinates_are_rejected(self):
        generation = self.generation()
        for coordinate in ((0, 0), (True, 1), (-1, 1), (2, 1), (1, 2)):
            node, caption, _ = generation['cells'][-1]
            altered = {'cells': generation['cells'][:-1] + ((node, caption, coordinate),)}
            with self.subTest(coordinate=coordinate), self.assertRaises(RuntimeError):
                native_fixture_row_positions(altered)

    def test_unexpected_fixture_rows_are_not_silently_ignored(self):
        generation = self.generation()
        generation['cells'] += ((object(), 'Row 3, id: 3', (2, 0)),)
        with self.assertRaises(RuntimeError): native_fixture_row_positions(generation)


class NativeResultEditorEvidenceTest(unittest.TestCase):
    def test_retained_filter_stale_focus_reacquires_current_field_before_one_text_edit(self):
        modal = value_node(role='panel')
        state = {'focusRequests': [], 'textRequests': []}
        def field():
            node = value_node()
            node.text, node.focused = '', False
            node.clear_cache = lambda: None
            node.get_interfaces = lambda: ['Text', 'EditableText', 'Component']
            node.get_state_set = lambda: types.SimpleNamespace(contains=lambda flag:
                node.focused if flag == 'focused' else flag != 'readonly')
            return node
        stale, current, acknowledged = field(), field(), field()
        state['field'] = stale
        def nodes(): return [modal, state['field']]
        def acquire():
            return captured_native_modal_field(modal, 17,
                lambda: state['field'], nodes)
        def request(_, node):
            state['focusRequests'].append(node)
            if node is stale:
                state['field'] = current # queued focus was rejected as stale
            else:
                node.focused = True
            return True # dispatch alone is not the focus acknowledgement
        def edit(node, text):
            state['textRequests'].append((node, text))
            acknowledged.text, acknowledged.focused = text, True
            state['field'] = acknowledged
            return True
        def wait(predicate):
            for _ in range(8):
                value = predicate()
                if value: return value
            raise TimeoutError('Current native field did not acknowledge')
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry'),
            StateType=types.SimpleNamespace(VISIBLE='visible', SHOWING='showing',
                FOCUSED='focused', SENSITIVE='sensitive', EDITABLE='editable', READ_ONLY='readonly'),
            CoordType=types.SimpleNamespace(WINDOW='window'),
            Component=types.SimpleNamespace(get_extents=lambda *_: types.SimpleNamespace(x=0,y=0,width=100,height=30)),
            Text=types.SimpleNamespace(get_character_count=lambda node:len(node.text),
                get_caret_offset=lambda node:len(node.text),
                get_text=lambda node,start,end:node.text[start:] if end==-1 else node.text[start:end]),
            EditableText=types.SimpleNamespace(set_text_contents=edit))
        with patch('native_workbench_acceptance.accessible_ancestors', return_value=[modal]), patch(
                'native_workbench_acceptance.request_native_focus', side_effect=request):
            self.assertIs(acknowledged, set_native_inline_text(atspi, acquire, '2', wait, expected_original=''))
        self.assertEqual(state['focusRequests'], [stale, current])
        self.assertEqual(state['textRequests'], [(current, '2')])
        self.assertEqual(stale.text, '')

    def test_captured_filter_modal_reacquires_fields_without_accepting_another_dialog(self):
        modal, foreign = value_node(role='panel'), value_node(role='panel')
        first, second = value_node(), value_node()
        state = {'field': first, 'modal': modal}
        def nodes(): return [state['modal'], state['field']]
        def parents(_): return [state['modal']]
        def current():
            return captured_native_modal_field(modal, 17,
                lambda: state['field'], nodes)
        with patch('native_workbench_acceptance.accessible_ancestors', side_effect=parents):
            self.assertIs(current(), first)
            state['field'] = second
            self.assertIs(current(), second)
            state['modal'] = foreign
            with self.assertRaisesRegex(RuntimeError, 'modal retired'): current()

    def test_captured_filter_modal_requires_the_same_process_and_ancestry(self):
        for change in ('field-process', 'modal-process', 'ancestry'):
            modal = value_node(role='panel', pid=18 if change == 'modal-process' else 17)
            field = value_node(pid=18 if change == 'field-process' else 17)
            with self.subTest(change=change), patch(
                    'native_workbench_acceptance.accessible_ancestors',
                    return_value=[] if change == 'ancestry' else [modal]), self.assertRaises(RuntimeError):
                captured_native_modal_field(modal, 17, lambda: field, lambda: [modal, field])

    def test_incomplete_filter_field_reads_are_pending_without_authorizing_text_input(self):
        modal, field = value_node(), value_node()
        def incomplete(): raise NativeSnapshotIncomplete('missing edge')
        self.assertIsNone(captured_native_modal_field(modal, 17, lambda: field, incomplete))
        self.assertIsNone(captured_native_modal_field(modal, 17, lambda: field, lambda: [modal]))
        self.assertIsNone(captured_native_modal_field(modal, 17, lambda: None, lambda: [modal]))
        for pid in (True, 0, -1, 2 ** 31):
            with self.subTest(pid=pid), self.assertRaises(ValueError):
                captured_native_modal_field(modal, pid, lambda: field, lambda: [modal, field])

    def value_edit_fixture(self):
        modal = value_node(role='dialog', title='n · text')
        replacement_body = value_node(OTHER_INSTANCE, role='panel')
        state = {'owner': 'source', 'modal': modal, 'body': value_node(VALUE_INSTANCE),
                 'dispatches': [], 'reads': []}
        def node(text):
            result = value_node()
            result.text, result.clear_cache = text, lambda: None
            result.get_interfaces = lambda: ['Text', 'EditableText']
            result.get_state_set = lambda: types.SimpleNamespace(contains=lambda name: name != 'readonly')
            return result
        held, live, acknowledged = node('obsolete handle'), node('second'), node('second')
        state['current'] = live
        scope = capture_value_owner(state)
        def current(): return scope.field(state['current'])
        def read(item, start, end):
            state['reads'].append((item, start, end))
            return item.text if end == -1 else item.text[start:end]
        def dispatch(item, value):
            state['dispatches'].append((item, value))
            acknowledged.text = value
            state['current'] = acknowledged
            return True
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(ENTRY='entry'),
            StateType=types.SimpleNamespace(FOCUSED='focused', SHOWING='showing',
                SENSITIVE='sensitive', EDITABLE='editable', READ_ONLY='readonly'),
            Text=types.SimpleNamespace(get_text=read, get_character_count=lambda item: len(item.text)),
            EditableText=types.SimpleNamespace(set_text_contents=dispatch))
        def wait(predicate):
            for _ in range(4):
                value = predicate()
                if value: return value
            raise TimeoutError('Current value was not acknowledged')
        return state, atspi, current, wait, held, live, acknowledged, replacement_body

    def test_value_edit_reacquires_modal_field_and_acknowledges_current_exact_unicode(self):
        state, atspi, current, wait, held, live, acknowledged, _ = self.value_edit_fixture()
        with patch('native_workbench_acceptance.focus_visible_native_field',
                side_effect=lambda _, current_item, __: current_item()):
            result = set_native_inline_text(atspi, current, 'draft 漢😀', wait,
                expected_original='second')
        self.assertIs(acknowledged, result)
        self.assertEqual([(live, 'draft 漢😀')], state['dispatches'])
        self.assertEqual([(live, 0, 6), (acknowledged, 0, -1)], state['reads'])
        self.assertEqual('obsolete handle', held.text)

    def test_changed_original_rejects_before_dispatch_without_reading_oversized_content(self):
        for original in ('altered', 'wrong!', 'x' * 65537):
            with self.subTest(units=len(original)):
                state, atspi, current, wait, _, live, _, _ = self.value_edit_fixture()
                live.text = original
                with patch('native_workbench_acceptance.focus_visible_native_field',
                        side_effect=lambda _, current_item, __: current_item()), self.assertRaises(RuntimeError):
                    set_native_inline_text(atspi, current, 'draft', wait, expected_original='second')
                self.assertEqual([], state['dispatches'])
                self.assertEqual(1 if len(original) == 6 else 0, len(state['reads']))

    def test_original_verification_bound_rejects_invalid_expected_values_before_text_read(self):
        for original in (True, 1, b'second', 'x' * 65537):
            state, atspi, current, wait, _, _, _, _ = self.value_edit_fixture()
            with patch('native_workbench_acceptance.focus_visible_native_field',
                    side_effect=lambda _, current_item, __: current_item()), self.assertRaises(ValueError):
                set_native_inline_text(atspi, current, 'draft', wait, expected_original=original)
            self.assertEqual([], state['dispatches'])
            self.assertEqual([], state['reads'])

    def test_foreign_source_or_replaced_editor_during_focus_cannot_receive_value_edit(self):
        for change in ('owner', 'body'):
            state, atspi, current, wait, _, _, _, other_modal = self.value_edit_fixture()
            def focus(_, current_item, __):
                state[change] = 'foreign' if change == 'owner' else other_modal
                return current_item()
            with patch('native_workbench_acceptance.focus_visible_native_field', side_effect=focus), self.assertRaises(RuntimeError):
                set_native_inline_text(atspi, current, 'draft', wait, expected_original='second')
            self.assertEqual([], state['dispatches'])

    def test_owner_loss_after_one_dispatch_prevents_acknowledgement_and_stage_without_retry(self):
        state, atspi, current, wait, _, live, _, _ = self.value_edit_fixture()
        def dispatch(item, value):
            state['dispatches'].append((item, value))
            state['owner'] = 'foreign'
            return True
        atspi.EditableText.set_text_contents = dispatch
        staged = []
        with patch('native_workbench_acceptance.focus_visible_native_field',
                side_effect=lambda _, current_item, __: current_item()), self.assertRaises(RuntimeError):
            set_native_inline_text(atspi, current, 'draft', wait, expected_original='second')
            staged.append(True)
        self.assertEqual([(live, 'draft')], state['dispatches'])
        self.assertEqual([], staged)

    def test_complete_native_field_waits_for_exact_bounded_current_content(self):
        text = ['漢' * 16384]
        reads = []
        field = object()
        atspi = types.SimpleNamespace(Text=types.SimpleNamespace(
            get_character_count=lambda item: len(text[0]),
            get_text=lambda item, start, end: reads.append((start, end)) or text[0][start:end]))
        observed = {}
        self.assertFalse(native_complete_value_matches(atspi, lambda: field, '漢' * 30000, observed))
        self.assertEqual(observed, {'characterCount': 16384})
        self.assertEqual(reads, [])
        text[0] = '漢' * 30000
        self.assertTrue(native_complete_value_matches(atspi, lambda: field, text[0], observed))
        self.assertEqual(reads, [(0, 30000)])
        self.assertEqual(observed['returnedCharacters'], 30000)
        text[0] = 'x' * 30000
        self.assertFalse(native_complete_value_matches(atspi, lambda: field, '漢' * 30000, observed))
        with self.assertRaises(ValueError):
            native_complete_value_matches(atspi, lambda: field, 'x' * 65537, observed)

    def test_modal_owner_follows_only_same_instance_across_native_handle_recreation(self):
        field = value_node()
        state = {'owner': 'related-owner', 'modal': value_node(role='dialog', title='body · text'),
                 'body': value_node(VALUE_INSTANCE), 'current': field}
        scope = capture_value_owner(state, 'related-owner')
        self.assertIs(scope.field(field), field)
        state['owner'] = None
        self.assertIs(scope.field(field), field)
        self.assertIsNone(scope.field(None))
        state['modal'] = value_node(role='dialog', title='body · text')
        state['body'] = value_node(VALUE_INSTANCE)
        self.assertIs(scope.field(field), field)
        state['body'] = value_node(OTHER_INSTANCE)
        with self.assertRaises(RuntimeError): scope.field(field)
        state['body'] = value_node(VALUE_INSTANCE)
        state['owner'] = 'foreign-owner'
        with self.assertRaises(RuntimeError): scope.field(field)
        with self.assertRaises(ValueError): capture_value_owner(state, '')

    def test_value_instance_rejects_foreign_process_wrong_title_role_and_duplicate_identity(self):
        for change in ('body-pid', 'field-pid', 'modal-pid', 'title', 'role', 'duplicate'):
            state = {'owner': 'source', 'modal': value_node(role='dialog', title='body · text'),
                     'body': value_node(VALUE_INSTANCE), 'current': value_node()}
            scope = capture_value_owner(state)
            if change == 'body-pid': state['body'] = value_node(VALUE_INSTANCE, pid=18)
            elif change == 'field-pid': state['current'] = value_node(pid=18)
            elif change == 'modal-pid': state['modal'] = value_node(role='dialog', title='body · text', pid=18)
            elif change == 'title': state['modal'] = value_node(role='dialog', title='other · text')
            elif change == 'role': state['modal'] = value_node(role='panel', title='body · text')
            else: state['extra'] = [value_node(VALUE_INSTANCE)]
            with self.subTest(change=change), self.assertRaises(RuntimeError): scope.field(state['current'])

    def test_value_instance_missing_snapshot_stays_pending_without_accepting_same_title(self):
        from native_workbench_acceptance import NativeSnapshotIncomplete
        field = value_node()
        state = {'owner': 'source', 'modal': value_node(role='dialog', title='body · text'),
                 'body': value_node(VALUE_INSTANCE), 'current': field}
        scope = capture_value_owner(state)
        def incomplete(): raise NativeSnapshotIncomplete('missing child')
        scope.current_nodes = incomplete
        self.assertIsNone(scope.field(field))
        scope.current_nodes = lambda: []
        self.assertIsNone(scope.field(field))
        self.assertIsNone(NativeValueModalOwner.capture('source', None, lambda: None,
            lambda _: [], lambda: []))

    def test_value_instance_rejects_malformed_ids_or_process_before_use(self):
        for identifier in ('busydata.value.editor.v1.caption', 'busydata.value.editor.v2.' + VALUE_INSTANCE[-36:],
                           VALUE_INSTANCE.upper().replace('BUSYDATA.VALUE.EDITOR.', 'busydata.value.editor.'),
                           'busydata.value.editor.v1.' + '0' * 36):
            with self.subTest(identifier=identifier), self.assertRaises(RuntimeError):
                native_value_editor_identity(value_node(identifier))
        for pid in (True, 0, -1, 2 ** 31):
            with self.subTest(pid=pid), self.assertRaises(RuntimeError):
                native_value_editor_identity(value_node(VALUE_INSTANCE, pid=pid))
        self.assertIsNone(native_value_editor_identity(value_node('unrelated')))

    def test_modal_dismissal_waits_for_complete_retirement_and_exact_source_owner(self):
        modal = object()
        self.assertIsNone(native_modal_source_restored([modal], modal, 'source', lambda: 'source', lambda: [modal]))
        self.assertIsNone(native_modal_source_restored([], modal, 'source', lambda: None, lambda: []))
        self.assertTrue(native_modal_source_restored([], modal, 'source', lambda: 'source', lambda: []))
        for nodes in ([modal], []):
            with self.subTest(modal_present=bool(nodes)), self.assertRaisesRegex(RuntimeError, 'another'):
                native_modal_source_restored(nodes, modal, 'source', lambda: 'foreign', lambda: nodes)
        failure = RuntimeError('Modal node retired during observation')
        failure.domain, failure.code = 'atspi_error', 1
        class Retired:
            def __eq__(self, _): raise failure
        retired = Retired()
        self.assertIsNone(native_modal_source_restored([retired], modal, 'source', lambda: 'source', lambda: []))
        with self.assertRaises(RuntimeError) as raised:
            native_modal_source_restored([retired], modal, 'source', lambda: 'source', lambda: [retired])
        self.assertIs(failure, raised.exception)

    def test_single_close_captures_exact_localized_modal_and_only_observes_after_dispatch(self):
        for title, role in ((title, role) for title in
                ('Metadata and introspection', 'Aggregatansicht', 'إدراج صف')
                for role in ('panel', 'dialog')):
            with self.subTest(title=title, role=role):
                state = {'closed': 0, 'polls': 0, 'phase': 0}
                modal = types.SimpleNamespace(get_role=lambda: role, get_name=lambda: title,
                    get_state_set=lambda: types.SimpleNamespace(contains=lambda _: True))
                header = types.SimpleNamespace(get_role=lambda: 'heading', get_name=lambda: title)
                atspi = types.SimpleNamespace(Role=types.SimpleNamespace(PANEL='panel', DIALOG='dialog'),
                    StateType=types.SimpleNamespace(SHOWING='showing'))
                def nodes(): return [modal, header] if state['phase'] < 2 else [header]
                def selected(): return 'source' if state['phase'] >= 3 else None
                def wait(predicate):
                    for _ in range(5):
                        result = predicate()
                        if result: return result
                        state['phase'] += 1
                        state['polls'] += 1
                    raise TimeoutError('Owned modal did not retire')
                def close(): state['closed'] += 1
                self.assertTrue(close_native_source_modal(atspi, nodes, wait,
                    'source', selected, title, close, modal_role=role))
                self.assertEqual(1, state['closed'])
                self.assertEqual(3, state['polls'])

    def test_modal_close_fails_foreign_owner_ambiguity_or_getter_error_without_retry(self):
        for failure, role in ((failure, role) for failure in
                ('foreign', 'ambiguous', 'live-error') for role in ('panel', 'dialog')):
            with self.subTest(failure=failure, role=role):
                closed = []
                modal = types.SimpleNamespace(get_role=lambda: role, get_name=lambda: 'Exact modal',
                    get_state_set=lambda: types.SimpleNamespace(contains=lambda _: True))
                atspi = types.SimpleNamespace(Role=types.SimpleNamespace(PANEL='panel', DIALOG='dialog'),
                    StateType=types.SimpleNamespace(SHOWING='showing'))
                def failed_name(): raise ValueError('Live native getter failed')
                if failure == 'live-error': modal.get_name = failed_name
                def nodes(): return ([modal, modal] if failure == 'ambiguous' else [modal]) if not closed else []
                def wait(predicate):
                    for _ in range(3):
                        result = predicate()
                        if result: return result
                    raise TimeoutError('No acknowledgement')
                with self.assertRaises((RuntimeError, ValueError)):
                    close_native_source_modal(atspi, nodes, wait, 'source',
                        lambda: 'foreign' if closed else None, 'Exact modal', lambda: closed.append(True), modal_role=role)
                self.assertEqual(1 if failure == 'foreign' else 0, len(closed))

    def test_authored_modal_capture_requires_the_declared_role_exact_title_and_visibility(self):
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(PANEL='panel', DIALOG='dialog'),
            StateType=types.SimpleNamespace(SHOWING='showing'))
        def node(role, title='body · text', showing=True):
            return types.SimpleNamespace(get_role=lambda: role, get_name=lambda: title,
                get_state_set=lambda: types.SimpleNamespace(contains=lambda _: showing))
        for role, other in [('panel', 'dialog'), ('dialog', 'panel')]:
            with self.subTest(role=role):
                modal = node(role)
                # A heading or the other platform's role cannot substitute for
                # the exact authored scope, even when its caption is identical.
                candidates = [node('heading'), node(other), node(role, 'Other value'),
                              node(role, showing=False), modal]
                self.assertIs(modal, find_native_authored_modal(atspi,
                    lambda: candidates, 'body · text', role))
                self.assertIsNone(find_native_authored_modal(atspi,
                    lambda: candidates[:-1], 'body · text', role))
                with self.assertRaisesRegex(RuntimeError, 'Ambiguous'):
                    find_native_authored_modal(atspi,
                        lambda: [modal, node(role)], 'body · text', role)
        with self.assertRaises(ValueError):
            find_native_authored_modal(atspi, lambda: self.fail('Invalid role read the tree'),
                'body · text', 'heading')

    def test_authored_modal_role_requires_verified_fluent_or_ordinary_linux(self):
        atspi = types.SimpleNamespace(Role=types.SimpleNamespace(PANEL='panel', DIALOG='dialog'))
        fluent = {'entrypoint': 'integration_test/fluent_composition_linux.dart',
            'composition': 'Linux-host Fluent', 'hostPlatform': 'linux',
            'releaseMode': True, 'actualWindowsWorkspaceShell': True,
            'actualFluentTheme': True, 'actualPinnedBackend': True,
            'windowsNativeAcceptance': False, 'workspaceRenderBox': {'width': 1280, 'height': 800},
            'textScale': 1, 'direction': 'ltr'}
        self.assertEqual('panel', native_authored_modal_role(atspi, {}))
        self.assertEqual('panel', native_authored_modal_role(atspi, {'actualComposedSettings': {}}))
        self.assertEqual('dialog', native_authored_modal_role(atspi, {'actualComposition': fluent}))
        for invalid in (None, [], {}, dict(fluent, composition='Unknown'),
                        dict(fluent, actualWindowsWorkspaceShell=False),
                        dict(fluent, releaseMode=False)):
            with self.subTest(invalid=invalid), self.assertRaises(RuntimeError):
                native_authored_modal_role(atspi, {'actualComposition': invalid})

    def test_informational_native_lines_remain_exact_and_bounded(self):
        self.assertTrue(has_exact_native_line('id\nSum: 1\nAverage: 1', 'Sum: 1'))
        self.assertTrue(has_exact_native_line(
            'Selected cells only\nOriginal values', 'Selected cells only'))
        self.assertTrue(has_exact_native_line(
            'Truncated preview\nBytes 0–65536 of 90000', 'Bytes 0–65536 of 90000'))
        self.assertFalse(has_exact_native_line(
            'Truncated preview\nBytes 0–90000 of 90000', 'Bytes 0–65536 of 90000'))
        self.assertTrue(has_exact_native_line(
            'Source\nRecord View · Row 1\nNavigation', 'Record View · Row 1'))
        self.assertFalse(has_exact_native_line(
            'Source\nRecord View · Row 2', 'Record View · Row 1'))
        for invalid in ('Sum: 10', 'Staged Sum: 1', 'x' * 4097 + '\nSum: 1'):
            with self.subTest(invalid=invalid[:80]):
                self.assertFalse(has_exact_native_line(invalid, 'Sum: 1'))

    def test_cache_status_accepts_one_complete_merged_native_line(self):
        line = 'Cache state: PARTIAL_OR_STALE · 1 / 9'
        self.assertEqual(exact_native_status_line(line, 'Cache state'), line)
        self.assertEqual(exact_native_status_line(
            'Source\nCache state\n' + line + '\nScope detail', 'Cache state'), line)
        self.assertEqual(exact_native_status_line(
            'Quelle\nCachezustand: AVAILABLE · 1 / 10', 'Cachezustand'),
            'Cachezustand: AVAILABLE · 1 / 10')
        for invalid in ('not ' + line, line + '\n' + line, 'x' * 4097):
            with self.subTest(invalid=invalid[:80]):
                self.assertIsNone(exact_native_status_line(invalid, 'Cache state'))

    @staticmethod
    def complete():
        value = {key: True for key in (
            'passed', 'centralMetadataFullRefreshAndNewRetainedSource',
            'transposeExactSelectionAndKeyboard', 'treeKeyboardExpansionAndExactValue',
            'textExactSelectionAndExplicitScope', 'recordNavigationAndTypedValueEditorStaging',
            'explicitDiscardPreservesOriginal', 'exactNumericAggregateAndScope',
            'cloneVisibleStagedOnlyAndExplicitDiscard', 'relatedRowsReviewedNormalDocument',
            'customTemporalDisplayPreservesExactCopy', 'sourceOwnerSelectionAndReaderRestored')}
        value.update(databaseMutationSubmitted=False, sourceOwner='table-owner',
            metadataRefreshSourceProof={'document': 'table-owner', 'owner': 'document-owner',
                'previousSource': 'retained-before', 'source': 'retained-after',
                'display': 'retained-after', 'keyedRows': {'1': 1, '2': 2}},
            relatedOwner='related-table-owner', completeValueOwnerBeforeModal='related-table-owner',
            completeValueOwnerAfterModal='related-table-owner', readerOffsets={
                'transpose': [0, 10], 'valueEditor': [10, 20], 'restoredSource': [20, 30]},
            chunkedAndCompleteValueExactStagingAndDiscard={
                'retainedUtf8Bytes': 90000, 'textUnits': 30000,
                'explicitAcquisition': True, 'appliedDatabaseMutation': False},
            independentDurableRowsUnchanged={'parentRows': 2, 'childRows': 1,
                'childTextUtf8Bytes': 90000, 'snapshotSha256': 'a' * 64})
        def readback(text):
            return {'characterCount': len(text), 'returnedCharacters': len(text),
                    'utf8Sha256': hashlib.sha256(text.encode()).hexdigest()}
        value['completeValueNativeReadbacks'] = [
            dict(readback('漢' * count), page=index + 1, owner='related-table-owner')
            for index, count in enumerate((16384, 13616))]
        value['completeValueNativeEditedLastPage'] = readback('漢' * 13615 + '末')
        return value

    def test_every_workflow_requires_its_own_native_receipt(self):
        expected = self.complete()
        self.assertIs(validate(expected), expected)
        for key, value in expected.items():
            if value is not True:
                continue
            altered = copy.deepcopy(expected)
            del altered[key]
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate(altered)

    def test_metadata_refresh_requires_fresh_bounded_source_and_captured_document(self):
        for replacement in (None, {}, {'document': 'another-table'}):
            altered = self.complete()
            altered['metadataRefreshSourceProof'] = replacement
            with self.subTest(replacement=replacement), self.assertRaises(RuntimeError):
                validate(altered)
        for key in ('owner', 'previousSource', 'source', 'display'):
            for invalid in ('', None, 'x' * 129, 'source\nstale'):
                altered = self.complete()
                altered['metadataRefreshSourceProof'][key] = invalid
                with self.subTest(key=key, invalid=invalid), self.assertRaises(RuntimeError):
                    validate(altered)
        altered = self.complete()
        altered['metadataRefreshSourceProof']['source'] = 'retained-before'
        altered['metadataRefreshSourceProof']['display'] = 'new-local-view'
        with self.assertRaises(RuntimeError): validate(altered)

    def test_refresh_receipt_requires_both_exact_keyed_source_rows(self):
        for positions in ({'1': 1, '2': 2}, {'1': 2, '2': 1}):
            value = self.complete()
            value['metadataRefreshSourceProof']['keyedRows'] = positions
            self.assertIs(value, validate(value))
        for positions in (None, {}, {'1': 1}, {'1': 1, '2': 1},
                          {'1': True, '2': 2}, {'1': 2, '2': 3}, {'1': 1, '2': 2, '3': 3}):
            value = self.complete()
            value['metadataRefreshSourceProof']['keyedRows'] = positions
            with self.subTest(positions=positions), self.assertRaises(RuntimeError): validate(value)

    def test_complete_value_ownership_requires_pre_modal_page_and_post_modal_proof(self):
        for key in ('completeValueOwnerBeforeModal', 'completeValueOwnerAfterModal'):
            value = self.complete()
            value[key] = 'another-owner'
            with self.subTest(key=key), self.assertRaises(RuntimeError): validate(value)
        value = self.complete()
        value['completeValueNativeReadbacks'][1]['owner'] = 'another-owner'
        with self.assertRaises(RuntimeError): validate(value)

    def test_generated_browse_and_durable_source_require_distinct_verified_owners(self):
        for owner in ('', 'table-owner', None):
            altered = self.complete()
            altered['relatedOwner'] = owner
            with self.subTest(owner=owner), self.assertRaises(RuntimeError):
                validate(altered)
        for key in ('parentRows', 'childRows', 'childTextUtf8Bytes', 'snapshotSha256'):
            altered = self.complete()
            del altered['independentDurableRowsUnchanged'][key]
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate(altered)

    def test_historical_reader_output_or_unbounded_value_cannot_certify_this_action(self):
        for interval in ([30, 30], [30, 20], [-1, 30], [0, 4 * 1024 * 1024 + 1], [True, 30]):
            altered = self.complete()
            altered['readerOffsets']['transpose'] = interval
            with self.subTest(interval=interval), self.assertRaises(RuntimeError):
                validate(altered)
        altered = self.complete()
        altered['chunkedAndCompleteValueExactStagingAndDiscard']['retainedUtf8Bytes'] = 0
        with self.assertRaises(RuntimeError):
            validate(altered)
        for key in ('completeValueNativeReadbacks', 'completeValueNativeEditedLastPage'):
            altered = self.complete()
            del altered[key]
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                validate(altered)
        altered = self.complete()
        altered['completeValueNativeReadbacks'][1]['utf8Sha256'] = '0' * 64
        with self.assertRaises(RuntimeError):
            validate(altered)
