# Database workbench presentation and behavior contract

## Current Linux reference

The authoritative presentation reference is BusyMark
`3007fa1` (initial clean snapshot `8b9aa85`; the later focus-only change was
revalidated during the port). The BusyData baseline for this task is
`a9e4f3a3e98cb4859f5ad6cc0d1df1c96afa2163`
(`redesign/professional-workbench`). The reference checkout is read-only. Both
lockfiles resolve Yaru 10.2.0. That original presentation port did not change
dependencies. The current official-package policy and first-party editor/input
adapters are specified in [editor dependency adapters](editor_dependency_adapters.md).
Source identity, captures and executed acceptance outcomes belong
in ignored run-specific `build/` output, separately from this contract.

BusyMark's current ordinary appearance governs Linux components and composition.
It does not replace BusyData's database grid, editor, session/document ownership,
capability checks, command registry, backend or security policies. No runtime
path to a reference checkout or external shared toolkit is permitted. Windows
keeps its separate Fluent presentation and Win32 host.

| Presentation role | Reference source | BusyData implementation and active callers |
| --- | --- | --- |
| Neutral surface roles, control states, geometry and typography | `app_theme.dart`, `busymark_design.dart` | `BusyDataYaruTheme`, surface resolver, `busydata_design.dart`; `LinuxControls` and all Linux production screens |
| Grouped lists, text entries, ComboRow/PopupSelector, actions and boolean rows | `busymark_design.dart`, Settings, Nextcloud settings | Connection manager, authentication, privileges, designer, transfers, comparison, snippets and Settings through semantic `DesktopControls` methods |
| Header, sidebar allocation and window controls | Linux header/page/window sources | `LinuxWorkbenchFrame`, `LinuxPageFrame`, `LinuxWindowHost`; leading sidebar/Back, title centered in the available control gap or retained full-gap search, contextual view selector, trailing Search and open-menu symbolic application menu |
| Welcome | `welcome_screen.dart` | `WorkbenchView._startSurface`; clamped Create/Open action groups with saved connections in Explorer |
| Sidebar records, tree controls, selection and focus | Design and workspace sources | `BusyDataSidebarRowSurface`, tree control; virtualized Explorer and shared `WorkbenchRecord` callers |
| Document tabs and representation selector | Workspace `_EditorTabStrip`/`_WorkspaceTabButton` | `WorkbenchTabs`, table Data/Structure header selector, execution results/messages, Structure and plans |
| Search entry and sidebar result hierarchy | `busymark_search_field.dart`, `search_sidebar.dart` | `SearchHeaderField`, `SearchSidebar`, `SearchResultList`; Current SQL, Database Objects, Query History and Actions over existing operations |
| Settings and per-action shortcut recording | Settings and keyboard shortcut sources | `WorkbenchSettings`, `WorkbenchShortcutCapture`, shared modal editor scaffold; immediate Appearance/shortcut acceptance and staged Execution/Private recovery over one acknowledged writer |
| Dialogs, status boxes, banners and compact actions | Design and document status bar sources | Linux dialog adapters, connection/test/trust feedback, shared status and output inspectors |
| Menus | Native menu service and GTK runner | Recursive Dart/GTK adapter with icons, checks, separators, shortcuts, direction and disabled explanations; BusyData menu retirement/focus protections retained |
| SQL typography and syntax roles | `BusyMarkSyntaxColors` and source editor metrics | `sql_presentation.dart`; first-party editor state and public official `re_editor` layout/input adapters in SQL, snippets and definitions |

## Shared visual and input rules

The central resolver produces the reference normal neutral palette. Runtime GTK accent/theme inputs remain live. Ordinary role typography preserves
Yaru’s resolved families, fallback chains, sizes, weights and line heights, as
in BusyMark. GTK font points do not replace or multiply those roles. MediaQuery
text scaling remains live; high contrast has paired roles and reduced motion
follows the system. Do not substitute unrelated GTK neutral roles for
reference component roles, hardcode a sampled accent, or patch individual screens
with decorative colors. Material primitives beneath Yaru are intentional.

Use the reference 760 content/settings clamp, 300 default sidebar, 38 pane/tab
strip, 28 status bar, 24 compact icon, 16 small icon, 4 small/tab radius, 8 sidebar
row radius, 14 tree indentation, 18 expander slot, 14 tree arrow and 6 header gap.
Component purpose determines radius mapping. Minimum geometry grows for real
font metrics and text scale; content must not be transformed, shrunk or clipped.
Grid and graph viewports use available workbench width without a prose clamp.
Measurements are bounded labels or representative lines, never full result sets.

