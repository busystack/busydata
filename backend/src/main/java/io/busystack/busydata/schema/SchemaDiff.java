package io.busystack.busydata.schema;

import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.metadata.MetadataSnapshot;
import io.busystack.busydata.sessions.SessionRegistry;
import java.util.*;

/** Phase-ordered ordinary migrations. Every omitted change remains explicit. */
final class SchemaDiff {
    private final SessionRegistry.Session session;private final boolean postgres;private final MetadataSnapshot identifierEvidence;
    private final SchemaToolResult.Builder result=SchemaToolResult.newBuilder();
    private final List<String> dependencies=new ArrayList<>(),drops=new ArrayList<>(),creates=new ArrayList<>(),alters=new ArrayList<>(),keys=new ArrayList<>(),foreignKeys=new ArrayList<>(),routines=new ArrayList<>(),triggers=new ArrayList<>(),views=new ArrayList<>();
    private String schema;
    private final Map<String,String> tableNodes=new HashMap<>();
    private final Map<String,List<String>> creationGroups=new TreeMap<>(),dropGroups=new TreeMap<>();
    SchemaDiff(SessionRegistry.Session session,MetadataSnapshot identifierEvidence){this.session=session;this.identifierEvidence=Objects.requireNonNull(identifierEvidence);if(identifierEvidence.rules().engine()!=session.profile.getEngine())throw new IllegalArgumentException("Native constraint rules belong to another engine");postgres=session.profile.getEngine()==Engine.POSTGRESQL;}
    SchemaToolResult compare(SchemaToolRequest request) {
        var before=SchemaConstraints.importSnapshot(SnapshotJson.read(request.getSourceSnapshot()));var after=SchemaConstraints.importSnapshot(SnapshotJson.read(request.getTargetSnapshot()));
        for(var snapshot:List.of(before,after))if(!snapshot.has("version")||snapshot.get("version").getAsInt()!=2||!snapshot.get("engine").getAsString().equals(session.profile.getEngine().name()))throw new IllegalArgumentException("Use snapshots from the same engine and snapshot version");
        if(!before.get("schema").equals(after.get("schema")))throw new IllegalArgumentException("Snapshot schemas must match; renames are never guessed");schema=before.get("schema").getAsString();
        structuredDifferences(before,after);
        result.addRisks("Review each dependency and statement. Drops lose data; type/default/generated changes may rewrite or lock tables. MySQL/MariaDB DDL implicitly commits and cannot be made harmless by rollback.");
        var source=before.getAsJsonObject("tables");var target=after.getAsJsonObject("tables");
        if(source.size()>1000||target.size()>1000)throw new IllegalArgumentException("Snapshot table limit is 1000");
        for(String name:union(source,target)){
            var a=source.getAsJsonObject(name);var b=target.getAsJsonObject(name);
            var oldTriggers=a!=null&&a.has("triggers")?a.getAsJsonObject("triggers"):new JsonObject();
            var newTriggers=b!=null&&b.has("triggers")?b.getAsJsonObject("triggers"):new JsonObject();
            if(!triggerChangesAvailable(oldTriggers,newTriggers,identifierEvidence)){
                unsupported("Native trigger lookup is unsupported or unavailable for this captured server");
                return result.setComplete(false).setEquivalent(false).build();
            }
        }
        if(!source.equals(target))for(var entry:source.entrySet())if(!SchemaConstraints.foreignKeyDropsUnambiguous(entry.getValue().getAsJsonObject(),identifierEvidence)){
            unsupported("Native foreign-key DROP identity is unavailable or ambiguous on "+entry.getKey());
            return result.setComplete(false).setEquivalent(false).build();
        }
        for(String name:union(source,target))tableNodes.put(table(name),"T:"+name);
        for(String name:union(source,target)) {
            var a=source.getAsJsonObject(name);var b=target.getAsJsonObject(name);String table=table(name);
            if(a==null){create(name,b);continue;}
            if(b==null){dropConstraints(table,a,null);dropGroups.put("T:"+name,List.of("DROP TABLE "+table+";"));continue;}
            if(a.equals(b))continue;
            int dependencyStart=dependencies.size(),keyStart=keys.size();
            dropConstraints(table,a,b);indexes(table,a,b);
            columns(table,a.getAsJsonObject("columns"),b.getAsJsonObject("columns"));
            properties(table,a,b);
            if(!postgres)coalesceTableAlterations(table,dependencyStart,keyStart);
            for(String category:List.of("constraints","indexes","triggers"))if(!a.has(category)||!b.has(category))unsupported("Missing captured "+category+" on "+table);
            for(String category:List.of("triggers"))if(a.has(category)&&b.has(category))triggerChanges(table,a.getAsJsonObject(category),b.getAsJsonObject(category));
            for(String key:union(a,b))if(!Set.of("columns","constraints","indexes","triggers","properties","unsupportedProperties","create","createBase","unsupportedDefinition").contains(key)&&!Objects.equals(a.get(key),b.get(key)))unsupported("Changed captured property "+key+" on "+table);
            if(!Objects.equals(a.get("create"),b.get("create"))&&List.of("columns","constraints","indexes","triggers","properties").stream().allMatch(key->Objects.equals(a.get(key),b.get(key))))unsupported("Native table definition differs outside captured structured properties: "+table);
            if(!Objects.equals(a.get("unsupportedDefinition"),b.get("unsupportedDefinition")))unsupported("Changed unsupported native definition on "+table);
        }
        if(!source.equals(target))foreignKeyDependencies(source,target);
        routineChanges(before,after);
        viewChanges(before,after,!source.equals(target)||!Objects.equals(before.get("routines"),after.get("routines")));
        orderCreations(after);
        orderDrops(before);
        for(var phase:List.of(dependencies,drops,creates,alters,keys,foreignKeys,routines,triggers,views))result.addAllSql(phase);
        for(String key:union(before,after))if(!Set.of("version","engine","schema","tables","views","viewProperties","viewDependencies","routines","objectDependencies").contains(key)&&!Objects.equals(before.get(key),after.get(key)))unsupported("Changed captured schema property "+key);
        boolean complete=result.getUnsupportedCount()==0;
        return result.setComplete(complete).setEquivalent(complete&&result.getSqlCount()==0).build();
    }
    private void structuredDifferences(JsonObject before,JsonObject after) {
        int remaining=2*1024*1024;
        for(String category:List.of("tables","views","routines")) {
            var a=before.has(category)?before.getAsJsonObject(category):new JsonObject();
            var b=after.has(category)?after.getAsJsonObject(category):new JsonObject();
            for(String name:union(a,b)) {
                var current=a.get(name);var desired=b.get(name);
                if(Objects.equals(current,desired))continue;
                if(result.getDifferencesCount()>=2048||remaining<=0){result.setDifferencesLimited(true);return;}
                String left=definition(current),right=definition(desired);
                boolean limited=left.length()>65536||right.length()>65536||left.length()+right.length()>remaining;
                int leftLimit=Math.min(65536,remaining/2),rightLimit=Math.min(65536,remaining-leftLimit);
                left=bounded(left,leftLimit);right=bounded(right,rightLimit);remaining-=left.length()+right.length();
                result.addDifferences(SchemaDifference.newBuilder().setKind(category).setName(name).setState(current==null?"added":desired==null?"removed":"changed").setBeforeDefinition(left).setAfterDefinition(right).setPresentationLimited(limited));
            }
        }
    }
    private static String definition(JsonElement element) {
        if(element==null)return "";
        if(element.isJsonPrimitive())return element.getAsString();
        var object=element.getAsJsonObject();
        if(object.has("create"))return object.get("create").getAsString();
        if(object.has("definition"))return object.get("definition").getAsString();
        return new GsonBuilder().setPrettyPrinting().create().toJson(object);
    }
    private static String bounded(String text,int units) {
        int end=Math.min(text.length(),units);
        if(end>0&&end<text.length()&&Character.isHighSurrogate(text.charAt(end-1)))end--;
        return text.substring(0,end);
    }
    private void create(String name,JsonObject object) {
        String table=table(name);
        for(String property:object.keySet())if(!Set.of("columns","constraints","indexes","triggers","properties","unsupportedProperties","create","createBase","unsupportedDefinition").contains(property)){unsupported("Create "+table+": unsupported captured property "+property);return;}
        for(var entry:object.getAsJsonObject("columns").entrySet())for(String property:entry.getValue().getAsJsonObject().keySet())if(!Set.of("type","nullable","default","special","generated","ordinal","definition","comment","collation","charset").contains(property)){unsupported("Create "+table+"."+entry.getKey()+": unsupported captured column property "+property);return;}
        if(object.get("unsupportedProperties").getAsBoolean()||object.has("unsupportedDefinition")){unsupported("Create "+table+": unsupported native properties are retained in the snapshot");return;}
        creationGroups.put("T:"+name,new ArrayList<>(List.of((postgres?object.get("create"):object.get("createBase")).getAsString()+";")));
        if(postgres){
            for(var entry:object.getAsJsonObject("columns").entrySet())if(!empty(entry.getValue().getAsJsonObject(),"comment"))alter(table,"COMMENT ON COLUMN "+table+"."+quote(entry.getKey())+" IS "+literal(entry.getValue().getAsJsonObject().get("comment").getAsString())+";");
            if(!empty(object.getAsJsonObject("properties"),"comment"))alter(table,"COMMENT ON TABLE "+table+" IS "+literal(object.getAsJsonObject("properties").get("comment").getAsString())+";");
        }
        if(postgres)for(var index:object.getAsJsonObject("indexes").entrySet())keys.add(index.getValue().getAsString()+";");
        triggerChanges(table,new JsonObject(),object.getAsJsonObject("triggers"));
    }
    private void dropConstraints(String table,JsonObject before,JsonObject after) {
        var a=before.getAsJsonObject("constraints");var b=after==null?new JsonObject():after.getAsJsonObject("constraints");
        for(String identity:union(a,b)) {
            var x=a.getAsJsonObject(identity);var y=b.getAsJsonObject(identity);if(Objects.equals(x,y))continue;
            var record=x!=null?x:y;String name=record.get("name").getAsString();
            String type=SchemaConstraints.kind(record.get("type").getAsString());
            if(type.equals("f"))continue;
            if(type.equals("unknown")){unsupported("Constraint identity/type unavailable: "+table+"."+name);continue;}
            if(x!=null) {
                String sql="ALTER TABLE "+table+" "+(postgres?"DROP CONSTRAINT "+quote(name):switch(type){case "p"->"DROP PRIMARY KEY";case "u"->"DROP INDEX "+quote(name);case "f"->"DROP FOREIGN KEY "+quote(name);default->(session.profile.getEngine()==Engine.MARIADB?"DROP CONSTRAINT ":"DROP CHECK ")+quote(name);})+";";
                // Foreign keys are removed before the keys/tables they reference.
                if(type.equals("f"))dependencies.add(0,sql);else if(after!=null)dependencies.add(sql);
            }
            if(y!=null){String sql="ALTER TABLE "+table+" ADD "+y.get("definition").getAsString()+";";if(SchemaConstraints.kind(y.get("type").getAsString()).equals("f"))foreignKeys.add(sql);else keys.add(sql);}
        }
    }
    private void foreignKeyDependencies(JsonObject source,JsonObject target) {
        for(String name:source.keySet()) {
            var object=source.getAsJsonObject(name);
            for(var constraint:object.getAsJsonObject("constraints").entrySet())if(kind(object,constraint.getKey()).equals("f"))dependencies.add(0,"ALTER TABLE "+table(name)+(postgres?" DROP CONSTRAINT ":" DROP FOREIGN KEY ")+quote(constraint.getValue().getAsJsonObject().get("name").getAsString())+";");
        }
        for(String name:target.keySet()) {
            var object=target.getAsJsonObject(name);
            for(var constraint:object.getAsJsonObject("constraints").entrySet())if(kind(object,constraint.getKey()).equals("f"))foreignKeys.add("ALTER TABLE "+table(name)+" ADD "+constraint.getValue().getAsJsonObject().get("definition").getAsString()+";");
        }
        if(!foreignKeys.isEmpty())result.addDependencies("Foreign keys are detached before structural changes and revalidated after all base tables, unique keys, and indexes. Mutual foreign-key cycles are resolved by this two-phase operation.");
    }
    private void indexes(String table,JsonObject before,JsonObject after) {
        var a=before.getAsJsonObject("indexes");var b=after.getAsJsonObject("indexes");
        for(String name:union(a,b))if(!Objects.equals(a.get(name),b.get(name))) {
            if(a.has(name))dependencies.add(postgres?"DROP INDEX "+session.adapter.table("",schema,name)+";":"ALTER TABLE "+table+" DROP INDEX "+quote(name)+";");
            if(b.has(name))keys.add(postgres?b.get(name).getAsString()+";":"ALTER TABLE "+table+" ADD "+b.get(name).getAsString()+";");
        }
    }
    /** MySQL validates AUTO_INCREMENT/index requirements against the final ALTER
     * definition. Combining only our own generated clauses also preserves data
     * when replacing the key that owns an existing AUTO_INCREMENT column. */
    private void coalesceTableAlterations(String table,int dependencyStart,int keyStart) {
        String prefix="ALTER TABLE "+table+" ";
        var clauses=new ArrayList<String>();
        takeAlterClauses(dependencies,dependencyStart,prefix,clauses);
        String node=tableNodes.get(table);
        var structural=creationGroups.computeIfAbsent(node,ignored->new ArrayList<>());
        takeAlterClauses(structural,0,prefix,clauses);
        takeAlterClauses(keys,keyStart,prefix,clauses);
        if(!clauses.isEmpty())structural.add(prefix+String.join(", ",clauses)+";");
        if(structural.isEmpty())creationGroups.remove(node);
    }
    private static void takeAlterClauses(List<String> statements,int start,String prefix,List<String> clauses) {
        for(int index=start;index<statements.size();) {
            String sql=statements.get(index);
            if(sql.startsWith(prefix)&&sql.endsWith(";")) {
                clauses.add(sql.substring(prefix.length(),sql.length()-1));statements.remove(index);
            }else index++;
        }
    }
    private void columns(String table,JsonObject before,JsonObject after) {
        if(before.size()>2048||after.size()>2048)throw new IllegalArgumentException("Snapshot column limit is 2048");
        for(String name:before.keySet())if(!after.has(name))alter(table,"ALTER TABLE "+table+" DROP COLUMN "+quote(name)+";");
        var ordered=after.entrySet().stream().sorted(Comparator.comparingInt(e->e.getValue().getAsJsonObject().get("ordinal").getAsInt())).toList();
        String predecessor=null;
        for(var entry:ordered) {
            String name=entry.getKey();var a=before.getAsJsonObject(name);var b=entry.getValue().getAsJsonObject();String column=quote(name);
            if(a==null){alter(table,"ALTER TABLE "+table+" ADD COLUMN "+definition(name,b)+(!postgres?(predecessor==null?" FIRST":" AFTER "+quote(predecessor)):"")+";");}
            else if(!a.equals(b)) {
                if(!postgres){if(!b.has("definition"))unsupported("Native column definition missing: "+table+"."+name);else alter(table,"ALTER TABLE "+table+" MODIFY COLUMN "+b.get("definition").getAsString()+(a.get("ordinal").equals(b.get("ordinal"))?"":predecessor==null?" FIRST":" AFTER "+quote(predecessor))+";");}
                else postgresColumn(table,column,a,b);
                for(String property:union(a,b))if(!Set.of("type","nullable","default","special","generated","ordinal","definition","comment","collation","charset").contains(property)&&!Objects.equals(a.get(property),b.get(property)))unsupported("Changed captured column property "+property+" on "+table+"."+name);
            }
            predecessor=name;
        }
    }
    private String definition(String name,JsonObject column) {
        if(!postgres){if(!column.has("definition"))throw new IllegalArgumentException("Native column definition is required");return column.get("definition").getAsString();}
        String definition=quote(name)+" "+column.get("type").getAsString();
        if(!empty(column,"collation"))definition+=" COLLATE "+column.get("collation").getAsString();
        if(!empty(column,"special"))definition+=" GENERATED "+(column.get("special").getAsString().equals("a")?"ALWAYS":"BY DEFAULT")+" AS IDENTITY";
        else if(!empty(column,"generated"))definition+=" GENERATED ALWAYS AS ("+column.get("default").getAsString()+") STORED";
        else if(!empty(column,"default"))definition+=" DEFAULT "+column.get("default").getAsString();
        return definition+(column.get("nullable").getAsBoolean()?"":" NOT NULL");
    }
    private void postgresColumn(String table,String column,JsonObject before,JsonObject after) {
        String alter="ALTER TABLE "+table+" ALTER COLUMN "+column;
        if(!Objects.equals(before.get("comment"),after.get("comment")))alter(table,"COMMENT ON COLUMN "+table+"."+column+" IS "+literal(after.get("comment").getAsString())+";");
        if(!Objects.equals(before.get("collation"),after.get("collation")))alter(table,alter+" TYPE "+after.get("type").getAsString()+" COLLATE "+(empty(after,"collation")?"\"default\"":after.get("collation").getAsString())+";");
        if(!before.get("ordinal").equals(after.get("ordinal")))unsupported("PostgreSQL column reordering requires an explicit table rebuild: "+table+"."+column);
        if(!before.get("type").equals(after.get("type")))alter(table,alter+" TYPE "+after.get("type").getAsString()+";");
        if(!before.get("nullable").equals(after.get("nullable")))alter(table,alter+(after.get("nullable").getAsBoolean()?" DROP":" SET")+" NOT NULL;");
        if(!before.get("special").equals(after.get("special"))) {
            if(empty(after,"special"))alter(table,alter+" DROP IDENTITY;");
            else alter(table,alter+(empty(before,"special")?" ADD GENERATED ":" SET GENERATED ")+(after.get("special").getAsString().equals("a")?"ALWAYS":"BY DEFAULT")+(empty(before,"special")?" AS IDENTITY":"")+";");
        }
        if(!before.get("generated").equals(after.get("generated"))) {
            if(empty(after,"generated"))alter(table,alter+" DROP EXPRESSION;");
            else unsupported("Converting a base column into a generated column requires an explicit data-preservation plan: "+table+"."+column);
        }
        if(!before.get("default").equals(after.get("default"))) {
            if(!empty(after,"generated")&&!empty(before,"generated"))alter(table,alter+" SET EXPRESSION AS ("+after.get("default").getAsString()+");");
            else if(empty(after,"generated")&&empty(after,"special"))alter(table,alter+(empty(after,"default")?" DROP DEFAULT":" SET DEFAULT "+after.get("default").getAsString())+";");
            else if(empty(before,"generated"))unsupported("Default/generation transition requires explicit review: "+table+"."+column);
        }
    }
    private void properties(String table,JsonObject before,JsonObject after) {
        if(!Objects.equals(before.get("unsupportedProperties"),after.get("unsupportedProperties")))unsupported("Changed unsupported table properties on "+table);
        var a=before.getAsJsonObject("properties");var b=after.getAsJsonObject("properties");if(a==null&&b==null)return;
        if(a==null||b==null){unsupported("Snapshot table properties are incomplete: "+table);return;}
        for(String key:union(a,b))if(!Objects.equals(a.get(key),b.get(key))) {
            if(!b.has(key)){unsupported("Removed captured table property "+key+" on "+table);continue;}
            String value=b.get(key).getAsString();
            if(postgres&&key.equals("persistence")&&Set.of("p","u").contains(value))alter(table,"ALTER TABLE "+table+" SET "+(value.equals("p")?"LOGGED":"UNLOGGED")+";");
            else if(key.equals("engine")&&value.matches("[A-Za-z0-9_]{1,64}"))alter(table,"ALTER TABLE "+table+" ENGINE="+value+";");
            else if(key.equals("collation")&&value.matches("[A-Za-z0-9_]{1,128}"))alter(table,"ALTER TABLE "+table+" COLLATE="+value+";");
            else if(key.equals("rowFormat")&&Set.of("Dynamic","Compressed","Redundant","Compact","Fixed").contains(value))alter(table,"ALTER TABLE "+table+" ROW_FORMAT="+value.toUpperCase(Locale.ROOT)+";");
            else if(key.equals("comment"))alter(table,postgres?"COMMENT ON TABLE "+table+" IS "+literal(value)+";":"ALTER TABLE "+table+" COMMENT="+literal(value)+";");
            else unsupported("Changed captured table property "+key+" on "+table);
        }
    }
    static boolean triggerLookupAvailable(MetadataSnapshot evidence){return evidence.identifierRulesAvailable()&&evidence.rules().kindAvailable(ObjectKind.TRIGGER);}
    static boolean triggerChangesAvailable(JsonObject before,JsonObject after,MetadataSnapshot evidence){return before.equals(after)||triggerLookupAvailable(evidence);}
    private void triggerChanges(String table,JsonObject before,JsonObject after) {
        for(String name:union(before,after))if(!Objects.equals(before.get(name),after.get(name))) {
            if(before.has(name))dependencies.add("DROP TRIGGER "+(postgres?quote(name)+" ON "+table:session.adapter.table("",schema,name))+";");
            if(after.has(name))triggers.add(RoutineDefinitions.script(after.get(name).getAsString(),postgres));
        }
    }
    private void routineChanges(JsonObject before,JsonObject after) {
        var a=before.has("routines")?before.getAsJsonObject("routines"):new JsonObject();var b=after.has("routines")?after.getAsJsonObject("routines"):new JsonObject();
        for(String key:union(a,b)) {
            var x=a.getAsJsonObject(key);var y=b.getAsJsonObject(key);if(Objects.equals(x,y))continue;
            if(y!=null){var unknown=y.keySet().stream().filter(property->!Set.of("name","arguments","kind","definition","returnType","access").contains(property)).sorted().toList();if(!unknown.isEmpty()){unsupported("Routine "+key+" has unsupported captured properties: "+String.join(", ",unknown));continue;}}
            if(y!=null&&empty(y,"definition")){unsupported("Routine definition unavailable: "+key);continue;}
            if(postgres&&x!=null&&y!=null&&!Objects.equals(x.get("returnType"),y.get("returnType"))){unsupported("Routine return-type changes require explicit dependent-object review: "+key);continue;}
            if(x!=null&&y!=null) {
                boolean unsupportedProperty=false;
                for(String property:union(x,y))if(!Set.of("definition","access").contains(property)&&!Objects.equals(x.get(property),y.get(property))){unsupported("Routine identity/type/property change requires a separate native definition and dependency review: "+key+" ("+property+")");unsupportedProperty=true;}
                if(unsupportedProperty)continue;
            }
            var object=x!=null?x:y;
            List<String> access=List.of();
            if(y!=null&&(x==null||!postgres))try{access=RoutineAccess.restore(session,schema,y);}catch(UnsupportedOperationException unknown){unsupported(key+": "+unknown.getMessage());continue;}
            if(postgres&&x!=null&&y!=null&&!Objects.equals(x.get("access"),y.get("access"))){unsupported("Routine ownership/grant changes require the native privilege designer: "+key);continue;}
            String definition=null;
            if(y!=null)try{definition=DefinitionBinding.routine(session,schema,y,y.get("definition").getAsString());if(x!=null)DefinitionBinding.routine(session,schema,x,definition);}catch(IllegalArgumentException invalid){unsupported(key+": "+invalid.getMessage());continue;}
            String kind=Set.of("p","PROCEDURE").contains(object.get("kind").getAsString())?"PROCEDURE":"FUNCTION";
            if(x!=null&&(y==null||!postgres))dropGroups.put("R:"+key,List.of("DROP "+kind+" "+table(object.get("name").getAsString())+(postgres?"("+object.get("arguments").getAsString()+")":"")+";"));
            if(y!=null){var operations=new ArrayList<String>();operations.add(RoutineDefinitions.script(definition,postgres));operations.addAll(access);creationGroups.put("R:"+key,operations);}
            result.addRisks("Routine "+key+" retains its native security/definer and body. Review privileges and dependencies expressed inside procedural or dynamic SQL.");
        }
    }
    private void viewChanges(JsonObject before,JsonObject after,boolean baseChanged) {
        var a=before.getAsJsonObject("views");var b=after.getAsJsonObject("views");
        if(a.equals(b)&&Objects.equals(before.get("viewProperties"),after.get("viewProperties"))&&!baseChanged)return;
        // Changed base objects can affect unchanged dependent views. Explicitly
        // rebuild this supported view set in dependency order, without CASCADE.
        if((before.has("viewDependencyAvailability")||after.has("viewDependencyAvailability"))&&(!a.isEmpty()||!b.isEmpty())){unsupported("View dependencies unavailable; dependent views require explicit ordering");return;}
        var graph=after.has("viewDependencies")?after.getAsJsonObject("viewDependencies"):new JsonObject();
        var sourceGraph=before.has("viewDependencies")?before.getAsJsonObject("viewDependencies"):new JsonObject();
        var oldOrder=order(a,sourceGraph);
        for(String name:oldOrder)dropGroups.put("V:"+name,List.of("DROP VIEW "+table(name)+";"));
        for(String name:order(b,graph)) {
            if(b.get(name).isJsonNull()){unsupported("View definition unavailable: "+table(name));continue;}
            try {creationGroups.put("V:"+name,ViewProperties.create(session,schema,name,b.get(name).getAsString(),after.has("viewProperties")?after.getAsJsonObject("viewProperties").getAsJsonObject(name):null));}
            catch(UnsupportedOperationException unsupported){unsupported("View "+name+": "+unsupported.getMessage());}
        }
    }
    private void alter(String table,String sql) {
        String node=tableNodes.get(table);
        if(node==null)throw new IllegalStateException("Generated alteration has no captured target");
        creationGroups.computeIfAbsent(node,ignored->new ArrayList<>()).add(sql);
    }
    private void orderDrops(JsonObject source) {
        var graph=source.has("objectDependencies")?source.getAsJsonObject("objectDependencies"):new JsonObject();
        if(!postgres&&source.has("viewDependencies"))for(var entry:source.getAsJsonObject("viewDependencies").entrySet()) {
            var edges=new JsonArray();for(var dependency:entry.getValue().getAsJsonArray())edges.add("V:"+dependency.getAsString());graph.add("V:"+entry.getKey(),edges);
        }
        var remaining=new TreeSet<>(dropGroups.keySet());
        while(!remaining.isEmpty()) {
            String ready=remaining.stream().filter(name->remaining.stream().noneMatch(other->{var refs=graph.getAsJsonArray(other);return refs!=null&&refs.asList().stream().anyMatch(ref->ref.getAsString().equals(name));})).findFirst().orElse(null);
            if(ready==null){unsupported("Dependency cycle among removed/rebuilt objects: "+String.join(", ",remaining));break;}
            remaining.remove(ready);drops.addAll(dropGroups.get(ready));
        }
    }
    private void orderCreations(JsonObject target) {
        var graph=target.has("objectDependencies")?target.getAsJsonObject("objectDependencies"):new JsonObject();
        // MySQL/MariaDB expose native view relationships but no complete routine
        // body dependency catalog. Keep that distinction in the review.
        if(!postgres&&target.has("viewDependencies"))for(var entry:target.getAsJsonObject("viewDependencies").entrySet()) {
            var edges=new JsonArray();for(var dependency:entry.getValue().getAsJsonArray())edges.add("V:"+dependency.getAsString());graph.add("V:"+entry.getKey(),edges);
        }
        var remaining=new TreeSet<>(creationGroups.keySet());
        while(!remaining.isEmpty()) {
            String ready=remaining.stream().filter(name->{var refs=graph.getAsJsonArray(name);return refs==null||refs.asList().stream().noneMatch(ref->remaining.contains(ref.getAsString()));}).findFirst().orElse(null);
            if(ready==null){unsupported("Dependency cycle among created/replaced objects: "+String.join(", ",remaining));break;}
            remaining.remove(ready);
            // Views must follow column/constraint alterations, except when a new
            // routine needs a new view: then catalog order is authoritative.
            if(ready.startsWith("V:")&&remaining.stream().noneMatch(name->{var refs=graph.getAsJsonArray(name);return refs!=null&&refs.asList().stream().anyMatch(ref->ref.getAsString().equals(ready));}))views.addAll(creationGroups.get(ready));
            else creates.addAll(creationGroups.get(ready));
        }
        if(!creationGroups.isEmpty())result.addDependencies("Native PostgreSQL dependencies order tables, defaults, SQL routines and views; foreign keys and triggers follow base-object creation. Procedural/dynamic SQL dependencies not exposed by the server require review.");
    }
    private List<String> order(JsonObject objects,JsonObject graph) {
        var remaining=new TreeSet<>(objects.keySet());var ordered=new ArrayList<String>();
        while(!remaining.isEmpty()) {
            String ready=remaining.stream().filter(name->{var refs=graph.getAsJsonArray(name);return refs==null||refs.asList().stream().noneMatch(ref->remaining.contains(ref.getAsString()));}).findFirst().orElse(null);
            if(ready==null){unsupported("Dependency cycle in views: "+String.join(", ",remaining));break;}
            remaining.remove(ready);ordered.add(ready);
        }
        return ordered;
    }
    private String literal(String value){return (postgres?"E":"")+"'"+((postgres||!session.context.lexical().noBackslashEscapes())?value.replace("\\","\\\\"):value).replace("'","''")+"'";}
    private String kind(JsonObject table,String identity){return SchemaConstraints.kind(table.getAsJsonObject("constraints").getAsJsonObject(identity).get("type").getAsString());}
    private String table(String name){return session.adapter.table("",schema,name);}
    private String quote(String name){return session.adapter.quote(name);}
    private void unsupported(String detail){result.addUnsupported(detail);}
    private static Set<String> union(JsonObject a,JsonObject b){var keys=new TreeSet<String>();keys.addAll(a.keySet());keys.addAll(b.keySet());return keys;}
    private static boolean empty(JsonObject object,String key){return !object.has(key)||object.get(key).isJsonNull()||object.get(key).getAsString().isBlank();}
}
