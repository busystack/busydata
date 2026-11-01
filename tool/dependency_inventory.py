#!/usr/bin/env python3
"""Inventory exact packaged backend files and Flutter package/license sources."""
import hashlib, json, pathlib, re, urllib.parse, os
root = pathlib.Path(__file__).resolve().parents[1]
from verify_official_dependencies import revalidate_receipt
official_dependencies = revalidate_receipt(root)
bundle = root / 'backend/target/bundle'
def checksum(file):
    with file.open('rb') as data: return hashlib.file_digest(data, 'sha256').hexdigest()
configuration = json.loads((root / '.dart_tool/package_config.json').read_text())
packages = configuration['packages']
dart = []
licenses = bundle / 'notices/flutter'
licenses.mkdir(parents=True, exist_ok=True)
for package in packages:
    uri = package['rootUri']
    if uri.startswith('file:'):
        location = urllib.parse.unquote(urllib.parse.urlparse(uri).path)
        if os.name == 'nt' and re.match(r'^/[A-Za-z]:', location): location = location[1:]
        path = pathlib.Path(location)
    else: path = (root / '.dart_tool' / uri).resolve()
    if package['name'] == 'busydata': continue
    specification = (path / 'pubspec.yaml').read_text()
    version = re.search(r'^version:\s*([^\s]+)', specification, re.M)
    license = next((path / name for name in ['LICENSE', 'LICENSE.md', 'LICENSE.txt', 'COPYING'] if (path / name).is_file()), None)
    if license is None:
        license = next((parent / 'LICENSE' for parent in path.parents if (parent / 'bin/flutter').is_file() and (parent / 'LICENSE').is_file()), None)
    if license is None: raise RuntimeError('Missing Flutter license: ' + package['name'])
    (licenses / (package['name'] + '.txt')).write_bytes(license.read_bytes())
    dart.append({'name': package['name'], 'version': version.group(1) if version else 'SDK', 'licenseSha256': checksum(license)})
manifest = json.loads((root / 'third_party/source_archives.json').read_text())
for archive in manifest:
    if checksum(bundle / 'sources' / archive['name']) != archive['sha256']: raise RuntimeError('Source archive validation failed')
report = {'version': 1, 'officialFlutterDependencySources': official_dependencies, 'pubspecLockSha256': checksum(root / 'pubspec.lock'), 'flutterVersion': configuration.get('flutterVersion'), 'flutterPackagesIncludingDevelopment': dart,
          'backendJars': [{'name': jar.name, 'sha256': checksum(jar)} for jar in sorted((bundle / 'lib').glob('*.jar'))],
          'sources': manifest, 'runtime': json.loads((bundle / 'runtime-check.json').read_text()),
          'declaredNativeRequirementsNotInstalledPackageSbom': {'linux': ['GTK3', 'libhandy-1', 'libsecret-1', 'liblzma5', 'GNOME core24 extension'], 'windows': ['Windows 11 24H2 x64', 'Microsoft VC runtime']}}
(bundle / 'dependency-inventory.json').write_text(json.dumps(report, indent=2) + '\n')
print('Inventory:', len(dart), 'Flutter packages,', len(report['backendJars']), 'backend JARs')
