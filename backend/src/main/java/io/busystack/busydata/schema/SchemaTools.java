package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Deterministic, same-engine catalog snapshots. Unsupported changes never get guessed DDL. */
public final class SchemaTools {
    private final io.busystack.busydata.metadata.MetadataPlatform platform;
    public SchemaTools(io.busystack.busydata.metadata.MetadataPlatform platform){this.platform=Objects.requireNonNull(platform);}
    /** The central introspector already owns this independent read-only view. */
    public static SchemaToolResult definitionOnMetadataView(SessionRegistry.Session view,SchemaToolRequest request)throws Exception{return definition(view,request);}
    private static final Gson JSON=new GsonBuilder().serializeNulls().setPrettyPrinting().disableHtmlEscaping().create();
    public SchemaToolResult run(SessionRegistry.Session s,SchemaToolRequest r)throws Exception {
        if(r.getSourceSnapshot().length()>8_388_608||r.getTargetSnapshot().length()>8_388_608)throw new IllegalArgumentException("Snapshot exceeds 8MiB");
        if(r.getAction()==SchemaToolAction.COMPARE_SCHEMA)return compare(s,r);
        if(r.getAction()==SchemaToolAction.OBJECT_DEFINITION) {
            String catalog=r.getCatalog().isEmpty()?(s.profile.getEngine()!=Engine.POSTGRESQL&&!r.getSchema().isEmpty()?r.getSchema():s.context.catalog()):r.getCatalog();
            long revision=s.revision,contextRevision=s.contextRevision;
            boolean child=Set.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER).contains(r.getKind());
            if(r.getKind()==ObjectKind.ROUTINE&&r.getIdentifier().isEmpty())return SchemaToolResult.newBuilder().addUnsupported("An exact routine overload identity is required").build();
            var metadataExplorer=new Explorer(platform);boolean ownedTemporary=metadataExplorer.isOwnedTemporary(s,catalog,r.getSchema(),r.getTable());
            var objects=metadataExplorer.explore(s,ExploreRequest.newBuilder().setKind(r.getKind()).setCatalog(catalog).setSchema(r.getSchema()).setTable(r.getTable())
                .setSearch(child?r.getObjectName():r.getTable()).setExactName(true).setIdentifier(r.getIdentifier()).setIntrospectionLevel(3).setIndependentMetadata(!(ownedTemporary||s.profile.getEngine()==Engine.POSTGRESQL&&(r.getSchema().equals("pg_temp")||r.getSchema().equals(s.context.temporarySchema())))).build());
            if(s.revision!=revision||s.contextRevision!=contextRevision)throw new IllegalStateException("Object definition owner changed; refresh the selected object");
            if(objects.getObjectsCount()!=1||!objects.getComplete())return SchemaToolResult.newBuilder().addUnsupported("Exact object source is unavailable or its identity is ambiguous").build();
            var object=objects.getObjects(0);String availability=object.getPropertiesOrDefault("sourceAvailability","UNAVAILABLE");
            var result=SchemaToolResult.newBuilder().setInspectedObject(object).setDefinition(object.getDefinition()).setProvenance(object.getPropertiesOrDefault("sourceProvenance","")).setComplete(availability.equals("AVAILABLE"));
            if(object.getDefinition().isEmpty())result.addUnsupported("Native object source is "+availability.toLowerCase(Locale.ROOT));
            return result.build();
        }
        String catalog=r.getCatalog().isEmpty()?(s.profile.getEngine()!=Engine.POSTGRESQL&&!r.getSchema().isEmpty()?r.getSchema():s.context.catalog()):r.getCatalog();
        if(r.getAction()==SchemaToolAction.DESIGN_COLUMN&&!catalog.equals(s.context.catalog()))throw new IllegalArgumentException("Schema design requires an owned physical session for the requested database");
        return platform.inspectSchema(s,catalog,(view,capture)->switch(r.getAction()) {
            case CAPTURE_SCHEMA->{
                if(r.getTable().isEmpty())yield SchemaToolResult.newBuilder().setSnapshot(JSON.toJson(capture.capture(r.getSchema(),null))).build();
                if(r.getTable().length()>256||r.getTable().indexOf('\0')>=0)throw new IllegalArgumentException("Invalid scoped snapshot identity");
                String schema=r.getSchema().isEmpty()?view.context.schema():r.getSchema();
                var snapshot=capture.capture(schema,r.getTable());
                if(!snapshot.getAsJsonObject("tables").has(r.getTable()))throw new IllegalArgumentException("Selected table is missing or inaccessible in "+view.context.catalog()+"/"+schema);
                var subtype=ObjectSubtype.ORDINARY_TABLE;
                if(view.profile.getEngine()==Engine.POSTGRESQL)try(var statement=catalog(view,"SELECT c.relkind FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")) {
                    statement.setString(1,schema);statement.setString(2,r.getTable());
                    try(var rows=statement.executeQuery()) {
                        if(!rows.next()||!"r".equals(rows.getString(1)))throw new IllegalArgumentException("Scoped comparison supports ordinary tables; refresh the selected object");
                    }
                }
                yield SchemaToolResult.newBuilder().setSnapshot(JSON.toJson(snapshot)).setInspectedObject(SchemaObject.newBuilder()
                    .setCatalog(view.context.catalog()).setSchema(schema).setName(r.getTable()).setKind(ObjectKind.TABLE).setSubtype(subtype)).build();
            }
            case INSPECT_OBJECT->{var snapshot=capture.capture(r.getSchema(),null);var object=snapshot.getAsJsonObject("tables").get(r.getTable());yield SchemaToolResult.newBuilder().setSnapshot(snapshot.toString()).setDefinition(JSON.toJson(object==null?snapshot:object)).build();}
            case DESIGN_COLUMN->{if(!catalog.equals(s.context.catalog()))throw new io.busystack.busydata.rpc.WorkbenchFailure(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE);var current=capture.capture(r.getSchema(),null);yield new ObjectDesigner(view,platform.capture(s)).design(r,current); }
            default->throw new IllegalArgumentException("Invalid schema operation");
        });
    }
    /** Source text is fetched for one exact object; designer snapshots remain
     * separate because their complete-schema evidence authorizes later review. */
    private static SchemaToolResult definition(SessionRegistry.Session s,SchemaToolRequest r)throws Exception {
        for(String name:List.of(r.getSchema(),r.getTable()))if(name.length()>256||name.indexOf('\0')>=0)throw new IllegalArgumentException("Invalid definition scope");
        if(r.getIdentifier().getBytes(java.nio.charset.StandardCharsets.UTF_8).length>RoutineIdentity.MAX_BYTES)throw new IllegalArgumentException("Definition identity exceeds its budget");
        boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;
        String schema=r.getSchema().isEmpty()?s.context.schema():r.getSchema(),name=r.getTable();
        if(!pg&&!schema.equals(s.context.catalog()))throw new IllegalArgumentException("MySQL/MariaDB database and schema scopes must agree");
        boolean child=Set.of(ObjectKind.COLUMN,ObjectKind.INDEX,ObjectKind.CONSTRAINT,ObjectKind.FOREIGN_KEY,ObjectKind.TRIGGER).contains(r.getKind());
        String objectName=child?r.getObjectName():name;
        if(child&&(objectName.isEmpty()||objectName.length()>256||objectName.indexOf('\0')>=0))throw new IllegalArgumentException("Exact child definition identity required");
        var object=SchemaObject.newBuilder().setCatalog(s.context.catalog()).setSchema(schema).setName(objectName).setTable(child?name:"").setKind(r.getKind()).setIdentifier(r.getIdentifier());
        var result=SchemaToolResult.newBuilder();String ddl="",provenance="native";boolean complete=true;
        String qualified=s.adapter.table("",schema,name);
        switch(r.getKind()) {
            case COLUMN,INDEX,CONSTRAINT,FOREIGN_KEY,TRIGGER->{
                var table=SchemaSnapshotReader.read(s,schema,name).getAsJsonObject("tables").getAsJsonObject(name);
                if(table==null)return result.setInspectedObject(object).addUnsupported("Native parent table definition unavailable").build();
                String group=switch(r.getKind()){case COLUMN->"columns";case INDEX->"indexes";case TRIGGER->"triggers";default->"constraints";};
                var entry=group.equals("constraints")?SchemaConstraints.find(table,objectName,r.getKind()==ObjectKind.FOREIGN_KEY?(pg?"f":"FOREIGN KEY"):r.getIdentifier()):table.getAsJsonObject(group).get(objectName);
                if(entry!=null&&!entry.isJsonNull()) {
                    if(entry.isJsonPrimitive())ddl=entry.getAsString();
                    else if(entry.getAsJsonObject().has("definition"))ddl=entry.getAsJsonObject().get("definition").getAsString();
                    else if(pg&&r.getKind()==ObjectKind.COLUMN) {
                        var column=entry.getAsJsonObject();ddl=s.adapter.quote(objectName)+" "+column.get("type").getAsString();
                        String collation=column.get("collation").getAsString(),special=column.get("special").getAsString(),generated=column.get("generated").getAsString();
                        if(!collation.isEmpty())ddl+=" COLLATE "+collation;
                        if(!special.isEmpty())ddl+=" GENERATED "+(special.equals("a")?"ALWAYS":"BY DEFAULT")+" AS IDENTITY";
                        else if(!generated.isEmpty())ddl+=" GENERATED ALWAYS AS ("+column.get("default").getAsString()+") "+(generated.equals("v")?"VIRTUAL":"STORED");
                        else if(!column.get("default").isJsonNull())ddl+=" DEFAULT "+column.get("default").getAsString();
                        if(!column.get("nullable").getAsBoolean())ddl+=" NOT NULL";
                        provenance="generated-partial";complete=false;
                    }
                }
            }
            case TABLE->{
                var snapshot=SchemaSnapshotReader.read(s,schema,name);var table=snapshot.getAsJsonObject("tables").getAsJsonObject(name);
                if(table==null)return result.setInspectedObject(object).addUnsupported("Native table definition unavailable").build();
                if(pg) {
                    if(!table.getAsJsonObject("properties").get("kind").getAsString().equals("r"))return result.setInspectedObject(object).addUnsupported("Native partitioned/foreign table DDL generation is unavailable").build();
                    provenance="generated-partial";complete=false;
                    var script=new StringBuilder();
                    appendDefinition(script,"-- Generated from native catalogs; ownership, grants and storage/options are not included.\n");appendDefinition(script,table.get("create").getAsString()+";");
                    for(var entry:table.getAsJsonObject("constraints").entrySet()){var constraint=entry.getValue().getAsJsonObject();if("f".equals(SchemaConstraints.kind(constraint.get("type").getAsString())))appendDefinition(script,"\nALTER TABLE "+qualified+" ADD "+constraint.get("definition").getAsString()+";");}
                    for(String group:List.of("indexes","triggers"))for(var entry:table.getAsJsonObject(group).entrySet())appendDefinition(script,"\n"+entry.getValue().getAsString()+";");
                    ddl=script.toString();
                }else ddl=table.get("create").getAsString()+";";
                object.setSubtype(ObjectSubtype.ORDINARY_TABLE);
            }
            case VIEW->{
                if(pg)try(var st=catalog(s,"SELECT c.relkind,CASE WHEN OCTET_LENGTH(pg_get_viewdef(c.oid,true))<=65536 THEN pg_get_viewdef(c.oid,true) ELSE NULL END FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=? AND c.relkind IN ('v','m')")) {
                    st.setString(1,schema);st.setString(2,name);try(var rows=st.executeQuery()){if(rows.next()&&rows.getString(2)!=null){boolean materialized=rows.getString(1).equals("m");object.setSubtype(materialized?ObjectSubtype.MATERIALIZED_VIEW:ObjectSubtype.REGULAR_VIEW);ddl="-- Generated from pg_get_viewdef; ownership, grants and view options are not included.\nCREATE "+(materialized?"MATERIALIZED ":"")+"VIEW "+qualified+" AS\n"+rows.getString(2);provenance="generated-partial";complete=false;}}
                }else {preflightDefinition(s,"SELECT OCTET_LENGTH(VIEW_DEFINITION) FROM information_schema.VIEWS WHERE TABLE_SCHEMA=? AND TABLE_NAME=?",schema,name);ddl=nativeDefinition(s,"VIEW",qualified);object.setSubtype(ObjectSubtype.REGULAR_VIEW);}
            }
            case SEQUENCE->{
                object.setSubtype(ObjectSubtype.NATIVE_SEQUENCE);
                if(s.profile.getEngine()==Engine.MYSQL)return result.setInspectedObject(object).addUnsupported("MySQL has no sequence objects").build();
                if(pg)try(var st=catalog(s,"SELECT data_type::text,start_value,min_value,max_value,increment_by,cycle,cache_size,last_value FROM pg_catalog.pg_sequences WHERE schemaname=? AND sequencename=?")) {
                    st.setString(1,schema);st.setString(2,name);try(var rows=st.executeQuery()){if(rows.next()) {
                        for(int column=1;column<=8;column++){String value=rows.getString(column);if(value!=null)object.putProperties(List.of("type","startValue","minValue","maxValue","increment","cycle","cacheSize","lastValue").get(column-1),value);}
                        if(rows.getString(8)==null)object.putProperties("lastValueAvailability","unavailable");
                        ddl="-- Generated from pg_sequences; current value, ownership and grants are not included.\nCREATE SEQUENCE "+qualified+" AS "+rows.getString(1)+" START WITH "+rows.getString(2)+" INCREMENT BY "+rows.getString(5)+" MINVALUE "+rows.getString(3)+" MAXVALUE "+rows.getString(4)+" CACHE "+rows.getString(7)+(rows.getBoolean(6)?" CYCLE":" NO CYCLE")+";";
                        provenance="generated-partial";complete=false;
                    }}
                }else ddl=nativeDefinition(s,"SEQUENCE",qualified);
            }
            case ROUTINE->{
                if(r.getIdentifier().isEmpty())return result.setInspectedObject(object).addUnsupported("An exact routine overload identity is required").build();
                if(!pg){
                    ObjectSubtype subtype;
                    if(r.getIdentifier().equals("FUNCTION:"+name))subtype=ObjectSubtype.FUNCTION;
                    else if(r.getIdentifier().equals("PROCEDURE:"+name))subtype=ObjectSubtype.PROCEDURE;
                    else return result.setInspectedObject(object).addUnsupported("Exact native routine kind is unavailable").build();
                    object.setSubtype(subtype);
                    var source=io.busystack.busydata.metadata.NativeRoutineSource.read(s,object.build(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
                    ddl=source.definition();complete=source.available();object.putProperties("sourceAvailability",source.state().name()).putProperties("sourceSqlMode",source.sqlMode());
                    if(!complete)result.addUnsupported("Native routine source is "+source.state().name().toLowerCase(Locale.ROOT));
                    break;
                }
                String sql="SELECT p.prokind,CASE WHEN OCTET_LENGTH(pg_get_functiondef(p.oid))<=65536 THEN pg_get_functiondef(p.oid) ELSE NULL END FROM "+RoutineIdentity.POSTGRES_FROM+" WHERE n.nspname=? AND p.proname=? AND p.prokind IN ('f','p','w') AND "+RoutineIdentity.POSTGRES_KEY+"=?";
                try(var st=catalog(s,sql)){st.setString(1,schema);st.setString(2,name);st.setString(3,r.getIdentifier());try(var rows=st.executeQuery()){if(rows.next()) {
                    String kind=rows.getString(1);object.setSubtype(kind.equals("p")?ObjectSubtype.PROCEDURE:ObjectSubtype.FUNCTION);
                    ddl=Objects.toString(rows.getString(2),"");
                    if(rows.next())throw new IllegalArgumentException("Ambiguous routine identity");
                }}}
            }
            default->{return result.setInspectedObject(object).addUnsupported("DDL inspection is unavailable for this object kind").build();}
        }
        if(ddl.getBytes(java.nio.charset.StandardCharsets.UTF_8).length>65536)return result.setInspectedObject(object).addUnsupported("Native object definition exceeds the 64KiB inspection budget").build();
        return result.setInspectedObject(object).setDefinition(ddl).setProvenance(provenance).setComplete(complete&&!ddl.isEmpty()).build();
    }
    private static PreparedStatement catalog(SessionRegistry.Session s,String sql)throws SQLException {
        if(s.profile.getEngine()!=Engine.POSTGRESQL&&sql.startsWith("SELECT ")&&sql.contains("information_schema."))
            for(String field:List.of("TABLE_SCHEMA","TABLE_NAME","VIEW_SCHEMA","VIEW_NAME","ROUTINE_SCHEMA","ROUTINE_NAME","TRIGGER_SCHEMA","TRIGGER_NAME","EVENT_OBJECT_TABLE","REFERENCED_TABLE_SCHEMA","REFERENCED_TABLE_NAME","CONSTRAINT_SCHEMA"))sql=sql.replaceAll("(?<![A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*\\.)?"+field+"=\\?","BINARY $1"+field+"=BINARY ?");
        return s.adapter.catalogStatement(s.connection,sql);
    }
    private static void appendDefinition(StringBuilder script,String text){if(script.length()+text.length()>65536)throw new IllegalArgumentException("Native object definition exceeds the 64KiB inspection budget");script.append(text);}
    private static void preflightDefinition(SessionRegistry.Session s,String sql,String schema,String name)throws SQLException {
        try(var st=catalog(s,sql)){st.setString(1,schema);st.setString(2,name);try(var rows=st.executeQuery()){if(!rows.next()||rows.getObject(1)==null)throw new SQLException("Native definition unavailable");if(rows.getLong(1)>65536)throw new IllegalArgumentException("Native definition exceeds the 64KiB inspection budget");}}
    }
    static PreparedStatement nativeDefinitionStatement(SessionRegistry.Session session,String kind,String qualified)throws SQLException {return catalog(session,"SHOW CREATE "+kind+" "+qualified);}
    private static String nativeDefinition(SessionRegistry.Session s,String kind,String qualified)throws SQLException {
        try(var st=nativeDefinitionStatement(s,kind,qualified);var rows=st.executeQuery()) {
            if(!rows.next())throw new SQLException("Native definition unavailable");
            int column=Set.of("FUNCTION","PROCEDURE").contains(kind)?3:2;
            return Objects.toString(rows.getString(column),"");
        }
    }
    public JsonObject capture(SessionRegistry.Session session,String requested)throws Exception {return platform.captureSchema(session,requested,null);}
    private SchemaToolResult compare(SessionRegistry.Session session,SchemaToolRequest request){return new SchemaDiff(session,platform.capture(session)).compare(request);}
}
