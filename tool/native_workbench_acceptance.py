"""Drive real native database controls; only disposable fixture values are used."""
import os
import re
import json
import hashlib
import math
import time
from collections import deque
from functools import lru_cache
from pathlib import Path
import subprocess

APPLICATION_MENU_PARENTS = {'Edit': 'SQL execution', 'Run options': 'SQL execution',
                            'Connection': 'Database', 'Object': 'Database'}
APPLICATION_MENU_CATEGORIES = ('Documents', 'SQL execution', 'Database', 'View',
                               *APPLICATION_MENU_PARENTS)

def owned_product_window(command, wait, process_id):
    """Await this application's mapped window without admitting another process."""
    def visible():
        try:
            reply = command(['xdotool', 'search', '--all', '--onlyvisible', '--pid', str(process_id),
                             '--name', '^BusyData$'], capture_output=True, text=True)
        except subprocess.CalledProcessError as error:
            if error.returncode == 1:
                return None
            raise
        windows = reply.stdout.splitlines()
        if len(windows) > 1:
            main = []
            for xid in windows:
                if not xid.isdecimal() or len(xid) > 20:
                    raise RuntimeError('Invalid owned native window identity')
                properties = command(['xprop', '-id', xid, '_NET_WM_WINDOW_TYPE'],
                                     capture_output=True, text=True).stdout
                if len(properties) > 1024:
                    raise RuntimeError('Native window-type response budget')
                types = set(re.findall(r'_NET_WM_WINDOW_TYPE_[A-Z_]+', properties))
                if types == {'_NET_WM_WINDOW_TYPE_NORMAL'}:
                    main.append(xid)
                elif not types:
                    information = command(['xwininfo', '-id', xid],
                        capture_output=True, text=True).stdout
                    if len(information) > 4096 or not re.search(r'^\s*Class: InputOnly\s*$', information, re.MULTILINE):
                        raise RuntimeError('Exactly one owned ordinary product window is required')
                elif not types <= {'_NET_WM_WINDOW_TYPE_DROPDOWN_MENU',
                                   '_NET_WM_WINDOW_TYPE_POPUP_MENU', '_NET_WM_WINDOW_TYPE_TOOLTIP'}:
                    raise RuntimeError('Exactly one owned ordinary product window is required')
            if len(main) != 1:
                raise RuntimeError('Exactly one owned ordinary product window is required')
            return main[0]
        return windows[0] if windows else None
    return wait(visible)


def request_owned_x11_window_close(command, window, process_id):
    """Send one advertised ICCCM WM_DELETE_WINDOW to the current owned window."""
    import ctypes
    if (not isinstance(window, str) or not window.isdecimal() or not 0 < int(window) < 2 ** 32 or
            type(process_id) is not int or not 0 < process_id < 2 ** 31):
        raise ValueError('Invalid owned X11 close identity')
    actual_pid = command(['xdotool', 'getwindowpid', window], capture_output=True,
                         text=True).stdout.strip()
    if actual_pid != str(process_id):
        raise RuntimeError('Native close window belongs to another process')
    class Data(ctypes.Union):
        _fields_ = [('b', ctypes.c_char * 20), ('s', ctypes.c_short * 10), ('l', ctypes.c_long * 5)]
    class ClientMessage(ctypes.Structure):
        _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong), ('send_event', ctypes.c_int),
            ('display', ctypes.c_void_p), ('window', ctypes.c_ulong),
            ('message_type', ctypes.c_ulong), ('format', ctypes.c_int), ('data', Data)]
    class Event(ctypes.Union):
        _fields_ = [('client', ClientMessage), ('pad', ctypes.c_long * 24)]
    x11 = ctypes.CDLL('libX11.so.6')
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XGetWMProtocols.argtypes = [ctypes.c_void_p, ctypes.c_ulong,
        ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)), ctypes.POINTER(ctypes.c_int)]
    x11.XGetWMProtocols.restype = ctypes.c_int
    x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
        ctypes.c_long, ctypes.POINTER(Event)]
    x11.XSendEvent.restype = ctypes.c_int
    x11.XFree.argtypes = [ctypes.c_void_p]
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError('Owned native close X display unavailable')
    try:
        protocol = x11.XInternAtom(display, b'WM_PROTOCOLS', True)
        delete = x11.XInternAtom(display, b'WM_DELETE_WINDOW', True)
        if not protocol or not delete:
            raise RuntimeError('Advertised native close protocol unavailable')
        protocols, count = ctypes.POINTER(ctypes.c_ulong)(), ctypes.c_int()
        try:
            if (not x11.XGetWMProtocols(display, int(window), ctypes.byref(protocols), ctypes.byref(count)) or
                    not protocols or not 1 <= count.value <= 64 or
                    delete not in [protocols[index] for index in range(count.value)]):
                raise RuntimeError('Owned window does not advertise bounded WM_DELETE_WINDOW')
        finally:
            if protocols:
                x11.XFree(protocols)
        event = Event()
        event.client.type, event.client.display, event.client.window = 33, display, int(window)
        event.client.message_type, event.client.format = protocol, 32
        event.client.data.l[0] = delete
        if not x11.XSendEvent(display, int(window), False, 0, ctypes.byref(event)):
            raise RuntimeError('Owned WM_DELETE_WINDOW request rejected')
        x11.XFlush(display)
    finally:
        x11.XCloseDisplay(display)


def physical_window_picture(Gdk, x, y, width, height):
    """Capture physical X11 geometry through GDK's logical coordinates."""
    root = Gdk.get_default_root_window()
    scale = root.get_scale_factor()
    if not 1 <= scale <= 8 or width <= 0 or height <= 0:
        raise RuntimeError('Product screenshot scale or extent unavailable')
    left, top = x // scale, y // scale
    right, bottom = (x + width + scale - 1) // scale, (y + height + scale - 1) // scale
    picture = Gdk.pixbuf_get_from_window(root, left, top, right - left, bottom - top)
    if picture is None or picture.get_width() != (right - left) * scale or picture.get_height() != (bottom - top) * scale:
        raise RuntimeError('Product screenshot extent unavailable')
    return picture.new_subpixbuf(x - left * scale, y - top * scale, width, height)


def native_display_scale():
    import gi
    gi.require_version('Gdk', '3.0')
    from gi.repository import Gdk
    scale = Gdk.get_default_root_window().get_scale_factor()
    if not 1 <= scale <= 8:
        raise RuntimeError('Native pointer scale unavailable')
    return scale


def pointer_at_native_bounds(command, bounds, repeat=1, button=1):
    """AT-SPI exposes GTK logical bounds; xdotool accepts physical pixels."""
    scale = native_display_scale()
    x, y = (round((bounds.x + bounds.width / 2) * scale),
            round((bounds.y + bounds.height / 2) * scale))
    argv = ['xdotool', 'mousemove', str(x), str(y), 'click']
    if repeat != 1: argv += ['--repeat', str(repeat), '--delay', '120']
    command([*argv, str(button)])


