# Database verification matrix

| Engine | Verification target | Pinned JDBC driver | Evidence |
| --- | --- | --- | --- |
| PostgreSQL | 17.11 | pgJDBC 42.7.13 | DatabaseIT, DatabaseTlsIT, PerformanceIT and real desktop fixture |
| MySQL | 8.4.10 LTS | Connector/J 26.7.0 | DatabaseIT and DatabaseTlsIT |
| MariaDB | 11.8.9 LTS | Connector/J 3.5.10 | DatabaseIT and DatabaseTlsIT |

These are the initial narrow verification targets, not blanket certification of
all tools or server versions. Other majors are unverified. SQLite is Java's
internal metadata store, without a user connector. Administration uses real
catalogs/statistics and reports permission/unsupported errors instead of fabricated
metrics. **Commands → Connection capabilities** explicitly inspects the live
server version, available plan syntax, visible catalogs and instrumentation on an
independent read-only connection. Its scoped results distinguish denial, missing
instrumentation/catalogs, empty visible data and profile-disabled modifications.
Limited visibility is explicit; a successful probe is not an effective-permission
calculation or authorization for another object/action.

The real Docker matrix checks physical-session temporary objects; direct BEGIN/
ROLLBACK; failed PostgreSQL transactions; MySQL/MariaDB implicit DDL commits;
responsive status during execution; streaming preservation of direct-SQL
transactions; cancellation races and reuse; duplicate execution IDs; exact decimals/NULL,
signed/unsigned extremes, wide BIT, bytes, Unicode, local/offset temporals and
PostgreSQL arrays/infinity; exact typed SQL-copy→insert round trips including
booleans, bytes, decimals, Unicode/backslashes/quotes and temporal values;
composite-key optimistic editing, retained-source provenance, forged-row/join
rejection, optimistic conflicts, generated columns
and default-only inserts; catalog inspection;
column migration introspect→diff→apply→re-introspect; full large-cell CSV/JSON
exports; CSV/JSON/NDJSON preview/mapping/import and conversion rollback;
grant/revoke and role-membership review/apply/re-inspection with quoted Unicode
principals; PostgreSQL schema/database grants; MySQL/MariaDB database-name wildcard
isolation including MySQL partial_revokes mode; password-free privilege inspection;
server rejection of LOAD DATA LOCAL even with server local_infile enabled; native close
review of a real transaction in another SQL tab;
read-only enforcement; server loss during a write and blocked uncertain-session
reuse; retained export after disconnection. TLS fixtures exercise Driver default negotiation, Require rejection of non-TLS
endpoints, Verify CA without hostname checking, Full Verification rejection of
bad CA/hostnames, and selected client certificates for all three adapters. These
explicit policies do not make fresh Driver default profiles universally verified.

Additional hardening tests apply alias-swap edits and verify durable rows, queued cancellation and transaction faults, live USE/search-path/quoting modes, byte-shortened paging and retained lifecycles. Required tests include successful >2GiB export/import checksum round trips and native dump/restore, including partial failure and verified TLS through SSH for supported native transport policies. Ordinary designer and migration tests include independent indexes, composite foreign keys, generated/default/identity columns, table properties, routine/trigger definitions and preserved view security/options/grants. Query/index statistics tests cover actual enabled instrumentation on all three engines and explicit unavailable states. Role inspection includes inherited roles, default activation and documented effective-access limits.


MySQL/MariaDB native dump/restore through SSH uses private local IPC and a
BusyData TLS relay. The relay verifies the original destination under the
reviewed policy before forwarding authentication; required TLS failures stop
the operation. PostgreSQL native SSH retains public host/hostaddr routing.
Clients, resolver imports and upstream binaries remain unmodified. Synthetic
relay peers and Linux policy checks do not certify genuine Windows native
execution or installed-package acceptance; those remain separate required gates.
See [native transport requirements](native_transport_acceptance.md).

