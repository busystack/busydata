import json
import io
import hashlib
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
import uuid
from unittest.mock import patch

from package_verification_evidence import package, finish_with_archive, verify_evidence_archive, native_references, native_relative
from native_platform_matrix import CASES
from verification_evidence import start, run, finish, unavailable, manifest_path, source_hash, digest


class EvidenceArchiveTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name).resolve()
        (self.root / 'lib').mkdir()
        (self.root / 'lib/main.dart').write_text('authoritative source')
        self.probes = patch('verification_evidence.command_output', return_value={'exitCode': 0})
        self.probes.start()
        self.run_id = start(self.root)

    def tearDown(self):
        self.probes.stop()
        self.temporary.cleanup()

    def stage(self):
        code = "from pathlib import Path;p=Path('backend/target/surefire-reports');p.mkdir(parents=True);(p/'TEST-current.xml').write_text('<testsuite name=\"unit\" tests=\"1\" failures=\"0\" errors=\"0\" skipped=\"0\"/>');print('actual run output')"
        run('java', [sys.executable, '-c', code],
            reports=['backend/target/surefire-reports'], root=self.root)

    def test_archive_contains_underlying_reports_and_no_unreferenced_private_files(self):
        self.stage()
        private = manifest_path(self.root).parent / 'private'
        private.mkdir();(private / 'password.txt').write_text('must stay private')
        finish(['java'], self.root)
        archive = package(self.run_id, self.root)
        with tarfile.open(archive) as content:
            names = content.getnames()
            self.assertTrue(any(name.endswith('TEST-current.xml') for name in names))
            self.assertTrue(any(name.endswith('command.log') for name in names))
            self.assertFalse(any('private' in name or 'preexisting' in name for name in names))
            collection = json.load(content.extractfile('collection.json'))
            self.assertTrue(collection['currentSourceMatches'])
            self.assertTrue(collection['recordedAcceptancePassed'])
            self.assertFalse(collection['productionComplete'])
        self.assertTrue(archive.with_name(archive.name + '.sha256').is_file())
        self.assertNotEqual(archive, package(self.run_id, self.root))

    def test_failed_and_unavailable_stages_remain_failed_in_the_archive(self):
        self.stage();unavailable('windows', 'No actual runner', self.root)
        finish(['java', 'windows', 'not-executed'], self.root)
        archive = package(self.run_id, self.root)
        with tarfile.open(archive) as content:
            collection = json.load(content.extractfile('collection.json'))
            self.assertFalse(collection['recordedAcceptancePassed'])
            name = next(name for name in content.getnames() if name.endswith('verification-evidence.json'))
            record = json.load(content.extractfile(name))
            self.assertEqual('unavailable', record['stages']['windows']['status'])
            self.assertEqual('not-run', record['stages']['not-executed']['status'])

    def test_modified_logs_and_reports_cannot_be_packaged(self):
        self.stage();finish(['java'], self.root)
        stage = json.loads(manifest_path(self.root).read_text())['stages']['java']
        (self.root / stage['reports'][0]['retained']).write_text('tampered')
        with self.assertRaisesRegex(ValueError, 'hash changed'):
            package(self.run_id, self.root)
        self.assertFalse((self.root / 'build/evidence').exists())

    def test_changed_source_requires_an_explicit_historical_collection(self):
        self.stage();finish(['java'], self.root)
        (self.root / 'lib/main.dart').write_text('new implementation')
        with self.assertRaisesRegex(ValueError, 'Source changed'):
            package(self.run_id, self.root)
        archive = package(self.run_id, self.root, historical=True)
        with tarfile.open(archive) as content:
            collection = json.load(content.extractfile('collection.json'))
            self.assertTrue(collection['historical'])
            self.assertFalse(collection['currentSourceMatches'])

    def test_native_report_cannot_select_a_private_file_outside_its_diagnostic_run(self):
        secret = self.root / 'private-key';secret.write_text('excluded')
        artifact = self.root / 'build/native-accessibility-linux.json'
        code = "from pathlib import Path;Path('build/native-accessibility-linux.json').write_text(" + repr(json.dumps({
            'sourceSha256': source_hash(self.root),
            'logs': [{'file': str(secret), 'sha256': 'irrelevant'}],
        })) + ')'
        run('native', [sys.executable, '-c', code], artifacts=[str(artifact.relative_to(self.root))], root=self.root)
        finish(['native'], self.root)
        with self.assertRaisesRegex(ValueError, 'owned run'):
            package(self.run_id, self.root)

    def test_symbolic_diagnostic_files_are_rejected(self):
        self.stage();finish(['java'], self.root)
        stage = json.loads(manifest_path(self.root).read_text())['stages']['java']
        log = self.root / stage['log'];target = self.root / 'secret'
        target.write_bytes(log.read_bytes());log.unlink();log.symlink_to(target)
        with self.assertRaisesRegex(ValueError, 'symbolic'):
            package(self.run_id, self.root)

    def test_archive_failure_fails_the_final_record_instead_of_reporting_success(self):
        self.stage()
        (self.root / 'build/verification-archive.json').write_text(json.dumps({'runId': 'stale', 'file': 'old-archive'}))
        with patch('package_verification_evidence.package', side_effect=OSError('denied')):
            result = finish_with_archive(['java'], self.root)
        self.assertFalse(result['acceptancePassed'])
        self.assertIn('Underlying evidence archive failed: OSError', result['acceptanceFailures'])
        current = json.loads((self.root / 'build/verification-archive.json').read_text())
        self.assertEqual(self.run_id, current['runId'])
        self.assertEqual('failed', current['status'])
        self.assertNotIn('file', current)

    def rewrite_archive(self, original, change):
        with tarfile.open(original) as source:
            files = {member.name: source.extractfile(member).read() for member in source.getmembers()}
        change(files)
        altered = self.root / 'altered.tar.gz'
        with tarfile.open(altered, 'w:gz') as archive:
            for name, data in files.items():
                member = tarfile.TarInfo(name)
                member.size = len(data)
                archive.addfile(member, io.BytesIO(data))
        return altered

    def test_archive_reproduces_its_canonical_source_and_complete_inventory(self):
        self.stage();finish(['java'], self.root)
        archive = package(self.run_id, self.root)
        with patch('tarfile.TarFile.getmembers', side_effect=AssertionError('Member inventory must be incremental')):
            collection = verify_evidence_archive(archive)
        manifest = json.loads(manifest_path(self.root).read_text())
        self.assertEqual(manifest['sourceSnapshot'], collection['sourceSnapshot'])
        self.assertEqual(source_hash(self.root), collection['buildSourceSha256'])
        self.assertIn(collection['sourceSnapshot']['manifest']['file'], collection['files'])
        self.assertIn(collection['sourceSnapshot']['archive']['file'], collection['files'])

    def test_archive_rejects_missing_undeclared_changed_and_wrong_size_members(self):
        self.stage();finish(['java'], self.root)
        archive = package(self.run_id, self.root)
        def missing(files):
            del files[next(name for name in files if name.endswith('command.log'))]
        def undeclared(files):
            files['unrequested-data'] = b'never retain'
        def changed(files):
            files[next(name for name in files if name.endswith('command.log'))] += b'changed'
        def wrong_size(files):
            index = json.loads(files['collection.json'])
            name = next(iter(index['files']))
            index['files'][name]['bytes'] += 1
            files['collection.json'] = json.dumps(index).encode()
        for change in (missing, undeclared, changed, wrong_size):
            with self.subTest(change=change.__name__), self.assertRaises(ValueError):
                verify_evidence_archive(self.rewrite_archive(archive, change))

    def test_source_artifact_tampering_and_cross_snapshot_stages_cannot_be_packaged(self):
        self.stage();finish(['java'], self.root)
        path = manifest_path(self.root)
        manifest = json.loads(path.read_text())
        record_path = path.parent / 'verification-evidence.json'
        record = json.loads(record_path.read_text())
        manifest['stages']['java']['buildSourceSha256'] = '0' * 64
        record['stages']['java']['buildSourceSha256'] = '0' * 64
        path.write_text(json.dumps(manifest));record_path.write_text(json.dumps(record))
        with self.assertRaisesRegex(ValueError, 'different source'):
            package(self.run_id, self.root)
        manifest['stages']['java']['buildSourceSha256'] = record['buildSourceSha256']
        record['stages']['java']['buildSourceSha256'] = record['buildSourceSha256']
        path.write_text(json.dumps(manifest));record_path.write_text(json.dumps(record))
        (self.root / record['sourceSnapshot']['archive']['file']).write_bytes(b'not the verified source')
        with self.assertRaisesRegex(ValueError, 'size or hash changed'):
            package(self.run_id, self.root)

    def test_declared_artifact_size_is_checked_and_old_snapshot_cannot_satisfy_a_stage(self):
        code = "from pathlib import Path;Path('build/result.json').write_text('{\"sourceSha256\":\"stale-source\"}')"
        run('artifact', [sys.executable, '-c', code], artifacts=['build/result.json'], root=self.root)
        finish(['artifact'], self.root)
        with self.assertRaisesRegex(ValueError, 'different source'):
            package(self.run_id, self.root)

    def test_native_platform_matrix_retains_checked_receipts_and_excludes_private_state(self):
        native = self.root / 'build/native-accessibility' / str(uuid.uuid4())
        case = native / 'platform-matrix/display-200'
        case.mkdir(parents=True)
        def receipt(path):
            return {'file': str(path), 'sha256': digest(path), 'bytes': path.stat().st_size}
        log = case / 'controller.log';log.write_text('owned controller diagnostics')
        composed = case / 'composed-settings.json';composed.write_text('{"passed":true}')
        case_report = case / 'report.json';case_report.write_text(json.dumps({
            'sourceSha256': source_hash(self.root),
            'logs': [receipt(log)], 'actualComposedSettingsFile': receipt(composed)}))
        matrix = native / 'platform-matrix/matrix.json'
        matrix.write_text(json.dumps({'sourceSha256': source_hash(self.root), 'cases': [{
            'name': 'display-200', 'controllerLog': receipt(log),
            'report.json': receipt(case_report), 'composed-settings.json': receipt(composed)}]}))
        private = case / 'config/password.txt';private.parent.mkdir();private.write_text('unrequested private state')
        code = "from pathlib import Path;Path('build/native-accessibility-linux.json').write_text(" + repr(json.dumps({
            'sourceSha256': source_hash(self.root), 'platformMatrix': receipt(matrix)})) + ')'
        run('native', [sys.executable, '-c', code], artifacts=['build/native-accessibility-linux.json'], root=self.root)
        finish(['native'], self.root)
        archive = package(self.run_id, self.root)
        collection = verify_evidence_archive(archive)
        for path in (log, composed, case_report, matrix):
            self.assertIn(path.relative_to(self.root).as_posix(), collection['files'])
        self.assertNotIn(private.relative_to(self.root).as_posix(), collection['files'])

    def test_native_matrix_admits_all_configured_public_cases_and_rejects_private_paths(self):
        prefix = 'build/native-accessibility/' + str(uuid.uuid4()) + '/platform-matrix/'
        source = source_hash(self.root)
        matrix = {'sourceSha256': source, 'cases': []}
        documents = {prefix + 'matrix.json': matrix}
        for expected in CASES:
            name = expected['name']
            path = prefix + name + '/report.json'
            matrix['cases'].append({'name': name, 'report.json': {'file': path, 'sha256': 'receipt'}})
            documents[path] = {'sourceSha256': source, 'logs': []}
            with self.assertRaisesRegex(ValueError, 'outside its allowed owned files'):
                native_relative(prefix + name + '/config/password.txt')
        native = {'sourceSha256': source, 'platformMatrix': {
            'file': prefix + 'matrix.json', 'sha256': 'matrix'}}
        references = native_references(native, documents.__getitem__)
        self.assertEqual({entry['file'] for entry in references}, set(documents))
        self.assertEqual(len(references), len(CASES) + 1)

    def test_native_relaunch_retains_only_the_named_owned_diagnostic(self):
        prefix = 'build/native-accessibility/' + str(uuid.uuid4()) + '/'
        log = {'file': prefix + 'application-relaunch.log', 'sha256': 'relaunch', 'bytes': 42}
        native = {'sourceSha256': source_hash(self.root), 'logs': [log]}
        self.assertEqual(native_references(native, {}.__getitem__), [log])
        for path in ('application-unrelated.log', 'config/application-relaunch.log',
                     '../application-relaunch.log'):
            with self.assertRaisesRegex(ValueError, 'outside its allowed owned files'):
                native_relative(prefix + path)

    def test_native_case_cannot_retain_a_report_from_a_different_source(self):
        prefix = 'build/native-accessibility/' + str(uuid.uuid4()) + '/platform-matrix/'
        native = {'sourceSha256': source_hash(self.root), 'platformMatrix': {
            'file': prefix + 'matrix.json', 'sha256': 'matrix'}}
        documents = {prefix + 'matrix.json': {'sourceSha256': native['sourceSha256'], 'cases': [{
            'name': 'light', 'report.json': {'file': prefix + 'light/report.json', 'sha256': 'case'}}]},
            prefix + 'light/report.json': {'sourceSha256': 'stale-source', 'logs': []}}
        with self.assertRaisesRegex(ValueError, 'case.*different source'):
            native_references(native, documents.__getitem__)

    def test_duplicate_native_reference_does_not_bypass_declared_size(self):
        native = self.root / 'build/native-accessibility' / str(uuid.uuid4())
        case = native / 'platform-matrix/light'
        case.mkdir(parents=True)
        case_report = case / 'report.json'
        case_report.write_text(json.dumps({'sourceSha256': source_hash(self.root), 'logs': []}))
        matrix = native / 'platform-matrix/matrix.json'
        matrix.write_text(json.dumps({'sourceSha256': source_hash(self.root), 'cases': [{
            'name': 'light', 'report.json': {'file': str(case_report), 'sha256': digest(case_report),
                                          'bytes': case_report.stat().st_size + 1}}]}))
        payload = {'sourceSha256': source_hash(self.root), 'platformMatrix': {
            'file': str(matrix), 'sha256': digest(matrix), 'bytes': matrix.stat().st_size}}
        code = "from pathlib import Path;Path('build/native-accessibility-linux.json').write_text(" + repr(json.dumps(payload)) + ')'
        run('native', [sys.executable, '-c', code], artifacts=['build/native-accessibility-linux.json'], root=self.root)
        finish(['native'], self.root)
        with self.assertRaisesRegex(ValueError, 'byte size changed'):
            package(self.run_id, self.root)

    def test_downloaded_archive_validates_native_reference_bytes_independently(self):
        native = self.root / 'build/native-accessibility' / str(uuid.uuid4())
        native.mkdir(parents=True)
        log = native / 'application.log';log.write_text('owned native diagnostics')
        payload = {'sourceSha256': source_hash(self.root), 'logs': [{
            'file': str(log), 'sha256': digest(log), 'bytes': log.stat().st_size}]}
        code = "from pathlib import Path;Path('build/native-accessibility-linux.json').write_text(" + repr(json.dumps(payload)) + ')'
        run('native', [sys.executable, '-c', code], artifacts=['build/native-accessibility-linux.json'], root=self.root)
        finish(['native'], self.root)
        archive = package(self.run_id, self.root)
        def wrong_reference_size(files):
            record_name = next(name for name in files if name.endswith('/verification-evidence.json'))
            manifest_name = record_name.removesuffix('verification-evidence.json') + 'manifest.json'
            record = json.loads(files[record_name])
            artifact_name = record['stages']['native']['artifacts'][0]['retained']
            report = json.loads(files[artifact_name]);report['logs'][0]['bytes'] += 1
            files[artifact_name] = json.dumps(report).encode()
            for name in (record_name, manifest_name):
                document = json.loads(files[name])
                entry = document['stages']['native']['artifacts'][0]
                entry.update(sha256=hashlib.sha256(files[artifact_name]).hexdigest(), bytes=len(files[artifact_name]))
                files[name] = json.dumps(document).encode()
            collection = json.loads(files['collection.json'])
            for name in (artifact_name, record_name, manifest_name):
                collection['files'][name] = {'bytes': len(files[name]), 'sha256': hashlib.sha256(files[name]).hexdigest()}
            files['collection.json'] = json.dumps(collection).encode()
        with self.assertRaisesRegex(ValueError, 'declared byte size'):
            verify_evidence_archive(self.rewrite_archive(archive, wrong_reference_size))

    def test_installed_vm_diagnostics_and_separate_package_are_hash_bound(self):
        diagnostics = manifest_path(self.root).parent / 'installed-snap/diagnostics'
        diagnostics.mkdir(parents=True)
        log = diagnostics / 'vm.log';log.write_text('owned VM receipt')
        release = self.root / 'build/installed-snap-vm' / str(uuid.uuid4()) / 'product-package/product.snap'
        release.parent.mkdir(parents=True);release.write_bytes(b'disposable package fixture')
        payload = {'sourceSha256': source_hash(self.root), 'diagnostics': [{
            'file': log.relative_to(self.root).as_posix(), 'sha256': digest(log), 'bytes': log.stat().st_size}],
            'packages': [{'kind': 'product', 'file': release.relative_to(self.root).as_posix(),
                          'sha256': digest(release), 'bytes': release.stat().st_size,
                          'sourceSha256': source_hash(self.root)}]}
        code = "from pathlib import Path;Path('build/installed-snap.json').write_text(" + repr(json.dumps(payload)) + ')'
        run('installed-check', [sys.executable, '-c', code], artifacts=['build/installed-snap.json'], root=self.root)
        finish(['installed-check'], self.root)
        archive = package(self.run_id, self.root)
        collection = verify_evidence_archive(archive)
        self.assertEqual(payload['packages'], collection['externalArtifacts'])
        self.assertIn(log.relative_to(self.root).as_posix(), collection['files'])
        release.write_bytes(b'changed package')
        with self.assertRaisesRegex(ValueError, 'Separate release package'):
            package(self.run_id, self.root)


if __name__ == '__main__':
    unittest.main()
