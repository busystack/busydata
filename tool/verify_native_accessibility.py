#!/usr/bin/env python3
"""Real Linux AT-SPI/Orca/IBus acceptance of the ordinary native product.
Requires real facilities; missing facilities fail this required stage. All
documents, settings, buses, display, clipboard and speech output are disposable.
"""
import hashlib
import json
import os
import platform
import re
import signal
import socket
from pathlib import Path
import shutil
import secrets
import subprocess
import sys
import tempfile
import time
import uuid
from bounded_process_log import BoundedProcessLog
from application_exception_log import ApplicationLogNames, audit as audit_application_logs, validate as validate_application_logs
from native_runtime_cleanup import remove_native_runtime
from verification_evidence import ROOT, source_hash, digest
from verify_installed_snap import paste_gtk_text, stop
from native_workbench_acceptance import verify as verify_workbench, verify_multicaret, fresh_accessible_objects, accessible_ancestors, native_display_scale, native_catalog_labels, photograph_product, find_live_activation, focus_native_control, native_sql_editor_label, native_sql_editor_announcement, native_ime_composition_active
from native_workbench_acceptance import native_catalog_text
from native_workbench_acceptance import find_live_control
from native_workbench_acceptance import focused_native_action
from native_workbench_acceptance import set_native_inline_text
from native_workbench_acceptance import native_control_absent, find_live_sql_editor, native_startup_editor_state, read_live_native_controls, native_caption_presence, restored_native_sql_editor
from desktop_build_evidence import verify_existing_bundle


def native_report_json(report):
    # Ancestry-rich diagnostics must fit the existing archive receipt budget.
    # Whitespace is dispensable; observations and failure flags are not.
    serialized = json.dumps(report, separators=(',', ':')) + '\n'
    if len(serialized.encode('utf-8')) > 1024 * 1024:
        raise RuntimeError('Native evidence JSON receipt exceeds byte budget')
    return serialized


def stop_database_fixture(identifier, receipt, creation_attempted):
    """Retain ownership when Docker creates a fixture before run times out."""
    if not creation_attempted:
        return False
    recovered = False
    if receipt.is_symlink():
        raise RuntimeError('Owned database fixture identifier receipt is a link')
    if receipt.exists():
        if not receipt.is_file() or receipt.stat().st_size > 65:
            raise RuntimeError('Invalid owned database fixture identifier receipt')
        contents = receipt.read_bytes()
        if re.fullmatch(rb'[0-9a-f]{64}\n?', contents) is None:
            raise RuntimeError('Invalid owned database fixture identifier receipt')
        recorded = contents.decode('ascii').rstrip('\n')
        if identifier is not None and identifier != recorded:
            raise RuntimeError('Owned database fixture identifiers disagree')
        recovered = identifier is None
        identifier = recorded
    if identifier is None:
        raise RuntimeError('Database fixture creation outcome is unavailable')
    if re.fullmatch(r'[0-9a-f]{64}', identifier) is None:
        raise RuntimeError('Invalid owned database fixture identity')
    subprocess.run(['docker', 'stop', identifier], check=True,
                   stdout=subprocess.DEVNULL, timeout=30)
    return recovered


def native_failure_structure(Atspi, nodes, catalog):
    """Bounded structural evidence; never retain accessible text or labels."""
    statuses = {'ok', 'limited', 'unavailable', 'none', 'pending', 'stale',
                'malformed', 'disposed', 'cancelled', 'transport-error'}
    actions = {'focus', 'tap', 'longPress', 'scrollLeft', 'scrollRight',
               'scrollUp', 'scrollDown', 'increase', 'decrease', 'showOnScreen',
               'setSelection', 'setText', 'copy', 'cut', 'paste', 'copyRange', 'cutRange', 'pasteAt',
               'insertText', 'deleteRange', 'moveCursorForwardByCharacter',
               'moveCursorBackwardByCharacter', 'moveCursorForwardByWord',
               'moveCursorBackwardByWord', 'dismiss', 'expand', 'collapse',
               'didGainAccessibilityFocus', 'didLoseAccessibilityFocus'}
    counters = {'busydata-bridge-epoch', 'busydata-owner-epoch', 'busydata-revision',
                'busydata-action-sequence', 'busydata-action-node-id',
                'busydata-action-request-revision', 'busydata-action-reply-revision',
                'busydata-action-bridge-epoch', 'busydata-action-owner-epoch',
                'busydata-action-view-id', 'busydata-action-reply-count',
                'busydata-action-stale-count', 'busydata-action-timeout-count',
                'busydata-action-inflight'}
    limit = 256
    evidence = []
    for node in nodes[:limit]:
        if node.get_role() == Atspi.Role.PASSWORD_TEXT:
            continue
        attributes = node.get_attributes()
        if not isinstance(attributes, dict):
            attributes = {}
        interfaces = list(node.get_interfaces())
        own_root = 'busydata-status' in attributes
        editor = native_sql_editor_label(node.get_name() or '', catalog) is not None
        if not (own_root or editor or 'Text' in interfaces):
            continue
        safe_attributes = {}
        for key, value in attributes.items():
            if not isinstance(value, str):
                continue
            if key in counters and re.fullmatch(r'-?[0-9]{1,20}', value):
                safe_attributes[key] = value
            elif key in ('busydata-status', 'busydata-action-status') and value in statuses:
                safe_attributes[key] = value
            elif key == 'busydata-action-name' and value in actions:
                safe_attributes[key] = value
            elif key == 'busydata-geometry-precision' and value in ('field-bounds', 'glyph-bounds'):
                safe_attributes[key] = value
        states = node.get_state_set()
        evidence.append({
            'category': 'owned-root' if own_root else 'sql-editor' if editor else 'text',
            'role': node.get_role_name(), 'interfaces': interfaces,
            'attributes': safe_attributes,
            'readOnly': states.contains(Atspi.StateType.READ_ONLY),
            'editable': states.contains(Atspi.StateType.EDITABLE),
            'showing': states.contains(Atspi.StateType.SHOWING),
            'focused': states.contains(Atspi.StateType.FOCUSED),
        })
    return {'nodeCount': len(nodes), 'examinedNodeCount': min(len(nodes), limit),
            'nodeLimit': limit, 'scanLimited': len(nodes) > limit, 'nodes': evidence}


def catalog_fixture_rows_match(output):
    expected = ['1\t' + '漢😀'.encode('utf-8').hex(), '2\t' + 'second'.encode('utf-8').hex()]
    return output.strip().lower().splitlines() == expected


def catalog_page_scripts():
    # Four bounded writers, disjoint real identities, no retries. Keep this
    # metadata workload beyond the frontend's 2,048-node budget.
    return tuple(''.join(f'CREATE TABLE busydata.page_{number:04d}(id integer);\n'
                        for number in range(shard, 2305, 4)) for shard in range(4))


def native_report_name(engine, rendering_only=None, platform_case=None, database_explorer=False, database_explorer_local=False, database_explorer_tools=False, connection_management_only=False, ordinary_mysql=False):
    if ordinary_mysql:
        if (engine != 'MYSQL' or rendering_only is not None or platform_case is not None or
                database_explorer or database_explorer_local or database_explorer_tools or connection_management_only):
            raise ValueError('Ordinary MySQL requires its own complete MySQL product scope')
        return 'native-accessibility-mysql-ordinary.json'
    if connection_management_only:
        if engine != 'POSTGRESQL' or rendering_only or platform_case or database_explorer or database_explorer_local or database_explorer_tools:
            raise ValueError('Connection management requires its own PostgreSQL product scope')
        return 'native-connection-management-linux.json'
    if database_explorer_tools:
        if database_explorer or database_explorer_local or rendering_only is not None or platform_case is not None:
            raise ValueError('Object inspection tour requires its own ordinary product scope')
        return 'native-database-explorer-tools-' + engine.lower() + '.json'
    if database_explorer_local:
        if database_explorer or rendering_only is not None or platform_case is not None:
            raise ValueError('Local Explorer tour requires its own ordinary product scope')
        return 'native-database-explorer-local-' + engine.lower() + '.json'
    if database_explorer:
        if rendering_only is not None or platform_case is not None:
            raise ValueError('Database Explorer tour requires the ordinary product')
        return 'native-database-explorer-' + engine.lower() + '.json'
    if platform_case is not None:
        if engine != 'POSTGRESQL' or rendering_only != 'platform':
            raise ValueError('Single-case diagnostics require platform rendering')
        return 'native-platform-diagnostic-linux.json'
    if rendering_only is not None:
        if engine != 'POSTGRESQL' or rendering_only not in ('fluent', 'platform'):
            raise ValueError('Rendering scope requires the PostgreSQL fixture')
        return 'native-rendering-' + rendering_only + '-linux.json'
    return 'native-accessibility-' + ('linux' if engine == 'POSTGRESQL' else engine.lower()) + '.json'


class NativeProgressReport(dict):
    """Retain bounded stage evidence even when a native call hits the deadline."""
    def __init__(self, directory, values):
        super().__init__(values)
        self.directory = directory
        self.started = time.monotonic()
        self['stage'] = values['stage']

    def __setitem__(self, key, value):
        super().__setitem__(key, value)
        if key != 'stage':
            return
        if not isinstance(value, str):
            raise TypeError('Native progress stage must be text')
        # Only control/workflow labels are retained, never form inputs, SQL or
        # the rest of the diagnostic report. The completed report is separate.
        stage = value.encode('utf-8')[:512].decode('utf-8', errors='ignore')
        checkpoint = {
            'version': 1,
            'sourceSha256': self['sourceSha256'],
            'stage': stage,
            'elapsedSeconds': round(time.monotonic() - self.started, 3),
            'stageComplete': False,
        }
        temporary = self.directory / 'progress.json.tmp'
        temporary.write_text(json.dumps(checkpoint, ensure_ascii=False) + '\n')
        os.replace(temporary, self.directory / 'progress.json')


def configure_reader_receipts(data_home):
    """Orca's supported private customization changes diagnostics only.

    Orca opens its diagnostic stream before loading this file. No speech is
    fabricated and no reader behavior or host preferences are changed.
    """
    prefs = data_home / 'orca'
    prefs.mkdir(parents=True, exist_ok=True)
    customization = prefs / 'orca-customizations.py'
    customization.write_text('from orca import debug\n'
        'debug.debugLevel = debug.LEVEL_INFO\n'
        'if debug.debugFile is not None:\n'
        '    debug.debugFile.reconfigure(line_buffering=True, write_through=True)\n'
        '    class _ReaderDiagnostics:\n'
        '        def __init__(self, stream): self.stream = stream\n'
        '        def __getattr__(self, name): return getattr(self.stream, name)\n'
        '        def writelines(self, lines):\n'
        '            message = "".join(lines)\n'
        '            prefix = message.split(" - ", 1)[-1]\n'
        '            if not prefix.startswith(("SPEECH OUTPUT:", "ERROR:", "WARNING:", "FLAT REVIEW PRESENTER: Creating new context.")) and prefix.strip() != "ORCA: Starting Atspi main event loop":\n'
        '                return\n'
        '            self.stream.write(message)\n'
        '    debug.debugFile = _ReaderDiagnostics(debug.debugFile)\n')
    customization.chmod(0o600)
    return customization


