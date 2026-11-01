"""Genuine Windows IPC, literal arguments, isolation and owned-child acceptance."""
import concurrent.futures
import ctypes
from ctypes import wintypes
import os
from pathlib import Path
import queue
import shutil
import tempfile
import secrets
import socket
import subprocess
import sys
import threading
import unittest

LAUNCHER, CLIENT, OWNER_FIXTURE = sys.argv[1:4]
del sys.argv[1:4]
LITERAL = 'Unicode 漢 path with "quote" and trailing slash' + chr(92)
kernel = ctypes.WinDLL('kernel32', use_last_error=True)
kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
kernel.OpenProcess.restype = wintypes.HANDLE
kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
kernel.WaitForSingleObject.restype = wintypes.DWORD
kernel.CloseHandle.argtypes = [wintypes.HANDLE]

class Bridge:
    def __init__(self):
        self.socket = socket.socket()
        self.socket.bind(('127.0.0.1', 0))
        self.socket.listen(1)
        self.socket.settimeout(10)
        self.token = secrets.token_bytes(32)
        self.name = 'BusyData.Native.' + secrets.token_hex(16)
        self.environment = dict(os.environ, BUSYDATA_NATIVE_PIPE=self.name,
            BUSYDATA_NATIVE_PORT=str(self.socket.getsockname()[1]),
            BUSYDATA_NATIVE_TOKEN=self.token.hex())
        self.finished = concurrent.futures.Future()
        self.connection = None
        self.thread = threading.Thread(target=self.serve, daemon=True)
        self.thread.start()
    def serve(self):
        try:
            with self.socket.accept()[0] as connection:
                self.connection = connection
                connection.settimeout(20)
                token = b''
                while len(token) < 32:
                    chunk = connection.recv(32 - len(token))
                    if not chunk: raise AssertionError('Private bridge authentication was truncated')
                    token += chunk
                if not secrets.compare_digest(token, self.token):
                    raise AssertionError('Wrong operation-bound private bridge identity')
                count = 0
                while True:
                    chunk = connection.recv(65536)
                    if not chunk: break
                    count += len(chunk)
                    connection.sendall(chunk)
                self.finished.set_result(count)
        except BaseException as failure:
            self.finished.set_exception(failure)
    def command(self, mode='--assert-child'):
        return [LAUNCHER, CLIENT, self.name, mode, LITERAL]
    def close(self):
        if self.connection:
            try: self.connection.shutdown(socket.SHUT_RDWR)
            except OSError: pass
        self.socket.close()
        self.thread.join(timeout=2)

