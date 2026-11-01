import json
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest
import uuid
from unittest.mock import patch

from verification_evidence import (start, run, finish, manifest_path, unavailable,
                                   validate_source_snapshot)


class EvidenceTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        (self.root / 'lib').mkdir()
        (self.root / 'lib/main.dart').write_text('original build input')
        self.probes = patch('verification_evidence.command_output', return_value={
            'exitCode': 0, 'stdout': 'actual tool output', 'stderr': ''})
        self.probes.start()
        start(self.root)

    def tearDown(self):
        self.probes.stop()
        self.temporary.cleanup()

    def command(self, code):
        return [sys.executable, '-c', code]

    def xml(self, skipped=0):
        return f'<testsuite name="fixture" tests="1" failures="0" errors="0" skipped="{skipped}"/>'

    @unittest.skipIf(sys.platform == 'win32', 'POSIX owned process-group interrupt regression; Windows native cleanup is a separate required stage')
    def test_interrupted_command_retains_failure_and_owned_child_exit(self):
        code = "import os,signal,time;os.kill(os.getppid(),signal.SIGINT);time.sleep(60)"
        self.assertEqual(130, run('interrupted', self.command(code), root=self.root))
        record = finish(['interrupted'], self.root)
        self.assertFalse(record['acceptancePassed'])
        self.assertEqual('failed', record['stages']['interrupted']['status'])
        self.assertEqual(130, record['stages']['interrupted']['exitCode'])
        self.assertIsNotNone(record['stages']['interrupted']['commandExitCode'])

    def test_stage_logs_are_bounded_and_overflow_is_not_a_pass(self):
        from bounded_process_log import BoundedProcessLog
        code = "import sys;sys.stdout.buffer.write(b'x' * 1025)"
        def small_limit(process, destination, limit):
            self.assertEqual(32*1024*1024, limit)
            return BoundedProcessLog(process, destination, limit=1024)
        with patch('verification_evidence.BoundedProcessLog', side_effect=small_limit):
            self.assertEqual(1, run('log-overflow', self.command(code), root=self.root))
        stage = finish(['log-overflow'], self.root)['stages']['log-overflow']
        self.assertEqual(1024, (self.root / stage['log']).stat().st_size)
        self.assertEqual(1025, stage['logRetention']['receivedBytes'])
        self.assertFalse(stage['logRetention']['complete'])

    def test_complete_stage_log_retains_exact_bytes_and_hash(self):
        self.assertEqual(0, run('bounded', self.command("print('actual evidence')"), root=self.root))
        stage = finish(['bounded'], self.root)['stages']['bounded']
        self.assertTrue(stage['logRetention']['complete'])
        self.assertEqual(b'actual evidence\n', (self.root / stage['log']).read_bytes())
        self.assertEqual(16, stage['logRetention']['retainedBytes'])

    def test_native_stage_cannot_pass_without_the_required_exception_check(self):
        from verification_evidence import source_hash
        artifact = 'build/native-accessibility-mariadb.json'
        payload = {'sourceSha256': source_hash(self.root), 'exitCode': 0,
                   'nativeCatalogEngineCoreVerified': True}
        code = 'from pathlib import Path;Path("build").mkdir(exist_ok=True);Path(' + repr(artifact) + ').write_text(' + repr(json.dumps(payload)) + ')'
        self.assertEqual(1, run('native-workflow-mariadb', self.command(code), artifacts=[artifact], root=self.root))
        record = json.loads(manifest_path(self.root).read_text())['stages']['native-workflow-mariadb']
        self.assertEqual('failed', record['status'])
        self.assertIn('application exception check', record['reason'])

    def test_ordinary_mysql_cannot_bypass_native_application_log_validation(self):
        from verification_evidence import source_hash
        artifact = 'build/native-accessibility-mysql-ordinary.json'
        payload = {'sourceSha256': source_hash(self.root), 'exitCode': 0,
                   'ordinaryMySqlConfiguration': {'freshAccount': True}}
        code = 'from pathlib import Path;Path("build").mkdir(exist_ok=True);Path(' + repr(artifact) + ').write_text(' + repr(json.dumps(payload)) + ')'
        self.assertEqual(1, run('native-workflow-mysql-ordinary', self.command(code), artifacts=[artifact], root=self.root))
        record = json.loads(manifest_path(self.root).read_text())['stages']['native-workflow-mysql-ordinary']
        self.assertEqual('failed', record['status'])
        self.assertIn('application exception check', record['reason'])

    def test_native_stage_rechecks_completed_source_and_raw_application_log(self):
        from application_exception_log import audit
        from verification_evidence import source_hash
        source = source_hash(self.root)
        directory = self.root/'build/native-accessibility'/str(uuid.uuid4());directory.mkdir(parents=True)
        log = directory/'application.log';raw=b'libEGL warning: DRI3 error: no device\n';log.write_bytes(raw)
        logs=[{'file':str(log),'sha256':hashlib.sha256(raw).hexdigest(),'receivedBytes':len(raw),
               'retainedBytes':len(raw),'limitBytes':2*1024*1024,'complete':True,'failureType':None}]
        payload={'sourceSha256':source,'exitCode':0,'logs':logs,'applicationExceptionCheck':audit(logs,source,directory)}
        artifact='build/native-accessibility-linux.json'
        code='from pathlib import Path;Path('+repr(artifact)+').write_text('+repr(json.dumps(payload))+')'
        self.assertEqual(0,run('native-accessibility',self.command(code),artifacts=[artifact],root=self.root))
        log.write_text('Unhandled Exception: late failure\n')
        final=finish(['native-accessibility'],self.root)
        self.assertFalse(final['acceptancePassed'])
        self.assertTrue(any('application exception check' in reason for reason in final['acceptanceFailures']))

    def test_stale_reports_cannot_make_an_empty_stage_pass(self):
        directory = self.root / 'backend/target/surefire-reports'
        directory.mkdir(parents=True)
        (directory / 'TEST-old.xml').write_text(self.xml())
        status = run('java', self.command('print("BUILD SUCCESS")'),
                     ['backend/target/surefire-reports'], root=self.root)
        self.assertEqual(1, status)
        record = finish(['java'], self.root)
        self.assertFalse(record['acceptancePassed'])
        self.assertEqual([], record['stages']['java']['reports'])
        self.assertTrue((manifest_path(self.root).parent / 'java/preexisting-surefire-reports/TEST-old.xml').exists())

    def test_exit_codes_and_unavailable_stages_remain_failures(self):
        self.assertEqual(7, run('failed', self.command('raise SystemExit(7)'), root=self.root))
        unavailable('windows-native', 'No available Windows runner', self.root)
        record = finish(['failed', 'windows-native', 'not-executed'], self.root)
        self.assertFalse(record['acceptancePassed'])
        self.assertEqual(7, record['stages']['failed']['exitCode'])
        self.assertIsNone(record['stages']['windows-native']['exitCode'])
        self.assertEqual('not-run', record['stages']['not-executed']['status'])
        with self.assertRaises(ValueError):
            unavailable('failed', 'Cannot relabel a product failure', self.root)

    def test_skipped_required_tests_fail_even_with_a_successful_command(self):
        code = "from pathlib import Path;p=Path('backend/target/surefire-reports');p.mkdir(parents=True);(p/'TEST-fresh.xml').write_text(" + repr(self.xml(1)) + ')'
        self.assertEqual(1, run('java', self.command(code), ['backend/target/surefire-reports'], root=self.root))
        self.assertFalse(finish(['java'], self.root)['acceptancePassed'])

    def test_fresh_reports_are_preserved_and_verified_with_their_run(self):
        code = "from pathlib import Path;p=Path('backend/target/surefire-reports');p.mkdir(parents=True);(p/'TEST-fresh.xml').write_text(" + repr(self.xml()) + ')'
        self.assertEqual(0, run('java', self.command(code), ['backend/target/surefire-reports'], root=self.root))
        record = finish(['java'], self.root)
        self.assertTrue(record['acceptancePassed'])
        report = record['stages']['java']['reports'][0]
        (self.root / report['retained']).write_text('changed evidence')
        self.assertFalse(finish(['java'], self.root)['acceptancePassed'])

    def test_build_changes_invalidate_earlier_evidence(self):
        self.assertEqual(0, run('analyze', self.command('pass'), root=self.root))
        (self.root / 'lib/main.dart').write_text('changed build input')
        self.assertFalse(finish(['analyze'], self.root)['acceptancePassed'])
        with self.assertRaises(ValueError):
            run('new-stage', self.command('pass'), root=self.root)

    def test_an_executed_stage_cannot_be_replaced_by_a_later_success(self):
        run('tests', self.command('raise SystemExit(1)'), root=self.root)
        with self.assertRaises(ValueError):
            run('tests', self.command('pass'), root=self.root)
        self.assertFalse(finish(['tests'], self.root)['acceptancePassed'])

    def test_generated_platform_cache_does_not_change_build_identity(self):
        self.assertEqual(0, run('analyze', self.command('pass'), root=self.root))
        generated = self.root / 'linux/flutter/ephemeral/generated'
        generated.parent.mkdir(parents=True)
        generated.write_text('platform build cache')
        self.assertTrue(finish(['analyze'], self.root)['acceptancePassed'])

    def test_each_required_report_directory_must_have_current_results(self):
        code = "from pathlib import Path;p=Path('backend/target/surefire-reports');p.mkdir(parents=True);(p/'TEST-fresh.xml').write_text(" + repr(self.xml()) + ')'
        self.assertEqual(1, run('matrix', self.command(code), ['backend/target/surefire-reports', 'backend/target/failsafe-reports'], root=self.root))
        self.assertFalse(finish(['matrix'], self.root)['acceptancePassed'])

    def test_missing_logs_are_recorded_as_failures_without_losing_the_record(self):
        run('java', self.command('pass'), root=self.root)
        manifest = json.loads(manifest_path(self.root).read_text())
        (self.root / manifest['stages']['java']['log']).unlink()
        self.assertFalse(finish(['java'], self.root)['acceptancePassed'])

    def test_start_captures_an_independently_reproducible_source_archive(self):
        manifest = json.loads(manifest_path(self.root).read_text())
        verified = validate_source_snapshot(manifest, self.root)
        self.assertTrue(verified['extractedAndVerified'])
        self.assertEqual(manifest['buildSourceSha256'], verified['manifestSha256'])
        self.assertEqual(1, verified['files'])
        self.assertIn('workingTree', manifest)
        self.assertIn('sourceRevision', manifest)

    def test_changed_source_archive_and_cross_snapshot_stage_invalidate_acceptance(self):
        run('java', self.command('pass'), root=self.root)
        path = manifest_path(self.root)
        manifest = json.loads(path.read_text())
        manifest['stages']['java']['buildSourceSha256'] = '0' * 64
        path.write_text(json.dumps(manifest))
        record = finish(['java'], self.root)
        self.assertFalse(record['acceptancePassed'])
        self.assertIn('Changed stage source snapshot: java', record['acceptanceFailures'])
        (self.root / manifest['sourceSnapshot']['archive']['file']).write_bytes(b'tampered ZIP')
        record = finish(['java'], self.root)
        self.assertTrue(any('Canonical source snapshot failed' in value for value in record['acceptanceFailures']))


if __name__ == '__main__':
    unittest.main()
