"""Source-policy checks; these do not claim execution on Windows."""
import ast
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class WindowsNativePolicyTest(unittest.TestCase):
    def test_windows_native_sources_do_not_modify_other_processes_or_imports(self):
        retired = ['hostname_forward_windows.c', 'hostname_forward_windows_test.c',
                   'test_support/readiness_test.c', 'test_support/windows.h',
                   'test_support/psapi.h', 'test_support/ws2tcpip.h',
                   'test_support/winsock2.h']
        for name in retired:
            self.assertFalse((ROOT / 'backend/native' / name).exists(), name)
        launcher = (ROOT / 'backend/native/tool_launcher_windows.c').read_text()
        for forbidden in ['VirtualAllocEx', 'WriteProcessMemory', 'CreateRemoteThread',
                          'VirtualProtect', 'InterlockedExchangePointer', 'EnumProcessModules',
                          'DEBUG_ONLY_THIS_PROCESS', 'LoadLibrary', 'IMAGE_IMPORT_DESCRIPTOR']:
            self.assertNotIn(forbidden, launcher)

    def test_owned_launcher_keeps_public_process_and_handle_ownership(self):
        launcher = (ROOT / 'backend/native/tool_launcher_windows.c').read_text()
        self.assertLess(launcher.index('CREATE_SUSPENDED'), launcher.index('AssignProcessToJobObject'))
        self.assertLess(launcher.index('AssignProcessToJobObject'), launcher.index('ResumeThread'))
        for required in ['JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE', 'CREATE_NO_WINDOW',
                         'PROC_THREAD_ATTRIBUTE_HANDLE_LIST', 'DuplicateHandle', 'STARTF_USESTDHANDLES']:
            self.assertIn(required, launcher)

    def test_bundle_copies_only_owned_launcher_and_removes_all_retired_interposers(self):
        source = (ROOT / 'tool/bundle_backend.py').read_text()
        tree = ast.parse(source)
        assignment = next(item for item in tree.body if isinstance(item, ast.Assign)
                          and any(isinstance(target, ast.Name) and target.id == 'native_files'
                                  for target in item.targets))
        self.assertEqual(['busydata_tool_launcher.exe', 'busydata_windows_files.dll'],
                         ast.literal_eval(assignment.value.body))
        self.assertEqual([], ast.literal_eval(assignment.value.orelse))
        stale_loop = next(item for item in tree.body if isinstance(item, ast.For)
                          and isinstance(item.target, ast.Name) and item.target.id == 'stale'
                          and isinstance(item.iter, ast.Tuple))
        self.assertEqual({'busydata_hostname_forward.dll', 'libbusydata_hostname_forward.so'},
                         set(ast.literal_eval(stale_loop.iter)))
        removal = stale_loop.body[0].value
        self.assertIsInstance(removal, ast.Call)
        self.assertEqual('unlink', removal.func.attr)
        self.assertIsInstance(removal.func.value, ast.BinOp)
        self.assertIsInstance(removal.func.value.op, ast.Div)
        self.assertEqual('native', removal.func.value.left.id)
        self.assertEqual('stale', removal.func.value.right.id)
        cmake = (ROOT / 'backend/native/CMakeLists.txt').read_text()
        self.assertNotIn('hostname_forward', cmake)
        self.assertNotIn('bcrypt', cmake)
        self.assertNotIn('psapi', cmake)
        for fixture in ['pipe_transport_windows_test.c', 'tool_launcher_windows_test.c']:
            self.assertIn(fixture, cmake)

    def test_reviewed_relay_policy_is_explicit_and_acknowledged_before_success(self):
        native = ROOT / 'backend/src/main/java/io/busystack/busydata/security'
        transport = (native / 'NativeToolTransport.java').read_text()
        relay = (native / 'NativeMysqlRelay.java').read_text()
        for api in ['NativeMysqlRelay', 'SSLContext']:
            self.assertIn(api, transport)
        self.assertIn('setEndpointIdentificationAlgorithm("HTTPS")', relay)
        self.assertIn('Native SSH server does not offer the reviewed TLS policy', relay)
        for relative in ['transfers/NativeToolChecks.java', 'transfers/Transfers.java', 'rpc/WorkbenchService.java']:
            source = (ROOT / 'backend/src/main/java/io/busystack/busydata' / relative).read_text()
            self.assertNotIn('NativeToolTransport.requireSupported(', source)
        transfers = (ROOT / 'backend/src/main/java/io/busystack/busydata/transfers/Transfers.java').read_text()
        self.assertIn('builder.environment().put("PGHOSTADDR","127.0.0.1")', transfers)
        self.assertIn('NativeToolTransport.sanitize(builder)', transfers)
        self.assertIn('nativeContext(profile,rootSnapshot)', transfers)
        native_operation = transfers[transfers.index('Path defaults=null;'): ]
        self.assertLess(native_operation.index('relay.check()'), native_operation.index('commit.commit()'))
        self.assertIn('relay.close()', transfers)
        launcher = (ROOT / 'backend/native/tool_launcher_windows.c').read_text()
        self.assertLess(launcher.index('if(*length+3>=32767)return 0;'),
                        launcher.index("if(*length)out[(*length)++]=L' '"))
        for guard in ['CreateNamedPipeW', 'GetNamedPipeClientProcessId',
                      'PIPE_REJECT_REMOTE_CLIENTS', 'FILE_FLAG_FIRST_PIPE_INSTANCE',
                      'SetEntriesInAclW', 'client_pid!=process.dwProcessId']:
            self.assertIn(guard, launcher)

if __name__ == '__main__':
    unittest.main()
