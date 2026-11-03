#!/usr/bin/env python3
"""Preserve one completed run and its checked underlying reports locally. No upload."""
import argparse
import json
import hashlib
import gzip
from pathlib import Path
import tarfile
import tempfile
import uuid

from verification_evidence import (ROOT, atomic_json, digest, finish, source_hash,
                                   utc, validate_source_snapshot)
from canonical_source import (normalized_path, load_manifest, verify_archive,
                              manifest_hash, MAX_MANIFEST_BYTES, commit_new_artifact)
from application_exception_log import RELAUNCH_NAMES

NATIVE_LOGS = {'speech.log', 'ibus.log', 'orca.log', 'application.log', 'application-relaunch.log',
               'controller.log', 'orca-debug.log', 'xdg-desktop-portal.log',
               'xdg-desktop-portal-gtk.log'}
NATIVE_LOGS |= RELAUNCH_NAMES
NATIVE_CASES = {'light', 'dark', 'light-125', 'light-150', 'display-200',
                'contrast-200-reduced', 'contrast-dark-200-reduced',
                'de-light-200-reduced', 'rtl-dark-200-reduced'}
NATIVE_CASE_FILES = NATIVE_LOGS | {'report.json', 'composed-settings.json', 'portal-settings.txt',
                                  'authored-editor-undo-failure.png', 'authored-cell-dialog-failure.png'}


def preflight_evidence_tar(path):
    """Check gzip/tar budgets before TarFile allocates members or PAX values.

    The generated format contains regular files and bounded standard path/time
    metadata. Size overrides, long-link records and recursively chained metadata
    are unnecessary for this format and are rejected rather than interpreted.
    """
    if Path(path).stat().st_size > 272 * 1024 * 1024:
        raise ValueError('Evidence compressed archive byte budget exceeded')
    members = metadata_records = payload = metadata_bytes = consecutive_metadata = 0
    with gzip.open(path, 'rb') as stream:
        def read_exact(count):
            result = bytearray()
            while count:
                chunk = stream.read(min(count, 65536))
                if not chunk:
                    raise ValueError('Evidence archive is truncated')
                result.extend(chunk)
                count -= len(chunk)
            return bytes(result)

        def skip_exact(count):
            while count:
                chunk = stream.read(min(count, 65536))
                if not chunk:
                    raise ValueError('Evidence archive is truncated')
                count -= len(chunk)

        while True:
            header = read_exact(512)
            if not any(header):
                if consecutive_metadata:
                    raise ValueError('Evidence archive has metadata without a member')
                if any(read_exact(512)):
                    raise ValueError('Evidence archive lacks its second end marker')
                # tarfile pads its final record to 10KiB. Bound trailing zeros,
                # and reject hidden concatenated members instead of ignoring them.
                trailing = stream.read(10241)
                if len(trailing) > 10240 or any(trailing):
                    raise ValueError('Evidence archive has excessive or nonzero trailing data')
                return
            try:
                size = tarfile.nti(header[124:136])
                checksum = tarfile.nti(header[148:156])
            except tarfile.HeaderError as error:
                raise ValueError('Evidence archive has an invalid tar header') from error
            if checksum not in tarfile.calc_chksums(header) or size < 0:
                raise ValueError('Evidence archive has an invalid tar checksum or size')
            kind = header[156:157]
            if kind in (tarfile.XHDTYPE, tarfile.XGLTYPE, tarfile.GNUTYPE_LONGNAME):
                metadata_records += 1
                consecutive_metadata += 1
                metadata_bytes += size
                if size > 8192 or metadata_bytes > 4 * 1024 * 1024:
                    raise ValueError('Evidence tar metadata byte budget exceeded')
                if metadata_records > 32768 or consecutive_metadata > 2:
                    raise ValueError('Evidence tar metadata count/depth budget exceeded')
                data = read_exact(size)
                if kind == tarfile.GNUTYPE_LONGNAME:
                    normalized_path(data.rstrip(b'\0').decode('utf-8', errors='strict'))
                else:
                    position = 0
                    while position < len(data):
                        end = data.find(b' ', position)
                        if end < 0 or end - position > 5 or not data[position:end].isdigit():
                            raise ValueError('Evidence PAX record is malformed')
                        length = int(data[position:end])
                        record_end = position + length
                        if length <= end - position + 1 or record_end > len(data) or data[record_end - 1:record_end] != b'\n':
                            raise ValueError('Evidence PAX record is malformed')
                        key, separator, value = data[end + 1:record_end - 1].partition(b'=')
                        if not separator or key not in (b'path', b'mtime', b'atime', b'ctime', b'uname', b'gname'):
                            raise ValueError('Evidence PAX field is unsupported (including size overrides)')
                        if len(value) > 2048:
                            raise ValueError('Evidence PAX field byte budget exceeded')
                        if key == b'path':
                            normalized_path(value.decode('utf-8', errors='strict'))
                        position = record_end
            elif kind in (tarfile.REGTYPE, tarfile.AREGTYPE):
                members += 1
                consecutive_metadata = 0
                if members > 32768:
                    raise ValueError('Evidence archive member-count budget exceeded')
                if size > 32 * 1024 * 1024:
                    raise ValueError('Evidence archive member byte budget exceeded')
                payload += size
                # The collection index has its separate 4MiB cap and is not
                # part of the 256MiB declared retained-file budget checked below.
                if payload > 256 * 1024 * 1024 + MAX_MANIFEST_BYTES:
                    raise ValueError('Evidence archive payload byte budget exceeded')
                skip_exact(size)
            else:
                raise ValueError('Evidence archive contains unsupported tar member types')
            skip_exact((-size) % 512)


