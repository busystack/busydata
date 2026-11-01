#!/usr/bin/env python3
"""Build and exercise current strict packages in BusyData's owned disposable VM.

No Store upload, host Snap installation, confinement changes or host service
configuration. The ordinary product and private acceptance package remain separate.
Every source/build/installed receipt is bound to the active frozen verification run.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import time
import uuid

from bounded_process_log import BoundedProcessLog
from canonical_source import extract_archive, load_manifest, source_manifest, manifest_hash
from desktop_build_evidence import verify_existing_bundle
from public_bundle_permissions import publish_public_bundle
from verification_evidence import (ROOT, manifest_path, validate_source_snapshot,
                                   source_hash, digest, atomic_json, utc)
from verify_installed_snap import validate_desktop_report

VM = 'busydata-installed-20261003'
VM_ROOT = '/home/albert/busydata-acceptance'


def request_x11_window_close(window):
    """Send the normal ICCCM close request; never destroy the client's drawable."""
    import ctypes

    class Data(ctypes.Union):
        _fields_ = [('b', ctypes.c_char * 20), ('s', ctypes.c_short * 10),
                    ('l', ctypes.c_long * 5)]

    class ClientMessage(ctypes.Structure):
        _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong),
                    ('send_event', ctypes.c_int), ('display', ctypes.c_void_p),
                    ('window', ctypes.c_ulong), ('message_type', ctypes.c_ulong),
                    ('format', ctypes.c_int), ('data', Data)]

    class Event(ctypes.Union):
        _fields_ = [('client', ClientMessage), ('pad', ctypes.c_long * 24)]

    x11 = ctypes.CDLL('libX11.so.6')
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
    x11.XInternAtom.restype = ctypes.c_ulong
    x11.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int,
                              ctypes.c_long, ctypes.POINTER(Event)]
    x11.XSendEvent.restype = ctypes.c_int
    x11.XFlush.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    display = x11.XOpenDisplay(None)
    if not display:
        raise RuntimeError('Owned X display unavailable')
    try:
        protocol = x11.XInternAtom(display, b'WM_PROTOCOLS', True)
        delete = x11.XInternAtom(display, b'WM_DELETE_WINDOW', True)
        if not protocol or not delete:
            raise RuntimeError('Window close protocol unavailable')
        event = Event()
        event.client.type = 33  # X11 ClientMessage, with a 32-bit protocol payload.
        event.client.display = display
        event.client.window = int(window)
        event.client.message_type = protocol
        event.client.format = 32
        event.client.data.l[0] = delete
        if not x11.XSendEvent(display, int(window), False, 0, ctypes.byref(event)):
            raise RuntimeError('Window close request rejected')
        x11.XFlush(display)
    finally:
        x11.XCloseDisplay(display)