def command(argv, **options):
    return subprocess.run(argv, check=True, timeout=10, **options)


def native_speech_ready(socket_path):
    """A socket file can exist before the private SSIP server accepts commands."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as peer:
            peer.settimeout(.25)
            peer.connect(str(socket_path))
            peer.sendall(b'SET SELF CLIENT_NAME busydata:readiness:main\r\n')
            reply = b''
            while b'\r\n' not in reply:
                if len(reply) >= 512:
                    raise RuntimeError('Native speech readiness response budget')
                chunk = peer.recv(512 - len(reply))
                if not chunk:
                    return False
                reply += chunk
            if not reply.startswith(b'208 '):
                raise RuntimeError('Native speech readiness acknowledgement rejected')
            return True
    except (FileNotFoundError, ConnectionRefusedError, ConnectionResetError, socket.timeout):
        return False


def native_reader_ready(path):
    """A live reader process is not acknowledgement of activated key listeners."""
    if not path.is_file():
        return False
    if path.stat().st_size > 4 * 1024 * 1024:
        raise RuntimeError('Native reader diagnostic byte budget')
    return any(line.split(' - ', 1)[-1].strip() ==
               'ORCA: Starting Atspi main event loop'
               for line in path.read_text().splitlines())


def native_speech_contains(log, labels):
    """Keep multiline Orca utterances; field names can contain line breaks."""
    events, current = [], None
    for line in log.splitlines():
        if ' - SPEECH OUTPUT:' in line:
            if current is not None:
                events.append(' '.join(current.split()))
            current = line
        elif re.match(r'^\d{2}:\d{2}:\d{2}\.\d+ - ', line):
            if current is not None:
                events.append(' '.join(current.split()))
                current = None
        elif current is not None:
            current += '\n' + line
    if current is not None:
        events.append(' '.join(current.split()))
    return all(any(' '.join(label.split()) in event for event in events)
               for label in labels)


def native_reader_line_ready(path, after_bytes, text):
    """Require fresh flat-review entry followed by the requested real speech."""
    if not path.is_file():
        return False
    with path.open('rb') as stream:
        data = stream.read(4 * 1024 * 1024 + 1)
    if len(data) > 4 * 1024 * 1024:
        raise RuntimeError('Native reader diagnostic byte budget')
    if not 0 <= after_bytes <= len(data):
        return False
    tail = data[after_bytes:].decode('utf-8', errors='replace')
    entered = re.search(
        r'^\d{2}:\d{2}:\d{2}\.\d+ - FLAT REVIEW PRESENTER: Creating new context\.',
        tail, re.MULTILINE)
    return entered is not None and native_speech_contains(
        tail[entered.start():], ["SPEECH OUTPUT: '" + text + "'"])


def native_request_current_line(path, text, command, wait):
    """Fence the owned reader log before dispatching a real flat-review command."""
    after_bytes = path.stat().st_size
    command(['xdotool', 'key', '--clearmodifiers', 'KP_Up'])
    wait(lambda: native_reader_line_ready(path, after_bytes, text))


def native_wait(predicate, context, reader_log, seconds=15):
    """Continuous native events must not starve acknowledgements or deadlines."""
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        # AT-SPI can keep the context pending while short-lived GTK helpers
        # disappear. Yield back to the actual UI condition after a bounded batch.
        for _ in range(32):
            if not context.pending():
                break
            context.iteration(False)
        value = predicate()
        if value:
            return value
        if reader_log.exists() and reader_log.stat().st_size > 4 * 1024 * 1024:
            raise RuntimeError('Native reader diagnostic byte budget')
        time.sleep(.03)
    raise TimeoutError('Native acceptance condition deadline')


def configure_private_platform_settings(expected, directory, start):
    """Real portal/GSettings on this controller's owned bus and config only."""
    configuration = Path(os.environ['XDG_CONFIG_HOME'])
    if not configuration.is_relative_to(directory):
        raise RuntimeError('Native settings require this case-owned configuration')
    gtk = configuration / 'gtk-3.0'
    gtk.mkdir(parents=True, exist_ok=True)
    (gtk / 'settings.ini').write_text('[Settings]\n'
        'gtk-theme-name=' + expected['gtkTheme'] + '\n'
        'gtk-font-name=Sans 11\n'
        'gtk-enable-animations=' + str(expected['animations']).lower() + '\n')
    settings = [('org.gnome.desktop.interface', 'gtk-theme', expected['gtkTheme']),
        ('org.gnome.desktop.interface', 'color-scheme',
         'prefer-dark' if expected['brightness'] == 'dark' else 'prefer-light'),
        ('org.gnome.desktop.interface', 'text-scaling-factor', str(expected['textScale'])),
        ('org.gnome.desktop.interface', 'enable-animations', str(expected['animations']).lower()),
        ('org.gnome.desktop.a11y.interface', 'high-contrast', str(expected['highContrast']).lower())]
    for schema, key, value in settings:
        command(['gsettings', 'set', schema, key, value])
    portal = configuration / 'xdg-desktop-portal'
    portal.mkdir(parents=True, exist_ok=True)
    (portal / 'portals.conf').write_text('[preferred]\ndefault=gtk\n')
    for executable, service in [('/usr/libexec/xdg-desktop-portal-gtk', 'org.freedesktop.impl.portal.desktop.gtk'),
                                ('/usr/libexec/xdg-desktop-portal', 'org.freedesktop.portal.Desktop')]:
        start([executable], Path(executable).name)
        command(['gdbus', 'wait', '--session', '--timeout', '8', service])
    # Retain actual portal values separately from the desired input. The Dart
    # receipt must still prove they reached the real composed UI.
    actual = command(['gdbus', 'call', '--session', '--dest', 'org.freedesktop.portal.Desktop',
        '--object-path', '/org/freedesktop/portal/desktop', '--method',
        'org.freedesktop.portal.Settings.ReadAll', '["org.gnome.desktop.interface", "org.gnome.desktop.a11y.interface", "org.freedesktop.appearance"]'],
        capture_output=True, text=True).stdout
    if len(actual.encode('utf-8')) > 32768:
        raise RuntimeError('Native portal settings receipt bound')
    (directory / 'portal-settings.txt').write_text(actual)
    return actual


