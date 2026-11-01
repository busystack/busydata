# Native identifier rules

Java owns identifier comparison. Explorer, semantic analysis, retained-result
proofs and generated operations consume the same immutable `IdentifierRules`
from a captured metadata snapshot. Display labels and Java Unicode case
conversion are not database identifiers or comparison evidence.

On each physical MySQL/MariaDB connection, before adoption, a bounded header
reads `lower_case_table_names`, the server version and `lower_case_file_system`.
The header belongs to that connection and is immutable. PostgreSQL's supported
UTF-8 scanner policy requires no MySQL-style header. Metadata publication and
proof admission verify the captured rules against the physical header. A cached
model for a different mode, version or filesystem remains inspectable through a
shared unavailable view; it cannot certify binding, absence or editing.

## Comparison domains

Several native operations have different name semantics. A single case-folded
string cannot represent all of them.

| Domain | PostgreSQL UTF-8 | MySQL | MariaDB |
| --- | --- | --- | --- |
| Unquoted identifiers | ASCII lowercase | Object-dependent | Object-dependent |
| Quoted identifiers | Exact | Quoting preserves the object's native policy | Quoting preserves the object's native policy |
| Database/relation names | Scanner result or exact quoted name | Exact in mode 0; legacy native lowercase in modes 1/2 | Exact in mode 0; legacy native lowercase in modes 1/2 |
| Relation aliases | Scanner result or exact quoted name | Exact in mode 0; legacy lowercase otherwise | Exact in mode 0; native Unicode 14 uppercase comparison otherwise |
| CTE names | Scanner result or exact quoted name | Exact in mode 0; legacy lowercase otherwise | Column comparison, independent of table-name mode |
| Columns, output aliases, indexes and CHECK names | Scanner result or exact quoted name | Legacy native lowercase comparison | Native Unicode 14 uppercase comparison |
| Stored routine lookup | Captured search path and exact overload identity | Native `utf8mb3_general_ci` equivalence | Native `utf8mb3_general_ci` equivalence |
| Foreign-key creation uniqueness | Exact native constraint identity | Native `utf8mb3_general_ci` equivalence | Raw UTF-8 bytes compared with `latin1_swedish_ci` |
| Foreign-key DROP lookup | Exact quoted name | Legacy lowercase comparison | Native Unicode 14 uppercase comparison |
| Trigger lookup | Scanner result or exact quoted name | Native dictionary comparison | Exact on the verified case-sensitive server filesystem |

The table-name mode comes from the server. A case-insensitive MariaDB server
filesystem makes trigger lookup explicitly unsupported until its filesystem
comparison can be proven. Exact trigger candidates remain inspectable; other
metadata kinds stay available. Neither a Linux client nor mode 1 proves that the
server's filesystem is case-sensitive. The database verification matrix records
which filesystem/mode combinations have genuine coverage.

Normalized catalog foreign-key lookup uses creation uniqueness; generated DROP
uses `constraintDropKey`. The two operations deliberately have separate APIs.
If multiple exact foreign-key names share one DROP key, quoting cannot establish
which native object will be selected. Generated schema operations refuse that
ambiguity and preserve the original artifacts and drafts.

Constraint type is also part of identity. MySQL can expose a CHECK,
UNIQUE and FOREIGN KEY with the same exact name on one table. Both engines retain the actual
`TABLE_CONSTRAINTS.CONSTRAINT_TYPE` is the normalized identity's signature and
the existing wire `identifier`. Names-only introspection retains it. Component
joins compare exact native names and actual types, and preserve foreign-key
versus unique-key column components separately. Source inspection requires the
selected exact type when a display name is ambiguous.

## Acquiring native evidence

Only independently admitted metadata connections acquire comparison maps.
Completion, diagnostics and parameter information read published maps without
JDBC. Session-local introspection reuses captured evidence and never runs the
map acquisition on an adopted console connection.

The fixed scalar corpus contains the 63,487 non-NUL, non-surrogate BMP values
accepted by the supported MySQL/MariaDB identifier grammar. Public `JSON_TABLE`,
`LOWER`, `UPPER`, explicit collations and a partitioned `MIN` acquire scalar
representatives. MariaDB foreign-key uniqueness additionally acquires a fixed
256-byte equivalence map using `UNHEX`, explicit Latin-1 interpretation and a
verified hexadecimal round trip. No internal weight-string API, copied Unicode
table, dependency patch or per-keystroke catalog query is used.

Acquisition has a shared five-second deadline, cancellation, explicit result
limits with an extra-row sentinel, streaming JDBC reads, exact input/ordinal
checks, scalar cardinality checks, warning refusal and idempotent-map validation.
It rejects missing, extra, transformed or truncated evidence. Native version,
table-name mode and filesystem identity permit reuse of the same immutable
evidence in subsequent acquisitions.

Unavailable native evidence permits provisional name candidates, with explicit
incomplete availability. Provisional ASCII keys cannot certify Unicode
resolution, absence, editability or a generated operation.

## Publication and retention

Rebuildable cache format 5 stores normalized objects and bounded identifier
evidence atomically. Its independently versioned, checksummed evidence codec
validates engine, mode, version, filesystem flag, map lengths, scalar/byte ranges,
idempotence and framing before admission. The encoded evidence is capped at
400,000 bytes. User-data schema 4 is unchanged by this cache migration. The
current strict protocol is 15; its ownership envelopes do not change this codec.

Snapshots, session views and compact execution evidence share immutable map
references. Metadata admission and the one-MiB execution-evidence budget charge
their retained cost. A changed fingerprint disables incremental reuse, rekeys
retained objects, marks unrefreshed coverage stale and retires normalized
session-resolution anchors. Exact temporary identities and drafts survive.
Global rule publication has a ticket fence even when refresh branches do not
overlap; an older refresh cannot restore earlier comparison semantics.

These contracts follow the pinned engines' primary implementation and public
APIs: [PostgreSQL scanner normalization](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/parser/scansup.c),
[MySQL identifier rules](https://dev.mysql.com/doc/refman/8.4/en/identifier-case-sensitivity.html),
[MySQL public JSON table functions](https://dev.mysql.com/doc/refman/8.4/en/json-table-functions.html),
[MySQL UTF-8 comparators](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/strings/ctype-utf8.cc),
[MariaDB identifier comparators](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/lex_ident.h),
[MariaDB foreign-key dictionary](https://github.com/MariaDB/server/blob/mariadb-11.8.9/storage/innobase/dict/dict0crea.cc),
[MariaDB public JSON table functions](https://mariadb.com/docs/server/reference/sql-functions/special-functions/json-functions/json_table),
[MySQL streaming JDBC](https://dev.mysql.com/doc/connector-j/en/connector-j-reference-implementation-notes.html)
and [MariaDB JDBC streaming](https://mariadb.com/docs/connectors/mariadb-connector-j/about-mariadb-connector-j).
