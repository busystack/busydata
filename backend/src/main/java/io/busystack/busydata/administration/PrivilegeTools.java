package io.busystack.busydata.administration;

import com.google.gson.GsonBuilder;
import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Read-first privilege inspection and SQL drafting. Execution remains in Jobs/Safety. */
public final class PrivilegeTools {
    private static final int ROW_LIMIT = 500;
    private static final int TEXT_LIMIT = 1_048_576;

    public PrivilegeReply run(SessionRegistry.Session session, PrivilegeRequest request) throws Exception {
        return session.metadata(view -> {
            Engine engine = view.profile.getEngine();
            if (request.getAction() == PrivilegeAction.DESIGN_PRIVILEGE) {
                Principal grantee = principal(view.connection, engine, request.getGrantee());
                boolean roleRequired=request.getScope()==PrivilegeScope.ROLE_MEMBERSHIP||request.getScope()==PrivilegeScope.DEFAULT_ROLE&&!request.getRevoke();
                Principal role = roleRequired ? principal(view.connection, engine, request.getRole()) : Principal.getDefaultInstance();
                if (engine == Engine.MARIADB && roleRequired
                        && !role.getKind().equals("role")) {
                    throw new IllegalArgumentException("Choose a MariaDB role, not a user account");
                }
                return PrivilegeReply.newBuilder().addSql(sql(engine, request, grantee, role,
                        databaseScope(view.connection, engine, request)))
                    .addRisks("Review the exact target and grantee. Grants can expose data; revokes can break running applications.")
                    .addRisks("Delegation lets the recipient grant access to others. MySQL/MariaDB privilege changes may implicitly commit; role membership may require explicit activation.")
                    .build();
            }
            if (request.getAction() != PrivilegeAction.INSPECT_PRIVILEGES) {
                throw new IllegalArgumentException("Invalid privilege action");
            }
            if (request.getSearch().length() > 128) throw new IllegalArgumentException("Principal search exceeds 128 characters");
            var out = PrivilegeReply.newBuilder();
            String query = switch (engine) {
                case POSTGRESQL -> "SELECT rolname,'' AS host,CASE WHEN rolcanlogin THEN 'login role' ELSE 'role' END AS kind FROM pg_roles WHERE rolname LIKE ? ESCAPE '!' ORDER BY rolname";
                case MYSQL -> "SELECT User,Host,CASE WHEN account_locked='Y' THEN 'locked account / role' ELSE 'account' END AS kind FROM mysql.user WHERE User LIKE ? ESCAPE '!' ORDER BY User,Host";
                case MARIADB -> "SELECT User,Host,CASE WHEN is_role='Y' THEN 'role' ELSE 'account' END AS kind FROM mysql.user WHERE User LIKE ? ESCAPE '!' ORDER BY User,Host";
                default -> throw new IllegalArgumentException("Choose a database engine");
            };
            try (var statement = view.connection.prepareStatement(query)) {
                statement.setString(1, "%" + request.getSearch().replace("!", "!!").replace("%", "!%").replace("_", "!_") + "%");
                statement.setMaxRows(ROW_LIMIT + 1);
                statement.setQueryTimeout(10);
                try (var rows = statement.executeQuery()) {
                    while (rows.next()) {
                        if (out.getPrincipalsCount() == ROW_LIMIT) { out.setLimited(true); break; }
                        out.addPrincipals(Principal.newBuilder().setName(rows.getString(1)).setHost(rows.getString(2)).setKind(rows.getString(3)));
                    }
                }
            }
            if (request.hasGrantee() && !request.getGrantee().getName().isBlank()) {
                Principal target = principal(view.connection, engine, request.getGrantee());
                if (out.getPrincipalsList().stream().noneMatch(p -> p.getName().equals(target.getName()) && p.getHost().equals(target.getHost()))) {
                    out.addPrincipals(target);
                }
                var definition = new LinkedHashMap<String, Object>();
                definition.put("principal", target.getName());
                definition.put("host", target.getHost());
                definition.put("kind", target.getKind());
                definition.put("visibility", "Direct grants visible to this connection; inherited/effective privileges and all dynamic privileges are not inferred. Authentication material is never queried.");
                if (engine == Engine.POSTGRESQL) {
                    definition.put("tablePrivileges", rows(view.connection, "SELECT grantor,table_schema,table_name,privilege_type,is_grantable FROM information_schema.table_privileges WHERE grantee=? ORDER BY table_schema,table_name,privilege_type", target.getName(), out));
                    definition.put("schemaPrivileges", rows(view.connection, "SELECT n.nspname AS schema,a.privilege_type,a.is_grantable FROM pg_namespace n CROSS JOIN LATERAL aclexplode(COALESCE(n.nspacl,acldefault('n',n.nspowner))) a JOIN pg_roles r ON r.oid=a.grantee WHERE r.rolname=? ORDER BY n.nspname,a.privilege_type", target.getName(), out));
                    definition.put("databasePrivileges", rows(view.connection, "SELECT d.datname AS database,a.privilege_type,a.is_grantable FROM pg_database d CROSS JOIN LATERAL aclexplode(COALESCE(d.datacl,acldefault('d',d.datdba))) a JOIN pg_roles r ON r.oid=a.grantee WHERE r.rolname=? ORDER BY d.datname,a.privilege_type", target.getName(), out));
                    definition.put("memberships", rows(view.connection, "SELECT r.rolname AS role,m.admin_option,m.inherit_option,m.set_option FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.roleid JOIN pg_roles u ON u.oid=m.member WHERE u.rolname=? ORDER BY r.rolname", target.getName(), out));
                } else {
                    // SHOW GRANTS on MariaDB can include authentication hashes. Use the
                    // privilege catalogs instead and never read mysql.user password fields.
                    String grantee = "'" + target.getName() + "'@'" + target.getHost() + "'";
                    definition.put("globalPrivileges", rows(view.connection, "SELECT privilege_type,is_grantable FROM information_schema.USER_PRIVILEGES WHERE grantee=? ORDER BY privilege_type", grantee, out));
                    definition.put("databasePrivileges", rows(view.connection, "SELECT table_schema,privilege_type,is_grantable FROM information_schema.SCHEMA_PRIVILEGES WHERE grantee=? ORDER BY table_schema,privilege_type", grantee, out));
                    definition.put("tablePrivileges", rows(view.connection, "SELECT table_schema,table_name,privilege_type,is_grantable FROM information_schema.TABLE_PRIVILEGES WHERE grantee=? ORDER BY table_schema,table_name,privilege_type", grantee, out));
                    definition.put("columnPrivileges", rows(view.connection, "SELECT table_schema,table_name,column_name,privilege_type,is_grantable FROM information_schema.COLUMN_PRIVILEGES WHERE grantee=? ORDER BY table_schema,table_name,column_name,privilege_type", grantee, out));
                    String membership = engine == Engine.MYSQL
                        ? "SELECT FROM_USER AS role,FROM_HOST AS host,WITH_ADMIN_OPTION AS delegation FROM mysql.role_edges WHERE TO_USER=? AND TO_HOST=? ORDER BY FROM_USER,FROM_HOST"
                        : "SELECT Role AS role,Admin_option AS delegation FROM mysql.roles_mapping WHERE User=? AND Host=? ORDER BY Role";
                    definition.put("memberships", rows(view.connection, membership, List.of(target.getName(), target.getHost()), out));
                }
                inherited(view.connection, engine, target, definition, out);
                String json = new GsonBuilder().setPrettyPrinting().create().toJson(definition);
                if (json.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > TEXT_LIMIT) {
                    throw new IllegalStateException("Privilege inspection exceeds 1MiB; use a narrower principal or manual catalog query");
                }
                out.setDefinition(json);
            }
            return out.build();
        });
    }

