# Workbench usage

Database Explorer occupies the native left working surface. The center contains
SQL, table/structure, retained-result, comparison, plan, diagram, administration,
and transfer documents. On Linux, the header's main menu contains File, Edit,
View, Connection, Object and Run commands. Actions search opens in the shared
header and sidebar; Escape restores the current editor and Explorer. Optional Jobs, History and
retained-result browsing open in the lower working allocation; closing them
restores the current document output. The first SQL document is editable and
saveable while disconnected. Welcome groups New connection and New query under
Create and Open SQL file under Open. New connection remains available when saved
sources exist; those sources stay in Explorer.

## Connections and Explorer

Choose **New connection** to open **Data Sources and Drivers**. Select a saved
source or add a draft in its source list; each keeps independent values in
**General**, **Options** and **SSH/SSL**. General selects a bundled driver, TCP
host/port, User & Password authentication and database. The generated JDBC URL
is read-only and copyable; MariaDB's initial database is separate from that URL.
Only the three bundled drivers and TCP are supported, without arbitrary driver
loading, raw URL overrides or socket routes. Options exposes the supported
connection settings and timeout units.

**Test Connection** tests the complete selected database connection without
saving or connecting Explorer. Cancellation/errors preserve the fields. Success
reports the actual server/version, endpoint and observed TLS state. **Apply**
saves changed sources and pending deletions without connecting. **Cancel** discards
changes since the last acknowledged Apply; it cannot undo acknowledged saves or
deletions. **Save & connect** applies and completes the original connection action,
whose frozen destination is named above the actions. Selecting another source
does not retarget completion. Removing
the last source leaves an empty manager with Add available, without a replacement
draft. Removing the captured destination cancels that action.

Global creation through Explorer or the Connection menu loads that source in
Explorer and opens a separate blank bound SQL console without running SQL.
Creation through a query's target selector connects only that captured query,
preserving its text and other documents. Editing through an existing SQL context
and Save & connect replaces that query's session when allowed, retaining SQL/prior output;
it does not replay SQL or change other sessions. Saving configuration alone does
not mutate existing physical sessions. Transaction/job/edit safeguards still apply.

Fresh sources use **Driver default**: PostgreSQL `prefer`, MySQL `PREFERRED`,
MariaDB `disable`. These policies can permit unencrypted connections and do not
universally verify certificates/hostnames. Enabling **Use SSL** initially chooses
**Require**, which requires encryption without certificate/hostname checks.
**Verify CA** checks the certificate chain; **Full Verification** also checks the
database hostname; clearing Use SSL explicitly selects **Disabled**. Re-enabling
retains the chosen mode in the draft. An observed TLS cipher proves encryption
only. Select CA, Java/System public roots and client certificate/key files
explicitly; an encrypted JDBC key has a separate password/storage choice. See
[security.md](security.md) for exact mappings and native-transfer restrictions.

SSH settings precede SSL and open a profile-owned editor. Its separate test
authenticates only SSH: it opens no JDBC session or database forwarding and does
not require valid General/database fields. The main Test Connection still tests
the complete database connection. Host-key review binds the endpoint, algorithm
and fingerprint; changed keys require explicit replacement review. Agent selection
names a socket and SHA256 identity; forwarding uses a dynamic local port.
Password storage is **Never** or explicit OS credential storage when available,
with session-only fallback and no app-lifetime cache. Native file pickers select
certificates, keys and known-hosts files.

The Database panel lists saved sources, including disconnected sources. Its New
menu opens connection, console and supported object creation for the selected
scope. The compact toolbar moves additional actions into More at narrow widths.
At larger text sizes, namespace selectors can use a second line to keep their
counts readable.
Favorites remain marked. New → New source folder creates local folders; a slash
creates nested folders. Folder/source menus move items to another folder or the
top level and move them up/down. Rename preserves source IDs. Remove only accepts
empty folders; move their contents first. These actions never delete a server
database. Existing connection-group labels migrate to folders once.
Single-click selects; Enter or double-click opens table/view data or an
object's structure. Namespace and category rows expand instead.
Opening Columns, Indexes or Definition does not fetch table rows.
New Query captures the selected source settings and exact database/schema scope.
If saved endpoint or safety settings differ from the connection that loaded the
tree, reconnect that source first. Display renames preserve the binding.
**Deactivate source** reviews every live physical session bound to that saved
source, including independent consoles and table documents. Resolve active jobs,
transactions, uncertain outcomes and staged edits first. Acknowledged disconnects
preserve saved profiles, SQL drafts and retained output. The Session menu's
Disconnect continues to address one physical session and its clients.

