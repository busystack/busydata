package io.busystack.busydata;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.storage.MetadataStore;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class WorkbenchJobFailureTest {
    @TempDir Path root;

    @Test void typedFailuresKeepTheirAllowlistedCodeWithoutReplayingOrDiscardingDrafts()throws Exception {
        try(var metadata=new MetadataStore(root);var results=new ResultStore(root,1024)){
            var analysis=new SqlAnalysis();try(var jobs=new Jobs(results,metadata,analysis,new Safety(analysis))){
                var retained=results.create(List.of(Column.newBuilder().setName("value").build()));
                var row=Row.newBuilder().addValues(Value.newBuilder().setText("exact retained 漢😀")).build();retained.append(row);retained.fetchFinished=true;
                var draft=StoredEditDraft.newBuilder().setDocumentId("original-owner").setSourceSql("unsubmitted private SQL")
                    .setChanges(ChangeRequest.newBuilder().setResultId(retained.id).addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE)
                        .putValues(0,ValueAssignment.newBuilder().setValue(Value.newBuilder().setText("pending exact value")).build()))).build();
                String draftId=metadata.saveEditDraft("",draft);
                for(var reason:WorkbenchFailure.Reason.values()){
                    var calls=new AtomicInteger();String execution=UUID.randomUUID().toString();
                    var job=jobs.submitRetainedExport(retained,execution,operation->{
                        calls.incrementAndGet();assertNull(operation.session,"This pure job owns no live SQL connection");throw new WorkbenchFailure(reason);
                    });
                    var outcome=job.finished.get(5,TimeUnit.SECONDS);
                    assertEquals(JobState.FAILED,outcome.getState());assertEquals(reason.wire(),outcome.getErrorCode());assertEquals(1,calls.get());
                    assertTrue(outcome.getResultsList().isEmpty());assertSame(retained,results.get(retained.id));assertEquals(row,retained.read(0));
                    var recovered=metadata.editDraft(draftId);assertEquals("STAGED",recovered.state());assertEquals(draft,recovered.data());
                    assertTrue(outcome.getMessagesList().stream().noneMatch(message->message.contains("unsubmitted private SQL")||message.contains("pending exact value")));
                    assertThrows(IllegalArgumentException.class,()->jobs.submitRetainedExport(retained,execution,ignored->calls.incrementAndGet()),"An explicit duplicate execution cannot replay the failed task");
                    assertEquals(1,calls.get());
                }
                assertEquals(WorkbenchFailure.Reason.values().length,jobs.list("").size());
            }
        }
    }

    @Test void humanReadableTextCannotInventATypedWorkbenchReason()throws Exception {
        try(var metadata=new MetadataStore(root);var results=new ResultStore(root,1024)){
            var analysis=new SqlAnalysis();try(var jobs=new Jobs(results,metadata,analysis,new Safety(analysis))){
                var retained=results.create(List.of(Column.newBuilder().setName("value").build()));retained.fetchFinished=true;
                var calls=new AtomicInteger();var job=jobs.submitRetainedExport(retained,UUID.randomUUID().toString(),operation->{
                    calls.incrementAndGet();throw new IllegalStateException("Workbench request failed: stale; private SQL and credentials");
                });
                var outcome=job.finished.get(5,TimeUnit.SECONDS);
                assertEquals(JobState.FAILED,outcome.getState());assertEquals("OPERATION_FAILED",outcome.getErrorCode());assertEquals(1,calls.get());
                assertTrue(outcome.getMessagesList().stream().noneMatch(message->message.contains("private SQL")||message.contains("credentials")));
            }
        }
    }
}
