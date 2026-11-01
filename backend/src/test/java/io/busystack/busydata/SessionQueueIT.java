package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.jobs.Jobs;
import java.nio.file.Path;
import java.util.UUID;
import java.util.concurrent.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class SessionQueueIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void queuedSqlByteAdmissionRecoversAfterCancellationWithoutExecutingRejectedWork(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();session.lock.lock();
            var invoked=new java.util.concurrent.atomic.AtomicBoolean();
            String sql="x".repeat(8_000_000),rejectedId=UUID.randomUUID().toString();
            Jobs.Job first=null,second=null,recovered=null;
            try {
                first=f.jobs.submit(session,UUID.randomUUID().toString(),sql,job->invoked.set(true));
                second=f.jobs.submit(session,UUID.randomUUID().toString(),sql,job->invoked.set(true));
                assertThrows(IllegalStateException.class,()->f.jobs.submit(session,rejectedId,"x".repeat(1_000_000),job->invoked.set(true)));
                f.jobs.cancel(first.id);assertEquals(JobState.CANCELLED,first.finished.get(2,TimeUnit.SECONDS).getState());
                recovered=f.jobs.submit(session,rejectedId,sql,job->invoked.set(true));
                f.jobs.cancel(recovered.id);f.jobs.cancel(second.id);
                assertEquals(JobState.CANCELLED,recovered.finished.get(2,TimeUnit.SECONDS).getState());
                assertEquals(JobState.CANCELLED,second.finished.get(2,TimeUnit.SECONDS).getState());
                assertFalse(invoked.get(),"No queued/admission-rejected task may run");
            }finally {
                for(var job:new Jobs.Job[]{first,second,recovered})if(job!=null&&!Jobs.terminal(job.state))f.jobs.cancel(job.id);
                session.lock.unlock();
            }
            f.execute(session,"SELECT 9");
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void queueDeadlinesAdmissionAndShutdownReleaseUnstartedWork(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();session.lock.lock();
            try(var jobs=new Jobs(f.results,f.metadata,f.analysis,f.safety,java.time.Duration.ofMillis(100))) {
                var timed=jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->fail("Queued SQL must not execute"));
                var info=timed.finished.get(2,TimeUnit.SECONDS);assertEquals(JobState.FAILED,info.getState());assertEquals("QUEUE_WAIT_TIMEOUT",info.getErrorCode());
            }finally{session.lock.unlock();}
            session.lock.lock();
            try(var jobs=new Jobs(f.results,f.metadata,f.analysis,f.safety,java.time.Duration.ofMinutes(1))) {
                var queued=new java.util.ArrayList<Jobs.Job>();for(int i=0;i<32;i++)queued.add(jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->fail("Unstarted work must not execute")));
                assertThrows(IllegalStateException.class,()->jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->{}));
                for(var job:queued){jobs.cancel(job.id);jobs.cancel(job.id);}for(var job:queued)assertEquals(JobState.CANCELLED,job.finished.get(2,TimeUnit.SECONDS).getState());
                var recovered=jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->fail("Shutdown must cancel queued SQL"));
                jobs.close();assertEquals(JobState.CANCELLED,recovered.finished.get(2,TimeUnit.SECONDS).getState());
                assertThrows(IllegalStateException.class,()->jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->{}));
            }finally{session.lock.unlock();}
            f.execute(session,"SELECT 9");
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void cancellingQueuedWorkDoesNotCancelTheCurrentQuery(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var session=fixture.open();var entered=new CountDownLatch(1);
            var running=fixture.jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->{
                try(var statement=session.adapter.rawStatement(session.connection,false,30,1000)){
                    job.statement=statement;entered.countDown();
                    try(var rows=statement.executeQuery(fixture.engine==Engine.POSTGRESQL?"SELECT pg_sleep(2),7":"SELECT SLEEP(2),7")){
                        assertTrue(rows.next());assertEquals(7,rows.getInt(2));
                    }
                }finally{job.statement=null;}
            });
            assertTrue(entered.await(5,TimeUnit.SECONDS));var invoked=new java.util.concurrent.atomic.AtomicBoolean();
            var queued=fixture.jobs.submit(session,UUID.randomUUID().toString(),"SELECT 1",job->invoked.set(true));
            long started=System.nanoTime();fixture.jobs.cancel(queued.id);fixture.jobs.cancel(queued.id);
            try {
                queued.finished.get(1,TimeUnit.SECONDS);
                assertEquals(JobState.CANCELLED,queued.state,"Queued cancellation must complete while A retains the session");
                assertFalse(invoked.get());assertFalse(running.cancel.get());assertFalse(Jobs.terminal(running.state));
                assertTrue(System.nanoTime()-started<TimeUnit.SECONDS.toNanos(1));
                EditingIT.await(running);assertEquals(JobState.COMPLETED,running.state,running.info().toString());
                fixture.execute(session,"SELECT 9");
            }finally {if(!Jobs.terminal(running.state))fixture.jobs.cancel(running.id);}
        }
    }
}
