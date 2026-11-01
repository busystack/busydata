package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchService;
import io.grpc.stub.StreamObserver;
import java.lang.reflect.Proxy;
import java.nio.file.Path;
import java.sql.*;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.function.Consumer;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Execution-backed plans use the ordinary RPC/job/transaction outcome policy. */
class PlanCancellationIT {
    @TempDir Path root;
    @Test void cancellationBeforeStatementPublicationCannotExecuteTheReviewedMutation()throws Exception {
        exercise(false);
    }
    @Test void acknowledgedPlanMutationIsNotRelabelledCancelledWhileFetchingIsBlocked()throws Exception {
        exercise(true);
    }
    private void exercise(boolean fetching)throws Exception {
        var target=new AtomicReference<Connection>();var armed=new AtomicBoolean();
        var reached=new CountDownLatch(1);var release=new CountDownLatch(1);
        try(var f=new EngineFixture(root,"POSTGRESQL",(adapter,request,port)->{
            var owner=new AtomicReference<Connection>();
            var delegate=NativePostgresFaults.wrap(adapter.connect(request,port),new NativePostgresFaults.Observer(){
                @Override public ResultSet result(String sql,ResultSet rows){
                    if(!armed.get()||!fetching||owner.get()!=target.get()||!sql.startsWith("EXPLAIN ")||!sql.contains("INSERT INTO plan_mutation"))return rows;
                    return (ResultSet)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{ResultSet.class},(rs,read,arguments)->{
                        if(read.getName().equals("next")){reached.countDown();if(!release.await(10,TimeUnit.SECONDS))throw new SQLException("Result delivery gate expired","08006");}
                        return TransactionFaultIT.Faults.invoke(rows,read,arguments);
                    });
                }
            });
            var connection=(Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object value=TransactionFaultIT.Faults.invoke(delegate,method,args);
                if(armed.get()&&proxy==target.get()&&!fetching&&method.getName().equals("createStatement")&&args!=null&&args.length==2) {
                    reached.countDown();if(!release.await(10,TimeUnit.SECONDS))throw new SQLException("Statement publication gate expired","08006");
                }
                return value;
            });
            owner.set(connection);return connection;
        })) {
            var session=f.open();f.execute(session,"CREATE TABLE plan_mutation(id INTEGER PRIMARY KEY,n INTEGER)");
            var service=new WorkbenchService(f.sessions,f.jobs,f.results,f.metadata,f.safety,f.analysis,()->{});
            var context=io.busystack.busydata.protocol.Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId(UUID.randomUUID().toString()).build();
            var request=ToolRequest.newBuilder().setContext(context).setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setKind(ToolKind.EXPLAIN_ANALYZE).setSql("INSERT INTO plan_mutation VALUES(1,31)").build();
            Approval approval=rpc(out->service.reviewTool(request,out));
            target.set(session.connection);armed.set(true);
            JobInfo submitted=rpc(out->service.tool(request.toBuilder().setApprovalToken(approval.getToken()).build(),out));
            assertTrue(submitted.hasToolKind());assertEquals(ToolKind.EXPLAIN_ANALYZE,submitted.getToolKind());
            assertEquals(session.targetProfile().getId(),submitted.getTarget().getId());
            assertFalse(submitted.getTarget().hasTls());assertFalse(submitted.getTarget().hasSsh());
            assertTrue(submitted.getTarget().getCredentialRef().isEmpty());
            var job=f.jobs.get(submitted.getJobId());
            assertTrue(reached.await(10,TimeUnit.SECONDS));
            f.jobs.cancel(job.id);release.countDown();job.finished.get(10,TimeUnit.SECONDS);
            armed.set(false);
            var observer=f.open();
            try(var statement=observer.connection.createStatement();var rows=statement.executeQuery("SELECT COUNT(*),COALESCE(SUM(n),0) FROM plan_mutation")) {
                assertTrue(rows.next());assertEquals(fetching?1:0,rows.getInt(1));assertEquals(fetching?31:0,rows.getInt(2));
            }
            assertEquals(fetching?JobState.COMPLETED:JobState.CANCELLED,job.state,job.info().toString());
            if(fetching) {
                assertTrue(job.info().getResults(0).getPlan());
                var retained=f.results.get(job.info().getResults(0).getResultId()).retained();
                assertEquals(f.schema(),retained.getSourceSchema());
                assertTrue(io.busystack.busydata.results.Values.text(retained.getSqlProvenance()).startsWith("EXPLAIN"));
                assertFalse(job.info().getResults(0).getComplete());
                assertTrue(job.info().getMessagesList().stream().anyMatch(message->message.contains("acknowledgement")));
            }
            assertEquals(TransactionState.IDLE,session.state);
            f.execute(session,"SELECT 37");
        }finally {release.countDown();}
    }
    private static <T> T rpc(Consumer<StreamObserver<T>> invoke)throws Exception {
        var result=new CompletableFuture<T>();
        invoke.accept(new StreamObserver<>() {
            public void onNext(T value){result.complete(value);}
            public void onError(Throwable failure){result.completeExceptionally(failure);}
            public void onCompleted(){}
        });
        return result.get(10,TimeUnit.SECONDS);
    }
}
