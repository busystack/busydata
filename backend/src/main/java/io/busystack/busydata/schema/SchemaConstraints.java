package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.Engine;
import io.busystack.busydata.metadata.MetadataSnapshot;
import java.util.*;

/** One typed constraint representation for captures, imported artifacts and
 * exact source lookup. Legacy files are converted in memory, never rewritten. */
public final class SchemaConstraints {
    private SchemaConstraints(){}
    private static final Gson JSON=new GsonBuilder().disableHtmlEscaping().create();
    private static final Set<String> MYSQL_TYPES=Set.of("PRIMARY KEY","UNIQUE","FOREIGN KEY","CHECK");
    private static final Set<String> PG_TYPES=Set.of("p","u","f","c","x","t","n");
    public static boolean nativeType(String type){return MYSQL_TYPES.contains(type);}
    public static String key(String name,String type){var tuple=new JsonArray();tuple.add(type);tuple.add(name);return JSON.toJson(tuple);}
    public static void put(JsonObject constraints,String name,String type,String definition){
        identity(name,type);if(definition==null||definition.isBlank()||definition.length()>1_048_576)throw new IllegalArgumentException("Constraint definition exceeds its budget");
        String key=key(name,type);if(constraints.has(key))throw new IllegalArgumentException("Duplicate exact constraint identity");
        if(constraints.size()>=4096)throw new IllegalArgumentException("Snapshot constraint limit is 4096 per table");
        var value=new JsonObject();value.addProperty("name",name);value.addProperty("type",type);value.addProperty("definition",definition);constraints.add(key,value);
    }
    private static void identity(String name,String type){if(name==null||name.isEmpty()||name.length()>256||name.indexOf('\0')>=0||type==null||!MYSQL_TYPES.contains(type)&&!PG_TYPES.contains(type))throw new IllegalArgumentException("Exact native constraint name/type unavailable");}
    public static String kind(String type){return switch(type){case "PRIMARY KEY"->"p";case "UNIQUE"->"u";case "FOREIGN KEY"->"f";case "CHECK"->"c";default->PG_TYPES.contains(type)?type:"unknown";};}
    public static String type(Engine engine,String kind){return switch(kind){case "primary"->engine==Engine.POSTGRESQL?"p":"PRIMARY KEY";case "unique"->engine==Engine.POSTGRESQL?"u":"UNIQUE";case "foreign"->engine==Engine.POSTGRESQL?"f":"FOREIGN KEY";case "check"->engine==Engine.POSTGRESQL?"c":"CHECK";default->throw new IllegalArgumentException("Choose a native constraint type");};}
    public static JsonObject find(JsonObject table,String name,String type){
        var constraints=table.getAsJsonObject("constraints");if(!type.isEmpty())return constraints.getAsJsonObject(key(name,type));
        JsonObject found=null;for(var value:constraints.entrySet())if(value.getValue().getAsJsonObject().get("name").getAsString().equals(name)){
            if(found!=null)throw new IllegalArgumentException("Constraint name is ambiguous; select its exact native type");found=value.getValue().getAsJsonObject();
        }return found;
    }
    public static String definition(JsonObject table,String name,String type){var found=find(table,name,type);return found==null?"":found.get("definition").getAsString();}
    public static boolean hasName(JsonObject table,String name){return table.getAsJsonObject("constraints").entrySet().stream().anyMatch(entry->entry.getValue().getAsJsonObject().get("name").getAsString().equals(name));}
    /** Raw native identity and the server's DROP lookup domain are distinct.
     * Quoting cannot select between two existing names with one DROP key. */
    public static boolean foreignKeyDropsUnambiguous(JsonObject table,MetadataSnapshot evidence){
        var rules=evidence.rules();
        var keys=new HashSet<String>();
        for(var entry:table.getAsJsonObject("constraints").entrySet()){
            var record=entry.getValue().getAsJsonObject();String type=record.get("type").getAsString();if(!kind(type).equals("f"))continue;
            if(!evidence.identifierRulesAvailable()||!rules.complete()||!keys.add(rules.constraintDropKey(type,record.get("name").getAsString())))return false;
        }return true;
    }

