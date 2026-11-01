"""Publish complete generated Linux bundle copies without changing input modes."""
import os
from pathlib import Path
import stat


MAX_PUBLIC_BUNDLE_ENTRIES = 40000


def _inventory(bundle):
    bundle = Path(bundle).absolute()
    if bundle.is_symlink() or bundle.resolve(strict=True) != bundle or not bundle.is_dir():
        raise RuntimeError('Public bundle root must be a direct directory')
    entries, pending = [], [bundle]
    while pending:
        path = pending.pop()
        info = path.lstat()
        if len(entries) >= MAX_PUBLIC_BUNDLE_ENTRIES:
            raise RuntimeError('Public bundle entry budget exceeded')
        if info.st_uid != os.getuid():
            raise RuntimeError('Public bundle entry has a different owner')
        entries.append((path, info))
        if stat.S_ISLNK(info.st_mode):
            if not path.resolve(strict=True).is_relative_to(bundle):
                raise RuntimeError('Public bundle link escapes its generated root')
        elif stat.S_ISDIR(info.st_mode):
            with os.scandir(path) as children:
                for child in children:
                    if len(entries) + len(pending) >= MAX_PUBLIC_BUNDLE_ENTRIES:
                        raise RuntimeError('Public bundle entry budget exceeded')
                    pending.append(Path(child.path))
        elif not stat.S_ISREG(info.st_mode) or info.st_nlink != 1:
            raise RuntimeError('Public bundle requires unshared regular files')
    return bundle, entries


def _mode(info):
    return 0o755 if stat.S_ISDIR(info.st_mode) else 0o644 | (info.st_mode & 0o111)


def publish_public_bundle(bundle):
    """Only complete generated copies may enter this publication boundary.

    Preflight the entire bounded tree before chmod. Parents, input caches,
    original SDKs, private state and symlink targets are never chmod targets.
    """
    bundle, entries = _inventory(bundle)
    directories = files = links = 0
    for path, before in sorted(entries, key=lambda entry: entry[0].as_posix()):
        current = path.lstat()
        identity = lambda info: (info.st_dev, info.st_ino, info.st_mode, info.st_uid, info.st_nlink)
        if identity(current) != identity(before) or not path.resolve(strict=True).is_relative_to(bundle):
            raise RuntimeError('Public bundle changed before publication')
        if stat.S_ISLNK(before.st_mode):
            links += 1
        else:
            path.chmod(_mode(before), follow_symlinks=False)
            directory = stat.S_ISDIR(before.st_mode)
            directories += directory
            files += not directory
    return {'policy': 'linux-public-copy-v1', 'directories': directories,
            'files': files, 'symlinks': links, 'entryLimit': MAX_PUBLIC_BUNDLE_ENTRIES}


def validate_public_bundle(bundle):
    """Check the published contract; validation never repairs an artifact."""
    _, entries = _inventory(bundle)
    for _, info in entries:
        if not stat.S_ISLNK(info.st_mode) and stat.S_IMODE(info.st_mode) != _mode(info):
            raise RuntimeError('Public bundle permissions differ from publication policy')


def validate_public_payload_paths(bundle, required_files):
    """Read-only validation of published files, including foreign-owned primes.

    Unlike publication, this operation cannot change modes or require the current
    UID to own packaged files. Every checked path must still be direct, publicly
    readable, and traversable through public directories inside the payload root.
    Unrelated staged-package entries and private parents are outside this scope.
    """
    bundle = Path(bundle).absolute()
    if bundle.is_symlink() or bundle.resolve(strict=True) != bundle or not bundle.is_dir():
        raise ValueError('Public payload root must be a direct directory')
    if stat.S_IMODE(bundle.lstat().st_mode) != 0o755:
        raise ValueError('Public payload permissions differ from publication policy')
    checked = {bundle: True}
    directories, files = 1, 0
    for index, name in enumerate(required_files):
        if index >= MAX_PUBLIC_BUNDLE_ENTRIES:
            raise ValueError('Public payload entry budget exceeded')
        relative = Path(name)
        if (relative.is_absolute() or not relative.parts or '..' in relative.parts
                or len(str(relative)) > 4096):
            raise ValueError('Public payload file must be a relative path')
        for depth in range(1, len(relative.parts) + 1):
            path = bundle.joinpath(*relative.parts[:depth])
            directory = depth < len(relative.parts)
            if path in checked:
                if checked[path] != directory:
                    raise ValueError('Public payload requires direct directories and regular files')
                continue
            if len(checked) >= MAX_PUBLIC_BUNDLE_ENTRIES:
                raise ValueError('Public payload entry budget exceeded')
            info = path.lstat()
            if not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)):
                raise ValueError('Public payload requires direct directories and regular files')
            if stat.S_IMODE(info.st_mode) != _mode(info):
                raise ValueError('Public payload permissions differ from publication policy')
            checked[path] = directory
            directories += directory
            files += not directory
    return {'policy': 'linux-public-paths-v1', 'directories': directories,
            'files': files, 'entryLimit': MAX_PUBLIC_BUNDLE_ENTRIES}
