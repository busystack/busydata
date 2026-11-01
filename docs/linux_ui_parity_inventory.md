# Linux presentation inventory

Reference inspected: BusyMark `8b9aa85` initially, then `3007fa1`, and `9c3acfa`
for the interaction correction pass. The reference remained read-only; current
captures use an isolated snapshot. BusyData follow-up baseline: `25ba5d8`.
BusyData baseline: see `build/ui-parity/current/baseline-source-identity.json`.
The ordinary path is `main_linux.startLinux` → `LinuxBusyDataApp` →
`LinuxWindowHost` → `WorkbenchView(LinuxControls)` → `LinuxWorkbenchFrame` →
`LinuxPageFrame`. Common database views consume `DesktopControls` and
`DesktopAppearance`; Windows uses its independent Fluent adapter.

This table tracks active surfaces, not the presence of similarly named helpers.
Verification receipts and images belong in `build/ui-parity/current/`.
The correction pass records current evidence in `build/ui-followup/current/`.
The subsequent workbench correction uses `build/ui-correction-pass/current/` and
[ui_correction_pass.md](ui_correction_pass.md). It replaces repeated Structure
cards with metadata rows plus selected details, consolidates contextual controls,
shares creation-assigned document/source names, matches native tab focus and
uses the connection dialog's available height. Its current manifest records the
read-only BusyMark snapshot, including any unversioned sibling package inputs.

| Active BusyData caller | Current BusyMark implementation | Confirmed difference / integration | Verification |
| --- | --- | --- | --- |
| LinuxBusyDataApp / BusyDataYaruTheme | app_theme / BusyMarkTypography | GTK family replacement and size/11 scaling changes Yaru roles; preserve reference typography and accessible semantic colors | Theme roles, real-font captures, live appearance |
| LinuxWorkbenchFrame / header delegate | Linux header / workspace header | Title uses window midpoint, search does not fill control gap; native menu/Back artwork differs | Asymmetric controls, decoration sides, RTL, search focus/IME |
| LinuxPageFrame | LinuxPageFrame.sidebarOverlay | Compact search forces a split; retain mounted bodies across overlay allocation | Resize, compact opening/closing, Explorer width/focus |
| LinuxWindowHost | _LinuxWindowControl | Direct Yaru controls ignore reduced motion; Material storage icon in decorations | Host tests, live reduced motion, native gestures |
| BusyDataSwitchRow / checkbox | BusyMarkSwitch / RadioButton / Checkbox | Plain switch and global indicator suppression | Drag, hover/press, disabled, keyboard focus |
| WorkbenchView welcome / navigation | WelcomeScreen / workspace | Idle status chrome, no retained route back to start | Startup scratch and restored-document tests |
| LinuxWorkbenchMainMenu | BusyMarkMainMenuButton | Wrapped menubar → application roots plus Documents/SQL/Database destinations; Settings has no hidden document commands | Registry routes, local shortcut boundaries |
| WorkbenchSettings / navigation | SettingsScreen / SidebarNavigation | Generic records → ported reference navigation and preference rows; missing Appearance → immediate preferences; Back now guards drafts; shortcut acceptance not durable | Live persistence, failure rollback, guarded departure |
| WorkbenchTabs | _EditorTabStrip / _WorkspaceTabButton | Audit dirty position, close/overflow and database state badges | Tabs, scale, owner-safe close |
| SearchHeaderField / SearchSidebar | SearchField / SearchSession / SearchSidebar | One no-op Actions category plus independent SQL/object/history query bars | Captured owners, cancellation, IME, navigation, replacements |
| ConnectionForm / AuthenticationForm | GroupedList / TextEntry / ComboRow / modal scaffold | Audit nested row surfaces; SSH ellipsis lacks meaning | Connection draft/test/apply/trust suites |
| Four CodeEditor callers | editor_text_context_menu | No SelectionToolbarController | Pointer/keyboard, clipboard, read-only, stale owner, viewport |
| WorkbenchCompletion | _SourceAutocompletePopup | Square bordered box; missing secondary kind hierarchy | Containment, reveal, stale-analysis rejection |
| DatabaseExplorer rows | BusyMarkSidebarTreeRow | Conditional More insertion changes title allocation | Stable trailing slot, selected/keyboard menu, lazy paging |
| PlanView | Direction-aware sidebar tree | Left/Right expansion hardcoded | LTR/RTL disclosure agreement |
| ResultGrid / cell inspector | Pane headers, records, popovers, technical text | Database viewport retained; use shared chrome and paired states | Grid identity/selection/edit, virtualization budgets |
| Structure / ObjectDesigner / changes / comparison | Property rows, groups, technical evidence | Keep exact metadata, drafts and explicit reviewed application | Secondary-view suites, accessibility |
| History / snippets | Record/action rows, source presentation | Keep privacy, paging, reopen/insert/delete; centralize global query | History/snippet suites and search |
| TransferDocument / backup | Grouped forms, modal review, progress | Keep immutable reviewed inputs, overwrite/cancel and captured target | Transfer/review suites |
| Privileges / authentication | Grouped forms and action states | Keep engine capabilities and secret handling | Privilege/authentication suites |
| Activity / capabilities | Record/property/feedback hierarchy | Keep polling, cancellation and stale-target admission | Secondary-view suites |
| ER diagrams | Shared toolbar/menu/inspector | Keep graph and export-specific presentation | Diagram suite, pan/zoom/export |
| Jobs / problems / recovery / evidence | Status boxes, records, empty/error/loading | Persistent failures and unknown outcomes remain durable/selectable | Recovery/job/ownership suites |
| Native menus / modal shells | Native service / dialogs | Retain BusyData event-after, release retirement and accepted-pop protection | Menu/modal handoff, native accessibility/IME |

