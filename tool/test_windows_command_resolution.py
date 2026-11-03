"""Resolved Windows SDK launchers retain arguments and strict test evidence."""
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import verification_evidence as evidence
import test_verification_evidence as evidence_fixture


class WindowsCommandResolutionTest(unittest.TestCase):
    def test_windows_batch_executable_is_resolved_without_mutating_arguments(self):
        command = ['flutter', 'test', 'path with spaces/資料.dart', '--dart-define=value=$&%literal']
        expected = list(command)
        with patch.object(evidence, 'os', SimpleNamespace(name='nt')), \
             patch.object(evidence.shutil, 'which', return_value=r'C:\official SDK\bin\flutter.BAT') as which:
            resolved = evidence.resolve_command(command)
        which.assert_called_once_with('flutter')
        self.assertEqual([r'C:\official SDK\bin\flutter.BAT', *expected[1:]], resolved)
        self.assertEqual(expected, command)

    def test_missing_windows_executable_remains_missing(self):
        with patch.object(evidence, 'os', SimpleNamespace(name='nt')), \
             patch.object(evidence.shutil, 'which', return_value=None):
            self.assertEqual(['missing-command', '--version'], evidence.resolve_command(['missing-command', '--version']))

    def test_posix_execution_keeps_its_existing_path_search(self):
        with patch.object(evidence, 'os', SimpleNamespace(name='posix')), \
             patch.object(evidence.shutil, 'which') as which:
            self.assertEqual(['flutter', 'build', 'linux'], evidence.resolve_command(['flutter', 'build', 'linux']))
        which.assert_not_called()

    def test_version_metadata_records_the_actual_resolved_command(self):
        resolved = [r'C:\official SDK\bin\dart.BAT', '--version']
        with patch.object(evidence, 'resolve_command', return_value=resolved), \
             patch.object(evidence.subprocess, 'run', return_value=SimpleNamespace(returncode=0, stdout='official version', stderr='')) as run:
            record = evidence.command_output(['dart', '--version'])
        self.assertEqual(resolved, record['command'])
        self.assertEqual(resolved, run.call_args.args[0])
        self.assertNotIn('shell', run.call_args.kwargs)

    def machine_stage(self, events):
        fixture = evidence_fixture.EvidenceTest()
        fixture.setUp()
        try:
            # Real Python subprocess emits the controlled machine protocol;
            # this is evidence-parser coverage, not a Flutter qualification.
            code = 'import json; events=' + repr(events) + '; [print(json.dumps(event)) for event in events]'
            requested = ['flutter', 'test', '--machine']
            actual = fixture.command(code) + ['flutter.BAT', '--machine']
            with patch.object(evidence, 'resolve_command', return_value=actual):
                status = evidence.run('flutter-tests', requested, root=fixture.root)
            record = json.loads(evidence.manifest_path(fixture.root).read_text())['stages']['flutter-tests']
            self.assertEqual(actual, record['command'])
            self.assertEqual(requested, record['requestedCommand'])
            return status, record
        finally:
            fixture.tearDown()

    def test_uppercase_batch_launcher_requires_actual_complete_flutter_events(self):
        status, record = self.machine_stage([
            {'type': 'testDone', 'result': 'success', 'skipped': False},
            {'type': 'done', 'success': True}])
        self.assertEqual(0, status)
        self.assertEqual({'passed': 1, 'failed': 0, 'skipped': 0, 'doneSuccess': True}, record['flutterTests'])

    def test_uppercase_batch_launcher_cannot_hide_skipped_or_empty_tests(self):
        for events in [[{'type': 'done', 'success': True}],
                       [{'type': 'testDone', 'result': 'success', 'skipped': True}, {'type': 'done', 'success': True}]]:
            with self.subTest(events=events):
                status, record = self.machine_stage(events)
                self.assertEqual(1, status)
                self.assertEqual('failed', record['status'])


if __name__ == '__main__':
    unittest.main()
