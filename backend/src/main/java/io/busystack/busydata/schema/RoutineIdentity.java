package io.busystack.busydata.schema;

/** Native identity agrees with RoutineDefinitions and CatalogDependencies.
 * PostgreSQL visibility and source preview retain information_schema's role
 * rules. Specific names are opaque; the client never parses them. */
final class RoutineIdentity {
    static final String POSTGRES_FROM="pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid=p.pronamespace";
    static final String POSTGRES_VISIBLE="p.prokind IN ('f','p') AND (pg_catalog.pg_has_role(p.proowner,'USAGE') OR pg_catalog.has_function_privilege(p.oid,'EXECUTE'))";
    static final String POSTGRES_KEY="p.proname||'('||pg_catalog.pg_get_function_identity_arguments(p.oid)||')'";
    static final String MYSQL_KEY="CONCAT(ROUTINE_TYPE,':',ROUTINE_NAME)";
    static final int MAX_BYTES=8192, CONTINUATION_BYTES=16384, CONTINUATION_TEXT=24576;
    private RoutineIdentity(){}
}
