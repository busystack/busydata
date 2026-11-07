"""Actual P0 result-editor actions on the ordinary disposable table document.

Only native controls and the existing command palette are used. A verified fixture
owner is reacquired before every source operation; generated navigation is reviewed.
No model injection, direct RPC, SQL synthesis, or database mutation is performed.
"""


def native_fixture_row_positions(generation):
    """Bind both fixture keys and values to the refreshed source coordinates.

    A table browse without an explicit sort has no promised database row order.
    Labels and retained coordinates must agree before any editor action follows.
    """
    cells = generation['cells']
    if len(cells) > 4:
        raise RuntimeError('Unexpected native P0 fixture cell count')
    observed = set()
    coordinates = set()
    for _, caption, coordinate in cells:
        if (not isinstance(coordinate, tuple) or len(coordinate) != 2 or
                any(type(value) is not int or value not in (0, 1) for value in coordinate)
                or coordinate in coordinates):
            raise RuntimeError('Invalid native P0 fixture source coordinate')
        coordinates.add(coordinate)
        observed.add((caption.splitlines()[0], *coordinate))
    positions = {}
    for key, value in (('1', '漢😀'), ('2', 'second')):
        matches = [row + 1 for row in (0, 1) if {
            (f'Row {row + 1}, id: {key}', row, 0),
            (f'Row {row + 1}, n: {value}', row, 1)} <= observed]
        if len(matches) > 1:
            raise RuntimeError('Ambiguous native P0 fixture key')
        if not matches:
            return None
        positions[key] = matches[0]
    if set(positions.values()) != {1, 2}:
        raise RuntimeError('Native P0 fixture keys share a source row')
    return positions


def exact_native_status_line(text, label, limit=4096):
    """Read one complete status from a bounded, possibly merged GTK label."""
    if not isinstance(text, str) or len(text) > limit:
        return None
    matches = [line for line in text.splitlines() if line.startswith(label + ': ')]
    return matches[0] if len(matches) == 1 else None


def has_exact_native_line(text, label, limit=4096):
    """Read informational text without requiring GTK to split sibling labels."""
    return isinstance(text, str) and len(text) <= limit and label in text.splitlines()


def native_complete_value_matches(Atspi, current_field, expected, observation,
                                  current_nodes=None):
    """Read a freshly acquired field after its strict modal-owner validation.

    Only count/text getters may wait for proved retirement; current_field's
    captured-owner and ancestor checks always propagate their failures.
    """
    import hashlib
    if len(expected) > 65536:
        raise ValueError('Native complete-value readback bound')
    field = current_field()
    if field is None:
        return False
    def read_value(node):
        count = Atspi.Text.get_character_count(node)
        return count, Atspi.Text.get_text(node, 0, count) if count == len(expected) else None
    if current_nodes is None:
        count, actual = read_value(field)
    else:
        from native_workbench_acceptance import read_live_native_controls
        values = read_live_native_controls([field], read_value, current_nodes)
        if values is None:
            return None
        count, actual = values[0]
    observation['characterCount'] = count
    if count != len(expected):
        return False
    observation['returnedCharacters'] = len(actual)
    observation['utf8Sha256'] = hashlib.sha256(actual.encode()).hexdigest()
    return actual == expected



def native_modal_source_restored(nodes, modal, source_owner, selected_owner, current_nodes):
    """Dismissal is acknowledged only by complete retirement and the same owner."""
    from native_workbench_acceptance import native_observe_none
    selected = selected_owner()
    if selected is not None and selected != source_owner:
        raise RuntimeError('Native modal returned to another result-editor source owner')
    absent = native_observe_none(nodes, lambda node: node == modal, current_nodes)
    return True if absent is True and selected == source_owner else None


def native_result_source_ready(source_owner, selected_owner):
    """Wait for a complete owner read, but reject an actual different source."""
    selected = selected_owner()
    if selected is None:
        return None
    if selected != source_owner:
        raise RuntimeError('P0 result-editor source owner changed')
    return True


def native_authored_modal_role(Atspi, report):
    """Bind the role to the verified composition, not an observed alternative."""
    if 'actualComposition' not in report:
        return Atspi.Role.PANEL
    from native_fluent_rendering import validate_composition
    composition = report['actualComposition']
    if not isinstance(composition, dict):
        raise RuntimeError('Native authored modal requires a verified composition')
    validate_composition(composition)
    return Atspi.Role.DIALOG


def find_native_authored_modal(Atspi, current_nodes, title, modal_role):
    """Find the platform's declared title-bearing scope, never a role fallback."""
    from native_workbench_acceptance import read_live_native_controls
    if modal_role not in (Atspi.Role.PANEL, Atspi.Role.DIALOG):
        raise ValueError('Unsupported authored native modal role')
    values = read_live_native_controls(current_nodes(), lambda node: node if
        node.get_role() == modal_role and node.get_name() == title and
        node.get_state_set().contains(Atspi.StateType.SHOWING) else None, current_nodes)
    if values is None:
        return None
    matches = [node for node in values if node is not None]
    if len(matches) > 1:
        raise RuntimeError('Ambiguous authored native result-editor modal')
    return matches[0] if matches else None


