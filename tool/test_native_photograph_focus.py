"""Screenshot control flow only; mock pixels never certify native acceptance."""
import os
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

from native_workbench_acceptance import photograph_product


class NativePhotographFocusTest(unittest.TestCase):
    def photograph(self, focused='128', read_error=None, raw_focused=None, ancestor_error=None,
                   ancestor_response=None):
        calls, geometry = [], {'WIDTH': '1280', 'HEIGHT': '800', 'X': '0', 'Y': '0'}
        def command(argv, **options):
            calls.append(argv)
            if argv[:2] == ['xdotool', 'search']:
                self.assertIn('41', argv)
                return types.SimpleNamespace(stdout='128\n')
            if argv == ['xdotool', 'getwindowfocus', '-f']:
                if read_error is not None: raise read_error
                return types.SimpleNamespace(stdout=(focused if raw_focused is None else raw_focused) + '\n')
            if argv == ['xdotool', 'getwindowfocus']:
                if ancestor_error is not None: raise ancestor_error
                if ancestor_response is not None:
                    return types.SimpleNamespace(stdout=ancestor_response + '\n')
                if focused in ('0', '1'):
                    raise subprocess.CalledProcessError(1, argv)
                return types.SimpleNamespace(stdout=focused + '\n')
            if argv[:3] == ['xdotool', 'windowfocus', '--sync']:
                if focused == '128': raise subprocess.TimeoutExpired(argv, 10)
                return types.SimpleNamespace(returncode=0)
            if argv[:2] == ['xdotool', 'windowsize']:
                geometry.update(WIDTH=argv[3], HEIGHT=argv[4])
                return types.SimpleNamespace(returncode=0)
            if argv[:2] == ['xdotool', 'getwindowgeometry']:
                return types.SimpleNamespace(stdout='\n'.join(k + '=' + v for k, v in geometry.items()))
            if argv[:2] == ['xdotool', 'mousemove']:
                return types.SimpleNamespace(returncode=0)
            raise AssertionError('Unexpected photograph command')
        picture = types.SimpleNamespace(get_width=lambda: 1366, get_height=lambda: 768,
            save_to_bufferv=lambda *unused: (True, b'\x89PNG\r\n\x1a\nunit-only mock pixels'))
        # Keep these controller unit cases portable. Actual GTK/AT-SPI is
        # mandatory in the separate native workflow, not substituted here.
        gi = types.ModuleType('gi')
        gi.require_version = lambda *unused: None
        repository = types.ModuleType('gi.repository')
        repository.Gdk = object()
        report = {}
        with tempfile.TemporaryDirectory() as directory, \
                patch.dict('sys.modules', {'gi': gi, 'gi.repository': repository}), \
                patch.dict(os.environ, {'XDG_DATA_HOME': str(Path(directory) / 'data')}), \
                patch('native_workbench_acceptance.native_display_scale', return_value=1), \
                patch('native_workbench_acceptance.physical_window_picture', return_value=picture), \
                patch('native_workbench_acceptance.time.sleep'):
            photograph_product(types.SimpleNamespace(Role=types.SimpleNamespace(PASSWORD_TEXT='password')),
                types.SimpleNamespace(get_process_id=lambda: 41), lambda app: [],
                lambda predicate: predicate(), command, report, 'unit-only')
        return calls, report

    def test_already_focused_owned_window_is_photographed_without_refocusing(self):
        calls, report = self.photograph()
        self.assertFalse(any(call[1] == 'windowfocus' for call in calls))
        self.assertEqual(1, len(report['productScreenshots']))
        self.assertEqual({'requestedWindow': '128', 'status': 'observed', 'readPhase': 'raw',
                          'rawFocusedWindow': '128', 'focusState': 'window',
                          'focusedTopLevel': '128', 'alreadyFocused': True},
            report['nativePhotographFocus'])
        self.assertNotIn(['xdotool', 'getwindowfocus'], calls)

    def test_another_focused_window_requires_existing_synchronized_request(self):
        calls, report = self.photograph(focused='129')
        self.assertEqual([['xdotool', 'windowfocus', '--sync', '128']],
            [call for call in calls if call[1] == 'windowfocus'])
        self.assertEqual(1, len(report['productScreenshots']))
        self.assertFalse(report['nativePhotographFocus']['alreadyFocused'])

    def test_focus_read_failure_is_not_replaced_with_focus_guess(self):
        failure = subprocess.CalledProcessError(2, ['xdotool', 'getwindowfocus', '-f'])
        with self.assertRaises(subprocess.CalledProcessError) as raised:
            self.photograph(read_error=failure)
        self.assertIs(failure, raised.exception)

    def test_malformed_focus_identity_cannot_authorize_capture(self):
        for focused in ('', 'not-an-xid', '9' * 30, '١٢٨', '-1', '4294967296'):
            with self.subTest(focused=focused), self.assertRaises(RuntimeError):
                self.photograph(focused=focused)

    def test_none_focus_requires_one_synchronized_owned_window_request(self):
        calls, report = self.photograph(focused='0')
        self.assertNotIn(['xdotool', 'getwindowfocus'], calls)
        self.assertEqual([['xdotool', 'windowfocus', '--sync', '128']],
                         [call for call in calls if call[1] == 'windowfocus'])
        self.assertEqual('none', report['nativePhotographFocus']['focusState'])
        self.assertIsNone(report['nativePhotographFocus']['focusedTopLevel'])
        self.assertEqual(1, len(report['productScreenshots']))

    def test_pointer_root_focus_requires_one_synchronized_owned_window_request(self):
        calls, report = self.photograph(focused='1')
        self.assertNotIn(['xdotool', 'getwindowfocus'], calls)
        self.assertEqual([['xdotool', 'windowfocus', '--sync', '128']],
                         [call for call in calls if call[1] == 'windowfocus'])
        self.assertEqual('pointer-root', report['nativePhotographFocus']['focusState'])
        self.assertFalse(report['nativePhotographFocus']['alreadyFocused'])
        self.assertEqual(1, len(report['productScreenshots']))

    def test_focused_child_preserves_its_owned_top_level_and_control(self):
        calls, report = self.photograph(focused='128', raw_focused='129')
        self.assertIn(['xdotool', 'getwindowfocus'], calls)
        self.assertFalse(any(call[1] == 'windowfocus' for call in calls))
        self.assertEqual('129', report['nativePhotographFocus']['rawFocusedWindow'])
        self.assertTrue(report['nativePhotographFocus']['alreadyFocused'])

    def test_ancestor_read_failure_remains_a_failure(self):
        failure = subprocess.CalledProcessError(1, ['xdotool', 'getwindowfocus'])
        with self.assertRaises(subprocess.CalledProcessError) as raised:
            self.photograph(focused='129', ancestor_error=failure)
        self.assertIs(failure, raised.exception)

    def test_command_failure_cannot_be_interpreted_as_pointer_root(self):
        failure = subprocess.CalledProcessError(1, ['xdotool', 'getwindowfocus', '-f'], output='1\n')
        with self.assertRaises(subprocess.CalledProcessError) as raised:
            self.photograph(focused='1', read_error=failure)
        self.assertIs(failure, raised.exception)

    def test_sentinel_in_an_ancestor_response_is_not_a_window_identity(self):
        for focused in ('0', '1'):
            with self.subTest(focused=focused), self.assertRaises(RuntimeError):
                self.photograph(focused='129', ancestor_response=focused)


if __name__ == '__main__': unittest.main()
