package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.schema.SchemaTools;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;
class ObjectSearchIT {
 @TempDir Path root;
 @Test void viewChildSearchResolvesOnlyItsExactPhysicalParent()throws Exception {
  try(var fixture=new EngineFixture(root,"POSTGRESQL")) {
   var source=fixture.open();var explorer=new Explorer(fixture.metadata);
   fixture.execute(source,"CREATE SCHEMA audit; CREATE VIEW audit.named_parent AS SELECT 1 AS view_late_column; CREATE MATERIALIZED VIEW audit.named_materialized AS SELECT 1 AS id; CREATE INDEX materialized_child_index ON audit.named_materialized(id); CREATE DATABASE other_parent_database");
   var other=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile).setCatalog("other_parent_database").setPassword("fixture").build());
   fixture.execute(other,"CREATE SCHEMA audit; CREATE TABLE audit.named_parent(view_late_column text); CREATE TABLE audit.named_materialized(id integer)");
   for(var entry:Map.of("view_late_column","named_parent","materialized_child_index","named_materialized").entrySet()) {
    var found=explorer.explore(source,ExploreRequest.newBuilder().setGlobalSearch(true).setCatalog("busydata").setSchema("audit").setSearch(entry.getKey()).build());
    assertTrue(found.getComplete());assertEquals(1,found.getObjectsCount());var child=found.getObjects(0);
    assertEquals("busydata",child.getCatalog());assertEquals("audit",child.getSchema());assertEquals(entry.getValue(),child.getTable());
    assertEquals(entry.getKey().equals("view_late_column")?ObjectKind.COLUMN:ObjectKind.INDEX,child.getKind());
    var parent=ExploreRequest.newBuilder().setCatalog(child.getCatalog()).setSchema(child.getSchema()).setExactName(true).setSearch(child.getTable()).setLimit(1);
    assertEquals(0,explorer.explore(source,parent.setKind(ObjectKind.TABLE).build()).getObjectsCount());
    var view=explorer.explore(source,parent.setKind(ObjectKind.VIEW).build()).getObjects(0);
    assertEquals(entry.getKey().equals("view_late_column")?ObjectSubtype.REGULAR_VIEW:ObjectSubtype.MATERIALIZED_VIEW,view.getSubtype());
    var exact=explorer.explore(source,parent.setKind(child.getKind()).setTable(child.getTable()).setSearch(child.getName()).build());
    assertEquals(child.getName(),exact.getObjects(0).getName());assertEquals(child.getCatalog(),exact.getObjects(0).getCatalog());
   }
   assertEquals("busydata",source.context.catalog());assertEquals("busydata",source.connection.getCatalog());
  }
 }
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void routineTreeAndSearchUseTheExactNativeSnapshotIdentity(String engine)throws Exception {
  try(var fixture=new EngineFixture(root,engine)) {
   var session=fixture.open();boolean pg=fixture.engine==Engine.POSTGRESQL;
   String qualified=session.adapter.table("",fixture.schema(),"find_routine_漢");
   fixture.execute(session,pg?
    "CREATE FUNCTION "+qualified+"(\"quoted argument\" integer) RETURNS integer LANGUAGE SQL AS $$ SELECT 7 $$; CREATE FUNCTION "+qualified+"(x text) RETURNS text LANGUAGE SQL AS $$ SELECT x $$; CREATE PROCEDURE "+qualified+"(x bigint) LANGUAGE SQL AS $$ SELECT x $$;":
    "CREATE FUNCTION "+qualified+"(x INTEGER) RETURNS INTEGER DETERMINISTIC RETURN x+7; CREATE PROCEDURE "+qualified+"(IN x INTEGER) SELECT x;");
   var definitions=new io.busystack.busydata.schema.SchemaTools(new io.busystack.busydata.metadata.MetadataPlatform()).capture(session,fixture.schema()).getAsJsonObject("routines");
   var explorer=new Explorer(fixture.metadata);var tree=explorer.explore(session,ExploreRequest.newBuilder().setKind(ObjectKind.ROUTINE).setSchema(fixture.schema()).build());
   var actual=tree.getObjectsList().stream().filter(o->o.getName().equals("find_routine_漢")).toList();
   assertEquals(pg?3:2,actual.size());assertEquals(actual.size(),actual.stream().map(SchemaObject::getIdentifier).distinct().count());
   for(var subtype:List.of(ObjectSubtype.FUNCTION,ObjectSubtype.PROCEDURE)) {
    var filtered=ExploreRequest.newBuilder().setKind(ObjectKind.ROUTINE).setSchema(fixture.schema()).setSubtype(subtype).setLimit(1).build();
    var seen=new HashSet<String>();String cursor="";
    do {var page=explorer.explore(session,filtered.toBuilder().setContinuation(cursor).build());
     assertEquals(subtype,page.getSubtype());assertEquals(actual.stream().filter(o->o.getSubtype()==subtype).count(),page.getTotalCount());
     assertTrue(page.getObjectsList().stream().allMatch(o->o.getSubtype()==subtype));for(var o:page.getObjectsList())assertTrue(seen.add(o.getIdentifier()));
     if(!page.getContinuation().isEmpty())assertThrows(Explorer.ContinuationFailure.class,()->explorer.explore(session,filtered.toBuilder().setSubtype(subtype==ObjectSubtype.FUNCTION?ObjectSubtype.PROCEDURE:ObjectSubtype.FUNCTION).setContinuation(page.getContinuation()).build()));
     cursor=page.getContinuation();
    }while(!cursor.isEmpty());
    assertEquals(actual.stream().filter(o->o.getSubtype()==subtype).count(),seen.size());
   }
   for(var object:actual){assertFalse(object.getIdentifier().isEmpty());assertTrue(definitions.has(object.getIdentifier()),object.toString());assertTrue(definitions.getAsJsonObject(object.getIdentifier()).get("definition").getAsString().contains("find_routine_漢"));
    var exact=explorer.explore(session,ExploreRequest.newBuilder().setKind(ObjectKind.ROUTINE).setSchema(fixture.schema()).setSearch(object.getName()).setExactName(true).setIdentifier(object.getIdentifier()).setLimit(1).build());
    assertEquals(1,exact.getTotalCount());assertTrue(exact.getComplete());assertEquals(object.getIdentifier(),exact.getObjects(0).getIdentifier());
    var ddl=new SchemaTools(fixture.metadata.metadataPlatform()).run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.OBJECT_DEFINITION).setCatalog("busydata").setSchema(fixture.schema()).setKind(ObjectKind.ROUTINE).setTable(object.getName()).setIdentifier(object.getIdentifier()).build());
    assertEquals(object.getIdentifier(),ddl.getInspectedObject().getIdentifier());assertTrue(ddl.getDefinition().contains("find_routine_漢"));assertTrue(ddl.getDefinition().toUpperCase(java.util.Locale.ROOT).contains("CREATE"));assertTrue(ddl.getSnapshot().isEmpty());
   }
   var request=ExploreRequest.newBuilder().setGlobalSearch(true).setSchema(fixture.schema()).setSearch("find_routine_漢").setLimit(1).build();
   var found=new LinkedHashSet<String>();String continuation="";
   do {var page=explorer.explore(session,request.toBuilder().setContinuation(continuation).build());assertEquals(1,page.getObjectsCount());var object=page.getObjects(0);assertTrue(found.add(object.getIdentifier()),"Overloaded routines must advance independently");assertTrue(definitions.has(object.getIdentifier()));continuation=page.getContinuation();assertTrue(found.size()<=actual.size());}while(!continuation.isEmpty());
   assertEquals(actual.stream().map(SchemaObject::getIdentifier).collect(java.util.stream.Collectors.toSet()),found);
   assertThrows(IllegalArgumentException.class,()->explorer.explore(session,request.toBuilder().setContinuation("x".repeat(24577)).build()));
  }
 }
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void searchesActualCatalogsAndPaginatesBeyondTheDisplayedTree(String engine)throws Exception{
  try(var fixture=new EngineFixture(root,engine)){
   var session=fixture.open();String quote=fixture.engine==Engine.POSTGRESQL?"\"":"`";
   fixture.execute(session,"CREATE TABLE "+quote+"find_%_漢"+quote+" (id INTEGER PRIMARY KEY, find_column INTEGER); CREATE INDEX find_index ON "+quote+"find_%_漢"+quote+" (find_column);");
   var explorer=new Explorer(fixture.metadata);var request=ExploreRequest.newBuilder().setGlobalSearch(true).setSearch("find").setLimit(1).build();var seen=new ArrayList<SchemaObject>();String continuation="";
   do {var page=explorer.explore(session,request.toBuilder().setContinuation(continuation).build());assertFalse(page.getObjectsList().isEmpty());assertEquals(session.contextRevision,page.getContextRevision());seen.addAll(page.getObjectsList());continuation=page.getContinuation();if(page.getComplete())assertTrue(continuation.isEmpty());assertTrue(seen.size()<20);}while(!continuation.isEmpty());
   assertTrue(seen.stream().anyMatch(o->o.getKind()==ObjectKind.TABLE&&o.getName().equals("find_%_漢")),seen.toString());
   assertTrue(seen.stream().anyMatch(o->o.getKind()==ObjectKind.COLUMN&&o.getName().equals("find_column")));
   assertTrue(seen.stream().anyMatch(o->o.getKind()==ObjectKind.INDEX&&o.getName().equals("find_index")));
   var literal=explorer.explore(session,request.toBuilder().setSearch("_%_").setLimit(200).build());assertTrue(literal.getObjectsList().stream().allMatch(o->o.getName().contains("_%_")));assertTrue(literal.getObjectsList().stream().anyMatch(o->o.getKind()==ObjectKind.TABLE&&o.getName().equals("find_%_漢")));
   var first=explorer.explore(session,request);assertThrows(IllegalArgumentException.class,()->explorer.explore(session,request.toBuilder().setSearch("other").setContinuation(first.getContinuation()).build()));
  }
 }
}