Grouped entries put persistent labels, associated help/errors and the editor in
one grouped row. The row owns its surface; embedded input decoration removes a
second outlined rectangle. Browse, copy and reveal actions have independent
focus and semantics. Secret fields remain protected. Technical addresses remain
read-only, selectable, copyable and LTR inside RTL UI. Ordinary labels follow the
interface direction. Read-only properties keep one name/value semantic record.

PopupSelector represents a selected value; ComboRow activates a selector from a
whole preference row. Actions remain actions; real booleans use the reference
switch or checkbox. Neutral, suggested and destructive buttons preserve Yaru
geometry, typography, interaction overlays and keyboard focus. Sidebar records
use the reference neutral selection with visible focus, paired foregrounds and
compact geometry. Consequential production/read-only/unknown/failure states also
have text or symbols. Complete diagnostics are selectable/copyable and bounded
scrolling preserves pinned actions.

Linux has one application menu using `open-menu-symbolic`. Settings and the
retained Welcome/workbench route are application actions at its root. Documents
contains file/workspace actions; SQL execution groups Edit and Run options;
Database groups Connection and Object; View contains global tools. Document, Explorer, grid and caret
menus keep their captured scopes. Every existing command stays discoverable in
its contextual destination or Actions search. The ID inventory is in
[ui_reference_mapping.md](ui_reference_mapping.md). Registry labels, effective
shortcuts, checks, eligibility and captured invocation targets remain authoritative.
Settings receives an application-level menu without commands for the hidden SQL
editor. Local input, modal and shortcut-recording boundaries remain effective.

Header dependencies include current title, search, representation and command
eligibility without remounting editors. Ordinary titles center in the actual
leading/trailing control gap, including physical window-control obstructions.
Active search fills that gap and retains its text/IME state through the title
transition. Titles and the brand own native titlebar gestures. Narrow search uses
the reference sidebar overlay while retaining the body and Explorer elements;
closing it restores the previous Explorer visibility, width and focus. The ordinary
sidebar toggle is unavailable where its pane cannot be displayed.

Welcome initially covers only scratch created by this launch. Restored blank SQL
is data. An explicit Welcome route also covers retained work without closing its
documents, sessions, jobs or results; the workbench remains mounted. New connection,
New query and Open SQL keep their existing semantics. Welcome omits idle status
chrome and preserves actual backend, recovery and operational problems. Saved
connections keep their existing Explorer records; there is no second Recent store.
The presented destination gates contextual chrome: retained table target/session
controls and its Data/Structure selector are absent from Welcome's rendering,
focus traversal and semantics until returning to the workbench.

One search-session owner captures the focused Explorer or document context before
header or keyboard entry gives focus to search. Current SQL uses
the captured document, literal search and explicit revision-aware replacement with
existing editor undo. Database Objects reuses the owned inspection operation,
metadata admission, pagination, cancellation and response validation. History
reuses its existing bounded catalog/privacy operations; activation opens inspection,
and reopening SQL is explicit and never executes it. Actions uses the existing
registry and validates the captured target at invocation. A modal action waits for
the closing search surface to re-enable its retained origin before transferring
focus. A newer focus owner, route or active document cancels that pending handoff.
Context-invalid categories
cannot redirect old operations to a new document, session or backend. Query clear,
Escape, category selection, result navigation and IME stay local to search. Grid
filters and Explorer type-to-select remain local. Superseded global query bars
are removed; richer object/history management remains in its appropriate view.
Result navigation keys belong to the header query and result rows. Other focused
sidebar controls retain normal button activation. A History activation explicitly
hands its accepted page/filter/offset/selection to an already-mounted inspection
view; a revision retires older state writers. Retained History pagination requires
the query and captured backend that produced it; changed identities start at zero.

Settings remains in-window with Back, reference sidebar navigation, a narrow
category popup, grouped content and the 760-pixel clamp. Explorer and the workbench
remain mounted. Appearance offers supported languages and System/Light/Dark, applies
live after durable acknowledgement and has no page-level Save requirement.
Execution and Private recovery have staged validation and scoped Save/Discard
controls. Category changes retain their drafts, including invalid text. Back,
Close and application closure require an explicit save/discard decision for drafts.
Shortcut proposals are staged only inside the per-command dialog; acceptance
validates the complete keymap and saves it durably. Failure retains the proposal
and the last acknowledged active mapping; Cancel discards the proposal. There is
no second page Save. Recording suppresses commands and retains the reserved F6 /
Shift+F6 rules. Appearance, shortcut acceptance and database preferences use one
serialized settings writer, which builds merged snapshots at execution and applies
preferences only after acknowledgement. Recovery-disable review, reconciliation
restrictions and failure rollback remain authoritative. Settings never executes SQL
or resolves a database transaction to save a preference.
During shortcut persistence the shared editor scaffold shows saving, disables
recording and cancellation, and blocks departure. Validation errors and persistence
failures are separate: a failed write retains a valid, directly retryable proposal.
Shortcut rows expose both command and effective binding through their accessible
focus/activation node. One supported-locale normalization policy serves restored,
saved and displayed language preferences; unsupported tags safely select System.