The **N of M** badge selects databases and schemas for introspection. Names,
All, Default and a bounded regular-expression rule persist by source ID and
database. In All mode, unchecking a name excludes only that namespace, including
when other names are on later pages. Pending selections survive page navigation;
Apply validates them and immediately exposes accepted names. Cancel preserves the
previous rule. This selection never changes a console's execution context. PostgreSQL
has separate database and schema levels; MySQL/MariaDB databases are schemas.
View options exposes nonselected discovered namespaces and empty groups. Expanding
a nonselected namespace explains its state without introspecting its objects.
It also controls namespace/object/element grouping, alphabetic sorting, virtual
objects, available comments and visible object types. Functions and procedures can have separate groups on PostgreSQL, MySQL and
MariaDB, each with its own scoped count and paging.
Turning off element grouping shows columns directly beneath tables. A paged group keeps its
navigation row so later pages remain accessible. Filters, expansion references
and view preferences restore disconnected; they never restore live sessions.

Type with the tree focused, or press Ctrl+F, for transient **Speed Search**.
It matches expanded, loaded rows; arrows cycle, Enter activates and Escape clears
it. The optional speed filter uses the same scope and never searches the server.
**Filter connections and objects** is a separate View options choice for loaded
names. **Search database objects** uses bounded server metadata pages in the
selected database/schema scope. The tree replaces displayed pages and offers
Previous page, keeping later objects reachable within its node budget.
Loading, unavailable, denied, stale and failed metadata are distinct from empty
metadata. Refresh and additional pages are explicit.
Search results reveal the exact object in the tree. Table/structure documents
also offer **Reveal in Database Explorer** (Alt+Shift+B). Reveal leaves namespace
selection unchanged and explains hidden/unselected targets. For an unloaded
object it can narrow a branch through bounded metadata lookup; **Clear object
lookup** restores the full group. Its narrowed page omits a full-group total.
Reveal checks the document's original connection against the Explorer's source.
If a saved source now points to another server, it reports the changed target
instead of revealing a same-named object there. Tooltips expose the endpoint.
In a connected SQL console, place the caret on a real table/view reference or its
alias and use the same Reveal action, or Ctrl+B for Go to DDL. Resolution uses the
console's physical database/search path, keeps quoted native identities, and
ignores strings/comments. Uncertain matches require an explicit qualified choice.
CTEs, derived queries and unsupported references report unavailable rather than
guessing a persistent object.

**Open definition** in an object's Explorer menu opens a read-only definition
document for its qualified target. It is separate from **Open SQL**, which
generates browse SQL. Native definitions and generated partial PostgreSQL
definitions identify their provenance; generated SQL comments describe omissions.

Ctrl-click two ordinary tables with the same native name/schema on the same
engine, then choose **Compare structure**. BusyData captures just those tables
from their exact databases and opens the existing structural diff/review. Other
object types and rename matching are unavailable in this scoped action. Opening
generated migration SQL creates a source/database/schema-bound console; viewing
a diff never executes its SQL.

Schema/database context menus also retain Save snapshot, Compare schemas, and
ER diagram for the selected namespace. These tools require a supported live
connection scope; unavailable targets show the required connection context.

