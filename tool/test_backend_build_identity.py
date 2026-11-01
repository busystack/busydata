import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from backend_build_identity import backend_source_hash, verify_jar, verify_bundle
from canonical_source import source_manifest, manifest_hash

class BackendIdentityTest(unittest.TestCase):
    def test_linked_generated_directories_match_python_without_exempting_source_links(self):
        repository = Path(__file__).resolve().parents[1]
        java = str(Path(os.environ['JAVA_HOME']) / 'bin/java') if 'JAVA_HOME' in os.environ else 'java'
        with tempfile.TemporaryDirectory() as directory:
            root, external = Path(directory) / 'source', Path(directory) / 'generated'
            (root / 'tool').mkdir(parents=True)
            (root / 'lib').mkdir()
            shutil.copy2(repository / 'tool/source_policy.properties', root / 'tool/source_policy.properties')
            shutil.copy2(repository / 'tool/BackendBuildIdentity.java', root / 'tool/BackendBuildIdentity.java')
            (root / 'lib/main.dart').write_text('authoritative source')
            # A regular source file sharing an excluded directory name is still hashed.
            (root / 'lib/cache').write_text('ordinary included source file')
            generated = ('linux/flutter/ephemeral', 'windows/flutter/ephemeral',
                         'backend/.mvn/cache', 'docs/acceptance', 'tool/__pycache__')
            for name in generated:
                path = root / name
                path.mkdir(parents=True)
                (path / 'output').write_text('generated output')
            destination = root / 'build/identity.json'

            def identity():
                reply = subprocess.run([java, str(root / 'tool/BackendBuildIdentity.java'), str(root), str(destination)],
                                       capture_output=True, text=True, timeout=60)
                self.assertEqual(0, reply.returncode, reply.stderr)
                value = json.loads(destination.read_text())
                manifest = source_manifest(root)
                self.assertEqual(manifest_hash(manifest), value['buildSourceSha256'])
                self.assertIn('lib/cache', {entry['path'] for entry in manifest['files']})
                return value

            original = identity()
            for name in generated:
                path, target = root / name, external / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.move(path, target)
                path.symlink_to(target, target_is_directory=True)
            self.assertEqual(original, identity())

            # Neither an arbitrary source directory link nor a source-file link
            # receives the excluded generated-directory treatment.
            for name, target in [('lib/linked', external / generated[0]),
                                 ('lib/linked.dart', external / generated[0] / 'output')]:
                with self.subTest(link=name):
                    link = root / name
                    link.symlink_to(target, target_is_directory=target.is_dir())
                    try:
                        with self.assertRaisesRegex(ValueError, 'symbolic'):
                            source_manifest(root)
                        reply = subprocess.run([java, str(root / 'tool/BackendBuildIdentity.java'), str(root), str(destination)],
                                               capture_output=True, text=True, timeout=60)
                        self.assertNotEqual(0, reply.returncode)
                        self.assertIn('Source non-regular files are unsupported', reply.stderr)
                    finally:
                        link.unlink()

    def test_java_and_python_share_exact_canonical_full_source_identity(self):
        repository = Path(__file__).resolve().parents[1]
        java = str(Path(os.environ['JAVA_HOME']) / 'bin/java') if 'JAVA_HOME' in os.environ else 'java'
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'tool').mkdir()
            shutil.copy2(repository / 'tool/source_policy.properties', root / 'tool/source_policy.properties')
            shutil.copy2(repository / 'tool/BackendBuildIdentity.java', root / 'tool/BackendBuildIdentity.java')
            for name in ('lib/漢😀.dart', 'lib/\ue000.dart', 'lib/😀.dart',
                         'docs/security.md', 'docs/acceptance-notes.md', 'test/acceptance/fixture.sql',
                         'backend/mvnw', 'tool/build.sh'):
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('fixture ' + name, encoding='utf-8')
                path.chmod(0o600)
            destination = root / 'build/identity.json'

            def read_identity():
                reply = subprocess.run([java, str(root / 'tool/BackendBuildIdentity.java'), str(root), str(destination)],
                                       capture_output=True, text=True, timeout=60)
                self.assertEqual(0, reply.returncode, reply.stderr)
                identity = json.loads(destination.read_text())
                manifest = source_manifest(root)
                canonical = manifest_hash(manifest)
                self.assertEqual(2, identity['version'])
                self.assertEqual(canonical, identity['buildSourceSha256'])
                self.assertEqual(canonical, identity['backendSourceSha256'])
                self.assertEqual(len(manifest['files']), identity['files'])
                return identity

            original = read_identity()
            captured = root / 'docs/acceptance/run/captured.log'
            captured.parent.mkdir(parents=True)
            captured.write_text('ignored local output')
            self.assertEqual(original, read_identity())
            jar = root / 'build/backend.jar'
            with zipfile.ZipFile(jar, 'w') as archive:
                archive.writestr('busydata-build-identity.json', destination.read_bytes())
            self.assertEqual(original, verify_jar(jar, root))
            for name in ('docs/security.md', 'docs/acceptance-notes.md', 'test/acceptance/fixture.sql'):
                with self.subTest(included=name):
                    path = root / name
                    content = path.read_text()
                    path.write_text(content + '\nchanged')
                    self.assertNotEqual(original['buildSourceSha256'], read_identity()['buildSourceSha256'])
                    with self.assertRaisesRegex(RuntimeError, 'stale'):
                        verify_jar(jar, root)
                    path.write_text(content)

    def test_unchanged_mtime_does_not_authorize_changed_backend_or_protocol(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['backend/src/main/Main.java','protocol/busydata.proto','backend/pom.xml','tool/BackendBuildIdentity.java']:
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text('original '+name)
            jar=root/'backend/target/bundle/lib/busydata-backend-0.1.0.jar';jar.parent.mkdir(parents=True)
            identity={'version':2,'backendSourceSha256':backend_source_hash(root),
                      'buildSourceSha256':backend_source_hash(root)}
            with zipfile.ZipFile(jar,'w') as archive:
                archive.writestr('busydata-build-identity.json',json.dumps(identity))
            (root/'backend/target/busydata-backend-0.1.0.jar').write_bytes(jar.read_bytes())
            self.assertEqual(identity,verify_bundle(root))
            source=root/'backend/src/main/Main.java';source.write_text('changed Java')
            with self.assertRaisesRegex(RuntimeError,'stale'):
                verify_jar(jar,root)
            source.write_text('original backend/src/main/Main.java')
            (root/'protocol/busydata.proto').write_text('changed protocol')
            with self.assertRaisesRegex(RuntimeError,'stale'):
                verify_bundle(root)
            (root/'protocol/busydata.proto').write_text('original protocol/busydata.proto')
            (root/'backend/target/busydata-backend-0.1.0.jar').write_bytes(b'different build')
            with self.assertRaisesRegex(RuntimeError,'differs'):
                verify_bundle(root)

if __name__=='__main__':unittest.main()
