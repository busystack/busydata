#!/usr/bin/env python3
"""Collect isolated, current-run verification evidence without certifying skips."""
import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import platform
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET
from bounded_process_log import BoundedProcessLog

from canonical_source import (SOURCE_INPUTS, GENERATED_PARTS, source_manifest,
                              manifest_hash, json_bytes, write_archive,
                              load_manifest, verify_archive)

ROOT = Path(__file__).resolve().parents[1]
BUILD_INPUTS = SOURCE_INPUTS
REPORT_DIRECTORIES = {'backend/target/surefire-reports', 'backend/target/failsafe-reports'}
NATIVE_APPLICATION_STAGES = {'native-accessibility', 'native-workflow-mysql', 'native-workflow-mariadb', 'native-workflow-mysql-ordinary'}


def validate_native_application_artifact(stage, artifact, source, root):
    if stage not in NATIVE_APPLICATION_STAGES:
        return
    if artifact.stat().st_size > 1024 * 1024:
        raise ValueError('Native application receipt exceeds its byte budget')
    from application_exception_log import validate_tree
    validate_tree(json.loads(artifact.read_text()), source, root=root)


def utc():
    return dt.datetime.now(dt.timezone.utc).isoformat()


def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def source_hash(root=ROOT):
    return manifest_hash(source_manifest(root))


def validate_source_snapshot(manifest, root=ROOT):
    """Reproduce the frozen distributable snapshot without relying on Git metadata."""
    snapshot = manifest.get('sourceSnapshot')
    if not snapshot:
        raise ValueError('Canonical source snapshot is missing')
    run = root / 'build/verification/runs' / manifest['runId']
    paths = {}
    for key in ('manifest', 'archive'):
        item = snapshot[key]
        path = root / item['file']
        if (path.is_symlink() or not path.is_file() or path.absolute() != path.resolve()
                or not path.resolve().is_relative_to(run.resolve())):
            raise ValueError('Canonical source artifact must remain inside its owned run')
        if path.stat().st_size != item['bytes'] or digest(path) != item['sha256']:
            raise ValueError('Canonical source artifact size or hash changed')
        paths[key] = path
    canonical = load_manifest(paths['manifest'])
    if (manifest_hash(canonical) != manifest['buildSourceSha256']
            or snapshot['manifest']['sha256'] != manifest['buildSourceSha256']):
        raise ValueError('Canonical source manifest belongs to another snapshot')
    return verify_archive(paths['archive'], canonical)


def command_output(argv, root=ROOT):
    try:
        reply = subprocess.run(argv, cwd=root, capture_output=True, text=True, timeout=30)
        return {'command': argv, 'exitCode': reply.returncode, 'stdout': reply.stdout,
                'stderr': reply.stderr}
    except (OSError, subprocess.TimeoutExpired) as error:
        return {'command': argv, 'exitCode': None, 'unavailable': type(error).__name__}


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, indent=2) + '\n')
    temporary.replace(path)


def start(root=ROOT):
    identifier = str(uuid.uuid4())
    destination = root / 'build/verification/runs' / identifier
    destination.mkdir(parents=True)
    java = str(Path(os.environ['JAVA_HOME']) / 'bin/java') if 'JAVA_HOME' in os.environ else 'java'
    canonical = source_manifest(root)
    canonical_path = destination / 'canonical-source-manifest.json'
    canonical_path.write_bytes(json_bytes(canonical))
    archive_path = destination / 'busydata-source.zip'
    verification = write_archive(root, archive_path, canonical)
    manifest = {
        'schemaVersion': 3, 'runId': identifier, 'startedUtc': utc(),
        'buildSourceSha256': manifest_hash(canonical),
        'sourceSnapshot': {
            'policy': canonical['policy'], 'extractionVerification': verification,
            'manifest': {'file': canonical_path.relative_to(root).as_posix(),
                         'sha256': digest(canonical_path), 'bytes': canonical_path.stat().st_size},
            'archive': {'file': archive_path.relative_to(root).as_posix(),
                        'sha256': digest(archive_path), 'bytes': archive_path.stat().st_size},
        },
        'sourceRevision': command_output(['git', 'rev-parse', 'HEAD'], root),
        'workingTree': command_output(['git', 'status', '--short'], root),
        'busymaxRevision': command_output(['git', '-C', str(root.parent / 'busymax'), 'rev-parse', 'HEAD'], root),
        'busymaxState': command_output(['git', '-C', str(root.parent / 'busymax'), 'status', '--short'], root),
        'host': {'platform': platform.platform(), 'machine': platform.machine(), 'processors': os.cpu_count()},
        'toolOutputs': {
            'dart': command_output(['dart', '--version'], root),
            'flutter': command_output(['flutter', '--version', '--machine'], root),
            'java': command_output([java, '-version'], root),
            'maven': command_output([str(root / 'backend/mvnw'), '-f', str(root / 'backend/pom.xml'), '-v'], root),
            'python': command_output([sys.executable, '--version'], root),
            'docker': command_output(['docker', 'version', '--format', '{{.Client.Version}} / {{.Server.Version}}'], root),
        },
        'stages': {},
    }
    if source_hash(root) != manifest['buildSourceSha256']:
        raise ValueError('Source changed while establishing the frozen run')
    atomic_json(destination / 'manifest.json', manifest)
    atomic_json(root / 'build/verification/current-run.json', {'runId': identifier})
    return identifier


