# Historical native Linux UI review at 5551a133

This review was recorded at BusyData `5551a13370eadf39ad1cf5044d6873a59226c460`
against read-only BusyMark `c269f6d345268373f70dae0e1ae889f92d117c7c`.
Both working trees were clean at that review. Its development host was Ubuntu 26.04.1 LTS;
Ubuntu 24.04 references in older acceptance material describe other environments.
Run-specific identities, commands, compiler diagnostics and captures belong in
`build/native-ui-review-20261026/`. This inventory preserves that source-specific
review; historical screenshots and findings do not certify a later integration.

## Integrated-source disposition

The integrated application pins official unmodified ReEditor 0.9.0 and HTTP/2
3.1.0. Its first-party `SqlEditorController`, `SqlSource` and `SqlEditorInput`
own admission, exact line endings, multiple selections, history and the public
delta input connection. `WorkbenchSqlEditor` and its public paragraph geometry
supply the view and completion adapters. R1 and R2 below describe the earlier
0.8.0 application, not a current missing implementation. The approved dependency
changes and remaining qualification requirements are described in
[editor dependency boundaries](editor_dependency_adapters.md).

Linux accessibility now projects the public Flutter semantics tree into owned
GTK/ATK objects. Its owned binding preserves the complete public tree and
actions while preventing a duplicate stock native projection. No upstream
class, interface or runtime function is replaced. The original branch's
stock-engine-only description must not replace the integrated
[architecture](architecture.md) or [accessibility contract](native_accessibility_bridge.md).

The appearance integration carries R4's deduplicated effective-brightness
synchronization and R5's bootstrap decoration fallback alongside the existing
guarded header-close and OS-exit paths. R3's relative package-URI correction
belongs with the current source/font manifest and its first-party editor hashes.
Reference gallery preparation does not certify a reference build: independent
official-source verification of the reference's hosted and native dependencies
is still required before it can execute. Neither this source reconciliation nor
the historical review closes a current rendering or native acceptance gate.

## Findings established at the review baseline

| ID | Priority at baseline | Files | Historical finding and disposition |
| --- | --- | --- | --- |
| R1 | P0 / release blocker | `pubspec.yaml`, `tool/diagnostics/re_editor_compatibility.dart` | Official pinned ReEditor 0.8.0 failed compilation on official Flutter 3.47.5/Dart 3.13.4: `_CodeInputController` did not implement `TextInputClient.onFocusReceived`. The standalone fixture imported no BusyData code and reproduced this. The integrated 0.9.0 pin supplies the publisher's compatibility fix; upstream source remains unmodified. |
| R2 | P0 / application compatibility | `features/workspace/documents.dart`, `features/workspace/workbench_model.dart`, `ui/common/workbench_completion.dart`, editor/menu/scroll callers | The baseline still consumed APIs formerly supplied by its removed ReEditor fork, including `beforeChange`, `onChangeRejected`, `secondarySelections`, `ending`, `trailingEnding` and completion refresh hooks. Restoring official packages alone did not port these consumers. Removing these calls would lose byte admission, line endings, multiple carets and completion ownership. The integrated first-party source, input and view adapters now own those contracts; their qualification remains separate from the upstream compilation fix. |
| R3 | P1 / verification tooling | `tool/capture_reference_gallery.py` | `--prepare-only` crashes with `UnboundLocalError` for `unquote`: a function-local import shadows the module import before first use. Correct the import and exercise source/font manifest preparation, including relative package URIs. |
| R4 | P2 / native appearance | `app/linux/linux_window_host.dart`, `platform/gtk_font_service.dart` | The active app never calls the existing `GtkThemeService.setPreferDark`. Flutter changes appearance while GTK selectors/menu controls can retain the other variant. BusyMark synchronizes effective brightness at the host. Restore that narrowly scoped call, deduplicated by effective brightness. |
| R5 | P2 / first-frame header allocation | `app/linux/linux_window_host.dart`, `platform/gtk_window_preferences_service.dart` | The host ignores bootstrap preferences while the stream is loading. GTK layouts with controls on the left initially allocate the default right-side controls. Use the already loaded initial provider until stream data arrives, as BusyMark does. |
| R6 | P2 / documentation accuracy | `docs/architecture.md`, `docs/development.md` | The baseline architecture still described the removed native tree-interface replacement as active, and development documented only the upstream compiler failure. Its historical correction described the original branch after removal; the integrated owned provider and editor require their current architecture and adapter documentation. |

These were pre-existing findings in the review baseline. No database command, storage format, editor
owner, result identity or backend protocol change is required for R3–R6.

## Baseline file-by-file presentation inventory

