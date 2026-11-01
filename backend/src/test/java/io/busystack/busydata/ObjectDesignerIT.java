package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.SchemaTools;
import io.busystack.busydata.schema.SchemaConstraints;
import com.google.gson.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class ObjectDesignerIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void nativeDesignerPreservesPropertiesAndAppliesOrdinaryChanges(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();var tools=new SchemaTools(fixture.metadata.metadataPlatform());
            fixture.execute(session,"CREATE TABLE designed(id INTEGER PRIMARY KEY,n INTEGER NOT NULL DEFAULT 7,v VARCHAR(40) NOT NULL DEFAULT 'old'"+(fixture.engine==Engine.POSTGRESQL?"":" COMMENT 'retained'")+")");
            if(fixture.engine==Engine.POSTGRESQL)fixture.execute(session,"COMMENT ON COLUMN designed.v IS 'retained'");
            var base=SchemaToolRequest.newBuilder().setSessionId(session.id).setAction(SchemaToolAction.DESIGN_COLUMN).setSchema(fixture.schema()).setTable("designed");
            apply(fixture,session,tools,base.clone().setOperation("alter").setColumn("v").setProperty("type").setValue("varchar(80)"));
            var current=tools.capture(session,fixture.schema()).getAsJsonObject("tables").getAsJsonObject("designed").getAsJsonObject("columns").getAsJsonObject("v");
            assertEquals("retained",current.get("comment").getAsString());assertFalse(current.get("nullable").getAsBoolean());assertTrue(current.get("default").getAsString().contains("old"));
            apply(fixture,session,tools,base.clone().setOperation("alter").setColumn("v").setProperty("default").setValue("'changed'"));
            apply(fixture,session,tools,base.clone().setOperation("alter").setColumn("v").setProperty("nullable").setValue("true"));
            apply(fixture,session,tools,base.clone().setOperation("index").setObjectName("designed_n_idx").addObjectColumns("n"));
            apply(fixture,session,tools,base.clone().setOperation("constraint").setObjectName("positive_n").setObjectKind("check").setExpression("n>=0"));
            apply(fixture,session,tools,base.clone().setOperation("add").setColumn("g").setType("integer").setNullable(true).setProperty("generated").setValue("n+1"));
            fixture.execute(session,"INSERT INTO designed(id) VALUES(1)");
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT n,v,g FROM designed")){assertTrue(rows.next());assertEquals(7,rows.getInt(1));assertEquals("changed",rows.getString(2));assertEquals(8,rows.getInt(3));}
            var snapshot=tools.capture(session,fixture.schema());var object=snapshot.getAsJsonObject("tables").getAsJsonObject("designed");
            assertTrue(object.getAsJsonObject("indexes").has("designed_n_idx"));assertTrue(SchemaConstraints.find(object,"positive_n",fixture.engine==Engine.POSTGRESQL?"c":"CHECK")!=null);assertEquals("retained",object.getAsJsonObject("columns").getAsJsonObject("v").get("comment").getAsString());
            fixture.execute(session,"CREATE TABLE parent_pair(a INTEGER,b INTEGER,PRIMARY KEY(a,b));CREATE TABLE child_pair(id INTEGER PRIMARY KEY,a INTEGER,b INTEGER);INSERT INTO parent_pair VALUES(1,2);INSERT INTO child_pair VALUES(7,1,2)");
            apply(fixture,session,tools,base.clone().setTable("child_pair").setOperation("constraint").setObjectName("child_parent").setObjectKind("foreign").addObjectColumns("a").addObjectColumns("b").setReferenceTable("parent_pair").addReferenceColumns("a").addReferenceColumns("b").setOnDelete("CASCADE").setOnUpdate("CASCADE").setDeferrable(fixture.engine==Engine.POSTGRESQL).setInitiallyDeferred(fixture.engine==Engine.POSTGRESQL));
            fixture.execute(session,"UPDATE parent_pair SET a=3 WHERE a=1");EditingIT.assertRows(session,"SELECT a,b FROM child_pair",new int[][]{{3,2}});
            fixture.execute(session,"DELETE FROM parent_pair WHERE a=3");EditingIT.assertRows(session,"SELECT a,b FROM child_pair",new int[][]{});
            snapshot=tools.capture(session,fixture.schema());
            var stale=base.clone().setSourceSnapshot(snapshot.toString()).setOperation("alter").setColumn("v").setProperty("type").setValue("varchar(90)").build();
            fixture.execute(session,"ALTER TABLE designed ADD COLUMN external_change INTEGER");
            assertTrue(assertThrows(IllegalArgumentException.class,()->tools.run(session,stale)).getMessage().contains("metadata changed"));
        }
    }
    private static void apply(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session,SchemaTools tools,SchemaToolRequest.Builder request)throws Exception{
        var source=tools.capture(session,fixture.schema());var plan=tools.run(session,request.setSourceSnapshot(source.toString()).build());
        assertTrue(plan.getComplete(),plan.toString());assertFalse(plan.getSqlList().isEmpty());fixture.execute(session,String.join("\n",plan.getSqlList()));
    }
}
