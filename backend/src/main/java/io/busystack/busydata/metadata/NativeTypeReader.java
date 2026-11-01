package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** PostgreSQL named types; MySQL/MariaDB enum/set remain exact column-native types. */
public final class NativeTypeReader {
    private NativeTypeReader(){}
    /** Aggregate the same catalog type dependencies without transferring type definitions. */
    public static Map<String,String> namespaceFingerprints(SessionRegistry.Session session,String schema,long deadline)throws SQLException {
        return namespaceFingerprints(session,schema,"",deadline);
    }
    public static Map<String,String> namespaceFingerprints(SessionRegistry.Session session,String schema,String table,long deadline)throws SQLException {
        if(session.profile.getEngine()!=Engine.POSTGRESQL)return Map.of();
        String sql="WITH RECURSIVE relations AS (SELECT c.oid,c.relname FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relkind IN ('r','p','f','v','m')),relevant_types(relation,oid,depth) AS (SELECT DISTINCT r.oid,a.atttypid,0 FROM relations r JOIN pg_catalog.pg_attribute a ON a.attrelid=r.oid WHERE a.attnum>0 AND NOT a.attisdropped UNION SELECT r.relation,dependency.oid,r.depth+1 FROM relevant_types r JOIN pg_catalog.pg_type t ON t.oid=r.oid CROSS JOIN LATERAL unnest(ARRAY[t.typbasetype,t.typelem]) dependency(oid) WHERE dependency.oid<>0 AND r.depth<32),ids AS (SELECT DISTINCT relation,oid FROM relevant_types),evidence AS (SELECT i.relation,'type' kind,t.oid::text identity,ROW(t.*)::text content FROM ids i JOIN pg_catalog.pg_type t ON t.oid=i.oid UNION ALL SELECT i.relation,'constraint',c.oid::text,ROW(c.*)::text FROM ids i JOIN pg_catalog.pg_constraint c ON c.contypid=i.oid UNION ALL SELECT i.relation,'enum',e.oid::text,ROW(e.*)::text FROM ids i JOIN pg_catalog.pg_enum e ON e.enumtypid=i.oid),fingerprints AS (SELECT relation,COUNT(*) count,bit_xor(hashtextextended(ROW(kind,identity,content)::text,0)) checksum FROM evidence GROUP BY relation) SELECT r.relname,COALESCE(f.count,0)::text||':'||COALESCE(f.checksum,0)::text,EXISTS(SELECT 1 FROM relevant_types d JOIN pg_catalog.pg_type t ON t.oid=d.oid WHERE d.relation=r.oid AND d.depth=32 AND (t.typbasetype<>0 OR t.typelem<>0)) limited FROM relations r LEFT JOIN fingerprints f ON f.relation=r.oid";
        if(!table.isEmpty())sql=sql.replace("c.relkind IN ('r','p','f','v','m')", "c.relkind IN ('r','p','f','v','m') AND c.relname=?");
        var result=new HashMap<String,String>();long bytes=0;
        try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setMaxRows(MetadataSnapshot.MAX_OBJECTS+1);statement.setString(1,schema);if(!table.isEmpty())statement.setString(2,table);
            try(var rows=statement.executeQuery()){while(rows.next()) {
                if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Metadata dependency scan cancelled");
                if(System.nanoTime()>deadline)throw new SQLTimeoutException("Native type dependency scan deadline exceeded","HYT00");
                String name=rows.getString(1),fingerprint=rows.getString(2);
                if(name==null||name.length()>256||result.size()>=MetadataSnapshot.MAX_OBJECTS||(bytes+=2L*(name.length()+fingerprint.length())+80)>8_388_608)throw new IllegalArgumentException("Native type dependency fingerprint budget exceeded");
                if(rows.getBoolean(3))throw new IllegalArgumentException("Native type dependency depth budget exceeded");
                if(result.put(name,fingerprint)!=null)throw new SQLException("Duplicate native type dependency identity");
            }}
        }
        return Map.copyOf(result);
    }
    public static String tableFingerprint(SessionRegistry.Session session,String schema,String table)throws SQLException {
        if(session.profile.getEngine()!=Engine.POSTGRESQL)return "column-native-type-declarations";
        String sql="WITH RECURSIVE relevant_types(oid,depth) AS (SELECT DISTINCT a.atttypid,0 FROM pg_catalog.pg_attribute a JOIN pg_catalog.pg_class t ON t.oid=a.attrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND t.relname=? AND a.attnum>0 AND NOT a.attisdropped UNION ALL SELECT dependency.oid,r.depth+1 FROM relevant_types r JOIN pg_catalog.pg_type t ON t.oid=r.oid CROSS JOIN LATERAL unnest(ARRAY[t.typbasetype,t.typelem]) dependency(oid) WHERE dependency.oid<>0 AND r.depth<32),ids AS (SELECT DISTINCT oid FROM relevant_types),evidence AS (SELECT 'type' kind,t.oid::text identity,ROW(t.*)::text content FROM pg_catalog.pg_type t WHERE t.oid IN (SELECT oid FROM ids) UNION ALL SELECT 'constraint',c.oid::text,ROW(c.*)::text FROM pg_catalog.pg_constraint c WHERE c.contypid IN (SELECT oid FROM ids) UNION ALL SELECT 'enum',e.oid::text,ROW(e.*)::text FROM pg_catalog.pg_enum e WHERE e.enumtypid IN (SELECT oid FROM ids)) SELECT kind,identity,CASE WHEN OCTET_LENGTH(content)<=65536 THEN content ELSE NULL END content,EXISTS(SELECT 1 FROM relevant_types r JOIN pg_catalog.pg_type t ON t.oid=r.oid WHERE r.depth=32 AND (t.typbasetype<>0 OR t.typelem<>0)) limited FROM evidence ORDER BY kind,identity";
        var parts=new ArrayList<String>();int count=0;long bytes=0;
        try(var statement=session.adapter.catalogStatement(session.connection,sql)) {
            statement.setMaxRows(65537);statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()){while(rows.next()) {
                String content=rows.getString("content");if(++count>65536||content==null||rows.getBoolean("limited")||(bytes+=content.length()*2L)>8_388_608)throw new IllegalArgumentException("Native type dependency evidence exceeds its depth/row/byte budget");
                parts.add(rows.getString("kind"));parts.add(rows.getString("identity"));parts.add(content);
            }}
        }
        return MetadataIdentity.digest(parts.toArray(String[]::new));
    }
    public static SchemaObject enrich(SessionRegistry.Session session,SchemaObject object,int level)throws SQLException {
        if(session.profile.getEngine()!=Engine.POSTGRESQL)throw new UnsupportedOperationException("This engine has no independently named enum/domain objects");
        var out=object.toBuilder();String nativeId=object.getPropertiesOrThrow("nativeId"),kind=object.getPropertiesOrDefault("nativeTypeKind","");
        var rules=new IdentifierRules(Engine.POSTGRESQL,0);String qualified=rules.quote(object.getSchema())+"."+rules.quote(object.getName());
        if(kind.equals("e")) {
            long count;try(var statement=session.adapter.catalogStatement(session.connection,"SELECT COUNT(*) FROM pg_catalog.pg_enum WHERE enumtypid=?::oid")){statement.setString(1,nativeId);try(var rows=statement.executeQuery()){if(!rows.next())throw new SQLException("Enum label count unavailable");count=rows.getLong(1);}}
            out.putProperties("enumLabelCount",Long.toString(count));
            if(count>1024)return out.putProperties("enumLabelsAvailability","LIMITED").build();
            var literals=new ArrayList<String>();int index=0;
            try(var statement=session.adapter.catalogStatement(session.connection,"SELECT enumlabel,quote_literal(enumlabel) FROM pg_catalog.pg_enum WHERE enumtypid=?::oid ORDER BY enumsortorder")) {
                statement.setString(1,nativeId);try(var rows=statement.executeQuery()){while(rows.next()){if(index>=1024)throw new SQLException("Enum labels changed during introspection");out.putProperties("enumLabel."+index++,rows.getString(1));literals.add(rows.getString(2));}}
            }
            if(index!=count)throw new SQLException("Enum labels changed during introspection");out.putProperties("enumLabelsAvailability","AVAILABLE");
            if(level==3)out.setDefinition("CREATE TYPE "+qualified+" AS ENUM ("+String.join(", ",literals)+");").putProperties("sourceAvailability","PARTIAL").putProperties("sourceProvenance","generated native enum structure; ownership and grants require separate inspection");
        }else if(kind.equals("d")) {
            var constraints=new ArrayList<String>();int index=0;
            try(var statement=session.adapter.catalogStatement(session.connection,"SELECT conname,CASE WHEN OCTET_LENGTH(pg_get_constraintdef(oid,true))<=65536 THEN pg_get_constraintdef(oid,true) ELSE NULL END definition FROM pg_catalog.pg_constraint WHERE contypid=?::oid ORDER BY conname")) {
                statement.setString(1,nativeId);try(var rows=statement.executeQuery()){while(rows.next()){if(index>=1024)throw new IllegalArgumentException("Domain constraint budget exceeded");String definition=rows.getString(2);if(definition==null){out.putProperties("domainConstraintsAvailability","LIMITED");continue;}out.putProperties("domainConstraint."+index+".name",rows.getString(1)).putProperties("domainConstraint."+index+".definition",definition);constraints.add("CONSTRAINT "+rules.quote(rows.getString(1))+" "+definition);index++;}}
            }
            out.putProperties("domainConstraintCount",Integer.toString(index));if(!out.containsProperties("domainConstraintsAvailability"))out.putProperties("domainConstraintsAvailability","AVAILABLE");
            if(level==3) {
                String ddl="CREATE DOMAIN "+qualified+" AS "+object.getPropertiesOrDefault("baseType","");
                if(!object.getPropertiesOrDefault("default","").isEmpty())ddl+=" DEFAULT "+object.getPropertiesOrThrow("default");
                if(object.getPropertiesOrDefault("notNull","").equals("true"))ddl+=" NOT NULL";
                if(!constraints.isEmpty())ddl+=" "+String.join(" ",constraints);
                out.setDefinition(ddl+";").putProperties("sourceAvailability","PARTIAL").putProperties("sourceProvenance","generated native domain structure; ownership, grants and explicit collation require separate inspection");
            }
        }else if(level==3)out.putProperties("sourceAvailability","UNSUPPORTED").putProperties("sourceProvenance","This native type kind has no safe canonical source extractor");
        return out.build();
    }
}