The baseline Linux route was `main_linux.startLinux` → `LinuxBusyDataApp` →
`LinuxWindowHost` → `WorkbenchView(LinuxControls)` → `LinuxWorkbenchFrame` →
`LinuxPageFrame`. Windows retains `WindowsBusyDataApp`, `FluentApp.router`,
`NavigationView` and `WindowsControls`. Source inspection establishes the following
implementation facts for that baseline; blocked runtime/gallery checks must not be read as passed.

| BusyData files (under `lib/src/` unless stated) | Baseline reference / review disposition |
| --- | --- |
| `app/app_theme.dart`, `app/busydata_yaru_theme.dart`, `app/busydata_surface_colors.dart` | BusyMark `app_theme.dart` and semantic neutral roles: Yaru geometry/typography, restrained neutral selections, floating surfaces, accent foreground, disabled roles, and opaque elevation ladder are already present. Explicit high contrast is an accessibility extension; do not replace it with ordinary reference colors. |
| `app/busydata_design.dart` | BusyMark grouped lists, native shadow layers, entries, selectors, ComboRows, switches, checkboxes, buttons, sidebar records and dialog scaffolds are already ported. Material/InkWell use is deliberate. No wholesale component replacement is warranted. |
| `app/common/busydata_design_values.dart`, `app/common/busydata_motion_widgets.dart`, `app/busydata_motion_widgets.dart` | Existing spacing, retained crossfades, reduced motion and full-width reveal retain their elements. Functional viewport/window dimensions are not generic spacing defects. |
| `app/busydata_glyphs.dart`, `ui/linux/linux_database_icon.dart` | Directional navigation and database-specific glyphs remain distinct. Material icon identifiers in native-menu mapping are identity mappings, not evidence of a rendered fallback. |
| `ui/common/desktop_appearance.dart`, `ui/common/desktop_controls.dart`, `ui/linux/linux_appearance.dart`, `ui/linux/linux_controls.dart`, `ui/windows/windows_controls.dart` | Semantic adapter boundary remains intact. SQL technical fonts, grid state colors and metric-based row/control heights are deliberate; ordinary controls inherit role typography. No Linux imports belong in shared database views. |
| `app/linux/linux_busydata_app.dart`, `app/linux/linux_window_host.dart` | Existing theme, locale, live GTK accent, animation policy and guarded application closure; R4/R5 correct native synchronization and startup allocation. |
| `app/linux/linux_header_style.dart`, `app/linux/linux_page_frame.dart`, `ui/linux/linux_workbench_frame.dart` | Title allocation uses actual physical control obstructions, retained full-gap search, branded sidebar, native gestures and compact search overlay. Sidebar resize is an intentional database-workbench addition. Keep mounted bodies and focus ownership. |
| `ui/common/workbench_view.dart`, `workspace_content_layout.dart`, `workspace_divider.dart` | Retained Welcome/workbench/Settings destinations; contextual controls gated by destination; measured editor/results split. Grids intentionally use full width instead of BusyMark's prose clamp. |
| `ui/common/workbench_actions.dart`, `workbench_shortcut_scope.dart`, `modal_command_boundary.dart` | Existing command registry, captured contexts, eligibility and local/modal shortcut boundaries remain authoritative. Linux application menu and Windows Fluent menu keep independent presentation. |
| `ui/common/connection_form.dart`, `authentication_form.dart`, `connection_presentation.dart` | General/SSH–SSL/Options, compact grouped fields, bounded scrolling, independent source drafts, Test/Apply/Cancel/Save & connect and secure-storage/trust review remain present. No redesign of this already corrected form is justified. |
| `ui/common/database_explorer.dart` | Lazy virtualized rows, stable trailing menu slot, semantic object identities, directional disclosure, source/namespace ownership, filtered/revealed metadata and captured context actions remain present. Native tree roles require actual AT-SPI acceptance. |
| `ui/common/workbench_document_view.dart`, `workbench_tabs.dart`, `document_presentation.dart` | Shared contextual chrome, creation-assigned names, qualifiers/tooltips, leading dirty indicators, neutral tab state and captured close actions already existed. R1/R2 blocked runtime tab/document qualification at this baseline; the integrated implementation is described above. |
| `ui/common/workbench_completion.dart`, `workbench_editor_menu.dart`, `workbench_editor_scroll.dart`, `editor_shortcuts.dart`, `sql_presentation.dart` | Bounded themed completion, native text menus, effective shortcuts and retained SQL controllers were present; R2 blocked the baseline official-editor integration. The integrated first-party adapters preserve these purposes. Do not substitute plain text fields or remove safety hooks. |
| `ui/common/result_grid.dart` | `TableView.builder`, bounded windows/cache, retained source indices, column resize, selected-cell semantics, reviewed mutations and exact-value distinctions remain intact. Ordinary `DataTable` is not a replacement. |
| `ui/common/result_presentations.dart`, `result_value_editor.dart`, `result_staged_insert.dart`, `result_display_format_dialog.dart`, `result_presentation_target.dart` | Newer Table/Transpose/Tree/Text/Record and typed-value surfaces use the same platform adapters and retained result/edit owners. Pagination/complete acquisition and explicit staging remain domain requirements. Their native acceptance cannot be inferred from older galleries. |
| `ui/common/result_extractors.dart`, `result_operations.dart`, `result_operation_messages.dart`, `paged_selectable_text.dart`, `exact_text_clipboard.dart`, `bounded_text_controller.dart` | Exact values, LTR technical evidence, bounded selectable pages and clipboard/admission failures are functional presentation constraints. |
| `ui/common/schema_tools_view.dart`, `object_designer.dart`, `structure_presentation.dart`, `plan_view.dart`, `er_diagram_export.dart` | Shared grouped properties/toolbars and selectable DDL, virtualized Structure metadata, direction-aware plans and reviewed modification; diagram geometry/export typography are intentional canvas measurements. |
| `ui/common/workbench_search.dart`, `workbench_search_session.dart`, `workbench_sql_search.dart`, `history_view.dart`, `snippet_view.dart` | One captured global search session, separate local searches, revision-bound SQL replacement, refreshed history pagination, explicit reopen without execution, retained snippet editor and keyboard ownership are already implemented. |
| `ui/common/workbench_settings.dart`, `workbench_shortcut_capture.dart`, `sql_language_settings.dart`, `metadata_settings_dialog.dart` | Reference sidebar/grouped preferences, compact category selector, immediate acknowledged appearance/shortcut writes, staged execution/recovery/language changes and guarded departure. No second Save mechanism should be added. |
| `ui/common/sql_diagnostics.dart`, `sql_parameter_information.dart` | Diagnostic actions and overload popovers use platform controls and captured editor analysis. These newer surfaces need current runtime coverage rather than historical acceptance. |
| `ui/common/transfer_document.dart`, `privileges_view.dart`, `activity_view.dart`, `capabilities_view.dart` | Shared forms, selectable properties, progress and error states retain review/cancellation/authentication and captured request ownership. |
| `ui/common/workbench_document_view.dart` jobs/problems/recovery/comparison/changes/output routes, `workbench_close.dart`, `workbench_presentation.dart` | Durable warning/error/unknown evidence, exact read-only code, property rows, reviewed mutations and close/recovery policy remain deliberate workbench differences from BusyMark's document editor. |
| `app/busydata_dialogs.dart`, `app/busydata_dialog_identity.dart`, `app/busydata_window_close.dart`, native-menu service/runner | BusyMark-derived dialog visuals surround BusyData's accepted-pop focus restoration, newer-focus protection, native menu release retirement and database-safe close coordinator. These stronger ownership rules must remain. |
| `tool/capture_reference_gallery.py`, `tool/build_ui_comparison_gallery.py`, `tool/package_ui_comparison.py`, existing gallery/workflow tests | Current source-bound rendering infrastructure includes the R3 correction; verify official reference dependencies and the current source/font manifest before recapture. An incomplete gallery must not be packaged as the complete requested comparison. |