    private static void inherited(Connection connection,Engine engine,Principal target,Map<String,Object> definition,PrivilegeReply.Builder out)throws SQLException {
        if(engine==Engine.POSTGRESQL) {
            definition.put("roleAttributes",rows(connection,"SELECT rolsuper,rolinherit,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls,rolcanlogin,rolconnlimit,rolvaliduntil FROM pg_roles WHERE rolname=?",target.getName(),out));
            definition.put("inheritedRoles",rows(connection,"WITH RECURSIVE role_closure AS (SELECT oid FROM pg_roles WHERE rolname=? UNION SELECT m.roleid FROM pg_auth_members m JOIN role_closure r ON r.oid=m.member) SELECT p.rolname,pg_has_role(?,p.oid,'USAGE') AS automatically_inherited,pg_has_role(?,p.oid,'SET') AS can_set_role FROM role_closure r JOIN pg_roles p ON p.oid=r.oid ORDER BY p.rolname",List.of(target.getName(),target.getName(),target.getName()),out));
            definition.put("effectiveCurrentDatabaseTables",rows(connection,"SELECT n.nspname,c.relname,has_table_privilege(?,c.oid,'SELECT') AS can_select,has_table_privilege(?,c.oid,'INSERT') AS can_insert,has_table_privilege(?,c.oid,'UPDATE') AS can_update,has_table_privilege(?,c.oid,'DELETE') AS can_delete FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind IN ('r','p','v') AND n.nspname NOT IN ('pg_catalog','information_schema') ORDER BY n.nspname,c.relname",List.of(target.getName(),target.getName(),target.getName(),target.getName()),out));
            definition.put("effectivePermissionBoundary","Server has_table_privilege includes ownership, PUBLIC and inherited table grants in this database. Column-only grants, row-level security, function execution, other databases and session SET ROLE context remain separate; booleans do not promise unrestricted data visibility.");
        } else if(engine==Engine.MYSQL) {
            definition.put("inheritedRoles",rows(connection,"WITH RECURSIVE role_closure AS (SELECT FROM_USER AS role,FROM_HOST AS host FROM mysql.role_edges WHERE TO_USER=? AND TO_HOST=? UNION DISTINCT SELECT e.FROM_USER,e.FROM_HOST FROM mysql.role_edges e JOIN role_closure r ON e.TO_USER=r.role AND e.TO_HOST=r.host) SELECT role,host FROM role_closure ORDER BY role,host",List.of(target.getName(),target.getHost()),out));
            definition.put("defaultRoles",rows(connection,"SELECT DEFAULT_ROLE_USER AS role,DEFAULT_ROLE_HOST AS host FROM mysql.default_roles WHERE USER=? AND HOST=? ORDER BY role,host",List.of(target.getName(),target.getHost()),out));
            definition.put("dynamicPrivileges",rows(connection,"SELECT PRIV AS privilege_name,WITH_GRANT_OPTION AS delegation FROM mysql.global_grants WHERE USER=? AND HOST=? ORDER BY PRIV",List.of(target.getName(),target.getHost()),out));
            definition.put("activationBoundary","Membership closure and default roles are explicit catalog evidence. Dynamic/global privileges and grants of inherited roles are inspected independently; active/mandatory-role settings and SQL SECURITY definers can change effective access. No universal effective-access claim is made.");
        } else {
            definition.put("inheritedRoles",rows(connection,"WITH RECURSIVE role_closure AS (SELECT Role AS role FROM mysql.roles_mapping WHERE User=? AND Host=? UNION DISTINCT SELECT m.Role FROM mysql.roles_mapping m JOIN role_closure r ON m.User=r.role AND m.Host='') SELECT role FROM role_closure ORDER BY role",List.of(target.getName(),target.getHost()),out));
            definition.put("defaultRoles",rows(connection,"SELECT default_role FROM mysql.user WHERE User=? AND Host=?",List.of(target.getName(),target.getHost()),out));
            definition.put("activationBoundary","MariaDB roles use exact role identities and explicit default-role activation. Inspect each inherited role's own grants; object definers and active session roles remain relevant. Authentication hashes are never queried.");
        }
    }