Native GTK3 Handy window + one FlView + Flutter chrome is already the common
architecture. The runner sets a default size and has no explicit GTK geometry-hint
enforcement of its declared minimum. Compact layouts do not assume native
enforcement; actual resize reachability remains part of native acceptance.
Ordinary text fields already use the same standard Flutter text infrastructure.
No app-wide replacement text-editing framework is justified by that fact.

The implementation now routes every listed common surface through the existing
platform controls/appearance boundary. Database-specific viewports, immutable
evidence and reviewed actions retain their original owners. Capabilities now
defers initial owned-request admission until after the shell frame; its complete
read-only details use the shared property rows. The full-screen harness exercises
these production callers rather than separate showcase widgets.

For final check results, screenshot provenance, and facilities that could not run,
see [linux_ui_parity_verification.md](linux_ui_parity_verification.md).

The correction pass traces these remaining active interactions:

| Active caller | BusyMark reference concept | Confirmed defect and correction | Regression evidence |
| --- | --- | --- | --- |
| SearchSidebar + SQL/History/Objects | Query/result keyboard routing | Descendant button Enter was consumed; only result-row focus owns sidebar navigation, and query owns its own keys | Actual Linux Replace all, Previous/Next and More buttons; query/row keys |
| HistoryView + existing inspection document | Captured search result → existing detail destination | Mounted details retained A after selecting B; observable revision handoff synchronizes accepted page, selection, filter and offset; stale disposal cannot write back | A→B with the same mounted details/owner; reopen B disconnected, no execution |
| HistoryView category remount | Query/session identity and refreshed search results | Cache requires the same query and backend object/instance; shared search always refreshes the accepted offset on mounting, with the cached page visible until acceptance | Category switching, changed query, cached A→A+B, empty→B, matching page-two offset on reopen; existing generation/backend rejection |
| WorkbenchSettings.assign + editorShell | BusyMark modal editor saving state | Recording/cancel stayed enabled and persistence error disabled retry; freeze proposal, visible saving/disabled cancel, separate validation and write errors | Delayed failed writer; same-proposal retry; acknowledged mapping unchanged on failure |
| Four WorkbenchEditorMenu callers | Text-location menu and effective hints | Nonexistent fallback hints and constant keyboard anchor; hints now use dispatched activators, anchor reads retained editor geometry | Settings remaps Ctrl X/C/V, actual clipboard/undo, distant visible and offscreen caret |
| WorkbenchSqlEditor shortcuts | Live effective shortcut updates | First-party public Shortcuts/Actions own current bindings and retire stale dispatch while retaining editor/controller | Live reservation removal restores displayed executable bindings |
| WorkbenchEditorMenu / platform menu presenters | Editable text menu focus handoff | Selection-toolbar retirement closed the new popup when it took focus; admit that single handoff only for the presenter's actual popup route and unchanged editing revision | Real Linux/Fluent popup Copy and keyboard Escape, unfocused editor, delayed-clipboard/newer-focus regressions; gallery asserts visible Cut |
| WorkbenchView presented destination | Welcome/workbench navigation | Retained table leaked contextual chrome onto Welcome; both target strip and representation selector follow the presented destination | Rendering/semantics absence and same owner/session on return |
| Linux actionRow / BusyDataActionRow | Grouped shortcut row/badge | GTK generic button nodes omit string values; reuse the selector’s combined accessible name for command and binding, retaining the existing focus/activation node and excluding duplicate badge text | Binding in the semantic label, one accessible row, focus action, focused flag, one Enter activation; native AT-SPI name still requires desktop acceptance |
| Appearance restore/save/display | BusyMark supported-locale normalization | Regional persisted tags were not selectable; one normalization policy and safe selector label | Regional/script/unsupported tags, save acknowledgement and Appearance rendering |
| Reference component capture / BusyMarkMenuButton | Production menu trigger and Flutter fallback | Fixture omitted trigger focus ownership; wire its supplied FocusNode and explicitly reject the unavailable native channel. Both projects assert visible menu items before capture | Light/dark open-menu images and capture assertions, without reference production edits |

Portable evidence is produced by `tool/package_ui_comparison.py`. Its ZIP retains
every image, manifests and selected run receipts; its standalone HTML embeds all
image and manifest links. Missing dependencies and modified image hashes fail
packaging. Rendering remains supplemental to the unmodified native gates.
