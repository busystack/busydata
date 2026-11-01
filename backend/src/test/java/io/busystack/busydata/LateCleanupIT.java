package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import java.lang.reflect.Proxy;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Final status inspection can fail after cancellation has chosen an outcome. */
class LateCleanupIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void finalCleanupUncertaintyRemainsVisibleWithoutOverwritingAcknowledgedWrites(String engine)throws Exception {
        var failRefresh=new AtomicReference<Connection>();
        try(var f=new EngineFixture(root,engine,(adapter,request,port)->{
            var actual=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(proxy==failRefresh.get()&&method.getName().equals("getAutoCommit"))throw new SQLException("Injected final context response loss","08006");
                return TransactionFaultIT.Faults.invoke(actual,method,args);
            });
        })) {
            var observer=f.open();f.execute(observer,"CREATE TABLE late_cleanup(id INTEGER PRIMARY KEY,n INTEGER)");
            var outcomes=new ArrayList<JobInfo>();
            for(int scenario=0;scenario<3;scenario++) {
                var session=f.open();boolean write=scenario>0,acknowledged=scenario==2;
                String sql=write?"INSERT INTO late_cleanup VALUES("+scenario+",67)":"SELECT 61";
                var reached=new CountDownLatch(1);var release=new CountDownLatch(1);
                var job=f.jobs.submit(session,UUID.randomUUID().toString(),sql,current->{
                    try(var statement=session.connection.createStatement()) {
                        current.statement=statement;
                        statement.execute(sql);
                        if(acknowledged)current.commitAcknowledged();
                        reached.countDown();
                        if(!release.await(10,TimeUnit.SECONDS))throw new AssertionError("Delivery gate expired");
                        current.checkCancel();
                    }
                });
                try {
                    assertTrue(reached.await(10,TimeUnit.SECONDS));
                    failRefresh.set(session.connection);
                    f.jobs.cancel(job.id);release.countDown();
                    outcomes.add(job.finished.get(15,TimeUnit.SECONDS));
                    assertEquals(TransactionState.UNKNOWN_TRANSACTION,session.state);
                    assertTrue(session.connection.isClosed());
                    assertThrows(IllegalStateException.class,()->f.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.COMMIT).build()));
                    assertEquals(job.state,f.jobs.cancel(job.id).getState());
                    if(write)try(var statement=observer.connection.createStatement();var rows=statement.executeQuery("SELECT COUNT(*),SUM(n) FROM late_cleanup WHERE id="+scenario)) {
                        assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertEquals(67,rows.getInt(2));
                    }
                }finally {release.countDown();failRefresh.set(null);f.sessions.close(session.id,true);}
            }
            assertAll(
                ()->assertEquals(JobState.INTERRUPTED,outcomes.get(0).getState(),"Lost final connection status must remain visible for the cancelled read"),
                ()->assertEquals(JobState.UNKNOWN_OUTCOME,outcomes.get(1).getState(),"Unacknowledged writes must not retain a definite cancellation after quarantine"),
                ()->assertEquals(JobState.COMPLETED,outcomes.get(2).getState(),"A known acknowledgement survives late cleanup/cancellation"),
                ()->assertTrue(outcomes.stream().allMatch(info->info.getMessagesList().stream().anyMatch(message->message.contains("cleanup")||message.contains("context"))),"Every failed final inspection needs a safe actionable diagnostic")
            );
            assertEquals(1,f.sessions.physicalSessionCount());
        }
    }
}
