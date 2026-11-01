#!/usr/bin/env python3
"""Validate retained, current-run real-engine acceptance reports and measurements."""
import argparse
import json
from pathlib import Path
from verification_evidence import ROOT, manifest_path, digest, source_hash


def validate(coverage, root=ROOT):
    manifest = json.loads(manifest_path(root).read_text())
    stage = manifest['stages'].get('database-matrix', {})
    if stage.get('status') != 'passed' or manifest['buildSourceSha256'] != source_hash(root):
        raise ValueError('Coverage requires a passed database matrix for this unchanged source tree')
    reports = {record['name'].rsplit('.', 1)[-1]: record for record in stage.get('reports', [])}
    required = {'LargeTransferIT': 3} if coverage == 'large-transfers' else {'NativeBackupIT': 3, 'NativeBackupTlsIT': 3}
    for name, minimum in required.items():
        report = reports.get(name)
        if not report or report['tests'] < minimum or any(report[k] for k in ('failures', 'errors', 'skipped')):
            raise ValueError('Required three-engine coverage is missing: ' + name)
        if digest(root / report['retained']) != report['sha256']:
            raise ValueError('Retained test report hash changed: ' + name)
    measurements = []
    if coverage == 'large-transfers':
        expected = {'POSTGRESQL': '17.11', 'MYSQL': '8.4.10', 'MARIADB': '11.8.9'}
        for engine, version in expected.items():
            filename = f'backend/target/large-transfer-{engine.lower()}.json'
            artifact = next((item for item in stage.get('artifacts', []) if item['file'] == filename), None)
            if artifact is None or digest(root / artifact['retained']) != artifact['sha256']:
                raise ValueError('Current retained large transfer measurement missing: ' + engine)
            data = json.loads((root / artifact['retained']).read_text())
            if (data['engine'] != engine or not data['serverVersion'].startswith(version)
                    or data['rows'] != 32768 or data['cellBytes'] != 65536
                    or data['outputBytes'] <= 2147483648 or len(data['outputSha256']) != 64
                    or data['resultSpoolBytes'] != 0 or data['remainingImportSnapshotBytes'] != 0):
                raise ValueError('Successful exact multi-gigabyte acceptance requirements failed: ' + engine)
            measurements.append(data)
    return {'runId': manifest['runId'], 'buildSourceSha256': manifest['buildSourceSha256'],
            'coverage': coverage, 'reports': [reports[name] for name in required],
            'measurements': measurements, 'passed': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('coverage', choices=('large-transfers', 'native-backup'))
    args = parser.parse_args()
    result = validate(args.coverage)
    destination = ROOT / 'build' / (args.coverage + '-coverage.json')
    destination.write_text(json.dumps(result, indent=2) + '\n')
    print(destination)


if __name__ == '__main__':
    main()
