#!/usr/bin/env python3
"""Finalize a current-run record. Old loose logs never satisfy acceptance."""
import argparse
from verification_evidence import ROOT
from package_verification_evidence import finish_with_archive

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--required', nargs='+', default=[
    'toolchain', 'flutter-dependencies', 'official-dependencies', 'localizations', 'java', 'protocol',
    'format', 'analyze', 'boundaries', 'flutter-tests', 'database-matrix',
    'runtime', 'sources', 'inventory', 'lifecycle', 'linux-release',
    'gtk-icons', 'linux-close', 'database-desktop', 'release-performance',
    'native-accessibility',
    'large-transfers', 'native-backup', 'installed-snap', 'windows-native', 'msix',
])
args = parser.parse_args()
record = finish_with_archive(args.required)
print(ROOT / 'build/verification-evidence.json')
for kind in ('manifest', 'archive'):
    item = record['sourceSnapshot'][kind]
    print('Canonical source ' + kind + ': ' + item['file'] + ' SHA-256 ' + item['sha256'])
for failure in record['acceptanceFailures']:
    print(failure)
raise SystemExit(0 if record['acceptancePassed'] else 1)
