# Schema artifacts

Schema capture exports JSON artifact version 2. Constraint identity consists of
the exact native name and native type. PostgreSQL retains `pg_constraint.contype`;
MySQL and MariaDB retain `TABLE_CONSTRAINTS.CONSTRAINT_TYPE`. Different types can
therefore retain the same name without overwriting their source or components.
Constraint declarations come from the shared actual native constraint reader.
JDBC primary/unique-index evidence still supplies row identity; a standalone
PostgreSQL unique index does not become a fabricated UNIQUE constraint.

Each table's `constraints` object uses the compact JSON encoding of
`[type, name]` as its key. Its value contains exactly `name`, `type`, and
`definition`. For example:

```json
{
  "constraints": {
    "[\"CHECK\",\"shared\"]": {
      "name": "shared",
      "type": "CHECK",
      "definition": "CONSTRAINT `shared` CHECK (`amount` > 0)"
    }
  }
}
```

The key, record and leading native definition name/type must agree. Unsupported
constraint-header grammar is unavailable rather than inferred. There is no separate `constraintKinds`
dictionary. Comparison, designer changes and exact native source lookup use
the same typed records. Exact MySQL/MariaDB constraint requests carry the actual
type in the existing native `identifier`; an ambiguous name without its type
cannot select one sibling arbitrarily. This changes the artifact format, not
the RPC fields or database schema.

Native creation identity and DROP lookup are separate server operations.
Distinct exact foreign-key names can coexist yet match one native DROP lookup.
Migration and designer generation use the captured central operation rules to
reject that ambiguity before producing executable statements; quoting does not
pretend to distinguish those targets. Missing native comparison evidence also
prevents such DROP generation.
Trigger changes also require the captured native trigger capability. MariaDB on
a server reporting a case-insensitive file system does not authorize generated
trigger changes; this decision uses the server header, not the backend host OS.

Version 1 files are migrated in memory when imported for comparison or design.
PostgreSQL's retained name/type maps supply its typed records. For MySQL/MariaDB,
the bounded native CREATE parser reads each leading constraint name and type,
then verifies the surviving legacy constraint/index maps and derived base
statement against the old capture projection. Only after that verification can
the full retained CREATE recover typed siblings that the old name-only map
overwrote. The native CREATE string remains unchanged. The derived base
statement excludes foreign keys by their actual type, and a recovered UNIQUE
constraint is emitted once rather than also being treated as an independent
index.

Missing native evidence, conflicting legacy edits, unsupported leading native
grammar, inconsistent typed keys and resource-limit violations fail explicitly.
Artifact import accepts strict JSON only: object keys must be unique after
escape decoding, names and strings must contain well-formed Unicode, and the
100,000-node admission counts names, scalar values and containers. The existing
input, raw string and nesting limits also apply before Gson builds its tree.
Import never guesses a missing constraint from a name or silently replaces an
edited definition. Preserve the original file and capture fresh native metadata
when its legacy evidence cannot be verified.

Saved external `schema.busydata.json` files are user-owned. Import does not
rewrite them or migrate workspace preferences, SQL history or recovery files.
New captures and designer snapshots use version 2; saving one uses the existing
reviewed native destination and atomic-write path. Schema comparison still
requires matching engines and schemas, retains its byte/object/dependency
limits, reports unsupported changes, and only generates SQL for the ordinary
reviewed execution flow. It never executes or retries that SQL automatically.

Capture and designer inspection share the central metadata reservation and
independent-connection policy. The original profile/session/context/configuration
owner is checked before opening, after acquisition and at publication. The
30-second acquisition budget is checked before and after the existing connection
constructor; it does not preempt that constructor. Opening retains existing
driver/context timeouts and the profile connect timeout, which may be 120 seconds.
Once opened, the independent read scope enforces the remaining acquisition
budget. Ordinary autocommit capture keeps the physical command session available
during cache writer contention; a caller already holding that physical lease is
refused rather than releasing it or waiting on the durable writer. Direct manual
capture requires an already active transaction. With manual mode and `IDLE`
state it returns unavailable before JDBC or lease changes, so catalog reads
cannot implicitly begin a transaction. Active manual capture retains its
physical lease and session-owned visibility, publishes only an owned overlay
and never commits, rolls back or retries SQL. Its native structure/source uses
the owning connection. MySQL/MariaDB JDBC column transport descriptors retain
the existing separate read-only view policy; temporary LIKE-escape normalization
and restoration occur only on that view, which closes while the caller retains
its physical lease and SQL mode. PostgreSQL descriptors stay physical.
Production schema inspection and designer operations continue to use their
independent committed-metadata route.
Cancellation, stale ownership and deadline expiry return an error without
recapturing against a newer owner. The independent view stays open through
designer native checks and closes before the operation returns.

Manual physical capture checks cancellation and its 30-second acquisition budget
before and after the schema-reader phase, and between later structural branches.
The existing schema reader retains 10-second catalog-statement timeouts, at most
1,000 base tables and 2,048 columns per table, a 32MiB working-string admission
and a 6MiB encoded artifact limit. Its whole reader phase does not have uniform
30-second preemption: cancellation or budget expiry is acknowledged when that
phase returns. This route never aborts the physical connection to enforce a
metadata deadline; the caller retains the same transaction and lease.

Routine capture uses the metadata platform's bounded native source decoder,
including the pinned driver's actual result-column character encoding. Schema
artifacts keep their existing 6MiB aggregate encoded-output limit and 32MiB
working-string budget; the decoder admits at most 6MiB for an artifact source
field. Interactive introspection separately limits each source to 64KiB.
An oversized field fails capture explicitly rather than producing a truncated
definition. Transaction-aware capture keeps the physical session's ownership;
source cancellation targets its statement and does not resolve the transaction.
SQL NULL source remains JSON null, preserving the distinction from an empty or
complete definition.

MySQL documents a separate namespace for each constraint type and publishes the
actual type in its catalog:
[constraint namespaces](https://dev.mysql.com/doc/refman/8.4/en/create-table-check-constraints.html),
[TABLE_CONSTRAINTS](https://dev.mysql.com/doc/refman/8.4/en/information-schema-table-constraints-table.html).
