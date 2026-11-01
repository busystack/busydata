package io.busystack.busydata.metadata;

import java.sql.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/** Cancellation/deadline owns only an independently opened read-only metadata connection. */
public final class MetadataReadScope implements AutoCloseable {
    private static final ScheduledExecutorService deadlines=Executors.newSingleThreadScheduledExecutor(Thread.ofPlatform().daemon(true).name("metadata-deadline").factory());
    private static final ExecutorService cancellation=Executors.newVirtualThreadPerTaskExecutor();
    private final io.grpc.Context context=io.grpc.Context.current();
    private final AtomicBoolean finished=new AtomicBoolean(),aborted=new AtomicBoolean();
    private volatile boolean expired;
    private final Connection connection;
    private final io.grpc.Context.CancellationListener listener;
    private final ScheduledFuture<?> deadline;
    public MetadataReadScope(Connection independent,long deadlineNanos) {
        connection=independent;listener=ignored->abort();context.addListener(listener,cancellation);
        deadline=deadlines.schedule(()->{expired=true;abort();},Math.max(0,deadlineNanos-System.nanoTime()),TimeUnit.NANOSECONDS);
    }
    private void abort(){if(!finished.get()&&aborted.compareAndSet(false,true))cancellation.execute(()->{try{connection.abort(Runnable::run);}catch(SQLException unsupported){try{connection.close();}catch(SQLException ignored){}}});}
    public void check()throws SQLTimeoutException {
        if(expired)throw new SQLTimeoutException("Independent metadata acquisition deadline exceeded");
        if(context.isCancelled()||Thread.currentThread().isInterrupted())throw new CancellationException("Independent metadata acquisition cancelled");
    }
    @Override public void close(){finished.set(true);context.removeListener(listener);deadline.cancel(false);}
}
