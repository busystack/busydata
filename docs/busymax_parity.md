# Native platform design and provenance

`third_party/provenance.json` records the actual copied BusyMax source revisions,
source/destination mappings and Apache-2.0 notices. Copied-source provenance must
retain the revision used, independently of later reference checkout changes.

| Reference component | BusyData destination/adaptation |
| --- | --- |
| Design, Yaru theme, surfaces and search styles | BusyData equivalents with native controls/themes retained |
| Linux host/frame/header and GTK services | Same GTK3 Handy/single-engine host, coordinated sidebar, font/icons/animation/window preferences/native menu |
| Dialog identity/modal barriers/window close | Shared shortcut/focus coordination with database pending-work guards |
| Windows runner/single instance/system appearance | Independent BusyData identities, standard caption/DPI and reviewed database close |
| Windows app/workspace | FluentApp.router/NavigationView/System Icons with shared database content and Fluent dialogs |
| Locale resolver | English fallback, Portuguese filtering and Chinese script resolution in both compositions |
| Secure-storage portal mechanism | BusyData generic encrypted credential records, without provider migration |
| Fluent/Yaru/editor integration | Official unmodified packages; first-party editor source, input, focus and reduced-motion adapters use public APIs; historical notices remain in Git |
| Package helpers | Native launcher plus bundled runtime/backend; approved identities/artwork supplied separately |

Calendar/timezone/tray/notification/startup-activation workflows are not BusyData
features. The original reviewed visual golden and its test-only reference caption
remain useful regression fixtures, not product branding or compatibility aliases.
Regression coverage retains host/frame/header/menu/dialog/close/theme, native
font/icons, high contrast, encrypted portal and Windows single-instance contracts.
Shared database widgets use the platform controls of their workspace.

The current Linux presentation port uses BusyMark `8b9aa85`, inspected as a clean
read-only snapshot at task start. `third_party/BUSYMARK_NOTICE` and the per-file
SHA-256 values in `provenance.json` identify adapted source. Reused presentation
includes Yaru role typography, checked controls, sidebar navigation, retained
transitions, header allocation/gestures, compact overlay, icon raster rendering,
reduced-motion window controls, tabs and autocomplete surfaces. BusyData's close,
modal, clipboard, native-menu retirement and database owners remain authoritative.
No BusyMark editor/document/search provider, command registry or integration
subsystem is imported. The port has no runtime dependency on the reference.

Later unrelated BusyMark edits are preserved. The observed header-menu cancellation
callback refinement carries its trigger context for focus return; BusyData keeps
its existing captured trigger/session focus policy instead of changing that API.

`DesktopAppearance` and the existing controls boundary now carry paired selection
foregrounds/backgrounds, focus, disabled and consequential-state roles. Shared
workbench rows, measured labels and one SQL presentation builder consume them.
One header search owns Current SQL, Database Objects, History and Actions; the
existing operations retain their captured owners and budgets. Native
menu sessions, modal isolation, editor/session ownership and backend identities
retain their existing implementations. Four database object icons are original
symbolic drawings; their provenance and test-only DejaVu font licenses are
recorded alongside, rather than replacing, earlier copied-source notices.

New production-theme workbench/palette/source-manager visual fixtures supplement
the original reviewed button fixture. Running captures, native settings/reader/
IME receipts and aggregate verification remain source-bound evidence under
ignored build directories. A populated widget golden or Xvfb integer-DPR test
does not certify compositor fractional scaling, genuine Wayland, installed Snap
or native Windows/MSIX. See the presentation checklist in
[ui_workbench_spec.md](ui_workbench_spec.md) and the current run's evidence for
the implementation/acceptance distinction.

BusyData's Linux runner hosts the ordinary FlView inside an owned GTK container.
Owned ATK nodes project public Flutter semantics with exact view/owner revisions,
Unicode-to-UTF-16 action mapping and real view bounds. Conservative field geometry
is identified explicitly; per-glyph geometry is not promised. Focus dispatches
the public Flutter semantic focus action through the existing owner. Runtime
replacement of upstream classes or interfaces, private engine layouts, additional
engines and second views are prohibited. The ordinary native regression must run
again after bridge or SDK changes. See
[native accessibility ownership](native_accessibility_bridge.md).

Strict portal bootstrap uses `nameHasOwner(org.freedesktop.portal.Desktop)` rather
than denied bus-name enumeration. Encryption, portal FD retrieval and explicit
session-only fallback retain their original mechanisms; no bus/keyring permissions
are broadened.

Database adaptations include shared all-tab close policy, document-owned output,
retained editor/grid controls across progress, native high-contrast foregrounds,
measured compact/scaled content allocations and bounded credential/recovery storage.
These do not replace the platform compositions or regenerate reviewed goldens.
Native acceptance verifies the complete ordinary bundle, including Flutter payload,
backend JAR, runtime and notices; a private test payload cannot borrow the same
runner executable as product evidence. Real theme/text/DPR/high-contrast/RTL,
reduced-motion, IME and reader conditions require actual composed-setting receipts.
Linux-host Fluent/unit coverage cannot accept genuine Windows or installed Snap.
See [native_transport_acceptance.md](native_transport_acceptance.md) for native
transport/accessibility requirements and [development.md](development.md) for gates.

The bounded Linux follow-up preserves the existing BusyMark reference usage.
Read-only property names remain associated with selectable metadata values,
plan disclosures share their selected foreground, and retiring modal routes
respect newer navigation/focus ownership. Native typography measurements are
scoped to the effective appearance rather than recomputed for unrelated progress.
Read-only SQL/JSON keeps its code paragraph direction within RTL application
layout, retaining the captured string and selection through appearance changes.
GTK popup grabs preserve the opening key's physical release back to the same
Flutter view, keeping subsequent native context-menu shortcuts operable.
These corrections keep BusyData's database/session and editor ownership model;
the current port and its copied presentation components are recorded separately
in `third_party/BUSYMARK_NOTICE` and `provenance.json`.