New → **New virtual view** on a namespace stores a locally named SQL definition.
The separate Virtual views group lists these definitions; they are not server
views and cannot be queried by their local names. Open SQL opens an independent
source-bound console. Double-click, Enter and Run use the normal connection consent, SQL risk review,
Jobs, cancellation and document-owned results, including production/read-only
rules. Rename virtual view changes only its local name. Edit local definition
updates its saved SQL. Changed definitions or source connection/safety settings open fresh
consoles while earlier console text/results remain intact. Removing a definition
does not close its consoles or send DROP VIEW. Restore, reconnect, expansion and
metadata refresh never run its SQL. A deleted source leaves an unbound definition;
select a real replacement namespace and use **Rebind local definition here**.
Actions captured before a definition, binding or connection setting changes
expire; invoke the action again on the current row. A source display rename
preserves the binding.
Definition inspection does not execute DDL or authorize a schema change.
Ctrl+B opens the selected object's definition, F4 opens supported data, and
Ctrl+Q opens bounded Quick Documentation from known metadata. These shortcuts
respect tree focus. Ctrl+Shift+F10 lists consoles bound to the selected source;
choosing an existing console retains its text, output and transaction.
After an acknowledged connection or reviewed disconnect, the console keeps its
acknowledged database/schema for the chooser and its next explicit connection.
A restored draft keeps this scope while remaining disconnected.
Unsaved console names match their numbered tabs. Saved consoles with the same
filename include their paths so each choice remains distinguishable.

Connection rows distinguish **Explorer connected/disconnected** from the count
of physical query sessions. A disconnected Explorer can coexist with an open
query session. Overloaded routines display their native signatures and open the
corresponding definition; composite indexes and foreign keys occupy one tree row
with their ordered columns available in Structure.

Explorer inspection and SQL consoles own different sessions. New SQL carries a
profile reference and acquires its own physical session at the first explicit
operation. **Share physical session** is an advanced choice naming its clients;
transactions and temporary/session state are shared. Closing one client leaves
remaining clients connected. The eight-owned-session capacity includes uncertain
handles; resolve or disconnect existing handles before acquiring more. A failed
replacement preserves the old association.

**New SQL** from an Explorer category carries that category's source, database
and schema into the new console. The existing document keeps its SQL, results
and session. A PostgreSQL console with a database scope opens a separate physical
connection to that database on first use; it does not switch another console's
database or change the saved source configuration.

## SQL and retained output

Ctrl+Enter runs the selection when present, otherwise the current statement.
Ctrl+Shift+Enter explicitly runs the script. Explain uses the same selected/current
statement boundary; Explain analyze executes and requires the normal review.
Java determines dialect boundaries. **Execution options** controls that document's
row limit, streaming read and script error policy. Settings controls defaults.
The target row identifies environment, live catalog/schema, session, transaction
and read-only policy. Session details distinguish saved profile values from live
state. BusyData's read-only policy does not prove server-level permissions.

Close or Escape in the search fields returns to the initiating editor/control.
Actions search keeps its selected command visible as labels wrap or text scales.
The editor retains search/replace, completion at the caret, folding, clipboard,
IME, multiple carets, comments, formatting and bounded undo. Formatting applies a
captured, revision-checked response in one undo step. File saves preserve captured
content, revisions, atomic output and ordinary SQL-file confinement.

Each execution owns result-set tabs, Messages and retained evidence. The output
menu selects previous executions without running SQL. Background completion does
not select another document or override a historical selection. Update/DDL
messages show affected counts rather than an empty invented grid. Historical
results display their original target even after reconnect or disconnect.
At short heights, the selected output menu combines result sets, Messages, Plan
and execution history. The original environment and target stay beside it.

The grid keeps pinned headers/row selection, bounded paging, resizing, column
visibility, rectangular selection, keyboard traversal and copy/value inspection.
NULL, empty text, exact numbers, binary and truncated/large values are distinct.
The Grid menu exposes Filter, Sort, Columns, Refresh, editing and export. On SQL
output these operations build a Java-owned disk-backed view of a fixed fetched-row
snapshot; no SQL is rerun. Ordering uses retained values rather than database
collation. On a table Data document, deliberate Filter, Sort or Refresh submits a
reviewed query with verified identifiers and bound values. Pending edits must be
resolved before replacing the table snapshot.
At the minimum size with large text, More in the pinned row header keeps grid
actions available while leaving room for data. View details shows the original
target, fetched rows, completion/limit state, elapsed time and filter/sort scope.
Clicking a cell immediately selects and focuses it for keyboard traversal.
Open Actions search updates enabled states and explanations when its
captured owner's acknowledgement or session state changes; its filter, selected
command and keyboard focus remain in place. Another tab is never substituted.

