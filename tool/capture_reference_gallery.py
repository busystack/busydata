#!/usr/bin/env python3
"""Snapshot current component identities from two independent checkouts.

The reference remains read-only. Its source and exact dependency lock are copied
to an ignored verification directory; no runtime dependency is introduced.
"""

import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.parse import urljoin, urlparse, unquote
from verification_evidence import source_hash
import verify_official_dependencies as official_sources


def command(args, cwd):
    return subprocess.check_output(args, cwd=cwd, text=True, env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"}).strip()


def presentation_class(source, name):
    start = source.index(f"class {name} ")
    opening = source.index("{", start)
    depth = 0
    for end in range(opening, len(source)):
        if source[end] == "{":
            depth += 1
        elif source[end] == "}":
            depth -= 1
            if depth == 0:
                return source[start:end + 1]
    raise ValueError(f"Unclosed reference presentation class: {name}")


def copy_tracked_tree(source, destination):
    files = subprocess.check_output(["git", "ls-files", "-z"], cwd=source).decode().split("\0")
    hashes = {}
    for name in filter(None, files):
        path = source / name
        if not path.is_file():
            continue
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        hashes[name] = hashlib.sha256(target.read_bytes()).hexdigest()
    return hashes


def copy_local_package(source, destination):
    """Snapshot an unversioned sibling package's actual build inputs."""
    files = [source / name for name in ('pubspec.yaml', 'pubspec.lock', 'LICENSE', 'NOTICE')]
    for name in ('lib', 'assets', 'hook', 'linux', 'windows', 'packages'):
        folder = source / name
        if folder.exists():
            files.extend(path for path in folder.rglob('*') if path.is_file() and not any(part in {'.dart_tool', 'build', '.git'} for part in path.relative_to(source).parts))
    hashes = {}
    for path in files:
        if not path.is_file():
            continue
        name = path.relative_to(source)
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)
        hashes[str(name)] = hashlib.sha256(target.read_bytes()).hexdigest()
    return hashes



class ReferenceBuildUnavailable(RuntimeError):
    """Reference snapshots are inspectable but are not certified build inputs."""