def owned(directory):
    import gi
    gi.require_version('Atspi', '2.0')
    gi.require_version('IBus', '1.0')
    from gi.repository import Atspi, IBus, GLib
    if not os.environ['XDG_RUNTIME_DIR'].startswith('/tmp/bdna-'):
        raise RuntimeError('Owned short native runtime directory required')
    report = NativeProgressReport(directory, {'version': 1, 'exitCode': 1, 'stage': 'startup', 'cleanupConfirmed': False,
              'sourceSha256': source_hash(), 'atSpiVersion': tuple(Atspi.get_version()),
              'controllerPythonVersion': platform.python_version(),
              'readerDiagnosticsIncluded': ['SPEECH OUTPUT:', 'ERROR:', 'WARNING:',
                                           'ORCA: Starting Atspi main event loop']})
    children, logs = [], []
    application_log_names = ApplicationLogNames()

    def start(argv, name):
        if name in ('application', 'application-relaunch'):
            name = application_log_names.claim(name)
        child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        children.append(child)
        logs.append(BoundedProcessLog(child, directory / (name + '.log'), 2 * 1024 * 1024))
        return child

    def wait(predicate, seconds=15):
        return native_wait(predicate, GLib.MainContext.default(),
                           directory / 'orca-debug.log', seconds)

    def objects(application):
        def dispatch_pending_removals():
            context = GLib.MainContext.default()
            for _ in range(32):
                if not context.pending():
                    break
                context.iteration(False)
        return fresh_accessible_objects(application, transient_errors=(GLib.Error,),
            between_attempts=dispatch_pending_removals)

    catalog = native_catalog_labels()

    def sql_editor(application):
        return find_live_sql_editor(Atspi, objects(application), catalog,
            current_nodes=lambda: objects(application))

    def speech_contains(labels, *, after_bytes=0):
        path = directory / 'orca-debug.log'
        if not path.exists() or path.stat().st_size > 4 * 1024 * 1024:
            return False
        data = path.read_bytes()
        if not 0 <= after_bytes <= len(data):
            return False
        return native_speech_contains(data[after_bytes:].decode('utf-8', errors='replace'), labels)

    try:
        command(['dbus-update-activation-environment', 'DISPLAY', 'XAUTHORITY',
                 'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR',
                 'XDG_SESSION_TYPE', 'XDG_CURRENT_DESKTOP', 'GDK_BACKEND', 'GTK_IM_MODULE', 'GIO_USE_VFS'])
        settings_input = os.environ.get('BUSYDATA_NATIVE_SETTINGS_INPUT')
        if settings_input:
            selected = Path(settings_input)
            if selected.stat().st_size > 4096 or selected.parent != directory:
                raise RuntimeError('Private native settings input bound/identity')
            expected = json.loads(selected.read_text())
            configure_private_platform_settings(expected, directory, start)
            report['requestedSettings'] = expected
        config = directory / 'speech-config'
        (config / 'modules').mkdir(parents=True)
        (directory / 'speech-logs').mkdir()
        (config / 'modules/dummy.conf').write_text('')
        (config / 'speechd.conf').write_text('Timeout 0\nAddModule "dummy" "sd_dummy" "dummy.conf"\nDefaultModule "dummy"\nAudioOutputMethod "alsa"\nAudioALSADevice "null"\n')
        socket = str(Path(os.environ['XDG_RUNTIME_DIR']) / 'speechd.sock')
        os.environ['SPEECHD_ADDRESS'] = 'unix_socket:' + socket
        start(['/usr/bin/speech-dispatcher', '--run-single', '--config-dir', str(config),
               '--socket-path', socket, '--pid-file', str(Path(socket).with_suffix('.pid')),
               '--log-dir', str(directory / 'speech-logs')], 'speech')
        report['stage'] = 'speech-dispatcher-readiness'
        wait(lambda: native_speech_ready(Path(socket)))
        report['nativeSpeechDispatcherHandshakeVerified'] = True
        report['stage'] = 'startup'
        start(['/usr/bin/ibus-daemon', '--xim', '--panel=disable', '--emoji-extension=disable',
               '--config=disable', '--cache=none'], 'ibus')
        configure_reader_receipts(Path(os.environ['XDG_DATA_HOME']))
        reader = start(['/usr/bin/orca', '--debug-file', str(directory / 'orca-debug.log')], 'orca')
        # Register the reader's real event listeners before the application
        # creates its accessible window. Reader initialization has its own
        # existing bounded wait; product readiness remains bounded at 30s.
        wait(lambda: native_reader_ready(directory / 'orca-debug.log'))
        report['nativeReaderEventLoopReadyVerified'] = True
        executable = os.environ.get('BUSYDATA_NATIVE_ACCEPTANCE_EXECUTABLE')
        composition_output = os.environ.get('BUSYDATA_NATIVE_COMPOSITION_OUTPUT')
        if settings_input and composition_output:
            raise RuntimeError('Native settings and composition receipts must be separate')
        if composition_output:
            receipt_path = Path(composition_output)
            if receipt_path.parent != directory or not executable:
                raise RuntimeError('Private composition receipt identity')
        if executable and not (settings_input or composition_output):
            raise RuntimeError('Private acceptance executable requires actual settings/composition receipt')
        product = start([executable or str(ROOT / 'build/linux/x64/release/bundle/busydata')], 'application')

        def application():
            if product.poll() is not None:
                raise RuntimeError('Native product exited before readiness')
            if reader.poll() is not None:
                raise RuntimeError('Native reader exited before readiness')
            if not native_reader_ready(directory / 'orca-debug.log'):
                return None
            desktop = Atspi.get_desktop(0)
            for index in range(desktop.get_child_count()):
                candidate = desktop.get_child_at_index(index)
                if candidate.get_process_id() == product.pid and candidate.get_child_count():
                    welcome = native_catalog_labels()
                    query_title = welcome.get('New query', 'New query')
                    if (sql_editor(candidate) is not None or find_live_activation(
                            Atspi, objects(candidate), query_title,
                            current_nodes=lambda: objects(candidate)) is not None):
                        return candidate
            return None

        app = wait(application, 30)
        report['nativeReaderEventLoopReadyVerified'] = True
        if settings_input:
            receipt_path = Path(os.environ['BUSYDATA_NATIVE_SETTINGS_OUTPUT'])
            def applied_settings():
                if not receipt_path.is_file():
                    return None
                if receipt_path.stat().st_size > 8192:
                    raise RuntimeError('Native composed settings receipt bound')
                receipt = json.loads(receipt_path.read_text())
                from native_platform_matrix import validate_composed_settings
                return validate_composed_settings(expected, receipt)
            report['actualComposedSettings'] = wait(applied_settings, 30)
            report['actualComposedSettingsFile'] = {'file': str(receipt_path),
                'sha256': digest(receipt_path), 'bytes': receipt_path.stat().st_size}
        if composition_output:
            def composed():
                if not receipt_path.is_file(): return None
                if receipt_path.stat().st_size > 8192:
                    raise RuntimeError('Native composition receipt byte budget')
                from native_fluent_rendering import validate_composition
                return validate_composition(json.loads(receipt_path.read_text()))
            report['actualComposition'] = wait(composed, 30)
        startup_mode, initial_editor = wait(lambda: native_startup_editor_state(
            Atspi, objects(app), catalog, current_nodes=lambda: objects(app)))
        if startup_mode == 'welcome':
            photograph_product(Atspi, app, objects, wait, command, report, 'first-launch-no-profiles')
            window = command(['xdotool', 'search', '--onlyvisible', '--pid', str(product.pid), '--name', '^BusyData$'], capture_output=True, text=True).stdout.strip()
            command(['xdotool', 'windowfocus', '--sync', window])
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+shift+p'])
            palette_label = native_catalog_labels().get('Search actions…', 'Search actions…')
            def palette_input():
                return find_live_control(Atspi, objects(app), palette_label,
                    interface='EditableText', current_nodes=lambda: objects(app))
            query = wait(palette_input)
            focus_native_control(Atspi, query, wait)
            # Focus can publish a newer native snapshot. Reacquire the settled
            # field and acknowledge its value, not just a queued text action.
            set_native_inline_text(Atspi, palette_input, 'probe', wait,
                                   expected_original='')
            report['nativeStartupSearchProbeValueAcknowledged'] = True
            def native_clear_action():
                field = palette_input()
                if field is None: return None
                rectangles = read_live_native_controls([field],
                    lambda item: Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN),
                    current_nodes=lambda: objects(app))
                if rectangles is None: return None
                rectangle = rectangles[0]
                def candidate(item):
                    state = item.get_state_set()
                    if (item.get_role() != Atspi.Role.PUSH_BUTTON or
                            not state.contains(Atspi.StateType.SHOWING) or
                            not state.contains(Atspi.StateType.SENSITIVE)):
                        return None
                    box = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
                    if not (rectangle.x <= box.x + box.width / 2 <= rectangle.x + rectangle.width and
                            rectangle.y <= box.y + box.height / 2 <= rectangle.y + rectangle.height):
                        return None
                    count = Atspi.Action.get_n_actions(item)
                    if not 0 <= count <= 64: raise RuntimeError('Native search action-count budget')
                    actions = [Atspi.Action.get_action_name(item, index) for index in range(count)]
                    taps = [index for index, action in enumerate(actions) if action in ('tap', 'Tap')]
                    if len(taps) > 1: raise RuntimeError('Ambiguous native search clear action')
                    return (item, taps[0]) if taps else None
                observations = read_live_native_controls(objects(app), candidate,
                    current_nodes=lambda: objects(app))
                if observations is None: return None
                candidates = [value for value in observations if value is not None]
                if len(candidates) > 1: raise RuntimeError('Ambiguous native search clear action')
                return candidates[0] if candidates else None
            clear, action_index = focused_native_action(Atspi, native_clear_action, wait)
            report['nativeSearchClearLabel'] = clear.get_name()
            if not report['nativeSearchClearLabel'] or not Atspi.Action.do_action(clear, action_index):
                raise RuntimeError('Native search clear action rejected')
            def cleared_palette():
                field = palette_input()
                if field is None: return False
                observations = read_live_native_controls([field],
                    lambda item: (Atspi.Text.get_text(item, 0, -1) == '' and
                        item.get_state_set().contains(Atspi.StateType.FOCUSED)),
                    current_nodes=lambda: objects(app))
                return observations is not None and observations[0]
            wait(cleared_palette)
            report['nativeSearchClearActionAndFocusVerified'] = True
            command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
            wait(lambda: native_control_absent(Atspi, objects(app), palette_label, 'EditableText',
                current_nodes=lambda: objects(app)))
            report['nativeStartupCommandPaletteVerified'] = True
            welcome = native_catalog_labels()
            title = welcome.get('New query', 'New query')
            action = wait(lambda: find_live_activation(Atspi, objects(app), title,
                current_nodes=lambda: objects(app)))
            if not Atspi.Action.do_action(action[0], action[1]):
                raise RuntimeError('Native startup New query activation rejected')
            initial_editor = wait(lambda: sql_editor(app))
            report['nativeStartupAndNewQueryVerified'] = True
        focused_manager = os.environ.get('BUSYDATA_NATIVE_CONNECTION_MANAGEMENT_ONLY') == '1'
        report['nativeEditorInputTourIncluded'] = not focused_manager
        restart_product = None
        if not focused_manager:
            editor = initial_editor
            if not {'EditableText', 'Text'}.issubset(editor.get_interfaces()):
                raise RuntimeError('Native editor lacks editable text semantics')
            ancestors = accessible_ancestors(editor)
            report['editorAncestorRoles'] = [item.get_role_name() for item in ancestors]
            report['editorAncestorVisibility'] = []
            for item in ancestors:
                states = item.get_state_set()
                bounds = Atspi.Component.get_extents(item, Atspi.CoordType.WINDOW) if 'Component' in item.get_interfaces() else None
                report['editorAncestorVisibility'].append({
                    'role': item.get_role_name(),
                    'showing': states.contains(Atspi.StateType.SHOWING),
                    'visible': states.contains(Atspi.StateType.VISIBLE),
                    'bounds': [bounds.x, bounds.y, bounds.width, bounds.height] if bounds else None,
                })
            if not any(item.get_role() == Atspi.Role.FRAME for item in ancestors):
                raise RuntimeError('Native editor cannot reach its window frame')
            report['nativeEditorFrameAncestryVerified'] = True
            for item in ancestors:
                states = item.get_state_set()
                if not states.contains(Atspi.StateType.SHOWING) or not states.contains(Atspi.StateType.VISIBLE):
                    raise RuntimeError('Native editor subtree is hidden from reader traversal')
                if item.get_role() == Atspi.Role.FRAME:
                    break
            report['nativeEditorVisibleAncestryVerified'] = True
            report['stage'] = 'geometry'
            bounds = Atspi.Component.get_extents(editor, Atspi.CoordType.WINDOW)
            if min(bounds.x, bounds.y) < 0 or bounds.width < 100 or bounds.height < 30:
                raise RuntimeError('Native editor geometry is unusable')
            report['editorBounds'] = [bounds.x, bounds.y, bounds.width, bounds.height]
            window = command(['xdotool', 'search', '--onlyvisible', '--pid', str(product.pid),
                              '--name', '^BusyData$'], capture_output=True, text=True).stdout.splitlines()
            if len(window) != 1 or not window[0].isdecimal():
                raise RuntimeError('Owned native window identity')
            command(['xdotool', 'windowfocus', '--sync', window[0]])
            if not Atspi.Component.grab_focus(editor):
                raise RuntimeError('Native editor focus action rejected')
            wait(lambda: editor.get_state_set().contains(Atspi.StateType.FOCUSED))
            report['nativeComponentFocusVerified'] = True
            initial_editor_label = native_sql_editor_label(editor.get_name() or '', catalog)
            if initial_editor_label is None:
                raise RuntimeError('Initial native SQL editor lost its document heading')
            editor_heading = initial_editor_label.partition('\n')[0]
            text = lambda: Atspi.Text.get_text(editor, 0, -1)
            if text() != '':
                raise RuntimeError('Isolated editor must start empty')
            report['stage'] = 'ime-connect'
            bus = IBus.Bus.new()
            wait(bus.is_connected)
            engine = next(item.get_name() for item in bus.list_engines() if item.get_name() == 'table:cangjie3')
            if not bus.set_global_engine(engine):
                raise RuntimeError('Owned real IME activation failed')
            report['imeEngine'] = engine
            report['stage'] = 'ime-preedit-cancel'
            command(['xdotool', 'type', '--clearmodifiers', 'a'])
            wait(lambda: text() == '日')
            command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
            wait(lambda: text() == '')
            report['imePreeditCancelled'] = True
            report['stage'] = 'ime-commit'
            command(['xdotool', 'type', '--clearmodifiers', 'a'])
            wait(lambda: text() == '日')
            command(['xdotool', 'key', '--clearmodifiers', 'space'])
            wait(lambda: text() == '日')
            report['imeCommittedExactText'] = True
            report['stage'] = 'ime-reader-current-line'
            editor.clear_cache()
            composition_caption = native_catalog_text('sqlCompositionActive')
            wait(lambda: not native_ime_composition_active(
                editor.get_name() or '', composition_caption))
            from native_workbench_acceptance import native_character_geometry
            glyph = native_character_geometry(Atspi, editor)
            report['nativeTextGlyphGeometry'] = glyph
            report['nativeTextRangeBounds'] = glyph['range']
            # Require the requested flat-review command and its subsequent speech;
            # an earlier automatic IME utterance cannot acknowledge this command.
            native_request_current_line(directory / 'orca-debug.log', '日',
                                        command, wait)
            report['nativeImeCurrentLineReadByOrcaVerified'] = True
            # Resume ordinary editor navigation. The printable keypad-minus
            # toggle can also reach the active IME and mutate this exact fixture.
            report['stage'] = 'unicode-caret'
            command(['xdotool', 'key', '--clearmodifiers', 'Home'])
            wait(lambda: text() == '日' and Atspi.Text.get_caret_offset(editor) == 0)
            paste_gtk_text('😀', lambda: text() == '😀日')
            wait(lambda: text() == '😀日')
            report['unicodeCharacterCount'] = Atspi.Text.get_character_count(editor)
            report['unicodeCaretOffset'] = Atspi.Text.get_caret_offset(editor)
            if report['unicodeCharacterCount'] != 2 or report['unicodeCaretOffset'] != 1:
                raise RuntimeError('Native Unicode caret/count contract')
            report['unicodeCaretVerified'] = True
            report['stage'] = 'unicode-accessible-selection'
            if not Atspi.Text.set_caret_offset(editor, 2):
                raise RuntimeError('Native caret action rejected')
            wait(lambda: Atspi.Text.get_caret_offset(editor) == 2)
            if not Atspi.Text.add_selection(editor, 0, 1):
                raise RuntimeError('Native selection action rejected')
            wait(lambda: Atspi.Text.get_n_selections(editor) == 1)
            selected = Atspi.Text.get_selection(editor, 0)
            if (selected.start_offset, selected.end_offset) != (0, 1) or Atspi.Text.get_text(editor, selected.start_offset, selected.end_offset) != '😀':
                raise RuntimeError('Native Unicode selection contract')
            if not Atspi.Text.set_caret_offset(editor, 1):
                raise RuntimeError('Native collapse selection action rejected')
            wait(lambda: Atspi.Text.get_n_selections(editor) == 0 and Atspi.Text.get_caret_offset(editor) == 1)
            report['unicodeNativeSelectionActionsVerified'] = True
            report['stage'] = 'unicode-native-edit-actions'
            if not Atspi.EditableText.insert_text(editor, 1, '🧪', len('🧪'.encode('utf-8'))):
                raise RuntimeError('Native Unicode insertion action rejected')
            wait(lambda: text() == '😀🧪日' and Atspi.Text.get_caret_offset(editor) == 2)
            if not Atspi.EditableText.delete_text(editor, 0, 1):
                raise RuntimeError('Native Unicode delete action rejected')
            wait(lambda: text() == '🧪日' and Atspi.Text.get_caret_offset(editor) == 0)
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+z'])
            wait(lambda: text() == '😀🧪日')
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+z'])
            wait(lambda: text() == '😀日')
            report['unicodeNativeEditingAndUndoVerified'] = True
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+z'])
            wait(lambda: text() == '日')
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+z'])
            wait(lambda: text() == '')
            report['imeAndPasteUndoRestoredOriginal'] = True
            verify_multicaret(Atspi, editor, wait, command, report)
            if not bus.set_global_engine('xkb:us::eng'):
                raise RuntimeError('Owned keyboard layout restoration failed')
            wait(lambda: bus.get_global_engine().get_name() == 'xkb:us::eng')
            report['nativeImeReturnToKeyboardVerified'] = True
            report['stage'] = 'native-close-dialog'
            if not Atspi.EditableText.set_text_contents(editor, 'SELECT 1;'):
                raise RuntimeError('Native close fixture text action rejected')
            wait(lambda: text() == 'SELECT 1;')
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+w'])
            close_label = native_catalog_labels().get('Close SQL tab', 'Close SQL tab')
            def close_dialog():
                return native_caption_presence(objects(app),
                    lambda caption: caption.startswith(close_label),
                    current_nodes=lambda: objects(app))
            wait(close_dialog)
            report['stage'] = 'native-close-dialog-escape-guard'
            command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
            # BusyMax-derived editor/review modals deliberately keep Escape and
            # outside clicks from dismissing reviewed work. Use the actual Stay
            # control through closed-loop keyboard traversal.
            def focused_stay():
                observations = read_live_native_controls(objects(app),
                    lambda item: item if item.get_name() == native_catalog_labels().get('Stay', 'Stay') and
                        item.get_state_set().contains(Atspi.StateType.FOCUSED) else None,
                    current_nodes=lambda: objects(app))
                if observations is None: return None
                candidates = [item for item in observations if item is not None]
                if len(candidates) > 1: raise RuntimeError('Ambiguous native focused Stay control')
                return candidates[0] if candidates else None
            for _ in range(8):
                command(['xdotool', 'key', '--clearmodifiers', 'Tab'])
                try:
                    if wait(focused_stay, 1):
                        break
                except TimeoutError:
                    continue
            else:
                raise RuntimeError('Native modal keyboard traversal cannot reach Stay')
            if close_dialog() is not True:
                raise RuntimeError('Escape bypassed the native review modal guard')
            report['stage'] = 'native-close-dialog-stay'
            command(['xdotool', 'key', '--clearmodifiers', 'Return'])
            wait(lambda: close_dialog() is False)
            # Blocking modal routes retire background accessibility objects.
            # Rebind once across this explicit boundary, never during IME or
            # edits, and prove the same document/value before its Undo action.
            editor = wait(lambda: restored_native_sql_editor(Atspi, objects(app), catalog,
                editor_heading, 'SELECT 1;', product.pid, current_nodes=lambda: objects(app)))
            if text() != 'SELECT 1;' or product.poll() is not None:
                raise RuntimeError('Native close cancellation lost dirty SQL or the primary application')
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+z'])
            wait(lambda: text() == '')
            report['nativeCloseDialogEscapeGuardStayAndFocusUndoVerified'] = True
            def restart_product():
                nonlocal product, app
                wait(lambda: product.poll() is not None, 30)
                report['nativeNormalWindowCloseAcknowledged'] = True
                product = start([executable or str(ROOT / 'build/linux/x64/release/bundle/busydata')], 'application-relaunch')
                app = wait(application, 30)
                return app

        database_announcements = verify_workbench(Atspi, app, objects, wait, command, report, speech_contains, restart=restart_product, reader_offset=lambda: (directory / 'orca-debug.log').stat().st_size)
        report['stage'] = 'screen-reader'

        def announced():
            return speech_contains(database_announcements if focused_manager else [native_sql_editor_announcement(catalog), "SPEECH OUTPUT: '日", *database_announcements])

        wait(announced)
        if reader.poll() is not None:
            raise RuntimeError('Real screen reader exited')
        report['orcaVersionOutput'] = command(['/usr/bin/orca', '--version'], capture_output=True, text=True).stdout.strip()
        report['ibusVersionOutput'] = command(['/usr/bin/ibus', 'version'], capture_output=True, text=True).stdout.strip()
        report['orcaAnnouncedEditorAndText'] = not focused_manager
        report['orcaAnnouncedActualGridVerified'] = True
        report['orcaAnnouncedActualGridAndPlan'] = (
            os.environ.get('BUSYDATA_NATIVE_FIXTURE_ENGINE', 'POSTGRESQL') == 'POSTGRESQL'
            and os.environ.get('BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER') != '1'
            and os.environ.get('BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER_LOCAL') != '1'
            and os.environ.get('BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER_TOOLS') != '1'
            and os.environ.get('BUSYDATA_NATIVE_CONNECTION_MANAGEMENT_ONLY') != '1')
        report['exitCode'] = 0
        report['stage'] = 'completed'
    except Exception as failure:
        report['failureStage'] = report.get('stage')
        report['failureType'] = type(failure).__name__
        from native_workbench_acceptance import NativeNodeBudgetExceeded
        if isinstance(failure, NativeNodeBudgetExceeded):
            report['nativeFailureNodeBudget'] = {
                'childCount': failure.child_count, 'foundCount': failure.found_count,
                'pendingCount': failure.pending_count, 'limit': failure.limit}
        # Native RPC domains/codes identify disposed-tree or connection errors
        # without retaining exception messages that can contain private text.
        domain, code = getattr(failure, 'domain', None), getattr(failure, 'code', None)
        if isinstance(domain, str) and len(domain) <= 128:
            report['nativeFailureDomain'] = domain
        if isinstance(code, int):
            report['nativeFailureCode'] = code
        # Frame identities diagnose owned fixture failures without exception
        # messages, source lines, values or locals that could contain secrets.
        import traceback
        report['failureFrames'] = [
            {'file': Path(frame.filename).name, 'line': frame.lineno, 'function': frame.name}
            for frame in traceback.extract_tb(failure.__traceback__, limit=32)]
        try:
            report['nativeFailureStructure'] = native_failure_structure(
                Atspi, objects(app), catalog)
        except Exception as diagnostic:
            report['nativeFailureStructureError'] = type(diagnostic).__name__
        if report['stage'] == 'native-object-definition':
            try:
                # Only inspect the disposable fixture's read-only DDL surface.
                # State/extent receipts distinguish visible SelectableText
                # from an editable SQL document without retaining SQL/secrets.
                evidence = []
                for node in objects(app):
                    if node.get_role() == Atspi.Role.PASSWORD_TEXT or 'Text' not in node.get_interfaces():
                        continue
                    count = Atspi.Text.get_character_count(node)
                    if not 0 <= count <= 65536:
                        continue
                    text = Atspi.Text.get_text(node, 0, count)
                    if 'CREATE TABLE' not in text or 'native_atspi_fixture' not in text:
                        continue
                    states = node.get_state_set()
                    box = Atspi.Component.get_extents(node, Atspi.CoordType.SCREEN)
                    evidence.append({'role': node.get_role_name(), 'characters': count,
                        'showing': states.contains(Atspi.StateType.SHOWING),
                        'visible': states.contains(Atspi.StateType.VISIBLE),
                        'editable': states.contains(Atspi.StateType.EDITABLE),
                        'readOnly': states.contains(Atspi.StateType.READ_ONLY),
                        'interfaces': list(node.get_interfaces()),
                        'bounds': [box.x, box.y, box.width, box.height],
                        'sha256': hashlib.sha256(text.encode()).hexdigest()})
                report['nativeDefinitionTextStateEvidence'] = evidence
                photograph_product(Atspi, app, objects, wait, command, report,
                    'object-definition-at-deadline')
            except Exception as diagnostic:
                report['nativeDefinitionCaptureFailureType'] = type(diagnostic).__name__
        try:
            safe_labels = set(native_catalog_labels().values())
            safe_labels.update({'BusyData', 'Search', 'Choose connection',
                                'Native accessibility fixture', 'Connect', 'Run'})
            report['nativeFailureFocusStates'] = [
                {'name': node.get_name() if node.get_name() in safe_labels else '[Interface label omitted]',
                 'role': node.get_role_name(),
                 'interfaces': list(node.get_interfaces()),
                 'editable': node.get_state_set().contains(Atspi.StateType.EDITABLE),
                 'showing': node.get_state_set().contains(Atspi.StateType.SHOWING),
                 'focused': node.get_state_set().contains(Atspi.StateType.FOCUSED)}
                for node in objects(app)
                if node.get_state_set().contains(Atspi.StateType.FOCUSED) or
                   node.get_role() in (Atspi.Role.MENU, Atspi.Role.DIALOG)]
        except Exception as diagnostic:
            report['nativeFailureFocusStatesFailureType'] = type(diagnostic).__name__
        if report['stage'] == 'visible-explorer-new-connection':
            try:
                captions = native_catalog_labels()
                report['nativeManagerFieldVisibility'] = [
                    {'field': label, 'role': node.get_role_name(),
                     'showing': node.get_state_set().contains(Atspi.StateType.SHOWING),
                     'visible': node.get_state_set().contains(Atspi.StateType.VISIBLE),
                     'interfaces': list(node.get_interfaces())}
                    for label in ('Name', 'Host', 'Password')
                    for node in objects(app)
                    if node.get_name() == captions.get(label, label)]
                photograph_product(Atspi, app, objects, wait, command, report,
                    'connection-opening-at-deadline', protected_form=True)
            except Exception as diagnostic:
                report['nativeManagerOpeningCaptureFailureType'] = type(diagnostic).__name__
        if report['stage'] == 'native-action: Test connection':
            try:
                field = next((node for node in objects(app) if
                    node.get_name() == native_catalog_labels().get('Name', 'Name') and
                    'EditableText' in node.get_interfaces()), None)
                if field is not None and Atspi.Text.get_text(field, 0, -1) == 'Native accessibility fixture':
                    photograph_product(Atspi, app, objects, wait, command, report,
                        'connection-feedback-at-deadline', protected_form=True)
                    report['nativeConnectionFeedbackNodes'] = [
                        {'name': (node.get_name() or '')[:256], 'role': node.get_role_name()}
                        for node in objects(app) if 'EditableText' not in node.get_interfaces() and
                        node.get_role() != Atspi.Role.PASSWORD_TEXT and node.get_name()]
            except Exception as diagnostic:
                report['nativeConnectionFeedbackCaptureFailureType'] = type(diagnostic).__name__
        if report['stage'] == 'native-grid-action: Filter':
            try:
                captions = native_catalog_labels()
                filters = [node for node in objects(app)
                    if node.get_name() == captions.get('Filter', 'Filter') and
                    node.get_role() == Atspi.Role.PUSH_BUTTON]
                report['nativeFilterControlStates'] = [
                    {'showing': node.get_state_set().contains(Atspi.StateType.SHOWING),
                     'sensitive': node.get_state_set().contains(Atspi.StateType.SENSITIVE),
                     'visible': node.get_state_set().contains(Atspi.StateType.VISIBLE)}
                    for node in filters]
                if len(filters) == 1 and 'Component' in filters[0].get_interfaces():
                    box = Atspi.Component.get_extents(filters[0], Atspi.CoordType.SCREEN)
                    frame = next((node for node in accessible_ancestors(filters[0])
                        if node.get_role() == Atspi.Role.FRAME), None)
                    if frame is not None:
                        bounds = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
                        if (box.width > 0 and box.height > 0 and box.x >= bounds.x and box.y >= bounds.y
                                and box.x + box.width <= bounds.x + bounds.width
                                and box.y + box.height <= bounds.y + bounds.height):
                            scale = native_display_scale()
                            command(['xdotool','mousemove',str(int((box.x+box.width/2)*scale)),
                                str(int((box.y+box.height/2)*scale))])
                            allowed = {captions.get(label,label): label for label in
                                ('Requires retained data','A document operation is awaiting acknowledgement')}
                            def reason():
                                return next((allowed[node.get_name()] for node in objects(app)
                                    if node.get_name() in allowed),None)
                            try: report['nativeFilterDisabledReason'] = wait(reason,3)
                            except TimeoutError: pass
            except Exception as diagnostic:
                report['nativeFilterDiagnosticsFailureType'] = type(diagnostic).__name__
        if report.get('nativeProfileDialogClosedVerified'):
            # Authored disposable fixture only: names/roles/states diagnose
            # stale AT-SPI nodes without reading credential or text values.
            try:
                report['nativeDeadlineNodes'] = [
                    {'name': (node.get_name() or '')[:128], 'role': node.get_role_name(),
                     'showing': node.get_state_set().contains(Atspi.StateType.SHOWING),
                     'sensitive': node.get_state_set().contains(Atspi.StateType.SENSITIVE),
                     'visible': node.get_state_set().contains(Atspi.StateType.VISIBLE),
                     'focused': node.get_state_set().contains(Atspi.StateType.FOCUSED)}
                    for node in objects(app)]
            except Exception as diagnostic:
                report['nativeDeadlineNodesFailureType'] = type(diagnostic).__name__
            if (report['stage'].startswith('native-grid-action: ') or report['stage'] in ('native-action: Connect', 'native-action: Filter', 'native-action: Apply',
                                   'native-action: Refresh', 'native-visible-grid-refresh', 'native-action: Run', 'native-core-new-query')) and not any(
                    node.get_role() == Atspi.Role.PASSWORD_TEXT for node in objects(app)):
                try:
                    photograph_product(Atspi, app, objects, wait, command, report, 'workflow-at-deadline', resize=False)
                except Exception as diagnostic:
                    report['nativeWorkflowCaptureFailureType'] = type(diagnostic).__name__
        # Capture only the authored editor or explicitly selected disposable
        # cell fixture. Pixels distinguish stale AT-SPI state from the actual
        # ordinary product. Never capture credential entry or user contents.
        authored_editor_failure = report['stage'] == 'native-multicaret-undo-original-input'
        authored_cell_failure = (report['stage'] == 'native-action: Close' and
            report.get('nativeGridFocusAndKeyboardSelectionVerified') and
            not report.get('nativeGridValueInspectionDialogVerified'))
        authored_palette_failure = (report['stage'] == 'native-palette-open: Connect' and
            report.get('nativeProfileDialogClosedVerified') and
            not any(node.get_role() == Atspi.Role.PASSWORD_TEXT for node in objects(app)))
        authored_administration_failure = (report['stage'] == 'native-action: Sessions and locks' and
            report.get('nativeProfileInputsAndExplicitSessionOnlyConnectVerified') and
            not any(node.get_role() == Atspi.Role.PASSWORD_TEXT for node in objects(app)))
        if authored_editor_failure or authored_cell_failure or authored_palette_failure or authored_administration_failure:
            try:
                gi.require_version('Gdk', '3.0')
                from gi.repository import Gdk
                Gdk.init([])
                window = Gdk.get_default_root_window()
                width, height = window.get_width(), window.get_height()
                if width < 1 or height < 1 or width * height > 2 * 1024 * 1024:
                    raise RuntimeError('Owned diagnostic pixel budget')
                picture = Gdk.pixbuf_get_from_window(window, 0, 0, width, height)
                path = directory / ('authored-administration-failure.png' if authored_administration_failure else 'authored-editor-undo-failure.png' if authored_editor_failure else 'authored-cell-dialog-failure.png')
                picture.savev(str(path), 'png', [], [])
                path.chmod(0o600)
                report['authoredEditorFailureImage' if authored_editor_failure else 'authoredCellDialogFailureImage'] = {
                    'file': str(path), 'sha256': digest(path),
                    'bytes': path.stat().st_size, 'width': width, 'height': height,
                }
            except Exception as diagnostic:
                report['authoredEditorImageFailureType'] = type(diagnostic).__name__
    finally:
        for child in reversed(children):
            stop(child)
        report['logs'] = [log.finish() for log in logs]
        for item in report['logs']:
            item['sha256'] = digest(Path(item['file']))
        report['applicationExceptionCheck'] = audit_application_logs(
            report['logs'], report['sourceSha256'], directory)
        if not report['applicationExceptionCheck']['passed']:
            report['exitCode'] = 1
        reader_log = directory / 'orca-debug.log'
        if reader_log.is_file():
            report['readerLog'] = {'file': str(reader_log), 'sha256': digest(reader_log),
                                   'bytes': reader_log.stat().st_size}
            if report['readerLog']['bytes'] > 4 * 1024 * 1024:
                report['exitCode'] = 1
        report['cleanupConfirmed'] = all(child.poll() is not None for child in children)
        if not report['cleanupConfirmed'] or any(not log['complete'] for log in report['logs']):
            report['exitCode'] = 1
        (directory / 'report.json').write_text(native_report_json(report))
    return report['exitCode']