def close_native_source_modal(Atspi, current_nodes, wait, source_owner, selected_owner,
                               title, close, *, modal_role):
    """Capture one authored modal, dispatch Close once, then only observe."""
    modal = wait(lambda: find_native_authored_modal(Atspi, current_nodes, title, modal_role))
    close()
    return wait(lambda: native_modal_source_restored(current_nodes(), modal,
        source_owner, selected_owner, current_nodes))


def native_cell_editability_hint(description, editable_label, readonly_label):
    """Classify a rendered hint without retaining native type/value/reason text."""
    import hashlib
    if description is None: description = ''
    if not isinstance(description, str):
        raise RuntimeError('Invalid native selected-cell description')
    raw = description.encode('utf-8', errors='strict')
    if len(raw) > 4096:
        raise RuntimeError('Native selected-cell description byte budget')
    for label, state in ((editable_label, 'editable'), (readonly_label, 'read-only')):
        if description == label or description.endswith(' · ' + label):
            return {'state': state, 'classification': 'rendered-cell-hint',
                    'centralReasonAvailable': False}
    return {'state': 'unavailable' if not raw else 'unknown',
            'classification': 'rendered-cell-hint', 'centralReasonAvailable': False,
            'descriptionUtf8Bytes': len(raw), 'descriptionSha256': hashlib.sha256(raw).hexdigest()}


def wait_native_selected_cell_editable(Atspi, current_nodes, wait, *, source_owner,
        selected_owner, generation, row, column, label, native_name,
        editable_label, readonly_label, navigation_ready, observation):
    """Only observe the captured grid cell before the single Inspect dispatch."""
    from native_workbench_acceptance import (NativeSnapshotIncomplete,
        native_result_cell_identity, read_live_native_controls)
    if (not isinstance(generation, tuple) or len(generation) != 3 or
            any(not isinstance(value, str) or not 1 <= len(value) <= 128 for value in generation) or
            type(row) is not int or not 0 <= row < 2 ** 63 or
            type(column) is not int or not 0 <= column < 2048):
        raise ValueError('Captured native editability cell identity is invalid')
    observation.update({'expectedIdentity': list(generation) + [row, column],
                        'editableAcknowledged': False, 'observations': 0,
                        'history': [], 'historyLimited': False})
    def record(state):
        observation['observations'] += 1
        observation['lastObservation'] = state
        history = observation['history']
        if not history or history[-1] != state['state']:
            if len(history) < 8: history.append(state['state'])
            else: observation['historyLimited'] = True
    def owned():
        current = selected_owner()
        if current is not None and current != source_owner:
            raise RuntimeError('Native editability document owner changed')
        return current == source_owner
    def project(node):
        states = node.get_state_set()
        if ('Action' not in node.get_interfaces() or
                not all(states.contains(state) for state in
                        (Atspi.StateType.SHOWING, Atspi.StateType.SELECTED))):
            return None
        attributes = node.get_attributes()
        if not isinstance(attributes, dict):
            raise RuntimeError('Native selected-cell attributes are unavailable')
        identity = native_result_cell_identity(attributes.get('id'))
        if identity is None: return None # Record View's duplicate labels are not grid proof.
        if identity[:3] != generation:
            raise RuntimeError('Native editability result generation changed')
        if identity[3:] != (row, column): return None
        name = native_name(node)
        if not isinstance(name, str) or len(name) > 4096 or name.splitlines()[0:1] != [label]:
            raise RuntimeError('Native editability selected value changed')
        return node, native_cell_editability_hint(node.get_description(), editable_label, readonly_label)
    def observed():
        try:
            if not owned():
                record({'state': 'owner-unavailable'})
                return None
            values = read_live_native_controls(current_nodes(), project, current_nodes)
            if values is None:
                record({'state': 'incomplete'})
                return None
            candidates = [value for value in values if value is not None]
            if len(candidates) > 1:
                raise RuntimeError('Ambiguous native selected editability cell')
            if not candidates:
                record({'state': 'selected-cell-unavailable'})
                return None
            node, hint = candidates[0]
            if not navigation_ready():
                record({'state': 'navigation-pending'})
                return None
            current = current_nodes()
            if node not in current:
                record({'state': 'retired-cell'})
                return None
            verified = read_live_native_controls([node], project, current_nodes)
            if verified is None or verified[0] is None:
                record({'state': 'incomplete'})
                return None
            node, hint = verified[0]
            if not owned():
                record({'state': 'owner-unavailable'})
                return None
            record(hint)
            if hint['state'] != 'editable': return None
            observation['editableAcknowledged'] = True
            return node
        except NativeSnapshotIncomplete:
            record({'state': 'incomplete'})
            return None
    return wait(observed)


