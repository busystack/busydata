package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class MetadataResourcesIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void catalogDefaultsAreAdmittedBeforeDriverMaterializationAndSessionStaysUsable(String name)throws Exception {
        try(var fixture=new EngineFixture(root,name)) {
            var session=fixture.open();var tables=new java.util.ArrayList<String>();
            if(fixture.engine==Engine.POSTGRESQL) {
                tables.add("metadata_bytes");fixture.execute(session,"CREATE TABLE metadata_bytes(id INTEGER)");
                String value="x".repeat(300000);
                for(int index=0;index<34;index++)fixture.execute(session,"ALTER TABLE metadata_bytes ADD COLUMN c"+index+" TEXT DEFAULT ('"+value+"')");
            }else {
                // MariaDB's .frm definition and MySQL's dictionary impose their
                // own per-table/default limits. Retain a >4MiB valid workload
                // across tables rather than testing rejected server DDL.
                String value="x".repeat(14000);
                for(int index=0;index<110;index++) {
                    String table="metadata_bytes_"+index;tables.add(table);
                    fixture.execute(session,"CREATE TABLE "+table+"(id INTEGER,c0 LONGTEXT DEFAULT ('"+value+"'),c1 LONGTEXT DEFAULT ('"+value+"'),c2 LONGTEXT DEFAULT ('"+value+"'))");
                }
            }
            var listed=new Explorer(fixture.metadata).explore(session,ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setSchema(fixture.schema()).setTable(tables.getFirst()).build());
            if(fixture.engine==Engine.POSTGRESQL){assertTrue(listed.getAvailability().startsWith("limited:"),listed.toString());assertFalse(listed.getComplete());assertEquals(0,listed.getObjectsCount());
                session.connection.setAutoCommit(false);session.autoCommit=false;session.refresh();
                var isolated=new Explorer(fixture.metadata).explore(session,ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setSchema(fixture.schema()).setTable(tables.getFirst()).build());
                assertFalse(isolated.getComplete());assertTrue(isolated.getAvailability().startsWith("limited:"),isolated.toString());
                session.connection.rollback();session.connection.setAutoCommit(true);session.autoCommit=true;session.refresh();
            }
            else {assertTrue(listed.getComplete());assertEquals(4,listed.getObjectsCount());assertEquals("available",listed.getAvailability());assertTrue(listed.getObjects(1).getPropertiesOrDefault("default", "").contains("xxxx"));}
            var failure=assertThrows(Exception.class,()->new SchemaTools(fixture.metadata.metadataPlatform()).run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.CAPTURE_SCHEMA).setSchema(fixture.schema()).build()));
            assertInstanceOf(IllegalArgumentException.class,failure);
            assertTrue(failure.getMessage().contains("budget")||failure.getMessage().contains("limit"),"Expected the application resource policy, not a server fixture failure");
            fixture.execute(session,"SELECT 11");
            assertEquals(TransactionState.IDLE,session.state);
            fixture.execute(session,"DROP TABLE "+String.join(",",tables)+"; CREATE TABLE ordinary_metadata(id INTEGER PRIMARY KEY,n TEXT DEFAULT ('normal'))");
            var normal=new Explorer(fixture.metadata).explore(session,ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setSchema(fixture.schema()).setTable("ordinary_metadata").build());
            assertEquals(2,normal.getObjectsCount());
            assertTrue(normal.getComplete());
            assertFalse(new SchemaTools(fixture.metadata.metadataPlatform()).run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.CAPTURE_SCHEMA).setSchema(fixture.schema()).build()).getSnapshot().isEmpty());
        }
    }
}
