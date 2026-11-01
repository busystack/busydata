package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.management.*;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.concurrent.locks.LockSupport;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real-engine review against request-owned central metadata; no edit is applied. */
class ReviewedInspectionIsolationIT {
    private static final String TABLE="inspection_rows";
    @TempDir Path root;

    private static ThreadInfo pendingNativeWrite(Thread publisher){
        var value=ManagementFactory.getThreadMXBean().getThreadInfo(new long[]{publisher.threadId()},true,true)[0];
        if(value==null)return null;
        boolean step=Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.core.NativeDB")&&frame.getMethodName().equals("step"));
        boolean begin=Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.SQLiteConnection")&&frame.getMethodName().equals("setAutoCommit"))
            &&Arrays.stream(value.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.core.DB")&&frame.getMethodName().equals("exec"));
        return step&&begin?value:null;
    }
    private static MetadataObject relation(MetadataSnapshot snapshot,EngineFixture fixture){
        var found=snapshot.resolve("busydata",fixture.schema(),ObjectKind.TABLE,"",TABLE,true);
        assertEquals(1,found.size());assertTrue(found.getFirst().identity().sessionOwner().isEmpty());
        return found.getFirst();
    }
    private static void seed(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        owner.lock.lock();try(var statement=owner.connection.createStatement()){
            statement.execute("CREATE TABLE "+owner.adapter.table("busydata",fixture.schema(),TABLE)+"(id INTEGER PRIMARY KEY,n INTEGER NOT NULL DEFAULT 7)");
            statement.execute("INSERT INTO "+owner.adapter.table("busydata",fixture.schema(),TABLE)+"(id) VALUES(1)");
        }finally{owner.lock.unlock();}
        fixture.warm(owner,TABLE);
    }
    private static ChangeRequest changes(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        var query=fixture.execute(owner,"SELECT id,n FROM "+owner.adapter.table("busydata",fixture.schema(),TABLE));
        var retained=fixture.results.get(query.info().getResults(0).getResultId());
        assertTrue(retained.metadataProof().available());
        return ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(retained.id)
            .setCatalog("busydata").setSchema(fixture.schema()).setTable(TABLE)
            .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0)
                .putValues(2,Assignments.value(Value.newBuilder().setSignedInteger("99").build()))).build();
    }
    private static TableStructure nativeStructure(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        owner.lock.lock();try{return fixture.metadata.metadataPlatform().readTableStructure(owner,"busydata",fixture.schema(),TABLE);}
        finally{owner.lock.unlock();}
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void reviewFinishesBeforeObservedPrivateCacheUnlockWithoutPublishingOrMutation(String engine)throws Exception{
        Path evidence=Files.createTempDirectory(Path.of("target"),"reviewed-inspection-cache-").toAbsolutePath();
        var report=new LinkedHashMap<String,Object>();report.put("engine",engine);
        report.put("scope","Real engine and retained provenance; synthetic property forces one observed private SQLite cache write; foreground is one review, no Apply");
        var released=new AtomicBoolean();var unlocks=new AtomicInteger();var publications=new AtomicInteger();var reviewCalls=new AtomicInteger();
        Throwable problem=null;
        try(var fixture=new EngineFixture(root,engine);var worker=Executors.newSingleThreadExecutor()){
            var owner=fixture.open();var observer=fixture.open();seed(fixture,owner);
            var request=changes(fixture,owner);var platform=fixture.metadata.metadataPlatform();var planner=new ChangePlanner(fixture.safety,fixture.results,platform);
            var originalProof=fixture.results.get(request.getResultId()).metadataProof();var permanent=relation(platform.capture(owner),fixture);
            int jobs=fixture.jobs.list(owner.id).size(),overlays=platform.sessionOverlayCount(),witnesses=PreparedMetadataWitness.retainedForSession(owner.id);
            long revision=owner.revision,context=owner.contextRevision;
            var scope=new MetadataScope("busydata",fixture.schema(),"",ObjectKind.TABLE,TABLE,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
            var state=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"one-controlled-private-cache-write",observer.revision,observer.contextRevision,System.currentTimeMillis(),"");
            var projected=platform.publishedSnapshot(observer).projection(relation(platform.publishedSnapshot(observer),fixture)).toBuilder().putProperties("fixtureCacheWrite","controlled").build();
            var branches=Map.of(scope,new MetadataPlatform.Branch(List.of(projected),state));var rules=platform.publishedSnapshot(observer).rules();long ticket=platform.beginRefresh(observer);
            var publisherDone=new AtomicBoolean();var publisherFailure=new AtomicReference<Throwable>();
            try(var blocker=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var lock=blocker.createStatement()){
                lock.execute("PRAGMA busy_timeout=5000");lock.execute("BEGIN IMMEDIATE");
                Thread publisher=Thread.ofPlatform().name("reviewed-inspection-cache-publisher").unstarted(()->{
                    publications.incrementAndGet();try{platform.publish(observer,ticket,rules,branches,false);}catch(Throwable failure){publisherFailure.set(failure);}finally{publisherDone.set(true);}
                });
                var guard=Executors.newSingleThreadScheduledExecutor();Runnable release=()->{
                    if(released.compareAndSet(false,true))try{lock.execute("ROLLBACK");unlocks.incrementAndGet();}catch(SQLException failure){publisherFailure.compareAndSet(null,failure);}
                };
                var safety=guard.schedule(release,8,TimeUnit.SECONDS);
                try{
                    publisher.start();long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);ThreadInfo nativeWrite=null;
                    while(System.nanoTime()<deadline&&!released.get()&&!publisherDone.get()){
                        nativeWrite=pendingNativeWrite(publisher);if(nativeWrite!=null)break;LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
                    }
                    assertNotNull(nativeWrite,"Observe the real SQLite BEGIN/NativeDB.step; timing alone does not prove cache contention");
                    assertFalse(released.get());assertFalse(publisherDone.get());assertEquals("WRITE_PENDING",platform.cacheState());
                    assertTrue(Arrays.stream(nativeWrite.getLockedMonitors()).noneMatch(monitor->monitor.getClassName().equals(MetadataPlatform.class.getName()+"$Source")));
                    var durable=platform.publishedSnapshot(owner);long started=System.nanoTime();
                    var plan=worker.submit(()->{reviewCalls.incrementAndGet();return planner.preview(owner,request);}).get(2,TimeUnit.SECONDS);
                    assertEquals(1,plan.getChangesCount());assertFalse(plan.getPlanId().isEmpty());
                    report.put("reviewElapsedMs",(System.nanoTime()-started)/1_000_000.0);
                    assertFalse(released.get(),"Review must finish while the exact private cache writer is still blocked");assertFalse(publisherDone.get());
                    assertSame(durable,platform.publishedSnapshot(owner),"A request-owned inspection must not publish into durable metadata");
                    assertEquals(permanent.identity().key(),relation(platform.capture(owner),fixture).identity().key());
                    assertEquals(permanent.identity().key(),relation(platform.capture(observer),fixture).identity().key());
                    assertEquals(overlays,platform.sessionOverlayCount(),"Review must not leave an ordinary session overlay");
                    assertEquals(witnesses,PreparedMetadataWitness.retainedForSession(owner.id),"Review must not create a retained observer");
                    assertEquals(originalProof,fixture.results.get(request.getResultId()).metadataProof());
                    assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);
                    assertEquals(jobs,fixture.jobs.list(owner.id).size(),"Review never creates or replays an execution");assertEquals(1,reviewCalls.get());
                    assertEquals(io.busystack.busydata.rpc.WorkbenchFailure.Reason.MALFORMED_REQUEST,assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->planner.preview(owner,request.toBuilder().setTable("forged_target").build()),"Retained provenance is checked before native inspection").reason());
                    assertSame(durable,platform.publishedSnapshot(owner));assertEquals(jobs,fixture.jobs.list(owner.id).size());
                    fixture.safety.discard(plan.getPlanId());
                    report.put("nativeCacheBeginObserved",true);report.put("reviewFinishedBeforeCacheUnlock",true);report.put("permanentIdentity",permanent.identity().key());
                }finally{
                    release.run();safety.cancel(false);guard.shutdown();publisher.join(10_000);
                    assertFalse(publisher.isAlive(),"The one cache writer must finish after its explicit unlock");
                }
                if(publisherFailure.get()!=null)throw new AssertionError("Controlled durable writer failed",publisherFailure.get());
                assertEquals(1,unlocks.get());assertEquals(1,publications.get());assertEquals("AVAILABLE",platform.cacheState());
            }
            EditingIT.assertRows(owner,"SELECT id,n FROM "+owner.adapter.table("busydata",fixture.schema(),TABLE),new int[][]{{1,7}});
            assertEquals(jobs,fixture.jobs.list(owner.id).size());report.put("completed",true);
        }catch(Throwable failure){problem=failure;report.put("completed",false);report.put("failureType",failure.getClass().getName());throw failure;}
        finally{report.put("failed",problem!=null);report.put("reviewCalls",reviewCalls.get());report.put("durablePublicationAttempts",publications.get());report.put("cacheUnlocks",unlocks.get());Files.writeString(evidence.resolve("result.json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void externalColumnDefaultChangeCannotCompareRetainedProofOnlyToCachedProof(String engine)throws Exception{
        externalColumnChangeRejectsReviewAndPreservesDraft(engine,false);
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void externalDropAndAddColumnCannotReuseOldRetainedIdentity(String engine)throws Exception{
        externalColumnChangeRejectsReviewAndPreservesDraft(engine,true);
    }
    private void externalColumnChangeRejectsReviewAndPreservesDraft(String engine,boolean replace)throws Exception{
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var external=fixture.open();seed(fixture,owner);
            var request=changes(fixture,owner);var platform=fixture.metadata.metadataPlatform();var planner=new ChangePlanner(fixture.safety,fixture.results,platform);
            var drafts=new EditDrafts(fixture.metadata,fixture.results,planner);
            var saved=drafts.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(owner.id).setDocumentId("retained-intent").setChanges(request).build());
            String draft=saved.getDrafts(0).getDraftId();var original=fixture.metadata.editDraft(draft).data();byte[] originalBytes=original.toByteArray();
            var retained=fixture.results.get(request.getResultId());var proof=retained.metadataProof();assertTrue(proof.available());
            var cached=platform.capture(owner);var before=nativeStructure(fixture,owner);int jobs=fixture.jobs.list(owner.id).size(),overlays=platform.sessionOverlayCount(),witnesses=PreparedMetadataWitness.retainedForSession(owner.id);
            String table=external.adapter.table("busydata",fixture.schema(),TABLE);
            external.lock.lock();try(var statement=external.connection.createStatement()){
                if(replace){statement.execute("ALTER TABLE "+table+" DROP COLUMN n");statement.execute("ALTER TABLE "+table+" ADD COLUMN n INTEGER NOT NULL DEFAULT 7");}
                else statement.execute("ALTER TABLE "+table+" ALTER COLUMN n SET DEFAULT 9");
            }finally{external.lock.unlock();}
            var current=nativeStructure(fixture,owner);
            if(fixture.engine!=Engine.MARIADB||!replace)assertNotEquals(before.signature(),current.signature(),"This native metadata change must be exposed by the adapter");
            // MariaDB can expose the same dictionary generation/signature after
            // same-definition DROP+ADD. Its retained prepared witness must still
            // reject that lifetime replacement before approval; never fabricate
            // a column-lifetime identity which the server does not expose.
            if(fixture.engine==Engine.POSTGRESQL)assertEquals(before.nativeGeneration(),current.nativeGeneration(),"PostgreSQL oid:filenode stays unchanged; checking only table generation cannot reject this stale column proof");
            assertSame(cached,platform.capture(owner),"Raw external DDL does not run Smart refresh or change the cached proof");
            assertTrue(proof.samePhysicalStructure(RetainedMetadataProof.capture(cached,retained.columns,owner.targetProfile(),owner.id,owner.context)),"A cached-to-cached comparison is deliberately insufficient in this fixture");
            var failure=assertThrows(WorkbenchFailure.class,()->planner.preview(owner,request));assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());
            assertTrue((fixture.engine==Engine.MARIADB&&replace?Set.of(WorkbenchFailure.Origin.RETAINED_PROOF,WorkbenchFailure.Origin.NATIVE_WITNESS):Set.of(WorkbenchFailure.Origin.RETAINED_PROOF)).contains(failure.origin()));
            assertArrayEquals(originalBytes,fixture.metadata.editDraft(draft).data().toByteArray());assertEquals("STAGED",fixture.metadata.editDraft(draft).state());
            assertEquals(original,fixture.metadata.editDraft(draft).data());assertEquals(jobs,fixture.jobs.list(owner.id).size(),"Failed review must not execute, retry or replay SQL");
            assertSame(cached,platform.capture(owner));assertEquals(overlays,platform.sessionOverlayCount());assertEquals(witnesses,PreparedMetadataWitness.retainedForSession(owner.id));
            assertEquals("7",retained.read(0).getValues(1).getSignedInteger());
            EditingIT.assertRows(owner,"SELECT id,n FROM "+table,new int[][]{{1,7}});
        }
    }
}
