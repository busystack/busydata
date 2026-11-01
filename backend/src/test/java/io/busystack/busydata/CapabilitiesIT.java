package io.busystack.busydata;

import io.busystack.busydata.administration.Capabilities;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.CancellationException;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class CapabilitiesIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void freshReadProbesPreserveActualConsoleTransactionAndRejectStaleContext(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();
            f.execute(session,"CREATE TEMPORARY TABLE capability_local(n INTEGER); INSERT INTO capability_local VALUES(53)");
            boolean instrumented=instrumented(f,session);
            f.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.BEGIN).build());
            var before=session.info();var request=request(session);
            var report=Capabilities.inspect(session,request,()->false);
            assertEquals("capability-test",report.getBackendInstance());
            assertEquals(before.getSessionRevision(),report.getSessionRevision());
            assertEquals(before.getContextRevision(),report.getContextRevision());
            assertEquals(before,session.info(),"Independent probes must not alter console state or context");
            assertEquals(TransactionState.ACTIVE,session.adapter.transaction(session.connection));
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT n FROM capability_local")) {
                assertTrue(rows.next());assertEquals(53,rows.getInt(1));assertFalse(rows.next());
            }
            assertTrue(report.getSerializedSize()<=32768);assertTrue(report.getEntriesCount()<=16);
            var entries=entries(report);
            assertEquals(CapabilityState.CAPABILITY_AVAILABLE,entries.get("plans").getState());
            assertEquals(CapabilityState.CAPABILITY_AVAILABLE,entries.get("principals").getState());
            assertEquals(CapabilityState.CAPABILITY_AVAILABLE,entries.get("locks").getState());
            assertTrue(entries.get("locks").getDataChecked());
            assertEquals(instrumented?CapabilityState.CAPABILITY_AVAILABLE:CapabilityState.CAPABILITY_UNAVAILABLE,entries.get("query-statistics").getState());
            if(!instrumented)assertFalse(entries.get("query-statistics").getDataChecked(),"Missing instrumentation is not an empty workload");
            assertTrue(report.getAvailability().contains("owning console"));
            f.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.ROLLBACK).build());
            assertEquals(TransactionState.IDLE,session.state);
            assertThrows(IllegalStateException.class,()->Capabilities.inspect(session,request,()->false));
            var reads=new AtomicInteger();
            assertThrows(CancellationException.class,()->Capabilities.inspect(session,request(session),()->reads.incrementAndGet()>2));
            assertEquals(TransactionState.IDLE,session.state);assertEquals(1,f.sessions.physicalSessionCount());
            var opened=new ArrayList<String>();for(int i=0;i<7;i++)opened.add(f.open().id);
            assertThrows(IllegalStateException.class,f::open);
            for(String id:opened)f.sessions.close(id,true);
            f.execute(session,"SELECT 59");
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void limitedPrincipalsAndReadOnlyProfilesReportActualScopeWithoutLeakingCredentials(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var administrator=f.open();boolean instrumented=instrumented(f,administrator);
            String sql=f.engine==Engine.POSTGRESQL?"CREATE ROLE capability_limited LOGIN PASSWORD 'fixture-limited'; GRANT CONNECT ON DATABASE busydata TO capability_limited":"CREATE USER 'capability_limited'@'%' IDENTIFIED BY 'fixture-limited'; GRANT SELECT ON busydata.* TO 'capability_limited'@'%'";
            f.execute(administrator,sql);
            var profile=f.profile.toBuilder().setUser("capability_limited").setReadOnly(true).build();
            var session=f.sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("fixture-limited").build());
            var report=Capabilities.inspect(session,request(session),()->false);var entries=entries(report);
            assertFalse(report.toString().contains("fixture-limited"));
            assertEquals(CapabilityState.CAPABILITY_DISABLED,entries.get("editing").getState());
            assertEquals(CapabilityState.CAPABILITY_DISABLED,entries.get("schema-changes").getState());
            assertEquals(CapabilityState.CAPABILITY_LIMITED,entries.get("grants").getState());
            if(f.engine==Engine.POSTGRESQL) {
                assertEquals(CapabilityState.CAPABILITY_LIMITED,entries.get("activities").getState());
                assertEquals(CapabilityState.CAPABILITY_AVAILABLE,entries.get("principals").getState());
                assertEquals(CapabilityState.CAPABILITY_UNAVAILABLE,entries.get("query-statistics").getState());
            }else {
                assertEquals(CapabilityState.CAPABILITY_DENIED,entries.get("principals").getState());
                assertEquals(instrumented?CapabilityState.CAPABILITY_DENIED:CapabilityState.CAPABILITY_UNAVAILABLE,entries.get("query-statistics").getState());
            }
            assertEquals(TransactionState.IDLE,session.state);
            assertEquals("busydata",session.context.catalog());
            assertEquals(CapabilityState.CAPABILITY_AVAILABLE,entries.get("plans").getState());
        }
    }
    private static CapabilityRequest request(SessionRegistry.Session session){return CapabilityRequest.newBuilder().setContext(Context.newBuilder().setInstanceId("capability-test")).setSessionId(session.id).setContextRevision(session.contextRevision).setSessionRevision(session.revision).build();}
    private static Map<String,Capability> entries(CapabilityList report){var entries=new LinkedHashMap<String,Capability>();for(var value:report.getEntriesList())assertNull(entries.put(value.getId(),value));return entries;}
    private static boolean instrumented(EngineFixture fixture,SessionRegistry.Session session)throws Exception {
        if(fixture.engine==Engine.POSTGRESQL)return false;
        try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT @@performance_schema")){assertTrue(rows.next());return rows.getBoolean(1);}
    }
}
