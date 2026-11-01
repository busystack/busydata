package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.concurrent.locks.LockSupport;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Real pinned SQLite connections; gates surround actual terminal calls only. */
class MetadataCacheTerminalTest {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private enum Mode { COMMIT,CLOSE,INTERRUPT_COMMIT,FAIL_CLOSE }
    private static final class Gate {
        final AtomicInteger opens=new AtomicInteger(),commits=new AtomicInteger(),closes=new AtomicInteger();final AtomicReference<Mode> arm=new AtomicReference<>();
        final CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);volatile OwnedConnection target;
        Connection open(Path file,Properties options)throws SQLException {opens.incrementAndGet();var connection=new OwnedConnection(file,options,this,arm.getAndSet(null));if(connection.mode!=null)target=connection;return connection;}
        void await()throws SQLException {entered.countDown();try{if(!release.await(8,TimeUnit.SECONDS))throw new SQLTimeoutException("Owned terminal fixture gate was not released");}catch(InterruptedException interrupted){Thread.currentThread().interrupt();throw new SQLTransientException("Owned terminal fixture interrupted","57014");}}
        void observed()throws Exception {assertTrue(entered.await(3,TimeUnit.SECONDS),"The owned terminal call never reached its causal gate");}
    }
    private static final class OwnedConnection extends org.sqlite.jdbc4.JDBC4Connection {
        private Gate gate;private Mode mode;
        OwnedConnection(Path file,Properties options,Gate gate,Mode mode)throws SQLException {super("jdbc:sqlite:"+file,file.toString(),options);this.gate=gate;this.mode=mode;}
        @Override public void setAutoCommit(boolean autoCommit)throws SQLException {
            if(gate!=null&&mode!=null&&autoCommit&&!getAutoCommit()){
                gate.commits.incrementAndGet();if(mode==Mode.COMMIT||mode==Mode.INTERRUPT_COMMIT){gate.await();if(mode==Mode.INTERRUPT_COMMIT)throw new org.sqlite.SQLiteException("Owned fixture interrupt",org.sqlite.SQLiteErrorCode.SQLITE_INTERRUPT);}
            }
            super.setAutoCommit(autoCommit);
        }
        @Override public void close()throws SQLException {
            if(gate!=null&&mode!=null){gate.closes.incrementAndGet();if(mode==Mode.CLOSE)gate.await();if(mode==Mode.FAIL_CLOSE)throw new SQLNonTransientConnectionException("Owned fixture close not acknowledged","08006");}
            super.close();
        }
        void fixtureCloseNative()throws SQLException {super.close();}
    }
    private static long until(long milliseconds){return System.nanoTime()+TimeUnit.MILLISECONDS.toNanos(milliseconds);}
    private static MetadataSnapshot snapshot(long revision){var object=MetadataObject.from("source","profile","",RULES,SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("public").setName("table_"+revision).build(),IntrospectionLevel.STRUCTURE,1,1);return new MetadataSnapshot("source","profile",revision,1,revision,RULES,List.of(object),Map.of());}
    private static MetadataSnapshot empty(){return MetadataSnapshot.empty("source","profile",RULES);}
    private static void idleRefusedWithoutOpen(MetadataRepository repository,Gate gate,MetadataSnapshot previous)throws Exception {
        int before=gate.opens.get();for(int n=0;n<2;n++){assertEquals("55000",assertThrows(SQLTransientException.class,repository::loadNewest).getSQLState());assertEquals("55000",assertThrows(SQLTransientException.class,()->repository.publish(snapshot(previous.revision()+1),previous)).getSQLState());}assertEquals(before,gate.opens.get(),"An owned/quarantined terminal slot must prevent a second native open");
    }
    private static void noModelsRetained(Object start)throws Exception {
        var seen=Collections.newSetFromMap(new IdentityHashMap<Object,Boolean>());var queue=new ArrayDeque<Object>();queue.add(start);
        while(!queue.isEmpty()){var value=queue.removeFirst();if(!seen.add(value))continue;assertTrue(seen.size()<=128,"Owned terminal graph exceeded its inspection bound");assertFalse(value instanceof MetadataSnapshot||value instanceof MetadataObject||value instanceof IdentifierRules,"Native terminal ownership retained semantic model/index evidence");
            if(value instanceof java.lang.ref.Reference<?>||!value.getClass().getName().startsWith("io.busystack.busydata."))continue;
            for(var type=value.getClass();type!=null&&type.getName().startsWith("io.busystack.busydata.");type=type.getSuperclass())for(var field:type.getDeclaredFields())if(!Modifier.isStatic(field.getModifiers())&&!field.getType().isPrimitive()){field.setAccessible(true);var child=field.get(value);if(child!=null)queue.addLast(child);}
        }
    }
    @Test void blockedCommitReturnsAtCallerDeadlineKeepsItsSlotAndEventuallyAcknowledgesExactlyOnce()throws Exception {
        var gate=new Gate();var repository=new MetadataRepository(root,gate::open);var before=snapshot(1);repository.publish(before,empty()).await(until(3000));gate.arm.set(Mode.COMMIT);long deadline=until(400);
        var receipt=repository.publish(snapshot(2),before,deadline);try{gate.observed();noModelsRetained(receipt);assertThrows(SQLTimeoutException.class,()->receipt.await(deadline));assertTrue(receipt.active());assertTrue(receipt.completed().isEmpty());assertEquals("WRITE_UNAVAILABLE",repository.cacheState());idleRefusedWithoutOpen(repository,gate,before);}
        finally{gate.release.countDown();}
        var completion=receipt.awaitCompletion(until(3000));assertNull(completion.failure());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,completion.metrics().commitOutcome());assertTrue(completion.metrics().deadlineOverrun());assertFalse(receipt.active());assertEquals(1,gate.commits.get());assertEquals(1,gate.closes.get());assertEquals("AVAILABLE",repository.cacheState());assertEquals(snapshot(2).identities(),repository.loadNewest().getFirst().identities());
    }
    @Test void blockedCloseKeepsAcknowledgedCommitSeparateFromUnconfirmedResourceCompletion()throws Exception {
        var gate=new Gate();var repository=new MetadataRepository(root,gate::open);var before=snapshot(1);repository.publish(before,empty()).await(until(3000));gate.arm.set(Mode.CLOSE);long deadline=until(400);var receipt=repository.publish(snapshot(2),before,deadline);
        try{gate.observed();assertEquals(1,gate.commits.get());assertThrows(SQLTimeoutException.class,()->receipt.await(deadline));assertTrue(receipt.active());idleRefusedWithoutOpen(repository,gate,before);}finally{gate.release.countDown();}
        var completion=receipt.awaitCompletion(until(3000));assertNull(completion.failure());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,completion.metrics().commitOutcome());assertTrue(completion.metrics().deadlineOverrun());assertFalse(completion.metrics().terminalCloseFailed());assertFalse(receipt.active());assertEquals(1,gate.closes.get());
    }
    @Test void explicitCancellationAndDeadlineRemainDistinctAfterAnUnacknowledgedNativeInterrupt()throws Exception {
        for(boolean cancelled:List.of(false,true)){
            Path scope=root.resolve(cancelled?"cancelled":"expired");var gate=new Gate();var repository=new MetadataRepository(scope,gate::open);var before=snapshot(1);repository.publish(before,empty()).await(until(3000));gate.arm.set(Mode.INTERRUPT_COMMIT);long deadline=until(cancelled?3000:300);var receipt=repository.publish(snapshot(2),before,deadline);
            try{gate.observed();if(cancelled)receipt.cancel();else while(System.nanoTime()<deadline)LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(2));}finally{gate.release.countDown();}
            var completion=receipt.awaitCompletion(until(3000));assertEquals(cancelled?MetadataRepository.FailureReason.CANCELLED:MetadataRepository.FailureReason.TIMED_OUT,completion.failure().primary().reason());assertEquals(1,completion.failure().suppressed().size());assertEquals(9,completion.failure().suppressed().getFirst().vendorCode()&255);assertFalse(completion.failure().factsLimited());
            assertEquals(MetadataRepository.CommitOutcome.UNKNOWN,completion.metrics().commitOutcome());assertTrue(completion.transactionBegan());assertTrue(completion.rollbackAttempted());assertTrue(completion.rollbackAcknowledged());assertEquals(1,gate.commits.get());assertEquals(before.identities(),repository.loadNewest().getFirst().identities());
        }
    }
    @Test void failedNativeCloseQuarantinesTheOnlySlotWithoutTrustingTheDriversClosedFlag()throws Exception {
        var gate=new Gate();var repository=new MetadataRepository(root,gate::open);var before=snapshot(1);repository.publish(before,empty()).await(until(3000));gate.arm.set(Mode.FAIL_CLOSE);var receipt=repository.publish(snapshot(2),before);
        try{var completion=receipt.awaitCompletion(until(3000));assertNotNull(completion.failure());assertEquals("08006",completion.failure().primary().sqlState());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,completion.metrics().commitOutcome());assertTrue(completion.metrics().terminalCloseFailed());assertTrue(receipt.active());idleRefusedWithoutOpen(repository,gate,before);assertEquals(1,gate.commits.get());assertEquals(1,gate.closes.get());}
        finally{assertNotNull(gate.target);gate.target.fixtureCloseNative();}
        assertTrue(receipt.active(),"Out-of-band fixture cleanup cannot authorize an automatic production reopen");idleRefusedWithoutOpen(repository,gate,before);
    }
    @Test void aQueuedLoadRechecksTerminalOwnershipAfterAcquiringTheFairTransactionLock()throws Exception {
        var gate=new Gate();var repository=new MetadataRepository(root,gate::open);var before=snapshot(1);repository.publish(before,empty()).await(until(3000));
        var field=MetadataRepository.class.getDeclaredField("transaction");field.setAccessible(true);var lock=(java.util.concurrent.locks.ReentrantLock)field.get(repository);assertTrue(lock.isFair());
        var readerThread=new AtomicReference<Thread>();var writerThread=new AtomicReference<Thread>();var started=new CountDownLatch(1);var workers=Executors.newFixedThreadPool(2);int opened=gate.opens.get();lock.lock();
        try{
            var reader=workers.submit(()->{readerThread.set(Thread.currentThread());started.countDown();return repository.loadNewest();});assertTrue(started.await(3,TimeUnit.SECONDS));
            long wait=until(3000);while(System.nanoTime()<wait&&!lock.hasQueuedThread(readerThread.get()))LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));assertTrue(lock.hasQueuedThread(readerThread.get()),"The exact reader must queue before the writer reserves its slot");
            gate.arm.set(Mode.COMMIT);var writer=workers.submit(()->{writerThread.set(Thread.currentThread());return repository.publish(snapshot(2),before);});
            wait=until(3000);while(System.nanoTime()<wait&&(repository.activeReceipt().isEmpty()||writerThread.get()==null||!lock.hasQueuedThread(writerThread.get())))LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
            assertTrue(repository.activeReceipt().isPresent());assertNotNull(writerThread.get());assertTrue(lock.hasQueuedThread(writerThread.get()));assertEquals(opened,gate.opens.get(),"Reservation must precede the first writer JDBC open");
            lock.unlock();var failure=assertThrows(ExecutionException.class,()->reader.get(3,TimeUnit.SECONDS));assertEquals("55000",assertInstanceOf(SQLTransientException.class,failure.getCause()).getSQLState());
            var receipt=writer.get(3,TimeUnit.SECONDS);gate.observed();assertEquals(opened+1,gate.opens.get(),"The queued reader must refuse after locking, before opening SQLite");gate.release.countDown();assertNull(receipt.awaitCompletion(until(3000)).failure());
        }finally{
            if(lock.isHeldByCurrentThread())lock.unlock();gate.release.countDown();workers.shutdownNow();assertTrue(workers.awaitTermination(3,TimeUnit.SECONDS));
            var active=repository.activeReceipt();if(active.isPresent())active.orElseThrow().awaitCompletion(until(3000));
        }
    }
}
