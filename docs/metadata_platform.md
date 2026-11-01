# Metadata platform

The Java backend owns the metadata authority. `MetadataPlatform` publishes
immutable `MetadataSnapshot` instances shared by Database Explorer, SQL services,
table browsing, related rows and edit planning. Flutter receives bounded
projections; it does not reconstruct keys, overloads or executable identities from
labels. A completion request reads its captured snapshot and performs no catalog
or internal-cache JDBC work.

## Identity and publication

`MetadataIdentity` distinguishes the connection/security configuration, profile ID,
catalog, schema, object kind/subtype, exact name, parent, overload identity and
physical-session owner. Its length-prefixed SHA-256 key cannot collide through
ambiguous component concatenation. PostgreSQL native IDs preserve relation, column,
routine and named-type identity across renames and level changes. Cosmetic profile
names, environment labels and timeout settings do not change source identity.
`SourceIdentity` fingerprints explicitly enumerated profile, TLS and SSH fields,
sorted option key/value pairs and typed unknown fields. Optional-field and
submessage presence remain significant. Protobuf serialization is not a
canonical identity format: [map ordering is undefined](https://protobuf.dev/programming-guides/proto3/#maps),
and [deterministic serialization is not canonical](https://protobuf.dev/programming-guides/serialization-not-canonical/).
An indexed durable binding maps that fingerprint to an opaque source ID. Every
physical session resolves it once; independent metadata views inherit the
physical owner's ID, including when their read-only policy or target catalog
differs. All metadata consumers use the captured ID. No semantic read performs
an identity-store query.

User-data schema 4 creates `metadata_source_identity` in the same initialization
transaction as any pending schema-2 assignment migration and restart recovery.
For each existing saved profile, it binds the explicit fingerprint to its existing
source ID. Existing catalog keys, introspection settings and opaque Flutter column
preference identities therefore remain valid, even if the rebuildable cache is
absent. Profiles and preference payloads are not rewritten. Unassociated historic
scope settings remain retained; the migration does not guess an owner for them.
New bindings use the fingerprint as the source ID and follow the same indexed
resolution path. The table admits at most 4,096 bindings; exhausting that budget
rejects a new owner without deleting existing settings. A migration failure rolls
back initialization, assignment conversion and recovery changes together.
Display names, engine-quoted names and lookup
keys remain separate. Parent references point to the actual loaded relation;
an unavailable parent is not replaced with a guessed table identity.

PostgreSQL folds unquoted lookups and preserves quoted names. MySQL/MariaDB
database/relation lookup follows the inspected server's `lower_case_table_names`;
column and routine lookup follows their case-insensitive namespace rules.
PostgreSQL database targeting opens a distinct ephemeral physical connection.
MySQL/MariaDB catalog and schema identify the same database. Profile ownership
includes the user/security configuration, so profiles sharing a display ID cannot
share another role's metadata. Identifier rendering uses engine quoting.

MySQL and MariaDB comparison evidence is acquired through the independent native
metadata adapter and captured immutably with each snapshot. Physical names,
aliases and dictionary constraint/routine names use their verified native
comparison domains. Actual constraint type distinguishes separate namespaces;
foreign-key creation uniqueness and native DROP resolution use distinct verified
domains rather than a universal Unicode fold. Missing evidence permits names-only inspection with
explicit unavailable completeness and editability; it never invokes Java Unicode
folding or a reader-side catalog query.

Each physical connection captures its immutable engine, identifier mode, server
version and filesystem case flag in one bounded initialization header read. Independent metadata
connections confirm their own header before acquiring or reusing full maps.
Cached maps must match that physical header, including a mode change with an
unchanged version. A mismatch produces an unavailable snapshot view sharing the
existing indexes; publication, physical reconciliation and final proof admission
cannot certify it. Rows and exact cached names remain inspectable while a valid
independent acquisition replaces the evidence. The console never acquires the
full character corpus.

An initially empty source may bootstrap only this native-rule header when an
owned native observation proves a temporary relation, owned temporary inventory
needs comparison evidence, or an explicit reviewed table inspection requests it.
The maps are acquired through a separate bounded metadata connection. Exact
source, physical owner/context, configuration, request, ticket, proof and native
affinity fences are rechecked before the new immutable header revision is
published. A nonempty incomplete or incompatible model requires normal explicit
reconciliation; bootstrap never silently rekeys its existing facts. Ordinary
cold persistent SELECTs do not bootstrap comparison maps. A fully drained native
header recognizing a persistent table or view still returns unavailable source
provenance when central identifier rules have not been inspected. That absence
of comparison evidence leaves the existing physical resolution and epoch
unchanged, records no verified relation, and cannot upgrade an earlier unknown
resolution. Native read, identity, permission and cancellation failures continue
to retire affected physical authority.

Header-only publication does not claim a successful structural refresh. Its
unpersisted generation reports `WRITE_UNAVAILABLE` until the existing sole durable
cache publication path stores that source, configuration and native generation.
An older cache completion or another source cannot certify it. The one recorded
old-to-new empty-header transition may readmit an already committed smart-refresh
intent only at a real statement acknowledgement or cleanup boundary, for the
same physical session/context and configuration/request epoch. This exception
never relaxes worker reservations, publication fences or RPC response revisions;
normal durable publication and source invalidation retire it.

MariaDB trigger resolution on an observed case-insensitive server filesystem is
explicitly unsupported. Exact cached trigger names remain inspectable, with
incomplete coverage and `UNSUPPORTED` projections; other object kinds retain
their verified availability. No client-host filesystem or guessed uppercase
mapping substitutes for server evidence.

A rule fingerprint change rekeys every retained object and session overlay under
one rule generation, preserving exact identities, properties and temporary
objects. Unrefreshed scope coverage becomes stale; only the newly acquired
branches regain completeness. Old normalized physical-resolution anchors are
retired until owning-session verification. A source-wide rule publication ticket
also fences older disjoint acquisitions, and an owned overlay cannot replace the
durable source's rules. Coverage/session views and compact execution candidates
share the same immutable rule evidence, with its memory charged to their budgets.

Each snapshot carries a metadata configuration revision and publication revision.
Object/coverage records retain the session/context revisions at acquisition.
Refresh tickets prevent an older acquisition from replacing a newer publication
for overlapping scopes, including broad-versus-exact fragment races. Configuration
changes invalidate outstanding acquisition tickets. A logical explicit refresh
reserves its ticket before dependency discovery opens a metadata connection.
Reservation and the final memory swap use the same short source monitor.
A separate per-source gate serializes durable metadata writers and their cache
attempts. Physical-session overlay publication, analysis capture and interactive
proof admission never acquire that gate. An independently prepared durable
candidate still verifies its captured owned views before publication; a newer
owned creation or retirement makes that older candidate stale.
Entry replacement, coverage reconciliation, indexes and session-overlay rebases
are prepared outside the source monitor. The final swap rechecks the exact
captured source/snapshot, rules, configuration, reservation, proof epoch,
physical session/context and bounded overlay/resolution owners. A concurrent
invalidation or native mutation rejects the candidate rather than advancing its
owner. Catalog traversal, file/JDBC work and rebuildable cache writes do not run
under the source monitor. Readers retain immutable revisions while preparation
and cache I/O continue. A foreground owned publication proceeds through the
short source admission guard while a private cache write is pending. It never
waits for the durable writer while holding its physical-session lock. Unrelated
physical-session overlays have separate captured ownership fences.

Schema artifacts and designer inspections use that same reservation contract.
The platform captures the physical owner, context and configuration before
opening the existing independent metadata view. Its 30-second acquisition
budget starts before opening; cancellation, deadline and owner are checked
before and after the existing connection constructor. Opening retains the
existing driver connect/context timeouts, including a profile connect timeout
of up to 120 seconds. The acquisition deadline does not interrupt that
constructor. Once a view is open, its read scope enforces the remaining budget
through native acquisition, durable writer admission and the inspection
callback. Its single-use capture capability publishes with the original
reservation; stale ownership never creates a replacement acquisition.
The borrowed view remains open through later native designer checks, including
collation validation, then closes without touching the command connection.
Autocommit artifact capture never owns the physical-session lock while waiting
for a durable writer. A caller that already holds that lock leaves its lease
intact and receives explicit unavailable admission. Direct manual capture
requires an already active transaction: manual mode with `IDLE` state is
unavailable before any JDBC work or lease change, since a catalog query could
implicitly start a transaction. Active manual capture reads the owning physical
session and publishes its session-only overlay. It cannot abort that connection,
resolve its transaction or persist uncommitted structure as durable metadata.
Native structure/source stays under that physical ownership. The existing
MySQL/MariaDB JDBC transport-descriptor reader separately opens a read-only
metadata view: only that view temporarily normalizes `NO_BACKSLASH_ESCAPES`,
restores its mode and closes. This does not release the caller's lease, change
the physical SQL mode or publish the manual overlay as committed metadata.
PostgreSQL's exact JDBC descriptors remain on its owning physical session.
The production schema inspection/designer operation retains its independent
committed-metadata route, including when the command session is manual and idle.

Unchanged immutable semantic objects are shared between revisions; protocol
fields carry ownership/revisions once rather than duplicating them in properties.
Failed acquisitions retain prior objects with explicit unavailable/stale scope
information rather than publishing an empty successful replacement.

Typed workbench failures may retain one internal closed origin enum for source
parsing, coverage rebase, inspection, native classification or owned publication.
A retained-proof origin identifies observation of a stored failure state; it does
not guess the historical cause. This job diagnostic retains only that enum;
it does not attach the original throwable or its SQL/driver text. It does not
alter the protocol reason, ownership,
cancellation, admission, deadline or retry behavior. Verification assertions can
record the origin separately from the unchanged `timed_out` wire code; elapsed
time alone cannot identify which component expired.

Exact identity, normalized name, namespace/kind/parent and incoming/outgoing
relationship indexes are built once for a snapshot. SQL services retain the exact
captured snapshot for a request. A later refresh cannot change an in-flight
request's binding.

Stable object identities use a private sorted reference array for bounded
`O(log N)` exact lookup. Read-only map views preserve acquisition order through
the same immutable value list used by lazy protocol projection; they retain no
linked hash entry per identity. Namespace, normalized-name and relationship
indexes keep their existing lookup semantics and share unchanged native objects
between published generations. Session-resolution and coverage views share these
immutable indexes.

The native name index stores singleton objects directly within a namespace;
duplicate-name lists exist only for actual ambiguity. Protocol projections are
lazy and are never retained as a second full catalog. Empty, inapplicable native
column attributes are omitted while availability and level remain explicit.
Immutable property maps share a bounded key-layout dictionary and keep values in
lossless encoded backing storage. Lookups decode only accessed values; SQLite
still stores each property as an indexed scalar. Empty enum labels and malformed
synthetic UTF-16 values retain their exact identity and contents.

## Storage and recovery

`metadata_catalog.sqlite` format 5 is a private, rebuildable cache. Its `publication`,
`object`, `property` and `coverage` tables contain normalized scalar identities,
properties and acquisition evidence; no serialized Explorer response is the
metadata authority. Namespace and normalized-name indexes support lookup;
property indexes support native types, relationship targets and source evidence.
The scalar `property` table uses its composite primary key as its SQLite
`WITHOUT ROWID` storage key, avoiding a second copy of that key in a rowid-table
index. Other tables retain their existing layout. No consumer uses property
rowids, generated keys, incremental BLOB access or SQLite update hooks. This is
an internal layout optimization, independent of database-engine support; see
the official [SQLite storage guidance](https://www.sqlite.org/withoutrowid.html).
Transactional updates replace changed identities and scopes and remove deleted
records. Only eight source publications are retained. Memory publication precedes
the optional cache transaction. Its exact previous SQLite header (source, profile,
revision, configuration, engine, timestamp and bounded native-rule bytes) must
match before using a delta. Without a matching memory predecessor, the writer
may retain an unchanged stored object/property body only after checking every
scalar and property against the freshly acquired immutable snapshot. It checks
the owning profile, configuration, engine and native rules, rejects a newer
stored revision, and verifies exact row counts, identities, types, availability
and evidence revisions. This streams bounded SQL projections into the existing
snapshot's indexes; it does not restore another semantic model, trust a content
hash or derive fresh coverage from cached rows. Missing, extra, malformed or
different rows require full replacement of that source's body, including orphan
properties. Coverage and the publication header are always written from the
new snapshot when there is no matching predecessor. This avoids rewriting a
large, exactly unchanged cache after restart admission rejected restoring it.
SQLite's [storage classes](https://www.sqlite.org/datatype3.html) and
[byte-length functions](https://www.sqlite.org/lang_corefunc.html#length) govern
the type and size guards before JDBC materialization. The
private cache obtains an SQLite `IMMEDIATE` transaction before reading that
header and checking stored content, so another cache writer cannot change the
base between validation and publication. Commit/rollback covers only the acknowledged private-cache
transaction; it never changes ownership or boundaries of a user's database
transaction. Native-rule bytes are type/byte bounded in the SQLite result before
materialization. A failed write therefore cannot make a later delta retain
phantom rows or omit changes.
Per-source writer ownership preserves cache-attempt order. Loaded coverage is
always stale and cannot authorize fresh writes. If durable user-policy revision
differs from the cache header, startup filters objects/scopes through the
committed policy before exposing those stale facts.

Cache status is `WRITE_PENDING` while the current cache attempt remains within
its deadline. Cancellation, expiry or changed identity reports
`WRITE_UNAVAILABLE` even while native work remains owned. Actual completion may
report `AVAILABLE` only for a still-current acknowledged attempt with successful
cleanup; other outcomes remain unavailable. A cache-only timeout/failure
leaves the committed memory snapshot valid and does not replay SQL. Metadata
coverage freshness and cache persistence health are separate facts: settings may
report `WRITE_UNAVAILABLE` alongside the exact current snapshot revision and
complete `AVAILABLE` scopes. Each source retains only a bounded failure enum,
validated SQLSTATE, numeric driver code and cache-attempt duration. SQL, driver
messages, identifiers, paths and values are not retained in that diagnostic.
A later successful cache attempt clears its prior failure. Cache lock
admission, busy/progress callbacks and row loops observe cancellation and the
refresh's remaining deadline; direct publication establishes a thirty-second
cooperative deadline. It does not preempt a blocked native call or terminal
cleanup. Preparation also checks its deadline/cancellation in catalog phases
and index-building chunks. Essential introspection-preference CAS writes remain
different from disposable cache writes: affected-scope policy filtering is
prepared outside the source monitor; a short transition fences proof admission
while the preference write occurs outside the monitor. Only a successful
preference CAS commits the new policy/model. Its final revision view shares
prepared indexes and preserves any concurrent loss of authority through an
immutable coverage view: newly excluded keys stay absent and latest changed
incomplete scope records cannot become complete. The next preparation
materializes coverage outside the monitor, bounding that view composition.
Native mutation flags and proof epochs remain fenced.
Each cache attempt also records eight constant-size duration fields: admission;
connection setup, `BEGIN` and predecessor inspection; row mutations; `COMMIT`;
callback detach; connection close; rollback; and the complete call. These exact
local call durations can include native synchronization and cleanup. Commit
state separately distinguishes not attempted, unacknowledged/unknown, and
acknowledged. A deadline-overrun observation does not throw after an acknowledged
commit or imply rollback; terminal close failure remains a separate fact. Metrics
are available only for their exact current source owner, profile, snapshot and
configuration revisions. They are diagnostics, not proof of a wall-clock bound.
The repository reserves one terminal ownership slot before opening a private
writer. Row preparation uses the existing cancellable VM/progress/busy checks;
after its final check, the same connection and callbacks transfer sequentially
to that slot's sole daemon owner for `COMMIT`, rollback when appropriate, callback
detach and close. Failed preparation also hands its cleanup to this owner. No
second writer or cache load/rebuild is admitted until actual completion. The
slot has no queue, and retains scalar attempt identity/timings rather than a
snapshot, source model, session or branches. Its completion observer holds only
a weak platform reference and is discarded after one delivery.

Both normal publication and essential preference configuration release their
caller-owned writer locks before optionally waiting for the receipt under the
original deadline. A wait timeout neither retries persistence nor implies that
the private transaction rolled back. Outstanding work reports explicit pending
or expired/unknown cache health while fresh memory remains available. A late
acknowledged commit with successful cleanup may subsequently report available;
its deadline-overrun measurement remains unchanged. Monotonic attempt identity,
source owner, profile, snapshot/configuration revisions and native-rule fingerprint
fence completion, so an old result cannot clear a newer failure or policy gap.
Preference CAS remains synchronous and never waits for a disposable terminal tail.

Any unconfirmed native close failure quarantines the sole cache slot until backend
restart, even after its worker exits. It never authorizes a reopen, retry, cache
deletion or corruption rebuild. Java/JDBC closed flags are not proof of native
closure: [SQLite close](https://www.sqlite.org/c3ref/close.html) may leave a busy
handle open. Sequential transfer uses the pinned driver's synchronized connection
operations and callback thread attachment in [Xerial 3.53.4.0 NativeDB.c](https://raw.githubusercontent.com/xerial/sqlite-jdbc/3.53.4.0/src/main/java/org/sqlite/core/NativeDB.c).
This bounds caller waiting for the terminal tail and caps owned connections/workers;
it does not promise preemption or finite lifetime of blocked native connection
setup, row I/O or an
operating-system read, write or synchronization call. No user database transaction
or execution is transferred, retried or resolved by this cache mechanism.
Every private cache writer applies and verifies its own `max_page_count` before
beginning the transaction, after arming cancellation/deadline callbacks. The bound
is derived from that connection's page size and remains 512MiB for main-database
pages; it is never increased to admit an existing oversized cache. Such a cache
is refused explicitly without copying, deleting or truncating it. SQLite WAL and
shared-memory sidecars remain owned by SQLite's transactional lifecycle.
`max_page_count` is connection-local pager state, rather than a persistent file
policy. This follows the pinned [SQLite 3.53.4 pager
implementation](https://github.com/sqlite/sqlite/blob/version-3.53.4/src/pager.c),
whose [source identity](https://github.com/sqlite/sqlite/blob/version-3.53.4/manifest.uuid)
is `bf7c7f30031888f4e796e429ab3978879485813aaca6f641c7b33e4e09459bcc`.
Numeric failure categories follow SQLite's [primary and extended result
codes](https://www.sqlite.org/rescode.html); no human-readable error parsing is
used.

Each publication stores one bounded, validated native-rule encoding. Cached
lookup keys must agree with that publication's decoded rules before any objects
are adopted; map lengths, framing, owner and fingerprint are validated first.
Startup restores resident indexes for the newest eligible cached source, rather
than materializing all eight catalogs in a 128MiB process. Other source records
remain disposable on disk and are replaced when their scopes are explicitly
reconciled. Analysis never opens the cache database on a keystroke.

Physical or logical cache corruption rebuilds this cache after closing readers.
Invalid kinds, identities, levels, properties and coverage are rejected before
adoption. Cache recovery never deletes profiles, history, documents or drafts.
Introspection preferences live in the durable `metadata_configuration` table in
`metadata.sqlite`, separately from rebuildable catalog storage. Initialization
removes the obsolete `schema_cache` response table while
preserving existing user records. Source bindings live in user-data schema 4;
rebuildable catalog format 5 is a separate version.

Cache format 5 discards older rebuildable catalog records before restoring any
objects or fingerprints, including the format-4 rowid layout and format-3
Java-derived Unicode lookup keys.
It also preserves the earlier invalidation that prevents unchanged routine fingerprints
from reviving parameters acquired without the function/procedure kind in their
identity. MySQL and MariaDB parameter lookup verifies `ROUTINE_TYPE` together with
the native schema and specific name; function return rows at ordinal zero remain
separate from callable parameters. The profile, introspection-configuration and
edit-recovery formats are unchanged. See the official [MySQL PARAMETERS table](https://dev.mysql.com/doc/refman/8.4/en/information-schema-parameters-table.html)
and [MariaDB PARAMETERS table](https://mariadb.com/docs/server/reference/system-tables/information-schema/information-schema-tables/information-schema-parameters-table).

Restored catalog objects are evidence for display, not current server truth.
Every restored coverage record is `STALE` and incomplete until reconciliation.
External DDL while the backend was stopped cannot establish false absence or
current editability. A successful settings update is authoritative even if a
subsequent rebuildable-cache write fails; revisions keep the cache from
authorizing a different configuration after restart.

## Levels and configuration

| Level | Acquired evidence |
| --- | --- |
| 1: names | Names, namespaces, kinds, parent/overload identity and availability; structural properties are not complete. |
| 2: structure | Native/JDBC column types, dimensions, nullability, defaults, generation/identity, collation/comments, keys, check constraints, index components and routine signatures where visible. |
| 3: source | Level 2 and bounded native or generated object source with explicit provenance and retrieval status. |

Availability is independent of empty enumeration and introspection level.
`AVAILABLE`, `NOT_REQUESTED`, `UNAVAILABLE`, `DENIED`, `INVISIBLE`, `UNSUPPORTED`,
`PARTIAL`, `LIMITED`, `STALE`, `CANCELLED`, `TIMED_OUT`, `FAILED` and `UNKNOWN`
remain distinguishable. Property-level availability describes unavailable source,
oversized expressions/comments and metadata not exposed by the engine. Relation
comment previews retain at most 2,048 native characters, with exact `remarksBytes`
and explicit `remarksAvailability`; a partial comment does not make the table
identity unavailable. Full native comment hashes still participate in refresh
fingerprints. MySQL/MariaDB base-table names do not require querying view bodies;
view-source fingerprints are isolated to the view kind. A
generated PostgreSQL structural definition is explicitly partial when ownership,
grants or other properties are omitted; a nonempty string does not certify source
completeness.

Settings independently include/exclude catalogs and schemas, select system-object
visibility and kinds, filter object names with bounded `*`/`?` patterns and assign
default/per-scope levels. Child structure follows its selected parent object.
Per-scope keys encode catalog/schema components unambiguously, including names
containing separators. A configuration revision invalidates affected coverage and
removes excluded objects. Unchanged effective permission and level preserve the
exact coverage record, including prior failure state and acquisition time; a
revision-only or equivalent predicate change does not force unrelated structure
stale. Parent-owned column/key scopes follow the selected relation name rather
than a child's own name. Broad/filtered name enumerations become incomplete when
their membership predicate changes, even if every currently cached name remains
allowed: newly enabled unseen names have not been enumerated. Catalog/schema
selector and system-visibility changes affect their literal namespace or spanning
aggregate; an override that keeps a namespace's effective level unchanged masks
a default-level change there. No configuration change upgrades old incomplete
facts or fabricates fresh empty scopes for newly enabled kinds/names.
Empty inclusion lists use the acknowledged current
database/search path; they do not silently inspect every discovered database.
MySQL/MariaDB scope selection never forms a catalog/schema Cartesian product.

`MetadataSettings` validates the exact physical session/context and expected
configuration revision. Scope status is paged, at most 128 records per reply.
The dialog can request full or incremental refresh explicitly. Counts describe
metadata objects in the configured scope, never server table row counts.

## Refresh algorithms

Full refresh acquires configured scopes and structural children on independent
read-only metadata connections, then publishes the complete acquired change set
atomically. Permission failures retain explicit denied coverage. A deadline,
cancellation or owner change cannot publish an incomplete successful replacement.
Explorer refresh modes route through this coordinator: `FULL` respects the data
source configuration, `FRAGMENT` refreshes the selected object/branch and required
relationship owners, and `INCREMENTAL` uses the two-stage scan. Unknown modes and
refresh-plus-continuation requests are rejected. Durable Explorer acquisition
uses independent metadata connections; physical access is reserved for owned
temporary objects.

A first-page Explorer acquisition can be overtaken by another metadata writer.
It may reuse the winning immutable snapshot only when the exact requested scope,
level and captured configuration are complete. Otherwise it reacquires catalog
metadata at most three times under the original 30-second deadline. Physical
owner, session/context and configuration changes reject the request; cancellation
is checked around every acquisition. These retries never execute user SQL.
Continuation requests remain strict: a changed enumeration fingerprint, owner,
context, configuration or scope rejects the cursor. An unrelated publication may
retain the same verified branch; a continuation never reacquires its catalog
branch or switches to changed enumeration contents.

Fragment refresh acquires the selected object, structural children and required
relationship owners. Exact routine points that carry the same immutable
reference already admitted by a replacing parent in this publication certify
only their coverage, without rescanning the full catalog. This requires an exact
typed signature, current reference membership, matching normalization and
available facts at the requested level. Historical/reused points and unmatched
references retain the ordinary reconciliation and rule-change guards.
Within one publication, reconciled namespace-name branches
precede freshly acquired exact structural branches. Conservative stale facts
from name reconciliation cannot overwrite an explicit structural repair;
unrequested scopes retain their stale availability.
A native exported-key identity scan discovers incoming
foreign keys added outside BusyData, including referencing owners absent from the
old snapshot. Previously cached referencing owners are also refreshed to remove
deleted relationships. Composite keys preserve separately verified ordinal
components; formatted comma-separated previews are never parsed into identifiers.
Previous and current outgoing targets supply the required verified table identity
and columns, including configured cross-schema/database targets. Acquisition is
limited to this dependency hop; a target's other outgoing keys do not expand the
refresh into an entire foreign-key component. Independent catalog work is queued
by database without mutating an active catalog iterator.

A relation fragment also reconciles previously cached name enumerations in its
namespace. The names scan and selected structural branches publish atomically;
name coverage is explicitly Level 1. Fixed-size, per-parent native catalog
aggregates verify cached column, index, constraint, relationship and trigger
fingerprints. PostgreSQL type dependency aggregates include domains, enums and
array element types. InnoDB identity probes read bounded native table identities
and MySQL column epochs without fetching the complete column dictionary.
Verified unchanged higher-level objects, source and exact coverage are shared;
missing or changed evidence retains inspected facts as explicitly stale. A name
scan cannot silently certify structural completeness. Removed identities remove
child objects and invalidate child/incoming relationship coverage. An exact fresh
fragment supersedes stale facts from the name reconciliation. Replacing a subset
at a lower level invalidates matching broader higher-level coverage; it cannot
leave a complete source claim over an object whose source was not reacquired.
Verified unchanged exact source coverage remains available. Excluded object kinds
are not mistaken for missing requested evidence during preservation. When only
selected structural kinds were requested, verified columns remain current;
previous source whose omitted structural dependencies were not verified stays
visible with `sourceAvailability=STALE`, while matching Level 3 coverage becomes
stale. Missing evidence for a requested kind still invalidates its facts. Refresh writers
use the durable snapshot as their baseline; a physical-session temporary overlay
cannot conceal or replace the permanent relation during independent acquisition.

Incremental refresh first scans native identities and bounded count/fingerprint
evidence, then retrieves detail only for changed scopes. Equivalent acquisitions coalesce
under at most 32 in-flight owner/context/configuration/scope keys; joined readers
can cancel independently of the primary acquisition. Column/default metadata,
constraint identities/expressions, index definitions, relationships and routine
version evidence participate in the relevant scans. Deleted relation identities
remove their child scopes. Diagnostics report the scan/detail strategy, scanned
and fetched scopes, fetched objects and elapsed acquisition time. An unchanged
refresh fetches no structural detail; it is not a renamed full refresh.
MySQL/MariaDB relation fingerprints additionally include verified InnoDB table and
column-dictionary identities; second-resolution creation timestamps cannot prove
that a same-name table was not replaced. PostgreSQL relation fingerprints include
native OIDs and storage filenodes.
Unchanged incremental branches retain native immutable entries without building
protobuf copies. Fetched branches normalize and share unchanged objects during
acquisition, releasing branch-local wire projections before the next branch.

Routine refresh compares native fingerprints per exact overload or routine kind,
then acquires signatures/source only for changed or newly discovered identities.
The namespace and its exact point scopes publish atomically: deleted overloads
are removed without touching same-named siblings, and unchanged routines retain
their existing immutable objects and any verified higher source level. A changed
structure acquisition retires an older exact source proof instead of leaving it
complete. Missing or denied fingerprint evidence retains inspectable history
with incomplete coverage; it cannot certify an empty namespace.

Routine fingerprint acquisition includes parameter order, modes and native type
facts rather than relying on second-resolution alteration timestamps. MariaDB
also requires bounded native source reads to fingerprint defaults unavailable in
its public parameter catalog. These are stage-one reads, one transient source at
a time; diagnostics report their read/byte counts separately from the changed
point details fetched in stage two. An unchanged incremental routine refresh
therefore fetches zero detail objects, without claiming zero native source reads.
Scanned routine scopes count the namespace and each exact identity visited in
both verification passes; they are scope-work counts rather than SQL-call counts.
MySQL/MariaDB scans use fixed native SHA-256 values for bodies/characteristics
and length-tagged parameter facts joined by exact schema, specific name, routine
kind and ordinal. They use no `GROUP_CONCAT`: a streamed scan admits at most
10,000 rows, 1,024 parameters per routine (plus a function's return ordinal zero)
and 8MiB of fingerprint evidence. MariaDB additionally admits at most 8MiB of
bounded source-byte work per scan. A single source value retains at most 64KiB;
the pinned JDBC drivers can still buffer a received packet up to their 8MiB
limit, so this is not a claim of wire-level source streaming. Source-read counters
include failed or limited acquisition attempts, while byte counters describe the
bounded bytes actually consumed. The existing 30-second acquisition deadline,
cancellable statements and publication-owner fences apply to both passes.
The original source owner's captured introspection policy filters identities
before any native source read or detail fetch. An independent metadata view's
connection profile is not used to infer that policy; configuration changes still
invalidate the acquisition before publication.

If native parameter/default interpretation remains unsupported or limited,
known names, modes, types, counts and any acquired source remain inspectable as
partial facts. Only fresh NAMES coverage is complete; the exact requested
structural/source point retains its typed failure. Source-only limits can retain
a complete signature at STRUCTURE without claiming complete SOURCE coverage.

Smart refresh consumes acknowledged DDL effects from Java execution. Autocommit
effects schedule independent acquisition. PostgreSQL manual-transaction effects
remain session-pending until explicit commit; rollback discards pending ordinary
structure. MySQL/MariaDB follow the actual transaction state after implicit DDL
commit. Unknown outcomes mark metadata stale and require reconciliation. A
superseded explicit metadata acquisition may reacquire at most three times under
its original deadline; this never retries SQL execution or a database mutation.
Coalescing and admission remain bounded, and unsupported impact analysis selects
a conservative configured namespace scope. A precise relation effect invalidates
the affected name enumerations, that relation's structural coverage and cached
incoming relationship/constraint owners. Unrelated relation structures remain
current. When impact cannot prove a complete fragment, invalidation and refresh
use the conservative scope. Completion JOIN proposals, related rows and table
browse origins require current source/target column and relationship coverage;
an available cached foreign-key object alone cannot authorize a stale relation.
The execution listener is owned by `Jobs`; it is mandatory for every execution
path. A failed older acquisition cannot mark a newer successful publication stale.
Acknowledged committed effects are invalidated promptly and retained as one
bounded reconciliation intent per physical session (at most 32 effects, eight
sessions). Transaction-pending effects remain separate: rollback removes only
those uncommitted effects, while an earlier autocommit or implicit DDL commit
still needs reconciliation. Commit promotes the acknowledged transaction effects.
The intent contains descriptors and scalar ownership fences, never a snapshot.

Executable admission happens after each acknowledged statement's context and
transaction refresh and revision advance, while it still owns the physical lock.
An autocommit DDL acknowledgement schedules independent acquisition even when a
later statement in the same script is still running. Final job cleanup and
reviewed session commands provide further real boundaries with the same ownership.
An acquisition admitted before execution advances must pass its original owner
checks; a later boundary may admit the remaining committed intent again.
Every admitted attempt captures an immutable queue owner: exact source and
physical session, durable publication revision, last reserved ticket,
configuration revision, session revision and context revision. This includes
attempts waiting behind work for the same session.
Admission checks that owner and reserves one ticket before any dependency JDBC.
Atomic publication checks it again. A newer explicit reservation supersedes that
batch even before the explicit acquisition publishes. Obsolete batches neither
retry with a new owner nor join an explicit refresh's coalesced future, publish
diagnostics or stale newer coverage. An initial connection task's failure
invalidation uses the same reservation fence. A real later statement ACK or
cleanup boundary, including completion of a benign read, may admit a fresh attempt from still unreconciled
committed intent. It must preserve the original source generation, configuration,
context, durable publication and explicit-request epoch. The central epoch
distinguishes explicit reservations from Smart acquisition and synchronous owned
temporary-inventory maintenance; every attempt still requires the exact latest
ticket at acquisition and publication. Explicit refresh starting, publishing,
or changing policy prevents intent revival. Worker completion/finally never
recaptures an owner or schedules new intent. Only attempts already admitted by
real statement or cleanup boundaries can be dequeued there. Matching success retires its intent;
newly acknowledged effects create a distinct generation and cannot be erased by
an older attempt. Advancing only the execution revision for an ordinary read
does not invalidate newly acquired structure. One background acquisition worker leaves the other
metadata connection slot available to interactive requests.


Native restore uses a typed external-mutation boundary because its SQL runs in a
separate native session. Immediately before launching the reviewed child, the
central source owner admits at most two mutation leases, advances its acquisition
and publication fence, and marks all durable source coverage stale. It retires
all retained editable-source evidence for that source without changing retained
rows, value files or drafts. Existing owning-session temporary overlays and
session-resolution facts remain unchanged. Persistent session-overlay coverage
is retired alongside durable coverage so that rebasing onto a later durable
publication cannot certify pre-restore persistent evidence. Pending console DDL
identities remain inspectable with stale coverage; exact temporary identities
and their coverage are preserved. Native prelaunch invalidation runs without the
Job status/cancellation monitor, and cancellation is checked again immediately
before starting the child. A refused or failed launch releases
only its prepared lease and has no unknown database outcome.

While any lease is active, explicit and background acquisitions fail with the
structured stale state before starting metadata JDBC. Acquisitions that began
before restore cannot publish across its source fence. Generated operations and
retained-proof publication use the same barrier; ordinary user SELECTs can still
retain inspectable results with unavailable editability. Result spools and indexes are allocated and registered with a noneditable proof,
and bounded identity metadata is reserved, before entering the source monitor.
The final source/proof-epoch gate only swaps prepared immutable proof and column
references under a separate short proof lock; file I/O, quota waits, witness close
and disposal never run under that monitor. Unused proof quota is released after
leaving it. The proof-publication gate also rejects a compact execution proof
captured before a restore wave.
The last source lease is held through memory-only retirement of all registered
available and rollback-recoverable stale proofs; only then can its native terminal
boundary release the barrier. Witnesses are detached during that retirement and
closed afterward outside the source monitor. External proof retirement is
irreversible: the console's rollback and ordinary same-structure recovery cannot
make an old retained result editable again. Recovery rebind captures the same
source/proof-epoch fence before physical verification and finalizes only after
its exact retained rows and assignments are rebuilt. A superseding restore leaves
the original durable draft unchanged and returns a structured stale result.
MariaDB's unusable definition witness is detached and closed through its existing
bounded physical-owner cleanup outside source and result-wide locks.

Only a real successful native child completion, including relay acknowledgement,
records an external committed intent. It enters the existing bounded Smart intent
map separately from uncommitted console DDL and reconciles configured persistent
context through independent metadata connections even when the console has an
active transaction. It never commits, rolls back or replays console work. Two
overlapping successful restores reconcile only after the last active lease
settles. A final nonmutating spawn failure may release an already captured ACK
and already admitted immutable attempt; it cannot capture a newer owner.
Explicit requests and publications, configuration, source generation, and physical
context still supersede that attempt. Any overlapping started restore with an
unknown or cancelled outcome retires the wave's successful intent and leaves
metadata stale until an explicit successful acquisition. Job outcome uncertainty
remains unchanged by that acquisition.

## Session overlays

Owned composition admission counts the durable base once and each distinct owned
delta once. Staging reserves new objects, key layouts, coverage and index/mask
allocations before preparation; semantic references already retained by the base
or captured prior delta are not charged as new allocations. Reservations transfer
to the published resident view only at the atomic memory swap and are released on
failure or cancellation. An empty retired inventory carries no duplicate model
charge. Rebuildable storage rejects composed snapshots before opening a write.

An owned snapshot is a fixed-depth composition of the captured immutable durable
snapshot and a small acquired delta. Durable identities, native name indexes,
namespaces and relationships are shared. Only owned facts, replacement masks,
coverage overrides and packed visibility/rank masks are allocated. Rebase replaces
the captured durable base directly; it cannot retain a chain of old bases.
Temporary names shadow persistent relations together with their unacquired child
metadata. Missing owned columns or relationships remain explicitly incomplete;
a same-named permanent relation cannot supply them. A verified empty inventory
retires every temporary mask and restores the exact current permanent identity.

An uncommitted ordinary structural effect lazily marks inherited structural
coverage stale for its physical owner, including explicitly qualified PostgreSQL
relations. Name-visibility uncertainty alone cannot certify old columns. Freshly
acquired owned overrides may regain completeness while inherited structure stays
stale. Commit or rollback replaces the owned pending structure atomically and
retains temporary facts; cancellation cannot expose an intermediate durable-only
view or erase the prior owned snapshot.

Temporary definitions belong to the creating physical session. PostgreSQL refresh
reads that session's acknowledged `pg_temp` namespace. MySQL 8.4 does not expose
user temporary tables through ordinary table enumeration. MariaDB 11.8 exposes
them as `TABLE_TYPE='TEMPORARY'` in the owning session's `information_schema.TABLES`;
that inventory must never run on an independent metadata connection. The
`TEMPORARY='Y'` flag alone also describes some system views and is insufficient.
Owned inventory respects configured namespaces, kinds, patterns and levels.
An exact temporary target is inspected through a zero-row JDBC result and native
column metadata on its physical connection. No other session performs that read.
These rules follow [MySQL SHOW TABLES](https://dev.mysql.com/doc/refman/8.4/en/show-tables.html)
and [MariaDB's TABLES definition from 11.2](https://mariadb.com/docs/server/reference/system-tables/information-schema/information-schema-tables/information-schema-tables-table).
MySQL/MariaDB temporary identities obtained by exact physical classification use
only the bounded native CREATE TABLE header. The first SHOW result field is a
reference alias and never supplies an executable name. A shared lossless lexer
reads the header with the captured SQL modes, including ANSI_QUOTES and doubled
identifier delimiters. At most 2,048 UTF-16 header units are retained; the existing
8MiB cell receive bound, complete drain, encoding checks, physical ownership and
cancellation remain mandatory. Malformed or cut body syntax after a complete
name does not change the header's identity. Names/structure acquisition does not
materialize or retain a full source document.

In native identifier modes 0 and 1, both pinned CREATE renderers supply the stored
table-share name. The name must match the requested target and optional namespace
through the central verified comparison rules before publication. Objects expose
`nativeNameAvailability=AVAILABLE` with `nativeNameProvenance` distinguishing
`OWNED_NATIVE_CREATE_HEADER` from MariaDB's
`OWNED_NATIVE_TEMPORARY_INVENTORY`. A temporary marker retires the
same-name permanent resolution claim, even if the remaining header is limited,
malformed or unavailable. It cannot leave old permanent editability authoritative.
An already complete, fresh owning-session structural model can retain its exact
published record only when a new fully drained native definition, SQL mode and
renderer proof match the previously acquired evidence under the same scalar
source/configuration/native/physical/context/resolution owners. Unknown,
names-only, stale, partial, failed or changed observations still retire authority
and require explicit structural acquisition. Merely observing the same name or
TEMP marker cannot certify cached columns.

The native definition marker is a streaming UTF-8 SHA-256 over the complete
bounded SHOW CREATE cell, with explicit availability/provenance. An incomplete
read never exposes a prefix digest. ANSI and NO_DIR_IN_CREATE, and applicable
MariaDB output-omission/emulation modes, report PARTIAL source evidence; active
renderer variables and the actual session SQL mode are inspected without changing
them. MySQL's hidden generated-key renderer also prevents complete source proof.
This marker is owned comparison evidence, never physical incarnation or temporary
edit authorization, and is never persisted as durable metadata.

The same bounded native header adapter distinguishes an actually resolved VIEW
from TABLE without using SHOW's first display field as canonical identity.
Generated readonly browsing requires that actual kind/persistence match the
Java-selected central object; a TEMP-table shadow cannot use a persistent view
approval. Exact executable identifiers remain central metadata identities.

Mode 2's CREATE header also renders the reference alias in both pinned engines;
this header cannot certify an exact temporary name. Exact physical classification
therefore reports `UNSUPPORTED` name evidence for that mode, keeps the reference
unproved in its physical context, and never substitutes SHOW labels, Java case
conversion or JDBC display metadata. This limitation does not change durable
catalog introspection or connector scope. Mode 2 requires the applicable server
filesystem and is not certified by case-sensitive Linux fixtures.

The authoritative renderer distinction is defined by
[MySQL 8.4.10 SHOW implementation](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/sql_show.cc#L1833)
and [MariaDB 11.8.9 SHOW implementation](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_show.cc#L2092),
with the [MySQL case contract](https://dev.mysql.com/doc/refman/8.4/en/identifier-case-sensitivity.html).

Owned temporary inventory admits at most 128 configured catalogs, 256 temporary
relations, 8,192 columns in total and 8MiB of projected metadata under a ten-second
deadline. Descriptors and detail maps reserve bytes before retention. Fixed
multirow native queries stream with MySQL's `Integer.MIN_VALUE` mode and MariaDB's
single-row nonzero fetch mode, including `SHOW` statements; a per-packet receive
limit alone cannot bound a complete multirow result. The MySQL behavior follows
the [Connector/J streaming contract](https://dev.mysql.com/doc/connector-j/en/connector-j-reference-implementation-notes.html),
and MariaDB's behavior follows the pinned
[3.5.10 ClientMessage result selection](https://github.com/mariadb-corporation/mariadb-connector-j/blob/3.5.10/src/main/java/org/mariadb/jdbc/message/ClientMessage.java#L325).
PostgreSQL overlays include temporary relations, sequences, routines and named
types. The `pg_temp` alias resolves only to the owning physical namespace; another
session's `pg_temp_*` namespace is rejected. These scopes never enter independent
durable refresh or persistent cache publication.

Known MySQL/MariaDB temporary table source is retrieved with `SHOW CREATE TABLE`
on the locked owning physical session, using its verified overlay identity. The
native `TEMPORARY` marker is checked before accepting source; an independent
permanent object is never a substitute. Busy ownership fails immediately. Source
copies retained in metadata and returned through protobuf are bounded to 64KiB
of UTF-8. This is separate from the native receive budget: both adapters set
`maxAllowedPacket` to 8MiB, and the pinned drivers reject an oversized packet
before allocating its payload. The drivers materialize the native row before
BusyData applies its source-text limit, so the Reader does not establish a
64KiB JDBC allocation limit. Fetching one row at a time bounds the row count,
not the size of that row. The receive guards follow
[MySQL Connector/J 26.7.0's packet reader](https://github.com/mysql/mysql-connector-j/blob/26.7.0/src/main/protocol-impl/java/com/mysql/cj/protocol/a/SimplePacketReader.java#L62)
and [MariaDB Connector/J's `maxAllowedPacket` option, introduced in 3.5.10](https://mariadb.com/docs/connectors/mariadb-connector-j/about-mariadb-connector-j#maxallowedpacket).
Cancellation/control completion is fenced before the physical session can
execute another command. A temporary
network deadline is restored after inspection. Source carries its SQL-mode
provenance; a changed SQL mode requires a new owned source read, and modes that
suppress native options produce an explicit partial source status. Changing the current database retains the original temporary
namespace and physical owner. Individual temporary child source that is not
exposed by the adapter remains explicitly unsupported.

Overlays are immutable, excluded from persistent cache writes and filtered by
session identity. Temporary definitions shadow persistent definitions only for
the owning session. Ordinary SELECT revision advances do not discard a valid
temporary definition. A subsequent committed publication rebases its persistent
portion while retaining the owned overlay. Ending the physical session removes
the overlay. PostgreSQL transaction resolution refreshes temporary structure,
including rolled-back DDL and `ON COMMIT DROP`; MySQL/MariaDB temporary creation
is not treated as rollbackable ordinary DDL. Dropping a temporary relation restores
the persistent identity it shadowed. Uncommitted ordinary structure never becomes
globally committed metadata.

Opaque `CALL`, `DO` and `EXECUTE` operations can change structure without naming
their affected objects in the submitted SQL. Before attempting them, the central
platform records a new physical-session resolution epoch with `UNKNOWN` state
and invalidates potentially affected retained proofs. Successful execution also
schedules conservative durable reconciliation. Failure does not establish absence
of side effects. Commit, rollback, independent refresh and overlay replacement
cannot erase this uncertainty. MySQL temporary create/drop is not rollbackable,
even though it avoids an ordinary DDL implicit commit; see the
[8.4 transaction rules](https://dev.mysql.com/doc/refman/8.4/en/implicit-commit.html).

The session view shares the durable snapshot's immutable indexes. It does not
copy or reindex the catalog when its resolution state changes. Exact owned
observations, capped at 2,048 entries and a 512KiB estimate per physical session
within the metadata resident budget, may verify individual
relations within the captured epoch. They do not certify uninspected names.
Complete supported owned inventories can reconcile their actual scope; another
connection's absence scan cannot. Each changed captured view receives a new
snapshot revision, so in-flight language responses remain tied to their original
visibility evidence. These facts are never written to the rebuildable cache.
Fresh temporary structure also needs evidence for the exact acquired table and
column coverage in that epoch. Only a complete matching native-definition marker
under unchanged exact owners can preserve previously acquired complete columns;
a name or TEMP marker alone cannot certify them. Names-only acquisition does not
grant structural completeness. Readers use effective snapshot coverage; raw
catalog acquisition coverage is reserved for publication and rebuildable storage.
The physical-session resource owner invokes a bounded, once-only cleanup callback
on disconnect and quarantine, so overlays disappear even when no later metadata
read or transaction RPC occurs. A closing session cannot publish a new overlay.

## Native capabilities

The supported targets and driver pins remain those in
[database_support_matrix.md](database_support_matrix.md).

| Feature | PostgreSQL 17 | MySQL 8.4 | MariaDB 11.8 |
| --- | --- | --- | --- |
| Namespaces | Physical database plus schemas/search path | Database/catalog namespace | Database/catalog namespace |
| Relation subtypes | Ordinary, partitioned, foreign, view, materialized view, sequence | Ordinary table/view; standalone sequences unsupported | Ordinary table/view/native sequence |
| Routine identity | Exact argument signature distinguishes overloads | Kind/name identity; native parameter list | Kind/name identity; native parameter list |
| Keys | Primary/unique, composite FK components/actions | Primary/unique, composite FK components/actions | Primary/unique, composite FK components/actions |
| Index structure | Expressions, included attributes, native ordering/method | Column/expression parts where exposed, ordering/method | Native indexed-column parts, ordering/method |
| Named types | Enums, domains and visible native named types | Standalone type objects unsupported; column-native enum/set | Standalone type objects unsupported; column-native enum/set |
| Source | Native routines/views/triggers; explicit partial generated structural definitions | Native `SHOW CREATE` where permitted | Native `SHOW CREATE` where permitted |
| Temporary objects | Physical `pg_temp` namespace; transaction-aware | Physical-only temporary relation inspection | Physical-only temporary relation inspection |
| Retained editable-source generation | Relation OID and storage filenode | InnoDB table ID, instant-DDL row-version epoch and column-dictionary fingerprint | InnoDB table ID/dictionary fingerprint plus a retained native table-definition observer |
| Sequence structure | Native type/start/min/max/increment/cycle/cache | Unsupported | Native type/precision/start/min/max/increment/cycle; cache size not exposed by the metadata table |

Exact JDBC transport types coexist with native declarations, signedness, enum/set
content, array dimensions and domain base types. PostgreSQL array element OIDs and
delimiters come from the actual element's `pg_type` row; database type display
names are not parsed to reconstruct them. Routine parameters retain names,
modes, native types, optional/variadic state and return type. PostgreSQL defaults
come from `pg_get_expr(proargdefaults, 0)` and the catalog's trailing input
argument count. The bounded lossless lexer preserves commas inside arrays,
parentheses and quoted text while aligning expressions with native parameter
ordinals and modes. See PostgreSQL's [`pg_proc` catalog](https://www.postgresql.org/docs/17/catalog-pg-proc.html)
and [catalog information functions](https://www.postgresql.org/docs/17/functions-info.html#FUNCTIONS-INFO-CATALOG-TABLE).

MariaDB 11.8 supports defaults in both function and procedure headers, while its
`PARAMETERS` catalog does not expose them. Level 2 therefore reads the exact
native `SHOW CREATE` header with its stored `SQL_MODE`, reconciles names, modes
and ordinals, and retains only parameter/default facts. The body remains opaque
and is not retained at Level 2. MySQL 8.4 has no parameter-default grammar and
does not fetch source to establish Level 2 defaults. Native default `NULL`, an
absent default, and unavailable source remain distinct. Unsupported headers,
denied source and limits preserve known parameter types with incomplete
signature availability; they cannot establish a complete argument-count rule.

PostgreSQL resolves default-expanded candidates across routine kinds before
checking whether the statement requires a function or procedure. Captured
parameter/default facts remain complete, but call-local parameter information,
argument validation and return-type inference stay conservative when a visible
opposite-kind candidate can accept that call's arity. The editor reports partial
signatures in that case; it does not reproduce PostgreSQL's full coercion and
candidate-preference algorithm or claim that every such call is ambiguous.
An arity the opposite kind cannot accept retains the usual complete signature
availability. Name completion continues to present the requested routine kind.

The shared native routine decoder bounds introspection source to 64KiB of raw
bytes and retained UTF-8, with one extra byte only to detect overflow. Schema
artifact capture explicitly uses its separate existing 6MiB maximum and keeps
its aggregate artifact budgets; it fails rather than truncating a definition.
These are owned read/retention bounds: JDBC buffers the received row first,
subject to the configured 8MiB driver packet limit described below. MySQL uses
the public field-character-set metadata to decode the raw bytes strictly;
MariaDB's pinned driver uses UTF-8. Independent acquisitions own their connection
deadline. A transaction-aware owned acquisition requires the physical-session
lock and cancels only its current statement, preserving the console connection
and transaction. No privileged source fallback or automatic SQL replay occurs.
Every result, statement and connection warning chain is checked with bounded
length and cycle rejection. One native informational exception is permitted:
MariaDB's verified `SHOW CREATE FUNCTION` may report note 1585 with a null or
empty SQLSTATE when the stored name collides with a native function. The
[pinned server intentionally emits that note while loading a stored function](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_lex.cc#L1510).
Preflight, procedures, other engines and every other warning remain strict;
mixed chains cannot hide a conversion warning. Warning messages are not retained.

The pinned MySQL/MariaDB JDBC metadata pattern path runs on an independent
metadata view. That view temporarily masks `NO_BACKSLASH_ESCAPES` while fetching
escaped exact identifier patterns, then restores its original SQL mode and
network timeout. The user's physical session is never changed. Exact returned
catalog/schema/table components are checked before adoption; no wildcard scan is
used as a substitute. Native attributes enrich those transport descriptors, while
the recovery-shape signature uses the original driver facts before enrichment.
Temporary objects keep their separate physical-session introspection path.

Editing requires a compact proof captured before execution from the immutable
metadata model and the acknowledged physical-session resolution context. The SQL
source must bind directly to the same base relation; a simple view exposing base
columns does not authorize underlying-table editing. Unqualified PostgreSQL
sources require proof for preceding temporary, system and search-path namespaces;
excluded or uninspected namespaces produce explicit incomplete metadata. Generated
qualified table-browse SQL avoids ambiguity. Known stale proofs may be compared
with fresh exact physical and column evidence after explicit review; an execution
whose proof was unavailable never gains provenance from a later refresh.
Before JDBC execution, `ExecutionMetadata` detaches at most 2,048 column evidence
entries under a 1MiB budget, including its captured context. Jobs retain these
strings, native identities and type/context flags through execution and fetching;
they retain no catalog snapshot, index, syntax tree or metadata projection. The
native physical classifier receives detached identifiers, and MariaDB prepares
its observer before the final preparation frame releases the snapshot. Actual
JDBC base provenance and result ordinals finalize the selected column proofs.
Execution and recovery share evidence extraction and finalization. Unavailable
unselected columns do not disable a valid selected projection; a selected
unavailable column or a stale source table remains unavailable. Database/schema
case matching uses the captured central identifier rules and preserves canonical
metadata identities in the proof.
For MySQL/MariaDB, an eligible direct-table SELECT first classifies the native
relation on its locked physical session, before submitting user SQL or opening
its result stream. Native `SHOW CREATE TABLE` distinguishes a permanent table
from a session temporary table with the same qualified name. Only a bounded
header is retained for classification; the complete bounded cell must be drained
and validated. The existing native receive limit and cancellation fences apply.
Generated browse and edit operations recheck physical resolution as well. Denied,
absent or unproved classification cannot borrow durable InnoDB identity; ordinary
user results remain inspectable with unavailable edit provenance. Removing a
temporary table never upgrades the provenance of its previously retained result.
PostgreSQL array projections also capture the native array input context. Text
array input requires `array_nulls=on`; date/timestamp element text requires ISO
`DateStyle`, and interval text remains unsupported without an exact interval
format proof. A later settings change cannot upgrade an unavailable execution
proof. Recovery does not assign the current DateStyle to historical array text:
stored date/timestamp literals must independently validate as ISO against the
verified native column before a fresh proof and review can be created.
The pinned PostgreSQL driver itself closes a connection when a server DateStyle
report is outside ISO ([driver protocol contract](https://github.com/pgjdbc/pgjdbc/blob/REL42.7.13/pgjdbc/src/main/java/org/postgresql/core/v3/QueryExecutorImpl.java#L2947)).
BusyData preserves that explicit physical-session failure and never retries the
setting or a user query to manufacture support for another DateStyle.

MySQL/MariaDB InnoDB dictionary access requires `PROCESS`. Missing privileges leave
physical generation explicitly denied and data editing unavailable. No creation
timestamp or guessed generation substitutes for dictionary identity. Identifier
filename mappings outside the verified native mapping subset are explicitly
unsupported for this proof. Temporary MySQL/MariaDB objects cannot borrow a
persistent InnoDB generation and remain read-only. These are current editing
limitations, including when structural browsing and SQL completion are available.

MySQL's `TOTAL_ROW_VERSIONS` participates in the physical generation: an instant
drop/add of identically named and typed columns can preserve the table ID and
current dictionary shape. MariaDB's exposed InnoDB dictionary does not expose an
equivalent durable column epoch. Its retained results therefore also own a native
server-prepared observer established before the original query executes. The
observer contains only generated, identifier-quoted `SELECT 1 FROM ... LIMIT 0`;
preparation obtains metadata without executing it or starting an idle manual
transaction. It is not a retained copy or replay of the original SQL.

Before review, related-row navigation and Apply, Java executes this generated
zero-row observer and compares the native session reprepare counter immediately
before and after it. A changed counter invalidates the original table-definition
proof, even if current names, types, values and dictionary IDs match. Apply repeats
the check while holding its verified table metadata lock. An idle manual
transaction is not implicitly started for inspection. Unknown native identity,
a missing observer, cancellation, a changed definition or an uncertain physical
session remains explicitly unavailable/stale. Counter resets before a check do
not substitute for the local before/after comparison.

Observers use the pinned driver's public server-preparation entry point and a
unique generated statement identity; only that observer is removed from the
driver preparation cache. At most 96 active/closing observers cover retained
results and admitted jobs. Disposal and physical-session termination close native
handles under physical-session ownership. Cleanup cannot wait for that ownership
while holding a retained-result monitor. Existing retained values remain available
after disconnection, while editing requires a live owner. Explicit recovery
rebind prepares a new generated observer after stored target, schema-shape and
temporal-context checks, then requires a new reviewed plan.

PostgreSQL column presentation identities derive from native relation/attribute
identities. MySQL column identities combine the verified InnoDB table ID,
instant-column epoch and ordinal, so a replacement does not inherit preferences
for an old column. MariaDB's observer proves a retained execution lifetime but
does not supply a persistent column identity: those presentation settings remain
transient instead of being persisted by display label.

These contracts follow the pinned engine's native table-definition version checks
and reprepare path ([MariaDB table identity](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/table.h#L1028),
[native version comparison](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/table.cc#L9866),
[native reprepare counter](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_prepare.cc#L4474))
and the [pinned Connector/J server-preparation method](https://github.com/mariadb-corporation/mariadb-connector-j/blob/3.5.10/src/main/java/org/mariadb/jdbc/Connection.java#L163).
No native source is copied into BusyData.

## Resource budgets and verification

Each snapshot admits at most 250,000 objects and 192MiB estimated semantic data;
all published sources/overlays and newly normalized in-flight objects share a
128MiB semantic admission ceiling, calibrated against the production 128MiB heap
fixture. This accounting is distinct from JVM heap size; it charges semantic
objects, encoded backing storage, identities and indexes conservatively. A second
large independent acquisition receives explicit backpressure before its indexes
are allocated. Startup
performs cache resource inspection before materialization. Publication retains
bounded old snapshots only for active readers. Persistent cache growth is capped
at 512MiB. Normal refresh deadlines are 30 seconds; physical temporary inspection
uses a 10-second budget. The existing two independent metadata connections and
four enumeration admissions remain in force. Explorer pages target 512KiB and
at most 500 objects, never the complete server catalog in Flutter.

Owning PostgreSQL TEMP browsing captures only a compact native identity,
structural-column and type-dependency witness from the selected immutable model.
An actual native check occurs before approval/job admission and again on the
physical worker; it does not publish a transient snapshot or retain a full catalog
lease. TEMP views additionally verify the central native view-definition marker,
so CREATE OR REPLACE cannot retain an approval merely by keeping its OID/columns.
An observed mismatch first retires that physical owner's resolution authority to
UNKNOWN, then marks its overlay stale. Allocation failure while marking coverage
cannot leave the old shape advertised as AVAILABLE. Durable metadata, other
physical owners, retained values and draft bytes remain separate; reconciliation
and a new review are explicit.

Native generation expressions and type declarations receive server-side byte
inspection before JDBC column materialization. The pinned PostgreSQL driver's
point getTables/getColumns readers also preflight full table/column remark bytes,
column count and aggregate declaration bytes before eager tuple retention.
Oversize metadata is explicitly LIMITED; the JDBC descriptor reader is not
replaced and no truncated declaration becomes complete evidence. Fields beyond the bounded native
projection expose `LIMITED` availability; larger individual or aggregate driver
metadata declarations reject acquisition before allocation. Source retrieval
remains separately bounded and never silently substitutes a preview for source.

`MetadataSnapshotTest` covers immutable/indexed identities, Unicode/quoting,
overloads, coverage states, exact composite components, atomic persistence,
restart staleness and physical/logical corruption recovery. Its synthetic model
contains 10,000 relations, 100,000 columns, 3,000 constraints, 2,000 foreign keys
and 3,000 routine signatures with duplicate names across namespaces. Targeted
lookup measurements do not certify whole-language completion latency.

`MetadataCacheRestartHeapIT` exercises the normalized SQLite cache across two
separate JVM lifetimes while one genuine PostgreSQL physical source remains
available. The catalog contents are explicitly synthetic: 10,000 relations,
100,000 columns, 3,000 constraints, 2,000 foreign keys and 3,000 routine signatures.
A seed process has a bounded 256MiB heap; its fixture construction is not a
production-reader measurement. The restarted process uses the unchanged 128MiB
heap, Serial GC and 64MiB direct-memory ceiling. It invokes the real metadata
settings mapping before reconciliation. An adopted cache must contain the exact
full model with stale, incomplete coverage. A resource-rejected cache must expose
`UNAVAILABLE` or `LIMITED` with no partial object or scope model; an empty result
cannot certify a complete empty catalog.

The restart probe then supplies the synthetic structural acquisition to the real
platform publication path, preserving the normal publication deadline and all
admission guards. It requires exact native object, property and persisted-row
digests, advances the captured snapshot revision, and checks fresh complete
metadata through settings for the same physical owner. Cache health is recorded
before assertions. Cache persistence acceptance starts false and becomes true
only after the exact new header, native rows, and fresh coverage count/all-field
digest have been independently verified. Coverage proof uses constant working
storage rather than copying the full map. A failed attempt must expose a
structured reason and preserve the entire prior
header, coverage and row digests. The report explicitly sets cache persistence
acceptance false in that case; it does not certify a successful large-cache write.
Warm completion and parameter information must remain available without native
JDBC calls or new connections in either case. This covers cache admission and
explicit reconciliation, not a large cache hit when preflight intentionally
rejects it. It does not establish native catalog introspection or desktop
performance. Unique ignored `backend/target/p0-cache-restart-heap-*/` output retains
both child logs, runtime/heap context, availability, persisted counts/digests and
individual service samples, including failed runs. Acquisition, branch preparation,
publication and cache-attempt durations, plus reconciliation GC count/time deltas,
separate fixture construction from the unchanged publication deadline.
`MetadataCacheHealthIT` deterministically blocks the private cache, then expires
or cancels its attempt after memory publication. It requires current fresh scope
availability, explicit cache failure and an unchanged prior transaction. These
cases can fail during BEGIN admission; they do not alone certify partial-write
rollback. The existing repository FULL/trigger regressions provide that
complementary evidence after actual private-cache writes.
`MetadataCacheLimitsTest` exercises actual pinned SQLite page limits with a
smaller helper bound; runtime writers always use the fixed production bound.

The shared owned-view heap probe uses this 118,000-object model, eight physical
views and four durable generations under the shipped 128MiB heap, retaining
32MiB of allocation pressure during analysis. Each owner runs five unmeasured
warmup calls followed by twenty measured completion calls. Warmup evidence records
availability, elapsed time and exact diagnostics; only the explicit analysis
deadline limit may be recorded instead of an available verified field. A cold
warmup deadline limit does not certify acceptance. Every measured call must be
fully available and include the verified field, with completion p95 at most
250ms. The service's 750ms hard deadline and the child process's 120-second bound
remain in force; missing or limited measured output fails the gate.

`MetadataPlatformIT` exercises real PostgreSQL/MySQL/MariaDB levels, source,
incremental external changes/rename/deletion, fragment dependency discovery,
temporary/manual transaction isolation, cancellation and durable configuration.
`SchemaSnapshotReader` supplies bounded native source/evidence to the central
platform; schema comparison/designer artifacts retain their existing format and
are normalized into the same structural snapshots before publication. Reviewed
editing uses deterministic strong fingerprints over native columns, constraints,
foreign keys and type dependencies. The separate durable recovery-shape signature
keeps the original algorithm for every record, preserving old drafts without
runtime format negotiation; all rebound intentions require fresh strong review.
Existing Explorer, schema/designer, browse, editing and related-row integration
fixtures remain required. Missing engine or platform infrastructure is unavailable,
never a passing skip. Record actual commands/results under ignored build output.

Primary references:
[DataGrip introspection](https://www.jetbrains.com/help/datagrip/introspection.html),
[PostgreSQL catalogs](https://www.postgresql.org/docs/17/catalogs.html),
[PostgreSQL identifiers](https://www.postgresql.org/docs/17/sql-syntax-lexical.html),
[PostgreSQL types](https://www.postgresql.org/docs/17/catalog-pg-type.html),
[PostgreSQL enum labels](https://www.postgresql.org/docs/17/catalog-pg-enum.html),
[PostgreSQL sequence catalog](https://www.postgresql.org/docs/17/catalog-pg-sequence.html),
[PostgreSQL relation location](https://www.postgresql.org/docs/17/functions-admin.html),
[MySQL identifiers](https://dev.mysql.com/doc/refman/8.4/en/identifier-case-sensitivity.html),
[MySQL InnoDB dictionary](https://dev.mysql.com/doc/refman/8.4/en/information-schema-innodb-tables-table.html),
[MySQL identifier filename mapping](https://dev.mysql.com/doc/refman/8.4/en/identifier-mapping.html),
[MySQL statistics](https://dev.mysql.com/doc/refman/8.4/en/information-schema-statistics-table.html),
[MariaDB identifiers](https://mariadb.com/docs/server/reference/sql-structure/sql-language-structure/identifier-case-sensitivity),
[MariaDB statistics](https://mariadb.com/docs/server/reference/system-tables/information-schema/information-schema-tables/information-schema-statistics-table),
[MariaDB sequence metadata](https://mariadb.com/docs/server/reference/system-tables/information-schema/information-schema-tables/information-schema-sequences-table),
[MariaDB InnoDB dictionary](https://mariadb.com/docs/server/reference/system-tables/information-schema/information-schema-tables/information-schema-innodb-tables/information-schema-innodb_sys_tables-table),
and [JDBC metadata](https://docs.oracle.com/en/java/javase/25/docs/api/java.sql/java/sql/DatabaseMetaData.html).

PostgreSQL17's UTF-8 identifier folding preserves non-ASCII code points and folds
ASCII letters only; it does not use Java Unicode lowercasing. The rule follows
the release's [official scanner source](https://raw.githubusercontent.com/postgres/postgres/REL_17_STABLE/src/backend/parser/scansup.c).
The live verification fixtures use UTF-8 databases; locale-dependent non-ASCII
folding in single-byte PostgreSQL encodings remains explicitly unverified.

The native fingerprint adapters follow the pinned releases' catalog contracts,
including [MySQL 8.4 index expressions and visibility](https://dev.mysql.com/doc/refman/8.4/en/information-schema-statistics-table.html)
and [MariaDB index ordering, prefix lengths and ignored state](https://mariadb.com/docs/server/reference/system-tables/information-schema/information-schema-tables/information-schema-statistics-table).
Fingerprints hash complete native defaults, expressions and comments on the
server; bounded display previews do not determine whether structure changed.

Relation-comment bounds follow the native
[MySQL 8.4 table options](https://dev.mysql.com/doc/refman/8.4/en/create-table.html)
and [MariaDB table options](https://mariadb.com/docs/server/server-usage/tables/create-table):
the table-comment maximum is 2,048 characters. PostgreSQL longer comments are
retained as explicitly limited previews. The pinned native temporary markers are
emitted by [MySQL 8.4.10 `store_create_info`](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/sql_show.cc)
and [MariaDB 11.8.9 `show_create_table_ex`](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_show.cc).


### Native index facts for clone planning

One bounded native index adapter supplies Explorer structural indexes and the
central `TableStructure` used by reviewed operations. It captures uniqueness,
key versus included attribute count, exact component ordinals, expressions,
prefix lengths and explicit predicate availability. PostgreSQL records
`indnullsnotdistinct`, `indisvalid`, `indisready` and `indislive`; MySQL/MariaDB
record their documented DISTINCT NULL policy and identify unavailable index-state
properties as NOT_EXPOSED. Optimizer visibility/ignored status does not remove a
unique index from clone checks. Native constraints remain separate objects;
standalone PostgreSQL unique indexes are never fabricated as constraints.

The existing central table inspection owns acquisition and physical-session
validation. Clone policy performs no JDBC work. Its physical structure signature
includes exact normalized index facts; its recovery transport signature is
unchanged. Reviewed row operations use central native inspection to produce
compact request-owned evidence from the same normalization, identifier rules,
column-evidence extraction and retained-proof finalization used by execution.
Fresh columns and native generation are compared with the original retained
proof; two unchanged cached copies cannot establish current structure.

The current catalog is read only during bounded pure proof/type extraction. No
full snapshot, catalog index, Source or identifier-comparison map survives in the
inspection handle or deferred plan. Its proof revision identifies the captured
catalog/rules/configuration view, not a durable publication of newly observed
native structure. Temporary normalization allocations transfer to the existing
global admission's compact evidence charge until close. Native table structure,
compact proof, selected typed descriptors and scalar ownership fences are the
only retained inspection data.

Private monotonically assigned owned-record tokens distinguish exact immutable
overlay/resolution replacements within one resolution epoch. They are in-memory
bookkeeping only, never persisted or transported as snapshot/context revisions.
Physical, source, context, native-rule, configuration, proof-epoch, request or
captured-view changes fail explicitly before use. Close releases the charge and
captured references. Review, clone and Apply never wait for a private-cache writer
while holding the physical session. Apply still locks the native table and
rechecks the fresh strong signature and retained witness before mutation.

Index fingerprint input carries `index-shape-v2`. This changes only affected
INDEX fingerprints, so an incremental refresh obtains the new NULL/key/state
facts even when server DDL did not change. Rebuildable cache schema 5 and user-data
schema 4 are independent of index normalization. The current strict protocol is
15; its ownership envelopes do not change the cache format. Restored cache
coverage remains STALE;
missing versioned index facts cannot authorize cloning or acquire a presumed
NULL policy. All existing object, row, byte and acquisition deadlines apply.

The published model's source/configuration and physical-session response fences
are detailed in [metadata revision ownership](metadata_revision_ownership.md).
The rebuildable source cache admits at most eight sources. An active physical
console or independent metadata owner pins its existing Source with bounded weak
owner references until physical close; logical overlay retirement does not
unpin a live session. Eviction rechecks physical owners and active writer,
external-mutation, overlay and pending-cache ownership before removing a source.
Capacity pressure is explicit and cannot reset an active source's revision clock.