## Changes and transactions

The grid's Changes control opens the review for that result's pending batch.
Export retained data is available beside the grid controls at ordinary widths;
the Data grid menu keeps it available at constrained widths and larger text.
These controls retain their original result and document when another tab changes.

Double-click or F2 edits an eligible cell; Enter stages and Escape cancels the
local edit. Unsupported/read-only values open inspection. The backend assesses
provenance and row identity. Repeated edits coalesce by original retained row;
reverting the exact value removes the intention. Set NULL, a typed empty string,
and omitted/default insertion columns have different meanings. Pending cells and
deletions are marked. Each result/document owns its independent bounded batch.

**Apply and commit** opens a structured review of original/proposed values,
parameterized SQL, target and risks. It starts and commits a backend-owned batch
transaction. The source console must be idle with auto-commit enabled. Resolve a
manual SQL transaction separately with Commit or Rollback; application does not
silently change it. Conflicts/failures preserve intentions. Unknown outcomes may
have committed and prohibit replay. Successful application leaves the old grid as
a pre-change snapshot; Refresh is explicit and does not invent defaults/triggers.

Recovery is a dedicated review document. Opening it never connects, executes
source SQL, resumes a transaction or reapplies a batch. Rebinding verified rows
requires an explicitly connected SQL owner and a fresh preview. Committed/unknown
records prohibit replay. Disabling private recovery explicitly deletes saved
recovery records; portable workspaces never contain credentials, live handles,
retained rows or mutation approvals.

## Object, schema and professional tools

Table Data and Structure are primary subviews. Structure exposes supported
columns, indexes, constraints, foreign keys, triggers, native definition and
captured dependencies. Views/routines show available definition/metadata without
claiming base-table editability. Unsupported inspection remains identifiable.
Object designer fields and ordered metadata-backed selections generate SQL for
review; changing fields does not execute. Opening generated SQL creates an
ordinary unsaved document with a profile reference and an independent session.
Unsaved designer fields survive tab changes and, when private draft recovery is
enabled, application restarts within the shared recovery budget. Recovered
designs require explicit connection and fresh metadata before generating SQL.
Saving generated SQL uses the ordinary SQL document save workflow.

At large text sizes, Structure controls and properties share a scrollable view.
Compact targets keep the environment visible; More opens the full target details.
Scrolling properties does not refresh metadata or execute SQL. Structure and
import mappings acquire all supported columns within their existing budgets,
including columns beyond the first metadata page. Direct child inspection uses an
exact scoped lookup. Incomplete metadata requires Retry rather than presenting a
partial list as complete; generated or unknown target fields cannot be mapped.

Structure presents JDBC flags as Yes, No or Unknown and identifies index
uniqueness explicitly. Positions, referenced columns and data types have readable
labels. SQL expressions and native type names remain exact; an unknown metadata
flag does not imply a permission or editability guarantee.

Save schema snapshots from the appropriate connection/schema menu. The comparison
document accepts saved snapshots or explicit captures for **Current schema (to be
changed)** and **Desired schema**, with a separate **Apply to** connection. Comparison
requires the same engine and schema name. New files use format 2; compatible
format-1 files are validated and converted in memory, preserving the original
file. Contradictory or incomplete legacy evidence is reported explicitly. The central review
shows changed objects, before/after evidence, dependencies, risks and unsupported
differences. SQL remains one dependency-ordered batch; object selection is for
inspection. Save SQL does not apply it. Open SQL binds the explicit Apply to
profile for ordinary reviewed execution. No automatic migration application or
cross-engine/schema-renaming support is provided. Recheck current schema drift
before executing saved migration SQL. MySQL/MariaDB DDL may implicitly commit.
If different exact foreign-key names share the server's DROP lookup key, BusyData
refuses the ambiguous generated operation. A selected constraint retains its
native type as well as its name. [Schema artifacts](schema_artifacts.md) describes
file validation and import behavior.

