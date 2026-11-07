# Development and verification

Verification logs, XML, screenshots, source receipts and captured outputs belong
in ignored run-specific `build/` directories or CI artifacts. Do not commit them
under `docs/acceptance/`. Documentation describes enduring contracts; a past run
cannot certify later source.

Verification roots resolve physically. When temporary linked worktrees are moved
to external storage, reconnect them with `git worktree repair` and run gates from
their physical source directories. Preserve old generated outputs and rebuild
caches containing absolute source/owner paths; do not restamp old receipts or
weaken source-link checks to reuse them. Generated-directory aliases remain
ignored, and do not override artifact ownership validation.
Unix-domain test sockets use a private OS temporary directory to respect the
address-length limit. Keys, retained values and evidence remain in the owned
build output. Socket fixtures stop their owned agent and remove the socket.

Required release coverage remains incomplete until genuine installed strict-Snap
and native Windows/MSIX gates pass. Linux-host Fluent tests do not certify Windows.
Continuous native desktop SSH/mTLS database tours and IntelliJ runtime-default/
trust-combination equivalence remain unverified; backend security fixtures and
SSH-only editor tests do not establish those combinations. See
[security.md](security.md) for actual driver and native-transfer policies.

Use an approved disposable VM for local Snap build/install acceptance. The
existing selected test VM is `busydata-installed-20261003`; run the full pipeline
with `--installed-snap-vm busydata-installed-20261003` only when approved and
available. No Snap upload/publication or unrelated host change is part of verification. Missing installed/native stages remain
failed/unavailable, never passed by a staged-directory test.

Third-party dependencies must be official and unmodified. Package versions and
publisher archive hashes remain pinned in `pubspec.lock`. ReEditor 0.8.0 lacks
`TextInputClient.onFocusReceived` required by the approved Flutter SDK. The current
0.9.0 pin supplies the publisher's compatibility fix; HTTP/2 3.1.0 supplies the
official canceled-stream fix. These necessary changes and the first-party editor
and transport boundaries are documented in
[editor dependency adapters](editor_dependency_adapters.md). Neither an SDK patch
nor a modified package is an accepted workaround. Controller-only compilation
cannot certify editor ownership, exact text, undo, IME or native acceptance.
The [Linux UI review](native_linux_ui_review.md) preserves the earlier
restoration findings and distinguishes them from the current owned integration.

Runtime replacement of Flutter or ATK class/interface functions is prohibited,
including code located in the application runner. The former geometry, socket,
text-offset and tree-role patches have been removed from native composition.
Native accessibility gates still require correct geometry, Unicode selection,
editing, focus and tree relationships. Failures in the official runtime remain
failed acceptance checks. The standalone official-Flutter reproduction and GTK
control are described in BusyFiles' `engine/UPSTREAM.md`; no patched runtime is
an accepted verification input.

Exercise the current locked editor public API independently with:

```sh
flutter test --no-pub tool/diagnostics/re_editor_compatibility.dart
```

Native database clients are built from checksum-pinned, unchanged source using
supported linker configuration. Packaging copies their linked bytes unchanged.
Disposable image-based test clients use an application launcher and the image's
unchanged loader and libraries; they do not patch executable RPATHs or replace
workstation tools. Build fixture tools into a new output directory and verify
it before replacing an existing fixture tree.

Approved toolchain: Flutter **3.49.0-0.2.pre**, bundled Dart **3.14.0-211.1.beta**,
Temurin **25.0.4.1+1**, Maven Wrapper **3.9.11** / wrapper **3.3.4**.
Select the approved official beta SDK through the build process PATH.
config/toolchain.json is the shared
toolchain declaration. Verification requires the exact Flutter/Dart pins and
unmodified SDK; configuration checks prevent pins from diverging. Evidence reports
versions from executed tools, with configured CI versions labelled separately.
Java source requires 25, no preview features. Release bundling enforces the
maintained Temurin patch; `--development-runtime` is local validation only.

Routine CI (`.github/workflows/ci.yml`) runs on branch pushes and pull requests:
locked dependencies, toolchain checks, localization/protocol generation,
formatting, analysis, platform boundaries, complete Flutter unit/widget, Java
unit and Python tool suites. It retains test results for seven days and does not
run real-engine/desktop transfer fixtures or package Linux/Windows releases.

Full pre-release CI (`.github/workflows/verify.yml`) runs only through Actions
**Run workflow** (`workflow_dispatch`, select the intended branch/tag), or a push
of a release tag matching `v[0-9]*`, such as `v0.1.0-rc.1`. The equivalent manual
CLI event is `gh workflow run verify.yml --ref <branch-or-tag>`. It runs the
original three-engine database matrix, native transport, Linux desktop/settings/
accessibility, debug/release budgets, release bundle, both strict Snap packages
and native Windows build/tests. Snap requires successful database **and** Linux
jobs. Original logs/XML and source-bound evidence remain CI artifacts for 14 days.
Download required release evidence before expiry. No event publishes to a Store.

The hosted Snap job tests the disposable installed test-entrypoint package. Its
ordinary installed product gate is explicitly unavailable, so the full job fails
until the approved product gate is executed separately. Run the existing complete
VM machinery on an approved owned builder/runner:

```sh
python3 tool/verify_pipeline.py --scope database
python3 tool/verify_pipeline.py --scope linux
python3 tool/verify_pipeline.py --scope desktop-full --installed-snap-vm <approved-owned-vm>
```

The approved `busydata-installed-20261003` VM uses its dedicated
`busydata-test-docker.service` for disposable database fixtures. Before the
installed gate, start that existing service inside the VM with
`lxc exec busydata-installed-20261003 -- systemctl start busydata-test-docker.service`
and verify Docker access as the VM's `albert` test user. This does not enable the
service at boot or alter the host Docker service. A missing or stopped fixture
daemon makes installed database acceptance unavailable until it is restored;
an ordinary installed product launch alone does not establish that acceptance.

The aggregate owns a clean rebuildable Pub cache at
`build/official-dependencies/pub-cache` and a short temporary path at `build/t`.
It restores the caller's `PUB_CACHE` and `TMPDIR` afterward. The same resolved
package configuration supplies analysis, protocol generation, builds and package
inventory; protocol generation uses the pinned project `protoc_plugin`, without
global activation. A shared user cache is neither repaired nor cleared.

Before localization or editor gates, `official-dependencies` validates every
published regular package member against an official archive whose SHA256 matches
both the lockfile and fresh Pub version metadata. Unknown path/Git dependencies,
modified sources, injected files, missing archives and failed downloads fail the
gate. The same stage also verifies the approved SDK source revision and installed
SDK/runtime bytes against official publisher identities. Matching version strings
alone do not establish unmodified inputs. Inventory
creation revalidates the retained archive, metadata and resolved bytes before
packaging. The bootstrap/verifier bounds are described in
[editor dependency adapters](editor_dependency_adapters.md); they do not replace
product memory, document or transport limits.

On Linux, the aggregate Flutter stage enables both screen-gallery cases with a
fresh output directory owned by that verification run. It retains their dark and
light caption inventories and rejects skipped tests. The ordinary standalone
`flutter test` command leaves these capture-only cases opt-in; it does not replace
the complete aggregate scope. Caller-supplied gallery settings are restored after
the stage. Gallery captures do not substitute for native accessibility or genuine
Windows acceptance.

