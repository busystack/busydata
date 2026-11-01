#!/usr/bin/env python3
"""Real native acceptance inside an installed strict test package.
Disposable infrastructure is outside the package; every product operation uses
its native Flutter launcher, private TLS RPC and bundled Java/clients.
"""
import hashlib
import json
import os
import re
from pathlib import Path
import selectors
import shutil
import subprocess
import time
import sys
import tempfile
import uuid
from verification_evidence import ROOT, source_hash
from bounded_process_log import BoundedProcessLog


def run(argv, **options):
    return subprocess.run(argv, check=True, **options)


def stop(process):
    if process is None or process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=10)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def installed(command):
    return run(['snap', 'run', '--shell', 'busydata', '-c', command], capture_output=True,
               env=tracking_environment(), text=True, timeout=30).stdout.strip()


def tracking_environment():
    address = os.environ.get('BUSYDATA_ACCEPTANCE_TRACKING_BUS')
    expected = '/run/user/' + str(os.getuid()) + '/bus'
    if address != 'unix:path=' + expected or Path(expected).stat().st_uid != os.getuid():
        raise RuntimeError('A normal systemd user session is required for strict Snap tracking')
    return dict(os.environ, DBUS_SESSION_BUS_ADDRESS=address)


def desktop_command(private_bus):
    # snapd creates its normal scope through the real user bus. Only after
    # confinement is established does the application join our isolated bus.
    # Execute the exact generated product command chain, without test permissions.
    return ['snap', 'run', '--shell', 'busydata', '-c',
            'export DBUS_SESSION_BUS_ADDRESS="$1"; exec "$SNAP/snap/command-chain/gpu-2404-wrapper" '
            '"$SNAP/snap/command-chain/desktop-launch" "$SNAP/busydata"',
            'busydata-owned-desktop', private_bus]


def process_confinement(identifier, executable_suffix):
    process = Path('/proc') / str(identifier)
    if not os.readlink(process / 'exe').endswith(executable_suffix):
        return None
    profile = (process / 'attr/current').read_text().strip()
    if profile != 'snap.busydata.busydata (enforce)':
        raise RuntimeError('Installed application process is not under the enforcing Snap profile')
    return {'pid': identifier, 'appArmorProfile': profile,
            'cgroup': (process / 'cgroup').read_text().strip()}


def validate_desktop_report(report):
    """An aggregate boolean cannot replace every required confined workflow."""
    engines = ('POSTGRESQL', 'MYSQL', 'MARIADB')
    required = {'native-single-instance', 'portal-credentials', 'files-recovery',
                'native-open-picker', 'native-save-picker', 'native-ca-picker',
                'native-key-picker', 'changed-ssh-key-review',
                'backend-lifecycle'}
    per_engine = ('tls-execution', 'transactions-cancellation-editing-paging', 'p0-result-editor',
                  'native-export-picker', 'native-import-picker',
                  'transfers', 'large-streaming-transfer',
                  'ssh-password-key-agent-native-backup', 'retained-after-disconnect')
    required.update(engine + '-' + workflow for engine in engines for workflow in per_engine)
    stages = report.get('stages')
    if (report.get('version') != 1 or report.get('entrypoint') != 'installed_snap_linux.dart'
            or report.get('releaseMode') is not True or report.get('exitCode') != 0
            or report.get('fullInstalledDatabaseFileSecretSshAcceptance') is not True
            or not isinstance(stages, dict) or not required.issubset(stages)
            or any(not isinstance(item, dict) or item.get('passed') is not True
                   for item in stages.values())):
        raise RuntimeError('Required confined native workflows are missing or failed')
    for engine in engines:
        editor = report.get(engine + '-p0ResultEditor', {})
        if (any(editor.get(key) is not True for key in (
                'exactCompleteUnicodeAndBytes', 'aggregateExactScope',
                'cloneStagedWithoutMutation', 'relatedBrowseReviewed', 'sourceRetainedUnchanged'))
                or editor.get('nonBrowseDatabaseJobsSubmitted') != 0
                or editor.get('textUtf8Bytes') != 90000 or editor.get('binaryBytes') != 90000):
            raise RuntimeError('Installed P0 result-editor evidence is incomplete')
        transfer = report.get(engine + '-largeTransfer', {})
        interactive = report.get(engine + '-interactiveAcceptance', {})
        if (transfer.get('rows') != 512 or transfer.get('payloadBytesPerRow') != 65536
                or transfer.get('outputBytes', 0) <= 512 * 65536
                or re.fullmatch(r'[0-9a-f]{64}', transfer.get('outputSha256', '')) is None
                or transfer.get('allDurableValuesVerified') is not True
                or interactive.get('transactionCommitRollback') is not True
                or interactive.get('queuedRunningCancellation') is not True
                or interactive.get('reviewedDurableEdit') is not True
                or interactive.get('verifiedPagedRows') != 300):
            raise RuntimeError('Required confined durable transfer or interactive evidence is incomplete')


