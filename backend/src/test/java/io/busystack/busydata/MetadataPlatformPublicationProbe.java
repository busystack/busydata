package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.management.*;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.concurrent.locks.LockSupport;

/** Real Platform/SQLite and PostgreSQL owner; catalog contents are explicitly synthetic. */
public final class MetadataPlatformPublicationProbe {
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final ThreadMXBean THREADS=ManagementFactory.getThreadMXBean();
    private static final long PROOF_MS=250,JOB_MS=750;
    private MetadataPlatformPublicationProbe(){}
    private record Setup(Map<MetadataScope,MetadataPlatform.Branch> branches,List<MetadataObject> routines){}
    private static double elapsed(long start){return (System.nanoTime()-start)/1_000_000.0;}
    private static MetadataCoverage coverage(MetadataScope scope,SessionRegistry.Session session,String fingerprint){return new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,fingerprint,session.revision,session.contextRevision,System.currentTimeMillis(),"");}
    private static void require(boolean condition,String reason){if(!condition)throw new AssertionError(reason);}
    private static Setup synthetic(SessionRegistry.Session session){
        var fixture=ProductionMetadataHeapProbe.fixture();String source=session.metadataSourceIdentity,catalog=session.context.catalog();
        var grouped=new LinkedHashMap<ObjectKind,List<MetadataObject>>();var routines=new ArrayList<MetadataObject>();
        for(var object:fixture.identities().values()){
            var i=object.identity();var subtype=i.kind()==ObjectKind.ROUTINE?ObjectSubtype.FUNCTION:i.subtype();var identity=new MetadataIdentity(source,session.profile.getId(),catalog,i.schema(),i.kind(),subtype,i.parent(),i.name(),i.signature(),"",i.nativeKey());
            var properties=object.properties();if(i.kind()==ObjectKind.ROUTINE){var typed=new HashMap<>(properties);typed.put("type","FUNCTION");properties=typed;}if(properties.containsKey("referencedCatalog")){var mapped=new HashMap<>(properties);mapped.put("referencedCatalog",catalog);properties=mapped;}
            var mapped=new MetadataObject(identity,object.displayName(),object.quotedIdentifier(),object.lookupKey(),properties,object.source(),object.level(),object.state(),session.revision,session.contextRevision);
            grouped.computeIfAbsent(i.kind(),ignored->new ArrayList<>()).add(mapped);if(i.kind()==ObjectKind.ROUTINE)routines.add(mapped);
        }
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();
        for(var entry:grouped.entrySet()){var scope=new MetadataScope(catalog,"","",entry.getKey());branches.put(scope,new MetadataPlatform.Branch(List.of(),coverage(scope,session,"synthetic-initial"),entry.getValue(),false));}
        for(var entry:fixture.catalogCoverage().entrySet())if(entry.getKey().kind()==ObjectKind.COLUMN){var s=entry.getKey();var scope=new MetadataScope(catalog,s.schema(),s.parent(),s.kind(),s.search(),s.exactName(),s.signature(),s.subtype());branches.put(scope,MetadataPlatform.Branch.reused(coverage(scope,session,"synthetic-column-coverage")));}
        return new Setup(branches,List.copyOf(routines));
    }
    private static Map<MetadataScope,MetadataPlatform.Branch> points(SessionRegistry.Session session,List<MetadataObject> routines){
        var branches=new LinkedHashMap<MetadataScope,MetadataPlatform.Branch>();var parent=new MetadataScope(session.context.catalog(),"namespace_0","",ObjectKind.ROUTINE);
        branches.put(parent,new MetadataPlatform.Branch(List.of(),coverage(parent,session,"routine-parent"),routines,false));
        for(var object:routines){var i=object.identity();var point=new MetadataScope(i.catalog(),i.schema(),"",ObjectKind.ROUTINE,i.name(),true,i.signature(),i.subtype());branches.put(point,new MetadataPlatform.Branch(List.of(),coverage(point,session,"routine-point"),List.of(object),false));}
        return branches;
    }
    private static void selectOne(EngineFixture fixture,SessionRegistry.Session session)throws Exception{
        var job=fixture.execute(session,"SELECT 1");require(job.state==JobState.COMPLETED,"Read-only control must complete");
        var row=fixture.results.get(job.info().getResults(0).getResultId()).read(0);require("1".equals(io.busystack.busydata.results.Values.text(row.getValues(0))),"Read-only control returned a different scalar");
    }
    private static ThreadInfo nativeSqlite(Thread writer){
        var info=THREADS.getThreadInfo(new long[]{writer.threadId()},true,true)[0];if(info==null)return null;
        boolean nativeStep=Arrays.stream(info.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.core.NativeDB")&&frame.getMethodName().equals("step"));
        boolean statementWrite=Arrays.stream(info.getStackTrace()).anyMatch(frame->frame.getClassName().startsWith("org.sqlite.")&&Set.of("executeUpdate","executeLargeUpdate","executeBatch","executeLargeBatch").contains(frame.getMethodName()));
        // Pinned sqlite-jdbc3.53.4.0 setAutoCommit(false) acquires its configured
        // IMMEDIATE transaction through DB.exec -> NativeDB.step. This is the
        // real transaction write boundary, distinct from header SELECT reads.
        boolean begin=Arrays.stream(info.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.SQLiteConnection")&&frame.getMethodName().equals("setAutoCommit"))
            &&Arrays.stream(info.getStackTrace()).anyMatch(frame->frame.getClassName().equals("org.sqlite.core.DB")&&frame.getMethodName().equals("exec"));
        return nativeStep&&(statementWrite||begin)?info:null;
    }
    private static boolean publicPublication(Thread writer){var info=THREADS.getThreadInfo(writer.threadId(),64);return info!=null&&Arrays.stream(info.getStackTrace()).anyMatch(frame->frame.getClassName().equals(MetadataPlatform.class.getName())&&frame.getMethodName().contains("publish"));}
    private static void awaitPublication(Thread writer,AtomicBoolean done)throws Exception{
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);while(System.nanoTime()<deadline&&!done.get()){if(publicPublication(writer))return;LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));}throw new AssertionError("Actual publication was not observed; concurrent measurement is unavailable");
    }
    private static long timedProof(MetadataPlatform platform,SessionRegistry.Session session){long start=System.nanoTime();var fence=platform.proofFence(session);require(platform.proofAdmissionState(session,fence)==MetadataState.AVAILABLE,"Physical proof admission changed");return System.nanoTime()-start;}
    private static long timedSelect(EngineFixture fixture,SessionRegistry.Session session)throws Exception{long start=System.nanoTime();selectOne(fixture,session);return System.nanoTime()-start;}
    private static void persisted(Path root,long expected,Map<String,Object> report,String phase)throws Exception{
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var query=db.createStatement();var rows=query.executeQuery("SELECT (SELECT COUNT(*) FROM object),(SELECT COUNT(*) FROM publication)")){
            boolean available=rows.next();report.put(phase+"PersistedCountAvailable",available);
            long objects=available?rows.getLong(1):-1,sources=available?rows.getLong(2):-1;report.put(phase+"ActualPersistedObjects",objects);report.put(phase+"ActualPersistedSources",sources);report.put(phase+"ExpectedPersistedObjects",expected);
            require(available&&objects==expected&&sources==1,"Persisted synthetic fixture changed");
        }
    }
    private static void large(EngineFixture fixture,SessionRegistry.Session session,SessionRegistry.Session interactive,Map<String,Object> report)throws Exception{
        var platform=fixture.metadata.metadataPlatform();var setup=synthetic(session);long began=System.nanoTime();var held=platform.publish(session,platform.beginRefresh(session),RULES,setup.branches(),false);
        report.put("initialPublicationMs",elapsed(began));report.put("cacheStateAfterInitialPublication",platform.cacheState());require(held.identities().size()==118000&&setup.routines().size()==3000,"Existing scale fixture changed");
        selectOne(fixture,interactive); // Separate physical owner and explicit warmup execution; the measured request is never retried.
        var branches=points(session,setup.routines());report.put("publicationBranchCount",branches.size());
        var admitted=Collections.newSetFromMap(new IdentityHashMap<MetadataObject,Boolean>());admitted.addAll(setup.routines());var current=platform.publishedSnapshot(session);int certified=0;
        for(var entry:branches.entrySet())if(entry.getKey().exactName()){
            require(entry.getKey().subtype()==ObjectSubtype.FUNCTION&&entry.getValue().normalized().getFirst().identity().subtype()==ObjectSubtype.FUNCTION&&"FUNCTION".equals(entry.getValue().normalized().getFirst().properties().get("type")),"Synthetic native kind must be explicit and consistent");
            require(MetadataPublicationTestAccess.freshRoutinePoint(entry.getKey(),entry.getValue().coverage(),entry.getValue(),current.identities(),admitted,RULES),"Actual production fresh-point prerequisites are not met");certified++;
        }
        require(certified==3000,"All3000 intended typed points must qualify");report.put("productionFastPointPrerequisitesMet",certified);report.put("baselineFixtureDelta","Routine subtype/type is now explicitly FUNCTION; earlier immutable baseline retained unspecified routine kind and measured SELECT1 on the publishing physical session; this regression uses an explicit FUNCTION kind and separate physical interactive session on the same source, and must not be represented as an identical fixture comparison");var done=new AtomicBoolean();var failure=new AtomicReference<Throwable>();var next=new AtomicReference<MetadataSnapshot>();var duration=new AtomicReference<Double>();long ticket=platform.beginRefresh(session);
        Thread publisher=Thread.ofPlatform().name("owned-platform-scale-publisher").unstarted(()->{long start=System.nanoTime();try{next.set(platform.publish(session,ticket,RULES,branches,false));}catch(Throwable problem){failure.set(problem);}finally{duration.set(elapsed(start));done.set(true);}});
        try(var readers=Executors.newFixedThreadPool(2)){
            publisher.start();awaitPublication(publisher,done);report.put("actualPublicPublisherObserved",true);
            var proof=readers.submit(()->timedProof(platform,interactive));var sql=readers.submit(()->timedSelect(fixture,interactive));
            long proofNanos=proof.get(PROOF_MS,TimeUnit.MILLISECONDS),sqlNanos=sql.get(JOB_MS,TimeUnit.MILLISECONDS);
            report.put("proofMs",proofNanos/1_000_000.0);report.put("actualJobsSelect1Ms",sqlNanos/1_000_000.0);require(proofNanos<=TimeUnit.MILLISECONDS.toNanos(PROOF_MS),"Proof admission exceeded interactive budget");require(sqlNanos<=TimeUnit.MILLISECONDS.toNanos(JOB_MS),"Read-only job exceeded interactive budget");
        }finally{publisher.join(TimeUnit.SECONDS.toMillis(120));require(!publisher.isAlive(),"Owned publisher exceeded deadline");}
        report.put("pointPublicationMs",duration.get());report.put("cacheStateAfterPointPublication",platform.cacheState());
        if(failure.get()!=null)throw new AssertionError("Actual scale publication failed",failure.get());
        var published=next.get();report.put("actualPublishedObjectCount",published==null?-1:published.identities().size());require(published!=null&&published.identities().size()==118000,"Publication lost synthetic identities");int reused=0;for(var item:setup.routines())if(published.identities().get(item.identity().key())==item)reused++;
        require(reused==3000,"Unchanged routines must retain the same model objects");require(held.identities().size()==118000&&held.revision()<published.revision(),"Captured old snapshot changed");persisted(fixture.metadata.root(),118000,report,"afterPoint");
        report.put("pointPublicationMs",duration.get());report.put("syntheticObjects",published.identities().size());report.put("sameRoutineReferences",reused);report.put("persistedObjects",118000);
    }
    private static void cache(EngineFixture fixture,SessionRegistry.Session session,SessionRegistry.Session interactive,Map<String,Object> report)throws Exception{
        var platform=fixture.metadata.metadataPlatform();var scope=new MetadataScope(session.context.catalog(),"synthetic_scope","",ObjectKind.TABLE);
        var object=SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog(session.context.catalog()).setSchema("synthetic_scope").setName("synthetic_table").putProperties("nativeId","1").build();
        platform.publish(session,platform.beginRefresh(session),RULES,Map.of(scope,new MetadataPlatform.Branch(List.of(object),coverage(scope,session,"initial"))),false);selectOne(fixture,interactive);
        var branch=new MetadataPlatform.Branch(List.of(object.toBuilder().putProperties("remarks","changed synthetic fixture").build()),coverage(scope,session,"changed"));long ticket=platform.beginRefresh(session);var done=new AtomicBoolean();var failure=new AtomicReference<Throwable>();var releaseCount=new AtomicInteger();var released=new AtomicBoolean();var timeline=new ArrayList<Map<String,Object>>();report.put("timeline",timeline);
        try(var blocker=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var lock=blocker.createStatement();var readers=Executors.newFixedThreadPool(2)){
            lock.execute("PRAGMA busy_timeout=5000");lock.execute("BEGIN IMMEDIATE");long began=System.nanoTime();timeline.add(Map.of("event","OWN_WRITE_LOCK_HELD","ms",0));
            Thread publisher=Thread.ofPlatform().name("owned-cache-publisher").unstarted(()->{try{platform.publish(session,ticket,RULES,Map.of(scope,branch),false);}catch(Throwable problem){failure.set(problem);}finally{done.set(true);}});
            ScheduledExecutorService guard=Executors.newSingleThreadScheduledExecutor();Runnable release=()->{if(released.compareAndSet(false,true))try{lock.execute("ROLLBACK");releaseCount.incrementAndGet();}catch(SQLException problem){failure.compareAndSet(null,problem);}};var safety=guard.schedule(release,3,TimeUnit.SECONDS);
            try{
                publisher.start();ThreadInfo sqlite=null;long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
                while(System.nanoTime()<deadline&&!released.get()&&!done.get()){sqlite=nativeSqlite(publisher);if(sqlite!=null)break;LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));}
                report.put("nativeCacheWriteObserved",sqlite!=null&&!released.get());report.put("cacheWriterDoneAtEntryCheck",done.get());report.put("cacheStateAtEntryCheck",platform.cacheState());
                require(sqlite!=null&&!released.get(),"Native cache write not observed under owned lock; no negative inference is valid");timeline.add(Map.of("event","PUBLISHER_NATIVE_SQLITE_WRITE_PENDING","ms",elapsed(began)));
                require(platform.cacheState().equals("WRITE_PENDING"),"Cache state must expose the pending rebuildable write");report.put("cacheStateWhileBlocked",platform.cacheState());
                require(Arrays.stream(sqlite.getLockedMonitors()).noneMatch(monitor->monitor.getClassName().equals(MetadataPlatform.class.getName()+"$Source")),"Cache I/O must not hold the Source monitor");
                var proof=readers.submit(()->timedProof(platform,interactive));var sql=readers.submit(()->timedSelect(fixture,interactive));
                long proofNanos=proof.get(PROOF_MS,TimeUnit.MILLISECONDS),sqlNanos=sql.get(JOB_MS,TimeUnit.MILLISECONDS);
                require(!released.get()&&!done.get(),"Proof/job must finish while cache write is still blocked");timeline.add(Map.of("event","PROOF_AND_JOB_COMPLETED_BEFORE_WRITE_UNLOCK","ms",elapsed(began)));
                require(proofNanos<=TimeUnit.MILLISECONDS.toNanos(PROOF_MS),"Proof admission exceeded interactive budget");require(sqlNanos<=TimeUnit.MILLISECONDS.toNanos(JOB_MS),"Read-only job exceeded interactive budget");
                report.put("proofMs",proofNanos/1_000_000.0);report.put("actualJobsSelect1Ms",sqlNanos/1_000_000.0);report.put("cacheWriterPendingAtInteractiveCompletion",!done.get());
            }finally{release.run();safety.cancel(false);guard.shutdown();timeline.add(Map.of("event","OWN_WRITE_LOCK_RELEASED","ms",elapsed(began)));report.put("writeLockHeldMs",elapsed(began));report.put("writeLockReleaseCount",releaseCount.get());publisher.join(10_000);require(!publisher.isAlive(),"Owned cache publisher did not finish after release");}
            require(releaseCount.get()==1,"The one owned write lock must be released exactly once");if(failure.get()!=null)throw new AssertionError("Cache publication failed",failure.get());
        }
        require(platform.cacheState().equals("AVAILABLE"),"Successful cache completion must clear pending state");report.put("cacheStateAfterCompletion",platform.cacheState());
        var values=platform.publishedSnapshot(session).select(scope);require(values.size()==1&&"changed synthetic fixture".equals(values.getFirst().properties().get("remarks")),"Committed memory publication changed after cache completion");persisted(fixture.metadata.root(),1,report,"measuredSuccess");report.put("persistedObjectsAfterMeasuredSuccess",1);
        cancelCacheAndRepair(fixture,session,scope,object,report);
    }

    private static Set<String> persistedNames(Path root)throws Exception{
        var names=new LinkedHashSet<String>();
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));var query=db.createStatement();var rows=query.executeQuery("SELECT name FROM object ORDER BY name LIMIT 4")){
            while(rows.next())names.add(rows.getString(1));
        }
        return Set.copyOf(names);
    }
    private static void cancelCacheAndRepair(EngineFixture fixture,SessionRegistry.Session session,MetadataScope scope,SchemaObject old,Map<String,Object> report)throws Exception{
        var platform=fixture.metadata.metadataPlatform();var phase=new LinkedHashMap<String,Object>();report.put("cancelledCacheThenNewPublication",phase);var timeline=new ArrayList<Map<String,Object>>();phase.put("timeline",timeline);
        var memoryOnly=old.toBuilder().setName("memory_only_after_cancel").putProperties("nativeId","2").build();var branch=new MetadataPlatform.Branch(List.of(memoryOnly),coverage(scope,session,"memory-commit-cache-cancel"));long ticket=platform.beginRefresh(session);
        var cancelled=io.grpc.Context.current().withCancellation();var done=new AtomicBoolean();var failure=new AtomicReference<Throwable>();var released=new AtomicBoolean();var releaseCount=new AtomicInteger();var attempts=new AtomicInteger();long previousRevision=platform.publishedSnapshot(session).revision();
        try(var blocker=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var lock=blocker.createStatement()){
            lock.execute("PRAGMA busy_timeout=5000");lock.execute("BEGIN IMMEDIATE");long began=System.nanoTime();timeline.add(Map.of("event","OWN_CANCEL_PHASE_WRITE_LOCK_HELD","ms",0));
            Thread publisher=Thread.ofPlatform().name("owned-cache-cancel-after-memory-commit").unstarted(cancelled.wrap(()->{attempts.incrementAndGet();try{platform.publish(session,ticket,RULES,Map.of(scope,branch),false);}catch(Throwable problem){failure.set(problem);}finally{done.set(true);}}));
            ScheduledExecutorService guard=Executors.newSingleThreadScheduledExecutor();Runnable release=()->{if(released.compareAndSet(false,true))try{lock.execute("ROLLBACK");releaseCount.incrementAndGet();}catch(SQLException problem){failure.compareAndSet(null,problem);}};var safety=guard.schedule(release,3,TimeUnit.SECONDS);
            try{
                publisher.start();ThreadInfo sqlite=null;long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
                while(System.nanoTime()<deadline&&!released.get()&&!done.get()){sqlite=nativeSqlite(publisher);if(sqlite!=null)break;LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));}
                phase.put("nativeCacheWriteObserved",sqlite!=null&&!released.get());phase.put("cacheWriterDoneAtEntryCheck",done.get());phase.put("cacheStateAtEntryCheck",platform.cacheState());
                require(sqlite!=null&&!released.get(),"Cancellation phase requires observed pending native cache write");
                require(Arrays.stream(sqlite.getLockedMonitors()).noneMatch(monitor->monitor.getClassName().equals(MetadataPlatform.class.getName()+"$Source")),"Pending canceled cache I/O must not hold Source");
                var committed=platform.publishedSnapshot(session);require(committed.revision()>previousRevision&&committed.complete(scope,IntrospectionLevel.STRUCTURE)&&committed.select(scope).size()==1&&committed.select(scope).getFirst().identity().name().equals("memory_only_after_cancel"),"Memory commit must be observed before cache cancellation");
                require(platform.cacheState().equals("WRITE_PENDING"),"The owned cache attempt must still be pending");timeline.add(Map.of("event","NATIVE_WRITE_PENDING_AND_MEMORY_COMMITTED","ms",elapsed(began)));
                cancelled.cancel(null);timeline.add(Map.of("event","OWN_REQUEST_CANCELLED_AFTER_MEMORY_COMMIT","ms",elapsed(began)));publisher.join(500);
                require(done.get()&&!publisher.isAlive()&&!released.get(),"Owned cache cancellation must return before the write lock is released");
                if(failure.get()!=null)throw new AssertionError("Rebuildable cache cancellation cannot undo committed memory",failure.get());
                require(platform.cacheState().equals("WRITE_UNAVAILABLE"),"Canceled cache persistence must be explicit");require(platform.publishedSnapshot(session)==committed,"Cache cancellation must not replace or invalidate committed memory");
                require(persistedNames(fixture.metadata.root()).equals(Set.of("synthetic_table")),"Canceled transaction must leave only the previous persisted rows");timeline.add(Map.of("event","COMMITTED_MEMORY_RETAINED_CACHE_WRITE_UNAVAILABLE","ms",elapsed(began)));phase.put("cacheStateAfterCancellation",platform.cacheState());phase.put("memoryRevisionAfterCancellation",committed.revision());phase.put("cancelledPublicationExecutions",attempts.get());
            }finally{release.run();safety.cancel(false);guard.shutdown();timeline.add(Map.of("event","OWN_CANCEL_PHASE_WRITE_LOCK_RELEASED","ms",elapsed(began)));phase.put("writeLockHeldMs",elapsed(began));phase.put("writeLockReleaseCount",releaseCount.get());publisher.join(10_000);cancelled.close();require(!publisher.isAlive(),"Owned canceled cache publisher did not finish");}
            require(releaseCount.get()==1&&attempts.get()==1,"Cancellation phase owns one publication and one lock release");
        }
        var added=old.toBuilder().setName("later_new_publication").putProperties("nativeId","3").build();var repair=new MetadataPlatform.Branch(List.of(memoryOnly,added),coverage(scope,session,"later-new-publication"));
        platform.publish(session,platform.beginRefresh(session),RULES,Map.of(scope,repair),false);
        var expected=Set.of("memory_only_after_cancel","later_new_publication");require(platform.publishedSnapshot(session).select(scope).stream().map(value->value.identity().name()).collect(java.util.stream.Collectors.toSet()).equals(expected),"New publication changed authoritative memory");
        require(persistedNames(fixture.metadata.root()).equals(expected),"New publication must repair missing memory-only rows and remove old persisted phantoms");require(platform.cacheState().equals("AVAILABLE"),"Successful replacement must clear failed cache state");persisted(fixture.metadata.root(),2,phase,"afterRepair");
        phase.put("laterNewPublicationExecutions",1);phase.put("cacheStateAfterRepair",platform.cacheState());phase.put("exactPersistedObjectCountAfterRepair",2);phase.put("sqlReplayed",false);
    }
    public static void main(String[] args)throws Exception{
        Path out=Path.of(args[0]);String mode=args[1];require(Set.of("large","cache").contains(mode),"Unknown publication probe mode");Files.createDirectories(out);
        var report=new LinkedHashMap<String,Object>();report.put("mode",mode);report.put("scope","Synthetic metadata via actual Platform/SQLite plus genuine PostgreSQL read-only Jobs controls; not live native catalog acceptance");report.put("java",System.getProperty("java.runtime.version"));report.put("vmArgs",ManagementFactory.getRuntimeMXBean().getInputArguments());report.put("maxHeapBytes",Runtime.getRuntime().maxMemory());report.put("processors",Runtime.getRuntime().availableProcessors());report.put("proofBudgetMs",PROOF_MS);report.put("jobBudgetMs",JOB_MS);
        var peak=new AtomicLong();var sampler=Executors.newSingleThreadScheduledExecutor();sampler.scheduleAtFixedRate(()->peak.accumulateAndGet(ManagementFactory.getMemoryMXBean().getHeapMemoryUsage().getUsed(),Math::max),0,10,TimeUnit.MILLISECONDS);EngineFixture fixture=null;boolean cleaned=false;Throwable failure=null;
        try{require(Runtime.getRuntime().maxMemory()<=128L*1024*1024,"Probe requires the unchanged production heap");fixture=new EngineFixture(out.resolve("fixture"),"POSTGRESQL");var session=fixture.open();var interactive=fixture.open();require(!session.id.equals(interactive.id)&&session.metadataSourceIdentity.equals(interactive.metadataSourceIdentity),"Interactive control must own a distinct physical session on the same source");report.put("separatePhysicalInteractiveOwnerOnSameSource",true);if(mode.equals("large"))large(fixture,session,interactive,report);else cache(fixture,session,interactive,report);report.put("completed",true);}
        catch(Throwable problem){
            failure=problem;report.put("completed",false);report.put("failureType",problem.getClass().getName());
            report.put("failureFrames",Arrays.stream(problem.getStackTrace()).limit(16).map(frame->Map.of("class",frame.getClassName(),"method",frame.getMethodName(),"file",Objects.toString(frame.getFileName(),""),"line",frame.getLineNumber())).toList());
            var causes=new ArrayList<Map<String,Object>>();var seen=Collections.newSetFromMap(new IdentityHashMap<Throwable,Boolean>());
            for(var cause=problem;cause!=null&&causes.size()<8&&seen.add(cause);cause=cause.getCause()){var item=new LinkedHashMap<String,Object>();item.put("type",cause.getClass().getName());if(cause instanceof SQLException sql){item.put("sqlState",Objects.toString(sql.getSQLState(),""));item.put("vendorCode",sql.getErrorCode());}causes.add(item);}report.put("causes",causes);
        }
        finally{if(fixture!=null)try{fixture.close();cleaned=true;}catch(Throwable problem){report.put("cleanupFailureType",problem.getClass().getName());if(failure==null)failure=problem;}sampler.shutdownNow();report.put("cleanupConfirmed",cleaned);report.put("peakUsedHeapBytes",peak.get());Files.writeString(out.resolve("result.json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
        if(failure!=null||!cleaned)System.exit(1);
    }
}