On a shared host, `--flutter-test-concurrency 1` runs the complete Flutter
unit/widget suite one file at a time through Flutter's supported concurrency
option. The aggregate records that exact command. The default scheduling,
individual test deadlines, gallery coverage and native performance workloads
remain unchanged. Use this option to bound verification's own parallel work.


The VM tool builds separate product/acceptance packages, installs and checks the
ordinary product's native window, activation, cleanup, payload and kernel labels,
then executes the confined test-entrypoint workflows. A staged/unpacked payload
or the test entrypoint alone cannot accept the product. Missing facilities or
failed checks remain failures; `--unavailable-installed-snap REASON` records an
unavailable gate and exits unsuccessfully for full acceptance.

On the genuine Windows 11 runner, run
`pwsh -File tool/windows/build_release.ps1`, then
`pwsh -File tool/windows/package_store.ps1 -ConfigPath <approved-test-config.json>`.
MSIX installation/Windows App Certification Kit acceptance additionally requires
approved artwork, test identity and matching signing inputs. The hosted workflow
records this unconfigured installed gate as unavailable and fails; the source and
native-build checks do not accept an installed MSIX. Both target-OS gates and
legal/Store review are required before a release decision. Keep Snap
`confinement: strict` and `grade: devel` until separately approved Store readiness.

```sh
export PUB_CACHE="$PWD/build/official-dependencies/pub-cache"
export TMPDIR="$PWD/build/t"
mkdir -p "$PUB_CACHE" "$TMPDIR"
flutter pub get --enforce-lockfile
python3 tool/verify_official_dependencies.py
flutter gen-l10n
backend/mvnw -f backend/pom.xml verify
python3 tool/generate_protocol.py
dart format --output=none --set-exit-if-changed lib test tool integration_test
flutter analyze
dart run tool/check_platform_boundaries.dart
flutter test
python3 tool/prepare_native_test_tools.py
cmake -S backend/native -B backend/target/native-build -DCMAKE_BUILD_TYPE=Release
cmake --build backend/target/native-build
ctest --test-dir backend/target/native-build --output-on-failure
backend/mvnw -f backend/pom.xml verify -Pdatabase-it
python3 tool/bundle_backend.py --java-home "$JAVA_HOME"
python3 tool/prepare_sources.py
python3 tool/dependency_inventory.py
dart --define=BUSYDATA_BACKEND_DIR="$PWD/backend/target/bundle" run tool/verify_backend_lifecycle.dart
python3 tool/build_linux_release.py
/usr/bin/python3 tool/verify_native_accessibility.py
xvfb-run -a flutter test integration_test/gtk_header_icons_integration_test.dart -d linux
xvfb-run -a flutter test integration_test/linux_window_close_acceptance_test.dart -d linux
bash tool/verify_database_ui.sh
```

The optional `--database-explorer` scope uses the ordinary release application's
visible namespace badge, two physical databases with duplicate table names,
data/DDL controls, category-origin console creation and console chooser. Run it
with `--engine MYSQL` or `--engine MARIADB` for the corresponding native database
tour. Its separate receipts do not replace the complete editing/export workflow,
platform matrix, installed strict Snap or native Windows gates.
The separate `--database-explorer-local` scope exercises named local definitions,
explicit Run/cancellation, nested source folders and normal disconnected relaunch.
It also retains its own receipt and cannot certify the complete workflow gate.
The independent `--database-explorer-tools` scope uses actual sequence, routine,
relation-subtype and restricted-database fixtures, exact document/search reveal,
view filters, external DDL refresh and compatible table comparison. PostgreSQL
also opens audit-schema data/DDL in both databases, checks selection changes
against the console's unchanged backend identity, and uses a fixture-owned catalog
lock to verify concurrent other-source refresh and reviewed deactivation. The
lock never changes application TLS policy or injects a session. Run all three
engine scopes; their receipts never substitute for the complete native workflow.
The tools tour also uses 160-column tables for complete Structure, exact late-child
search/reveal, generated-field restrictions and an ordinary reviewed import mapped
to a later column. PostgreSQL adds view-column/materialized-view-index reveal and
160 schemas to verify All-minus-exclusions, edits across namespace pages, Cancel,
off-page Default and disconnected restart through the normal controls.


`tool/verify.sh` is the Linux aggregate entrypoint; Windows uses
`tool/windows/build_release.ps1` and explicit `lib/main_windows.dart`.
Windows builds target only x64 Windows 11 24H2 (26100+) with the corresponding
SDK/Visual Studio requirements. Native single-instance tests are part of its
build. Database CI requires Docker and pulls every matrix image; missing stages
fail rather than becoming a passing skipped matrix. Testcontainers is test-only.
Exact Linux button/workbench PNG baselines run on Linux, where their reviewed
font rasterization applies. Windows records its complete selected file list and
the four Linux-only renderer files in `build/windows-flutter-test-scope.json`.
The Windows suite still rejects skipped tests; the full Linux suite executes the
renderer cases. This scope does not certify native Fluent presentation acceptance.

Native Windows window checks run against the ordinary release and its exact
`build/windows-release-build.json` receipt. Before moving or resizing a fresh
normal window, run `tool/windows/verify_initial_window_bounds.ps1` with
`-ApplicationPid`, `-ExpectedExecutable`, `-BuildEvidencePath`,
`-ExpectedSourceSha256`, `-SourceRevision` and `-OutputPath`. The script reads the
actual visible frame and monitor work area in physical coordinates, requires an
unminimized, unmaximized window within that area, and verifies restoration of its
calling thread's temporary coordinate context. The runner constrains its initial
size and position to that monitor's usable area; the display configuration is
unchanged.

The Windows shell gives Explorer and the workbench separate, stable semantic
pane containers. Shared search can add focused siblings and move the document
layout without merging either pane into the common semantic root. The widget
regression preserves pane ancestry, editor identity and the captured keyboard
focus through search transitions. Native acceptance must also observe current
controls and geometry after menu and keyboard transitions, with no rejected
AXTree updates from the unchanged Windows engine.

Native close acceptance uses one already-running verified release process with
at least one unsaved literal SQL document and no pending work. Run the
Windows-provided `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy
Bypass -File tool/windows/verify_reviewed_close.ps1` with the same identity/report
parameters and `-ExpectedUnsavedDocuments <count>`. It verifies the exact built
code/runtime hashes, sends one native close request, checks the safe draft-saving
review, approves once, and requires both the application and its one owned
backend to exit normally with code zero. A repeated review fails and leaves the
application open for inspection. The test never retries an approval or force-stops
the application. Verify the saved drafts on a normal relaunch separately.
BusyData's native runner owns this review before Flutter's framework close
delegate; all other window messages retain their normal dispatch.

The Windows procedure builds/tests BusyData's file-call DLL before Flutter tests.
Its tiny Win32 wrappers capture each return value and error in the same native
call, before Dart runtime work can change thread-local `GetLastError`. Standalone
Windows Flutter tests require that build and the explicit compile-time
`--dart-define=BUSYDATA_WINDOWS_FILE_LIBRARY=<absolute-built-dll>` argument.
Ordinary Windows builds load only the packaged `backend/native` DLL by absolute
path; they contain no test path or alternate filesystem policy.

