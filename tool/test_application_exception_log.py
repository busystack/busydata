import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import uuid
from application_exception_log import ApplicationLogNames, audit, scan, validate, validate_tree, MAX_LOG_BYTES, MAX_FINDINGS, MAX_LOGS

SOURCE = 'a' * 64


class ApplicationExceptionLogTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)

    def tearDown(self):
        self.temp.cleanup()

    def receipt(self, name, data):
        path = self.directory / name
        path.write_bytes(data)
        return {'file': str(path), 'sha256': hashlib.sha256(data).hexdigest(),
                'receivedBytes': len(data), 'retainedBytes': len(data),
                'limitBytes': MAX_LOG_BYTES, 'complete': True, 'failureType': None}

    def report(self, logs):
        return {'sourceSha256': SOURCE, 'logs': logs,
                'applicationExceptionCheck': audit(logs, SOURCE, self.directory)}

    def test_release_plain_label_and_stack_from_real_object_pane_failure_is_fatal(self):
        raw = (b'Bad state: Too many elements\n'
               b'#0      ListBase.single (dart:collection/list.dart:85)\n'
               b'#1      _ObjectDocumentViewState.build (package:busydata/src/ui/common/workbench_document_view.dart:1152)\n'
               b'#2      StatefulElement.build (package:flutter/src/widgets/framework.dart:5944)\n')
        result = scan(raw)
        self.assertEqual([{'code': 'flutter-release-error-stack', 'line': 2}], result['findings'])
        report = self.report([self.receipt('application.log', raw)])
        self.assertFalse(report['applicationExceptionCheck']['passed'])
        with self.assertRaises(ValueError): validate(report, SOURCE)

    def test_pinned_engine_unhandled_and_framework_variants_are_fatal(self):
        for raw in (
            b'[ERROR:flutter/runtime/dart_vm_initializer.cc(40)] Unhandled Exception: failure\n',
            b'Unhandled exception:\nStateError\n',
            '══╡ EXCEPTION CAUGHT BY WIDGETS LIBRARY ╞══\n'.encode(),
            b'Another exception was thrown: failure\n',
            b'A RenderFlex overflowed by 12.5 pixels on the right.\n',
            b'\x1b[31mflutter: Another exception was thrown: failure\x1b[0m\n',
            b'[FATAL:flutter/runtime/platform.cc(1)] failed\n',
        ):
            with self.subTest(raw=raw):self.assertGreater(scan(raw)['findingCount'], 0)

    def test_benign_gtk_expected_database_and_errors_as_data_do_not_match(self):
        raw = ('libEGL warning: DRI3 error: Could not get DRI3 device\n'
               '** (busydata:1): Gtk-WARNING **: Timed out waiting for OpenGL frame\n'
               'SQL error 42601: syntax error at or near ERROR\n'
               'gRPC Error(code:1,message:cancelled)\n'
               'java.sql.SQLSyntaxErrorException: expected disposable fault\n'
               ' at org.postgresql.Driver.query(Driver.java:10)\n' +
               json.dumps({'message': 'Unhandled Exception: data', 'stack': '#0 App (package:busydata/main.dart:1)'}) + '\n').encode()
        self.assertEqual(0, scan(raw)['findingCount'])
        validate(self.report([self.receipt('application.log', raw)]), SOURCE)

    def test_relaunch_failure_cannot_be_hidden_by_successful_first_process(self):
        report = self.report([self.receipt('application.log', b'ordinary\n'),
                              self.receipt('application-relaunch.log', b'Unhandled Exception: late failure\n')])
        self.assertEqual(1, report['applicationExceptionCheck']['findingCount'])
        with self.assertRaises(ValueError):validate(report, SOURCE)

    def test_each_relaunch_preserves_its_own_log_and_earlier_failure(self):
        names=ApplicationLogNames()
        logs=[self.receipt(names.claim('application')+'.log', b'ordinary\n')]
        logs.append(self.receipt(names.claim('application-relaunch')+'.log', b'Unhandled Exception: first relaunch\n'))
        logs.append(self.receipt(names.claim('application-relaunch')+'.log', b'clean later relaunch\n'))
        self.assertEqual(3,len({item['file'] for item in logs}))
        check=audit(logs,SOURCE,self.directory)
        self.assertEqual(1,check['findingCount'])
        self.assertFalse(check['passed'])
        self.assertEqual('dart-unhandled-exception',check['logs'][1]['findings'][0]['code'])
        with self.assertRaises(ValueError):validate(self.report(logs),SOURCE)

    def test_launch_log_names_are_admitted_before_spawn_and_have_a_hard_bound(self):
        names=ApplicationLogNames()
        with self.assertRaises(ValueError):names.claim('application-relaunch')
        self.assertEqual('application',names.claim('application'))
        with self.assertRaises(ValueError):names.claim('application')
        for index in range(1,MAX_LOGS):
            self.assertEqual(f'application-relaunch-{index}',names.claim('application-relaunch'))
        with self.assertRaises(ValueError):names.claim('application-relaunch')

    def test_evidence_archive_only_admits_the_exact_bounded_relaunch_names(self):
        from package_verification_evidence import native_relative
        prefix='build/native-accessibility/00000000-0000-0000-0000-000000000001/'
        for index in range(1,MAX_LOGS):
            name=prefix+f'application-relaunch-{index}.log'
            self.assertEqual(name,native_relative(name))
        for name in ('application-relaunch-0.log','application-relaunch-8.log','application-relaunch-999.log'):
            with self.assertRaises(ValueError):native_relative(prefix+name)

    def test_missing_check_source_change_and_forged_zero_flag_cannot_certify(self):
        report = self.report([self.receipt('application.log', b'ordinary\n')])
        validate(report, SOURCE)
        with self.assertRaises(ValueError):validate({**report, 'applicationExceptionCheck': None}, SOURCE)
        with self.assertRaises(ValueError):validate(report, 'b' * 64)
        path = self.directory / 'application.log'
        path.write_text('Unhandled Exception: later failure\n')
        with self.assertRaises(ValueError):validate(report, SOURCE)
        changed = path.read_bytes()
        report['logs'][0].update(sha256=hashlib.sha256(changed).hexdigest(),
                                receivedBytes=len(changed), retainedBytes=len(changed))
        report['applicationExceptionCheck']['logs'][0].update(
            sha256=hashlib.sha256(changed).hexdigest(), bytes=len(changed))
        with self.assertRaises(ValueError):validate(report, SOURCE)

    def test_wrong_owner_symlink_and_missing_primary_are_not_complete(self):
        item = self.receipt('application-relaunch.log', b'ordinary\n')
        self.assertFalse(audit([item], SOURCE, self.directory)['complete'])
        self.assertFalse(audit([item], None, self.directory)['complete'])
        target = self.directory / 'elsewhere.log';target.write_text('ordinary\n')
        (self.directory / 'application.log').symlink_to(target)
        item.update(file=str(self.directory/'application.log'))
        self.assertFalse(audit([item], SOURCE, self.directory)['complete'])

    def test_missing_incomplete_truncated_changed_and_invalid_encoding_are_unavailable(self):
        self.assertFalse(audit([], SOURCE, self.directory)['passed'])
        for alteration in ({'complete': False}, {'receivedBytes': 100}, {'sha256': '0' * 64}):
            item = self.receipt('application.log', b'ordinary\n');item.update(alteration)
            self.assertFalse(audit([item], SOURCE, self.directory)['complete'])
        item = self.receipt('application.log', b'\xff')
        self.assertFalse(audit([item], SOURCE, self.directory)['complete'])
        with self.assertRaises(ValueError):scan(b'x' * (MAX_LOG_BYTES + 1))

    def test_findings_are_bounded_and_never_copy_private_exception_messages(self):
        raw = b'Unhandled Exception: secret-value\n' * (MAX_FINDINGS + 3)
        result = scan(raw)
        self.assertEqual(MAX_FINDINGS + 3, result['findingCount'])
        self.assertEqual(MAX_FINDINGS, len(result['findings']))
        self.assertTrue(result['findingsLimited'])
        self.assertNotIn('secret-value', json.dumps(result))

    def test_aggregate_platform_and_fluent_cannot_omit_the_child_check(self):
        root = self.directory
        owned = root/'build/native-accessibility'/str(uuid.uuid4());owned.mkdir(parents=True)
        self.directory = owned
        parent = self.report([self.receipt('application.log', b'ordinary\n')])
        def entry(path, value):
            data=json.dumps(value).encode();path.write_bytes(data)
            return {'file':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
        for kind in ('platformMatrix','fluentRendering'):
            with self.subTest(kind=kind):
                nested = owned/('platform-matrix/light' if kind=='platformMatrix' else 'fluent-rendering')
                nested.mkdir(parents=True,exist_ok=True)
                child = {'sourceSha256':SOURCE,'exitCode':0}
                child_entry = entry(nested/'report.json',child)
                if kind=='platformMatrix':
                    wrapper={'sourceSha256':SOURCE,'passed':True,'cases':[{'name':'light','report.json':child_entry}]}
                    linked=entry(nested.parent/'matrix.json',wrapper)
                else:
                    wrapper={'sourceSha256':SOURCE,'passed':True,'report.json':child_entry}
                    linked=entry(nested/'rendering.json',wrapper)
                with self.assertRaises(ValueError):validate_tree({**parent,kind:linked},SOURCE,root=root)
                self.directory=nested
                child=self.report([self.receipt('application.log',b'ordinary\n')])
                child_entry=entry(nested/'report.json',child)
                if kind=='platformMatrix':wrapper['cases'][0]['report.json']=child_entry
                else:wrapper['report.json']=child_entry
                linked=entry(nested.parent/'matrix.json' if kind=='platformMatrix' else nested/'rendering.json',wrapper)
                validate_tree({**parent,kind:linked},SOURCE,root=root)
                self.directory=owned


if __name__ == '__main__':unittest.main()
