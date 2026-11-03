#!/usr/bin/env python3
"""Attest the reviewed publisher package catalog and official Flutter SDK.

Read-only: does not repair the pub cache, edit upstream files, resolve packages,
or accept a version string as proof of unchanged source. The JSON manifest is
generated from checksum-verified publisher archives when an upgrade is reviewed.
The complete locked graph and packaging receipt belong to
verify_official_dependencies; this catalog supplements that single authority.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import fnmatch
import re
import subprocess
import sys
from urllib.parse import unquote, urlparse
from urllib.request import url2pathname

MAX_MANIFEST_BYTES = 2 * 1024 * 1024
MAX_CATALOG_FILES = 20000


def document(path, limit=MAX_MANIFEST_BYTES):
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.stat().st_size > limit:
        raise ValueError('Publisher attestation input is missing or exceeds its bound')
    return json.loads(path.read_text())


def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def package_root(configuration, value):
    uri = urlparse(value)
    if uri.scheme == 'file':
        if uri.netloc not in ('', 'localhost'):
            raise ValueError('Package root must be local')
        return Path(url2pathname(uri.path)).resolve()
    if uri.scheme or uri.netloc or uri.query or uri.fragment:
        raise ValueError('Unsupported resolved package root')
    return (configuration.parent / unquote(uri.path)).resolve()


def verify_sdk(root, expected, host=None, artifact_inputs=None):
    root = Path(root).resolve()
    host = host or sys.platform
    if host not in expected['artifacts']:
        raise ValueError('No reviewed official SDK artifact catalog for this host')
    version = document(root / 'bin/cache/flutter.version.json', 1048576)
    if any(version.get(key) != value for key, value in expected['identity'].items()):
        raise ValueError('Flutter/Dart identity differs from the approved official toolchain')
    environment = {key: value for key, value in os.environ.items() if not key.startswith('GIT_')}
    command = ['git', '--no-optional-locks', '--no-replace-objects', '-c', 'core.fsmonitor=false',
               '-c', 'core.hooksPath=' + os.devnull, '-C', str(root)]
    head = subprocess.check_output([*command, 'rev-parse', 'HEAD'], env=environment, text=True, timeout=30).strip()
    if head != expected['identity']['frameworkRevision']:
        raise ValueError('Flutter framework is not the approved upstream revision')
    entries = subprocess.check_output([*command, 'ls-tree', '-rz', '--full-tree', 'HEAD'], env=environment, timeout=30)
    source_tree = expected.get('sourceTrees', {}).get(host)
    if host == 'win32' and source_tree is None:
        raise ValueError('No reviewed official Windows SDK source archive identity')
    if source_tree is not None and (not isinstance(source_tree, dict) or
            type(source_tree.get('files')) is not int or not 1 <= source_tree['files'] <= 100000 or
            not re.fullmatch('[0-9a-f]{64}', str(source_tree.get('sha256', '')))):
        raise ValueError('Invalid official SDK source archive identity')
    raw_sources = []
    crlf = ('*.bat', '*.ps1', '*.rc', '*.sln', '*.props', '*.vcxproj',
            '*.vcxproj.filters', '*.sln.tmpl', '*.props.tmpl', '*.vcxproj.tmpl')
    for entry in entries.split(b'\0'):
        if not entry: continue
        metadata, relative = entry.split(b'\t', 1)
        mode, kind, object_id = metadata.split()
        path = root / os.fsdecode(relative)
        if kind != b'blob' or mode not in (b'100644', b'100755', b'120000'):
            raise ValueError('Unsupported official SDK source entry')
        if mode == b'120000':
            if path.is_symlink():
                content = os.fsencode(os.readlink(path))
            elif source_tree is not None and path.is_file():
                # The official Windows ZIP stores Git link targets as files.
                # The full raw publisher source digest below binds that form.
                content = path.read_bytes()
            else:
                raise ValueError('Flutter SDK source link was replaced')
        else:
            if path.is_symlink() or not path.is_file(): raise ValueError('Flutter SDK source is missing or substituted')
            if os.name != 'nt' and bool(path.stat().st_mode & 0o111) != (mode == b'100755'):
                raise ValueError('Flutter SDK source mode was modified')
            content = path.read_bytes()
        if source_tree is not None:
            raw_sources.append([os.fsdecode(relative), mode.decode('ascii'), len(content),
                                hashlib.sha256(content).hexdigest()])
        digest = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
        if digest.encode() != object_id and mode != b'120000' and content.count(b'\n') == content.count(b'\r\n') and (
                source_tree is not None or any(fnmatch.fnmatchcase(os.fsdecode(relative), pattern) for pattern in crlf)):
            content = content.replace(b'\r\n', b'\n')
            digest = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
        if digest.encode() != object_id:
            raise ValueError('Flutter SDK contains source modifications')
    if source_tree is not None:
        raw_manifest = json.dumps(raw_sources, ensure_ascii=False, separators=(',', ':')).encode('utf-8')
        if len(raw_sources) != source_tree['files'] or hashlib.sha256(raw_manifest).hexdigest() != source_tree['sha256']:
            raise ValueError('Flutter SDK differs from the official source archive bytes')
    verified = 0
    for artifact in expected['artifacts'][host]:
        directory = PurePosixPath(artifact['directory'])
        if directory.is_absolute() or '..' in directory.parts:
            raise ValueError('Invalid SDK artifact directory')
        parent = root.joinpath(*directory.parts)
        # A mode not yet precached has no executable input to attest. Recheck
        # after Flutter has acquired/build-used it; existing inputs never skip.
        if not parent.exists():
            if artifact.get('required'): raise ValueError('Official Dart SDK is missing')
            continue
        for relative, digest in artifact['files'].items():
            path = PurePosixPath(relative)
            if path.is_absolute() or '..' in path.parts:
                raise ValueError('Invalid SDK artifact path')
            actual = parent.joinpath(*path.parts)
            if not actual.exists() and not actual.is_symlink() and not artifact.get('required'):
                continue
            approved = digest if isinstance(digest, list) else [digest]
            if not actual.is_file() or actual.is_symlink():
                raise ValueError('Official SDK compiler/runtime missing or modified: ' + relative)
            before = actual.stat()
            actual_digest = sha(actual)
            after = actual.stat()
            if actual_digest not in approved or (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
                raise ValueError('Official SDK compiler/runtime missing or modified: ' + relative)
            if artifact_inputs is not None:
                artifact_inputs[actual.relative_to(root).as_posix()] = actual_digest
            verified += 1
    return verified


def verify(configuration, manifest, locked=None):
    configuration = Path(configuration).resolve()
    packages = document(configuration, 1048576)['packages']
    expected = document(manifest)
    if expected.get('schema') != 1:
        raise ValueError('Unsupported upstream package identity manifest')
    resolved = {}
    for package in packages:
        name = package['name']
        if name in resolved:
            raise ValueError('Duplicate resolved package identity')
        resolved[name] = package_root(configuration, package['rootUri'])
    checked = []
    for record in expected['packages']:
        name, version = record['name'], record['version']
        if not re.fullmatch(r'[a-z][a-z0-9_]*', name) or not re.fullmatch(r'[0-9a-f]{64}', record['archive_sha256']):
            raise ValueError('Invalid pinned publisher identity')
        if record['archive_url'] != f'https://pub.dev/api/archives/{name}-{version}.tar.gz':
            raise ValueError('Publisher package URL differs from its reviewed identity')
        if name not in resolved:
            if record.get('optional'):
                continue
            raise ValueError(f'Required upstream package is unresolved: {name}')
        if locked is not None:
            entry = locked.get(name)
            if entry is None or entry.get('source') != 'hosted' or entry.get('version') != version or entry.get('sha256') != record['archive_sha256']:
                raise ValueError('Reviewed publisher catalog differs from the complete lockfile: ' + name)
        root = resolved[name]
        entries = record['files']
        if not isinstance(entries, dict) or not entries or len(entries) > MAX_CATALOG_FILES:
            raise ValueError('Reviewed publisher file catalog exceeds its bound')
        for relative, digest in entries.items():
            path = PurePosixPath(relative)
            if path.is_absolute() or '..' in path.parts or not relative or '\\' in relative or not re.fullmatch('[0-9a-f]{64}', digest):
                raise ValueError('Publisher path escapes its package')
            actual = root.joinpath(*path.parts)
            if actual.is_symlink() or not actual.is_file() or not actual.resolve().is_relative_to(root):
                raise ValueError(f'Upstream package file missing or substituted: {name}/{relative}')
            if sha(actual) != digest:
                raise ValueError(f'Upstream package source modified: {name}/{relative}')
        # Extra source can alter compilation without changing an archived file.
        # Ignore only root-level tool output, never a similarly named lib path.
        ignored = {'.dart_tool', '.git', 'build', '__pycache__'}
        for parent, directories, files in os.walk(root, followlinks=False):
            parent = Path(parent)
            if parent == root:
                directories[:] = [item for item in directories if item not in ignored]
            for item in [*directories, *files]:
                path = parent / item
                if path.is_symlink():
                    raise ValueError(f'Unreviewed package symlink: {name}/{path.relative_to(root)}')
            for item in files:
                relative = (parent / item).relative_to(root).as_posix()
                if relative not in entries:
                    raise ValueError(f'Unreviewed package source added: {name}/{relative}')
        checked.append({'name': name, 'version': version, 'archive_sha256': record['archive_sha256']})
    return checked


def attest(configuration, manifest, locked):
    """Supplement the full graph with its exact reviewed pins and actual SDK."""
    configuration, manifest = Path(configuration).resolve(), Path(manifest).resolve()
    graph, expected = document(configuration, 1048576), document(manifest)
    flutter = [package for package in graph['packages'] if package['name'] == 'flutter']
    if len(flutter) != 1:
        raise ValueError('Resolved Flutter SDK owner is unavailable or ambiguous')
    sdk = package_root(configuration, flutter[0]['rootUri']).parent.parent
    if package_root(configuration, graph.get('flutterRoot', '')) != sdk:
        raise ValueError('Resolved Flutter package and SDK owner differ')
    inputs = {}
    verified = verify_sdk(sdk, expected['flutter'], artifact_inputs=inputs)
    return {'catalogSha256': sha(manifest), 'verifierSha256': sha(Path(__file__)),
            'sdk': {'root': str(sdk), 'host': sys.platform,
                    'identity': expected['flutter']['identity'],
                    'verifiedArtifactFiles': verified, 'artifactInputs': inputs},
            'reviewedPackages': verify(configuration, manifest, locked)}


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--configuration', type=Path, default=root / '.dart_tool/package_config.json')
    parser.add_argument('--manifest', type=Path, default=root / 'tool/upstream_packages.json')
    parser.add_argument('--sdk', type=Path)
    parser.add_argument('--sdk-only', action='store_true')
    args = parser.parse_args()
    manifest = document(args.manifest)
    sdk = args.sdk
    if args.sdk_only and sdk is None:
        parser.error('--sdk-only requires an explicit --sdk')
    if sdk is None and 'flutter' in manifest:
        configuration = args.configuration.resolve()
        flutter = next((p for p in document(configuration, 1048576)['packages'] if p['name'] == 'flutter'), None)
        if flutter is None: raise ValueError('Resolved Flutter SDK is unavailable')
        sdk = package_root(configuration, flutter['rootUri']).parent.parent
    sdk_files = verify_sdk(sdk, manifest['flutter']) if 'flutter' in manifest else None
    packages = [] if args.sdk_only else verify(args.configuration, args.manifest)
    print(json.dumps({'scope': 'Reviewed publisher subset and SDK; not a complete locked-graph receipt',
                      'verifiedUpstreamPackages': packages, 'verifiedSdkFiles': sdk_files}))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, subprocess.SubprocessError) as failure:
        raise SystemExit('Official dependency integrity check failed: ' + str(failure))
