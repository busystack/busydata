# SQL language service

SQL intelligence reads the same Java-owned published metadata snapshots as
Database Explorer and table-data relationships. Analysis does not execute SQL,
open JDBC connections, introspect on a keystroke, approve execution, or modify
editor text. Flutter captures text, UTF-16 caret, document version and physical
session/context revisions before requesting a service. It applies a reply only
while that complete binding remains current.

## Pipeline and ownership

The `analysis.language` package separates the following responsibilities:

| Component | Contract |
| --- | --- |
| `LosslessLexer` | Own every original UTF-16 unit, including whitespace, comments, incomplete tokens, CRLF, strings and quoted identifiers. Preserve exact source spelling. |
| `Dialect` | Supported engine capabilities, captured lexical settings and insertion quoting. |
| `SyntaxParser` / `SyntaxTree` | Recoverable groups, statements, query blocks, CTE declarations, set branches, relation declarations, projections, clauses and opaque procedural regions. |
| `TableSourceParser` / `JoinedNamespace` | Joined-source tree, merged USING/NATURAL outputs, qualified operand visibility and outer null extension. |
| `ResolutionContext` | Captured catalog, schema, search path, metadata completeness/revisions and the central snapshot's native identifier rules and physical affinity. |
| `SemanticCatalog` | Uses immutable central indexes and projects referenced branches lazily; no full-catalog per-request copy, independent refresh policy, durable cache or JDBC acquisition. |
| `SemanticBinder` | Scope, declaration order, shadowing, derived output, outer references, ambiguity, type evidence and inspections. |
| `ExpressionSyntax` / `ExpressionParser` / `ExpressionAnalyzer` | Source-bound scalar AST, bounded tolerant grammar, operator/cast/CASE inference and expression diagnostics. |
| `QueryOutputs` | Positional and named output shapes, CTE aliases, recursive anchors, scalar nullability and set-operation type propagation. |
| `SqlTypes` / `RoutineSignatures` | Native SQL type descriptors and signature-aware overload/parameter evidence, separate from JDBC transport categories. |
| `NumericShape` / `NativeNumericTypes` | Bounded native display/precision facts, engine integer widths, materialized-field evidence and explicit uncertainty when captured context is insufficient. |
| `ExpressionOperators` / `RoutineOverloads` | Engine-specific native signatures, argument-dependent results, coercion evidence and deterministic overload selection. |
| `CompletionService` | Syntax-context candidates, exact replacements, deterministic ordering and verified foreign-key predicates. |
| `ParameterService` | Independently bounded active-call/argument and overload lookup. |
| `SymbolService` | Original quoted syntax names and shared catalog scope/case/temp/search-path resolution, with bounded identities and no JDBC. |
| `SqlFormatter` | Configurable token-preserving explicit edits and source-token mappings. |
| `DdlImpact` | Conservative refresh effects consumed after acknowledged execution. |
| `SqlAnalysis` | Pure service dispatch, protocol mapping and inspection settings. |

The execution splitter and review classifier remain separate. Neither execution
selection nor JDBC input is reconstructed from this editor syntax tree.
See [joined-table resolution](sql_join_resolution.md) and
[expression typing](sql_expression_typing.md) for the engine matrices and
availability boundaries of these stages.
JSQLParser remains isolated behind `SqlParsing` for its existing bounded schema
expression/read-classification uses. Unsupported parser serialization is never
used as execution input.

