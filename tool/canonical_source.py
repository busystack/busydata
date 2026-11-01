"""Canonical distributable BusyData source identity, independent of extraction modes.

The reviewed inclusion/executable policy is code, not metadata supplied by an
archive. A receipt's content hashes are always recomputed from the extracted
files. Archives must contain only the complete declared regular-file snapshot.
"""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import struct
import tempfile
import zipfile


_POLICY = dict(line.split('=', 1) for line in
               Path(__file__).with_name('source_policy.properties').read_text(encoding='utf-8').splitlines()
               if line and not line.startswith('#'))
SOURCE_INPUTS = tuple(_POLICY['inputs'].split(','))
GENERATED_PARTS = set(_POLICY['generatedParts'].split(','))
GENERATED_PATHS = set(_POLICY['generatedPaths'].split(','))
MAX_FILES = int(_POLICY['maxFiles'])
MAX_FILE_BYTES = int(_POLICY['maxFileBytes'])
MAX_SOURCE_BYTES = int(_POLICY['maxSourceBytes'])
MAX_MANIFEST_BYTES = 4 * 1024 * 1024
POLICY = _POLICY['policy']


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True,
                       separators=(',', ':')) + '\n').encode('utf-8')


def normalized_path(name):
    if (not isinstance(name, str) or not name or '\\' in name or '\x00' in name
            or ':' in name or name.startswith('/') or name.endswith('/')
            or len(name.encode('utf-8')) > 2048 or any(ord(ch) < 32 for ch in name)):
        raise ValueError('Source paths must be normalized relative POSIX paths')
    parts = name.split('/')
    if any(part in ('', '.', '..') for part in parts):
        raise ValueError('Source paths cannot contain traversal or empty components')
    if PurePosixPath(name).as_posix() != name:
        raise ValueError('Source path is not normalized')
    return name


def intentional_mode(name):
    """Executable semantics are policy-defined; chmod/ZIP metadata are incidental."""
    normalized_path(name)
    if name in _POLICY['executableExact'].split(','):
        return '0755'
    prefix = _POLICY['executableRoot'] + '/'
    if name.startswith(prefix) and '/' not in name.removeprefix(prefix):
        if (name.endswith(tuple(_POLICY['executableExtensions'].split(',')))
                and not Path(name).name.startswith(tuple(_POLICY['nonExecutablePrefixes'].split(',')))):
            return '0755'
    return '0644'


def _regular(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode):
        raise ValueError('Source symbolic links and non-regular files are unsupported')
    return info


def _file_record(root, path):
    name = normalized_path(path.relative_to(root).as_posix())
    before = _regular(path)
    if before.st_size > MAX_FILE_BYTES:
        raise ValueError('Source file exceeds byte budget')
    flags = os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0)
    with os.fdopen(os.open(path, flags), 'rb') as stream:
        opened = os.fstat(stream.fileno())
        if (opened.st_dev, opened.st_ino) != (before.st_dev, before.st_ino):
            raise ValueError('Source file changed while opening')
        checksum = hashlib.file_digest(stream, 'sha256').hexdigest()
    after = _regular(path)
    if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
            after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
        raise ValueError('Source file changed during hashing')
    return {'path': name, 'type': 'file', 'mode': intentional_mode(name),
            'bytes': before.st_size, 'sha256': checksum}


