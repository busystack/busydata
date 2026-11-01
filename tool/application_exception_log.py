"""Bounded, source-bound checks of drained native Flutter application output.

The pinned release framework emits a plain exception label followed by Dart
frames; debug/profile banners alone cannot certify an ordinary release run.
Only engine/framework signatures are classified, never a generic 'error' word.
No exception message, SQL text or value is copied into these receipts.
"""
import hashlib
from pathlib import Path
import re
import uuid

POLICY = 'pinned-flutter-native-exceptions-v1'
MAX_LOG_BYTES = 2 * 1024 * 1024
MAX_LOGS = 8
MAX_FINDINGS = 32
RELAUNCH_NAMES = {f'application-relaunch-{index}.log' for index in range(1, MAX_LOGS)}
NAMES = {'application.log', 'application-relaunch.log'} | RELAUNCH_NAMES
_ANSI = re.compile(r'\x1b\[[0-?]*[ -/]*[@-~]')
_UNHANDLED = re.compile(r'^(?:\[ERROR:flutter/runtime/dart_vm_initializer\.cc\([0-9]+\)\]\s*)?Unhandled [Ee]xception:')
_BANNER = re.compile(r'^[═╞╡\s-]*EXCEPTION CAUGHT BY [A-Z /_-]+ LIBRARY[═╞╡\s-]*$')
_FRAME = re.compile(r'^#0\s+[^\r\n]+\((?:package:|dart:|file:)[^\r\n)]*\)\s*$')
_OVERFLOW = re.compile(r'^A RenderFlex overflowed by [0-9.,]+ pixels on the (?:left|right|top|bottom)\.$')
_FATAL = re.compile(r'^\[FATAL:flutter/[^\r\n\]]+\]')


class ApplicationLogNames:
    """Reserve one immutable log per actual owned process before launching it."""
    def __init__(self):
        self.primary = False
        self.relaunches = 0

    def claim(self, requested):
        if requested == 'application':
            if self.primary:
                raise ValueError('Owned primary application log is already reserved')
            self.primary = True
            return requested
        if requested != 'application-relaunch' or not self.primary or self.relaunches >= MAX_LOGS - 1:
            raise ValueError('Owned application relaunch log admission failed')
        self.relaunches += 1
        return f'application-relaunch-{self.relaunches}'


def scan(data):
    """Return codes/line numbers only; raw diagnostics stay in their owned log."""
    if len(data) > MAX_LOG_BYTES:
        raise ValueError('application-log-byte-limit')
    text = data.decode('utf-8', errors='strict')
    findings = []
    total = 0
    for number, raw in enumerate(text.splitlines(), 1):
        line = _ANSI.sub('', raw).strip()
        if line.startswith('flutter: '):
            line = line[len('flutter: '):]
        code = None
        if _UNHANDLED.match(line): code = 'dart-unhandled-exception'
        elif _BANNER.match(line): code = 'flutter-framework-exception'
        elif line.startswith('Another exception was thrown:'): code = 'flutter-framework-repeated-exception'
        elif _FRAME.match(line): code = 'flutter-release-error-stack'
        elif _OVERFLOW.match(line): code = 'flutter-render-overflow'
        elif _FATAL.match(line): code = 'flutter-engine-fatal'
        if code:
            total += 1
            if len(findings) < MAX_FINDINGS:
                findings.append({'code': code, 'line': number})
    return {'findingCount': total, 'findings': findings, 'findingsLimited': total > len(findings)}


def _application_logs(logs):
    if not isinstance(logs, list) or len(logs) > 64:
        return []
    return [item for item in logs if isinstance(item, dict) and
            isinstance(item.get('file'), str) and Path(item['file']).name in NAMES]


