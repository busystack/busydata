#!/usr/bin/env python3
"""Run explicit verification scopes with immutable logs, reports and source identity."""
import argparse
from contextlib import contextmanager
import os
from pathlib import Path
import shutil
import sys
from verification_evidence import ROOT, start, run, unavailable
from package_verification_evidence import finish_with_archive
from verify_official_dependencies import owned_build_environment


@contextmanager
def official_pub_cache():
    """Keep package resolution in this source owner's rebuildable cache."""
    environment = owned_build_environment(ROOT)
    owned = {key: environment[key] for key in ('PUB_CACHE', 'TMPDIR')}
    previous = {key: os.environ.get(key) for key in owned}
    os.environ.update(owned)
    try:
        yield
    finally:
        for key, value in previous.items():
            if value is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = value


@contextmanager
def gallery_capture(directory):
    """Give aggregate Linux tests a fresh evidence owner, then restore the caller."""
    variable = 'BUSYDATA_SCREEN_GALLERY_OUTPUT'
    previous = os.environ.get(variable)
    os.environ[variable] = str(directory)
    try:
        yield
    finally:
        if previous is None:
            os.environ.pop(variable, None)
        else:
            os.environ[variable] = previous


def main():
    with official_pub_cache():
        return run_pipeline()


def run_pipeline():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scope', choices=('database', 'linux', 'desktop-full'), default='desktop-full')
    parser.add_argument('--offline-flutter', action='store_true',
                        help='Verify the existing locked Flutter cache without network resolution')
    parser.add_argument('--unavailable-installed-snap', metavar='REASON',
                        help='Record required installed Snap acceptance as unavailable without invoking it; full acceptance remains failed')
    parser.add_argument('--installed-snap-vm', metavar='OWNED_VM',
                        help='Build and test fresh strict packages in the explicitly selected disposable LXD VM')
    parser.add_argument('--windows-native-unavailable-reason', default='This Linux scope has no approved genuine Windows runner; run tool/windows/build_release.ps1 on the native runner')
    parser.add_argument('--msix-unavailable-reason', default='Native Windows install acceptance and genuine approved development/test identity, artwork and signing inputs are required')
    args = parser.parse_args()
    run_identifier = start()
    required = []
    failures = []

    def stage(name, command, reports=(), artifacts=(), needs=()):
        required.append(name)
        if any(item in failures for item in needs):
            unavailable(name, 'Not run because a required upstream product check failed: ' + ', '.join(needs))
            failures.append(name)
            return False
        print('Running ' + name, flush=True)
        status = run(name, command, reports, artifacts)
        if status:
            failures.append(name)
        return status == 0

    python = sys.executable
    maven = [str(ROOT / 'backend/mvnw'), '-f', 'backend/pom.xml']
    if os.environ.get('BUSYDATA_MAVEN_REPOSITORY'):
        maven.append('-Dmaven.repo.local=' + os.environ['BUSYDATA_MAVEN_REPOSITORY'])
    stage('configuration', [python, 'tool/check_toolchain.py'])
    stage('evidence-tests', [python, '-m', 'unittest', 'discover', '-s', 'tool', '-p', 'test_*.py'])
    if args.scope != 'database':
        flutter = Path(shutil.which('flutter') or 'flutter').resolve()
        dart = flutter.parent / 'cache/dart-sdk/bin/dart'
        stage('toolchain', [str(dart), 'tool/verify_flutter_sdk.dart', '--flutter', str(flutter), '--dart', str(dart), '--toolchain', 'config/toolchain.json'])
        dependency_command = ['flutter', 'pub', 'get', '--enforce-lockfile']
        if args.offline_flutter:
            dependency_command.append('--offline')
        stage('flutter-dependencies', dependency_command, needs=('toolchain',))
        stage('official-dependencies', [python, 'tool/verify_official_dependencies.py'],
              artifacts=('build/official-dependencies/verification.json',), needs=('flutter-dependencies',))
        stage('localizations', ['flutter', 'gen-l10n'], needs=('flutter-dependencies', 'official-dependencies'))
    stage('java', maven + ['verify'], ('backend/target/surefire-reports',), ('backend/target/bom.json',))
    if args.scope != 'database':
        stage('protocol', [python, 'tool/generate_protocol.py'], needs=('java', 'flutter-dependencies', 'official-dependencies'))
        stage('format', ['dart', 'format', '--output=none', '--set-exit-if-changed', 'lib', 'test', 'tool', 'integration_test'], needs=('official-dependencies',))
        stage('analyze', ['flutter', 'analyze'], needs=('official-dependencies',))
        stage('boundaries', ['dart', 'run', 'tool/check_platform_boundaries.dart'], needs=('official-dependencies',))
        if sys.platform == 'linux':
            gallery = ROOT / 'build/verification/runs' / str(run_identifier) / 'screen-gallery'
            captions = tuple((gallery / theme / 'captions.json').relative_to(ROOT).as_posix()
                             for theme in ('dark', 'light'))
            with gallery_capture(gallery):
                stage('flutter-tests', ['flutter', 'test', '--machine', '--no-pub'],
                      artifacts=captions, needs=('flutter-dependencies', 'official-dependencies'))
        else:
            stage('flutter-tests', ['flutter', 'test', '--machine', '--no-pub'], needs=('flutter-dependencies', 'official-dependencies'))
        if sys.platform == 'linux':
            component = ROOT / 'build/verification/runs' / str(run_identifier) / 'native-accessibility-component/component'
            stage('native-accessibility-component',
                  [python, 'tool/verify_native_accessibility_component.py', '--output', str(component)],
                  artifacts=((component / 'report.json').relative_to(ROOT).as_posix(),),
                  needs=('toolchain', 'official-dependencies'))
    if args.scope != 'linux':
        stage('native-test-tools', [python, 'tool/prepare_native_test_tools.py'], artifacts=('backend/target/native-tools/fixture-tools.json',))
        stage('native-configure', ['cmake', '-S', 'backend/native', '-B', 'backend/target/native-build', '-DCMAKE_BUILD_TYPE=Release'])
        stage('native-build', ['cmake', '--build', 'backend/target/native-build'], needs=('native-configure',))
        stage('native-transport', ['ctest', '--test-dir', 'backend/target/native-build', '--output-on-failure'], needs=('native-build',))
        stage('database-matrix', maven + ['verify', '-Pdatabase-it'], ('backend/target/surefire-reports', 'backend/target/failsafe-reports'),
              ('backend/target/large-transfer-postgresql.json', 'backend/target/large-transfer-mysql.json', 'backend/target/large-transfer-mariadb.json'), needs=('native-test-tools', 'native-transport'))
    if args.scope != 'linux':
        stage('large-transfers', [python, 'tool/verify_database_coverage.py', 'large-transfers'], artifacts=('build/large-transfers-coverage.json',), needs=('database-matrix',))
        stage('native-backup', [python, 'tool/verify_database_coverage.py', 'native-backup'], artifacts=('build/native-backup-coverage.json',), needs=('database-matrix',))
    if args.scope != 'database':
        stage('runtime', [python, 'tool/bundle_backend.py'], artifacts=('backend/target/bundle/runtime-check.json',), needs=('java',))
        stage('sources', [python, 'tool/prepare_sources.py'], needs=('runtime',))
        stage('inventory', [python, 'tool/dependency_inventory.py'], needs=('sources', 'official-dependencies'))
        stage('lifecycle', ['dart', '--define=BUSYDATA_BACKEND_DIR=' + str(ROOT / 'backend/target/bundle'), 'run', 'tool/verify_backend_lifecycle.dart'], needs=('runtime', 'official-dependencies'))
        native_flutter = ['env', '-u', 'WAYLAND_DISPLAY', 'GDK_BACKEND=x11',
                          'XDG_SESSION_TYPE=x11', 'xvfb-run', '-a',
                          'dbus-run-session', '--', 'flutter', 'test', '--no-pub']
        stage('gtk-icons', native_flutter + ['integration_test/gtk_header_icons_integration_test.dart', '-d', 'linux'], needs=('runtime', 'flutter-dependencies', 'official-dependencies'))
        stage('linux-close', native_flutter + ['integration_test/linux_window_close_acceptance_test.dart', '-d', 'linux'], needs=('runtime', 'flutter-dependencies', 'official-dependencies'))
        stage('database-desktop', ['bash', 'tool/verify_database_ui.sh'], artifacts=('build/performance-linux-ui.json',), needs=('runtime', 'flutter-dependencies', 'official-dependencies'))
        stage('release-performance', [python, 'tool/verify_release_performance.py', '--no-pub'], artifacts=('build/performance-linux-release.json',), needs=('runtime', 'flutter-dependencies', 'official-dependencies'))
        # The acceptance executable has its own isolated bundle; leave the product entrypoint installed last.
        stage('linux-release', [python, 'tool/build_linux_release.py', '--no-pub'], artifacts=('build/linux-release-build.json',), needs=('runtime', 'inventory', 'flutter-dependencies', 'official-dependencies'))
        stage('native-accessibility', ['/usr/bin/python3', 'tool/verify_native_accessibility.py'], artifacts=('build/native-accessibility-linux.json',), needs=('linux-release',))
        for engine in ('MYSQL', 'MARIADB'):
            stage('native-workflow-' + engine.lower(), ['/usr/bin/python3', 'tool/verify_native_accessibility.py', '--engine', engine],
                  artifacts=('build/native-accessibility-' + engine.lower() + '.json',), needs=('linux-release',))
        stage('native-workflow-mysql-ordinary', ['/usr/bin/python3', 'tool/verify_native_accessibility.py', '--engine', 'MYSQL', '--ordinary-mysql'],
              artifacts=('build/native-accessibility-mysql-ordinary.json',), needs=('linux-release',))
    if args.scope == 'desktop-full':
        required.extend(('windows-native', 'msix'))
        if args.unavailable_installed_snap:
            required.append('installed-snap')
            unavailable('installed-snap', args.unavailable_installed_snap)
        elif args.installed_snap_vm:
            stage('installed-snap', [python, 'tool/verify_installed_snap_vm.py', '--vm', args.installed_snap_vm], artifacts=('build/installed-snap.json',), needs=('linux-release', 'runtime', 'inventory'))
        elif shutil.which('snap') and Path('/snap/busydata/current').exists():
            stage('installed-snap', [python, 'tool/verify_installed_snap.py'], artifacts=('build/installed-snap.json',), needs=('linux-release', 'runtime', 'inventory'))
        else:
            required.append('installed-snap')
            unavailable('installed-snap', 'No installed BusyData Snap for confined database/file/key/agent/tool acceptance')
        unavailable('windows-native', args.windows_native_unavailable_reason)
        unavailable('msix', args.msix_unavailable_reason)
    record = finish_with_archive(required)
    print(ROOT / 'build/verification-evidence.json', flush=True)
    return 0 if record['acceptancePassed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
