package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.lang.management.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.concurrent.locks.LockSupport;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;
import static org.junit.jupiter.api.Assertions.*;

/** Cold owned and explicit native metadata acquire comparison rules independently. */
class InitialOwnedRulesBootstrapIT {
    @TempDir Path root;
    static Stream<Arguments> fences(){return Stream.of("MYSQL","MARIADB").flatMap(engine->Stream.of("cancellation","session-end","configuration","reservation","native-barrier","revision").map(race->Arguments.of(engine,race)));}
    private static ThreadInfo nativeBegin(Thread publisher){
        var value=ManagementFactory.getThreadMXBean().getThreadInfo(new long[]{publisher.threadId()},true,true)[0];if(value==null)return null;
        boolean step=Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.core.NativeDB")&&frame.getMethodName().equals("step"));
        boolean begin=Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.SQLiteConnection")&&frame.getMethodName().equals("setAutoCommit"));return step&&begin?value:null;
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void aColdOwnedBootstrapNeverWaitsForOrIsCertifiedByAnOlderPrivateCacheWrite(String engine)throws Exception{
        var released=new AtomicBoolean();var releases=new AtomicInteger();var attempts=new AtomicInteger();var failure=new AtomicReference<Throwable>();
        try(var fixture=new EngineFixture(root,engine);var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();var observer=fixture.open();var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();
            fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);var original=platform.publishedSnapshot(owner);assertTrue(original.identities().isEmpty());assertTrue(original.catalogCoverage().isEmpty());assertFalse(original.rules().complete());
            owner.lock.lock();try(var sql=owner.connection.createStatement()){sql.execute("CREATE TEMPORARY TABLE bootstrap_owned(v INTEGER)");}finally{owner.lock.unlock();}
            long ticket=platform.beginRefresh(observer);var incomplete=original.rules();var done=new AtomicBoolean();
            try(var blocker=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var lock=blocker.createStatement()){
                lock.execute("BEGIN IMMEDIATE");Thread publisher=Thread.ofPlatform().name("owned-old-empty-cache-writer").unstarted(()->{
                    attempts.incrementAndGet();try{platform.publish(observer,ticket,incomplete,Map.of(),false);}catch(Throwable problem){failure.set(problem);}finally{done.set(true);}
                });
                var guard=Executors.newSingleThreadScheduledExecutor();Runnable release=()->{if(released.compareAndSet(false,true))try{lock.execute("ROLLBACK");releases.incrementAndGet();}catch(SQLException problem){failure.compareAndSet(null,problem);}};
                var safety=guard.schedule(release,12,TimeUnit.SECONDS);
                try{
                    publisher.start();long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);ThreadInfo observed=null;
                    while(System.nanoTime()<deadline&&!released.get()&&!done.get()){observed=nativeBegin(publisher);if(observed!=null)break;LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));}
                    assertNotNull(observed,"An old-generation private SQLite write must actually be pending");assertFalse(released.get());assertFalse(done.get());
                    var owned=workers.submit(()->{owner.lock.lock();try(var maintenance=platform.ownedMaintenance(owner)){return explorer.refreshTemporary(owner,"busydata","busydata","bootstrap_owned");}finally{owner.lock.unlock();}}).get(8,TimeUnit.SECONDS);
                    assertFalse(released.get(),"Independent native acquisition and owned publication must finish before old cache unlock");assertFalse(done.get());
                    assertTrue(platform.publishedSnapshot(owner).rules().complete());assertTrue(platform.publishedSnapshot(owner).rules().matchesServer(owner.identifierContext));assertTrue(owned.complete(new MetadataScope("busydata","busydata","bootstrap_owned",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
                    assertEquals(List.of("v"),owned.namespace("busydata","busydata",ObjectKind.COLUMN,"bootstrap_owned").stream().map(value->value.identity().name()).toList());
                    assertEquals(owner.id,owned.resolve("busydata","busydata",ObjectKind.TABLE,"","bootstrap_owned",true).getFirst().identity().sessionOwner());assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner),"The newly bootstrapped generation was not persisted");
                    assertTrue(original.identities().isEmpty());assertFalse(original.rules().complete(),"The captured old empty snapshot stays immutable");
                }finally{release.run();safety.cancel(false);guard.shutdown();publisher.join(10_000);assertFalse(publisher.isAlive());}
                if(failure.get()!=null)throw new AssertionError("Owned old-generation writer failed",failure.get());assertEquals(1,releases.get());assertEquals(1,attempts.get());
            }
            assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner),"An older successful completion cannot certify the bootstrapped generation");
            var other=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setId("different-cache-owner")).setPassword("fixture").build());
            var rules=platform.publishedSnapshot(owner).rules();platform.publish(other,platform.beginRefresh(other),rules,Map.of(),false);
            assertEquals("AVAILABLE",platform.cacheState(other));assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner),"Another source's success cannot clear this source's gap");
            platform.publish(observer,platform.beginRefresh(observer),rules,Map.of(),false);assertEquals("AVAILABLE",platform.cacheState(owner));
            var stored=new MetadataRepository(root).load().stream().filter(value->value.source().equals(owner.metadataSourceIdentity)).findFirst().orElseThrow();
            assertEquals(rules.fingerprint(),stored.rules().fingerprint());assertTrue(stored.identities().values().stream().noneMatch(value->!value.identity().sessionOwner().isEmpty()));assertTrue(fixture.jobs.list(owner.id).isEmpty(),"Native introspection performs no SQL job or execution retry");
        }
    }
    @ParameterizedTest(name="{index}: {0}, {1}") @MethodSource("fences")
    void anInitialBootstrapCannotAdoptAuthorityChangedAfterItsIndependentAcquisition(String engine,String race)throws Exception{
        var prepared=new CountDownLatch(1);var release=new CountDownLatch(1);var armed=new AtomicBoolean(true);
        var platform=MetadataPublicationTestAccess.instrumented(root.resolve("publication"),()->{
            if(!armed.compareAndSet(true,false))return;prepared.countDown();try{if(!release.await(10,TimeUnit.SECONDS))throw new AssertionError("Missing controlled bootstrap release");}catch(InterruptedException failure){Thread.currentThread().interrupt();throw new AssertionError(failure);}
        });
        try(var fixture=new EngineFixture(root.resolve("physical-owner"),engine);var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();var observer=fixture.open();var initial=platform.publishedSnapshot(owner);assertTrue(initial.identities().isEmpty());assertTrue(initial.catalogCoverage().isEmpty());assertFalse(initial.rules().complete());
            var context=io.grpc.Context.current().withCancellation();
            var acquisition=workers.submit(context.wrap(()->{owner.lock.lock();try(var maintenance=platform.ownedMaintenance(owner)){try{return (Object)platform.ensureOwnedIdentifierRules(owner,System.nanoTime()+TimeUnit.SECONDS.toNanos(30));}catch(Throwable failure){return failure;}}finally{owner.lock.unlock();}}));
            MetadataPlatform.ExternalMutation mutation=null;
            try{
                assertTrue(prepared.await(8,TimeUnit.SECONDS),"The verified independent native map must already be acquired");
                switch(race){
                    case "cancellation"->context.cancel(null);
                    case "session-end"->workers.submit(owner::close).get(2,TimeUnit.SECONDS);
                    case "reservation"->assertNotNull(platform.reserveRefresh(observer));
                    case "revision"->owner.advanceRevision();
                    case "configuration"->{var old=platform.configuration(observer);platform.configure(observer,new MetadataConfiguration(old.revision()+1,old.includedCatalogs(),old.excludedCatalogs(),old.includedSchemas(),old.excludedSchemas(),old.systemObjects(),old.kinds(),old.includePatterns(),old.excludePatterns(),IntrospectionLevel.NAMES,old.scopeLevels()));}
                    case "native-barrier"->{observer.lock.lock();try{mutation=platform.beginExternalMutation(observer);}finally{observer.lock.unlock();}}
                    default->throw new AssertionError("Unknown native bootstrap race");
                }
                release.countDown();var refused=acquisition.get(5,TimeUnit.SECONDS);assertInstanceOf(Throwable.class,refused,"An obsolete native acquisition must not publish or retry with new authority");if(race.equals("cancellation"))assertInstanceOf(CancellationException.class,refused);
                assertFalse(platform.publishedSnapshot(observer).rules().complete());assertTrue(platform.publishedSnapshot(observer).identities().isEmpty());assertFalse(initial.rules().complete());assertTrue(initial.identities().isEmpty());assertTrue(fixture.jobs.list(owner.id).isEmpty());
            }finally{release.countDown();if(mutation!=null){observer.lock.lock();try{platform.finishExternalMutation(observer,mutation,false,false);}finally{observer.lock.unlock();}}acquisition.get(10,TimeUnit.SECONDS);context.close();}
        }finally{release.countDown();}
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void anIncompleteNonemptyCatalogRequiresExplicitReconciliationInsteadOfImplicitRekey(String engine)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var other=fixture.open();var platform=fixture.metadata.metadataPlatform();var original=platform.publishedSnapshot(owner);var scope=new MetadataScope("busydata","busydata","",ObjectKind.TABLE,"retained_names",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
            var wire=SchemaObject.newBuilder().setCatalog("busydata").setSchema("busydata").setName("retained_names").setKind(ObjectKind.TABLE).build();var coverage=new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,"names-only",other.revision,other.contextRevision,1,"");
            platform.publish(other,platform.beginRefresh(other),original.rules(),Map.of(scope,new MetadataPlatform.Branch(List.of(wire),coverage)),false);var nonempty=platform.publishedSnapshot(owner);assertEquals(1,nonempty.identities().size());assertFalse(nonempty.rules().complete());
            owner.lock.lock();try{var refused=assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->platform.ensureOwnedIdentifierRules(owner,System.nanoTime()+TimeUnit.SECONDS.toNanos(10)));assertEquals(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE,refused.reason());}finally{owner.lock.unlock();}
            assertSame(nonempty,platform.publishedSnapshot(owner));assertEquals(1,nonempty.identities().size());assertFalse(original.rules().complete());assertTrue(fixture.jobs.list(owner.id).isEmpty());
        }
    }
}
