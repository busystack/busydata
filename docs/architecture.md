# Architecture

BusyData uses **Flutter desktop → private TLS gRPC/protobuf → one bundled
Temurin Java 25 child → JDBC adapters**. There is one repository and backend build;
no separate daemon, embedded JVM, ORM, Rust backend or reactive framework.

| Boundary | Owner |
| --- | --- |
| Native composition, commands, dialogs and accessibility | Flutter/platform services |
| SQL text, undo, dirty files, drafts and presentation settings | Flutter |
| Physical sessions, transactions, jobs and cancellation | Java |
| Results, metadata, language analysis, changes and administration | Java |
| SSH, database TLS/authentication, transfers and native tools | Java |
| File selection and desktop secure storage | Flutter/platform services |
| Requests, identifiers, exact values, errors and job state | Generated protocol |

Linux retains BusyMax's GTK3 Handy application window with one engine/FlView.
LinuxWindowHost and LinuxPageFrame retain the clipped full-height sidebar and
coordinated movement. Flutter owns the visible header. Windows uses a separate
FluentApp.router/NavigationView composition; Win32 owns caption controls and DPI.
Shared database widgets use DesktopControls, without platform presentation imports.
Riverpod 3 disables automatic retries; execution is an explicit command.

The first-party SQL editor owns exact source, native input admission, ranges,
composition and bounded undo/redo. Official unmodified editor widgets provide
layout through public interfaces. Workspace live-text admission and retained
undo history have independent limits; a refused undo preserves its frame.
[Editor dependency boundaries](editor_dependency_adapters.md) describe the
extension APIs, official-source verification and necessary compatibility pins.
Database parsing and semantic decisions remain in Java. Native identifier
comparison and physical-server affinity use the shared snapshot rules described
in [identifier authority](identifier_rules.md).

Linux accessibility projects the public Flutter semantic tree into BusyData-owned
GTK/ATK objects with strict view, epoch and revision ownership. Native requests
use existing Flutter semantic actions; the projection is presentation state and
contains no independent database model. Only owned GObject class initializers
install interface implementations. Runtime replacement of Flutter classes,
private engine callbacks and changes to upstream objects are prohibited. See
[native accessibility ownership](native_accessibility_bridge.md).
Native scrolling uses Flutter's public reveal operation before an offscreen
control can receive focus or input; it retains the same ownership guards.


Main wires ordinary Java packages through constructors. Java exclusively writes
SQLite profiles, history, operation records, verified staged-edit recovery and durable introspection policy under
a single-writer lease. Flutter writes separate presentation and recovery files.
Version-1 human-readable workspaces contain ordinary .sql paths and safe profile
references, without secrets or live sessions. Opening does not connect or execute.
Linux and Windows share the database close policy, with their native dialog
controls. It refreshes all tracked physical sessions, shows counts of drafts,
staged edits, jobs, transactions and unknown outcomes, and refuses to close when
draft recovery or backend cleanup fails. A populated untitled SQL document is
unsaved even when it was created from history or generated SQL.
The owned Linux header Close invokes this coordinator before Flutter's public
required application-exit operation, so the completed review is not requested
again after cleanup. Concurrent clicks share one request; disposal or a changed
coordinator invalidates a pending approval. OS exit requests continue through
the same coordinator via `AppLifecycleListener`. The owned GTK delete handler
sends the public cancellable framework request through the binary messenger
without registering a platform-channel handler. Only a current explicit exit
reply may terminate the application; unavailable, cancelled or malformed replies
leave it open. The existing hide-on-close policy remains a hide operation.

A console retains its physical session. Ordinary jobs serialize on its fair lock;
status and cancellation have independent resources. Limits are 8 interactive
sessions, 2 concurrent metadata connections, 32 admitted jobs, 128 job summaries,
100,000 launch-local execution IDs, 2 transfers and 2 general CPU analyses and 4 bounded language CPU tasks.
MySQL reserves a separate cancellation connection per console. MariaDB cancellation
uses an ephemeral view within the same two-connection metadata admission limit.
This view repeats the owned SSH/TLS handshake with the selected credentials and
verification policy; it never reuses deleted handshake scratch or a missing
thread-local forwarding context from Connector/J's implicit cancellation opener.
Only the exact owned thread's current query is stopped; SQL is never replayed.
Virtual threads handle blocking work; they do not remove these limits.

Direct transaction SQL is tracked from actual driver/server state. PostgreSQL
failed transactions remain visible; MySQL/MariaDB DDL can implicitly commit.
Network failure during a write yields UNKNOWN_OUTCOME and an uncertain session
that refuses further SQL. Explicit reconnection never restores transactions or
replays operations. Pending operation records are reconciled on restart as
interrupted reads or uncertain mutations, without restoring physical sessions.
Cancellation must finish control work and validate the session before reuse.
Session status reads cached handshake data and volatile state without taking the
executing session lock or issuing JDBC SQL. Result paging and appends use fair
row-I/O admission so a continuous writer cannot starve a reader. Active results
cannot be disposed to implicitly stop execution; cancel or wait first.

