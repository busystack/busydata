"""Ordinary PostgreSQL namespace and delayed-metadata interaction checks."""
from contextlib import contextmanager
import os
import re
import selectors
import subprocess


@contextmanager
def hold_fixture_catalog(fixture, wait, evidence):
    """Delay genuine metadata reads in database A, without affecting database B."""
    process = subprocess.Popen(['docker', 'exec', '-i', fixture, 'psql', '-X', '-qAt',
        '-v', 'ON_ERROR_STOP=1', '-U', 'fixture_owner', '-d', 'busydata'],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=0)
    selector = selectors.DefaultSelector()
    selector.register(process.stdout, selectors.EVENT_READ)
    observed = bytearray()
    try:
        process.stdin.write(b"SET idle_in_transaction_session_timeout='30s'; BEGIN; LOCK TABLE pg_catalog.pg_class IN ACCESS EXCLUSIVE MODE; SELECT 'busydata-catalog-lock:'||pg_backend_pid();\n")
        process.stdin.flush()
        def acquired():
            if selector.select(0):
                observed.extend(os.read(process.stdout.fileno(), 512))
                if len(observed) > 4096: raise RuntimeError('Fixture lock acknowledgement budget')
            found = re.search(rb'(?m)^busydata-catalog-lock:([0-9]+)\r?$', observed)
            if found: return int(found.group(1))
            if process.poll() is not None: raise RuntimeError('Fixture catalog lock not acknowledged')
            return None
        evidence['fixtureOwnerPid'] = wait(acquired, 10)
        evidence['acquired'] = True
        yield
    finally:
        selector.close()
        try:
            if process.poll() is None:
                process.communicate(b'ROLLBACK;\n\\q\n', timeout=10)
            if process.returncode != 0: raise RuntimeError('Fixture catalog lock release failed')
            evidence['released'] = True
        finally:
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=3)


def blocked_fixture_metadata(fixture, locker_pid):
    # The observation runs in B: A's pg_class lock must not stall this check.
    response = subprocess.run(['docker', 'exec', fixture, 'psql', '-X', '-qAt',
        '-v', 'ON_ERROR_STOP=1', '-U', 'fixture_owner', '-d', 'busydata_desired', '-c',
        "SELECT count(*) FROM pg_locks WHERE NOT granted AND " + str(int(locker_pid)) + "=ANY(pg_blocking_pids(pid))"],
        check=True, capture_output=True, text=True, timeout=5)
    return response.stdout.strip().isdigit() and int(response.stdout.strip()) > 0


