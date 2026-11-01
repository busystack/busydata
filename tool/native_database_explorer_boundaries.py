"""Ordinary visible-control regressions for paged metadata integration."""
import os
from pathlib import Path
import re
import subprocess


def verify_boundaries(*, Atspi, app, objects, find, wait, focus, activate, command,
        photograph, supply_password, report, cases, engine, source, server, row,
        open_menu, expand, palette, expected_target):
    from native_workbench_acceptance import (accessible_ancestors, bounded_native_text,
        focus_live_native_control, pointer_at_native_bounds, visible_native_bounds, find_live_control, owned_product_window)
    from verify_installed_snap import picker_location_field

    namespace = 'public' if engine == 'POSTGRESQL' else 'busydata'
    document_scroll_x = None
    document_scroll_y = None

    def showing(item):
        if item is None or not all(item.get_state_set().contains(flag) for flag in
                (Atspi.StateType.SHOWING, Atspi.StateType.VISIBLE)):
            return False
        box = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
        frame = next((p for p in accessible_ancestors(item) if p.get_role() == Atspi.Role.FRAME), None)
        if frame is None: return False
        window = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
        return box.width > 0 and box.height > 0 and box.x >= window.x and box.y >= window.y and box.x + box.width <= window.x + window.width and box.y + box.height <= window.y + window.height

    def document_text(label):
        for n in objects(app):
            name = n.get_name() or ''
            # GTK coalesces a plain heading and its property labels. Match the
            # exact first line, then verify the live document and native bounds.
            if label not in name.splitlines() and not name.startswith(label + ': ') and bounded_native_text(Atspi, n) != label: continue
            if any(p.get_role() == Atspi.Role.TREE for p in accessible_ancestors(n)): continue
            if showing(n): return n
        return None

    def wheel(direction=5, dialog=False, steps=None):
        window = command(['xdotool', 'search', '--onlyvisible', '--name', '^BusyData$'], capture_output=True, text=True).stdout.splitlines()
        if len(window) != 1: raise RuntimeError('Boundary tour owned window identity')
        geometry = dict(line.split('=', 1) for line in command(['xdotool', 'getwindowgeometry', '--shell', window[0]], capture_output=True, text=True).stdout.splitlines() if '=' in line)
        x = document_scroll_x if not dialog and document_scroll_x is not None else int(geometry['X']) + int(int(geometry['WIDTH']) * (.5 if dialog else .78))
        y = document_scroll_y if not dialog and document_scroll_y is not None else int(geometry['Y']) + int(int(geometry['HEIGHT']) * .68)
        # Grouped property rows make a complete wide-table Structure view much
        # taller than the former compact list. Scroll approximately one native
        # window per probe; retain the same bounded probe count and deadline.
        clicks = steps if steps is not None else max(8, (int(geometry['HEIGHT']) + 47) // 48)
        command(['xdotool', 'mousemove', str(x), str(y), 'click', '--repeat', str(clicks), '--delay', '25', str(direction)])

    def reveal_text(label, direction=5, steps=None):
        for _ in range(100):
            found = document_text(label)
            if found is not None: return found
            wheel(direction, steps=steps)
        report['nativeBoundaryMissingControl'] = label
        photograph('database-panel-unreachable-' + label)
        raise RuntimeError('Bounded document control unreachable: ' + label)

    def press_in(owner, label):
        def button():
            parent = row(owner)
            return next((n for n in objects(app) if n.get_name() == label and parent in accessible_ancestors(n) and showing(n)), None) if parent else None
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, button, wait))

    def focus_tree(name):
        command(['xdotool', 'windowfocus', '--sync', owned_product_window(command, wait, app.get_process_id())])
        # Off-screen virtualized rows cannot acknowledge AT-SPI focus. Reveal
        # the scoped row by ordinary pointer scrolling before requesting it.
        def scroll_tree(direction):
            windows = command(['xdotool', 'search', '--onlyvisible', '--name', '^BusyData$'], capture_output=True, text=True).stdout.splitlines()
            if len(windows) != 1: raise RuntimeError('Boundary tree window identity')
            values = dict(line.split('=', 1) for line in command(['xdotool', 'getwindowgeometry', '--shell', windows[0]], capture_output=True, text=True).stdout.splitlines() if '=' in line)
            command(['xdotool', 'mousemove', str(int(values['X']) + 120),
                str(int(values['Y']) + int(int(values['HEIGHT']) * .65)),
                'click', '--repeat', '8', '--delay', '15', str(direction)])
        for direction in (4, 5):
            for _ in range(48):
                target = row(name)
                if target is not None and showing(target):
                    focus_live_native_control(Atspi, lambda: row(name), wait)
                    wait(lambda: (item := row(name)) is not None and all(
                        item.get_state_set().contains(flag) for flag in
                        (Atspi.StateType.FOCUSED, Atspi.StateType.SELECTED)))
                    return
                scroll_tree(direction)
        raise RuntimeError('Scoped native tree row could not be reached: ' + name)

    def search_child(name, parent, group):
        focus_tree(expected_target)
        open_menu(expected_target, 'Search database objects')
        field = wait(lambda: find('Search database objects', 'EditableText'))
        focus(field)
        if not Atspi.EditableText.set_text_contents(field, name): raise RuntimeError('Boundary object search input rejected')
        # The entry's independent clear action precedes the submit button.
        for _ in range(3):
            command(['xdotool', 'key', '--clearmodifiers', 'Tab'])
            try:
                wait(lambda: any(n.get_name() == 'Search database objects' and
                    n.get_role() == Atspi.Role.PUSH_BUTTON and
                    n.get_state_set().contains(Atspi.StateType.FOCUSED) for n in objects(app)), 1)
                break
            except TimeoutError:
                continue
        else:
            raise RuntimeError('Boundary search submit focus was not reached')
        command(['xdotool', 'key', '--clearmodifiers', 'Return'])
        result = 'busydata/' + namespace + '/' + parent + '/' + name
        try:
            wait(lambda: find(result), 30)
        except TimeoutError:
            photograph('database-panel-child-search-unavailable-' + name)
            raise
        activate(result)
        wait(lambda: row(name) is not None and row(name).get_state_set().contains(Atspi.StateType.FOCUSED), 30)
        target_name = row(name).get_name()
        if (' / ' + parent + ' · ') not in target_name: raise RuntimeError('Child reveal lost its native parent identity')
        focus_tree(group)
        if not row(group).get_state_set().contains(Atspi.StateType.EXPANDED): raise RuntimeError('Child revealed through the wrong relation group')
        report.setdefault('nativePagedChildRevealTargets', {})[name] = {'node': target_name, 'group': group}
        command(['xdotool', 'key', '--clearmodifiers', 'Left'])
        # The visible document toolbar captures its own exact child, independent
        # of the collapsed tree category which currently has keyboard focus.
        pointer_at_native_bounds(command, visible_native_bounds(Atspi,
            lambda: find('Reveal in Database Explorer (Alt+Shift+B)'), wait))
        wait(lambda: row(name) is not None and row(name).get_state_set().contains(Atspi.StateType.FOCUSED), 30)

    report['stage'] = 'native-boundary-complete-column-structure'
    open_menu('native_wide_columns', 'Inspect structure')
    wait(lambda: find('Close tab native_wide_columns'), 30)
    reveal_text('c159')
    wait(lambda: document_text('161'))
    photograph('database-panel-later-column-complete-structure')
    expand('native_wide_columns')
    expand('Columns')
    press_in('Columns', 'Load more')
    wait(lambda: row('c128') is not None, 30)
    focus_live_native_control(Atspi, lambda: row('Columns'), wait)
    command(['xdotool', 'type', '--clearmodifiers', 'c159'])
    wait(lambda: row('c159') and row('c159').get_state_set().contains(Atspi.StateType.FOCUSED))
    command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
    open_menu('c159', 'Inspect structure')
    wait(lambda: document_text('c159') and document_text('161'), 30)
    photograph('database-panel-later-column-exact-inspection')
    search_child('c159', 'native_wide_columns', 'Tables')
    cases['complete-later-column-structure-exact-tree-search'] = True

    report['stage'] = 'native-boundary-generated-fields-after-first-page'
    focus_tree('native_wide_columns')
    open_menu('native_wide_columns', 'New query')
    editor = wait(lambda: find_live_control(Atspi, objects(app), 'SQL editor', 'EditableText', current_nodes=lambda: objects(app), name_prefix=True))
    focus(editor)
    if not Atspi.EditableText.set_text_contents(editor, 'SELECT id,z_generated,z_identity FROM native_wide_columns ORDER BY id;'):
        raise RuntimeError('Source-bound boundary console rejected input')
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+Return'])
    wait(lambda: find('Password', 'EditableText') or find('Row 1, z_generated: 42'), 30)
    if find('Password', 'EditableText'):
        secret = find('Password', 'EditableText');focus(secret);supply_password(secret);activate('Connect')
    wait(lambda: find('Row 1, z_generated: 42'), 30)
    palette('Edit row')
    for name in ('z_generated', 'z_identity'):
        def generated_field():
            return next((n for n in objects(app) if (n.get_name() or '').startswith(name + ' · ') and 'EditableText' in n.get_interfaces() and showing(n)), None)
        field = wait(generated_field)
        state = field.get_state_set()
        if state.contains(Atspi.StateType.SENSITIVE) and not state.contains(Atspi.StateType.READ_ONLY):
            raise RuntimeError('Later generated/identity column became editable')
    photograph('database-panel-later-generated-fields-readonly')
    activate('Cancel')
    cases['later-generated-fields-remain-readonly'] = True

    report['stage'] = 'native-boundary-reviewed-later-column-import'
    focus_tree('native_wide_columns')
    open_menu('native_wide_columns', 'Import data')
    path = Path(os.environ['XDG_DATA_HOME']).parent / 'wide-column-import.csv'
    path.write_text('source_id,late_value\n2,9271\n')
    pointer_at_native_bounds(command, visible_native_bounds(Atspi,
        lambda: find('Choose source'), wait))
    def chooser():
        result = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', '^Open.*'], capture_output=True, text=True, timeout=10)
        return result.stdout.splitlines()[-1] if result.returncode == 0 and result.stdout.splitlines() else None
    window = wait(chooser)
    command(['xdotool', 'windowfocus', '--sync', window])
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+l'])
    location = wait(lambda: picker_location_field(window))
    if not Atspi.EditableText.set_text_contents(location, str(path)):
        raise RuntimeError('Native import chooser rejected the source path')
    wait(lambda: Atspi.Text.get_text(location, 0, -1) == str(path))
    # GTK location Enter can select the file without accepting the chooser.
    activate('Open')
    wait(lambda: chooser() is None)
    preview = visible_native_bounds(Atspi, lambda: reveal_text('Preview source'), wait)
    # The import form has its own bounded width. Keep wheel input inside that
    # actual form rather than the blank remainder of a wide document pane.
    document_scroll_x = preview.x + preview.width // 2
    pointer_at_native_bounds(command, preview)
    wait(lambda: document_text('source_id') or document_text('Source column source_id'))
    first_mapping = wait(lambda: next((n for n in objects(app)
        if n.get_name() == 'id: Omit / database default'), None))
    # First reveal the mapping viewport through the outer form's padding.
    # A page-sized wheel over a partially visible nested list can skip id.
    first_box = Atspi.Component.get_extents(first_mapping, Atspi.CoordType.SCREEN)
    document_scroll_x = first_box.x - 4
    for target, value in [('id', 'source_id'), ('c159', 'late_value')]:
        label = reveal_text(target, steps=1 if target == 'id' else None)
        box = Atspi.Component.get_extents(label, Atspi.CoordType.SCREEN)
        y = box.y
        # The mapping viewport virtualizes wide targets. Keep subsequent wheel
        # input inside its actual first visible row, rather than below it in
        # the independently scrolling outer form.
        if target == 'id':
            document_scroll_x = box.x + box.width // 2
            document_scroll_y = box.y + box.height // 2
        def mapping():
            return next((n for n in objects(app) if n.get_name() in ('Omit / database default', target + ': Omit / database default') and showing(n) and abs(Atspi.Component.get_extents(n, Atspi.CoordType.SCREEN).y-y) < 25), None)
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, mapping, wait))
        activate(value, menu_only=True)
    photograph('database-panel-later-column-import-mapping')
    activate('Review transfer')
    reveal_text('c159 → late_value')
    photograph('database-panel-later-column-import-review')
    activate('Start import')
    query = 'SELECT c159,z_generated FROM ' + namespace + '.native_wide_columns WHERE id=2'
    wait(lambda: server(query) == '9271\t9272' if engine != 'POSTGRESQL' else server(query) == '9271|9272', 30)
    cases['reviewed-import-reaches-later-target-column'] = True

    if engine == 'POSTGRESQL':
        report['stage'] = 'native-boundary-view-parent-reveal'
        for name, parent in [('native_view_late_column', 'native_late_view'), ('native_materialized_late_index', 'native_materialized')]:
            search_child(name, parent, 'Views')
            photograph('database-panel-reveal-' + name)
            cases['view-child-reveal-' + name] = True
    for name in ('native_wide_columns', 'Views'):
        focus_tree(name)
        if row(name).get_state_set().contains(Atspi.StateType.EXPANDED):
            command(['xdotool', 'key', '--clearmodifiers', 'Left'])
    focus_tree('Tables')
    command(['xdotool', 'key', '--clearmodifiers', 'Left', 'Right'])


