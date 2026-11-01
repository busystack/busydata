package io.busystack.busydata.transfers;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.storage.MetadataStore;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class NativeDiagnosticsTest {
    @TempDir Path root;
    private static NativeToolFailure failure(String stderr)throws Exception {
        var diagnostics=new NativeDiagnostics();diagnostics.drain(new ByteArrayInputStream(stderr.getBytes(StandardCharsets.UTF_8)));return diagnostics.failure(1);
    }
    @Test void structuredDeadlockRetainsOnlyControlledCodeAndState()throws Exception {
        var failure=failure("ERROR 1213 (40001) at line 42: private SQL, password and row values\n");
        assertEquals("NATIVE_DATABASE_DEADLOCK",failure.errorCode());assertEquals(NativeToolFailure.Category.DEADLOCK,failure.category());
        assertEquals(1,failure.exitCode());assertEquals(1213,failure.databaseCode().orElseThrow());assertEquals("40001",failure.sqlState().orElseThrow());
        assertEquals("Native tool exited 1: database deadlock (database code 1213, SQLSTATE 40001). Source values and server messages omitted.",failure.getMessage());
        assertNull(failure.getCause());assertEquals(0,failure.getSuppressed().length);
    }
    @Test void embeddedOrConflictingUntrustedTextCannotInventStructuredDeadlock()throws Exception {
        for(String text:List.of("private row says ERROR 1213 (40001): secret", "ERROR 1213 (HY000): secret", "ERROR 1213 (40001x): secret", "ERROR 1213 (40001)\nsecret", "ERROR 1213 (40001): secret\nERROR 1045 (28000): other")){
            var failure=failure(text);assertEquals("NATIVE_TOOL_FAILED",failure.errorCode());assertFalse(failure.getMessage().contains("secret"));
        }
    }
    @Test void ordinaryClientExitIsNotReportedAsFilesystemFailure()throws Exception {
        var failure=failure("mariadb: unknown option '--private-option'\n");
        assertEquals("NATIVE_TOOL_FAILED",failure.errorCode());assertEquals(NativeToolFailure.Category.UNSUPPORTED_OPTION,failure.category());assertTrue(failure.databaseCode().isEmpty());assertTrue(failure.sqlState().isEmpty());assertFalse(failure.getMessage().contains("private-option"));
    }
    @Test void stderrKeepsItsBoundButDrainsTheCompleteProcessStream()throws Exception {
        byte[] bytes=("x".repeat(16384)+"\nERROR 1213 (40001): secret\n").getBytes(StandardCharsets.UTF_8);var input=new ByteArrayInputStream(bytes);var diagnostics=new NativeDiagnostics();diagnostics.drain(input);
        assertEquals(-1,input.read());var failure=diagnostics.failure(1);assertEquals("NATIVE_TOOL_FAILED",failure.errorCode());assertTrue(failure.databaseCode().isEmpty());assertFalse(failure.getMessage().contains("secret"));
    }
    @Test void jobClassificationRetainsTypedFailureWithoutReplayOrDiscardingData()throws Exception {
        try(var metadata=new MetadataStore(root);var results=new ResultStore(root,1024)){
            var analysis=new SqlAnalysis();try(var jobs=new Jobs(results,metadata,analysis,new Safety(analysis))){
                var retained=results.create(List.of(Column.newBuilder().setName("retained").build()));
                var row=Row.newBuilder().addValues(Value.newBuilder().setText("retained exact 漢😀")).build();retained.append(row);retained.fetchFinished=true;
                var draft=StoredEditDraft.newBuilder().setDocumentId("native-failure-owner").setSourceSql("unsubmitted private SQL")
                    .setChanges(ChangeRequest.newBuilder().setResultId(retained.id).addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE)
                        .putValues(0,ValueAssignment.newBuilder().setValue(Value.newBuilder().setText("pending exact value")).build()))).build();
                String draftId=metadata.saveEditDraft("",draft);
                // Sessionless exporters can acknowledge finalized output, but
                // cannot pretend to own a native database mutation. Actual
                // restore UNKNOWN outcomes are covered by NativeRestoreMetadataIT.
                for(boolean acknowledged:List.of(false,true)){
                    String execution=UUID.randomUUID().toString();var calls=new AtomicInteger();
                    var job=jobs.submitRetainedExport(retained,execution,operation->{calls.incrementAndGet();assertNull(operation.session);if(acknowledged)operation.commitAcknowledged();throw failure("ERROR 1213 (40001): private source value\n");});
                    var outcome=job.finished.get(5,TimeUnit.SECONDS);
                    assertEquals(acknowledged?JobState.COMPLETED:JobState.FAILED,outcome.getState());assertEquals("NATIVE_DATABASE_DEADLOCK",outcome.getErrorCode());assertEquals(1,calls.get());
                    assertTrue(outcome.getMessagesList().stream().noneMatch(message->message.contains("private source")||message.contains("unsubmitted private SQL")||message.contains("pending exact value")));
                    assertSame(retained,results.get(retained.id));assertEquals(row,retained.read(0));
                    var recovered=metadata.editDraft(draftId);assertEquals("STAGED",recovered.state());assertEquals(draft,recovered.data());
                    assertThrows(IllegalArgumentException.class,()->jobs.submitRetainedExport(retained,execution,ignored->calls.incrementAndGet()),"A duplicate execution cannot replay the failed task");assertEquals(1,calls.get());
                }
            }
        }
    }
}