def manifest_path(root=ROOT):
    identifier = json.loads((root / 'build/verification/current-run.json').read_text())['runId']
    uuid.UUID(identifier)
    return root / 'build/verification/runs' / identifier / 'manifest.json'


def xml_reports(directory):
    entries = []
    for path in sorted(directory.rglob('TEST-*.xml')):
        suite = ET.parse(path).getroot()
        entries.append({'file': str(path.name), 'sha256': digest(path),
                        'name': suite.attrib.get('name'),
                        **{key: int(suite.attrib.get(key, 0))
                           for key in ('tests', 'failures', 'errors', 'skipped')}})
    return entries


def run(stage, argv, reports=(), artifacts=(), root=ROOT):
    if not argv or not stage.replace('-', '').replace('_', '').isalnum():
        raise ValueError('A named stage and command argument vector are required')
    path = manifest_path(root)
    manifest = json.loads(path.read_text())
    if stage in manifest['stages']:
        raise ValueError('Stages are immutable within a run; start a new run to repeat validation')
    if source_hash(root) != manifest['buildSourceSha256']:
        raise ValueError('Build inputs changed after run creation; start a new run')
    destination = path.parent / stage
    destination.mkdir()
    for relative in reports:
        if relative not in REPORT_DIRECTORIES:
            raise ValueError('Only known generated Maven report directories may be isolated')
        old = root / relative
        if old.is_symlink():
            raise ValueError('Report directory symlinks are not accepted')
        if old.exists():
            shutil.move(old, destination / ('preexisting-' + old.name))
    started = time.time()
    record = {'command': argv, 'startedUtc': utc(), 'exitCode': None,
              'status': 'running', 'buildSourceSha256': manifest['buildSourceSha256']}
    manifest['stages'][stage] = record
    atomic_json(path, manifest)
    log_path = destination / 'command.log'
    log_path.touch(exist_ok=False)
    drain = None
    try:
        child = subprocess.Popen(argv, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 start_new_session=os.name != 'nt')
        drain = BoundedProcessLog(child, log_path, limit=32 * 1024 * 1024)
        try:
            record['exitCode'] = child.wait()
            record['status'] = 'passed' if record['exitCode'] == 0 else 'failed'
        except BaseException as interruption:
            # Stop this exact owned child/process group, never an executable name.
            if child.poll() is None:
                if os.name == 'nt': child.terminate()
                else: os.killpg(child.pid, signal.SIGTERM)
                try: child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    if os.name == 'nt': child.kill()
                    else: os.killpg(child.pid, signal.SIGKILL)
                    child.wait(timeout=5)
            record.update(status='failed', exitCode=130 if isinstance(interruption, KeyboardInterrupt) else 1,
                          reason='Verifier interrupted; owned command terminated', commandExitCode=child.returncode)
    except OSError as error:
        record.update(status='unavailable', reason=type(error).__name__)
    finally:
        if drain is not None:
            record['logRetention'] = drain.finish()
            record['logRetention']['file'] = str(log_path.relative_to(root))
            if not record['logRetention']['complete']:
                record.update(status='failed', reason='Required stage log exceeded its 32MiB budget or could not be drained completely')
    record['finishedUtc'] = utc()
    record['durationSeconds'] = time.time() - started
    record['log'] = str((destination / 'command.log').relative_to(root))
    record['logSha256'] = digest(destination / 'command.log')
    record['reports'] = []
    missing_reports = []
    for relative in reports:
        source = root / relative
        if source.is_dir():
            shutil.copytree(source, destination / source.name)
            entries = xml_reports(destination / source.name)
            for entry in entries:
                entry['retained'] = str((destination / source.name / entry['file']).relative_to(root))
            record['reports'].extend(entries)
            if not entries: missing_reports.append(relative)
        else:
            missing_reports.append(relative)
    if reports and (missing_reports or not record['reports'] or any(r[k] for r in record['reports'] for k in ('failures', 'errors', 'skipped'))):
        record.update(status='failed', reason='Required tests are missing, failed, or skipped')
    if '--machine' in argv and any(Path(arg).name in ('flutter', 'flutter.bat') for arg in argv):
        completions, done = [], False
        for line in (destination / 'command.log').read_text(errors='replace').splitlines():
            try: event = json.loads(line)
            except json.JSONDecodeError: continue
            if isinstance(event, dict):
                if event.get('type') == 'testDone' and not event.get('hidden', False):
                    completions.append(event)
                if event.get('type') == 'done': done = event.get('success') is True
        record['flutterTests'] = {'passed': sum(e.get('result') == 'success' and not e.get('skipped', False) for e in completions),
                                  'failed': sum(e.get('result') != 'success' for e in completions),
                                  'skipped': sum(e.get('skipped', False) for e in completions), 'doneSuccess': done}
        if not done or not completions or any(e.get('skipped', False) or e.get('result') != 'success' for e in completions):
            record.update(status='failed', reason='Required Flutter tests are missing, failed, skipped, or lack a successful final event')
    record['artifacts'] = []
    for relative in artifacts:
        artifact = root / relative
        if not artifact.is_file() or artifact.stat().st_mtime < started - 2:
            record.update(status='failed', reason=f'Required artifact missing or stale: {relative}')
        else:
            retained = destination / 'artifacts' / relative
            retained.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(artifact, retained)
            record['artifacts'].append({'file': relative, 'retained': str(retained.relative_to(root)),
                                        'bytes': artifact.stat().st_size, 'sha256': digest(artifact)})
            if record['status'] == 'passed':
                try:
                    validate_native_application_artifact(stage, retained, manifest['buildSourceSha256'], root)
                except (OSError, ValueError, TypeError, KeyError):
                    record.update(status='failed', reason='Required native application exception check is missing or failed')
    if source_hash(root) != manifest['buildSourceSha256']:
        record.update(status='failed', reason='Build inputs changed during validation')
    atomic_json(path, manifest)
    return 0 if record['status'] == 'passed' else (record['exitCode'] or 1)


