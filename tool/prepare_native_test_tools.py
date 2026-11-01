#!/usr/bin/env python3
"""Publish fresh immutable fixture clients without altering upstream ELF bytes."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from bounded_process_log import BoundedProcessLog

ROOT = Path(__file__).resolve().parents[1]
CLIENTS = {
    'postgresql': ('postgres:17.11-bookworm', {'pg_dump': '/usr/lib/postgresql/17/bin/pg_dump', 'psql': '/usr/lib/postgresql/17/bin/psql'}),
    'mysql': ('mysql:8.4.10', {'mysqldump': '/usr/bin/mysqldump', 'mysql': '/usr/bin/mysql'}),
    'mariadb': ('mariadb:11.8.9', {'mariadb-dump': '/usr/bin/mariadb-dump', 'mariadb': '/usr/bin/mariadb'}),
}
FORMAT, MAX_GENERATIONS = 1, 8
MAX_CACHE_BYTES, MAX_GENERATION_BYTES, MAX_FILES = 2 * 1024**3, 256 * 1024**2, 2048


def checksum(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def bounded_capture(arguments, directory, *, limit=1024 * 1024, timeout=60, env=None):
    with tempfile.TemporaryDirectory(prefix='.capture-', dir=directory) as temporary:
        output = Path(temporary) / 'output.log'
        process = subprocess.Popen(arguments, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
        log = BoundedProcessLog(process, output, limit)
        try:
            try:
                status = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired as expired:
                raise RuntimeError('Owned fixture command exceeded its deadline') from expired
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(2)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(2)
            record = log.finish()
        if not record['complete']:
            raise RuntimeError('Fixture command output exceeded its bound or could not be drained')
        text = output.read_text(encoding='utf-8')
        if status != 0:
            raise RuntimeError('Fixture command failed (' + str(status) + '): ' + text[-4096:])
        return text


def image_copy(container, source, destination, expected_size):
    bounded_capture(['docker', 'cp', '-L', container + ':' + source, str(destination)], destination.parent)
    if not destination.is_file() or destination.is_symlink() or destination.stat().st_size != expected_size:
        raise RuntimeError('Official fixture file differs from its image size admission')


def write_launcher(path, tool, loader):
    if not re.fullmatch(r'[a-z0-9_-]+', tool) or not re.fullmatch(r'ld[-a-zA-Z0-9_.]+', loader):
        raise ValueError('Unexpected fixture executable name')
    libraries = sorted(item.name for item in (path.parent / 'lib').iterdir() if item.is_file())
    if len(libraries) > 256 or any(not re.fullmatch(r'[a-zA-Z0-9_.+-]+', name) for name in libraries):
        raise ValueError('Unexpected fixture library name or count')
    objects = ':'.join(['', '$fixture_dir/upstream/' + tool, tool,
                        *['$fixture_dir/lib/' + name for name in libraries], *libraries])
    if len(objects) > 65536:
        raise ValueError('Fixture loader object list exceeds 64KiB')
    # Pin the physical generation before exec, independent of later publication.
    # Include the executable and private libraries in the documented object-name
    # list, so an upstream RPATH cannot select an unrelated host/desktop library.
    path.write_text('#!/bin/sh\nset -eu\n'
                    'fixture_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)\n'
                    'exec "$fixture_dir/lib/' + loader + '" --inhibit-cache '
                    '--inhibit-rpath "' + objects + '" '
                    '--library-path "$fixture_dir/lib" '
                    '"$fixture_dir/upstream/' + tool + '" "$@"\n')
    path.chmod(0o755)


def populate_generation(target):
    records, admitted_bytes, admitted_files = [], 0, 0
    for engine, (image, tools) in CLIENTS.items():
        bounded_capture(['docker', 'pull', image], target, timeout=300)
        inspected = bounded_capture(['docker', 'image', 'inspect', image], target)
        identity = json.loads(inspected)[0]
        image_id = identity['Id']
        if not re.fullmatch(r'sha256:[0-9a-f]{64}', image_id):
            raise RuntimeError('Official fixture image identity is malformed')
        container = bounded_capture(['docker', 'create', '--read-only', '--entrypoint', '/bin/true', image_id], target).strip()
        if not re.fullmatch(r'[0-9a-f]{64}', container):
            raise RuntimeError('Owned fixture container identity is malformed')
        try:
            libraries, loader = {}, None
            for source in tools.values():
                dependencies = bounded_capture(['docker', 'run', '--rm', '--entrypoint', '/usr/bin/ldd', image_id, source], target)
                paths = sorted(set(re.findall(r'(?:=>\s+)?(/[^\s]+)', dependencies)))
                if not paths or len(paths) > 256:
                    raise RuntimeError('Unexpected fixture library inventory')
                for remote in paths:
                    name = PurePosixPath(remote).name
                    previous = libraries.get(name)
                    if previous is not None and previous != remote:
                        raise RuntimeError('Ambiguous fixture library: ' + name)
                    libraries[name] = remote
                    if name.startswith('ld-linux'):
                        if loader is not None and loader != name:
                            raise RuntimeError('Ambiguous image loader')
                        loader = name
            if loader is None:
                raise RuntimeError('Image loader is missing')
            paths = sorted(set(tools.values()) | set(libraries.values()))
            sizes_text = bounded_capture(['docker', 'run', '--rm', '--entrypoint', '/usr/bin/stat', image_id,
                                          '--dereference', '--format=%s', '--', *paths], target, limit=16384)
            sizes = sizes_text.splitlines()
            if len(sizes) != len(paths) or any(not re.fullmatch(r'[0-9]{1,12}', value) for value in sizes):
                raise RuntimeError('Official image file-size admission is unavailable')
            sizes = dict(zip(paths, map(int, sizes)))
            admitted_bytes += sum(sizes.values()) + len(tools) * 128 * 1024
            admitted_files += len(paths) + len(tools)
            if admitted_bytes > MAX_GENERATION_BYTES or admitted_files > MAX_FILES:
                raise RuntimeError('Official fixture image files exceed generation admission before copying')
            directory = target / engine
            lib, upstream = directory / 'lib', directory / 'upstream'
            lib.mkdir(parents=True)
            upstream.mkdir()
            for name, remote in libraries.items():
                image_copy(container, remote, lib / name, sizes[remote])
            runtime = [{'path': str((lib / name).relative_to(target)), 'source': remote,
                        'sha256': checksum(lib / name)} for name, remote in sorted(libraries.items())]
            for tool, source in tools.items():
                binary = upstream / tool
                image_copy(container, source, binary, sizes[source])
                before = checksum(binary)
                launcher = directory / tool
                write_launcher(launcher, tool, loader)
                # Version discovery is independent of any host preload. The
                # launcher itself preserves Java's reviewed SSH transport preload.
                environment = dict(os.environ)
                environment.pop('LD_PRELOAD', None)
                version = bounded_capture([str(launcher), '--version'], target, limit=4096, timeout=15, env=environment).strip()
                release = image.split(':', 1)[1].split('-', 1)[0]
                if not re.search(r'(?<![0-9.])' + re.escape(release) + r'(?![0-9.])', version):
                    raise RuntimeError('Fixture does not report its exact pinned release')
                if before != checksum(binary):
                    raise RuntimeError('Fixture client bytes changed')
                records.append({
                    'engine': engine, 'image': image, 'imageId': image_id,
                    'repositoryDigests': identity.get('RepoDigests', []),
                    'imageArchitecture': identity.get('Architecture'), 'imageOs': identity.get('Os'),
                    'tool': tool, 'version': version.replace(str(binary), tool),
                    'launcher': str(launcher.relative_to(target)), 'loader': loader,
                    'upstreamBinary': str(binary.relative_to(target)),
                    'upstreamBinarySha256': before, 'upstreamBinaryModified': False, 'runtime': runtime,
                })
        finally:
            bounded_capture(['docker', 'rm', container], target)
    return records


def file_inventory(directory):
    files, total, entries = [], 0, 0
    for path in directory.rglob('*'):
        entries += 1
        if entries > MAX_FILES * 2:
            raise RuntimeError('Fixture directory entry budget exceeded')
        if path.is_symlink():
            raise RuntimeError('Fixture generation must not contain symlinks')
        if not path.is_file() or path == directory / 'fixture-tools.json':
            continue
        size = path.stat().st_size
        total += size
        if len(files) >= MAX_FILES or total > MAX_GENERATION_BYTES:
            raise RuntimeError('Fixture generation exceeds its file/byte budget')
        files.append({'path': path.relative_to(directory).as_posix(), 'bytes': size, 'sha256': checksum(path)})
    return sorted(files, key=lambda item: item['path'])


def validate_assets(directory, manifest):
    if manifest.get('format') != FORMAT or manifest.get('upstreamBinaryModified') is not False:
        raise RuntimeError('Unsupported fixture generation provenance')
    if manifest.get('files') != file_inventory(directory):
        raise RuntimeError('Fixture generation assets changed after preparation')
    records = manifest.get('clients', [])
    expected = {(engine, tool) for engine, (_, tools) in CLIENTS.items() for tool in tools}
    if len(records) != len(expected) or {(r['engine'], r['tool']) for r in records} != expected:
        raise RuntimeError('Fixture generation client inventory is incomplete')
    files = {item['path']: item for item in manifest['files']}
    for record in records:
        engine, tool = record['engine'], record['tool']
        if (record.get('image') != CLIENTS[engine][0] or record.get('upstreamBinaryModified') is not False
                or record.get('launcher') != engine + '/' + tool
                or record.get('upstreamBinary') != engine + '/upstream/' + tool
                or files.get(record['upstreamBinary'], {}).get('sha256') != record.get('upstreamBinarySha256')):
            raise RuntimeError('Fixture client provenance does not match its assets')
        if not os.access(directory / record['launcher'], os.X_OK):
            raise RuntimeError('Fixture launcher is not executable')
        for item in record.get('runtime', []):
            if files.get(item['path'], {}).get('sha256') != item.get('sha256'):
                raise RuntimeError('Fixture runtime provenance does not match its assets')
    return manifest


def validate_generation(directory):
    path = directory / 'fixture-tools.json'
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 1024 * 1024:
        raise RuntimeError('Fixture generation manifest is unavailable')
    raw = path.read_bytes()
    if directory.name != 'generation-' + hashlib.sha256(raw).hexdigest():
        raise RuntimeError('Fixture generation identity does not match its manifest')
    return validate_assets(directory, json.loads(raw))


def check_public_target(target, generations):
    if not os.path.lexists(target):
        return
    if not target.is_symlink():
        raise RuntimeError('Existing unmanaged native-tools tree was preserved; select a fresh --output or review and move it explicitly after its users finish')
    resolved = target.resolve(strict=True)
    if resolved.parent != generations or not resolved.is_dir():
        raise RuntimeError('Existing fixture pointer is outside its owned generation store')
    validate_generation(resolved)


def check_admission(generations):
    count, total, entries, files = 0, 0, 0, 0
    for path in generations.iterdir():
        if path.name in ('.owner.json', '.lock'):
            continue
        if path.is_symlink() or not path.is_dir() or not re.fullmatch(r'(generation-[0-9a-f]{64}|\.building-[a-zA-Z0-9_-]+)', path.name):
            raise RuntimeError('Unrecognized entry in owned fixture generation store')
        count += 1
        if count > MAX_GENERATIONS:
            raise RuntimeError('Fixture generation entry limit exceeded')
        for item in path.rglob('*'):
            entries += 1
            if entries > MAX_FILES * MAX_GENERATIONS * 2:
                raise RuntimeError('Fixture store directory entry limit exceeded')
            if item.is_symlink():
                raise RuntimeError('Unrecognized symlink in owned fixture store')
            if item.is_file():
                total += item.stat().st_size
                files += 1
                if files > MAX_FILES * MAX_GENERATIONS or total > MAX_CACHE_BYTES:
                    raise RuntimeError('Fixture store file/byte admission exceeded')
    if count >= MAX_GENERATIONS or total + MAX_GENERATION_BYTES + 1024 * 1024 > MAX_CACHE_BYTES:
        raise RuntimeError('Fixture storage limit reached; preserve in-use generations and review cleanup explicitly')


def freeze_generation(directory):
    for path in directory.rglob('*'):
        if path.is_file():
            path.chmod(0o555 if os.access(path, os.X_OK) else 0o444)
    for path in sorted((p for p in directory.rglob('*') if p.is_dir()), key=lambda p: len(p.parts), reverse=True):
        path.chmod(0o555)
    directory.chmod(0o555)


def remove_unpublished(directory):
    # This is always a newly created, never-published staging tree.
    for path in directory.rglob('*'):
        if path.is_dir():
            path.chmod(0o700)
    directory.chmod(0o700)
    shutil.rmtree(directory)


def prepare(target):
    if sys.platform != 'linux':
        raise RuntimeError('Official ELF fixture preparation requires a Linux host')
    import fcntl
    target = Path(os.path.abspath(target))
    target.parent.mkdir(parents=True, exist_ok=True)
    target = target.parent.resolve() / target.name  # Never resolve the final public pointer.
    generations = target.parent / (target.name + '.generations')
    if generations.is_symlink():
        raise RuntimeError('Fixture generation store must be an owned real directory')
    owner = {'format': FORMAT, 'owner': 'busydata-native-fixture-generations', 'target': str(target)}
    if not generations.exists():
        generations.mkdir(mode=0o700)
        (generations / '.owner.json').write_text(json.dumps(owner, sort_keys=True) + '\n')
    else:
        ownership = generations / '.owner.json'
        if ownership.is_symlink() or not ownership.is_file() or ownership.stat().st_size > 4096 or json.loads(ownership.read_text()) != owner:
            raise RuntimeError('Existing fixture generation store ownership is unavailable')
    descriptor = os.open(generations / '.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'r+') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as busy:
            raise RuntimeError('Another fixture preparation owns this output; wait for it explicitly') from busy
        check_public_target(target, generations)
        check_admission(generations)
        staging = Path(tempfile.mkdtemp(prefix='.building-', dir=generations))
        temporary = target.parent / ('.' + target.name + '.publish-' + uuid.uuid4().hex)
        try:
            clients = populate_generation(staging)
            manifest = {'format': FORMAT, 'preparationId': uuid.uuid4().hex,
                        'preparerSha256': checksum(Path(__file__)),
                        'preparedUnixNs': time.time_ns(), 'upstreamBinaryModified': False,
                        'clients': clients, 'files': file_inventory(staging)}
            raw = (json.dumps(manifest, sort_keys=True, indent=2) + '\n').encode()
            if len(raw) > 1024 * 1024:
                raise RuntimeError('Fixture provenance manifest exceeds 1MiB')
            (staging / 'fixture-tools.json').write_bytes(raw)
            validate_assets(staging, manifest)
            published = generations / ('generation-' + hashlib.sha256(raw).hexdigest())
            staging.rename(published)
            staging = None  # Complete generations are never deleted after this point.
            validate_generation(published)
            freeze_generation(published)
            temporary.symlink_to(os.path.relpath(published, target.parent), target_is_directory=True)
            os.replace(temporary, target)
            return target / 'fixture-tools.json'
        finally:
            temporary.unlink(missing_ok=True)
            if staging is not None:
                remove_unpublished(staging)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT / 'backend/target/native-tools')
    args = parser.parse_args()
    print(prepare(args.output))


if __name__ == '__main__':
    main()