PostgreSQL auto-commit execution caps rows and does not claim cursor streaming.
An explicit streaming read creates a job-owned read-only transaction only for one
conservatively classified SELECT, uses forward-only fetching initially at 16 rows
with bounded adaptive batches of 1–256 rows, then
rolls back and restores auto-commit. Manual sessions retain their transaction
semantics. PostgreSQL rejects requested cursor ownership in a direct-SQL transaction
while JDBC auto-commit is still on; turning it off is an explicit session command.
Raw user SQL uses the engine adapter with escape rewriting disabled. PostgreSQL
uses a single native driver transport invocation behind the JDBC Statement
interface; it bypasses the pinned driver's narrower JDBC splitter and automatic
SQLSTATE-based replay while retaining its cursors, decoding and buffer limits.
Cancellation belongs to the active statement generation through cursor fetching.
Finishing the result chain revokes queued timeout workers; cancellation before
execution or after the final result is a no-op. Close waits for cancellation I/O
before releasing its physical-session owner.
MySQL and MariaDB retain their native JDBC Statement execution. Generated value
operations use parameterized JDBC statements. See security.md for the pinned
transport interfaces and cancellation ownership.
MySQL uses Connector/J text streaming with ordinary statements
and fetch size Integer.MIN_VALUE; MariaDB uses positive fetch size.
MySQL disables the driver's implicit net_write_timeout changes so streamed-result
cleanup preserves session settings and cached transaction status.
The SQL deadline includes fetching, preventing unlimited job-owned read transactions during slow
consumption. Cancellation is not rollback of already committed statements.
After initialization, a console connection's physical read timeout retains a
five-minute minimum and allows the selected SQL deadline plus a five-second
cancellation window. Connection setup, metadata views and cancellation
connections retain their original five-minute read bound.

