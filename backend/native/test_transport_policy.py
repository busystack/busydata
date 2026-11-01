"""Reject downstream runtime injection in BusyData-owned native transport source."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parent

class OfficialClientPolicy(unittest.TestCase):
    def test_no_foreign_memory_or_resolver_patch(self):
        source = '\n'.join(p.read_text() for p in ROOT.glob('*.c'))
        for api in ('VirtualProtect', 'VirtualAllocEx', 'WriteProcessMemory',
                    'CreateRemoteThread', 'DebugActiveProcessStop',
                    'IMAGE_IMPORT_DESCRIPTOR', 'RTLD_NEXT', 'dlsym'):
            self.assertNotRegex(source, r'\b' + api + r'\b')

    def test_private_pipe_is_bound_to_reviewed_child(self):
        source = (ROOT / 'tool_launcher_windows.c').read_text()
        for api in ('CreateNamedPipeW', 'GetNamedPipeClientProcessId',
                    'SetEntriesInAclW', 'AssignProcessToJobObject',
                    'JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE',
                    'PIPE_REJECT_REMOTE_CLIENTS', 'FILE_FLAG_FIRST_PIPE_INSTANCE',
                    'PROC_THREAD_ATTRIBUTE_HANDLE_LIST'):
            self.assertIn(api, source)
        self.assertIn('client_pid!=process.dwProcessId', source)

    def test_bundle_never_carries_legacy_interposer(self):
        source = (ROOT.parent.parent / 'tool/bundle_backend.py').read_text()
        self.assertNotRegex(source, r"native_files\s*=.*hostname_forward")

if __name__ == '__main__':
    unittest.main()
