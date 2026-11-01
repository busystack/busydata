#!/usr/bin/env python3
"""Verify exact relocated package clients and retained corresponding source."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
CLIENTS = {'postgresql': ('pg_dump', 'psql'), 'mysql': ('mysql', 'mysqldump'),
           'mariadb': ('mariadb', 'mariadb-dump')}

def checksum(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def verify(root):
    manifest = json.loads((ROOT / 'third_party/native_client_sources.json').read_text())
    reports = []
    for source in manifest:
        engine = source['engine']
        directory = root / 'backend/tools' / engine
        build = json.loads((directory / 'native-client-build.json').read_text())
        if build['source'] != source or not build['sourceIncluded'] or build['serverBuilt']:
            raise RuntimeError('Native client source/build identity mismatch: ' + engine)
        if build.get('upstreamSourceModified') is not False or build.get('postLinkBinaryModified') is not False:
            raise RuntimeError('Native clients require unmodified upstream source and build output: ' + engine)
        if checksum(directory / 'sources' / source['name']) != source['sha256']:
            raise RuntimeError('Corresponding source mismatch: ' + engine)
        for record in build['files']:
            name = record['path']
            if Path(name).is_absolute() or '..' in Path(name).parts:
                raise RuntimeError('Invalid native build inventory path')
            if checksum(directory / name) != record['sha256']:
                raise RuntimeError('Native client file changed: ' + engine + '/' + name)
        version = source['name'].split('-', 1)[1].split('.tar')[0]
        actual = {}
        for name in CLIENTS[engine]:
            tool = directory / 'bin' / name
            banner = subprocess.run([str(tool), '--version'], check=True, capture_output=True,
                                    text=True, timeout=15).stdout.strip()
            if version not in banner:
                raise RuntimeError('Pinned native client version mismatch: ' + name)
            actual[name] = {'versionOutput': banner, 'sha256': checksum(tool)}
        reports.append({'engine': engine, 'source': source, 'clients': actual,
                        'buildRecordSha256': checksum(directory / 'native-client-build.json')})
    return {'version': 1, 'passed': True, 'packageRoot': str(root), 'nativeClients': reports}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.root.resolve())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(args.output)

if __name__ == '__main__':
    main()
