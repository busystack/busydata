package io.busystack.busydata.analysis;

import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;

/** Test-only scheduling control over BusyData's existing bounded parser pool.
 * No upstream class, executor configuration, deadline or task is replaced. */
public final class SqlParsingTestAccess {
    private SqlParsingTestAccess(){}
    public static SharedCpuGate occupySharedCpu()throws Exception {
        var field=SqlParsing.class.getDeclaredField("CPU");field.setAccessible(true);var executor=(ThreadPoolExecutor)field.get(null);
        if(executor.getCorePoolSize()!=2||executor.getMaximumPoolSize()!=2)throw new IllegalStateException("Unexpected production parser concurrency");
        var gate=new SharedCpuGate(executor);try{gate.start();return gate;}catch(Exception|Error failure){try{gate.close();}catch(Exception|Error cleanup){failure.addSuppressed(cleanup);}throw failure;}
    }
    public static final class SharedCpuGate implements AutoCloseable {
        private final ThreadPoolExecutor executor;
        private final CountDownLatch entered=new CountDownLatch(2),release=new CountDownLatch(1),exited=new CountDownLatch(2);
        private final List<Future<?>> tasks=new ArrayList<>(2);private final AtomicReference<Throwable> failure=new AtomicReference<>();
        private boolean closed;
        private SharedCpuGate(ThreadPoolExecutor executor){this.executor=executor;}
        private void start()throws Exception {
            for(int index=0;index<2;index++)tasks.add(executor.submit(()->{
                entered.countDown();try{if(!release.await(20,TimeUnit.SECONDS))failure.compareAndSet(null,new AssertionError("Owned parser gate expired without release"));}
                catch(InterruptedException cancelled){Thread.currentThread().interrupt();failure.compareAndSet(null,cancelled);}
                finally{exited.countDown();}
            }));
            if(!entered.await(5,TimeUnit.SECONDS))throw new AssertionError("Both actual production parser workers must enter their owned gate");held();
        }
        public int occupiedWorkers(){held();return 2;}
        public void held(){if(closed||entered.getCount()!=0||release.getCount()!=1||exited.getCount()!=2||failure.get()!=null)throw new AssertionError("Production parser gate is no longer held",failure.get());}
        @Override public void close()throws Exception {
            if(closed)return;closed=true;release.countDown();Exception cleanup=null;
            for(var task:tasks)try{task.get(5,TimeUnit.SECONDS);}catch(Exception problem){if(!task.isDone())task.cancel(true);if(cleanup==null)cleanup=problem;else cleanup.addSuppressed(problem);}
            if(!exited.await(5,TimeUnit.SECONDS)){var problem=new IllegalStateException("An owned parser gate task did not exit");if(cleanup==null)cleanup=problem;else cleanup.addSuppressed(problem);}
            if(failure.get()!=null){var problem=new IllegalStateException("An owned parser gate failed",failure.get());if(cleanup==null)cleanup=problem;else cleanup.addSuppressed(problem);}
            if(cleanup!=null)throw cleanup;
            // The shared executor belongs to production. Never shut it down,
            // change its limits, purge its queue, or cancel another request.
        }
    }
}