def ready_line(process, timeout):
    deadline = time.monotonic() + timeout
    data = bytearray()
    with selectors.DefaultSelector() as selector:
        selector.register(process.stdout, selectors.EVENT_READ)
        while time.monotonic() < deadline:
            if not selector.select(min(1, deadline - time.monotonic())):
                if process.poll() is not None:
                    raise RuntimeError('Disposable fixture exited before readiness')
                continue
            chunk = os.read(process.stdout.fileno(), 1)
            if not chunk:
                raise RuntimeError('Disposable fixture pipe ended')
            if chunk == b'\n':
                return json.loads(data)
            data.extend(chunk)
            if len(data) > 16384:
                raise RuntimeError('Fixture readiness byte limit exceeded')
    raise TimeoutError('Disposable fixture readiness deadline')


def drive_picker(directory, seen):
    request = directory / 'picker-request.json'
    if not request.is_file():
        return
    data = json.loads(request.read_text())
    identity = (data['operation'], data['path'])
    if identity in seen:
        return
    selected = Path(data['path'])
    if (selected.parent != directory or
            (selected.suffix not in ('.sql', '.csv', '.pem') and selected.name != 'selected-key')):
        raise RuntimeError('Native picker requested an unexpected destination')
    # Drive the actual portal/GTK dialog. No mock picker or direct file-return.
    title = r'^(Open|Select).*(File|file)|^Open$' if data['operation'] == 'open' else r'^Save.*'
    found = subprocess.run(['xdotool', 'search', '--onlyvisible', '--name', title],
                           capture_output=True, text=True, timeout=3)
    if found.returncode != 0 or not found.stdout.strip():
        return
    # The primary BusyData window also matches its application class. Wait for
    # the actual chooser title, then focus that exact window on the owned Xvfb.
    window = found.stdout.splitlines()[-1]
    if not window.isdecimal():
        raise RuntimeError('Invalid native chooser window identity')
    run(['xdotool', 'windowfocus', '--sync', window], timeout=3)
    run(['xdotool', 'key', '--clearmodifiers', 'ctrl+l'])
    run(['xdotool', 'key', '--clearmodifiers', 'ctrl+a'])
    paste_gtk_text(str(selected), lambda: picker_has_text(window, str(selected)))
    run(['xdotool', 'key', '--clearmodifiers', 'Return'])
    if data['operation'] == 'save':
        time.sleep(.3)
        run(['xdotool', 'key', '--clearmodifiers', 'Return'])
    seen.add(identity)


def editable_text_matches(item, expected, text_interface):
    # get_interfaces is the public AT-SPI API on both the installed core24
    # facilities and the workstation. The is_text/is_editable_text shortcuts
    # are absent from the core24 introspection bindings.
    interfaces = item.get_interfaces()
    if 'EditableText' not in interfaces or 'Text' not in interfaces:
        return False
    count = text_interface.get_character_count(item)
    return 0 <= count <= 4095 and text_interface.get_text(item, 0, -1) == expected