Plan documents reuse retained evidence without rerunning it and expose raw output
and bounded operator navigation. Diagrams use captured foreign keys, deterministic
layout, keyboard navigation, notes and SVG/PNG exports within existing budgets.
Resizing preserves the diagram's world center and zoom. At constrained sizes,
More exposes relationships, notes and export while keeping the canvas usable.
Connection administration contains Sessions and Locks, capabilities, diagnostics,
and Users and roles. Activity cancellation/termination binds a selected fingerprint
and revalidates races. Principal/host semantics remain engine-specific. Password
operations use private typed requests and redacted history/reviews, never SQL
containing passwords. Refresh is explicit.

Import documents contain Source, a real bounded preview, metadata-backed Mapping,
Review and progress. Encoding, delimiter, quote-aware NULL semantics, source hash
and all-or-nothing/batched/skip-invalid policies remain explicit.
CSV/JSON source checking can take up to five minutes for files within the 8GiB
limit; **Request cancellation** is available while preview, review or start is
pending. A cancelled start or a changed source requires another review and is
never retried automatically. Batch policies
can preserve earlier commits after cancellation/failure. Acknowledged/rejected
counts come from the job. **Export retained data** exports fetched source/view
scope after disconnect; **Run SQL export** is a distinct reviewed execution.
Full-value export stays bound to its retained value. Output identity, overwrite,
no-clobber, cleanup and published-but-unconfirmed outcomes remain protected.
PostgreSQL arrays export with their original native text, including dimension
bounds. JSON and NDJSON contain that text as a string. An array retained only in
binary form remains inspectable in Tree, but exact text and SQL copying are
unavailable; run an explicitly reviewed textual projection if text is needed.
Backup/restore documents identify the compatible selected tool, file, progress,
logs, cancellation and outcome. Restore cancellation cannot undo partial commits.
Restore invalidates cached structure and retained editability evidence before it
starts. Metadata reconciles after an acknowledged restore without committing or
rolling back the console transaction. An unknown or cancelled restore leaves
metadata stale until explicit refresh; inspecting retained results does not rerun
their SQL or authorize applying an old edit draft.


Native backup/restore through SSH preserves the selected TLS policy and original
database hostname. Required TLS failures stop the operation; BusyData does not
retry with weaker verification. PostgreSQL uses its supported hostname/address
configuration; MySQL/MariaDB use BusyData's private transport relay. Genuine
Windows execution and installed-package acceptance require their separate gates.
See the [native transport requirements](native_transport_acceptance.md).

History defaults to withholding SQL text. Reopen creates a document and never
executes it. Settings contains Execution, Private recovery and Keyboard shortcuts.
SQL snippets remains a separate command. Local
presentation remembers Explorer width, visibility and document split/row limits; safe object
hints reopen disconnected in Structure and never fetch live data automatically.

Ctrl+S saves SQL, Ctrl+T creates SQL, Ctrl+W uses the shared close policy, Ctrl+F
focuses Find text, Ctrl+H focuses replacement, Ctrl+/ comments, Ctrl+Shift+P opens Actions search,
Ctrl+Shift+O searches database objects, Alt+1 reveals and focuses Explorer, and F6/Shift+F6
traverses panes. Dialogs isolate shortcuts and restore focus. Tab pointer,
middle-click, menu and keyboard close use the same policy. Closing a view,
disposing retained data, cancelling a job and disconnecting a session are distinct.
Outcome unknown remains visible in session/tab/status state and forbids further
SQL or automatic replay. Messages and Owned sessions explain that the operation
may have completed and must be reconciled before starting new work.
See [development.md](development.md) for required verification and unaccepted
platform/security coverage, and [database_support_matrix.md](database_support_matrix.md)
for supported test targets and limits.

Explain output has an attached Plan surface with the original SQL and schema. Open plan document keeps that same retained evidence available independently. Inspecting either surface does not execute SQL or acquire a session. Ordinary query rows do not advertise a plan. Jobs includes each operation’s original target, environment and type even when another document is active.

