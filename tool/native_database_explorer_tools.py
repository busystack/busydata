"""Real disposable objects used by the ordinary Database inspection tour."""


def boundary_fixture_sql(engine):
    if engine not in ('POSTGRESQL', 'MYSQL', 'MARIADB'):
        raise ValueError('Unsupported boundary fixture engine')
    fields = ['id INTEGER PRIMARY KEY'] + [f'c{i:03} INTEGER DEFAULT 0' for i in range(160)]
    fields += ['z_generated INTEGER GENERATED ALWAYS AS (c159+1) STORED',
        'z_identity INTEGER GENERATED ALWAYS AS IDENTITY' if engine == 'POSTGRESQL'
        else 'z_identity INTEGER AUTO_INCREMENT UNIQUE']
    sql = ('CREATE TABLE native_wide_columns(' + ','.join(fields) + ');\n'
        'INSERT INTO native_wide_columns(id,c159) VALUES(1,41);\n'
        'CREATE VIEW native_late_view AS SELECT c159 AS native_view_late_column FROM native_wide_columns;\n')
    if engine == 'POSTGRESQL':
        sql += ('CREATE INDEX native_materialized_late_index ON native_materialized(id);\n' +
            ''.join(f'CREATE SCHEMA namespace_page_{i:03};\n' for i in range(160)) +
            'CREATE TABLE audit.native_late_view(native_view_late_column text);\n'
            '\\connect busydata_desired busydata\nCREATE TABLE native_late_view(native_view_late_column text);\n'
            'CREATE TABLE native_materialized(id text);\n\\connect busydata busydata\n')
    return sql


def object_fixture_sql(engine):
    if engine == 'POSTGRESQL':
        return r'''\connect busydata_desired busydata
CREATE SCHEMA audit;
CREATE TABLE audit.native_atspi_fixture(id integer PRIMARY KEY,n text,audit_note text);
INSERT INTO audit.native_atspi_fixture VALUES(1,'other schema second database','audit only');
\connect busydata busydata
CREATE SEQUENCE native_sequence START 41 INCREMENT 3;
COMMENT ON SEQUENCE native_sequence IS 'Read-only sequence inspection fixture';
CREATE TABLE native_partition(id integer) PARTITION BY RANGE(id);
CREATE TABLE native_partition_first PARTITION OF native_partition FOR VALUES FROM(0) TO(100);
\connect busydata fixture_owner
CREATE EXTENSION postgres_fdw;
CREATE SERVER native_foreign_server FOREIGN DATA WRAPPER postgres_fdw OPTIONS(host '127.0.0.1',dbname 'busydata');
GRANT USAGE ON FOREIGN SERVER native_foreign_server TO busydata;
\connect busydata busydata
CREATE FOREIGN TABLE native_foreign_table(id integer) SERVER native_foreign_server OPTIONS(table_name 'native_atspi_fixture');
CREATE MATERIALIZED VIEW native_materialized AS SELECT id,n FROM native_atspi_fixture;
CREATE FUNCTION native_function(x integer) RETURNS integer LANGUAGE SQL AS 'SELECT x';
CREATE FUNCTION native_function(x text) RETURNS text LANGUAGE SQL AS 'SELECT x';
CREATE PROCEDURE native_procedure() LANGUAGE SQL AS 'SELECT 17';
\connect busydata fixture_owner
CREATE DATABASE restricted_fixture OWNER fixture_owner;
REVOKE CONNECT ON DATABASE restricted_fixture FROM PUBLIC;
\connect busydata busydata
''' + boundary_fixture_sql(engine)
    if engine not in ('MYSQL', 'MARIADB'):
        raise ValueError('Unsupported inspection fixture engine')
    return ("USE busydata;\n"
        "CREATE FUNCTION native_function(x integer) RETURNS integer DETERMINISTIC RETURN x;\n"
        "CREATE PROCEDURE native_procedure() SELECT 17;\n" +
        ("CREATE SEQUENCE native_sequence START WITH 41 INCREMENT BY 3;\n" if engine == 'MARIADB' else '') + boundary_fixture_sql(engine))