Linux needs clang/cmake/ninja/pkg-config, libgtk-3-dev, libhandy-1-dev,
libsecret-1-dev and liblzma-dev. Prepare the verified release bundle, then use
`SNAPCRAFT_BUILD_ENVIRONMENT=lxd snapcraft` in a disposable LXD builder. CI follows BusyMax's
snapcore/action-build workflow, installs its locally built strict package with
`sudo snap install --dangerous <artifact.snap>`, and runs
`python3 tool/verify_installed_snap.py`. The separate installed-acceptance entrypoint runs the actual native launcher and
bundled backend inside strict confinement, with disposable external database/SSH
fixtures and an isolated desktop bus/keyring. It verifies real database cells,
TLS rejection, native file pickers, encrypted portal credentials, transfers,
new/changed host-key review, selected keys/agents, native dump/restore and primary
instance ownership. See the exact preparation commands below. It must be built
and installed as a separate test package; never package that entrypoint as the
ordinary product. Exceeding fixture or log budgets fails evidence. Keys outside
package-owned test storage require explicit `sudo snap connect busydata:ssh-keys`;
removable media also needs user connection. Tests under the installed AppArmor
profile, not a shell environment claiming SNAP, provide confinement evidence.

MSIX follows reference MakeAppx staging/unpack/hash verification in
`tool/windows/package_store.ps1`. Local engineering installation can use a separate
explicit test-only identity, matching local signing certificate and existing
BusyData artwork; production Store credentials are not required for that test.
Keep test configuration and certificates separate from production inputs.
`config/windows_store.example.json` is an intentionally unusable placeholder,
not fabricated Store registration. No Windows
10, extra architecture or alternate installer is supported. Native integration
and release package stages must run on the target OS before shipping.

Bundles contain backend/runtime, backend/lib, runtime smoke report, CycloneDX
SBOM, extracted dependency notices, Flutter dependency inventory, BusyData and
BusyMax notices, provenance, and checksum-verified full corresponding source
archives for Temurin/MySQL/MariaDB. RuntimeCheck verifies four dynamically found
JDBC drivers, SQLite JNI, EC/TLS1.3 and charsets in the jlink image. Explicit modules
avoid pulling jdk.jlink into Temurin's JEP 493 image through indiscriminate service
binding. Classpath SPI still discovers the drivers. Source preparation and
inventory failures fail verification; legal/distribution review remains required.

PerformanceIT uses PostgreSQL 17.11, fetch size 256, 1M rows and a 2GiB generated
source that must hit a 128MiB spool quota. The desktop performance integration
runs the actual Flutter process and bundled JVM under Xvfb against a disposable
PostgreSQL fixture, measuring combined RSS, first visible result, completion,
frame build+raster p95 and cancellation of an ordinary running PostgreSQL operation. Budgets are 768MiB combined **debug** RSS,
5s first visible result, 120s completion, 100ms p95 frame and 5s cancellation.
The fixture helper owns/stops only its created container and creates fresh private
XDG directories for each test. It fails if fixture cleanup fails.
Artifacts record hardware/configuration; debug results are not release budgets
or proof of bounded individual driver-cell allocation. CI never treats missing
fixtures or skipped matrix entries as passed checks.
The latest debug measurement is recorded in `build/performance-linux-ui.json`.
Run the actual release application acceptance with:

```sh
python3 tool/verify_release_performance.py
```

The verifier clears inherited display and Wayland variables before its owned
Xvfb process, forces the X11 backend with a private D-Bus session, and records the
release executable's actual display environment. The executable rejects a
mismatched display contract.
It uses the Linux composition and bundled backend, with an actual decoded cell
after layout, one million rows, running/queued cancellation, 130 execution/result
lifecycles, wide rows, a separate 6MB Unicode value, four concurrent physical
sessions, and a successful greater-than-2GiB direct export/import. Every exported
row and imported identity/value checksum is verified. Budgets remain 768MiB
combined RSS, 5s visible first cell, 120s million-row completion, 100ms frame p95,
1s queued and 5s running cancellation. Both processes are sampled through the
transfers, with Java heap/direct-buffer and private spool aggregates recorded.
The debug report also captures numeric glibc allocator bookkeeping at its initial,
combined-RSS peak and final sample points. These counts are separate from
resident bytes. The report keeps RSS as the acceptance metric and requests no
collection, heap inventory or allocator-policy change.
The export fixture is verified byte by byte, including its exact header, quoted
sequential IDs, every payload byte and the exporter's LF endings. The same single
stream computes the immutable import hash. Verification retains counters and a
small row prefix instead of decoding multi-gigabyte output into temporary line
strings. Full row/value checks and measured process scope remain unchanged.

Release frame measurements join the engine's physical frame IDs to the action
that rendered each frame. Batched timing delivery does not change phase
membership. The verifier waits within a fixed deadline for already-rendered
frames; that wait adds no warm-up frames and cannot dilute workload quantiles.
Missing, unknown, duplicate or over-budget timing records make the measurement
unavailable. Numeric summaries and bounded raw ownership/timing evidence are
retained on failure as well as success.

Each run keeps its exact executable bundle, actual tool/runtime output, image
digest, build-input hash, and `performance.json` in a unique
`build/release-performance/<run-id>/` directory, including failures.
`build/performance-linux-release.json` is only a convenience copy of the latest
report. A failed, stale or missing report cannot satisfy release acceptance.
The acceptance entrypoint is not the product entrypoint: rebuild
`flutter build linux --release -t lib/main_linux.dart` before packaging.
Linux distribution permissions are set only on completed generated bundle
copies, before desktop inventories or private acceptance archives are recorded.
Directories use `0755`; regular files use `0644` plus their existing execute
bits. Original SDKs, dependency/build caches and application state retain their
permissions. The owned acceptance archive is extracted with Python's safe
`data` filter. Because that filter ignores directory modes, the extracted
complete generated bundle is published again before Snapcraft reads it; the
controller's private umask and surrounding directories are unchanged. Public
bundle validation rejects changed permissions and unsafe links without repairing
an already recorded artifact. Private fixture parents, credentials and
recovery/TLS data keep their existing restrictive permissions.
Nonsecret controller probes pushed after VM preparation explicitly retain read
access for the unprivileged acceptance user. Their parent directories retain
private ownership and modes; other fixture files retain the controller's private
umask.

Linux installation and releases use the Snap Store only. The unarchived
`build/linux/x64/release/bundle` is required for native release testing and is
Snapcraft's product input; it is not a separate customer download. CI's temporary
`build/busydata-linux-x64.tar.gz` transfers exactly this compiled bundle between
Linux and Snap jobs while preserving symlinks and modes. It is an internal
intermediate and must not be published as a release.

The aggregate and recorder also create a local archive under `build/evidence/`,
with a collection index and SHA-256 sidecar. `build/verification-archive.json`
identifies the current run's archive or an explicit collection failure. It includes
the referenced Flutter output, Java XML, performance/runtime reports and native
diagnostic logs after verifying their hashes. Private fixtures, credentials,
documents, spools and preexisting reports are excluded. Nothing is uploaded.
For an earlier completed comparison run after source changes, use
`python3 tool/package_verification_evidence.py --run-id <UUID> --historical`;
the collection records the source mismatch and cannot certify current source.

The recorder fails on missing/failed stages, skipped Java tests, exceeded desktop
budgets, or inconsistent bundle hashes. Its explicit unavailable-acceptance flags
do not substitute for Windows, installed-package or accessibility verification.

