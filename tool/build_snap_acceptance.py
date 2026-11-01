#!/usr/bin/env python3
"""Build a separate native installed-acceptance bundle; restore the product bundle.
The private test entrypoint is never included in the product release archive.
"""
import hashlib
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import uuid
from backend_build_identity import verify_bundle, verify_jar
from desktop_build_evidence import verify_existing_bundle
from public_bundle_permissions import publish_public_bundle
from verification_evidence import ROOT, source_hash, command_output
from verify_official_dependencies import revalidate_receipt, owned_build_environment


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-pub', action='store_true',
                        help='Use dependencies already verified by a separate locked pub get')
    options = parser.parse_args()
    backend_identity = verify_bundle()
    source = source_hash()
    current = ROOT / 'build/linux/x64/release/bundle'
    product = json.loads((ROOT / 'build/linux-release-build.json').read_text())
    product_hashes = verify_existing_bundle('linux', product, current, source)
    dependency_sources = revalidate_receipt(ROOT)
    environment = owned_build_environment(ROOT)
    output = ROOT / 'build/snap-acceptance' / str(uuid.uuid4())
    output.mkdir(parents=True)
    original = output / 'product-bundle'
    shutil.copytree(current, original, symlinks=True)
    try:
        entrypoint = 'integration_test/installed_snap_linux.dart'
        command = ['flutter', 'build', 'linux', '--release', '-t', entrypoint]
        if options.no_pub:
            command.append('--no-pub')
        subprocess.run(command, cwd=ROOT, check=True, env=environment)
        if source_hash() != source:
            raise RuntimeError('Source changed while building installed acceptance')
        if revalidate_receipt(ROOT) != dependency_sources:
            raise RuntimeError('Official dependency proof changed while building installed acceptance')
        if verify_jar(current / 'backend/lib/busydata-backend-0.1.0.jar') != backend_identity:
            raise RuntimeError('Acceptance build copied a different backend source identity')
        hashes = {}
        for name in ['busydata', 'lib/libapp.so', 'backend/lib/busydata-backend-0.1.0.jar', 'backend/runtime/bin/java']:
            with (current / name).open('rb') as stream:
                hashes[name] = hashlib.file_digest(stream, 'sha256').hexdigest()
        manifest = {'version': 1, 'sourceSha256': source, 'entrypoint': entrypoint,
                    'productBuildId': product['buildId'], 'productArtifactHashes': product_hashes,
                    'officialDependencySources': dependency_sources,
                    'command': command, 'backendSourceIdentity': backend_identity, 'flutter': command_output(['flutter', '--version', '--machine']),
                    'artifacts': hashes}
        (current / 'installed-acceptance-build.json').write_text(json.dumps(manifest, indent=2) + '\n')
        publish_public_bundle(current)
        archive = ROOT / 'build/busydata-installed-acceptance.tar.gz'
        with tarfile.open(archive, 'w:gz') as target:
            target.add(current, arcname='bundle')
        with archive.open('rb') as stream:
            manifest['archiveSha256'] = hashlib.file_digest(stream, 'sha256').hexdigest()
        (ROOT / 'build/snap-acceptance-build.json').write_text(json.dumps(manifest, indent=2) + '\n')
        print(archive)
    finally:
        shutil.rmtree(current)  # Generated bundle only; never application data.
        shutil.copytree(original, current, symlinks=True)
        verify_existing_bundle('linux', product, current, source)


if __name__ == '__main__':
    main()