class VmAcceptance:
    def __init__(self, root=ROOT, vm=VM):
        if vm != VM:
            raise ValueError('Only the explicitly owned BusyData acceptance VM is supported')
        self.root, self.vm = Path(root).resolve(), vm
        self.manifest = json.loads(manifest_path(self.root).read_text())
        validate_source_snapshot(self.manifest, self.root)
        self.source = self.manifest['buildSourceSha256']
        if source_hash(self.root) != self.source:
            raise ValueError('Installed acceptance must use the active frozen source snapshot')
        self.identifier = str(uuid.uuid4())
        self.work = self.root / 'build/installed-snap-vm' / self.identifier
        self.work.mkdir(parents=True)
        # These are directly inside the parent's owned stage so its evidence
        # packager can retain checked diagnostics without collecting private data.
        self.diagnostics = manifest_path(self.root).parent / 'installed-snap/diagnostics'
        self.diagnostics.mkdir(parents=True, exist_ok=True)
        self.remote = VM_ROOT + '/' + self.identifier
        self.records, self.logs = [], []
        self.report = {'version': 3, 'sourceSha256': self.source,
                       'runId': self.manifest['runId'], 'startedUtc': utc(),
                       'vm': vm, 'exitCode': 1, 'published': False,
                       'hostSnapModified': False, 'packages': [], 'diagnostics': [],
                       'fullInstalledDatabaseFileSecretSshAcceptance': False}

    def run(self, name, argv, *, cwd=None, env=None, timeout=1800, allowed=(0,), umask=-1):
        print('Installed Snap: ' + name, flush=True)
        log = self.diagnostics / (name + '.log')
        started = time.monotonic()
        process = subprocess.Popen(argv, cwd=cwd or self.root, env=env,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, umask=umask)
        capture = BoundedProcessLog(process, log, 8 * 1024 * 1024)
        try:
            while process.poll() is None:
                if time.monotonic() - started > timeout:
                    process.terminate()
                    try:
                        process.wait(timeout=10)
                    except subprocess.TimeoutExpired:
                        process.kill();process.wait(timeout=10)
                    raise TimeoutError('Installed acceptance operation exceeded its deadline: ' + name)
                time.sleep(.2)
            if process.returncode not in allowed:
                raise RuntimeError('Installed acceptance command failed: ' + name + ' (exit ' + str(process.returncode) + ')')
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill();process.wait(timeout=10)
            receipt = capture.finish()
            receipt.update(file=log.relative_to(self.root).as_posix(), sha256=digest(log), bytes=log.stat().st_size)
            self.logs.append(receipt)
            self.records.append({'name': name, 'command': argv, 'exitCode': process.returncode,
                                 'durationSeconds': time.monotonic() - started,
                                 'log': receipt, 'buildSourceSha256': self.source})
            if not receipt['complete']:
                raise RuntimeError('Installed acceptance diagnostic admission failed: ' + name)
        return log.read_text(errors='replace')

    def vm_command(self, name, argv, *, timeout=120):
        return self.run(name, ['lxc', 'exec', self.vm, '--', *argv], timeout=timeout)

    def push(self, name, source, remote):
        self.run(name, ['lxc', 'file', 'push', str(source), self.vm + remote], timeout=900)

    def pull(self, name, remote, target):
        target.parent.mkdir(parents=True, exist_ok=True)
        self.run(name, ['lxc', 'file', 'pull', self.vm + remote, str(target)], timeout=900)

    def receipt(self, path):
        path = Path(path)
        return {'file': path.relative_to(self.root).as_posix(), 'bytes': path.stat().st_size,
                'sha256': digest(path), 'sourceSha256': self.source}

    def materialize_source(self):
        snapshot = self.manifest['sourceSnapshot']
        canonical = load_manifest(self.root / snapshot['manifest']['file'])
        source = extract_archive(self.root / snapshot['archive']['file'], self.work / 'source', canonical)
        if manifest_hash(source_manifest(source)) != self.source:
            raise RuntimeError('Snap build source differs from its verified canonical manifest')
        return source

    def fixture_archive(self):
        classpath = self.root / 'backend/target/installed-fixture-classpath.txt'
        maven = [str(self.root / 'backend/mvnw'), '-f', str(self.root / 'backend/pom.xml')]
        if os.environ.get('BUSYDATA_MAVEN_REPOSITORY'):
            maven.append('-Dmaven.repo.local=' + os.environ['BUSYDATA_MAVEN_REPOSITORY'])
        self.run('fixture-compile', maven + ['test-compile', 'dependency:build-classpath',
                 '-Dmdep.includeScope=test', '-Dmdep.outputFile=target/installed-fixture-classpath.txt'], timeout=600)
        libraries = [Path(item) for item in classpath.read_text().strip().split(os.pathsep)]
        if len(libraries) > 256 or len({item.name for item in libraries}) != len(libraries):
            raise RuntimeError('Fixture dependency count/name identity is ambiguous')
        archive = self.work / 'fixture-classes.tar.gz'
        entries = []
        with tarfile.open(archive, 'x:gz') as output:
            for directory in ('classes', 'test-classes'):
                origin = self.root / 'backend/target' / directory
                for path in sorted(origin.rglob('*')):
                    if path.is_symlink():
                        raise RuntimeError('Fixture classes cannot contain symbolic links')
                    if path.is_file():
                        relative = 'backend/target/' + directory + '/' + path.relative_to(origin).as_posix()
                        output.add(path, arcname=relative, recursive=False)
                        entries.append({'file': relative, 'sha256': digest(path), 'bytes': path.stat().st_size})
            for path in libraries:
                if path.is_symlink() or not path.is_file() or path.stat().st_size > 64 * 1024 * 1024:
                    raise RuntimeError('Fixture dependency must be a bounded regular JAR')
                relative = 'backend/target/test-libs/' + path.name
                output.add(path, arcname=relative, recursive=False)
                entries.append({'file': relative, 'sha256': digest(path), 'bytes': path.stat().st_size})
        receipt = {'sourceSha256': self.source, 'files': entries,
                   'classpath': [item['file'] for item in entries if item['file'].startswith('backend/target/test-libs/')]}
        path = self.work / 'fixture-receipt.json'
        atomic_json(path, receipt)
        return archive, path

    def build_packages(self, source):
        product = self.root / 'build/linux/x64/release/bundle'
        product_report = json.loads((self.root / 'build/linux-release-build.json').read_text())
        verify_existing_bundle('linux', product_report, product, self.source)
        stage_bundle = source / 'build/linux/x64/release/bundle'
        stage_bundle.parent.mkdir(parents=True)
        shutil.copytree(product, stage_bundle, symlinks=True)
        environment = dict(os.environ, SNAPCRAFT_BUILD_ENVIRONMENT='lxd', SNAPCRAFT_BUILD_INFO='1')
        packages = {}
        self.run('acceptance-build', [sys.executable, str(self.root / 'tool/build_snap_acceptance.py'), '--no-pub'], timeout=900)
        acceptance = json.loads((self.root / 'build/snap-acceptance-build.json').read_text())
        if acceptance['sourceSha256'] != self.source:
            raise RuntimeError('Acceptance bundle belongs to another source')
        self.report['acceptanceBuild'] = acceptance
        for kind in ('product', 'acceptance'):
            if kind == 'acceptance':
                shutil.rmtree(stage_bundle)  # UUID-owned generated bundle only.
                archive = self.root / 'build/busydata-installed-acceptance.tar.gz'
                if digest(archive) != acceptance['archiveSha256']:
                    raise RuntimeError('Acceptance archive differs from its current build receipt')
                with tarfile.open(archive) as content:
                    # Own generated tar, with an independently checked hash;
                    # Python's data filter rejects traversal/escaping symlinks.
                    content.extractall(stage_bundle.parent, filter='data')
                # The safe data filter intentionally ignores directory modes.
                # Re-publish only this complete generated copy under a private
                # controller umask; parent fixtures and inputs stay unchanged.
                publish_public_bundle(stage_bundle)
                self.run('snap-clean-application', ['snapcraft', 'clean', 'busydata'], cwd=source,
                         env=environment, timeout=600)
            # The managed builder mounts only the project tree. Its output must
            # be inside that tree and addressed relative to the mounted cwd.
            destination = source / 'build/snap-packages' / self.identifier / kind
            destination.mkdir(parents=True)
            self.run('snap-pack-' + kind, ['snapcraft', 'pack', '--use-lxd', '--output',
                     str(destination.relative_to(source))],
                     cwd=source, env=environment, timeout=10800)
            files = list(destination.glob('*.snap'))
            if len(files) != 1:
                raise RuntimeError('Snap build did not produce exactly one fresh package')
            package = files[0]
            prime = self.work / (kind + '-prime')
            self.run('unpack-' + kind, ['unsquashfs', '-d', str(prime), str(package)],
                     timeout=300, umask=0o022)
            self.run('payload-' + kind, [sys.executable, str(self.root / 'tool/verify_snap_payload.py'),
                     '--source', str(stage_bundle), '--prime', str(prime), '--output', str(self.diagnostics / (kind + '-payload.json'))])
            self.run('inventory-' + kind, [sys.executable, str(self.root / 'tool/verify_snap_distribution.py'),
                     '--prime', str(prime), '--output', str(self.diagnostics / (kind + '-inventory.json'))], timeout=300)
            if source_hash(source) != self.source:
                raise RuntimeError('Source changed during Snap packaging')
            packages[kind] = package
            self.report['packages'].append({'kind': kind, **self.receipt(package)})
            for receipt in (self.diagnostics / (kind + '-payload.json'), self.diagnostics / (kind + '-inventory.json')):
                self.report['diagnostics'].append(self.receipt(receipt))
        return packages

    def fixture_environment(self):
        return ['env', 'PATH=/opt/busydata-docker/docker:/usr/bin:/bin',
                'JAVA_HOME=/snap/busydata/current/backend/runtime', 'XDG_RUNTIME_DIR=/run/user/1001',
                'TMPDIR=' + self.remote + '/source/build/tmp']

    def install_and_run(self, packages):
        self.vm_command('vm-owned-directory', ['install', '-d', '-o', '1001', '-g', '1002', '-m', '0700', self.remote])
        snapshot = self.manifest['sourceSnapshot']
        for key in ('manifest', 'archive'):
            self.push('push-source-' + key, self.root / snapshot[key]['file'], self.remote + '/' + key)
        fixture, fixture_receipt = self.fixture_archive()
        self.push('push-fixture', fixture, self.remote + '/fixture.tar.gz')
        self.push('push-fixture-receipt', fixture_receipt, self.remote + '/fixture-receipt.json')
        self.push('push-acceptance-package', packages['acceptance'], self.remote + '/acceptance.snap')
        self.push('push-product-package', packages['product'], self.remote + '/product.snap')
        product_hash = self.vm_command('vm-product-package-hash', ['sha256sum', self.remote + '/product.snap']).split()[0]
        if product_hash != digest(packages['product']):
            raise RuntimeError('Transferred ordinary package differs from its current build')
        remote_hash = self.vm_command('vm-package-hash', ['sha256sum', self.remote + '/acceptance.snap']).split()[0]
        if remote_hash != digest(packages['acceptance']):
            raise RuntimeError('Transferred acceptance package differs from its current build')
        # Fixed infrastructure script; no database SQL, secrets or shell-expanded
        # user destinations. It validates source and each fixture class/JAR before
        # running any installed product operation.
        script = self.work / 'prepare-vm.py'
        script.write_text(VM_PREPARATION, encoding='utf-8')
        self.push('push-preparation', script, self.remote + '/prepare.py')
        self.vm_command('vm-prepare', ['python3', self.remote + '/prepare.py', self.remote, self.source], timeout=300)
        probe = self.work / 'product-probe.py'
        probe.write_text(VM_PRODUCT_PROBE, encoding='utf-8')
        # This nonsecret script is pushed as root after preparation. The VM's
        # unprivileged reader needs read access; its parent remains private.
        probe.chmod(0o644)
        self.push('push-product-probe', probe, self.remote + '/product-probe.py')
        self.vm_command('vm-install-product', ['snap', 'install', '--dangerous', self.remote + '/product.snap'], timeout=600)
        environment = self.fixture_environment()
        self.vm_command('vm-ordinary-product-launch', ['runuser', '-u', 'albert', '--', *environment,
                        '/usr/bin/python3', self.remote + '/product-probe.py', self.remote], timeout=120)
        product_receipt = self.diagnostics / 'vm-ordinary-product.json'
        self.pull('pull-product-receipt', self.remote + '/product-launch.json', product_receipt)
        self.report['ordinaryProduct'] = json.loads(product_receipt.read_text())
        self.report['diagnostics'].append(self.receipt(product_receipt))
        if self.report['ordinaryProduct'].get('passed') is not True:
            raise RuntimeError('Installed ordinary product launch/activation/cleanup did not pass')
        product = json.loads((self.root / 'build/linux-release-build.json').read_text())
        names = set(self.report['ordinaryProduct'].get('installedHashes', {}))
        expected_hashes = {item['path']: item['sha256'] for item in product['files'] if item['path'] in names}
        if self.report['ordinaryProduct']['installedHashes'] != expected_hashes or len(names) != 4:
            raise RuntimeError('Installed ordinary payload differs from its verified build')
        self.vm_command('vm-install-strict', ['snap', 'install', '--dangerous', self.remote + '/acceptance.snap'], timeout=600)
        self.vm_command('vm-selected-ssh-interface', ['snap', 'connect', 'busydata:ssh-keys'], timeout=120)
        acceptance_failure = None
        try:
            self.vm_command('vm-actual-confined-acceptance', ['runuser', '-u', 'albert', '--', *environment,
                            '/usr/bin/python3', self.remote + '/source/tool/verify_installed_snap.py'], timeout=2400)
        except (RuntimeError, TimeoutError) as failure:
            acceptance_failure = failure
        installed = self.diagnostics / 'vm-installed-snap.json'
        self.pull('pull-installed-receipt', self.remote + '/source/build/installed-snap.json', installed)
        actual = json.loads(installed.read_text())
        self.report['vmAcceptance'] = actual
        self.report['diagnostics'].append(self.receipt(installed))
        for index, log in enumerate(actual.get('logs', [])):
            if (not log.get('complete') or log.get('retainedBytes', 0) > 8 * 1024 * 1024
                    or not Path(log['file']).is_relative_to(Path(self.remote + '/source/build/installed-snap'))):
                raise RuntimeError('VM acceptance log admission or ownership failed')
            target = self.diagnostics / ('vm-diagnostic-' + str(index) + '.log')
            remote_hash = self.vm_command('vm-diagnostic-hash-' + str(index), ['sha256sum', log['file']]).split()[0]
            self.pull('pull-diagnostic-' + str(index), log['file'], target)
            if target.stat().st_size != log['retainedBytes'] or digest(target) != remote_hash:
                raise RuntimeError('VM acceptance log changed during transfer')
            self.report['diagnostics'].append(self.receipt(target))
        if (actual.get('exitCode') != 0 or actual.get('sourceSha256') != self.source
                or actual.get('cleanupConfirmed') is not True
                or actual.get('fullInstalledDatabaseFileSecretSshAcceptance') is not True
                or actual.get('forcedParentTermination', {}).get('passed') is not True):
            raise RuntimeError('Installed VM receipt is failed, stale, or incomplete') from acceptance_failure
        validate_desktop_report(actual['desktop'])
        if actual['installedBuild']['artifacts'] != self.report['acceptanceBuild']['artifacts']:
            raise RuntimeError('Installed payload differs from the freshly built acceptance bundle')
        self.report['exitCode'] = 0
        self.report['fullInstalledDatabaseFileSecretSshAcceptance'] = True

    def execute(self):
        try:
            for tool in ('snapcraft', 'lxc', 'unsquashfs'):
                if not shutil.which(tool):
                    raise RuntimeError('Required installed package facility unavailable: ' + tool)
            listing = json.loads(self.run('vm-state', ['lxc', 'list', self.vm, '--format', 'json'], timeout=30))
            if len(listing) != 1 or listing[0]['name'] != self.vm or listing[0]['type'] != 'virtual-machine' or listing[0]['status'] != 'Running':
                raise RuntimeError('The existing owned BusyData acceptance VM is not running')
            self.report['vmIdentity'] = {'name': listing[0]['name'], 'type': listing[0]['type'],
                                         'uuid': listing[0]['config']['volatile.uuid']}
            packages = self.build_packages(self.materialize_source())
            self.install_and_run(packages)
            if source_hash(self.root) != self.source:
                raise RuntimeError('Source changed during installed package acceptance')
        except Exception as failure:
            self.report['exitCode'] = 1
            self.report['fullInstalledDatabaseFileSecretSshAcceptance'] = False
            self.report['failureType'] = type(failure).__name__
            self.report['failure'] = str(failure) if isinstance(failure, (RuntimeError, ValueError, TimeoutError)) else type(failure).__name__
        finally:
            self.report.update(finishedUtc=utc(), commands=self.records)
            self.report['diagnostics'].extend(item for item in self.logs if item not in self.report['diagnostics'])
            atomic_json(self.root / 'build/installed-snap.json', self.report)
        return self.report['exitCode']