    private static List<Map<String,Object>> rows(Connection connection, String sql, String value, PrivilegeReply.Builder out) throws SQLException {
        return rows(connection, sql, List.of(value), out);
    }

    private static List<Map<String,Object>> rows(Connection connection, String sql, List<String> values, PrivilegeReply.Builder out) throws SQLException {
        var records = new ArrayList<Map<String,Object>>();
        try (var statement = connection.prepareStatement(sql)) {
            for (int i=0; i<values.size(); i++) statement.setString(i+1, values.get(i));
            statement.setMaxRows(ROW_LIMIT+1);
            statement.setQueryTimeout(10);
            try (var result = statement.executeQuery()) {
                var metadata = result.getMetaData();
                while (result.next()) {
                    if (records.size()==ROW_LIMIT) { out.setLimited(true); break; }
                    var row = new LinkedHashMap<String,Object>();
                    for (int i=1; i<=metadata.getColumnCount(); i++) row.put(metadata.getColumnLabel(i), result.getObject(i));
                    records.add(row);
                }
            }
        }
        return records;
    }

    private static Principal principal(Connection connection, Engine engine, Principal requested) throws SQLException {
        if (requested.getName().isBlank() || requested.getName().length()>128 || requested.getHost().length()>255) {
            throw new IllegalArgumentException("Choose an existing named principal and its exact host");
        }
        if (engine == Engine.POSTGRESQL && !requested.getHost().isEmpty()) throw new IllegalArgumentException("PostgreSQL roles do not have an account-host component");
        String query = engine == Engine.POSTGRESQL
            ? "SELECT rolname,'' AS host,CASE WHEN rolcanlogin THEN 'login role' ELSE 'role' END FROM pg_roles WHERE rolname=?"
            : engine == Engine.MARIADB
            ? "SELECT User,Host,CASE WHEN is_role='Y' THEN 'role' ELSE 'account' END FROM mysql.user WHERE User=? AND Host=?"
            : "SELECT User,Host,CASE WHEN account_locked='Y' THEN 'locked account / role' ELSE 'account' END FROM mysql.user WHERE User=? AND Host=?";
        try (var statement = connection.prepareStatement(query)) {
            statement.setQueryTimeout(10);
            statement.setString(1, requested.getName());
            if (engine != Engine.POSTGRESQL) statement.setString(2, requested.getHost());
            try (var rows = statement.executeQuery()) {
                if (!rows.next()) throw new IllegalArgumentException("Principal no longer exists or is not visible");
                return Principal.newBuilder().setName(rows.getString(1)).setHost(rows.getString(2)).setKind(rows.getString(3)).build();
            }
        }
    }