def is_object_ddl(value, name):
    """Recognize native SHOW CREATE prefixes without discarding DEFINER clauses."""
    import re
    account = r"(?:`(?:``|[^`])*`|'(?:''|[^'])*'|[A-Za-z0-9_%.:-]+)"
    prefix = (r'\bCREATE\s+(?:OR\s+REPLACE\s+)?' +
        r'(?:DEFINER\s*=\s*' + account + r'\s*@\s*' + account + r'\s+)?')
    return name in value and re.search(prefix +
        r'(?:TABLE|VIEW|MATERIALIZED VIEW|SEQUENCE|FUNCTION|PROCEDURE)\b', value) is not None


def verify_tools(*, Atspi, app, report, objects, find, wait, focus, activate,
                 command, photograph, supply_password, fixture, source, engine,
                 labels, expected_target, native_function_key, native_name, supports, palette, restart):
    import os
    import re
    import subprocess
    import time
    from native_workbench_acceptance import (accessible_ancestors,
        bounded_native_text, find_native_tree_row, focus_live_native_control, native_tab_name,
        pointer_at_native_bounds, visible_native_bounds,
        visible_object_definition, find_live_control, owned_product_window, request_native_focus)
    postgres = engine == 'POSTGRESQL'
    cases = report['databaseExplorerToolsCases'] = {'startup-default-console': True}
    original = wait(lambda: next((re.match(r'Query [0-9]+', native_tab_name(native_name(n))).group()
        for n in objects(app) if native_tab_name(native_name(n)).startswith('Query ')
        and n.get_state_set().contains(Atspi.StateType.SELECTED)), None))

    def row(name, catalog='busydata'):
        nodes = objects(app)
        if name != expected_target:
            # Delimiters matter: busydata must never match busydata_desired.
            scope = re.compile(r' · ' + re.escape(catalog) + r'(?: / | · )')
            nodes = [n for n in nodes if scope.search(native_name(n))]
        return find_native_tree_row(Atspi, nodes, labels, name, settling=True)

    def reveal_row(name, catalog='busydata'):
        # A loaded logical namespace can be outside the virtualized native
        # viewport. Scroll that viewport; absence from AT-SPI is not absence
        # from the selected namespace set. Retain the former 30-second bound.
        deadline = time.monotonic() + 30
        def current_tree():
            trees = [n for n in objects(app) if n.get_role() == Atspi.Role.TREE and
                n.get_state_set().contains(Atspi.StateType.SHOWING) and
                n.get_name() == labels.get('Database', 'Database')]
            if len(trees) > 1:
                raise RuntimeError('Explorer reveal requires one owned tree')
            return trees[0] if trees else None
        for direction in (4, 5):
            for _ in range(48):
                tree = wait(current_tree, max(.01, deadline - time.monotonic()))
                viewport = Atspi.Component.get_extents(tree, Atspi.CoordType.SCREEN)
                report['nativeExplorerRevealViewport'] = {'name': name, 'catalog': catalog,
                    **{key: getattr(viewport, key) for key in ('x', 'y', 'width', 'height')}}
                item = row(name, catalog)
                if item is not None:
                    box = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
                    if all(item.get_state_set().contains(flag) for flag in
                            (Atspi.StateType.SHOWING, Atspi.StateType.VISIBLE)) and \
                            box.width > 0 and box.height > 0 and \
                            box.y >= viewport.y and box.y + box.height <= viewport.y + viewport.height:
                        return item
                if time.monotonic() >= deadline:
                    raise TimeoutError('Native Explorer row reveal deadline')
                command(['xdotool', 'mousemove',
                    str(viewport.x + viewport.width // 3),
                    str(viewport.y + int(viewport.height * .65)),
                    'click', '--repeat', '8', '--delay', '15', str(direction)])
        raise RuntimeError('Loaded Explorer row could not be revealed: ' + name)

    def select_row(name, catalog='busydata'):
        command(['xdotool', 'windowfocus', '--sync', owned_product_window(command, wait, app.get_process_id())])
        target = reveal_row(name, catalog)
        before = Atspi.Component.get_extents(target, Atspi.CoordType.SCREEN)
        def selected_and_focused():
            item = row(name, catalog)
            if item is None: return False
            if all(item.get_state_set().contains(flag) for flag in
                   (Atspi.StateType.FOCUSED, Atspi.StateType.SELECTED)):
                return True
            # Dialog restoration and regrouping can replace the focused node.
            # Reacquire this same live row, never a cached or unrelated target.
            request_native_focus(Atspi, item)
            return False
        wait(selected_and_focused)
        after = Atspi.Component.get_extents(row(name, catalog), Atspi.CoordType.SCREEN)
        report.setdefault('nativeExplorerSelectionBounds', []).append({'name': name, 'catalog': catalog,
            'beforeFocus': {key: getattr(before, key) for key in ('x','y','width','height')},
            'afterFocus': {key: getattr(after, key) for key in ('x','y','width','height')}})

    def context(name, action, catalog='busydata'):
        select_row(name, catalog)
        item = row(name, catalog)
        request = {'name': name, 'catalog': catalog, 'action': action,
            'row': native_name(item), 'selected': item.get_state_set().contains(Atspi.StateType.SELECTED),
            'focused': item.get_state_set().contains(Atspi.StateType.FOCUSED)}
        report.setdefault('nativeExplorerMenuRequests', []).append(request)
        command(['xdotool', 'key', '--clearmodifiers', 'Menu'])
        try:
            # Explorer commands are command items. A representation selector's
            # radio item with the same caption cannot acknowledge this request.
            wait(lambda: any(native_name(n) == action and
                n.get_role() == Atspi.Role.MENU_ITEM and
                n.get_state_set().contains(Atspi.StateType.SHOWING) and
                n.get_state_set().contains(Atspi.StateType.SENSITIVE)
                for n in objects(app)))
            request['openedAsCommandMenu'] = True
            activate(action, menu_only=True)
            request['invokedThroughMenu'] = True
        finally:
            request['showingPopups'] = [{'name': native_name(n), 'role': n.get_role_name(),
                'enabled': n.get_state_set().contains(Atspi.StateType.SENSITIVE)}
                for n in objects(app) if n.get_state_set().contains(Atspi.StateType.SHOWING)
                and n.get_role() in (Atspi.Role.MENU, Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM)]


    def expand(name, catalog='busydata'):
        select_row(name, catalog)
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])

    def server(query, catalog='busydata'):
        secret = (source / 'password').read_text()
        if postgres:
            argv = ['docker', 'exec', '-e', 'PGPASSWORD', fixture, 'psql', '-h', '127.0.0.1', '-U', 'busydata', '-d', catalog, '-v', 'ON_ERROR_STOP=1', '-Atc', query]
            environment = dict(os.environ, PGPASSWORD=secret)
        else:
            argv = ['docker', 'exec', '-e', 'MYSQL_PWD', fixture, 'mysql' if engine == 'MYSQL' else 'mariadb', '-h', '127.0.0.1', '-u', 'root', '--batch', '--skip-column-names', '-e', query]
            environment = dict(os.environ, MYSQL_PWD=secret)
        reply = subprocess.run(argv, env=environment, check=True, capture_output=True, text=True, timeout=20)
        if len(reply.stdout) > 4096: raise RuntimeError('Inspection fixture observation budget')
        return reply.stdout.strip()

    def contents(value):
        return any(value in bounded_native_text(Atspi, n) or value in native_name(n)
            for n in objects(app))

    def ddl(name):
        context(name, 'Open definition')
        def actual_definition():
            for n in objects(app):
                state = n.get_state_set()
                if not state.contains(Atspi.StateType.SHOWING): continue
                if state.contains(Atspi.StateType.EDITABLE) and not state.contains(Atspi.StateType.READ_ONLY): continue
                value = native_name(n) + '\n' + bounded_native_text(Atspi, n)
                if is_object_ddl(value, name.split('(')[0]):
                    return True
            return False
        wait(actual_definition, 30)
        photograph('database-panel-definition-' + name.split('(')[0])

    def source_badge():
        owner = row(expected_target)
        return next((n for n in objects(app) if re.fullmatch(r'[0-9]+ of [1-9][0-9]*', native_name(n))
            and owner in accessible_ancestors(n)
            and n.get_state_set().contains(Atspi.StateType.SHOWING)), None)

    def source_badge_text():
        badge = source_badge()
        return native_name(badge) if badge is not None else ''

    def view_options():
        def toolbar_more():
            candidates = [n for n in objects(app) if native_name(n) == 'More'
                and supports(n, 'Action') and n.get_state_set().contains(Atspi.StateType.SHOWING)
                and any(parent.get_name() == labels.get('Database Explorer', 'Database Explorer')
                    for parent in accessible_ancestors(n))]
            if len(candidates) > 1: raise RuntimeError('Ambiguous Explorer toolbar More owner')
            return candidates[0] if candidates else None
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, toolbar_more, wait))
        activate('View options', menu_only=True)
        wait(lambda: find('Filter connections and objects'))

    def table_count():
        owner = row('Tables')
        if owner is None: return None
        for n in objects(app):
            if owner in accessible_ancestors(n):
                match = re.fullmatch(r'Tables\n([0-9]+)', native_name(n))
                if match: return int(match.group(1))
        return None

    def choose_namespace(name):
        select_row(expected_target)
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, source_badge, wait))
        activate(name); activate('Apply')
        reveal_row(name, name)

    expand('public' if postgres else 'busydata')
    expand('Tables')
    wait(lambda: row('native_atspi_fixture'))
    known_tables = int(server("SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND c.relkind IN ('r','p','f')" if postgres else "SELECT count(*) FROM information_schema.tables WHERE table_schema='busydata' AND table_type='BASE TABLE'"))
    wait(lambda: table_count() == known_tables)
    focus_live_native_control(Atspi, lambda: row('Tables'), wait)
    if row('Tables').get_role() != Atspi.Role.TREE_ITEM: raise RuntimeError('Database row has no native tree-item role')
    state = row('Tables').get_state_set()
    report['nativeDatabaseTreeStates'] = {name: state.contains(flag) for name, flag in [('expandable', Atspi.StateType.EXPANDABLE), ('expanded', Atspi.StateType.EXPANDED), ('selected', Atspi.StateType.SELECTED)]}
    if not all(state.contains(flag) for flag in (Atspi.StateType.EXPANDABLE, Atspi.StateType.EXPANDED, Atspi.StateType.SELECTED)):
        raise RuntimeError('Native tree omitted expanded/selected semantics')
    command(['xdotool', 'key', '--clearmodifiers', 'Left'])
    wait(lambda: row('Tables') and not row('Tables').get_state_set().contains(Atspi.StateType.EXPANDED))
    command(['xdotool', 'key', '--clearmodifiers', 'Right'])
    wait(lambda: row('native_atspi_fixture'))
    cases['native-tree-expanded-selected-keyboard-semantics'] = True
    # Document -> exact reveal preserves its qualified source and namespace.
    context('native_atspi_fixture', 'Inspect structure')
    activate('Open definition')
    wait(lambda: visible_object_definition(Atspi, objects(app), 'native_atspi_fixture'), 30)
    select_row('Tables')
    command(['xdotool', 'key', '--clearmodifiers', 'Left'])
    wait(lambda: row('native_atspi_fixture') is None and
        not row('Tables').get_state_set().contains(Atspi.StateType.EXPANDED))
    focus_live_native_control(Atspi,
        lambda: find('Reveal in Database Explorer (Alt+Shift+B)'), wait)
    command(['xdotool', 'key', '--clearmodifiers', 'alt+shift+b'])
    wait(lambda: row('native_atspi_fixture') is not None and
        row('native_atspi_fixture').get_state_set().contains(Atspi.StateType.FOCUSED))
    cases['document-exact-reveal'] = True

    from native_database_explorer_boundaries import verify_boundaries
    verify_boundaries(Atspi=Atspi, app=app, objects=objects, find=find, wait=wait,
        focus=focus, activate=activate, command=command, photograph=photograph,
        supply_password=supply_password, report=report, cases=cases, engine=engine,
        source=source, server=server, row=row, open_menu=context, expand=expand,
        palette=palette, expected_target=expected_target)

    # Speed Search is explicitly local to expanded loaded nodes.
    focus_live_native_control(Atspi, lambda: row('Tables'), wait)
    command(['xdotool', 'type', '--clearmodifiers', 'native_atspi_f'])
    wait(lambda: contents('Expanded, loaded nodes only.'))
    wait(lambda: row('native_atspi_fixture').get_state_set().contains(Atspi.StateType.FOCUSED))
    command(['xdotool', 'key', '--clearmodifiers', 'Down', 'Up', 'Escape'])
    wait(lambda: not contents('Expanded, loaded nodes only.'))
    cases['expanded-loaded-speed-search-escape'] = True

    view_options()
    activate('Filter connections and objects'); activate('Apply')
    field = wait(lambda: find('Filter connections and objects', 'EditableText'))
    focus(field)
    if not Atspi.EditableText.set_text_contents(field, 'native_atspi_fixture'):
        raise RuntimeError('Explicit metadata view filter rejected native input')
    wait(lambda: row('native_atspi_fixture') is not None and row('native_atspi_child') is None)
    if not Atspi.EditableText.set_text_contents(field, ''): raise RuntimeError('View filter clear rejected')
    wait(lambda: row('native_atspi_child') is not None)
    view_options()
    activate('Filter connections and objects'); activate('Apply')
    cases['explicit-view-filter-preserves-loaded-objects'] = True

    expand('Routines')
    routines = ['native_function(x integer)', 'native_function(x text)', 'native_procedure()'] if postgres else ['native_function', 'native_procedure']
    for name in routines:
        wait(lambda name=name: row(name), 30)
        context(name, 'Quick Documentation')
        wait(lambda: contents('Quick Documentation'))
        command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
        ddl(name)
    cases['native-routine-types-overloads-ddl'] = True
    view_options()
    activate('Separate procedures and functions'); activate('Apply')
    expand('Functions'); expand('Procedures')
    for name in routines: wait(lambda name=name: row(name), 30)
    if row('Routines') is not None: raise RuntimeError('Routine presentation setting did not regroup actual objects')
    cases['view-options-real-function-procedure-groups'] = True
    if engine != 'MYSQL':
        expand('Sequences')
        ddl('native_sequence')
        wait(lambda: contents('41') and contents('3'))
        # Viewing definitions must never advance the sequence.
        query = "SELECT last_value IS NULL FROM pg_sequences WHERE schemaname='public' AND sequencename='native_sequence'" if postgres else 'SELECT next_not_cached_value FROM busydata.native_sequence'
        if server(query) != ('t' if postgres else '41'):
            raise RuntimeError('Read-only inspection advanced the fixture sequence')
        cases['native-sequence-definition-no-nextval'] = True
    else:
        if row('Sequences') is not None: raise RuntimeError('MySQL advertised sequence objects')
        cases['mysql-no-sequence-category'] = True
    if postgres:
        for name, kind in [('native_partition', 'Partitioned table'), ('native_foreign_table', 'Foreign table')]:
            target = wait(lambda name=name: row(name))
            if kind not in native_name(target): raise RuntimeError('Lost PostgreSQL relation subtype')
        expand('Views')
        target = wait(lambda: row('native_materialized'))
        if 'Materialized view' not in native_name(target): raise RuntimeError('Lost materialized-view subtype')
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, lambda: row('native_materialized'), wait), repeat=2)
        secret = wait(lambda: find('Password', 'EditableText'))
        focus(secret); supply_password(secret); activate('Connect')
        wait(lambda: find('Row 1, n: 漢😀'), 30)
        cases['postgres-relation-subtypes-materialized-data'] = True
    photograph('database-panel-real-object-types')

    # External DDL is fixture setup, not a hidden application command.
    server('CREATE TABLE busydata.native_refresh(id integer);' if not postgres else 'CREATE TABLE public.native_refresh(id integer);')
    context('Tables', 'Refresh')
    wait(lambda: row('native_refresh') and table_count() == known_tables + 1, 30)
    server('ALTER TABLE ' + ('public' if postgres else 'busydata') + '.native_refresh ADD COLUMN external_note text;')
    context('native_refresh', 'Refresh')
    ddl('native_refresh')
    wait(lambda: contents('external_note'), 30)
    server('DROP TABLE ' + ('public' if postgres else 'busydata') + '.native_refresh;')
    context('native_refresh', 'Refresh')
    wait(lambda: row('native_refresh') is None and row('native_atspi_fixture') is not None and table_count() == known_tables, 30)
    cases['targeted-external-create-alter-drop-refresh'] = True

    # A server search can reveal a real object in an unexpanded group.
    if row('Views') is not None and row('Views').get_state_set().contains(Atspi.StateType.EXPANDED):
        select_row('Views')
        command(['xdotool', 'key', '--clearmodifiers', 'Left'])
    context(expected_target, 'Search database objects')
    field = wait(lambda: find('Search database objects', 'EditableText'))
    focus(field)
    if not Atspi.EditableText.set_text_contents(field, 'native_atspi_view'):
        raise RuntimeError('Server object search rejected visible input')
    # The ordinary entry exposes an independently focusable clear action.
    # Traverse it without activation and acknowledge the actual submit button;
    # the search tab and field legitimately share that button's caption.
    for _ in range(3):
        command(['xdotool', 'key', '--clearmodifiers', 'Tab'])
        try:
            wait(lambda: any(native_name(n) == 'Search database objects'
                and n.get_role() == Atspi.Role.PUSH_BUTTON
                and n.get_state_set().contains(Atspi.StateType.FOCUSED) for n in objects(app)), 1)
            break
        except TimeoutError:
            continue
    else:
        raise RuntimeError('Native traversal did not reach the object-search submit button')
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    result = 'busydata/' + ('public/' if postgres else 'busydata/') + 'native_atspi_view'
    activate(result)
    wait(lambda: row('native_atspi_view') and row('native_atspi_view').get_state_set().contains(Atspi.StateType.FOCUSED), 30)
    cases['server-search-unexpanded-exact-reveal'] = True

    known_namespaces = int(server("SELECT count(*) FROM pg_database WHERE datallowconn" if postgres else "SELECT count(*) FROM information_schema.schemata"))
    wait(lambda: source_badge_text() == '1 of ' + str(known_namespaces))
    pointer_at_native_bounds(command, visible_native_bounds(Atspi, source_badge, wait))
    activate('Selected'); activate('Name pattern (regular expression)')
    field = wait(lambda: find('Name pattern (regular expression)', 'EditableText'))
    focus(field)
    if not Atspi.EditableText.set_text_contents(field, '['): raise RuntimeError('Pattern input rejected')
    activate('Apply')
    wait(lambda: contents('The pattern is invalid or exceeds its work limit. The previous selection is retained.'))
    activate('Cancel')
    wait(lambda: source_badge_text() == '1 of ' + str(known_namespaces))
    pointer_at_native_bounds(command, visible_native_bounds(Atspi, source_badge, wait))
    activate('Selected'); activate('Name pattern (regular expression)')
    field = wait(lambda: find('Name pattern (regular expression)', 'EditableText'))
    focus(field)
    if not Atspi.EditableText.set_text_contents(field, '^busydata(_desired)?$'): raise RuntimeError('Corrected pattern input rejected')
    activate('Apply')
    wait(lambda: source_badge_text() == '2 of ' + str(known_namespaces))
    pointer_at_native_bounds(command, visible_native_bounds(Atspi, source_badge, wait))
    activate('Default'); activate('Apply')
    wait(lambda: source_badge_text() == '1 of ' + str(known_namespaces))
    pointer_at_native_bounds(command, visible_native_bounds(Atspi, source_badge, wait))
    activate('Selected'); activate('All Namespaces'); activate('Apply')
    wait(lambda: source_badge_text() == str(known_namespaces) + ' of ' + str(known_namespaces))
    pointer_at_native_bounds(command, visible_native_bounds(Atspi, source_badge, wait))
    activate('Default'); activate('Apply')
    wait(lambda: source_badge_text() == '1 of ' + str(known_namespaces))
    cases['real-namespace-denominator-pattern-rejection-default'] = True

    if postgres:
        choose_namespace('busydata_desired')
        expand('busydata_desired', 'busydata_desired')
        expand('public', 'busydata_desired')
        expand('Tables', 'busydata_desired')
        # The existing diff contract requires the same native name/schema.
        # Collapse inspected groups through their normal controls so both
        # comparison rows fit the same native viewport.
        for group in ('Functions', 'Procedures', 'Views', 'Sequences'):
            item = row(group, 'busydata')
            if item is not None and item.get_state_set().contains(Atspi.StateType.EXPANDED):
                select_row(group, 'busydata')
                command(['xdotool', 'key', '--clearmodifiers', 'Left'])
        focus_live_native_control(Atspi, lambda: row('native_atspi_fixture'), wait)
        command(['xdotool', 'keydown', 'ctrl'])
        try:
            pointer_at_native_bounds(command, visible_native_bounds(Atspi,
                lambda: row('native_atspi_fixture', 'busydata_desired'), wait))
        finally: command(['xdotool', 'keyup', 'ctrl'])
        command(['xdotool', 'key', '--clearmodifiers', 'Menu'])
        activate('Compare structure', menu_only=True)
        wait(lambda: contents('desired_note'), 30)
        cases['two-exact-table-structural-comparison'] = True
        photograph('database-panel-scoped-structural-comparison')

    if postgres:
        choose_namespace('restricted_fixture')
        expand('restricted_fixture', 'restricted_fixture')
        wait(lambda: contents('permission') or contents('Permission') or contents('denied'), 30)
        if row('native_atspi_fixture', 'restricted_fixture') is not None:
            raise RuntimeError('Restricted database displayed another database\'s table')
        cases['restricted-database-scoped-error'] = True
        photograph('database-panel-restricted-database')
    # Existing original console retains its text, output and physical target.
    focus_live_native_control(Atspi, lambda: row(expected_target), wait)
    native_function_key('F10', control=True, shift=True)
    activate(original + ' · busydata / ' + ('public' if postgres else 'busydata'))
    wait(lambda: find('Row 1, n: 漢😀'), 30)
    def current_editor():
        return find_live_control(Atspi, objects(app), 'SQL editor', 'EditableText',
            current_nodes=lambda: objects(app), name_prefix=True)

    def run_original(text, marker):
        editor = wait(current_editor)
        focus(editor)
        if not Atspi.EditableText.set_text_contents(editor, text): raise RuntimeError('Transaction safety input rejected')
        # Run defaults to the caret statement. Explicitly run this authored
        # script so BEGIN/ROLLBACK and its marker execute in the same owner.
        command(['xdotool', 'key', '--clearmodifiers', 'ctrl+shift+Return'])
        wait(lambda: contents('Review details') or find('Row 1, safety_marker: ' + str(marker)), 30)
        if contents('Review details'): activate('Run')
        wait(lambda: find('Row 1, safety_marker: ' + str(marker)), 30)

    run_original('BEGIN; SELECT 8201 AS safety_marker;', 8201)
    wait(lambda: contents('Transaction open'))
    focus_live_native_control(Atspi, lambda: row(expected_target), wait)
    command(['xdotool', 'key', '--clearmodifiers', 'Menu'])
    disabled = wait(lambda: next((n for n in objects(app)
        if native_name(n).startswith('Deactivate source') and n.get_role() == Atspi.Role.MENU_ITEM), None))
    if disabled.get_state_set().contains(Atspi.StateType.ENABLED):
        raise RuntimeError('Source deactivation enabled during its document transaction')
    command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
    run_original('ROLLBACK; SELECT 8202 AS safety_marker;', 8202)
    context(expected_target, 'Deactivate source')
    wait(lambda: contents('Deactivate source'))
    activate('Cancel')
    wait(lambda: find('Row 1, safety_marker: 8202'))
    cases['source-deactivation-transaction-guard-reviewed-cancel'] = True
    run_original('SELECT id,n,8203 AS safety_marker FROM native_atspi_fixture ORDER BY id;', 8203)
    wait(lambda: find('Row 1, n: 漢😀'))
    def reveal_sql(text, token, expected=None):
        editor = wait(current_editor)
        focus(editor)
        if not Atspi.EditableText.set_text_contents(editor, text): raise RuntimeError('SQL reveal input rejected')
        wait(lambda: (field := current_editor()) is not None and Atspi.Text.get_text(field, 0, -1) == text)
        editor = wait(current_editor)
        caret = text.index(token) + 3
        if not Atspi.Text.set_caret_offset(editor, caret): raise RuntimeError('SQL reveal caret rejected')
        wait(lambda: (field := current_editor()) is not None and Atspi.Text.get_caret_offset(field) == caret)
        command(['xdotool', 'key', '--clearmodifiers', 'alt+shift+b'])
        if expected is None:
            wait(lambda: row('native_atspi_fixture') and row('native_atspi_fixture').get_state_set().contains(Atspi.StateType.FOCUSED), 30)
            if row('native_atspi_fixture', 'busydata_desired') is not None and row('native_atspi_fixture', 'busydata_desired').get_state_set().contains(Atspi.StateType.FOCUSED):
                raise RuntimeError('SQL symbol reveal selected the other physical database')
        else:
            wait(lambda: contents(expected), 30)
            editor = wait(current_editor)
            if not editor.get_state_set().contains(Atspi.StateType.FOCUSED): raise RuntimeError('Rejected SQL reference stole editor focus')
        return wait(current_editor)

    original_sql = 'SELECT id,n,8203 AS safety_marker FROM native_atspi_fixture ORDER BY id;'
    reveal_sql(original_sql, 'native_atspi_fixture')
    unavailable = 'No safely resolved persistent object at the caret.'
    reveal_sql("SELECT 'native_atspi_fixture' AS literal_value;", 'native_atspi_fixture', unavailable)
    reveal_sql('SELECT 1; -- native_atspi_fixture', 'native_atspi_fixture', unavailable)
    ambiguous = ('SET search_path TO audit; ' if postgres else 'USE audit; ') + 'SELECT * FROM native_atspi_fixture;'
    editor = reveal_sql(ambiguous, 'native_atspi_fixture', 'Ambiguous SQL object reference.')
    if not Atspi.EditableText.set_text_contents(editor, original_sql): raise RuntimeError('SQL restoration rejected')
    wait(lambda: find('Row 1, safety_marker: 8203') and find('Row 1, n: 漢😀'))
    cases['sql-symbol-exact-scope-literals-comments-ambiguity-no-run'] = True
    if postgres:
        from native_database_explorer_boundaries import verify_namespace_pages
        def restart_tools():
            nonlocal app
            app = restart()
            return app
        verify_namespace_pages(Atspi=Atspi, app=app, objects=objects, find=find,
            wait=wait, focus=focus, activate=activate, command=command,
            photograph=photograph, supply_password=supply_password,
            report=report, cases=cases, row=row, open_menu=context, server=server,
            expected_target=expected_target, original=original, restart=restart_tools,
            native_function_key=native_function_key, current_editor=current_editor)
        from native_database_explorer_races import verify_namespace_races
        verify_namespace_races(Atspi=Atspi, app=app, report=report, cases=cases,
            objects=objects, find=find, wait=wait, focus=focus, activate=activate,
            command=command, photograph=photograph, supply_password=supply_password,
            fixture=fixture, source=source, expected_target=expected_target,
            original=original, native_function_key=native_function_key,
            native_name=native_name, labels=labels, server=server)
    report['databaseExplorerToolsTourPassed'] = len(cases) == (25 if postgres else 16) and all(cases.values())
    focus_live_native_control(Atspi, lambda: find('Row 1, n: 漢😀'), wait)
    return ['Row 1, n: 漢😀']
