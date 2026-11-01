package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Exact structural components; display column lists never become semantic input. */
public final class StructuralDetails {
    private StructuralDetails(){}
    private record ConstraintKey(String name,String type){}
    public static String constraintFingerprint(SessionRegistry.Session session,String schema,String table)throws SQLException {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        String sql=pg?"SELECT c.conname name,c.contype::text kind,CASE WHEN OCTET_LENGTH(ROW(c.*)::text)<=65536 THEN ROW(c.*)::text ELSE NULL END evidence FROM pg_catalog.pg_constraint c JOIN pg_catalog.pg_class t ON t.oid=c.conrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND t.relname=? ORDER BY c.conname,c.oid":
            "SELECT tc.CONSTRAINT_NAME name,tc.CONSTRAINT_TYPE kind,CONCAT_WS(CHAR(0),COALESCE(SHA2(cc.CHECK_CLAUSE,256),''),COALESCE(rc.UPDATE_RULE,''),COALESCE(rc.DELETE_RULE,''),COALESCE(rc.MATCH_OPTION,'')) evidence FROM information_schema.TABLE_CONSTRAINTS tc LEFT JOIN information_schema.CHECK_CONSTRAINTS cc ON tc.CONSTRAINT_TYPE='CHECK' AND BINARY cc.CONSTRAINT_SCHEMA=BINARY tc.CONSTRAINT_SCHEMA AND BINARY cc.CONSTRAINT_NAME=BINARY tc.CONSTRAINT_NAME"+(session.profile.getEngine()==Engine.MARIADB?" AND BINARY cc.TABLE_NAME=BINARY tc.TABLE_NAME":"")+" LEFT JOIN information_schema.REFERENTIAL_CONSTRAINTS rc ON tc.CONSTRAINT_TYPE='FOREIGN KEY' AND BINARY rc.CONSTRAINT_SCHEMA=BINARY tc.CONSTRAINT_SCHEMA AND BINARY rc.CONSTRAINT_NAME=BINARY tc.CONSTRAINT_NAME AND BINARY rc.TABLE_NAME=BINARY tc.TABLE_NAME WHERE BINARY tc.TABLE_SCHEMA=BINARY ? AND BINARY tc.TABLE_NAME=BINARY ? ORDER BY BINARY tc.CONSTRAINT_NAME,BINARY tc.CONSTRAINT_TYPE";
        var parts=new ArrayList<String>();int count=0;long bytes=0;
        try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setMaxRows(32769);statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()){while(rows.next()) {
                String evidence=rows.getString("evidence");if(++count>32768||evidence==null||(bytes+=evidence.length()*2L)>8_388_608)throw new IllegalArgumentException("Constraint fingerprint evidence exceeds its byte/row budget");
                parts.add(rows.getString("name"));parts.add(rows.getString("kind"));parts.add(evidence);
            }}
        }
        return MetadataIdentity.digest(parts.toArray(String[]::new));
    }
    @FunctionalInterface private interface ConstraintRows<T>{T read(ResultSet rows)throws SQLException;}
    private static <T> T readConstraintRows(SessionRegistry.Session session,String schema,String table,ConstraintRows<T> read)throws SQLException {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        String sql=pg?"SELECT con.conname name,con.contype::text type,con.oid::text native_id,con.condeferrable::text deferrable,con.condeferred::text initially_deferred,con.convalidated::text validated,key.position ordinal,a.attname column_name,CASE WHEN OCTET_LENGTH(pg_get_constraintdef(con.oid,true))<=65536 THEN pg_get_constraintdef(con.oid,true) ELSE NULL END expression, OCTET_LENGTH(pg_get_constraintdef(con.oid,true)) expression_bytes FROM pg_catalog.pg_constraint con JOIN pg_catalog.pg_class t ON t.oid=con.conrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace LEFT JOIN LATERAL unnest(con.conkey) WITH ORDINALITY key(number,position) ON true LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid=t.oid AND a.attnum=key.number WHERE n.nspname=? AND t.relname=? ORDER BY con.conname,con.oid,key.position":
            "SELECT tc.CONSTRAINT_NAME name,tc.CONSTRAINT_TYPE type,'' native_id,'false' deferrable,'false' initially_deferred,'true' validated,k.ORDINAL_POSITION ordinal,k.COLUMN_NAME column_name,CASE WHEN OCTET_LENGTH(cc.CHECK_CLAUSE)<=65536 THEN cc.CHECK_CLAUSE ELSE NULL END expression,OCTET_LENGTH(cc.CHECK_CLAUSE) expression_bytes FROM information_schema.TABLE_CONSTRAINTS tc LEFT JOIN information_schema.KEY_COLUMN_USAGE k ON (tc.CONSTRAINT_TYPE='FOREIGN KEY' AND k.REFERENCED_TABLE_NAME IS NOT NULL OR tc.CONSTRAINT_TYPE IN ('PRIMARY KEY','UNIQUE') AND k.REFERENCED_TABLE_NAME IS NULL) AND BINARY k.CONSTRAINT_SCHEMA=BINARY tc.CONSTRAINT_SCHEMA AND BINARY k.TABLE_NAME=BINARY tc.TABLE_NAME AND BINARY k.CONSTRAINT_NAME=BINARY tc.CONSTRAINT_NAME LEFT JOIN information_schema.CHECK_CONSTRAINTS cc ON tc.CONSTRAINT_TYPE='CHECK' AND BINARY cc.CONSTRAINT_SCHEMA=BINARY tc.CONSTRAINT_SCHEMA AND BINARY cc.CONSTRAINT_NAME=BINARY tc.CONSTRAINT_NAME"+(session.profile.getEngine()==Engine.MARIADB?" AND BINARY cc.TABLE_NAME=BINARY tc.TABLE_NAME":"")+" WHERE BINARY tc.TABLE_SCHEMA=BINARY ? AND BINARY tc.TABLE_NAME=BINARY ? ORDER BY BINARY tc.CONSTRAINT_NAME,BINARY tc.CONSTRAINT_TYPE,k.ORDINAL_POSITION";
        try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setMaxRows(32769);statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()){return read.read(rows);}
        }
    }
    public static List<SchemaObject> constraints(SessionRegistry.Session session,List<SchemaObject> objects,String schema,String table)throws SQLException {
        return readConstraintRows(session,schema,table,rows->constraintComponents(objects,rows));
    }
    /** Actual native constraints, never declarations inferred from JDBC indexes.
     * Row identity still has its separate primary/unique-index evidence. */
    public static List<SchemaObject> readConstraints(SessionRegistry.Session session,String catalog,String schema,String table)throws SQLException {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        return readConstraintRows(session,schema,table,rows->{
            var detail=constraintDetails(rows);var result=new ArrayList<SchemaObject>();
            for(var entry:detail.entrySet()){
                var key=entry.getKey();var properties=entry.getValue();
                if(pg&&properties.getOrDefault("nativeId","").isEmpty())throw new SQLException("Native PostgreSQL constraint identity unavailable");
                var object=SchemaObject.newBuilder().setCatalog(catalog).setSchema(schema).setTable(table).setName(key.name()).setKind(ObjectKind.CONSTRAINT).putAllProperties(properties);
                if(!pg)object.setIdentifier(key.type());result.add(object.build());
            }return List.copyOf(result);
        });
    }
    /** Exact native type is part of the constraint namespace; display names
     * alone cannot join a CHECK to a same-named key. */
    static List<SchemaObject> constraintComponents(List<SchemaObject> objects,ResultSet rows)throws SQLException {
        var detail=constraintDetails(rows);var result=new ArrayList<SchemaObject>();
        for(var object:objects){
            var properties=detail.get(new ConstraintKey(object.getName(),object.getPropertiesOrDefault("type","")));
            if(properties==null||object.containsProperties("nativeId")&&properties.containsKey("nativeId")&&!object.getPropertiesOrThrow("nativeId").equals(properties.get("nativeId")))throw new SQLException("Constraint identity changed during introspection");
            result.add(object.toBuilder().putAllProperties(properties).build());
        }return List.copyOf(result);
    }
    private static Map<ConstraintKey,Map<String,String>> constraintDetails(ResultSet rows)throws SQLException {
        var detail=new LinkedHashMap<ConstraintKey,Map<String,String>>();int rowsSeen=0;
        while(rows.next()) {
            if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Constraint introspection cancelled");
            if(++rowsSeen>32768)throw new IllegalArgumentException("Constraint component budget exceeded");
            String name=rows.getString("name"),type=rows.getString("type");if(name==null||type==null||type.isEmpty())throw new SQLException("Constraint type identity unavailable");
            var properties=detail.computeIfAbsent(new ConstraintKey(name,type),k->new HashMap<>());
            String nativeId=rows.getString("native_id");if(nativeId!=null&&!nativeId.isEmpty()){
                String previous=properties.putIfAbsent("nativeId",nativeId);if(previous!=null&&!previous.equals(nativeId))throw new SQLException("Native constraint identity is ambiguous");
            }
            for(String field:List.of("type","deferrable","initially_deferred","validated"))properties.put(field,Objects.toString(rows.getString(field),""));
            String column=rows.getString("column_name");int ordinal=rows.getInt("ordinal");if(column!=null&&ordinal>0){properties.put("column."+(ordinal-1),column);properties.put("columnCount",Integer.toString(Math.max(Integer.parseInt(properties.getOrDefault("columnCount","0")),ordinal)));}
            String expression=rows.getString("expression");if(expression!=null)properties.put("expression",expression);
            properties.put("expressionAvailability",rows.getLong("expression_bytes")>65536?"LIMITED":expression==null?"NOT_APPLICABLE":"AVAILABLE");
        }
        return detail;
    }
    public static List<SchemaObject> indexes(SessionRegistry.Session session,List<SchemaObject> objects,String schema,String table)throws SQLException {
        return NativeIndexReader.enrich(session,objects,schema,table);
    }
}
