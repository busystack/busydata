#!/usr/bin/env python3
"""Exercise owned GTK/ATK bridge components; this is not native acceptance."""
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import tempfile
import time
import uuid

from bounded_process_log import BoundedProcessLog

ROOT = Path(__file__).resolve().parents[1]


def component_test_counts(text, expected):
    plans = re.findall(r'^1\.\.([0-9]+)$', text, re.MULTILINE)
    observed = re.findall(r'^ok ([0-9]+) (/\S+)(?:\s+(#.*))?$', text, re.MULTILINE)
    failed = len(re.findall(r'^not ok\b', text, re.MULTILINE))
    skipped = sum(bool(re.search(r'#\s*(?:SKIP|TODO)\b', note, re.IGNORECASE))
                  for _, _, note in observed)
    complete = (bool(expected) and len(plans) == 1 and int(plans[0]) == len(expected) and
                [int(index) for index, _, _ in observed] == list(range(1, len(expected) + 1)) and
                len(set(expected)) == len(expected) and
                {name for _, name, _ in observed} == set(expected) and
                not failed and not skipped and not re.search(r'^Bail out!', text, re.MULTILINE))
    return {'total': len(expected), 'passed': len(observed) - skipped,
            'failed': failed, 'skipped': skipped,
            'unrun': max(0, len(expected) - len(observed) - failed),
            'complete': complete}


def checksum(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def run(command, output, *, timeout, environment):
    def disable_core_dumps():
        import resource
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

    process = subprocess.Popen(command, cwd=ROOT, env=environment,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               start_new_session=True,
                               preexec_fn=disable_core_dumps)
    log = BoundedProcessLog(process, output, 2 * 1024 * 1024)
    timed_out = False
    try:
        try:
            status = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            os.killpg(process.pid, signal.SIGTERM)
            try:
                status = process.wait(3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                status = process.wait(3)
    finally:
        record = log.finish()
    return {'command': command, 'exitCode': status, 'timedOut': timed_out,
            'log': record, 'passed': status == 0 and not timed_out and record['complete']}


def verify(flutter_root, directory):
    if not directory.is_relative_to(ROOT / 'build'):
        raise ValueError('Component evidence must remain in ignored build output')
    directory.mkdir(parents=True, exist_ok=False)
    engine = flutter_root / 'bin/cache/artifacts/engine/linux-x64'
    inputs = [ROOT / 'linux/runner/tests/accessibility_bridge_test.cc',
              ROOT / 'linux/runner/busydata_accessibility_bridge.cc',
              ROOT / 'linux/runner/busydata_accessibility_bridge.h',
              ROOT / 'linux/runner/busydata_window_close.cc',
              ROOT / 'linux/runner/busydata_window_close.h',
              ROOT / 'tool/verify_native_accessibility_component.py',
              ROOT / 'tool/bounded_process_log.py',
              engine / 'libflutter_linux_gtk.so']
    inputs.extend(sorted((engine / 'flutter_linux').glob('*.h')))
    if len(inputs) < 7 or any(not path.is_file() for path in inputs):
        raise RuntimeError('Pinned official Linux Flutter headers/runtime are required')
    before = {str(path): checksum(path) for path in inputs}
    report = {'version': 1, 'scope': 'owned-gtk-atk-component',
              'nativeAcceptance': False, 'passed': False, 'sourceBefore': before,
              'commands': [], 'startedUnixSeconds': time.time()}
    output = directory / 'report.json'
    environment = dict(os.environ, TMPDIR=str(ROOT / 'build/t'))
    Path(environment['TMPDIR']).mkdir(exist_ok=True)
    runtime = Path(tempfile.mkdtemp(prefix='bdac-', dir=environment['TMPDIR']))
    runtime.chmod(0o700)
    environment.update(XDG_RUNTIME_DIR=str(runtime), GSETTINGS_BACKEND='memory',
                       GIO_USE_VFS='local')
    for key, name in (('XDG_CONFIG_HOME', 'config'), ('XDG_DATA_HOME', 'data'),
                      ('XDG_CACHE_HOME', 'cache')):
        target = directory / name
        target.mkdir(mode=0o700)
        environment[key] = str(target)
    try:
        compiler = shutil.which('c++')
        if (not compiler or not shutil.which('pkg-config') or
                not shutil.which('xvfb-run') or not shutil.which('dbus-run-session')):
            raise RuntimeError('C++, GTK development tools, Xvfb and private D-Bus are required; no passing skip')
        discovery = run(['pkg-config', '--cflags', '--libs', 'gtk+-3.0', 'gmodule-2.0'],
                        directory / 'pkg-config.log', timeout=15, environment=environment)
        report['commands'].append(discovery)
        if not discovery['passed']:
            raise RuntimeError('Official GTK development dependency discovery failed')
        flags = shlex.split((directory / 'pkg-config.log').read_text())
        binary = directory / 'accessibility-bridge-test'
        command = [compiler, '-std=c++14', '-Wall', '-Werror',
                   '-I' + str(engine), str(inputs[0]), '-L' + str(engine),
                   '-Wl,-rpath,' + str(engine), '-lflutter_linux_gtk', *flags,
                   '-o', str(binary)]
        compiled = run(command, directory / 'compile.log', timeout=120, environment=environment)
        report['commands'].append(compiled)
        if not compiled['passed']:
            raise RuntimeError('Owned accessibility component compilation failed')
        report['binarySha256'] = checksum(binary)
        tested = run(['xvfb-run', '-a', '-s', '-screen 0 1280x800x24 -noreset',
                      'dbus-run-session', '--', str(binary), '--verbose'], directory / 'tests.log',
                     timeout=60, environment=environment)
        report['commands'].append(tested)
        expected = re.findall(r'g_test_add_func\("([^\"]+)"', inputs[0].read_text())
        report['testCounts'] = component_test_counts((directory / 'tests.log').read_text(), expected)
        if not tested['passed'] or not report['testCounts']['complete']:
            raise RuntimeError('Owned accessibility component assertions failed')
        report['passed'] = True
    finally:
        try:
            shutil.rmtree(runtime)
            report['privateRuntimeRemoved'] = True
        except OSError as failure:
            report['privateRuntimeRemoved'] = False
            report['cleanupFailureType'] = type(failure).__name__
        report['sourceAfter'] = {str(path): checksum(path) for path in inputs}
        report['componentUnchanged'] = report['sourceBefore'] == report['sourceAfter']
        report['passed'] = (report['passed'] and report['componentUnchanged'] and
                            report['privateRuntimeRemoved'])
        output.write_text(json.dumps(report, indent=2) + '\n')
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter-root', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    flutter = shutil.which('flutter')
    if args.flutter_root is None and flutter is None:
        parser.error('The approved Flutter SDK is required')
    flutter_root = (args.flutter_root or Path(flutter).resolve().parents[1]).resolve()
    directory = (args.output or ROOT / 'build/native-accessibility-component' / str(uuid.uuid4())).resolve()
    report = verify(flutter_root, directory)
    print(json.dumps({'passed': report['passed'], 'nativeAcceptance': False,
                      'report': str(directory / 'report.json')}))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
