package io.busystack.busydata;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.schema.*;
import java.io.IOException;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real recovery and engine metadata; the competing lease is PREPARED only.
 * No native-client execution or acceptance is claimed by this fence fixture. */
class EditRecoveryExternalFenceIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void nativePreparationCrossingRebindCannotPublishOldProofOrOverwriteDraft(String engine)throws Exception {
        var block=new AtomicBoolean();var allocating=new CountDownLatch(1);var releaseAllocation=new CountDownLatch(1);var prepared=new CountDownLatch(1);var releasePreparation=new CountDownLatch(1);
        try(var fixture=new EngineFixture(root.resolve("engine"),engine)){
            var owner=fixture.open();var other=fixture.open();
            fixture.execute(owner,"CREATE TABLE recovery_fence(id INTEGER PRIMARY KEY,n INTEGER NOT NULL)");fixture.execute(owner,"INSERT INTO recovery_fence VALUES(1,2),(2,3)");fixture.warm(owner,"recovery_fence");
            try(var results=new ResultStore(root.resolve("retained"),16L*1024*1024,Files::deleteIfExists,path->{
                if(block.compareAndSet(true,false)){allocating.countDown();try{if(!releaseAllocation.await(10,TimeUnit.SECONDS))throw new IOException("Missing owned recovery allocation release");}catch(InterruptedException error){Thread.currentThread().interrupt();throw new IOException(error);}}Files.createFile(path);
            })){var analysis=new SqlAnalysis();var safety=new Safety(analysis);
                try(var jobs=new Jobs(results,fixture.metadata,analysis,safety);var worker=Executors.newSingleThreadExecutor()){
                    String table=owner.adapter.table(owner.context.catalog(),fixture.schema(),"recovery_fence");
                    var query=EditingIT.execute(jobs,safety,owner,"SELECT id,n FROM "+table+" ORDER BY id");String result=query.info().getResults(0).getResultId();
                    var planner=new ChangePlanner(safety,results,fixture.metadata.metadataPlatform());var recovery=new EditDrafts(fixture.metadata,results,planner);
                    var changes=ChangeRequest.newBuilder().setSessionId(owner.id).setSchema(fixture.schema()).setTable("recovery_fence").setResultId(result).addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(1,Assignments.value(Value.newBuilder().setSignedInteger("99").build()))).build();
                    var saved=recovery.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(owner.id).setDocumentId("original").setChanges(changes).build());String id=saved.getDrafts(0).getDraftId();var original=fixture.metadata.editDraft(id).data();
                    var request=EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setDraftId(id).setSessionId(owner.id).setDocumentId("rebound").build();
                    block.set(true);var rebinding=worker.submit(()->recovery.run(fixture.sessions,request));
                    Jobs.Job preparation=null;
                    try{
                        assertTrue(allocating.await(10,TimeUnit.SECONDS),"Rebind must finish physical/schema verification before allocating its private result");
                        preparation=jobs.submit(other,UUID.randomUUID().toString(),"",operation->{operation.beforeExternalMutation();prepared.countDown();if(!releasePreparation.await(10,TimeUnit.SECONDS))throw new IOException("Missing owned prepared-source release");throw new IOException("Owned fixture refused before child launch");});
                        assertTrue(prepared.await(10,TimeUnit.SECONDS),"Source preparation cannot wait on another result's file allocation lock");assertTrue(fixture.metadata.metadataPlatform().externalMutationActive(owner));assertNull(preparation.process);
                        releaseAllocation.countDown();var failure=assertThrows(ExecutionException.class,()->rebinding.get(10,TimeUnit.SECONDS));assertInstanceOf(WorkbenchFailure.class,failure.getCause());assertEquals(WorkbenchFailure.Reason.STALE,((WorkbenchFailure)failure.getCause()).reason());
                        assertEquals(original,fixture.metadata.editDraft(id).data());assertEquals("STAGED",fixture.metadata.editDraft(id).state());assertEquals(2,jobs.list("").size(),"Rebind never creates an execution job or replays the original query");
                    }finally{releaseAllocation.countDown();releasePreparation.countDown();if(preparation!=null){var outcome=preparation.finished.get(10,TimeUnit.SECONDS);assertEquals(JobState.FAILED,outcome.getState());assertFalse(fixture.metadata.metadataPlatform().externalMutationActive(owner));}}
                    fixture.warm(owner,"recovery_fence");var rebound=recovery.run(fixture.sessions,request);var recovered=results.get(rebound.getChanges().getResultId());
                    assertTrue(recovered.metadataProof().available());assertEquals(original.getRowsCount(),recovered.rows());
                    for(var row:original.getRowsList())assertEquals(row.getRow(),recovered.read(row.getSourceRow()));
                    assertEquals(original.getChanges().getChangesList(),rebound.getChanges().getChangesList());assertEquals(2,jobs.list("").size());
                    try(var statement=owner.connection.createStatement();var rows=statement.executeQuery("SELECT n FROM "+table+" ORDER BY id")){assertTrue(rows.next());assertEquals(2,rows.getInt(1));assertTrue(rows.next());assertEquals(3,rows.getInt(1));assertFalse(rows.next());}
                }
            }
        }finally{releaseAllocation.countDown();releasePreparation.countDown();}
    }
}
