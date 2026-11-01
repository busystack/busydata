import json
import io
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock
from types import SimpleNamespace
from verify_installed_snap import ready_line, stop, drive_picker, desktop_command, paste_gtk_text, editable_text_matches, picker_has_text, picker_location_field, validate_desktop_report

class InstalledAcceptanceTest(unittest.TestCase):
    def test_native_picker_input_requires_focus_visibility_and_window_bounds(self):
        field, frame, application, desktop = Mock(), Mock(), Mock(), Mock()
        field.get_child_count.return_value = 0
        field.get_interfaces.return_value = ['EditableText', 'Text']
        field.get_role.return_value = 'text'
        field.get_parent.return_value = frame
        frame.get_role.return_value = 'file chooser'
        frame.get_name.return_value = 'Chooser'
        frame.get_child_count.return_value = 1
        frame.get_interfaces.return_value = []
        frame.get_child_at_index.return_value = field
        application.get_process_id.return_value = 101
        application.get_child_count.return_value = 1
        application.get_interfaces.return_value = []
        application.get_child_at_index.return_value = frame
        desktop.get_child_count.return_value = 1
        desktop.get_child_at_index.return_value = application
        allocation = SimpleNamespace(x=0, y=0, width=500, height=300)
        box = SimpleNamespace(x=10, y=20, width=300, height=30)
        atspi = SimpleNamespace(get_desktop=lambda _: desktop,
            StateType=SimpleNamespace(FOCUSED='focused', SHOWING='showing'),
            Role=SimpleNamespace(FRAME='frame', DIALOG='dialog', FILE_CHOOSER='file chooser'), CoordType=SimpleNamespace(SCREEN='screen'),
            Component=SimpleNamespace(get_extents=lambda node, _: allocation if node is frame else box))
        modules = {'gi': SimpleNamespace(require_version=lambda *args: None),
                   'gi.repository': SimpleNamespace(Atspi=atspi, GLib=SimpleNamespace(Error=RuntimeError))}
        with patch.dict(sys.modules, modules), patch('verify_installed_snap.run', side_effect=lambda argv, **kwargs: SimpleNamespace(stdout='101' if argv[1] == 'getwindowpid' else 'Chooser')):
            field.get_state_set.return_value.contains.side_effect = lambda state: state == 'showing'
            self.assertIsNone(picker_location_field('owned-window'))
            field.get_state_set.return_value.contains.side_effect = lambda state: True
            box.y = 310
            self.assertIsNone(picker_location_field('owned-window'))
            box.y = 20
            self.assertIs(field, picker_location_field('owned-window'))
            frame.get_name.return_value = 'BusyData'
            self.assertIsNone(picker_location_field('owned-window'))

    def test_picker_retries_disposed_descendant_without_accepting_another_value(self):
        class NativeDisposed(Exception):
            pass
        field = Mock()
        field.get_child_count.return_value = 0
        field.get_interfaces.return_value = ['Text', 'EditableText']
        application = Mock()
        application.get_process_id.return_value = 101
        application.get_role.return_value = 'frame'
        application.get_name.return_value = '101'
        application.get_interfaces.return_value = []
        application.get_child_count.side_effect = [NativeDisposed(), 1, 1]
        application.get_child_at_index.return_value = field
        desktop = Mock()
        desktop.get_child_count.return_value = 1
        desktop.get_child_at_index.return_value = application
        text = Mock()
        text.get_character_count.return_value = 10
        text.get_text.return_value = '/exact.sql'
        atspi = SimpleNamespace(get_desktop=lambda _: desktop, Text=text, Role=SimpleNamespace(FRAME='frame', DIALOG='dialog', FILE_CHOOSER='file chooser'))
        modules = {'gi': SimpleNamespace(require_version=lambda *args: None),
                   'gi.repository': SimpleNamespace(Atspi=atspi, GLib=SimpleNamespace(Error=NativeDisposed))}
        with patch.dict(sys.modules, modules), patch('verify_installed_snap.run', return_value=SimpleNamespace(stdout='101')):
            self.assertFalse(picker_has_text('owned-window', '/exact.sql'))
            self.assertFalse(picker_has_text('owned-window', '/another.sql'))
            self.assertTrue(picker_has_text('owned-window', '/exact.sql'))

    def test_aggregate_success_cannot_hide_missing_confined_workflows(self):
        report = {'version': 1, 'entrypoint': 'installed_snap_linux.dart',
                  'releaseMode': True, 'exitCode': 0,
                  'fullInstalledDatabaseFileSecretSshAcceptance': True,
                  'stages': {'backend-lifecycle': {'passed': True}}}
        with self.assertRaisesRegex(RuntimeError, 'missing or failed'):
            validate_desktop_report(report)

    @staticmethod
    def complete_report():
        report = {'version': 1, 'entrypoint': 'installed_snap_linux.dart',
                  'releaseMode': True, 'exitCode': 0,
                  'fullInstalledDatabaseFileSecretSshAcceptance': True,
                  'stages': {name: {'passed': True} for name in
                      ('native-single-instance', 'portal-credentials', 'files-recovery',
                       'native-open-picker', 'native-save-picker', 'native-ca-picker',
                       'native-key-picker', 'changed-ssh-key-review',
                       'backend-lifecycle')}}
        for engine in ('POSTGRESQL', 'MYSQL', 'MARIADB'):
            for name in ('tls-execution', 'transactions-cancellation-editing-paging', 'p0-result-editor',
                         'native-export-picker', 'native-import-picker',
                         'transfers', 'large-streaming-transfer',
                         'ssh-password-key-agent-native-backup', 'retained-after-disconnect'):
                report['stages'][engine + '-' + name] = {'passed': True}
            report[engine + '-p0ResultEditor'] = {
                'exactCompleteUnicodeAndBytes': True, 'aggregateExactScope': True,
                'cloneStagedWithoutMutation': True, 'relatedBrowseReviewed': True,
                'sourceRetainedUnchanged': True, 'nonBrowseDatabaseJobsSubmitted': 0,
                'textUtf8Bytes': 90000, 'binaryBytes': 90000}
            report[engine + '-largeTransfer'] = {'rows': 512, 'payloadBytesPerRow': 65536,
                'outputBytes': 512 * 65536 + 10000, 'outputSha256': 'a' * 64,
                'allDurableValuesVerified': True}
            report[engine + '-interactiveAcceptance'] = {
                'transactionCommitRollback': True, 'queuedRunningCancellation': True,
                'reviewedDurableEdit': True, 'verifiedPagedRows': 300}
        return report

    def test_complete_report_requires_real_cell_and_durable_transfer_receipts(self):
        report = self.complete_report()
        validate_desktop_report(report)
        for engine in ('POSTGRESQL', 'MYSQL', 'MARIADB'):
            altered = json.loads(json.dumps(report))
            altered[engine + '-interactiveAcceptance']['verifiedPagedRows'] = 0
            with self.assertRaisesRegex(RuntimeError, 'evidence is incomplete'):
                validate_desktop_report(altered)
            altered = json.loads(json.dumps(report))
            altered[engine + '-largeTransfer']['outputSha256'] = ''
            with self.assertRaisesRegex(RuntimeError, 'evidence is incomplete'):
                validate_desktop_report(altered)

    def test_p0_editor_requires_each_exact_native_receipt(self):
        for engine in ('POSTGRESQL', 'MYSQL', 'MARIADB'):
            for key in ('exactCompleteUnicodeAndBytes', 'aggregateExactScope',
                        'cloneStagedWithoutMutation', 'relatedBrowseReviewed',
                        'sourceRetainedUnchanged', 'textUtf8Bytes', 'binaryBytes'):
                altered = self.complete_report()
                del altered[engine + '-p0ResultEditor'][key]
                with self.assertRaisesRegex(RuntimeError, 'P0 result-editor evidence is incomplete'):
                    validate_desktop_report(altered)
            altered = self.complete_report()
            altered[engine + '-p0ResultEditor']['nonBrowseDatabaseJobsSubmitted'] = 1
            with self.assertRaisesRegex(RuntimeError, 'P0 result-editor evidence is incomplete'):
                validate_desktop_report(altered)

    def test_failed_or_removed_required_stage_and_debug_build_cannot_pass(self):
        for mutation in ('failed', 'removed', 'debug', 'failed-extra'):
            report = self.complete_report()
            if mutation == 'failed':
                report['stages']['MYSQL-transfers']['passed'] = False
            elif mutation == 'removed':
                del report['stages']['MARIADB-large-streaming-transfer']
            elif mutation == 'debug':
                report['releaseMode'] = False
            else:
                report['stages']['additional-required-test'] = {'passed': False}
            with self.assertRaisesRegex(RuntimeError, 'missing or failed'):
                validate_desktop_report(report)

    def test_picker_observation_uses_public_interfaces_available_on_core24(self):
        class Core24Accessible:
            def get_interfaces(self):
                return ['Accessible', 'Component', 'Text', 'EditableText']
        item = Core24Accessible()
        text = Mock()
        text.get_character_count.return_value = 8
        text.get_text.return_value = '/漢😀.sql'
        self.assertTrue(editable_text_matches(item, '/漢😀.sql', text))
        text.get_text.assert_called_once_with(item, 0, -1)
        self.assertFalse(editable_text_matches(item, '/another.sql', text))

    def test_read_only_or_oversized_native_text_is_not_a_picker_receipt(self):
        class ReadOnlyAccessible:
            def get_interfaces(self):
                return ['Text']
        class EditableAccessible:
            def get_interfaces(self):
                return ['Text', 'EditableText']
        text = Mock()
        self.assertFalse(editable_text_matches(ReadOnlyAccessible(), 'text', text))
        text.get_character_count.assert_not_called()
        for count in [-1, 4096]:
            text.get_character_count.return_value = count
            self.assertFalse(editable_text_matches(EditableAccessible(), 'text', text))
        text.get_text.assert_not_called()

    def test_a_reader_request_does_not_end_clipboard_ownership_before_target_consumption(self):
        helper = Mock(stdin=io.BytesIO(), stdout=io.BytesIO())
        helper.wait.return_value = 0
        helper.poll.return_value = 0
        observations = []
        def target_consumed():
            self.assertFalse(helper.stdin.closed)
            observations.append(True)
            return len(observations) == 2
        with patch('verify_installed_snap.subprocess.Popen', return_value=helper), \
             patch('verify_installed_snap.ready_line', side_effect=[{'ready':True}, {'served':True}]), \
             patch('verify_installed_snap.run'), patch('verify_installed_snap.time.sleep'):
            paste_gtk_text('/owned/漢😀.sql', target_consumed)
        self.assertEqual(2, len(observations))
        self.assertTrue(helper.stdin.closed)
        self.assertTrue(helper.stdout.closed)

    def test_unconfirmed_valid_paste_cannot_spawn_an_owner(self):
        with patch('verify_installed_snap.subprocess.Popen') as children:
            with self.assertRaisesRegex(RuntimeError, 'confirmation from the intended control'):
                paste_gtk_text('/owned/ordinary.sql')
            children.assert_not_called()

    def test_picker_clipboard_rejects_control_characters_and_oversized_utf8_before_spawning(self):
        with patch('verify_installed_snap.subprocess.Popen') as children:
            for path in ['/owned/evil\n.sql', '/owned/evil\r.sql', '/owned/evil\0.sql', '漢'*1400]:
                with self.assertRaisesRegex(RuntimeError,'path byte or control-character'):
                    paste_gtk_text(path)
            children.assert_not_called()

    def test_tracking_bus_does_not_replace_the_applications_owned_bus_or_command_chain(self):
        address='unix:abstract=/tmp/dbus-test-owned'
        command=desktop_command(address)
        self.assertEqual(['snap','run','--shell','busydata','-c'],command[:5])
        self.assertIn('export DBUS_SESSION_BUS_ADDRESS="$1"',command[5])
        self.assertIn('gpu-2404-wrapper',command[5])
        self.assertIn('desktop-launch',command[5])
        self.assertEqual(address,command[-1])
        self.assertNotIn('--devmode',command)

    def test_fixture_readiness_is_real_bounded_pipe_io(self):
        child = subprocess.Popen([sys.executable, '-c', 'import json,sys;print(json.dumps({"version":1}),flush=True);sys.stdin.read()'],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        try:
            self.assertEqual({'version': 1}, ready_line(child, 5))
        finally:
            child.stdin.close()
            child.wait(timeout=5)
            child.stdout.close()
        self.assertEqual(0, child.returncode)

    def test_oversized_fixture_is_not_decoded_and_only_owned_child_is_stopped(self):
        child = subprocess.Popen([sys.executable, '-c', 'import sys;sys.stdout.write("x"*16385);sys.stdout.flush();sys.stdin.read()'],
                                 stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        try:
            with self.assertRaisesRegex(RuntimeError, 'byte limit'):
                ready_line(child, 5)
            stop(child)
            self.assertIsNotNone(child.returncode)
        finally:
            stop(child)
            child.stdin.close()
            child.stdout.close()

    def test_native_picker_cannot_select_a_path_outside_its_fixture(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'picker-request.json').write_text(json.dumps({'operation':'open','path':str(root.parent/'unrelated.sql')}))
            with patch('verify_installed_snap.run') as commands:
                with self.assertRaisesRegex(RuntimeError, 'unexpected destination'):
                    drive_picker(root, set())
                commands.assert_not_called()

    def test_primary_window_is_not_used_as_a_file_chooser(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'picker-request.json').write_text(json.dumps({'operation':'open','path':str(root/'ordinary.sql')}))
            with patch('verify_installed_snap.subprocess.run', return_value=subprocess.CompletedProcess([],1,'')) as search, patch('verify_installed_snap.run') as commands:
                drive_picker(root, set())
                self.assertIn('--name', search.call_args.args[0])
                self.assertNotIn('--class', search.call_args.args[0])
                commands.assert_not_called()

if __name__ == '__main__':
    unittest.main()