def native_value_editor_identity(node):
    """Presentation identity, never a caption, retained value or database key."""
    import re
    attributes = node.get_attributes()
    if not isinstance(attributes, dict):
        raise RuntimeError('Native value editor attributes unavailable')
    identifier = attributes.get('id', '')
    if not isinstance(identifier, str):
        raise RuntimeError('Malformed native value editor identity')
    if not identifier.startswith('busydata.value.editor.'):
        return None
    if not re.fullmatch(r'busydata\.value\.editor\.v1\.[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}', identifier):
        raise RuntimeError('Malformed native value editor identity')
    pid = node.get_process_id()
    if type(pid) is not int or not 0 < pid < 2 ** 31:
        raise RuntimeError('Invalid native value editor process')
    return pid, identifier


class NativeValueModalOwner:
    """Bind one editor State across native handle retirement by popup routes.

    Capture requires the authored modal and its unique instance body. Every
    field read proves the same process, instance, title/role and document owner.
    A same-caption replacement editor can never substitute for this instance.
    """
    def __init__(self, owner, identity, role, title, current_owner, ancestors, current_nodes):
        if not owner or identity is None:
            raise ValueError('Native value modal requires a captured owner')
        self.owner, self.identity, self.role, self.title = owner, identity, role, title
        self.current_owner, self.ancestors, self.current_nodes = current_owner, ancestors, current_nodes

    @classmethod
    def capture(cls, owner, dialog, current_owner, ancestors, current_nodes):
        from native_workbench_acceptance import read_native_snapshot, read_live_native_controls
        if not owner:
            raise ValueError('Native value modal requires a captured owner')
        if dialog is None:
            return None
        selected = current_owner()
        if selected is not None and selected != owner:
            raise RuntimeError('Native value modal document owner changed')
        def read(nodes):
            if dialog not in nodes:
                return None
            def candidate(node):
                identity = native_value_editor_identity(node)
                return identity if identity is not None and dialog in ancestors(node) else None
            values = read_live_native_controls(nodes, candidate, current_nodes)
            if values is None:
                return None
            matches = [value for value in values if value is not None]
            if len(matches) > 1:
                raise RuntimeError('Ambiguous native value editor instance')
            if not matches:
                return None
            def modal(node):
                if node.get_process_id() != matches[0][0]:
                    raise RuntimeError('Native value modal process changed')
                return cls(owner, matches[0], node.get_role(), node.get_name(),
                           current_owner, ancestors, current_nodes)
            captured = read_live_native_controls([dialog], modal, current_nodes)
            return captured[0] if captured is not None else None
        return read_native_snapshot(current_nodes, read)

    def field(self, current):
        from native_workbench_acceptance import read_native_snapshot, read_live_native_controls
        selected = self.current_owner()
        if selected is not None and selected != self.owner:
            raise RuntimeError('Native value modal document owner changed')
        if current is None:
            return None
        def read(nodes):
            if current not in nodes:
                return None
            def project(field):
                if field.get_process_id() != self.identity[0]:
                    raise RuntimeError('Native value field process changed')
                chain = self.ancestors(field)
                bodies = [(index, node, native_value_editor_identity(node))
                          for index, node in enumerate(chain)]
                bodies = [body for body in bodies if body[2] is not None]
                if len(bodies) != 1 or bodies[0][2] != self.identity:
                    raise RuntimeError('Native value field left its captured editor instance')
                index, body, _ = bodies[0]
                modals = [node for node in chain[index + 1:] if
                          node.get_role() == self.role and node.get_name() == self.title and
                          node.get_process_id() == self.identity[0]]
                if len(modals) != 1:
                    raise RuntimeError('Native value field left its authored dialog')
                if body not in nodes or modals[0] not in nodes:
                    return None
                return field
            fields = read_live_native_controls([current], project, self.current_nodes)
            if fields is None or fields[0] is None:
                return None
            identities = read_live_native_controls(nodes, native_value_editor_identity, self.current_nodes)
            if identities is None:
                return None
            if identities.count(self.identity) != 1:
                raise RuntimeError('Ambiguous native value editor instance')
            return fields[0]
        return read_native_snapshot(self.current_nodes, read)


