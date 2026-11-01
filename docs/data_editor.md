# Data Editor state and retained-data operations

The data editor is a presentation of a Java-owned retained result. Flutter does
not query JDBC, infer keys from labels, construct related-row SQL, or apply a
mutation when a view changes. The workbench's physical session, reviewed change
plan, explicit Apply, transaction and private recovery contracts still apply.

`ResultViewState` owns `ResultPresentationState`, selection, the current paging
window, column visibility and widths. The result/view mapping in `WorkbenchModel`
continues to map visible rows to retained source rows. `ResultPresentationHost`
passes the same readers, source mapping and staging callbacks to all presentations.
No alternate view keeps an editable copy of a result or rereads the original SQL.
`result_extractors.dart` contains the existing bounded exact fetched-data copy
contract; changing display formats does not change it.

Each data cell exposes a `busydata.result.cell.v1:` accessibility identifier
followed by a compact JSON array of the owning document ID, backend source-result
ID, displayed result or retained-view ID, zero-based visible row index and column
index. Headers omit this identifier. A local retained view can change the display
ID while preserving its source-result ID; a fresh backend result has a new source
ID. These opaque handles contain no SQL, cell values or display names and grant
no authority to edit or execute. The [owned native bridge](native_accessibility_bridge.md)
forwards this identifier as the native accessible ID and `id` attribute.

Table retains its two-dimensional virtualized `TableView`. Transpose exchanges
its visible field/row axes and virtualizes wide results; it shows at most 32
selected source rows and explicitly identifies a larger selection. Tree starts
with the current retained window's collapsed rows. Field, JSON and array branches
expand lazily, with a 4,096-entry display budget. Text explicitly chooses the
selection or current retained window, with the same 10,000-cell / 1 MiB encoded
extractor limits as fetched-data copying. SQL text comes from Java's exact SQL-copy
operation; Flutter combines only validated generated tuples. Full results and
large values continue to use the reviewed export pipeline.

Record View is a virtualized field list for the selected visible row. It shares
the grid's source identity, selection and staged assignments, shows native types
and nullability, and distinguishes original values from pending assignments.
Previous/Next follow the visible retained view. Following selection does not
request grid focus. At narrow widths the record fills the available pane; hiding
it exposes the original presentation and its unchanged state.

## Value assignments and recovery

A protobuf `ValueAssignment` carries exactly one of an explicit typed value,
explicit SQL NULL, or explicit server DEFAULT. An unset assignment means no
change (or no supplied insert field). A text value containing `DEFAULT` remains
ordinary text. Update generation emits `column = DEFAULT` only for the explicit
DEFAULT state. Insert omission and explicit DEFAULT remain distinguishable in
review and recovery. Original optimistic-verification values remain `Value`
messages and never acquire assignment intent.

The one-way user-data schema-2 to schema-3 migration atomically converts saved
legacy assignments to this format. It preserves existing drafts and has no
alternate runtime decoder. Optional `StoredEditDraft` fields 10 and 11 retain
original timestamp timezone facts; older records do not receive guessed values.
Recovery signatures retain the pinned driver's original `getColumns` facts before
native structural enrichment. MySQL/MariaDB acquire those facts on an independent
metadata view, temporarily masking only `NO_BACKSLASH_ESCAPES` there for exact
escaped metadata patterns and restoring the actual mode afterward. A restoration
failure disposes that view. The console SQL mode and transaction are untouched;
there is no alternate recovery signature or execution of the source query.

Inline editing, Record View, Value Editor and the staged-insert editor submit the
same `OwnedEditBatch` operations. Reverting an assignment compares its explicit
value with the original retained value; DEFAULT cannot disappear because the
original value happened to be NULL. Staging and recovery have their existing
shared byte/count limits, and Java validates column ownership and typed input.
Explicit draft rebinding obtains its current compact inspection proof from the
saved verified projection, checks the durable recovery signature and captured
timestamp/array context, and creates a new MariaDB witness through the shared
native preparation path. It does not depend on an incidental metadata cache
publication, warm an entire source, or execute the original SELECT. Failed rebind
preserves the saved record and intentions.

