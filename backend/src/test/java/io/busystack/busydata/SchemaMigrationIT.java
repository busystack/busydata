package io.busystack.busydata;

import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.SchemaTools;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class SchemaMigrationIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void compositeKeysForeignKeyCyclesDefaultsGeneratedColumnsAndDependentViewsRoundTrip(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());String before=capture(tools,session,f.schema());
            f.execute(session,"CREATE TABLE parent_table(a INTEGER,b INTEGER,child_id INTEGER,n INTEGER DEFAULT 7,CONSTRAINT parent_pk PRIMARY KEY(a,b),CONSTRAINT parent_uq UNIQUE(n)); CREATE TABLE child_table(id INTEGER PRIMARY KEY,a INTEGER,b INTEGER,n INTEGER DEFAULT 3,g INTEGER GENERATED ALWAYS AS (n*2) STORED); CREATE INDEX child_n ON child_table(n); ALTER TABLE child_table ADD CONSTRAINT child_parent FOREIGN KEY(a,b) REFERENCES parent_table(a,b); ALTER TABLE parent_table ADD CONSTRAINT parent_child FOREIGN KEY(child_id) REFERENCES child_table(id); CREATE VIEW parent_view AS SELECT a,b,n FROM parent_table; CREATE VIEW dependent_view AS SELECT a,n FROM parent_view");
            String target=capture(tools,session,f.schema());
            f.execute(session,"DROP VIEW dependent_view; DROP VIEW parent_view; ALTER TABLE parent_table "+(f.engine==Engine.POSTGRESQL?"DROP CONSTRAINT":"DROP FOREIGN KEY")+" parent_child; DROP TABLE child_table; DROP TABLE parent_table");
            var plan=compare(tools,session,before,target);assertTrue(plan.getComplete(),plan.toString());
            f.execute(session,String.join("\n",plan.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(capture(tools,session,f.schema())),plan.toString());
            f.execute(session,"INSERT INTO parent_table(a,b,n) VALUES(1,2,7); INSERT INTO child_table(id,a,b,n) VALUES(1,1,2,5)");
            EditingIT.assertRows(session,"SELECT id,g FROM child_table",new int[][]{{1,10}});
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void modifiesOrdinaryColumnsAndIndexesWithoutDroppingUntouchedProperties(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());f.execute(session,"CREATE TABLE modify_table(id INTEGER PRIMARY KEY,n INTEGER DEFAULT 7); CREATE INDEX old_n ON modify_table(n)");String before=capture(tools,session,f.schema());
            String change=f.engine==Engine.POSTGRESQL?"ALTER TABLE modify_table ALTER COLUMN n TYPE BIGINT; ALTER TABLE modify_table ALTER COLUMN n SET DEFAULT 9; ALTER TABLE modify_table ALTER COLUMN n SET NOT NULL":"ALTER TABLE modify_table MODIFY COLUMN n BIGINT NOT NULL DEFAULT 9";
            f.execute(session,change+"; "+(f.engine==Engine.POSTGRESQL?"DROP INDEX old_n":"DROP INDEX old_n ON modify_table")+"; CREATE INDEX new_n ON modify_table(n)");String target=capture(tools,session,f.schema());
            f.execute(session,"DROP TABLE modify_table; CREATE TABLE modify_table(id INTEGER PRIMARY KEY,n INTEGER DEFAULT 7); CREATE INDEX old_n ON modify_table(n)");
            var plan=compare(tools,session,before,target);assertTrue(plan.getComplete(),plan.toString());f.execute(session,String.join("\n",plan.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(capture(tools,session,f.schema())));
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void routineAndTriggerDefinitionsProduceAppliedNativeBehavior(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());f.execute(session,"CREATE TABLE trigger_table(id INTEGER PRIMARY KEY,n INTEGER)");String before=capture(tools,session,f.schema());
            if(f.engine==Engine.POSTGRESQL)f.execute(session,"CREATE FUNCTION trigger_fn() RETURNS trigger LANGUAGE plpgsql AS $body$BEGIN NEW.n := NEW.n + 1; RETURN NEW; END;$body$; CREATE TRIGGER increment_n BEFORE INSERT ON trigger_table FOR EACH ROW EXECUTE FUNCTION trigger_fn()");
            else f.execute(session,"DELIMITER $$\nCREATE PROCEDURE ordinary_routine() BEGIN SELECT 7; END$$\nCREATE TRIGGER increment_n BEFORE INSERT ON trigger_table FOR EACH ROW SET NEW.n = NEW.n + 1$$\nDELIMITER ;\n");
            String target=capture(tools,session,f.schema());
            f.execute(session,"DROP TRIGGER increment_n"+(f.engine==Engine.POSTGRESQL?" ON trigger_table; DROP FUNCTION trigger_fn()":"; DROP PROCEDURE ordinary_routine"));
            var plan=compare(tools,session,before,target);assertTrue(plan.getComplete(),plan.toString());f.execute(session,String.join("\n",plan.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(capture(tools,session,f.schema())));
            f.execute(session,"INSERT INTO trigger_table VALUES(1,7)");EditingIT.assertRows(session,"SELECT id,n FROM trigger_table",new int[][]{{1,8}});
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void addedTableKeepsIndependentIndexesInAnAppliedRoundTrip(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());String before=capture(tools,session,f.schema());
            f.execute(session,"CREATE TABLE added (id INTEGER PRIMARY KEY,n INTEGER DEFAULT 7); CREATE INDEX added_n ON added(n)");
            String target=capture(tools,session,f.schema());f.execute(session,"DROP TABLE added");
            var plan=compare(tools,session,before,target);assertTrue(plan.getUnsupportedList().isEmpty(),plan.toString());
            f.execute(session,String.join("\n",plan.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(capture(tools,session,f.schema())),"Fresh canonical database introspection must match the desired indexed table");
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void changedTableCollationIsAnExplicitAppliedDifference(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());f.execute(session,"CREATE TABLE properties_table(id INTEGER PRIMARY KEY,n INTEGER) COLLATE utf8mb4_unicode_ci");
            String before=capture(tools,session,f.schema());f.execute(session,"ALTER TABLE properties_table COLLATE utf8mb4_bin");String target=capture(tools,session,f.schema());
            f.execute(session,"ALTER TABLE properties_table COLLATE utf8mb4_unicode_ci");
            var plan=compare(tools,session,before,target);assertFalse(plan.getSqlList().isEmpty(),"Captured collation cannot disappear from comparison");assertTrue(plan.getUnsupportedList().isEmpty(),plan.toString());
            f.execute(session,String.join("\n",plan.getSqlList()));assertEquals(JsonParser.parseString(target),JsonParser.parseString(capture(tools,session,f.schema())));
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void viewRebuildRetainsSecurityCheckOptionsAndExplicitGrants(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());f.execute(session,"CREATE TABLE protected_rows(id INTEGER PRIMARY KEY,n INTEGER)");
            f.execute(session,f.engine==Engine.POSTGRESQL?"CREATE ROLE view_reader;CREATE VIEW protected_view WITH (security_barrier=true,security_invoker=true) AS SELECT id,n FROM protected_rows WHERE n>0 WITH LOCAL CHECK OPTION;GRANT SELECT ON protected_view TO view_reader":"CREATE USER 'view_reader'@'localhost';CREATE SQL SECURITY INVOKER VIEW protected_view AS SELECT id,n FROM protected_rows WHERE n>0 WITH LOCAL CHECK OPTION;GRANT SELECT ON protected_view TO 'view_reader'@'localhost'");
            String target=capture(tools,session,f.schema());f.execute(session,"DROP VIEW protected_view");String source=capture(tools,session,f.schema());
            var plan=compare(tools,session,source,target);assertTrue(plan.getComplete(),plan.toString());f.execute(session,String.join("\n",plan.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(capture(tools,session,f.schema())),"Fresh security/options/grant introspection must match after rebuilding the view");
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void autoIncrementAndItsFirstKeyAreOneAppliedStructuralChange(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var tools=new SchemaTools(f.metadata.metadataPlatform());
            f.execute(session,"CREATE TABLE sequence_rows(id INTEGER NOT NULL,n VARCHAR(32) DEFAULT 'untouched'); INSERT INTO sequence_rows VALUES(7,'漢')");
            String source=capture(tools,session,f.schema());
            f.execute(session,"ALTER TABLE sequence_rows MODIFY COLUMN id INTEGER NOT NULL AUTO_INCREMENT, ADD PRIMARY KEY(id)");
            String target=capture(tools,session,f.schema());
            f.execute(session,"ALTER TABLE sequence_rows MODIFY COLUMN id INTEGER NOT NULL, DROP PRIMARY KEY");
            var plan=compare(tools,session,source,target);assertTrue(plan.getComplete(),plan.toString());
            f.execute(session,String.join("\n",plan.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(capture(tools,session,f.schema())));
            f.execute(session,"INSERT INTO sequence_rows(n) VALUES('next')");
            try(var query=session.connection.createStatement();var rows=query.executeQuery("SELECT id,n FROM sequence_rows ORDER BY id")) {
                assertTrue(rows.next());assertEquals(7,rows.getInt(1));assertEquals("漢",rows.getString(2));
                assertTrue(rows.next());assertEquals(8,rows.getInt(1));assertEquals("next",rows.getString(2));assertFalse(rows.next());
            }
        }
    }
    static String capture(SchemaTools tools,io.busystack.busydata.sessions.SessionRegistry.Session session,String schema)throws Exception{return tools.run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.CAPTURE_SCHEMA).setSchema(schema).build()).getSnapshot();}
    static SchemaToolResult compare(SchemaTools tools,io.busystack.busydata.sessions.SessionRegistry.Session session,String source,String target)throws Exception{return tools.run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSourceSnapshot(source).setTargetSnapshot(target).build());}
}