def verify(Atspi, app, objects, wait, command, report, *, palette, activate,
           find, focus, native_name, localized, photograph, source_owner,
           selected_owner, speech_contains, reader_offset, refresh_grid):
    from native_workbench_acceptance import (find_live_activation,
        visible_native_bounds, pointer_at_native_bounds,
        bounded_native_text, accessible_ancestors, native_catalog_text,
        native_observe_any, native_observe_first, read_live_native_controls,
        read_native_snapshot,
        set_native_inline_text)
    import gi
    import hashlib
    import os
    from pathlib import Path
    import subprocess
    import unicodedata
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, Gdk

    evidence = {'passed': False, 'sourceOwner': source_owner, 'readerOffsets': {},
                'databaseMutationSubmitted': False}
    report['nativeP0ResultEditorVerified'] = evidence
    # Both owned controls publish exact title-bearing modal scopes. Fluent
    # declares dialog; ordinary Linux's route-title wrapper remains a panel.
    modal_role = native_authored_modal_role(Atspi, report)

    def durable_snapshot():
        engine = os.environ['BUSYDATA_NATIVE_FIXTURE_ENGINE']
        fixture = os.environ['BUSYDATA_NATIVE_FIXTURE_ID']
        password = (Path(os.environ['BUSYDATA_NATIVE_FIXTURE_DIRECTORY']) / 'password').read_text()
        query = ('SELECT COUNT(*),SUM(id) FROM busydata.native_atspi_fixture;'
                 'SELECT id,n FROM busydata.native_atspi_fixture ORDER BY id;'
                 'SELECT COUNT(*),SUM(parent_id),SUM(OCTET_LENGTH(body)) FROM busydata.native_atspi_child;')
        if engine == 'POSTGRESQL':
            query = query.replace('busydata.', 'public.')
            argv = ['docker', 'exec', '-e', 'PGPASSWORD', fixture, 'psql',
                    '-h', '127.0.0.1', '-U', 'busydata', '-d', 'busydata',
                    '-At', '-F', '\t', '-c', query]
            environment = dict(os.environ, PGPASSWORD=password)
        else:
            argv = ['docker', 'exec', '-e', 'MYSQL_PWD', fixture,
                    'mysql' if engine == 'MYSQL' else 'mariadb', '-h', '127.0.0.1',
                    '-u', 'busydata' if os.environ.get('BUSYDATA_NATIVE_ORDINARY_MYSQL') == '1' else 'root',
                    '--default-character-set=utf8mb4', '--batch', '--raw', '--skip-column-names', '-e', query]
            environment = dict(os.environ, MYSQL_PWD=password)
        value = subprocess.run(argv, env=environment, capture_output=True,
            text=True, check=True, timeout=10).stdout.splitlines()
        if value != ['2\t3', '1\t漢😀', '2\tsecond', '1\t1\t90000']:
            raise RuntimeError('Native P0 durable fixture differs from its exact baseline')
        return hashlib.sha256('\n'.join(value).encode()).hexdigest()

    before_durable = durable_snapshot()

    def owned():
        wait(lambda: native_result_source_ready(source_owner, selected_owner))

    def observed_any(predicate):
        return read_native_snapshot(lambda: objects(app), lambda nodes:
            native_observe_any(nodes, predicate, lambda: objects(app)))

    def observed_first(project):
        return read_native_snapshot(lambda: objects(app), lambda nodes:
            native_observe_first(nodes, project, lambda: objects(app)))

    def observed_values(project):
        return read_native_snapshot(lambda: objects(app), lambda nodes:
            read_live_native_controls(nodes, project, lambda: objects(app)))

    def seen_raw(label):
        return observed_first(lambda node: (
            node.get_state_set().contains(Atspi.StateType.SHOWING) and
            (has_exact_native_line(node.get_name(), label) or
             has_exact_native_line(bounded_native_text(Atspi, node, 4096), label)), node))

    def seen_key(key, **fields):
        return seen_raw(native_catalog_text(key, **fields))

    def cell(row, column, value, selected=False):
        label = f'Row {row}, {column}: {value}'
        return observed_first(lambda node: (
            'Action' in node.get_interfaces() and
            node.get_state_set().contains(Atspi.StateType.SHOWING) and
            (native_name(node) == label or native_name(node).startswith(label + ' · ')
             or native_name(node).startswith(label + '\n')) and
            (not selected or node.get_state_set().contains(Atspi.StateType.SELECTED)), node))

    def click_node(current):
        box = visible_native_bounds(Atspi, current, wait)
        pointer_at_native_bounds(command, box)

    def select(row, column, value):
        owned()
        click_node(lambda: cell(row, column, value))
        wait(lambda: cell(row, column, value, selected=True))

    def source_command(label):
        owned()
        palette(label)

    def close_dialog(title_key):
        close_native_source_modal(Atspi, lambda: objects(app), wait, source_owner,
            selected_owner, native_catalog_text(title_key),
            lambda: activate('Close', message_key='close'), modal_role=modal_role)

    if reader_offset is None:
        raise RuntimeError('Native P0 reader cursor is unavailable')
    source_command('Metadata and introspection')
    wait(lambda: find('Full refresh'))
    activate('Metadata and introspection', message_key='metadataSettings')
    activate('Cache state', message_key='metadataCacheState')
    def cache_caption():
        def caption(node):
            if not node.get_state_set().contains(Atspi.StateType.SHOWING):
                return False, None
            for text, label in ((native_name(node), 'Cache state'),
                    (node.get_name(), localized('Cache state')),
                    (bounded_native_text(Atspi, node, 4096), localized('Cache state'))):
                value = exact_native_status_line(text, label)
                if value is not None:
                    return True, value
            return False, None
        return observed_first(caption)
    previous_metadata = wait(cache_caption)
    activate('Cache state', message_key='metadataCacheState')
    activate('Metadata and introspection', message_key='metadataSettings')
    activate('Full refresh', message_key='metadataFullRefresh')
    activate('Metadata and introspection', message_key='metadataSettings')
    activate('Cache state', message_key='metadataCacheState')
    wait(lambda: (caption := cache_caption()) is not None and caption != previous_metadata)
    close_dialog('metadataSettings')
    from native_workbench_acceptance import (NativeSnapshotIncomplete,
        native_grid_generation, replaced_native_grid_generation)
    def source_generation():
        owned()
        generation = native_grid_generation(Atspi, objects(app), source_owner,
            native_name, current_nodes=lambda: objects(app))
        return generation if generation is not None and generation['completed'] else None
    previous_generation = wait(source_generation, 30)
    refresh_grid()
    def refreshed_source():
        try:
            owned()
            current = replaced_native_grid_generation(Atspi, objects(app),
                previous_generation, native_name, current_nodes=lambda: objects(app))
            return current if current is not None and native_fixture_row_positions(current) is not None else None
        except NativeSnapshotIncomplete:
            return None
    refreshed = wait(refreshed_source, 30)
    # A virtualized native control can survive a refresh. Its current retained
    # source/owner markers, rather than widget retirement, prove the new result.
    evidence['metadataRefreshSourceProof'] = {
        'document': refreshed['document'], 'owner': refreshed['owner'],
        'previousSource': previous_generation['source'],
        'source': refreshed['source'], 'display': refreshed['display'],
        'keyedRows': native_fixture_row_positions(refreshed)}
    primary_row = evidence['metadataRefreshSourceProof']['keyedRows']['1']
    secondary_row = evidence['metadataRefreshSourceProof']['keyedRows']['2']
    editability_generation = tuple(refreshed[key] for key in ('owner', 'source', 'display'))
    evidence['centralMetadataFullRefreshAndNewRetainedSource'] = True
    source_command('Assess editing')
    select(primary_row, 'n', '漢😀')
    source_command('View as · Transpose')
    wait(lambda: cell(primary_row, 'n', '漢😀'))
    transpose_speech = reader_offset()
    click_node(lambda: cell(primary_row, 'n', '漢😀'))
    command(['xdotool', 'key', '--clearmodifiers', 'Up'])
    wait(lambda: cell(primary_row, 'id', '1', selected=True))
    command(['xdotool', 'key', '--clearmodifiers', 'Down'])
    wait(lambda: cell(primary_row, 'n', '漢😀', selected=True))
    wait(lambda: speech_contains([localized(f'Row {primary_row}, n: 漢😀')], after_bytes=transpose_speech))
    evidence['readerOffsets']['transpose'] = [transpose_speech, reader_offset()]
    photograph('p0-transpose-keyboard')
    evidence['transposeExactSelectionAndKeyboard'] = True

    source_command('View as · Tree')
    branch = wait(lambda: observed_first(lambda node: (
        (node.get_name() or '') == '▸ ' + localized('Row') + f' {primary_row}', node)))
    focus(branch)
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait(lambda: find('n: 漢😀'))
    photograph('p0-tree-expanded')
    evidence['treeKeyboardExpansionAndExactValue'] = True

    source_command('View as · Text')
    wait(lambda: seen_key('selectedCellsScope'))
    wait(lambda: observed_any(lambda node: 'Text' in node.get_interfaces() and
        bounded_native_text(Atspi, node, 4096) == '漢😀'))
    photograph('p0-text-explicit-scope')
    evidence['textExactSelectionAndExplicitScope'] = True

    source_command('View as · Table')
    select(primary_row, 'n', '漢😀')
    source_command('Record View')
    wait(lambda: seen_raw(native_catalog_text('recordView') + ' · ' + native_catalog_text('row') + f' {primary_row}'))
    navigate_record = 'Next record' if secondary_row > primary_row else 'Previous record'
    return_record = 'Previous record' if secondary_row > primary_row else 'Next record'
    adjacent_record = wait(lambda: find(navigate_record))
    focus(adjacent_record)
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait(lambda: cell(secondary_row, 'n', 'second'))
    def return_record_ready():
        node = find(return_record)
        if node is None:
            return None
        values = read_live_native_controls([node],
            lambda item: item.get_state_set().contains(Atspi.StateType.SENSITIVE),
            lambda: objects(app))
        return None if values is None else values[0]
    report['stage'] = 'native-record-selected-cell-editability'
    editability_observation = evidence['recordValueEditabilityReadiness'] = {}
    wait_native_selected_cell_editable(Atspi, lambda: objects(app), wait,
        source_owner=source_owner, selected_owner=selected_owner,
        generation=editability_generation, row=secondary_row - 1, column=1,
        label=f'Row {secondary_row}, n: second', native_name=native_name,
        editable_label=native_catalog_text('editableCell'),
        readonly_label=native_catalog_text('readonlyCell'),
        navigation_ready=return_record_ready, observation=editability_observation)
    source_command('Inspect value')
    wait(lambda: observed_any(lambda node:
        node.get_state_set().contains(Atspi.StateType.SHOWING) and
        has_exact_native_line((native_name(node) or '').lower(), 'n · text')))
    wait(lambda: observed_any(lambda node: 'Text' in node.get_interfaces() and
        bounded_native_text(Atspi, node, 4096) == 'second'))
    report['stage'] = 'native-record-value-editor-edit-control'
    value_title = 'n · ' + ('text' if os.environ['BUSYDATA_NATIVE_FIXTURE_ENGINE'] == 'POSTGRESQL' else 'TEXT')
    value_owner = wait(lambda: NativeValueModalOwner.capture(source_owner,
        find_native_authored_modal(Atspi, lambda: objects(app), value_title, modal_role),
        selected_owner, accessible_ancestors, lambda: objects(app)))
    def current_value_field():
        return value_owner.field(find('Exact value', 'EditableText'))
    field = wait(lambda: find('Edit cell'))
    focus(field)
    command(['xdotool', 'key', '--clearmodifiers', 'space'])
    value = wait(current_value_field)
    value_speech = reader_offset()
    focus(value)
    wait(lambda: speech_contains([localized('Exact value')], after_bytes=value_speech))
    evidence['readerOffsets']['valueEditor'] = [value_speech, reader_offset()]
    # Reacquire the same captured modal's field after reader/focus updates.
    # Wait for current focus and reveal before exactly one local edit, then
    # acknowledge its exact content on the current live field before Stage.
    set_native_inline_text(Atspi, current_value_field,
        'P0 native staged draft 漢😀', wait, expected_original='second')
    photograph('p0-record-value-editor')
    activate('Stage change', message_key='stageChange')
    wait(lambda: cell(secondary_row, 'n', 'P0 native staged draft 漢😀'))
    evidence['recordNavigationAndTypedValueEditorStaging'] = True
    source_command('Record View')
    source_command('Discard pending changes')
    wait(lambda: find('Discard pending changes'))
    activate('Discard pending changes', message_key='discardChanges')
    wait(lambda: cell(secondary_row, 'n', 'second'))
    evidence['explicitDiscardPreservesOriginal'] = True

    select(primary_row, 'id', '1')
    source_command('Aggregate View')
    wait(lambda: seen_key('selectedCellsScope'))
    wait(lambda: seen_raw(native_catalog_text('aggregateSelectedCount') + ': 1'))
    wait(lambda: seen_raw(native_catalog_text('aggregateSum') + ': 1'))
    wait(lambda: seen_raw(native_catalog_text('aggregateAverage') + ': 1'))
    photograph('p0-exact-aggregate')
    close_dialog('aggregateView')
    evidence['exactNumericAggregateAndScope'] = True

    select(primary_row, 'n', '漢😀')
    source_command('Clone Row')
    wait(lambda: seen_key('stageInsert'))
    wait(lambda: find('Unchanged / unset'))
    copied = wait(lambda: observed_first(lambda node: (
        (node.get_name() or '').startswith('n · ') and
        'EditableText' in node.get_interfaces() and
        node.get_state_set().contains(Atspi.StateType.SHOWING) and
        node.get_state_set().contains(Atspi.StateType.SENSITIVE), node)))
    if Atspi.Text.get_text(copied, 0, -1) != '漢😀':
        raise RuntimeError('Clone changed the retained source value')
    photograph('p0-clone-staged-insert')
    close_dialog('stageInsert')
    source_command('Discard pending changes')
    wait(lambda: find('Discard pending changes'))
    activate('Discard pending changes', message_key='discardChanges')
    wait(lambda: cell(primary_row, 'n', '漢😀') and cell(secondary_row, 'n', 'second'))
    evidence['cloneVisibleStagedOnlyAndExplicitDiscard'] = True

    select(primary_row, 'id', '1')
    source_command('Related Rows')
    target = wait(lambda: observed_first(lambda node: (
        'native_atspi_child' in (node.get_name() or '') and
           '←' in (node.get_name() or '') and
           'Action' in node.get_interfaces() and
           node.get_state_set().contains(Atspi.StateType.SENSITIVE), node)))
    action = find_live_activation(Atspi, [target], target.get_name())
    if action is None or not Atspi.Action.do_action(action[0], action[1]):
        raise RuntimeError('Native related-row selection rejected')
    wait(lambda: find('Open data'))
    wait(lambda: observed_any(lambda node: 'Text' in node.get_interfaces() and
        'native_atspi_child' in bounded_native_text(Atspi, node, 8192) and
        'parent_id' in bounded_native_text(Atspi, node, 8192)))
    photograph('p0-related-reviewed-browse')
    activate('Open data', message_key='openData')
    wait(lambda: cell(1, 'parent_id', '1'), 30)
    related_owner = selected_owner()
    if related_owner is None or related_owner == source_owner:
        raise RuntimeError('Related rows replaced the source owner')
    evidence['relatedRowsReviewedNormalDocument'] = True
    evidence['relatedOwner'] = related_owner

    def observed_cell():
        return observed_first(lambda node: (
            (native_name(node) or '').startswith('Row 1, observed: '), node))
    wait(observed_cell)
    click_node(observed_cell)
    clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clipboard.set_text('P0 clipboard sentinel', -1)
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+c'])
    original = wait(lambda: text if (text := clipboard.wait_for_text())
        and text != 'P0 clipboard sentinel' else None)
    if '2026-10-24' not in original or '123456' not in original:
        raise RuntimeError('Related-row temporal fixture was not exact')
    def calendar_cell():
        def decimal_digits(text):
            return ''.join(str(unicodedata.decimal(ch)) if ch.isdecimal() else ch for ch in text)
        return observed_first(lambda node: ('Action' in node.get_interfaces() and
            decimal_digits(native_name(node)) == 'Row 1, observed: 24/10/2026 13:14:15.123456', node))
    palette('Display format')
    wait(lambda: find('Canonical / raw'))
    activate('Canonical / raw', message_key='canonicalValue')
    activate('Temporal · custom pattern', message_key='temporalCustomPattern')
    pattern = wait(lambda: find('Temporal display pattern', 'EditableText'))
    focus(pattern)
    if not Atspi.EditableText.set_text_contents(pattern, 'dd/MM/yyyy HH:mm:ss.SSSSSS'):
        raise RuntimeError('Native temporal pattern rejected')
    activate('Apply', message_key='applyView')
    wait(calendar_cell)
    photograph('p0-temporal-display-only')
    click_node(calendar_cell)
    clipboard.set_text('P0 displayed-copy sentinel', -1)
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+c'])
    wait(lambda: clipboard.wait_for_text() == original)
    evidence['customTemporalDisplayPreservesExactCopy'] = True
    def body_cell(selected=False):
        return observed_first(lambda node: (
            (native_name(node) or '').startswith('Row 1, body: ') and
            'Action' in node.get_interfaces() and
            (not selected or node.get_state_set().contains(Atspi.StateType.SELECTED)), node))
    command(['xdotool', 'key', '--clearmodifiers', 'Right'])
    wait(lambda: body_cell(selected=True))
    click_node(body_cell)
    palette('Assess editing')
    wait(lambda: selected_owner() == related_owner)
    evidence['completeValueOwnerBeforeModal'] = related_owner
    palette('Inspect value')
    wait(lambda: seen_key('valueTruncated'))
    title = 'body · ' + ('text' if os.environ['BUSYDATA_NATIVE_FIXTURE_ENGINE'] == 'POSTGRESQL' else 'LONGTEXT')
    def value_dialog():
        return find_native_authored_modal(Atspi, lambda: objects(app), title, modal_role)
    modal_owner = wait(lambda: NativeValueModalOwner.capture(related_owner, value_dialog(),
        selected_owner, accessible_ancestors, lambda: objects(app)))
    def complete_field():
        return modal_owner.field(find('Exact value', 'EditableText'))
    activate('Value actions', message_key='valueEditorActions')
    activate('Load next 64 KiB', message_key='loadValueChunk')
    wait(lambda: seen_key('valueChunkRange', start='0', end='65536', total='90000'))
    activate('Value actions', message_key='valueEditorActions')
    activate('Reset value preview', message_key='resetValueChunks')
    activate('Value actions', message_key='valueEditorActions')
    activate('Edit complete value', message_key='editCompleteValue')
    evidence['completeValueNativeReadbacks'] = []
    for index, count in enumerate((16384, 13616)):
        wait(lambda index=index: seen_key('textValuePage', current=str(index + 1), total='2'))
        complete = wait(complete_field)
        focus(complete)
        observed = {'page': index + 1, 'owner': related_owner}
        wait(lambda count=count: native_complete_value_matches(Atspi,
            complete_field, '漢' * count, observed, current_nodes=lambda: objects(app)))
        evidence['completeValueNativeReadbacks'].append(observed)
        if index == 0:
            activate('Next text page', message_key='textValueNextPage')
    edited_last = '漢' * 13615 + '末'
    set_native_inline_text(Atspi, complete_field, edited_last, wait,
        expected_original='漢' * 13616)
    evidence['completeValueNativeEditedLastPage'] = {}
    wait(lambda: native_complete_value_matches(Atspi,
        complete_field, edited_last,
        evidence['completeValueNativeEditedLastPage'], current_nodes=lambda: objects(app)))
    photograph('p0-explicit-complete-value')
    activate('Stage change', message_key='stageChange')
    wait(lambda: selected_owner() == related_owner)
    evidence['completeValueOwnerAfterModal'] = related_owner
    palette('Discard pending changes')
    activate('Discard pending changes', message_key='discardChanges')
    wait(body_cell)
    evidence['chunkedAndCompleteValueExactStagingAndDiscard'] = {
        'retainedUtf8Bytes': 90000, 'textUnits': 30000,
        'explicitAcquisition': True, 'appliedDatabaseMutation': False}
    restored_speech = reader_offset()
    palette('Close tab')
    wait(lambda: selected_owner() == source_owner)
    select(primary_row, 'n', '漢😀')
    wait(lambda: speech_contains([localized(f'Row {primary_row}, n: 漢😀')], after_bytes=restored_speech))
    evidence['readerOffsets']['restoredSource'] = [restored_speech, reader_offset()]
    evidence['sourceOwnerSelectionAndReaderRestored'] = True
    if durable_snapshot() != before_durable:
        raise RuntimeError('P0 staging or inspection mutated durable fixture rows')
    evidence['independentDurableRowsUnchanged'] = {
        'parentRows': 2, 'childRows': 1, 'childTextUtf8Bytes': 90000,
        'snapshotSha256': before_durable}
    evidence['passed'] = True
    return validate(evidence)


