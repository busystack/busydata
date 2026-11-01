#!/usr/bin/env python3
"""Inventory the actual primed Snap and versioned stage-package license receipts.
Run after Snapcraft pack with SNAPCRAFT_BUILD_INFO=1. No declared dependency list
is substituted for the generated package manifest or its actual files.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
from verify_native_clients import verify as verify_clients


def checksum(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()


def receipts(prime, manifest):
    packages = {}
    parts = manifest.get('parts')
    if not isinstance(parts, dict) or not parts:
        raise RuntimeError('Actual Snap build manifest has no part receipts')
    for part, record in parts.items():
        for entry in record.get('stage-packages', []):
            name, separator, version = entry.partition('=')
            if not separator or not version or not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*(?::[a-z0-9]+)?', name):
                raise RuntimeError('Stage package lacks its actual name/version receipt')
            if name in packages and packages[name]['version'] != version:
                raise RuntimeError('Conflicting versions for one staged package')
            path = prime / 'backend/notices/ubuntu-stage' / name.split(':')[0] / 'copyright'
            if not path.is_file():
                path = prime / 'usr/share/doc' / name.split(':')[0] / 'copyright'
            if not path.is_file() or not path.resolve().is_relative_to(prime.resolve()):
                raise RuntimeError('Missing or external staged-package license: ' + name)
            packages.setdefault(name, {'name': name, 'version': version, 'parts': [],
                'licensePath': path.relative_to(prime).as_posix(), 'licenseSha256': checksum(path)})['parts'].append(part)
            if len(packages) > 2000:
                raise RuntimeError('Staged-package inventory admission limit')
    if not packages:
        raise RuntimeError('No actual staged-package inventory')
    return sorted(packages.values(), key=lambda entry: entry['name'])


def inventory(prime):
    import yaml  # Snap inspection only; Windows/native checks do not need this parser.
    manifest = prime / 'snap/manifest.yaml'
    if not manifest.is_file() or manifest.stat().st_size > 2 * 1024 * 1024:
        raise RuntimeError('Missing/oversized actual Snap manifest; enable SNAPCRAFT_BUILD_INFO=1')
    value = yaml.safe_load(manifest.read_bytes())
    packages = receipts(prime, value)
    files, total = [], 0
    for path in sorted(prime.rglob('*')):
        relative = path.relative_to(prime).as_posix()
        if path.is_symlink():
            files.append({'path': relative, 'linkTarget': path.readlink().as_posix()})
        elif path.is_file():
            size = path.stat().st_size
            total += size
            if total > 12 * 1024 ** 3:
                raise RuntimeError('Package file inventory byte limit')
            files.append({'path': relative, 'bytes': size, 'sha256': checksum(path)})
        if len(files) > 25000:
            raise RuntimeError('Package file inventory count limit')
    dependency = prime / 'backend/dependency-inventory.json'
    bom = prime / 'backend/bom.json'
    if not dependency.is_file() or not bom.is_file():
        raise RuntimeError('Prepared Flutter/runtime inventory or Java CycloneDX SBOM missing')
    return {'version': 1, 'distributionInventoryComplete': True,
            'snapManifestSha256': checksum(manifest), 'yamlParserVersion': yaml.__version__,
            'stagePackages': packages, 'nativeClients': verify_clients(prime),
            'dependencyInventorySha256': checksum(dependency), 'javaSbomSha256': checksum(bom),
            'buildManifest': value, 'files': files, 'fileBytes': total,
            'legalApproval': False,
            'scope': 'Actual primed files and retained licenses; runtime content snaps remain separately managed dependencies recorded in the Snap manifest'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prime', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = inventory(args.prime.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(args.output)


if __name__ == '__main__':
    main()