The original-size large-transfer fixtures verify all 32,768 rows of 65,536-byte
values and durable imported checksums, with zero remaining result-spool/import-
snapshot charges. Their required aggregation gates depend on the complete
three-engine matrix. Native Linux accessibility exercises real IBus multi-caret
editing/undo, AT-SPI Unicode operations, frame ancestry, modal focus and Orca
speech for editor/grid/plan/designer controls; current-source receipts are required.

Remaining coverage includes broader restart/reconnection permutations, complex dependency cycles, every privilege combination, the full native accessibility/theme/scale matrix, Windows and complete installed-package workflows. Individual driver rows above the supported 8MiB protocol budget fail explicitly and quarantine the interrupted connection; multi-gigabyte individual cells are not supported. Large transfers use many bounded records rather than exceeding this per-record policy. Testcontainers is a test dependency only. Missing Docker
or images fails the required CI stage; mocks do not replace the matrix.

Maintained driver references: [pgJDBC](https://jdbc.postgresql.org/),
[MySQL releases](https://dev.mysql.com/doc/connector-j/en/connector-j-versions.html),
[MariaDB releases](https://mariadb.org/connector-java/all-releases/).
Streaming policy follows [pgJDBC cursor requirements](https://jdbc.postgresql.org/documentation/query/)
and is adapter-specific; see architecture.md.
Privilege drafts follow the engine's own [PostgreSQL GRANT](https://www.postgresql.org/docs/17/sql-grant.html),
[MySQL GRANT](https://dev.mysql.com/doc/refman/8.4/en/grant.html) and
[MariaDB GRANT](https://mariadb.com/docs/server/reference/sql-statements/account-management-sql-statements/grant)
syntax; they do not translate privilege models between engines.

Release hardening retains this matrix and every F1–F12 real-engine regression.
Output finalization changes require fresh ordinary/direct/value export, successful
large transfer and native dump/restore runs; old counts are historical comparisons.
The current immutable verification record is authoritative for exact server versions,
case counts, failures and unavailable installed-platform acceptance. Linux results
are not relabelled as genuine Windows or installed Snap evidence.


## Workbench foundation dialect capabilities

The release/driver pins above remain unchanged. [Metadata](metadata_platform.md),
[language coverage](sql_language_service.md) and [data editing](data_editor.md)
define exact supported behavior and explicit limitations.
The [joined-output matrix](sql_join_resolution.md) and
[expression/type matrix](sql_expression_typing.md) specify column merging,
scope lookup, native truth types, recursive output and SQL-mode differences.

| Feature | PostgreSQL17.11 | MySQL8.4.10 | MariaDB11.8.9 |
| --- | --- | --- | --- |
| Names/structure/source metadata | Native catalogs, JDBC structural evidence | information_schema/JDBC and native source | information_schema/JDBC and native source |
| Incremental introspection | Native scoped identity/structural fingerprints | Native scoped fingerprints; no universal DDL stream claim | Native scoped fingerprints; no universal DDL stream claim |
| Temporary metadata | Physical-session pg_temp inventory and overlay | Exact owned native observations and temporary relation overlay; unknown unenumerated scope is explicit | Owning-session TABLES temporary inventory in11.8 and exact native observations |
| Opaque execution effects | Session resolution epoch plus owned namespace reconciliation | Unknown session inventory; bounded exact physical-table verification | Unknown until bounded owned inventory or exact physical-table verification |
| DDL transaction visibility | Deferred global publication until commit; rollback discards pending structure | Actual implicit commits; temporary exceptions stay session-owned | Actual implicit commits; temporary exceptions stay session-owned |
| RETURNING | INSERT/UPDATE/DELETE | Unsupported | INSERT/DELETE; UPDATE unsupported in11.8 |
| Upsert | ON CONFLICT | ON DUPLICATE KEY UPDATE | ON DUPLICATE KEY UPDATE |
| LATERAL derived sources | Supported core binding | Supported core binding | Explicit unsupported state |
| Explicit DEFAULT assignment | INSERT/UPDATE grammar | INSERT/UPDATE grammar | INSERT/UPDATE grammar |
| Composite related-row predicates | Verified metadata + bound exact values | Verified metadata + bound exact values | Verified metadata + bound exact values |

SQL modes and server-derived case rules belong to captured session context.
PostgreSQL unquoted identifier folding and quoted identity are independent of the
desktop platform. MySQL/MariaDB table and database lookup uses the captured
`lower_case_table_names` initialization setting; column and routine lookup keeps
the engine's separate case rules. `IdentifierCaseModeIT` starts fresh pinned
MySQL and MariaDB fixtures with setting 1 and exercises the same identities
through Explorer, qualified completion, relationships, retained provenance,
reviewed browsing and reviewed Apply. It never changes an existing server's
initialization setting. Setting 2 requires the applicable case-insensitive
filesystem; Linux fixtures on a case-sensitive filesystem do not certify it or
genuine Windows behavior. These distinctions follow the official
[MySQL case rules](https://dev.mysql.com/doc/refman/8.4/en/identifier-case-sensitivity.html)
and [MariaDB case rules](https://mariadb.com/docs/server/reference/sql-structure/sql-language-structure/identifier-case-sensitivity).
The [identifier-domain matrix](identifier_rules.md) distinguishes relation/CTE
aliases, native uniqueness and operation lookup. `NativeIdentifierCaseRulesIT`
uses native SELECT, duplicate controls, DROP and trigger-source observations;
`NativeIdentifierMapProbeIT` and `NativeForeignKeyByteMapProbeIT` independently
check bounded native acquisition. Server filesystem sensitivity is captured,
not inferred from the client OS. MariaDB trigger lookup on a case-insensitive
server filesystem is explicitly unsupported; other object kinds remain usable.

Temporary-name authority has an additional native rendering distinction:

| Temporary exact-name evidence | MySQL 8.4.10 | MariaDB 11.8.9 |
|---|---|---|
| Identifier modes 0/1 | Bounded native CREATE header; SHOW display field is an alias | Bounded native CREATE header or owned temporary inventory |
| Captured ANSI_QUOTES | Double-quoted header identifiers use the same lossless lexer | Double-quoted header identifiers use the same lossless lexer |
| Identifier mode 2 physical classification | Explicit unsupported exact-name evidence; header renders an alias | Explicit unsupported header-name evidence; owned inventory remains a distinct native source |
| Missing/malformed/cut header | Explicit unavailable/limited name, physical reference unproved | Explicit unavailable/limited name, physical reference unproved |

`TemporaryCanonicalNameIT` checks first-reference spelling, level changes, actual
SQL modes and permanent-shadow retirement across the two native engines;
`ColdProcedureTemporaryMetadataIT` retains its initial empty-source setup and
blocked independent refresh. Pure header/physical-classification controls cover
escaped and safe unquoted names, bounded draining, body cuts, cancellation and
unavailable mode-2 authority. The mode-2 rows describe explicit availability,
not acceptance of a native mode-2 host that was unavailable to verification.
Renderer contracts:
[MySQL 8.4.10](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/sql_show.cc#L1833),
[MariaDB 11.8.9](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_show.cc#L2092).

MySQL/MariaDB routine binding also captures `IGNORE_SPACE`; native keyword
calls, quoted names, comments and colliding stored routines use the pinned
engine rules documented in [sql_language_service.md](sql_language_service.md).
`CALL` selects procedures independently of function expressions.
Source visibility and unsupported catalog properties are never inferred from an
empty value. See the primary-source links in the focused architecture documents.

MySQL/MariaDB connections disable `tinyInt1isBit` and `yearIsDateType` so native
TINYINT(1)/BOOLEAN aliases retain their full integer values and YEAR remains an
integer. BIT values retain their native boolean/bit-width handling. This is fixed
adapter conversion policy, not a user driver-option override or dependency change.
See the official [Connector/J type mapping](https://dev.mysql.com/doc/connector-j/en/connector-j-reference-type-conversions.html?ff=nopfpls)
and [MariaDB mapping flags](https://mariadb.com/docs/connectors/mariadb-connector-j/about-mariadb-connector-j#tinyint1isbit).

Native lexical contracts use six ASCII SQL whitespace characters. Unicode
identifier characters such as U+2002 are retained as identifier contents.
PostgreSQL UTF-8 identifiers and dollar tags accept non-ASCII Unicode scalars;
MySQL/MariaDB identifiers are limited to the BMP and may start with digits when
they are not numeric literals. The execution splitter and editor scanners share
only these character facts and have separate selection/formatting regressions.
Primary contracts: [PostgreSQL 17 scanner](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/parser/scan.l),
[MySQL 8.4 identifiers](https://dev.mysql.com/doc/refman/8.4/en/identifiers.html),
and [MariaDB identifiers](https://mariadb.com/docs/server/reference/sql-structure/sql-language-structure/identifier-names).

| Exact TIME assignment | PostgreSQL 17 | MySQL 8.4 | MariaDB 11.8 |
| --- | --- | --- | --- |
| Native range | Clock time through 24:00:00 | Signed duration through ±838:59:59.000000 | Signed duration through ±838:59:59.999999 |

Pre-review conversion rejects values outside the applicable native range and
precision. It does not depend on server clipping or non-strict SQL modes. See
[data_editor.md](data_editor.md) for the primary type references and exact
assignment/optimistic-verification contracts.


Clone planning uses native unique-index evidence independently of nonnullable
editable row identity:

| Clone fact | PostgreSQL 17.11 | MySQL 8.4.10 | MariaDB 11.8.9 |
| --- | --- | --- | --- |
| Constraint kind | Native `p`/`u` through shared kind mapping | PRIMARY KEY / UNIQUE | PRIMARY KEY / UNIQUE |
| Nullable unique key | `indnullsnotdistinct` selects DISTINCT or NOT DISTINCT | DISTINCT NULLs | DISTINCT NULLs |
| Standalone unique index | Included as an index, without inventing a constraint | Native STATISTICS identity | Native STATISTICS identity |
| Included attributes | `indnkeyatts` separates keys from INCLUDE | Not applicable | Not applicable |
| Functional/partial unique cloning | Explicitly unsupported | Functional key parts explicitly unsupported; partial indexes not applicable | Computed unique columns require a verified plain DISTINCT NULL witness |
| Unavailable or incomplete key facts | Explicit incomplete/unsupported result; no generated mutation | Same | Same |

PostgreSQL index states and NULL equality follow
[pg_index](https://www.postgresql.org/docs/17/catalog-pg-index.html) and
[CREATE INDEX](https://www.postgresql.org/docs/17/sql-createindex.html).
MySQL/MariaDB key components and DISTINCT NULL behavior follow
[MySQL STATISTICS](https://dev.mysql.com/doc/refman/8.4/en/information-schema-statistics-table.html),
[MySQL UNIQUE indexes](https://dev.mysql.com/doc/refman/8.4/en/create-index.html#unique-indexes),
[MariaDB STATISTICS](https://mariadb.com/docs/server/reference/system-tables/information-schema/information-schema-tables/information-schema-statistics-table),
and [MariaDB UNIQUE](https://mariadb.com/docs/server/server-usage/tables/create-table#unique).

The shared [metadata response ownership](metadata_revision_ownership.md) contract
applies to all three pinned engines. `SessionContextIT`, `SessionAdoptionIT` and
`SessionCleanupIT` verify Java-issued source identities through independent
namespaces, adoption and terminal acknowledgement. `MetadataRpcOwnershipIT` and
`RelatedRowsOwnershipIT` verify typed refusal before database access;
`MetadataActiveSourceOwnershipIT` keeps a live source's clock stable while closed
sources churn through the bounded cache. These ownership cases complement the
native catalog, transaction, temporary-object and foreign-key tests; they do not
turn synthetic catalog fixtures into live-engine catalog acceptance.
