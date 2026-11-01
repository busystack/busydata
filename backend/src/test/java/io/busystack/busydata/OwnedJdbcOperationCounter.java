package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.OpenRequest;
import java.lang.reflect.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

/** Bounded observation of public JDBC calls on exactly the first writable fixture connection.
 * Native unwraps and driver-internal statements are deliberately outside this coverage. */
final class OwnedJdbcOperationCounter {
    private static final long LIMIT=1_000_000;
    private final AtomicReference<Connection> owner=new AtomicReference<>();
    private final AtomicBoolean armed=new AtomicBoolean(),overflow=new AtomicBoolean(),gateArmed=new AtomicBoolean();
    private final AtomicLong executes=new AtomicLong(),executed=new AtomicLong(),updates=new AtomicLong(),updated=new AtomicLong(),commits=new AtomicLong(),committed=new AtomicLong(),rollbacks=new AtomicLong(),rolledBack=new AtomicLong();
    final CountDownLatch indexRead=new CountDownLatch(1),indexRelease=new CountDownLatch(1);
    Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
        var actual=adapter.connect(request,port);
        if(request.getProfile().getReadOnly()||!owner.compareAndSet(null,actual))return actual;
        return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
            boolean observe=armed.get();String operation=method.getName();
            if(observe&&operation.equals("commit"))increment(commits);
            if(observe&&operation.equals("rollback"))increment(rollbacks);
            Object value=invoke(actual,method,args);
            if(observe&&operation.equals("commit"))increment(committed);
            if(observe&&operation.equals("rollback"))increment(rolledBack);
            if(value instanceof Statement statement&&(operation.equals("createStatement")||operation.equals("prepareStatement")))return statement(statement);
            if(operation.equals("getMetaData")&&value instanceof DatabaseMetaData metadata)return Proxy.newProxyInstance(DatabaseMetaData.class.getClassLoader(),new Class[]{DatabaseMetaData.class},(selected,call,parameters)->{
                if(call.getName().equals("getIndexInfo")&&gateArmed.compareAndSet(true,false)){
                    indexRead.countDown();
                    if(!indexRelease.await(20,TimeUnit.SECONDS))throw new SQLTimeoutException("Fixture owned index-read gate exceeded its bound");
                }
                return invoke(metadata,call,parameters);
            });
            return value;
        });
    }
    private Object statement(Statement actual){
        Class<?> contract=actual instanceof PreparedStatement?PreparedStatement.class:Statement.class;
        return Proxy.newProxyInstance(contract.getClassLoader(),new Class[]{contract},(proxy,method,args)->{
            String operation=method.getName();boolean observe=armed.get();
            boolean execution=Set.of("execute","executeQuery","executeUpdate","executeLargeUpdate").contains(operation);
            boolean update=operation.equals("executeUpdate")||operation.equals("executeLargeUpdate");
            if(observe&&execution)increment(executes);if(observe&&update)increment(updates);
            Object value=invoke(actual,method,args);
            if(observe&&execution)increment(executed);if(observe&&update)increment(updated);return value;
        });
    }
    private static Object invoke(Object actual,Method method,Object[] args)throws Throwable {
        try{return method.invoke(actual,args);}catch(InvocationTargetException failure){throw failure.getCause();}
    }
    private void increment(AtomicLong counter){counter.updateAndGet(previous->{if(previous>=LIMIT){overflow.set(true);return LIMIT;}return previous+1;});}
    void begin(){if(!armed.compareAndSet(false,true))throw new IllegalStateException("Fixture operation window is already active");}
    void end(){armed.set(false);}
    void gateNextIndexRead(){if(!gateArmed.compareAndSet(false,true))throw new IllegalStateException("Fixture index gate is already armed");}
    void releaseIndexRead(){indexRelease.countDown();}
    Map<String,Object> snapshot(){return Map.ofEntries(
        Map.entry("publicJdbcCoverage",true),Map.entry("driverInternalCoverage",false),Map.entry("nativeUnwrapCoverage",false),Map.entry("overflow",overflow.get()),
        Map.entry("executeAttempts",executes.get()),Map.entry("executeAcknowledgements",executed.get()),
        Map.entry("updateAttempts",updates.get()),Map.entry("updateAcknowledgements",updated.get()),
        Map.entry("commitAttempts",commits.get()),Map.entry("commitAcknowledgements",committed.get()),
        Map.entry("rollbackAttempts",rollbacks.get()),Map.entry("rollbackAcknowledgements",rolledBack.get()));}
    void noGeneratedDmlOrCommit(){var facts=snapshot();org.junit.jupiter.api.Assertions.assertEquals(false,facts.get("overflow"));org.junit.jupiter.api.Assertions.assertEquals(0L,facts.get("updateAttempts"));org.junit.jupiter.api.Assertions.assertEquals(0L,facts.get("commitAttempts"));}
}
