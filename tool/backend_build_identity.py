"""Require the packaged JVM classes to match current source, not just their mtime."""
import hashlib
import json
from pathlib import Path
import zipfile
from verification_evidence import ROOT, source_hash


def backend_source_hash(root=ROOT):
    return source_hash(root)


def verify_jar(jar, root=ROOT):
    with zipfile.ZipFile(jar) as archive:
        metadata = archive.getinfo('busydata-build-identity.json')
        if metadata.file_size > 4096:
            raise RuntimeError('Backend source identity is too large')
        identity = json.loads(archive.read(metadata))
    if (identity.get('version') != 2 or identity.get('backendSourceSha256') != backend_source_hash(root)
            or identity.get('buildSourceSha256') != source_hash(root)):
        raise RuntimeError('Backend artifact is stale; run Maven verify and rebuild the runtime bundle')
    return identity


def verify_bundle(root=ROOT):
    jar = root / 'backend/target/bundle/lib/busydata-backend-0.1.0.jar'
    identity = verify_jar(jar, root)
    target = root / 'backend/target/busydata-backend-0.1.0.jar'
    with jar.open('rb') as stream:
        bundled = hashlib.file_digest(stream, 'sha256').digest()
    with target.open('rb') as stream:
        current = hashlib.file_digest(stream, 'sha256').digest()
    if bundled != current:
        raise RuntimeError('Backend bundle differs from the current Maven artifact; run tool/bundle_backend.py')
    return identity