Failed validation or recovery preserves the in-memory intention. Applying,
committed or unknown-outcome batches cannot be changed or replayed implicitly.

Clone Row asks Java for a staged insert after retained provenance and central
metadata validation. The central native table structure supplies every visible
unique index, including standalone indexes. PostgreSQL constraint kinds retain
their native `p`/`u` identities and use the shared constraint-kind mapping.
Generated and identity columns and non-NULL unique key components are left unset.
An exact NULL is preserved for a unique key only when its captured native policy
is NULLS DISTINCT. PostgreSQL NULLS NOT DISTINCT keys leave the NULL assignment
unset. Ordinary fields and their explicit NULL values remain exact.

Index key attributes and INCLUDE attributes have separate metadata ordinals;
INCLUDE fields remain ordinary cloned data. Primary-key, generated and identity
values remain unset. The editable row-identity model is unchanged. Expression,
partial, invalid or incompletely described unique indexes return a structured
unavailable/unsupported reason. A computed unique key requires a preserved plain
NULL component under verified DISTINCT semantics; BusyData does not evaluate a
generated expression to invent a replacement. These checks execute no SQL and
consume the same centrally inspected structure used by reviewed edits.

Server defaults run for omitted assignments through the existing reviewed insert
pipeline. The user can supply a new key before Apply; cloning does not resolve a
server conflict or replay an operation. Failed intentions remain available. The native
staged-insert editor exposes each permitted assignment before Apply. Existing
staged inserts can be reopened through the same command. Replacing a staged
insert validates its batch revision and uses the same shared staging budget.
If saving a provisional insert fails, correction and retry replace that same
intention instead of appending another insert. Cancellation leaves the intention
available for explicit review or discard; it does not execute SQL.

## Typed review and optimistic verification