At constrained heights, the Plan menu opens its details and original SQL while keeping operator navigation visible. Generated SQL retains the connection configuration used to inspect the object. If that saved configuration changes, explicitly choose the intended target before connecting; already connected documents continue to use their original sessions.

Change review lists the complete batch and lets you inspect one operation’s Original and Proposed values. Generated SQL shows the complete parameterized batch. The More menu contains full review details and Revert; reverting invalidates the approval. Apply and commit remains separate from manual transaction controls. Activity filtering searches the current fetched catalog and does not refresh the database; actions are disabled when their selected row is hidden.

The comparison’s Apply to connection must use the snapshots’ engine. A different-engine target disables Open SQL; Save SQL remains available. Choosing Apply to selects a target for the generated query and never opens a session or applies a migration.

After Apply and commit, the grid remains an immutable pre-change snapshot. Refresh explicitly before staging another change. Recovery discard must be acknowledged before its document can close. Editing a saved connection does not retarget historical results; their data remains inspectable and exportable after that profile is removed. Objects from different connection configurations retain separate documents even when their saved profile ID and object names match. After a session replacement, refresh Structure explicitly to inspect its new metadata.

For a foreign key in another schema or database, enter its exact name and choose Inspect structure beside Referenced schema / database. Then choose the referenced table and its columns in matching order. Typing does not fetch metadata. A changed schema, design, session, or closed document invalidates a late inspection or generated review; inspect or generate again. Database permissions and engine restrictions still apply.

History opens in the optional global tool area and keeps its fetched page, selection, filter and scroll when switching documents. Search opens a native dialog at constrained heights; More contains history actions and privacy/retention settings. Reopening an entry creates an unsaved, disconnected SQL document and hides the history tool. It never executes SQL, adopts a session or closes the application route.

Jobs and Problems are available from View, Actions search and the status bar. Problems shows failed, interrupted and unknown-outcome jobs with their original targets and messages. Closing either tool restores the selected document's output. Owned sessions includes unattached uncertain sessions and shows unknown outcomes, failed transactions and open transactions before idle sessions. Disconnect confirmation names the physical session and its clients; disconnect affects every client, never commits or replays SQL, and does not resolve an unknown outcome. Saved connections can be duplicated or deleted from their Explorer menus; existing sessions retain their original settings.

Tab state labels remain separate from truncated document titles. Close reviews name their original connection and session, show pending work and explain recovery and cleanup. Closing an object design discards its unsaved fields after review; generate and save SQL first to retain it. Application recovery can retain open designs when enabled. In History privacy, Enable SQL history explains the retention period and possible secrets in SQL; Stop SQL retention removes previously retained SQL text.

At constrained heights or 200% text, Plan → SQL provenance inspects the captured SQL and original target without rerunning it. Retained data remains a separate Plan menu action. Explorer menus distinguish source management, namespace/category creation scopes and real object data/definition actions. Schema snapshots, comparison and diagrams remain explicit workbench tools.

Settings opens in the Linux window with Back navigation and grouped categories.
Changes remain staged until Save. Each shortcut row opens an assignment recorder;
conflicts and invalid row limits identify the affected field. Ctrl/Shift/Alt order
is normalized; F6 and Shift+F6 remain reserved for pane traversal. Keeping the
existing recovery privacy setting preserves private records. Disabling recovery
requires acknowledged cleanup and is refused while an apply is in progress or
has an unknown outcome. Save failures keep Settings open with the previous
persisted values. Back or Close returns to the same workbench and controllers.

Share an existing session (advanced) reviews the named physical session, its environment, transaction and clients. The initiating document and chosen session are revalidated after review; another active tab does not change ownership.

Recovery opens private intentions without connecting, executing source SQL or replaying changes. Discard reviews the original target and exact recorded state, then revalidates that record before deleting it. Unknown outcomes may be explicitly discarded as metadata, but never retried. Applying, changed or restarted records require a fresh review. Explorer connection badges link to all owned sessions with open, failed or unknown transactions.

In a diagram, Search table and Focus expose readable foreign-key columns and their referenced schema/table/column. Export SVG/PNG and notes are explicit actions; they capture the current evidence before native destination review.

