"""Build identity covers the complete native desktop bundle, including reused runners."""
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import uuid
from backend_build_identity import verify_bundle, verify_jar
from public_bundle_permissions import publish_public_bundle, validate_public_bundle
from verification_evidence import ROOT, source_hash, resolve_command
from verify_official_dependencies import revalidate_receipt, owned_build_environment


def verify_existing_bundle(platform, report, bundle, source):
    """Reject a stale or replaced bundle, including a reused native runner."""
    if platform not in ('linux', 'windows'):
        raise ValueError('Only the approved desktop targets are supported')
    if (report.get('exitCode') != 0 or report.get('buildSourceSha256') != source or
            report.get('entrypoint') != f'lib/main_{platform}.dart'):
        raise RuntimeError('Build the fresh ordinary desktop product before native acceptance')
    required = {'backend/lib/busydata-backend-0.1.0.jar', 'backend/dependency-inventory.json'}
    required.update(('busydata', 'lib/libapp.so', 'backend/runtime/bin/java') if platform == 'linux'
                    else ('busydata.exe', 'flutter_windows.dll', 'data/app.so', 'backend/runtime/bin/java.exe'))
    recorded = report.get('files', [])
    if not isinstance(recorded, list) or not 1 <= len(recorded) <= 20000:
        raise RuntimeError('Product bundle inventory budget')
    names = set()
    for item in recorded:
        name = item.get('path', '')
        relative = Path(name)
        if (not name or relative.is_absolute() or '..' in relative.parts or
                relative.as_posix() != name or name in names):
            raise RuntimeError('Invalid product bundle inventory path')
        names.add(name)
        path = bundle / relative
        if not path.resolve().is_relative_to(bundle.resolve()):
            raise RuntimeError('Product bundle link escapes the bundle')
        if 'linkTarget' in item:
            if not path.is_symlink() or path.readlink().as_posix() != item['linkTarget'] or not path.exists():
                raise RuntimeError('Product bundle link changed: ' + name)
        else:
            if path.is_symlink() or not path.is_file():
                raise RuntimeError('Product bundle file missing or replaced: ' + name)
            with path.open('rb') as stream:
                actual = hashlib.file_digest(stream, 'sha256').hexdigest()
            if (actual != item.get('sha256') or path.stat().st_size != item.get('bytes') or
                    path.stat().st_mode & 0o777 != item.get('mode')):
                raise RuntimeError('Product bundle contents changed: ' + name)
    if not required.issubset(names):
        raise RuntimeError('Incomplete ordinary product bundle inventory')
    actual_names = set()
    for path in bundle.rglob('*'):
        if path.is_file() or path.is_symlink():
            actual_names.add(path.relative_to(bundle).as_posix())
            if len(actual_names) > 20000:
                raise RuntimeError('Product bundle file-count budget exceeded')
    if actual_names != names:
        raise RuntimeError('Product bundle inventory differs from actual files')
    if platform == 'linux':
        validate_public_bundle(bundle)
    return {item['path']: item['sha256'] for item in recorded if item['path'] in required}


def build(platform, no_pub=False):
    if platform not in ('linux', 'windows'):
        raise ValueError('Only the approved desktop targets are supported')
    backend_identity = verify_bundle()
    dependency_sources = revalidate_receipt(ROOT)
    environment = owned_build_environment(ROOT)
    build_id, source = str(uuid.uuid4()), source_hash()
    started = datetime.datetime.now(datetime.timezone.utc).isoformat()
    entrypoint = f'lib/main_{platform}.dart'
    command = resolve_command(['flutter', 'build', platform, '--release', '-t', entrypoint])
    if no_pub:
        # Explicit local mode following a separately successful locked pub get.
        # CI still executes its required flutter-dependencies stage.
        command.append('--no-pub')
    if platform == 'linux':
        # The approved SDK can reuse a font subset after a Dart-only glyph
        # change. Refresh this derived asset target, then verify the actual cmap.
        # No source, dependency, SDK or native host file is modified.
        (ROOT / 'build/flutter_assets/packages/yaru/assets/yaru_icons.otf').unlink(missing_ok=True)
        for stamp in (ROOT / '.dart_tool/flutter_build').glob('*/release_bundle_linux-x64_assets.stamp'):
            stamp.unlink()
    status = subprocess.run(command, cwd=ROOT, env=environment).returncode
    if status:
        return status
    if source_hash() != source:
        raise RuntimeError('Build inputs changed during the product build')
    if revalidate_receipt(ROOT) != dependency_sources:
        raise RuntimeError('Official dependency proof changed during the product build')
    if platform == 'linux':
        bundle = ROOT / 'build/linux/x64/release/bundle'
        required = ('busydata', 'lib/libapp.so', 'backend/runtime/bin/java')
    else:
        bundle = ROOT / 'build/windows/x64/runner/Release'
        required = ('busydata.exe', 'flutter_windows.dll', 'data/app.so', 'backend/runtime/bin/java.exe')
    for name in (*required, 'backend/lib/busydata-backend-0.1.0.jar', 'backend/dependency-inventory.json'):
        if not (bundle / name).is_file():
            raise RuntimeError('Incomplete product bundle: ' + name)
    if verify_jar(bundle / 'backend/lib/busydata-backend-0.1.0.jar') != backend_identity:
        raise RuntimeError('Native build copied a different backend source identity')
    icon_font = None
    publication = None
    if platform == 'linux':
        publication = publish_public_bundle(bundle)
        from verify_linux_icon_font import verify_linux_icon_font
        icon_font = verify_linux_icon_font(bundle)
    files = []
    for path in sorted(bundle.rglob('*')):
        if len(files) >= 20000:
            raise RuntimeError('Product bundle file-count budget exceeded')
        if path.is_symlink():
            files.append({'path': path.relative_to(bundle).as_posix(), 'linkTarget': path.readlink().as_posix()})
        elif path.is_file():
            with path.open('rb') as stream:
                digest = hashlib.file_digest(stream, 'sha256').hexdigest()
            files.append({'path': path.relative_to(bundle).as_posix(), 'sha256': digest,
                          'bytes': path.stat().st_size, 'mode': path.stat().st_mode & 0o777})
    sdk = subprocess.run(resolve_command(['flutter', '--version', '--machine']), check=True, capture_output=True, text=True)
    report = {'buildId': build_id, 'buildSourceSha256': source, 'entrypoint': entrypoint,
              'startedUtc': started, 'finishedUtc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
              'command': command, 'exitCode': status, 'backendSourceIdentity': backend_identity,
              'officialDependencySources': dependency_sources, 'flutter': json.loads(sdk.stdout), 'files': files}
    if icon_font is not None:
        report['linuxWorkbenchIconFont'] = icon_font
    if publication is not None:
        report['publicBundlePermissions'] = publication
    destination = ROOT / f'build/{platform}-release-build.json'
    partial = destination.with_suffix('.json.partial')
    partial.write_text(json.dumps(report, indent=2) + '\n')
    partial.replace(destination)
    print(destination)
    return 0
