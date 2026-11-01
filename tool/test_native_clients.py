"""Source pins and confined native-client paths must stay consistent."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tarfile
import unittest
from build_snap_native_clients import native_linker_flags, postgres_configure_linker_flags, copy_upstream_binary, sha256, verify_source_tree
from prepare_native_test_tools import write_launcher
import prepare_native_test_tools as fixture_tools
import verify_native_clients as packaged_clients
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]

class NativeClientConfigurationTest(unittest.TestCase):
    def test_compiler_source_must_match_the_pinned_archive_even_on_reuse(self):
        with tempfile.TemporaryDirectory(prefix='busydata-source-identity-') as temporary:
            root = Path(temporary)
            source = root / 'publisher-1.0'
            source.mkdir()
            (source / 'client.c').write_text('int main(void) { return 0; }\n')
            archive = root / 'publisher-1.0.tar.gz'
            with tarfile.open(archive, 'w:gz') as content:
                content.add(source, arcname=source.name)
            verify_source_tree(archive, source)
            (source / 'client.c').write_text('int main(void) { return 1; }\n')
            with self.assertRaisesRegex(RuntimeError, 'differs from publisher archive'):
                verify_source_tree(archive, source)
            (source / 'client.c').write_text('int main(void) { return 0; }\n')
            (source / 'downstream.c').write_text('/* synthetic unauthorized addition */\n')
            with self.assertRaisesRegex(RuntimeError, 'missing or additional paths'):
                verify_source_tree(archive, source)

    @unittest.skipUnless(sys.platform == 'linux', 'Official ELF fixture launchers are Linux-specific')
    def test_fixture_launcher_preserves_official_binary_and_arguments(self):
        with tempfile.TemporaryDirectory(prefix='busydata-loader-fixture-') as temporary:
            root = Path(temporary)
            (root / 'upstream').mkdir()
            (root / 'lib').mkdir()
            source = root / 'arguments.c'
            source.write_text('#include <stdio.h>\nint main(int n, char **v) { if(n != 3) return 2; printf("%s|%s", v[1], v[2]); return 0; }\n')
            subprocess.run(['cc', str(source), '-o', str(root / 'upstream/fixture')], check=True)
            dependencies = subprocess.check_output(['ldd', str(root / 'upstream/fixture')], text=True)
            import re
            paths = set(re.findall(r'(?:=>\s+)?(/[^\s]+)', dependencies))
            loader = next(Path(path).name for path in paths if Path(path).name.startswith('ld-linux'))
            for path in paths:
                shutil.copy2(path, root / 'lib' / Path(path).name)
            before = sha256(root / 'upstream/fixture')
            write_launcher(root / 'fixture', 'fixture', loader)
            result = subprocess.check_output([str(root / 'fixture'), 'space and 日本語', '$(untouched)'], text=True)
            self.assertEqual('space and 日本語|$(untouched)', result)
            self.assertEqual(before, sha256(root / 'upstream/fixture'))
            with self.assertRaises(ValueError):
                write_launcher(root / 'invalid', '../escape', loader)

    @unittest.skipUnless(sys.platform == 'linux', 'Official ELF fixture launchers are Linux-specific')
    def test_fixture_loader_overrides_transitive_rpath_and_desktop_library_path_without_rewriting(self):
        import re
        for tool in ('cc', 'ldd'):
            self.assertIsNotNone(shutil.which(tool), 'Native loader regression requires ' + tool)
        with tempfile.TemporaryDirectory(prefix='busydata-loader-') as temporary:
            root = Path(temporary) / 'private path 漢'
            libraries, binaries, desktop = root / 'lib', root / 'upstream', root / 'desktop'
            for directory in (libraries, binaries, desktop):
                directory.mkdir(parents=True, exist_ok=True)
            leaf, middle, source = root / 'leaf.c', root / 'middle.c', root / 'client.c'
            leaf.write_text('int selected_value(void) { return 17; }\n')
            subprocess.run(['cc', '-shared', '-fPIC', str(leaf), '-Wl,-soname,libbusydata_leaf.so', '-o', str(libraries / 'libbusydata_leaf.so')], check=True)
            leaf.write_text('int selected_value(void) { return 9; }\n')
            subprocess.run(['cc', '-shared', '-fPIC', str(leaf), '-Wl,-soname,libbusydata_leaf.so', '-o', str(desktop / 'libbusydata_leaf.so')], check=True)
            middle.write_text('extern int selected_value(void); int middle_value(void) { return selected_value(); }\n')
            subprocess.run(['cc', '-shared', '-fPIC', str(middle), '-L' + str(libraries), '-lbusydata_leaf',
                            '-Wl,-soname,libbusydata_middle.so', '-Wl,--disable-new-dtags', '-Wl,-rpath,' + str(desktop),
                            '-o', str(libraries / 'libbusydata_middle.so')], check=True)
            source.write_text('extern int middle_value(void); int main(void) { return middle_value() == 17 ? 0 : 1; }\n')
            binary = binaries / 'fixture'
            subprocess.run(['cc', str(source), '-L' + str(libraries), '-lbusydata_middle',
                            '-Wl,-rpath-link,' + str(libraries), '-Wl,--disable-new-dtags', '-Wl,-rpath,' + str(desktop),
                            '-o', str(binary)], check=True)
            dependencies = subprocess.check_output(['ldd', '/bin/true'], text=True)
            paths = set(re.findall(r'(?:=>\s+)?(/[^\s]+)', dependencies))
            loader = next(Path(path).name for path in paths if Path(path).name.startswith('ld-linux'))
            for path in paths:
                shutil.copy2(path, libraries / Path(path).name)
            before = {path: sha256(path) for path in [binary, *libraries.iterdir()]}
            wrong_environment = dict(os.environ, LD_LIBRARY_PATH=str(libraries))
            self.assertNotEqual(0, subprocess.run([str(binary)], env=wrong_environment).returncode,
                                'The first-party fixture must reproduce the conflicting upstream RPATH')
            write_launcher(root / 'fixture', 'fixture', loader)
            environment = dict(os.environ, LD_LIBRARY_PATH=str(desktop), LD_BIND_NOW='1')
            self.assertEqual(0, subprocess.run([str(root / 'fixture')], env=environment).returncode)
            self.assertEqual(before, {path: sha256(path) for path in before},
                             'No upstream executable, loader or shared library may be rewritten')

    @unittest.skipUnless(sys.platform == 'linux', 'Snap client linkage is Linux-specific')
    def test_postgresql_client_prefers_its_matching_library_over_desktop_platform(self):
        for tool in ('cc', 'make', 'readelf'):
            self.assertIsNotNone(shutil.which(tool), 'Native packaging regression requires ' + tool)
        with tempfile.TemporaryDirectory(prefix='busydata-client-linkage-') as temporary:
            root = Path(temporary)
            for directory in ('bin', 'lib', 'desktop'):
                (root / directory).mkdir()
            library = root / 'library.c'
            library.write_text('int client_version(void) { return VERSION; }\n')
            for directory, version in (('lib', 17), ('desktop', 16)):
                subprocess.run(['cc', '-shared', '-fPIC', '-DVERSION=' + str(version),
                                '-Wl,-soname,libbusydata_fixture.so', str(library),
                                '-o', str(root / directory / 'libbusydata_fixture.so')], check=True)
            source = root / 'client.c'
            source.write_text('extern int client_version(void); int main(void) { return client_version() == 17 ? 0 : 1; }\n')
            client = root / 'bin/client'
            subprocess.run(['cc', str(source), '-L' + str(root / 'lib'),
                            '-lbusydata_fixture', *native_linker_flags('$ORIGIN/../lib', 'postgresql'),
                            '-o', str(client)], check=True)
            linked_digest = sha256(client)
            environment = dict(os.environ, LD_LIBRARY_PATH=str(root / 'desktop'), LD_BIND_NOW='1')
            self.assertEqual(0, subprocess.run([str(client)], env=environment).returncode,
                             'Desktop libraries must not replace the client-matched PostgreSQL library')
            self.assertEqual(linked_digest, sha256(client))
            dynamic = subprocess.check_output(['readelf', '-d', str(client)], text=True)
            self.assertIn('(RPATH)', dynamic)
            self.assertIn('$ORIGIN/../lib', dynamic)
            self.assertNotIn('(RUNPATH)', dynamic)
            # Configure substitutes LDFLAGS into the upstream Makefile, whose
            # per-target library directories must remain appendable.
            (root / 'Makefile').write_text(
                'LDFLAGS = ' + postgres_configure_linker_flags() + '\n'
                'LDFLAGS += -Llib\n'
                'all:\n\tcc client.c $(LDFLAGS) -lbusydata_fixture -o linked\n')
            subprocess.run(['make'], cwd=root, check=True)
            copy_upstream_binary(root / 'linked', client)
            self.assertEqual(sha256(root / 'linked'), sha256(client))
            self.assertEqual(0, subprocess.run([str(client)], env=environment).returncode)

    def test_snap_sources_are_exact_checksum_pinned_manifest_entries(self):
        recipe = (ROOT / 'snap/snapcraft.yaml').read_text()
        records = json.loads((ROOT / 'third_party/native_client_sources.json').read_text())
        self.assertEqual({'postgresql', 'mysql', 'mariadb'}, {item['engine'] for item in records})
        for item in records:
            self.assertRegex(item['sha256'], '^[0-9a-f]{64}$')
            self.assertIn('source: ' + item['url'], recipe)
            self.assertIn('source-checksum: sha256/' + item['sha256'], recipe)
            self.assertIn('build_snap_native_clients.py" ' + item['engine'], recipe)
        self.assertIn('confinement: strict', recipe)
        self.assertNotIn('classic', recipe)

    def test_package_client_matrix_matches_backend_and_frontend(self):
        dart = (ROOT / 'lib/src/platform/common/packaged_database_tools.dart').read_text()
        java = (ROOT / 'backend/src/main/java/io/busystack/busydata/transfers/NativeToolChecks.java').read_text()
        builder = (ROOT / 'tool/build_snap_native_clients.py').read_text()
        for name in ['pg_dump', 'psql', 'mysql', 'mysqldump', 'mariadb', 'mariadb-dump']:
            self.assertIn(name, dart)
            self.assertIn(name, java)
            self.assertIn(name, builder)
        self.assertIn('sourceIncluded', builder)
        self.assertIn('serverBuilt', builder)
        self.assertIn('filter=\'data\'', builder)
        self.assertIn('Installed client runtime differs', builder)

@unittest.skipUnless(sys.platform == 'linux', 'Official ELF fixture publication is Linux-specific')
class NativeFixturePublicationTest(unittest.TestCase):
    def populate(self, directory, value=b'official-fixture-bytes'):
        records = []
        for engine, (image, tools) in fixture_tools.CLIENTS.items():
            base = directory / engine
            (base / 'upstream').mkdir(parents=True)
            (base / 'lib').mkdir()
            loader = base / 'lib/ld-fixture'
            loader.write_text('#!/bin/sh\nprogram=$6\nprintf "ready\\n"\nIFS= read -r released\ncat "$program"\n')
            loader.chmod(0o755)
            for tool in tools:
                binary = base / 'upstream' / tool
                binary.write_bytes(value + b'-' + tool.encode())
                binary.chmod(0o755)
                fixture_tools.write_launcher(base / tool, tool, loader.name)
                records.append({'engine': engine, 'tool': tool, 'image': image,
                    'imageId': 'sha256:' + '1' * 64, 'repositoryDigests': [image + '@sha256:' + '2' * 64],
                    'launcher': engine + '/' + tool, 'upstreamBinary': engine + '/upstream/' + tool,
                    'upstreamBinarySha256': fixture_tools.checksum(binary), 'upstreamBinaryModified': False,
                    'runtime': [{'path': engine + '/lib/ld-fixture', 'source': '/fixture/ld-fixture',
                                 'sha256': fixture_tools.checksum(loader)}]})
        return records

    def test_repeat_preparation_reacquires_and_preserves_old_generation_and_consumer_layout(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'native-tools'
            with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate) as acquire:
                fixture_tools.prepare(target)
                old = target.resolve()
                old_inventory = fixture_tools.file_inventory(old)
                fixture_tools.prepare(target)
                self.assertEqual(2, acquire.call_count, 'A successful repeated preparation must really reacquire clients')
            self.assertNotEqual(old, target.resolve())
            self.assertEqual(old_inventory, fixture_tools.file_inventory(old))
            fixture_tools.validate_generation(old)
            fixture_tools.validate_generation(target.resolve())
            # Match both NativeBackupIT and NativeBackupTlsIT's existing public
            # consumer choice: a bin directory would bypass the wrapper.
            for engine, (_, tools) in fixture_tools.CLIENTS.items():
                directory = target / engine
                selected = directory / 'bin' if (directory / 'bin').is_dir() else directory
                self.assertEqual(directory, selected)
                for tool in tools:
                    self.assertTrue((selected / tool).read_text().startswith('#!/bin/sh\n'))
                    self.assertTrue((directory / 'upstream' / tool).is_file())

    def test_failed_acquisition_keeps_prior_pointer_and_retry_builds_new_generation(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'native-tools'
            with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate):
                fixture_tools.prepare(target)
            old, inventory = target.resolve(), fixture_tools.file_inventory(target.resolve())
            def fail(directory):
                (directory / 'partial').write_bytes(b'partial acquisition')
                raise RuntimeError('Acquisition did not complete')
            with patch.object(fixture_tools, 'populate_generation', side_effect=fail):
                with self.assertRaisesRegex(RuntimeError, 'did not complete'):
                    fixture_tools.prepare(target)
            self.assertEqual(old, target.resolve())
            self.assertEqual(inventory, fixture_tools.file_inventory(old))
            self.assertEqual([], list(target.parent.glob('.native-tools.publish-*')))
            self.assertEqual([], list(target.parent.glob('native-tools.generations/.building-*')))
            with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate):
                fixture_tools.prepare(target)
            self.assertNotEqual(old, target.resolve())

    def test_failure_after_complete_rename_preserves_orphan_and_prior_pointer(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'native-tools'
            with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate):
                fixture_tools.prepare(target)
            old = target.resolve()
            with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate), patch.object(fixture_tools, 'freeze_generation', side_effect=RuntimeError('freeze failed')):
                with self.assertRaisesRegex(RuntimeError, 'freeze failed'):
                    fixture_tools.prepare(target)
            self.assertEqual(old, target.resolve())
            complete = list(target.parent.glob('native-tools.generations/generation-*'))
            self.assertEqual(2, len(complete), 'A completely renamed generation must remain counted after publication fails')
            for generation in complete:
                fixture_tools.validate_generation(generation)
            with patch.object(fixture_tools, 'MAX_GENERATIONS', 2), patch.object(fixture_tools, 'populate_generation') as acquire:
                with self.assertRaisesRegex(RuntimeError, 'storage limit reached'):
                    fixture_tools.prepare(target)
                acquire.assert_not_called()
            self.assertEqual(old, target.resolve())

    def test_concurrent_preparation_is_rejected_without_replacing_current_generation(self):
        import fcntl
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'native-tools'
            with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate):
                fixture_tools.prepare(target)
            old = target.resolve()
            with (target.parent / 'native-tools.generations/.lock').open('r+') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with patch.object(fixture_tools, 'populate_generation') as acquire:
                    with self.assertRaisesRegex(RuntimeError, 'Another fixture preparation owns'):
                        fixture_tools.prepare(target)
                    acquire.assert_not_called()
            self.assertEqual(old, target.resolve())

    def test_invalid_candidate_is_not_published_and_partial_generation_is_removed(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'native-tools'
            with patch.object(fixture_tools, 'populate_generation', return_value=[]):
                with self.assertRaisesRegex(RuntimeError, 'inventory is incomplete'):
                    fixture_tools.prepare(target)
            self.assertFalse(target.exists())
            self.assertEqual([], list(target.parent.glob('native-tools.generations/generation-*')))
            self.assertEqual([], list(target.parent.glob('native-tools.generations/.building-*')))

    def test_changed_binary_or_manifest_fails_integrity_without_fallback(self):
        for what in ('upstream', 'manifest'):
            with self.subTest(what=what), tempfile.TemporaryDirectory() as temporary:
                target = Path(temporary) / 'native-tools'
                with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate):
                    fixture_tools.prepare(target)
                generation = target.resolve()
                changed = generation / ('postgresql/upstream/pg_dump' if what == 'upstream' else 'fixture-tools.json')
                changed.chmod(0o644)
                changed.write_bytes(changed.read_bytes() + b'altered')
                with self.assertRaises(RuntimeError):
                    fixture_tools.validate_generation(generation)
                with patch.object(fixture_tools, 'populate_generation') as acquire:
                    with self.assertRaises(RuntimeError):
                        fixture_tools.prepare(target)
                    acquire.assert_not_called()
                self.assertEqual(generation, target.resolve())

    def test_unmanaged_existing_tree_is_preserved_and_never_consumed(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'native-tools'
            target.mkdir()
            existing = target / 'selected-client'
            existing.write_bytes(b'previous unreviewed client')
            stamp = existing.stat().st_mtime_ns
            with patch.object(fixture_tools, 'populate_generation') as acquire:
                with self.assertRaisesRegex(RuntimeError, 'unmanaged native-tools tree was preserved'):
                    fixture_tools.prepare(target)
                acquire.assert_not_called()
            self.assertFalse(target.is_symlink())
            self.assertEqual(b'previous unreviewed client', existing.read_bytes())
            self.assertEqual(stamp, existing.stat().st_mtime_ns)

    def test_unknown_pointer_and_storage_backpressure_do_not_replace_valid_assets(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            foreign = root / 'foreign'
            foreign.mkdir()
            target = root / 'native-tools'
            target.symlink_to(foreign, target_is_directory=True)
            with patch.object(fixture_tools, 'populate_generation') as acquire:
                with self.assertRaisesRegex(RuntimeError, 'outside its owned generation store'):
                    fixture_tools.prepare(target)
                acquire.assert_not_called()
            target.unlink()
            with patch.object(fixture_tools, 'populate_generation', side_effect=self.populate):
                fixture_tools.prepare(target)
            old = target.resolve()
            with patch.object(fixture_tools, 'MAX_GENERATIONS', 1), patch.object(fixture_tools, 'populate_generation') as acquire:
                with self.assertRaisesRegex(RuntimeError, 'storage limit reached'):
                    fixture_tools.prepare(target)
                acquire.assert_not_called()
            self.assertEqual(old, target.resolve())

    def test_an_already_running_launcher_keeps_its_physical_generation(self):
        import select
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / 'native-tools'
            with patch.object(fixture_tools, 'populate_generation', side_effect=lambda path: self.populate(path, b'old')):
                fixture_tools.prepare(target)
            process = subprocess.Popen([str(target / 'postgresql/pg_dump')], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                self.assertTrue(select.select([process.stdout], [], [], 5)[0], 'Owned loader did not become ready')
                self.assertEqual(b'ready\n', process.stdout.readline())
                with patch.object(fixture_tools, 'populate_generation', side_effect=lambda path: self.populate(path, b'new')):
                    fixture_tools.prepare(target)
                output, error = process.communicate(b'release\n', timeout=5)
                self.assertEqual(0, process.returncode, error)
                self.assertEqual(b'old-pg_dump', output)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(2)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait(2)


class NativeFixtureResourceAdmissionTest(unittest.TestCase):
    def test_bounded_command_output_and_deadline_fail_without_leaving_capture_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(RuntimeError, 'output exceeded'):
                fixture_tools.bounded_capture([sys.executable, '-c', 'print("x" * 32768)'], root, limit=1024)
            with self.assertRaisesRegex(RuntimeError, 'deadline'):
                fixture_tools.bounded_capture([sys.executable, '-c', 'import time; time.sleep(30)'], root, timeout=0.1)
            self.assertEqual([], list(root.iterdir()))

    def test_remote_file_sizes_are_admitted_before_any_docker_copy(self):
        calls = []
        def command(arguments, directory, **options):
            calls.append(arguments)
            if arguments[1:3] == ['image', 'inspect']:
                return json.dumps([{'Id': 'sha256:' + 'a' * 64}])
            if arguments[1] == 'create':
                return 'b' * 64
            if '/usr/bin/ldd' in arguments:
                return 'libc.so.6 => /lib/libc.so.6 (0x1)\n/lib64/ld-linux-x86-64.so.2 (0x2)\n'
            if '/usr/bin/stat' in arguments:
                return '\n'.join(str(fixture_tools.MAX_GENERATION_BYTES) for unused in arguments[arguments.index('--') + 1:])
            return ''
        with tempfile.TemporaryDirectory() as temporary, patch.object(fixture_tools, 'bounded_capture', side_effect=command), patch.object(fixture_tools, 'image_copy') as copy:
            with self.assertRaisesRegex(RuntimeError, 'before copying'):
                fixture_tools.populate_generation(Path(temporary))
            copy.assert_not_called()
        self.assertTrue(any('/usr/bin/stat' in command for command in calls))
        self.assertEqual('rm', calls[-1][1], 'The owned container must be removed after rejected admission')

    def test_file_count_and_store_walk_fail_at_the_bound(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for index in range(3):
                (root / str(index)).write_bytes(b'x')
            with patch.object(fixture_tools, 'MAX_FILES', 2):
                with self.assertRaisesRegex(RuntimeError, 'file/byte budget'):
                    fixture_tools.file_inventory(root)
            store = root / 'store'
            store.mkdir()
            generation = store / ('generation-' + 'a' * 64)
            generation.mkdir()
            for index in range(3):
                (generation / str(index)).write_bytes(b'x')
            with patch.object(fixture_tools, 'MAX_FILES', 2), patch.object(fixture_tools, 'MAX_GENERATIONS', 1):
                with self.assertRaisesRegex(RuntimeError, 'file/byte admission'):
                    fixture_tools.check_admission(store)


class PackagedNativeProvenanceTest(unittest.TestCase):
    def package(self, root, flags):
        records = []
        for engine, tools in packaged_clients.CLIENTS.items():
            source = {'engine': engine, 'name': engine + '-1.2.3.tar.gz',
                      'sha256': __import__('hashlib').sha256(b'official source fixture').hexdigest()}
            records.append(source)
            directory = root / 'backend/tools' / engine
            (directory / 'sources').mkdir(parents=True)
            (directory / 'bin').mkdir()
            (directory / 'sources' / source['name']).write_bytes(b'official source fixture')
            for tool in tools:
                client = directory / 'bin' / tool
                client.write_text('#!/bin/sh\nprintf "client 1.2.3\\n"\n')
                client.chmod(0o755)
            build = {'source': source, 'sourceIncluded': True, 'serverBuilt': False, 'files': [], **flags}
            (directory / 'native-client-build.json').write_text(json.dumps(build))
        (root / 'third_party').mkdir()
        (root / 'third_party/native_client_sources.json').write_text(json.dumps(records))

    def test_missing_or_modified_upstream_provenance_is_rejected_before_execution(self):
        required = {'upstreamSourceModified': False, 'postLinkBinaryModified': False}
        for field in required:
            for value in ('missing', True, None):
                with self.subTest(field=field, value=value), tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    flags = dict(required)
                    if value == 'missing':
                        flags.pop(field)
                    else:
                        flags[field] = value
                    self.package(root, flags)
                    with patch.object(packaged_clients, 'ROOT', root), patch.object(packaged_clients.subprocess, 'run') as execute:
                        with self.assertRaisesRegex(RuntimeError, 'unmodified upstream'):
                            packaged_clients.verify(root)
                        execute.assert_not_called()

    def test_explicit_unmodified_build_and_exact_source_are_verified(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            self.package(root, {'upstreamSourceModified': False, 'postLinkBinaryModified': False})
            with patch.object(packaged_clients, 'ROOT', root):
                report = packaged_clients.verify(root)
            self.assertTrue(report['passed'])
            self.assertEqual(3, len(report['nativeClients']))


if __name__ == '__main__':
    unittest.main()
