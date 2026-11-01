package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Genuine exact view selection, native kind/persistence and readonly controls. */
class ReadonlyViewBrowseIT {
    @TempDir Path root;
    private static final String NAME="Quoted view_%";
    private static final class Generated {
        volatile String sql="";final AtomicInteger prepares=new AtomicInteger(),executes=new AtomicInteger();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception{
            var actual=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object value=invoke(actual,method,args);
                if(method.getName().equals("prepareStatement")&&args[0].equals(sql)&&value instanceof PreparedStatement statement){
                    prepares.incrementAndGet();return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(prepared,operation,parameters)->{
                        if(operation.getName().equals("executeQuery")||operation.getName().equals("execute"))executes.incrementAndGet();return invoke(statement,operation,parameters);
                    });
                }return value;
            });
        }
    }
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable{try{return method.invoke(target,args);}catch(InvocationTargetException error){throw error.getCause();}}
    private static BrowseRequest selected(EngineFixture fixture,SessionRegistry.Session owner,Explorer explorer){
        var snapshot=explorer.metadata().capture(owner);var view=snapshot.resolve("busydata",fixture.schema(),ObjectKind.VIEW,"",NAME,true).getFirst();
        return BrowseRequest.newBuilder().setSessionId(owner.id).setExecutionId(UUID.randomUUID().toString()).setDocumentId("verified-readonly-view").setCatalog(view.identity().catalog()).setSchema(view.identity().schema()).setTable(view.identity().name()).setMetadataObjectIdentity(view.identity().key()).setMetadataSnapshotRevision(snapshot.revision()).setRowLimit(10).build();
    }
    private static void setup(EngineFixture fixture,SessionRegistry.Session owner,Explorer explorer,boolean materialized)throws Exception{
        fixture.execute(owner,"CREATE TABLE view_source(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO view_source VALUES(1,7); CREATE "+(materialized?"MATERIALIZED ":"")+"VIEW "+owner.adapter.quote(NAME)+" AS SELECT id,n FROM view_source");
        explorer.refreshFragment(owner,"busydata",fixture.schema(),NAME,ObjectKind.VIEW);
    }
    private static void readableAndReadonly(EngineFixture fixture,SessionRegistry.Session owner,Explorer explorer,Generated generated)throws Exception{
        var request=selected(fixture,owner,explorer);generated.sql="SELECT * FROM "+owner.adapter.table(request.getCatalog(),request.getSchema(),request.getTable());
        var review=TableBrowse.review(owner,request,explorer,fixture.safety);var job=TableBrowse.submit(owner,request.toBuilder().setApprovalToken(review.getToken()).build(),explorer,fixture.safety,fixture.jobs);EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
        assertEquals(1,generated.prepares.get());assertEquals(1,generated.executes.get());var result=fixture.results.get(job.info().getResults(0).getResultId());assertEquals(1,result.rows());assertEquals("7",result.read(0).getValues(1).getSignedInteger());
        var edit=ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(result.id).setCatalog(request.getCatalog()).setSchema(request.getSchema()).setTable(request.getTable()).build();assertFalse(new ChangePlanner(fixture.safety,fixture.results,explorer.metadata()).assess(owner,edit).getEditable());
        EditingIT.assertRows(owner,"SELECT id,n FROM view_source",new int[][]{{1,7}});
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void exactQuotedViewRetainsNormalReadonlyBrowse(String engine)throws Exception{
        var generated=new Generated();try(var fixture=new EngineFixture(root,engine,generated::connect)){
            var owner=fixture.open();var explorer=new Explorer(fixture.metadata);setup(fixture,owner,explorer,false);
            if(fixture.engine!=Engine.POSTGRESQL){owner.lock.lock();try{
                var physical=OwnedTemporarySource.verify(explorer.metadata(),owner,"busydata",fixture.schema(),NAME,System.nanoTime()+TimeUnit.SECONDS.toNanos(10),null);physical.requirePersistent();assertEquals(ObjectKind.VIEW,physical.nativeObjectKind());assertTrue(physical.nativeName().isEmpty(),"The native display alias is not a new canonical identity");
            }finally{owner.lock.unlock();}}
            readableAndReadonly(fixture,owner,explorer,generated);
        }
    }
    @Test void exactMaterializedViewRetainsReadonlyBrowseWithoutInventingATemporaryVariant()throws Exception{
        var generated=new Generated();try(var fixture=new EngineFixture(root,"POSTGRESQL",generated::connect)){
            var owner=fixture.open();var explorer=new Explorer(fixture.metadata);setup(fixture,owner,explorer,true);var request=selected(fixture,owner,explorer);assertEquals(ObjectSubtype.MATERIALIZED_VIEW,explorer.metadata().capture(owner).identity(request.getMetadataObjectIdentity()).orElseThrow().identity().subtype());readableAndReadonly(fixture,owner,explorer,generated);
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void temporaryTableShadowCannotUseAPersistentViewApproval(String engine)throws Exception{
        var generated=new Generated();try(var fixture=new EngineFixture(root,engine,generated::connect)){
            var owner=fixture.open();var explorer=new Explorer(fixture.metadata);setup(fixture,owner,explorer,false);var request=selected(fixture,owner,explorer);generated.sql="SELECT * FROM "+owner.adapter.table(request.getCatalog(),request.getSchema(),request.getTable());var review=TableBrowse.review(owner,request,explorer,fixture.safety);int jobs=fixture.jobs.list("").size();var durable=explorer.metadata().publishedSnapshot(owner);
            owner.lock.lock();try(var sql=owner.connection.createStatement()){sql.execute("CREATE TEMPORARY TABLE "+owner.adapter.quote(NAME)+"(id INTEGER PRIMARY KEY,n INTEGER)");sql.execute("INSERT INTO "+owner.adapter.quote(NAME)+" VALUES(99,999)");}finally{owner.lock.unlock();}
            var failed=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setApprovalToken(review.getToken()).build(),explorer,fixture.safety,fixture.jobs));assertEquals(WorkbenchFailure.Reason.STALE,failed.reason());assertEquals(jobs,fixture.jobs.list("").size());assertEquals(0,generated.prepares.get());assertEquals(0,generated.executes.get());assertSame(durable,explorer.metadata().publishedSnapshot(owner));
            var other=fixture.open();EditingIT.assertRows(other,"SELECT id,n FROM "+other.adapter.quote(NAME),new int[][]{{1,7}});EditingIT.assertRows(owner,"SELECT id,n FROM "+owner.adapter.quote(NAME),new int[][]{{99,999}});
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void rawReplacementWithABaseTableRejectsAnOldViewApprovalBeforeAnyGeneratedSql(String engine)throws Exception{
        var generated=new Generated();try(var fixture=new EngineFixture(root,engine,generated::connect)){
            var owner=fixture.open();var explorer=new Explorer(fixture.metadata);setup(fixture,owner,explorer,false);var request=selected(fixture,owner,explorer);generated.sql="SELECT * FROM "+owner.adapter.table(request.getCatalog(),request.getSchema(),request.getTable());var review=TableBrowse.review(owner,request,explorer,fixture.safety);int jobs=fixture.jobs.list("").size();long revision=owner.revision,context=owner.contextRevision;
            owner.lock.lock();try(var sql=owner.connection.createStatement()){sql.execute("DROP VIEW "+owner.adapter.quote(NAME));sql.execute("CREATE TABLE "+owner.adapter.quote(NAME)+"(id INTEGER PRIMARY KEY,n INTEGER)");sql.execute("INSERT INTO "+owner.adapter.quote(NAME)+" VALUES(99,999)");}finally{owner.lock.unlock();}
            assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);
            var failed=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setApprovalToken(review.getToken()).build(),explorer,fixture.safety,fixture.jobs));assertEquals(WorkbenchFailure.Reason.STALE,failed.reason());assertEquals(jobs,fixture.jobs.list("").size());assertEquals(0,generated.prepares.get());assertEquals(0,generated.executes.get());
            assertFalse(explorer.metadata().capture(owner).complete(new MetadataScope("busydata",fixture.schema(),NAME,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE),"Observed stale native kind cannot leave the selected structural scope advertised complete");EditingIT.assertRows(owner,"SELECT id,n FROM view_source",new int[][]{{1,7}});EditingIT.assertRows(owner,"SELECT id,n FROM "+owner.adapter.quote(NAME),new int[][]{{99,999}});
        }
    }
}