def verify_namespace_races(*, Atspi, app, report, cases, objects, find, wait, focus,
        activate, command, photograph, supply_password, fixture, source, expected_target,
        original, native_function_key, native_name, labels, server):
    from native_workbench_acceptance import (accessible_ancestors, find_native_tree_row,
        find_live_control, focus_live_native_control, focus_visible_native_field,
        native_tab_name, pointer_at_native_bounds, visible_native_bounds,
        bounded_native_text, find_selected_object_document)

    def row(name, catalog='busydata', schema=None, owner=expected_target):
        nodes = objects(app)
        if name != owner:
            target = re.escape(catalog) + (r' / ' + re.escape(schema) if schema else r'(?: / [^·]+)?')
            scope = re.compile(r' · ' + target + r' · ')
            nodes = [n for n in nodes if ' · ' + owner + ' · ' in native_name(n) and scope.search(native_name(n))]
        try:
            return find_native_tree_row(Atspi, nodes, labels, name)
        except RuntimeError as error:
            if str(error) != 'Ambiguous native Explorer row': raise
            # A live semantics update is not an atomic D-Bus snapshot. Never
            # activate one of its duplicate rows; wait for a unique owner.
            report['nativeNamespaceTransientAmbiguity'] = [native_name(n) for n in nodes
                if native_name(n).startswith(name + ' · level ')][:8]
            return None

    def context(name, action, **scope):
        focus_live_native_control(Atspi, lambda: row(name, **scope), wait)
        command(['xdotool', 'key', '--clearmodifiers', 'Menu'])
        activate(action, menu_only=True)

    def expand(name, **scope):
        focus_live_native_control(Atspi, lambda: row(name, **scope), wait)
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])

    def editor():
        return find_live_control(Atspi, objects(app), 'SQL editor', 'EditableText',
            current_nodes=lambda: objects(app), name_prefix=True)

    def selected_query():
        return next((re.match(r'Query [0-9]+', native_tab_name(native_name(n))).group()
            for n in objects(app) if native_tab_name(native_name(n)).startswith('Query ')
            and n.get_state_set().contains(Atspi.StateType.SELECTED)), None)

    def execute(text, marker, allow_credentials=True):
        field = wait(editor); focus(field)
        if not Atspi.EditableText.set_text_contents(field, text): raise RuntimeError('Namespace console input rejected')
        wait(lambda: Atspi.Text.get_text(wait(editor), 0, -1) == text)
        activate('Run')
        def review():
            return any(native_name(n) == 'Review details' and n.get_role() == Atspi.Role.HEADING for n in objects(app))
        done = lambda: find('Row 1, safety_marker: ' + str(marker))
        wait(lambda: find('Password', 'EditableText') or review() or done(), 30)
        if find('Password', 'EditableText'):
            if not allow_credentials: raise RuntimeError('Metadata display change disconnected the existing console')
            field = wait(lambda: find('Password', 'EditableText')); focus(field)
            supply_password(field); activate('Connect')
        wait(lambda: review() or done(), 30)
        if review(): activate('Run')
        wait(done, 30)

    def badge(name, **scope):
        owner = row(name, **scope)
        if owner is None: return None
        return next((n for n in objects(app) if re.fullmatch(r'[0-9]+ of [1-9][0-9]*', native_name(n))
            and owner in accessible_ancestors(n) and n.get_state_set().contains(Atspi.StateType.SHOWING)), None)

    def select_namespace(name, choice, count, **scope):
        focus_live_native_control(Atspi, lambda: row(name, **scope), wait)
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, lambda: badge(name, **scope), wait))
        if choice == 'All':
            activate('Selected'); activate('All Namespaces')
        else: activate(choice)
        activate('Apply')
        wait(lambda: (n := badge(name, **scope)) is not None and native_name(n) == count, 30)

    def console(owner, name, catalog='busydata', schema='public'):
        focus_live_native_control(Atspi, lambda: row(owner, owner=owner), wait)
        native_function_key('F10', control=True, shift=True)
        activate(name + ' · ' + catalog + ' / ' + schema)
        wait(editor)

    known_databases = int(server('SELECT count(*) FROM pg_database WHERE datallowconn'))
    schema_counts = {catalog: int(server('SELECT count(*) FROM pg_namespace', catalog=catalog))
        for catalog in ('busydata', 'busydata_desired')}
    select_namespace(expected_target, 'Default', '1 of ' + str(known_databases))
    expand('busydata')
    for catalog in ('busydata', 'busydata_desired'):
        if catalog != 'busydata':
            select_namespace(expected_target, catalog, '2 of ' + str(known_databases))
            expand(catalog, catalog=catalog)
        select_namespace(catalog, 'audit', '2 of ' + str(schema_counts[catalog]), catalog=catalog)
        expand('audit', catalog=catalog, schema='audit')
        expand('Tables', catalog=catalog, schema='audit')
        pointer_at_native_bounds(command, visible_native_bounds(Atspi,
            lambda: row('native_atspi_fixture', catalog=catalog, schema='audit'), wait), repeat=2)
        expected = 'other schema' if catalog == 'busydata' else 'other schema second database'
        wait(lambda: find('Password', 'EditableText') or find('Row 1, n: ' + expected), 30)
        if find('Password', 'EditableText'):
            field = wait(lambda: find('Password', 'EditableText')); focus(field)
            supply_password(field); activate('Connect')
        wait(lambda: find('Row 1, n: ' + expected), 30)
        photograph('database-panel-audit-data-' + catalog)
        if catalog != 'busydata':
            context('native_atspi_fixture', 'Open definition', catalog=catalog, schema='audit')
            def exact_definition():
                for n in objects(app):
                    value = bounded_native_text(Atspi, n)
                    if 'CREATE TABLE' in value and '"audit"' in value and 'audit_note' in value: return True
                return False
            wait(exact_definition, 30)
            photograph('database-panel-audit-ddl-second-database')
        # The established close lifecycle reviews owned data sessions. Accept
        # that visible review; a modal's hidden background is not a closed tab.
        for _ in range(2 if catalog != 'busydata' else 1):
            def selected_inspection():
                return find_selected_object_document(Atspi, objects(app), 'native_atspi_fixture', native_name)
            closing = wait(selected_inspection)
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+w'])
            close_choices = ('Close native_atspi_fixture', 'Close native_atspi_fixture — Structure')
            wait(lambda: any(find(label) for label in close_choices) or
                row(expected_target) is not None and selected_inspection() != closing)
            for label in close_choices:
                if find(label):
                    activate(label)
                    break
            wait(lambda: row(expected_target) is not None and selected_inspection() != closing, 30)
            if find('Row 1, n: ' + expected) is None: break
        wait(lambda: find('Row 1, n: ' + expected) is None)

    context('Tables', 'New query', schema='audit')
    audit_query = wait(selected_query)
    audit_sql = 'SELECT n,current_database() AS namespace_database,current_schema() AS namespace_schema,pg_backend_pid() AS namespace_pid,8302 AS safety_marker FROM native_atspi_fixture;'
    execute(audit_sql, 8302)
    wait(lambda: find('Row 1, n: other schema') and find('Row 1, namespace_schema: audit'))
    pid = wait(lambda: next((re.fullmatch(r'Row 1, namespace_pid: ([0-9]+)', native_name(n)).group(1)
        for n in objects(app) if re.fullmatch(r'Row 1, namespace_pid: ([0-9]+)', native_name(n))), None))
    select_namespace('busydata', 'Default', '1 of ' + str(schema_counts['busydata']))
    console(expected_target, audit_query, schema='audit')
    execute(audit_sql.replace('8302', '8303'), 8303, allow_credentials=False)
    wait(lambda: find('Row 1, namespace_pid: ' + pid) and find('Row 1, namespace_schema: audit') and find('Row 1, n: other schema'))
    cases['two-database-audit-schema-data-ddl-selection-does-not-retarget-console'] = True
    photograph('database-panel-schema-selection-independent-console')

    # Duplicate/edit through the existing manager; no profile or session enters
    # application test state. B points at a different physical database.
    other = 'Delayed metadata target'
    focus_live_native_control(Atspi, lambda: row(expected_target), wait)
    command(['xdotool', 'key', '--clearmodifiers', 'Left'])
    context(expected_target, 'Duplicate connection')
    for label, value in [('Name', other), ('Database', 'busydata_desired')]:
        field = focus_visible_native_field(Atspi, lambda: find(label, 'EditableText'), wait)
        if not Atspi.EditableText.set_text_contents(field, value): raise RuntimeError('Source properties input rejected')
        wait(lambda: Atspi.Text.get_text(find(label, 'EditableText'), 0, -1) == value)
    field = focus_visible_native_field(Atspi, lambda: find('Password', 'EditableText'), wait)
    supply_password(field)
    activate('Save & connect'); wait(lambda: find('Name', 'EditableText') is None, 30)
    other_query = wait(selected_query)
    other_sql = 'SELECT n,current_database() AS namespace_database,pg_backend_pid() AS namespace_pid,8304 AS safety_marker FROM native_atspi_fixture;'
    execute(other_sql, 8304)
    wait(lambda: find('Row 1, n: second physical database') and find('Row 1, namespace_database: busydata_desired'))
    other_pid = wait(lambda: next((re.fullmatch(r'Row 1, namespace_pid: ([0-9]+)', native_name(n)).group(1)
        for n in objects(app) if re.fullmatch(r'Row 1, namespace_pid: ([0-9]+)', native_name(n))), None))
    for name, schema in [('busydata_desired', None), ('public', 'public'), ('Tables', 'public')]:
        expand(name, catalog='busydata_desired', schema=schema, owner=other)
    wait(lambda: row('native_atspi_fixture', catalog='busydata_desired', schema='public', owner=other))

    server('CREATE SCHEMA late_audit; CREATE TABLE late_audit.race_a_only(id integer);')
    server('CREATE TABLE public.race_b_only(id integer);', catalog='busydata_desired')
    # Reopen discovery through its normal selector so the newly created schema
    # is selected but has never been expanded or introspected.
    schema_count = int(server('SELECT count(*) FROM pg_namespace'))
    expand(expected_target)
    context('busydata', 'Refresh')
    wait(lambda: (n := badge('busydata')) is not None and native_name(n) == '1 of ' + str(schema_count), 30)
    select_namespace('busydata', 'late_audit', '2 of ' + str(schema_count))
    delay = report['nativeDelayedMetadataFixture'] = {}
    with hold_fixture_catalog(fixture, wait, delay):
        expand('late_audit', schema='late_audit')
        wait(lambda: row('late_audit', schema='late_audit') is not None and
            'Loading' in native_name(row('late_audit', schema='late_audit')))
        wait(lambda: blocked_fixture_metadata(fixture, delay['fixtureOwnerPid']), 5)
        delay['serverObservedBlockedMetadata'] = True
        context('Tables', 'Refresh', catalog='busydata_desired', schema='public', owner=other)
        wait(lambda: row('race_b_only', catalog='busydata_desired', schema='public', owner=other), 10)
        context(expected_target, 'Deactivate source')
        wait(lambda: find('Deactivate source'))
        activate('Deactivate source')
        wait(lambda: row(expected_target) is not None and 'Explorer disconnected' in native_name(row(expected_target)), 10)
        delay['sourceDeactivatedBeforeRelease'] = True
    def no_old_database_connections():
        value = subprocess.run(['docker', 'exec', fixture, 'psql', '-X', '-qAt',
            '-U', 'fixture_owner', '-d', 'busydata_desired', '-c',
            "SELECT count(*) FROM pg_stat_activity WHERE datname='busydata' AND usename='busydata'"],
            check=True, capture_output=True, text=True, timeout=5).stdout.strip()
        return value == '0'
    wait(no_old_database_connections, 10)
    delay['oldDatabaseConnectionsClosed'] = True
    focus_live_native_control(Atspi, lambda: row(other, owner=other), wait)
    wait(lambda: row('race_b_only', catalog='busydata_desired', schema='public', owner=other))
    if row('race_a_only', catalog='busydata_desired', schema='public', owner=other) is not None:
        raise RuntimeError('Delayed metadata populated the other source')
    console(other, other_query, catalog='busydata_desired')
    wait(lambda: find('Row 1, safety_marker: 8304') and find('Row 1, n: second physical database'))
    execute(other_sql.replace('8304', '8305'), 8305, allow_credentials=False)
    wait(lambda: find('Row 1, namespace_pid: ' + other_pid) and find('Row 1, namespace_database: busydata_desired'))
    delay['healthyConsoleRetainedPhysicalConnection'] = True
    cases['real-delayed-metadata-switch-refresh-deactivate-preserves-other-source'] = True
    photograph('database-panel-delayed-metadata-other-source')
    console(expected_target, original)
    wait(lambda: find('Row 1, safety_marker: 8203') and find('Row 1, n: 漢😀'))