def unavailable(stage, reason, root=ROOT):
    path = manifest_path(root)
    manifest = json.loads(path.read_text())
    if stage in manifest['stages']:
        raise ValueError('An executed stage cannot be overwritten with an unavailable declaration')
    manifest['stages'][stage] = {'status': 'unavailable', 'reason': reason,
                                 'recordedUtc': utc(), 'exitCode': None, 'command': None}
    atomic_json(path, manifest)


def finish(required, root=ROOT):
    path = manifest_path(root)
    manifest = json.loads(path.read_text())
    current = source_hash(root)
    reasons = []
    try:
        validate_source_snapshot(manifest, root)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        reasons.append('Canonical source snapshot failed: ' + type(error).__name__)
    if current != manifest['buildSourceSha256']:
        reasons.append('Build inputs changed after this verification run')
    for stage in required:
        entry = manifest['stages'].get(stage)
        if entry is None:
            manifest['stages'][stage] = {'status': 'not-run', 'exitCode': None, 'command': None}
            reasons.append(f'Required stage not run: {stage}')
        elif entry['status'] != 'passed':
            reasons.append(f'Required stage {stage}: {entry["status"]}')
    for name, entry in manifest['stages'].items():
        if (entry.get('command') is not None and
                entry.get('buildSourceSha256') != manifest['buildSourceSha256']):
            reasons.append(f'Changed stage source snapshot: {name}')
        if entry.get('log') and (not (root / entry['log']).is_file() or digest(root / entry['log']) != entry['logSha256']):
            reasons.append(f'Changed evidence log: {name}')
        for report in entry.get('reports', []):
            if not (root / report['retained']).is_file() or digest(root / report['retained']) != report['sha256']:
                reasons.append(f'Changed evidence test report: {report["file"]}')
        for artifact in entry.get('artifacts', []):
            if (not (root / artifact['retained']).is_file()
                    or (root / artifact['retained']).stat().st_size != artifact['bytes']
                    or digest(root / artifact['retained']) != artifact['sha256']):
                reasons.append(f'Changed evidence artifact: {artifact["file"]}')
            elif entry.get('status') == 'passed':
                try:
                    validate_native_application_artifact(name, root / artifact['retained'], manifest['buildSourceSha256'], root)
                except (OSError, ValueError, TypeError, KeyError):
                    reasons.append(f'Required native application exception check failed: {name}')
    record = {**manifest, 'recordedUtc': utc(), 'currentBuildSourceSha256': current,
              'requiredStages': list(required), 'acceptancePassed': not reasons,
              'acceptanceFailures': reasons, 'productionComplete': False}
    atomic_json(path.parent / 'verification-evidence.json', record)
    atomic_json(root / 'build/verification-evidence.json', record)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest='action', required=True)
    commands.add_parser('start')
    execute = commands.add_parser('run')
    execute.add_argument('--stage', required=True)
    execute.add_argument('--reports', action='append', default=[])
    execute.add_argument('--artifact', action='append', default=[])
    execute.add_argument('command', nargs=argparse.REMAINDER)
    missing = commands.add_parser('unavailable')
    missing.add_argument('--stage', required=True)
    missing.add_argument('--reason', required=True)
    args = parser.parse_args()
    if args.action == 'start':
        print(start())
    elif args.action == 'run':
        argv = args.command[1:] if args.command[:1] == ['--'] else args.command
        sys.exit(run(args.stage, argv, args.reports, args.artifact))
    else:
        unavailable(args.stage, args.reason)


if __name__ == '__main__':
    main()
