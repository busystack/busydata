#!/usr/bin/env python3
"""Reject stale/mixed dump-plugin payloads before a local Snap can be packed."""
import argparse
import hashlib
import json
from pathlib import Path
from public_bundle_permissions import validate_public_payload_paths


def checksum(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def verify(source, prime):
    source, prime = Path(source).resolve(), Path(prime).resolve()
    if source == prime or not source.is_dir() or not prime.is_dir():
        raise ValueError('Distinct existing source and prime directories required')
    required = ['busydata', 'lib/libapp.so', 'backend/runtime/bin/java',
                'backend/dependency-inventory.json', 'backend/build-info.json']
    jars = sorted((source / 'backend/lib').glob('*.jar'))
    if not jars or len(jars) > 128:
        raise ValueError('Missing or oversized verified backend JAR catalog')
    if {p.name for p in jars} != {p.name for p in (prime / 'backend/lib').glob('*.jar')}:
        raise ValueError('Primed backend JAR catalog differs from current source')
    required.extend(str(p.relative_to(source)) for p in jars)
    manifest = 'installed-acceptance-build.json'
    if (source / manifest).exists() != (prime / manifest).exists():
        raise ValueError('Stale or missing private acceptance manifest in primed payload')
    if (source / manifest).exists():
        required.append(manifest)
    hashes = {}
    for name in required:
        original, staged = source / name, prime / name
        if original.is_symlink() or staged.is_symlink() or not original.is_file() or not staged.is_file():
            raise ValueError('Missing or indirect required payload file: ' + name)
        if original.stat().st_size != staged.stat().st_size or checksum(original) != checksum(staged):
            raise ValueError('Primed payload differs from current source: ' + name)
        if (original.stat().st_mode & 0o111) != (staged.stat().st_mode & 0o111):
            raise ValueError('Primed executable permissions differ: ' + name)
        if name in ('busydata', 'backend/runtime/bin/java') and any(
                (path.stat().st_mode & 0o555) != 0o555 for path in (original, staged)):
            raise ValueError('Required runtime executable is not publicly readable and executable: ' + name)
        hashes[name] = checksum(staged)
    # Build/root ownership must not hide inaccessible payload directories. This
    # read-only policy accepts foreign-owned primes and never repairs artifacts.
    permissions = {key: validate_public_payload_paths(root, required)
                   for key, root in (('source', source), ('prime', prime))}
    return {'version': 1, 'payloadMatchesSource': True, 'files': hashes,
            'publicPermissions': permissions,
            'privateAcceptanceEntrypoint': (source / manifest).exists()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--prime', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    record = verify(args.source, args.prime)
    args.output.write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    main()