The independent scanners share only native character facts through
`SqlLexicalCharacters`. SQL spaces are the six ASCII space/control separators;
Unicode space characters inside native identifiers stay identifier content.
PostgreSQL accepts non-ASCII Unicode scalars, including supplementary characters,
in identifiers and dollar tags; MySQL and MariaDB identifiers are limited to the
BMP. These rules follow the supported PostgreSQL scanner's
[`ident_start`, `ident_cont` and `dolqdelim` definitions](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/parser/scan.l),
[MySQL identifier rules](https://dev.mysql.com/doc/refman/8.4/en/identifiers.html)
and [MariaDB identifier rules](https://mariadb.com/docs/server/reference/sql-structure/sql-language-structure/identifier-names).

Published metadata supplies exact object/parent identities, names, namespaces,
native types and signature properties. The language projection cannot invent a
relation because a column preview happened to mention its table. Metadata states
remain explicit. Missing or partial metadata suppresses unsupported absence
claims instead of turning every reference into an unresolved-object error.
The captured PostgreSQL temporary namespace resolves the `pg_temp` alias only
for its owning snapshot/context. `MetadataSearchPath` supplies the shared
effective namespace order: an implicit temporary namespace precedes an implicit
`pg_catalog`, and explicitly listed namespaces retain their declared positions.
Temporary namespaces are excluded from unqualified routine searches.
Explicit `pg_temp.routine` still resolves through that exact owned namespace.
Unqualified PostgreSQL routines combine overloads from every effective
nontemporary namespace. Only an identical ordered native input-type identity
is shadowed by an earlier namespace; output-only parameters do not form that
identity. Unknown earlier coverage or missing native parameter identity makes
the affected signatures explicitly partial. These candidate rules follow
PostgreSQL's [function resolution rules](https://www.postgresql.org/docs/17/typeconv-func.html).
MySQL and MariaDB resolve eligible unqualified native calls before colliding
stored functions; stored-function completion retains the qualified alternative.
`CALL` completion and parameter information select procedures, while nested
argument expressions select functions. PostgreSQL overload shadowing still
considers an earlier same-input signature before rejecting an invocation of the
wrong routine kind. Fresh exact routine coverage can recover independently of
unknown temporary-table visibility; stale routine coverage cannot.
The captured `ResolutionContext` references its immutable central snapshot.
All metadata-aware service entry points require that captured context; they do
not accept a second flat catalog of Explorer objects. Requests without a session
use an empty central snapshot for syntax, local declarations, builtins and
formatting, and explicitly report server metadata as unavailable. Test fixtures
also construct normalized snapshots with declared coverage before analysis, so
the performance and correctness tests exercise the production lookup path.
Unresolved persistent-relation claims require complete structural TABLE/VIEW
coverage for the referenced namespace, including explicit qualifiers outside the
search path. A nonempty column preview never establishes completeness. Exact
COLUMN scope coverage governs column-absence proofs, full field lists and
relationship generation independently of an unrelated incomplete scope. An
unqualified source also needs names coverage proving that earlier namespaces
cannot shadow it; otherwise its fields remain explicitly incomplete. This
ordering follows PostgreSQL's [documented search path behavior](https://www.postgresql.org/docs/17/runtime-config-client.html#GUC-SEARCH-PATH).
Derived/CTE wildcard output inherits its sources' completeness; explicit output
names remain syntax-owned evidence. Incomplete targets produce a localized
`metadata.incomplete` hint rather than speculative unresolved or type errors.

The captured snapshot also carries physical-session resolution availability.
Opaque procedure or dynamic execution can leave that state unknown, including
after a failed call. Cached permanent names remain discovery candidates, but
their columns, relationship predicates and routine signatures cannot become
verified evidence merely because their fields are populated. MySQL/MariaDB
qualification does not bypass temporary-table shadowing. Exact owned observations
can verify one relation without asserting that the rest of the session is known.
Completion, diagnostics and parameter information consume this same immutable
state and never run the physical verification themselves.

## Pinned dialect behavior

These capabilities concern the pinned versions in
[database_support_matrix.md](database_support_matrix.md), not newer server
features inferred from current documentation examples.

| Construct | PostgreSQL 17 | MySQL 8.4 | MariaDB 11.8 |
| --- | --- | --- | --- |
| SELECT clauses, explicit/implicit joins, derived/scalar/correlated queries | Query scopes and projections | Query scopes and projections | Query scopes and projections |
| WITH / RECURSIVE | CTE declarations and explicit recursive output names | CTE declarations and explicit recursive output names | CTE declarations and explicit recursive output names |
| UNION / INTERSECT / EXCEPT | Branch scopes; first-branch output names | Branch scopes; first-branch output names | Branch scopes; first-branch output names |
| LATERAL derived relation | Preceding sibling visibility | Preceding sibling visibility | Explicit dialect diagnostic |
| INSERT / multi-row VALUES / INSERT SELECT | Target columns and sources | Target columns and sources | Target columns and sources |
| UPDATE / DELETE | Targets, clauses and unrestricted-write inspections | Targets, clauses and unrestricted-write inspections | Targets, clauses and unrestricted-write inspections |
| RETURNING | INSERT, UPDATE, DELETE | Explicit dialect diagnostic | INSERT and single-table DELETE; UPDATE diagnosed |
| WITH before UPDATE / DELETE | Supported declaration scope | Supported declaration scope | Explicit diagnostic: requires a later MariaDB release |
| Upsert | ON CONFLICT candidates | ON DUPLICATE KEY UPDATE candidates | ON DUPLICATE KEY UPDATE candidates |
| Identifier quotes | Double quotes; unquoted lowercase folding | Backticks; ANSI_QUOTES changes double quotes | Backticks; ANSI_QUOTES changes double quotes |
| String escapes | standard_conforming_strings and E strings | NO_BACKSLASH_ESCAPES captured | NO_BACKSLASH_ESCAPES captured |
| Function name/parenthesis trivia | Ordinary SQL trivia; quoted names keep exact case | IGNORE_SPACE captured; native keyword, quoting and comment rules | IGNORE_SPACE captured; MariaDB-specific keyword and quoting rules |
| PostgreSQL operators, dollar strings, positional parameters | Lossless tokens, including casts/JSON operators | No PostgreSQL dialect inference | No PostgreSQL dialect inference |
| JSON, arrays and native type details | Distinct native families | Native families; no PostgreSQL coercion assumptions | Native families; no PostgreSQL coercion assumptions |
| Routine bodies / procedural languages | Bounded opaque region and one availability diagnostic | Bounded opaque region and one availability diagnostic | Bounded opaque region and one availability diagnostic |

The tolerant syntax tree retains expression tokens even when an expression's
complete semantics cannot be proved. A native/user type remains named and
unknown inference remains unknown. This service is not a server-equivalent SQL
validator. It does not claim a complete server operator/coercion catalog,
procedural-language compiler, arbitrary table-function return inference or
complete effective-permission model. Unaliased computed projection names that
depend on server rendering are not invented. Matching a known routine's arity
does not establish that every server-specific coercion will succeed.

The finite native signature catalog follows these pinned invocation rules. A
qualified name selects stored-routine lookup. For special names, an adjacent
unquoted `(` selects native lookup; whitespace requires `IGNORE_SPACE`, and a
comment between name and parenthesis selects stored lookup in either mode.

| Names in the bundled signature catalog | MySQL 8.4 | MariaDB 11.8 |
| --- | --- | --- |
| COUNT, MIN, MAX, SUM | Special-name rules; quoted names select stored lookup | Same |
| AVG, ROW_NUMBER | Unquoted native keyword; quoted name selects stored lookup | Same |
| RANK, DENSE_RANK | Unquoted native keyword; quoted name selects stored lookup | Special-name rules; quoted names select stored lookup |
| COALESCE | Unquoted native keyword; quoted name selects stored lookup | Native lookup also accepts a quoted name |
| ABS, LOWER, UPPER, LENGTH, NULLIF, DATE_FORMAT, JSON_OBJECT | Native lookup accepts quoted names and intervening trivia | Same |

These rules use the captured SQL mode and lossless token spans in one shared
`NativeCallSyntax` service. Formatting preserves the original name/parenthesis
trivia and does not switch invocation categories. Primary sources are the
[MySQL function resolution rules](https://dev.mysql.com/doc/refman/8.4/en/function-resolution.html),
[MariaDB stored function rules](https://mariadb.com/docs/server/reference/sql-statements/data-definition/create/create-function),
and the pinned [MySQL lexical definitions](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/lex.h)
and [MariaDB lexical definitions](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/lex.h).

Primary references: [PostgreSQL SELECT](https://www.postgresql.org/docs/17/sql-select.html),
[PostgreSQL lexical structure](https://www.postgresql.org/docs/17/sql-syntax-lexical.html),
[PostgreSQL INSERT](https://www.postgresql.org/docs/17/sql-insert.html),
[PostgreSQL type conversion](https://www.postgresql.org/docs/17/typeconv.html),
[MySQL SELECT](https://dev.mysql.com/doc/refman/8.4/en/select.html),
[MySQL INSERT](https://dev.mysql.com/doc/refman/8.4/en/insert.html),
[MySQL SQL modes](https://dev.mysql.com/doc/refman/8.4/en/sql-mode.html),
[MySQL identifier case](https://dev.mysql.com/doc/refman/8.4/en/identifier-case-sensitivity.html),
[MySQL type conversion](https://dev.mysql.com/doc/refman/8.4/en/type-conversion.html),
[MariaDB SELECT](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/selecting-data/select),
[MariaDB INSERT RETURNING](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/inserting-loading-data/insertreturning),
[MariaDB DELETE](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/changing-deleting-data/delete),
[MariaDB UPDATE](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/changing-deleting-data/update),
and [MariaDB SQL modes](https://mariadb.com/docs/server/server-management/variables-and-modes/sql_mode.md).
DataGrip's [documented completion workflows](https://www.jetbrains.com/help/datagrip/auto-completing-code.html)
are a behavioral reference; no JetBrains implementation is used.

## Editor services

The private protocol exposes six independent RPCs: `CompleteSql`, `DiagnoseSql`,
`SqlParameterInformation`, `FormatSql`, `ResolveSqlSymbol` and `SqlDdlImpact`.
Each requires its matching `AnalysisOperation` and has an independent cancellation
lifetime and admission reservation. There is no all-purpose `Analyze` wire
endpoint. A completion request does not run diagnostics, formatting or parameter
information before replying. `SqlAnalysis.analyze` is an internal pure Java
dispatcher rather than a combined protocol operation.

Completion ranks visible columns before aliases, current-namespace relations,
other namespaces, routines and grammar keywords. Ties sort by normalized label,
exact label, detail and stable target identity. Ambiguous columns carry qualified
insertions; same-named relations retain namespace choices. Replacement spans are
original UTF-16 coordinates, including quoted and incomplete identifiers.
After a schema/database qualifier, function candidates retain the typed
namespace and replace only the function-name token. A visible relation alias
with the same spelling keeps column-completion precedence. PostgreSQL routine
candidates belong to the captured connection's database; a cached routine from
another database cannot suppress a builtin or become an invocable candidate.
MySQL and MariaDB retain verified qualified routines from other configured
databases. These namespace rules follow the supported engines' documentation
for [PostgreSQL schemas](https://www.postgresql.org/docs/17/ddl-schemas.html),
[PostgreSQL function calls](https://www.postgresql.org/docs/17/sql-expressions.html#SQL-SYNTAX-FUNCTIONS),
[MySQL function resolution](https://dev.mysql.com/doc/refman/8.4/en/function-resolution.html)
and [MariaDB stored functions](https://mariadb.com/docs/server/reference/sql-statements/data-definition/create/create-function).
Completion is bounded to 200 entries and 256KiB. Field-list insertions are bounded
to 32Ki UTF-16 units.
When additional matching candidates exceed either response cap,
`Analysis.completion_limited` is true. The returned items retain their exact
labels, insertion text, spans, details and deterministic order; a capped batch
never claims complete availability. An exactly full batch without another
candidate is complete.

Flutter sends its configured snippets as request-owned text. The map admits at
most 32 names of 64 UTF-16 units, 4,096 UTF-16 units per template and 32KiB total
UTF-8 names/text. Java rejects malformed or oversized maps; it never truncates a
template. Snippet candidates share completion's ranking and replacement pipeline
with kind `snippet`. They are offered only at a statement start or its partially
typed initial word, including after leading comments. They do not appear inside
strings/comments, qualified names, expressions, clauses or nested argument lists.
Selecting a snippet edits Flutter-owned text and grants no execution approval.
Candidate collection retains only the best 201 unique prefix matches under the
same deterministic ordering used for presentation. The extra item proves the
200-item limit; collection checks cancellation and deadlines while iterating.
Qualification checks use captured indexes or visible scopes for those retained
items, without collecting every catalog label. The response byte ceiling and
explicit limited state remain independent of this bounded collection.

Foreign-key candidates require complete component evidence with
`relationshipVerified`, exact source/target namespaces and ordered `column.N` /
`referencedColumn.N` identities. Every component must exist in the bound sources.
Comma-separated display labels are never parsed into executable identifiers.
Separate foreign keys retain their names and stable identities.

Diagnostics carry stable code, component, severity, dialect, exact span and
incomplete-evidence state. Mechanical ambiguity fixes qualify the existing
column with a visible relation; selecting one remains an editor edit, never
execution authorization. Settings can disable an inspection or change severity.
Syntax and availability diagnostics remain distinct from semantic absence.
Qualified routine calls bind their complete namespace and overload identity;
their namespace is never inspected as a column qualifier. An unknown-routine
error requires complete structural coverage of that exact qualified routine
namespace and unfiltered captured metadata policy. Unrequested builtin or
routine catalogs produce a localized availability diagnostic instead.

The editor's **Inspections** command opens the complete bounded diagnostic list
with UTF-16 source spans, severity, inspection name and metadata availability.
Mechanical corrections require explicit selection and use one Flutter undo
operation. The dialog keeps its captured diagnostics owner and refuses a late
correction after text, selection, tab, backend, context or metadata changes.

Parameter information resolves the innermost call independently of diagnostics,
including commas inside nested calls or strings. It returns up to 64 signatures
and 64KiB with names, modes, native types, optional/default information, variadic
state and return type. Unavailable signature properties remain unavailable;
default expressions are not reconstructed from presentation text.
If additional overloads exceed the count or byte cap, parameter information
returns explicit `limited` availability. An incomplete signature set is never
treated as proof that no matching overload exists. Native lookup retains only
the best 65 signatures after resolving the exact namespace; the extra signature
proves the response limit without materializing every overload.

Symbol resolution preserves original quoted syntax names and shares the same
catalog case, search-path and temporary-object rules as binding. It returns at
most 32 identities across at most 32 captured scopes. Prior unexecuted context
changes remain explicitly ambiguous for an unqualified reference. Existing
object navigation consumes this pure service without JDBC work.

Formatting supports a document, exact token-aligned selection, or current
statement. The transient `AnalysisRequest.format_current_statement` flag is valid
only for `FormatSql` / `FORMAT`. Java selects the original fragment using the
independently validated execution splitter and shared caret/delimiter/whitespace
selection rules. This performs no execution. The rest of the document remains
exact: every formatting pass, including assignment alignment, is confined to
the selected fragment before the original UTF-16 prefix and suffix are
reattached. Alignment neither inspects nor changes assignments in other
statements. Returned token mappings retain full-document coordinates. A caret with
no active executable fragment returns `no-active-statement` without an edit.
Options cover case, indentation/continuation, clause/JOIN/CTE layout, comma and
logical-operator placement, list/argument wrapping, subquery indentation,
parenthesis/operator spacing, assignment alignment, line length and blank lines.
Comments, quoted contents, original line-ending style and a final newline are
preserved. `-- busydata-format:off` through `-- busydata-format:on` remains exact.
Directive state comes from lossless comment tokens in the full document, so a
selection or current statement also honors an opening directive in its untouched
prefix. Literal, quoted-identifier and block-comment lookalikes are not controls.
Formatting resumes only at a real closing directive; assignment alignment skips
disabled clauses. An entirely inherited disabled range is an exact no-op with
identity token mappings, including when its unchanged syntax is incomplete.
DDL word case beyond the leading command is retained until the tolerant tree can
prove each native declaration's keyword/name role. This preserves case-sensitive
MySQL/MariaDB object identifiers that happen to spell nonreserved SQL keywords.
Malformed delimiters, incomplete tokens and selections through a lexical token
return an availability state. Token verification and mappings are returned only
after a successful proof. MySQL function-name/parenthesis adjacency is retained.

Flutter stores per-dialect preferences and explicit per-profile overrides in its
existing atomic presentation file. This introduces no second editor-text or
database metadata owner. Settings drafts share the existing Save/Discard/close
review boundary. The preference object is bounded to 128 scopes and 16KiB.

## Resource and verification contracts

Each of the six language RPCs has a 1MiB request envelope, separate from the
16MiB execution/review envelope. The source-unit limit below fits worst-case
UTF-8 with bounded settings and snippets. Inspection configuration accepts at
most 64 entries, with 128 UTF-16 units per code and 16 per severity. Six independent
transport admissions feed four bounded language CPU tasks.

A source snapshot is at most 262,144 UTF-16 units, 100,000 lexical tokens,
64 nested delimiters, 2,048 query scopes and 32 recursive projection steps.
Diagnostics return at most 64 issues. Each service checks cancellation and a
hard CPU deadline; limit results are explicitly incomplete and contain no
partially generated insertion/formatting operation. Formatting has a 1,500ms
deadline and the other pure operations a 750ms deadline. Superseding a service
cancels that operation without cancelling SQL execution.

Run focused backend coverage with:

```sh
backend/mvnw -f backend/pom.xml test -Dtest=CompletionTest,SqlLexerTest,SemanticLanguageTest,LanguagePerformanceTest,ProductionMetadataHeapTest
```

`LanguagePerformanceTest` defines a normal active document as its fixed 123-UTF-16
SELECT with typed parameter, qualified fields, filtering, ordering and paging.
Its immutable fixture has 10,000 relations, 100,000 columns, 1,000 foreign keys,
1,000 routine signatures and duplicate relation names across ten namespaces.
The fixture is normalized once before measurement and verifies distinct native
routine input signatures instead of counting repeated names as overloads.
Five warmup iterations precede twenty measured samples. It requires completion
and parameter-information p95 at most 250ms and diagnostics p95 at most 750ms.
The actual JVM, OS, processors, heap, fixture sizes and individual samples are
written to ignored `backend/target/p0-language-performance.json`. These pure
backend CPU checks establish no Linux frame/RSS, installed-package, Windows or
live-engine acceptance. Those separate gates remain in
[development.md](development.md).

`ProductionMetadataHeapTest` launches a separate JVM with the shipped 128MiB
maximum heap, Serial GC and 64MiB direct-memory ceiling. Its actual normalized
snapshot contains 10,000 relations, 100,000 structural columns, 3,000 constraints,
2,000 foreign keys and 3,000 routine signatures. Completion, diagnostics,
parameter information and formatting run concurrently after five warmups, with
twenty measured samples each and the same latency requirements. Every warmup's
availability, diagnostics and elapsed time are recorded, including bounded
unavailability during initial class loading; the final warmup and all measured
responses must be complete. The gate records
sampled peak heap, per-pool peak usage, maximum heap, Linux peak RSS and runtime
context in a unique ignored `backend/target/p0-production-heap-*/` directory per
invocation, preserving failed runs. Separate
workloads exercise one resident snapshot, a second immutable revision sharing
unchanged native objects while four old-revision readers remain live, and a
touched 32MiB retained allocation representing other backend work. Old readers
are validated again after publication. These checks do not substitute for
physical-connection, retained-result, combined-process RSS or desktop gates.