def verify_namespace_pages(*, Atspi, app, objects, find, wait, focus, activate,
        command, photograph, supply_password, report, cases, row, open_menu,
        server, expected_target, original, restart, native_function_key, current_editor):
    from native_workbench_acceptance import (accessible_ancestors,
        focus_live_native_control, pointer_at_native_bounds, visible_native_bounds)

    total = int(server('SELECT count(*) FROM pg_namespace'))
    if total <= 128: raise RuntimeError('Namespace boundary fixture did not exceed one page')

    def badge():
        parent = row('busydata')
        return next((n for n in objects(app) if re.fullmatch(r'[0-9]+ of [0-9]+', n.get_name() or '') and parent in accessible_ancestors(n)), None) if parent else None

    def badge_text():
        value = badge()
        return value.get_name() if value else ''

    def selector():
        focus_live_native_control(Atspi, lambda: row('busydata'), wait)
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, badge, wait))

    def dialog_button(label):
        return next((n for n in objects(app) if n.get_name() == label and 'Action' in n.get_interfaces() and
            n.get_state_set().contains(Atspi.StateType.SHOWING) and
            not any(p.get_role() == Atspi.Role.TREE for p in accessible_ancestors(n))), None)

    def dialog_click(label):
        control = wait(lambda: dialog_button(label))
        if control.get_role() == Atspi.Role.CHECK_BOX:
            checked = control.get_state_set().contains(Atspi.StateType.CHECKED)
            # The merged checkbox row includes blank layout space. Invoke its
            # real accessible Tap and acknowledge the checked state before Apply.
            activate(label)
            wait(lambda: (item := dialog_button(label)) is not None and
                item.get_state_set().contains(Atspi.StateType.CHECKED) != checked)
        else:
            pointer_at_native_bounds(command, visible_native_bounds(Atspi, lambda: dialog_button(label), wait))

    def dialog_scroll(direction=5):
        window = command(['xdotool', 'search', '--onlyvisible', '--name', '^BusyData$'], capture_output=True, text=True).stdout.splitlines()
        if len(window) != 1: raise RuntimeError('Namespace dialog window identity')
        values = dict(line.split('=', 1) for line in command(['xdotool', 'getwindowgeometry', '--shell', window[0]], capture_output=True, text=True).stdout.splitlines() if '=' in line)
        command(['xdotool', 'mousemove', str(int(values['X']) + int(values['WIDTH']) // 2),
            str(int(values['Y']) + int(int(values['HEIGHT']) * .6)), 'click', '--repeat', '90', '--delay', '10', str(direction)])

    report['stage'] = 'native-namespace-all-excludes-only-first-page-name'
    selector()
    activate('Selected');activate('All Namespaces')
    dialog_click('namespace_page_000')
    photograph('database-panel-namespace-all-except-one-pending')
    activate('Apply')
    wait(lambda: badge_text() == f'{total-1} of {total}', 30)
    if row('namespace_page_000') is not None: raise RuntimeError('Excluded namespace remained selected')
    # Reach an untouched later page through its owning database row.
    parent = row('busydata')
    more = lambda: next((n for n in objects(app) if n.get_name() == 'Load more' and row('busydata') in accessible_ancestors(n)), None)
    pointer_at_native_bounds(command, visible_native_bounds(Atspi, more, wait))
    wait(lambda: row('namespace_page_129'))
    focus_live_native_control(Atspi, lambda: row('namespace_page_129'), wait)
    command(['xdotool', 'key', '--clearmodifiers', 'Right'])
    wait(lambda: row('namespace_page_129').get_state_set().contains(Atspi.StateType.EXPANDED))
    photograph('database-panel-namespace-all-except-one-later-page')
    wait(lambda: find('Row 1, safety_marker: 8203'))

    def close_window():
        for n in objects(app):
            if n.get_name() != 'Close' or 'Component' not in n.get_interfaces(): continue
            frame = next((p for p in accessible_ancestors(n) if p.get_role() == Atspi.Role.FRAME), None)
            if frame is not None:
                box = Atspi.Component.get_extents(n, Atspi.CoordType.SCREEN)
                window = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
                if box.y < window.y + 64: return n
        return None
    pointer_at_native_bounds(command, visible_native_bounds(Atspi, close_window, wait))
    activate('Save drafts and close')
    app = restart()
    wait(lambda: row(expected_target), 30)
    if server("SELECT count(*) FROM pg_stat_activity WHERE application_name='BusyData'") != '0':
        raise RuntimeError('Namespace recovery acquired a JDBC session')
    open_menu(expected_target, 'Connect')
    secret = wait(lambda: find('Password', 'EditableText'));focus(secret);supply_password(secret);activate('Connect')
    wait(lambda: badge_text() == f'{total-1} of {total}', 30)
    photograph('database-panel-namespace-exclusion-restored')
    selector()
    dialog_scroll();dialog_click('Load more');dialog_scroll(4)
    dialog_click('namespace_page_129')
    activate('Apply')
    wait(lambda: badge_text() == f'{total-2} of {total}', 30)
    if row('namespace_page_000') is not None or row('namespace_page_129') is not None:
        raise RuntimeError('All exclusions changed an unedited namespace after restart')
    photograph('database-panel-namespace-later-page-exclusion-after-restart')
    cases['namespace-all-exclusion-restores-disconnected'] = True

    # Recover the source-bound draft through the ordinary first Run route.
    focus_live_native_control(Atspi, lambda: row(expected_target), wait)
    native_function_key('F10', control=True, shift=True)
    activate(original + ' · busydata / public')
    focus_live_native_control(Atspi, current_editor, wait)
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+Return'])
    wait(lambda: find('Password', 'EditableText') or find('Row 1, safety_marker: 8203'), 30)
    if find('Password', 'EditableText'):
        secret = find('Password', 'EditableText');focus(secret);supply_password(secret);activate('Connect')
    wait(lambda: find('Row 1, safety_marker: 8203') and find('Row 1, n: 漢😀'), 30)

    report['stage'] = 'native-namespace-explicit-edits-across-pages'
    selector()
    activate('All Namespaces');activate('Selected')
    dialog_click('namespace_page_000')
    dialog_scroll();dialog_click('Load more');dialog_scroll(4)
    dialog_click('namespace_page_129')
    photograph('database-panel-namespace-explicit-second-page-pending')
    activate('Apply')
    wait(lambda: badge_text() == f'2 of {total}' and row('namespace_page_000') and row('namespace_page_129'), 30)
    if row('public') is not None: raise RuntimeError('All Namespaces hidden did not retain the exact accepted set')
    photograph('database-panel-namespace-both-pages-accepted')
    selector();dialog_click('namespace_page_000');activate('Cancel')
    wait(lambda: badge_text() == f'2 of {total}' and row('namespace_page_000') and row('namespace_page_129'))
    selector();activate('Default');activate('Apply')
    wait(lambda: badge_text() == f'1 of {total}' and row('public'), 30)
    wait(lambda: find('Row 1, safety_marker: 8203') and find('Row 1, n: 漢😀'))
    cases['namespace-pending-pages-cancel-off-page-default'] = True
