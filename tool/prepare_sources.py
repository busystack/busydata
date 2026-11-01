#!/usr/bin/env python3
"""Fetch and verify full corresponding source archives; never publish artifacts."""
import hashlib, json, pathlib, urllib.request
root = pathlib.Path(__file__).resolve().parents[1]
destination = root / 'backend/target/bundle/sources'
destination.mkdir(parents=True, exist_ok=True)
manifest = root / 'third_party/source_archives.json'
for archive in json.loads(manifest.read_text()):
    target = destination / archive['name']
    def checksum(file):
        with file.open('rb') as data:
            return hashlib.file_digest(data, 'sha256').hexdigest()
    if not target.exists() or checksum(target) != archive['sha256']:
        partial = target.with_suffix(target.suffix + '.partial')
        try:
            with urllib.request.urlopen(archive['url'], timeout=120) as remote, partial.open('wb') as output:
                while chunk := remote.read(65536): output.write(chunk)
            if checksum(partial) != archive['sha256']: raise RuntimeError('Source checksum mismatch: ' + archive['name'])
            partial.replace(target)
        finally:
            partial.unlink(missing_ok=True)
    print('Verified source:', archive['name'])
(destination / 'source_archives.json').write_text(manifest.read_text())