    /** The sole V1 import boundary. Comparison/designer logic only sees V2.
     * A legacy MySQL map can have overwritten siblings; exact native CREATE is
     * authoritative only after its surviving legacy projections are verified. */
    public static JsonObject importSnapshot(JsonObject snapshot){
        if(!snapshot.has("version")||!snapshot.get("version").isJsonPrimitive()||!snapshot.get("version").getAsJsonPrimitive().isNumber())throw new IllegalArgumentException("Missing schema artifact version");
        int version=snapshot.get("version").getAsInt();if(version!=1&&version!=2||!snapshot.get("version").getAsString().equals(Integer.toString(version)))throw new IllegalArgumentException("Unsupported schema artifact version");
        Engine engine;try{engine=Engine.valueOf(snapshot.get("engine").getAsString());}catch(RuntimeException invalid){throw new IllegalArgumentException("Unsupported schema artifact engine");}
        if(engine!=Engine.POSTGRESQL&&engine!=Engine.MYSQL&&engine!=Engine.MARIADB)throw new IllegalArgumentException("Unsupported schema artifact engine");
        var tables=snapshot.getAsJsonObject("tables");if(tables==null||tables.size()>1000)throw new IllegalArgumentException("Snapshot table limit is 1000");
        var budget=new SnapshotBudget();
        for(var entry:tables.entrySet()){
            var table=entry.getValue().getAsJsonObject();
            if(version==1){if(engine==Engine.POSTGRESQL)legacyPostgres(table,budget);else legacyMysql(table,budget);table.remove("constraintKinds");}
            else if(table.has("constraintKinds"))throw new IllegalArgumentException("V2 constraint types belong to exact constraint records");
            validate(table.getAsJsonObject("constraints"),engine);
        }
        snapshot.addProperty("version",2);return snapshot;
    }
    private static void validate(JsonObject constraints,Engine engine){
        if(constraints==null||constraints.size()>4096)throw new IllegalArgumentException("Snapshot constraint limit is 4096 per table");
        for(var entry:constraints.entrySet()){
            if(!entry.getValue().isJsonObject())throw new IllegalArgumentException("Expected a typed constraint record");var value=entry.getValue().getAsJsonObject();
            if(!value.keySet().equals(Set.of("name","type","definition")))throw new IllegalArgumentException("Incomplete or unsupported typed constraint record");
            for(String field:List.of("name","type","definition"))if(!value.get(field).isJsonPrimitive()||!value.get(field).getAsJsonPrimitive().isString())throw new IllegalArgumentException("Expected constraint text fields");
            String name=value.get("name").getAsString(),type=value.get("type").getAsString();identity(name,type);
            if(!(engine==Engine.POSTGRESQL?PG_TYPES:MYSQL_TYPES).contains(type)||!entry.getKey().equals(key(name,type))||value.get("definition").getAsString().isBlank()||value.get("definition").getAsString().length()>1_048_576)throw new IllegalArgumentException("Invalid exact constraint record");
            validateDefinition(engine,name,type,value.get("definition").getAsString());
        }
    }
    private static void validateDefinition(Engine engine,String name,String type,String definition){
        if(engine!=Engine.POSTGRESQL){
            var parsed=DdlParts.constraint(definition);if(parsed==null||!parsed.name().equals(name)||!parsed.type().equals(type))throw new IllegalArgumentException("Constraint definition disagrees with its exact native name/type");
            return;
        }
        String body=DdlParts.constraintBody(definition,name);
        String prefix=switch(type){case "p"->"PRIMARY\\s+KEY";case "u"->"UNIQUE";case "f"->"FOREIGN\\s+KEY";case "c"->"CHECK";case "x"->"EXCLUDE";case "n"->"NOT\\s+NULL";default->throw new IllegalArgumentException("Native constraint definition grammar is unavailable");};
        if(!java.util.regex.Pattern.compile("(?is)^(?:"+prefix+")(?=\\s|\\().+").matcher(body).matches())throw new IllegalArgumentException("Constraint definition type disagrees with its captured native type");
    }
    private static void legacyPostgres(JsonObject table,SnapshotBudget budget){
        var old=required(table,"constraints");var kinds=required(table,"constraintKinds");var converted=new JsonObject();
        if(!old.keySet().equals(kinds.keySet()))throw legacyUnavailable();
        for(var entry:old.entrySet()){
            String name=entry.getKey(),type=text(kinds.get(name)),definition=text(entry.getValue());if(!PG_TYPES.contains(type))throw legacyUnavailable();
            // PG V1 names are unique per table; pg_get_constraintdef was retained
            // independently, including foreign keys omitted from generated CREATE.
            retain(budget,name,type,definition);put(converted,name,type,definition);
        }table.add("constraints",converted);
    }
    private static void legacyMysql(JsonObject table,SnapshotBudget budget){
        var old=required(table,"constraints");var kinds=required(table,"constraintKinds");var indexes=required(table,"indexes");
        String create=text(table.get("create")),base=text(table.get("createBase"));var parts=DdlParts.table(create);var oldBase=DdlParts.table(base);
        var converted=new JsonObject();var expectedOld=new JsonObject();var expectedIndexes=new JsonObject();var expectedBase=new ArrayList<String>();var recoveredBase=new ArrayList<String>();
        var recoveredKinds=new HashMap<String,Set<String>>();
        for(String part:parts.parts()){
            var constraint=DdlParts.constraint(part);String upper=part.toUpperCase(Locale.ROOT);
            if(constraint!=null){
                retain(budget,constraint.name(),constraint.type(),constraint.definition());put(converted,constraint.name(),constraint.type(),constraint.definition());
                recoveredKinds.computeIfAbsent(constraint.name(),ignored->new HashSet<>()).add(kind(constraint.type()));
                if(!constraint.type().equals("FOREIGN KEY"))recoveredBase.add(part);
                if(upper.startsWith("PRIMARY KEY")){expectedOld.addProperty("PRIMARY",part);expectedBase.add(part);}
                else if(upper.startsWith("CONSTRAINT ")){expectedOld.addProperty(constraint.name(),part);if(!"f".equals(kinds.has(constraint.name())?text(kinds.get(constraint.name())):""))expectedBase.add(part);}
                else {if("u".equals(kinds.has(constraint.name())?text(kinds.get(constraint.name())):""))expectedOld.addProperty(constraint.name(),part);else expectedIndexes.addProperty(constraint.name(),part);expectedBase.add(part);}
            }else{
                expectedBase.add(part);recoveredBase.add(part);
                String prefix=List.of("FULLTEXT KEY ","SPATIAL KEY ","KEY ").stream().filter(upper::startsWith).findFirst().orElse(null);
                if(prefix!=null){String name=DdlParts.leadingIdentifier(part.substring(prefix.length()));if(name.isEmpty())throw legacyUnavailable();expectedIndexes.addProperty(name,part);}
            }
        }
        if(!old.equals(expectedOld)||!indexes.equals(expectedIndexes)||!oldBase.parts().equals(expectedBase)||!oldBase.suffix().equals(parts.suffix())||!kinds.keySet().equals(recoveredKinds.keySet()))throw legacyUnavailable();
        for(var entry:kinds.entrySet())if(!recoveredKinds.get(entry.getKey()).contains(text(entry.getValue())))throw legacyUnavailable();
        // Preserve the original native CREATE string. Only the derived base
        // statement is rebuilt, with its already captured qualified prefix.
        String corrected=oldBase.render(recoveredBase);budget.retain(corrected);table.addProperty("createBase",corrected);table.add("constraints",converted);
        // A legacy UNIQUE clause misclassified as an index belongs solely to
        // its recovered constraint, never to two independently emitted phases.
        var independent=new JsonObject();for(var entry:indexes.entrySet())if(DdlParts.constraint(text(entry.getValue()))==null)independent.add(entry.getKey(),entry.getValue());table.add("indexes",independent);
    }
    private static JsonObject required(JsonObject table,String field){if(!table.has(field)||!table.get(field).isJsonObject())throw legacyUnavailable();return table.getAsJsonObject(field);}
    private static String text(JsonElement value){if(value==null||!value.isJsonPrimitive()||!value.getAsJsonPrimitive().isString())throw legacyUnavailable();return value.getAsString();}
    private static void retain(SnapshotBudget budget,String name,String type,String definition){budget.retain(name);budget.retain(type);budget.retain(definition);budget.retain(key(name,type));}
    private static IllegalArgumentException legacyUnavailable(){return new IllegalArgumentException("Legacy constraint evidence is unavailable or contradictory; retain the original artifact and capture fresh native metadata");}
}
