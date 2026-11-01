package io.busystack.busydata;

import io.busystack.busydata.metadata.IntrospectionLevel;
import io.busystack.busydata.protocol.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real transport/session ownership with a bounded, deterministic native-read gate. */
class PhysicalRelationClassificationIT {
    @TempDir Path root;
    private static Object invoke(Object target,Method method,Object[] arguments)throws Throwable {
        try{return method.invoke(target,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void cancellingTheNativeCheckNeverSubmitsTheFollowingUserSelect(String engine)throws Exception {
        var first=new AtomicBoolean();var armed=new AtomicBoolean();var entered=new CountDownLatch(1);var release=new CountDownLatch(1);
        var sourceQueries=new AtomicInteger();var nativeProbe=new AtomicReference<Statement>();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);boolean owner=!request.getProfile().getReadOnly()&&first.compareAndSet(false,true);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object result=invoke(physical,method,args);
                if(owner&&method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SHOW CREATE TABLE")){
                    var prepared=(PreparedStatement)result;
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(statement,operation,parameters)->{
                        if(operation.getName().equals("executeQuery")&&armed.get()){
                            nativeProbe.set((Statement)statement);entered.countDown();
                            if(!release.await(10,TimeUnit.SECONDS))throw new SQLTimeoutException("Fixture native-read gate exceeded its bound");
                            throw new SQLException("Fixture native read interrupted","70100");
                        }
                        return invoke(prepared,operation,parameters);
                    });
                }
                if(owner&&method.getName().equals("createStatement")){
                    var statement=(Statement)result;
                    return Proxy.newProxyInstance(Statement.class.getClassLoader(),new Class[]{Statement.class},(ignored,operation,parameters)->{
                        if(operation.getName().equals("execute")&&parameters!=null&&parameters.length>0&&parameters[0] instanceof String sql&&sql.startsWith("SELECT id,n FROM "))sourceQueries.incrementAndGet();
                        return invoke(statement,operation,parameters);
                    });
                }
                return result;
            });
        })){
            var owner=fixture.open();fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
            fixture.execute(owner,"CREATE TABLE classified_rows(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO classified_rows VALUES(1,2)");fixture.warm(owner,"classified_rows");
            int originalTimeout=owner.connection.getNetworkTimeout();String select="SELECT id,n FROM "+owner.adapter.table("busydata","busydata","classified_rows");
            armed.set(true);var job=fixture.submit(owner,select);
            assertTrue(entered.await(10,TimeUnit.SECONDS),"The native relation check must run before the user SELECT");
            assertSame(nativeProbe.get(),job.statement,"Job cancellation owns the active native metadata statement");assertSame(owner,job.statementSession);
            fixture.jobs.cancel(job.id);release.countDown();
            var outcome=job.finished.get(15,TimeUnit.SECONDS);assertEquals(JobState.CANCELLED,outcome.getState());
            assertEquals(0,sourceQueries.get(),"Cancelled metadata work must never submit or retry the original SELECT");
            assertNull(job.statement);assertTrue(job.cancelFinished.isDone());assertEquals(originalTimeout,owner.connection.getNetworkTimeout());assertEquals(TransactionState.IDLE,owner.state);
            armed.set(false);var explicit=fixture.execute(owner,select);assertEquals(JobState.COMPLETED,explicit.state);assertEquals(1,sourceQueries.get(),"A later explicitly requested SELECT is a separate execution");
            assertTrue(fixture.results.get(explicit.info().getResults(0).getResultId()).metadataProof().available());
        }finally{release.countDown();}
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void nativeMetadataDenialKeepsTheUserResultReadableAndItsTypedProofUnavailable(String engine)throws Exception {
        var first=new AtomicBoolean();var denied=new AtomicBoolean();var metadataAttempts=new AtomicInteger();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);boolean owner=!request.getProfile().getReadOnly()&&first.compareAndSet(false,true);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object result=invoke(physical,method,args);
                if(owner&&method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SHOW CREATE TABLE")){
                    var prepared=(PreparedStatement)result;
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(statement,operation,parameters)->{
                        if(operation.getName().equals("executeQuery")&&denied.get()){metadataAttempts.incrementAndGet();throw new SQLException("Fixture native metadata denied","42000",1142);}
                        return invoke(prepared,operation,parameters);
                    });
                }return result;
            });
        })){
            var owner=fixture.open();fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
            fixture.execute(owner,"CREATE TABLE denied_classification(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO denied_classification VALUES(1,2)");fixture.warm(owner,"denied_classification");
            int timeout=owner.connection.getNetworkTimeout();String sql="SELECT id,n FROM "+owner.adapter.table("busydata","busydata","denied_classification");
            denied.set(true);var operation=fixture.execute(owner,sql);assertEquals(JobState.COMPLETED,operation.state);
            var retained=fixture.results.get(operation.info().getResults(0).getResultId());assertEquals(1,retained.rows());assertEquals(io.busystack.busydata.metadata.MetadataState.DENIED,retained.metadataProof().state());assertFalse(retained.metadataProof().capturedStructure());
            assertEquals(1,metadataAttempts.get(),"The denied native check is never retried");assertEquals(timeout,owner.connection.getNetworkTimeout());assertEquals(TransactionState.IDLE,owner.state);
            denied.set(false);var fresh=fixture.results.get(fixture.execute(owner,sql).info().getResults(0).getResultId());assertTrue(fresh.metadataProof().available());assertEquals(io.busystack.busydata.metadata.MetadataState.DENIED,retained.metadataProof().state(),"Later native verification never upgrades the old execution");
        }
    }

}