class NativePipeTransport(unittest.TestCase):
    def roundtrip(self):
        bridge = Bridge()
        try:
            result = subprocess.run(bridge.command(), env=bridge.environment,
                check=True, capture_output=True, timeout=30)
            self.assertEqual(1048576, bridge.finished.result(timeout=5))
            self.assertIn(b'unchanged Winsock passed', result.stdout)
        finally: bridge.close()
    def test_exact_binary_unicode_unmodified_resolver_and_private_environment(self):
        self.roundtrip()
    def test_sequential_operations_have_independent_pipes_and_tokens(self):
        for _ in range(3): self.roundtrip()
    def test_concurrent_operations_do_not_cross_route(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            for task in [pool.submit(self.roundtrip) for _ in range(2)]: task.result(timeout=40)
    def test_client_failure_propagates_without_transport_fallback(self):
        environment = self.environment()
        result = subprocess.run([LAUNCHER, CLIENT, environment['BUSYDATA_NATIVE_PIPE'],
            '--child-failure', LITERAL], env=environment, timeout=15)
        self.assertEqual(61, result.returncode)
    def environment(self):
        return dict(os.environ, BUSYDATA_NATIVE_PIPE='BusyData.Native.' + secrets.token_hex(16),
            BUSYDATA_NATIVE_PORT='54321', BUSYDATA_NATIVE_TOKEN=secrets.token_hex(32))
    def reject(self, key, value):
        environment = self.environment()
        if value is None: environment.pop(key)
        else: environment[key] = value
        result = subprocess.run([LAUNCHER, CLIENT, 'unused', '--child-failure', LITERAL],
            env=environment, capture_output=True, timeout=10)
        self.assertEqual(4, result.returncode)
        self.assertNotIn(b'fixture', result.stdout + result.stderr)
    def test_missing_pipe(self): self.reject('BUSYDATA_NATIVE_PIPE', None)
    def test_other_pipe_prefix(self): self.reject('BUSYDATA_NATIVE_PIPE', 'Unreviewed.' + 'a' * 32)
    def test_pipe_path_substitution(self): self.reject('BUSYDATA_NATIVE_PIPE', 'BusyData.Native.' + '../' * 10 + 'aa')
    def test_short_pipe_identity(self): self.reject('BUSYDATA_NATIVE_PIPE', 'BusyData.Native.a')
    def test_oversized_pipe_identity(self): self.reject('BUSYDATA_NATIVE_PIPE', 'BusyData.Native.' + 'a' * 128)
    def test_missing_port(self): self.reject('BUSYDATA_NATIVE_PORT', None)
    def test_zero_port(self): self.reject('BUSYDATA_NATIVE_PORT', '0')
    def test_port_overflow(self): self.reject('BUSYDATA_NATIVE_PORT', '65536')
    def test_port_trailing_command(self): self.reject('BUSYDATA_NATIVE_PORT', '12&bad')
    def test_missing_token(self): self.reject('BUSYDATA_NATIVE_TOKEN', None)
    def test_short_token(self): self.reject('BUSYDATA_NATIVE_TOKEN', 'a' * 63)
    def test_oversized_token(self): self.reject('BUSYDATA_NATIVE_TOKEN', 'a' * 65)
    def test_nonhex_token(self): self.reject('BUSYDATA_NATIVE_TOKEN', 'z' * 64)
    def test_missing_client_cannot_fall_back_to_path(self):
        environment = self.environment()
        result = subprocess.run([LAUNCHER, str(Path(CLIENT).with_name('not-installed.exe'))],
            env=environment, timeout=10)
        self.assertNotEqual(0, result.returncode)
    def test_quoted_argument_change_is_detected(self):
        environment = self.environment()
        result = subprocess.run([LAUNCHER, CLIENT, environment['BUSYDATA_NATIVE_PIPE'],
            '--assert-child', LITERAL + 'different'], env=environment, timeout=15)
        self.assertEqual(7, result.returncode)
    def test_launcher_termination_reaps_owned_client(self):
        bridge = Bridge(); process = None; child = None
        try:
            process = subprocess.Popen(bridge.command('--child-hold'), env=bridge.environment,
                stdout=subprocess.PIPE, text=True)
            lines = queue.Queue(maxsize=1)
            threading.Thread(target=lambda: lines.put(process.stdout.readline()), daemon=True).start()
            child = kernel.OpenProcess(0x00100000, False, int(lines.get(timeout=15)))
            self.assertTrue(child)
            self.assertEqual(0x102, kernel.WaitForSingleObject(child, 0))
            process.terminate(); process.wait(timeout=5)
            self.assertEqual(0, kernel.WaitForSingleObject(child, 5000))
        finally:
            if process and process.poll() is None: process.kill(); process.wait(timeout=5)
            if child: kernel.CloseHandle(child)
            bridge.close()

class SecurityAttributes(ctypes.Structure):
    _fields_ = [('length', wintypes.DWORD), ('descriptor', wintypes.LPVOID),
                ('inherit', wintypes.BOOL)]

kernel.CreateEventW.argtypes = [ctypes.POINTER(SecurityAttributes), wintypes.BOOL,
                               wintypes.BOOL, wintypes.LPCWSTR]
kernel.CreateEventW.restype = wintypes.HANDLE
kernel.ResetEvent.argtypes = [wintypes.HANDLE]


class NativeProcessOwnership(unittest.TestCase):
    # This independent client deliberately exits without using the pipe. It
    # verifies launch ownership, not successful native database transport.
    def environment(self):
        return dict(os.environ, BUSYDATA_NATIVE_PIPE='BusyData.Native.' + secrets.token_hex(16),
                    BUSYDATA_NATIVE_PORT='54321', BUSYDATA_NATIVE_TOKEN=secrets.token_hex(32))

    def assert_owned_arguments(self, launcher=LAUNCHER):
        subprocess.run([launcher, OWNER_FIXTURE, '--assert-child', LITERAL],
                       env=self.environment(), stdin=subprocess.DEVNULL,
                       check=True, timeout=15)

    def test_sequential_literal_arguments_remain_owned(self):
        for _ in range(3):
            self.assert_owned_arguments()

    def test_concurrent_literal_arguments_remain_owned(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            for task in [pool.submit(self.assert_owned_arguments) for _ in range(2)]:
                task.result(timeout=20)

    def test_copied_launcher_requires_no_sibling_injection_library(self):
        with tempfile.TemporaryDirectory(prefix='busydata-process-owner-') as directory:
            copied = Path(directory) / Path(LAUNCHER).name
            shutil.copyfile(LAUNCHER, copied)
            self.assert_owned_arguments(str(copied))

    def test_exact_binary_stdio_and_separate_stderr(self):
        payload = b'UTF-8: \xe6\xbc\xa2\nNUL:\x00\r\n'
        result = subprocess.run([LAUNCHER, OWNER_FIXTURE, '--stdio'],
                                env=self.environment(), input=payload,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                timeout=15)
        self.assertEqual(0, result.returncode)
        self.assertEqual(payload, result.stdout)
        self.assertEqual(b'owned stderr\n', result.stderr)

    def test_unrelated_inheritable_handle_is_excluded_with_positive_control(self):
        attributes = SecurityAttributes(ctypes.sizeof(SecurityAttributes), None, True)
        event = kernel.CreateEventW(ctypes.byref(attributes), True, False, None)
        if not event:
            raise OSError(ctypes.get_last_error(), 'Cannot create owned handle fixture')
        try:
            arguments = [OWNER_FIXTURE, '--try-inherited-event', str(event)]
            subprocess.run(arguments, env=self.environment(), stdin=subprocess.DEVNULL,
                           close_fds=False, creationflags=subprocess.CREATE_NO_WINDOW,
                           check=True, timeout=15)
            self.assertEqual(0, kernel.WaitForSingleObject(event, 0),
                             'Direct positive control must inherit the owned event')
            if not kernel.ResetEvent(event):
                raise OSError(ctypes.get_last_error(), 'Cannot reset owned event')
            subprocess.run([LAUNCHER, *arguments], env=self.environment(),
                           stdin=subprocess.DEVNULL, close_fds=False,
                           check=True, timeout=15)
            self.assertEqual(0x102, kernel.WaitForSingleObject(event, 0),
                             'Selected client must not inherit an unrelated handle')
        finally:
            kernel.CloseHandle(event)


if __name__ == '__main__': unittest.main()