SQL text-menu hints come from the same filtered re_editor activators used for
dispatch. A reserved binding has no hint when no alternative exists. Live remaps
replace the activator map without replacing the editor. Menu/Shift+F10 uses rendered
caret geometry clamped to the visible viewport and never scrolls an offscreen caret.
An initiating right-click completes the editor's own focus handoff before preparing
its menu. Selection-toolbar retirement admits that popup's single focus handoff
only while its actual route owns focus and the captured revision is unchanged.
Later focus changes and asynchronous clipboard replies still retire
obsolete popups; an earlier key release cannot enter a newly focused editor.

Connection drafts/controllers and their state machine remain authoritative. Test
uses the selected unsaved revision without saving/connecting; changes invalidate
its feedback and obsolete results are rejected. Apply acknowledges changed drafts
and removals while staying open. Cancel discards only uncommitted work and tests.
Completion explicitly says Save & connect and names the destination frozen when
the manager opened; selecting another source cannot retarget it. Acknowledged
saves survive later cancellation/failure. Saved/connect-failed is distinct from
unsaved/test-failed. Independent secrets, manual ports, timeouts, TLS, SSH trust
binding/review and late password/picker/test ownership checks are preserved.

Tabs use the reference leading dirty marker in place of the ordinary file icon,
then the title and close affordance. They retain safe close, middle-click/context
routes, disambiguation and dirty,
running, failure, production, transaction and unknown states. Their neutral strip,
rounded top corners and compact close controls replace the accent underline.
Offscreen activation reveals the tab without stealing editor focus; background
updates do not reset scroll or activate a document from accessibility focus.

The grid retains `TableView.builder`, pinned column/header, two-dimensional
scrolling, bounded cache/paging, source-row mapping and retained-result identity.
Its shared header separates representation, actions, result facts and important
pending/unknown states. Hidden columns normalize selected/anchor physical indices;
Home/End, Ctrl/Shift ranges, copy, inspection and editing use visible columns while
retaining exact underlying values. NULL/empty/unavailable/truncated/staged/deleted
remain distinct. SQL copy keeps backend literal serialization and admission limits.
Server browsing differs from retained-result transformations as before.

SQL target controls retain one presentation while only execution progress changes.
Every update still reevaluates command requirements. Reuse requires equal captured
document/result/job ownership, physical-session and context revisions, profiles,
locale, bindings and disabled reasons. Mutable protocol values are copied for
comparison. Selection, focus and native controls remain mounted; changed inputs
replace that presentation, and invocation keeps its existing live owner checks.

The first-party SQL editor owns its immutable controller state, undo/multi-caret, IME, clipboard and exact mixed-line-ending source,
analysis revisions, completion identity and scroll ownership. Official `re_editor` supplies read-only layout and hit testing through public
interfaces. BusyData owns the native input connection, exact old-text/revision
validation, bounded atomic admission/history, additional-range
painting, completion, accessible visible-line semantics and dynamic shortcuts.
Public paragraph observations carry exact editor/scroll ownership and become
unavailable until layout catches up after changes. See
[editor dependency adapters](editor_dependency_adapters.md).
Appearance changes
update consumed roles without replacing editor subtrees. Font reflow retains valid
viewport offsets after paragraph layout and yields to newer navigation; the main,
snippet, designer and local-definition editors share that behavior. The main SQL, snippet, object-definition and virtual-definition editors all use
one owned SelectionToolbarController adapter with the existing platform menus.
Cut/Copy/Paste/Select all retain clipboard budgets, read-only availability, revision
checks, multi-caret and line-ending behavior; Menu/Shift+F10 and Escape are local.
Completion uses the reference clipped popover, elevation, radius and label/kind
rows, stays bounded and reveals selection without taking input focus. `WorkbenchCodeEvidence` preserves
exact selectable LTR evidence within RTL UI. Its own semantic boundary keeps
adjacent object headings separate from the read-only technical value.
Generating/opening/saving SQL remains separate from execution.

