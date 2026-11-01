package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import java.sql.*;
import java.lang.reflect.Proxy;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class SessionCleanupIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void failedSetupRetainsPrimaryAndCleanupFailuresAndReleasesItsPermit(String name)throws Exception {
        var ordinal=new AtomicInteger();var closed=new AtomicInteger();
        try(var fixture=new EngineFixture(root,name,(adapter,request,port)->{
            var delegate=adapter.connect(request,port);int index=ordinal.incrementAndGet();
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(index==1&&method.getName().equals("getAutoCommit"))throw new SQLException("Injected setup failure","08006");
                Object value=TransactionFaultIT.Faults.invoke(delegate,method,args);
                if(index==1&&method.getName().equals("close")){closed.incrementAndGet();throw new SQLException("Injected cleanup failure","58000");}
                return value;
            });
        })) {
            var failure=assertThrows(SQLException.class,fixture::open);
            assertEquals("08006",failure.getSQLState());assertEquals(1,failure.getSuppressed().length);
            assertEquals("58000",((SQLException)failure.getSuppressed()[0]).getSQLState());
            assertEquals(1,closed.get());assertEquals(0,fixture.sessions.size());
            var opened=new java.util.ArrayList<String>();for(int count=0;count<8;count++)opened.add(fixture.open().id);
            assertThrows(IllegalStateException.class,fixture::open);
            for(String id:opened)fixture.sessions.close(id,true);
            assertEquals(0,fixture.sessions.size());assertEquals(1,closed.get());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void disconnectReportsCleanupFailureWithoutLeakingDiagnosticsOrRepeatingClose(String name)throws Exception {
        var armed=new java.util.concurrent.atomic.AtomicReference<Connection>();var closed=new AtomicInteger();
        try(var fixture=new EngineFixture(root,name,(adapter,request,port)->{
            var delegate=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object value=TransactionFaultIT.Faults.invoke(delegate,method,args);
                if(proxy==armed.get()&&method.getName().equals("close")){closed.incrementAndGet();throw new SQLException("fixture-secret must not be a bridge warning","58000");}
                return value;
            });
        })) {
            var session=fixture.open();armed.set(session.connection);
            var reply=fixture.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.DISCONNECT).build());
            assertEquals(TransactionState.DISCONNECTED,reply.getTransaction());assertFalse(reply.getCommandWarning().isBlank());
            assertEquals(session.id,reply.getSessionId());assertEquals(session.profile,reply.getProfile());
            assertEquals(session.metadataSourceIdentity,reply.getMetadataSourceIdentity());
            assertEquals(session.revision,reply.getSessionRevision());assertEquals(session.contextRevision,reply.getContextRevision());
            assertFalse(reply.toString().contains("fixture-secret"));assertNotNull(session.cleanupFailure());
            session.close();fixture.sessions.close(session.id,true);assertEquals(1,closed.get());assertEquals(0,fixture.sessions.size());
            var replacement=fixture.open();fixture.execute(replacement,"SELECT 13");
        }
    }
}
