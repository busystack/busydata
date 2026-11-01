package io.busystack.busydata;

import io.busystack.busydata.metadata.MetadataState;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Session-dependent array text never borrows a later session's interpretation. */
class ArrayContextIT {
    @TempDir Path root;
    private static ChangeRequest source(EngineFixture f,io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception {
        String table=session.adapter.table(session.context.catalog(),f.schema(),"array_context_rows");
        var result=f.results.get(f.execute(session,"SELECT id,n,days FROM "+table).info().getResults(0).getResultId());
        return ChangeRequest.newBuilder().setSessionId(session.id).setResultId(result.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("array_context_rows").addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.value(EditingIT.integer(9)))).build();
    }
    @Test void arrayNullAndDateOutputContextsCannotBeReinterpretedByLaterReviewOrRecovery()throws Exception {
        try(var f=new EngineFixture(root,"POSTGRESQL")){
            var session=f.open();f.execute(session,"CREATE TABLE array_context_rows(id INTEGER PRIMARY KEY,n INTEGER,days DATE[]); INSERT INTO array_context_rows VALUES(1,2,ARRAY[DATE '2024-02-03',NULL])");f.warm(session,"array_context_rows");var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            f.execute(session,"SET array_nulls=off");f.warm(session,"array_context_rows");var off=source(f,session);assertEquals(MetadataState.UNSUPPORTED,f.results.get(off.getResultId()).metadataProof().state());
            f.execute(session,"SET array_nulls=on; SET DateStyle='ISO, MDY'");f.warm(session,"array_context_rows");assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->planner.preview(session,off)).reason());
            var safe=source(f,session);var recovery=new EditDrafts(f.metadata,f.results,planner);String id=recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(session.id).setDocumentId("array-context").setChanges(safe).build()).getDrafts(0).getDraftId();var saved=f.metadata.editDraft(id).data();
            // The pinned driver's native protocol contract itself requires ISO
            // and closes a connection receiving a different DateStyle. Exercise
            // that real limitation without pretending a live SQL-style context
            // can be established; the pure proof test covers captured contexts.
            var incompatible=f.open();var attempted=f.submit(incompatible,"SET DateStyle='SQL, DMY'");EditingIT.await(attempted);assertEquals(JobState.UNKNOWN_OUTCOME,attempted.state);assertEquals(TransactionState.UNKNOWN_TRANSACTION,incompatible.state);assertEquals("SQLSTATE_08006",attempted.info().getErrorCode());f.sessions.close(incompatible.id,true);
            var original=saved.getRows(0);var ambiguous=original.getRow().getValues(2).toBuilder().setArray(original.getRow().getValues(2).getArray().toBuilder().clearNativeBinary().setNativeLiteral("{\"03/02/2024\",NULL}")).build();
            var historic=saved.toBuilder().setRows(0,original.toBuilder().setRow(original.getRow().toBuilder().setValues(2,ambiguous))).build();String historicalId=f.metadata.saveEditDraft("",historic);
            var rebind=EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setSessionId(session.id).setDocumentId("array-context-recovery").setDraftId(historicalId).build();assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(WorkbenchFailure.class,()->recovery.run(f.sessions,rebind)).reason());assertEquals("STAGED",f.metadata.editDraft(historicalId).state());assertEquals(historic.getRowsList(),f.metadata.editDraft(historicalId).data().getRowsList());
            var valid=recovery.run(f.sessions,rebind.toBuilder().setDraftId(id).build());assertTrue(f.results.get(valid.getResult().getResult().getResultId()).metadataProof().available());assertEquals(saved.getRows(0).getRow(),f.results.get(valid.getResult().getResult().getResultId()).read(0));
            EditingIT.assertRows(session,"SELECT id,n FROM array_context_rows",new int[][]{{1,2}});
        }
    }
}