MySQL and MariaDB ENUM/SET labels are decoded from the pinned servers' canonical
native column declaration. Reviews retain the chosen exact labels; assignment
parameters bind the verified ENUM ordinal or SET bit mask. This preserves a
selected member even when the column collation treats distinct labels as equal.
Java does not reproduce database collation rules. Declarations with identical
labels, declared empty members, ambiguous SET separators, unavailable native
declarations or excessive member counts cannot prove retained value identity and
remain explicitly unavailable for editing that projection. Numeric-looking
labels are never interpreted as user-supplied ordinal shortcuts.
The native contracts are documented in
[MySQL ENUM](https://dev.mysql.com/doc/refman/8.4/en/enum.html),
[MySQL SET](https://dev.mysql.com/doc/refman/8.4/en/set.html),
[MariaDB ENUM](https://mariadb.com/docs/server/reference/data-types/string-data-types/enum)
and [MariaDB SET](https://mariadb.com/docs/server/reference/data-types/string-data-types/set-data-type).

Before issuing a change approval, `ChangePlanner` converts supplied values through
`EditValues` using the captured central column descriptor and shared `SqlTypes`.
The conversion performs no JDBC work. The owning reviewed operation receives a
bounded compact inspection proof from the central metadata platform. Fresh native
table and column evidence is compared with the original retained proof without
publishing it globally or waiting for the private cache writer. The current
catalog is used only during pure extraction; no catalog generation escapes in an
inspection or deferred plan. The request keeps its compact evidence admission
until completion; approvals and recovery retain only their existing compact
evidence. Integer widths and signedness use exact
`BigInteger` ranges; decimal precision/scale use `BigDecimal` without rounding.
Exponent and expanded-digit budgets are checked before allocating a plain decimal
string. A text field never delegates numeric validation to driver conversion at
Apply. NULL, DEFAULT and omission remain separate assignment states.

ISO temporal conversion preserves the distinction between local and offset values,
checks precision without rounding, and keeps PostgreSQL `24:00:00` and MySQL/MariaDB
negative or multi-day TIME values. Engine endpoint rules differ: MySQL TIME ends
at `838:59:59.000000`; MariaDB permits `838:59:59.999999`. Timestamp boundary inputs
require a verified session offset; unsupported extremes and unverified native type
constraints are reported explicitly. These rules follow the official
[PostgreSQL temporal contract](https://www.postgresql.org/docs/17/datatype-datetime.html),
[MySQL TIME contract](https://dev.mysql.com/doc/refman/8.4/en/time.html) and
[MariaDB TIME contract](https://mariadb.com/docs/server/reference/data-types/date-and-time-data-types/time).

Retained PostgreSQL dates and timestamps use Java's proleptic ISO year numbering.
SQL copy converts year zero and negative years to an unsigned native year with a
`BC` suffix after the complete time/offset, and removes the ISO leading `+` from
extended positive years. The retained value stays unchanged. If the pinned
driver cannot decode a valid native BC leap day through Java time, retention
keeps the exact native text and type instead. New BC assignments remain explicitly
unsupported by the typed editor validator. This follows PostgreSQL's
[calendar input rules](https://www.postgresql.org/docs/17/datetime-input-rules.html)
and the pinned driver's [Java-time era conversion](https://github.com/pgjdbc/pgjdbc/blob/REL42.7.13/pgjdbc/src/main/java/org/postgresql/jdbc/TimestampUtils.java).

MySQL and MariaDB TIMESTAMP originals also carry their captured session timezone
interpretation in the retained metadata proof. Verification requires the same
proven fixed UTC offset; `SYSTEM` is accepted only when its native system zone
reports UTC. Named or DST-dependent zones remain explicitly unsupported for
timestamp editing. Changing `time_zone` advances the session context revision
and cannot make a different stored instant match an older wall-clock value.
Recovery stores both native timezone facts. Older timestamp drafts lacking them
remain preserved and unavailable for rebind; BusyData never guesses historical
interpretation. DATE, TIME and DATETIME do not acquire timezone semantics.
The conversion distinction follows [MySQL timezone support](https://dev.mysql.com/doc/refman/8.4/en/time-zone-support.html)
and [MariaDB TIMESTAMP](https://mariadb.com/docs/server/reference/data-types/date-and-time-data-types/timestamp).

MariaDB also requires a server-prepared zero-row metadata witness captured before
the source query, in addition to visible native InnoDB table identity. Revalidation
checks the native reprepare counter under physical-session ownership. A changed
table definition, unavailable witness or ended session leaves retained values
inspectable but editing unavailable. At most 96 active/closing witnesses share
the result/job lifecycle. Explicit recovery rebind prepares a new generated
observer after schema/timezone verification; it never replays the original SQL.
The witness is not a persistable column-lifetime identity.

JSON validation is bounded to 64 levels, 65,536 nodes and the shared value budget;
raw text, number lexemes and duplicate members are retained. Malformed values,
overflows, unsupported conversions and missing type evidence fail before approval
with a fixed diagnostic code that excludes sensitive input. Failed intentions stay
available for correction. Exact retained arrays can be cloned only with their
original bounded native representation and verified PostgreSQL array type identity;
no array SQL is reconstructed from a display tree. Modified opaque engine values
require an explicit supported conversion; type-name similarity does not authorize a
cast of a user-defined type.

The Value Editor can also stage a PostgreSQL array's native literal as text.
Java validates structure and every element against the same central native type
and scalar conversion rules, and exposes the typed array in Review. Supported
new elements are builtin integers, exact numeric and finite floating values,
text/character values, booleans, UUIDs, canonical ISO temporal values, JSON/JSONB
and hexadecimal bytea. Native element OID, namespace, kind and delimiter must
match the captured catalog. Domains, custom/composite types and non-comma
delimiters remain explicitly unsupported for new input; retained original proof
is still required for opaque cloning. Literal parsing never executes SQL.
Bounds, dimensions, quoted/escaped text, empty strings and NULL remain distinct.
The source ceiling is 16 Ki UTF-16 units, scalar count is 1,024, native dimension
count is six and aggregate typed expansion is bounded to 1 MiB. Ragged dimensions,
invalid scalars and exhausted budgets fail before approval and keep the draft.
These rules follow PostgreSQL's [array input contract](https://www.postgresql.org/docs/17/arrays.html)
and the pinned [native dimension limit](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/include/utils/array.h).
Native text array parameters require captured `array_nulls=on`; datetime arrays
also require ISO DateStyle. Those settings are checked again during binding.
Binary native arrays have their own typed NULL bitmap. Historical datetime-array
drafts are validated as unambiguous ISO native text before rebind; an ambiguous
literal remains preserved and unavailable. The pinned pgJDBC driver itself
rejects a non-ISO DateStyle change by [closing its connection](https://github.com/pgjdbc/pgjdbc/blob/REL42.7.13/pgjdbc/src/main/java/org/postgresql/core/v3/QueryExecutorImpl.java); BusyData reports
that native incompatibility and quarantines the owner without retrying SQL.

Optimistic row checks compare textual originals by their exact UTF-8 database
representation, rather than a possibly case-insensitive collation. `RowVerification`
uses PostgreSQL native output through `format('%s', column)` and `convert_to`, or
MySQL/MariaDB `CAST(CONVERT(column USING utf8mb4) AS BINARY)`, with a bound byte
parameter. This preserves PostgreSQL fixed-character padding and allows JSON/XML
verification without inventing equality operators. PostgreSQL arrays format both
the current column and the bound original native array; NULL uses `IS NULL`, and
other scalar types keep typed equality. A case-only concurrent textual change
therefore fails optimistic verification instead of being overwritten. Identifiers
must already be verified/quoted, and incomplete original values cannot authorize
an update. MySQL/MariaDB ENUM and SET changes are validated against the verified
canonical native declaration. Review/recovery retain labels; JDBC binds the exact
ENUM ordinal or unsigned SET mask so collation cannot substitute a differently
cased declared member. SET text must already follow declaration order, without
duplicates or unknown members. Declarations with ambiguous empty/identical members
are explicitly unavailable for retained editing. These rules follow the official
[MySQL ENUM](https://dev.mysql.com/doc/refman/8.4/en/enum.html),
[MySQL SET](https://dev.mysql.com/doc/refman/8.4/en/set.html),
[MariaDB ENUM](https://mariadb.com/docs/server/reference/data-types/string-data-types/enum)
and [MariaDB SET](https://mariadb.com/docs/server/reference/data-types/string-data-types/set-data-type)
contracts. The primary optimistic-comparison contracts are PostgreSQL
[`format`](https://www.postgresql.org/docs/17/functions-string.html#FUNCTIONS-STRING-FORMAT),
[`convert_to`](https://www.postgresql.org/docs/17/functions-binarystring.html), the
[pinned PostgreSQL native-output implementation](https://github.com/postgres/postgres/blob/REL_17_11/src/backend/utils/adt/varlena.c),
[MySQL casts](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html) and
[MariaDB conversion](https://mariadb.com/docs/server/reference/sql-functions/string-functions/convert).

## Value Editor limits and interpretations

`ValueDocument` retains one 64 KiB byte page. Loading another page is explicit,
cancellable and bound to the captured backend, result/value and document/session
owner. Stale responses are rejected before display. No LOB is loaded completely
without a bounded user operation. Full-value export keeps the existing native
picker, destination review and Java-owned exact-byte pipeline.

The native **Value actions** menu contains **Copy displayed text**, **Load next
64 KiB**, **Reset value preview**, **Edit complete value**, **Add editing page**,
**Set NULL** and **Set DEFAULT**. **Stage change** and previous/next page controls
remain primary visible actions. A cached complete draft resumes when **Edit** is
switched off and on or the editor is reopened; it does not reacquire the original
value over the user's retained edits.

**Edit complete value** explicitly acquires a retained TEXT, JSON or binary value
through the same 64KiB owner-checked chunks. Admission is at most 1MiB and 262,144
UTF-16 units for text, with at most 32 chunk replies and a ten-second operation
deadline. Cancellation/supersession discards incomplete acquisition; malformed
UTF-8 is rejected rather than replaced. Java still validates and stages the exact
typed assignment. Values beyond these bounds remain inspectable/exportable.
Review and recovery share a separate 1MiB aggregate budget for server-retained
originals, canonical replacements and their request overhead. Java alone resolves
the original cell IDs, verifies their retained owner, byte count and exact prefix,
then reads bounded chunks with cancellation and strict UTF-8 checks. Recovery
stores verified complete originals; explicit rebind restores bounded previews and
new private cell IDs before appending rows, preserving the 256KiB row-spool limit.
The source result remains unchanged and the source SQL is never replayed.
The current editable text-page status sits outside the independently scrollable
options and action regions, immediately above the paging actions. It remains
visible when the value field takes focus or full-export actions wrap at large
text sizes. This is the existing draft's page index, not a separate paging model.

Complete text editing exposes at most 16,384 UTF-16 units in the active native
field, without splitting a surrogate pair; its UTF-8 input budget is 49,152 bytes.
A `TextValueDraft` keeps the complete exact String and at most 18 logical pages.
Ordinary edits and previous/next navigation preserve page boundaries, including
empty pages, and every untouched prefix and suffix. **Add editing page** may
repack a fragmented page index only on that explicit action, then exposes a
vacant last page. Presentation fragmentation cannot reduce the whole-value
admission limit. Staging submits the complete String, and presentation recovery
continues to retain that String without a new storage format. Undo applies to the
active native page and resets when changing pages; the full draft stays retained.
Oversized, malformed UTF-16 or NUL-containing native input is rejected before
listeners/renderers see it, preserving the previous text, selection and IME state.

Binary editing retains one bounded byte buffer and one editable 16KiB byte page,
represented by at most 32,768 hexadecimal characters. Navigation validates the
page before moving, preserves untouched bytes and uses copy-on-write snapshots
when applying a page. **Add editing page** requires the complete value's end to
be 16KiB-aligned and below the 1MiB limit; a partial last page must be filled first.
The action opens an empty aligned window without padding or adding any bytes.
Previous returns to the last actual page, and failed input and empty-window
snapshots retain the same offset/byte recovery shape. Failed page input survives
closing/reopening while its result owner exists, without another automatic read.
An asynchronous staging reply cannot discard text entered afterward; the newer
draft remains visible for another explicit stage action.

Read-only inspection of already retained previews remains available without a
backend; chunk retrieval, export and staging require their live owner. Raw,
formatted JSON/XML, hexadecimal and Text presentations expose the represented
String through surrogate-safe pages of at most 16,384 UTF-16 units.
Value Editor uses a smaller 8,192-unit read-only native window to bound paragraph
layout independently of its 64 KiB retained byte chunk. Full displayed-text copy
still covers the represented value, and the independently staged editing pages
retain their own limits. The release inspection workload visits every native
window for the same complete 64 KiB chunk rather than inspecting fewer bytes.
The represented read-only scope is bounded to 2,097,152 UTF-16 units; a larger scope reports an
explicit limit. Paging changes neither its retained source nor the named
copy/export scope. A selection within a native text page covers that page's
selected characters. NUL-containing text remains read-only in native fields and
is inspectable through explicit UTF-8 hexadecimal/Base64 presentations; exact raw
export remains available. Its underlying retained String is never escaped or
rewritten to fit a native field.

Read-only pages use the shared native technical text style. Moving between pages
retains the native selection field and its render/gesture owners, clears the old
selection and toolbar, and reveals the start before changing the represented
page. The reset also applies to equal-text pages and replacement values, without
requesting focus from another control. The viewport keeps its native field when
page controls appear or disappear after a display-format or scope change.
The unchanged adaptive selection toolbar
is [parented to the field's focus owner](https://api.flutter.dev/flutter/widgets/Focus/parentNode.html),
so keyboard Copy retains the selection; Tab can leave the toolbar and moving to
another control dismisses it. Hexadecimal display uses one bounded
ASCII buffer for at most the existing 1MiB complete-value limit; it rejects invalid
bytes or a larger scope instead of narrowing or truncating the source.

Exact text/CSV clipboard actions and **Copy displayed text** refuse embedded
NUL before writing to the native clipboard. Rejection preserves the previous
clipboard and all retained source values. Choose explicit JSON copy for an
escaped representation, or export exact raw bytes. The existing clipboard ceiling
remains 1MiB of UTF-8, including the selected extractor's encoding overhead.

These presentation bounds account for the pinned
[Flutter Linux accessibility field's use of `GtkEntryBuffer`](https://github.com/flutter/flutter/blob/af7e796e161ae0bb1ff0758c71a7105418bd9ded/engine/src/flutter/shell/platform/linux/fl_accessible_text_field.cc#L225)
and [GTK's native buffer contract](https://docs.gtk.org/gtk3/class.EntryBuffer.html).
The SDK and native engine implementation remain unchanged.
Raw text remains available when an interpretation fails. JSON display parses at
most 256 Ki UTF-16 units, 4,096 nodes and 32 levels. Numeric tokens remain source
slices rather than Dart floating-point numbers; duplicate keys remain visible.
JSON pretty printing and tree inspection are display operations. XML
interpretation is bounded and refuses external DTD/entity declarations; it does
not load external resources. Binary has explicit hexadecimal, Base64 and 16-byte
UUID presentations, with exact-byte editing. Array inspection uses retained typed
elements rather than reparsing database array syntax.
CSV/TSV and JSON/NDJSON export preserve retained native array text; JSON formats
encode it as a string rather than a list that would lose native dimensions and
bounds. Binary-only arrays remain inspectable through their structured preview
but cannot be converted to exact text offline. Such exports fail atomically and
require an explicitly reviewed server-side textual projection.

Image preview recognizes PNG, JPEG and GIF bytes, rather than filenames or MIME
claims. Admission requires at most 1 MiB encoded bytes, dimensions no larger than
4,096 on either axis and at most 4,194,304 pixels. The decoder requests at most a
1,024-pixel display dimension and retains one frame; decoded images/codecs are
disposed when replaced or closed. Unsupported or invalid data keeps its raw form.

Unstaged Value Editor drafts are presentation-owned and bounded to 16 cells,
256 Ki UTF-16 units per text field and 512 Ki text units across a result view.
Complete binary buffers plus their active page text share a combined
2MiB ceiling with those text drafts; each byte buffer remains at most 1MiB. Their binary
interpretation is retained with their text so reopening Base64 never treats it as
hexadecimal. Oversized text edits are refused before notifying renderers,
preserving the previous text and selection rather than shortening input. Failed
drafts remain available while the result/view owner exists.
Staged intentions use the existing Java-verified private recovery records.

## Aggregates, relationships and operation scope

Aggregate View sends an explicit retained result/view row range and one-based
result-column positions to Java. Result positions are separate from base-table
column ordinals. Counts, NULL counts and exact numeric aggregates operate on
original retained values, excluding staged edits. Per-column availability explains
unsupported types or combinations. A partial snapshot is labelled and never
claims to be a complete server table. Closing/cancelling the aggregate cancels
its independent request. Text minimum/maximum use retained UTF-16 ordinal
ordering, with a visible notice that database collation is not applied. Mixed
or unsupported types have localized availability messages rather than fabricated
numeric results.

Related Rows requires the source's immutable metadata proof captured before
execution. The current snapshot must match its physical relation generation and
exact column evidence. Later introspection cannot grant relationship semantics to
an unproven old result; an external same-name table replacement makes the old
source stale and requires a fresh result.
Related Rows uses central metadata's incoming/outgoing relationships. Java owns
composite key predicates, typed parameters, namespace quoting and relationship
identity. A reply admits at most 128 relationships and 512KiB including its
stamped ownership header and protobuf framing. Exceeding either budget returns
`relationship-budget-exceeded` with no relationship choices; the UI uses its
existing localized limit message. It never presents a silently partial list.
NULL-key and unavailable relationships cannot be invoked. The UI captures
the source result/row and physical session, then reviews Java's returned browse
operation after an explicit relationship choice. The normal table-data document
retains relationship/source provenance and shares the named physical session only
after that review. The metadata snapshot/object identity remains bound through
review and submission. A different PostgreSQL catalog is never assigned to the
source session. Missing projected keys, NULL keys, denied metadata and stale
source evidence have localized actionable states. An unavailable backend disables
aggregate/relationship/clone commands and leaves retained raw previews inspectable;
it never opens a connection or retries SQL automatically.

Open Data, Open SQL and table Refresh share one explicit central target
preparation. Live Explorer/SQL selections carry ephemeral server object identity,
snapshot/configuration and physical-owner proof; logical document identity and
restored hints remain presentation state. A newly unbound data document may share
only the explicitly selected live matching-profile session. An already-bound
mismatch is rejected, and a restored name-only hint requires explicit connection
and metadata resolution. Preparation enriches the exact relation and columns at
Structure level before Review; changing owner or revision rejects the operation
without replacing retained rows or staged drafts. TABLE, VIEW and PostgreSQL
materialized-view browsing use the same contract; views remain noneditable.

Table-data sorting/filtering is explicitly server-side and uses the reviewed
browse operation. Retained query sorting/filtering is explicitly local and never
reruns source SQL. Headers, cell-value actions and dialogs use the same column
reference contract: a retained column position (`#1`, `#2`, …), or the captured
base-column identifier for a reviewed table browse. Duplicate display labels and
labels resembling ordinal references cannot retarget the selected column.
Every presentation, Record View and editing operation retains
the local view's source-row mapping. Partial retained results carry their existing
limitation state.

## Display preferences and current limits

Column presentation preferences use the owning profile ID and Java's captured
physical-column metadata identity, with a positive metadata snapshot revision.
Display labels and catalog/schema/table/column spelling do not form the key.
Renaming an object preserves preferences when its verified physical identity
remains stable; a replacement identity receives separate settings. Names-only or
unknown expression provenance uses transient result-local preferences. MariaDB
columns also remain transient because their prepared witness does not establish
a persistent column identity. The existing Flutter-owned presentation file
retains the preferences under its shared 64 KiB limit; the display map admits at
most 128 entries / 16 KiB. Canonical, grouping, exact fixed-scale presets, JSON,
hexadecimal, Base64, UUID, wrapping and temporal date/time/UTC/local presets affect
presentation only. Fixed-scale display rounds decimal digits with arbitrary-size
integer arithmetic. UTC/local conversion requires an explicit ISO offset; a
local timestamp is never assigned an invented timezone. Equality, filtering,
sorting, staging, generated SQL and default copy/export continue to use original
exact values.

Custom temporal patterns use the pinned `intl` calendar-field grammar, with
balanced quoted literals, at most 128 UTF-16 units/512 UTF-8 bytes and six
fractional-second digits. BusyData combines exact millisecond/microsecond fields
for `S` output instead of inventing lower digits. Source, UTC and local timezone
choices are stored in the same stable-column preference value. UTC/local require
an explicit retained ISO offset; unsupported calendar values remain raw. Zone
letters `z`, `Z` and `v` are unsupported by the pinned formatter; timezone
presentation uses the separate native choice. Formatting does not change a
database timezone, type, equality comparison, staged value or export.

Numeric controls retain named scale presets. XML interpretation is a bounded
display subset, not an XML schema validator or an entity-expanding document
processor. Native PostgreSQL array text and raw engine/domain values use the same
typed Java staging path; unknown native types or unsupported conversions retain
their drafts and fail explicitly. Unstaged presentation drafts do not survive backend/result disposal;
stage an intention to put it through private recovery. These limitations are
explicit and do not imply complete P0 or native-platform acceptance.

Cell activation claims grid keyboard focus on pointer-down, before double-click
recognition can delay or replace selection. Table and Record View share selection,
while only the pane that owns primary cell focus exposes a focused cell. Record
navigation does not redirect focus to the grid while its button remains enabled;
boundary buttons expose their disabled state. Value dialogs preserve accessible input
names on both adapters, and the temporal format form scrolls within its bounded
modal at larger text scales.

The focused widget fixtures exercise both native control adapters, LTR/RTL,
high contrast/reduced motion and 100%, 150% and 200% text scaling. The Value Editor
and temporal dialog matrices check keyboard opening, accessible field names,
validation focus, exact staging and trigger focus restoration. Shared presentation
fixtures additionally check transposed keyboard selection and Record View controls.
The ordinary Linux AT-SPI tour exercises the four presentations, Record View,
typed Value Editor staging, aggregate scope, staged cloning with explicit discard,
reviewed related-row browsing, custom temporal display with exact clipboard copy,
and explicit chunk/complete-value editing. It reacquires the exact document owner
and independently verifies unchanged durable fixture rows after staging/discard.
The release fixture measures actual rendered presentation switches over its
million-row result and bounded Value Editor hex inspection of a 64KiB retained
chunk from a 6MB value through native text pages. It verifies stable source mapping, selection and unstaged drafts,
no new execution jobs, unchanged retained bytes and the existing bounded row cache.
These measured phases retain the global frame/RSS gates and additionally bound
Flutter resident growth to 64MiB and combined resident growth to 96MiB per phase.
Installed strict-Snap fixtures exercise exact complete text/binary transport,
retained aggregates, staged clone review and reviewed related-row browsing through
the installed private protocol on all supported engines. They do not
substitute for real AT-SPI, genuine Windows, installed strict-Snap, live-engine or
release performance gates. Required commands and evidence rules remain in
[development.md](development.md).

Workflow references are the official [DataGrip data editor documentation](https://www.jetbrains.com/help/datagrip/data-editor-and-viewer.html).
Presentation implementation follows the pinned SDK contracts for
[Dart BigInt](https://api.dart.dev/dart-core/BigInt-class.html),
[ISO DateTime parsing](https://api.dart.dev/dart-core/DateTime/parse.html) and
[Flutter image codecs](https://api.flutter.dev/flutter/dart-ui/instantiateImageCodec.html).
Exact fraction presentation follows [DateTime.microsecond](https://api.dart.dev/dart-core/DateTime/microsecond.html);
complete text acquisition uses strict [UTF-8 decoding](https://api.dart.dev/dart-convert/Utf8Decoder-class.html).
These references do not authorize database operations or override BusyData's
retention, transaction, review and recovery contracts.


Clone uniqueness follows the supported engine manuals:
[PostgreSQL unique indexes](https://www.postgresql.org/docs/17/indexes-unique.html),
[PostgreSQL index key and INCLUDE metadata](https://www.postgresql.org/docs/17/catalog-pg-index.html),
[MySQL 8.4 unique indexes](https://dev.mysql.com/doc/refman/8.4/en/create-index.html#unique-indexes),
and [MariaDB UNIQUE](https://mariadb.com/docs/server/server-usage/tables/create-table#unique).

Related-row choices retain the full protocol 15 metadata
owner/source/configuration stamp. Any accepted source configuration change
fences other consoles of that source; a late choice or review cannot reopen an
browse operation in an older configuration. Disconnected retained documents do
not create a new session implicitly. See [metadata revision
ownership](metadata_revision_ownership.md) for the domain and stale-response
contract.