def native_relative(value):
    parts = Path(value).parts
    try:
        offset = parts.index('native-accessibility')
        tail = parts[offset + 1:]
    except ValueError as error:
        raise ValueError('Native evidence diagnostic has no owned run') from error
    if not tail:
        raise ValueError('Native evidence has no run identity')
    uuid.UUID(tail[0])
    allowed = (len(tail) == 2 and tail[1] in NATIVE_CASE_FILES)
    allowed |= (len(tail) == 3 and tail[1:] == ('platform-matrix', 'matrix.json'))
    allowed |= (len(tail) == 4 and tail[1] == 'platform-matrix'
                and tail[2] in NATIVE_CASES and tail[3] in NATIVE_CASE_FILES)
    if not allowed:
        raise ValueError('Native evidence diagnostic is outside its allowed owned files')
    return 'build/native-accessibility/' + '/'.join(tail)


def native_references(native, read_json):
    """Only hash-bound public acceptance receipts and explicitly named diagnostics."""
    references = []

    def add(entry):
        if entry is not None:
            if not isinstance(entry, dict) or 'file' not in entry or 'sha256' not in entry:
                raise ValueError('Native evidence reference lacks its identity')
            references.append({**entry, 'file': native_relative(entry['file'])})

    def report_entries(report):
        for entry in [*report.get('logs', []), report.get('readerLog'), report.get('controllerLog'),
                      report.get('actualComposedSettingsFile'), report.get('authoredEditorFailureImage'),
                      report.get('authoredCellDialogFailureImage')]:
            add(entry)

    report_entries(native)
    matrix_entry = native.get('platformMatrix')
    if matrix_entry:
        add(matrix_entry)
        matrix = read_json(native_relative(matrix_entry['file']))
        if matrix.get('sourceSha256') != native['sourceSha256']:
            raise ValueError('Native platform matrix belongs to different source')
        if len(matrix.get('cases', [])) > len(NATIVE_CASES):
            raise ValueError('Native platform matrix case admission exceeded')
        for case in matrix.get('cases', []):
            if case.get('name') not in NATIVE_CASES:
                raise ValueError('Unknown native platform matrix case')
            for key in ('controllerLog', 'report.json', 'composed-settings.json', 'portal-settings.txt'):
                add(case.get(key))
            if case.get('report.json'):
                case_report = read_json(native_relative(case['report.json']['file']))
                if case_report.get('sourceSha256') != native['sourceSha256']:
                    raise ValueError('Native platform case belongs to different source')
                report_entries(case_report)
    return references