Java retains private data and row-offset index spools: 1GiB combined quota, 64 results, 1M rows/result,
256KiB encoded rows. Large text/binary previews have separate full-value files;
retrieval chunks are at most 64KiB. Arrays have depth/element limits. Flutter pages
are at most 1MiB/500 rows; its cache is 2MiB/1,000 rows with 4 concurrent loads.
TableView lays out a window of at most 256 fetched rows; range controls, absolute
row navigation and keyboard traversal preserve global row identity across windows.
Progress/page repaint notifications coalesce at 100ms while document edits and
explicit commands notify immediately. Paging starts at actual missing row offsets and uses returned continuations.
Byte-shortened pages never force a repeated fixed-boundary request. Wait/end,
oversized metadata/rows, disposal and persistent errors are explicit; retries
read retained data and never execute SQL.
Editor and command controls retain their widgets across progress changes. The
table retains cells until visible data, selection, geometry or theme changes;
fetched-row totals update without invalidating the same immutable retained rows.
Scrolling and export never rerun SQL. Retained exports use the same job system
without a live session and can export explicitly incomplete fetched rows.
Row offsets are on disk rather than retaining one boxed object per row. The
launcher caps JVM heap at 128MiB and direct memory at 64MiB; these do not cap all
native memory or replace combined measurements. JDBC may allocate an entire individual field/array before these limits apply;
large individual driver allocations are not certified as bounded.
The launcher selects Serial GC for this small retained dataset; desktop tests
verify the actual collector names through Java management counters and measure
combined RSS, responsiveness, cancellation, concurrency and large transfers.
This choice follows [Java 25 small-dataset collector guidance](https://docs.oracle.com/en/java/javase/25/gctuning/available-collectors.html)
and remains subject to those measurements rather than an assumed footprint gain.
The bundled Java 25 launcher also selects the documented client compiler
configuration with `-XX:+NeverActAsServerClassMachine`: C1 compilation and a
32MiB reserved code cache. This limits compiler overhead without changing heap,
direct-memory, retained-result or language-service limits. The heap probes use
the same configuration; desktop gates still measure the complete workload,
including sustained execution, concurrency and large transfers. See the
[Java 25 launcher options](https://docs.oracle.com/en/java/javase/25/docs/specs/man/java.html).

Job summaries are separate from result ownership. Summary pages are at most
32 entries/1MiB with revision-bound continuation; the retained-result catalog
provides authoritative column metadata after job eviction. Leases protect active
exports while disposal waits. Failed cleanup retains quota accounting and a
retryable disposal record.

Ordinary unary RPCs have a 30-second deadline. CSV/JSON import preview, review and
start share an explicit five-minute admission budget for sources bounded to
8GiB. Java keeps the reviewed SHA256 inside the existing single-use approval
store. Start consumes its 120-second permit before long source checking, verifies
the exact request/session revision and server-owned digest, then submits one job.
The immutable snapshot is verified before writes; admission and job cancellation
are checked between bounded reads. No deadline failure retries an operation.

Java user-data schema 4 retains bounded verified edit drafts (32 records, 8MiB total,
1MiB/record). Flutter retains staged intentions in memory and requests Java to
store verified provenance/original rows, never client-supplied original labels.
Recovery lists records without connecting. Explicit rebinding requires the original
engine/endpoint/database/user, unchanged table metadata and a fresh change preview.
It creates retained rows without executing their source query. Before an apply,
the record becomes APPLYING; an acknowledged commit becomes COMMITTED; an
unconfirmed outcome or restart during application becomes UNKNOWN_OUTCOME. These
records prohibit replay. This is crash recovery, not exactly-once execution.
The one-way schema-2/3 to schema-4 migration converts pending old assignments and
binds saved profile fingerprints to their existing opaque metadata source IDs in
one transaction with restart recovery. A physical session captures that resolved
source ID once; all metadata consumers and independent views share it. Option map
order cannot split a source. Existing scope settings and column presentation IDs
remain bound without requiring the rebuildable cache. There is one runtime
assignment format. Optional `StoredEditDraft` fields 10 and
11 retain original MySQL/MariaDB timestamp timezone facts without a further
storage-schema version. Historical drafts lacking those facts stay preserved,
but cannot rebind timestamp originals by guessing an offset.

Typed authentication operations use the same Jobs/Safety/session ownership. Their
redacted review/history never contain password-bearing SQL. Ordinary account
creation/reset/locking/drop and non-login roles retain engine-specific identities;
PostgreSQL requires the server SCRAM policy, MySQL preserves caching_sha2_password
and MariaDB password reset retains the account's authentication methods.

Connection management keeps independent drafts and acknowledged Apply baselines.
Testing does not save configuration; the SSH editor tests only SSH authentication,
while the manager tests the complete database connection. Global source creation
loads Explorer and creates a separate bound console. Query-selector creation and
explicit SQL-context editing retain their captured owner throughout connection
and replacement; no action adopts another active tab or replays SQL.

Retained-row views use Java-owned disk-backed source mappings and shared spool
quota. Internal SQLite indexes are metadata, not another database connector.
Routine identifiers are bounded to 8KiB; keyset continuations to 16KiB raw/24KiB
encoded. Explorer selection, local filtering and keyboard revelation do not
rebind SQL documents. Activity filtering operates on the bounded fetched catalog;
selection, focus and scroll survive background updates without another request.

Ordinary Explorer metadata projects immutable central snapshots into bounded
pages, scoped counts and signed owner/revision/scope continuations. Native keyset
acquisition belongs to the introspection adapters, not completion. Compound JDBC index and
foreign-key rows represent one logical tree object. PostgreSQL metadata for a
different database uses a deliberately database-targeted ephemeral read-only
view, sharing the owned tunnel/security policy and the existing two-view
admission limit. It never calls setCatalog on the console connection. Dedicated
first-use sessions choose that database before opening JDBC while retaining the
saved profile identity. Category commands carry DatabaseCreationScope separately
from DatabaseObjectIdentity, so New Query retains its source/database/schema
without treating the category label as a native object.

Explorer namespace rules live in the existing bounded private presentation
record, keyed by stable source ID and database. All rules retain bounded exclusions
rather than converting a visible discovery page into a positive name list. Dialog
edits remain independent of the page window; exact pending/default names are
verified before persistence, with stale-owner acknowledgement rollback.
Scoped refresh invalidates retained descendant cursors and reloads expanded
branches under the acknowledged metadata revision.
Rules and view visibility are
independent of document connection contexts. Pattern matching runs in a disposable
worker with a deadline. The frontend validates reply owner, instance, revision,
kind and scope, retains bounded page history, replaces displayed pages, and
disposes row focus nodes when their identities leave the window. Object identity
also preserves relation/routine subtype. Focused tree commands carry a captured
scope through the existing registry; document toolbars retain document ownership.
The same presentation record stores source-folder identities/membership/order,
view filters and bounded expansion references. Group-label migration is one-time;
folders cannot own sessions and cycle/depth checks apply to moves. Local virtual
views contain stable IDs, names, source/catalog/schema scope and user-authored SQL
(16KiB each, 32KiB total). No credentials, backend handles or result rows accompany
them. Local writes roll back on failed persistence. Opening a saved definition
uses an independent SQL document; executing it uses the existing review path.
Deleted sources remain unbound until an explicit namespace rebind.

Document metadata enumeration reuses WorkbenchModel's owned request and shared
document budget. It consumes bounded continuations, validates every scope/revision,
rejects non-progress, and adopts only complete results. Column surfaces restore
native ordinal order. Direct children use exact parent/name/native-identifier
lookups rather than a first-page filter; missing generated-field evidence blocks
staging and import mappings while backend review remains authoritative.

Exact reveal reuses the Explorer's paged acquisitions and revision fences. Child
reveal resolves the exact parent as a table or view, retaining its relation subtype
and original database before choosing the owning tree category. Deferred focus
checks that a newer tree selection has not superseded the revealed row. Explicit
SQL symbol navigation preserves current backend failures while superseded analysis
replies remain ignored. A server-confirmed read-only analysis admission rejection
can be re-probed up to five times within the original deadline; each attempt
revalidates the captured document and context. Keyboard failures use the existing
safe localized feedback. A narrowed lookup is visibly identified and has no
full-category count. Scoped
two-table comparison uses the existing snapshot/diff document and checks exact
returned identities. Snapshots capture one ordinary table; server views and
rename matching are unavailable in this mode. Migration SQL inherits the first
object's exact connection scope and still requires normal SQL review.

Explicit editor reveal/DDL uses the strict protocol's lexer-based, active-statement
symbol lookup. It reads bounded matching table/view identities from the captured central snapshot
under the physical session's catalog/search path without live acquisition. Literals, comments, ambiguous aliases and unresolved context changes cannot
choose an object. Native-case uncertainty requires explicit selection. Definition
viewers may use a captured live metadata source; that runtime hint is never
serialized and does not share SQL execution or table-result ownership.

Output owners and publication phases are specified in [output_commit.md](output_commit.md).
Required verification and unaccepted platform gates are in
[development.md](development.md); database limits are in
[database_support_matrix.md](database_support_matrix.md).


## Coordinated metadata, language and data editor

[Metadata platform](metadata_platform.md), [SQL language service](sql_language_service.md)
and [Data Editor](data_editor.md) define the shared model. One Java-owned platform
normalizes identities, properties, coverage and relationships in rebuildable
`metadata_catalog.sqlite`. A per-source writer gate prepares immutable indexes
outside the short ownership/proof guard, then atomically swaps the validated
snapshot. Interactive readers retain their exact revision and do not wait for
rebuildable cache I/O. Pending/failed cache writes are explicit; they do not undo
valid memory publication. Durable introspection policy
belongs to user-data SQLite and survives cache rebuild. Session-local overlays
are isolated, never durable and reconciled against real transaction outcomes.
Physical-session name-resolution evidence is separate from durable coverage.
Opaque execution can make it unknown; exact native observations and supported
owned inventories reconcile it. These revisioned views share immutable indexes,
and independent refresh cannot certify another connection's temporary objects.

Native restore uses a separate database session. Its reviewed lifecycle fences
the persistent metadata source before client launch, keeps refresh publication
and editability proofs unavailable during active restores, and preserves physical
session temporary overlays. Acknowledged external changes reconcile through the
independent metadata connection policy, including while the console transaction
remains active. Unknown or cancelled external writes leave metadata stale for
explicit reconciliation; metadata refresh never resolves a console transaction
or replays a restore. See the metadata platform for overlapping-operation and
publication ownership rules.

The SQL service has lossless tokens, tolerant dialect syntax, semantic scopes,
central-metadata binding, native type/signature evidence and separate bounded
editor operations. [Joined-table namespaces](sql_join_resolution.md) preserve
merged output columns and nearest-query-scope lookup. The
[expression pipeline](sql_expression_typing.md) propagates operator, cast,
CASE, routine, CTE and set-output types from that same captured metadata.
The execution splitter remains independently validated.
Flutter retains its own text, undo, selection and visual state.
The six independent language RPCs each admit at most 1MiB, separately from the
16MiB execution/review envelope. Their source limit is 262,144 UTF-16 units;
inspection settings admit 64 entries with 128-unit codes and 16-unit severities.
Six transport admissions feed four bounded language CPU tasks.

Result presentation state refers to retained source rows and one edit batch.
Table/Transpose/Tree/Text, Record View and Value Editor cannot create independent
editable copies. Java owns exact aggregates, verified relationship navigation,
clone intentions and reviewed DEFAULT/NULL/value assignments. Per-column display
settings live only in bounded Flutter presentation preferences and never affect
retained equality, database ordering, optimistic checks or default extraction.
Persistent display keys require the profile and Java-proven physical column
identity from strict protocol 15. Names alone are transient. MariaDB's
session-owned prepared witness proves retained editing continuity, not a durable
column identity, so its column display settings remain result-local.

Metadata response adoption uses one bounded scalar ownership registry shared by
Explorer, language services, table browsing and Related Rows. It is distinct from
the Java semantic model and contains no database objects. See
[metadata revision ownership](metadata_revision_ownership.md) for source-wide
configuration propagation, physical-session epochs, terminal states and staged
branch publication.
