#!/usr/bin/env python3
"""Package the actual comparison images, source identities and run receipts.

This does not create acceptance claims. The verification summary must describe
the runs, including failures and unavailable native gates, before packaging.
"""
import argparse
import base64
import hashlib
import html
from html.parser import HTMLParser
import json
import mimetypes
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit
import zipfile


class Links(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.targets = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        self.targets.extend(value for key, value in attrs
                            if key in ('src', 'href') and value)


def local_target(base, url, root):
    parsed = urlsplit(html.unescape(url))
    if parsed.scheme or parsed.netloc or not parsed.path:
        return None
    target = (base / unquote(parsed.path)).resolve()
    if not target.is_relative_to(root):
        raise ValueError(f'Comparison link escapes evidence root: {url}')
    if not target.is_file():
        raise ValueError(f'Missing comparison dependency: {url}')
    return target


def package(evidence, archive, standalone, receipts=()):
    root = evidence.resolve(strict=True)
    index = root / 'gallery/index.html'
    text = index.read_text()
    files = {index}
    for name in ('gallery/images.json', 'gallery-source-identity.json',
                 'baseline-source-identity.json', 'verification-summary.json'):
        path = root / name
        if not path.is_file():
            raise ValueError(f'Missing evidence: {name}')
        files.add(path)
    for path in (root / 'gallery').rglob('*'):
        if path.is_file():
            if path.is_symlink():
                raise ValueError(f'Symlink in gallery: {path}')
            files.add(path)
    images = json.loads((root / 'gallery/images.json').read_text())['images']
    for record in images:
        image = local_target(root / 'gallery', record['path'], root)
        if image is None or hashlib.sha256(image.read_bytes()).hexdigest() != record['sha256']:
            raise ValueError(f'Image does not match its source-bound manifest: {record["path"]}')
        files.add(image)
    for path in receipts:
        path = path.resolve(strict=True)
        if not path.is_relative_to(root):
            raise ValueError(f'Receipt must be inside evidence root: {path}')
        for candidate in path.rglob('*') if path.is_dir() else (path,):
            if candidate.is_symlink():
                raise ValueError(f'Symlink in receipts: {candidate}')
            if candidate.is_file():
                files.add(candidate)
    # Follow HTML dependencies transitively, retaining their directory layout.
    inspected = set()
    while pending := [file for file in files - inspected if file.suffix == '.html']:
        for page in pending:
            inspected.add(page)
            for url in Links(page.read_text()).targets:
                target = local_target(page.parent, url, root)
                if target is not None:
                    files.add(target)
    manifest = {
        'kind': 'Portable rendering comparison and actual verification receipts; not native acceptance',
        'index': 'gallery/index.html', 'imageCount': len(images),
        'files': {str(path.relative_to(root)): {
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size,
        } for path in sorted(files)},
    }
    archive.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as bundle:
        for path in sorted(files):
            bundle.write(path, str(path.relative_to(root)))
        bundle.writestr('bundle-manifest.json', json.dumps(manifest, indent=2) + '\n')
        bundle.writestr('README.txt',
            'Extract the whole archive and open gallery/index.html.\n'
            'Images are unchanged captures; hashes and source identities are included.\n'
            'Read verification-summary.json and receipts for executed and unavailable checks.\n'
            'The gallery does not certify native desktop/database/platform acceptance.\n')

    def embed(match):
        target = local_target(index.parent, match.group(3), root)
        if target is None:
            return match.group(0)
        mime = mimetypes.guess_type(target.name)[0] or 'application/octet-stream'
        payload = base64.b64encode(target.read_bytes()).decode('ascii')
        return f'{match.group(1)}={match.group(2)}data:{mime};base64,{payload}{match.group(2)}'

    embedded = re.sub(r'(src|href)=(\"|\x27)(.*?)\2', embed, text)
    if any(local_target(index.parent, url, root) is not None
           for url in Links(embedded).targets):
        raise ValueError('Standalone HTML still has a local file dependency')
    standalone.parent.mkdir(parents=True, exist_ok=True)
    standalone.write_text(embedded)
    manifest['archiveSha256'] = hashlib.sha256(archive.read_bytes()).hexdigest()
    manifest['standaloneSha256'] = hashlib.sha256(standalone.read_bytes()).hexdigest()
    archive.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--standalone', type=Path, required=True)
    parser.add_argument('--receipt', action='append', type=Path, default=[])
    args = parser.parse_args()
    result = package(args.evidence, args.archive, args.standalone, args.receipt)
    print(json.dumps({'files': len(result['files']), 'images': result['imageCount'],
                      'archiveSha256': result['archiveSha256']}))


if __name__ == '__main__':
    main()
