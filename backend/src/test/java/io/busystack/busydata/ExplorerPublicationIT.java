package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real catalog reads with deterministic publication races, without timed SQL or retries. */
class ExplorerPublicationIT {
    @TempDir Path root;
    private static final class Round {
        final CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);
    }
    private static final class Gate {
        private final AtomicReference<Round> next=new AtomicReference<>();
        private volatile List<Round> rounds=List.of();
        final AtomicInteger metadataConnections=new AtomicInteger(),blocked=new AtomicInteger();
        List<Round> arm(int count){var made=new ArrayList<Round>();for(int index=0;index<count;index++)made.add(new Round());rounds=List.copyOf(made);next.set(rounds.getFirst());return rounds;}
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            Round round=request.getProfile().getReadOnly()?next.get():null;
            if(request.getProfile().getReadOnly())metadataConnections.incrementAndGet();
            if(round==null||!next.compareAndSet(round,null))return adapter.connect(request,port);
            blocked.incrementAndGet();round.entered.countDown();
            if(!round.release.await(15,TimeUnit.SECONDS))throw new TimeoutException("The fixture did not release its metadata acquisition");
            var connection=adapter.connect(request,port);var closed=new AtomicBoolean();
            return (Connection)Proxy.newProxyInstance(getClass().getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                try{return method.invoke(connection,args);}
                catch(InvocationTargetException failure){throw failure.getCause();}
                finally{if(method.getName().equals("close")&&closed.compareAndSet(false,true)){int index=rounds.indexOf(round)+1;if(index<rounds.size())next.compareAndSet(null,rounds.get(index));}}
            });
        }
    }
    private static void setup(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception {
        session.lock.lock();try{try(var statement=session.connection.createStatement()){statement.execute("CREATE TABLE publication_a(id INTEGER)");statement.execute("CREATE TABLE publication_b(id INTEGER)");}session.refresh();session.advanceRevision();}finally{session.lock.unlock();}
        fixture.warm(session,"publication_a","publication_b");
    }
    private static MetadataScope requested(String schema){return new MetadataScope("busydata",schema,"",ObjectKind.TABLE,"publication_",false,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    private static ExploreRequest request(String schema){return ExploreRequest.newBuilder().setCatalog("busydata").setSchema(schema).setKind(ObjectKind.TABLE).setSearch("publication_").setLimit(1).setIndependentMetadata(true).build();}
    private static List<SchemaObject> verified(MetadataPlatform platform,io.busystack.busydata.sessions.SessionRegistry.Session session,String schema){var snapshot=platform.capture(session);return snapshot.namespace("busydata",schema,ObjectKind.TABLE,"").stream().filter(object->object.identity().name().startsWith("publication_")).map(snapshot::projection).toList();}
    private static MetadataSnapshot newer(MetadataPlatform platform,io.busystack.busydata.sessions.SessionRegistry.Session session,MetadataScope scope,List<SchemaObject> objects)throws Exception {
        var coverage=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,MetadataFingerprint.objects(objects),session.revision,session.contextRevision,System.currentTimeMillis(),"");
        return platform.publish(session,platform.beginRefresh(session),platform.capture(session).rules(),Map.of(scope,new MetadataPlatform.Branch(objects,coverage)),false);
    }
    private static FutureTask<SchemaObjects> start(Explorer explorer,io.busystack.busydata.sessions.SessionRegistry.Session session,ExploreRequest request){var future=new FutureTask<SchemaObjects>(()->explorer.explore(session,request));Thread.ofVirtual().start(future);return future;}
    private static void entered(Round round)throws Exception{assertTrue(round.entered.await(15,TimeUnit.SECONDS),"An old-ticket metadata acquisition must enter the fixture gate");}
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void newerCompleteBranchIsReusedAndItsContinuationRemainsStrict(String engine)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::connect)){
            var session=fixture.open();setup(fixture,session);var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();var values=verified(platform,session,fixture.schema());
            int before=gate.metadataConnections.get();var round=gate.arm(1).getFirst();var future=start(explorer,session,request(fixture.schema()));entered(round);
            MetadataSnapshot winner;try{winner=newer(platform,session,requested(fixture.schema()),values);}finally{round.release.countDown();}
            var first=future.get(20,TimeUnit.SECONDS);assertEquals(winner.revision(),first.getMetadataSnapshotRevision());assertEquals(2,first.getTotalCount());assertFalse(first.getComplete());
            assertEquals(1,gate.metadataConnections.get()-before,"A complete newer publication must not trigger another native acquisition");
            var second=explorer.explore(session,request(fixture.schema()).toBuilder().setContinuation(first.getContinuation()).build());assertTrue(second.getComplete());assertEquals(winner.revision(),second.getMetadataSnapshotRevision());assertNotEquals(first.getObjects(0).getStableIdentity(),second.getObjects(0).getStableIdentity());
            explorer.explore(session,request(fixture.schema()).toBuilder().setRefresh(true).build());assertThrows(Explorer.ContinuationFailure.class,()->explorer.explore(session,request(fixture.schema()).toBuilder().setContinuation(first.getContinuation()).build()));
            assertEquals(0,fixture.jobs.list("").size(),"Metadata reconciliation cannot submit a SQL job or replay a query");assertEquals(TransactionState.IDLE,session.state);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void newerFragmentCannotPretendTheRequestedBroadBranchIsComplete(String engine)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::connect)){
            var session=fixture.open();setup(fixture,session);var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();var values=verified(platform,session,fixture.schema());
            int before=gate.metadataConnections.get();var round=gate.arm(1).getFirst();var future=start(explorer,session,request(fixture.schema()));entered(round);
            MetadataSnapshot winner;try{winner=newer(platform,session,new MetadataScope("busydata",fixture.schema(),"",ObjectKind.TABLE,"publication_a",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),values.stream().filter(object->object.getName().equals("publication_a")).toList());}finally{round.release.countDown();}
            var first=future.get(20,TimeUnit.SECONDS);assertTrue(first.getMetadataSnapshotRevision()>winner.revision());assertEquals(2,first.getTotalCount());assertEquals(MetadataCount.AUTHORITATIVE_TOTAL,first.getCountAvailability());assertEquals("AVAILABLE",first.getMetadataState());
            assertEquals(2,gate.metadataConnections.get()-before,"An incomplete winning fragment requires one bounded reacquisition");assertEquals(0,fixture.jobs.list("").size());assertEquals(TransactionState.IDLE,session.state);
        }
    }
    @Test void repeatedSupersessionStopsAfterThreeMetadataAcquisitions()throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",gate::connect)){
            var session=fixture.open();setup(fixture,session);var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();var value=verified(platform,session,fixture.schema()).stream().filter(object->object.getName().equals("publication_a")).toList();
            var rounds=gate.arm(3);var future=start(explorer,session,request(fixture.schema()));
            for(var round:rounds){entered(round);try{newer(platform,session,new MetadataScope("busydata",fixture.schema(),"",ObjectKind.TABLE,"publication_a",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),value);}finally{round.release.countDown();}}
            var failed=assertThrows(ExecutionException.class,()->future.get(20,TimeUnit.SECONDS));assertInstanceOf(MetadataPlatform.SupersededRefresh.class,failed.getCause());assertEquals(3,gate.blocked.get());assertFalse(platform.capture(session).complete(requested(fixture.schema()),IntrospectionLevel.STRUCTURE));assertEquals(0,fixture.jobs.list("").size());assertEquals(TransactionState.IDLE,session.state);
        }
    }
    @Test void configurationChangeCannotUpgradeTheCapturedRequest()throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",gate::connect)){
            var session=fixture.open();setup(fixture,session);var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();var round=gate.arm(1).getFirst();var future=start(explorer,session,request(fixture.schema()));entered(round);
            try{var old=platform.configuration(session);platform.configure(session,new MetadataConfiguration(old.revision()+1,old.includedCatalogs(),old.excludedCatalogs(),old.includedSchemas(),old.excludedSchemas(),old.systemObjects(),old.kinds(),old.includePatterns(),old.excludePatterns(),IntrospectionLevel.NAMES,old.scopeLevels()));}finally{round.release.countDown();}
            var failed=assertThrows(ExecutionException.class,()->future.get(20,TimeUnit.SECONDS));assertInstanceOf(Explorer.ContinuationFailure.class,failed.getCause());assertEquals(1,gate.blocked.get());assertEquals(2,platform.capture(session).configurationRevision());assertEquals(0,fixture.jobs.list("").size());
        }
    }
}
