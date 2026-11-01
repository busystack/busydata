package io.busystack.busydata;

import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.rpc.WorkbenchService;
import io.busystack.busydata.schema.ChangePlanner;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.sessions.SessionRegistry;
import io.grpc.stub.StreamObserver;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Actual official clients and engine locks; metadata is never supplied by a fake peer. */
class NativeRestoreMetadataIT {
    @TempDir Path root;
    private static final String WARM="restore_warm", TEMP="restore_owned_temp";
    private static final long LOCK=714143L;
    private static final String LOCK_NAME="busydata_native_restore_metadata";
    @FunctionalInterface private interface Observation {boolean complete()throws Exception;}
    /** Poll read-only acknowledgements; never rerun a native client or mutating SQL. */
    private static void await(Observation observation,String purpose)throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(15);
        while(System.nanoTime()<deadline){if(observation.complete())return;Thread.sleep(20);}
        fail(purpose);
    }
    private static final class Reply<T> implements StreamObserver<T> {
        T value;Throwable failure;
        public void onNext(T next){value=next;}
        public void onError(Throwable error){failure=error;}
        public void onCompleted(){}
    }
    private static Context context(WorkbenchService service){return Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId(UUID.randomUUID().toString()).build();}
    private static WorkbenchService service(EngineFixture fixture){return new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});}
    private static Path tool(EngineFixture fixture,boolean dump){
        Path directory=Path.of(System.getProperty("busydata.native.tools.root",Path.of(System.getProperty("basedir")).resolve("target/native-tools").toString())).resolve(fixture.engine.name().toLowerCase(Locale.ROOT));
        if(Files.isDirectory(directory.resolve("bin")))directory=directory.resolve("bin");
        String name=fixture.engine==Engine.POSTGRESQL?(dump?"pg_dump":"psql"):fixture.engine==Engine.MYSQL?(dump?"mysqldump":"mysql"):(dump?"mariadb-dump":"mariadb");
        Path selected=directory.resolve(name);
        assertTrue(Files.isExecutable(selected),"Prepare the real official native fixture tools before this required gate; no tool-unavailable skip");return selected;
    }
    private static Jobs.Job nativeJob(EngineFixture fixture,WorkbenchService service,SessionRegistry.Session owner,Path file,boolean dump){
        var request=ToolRequest.newBuilder().setContext(context(service)).setSessionId(owner.id).setExecutionId(UUID.randomUUID().toString()).setKind(dump?ToolKind.DUMP:ToolKind.RESTORE).setPath(file.toString()).setNativeToolPath(tool(fixture,dump).toString()).build();
        var review=new Reply<Approval>();service.reviewTool(request,review);assertNull(review.failure,"The selected fixture native request must pass the real review path");assertNotNull(review.value);
        var reply=new Reply<JobInfo>();service.tool(request.toBuilder().setContext(context(service)).setApprovalToken(review.value.getToken()).build(),reply);assertNull(reply.failure,"The once-reviewed native request must submit exactly once");assertNotNull(reply.value);
        return fixture.jobs.get(reply.value.getJobId());
    }
    private static JobInfo finished(Jobs.Job job)throws Exception{return job.finished.get(60,TimeUnit.SECONDS);}
    private static void completed(Jobs.Job job)throws Exception {
        var outcome=finished(job);assertEquals(JobState.COMPLETED,outcome.getState(),"Native fixture state="+outcome.getState()+" code="+outcome.getErrorCode());
    }
    private static String table(SessionRegistry.Session owner,EngineFixture fixture,String name){return owner.adapter.table("busydata",fixture.schema(),name);}
    private static void sql(SessionRegistry.Session owner,String text)throws Exception {
        owner.lock.lock();try(var command=owner.connection.createStatement()){command.setQueryTimeout(5);command.execute(text);owner.refresh();owner.advanceRevision();}finally{owner.lock.unlock();}
    }
    private static int count(SessionRegistry.Session observer,String table)throws Exception {
        observer.lock.lock();try(var command=observer.connection.createStatement()){command.setQueryTimeout(2);try(var rows=command.executeQuery("SELECT COUNT(*) FROM "+table)){assertTrue(rows.next());return rows.getInt(1);}}finally{observer.lock.unlock();}
    }
    private static MetadataScope columns(EngineFixture fixture,String name){return new MetadataScope("busydata",fixture.schema(),name,ObjectKind.COLUMN);}
    private static MetadataScope pendingScope(EngineFixture fixture){return new MetadataScope("busydata",fixture.schema(),"",ObjectKind.TABLE,"console_pending",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);}
    /** Acquire actual uncommitted names on their physical owner. Ordinary DDL
     * acknowledgement queues effects; it does not invent persistent objects. */
    private static MetadataObject capturePendingOverlay(EngineFixture fixture,SessionRegistry.Session owner)throws Exception {
        var platform=fixture.metadata.metadataPlatform();var explorer=new Explorer(platform);var scope=pendingScope(fixture);
        owner.lock.lock();try{
            assertEquals(TransactionState.ACTIVE,owner.state);long ticket=platform.beginRefresh(owner);
            var request=ExploreRequest.newBuilder().setCatalog(scope.catalog()).setSchema(scope.schema()).setKind(ObjectKind.TABLE).setSearch(scope.search()).setExactName(true).setIntrospectionLevel(IntrospectionLevel.NAMES.number()).setLimit(500).build();
            var scan=explorer.scanBranch(owner,request);var values=explorer.fetchBranch(owner,request,System.nanoTime()+TimeUnit.SECONDS.toNanos(10));
            assertEquals(1,values.size());assertEquals("console_pending",values.getFirst().getName());
            var coverage=new MetadataCoverage(scope,IntrospectionLevel.NAMES,MetadataState.AVAILABLE,true,scan.fingerprint(),owner.revision,owner.contextRevision,System.currentTimeMillis(),"");
            var snapshot=platform.publish(owner,ticket,platform.capture(owner).rules(),Map.of(scope,new MetadataPlatform.Branch(values,coverage)),true);
            var captured=snapshot.resolve(scope.catalog(),scope.schema(),ObjectKind.TABLE,"",scope.search(),true);assertEquals(1,captured.size());assertTrue(snapshot.complete(scope,IntrospectionLevel.NAMES));
            assertTrue(captured.getFirst().identity().sessionOwner().isEmpty(),"Persistent identity does not become a temporary identity when its coverage is owned by a session");return captured.getFirst();
        }finally{owner.lock.unlock();}
    }
    private static boolean pendingVisible(SessionRegistry.Session owner)throws Exception {
        owner.lock.lock();try(var command=owner.connection.createStatement()){command.setQueryTimeout(2);try(var rows=command.executeQuery("SELECT to_regclass('public.console_pending') IS NOT NULL")){assertTrue(rows.next());return rows.getBoolean(1);}}finally{owner.lock.unlock();}
    }
    private static void drainDifferentSourceMetadata(EngineFixture fixture)throws Exception {
        var barrier=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setId("restore-drain-ack-pending")).setPassword("fixture").build());
        try{
            configure(fixture,barrier);fixture.jobs.metadataRefresh().connected(barrier);
            await(()->fixture.metadata.metadataPlatform().publishedSnapshot(barrier).complete(columns(fixture,WARM),IntrospectionLevel.STRUCTURE),"A different-source task must drain earlier native ACK work without refreshing the original source");
        }finally{fixture.sessions.close(barrier.id,true);}
    }
    private static void commitConsole(WorkbenchService service,SessionRegistry.Session owner){
        var request=SessionRequest.newBuilder().setContext(context(service)).setSessionId(owner.id).setAction(SessionAction.COMMIT).build();
        var review=new Reply<Approval>();service.reviewSession(request,review);assertNull(review.failure);assertNotNull(review.value);
        var reply=new Reply<SessionInfo>();service.session(request.toBuilder().setContext(context(service)).setApprovalToken(review.value.getToken()).build(),reply);assertNull(reply.failure);assertNotNull(reply.value);
        assertTrue(reply.value.getCommandAcknowledged());assertEquals(SessionAction.COMMIT,reply.value.getAcknowledgedAction());
    }
    private static void configure(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        var platform=fixture.metadata.metadataPlatform();var before=platform.configuration(owner);
        platform.configure(owner,new MetadataConfiguration(before.revision()+1,Set.of("busydata"),Set.of(),Set.of(fixture.schema()),Set.of(),false,before.kinds(),List.of(),List.of(),IntrospectionLevel.STRUCTURE,Map.of()));
    }
    private static void setup(EngineFixture fixture,SessionRegistry.Session owner)throws Exception {
        sql(owner,"CREATE TABLE restore_warm(id INTEGER PRIMARY KEY,n INTEGER)");
        sql(owner,"INSERT INTO restore_warm VALUES(1,10)");
        sql(owner,"CREATE TABLE restore_guard(id INTEGER PRIMARY KEY)");
        sql(owner,"CREATE TABLE restore_marker(id INTEGER PRIMARY KEY)");
        sql(owner,"CREATE TEMPORARY TABLE restore_owned_temp(id INTEGER PRIMARY KEY)");
        sql(owner,"INSERT INTO restore_owned_temp VALUES(7)");
        configure(fixture,owner);fixture.warm(owner,WARM);
        owner.lock.lock();try{new Explorer(fixture.metadata).refreshTemporary(owner,"busydata",fixture.schema(),TEMP);}finally{owner.lock.unlock();}
    }
    private static ResultStore.Result retained(EngineFixture fixture,SessionRegistry.Session owner)throws Exception {
        var job=fixture.execute(owner,"SELECT id,n FROM "+table(owner,fixture,WARM));
        assertEquals(JobState.COMPLETED,job.state);assertEquals(1,job.info().getResultsCount());
        var result=fixture.results.get(job.info().getResults(0).getResultId());assertTrue(result.fetchFinished);assertTrue(result.metadataProof().available(),"The unchanged real table must have a warm retained proof before native restore");return result;
    }
    private static ChangeRequest assessment(EngineFixture fixture,SessionRegistry.Session owner,ResultStore.Result result){return ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(result.id).setCatalog("busydata").setSchema(fixture.schema()).setTable(WARM).build();}
    private static void irreversiblyStale(EngineFixture fixture,SessionRegistry.Session owner,ResultStore.Result result)throws Exception {
        assertEquals(MetadataState.STALE,result.metadataProof().state());assertFalse(result.metadataProof().available());assertFalse(result.metadataProof().capturedStructure(),"External invalidation cannot retain a rollback/physical-structure recovery route");
        int jobs=fixture.jobs.list(owner.id).size();var assessment=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform()).assess(owner,assessment(fixture,owner,result));
        assertFalse(assessment.getEditable());assertEquals("stale",assessment.getReasonCode());assertEquals(jobs,fixture.jobs.list(owner.id).size(),"Assessment never reruns the retained query");
        assertEquals(1,result.rows(),"Rows remain retained after editability evidence is invalidated");
    }
    private static Set<String> temporaryIdentities(EngineFixture fixture,SessionRegistry.Session owner){return fixture.metadata.metadataPlatform().capture(owner).identities().values().stream().filter(object->object.identity().sessionOwner().equals(owner.id)&&(object.identity().name().equals(TEMP)||object.identity().parent().equals(TEMP))).map(object->object.identity().key()).collect(java.util.stream.Collectors.toUnmodifiableSet());}
    private static void temporaryUnchanged(EngineFixture fixture,SessionRegistry.Session owner,Set<String> expected)throws Exception {
        assertEquals(expected,temporaryIdentities(fixture,owner));assertFalse(expected.isEmpty());assertEquals(1,count(owner,TEMP),"The actual console-owned temporary table is untouched by the external session");
    }
    private record BeforeLaunch(boolean processAbsent,boolean barrier,boolean oldProofAvailable,boolean durableFresh){}
    private static void prelaunchFailure(EngineFixture fixture,SessionRegistry.Session owner,ResultStore.Result result)throws Exception {
        var platform=fixture.metadata.metadataPlatform();var observed=new AtomicReference<BeforeLaunch>();
        // This deliberate failure exercises the public lifecycle hook before
        // ANY native process. The real client cases below are separate jobs.
        var job=fixture.jobs.submit(owner,UUID.randomUUID().toString(),"",operation->{
            operation.beforeExternalMutation();
            observed.set(new BeforeLaunch(operation.process==null,platform.externalMutationActive(owner),result.metadataProof().available(),platform.publishedSnapshot(owner).complete(columns(fixture,WARM),IntrospectionLevel.STRUCTURE)));
            throw new IllegalStateException("Controlled fixture failure before native process launch");
        });
        assertEquals(JobState.FAILED,finished(job).getState(),"No spawned native process means no external unknown outcome");
        assertEquals(new BeforeLaunch(true,true,false,false),observed.get());assertFalse(platform.externalMutationActive(owner));
        fixture.warm(owner,WARM);irreversiblyStale(fixture,owner,result);
    }
    /** A real engine advisory lock pauses the real client without a sleep or fake executable. */
    private static final class NativeGate implements AutoCloseable {
        final EngineFixture fixture;final SessionRegistry.Session owner;boolean released;
        NativeGate(EngineFixture fixture)throws Exception {
            this.fixture=fixture;owner=fixture.open();
            try(var command=owner.connection.createStatement()){command.setQueryTimeout(5);try(var rows=command.executeQuery(fixture.engine==Engine.POSTGRESQL?"SELECT pg_advisory_lock("+LOCK+")":"SELECT GET_LOCK('"+LOCK_NAME+"',5)")){assertTrue(rows.next());if(fixture.engine!=Engine.POSTGRESQL)assertEquals(1,rows.getInt(1));}}
        }
        String waitSql(){return fixture.engine==Engine.POSTGRESQL?"SELECT pg_advisory_lock("+LOCK+"); SELECT pg_advisory_unlock("+LOCK+");":"SELECT GET_LOCK('"+LOCK_NAME+"',30); SELECT RELEASE_LOCK('"+LOCK_NAME+"');";}
        void release()throws Exception {
            if(released)return;
            try(var command=owner.connection.createStatement()){command.setQueryTimeout(5);try(var rows=command.executeQuery(fixture.engine==Engine.POSTGRESQL?"SELECT pg_advisory_unlock("+LOCK+")":"SELECT RELEASE_LOCK('"+LOCK_NAME+"')")){assertTrue(rows.next());if(fixture.engine==Engine.POSTGRESQL)assertTrue(rows.getBoolean(1));else assertEquals(1,rows.getInt(1));}}
            released=true;
        }
        public void close()throws Exception{try{release();}finally{fixture.sessions.close(owner.id,true);}}
    }
    private static void cleanup(EngineFixture fixture,SessionRegistry.Session owner,Jobs.Job job)throws Exception {
        if(job!=null&&!job.finished.isDone()){if(!job.cancel.get())fixture.jobs.cancel(job.id);finished(job);}
        if(owner.state==TransactionState.ACTIVE){fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.ROLLBACK).build());fixture.jobs.metadataRefresh().transaction(owner,SessionAction.ROLLBACK);}
    }
    private static void sourceRemainsStaleAfterWorkerDrain(EngineFixture fixture,SessionRegistry.Session owner,String phase)throws Exception {
        // A new ordinary read settlement cannot turn unknown restore effects
        // into acknowledged committed effects or replay a native operation.
        assertEquals(JobState.COMPLETED,fixture.execute(owner,"SELECT 1").state);
        var barrier=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setId("restore-drain-"+phase)).setPassword("fixture").build());
        configure(fixture,barrier);fixture.jobs.metadataRefresh().connected(barrier);
        var platform=fixture.metadata.metadataPlatform();
        await(()->platform.publishedSnapshot(barrier).complete(columns(fixture,WARM),IntrospectionLevel.STRUCTURE),"A later real metadata task must pass the single worker before checking no automatic restore reconciliation");
        assertFalse(platform.externalMutationActive(owner));
        assertEquals(MetadataState.STALE,platform.publishedSnapshot(owner).coverage(columns(fixture,WARM)).orElseThrow().state());
        assertFalse(platform.publishedSnapshot(owner).complete(columns(fixture,WARM),IntrospectionLevel.STRUCTURE));
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void realAckReconcilesIndependentCommittedEffectsWithoutResolvingConsoleTransaction(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner);var service=service(fixture);var platform=fixture.metadata.metadataPlatform();
            Jobs.Job restore=null;boolean committed=false;
            try{
                var original=retained(fixture,owner);var proof=original.metadataProof();long publication=platform.publicationRevision(owner).revision();
                Path dump=root.resolve("actual-native-dump.sql");completed(nativeJob(fixture,service,owner,dump,true));assertTrue(Files.size(dump)>0);
                assertFalse(platform.externalMutationActive(owner));assertSame(proof,original.metadataProof(),"DUMP does not invalidate editing evidence");assertEquals(publication,platform.publicationRevision(owner).revision());
                prelaunchFailure(fixture,owner,original);
                var warm=retained(fixture,owner);var peerWarm=retained(fixture,observer);var temporary=temporaryIdentities(fixture,owner);assertFalse(temporary.isEmpty());
                fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.BEGIN).build());fixture.jobs.metadataRefresh().transaction(owner,SessionAction.BEGIN);
                assertEquals(JobState.COMPLETED,fixture.execute(owner,"INSERT INTO restore_guard VALUES(41)").state);
                MetadataObject pending=null;
                if(fixture.engine==Engine.POSTGRESQL){
                    assertEquals(JobState.COMPLETED,fixture.execute(owner,"CREATE TABLE console_pending(id INTEGER)").state);
                    pending=capturePendingOverlay(fixture,owner);
                    assertTrue(platform.publishedSnapshot(owner).resolve("busydata",fixture.schema(),ObjectKind.TABLE,"","console_pending",true).isEmpty());
                    assertTrue(pendingVisible(owner));assertFalse(pendingVisible(observer));
                }
                assertEquals(TransactionState.ACTIVE,owner.state);assertFalse(owner.autoCommit);assertEquals(0,count(observer,"restore_guard"));
                assertTrue(warm.metadataProof().available());assertTrue(peerWarm.metadataProof().available());
                try(var gate=new NativeGate(fixture)){
                    Path input=root.resolve("actual-native-restoration.sql");Files.writeString(input,"INSERT INTO restore_marker VALUES(1);\n"+gate.waitSql()+"\nCREATE TABLE native_committed(id INTEGER PRIMARY KEY,n INTEGER);\nINSERT INTO native_committed VALUES(1,73);\n");
                    restore=nativeJob(fixture,service,owner,input,false);Jobs.Job running=restore;
                    await(()->count(observer,"restore_marker")==1,"The actual native client must commit its marker and reach the real engine gate");
                    assertFalse(running.finished.isDone());assertNotNull(running.process);assertTrue(platform.externalMutationActive(owner));
                    assertEquals(MetadataState.STALE,platform.publishedSnapshot(owner).coverage(columns(fixture,WARM)).orElseThrow().state());
                    var refused=assertThrows(WorkbenchFailure.class,()->new Explorer(fixture.metadata).refreshFragment(observer,"busydata",fixture.schema(),WARM,ObjectKind.TABLE));assertEquals(WorkbenchFailure.Reason.STALE,refused.reason());
                    var activeAssessment=new ChangePlanner(fixture.safety,fixture.results,platform).assess(observer,assessment(fixture,observer,peerWarm));assertFalse(activeAssessment.getEditable());assertEquals("stale",activeAssessment.getReasonCode());
                    var during=fixture.execute(observer,"SELECT id,n FROM "+table(observer,fixture,WARM));assertEquals(JobState.COMPLETED,during.state,"Unavailable metadata proof does not suppress a deliberate read-only query");
                    var duringResult=fixture.results.get(during.info().getResults(0).getResultId());assertFalse(duringResult.metadataProof().available());
                    assertEquals(temporary,temporaryIdentities(fixture,owner));
                    gate.release();completed(restore);
                }
                await(()->platform.publishedSnapshot(owner).complete(columns(fixture,"native_committed"),IntrospectionLevel.STRUCTURE),"Real native acknowledgement must reconcile committed metadata despite the console transaction remaining ACTIVE");
                assertEquals(TransactionState.ACTIVE,owner.state);assertFalse(owner.autoCommit);assertEquals(0,count(observer,"restore_guard"),"Native success never commits the console transaction");
                assertEquals(1,count(observer,"native_committed"));temporaryUnchanged(fixture,owner,temporary);
                irreversiblyStale(fixture,owner,warm);irreversiblyStale(fixture,observer,peerWarm);
                assertEquals(JobState.COMPLETED,fixture.execute(owner,"SELECT id,n FROM "+table(owner,fixture,WARM)).state);
                if(fixture.engine==Engine.POSTGRESQL){
                    assertNotNull(pending);var captured=platform.capture(owner);assertSame(pending,captured.identity(pending.identity().key()).orElseThrow(),"The real acquired persistent identity remains in the owned overlay after native ACK");
                    assertEquals(MetadataState.STALE,captured.coverage(pendingScope(fixture)).orElseThrow().state());
                    assertTrue(pendingVisible(owner));assertFalse(pendingVisible(observer));temporaryUnchanged(fixture,owner,temporary);
                    drainDifferentSourceMetadata(fixture);
                    assertTrue(platform.publishedSnapshot(owner).resolve("busydata",fixture.schema(),ObjectKind.TABLE,"","console_pending",true).isEmpty(),"Native ACK work cannot publish the console's uncommitted DDL");
                    assertEquals(TransactionState.ACTIVE,owner.state);assertEquals(0,count(observer,"restore_guard"));
                    commitConsole(service,owner);committed=true;
                    assertEquals(TransactionState.IDLE,owner.state);assertEquals(1,count(observer,"restore_guard"));assertTrue(pendingVisible(observer));
                    await(()->platform.publishedSnapshot(owner).complete(columns(fixture,"console_pending"),IntrospectionLevel.STRUCTURE),"Only explicit console COMMIT releases the preserved pending DDL effect for independent reconciliation");
                    var published=platform.publishedSnapshot(owner).resolve("busydata",fixture.schema(),ObjectKind.TABLE,"","console_pending",true);assertEquals(1,published.size());assertTrue(published.getFirst().level().includes(IntrospectionLevel.STRUCTURE));
                }
            }finally{cleanup(fixture,owner,restore);}
            assertEquals(committed?1:0,count(observer,"restore_guard"),"Only explicit fixture COMMIT or rollback resolves the held console transaction");
        }
    }

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void partialFailureAndSingleCancellationStayStaleUntilExplicitRefresh(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner);var service=service(fixture);var platform=fixture.metadata.metadataPlatform();
            var original=retained(fixture,owner);var temporary=temporaryIdentities(fixture,owner);
            Path partial=root.resolve("actual-native-partial.sql");Files.writeString(partial,"CREATE TABLE native_partial(id INTEGER PRIMARY KEY);\nINSERT INTO native_partial VALUES(1);\nNATIVE_RESTORE_EXPECTED_PARSE_FAILURE;\nINSERT INTO native_partial VALUES(2);\n");
            var failed=nativeJob(fixture,service,owner,partial,false);var failure=finished(failed);assertEquals(JobState.UNKNOWN_OUTCOME,failure.getState());assertEquals("NATIVE_TOOL_FAILED",failure.getErrorCode());assertEquals(1,count(observer,"native_partial"));
            assertTrue(failure.getMessagesList().stream().anyMatch(message->message.contains("SQL is never replayed")));
            assertThrows(IllegalArgumentException.class,()->fixture.jobs.submit(owner,failed.execution,"",ignored->fail("The failed native execution cannot be replayed")));
            assertFalse(failure.getMessagesList().stream().anyMatch(message->message.contains("NATIVE_RESTORE_EXPECTED_PARSE_FAILURE")),"Diagnostics omit submitted SQL");
            sourceRemainsStaleAfterWorkerDrain(fixture,owner,"partial");temporaryUnchanged(fixture,owner,temporary);
            fixture.warm(owner,WARM);irreversiblyStale(fixture,owner,original);var refreshed=retained(fixture,owner);
            Jobs.Job cancelled=null;
            try{
                try(var gate=new NativeGate(fixture)){
                    Path input=root.resolve("actual-native-cancelled.sql");Files.writeString(input,"INSERT INTO restore_marker VALUES(2);\n"+gate.waitSql()+"\nCREATE TABLE native_after_cancel(id INTEGER);\n");
                    cancelled=nativeJob(fixture,service,owner,input,false);Jobs.Job running=cancelled;
                    await(()->count(observer,"restore_marker")==1,"The real client must have entered restore before the single cancellation");
                    assertTrue(platform.externalMutationActive(owner));assertFalse(running.finished.isDone());assertNotNull(running.process);
                    fixture.jobs.cancel(running.id);
                    assertEquals(JobState.UNKNOWN_OUTCOME,finished(running).getState(),"Cancelling a started external restore cannot prove no statement committed");
                }
                sourceRemainsStaleAfterWorkerDrain(fixture,owner,"cancelled");temporaryUnchanged(fixture,owner,temporary);
                fixture.warm(owner,WARM);irreversiblyStale(fixture,owner,refreshed);
                assertTrue(retained(fixture,owner).metadataProof().available(),"Only a fresh explicit query obtains fresh retained editing proof");
            }finally{cleanup(fixture,owner,cancelled);}
        }
    }
}
