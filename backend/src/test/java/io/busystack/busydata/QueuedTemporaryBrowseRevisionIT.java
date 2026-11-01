package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;
import static org.junit.jupiter.api.Assertions.*;

/** Real TEMP browsing: native observations must not make unchanged approvals stale,
 * and raw structural changes must not borrow a previously approved shape. */
class QueuedTemporaryBrowseRevisionIT {
    private static final String TABLE="browse_temp_rows";
    @TempDir Path root;
    private static final class Counter {
        final AtomicReference<Connection> physical=new AtomicReference<>();
        final AtomicInteger prepared=new AtomicInteger(),executed=new AtomicInteger();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception{
            var actual=adapter.connect(request,port);boolean owned=!request.getProfile().getReadOnly()&&physical.compareAndSet(null,actual);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object value=invoke(actual,method,args);
                if(owned&&method.getName().equals("prepareStatement")&&args!=null&&args[0] instanceof String sql&&value instanceof PreparedStatement statement
                    &&sql.startsWith("SELECT * FROM ")&&sql.contains(TABLE)&&!sql.endsWith(" LIMIT 0")){
                    prepared.incrementAndGet();
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(selected,operation,parameters)->{
                        if(operation.getName().equals("executeQuery"))executed.incrementAndGet();return invoke(statement,operation,parameters);
                    });
                }
                return value;
            });
        }
    }
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable{
        try{return method.invoke(target,args);}catch(InvocationTargetException error){throw error.getCause();}
    }
    static Stream<Arguments> mutations(){return Stream.of(
        Arguments.of("MYSQL",false),Arguments.of("MYSQL",true),
        Arguments.of("MARIADB",false),Arguments.of("MARIADB",true));}
    private static void setup(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
        String permanent=owner.adapter.table("busydata",fixture.schema(),TABLE);
        fixture.execute(owner,"CREATE TABLE "+permanent+"(id INTEGER PRIMARY KEY,marker INTEGER); INSERT INTO "+permanent+" VALUES(99,999)");
        fixture.warm(owner,TABLE);
        fixture.execute(owner,"CREATE TEMPORARY TABLE "+owner.adapter.quote(TABLE)+"(id INTEGER PRIMARY KEY,marker VARCHAR(40)); INSERT INTO "+owner.adapter.quote(TABLE)+" VALUES(1,'temp')");
        refreshOwned(fixture,owner);
    }
    private static void refreshOwned(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        var explorer=new Explorer(fixture.metadata);owner.lock.lock();try{
            explorer.refreshTemporary(owner,"busydata","busydata",TABLE);
        }finally{owner.lock.unlock();}
    }
    private static BrowseRequest selected(EngineFixture fixture,SessionRegistry.Session owner){
        var snapshot=fixture.metadata.metadataPlatform().capture(owner);
        String schema="busydata";assertFalse(schema.isEmpty());
        var relations=snapshot.resolve("busydata",schema,ObjectKind.TABLE,"",TABLE,true);assertEquals(1,relations.size());var relation=relations.getFirst();
        assertEquals(owner.id,relation.identity().sessionOwner());assertEquals("true",relation.properties().get("temporary"));
        assertTrue(snapshot.complete(new MetadataScope("busydata",schema,TABLE,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
        return BrowseRequest.newBuilder().setSessionId(owner.id).setDocumentId("native-temp-browse").setCatalog("busydata").setSchema(schema).setTable(TABLE).setRowLimit(10)
            .setMetadataSnapshotRevision(snapshot.revision()).setMetadataObjectIdentity(relation.identity().key())
            .addConditions(RowCondition.newBuilder().setColumn("marker").setPredicate(ValuePredicate.EQUAL).setValue(Value.newBuilder().setText("temp"))).build();
    }
    private static void assertPermanentUntouched(EngineFixture fixture,SessionRegistry.Session observer)throws Exception{
        EditingIT.assertRows(observer,"SELECT id,marker FROM "+observer.adapter.table("busydata",fixture.schema(),TABLE),new int[][]{{99,999}});
        var global=fixture.metadata.metadataPlatform().publishedSnapshot(observer);
        var permanent=global.resolve("busydata",fixture.schema(),ObjectKind.TABLE,"",TABLE,true);assertEquals(1,permanent.size());assertTrue(permanent.getFirst().identity().sessionOwner().isEmpty());
        assertTrue(global.identities().values().stream().allMatch(value->value.identity().sessionOwner().isEmpty()),"No physical owner's TEMP identity may enter durable metadata");
    }
    @ParameterizedTest(name="{0}: recreate {1}") @MethodSource("mutations")
    void queuedNativeTemporaryChangeFailsBeforeGeneratedSelect(String engine,boolean recreate)throws Exception {
        var counter=new Counter();
        try(var dispatch=new JobDispatchGate();var fixture=new EngineFixture(root,engine,counter::connect,database->{},dispatch::decorate)) {
            dispatch.attach(fixture.jobs);
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner);
            var explorer=new Explorer(fixture.metadata);var request=selected(fixture,owner);
            var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            int before=fixture.jobs.list(owner.id).size();String execution=UUID.randomUUID().toString();Jobs.Job accepted;
            long revision=owner.revision,context=owner.contextRevision;
            dispatch.arm();
            try {
                accepted=TableBrowse.submit(owner,request.toBuilder().setExecutionId(execution).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
                dispatch.assertHeld(accepted);assertSame(accepted,fixture.jobs.get(accepted.id));assertEquals(execution,accepted.execution);
                assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);
                String target=owner.adapter.table(request.getCatalog(),request.getSchema(),TABLE);
                owner.lock.lock();try(var statement=owner.connection.createStatement()) {
                    if(recreate) {
                        statement.execute("DROP TEMPORARY TABLE "+target);
                        statement.execute("CREATE TEMPORARY TABLE "+target+"(id INTEGER PRIMARY KEY,marker VARCHAR(40),extra INTEGER DEFAULT 5)");
                        statement.execute("INSERT INTO "+target+"(id,marker) VALUES(1,'temp')");
                    }else statement.execute("ALTER TABLE "+target+" ADD COLUMN extra INTEGER DEFAULT 5");
                }finally{owner.lock.unlock();}
                assertEquals(revision,owner.revision,"The raw native mutation must not borrow a tracked session revision");
                assertEquals(context,owner.contextRevision,"The context must remain identical during this native revision gap");
                assertEquals(request.getMetadataSnapshotRevision(),fixture.metadata.metadataPlatform().capture(owner).revision(),"The queued guard must compare cached-old against native-new metadata");
                assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());
                // Job.info/list synchronize on the held monitor; inspect the
                // terminal summaries only after the explicit dispatch release.
            }finally{dispatch.release();}
            EditingIT.await(accepted);
            assertSame(accepted,fixture.jobs.get(accepted.id));assertEquals(execution,accepted.info().getExecutionId());
            assertEquals(JobState.FAILED,accepted.state,accepted.info().toString());assertEquals("stale",accepted.info().getErrorCode());
            assertEquals(0,accepted.info().getResultsCount());assertEquals(before+1,fixture.jobs.list(owner.id).size(),"The accepted job remains one failed job without retry or replacement");
            assertEquals(0,counter.prepared.get(),"A stale native TEMP shape must fail before JDBC prepares generated browse SQL");
            assertEquals(0,counter.executed.get(),"The queued guard must send no generated browse SQL");
            assertPermanentUntouched(fixture,observer);
            var other=fixture.metadata.metadataPlatform().capture(observer);
            assertTrue(other.identity(request.getMetadataObjectIdentity()).isEmpty(),"An owning TEMP incarnation cannot leak to another physical session");
            assertTrue(other.resolve("busydata",fixture.schema(),ObjectKind.TABLE,"",TABLE,true).stream().allMatch(relation->relation.identity().sessionOwner().isEmpty()));
        }
    }
}