Dialogs reuse reference visuals around BusyData's accepted-pop focus restoration,
newer-focus protection, closed-loop traversal, live barriers, native close
coordination and independently scrolling bounded bodies. `ModalCommandBoundary`
and local input boundaries prevent background shortcut execution. Native menu
sessions retain explicit ownership, pointer/keyboard opening, native focus return,
and event-after/key-release retirement: an old session cannot close a new menu or
send an obsolete release to a new editor.

The GTK/Handy application window still owns one Flutter view and Flutter chrome;
window controls follow GTK preferences. Source styling does not certify native
menu, Orca or IME behavior. Acceptance must execute the ordinary product, inspect
current light/dark reference comparisons before golden updates, cover 1280×720,
100/150/200% text, long locales/RTL, high contrast/reduced motion and live appearance
changes, and retain performance budgets. Linux-host Fluent tests do not certify
native Windows; Linux UI evidence does not imply Snap/release qualification.

Explorer browsing state is labelled separately from owned query sessions.
Routine identities come from Java native catalogs and match snapshot/dependency
keys, including PostgreSQL overloads. Composite index/foreign-key metadata rows
produce one logical Explorer node; Structure retains their ordered column rows.

Retained evidence keeps its original connection/execution identity. Independent
physical sessions are the default. Generated SQL holds a profile reference and
acquires a session only on an explicit database operation. Async work captures
its owner/backend/session/context and rejects invalidated targets, independently
of active-tab changes. Reviewed row changes use **Apply and commit**; manual SQL
transactions are separate and are never silently resolved to permit an edit.
Native browsing acceptance focuses the selected Explorer row before capturing
its physical session through Session details. A separately authenticated SQL
console is a different context. The opened table must prove a fresh result on
the selected Explorer session, exact rows and generated SQL provenance; both
observed session identities are retained even when equality fails.
Native table refresh acceptance requires a completed new retained-source
identity on the captured document, owner and target context, with exact visible
cell coordinates and values. Virtualized native controls may be reused when
their current result identifiers change. Widget retirement is not result
provenance; a local view change, an old retained source, mixed cell owners or an
incomplete observation cannot acknowledge a server refresh.

Preserve resource admission, F1–F12, output integrity, confinement, secrets,
session adoption, production review, strict wire identity and existing pins.
Presentation additions are validated optional version-1 fields; portable
workspaces contain ordinary SQL references only. Restoration never executes.

| Workflow | Product destination and owner |
| --- | --- |
| SQL files, workspaces, editor actions, snippets, completion | Linux Documents/SQL execution destinations (Fluent File/Edit), tabs, caret popup and shared search; Flutter documents, Java analysis |
| Profiles, testing, credentials, connect/disconnect/sharing | Data Sources and Drivers, target/connection menus; Java sessions/security |
| Tree browsing, search, table Data/Structure and object design | Explorer and captured object documents; Java catalogs/designer |
| Execute, cancel, manual transactions, retained results/messages | Target/Run and owned output; Java Safety, Jobs, transactions and retained stores |
| Grid paging, copy, value inspection, filter/sort and staged changes | Grid/Changes controls; Java retained views, row provenance and ChangePlanner |
| Snapshots/comparison, plans, diagrams and notes | Comparison/plan/diagram documents; Java schema/plan evidence, Flutter presentation/exports |
| Sessions/locks, diagnostics, capabilities, users/roles/grants | Connection administration and object tools; Java engine-specific services |
| Import, retained/direct/full-value export, backup/restore | Distinct transfer documents/actions; Java transfers/native tools and OutputCommit |
| History/privacy, recovery, jobs/problems and owned sessions | Optional global tools and review documents; their original Java/Flutter owners |

Close commands share one save/recovery/job/transaction policy across tab, keyboard
and native application routes. Retained output stays inspectable/exportable after
disconnect or saved-profile removal. Async actions revalidate the captured owner
before adoption/publication; configuration edits cannot retarget old results.
Recovery requires acknowledged cleanup before losing its owner and cannot replay
committed/unknown changes. Comparison exposes the complete coupled Current→Desired
batch with a separate Apply to target and no automatic migration application.

Compact/200%/RTL layouts measure native font metrics, preserve a pinned header and
actual data-row allocation, and retain actions in existing menus. Pane/size changes
preserve the mounted editor, text, undo, grid selection and focus. Shared search rows
preserve stable command order and the 256-command bound; live eligibility updates
retain the filter, selection and focus. Modal actions require a fresh enabled
visible control and verified focused-descendant ancestry, with bounded keyboard
acknowledgment; independent focused leaves or workspace escape fail acceptance.

Executable regression suites remain under `test/`, `integration_test/`,
`backend/src/test/` and `tool/test_*.py`. Implementation does not imply acceptance:
[development.md](development.md) defines current-source release gates and remaining
Windows/MSIX, installed Snap and security-coverage limits.