def main():
    if len(sys.argv) == 3 and sys.argv[1] == '--owned-session':
        return owned(Path(sys.argv[2]))
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--engine', choices=('POSTGRESQL', 'MYSQL', 'MARIADB'), default='POSTGRESQL')
    parser.add_argument('--ordinary-mysql', action='store_true', help='Use ordinary MySQL defaults and a fresh caching_sha2_password account; enter only General for the first connection.')
    parser.add_argument('--connection-management', action='store_true',
        help='Additionally verify global application-menu creation and live SQL-form reconnect with the existing PostgreSQL fixture.')
    parser.add_argument('--connection-management-only', action='store_true',
        help='Run the existing connection-management workflow independently; retains the 600-second deadline and never certifies the complete native workbench gate.')
    parser.add_argument('--database-explorer', action='store_true',
        help='Run the ordinary two-database Explorer/data/DDL/category-console tour; does not certify the longer native editing/export or platform matrix gates.')
    parser.add_argument('--database-explorer-local', action='store_true',
        help='Run ordinary local virtual-view, source-folder and disconnected recovery controls; independent of other native gates.')
    parser.add_argument('--database-explorer-tools', action='store_true',
        help='Run ordinary object types, exact reveal, search, scoped refresh and comparison controls; independent of other native gates.')
    parser.add_argument('--rendering-only', choices=('fluent', 'platform'),
        help='Rerun a supplementary composition; never records ordinary-workflow acceptance.')
    from native_platform_matrix import CASES
    parser.add_argument('--platform-case', choices=tuple(case['name'] for case in CASES),
        help='Diagnose one existing platform case; does not certify the complete nine-case matrix.')
    args = parser.parse_args()
    if args.connection_management_only:
        if args.rendering_only or args.platform_case:
            parser.error('Connection management is an independent ordinary-product scope')
        args.connection_management = True
    engine = args.engine
    if args.ordinary_mysql and (engine != 'MYSQL' or args.rendering_only is not None or args.platform_case is not None or
            args.database_explorer or args.database_explorer_local or args.database_explorer_tools or args.connection_management_only):
        parser.error('Ordinary MySQL requires its own complete MySQL product scope')
    if args.connection_management and engine != 'POSTGRESQL':
        parser.error('Connection-management coverage requires the PostgreSQL fixture')
    if args.database_explorer and (args.rendering_only or args.connection_management):
        parser.error('Database Explorer tour is an independent ordinary-product scope')
    if args.database_explorer_local and (args.database_explorer or args.rendering_only or args.connection_management):
        parser.error('Local Explorer tour is an independent ordinary-product scope')
    if args.database_explorer_tools and (args.database_explorer or args.database_explorer_local or args.rendering_only or args.connection_management):
        parser.error('Object inspection tour is an independent ordinary-product scope')
    if args.rendering_only and engine != 'POSTGRESQL':
        parser.error('Supplementary rendering uses the PostgreSQL fixture')
    if args.platform_case and args.rendering_only != 'platform':
        parser.error('--platform-case requires --rendering-only platform')
    postgres = engine == 'POSTGRESQL'
    image = {'POSTGRESQL': 'postgres:17.11', 'MYSQL': 'mysql:8.4.10', 'MARIADB': 'mariadb:11.8.9'}[engine]
    port = '5432' if postgres else '3306'
    source = source_hash()
    build = json.loads((ROOT / 'build/linux-release-build.json').read_text())
    bundle_hashes = verify_existing_bundle('linux', build, ROOT / 'build/linux/x64/release/bundle', source)
    directory = ROOT / 'build/native-accessibility' / str(uuid.uuid4())
    directory.mkdir(parents=True)
    # Unix socket paths must stay short even when the test runner uses a long
    # task-owned TMPDIR. This directory is new, private and exclusively ours.
    runtime = Path(tempfile.mkdtemp(prefix='bdna-', dir='/tmp'))
    environment = dict(os.environ, XDG_RUNTIME_DIR=str(runtime),
        XDG_DATA_HOME=str(directory / 'data'), XDG_CONFIG_HOME=str(directory / 'config'),
        # IBus also binds its private socket beneath XDG_CACHE_HOME. Keep that
        # path short independently of the retained evidence directory.
        XDG_CACHE_HOME=str(runtime / 'cache'), XDG_SESSION_TYPE='x11',
        XDG_CURRENT_DESKTOP='BusyDataAcceptance', GDK_BACKEND='x11', GTK_IM_MODULE='ibus',
        GIO_USE_VFS='local', GTK_MODULES='gail:atk-bridge')
    environment.pop('NO_AT_BRIDGE', None)
    if args.platform_case or args.database_explorer_local or args.database_explorer_tools:
        environment['G_MESSAGES_DEBUG'] = 'BusyDataNativeMenu'
    if args.ordinary_mysql:
        environment['BUSYDATA_NATIVE_ORDINARY_MYSQL']='1'
    if args.connection_management:
        environment['BUSYDATA_NATIVE_VERIFY_CONNECTION_MANAGEMENT'] = '1'
    if args.connection_management_only:
        environment['BUSYDATA_NATIVE_CONNECTION_MANAGEMENT_ONLY'] = '1'
    if args.database_explorer:
        environment['BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER'] = '1'
    if args.database_explorer_local:
        environment['BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER_LOCAL'] = '1'
    if args.database_explorer_tools:
        environment['BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER_TOOLS'] = '1'
    manager_edges = os.environ.get('BUSYDATA_NATIVE_VERIFY_MANAGER_EDGES') == '1'
    if manager_edges and (not postgres or args.rendering_only):
        parser.error('Manager-edge acceptance uses the ordinary PostgreSQL workflow')
    report = {'version': 1, 'exitCode': 1, 'stage': 'controller-start',
              'sourceSha256': source, 'cleanupConfirmed': False}
    controller = log = fixture = ssh_fixture = ssh_log = None
    fixture_receipt = directory / 'database-fixture.cid'
    fixture_creation_attempted = False
    catalog_fixture = {'configuredPageTables': 2305, 'serverMemoryLimitBytes': 256 * 1024 * 1024} if args.database_explorer else None
    ordinary_mysql_cache_bytes = None
    ordinary_mysql_metadata_privilege = None
    fixture_memory_limit_bytes = None
    try:
        fixture_directory = directory / 'private-fixture'
        fixture_directory.mkdir(mode=0o700)
        if manager_edges:
            ssh_directory = fixture_directory / 'ssh-editor'
            ssh_directory.mkdir(mode=0o700)
            (ssh_directory / 'password').write_text(secrets.token_hex(24))
            (ssh_directory / 'password').chmod(0o600)
            classpath_file = ROOT / 'backend/target/native-editor-classpath.txt'
            subprocess.run([str(ROOT / 'backend/mvnw'), '-f', str(ROOT / 'backend/pom.xml'),
                'test-compile', 'dependency:build-classpath', '-Dmdep.includeScope=test',
                '-Dmdep.outputFile=target/native-editor-classpath.txt'], check=True,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=180)
            classpath = os.pathsep.join([str(ROOT / 'backend/target/test-classes'),
                str(ROOT / 'backend/target/classes'), classpath_file.read_text().strip()])
            ssh_fixture = subprocess.Popen([str(Path(os.environ['JAVA_HOME']) / 'bin/java'),
                '-cp', classpath, 'io.busystack.busydata.NativeSshEditorFixture', str(ssh_directory)],
                stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            ssh_log = BoundedProcessLog(ssh_fixture, directory / 'ssh-fixture.log', 256 * 1024)
            deadline = time.monotonic() + 15
            while not (ssh_directory / 'endpoint.json').is_file():
                if ssh_fixture.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('Disposable SSH editor endpoint did not start')
                time.sleep(.05)
        password = fixture_directory / 'password'
        password.write_text(secrets.token_hex(24))
        password.chmod(0o600)
        schema = fixture_directory / 'fixture.sql'
        schema.write_text(("CREATE TABLE native_atspi_fixture(id integer PRIMARY KEY,n text);\n"
                          "INSERT INTO native_atspi_fixture VALUES(1,'漢😀'),(2,'second');\n"
                          "CREATE TABLE native_atspi_child(id integer PRIMARY KEY, parent_id integer REFERENCES native_atspi_fixture(id), observed timestamp(6), body text); INSERT INTO native_atspi_child VALUES(1,1,'2026-10-24 13:14:15.123456',REPEAT('漢',30000));\n"
                          "CREATE SCHEMA audit; CREATE TABLE audit.native_atspi_fixture(id integer PRIMARY KEY,n text);\n"
                          "INSERT INTO audit.native_atspi_fixture VALUES(1,'other schema'); CREATE VIEW native_atspi_view AS SELECT id,n FROM native_atspi_fixture;\n"
                          "CREATE DATABASE busydata_desired;\n"
                          "\\connect busydata_desired\n"
                          "CREATE TABLE native_atspi_fixture(id integer PRIMARY KEY,n text, desired_note text);\n"
                          "INSERT INTO native_atspi_fixture VALUES(1,'second physical database','secondary only');\n"
                          "CREATE TABLE native_atspi_child(id integer PRIMARY KEY, parent_id integer REFERENCES native_atspi_fixture(id), observed timestamp(6), body text);\n") if postgres else
                          "SET NAMES utf8mb4; USE busydata; CREATE TABLE native_atspi_fixture(id integer PRIMARY KEY,n text);\n"
                          "INSERT INTO native_atspi_fixture VALUES(1,'漢😀'),(2,'second');\n"
                          "CREATE TABLE native_atspi_child(id integer PRIMARY KEY,parent_id integer,observed timestamp(6),body longtext,FOREIGN KEY(parent_id) REFERENCES native_atspi_fixture(id)); INSERT INTO native_atspi_child VALUES(1,1,'2026-10-24 13:14:15.123456',REPEAT('漢',30000));\n"
                          "CREATE DATABASE audit; CREATE TABLE audit.native_atspi_fixture(id integer PRIMARY KEY,n text);\n"
                          "INSERT INTO audit.native_atspi_fixture VALUES(1,'other catalog');\n"
                          "CREATE VIEW native_atspi_view AS SELECT id,n FROM native_atspi_fixture;\n"
                          "CREATE DATABASE busydata_desired; CREATE TABLE busydata_desired.native_atspi_fixture(id integer PRIMARY KEY,n text,desired_note text);\n"
                          "INSERT INTO busydata_desired.native_atspi_fixture VALUES(1,'second physical database','secondary only');\n")
        if args.database_explorer_tools:
            from native_database_explorer_tools import object_fixture_sql
            with schema.open('a') as target:
                target.write(object_fixture_sql(engine))
        if args.database_explorer:
            # This independent tour owns the large catalog. The complete core
            # editing/export tour keeps its original small disposable fixture.
            select_primary = "\\connect busydata\n" if postgres else "USE busydata;\n"
            select_secondary = "\\connect busydata_desired\n" if postgres else "USE busydata_desired;\n"
            with schema.open('a') as target:
                target.write(select_secondary + "CREATE TABLE customers(id integer PRIMARY KEY,n text,desired_note text); INSERT INTO customers VALUES(1,'second physical database','secondary only');\n")
                target.write(select_primary + "CREATE TABLE customers(id integer PRIMARY KEY,n text); INSERT INTO customers VALUES(1,'漢😀');\n")
                if postgres:
                    for number in range(2305):
                        target.write(f"CREATE TABLE page_{number:04d}(id integer);\n")
        if args.database_explorer_tools and postgres:
            # The bootstrap superuser cannot be demoted. Give the visible app
            # its own ordinary login before creating its owned fixture objects.
            body = schema.read_text()
            schema.write_text("DO $$ BEGIN EXECUTE format('CREATE ROLE busydata LOGIN CREATEDB PASSWORD %L', pg_read_file('/tmp/fixture-password')); END $$;\n"
                "ALTER DATABASE busydata OWNER TO busydata;\n"
                "\\connect busydata busydata\n" + body)
        # The image reads this individual bind mount as its database user.
        # Keep the containing fixture directory and credentials private.
        schema.chmod(0o644)
        subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-days', '2',
            '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost,IP:127.0.0.1',
            '-keyout', str(fixture_directory / 'server.key'), '-out', str(fixture_directory / 'ca.crt')],
            check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
        (fixture_directory / 'server.key').chmod(0o600)
        database_environment = ['-e', 'POSTGRES_USER=busydata', '-e', 'POSTGRES_DB=busydata',
            '-e', 'POSTGRES_PASSWORD_FILE=/run/busydata-password'] if postgres else [
            '-e', ('MYSQL' if engine == 'MYSQL' else 'MARIADB') + '_DATABASE=busydata',
            '-e', ('MYSQL' if engine == 'MYSQL' else 'MARIADB') + '_ROOT_PASSWORD_FILE=/run/busydata-password']
        if args.ordinary_mysql:
            database_environment += ['-e','MYSQL_USER=busydata','-e','MYSQL_PASSWORD_FILE=/run/busydata-password']
        if args.database_explorer_tools and postgres:
            database_environment[1] = 'POSTGRES_USER=fixture_owner'
        startup = ('install -m 600 -o postgres -g postgres /fixture/server.key /tmp/server.key; '
            'install -m 644 -o postgres -g postgres /fixture/ca.crt /tmp/server.crt; '
            'exec docker-entrypoint.sh postgres -c ssl=on -c ssl_cert_file=/tmp/server.crt -c ssl_key_file=/tmp/server.key') if postgres else (
            'install -m 600 -o mysql -g mysql /fixture/server.key /tmp/server.key; '
            'install -m 644 -o mysql -g mysql /fixture/ca.crt /tmp/server.crt; '
            'exec docker-entrypoint.sh ' + ('mysqld' if engine == 'MYSQL' else 'mariadbd') +
            ' --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci '
            '--ssl-ca=/tmp/server.crt --ssl-cert=/tmp/server.crt --ssl-key=/tmp/server.key')
        if args.database_explorer_tools and postgres:
            startup = 'install -m 600 -o postgres -g postgres /run/busydata-password /tmp/fixture-password; ' + startup
        if args.ordinary_mysql:
            startup='exec docker-entrypoint.sh mysqld --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci'
        if engine == 'MYSQL' and (args.database_explorer or args.ordinary_mysql):
            # Keep the fixture's InnoDB cache explicit and small. Ordinary
            # MySQL retains its default TLS/authentication and instrumentation.
            # Ordinary connection still uses default server TLS/authentication
            # and General-only client settings. No product/workload cap changes.
            startup += ' --innodb-buffer-pool-size=32M'
            if catalog_fixture is not None:
                catalog_fixture['configuredInnoDBBufferPoolBytes'] = 32 * 1024 * 1024
        report['stage'] = 'fixture-start'
        # MySQL's default server is designed for approximately 512 MiB. Its
        # ordinary authentication/connection tour must not run in a 256 MiB
        # container that can die after readiness. This is disposable server
        # provisioning, separate from the unchanged measured application cap.
        fixture_memory_mib = 512 if args.ordinary_mysql else 256
        fixture_creation_attempted = True
        fixture = subprocess.run(['docker', 'run', '--rm', '-d',
            '--cidfile', str(fixture_receipt),
            '--memory=' + str(fixture_memory_mib) + 'm', '--cpus=1',
            '--label', 'io.busystack.busydata.acceptance=native-accessibility',
            *database_environment,
            '--mount', f'type=bind,src={password},dst=/run/busydata-password,readonly',
            '--mount', f'type=bind,src={schema},dst=/docker-entrypoint-initdb.d/fixture.sql,readonly',
            '--mount', f'type=bind,src={fixture_directory},dst=/fixture,readonly',
            '-p', '127.0.0.1::' + port, image, 'bash', '-ec', startup], check=True,
            capture_output=True, text=True, timeout=60).stdout.strip()
        if len(fixture) != 64 or any(c not in '0123456789abcdef' for c in fixture):
            raise RuntimeError('Invalid owned database fixture identity')
        observed_memory = subprocess.run(['docker', 'inspect', '--format',
            '{{.HostConfig.Memory}}', fixture], check=True,
            capture_output=True, text=True, timeout=10).stdout.strip()
        if observed_memory != str(fixture_memory_mib * 1024 * 1024):
            raise RuntimeError('Owned database fixture memory limit differs from admission')
        fixture_memory_limit_bytes = int(observed_memory)
        deadline = time.monotonic() + (45 if postgres else 180)
        report['stage'] = 'fixture-readiness'
        ready = ['psql','-h','127.0.0.1','-U','busydata','-d','busydata','-Atq','-c',"SELECT count(*) FROM native_atspi_fixture"] if postgres else [
            'mysql' if engine == 'MYSQL' else 'mariadb', '--connect-timeout=2', '--default-character-set=utf8mb4', '-h', '127.0.0.1', '-u', 'root', '-D', 'busydata', '-N', '-B',
            '-e', 'SELECT id,HEX(n) FROM native_atspi_fixture ORDER BY id']
        if args.database_explorer and postgres:
            catalog_ready = "SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name LIKE 'page_%'"
            ready = ['psql','-h','127.0.0.1','-U','busydata','-d','busydata','-Atq','-c',catalog_ready]
        readiness_environment = dict(os.environ, MYSQL_PWD=password.read_text(), PGPASSWORD=password.read_text())
        while True:
            checked = subprocess.run(['docker', 'exec', *(['-e','PGPASSWORD'] if postgres else ['-e', 'MYSQL_PWD']), fixture, *ready],
                             env=readiness_environment, capture_output=True, text=True, timeout=5)
            if checked.returncode == 0 and (checked.stdout.strip() == '2305' if args.database_explorer and postgres else checked.stdout.strip() == '2' if postgres else catalog_fixture_rows_match(checked.stdout)):
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('Owned database readiness deadline')
            time.sleep(.2)
        if args.database_explorer:
            if not postgres:
                from concurrent.futures import ThreadPoolExecutor, as_completed
                report['stage'] = 'fixture-large-catalog'
                catalog_fixture['parallelDdlClients'] = 4
                started = time.monotonic()
                def create_pages(script):
                    remaining = deadline - time.monotonic()
                    if remaining <= 0: raise RuntimeError('Owned database preparation deadline')
                    subprocess.run(['docker','exec','-i','-e','MYSQL_PWD',fixture,
                        'mysql' if engine == 'MYSQL' else 'mariadb','--connect-timeout=2',
                        '-h','127.0.0.1','-u','root','-D','busydata','-N','-B'],
                        input=script, env=readiness_environment, capture_output=True,
                        text=True, check=True, timeout=remaining)
                with ThreadPoolExecutor(max_workers=4) as writers:
                    pending = [writers.submit(create_pages, script) for script in catalog_page_scripts()]
                    for completed in as_completed(pending, timeout=max(.1, deadline-time.monotonic())):
                        completed.result()
                count = subprocess.run(['docker','exec','-e','MYSQL_PWD',fixture,
                    'mysql' if engine == 'MYSQL' else 'mariadb','--connect-timeout=2',
                    '-h','127.0.0.1','-u','root','-N','-B','-e',
                    "SELECT count(*) FROM information_schema.tables WHERE table_schema='busydata' AND table_name LIKE 'page_%'"],
                    env=readiness_environment, capture_output=True, text=True, check=True,
                    timeout=max(.1,min(5,deadline-time.monotonic()))).stdout.strip()
                if count != '2305' or time.monotonic() >= deadline:
                    raise RuntimeError('Large catalog fixture is incomplete or late')
                catalog_fixture['observedPageTables'] = int(count)
                catalog_fixture['preparationSeconds'] = time.monotonic() - started
            else:
                catalog_fixture['observedPageTables'] = int(checked.stdout.strip())
            if engine == 'MYSQL':
                observed = subprocess.run(['docker','exec','-e','MYSQL_PWD',fixture,'mysql','--connect-timeout=2','-h','127.0.0.1','-u','root','-N','-B','-e','SELECT @@innodb_buffer_pool_size'], env=readiness_environment, capture_output=True, text=True, check=True, timeout=max(.1,min(10,deadline-time.monotonic()))).stdout.strip()
                catalog_fixture['observedInnoDBBufferPoolBytes'] = int(observed)
                if catalog_fixture['observedInnoDBBufferPoolBytes'] != 32 * 1024 * 1024:
                    raise RuntimeError('Large MySQL fixture cache configuration differs')
        if args.ordinary_mysql:
            observed=subprocess.run(['docker','exec','-e','MYSQL_PWD',fixture,'mysql','-u','root','-N','-B','-e',"SELECT VERSION(); SELECT plugin FROM mysql.user WHERE user='busydata' AND host='%'; SELECT @@innodb_buffer_pool_size;"],env=readiness_environment,capture_output=True,text=True,check=True,timeout=10).stdout.splitlines()
            if len(observed)!=3 or observed[1]!='caching_sha2_password': raise RuntimeError('Ordinary fresh MySQL account authentication was not established')
            ordinary_mysql_cache_bytes = int(observed[2])
            if ordinary_mysql_cache_bytes != 32 * 1024 * 1024:
                raise RuntimeError('Ordinary MySQL fixture cache configuration differs')
            # Disposable administrator setup only. Native table/column identity
            # requires PROCESS; database-level grants alone cannot prove it.
            # Do not authenticate as busydata here: its first GUI connection
            # must still exercise a fresh caching_sha2_password account.
            granted = subprocess.run(['docker', 'exec', '-e', 'MYSQL_PWD', fixture,
                'mysql', '--connect-timeout=2', '-u', 'root', '-N', '-B', '-e',
                "GRANT PROCESS ON *.* TO 'busydata'@'%'; SELECT COUNT(*) FROM information_schema.USER_PRIVILEGES WHERE GRANTEE = CONCAT(CHAR(39),'busydata',CHAR(39),'@',CHAR(39),'%',CHAR(39)) AND PRIVILEGE_TYPE = 'PROCESS';"],
                env=readiness_environment, capture_output=True, text=True, check=True, timeout=10)
            if granted.stdout.strip() != '1':
                raise RuntimeError('Ordinary MySQL fixture native-identity privilege was not established')
            ordinary_mysql_metadata_privilege = {
                'privilege': 'PROCESS', 'account': 'busydata@%',
                'disposableAdministratorProvisioned': True,
                'verifiedWithoutAccountAuthentication': True,
                'productGrantsPrivileges': False}
            environment['BUSYDATA_NATIVE_ORDINARY_MYSQL_SERVER_VERSION']=observed[0]
        report['stage'] = 'fixture-endpoint'
        endpoint = subprocess.run(['docker', 'port', fixture, port + '/tcp'], check=True,
            capture_output=True, text=True, timeout=5).stdout.strip()
        if not endpoint.startswith('127.0.0.1:') or not endpoint.rsplit(':', 1)[1].isdecimal():
            raise RuntimeError('Owned loopback fixture endpoint')
        environment['BUSYDATA_NATIVE_FIXTURE_DIRECTORY'] = str(fixture_directory)
        environment['BUSYDATA_NATIVE_FIXTURE_PORT'] = endpoint.rsplit(':', 1)[1]
        environment['BUSYDATA_NATIVE_FIXTURE_ID'] = fixture
        environment['BUSYDATA_NATIVE_FIXTURE_ENGINE'] = engine
        report['fixtureImage'] = image
        report['ordinaryMySqlConfiguration'] = bool(args.ordinary_mysql)
        if args.rendering_only is not None:
            report.update(scope=args.rendering_only + '-rendering-only', ordinaryWorkflowMeasured=False,
                buildId=build['buildId'], artifactHashes=bundle_hashes, fixtureEngine=engine)
            report['stage'] = 'native-rendering-' + args.rendering_only
            if args.rendering_only == 'fluent':
                from native_fluent_rendering import verify as render
                result_key = 'fluentRendering'
            else:
                from native_platform_matrix import verify as render
                result_key = 'platformMatrix'
            report[result_key] = render(source, build, directory, environment,
                **({'case_name': args.platform_case} if args.platform_case else {}))
            if args.platform_case:
                report['scope'] = 'single-case-diagnostic'
                report['platformCase'] = args.platform_case
            report['sourceUnchanged'] = source_hash() == source
            report['exitCode'] = 0 if report[result_key]['passed'] and report['sourceUnchanged'] else 1
        else:
            report['stage'] = 'native-controller'
            # The supplementary 25-case tools tour includes repeated restarts,
            # paged namespace editing and catalog locks. Each UI transition keeps
            # its existing deadline; the ordinary required tour keeps 600s.
            controller_seconds = 1800 if args.database_explorer_tools else 600
            report['controllerTimeoutSeconds'] = controller_seconds
            report['buildId'] = build['buildId']
            report['artifactHashes'] = bundle_hashes
            controller = subprocess.Popen(['xvfb-run', '-a', '-s', '-screen 0 1920x1080x24 -noreset',
                '/usr/bin/dbus-run-session', '--', '/usr/bin/python3', str(Path(__file__).resolve()),
                '--owned-session', str(directory)], env=environment, stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT, start_new_session=True)
            log = BoundedProcessLog(controller, directory / 'controller.log', 2 * 1024 * 1024)
            controller.wait(timeout=controller_seconds)
            report = json.loads((directory / 'report.json').read_text())
            validate_application_logs(report, source, directory=directory)
            report['buildId'] = build['buildId']
            report['artifactHashes'] = bundle_hashes
            report['nativeExecutableSha256'] = digest(ROOT / 'build/linux/x64/release/bundle/busydata')
            report['sourceUnchanged'] = source_hash() == source
            if controller.returncode or not report['sourceUnchanged']:
                report['exitCode'] = 1
            report['fixtureImage'] = image
            report['fixtureEngine'] = engine
            if args.ordinary_mysql:
                report['ordinaryMySqlConfiguration']={'serverVersion':environment['BUSYDATA_NATIVE_ORDINARY_MYSQL_SERVER_VERSION'],'startupSslOverrides':False,'freshAccount':True,'authentication':'caching_sha2_password','generalOnlyFirstConnection':True,'serverMemoryLimitBytes':fixture_memory_limit_bytes,'configuredInnoDBBufferPoolBytes':32*1024*1024,'observedInnoDBBufferPoolBytes':ordinary_mysql_cache_bytes}
            report['fixtureStoredUtf8RowsVerified'] = not postgres
            if args.connection_management_only:
                report['scope'] = 'ordinary-connection-management-tour'
                report['completeNativeWorkflowGate'] = False
                if report.get('nativeConnectionManagementVerified', {}).get('passed') is not True:
                    report['exitCode'] = 1
                if manager_edges and report.get('nativeSshEditorAndEmptyManagerVerified', {}).get('passed') is not True:
                    report['exitCode'] = 1
            elif args.database_explorer or args.database_explorer_local or args.database_explorer_tools:
                report['scope'] = 'ordinary-database-explorer-tools-tour' if args.database_explorer_tools else 'ordinary-database-explorer-local-tour' if args.database_explorer_local else 'ordinary-database-explorer-two-database-tour'
                report['completeNativeWorkflowGate'] = False
                if report.get('databaseExplorerToolsTourPassed' if args.database_explorer_tools else 'databaseExplorerLocalTourPassed' if args.database_explorer_local else 'databaseExplorerTourPassed') is not True:
                    report['exitCode'] = 1
            elif report.get('exitCode') == 0:
                core = ('nativeConnectionTestCorrectionVerified', 'nativeConnectionTestCancellationRetryVerified', 'nativeFirstRunAcquisitionAndExactSubmissionVerified',
                        'nativeTableDoubleClickOwnedDataVerified', 'nativeObjectIndexesWithoutDataQueryVerified', 'nativeObjectDefinitionVerified',
                        'nativeValidatedTableSortFilterResetVerified', 'nativeCancelledReviewRetainsPendingCellVerified',
                        'nativeIndependentCommittedRowCheckVerified', 'nativeInlineOwnedEditReviewApplyAndCommitVerified',
                        'nativeGridExactSelectedServerCellClipboardVerified')
                if not all(report.get(key) is True for key in core):
                    raise RuntimeError('Ordinary database core workflow evidence is incomplete')
                from native_result_editor_acceptance import validate as validate_result_editor
                validate_result_editor(report.get('nativeP0ResultEditorVerified'))
                if postgres:
                    if (report.get('nativeVisibleIndependentConsolesAndFocusVerified', {}).get('distinctSessions') is not True or
                            not report.get('nativeSqlSaveReopenTargetWithoutExecutionVerified', {}).get('sha256') or
                            not report.get('nativeVisibleRetainedExportWithoutExecutionVerified', {}).get('sha256') or
                            report.get('nativeWmDeleteCancelAndSqlOriginRestoredVerified') is not True or
                            report.get('nativeNormalRelaunchDisconnectedAndDeliberateReconnectVerified') is not True or
                            report.get('nativeRecoveredTableResumesThroughOwnedAcquisitionVerified') is not True):
                        raise RuntimeError('Continuous PostgreSQL export/recovery workflow evidence is incomplete')
                    if args.connection_management and report.get('nativeConnectionManagementVerified', {}).get('passed') is not True:
                        raise RuntimeError('Connection-management workflow evidence is incomplete')
                    if manager_edges and report.get('nativeSshEditorAndEmptyManagerVerified', {}).get('passed') is not True:
                        raise RuntimeError('SSH-editor and source-deletion workflow evidence is incomplete')
                    report['gateAOrdinaryPostgresqlWorkflowPassed'] = True
                elif (report.get('nativeCatalogEngineCoreVerified') is not True or
                      not report.get('nativeVisibleRetainedExportVerified', {}).get('sha256')):
                    raise RuntimeError('Ordinary catalog-engine export workflow evidence is incomplete')
            if report.get('exitCode') == 0 and postgres and not (args.database_explorer or args.database_explorer_local or args.database_explorer_tools or args.connection_management_only):
                from native_fluent_rendering import REQUIRED, verify as verify_fluent_rendering
                if not all(report.get(key) is True for key in REQUIRED):
                    raise RuntimeError('Extended ordinary native workflow evidence is incomplete')
                report['fluentRendering'] = verify_fluent_rendering(source, build, directory, environment)
                if not report['fluentRendering']['passed']:
                    report['exitCode'] = 1
            if report.get('gateAOrdinaryPostgresqlWorkflowPassed') is True:
                from native_platform_matrix import verify as verify_platform_matrix
                layout_environment = dict(environment)
                layout_environment.pop('BUSYDATA_NATIVE_VERIFY_CONNECTION_MANAGEMENT', None)
                layout_environment.pop('BUSYDATA_NATIVE_VERIFY_MANAGER_EDGES', None)
                report['platformMatrix'] = verify_platform_matrix(source, build, directory, layout_environment)
                if not report['platformMatrix']['passed']:
                    report['exitCode'] = 1
    except BaseException as failure:
        report['exitCode'] = 1
        report['failureType'] = type(failure).__name__
        if isinstance(failure, subprocess.TimeoutExpired):
            report['stage'] = 'native-controller-deadline'
            progress = directory / 'progress.json'
            if progress.is_file() and progress.stat().st_size <= 4096:
                checkpoint = json.loads(progress.read_text())
                if checkpoint.get('sourceSha256') == source:
                    report['lastNativeCheckpoint'] = checkpoint
                    report['lastNativeCheckpointFile'] = {'file': str(progress),
                        'sha256': digest(progress), 'bytes': progress.stat().st_size}
    finally:
        if ordinary_mysql_metadata_privilege is not None:
            report['ordinaryMySqlMetadataPrivilege'] = ordinary_mysql_metadata_privilege
        if fixture_memory_limit_bytes is not None:
            report['databaseFixtureMemoryLimitBytes'] = fixture_memory_limit_bytes
        if catalog_fixture is not None:
            report['largeCatalogFixture'] = catalog_fixture
        if controller is not None and controller.poll() is None:
            os.killpg(controller.pid, signal.SIGTERM)
            try:
                controller.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(controller.pid, signal.SIGKILL)
                controller.wait(timeout=5)
        if log is not None:
            report['controllerLog'] = log.finish()
            report['controllerLog']['sha256'] = digest(Path(report['controllerLog']['file']))
            if not report['controllerLog']['complete']:
                report['exitCode'] = 1
        if ssh_fixture is not None:
            metrics = directory / 'private-fixture/ssh-editor/metrics.json'
            if metrics.is_file():
                report['sshFixtureFinalMetrics'] = json.loads(metrics.read_text())
            try:
                ssh_fixture.stdin.close()
                ssh_fixture.wait(timeout=10)
                report['sshFixtureCleanupConfirmed'] = ssh_fixture.returncode == 0
            except Exception:
                ssh_fixture.kill()
                ssh_fixture.wait(timeout=5)
                report['sshFixtureCleanupConfirmed'] = False
            if not report['sshFixtureCleanupConfirmed']:
                report['exitCode'] = 1
        if ssh_log is not None:
            report['sshFixtureLog'] = ssh_log.finish()
        ssh_secret_path = directory / 'private-fixture/ssh-editor/password'
        if ssh_secret_path.is_file():
            secret = ssh_secret_path.read_bytes()
            candidates = [directory / 'ssh-fixture.log', directory / 'controller.log',
                directory / 'orca-debug.log', directory / 'report.json',
                *(directory / (name + '.log') for name in ('application', 'orca', 'ibus', 'speech'))]
            report['sshCredentialAbsentFromDiagnostics'] = all(
                not path.exists() or (path.stat().st_size <= 4 * 1024 * 1024 and
                    secret not in path.read_bytes()) for path in candidates)
            if not report['sshCredentialAbsentFromDiagnostics']:
                report['exitCode'] = 1
            shutil.rmtree(ssh_secret_path.parent)
        # Inspect only bounded test diagnostics; never record the secret or
        # package private fixture files with the public evidence.
        password_path = directory / 'private-fixture/password'
        if password_path.is_file():
            secret = password_path.read_bytes()
            candidates = [directory / 'controller.log', directory / 'orca-debug.log', directory / 'report.json',
                          *(directory / (name + '.log') for name in ('application', 'orca', 'ibus', 'speech'))]
            report['fixtureCredentialAbsentFromDiagnostics'] = all(
                not path.exists() or (path.stat().st_size <= 4 * 1024 * 1024 and
                                     secret not in path.read_bytes()) for path in candidates)
            if not report['fixtureCredentialAbsentFromDiagnostics']:
                report['exitCode'] = 1
        try:
            report['databaseFixtureIdentifierRecovered'] = stop_database_fixture(
                fixture, fixture_receipt, fixture_creation_attempted)
            report['databaseFixtureCleanupConfirmed'] = True
        except Exception as cleanup:
            report['databaseFixtureCleanupConfirmed'] = False
            report['databaseFixtureCleanupFailureType'] = type(cleanup).__name__
            report['exitCode'] = 1
        try:
            remove_native_runtime(runtime)
            if args.rendering_only is not None:
                result_key = 'fluentRendering' if args.rendering_only == 'fluent' else 'platformMatrix'
                rendering_path = Path(report.get(result_key, {}).get('file', ''))
                rendering = json.loads(rendering_path.read_text()) if rendering_path.is_file() else {}
                cases = rendering.get('cases', [])
                report['cleanupConfirmed'] = rendering.get('cleanupConfirmed') is True or bool(cases) and all(
                    case.get('cleanupConfirmed') is True for case in cases)
        except OSError as cleanup:
            report['cleanupFailureType'] = type(cleanup).__name__
            report['cleanupFailureErrno'] = cleanup.errno
            report['cleanupConfirmed'] = False
            report['exitCode'] = 1
        (directory / 'report.json').write_text(native_report_json(report))
        shutil.copy2(directory / 'report.json', ROOT / 'build' / native_report_name(engine, args.rendering_only, args.platform_case, args.database_explorer, args.database_explorer_local, args.database_explorer_tools, args.connection_management_only, ordinary_mysql=args.ordinary_mysql))
        print(directory / 'report.json')
    return report['exitCode']


if __name__ == '__main__':
    raise SystemExit(main())
