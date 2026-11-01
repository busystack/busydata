package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class TimestampContextIT {
    @TempDir Path root;
    private static ChangeRequest change(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session,String table)throws Exception {
        String source=session.adapter.table(session.context.catalog(),fixture.schema(),table);var result=fixture.results.get(fixture.execute(session,"SELECT id,n,moment FROM "+source).info().getResults(0).getResultId());return ChangeRequest.newBuilder().setSessionId(session.id).setResultId(result.id).setCatalog(session.context.catalog()).setSchema(fixture.schema()).setTable(table).addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.value(Value.newBuilder().setSignedInteger("2").build()))).build();
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void changedZoneCannotMakeAnExternalTimestampMutationLookUnchangedAndRecoveryKeepsItsProof(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();fixture.execute(session,"SET SESSION time_zone='+00:00'");fixture.execute(session,"CREATE TABLE timestamp_context_values(id INTEGER PRIMARY KEY,n INTEGER NOT NULL,moment TIMESTAMP(6) NOT NULL); INSERT INTO timestamp_context_values VALUES(1,1,'2024-01-01 12:00:00.123456')");fixture.warm(session,"timestamp_context_values");
            var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());var original=change(fixture,session,"timestamp_context_values");var recovery=new EditDrafts(fixture.metadata,fixture.results,planner);var saved=recovery.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(session.id).setChanges(original).setDocumentId("timestamp-original").build());String draft=saved.getDrafts(0).getDraftId();var data=fixture.metadata.editDraft(draft).data();assertTrue(data.hasSourceTimeZone());assertEquals("+00:00",data.getSourceTimeZone());long contextRevision=session.contextRevision;
            fixture.execute(session,"SET SESSION time_zone='+01:00'");assertTrue(session.contextRevision>contextRevision);var external=fixture.open();fixture.execute(external,"SET SESSION time_zone='+00:00'");String source=session.adapter.table(session.context.catalog(),fixture.schema(),"timestamp_context_values");fixture.execute(external,"UPDATE "+source+" SET moment='2024-01-01 11:00:00.123456' WHERE id=1");
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT moment,n FROM "+source)){assertTrue(rows.next());assertEquals("2024-01-01 12:00:00.123456",rows.getString(1));assertEquals(1,rows.getInt(2));}
            assertEquals(WorkbenchFailure.Reason.STALE,assertThrows(WorkbenchFailure.class,()->planner.preview(session,original)).reason());var rebind=EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setSessionId(session.id).setDraftId(draft).setDocumentId("timestamp-recovery").build();assertEquals(WorkbenchFailure.Reason.STALE,assertThrows(WorkbenchFailure.class,()->recovery.run(fixture.sessions,rebind)).reason());assertEquals("STAGED",fixture.metadata.editDraft(draft).state());
            fixture.execute(session,"SET SESSION time_zone='+00:00'");var fresh=change(fixture,session,"timestamp_context_values");var proof=fixture.results.get(fresh.getResultId()).metadataProof();assertTrue(proof.available(),proof.state()+": "+proof.availability());EditingIT.apply(planner,fixture.jobs,session,fresh);try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT n FROM "+source)){assertTrue(rows.next());assertEquals(2,rows.getInt(1));}
            String missing=fixture.metadata.saveEditDraft("",data.toBuilder().clearSourceTimeZone().clearSourceSystemTimeZone().build());assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->recovery.run(fixture.sessions,rebind.toBuilder().setDraftId(missing).build())).reason());assertEquals("STAGED",fixture.metadata.editDraft(missing).state());assertEquals(data.getRowsList(),fixture.metadata.editDraft(missing).data().getRowsList());
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void systemDstContextsRetainReadableResultsButCannotAuthorizeTimestampVerification(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine,container->container.withEnv("TZ","Europe/Berlin"))){
            var session=fixture.open();assertEquals("SYSTEM",session.context.timeZone());assertNotEquals("UTC",session.context.systemTimeZone());fixture.execute(session,"CREATE TABLE timestamp_named_context(id INTEGER PRIMARY KEY,n INTEGER NOT NULL,moment TIMESTAMP(6) NOT NULL); INSERT INTO timestamp_named_context VALUES(1,1,'2024-01-01 12:00:00.123456')");fixture.warm(session,"timestamp_named_context");var request=change(fixture,session,"timestamp_named_context");assertEquals(1,fixture.results.get(request.getResultId()).rows());var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->planner.preview(session,request)).reason());
        }
    }
}
