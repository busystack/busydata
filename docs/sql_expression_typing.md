# SQL expression analysis

The language service parses scalar expressions into source-bound nodes after
query scopes have been established. `ExpressionParser` implements operator
precedence, parentheses, casts, calls, predicates, CASE, arrays, subscripts, and
aggregate/window decorations. `ExpressionAnalyzer` propagates native types over
those nodes. `ExpressionOperators` contains the finite engine operator facts;
`RoutineOverloads` selects among signatures already resolved by the central
metadata catalog. `SemanticBinder` supplies the captured query scope and metadata
snapshot, including merged joined-table outputs and nearest outer-scope lookup.
There is no second catalog, database connection, SQL execution, or evaluation of
runtime database values. Constant arithmetic facts are bounded to 65 bits and
serve only native display/precision inference.

Tokens retain the original source, comments, trivia, line endings and UTF-16
offsets. Expression nodes retain those tokens and groups. No expression is
reserialized for binding. Parsing and inference share the request's cancellation
and deadline budget, token/document limits and 64-level expression nesting limit.
Query projection recursion additionally uses the existing 32-level bound. Native
metadata type descriptors have an independent 64-dimension array nesting limit,
including descriptors supplied by a cached snapshot. Type
traversal is iterative so long, flat operator chains do not exhaust the Java stack.

## Engine capability matrix

| Expression | PostgreSQL 17 | MySQL 8.4 | MariaDB 11.8 |
| --- | --- | --- | --- |
| Integer, exact decimal and exponent literals | Integer/bigint/numeric width; exponents remain numeric | Exact integers/decimal; exponent is double | Exact integers/decimal; exponent is double |
| Core arithmetic | Native numeric promotion; integral division remains integral | BIGINT integer arithmetic, decimal exact division, double approximate/string arithmetic | Native integer family, decimal exact division, double approximate/string arithmetic |
| Integer signedness | Signed native integer families | Unsigned operands and NO_UNSIGNED_SUBTRACTION participate | Unsigned operands and NO_UNSIGNED_SUBTRACTION participate |
| Boolean operations/comparisons | Boolean operands; native comparison compatibility | Numeric/text truth coercion; NULL-safe comparison | Numeric/text truth coercion; NULL-safe comparison |
| Casts | Standard CAST and `::`; native precision/scale and time zones | Supported CAST targets, signed/unsigned BIGINT and REAL_AS_FLOAT | Supported CAST targets, signed/unsigned INTEGER or BIGINT by native display width, and REAL_AS_FLOAT |
| CASE, COALESCE and NULLIF | Common result, numeric promotion and domain base handling | Common numeric/string/temporal families | Common numeric/string/temporal families |
| Routine overload selection | Exact types, directional implicit conversions, preferred types, unknown-input categories, defaults and variadics | Captured signature/arity and native coercion facts | Captured signature/arity and native coercion facts |
| Argument-dependent builtin results | ABS, SUM, AVG, MIN, MAX, COALESCE, NULLIF; timestamp/interval date_trunc overloads | Exact/approximate aggregates and common-result functions | Exact/approximate aggregates and common-result functions |
| Array constructors, element access, JSON extraction and temporal arithmetic | Finite documented native signatures | Unavailable signatures remain explicit | Unavailable signatures remain explicit |
| Window/aggregate decoration | Preserve call result; bind PARTITION/ORDER expressions and FILTER condition | Preserve call result; bind PARTITION/ORDER expressions; FILTER unavailable | Preserve call result; bind PARTITION/ORDER expressions; FILTER unavailable |

