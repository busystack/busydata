package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Owning PostgreSQL TEMP edits retain their existing system-visibility policy. */
class InspectionTemporaryPolicyIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void ownedPostgresTemporaryReviewAndRecoveryRemainAvailableWithoutSystemObjects(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var other=fixture.open();var platform=fixture.metadata.metadataPlatform();var explorer=new Explorer(platform);
            assertFalse(platform.configuration(owner).systemObjects());
            fixture.execute(owner,"CREATE TEMPORARY TABLE inspection_temp_rows(id INTEGER PRIMARY KEY,n INTEGER NOT NULL DEFAULT 7); INSERT INTO inspection_temp_rows VALUES(1,7)");
            owner.lock.lock();try{explorer.refreshSessionOverlay(owner);}finally{owner.lock.unlock();}
            String schema=fixture.engine==Engine.POSTGRESQL?owner.context.temporarySchema():fixture.schema();assertFalse(schema.isEmpty());
            String table=owner.adapter.table("busydata",schema,"inspection_temp_rows");var result=fixture.results.get(fixture.execute(owner,"SELECT id,n FROM "+table).info().getResults(0).getResultId());
            var planner=new ChangePlanner(fixture.safety,fixture.results,platform);var changes=ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(result.id).setCatalog("busydata").setSchema(schema).setTable(result.columns.getFirst().getTable())
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.defaultValue())).build();
            if(fixture.engine!=Engine.POSTGRESQL){
                assertFalse(result.metadataProof().available(),"MySQL/MariaDB TEMP incarnation still cannot authorize a retained edit");
                var assessment=planner.assess(owner,changes.toBuilder().clearChanges().build());assertFalse(assessment.getEditable());
            }else{
                assertTrue(result.metadataProof().available(),result.metadataProof().toString());assertEquals(schema,result.metadataProof().schema());
                var plan=planner.preview(owner,changes);assertTrue(plan.getSql(0).contains("DEFAULT"));
                var drafts=new EditDrafts(fixture.metadata,fixture.results,planner);var saved=drafts.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(owner.id).setDocumentId("temporary-intent").setChanges(changes).build());
                String id=saved.getDrafts(0).getDraftId();var original=fixture.metadata.editDraft(id).data();
                var rebound=drafts.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setSessionId(owner.id).setDraftId(id).setDocumentId("temporary-rebound").build());
                assertTrue(rebound.getChanges().getChanges(0).getValuesOrThrow(2).hasDefaultValue());assertEquals(original.getChanges().getChangesList(),rebound.getChanges().getChangesList());
                assertTrue(planner.preview(owner,rebound.getChanges()).getSql(0).contains("DEFAULT"));
                assertTrue(platform.publishedSnapshot(owner).identity(result.metadataProof().tableIdentity()).isEmpty(),"Only the owning overlay may contain this TEMP relation");
                assertTrue(platform.capture(other).identity(result.metadataProof().tableIdentity()).isEmpty());
                other.lock.lock();try{
                    var rejected=assertThrows(WorkbenchFailure.class,()->{try(var inspection=platform.inspectTable(other,"busydata",schema,"inspection_temp_rows",result.columns)){} });assertEquals(WorkbenchFailure.Reason.INVALID_OWNER,rejected.reason());
                }finally{other.lock.unlock();}
            }
            EditingIT.assertRows(owner,"SELECT id,n FROM "+table,new int[][]{{1,7}});
        }
    }
}
