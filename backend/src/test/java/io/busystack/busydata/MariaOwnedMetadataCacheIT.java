package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import java.lang.management.*;
import java.nio.file.*;
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

/** Native MariaDB temporary inventory while an observed real private cache write is blocked. */
class MariaOwnedMetadataCacheIT {
    @TempDir Path root;
    private enum HeaderWitness { MATCHED_ATTEMPTED_REVISION, DIFFERENT_REVISION, MISSING }
    private static void snapshotFacts(Map<String,Object> report,String phase,MetadataSnapshot snapshot){
        report.put(phase+"SnapshotRevision",snapshot.revision());report.put(phase+"ConfigurationRevision",snapshot.configurationRevision());
        var counts=new TreeMap<String,Integer>();int complete=0;
        for(var state:MetadataState.values())counts.put(state.name(),0);
        for(var value:snapshot.catalogCoverage().values()){counts.merge(value.state().name(),1,Integer::sum);if(value.complete())complete++;}
        report.put(phase+"CoverageStates",counts);report.put(phase+"CoverageCount",snapshot.catalogCoverage().size());report.put(phase+"CompleteCoverageCount",complete);
    }
    /** One bounded read witnesses a persisted header, not an observed receipt ACK. */
    private static void persistedAttemptedHeader(Path root,MetadataSnapshot attempted,Map<String,Object> report)throws Exception{
        Path file=root.resolve("metadata_catalog.sqlite");assertTrue(Files.isRegularFile(file,LinkOption.NOFOLLOW_LINKS));
        report.put("oldWriteReceiptObserved",false);
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+file);var query=db.prepareStatement("SELECT revision,configuration_revision FROM publication WHERE source=?")){
            query.setQueryTimeout(2);query.setMaxRows(2);query.setString(1,attempted.source());
            try(var rows=query.executeQuery()){
                boolean found=rows.next();report.put("cacheHeaderWitness",found?HeaderWitness.DIFFERENT_REVISION:HeaderWitness.MISSING);assertTrue(found,"The controlled cache attempt must leave a persisted header");
                long revision=rows.getLong(1),configuration=rows.getLong(2);report.put("persistedSnapshotRevision",revision);report.put("persistedConfigurationRevision",configuration);
                boolean matches=revision==attempted.revision()&&configuration==attempted.configurationRevision();report.put("cacheHeaderWitness",matches?HeaderWitness.MATCHED_ATTEMPTED_REVISION:HeaderWitness.DIFFERENT_REVISION);
                assertFalse(rows.next());assertEquals(attempted.revision(),revision);assertEquals(attempted.configurationRevision(),configuration);
            }
        }
    }
    static Stream<Arguments> transitions(){
        return Stream.of("creation","removal").flatMap(transition->Stream.of(1,2,3).map(level->Arguments.of(transition,level)));
    }
    private static ThreadInfo pendingNativeWrite(Thread publisher){
        var value=ManagementFactory.getThreadMXBean().getThreadInfo(new long[]{publisher.threadId()},true,true)[0];
        if(value==null)return null;
        boolean step=Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.core.NativeDB")&&frame.getMethodName().equals("step"));
        boolean begin=Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.SQLiteConnection")&&frame.getMethodName().equals("setAutoCommit"))
            &&Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.core.DB")&&frame.getMethodName().equals("exec"));
        return step&&begin?value:null;
    }
    private static MetadataObject relation(MetadataSnapshot snapshot){
        var values=snapshot.resolve("busydata","busydata",ObjectKind.TABLE,"","owned_cache_rows",true);
        assertEquals(1,values.size(),"One physical relation identity must resolve");return values.getFirst();
    }
    private static MetadataSnapshot ownedInventory(Explorer explorer,io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception{
        session.lock.lock();try(var maintenance=explorer.metadata().ownedMaintenance(session)){return explorer.refreshSessionOverlay(session);}finally{session.lock.unlock();}
    }
    @ParameterizedTest(name="{index}: {0}, level {1}") @MethodSource("transitions")
    void ownedCreationAndRemovalFinishBeforeDurableCacheUnlock(String transition,int requested)throws Exception{
        Path evidence=Files.createTempDirectory(Path.of("target"),"maria-owned-cache-").toAbsolutePath();var report=new LinkedHashMap<String,Object>();
        report.put("transition",transition);report.put("level",requested);report.put("engine","MARIADB");
        report.put("scope","Native MariaDB11.8.9 inventory and reviewed CALL; the extra durable cache-write property is synthetic");
        var released=new AtomicBoolean();var releases=new AtomicInteger();var attempts=new AtomicInteger();var callExecutions=new AtomicInteger();
        Throwable problem=null;
        try(var fixture=new EngineFixture(root,"MARIADB");var workers=Executors.newFixedThreadPool(2)){
            var owner=fixture.open();var observer=fixture.open();var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();
            observer.lock.lock();try(var sql=observer.connection.createStatement()){
                sql.execute("CREATE TABLE busydata.owned_cache_rows(persistent_a INTEGER)");
                sql.execute("CREATE PROCEDURE busydata.remove_owned_cache_rows() SQL SECURITY DEFINER BEGIN DROP TEMPORARY TABLE busydata.owned_cache_rows; END");
            }finally{observer.lock.unlock();}
            var current=platform.configuration(owner);
            platform.configure(owner,new MetadataConfiguration(current.revision()+1,Set.of("busydata"),Set.of(),Set.of(),Set.of(),false,Set.of(ObjectKind.TABLE,ObjectKind.COLUMN),List.of(),List.of(),IntrospectionLevel.of(requested),Map.of()));
            fixture.warm(owner,"owned_cache_rows");var initial=platform.capture(owner);var permanent=relation(initial);
            assertTrue(permanent.identity().sessionOwner().isEmpty());report.put("permanentIdentity",permanent.identity().key());
            owner.lock.lock();try(var sql=owner.connection.createStatement()){sql.execute("CREATE TEMPORARY TABLE busydata.owned_cache_rows(temporary_b INTEGER DEFAULT 7)");}finally{owner.lock.unlock();}
            MetadataSnapshot existingOwned=transition.equals("removal")?ownedInventory(explorer,owner):null;
            if(existingOwned!=null)assertEquals(owner.id,relation(existingOwned).identity().sessionOwner());
            var scope=new MetadataScope("busydata","busydata","",ObjectKind.TABLE,"owned_cache_rows",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
            var state=new MetadataCoverage(scope,IntrospectionLevel.of(requested),MetadataState.AVAILABLE,true,"controlled-private-cache-write",observer.revision,observer.contextRevision,System.currentTimeMillis(),"");
            var projected=platform.publishedSnapshot(observer).projection(relation(platform.publishedSnapshot(observer))).toBuilder().putProperties("fixtureCacheWrite","controlled").build();
            var branches=Map.of(scope,new MetadataPlatform.Branch(List.of(projected),state));var rules=platform.publishedSnapshot(observer).rules();long ticket=platform.beginRefresh(observer);
            var publisherDone=new AtomicBoolean();var publisherFailure=new AtomicReference<Throwable>();
            MetadataSnapshot attemptedDurable=null,advancedDurable=null,fencedDurable=null;long abandonedRefreshTicket=-1;
            try(var blocker=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var lock=blocker.createStatement()){
                lock.execute("PRAGMA busy_timeout=5000");lock.execute("BEGIN IMMEDIATE");
                Thread publisher=Thread.ofPlatform().name("owned-maria-cache-publisher").unstarted(()->{
                    attempts.incrementAndGet();try{platform.publish(observer,ticket,rules,branches,false);}catch(Throwable failure){publisherFailure.set(failure);}finally{publisherDone.set(true);}
                });
                var guard=Executors.newSingleThreadScheduledExecutor();Runnable release=()->{
                    if(released.compareAndSet(false,true))try{lock.execute("ROLLBACK");releases.incrementAndGet();}catch(SQLException failure){publisherFailure.compareAndSet(null,failure);}
                };
                var safety=guard.schedule(release,8,TimeUnit.SECONDS);
                MetadataSnapshot capturedTemporary=existingOwned;
                try{
                    publisher.start();long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);ThreadInfo nativeWrite=null;
                    while(System.nanoTime()<deadline&&!released.get()&&!publisherDone.get()){
                        nativeWrite=pendingNativeWrite(publisher);if(nativeWrite!=null)break;LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
                    }
                    report.put("nativeCacheBeginObserved",nativeWrite!=null&&!released.get());
                    assertNotNull(nativeWrite,"The real private SQLite BEGIN must be observed; timing alone is not cache contention proof");
                    assertFalse(released.get());assertFalse(publisherDone.get());assertEquals("WRITE_PENDING",platform.cacheState());
                    assertTrue(Arrays.stream(nativeWrite.getLockedMonitors()).noneMatch(monitor->monitor.getClassName().equals(MetadataPlatform.class.getName()+"$Source")),"Private cache I/O must not hold Source");
                    attemptedDurable=platform.publishedSnapshot(observer);snapshotFacts(report,"attempted",attemptedDurable);
                    long start=System.nanoTime();
                    if(transition.equals("creation")){
                        capturedTemporary=workers.submit(()->ownedInventory(explorer,owner)).get(2,TimeUnit.SECONDS);
                        var temporary=relation(capturedTemporary);report.put("creationIdentity",temporary.identity().key());
                        assertEquals(owner.id,temporary.identity().sessionOwner());assertEquals("true",temporary.properties().get("temporary"));assertNotEquals(permanent.identity().key(),temporary.identity().key());
                        assertEquals(IntrospectionLevel.of(requested),temporary.level());
                        if(requested>1)assertEquals(List.of("temporary_b"),capturedTemporary.namespace("busydata","busydata",ObjectKind.COLUMN,"owned_cache_rows").stream().map(value->value.identity().name()).toList());
                        if(requested==3){assertEquals("AVAILABLE",temporary.properties().get("sourceAvailability"));assertTrue(temporary.source().startsWith("CREATE TEMPORARY TABLE"));}
                        assertFalse(released.get());assertFalse(publisherDone.get());report.put("creationFinishedBeforeCacheUnlock",true);
                    }
                    var held=capturedTemporary;assertNotNull(held);var temporary=relation(held);report.put("temporaryIdentity",temporary.identity().key());
                    var job=workers.submit(()->{callExecutions.incrementAndGet();return fixture.execute(owner,"CALL busydata.remove_owned_cache_rows()");}).get(2,TimeUnit.SECONDS);
                    assertEquals(JobState.COMPLETED,job.state);report.put("foregroundElapsedMs",(System.nanoTime()-start)/1_000_000.0);
                    advancedDurable=platform.publishedSnapshot(observer);snapshotFacts(report,"beforeUnlock",advancedDurable);
                    boolean advanced=advancedDurable.revision()>attemptedDurable.revision();report.put("durableRevisionAdvancedBeforeUnlock",advanced);report.put("cacheStateBeforeUnlock",platform.cacheState());
                    assertTrue(advanced,"Opaque CALL must retire the attempted durable metadata revision while native BEGIN is still blocked");
                    assertFalse(released.get(),"The foreground SQL/owned publication must finish before the private cache lock is released");assertFalse(publisherDone.get());
                    var removed=platform.capture(owner);var restored=relation(removed);
                    report.put("restoredIdentity",restored.identity().key());report.put("restoredSessionOwner",restored.identity().sessionOwner());report.put("resolutionState",removed.sessionResolution().state().name());
                    assertEquals(permanent.identity().key(),restored.identity().key(),()->"Permanent="+permanent.identity()+"; held temporary="+temporary.identity()+"; actual="+restored.identity()+"; cache still pending="+!publisherDone.get());
                    assertTrue(restored.identity().sessionOwner().isEmpty());assertFalse("true".equals(restored.properties().get("temporary")));
                    assertSame(temporary,relation(held),"Held immutable owned snapshots retain their original identity after removal");
                    assertTrue(removed.identities().values().stream().noneMatch(value->value.identity().sessionOwner().equals(owner.id)));
                    assertEquals(permanent.identity().key(),relation(platform.capture(observer)).identity().key());assertTrue(relation(platform.capture(observer)).identity().sessionOwner().isEmpty());
                    assertEquals(1,callExecutions.get());assertEquals(1,fixture.jobs.list(owner.id).size(),"No SQL replay or hidden execution may be introduced");
                    assertThrows(IllegalStateException.class,()->platform.publishTemporaryInventory(owner,ticket,rules,Map.of()),"Owned publication requires its physical session lock");
                    report.put("removalFinishedBeforeCacheUnlock",true);report.put("sqlExecutions",callExecutions.get());report.put("completed",true);
                    // A public explicit request supersedes queued reconciliation;
                    // abandoning it before acquisition issues no JDBC or SQL.
                    // Observe BEGIN again: the manual publisher still owns the
                    // durable writer, so no background publication can win here.
                    var stillBlocked=pendingNativeWrite(publisher);report.put("nativeCacheBeginObservedAtSupersession",stillBlocked!=null);
                    assertNotNull(stillBlocked);assertFalse(released.get());assertFalse(publisherDone.get());
                    var beforeSupersession=platform.publishedSnapshot(observer);
                    try(var abandoned=io.grpc.Context.current().withCancellation()){
                        abandonedRefreshTicket=abandoned.call(()->platform.beginRefresh(observer));abandoned.cancel(null);
                        report.put("explicitRefreshContextCancelled",abandoned.isCancelled());
                    }
                    report.put("abandonedExplicitRefreshTicket",abandonedRefreshTicket);report.put("explicitRefreshAcquisitionStarted",false);report.put("explicitRefreshPublished",false);
                    assertTrue(abandonedRefreshTicket>ticket);assertFalse(released.get());assertFalse(publisherDone.get());
                    fencedDurable=platform.publishedSnapshot(observer);assertSame(beforeSupersession,fencedDurable);snapshotFacts(report,"fenced",fencedDurable);
                }finally{
                    release.run();safety.cancel(false);guard.shutdown();publisher.join(10_000);
                    report.put("cacheUnlocks",releases.get());report.put("durablePublicationAttempts",attempts.get());
                    assertFalse(publisher.isAlive(),"The one durable cache writer must finish after its explicit unlock");
                }
                if(publisherFailure.get()!=null)throw new AssertionError("Controlled durable cache writer failed",publisherFailure.get());
                assertEquals(1,releases.get());assertEquals(1,attempts.get());assertNotNull(attemptedDurable);assertNotNull(advancedDurable);assertNotNull(fencedDurable);
                var afterUnlock=platform.publishedSnapshot(observer);snapshotFacts(report,"afterUnlock",afterUnlock);
                boolean unchanged=afterUnlock==fencedDurable;report.put("durableUnchangedAfterExplicitSupersession",unchanged);assertSame(fencedDurable,afterUnlock,"Superseded background refresh must not publish after the manual cache writer is released");
                assertTrue(afterUnlock.revision()>=advancedDurable.revision());assertTrue(afterUnlock.revision()>attemptedDurable.revision());
                report.put("cacheStateAfterOldPublisher",platform.cacheState());report.put("currentCacheReceiptAvailable",platform.cacheWriteReceipt(observer).isPresent());report.put("currentCacheMetricsAvailable",platform.cacheWriteMetrics(observer).isPresent());
                assertEquals("WRITE_UNAVAILABLE",platform.cacheState(),"Older persistence cannot certify a newer durable metadata revision");
                persistedAttemptedHeader(fixture.metadata.root(),attemptedDurable,report);
            }
            assertTrue(initial.resolve("busydata","busydata",ObjectKind.TABLE,"","owned_cache_rows",true).getFirst().identity().sessionOwner().isEmpty());
        }catch(Throwable failure){problem=failure;report.put("completed",false);report.put("failureType",failure.getClass().getName());throw failure;}
        finally{report.put("failed",problem!=null);Files.writeString(evidence.resolve("result.json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
    }
}
