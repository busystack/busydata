import errno
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

from native_runtime_cleanup import remove_native_runtime


@unittest.skipUnless(sys.platform == 'linux', 'Linux native runtime cleanup')
class NativeRuntimeCleanupTest(unittest.TestCase):
    def setUp(self):
        self.runtime = Path(tempfile.mkdtemp(prefix='bdna-', dir='/tmp'))
        self.addCleanup(lambda: shutil.rmtree(self.runtime, ignore_errors=True))
        (self.runtime / 'cache').mkdir()

    def test_late_cache_creation_and_descendant_removal_are_bounded_retries(self):
        original = shutil.rmtree
        for code in (errno.ENOTEMPTY, errno.ENOENT):
            with self.subTest(code=code):
                calls = []
                def remove(path):
                    calls.append(path)
                    if len(calls) == 1:
                        (path / 'cache' / 'shader').write_bytes(b'owned cache')
                        if code == errno.ENOENT:
                            (path / 'cache' / 'shader').unlink()
                        raise OSError(code, 'Private cache teardown race')
                    original(path)
                with patch('native_runtime_cleanup.shutil.rmtree', side_effect=remove), \
                        patch('native_runtime_cleanup.time.sleep') as pause:
                    remove_native_runtime(self.runtime)
                self.assertEqual([self.runtime, self.runtime], calls)
                pause.assert_called_once_with(0.1)
                self.assertFalse(self.runtime.exists())
                self.runtime.mkdir()
                (self.runtime / 'cache').mkdir()

    def test_other_io_failures_are_never_retried_or_swallowed(self):
        for code in (errno.EACCES, errno.ENOSPC):
            with self.subTest(code=code), \
                    patch('native_runtime_cleanup.shutil.rmtree', side_effect=OSError(code, 'Failure')) as remove, \
                    patch('native_runtime_cleanup.time.sleep') as pause:
                with self.assertRaises(OSError) as failure:
                    remove_native_runtime(self.runtime)
                self.assertEqual(code, failure.exception.errno)
                remove.assert_called_once_with(self.runtime)
                pause.assert_not_called()
                self.assertTrue(self.runtime.is_dir())

    def test_recreated_root_is_not_deleted_on_retry(self):
        moved = self.runtime.with_name(self.runtime.name + '-original')
        self.addCleanup(lambda: shutil.rmtree(moved, ignore_errors=True))
        def replace(path):
            path.rename(moved)
            path.mkdir()
            (path / 'replacement').write_bytes(b'preserve')
            raise OSError(errno.ENOTEMPTY, 'Replaced root')
        with patch('native_runtime_cleanup.shutil.rmtree', side_effect=replace) as remove, \
                patch('native_runtime_cleanup.time.sleep'):
            with self.assertRaisesRegex(ValueError, 'identity changed'):
                remove_native_runtime(self.runtime)
            remove.assert_called_once()
        self.assertEqual(b'preserve', (self.runtime / 'replacement').read_bytes())

    def test_retry_exhaustion_remains_a_cleanup_failure(self):
        with patch('native_runtime_cleanup.shutil.rmtree', side_effect=OSError(errno.ENOTEMPTY, 'Still busy')) as remove, \
                patch('native_runtime_cleanup.time.sleep') as pause:
            with self.assertRaises(OSError):
                remove_native_runtime(self.runtime)
        self.assertEqual(30, remove.call_count)
        self.assertEqual(29, pause.call_count)
        self.assertTrue(self.runtime.is_dir())

    def test_unowned_paths_and_root_symlinks_are_rejected(self):
        outside = Path(tempfile.mkdtemp(prefix='native-other-', dir='/tmp'))
        self.addCleanup(lambda: shutil.rmtree(outside))
        (outside / 'preserved').write_bytes(b'preserve')
        with self.assertRaises(ValueError):
            remove_native_runtime(outside)
        shutil.rmtree(self.runtime)
        self.runtime.symlink_to(outside, target_is_directory=True)
        try:
            with self.assertRaises(ValueError):
                remove_native_runtime(self.runtime)
            self.assertEqual(b'preserve', (outside / 'preserved').read_bytes())
        finally:
            self.runtime.unlink()


if __name__ == '__main__':
    unittest.main()