def audit(logs, source_sha256, directory):
    """Call only after children stopped and every BoundedProcessLog finished."""
    directory = Path(directory).absolute()
    result = {'version': 1, 'policy': POLICY, 'sourceSha256': source_sha256,
              'directory': str(directory), 'complete': False, 'passed': False,
              'findingCount': 0, 'logs': []}
    if not isinstance(source_sha256, str) or re.fullmatch('[0-9a-f]{64}', source_sha256) is None:
        result['failureCode'] = 'application-log-source-unavailable'
        return result
    selected = _application_logs(logs)
    if not selected or len(selected) > MAX_LOGS or not any(Path(item['file']).name == 'application.log' for item in selected):
        result['failureCode'] = 'application-log-missing-or-count-limit'
        return result
    seen = set()
    for item in selected:
        path = Path(item['file']).absolute()
        record = {'file': str(path), 'complete': False}
        result['logs'].append(record)
        try:
            if path in seen or path.parent != directory or path.resolve() != path or path.is_symlink() or not path.is_file():
                raise ValueError('application-log-owner')
            seen.add(path)
            before = path.stat()
            if (item.get('complete') is not True or item.get('failureType') is not None or
                    type(item.get('limitBytes')) is not int or not 0 <= item['limitBytes'] <= MAX_LOG_BYTES or
                    item.get('receivedBytes') != before.st_size or item.get('retainedBytes') != before.st_size or
                    before.st_size > item['limitBytes']):
                raise ValueError('application-log-incomplete')
            data = path.read_bytes()
            sha = hashlib.sha256(data).hexdigest()
            after = path.stat()
            if (len(data) != before.st_size or sha != item.get('sha256') or
                    (before.st_ino, before.st_size, before.st_mtime_ns) !=
                    (after.st_ino, after.st_size, after.st_mtime_ns)):
                raise ValueError('application-log-changed')
            found = scan(data)
            record.update({'sha256': sha, 'bytes': len(data), 'complete': True, **found})
            result['findingCount'] += found['findingCount']
        except UnicodeDecodeError:
            record['failureCode'] = 'application-log-invalid-utf8'
        except (OSError, ValueError) as error:
            record['failureCode'] = str(error) if isinstance(error, ValueError) else 'application-log-unavailable'
    result['complete'] = all(item['complete'] for item in result['logs'])
    result['passed'] = result['complete'] and result['findingCount'] == 0
    return result


def validate(report, expected_source, *, directory=None, root=None):
    """A missing/forged check or newly changed raw application log cannot pass."""
    if not isinstance(expected_source, str) or re.fullmatch('[0-9a-f]{64}', expected_source) is None:
        raise ValueError('Native application source identity is unavailable')
    if not isinstance(report, dict):
        raise ValueError('Native application receipt is malformed')
    check = report.get('applicationExceptionCheck')
    if (not isinstance(check, dict) or check.get('version') != 1 or check.get('policy') != POLICY or
            report.get('sourceSha256') != expected_source or check.get('sourceSha256') != expected_source or
            check.get('complete') is not True or check.get('passed') is not True or check.get('findingCount') != 0):
        raise ValueError('Native application exception check is missing, failed or belongs to another source')
    owned = Path(check.get('directory', '')).absolute()
    if directory is not None and owned != Path(directory).absolute():
        raise ValueError('Native application log directory owner changed')
    if root is not None:
        allowed = Path(root).resolve() / 'build/native-accessibility'
        if owned.resolve() != owned or not owned.is_relative_to(allowed):
            raise ValueError('Native application logs are outside the owned evidence directory')
        parts = owned.relative_to(allowed).parts
        if not parts:
            raise ValueError('Native application logs lack their owned run')
        uuid.UUID(parts[0])
    actual = audit(report.get('logs', []), expected_source, owned)
    if actual != check or not actual['passed']:
        raise ValueError('Native application logs do not prove an exception-free completed run')
    return check


def validate_tree(report, expected_source, *, root):
    """Revalidate aggregate ordinary, Fluent and platform-case raw log receipts."""
    validate(report, expected_source, root=root)
    allowed = Path(root).resolve() / 'build/native-accessibility'

    def read(entry, filename):
        if not isinstance(entry, dict) or not isinstance(entry.get('file'), str):
            raise ValueError('Native child exception-check receipt is missing')
        path = Path(entry['file']).absolute()
        if (path.name != filename or path.resolve() != path or not path.is_relative_to(allowed) or
                not path.is_file() or path.stat().st_size > 1024 * 1024):
            raise ValueError('Native child exception-check receipt owner or size is invalid')
        uuid.UUID(path.relative_to(allowed).parts[0])
        data = path.read_bytes()
        if len(data) != entry.get('bytes') or hashlib.sha256(data).hexdigest() != entry.get('sha256'):
            raise ValueError('Native child exception-check receipt changed')
        import json
        value = json.loads(data)
        if not isinstance(value, dict) or value.get('sourceSha256') != expected_source:
            raise ValueError('Native child exception-check source changed')
        return value

    if report.get('fluentRendering') is not None:
        rendering = read(report['fluentRendering'], 'rendering.json')
        if rendering.get('passed') is not True:
            raise ValueError('Native Fluent exception-check scope failed')
        validate(read(rendering.get('report.json'), 'report.json'), expected_source, root=root)
    if report.get('platformMatrix') is not None:
        matrix = read(report['platformMatrix'], 'matrix.json')
        cases = matrix.get('cases')
        if matrix.get('passed') is not True or not isinstance(cases, list) or not 1 <= len(cases) <= 9:
            raise ValueError('Native platform exception-check scope is incomplete')
        seen = set()
        for case in cases:
            if not isinstance(case, dict):
                raise ValueError('Native platform exception-check case is malformed')
            name = case.get('name')
            if not isinstance(name, str) or name in seen:
                raise ValueError('Native platform exception-check scope is duplicated')
            seen.add(name)
            validate(read(case.get('report.json'), 'report.json'), expected_source, root=root)