def package(run_id, root=ROOT, historical=False):
    uuid.UUID(run_id)
    root = root.resolve()
    run = root / 'build/verification/runs' / run_id
    record_path = run / 'verification-evidence.json'
    record = json.loads(record_path.read_text())
    if record['runId'] != run_id or not record.get('recordedUtc'):
        raise ValueError('A completed matching verification record is required')
    manifest = json.loads((run / 'manifest.json').read_text())
    missing = {name: value for name, value in record['stages'].items()
               if name not in manifest['stages']}
    if (any(record['stages'].get(name) != value for name, value in manifest['stages'].items())
            or any(value != {'status': 'not-run', 'exitCode': None, 'command': None}
                   for value in missing.values())
            or record['buildSourceSha256'] != manifest['buildSourceSha256']):
        raise ValueError('Completed evidence and its immutable stage manifest diverged')
    if record.get('sourceSnapshot') != manifest.get('sourceSnapshot'):
        raise ValueError('Completed evidence source snapshot diverged')
    validate_source_snapshot(manifest, root)
    for name, stage in record['stages'].items():
        if (stage.get('command') is not None and
                stage.get('buildSourceSha256') != record['buildSourceSha256']):
            raise ValueError('Evidence stage belongs to different source: ' + name)
    current = source_hash(root)
    matches = current == record['buildSourceSha256'] == record['currentBuildSourceSha256']
    if not matches and not historical:
        raise ValueError('Source changed; historical evidence requires explicit --historical and cannot certify current source')
    files = {}
    external_artifacts = []
    total = 0

    def retain(relative, expected=None, native=False, expected_bytes=None):
        nonlocal total
        normalized_path(str(relative))
        path = root / relative
        if path.is_symlink() or not path.is_file():
            raise ValueError('Evidence file is missing or symbolic')
        resolved = path.resolve()
        scope = root / 'build/native-accessibility' if native else run
        if not resolved.is_relative_to(scope) or path.absolute() != resolved:
            raise ValueError('Evidence must remain inside its owned run without symbolic ancestors')
        if native:
            if native_relative(str(resolved)) != path.relative_to(root).as_posix():
                raise ValueError('Only named native diagnostic logs are allowed; private fixtures are excluded')
        value = digest(path)
        if expected is not None and value != expected:
            raise ValueError('Evidence hash changed: ' + str(relative))
        key = path.relative_to(root).as_posix()
        size = path.stat().st_size
        if expected_bytes is not None and size != expected_bytes:
            raise ValueError('Evidence byte size changed: ' + str(relative))
        if key in files:
            return
        if size > 32 * 1024 * 1024 or total + size > 256 * 1024 * 1024:
            raise ValueError('Local evidence archive byte budget exceeded')
        total += size
        files[key] = {'sha256': value, 'bytes': size}

    retain(record_path.relative_to(root).as_posix())
    retain((run / 'manifest.json').relative_to(root).as_posix())
    for artifact in record['sourceSnapshot'].values():
        if isinstance(artifact, dict) and 'file' in artifact:
            retain(artifact['file'], artifact['sha256'], expected_bytes=artifact['bytes'])
    for stage in record['stages'].values():
        if stage.get('status') == 'running':
            raise ValueError('A running stage cannot be archived as completed evidence')
        if stage.get('log'):
            retain(stage['log'], stage['logSha256'])
        for report in stage.get('reports', []):
            retain(report['retained'], report['sha256'])
        for artifact in stage.get('artifacts', []):
            retain(artifact['retained'], artifact['sha256'], expected_bytes=artifact['bytes'])
            if artifact['file'].endswith('.json') and artifact['bytes'] <= 8 * 1024 * 1024:
                value = json.loads((root / artifact['retained']).read_text())
                if isinstance(value, dict):
                    for identity in ('sourceSha256', 'buildSourceSha256'):
                        if identity in value and value[identity] != record['buildSourceSha256']:
                            raise ValueError('Evidence artifact belongs to different source: ' + artifact['file'])
                if artifact['file'] == 'build/installed-snap.json':
                    if len(value.get('diagnostics', [])) > 128:
                        raise ValueError('Installed acceptance diagnostic admission exceeded')
                    for entry in value.get('diagnostics', []):
                        retain(entry['file'], entry['sha256'], expected_bytes=entry['bytes'])
                    for entry in value.get('packages', []):
                        path = root / normalized_path(entry['file'])
                        if (entry.get('sourceSha256') != record['buildSourceSha256']
                                or path.is_symlink() or path.absolute() != path.resolve()
                                or not path.resolve().is_relative_to(root / 'build/installed-snap-vm')
                                or path.suffix != '.snap' or not path.is_file()
                                or path.stat().st_size != entry['bytes'] or digest(path) != entry['sha256']):
                            raise ValueError('Separate release package is missing, changed, or stale')
                        external_artifacts.append(entry)
            if artifact['file'] == 'build/native-accessibility-linux.json':
                native = json.loads((root / artifact['retained']).read_text())
                if native['sourceSha256'] != record['buildSourceSha256']:
                    raise ValueError('Native acceptance belongs to different source')
                def read_native_json(relative):
                    retain(relative, native=True)
                    path = root / relative
                    if path.stat().st_size > 1024 * 1024:
                        raise ValueError('Native evidence JSON receipt exceeds byte budget')
                    return json.loads(path.read_text())
                for entry in native_references(native, read_native_json):
                    retain(entry['file'], entry['sha256'], native=True,
                           expected_bytes=entry.get('bytes', entry.get('retainedBytes')))
    collection = {
        'version': 2, 'runId': run_id, 'collectedUtc': utc(),
        'buildSourceSha256': record['buildSourceSha256'],
        'currentBuildSourceSha256': current, 'currentSourceMatches': matches,
        'historical': not matches, 'recordedAcceptancePassed': record['acceptancePassed'],
        'productionComplete': False, 'files': files,
        'sourceSnapshot': record['sourceSnapshot'],
        'sourceRevision': record['sourceRevision'], 'workingTree': record['workingTree'],
        'externalArtifacts': external_artifacts,
        'excluded': ['preexisting reports', 'private fixtures', 'credentials',
                     'user documents', 'result spools', 'unreferenced files',
                     'separate release packages (hash-bound in externalArtifacts)'],
    }
    destination = root / 'build/evidence'
    destination.mkdir(parents=True, exist_ok=True)
    archive = destination / ('busydata-' + run_id + '-evidence-' + uuid.uuid4().hex[:12] + '.tar.gz')
    index = archive.with_name(archive.name.removesuffix('.tar.gz') + '.json')
    partial = archive.with_suffix('.partial')
    with index.open('x') as stream:
        stream.write(json.dumps(collection, indent=2) + '\n')
    created = False
    try:
        stream = partial.open('xb')
        created = True
        with stream, tarfile.open(fileobj=stream, mode='w:gz', dereference=False) as output:
            output.add(index, arcname='collection.json', recursive=False)
            for relative in sorted(files):
                if digest(root / relative) != files[relative]['sha256']:
                    raise ValueError('Evidence changed during collection')
                output.add(root / relative, arcname=relative, recursive=False)
        verify_evidence_archive(partial)
        commit_new_artifact(partial, archive)
    finally:
        if created:
            partial.unlink(missing_ok=True)
    checksum = archive.with_name(archive.name + '.sha256')
    with checksum.open('x') as stream:
        stream.write(digest(archive) + '  ' + archive.name + '\n')
    return archive


