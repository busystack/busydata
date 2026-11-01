#!/usr/bin/env python3
"""Retain actual Ubuntu stage copyrights before GNOME removes duplicate files."""
import argparse
import hashlib
import json
from pathlib import Path


def preserve(stage, prime):
    stage = stage.resolve()
    destination = prime / 'backend/notices/ubuntu-stage'
    records, total = [], 0
    for package in sorted((stage / 'usr/share/doc').iterdir()):
        license = package / 'copyright'
        if not license.is_file():
            continue
        resolved = license.resolve()
        if len(records) >= 2000 or not resolved.is_relative_to(stage):
            raise RuntimeError('Stage license admission/path limit')
        size = resolved.stat().st_size
        total += size
        if size > 2 * 1024 ** 2 or total > 16 * 1024 ** 2:
            raise RuntimeError('Stage license byte budget')
        with resolved.open('rb') as source:
            data = source.read(size + 1)
        if len(data) != size:
            raise RuntimeError('Stage license changed during retention')
        output = destination / package.name / 'copyright'
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(data)
        records.append({'package': package.name, 'path': output.relative_to(prime).as_posix(),
                        'bytes': size, 'sha256': hashlib.sha256(data).hexdigest()})
    if not records:
        raise RuntimeError('Actual staged copyrights unavailable')
    (destination / 'licenses.json').write_text(json.dumps({'version': 1, 'packages': records}, indent=2) + '\n')
    return records


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stage', type=Path, required=True)
    parser.add_argument('--prime', type=Path, required=True)
    args = parser.parse_args()
    preserve(args.stage, args.prime)
