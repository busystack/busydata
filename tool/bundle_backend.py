#!/usr/bin/env python3
"""Build one relocatable backend bundle. Requires an already verified Maven package."""
import argparse, json, os, pathlib, shutil, subprocess, tempfile, zipfile
from backend_build_identity import verify_jar
from jlink_runtime import build_image

root = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--java-home', default=os.environ.get('JAVA_HOME'))
parser.add_argument('--development-runtime', action='store_true')
args = parser.parse_args()
jdk = pathlib.Path(args.java_home) if args.java_home else pathlib.Path(shutil.which('java')).resolve().parents[1]
release = (jdk / 'release').read_text()
if not args.development_runtime and '25.0.4.1' not in release:
    raise SystemExit('Release bundles require pinned Temurin 25.0.4.1+1; use --development-runtime only for local validation.')
if 'IMPLEMENTOR="Eclipse Adoptium"' not in release or 'JAVA_VERSION="25.' not in release:
    raise SystemExit('Temurin Java 25 is required')
identity = verify_jar(root / 'backend/target/busydata-backend-0.1.0.jar', root)
bundle = root / 'backend/target/bundle'
native_build = root / 'backend/target/native-build'
native = bundle / 'native'
native.mkdir(parents=True, exist_ok=True)
subprocess.run(['cmake', '-S', str(root / 'backend/native'), '-B', str(native_build),
                '-DCMAKE_BUILD_TYPE=Release'], check=True)
subprocess.run(['cmake', '--build', str(native_build), '--config', 'Release'], check=True)
subprocess.run(['ctest', '--test-dir', str(native_build), '-C', 'Release',
                '--output-on-failure'], check=True)
native_files = ['busydata_tool_launcher.exe', 'busydata_windows_files.dll'] if os.name == 'nt' else []
# Only generated BusyData bundle contents: never leave an obsolete injected
# transport in a package built incrementally. Installed clients are untouched.
for stale in ('busydata_hostname_forward.dll', 'libbusydata_hostname_forward.so'):
    (native / stale).unlink(missing_ok=True)
for name in native_files:
    source = native_build / ('Release' if os.name == 'nt' else '') / name
    shutil.copy2(source, native / name)
lib = bundle / 'lib'
lib.mkdir(parents=True, exist_ok=True)
classpath = root / 'backend/target/runtime-classpath.txt'
if not classpath.exists():
    raise SystemExit('Run Maven package/verify to create runtime-classpath.txt before bundling.')
dependencies = [pathlib.Path(path) for path in classpath.read_text().strip().split(os.pathsep)]
expected = {path.name for path in dependencies} | {'busydata-backend-0.1.0.jar'}
for stale in lib.glob('*.jar'):
    if stale.name not in expected: stale.unlink()  # Generated bundle only; stale versions must never ship.
for dependency in dependencies: shutil.copy2(dependency, lib)
shutil.copy2(root / 'backend/target/busydata-backend-0.1.0.jar', lib)
runtime = bundle / 'runtime'
if runtime.exists():
    shutil.rmtree(runtime)  # Only this generated, application-owned runtime image.
modules = ['java.base','java.sql','java.naming','java.management','java.net.http','java.rmi','java.security.jgss','java.security.sasl','java.xml','java.logging','jdk.crypto.ec','jdk.unsupported','jdk.charsets','jdk.security.auth']
if os.name == 'nt': modules.append('jdk.crypto.mscapi')
jlink = build_image(jdk / 'bin/jlink', modules, runtime,
                    root / 'backend/target/jlink-tmp', bundle / 'jlink.log')
java = runtime / 'bin' / ('java.exe' if os.name == 'nt' else 'java')
with tempfile.TemporaryDirectory(prefix='runtime-smoke-', dir=root / 'backend/target') as smoke:
    check = subprocess.run([str(java), '--enable-native-access=ALL-UNNAMED',
        '-Djava.io.tmpdir=' + smoke, '-cp', str(lib / '*'),
        'io.busystack.busydata.RuntimeCheck'], check=True, capture_output=True, text=True, timeout=60)
(bundle / 'runtime-check.json').write_text(check.stdout)
(bundle / 'build-info.json').write_text(json.dumps({'release': release, 'developmentRuntime': args.development_runtime, 'modules': modules, 'backendSourceIdentity': identity, 'jlinkVerification': jlink}, indent=2))
notices = bundle / 'notices'
if notices.exists(): shutil.rmtree(notices)  # Generated notices reflect the exact bundled dependency set.
notices.mkdir(exist_ok=True)
shutil.copy2(root / 'LICENSE', notices / 'BUSYDATA_LICENSE')
shutil.copy2(root / 'third_party/BUSYMAX_NOTICE', notices / 'BUSYMAX_NOTICE')
shutil.copy2(root / 'third_party/BUSYMARK_NOTICE', notices / 'BUSYMARK_NOTICE')
shutil.copy2(root / 'third_party/provenance.json', notices / 'busymax-provenance.json')
for jar in sorted(lib.glob('*.jar')):
    with zipfile.ZipFile(jar) as archive:
        for name in archive.namelist():
            if any(s in pathlib.PurePosixPath(name).name.lower() for s in ['license','notice','copying']) and not name.endswith('/') and not name.endswith('.class'):
                destination = notices / jar.stem / pathlib.PurePosixPath(name).name
                destination.parent.mkdir(exist_ok=True)
                destination.write_bytes(archive.read(name))
for name in ['bom.json','bom.xml']:
    source = root / 'backend/target' / name
    if source.exists(): shutil.copy2(source, bundle)
print(bundle)
