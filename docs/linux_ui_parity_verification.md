# Linux presentation verification record

## Review correction pass

The correction baseline is BusyData `ffbae95`; the read-only reference snapshot is
BusyMark `476ce5e`. New evidence is under `build/ui-review-corrections/current/`;
the complete portable handoff is `build/ui-review-corrections/busydata-comparison.zip`
and its standalone HTML. Source/font manifests, all comparison images and actual
run receipts travel together. Read that run's `verification-summary.json` for the
executed checks and their results. Previous run totals below remain historical.

Shared History search refreshes each time it mounts, including a matching cached
or empty page. Matching backend/query pagination is restored, cached rows remain
visible during the request, and the existing generation/backend admission guards
still accept or reject the response. Regressions cover A→A+B, empty→B and the same
query's page-two offset, alongside the earlier handoff and changed-query cases.

Linux action rows use the existing combined-name helper from selectors so the
command and effective binding appear together in `Semantics.label`. The trailing
badge is excluded to avoid duplicate announcements. Focus and activation remain
on the existing merged row. The pinned Linux engine uses a generic accessibility
node for buttons; its string-value implementation is empty, whereas its label
becomes the native name. This was checked in `fl_view_accessible.cc` and
`fl_accessible_node.cc` at engine `af7e796e16`. The widget regression now requires
the full label, one row, focus action/focused state and one Enter activation.

Native follow-through: open Settings → Keyboard shortcuts, inspect the button's
AT-SPI name (for example, `Run current statement: Ctrl+Enter`), focus the row and
press Enter to open its editor. The binding must be in the name, with no separate
duplicate badge announcement. This native assertion remains open until the real
accessibility procedure runs; a `Semantics.value` assertion cannot close it.

Both component capture fixtures assert that Copy, Selected value, Unavailable
action and More are visible before writing either menu image. The BusyMark fixture
uses the trigger's own focus node and explicitly selects the production Flutter
fallback when its native menu channel is unavailable. No reference production
widget is changed. These captures compare fallback presentation, not GTK menus.
The asset build explicitly targets Linux so native hooks resolve Linux assets.

The sandbox's Flutter listener still fails before test bodies. For this pass,
scoped execution outside that restriction was approved for the normal pinned
Flutter CLI. Its current receipts supersede the earlier supplemental runner's
limitations only for the checks actually executed. Native desktop, database,
performance, Windows, Arabic fallback and Wayland acceptance remain separate.

## Earlier port and interaction follow-up

BusyData baseline: `a9e4f3a3e98cb4859f5ad6cc0d1df1c96afa2163`.
Interaction follow-up baseline: `25ba5d8`. The follow-up inspects clean BusyMark
`9c3acfa` read-only and regenerates its captures from an isolated source snapshot.
Current follow-up evidence is under `build/ui-followup/current/`; the portable
handoff is `build/ui-followup/busydata-comparison.zip` and its standalone HTML.
The ZIP includes all images, source/font manifests and actual run receipts. The
standalone embeds its image/manifest links, addressing the earlier loose-index
handoff. Source and image hashes remain independently inspectable in the ZIP.
BusyMark was inspected read-only at `8b9aa85`, then revalidated at `3007fa1`.
Its later independent working-tree changes concern document history and editor
ownership. Their shared shell, control, menu and completion presentation was
rechecked; the final gallery records the exact isolated source snapshot, including
the reference's working-tree status. Those unrelated changes were left untouched.
The later reference change supplies the menu trigger context during cancellation;
BusyData retains its existing captured menu-session/focus protections. Adapted
source hashes and mappings are in `third_party/provenance.json`.

The ordinary composition and complete surface inventory are documented in
[linux_ui_parity_inventory.md](linux_ui_parity_inventory.md). The implementation
keeps database owners, reviewed actions, recovery, retained evidence, virtualization
and the independent Fluent presentation. The original presentation port did not
change backend operations, protocol, dependency locks, SDK or engine. The current
editor uses official unmodified packages and first-party source, native-input,
geometry and shortcut adapters through public interfaces. See
[editor dependency boundaries](editor_dependency_adapters.md) for the required
compatibility pins and official-source verification. Historical port evidence
does not certify the later dependency or editor changes.

