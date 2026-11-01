package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Native source/evidence adapter; semantic publication belongs to MetadataPlatform. */
public final class SchemaSnapshotReader {
    private SchemaSnapshotReader(){}
    private static final Gson JSON=new GsonBuilder().serializeNulls().setPrettyPrinting().disableHtmlEscaping().create();
    private static PreparedStatement catalog(SessionRegistry.Session s,String sql)throws SQLException {
        if(s.profile.getEngine()!=Engine.POSTGRESQL&&sql.startsWith("SELECT ")&&sql.contains("information_schema."))
            for(String field:List.of("TABLE_SCHEMA","TABLE_NAME","VIEW_SCHEMA","VIEW_NAME","ROUTINE_SCHEMA","ROUTINE_NAME","TRIGGER_SCHEMA","TRIGGER_NAME","EVENT_OBJECT_TABLE","REFERENCED_TABLE_SCHEMA","REFERENCED_TABLE_NAME","CONSTRAINT_SCHEMA"))sql=sql.replaceAll("(?<![A-Za-z0-9_])([A-Za-z_][A-Za-z0-9_]*\\.)?"+field+"=\\?","BINARY $1"+field+"=BINARY ?");
        return s.adapter.catalogStatement(s.connection,sql);
    }
    public static JsonObject read(SessionRegistry.Session s,String requested,String tableFilter)throws Exception {
        String schema=requested.isBlank()?(s.context.schema()):requested;
        var root=new JsonObject();root.addProperty("version",2);root.addProperty("engine",s.profile.getEngine().name());root.addProperty("schema",schema);
        long snapshotBytes=512;var working=new SnapshotBudget();
        var tables=new TreeMap<String,JsonObject>();boolean pg=s.profile.getEngine()==Engine.POSTGRESQL;
        try(var statement=catalog(s,"SELECT TABLE_NAME FROM information_schema.TABLES WHERE "+(pg?"TABLE_SCHEMA=?":"BINARY TABLE_SCHEMA=BINARY ?")+" AND TABLE_TYPE='BASE TABLE'"+(tableFilter==null?"":pg?" AND TABLE_NAME=?":" AND BINARY TABLE_NAME=BINARY ?")+" ORDER BY TABLE_NAME LIMIT 1001")) {
            statement.setString(1,schema);
            if(tableFilter!=null)statement.setString(2,tableFilter);
            try(var rows=statement.executeQuery()) {
                while(rows.next()){if(tables.size()>=1000)throw new IllegalArgumentException("Snapshot table limit (1000)");tables.put(working.retain(rows.getString(1)),new JsonObject());}
            }
        }
        for(var entry:tables.entrySet()) {
            String table=entry.getKey(),qualified=s.adapter.table("",schema,table);var object=entry.getValue();var cols=new TreeMap<String,JsonObject>();var definitions=new ArrayList<String>();
            try{Explorer.preflightColumns(s,schema,table);}catch(io.busystack.busydata.metadata.MetadataLimit limited){throw new IllegalArgumentException("Column snapshot byte/row resource limit reached; choose a narrower object");}
            String columnSql=pg?"SELECT a.attname,format_type(a.atttypid,a.atttypmod),a.attnotnull,pg_get_expr(d.adbin,d.adrelid),a.attidentity,a.attgenerated,row_number() OVER (ORDER BY a.attnum) FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid JOIN pg_namespace n ON n.oid=t.relnamespace LEFT JOIN pg_attrdef d ON d.adrelid=a.attrelid AND d.adnum=a.attnum WHERE n.nspname=? AND t.relname=? AND a.attnum>0 AND NOT a.attisdropped ORDER BY a.attnum":"SELECT COLUMN_NAME,COLUMN_TYPE,IS_NULLABLE,COLUMN_DEFAULT,EXTRA,GENERATION_EXPRESSION,ORDINAL_POSITION FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=? AND TABLE_NAME=? ORDER BY ORDINAL_POSITION";
            try(var st=catalog(s,columnSql)){st.setString(1,schema);st.setString(2,table);try(var rows=st.executeQuery()){while(rows.next()) {
                String name=working.retain(rows.getString(1)),type=working.retain(rows.getString(2));boolean nullable=pg?!rows.getBoolean(3):"YES".equals(rows.getString(3));String defaultValue=working.retain(rows.getString(4));if(!pg&&"NULL".equals(defaultValue)&&nullable)defaultValue=null;var col=new JsonObject();col.addProperty("type",type);col.addProperty("nullable",nullable);col.addProperty("default",defaultValue);col.addProperty("special",working.retain(rows.getString(5)));col.addProperty("generated",working.retain(rows.getString(6)));col.addProperty("ordinal",rows.getInt(7));if(cols.size()>=2048||type.length()>256||defaultValue!=null&&defaultValue.length()>1_048_576)throw new IllegalArgumentException("Column snapshot resource limit reached");cols.put(name,col);
                String ddl=s.adapter.quote(name)+" "+type;
                if(pg&&!rows.getString(5).isBlank())ddl+=" GENERATED "+(rows.getString(5).equals("a")?"ALWAYS":"BY DEFAULT")+" AS IDENTITY";
                else if(pg&&!rows.getString(6).isBlank())ddl+=" GENERATED ALWAYS AS ("+rows.getString(4)+") STORED";
                else if(rows.getString(4)!=null)ddl+=" DEFAULT "+rows.getString(4);
                if(!nullable)ddl+=" NOT NULL";definitions.add(working.retain(ddl));
            }}}
            object.add("columns",JSON.toJsonTree(cols));var constraints=new JsonObject();var indexes=new TreeMap<String,String>();var triggers=new TreeMap<String,String>();
            String decorationSql=pg?"SELECT a.attname,COALESCE(col_description(a.attrelid,a.attnum),''),CASE WHEN a.attcollation<>ty.typcollation THEN quote_ident(cn.nspname)||'.'||quote_ident(co.collname) ELSE '' END FROM pg_attribute a JOIN pg_class t ON t.oid=a.attrelid JOIN pg_namespace n ON n.oid=t.relnamespace JOIN pg_type ty ON ty.oid=a.atttypid LEFT JOIN pg_collation co ON co.oid=a.attcollation LEFT JOIN pg_namespace cn ON cn.oid=co.collnamespace WHERE n.nspname=? AND t.relname=? AND a.attnum>0 AND NOT a.attisdropped":"SELECT COLUMN_NAME,COLUMN_COMMENT,COALESCE(COLLATION_NAME,''),COALESCE(CHARACTER_SET_NAME,'') FROM information_schema.COLUMNS WHERE TABLE_SCHEMA=? AND TABLE_NAME=?";
            try(var st=catalog(s,decorationSql)){st.setString(1,schema);st.setString(2,table);st.setQueryTimeout(10);try(var rows=st.executeQuery()){while(rows.next()){var column=cols.get(rows.getString(1));if(column!=null){column.addProperty("comment",working.retain(rows.getString(2)));column.addProperty("collation",working.retain(rows.getString(3)));if(!pg)column.addProperty("charset",working.retain(rows.getString(4)));}}}}
            object.add("columns",JSON.toJsonTree(cols));
            if(pg) {
                try(var st=catalog(s,"SELECT c.conname,pg_get_constraintdef(c.oid,true),c.contype FROM pg_constraint c JOIN pg_class t ON t.oid=c.conrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND t.relname=? ORDER BY c.conname")){st.setString(1,schema);st.setString(2,table);try(var rows=st.executeQuery()){while(rows.next()){String def=working.retain("CONSTRAINT "+s.adapter.quote(rows.getString(1))+" "+rows.getString(2));if(!rows.getString(3).equals("f"))definitions.add(def);SchemaConstraints.put(constraints,working.retain(rows.getString(1)),working.retain(rows.getString(3)),def);}}}
                try(var st=catalog(s,"SELECT i.relname,pg_get_indexdef(x.indexrelid) FROM pg_index x JOIN pg_class i ON i.oid=x.indexrelid JOIN pg_class t ON t.oid=x.indrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND t.relname=? AND NOT EXISTS(SELECT 1 FROM pg_constraint c WHERE c.conindid=x.indexrelid AND c.contype IN ('p','u','x')) ORDER BY i.relname")){st.setString(1,schema);st.setString(2,table);try(var rows=st.executeQuery()){while(rows.next())indexes.put(working.retain(rows.getString(1)),working.retain(rows.getString(2)));}}
                try(var st=catalog(s,"SELECT g.tgname,pg_get_triggerdef(g.oid,true) FROM pg_trigger g JOIN pg_class t ON t.oid=g.tgrelid JOIN pg_namespace n ON n.oid=t.relnamespace WHERE n.nspname=? AND t.relname=? AND NOT g.tgisinternal ORDER BY g.tgname")){st.setString(1,schema);st.setString(2,table);try(var rows=st.executeQuery()){while(rows.next())triggers.put(working.retain(rows.getString(1)),working.retain(rows.getString(2)));}}
                try(var st=catalog(s,"SELECT c.relkind,c.relpersistence,c.reloptions::text,EXISTS(SELECT 1 FROM pg_inherits WHERE inhrelid=c.oid OR inhparent=c.oid) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")){st.setString(1,schema);st.setString(2,table);try(var rows=st.executeQuery()){rows.next();var properties=new JsonObject();properties.addProperty("kind",rows.getString(1));properties.addProperty("persistence",rows.getString(2));properties.addProperty("options",Objects.toString(rows.getString(3),""));properties.addProperty("inheritance",rows.getBoolean(4));object.add("properties",properties);object.addProperty("unsupportedProperties",!rows.getString(1).equals("r")||!Set.of("p","u").contains(rows.getString(2))||rows.getString(3)!=null||rows.getBoolean(4));}}
                for(var column:cols.entrySet())if(!column.getValue().get("collation").getAsString().isEmpty()){
                    int ordinal=column.getValue().get("ordinal").getAsInt()-1;String prefix=s.adapter.quote(column.getKey())+" "+column.getValue().get("type").getAsString();definitions.set(ordinal,definitions.get(ordinal).replace(prefix,prefix+" COLLATE "+column.getValue().get("collation").getAsString()));
                }
                long createCost=256+qualified.length()*2L;for(String definition:definitions)createCost+=definition.length()*2L+8;working.reserve(createCost);
                object.addProperty("create","CREATE "+(object.getAsJsonObject("properties").get("persistence").getAsString().equals("u")?"UNLOGGED ":"")+"TABLE "+qualified+" (\n  "+String.join(",\n  ",definitions)+"\n)");
                try(var st=catalog(s,"SELECT COALESCE(obj_description(c.oid,'pg_class'),'') FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")){st.setString(1,schema);st.setString(2,table);try(var rows=st.executeQuery()){if(rows.next())object.getAsJsonObject("properties").addProperty("comment",rows.getString(1));}}
            } else {
                String nativeDdl;
                try(var st=s.connection.createStatement()){st.setQueryTimeout(10);try(var rows=st.executeQuery("SHOW CREATE TABLE "+qualified)){if(!rows.next())throw new IllegalStateException("Table disappeared during capture");nativeDdl=working.retain(rows.getString(2));object.addProperty("create",nativeDdl);}}
                var parts=DdlParts.table(nativeDdl);var base=new ArrayList<String>();var canonical=new ArrayList<String>();
                var nativeConstraints=new HashSet<String>();
                try(var st=catalog(s,"SELECT CONSTRAINT_NAME,CONSTRAINT_TYPE FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA=? AND TABLE_NAME=? ORDER BY BINARY CONSTRAINT_NAME,BINARY CONSTRAINT_TYPE")){st.setString(1,schema);st.setString(2,table);st.setQueryTimeout(10);st.setMaxRows(4097);try(var rows=st.executeQuery()){while(rows.next()){if(nativeConstraints.size()>=4096)throw new IllegalArgumentException("Snapshot constraint limit is 4096 per table");String name=working.retain(rows.getString(1)),type=working.retain(rows.getString(2));if(!SchemaConstraints.nativeType(type)||!nativeConstraints.add(SchemaConstraints.key(name,type)))throw new IllegalArgumentException("Native constraint identity unavailable");}}}
                for(String part:parts.parts()) {
                    String name=DdlParts.leadingIdentifier(part),upper=part.toUpperCase(Locale.ROOT);
                    if(!name.isEmpty()&&cols.containsKey(name)){part=ColumnDdl.canonicalProperties(part,cols.get(name).get("charset").getAsString(),cols.get(name).get("collation").getAsString());working.retain(part);cols.get(name).addProperty("definition",part);base.add(part);canonical.add(part);continue;}
                    canonical.add(part);
                    var constraint=DdlParts.constraint(part);
                    if(constraint!=null){
                        if(!nativeConstraints.remove(SchemaConstraints.key(constraint.name(),constraint.type())))throw new IllegalArgumentException("Native constraint source/type changed during capture");
                        SchemaConstraints.put(constraints,working.retain(constraint.name()),working.retain(constraint.type()),working.retain(part));
                        if(!constraint.type().equals("FOREIGN KEY"))base.add(part);continue;
                    }
                    String keyPrefix=List.of("FULLTEXT KEY ","SPATIAL KEY ","KEY ").stream().filter(upper::startsWith).findFirst().orElse(null);
                    if(keyPrefix!=null){String index=DdlParts.leadingIdentifier(part.substring(keyPrefix.length()));indexes.put(working.retain(index),working.retain(part));base.add(part);continue;}
                    object.addProperty("unsupportedDefinition",part);base.add(part);
                }
                if(!nativeConstraints.isEmpty())throw new IllegalArgumentException("Native constraint definition unavailable during capture");
                object.add("columns",JSON.toJsonTree(cols));object.addProperty("create",parts.render(canonical));object.addProperty("createBase",new DdlParts("CREATE TABLE "+qualified+" ",parts.parts(),parts.suffix()).render(base));
                try(var st=catalog(s,"SELECT TRIGGER_NAME FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA=? AND EVENT_OBJECT_TABLE=? ORDER BY TRIGGER_NAME")){st.setString(1,schema);st.setString(2,table);st.setQueryTimeout(10);try(var rows=st.executeQuery()){while(rows.next()){String trigger=rows.getString(1);if(triggers.size()>=1000)throw new IllegalArgumentException("Trigger snapshot limit is 1000");try(var nativeStatement=s.connection.createStatement()){nativeStatement.setQueryTimeout(10);try(var definition=nativeStatement.executeQuery("SHOW CREATE TRIGGER "+s.adapter.table("",schema,trigger))){if(!definition.next()||definition.getString(3)==null)throw new IllegalStateException("Trigger definition unavailable");triggers.put(working.retain(trigger),working.retain(definition.getString(3)));}}}}}

                var properties=new JsonObject();
                try(var st=catalog(s,"SELECT ENGINE,TABLE_COLLATION,ROW_FORMAT,CREATE_OPTIONS,TABLE_COMMENT FROM information_schema.TABLES WHERE TABLE_SCHEMA=? AND TABLE_NAME=?")){st.setString(1,schema);st.setString(2,table);try(var rows=st.executeQuery()){if(!rows.next())throw new IllegalStateException("Table disappeared during snapshot");for(int i=1;i<=5;i++)properties.addProperty(List.of("engine","collation","rowFormat","createOptions","comment").get(i-1),Objects.toString(rows.getString(i),""));}}
                object.add("properties",properties);
                // Exact native DDL retains collation, storage engine, generated columns and unsupported options.
                object.addProperty("unsupportedProperties",false);

            }
            object.add("constraints",constraints);object.add("indexes",JSON.toJsonTree(indexes));object.add("triggers",JSON.toJsonTree(triggers));
            snapshotBytes+=SnapshotJson.encodedBytes(object)+table.length()*3L+2;if(snapshotBytes>6_291_456)throw new IllegalArgumentException("Schema snapshot byte budget exceeded; choose a narrower schema");
        }
        root.add("tables",JSON.toJsonTree(tables));
        if(tableFilter!=null){
            for(String property:List.of("views","viewProperties","viewDependencies","routines","objectDependencies"))root.add(property,new JsonObject());
            return root;
        }
        var views=new TreeMap<String,String>();
        long viewBytes=0;
        try(var st=catalog(s,"SELECT TABLE_NAME,CASE WHEN OCTET_LENGTH(VIEW_DEFINITION)<=65536 THEN VIEW_DEFINITION ELSE NULL END,OCTET_LENGTH(VIEW_DEFINITION) FROM information_schema.VIEWS WHERE TABLE_SCHEMA=? ORDER BY TABLE_NAME")){st.setString(1,schema);st.setQueryTimeout(10);st.setMaxRows(1001);try(var rows=st.executeQuery()){while(rows.next()){if(views.size()>=1000||rows.getLong(3)>65536||(viewBytes+=rows.getLong(3))>1048576)throw new IllegalArgumentException("View snapshot supports 1000 views, 64KiB per definition and 1MiB total; choose a narrower schema");views.put(working.retain(rows.getString(1)),working.retain(rows.getString(2)));}}}
        root.add("views",JSON.toJsonTree(views));root.add("viewProperties",ViewProperties.capture(s,schema,working));var viewDependencies=new TreeMap<String,Set<String>>();int dependencyCount=0;
        if(pg)try(var st=catalog(s,"SELECT DISTINCT v.relname,r.relname FROM pg_class v JOIN pg_namespace n ON n.oid=v.relnamespace JOIN pg_rewrite w ON w.ev_class=v.oid JOIN pg_depend d ON d.objid=w.oid AND d.classid='pg_rewrite'::regclass JOIN pg_class r ON r.oid=d.refobjid AND d.refclassid='pg_class'::regclass WHERE n.nspname=? AND v.relkind='v' AND r.relkind='v' AND r.oid<>v.oid AND r.relnamespace=n.oid ORDER BY v.relname,r.relname")){st.setString(1,schema);st.setQueryTimeout(10);try(var rows=st.executeQuery()){while(rows.next()){if(++dependencyCount>10000)throw new IllegalArgumentException("View dependency limit is 10,000 edges");viewDependencies.computeIfAbsent(working.retain(rows.getString(1)),ignored->new TreeSet<>()).add(working.retain(rows.getString(2)));}}}
        else if(!views.isEmpty())try(var st=catalog(s,"SELECT VIEW_NAME,TABLE_NAME FROM information_schema.VIEW_TABLE_USAGE WHERE VIEW_SCHEMA=? AND TABLE_SCHEMA=? ORDER BY VIEW_NAME,TABLE_NAME")){st.setString(1,schema);st.setString(2,schema);st.setQueryTimeout(10);try(var rows=st.executeQuery()){while(rows.next()){if(++dependencyCount>10000)throw new IllegalArgumentException("View dependency limit is 10,000 edges");if(views.containsKey(rows.getString(2)))viewDependencies.computeIfAbsent(working.retain(rows.getString(1)),ignored->new TreeSet<>()).add(working.retain(rows.getString(2)));}}}
        catch(SQLException error){if(error.getSQLState()!=null&&error.getSQLState().startsWith("42")) {
            try {
                for(var view:views.entrySet()) {
                    if(view.getValue()==null)throw new IllegalArgumentException("View definition is unavailable");
                    var references=io.busystack.busydata.analysis.SqlParsing.tables(view.getValue(),s.profile.getEngine());
                    for(String reference:references)for(String candidate:views.keySet())if(reference.equals(candidate)||reference.equals(schema+"."+candidate)||reference.equals(s.adapter.table("",schema,candidate)))viewDependencies.computeIfAbsent(view.getKey(),ignored->new TreeSet<>()).add(candidate);
                }
            }catch(Exception unsupported){root.addProperty("viewDependencyAvailability","View dependency parsing unavailable; review explicit ordering");}
        }else throw error;}
        root.add("viewDependencies",JSON.toJsonTree(viewDependencies));root.add("routines",RoutineDefinitions.capture(s,schema,working));root.add("objectDependencies",CatalogDependencies.capture(s,schema,working));if(SnapshotJson.encodedBytes(root)>6_291_456)throw new IllegalArgumentException("Schema snapshot byte budget exceeded; choose a narrower schema");return root;
    }
}
