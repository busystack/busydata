package io.busystack.busydata;

import io.busystack.busydata.metadata.IntrospectionLevel;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.ChangePlanner;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Object permissions cannot substitute for MySQL's native dictionary privilege. */
class OrdinaryMysqlEditingIT {
    @TempDir Path root;

    @Test void dictionaryDenialRemainsImmutableAndExplicitGrantEnablesOnlyFreshProof()throws Exception {
        try(var fixture=new EngineFixture(root,"MYSQL")) {
            var administrator=fixture.open();
            fixture.execute(administrator,"CREATE TABLE ordinary_edit(id INTEGER PRIMARY KEY,n VARCHAR(40)); INSERT INTO ordinary_edit VALUES(1,'unchanged')");
            // Disposable setup only: the product never grants privileges.
            try(var setup=administrator.connection.createStatement()) {
                setup.execute("CREATE USER 'ordinary_editor'@'%' IDENTIFIED BY 'fixture'");
                setup.execute("GRANT ALL PRIVILEGES ON busydata.* TO 'ordinary_editor'@'%'");
            }
            var profile=fixture.profile.toBuilder().setUser("ordinary_editor").setTls(Tls.newBuilder().setMode(TlsMode.DRIVER_DEFAULT)).build();
            var request=OpenRequest.newBuilder().setProfile(profile).setPassword("fixture").build();
            var limited=fixture.sessions.open(request);
            fixture.introspectionLevel(limited,IntrospectionLevel.STRUCTURE);
            fixture.warm(limited,"ordinary_edit");
            String table=limited.adapter.table(limited.context.catalog(),fixture.schema(),"ordinary_edit");
            var denied=fixture.results.get(fixture.execute(limited,"SELECT id,n FROM "+table).info().getResults(0).getResultId());
            var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());
            var deniedRequest=ChangeRequest.newBuilder().setSessionId(limited.id).setResultId(denied.id)
                .setCatalog(limited.context.catalog()).setSchema(fixture.schema()).setTable("ordinary_edit").build();
            var assessment=planner.assess(limited,deniedRequest);
            assertFalse(assessment.getEditable());assertEquals(WorkbenchFailure.Reason.DENIED.wire(),assessment.getReasonCode());
            assertEquals("unchanged",denied.read(0).getValues(1).getText(),"Denied metadata must leave exact results inspectable");

            try(var setup=administrator.connection.createStatement()) {
                setup.execute("GRANT PROCESS ON *.* TO 'ordinary_editor'@'%'");
            }
            // Static global privileges require a newly authenticated connection.
            // Neither the product nor this test reconnects the old owner silently.
            var permitted=fixture.sessions.open(request);
            assertNotEquals(limited.id,permitted.id);
            fixture.warm(permitted,"ordinary_edit");
            var fresh=fixture.results.get(fixture.execute(permitted,"SELECT id,n FROM "+table).info().getResults(0).getResultId());
            var freshRequest=deniedRequest.toBuilder().setSessionId(permitted.id).setResultId(fresh.id).build();
            var editable=planner.assess(permitted,freshRequest);
            assertTrue(editable.getEditable(),editable.getReasonCode());assertEquals(java.util.Set.of(1,2),java.util.Set.copyOf(editable.getEditableColumnsList()));
            assertEquals(2,editable.getEditableColumnsCount());
            var unchangedDenial=planner.assess(limited,deniedRequest);
            assertFalse(unchangedDenial.getEditable(),"New privileges and metadata cannot upgrade an old retained proof");
            assertEquals(WorkbenchFailure.Reason.DENIED.wire(),unchangedDenial.getReasonCode());
            assertEquals("unchanged",fresh.read(0).getValues(1).getText());
        }
    }
}
