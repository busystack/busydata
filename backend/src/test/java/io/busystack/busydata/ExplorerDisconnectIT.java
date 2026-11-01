package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.nio.file.Path;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class ExplorerDisconnectIT {
    @TempDir Path root;
    @Test void blockedTreeReadDoesNotOwnDisconnectLockOrSurviveItsSource()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")) {
            var source=fixture.open();var locker=fixture.open();
            var observer=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile).setPassword("fixture").setCatalog("postgres").build());
            var ordinary=new Explorer(fixture.metadata).explore(source,ExploreRequest.newBuilder().setKind(ObjectKind.TABLE)
                .setCatalog("busydata").setSchema("public").setIndependentMetadata(true).build());
            assertTrue(ordinary.getComplete());assertEquals("available",ordinary.getAvailability());
            int sourcePid;
            try(var statement=source.connection.createStatement();var rows=statement.executeQuery("SELECT pg_backend_pid()")){assertTrue(rows.next());sourcePid=rows.getInt(1);}
            int lockerPid;
            try(var statement=locker.connection.createStatement();var rows=statement.executeQuery("SELECT pg_backend_pid()")){assertTrue(rows.next());lockerPid=rows.getInt(1);}
            locker.connection.setAutoCommit(false);
            try(var statement=locker.connection.createStatement()){statement.execute("LOCK TABLE pg_catalog.pg_class IN ACCESS EXCLUSIVE MODE");}
            var context=io.grpc.Context.current().withCancellation();
            try(var executor=Executors.newSingleThreadExecutor()) {
                var worker=new java.util.concurrent.atomic.AtomicReference<Thread>();
                var pending=executor.submit(()->{worker.set(Thread.currentThread());return context.call(()->new Explorer(fixture.metadata).explore(source,ExploreRequest.newBuilder()
                    .setRefresh(true).setSessionId(source.id).setKind(ObjectKind.TABLE).setCatalog("busydata").setSchema("public").setIndependentMetadata(true).build()));});
                try {
                    long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);boolean blocked=false;
                    while(!blocked&&System.nanoTime()<deadline) {
                        if(pending.isDone())pending.get();
                        try(var statement=observer.connection.createStatement();var rows=statement.executeQuery("SELECT count(*) FROM pg_locks WHERE NOT granted AND "+lockerPid+"=ANY(pg_blocking_pids(pid))")){assertTrue(rows.next());blocked=rows.getInt(1)>0;}
                        if(!blocked)Thread.sleep(25);
                    }
                    if(!blocked) {
                        try(var statement=observer.connection.createStatement();var rows=statement.executeQuery("SELECT datname,state,wait_event_type,wait_event FROM pg_stat_activity")) {
                            while(rows.next())System.err.println("Metadata fixture activity: "+rows.getString(1)+" / "+rows.getString(2)+" / "+rows.getString(3)+" / "+rows.getString(4));
                        }
                        for(var frame:worker.get().getStackTrace())System.err.println("Metadata fixture worker: "+frame);
                        pending.get(1,TimeUnit.SECONDS);
                    }
                    assertTrue(blocked,"Fixture must observe the real delayed catalog read");
                    boolean acquired=source.lock.tryLock();
                    try{assertTrue(acquired,"Tree metadata must not hold the physical source's disconnect lock");}
                    finally{if(acquired)source.lock.unlock();}
                    assertEquals(TransactionState.DISCONNECTED,fixture.sessions.command(SessionRequest.newBuilder().setSessionId(source.id).setAction(SessionAction.DISCONNECT).build()).getTransaction());
                    try(var statement=observer.connection.createStatement();var rows=statement.executeQuery("SELECT count(*) FROM pg_stat_activity WHERE pid="+sourcePid)){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}
                } finally {
                    context.cancel(null);locker.connection.rollback();
                }
                assertThrows(ExecutionException.class,()->pending.get(5,TimeUnit.SECONDS),"Canceled/disconnected source cannot return usable metadata");
            }
            try(var statement=observer.connection.createStatement();var rows=statement.executeQuery("SELECT count(*) FROM pg_stat_activity WHERE datname='busydata'")){assertTrue(rows.next());assertEquals(1,rows.getInt(1),"Only the fixture locker may remain; ephemeral metadata must close");}
        }
    }
}
