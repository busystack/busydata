# Coordinated workbench foundations

The metadata, language and result editor changes share the existing Flutter →
private TLS gRPC → Java 25 → JDBC boundary. Java publishes immutable metadata;
Flutter owns document text and presentation. Analysis never executes SQL.

## Identity and revisions

Profile identity selects the saved source; a physical session has its own identity
and monotonically increasing execution revision. Context revision changes when
catalog, schema, search path or lexical mode changes. Metadata configuration and
published snapshot revisions are independent of those session revisions. A
metadata identity includes source, engine, namespace, kind, parent, exact name
and overload identity. Labels cannot authorize generated identifiers.

An editor request captures document ID/version, caret, backend instance, physical
session, session revision and context revision. Its response additionally names
the immutable metadata revision used. A result is a retained execution snapshot;
a local view only maps its source rows. Draft revision belongs to the retained
source, independently of presentation. Changing a presentation never changes row
identity or copies a draft.

## Metadata publication

A separate rebuildable normalized SQLite catalog stores identities, properties,
scope coverage and publication revisions. Publication atomically swaps the
immutable reader reference before optional bounded cache persistence; cache write
status remains explicit and never changes database transaction ownership. Readers retain their
captured snapshot. Session-local metadata is excluded from durable storage.
Names, structure and source levels are explicit coverage, not inferred from
missing fields. Failed/cancelled refresh retains the previous published data and
records its availability; it cannot publish a partially collected branch.

Full refresh visits configured scopes. Fragment refresh replaces the requested
branch and required relationships. Incremental refresh compares bounded native
identity/structural fingerprints before retrieving changed details. Smart refresh
uses successful statement impact and actual transaction state: committed changes
can refresh durable metadata; pending manual-transaction changes cannot become
global state. Unknown outcomes make affected metadata stale.

## Language pipeline

Lossless tokens and UTF-16 spans feed tolerant dialect syntax, scopes, binding,
native types and editor services. The execution splitter remains independently
validated. Completion, diagnostics, parameter information, formatting, symbol
resolution and DDL impact are separate request operations and are cancellable.
They consume a captured metadata snapshot and never acquire JDBC connections.
Unavailable metadata suppresses speculative unresolved-symbol errors.

## Result state and generated operations

Table, transpose, tree, text, Record View and Value Editor share retained rows,
selection, source-row mappings and one typed draft. Values remain exact; display
formats do not participate in equality, optimistic predicates or export defaults.
Large values use explicit bounded chunk retrieval. Aggregates run in Java with
exact integer/decimal arithmetic and a declared retained-selection scope.

Assignments are a oneof: value, SQL NULL, DEFAULT; an absent assignment is unset.
Only bound exact values create JDBC parameters. DEFAULT is generated grammar,
never a string value. Clone creates a staged insert and excludes verified row
identities/generated columns. Related rows use verified composite relationships
and typed predicates, followed by the normal browse review.

## Migration and verification

The private protocol is version 15; peers of other versions fail.
Stored edit drafts migrate atomically once from value maps to assignment maps.
Profiles, history and unrelated preferences retain their formats. Rebuildable
catalogs may be invalidated; user drafts may not be silently discarded.

Evidence belongs under ignored build directories. Baseline source and failed
commands are retained before edits. Unit/widget, live three-engine, protocol,
release performance, Linux native, Windows native and installed strict-Snap
acceptance remain distinct gates. An unavailable gate is not a passing skip.
See development.md for original budgets and full commands. Language tests define
normal documents and large metadata fixtures with bounded operation deadlines.
