package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** One bounded native index adapter for Explorer and reviewed table structure. */
public final class NativeIndexReader {
    public static final String FINGERPRINT_VERSION="index-shape-v2";
    private static final int MAX_ROWS=32768,MAX_COMPONENTS=2048,MAX_OBJECT_BYTES=65536;
    private static final long MAX_DETAIL_BYTES=8_388_608;
    private NativeIndexReader(){}
    private static void check(){if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Index introspection cancelled");}
    private static String sql(Engine engine){
        if(engine==Engine.POSTGRESQL)return "SELECT idx.relname name,position ordinal,a.attname column_name,CASE WHEN OCTET_LENGTH(pg_get_indexdef(x.indexrelid,position,true))<=8192 THEN pg_get_indexdef(x.indexrelid,position,true) ELSE NULL END expression,OCTET_LENGTH(pg_get_indexdef(x.indexrelid,position,true)) expression_bytes,(position>x.indnkeyatts)::text included,(x.indkey[position-1]=0)::text expression_part,CASE WHEN position>x.indnkeyatts THEN 'NOT_APPLICABLE' WHEN (x.indoption[position-1]&1)=1 THEN 'DESC' ELSE 'ASC' END ordering,(NOT x.indisunique)::text non_unique,am.amname method,CASE WHEN OCTET_LENGTH(pg_get_expr(x.indpred,x.indrelid))<=8192 THEN pg_get_expr(x.indpred,x.indrelid) ELSE NULL END predicate,OCTET_LENGTH(pg_get_expr(x.indpred,x.indrelid)) predicate_bytes,(x.indpred IS NOT NULL)::text partial,x.indnkeyatts::text key_count,x.indnatts::text total_count,x.indnullsnotdistinct::text nulls_not_distinct,x.indisprimary::text primary_key,x.indisvalid::text valid,x.indisready::text ready,x.indislive::text live,NULL::text prefix_length FROM pg_catalog.pg_index x JOIN pg_catalog.pg_class t ON t.oid=x.indrelid JOIN pg_catalog.pg_class idx ON idx.oid=x.indexrelid JOIN pg_catalog.pg_namespace n ON n.oid=t.relnamespace JOIN pg_catalog.pg_am am ON am.oid=idx.relam CROSS JOIN LATERAL generate_series(1,x.indnatts) position LEFT JOIN pg_catalog.pg_attribute a ON a.attrelid=t.oid AND a.attnum=x.indkey[position-1] WHERE n.nspname=? AND t.relname=? ORDER BY idx.relname,position";
        return "SELECT INDEX_NAME name,SEQ_IN_INDEX ordinal,COLUMN_NAME column_name,"+(engine==Engine.MYSQL?"CASE WHEN OCTET_LENGTH(EXPRESSION)<=8192 THEN EXPRESSION ELSE NULL END expression,OCTET_LENGTH(EXPRESSION) expression_bytes,(EXPRESSION IS NOT NULL)":"NULL expression,0 expression_bytes,false")+" expression_part,'false' included,CASE COLLATION WHEN 'D' THEN 'DESC' WHEN 'A' THEN 'ASC' ELSE 'UNAVAILABLE' END ordering,NON_UNIQUE non_unique,INDEX_TYPE method,NULL predicate,0 predicate_bytes,false `partial`,NULL key_count,NULL total_count,false nulls_not_distinct,(BINARY INDEX_NAME=BINARY 'PRIMARY') primary_key,NULL valid,NULL ready,NULL live,SUB_PART prefix_length FROM information_schema.STATISTICS WHERE BINARY TABLE_SCHEMA=BINARY ? AND BINARY TABLE_NAME=BINARY ? ORDER BY BINARY INDEX_NAME,SEQ_IN_INDEX";
    }
    public static List<SchemaObject> read(SessionRegistry.Session session,String catalog,String schema,String table)throws SQLException {
        check();if(!Set.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB).contains(session.profile.getEngine()))throw new SQLFeatureNotSupportedException("Unsupported native index engine");
        try(var statement=session.adapter.catalogStatement(session.connection,sql(session.profile.getEngine()))){
            statement.setMaxRows(MAX_ROWS+1);statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()){return components(session.profile.getEngine(),catalog,schema,table,rows);}
        }
    }
    public static List<SchemaObject> enrich(SessionRegistry.Session session,List<SchemaObject> objects,String schema,String table)throws SQLException {
        String catalog=session.profile.getEngine()==Engine.POSTGRESQL?session.context.catalog():schema;
        var detail=new HashMap<String,SchemaObject>();for(var object:read(session,catalog,schema,table))detail.put(object.getName(),object);
        var result=new ArrayList<SchemaObject>();
        for(var object:objects){var nativeObject=detail.get(object.getName());if(nativeObject==null)throw new SQLException("Index identity changed during introspection");result.add(object.toBuilder().putAllProperties(nativeObject.getPropertiesMap()).build());}
        return List.copyOf(result);
    }
    private static String require(String value)throws SQLException {if(value==null||value.isEmpty()||value.length()>256||value.indexOf('\0')>=0)throw new SQLException("Index identity unavailable");return value;}
    private static boolean bool(String value)throws SQLException {
        return switch(Objects.toString(value,"")){case "true","t","1"->true;case "false","f","0"->false;default->throw new SQLException("Native index boolean unavailable");};
    }
    private static int count(String value)throws SQLException {try{int count=Integer.parseInt(value);if(count<1||count>MAX_COMPONENTS)throw new NumberFormatException();return count;}catch(RuntimeException invalid){throw new SQLException("Native index component count unavailable");}}
    private static void constant(Map<String,String> properties,String name,String value)throws SQLException {
        String previous=properties.putIfAbsent(name,value);if(previous!=null&&!previous.equals(value))throw new SQLException("Index definition changed during introspection");
    }
    /** Package-visible for adapter tests; engine-specific facts stay out of editor policy. */
    static List<SchemaObject> components(Engine engine,String catalog,String schema,String table,ResultSet rows)throws SQLException {
        if(!Set.of(Engine.POSTGRESQL,Engine.MYSQL,Engine.MARIADB).contains(engine))throw new SQLException("Unsupported native index engine");
        boolean pg=engine==Engine.POSTGRESQL;var detail=new TreeMap<String,Map<String,String>>();var ordinals=new HashMap<String,Set<Integer>>();int seen=0;long bytes=0;
        while(rows.next()){
            check();if(++seen>MAX_ROWS)throw new IllegalArgumentException("Index component budget exceeded");String name=require(rows.getString("name"));
            var properties=detail.computeIfAbsent(name,ignored->new HashMap<>());int ordinal=rows.getInt("ordinal")-1;
            if(ordinal<0||ordinal>=MAX_COMPONENTS||!ordinals.computeIfAbsent(name,ignored->new HashSet<>()).add(ordinal))throw new SQLException("Index component identity is incomplete or duplicated");
            properties.put("columnCount",Integer.toString(Math.max(Integer.parseInt(properties.getOrDefault("columnCount","0")),ordinal+1)));
            String column=rows.getString("column_name"),expression=rows.getString("expression"),predicate=rows.getString("predicate");
            if((expression!=null&&expression.length()>8192)||(predicate!=null&&predicate.length()>8192))throw new IllegalArgumentException("Index expression byte budget exceeded");
            bytes+=2L*(name.length()+Objects.toString(column,"").length()+Objects.toString(expression,"").length()+Objects.toString(predicate,"").length());
            if(bytes>MAX_DETAIL_BYTES)throw new IllegalArgumentException("Index details exceed their byte budget");
            if(column!=null)properties.put("column."+ordinal,require(column));if(expression!=null)properties.put("expression."+ordinal,expression);
            boolean included=bool(rows.getString("included")),expressionPart=bool(rows.getString("expression_part"));
            properties.put("included."+ordinal,Boolean.toString(included));properties.put("keyKind."+ordinal,expressionPart?"EXPRESSION":"COLUMN");
            properties.put("ordering."+ordinal,Objects.toString(rows.getString("ordering"),"UNAVAILABLE"));
            properties.put("expressionAvailability."+ordinal,rows.getLong("expression_bytes")>8192?"LIMITED":expression==null?(expressionPart?"UNAVAILABLE":"NOT_APPLICABLE"):"AVAILABLE");
            String prefix=rows.getString("prefix_length");if(prefix!=null)properties.put("prefixLength."+ordinal,prefix);
            boolean nonUnique=bool(rows.getString("non_unique"));constant(properties,"nonUnique",Objects.toString(rows.getString("non_unique"),""));
            constant(properties,"uniqueness",nonUnique?"NON_UNIQUE":"UNIQUE");constant(properties,"uniquenessAvailability","AVAILABLE");
            boolean primary=bool(rows.getString("primary_key"));if(primary&&nonUnique)throw new SQLException("Native primary index is not unique");constant(properties,"primary",Boolean.toString(primary));
            constant(properties,"uniqueNullsPolicy",nonUnique?"NOT_APPLICABLE":bool(rows.getString("nulls_not_distinct"))?"NOT_DISTINCT":"DISTINCT");
            boolean partial=bool(rows.getString("partial"));constant(properties,"method",Objects.toString(rows.getString("method"),""));constant(properties,"partial",Boolean.toString(partial));
            constant(properties,"predicate",Objects.toString(predicate,""));constant(properties,"predicateAvailability",rows.getLong("predicate_bytes")>8192?"LIMITED":predicate==null?(partial?"UNAVAILABLE":"ABSENT"):"AVAILABLE");
            if(pg){
                constant(properties,"keyColumnCount",Integer.toString(count(rows.getString("key_count"))));constant(properties,"nativeColumnCount",Integer.toString(count(rows.getString("total_count"))));
                for(String field:List.of("valid","ready","live"))constant(properties,field,Boolean.toString(bool(rows.getString(field))));
                constant(properties,"indexStateAvailability","AVAILABLE");
            }else constant(properties,"indexStateAvailability","NOT_EXPOSED");
        }
        var result=new ArrayList<SchemaObject>();
        for(var entry:detail.entrySet()){
            var properties=entry.getValue();int total=count(properties.get("columnCount"));if(ordinals.get(entry.getKey()).size()!=total)throw new SQLException("Index component ordinals are incomplete");
            int keys=pg?count(properties.get("keyColumnCount")):total;
            if(keys>total||pg&&count(properties.get("nativeColumnCount"))!=total)throw new SQLException("Index key and included counts changed during introspection");
            properties.put("keyColumnCount",Integer.toString(keys));
            for(int ordinal=0;ordinal<total;ordinal++){
                if(!ordinals.get(entry.getKey()).contains(ordinal)||Boolean.parseBoolean(properties.get("included."+ordinal))!=(ordinal>=keys))throw new SQLException("Index included-column identity is inconsistent");
                if(!properties.containsKey("column."+ordinal)&&!properties.get("keyKind."+ordinal).equals("EXPRESSION"))throw new SQLException("Native indexed column identity unavailable");
            }
            properties.put("columnComponentsComplete","true");properties.put("indexStructureVersion","2");
            var object=SchemaObject.newBuilder().setCatalog(catalog).setSchema(schema).setTable(table).setName(entry.getKey()).setKind(ObjectKind.INDEX).putAllProperties(properties).build();
            if(object.getSerializedSize()>MAX_OBJECT_BYTES)throw new IllegalArgumentException("Index structure exceeds its object budget");result.add(object);
        }
        return List.copyOf(result);
    }
}