def verify_evidence_archive(archive_path):
    """Validate complete members, byte sizes/hashes and the embedded source ZIP.

    No general tar extraction is used. Only the declared regular source manifest
    and ZIP are copied into a disposable directory after every member is checked.
    """
    preflight_evidence_tar(archive_path)
    with tarfile.open(archive_path, 'r:gz') as archive:
        members, actual_files = {}, {}
        collection, total = None, 0
        for member in archive:
            name = normalized_path(member.name)
            if name in members:
                raise ValueError('Evidence archive contains duplicate members')
            if len(members) >= 32768 or not member.isfile():
                raise ValueError('Evidence archive contains unsupported members')
            members[name] = member
            if name == 'collection.json':
                if member.size > MAX_MANIFEST_BYTES:
                    raise ValueError('Evidence collection exceeds byte budget')
                collection = json.load(archive.extractfile(member))
                continue
            if member.size < 0 or member.size > 32 * 1024 * 1024:
                raise ValueError('Evidence archive member byte size changed')
            total += member.size
            if total > 256 * 1024 * 1024:
                raise ValueError('Evidence archive byte budget exceeded')
            with archive.extractfile(member) as source:
                actual_files[name] = {'bytes': member.size,
                                      'sha256': hashlib.file_digest(source, 'sha256').hexdigest()}
        if collection is None:
            raise ValueError('Evidence archive lacks its collection')
        declared = collection.get('files')
        if not isinstance(declared, dict) or set(actual_files) != set(declared):
            raise ValueError('Evidence archive has missing or undeclared retained files')
        uuid.UUID(collection['runId'])
        for name, expected in declared.items():
            normalized_path(name)
            if actual_files[name]['bytes'] != expected['bytes']:
                raise ValueError('Evidence archive member byte size changed')
            if actual_files[name]['sha256'] != expected['sha256']:
                raise ValueError('Evidence archive member hash changed')
        def content(name):
            return archive.extractfile(members[name])
        run_prefix = 'build/verification/runs/' + collection['runId'] + '/'
        record_name, manifest_name = run_prefix + 'verification-evidence.json', run_prefix + 'manifest.json'
        if record_name not in declared or manifest_name not in declared:
            raise ValueError('Evidence archive lacks its completed run records')
        record = json.load(content(record_name))
        manifest = json.load(content(manifest_name))
        if (record.get('runId') != collection['runId'] or manifest.get('runId') != collection['runId']
                or record.get('buildSourceSha256') != collection['buildSourceSha256']
                or manifest.get('buildSourceSha256') != collection['buildSourceSha256']
                or record.get('sourceSnapshot') != collection.get('sourceSnapshot')
                or manifest.get('sourceSnapshot') != collection.get('sourceSnapshot')):
            raise ValueError('Evidence archive records belong to different source snapshots')
        if any(record['stages'].get(name) != stage for name, stage in manifest['stages'].items()):
            raise ValueError('Evidence archive completed record differs from its stage manifest')
        if any(stage != {'status': 'not-run', 'exitCode': None, 'command': None}
               for name, stage in record['stages'].items() if name not in manifest['stages']):
            raise ValueError('Evidence archive completed record contains unrecorded stages')
        references = {record_name, manifest_name}
        for stage in record['stages'].values():
            if stage.get('command') is not None and stage.get('buildSourceSha256') != collection['buildSourceSha256']:
                raise ValueError('Evidence archive stage belongs to different source')
            if stage.get('log'):
                references.add(stage['log'])
                if declared.get(stage['log'], {}).get('sha256') != stage['logSha256']:
                    raise ValueError('Evidence stage log differs from its declared hash')
            for entry in [*stage.get('reports', []), *stage.get('artifacts', [])]:
                references.add(entry['retained'])
                if declared.get(entry['retained'], {}).get('sha256') != entry['sha256']:
                    raise ValueError('Evidence report/artifact differs from its declared hash')
                if 'bytes' in entry and declared[entry['retained']]['bytes'] != entry['bytes']:
                    raise ValueError('Evidence artifact differs from its declared byte size')
            for entry in stage.get('artifacts', []):
                if entry['file'] == 'build/installed-snap.json':
                    installed = json.load(content(entry['retained']))
                    for diagnostic in installed.get('diagnostics', []):
                        references.add(diagnostic['file'])
                        if declared.get(diagnostic['file']) != {'bytes': diagnostic['bytes'], 'sha256': diagnostic['sha256']}:
                            raise ValueError('Installed diagnostic differs from its declared receipt')
                    if any(package not in collection.get('externalArtifacts', []) for package in installed.get('packages', [])):
                        raise ValueError('Separate release package differs from its evidence inventory')
                if entry['file'] != 'build/native-accessibility-linux.json':
                    continue
                native = json.load(content(entry['retained']))
                if native.get('sourceSha256') != collection['buildSourceSha256']:
                    raise ValueError('Native evidence belongs to different source')
                def read_native_json(relative):
                    if declared.get(relative, {}).get('bytes', 1024 * 1024 + 1) > 1024 * 1024:
                        raise ValueError('Native evidence JSON receipt exceeds byte budget')
                    return json.load(content(relative))
                for log in native_references(native, read_native_json):
                    references.add(log['file'])
                    if declared.get(log['file'], {}).get('sha256') != log['sha256']:
                        raise ValueError('Native evidence log differs from its declared hash')
                    expected_bytes = log.get('bytes', log.get('retainedBytes'))
                    if (expected_bytes is not None and
                            declared[log['file']]['bytes'] != expected_bytes):
                        raise ValueError('Native evidence file differs from its declared byte size')
        snapshot = collection.get('sourceSnapshot')
        if not snapshot:
            raise ValueError('Evidence archive lacks its canonical source snapshot')
        references.update(snapshot[key]['file'] for key in ('manifest', 'archive'))
        if references != set(declared):
            raise ValueError('Evidence archive contains files unreferenced by its run')
        with tempfile.TemporaryDirectory(prefix='busydata-evidence-check-') as work:
            paths = {}
            for key in ('manifest', 'archive'):
                entry = snapshot[key]
                if declared.get(entry['file']) != {'bytes': entry['bytes'], 'sha256': entry['sha256']}:
                    raise ValueError('Evidence source receipt differs from its member inventory')
                target = Path(work) / key
                with content(entry['file']) as source, target.open('xb') as output:
                    while chunk := source.read(65536):
                        output.write(chunk)
                paths[key] = target
            canonical = load_manifest(paths['manifest'])
            if manifest_hash(canonical) != collection['buildSourceSha256']:
                raise ValueError('Evidence canonical source belongs to another snapshot')
            verify_archive(paths['archive'], canonical)
        return collection