def source_manifest(root):
    root = Path(root).resolve()
    paths = set()
    for relative in SOURCE_INPUTS:
        path = root / relative
        if path.is_symlink():
            raise ValueError('Source symbolic links are unsupported')
        # Check every ancestor, including roots that select one nested file.
        for parent in path.parents:
            if parent == root:
                break
            if parent.is_symlink():
                raise ValueError('Source symbolic ancestors are unsupported')
        if not path.exists():
            continue
        if path.is_file():
            paths.add(path)
        elif path.is_dir():
            for directory, names, files in os.walk(path, followlinks=False):
                base = Path(directory)
                for name in list(names):
                    child = base / name
                    if name in GENERATED_PARTS or child.relative_to(root).as_posix() in GENERATED_PATHS:
                        names.remove(name)
                    elif child.is_symlink():
                        raise ValueError('Source symbolic directories are unsupported')
                for name in files:
                    if not name.endswith('.pyc'):
                        paths.add(base / name)
        else:
            raise ValueError('Source input must be a regular file or directory')
    if len(paths) > MAX_FILES:
        raise ValueError('Source file-count budget exceeded')
    entries = [_file_record(root, path) for path in sorted(paths,
               key=lambda path: path.relative_to(root).as_posix())]
    if sum(entry['bytes'] for entry in entries) > MAX_SOURCE_BYTES:
        raise ValueError('Source snapshot byte budget exceeded')
    # Windows cannot faithfully extract case-colliding paths. Reject rather than
    # producing a platform-dependent archive identity.
    names = [entry['path'].casefold() for entry in entries]
    if len(set(names)) != len(names):
        raise ValueError('Source paths collide under Windows case folding')
    manifest = {'schemaVersion': 1, 'policy': POLICY, 'files': entries}
    if len(json_bytes(manifest)) > MAX_MANIFEST_BYTES:
        raise ValueError('Source manifest exceeds byte budget')
    return manifest


def manifest_hash(manifest):
    return hashlib.sha256(json_bytes(manifest)).hexdigest()


def source_hash(root):
    return manifest_hash(source_manifest(root))


def load_manifest(path):
    if path.stat().st_size > MAX_MANIFEST_BYTES:
        raise ValueError('Source manifest exceeds byte budget')
    data = path.read_bytes()
    manifest = json.loads(data)
    if data != json_bytes(manifest):
        raise ValueError('Source manifest must use canonical JSON encoding')
    if manifest.get('schemaVersion') != 1 or manifest.get('policy') != POLICY:
        raise ValueError('Unsupported canonical source policy')
    files = manifest.get('files')
    if not isinstance(files, list) or len(files) > MAX_FILES:
        raise ValueError('Source manifest file-count budget exceeded')
    return manifest


def verify_archive(archive_path, expected, *, restore_modes=False):
    """Extract an untrusted ZIP safely, then independently derive its identity."""
    archive_path = Path(archive_path)
    archive_bytes = archive_path.stat().st_size
    if archive_bytes > MAX_SOURCE_BYTES + MAX_MANIFEST_BYTES:
        raise ValueError('Source archive exceeds byte budget')
    # Bound central-directory allocation before ZipFile constructs its member
    # list. This source format never needs multi-disk or ZIP64 metadata.
    with archive_path.open('rb') as source:
        source.seek(max(0, archive_bytes - 65557))
        tail = source.read(65557)
    offset = tail.rfind(b'PK\x05\x06')
    if offset < 0 or len(tail) - offset < 22:
        raise ValueError('Source archive lacks a valid ZIP directory')
    disk, directory_disk, disk_count, count, size, directory_offset, comment = struct.unpack_from('<4H2IH', tail, offset + 4)
    if (disk or directory_disk or disk_count != count or count > MAX_FILES
            or size > MAX_MANIFEST_BYTES or directory_offset + size > archive_bytes
            or len(tail) - offset != 22 + comment):
        raise ValueError('Source archive directory exceeds policy or is unsupported')
    expected_names = {entry['path'] for entry in expected['files']}
    with tempfile.TemporaryDirectory(prefix='busydata-source-check-') as work:
        root = Path(work)
        with zipfile.ZipFile(archive_path) as archive:
            members = archive.infolist()
            if len(members) > MAX_FILES:
                raise ValueError('Source archive file-count budget exceeded')
            names, total = set(), 0
            for member in members:
                name = normalized_path(member.filename)
                if name in names or name not in expected_names:
                    raise ValueError('Source archive contains duplicate or undeclared files')
                names.add(name)
                kind = (member.external_attr >> 16) & 0o170000
                if kind not in (0, stat.S_IFREG) or member.is_dir() or member.flag_bits & 1:
                    raise ValueError('Source archive contains unsupported file type')
                if member.file_size > MAX_FILE_BYTES:
                    raise ValueError('Source archive file exceeds byte budget')
                total += member.file_size
                if total > MAX_SOURCE_BYTES:
                    raise ValueError('Source archive byte budget exceeded')
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as source, target.open('xb') as output:
                    remaining = member.file_size
                    while chunk := source.read(min(65536, remaining + 1)):
                        remaining -= len(chunk)
                        if remaining < 0:
                            raise ValueError('Source archive expanded beyond declared size')
                        output.write(chunk)
                    if remaining:
                        raise ValueError('Source archive has a truncated member')
                if restore_modes:
                    target.chmod(int(intentional_mode(name), 8))
            if names != expected_names:
                raise ValueError('Source archive is missing declared source files')
        actual = source_manifest(root)
        if actual != expected:
            raise ValueError('Extracted source does not reproduce the canonical manifest')
        return {'manifestSha256': manifest_hash(actual), 'files': len(actual['files']),
                'bytes': sum(item['bytes'] for item in actual['files']),
                'extractedAndVerified': True}