VM_PREPARATION = r'''import hashlib,json,os,pathlib,sys,tarfile,zipfile
root=pathlib.Path(sys.argv[1]); expected=sys.argv[2]
manifest=json.loads((root/'manifest').read_text())
encoded=(json.dumps(manifest,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n').encode()
if hashlib.sha256(encoded).hexdigest()!=expected:raise RuntimeError('Transferred source manifest differs from frozen evidence')
source=root/'source';source.mkdir()
with zipfile.ZipFile(root/'archive') as archive:
    for entry in manifest['files']:
        name=entry['path'];path=pathlib.PurePosixPath(name)
        if path.is_absolute() or '..' in path.parts or '\\' in name:raise RuntimeError('Unsafe source path')
        target=source/name;target.parent.mkdir(parents=True,exist_ok=True)
        with archive.open(name) as origin,target.open('xb') as output:
            while chunk:=origin.read(65536):output.write(chunk)
        with target.open('rb') as origin:actual=hashlib.file_digest(origin,'sha256').hexdigest()
        if actual!=entry['sha256'] or target.stat().st_size!=entry['bytes']:raise RuntimeError('Transferred source bytes differ')
        target.chmod(int(entry['mode'],8))
sys.path.insert(0,str(source/'tool'))
from canonical_source import source_hash
if source_hash(source)!=expected:raise RuntimeError('VM canonical source differs from evidence')
receipt=json.loads((root/'fixture-receipt.json').read_text())
if receipt['sourceSha256']!=expected:raise RuntimeError('Fixture receipt belongs to another source')
with tarfile.open(root/'fixture.tar.gz') as archive:archive.extractall(source,filter='data')
for entry in receipt['files']:
    path=source/entry['file']
    with path.open('rb') as origin:actual=hashlib.file_digest(origin,'sha256').hexdigest()
    if path.is_symlink() or actual!=entry['sha256'] or path.stat().st_size!=entry['bytes']:raise RuntimeError('Transferred fixture changed')
target=source/'backend/target/installed-fixture-classpath.txt'
target.write_text(':'.join(str(source/name) for name in receipt['classpath']))
(source/'build/tmp').mkdir(parents=True)
for directory,subdirectories,files in os.walk(root):
    os.chown(directory,1001,1002)
    for name in files:os.chown(pathlib.Path(directory)/name,1001,1002,follow_symlinks=False)
'''