Evidence is generated under `build/ui-parity/current/`. Its gallery index links
the exact source/font manifests, full production-widget captures, matching
BusyMark components, and the prior regression images. The complete applications
are instantiated with test storage/backend/native-channel fixtures; these images
are supplemental rendering evidence. They are not native desktop acceptance.
The comparison uses real Ubuntu/Yaru and resolved fallback fonts. Synthetic font
variation remains only in the separate layout/retention regression helpers.
Changed regression images were inspected before their goldens were updated.
The capture driver uses the pinned unmodified engine without the test-font
switches and loads the real font assets. The headless renderer still shows
missing Arabic fallback glyphs in both applications despite loading the actual
Arabic font. Those captures exercise RTL allocation but do not accept Arabic
typography or native font fallback. Neither application's font policy is changed
to conceal that limitation. The regression suite retains its normal test fonts.

Executed checks include pinned-toolchain verification, localization generation,
formatting, Flutter/Dart analysis, platform reachability/presentation guards,
Python tool tests, the affected widget suites, all Flutter test declarations,
and the ordinary Linux release build. Read the named logs and JSON receipts for
their actual results; successful compilation does not accept a native workflow.
The backend package and native helper checks execute with the pinned JDK.
Its SSH runtime smoke test requires a loopback listener and is unavailable under
the same socket restriction. The compiled Linux bundle therefore carries an
explicit unaccepted runtime-smoke record; no prior success is reused as current
acceptance and the release is not certified for distribution.

The standard `flutter test --no-pub --machine --fail-fast` invocation cannot start
its test listener here: binding `127.0.0.1` returns `Operation not permitted`.
It was interrupted after repeated listener failures. Supplemental execution uses
the unchanged pinned compiler and `flutter_tester`, with a fresh engine process
for each test file and the existing test declarations/assertions. Its runner,
per-suite results and aggregate report are retained alongside the logs. This
does not claim a successful standard Flutter CLI run. The two HTTP/2 contract
checks also require a real listening socket and remain unavailable here.

The native desktop gates require a private display/session bus and disposable
database containers. This sandbox denies socket operations, including private
Unix sockets. The Python speech-readiness socket test is likewise unavailable;
its other tool tests execute. Automatic approval review rejected the request to
run the Flutter test outside that restriction. The native workbench, Explorer,
accessibility, IME, three-engine database and release-performance paths therefore
remain unaccepted in this environment. Their budgets and assertions are retained.
No personal desktop settings or running applications were changed to bypass this.

Linux-host Fluent/widget coverage and Windows import-graph checks preserve the
separate platform implementation. Genuine Windows compilation/desktop acceptance,
Wayland/fractional compositor scaling, installed-product acceptance and distribution
packaging are not certified by this run. No push or publication is part of this task.

Prepare the read-only source identity snapshot:

```sh
python3 tool/capture_reference_gallery.py --reference /path/to/busymark --prepare-only
```

Standalone comparative rendering remains unavailable pending the reference's
independent hosted and native dependency verification. Preparation is not a
rendered comparison or native acceptance.

For native verification use the existing commands in
[development.md](development.md), including `tool/build_linux_release.py`,
`tool/verify_native_accessibility.py`, `tool/verify_database_ui.sh` and
`tool/verify_release_performance.py`. The gallery is a review aid alongside those
gates, not a replacement for them.

The follow-up regressions exercise actual Linux sidebar buttons, the mounted
History A→B handoff and query pagination, delayed/failed shortcut persistence and
direct retry, Settings-recorded Ctrl X/C/V reservations with clipboard/undo,
accessible shortcut semantics/focus/activation, regional locale normalization, retained
table navigation and text-location menus with an offscreen caret. The gallery also
captures a pending shortcut write, its retryable failure and Welcome after a table.
Visual inspection exposed a missing popup in the former SQL-menu capture. The
capture now asserts the actual menu is visible. A real Linux-popup regression
also covers right-click focus entry and real Copy/keyboard dismissal. The editor
completes its initiating focus change before preparation, then permits its own
popup's single focus handoff using the actual route and editing revision. Later
scroll, edit, lifecycle and focus cancellation keep the existing retirement policy.
The full-screen harness supplies an explicit empty clipboard response; a headless
engine has no real clipboard host. The Fluent text-menu adapter owns its selected
result close, avoiding a default null-result close before invoking Copy. This is
covered by its actual Flyout test and does not change the Windows presentation.
Read the follow-up summary/receipts for actual totals and gate failures. The socket
restriction and native/platform limitations above remain open until the genuine
procedures run successfully; a compile, supplemental test runner or gallery cannot
close those acceptance items.