def picker_objects(window):
    """Traverse only the actual native chooser, never its obscured editor."""
    import gi
    gi.require_version('Atspi', '2.0')
    from gi.repository import Atspi, GLib
    pid = int(run(['xdotool', 'getwindowpid', window], capture_output=True, text=True).stdout.strip())
    title = run(['xdotool', 'getwindowname', window], capture_output=True, text=True).stdout.rstrip('\n')
    desktop = Atspi.get_desktop(0)
    for index in range(desktop.get_child_count()):
        application = desktop.get_child_at_index(index)
        if application.get_process_id() != pid:
            continue
        pending, examined = [(application, False)], 0
        try:
            while pending:
                item, in_picker = pending.pop(0)
                if item is None:
                    continue
                item.clear_cache()
                examined += 1
                count = item.get_child_count()
                if count < 0 or examined + len(pending) + count > 512:
                    raise RuntimeError('Owned native picker accessibility node budget')
                if not in_picker and item.get_role() in (Atspi.Role.FRAME, Atspi.Role.DIALOG, Atspi.Role.FILE_CHOOSER):
                    in_picker = item.get_name() == title
                    if not in_picker:
                        continue
                if in_picker:
                    yield item
                pending.extend((item.get_child_at_index(child), in_picker) for child in range(count))
        except GLib.Error:
            # GTK replaces chooser descendants while changing location.
            return


def picker_has_text(window, expected):
    import gi
    gi.require_version('Atspi', '2.0')
    from gi.repository import Atspi, GLib
    try:
        return any(editable_text_matches(item, expected, Atspi.Text) for item in picker_objects(window))
    except GLib.Error:
        return False


def picker_location_field(window):
    """Find a focused input whose bounds fit the exact native chooser."""
    import gi
    gi.require_version('Atspi', '2.0')
    from gi.repository import Atspi
    frame = None
    for item in picker_objects(window):
        if frame is None:
            frame = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
        states = item.get_state_set()
        if (frame is not None and 'EditableText' in item.get_interfaces() and
                states.contains(Atspi.StateType.FOCUSED) and states.contains(Atspi.StateType.SHOWING)):
            box = Atspi.Component.get_extents(item, Atspi.CoordType.SCREEN)
            if (box.width > 0 and box.height > 0 and box.x >= frame.x and box.y >= frame.y and
                    box.x + box.width <= frame.x + frame.width and box.y + box.height <= frame.y + frame.height):
                return item
    return None


