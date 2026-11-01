package io.busystack.busydata;

import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.JobState;
import java.lang.reflect.*;
import java.sql.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import static org.junit.jupiter.api.Assertions.*;

/** Test-only dispatch gate, installed through MetadataStore's existing JDBC decorator.
 * The newly registered Job's public state monitor is held before workers.submit.
 * No physical-session lock or production callback/API is added. */
final class JobDispatchGate implements AutoCloseable {
    private final AtomicReference<Jobs> registry=new AtomicReference<>();
    private final AtomicReference<Jobs.Job> selected=new AtomicReference<>();
    private final AtomicBoolean armed=new AtomicBoolean(),expired=new AtomicBoolean();
    private final AtomicReference<Throwable> failure=new AtomicReference<>();
    private final CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);
    private final ScheduledExecutorService guard=Executors.newSingleThreadScheduledExecutor();
    private volatile Thread holder;private volatile ScheduledFuture<?> safety;
    void attach(Jobs jobs){assertTrue(registry.compareAndSet(null,jobs));}
    void arm(){assertNull(selected.get());assertTrue(armed.compareAndSet(false,true));}
    Connection decorate(Connection actual){
        return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
            Object value=invoke(actual,method,args);
            if(method.getName().equals("prepareStatement")&&args!=null&&args[0].equals("INSERT INTO operations VALUES(?,?,?)")&&value instanceof PreparedStatement statement){
                var jobId=new AtomicReference<String>();
                return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(prepared,operation,parameters)->{
                    Object result=invoke(statement,operation,parameters);
                    if(operation.getName().equals("setString")&&parameters!=null&&parameters[0].equals(1))jobId.set((String)parameters[1]);
                    if(operation.getName().equals("executeUpdate")&&armed.compareAndSet(true,false)){
                        var job=registry.get().get(jobId.get());assertTrue(selected.compareAndSet(null,job));
                        holder=Thread.ofPlatform().name("owned-browse-dispatch-gate").start(()->{
                            synchronized(job){entered.countDown();try{if(!release.await(10,TimeUnit.SECONDS))failure.compareAndSet(null,new AssertionError("Missing dispatch release"));}
                                catch(InterruptedException error){Thread.currentThread().interrupt();failure.compareAndSet(null,error);}}
                        });
                        safety=guard.schedule(()->{expired.set(true);release.countDown();},8,TimeUnit.SECONDS);
                        if(!entered.await(2,TimeUnit.SECONDS))throw new SQLException("The exact registered job monitor was not acquired before dispatch");
                    }
                    return result;
                });
            }
            return value;
        });
    }
    void assertHeld(Jobs.Job job){
        assertSame(job,selected.get());assertEquals(0,entered.getCount());assertEquals(1,release.getCount());assertFalse(expired.get());
        assertEquals(JobState.QUEUED,job.state,"The exact worker is gated before physical-session acquisition and generated SQL");
        // Job.info/list synchronize on this same monitor; read public immutable
        // handles/state here, and inspect final summaries only after release.
    }
    void release()throws Exception{
        release.countDown();var deadline=safety;if(deadline!=null)deadline.cancel(false);var thread=holder;
        if(thread!=null){thread.join(10_000);assertFalse(thread.isAlive());}
        assertFalse(expired.get(),"Emergency release cannot masquerade as a controlled race");
        if(failure.get()!=null)throw new AssertionError("Owned dispatch holder failed",failure.get());
    }
    @Override public void close()throws Exception{try{release();}finally{guard.shutdown();}}
    private static Object invoke(Object owner,Method method,Object[] arguments)throws Throwable{
        try{return method.invoke(owner,arguments);}catch(InvocationTargetException error){throw error.getCause();}
    }
}