PostgreSQL numeric constants and precedence follow its [lexical
specification](https://www.postgresql.org/docs/17/sql-syntax-lexical.html).
Arithmetic result families follow its [mathematical
operators](https://www.postgresql.org/docs/17/functions-math.html), temporal
signatures follow [date/time
operators](https://www.postgresql.org/docs/17/functions-datetime.html), and
aggregate results follow [aggregate
signatures](https://www.postgresql.org/docs/17/functions-aggregate.html).

CASE/common-type rules and overload selection use PostgreSQL's [common result
resolution](https://www.postgresql.org/docs/17/typeconv-union-case.html) and
[function resolution](https://www.postgresql.org/docs/17/typeconv-func.html).
Exact matches precede preferred-type selection; a nearer numeric width does not
break an ambiguous overload tie. Namespace/signature shadowing happens in the
metadata catalog before this selection step.

PostgreSQL `NULLIF` resolves the implied equality operator and returns its coerced
left operand's type. Cross-width integer and floating-point equality operators
can preserve that operand's original native type; integer/numeric or numeric/float
inputs may instead require an implicit cast. A single unknown input first uses
the known input's type for exact operator lookup. The finite builtin equality
signatures follow the pinned [operator catalog](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/include/catalog/pg_operator.dat),
[implicit casts](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/include/catalog/pg_cast.dat),
and [operator resolution rules](https://www.postgresql.org/docs/17/typeconv-oper.html).
Uncaptured domain, extension, enum and array equality declarations leave NULLIF's
result explicitly unavailable rather than inventing a matching operator.

For PostgreSQL CASE/COALESCE, set outputs and USING columns, the shared native
type is selected separately from its modifier. Two varchar, character, numeric
or temporal inputs with different modifiers retain that native type with an
unspecified modifier. Equal modifiers remain known only when every result input
agrees; an unknown string or NULL input has no modifier. These rules follow
[common-type selection](https://www.postgresql.org/docs/17/typeconv-union-case.html)
and the pinned [expression modifier rules](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/nodes/nodeFuncs.c).
PostgreSQL's native `bpchar` descriptor is recognized as its character family;
MySQL/MariaDB inference and their native names remain engine-specific.

MySQL behavior is based on its [numeric
literals](https://dev.mysql.com/doc/refman/8.4/en/precision-math-numbers.html),
[arithmetic](https://dev.mysql.com/doc/refman/8.4/en/arithmetic-functions.html),
[CASE result rules](https://dev.mysql.com/doc/refman/8.4/en/flow-control-functions.html),
[CAST targets](https://dev.mysql.com/doc/refman/8.4/en/cast-functions.html), and
[aggregate results](https://dev.mysql.com/doc/refman/8.4/en/aggregate-functions.html).
MariaDB is verified separately against its [conversion
rules](https://mariadb.com/docs/server/reference/sql-functions/string-functions/type-conversion),
[CAST targets](https://mariadb.com/docs/server/reference/sql-functions/string-functions/cast),
and the pinned server's [aggregate type
dispatch](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_type.cc).
These facts are not inferred from JDBC type codes alone.

## Availability and precision

An unresolved or unavailable symbol is different from a contextually typed SQL
literal or parameter. Incomplete metadata blocks inference through that symbol
and produces an availability diagnostic; complete metadata permits a precise
binding diagnostic. Neither state invents an operator or routine overload.
Ambiguous complete overload sets remain ambiguous even if their return types
happen to match. Partial routine signatures never establish a known return type.
Stored functions sharing builtin names retain their captured declared signatures
and never acquire builtin polymorphic behavior.

The model preserves native name, family, JDBC transport type, signedness,
nullability, array element, timezone distinction and known typemods. A computed
decimal with precision zero has an unknown typemod; its scale field must not be
interpreted as a proven zero scale. In particular, the captured context does not
currently include `div_precision_increment`, so division and AVG retain the
known exact decimal family without inventing an exact scale. No integer or
decimal literal is converted through binary floating point.

`QueryOutputs` retains every positional output even when its generated label is
unavailable. Aliases and simple references supply verified names; PostgreSQL
function calls also supply their documented function name. Compound expressions
never borrow their final identifier as an output name. Explicit CTE/derived-table
column lists can name those positions without losing inferred types. PostgreSQL
allows a shorter CTE name list; MySQL/MariaDB require matching counts.

Set outputs retain the first input's names and infer corresponding types from all
inputs, honoring INTERSECT precedence and PostgreSQL's pairwise resolution.
PostgreSQL unknown string/NULL literals stay contextual until that resolution;
they become text only where an output context requires it. Recursive CTEs seed
their own references with the nonrecursive anchor's types, then validate the
recursive term. PostgreSQL requires its overall native type and known typemod to
match the anchor; MySQL/MariaDB retain the anchor type rather than widening it.
Scalar subquery results are nullable because an empty result produces SQL NULL.
These rules follow [PostgreSQL CTE
analysis](https://github.com/postgres/postgres/blob/REL_17_STABLE/src/backend/parser/parse_cte.c),
[MySQL CTE rules](https://dev.mysql.com/doc/refman/8.4/en/with.html), and
[MariaDB recursive type
rules](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/selecting-data/common-table-expressions/recursive-common-table-expressions-overview).

Native truth-valued results are PostgreSQL Boolean, MySQL signed BIGINT, and
MariaDB signed INTEGER. Boolean semantics are checked through each engine's
operand/coercion rules, separately from its native result representation. The
pinned implementations establish those native representations in [MySQL
Item::set_data_type_bool](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/item.h)
and [MariaDB
Type_handler_bool](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_type.h).

Exact decimal arithmetic keeps its own signedness rules: addition, subtraction,
multiplication and division retain unsigned only when both operands are unsigned;
remainder follows its left operand and NO_UNSIGNED_SUBTRACTION clears subtraction's
unsigned result. Integer DIV follows the integer unsigned rule and MariaDB chooses
its native integer width from the dividend's integer precision. Division and
remainder remain nullable. MySQL common DECIMAL results for CASE/COALESCE and set
operations are signed; MariaDB retains unsigned only when every supplied input is
unsigned. In MariaDB an explicit ELSE NULL participates as a signed input, while an
absent ELSE makes the result nullable without introducing that supplied input.
NULLIF retains its first argument; SUM/AVG return signed exact decimals and ABS
preserves unsigned. These separate rules follow the pinned [MySQL common-result
implementation](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/item.cc),
[MySQL operators](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/item_func.cc)
and [MariaDB operator
attributes](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/item_func.h).

The PostgreSQL lossless lexer accepts the supported release's hexadecimal,
octal and binary integer forms and its permitted digit separators. It retains
malformed numeric input as one error region, including invalid prefixes/digits,
separator placement and trailing identifier text. This scanner follows the
[PostgreSQL17 lexical
rules](https://www.postgresql.org/docs/17/sql-syntax-lexical.html) and is independent
of the execution splitter.

User-defined casts require resolved native type metadata. Unknown custom
operators, unsupported native money/temporal arithmetic signatures and opaque
constructs return a bounded, localized availability result. This finite signature
set does not claim to duplicate every server extension/operator catalog. Window
frame validation remains separate from scalar result typing; partition/order
expressions are bound in the current query scope.

## Native integer width evidence

`NumericShape` records bounded primitive display/precision facts and optional
constant facts of at most 65 bits. Widths describe server metadata; they never
allocate a value or buffer. Large text precision remains a primitive descriptor.
`NativeNumericTypes` applies the pinned engines' rules to those facts. MariaDB
integer literals retain source width, including leading zeros and negation;
ordinary signed integer expressions select INTEGER through nine display
characters and BIGINT above that boundary. Unsigned casts have a separate
ten-character INTEGER boundary. Arithmetic computes display precision from its
operands rather than selecting the smallest storage type for the resulting value.
These rules are specified in the pinned [MariaDB numeric
handlers](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_type.cc)
and [numeric expression
attributes](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/item_func.h).

MariaDB derived-table and CTE references reserve the full native integer range
when used as expression inputs, even when the temporary field's displayed
precision is smaller. Scalar subqueries retain their expression evidence instead.
This follows [Field_int numeric
attributes](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/field.h).

MySQL direct integer expressions retain BIGINT. Guaranteed materialization of a
small integer expression can produce INTEGER; set/recursive type holders preserve
their declared native type. Mergeable derived tables and CTEs can depend on
optimizer settings absent from the captured context. For those cases the service
preserves the INTEGER family and signedness while marking native width
unavailable, rather than claiming either execution strategy. The pinned [MySQL
temporary-field rules](https://github.com/mysql/mysql-server/blob/mysql-8.4.10/sql/sql_tmp_table.cc)
provide the materialized representation; analysis never queries the optimizer.

## Active SQL modes and recovery

The captured lexical context includes PIPES_AS_CONCAT, HIGH_NOT_PRECEDENCE,
NO_UNSIGNED_SUBTRACTION and REAL_AS_FLOAT, in addition to quoting, escaping and
IGNORE_SPACE. `sqlMode()` preserves every captured server mode in deterministic
canonical order, including modes the language service does not interpret. Session
capture and edit-draft recovery must serialize that complete context. The server
is responsible for expanding composite modes; the editor does not guess their
meaning from an incomplete client-side alias table.

Mode semantics come from [MySQL operator
precedence](https://dev.mysql.com/doc/refman/8.4/en/operator-precedence.html),
[MySQL SQL modes](https://dev.mysql.com/doc/refman/8.4/en/sql-mode.html),
[MariaDB operator
precedence](https://mariadb.com/docs/server/reference/sql-structure/operators/operator-precedence)
and [MariaDB SQL
modes](https://mariadb.com/docs/server/server-management/variables-and-modes/sql_mode).

## Regression gates

Run `backend/mvnw -f backend/pom.xml -Dtest=ExpressionTypingTest,NativeWidthTypingTest,NumericMetadataBoundsTest,QueryOutputTypingTest,PostgresNumericTokensTest,ProjectionAliasSyntaxTest,QualifiedObjectNameTest,SemanticLanguageTest,SemanticIdentifierCaseRulesTest,SemanticJoinScopeTest test`
after the metadata/binder and mode-capture integration. Live-engine expression
fixtures must compare native result families and signedness on each pinned
engine; unit fixtures establish inference behavior, not live-server acceptance.
