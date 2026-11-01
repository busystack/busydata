package io.busystack.busydata;

import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.SchemaTools;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class SchemaDependencyIT {
    @TempDir Path root;
    @Test void nativeSqlRoutineTableDefaultViewAndReverseDropsRoundTrip()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")) {
            var session=fixture.open();var tools=new SchemaTools(fixture.metadata.metadataPlatform());
            String source=SchemaMigrationIT.capture(tools,session,fixture.schema());
            fixture.execute(session,"CREATE FUNCTION ordinary_value() RETURNS integer LANGUAGE SQL RETURN 7; CREATE TABLE depends_value(id INTEGER PRIMARY KEY,n INTEGER DEFAULT ordinary_value()); CREATE VIEW depends_view AS SELECT id,n FROM depends_value; CREATE FUNCTION view_count() RETURNS bigint LANGUAGE SQL RETURN (SELECT count(*) FROM depends_view); CREATE VIEW depends_function AS SELECT view_count() AS n");
            String target=SchemaMigrationIT.capture(tools,session,fixture.schema());
            var remove=SchemaMigrationIT.compare(tools,session,target,source);assertTrue(remove.getComplete(),remove.toString());
            fixture.execute(session,String.join("\n",remove.getSqlList()));
            assertEquals(JsonParser.parseString(source),JsonParser.parseString(SchemaMigrationIT.capture(tools,session,fixture.schema())));
            var add=SchemaMigrationIT.compare(tools,session,source,target);assertTrue(add.getComplete(),add.toString());
            fixture.execute(session,String.join("\n",add.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(SchemaMigrationIT.capture(tools,session,fixture.schema())),add.toString());
            fixture.execute(session,"INSERT INTO depends_value(id) VALUES(1)");
            EditingIT.assertRows(session,"SELECT id,n FROM depends_value",new int[][]{{1,7}});
            EditingIT.assertRows(session,"SELECT n FROM depends_function",new int[][]{{1}});
        }
    }
    @Test void sqlRoutineAndViewFollowAnAddedColumnOnAnExistingTable()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")) {
            var session=fixture.open();var tools=new SchemaTools(fixture.metadata.metadataPlatform());fixture.execute(session,"CREATE TABLE existing_base(id INTEGER PRIMARY KEY)");
            String source=SchemaMigrationIT.capture(tools,session,fixture.schema());
            fixture.execute(session,"ALTER TABLE existing_base ADD COLUMN n INTEGER DEFAULT 7; CREATE FUNCTION new_column_value() RETURNS bigint LANGUAGE SQL RETURN (SELECT sum(n) FROM existing_base); CREATE VIEW new_column_view AS SELECT new_column_value() AS n");
            String target=SchemaMigrationIT.capture(tools,session,fixture.schema());
            fixture.execute(session,"DROP VIEW new_column_view; DROP FUNCTION new_column_value(); ALTER TABLE existing_base DROP COLUMN n");
            var plan=SchemaMigrationIT.compare(tools,session,source,target);assertTrue(plan.getComplete(),plan.toString());
            fixture.execute(session,String.join("\n",plan.getSqlList()));
            assertEquals(JsonParser.parseString(target),JsonParser.parseString(SchemaMigrationIT.capture(tools,session,fixture.schema())),plan.toString());
            fixture.execute(session,"INSERT INTO existing_base(id) VALUES(1)");EditingIT.assertRows(session,"SELECT n FROM new_column_view",new int[][]{{7}});
        }
    }
    @Test void explicitNativeCreationCycleCannotBeACompletePlan()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")) {
            var session=fixture.open();var tools=new SchemaTools(fixture.metadata.metadataPlatform());String source=SchemaMigrationIT.capture(tools,session,fixture.schema());
            fixture.execute(session,"CREATE TABLE cycle_target(id INTEGER PRIMARY KEY);CREATE FUNCTION cycle_function() RETURNS integer LANGUAGE SQL RETURN 1");
            var target=JsonParser.parseString(SchemaMigrationIT.capture(tools,session,fixture.schema())).getAsJsonObject();
            var graph=target.getAsJsonObject("objectDependencies");var a=new JsonArray();a.add("R:cycle_function()");graph.add("T:cycle_target",a);var b=new JsonArray();b.add("T:cycle_target");graph.add("R:cycle_function()",b);
            var plan=SchemaMigrationIT.compare(tools,session,source,target.toString());
            assertFalse(plan.getComplete());assertFalse(plan.getEquivalent());assertTrue(plan.getUnsupportedList().stream().anyMatch(value->value.contains("Dependency cycle")));
        }
    }
}
