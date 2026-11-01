package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class MetadataCommentsIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void nativeCommentSizesAndPreviewAvailabilityAreExplicit(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();var explorer=new Explorer(f.metadata);boolean pg=f.engine==Engine.POSTGRESQL;String comment="漢".repeat(pg?5000:2048);
            session.lock.lock();try{try(var statement=session.connection.createStatement()){statement.execute("CREATE TABLE comment_table(id INTEGER)");statement.execute(pg?"COMMENT ON TABLE comment_table IS '"+comment+"'":"ALTER TABLE comment_table COMMENT='"+comment+"'");statement.execute("CREATE VIEW comment_view AS SELECT id FROM comment_table");if(pg)statement.execute("COMMENT ON VIEW comment_view IS '"+comment+"'");}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}
            var request=ExploreRequest.newBuilder().setCatalog("busydata").setSchema(f.schema()).setKind(ObjectKind.TABLE).setSearch("comment_table").setExactName(true).setIntrospectionLevel(2).setIndependentMetadata(true);
            var table=explorer.explore(session,request.build());assertEquals("AVAILABLE",table.getMetadataState());assertTrue(table.getComplete());var object=table.getObjects(0);assertEquals(Long.toString(comment.getBytes(StandardCharsets.UTF_8).length),object.getPropertiesOrThrow("remarksBytes"));assertEquals(pg?"LIMITED":"AVAILABLE",object.getPropertiesOrThrow("remarksAvailability"));assertEquals(pg?comment.substring(0,2048):comment,object.getPropertiesOrThrow("remarks"));
            var view=explorer.explore(session,request.setKind(ObjectKind.VIEW).setSearch("comment_view").build()).getObjects(0);assertEquals(pg?"LIMITED":"AVAILABLE",view.getPropertiesOrThrow("remarksAvailability"));
            if(pg){assertEquals(object.getPropertiesOrThrow("remarksBytes"),view.getPropertiesOrThrow("remarksBytes"));String previous=object.getPropertiesOrThrow("catalogFingerprint");session.lock.lock();try{try(var statement=session.connection.createStatement()){statement.execute("COMMENT ON TABLE comment_table IS '"+comment+"changed-tail'");}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}var changed=explorer.refreshFragment(session,"busydata",f.schema(),"comment_table",ObjectKind.TABLE).resolve("busydata",f.schema(),ObjectKind.TABLE,"","comment_table",true).getFirst();assertNotEquals(previous,changed.properties().get("catalogFingerprint"));assertEquals("LIMITED",changed.properties().get("remarksAvailability"));}
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void namesOfPermittedBaseTablesDoNotRequireViewSourcePrivileges(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var administrator=f.open();try(var statement=administrator.connection.createStatement()){statement.execute("CREATE TABLE permission_table(id INTEGER)");statement.execute("CREATE VIEW permission_view AS SELECT id FROM permission_table");statement.execute("CREATE USER 'metadata_names_only'@'%' IDENTIFIED BY 'fixture'");statement.execute("GRANT SELECT ON busydata.permission_table TO 'metadata_names_only'@'%'");}
            var limited=f.sessions.open(OpenRequest.newBuilder().setProfile(f.profile.toBuilder().setId("limited-metadata").setUser("metadata_names_only")).setPassword("fixture").build());
            assertThrows(java.sql.SQLException.class,()->{try(var statement=limited.connection.createStatement()){statement.executeQuery("SHOW CREATE VIEW busydata.permission_view");}});
            var names=new Explorer(f.metadata).explore(limited,ExploreRequest.newBuilder().setCatalog("busydata").setSchema("busydata").setKind(ObjectKind.TABLE).setSearch("permission_table").setExactName(true).setIntrospectionLevel(1).setIndependentMetadata(true).build());assertTrue(names.getComplete());assertEquals("AVAILABLE",names.getMetadataState());assertEquals("permission_table",names.getObjects(0).getName());assertEquals(1,names.getIntrospectionLevel());
        }
    }
}
