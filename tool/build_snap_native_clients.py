#!/usr/bin/env python3
"""Build exact client-only source for a strict core24 Snap; no host-tool assumption."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def sha256(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def execute(arguments, directory=None):
    subprocess.run([str(value) for value in arguments], cwd=directory, check=True)


def native_linker_flags(runtime_path, engine):
    """Supported linker configuration; never rewrite an upstream executable."""
    flags = ['-Wl,-rpath,' + runtime_path]
    # The GNOME content snap exports an older libpq through LD_LIBRARY_PATH.
    # DT_RPATH keeps the matching package-owned PostgreSQL library first.
    if engine == 'postgresql':
        flags.insert(0, '-Wl,--disable-new-dtags')
    return flags


def postgres_configure_linker_flags():
    # Autoconf preserves the value in Makefile.global. Make consumes one dollar
    # and the shell's backslash protects the remaining literal ORIGIN. Quotes
    # inside configure's variable would reach gcc as literal filename bytes.
    return " ".join(flag.replace("$", r"\$$")
                    for flag in native_linker_flags('$ORIGIN/../lib', 'postgresql'))


def copy_upstream_binary(source, destination):
    shutil.copy2(source, destination)
    if sha256(source) != sha256(destination):
        raise RuntimeError('Upstream binary changed while being packaged')


def verify_source_tree(archive, source):
    """Prove the actual compiler input still matches the publisher archive."""
    source = source.resolve()
    expected = set()
    with tarfile.open(archive) as content:
        roots, size, count = set(), 0, 0
        for member in content:
            parts = Path(member.name).parts
            count += 1
            size += member.size
            if (not parts or Path(member.name).is_absolute() or '..' in parts
                    or count > 200000 or size > 6 * 1024**3):
                raise RuntimeError('Unsafe or excessive upstream source inventory')
            roots.add(parts[0])
            if len(roots) != 1:
                raise RuntimeError('Expected one publisher source root')
            relative = Path(*parts[1:])
            if not parts[1:]:
                continue
            path = source / relative
            expected.add(relative.as_posix())
            if not path.resolve().is_relative_to(source):
                raise RuntimeError('Upstream source path escapes its root')
            if member.isdir():
                valid = path.is_dir() and not path.is_symlink()
            elif member.issym():
                valid = path.is_symlink() and os.readlink(path) == member.linkname
            elif member.isfile() or member.islnk():
                valid = (path.is_file() and not path.is_symlink()
                         and bool(path.stat().st_mode & 0o111) == bool(member.mode & 0o111)
                         and sha256(path) == hashlib.file_digest(content.extractfile(member), 'sha256').hexdigest())
            else:
                valid = False
            if not valid:
                raise RuntimeError('Upstream source differs from publisher archive: ' + str(relative))
    actual = set()
    for path in source.rglob('*'):
        actual.add(path.relative_to(source).as_posix())
        if len(actual) > 200000:
            raise RuntimeError('Excessive actual source inventory')
    if actual != expected:
        raise RuntimeError('Actual source contains missing or additional paths')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('engine', choices=('postgresql', 'mysql', 'mariadb'))
    parser.add_argument('--source', type=Path)
    parser.add_argument('--build', type=Path, required=True)
    parser.add_argument('--install', type=Path, required=True)
    parser.add_argument('--archive', type=Path)
    parser.add_argument('--jobs', type=int, default=2)
    args = parser.parse_args()
    if not 1 <= args.jobs <= 4:
        parser.error('Use 1–4 bounded client build jobs')
    manifest = json.loads((ROOT / 'third_party/native_client_sources.json').read_text())
    record = next(item for item in manifest if item['engine'] == args.engine)
    args.build.mkdir(parents=True, exist_ok=True)
    archive = args.archive or args.build / record['name']
    if not archive.exists():
        partial = archive.with_suffix(archive.suffix + '.partial')
        try:
            total = 0
            with urllib.request.urlopen(record['url'], timeout=60) as remote, partial.open('wb') as output:
                while chunk := remote.read(65536):
                    total += len(chunk)
                    if total > 600 * 1024 * 1024:
                        raise RuntimeError('Native client source download exceeds 600MiB')
                    output.write(chunk)
            partial.replace(archive)
        finally:
            partial.unlink(missing_ok=True)
    if sha256(archive) != record['sha256']:
        raise RuntimeError('Native source checksum mismatch')
    source = args.source
    if source is None:
        extracted = args.build / 'source'
        extracted.mkdir(exist_ok=True)
        if not (extracted / '.extracted').exists():
            with tarfile.open(archive, 'r|*') as content:
                size, count = 0, 0
                for member in content:
                    count += 1
                    size += member.size
                    if count > 200000 or size > 6 * 1024**3:
                        raise RuntimeError('Native source extraction resource limit')
                    content.extract(member, extracted, filter='data')
            (extracted / '.extracted').write_text(record['sha256'])
        directories = [path for path in extracted.iterdir() if path.is_dir()]
        if len(directories) != 1:
            raise RuntimeError('Expected one source root')
        source = directories[0]
    source = source.resolve()
    verify_source_tree(archive, source)
    objects = (args.build / 'objects').resolve()
    destination = args.install.resolve() / 'backend/tools' / args.engine
    binary_directory = destination / 'bin'
    binary_directory.mkdir(parents=True, exist_ok=True)
    flags = []
    if args.engine == 'postgresql':
        objects.mkdir(exist_ok=True)
        flags = ['--without-readline', '--without-icu', '--with-openssl',
                 '--disable-rpath', '--prefix=/backend/tools/postgresql']
        # Configure records these in Makefile.global. A command-line Make
        # override would suppress PostgreSQL's per-target -L additions and
        # prevent its clients from finding libpq/libpgcommon/libpgport.
        flags.append('LDFLAGS=' + postgres_configure_linker_flags())
        execute([source / 'configure', *flags], objects)
        execute(['make', '-j', args.jobs, '-C', 'src/backend', 'generated-headers'], objects)
        execute(['make', '-j', args.jobs, '-C', 'src/bin/pg_dump', 'all'], objects)
        execute(['make', '-j', args.jobs, '-C', 'src/bin/psql', 'all'], objects)
        tools = {'pg_dump': objects / 'src/bin/pg_dump/pg_dump', 'psql': objects / 'src/bin/psql/psql'}
    else:
        flags = ['-DCMAKE_BUILD_TYPE=Release', '-DWITHOUT_SERVER=ON', '-DWITH_UNIT_TESTS=OFF',
                 '-DWITH_SSL=system', '-DCMAKE_INSTALL_RPATH=$ORIGIN/../lib',
                 '-DCMAKE_BUILD_WITH_INSTALL_RPATH=ON',
                 '-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=OFF']
        if args.engine == 'mysql':
            flags += ['-DWITH_EDITLINE=bundled', '-DWITH_AUTHENTICATION_LDAP=OFF', '-DWITH_AUTHENTICATION_CLIENT_PLUGINS=OFF', '-DWITH_SASL=system', '-DWITH_KERBEROS=none']
        execute(['cmake', '-S', source, '-B', objects, *flags])
        names = ('mysql', 'mysqldump') if args.engine == 'mysql' else ('mariadb', 'mariadb-dump')
        execute(['cmake', '--build', objects, '--parallel', args.jobs, '--target', *names])
        tools = {name: objects / ('runtime_output_directory' if args.engine == 'mysql' else 'client') / name for name in names}
    verify_source_tree(archive, source)
    # Configure embeds the eventual package prefix; discover only build-owned
    # shared libraries while checking the pre-relocation binaries.
    shared = []
    for path in objects.rglob("*.so*"):
        if len(shared) >= 2000:
            raise RuntimeError("Native client shared-library inventory limit")
        shared.append(path)
    build_environment = dict(os.environ)
    build_environment["LD_LIBRARY_PATH"] = ":".join(sorted({str(path.parent) for path in shared}))
    owned_libraries = {}
    versions = {}
    for name, built in tools.items():
        if not built.is_file():
            raise RuntimeError('Expected client binary was not built: ' + name)
        installed = binary_directory / name
        copy_upstream_binary(built, installed)
        dependencies = subprocess.run(['ldd', str(built)], check=True, capture_output=True, text=True, env=build_environment).stdout
        for library in re.findall(r'(?:=>\s+)?(/[^\s]+)', dependencies):
            path = Path(library).resolve()
            if path.is_relative_to(objects) or path.is_relative_to(source):
                owned_libraries[Path(library).name] = path
        versions[name] = subprocess.run([str(built), '--version'], check=True, capture_output=True, text=True, env=build_environment).stdout.strip()
        if record['name'].split('-')[1].split('.tar')[0] not in versions[name]:
            raise RuntimeError('Built tool does not report the pinned release: ' + name)
    libraries = destination / 'lib'
    libraries.mkdir(exist_ok=True)
    for name, path in owned_libraries.items():
        copy_upstream_binary(path, libraries / name)
    relocated_versions = {}
    for name, expected in versions.items():
        actual = subprocess.run([str(binary_directory / name), '--version'], check=True, capture_output=True, text=True).stdout.strip()
        # MySQL's version banner includes argv[0], which changes on relocation.
        built_banner = expected.replace(str(tools[name]), name, 1)
        installed_banner = actual.replace(str(binary_directory / name), name, 1)
        if installed_banner != built_banner:
            raise RuntimeError('Installed client runtime differs from its built version: ' + name)
        relocated_versions[name] = actual
    sources = destination / 'sources'
    sources.mkdir(exist_ok=True)
    shutil.copy2(archive, sources / archive.name)
    shutil.copy2(Path(__file__), sources / 'busydata-client-build.py')
    notices = destination / 'notices'
    notices.mkdir(exist_ok=True)
    count = 0
    for name in ('COPYRIGHT', 'COPYING', 'LICENSE', 'LICENSE.txt', 'LICENSE.md', 'LICENSES'):
        path = source / name
        if path.is_file():
            shutil.copy2(path, notices / name)
            count += 1
    if not count:
        raise RuntimeError('Native source license/notice is missing')
    package_versions = subprocess.run(['dpkg-query', '-W', '-f=${Package}\t${Version}\n'], check=True, capture_output=True, text=True).stdout
    report = {'source': record, 'configuration': flags,
              'configureLinkerFlags': postgres_configure_linker_flags() if args.engine == 'postgresql' else None,
              'upstreamSourceModified': False, 'postLinkBinaryModified': False,
              'buildJobs': args.jobs, 'versions': versions, 'installedVersions': relocated_versions,
              'builderPackages': package_versions.splitlines(),
              'files': [{'path': str(path.relative_to(destination)), 'sha256': sha256(path)}
                        for path in sorted(destination.rglob('*')) if path.is_file() and path.name != 'native-client-build.json'],
              'sourceIncluded': True, 'serverBuilt': False,
              'builtTargets': list(tools), 'builderOperatingSystem': Path('/etc/os-release').read_text()}
    (destination / 'native-client-build.json').write_text(json.dumps(report, indent=2) + '\n')
    print(destination)


if __name__ == '__main__':
    main()