def validate(evidence):
    """A summary boolean cannot certify omitted native editor workflows."""
    import re
    import hashlib
    if not isinstance(evidence, dict) or evidence.get('passed') is not True:
        raise RuntimeError('Native P0 result-editor evidence is incomplete')
    required = ('centralMetadataFullRefreshAndNewRetainedSource',
        'transposeExactSelectionAndKeyboard', 'treeKeyboardExpansionAndExactValue',
        'textExactSelectionAndExplicitScope', 'recordNavigationAndTypedValueEditorStaging',
        'explicitDiscardPreservesOriginal', 'exactNumericAggregateAndScope',
        'cloneVisibleStagedOnlyAndExplicitDiscard', 'relatedRowsReviewedNormalDocument',
        'customTemporalDisplayPreservesExactCopy', 'sourceOwnerSelectionAndReaderRestored')
    if (any(evidence.get(key) is not True for key in required)
            or evidence.get('databaseMutationSubmitted') is not False
            or not isinstance(evidence.get('sourceOwner'), str) or not evidence['sourceOwner']
            or not isinstance(evidence.get('relatedOwner'), str) or not evidence['relatedOwner']
            or evidence['sourceOwner'] == evidence['relatedOwner']):
        raise RuntimeError('Native P0 result-editor workflow or owner evidence is incomplete')
    refresh = evidence.get('metadataRefreshSourceProof')
    if (not isinstance(refresh, dict) or refresh.get('document') != evidence['sourceOwner'] or
            any(not isinstance(refresh.get(key), str) or
                re.fullmatch(r'[^\x00-\x20\x7f]{1,128}', refresh[key]) is None
                for key in ('owner', 'previousSource', 'source', 'display')) or
            refresh['previousSource'] == refresh['source']):
        raise RuntimeError('Native P0 metadata refresh lacks a fresh retained source proof')
    keyed_rows = refresh.get('keyedRows')
    if (not isinstance(keyed_rows, dict) or set(keyed_rows) != {'1', '2'} or
            any(type(row) is not int for row in keyed_rows.values()) or
            set(keyed_rows.values()) != {1, 2}):
        raise RuntimeError('Native P0 fixture key/source-row evidence is incomplete')
    value = evidence.get('chunkedAndCompleteValueExactStagingAndDiscard', {})
    pages = evidence.get('completeValueNativeReadbacks', [])
    def exact_readback(receipt, text):
        return (isinstance(receipt, dict) and
            receipt.get('characterCount') == len(text) and
            receipt.get('returnedCharacters') == len(text) and
            receipt.get('utf8Sha256') == hashlib.sha256(text.encode()).hexdigest())
    if (evidence.get('completeValueOwnerBeforeModal') != evidence['relatedOwner'] or
            evidence.get('completeValueOwnerAfterModal') != evidence['relatedOwner'] or
            len(pages) != 2 or any(not exact_readback(page, '漢' * count) or
            page.get('page') != index + 1 or page.get('owner') != evidence['relatedOwner'] for index, (page, count) in
            enumerate(zip(pages, (16384, 13616)))) or
            not exact_readback(evidence.get('completeValueNativeEditedLastPage'),
                '漢' * 13615 + '末')):
        raise RuntimeError('Native complete-value pages are not exact')
    rows = evidence.get('independentDurableRowsUnchanged', {})
    readers = evidence.get('readerOffsets', {})
    if (value.get('retainedUtf8Bytes') != 90000 or value.get('textUnits') != 30000
            or value.get('explicitAcquisition') is not True
            or value.get('appliedDatabaseMutation') is not False
            or rows.get('parentRows') != 2 or rows.get('childRows') != 1
            or rows.get('childTextUtf8Bytes') != 90000
            or re.fullmatch(r'[0-9a-f]{64}', rows.get('snapshotSha256', '')) is None):
        raise RuntimeError('Native P0 exact value or durable source evidence is incomplete')
    for phase in ('transpose', 'valueEditor', 'restoredSource'):
        interval = readers.get(phase)
        if (not isinstance(interval, list) or len(interval) != 2
                or any(type(number) is not int for number in interval)
                or not 0 <= interval[0] < interval[1] <= 4 * 1024 * 1024):
            raise RuntimeError('Native P0 reader evidence is not from the current action')
    return evidence
