package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.SchemaTools;
import java.lang.management.ManagementFactory;
import java.nio.file.Path;
import java.util.Arrays;
import java.util.concurrent.*;
import java.util.concurrent.locks.LockSupport;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** A real owned native capture and coverage-only invalidation exercise the
 * unchanged100ms reader budget, independently of SQL parsing or SQL execution. */
class MetadataCaptureTimeoutIT {
    @TempDir Path root;
    @Test void expiredActualCoverageRebaseRetainsItsOriginAndBothPublishedOwners()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);
            fixture.execute(owner,"CREATE TABLE rebase_timeout_owner(id INTEGER PRIMARY KEY,n INTEGER NOT NULL)");
            tools.capture(owner,fixture.schema());
            fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.BEGIN).build());
            owner.lock.lock();
            try{
                var artifact=tools.capture(owner,fixture.schema());assertTrue(artifact.getAsJsonObject("tables").has("rebase_timeout_owner"));
                var overlay=platform.capture(owner);platform.markStale(owner,"Explicit fixture coverage-only invalidation");
                var durable=platform.publishedSnapshot(owner);assertTrue(MetadataCaptureTestAccess.coverageOnlyRebase(overlay,durable),"Fixture must retain real native indexes and require only a coverage rebase");
                var originalOverlay=MetadataCaptureTestAccess.overlayOwner(platform,owner);Object monitor=MetadataCaptureTestAccess.sourceMonitor(platform,owner);
                long revision=owner.revision,contextRevision=owner.contextRevision;var context=owner.context;int holds=owner.lock.getHoldCount();
                var outcome=new FutureTask<>(()->{try{platform.capture(owner);return (Throwable)null;}catch(Throwable failure){return failure;}});
                Thread reader=Thread.ofPlatform().name("actual-owned-rebase-timeout").unstarted(outcome);
                try{
                    synchronized(monitor){
                        reader.start();awaitBlockedCapture(reader,monitor);
                        // The actual capture has already set its100ms deadline
                        // before blocking on this exact source. Keep that owner
                        // stable beyond the deadline rather than replacing time.
                        long releaseAt=System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(125);
                        while(System.nanoTime()<releaseAt)LockSupport.parkNanos(releaseAt-System.nanoTime());
                        assertFalse(outcome.isDone());
                    }
                    var failure=assertInstanceOf(WorkbenchFailure.class,outcome.get(5,TimeUnit.SECONDS));
                    assertEquals(WorkbenchFailure.Reason.TIMED_OUT,failure.reason());assertEquals(WorkbenchFailure.Origin.CAPTURE_REBASE,failure.origin());assertNull(failure.getCause());
                    assertSame(durable,platform.publishedSnapshot(owner));assertSame(originalOverlay,MetadataCaptureTestAccess.overlayOwner(platform,owner),"Expired capture must never replace its real owned overlay");
                    assertEquals(revision,owner.revision);assertEquals(contextRevision,owner.contextRevision);assertEquals(context,owner.context);assertEquals(holds,owner.lock.getHoldCount());
                    assertFalse(owner.autoCommit);assertFalse(owner.connection.getAutoCommit());assertEquals(TransactionState.ACTIVE,owner.state);assertEquals(TransactionState.ACTIVE,owner.adapter.transaction(owner.connection));assertFalse(owner.connection.isClosed());
                }finally{
                    if(reader.isAlive()){reader.interrupt();reader.join(5000);}assertFalse(reader.isAlive(),"Owned reader must not leak after its source gate opens");
                }
            }finally{
                owner.lock.unlock();fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.ROLLBACK).build());
                fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.AUTO_COMMIT_ON).build());
            }
        }
    }
    private static void awaitBlockedCapture(Thread reader,Object monitor)throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
        while(System.nanoTime()<deadline&&reader.isAlive()){
            var info=ManagementFactory.getThreadMXBean().getThreadInfo(reader.threadId(),64);
            if(info!=null&&info.getThreadState()==Thread.State.BLOCKED&&info.getLockInfo()!=null&&info.getLockInfo().getIdentityHashCode()==System.identityHashCode(monitor)
                    &&info.getLockInfo().getClassName().equals(monitor.getClass().getName())&&info.getLockOwnerId()==Thread.currentThread().threadId()
                    &&Arrays.stream(info.getStackTrace()).anyMatch(frame->frame.getClassName().equals(MetadataPlatform.class.getName())&&frame.getMethodName().equals("captureBase")))return;
            LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
        }
        fail("The exact native-overlay reader did not block at its real source monitor");
    }
}