Flutter tests may use repository-owned `build/tmp` and TMPDIR for local temporary
storage. Socket/desktop/fixture prerequisites must be available; a denied or
missing prerequisite is a failure, not a skipped pass. Windows execution and
signed-package installation require their genuine target environment.

Linux native accessibility additionally requires real AT-SPI GI, IBus/Cangjie,
Orca, Speech Dispatcher and xdotool. CI installs these facilities and treats this
stage as required. The verifier uses the ordinary product entrypoint and creates
its own display, bus, short private runtime/cache, documents and speech output.
It never changes the user's input-method settings, clipboard or desktop bus.
Reports and underlying reader/process logs remain under
`build/native-accessibility/<run-id>/`; the latest convenience record is
`build/native-accessibility-linux.json`.
The Linux aggregate retains separate complete MySQL workflows: `--engine MYSQL`
verifies explicit TLS Full Verification, while `--engine MYSQL --ordinary-mysql`
uses server TLS defaults, a fresh `caching_sha2_password` account and only General
settings for the first connection. Both run the complete catalog-engine and P0
result-editor tour. The additional `native-workflow-mysql-ordinary` stage retains
`build/native-accessibility-mysql-ordinary.json`; it does not replace the TLS
verification stage or its `build/native-accessibility-mysql.json` report.
The disposable ordinary account receives database-level grants plus `PROCESS`,
which MySQL requires for the native InnoDB table/column identities used to prove
editability. The fixture administrator grants and verifies this privilege without
authenticating as the application account, preserving its fresh authentication
path. BusyData never grants privileges. `OrdinaryMysqlEditingIT` separately checks
that database-level grants alone produce a typed denial, that an explicit
administrator grant enables a newly authenticated result, and that the original
retained result keeps its denied proof. See the official
[InnoDB table metadata requirements](https://dev.mysql.com/doc/refman/8.4/en/information-schema-innodb-tables-table.html).
The PostgreSQL restoration tour first verifies that relaunch opens no database
connections. After deliberate SQL and Explorer authentication, recovered table
browsing uses the selected Explorer physical session. Acceptance requires a new
retained result generation, exact rows, the selected physical owner and generated
SQL provenance. Initial and recovered browse proofs are retained separately;
credential-dialog appearance does not establish ownership.
The Value Editor tour captures the same source and authored modal before editing.
After focus and reader activity it reacquires the current field, waits for native
focus and stable reveal geometry, and checks the exact bounded original text.
It dispatches one local text edit and observes exact readback on the current field
before Stage. Retired controls, a replaced modal, changed source or original text,
and missing acknowledgement fail the case without replaying the edit. The native
bridge's exact epoch, revision and node guards remain unchanged.
The ordinary MySQL and large-catalog fixtures configure a 32MiB InnoDB buffer
pool and verify the actual server value. The ordinary MySQL container receives
512MiB, consistent with the default server startup footprint described in the
[MySQL memory guide](https://dev.mysql.com/doc/refman/8.4/en/memory-use.html).
The large-catalog and other core fixtures retain their 256MiB allocation.
The controller verifies the actual container limit before readiness. This is
fixture memory configuration, independent of the ordinary
connection's default TLS/authentication and General-only client workflow. The
workload, server version, application RSS limit and native checks remain the
same. See the official [MySQL 8.4 buffer-pool setting](https://dev.mysql.com/doc/refman/8.4/en/innodb-parameters.html#sysvar_innodb_buffer_pool_size).

The controller verifies the complete ordinary bundle against its recorded hashes,
including Flutter payload, backend JAR and runtime. It makes Orca diagnostic output
line-buffered using the supported customization in the owned XDG data directory;
reader behavior and speech remain real. Fixture credentials are checked against
bounded diagnostics and private fixture files must not be included in evidence
archives. No host reader/input-method preferences are modified.

The ordinary PostgreSQL tour separately cancels an advertised window-manager close
request and verifies restored SQL ownership before approving the owned header's
close review and checking recovery after relaunch. Aggregate GTK integration tests
force X11 under Xvfb and use a private session bus; an inherited Wayland display
cannot redirect those tests to the host desktop.
The integration test configuration installs the owned Linux semantics binding
before Flutter's generated integration runner initializes its binding. Keep that
configuration hook when adding native test entrypoints; initialization in a
test's `main` alone is too late.

Native settings acceptance runs the ordinary release entrypoint under actual
light/dark, high-contrast/reduced-motion and 200%/RTL settings. Keep its failed
source-bound reports when correcting a defect, then rerun the full verification
from a new frozen snapshot. `test/workbench_scaled_layout_test.dart` covers
fractional allocations, additional retained executions and multiple result sets
with actual cells in Yaru/Fluent LTR/RTL. The native modal controller verifies
focused control ancestry and separately records plan approval and result waiting;
it does not weaken visibility or substitute a focused window for control focus.

For an already populated locked Flutter cache when network resolution is
unavailable, use `bash tool/verify.sh --offline-flutter`. Its dependency stage
still executes `flutter pub get --enforce-lockfile --offline` and fails if the
required cache is missing or mismatched. Subsequent builds/tests use `--no-pub`
after that successful check. A standalone local build may similarly run the
locked pub get first, then `python3 tool/build_linux_release.py --no-pub`;
the actual commands remain in evidence. No versions or dependencies change.

Strict Snap now builds pinned PostgreSQL 17.11, MySQL 8.4.10 and MariaDB 11.8.9
client-only sources using `tool/build_snap_native_clients.py`; full matching source
archives and licenses remain beside the tools. The checksum manifest is
`third_party/native_client_sources.json`. Prime fails if the relocated binaries,
source archives or build inventory do not verify. `tool/verify_native_clients.py
--root <package-root> --output <record.json>` records actual tool version output
and file hashes. These clients are selected automatically inside Snap; outside
confinement, backup/restore retains explicit compatible-tool selection. Client
build and real database round trips do not substitute for installed confinement,
portal, SSH-key/agent and desktop acceptance.

`python3 tool/build_snap_acceptance.py` builds a separate release acceptance bundle
and restores the ordinary product bundle. Its archive is never substituted for a
published product. CI packages the ordinary product and preserves it separately,
then installs a strict test package using this acceptance entrypoint. Compile its
external fixtures using:

```bash
backend/mvnw -f backend/pom.xml test-compile dependency:build-classpath -Dmdep.includeScope=test -Dmdep.outputFile=target/installed-fixture-classpath.txt
python3 tool/verify_installed_snap.py
```

The verifier creates its own DBus/Xvfb session, portal/keyring data, selected agent,
and real PostgreSQL/MySQL/MariaDB TLS servers. It checks installed artifact hashes
and the actual AppArmor profile. Native file chooser automation requires xdotool,
system Python GI and `gir1.2-atspi-2.0`; it checks the intended chooser's exact
Unicode text before releasing the GTK clipboard, including when a reader requests
the clipboard first.
the portal and keyring daemons must be installed. Missing services, inaccessible
agent sockets, or failed cleanup fail acceptance. User profiles/keyrings/desktop
settings are never replaced. Installed evidence includes per-workflow results and
underlying logs in `build/installed-snap/`. The latest record must match the
installed package and current source; failed or historical runs do not accept it.

Every backend JAR embeds a build-time source identity derived from current Java,
protocol, POM and its generator. Bundling verifies that identity, and native
build recorders verify the actual copied JAR after building. A rebuilt Flutter
executable cannot certify an older backend. Source changes require Maven verify
and runtime bundling again. Windows uses `tool/build_windows_release.py` through
the established PowerShell entrypoint, retaining the complete native bundle hash.

For the built strict Snap, keep `SNAPCRAFT_BUILD_INFO=1` enabled and inventory
its actual unpacked files and generated versioned stage-package manifest:

```sh
python3 -m venv build/snap-inventory-tools
build/snap-inventory-tools/bin/pip install -r tool/requirements-verification.txt
unsquashfs -d build/snap-product-files build/busydata-product.snap
build/snap-inventory-tools/bin/python tool/verify_snap_distribution.py --prime build/snap-product-files --output build/snap-distribution.json
```

The isolated inspection environment does not replace workstation dependencies.
The inventory requires versioned package receipts, retained copyright files,
actual native-client hashes/sources, Flutter/runtime inventory and Java CycloneDX
SBOM. Missing licenses or receipts fail it. This records distribution inputs;
it does not fabricate legal, Store or signing approval.

Replacing the generated release bundle requires refreshing BusyData's dump
plugin pull output. Run `snapcraft clean busydata` in its disposable builder
before rebuilding a different entrypoint; this retains the separate native
client parts. CI does this between ordinary and private acceptance packages.
Part cleaning may leave an untracked optional private-test marker in shared prime;
the recipe resets only this BusyData-owned file before the current payload copy.
Prime also runs `verify_snap_payload.py` against the actual project bundle,
never its cached part source. It checks launcher/app/backend/runtime bytes,
executable permissions, exact JAR catalog and private-manifest presence.
A bounded read-only public-path check also requires `0755` for every required
payload directory and public file readability, using the bundle publication
mode policy. The two declared runtime executables, `busydata` and the bundled
`backend/runtime/bin/java`, must also be readable and executable by all users;
matching owner-only executable modes in source and prime are insufficient.
The read-only check accepts root-owned prime files without relaxing the separate
publisher's ownership checks, and never changes packaged modes. A successful
Snapcraft exit or dependency inventory alone cannot certify payload
freshness. No upload/publish command is part of these verification paths.

Java test JVMs place temporary files under `backend/target` from JVM startup. This
keeps large disposable fixtures off a small shared `/tmp` mount; it changes no
product storage policy, workload, heap cap or spool quota. Required performance
assertions still fail on disk exhaustion, and their original reports are retained.

jlink also uses `backend/target/jlink-tmp` through its JVM startup property.
`tool/jlink_runtime.py` retains bounded diagnostics and a `jlink.json` receipt,
rejecting nonzero exits, timeouts, truncated output and zero-exit `Error:` or
`objcopy:` errors. Runtime smoke checks run only after this build gate. Inspect
`backend/target/bundle/jlink.log`, `jlink.json` and `runtime-check.json`; a smoke
check alone cannot make a failed image build acceptable.

Strict installed acceptance also requires the invoking account's normal systemd
user bus at `/run/user/<uid>/bus` (`dbus-user-session`). On disposable CI/VM accounts,
`loginctl enable-linger <test-user>` starts that normal user manager. Snap creates
its ordinary tracked scope through this bus. After confinement, the exact product
command chain receives the separate abstract test bus for private portals/keyring.
The outside controller verifies the actual Flutter and Java kernel AppArmor labels;
it does not add a product permission to read `/proc/self/attr/current`. The owned
bus uses ordinary EXTERNAL authentication and standard session policy. Personal
keyrings, portal configuration, desktop settings and activation environments are
not changed.

The controller inspects installed Snap metadata locally and never contacts the
Store for an installed-app prerequisite. It updates DISPLAY/configuration only
on its owned private daemon (never with `--systemd`) and waits for actual portal
service ownership before starting product work.

The tailored runtime includes `java.rmi`: Apache MINA SSHD session creation
loads `java.rmi.ServerException`. RuntimeCheck performs a real private host-key
review, exact pin approval and authenticated forwarding against an ephemeral
loopback fixture, in addition to JDBC discovery, SQLite JNI and TLS providers.
Creating a client without opening an SSH session is insufficient validation.

## Canonical release source

Finish included code, tests, tools, documentation and notices before freezing the
run. `tool/source_policy.properties` defines included files, transient exclusions
and intentional executable semantics. The canonical manifest sorts normalized
relative paths and records type, SHA-256, size and policy-defined mode. Incidental
chmod, extraction permissions, owners, timestamps and absolute paths are excluded.
The historical `docs/acceptance/` output path is excluded explicitly; ordinary
documentation and test fixtures remain source inputs.
Source symlinks, traversal and case collisions fail packaging. Portable intentional
IDE configuration is included; generated IDE/library/cache state is excluded.

The verifier creates `canonical-source-manifest.json` and `busydata-source.zip`
inside its UUID run. It safely extracts the ZIP and recomputes the exact manifest
before starting and before sealing evidence. Every stage and the Java build
receipt use that same full-source identity. Independently verify downloaded files:

```bash
python3 tool/verify_source_artifact.py --manifest MANIFEST --archive SOURCEZIP --expected-source-sha256 SOURCE_HASH
python3 tool/package_verification_evidence.py --verify-archive EVIDENCE --expected-sha256 ARCHIVE_HASH
```

A final commit can change Git metadata without changing canonical source bytes.
Record its revision and reproduced source hash in a build-only handoff receipt;
do not mutate included documentation after verification. Any included source
change requires a new full run and fresh archive. No old artifact can satisfy it.

For selected-file finalization see [output_commit.md](output_commit.md).

Import admission uses the production helper in
`lib/src/backend/tool_admission_requests.dart` in both the UI and native/release
fixtures. CSV/JSON preview, review and start each have a five-minute transport
budget for the existing 8GiB source bound; ordinary unary calls retain 30 seconds.
This is independent of the transfer job deadline and the native controller's
outer allowance. Hashing checks explicit RPC cancellation between 64KiB reads,
and the transfer document offers cancellation while admission is pending.
Deadline failures remain failures, with no automatic retry. Source permits retain
their 120-second review lifetime and are consumed before the long start check.
Run `flutter test test/tool_admission_requests_test.dart test/transfer_document_test.dart`
and the Java `ImportTest`, `SourcePermitTest` and three-engine `ImportAdmissionIT`
regressions when changing this boundary. Release performance still requires the
actual multi-GiB import to complete within its existing job and resource budgets.

Native AT-SPI acceptance requires `xdotool` in addition to the documented reader,
IBus and D-Bus tools. A test-only extracted distro package can supply that binary
through PATH; keep any local library search changes inside its wrapper rather
than the product/Java environment. Retain actual package, binary and setup hashes.
Do not waive a missing-tool failure or change native assertions to accommodate it.
The owned Snap VM's approved fixture CLI is
`/opt/busydata-docker/docker/docker`; this test facility is not a product dependency.

The supplemental `--database-explorer-tools` tour has a 1,800-second outer
controller allowance for its 25 PostgreSQL cases, including paged namespace
editing, restarts and catalog-lock ownership. Individual native-action/state
waits remain bounded at their existing values. The ordinary required controller
keeps its 600-second allowance. A controller deadline retains the last existing
`progress.json` checkpoint, source identity and bundle hashes; it is a failed
run, never a completed action or accepted performance result. Debug/release
workloads and all release/performance thresholds remain unchanged.

The native settings matrix retains the six established cases and adds dark high
contrast (`HighContrastInverse`, verified in the installed GTK3 catalog) and
German at 200% text with reduced motion. These are real private GTK/GSettings
cases, not provider fixtures. Performance reports also record the mounted
workbench's effective font, text/display scale, direction and viewport at the
start and end without changing the workload or sampling span.

Native editor discovery recognizes the localized `sqlEditorLabel` template and
preserves its document title verbatim; the reader check requires the actual
translated label. Numeric interface-label normalization must not reinterpret
arbitrary titles or SQL. Result-reset checks wait for the captured old cells to
retire and the same selected document to complete before resolving exact source
keys and values. Ambiguous stable source identities remain failures.
Controls whose English labels are shared by different messages use their actual
ARB key, including its existing English fallback, rather than another domain's
translation of the same word. Reader checks require the translated editor noun
at both initial focus and final acceptance.
Native input acknowledgements reacquire the same named field when semantics
reflow temporarily removes its node, within the original deadline. They do not
repeat input or focus requests; transport and ambiguous-owner errors still fail.
Complete native-tree reads have at most three attempts. Between attempts the
controller dispatches at most 32 pending GLib events so queued child removals
can retire old AT-SPI proxies before the next root traversal. A failed traversal
provides no evidence of control absence; persistent errors and node limits fail
the gate. These reads never repeat an input or database operation.
The C child-count API's `-1` error result and PyGObject's corresponding
`atspi_error`/code-1 exception both make the entire snapshot unavailable. After
three unsuccessful attempts, a post-acknowledgement modal wait may read a new
snapshot within its original deadline. Only a complete tree without the captured
modal acknowledges dismissal. Other error domains/codes remain failures; lasting
unavailability reaches the existing deadline. Bounded read diagnostics retain the
action, counts and transport code, without native messages or values. Failure
receipts preserve the original workflow stage before diagnostic capture.
See the official [AT-SPI child-count contract](https://docs.gtk.org/atspi2/method.Accessible.get_child_count.html).

Product photographs first read raw focus through the pinned
`xdotool getwindowfocus -f` interface. X11's valid `None` and `PointerRoot` states
require the existing synchronized focus request to the captured owned product
window. For an ordinary focused window, an exact match or a verified
`WM_CLASS` ancestor match preserves the existing control focus. Other observed
windows require that same synchronized request. Unavailable or malformed reads
fail; command errors are never interpreted as unfocused states. See the official
[Xlib input-focus contract](https://xorg.freedesktop.org/archive/current/doc/libX11/libX11/libX11.html).
This does not replace keyboard, field-focus, reader or physical-pixel assertions.
Grid refresh diagnostics retain bounded native action, ancestry and state
observations to distinguish a missing eligible control from a wrong owner.
Read-only SQL, JSON and raw-plan evidence use `WorkbenchCodeEvidence`: the native
technical text role and an LTR code paragraph inside an otherwise RTL interface.
Regression coverage checks punctuation geometry, exact clipboard contents and
retained selection/controller state across native-style font/theme changes.

The rapid Owned sessions handoff focuses its Close button before dismissal,
then sends Return and the palette shortcut as one ordered physical-key sequence
with no inter-key delay. It never focuses or edits the palette query through
AT-SPI after dismissal. An AT-SPI action acknowledgement alone cannot establish
ordering between its queued Flutter callback and separately dispatched X input.
Focus restoration resolves once at route pop, through the public focus manager,
from the route's synchronous accepted-pop hook; a Future continuation is too late
for a native key batch. Linux and Fluent modal routes share the same captured
leaf, route and scope ownership policy. Linux modal futures retain their wait for
route completion; Fluent modal futures retain their stock popped-result timing.
A key arriving before the next frame must not remain attached to an inactive
dialog. Regression tests cover keyboard and pointer dismissal, deferred page
focus, and paired public native key channels with no awaited replies between
Return and the palette chord. Newer routes and intentional leaf focus still
take precedence. Instrumented
native focus traces are diagnostic builds with their own artifact hashes and
entrypoint, never the ordinary acceptance bundle.

The GTK icon integration entrypoint also exercises real X11 keyboard Menu and
Shift+F10 popups, including opening-key release, captured activation and return
to the same focused row. It requires the existing native test tools on `PATH`
and their shared libraries available to the process. Run Orca reader tours
serially: the installed Orca launcher checks for any Orca process owned by the
same user, even across private displays/buses. Do not replace an unrelated
reader to make an acceptance run start; retain its startup failure instead.

## Linux presentation verification

The current workbench correction contracts and eight screenshot workflows are in
[ui_correction_pass.md](ui_correction_pass.md). Their evidence uses
`build/ui-correction-pass/current/`; rendering supplements the required native gates.

`docs/linux_ui_parity_inventory.md` maps active callers to the current BusyMark
components. Keep reference checkouts read-only; use a copied tree for generated
files and builds. Record its commit, dirty status, relevant source hashes, real
font paths/hashes and toolchain. A later unrelated reference edit does not
invalidate a source-bound snapshot, but relevant component changes must be audited.

Standalone `tool/capture_reference_gallery.py --prepare-only` may retain read-only
source snapshots, including legitimate first-party sibling packages. Build and
capture modes first revalidate BusyData's official-source proof, then stop with
`REFERENCE_DEPENDENCY_VERIFICATION_UNAVAILABLE` before invoking Flutter. The
reference application needs independent verification of its hosted dependencies
and embedded native sources; BusyData's hosted-package receipt does not certify
them. The tool records this unavailable prerequisite in
`gallery-build-availability.json`. Do not report a prepared snapshot as a passed
comparative capture. BusyData's own native verification runs independently.

The production theme preserves Yaru role typography; GTK font-point normalization
is not a product option. `test/support/presentation_fonts.dart` provides synthetic
role-size variation for layout/retention regressions. It is not comparison evidence.
The reference gallery loads actual Yaru and resolved system fonts. Inspect source-
bound component and full-screen images before changing any reviewed golden.

Run the normal Flutter suite, localization generation, formatting, analysis,
platform boundaries and ordinary release build. Linux-host Fluent tests supplement
Windows reachability checks; they do not certify native Windows. Native workbench,
Explorer, accessibility/IME and three-engine disposable-data tours still require
their real facilities and existing budgets. Never report a source guard, mock menu,
widget capture or alternate test runner as native acceptance. A sandbox which
rejects loopback/D-Bus/X11 sockets cannot run these native stages or the Flutter
CLI's test transport; retain its actual error and complete independent checks.

Package comparison evidence after writing the actual run summary:

```sh
python3 tool/build_ui_comparison_gallery.py --output build/ui-followup/current
python3 tool/package_ui_comparison.py --evidence build/ui-followup/current \
  --receipt build/ui-followup/current/receipts \
  --archive build/ui-followup/busydata-comparison.zip \
  --standalone build/ui-followup/busydata-comparison.html
```

The ZIP includes images, source/font identities and receipts with preserved paths;
the standalone HTML embeds every image and linked manifest. Packaging rejects
missing links or image hashes that no longer match. It makes existing evidence
portable and does not change native acceptance requirements or performance budgets.

The review correction bundle uses `build/ui-review-corrections/current` with the
same gallery/package commands above. A menu capture must first assert its popup
items are visible; a trigger-only image cannot certify an open menu. On Linux,
shortcut action rows must expose both command and binding in the accessible name,
using the existing selector helper. Generic native button nodes omit string values;
verify the AT-SPI name and focus/Enter activation in the native accessibility tour.


## Coordinated workbench foundation verification

Source-bound pre-change evidence is captured before architectural edits. Do not
reuse historical counts or debug measurements as current release acceptance.
The focused contracts are `MetadataSnapshotTest`, `MetadataPlatformIT`,
`SemanticLanguageTest`, `LanguagePerformanceTest`, `EditAssignmentsTest`,
`EditorAssignmentsIT`, `RetainedAggregatesTest` and `RelatedRowsIT`, alongside the
existing complete suites above. No mocked engine fixture replaces the three
pinned real servers. Independent language RPC tests cover admission, cancellation,
operation mismatch, strict versioning and byte limits.
All six language requests have a 1MiB envelope, at most 262,144 source UTF-16
units and 64 inspection entries with 128-unit codes/16-unit severities. Six
reserved transport admissions remain separate from four language CPU slots and
the 16MiB execution/review envelope. Rebuildable metadata storage and schema-4
user-data migration are distinct from strict protocol 15. `SourceIdentityTest`,
`SourceIdentityMigrationTest` and the three-engine `SourceIdentityIT` cover map
order, captured physical ownership, preserved source/column keys without a cache,
and atomic rollback with draft recovery. MySQL's option allowlist remains narrower
than PostgreSQL/MariaDB; tests never enable an unsupported option. Optional saved-draft
timezone fields 10/11 preserve presence; absent historical facts are not invented.
`JdbcRecoveryShapeIT` compares current signatures with the original pinned-driver
`getColumns` recovery shape across native types, verifies exact wildcard-containing
identifiers under active SQL modes, and checks private-view restoration failure
without changing the console context. Native structural precision is verified
separately from these durable JDBC transport facts.

The language performance fixture defines a normal123UTF-16-unit SQL document,
10000 relations,100000 columns, duplicate names across10 namespaces,1000 foreign
keys and1000 routine signatures. Five warmups precede20 samples per service;
completion/parameter information have250ms p95 budgets and diagnostics750ms.
Machine/runtime and measurements are written to ignored
`backend/target/p0-language-performance.json`. This JVM gate is separate from the
ordinary release desktop frame, combined RSS, transfer and million-row gates.
Metadata tests separately exercise a larger indexed structural fixture.

Editor tests exercise shared row/draft identity, four modes, exact value and
binary interpretations, bounded structured parsing, assignment recovery and native
controls at100/150/200% with LTR/RTL. Native accessibility, genuine Windows and
installed strict-Snap acceptance retain their original independent requirements.
`test/complete_value_test.dart` and `test/result_complete_value_editor_test.dart` cover explicit bounded complete
acquisition, split UTF-8, exact binary page edits, cancellation, stale ownership,
failed drafts and delayed staging replies. `test/temporal_display_test.dart` and
`test/result_display_format_dialog_test.dart` cover exact fractions, native pattern validation,
focus and stable-column persistence. Complete acquisition is bounded to 1MiB,
262,144 text units, 32 replies and ten seconds. Binary presentation buffers/page
drafts share 2MiB with existing text drafts; the text-only 1MiB and 16-cell limits
remain. These focused fixtures do not establish release frame/RSS acceptance.


The P0 editor verification matrix includes
`flutter test test/result_editor_accessibility_test.dart test/result_presentations_test.dart`.
It uses the actual Yaru and Fluent adapters at 100%, 150% and 200% text scaling in
LTR and RTL, high contrast and reduced motion; widget semantics do not certify
native accessibility or Windows. The ordinary
`/usr/bin/python3 tool/verify_native_accessibility.py` tour requires
`nativeP0ResultEditorVerified`: native presentations/Record View, exact staged
Value Editor edits, explicit discard, aggregate scope, staged cloning, reviewed
relationship navigation, custom temporal display and chunk/complete-value inspection.
It checks the captured document and independent durable database rows before and
after the tour. The existing three-engine native scopes and genuine platform
requirements remain required.

`tool/verify_release_performance.py` additionally measures production result
presentation switches and Record View over its million-row retained fixture,
restoration of an unstaged typed-value draft through view changes, and actual
Value Editor rendering of an explicitly loaded 64KiB chunk from a 6MB retained
value. Sixteen ordered native text pages, each at most 8,192 UTF-16 units,
reconstruct the exact 131,072 hexadecimal characters; a native field never
receives the entire chunk's encoded text at once. The read-only field receives
a finite viewport and owns its native scrolling and selection. Page changes
retain that native field's render and gesture owners, dismiss its old toolbar,
and reset selection and scrolling before replacing the represented text,
including when adjacent pages contain identical strings.
Per-phase build+raster p95 remains below 100ms; Flutter and combined resident
growth are bounded to 64MiB and 96MiB respectively, in addition to the unchanged
768MiB global combined-resident gate and 2MiB decoded row cache. No additional SQL
job or retained-result copy is permitted during those presentation operations.
On Linux, the native launcher sets glibc's arena limit to two and fixes mmap and
trim thresholds at 128KiB before GTK/Flutter initialize. The owned Java process
receives the same startup allocator settings; inherited `GLIBC_TUNABLES` does not
override this resource policy. This affects allocation and release, rather than
the amount of data retained by the application. No periodic trim or forced GC is
used. Both debug and release desktop gates measure the resulting RSS, latency
and frame times. See the official [glibc allocation parameters](https://sourceware.org/glibc/manual/latest/html_node/Malloc-Tunable-Parameters.html).
Java uses its documented client compiler configuration with
`-XX:+NeverActAsServerClassMachine`, retaining the existing 32MiB initial heap,
128MiB maximum heap, Serial GC and 64MiB direct-memory ceiling. The child-process
heap probes use these same startup settings. `ProductionMetadataHeapProbe`
records the actual compiler policy, compiler thread count and reserved code cache
through the supported HotSpot management interface. Neither reserved code cache
nor heap limits bound total process RSS; both desktop gates remain required.
Installed acceptance requires each engine's `p0-result-editor` stage and its exact
text/binary, aggregate, clone, reviewed relationship and unchanged-source receipts;
an aggregate passing boolean cannot replace those receipts.
The installed fixture supplies a new primary-key assignment before reviewing a
cloned insert, captures the current session/context and metadata snapshot before
requesting related rows, and removes dependent fixture tables before native
restore. Failure receipts identify the operation checkpoint and allowlisted RPC
reason without retaining database messages or values. These checks use the
production ownership and review contracts.
Editable installed-fixture selections qualify their configured table namespace.
With a public-table fragment and excluded system schemas, an unqualified
PostgreSQL reference cannot presume that an earlier implicit `pg_catalog` scope
is empty. The retained-proof regression requires that reference to remain
explicitly partial; it does not weaken the provenance guard to make editing pass.

Native workflow evidence also requires drained, source-bound application logs
for the primary process and every relaunch. Each process retains its own bounded
log. Framework exception banners, release Dart error stacks, unhandled
exceptions, render overflows and fatal engine output fail the run, including
when an earlier process failed before a successful relaunch. Aggregate ordinary,
Fluent rendering and platform-matrix receipts revalidate their child log hashes;
workflow booleans cannot substitute for the raw completed evidence.

The native result-editor fixture binds its two primary keys and exact values to
the refreshed retained source coordinates. Table browsing without an explicit
sort must not assume a row order; Record View navigation, staging, cloning,
aggregates, related rows and reader checks follow those captured coordinates.
The fresh source and owner checks remain required. See PostgreSQL's
[row ordering contract](https://www.postgresql.org/docs/17/queries-order.html).

`ProcedureTemporaryMetadataIT` runs the production jobs and change planner against
the pinned MySQL and MariaDB servers. It covers qualified and unqualified sources,
temporary tables created and removed by procedures, independent-session isolation,
old result provenance and fresh permanent-table edits. Run it through the normal
database matrix, or focus it with:

```sh
backend/mvnw -f backend/pom.xml verify -Pdatabase-it -Dit.test=ProcedureTemporaryMetadataIT
```

`PhysicalRelationClassificationIT` covers cancellation before user SQL and denied
native classification with a still-readable result. `MariaTemporaryInventoryIT`
covers levels, configured scope and physical isolation. `OwnedTemporaryStreamingIT`
checks the pinned drivers' actual streaming result implementations for multirow
native column inspection. These fixtures supplement the full three-engine matrix.
`SmartQueuedRefreshIT` orders real catalog reads around explicit acquisition and
an ordinary user read. It verifies that a superseded queued refresh preserves the
newer structural snapshot, while a failed initial refresh without newer evidence
still leaves cached coverage stale.

`ProductionMetadataHeapTest` runs normal concurrent language service, atomic
publication with four captured readers, and a separate 32MiB retained-allocation
workload under the shipped 128MiB heap, Serial GC and 64MiB direct-memory ceiling.
Its normalized fixture contains 10,000 relations, 100,000 columns, 3,000
constraints, 2,000 foreign keys and 3,000 routine signatures. It records service
samples, p95 and maximum elapsed time, heap usage, and JVM uptime boundaries for
publication and measurement so separate GC logs can be correlated. Availability
failures retain the stable diagnostic code, safe controlled reason and operation
elapsed time; SQL and values are never diagnostic content. Existing latency and
analysis deadlines remain mandatory.

`MetadataCacheRestartHeapIT` supplements the pure heap probes with normalized
SQLite cache persistence, a separate 128MiB restart, explicit metadata-settings
availability, full synthetic reconciliation through the platform, and exact
persisted/native model checks. A bounded 256MiB seed process isolates fixture
construction from the production-reader measurement. PostgreSQL supplies a real
physical owner across both JVM lifetimes; the large catalog itself is synthetic.
The cache's existing resource preflight may reject adoption, but the regression
requires explicit unavailability and successful bounded reconciliation rather
than treating an empty/partial model as complete. Warm completion and parameter
information require available output, the existing 250ms p95 limit and zero
native JDBC calls/new connections. Focus this gate with:

```sh
backend/mvnw -f backend/pom.xml verify -Pdatabase-it -Dit.test=MetadataCacheRestartHeapIT
```

`ExecutionMetadataHeapTest` verifies pre-execution provenance independently of
language-service reader lifetimes. Its child JVM uses the shipped 128MiB heap,
Serial GC and 64MiB direct-memory ceiling, the normalized 118,000-object fixture,
eight index generations, seven retained execution candidates and 32MiB of
additional retained allocation. It requires collection of the seven superseded
snapshots and exact finalization of every candidate. A separate control measures
the previous full-snapshot retention topology under the same limits and records
its actual outcome. Explicit collection belongs only to the test. Commands,
runtime context and individual reports remain in unique ignored target output.

```sh
backend/mvnw -f backend/pom.xml test -Dtest=ExecutionMetadataTest,ExecutionMetadataHeapTest,RoutineResolutionTest,MetadataPublicationPrecedenceTest
```


## Unmodified native-client fixtures

Native tools remain official, unmodified upstream build outputs. The source-build
packaging helper supplies supported PostgreSQL linker settings and CMake RPATH
settings before linking, then verifies byte-identical copies. It never rewrites
ELF files after linking. Corresponding checksum-pinned source, builder settings,
installed file hashes and explicit unmodified-source/output provenance accompany
each packaged client. Package verification rejects missing or modified provenance.

On Linux, `python3 tool/prepare_native_test_tools.py` freshly acquires the pinned
official container images. It copies each client, its loader and its complete
shared-library closure without rewriting them. First-party launchers use the
[glibc loader's supported options](https://sourceware.org/glibc/manual/latest/html_node/Dynamic-Linker-Invocation.html)
to select those exact libraries ahead of host or desktop-platform libraries.
They preserve the reviewed BusyData SSH forwarding preload; TLS hostname and
certificate verification remain exercised by `NativeBackupTlsIT`. Fixture clients
are exposed at `backend/target/native-tools/<engine>/<tool>`, while untouched ELF
files reside in `upstream/`. There is deliberately no fixture `bin/` directory
that could bypass the launcher. Packaged clients retain their normal `bin/` paths.

The public fixture path atomically selects an immutable, manifest-hash-identified
generation in the adjacent `.generations` store. Every successful preparation
really reacquires and verifies clients; a running launcher pins the physical
generation so a later publication cannot change its libraries or executable.
Failures retain the previous pointer and fail the command. Corrupt assets and
unmanaged existing output directories fail explicitly and remain preserved;
select a fresh `--output` or review and move an inactive unmanaged directory
before preparing it again. There is no silent reuse or fallback to old clients.

Preparation admits at most eight generations, 2GiB of cached files, 256MiB and
2,048 files per generation, with bounded command output and deadlines. Official
image file sizes are checked before copying. A complete generation retained after
a publication failure counts against these limits. The preparer does not delete
potentially active generations: cleanup requires explicit review after their
consumers finish. Image identities, repository digests, source paths, client and
runtime hashes, preparation identity and tool-source hash remain in
`fixture-tools.json`. Preserve this ignored evidence with the verification run.

Supported build configuration is documented by
[PostgreSQL 17](https://www.postgresql.org/docs/17/install-make.html),
[CMake install RPATH](https://cmake.org/cmake/help/latest/prop_tgt/INSTALL_RPATH.html)
and [CMake build RPATH selection](https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_WITH_INSTALL_RPATH.html).
The focused native-client Python suite verifies actual launcher argument passing,
transitive library precedence, source/output integrity, publication failure,
concurrent preparation and repeated acquisition. These focused checks supplement
real three-engine native backup/TLS tests and installed-package acceptance.

Schema capture and comparison use [typed version 2 schema artifacts](schema_artifacts.md). Version 1 user files are converted in memory at import only when their retained native evidence can be verified; the original file is preserved. Exact same-name constraints retain their native type, source and components through central metadata and reviewed migration generation.

Revision-envelope regressions cover delayed replies across source configuration
changes, transaction-overlay retirement, session retirement and backend restart.
Use `MetadataEnvelopeProtocolTest`, `MetadataSettingsEnvelopeTest`,
`MetadataRpcOwnershipIT`, `RelatedRowsOwnershipIT`, `SessionContextIT`, `SessionAdoptionIT` and
`SessionCleanupIT` together with the shared registry and Explorer/widget tests.
Related-row budget tests exercise the actual protobuf mapper, including exact
byte-boundary cases, rather than a duplicate size predicate. Run protocol
regeneration before Dart analysis and run the complete aggregate pipeline against
the final committed source; focused checks do not replace native acceptance.
