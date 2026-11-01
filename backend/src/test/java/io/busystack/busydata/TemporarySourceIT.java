package io.busystack.busydata;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import java.io.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class TemporarySourceIT {
    @TempDir Path root;
    private static final class Gate {
        final AtomicBoolean first=new AtomicBoolean(),enabled=new AtomicBoolean();final AtomicInteger shows=new AtomicInteger();
        final CountDownLatch readerEntered=new CountDownLatch(1),releaseReader=new CountDownLatch(1),controlReached=new CountDownLatch(1);
        Connection open(io.busystack.busydata.adapters.JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            var physical=adapter.connect(request,port);boolean owner=!request.getProfile().getReadOnly()&&first.compareAndSet(false,true);
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object result=invoke(physical,method,args);
                if(result instanceof PreparedStatement statement&&method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&sql.startsWith("SHOW CREATE TABLE")&&owner){shows.incrementAndGet();return prepared(statement);}
                if(result instanceof Statement statement&&method.getName().equals("createStatement"))return Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Statement.class},(p,m,a)->{if(m.getName().equals("executeQuery")&&a[0] instanceof String sql&&sql.contains("information_schema.PROCESSLIST"))controlReached.countDown();return invoke(statement,m,a);});
                return result;
            });
        }
        Object prepared(PreparedStatement statement){return Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{PreparedStatement.class},(proxy,method,args)->{
            Object value=invoke(statement,method,args);
            if(enabled.get()&&method.getName().equals("executeQuery")&&value instanceof ResultSet rows)return Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{ResultSet.class},(p,m,a)->{Object returned=invoke(rows,m,a);if(m.getName().equals("getCharacterStream")&&returned instanceof Reader reader)return new FilterReader(reader){boolean first=true;@Override public int read(char[] target,int offset,int length)throws IOException{if(first){first=false;readerEntered.countDown();try{if(!releaseReader.await(8,TimeUnit.SECONDS))throw new IOException("Fixture reader gate was not released");}catch(InterruptedException error){Thread.currentThread().interrupt();throw new IOException(error);}}return super.read(target,offset,length);}};return returned;});
            return value;
        });}
        private static Object invoke(Object target,Method method,Object[] args)throws Throwable{try{return method.invoke(target,args);}catch(InvocationTargetException failure){throw failure.getCause();}}
    }
    private static void ddl(io.busystack.busydata.sessions.SessionRegistry.Session session,String... statements)throws Exception{session.lock.lock();try{try(var command=session.connection.createStatement()){for(String statement:statements)command.execute(statement);}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}}
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void temporarySourceNeverBorrowsPermanentDefinitionsAndCancellationIsFenced(String engine)throws Exception {
        var gate=new Gate();
        try(var f=new EngineFixture(root,engine,gate::open)){
            var owner=f.open();int originalNetworkTimeout=owner.connection.getNetworkTimeout();var other=f.open();var explorer=new Explorer(f.metadata);var platform=explorer.metadata();var tools=new SchemaTools(platform);
            ddl(owner,"CREATE TABLE temporary_shadow(persistent_a INTEGER DEFAULT 1)");explorer.refreshContext(owner,MetadataPlatform.RefreshMode.FULL);
            var definition=SchemaToolRequest.newBuilder().setCatalog("busydata").setSchema("busydata").setTable("temporary_shadow").setKind(ObjectKind.TABLE).setAction(SchemaToolAction.OBJECT_DEFINITION).build();
            var permanent=tools.run(other,definition);assertTrue(permanent.getDefinition().contains("persistent_a"));
            ddl(owner,"CREATE TEMPORARY TABLE temporary_shadow(temporary_b INTEGER DEFAULT 2)");owner.lock.lock();try{explorer.refreshTemporary(owner,"busydata","busydata","temporary_shadow");}finally{owner.lock.unlock();}
            String identity=platform.capture(owner).resolve("busydata","busydata",ObjectKind.TABLE,"","temporary_shadow",true).getFirst().identity().key();assertNotEquals(permanent.getInspectedObject().getStableIdentity(),identity);
            var held=new CountDownLatch(1);var release=new CountDownLatch(1);var blocker=Thread.ofVirtual().start(()->{owner.lock.lock();try{held.countDown();release.await();}catch(InterruptedException error){Thread.currentThread().interrupt();}finally{owner.lock.unlock();}});assertTrue(held.await(3,TimeUnit.SECONDS));int shows=gate.shows.get();
            try{assertEquals(WorkbenchFailure.Reason.UNAVAILABLE,assertThrows(WorkbenchFailure.class,()->tools.run(owner,definition)).reason());assertTrue(tools.run(other,definition).getDefinition().contains("persistent_a"));assertEquals(shows,gate.shows.get());}finally{release.countDown();blocker.join(3000);}
            try(var cancelled=io.grpc.Context.current().withCancellation()){cancelled.cancel(new CancellationException("Superseded source request"));assertThrows(CancellationException.class,()->cancelled.call(()->tools.run(owner,definition)));assertEquals(shows,gate.shows.get());}
            gate.enabled.set(true);
            try(var cancelled=io.grpc.Context.current().withCancellation()){
                var future=new FutureTask<SchemaToolResult>(()->cancelled.call(()->tools.run(owner,definition)));Thread.ofVirtual().start(future);
                assertTrue(gate.readerEntered.await(5,TimeUnit.SECONDS));cancelled.cancel(new CancellationException("Superseded during native source read"));try{assertTrue(gate.controlReached.await(5,TimeUnit.SECONDS),"The owned native cancellation controller must run");}finally{gate.releaseReader.countDown();}
                var failure=assertThrows(ExecutionException.class,()->future.get(8,TimeUnit.SECONDS));assertInstanceOf(CancellationException.class,failure.getCause());
            }finally{gate.enabled.set(false);gate.releaseReader.countDown();}
            assertEquals(originalNetworkTimeout,owner.connection.getNetworkTimeout());assertEquals(TransactionState.IDLE,owner.state);assertEquals(TransactionState.IDLE,owner.adapter.transaction(owner.connection));try(var statement=owner.connection.createStatement();var rows=statement.executeQuery("SELECT 17")){assertTrue(rows.next());assertEquals(17,rows.getInt(1));}
            owner.connection.setAutoCommit(false);owner.autoCommit=false;owner.refresh();assertEquals(TransactionState.IDLE,owner.state);
            var beforeSource=platform.capture(owner);var columnScope=new MetadataScope("busydata","busydata","temporary_shadow",ObjectKind.COLUMN);var knownColumns=beforeSource.catalogCoverage().get(columnScope);
            assertTrue(beforeSource.ownedRelationAvailable("busydata","busydata","temporary_shadow",true),"The native L2 acquisition established owned structure before the L3-only read");
            var nativeSource=tools.run(owner,definition);assertTrue(nativeSource.getComplete(),()->{
                var snapshot=platform.capture(owner);var names=new io.busystack.busydata.metadata.MetadataScope("busydata","busydata","",ObjectKind.TABLE,"temporary_shadow",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);var columns=new io.busystack.busydata.metadata.MetadataScope("busydata","busydata","temporary_shadow",ObjectKind.COLUMN);
                return "Source availability="+nativeSource.getInspectedObject().getPropertiesOrDefault("sourceAvailability","")+" objectState="+nativeSource.getInspectedObject().getMetadataState()+" unsupported="+nativeSource.getUnsupportedList()+" resolution="+snapshot.sessionResolution().state()+" epoch="+snapshot.sessionResolution().epoch()+" ownedNameAvailable="+snapshot.scopeResolutionAvailable(names)+" ownedShapeAvailable="+snapshot.scopeResolutionAvailable(columns)+" nativeTemporary="+snapshot.sessionResolution().verified()+" anchors="+snapshot.sessionResolution().owned().values().stream().map(e->"objectSame:"+(snapshot.identity(e.relation().identity().key()).orElse(null)==e.relation())+",namesSame:"+(snapshot.catalogCoverage().get(e.namesScope())==e.names())+",columnsSame:"+(e.columnsScope()!=null&&snapshot.catalogCoverage().get(e.columnsScope())==e.columns())).toList()+" rawScopes="+snapshot.catalogCoverage().values().stream().filter(c->c.scope().parent().equals("temporary_shadow")||c.scope().parent().isEmpty()&&c.scope().search().equals("temporary_shadow")).map(c->c.scope().kind()+":"+c.level()+":"+c.state()+":"+c.complete()+":"+c.limitation()).toList();
            });assertEquals("AVAILABLE",nativeSource.getInspectedObject().getPropertiesOrThrow("sourceAvailability"));assertTrue(nativeSource.getDefinition().startsWith("CREATE TEMPORARY TABLE"));assertTrue(nativeSource.getDefinition().contains("temporary_b"));assertFalse(nativeSource.getDefinition().contains("persistent_a"));assertEquals(identity,nativeSource.getInspectedObject().getStableIdentity());assertEquals(originalNetworkTimeout,owner.connection.getNetworkTimeout());assertFalse(owner.connection.getAutoCommit());assertEquals(TransactionState.IDLE,owner.adapter.transaction(owner.connection));owner.connection.rollback();owner.connection.setAutoCommit(true);owner.autoCommit=true;owner.refresh();
            var afterSource=platform.capture(owner);
            assertSame(knownColumns,afterSource.catalogCoverage().get(columnScope),"A source-only publication must retain the already verified column acquisition");
            assertTrue(afterSource.ownedRelationAvailable("busydata","busydata","temporary_shadow",true),"The collect-release/publication boundary must rebind fresh TABLE source to the owned L2 column anchors");
            assertEquals(beforeSource.sessionResolution().epoch(),afterSource.sessionResolution().epoch());
            assertTrue(beforeSource.ownedRelationAvailable("busydata","busydata","temporary_shadow",true),"Publishing L3 must leave the prior immutable captured reader unchanged");
            for(int level:List.of(1,2,3)){var response=explorer.explore(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema("busydata").setKind(ObjectKind.TABLE).setSearch("temporary_shadow").setExactName(true).setIntrospectionLevel(level).setIndependentMetadata(true).build());assertEquals(identity,response.getObjects(0).getStableIdentity());assertEquals(owner.id,response.getObjects(0).getPropertiesOrThrow("sessionOwner"));}
            assertTrue(platform.publishedSnapshot(owner).identities().values().stream().noneMatch(object->object.identity().sessionOwner().equals(owner.id)));assertTrue(tools.run(other,definition).getDefinition().contains("persistent_a"));
            ddl(owner,"CREATE DATABASE temporary_context");owner.connection.setCatalog("temporary_context");owner.refresh();owner.advanceRevision();assertTrue(tools.run(owner,definition).getDefinition().contains("temporary_b"));
            var columns=new ArrayList<String>();String quotes="'".repeat(1024).replace("'","''");for(int index=0;index<40;index++)columns.add("c"+index+" TEXT COMMENT '"+quotes+"'");ddl(owner,"CREATE TEMPORARY TABLE temporary_large("+String.join(",",columns)+")");owner.lock.lock();try{explorer.refreshTemporary(owner,"temporary_context","temporary_context","temporary_large");}finally{owner.lock.unlock();}
            var limited=tools.run(owner,definition.toBuilder().setCatalog("temporary_context").setSchema("temporary_context").setTable("temporary_large").build());assertFalse(limited.getComplete());assertTrue(limited.getDefinition().isEmpty());assertEquals("LIMITED",limited.getInspectedObject().getPropertiesOrThrow("sourceAvailability"));assertTrue(f.jobs.list("").isEmpty());
        }finally{gate.releaseReader.countDown();}
    }
}
