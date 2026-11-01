"""Lossless, bounded native evidence capture through supported GdkPixbuf APIs."""
import os
from pathlib import Path
import stat
import uuid


MAX_PIXELS = 16 * 1024 * 1024
MAX_PNG_BYTES = 4 * MAX_PIXELS + 1024 * 1024


def save_native_png(picture, path):
    """Encode without Gdk file loaders; publish only a complete owned PNG.

    GdkPixbuf.save_to_bufferv is the official PNG encoder, with the same empty
    option list as savev. The pixel bound precedes encoding; no pixels, options,
    dimensions or evidence paths are changed to make a capture fit.
    """
    width, height = picture.get_width(), picture.get_height()
    if (type(width) is not int or type(height) is not int or
            not 0 < width <= 8192 or not 0 < height <= 8192 or
            width * height > MAX_PIXELS):
        raise ValueError('Native PNG pixel budget')
    success, data = picture.save_to_bufferv('png', [], [])
    if not success or not isinstance(data, bytes) or not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise RuntimeError('Native PNG encoding failed')
    if len(data) > MAX_PNG_BYTES:
        raise ValueError('Native PNG byte budget')
    path = Path(path)
    directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    temporary = '.native-png-' + str(uuid.uuid4())
    created = False
    try:
        info = os.fstat(directory)
        if info.st_uid != os.geteuid() or info.st_mode & 0o022:
            raise RuntimeError('Native PNG directory ownership changed')
        try:
            previous = os.stat(path.name, dir_fd=directory, follow_symlinks=False)
        except FileNotFoundError:
            previous = None
        if previous is not None and (not stat.S_ISREG(previous.st_mode) or
                                     previous.st_uid != os.geteuid()):
            raise RuntimeError('Native PNG target ownership changed')
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                             0o600, dir_fd=directory)
        created = True
        with os.fdopen(descriptor, 'wb') as output:
            if output.write(data) != len(data):
                raise OSError('Native PNG write incomplete')
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path.name, src_dir_fd=directory, dst_dir_fd=directory)
        created = False
    finally:
        if created:
            os.unlink(temporary, dir_fd=directory)
        os.close(directory)