Open definition places the exact selectable SQL before descriptive properties,
so its beginning is visible at large text scales. Metadata availability and
source-provenance notices remain above the content. Java retains publication
fingerprints, physical-generation markers and internal identity evidence in the
authoritative metadata model; ordinary Structure details show database properties.

### Presentation correction and acceptance checklist

- [x] Read-only Structure properties merge their localized name and selectable
  value into one semantic record in either responsive layout. The read-only
  variant owns the value's real Focus action and visible focus boundary, keeps
  its existing Tab order, and retains text selection across responsive reflow.
  Input rows retain their own name without a second label announcement.
- [x] Plan branch disclosures and text use the same paired selected foreground,
  including focused and unfocused high-contrast states.
- [x] The presentation messages are explicit in every existing locale;
  ICU argument names/types and technical identifiers remain unchanged.
- [x] Captured designer/grant definitions and transfer SQL evidence use the shared
  selectable technical role without editing controllers. SQL/JSON code evidence
  preserves punctuation and indentation in RTL, including definitions, reviewed
  statements, activity/history SQL and raw plans.
- [x] Modal dismissal resolves the original live focus owner when its route is
  popped, before another native key can reach the retiring dialog. Restoration
  occurs once and does not displace a newer route or leaf. The modal future still
  waits for route completion/cleanup. Overlapping shared search retirement, deferred
  route focus, repeated reopening and nested-modal history have regressions.
- [x] GTK popups return actual releases of keys pressed in the existing FlView
  to that same view. Popup navigation stays with GTK; repeated Menu and Shift+F10
  invocations retain their captured row without synthetic activation or refocus.
- [x] Linux appearance and representative line metrics are retained within the
  application scope, invalidating for effective theme/font/scale/locale/direction.
  Header title, search state and command eligibility are live children; unrelated
  job progress does not replace editors. Diagnostic counters are opt-in and
  collect no database values.
- [ ] Native Structure reader, selected plan rendering and technical evidence
  inspection on the final ordinary product.
- [ ] Raw-keyboard rapid modal-to-shared search transition and scoped Explorer popups.
- [ ] Unchanged debug and release performance workloads and a fresh complete
  Linux aggregate, with immutable source/bundle-bound acceptance evidence.

Checked source items are implementation contracts; running acceptance remains
separate. Diagnostic frame spans do not replace either required performance gate.


## Metadata, SQL and result foundations

Connection → Metadata and introspection edits the Java-owned discovery policy,
including exact included/excluded namespaces, system visibility, object kinds,
bounded wildcard patterns and per-scope levels. Status pages state cache,
completeness, limitations and refresh work. Full/incremental refresh is explicit
and cancellable; closing a dialog cancels its owned request without retry.
Cache status uses localized labels. A pending cache write displays progress;
a failed cache write displays a separate failure notice while preserving the
published metadata and unsaved settings. Switching configuration/status sections
does not replace the settings draft.

Settings → SQL language stages formatting and inspection severity preferences per
dialect or data source. Completion and parameter information have independent
lifetimes; suggestions carry namespace/type/signature evidence. Formatting an
active selection uses exact source spans and applies through one undoable edit.
Parameter-information limitations precede overload rows: partial signatures are
labelled as incomplete, while a bounded overload list separately reports its
limit. The popup retains the current argument and independent cancellation owner.

The result selector exposes Table, Transpose, Tree and Text with the same source
selection and staged batch. Record View follows that selection without taking
editor focus. Value Editor exposes exact raw content and bounded interpretations,
explicit chunk loading/cancellation and full export. The editable text-page
indicator remains visible with its paging actions when options and outer dialog
actions need scrolling or wrapping. Aggregate scope is visibly
retained/partial. Clone opens staged insert assignments; related-row choices enter
the ordinary explicit browse review. DEFAULT, NULL, value and unset are distinct
controls. Local retained operations and reviewed server browse operations retain
their different scope labels. These surfaces use existing native DesktopControls,
localization, focus, shortcut and modal boundaries.
Metadata or physical-source uncertainty disables edits and relationship actions
with the existing structured availability reason. It preserves retained rows,
selection and drafts. A later metadata refresh cannot silently promote an old
result to editable or rerun the source SQL.

Source configuration changes retire visible Explorer and Structure metadata
through their existing native context/status flows and ordinary bounded metadata
requests. Snapshot changes alone do not reload every branch. Rejected refreshes
for the same owner and configuration retain their previous complete
presentation; a new owner/source/configuration/section cannot borrow it.
Related-row choices and review dialogs retain and recheck the complete metadata
ownership stamp.