def write_archive(root, destination, manifest):
    """Create a deterministic ZIP from the exact frozen regular-file snapshot."""
    destination = Path(destination)
    partial = destination.with_suffix('.partial')
    created = False
    try:
        stream = partial.open('xb')
        created = True
        with stream, zipfile.ZipFile(stream, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for entry in manifest['files']:
                path = Path(root) / entry['path']
                if _file_record(Path(root), path) != entry:
                    raise ValueError('Source changed during archive creation')
                info = zipfile.ZipInfo(entry['path'], date_time=(1980, 1, 1, 0, 0, 0))
                info.create_system = 3
                info.external_attr = (stat.S_IFREG | int(entry['mode'], 8)) << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                flags = os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0)
                with os.fdopen(os.open(path, flags), 'rb') as source, archive.open(info, 'w') as output:
                    checksum = hashlib.sha256()
                    size = 0
                    while chunk := source.read(65536):
                        size += len(chunk)
                        if size > entry['bytes']:
                            raise ValueError('Source grew during archive creation')
                        checksum.update(chunk)
                        output.write(chunk)
                    if size != entry['bytes'] or checksum.hexdigest() != entry['sha256']:
                        raise ValueError('Source changed during archive creation')
        if source_manifest(root) != manifest:
            raise ValueError('Source changed after archive creation')
        verified = verify_archive(partial, manifest)
        commit_new_artifact(partial, destination)
        return verified
    finally:
        if created:
            partial.unlink(missing_ok=True)


def commit_new_artifact(partial, destination):
    """Publish a build-owned completed artifact without clobbering any winner.

    Artifacts are created beside their final path. Atomic hard-link insertion is
    the no-clobber primitive; unsupported/cross-device filesystems fail explicitly.
    No exists-then-rename or replacing fallback is used.
    """
    before = _regular(Path(partial))
    os.link(partial, destination, follow_symlinks=False)
    after = _regular(Path(destination))
    if (before.st_dev, before.st_ino) != (after.st_dev, after.st_ino):
        raise ValueError('Artifact source changed during no-clobber publication')
    Path(partial).unlink()


def extract_archive(archive_path, destination, expected):
    """Materialize a previously verified source ZIP into a new empty directory."""
    verify_archive(archive_path, expected)
    destination = Path(destination)
    destination.mkdir(parents=True, exist_ok=False)
    with zipfile.ZipFile(archive_path) as archive:
        for entry in expected['files']:
            target = destination / normalized_path(entry['path'])
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(entry['path']) as source, target.open('xb') as output:
                count = 0
                while chunk := source.read(65536):
                    count += len(chunk)
                    if count > entry['bytes']:
                        raise ValueError('Source archive changed during materialization')
                    output.write(chunk)
            target.chmod(int(intentional_mode(entry['path']), 8))
    if source_manifest(destination) != expected:
        raise ValueError('Materialized source does not match its frozen manifest')
    return destination
