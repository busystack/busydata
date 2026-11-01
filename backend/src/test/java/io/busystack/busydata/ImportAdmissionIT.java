package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchService;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import io.grpc.stub.StreamObserver;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.function.Consumer;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class ImportAdmissionIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void reviewedSourceIsServerBoundWithoutPreviewAndCancelledAdmissionStartsNoJob(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();f.execute(session,"CREATE TABLE admitted_import(id INTEGER PRIMARY KEY,v VARCHAR(40))");
            var service=new WorkbenchService(f.sessions,f.jobs,f.results,f.metadata,f.safety,f.analysis,()->{});
            var context=io.busystack.busydata.protocol.Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId(UUID.randomUUID().toString()).build();
            for(boolean json:List.of(false,true)) {
                Path source=root.resolve(json?"reviewed.json":"reviewed.csv");
                String bytes=json?"[{\"id\":1,\"v\":\"reviewed\"}]":"id,v\n1,reviewed\n";
                Files.writeString(source,bytes);
                var request=ToolRequest.newBuilder().setContext(context).setSessionId(session.id).setExecutionId(UUID.randomUUID().toString())
                    .setKind(json?ToolKind.IMPORT_JSON:ToolKind.IMPORT_CSV).setFormat(json?"json":"csv").setPath(source.toString())
                    .setSchema(f.schema()).setTable("admitted_import").addAllColumns(List.of("id","v")).build();
                Approval changed=rpc(out->service.reviewTool(request,out));int jobs=f.jobs.list(session.id).size();
                Files.writeString(source,json?"[{\"id\":2,\"v\":\"changed\"}]":"id,v\n2,changed\n");
                var changedRequest=request.toBuilder().setApprovalToken(changed.getToken()).build();
                assertThrows(StatusRuntimeException.class,()->ImportAdmissionIT.<JobInfo>rpc(out->service.tool(changedRequest,out)));
                assertEquals(jobs,f.jobs.list(session.id).size());assertEmpty(session);
                Files.writeString(source,bytes);
                assertThrows(StatusRuntimeException.class,()->ImportAdmissionIT.<JobInfo>rpc(out->service.tool(changedRequest,out)),"A failed admission must require another review");
                Approval cancelled=rpc(out->service.reviewTool(request,out));
                try(var cancellation=io.grpc.Context.current().withCancellation()) {
                    cancellation.cancel(null);
                    var failure=cancellation.call(()->assertThrows(StatusRuntimeException.class,()->ImportAdmissionIT.<JobInfo>rpc(out->service.tool(request.toBuilder().setApprovalToken(cancelled.getToken()).build(),out))));
                    assertEquals(Status.Code.CANCELLED,failure.getStatus().getCode());
                }
                assertEquals(jobs,f.jobs.list(session.id).size());assertEmpty(session);
                Approval mapping=rpc(out->service.reviewTool(request,out));
                var forged=request.toBuilder().setApprovalToken(mapping.getToken()).putColumnMapping("v","other").build();
                assertThrows(StatusRuntimeException.class,()->ImportAdmissionIT.<JobInfo>rpc(out->service.tool(forged,out)));
                assertEquals(jobs,f.jobs.list(session.id).size());assertEmpty(session);
                Approval accepted=rpc(out->service.reviewTool(request,out));
                JobInfo job=rpc(out->service.tool(request.toBuilder().setApprovalToken(accepted.getToken()).build(),out));
                EditingIT.await(f.jobs.get(job.getJobId()));assertEquals(JobState.COMPLETED,f.jobs.get(job.getJobId()).state);
                try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT id,v FROM admitted_import")) {
                    assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertEquals("reviewed",rows.getString(2));assertFalse(rows.next());
                }
                assertThrows(StatusRuntimeException.class,()->ImportAdmissionIT.<JobInfo>rpc(out->service.tool(request.toBuilder().setApprovalToken(accepted.getToken()).build(),out)));
                f.execute(session,"DELETE FROM admitted_import");
            }
        }
    }
    private static void assertEmpty(io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception {
        try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT COUNT(*) FROM admitted_import")){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}
    }
    private static <T> T rpc(Consumer<StreamObserver<T>> invoke)throws Exception {
        var result=new CompletableFuture<T>();
        invoke.accept(new StreamObserver<>(){public void onNext(T value){result.complete(value);}public void onError(Throwable error){result.completeExceptionally(error);}public void onCompleted(){}});
        try{return result.get(10,TimeUnit.SECONDS);}catch(ExecutionException error){if(error.getCause() instanceof Exception cause)throw cause;throw error;}
    }
}
