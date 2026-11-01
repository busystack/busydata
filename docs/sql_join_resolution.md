# Joined tables and query-scope resolution

The editor parser records table sources as a tree. Explicit joins bind before
comma-separated sources, and parenthesized sources preserve their grouping.
Binding keeps two namespaces: the joined table's unqualified output, and its
visible operands for qualified references. `USING` and `NATURAL` merge common
output columns; `a.id` and `a.*` still refer to operand `a`. A PostgreSQL alias
on a parenthesized join replaces the externally visible operand aliases.

| Behavior | PostgreSQL 17 | MySQL 8.4 | MariaDB 11.8 |
| --- | --- | --- | --- |
| `USING` common output order | Order of the explicit column list | Operand column order | Operand column order |
| `NATURAL` common output order | Left operand order | Preserved operand order | Preserved operand order |
| Remaining output columns | Left, then right | First operand, then second; RIGHT joins use the preserved right operand first | Same RIGHT-join orientation |
| Qualified operand columns | Kept separately | Kept separately | Kept separately |
| LEFT / RIGHT joined output | Merge common keys; null-extend the nonpreserved operand | Same; native coalesced-key type | Same; native coalesced-key type |
| FULL joined output | Common type and coalesced keys | Explicit dialect diagnostic | Explicit dialect diagnostic |
| Alias on a grouped joined table | Hides the inner relation aliases | Explicit availability diagnostic | Explicit availability diagnostic |

PostgreSQL's [table-expression rules](https://www.postgresql.org/docs/17/queries-table-expressions.html)
define its common-column ordering and alias visibility.
[MySQL's join rules](https://dev.mysql.com/doc/refman/8.4/en/join.html)
define its coalesced columns and RIGHT-join ordering.
MariaDB's supported grammar is its [join syntax](https://mariadb.com/docs/server/reference/sql-statements/data-manipulation/selecting-data/joins/join-syntax);
the pinned server's [`store_natural_using_join_columns`](https://github.com/MariaDB/server/blob/mariadb-11.8.9/sql/sql_base.cc)
defines common-column ordering and the restored RIGHT-join operand orientation.
BusyData implements this behavior with its own source model and binder.

Column lookup examines one query scope at a time. A matching local column stops
the search, even when outer relations have different aliases. Only a complete
local namespace that lacks the name permits an unqualified outer lookup. An
incomplete local source leaves the result unavailable because an unknown local
column could shadow the outer name. Qualified lookup stops at the nearest
matching relation alias even if that relation lacks the requested column.
LATERAL visibility retains only preceding sources; a join's `ON` condition sees
its operands, excluding unrelated comma-separated sources.

These namespaces are request-local projections of the captured immutable central
metadata snapshot. They neither query JDBC nor create a second persistent cache.
Missing or ambiguous `USING` columns produce localized binding diagnostics;
partial metadata does not prove a natural-column intersection. Completion,
wildcard expansion, derived/CTE outputs and expression typing use the same joined
namespace and nearest-scope lookup.
The table-source tree shares the parser's 64-level syntax-depth budget, including
left-associated join chains, so an oversized join cannot overflow recursive
binding or condition inspection.

`SemanticJoinScopeTest` covers all three dialects using normalized central
metadata fixtures. `SemanticJoinScopeIT` compares projected output names with
the actual pinned servers and asserts that warm binding performs no JDBC work.
They run through the documented Maven unit and database integration gates.
