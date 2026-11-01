# Workbench presentation contracts

The correction baseline is `6a95f85`. BusyMark is a read-only reference; capture
its current tracked working tree and any local sibling packages into an isolated
directory with `tool/capture_reference_gallery.py`. Its manifest records source,
dependency and font identities. Do not build or generate files in BusyMark.

## Structure and contextual controls

The ordinary hierarchy is the window header, document tabs, one contextual
toolbar, then working content. The existing header View menu selects Data or
Structure and shows the selected representation. The contextual identity starts
with that representation, followed by the captured source/object. Environment,
transaction/autocommit, read-only policy and session actions remain visible.
Structure's section selector, Refresh and Reveal share this toolbar. Execution
history belongs to result content; it is not a representation selector.
The table Data container owns its execution-history control. It supplies that
control to the grid's header slot when rows exist, and keeps it reachable above
messages, loading and resultless executions. Compact grids retain the same
control. Selecting history captures the table owner and never executes SQL.
At small allocations with enlarged text, the contextual area keeps identity on
one line and scrolls state/actions horizontally on the next, leaving working
content usable. Focus traversal reveals offscreen actions.

`SchemaOverview` virtualizes metadata rows without using result execution or
editing ownership. Name, type, nullable, default and identity/generated attributes
align in the Columns overview. Its bounded height leaves a separate scrollable
detail region for one selected item. Horizontal scrolling preserves native text
sizes at small allocations and enlarged text. `SchemaObjectDetails` also presents
directly opened children and exact definitions without another breadcrumb or an
empty toolbar. Detail values remain selectable and keyboard reachable.

Selection is a metadata identity scoped to its document and inspection section;
ordinal position and response order are not identity. Refresh preserves a matching
selection, and removal clears it with an explicit message. `DocumentViewState`
distinguishes both directions of a mutual dependency as separate captured edges;
the direction is part of that edge's identity. It
stores only these identities. The inspector still owns payloads, request generation,
cancellation, inspection-session checks, metadata revision admission and evidence
budgets. Choosing a row does not execute SQL, open a document or acquire a session.
Empty captured metadata strings remain empty. Missing, unknown, unsupported and
Yes/No values remain distinct, including index uniqueness and generated expressions.

## Document and source names

`document_presentation.dart` supplies names for headers, tabs, SQL editor labels,
search and console choices. An untitled query gets its number when adopted into
the workbench. Closing or reordering other documents never renumbers it. The number
travels through the existing bounded draft store; presentation persistence retains
the sequence. Saving changes the displayed filename through the same document and
controller. Recovery text, IDs and file publication remain unchanged.

Tabs separately paint a short scope/connection qualifier and an instance suffix.
Every qualifier that can elide has a separate visible differentiator, independent
of its character count or text scale. Full context remains in the
tooltip and accessible name, after the short title on a separate line. Native
acceptance's identity parser accounts for that boundary. Retained results use
their captured profile. SQL tabs instead identify the console's current or
prospective execution target, including its Production indicator, even while an
older result remains selected. Historical output keeps its original provenance.
Labels do not affect reuse, selection or session ownership.

Linux tabs use BusyMark's Material/InkWell focus and hover behavior, with its native
typography, surface and border roles. Fluent retains its own FocusBorder. Enter has
one activation owner; close, middle-click and context-menu actions retain the
captured document. Consequential badges remain outside the shortened title.

`connection_presentation.dart` assigns duplicate display qualifiers by source ID
for both manager drafts and Explorer. These qualifiers never rename profiles or
follow a document into Explorer. Duplication also makes absent protobuf TLS/SSH
defaults mutable before clearing the independent draft's credential/trust references.

## Connection form and result grid

General, SSH/SSL and Options remain the three approved pages. The manager uses the
dialog shell's available height as a bound and shrinks to its form/source content
when that content fits. One form viewport and a scrollbar handle smaller windows
and enlarged text without a fixed body-height ceiling. Immutable TCP
and authentication facts occupy compact contextual text. Name/Driver and editable
connection fields retain the shared grouped controls. At 1280×800 and ordinary text,
Name, Driver, Host, Port, User, Password, password storage and Database must all be
visible together. Test and completion actions remain reachable. The password-storage
option says OS secure storage; its labelled setting keeps the full meaning.

Controllers, drafts, composing ranges, validation reveal, focus restoration, test
state and Apply/Cancel/Save & connect semantics remain with their existing owners.
Shared Settings sizing is unchanged. Resize handles use the column separator at
rest and the shared focus role on hover, drag or focused selection. Their original
hit area, cursor, directional deltas and width bounds remain; row heights do not
stretch to fill empty space. Result counts/completeness and retained-data state
are consolidated, with full status available in the tooltip and existing details.

## Verification and handoff

Extend existing interaction tests and use `test/ui_correction_workflows_test.dart`
for the eight assembled production compositions. Its fixture follows the supplied
customers schema (`id`, `name`, `email`, `status`, `created_at`) and carries defaults,
positions, JDBC types and identity/generated metadata. Capture light/dark, tall,
small, 150%/200%, German and RTL layouts; inspect images before reviewing goldens.
`BUSYDATA_CORRECTION_GALLERY_OUTPUT` selects its ignored capture directory.

The comparison directory is `build/ui-correction-pass/current/`. Its gallery adds
the supplied original screenshots, the eight workflows and all Structure sections
to the existing full comparison inventory. Package the actual verification summary,
source/font manifests and receipts with `tool/package_ui_comparison.py`.

Run all normal gates in `development.md`, the native workbench/connection/Explorer
procedures for PostgreSQL, MySQL and MariaDB, accessibility/IME and the unchanged
release performance workload. Rebuild `lib/main_linux.dart` after any acceptance
entrypoint. A socket-denied Flutter CLI, missing native facility, stale backend or
failed runtime cannot be accepted through a widget runner or archived receipt.
Record exact failures and keep native acceptance open. Arabic glyph fallback is
still unresolved unless separately corrected and verified. No publication is part
of this pass.
