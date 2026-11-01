#!/usr/bin/env python3
"""Verify a downloaded source ZIP against the source hash in independent evidence."""
import argparse
import json
from pathlib import Path

from canonical_source import load_manifest, manifest_hash, verify_archive


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--archive', type=Path, required=True)
    parser.add_argument('--expected-source-sha256', required=True,
                        help='buildSourceSha256 from the independently obtained verification record')
    args = parser.parse_args()
    manifest = load_manifest(args.manifest)
    if manifest_hash(manifest) != args.expected_source_sha256:
        raise ValueError('Canonical manifest does not match the independent evidence source identity')
    print(json.dumps(verify_archive(args.archive, manifest), indent=2))


if __name__ == '__main__':
    main()