    private static String databaseScope(Connection connection, Engine engine, PrivilegeRequest request) throws SQLException {
        if (request.getScope()!=PrivilegeScope.DATABASE_PRIVILEGE || engine==Engine.POSTGRESQL) return request.getSchema();
        String name = request.getSchema();
        if (engine==Engine.MYSQL) {
            try (var statement=connection.createStatement(); var rows=statement.executeQuery("SELECT @@global.partial_revokes")) {
                rows.next();
                if (rows.getBoolean(1)) return name;
            }
        }
        // Database-level GRANT treats _ and % as patterns even inside backticks.
        return name.replace("\\", "\\\\").replace("_", "\\_").replace("%", "\\%");
    }

    public static String sql(Engine engine, PrivilegeRequest request, Principal grantee, Principal role, String databaseScope) {
        var adapter = new JdbcAdapter(engine);
        if (request.getPrivilegesCount()>20) throw new IllegalArgumentException("Choose at most 20 explicit privileges");
        String target = account(adapter, grantee);
        String verb = request.getRevoke() ? "REVOKE " : "GRANT ";
        String direction = request.getRevoke() ? " FROM " : " TO ";
        if (request.getRevoke() && request.getDelegation()) throw new IllegalArgumentException("Choose a full revoke or a grant with delegation; option-only revocation requires explicit native SQL");
        if(request.getScope()==PrivilegeScope.DEFAULT_ROLE) {
            if(engine==Engine.POSTGRESQL)throw new IllegalArgumentException("PostgreSQL uses membership inheritance and explicit SET ROLE; default-role account settings are a MySQL/MariaDB workflow");
            if(request.getPrivilegesCount()!=0||request.getDelegation())throw new IllegalArgumentException("Default role has no object privileges or delegation option");
            return "SET DEFAULT ROLE "+(request.getRevoke()?"NONE":account(adapter,role))+(engine==Engine.MYSQL?" TO ":" FOR ")+target+";";
        }
        if (request.getScope()==PrivilegeScope.ROLE_MEMBERSHIP) {
            if (request.getPrivilegesCount()!=0) throw new IllegalArgumentException("Role membership has no object-privilege list");
            return verb + account(adapter, role) + direction + target + (request.getDelegation() ? " WITH ADMIN OPTION" : "") + ";";
        }
        adapter.quote(request.getSchema()); // Object grants must have an explicit schema/database target.
        Set<String> supported = switch(request.getScope()) {
            case TABLE_PRIVILEGE -> engine==Engine.POSTGRESQL ? Set.of("SELECT","INSERT","UPDATE","DELETE","TRUNCATE","REFERENCES","TRIGGER") : Set.of("SELECT","INSERT","UPDATE","DELETE","REFERENCES","INDEX","ALTER","DROP","TRIGGER");
            case SCHEMA_PRIVILEGE -> {
                if (engine!=Engine.POSTGRESQL) throw new IllegalArgumentException("MySQL/MariaDB use database scope, not PostgreSQL schema privileges");
                yield Set.of("USAGE","CREATE");
            }
            case DATABASE_PRIVILEGE -> engine==Engine.POSTGRESQL ? Set.of("CONNECT","CREATE","TEMPORARY") : Set.of("SELECT","INSERT","UPDATE","DELETE","CREATE","DROP","REFERENCES","INDEX","ALTER","CREATE TEMPORARY TABLES","LOCK TABLES","EXECUTE","CREATE VIEW","SHOW VIEW","CREATE ROUTINE","ALTER ROUTINE","EVENT","TRIGGER");
            default -> throw new IllegalArgumentException("Invalid privilege scope");
        };
        var privileges = new TreeSet<String>();
        for (String value : request.getPrivilegesList()) {
            if (value.length()>64) throw new IllegalArgumentException("Privilege name exceeds 64 characters");
            String privilege=value.trim().toUpperCase(Locale.ROOT);
            if (!supported.contains(privilege)) throw new IllegalArgumentException("Choose privileges supported by the selected engine and scope");
            privileges.add(privilege);
        }
        if (privileges.isEmpty() || privileges.size()>20) throw new IllegalArgumentException("Choose explicit privileges");
        String object = switch(request.getScope()) {
            case TABLE_PRIVILEGE -> (engine==Engine.POSTGRESQL ? "TABLE " : "") + adapter.table("",request.getSchema(),request.getTable());
            case SCHEMA_PRIVILEGE -> "SCHEMA " + adapter.quote(request.getSchema());
            case DATABASE_PRIVILEGE -> engine==Engine.POSTGRESQL ? "DATABASE "+adapter.quote(request.getSchema()) : adapter.quote(databaseScope)+".*";
            default -> throw new IllegalArgumentException("Invalid object scope");
        };
        return verb + String.join(", ",privileges) + " ON " + object + direction + target + (request.getDelegation() ? " WITH GRANT OPTION" : "") + ";";
    }

    private static String account(JdbcAdapter adapter, Principal principal) {
        return adapter.quote(principal.getName()) + (adapter.engine()==Engine.POSTGRESQL || adapter.engine()==Engine.MARIADB && principal.getKind().equals("role") ? "" : "@"+adapter.quote(principal.getHost()));
    }
}