Diagram Focus centers the selected table and exposes its relationships. With the diagram canvas focused, arrow keys pan, +/− zoom and Home resets the view. The diagram View menu exposes the same zoom/reset actions and bindings. These keys do not affect a text field or SQL editor.

At constrained heights with large text, application commands move to More beside
the document tabs. Tab titles shorten to leave status badges readable. Unusually
wide Outcome unknown labels wrap when needed. Grid rows grow
with native font metrics; View details exposes captured target, fetched count,
execution and filter/sort scope when the compact grid hides its summary. Resizing
keeps the editor, grid selection and keyboard focus in place.
Explorer arrow-key navigation scrolls the focused row into view, including lazy
rows at large text sizes. Selection does not load new metadata or execute SQL.


## Metadata, SQL language and result presentations

Open **Connection → Metadata and introspection** for the captured live source.
Choose names, structure, or structure and source, configure exact namespaces and
object filters, and save the policy. Names alone do not provide complete columns
or relationships. Full refresh rebuilds configured scopes; incremental refresh
scans native fingerprints and retrieves changed details. Status pages expose
stale/denied/incomplete coverage. Successful structural SQL schedules refresh;
uncommitted PostgreSQL structure remains session-owned until transaction resolution.
The cache status shows when a save is pending or has failed. A cache-save failure
keeps the current metadata available and does not discard unsaved configuration.
Object coverage still determines which operations that metadata can support.

**Settings → SQL language** stages formatter options and inspection severities
for each dialect, with optional data-source overrides. Join-column, routine-overload,
Boolean, operator, CASE, array and query-output checks can each be disabled or
assigned a severity. Existing saved inspection choices remain in effect when new
checks are added; new checks start enabled. Completion and parameter
help use cached metadata; they never execute SQL. Formatting preserves comments,
quoted contents and line endings and can be undone as one edit. A selected SQL
range is formatted without rewriting the rest of the document. Unsupported or
malformed regions report availability instead of pretending to be valid SQL.

The result presentation selector switches **Table**, **Transpose**, **Tree** and
**Text** while retaining source rows, selection and drafts. Text explicitly names
its selection or loaded-window scope. **Record View** shows the active row
vertically. **Value Editor** keeps exact raw content, offers bounded JSON/XML or
binary interpretations, and loads large retained values only in explicit chunks.
Use full export for complete large output.
Open **Value actions** for **Copy displayed text**, **Load next 64 KiB**, **Reset
value preview**, **Edit complete value**, **Add editing page**, **Set NULL** or
**Set DEFAULT**. **Stage change** and previous/next page remain visible. Switching
**Edit** off and on, or reopening a retained complete draft, resumes that draft
without loading the original over your edits.

**Edit complete value** loads an explicitly selected retained text/JSON/binary
value up to 1MiB, with a 262,144 UTF-16-unit text limit. The native text field shows
one page of up to 16,384 UTF-16 units. Previous/next page keeps every untouched
prefix and suffix, and **Stage change** submits the complete value. The current
page indicator stays visible beside the paging controls while editing, including
at large text sizes. Undo applies
to the active page and resets when changing pages. **Add editing page** grows the
value within its full limit; that explicit action may repack fragmented text
pages without changing the text. Failed drafts retain the complete exact String.

Binary editing uses 16KiB byte pages in hexadecimal/Base64. **Add editing page**
requires a full 16KiB-aligned end below 1MiB; fill a partial last page first. It
opens an empty page without padding or changing any bytes. Oversized pastes are
rejected in full, preserving the previous input and selection. Cancellation keeps
the original preview; failed input remains available for correction. Larger
values stay available through export. Native PostgreSQL array text and raw engine
values enter the same validated staging workflow.