Direct colors in shared views are principally transparent state layers; palette
colors live in the theme/adapter. Repeated small paddings align to existing roles.
Grid/graph geometry, exact-value editors and native control clearances are
functional measurements, not candidates for blanket literal replacement.
No additional P0/P1/P2 rendering claim can be closed without current rendering.
Minor differences such as tooltip timing are P3 and should be assessed in the
real desktop before changing shared Windows behavior.

## Historical dependency evidence and current release limits

Commit `d08f9cb` removed the local `fluent_ui`, `re_editor`, `http2` and
`yaru_window` forks and native runtime interface replacement. The remaining
version overrides in the review resolved official hosted packages, not local source patches.
That review recorded publisher-file/SDK integrity verification of four restored
packages and 1,171 SDK files. Those counts describe its evidence, not a later
source or dependency graph. Do not restore removed patches to obtain screenshots.
The publisher records a Flutter compilation correction in
[ReEditor 0.9.0's changelog](https://pub.dev/packages/re_editor/changelog#090);
that is upstream evidence for the subsequently approved 0.9.0 compatibility pin,
not proof of the application's text, input or editing contracts. The first-party
adapter documentation describes their separate ownership and required checks.

Each required Linux/X11/Wayland, real-font/menu/clipboard/IME/AT-SPI,
three-engine database, release-performance and genuine Windows/MSIX gate must
execute successfully against the final integrated source with official
dependencies. Installed strict-Snap and current reference-gallery qualification
also remain required where declared. Partial or historical successes do not
close the complete release gate. No stale executable, source guard or widget
fixture may substitute for missing native acceptance.
