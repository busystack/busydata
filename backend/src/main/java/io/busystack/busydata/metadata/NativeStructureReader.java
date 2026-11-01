package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Engine/JDBC adapter boundary. No UI labels are parsed into identifiers. */
public final class NativeStructureReader {
    private NativeStructureReader(){}
    private static String text(String value){return Objects.toString(value,"");}
    private static void check(){if(io.grpc.Context.current().isCancelled()||Thread.currentThread().isInterrupted())throw new java.util.concurrent.CancellationException("Metadata refresh cancelled");}
    /** Native ownership and relkind protect the JDBC TEMP category admission. */
    private static String ownedPostgresTemporaryKind(SessionRegistry.Session session,String schema,String table)throws SQLException {
        try(var statement=session.adapter.catalogStatement(session.connection,"SELECT c.relkind::text,c.relpersistence::text,n.oid=pg_catalog.pg_my_temp_schema() FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")) {
            statement.setString(1,schema);statement.setString(2,table);
            try(var rows=statement.executeQuery()) {
                check();if(!rows.next())return "";String kind=rows.getString(1);
                if(!"t".equals(rows.getString(2))||!rows.getBoolean(3))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
                if(rows.next())throw new SQLException("Exact native temporary relation is ambiguous");return kind;
            }
        }
    }
    public static IdentifierRules rules(SessionRegistry.Session view,IdentifierRules previous,long deadline)throws SQLException {
        return NativeIdentifierCaseReader.read(view,previous,deadline);
    }
    private static void preflight(SessionRegistry.Session session,String catalog,String schema,String table)throws SQLException {
        String namespace=session.profile.getEngine()==Engine.POSTGRESQL?schema:catalog;
        String predicate=session.profile.getEngine()==Engine.POSTGRESQL?"TABLE_SCHEMA=? AND TABLE_NAME=?":"BINARY TABLE_SCHEMA=BINARY ? AND BINARY TABLE_NAME=BINARY ?";
        try(var query=session.adapter.catalogStatement(session.connection,"SELECT COUNT(*),COALESCE(SUM(OCTET_LENGTH(COALESCE(COLUMN_DEFAULT,''))+OCTET_LENGTH(COLUMN_NAME)+OCTET_LENGTH(DATA_TYPE)),0),COALESCE(MAX(OCTET_LENGTH(COLUMN_DEFAULT)),0) FROM information_schema.COLUMNS WHERE "+predicate)) {
            query.setString(1,namespace);query.setString(2,table);
            try(var rows=query.executeQuery()){if(!rows.next())throw new SQLException("Column metadata resource inspection unavailable");if(rows.getLong(1)>2048||rows.getLong(2)>4_194_304||rows.getLong(3)>1_048_576)throw new IllegalArgumentException("Table metadata exceeds its byte/column budget");}
        }
    }
    public static TableStructure inspect(SessionRegistry.Session session,String requestedCatalog,String requestedSchema,String table)throws Exception {
        return inspect(session,requestedCatalog,requestedSchema,table,true);
    }
    public static TableStructure inspect(SessionRegistry.Session session,String requestedCatalog,String requestedSchema,String table,boolean requireEditable)throws Exception {
        return inspect(session,requestedCatalog,requestedSchema,table,requireEditable,ignored->{});
    }
    public static TableStructure inspect(SessionRegistry.Session session,String requestedCatalog,String requestedSchema,String table,boolean requireEditable,java.util.function.LongConsumer allocations)throws Exception {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;String catalog=requestedCatalog.isEmpty()?session.context.catalog():requestedCatalog;
        String schema=requestedSchema.isEmpty()?(pg?session.context.schema():catalog):requestedSchema;
        if(pg&&!catalog.equals(session.context.catalog()))throw new IllegalArgumentException("Table inspection requires its physical PostgreSQL database");
        if(!pg&&!catalog.equals(schema))throw new IllegalArgumentException("MySQL/MariaDB database and schema scopes must agree");
        for(String name:List.of(catalog,schema,table))if(name.isEmpty()||name.length()>256||name.indexOf('\0')>=0)throw new IllegalArgumentException("Exact table metadata identity required");
        boolean ownedTemporary=pg&&!session.context.temporarySchema().isEmpty()&&schema.equals(session.context.temporarySchema());
        if(pg&&schema.startsWith("pg_temp_")&&!ownedTemporary)throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        if(ownedTemporary&&!session.lock.isHeldByCurrentThread())throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.INVALID_OWNER);
        // pgJDBC reports ordinary and partitioned pg_temp relations using its
        // TEMPORARY TABLE category. Only the exact physical owner's namespace
        // can qualify; the driver's pg_temp_ pattern is not ownership proof.
        String temporaryKind=ownedTemporary?ownedPostgresTemporaryKind(session,schema,table):"";
        check();preflight(session,catalog,schema,table);ColumnMetadataReader.preflight(session,schema,table);
        if(pg)allocations.accept(JdbcMetadataPatterns.postgresTableBytes(session,schema,table));
        var metadata=session.connection.getMetaData();String jdbcCatalog=pg?catalog:catalog,jdbcSchema=pg?schema:null;
        boolean base=false;String engine="";
        if(pg){String escape=metadata.getSearchStringEscape();String[] categories=requireEditable?new String[]{ownedTemporary?"TEMPORARY TABLE":"TABLE"}:null;
        try(var rows=metadata.getTables(jdbcCatalog,JdbcMetadataPatterns.exactPattern(schema,escape),JdbcMetadataPatterns.exactPattern(table,escape),categories)){
            while(rows.next()){check();if(table.equals(rows.getString("TABLE_NAME"))&&schema.equals(rows.getString("TABLE_SCHEM"))
                    &&(ownedTemporary?catalog.equals(rows.getString("TABLE_CAT"))&&"TEMPORARY TABLE".equals(rows.getString("TABLE_TYPE"))
                        &&(temporaryKind.equals("r")||!requireEditable&&temporaryKind.equals("p"))
                        :Set.of("TABLE","PARTITIONED TABLE","FOREIGN TABLE").contains(rows.getString("TABLE_TYPE"))))base=true;}
        }}else try(var query=session.adapter.catalogStatement(session.connection,"SELECT ENGINE,TABLE_TYPE FROM information_schema.TABLES WHERE BINARY TABLE_SCHEMA=BINARY ? AND BINARY TABLE_NAME=BINARY ?")){
            query.setString(1,catalog);query.setString(2,table);try(var rows=query.executeQuery()){if(!rows.next())throw new IllegalArgumentException("The table is missing or inaccessible");engine=text(rows.getString(1));base="BASE TABLE".equals(rows.getString(2));if(rows.next())throw new SQLException("Exact table identity is ambiguous");if(requireEditable&&!"InnoDB".equalsIgnoreCase(engine))throw new IllegalArgumentException("Atomic editing requires an InnoDB table");}
        }
        if(!base)throw new IllegalArgumentException("Editing requires a base table, not a view or ambiguous relation");
        var jdbcColumns=JdbcMetadataPatterns.columns(session,catalog,schema,table,allocations);
        // Durable recovery has one transport-facts shape, unchanged from schema 2.
        // Native temporal precision/default normalization must not rewrite it.
        var recoveryTypes=new TreeMap<String,Integer>();var recoveryDetails=new TreeMap<String,List<String>>();var recoveryGenerated=new TreeSet<String>();
        for(var column:jdbcColumns){var p=column.getPropertiesMap();String nullable=p.getOrDefault("nullable","UNKNOWN");recoveryTypes.put(column.getName(),Integer.parseInt(p.get("jdbcType")));
            recoveryDetails.put(column.getName(),List.of(p.getOrDefault("jdbcNativeType",""),p.getOrDefault("precision",""),p.getOrDefault("scale",""),nullable.equals("NO")?"0":nullable.equals("YES")?"1":"2",p.getOrDefault("default",""),p.getOrDefault("ordinal",""),p.getOrDefault("generated",""),p.getOrDefault("autoIncrement","")));
            if(p.getOrDefault("generated","").equals("YES")||p.getOrDefault("autoIncrement","").equals("YES"))recoveryGenerated.add(column.getName());
        }
        var nativeColumns=new ArrayList<SchemaObject>();for(var column:ColumnMetadataReader.enrich(session,jdbcColumns,schema,table,allocations))nativeColumns.add(column.toBuilder().putProperties("tableEngine",engine).build());
        var types=new TreeMap<String,Integer>();var generated=new TreeSet<String>();var nonNull=new TreeSet<String>();var details=new TreeMap<String,List<String>>();
        for(var column:nativeColumns){check();String name=column.getName();var properties=column.getPropertiesMap();types.put(name,Integer.parseInt(properties.get("jdbcType")));String nullable=properties.getOrDefault("nullable","UNKNOWN");
            details.put(name,List.of(properties.getOrDefault("jdbcNativeType",""),properties.getOrDefault("precision",""),properties.getOrDefault("scale",""),nullable.equals("NO")?"0":nullable.equals("YES")?"1":"2",properties.getOrDefault("default",""),properties.getOrDefault("ordinal",""),properties.getOrDefault("generated",""),properties.getOrDefault("autoIncrement","")));
            if(nullable.equals("NO"))nonNull.add(name);if(properties.getOrDefault("generated","").equals("YES")||properties.getOrDefault("autoIncrement","").equals("YES"))generated.add(name);
        }
        if(types.isEmpty())throw new IllegalArgumentException("Table columns are unavailable");
        var primary=new TreeSet<String>();var primaryOrder=new TreeMap<Integer,String>();
        try(var rows=metadata.getPrimaryKeys(jdbcCatalog,jdbcSchema,table)) {
            while(rows.next()){check();if(!table.equals(rows.getString("TABLE_NAME"))||pg&&!schema.equals(rows.getString("TABLE_SCHEM")))continue;if(primaryOrder.size()>=2048)throw new IllegalArgumentException("Primary key metadata budget exceeded");primary.add(rows.getString("COLUMN_NAME"));primaryOrder.put(rows.getInt("KEY_SEQ"),rows.getString("COLUMN_NAME"));}
        }
        var identities=new ArrayList<Set<String>>();
        if(!primary.isEmpty())identities.add(Set.copyOf(primary));
        var unique=new TreeMap<String,Set<String>>();var invalid=new HashSet<String>();int indexRows=0;
        try(var rows=metadata.getIndexInfo(jdbcCatalog,jdbcSchema,table,true,false)) {
            while(rows.next()) {
                check();if(++indexRows>32768)throw new IllegalArgumentException("Unique index metadata budget exceeded");
                if(!table.equals(rows.getString("TABLE_NAME"))||pg&&!schema.equals(rows.getString("TABLE_SCHEM")))continue;
                if(rows.getShort("TYPE")==DatabaseMetaData.tableIndexStatistic||rows.getBoolean("NON_UNIQUE"))continue;
                String index=rows.getString("INDEX_NAME"),column=rows.getString("COLUMN_NAME");if(index==null)continue;
                unique.computeIfAbsent(index,k->new TreeSet<>());
                if(column==null||!nonNull.contains(column))invalid.add(index);else unique.get(index).add(column);
                try{if(rows.getString("FILTER_CONDITION")!=null&&!rows.getString("FILTER_CONDITION").isBlank())invalid.add(index);}catch(SQLFeatureNotSupportedException ignored){}
            }
        }
        for(var entry:unique.entrySet()) {
            if(!invalid.contains(entry.getKey())&&!entry.getValue().isEmpty())identities.add(Set.copyOf(entry.getValue()));
        }
        // A unique index can provide row identity without being a native
        // constraint. Only the shared native reader declares constraints.
        var constraints=StructuralDetails.readConstraints(session,catalog,schema,table);
        var indexes=NativeIndexReader.read(session,catalog,schema,table);
        var nativeUnique=new HashSet<String>();for(var index:indexes)if(index.getPropertiesOrDefault("uniqueness","").equals("UNIQUE"))nativeUnique.add(index.getName());
        if(!nativeUnique.equals(unique.keySet()))throw new SQLException("Unique index visibility changed during central table inspection");
        var relationships=foreignKeys(session,catalog,schema,table);
        var generation=NativeRelationReader.inspect(session,catalog,schema,table);
        String signature=MetadataIdentity.digest(MetadataFingerprint.table(types,details,generated,primary,unique,invalid,nativeColumns,relationships,NativeTypeReader.tableFingerprint(session,schema,table),StructuralDetails.constraintFingerprint(session,schema,table)),generation.getOrDefault("nativeGeneration",""),generation.getOrDefault("nativeGenerationAvailability","UNAVAILABLE"),MetadataFingerprint.objects(indexes));
        String recoverySignature=recoveryTypes.toString()+recoveryDetails+recoveryGenerated+primary+unique+invalid;
        return new TableStructure(types,generated,identities,signature,recoverySignature,generation.getOrDefault("nativeGeneration",""),generation.getOrDefault("nativeGenerationAvailability","UNAVAILABLE"),nativeColumns,constraints,relationships,indexes);
    }
    public static List<SchemaObject> foreignKeys(SessionRegistry.Session session,String catalog,String schema,String table)throws SQLException {
        boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;var keys=new TreeMap<String,TreeMap<Integer,Map<String,String>>>();int count=0;
        try(var rows=session.connection.getMetaData().getImportedKeys(catalog,pg?schema:null,table)) {
            while(rows.next()) {
                check();if(++count>32768)throw new IllegalArgumentException("Foreign-key component budget exceeded");
                if(!table.equals(rows.getString("FKTABLE_NAME"))||pg&&!schema.equals(rows.getString("FKTABLE_SCHEM")))continue;
                String name=rows.getString("FK_NAME");if(name==null)throw new SQLException("Unnamed foreign-key identity is unavailable");
                var value=new HashMap<String,String>();
                for(String field:List.of("FKCOLUMN_NAME","PKCOLUMN_NAME","PKTABLE_CAT","PKTABLE_SCHEM","PKTABLE_NAME","UPDATE_RULE","DELETE_RULE","DEFERRABILITY"))value.put(field,text(rows.getString(field)));
                int ordinal=rows.getInt("KEY_SEQ");if(ordinal<1||ordinal>2048||keys.computeIfAbsent(name,k->new TreeMap<>()).put(ordinal,value)!=null)throw new SQLException("Foreign-key component identity is inconsistent");
            }
        }
        var result=new ArrayList<SchemaObject>();
        for(var entry:keys.entrySet()) {
            var first=entry.getValue().firstEntry().getValue();
            var out=SchemaObject.newBuilder().setCatalog(catalog).setSchema(schema).setTable(table).setName(entry.getKey()).setKind(ObjectKind.FOREIGN_KEY)
                .putProperties("columnCount",Integer.toString(entry.getValue().size())).putProperties("referencedCatalog",first.get("PKTABLE_CAT").isEmpty()?catalog:first.get("PKTABLE_CAT"))
                .putProperties("referencedSchema",pg?first.get("PKTABLE_SCHEM"):first.get("PKTABLE_CAT")).putProperties("referencedTable",first.get("PKTABLE_NAME"))
                .putProperties("onUpdate",first.get("UPDATE_RULE")).putProperties("onDelete",first.get("DELETE_RULE")).putProperties("deferrability",first.get("DEFERRABILITY"));
            int position=1;
            for(var component:entry.getValue().entrySet()) {
                if(component.getKey()!=position)throw new SQLException("Foreign-key component order is incomplete");
                var value=component.getValue();
                for(String field:List.of("PKTABLE_CAT","PKTABLE_SCHEM","PKTABLE_NAME","UPDATE_RULE","DELETE_RULE"))if(!Objects.equals(first.get(field),value.get(field)))throw new SQLException("Foreign-key target identity is inconsistent");
                out.putProperties("column."+(position-1),value.get("FKCOLUMN_NAME")).putProperties("referencedColumn."+(position-1),value.get("PKCOLUMN_NAME"));position++;
            }
            result.add(out.putProperties("relationshipVerified","true").build());
        }
        return List.copyOf(result);
    }
    public record ReferencingRelation(String catalog,String schema,String table){}
    public static Set<ReferencingRelation> referencingRelations(SessionRegistry.Session session,String catalog,String schema,String table)throws SQLException {
        var result=new LinkedHashSet<ReferencingRelation>();int count=0;boolean pg=session.profile.getEngine()==Engine.POSTGRESQL;
        try(var rows=session.connection.getMetaData().getExportedKeys(catalog,pg?schema:null,table)) {
            while(rows.next()) {
                check();if(++count>32768)throw new IllegalArgumentException("Incoming foreign-key scan component budget exceeded");
                if(!table.equals(rows.getString("PKTABLE_NAME"))||pg&&!schema.equals(rows.getString("PKTABLE_SCHEM")))continue;
                String targetCatalog=text(rows.getString("FKTABLE_CAT"));if(targetCatalog.isEmpty())targetCatalog=catalog;
                String targetSchema=pg?text(rows.getString("FKTABLE_SCHEM")):targetCatalog;
                String targetTable=text(rows.getString("FKTABLE_NAME"));if(targetTable.isEmpty())throw new SQLException("Incoming foreign-key owner identity unavailable");
                result.add(new ReferencingRelation(targetCatalog,targetSchema,targetTable));
            }
        }
        return Set.copyOf(result);
    }
}