def require_build_sources(root, output):
    """Check BusyData first; never execute an unaudited reference build.

    The BusyData gate deliberately rejects arbitrary path dependencies and
    certifies this application's package owner. It cannot certify a different
    application, its legitimate first-party siblings, or embedded native code.
    A package-name exception or a caller-supplied verifier would not prove
    official upstream bytes. Reference verification needs its own audited scope.
    """
    busydata = official_sources.revalidate_receipt(root)
    detail = (
        "Reference build unavailable: independent official-source verification "
        "for the reference hosted and native dependencies is absent. "
        "Use --prepare-only for read-only source snapshots; no Flutter command "
        "will run. BusyData native verification remains independent."
    )
    (output / "gallery-build-availability.json").write_text(json.dumps({
        "status": "unavailable",
        "code": "REFERENCE_DEPENDENCY_VERIFICATION_UNAVAILABLE",
        "detail": detail,
        "busydataOfficialSources": busydata,
        "referenceBuildExecuted": False,
    }, indent=2) + "\n")
    raise ReferenceBuildUnavailable(detail)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("build/ui-parity"))
    parser.add_argument("--prepare-only", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    reference = args.reference.resolve(strict=True)
    output = (root / args.output).resolve()
    if output == root or root not in output.parents:
        raise ValueError("Verification output must be inside BusyData")
    checkout = output / "reference-checkout"
    checkout.mkdir(parents=True, exist_ok=True)
    copy_tracked_tree(reference, checkout)
    # An active reference working tree can import newly added, untracked source.
    # Snapshot those real build inputs too; never substitute archived code for it.
    supplemental_inputs = copy_local_package(reference, checkout)
    # Current BusyMark shares local Git packages. Preserve their exact relative
    # paths/working-tree bytes inside the isolated copy, without upgrading or
    # generating anything in any reference repository.
    path_dependencies = {}
    for relative in re.findall(r'^\s+path:\s+(\.\./[^\s#]+)', (reference / 'pubspec.yaml').read_text(), re.MULTILINE):
        dependency = (reference / relative).resolve(strict=True)
        copied = (checkout / relative).resolve()
        if dependency.parent != reference.parent or copied.parent != output:
            raise ValueError('Reference sibling package must stay inside its isolated output')
        versioned = (dependency / '.git').exists()
        path_dependencies[relative] = {
            'head': command(['git', 'rev-parse', 'HEAD'], dependency) if versioned else None,
            'status': command(['git', '-c', 'core.fsmonitor=false', 'status', '--short'], dependency) if versioned else 'unversioned local package; actual copied files hashed',
            'files': copy_tracked_tree(dependency, copied) if versioned else copy_local_package(dependency, copied),
        }
    workspace = (reference / "lib/src/workspace/presentation/workspace_screen.dart").read_text()
    extracted = "\n\n".join(presentation_class(workspace, name) for name in (
        "_WorkspaceTabButton", "_DiffCompareIcon", "_DiffCompareIconPainter"
    ))
    template = (root / "tool/ui_reference_gallery.dart.template").read_text()
    (checkout / "test/ui_reference_gallery_test.dart").write_text(
        template.replace("// @REFERENCE_TAB_PRESENTATION@", extracted)
    )
    (checkout / "test/ui_parity_screens_test.dart").write_text(
        (root / "tool/ui_parity_reference_screens.dart.template").read_text())
    fonts = {}
    for family in ("Ubuntu", "Ubuntu Sans", "Ubuntu Mono", "Noto Sans Arabic", "Noto Sans", "DejaVu Sans"):
        path = Path(command(["fc-match", "--format=%{file}", family], root))
        fonts[family] = {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    configuration = root / '.dart_tool/package_config.json'
    packages = json.loads(configuration.read_text())
    yaru = next(item for item in packages["packages"] if item["name"] == "yaru")
    yaru_root = Path(unquote(urlparse(urljoin(configuration.as_uri(), yaru["rootUri"])).path))
    for path in sorted((yaru_root / "assets/fonts").glob("Ubuntu-*.ttf")):
        fonts[f"packages/yaru/{path.name}"] = {
            "path": str(path.resolve()), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
    identity = {"fonts": fonts, "kind": "source-bound widget rendering; native facilities are fixtures"}
    identity["captureConditions"] = {
        "platform": "linux (explicit test override)",
        "accent": {"fullScreen": "#3584e4", "components": "reference default Yaru orange"},
        "fullScreen": [1280, 800], "compactScreen": [760, 720],
        "devicePixelRatio": 1, "textScale": [1, 1.5, 2],
        "clipboard": "empty native-channel fixture for text-menu availability",
        "brightness": ["light", "dark"], "nativeMenu": "themed fallback fixture",
        "locales": ["en", "de", "ar"], "highContrast": [False, True],
        "nativeIcons": "appropriate-glyph fallback; GTK raster acceptance unavailable",
    }
    for name, repo in (("busydata", root), ("busymark", reference)):
        rendered = checkout if name == "busymark" else repo
        identity[name] = {
            "head": command(["git", "rev-parse", "HEAD"], repo),
            "branch": command(["git", "branch", "--show-current"], repo),
            "status": command(["git", "-c", "core.fsmonitor=false", "status", "--short"], repo),
            "sources": {str(path.relative_to(rendered)): hashlib.sha256(path.read_bytes()).hexdigest()
                        for path in sorted((rendered / "lib").rglob("*.dart"))},
            "dependencyLockSha256": hashlib.sha256((rendered / "pubspec.lock").read_bytes()).hexdigest(),
            "sourceKind": "isolated snapshot of live tracked working-tree files" if name == "busymark" else "live BusyData sources",
            "captureHarnesses": {str(path.relative_to(rendered)): hashlib.sha256(path.read_bytes()).hexdigest()
                                 for path in [rendered / "test/ui_reference_gallery_test.dart",
                                              rendered / ("test/ui_parity_screens_test.dart" if name == "busymark" else "test/ui_parity_screen_gallery_test.dart")]},
        }
    identity['busydata']['buildSourceSha256'] = source_hash(root)
    identity['busymark']['pathDependencies'] = path_dependencies
    identity['busymark']['workingTreeBuildInputs'] = supplemental_inputs
    identity['busydata']['editorBridgeSha256'] = {
        name: hashlib.sha256((root / name).read_bytes()).hexdigest()
        for name in ('lib/src/ui/common/sql_editor_geometry.dart',
                     'lib/src/ui/common/sql_editor_view.dart',
                     'lib/src/ui/common/editor_shortcuts.dart')
    }
    (output / "gallery-source-identity.json").write_text(json.dumps(identity, indent=2) + "\n")
    if args.prepare_only:
        return
    require_build_sources(root, output)


if __name__ == "__main__":
    try:
        main()
    except ReferenceBuildUnavailable as error:
        print(error, file=sys.stderr)
        raise SystemExit(2)
