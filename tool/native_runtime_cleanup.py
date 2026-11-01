"""Remove only an owned native-test runtime after its controller has stopped."""
import errno
import os
from pathlib import Path
import shutil
import stat
import time


def remove_native_runtime(runtime):
    runtime = Path(runtime)
    if runtime.parent != Path('/tmp') or not runtime.name.startswith('bdna-'):
        raise ValueError('Native runtime ownership boundary')
    try:
        original = runtime.lstat()
    except FileNotFoundError:
        return
    if not stat.S_ISDIR(original.st_mode) or original.st_uid != os.getuid():
        raise ValueError('Native runtime must be an owned directory')
    identity = original.st_dev, original.st_ino
    for attempt in range(30):
        try:
            current = runtime.lstat()
        except FileNotFoundError:
            return
        if (current.st_dev, current.st_ino) != identity:
            raise ValueError('Native runtime identity changed during cleanup')
        try:
            shutil.rmtree(runtime)
            return
        except OSError as failure:
            # Private display services can finish their cache writes while
            # D-Bus exits. Never retry a UI action or hide another I/O failure.
            if failure.errno not in (errno.ENOENT, errno.ENOTEMPTY) or attempt == 29:
                raise
            time.sleep(0.1)