def send_native_keycodes(codes):
    """XTEST input on the controller's display; always release pressed keys."""
    import ctypes
    if not 1 <= len(codes) <= 4 or len(set(codes)) != len(codes) or any(
            not isinstance(code, int) or not 8 <= code <= 255 for code in codes):
        raise ValueError('Native physical keycode budget')
    xlib, xtest = ctypes.CDLL('libX11.so.6'), ctypes.CDLL('libXtst.so.6')
    xlib.XOpenDisplay.argtypes = [ctypes.c_char_p]
    xlib.XOpenDisplay.restype = ctypes.c_void_p
    xlib.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
    xlib.XCloseDisplay.argtypes = [ctypes.c_void_p]
    xtest.XTestFakeKeyEvent.argtypes = [ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
    display = xlib.XOpenDisplay(None)
    if not display:
        raise RuntimeError('Controller X11 display unavailable')
    pressed, released = [], True
    try:
        for code in codes:
            if not xtest.XTestFakeKeyEvent(display, code, 1, 12):
                raise RuntimeError('Native key press rejected')
            pressed.append(code)
    finally:
        try:
            for code in reversed(pressed):
                released = bool(xtest.XTestFakeKeyEvent(display, code, 0, 12)) and released
            xlib.XSync(display, 0)
        finally:
            xlib.XCloseDisplay(display)
    if not released:
        raise RuntimeError('Native key release rejected')


def native_function_key(key, *, control=False, shift=False):
    # libxdo's keysym lookup chooses a higher-level F-key entry on current XKB
    # maps and adds Alt. Resolve the unmodified physical entry instead; this
    # remains ordinary keyboard input, with no application command dispatch.
    if not re.fullmatch(r'F(?:[1-9]|1[0-2])', key):
        raise ValueError('Expected a native function key')
    import gi
    gi.require_version('Gdk', '3.0')
    from gi.repository import Gdk
    display = Gdk.Display.get_default()
    if display is None:
        raise RuntimeError('Controller GDK display unavailable')
    keymap = Gdk.Keymap.get_for_display(display)
    codes = []
    for name in [*(['Control_L'] if control else []), *(['Shift_L'] if shift else []), key]:
        found, entries = keymap.get_entries_for_keyval(Gdk.keyval_from_name(name))
        entry = next((entry for entry in entries if entry.group == 0 and entry.level == 0), None) if found else None
        if entry is None:
            raise RuntimeError('Unmodified native key mapping unavailable')
        codes.append(entry.keycode)
    send_native_keycodes(codes)


def native_photograph_focus(command, report, owned_window):
    """Observe X11 focus, including its valid None and PointerRoot states."""
    observation = {'requestedWindow': owned_window, 'status': 'reading'}
    report['nativePhotographFocus'] = observation

    def read(arguments, phase, minimum):
        observation['readPhase'] = phase
        try:
            value = command(arguments, capture_output=True, text=True).stdout.strip()
        except subprocess.CalledProcessError as error:
            observation['readFailure'] = {'type': type(error).__name__, 'returnCode': error.returncode}
            raise
        if (len(value) > 10 or not value.isascii() or not value.isdecimal() or
                not minimum <= int(value) < 2 ** 32):
            observation['failureCode'] = 'focus-response-malformed'
            raise RuntimeError('Native photograph focus identity unavailable')
        return str(int(value))

    # The default command walks WM_CLASS ancestors, which is undefined for
    # the X11 None/PointerRoot sentinels. Its documented -f form reads those
    # states without attempting a property lookup on a non-window sentinel.
    raw = read(['xdotool', 'getwindowfocus', '-f'], 'raw', 0)
    state = {'0': 'none', '1': 'pointer-root'}.get(raw, 'window')
    focused = None
    if state == 'window':
        focused = raw if raw == owned_window else read(
            ['xdotool', 'getwindowfocus'], 'ancestor', 2)
    observation.update(status='observed', rawFocusedWindow=raw, focusState=state,
                       focusedTopLevel=focused, alreadyFocused=focused == owned_window)
    return observation


def photograph_product(Atspi, app, objects, wait, command, report, label, sizes=((1366, 768),), protected_form=False, resize=True):
    report['stage'] = 'product-screenshot: ' + label
    # This controller runs the ordinary product on an isolated display with
    # fixture data. Never capture a credential field or another application.
    import gi
    gi.require_version('Gdk', '3.0')
    from gi.repository import Gdk
    if not protected_form and any(item.get_role() == Atspi.Role.PASSWORD_TEXT for item in objects(app)):
        raise RuntimeError('Credential dialog must close before a product photograph')
    xid = owned_product_window(command, wait, app.get_process_id())
    folder = Path(os.environ['XDG_DATA_HOME']).parent / 'product-screenshots'
    folder.mkdir(exist_ok=True, mode=0o700)
    import time
    scale = native_display_scale()
    if resize:
        # Preserve an already focused product/control. A known unfocused state
        # still requires the original synchronized request to this owned window.
        focus = native_photograph_focus(command, report, xid)
        if not focus['alreadyFocused']:
            command(['xdotool', 'windowfocus', '--sync', xid])
    else:
        reply = command(['xdotool', 'getwindowgeometry', '--shell', xid], capture_output=True, text=True).stdout
        values = dict(line.split('=', 1) for line in reply.splitlines() if '=' in line)
        sizes = ((int(values['WIDTH']) // scale, int(values['HEIGHT']) // scale),)
    for logical_width, logical_height in sizes:
        width, height = logical_width * scale, logical_height * scale
        # Request a fresh native frame even when this state uses the window's
        # current dimensions; otherwise an inactive Xvfb surface can retain a
        # prior modal or resize frame while accessibility already reflects it.
        if resize:
            command(['xdotool', 'windowsize', xid, str(width + 2), str(height)])
            time.sleep(.15)
            command(['xdotool', 'windowsize', xid, str(width), str(height)])
        def geometry():
            reply = command(['xdotool', 'getwindowgeometry', '--shell', xid], capture_output=True, text=True).stdout
            values = dict(line.split('=', 1) for line in reply.splitlines() if '=' in line)
            return values if int(values['WIDTH']) == width and int(values['HEIGHT']) == height else None
        values = wait(geometry)
        # Leave the pointer over neutral title-bar space so a tree tooltip does
        # not obscure the adjacent document in a resting-state photograph.
        command(['xdotool', 'mousemove', str(int(values['X']) + width // 2), str(int(values['Y']) + 8)])
        # Wait for the resized frame to be visible through native geometry;
        # image acquisition is diagnostic, never a replacement for assertions.
        command(['xdotool', 'getwindowgeometry', xid], stdout=subprocess.DEVNULL)
        if resize: time.sleep(1.2)
        picture = physical_window_picture(Gdk, int(values['X']), int(values['Y']), width, height)
        if picture is None or picture.get_width() != width or picture.get_height() != height:
            raise RuntimeError('Product screenshot extent unavailable')
        path = folder / f'{label}-{width}x{height}.png'
        from native_png import save_native_png
        save_native_png(picture, path)
        report.setdefault('productScreenshots', []).append({'file': str(path), 'width': width, 'height': height,
            'logicalWidth': logical_width, 'logicalHeight': logical_height, 'devicePixelRatio': scale,
            'composition': report.get('actualComposition', {}).get('composition', 'Linux Yaru'), 'workflow': label})
    if resize: command(['xdotool', 'windowsize', xid, str(1280 * scale), str(800 * scale)])



def native_tab_name(label):
    """Identify the short tab title before its separately exposed full context."""
    return (label or '').split('\n', 1)[0].removeprefix('● ')


def native_close_review_label(tab_label, close_label):
    """Use the captured native title, including its translated object suffix."""
    title = native_tab_name(tab_label)
    if (not title or len(title) > 2048 or '\x00' in title or
            not close_label or len(close_label) > 128 or
            any(char in close_label for char in ('\x00', '\r', '\n'))):
        raise ValueError('Native close-review title bound')
    return close_label + ' ' + title


def find_native_close_review(Atspi, nodes, tab_label, close_label, current_nodes=None):
    expected = native_close_review_label(tab_label, close_label)
    values = read_live_native_controls(nodes, lambda node: node if
        node.get_role() == Atspi.Role.PUSH_BUTTON and
        node.get_name() == expected and 'Action' in node.get_interfaces() and
        all(node.get_state_set().contains(state) for state in
            (Atspi.StateType.SHOWING, Atspi.StateType.SENSITIVE)) else None, current_nodes)
    if values is None: return None
    matches = [value for value in values if value is not None]
    if len(matches) > 1:
        raise RuntimeError('Ambiguous native captured-document close review')
    return matches[0] if matches else None


NATIVE_TAB_BADGES = frozenset({'Running', 'Completed', 'Failed', 'Cancelled',
    'Production', 'Transaction open', 'Transaction failed', 'Outcome unknown'})


def native_tab_has_status(label, *statuses):
    """Read exact trailing title badges; provenance cannot supply a status."""
    value = native_tab_name(label)
    while ' · ' in value:
        value, badge = value.rsplit(' · ', 1)
        if badge not in NATIVE_TAB_BADGES:
            return False
        if badge in statuses:
            return True
    return False


def native_query_identity(label):
    """Remove trailing tab badges without looping on standalone status labels."""
    value = native_tab_name(label)
    while ' · ' in value and value.rsplit(' · ', 1)[-1] in NATIVE_TAB_BADGES:
        value = value.rsplit(' · ', 1)[0]
    return value


def assert_native_command_disabled(Atspi, item):
    """GTK SENSITIVE is flag presence; ENABLED is the pinned engine's value."""
    item.clear_cache()
    if item.get_state_set().contains(Atspi.StateType.ENABLED):
        raise RuntimeError('Uncertain session still admits SQL')
    count = Atspi.Action.get_n_actions(item) if 'Action' in item.get_interfaces() else 0
    if not 0 <= count <= 64:
        raise RuntimeError('Native action-count budget')
    actions = [Atspi.Action.get_action_name(item, index) for index in range(count)]
    if any(action in ('tap', 'Tap', 'click', 'activate', 'press') for action in actions):
        raise RuntimeError('Disabled command still exposes activation')
    return {'enabled': False, 'activationAvailable': False, 'actions': actions}


def dispatch_native_activation(Atspi, item, index):
    """Capture role before the single action can retire its native control."""
    role = item.get_role()
    if not Atspi.Action.do_action(item, index):
        raise RuntimeError('Native control rejected its explicit activation action')
    return role


def bounded_native_text(Atspi, item, limit=65536):
    """Read the authored review's native Text value, never protected inputs."""
    if (item.get_role() == Atspi.Role.PASSWORD_TEXT or
            'Text' not in item.get_interfaces() or
            not item.get_state_set().contains(Atspi.StateType.SHOWING)):
        return ''
    count = Atspi.Text.get_character_count(item)
    if count < 0 or count > limit:
        return ''
    return Atspi.Text.get_text(item, 0, count)


def native_readonly_sql_preview(Atspi, item, native_name):
    """Inspect the owned read-only SQL entry; a copy interface grants no editing."""
    states = item.get_state_set()
    if (native_name(item) != 'SQL' or item.get_role() != Atspi.Role.ENTRY or
            'Text' not in item.get_interfaces() or
            not all(states.contains(state) for state in
                (Atspi.StateType.READ_ONLY, Atspi.StateType.SHOWING, Atspi.StateType.VISIBLE)) or
            states.contains(Atspi.StateType.EDITABLE)):
        return None
    return bounded_native_text(Atspi, item)


def wait_native_field_value(Atspi, current_item, value, wait):
    """A field can be reparented while its authored value changes semantics."""
    def acknowledged():
        item = current_item()
        return item is not None and Atspi.Text.get_text(item, 0, -1) == value
    return wait(acknowledged)


def visible_object_definition(Atspi, nodes, object_name, current_nodes=None):
    """Verify actual visible read-only DDL, including native Text values."""
    def matches(item):
        states = item.get_state_set()
        if (item.get_role() == Atspi.Role.PASSWORD_TEXT or
                not states.contains(Atspi.StateType.SHOWING) or
                states.contains(Atspi.StateType.EDITABLE) and
                not states.contains(Atspi.StateType.READ_ONLY)):
            return False
        name = item.get_name() or ''
        text = name + '\n' + bounded_native_text(Atspi, item)
        return 'CREATE TABLE' in text and object_name in text
    return native_observe_any(nodes, matches, current_nodes)


def assert_current_grid_owner(Atspi, nodes, owner, *, flyout_pending=False):
    """Fluent flyouts scope out background semantics until they retire."""
    if owner in nodes:
        if owner.get_state_set().contains(Atspi.StateType.SELECTED):
            return True
    elif flyout_pending and not any(
            node.get_role() == Atspi.Role.PUSH_BUTTON and
            node.get_state_set().contains(Atspi.StateType.SELECTED)
            for node in nodes):
        return False
    raise RuntimeError('Captured grid document changed before activation')


def verify_native_sql_lines(Atspi, editor, expected, wait, command, *, observations=None):
    """Inspect a small authored SQL fixture through its bounded current-line window."""
    lines = expected.split('\n')
    if len(lines) > 64 or len(expected) > 65536:
        raise ValueError('Native SQL inspection fixture budget')
    if len(lines) == 1:
        wait(lambda: Atspi.Text.get_text(editor(), 0, -1) == expected)
        return
    # EditableText acknowledgements precede the editor's new line window.
    # Observe the authored text and line count before sending navigation keys;
    # an old first-line window cannot acknowledge a pending multiline update.
    def authored_window():
        current = editor()
        return (re.search(r'Visible SQL line [0-9]+ of ' + str(len(lines)) + r'(?:,|$)',
            current.get_name() or '') is not None and
            Atspi.Text.get_text(current, 0, -1) in lines)
    wait(authored_window)
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+Home'])
    for index, line in enumerate(lines):
        if index:
            command(['xdotool', 'key', '--clearmodifiers', 'Down'])
        try:
            wait(lambda: Atspi.Text.get_text(editor(), 0, -1) == line)
        except TimeoutError:
            if observations is not None:
                current = editor()
                actual = Atspi.Text.get_text(current, 0, -1)
                observations.append({'expectedLine': index + 1,
                    'editorContext': current.get_name(),
                    'focused': current.get_state_set().contains(Atspi.StateType.FOCUSED),
                    'expectedCharacters': len(line), 'actualCharacters': len(actual),
                    'expectedSha256': hashlib.sha256(line.encode()).hexdigest(),
                    'actualSha256': hashlib.sha256(actual.encode()).hexdigest()})
            raise
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+End'])
    wait(lambda: Atspi.Text.get_text(editor(), 0, -1) == lines[-1])


def wait_native_owned_session_nodes(Atspi, current_nodes, wait):
    """Opening a native menu action does not acknowledge its destination dialog."""
    def ready():
        nodes = current_nodes()
        return nodes if any(re.search(r' · [0-9a-f-]{36} · ', node.get_name() or '') and
            node.get_state_set().contains(Atspi.StateType.SHOWING) for node in nodes) else None
    return wait(ready)


@lru_cache(maxsize=2)
def native_label_patterns(items):
    """Compile two immutable catalog snapshots; do not cache native nodes."""
    patterns = []
    for english, translated in sorted(items, key=lambda pair: len(pair[1]), reverse=True):
        slots = re.findall(r'\{([A-Za-z_][A-Za-z_0-9]*)\}', translated)
        if slots:
            # Numeric UI templates only; never interpret identifiers or SQL as
            # translatable interface text. Captured counts retain their values.
            if len(set(slots)) != len(slots) or set(slots) != set(re.findall(r'\{([A-Za-z_][A-Za-z_0-9]*)\}', english)):
                continue
            pieces = re.split(r'(\{[A-Za-z_][A-Za-z_0-9]*\})', translated)
            expression = ''.join('(?P<' + piece[1:-1] + '>[0-9]{1,20})'
                                 if piece.startswith('{') else re.escape(piece) for piece in pieces)
            pattern = re.compile(r'(^| · | — |\n|^● )' + expression + r'(?=$| · |\n|: )')
        else:
            pattern = re.compile(r'(^| · | — |\n|^● )' + re.escape(translated) + r'(?=$| · |\n|: | {3})')
        patterns.append((english, tuple(slots), pattern))
    return tuple(patterns)


def normalized_native_label(actual, labels):
    """Normalize translated interface segments while retaining object names."""
    for english, slots, pattern in native_label_patterns(tuple(labels.items())):
        def replace(match):
            value = english
            for name in slots:
                value = value.replace('{' + name + '}', match.group(name))
            return match.group(1) + value
        actual = pattern.sub(replace, actual)
    for english in ('Expand', 'Collapse'):
        translated = labels.get(english)
        if translated and actual.startswith(translated + ' '):
            actual = english + actual[len(translated):]
    tree_level = labels.get('level')
    if tree_level:
        actual = re.sub(r' · ' + re.escape(tree_level) + r' ([0-9]{1,5}) · ',
                        lambda match: ' · level ' + match.group(1) + ' · ', actual)
    plan_level = labels.get('Level')
    if plan_level and re.match(r'^' + re.escape(plan_level) + r' [0-9]{1,5}, ', actual):
        actual = 'Level' + actual[len(plan_level):]
        for state in ('expanded', 'collapsed'):
            translated = labels.get(state)
            if translated and actual.endswith(', ' + translated):
                actual = actual[:-len(translated)] + state
    row_label = labels.get('Row')
    if row_label and re.match(r'^' + re.escape(row_label) + r' [0-9]{1,20}, ', actual):
        actual = 'Row' + actual[len(row_label):]
        pending = labels.get('pending change')
        if pending and actual.endswith(' · ' + pending):
            actual = actual[:-len(pending)] + 'pending change'
    return actual


def native_sql_editor_label(actual, labels):
    """Recognize the localized editor heading without translating its title."""
    template = labels.get('SQL editor {title}', 'SQL editor {title}')
    if template.count('{title}') != 1:
        raise RuntimeError('Invalid SQL editor semantic template')
    prefix, suffix = template.split('{title}')
    if not (prefix or suffix) or '{' in prefix + suffix:
        raise RuntimeError('Invalid SQL editor semantic template')
    heading, separator, detail = actual.partition('\n')
    if (not heading.startswith(prefix) or not heading.endswith(suffix) or
            len(heading) <= len(prefix) + len(suffix)):
        return None
    title = heading[len(prefix):len(heading) - len(suffix) if suffix else None]
    return 'SQL editor ' + title + separator + detail


def native_sql_editor_announcement(labels):
    """Require the actual translated control label in real reader output."""
    template = labels.get('SQL editor {title}', 'SQL editor {title}')
    if template.count('{title}') != 1:
        raise RuntimeError('Invalid SQL editor semantic template')
    fragment = max(template.split('{title}'), key=len).strip()
    if not fragment:
        raise RuntimeError('Missing SQL editor semantic label')
    return fragment


def native_character_geometry(Atspi, node, offset=0):
    """Require an actual glyph observation, never a substituted field bound."""
    node.clear_cache()
    attributes = node.get_attributes()
    if (not isinstance(attributes, dict) or
            attributes.get('busydata-geometry-precision') != 'glyph-bounds'):
        raise RuntimeError('Native text has no current actual glyph geometry')
    field = Atspi.Component.get_extents(node, Atspi.CoordType.WINDOW)
    glyph = Atspi.Text.get_range_extents(node, offset, offset + 1,
                                        Atspi.CoordType.WINDOW)
    values = [getattr(rect, key) for rect in (field, glyph)
              for key in ('x', 'y', 'width', 'height')]
    if (any(not isinstance(value, (int, float)) or isinstance(value, bool) or
            not math.isfinite(value) for value in values) or
            min(field.x, field.y, glyph.x, glyph.y) < 0 or
            min(field.width, field.height, glyph.width, glyph.height) < 1 or
            glyph.width >= field.width or
            glyph.x < field.x - 1 or glyph.y < field.y - 1 or
            glyph.x + glyph.width > field.x + field.width + 1 or
            glyph.y + glyph.height > field.y + field.height + 1):
        raise RuntimeError('Native character geometry is unavailable or outside its actual field')
    return {'precision': 'glyph-bounds', 'start': offset, 'end': offset + 1,
            'field': [field.x, field.y, field.width, field.height],
            'range': [glyph.x, glyph.y, glyph.width, glyph.height]}


def native_control_label(item, labels):
    actual = item.get_name() or ''
    if 'EditableText' in item.get_interfaces():
        editor = native_sql_editor_label(actual, labels)
        if editor is not None:
            return editor
    return normalized_native_label(actual, labels)


class NativeSnapshotIncomplete(RuntimeError):
    """AT-SPI reports -1 or a missing child when a live edge cannot be read."""


class NativeNodeBudgetExceeded(RuntimeError):
    def __init__(self, child_count, found_count, pending_count, limit):
        super().__init__('Native accessible node budget')
        self.child_count, self.found_count = child_count, found_count
        self.pending_count, self.limit = pending_count, limit


def fresh_accessible_objects(application, limit=512, transient_errors=(),
                             between_attempts=None):
    """Read live parent/child edges; cached modal nodes cannot prove disposal."""
    retryable_errors = (NativeSnapshotIncomplete,) + transient_errors
    for attempt in range(3):
        pending, found, seen = deque([application]), [], set()
        try:
            while pending:
                item = pending.popleft()
                if item is None:
                    raise NativeSnapshotIncomplete('Native child edge is unavailable')
                if item in seen:
                    continue
                seen.add(item)
                item.clear_cache()
                count = item.get_child_count()
                if count == -1:
                    raise NativeSnapshotIncomplete('AT-SPI child-count read failed')
                if count < -1:
                    raise RuntimeError('Invalid native child count')
                if len(found) + len(pending) + count + 1 > limit:
                    raise NativeNodeBudgetExceeded(count, len(found), len(pending), limit)
                found.append(item)
                pending.extend(item.get_child_at_index(i) for i in range(count))
            return found
        except retryable_errors as failure:
            # A GTK chooser can disappear while its former children are read.
            # Discard the whole snapshot: a partial tree cannot acknowledge
            # dismissal or establish that a completion control is absent.
            if attempt == 2:
                # The C API reports -1 with GError; PyGObject raises that
                # error instead. Both leave the entire snapshot unavailable.
                # A post-action wait may continue reading within its existing
                # deadline, but it must obtain a complete tree before acking.
                if (not isinstance(failure, NativeSnapshotIncomplete) and
                        getattr(failure, 'domain', None) == 'atspi_error' and
                        getattr(failure, 'code', None) == 1):
                    raise NativeSnapshotIncomplete('Native whole-tree read unavailable') from failure
                raise
            if between_attempts is not None:
                # Let the AT-SPI context deliver queued child-removal events
                # before restarting at the root. A synchronous retry can read
                # the same retired proxy three times without dispatching them.
                between_attempts()


def scoped_grid_menu_caption(caption, parents):
    """Recognize the visible grid header even when GTK merges tooltip labels."""
    parts = caption.splitlines()
    menu = any(part in ('More', 'Grid actions', 'Data grid') or
               part.startswith(('More · ', 'Grid actions · ')) for part in parts)
    scope = 'Row selection' in parts or any(
        'Row selection' in parent.splitlines() for parent in parents)
    return menu and (scope or 'Data grid' in parts)


def accessible_ancestors(item, limit=32):
    """Read the public upward tree, rejecting cycles and unbounded ancestry."""
    found, seen = [], {item}
    while item is not None:
        item.clear_cache()
        item = item.get_parent()
        if item is None:
            break
        if item in seen or len(found) >= limit:
            raise RuntimeError('Native accessible ancestor budget or cycle')
        seen.add(item)
        found.append(item)
    return found


def control_key_until(command, wait, key, acknowledged, shift=False):
    """One key press; retain its modifier until acknowledged and always release."""
    command(['xdotool', 'keydown', 'ctrl'])
    try:
        if shift:
            command(['xdotool', 'keydown', 'shift'])
        command(['xdotool', 'key', key])
        return wait(acknowledged)
    finally:
        if shift:
            command(['xdotool', 'keyup', 'shift'])
        command(['xdotool', 'keyup', 'ctrl'])


def execution_menu_dismissed(Atspi, nodes, history_names, trigger, name):
    """A Fluent flyout need not expose MENU; await its rows and restored focus."""
    for node in nodes:
        if node.get_state_set().contains(Atspi.StateType.SHOWING) and (
                node.get_role() == Atspi.Role.MENU or name(node) in history_names):
            return False
    return trigger is not None and trigger.get_state_set().contains(Atspi.StateType.FOCUSED)


def source_row_value_label(names, identity_column, identity_value, column, value):
    """Locate fixture evidence by its key after a query changes row order."""
    identities = []
    for name in names:
        match = re.fullmatch(r'Row ([1-9][0-9]*), ' + re.escape(identity_column) +
                             ': ' + re.escape(identity_value), name.split('\n')[0])
        if match:
            identities.append(match.group(1))
    if len(identities) > 1:
        raise RuntimeError('Ambiguous fixture source identity')
    return 'Row ' + identities[0] + ', ' + column + ': ' + value if identities else None


NATIVE_RESULT_CELL_PREFIX = 'busydata.result.cell.v1:'


def native_result_cell_identity(identifier):
    """Read only the owned versioned semantic identifier, never a cell label."""
    if identifier is None or identifier == '':
        return None
    if not isinstance(identifier, str):
        raise RuntimeError('Invalid native result identifier type')
    if not identifier.startswith('busydata.result.cell.'):
        return None
    try:
        if len(identifier.encode('utf-8', errors='strict')) > 2048:
            raise ValueError('identifier budget')
        if not identifier.startswith(NATIVE_RESULT_CELL_PREFIX):
            raise ValueError('identifier version')
        fields = json.loads(identifier[len(NATIVE_RESULT_CELL_PREFIX):])
        if (not isinstance(fields, list) or len(fields) != 5 or
                any(not isinstance(value, str) or not 1 <= len(value) <= 128 or
                    any(char in value for char in ('\x00', '\r', '\n')) for value in fields[:3]) or
                type(fields[3]) is not int or not 0 <= fields[3] < 2 ** 63 or
                type(fields[4]) is not int or not 0 <= fields[4] < 2048):
            raise ValueError('identifier fields')
    except (ValueError, UnicodeError, RecursionError) as failure:
        raise RuntimeError('Invalid versioned native result cell identifier') from failure
    return tuple(fields)


def native_grid_generation(Atspi, nodes, document, native_name, current_nodes):
    """One complete selected-document and visible result-generation observation."""
    def observe(node):
        states = node.get_state_set()
        if not all(states.contains(state) for state in
                   (Atspi.StateType.SHOWING, Atspi.StateType.SENSITIVE)):
            return None
        caption = native_name(node)
        if (node.get_role() == Atspi.Role.PUSH_BUTTON and
                states.contains(Atspi.StateType.SELECTED) and
                native_query_identity(caption) == document):
            return ('document', node, native_query_identity(caption),
                (node.get_name() or '').partition('\n')[2],
                native_tab_has_status(caption, 'Completed'))
        if (node.get_role() != Atspi.Role.PUSH_BUTTON or not caption.startswith('Row ') or
                'Action' not in node.get_interfaces()):
            return None
        attributes = node.get_attributes()
        if not isinstance(attributes, dict):
            raise RuntimeError('Native result attributes are unavailable')
        identity = native_result_cell_identity(attributes.get('id'))
        if identity is None:
            raise RuntimeError('Visible result cell has no versioned native identity')
        return ('cell', node, caption, identity)
    values = read_live_native_controls(nodes, observe, current_nodes)
    if values is None:
        return None
    documents = [value for value in values if value is not None and value[0] == 'document']
    cells = [value for value in values if value is not None and value[0] == 'cell']
    if len(documents) > 1:
        raise RuntimeError('Ambiguous selected result document generation')
    if not documents or not cells:
        return None
    if len(cells) > 16:
        raise RuntimeError('Native fixture result generation marker budget')
    groups = {value[3][:3] for value in cells}
    coordinates = [value[3][3:] for value in cells]
    if len(groups) != 1 or len(set(coordinates)) != len(coordinates):
        raise RuntimeError('Ambiguous native result generation or cell coordinate')
    selected = documents[0]
    owner, source, display = next(iter(groups))
    return {'document': selected[2], 'context': selected[3], 'completed': selected[4],
        'owner': owner, 'source': source, 'display': display,
        'tab': selected[1], 'cells': tuple((value[1], value[2], value[3][3:]) for value in cells)}


def replaced_native_grid_generation(Atspi, nodes, previous, native_name, current_nodes,
                                    *, expected_cells=(), absent_labels=(), expected_rows=()):
    """A local view or retired modal handles cannot acknowledge a server result."""
    current = native_grid_generation(Atspi, nodes, previous['document'], native_name, current_nodes)
    if current is None:
        return None
    if (current['context'] != previous['context'] or current['owner'] != previous['owner']):
        raise RuntimeError('Server result belongs to another captured document or target')
    if not current['completed'] or current['source'] == previous['source']:
        return None
    cells = [(caption.splitlines()[0], *coordinate) for _, caption, coordinate in current['cells']]
    captions = [caption for caption, _, _ in cells]
    if (any(cells.count(expected) != 1 for expected in expected_cells) or
            any(label in captions for label in absent_labels)):
        return None
    if expected_rows and native_keyed_fixture_generation(current, expected_rows) is None:
        return None
    return current


def find_visible_grid_cell(Atspi, nodes, label, native_name, *, previous=(), owner=None, current_nodes=None):
    # The same value can remain in the old result while a replacement runs.
    # Require retirement of that captured result and this actual document's
    # acknowledged completion before accepting the new visible source cell.
    if any(item in nodes for item in previous):
        return None
    def visible(item):
        states = item.get_state_set()
        return (states.contains(Atspi.StateType.SHOWING) and
                states.contains(Atspi.StateType.SENSITIVE))
    if owner is not None and (owner not in nodes or not visible(owner) or
            not owner.get_state_set().contains(Atspi.StateType.SELECTED) or
            not native_tab_has_status(native_name(owner), 'Completed')):
        return None
    values = read_live_native_controls(nodes, lambda item: item if
        native_name(item).splitlines()[0:1] == [label] and visible(item) and
        'Action' in item.get_interfaces() else None, current_nodes)
    if values is None:
        return None
    matches = [item for item in values if item is not None]
    if len(matches) > 1:
        raise RuntimeError('Ambiguous visible grid source cell')
    return matches[0] if matches else None


def find_keyed_grid_cell(Atspi, nodes, identity_column, identity_value, column,
                         value, native_name, *, previous=(), owner=None, current_nodes=None):
    """Resolve a source key only after the captured replacement is adopted."""
    if any(item in nodes for item in previous):
        return None
    if owner is not None and (owner not in nodes or
            not all(owner.get_state_set().contains(state) for state in
                    (Atspi.StateType.SHOWING, Atspi.StateType.SENSITIVE, Atspi.StateType.SELECTED)) or
            not native_tab_has_status(native_name(owner), 'Completed')):
        return None
    values = read_live_native_controls(nodes, lambda item: native_name(item) if 'Action' in item.get_interfaces() and
               all(item.get_state_set().contains(state) for state in
                   (Atspi.StateType.SHOWING, Atspi.StateType.SENSITIVE)) else None, current_nodes)
    if values is None:
        return None
    label = source_row_value_label([value for value in values if value is not None],
                                  identity_column, identity_value, column, value)
    return find_visible_grid_cell(Atspi, nodes, label, native_name,
                                  previous=previous, owner=owner, current_nodes=current_nodes) if label else None


def native_physical_session_identity(text, label):
    """Read one bounded authored Session details line, not a tab caption."""
    if not isinstance(text, str) or not isinstance(label, str) or not 1 <= len(label) <= 128:
        raise ValueError('Native physical-session evidence type or label bound')
    if len(text) > 4096 or any(char in label for char in ('\r', '\n', '\x00')):
        raise ValueError('Native physical-session evidence bound')
    prefix = label + ': '
    values = [line[len(prefix):] for line in text.splitlines() if line.startswith(prefix)]
    if not values:
        return None
    if (len(values) != 1 or re.fullmatch(
            r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
            values[0]) is None):
        raise RuntimeError('Invalid or ambiguous native physical-session identity')
    return values[0]


def native_fresh_browse_generation(previous, current, expected_rows):
    """Require a new completed Data owner and exact key/value source coordinates."""
    if (current is None or not current['completed'] or
            current['owner'] == previous['owner'] or current['source'] == previous['source']):
        return None
    return native_keyed_fixture_generation(current, expected_rows)


def native_keyed_fixture_generation(current, expected_rows):
    """Verify every fixture key/value pair against its actual source coordinate."""
    if not 1 <= len(expected_rows) <= 8:
        raise ValueError('Native browse fixture row budget')
    cells = [(caption.splitlines()[0], *coordinate) for _, caption, coordinate in current['cells']]
    names = [caption for caption, _, _ in cells]
    if len(cells) != 2 * len(expected_rows):
        return None
    for key, value in expected_rows:
        label = source_row_value_label(names, 'id', key, 'n', value)
        if label is None:
            return None
        row = int(re.fullmatch(r'Row ([1-9][0-9]*), n: .*', label).group(1)) - 1
        if (cells.count(('Row ' + str(row + 1) + ', id: ' + key, row, 0)) != 1 or
                cells.count((label, row, 1)) != 1):
            return None
    return current


def native_previous_browse_generation(Atspi, nodes, labels, native_name, current_nodes):
    """Bind the actual selected SQL owner, including renamed/localized titles."""
    checkpoint = native_palette_sql_checkpoint(Atspi, nodes, labels, current_nodes)
    if checkpoint is None:
        return None
    if checkpoint == (None,):
        raise RuntimeError('Native browse has no visible preceding SQL document')
    document = checkpoint[-1][0]
    generation = native_grid_generation(Atspi, nodes, document, native_name, current_nodes)
    return generation if generation is not None and generation['completed'] else None


def palette_rows_ready(names, label, labels=None):
    """Wait for the rendered command list, beyond the native input value."""
    labels = labels or {}
    categories = {labels.get(category, category) for category in
                  ('File', 'Edit', 'View', 'Connection', 'Object',
                   'Run options', 'Results', 'Changes')}
    query = labels.get(label, label)
    rows = [(name.split(' · ', 1)[0],
             name.split(' · ', 1)[1].split('   ', 1)[0])
            for name in names if name.split(' · ', 1)[0] in categories
            and ' · ' in name]
    # Registry search includes the category as well as the command label.
    # "Connect" therefore also matches other "Connection" commands. Retain
    # the exact requested row and reject stale rows outside that real query.
    return any(row == query for _, row in rows) and all(
        query.lower() in (category + ' ' + row).lower()
        for category, row in rows)


def _native_node_retired(failure, item, current_nodes):
    return (current_nodes is not None and getattr(failure, 'domain', None) == 'atspi_error' and
            getattr(failure, 'code', None) == 1 and item not in current_nodes())


def read_live_native_controls(nodes, read, current_nodes):
    """A retired getter invalidates the entire read-only observation poll."""
    values = []
    for item in nodes:
        try:
            values.append(read(item))
        except Exception as failure:
            if not _native_node_retired(failure, item, current_nodes):
                raise
            return None
    return values


def native_observe_any(nodes, predicate, current_nodes):
    """Read-only predicates only: incomplete stays pending, never absence.

    Actions belong outside observations and must never be repeated by a poll.
    """
    values = read_live_native_controls(nodes, predicate, current_nodes)
    return None if values is None else any(values)


def native_complete_observation(value):
    """Wrap complete false/empty reads for waits; None alone remains pending.

    Only use with read-only readers whose None means incomplete. Dispatch and
    evidence writes remain outside the observation.
    """
    return None if value is None else (value,)


def read_native_snapshot(current_nodes, read):
    """Read-only snapshot boundary: an unavailable edge is never an empty tree.

    The caller's original wait owns the deadline. Never dispatch an action from
    read: only observations may be repeated after an incomplete snapshot.
    """
    try:
        return read(current_nodes())
    except NativeSnapshotIncomplete:
        return None


def wait_native_inventory(current_nodes, project, wait):
    """Capture a complete read-only baseline before dispatching the next action."""
    values, = wait(lambda: native_complete_observation(read_native_snapshot(
        current_nodes, lambda nodes: read_live_native_controls(nodes, project, current_nodes))))
    return values


def native_observe_none(nodes, predicate, current_nodes):
    """Own negation so an incomplete read cannot acknowledge disappearance."""
    values = read_live_native_controls(nodes, predicate, current_nodes)
    return None if values is None else not any(values)


def native_observe_first(nodes, project, current_nodes):
    """Project read-only (matched, value) pairs, preserving False/0/None values."""
    values = read_live_native_controls(nodes, project, current_nodes)
    if values is None:
        return None
    return next((value for matched, value in values if matched), None)


def native_caption_presence(nodes, caption_match, current_nodes):
    """Duplicate route/header captions prove presence, never an action target."""
    observations = read_live_native_controls(nodes,
        lambda item: caption_match(item.get_name() or ''), current_nodes)
    return None if observations is None else any(observations)


def find_live_control(Atspi, nodes, name, interface='Action', current_nodes=None, activation_only=False,
                      alternate_names=(), menu_only=False, name_prefix=False, caption_match=None):
    matches = []
    for item in nodes:
        try:
            caption = item.get_name() or ''
            named = (caption_match(caption) if caption_match is not None else
                     caption.startswith(name) if name_prefix else
                     (caption == name or ' '.join(caption.split()) in alternate_names))
            if named and interface in item.get_interfaces():
                if activation_only:
                    count = Atspi.Action.get_n_actions(item)
                    if not 0 <= count <= 64: raise RuntimeError('Native action-count budget')
                    # Focus-only disabled controls do not compete with live actions.
                    if not any(Atspi.Action.get_action_name(item, index) in ('tap', 'Tap', 'click', 'activate', 'press') for index in range(count)): continue
                matches.append(item)
        except Exception as failure:
            # Native trees change between enumeration and property reads. Only
            # reacquire a lookup when a fresh live tree proves this exact node
            # disappeared. Application/transport errors still fail; actions are
            # never repeated here and the caller retains its original deadline.
            if not _native_node_retired(failure, item, current_nodes):
                raise
            return None
    if interface == 'Action':
        def eligibility(item):
            eligible = (item.get_state_set().contains(Atspi.StateType.SHOWING) and
                        item.get_state_set().contains(Atspi.StateType.SENSITIVE))
            return item, item.get_role() if eligible else None, eligible
        states = read_live_native_controls(matches, eligibility, current_nodes)
        if states is None:
            return None
        matches = [item for item, _, eligible in states if eligible]
        # A native menu retains the workbench behind it. Resolve its entries
        # within the active menu rather than confusing them with the same
        # action in a document toolbar or Explorer header.
        menu_matches = [item for item, role, eligible in states if eligible and role in
                        (Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM,
                         Atspi.Role.RADIO_MENU_ITEM)]
        if menu_matches or menu_only:
            matches = menu_matches
        menu_role = getattr(Atspi.Role, 'MENU', None)
        menu_showing = (native_observe_any(nodes, lambda item: item.get_role() == menu_role and
            item.get_state_set().contains(Atspi.StateType.SHOWING), current_nodes)
            if menu_role is not None else False)
        if menu_showing is None:
            return None
        if menu_showing:
            # An open native popup owns activation. A same-named toolbar button
            # behind it cannot stand in for a missing/unsupported menu action.
            scoped = read_live_native_controls(matches, lambda item: (item, item.get_role() in
                (Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM)
                or any(parent.get_role() == menu_role for parent in accessible_ancestors(item))), current_nodes)
            if scoped is None:
                return None
            matches = [item for item, eligible in scoped if eligible]
    if len(matches) > 1:
        raise RuntimeError('Ambiguous live native control: ' + name)
    return matches[0] if matches else None


def _complete_native_control_lookup(Atspi, nodes, name, interface, current_nodes, caption_match=None):
    incomplete = False
    def current_proof():
        nonlocal incomplete
        incomplete = True
        return current_nodes()
    match = find_live_control(Atspi, nodes, name, interface,
        current_nodes=current_proof, caption_match=caption_match)
    return not incomplete, match


def native_control_absent(Atspi, nodes, name, interface, current_nodes, caption_match=None):
    """Only a complete lookup can acknowledge that a retiring control is gone."""
    complete, match = _complete_native_control_lookup(Atspi, nodes, name, interface,
        current_nodes, caption_match)
    return complete and match is None


def find_live_sql_editor(Atspi, nodes, labels, current_nodes):
    """Read the exact localized title and interface within one guarded lookup."""
    return find_live_control(Atspi, nodes, 'SQL editor {title}', 'EditableText',
        current_nodes=current_nodes,
        caption_match=lambda caption: native_sql_editor_label(caption, labels) is not None)


def restored_native_sql_editor(Atspi, nodes, labels, expected_heading, expected_value,
                               expected_pid, current_nodes):
    """Rebind only the same fixture document after its modal semantics retire."""
    editor = find_live_sql_editor(Atspi, nodes, labels, current_nodes)
    if editor is None:
        return None
    def restored(item):
        label = native_sql_editor_label(item.get_name() or '', labels)
        if label is None or label.partition('\n')[0] != expected_heading:
            raise RuntimeError('Restored native SQL editor belongs to another document')
        if item.get_process_id() != expected_pid:
            raise RuntimeError('Restored native SQL editor belongs to another application')
        if Atspi.Text.get_text(item, 0, -1) != expected_value:
            return None
        if not item.get_state_set().contains(Atspi.StateType.FOCUSED):
            return None
        return item
    observations = read_live_native_controls([editor], restored, current_nodes)
    if observations is None or observations[0] is None:
        return None
    return editor if editor in current_nodes() else None


def native_sql_editor_origin(Atspi, editor, nodes, labels, current_nodes):
    """Capture scalar editing state and selected-document/session context.

    This read-only checkpoint is used only across an explicit modal boundary;
    it never adopts another editor after an edit or a rejected action.
    """
    label = native_sql_editor_label(editor.get_name() or '', labels)
    if label is None:
        raise RuntimeError('Native SQL origin has no authored document heading')
    heading = label.partition('\n')[0]
    document = native_query_identity(normalized_native_label(heading[len('SQL editor '):], labels))
    session_pattern = re.compile(r' · ([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$')
    def selected_context(node):
        if (node.get_role() != Atspi.Role.PUSH_BUTTON or
                not all(node.get_state_set().contains(state) for state in
                    (Atspi.StateType.SHOWING, Atspi.StateType.SELECTED))):
            return None
        raw_name = node.get_name() or ''
        name = normalized_native_label(raw_name, labels)
        _, separator, context = raw_name.partition('\n')
        session = session_pattern.search(context) if separator else None
        return (native_query_identity(name), context, session.group(1)) if session else None
    values = read_live_native_controls(nodes, selected_context, current_nodes)
    if values is None:
        return None
    selected = [value for value in values if value is not None]
    if len(selected) > 1:
        raise RuntimeError('Ambiguous selected SQL origin document')
    if not selected:
        return None
    if selected[0][0] != document:
        raise RuntimeError('Native SQL origin belongs to another selected document')
    count = Atspi.Text.get_character_count(editor)
    if not 0 <= count <= 65536:
        raise RuntimeError('Native SQL origin text budget')
    text = Atspi.Text.get_text(editor, 0, count)
    caret = Atspi.Text.get_caret_offset(editor)
    selection_count = Atspi.Text.get_n_selections(editor)
    if len(text) != count or not 0 <= caret <= count or not 0 <= selection_count <= 64:
        raise RuntimeError('Native SQL origin scalar editing bounds')
    selections = []
    for index in range(selection_count):
        selection = Atspi.Text.get_selection(editor, index)
        start, end = selection.start_offset, selection.end_offset
        if not 0 <= start <= end <= count:
            raise RuntimeError('Native SQL origin selection bounds')
        selections.append((start, end))
    if not editor.get_state_set().contains(Atspi.StateType.FOCUSED) or editor not in current_nodes():
        return None
    return {'heading': heading, 'pid': editor.get_process_id(), 'text': text,
        'caret': caret, 'selections': tuple(selections), 'document': selected[0][0],
        'context': selected[0][1], 'sessionId': selected[0][2]}


def native_palette_sql_checkpoint(Atspi, nodes, labels, current_nodes):
    """Explicit complete absence or exact visible SQL state, without taking focus."""
    complete, editor = _complete_native_control_lookup(Atspi, nodes, 'SQL editor {title}',
        'EditableText', current_nodes,
        caption_match=lambda caption: native_sql_editor_label(caption, labels) is not None)
    if not complete:
        return None
    if editor is None or not editor.get_state_set().contains(Atspi.StateType.SHOWING):
        return (None,)
    heading = native_sql_editor_label(editor.get_name() or '', labels).partition('\n')[0]
    document = native_query_identity(normalized_native_label(heading[len('SQL editor '):], labels))
    def selected_context(node):
        if (node.get_role() != Atspi.Role.PUSH_BUTTON or
                not all(node.get_state_set().contains(state) for state in
                    (Atspi.StateType.SHOWING, Atspi.StateType.SELECTED))):
            return None
        raw = node.get_name() or ''
        identity = native_query_identity(normalized_native_label(raw, labels))
        return (identity, raw.partition('\n')[2]) if identity == document else None
    values = read_live_native_controls(nodes, selected_context, current_nodes)
    if values is None:
        return None
    selected = [value for value in values if value is not None]
    if len(selected) > 1:
        raise RuntimeError('Ambiguous palette SQL document checkpoint')
    if not selected or editor not in current_nodes():
        return None
    count, selection_count = (Atspi.Text.get_character_count(editor),
                              Atspi.Text.get_n_selections(editor))
    if not 0 <= count <= 65536 or not 0 <= selection_count <= 64:
        raise RuntimeError('Palette SQL scalar checkpoint budget')
    text, caret = Atspi.Text.get_text(editor, 0, count), Atspi.Text.get_caret_offset(editor)
    if len(text) != count or not 0 <= caret <= count:
        raise RuntimeError('Palette SQL scalar checkpoint bounds')
    selections = []
    for index in range(selection_count):
        selection = Atspi.Text.get_selection(editor, index)
        if not 0 <= selection.start_offset <= selection.end_offset <= count:
            raise RuntimeError('Palette SQL selection checkpoint bounds')
        selections.append((selection.start_offset, selection.end_offset))
    return (editor, heading, editor.get_process_id(), text, caret, tuple(selections), selected[0])


def paste_native_palette_command(Atspi, app, objects, wait, command, labels, query,
                                  value, rows_ready, before_submit):
    """One primary GTK paste, exact read-only acknowledgements, then one Return."""
    from verify_installed_snap import paste_gtk_text
    process_id = app.get_process_id()
    caption = labels.get('Search actions…', 'Search actions…')
    def require_field(expected=None):
        query.clear_cache()
        if (query not in objects(app) or query.get_process_id() != process_id or
                query.get_name() != caption or 'EditableText' not in query.get_interfaces()):
            raise RuntimeError('Palette input owner or category changed')
        states = query.get_state_set()
        if (not all(states.contains(state) for state in
                (Atspi.StateType.FOCUSED, Atspi.StateType.SHOWING, Atspi.StateType.VISIBLE,
                 Atspi.StateType.SENSITIVE, Atspi.StateType.EDITABLE)) or
                states.contains(Atspi.StateType.READ_ONLY)):
            raise RuntimeError('Palette input is not the focused writable control')
        return Atspi.Text.get_text(query, 0, -1) == expected
    if not require_field(''):
        raise RuntimeError('New Actions search did not expose an empty query')
    original = wait(lambda: native_palette_sql_checkpoint(Atspi, objects(app), labels,
        current_nodes=lambda: objects(app)))
    window = owned_product_window(command, wait, process_id)
    command(['xdotool', 'windowfocus', '--sync', window])
    if not require_field(''):
        raise RuntimeError('Actions search changed before its single paste')
    paste_gtk_text(value, lambda: require_field(value))
    wait(rows_ready)
    restored = wait(lambda: native_palette_sql_checkpoint(Atspi, objects(app), labels,
        current_nodes=lambda: objects(app)))
    if restored != original:
        raise RuntimeError('Palette filtering changed its visible SQL owner or editing state')
    window = owned_product_window(command, wait, process_id)
    command(['xdotool', 'windowfocus', '--sync', window])
    if not require_field(value):
        raise RuntimeError('Actions search changed before its single submission')
    before_submit()
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])


def native_startup_editor_state(Atspi, nodes, labels, current_nodes):
    """Do not select either startup branch while a property scan is incomplete."""
    complete, editor = _complete_native_control_lookup(Atspi, nodes, 'SQL editor {title}',
        'EditableText', current_nodes,
        caption_match=lambda caption: native_sql_editor_label(caption, labels) is not None)
    return (('editor', editor) if editor is not None else ('welcome', None)) if complete else None


def find_live_activation(Atspi, nodes, name, current_nodes=None, alternate_names=(), menu_only=False):
    """A visible enabled node needs its real activation action, not Focus."""
    item = find_live_control(Atspi, nodes, name, current_nodes=current_nodes, activation_only=True,
                             alternate_names=alternate_names, menu_only=menu_only)
    if item is None:
        return None
    def action_names(node):
        count = Atspi.Action.get_n_actions(node)
        if not 0 <= count <= 64:
            raise RuntimeError('Native action-count budget')
        return [Atspi.Action.get_action_name(node, index) for index in range(count)]
    observed = read_live_native_controls([item], action_names, current_nodes)
    if observed is None:
        return None
    names = observed[0]
    index = next((index for index, action in enumerate(names)
                  if action in ('tap', 'Tap', 'click', 'activate', 'press')), None)
    return (item, index, names) if index is not None else None


def find_selected_value_control(Atspi, nodes, label, current_nodes=None):
    """Linux rows join field/value with a colon; Fluent merges with a newline."""
    matches = []
    for separator in (': ', '\n'):
        item = find_live_control(Atspi, nodes, label + separator,
            current_nodes=current_nodes, name_prefix=True, activation_only=True)
        if item is not None and item not in matches:
            matches.append(item)
    if len(matches) > 1:
        raise RuntimeError('Ambiguous selected-value control: ' + label)
    return matches[0] if matches else None


def find_metadata_section_control(Atspi, nodes, label, sections, current_nodes=None):
    """Keep the field name paired with its value, including merged GTK text."""
    captions = {label}
    for section in sections:
        captions.update((section, *(label + separator + section
            for separator in (': ', '\n', ' '))))
    def candidate(node):
        name = node.get_name() or ''
        # A neighbouring object path can precede the selector's full caption.
        # The last line alone loses field identity: View\nStructure belongs to
        # the representation control, not Structure\nColumns.
        if not any(name == caption or (caption != label and
                name.endswith('\n' + caption)) for caption in captions):
            return None
        return find_live_control(Atspi, [node], name, activation_only=True)
    values = read_live_native_controls(nodes, candidate, current_nodes)
    if values is None: return None
    matches = [value for value in values if value is not None]
    if len(matches) > 1:
        raise RuntimeError('Ambiguous metadata section selector')
    return matches[0] if matches else None


def find_new_menu_entry(Atspi, nodes, name, previous, fluent=False, current_nodes=None):
    """Capture a new popup entry, including genuinely disabled Fluent panels."""
    roles = {Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM}
    if fluent: roles.update((Atspi.Role.PUSH_BUTTON, Atspi.Role.PANEL))
    def candidate(node):
        if node in previous or node.get_role() not in roles: return None
        caption = node.get_name() or ''
        if (caption == name or caption.startswith(name + '\n') or caption.startswith(name + ' · ')) and node.get_state_set().contains(Atspi.StateType.SHOWING):
            return node
        return None
    values = read_live_native_controls(nodes, candidate, current_nodes)
    if values is None: return None
    matches = [value for value in values if value is not None]
    if len(matches) > 1: raise RuntimeError('Ambiguous newly opened native menu entry')
    return matches[0] if matches else None


def find_new_menu_activation(Atspi, nodes, name, previous, fluent=False, shortcut=None, current_nodes=None):
    roles = {Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM}
    if fluent: roles.update((Atspi.Role.PUSH_BUTTON, Atspi.Role.PANEL))
    labels = {name}
    if fluent and shortcut is not None: labels.add(name + '\n' + shortcut)
    def candidate(node):
        if node in previous or node.get_role() not in roles: return None
        caption = node.get_name()
        if caption not in labels: return None
        return find_live_activation(Atspi, [node], caption)
    values = read_live_native_controls(nodes, candidate, current_nodes)
    if values is None: return None
    matches = [value for value in values if value is not None]
    if len(matches) > 1: raise RuntimeError('Ambiguous newly opened native menu entry')
    return matches[0] if matches else None


def find_grid_menu_destination(Atspi, nodes, name, previous, fluent=False, current_nodes=None):
    menu = find_new_menu_activation(Atspi, nodes, name, previous, fluent=fluent, current_nodes=current_nodes)
    if menu is not None:
        return ('menu', menu)
    return None


def record_native_modal_read_unavailable(report, action, error):
    """Bounded diagnostic counters; never retain native error messages/values."""
    if action not in ('Cancel', 'Close', 'Connect'):
        raise ValueError('Unexpected acknowledged native modal action')
    notes = report.setdefault('nativeModalReadDiagnostics', {
        'unavailableWholeTreeReads': 0, 'countLimited': False})
    if notes['unavailableWholeTreeReads'] < 10000:
        notes['unavailableWholeTreeReads'] += 1
    else:
        notes['countLimited'] = True
    notes['lastAction'] = action
    cause = error.__cause__
    notes['lastUnavailableTransport'] = (
        {'domain': 'atspi_error', 'code': 1}
        if getattr(cause, 'domain', None) == 'atspi_error' and getattr(cause, 'code', None) == 1
        else None)


def wait_native_modal_retired(modal, current_nodes, wait, *, on_unavailable=None):
    """Only complete post-action reads can acknowledge the captured modal gone."""
    def absent():
        try:
            nodes = current_nodes()
        except NativeSnapshotIncomplete as error:
            # Discard the failed whole-tree observation. The existing wait
            # owns the deadline; this must never replay the acknowledged action.
            if on_unavailable is not None:
                on_unavailable(error)
            return False
        return modal not in nodes
    return wait(absent)


def wait_native_menu_retired(popup, entry, objects, wait):
    """The selected popup must retire before looking up its next dialog."""
    captured = popup if popup is not None else entry
    return wait(lambda: captured not in objects())


def activate_grid_menu_keyboard(Atspi, entry, name, caption, popup, current_nodes,
                               wait, command, *, fluent):
    """Keep Fluent focus and GTK child selection as distinct acknowledgments."""
    def current_entry():
        nodes = current_nodes()
        if entry not in nodes or (popup is not None and popup not in nodes):
            raise RuntimeError('Captured keyboard grid destination retired')
        def observe(item):
            item.clear_cache()
            return (item.get_name(), item.get_state_set(), accessible_ancestors(item))
        observed = read_live_native_controls([entry], observe, current_nodes)
        if observed is None:
            return None
        actual_caption, states, parents = observed[0]
        if actual_caption != caption:
            raise RuntimeError('Captured keyboard grid destination caption changed')
        if popup is not None and popup not in parents:
            raise RuntimeError('Captured keyboard grid destination owner changed')
        if not all(states.contains(state) for state in
                   (Atspi.StateType.SHOWING, Atspi.StateType.VISIBLE, Atspi.StateType.SENSITIVE)):
            raise RuntimeError('Captured keyboard grid destination is unavailable')
        return states.contains(Atspi.StateType.FOCUSED), parents

    initial = wait(current_entry)
    # Owned Fluent nodes may expose Selection without GTK's active-menu-child
    # behavior. Preserve their original explicit captured-entry focus path.
    menus = [] if fluent else [parent for parent in initial[1]
        if parent.get_role() == Atspi.Role.MENU and 'Selection' in parent.get_interfaces()]
    if menus:
        if len(menus) != 1 or name != 'Filter':
            raise RuntimeError('Keyboard grid destination requires one captured Filter popup')
        command(['xdotool', 'key', '--clearmodifiers', 'Down'])
        def selected():
            if current_entry() is None:
                return False
            return (Atspi.Selection.get_n_selected_children(menus[0]) == 1 and
                    Atspi.Selection.get_selected_child(menus[0], 0) == entry)
        wait(selected)
        if not selected():
            raise RuntimeError('Captured keyboard grid destination lost selection')
    else:
        focus_native_control(Atspi, entry, wait)
        acknowledged = current_entry()
        if acknowledged is None or not acknowledged[0]:
            raise RuntimeError('Captured keyboard grid destination lost focus')
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait_native_menu_retired(popup, entry, current_nodes, wait)


def find_selected_object_document(Atspi, nodes, object_name, native_name, current_nodes=None):
    """Capture the actual selected document; a selected Explorer row is separate."""
    values = read_live_native_controls(nodes, lambda node: native_query_identity(native_name(node))
        if node.get_role() == Atspi.Role.PUSH_BUTTON and
        native_tab_name(native_name(node)).startswith(object_name) and
        ' · level ' not in native_name(node) and
        node.get_state_set().contains(Atspi.StateType.SHOWING) and
        node.get_state_set().contains(Atspi.StateType.SELECTED) else None, current_nodes)
    if values is None: return None
    candidates = [value for value in values if value is not None]
    if len(candidates) > 1:
        raise RuntimeError('Ambiguous selected object document')
    return candidates[0] if candidates else None


def find_new_selected_query(Atspi, nodes, previous, native_name, current_nodes=None):
    """A previous selected tab cannot acknowledge a newly clicked console."""
    values = read_live_native_controls(nodes, lambda node: native_query_identity(native_name(node))
        if node.get_role() == Atspi.Role.PUSH_BUTTON and
        native_tab_name(native_name(node)).startswith('Query ') and
        node.get_state_set().contains(Atspi.StateType.SHOWING) and
        node.get_state_set().contains(Atspi.StateType.SELECTED) and
        native_query_identity(native_name(node)) not in previous else None, current_nodes)
    if values is None: return None
    candidates = [value for value in values if value is not None]
    if len(candidates) > 1:
        raise RuntimeError('Ambiguous newly selected query owner')
    return candidates[0] if candidates else None


def find_query_tab_activation(Atspi, nodes, identity, query_identity, native_name, current_nodes=None):
    """Dispatch by document identity even if its execution caption changes."""
    values = read_live_native_controls(nodes, lambda node: node if
                  query_identity(native_name(node)) == identity and
                  node.get_role() == Atspi.Role.PUSH_BUTTON and
                  'Action' in node.get_interfaces() and
                  node.get_state_set().contains(Atspi.StateType.SHOWING) and
                  node.get_state_set().contains(Atspi.StateType.SENSITIVE) else None, current_nodes)
    if values is None: return None
    candidates = [value for value in values if value is not None]
    if len(candidates) > 1:
        raise RuntimeError('Ambiguous physical query owner')
    if not candidates:
        return None
    item = candidates[0]
    def actions(node):
        count = Atspi.Action.get_n_actions(node)
        if not 0 <= count <= 64:
            raise RuntimeError('Native action-count budget')
        return [Atspi.Action.get_action_name(node, index) for index in range(count)]
    values = read_live_native_controls([item], actions, current_nodes)
    if values is None: return None
    names = values[0]
    activation = next((index for index, action in enumerate(names)
                       if action in ('tap', 'Tap', 'click', 'activate', 'press')), None)
    return (item, activation, names) if activation is not None else None


def native_tree_row_identity(item):
    attributes = item.get_attributes()
    identifier = attributes.get('id') if isinstance(attributes, dict) else None
    pid = item.get_process_id()
    if (not isinstance(identifier, str) or not re.fullmatch(
            r'busydata\.database\.item\.[1-9][0-9]{0,4}\.[0-9a-f]{64}', identifier) or
            type(pid) is not int or not 0 < pid < 2 ** 31):
        raise RuntimeError('Invalid native Explorer row identity')
    return pid, identifier


def find_native_tree_row(Atspi, nodes, labels, name=None, focused=False, loaded=False, settling=False, current_nodes=None, identity=None, expanded=None):
    """Require a unique actionable row; settling callers await a fresh snapshot."""
    def candidate(item):
        label = normalized_native_label(item.get_name() or '', labels)
        if (not re.match(r'^.+ · level [1-9][0-9]{0,4} · ', label) or
                (name is not None and not label.startswith(name + ' · level ')) or
                (loaded and label.endswith(' · Loading')) or
                (expanded is not None and item.get_state_set().contains(Atspi.StateType.EXPANDED) != expanded) or
                item.get_role() not in (Atspi.Role.PUSH_BUTTON, getattr(Atspi.Role, 'TREE_ITEM', Atspi.Role.PUSH_BUTTON)) or
                'Action' not in item.get_interfaces() or
                not item.get_state_set().contains(Atspi.StateType.SHOWING) or
                (focused and not item.get_state_set().contains(Atspi.StateType.FOCUSED))):
            return None
        if identity is not None and native_tree_row_identity(item) != identity:
            return None
        return item
    values = read_live_native_controls(nodes, candidate, current_nodes)
    if values is None: return None
    matches = [value for value in values if value is not None]
    if len(matches) > 1:
        if settling:
            return None
        raise RuntimeError('Ambiguous native Explorer row')
    return matches[0] if matches else None


def native_tree_navigation_step(Atspi, current_nodes, labels, expected_name):
    """One complete focused-row observation before deciding on another key."""
    def read(nodes):
        row = find_native_tree_row(Atspi, nodes, labels, focused=True,
            current_nodes=current_nodes)
        if row is None:
            return None
        def project(item):
            label = normalized_native_label(item.get_name() or '', labels)
            return item, native_tree_row_identity(item), label.startswith(expected_name + ' · level ')
        values = read_live_native_controls([row], project, current_nodes)
        return values[0] if values is not None else None
    return read_native_snapshot(current_nodes, read)


def native_tree_movement(Atspi, current_nodes, labels, expected_name, previous_identity):
    """A changed caption or rebuilt proxy cannot acknowledge a dispatched key."""
    current = native_tree_navigation_step(Atspi, current_nodes, labels, expected_name)
    if current is None:
        return None
    if current[1][0] != previous_identity[0]:
        raise RuntimeError('Native Explorer focus belongs to another application')
    return current if current[1] != previous_identity else None


def find_execution_output_menu(find):
    """Distinguish the compact menu from a regular result-set tab."""
    return find('Execution options')


def request_native_focus(Atspi, item):
    """Use the explicit semantic focus action, retaining GTK component focus."""
    if 'Action' in item.get_interfaces():
        count = Atspi.Action.get_n_actions(item)
        if not 0 <= count <= 64:
            raise RuntimeError('Native focus action-count budget')
        actions = [index for index in range(count)
            if Atspi.Action.get_action_name(item, index) in ('focus', 'Focus')]
        if len(actions) > 1:
            raise RuntimeError('Ambiguous native Focus action')
        if actions:
            if not Atspi.Action.do_action(item, actions[0]):
                raise RuntimeError('Native Focus action rejected')
            return True
    return Atspi.Component.grab_focus(item)


def focus_native_control(Atspi, item, wait):
    # Flutter omits a redundant Focus action on an already-focused field.
    # A native focus receipt is sufficient; activation still requires Action.
    def focused():
        item.clear_cache()
        return item.get_state_set().contains(Atspi.StateType.FOCUSED)
    if not focused():
        wait(lambda: focused() or request_native_focus(Atspi, item))
    wait(focused)


def focused_native_action(Atspi, current_action, wait):
    """Reacquire the live activation after its focus transition, without replay."""
    item, _ = wait(current_action)
    focus_native_control(Atspi, item, wait)
    def focused_action():
        action = current_action()
        if action is None:
            return None
        current, _ = action
        current.clear_cache()
        return action if current.get_state_set().contains(Atspi.StateType.FOCUSED) else None
    return wait(focused_action)


def focused_fluent_menu_action(Atspi, current_action, wait):
    """Read the owned focus reply before reacquiring its transient menu."""
    root = owner = pending_sequence = None
    reacquisitions = 0

    def number(attributes, name):
        value = attributes.get('busydata-' + name)
        if not isinstance(value, str) or not re.fullmatch(r'[0-9]{1,20}', value) or int(value) >= 2 ** 64:
            raise RuntimeError('Invalid Fluent focus receipt counter')
        return int(value)

    def identity(node, attributes):
        process, path = node.get_process_id(), node.path
        if (type(process) is not int or not 0 < process < 2 ** 31 or
                not isinstance(path, str) or not path.startswith('/') or len(path) > 4096):
            raise RuntimeError('Invalid Fluent focus receipt owner')
        return (process, path, number(attributes, 'bridge-epoch'), number(attributes, 'owner-epoch'))

    def observe():
        nonlocal root, owner, pending_sequence, reacquisitions
        action = None
        if root is None:
            action = current_action()
            if action is None:
                return None
            roots = []
            for node in accessible_ancestors(action[0]):
                if node.get_role() != Atspi.Role.PANEL:
                    continue
                attributes = node.get_attributes()
                if isinstance(attributes, dict) and 'busydata-status' in attributes:
                    roots.append((node, dict(attributes)))
            if len(roots) != 1:
                raise RuntimeError('Fluent focus receipt owner unavailable')
            root, attributes = roots[0]
            owner = identity(root, attributes)
        else:
            root.clear_cache()
            attributes = root.get_attributes()
            if identity(root, attributes) != owner:
                raise RuntimeError('Fluent focus destination owner changed')
        if attributes.get('busydata-status') != 'ok':
            return None
        sequence = number(attributes, 'action-sequence')
        status = None
        if pending_sequence is not None:
            if sequence < pending_sequence:
                return None
            if sequence != pending_sequence or attributes.get('busydata-action-name') != 'focus':
                raise RuntimeError('Fluent focus receipt belongs to an intervening native action')
            status = attributes.get('busydata-action-status')
            if status == 'pending':
                return None
            if (status not in ('stale', 'ok') or number(attributes, 'action-bridge-epoch') != owner[2] or
                    number(attributes, 'action-owner-epoch') != owner[3]):
                raise RuntimeError('Fluent focus receipt is not a same-owner revision refusal')
            if status == 'stale' and number(attributes, 'action-reply-revision') <= number(attributes, 'action-request-revision'):
                raise RuntimeError('Fluent focus receipt is not a same-owner revision refusal')
            if number(attributes, 'action-inflight'):
                return None
        # A pending reply can retire menu proxies. Read the stable root first;
        # reacquire the exact caption/role/menu only once a reply is available.
        action = action or current_action()
        if action is None:
            return None
        item, _ = action
        item.clear_cache()
        if item.get_state_set().contains(Atspi.StateType.FOCUSED):
            return action, reacquisitions
        if status == 'ok':
            return None
        if status == 'stale':
            reacquisitions += 1
        if sequence == 2 ** 64 - 1:
            raise RuntimeError('Fluent focus receipt sequence exhausted')
        pending_sequence = sequence + 1
        if not request_native_focus(Atspi, item):
            raise RuntimeError('Native Focus action rejected')
        return None

    return wait(observe)


def activate_fluent_menu_keyboard(Atspi, current_action, caption, role, wait,
                                  command, menus_retired):
    """Require current owned focus, then send exactly one Return."""
    def current_menu_action():
        action = current_action()
        if action is None:
            return None
        current, index, _ = action
        if (current.get_name() != caption or current.get_role() != role or
                not any(parent.get_role() == Atspi.Role.MENU
                        for parent in accessible_ancestors(current))):
            raise RuntimeError('Current Fluent menu destination changed')
        return current, index

    (current, _), reacquisitions = focused_fluent_menu_action(Atspi, current_menu_action, wait)
    current.clear_cache()
    if not current.get_state_set().contains(Atspi.StateType.FOCUSED):
        raise RuntimeError('Current Fluent menu destination lost focus')
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait(menus_retired)
    return reacquisitions


def open_native_choice_keyboard(Atspi, current_action, caption, owner, wait, command):
    """Open one captured chooser after its current focus reply; never replay Tap."""
    owner_identity = (owner.get_process_id(), owner.path)

    def current_choice():
        action = current_action()
        if action is None:
            return None
        item, index, _ = action
        if (item.get_name() != caption or item.get_role() != Atspi.Role.PUSH_BUTTON or
                not any((parent.get_process_id(), parent.path) == owner_identity
                        for parent in accessible_ancestors(item))):
            raise RuntimeError('Current native chooser destination changed')
        return item, index

    (current, _), reacquisitions = focused_fluent_menu_action(Atspi, current_choice, wait)
    current.clear_cache()
    if not current.get_state_set().contains(Atspi.StateType.FOCUSED):
        raise RuntimeError('Current native chooser lost focus')
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    return reacquisitions


class _NativeControlVisibility:
    """One reveal dispatch, followed only by current visibility observations."""
    def __init__(self, Atspi):
        self.Atspi, self.reveal_requested = Atspi, False

    def read(self, item):
        if item is None:
            return None
        item.clear_cache()
        states = item.get_state_set()
        if not all(states.contains(flag) for flag in
                   (self.Atspi.StateType.VISIBLE, self.Atspi.StateType.SHOWING)):
            if not self.reveal_requested:
                if not self.Atspi.Component.scroll_to(item, self.Atspi.ScrollType.ANYWHERE):
                    raise RuntimeError('Native control reveal rejected')
                self.reveal_requested = True
            return None
        return item


def wait_native_control_visible(Atspi, current_item, wait):
    visibility = _NativeControlVisibility(Atspi)
    return wait(lambda: visibility.read(current_item()))


def native_connection_page_marker(Atspi, nodes, caption, interface, current_nodes):
    """Read the exact page control; incomplete or disabled stays pending."""
    if interface not in ('Component', 'EditableText'):
        raise ValueError('Invalid connection page marker interface')
    available, control = _complete_native_control_lookup(Atspi, nodes, caption,
        interface, current_nodes=current_nodes)
    if not available or control is None:
        return available, control
    if interface == 'Component' and control.get_role() != Atspi.Role.CHECK_BOX:
        raise RuntimeError('Connection security page marker is not its checkbox')
    if not control.get_state_set().contains(Atspi.StateType.SENSITIVE):
        return False, None
    return True, control


def focus_live_native_control(Atspi, current_item, wait):
    """A virtualized control must acknowledge focus on its current live node."""
    visibility = _NativeControlVisibility(Atspi)
    def focused():
        item = visibility.read(current_item())
        if item is None:
            return None
        if item.get_state_set().contains(Atspi.StateType.FOCUSED):
            return item
        request_native_focus(Atspi, item)
        return None
    return wait(focused)


def _native_field_snapshot(item):
    """Read only the current owned bridge receipt, including queued actions."""
    roots = []
    for parent in accessible_ancestors(item):
        parent.clear_cache()
        attributes = parent.get_attributes()
        if isinstance(attributes, dict) and 'busydata-status' in attributes:
            roots.append((parent, attributes))
    if len(roots) != 1:
        raise RuntimeError('Native field snapshot owner unavailable')
    root, attributes = roots[0]
    def number(name, minimum=0):
        value = attributes.get('busydata-' + name)
        if (not isinstance(value, str) or not re.fullmatch(r'[0-9]{1,20}', value)
                or not minimum <= int(value) < 2 ** 64):
            raise RuntimeError('Invalid native field snapshot receipt')
        return int(value)
    process, path = root.get_process_id(), root.path
    if (type(process) is not int or not 0 < process < 2 ** 31 or
            not isinstance(path, str) or not path.startswith('/') or len(path) > 4096):
        raise RuntimeError('Invalid native field snapshot owner')
    owner = (process, path, number('bridge-epoch', 1), number('owner-epoch', 1))
    if attributes.get('busydata-status') != 'ok' or number('action-inflight'):
        return None
    return owner, number('revision', 1), number('action-sequence')


def focus_visible_native_field(Atspi, current_item, wait, minimum_height=0):
    """Await idle, stable owned semantics and geometry before one text action."""
    focus_live_native_control(Atspi, current_item, wait)
    previous = owner = None
    def revealed():
        nonlocal previous, owner
        item = current_item()
        if item is None:
            previous = None
            return None
        item.clear_cache()
        if not item.get_state_set().contains(Atspi.StateType.FOCUSED):
            previous = None
            return None
        before = _native_field_snapshot(item)
        if before is None:
            previous = None
            return None
        if owner is not None and before[0] != owner:
            raise RuntimeError('Native field snapshot owner changed')
        owner = before[0]
        bounds = Atspi.Component.get_extents(item, Atspi.CoordType.WINDOW)
        geometry = (bounds.x, bounds.y, bounds.width, bounds.height)
        count = Atspi.Text.get_character_count(item)
        caret = Atspi.Text.get_caret_offset(item)
        after = _native_field_snapshot(item)
        if after is not None and after[0] != owner:
            raise RuntimeError('Native field snapshot owner changed')
        if (after != before or bounds.width <= 0 or bounds.height <= 0 or
                bounds.height < minimum_height or not 0 <= caret <= count):
            previous = None
            return None
        observation = (after, geometry, count, caret)
        stable = previous == observation
        previous = observation
        return item if stable else None
    return wait(revealed)


def captured_native_modal_field(dialog, process_id, current_field, current_nodes):
    """Reacquire a field only inside the captured live modal and process.

    Capture after closing any choice popup. This scope does not cross popup
    retirement or accept a same-caption replacement dialog.
    """
    if dialog is None or type(process_id) is not int or not 0 < process_id < 2 ** 31:
        raise ValueError('Invalid captured native field modal')
    def read(nodes):
        field = current_field()
        if field is None:
            return None
        if dialog not in nodes:
            raise RuntimeError('Captured native field modal retired')
        if field not in nodes:
            return None
        def project(item):
            if (dialog.get_process_id() != process_id or
                    item.get_process_id() != process_id or
                    dialog not in accessible_ancestors(item)):
                raise RuntimeError('Native field left its captured modal owner')
            return item
        values = read_live_native_controls([field], project, current_nodes)
        return values[0] if values is not None else None
    return read_native_snapshot(current_nodes, read)


def right_click_native_row(Atspi, current_item, wait, command):
    # Keyboard focus reveals a scrolled row; re-resolve after the layout change.
    # SHOWING alone does not establish usable geometry in Flutter's GTK tree.
    focus_live_native_control(Atspi, current_item, wait)
    bounds = visible_native_bounds(Atspi, current_item, wait)
    if bounds.width < 16 or bounds.height < 16:
        raise RuntimeError('Clicked Explorer row has unusable bounds')
    pointer_at_native_bounds(command, bounds, button=3)


def native_menu_screen_bounds():
    # The AT-SPI registry's desktop object can retain its default 1024x768
    # rectangle even on a larger X display. GDK owns the actual popup screen.
    import gi
    gi.require_version('Gdk', '3.0')
    from gi.repository import Gdk
    root = Gdk.get_default_root_window()
    if root is None:
        raise RuntimeError('Native menu screen allocation is unavailable')
    from types import SimpleNamespace
    return SimpleNamespace(x=0, y=0, width=root.get_width(), height=root.get_height())


def visible_native_bounds(Atspi, current_item, wait):
    """Resolve stable, fully visible geometry after keyboard focus scrolls."""
    previous = None
    def revealed():
        nonlocal previous
        item = current_item()
        if item is None:
            previous = None
            return None
        item.clear_cache()
        box = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
        parents = accessible_ancestors(item)
        frame = next((parent for parent in parents
                     if parent.get_role() == Atspi.Role.FRAME), None)
        menu = None
        if frame is None:
            # GTK exposes a submenu's heading as its MENU parent, with the
            # heading's row bounds rather than the child popup's bounds. The
            # native popup can also extend beyond the application window.
            # Require an actual showing menu, then bound its pointer target by
            # the actual GDK screen allocation.
            menu = next((parent for parent in parents if parent.get_role() == Atspi.Role.MENU
                and parent.get_state_set().contains(Atspi.StateType.SHOWING)), None)
            if menu is not None:
                frame = menu
        if frame is None:
            raise RuntimeError('Native control lacks a visible window or menu viewport')
        window = (native_menu_screen_bounds() if menu is not None else
                  Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN))
        geometry = (box.x, box.y, box.width, box.height)
        if (box.width <= 0 or box.height <= 0 or
                box.x < window.x or box.y < window.y or
                box.x + box.width > window.x + window.width or
                box.y + box.height > window.y + window.height):
            previous = None
            return None
        stable = previous == geometry
        previous = geometry
        return box if stable else None
    return wait(revealed)


def set_native_inline_text(Atspi, current_item, value, wait, *, expected_original=None):
    """Acknowledge one local edit before the caller sends its commit key."""
    item = focus_visible_native_field(Atspi, current_item, wait)
    states = item.get_state_set()
    if (item.get_role() != Atspi.Role.ENTRY or
            not {'Text', 'EditableText'}.issubset(item.get_interfaces()) or
            not all(states.contains(state) for state in
                (Atspi.StateType.FOCUSED, Atspi.StateType.SHOWING,
                 Atspi.StateType.SENSITIVE, Atspi.StateType.EDITABLE)) or
            states.contains(Atspi.StateType.READ_ONLY)):
        raise RuntimeError('Inline edit requires its focused visible writable native ENTRY')
    if expected_original is not None:
        if not isinstance(expected_original, str) or len(expected_original) > 65536:
            raise ValueError('Native original-text verification bound')
        count = Atspi.Text.get_character_count(item)
        if (count != len(expected_original) or
                Atspi.Text.get_text(item, 0, count) != expected_original):
            raise RuntimeError('Native field no longer contains the captured original value')
    if not Atspi.EditableText.set_text_contents(item, value):
        raise RuntimeError('Eligible retained cell rejected its local edit')
    def acknowledged():
        current = current_item()
        if current is None:
            return None
        current.clear_cache()
        if (current.get_state_set().contains(Atspi.StateType.FOCUSED) and
                Atspi.Text.get_text(current, 0, -1) == value):
            return current
        return None
    return wait(acknowledged)


def paste_native_picker_path(Atspi, window, value, wait, command):
    """Paste only after the owned chooser acknowledges its location editor."""
    from verify_installed_snap import paste_gtk_text, picker_location_field
    command(['xdotool', 'windowfocus', '--sync', window])
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+l'])
    field = wait(lambda: picker_location_field(window))
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+a', 'BackSpace'])
    def exact(expected):
        current = picker_location_field(window)
        return current is not None and Atspi.Text.get_text(current, 0, -1) == expected
    wait(lambda: exact(''))
    paste_gtk_text(value, lambda: exact(value))
    return field


def assert_visible_protected_password(Atspi, item):
    """Require protected semantics, actual focus and complete visible geometry."""
    item.clear_cache()
    if item.get_role() != Atspi.Role.PASSWORD_TEXT:
        raise RuntimeError('Native authentication field lacks its protected password role')
    if not {'Component', 'EditableText', 'Text'} <= set(item.get_interfaces()):
        raise RuntimeError('Native protected field lacks editable text geometry')
    states = item.get_state_set()
    if not all(states.contains(getattr(Atspi.StateType, key))
               for key in ('FOCUSED', 'VISIBLE', 'SHOWING', 'SENSITIVE', 'EDITABLE')):
        raise RuntimeError('Native protected field is not focused, visible, showing and editable')

    def rectangle(node):
        bounds = Atspi.Component.get_extents(node, Atspi.CoordType.WINDOW)
        values = (bounds.x, bounds.y, bounds.width, bounds.height)
        if not all(isinstance(value, (int, float)) for value in values) or \
                not all(-2 ** 30 < value < 2 ** 30 for value in values) or \
                bounds.width <= 0 or bounds.height <= 0:
            raise RuntimeError('Native protected field has invalid visible bounds')
        return values

    bounds = rectangle(item)
    clips, forms, window = [], [], None
    labels = native_catalog_labels()
    form_names = {labels.get(name, name) for name in ('Data Sources and Drivers',)}
    for parent in accessible_ancestors(item):
        if 'Component' not in parent.get_interfaces():
            continue
        if parent.get_role() == Atspi.Role.FRAME:
            window = rectangle(parent)
        if parent.get_name() in form_names:
            forms.append(rectangle(parent))
        if 'Action' in parent.get_interfaces():
            count = Atspi.Action.get_n_actions(parent)
            if not 0 <= count <= 64:
                raise RuntimeError('Native action-count budget')
            actions = [Atspi.Action.get_action_name(parent, index) for index in range(count)]
            if any(action in ('ScrollUp', 'ScrollDown', 'ScrollLeft', 'ScrollRight',
                              'scrollUp', 'scrollDown', 'scrollLeft', 'scrollRight',
                              'scroll-up', 'scroll-down', 'Scroll Up', 'Scroll Down')
                   for action in actions):
                clips.append(rectangle(parent))
    if not clips and not forms or window is None:
        raise RuntimeError('Native protected field lacks its scroll viewport or native window')
    x, y, width, height = bounds
    if any(x < left or y < top or x + width > left + clip_width or
           y + height > top + clip_height
           for left, top, clip_width, clip_height in [*clips, *forms, window]):
        raise RuntimeError('Native protected field is offscreen or clipped')
    return {'role': item.get_role_name(), 'showing': states.contains(Atspi.StateType.SHOWING),
            'visible': True, 'focused': True, 'bounds': list(bounds),
            'scrollViewportBounds': [list(clip) for clip in clips],
            'boundedFormBounds': [list(form) for form in forms],
            'nativeWindowBounds': list(window)}


def focus_profile_password(Atspi, app, objects, wait, command, report, password_label='Password'):
    """Use real forward traversal, acknowledging each field once before entry."""
    names = (password_label,)
    for name in names:
        report['stage'] = 'native-password-forward-tab: ' + name
        command(['xdotool', 'key', '--clearmodifiers', 'Tab'])
        def focused():
            item = find_live_control(Atspi, objects(app), name, 'EditableText')
            return item if item is not None and \
                item.get_state_set().contains(Atspi.StateType.FOCUSED) else None
        item = wait(focused)
        report.setdefault('nativePasswordAcknowledgedForwardTabs', []).append(name)
    report['stage'] = 'native-password-visible-protected-focus'
    def visible():
        item = focused()
        if item is None:
            return None
        if item.get_role() != Atspi.Role.PASSWORD_TEXT:
            raise RuntimeError('Native authentication field lacks its protected password role')
        try:
            receipt = assert_visible_protected_password(Atspi, item)
        except RuntimeError as failure:
            # Focus/reveal is asynchronous. Never enter a credential through a
            # cached or clipped node; wait for the actual geometry, without
            # issuing another traversal or text action.
            report['nativePasswordLastVisibilityFailure'] = str(failure)
            return None
        report['nativeProtectedPasswordVisibility'] = receipt
        return item
    return wait(visible)


class NativeModalFocusPending(RuntimeError):
    """The native host owns focus, but no actual modal control acknowledges it."""


def native_node_observation(Atspi, item):
    """Bounded identity/state only; never read editable or password contents."""
    states = item.get_state_set()
    action_names = []
    if 'Action' in item.get_interfaces():
        count = Atspi.Action.get_n_actions(item)
        if not 0 <= count <= 64:
            raise RuntimeError('Native action-count budget')
        action_names = [Atspi.Action.get_action_name(item, i) for i in range(count)]
    record = {'path': str(getattr(item, 'path', '')),
              'role': item.get_role_name(), 'name': (item.get_name() or '')[:160],
              'interfaces': list(item.get_interfaces()), 'actions': action_names,
              **{name.lower(): states.contains(getattr(Atspi.StateType, name))
                 for name in ('FOCUSED', 'SHOWING', 'SENSITIVE', 'ENABLED', 'SELECTED')}}
    if 'Component' in item.get_interfaces():
        box = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
        record['bounds'] = {key: getattr(box, key) for key in ('x', 'y', 'width', 'height')}
    return record


def assert_modal_keyboard_focus(Atspi, nodes, outside_names, modal_name=None, observe=None, sample_hook=None):
    """Verify the live native focused node, rather than a modal-open flag."""
    focused = []
    for item in nodes:
        if item.get_state_set().contains(Atspi.StateType.FOCUSED) and not (
                   getattr(item, 'get_role', lambda: 'control')() == getattr(getattr(Atspi, 'Role', None), 'PANEL', None) and
                   not {'Action', 'EditableText', 'Text'} & set(item.get_interfaces())):
            focused.append(item)
            if sample_hook is not None:
                sample_hook(item)
    if not focused:
        raise NativeModalFocusPending('Native modal must expose one focused control')
    ancestry = {item: accessible_ancestors(item) for item in focused}
    if observe is not None:
        observe('focus-and-ancestry', focused, ancestry)
    # Each public ancestry read clears the node's cache. A real Tab can move
    # focus between the earlier state reads and this refreshed topology. Do
    # not count controls whose own fresh flag disproves the sampled set.
    for item in focused:
        item.clear_cache()
        if not item.get_state_set().contains(Atspi.StateType.FOCUSED):
            raise NativeModalFocusPending('Native focus changed during its state/ancestry read')
    # GTK also marks the engine's native host panel focused. Its descendant
    # is the actual keyboard control; unrelated focused leaves remain an error.
    leaves = [item for item in focused if not any(
        item in ancestors for other, ancestors in ancestry.items() if other != item)]
    if len(leaves) != 1:
        raise RuntimeError('Native modal must expose one focused control')
    item = leaves[0]
    container_roles = {getattr(getattr(Atspi, 'Role', None), role) for role in
                       ('APPLICATION', 'FRAME', 'WINDOW', 'DIALOG', 'PANEL',
                        'FILLER', 'SCROLL_PANE', 'VIEWPORT') if hasattr(getattr(Atspi, 'Role', None), role)}
    if (getattr(item, 'get_role', lambda: None)() in container_roles or
            not {'Action', 'EditableText'} & set(item.get_interfaces())):
        raise NativeModalFocusPending('Native modal keyboard focus has not reached its control')
    labels = native_catalog_labels()
    name = lambda node: native_control_label(node, labels)
    outside = {normalized_native_label(label, labels) for label in outside_names}
    if name(item) in outside or name(item).startswith('SQL editor'):
        raise RuntimeError('Native modal keyboard focus escaped to its workspace')
    if modal_name is not None and not any(name(parent) == normalized_native_label(modal_name, labels)
                                         for parent in ancestry[item]):
        raise RuntimeError('Native modal keyboard focus escaped its expected dialog')
    states = item.get_state_set()
    if not states.contains(Atspi.StateType.FOCUSED):
        raise NativeModalFocusPending('Native modal control no longer acknowledges keyboard focus')
    if not states.contains(Atspi.StateType.SHOWING) or not states.contains(Atspi.StateType.SENSITIVE):
        raise RuntimeError('Native modal focused a hidden or disabled control')
    return item


def wait_modal_keyboard_focus(Atspi, app, objects, wait, outside_names,
                             modal_name, previous=None, observe=None):
    """One dispatched traversal gets a bounded, fresh actual-control receipt."""
    def acknowledged():
        try:
            item = assert_modal_keyboard_focus(Atspi, objects(app), outside_names, modal_name, observe)
        except NativeModalFocusPending:
            return None
        return item if item != previous else None
    return wait(acknowledged, 15)


def reveal_native_choice_with_keyboard(Atspi, app, objects, wait, command,
                                      anchor, dialog_name, label, selected):
    """Reveal one exact choice through the captured dialog's real Tab order."""
    deadline = time.monotonic() + 15
    def bounded_wait(predicate):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError('Native choice keyboard reveal deadline')
        return wait(predicate, remaining)
    first = bounded_wait(anchor)
    states = first.get_state_set()
    if not all(states.contains(state) for state in
               (Atspi.StateType.VISIBLE, Atspi.StateType.SHOWING, Atspi.StateType.SENSITIVE)):
        raise RuntimeError('Native choice reveal anchor is hidden or disabled')
    ancestry = accessible_ancestors(first)
    dialogs = [parent for parent in ancestry if parent.get_role() == Atspi.Role.DIALOG]
    if len(dialogs) != 1 or not any(parent.get_name() == dialog_name for parent in ancestry):
        raise RuntimeError('Native choice reveal requires its exact owned dialog')
    dialog = dialogs[0]
    dialog_caption = dialog.get_name()
    captions = {label + ': ' + selected, label + '\n' + selected}
    def focused():
        nodes = objects(app)
        if dialog not in nodes:
            raise RuntimeError('Native choice reveal dialog owner changed')
        try:
            item = assert_modal_keyboard_focus(Atspi, nodes, set(), dialog_name)
        except NativeModalFocusPending:
            return None
        if dialog not in accessible_ancestors(item):
            raise RuntimeError('Native choice reveal focus escaped its captured dialog')
        return item
    if not states.contains(Atspi.StateType.FOCUSED):
        if not request_native_focus(Atspi, first):
            raise RuntimeError('Native choice reveal anchor rejected focus')
    item = bounded_wait(lambda: (current if (current := focused()) == first else None))
    for tabs in range(65):
        # Consume the exact focus receipt once. Repeating its full tree scan
        # here spends the same deadline without acknowledging another Tab.
        if item.get_name() in captions:
            expected_target, expected_role = item, item.get_role()
            def fresh_target():
                current = focused()
                if current is None:
                    return None
                if current != expected_target:
                    raise RuntimeError('Native choice reveal target changed after its focus receipt')
                return current
            target = bounded_wait(fresh_target)
            def current_target():
                # The full focus scan above proves the current modal owner and
                # focused leaf. Stable extents need only fresh reads of that
                # exact target, not another scan of every application node.
                target.clear_cache()
                parents = accessible_ancestors(target)
                if ([parent for parent in parents if parent.get_role() == Atspi.Role.DIALOG] != [dialog] or
                        dialog.get_name() != dialog_caption or
                        not any(parent.get_name() == dialog_name for parent in parents)):
                    raise RuntimeError('Native choice reveal dialog owner changed during geometry')
                if target.get_role() != expected_role:
                    raise RuntimeError('Native choice reveal target changed during geometry')
                if target.get_name() not in captions:
                    return None
                if not {'Action', 'EditableText'} & set(target.get_interfaces()):
                    return None
                state = target.get_state_set()
                if not all(state.contains(flag) for flag in
                           (Atspi.StateType.SHOWING, Atspi.StateType.SENSITIVE)):
                    raise RuntimeError('Native choice reveal target is hidden or disabled')
                return target if all(state.contains(flag) for flag in
                    (Atspi.StateType.FOCUSED, Atspi.StateType.VISIBLE,
                     Atspi.StateType.SHOWING, Atspi.StateType.SENSITIVE)) else None
            box = visible_native_bounds(Atspi, current_target, bounded_wait)
            return {'forwardTabs': tabs, 'sameDialog': True, 'focused': True,
                    'visible': True, 'showing': True, 'sensitive': True,
                    'bounds': [box.x, box.y, box.width, box.height]}
        if tabs == 64:
            raise RuntimeError('Native choice was not reached within its keyboard traversal bound')
        previous = item
        command(['xdotool', 'key', '--clearmodifiers', 'Tab'])
        item = bounded_wait(lambda: (current if (current := focused()) is not None and current != previous else None))


def native_ime_composition_active(label, caption):
    """Match the owned field's final status, never a document-title fragment."""
    if (not isinstance(label, str) or not isinstance(caption, str) or
            not caption or len(caption) > 4096):
        raise ValueError('Invalid native composition-status input')
    return label.endswith('; ' + caption)


def verify_multicaret(Atspi, editor, wait, command, report):
    """Real IME edits at two carets, checked on each native visible line."""
    report['stage'] = 'native-multicaret-multiline-input'
    text = lambda: Atspi.Text.get_text(editor, 0, -1)
    composition_caption = native_catalog_text('sqlCompositionActive')
    carets_caption = native_catalog_text('sqlActiveCarets', count='2')
    caret_template = native_catalog_message('sqlActiveCarets')
    if caret_template.count('{count}') != 1:
        raise RuntimeError('Native caret-status message requires its exact count role')
    caret_pattern = re.escape(caret_template).replace(r'\{count\}', r'[1-9][0-9]*')
    def fresh_name():
        editor.clear_cache()
        name = editor.get_name() or ''
        report['nativeMulticaretLastObservedName'] = name[:256]
        return name
    def expect_text(expected):
        def actual():
            value = text()
            report['nativeMulticaretLastObservedText'] = value[:64]
            report['nativeMulticaretExpectedText'] = expected
            return value == expected
        wait(actual)
    if not Atspi.EditableText.set_text_contents(editor, 'firstxx\nsecondx'):
        raise RuntimeError('Native multiline fixture input rejected')
    # The editor exposes its current line as a bounded native text window.
    # Verify different actual values on both lines, rather than relying on a
    # cached accessible name to tell us which line received the keyboard event.
    wait(lambda: text() == 'secondx')
    report['stage'] = 'native-multicaret-first-line'
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+Home'])
    expect_text('firstxx')
    wait(lambda: Atspi.Text.get_caret_offset(editor) == 0)
    command(['xdotool', 'key', '--clearmodifiers', 'End'])
    wait(lambda: Atspi.Text.get_caret_offset(editor) == 7)
    report['stage'] = 'native-multicaret-add-and-preedit'
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+alt+Down'])
    wait(lambda: fresh_name().endswith('; ' + carets_caption))
    command(['xdotool', 'type', '--clearmodifiers', 'a'])
    wait(lambda: text() == 'firstxx日')
    report['stage'] = 'native-multicaret-second-line-commit'
    command(['xdotool', 'key', '--clearmodifiers', 'space'])
    wait(lambda: not native_ime_composition_active(fresh_name(), composition_caption))
    command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
    command(['xdotool', 'key', '--clearmodifiers', 'Down'])
    wait(lambda: text() == 'secondx日')
    report['stage'] = 'native-multicaret-atomic-undo'
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+z'])
    # Undo restores the captured primary/secondary selections as well as both
    # lines. Its primary caret returns to the first line; it must not follow
    # the later inspection movement to the second line.
    expect_text('firstxx')
    report['stage'] = 'native-multicaret-inspect-undone-second-line'
    command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
    command(['xdotool', 'key', '--clearmodifiers', 'Down'])
    expect_text('secondx')
    report['stage'] = 'native-multicaret-restore-original-empty'
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+Home'])
    expect_text('firstxx')
    def original_selection():
        label = fresh_name()
        return (Atspi.Text.get_caret_offset(editor) == 0 and
                not native_ime_composition_active(label, composition_caption) and
                not any(re.fullmatch(caret_pattern, status) for status in label.rsplit('\n', 1)[-1].split('; ')))
    wait(original_selection)
    report['stage'] = 'native-multicaret-undo-original-input'
    control_key_until(command, wait, 'z', lambda: text() == '')
    expect_text('')
    report['nativeMulticaretImeBothLinesAndAtomicUndoVerified'] = True


def native_catalog_labels():
    """Use the actual configured locale for ordinary native UI discovery."""
    labels = {}
    settings = os.environ.get('BUSYDATA_NATIVE_SETTINGS_INPUT')
    if settings:
        import json
        language = json.loads(Path(settings).read_text())['language']
        if language != 'en':
            catalog = Path(__file__).resolve().parents[1] / 'lib/l10n'
            english = json.loads((catalog / 'app_en.arb').read_text())
            translated = json.loads((catalog / ('app_' + language + '.arb')).read_text())
            # Keep the established command/menu translation when a settings
            # heading uses a different translation of the same English word.
            for key, value in english.items():
                if (not key.startswith('@') and isinstance(value, str) and
                        isinstance(translated.get(key), str)):
                    labels.setdefault(value, translated[key])
    return labels


def native_catalog_message(key):
    """Resolve one UI role by its ARB key, including the existing fallback."""
    catalog = Path(__file__).resolve().parents[1] / 'lib/l10n'
    english = json.loads((catalog / 'app_en.arb').read_text())
    value = english[key]
    if not isinstance(value, str) or key.startswith('@'):
        raise ValueError('Native control requires a message key')
    settings = os.environ.get('BUSYDATA_NATIVE_SETTINGS_INPUT')
    if settings:
        language = json.loads(Path(settings).read_text())['language']
        if language != 'en':
            translated = json.loads((catalog / ('app_' + language + '.arb')).read_text())
            value = translated.get(key, value)
    return value


def native_catalog_text(key, **fields):
    """Resolve one bounded simple ARB message by role, without English guessing."""
    value = native_catalog_message(key)
    slots = set(re.findall(r'\{([A-Za-z_][A-Za-z_0-9]*)\}', value))
    if slots != set(fields):
        raise ValueError('Native message fields do not match its declared role')
    for name, field in fields.items():
        if not isinstance(field, str) or len(field) > 128 or any(c in field for c in ('\x00', '{', '}')):
            raise ValueError('Native message field bound')
        value = value.replace('{' + name + '}', field)
    if len(value) > 4096 or '{' in value or '}' in value:
        raise ValueError('Unsupported native message template')
    return value


def verify(Atspi, app, objects, wait, command, report, speech_contains, restart=None, reader_offset=None):
    # The real native locale remains intact. Discover controls by translated
    # catalog labels; fixture SQL/object identifiers are unchanged.
    labels = native_catalog_labels()
    def observed_any(predicate):
        return native_observe_any(objects(app), predicate, current_nodes=lambda: objects(app))
    def observed_none(predicate):
        return native_observe_none(objects(app), predicate, current_nodes=lambda: objects(app))
    def observed_first(project):
        return native_observe_first(objects(app), project, current_nodes=lambda: objects(app))
    def observed_values(project):
        return read_native_snapshot(lambda: objects(app), lambda nodes:
            read_live_native_controls(nodes, project, current_nodes=lambda: objects(app)))
    def observed_activation(nodes, name, **options):
        complete = True
        def current_proof():
            nonlocal complete
            complete = False
            return objects(app)
        action = find_live_activation(Atspi, nodes, name, current_nodes=current_proof, **options)
        return (action,) if complete else None
    def observed_missing(read):
        complete = True
        def current_proof():
            nonlocal complete
            complete = False
            return objects(app)
        value = read(current_proof)
        return value is None if complete else None
    def observed_sql_editor(accept=None):
        item = find_live_sql_editor(Atspi, objects(app), labels,
            current_nodes=lambda: objects(app))
        if item is None or accept is None:
            return item
        values = read_live_native_controls([item],
            lambda node: node if accept(node) else None, current_nodes=lambda: objects(app))
        return values[0] if values is not None else None
    def observed_field(current_field, read):
        node = current_field()
        if node is None:
            return None
        values = read_live_native_controls([node], read, current_nodes=lambda: objects(app))
        return values[0] if values is not None else None
    def selected_result_editor_owner():
        def observe(node):
            name = native_name(node)
            return native_query_identity(name) if (
                node.get_role() == Atspi.Role.PUSH_BUTTON and
                any(native_tab_name(name).startswith(object_name) for object_name in
                    ('native_atspi_fixture', 'native_atspi_child')) and
                ' · level ' not in name and
                node.get_state_set().contains(Atspi.StateType.SHOWING) and
                node.get_state_set().contains(Atspi.StateType.SELECTED)) else None
        values = observed_values(observe)
        if values is None:
            return None
        candidates = [value for value in values if value is not None]
        if len(candidates) > 1:
            raise RuntimeError('Ambiguous selected result-editor document owner')
        return candidates[0] if candidates else None

    def table_replacement():
        def captured():
            identity = selected_result_editor_owner()
            generation = (native_grid_generation(Atspi, objects(app), identity, native_name,
                current_nodes=lambda: objects(app)) if identity is not None else None)
            return generation if generation is not None and generation['completed'] else None
        return wait(captured, 30)
    def table_ready(previous, *labels, absent_labels=(), expected_rows=()):
        expected = []
        for label in labels:
            match = re.match(r'^Row ([1-9][0-9]*), (id|n): ', label)
            if match is None:
                raise RuntimeError('Native table fixture expectation has no exact source coordinate')
            expected.append((label, int(match.group(1)) - 1, 0 if match.group(2) == 'id' else 1))
        current = wait(lambda: replaced_native_grid_generation(Atspi, objects(app), previous,
            native_name, current_nodes=lambda: objects(app), expected_cells=expected,
            absent_labels=absent_labels, expected_rows=expected_rows), 30)
        proofs = report.setdefault('nativeServerResultGenerationProofs', [])
        if len(proofs) >= 32:
            raise RuntimeError('Native server result generation proof budget')
        proofs.append({'owner': current['owner'], 'previousBase': previous['source'],
            'base': current['source'], 'display': current['display'],
            'visibleCoordinates': [list(coordinate) for _, _, coordinate in current['cells']]})
        return current

    # Composite registry labels use their exact message roles. Generic duplicate
    # English words such as Text must not select a different translated key.
    for name, key in (('Table', 'resultTable'), ('Transpose', 'resultTranspose'),
                      ('Tree', 'resultTree'), ('Text', 'resultText')):
        labels['View as · ' + name] = (native_catalog_message('resultPresentation')
            + ' · ' + native_catalog_message(key))
    fluent = report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent'
    documents_menu = 'File' if fluent else 'Documents'
    def localized(label):
        if label in labels:
            return labels[label]
        for prefix in ('Expand', 'Collapse'):
            if label.startswith(prefix + ' ') and prefix in labels:
                return labels[prefix] + ' ' + labels.get(label[len(prefix) + 1:], label[len(prefix) + 1:])
        if label.startswith('Level ') and 'Level' in labels:
            return labels['Level'] + label[len('Level'):]
        if label.startswith('Row ') and 'Row' in labels:
            return labels['Row'] + label[len('Row'):]
        if re.fullmatch(r'Results [1-9][0-9]*', label) and 'Results' in labels:
            return labels['Results'] + label[len('Results'):]
        return label
    def native_name(item):
        return native_control_label(item, labels)

    def readable(item):
        # A selectable status is native Text evidence. Keep control identity
        # and activation lookup separate from the full readable value.
        return native_name(item) + '\n' + bounded_native_text(Atspi, item)

    def supports(item, interface):
        return interface in item.get_interfaces()

    selector_roles = ('Driver', 'Environment', 'Password storage', 'Mode',
                      'SSH connection', 'SSH authentication', 'Read-only policy',
                      'Results', 'Changes', 'Choose existing object')
    search_hints = ('Search actions…', 'Search current SQL…',
                    'Search database objects…', 'Search query history…')

    def find(name, interface='Action', current_nodes=None):
        nodes = objects(app)
        proof = current_nodes if current_nodes is not None else lambda: objects(app)
        if name == 'Search' and interface == 'EditableText':
            for hint in search_hints:
                field = find_live_control(Atspi, nodes, localized(hint), interface,
                                          current_nodes=proof)
                if field is not None:
                    return field
        direct = find_live_control(Atspi, nodes, localized(name), interface,
                                   current_nodes=proof)
        if direct is not None or interface != 'Action':
            return direct
        if name in selector_roles:
            return find_selected_value_control(Atspi, nodes, localized(name),
                current_nodes=proof)
        return None

    structure_sections = ('Columns', 'Indexes', 'Constraints', 'Foreign keys',
                          'Triggers', 'Open definition', 'Dependencies')

    def metadata_section_selector():
        return find_metadata_section_control(Atspi, objects(app),
            localized('Structure'), [localized(section) for section in structure_sections],
            current_nodes=lambda: objects(app))

    def activate(name, menu_only=False, dismisses_modal=True, message_key=None):
        if name == 'Documents':
            name = documents_menu
        report['stage'] = 'native-action: ' + name
        requested = native_catalog_message(message_key) if message_key else localized(name)
        # The Linux shell owns one native main menu. Category commands remain
        # the same registry entries and native submenus retain their own roles.
        snapshot = objects(app)
        exact = find_live_activation(Atspi, snapshot, requested,
            current_nodes=lambda: objects(app), menu_only=menu_only)
        if exact is None and not menu_only and not fluent and name in APPLICATION_MENU_CATEGORIES:
            activate(APPLICATION_MENU_PARENTS.get(name, 'Main menu'))
            wait(lambda: find_live_activation(Atspi, objects(app), requested,
                current_nodes=lambda: objects(app)))
        if exact is None and not menu_only and name in ('Data', 'Structure'):
            # The selected representation lives in the shared header popup.
            # Its visible/native name includes both the role and current value.
            header_names = {localized('View') + separator + localized(mode)
                            for mode in ('Data', 'Structure')
                            for separator in (': ', '\n', ' ')}
            def representation_route():
                nodes = objects(app)
                direct = observed_activation(nodes, requested)
                if direct is None:
                    return None
                if direct[0] is not None:
                    return ('direct', None)
                current = native_observe_first(nodes, lambda node: (True, node) if
                    (node.get_name() in header_names or native_name(node) in ('View: Data', 'View: Structure'))
                    and node.get_role() == Atspi.Role.PUSH_BUTTON else (False, None),
                    current_nodes=lambda: objects(app))
                return ('header', current) if current is not None else None
            route, current = wait(representation_route)
            if route == 'header':
                selected = find_live_activation(Atspi, [current], current.get_name(),
                    current_nodes=lambda: objects(app))
                if selected is None or not Atspi.Action.do_action(selected[0], selected[1]):
                    raise RuntimeError('Document representation selector rejected activation')
                wait(lambda: find_live_activation(Atspi, objects(app), requested,
                    current_nodes=lambda: objects(app), menu_only=not fluent))
        if exact is None and not menu_only and name in structure_sections:
            # Metadata sections use the same selected-value popup as Settings.
            trigger = metadata_section_selector()
            if trigger is not None:
                selected = find_live_activation(Atspi, [trigger], trigger.get_name(),
                    current_nodes=lambda: objects(app))
                if selected is None or not Atspi.Action.do_action(selected[0], selected[1]):
                    raise RuntimeError('Metadata section selector rejected activation')
                wait(lambda: find_live_activation(Atspi, objects(app), requested,
                    current_nodes=lambda: objects(app), menu_only=not fluent))
        # Preferences and connection sections use persistent selector names.
        # Opening a current value and selecting a menu option are separate acts.
        pages = {'General': ('Host', 'EditableText'),
                 'Options': ('Connection timeout · 1–120 seconds', 'EditableText'),
                 'SSH/SSL': ('Use SSL', 'Component')}
        if name in pages:
            field, interface = pages[name]
            page_visibility = _NativeControlVisibility(Atspi)
            def page_control(nodes):
                return native_connection_page_marker(Atspi, nodes,
                    localized(field), interface, current_nodes=lambda: objects(app))
        if name in pages and not menu_only:
            def page_route():
                nodes = objects(app)
                complete, control = page_control(nodes)
                if not complete:
                    return None
                if control is not None:
                    return ('ready', None) if page_visibility.read(control) is not None else None
                current = None
                for page in pages:
                    action = observed_activation(nodes, localized(page))
                    if action is None:
                        return None
                    if action[0] is not None:
                        current = page
                        break
                return ('selector', current) if current is not None and current != name else None
            route, current = wait(page_route)
            if route == 'ready':
                return
            if exact is None and current is not None and current != name:
                page_action = wait(lambda: find_live_activation(Atspi, objects(app), localized(current),
                    current_nodes=lambda: objects(app)))
                if not Atspi.Action.do_action(page_action[0], page_action[1]):
                    raise RuntimeError('Connection section selector rejected activation')
                wait(lambda: find_live_activation(Atspi, objects(app), requested,
                    current_nodes=lambda: objects(app), menu_only=not fluent))
        selector = {
            'PostgreSQL': 'Driver', 'MySQL': 'Driver', 'MariaDB': 'Driver',
            'Development': 'Environment', 'Staging': 'Environment', 'Production': 'Environment',
            'Require': 'Mode', 'Full Verification': 'Mode',
            'Never': 'Password storage',
        }.get(name)
        if exact is None and not menu_only and selector is not None and find(selector) is not None:
            return activate(selector, dismisses_modal=False)
        def live_action():
            # Connection choices now carry their persistent associated labels.
            labeled = {localized(label) + ' ' + requested for label in
                ('Driver', 'Environment', 'Password storage', 'Mode', 'SSH connection', 'SSH authentication', 'Read-only policy')}
            labeled.update(localized(label) + ': ' + requested for label in
                ('Driver', 'Environment', 'Password storage', 'Mode', 'SSH connection', 'SSH authentication', 'Read-only policy'))
            if name == 'Changes':
                labeled.update(localized('Changes') + ' ' + localized(value)
                               for value in ('Changes', 'Generated SQL'))
                labeled.update(localized('Changes') + ': ' + localized(value)
                               for value in ('Changes', 'Generated SQL'))
            # Use the same guarded snapshot for exact actions and labeled
            # choices. A retiring chooser must not trigger an unguarded scan.
            nodes = objects(app)
            direct = find_live_activation(Atspi, nodes, requested,
                current_nodes=lambda: objects(app), menu_only=menu_only)
            if direct is not None:
                return direct
            if name in selector_roles and not menu_only:
                field = find(name)
                if field is not None:
                    return find_live_activation(Atspi, [field], field.get_name(),
                        current_nodes=lambda: objects(app))
            return find_live_activation(Atspi, nodes, requested,
                current_nodes=lambda: objects(app), alternate_names=labeled,
                menu_only=menu_only)
        item, activation, names = wait(live_action)
        if menu_only:
            state = item.get_state_set()
            report.setdefault('nativeMenuOnlyActivations', []).append({
                'command': name, 'label': item.get_name(), 'role': item.get_role_name(),
                'showing': state.contains(Atspi.StateType.SHOWING),
                'enabled': state.contains(Atspi.StateType.ENABLED),
                'sensitive': state.contains(Atspi.StateType.SENSITIVE),
                'popupAncestors': [parent.get_role_name() for parent in accessible_ancestors(item)
                    if parent.get_role() == Atspi.Role.MENU],
                'action': names[activation]})
        modal = next((parent for parent in accessible_ancestors(item)
            if parent.get_role() == Atspi.Role.PANEL and parent.get_name()), None
            ) if dismisses_modal and name in ('Cancel', 'Close', 'Connect') else None
        if name in ('Test connection', 'Cancel test', 'Apply', 'OK', 'Save & connect'):
            def current_action():
                action = live_action()
                return action[0] if action is not None else None
            box = visible_native_bounds(Atspi, current_action, wait)
            frame = next(parent for parent in accessible_ancestors(item) if parent.get_role() == Atspi.Role.FRAME)
            window = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
            if (box.width <= 0 or box.height <= 0 or box.x < window.x or box.y < window.y or
                    box.x + box.width > window.x + window.width or box.y + box.height > window.y + window.height):
                raise RuntimeError('Connection completion action is outside the visible form')
            pointer_at_native_bounds(command, box)
            report.setdefault('nativeConnectionActionBounds', []).append({
                'control': name, 'coordinateSpace': 'GTK logical', 'devicePixelRatio': native_display_scale(),
                **{key: getattr(box, key) for key in ('x', 'y', 'width', 'height')}})
            return
        if name == 'Close' and report.get('nativeGridFocusAndKeyboardSelectionVerified'):
            candidates = [node for node in objects(app) if native_name(node) == name and supports(node, 'Action')]
            if len(candidates) > 8:
                raise RuntimeError('Owned modal action candidate budget')
            details = []
            for node in candidates:
                parents, parent = [], node.get_parent()
                for _ in range(8):
                    if parent is None:
                        break
                    parents.append((native_name(parent) or '')[:128])
                    parent = parent.get_parent()
                details.append({'chosen': node == item, 'parents': parents,
                    'showing': node.get_state_set().contains(Atspi.StateType.SHOWING),
                    'sensitive': node.get_state_set().contains(Atspi.StateType.SENSITIVE)})
            report['authoredFixtureModalCloseCandidates'] = details
        report['nativeActionNames'] = names
        # Flutter supplies Tap; the preserved GTK menu path supplies its native
        # click/activate action. Focus is never a substitute for activation.
        activated_role = item.get_role()
        if (fluent and name not in APPLICATION_MENU_CATEGORIES and activated_role in
                (Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM)):
            caption = item.get_name()
            focus_reacquisitions = activate_fluent_menu_keyboard(Atspi, live_action, caption, activated_role,
                wait, command, lambda: observed_none(lambda node:
                    node.get_role() == Atspi.Role.MENU and
                    node.get_state_set().contains(Atspi.StateType.SHOWING)))
            report.setdefault('nativeFluentKeyboardMenuActivations', []).append(
                {'control': name, 'caption': caption, 'input': 'one Return after current menu focus',
                 'staleFocusReacquisitions': focus_reacquisitions})
            report['nativeLastAcknowledgedActivation'] = {'control': name,
                                                         'action': 'keyboard:Return'}
        elif (not fluent and name == 'Ascending' and activated_role == Atspi.Role.PUSH_BUTTON):
            # This is the local sort-direction popup opener. Its asynchronous
            # Tap can be refused while the preceding column selection rebuilds.
            # A current owned focus reply followed by one Return opens it
            # without treating a queued/stale Tap as an acknowledgement.
            choice_owner = next(parent for parent in accessible_ancestors(item)
                if parent.get_role() == Atspi.Role.PANEL and parent.get_name())
            reacquisitions = open_native_choice_keyboard(Atspi, live_action,
                item.get_name(), choice_owner, wait, command)
            report.setdefault('nativeChoiceKeyboardOpenings', []).append({
                'control': name, 'input': 'one Return after current chooser focus',
                'staleFocusReacquisitions': reacquisitions})
            report['nativeLastAcknowledgedActivation'] = {'control': name,
                                                         'action': 'keyboard:Return'}
        else:
            activated_role = dispatch_native_activation(Atspi, item, activation)
            report['nativeLastAcknowledgedActivation'] = {'control': name,
                                                         'action': names[activation]}
        if modal is not None:
            wait_native_modal_retired(modal, lambda: objects(app), wait,
                on_unavailable=lambda error: record_native_modal_read_unavailable(report, name, error))
        page_field = {'General': 'Host', 'SSH/SSL': 'Use SSL',
                      'Options': 'Connection timeout · 1–120 seconds'}.get(name)
        if page_field is not None:
            def page_ready():
                complete, control = page_control(objects(app))
                return page_visibility.read(control) if complete else None
            wait(page_ready)
        if name not in APPLICATION_MENU_CATEGORIES and (names[activation] in ('click', 'activate', 'press') or activated_role in (Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM)):
            wait(lambda: observed_none(lambda node: node.get_role() == Atspi.Role.MENU and node.get_state_set().contains(Atspi.StateType.SHOWING)))

    def focus(item):
        focus_native_control(Atspi, item, wait)

    def grid_menu(nodes=None):
        nodes = objects(app) if nodes is None else nodes
        def candidate(node):
            caption = native_name(node)
            if scoped_grid_menu_caption(caption, [native_name(parent)
                    for parent in accessible_ancestors(node)]):
                return find_live_activation(Atspi, [node], node.get_name())
            return None
        values = read_live_native_controls(nodes, candidate, current_nodes=lambda: objects(app))
        if values is None:
            return None
        matches = [value for value in values if value is not None]
        if len(matches) > 1:
            raise RuntimeError('Ambiguous visible grid menu trigger')
        return matches[0] if matches else None

    def grid_action(name, menu_only=False, interaction='accessibility', owner=None):
        report['stage'] = 'native-grid-action: ' + name
        transition = {'action': name, 'interaction': interaction, 'snapshots': []}
        report.setdefault('nativeGridMenuTransitions', []).append(transition)
        flyout_pending = False
        def observe(phase, trigger=None):
            nodes = objects(app)
            if owner is not None and not assert_current_grid_owner(Atspi, nodes, owner,
                    flyout_pending=flyout_pending):
                transition.setdefault('backgroundOwnerScopes', []).append(phase)
            def project(node):
                relevant = (node.get_role() in
                (Atspi.Role.MENU, Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM)
                or (node.get_state_set().contains(Atspi.StateType.SELECTED) and
                    node.get_role() == Atspi.Role.PUSH_BUTTON)
                or native_name(node).startswith(('More', 'Row selection', 'Completed', 'Running', 'Loading', 'Queued'))
                or native_name(node) in ('Stop', 'Filter'))
                return native_node_observation(Atspi, node) if relevant else None
            values = read_live_native_controls(nodes, project, current_nodes=lambda: objects(app))
            complete = values is not None
            snapshot = {'phase': phase, 'availability': 'available' if complete else 'incomplete'}
            if complete:
                snapshot['nodes'] = [value for value in values if value is not None][:40]
            if trigger is not None:
                snapshot['triggerLive'] = trigger in nodes
                snapshot['trigger'] = {'path': str(getattr(trigger, 'path', ''))}
                if trigger in nodes:
                    def trigger_observation(node):
                        node.clear_cache()
                        return native_node_observation(Atspi, node), [native_node_observation(Atspi, parent)
                            for parent in accessible_ancestors(node)[:12]]
                    records = read_live_native_controls([trigger], trigger_observation,
                        current_nodes=lambda: objects(app))
                    if records is None:
                        complete = False
                        snapshot['availability'] = 'incomplete'
                        snapshot.pop('nodes', None)
                    else:
                        snapshot['trigger'], snapshot['parents'] = records[0]
            previous = transition['snapshots'][-1] if transition['snapshots'] else None
            if len(transition['snapshots']) < 24 and snapshot != previous:
                transition['snapshots'].append(snapshot)
            return nodes if complete else None
        def current_route():
            # A result replacement can reflow the header between native tree
            # snapshots. Resolve either the current toolbar or its scoped menu.
            nodes = objects(app)
            if not menu_only:
                direct = observed_activation(nodes, localized(name))
                if direct is None:
                    return None
                if direct[0] is not None:
                    return ('toolbar', None, nodes)
            menu = grid_menu(nodes)
            return ('menu', menu, nodes) if menu is not None else None
        route, menu, nodes = wait(current_route)
        if route == 'menu':
            # The trigger and pre-popup identities must come from the same
            # lookup, not another traversal during which it can retire.
            previous = set(nodes)
            if owner is not None:
                assert_current_grid_owner(Atspi, nodes, owner)
            item, activation, _ = menu
            transition['snapshots'].append({'phase': 'before-activation',
                'trigger': native_node_observation(Atspi, item),
                'parents': [native_node_observation(Atspi, parent) for parent in accessible_ancestors(item)[:12]]})
            if interaction == 'pointer':
                box = visible_native_bounds(Atspi, lambda: grid_menu(objects(app))[0], wait)
                pointer_at_native_bounds(command, box)
            elif interaction == 'keyboard':
                focus_live_native_control(Atspi, lambda: grid_menu(objects(app))[0], wait)
                # Fluent's existing button uses ActivateIntent (Enter); the
                # Linux native-menu button additionally opens with Down.
                opening_key = 'Return' if report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent' else 'Down'
                command(['xdotool', 'key', '--clearmodifiers', opening_key])
            elif not Atspi.Action.do_action(item, activation):
                raise RuntimeError('Visible grid menu rejected activation')
            flyout_pending = report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent'
            try:
                def current_destination():
                    current = observe('after-activation', item)
                    return (find_grid_menu_destination(Atspi, current, localized(name), previous,
                        fluent=report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent',
                        current_nodes=lambda: objects(app)) if current is not None else None)
                destination = wait(current_destination)
            except Exception:
                observe('failed', item)
                raise
            observe('destination-acknowledged', item)
            entry = destination[1][0]
            popup = next((parent for parent in accessible_ancestors(entry)
                if parent.get_role() == Atspi.Role.MENU), None)
            if name == 'Filter' and report.get('nativeDesignerDefinitionNestedModalAndKeyboardCloseVerified'):
                windows = command(['xdotool', 'search', '--all', '--onlyvisible', '--pid',
                    str(app.get_process_id()), '--name', '^BusyData$'], capture_output=True, text=True).stdout.splitlines()
                transition['popupWindows'] = [{'id': xid,
                    'types': command(['xprop', '-id', xid, '_NET_WM_WINDOW_TYPE'],
                        capture_output=True, text=True).stdout[:1024],
                    'windowInfo': command(['xwininfo', '-id', xid],
                        capture_output=True, text=True).stdout[:4096]} for xid in windows[:8]]
                photograph_product(Atspi, app, objects, wait, command, report,
                    'table-filter-popup-' + interaction, resize=False)
            if interaction == 'pointer':
                pointer_at_native_bounds(command, visible_native_bounds(Atspi, lambda: entry, wait))
                wait_native_menu_retired(popup, entry, lambda: objects(app), wait)
                return
            if interaction == 'keyboard':
                activate_grid_menu_keyboard(Atspi, entry, name, localized(name), popup,
                    lambda: objects(app), wait, command, fluent=fluent)
                return
        elif interaction != 'accessibility':
            item = wait(lambda: find(name))
            if interaction == 'pointer':
                pointer_at_native_bounds(command, visible_native_bounds(Atspi, lambda: item, wait))
            else:
                focus_native_control(Atspi, item, wait)
                command(['xdotool', 'key', '--clearmodifiers', 'Return'])
            return
        activate(name)

    def palette(label):
        report['stage'] = 'native-palette: ' + label
        wait(lambda: observed_none(lambda node: node.get_role() == Atspi.Role.MENU and node.get_state_set().contains(Atspi.StateType.SHOWING)))
        window = owned_product_window(command, wait, app.get_process_id())
        command(['xdotool', 'windowfocus', '--sync', window])
        report['stage'] = 'native-palette-open: ' + label
        query = control_key_until(command, wait, 'p', lambda: find_live_control(Atspi,
            objects(app), localized('Search actions…'), 'EditableText',
            current_nodes=lambda: objects(app)), shift=True)
        focus(query)
        def palette_rows():
            values = observed_values(lambda item: (item.get_name() or '') if
                item.get_role() == Atspi.Role.PUSH_BUTTON and
                item.get_state_set().contains(Atspi.StateType.SHOWING) else None)
            return (palette_rows_ready([value for value in values if value is not None], label, labels)
                    if values is not None else None)
        def before_submit():
            report['stage'] = 'native-palette-submit: ' + label
        paste_native_palette_command(Atspi, app, objects, wait, command, labels, query,
            localized(label), palette_rows, before_submit)
        def closed():
            values = observed_values(lambda item:
                {name: item.get_state_set().contains(getattr(Atspi.StateType, name.upper()))
                 for name in ('showing', 'visible', 'focused', 'sensitive')}
                if native_name(item) in search_hints and supports(item, 'EditableText') else None)
            if values is None:
                return None
            fields = [value for value in values if value is not None]
            report['nativePaletteRemainingFields'] = fields
            return not any(field['showing'] or field['focused'] for field in fields)
        wait(closed)

    def physical_session_details():
        # The palette captures the focused Explorer or result document owner.
        # Read the existing localized field; never infer a physical UUID from
        # a display label, metadata identity, or another console's toolbar.
        palette('Session details')
        title = 'Session details'
        wait(lambda: observed_any(lambda node: native_name(node) == title and
            node.get_role() == Atspi.Role.HEADING and
            node.get_state_set().contains(Atspi.StateType.SHOWING)))
        def identity():
            values = observed_values(lambda node: native_physical_session_identity(
                bounded_native_text(Atspi, node, 4096),
                native_catalog_message('physicalSessionLabel')) if
                node.get_state_set().contains(Atspi.StateType.SHOWING) else None)
            if values is None:
                return None
            candidates = {value for value in values if value is not None}
            if len(candidates) > 1:
                raise RuntimeError('Session details exposes multiple physical owners')
            return next(iter(candidates)) if candidates else None
        session_id = wait(identity)
        activate('Cancel')
        wait(lambda: observed_none(lambda node: native_name(node) == title and
            node.get_role() == Atspi.Role.HEADING and
            node.get_state_set().contains(Atspi.StateType.SHOWING)))
        return session_id

    def open_selected_explorer_table(previous, *,
            proof_key='nativeExplorerSelectedSessionBrowseProof',
            previous_source_observation=None):
        # Callers capture the actual visible SQL result before Explorer focus
        # (and before PG switches its attached output to Explain/Plan). Do not
        # assume that the old grid remains rendered after closing a Plan tab.
        checkpoint = wait(lambda: native_palette_sql_checkpoint(Atspi, objects(app),
            labels, current_nodes=lambda: objects(app)))
        if (checkpoint == (None,) or checkpoint[-1] !=
                (previous['document'], previous['context'])):
            raise RuntimeError('Explorer browse lost the captured preceding SQL document context')
        def explorer_table():
            return find_native_tree_row(Atspi, objects(app), labels,
                'native_atspi_fixture', current_nodes=lambda: objects(app))
        # Session details captures the focused context. After restoration the
        # SQL console and Explorer have separately authenticated physical owners;
        # establish Explorer focus before asking for its session, then reacquire
        # the row after the modal retires.
        focus_live_native_control(Atspi, explorer_table, wait)
        explorer_session = physical_session_details()
        focus_live_native_control(Atspi, explorer_table, wait)
        rectangle = visible_native_bounds(Atspi, lambda: find_native_tree_row(
            Atspi, objects(app), labels, 'native_atspi_fixture', focused=True,
            current_nodes=lambda: objects(app)), wait)
        report['nativeTableDoubleClickBounds'] = {
            key: getattr(rectangle, key) for key in ('x', 'y', 'width', 'height')}
        report['stage'] = 'native-explorer-double-click-selected-session-table'
        pointer_at_native_bounds(command, rectangle, repeat=2)
        # Standard fixtures explicitly select STAGING; ordinary MySQL retains
        # the form's DEVELOPMENT default. ReviewBrowse/token is still mandatory
        # in Java; neither policy presents a PRODUCTION risk-confirmation UI.
        expected_rows = (('1', '漢😀'), ('2', 'second'))
        def completed_browse():
            document = find_selected_object_document(Atspi, objects(app),
                'native_atspi_fixture', native_name, current_nodes=lambda: objects(app))
            generation = native_grid_generation(Atspi, objects(app), document,
                native_name, current_nodes=lambda: objects(app)) if document else None
            return native_fresh_browse_generation(previous, generation, expected_rows)
        report['stage'] = 'native-reviewed-browse-new-owned-result'
        generation = wait(completed_browse, 30)
        def exact_cell():
            current = completed_browse()
            return find_keyed_grid_cell(Atspi, objects(app), 'id', '1', 'n', '漢😀',
                native_name, owner=current['tab'], current_nodes=lambda: objects(app)) if current else None
        focus_live_native_control(Atspi, exact_cell, wait)
        data_session = physical_session_details()
        report[proof_key + 'SessionCheck'] = {
            'explorerPhysicalSession': explorer_session,
            'dataPhysicalSession': data_session,
            'samePhysicalSession': data_session == explorer_session}
        if data_session != explorer_session:
            raise RuntimeError('Data browsing changed the explicitly selected Explorer physical session')
        current = wait(completed_browse, 30)
        if any(current[key] != generation[key] for key in ('owner', 'source', 'display', 'context')):
            raise RuntimeError('Session details changed the captured browse result owner')
        focus_live_native_control(Atspi, exact_cell, wait)
        palette('SQL provenance')
        report['stage'] = 'native-reviewed-browse-generated-sql-provenance'
        title = 'SQL · text'
        wait(lambda: observed_any(lambda node: native_name(node) == title and
            node.get_role() == Atspi.Role.HEADING and
            node.get_state_set().contains(Atspi.StateType.SHOWING)))
        expected_sql = ('SELECT * FROM "public"."native_atspi_fixture"' if postgres else
            'SELECT * FROM `busydata`.`native_atspi_fixture`')
        wait(lambda: observed_any(lambda node: bounded_native_text(Atspi, node, 4096) == expected_sql))
        activate('Close')
        wait(lambda: observed_none(lambda node: native_name(node) == title and
            node.get_role() == Atspi.Role.HEADING and
            node.get_state_set().contains(Atspi.StateType.SHOWING)))
        current = wait(completed_browse, 30)
        if any(current[key] != generation[key] for key in ('owner', 'source', 'display', 'context')):
            raise RuntimeError('SQL provenance changed the captured browse result owner')
        report[proof_key] = {
            'explorerPhysicalSession': explorer_session, 'dataPhysicalSession': data_session,
            'document': current['document'], 'owner': current['owner'],
            'source': current['source'], 'display': current['display'],
            'previousDocument': previous['document'], 'previousOwner': previous['owner'],
            'previousSource': previous['source'],
            'previousSourceObservation': previous_source_observation or (
                'visible retained view before Explain/Plan' if postgres else
                'visible query result before Explorer browse'),
            'completed': current['completed'], 'expectedRows': [list(row) for row in expected_rows],
            'visibleCoordinates': [list(coordinate) for _, _, coordinate in current['cells']],
            'generatedSql': expected_sql, 'generatedSqlSha256': hashlib.sha256(expected_sql.encode()).hexdigest(),
            'reviewAdmissionEvidence': 'Java mandatory ReviewBrowse token contract; native UI proves completed owned browse, not RPC ordering',
            'environmentPolicy': 'DEVELOPMENT' if ordinary_mysql else 'STAGING',
            'passwordReacquisitionRequested': False}
        report['nativeOpenedTableDocumentIdentity'] = current['document']
        report['nativeTableDoubleClickOwnedDataVerified'] = True
        return current['document']

    def photograph(label, protected_form=False):
        photograph_product(Atspi, app, objects, wait, command, report, label, protected_form=protected_form)

    def refresh_grid():
        previous = table_replacement()
        report['stage'] = 'native-visible-grid-refresh'
        def scoped_action():
            current = objects(app)
            def project(item):
                parents = accessible_ancestors(item)
                record = ({'control': native_node_observation(Atspi, item),
                    'parents': [native_name(parent)[:256] for parent in parents]}
                    if native_name(item) == localized('Refresh') else None)
                scoped = any(native_name(parent).splitlines()[0:1] == ['Results'] for parent in parents)
                return item, record, scoped
            values = read_live_native_controls(current, project, current_nodes=lambda: objects(app))
            if values is None:
                return None
            observation = [record for _, record, _ in values if record is not None]
            nodes = [item for item, _, scoped in values if scoped]
            result = observed_activation(nodes, localized('Refresh'))
            if result is None:
                return None
            history = report.setdefault('nativeGridRefreshOwnerObservations', [])
            if len(history) < 24 and (not history or history[-1] != observation):
                history.append(observation)
            return result
        def refresh_route():
            result = scoped_action()
            if result is None:
                return None
            return (('toolbar', result[0]) if result[0] is not None else
                    ('menu', None) if grid_menu() is not None else None)
        choice = wait(refresh_route)
        if choice[0] == 'menu':
            grid_action('Refresh', menu_only=True, owner=previous['tab'])
            table_ready(previous)
            return
        item, _, _ = choice[1]
        bounds = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
        frame = next(parent for parent in accessible_ancestors(item)
                     if parent.get_role() == Atspi.Role.FRAME)
        window = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
        if (bounds.width <= 0 or bounds.height <= 0 or
                bounds.x < window.x or bounds.y < window.y or
                bounds.x + bounds.width > window.x + window.width or
                bounds.y + bounds.height > window.y + window.height):
            raise RuntimeError('Grid Refresh is outside the visible document')
        pointer_at_native_bounds(command, bounds)
        table_ready(previous)

    photograph('first-run-disconnected')
    report['stage'] = 'visible-explorer-new-connection'
    new = wait(lambda: find_live_activation(Atspi, objects(app), localized('New connection'), current_nodes=lambda: objects(app)))[0]
    xid = owned_product_window(command, wait, app.get_process_id())
    command(['xdotool', 'windowfocus', '--sync', xid])
    scale = native_display_scale()
    command(['xdotool', 'windowsize', xid, str(1366 * scale), str(768 * scale)])
    rectangle = visible_native_bounds(Atspi, lambda: find('New connection'), wait)
    pointer_at_native_bounds(command, rectangle)
    wait(lambda: find('Name', 'EditableText'))
    source = Path(os.environ['BUSYDATA_NATIVE_FIXTURE_DIRECTORY'])
    engine = os.environ.get('BUSYDATA_NATIVE_FIXTURE_ENGINE', 'POSTGRESQL')
    postgres = engine == 'POSTGRESQL'
    if not postgres:
        activate('PostgreSQL')
        activate('MySQL' if engine == 'MYSQL' else 'MariaDB')
        wait(lambda: observed_field(lambda: find('Port', 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == '3306'))
        report['nativeEngineDefaultPortVerified'] = True
    report['stage'] = 'native-selected-driver-value'
    selected_driver = {'POSTGRESQL': 'PostgreSQL', 'MYSQL': 'MySQL', 'MARIADB': 'MariaDB'}[engine]
    driver = wait(lambda: find('Driver'))
    if localized('Driver') not in driver.get_name() or selected_driver not in driver.get_name():
        raise RuntimeError('Native selector omitted its field or selected value')
    driver_caption = driver.get_name()
    report['nativeSelectedDriverName'] = driver_caption
    driver = focus_live_native_control(Atspi, lambda: find('Driver'), wait)
    if driver.get_name() != driver_caption:
        raise RuntimeError('Native selected driver changed during focus acquisition')
    wait(lambda: speech_contains([driver_caption]))
    report['nativeSelectedValueAndReaderVerified'] = True
    def supply_password(field):
        secret = (source / 'password').read_text()
        if not Atspi.EditableText.set_text_contents(field, secret):
            raise RuntimeError('Native protected input rejected')
        wait(lambda: observed_field(lambda: find('Password', 'EditableText'), lambda observed_node: Atspi.Text.get_character_count(observed_node) == len(secret)))

    def set_profile_field(label, value):
        report['stage'] = 'native-profile-field: ' + label
        field = focus_visible_native_field(Atspi, lambda: find(label, 'EditableText'), wait)
        protected = field.get_role() == Atspi.Role.PASSWORD_TEXT or any(
            marker in label.lower() for marker in ('password', 'passphrase'))
        if protected:
            if field.get_role() != Atspi.Role.PASSWORD_TEXT:
                raise RuntimeError('Native credential field lacks protected semantics')
            # Protected values never enter process arguments or diagnostics.
            if not Atspi.EditableText.set_text_contents(field, value):
                raise RuntimeError('Native protected input rejected')
            try:
                wait(lambda: observed_field(lambda: find(label, 'EditableText'), lambda observed_node: Atspi.Text.get_character_count(observed_node) == len(value)))
            except TimeoutError:
                current = find(label, 'EditableText')
                if current is not None:
                    current.clear_cache()
                    bounds = Atspi.Component.get_extents(current, Atspi.CoordType.WINDOW)
                    report['nativeProtectedInputFailure'] = {
                        'field': label, 'role': current.get_role_name(),
                        'expectedCharacters': len(value),
                        'actualCharacters': Atspi.Text.get_character_count(current),
                        'focused': current.get_state_set().contains(Atspi.StateType.FOCUSED),
                        'showing': current.get_state_set().contains(Atspi.StateType.SHOWING),
                        'bounds': {key: getattr(bounds, key) for key in ('x','y','width','height')}}
                raise
        else:
            # Exercise ordinary keyboard editing after the native IME/modal
            # transitions, including a real empty-value edit.
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+a'])
            command(['xdotool', 'key', '--clearmodifiers', 'BackSpace'])
            # A same-value replacement must first acknowledge the clear. The
            # previous value cannot certify queued X input in the new draft.
            wait(lambda: observed_field(lambda: find(label, 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == ''))
            if len(value) > 64:
                # Long fixture paths use the real desktop clipboard. Flooding
                # Orca's synchronous key listener with an artificial burst can
                # leave queued characters beyond the field's deadline. Short
                # fields above still exercise ordinary character input.
                from verify_installed_snap import paste_gtk_text
                paste_gtk_text(value, lambda: Atspi.Text.get_text(
                    find(label, 'EditableText'), 0, -1) == value)
                report.setdefault('nativeNonsecretClipboardFields', []).append(label)
            elif value:
                # Orca's synchronous key listener must consume each ordinary
                # keystroke, including on a busy desktop. Do not send a burst
                # whose trailing events remain queued beyond acknowledgement.
                command(['xdotool', 'type', '--clearmodifiers', '--delay', '40', '--', value])
            try:
                wait(lambda: observed_field(lambda: find(label, 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == value))
            except TimeoutError:
                actual = Atspi.Text.get_text(find(label, 'EditableText'), 0, -1)
                report['nativeNonsecretFieldAcknowledgement'] = {
                    'label': label, 'expectedCharacters': len(value),
                    'actualCharacters': len(actual),
                    'matchesExpected': actual == value,
                    'hasExpectedPrefix': actual.startswith(value[:16]),
                    'hasExpectedSuffix': actual.endswith(value[-16:]),
                    'keyboardEngine': command(['ibus', 'engine'], capture_output=True, text=True).stdout.strip(),
                }
                photograph_product(Atspi, app, objects, wait, command, report,
                    'nonsecret-field-acknowledgement', sizes=((1366,768),), protected_form=True)
                report['stage'] = 'native-profile-field: ' + label
                raise
    if os.environ.get('BUSYDATA_NATIVE_VERIFY_MANAGER_EDGES') == '1':
        import json
        ssh_source = source / 'ssh-editor'
        endpoint = json.loads((ssh_source / 'endpoint.json').read_text())
        def ssh_metrics():
            return json.loads((ssh_source / 'metrics.json').read_text())
        before = ssh_metrics()
        activate('Delete connection')
        wait(lambda: observed_any(lambda item: native_name(item) == 'No connections yet'))
        activate('Apply')
        wait(lambda: observed_any(lambda item: 'Configuration applied' in readable(item)))
        photograph('manager-empty-unsaved')
        activate('Save & connect')
        wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)))
        activate('New connection')
        wait(lambda: find('Name', 'EditableText'))
        for label, value in [('Name', 'Disposable SSH editor source'), ('Host', '127.0.0.1'),
                             ('Port', '1'), ('User', ''), ('Database', 'unavailable_database')]:
            set_profile_field(label, value)
        activate('SSH/SSL')
        activate('Use SSH tunnel')
        activate('SSH configuration', message_key='sshConfigurationLabel')
        for label, value in [('SSH host', endpoint['host']), ('SSH port', str(endpoint['port'])),
                             ('SSH user', endpoint['user']), ('Reviewed known_hosts file', str(ssh_source / 'known_hosts')),
                             ('SSH password', (ssh_source / 'password').read_text())]:
            set_profile_field(label, value)
        before_review = set(objects(app))
        activate('Review SSH host key')
        # The read-only selectable fingerprint is rendered in the confirmation.
        # Await the newly opened confirmation, fencing the initiating editor
        # action even before its disabled semantics arrive. Capture its key.
        wait(lambda: find_live_activation(Atspi,
            [node for node in objects(app) if node not in before_review], localized('Review SSH host key'), current_nodes=lambda: objects(app)))
        photograph('ssh-host-review-invalid-general', protected_form=True)
        activate('Cancel')
        wait(lambda: find('SSH host', 'EditableText'))
        def ssh_succeeded():
            # Shared status boxes use selectable Text values; GTK can expose
            # that evidence through Text rather than the accessible name.
            return observed_any(lambda item: 'Connected · SSH · ssh-user@127.0.0.1:' in (item.get_name() or '') + bounded_native_text(Atspi, item))
        activate('Test connection')
        try:
            wait(ssh_succeeded, 20)
        except TimeoutError:
            report['nativeSshTestFixtureObservation'] = ssh_metrics()
            photograph('ssh-test-feedback-deadline', protected_form=True)
            raise
        wait(lambda: ssh_metrics()['activeSessions'] == 0)
        if ssh_metrics()['forwards'] != before['forwards']:
            raise RuntimeError('Nested SSH test forwarded a database connection')
        photograph('ssh-test-empty-database-user', protected_form=True)
        activate('OK')
        wait(lambda: observed_missing(lambda proof: find('SSH host', 'EditableText', current_nodes=proof)))
        activate('General', message_key='generalSettings')
        if Atspi.Text.get_text(find('User', 'EditableText'), 0, -1) != '':
            raise RuntimeError('SSH test replaced General values')
        set_profile_field('User', 'database-user')
        activate('SSH/SSL')
        activate('SSH configuration', message_key='sshConfigurationLabel')
        activate('Test connection')
        wait(ssh_succeeded, 20)
        wait(lambda: ssh_metrics()['activeSessions'] == 0)
        if ssh_metrics()['forwards'] != before['forwards']:
            raise RuntimeError('SSH authentication depended on database availability')
        photograph('ssh-test-unavailable-database', protected_form=True)
        activate('OK')
        wait(lambda: observed_missing(lambda proof: find('SSH host', 'EditableText', current_nodes=proof)))
        activate('General', message_key='generalSettings')
        activate('Test connection')
        failures = ('The endpoint could not be reached.', 'Connection unavailable.',
                    'Connection was not completed.', 'Connection timed out.')
        wait(lambda: observed_any(lambda item: any((text in readable(item) for text in failures))), 30)
        photograph('main-test-unavailable-database', protected_form=True)
        for label in ('Test connection', 'Cancel', 'Apply', 'Save & connect'):
            visible_native_bounds(Atspi, lambda label=label: find(label), wait)
        activate('Apply')
        wait(lambda: observed_any(lambda item: 'Configuration applied' in readable(item)))
        activate('Delete connection')
        wait(lambda: observed_any(lambda item: native_name(item) == 'No connections yet'))
        activate('Apply')
        wait(lambda: observed_any(lambda item: 'Configuration applied' in readable(item)))
        photograph('manager-empty-saved-deletion')
        activate('Cancel')
        wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)))
        if find_native_tree_row(Atspi, objects(app), labels, 'Disposable SSH editor source', current_nodes=lambda: objects(app)) is not None:
            raise RuntimeError('Cancel undid the acknowledged source deletion')
        report['nativeSshEditorAndEmptyManagerVerified'] = {
            'passed': True, 'emptyDatabaseUserAcceptedForSshTest': True,
            'unavailableDatabaseAcceptedForSshTest': True, 'hostReviewIndependentOfGeneral': True,
            'sshAuthenticationAttempts': ssh_metrics()['authentications'] - before['authentications'],
            'sshTestsRequestedNoDatabaseForward': True, 'mainDatabaseTestStillFailed': True,
            'soleUnsavedSourceRemovedWithoutReplacement': True,
            'soleSavedSourceDeletionAppliedWithoutReplacement': True,
            'cancelPreservedAcknowledgedDeletion': True}
        activate('New connection')
        wait(lambda: find('Name', 'EditableText'))
    for label, value in [('Name', 'Native accessibility fixture'), ('Host', '127.0.0.1'),
                         ('Port', os.environ['BUSYDATA_NATIVE_FIXTURE_PORT']), ('Database', 'busydata'), ('User', 'busydata' if postgres or os.environ.get('BUSYDATA_NATIVE_ORDINARY_MYSQL') == '1' else 'root'), ('Password', 'wrong-disposable-password')]:
        set_profile_field(label, value)
    for label in ('Test connection', 'Cancel', 'Apply', 'Save & connect'):
        item = wait(lambda: find(label))
        rectangle = Atspi.Component.get_extents(item, Atspi.CoordType.WINDOW)
        if rectangle.height <= 0 or rectangle.y < 0 or rectangle.y + rectangle.height > 768:
            raise RuntimeError('Connection action is outside the visible form: ' + label)
    photograph_product(Atspi, app, objects, wait, command, report, 'connection-general', sizes=((1366,768),(1920,1080)), protected_form=True)
    ordinary_mysql = os.environ.get('BUSYDATA_NATIVE_ORDINARY_MYSQL') == '1'
    if not ordinary_mysql:
        activate('SSH/SSL')
        activate('Use SSL')
        def checked_ssl_anchor():
            field = find('Use SSL')
            return field if field is not None and field.get_state_set().contains(Atspi.StateType.CHECKED) else None
        report['nativeTlsModeKeyboardReveal'] = reveal_native_choice_with_keyboard(
            Atspi, app, objects, wait, command, anchor=checked_ssl_anchor,
            dialog_name=native_catalog_text('managerTitle'),
            label=localized('Mode'), selected=localized('Require'))
        activate('Require')
        activate('Full Verification')
        set_profile_field('CA certificate file', str(source / 'ca.crt'))
    photograph_product(Atspi, app, objects, wait, command, report, 'connection-driver-default-general' if ordinary_mysql else 'connection-ssh-ssl', protected_form=True)
    if not ordinary_mysql:
        activate('Options', message_key='optionsSettings')
        activate('Development')
        activate('Staging')
        activate('General', message_key='generalSettings')
    activate('Test connection')
    authentication_feedback = 'Database authentication was rejected. Check User and Password in General.'
    wait(lambda: observed_any(lambda item: localized(authentication_feedback) in readable(item)), 30)
    photograph_product(Atspi, app, objects, wait, command, report, 'connection-error', sizes=((1366,768),), protected_form=True)
    for label in ('Test connection', 'Cancel', 'Apply', 'Save & connect'):
        wait(lambda: find(label))
    set_profile_field('Password', (source / 'password').read_text())
    activate('Test connection')
    product = {'POSTGRESQL': 'PostgreSQL', 'MYSQL': 'MySQL', 'MARIADB': 'MariaDB'}[engine]
    wait(lambda: observed_any(lambda item: product in readable(item) and '/busydata' in readable(item)), 30)
    report['nativeAuthenticationPasswordRoleVerified'] = True
    report['nativeConnectionTestCorrectionVerified'] = True
    if ordinary_mysql:
        activate('Details')
        photograph('manager-tested-tls-details', protected_form=True)
        def visible_tls_diagnostic():
            def project(item):
                states=item.get_state_set()
                if not states.contains(Atspi.StateType.SHOWING) or item.get_role()==Atspi.Role.PASSWORD_TEXT:
                    return False, None
                if not any(native_name(parent)=='Data Sources and Drivers' for parent in accessible_ancestors(item)):
                    return False, None
                text=native_name(item)
                if ('Database TLS:' not in text and 'Text' in item.get_interfaces()
                        and Atspi.Text.get_character_count(item)<=4096):
                    text=Atspi.Text.get_text(item,0,-1)
                if 'Database TLS:' in text:
                    return True, text
                return False, None
            return observed_first(project)
        diagnostic=wait(visible_tls_diagnostic)
        safe_tls=re.search(r'Database TLS: (encrypted · [A-Za-z0-9_]+|unencrypted|unobserved)',diagnostic)
        if safe_tls is None or safe_tls.group(1)=='unobserved': raise RuntimeError('Ordinary MySQL TLS state was not observed on the tested connection')
        report['ordinaryMySqlTlsObservation']={'testedConnection':True,'state':safe_tls.group(1),'certificateVerificationClaimed':False}
        activate('Details')
    # Pause only this controller's disposable database to exercise an actual
    # pending JDBC test. Cancellation must keep the same unsaved form usable;
    # unpausing and testing again is fixture failure/retry, never a completion
    # workaround or an application configuration/session injection.
    fixture = os.environ['BUSYDATA_NATIVE_FIXTURE_ID']
    command(['docker', 'pause', fixture], stdout=subprocess.DEVNULL)
    try:
        activate('Test connection')
        wait(lambda: observed_any(lambda item: localized('Testing connection…') in readable(item)))
        activate('Cancel test')
        # Static live-region feedback may share its native node with adjacent
        # form guidance. Require the actual localized cancellation text, then
        # prove correction/retry on the same still-open form below.
        wait(lambda: observed_any(lambda item: localized('Cancelled') in readable(item)))
        if find('Name', 'EditableText') is None:
            raise RuntimeError('Cancelling Test dismissed the unsaved connection form')
    finally:
        command(['docker', 'unpause', fixture], stdout=subprocess.DEVNULL)
    activate('Test connection')
    wait(lambda: observed_any(lambda item: product in readable(item) and '/busydata' in readable(item)), 30)
    report['nativeConnectionTestCancellationRetryVerified'] = True
    activate('Save & connect')
    wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)), 30)
    report['nativeProfileDialogClosedVerified'] = True
    expected_target = 'Native accessibility fixture'
    wait(lambda: find_native_tree_row(Atspi, objects(app), labels, 'public' if postgres else 'busydata', current_nodes=lambda: objects(app)), 30)
    wait(lambda: observed_any(lambda item: 'Connects when run' in native_name(item)))
    # First Run acquires the console's independent session inside this action.
    report['stage'] = 'native-first-run-editor-focus'
    # Dialog dismissal can leave the editor already focused. Exercise an
    # actual focus transition before requiring its screen-reader receipt.
    focus(wait(lambda: find_native_tree_row(Atspi, objects(app), labels, expected_target, current_nodes=lambda: objects(app))))
    editor = wait(lambda: observed_sql_editor())
    focus(editor)
    wait(lambda: speech_contains([native_sql_editor_announcement(labels)]))
    sql = 'SELECT id, n FROM native_atspi_fixture ORDER BY id;'
    if not Atspi.EditableText.set_text_contents(editor, sql): raise RuntimeError('Native SQL input rejected')
    wait(lambda: Atspi.Text.get_text(editor, 0, -1) == sql)
    activate('Run')
    password = wait(lambda: find('Password', 'EditableText'))
    focus(password)
    supply_password(password)
    activate('Connect')
    wait(lambda: observed_any(lambda item: 'Row 1, n: 漢😀' in native_name(item)), 30)
    wait(lambda: observed_any(lambda item: 'Auto-commit' in native_name(item) and ('busydata/public' if postgres else 'busydata') in native_name(item)))
    report['nativeFirstRunAcquisitionAndExactSubmissionVerified'] = True
    report['nativeSessionOnlyLiveTargetVerified'] = True
    report['nativeProfileInputsAndExplicitSessionOnlyConnectVerified'] = True
    if os.environ.get('BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER_LOCAL') == '1':
        cases = report['databaseExplorerLocalCases'] = {}

        def local_row(name, namespace_scope=False, catalog='busydata', current_nodes=None):
            nodes = objects(app)
            proof = current_nodes if current_nodes is not None else lambda: objects(app)
            if namespace_scope:
                scope = ' / ' + catalog + (' / public' if postgres else '')
                values = read_live_native_controls(nodes,
                    lambda node: node if scope in native_name(node) else None, proof)
                if values is None:
                    return None
                nodes = [value for value in values if value is not None]
            return find_native_tree_row(Atspi, nodes, labels, name, current_nodes=proof)

        def local_context(name, action):
            item = wait(lambda: local_row(name))
            focus(item)
            item = wait(lambda: local_row(name))
            request = {'name': name, 'action': action, 'row': native_name(item),
                'focused': item.get_state_set().contains(Atspi.StateType.FOCUSED),
                'selected': item.get_state_set().contains(Atspi.StateType.SELECTED)}
            report.setdefault('nativeExplorerMenuRequests', []).append(request)
            command(['xdotool', 'key', '--clearmodifiers', 'Menu'])
            try:
                activate(action, menu_only=True)
                request['invokedThroughMenu'] = True
            finally:
                request['showingPopups'] = [{'name': native_name(n), 'role': n.get_role_name(),
                    'enabled': n.get_state_set().contains(Atspi.StateType.SENSITIVE)}
                    for n in objects(app) if n.get_state_set().contains(Atspi.StateType.SHOWING)
                    and n.get_role() in (Atspi.Role.MENU, Atspi.Role.MENU_ITEM, Atspi.Role.CHECK_MENU_ITEM, Atspi.Role.RADIO_MENU_ITEM)]

        def local_sql(value):
            def field():
                return observed_first(lambda n: (True, n) if supports(n, 'EditableText') and any(('Virtual view SQL definition' in native_name(p) for p in [n, *accessible_ancestors(n)])) else (False, None))
            editor = wait(field)
            focus(editor)
            if not Atspi.EditableText.set_text_contents(editor, value):
                raise RuntimeError('Local definition editor rejected native input')
            wait(lambda: Atspi.Text.get_text(field(), 0, -1) == value)

        def save_local():
            activate('Save')
            wait(lambda: observed_missing(lambda proof: find('Virtual view name', 'EditableText', current_nodes=proof)))

        def execute_local(name, credentials=False, marker=None, catalog='busydata'):
            focus(wait(lambda: local_row(name)))
            pointer_at_native_bounds(command, visible_native_bounds(
                Atspi, lambda: local_row(name), wait), repeat=2)
            if credentials:
                secret = wait(lambda: find('Password', 'EditableText'))
                focus(secret); supply_password(secret); activate('Connect')
            if marker is None:
                def review_visible():
                    return observed_any(lambda n: native_name(n) == 'Review details' and n.get_state_set().contains(Atspi.StateType.SHOWING))
                wait(lambda: review_visible() or observed_any(lambda n: native_tab_has_status(native_name(n), 'Running') and native_tab_name(native_name(n)).startswith('Query ')), 30)
                if review_visible(): activate('Run')
            if marker is not None:
                wait(lambda: find('Row 1, virtual_marker: ' + str(marker))
                    and find('Row 1, virtual_database: ' + catalog)
                    and find('Row 1, n: ' + ('漢😀' if catalog == 'busydata' else 'second physical database')), 30)

        namespace = 'public' if postgres else 'busydata'
        fast_sql = 'SELECT n,' + ('current_database()' if postgres else 'DATABASE()') + ' AS virtual_database,7101 AS virtual_marker FROM native_atspi_fixture WHERE id=1;'
        local_context(namespace, 'New virtual view')
        set_profile_field('Virtual view name', 'Local report')
        local_sql(fast_sql)
        photograph('database-panel-local-definition')
        save_local()
        if find('Expand ' + namespace): activate('Expand ' + namespace)
        focus(wait(lambda: local_row('Virtual views', namespace_scope=True)))
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])
        execute_local('Local report', credentials=True, marker=7101)
        cases['create-explicit-run-owned-results'] = True
        photograph('database-panel-local-results')
        local_context('Local report', 'Edit local definition')
        local_sql('SELECT ' + ('pg_sleep(30)' if postgres else 'SLEEP(30)') + ',7102 AS virtual_marker;')
        save_local()
        execute_local('Local report', credentials=True)
        wait(lambda: observed_any(lambda n: native_tab_has_status(native_name(n), 'Running') and native_tab_name(native_name(n)).startswith('Query ')), 30)
        # The SQL pane captures its own document/job even while the Explorer
        # still has focus. The palette intentionally retains tree ownership.
        activate('Cancel', dismisses_modal=False)
        wait(lambda: observed_any(lambda n: native_tab_has_status(native_name(n), 'Cancelled') and native_tab_name(native_name(n)).startswith('Query ')), 30)
        cases['edit-explicit-run-cancel'] = True
        local_context('Local report', 'Edit local definition')
        local_sql(fast_sql.replace('7101', '7103'))
        save_local()
        local_context('Local report', 'Rename virtual view')
        set_profile_field('Virtual view name', 'Local report renamed')
        save_local()
        wait(lambda: local_row('Local report renamed'))
        cases['rename-preserves-definition'] = True

        focus(wait(lambda: local_row(expected_target)))
        activate('New'); activate('New source folder', menu_only=True)
        set_profile_field('Folder name', 'Team/Development'); activate('Save')
        wait(lambda: observed_missing(lambda proof: find('Folder name', 'EditableText', current_nodes=proof)))
        local_context(expected_target, 'Move to folder')
        activate('Team / Development')
        wait(lambda: observed_none(lambda n: native_name(n) == 'Team / Development'))
        focus(wait(lambda: local_row('Team')))
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])
        focus(wait(lambda: local_row('Development')))
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])
        wait(lambda: local_row(expected_target))
        local_context('Team', 'Rename folder')
        set_profile_field('Folder name', 'Workspace'); activate('Save')
        wait(lambda: observed_missing(lambda proof: find('Folder name', 'EditableText', current_nodes=proof)))
        focus(wait(lambda: local_row(expected_target)))
        activate('New'); activate('New source folder', menu_only=True)
        set_profile_field('Folder name', 'Archive'); activate('Save')
        wait(lambda: observed_missing(lambda proof: find('Folder name', 'EditableText', current_nodes=proof)))
        local_context('Archive', 'Move up')
        wait(lambda: Atspi.Component.get_extents(local_row('Archive'), Atspi.CoordType.SCREEN).y <
            Atspi.Component.get_extents(local_row('Workspace'), Atspi.CoordType.SCREEN).y)
        local_context(expected_target, 'Toggle favorite')
        cases['nested-folders-move-rename-reorder-favorite'] = True
        photograph('database-panel-local-folders')

        if restart is None: raise RuntimeError('Local recovery tour needs normal relaunch')
        def local_window_close():
            def project(n):
                if native_name(n) != 'Close' or not supports(n, 'Component'): return None
                frame = next((p for p in accessible_ancestors(n) if p.get_role() == Atspi.Role.FRAME), None)
                if frame is None: return None
                box = Atspi.Component.get_extents(n, Atspi.CoordType.SCREEN)
                window = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
                return n if box.y < window.y + 64 and n.get_state_set().contains(Atspi.StateType.SHOWING) else None
            values = observed_values(project)
            if values is None: return None
            matches = [value for value in values if value is not None]
            if len(matches) > 1: raise RuntimeError('Ambiguous local tour window close')
            return matches[0] if matches else None
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, local_window_close, wait))
        activate('Save drafts and close')
        app = restart()
        for name in ('Archive', 'Workspace', 'Development', expected_target): wait(lambda name=name: local_row(name), 30)
        qualified = 'busydata / ' + ('public / ' if postgres else '') + 'Local report renamed'
        focus(wait(lambda: local_row('Virtual views')))
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])
        wait(lambda: local_row(qualified), 30)
        def server_scalar(query):
            if postgres:
                args = ['docker', 'exec', '-e', 'PGPASSWORD', fixture, 'psql', '-h', '127.0.0.1', '-U', 'busydata', '-d', 'busydata', '-Atc', query]
                environment = dict(os.environ, PGPASSWORD=(source / 'password').read_text())
            else:
                args = ['docker', 'exec', '-e', 'MYSQL_PWD', fixture, 'mysql' if engine == 'MYSQL' else 'mariadb', '-h', '127.0.0.1', '-u', 'busydata' if ordinary_mysql else 'root', '--batch', '--skip-column-names', '-e', query]
                environment = dict(os.environ, MYSQL_PWD=(source / 'password').read_text())
            return subprocess.run(args, env=environment, check=True, capture_output=True, text=True, timeout=10).stdout.strip()
        count_sql = "SELECT count(*) FROM pg_stat_activity WHERE application_name='BusyData'" if postgres else "SELECT count(*) FROM information_schema.processlist WHERE user=SUBSTRING_INDEX(CURRENT_USER(),'@',1) AND id<>CONNECTION_ID()"
        if server_scalar(count_sql) != '0': raise RuntimeError('Restoring local definitions opened a database session')
        wait(lambda: observed_any(lambda n: 'Connects when run' in native_name(n)))
        cases['normal-relaunch-folders-definition-disconnected'] = True
        photograph('database-panel-local-restored-disconnected')
        execute_local(qualified, credentials=True, marker=7103)
        cases['restored-definition-explicit-run'] = True
        local_context(expected_target, 'Edit connection')
        set_profile_field('Name', 'Renamed local source')
        set_profile_field('Password', (source / 'password').read_text())
        activate('Save & connect')
        wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)), 30)
        wait(lambda: local_row('Renamed local source'), 30)
        # A presentation-only rename must keep the local definition attached.
        wait(lambda: local_row('Local report renamed') or local_row(qualified), 30)
        cases['source-rename-retains-local-binding'] = True
        local_context('Renamed local source', 'Delete connection')
        activate('Delete connection')
        wait(lambda: observed_missing(lambda proof: local_row('Renamed local source', current_nodes=proof)), 30)
        focus(wait(lambda: local_row('Unbound virtual views')))
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])
        wait(lambda: local_row(qualified))
        photograph('database-panel-local-source-deleted-unbound')
        activate('New'); activate('New connection', menu_only=True)
        wait(lambda: find('Name', 'EditableText'))
        if not postgres:
            activate('PostgreSQL'); activate('MySQL' if engine == 'MYSQL' else 'MariaDB')
        for label, value in [('Name', 'Renamed local source'), ('Host', '127.0.0.1'),
                ('Port', os.environ['BUSYDATA_NATIVE_FIXTURE_PORT']), ('Database', 'busydata_desired'),
                ('User', 'busydata' if postgres or ordinary_mysql else 'root'), ('Password', (source / 'password').read_text())]:
            set_profile_field(label, value)
        if not ordinary_mysql:
            activate('SSH/SSL'); activate('Use SSL'); activate('Require'); activate('Full Verification')
            set_profile_field('CA certificate file', str(source / 'ca.crt'))
        activate('Save & connect')
        wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)), 30)
        wait(lambda: local_row('Renamed local source') and local_row('Unbound virtual views') and local_row(qualified), 30)
        # Same display name, different saved source ID: still visibly unbound.
        cases['deleted-source-same-name-stays-unbound'] = True
        replacement_namespace = 'public' if postgres else 'busydata_desired'
        wait(lambda: local_row(replacement_namespace), 30)
        if find('Expand ' + replacement_namespace): activate('Expand ' + replacement_namespace)
        local_context(replacement_namespace, 'Rebind local definition here')
        activate('Local report renamed · busydata / ' + namespace)
        wait(lambda: observed_missing(lambda proof: local_row('Unbound virtual views', current_nodes=proof)))
        focus(wait(lambda: local_row('Virtual views', namespace_scope=True, catalog='busydata_desired')))
        command(['xdotool', 'key', '--clearmodifiers', 'Right'])
        execute_local('Local report renamed', credentials=True, marker=7103, catalog='busydata_desired')
        cases['explicit-rebind-new-source-exact-database'] = True
        photograph('database-panel-local-explicit-rebind-results')
        local_context('Local report renamed', 'Remove')
        activate('Remove')
        wait(lambda: observed_missing(lambda proof: local_row('Local report renamed', current_nodes=proof)))
        no_server_view = "SELECT count(*) FROM information_schema.views WHERE table_name IN ('Local report','Local report renamed')"
        if server_scalar(no_server_view) != '0': raise RuntimeError('Local definition created a server VIEW')
        wait(lambda: find('Row 1, virtual_marker: 7103') and find('Row 1, n: second physical database'))
        cases['remove-local-only-retains-console-output'] = True
        photograph('database-panel-local-removed-output-retained')
        report['databaseExplorerLocalTourPassed'] = len(cases) == 10 and all(cases.values())
        focus(wait(lambda: find('Row 1, n: second physical database')))
        return [localized('Row 1, n: second physical database')]
    if os.environ.get('BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER_TOOLS') == '1':
        from native_database_explorer_tools import verify_tools
        def restart_tools_product():
            nonlocal app
            if restart is None: raise RuntimeError('Ordinary product restart is unavailable')
            app = restart()
            return app
        return verify_tools(Atspi=Atspi, app=app, report=report, objects=objects,
            find=find, wait=wait, focus=focus, activate=activate, command=command,
            photograph=photograph, supply_password=supply_password,
            fixture=fixture, source=source, engine=engine, labels=labels,
            expected_target=expected_target, native_function_key=native_function_key,
            native_name=native_name, supports=supports, palette=palette,
            restart=restart_tools_product)
    if os.environ.get('BUSYDATA_NATIVE_VERIFY_DATABASE_EXPLORER') == '1':
        # A dedicated ordinary-product tour. Every connection, namespace and
        # document comes from visible controls; this scope does not certify the
        # longer editing/export/native-matrix workflow below.
        cases = report['databaseExplorerCases'] = {}
        cases['startup-default-console'] = True
        original_query = wait(lambda: observed_first(lambda n: (True, native_query_identity(native_name(n))) if native_tab_name(native_name(n)).startswith('Query ') and n.get_state_set().contains(Atspi.StateType.SELECTED) else (False, None)))

        def tree_row(name, catalog=None):
            nodes = objects(app)
            if catalog is not None:
                values = read_live_native_controls(nodes,
                    lambda node: node if catalog in native_name(node) else None,
                    current_nodes=lambda: objects(app))
                if values is None:
                    return None
                nodes = [value for value in values if value is not None]
            return find_native_tree_row(Atspi, nodes, labels, name, current_nodes=lambda: objects(app))

        def open_table(catalog):
            namespace = 'public' if postgres else catalog
            wait(lambda: tree_row(namespace, catalog), 30)
            if find('Expand ' + namespace): activate('Expand ' + namespace)
            wait(lambda: tree_row('Tables', catalog), 30)
            if find('Expand Tables'): activate('Expand Tables')
            row = wait(lambda: tree_row('customers', catalog), 30)
            focus(row)
            box = visible_native_bounds(Atspi, lambda: tree_row('customers', catalog), wait)
            pointer_at_native_bounds(command, box, repeat=2)
            secret = wait(lambda: find('Password', 'EditableText'))
            focus(secret); supply_password(secret); activate('Connect')
            marker = '漢😀' if catalog == 'busydata' else 'second physical database'
            wait(lambda: find('Row 1, n: ' + marker), 30)
            photograph('database-panel-data-' + catalog)
            activate('Structure'); activate('Open definition')
            report['stage'] = 'native-object-definition'
            wait(lambda: visible_object_definition(Atspi, objects(app), 'customers', current_nodes=lambda: objects(app)), 30)
            if catalog != 'busydata':
                wait(lambda: observed_any(lambda n: 'desired_note' in bounded_native_text(Atspi, n) or 'desired_note' in (n.get_name() or '')), 30)
            photograph('database-panel-ddl-' + catalog)

        report['stage'] = 'database-panel-primary-data-ddl'
        open_table('busydata')
        source_row = wait(lambda: tree_row(expected_target))
        focus(source_row)
        def source_badge():
            row = tree_row(expected_target)
            if row is None: return None
            return observed_first(lambda n: (True, n) if re.fullmatch('1 of [1-9][0-9]*', native_name(n)) and row in accessible_ancestors(n) and n.get_state_set().contains(Atspi.StateType.SHOWING) else (False, None))
        badge = wait(source_badge)
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, source_badge, wait))
        wait(lambda: find('busydata_desired'))
        activate('busydata_desired'); activate('Apply')
        wait(lambda: observed_any(lambda n: re.fullmatch('2 of [1-9][0-9]*', native_name(n))))
        if find('Collapse busydata'): activate('Collapse busydata')
        wait(lambda: tree_row('busydata_desired'), 30)
        if find('Expand busydata_desired'): activate('Expand busydata_desired')
        report['stage'] = 'database-panel-secondary-data-ddl'
        open_table('busydata_desired')
        cases['two-physical-databases-data-ddl'] = True
        category = wait(lambda: tree_row('Tables', 'busydata_desired'))
        focus(category)
        command(['xdotool', 'key', '--clearmodifiers', 'Menu'])
        activate('New query', menu_only=True)
        scoped_editor = wait(lambda: observed_sql_editor())
        query = 'SELECT ' + ('current_database()' if postgres else 'DATABASE()') + ' AS exact_database;'
        focus(scoped_editor)
        if not Atspi.EditableText.set_text_contents(scoped_editor, query): raise RuntimeError('Scoped console input rejected')
        activate('Run')
        secret = wait(lambda: find('Password', 'EditableText'))
        focus(secret); supply_password(secret); activate('Connect')
        wait(lambda: find('Row 1, exact_database: busydata_desired'), 30)
        cases['category-console-first-run'] = True
        photograph('database-panel-category-console')
        focus(wait(lambda: tree_row(expected_target)))
        native_function_key('F10', control=True, shift=True)
        activate(original_query + ' · busydata / ' + ('public' if postgres else 'busydata'))
        original_editor = wait(lambda: observed_sql_editor(lambda n: Atspi.Text.get_text(n, 0, -1) == sql))
        wait(lambda: find('Row 1, n: 漢😀'), 30)
        # After checking the retained original text/output, explicitly author a
        # new visible query. Its new columns prove the following Run completed,
        # rather than accidentally accepting the retained prior result.
        verified_sql = 'SELECT id,n,' + ('current_database()' if postgres else 'DATABASE()') + ' AS exact_database,7341 AS namespace_check FROM native_atspi_fixture ORDER BY id;'
        focus(original_editor)
        if not Atspi.EditableText.set_text_contents(original_editor, verified_sql): raise RuntimeError('Visible target-verification input rejected')
        wait(lambda: Atspi.Text.get_text(original_editor, 0, -1) == verified_sql)
        activate('Run')
        wait(lambda: find('Row 1, namespace_check: 7341') and find('Row 1, exact_database: busydata') and find('Row 1, n: 漢😀'), 30)
        cases['console-chooser-retains-original-target-output'] = True
        photograph('database-panel-original-console-retained')
        if find('Collapse busydata_desired'): activate('Collapse busydata_desired')
        if find('Expand busydata'): activate('Expand busydata')
        if postgres and find('Expand public'): activate('Expand public')
        if find('Expand Tables'): activate('Expand Tables')
        report['stage'] = 'database-panel-paging-beyond-node-budget'
        # Three actual non-page tables precede the 2,305 fixture tables in native
        # order. Advance through the ordinary replacing 128-name windows.
        for page in range(1, 19):
            activate('Load more')
            wait(lambda: tree_row(f'page_{128 * page - 3:04d}', 'busydata'), 30)
        wait(lambda: tree_row('page_2304', 'busydata'), 30)
        activate('Previous page')
        wait(lambda: tree_row('page_2173', 'busydata'), 30)
        activate('Load more')
        last = wait(lambda: tree_row('page_2304', 'busydata'), 30)
        focus(last)
        command(['xdotool', 'key', '--clearmodifiers', 'ctrl+q'])
        wait(lambda: observed_any(lambda n: native_name(n).startswith('Quick Documentation') and n.get_state_set().contains(Atspi.StateType.SHOWING)))
        command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
        wait(lambda: observed_none(lambda n: native_name(n).startswith('Quick Documentation') and n.get_state_set().contains(Atspi.StateType.SHOWING)))
        focus(wait(lambda: tree_row('page_2304', 'busydata')))
        command(['xdotool', 'key', '--clearmodifiers', 'ctrl+b'])
        wait(lambda: visible_object_definition(Atspi, objects(app), 'page_2304', current_nodes=lambda: objects(app)), 30)
        photograph('database-panel-last-paged-object-ddl')
        cases['paging-last-object-back-forward-real-ddl'] = True
        report['databaseExplorerTourPassed'] = all(cases.values()) and len(cases) == 5
        tab = wait(lambda: find_query_tab_activation(Atspi, objects(app), original_query, native_query_identity, native_name, current_nodes=lambda: objects(app)))
        if not Atspi.Action.do_action(tab[0], tab[1]): raise RuntimeError('Original console tab rejected activation')
        focus(wait(lambda: find('Row 1, n: 漢😀'), 30))
        return [localized('Row 1, n: 漢😀')]
    # The extra two-source menu tour belongs to the ordinary and Fluent runs;
    # the platform matrix retains its separate complete core workflow scope.
    if (postgres and os.environ.get('BUSYDATA_NATIVE_VERIFY_CONNECTION_MANAGEMENT') == '1'
            and not os.environ.get('BUSYDATA_NATIVE_SETTINGS_INPUT')):
        # Additional visible actions in the ordinary workbench. The existing
        # fixture provides two databases; profiles/owners are never injected.
        report['stage'] = 'native-connection-management-start'
        management = {}
        session_pattern = re.compile(r' · ([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$')

        def selected_management_query():
            return wait(lambda: observed_first(lambda node: (True, native_query_identity(native_name(node))) if native_tab_name(native_name(node)).startswith('Query ') and node.get_state_set().contains(Atspi.StateType.SELECTED) else (False, None)))

        def management_tabs():
            values = observed_values(lambda node: native_query_identity(native_name(node)) if
                native_tab_name(native_name(node)).startswith('Query ') and
                node.get_role() == Atspi.Role.PUSH_BUTTON else None)
            if values is None:
                raise NativeSnapshotIncomplete('Management document baseline changed during capture')
            return {value for value in values if value is not None}

        def management_editor():
            return wait(lambda: find_live_control(Atspi, objects(app), 'SQL editor',
                'EditableText', current_nodes=lambda: objects(app), name_prefix=True))

        def management_session(profile):
            def observe(node):
                name = native_name(node)
                match = session_pattern.search(name) if name.startswith(profile + ' · 127.0.0.1:') else None
                return match.group(1) if match is not None else None
            values = observed_values(observe)
            if values is None:
                raise NativeSnapshotIncomplete('Management session observation changed during capture')
            matches = [value for value in values if value is not None]
            if len(set(matches)) > 1:
                raise RuntimeError('Ambiguous live query session')
            return matches[0] if matches else None

        def management_click(name):
            box = visible_native_bounds(Atspi, lambda: find(name), wait)
            pointer_at_native_bounds(command, box)

        def management_menu(category, action):
            if category == 'Documents':
                category = documents_menu
            report['stage'] = 'native-application-menu: ' + category + ' / ' + action
            previous = set(objects(app))
            if not fluent and category in APPLICATION_MENU_CATEGORIES and find(category) is None:
                management_click('Main menu')
                if category in APPLICATION_MENU_PARENTS:
                    management_click(APPLICATION_MENU_PARENTS[category])
            management_click(category)
            def current_entry():
                entry = find_new_menu_activation(Atspi, objects(app), localized(action), previous,
                    fluent=report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent',
                    shortcut={'New query': 'Ctrl+T', 'Close tab': 'Ctrl+W'}.get(action), current_nodes=lambda: objects(app))
                return entry[0] if entry is not None else None
            box = visible_native_bounds(Atspi, current_entry, wait)
            if category == 'No connection' and report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent':
                photograph_product(Atspi, app, objects, wait, command, report,
                    'management-query-selector-menu', resize=False)
                report['nativeQuerySelectorMenuBounds'] = {
                    'caption': current_entry().get_name(),
                    **{key: getattr(box, key) for key in ('x', 'y', 'width', 'height')}}
            pointer_at_native_bounds(command, box)

        def management_activate(identity):
            item, _, _ = wait(lambda: find_query_tab_activation(Atspi, objects(app), identity,
                native_query_identity, native_name, current_nodes=lambda: objects(app)))
            box = visible_native_bounds(Atspi, lambda: item, wait)
            pointer_at_native_bounds(command, box)
            wait(lambda: selected_management_query() == identity)

        def management_input(text):
            editor = management_editor(); focus(editor)
            if not Atspi.EditableText.set_text_contents(editor, text):
                raise RuntimeError('Connection-management SQL input rejected')
            verify_native_sql_lines(Atspi, management_editor, text, wait, command,
                observations=report.setdefault('nativeConnectionManagementSqlInspection', []))

        def management_run(profile, database, previous_pid=None):
            def review_open():
                return observed_any(lambda node: native_name(node) == 'Review details' and node.get_role() == Atspi.Role.HEADING and node.get_state_set().contains(Atspi.StateType.SHOWING))
            def completed_target():
                if find('Row 1, target_name: ' + database) is None: return False
                return previous_pid is None or observed_any(lambda node: (match := re.fullmatch('Row 1, backend_pid: ([0-9]+)', native_name(node))) and int(match.group(1)) != previous_pid)
            management_click('Run')
            wait(lambda: find('Password', 'EditableText') or review_open() or
                completed_target(), 30)
            if find('Password', 'EditableText'):
                secret = wait(lambda: find('Password', 'EditableText'))
                focus(secret)
                supply_password(secret)
                activate('Connect')
            wait(lambda: review_open() or completed_target(), 30)
            if review_open(): activate('Run')
            wait(lambda: completed_target(), 30)
            pid = wait(lambda: observed_first(lambda node: (True, int(match.group(1))) if (match := re.fullmatch('Row 1, backend_pid: ([0-9]+)', native_name(node))) else (False, None)), 30)
            return {'sessionId': wait(lambda: management_session(profile)), 'backendPid': pid, 'database': database}

        def management_form(name, database):
            wait(lambda: find('Name', 'EditableText'))
            for field, value in [('Name', name), ('Host', '127.0.0.1'),
                ('Port', os.environ['BUSYDATA_NATIVE_FIXTURE_PORT']), ('User', 'busydata'),
                ('Password', (source / 'password').read_text()), ('Database', database)]:
                set_profile_field(field, value)
            activate('SSH/SSL')
            if not wait(lambda: find('Use SSL')).get_state_set().contains(Atspi.StateType.CHECKED):
                activate('Use SSL')
                activate('Require')
                activate('Full Verification')
            set_profile_field('CA certificate file', str(source / 'ca.crt'))
            activate('General', message_key='generalSettings')

        def management_photo(label, protected=False):
            photograph_product(Atspi, app, objects, wait, command, report, label,
                sizes=((1366,768),), protected_form=protected)

        a = selected_management_query()
        a_session = wait(lambda: management_session(expected_target))
        original_sql = Atspi.Text.get_text(management_editor(), 0, -1)
        before = management_tabs()
        management_menu('Connection', 'New connection')
        management_form('Connection management B', 'busydata_desired')
        management_photo('management-global-menu-form', protected=True)
        activate('Save & connect')
        wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)), 30)
        b = wait(lambda: find_new_selected_query(Atspi, objects(app), before, native_name, current_nodes=lambda: objects(app)))
        if b == a or Atspi.Text.get_text(management_editor(), 0, -1) != '':
            raise RuntimeError('Global creation commandeered an existing SQL document')
        wait(lambda: find_native_tree_row(Atspi, objects(app), labels, 'busydata_desired', current_nodes=lambda: objects(app)), 30)
        wait(lambda: observed_any(lambda node: 'Connection management B' in native_name(node) and 'Connects when run' in native_name(node)))
        if management_session('Connection management B') is not None:
            raise RuntimeError('Global creation prematurely acquired its query session')
        management_photo('management-global-source-console')
        if find('Collapse Connection management B'): activate('Collapse Connection management B')
        management_activate(a)
        if (management_session(expected_target) != a_session or
                Atspi.Text.get_text(management_editor(), 0, -1) != original_sql or
                find('Row 1, n: 漢😀') is None or find('Row 2, n: second') is None):
            raise RuntimeError('Global creation changed the original query/session/output')
        management['globalCreation'] = {'initiatingQuery': a, 'originalSessionBefore': a_session,
            'originalSessionAfter': management_session(expected_target), 'newConsole': b,
            'explorerDatabase': 'busydata_desired', 'newConsoleAcquiredWhenRun': True,
            'originalSqlAndOutputPreserved': True}
        target_sql = 'SELECT current_database() AS target_name, pg_backend_pid() AS backend_pid;'
        management_activate(b); management_input(target_sql)
        b_result = management_run('Connection management B', 'busydata_desired')
        management_activate(a); management_input(target_sql)
        a_result = management_run(expected_target, 'busydata')
        if a_result['sessionId'] != a_session or a_result['sessionId'] == b_result['sessionId']:
            raise RuntimeError('Global creation failed independent target execution')
        management['targetsBeforeReconnect'] = {'a': a_result, 'b': b_result}
        management_menu('Connection', 'Edit connection')
        wait(lambda: find('Name', 'EditableText'))
        set_profile_field('Password', (source / 'password').read_text())
        activate('Save & connect')
        wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)), 30)
        replacement = wait(lambda: management_session(expected_target))
        if (replacement == a_session or selected_management_query() != a or
                Atspi.Text.get_text(management_editor(), 0, -1) != target_sql or
                find('Row 1, backend_pid: ' + str(a_result['backendPid'])) is None):
            raise RuntimeError('Live-form reconnect did not preserve its document/output and replace its session')
        count = subprocess.run(['docker', 'exec', os.environ['BUSYDATA_NATIVE_FIXTURE_ID'],
            'psql', '-U', 'busydata', '-d', 'busydata', '-Atq', '-c',
            'SELECT count(*) FROM pg_stat_activity WHERE pid=' + str(a_result['backendPid'])],
            check=True, capture_output=True, text=True, timeout=10).stdout.strip()
        if count != '0': raise RuntimeError('Retired unshared SQL connection remains on the server')
        management_photo('management-live-reconnect-preserved-output')
        a_replacement = management_run(expected_target, 'busydata', previous_pid=a_result['backendPid'])
        if a_replacement['sessionId'] != replacement or a_replacement['backendPid'] == a_result['backendPid']:
            raise RuntimeError('Replacement query did not execute through its new connection')
        management['liveReconnect'] = {'query': a, 'oldSessionId': a_session,
            'newSessionId': replacement, 'oldBackendPid': a_result['backendPid'],
            'newBackendPid': a_replacement['backendPid'], 'oldServerConnectionsAfterRetirement': 0,
            'sqlAndPriorOutputPreserved': True, 'executionAfterReconnectVerified': True}
        # Query 1 is the original intentionally blank offline document. Open a
        # distinct offline query from its File menu, keeping that blank intact.
        management_activate('Query 1')
        wait(lambda: find('No connection'))
        before = management_tabs()
        management_menu('Documents', 'New query')
        c = wait(lambda: find_new_selected_query(Atspi, objects(app), before, native_name, current_nodes=lambda: objects(app)))
        offline_sql = '-- meaningful offline connection target\n' + target_sql
        management_input(offline_sql)
        before = management_tabs()
        management_menu('No connection', 'New connection')
        management_form('Connection management C', 'busydata')
        activate('Save & connect')
        wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)), 30)
        if selected_management_query() != c or management_tabs() != before:
            raise RuntimeError('Explicit query-selector creation lost its initiating owner/text')
        focus(management_editor())
        verify_native_sql_lines(Atspi, management_editor, offline_sql, wait, command)
        c_result = management_run('Connection management C', 'busydata')
        if c_result['sessionId'] in (a_replacement['sessionId'], b_result['sessionId']):
            raise RuntimeError('Query selector implicitly shared a physical connection')
        management_photo('management-offline-selector-first-run')
        management['querySelector'] = {'query': c, **c_result, 'sqlPreserved': True,
            'newCompetingConsole': False, 'firstRunCompleted': True}
        # Inspect actual owned sessions through the application menu. C has
        # exactly its query session, while global B has query and Explorer owners.
        management_menu('View', 'Owned sessions')
        rows = set()
        for _ in range(4):
            nodes = wait_native_owned_session_nodes(Atspi, lambda: objects(app), wait)
            rows.update(native_name(node) for node in nodes if re.match(
                r'^(?:Connection management B|Connection management C) · [0-9a-f-]{36} · ', native_name(node)))
            if len(rows) >= 3: break
            # The ordinary bounded session list may scroll. Move the pointer
            # to a showing row and scroll its viewport, retaining seen identities.
            row = next(node for node in nodes if re.search(r' · [0-9a-f-]{36} · ', native_name(node))
                and node.get_state_set().contains(Atspi.StateType.SHOWING))
            box = visible_native_bounds(Atspi, lambda: row, wait)
            command(['xdotool', 'mousemove', str(box.x + box.width // 2),
                str(box.y + box.height // 2), 'click', '--repeat', '3', '--delay', '80', '5'])
        if (len([x for x in rows if x.startswith('Connection management C · ')]) != 1 or
                len([x for x in rows if x.startswith('Connection management B · ')]) != 2):
            raise RuntimeError('Creation intent produced the wrong Explorer/query ownership')
        management['ownedSessionRows'] = sorted(rows)
        activate('Close')
        for identity in (c, b):
            management_activate(identity)
            management_menu('Documents', 'Close tab')
            wait(lambda: find('Discard SQL and close')); management_click('Discard SQL and close')
            wait(lambda: identity not in management_tabs(), 30)
        management_activate(a)
        management_menu('View', 'Owned sessions')
        row = wait(lambda: observed_first(lambda node: (True, node) if native_name(node).startswith('Connection management B · ') else (False, None)))
        row_box = Atspi.Component.get_extents(row, Atspi.CoordType.SCREEN)
        following = [Atspi.Component.get_extents(node, Atspi.CoordType.SCREEN).y for node in objects(app)
            if re.search(r' · [0-9a-f-]{36} · ', native_name(node)) and
                Atspi.Component.get_extents(node, Atspi.CoordType.SCREEN).y > row_box.y]
        bottom = min(following, default=row_box.y + 130)
        button = wait(lambda: observed_first(lambda node: (True, node) if native_name(node) == 'Disconnect' and row_box.y < Atspi.Component.get_extents(node, Atspi.CoordType.SCREEN).y < bottom else (False, None)))
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, lambda: button, wait))
        wait(lambda: observed_any(lambda node: native_name(node) == 'Disconnect' and node.get_role() == Atspi.Role.HEADING))
        activate('Disconnect')
        wait(lambda: observed_none(lambda node: native_name(node).startswith('Connection management B · ')), 30)
        activate('Close')
        management_activate(a)
        management_input(original_sql); management_click('Run')
        wait(lambda: find('Row 1, n: 漢😀') and find('Row 2, n: second'), 30)
        if management_session(expected_target) != replacement:
            raise RuntimeError('Post-check cleanup changed connection A')
        row = wait(lambda: find_native_tree_row(Atspi, objects(app), labels, expected_target, current_nodes=lambda: objects(app)))
        pointer_at_native_bounds(command, visible_native_bounds(Atspi, lambda: row, wait))
        management['extraOwnedSessionsCleanedThroughUi'] = True
        management['passed'] = True
        report['nativeConnectionManagementVerified'] = management

    if os.environ.get('BUSYDATA_NATIVE_CONNECTION_MANAGEMENT_ONLY') == '1':
        if report.get('nativeConnectionManagementVerified', {}).get('passed') is not True:
            raise RuntimeError('Independent connection-management scope lacks acknowledged workflows')
        cell_label = localized('Row 1, n: 漢😀')
        focus(wait(lambda: find('Row 1, n: 漢😀')))
        wait(lambda: speech_contains([cell_label]))
        return [cell_label]

    if not postgres:
        # The same ordinary form, registry and document-owned browsing path is
        # exercised against each catalog-based engine; PostgreSQL's complete
        # advanced/IME/platform tour continues below without weaker checks.
        import csv
        import gi
        gi.require_version('Gtk', '3.0')
        from gi.repository import Gtk, Gdk
        from verify_installed_snap import paste_gtk_text, picker_has_text
        cell = wait(lambda: find('Row 1, n: 漢😀'))
        focus(cell)
        wait(lambda: speech_contains([localized('Row 1, n: 漢😀')]))
        clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
        clipboard.set_text('disposable previous value', -1)
        command(['xdotool', 'key', '--clearmodifiers', 'ctrl+c'])
        wait(lambda: clipboard.wait_for_text() == '漢😀')
        report['nativeGridExactSelectedServerCellClipboardVerified'] = True
        previous_browse = wait(lambda: native_previous_browse_generation(Atspi,
            objects(app), labels, native_name, current_nodes=lambda: objects(app)))
        photograph('query-results')
        if find('Expand busydata'): activate('Expand busydata')
        activate('Expand Tables')
        table = wait(lambda: find_native_tree_row(Atspi, objects(app), labels, 'native_atspi_fixture', current_nodes=lambda: objects(app)))
        focus(table)
        recovered_table_identity = open_selected_explorer_table(previous_browse)
        photograph('table-data')
        activate('Structure')
        wait(metadata_section_selector)
        activate('Open definition')
        report['stage'] = 'native-object-definition'
        wait(lambda: visible_object_definition(Atspi, objects(app), 'native_atspi_fixture', current_nodes=lambda: objects(app)), 30)
        report['nativeObjectDefinitionVerified'] = True
        photograph('object-definition')
        activate('Indexes')
        wait(lambda: observed_any(lambda node: 'PRIMARY' in native_name(node)), 30)
        report['nativeObjectIndexesWithoutDataQueryVerified'] = True
        photograph('object-structure')
        activate('Data')
        from native_result_editor_acceptance import verify as verify_result_editor
        verify_result_editor(Atspi, app, objects, wait, command, report,
            palette=palette, activate=activate, find=find, focus=focus,
            native_name=native_name, localized=localized, photograph=photograph,
            source_owner=recovered_table_identity,
            selected_owner=selected_result_editor_owner, speech_contains=speech_contains,
            reader_offset=reader_offset, refresh_grid=refresh_grid)
        previous = table_replacement()
        grid_action('Sort', owner=previous['tab'])
        wait(lambda: observed_any(lambda node: native_name(node) == 'Sort table data' and node.get_role() == Atspi.Role.HEADING and node.get_state_set().contains(Atspi.StateType.SHOWING)))
        if find('2 · n'): activate('2 · n'); activate('1 · id')
        activate('Ascending'); activate('Descending'); activate('Apply')
        wait(lambda: observed_none(lambda node: native_name(node) == 'Sort table data'))
        table_ready(previous, 'Row 1, id: 2', 'Row 1, n: second')
        previous = table_replacement()
        grid_action('Filter', owner=previous['tab'])
        wait(lambda: observed_any(lambda node: native_name(node) == 'Filter table data' and node.get_role() == Atspi.Role.HEADING and node.get_state_set().contains(Atspi.StateType.SHOWING)))
        if find('2 · n'): activate('2 · n'); activate('1 · id')
        exact = wait(lambda: find('Exact value', 'EditableText'))
        focus(exact); Atspi.EditableText.set_text_contents(exact, '1')
        activate('Apply')
        wait(lambda: observed_none(lambda node: native_name(node) == 'Filter table data'))
        table_ready(previous, 'Row 1, id: 1', 'Row 1, n: 漢😀', absent_labels=('Row 2, n: second',))
        previous = table_replacement()
        grid_action('Reset view', owner=previous['tab'])
        table_ready(previous, expected_rows=(('1', '漢😀'), ('2', 'second')))
        report['nativeValidatedTableSortFilterResetVerified'] = True
        # Row arrival precedes the asynchronous editing assessment. Verify the
        # actual enabled cell action before F2, without assuming native hosts
        # expose Flutter's semantic hint through AT-SPI descriptions.
        for attempt in range(3):
            report['stage'] = 'native-cell-editing-assessment'
            previous_menu_nodes = set(objects(app))
            right_click_native_row(Atspi, lambda: find('Row 1, n: 漢😀'), wait, command)
            entry = wait(lambda: find_new_menu_entry(Atspi, objects(app),
                localized('Edit cell'), previous_menu_nodes, current_nodes=lambda: objects(app)))
            enabled = all(entry.get_state_set().contains(state)
                          for state in (Atspi.StateType.ENABLED, Atspi.StateType.SENSITIVE))
            reason = entry.get_description() or ''
            report.setdefault('nativeCellEditingAssessments', []).append({
                'attempt': attempt + 1, 'enabled': enabled, 'reason': reason[:1024]})
            command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
            wait(lambda: observed_none(lambda node: node.get_role() == Atspi.Role.MENU and node.get_state_set().contains(Atspi.StateType.SHOWING)))
            if enabled:
                break
            if reason and reason not in (localized('Editability is not available'),
                    localized('Editability unavailable; refresh assessment after the session is idle')):
                raise RuntimeError('Native cell editing denied: ' + reason[:1024])
            grid_action('Assess editing')
        else:
            raise RuntimeError('Native cell editing assessment did not become available')
        focus(wait(lambda: find('Row 1, n: 漢😀')))
        native_function_key('F2')
        set_native_inline_text(Atspi, lambda: find('n', 'EditableText'), 'reviewed native edit', wait)
        command(['xdotool', 'key', '--clearmodifiers', 'Return'])
        wait(lambda: find('Row 1, n: reviewed native edit · pending change'))
        activate('Review details'); wait(lambda: find('Apply and commit'))
        review_tab = wait(lambda: find_selected_object_document(Atspi, objects(app),
            localized('Changes'), lambda node: node.get_name(), current_nodes=lambda: objects(app)))
        # Changes is a typed document. Its Cancel closes that captured tab;
        # the application panel remains mounted and is not a modal boundary.
        activate('Cancel', dismisses_modal=False)
        wait(lambda: observed_missing(lambda proof: find_query_tab_activation(Atspi, objects(app), review_tab, native_query_identity, lambda node: node.get_name(), current_nodes=proof)) and
            observed_missing(lambda proof: find('Apply and commit', current_nodes=proof)) and
            find('Row 1, n: reviewed native edit · pending change'))
        report['nativeCancelledReviewRetainsPendingCellVerified'] = True
        activate('Review details'); wait(lambda: find('Apply and commit'))
        photograph('structured-change-review')
        activate('Apply and commit')
        wait(lambda: observed_any(lambda node: native_name(node).startswith('Pre-change snapshot')), 30)
        checked = subprocess.run(['docker', 'exec', '-e', 'MYSQL_PWD', os.environ['BUSYDATA_NATIVE_FIXTURE_ID'],
            'mysql' if engine == 'MYSQL' else 'mariadb', '--default-character-set=utf8mb4', '-h', '127.0.0.1', '-u', 'root', '-D', 'busydata', '-N',
            '-e', 'SELECT id,n FROM native_atspi_fixture ORDER BY id'],
            env=dict(os.environ, MYSQL_PWD=(source / 'password').read_text()),
            check=True, capture_output=True, text=True, timeout=10).stdout.splitlines()
        if checked != ['1\treviewed native edit', '2\tsecond']:
            raise RuntimeError('Catalog-engine reviewed edit changed another row or catalog')
        report['nativeIndependentCommittedRowCheckVerified'] = True
        report['nativeInlineOwnedEditReviewApplyAndCommitVerified'] = True
        tab, action, _ = wait(lambda: find_query_tab_activation(Atspi, objects(app), 'native_atspi_fixture',
            native_query_identity, native_name, current_nodes=lambda: objects(app)))
        if not Atspi.Action.do_action(tab, action): raise RuntimeError('Table document activation rejected')
        refresh_grid()
        wait(lambda: find('Row 1, n: reviewed native edit'), 30)
        report['nativeExplicitPostChangeRefreshVerified'] = True
        palette('Export retained data')
        wait(lambda: find('Choose destination'))
        activate('Choose destination')
        tour = Path(os.environ['XDG_DATA_HOME']).parent / 'tour-files'
        tour.mkdir(mode=0o700, exist_ok=True)
        exported = tour / 'engine-result.csv'
        def picker():
            result = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', '^Save.*'],
                capture_output=True, text=True, timeout=10)
            return result.stdout.splitlines()[-1] if result.returncode == 0 and result.stdout.splitlines() else None
        window = wait(picker)
        paste_native_picker_path(Atspi, window, str(exported), wait, command)
        activate('Save')
        wait(lambda: picker() is None)
        for label in ('Review transfer', 'Start export'):
            for _ in range(16):
                action = find(label)
                if action is not None:
                    box = Atspi.Component.get_extents(action, Atspi.CoordType.WINDOW)
                    if box.y >= 0 and box.y + box.height <= 800:
                        activate(label)
                        break
                command(['xdotool', 'mousemove', '950', '700', 'click', '--repeat', '3', '--delay', '80', '5'])
            else: raise RuntimeError('Catalog-engine export action is outside its visible document')
        wait(exported.exists, 30)
        with exported.open(newline='') as stream: rows = list(csv.reader(stream))
        if rows != [['id', 'n'], ['1', 'reviewed native edit'], ['2', 'second']]:
            raise RuntimeError('Catalog-engine retained export differs from acknowledged rows')
        photograph('retained-result-export')
        report['nativeVisibleRetainedExportVerified'] = {'sha256': hashlib.sha256(exported.read_bytes()).hexdigest()}
        report['nativeCatalogEngineCoreVerified'] = True
        if ordinary_mysql:
            # Inspect the same manager through the ordinary application menu,
            # after the General-only connection/query/data route has succeeded.
            def manager_open():
                activate('Connection'); activate('Edit connection')
                wait(lambda: find('Name','EditableText'))
            manager_open()
            activate('Options', message_key='optionsSettings')
            photograph('manager-options', protected_form=True)
            activate('SSH/SSL')
            photograph('manager-ssh-ssl-off', protected_form=True)
            activate('Use SSL')
            photograph('manager-ssh-ssl-on', protected_form=True)
            activate('Cancel')
            manager_open()
            activate('Duplicate connection')
            wait(lambda: observed_field(lambda: find('Name', 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == 'Native accessibility fixture · ' + localized('Copy')))
            set_profile_field('Name','Manager independent draft')
            set_profile_field('User','busydata')
            activate('Native accessibility fixture')
            wait(lambda: observed_field(lambda: find('Name', 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == 'Native accessibility fixture'))
            activate('Manager independent draft *')
            wait(lambda: observed_field(lambda: find('Name', 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == 'Manager independent draft'))
            wait(lambda: observed_field(lambda: find('User', 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == 'busydata'))
            activate('Apply')
            wait(lambda: observed_any(lambda node: 'Configuration applied' in readable(node)))
            set_profile_field('Name','Discard this unsaved source name')
            activate('Cancel')
            manager_open()
            activate('Manager independent draft')
            wait(lambda: observed_field(lambda: find('Name', 'EditableText'), lambda observed_node: Atspi.Text.get_text(observed_node, 0, -1) == 'Manager independent draft'))
            photograph('manager-applied-independent-source', protected_form=True)
            activate('Cancel')
            report['nativeManagerDraftApplyCancelReopenVerified']=True
        return [localized('Row 1, n: 漢😀')]
    # Raw keyboard handoff while Owned sessions is still retiring. The normal
    # palette tour's explicit field focus is deliberately not used here.
    def rapid_session_palette():
        report['stage'] = 'native-rapid-owned-sessions-palette'
        def editor_node():
            return observed_sql_editor(lambda n: n.get_state_set().contains(Atspi.StateType.SHOWING))
        initial = wait(editor_node)
        focus(initial) # Establish the editor owner before opening the modal.
        original = bounded_native_text(Atspi, initial)
        original_name = native_name(initial)
        selection = [(Atspi.Text.get_selection(initial, i).start_offset,
            Atspi.Text.get_selection(initial, i).end_offset)
            for i in range(Atspi.Text.get_n_selections(initial))]
        receipts = report['nativeRapidPaletteTransitions'] = []
        def snapshot(phase):
            values = observed_values(lambda node: native_node_observation(Atspi, node)
                if node.get_state_set().contains(Atspi.StateType.FOCUSED) else None)
            if values is None:
                return {'phase': phase, 'availability': 'incomplete'}
            return {'phase': phase, 'availability': 'available',
                    'focused': [value for value in values if value is not None][:8]}
        for attempt in range(3):
            palette('Owned sessions')
            wait(lambda: find('Close'))
            receipt = {'attempt': attempt + 1, 'editorOwner': original_name,
                'sql': original, 'selection': selection, 'snapshots': [snapshot('before-dismissal')]}
            receipts.append(receipt)
            close_node, close_action, _ = wait(lambda: find_live_activation(
                Atspi, objects(app), localized('Close'), current_nodes=lambda: objects(app)))
            # This modal deliberately excludes Escape dismissal. Establish
            # focus on Close before dismissal, then send one ordered keyboard
            # sequence. An AT-SPI action acknowledgement only queues its Flutter
            # callback; racing that queue against X input can submit P first.
            focus(close_node)
            receipt['dismissalInput'] = 'Focused modal Close; physical Return then Ctrl+Shift+P; zero inter-key delay'
            receipt['snapshots'].append(snapshot('close-ready'))
            command(['xdotool', 'key', '--clearmodifiers', '--delay', '0', 'Return', 'ctrl+shift+p'])
            receipt['snapshots'].append(snapshot('route-retirement-and-palette-push'))
            query = wait(lambda: find('Search', 'EditableText'))
            receipt['snapshots'].append(snapshot('palette-open'))
            # Native semantics can expose the new field before its focus flag.
            # Type immediately, without forcing focus or waiting for it; the
            # real text destination and unchanged SQL are the decisive receipt.
            command(['xdotool', 'type', '--clearmodifiers', '--delay', '12', 'qz7'])
            wait(lambda: observed_field(lambda: find('Search', 'EditableText'),
                lambda field: Atspi.Text.get_text(field, 0, -1) == 'qz7' and
                    field.get_state_set().contains(Atspi.StateType.FOCUSED)))
            receipt['snapshots'].append(snapshot('typed-query'))
            command(['xdotool', 'key', '--clearmodifiers', 'Down', 'Escape'])
            wait(lambda: observed_missing(lambda proof: find('Search', 'EditableText', current_nodes=proof)))
            wait(lambda: observed_field(editor_node,
                lambda node: node.get_state_set().contains(Atspi.StateType.FOCUSED)))
            current = editor_node()
            if (native_name(current) != original_name or bounded_native_text(Atspi, current) != original
                or [(Atspi.Text.get_selection(current, i).start_offset,
                    Atspi.Text.get_selection(current, i).end_offset)
                    for i in range(Atspi.Text.get_n_selections(current))] != selection):
                raise RuntimeError('Rapid palette changed the original SQL editor owner, text or selection')
            receipt['snapshots'].append(snapshot('palette-closed'))
            receipt['automaticKeyboardInputVerified'] = True
        report['nativeRapidOwnedSessionsPaletteVerified'] = True
    rapid_session_palette()

    palette('Begin transaction')
    wait(lambda: observed_any(lambda item: 'Manual transaction' in (native_name(item) or '')))
    originating_editor = wait(lambda: observed_sql_editor())
    focus(originating_editor)
    originating_sql = wait(lambda: native_sql_editor_origin(Atspi, originating_editor,
        objects(app), labels, current_nodes=lambda: objects(app)))
    palette('Commit transaction')
    wait(lambda: observed_any(lambda item: native_name(item) == 'Commit transaction'))
    modal_focus = None
    photograph_product(Atspi, app, objects, wait, command, report, 'transaction-review-before-traversal', resize=False)
    for index in range(6):
        traversal = {'tab': index + 1, 'snapshots': []}
        report.setdefault('nativeModalFocusTransitions', []).append(traversal)
        def observe_focus(phase, focused, ancestry):
            if len(traversal['snapshots']) >= 24:
                return
            traversal['snapshots'].append({'phase': phase,
                'focused': [dict(native_node_observation(Atspi, node),
                    parents=[native_node_observation(Atspi, parent) for parent in ancestry[node][:12]])
                    for node in focused[:8]]})
        if index == 1 and os.environ.get('BUSYDATA_NATIVE_FOCUS_READ_PROBE') == '1':
            # Schedule this same single Tab between separate real state reads.
            # This diagnostic never supplies synthetic focus flags or UI hooks.
            dispatched = False
            def handoff(item):
                nonlocal dispatched
                if dispatched or native_name(item) != 'Cancel':
                    return
                dispatched = True
                traversal['beforeKey'] = native_node_observation(Atspi, item)
                command(['xdotool', 'key', '--clearmodifiers', 'Tab'])
                def moved():
                    values = observed_values(lambda node: node if native_name(node) == 'Commit transaction' and
                        node.get_role() == Atspi.Role.PUSH_BUTTON and
                        node.get_state_set().contains(Atspi.StateType.FOCUSED) else None)
                    if values is None:
                        return None
                    current = [value for value in values if value is not None]
                    return current[0] if len(current) == 1 else None
                target = wait(moved)
                traversal['afterKey'] = native_node_observation(Atspi, target)
            try:
                modal_focus = assert_modal_keyboard_focus(Atspi, objects(app),
                    {localized(value) for value in ('Run', 'Documents', 'Object', 'Connection', 'New connection')},
                    localized('Commit transaction'), observe_focus, handoff)
            except NativeModalFocusPending:
                traversal['mixedReadDiscarded'] = True
                modal_focus = wait_modal_keyboard_focus(Atspi, app, objects, wait,
                    {localized(value) for value in ('Run', 'Documents', 'Object', 'Connection', 'New connection')},
                    localized('Commit transaction'), previous=modal_focus, observe=observe_focus)
            if not dispatched:
                raise RuntimeError('Native handoff diagnostic did not dispatch its single Tab')
            continue
        command(['xdotool', 'key', '--clearmodifiers', 'Tab'])
        modal_focus = wait_modal_keyboard_focus(Atspi, app, objects, wait,
            {localized(value) for value in ('Run', 'Documents', 'Object', 'Connection', 'New connection')}, localized('Commit transaction'), modal_focus,
            observe=observe_focus)
    command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
    if not any(native_name(item) == 'Commit transaction' for item in objects(app)):
        raise RuntimeError('Escape bypassed transaction review')
    for index in range(6):
        command(['xdotool', 'key', '--clearmodifiers', 'shift+Tab'])
        modal_focus = wait_modal_keyboard_focus(Atspi, app, objects, wait,
            {localized(value) for value in ('Run', 'Documents', 'Object', 'Connection', 'New connection')},
            localized('Commit transaction'), modal_focus)
    photograph_product(Atspi, app, objects, wait, command, report, 'transaction-review-after-traversal', resize=False)
    cancel = wait(lambda: find('Cancel'))
    focus(cancel)
    if native_name(wait_modal_keyboard_focus(Atspi, app, objects, wait, set(), localized('Commit transaction'))) != 'Cancel':
        raise RuntimeError('Keyboard cancellation did not focus the actual Cancel control')
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    report['stage'] = 'native-commit-review-closed'
    wait(lambda: observed_none(lambda item: native_name(item) == 'Commit transaction'))
    # The modal's BlockSemantics retires background native handles. Adopt one
    # fresh handle only after complete dismissal and prove the same SQL owner.
    editor = wait(lambda: restored_native_sql_editor(Atspi, objects(app), labels,
        originating_sql['heading'], originating_sql['text'], originating_sql['pid'],
        current_nodes=lambda: objects(app)))
    restored_sql = wait(lambda: native_sql_editor_origin(Atspi, editor,
        objects(app), labels, current_nodes=lambda: objects(app)))
    if restored_sql != originating_sql:
        raise RuntimeError('Transaction cancellation changed its SQL origin editing or session context')
    report['nativeTransactionKeyboardCancelAndOriginFocusVerified'] = True
    palette('Roll back transaction')
    palette('Enable auto-commit')
    wait(lambda: observed_any(lambda item: 'Auto-commit' in (native_name(item) or '')))
    report['nativeTransactionReviewContainmentAndRollbackStateVerified'] = True
    report['stage'] = 'native-current-statement'
    editor = wait(lambda: observed_sql_editor())
    focus(editor)
    sql = 'SELECT id, n FROM native_atspi_fixture ORDER BY id;'
    if not Atspi.EditableText.set_text_contents(editor, sql):
        raise RuntimeError('Native SQL input rejected')
    wait(lambda: Atspi.Text.get_text(editor, 0, -1) == sql)
    wait(lambda: Atspi.Text.get_caret_offset(editor) == len(sql))

    def cell(label):
        return read_native_snapshot(lambda: objects(app), lambda nodes:
            find_visible_grid_cell(Atspi, nodes, label, native_name,
                current_nodes=lambda: objects(app)))

    def fixture_cell(value, *, identity='1', previous=(), owner=None):
        return find_keyed_grid_cell(Atspi, objects(app), 'id', identity, 'n', value,
                                   native_name, previous=previous, owner=owner, current_nodes=lambda: objects(app))

    def focus_fixture_cell(value):
        # Assessment and paging rebuild semantics. Resolve the retained source
        # cell for every acknowledgement, rather than keeping a node from before
        # an asynchronous palette action.
        windows = command(['xdotool', 'search', '--onlyvisible', '--name', '^BusyData$'],
                          capture_output=True, text=True).stdout.splitlines()
        if len(windows) != 1:
            raise RuntimeError('Owned retained grid window identity')
        command(['xdotool', 'windowfocus', '--sync', windows[0]])
        return focus_live_native_control(Atspi, lambda: fixture_cell(value), wait)

    wait(lambda: cell('Row 1, n: 漢😀'), 30)
    wait(lambda: cell('Row 2, n: second'))
    report['nativeCurrentStatementAndExactRetainedServerCellsVerified'] = True
    photograph('sql-explorer-results')
    report['stage'] = 'native-grid-focus-and-keyboard'
    # Screenshot resizing can virtualize this column out of the viewport and
    # dispose its native node. Resolve the verified source cell again, exactly
    # as after retained-grid assessment/paging, before checking real focus.
    focus_fixture_cell('漢😀')
    report['stage'] = 'native-grid-first-announcement'
    wait(lambda: speech_contains([localized('Row 1, n: 漢😀')]))
    report['stage'] = 'native-grid-keyboard-next-row'
    command(['xdotool', 'key', '--clearmodifiers', 'Down'])
    wait(lambda: cell('Row 2, n: second').get_state_set().contains(Atspi.StateType.SELECTED))
    wait(lambda: cell('Row 2, n: second').get_state_set().contains(Atspi.StateType.FOCUSED))
    # Screen-reader processing is asynchronous. Do not open the inspector and
    # cancel the pending announcement before observing the intended receipt.
    report['stage'] = 'native-grid-second-announcement'
    wait(lambda: speech_contains([localized('Row 2, n: second')]))
    report['nativeGridFocusAndKeyboardSelectionVerified'] = True
    report['stage'] = 'native-grid-clipboard'
    # Read the actual clipboard on this owned X display. This assertion checks
    # the selected server value, not whether a copy shortcut was dispatched.
    import gi
    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk, Gdk, GLib
    clipboard = Gtk.Clipboard.get(Gdk.SELECTION_CLIPBOARD)
    clipboard.set_text('disposable prior clipboard value', -1)
    command(['xdotool', 'key', '--clearmodifiers', 'ctrl+c'])
    wait(lambda: clipboard.wait_for_text() == 'second')
    report['nativeGridExactSelectedServerCellClipboardVerified'] = True
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait(lambda: observed_any(lambda item: (native_name(item) or '').startswith('n · text')))
    activate('Close')
    wait(lambda: observed_none(lambda item: (native_name(item) or '').startswith('n · text')))
    report['nativeGridValueInspectionDialogVerified'] = True
    def retained_execution_menu():
        # Focus the captured menu before its actual native activation, so Escape
        # returns through that trigger. A regular Results 1 tab must not be
        # mistaken for the compact menu during responsive subtree adoption.
        item = wait(lambda: find_execution_output_menu(find))
        focus(item)
        item.clear_cache()
        activation = find_live_activation(Atspi, [item], item.get_name())
        if activation is None or not Atspi.Action.do_action(item, activation[1]):
            raise RuntimeError('Native output menu rejected activation')
        def execution_captions():
            def project(node):
                name = native_name(node)
                return name if re.fullmatch(r'[0-9]+ · Completed · [0-9]+ ms', name) else None
            values = observed_values(project)
            return [value for value in values if value is not None] if values is not None else None
        names = wait(execution_captions)
        command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
        def dismissed():
            trigger = find_execution_output_menu(find)
            def observe(node):
                states = node.get_state_set()
                showing = states.contains(Atspi.StateType.SHOWING)
                return (showing and (node.get_role() == Atspi.Role.MENU or
                        native_name(node) in names),
                        node == trigger and states.contains(Atspi.StateType.FOCUSED))
            values = observed_values(observe)
            if values is None:
                return None
            return not any(open_menu for open_menu, _ in values) and any(
                restored_focus for _, restored_focus in values)
        wait(dismissed)
        return sorted(set(names))
    before_view = retained_execution_menu()
    # The extended route explicitly runs A's target query before and after
    # reconnect, then restores/runs its original SQL. Creation never runs SQL.
    expected_executions = 4 if report.get('nativeConnectionManagementVerified', {}).get('passed') else 1
    if len(before_view) != expected_executions:
        raise RuntimeError('Query execution history differs from its explicit Run actions')
    report['nativeExplicitExecutionCountBeforeRetainedView'] = expected_executions
    grid_action('Sort')
    wait(lambda: observed_any(lambda item: native_name(item) == 'Sort retained snapshot'))
    if find('2 · n'): activate('2 · n'); activate('1 · id')
    activate('Ascending')
    activate('Descending')
    activate('Apply')
    wait(lambda: cell('Row 1, n: second'), 30)
    grid_action('Filter')
    wait(lambda: observed_any(lambda item: native_name(item) == 'Filter retained snapshot'))
    if find('2 · n'): activate('2 · n'); activate('1 · id')
    from native_result_editor_acceptance import find_native_authored_modal, native_authored_modal_role
    filter_modal = wait(lambda: find_native_authored_modal(Atspi,
        lambda: objects(app), localized('Filter retained snapshot'),
        native_authored_modal_role(Atspi, report)))
    filter_pid = app.get_process_id()
    def filter_field():
        return captured_native_modal_field(filter_modal, filter_pid,
            lambda: find('Exact value', 'EditableText'), lambda: objects(app))
    set_native_inline_text(Atspi, filter_field, '2', wait, expected_original='')
    report['nativeRetainedFilterCurrentModalTextAcknowledged'] = True
    activate('Apply')
    wait(lambda: cell('Row 1, n: second'), 30)
    palette('View details')
    wait(lambda: observed_any(lambda item: native_name(item) == 'Fetched rows: 1'))
    def captured_provenance():
        def matches(item):
            text = (item.get_name() or '') + '\n' + bounded_native_text(Atspi, item, 4096)
            return 'Native accessibility fixture' in text and localized('Staging') in text
        return observed_any(matches)
    wait(captured_provenance)
    activate('Close')
    wait(lambda: observed_none(lambda item: native_name(item) == 'Fetched rows: 1'))
    report['nativeRetainedViewDetailsCapturedCountVerified'] = True
    if retained_execution_menu() != before_view:
        raise RuntimeError('Sorting or filtering retained output changed the source execution history')
    report['nativeRetainedSortFilterWithoutExecutionVerified'] = True
    photograph('retained-filtered-view')
    previous_browse = wait(lambda: native_previous_browse_generation(Atspi,
        objects(app), labels, native_name, current_nodes=lambda: objects(app)))
    palette('Explain')
    wait(lambda: observed_any(lambda item: native_name(item) == 'Review details · Explain'))
    activate('Explain')
    report['stage'] = 'native-plan-result-cells'
    wait(lambda: observed_any(lambda item: (native_name(item) or '').startswith('Row 1, QUERY PLAN:')), 30)
    palette('Plan')
    wait(lambda: observed_any(lambda item: (native_name(item) or '').startswith('Level 1, Plan')))
    photograph('execution-plan')
    report['stage'] = 'native-plan-focus-and-keyboard'
    tree = wait(lambda: observed_first(lambda item: (True, item) if (native_name(item) or '').startswith('Level 1, Plan') else (False, None)))
    focus(tree)
    wait(lambda: speech_contains([localized('Level 1, Plan')]))
    command(['xdotool', 'key', '--clearmodifiers', 'Down'])
    wait(lambda: observed_any(lambda item: (native_name(item) or '').startswith('Level 2, ') and item.get_state_set().contains(Atspi.StateType.SELECTED) and item.get_state_set().contains(Atspi.StateType.FOCUSED)))
    wait(lambda: speech_contains([localized('Level 2, ')]))
    report['nativePlanFocusAndKeyboardNavigationVerified'] = True
    palette('Open plan document')
    # A translated noun can also name an action (German Explain/Execution plan).
    # Identify this selected document by its actual title role and preserve its
    # source name rather than reversing an ambiguous translated word.
    plan_title = native_catalog_message('executionPlan') + ' ·'
    report['nativeStandalonePlanDocumentTitle'] = wait(lambda:
        find_selected_object_document(Atspi, objects(app), plan_title,
                                      lambda node: node.get_name() or '', current_nodes=lambda: objects(app)))
    if not any('EXPLAIN' in (native_name(item) or '') and 'SQL provenance' in (native_name(item) or '') for item in objects(app)):
        # At constrained heights/text sizes the actual provenance inspector is
        # reached through the native compact Plan menu.
        activate('Plan details')
        activate('SQL provenance')
        wait(lambda: observed_any(lambda item: 'EXPLAIN' in bounded_native_text(Atspi, item) and 'native_atspi_fixture' in bounded_native_text(Atspi, item)))
        report['nativeCompactPlanProvenanceInspectorVerified'] = True
        photograph('plan-provenance-inspector')
        activate('Close')
        wait(lambda: observed_none(lambda item: native_name(item) == 'SQL provenance' and item.get_role() != Atspi.Role.PUSH_BUTTON))
    photograph('independent-plan')
    report['nativeAttachedAndIndependentPlanProvenanceVerified'] = True
    palette('Close tab')
    wait(lambda: observed_none(lambda item: item.get_role() == Atspi.Role.PUSH_BUTTON and native_tab_name(item.get_name() or '').startswith(plan_title)))
    # Expand the persistent Explorer; no modal level browser is involved.
    if find('Expand Native accessibility fixture'): activate('Expand Native accessibility fixture')
    activate('Expand public')
    activate('Expand Tables')
    # Large native fonts can place the next table below the clipped viewport.
    # Move through the real tree's keyboard focus, acknowledging each row.
    def explorer_row(**options):
        return read_native_snapshot(lambda: objects(app), lambda nodes:
            find_native_tree_row(Atspi, nodes, labels,
                current_nodes=lambda: objects(app), **options))
    group = wait(lambda: explorer_row(name='Tables', loaded=True, expanded=True))
    group_identity = native_tree_row_identity(group)
    group = focus_live_native_control(Atspi,
        lambda: explorer_row(identity=group_identity, loaded=True, expanded=True), wait)
    report['nativeExplorerExpandedBranchAcknowledged'] = True
    traversal = []
    report['nativeExplorerKeyboardSteps'] = traversal
    for step in range(9):
        schema_item, previous_identity, is_target = wait(lambda: native_tree_navigation_step(
            Atspi, lambda: objects(app), labels, 'native_atspi_fixture'))
        if is_target:
            break
        if step == 8:
            raise RuntimeError('Native fixture Explorer traversal budget')
        observation = {'before': list(previous_identity), 'after': None}
        traversal.append(observation)
        report['stage'] = 'native-explorer-next-focused-row'
        command(['xdotool', 'key', '--clearmodifiers', 'Down'])
        changed = wait(lambda: native_tree_movement(Atspi,
            lambda: objects(app), labels, 'native_atspi_fixture', previous_identity))
        observation['after'] = list(changed[1])
    schema_identity = native_tree_row_identity(schema_item)
    schema_item = focus_live_native_control(Atspi,
        lambda: explorer_row(identity=schema_identity), wait)
    wait(lambda: speech_contains(['native_atspi_fixture']))
    if schema_item.get_role() != Atspi.Role.TREE_ITEM:
        raise RuntimeError('Native schema navigation lacks its tree-item role')
    report['nativeSchemaObjectFocusRoleAndSpeechVerified'] = True
    report['stage'] = 'native-explorer-enter-focused-object'
    wait(lambda: explorer_row(identity=schema_identity, focused=True))
    recovered_table_identity = open_selected_explorer_table(previous_browse)
    photograph('table-data')
    activate('Structure')
    wait(lambda: observed_any(lambda item: (native_name(item) or '').startswith('native_atspi_fixture')))
    wait(metadata_section_selector)
    activate('Open definition')
    report['stage'] = 'native-object-definition'
    wait(lambda: visible_object_definition(Atspi, objects(app), 'native_atspi_fixture', current_nodes=lambda: objects(app)), 30)
    report['nativeObjectDefinitionVerified'] = True
    photograph('object-definition')
    activate('Indexes')
    report['stage'] = 'native-object-index-metadata'
    wait(lambda: observed_any(lambda item: 'native_atspi_fixture_pkey' in (native_name(item) or '')))
    report['nativeObjectIndexesWithoutDataQueryVerified'] = True
    # A read-only metadata value must carry its associated localized property
    # name through the actual GTK text interface, not just widget semantics.
    def named_property():
        return observed_first(lambda node: (True, node) if node.get_name() == localized('Column') and supports(node, 'Text') and node.get_state_set().contains(Atspi.StateType.SHOWING) and (bounded_native_text(Atspi, node).strip() == 'id') else (False, None))
    property_node = wait(named_property)
    focus(property_node)
    wait(lambda: speech_contains([localized('Column')]))
    report['nativeStructurePropertyNameValueAndReaderVerified'] = True
    report['nativeStructurePropertyNameValueAndReaderEvidence'] = {
        'name': property_node.get_name(), 'value': bounded_native_text(Atspi, property_node),
        'role': property_node.get_role_name(), 'focused': property_node.get_state_set().contains(Atspi.StateType.FOCUSED)}
    photograph('object-structure')
    palette('Object designer')
    def selected_designer_tab():
        values = observed_values(lambda item: item if
            item.get_role() == Atspi.Role.PUSH_BUTTON and
            native_tab_name(native_name(item)) == 'native_atspi_fixture — Object designer' and
            all(item.get_state_set().contains(state) for state in
                (Atspi.StateType.SHOWING, Atspi.StateType.SELECTED)) else None)
        if values is None:
            return None
        candidates = [value for value in values if value is not None]
        if len(candidates) > 1:
            raise RuntimeError('Ambiguous native designer document owner')
        return candidates[0] if candidates else None
    designer_title = wait(selected_designer_tab).get_name()
    activate('Choose existing object')
    activate('n')
    report['stage'] = 'native-designer-field-focus'
    field = wait(lambda: find('Object / column name', 'EditableText'))
    focus(field)
    wait(lambda: Atspi.Text.get_text(field, 0, -1) == 'n')
    wait(lambda: speech_contains([localized('Object / column name')]))
    report['nativeDesignerMetadataFieldFocusAndSpeechVerified'] = True
    photograph('object-design')
    activate('Inspect captured definition')
    wait(lambda: observed_any(lambda item: native_name(item) == 'Captured object'))
    photograph('designer-captured-definition')
    # Keyboard traversal remains inside the BusyMax-derived nested modal.
    close = wait(lambda: find('Close'))
    focus(close)
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait(lambda: observed_none(lambda item: native_name(item) == 'Captured object'))
    wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith('native_atspi_fixture — Object designer')))
    report['nativeDesignerDefinitionNestedModalAndKeyboardCloseVerified'] = True
    palette('Close tab')
    review = wait(lambda: find_native_close_review(Atspi, objects(app),
        designer_title, localized('Close'), current_nodes=lambda: objects(app)))
    # This caption is already resolved in the real native locale. Preserve it
    # through activation instead of translating only its embedded title suffix.
    activate(review.get_name())
    wait(lambda: observed_none(lambda item: native_tab_name(native_name(item)).startswith('native_atspi_fixture — Object designer')))
    # Data reuses the same object's already acquired independent session.
    activate('Data')
    wait(lambda: fixture_cell('漢😀'), 30)
    from native_result_editor_acceptance import verify as verify_result_editor
    verify_result_editor(Atspi, app, objects, wait, command, report,
        palette=palette, activate=activate, find=find, focus=focus,
        native_name=native_name, localized=localized, photograph=photograph,
        source_owner=recovered_table_identity,
        selected_owner=selected_result_editor_owner, speech_contains=speech_contains,
        reader_offset=reader_offset, refresh_grid=refresh_grid)
    previous = table_replacement()
    table_owner = previous['tab']
    grid_action('Sort', owner=table_owner)
    wait(lambda: observed_any(lambda item: native_name(item) == 'Sort table data'))
    if find('2 · n'): activate('2 · n'); activate('1 · id')
    activate('Ascending')
    activate('Descending')
    activate('Apply')
    wait(lambda: observed_none(lambda item: native_name(item) == 'Sort table data'))
    table_owner = table_ready(previous, 'Row 1, id: 2', 'Row 1, n: second')['tab']
    # Repeat the operation while the same sorted value is already visible:
    # one matching retained cell cannot acknowledge the new browse operation.
    previous = table_replacement()
    table_owner = previous['tab']
    grid_action('Sort', owner=table_owner)
    wait(lambda: observed_any(lambda item: native_name(item) == 'Sort table data'))
    if find('2 · n'): activate('2 · n'); activate('1 · id')
    activate('Ascending')
    activate('Descending')
    activate('Apply')
    wait(lambda: observed_none(lambda item: native_name(item) == 'Sort table data'))
    table_owner = table_ready(previous, 'Row 1, id: 2', 'Row 1, n: second')['tab']
    photograph_product(Atspi, app, objects, wait, command, report, 'table-sorted-before-filter', resize=False)
    previous = table_replacement()
    table_owner = previous['tab']
    grid_action('Filter', interaction='pointer', owner=table_owner)
    wait(lambda: observed_any(lambda item: native_name(item) == 'Filter table data'))
    wait(lambda: find('Exact value', 'EditableText') and find('Apply') and find('Cancel'))
    photograph_product(Atspi, app, objects, wait, command, report, 'table-filter-dialog-pointer', resize=False)
    if find('2 · n'): activate('2 · n'); activate('1 · id')
    focus(wait(lambda: find('Exact value', 'EditableText')))
    Atspi.EditableText.set_text_contents(find('Exact value', 'EditableText'), '1')
    activate('Apply')
    # The matching id also exists in the prior two-row sorted snapshot. Wait
    # for the completed filtered output before invoking its next operation.
    wait(lambda: observed_none(lambda item: native_name(item) == 'Filter table data'))
    table_owner = table_ready(previous, 'Row 1, id: 1', 'Row 1, n: 漢😀',
        absent_labels=('Row 2, n: second',))['tab']
    previous = table_replacement()
    table_owner = previous['tab']
    grid_action('Reset view', owner=table_owner)
    table_owner = table_ready(previous, expected_rows=(('1', '漢😀'), ('2', 'second')))['tab']
    report['nativeValidatedTableSortFilterResetVerified'] = True
    previous = table_replacement()
    table_owner = previous['tab']
    grid_action('Sort', owner=table_owner)
    wait(lambda: observed_any(lambda item: native_name(item) == 'Sort table data'))
    if find('2 · n'): activate('2 · n'); activate('1 · id')
    activate('Ascending'); activate('Descending'); activate('Apply')
    wait(lambda: observed_none(lambda item: native_name(item) == 'Sort table data'))
    table_owner = table_ready(previous, 'Row 1, id: 2', 'Row 1, n: second')['tab']
    previous = table_replacement()
    table_owner = previous['tab']
    grid_action('Filter', interaction='keyboard', owner=table_owner)
    wait(lambda: observed_any(lambda item: native_name(item) == 'Filter table data'))
    wait(lambda: find('Exact value', 'EditableText') and find('Apply') and find('Cancel'))
    photograph_product(Atspi, app, objects, wait, command, report, 'table-filter-dialog-keyboard', resize=False)
    if find('2 · n'): activate('2 · n'); activate('1 · id')
    focus(wait(lambda: find('Exact value', 'EditableText')))
    Atspi.EditableText.set_text_contents(find('Exact value', 'EditableText'), '1')
    activate('Apply')
    wait(lambda: observed_none(lambda item: native_name(item) == 'Filter table data'))
    table_owner = table_ready(previous, 'Row 1, id: 1', 'Row 1, n: 漢😀',
        absent_labels=('Row 2, n: second',))['tab']
    previous = table_replacement()
    table_owner = previous['tab']
    grid_action('Reset view', owner=table_owner)
    inline_generation = table_ready(previous, expected_rows=(('1', '漢😀'), ('2', 'second')))
    table_owner = inline_generation['tab']
    report['nativeTablePointerAndKeyboardFilterAfterReplacementVerified'] = True
    inline_cell = focus_fixture_cell('漢😀')
    inline_identity = native_result_cell_identity(inline_cell.get_attributes().get('id'))
    expected_generation = tuple(inline_generation[key] for key in ('owner', 'source', 'display'))
    if inline_identity is None or inline_identity[:3] != expected_generation or inline_identity[4] != 1:
        raise RuntimeError('Native inline edit result generation changed')
    from native_result_editor_acceptance import wait_native_selected_cell_editable
    report['stage'] = 'native-inline-editability-readiness'
    editability_readiness = report['nativeInlineEditabilityReadiness'] = {}
    wait_native_selected_cell_editable(Atspi, lambda: objects(app), wait,
        source_owner=inline_generation['document'], selected_owner=selected_result_editor_owner,
        generation=expected_generation, row=inline_identity[3], column=inline_identity[4],
        label=f'Row {inline_identity[3] + 1}, n: 漢😀', native_name=native_name,
        editable_label=native_catalog_text('editableCell'),
        readonly_label=native_catalog_text('readonlyCell'),
        navigation_ready=lambda: selected_result_editor_owner() == inline_generation['document'],
        observation=editability_readiness)
    report['stage'] = 'native-inline-F2-editor'
    native_function_key('F2')
    set_native_inline_text(Atspi, lambda: find('n', 'EditableText'),
                           'reviewed native edit', wait)
    report['nativeInlineEditTextFieldFocusVerified'] = True
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait(lambda: fixture_cell('reviewed native edit · pending change'))
    photograph('table-pending-edit')
    activate('Review details')
    wait(lambda: observed_any(lambda item: '1 updates' in native_name(item)))
    review_tab = wait(lambda: find_selected_object_document(Atspi, objects(app),
        localized('Changes'), lambda node: node.get_name(), current_nodes=lambda: objects(app)))
    activate('Cancel', dismisses_modal=False)
    wait(lambda: observed_missing(lambda proof: find_query_tab_activation(Atspi, objects(app), review_tab, native_query_identity, lambda node: node.get_name(), current_nodes=proof)) and
        observed_missing(lambda proof: find('Apply and commit', current_nodes=proof)) and
        fixture_cell('reviewed native edit · pending change'))
    report['nativeCancelledReviewRetainsPendingCellVerified'] = True
    activate('Review details')
    wait(lambda: observed_any(lambda item: '1 updates' in (native_name(item) or '')))
    activate('Changes')
    activate('Generated SQL')
    photograph('generated-change-sql')
    report['stage'] = 'native-generated-sql-text-evidence'
    def generated_sql_evidence(item):
        if ('Text' not in item.get_interfaces() or
                item.get_role() == Atspi.Role.PASSWORD_TEXT or
                not item.get_state_set().contains(Atspi.StateType.SHOWING)):
            return None
        text = bounded_native_text(Atspi, item)
        return {'name': native_name(item)[:128], 'role': item.get_role_name(),
            'characters': Atspi.Text.get_character_count(item),
            'reviewedFixtureSql': text[:4096] if text.startswith('UPDATE') and 'native_atspi_fixture' in text else None}
    generated_evidence, = wait(lambda: native_complete_observation(observed_values(generated_sql_evidence)))
    report['nativeGeneratedSqlTextEvidence'] = [record for record in generated_evidence if record is not None]
    wait(lambda: observed_any(lambda item: 'UPDATE' in bounded_native_text(Atspi, item) and 'native_atspi_fixture' in bounded_native_text(Atspi, item)))
    # The mode selector retains its role name while its selected value changes.
    activate('Changes')
    activate('Changes')
    wait(lambda: observed_any(lambda item: native_name(item) == 'Original'))
    wait(lambda: observed_any(lambda item: native_name(item) == 'Proposed'))
    photograph('structured-change-review')
    activate('Apply and commit')
    wait(lambda: observed_any(lambda item: (native_name(item) or '').startswith('Pre-change snapshot')), 30)
    environment = dict(os.environ, PGPASSWORD=(source / 'password').read_text())
    checked = subprocess.run(['docker', 'exec', '-e', 'PGPASSWORD', os.environ['BUSYDATA_NATIVE_FIXTURE_ID'], 'psql', '-h', '127.0.0.1', '-U', 'busydata', '-d', 'busydata', '-Atc', 'SELECT id,n FROM public.native_atspi_fixture ORDER BY id'], env=environment, capture_output=True, text=True, check=True, timeout=10).stdout.splitlines()
    if checked != ['1|reviewed native edit', '2|second']: raise RuntimeError('Reviewed edit did not update exactly the intended fixture row')
    report['nativeIndependentCommittedRowCheckVerified'] = True
    report['nativeInlineOwnedEditReviewApplyAndCommitVerified'] = True
    palette('Close tab')
    wait(lambda: fixture_cell('漢😀'))
    wait(lambda: observed_any(lambda item: (native_name(item) or '').startswith('Pre-change snapshot')))
    report['nativeCommittedChangesPreservePreChangeSnapshotVerified'] = True
    refresh_grid()
    wait(lambda: fixture_cell('reviewed native edit'), 30)
    report['nativeExplicitPostChangeRefreshVerified'] = True
    # Restore the disposable fixture through the same reviewed UI workflow;
    # subsequent native theme/scale cases share this database deliberately.
    focus_fixture_cell('reviewed native edit')
    palette('Assess editing')
    report['stage'] = 'native-refreshed-grid-keyboard-focus'
    refreshed_cell = focus_fixture_cell('reviewed native edit')
    report['nativeRefreshedCellDescription'] = refreshed_cell.get_description()
    windows = command(['xdotool', 'search', '--onlyvisible', '--name', '^BusyData$'], capture_output=True, text=True).stdout.splitlines()
    if len(windows) != 1: raise RuntimeError('Owned grid window identity')
    command(['xdotool', 'windowfocus', '--sync', windows[0]])
    report['nativeRefreshedCellInterfaces'] = list(refreshed_cell.get_interfaces())
    command(['xdotool', 'key', '--clearmodifiers', 'Left'])
    wait(lambda: observed_any(lambda item: native_name(item).endswith(', id: 1') and item.get_state_set().contains(Atspi.StateType.FOCUSED)))
    command(['xdotool', 'key', '--clearmodifiers', 'Right'])
    def refreshed_focus():
        candidate = fixture_cell('reviewed native edit')
        return candidate and candidate.get_state_set().contains(Atspi.StateType.FOCUSED)
    wait(refreshed_focus)
    report['stage'] = 'native-refreshed-inline-edit-keyboard'
    # Use the same complete native keystroke as the initial inline edit.
    # Release the key before awaiting the resulting editable field.
    native_function_key('F2')
    set_native_inline_text(Atspi, lambda: find('n', 'EditableText'), '漢😀', wait)
    command(['xdotool', 'key', '--clearmodifiers', 'Return'])
    wait(lambda: fixture_cell('漢😀 · pending change'))
    palette('Apply and commit')
    wait(lambda: observed_any(lambda item: '1 updates' in native_name(item)))
    activate('Apply and commit')
    wait(lambda: observed_any(lambda item: native_name(item).startswith('Pre-change snapshot')), 30)
    palette('Close tab')
    refresh_grid()
    wait(lambda: fixture_cell('漢😀'), 30)
    report['nativeFixtureRestoredThroughReviewedUiVerified'] = True
    if restart is not None and not os.environ.get('BUSYDATA_NATIVE_ACCEPTANCE_EXECUTABLE'):
        from verify_installed_snap import paste_gtk_text, picker_has_text, picker_location_field
        tour = Path(os.environ['XDG_DATA_HOME']).parent / 'tour-files'
        tour.mkdir(mode=0o700, exist_ok=True)

        def click_visible(item):
            box = visible_native_bounds(Atspi,
                lambda: item if item in objects(app) else None, wait)
            pointer_at_native_bounds(command, box)

        def new_visible_query():
            report['stage'] = 'native-core-new-query'
            previous_values, = wait(lambda: native_complete_observation(observed_values(lambda node:
                native_query_identity(native_name(node)) if node.get_role() == Atspi.Role.PUSH_BUTTON and
                native_tab_name(native_name(node)).startswith('Query ') else None)))
            previous = {identity for identity in previous_values if identity is not None}
            previous_nodes = set(objects(app))
            if find(documents_menu) is None:
                click_visible(wait(lambda: find('Main menu')))
            click_visible(wait(lambda: find(documents_menu)))
            def menu_action():
                return find_new_menu_activation(Atspi, objects(app), localized('New query'), previous_nodes,
                    fluent=report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent',
                    shortcut='Ctrl+T', current_nodes=lambda: objects(app))
            bounds = visible_native_bounds(Atspi,
                lambda: action[0] if (action := menu_action()) is not None else None, wait)
            pointer_at_native_bounds(command, bounds)
            identity = wait(lambda: find_new_selected_query(Atspi, objects(app), previous, native_name, current_nodes=lambda: objects(app)))
            wait(lambda: observed_any(lambda node: native_name(node).startswith('SQL editor') and supports(node, 'EditableText') and (Atspi.Text.get_text(node, 0, -1) == '')))
            report.setdefault('nativeCoreConsoleCreations', []).append({
                'previousIdentities': sorted(previous), 'acknowledgedNewIdentity': identity})
            return identity

        def activate_core_query(identity):
            item, _, _ = wait(lambda: find_query_tab_activation(Atspi, objects(app), identity,
                native_query_identity, native_name, current_nodes=lambda: objects(app)))
            click_visible(item)
            wait(lambda: item.get_state_set().contains(Atspi.StateType.SELECTED))

        def input_core_sql(sql):
            editor = wait(lambda: observed_sql_editor())
            focus(editor)
            if not Atspi.EditableText.set_text_contents(editor, sql):
                raise RuntimeError('Core SQL input rejected')
            wait(lambda: Atspi.Text.get_text(editor, 0, -1) == sql)
            return editor

        def run_core_query(sql, credentials=False):
            identity = wait(lambda: observed_first(lambda node: (True, native_query_identity(native_name(node))) if (native_tab_name(native_name(node)).startswith('Query ') or native_query_identity(native_name(node)).endswith('.sql')) and node.get_state_set().contains(Atspi.StateType.SELECTED) else (False, None)))
            input_core_sql(sql)
            activate('Run')
            if credentials:
                secret = wait(lambda: find('Password', 'EditableText'))
                focus(secret)
                supply_password(secret)
                activate('Connect')
            wait(lambda: observed_any(lambda node: native_name(node) == 'Review details' or (native_query_identity(native_name(node)) == identity and native_tab_has_status(native_name(node), 'Running', 'Completed'))), 30)
            review_open, = wait(lambda: native_complete_observation(
                observed_any(lambda node: native_name(node) == 'Review details')))
            if review_open:
                activate('Run')
            pattern = re.compile(r' · ([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$')
            return wait(lambda: observed_first(lambda node: (True, match.group(1)) if native_name(node).startswith('Native accessibility fixture · 127.0.0.1:') and (match := pattern.search(native_name(node))) else (False, None)), 30)

        def choose_core_file(path, saving):
            report['stage'] = 'native-sql-save-picker' if saving else 'native-sql-open-picker'
            def picker():
                reply = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', '^Save.*' if saving else '^Open.*'],
                    capture_output=True, text=True, timeout=10)
                found = reply.stdout.splitlines()
                return found[-1] if reply.returncode == 0 and found else None
            window = wait(picker)
            if path.parent != tour or (saving and path.exists()):
                raise RuntimeError('Owned SQL file picker destination')
            command(['xdotool', 'windowfocus', '--sync', window])
            command(['xdotool', 'key', '--clearmodifiers', 'ctrl+l'])
            field = wait(lambda: picker_location_field(window))
            if not Atspi.EditableText.set_text_contents(field, str(path)):
                raise RuntimeError('Visible native chooser rejected path entry')
            wait(lambda: Atspi.Text.get_text(field, 0, -1) == str(path))
            if saving:
                command(['xdotool', 'key', '--clearmodifiers', 'Return'])
            else:
                # In GTK's location entry, Enter can navigate/select without
                # accepting the chooser. Use its visible completion action.
                activate('Open')
            wait(lambda: picker() is None)

        report['stage'] = 'native-core-independent-consoles'
        a = new_visible_query()
        a_session = run_core_query('SELECT pg_sleep(20), current_database() AS target_name;', credentials=True)
        b = new_visible_query()
        b_session = run_core_query('SELECT pg_sleep(3), current_database() AS target_name;', credentials=True)
        if a == b or a_session == b_session:
            raise RuntimeError('Core consoles did not acquire distinct independent sessions')
        activate_core_query(a)
        editor = wait(lambda: observed_sql_editor())
        focus(editor)
        wait(lambda: observed_any(lambda node: native_query_identity(native_name(node)) == b and native_tab_has_status(native_name(node), 'Completed')), 20)
        if not editor.get_state_set().contains(Atspi.StateType.FOCUSED) or Atspi.Text.get_text(editor, 0, -1) != 'SELECT pg_sleep(20), current_database() AS target_name;':
            raise RuntimeError('Background core result changed the initiating editor')
        wait(lambda: observed_any(lambda node: native_query_identity(native_name(node)) == a and native_tab_has_status(native_name(node), 'Completed')), 30)
        report['nativeVisibleIndependentConsolesAndFocusVerified'] = {'first': a, 'second': b, 'distinctSessions': True}
        sql = 'SELECT id, n FROM public.native_atspi_fixture ORDER BY id;'
        run_core_query(sql)
        wait(lambda: fixture_cell('漢😀'), 30)
        history = retained_execution_menu()
        editor = wait(lambda: observed_sql_editor())
        focus(editor)
        command(['xdotool', 'key', '--clearmodifiers', 'ctrl+s'])
        saved_sql = tour / 'workflow.sql'
        choose_core_file(saved_sql, True)
        wait(saved_sql.exists)
        if saved_sql.read_text() != sql: raise RuntimeError('Saved core SQL contents changed')
        wait(lambda: observed_any(lambda node: native_query_identity(native_name(node)) == 'workflow.sql' and (not (node.get_name() or '').startswith('● '))))
        activate('Documents')
        activate('Open SQL file')
        choose_core_file(saved_sql, False)
        wait(lambda: observed_any(lambda node: native_query_identity(native_name(node)) == 'workflow.sql' and node.get_state_set().contains(Atspi.StateType.SELECTED)))
        if retained_execution_menu() != history or find('Native accessibility fixture') is None:
            raise RuntimeError('Reopening SQL lost its target or changed execution history')
        photograph('sql-saved-and-reopened')
        report['nativeSqlSaveReopenTargetWithoutExecutionVerified'] = {'file': str(saved_sql), 'sha256': hashlib.sha256(saved_sql.read_bytes()).hexdigest()}
        palette('Export retained data')
        wait(lambda: find('Choose destination'))
        activate('Choose destination')
        exported = tour / 'workflow-result.csv'
        choose_core_file(exported, True)
        def core_transfer_action(label):
            for _ in range(16):
                node = find(label)
                if node is not None:
                    box = Atspi.Component.get_extents(node, Atspi.CoordType.SCREEN)
                    frame = next(parent for parent in accessible_ancestors(node)
                                 if parent.get_role() == Atspi.Role.FRAME)
                    allocation = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
                    if box.y >= allocation.y and box.y + box.height <= allocation.y + allocation.height:
                        click_visible(node)
                        return
                xid = owned_product_window(command, wait, app.get_process_id())
                geometry = dict(line.split('=', 1) for line in command(['xdotool', 'getwindowgeometry', '--shell', xid],
                    capture_output=True, text=True).stdout.splitlines() if '=' in line)
                command(['xdotool', 'mousemove', str(int(geometry['X']) + int(geometry['WIDTH']) * 3 // 4),
                    str(int(geometry['Y']) + int(geometry['HEIGHT']) - 100), 'click', '--repeat', '3', '--delay', '80', '5'])
            raise RuntimeError('Visible transfer completion action unavailable')
        core_transfer_action('Review transfer')
        core_transfer_action('Start export')
        wait(exported.exists, 30)
        import csv
        with exported.open(newline='') as stream: rows = list(csv.reader(stream))
        if rows != [['id', 'n'], ['1', '漢😀'], ['2', 'second']]:
            raise RuntimeError('Core retained export contents differ from the displayed result')
        photograph('retained-result-export')
        activate_core_query('workflow.sql')
        if retained_execution_menu() != history:
            raise RuntimeError('Retained export re-executed the source SQL')
        report['nativeVisibleRetainedExportWithoutExecutionVerified'] = {'file': str(exported), 'sha256': hashlib.sha256(exported.read_bytes()).hexdigest()}
        report['stage'] = 'native-core-wm-delete-cancel'
        editor = wait(lambda: observed_sql_editor())
        focus(editor)
        os_close_origin = wait(lambda: native_palette_sql_checkpoint(Atspi, objects(app), labels,
            current_nodes=lambda: objects(app)))
        if os_close_origin == (None,):
            raise RuntimeError('OS close cancellation requires its captured SQL document')
        window = owned_product_window(command, wait, app.get_process_id())
        request_owned_x11_window_close(command, window, app.get_process_id())
        close_review = wait(lambda: find('Save drafts and close'))
        activate('Stay', message_key='stay')
        close_title = native_catalog_text('closeBusyData')
        wait(lambda: observed_none(lambda node: node == close_review or node.get_name() == close_title))
        editor = wait(lambda: restored_native_sql_editor(Atspi, objects(app), labels,
            os_close_origin[1], os_close_origin[3], os_close_origin[2],
            current_nodes=lambda: objects(app)))
        def restored_os_origin():
            captured = native_palette_sql_checkpoint(Atspi, objects(app), labels,
                current_nodes=lambda: objects(app))
            return captured if captured != (None,) else None
        os_close_restored = wait(restored_os_origin)
        if os_close_restored[1:] != os_close_origin[1:]:
            raise RuntimeError('OS close cancellation changed the captured SQL document or editing context')
        report['nativeWmDeleteCancelAndSqlOriginRestoredVerified'] = True
        report['stage'] = 'native-core-normal-close'
        def window_close():
            def observe(node):
                if native_name(node) != 'Close' or 'Component' not in node.get_interfaces():
                    return None
                ancestors = accessible_ancestors(node)
                frame = next((parent for parent in ancestors if parent.get_role() == Atspi.Role.FRAME), None)
                if frame is None:
                    return None
                box = Atspi.Component.get_extents(node, Atspi.CoordType.SCREEN)
                allocation = Atspi.Component.get_extents(frame, Atspi.CoordType.SCREEN)
                return node if (box.y < allocation.y + 64 and
                    node.get_state_set().contains(Atspi.StateType.SHOWING)) else None
            values = observed_values(observe)
            if values is None:
                return None
            showing = [node for node in values if node is not None]
            if len(showing) > 1:
                raise RuntimeError('Ambiguous native window close control')
            return showing[0] if showing else None
        click_visible(wait(window_close))
        wait(lambda: find('Save drafts and close'))
        activate('Save drafts and close')
        app = restart()
        rows = subprocess.run(['docker', 'exec', '-e', 'PGPASSWORD', os.environ['BUSYDATA_NATIVE_FIXTURE_ID'],
            'psql', '-h', '127.0.0.1', '-U', 'busydata', '-d', 'busydata', '-Atc',
            "SELECT count(*) FROM pg_stat_activity WHERE application_name='BusyData'"],
            env=dict(os.environ, PGPASSWORD=(source / 'password').read_text()), check=True,
            capture_output=True, text=True, timeout=10).stdout.strip()
        if rows != '0': raise RuntimeError('Workspace restoration silently reconnected to the database')
        activate_core_query('workflow.sql')
        editor = wait(lambda: observed_sql_editor())
        if Atspi.Text.get_text(editor, 0, -1) != sql or find('Native accessibility fixture') is None:
            raise RuntimeError('Normal relaunch lost saved SQL or its profile reference')
        wait(lambda: observed_any(lambda node: 'Connects when run' in native_name(node)))
        photograph('workspace-restored-disconnected')
        run_core_query(sql, credentials=True)
        wait(lambda: fixture_cell('漢😀'), 30)
        recovered_previous_browse = wait(lambda: native_previous_browse_generation(
            Atspi, objects(app), labels, native_name, current_nodes=lambda: objects(app)))
        # Deliberate Explorer expansion includes credential acquisition and loads
        # its visible scope as part of the same action after restoration.
        activate('Expand Native accessibility fixture')
        secret = wait(lambda: find('Password', 'EditableText'))
        focus(secret)
        supply_password(secret)
        activate('Connect')
        wait(lambda: find_native_tree_row(Atspi, objects(app), labels, 'public', current_nodes=lambda: objects(app)), 30)
        report['nativeNormalRelaunchDisconnectedAndDeliberateReconnectVerified'] = True
        activate('Expand public')
        activate('Expand Tables')
        # The Explorer was explicitly authenticated above. Reuse its selected
        # physical session, exactly as ordinary browsing does; a second password
        # prompt is not evidence of ownership. Prove a new result generation,
        # exact rows, the selected physical owner and generated SQL instead.
        recovered_table_identity = open_selected_explorer_table(
            recovered_previous_browse,
            proof_key='nativeRecoveredTableBrowseProof',
            previous_source_observation='visible query result after deliberate reconnect')
        report['nativeRecoveredTableResumesThroughOwnedAcquisitionVerified'] = True
    if not os.environ.get('BUSYDATA_NATIVE_SETTINGS_INPUT'):
        import csv
        from verify_installed_snap import paste_gtk_text, picker_has_text
        tour = Path(os.environ['XDG_DATA_HOME']).parent / 'tour-files'
        tour.mkdir(mode=0o700, exist_ok=True)

        def tap_item(item):
            # Resolve the actual showing, enabled control again before dispatch;
            # an AT-SPI action on an obsolete/nonshowing node can return True.
            raw = item.get_name() or ''
            if native_tab_name(native_name(item)).startswith('Query '):
                identity = query_identity(native_name(item))
                current, activation, names = wait(lambda: find_query_tab_activation(
                    Atspi, objects(app), identity, query_identity, native_name, current_nodes=lambda: objects(app)))
                report['stage'] = 'native-query-activation: ' + identity
                report['nativeActionNames'] = names
                if not Atspi.Action.do_action(current, activation):
                    raise RuntimeError('Native query tab rejected activation')
                report['nativeLastAcknowledgedActivation'] = {
                    'control': identity, 'action': names[activation]}
                return
            activate(raw)

        def wheel(direction=5):
            # Real pointer events inside this owned document allocation.
            window = command(['xdotool', 'search', '--onlyvisible', '--name', '^BusyData$'],
                             capture_output=True, text=True).stdout.splitlines()
            if len(window) != 1:
                raise RuntimeError('Owned workbench window identity')
            values = dict(line.split('=', 1) for line in command(
                ['xdotool', 'getwindowgeometry', '--shell', window[0]],
                capture_output=True, text=True).stdout.splitlines() if '=' in line)
            # --sync waits forever when repeated scrolling keeps the pointer
            # at the same position. The ensuing visible-control acknowledgement
            # proves the real scroll; no pointer movement is required to repeat.
            command(['xdotool', 'mousemove',
                     str(int(values['X']) + int(values['WIDTH']) * 3 // 4),
                     str(int(values['Y']) + int(values['HEIGHT']) - 80),
                     'click', '--repeat', '3', '--delay', '80', str(direction)])

        def reveal(name, interface='Action', direction=5):
            for attempt in range(16):
                item = find(name, interface)
                if item is not None:
                    return item
                wheel(direction)
            raise RuntimeError('Contextual control unavailable: ' + name)

        def inspect_selected_activity_sql(expected=None):
            report['stage'] = 'native-activity-selected-query'
            for attempt in range(16):
                def project(item):
                    record = None
                    if item.get_role() == Atspi.Role.PASSWORD_TEXT or not supports(item, 'Text'):
                        return None, None
                    count = Atspi.Text.get_character_count(item)
                    if 0 < count <= 65536:
                        record = {'role': item.get_role_name(),
                            'interfaces': list(item.get_interfaces()), 'characters': count,
                            'showing': item.get_state_set().contains(Atspi.StateType.SHOWING),
                            'visible': item.get_state_set().contains(Atspi.StateType.VISIBLE),
                            'authoredSql': 'UPDATE native_atspi_fixture' in Atspi.Text.get_text(item, 0, count)}
                    preview = native_readonly_sql_preview(Atspi, item, native_name)
                    return record, preview
                def observation():
                    values = observed_values(project)
                    return (values,) if values is not None else None
                values, = wait(observation)
                report['nativeSelectedActivityTextEvidence'] = [record for record, _ in values if record is not None]
                # Owned read-only text fields expose ENTRY plus READ_ONLY.
                # EditableText may provide Copy; EDITABLE must remain absent.
                previews = [preview for _, preview in values if preview is not None]
                if any(text and text != 'SQL' and len(text) <= 8192 and
                       (expected is None or expected in text) for text in previews):
                    return
                wheel()
            raise RuntimeError('Selected activity SQL did not become inspectable')

        def set_field(name, value):
            report['stage'] = 'native-context-input: ' + name
            field = focus_visible_native_field(Atspi, lambda: find(name, 'EditableText'), wait)
            if not Atspi.EditableText.set_text_contents(field, value):
                raise RuntimeError('Owned native field rejected input: ' + name)
            wait_native_field_value(Atspi, lambda: find(name, 'EditableText'), value, wait)

        def create_profile(name, database, environment):
            palette('New connection')
            wait(lambda: find('Name', 'EditableText'))
            for field, value in [('Name', name),
                                 ('Host', '127.0.0.1'),
                                 ('Port', os.environ['BUSYDATA_NATIVE_FIXTURE_PORT']),
                                 ('Database', database), ('User', 'busydata')]:
                set_field(field, value)
            password = focus_profile_password(Atspi, app, objects, wait, command,
                                              report, localized('Password'))
            secret = (source / 'password').read_text()
            Atspi.EditableText.set_text_contents(password, secret)
            wait(lambda: observed_field(lambda: find('Password', 'EditableText'), lambda observed_node: Atspi.Text.get_character_count(observed_node) == len(secret)))
            activate('Options', message_key='optionsSettings')
            activate('Development')
            activate(environment)
            activate('SSH/SSL')
            activate('Use SSL')
            def checked_ssl_anchor():
                field = find('Use SSL')
                return field if field is not None and field.get_state_set().contains(Atspi.StateType.CHECKED) else None
            reveal_native_choice_with_keyboard(
                Atspi, app, objects, wait, command, anchor=checked_ssl_anchor,
                dialog_name=native_catalog_text('managerTitle'),
                label=localized('Mode'), selected=localized('Require'))
            activate('Require')
            activate('Full Verification')
            set_field('CA certificate file', str(source / 'ca.crt'))
            activate('General', message_key='generalSettings')
            activate('Apply')
            wait(lambda: observed_any(lambda item: 'Configuration applied' in readable(item)))
            activate('Cancel')
            wait(lambda: observed_missing(lambda proof: find('Name', 'EditableText', current_nodes=proof)))
            wait(lambda: observed_any(lambda item: native_name(item).startswith(name + ' · level 1')))

        query_identity = native_query_identity

        def selected_query():
            return wait(lambda: observed_first(lambda item: (True, query_identity(native_name(item))) if native_tab_name(native_name(item)).startswith('Query ') and item.get_state_set().contains(Atspi.StateType.SELECTED) else (False, None)))

        def activate_query(identity):
            item = wait(lambda: observed_first(lambda item: (True, item) if native_tab_name(native_name(item)).startswith(identity) and supports(item, 'Action') else (False, None)))
            tap_item(item)
            wait(lambda: observed_any(lambda node: native_tab_name(native_name(node)).startswith(identity) and node.get_state_set().contains(Atspi.StateType.SELECTED)))

        def input_sql(sql):
            editor = wait(lambda: observed_sql_editor())
            focus(editor)
            if not Atspi.EditableText.set_text_contents(editor, sql):
                raise RuntimeError('Native SQL document rejected fixture text')
            wait(lambda: Atspi.Text.get_text(editor, 0, -1) == sql and
                         Atspi.Text.get_caret_offset(editor) == len(sql))
            return editor

        def connect_query(profile):
            session_pattern = re.compile(r' · ([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})$')
            def prior_session(node):
                match = session_pattern.search(native_name(node))
                return match.group(1) if match is not None else None
            prior_values = wait_native_inventory(lambda: objects(app), prior_session, wait)
            prior_sessions = {value for value in prior_values if value is not None}
            palette('New query')
            # New query intentionally inherits a profile reference from an
            # object/connection context, while retaining an independent session.
            def query_choice():
                choices = ['No connection', 'Native accessibility fixture',
                           'Desired reference fixture', 'Native production fixture']
                nodes = objects(app)
                available = []
                for name in choices:
                    complete, choice = _complete_native_control_lookup(Atspi, nodes,
                        localized(name), 'Action', current_nodes=lambda: objects(app))
                    if not complete:
                        return None
                    if choice is not None:
                        available.append(name)
                if len(available) > 1:
                    raise RuntimeError('Ambiguous document connection selector')
                return available[0] if available else None
            current_profile = wait(query_choice)
            if current_profile != profile:
                activate(current_profile)
                activate(profile)
            palette('Connect')
            password = wait(lambda: find('Password', 'EditableText'))
            focus(password)
            secret = (source / 'password').read_text()
            Atspi.EditableText.set_text_contents(password, secret)
            wait(lambda: Atspi.Text.get_character_count(password) == len(secret))
            activate('Connect')
            def adopted_query():
                def observe(node):
                    name = native_name(node)
                    identity = query_identity(name) if (
                        native_tab_name(name).startswith('Query ') and
                        node.get_state_set().contains(Atspi.StateType.SELECTED)) else None
                    match = session_pattern.search(name) if name.startswith(
                        profile + ' · 127.0.0.1:') else None
                    return identity, match.group(1) if match is not None else None
                values = observed_values(observe)
                if values is None:
                    return None
                identities = {identity for identity, _ in values if identity is not None}
                if len(identities) > 1:
                    raise RuntimeError('Ambiguous selected query owner during session adoption')
                sessions = {session for _, session in values if session is not None}
                adopted = sessions - prior_sessions
                if len(identities) != 1 or len(adopted) != 1:
                    return None
                return next(iter(identities)), next(iter(adopted))
            identity, session = wait(adopted_query, 20)
            report.setdefault('nativeIndependentQuerySessions', {})[identity] = session
            return identity

        def run_sql(sql, review=False):
            editor = input_sql(sql)
            palette('Run current statement')
            if review:
                wait(lambda: observed_any(lambda item: native_name(item) == 'Review details'))
                activate('Run')
            return editor

        def right_menu(prefix):
            current = lambda: observed_first(lambda item: (True, item) if native_name(item).startswith(prefix) and supports(item, 'Component') and item.get_state_set().contains(Atspi.StateType.SHOWING) else (False, None))
            right_click_native_row(Atspi, current, wait, command)

        def choose_comparison(label, profile):
            report['stage'] = 'native-comparison-target: ' + label
            for attempt in range(16):
                def observation():
                    values = observed_values(lambda item: item if
                        (native_name(item).startswith(label + '\n') or
                         native_name(item).startswith(label + ': ')) and supports(item, 'Action') and
                        find_live_activation(Atspi, [item], item.get_name()) is not None else None)
                    return ([value for value in values if value is not None],) if values is not None else None
                candidates, = wait(observation)
                if len(candidates) > 1:
                    raise RuntimeError('Ambiguous captured comparison target')
                if candidates:
                    tap_item(candidates[0])
                    activate(profile + ' · Staging')
                    return
                wheel()
            raise RuntimeError('Labelled comparison target unavailable: ' + label)

        def choose_file(path):
            report['stage'] = 'native-output-picker: ' + path.name
            def chooser():
                # No match is an ordinary transient while this owned native
                # picker opens or closes, not a failed activation.
                reply = __import__('subprocess').run(['xdotool', 'search', '--onlyvisible', '--name', '^Save.*'],
                                capture_output=True, text=True, timeout=10)
                candidates = reply.stdout.splitlines()
                return candidates[-1] if reply.returncode == 0 and candidates else None
            window = wait(chooser)
            if not window.isdecimal() or path.parent != tour or path.exists():
                raise RuntimeError('Owned native file destination identity')
            paste_native_picker_path(Atspi, window, str(path), wait, command)
            # GTK can use Enter here to navigate/select the location while its
            # save chooser remains open. Invoke the visible completion action.
            activate('Save')
            wait(lambda: chooser() is None)

        create_profile('Desired reference fixture', 'busydata_desired', 'Staging')
        create_profile('Native production fixture', 'busydata', 'Production')
        # A real blocked session is inspected through connection administration.
        a = connect_query('Native accessibility fixture')
        # Inspect secondary presentation in the ordinary product. These visits
        # dismiss drafts without saving, inserting SQL or changing settings.
        palette('Settings')
        activate('Execution options', message_key='executionOptions')
        wait(lambda: find('Result row limit (1–1000000)', 'EditableText'))
        photograph('preferences-execution-recovery-shortcuts')
        activate('Close', dismisses_modal=False)
        wait(lambda: observed_missing(lambda proof: find('Result row limit (1–1000000)', 'EditableText', current_nodes=proof)))
        palette('SQL snippets')
        wait(lambda: find('Snippet name', 'EditableText'))
        set_field('Snippet name', 'Native typography 漢字')
        photograph('snippet-editor-unsaved')
        activate('Close')
        wait(lambda: observed_missing(lambda proof: find('Snippet name', 'EditableText', current_nodes=proof)))
        palette('Execution options')
        wait(lambda: find('Result row limit (1–1000000)', 'EditableText'))
        photograph('execution-options')
        activate('Cancel')
        wait(lambda: observed_missing(lambda proof: find('Result row limit (1–1000000)', 'EditableText', current_nodes=proof)))
        for title, picture in [('History', 'history-records'),
                ('Jobs', 'job-records'), ('Retained results', 'retained-result-records')]:
            palette(title)
            wait(lambda: find('Close ' + title))
            photograph(picture)
            activate('Close ' + title)
            wait(lambda: observed_missing(lambda proof: find('Close ' + title, current_nodes=proof)))
        activate_query(a)
        report['nativeSecondaryPresentationVisitsVerified'] = True
        palette('Begin transaction')
        run_sql('UPDATE native_atspi_fixture SET n=n WHERE id=1;', review=True)
        wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith(a) and native_tab_has_status(native_name(item), 'Completed')))
        blocked = connect_query('Native accessibility fixture')
        run_sql('UPDATE native_atspi_fixture SET n=n WHERE id=1;', review=True)
        wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith(blocked) and native_tab_has_status(native_name(item), 'Running')))
        right_menu('Native accessibility fixture · level 1')
        activate('Sessions and locks')
        wait(lambda: find('Filter current activities', 'EditableText'))
        set_field('Filter current activities', 'Lock')
        wait(lambda: observed_any(lambda item: native_name(item) == 'Blocked by:'))
        waiting = wait(lambda: observed_first(lambda item: (True, item) if ' · busydata · busydata · active · ' in native_name(item) and 'Lock' in native_name(item) and supports(item, 'Action') else (False, None)))
        waiting_name = native_name(waiting)
        tap_item(waiting)
        wait(lambda: observed_any(lambda node: native_name(node) == waiting_name and node.get_state_set().contains(Atspi.StateType.SELECTED)))
        photograph('administration-selected-activity')
        inspect_selected_activity_sql('UPDATE native_atspi_fixture')
        photograph('administration-blocked-session')
        blocker = wait(lambda: observed_first(lambda item: (True, item) if native_name(item).isdigit() and supports(item, 'Action') and (item.get_role() == Atspi.Role.PUSH_BUTTON) else (False, None)))
        blocker_id = blocker.get_name()
        tap_item(reveal(blocker_id, direction=4))
        wait(lambda: observed_any(lambda node: native_name(node).startswith(blocker_id + ' · ') and node.get_state_set().contains(Atspi.StateType.SELECTED)))
        inspect_selected_activity_sql()
        photograph('administration-blocker-detail')
        tap_item(reveal(waiting_name, direction=4))
        activate('Cancel selected activity')
        wait(lambda: observed_any(lambda item: native_name(item) == 'Review details'))
        photograph('activity-fingerprint-review')
        activate('Cancel')
        # Cancel here dismisses the consequential review; no dispatch is claimed.
        report['nativeActivityBlockerAndCapturedReviewVerified'] = True
        activate_query(blocked)
        palette('Cancel')
        wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith(blocked) and native_tab_has_status(native_name(item), 'Cancelled', 'Failed')), 15)
        activate_query(a)
        palette('Roll back transaction')
        palette('Enable auto-commit')
        # Different targets run concurrently. B's completion leaves A focused.
        editor_a = run_sql('SELECT pg_sleep(20), current_database() AS target_name;', review=True)
        desired_query = connect_query('Desired reference fixture')
        run_sql('SELECT pg_sleep(3), current_database() AS target_name;', review=True)
        wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith(a) and native_tab_has_status(native_name(item), 'Running')) and
                     observed_any(lambda item: native_tab_name(native_name(item)).startswith(desired_query) and native_tab_has_status(native_name(item), 'Running')))
        activate_query(a)
        editor_a = wait(lambda: observed_sql_editor())
        focus(editor_a)
        wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith(desired_query) and native_tab_has_status(native_name(item), 'Completed')), 20)
        if not editor_a.get_state_set().contains(Atspi.StateType.FOCUSED) or Atspi.Text.get_text(editor_a, 0, -1) != 'SELECT pg_sleep(20), current_database() AS target_name;':
            raise RuntimeError('Background completion changed the focused document')
        photograph('concurrent-targets-background-completion')
        report['nativeConcurrentDifferentTargetsPreserveFocusVerified'] = True
        wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith(a) and native_tab_has_status(native_name(item), 'Completed')), 20)
        # A schema context opens the actual two-table foreign-key diagram.
        right_menu('public · level 3 · Native accessibility fixture')
        activate('ER diagram')
        wait(lambda: find('Search table', 'EditableText'))
        set_field('Search table', 'native_atspi_child')
        activate('Focus')
        wait(lambda: observed_any(lambda item: 'native_atspi_child' in native_name(item)))
        photograph('schema-er-diagram')
        activate('Export SVG')
        diagram = tour / 'actual-foreign-key-diagram.svg'
        choose_file(diagram)
        wait(diagram.exists)
        import xml.etree.ElementTree as xml
        if diagram.stat().st_size > 65536:
            raise RuntimeError('Owned diagram evidence byte budget')
        tree = xml.fromstring(diagram.read_text())
        names = {item.text for item in tree.findall('{http://www.w3.org/2000/svg}text')}
        if not {'native_atspi_child', 'native_atspi_fixture'} <= names or len(tree.findall('{http://www.w3.org/2000/svg}path')) != 1:
            raise RuntimeError('Actual foreign-key diagram evidence incorrect')
        report['nativeSchemaDiagramActualForeignKeyScopeVerified'] = True
        report['diagramEvidence'] = {'file': str(diagram), 'sha256': hashlib.sha256(diagram.read_bytes()).hexdigest(), 'bytes': diagram.stat().st_size}
        palette('Close tab')
        right_menu('public · level 3 · Native accessibility fixture')
        activate('Compare schemas')
        choose_comparison('Current schema (to be changed)', 'Native accessibility fixture')
        activate('Capture schema · Current schema (to be changed)')
        choose_comparison('Desired schema', 'Desired reference fixture')
        tap_item(reveal('Capture schema · Desired schema'))
        password = wait(lambda: find('Password', 'EditableText'))
        focus(password)
        supply_password(password)
        activate('Connect')
        tap_item(reveal('Compare schemas'))
        wait(lambda: observed_any(lambda item: 'native_atspi_fixture' in native_name(item) and 'Changed' in native_name(item)), 20)
        photograph('schema-comparison-current-desired')
        save_sql = reveal('Save SQL')
        wait(lambda: observed_any(lambda item: 'desired_note' in bounded_native_text(Atspi, item)), 20)
        photograph('migration-review')
        tap_item(save_sql)
        migration = tour / 'reviewed-migration.sql'
        choose_file(migration)
        wait(migration.exists)
        sql = migration.read_text()
        if len(sql.encode('utf-8')) > 65536 or 'desired_note' not in sql or 'ADD' not in sql or 'DROP COLUMN' in sql:
            raise RuntimeError('Saved migration direction/evidence incorrect')
        photograph('migration-sql-saved-without-application')
        report['nativeCurrentDesiredComparisonAndSaveSqlVerified'] = True
        report['migrationSqlEvidence'] = {'file': str(migration), 'sha256': hashlib.sha256(migration.read_bytes()).hexdigest(), 'bytes': migration.stat().st_size}
        # Retained export remains available after the object's console disconnects.
        table, _, _ = wait(lambda: find_query_tab_activation(Atspi, objects(app),
            recovered_table_identity, native_query_identity, native_name, current_nodes=lambda: objects(app)))
        tap_item(table)
        wait(lambda: fixture_cell('漢😀'))
        palette('Disconnect')
        wait(lambda: observed_any(lambda item: native_name(item) == 'Disconnect'))
        activate('Disconnect')
        wait(lambda: fixture_cell('漢😀'))
        palette('Export retained data')
        wait(lambda: find('Choose destination'))
        activate('Choose destination')
        exported = tour / 'retained-after-disconnect.csv'
        choose_file(exported)
        tap_item(reveal('Review transfer'))
        tap_item(reveal('Start export'))
        wait(exported.exists, 30)
        wait(lambda: observed_any(lambda item: native_name(item).startswith('Completed · ')), 30)
        with exported.open(newline='') as stream:
            rows = list(csv.reader(stream))
        if len(rows) != 3 or rows[0] != ['id', 'n'] or sorted(row[0] for row in rows[1:]) != ['1', '2'] or not any(row[1] == '漢😀' for row in rows[1:]):
            raise RuntimeError('Disconnected retained export did not preserve exact source rows')
        photograph('transfer-retained-export-after-disconnect')
        report['nativeRetainedExportAfterDisconnectVerified'] = True
        report['retainedExportEvidence'] = {'file': str(exported), 'sha256': hashlib.sha256(exported.read_bytes()).hexdigest(), 'bytes': exported.stat().st_size}
        # An owned disposable production console loses its own connection during
        # a reviewed operation. Never manufacture or automatically replay a fault.
        production = connect_query('Native production fixture')
        run_sql('DO $$ BEGIN PERFORM pg_terminate_backend(pg_backend_pid()); END $$;', review=True)
        wait(lambda: observed_any(lambda item: native_tab_name(native_name(item)).startswith(production) and 'Production' in native_name(item) and ('Outcome unknown' in native_name(item))), 30)
        photograph('production-outcome-unknown')
        command(['xdotool', 'key', '--clearmodifiers', 'ctrl+shift+p'])
        query = wait(lambda: find('Search', 'EditableText'))
        focus(query)
        Atspi.EditableText.set_text_contents(query, 'Run current statement')
        disabled = wait(lambda: observed_first(lambda item: (True, item) if 'Run current statement' in native_name(item) and 'Outcome unknown' in native_name(item) and (item.get_role() == Atspi.Role.PUSH_BUTTON) else (False, None)))
        report['nativeUncertainCommandDisabledEvidence'] = assert_native_command_disabled(Atspi, disabled)
        command(['xdotool', 'key', '--clearmodifiers', 'Return'])
        wait(lambda: find('Search', 'EditableText'))
        wait(lambda: observed_first(lambda item: (True, item) if 'Run current statement' in native_name(item) and 'Outcome unknown' in native_name(item) and (item.get_role() == Atspi.Role.PUSH_BUTTON) else (False, None)))
        command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
        wait(lambda: observed_missing(lambda proof: find('Search', 'EditableText', current_nodes=proof)))
        activate_query(desired_query)
        wait(lambda: observed_any(lambda item: 'Outcome unknown' in native_name(item)))
        photograph('inactive-unknown-outcome-visible')
        # The healthy active document must not enable deactivation of the
        # separately selected production source with an unknown outcome.
        focus_live_native_control(Atspi, lambda: find_native_tree_row(Atspi,
            objects(app), labels, 'Native production fixture', current_nodes=lambda: objects(app)), wait)
        menu_previous = set(objects(app))
        command(['xdotool', 'key', '--clearmodifiers', 'Menu'])
        fluent = report.get('actualComposition', {}).get('composition') == 'Linux-host Fluent'
        source_deactivation = wait(lambda: find_new_menu_entry(Atspi, objects(app),
            localized('Deactivate source'), menu_previous, fluent=fluent, current_nodes=lambda: objects(app)))
        if source_deactivation.get_state_set().contains(Atspi.StateType.ENABLED):
            raise RuntimeError('Unknown source outcome still admits source deactivation')
        evidence = {'enabled': False, 'role': source_deactivation.get_role_name()}
        if fluent:
            evidence.update(assert_native_command_disabled(Atspi, source_deactivation))
        report['nativeUnknownSourceDeactivationDisabledEvidence'] = evidence
        report['nativeUnknownSourceDeactivationDisabledVerified'] = True
        photograph_product(Atspi, app, objects, wait, command, report,
            'unknown-source-deactivation-disabled', resize=False)
        command(['xdotool', 'key', '--clearmodifiers', 'Escape'])
        activate_query(desired_query)
        palette('Owned sessions')
        wait(lambda: observed_any(lambda item: 'Native production fixture' in native_name(item) and 'Outcome unknown' in native_name(item)))
        photograph('owned-uncertain-session')
        activate('Close')
        report['nativeProductionUnknownOutcomeQuarantineVisibleVerified'] = True
    return [localized(label) for label in ['Row 2, n: second', 'Level 2, ', 'Object / column name', 'native_atspi_fixture']]
