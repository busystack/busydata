#!/usr/bin/env python3
"""Build/run the actual native release acceptance executable on disposable data."""
import hashlib
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid
from backend_build_identity import verify_bundle, verify_jar
from verification_evidence import command_output, source_hash

ROOT = Path(__file__).resolve().parents[1]


def run(argv, **options):
    return subprocess.run(argv, cwd=ROOT, check=True, **options)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-pub', action='store_true',
                        help='Use dependencies already verified by a separate locked pub get')
    options = parser.parse_args()
    verify_bundle()
    directory = ROOT / 'build/release-performance' / str(uuid.uuid4())
    directory.mkdir(parents=True)
    fixture = None
    status = {"stage": "release-desktop", "sourceSha256": source_hash(), "exitCode": None, "cleanupConfirmed": False}
    output = directory / 'performance.json'
    try:
        build_command = ['flutter', 'build', 'linux', '--release', '-t',
                         'integration_test/performance_release_linux.dart']
        if options.no_pub:
            build_command.append('--no-pub')
        run(build_command)
        bundle = directory / 'bundle'
        shutil.copytree(ROOT / 'build/linux/x64/release/bundle', bundle)
        verify_jar(bundle / 'backend/lib/busydata-backend-0.1.0.jar')
        executable = bundle / 'busydata'
        with executable.open('rb') as source:
            digest = hashlib.file_digest(source, 'sha256').hexdigest()
        artifact_hashes = {}
        for name in ['busydata', 'lib/libapp.so', 'backend/lib/busydata-backend-0.1.0.jar',
                     'backend/runtime/bin/java', 'backend/dependency-inventory.json']:
            with (bundle / name).open('rb') as artifact:
                artifact_hashes[name] = hashlib.file_digest(artifact, 'sha256').hexdigest()
        inputs = {'version': 2, 'buildSourceSha256': source_hash(), 'executableSha256': digest,
                  'buildCommand': build_command,
                  'artifactHashes': artifact_hashes,
                  'flutter': command_output(['flutter', '--version', '--machine']),
                  'runtimeCheck': json.loads((bundle / 'backend/runtime-check.json').read_text()),
                  'fixtureImage': command_output(['docker', 'image', 'inspect',
                                                  'postgres:17.11', '--format', '{{json .RepoDigests}}']),
                  'display': 'Xvfb 1280x800x24; forced X11; private D-Bus; actual native Handy/Flutter composition',
                  'sampler': '/proc/<Flutter and owned Java PID>/status every >=50ms; private Java aggregates every fourth sample'}
        path = directory / 'inputs.json'
        path.write_text(json.dumps(inputs, indent=2) + '\n')
        fixture = run(['docker', 'run', '--rm', '-d', '-e',
                       'POSTGRES_PASSWORD=busydata-ui-fixture', '-p',
                       '127.0.0.1::5432', 'postgres:17.11'], capture_output=True,
                      text=True).stdout.strip()
        for _ in range(60):
            ready = subprocess.run(['docker', 'exec', fixture, 'pg_isready', '-U',
                                     'postgres'], stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL)
            if ready.returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('Disposable database readiness failed')
        port = run(['docker', 'port', fixture, '5432/tcp'], capture_output=True,
                   text=True).stdout.strip().rsplit(':', 1)[1]
        environment = dict(os.environ, BUSYDATA_TEST_PORT=port,
                           XDG_DATA_HOME=str(directory / 'support'),
                           BUSYDATA_PERFORMANCE_INPUTS=str(path),
                           BUSYDATA_PERFORMANCE_OUTPUT=str(output),
                           GDK_BACKEND='x11', XDG_SESSION_TYPE='x11')
        # xvfb-run supplies its own display and authority. A user service can
        # inherit a live Wayland desktop even when its caller has none.
        environment.pop('WAYLAND_DISPLAY', None)
        environment.pop('DISPLAY', None)
        run(['xvfb-run', '-a', '-s', '-screen 0 1280x800x24',
             'dbus-run-session', '--', str(executable)],
            env=environment, timeout=1200)
        report = json.loads(output.read_text())
        if not report.get('releaseModeMeasured') or report.get('exitCode') != 0:
            raise RuntimeError('Release acceptance did not pass')
        if source_hash() != inputs['buildSourceSha256']:
            raise RuntimeError('Build inputs changed during release acceptance')
        status['exitCode'] = 0
        print(output)
    except BaseException as failure:
        status['exitCode'] = failure.returncode if isinstance(failure, subprocess.CalledProcessError) else 1
        status['failure'] = type(failure).__name__
        raise
    finally:
        if output.is_file():
            shutil.copy2(output, ROOT / 'build/performance-linux-release.json')
        try:
            if fixture:
                run(['docker', 'stop', fixture], stdout=subprocess.DEVNULL)
            status['cleanupConfirmed'] = True
        except Exception as cleanup:
            status['cleanupFailure'] = type(cleanup).__name__
            if status['exitCode'] == 0: status['exitCode'] = 1
            raise
        finally:
            if output.is_file():
                with output.open('rb') as source:
                    status['performanceSha256'] = hashlib.file_digest(source, 'sha256').hexdigest()
            (directory / 'run-status.json').write_text(json.dumps(status, indent=2) + '\n')


if __name__ == '__main__':
    main()