def paste_gtk_text(value, consumed=None):
    encoded = value.encode('utf-8', errors='strict')
    if len(encoded) > 4095 or '\n' in value or '\r' in value or '\0' in value:
        raise RuntimeError('Native picker path byte or control-character limit')
    if consumed is None:
        raise RuntimeError('Native paste requires confirmation from the intended control')
    helper = subprocess.Popen([sys.executable, str(ROOT / 'tool/native_picker_clipboard.py')],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    try:
        helper.stdin.write(encoded + b'\n')
        helper.stdin.flush()
        if ready_line(helper, 5) != {'ready': True}:
            raise RuntimeError('Native fixture clipboard not ready')
        run(['xdotool', 'key', '--clearmodifiers', 'ctrl+v'])
        if ready_line(helper, 5) != {'served': True}:
            raise RuntimeError('GTK picker did not request the UTF-8 fixture selection')
        # AT clients such as Orca also read the clipboard. Its first served
        # request is not proof that the intended widget consumed the paste.
        deadline = time.monotonic() + 5
        while not consumed():
            if time.monotonic() >= deadline:
                raise RuntimeError('Intended native control did not consume exact UTF-8 text')
            time.sleep(.03)
        helper.stdin.close()
        if helper.wait(timeout=5):
            raise RuntimeError('Native fixture clipboard failed')
    finally:
        stop(helper)
        if helper.stdin and not helper.stdin.closed:
            helper.stdin.close()
        helper.stdout.close()



def main():
    destination = ROOT / 'build/installed-snap.json'
    evidence = ROOT / 'build/installed-snap' / str(uuid.uuid4())
    evidence.mkdir(parents=True)
    fixture = agent = desktop = None
    portal_services = []
    logs = []
    portal_directory = None
    report = {'version': 2, 'sourceSha256': source_hash(), 'exitCode': 1,
              'fullInstalledDatabaseFileSecretSshAcceptance': False, 'cleanupConfirmed': False}
    directory = None
    try:
        for executable in ['snap', 'docker', 'ssh-agent', 'ssh-add', 'xdotool']:
            if shutil.which(executable) is None:
                raise RuntimeError('Required installed acceptance facility unavailable: ' + executable)
        # This is a new dbus-run-session/Xvfb session, never the user's keyring or
        # desktop bus. All host portal data and daemon processes are disposable.
        if '--owned-session' not in sys.argv:
            raise RuntimeError('Installed acceptance must run in its owned desktop session')
        portal_directory = Path(tempfile.mkdtemp(prefix='busydata-portal-'))
        os.chmod(portal_directory, 0o700)
        environment = dict(os.environ, XDG_CONFIG_HOME=str(portal_directory / 'config'),
            XDG_DATA_HOME=str(portal_directory / 'data'), XDG_CACHE_HOME=str(portal_directory / 'cache'),
            XDG_RUNTIME_DIR=str(portal_directory / 'runtime'), XDG_CURRENT_DESKTOP='BusyDataAcceptance',
            GDK_BACKEND='x11')
        for name in ['config', 'data', 'cache', 'runtime']:
            (portal_directory / name).mkdir(mode=0o700)
        if not environment.get('DBUS_SESSION_BUS_ADDRESS', '').startswith('unix:abstract=/tmp/dbus-busydata-'):
            raise RuntimeError('Portal activation must use the owned abstract test bus')
        # Only our private daemon receives the owned display/configuration. Do
        # not use --systemd or change the real user's activation environment.
        run(['dbus-update-activation-environment', 'DISPLAY', 'XAUTHORITY',
             'XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_CACHE_HOME', 'XDG_RUNTIME_DIR',
             'XDG_CURRENT_DESKTOP', 'GDK_BACKEND'], env=environment, timeout=10)
        configuration = portal_directory / 'config/xdg-desktop-portal'
        configuration.mkdir()
        (configuration / 'portals.conf').write_text('[preferred]\ndefault=gtk\norg.freedesktop.impl.portal.Secret=gnome-keyring\n')
        keyring = subprocess.Popen(['gnome-keyring-daemon', '--foreground', '--unlock',
            '--components=secrets', '--control-directory=' + str(portal_directory / 'runtime/keyring')],
            env=environment, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        portal_services.append(keyring)
        logs.append(BoundedProcessLog(keyring, evidence / 'keyring.log', 2 * 1024 * 1024))
        keyring.stdin.write(b'disposable-installed-keyring-fixture\n')
        keyring.stdin.close()
        run(['gdbus', 'wait', '--session', '--timeout', '10', 'org.freedesktop.secrets'],
            env=environment, timeout=12)
        document_portal = subprocess.Popen(['/usr/libexec/xdg-document-portal'],
            env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        portal_services.append(document_portal)
        logs.append(BoundedProcessLog(document_portal, evidence / 'document-portal.log', 2 * 1024 * 1024))
        run(['gdbus', 'wait', '--session', '--timeout', '15', 'org.freedesktop.portal.Documents'],
            env=environment, timeout=17)
        for executable in ['/usr/libexec/xdg-desktop-portal-gtk', '/usr/libexec/xdg-desktop-portal']:
            service = subprocess.Popen([executable], env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            portal_services.append(service)
            logs.append(BoundedProcessLog(service, evidence / (Path(executable).name + '.log'), 2 * 1024 * 1024))
            name = 'org.freedesktop.impl.portal.desktop.gtk' if executable.endswith('-gtk') else 'org.freedesktop.portal.Desktop'
            run(['gdbus', 'wait', '--session', '--timeout', '15', name], env=environment, timeout=17)
        # Inspect installed metadata locally: snap info <name> contacts the
        # Store, which must not be a prerequisite for testing an installed app.
        info = installed('cat "$SNAP/meta/snap.yaml"')
        if not any(line.strip() == 'confinement: strict' for line in info.splitlines()):
            raise RuntimeError('Installed package is not strictly confined')
        build = json.loads(installed('cat "$SNAP/installed-acceptance-build.json"'))
        if build['sourceSha256'] != source_hash() or build['entrypoint'] != 'integration_test/installed_snap_linux.dart':
            raise RuntimeError('Install the fresh separate acceptance package, not an old build or the ordinary product entrypoint')
        digest_lines = installed('cd "$SNAP"; sha256sum busydata lib/libapp.so '
            'backend/lib/busydata-backend-0.1.0.jar backend/runtime/bin/java').splitlines()
        installed_hashes = {line.split(None, 1)[1].strip(): line.split(None, 1)[0]
                            for line in digest_lines}
        if installed_hashes != build['artifacts']:
            raise RuntimeError('Installed artifact hashes differ from build evidence')
        report['installedBuild'] = build
        common = Path(installed('printf "%s" "$SNAP_USER_COMMON"'))
        directory = common / ('installed-' + uuid.uuid4().hex[:12])
        directory.mkdir(mode=0o700)
        # These are real reviewed test credentials, never user profiles/secrets.
        classpath = ROOT / 'backend/target/installed-fixture-classpath.txt'
        if not classpath.is_file():
            raise RuntimeError('Compile the external fixture and its test classpath before installed acceptance')
        java_home = os.environ.get('JAVA_HOME')
        java = str(Path(java_home) / 'bin/java') if java_home else shutil.which('java')
        cp = os.pathsep.join([str(ROOT / 'backend/target/test-classes'),
                             str(ROOT / 'backend/target/classes'), classpath.read_text().strip()])
        fixture = subprocess.Popen([java, '--enable-native-access=ALL-UNNAMED', '-cp', cp,
            'io.busystack.busydata.InstalledPackageFixture', str(directory)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        class StderrSource:
            stdout = fixture.stderr
        logs.append(BoundedProcessLog(StderrSource(), evidence / 'fixture-stderr.log'))
        fixture_data = ready_line(fixture, 540)
        report['fixtureImages'] = fixture_data['engines']
        socket = directory / 'agent.sock'
        if len(os.fsencode(socket)) >= 104:
            raise RuntimeError('Isolated selected-agent socket path exceeds the OS limit')
        agent = subprocess.Popen(['ssh-agent', '-D', '-a', str(socket)], stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
        deadline = time.monotonic() + 10
        while not socket.exists() and time.monotonic() < deadline:
            time.sleep(.05)
        environment = dict(os.environ, SSH_AUTH_SOCK=str(socket))
        run(['ssh-add', str(directory / 'selected-key')], env=environment,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        desktop = subprocess.Popen(desktop_command(os.environ['DBUS_SESSION_BUS_ADDRESS']),
            env=tracking_environment(), stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        logs.append(BoundedProcessLog(desktop, evidence / 'desktop.log'))
        desktop.stdin.write((json.dumps(fixture_data) + '\n').encode())
        desktop.stdin.flush()
        seen = set()
        deadline = time.monotonic() + 1200
        confinement_deadline = time.monotonic() + 30
        while desktop.poll() is None and time.monotonic() < deadline:
            if 'desktopConfinement' not in report:
                try:
                    proof = process_confinement(desktop.pid, '/busydata')
                    if proof is not None:
                        report['desktopConfinement'] = proof
                except (FileNotFoundError, PermissionError):
                    # snap-confine is temporarily privileged/non-dumpable. Only
                    # the later ordinary Flutter process can be inspected by its
                    # unprivileged parent. Never weaken procfs or confinement.
                    if time.monotonic() >= confinement_deadline:
                        raise RuntimeError('Strict launcher did not reach an inspectable ordinary application')
                if 'desktopConfinement' not in report and time.monotonic() >= confinement_deadline:
                    raise RuntimeError('Actual confined Flutter startup was not observed within 30 seconds')
            live_report = directory / 'desktop-acceptance.json'
            if live_report.is_file() and 'backendConfinement' not in report:
                if live_report.stat().st_size > 65536:
                    raise RuntimeError('Installed acceptance report byte limit exceeded')
                details = json.loads(live_report.read_text())
                if details.get('backendPid'):
                    proof = process_confinement(details['backendPid'], '/backend/runtime/bin/java')
                    if proof is not None:
                        report['backendConfinement'] = proof
            if (directory / 'rotate-request').exists() and not (directory / 'host-key-rotated').exists():
                fixture.stdin.write(b'rotate-host-key\n')
                fixture.stdin.flush()
                (directory / 'rotate-request').unlink()
            drive_picker(directory, seen)
            time.sleep(.1)
        if desktop.poll() is None:
            raise TimeoutError('Installed native desktop acceptance deadline')
        desktop_report = directory / 'desktop-acceptance.json'
        if not desktop_report.is_file():
            raise RuntimeError('Installed native desktop did not produce evidence')
        if 'desktopConfinement' not in report or 'backendConfinement' not in report:
            raise RuntimeError('Actual Flutter and backend confinement was not observed')
        shutil.copy2(desktop_report, evidence / desktop_report.name)
        report['desktop'] = json.loads(desktop_report.read_text())
        with desktop_report.open('rb') as stream:
            report['desktopSha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
        if desktop.returncode:
            raise RuntimeError('At least one required confined native workflow failed; inspect individual stages')
        validate_desktop_report(report['desktop'])
        # A separate owned launch establishes pinned/authenticated RPC, then its
        # exact frontend is terminated without asking Java to shut down. Observe
        # the specific owned child disappearing; never kill by executable name.
        desktop = subprocess.Popen(desktop_command(os.environ['DBUS_SESSION_BUS_ADDRESS']),
            env=tracking_environment(), stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        logs.append(BoundedProcessLog(desktop, evidence / 'forced-parent-desktop.log'))
        desktop.stdin.write((json.dumps(dict(fixture_data, forceTerminationProbe=True)) + '\n').encode())
        desktop.stdin.flush()
        forced_ready = directory / 'force-parent-ready.json'
        deadline = time.monotonic() + 45
        while not forced_ready.is_file():
            if desktop.poll() is not None or time.monotonic() >= deadline:
                raise RuntimeError('Confined parent-death probe did not reach authenticated RPC')
            time.sleep(.05)
        if forced_ready.stat().st_size > 16384:
            raise RuntimeError('Confined parent-death bootstrap report byte limit')
        forced = json.loads(forced_ready.read_text())
        if (forced.get('version') != 1 or forced.get('releaseMode') is not True
                or forced.get('flutterPid') != desktop.pid
                or not isinstance(forced.get('backendPid'), int) or forced['backendPid'] <= 0):
            raise RuntimeError('Confined parent-death process identities do not match')
        forced_frontend = process_confinement(desktop.pid, '/busydata')
        forced_backend = process_confinement(forced['backendPid'], '/backend/runtime/bin/java')
        if forced_frontend is None or forced_backend is None:
            raise RuntimeError('Parent-death probe did not use the real confined frontend/backend')
        desktop.kill()
        desktop.wait(timeout=10)
        deadline = time.monotonic() + 30
        while Path('/proc', str(forced['backendPid'])).exists():
            if time.monotonic() >= deadline:
                raise RuntimeError('Specific confined backend remained alive after frontend termination')
            time.sleep(.05)
        report['forcedParentTermination'] = {
            'passed': True, 'frontend': forced_frontend, 'backend': forced_backend,
            'backendInstance': forced['backendInstance'],
            'javaRuntime': forced['javaRuntime'], 'frontendExitCode': desktop.returncode,
        }
        desktop.stdin.close()
        if source_hash() != report['sourceSha256']:
            raise RuntimeError('Source changed during installed acceptance')
        report['exitCode'] = 0
        report['fullInstalledDatabaseFileSecretSshAcceptance'] = True
    except Exception as failure:
        report['failureType'] = type(failure).__name__
        # Controlled orchestration errors carry no SQL/database diagnostic payload.
        report['failure'] = str(failure) if isinstance(failure, (RuntimeError, TimeoutError)) else type(failure).__name__
        raise
    finally:
        try:
            stop(desktop)
            stop(agent)
            for service in reversed(portal_services):
                stop(service)
            if portal_directory is not None:
                shutil.rmtree(portal_directory)
            if fixture is not None and fixture.poll() is None:
                fixture.stdin.close()
                fixture.wait(timeout=30)
            if fixture is not None and fixture.returncode:
                raise RuntimeError('External fixture cleanup failed')
            report['cleanupConfirmed'] = True
        except Exception as cleanup:
            stop(fixture)
            report['cleanupFailureType'] = type(cleanup).__name__
            report['exitCode'] = 1
            report['fullInstalledDatabaseFileSecretSshAcceptance'] = False
        if directory is not None:
            # Remove only the UUID-owned disposable fixture; no user documents.
            try:
                shutil.rmtree(directory)
            except OSError as cleanup:
                report['cleanupFailureType'] = type(cleanup).__name__
                report['exitCode'] = 1
                report['fullInstalledDatabaseFileSecretSshAcceptance'] = False
        report['logs'] = [item.finish() for item in logs]
        if any(not item['complete'] for item in report['logs']):
            report['logAdmissionFailed'] = True
            report['exitCode'] = 1
            report['fullInstalledDatabaseFileSecretSshAcceptance'] = False
        (evidence / 'run-status.json').write_text(json.dumps(report, indent=2) + '\n')
        destination.write_text(json.dumps(report, indent=2) + '\n')
        print(destination)
    if report['exitCode']:
        raise RuntimeError('Installed acceptance or cleanup did not pass')


if __name__ == '__main__':
    if '--owned-session' in sys.argv:
        main()
    else:
        # Strip inherited desktop-bus identity. dbus-run-session owns this new bus;
        # no user's keyring, DISPLAY, settings, activation environment or daemons
        # are modified by the acceptance fixtures.
        environment = dict(os.environ, BUSYDATA_ACCEPTANCE_TRACKING_BUS='unix:path=/run/user/' + str(os.getuid()) + '/bus')
        environment.pop('DBUS_SESSION_BUS_ADDRESS', None)
        # A pathname under /tmp is hidden by Snap's private /tmp mount. Use an
        # owned abstract session socket, preserving ordinary EXTERNAL auth and
        # the standard session policy. The product's real bus is never changed.
        with tempfile.TemporaryDirectory(prefix='busydata-owned-bus-') as directory:
            daemon = Path(directory) / 'dbus-daemon'
            daemon.write_text('#!/bin/sh\nexec /usr/bin/dbus-daemon --address=unix:abstract=/tmp/dbus-busydata-' + uuid.uuid4().hex + ' "$@"\n')
            daemon.chmod(0o700)
            raise SystemExit(subprocess.run(['dbus-run-session', '--dbus-daemon=' + str(daemon), '--', 'xvfb-run', '-a',
                sys.executable, str(Path(__file__).resolve()), '--owned-session'],
                env=environment).returncode)
