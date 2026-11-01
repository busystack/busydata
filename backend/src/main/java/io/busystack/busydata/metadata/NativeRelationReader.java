package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.sql.*;
import java.util.*;

/** Physical generation evidence is never replaced by timestamps or display-name guesses. */
public final class NativeRelationReader {
    private NativeRelationReader(){}
    public static List<SchemaObject> enrich(SessionRegistry.Session session,List<SchemaObject> objects)throws SQLException {
        if(session.profile.getEngine()==Engine.POSTGRESQL)return objects.stream().map(o->o.toBuilder().putProperties("nativeGenerationAvailability",o.getPropertiesOrDefault("nativeGeneration","").isEmpty()?"UNAVAILABLE":"AVAILABLE").build()).toList();
        var result=new ArrayList<SchemaObject>();var names=new LinkedHashMap<String,SchemaObject>();
        for(var object:objects) {
            var database=filename(object.getCatalog());var table=filename(object.getName());
            if(database.isEmpty()||table.isEmpty())result.add(object.toBuilder().putProperties("nativeGenerationAvailability","UNSUPPORTED_IDENTIFIER_MAPPING").build());
            else names.put(database.get()+"/"+table.get(),object);
        }
        var entries=new ArrayList<>(names.entrySet());
        for(int start=0;start<entries.size();start+=500) {
            var batch=entries.subList(start,Math.min(entries.size(),start+500));var probe=probe(session,batch);
            var found=probe.identities();var rowVersions=probe.rowVersions();String state=probe.state();
            var columnEvidence=new HashMap<String,List<String>>();
            if(!found.isEmpty()) {
                var ids=found.values().stream().distinct().toList();String columns=session.profile.getEngine()==Engine.MYSQL?"information_schema.INNODB_COLUMNS":"information_schema.INNODB_SYS_COLUMNS";long bytes=0;int count=0;
                try(var statement=session.adapter.catalogStatement(session.connection,"SELECT TABLE_ID,NAME,POS,MTYPE,PRTYPE,LEN FROM "+columns+" WHERE TABLE_ID IN ("+String.join(",",Collections.nCopies(ids.size(),"?"))+") ORDER BY TABLE_ID,POS,NAME")) {
                    statement.setMaxRows(100001);int parameter=1;for(String id:ids)statement.setString(parameter++,id);
                    try(var rows=statement.executeQuery()){while(rows.next()) {
                        if(++count>100000){state="LIMITED";break;}String id=rows.getString(1);var evidence=columnEvidence.computeIfAbsent(id,k->new ArrayList<>());
                        for(int field=2;field<=6;field++){String value=Objects.toString(rows.getString(field),"");if((bytes+=value.length()*2L)>8_388_608){state="LIMITED";break;}evidence.add(value);}
                        if(state.equals("LIMITED"))break;
                    }}
                }catch(SQLException denied){if(!denied(denied))throw denied;state="DENIED";}
            }
            for(var entry:batch) {
                String identity=found.get(entry.getKey());var object=entry.getValue().toBuilder().putProperties("nativeGenerationAvailability",identity!=null?"AVAILABLE":state.equals("DENIED")?state:"UNAVAILABLE");
                if(identity!=null&&state.equals("AVAILABLE")&&columnEvidence.containsKey(identity)){String generation="innodb:"+identity+":"+(session.profile.getEngine()==Engine.MYSQL?"rows:"+rowVersions.get(identity)+":":"")+MetadataIdentity.digest(columnEvidence.get(identity).toArray(String[]::new));object.putProperties("nativeGeneration",generation).putProperties("nativeTableId",identity).putAllProperties(identityProperties(generation));}
                else object.putProperties("nativeGenerationAvailability",state.equals("AVAILABLE")?"UNAVAILABLE":state).removeProperties("nativeGeneration");
                result.add(object.build());
            }
        }
        return result.stream().sorted(Comparator.comparing(SchemaObject::getName).thenComparing(SchemaObject::getIdentifier)).toList();
    }
    private record IdentityProbe(Map<String,String> identities,Map<String,String> rowVersions,String state){}
    private static IdentityProbe probe(SessionRegistry.Session session,List<Map.Entry<String,SchemaObject>> batch)throws SQLException {
        var found=new HashMap<String,String>();var versions=new HashMap<String,String>();String state="AVAILABLE";
        String catalog=session.profile.getEngine()==Engine.MYSQL?"information_schema.INNODB_TABLES":"information_schema.INNODB_SYS_TABLES";
        try(var statement=session.adapter.catalogStatement(session.connection,"SELECT NAME,TABLE_ID"+(session.profile.getEngine()==Engine.MYSQL?",TOTAL_ROW_VERSIONS":"")+" FROM "+catalog+" WHERE BINARY NAME IN ("+String.join(",",Collections.nCopies(batch.size(),"?"))+")")) {
            statement.setFetchSize(0);statement.setMaxRows(501);int parameter=1;for(var entry:batch)statement.setString(parameter++,entry.getKey());
            try(var rows=statement.executeQuery()){while(rows.next()){String name=rows.getString(1),id=rows.getString(2);if(name==null||name.length()>2048||id==null||!id.matches("[0-9]{1,20}")||found.put(name,id)!=null)throw new SQLException("Physical table identity is invalid or ambiguous");if(session.profile.getEngine()==Engine.MYSQL)versions.put(id,rows.getString(3));}}
        }catch(SQLException failure){if(!denied(failure))throw failure;state="DENIED";}
        return new IdentityProbe(found,versions,state);
    }
    /** A bounded names probe reads native identities only, never the column dictionary. */
    public static List<SchemaObject> names(SessionRegistry.Session session,List<SchemaObject> objects)throws SQLException {
        if(session.profile.getEngine()==Engine.POSTGRESQL)return objects;
        var result=new ArrayList<SchemaObject>();var names=new LinkedHashMap<String,SchemaObject>();
        for(var object:objects){var database=filename(object.getCatalog());var table=filename(object.getName());if(database.isEmpty()||table.isEmpty())result.add(object);else names.put(database.get()+"/"+table.get(),object);}
        var entries=new ArrayList<>(names.entrySet());
        for(int start=0;start<entries.size();start+=500){var batch=entries.subList(start,Math.min(entries.size(),start+500));var probe=probe(session,batch);for(var entry:batch){var out=entry.getValue().toBuilder().removeProperties("nativeTableId").removeProperties("nativeColumnEpoch");String id=probe.identities().get(entry.getKey());if(id!=null){out.putProperties("nativeTableId",id);if(session.profile.getEngine()==Engine.MYSQL)out.putProperties("nativeColumnEpoch",Objects.toString(probe.rowVersions().get(id),""));}result.add(out.build());}}
        return List.copyOf(result);
    }
    public static Map<String,String> inspect(SessionRegistry.Session session,String catalog,String schema,String table)throws SQLException {
        if(session.profile.getEngine()==Engine.POSTGRESQL) {
            try(var query=session.adapter.catalogStatement(session.connection,"SELECT c.oid::text,pg_catalog.pg_relation_filenode(c.oid)::text FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname=? AND c.relname=?")) {
                query.setString(1,schema);query.setString(2,table);try(var rows=query.executeQuery()){if(!rows.next())return Map.of("nativeGenerationAvailability","UNAVAILABLE");String id=rows.getString(1),filenode=rows.getString(2);if(rows.next())throw new SQLException("Physical relation identity is ambiguous");return filenode==null?Map.of("nativeId",id,"nativeGenerationAvailability","UNAVAILABLE"):Map.of("nativeId",id,"nativeGeneration",id+":"+filenode,"nativeGenerationAvailability","AVAILABLE");}
            }
        }
        return enrich(session,List.of(SchemaObject.newBuilder().setCatalog(catalog).setSchema(schema).setName(table).setKind(ObjectKind.TABLE).build())).getFirst().getPropertiesMap();
    }
    /** Official filename mapping is deliberately partial where the native case table is not verified. */
    public static Optional<String> filename(String name) {
        if(name.startsWith("#mysql50#"))return Optional.empty();var encoded=new StringBuilder();
        for(int index=0;index<name.length();index++) {
            char value=name.charAt(index);
            if(value>='A'&&value<='Z'||value>='a'&&value<='z'||value>='0'&&value<='9'||value=='_')encoded.append(value);
            else if(Character.isSurrogate(value)||Character.toUpperCase(value)!=Character.toLowerCase(value))return Optional.empty();
            else encoded.append('@').append(String.format(Locale.ROOT,"%04x",(int)value));
        }
        if(Set.of("CON","PRN","AUX","NUL","COM1","COM2","COM3","COM4","COM5","COM6","COM7","COM8","COM9","LPT1","LPT2","LPT3","LPT4","LPT5","LPT6","LPT7","LPT8","LPT9").contains(name.toUpperCase(Locale.ROOT)))encoded.append("@@@");
        return Optional.of(encoded.toString());
    }
    public static String fingerprint(List<SchemaObject> objects){return MetadataIdentity.digest(objects.stream().sorted(Comparator.comparing(SchemaObject::getName)).flatMap(o->java.util.stream.Stream.of(o.getCatalog(),o.getSchema(),o.getName(),o.getPropertiesOrDefault("nativeGeneration",""),o.getPropertiesOrDefault("nativeGenerationAvailability","UNAVAILABLE"))).toArray(String[]::new));}
    /** Decode only BusyData's validated native-generation record, never a label or SQL identifier. */
    public static Map<String,String> identityProperties(String generation){var parts=generation.split(":",-1);if(parts.length==5&&parts[0].equals("innodb")&&parts[1].matches("[0-9]{1,20}")&&parts[2].equals("rows")&&parts[3].matches("[0-9]{1,2}")&&parts[4].matches("[0-9a-f]{64}"))return Map.of("nativeTableId",parts[1],"nativeColumnEpoch",parts[3]);if(parts.length==3&&parts[0].equals("innodb")&&parts[1].matches("[0-9]{1,20}")&&parts[2].matches("[0-9a-f]{64}"))return Map.of("nativeTableId",parts[1]);return Map.of();}
    private static boolean denied(SQLException failure){String state=Objects.toString(failure.getSQLState(),"");return state.equals("42501")||state.startsWith("28")||Set.of(1044,1045,1142,1143,1227,1370).contains(failure.getErrorCode());}
}