VM_PRODUCT_PROBE = r'''import json,os,pathlib,subprocess,sys,tempfile,time,uuid
root=pathlib.Path(sys.argv[1]);source=root/'source'
sys.path.insert(0,str(source/'tool'))
from verify_installed_snap import desktop_command,tracking_environment,process_confinement,stop,installed
from verify_installed_snap_vm import request_x11_window_close
if '--owned-session' not in sys.argv:
    env=dict(os.environ,BUSYDATA_ACCEPTANCE_TRACKING_BUS='unix:path=/run/user/'+str(os.getuid())+'/bus')
    env.pop('DBUS_SESSION_BUS_ADDRESS',None)
    with tempfile.TemporaryDirectory(prefix='busydata-product-bus-') as work:
        daemon=pathlib.Path(work)/'dbus-daemon'
        daemon.write_text('#!/bin/sh\nexec /usr/bin/dbus-daemon --address=unix:abstract=/tmp/dbus-busydata-'+uuid.uuid4().hex+' "$@"\n')
        daemon.chmod(0o700)
        raise SystemExit(subprocess.run(['dbus-run-session','--dbus-daemon='+str(daemon),'--','xvfb-run','-a',sys.executable,str(pathlib.Path(__file__).resolve()),str(root),'--owned-session'],env=env).returncode)
report={'version':1,'passed':False,'entrypoint':'lib/main_linux.dart','ordinaryProduct':True}
primary=second=None;backend=None
try:
    subprocess.run(['dbus-update-activation-environment','DISPLAY','XAUTHORITY'],check=True,timeout=10)
    lines=installed('cd "$SNAP"; sha256sum busydata lib/libapp.so backend/lib/busydata-backend-0.1.0.jar backend/runtime/bin/java').splitlines()
    report['installedHashes']={line.split(None,1)[1].strip():line.split(None,1)[0] for line in lines}
    command=desktop_command(os.environ['DBUS_SESSION_BUS_ADDRESS'])
    primary=subprocess.Popen(command,env=tracking_environment(),stderr=subprocess.STDOUT)
    deadline=time.monotonic()+40;windows=[]
    while time.monotonic()<deadline:
        if primary.poll() is not None:raise RuntimeError('Installed ordinary frontend exited before first frame')
        try:
            proof=process_confinement(primary.pid,'/busydata')
            children=(pathlib.Path('/proc')/str(primary.pid)/'task'/str(primary.pid)/'children').read_text().split()
            for child in children:
                candidate=process_confinement(int(child),'/backend/runtime/bin/java')
                if candidate is not None:backend=candidate
            reply=subprocess.run(['xdotool','search','--onlyvisible','--pid',str(primary.pid)],capture_output=True,text=True,timeout=3)
            windows=[value for value in reply.stdout.splitlines() if value.isdecimal()]
            if proof and backend and len(windows)==1:break
        except (FileNotFoundError,PermissionError):pass
        time.sleep(.1)
    if not backend or len(windows)!=1:raise RuntimeError('Ordinary confined native window/backend was not observed')
    report.update(frontend=proof,backend=backend,nativeWindowObserved=True)
    second=subprocess.Popen(command,env=tracking_environment(),stderr=subprocess.STDOUT)
    if second.wait(timeout=15)!=0:raise RuntimeError('Second ordinary launch did not activate primary instance')
    report['singleInstanceActivation']=True
    request_x11_window_close(windows[0])
    report['nativeCloseRequest']='WM_DELETE_WINDOW'
    try:primary.wait(timeout=20)
    except subprocess.TimeoutExpired:raise RuntimeError('Ordinary empty-workspace close did not complete')
    deadline=time.monotonic()+30
    while pathlib.Path('/proc',str(backend['pid'])).exists():
        if time.monotonic()>=deadline:raise RuntimeError('Ordinary owned backend survived frontend close')
        time.sleep(.1)
    report.update(normalExitCode=primary.returncode,normalOwnedBackendCleanup=True,passed=primary.returncode==0)
except Exception as error:report.update(failureType=type(error).__name__,failure=str(error) if isinstance(error,RuntimeError) else type(error).__name__)
finally:
    stop(second);stop(primary)
    (root/'product-launch.json').write_text(json.dumps(report,indent=2)+'\n')
raise SystemExit(0 if report['passed'] else 1)
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--vm', default=VM, choices=(VM,))
    args = parser.parse_args()
    raise SystemExit(VmAcceptance(vm=args.vm).execute())


if __name__ == '__main__':
    main()
