package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.SQLException;
import java.util.*;

/** Stable native dependencies; no parsing of procedural/dynamic SQL as proof. */
final class CatalogDependencies {
    static JsonObject capture(SessionRegistry.Session session,String schema,SnapshotBudget working)throws SQLException {
        var graph=new TreeMap<String,SortedSet<String>>();
        if(session.profile.getEngine()==Engine.POSTGRESQL) {
            String sql="""
                SELECT DISTINCT 'T:'||t.relname,'R:'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')'
                FROM pg_attrdef a JOIN pg_class t ON t.oid=a.adrelid JOIN pg_namespace tn ON tn.oid=t.relnamespace
                JOIN pg_depend d ON d.classid='pg_attrdef'::regclass AND d.objid=a.oid AND d.refclassid='pg_proc'::regclass
                JOIN pg_proc p ON p.oid=d.refobjid JOIN pg_namespace pn ON pn.oid=p.pronamespace
                WHERE tn.nspname=? AND pn.nspname=?
                UNION
                SELECT DISTINCT 'R:'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
                  CASE WHEN t.relkind='v' THEN 'V:' ELSE 'T:' END||t.relname
                FROM pg_proc p JOIN pg_namespace pn ON pn.oid=p.pronamespace
                JOIN pg_depend d ON d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.refclassid='pg_class'::regclass
                JOIN pg_class t ON t.oid=d.refobjid JOIN pg_namespace tn ON tn.oid=t.relnamespace
                WHERE pn.nspname=? AND tn.nspname=? AND t.relkind IN ('r','v','p')
                UNION
                SELECT DISTINCT 'R:'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')',
                  'R:'||q.proname||'('||pg_get_function_identity_arguments(q.oid)||')'
                FROM pg_proc p JOIN pg_namespace pn ON pn.oid=p.pronamespace
                JOIN pg_depend d ON d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.refclassid='pg_proc'::regclass
                JOIN pg_proc q ON q.oid=d.refobjid JOIN pg_namespace qn ON qn.oid=q.pronamespace
                WHERE pn.nspname=? AND qn.nspname=? AND p.oid<>q.oid
                UNION
                SELECT DISTINCT 'V:'||v.relname,
                  CASE WHEN d.refclassid='pg_proc'::regclass THEN 'R:'||p.proname||'('||pg_get_function_identity_arguments(p.oid)||')'
                       WHEN t.relkind='v' THEN 'V:'||t.relname ELSE 'T:'||t.relname END
                FROM pg_class v JOIN pg_namespace vn ON vn.oid=v.relnamespace JOIN pg_rewrite w ON w.ev_class=v.oid
                JOIN pg_depend d ON d.classid='pg_rewrite'::regclass AND d.objid=w.oid
                LEFT JOIN pg_proc p ON d.refclassid='pg_proc'::regclass AND p.oid=d.refobjid
                LEFT JOIN pg_namespace pn ON pn.oid=p.pronamespace
                LEFT JOIN pg_class t ON d.refclassid='pg_class'::regclass AND t.oid=d.refobjid
                LEFT JOIN pg_namespace tn ON tn.oid=t.relnamespace
                WHERE vn.nspname=? AND v.relkind='v' AND ((pn.nspname=?) OR (tn.nspname=? AND t.oid<>v.oid))
                ORDER BY 1,2
                """;
            try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
                for(int index=1;index<=9;index++)statement.setString(index,schema);
                statement.setQueryTimeout(10);statement.setFetchSize(1);
                try(var rows=statement.executeQuery()) {
                    int count=0;while(rows.next()) {
                        if(++count>10000)throw new IllegalArgumentException("Schema dependency limit is 10,000 edges");
                        graph.computeIfAbsent(working.retain(rows.getString(1)),ignored->new TreeSet<>()).add(working.retain(rows.getString(2)));
                    }
                }
            }
        }
        var output=new JsonObject();graph.forEach((name,dependencies)->{var values=new JsonArray();dependencies.forEach(values::add);output.add(name,values);});return output;
    }
}
