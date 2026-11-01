package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import java.lang.reflect.Proxy;
import java.nio.file.Path;
import java.sql.*;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** A blocked JDBC cancel must never own the monitor used by status/control RPCs. */
class CancellationControlIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void explicitCancellationStopsRealSleepBeforeItsDeadline(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            assertPromptCancellation(f.sessions,f.jobs,f.safety,f.results,
                OpenRequest.newBuilder().setProfile(f.profile).setPassword("fixture").build());
        }
    }

    @org.junit.jupiter.api.Test
    void postgresqlCancellationBetweenPublicationAndExecuteStillStopsTheServer()throws Exception {
        var entered=new CountDownLatch(1);var firstControlFinished=new CountDownLatch(1);
        var attempts=new AtomicInteger();var wireAttempts=new AtomicInteger();var submissions=new AtomicInteger();
        try(var f=new EngineFixture(root,"POSTGRESQL",(adapter,request,port)->{
            var connection=NativePostgresFaults.wrap(adapter.connect(request,port),new NativePostgresFaults.Observer(){
                @Override public void beforeExecution(String sql)throws Exception {
                    if(!sql.equals("SELECT pg_sleep(30)"))return;
                    submissions.incrementAndGet();entered.countDown();
                    if(!firstControlFinished.await(5,TimeUnit.SECONDS))throw new AssertionError("Cancellation fixture gate timed out");
                }
                @Override public boolean statementCancellation(){
                    attempts.incrementAndGet();firstControlFinished.countDown();return true;
                }
            });
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(method.getName().equals("unwrap")&&args[0]==org.postgresql.PGConnection.class) {
                    var nativeConnection=connection.unwrap(org.postgresql.PGConnection.class);
                    return Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{org.postgresql.PGConnection.class},(pg,call,parameters)->{
                        if(call.getName().equals("cancelQuery"))wireAttempts.incrementAndGet();
                        return TransactionFaultIT.Faults.invoke(nativeConnection,call,parameters);
                    });
                }
                return TransactionFaultIT.Faults.invoke(connection,method,args);
            });
        })) {
            var session=f.open();
            var job=f.submit(session,"SELECT pg_sleep(30)");
            try {
                assertTrue(entered.await(5,TimeUnit.SECONDS),"Real executor must reach the post-publication gap");
                f.jobs.cancel(job.id);
                assertEquals(JobState.CANCELLED,job.finished.get(8,TimeUnit.SECONDS).getState());
                assertTrue(attempts.get()>=1,"Statement cancellation deliberately cannot reach the server");
                assertTrue(wireAttempts.get()>=1,"Cancellation must reach the same owned PostgreSQL connection");
                assertEquals(1,submissions.get(),"Cancellation must never replay SQL");
                assertEquals(TransactionState.IDLE,session.state);
                var healthy=f.execute(session,"SELECT 29");
                assertEquals("29",f.results.get(healthy.info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
            }finally{firstControlFinished.countDown();}
        }
    }

    static void assertPromptCancellation(io.busystack.busydata.sessions.SessionRegistry sessions,
            io.busystack.busydata.jobs.Jobs jobs,io.busystack.busydata.safety.Safety safety,
            io.busystack.busydata.results.ResultStore results,OpenRequest request)throws Exception {
        var session=sessions.open(request);
        String sql=session.profile.getEngine()==Engine.POSTGRESQL?"SELECT pg_sleep(30)":"SELECT SLEEP(30)";
        // Exercise the real executor as soon as its statement is available.
        // A released proxy task cannot establish that the server was stopped.
        for(int attempt=0;attempt<3;attempt++) {
            var execution=ExecuteRequest.newBuilder().setSessionId(session.id)
                .setExecutionId(UUID.randomUUID().toString()).setSql(sql).setRowLimit(10).build();
            var job=jobs.execute(session,execution.toBuilder().setApprovalToken(safety.review(execution,session).getToken()).build());
            long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);
            while(job.statement==null&&!job.finished.isDone()&&System.nanoTime()<deadline)Thread.sleep(1);
            assertNotNull(job.statement,"The real SQL statement must become cancellable");
            jobs.cancel(job.id);
            assertEquals(JobState.CANCELLED,job.finished.get(8,TimeUnit.SECONDS).getState(),
                "Cancel must interrupt the server statement, not await SLEEP's natural completion");
            assertEquals(TransactionState.IDLE,session.state);
            var healthy=EditingIT.execute(jobs,safety,session,"SELECT 29");
            assertEquals("29",results.get(healthy.info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
        }
        sessions.close(session.id,false);
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void blockedDriverCancellationKeepsStatusAndQueuedCancellationResponsive(String engine)throws Exception {
        var controlEntered=new CountDownLatch(1);var releaseControl=new CountDownLatch(1);
        var taskEntered=new CountDownLatch(1);var releaseTask=new CountDownLatch(1);
        var armed=new AtomicBoolean();var connections=new AtomicInteger();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
            var connection=adapter.connect(request,port);int ordinal=connections.incrementAndGet();
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object value=TransactionFaultIT.Faults.invoke(connection,method,args);
                if(value instanceof Statement statement)return Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{value instanceof PreparedStatement?PreparedStatement.class:Statement.class},(st,call,parameters)->{
                    // MariaDB's bounded control-view initialization also uses
                    // PreparedStatement.executeQuery() with no argument array.
                    boolean mysqlControl=!engine.equals("POSTGRESQL")&&ordinal==2&&call.getName().equals("executeQuery")&&parameters!=null&&parameters.length==1&&parameters[0] instanceof String query&&query.startsWith("SELECT COMMAND FROM");
                    if(armed.get()&&(call.getName().equals("cancel")||mysqlControl)) {
                        controlEntered.countDown();
                        if(!releaseControl.await(5,TimeUnit.SECONDS))throw new SQLException("Injected control deadline","08006");
                    }
                    return TransactionFaultIT.Faults.invoke(statement,call,parameters);
                });
                return value;
            });
        });var callers=Executors.newVirtualThreadPerTaskExecutor()) {
            var session=f.open();armed.set(true);
            var running=f.jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->{
                try(var statement=session.connection.createStatement()) {
                    job.statement=statement;taskEntered.countDown();
                    if(!releaseTask.await(5,TimeUnit.SECONDS))throw new AssertionError("Task gate timed out");
                    job.checkCancel();
                }finally {job.statement=null;}
            });
            try {
                assertTrue(taskEntered.await(5,TimeUnit.SECONDS));
                var cancellation=callers.submit(()->f.jobs.cancel(running.id));
                assertTrue(controlEntered.await(5,TimeUnit.SECONDS),()->"The controlled native cancellation query was not reached: "+running.info());
                var status=callers.submit(running::info);
                assertEquals(JobState.CANCELLING,status.get(1,TimeUnit.SECONDS).getState(),"Driver I/O must not block job status");
                assertEquals(JobState.CANCELLING,cancellation.get(1,TimeUnit.SECONDS).getState(),"Cancel submission must return while driver control is blocked");
                var catalog=callers.submit(()->f.jobs.page(JobRequest.newBuilder().setLimit(32).build()));
                assertEquals(running.id,catalog.get(1,TimeUnit.SECONDS).getJobs(0).getJobId());
                var invoked=new AtomicBoolean();
                var queued=f.jobs.submit(session,UUID.randomUUID().toString(),"SELECT 99",job->invoked.set(true));
                f.jobs.cancel(queued.id);
                assertEquals(JobState.CANCELLED,queued.finished.get(1,TimeUnit.SECONDS).getState());assertFalse(invoked.get());
                releaseTask.countDown();releaseControl.countDown();
                assertEquals(JobState.CANCELLED,running.finished.get(10,TimeUnit.SECONDS).getState());
                assertEquals(JobState.CANCELLED,f.jobs.cancel(running.id).getState());
                armed.set(false);
                var healthy=f.execute(session,"SELECT 29");
                assertEquals("29",f.results.get(healthy.info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
            }finally {armed.set(false);releaseTask.countDown();releaseControl.countDown();}
        }finally {releaseTask.countDown();releaseControl.countDown();}
    }
}
