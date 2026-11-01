# Third-party components

BusyMax source ports are listed in `provenance.json` at revision
`bf98600229d803f24ca5295e408379d1537aad08`; `BUSYMAX_NOTICE` preserves its notice.
Runtime Dart dependencies resolve to unmodified official Pub artifacts. No
runtime package source is patched or maintained in this directory. The resolved
`fluent_ui` 4.16.1 and `yaru_window` 0.2.2 remain at their existing versions;
platform-specific application composition remains BusyData-owned.

Two minimum dependency changes address demonstrated upstream incompatibilities.
Official `re_editor` 0.9.0 implements the Flutter input-client callback absent from
0.8.0, which cannot implement the pinned Flutter interface. Official `http2`
3.1.0 includes upstream cancellation handling for late response headers. Its
unknown-header handling does not by itself preserve BusyData's stricter rejection
of unsolicited response streams. Both transport contracts must be verified through
the first-party backend transport before acceptance. `grpc` remains 5.1.0; its
existing public transport APIs remain required.
See [editor dependency adapters](../docs/editor_dependency_adapters.md) for the
primary references, first-party extension boundaries and verification contract.
Neither dependency change authorizes retries or changes transport security.

`tool/verify_official_dependencies.py` compares every published package member
with the exact official Pub archive, validates the archive against fresh official
version metadata and the lockfile, and rejects missing, modified or injected
files. It reads an owned clean cache without modifying a package or SDK. The
packaged dependency inventory revalidates and binds that receipt. Package
licenses remain in the official packages and are copied into the bundled notices.

Maven generates a CycloneDX SBOM. The runtime bundler selects exactly the current
runtime classpath, removes stale dependency versions and extracts JAR notices.
The Java image retains its `legal/` directory. `tool/prepare_sources.py` fetches
checksum-pinned full source archives for the distributed Java runtime and GPL/LGPL
JDBC components. `tool/dependency_inventory.py` records hashes, Flutter dependencies
and their licenses alongside the backend inventory. These are build artifacts;
they do not publish anything.

Before a release, preserve the full source archives and notices in the package,
include BusyData's own source/build files, and validate the actual Snap/MSIX payload
and native dependencies. Producing an SBOM alone does not certify distribution
compliance. Installed-package and Windows validation remain release gates.

Production presentation tests explicitly load unmodified DejaVu 2.37 interface
and monospace fonts from `test/fonts/`, with their Bitstream Vera copyright and
license. Their origin and hashes are recorded in `provenance.json`. They are
not product runtime fonts or a dependency change. BusyMark revision
`87eebfe9847b62752450f33785c386883818ed29` informed native presentation principles;
no BusyMark source files, runner, palette or font defaults were copied.