Read-only Raw, formatted JSON/XML, hexadecimal and Text views also page their
represented scope, up to 2,097,152 UTF-16 units, without changing named copy/export
scope. NUL-containing text cannot be edited in the native text field; inspect its
exact UTF-8 bytes as hexadecimal/Base64 or use raw export. BusyData keeps the
underlying value unchanged.
Text/CSV copy and **Copy displayed text** refuse embedded NUL before writing to
the clipboard, leaving the previous clipboard unchanged. Use explicit JSON copy
for an escaped representation or export exact raw bytes. Clipboard payloads remain
limited to 1MiB of UTF-8.
The Value Editor distinguishes a complete value from a retained preview and keeps
failed input available for correction. Offline inspection shows the already
retained raw preview; loading/exporting additional bytes requires the live backend.
**Display format → Temporal · custom pattern** accepts calendar fields and quoted
literals, including up to six `S` fraction digits. Choose original calendar fields,
UTC or local timezone separately; conversion requires an explicit retained offset.
Unsupported temporal values remain raw. These settings use stable column identity
and affect display only, including after an object rename.

**Aggregate** states the exact retained selection and its partial-result limit.
Exact repeating averages may appear as ratios. **Related rows** lists verified
incoming/outgoing foreign keys; choose a relationship and review its generated
browse operation. Missing key columns, NULL components or incomplete metadata
explain why navigation is unavailable. **Clone Row** stages an insert, omits
identity/generated/key values and opens its editable assignments before Apply.
Unset, value, NULL and DEFAULT have distinct meanings. Display formatting changes
appearance only; ordinary copy/export remains exact. Local result sorting and
filtering operate on retained rows; server table browsing always uses a separate
reviewed request. Text minimum/maximum use retained UTF-16 ordinal order, with an
explicit notice that database collation is not used. Incompatible selections and
unavailable relationships explain their limitation before navigation.

Open Data and Open SQL first verify the selected object and acquire its
structural metadata. A live Explorer or SQL selection uses its explicitly selected
physical session, including its temporary objects and transaction context; BusyData
does not silently switch an existing data document to another session. Restored
object names require an explicit connection and fresh resolution. If the source
or metadata changes during preparation or review, refresh and review explicitly;
existing retained rows and staged drafts remain available. Views and PostgreSQL
materialized views can be browsed read-only through the same flow.

Retained-row editing requires structural metadata captured **before** the query
ran. Introspect the intended table at **Structure** or **Structure and source**
level, then run a fresh query. Use a qualified base
table in `FROM` when earlier search-path namespaces have not been inspected; an
unknown earlier namespace cannot prove that a same-named view was not used. View
projections do not authorize changes to a rewritten underlying table. Read-only
results remain available in every presentation.

MySQL/MariaDB physical InnoDB identity inspection requires visibility of the
engine dictionary, including the server's `PROCESS` privilege. Missing visibility
keeps editing unavailable rather than borrowing identity from a same-named
table. Their temporary tables remain session-local completion sources, with
editing unavailable when physical identity cannot be proved. PostgreSQL temporary
relations use their owning physical session's native identity.
Stored procedures and dynamic SQL may change structure without naming it in the
submitted statement. BusyData then marks affected metadata or session resolution
as unavailable until it can verify the relevant objects. Qualified MySQL/MariaDB
names do not bypass this check. A result captured from an unproved temporary
source stays read-only after that table is removed; explicitly reconcile metadata
and run a fresh SELECT to obtain a new result. Existing results and drafts remain
available for inspection.

MariaDB additionally retains a prepared metadata observer from before the query.
If the native table definition changes or that physical session ends, the old
result remains inspectable and cannot authorize editing. Re-run after refresh
or explicitly rebind a verified recovery record; neither action replays the old
query automatically. MariaDB column display formats remain local to that result
because its observer cannot establish a durable physical column identity.
MySQL/MariaDB TIMESTAMP editing requires the captured fixed-offset timezone.
Named or DST-dependent zones and saved timestamp drafts without their original
timezone facts remain explicitly unavailable.

Metadata settings apply to consoles using the same data-source identity. A
configuration change retires their previous metadata actions until a response in
the new configuration is available. Explorer keeps a previous complete branch
while a same-owner refresh is pending; it never combines pages from different
metadata revisions. After a session becomes disconnected or its transaction
outcome is unknown, metadata actions remain unavailable until the explicit
session workflow resolves that state. A stale Related Rows menu must be reopened
from the current selection; BusyData never replays the underlying SQL.