def finish_with_archive(required, root=ROOT):
    record = finish(required, root)
    try:
        archive = package(record['runId'], root,
                          historical=record['buildSourceSha256'] != record['currentBuildSourceSha256'])
        atomic_json(root / 'build/verification-archive.json', {
            'runId': record['runId'], 'file': archive.relative_to(root).as_posix(),
            'bytes': archive.stat().st_size, 'sha256': digest(archive),
            'recordedAcceptancePassed': record['acceptancePassed'],
        })
    except Exception as error:
        record['acceptancePassed'] = False
        record['acceptanceFailures'].append('Underlying evidence archive failed: ' + type(error).__name__)
        atomic_json(root / 'build/verification/runs' / record['runId'] / 'verification-evidence.json', record)
        atomic_json(root / 'build/verification-evidence.json', record)
        atomic_json(root / 'build/verification-archive.json', {
            'runId': record['runId'], 'status': 'failed',
            'recordedAcceptancePassed': False,
            'reason': 'Underlying evidence archive failed: ' + type(error).__name__,
        })
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-id')
    parser.add_argument('--historical', action='store_true')
    parser.add_argument('--verify-archive', type=Path)
    parser.add_argument('--expected-sha256')
    parser.add_argument('--external-artifact-root', type=Path,
                        help='Also verify separate release packages beneath this root')
    args = parser.parse_args()
    if args.verify_archive:
        if args.run_id or args.historical:
            parser.error('Archive verification cannot package or relabel a run')
        if args.expected_sha256 and digest(args.verify_archive) != args.expected_sha256:
            raise ValueError('Evidence archive differs from its independent SHA-256')
        collection = verify_evidence_archive(args.verify_archive)
        if args.external_artifact_root:
            root = args.external_artifact_root.resolve()
            for entry in collection.get('externalArtifacts', []):
                path = root / normalized_path(entry['file'])
                if (path.is_symlink() or path.absolute() != path.resolve()
                        or not path.resolve().is_relative_to(root) or not path.is_file()
                        or path.stat().st_size != entry['bytes'] or digest(path) != entry['sha256']):
                    raise ValueError('Separate release artifact differs from its independent evidence')
        print(json.dumps({'runId': collection['runId'], 'files': len(collection['files']),
                          'buildSourceSha256': collection['buildSourceSha256'],
                          'recordedAcceptancePassed': collection['recordedAcceptancePassed'],
                          'productionComplete': collection['productionComplete'],
                          'externalArtifactsVerified': args.external_artifact_root is not None,
                          'archiveVerified': True}, indent=2))
        return
    if args.expected_sha256 or args.external_artifact_root:
        parser.error('Independent hash/external-artifact checks require --verify-archive')
    run_id = args.run_id or json.loads((ROOT / 'build/verification/current-run.json').read_text())['runId']
    print(package(run_id, historical=args.historical))


if __name__ == '__main__':
    main()
