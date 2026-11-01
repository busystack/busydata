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
class TemporaryBrowseRevisionIT {
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
    static Stream<Arguments> modes(){return Stream.of(
        Arguments.of("POSTGRESQL",false),Arguments.of("MYSQL",false),Arguments.of("MARIADB",false),
        Arguments.of("MYSQL",true),Arguments.of("MARIADB",true));}
    private static void setup(EngineFixture fixture,SessionRegistry.Session owner,boolean ansi)throws Exception{
        fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
        if(ansi)fixture.execute(owner,"SET SESSION sql_mode=CONCAT(@@sql_mode,',ANSI_QUOTES')");
        String permanent=owner.adapter.table("busydata",fixture.schema(),TABLE);
        fixture.execute(owner,"CREATE TABLE "+permanent+"(id INTEGER PRIMARY KEY,marker INTEGER); INSERT INTO "+permanent+" VALUES(99,999)");
        fixture.warm(owner,TABLE);
        fixture.execute(owner,"CREATE TEMPORARY TABLE "+owner.adapter.quote(TABLE)+"(id INTEGER PRIMARY KEY,marker VARCHAR(40)); INSERT INTO "+owner.adapter.quote(TABLE)+" VALUES(1,'temp')");
        refreshOwned(fixture,owner);
    }
    private static void refreshOwned(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        var explorer=new Explorer(fixture.metadata);owner.lock.lock();try{
            if(fixture.engine==Engine.POSTGRESQL)explorer.refreshSessionOverlay(owner);
            else explorer.refreshTemporary(owner,"busydata","busydata",TABLE);
        }finally{owner.lock.unlock();}
    }
    private static BrowseRequest selected(EngineFixture fixture,SessionRegistry.Session owner){
        var snapshot=fixture.metadata.metadataPlatform().capture(owner);
        String schema=fixture.engine==Engine.POSTGRESQL?owner.context.temporarySchema():"busydata";assertFalse(schema.isEmpty());
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
    @ParameterizedTest(name="{index}: {0}, ANSI_QUOTES {1}") @MethodSource("modes")
    void unchangedTemporaryBrowseCanBeReviewedAndExecutedTwice(String engine,boolean ansi)throws Exception{
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)){
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,ansi);var explorer=new Explorer(fixture.metadata);
            int jobs=fixture.jobs.list(owner.id).size();String identity=selected(fixture,owner).getMetadataObjectIdentity();
            for(int round=1;round<=2;round++){
                var request=selected(fixture,owner);assertEquals(identity,request.getMetadataObjectIdentity());
                var approval=TableBrowse.review(owner,request,explorer,fixture.safety);assertFalse(approval.getToken().isEmpty());
                assertEquals(jobs+round-1,fixture.jobs.list(owner.id).size(),"Review never submits a generated SELECT");
                var job=TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
                EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
                assertEquals(jobs+round,fixture.jobs.list(owner.id).size());assertEquals(round,counter.prepared.get());assertEquals(round,counter.executed.get(),"One accepted TEMP browse sends exactly one generated SELECT");
                var retained=fixture.results.get(job.info().getResults(0).getResultId());assertEquals(1,retained.rows());assertEquals(2,retained.columns.size());
                assertEquals("1",retained.read(0).getValues(0).getSignedInteger());assertEquals("temp",retained.read(0).getValues(1).getText());
                assertEquals(identity,selected(fixture,owner).getMetadataObjectIdentity());assertPermanentUntouched(fixture,observer);
            }
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void rawTemporaryAlterRejectsTheExistingApprovalBeforeJobAdmission(String engine)throws Exception{
        rawMutationRejects(engine,false);
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void rawTemporaryRecreationOfSameNameRejectsTheExistingApprovalBeforeJobAdmission(String engine)throws Exception{
        rawMutationRejects(engine,true);
    }
    private void rawMutationRejects(String engine,boolean recreate)throws Exception{
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)){
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);var explorer=new Explorer(fixture.metadata);
            var request=selected(fixture,owner);var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            long revision=owner.revision,context=owner.contextRevision;int jobs=fixture.jobs.list(owner.id).size();String target=owner.adapter.table("busydata",request.getSchema(),TABLE);
            owner.lock.lock();try(var statement=owner.connection.createStatement()){
                if(recreate){
                    statement.execute((fixture.engine==Engine.POSTGRESQL?"DROP TABLE ":"DROP TEMPORARY TABLE ")+target);
                    statement.execute("CREATE TEMPORARY TABLE "+owner.adapter.quote(TABLE)+"(id INTEGER PRIMARY KEY,marker VARCHAR(40),extra INTEGER DEFAULT 5)");
                    statement.execute("INSERT INTO "+owner.adapter.quote(TABLE)+"(id,marker) VALUES(1,'temp')");
                }else statement.execute("ALTER TABLE "+target+" ADD COLUMN extra INTEGER DEFAULT 5");
            }finally{owner.lock.unlock();}
            assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision,"Raw fixture SQL intentionally bypasses Jobs revision/context updates");
            var unexpected=new AtomicReference<Jobs.Job>();
            try{
                var failure=assertThrows(WorkbenchFailure.class,()->unexpected.set(TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs)));
                assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());
            }finally{if(unexpected.get()!=null)EditingIT.await(unexpected.get());}
            assertEquals(jobs,fixture.jobs.list(owner.id).size(),"Stale TEMP approval is rejected before admission and is never replayed");
            assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void sqlModeChangeRetiresAnApprovalButFreshAnsiTemporaryBrowsingStillWorks(String engine)throws Exception{
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)){
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);var explorer=new Explorer(fixture.metadata);
            var old=selected(fixture,owner);var approval=TableBrowse.review(owner,old,explorer,fixture.safety);long context=owner.contextRevision;
            fixture.execute(owner,"SET SESSION sql_mode=CONCAT(@@sql_mode,',ANSI_QUOTES')");assertTrue(owner.contextRevision>context);int jobs=fixture.jobs.list(owner.id).size();
            var failure=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,old.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs));
            assertTrue(Set.of(WorkbenchFailure.Reason.STALE,WorkbenchFailure.Reason.INVALID_REVISION).contains(failure.reason()));
            assertEquals(jobs,fixture.jobs.list(owner.id).size());assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());
            refreshOwned(fixture,owner);var fresh=selected(fixture,owner);var reviewed=TableBrowse.review(owner,fresh,explorer,fixture.safety);
            var job=TableBrowse.submit(owner,fresh.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(reviewed.getToken()).build(),explorer,fixture.safety,fixture.jobs);
            EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());assertEquals(jobs+1,fixture.jobs.list(owner.id).size());assertEquals(1,counter.prepared.get());assertEquals(1,counter.executed.get());assertPermanentUntouched(fixture,observer);
        }
    }
}
