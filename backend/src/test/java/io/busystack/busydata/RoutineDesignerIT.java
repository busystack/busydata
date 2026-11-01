package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.SchemaTools;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;
class RoutineDesignerIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void nativeDefinitionDesignerCreatesExecutesAndInspectsAQualifiedRoutine(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());var base=SchemaToolRequest.newBuilder().setAction(SchemaToolAction.DESIGN_COLUMN).setSchema(f.schema()).setSourceSnapshot(tools.capture(s,f.schema()).toString()).setOperation("routine").setObjectName("routine_漢").setProperty("add");
   String name=s.adapter.table("",f.schema(),"routine_漢");
   String definition=f.engine==Engine.POSTGRESQL?"CREATE FUNCTION "+name+"(x integer) RETURNS integer LANGUAGE SQL AS $$ SELECT x+7 $$":"CREATE FUNCTION "+name+"(x INTEGER) RETURNS INTEGER DETERMINISTIC RETURN x+7";
   var plan=tools.run(s,base.clone().setDefinition(definition).build());assertTrue(plan.getComplete(),plan.toString());
   assertEquals(JobState.COMPLETED,f.execute(s,String.join("\n",plan.getSqlList())).state);
   try(var statement=s.connection.createStatement();var rows=statement.executeQuery("SELECT "+name+"(2)")){assertTrue(rows.next());assertEquals(9,rows.getInt(1));}
   assertTrue(tools.capture(s,f.schema()).getAsJsonObject("routines").keySet().stream().anyMatch(key->key.contains("routine_漢")));
   assertThrows(IllegalArgumentException.class,()->tools.run(s,base.clone().setSourceSnapshot(tools.capture(s,f.schema()).toString()).setObjectName("another").setDefinition(definition).build()));
   String comment="Table 'quotes' \\ Unicode 漢";
   f.execute(s,"CREATE TABLE comments(id INTEGER PRIMARY KEY)");
   var commentRequest=base.clone().setSourceSnapshot(tools.capture(s,f.schema()).toString()).setTable("comments").setOperation("property").setProperty("comment").setValue(comment).build();
   var commentPlan=tools.run(s,commentRequest);assertTrue(commentPlan.getComplete(),commentPlan.toString());f.execute(s,String.join("\n",commentPlan.getSqlList()));
   assertEquals(comment,tools.capture(s,f.schema()).getAsJsonObject("tables").getAsJsonObject("comments").getAsJsonObject("properties").get("comment").getAsString());
  }
 }
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void inspectedReplacementRetainsIdentitySignatureAndAccessAndRecapturesExactly(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());boolean pg=f.engine==Engine.POSTGRESQL;String name=s.adapter.table("",f.schema(),"edited_routine");
   f.execute(s,pg?"CREATE FUNCTION "+name+"(x integer) RETURNS integer LANGUAGE SQL AS $$ SELECT x+7 $$":"CREATE FUNCTION "+name+"(x INTEGER) RETURNS INTEGER DETERMINISTIC RETURN x+7");
   String principal=pg?"routine_reader":"'routine_reader'@'%'";
   f.execute(s,pg?"CREATE ROLE routine_reader":"CREATE USER "+principal+" IDENTIFIED BY 'fixture'");
   f.execute(s,"GRANT EXECUTE ON FUNCTION "+name+(pg?"(integer)":"")+" TO "+principal+" WITH GRANT OPTION");
   var before=tools.capture(s,f.schema());var routines=before.getAsJsonObject("routines");String key=routines.keySet().stream().filter(k->k.contains("edited_routine")).findFirst().orElseThrow();
   String nativeSql=routines.getAsJsonObject(key).get("definition").getAsString();assertTrue(nativeSql.contains("x+7"),nativeSql);
   var request=SchemaToolRequest.newBuilder().setAction(SchemaToolAction.DESIGN_COLUMN).setSchema(f.schema()).setSourceSnapshot(before.toString()).setOperation("routine").setObjectName(key).setProperty("alter").setDefinition(nativeSql.replace("x+7","x+8"));
   var plan=tools.run(s,request.build());assertTrue(plan.getComplete(),plan.toString());f.execute(s,String.join("\n",plan.getSqlList()));
   var after=tools.capture(s,f.schema());assertEquals(com.google.gson.JsonParser.parseString(plan.getSnapshot()),after,"Fresh canonical introspection must match the intended target, including routine grants");
   if(pg)f.execute(s,"SET ROLE routine_reader");
   var reader=pg?s:f.sessions.open(OpenRequest.newBuilder().setProfile(f.profile.toBuilder().setUser("routine_reader")).setPassword("fixture").build());
   try(var statement=reader.connection.createStatement();var rows=statement.executeQuery("SELECT "+name+"(2)")){assertTrue(rows.next());assertEquals(10,rows.getInt(1));}
   if(pg)f.execute(s,"RESET ROLE");else f.sessions.close(reader.id,true);
   request.setSourceSnapshot(after.toString());
   assertThrows(IllegalArgumentException.class,()->tools.run(s,request.clone().setDefinition(after.getAsJsonObject("routines").getAsJsonObject(key).get("definition").getAsString().replace("edited_routine","another_target")).build()));
   String current=after.getAsJsonObject("routines").getAsJsonObject(key).get("definition").getAsString();
   String changedSignature=current.replaceFirst("\\b(?:integer|int)\\b","bigint");assertNotEquals(current,changedSignature);
   assertThrows(IllegalArgumentException.class,()->tools.run(s,request.clone().setDefinition(changedSignature).build()));
   var unknown=after.deepCopy();unknown.getAsJsonObject("routines").getAsJsonObject(key).addProperty("futureSemanticProperty","changed");
   var incomplete=tools.run(s,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSourceSnapshot(after.toString()).setTargetSnapshot(unknown.toString()).build());
   assertFalse(incomplete.getComplete());assertFalse(incomplete.getEquivalent());assertTrue(incomplete.getUnsupportedList().stream().anyMatch(item->item.contains("futureSemanticProperty")));
  }
 }

}
