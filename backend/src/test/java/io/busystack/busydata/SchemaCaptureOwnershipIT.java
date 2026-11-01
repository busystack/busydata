package io.busystack.busydata;

import com.google.gson.*;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.Values;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.management.*;
import java.lang.reflect.*;
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

/** Real native catalogs and normalized SQLite contention. All database commands
 * are explicit fixture work; only the one held table property is synthetic. */
class SchemaCaptureOwnershipIT {
    @TempDir Path root;
    private static final String TABLE="schema_capture_owner",MARKER="fixtureCaptureOwnership";
    private static final ThreadMXBean THREADS=ManagementFactory.getThreadMXBean();
    private static final Set<String> JDBC_READS=Set.of("createStatement","prepareStatement","prepareCall","getMetaData");

    private record OwnerState(long revision,long contextRevision,boolean autoCommit,TransactionState transaction,Object context){
        static OwnerState of(SessionRegistry.Session owner){return new OwnerState(owner.revision,owner.contextRevision,owner.autoCommit,owner.state,owner.context);}
        void unchanged(SessionRegistry.Session owner)throws Exception {
            assertEquals(revision,owner.revision);assertEquals(contextRevision,owner.contextRevision);assertEquals(autoCommit,owner.autoCommit);assertEquals(transaction,owner.state);assertEquals(context,owner.context);
            assertFalse(owner.physicalEnded());assertFalse(owner.connection.isClosed());assertEquals(autoCommit,owner.connection.getAutoCommit());
        }
    }
    /** Supported JDBC proxies observe application-owned connections only. They
     * neither replace native calls nor fabricate rows/metadata. */
    private static final class Connections {
        enum Purpose { SCHEMA_INSPECTION,JDBC_COLUMN_DESCRIPTOR,UNCLASSIFIED }
        enum Caller { SCHEMA_INSPECTION,SCHEMA_CAPTURE,NATIVE_STRUCTURE,JDBC_COLUMNS }
        enum Observation { NOT_OBSERVED,AVAILABLE,FAILED }
        record DescriptorState(Observation observation,boolean serverReadOnly,String sqlMode){}
        private static List<Caller> callers(){
            return StackWalker.getInstance().walk(frames->frames.limit(64).map(frame->{
                if(frame.getClassName().equals(SchemaMetadataProjection.class.getName()))return switch(frame.getMethodName()){case "inspect"->Caller.SCHEMA_INSPECTION;case "captureOnce"->Caller.SCHEMA_CAPTURE;default->null;};
                if(frame.getClassName().equals(NativeStructureReader.class.getName())&&frame.getMethodName().equals("inspect"))return Caller.NATIVE_STRUCTURE;
                if(frame.getClassName().equals(JdbcMetadataPatterns.class.getName())&&frame.getMethodName().equals("columns"))return Caller.JDBC_COLUMNS;
                return null;
            }).filter(Objects::nonNull).limit(8).toList());
        }
        private static Purpose purpose(List<Caller> trace){
            if(trace.containsAll(List.of(Caller.JDBC_COLUMNS,Caller.NATIVE_STRUCTURE,Caller.SCHEMA_CAPTURE)))return Purpose.JDBC_COLUMN_DESCRIPTOR;
            if(trace.contains(Caller.SCHEMA_INSPECTION)&&!trace.contains(Caller.JDBC_COLUMNS))return Purpose.SCHEMA_INSPECTION;
            return Purpose.UNCLASSIFIED;
        }
        final AtomicReference<Thread> foreground=new AtomicReference<>();final AtomicReference<SessionRegistry.Session> owner=new AtomicReference<>();
        final AtomicInteger opens=new AtomicInteger(),closes=new AtomicInteger(),nativeCalls=new AtomicInteger(),schemaReads=new AtomicInteger(),openingHolds=new AtomicInteger(),closingHolds=new AtomicInteger();
        final AtomicReference<Purpose> purpose=new AtomicReference<>(Purpose.UNCLASSIFIED);final AtomicReference<List<Caller>> trace=new AtomicReference<>(List.of());
        final AtomicReference<DescriptorState> descriptorState=new AtomicReference<>(new DescriptorState(Observation.NOT_OBSERVED,false,""));
        final AtomicBoolean leaseDuringOpen=new AtomicBoolean(),notReadOnly=new AtomicBoolean(),gateNextOpen=new AtomicBoolean();
        final AtomicReference<Connection> view=new AtomicReference<>();
        final CountDownLatch opening=new CountDownLatch(1),releaseOpen=new CountDownLatch(1);
        void arm(Thread thread,SessionRegistry.Session session){owner.set(session);foreground.set(thread);opens.set(0);closes.set(0);nativeCalls.set(0);schemaReads.set(0);openingHolds.set(0);closingHolds.set(0);purpose.set(Purpose.UNCLASSIFIED);trace.set(List.of());descriptorState.set(new DescriptorState(Observation.NOT_OBSERVED,false,""));leaseDuringOpen.set(false);notReadOnly.set(false);view.set(null);}
        Connection open(io.busystack.busydata.adapters.JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            boolean captured=Thread.currentThread()==foreground.get();
            if(captured){
                opens.incrementAndGet();var physical=owner.get();var observed=callers();trace.set(observed);purpose.set(purpose(observed));
                if(physical!=null){openingHolds.set(physical.lock.getHoldCount());if(physical.lock.isHeldByCurrentThread())leaseDuringOpen.set(true);}
                if(!request.getProfile().getReadOnly())notReadOnly.set(true);
                if(gateNextOpen.compareAndSet(true,false)){opening.countDown();if(!releaseOpen.await(10,TimeUnit.SECONDS))throw new AssertionError("Missing owned view-opening release");}
            }
            var connection=adapter.connect(request,port);if(captured)view.set(connection);var closed=new AtomicBoolean();
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(Thread.currentThread()==foreground.get()){
                    if(JDBC_READS.contains(method.getName()))nativeCalls.incrementAndGet();
                    if(method.getName().equals("prepareStatement")&&args!=null&&args.length>0&&args[0] instanceof String sql&&sql.startsWith("SELECT TABLE_NAME FROM information_schema.TABLES WHERE "))schemaReads.incrementAndGet();
                }
                if(captured&&method.getName().equals("close")){
                    var physical=owner.get();if(physical!=null)closingHolds.set(physical.lock.getHoldCount());
                    if(!closed.get()&&purpose.get()==Purpose.JDBC_COLUMN_DESCRIPTOR)observeDescriptorBeforeClose(connection);
                }
                try{return method.invoke(connection,args);}catch(InvocationTargetException failure){throw failure.getCause();}
                finally{if(captured&&method.getName().equals("close")&&closed.compareAndSet(false,true))closes.incrementAndGet();}
            });
        }
        void independentClosed()throws Exception {
            assertEquals(1,opens.get(),"One original acquisition must open one independent view");assertEquals(Purpose.SCHEMA_INSPECTION,purpose.get());assertTrue(trace.get().contains(Caller.SCHEMA_INSPECTION));assertFalse(trace.get().contains(Caller.JDBC_COLUMNS));
            assertFalse(leaseDuringOpen.get(),"View opening must never own the physical-session lease");assertEquals(0,openingHolds.get());assertEquals(0,closingHolds.get());assertFalse(notReadOnly.get());
            assertNotNull(view.get());assertTrue(view.get().isClosed(),"Only the independent view must be closed");assertEquals(1,closes.get());
        }
        private void observeDescriptorBeforeClose(Connection connection){
            // Both pinned engines expose this server setting. MariaDB's JDBC
            // isReadOnly alone is a client flag; use the actual private view.
            // Observation failure is asserted after close, never a reason to
            // skip releasing this owned connection or retain driver prose.
            descriptorState.set(new DescriptorState(Observation.FAILED,false,""));
            try(var query=connection.createStatement()){
                query.setQueryTimeout(5);query.setMaxRows(2);
                try(var rows=query.executeQuery("SELECT @@SESSION.transaction_read_only,@@SESSION.sql_mode")){
                    if(!rows.next())return;boolean readOnly=rows.getBoolean(1);String mode=rows.getString(2);
                    if(mode==null||mode.length()>8192||rows.next())return;
                    descriptorState.set(new DescriptorState(Observation.AVAILABLE,readOnly,mode));
                }
            }catch(SQLException|RuntimeException ignored){/* The exact failed observation is rejected after the connection closes. */}
        }
        void descriptorClosed(int holdCount,String expectedMode)throws Exception {
            assertEquals(1,opens.get(),"The owning MySQL/MariaDB capture opens exactly one protected JDBC descriptor view");assertEquals(Purpose.JDBC_COLUMN_DESCRIPTOR,purpose.get());
            assertTrue(trace.get().containsAll(List.of(Caller.JDBC_COLUMNS,Caller.NATIVE_STRUCTURE,Caller.SCHEMA_CAPTURE)));assertFalse(trace.get().contains(Caller.SCHEMA_INSPECTION));
            assertTrue(leaseDuringOpen.get());assertEquals(holdCount,openingHolds.get());assertEquals(holdCount,closingHolds.get());assertFalse(notReadOnly.get(),"The descriptor request must ask for a read-only profile");
            assertNotNull(view.get());assertTrue(view.get().isClosed(),"Only the protected descriptor view is closed");assertEquals(1,closes.get());
            var actual=descriptorState.get();assertEquals(Observation.AVAILABLE,actual.observation());assertTrue(actual.serverReadOnly(),"The descriptor view must acknowledge server transaction_read_only");assertEquals(expectedMode,actual.sqlMode(),"The descriptor mode must be restored before its view closes");
        }
    }
    private static final class Capture implements AutoCloseable {
        final io.grpc.Context.CancellableContext context=io.grpc.Context.current().withCancellation();final FutureTask<JsonObject> result;final Thread thread;
        Capture(Connections connections,SessionRegistry.Session owner,Callable<JsonObject> action){
            result=new FutureTask<>(context.wrap(action));thread=Thread.ofPlatform().name("schema-owner-foreground").unstarted(result);connections.arm(thread,owner);thread.start();
        }
        JsonObject success()throws Exception{return result.get(10,TimeUnit.SECONDS);}
        Throwable refusal(long timeoutMs)throws Exception {
            var error=assertThrows(ExecutionException.class,()->result.get(timeoutMs,TimeUnit.MILLISECONDS),"The original capture must fail rather than silently recapture current authority");return error.getCause();
        }
        @Override public void close()throws Exception {
            context.cancel(null);if(thread.isAlive()){thread.interrupt();thread.join(5000);}assertFalse(thread.isAlive(),"Owned capture thread did not finish");context.close();
        }
    }
    private static final class CacheWriter implements AutoCloseable {
        final MetadataPlatform platform;final SessionRegistry.Session owner;final Connection db;final Statement lock;
        final io.grpc.Context.CancellableContext context=io.grpc.Context.current().withCancellation();final AtomicReference<Throwable> failure=new AtomicReference<>();
        final AtomicBoolean released=new AtomicBoolean(),automaticRelease=new AtomicBoolean();final AtomicInteger releaseCount=new AtomicInteger();
        final ScheduledExecutorService guard=Executors.newSingleThreadScheduledExecutor();final ScheduledFuture<?> safety;final Thread thread;
        CacheWriter(EngineFixture fixture,SessionRegistry.Session owner)throws Exception {
            this.owner=owner;platform=fixture.metadata.metadataPlatform();
            var old=relation(platform.publishedSnapshot(owner),owner,fixture.schema());
            var scope=new MetadataScope(owner.context.catalog(),fixture.schema(),"",ObjectKind.TABLE,TABLE,true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
            var object=old.projection(0,0).toBuilder().putProperties(MARKER,"held writer").build();
            var state=new MetadataCoverage(scope,old.level(),MetadataState.AVAILABLE,true,"owned-cache-contention",owner.revision,owner.contextRevision,System.currentTimeMillis(),"");long ticket=platform.beginRefresh(owner);
            thread=Thread.ofPlatform().name("schema-owner-cache-publisher").unstarted(context.wrap(()->{try{platform.publish(owner,ticket,platform.publishedSnapshot(owner).rules(),Map.of(scope,new MetadataPlatform.Branch(List.of(object),state)),false);}catch(Throwable problem){failure.set(problem);}}));
            db=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));Statement acquired=null;
            try{acquired=db.createStatement();acquired.execute("PRAGMA busy_timeout=5000");acquired.execute("BEGIN IMMEDIATE");}
            catch(Exception|Error problem){if(acquired!=null)try{acquired.close();}catch(Exception cleanup){problem.addSuppressed(cleanup);}try{db.close();}catch(Exception cleanup){problem.addSuppressed(cleanup);}guard.shutdownNow();context.close();throw problem;}
            lock=acquired;
            safety=guard.schedule(()->release(true),4,TimeUnit.SECONDS);
            try{thread.start();awaitNativeWrite(this);pending();}
            catch(Exception|Error problem){try{close();}catch(Exception|Error cleanup){problem.addSuppressed(cleanup);}throw problem;}
        }
        void pending(){assertFalse(released.get(),"Owned SQLite lock released before causal observation");assertFalse(automaticRelease.get());assertTrue(thread.isAlive());assertNull(failure.get());assertEquals("WRITE_PENDING",platform.cacheState());}
        void release(){release(false);}
        private void release(boolean automatic){if(released.compareAndSet(false,true)){if(automatic)automaticRelease.set(true);try{lock.execute("ROLLBACK");releaseCount.incrementAndGet();}catch(Throwable problem){failure.compareAndSet(null,problem);}}}
        void finish()throws Exception {release();safety.cancel(false);thread.join(10000);assertFalse(thread.isAlive());assertFalse(automaticRelease.get(),"Safety release is cleanup, not an observed successful concurrency test");assertNull(failure.get(),()->"Owned cache writer failed: "+failure.get());assertEquals(1,releaseCount.get());}
        @Override public void close()throws Exception {
            release();safety.cancel(false);guard.shutdownNow();if(thread.isAlive())thread.join(10000);if(thread.isAlive()){context.cancel(null);thread.interrupt();thread.join(5000);}context.close();
            try{assertFalse(thread.isAlive(),"Owned metadata writer did not finish");assertEquals(1,releaseCount.get());}finally{try{lock.close();}finally{db.close();}}
        }
    }
    private static ThreadInfo info(Thread thread){return THREADS.getThreadInfo(new long[]{thread.threadId()},true,true)[0];}
    private static boolean frame(ThreadInfo info,String type,String method){return info!=null&&Arrays.stream(info.getStackTrace()).anyMatch(value->value.getClassName().equals(type)&&value.getMethodName().equals(method));}
    private static void awaitNativeWrite(CacheWriter writer)throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
        while(System.nanoTime()<deadline&&writer.thread.isAlive()&&!writer.released.get()){
            var snapshot=info(writer.thread);boolean nativeStep=frame(snapshot,"org.sqlite.core.NativeDB","step");
            boolean begin=frame(snapshot,"org.sqlite.SQLiteConnection","setAutoCommit")&&frame(snapshot,"org.sqlite.core.DB","exec");
            boolean write=snapshot!=null&&Arrays.stream(snapshot.getStackTrace()).anyMatch(value->value.getClassName().startsWith("org.sqlite.")&&Set.of("executeUpdate","executeLargeUpdate","executeBatch","executeLargeBatch").contains(value.getMethodName()));
            if(nativeStep&&(begin||write)&&writer.platform.cacheState().equals("WRITE_PENDING")){
                assertTrue(Arrays.stream(snapshot.getLockedMonitors()).noneMatch(value->value.getClassName().equals(MetadataPlatform.class.getName()+"$Source")),"Cache I/O must not hold Source");return;
            }
            LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
        }
        fail("The exact owned publisher was not observed in native SQLite write wait; no timing inference is valid");
    }
    private static void awaitForegroundWriter(Capture capture,CacheWriter writer)throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(2);
        while(System.nanoTime()<deadline&&!capture.result.isDone()){
            var snapshot=info(capture.thread);
            if(frame(snapshot,MetadataPlatform.class.getName(),"enterWriter")&&(snapshot.getThreadState()==Thread.State.WAITING||snapshot.getThreadState()==Thread.State.TIMED_WAITING)){
                writer.pending();assertTrue(Arrays.stream(snapshot.getLockedMonitors()).noneMatch(value->value.getClassName().equals(MetadataPlatform.class.getName()+"$Source")));return;
            }
            LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));
        }
        if(capture.result.isDone())fail("Capture finished instead of reaching the safe writer wait: "+capture.refusal(100));
        fail("Foreground capture was not observed waiting in the real source writer gate");
    }
    private static MetadataObject relation(MetadataSnapshot snapshot,SessionRegistry.Session owner,String schema){var found=snapshot.resolve(owner.context.catalog(),schema,ObjectKind.TABLE,"",TABLE,true);assertEquals(1,found.size());return found.getFirst();}
    private static JsonObject seed(EngineFixture fixture,SessionRegistry.Session owner,SchemaTools tools)throws Exception {
        String table=owner.adapter.table(owner.context.catalog(),fixture.schema(),TABLE);fixture.execute(owner,"CREATE TABLE "+table+"(id INTEGER PRIMARY KEY,n INTEGER NOT NULL DEFAULT 7)");
        var result=tools.capture(owner,fixture.schema());artifact(result,fixture);return result;
    }
    private static void artifact(JsonObject value,EngineFixture fixture){
        assertEquals(2,value.get("version").getAsInt());assertEquals(fixture.engine.name(),value.get("engine").getAsString());assertEquals(fixture.schema(),value.get("schema").getAsString());
        assertEquals(Set.of(TABLE),value.getAsJsonObject("tables").keySet());var columns=value.getAsJsonObject("tables").getAsJsonObject(TABLE).getAsJsonObject("columns");assertEquals(Set.of("id","n"),columns.keySet());
        var n=columns.getAsJsonObject("n");assertFalse(n.get("nullable").getAsBoolean());assertTrue(n.get("type").getAsString().toLowerCase(Locale.ROOT).contains("int"));assertTrue(n.get("default").getAsString().contains("7"));
    }
    private static String scalar(EngineFixture fixture,SessionRegistry.Session owner,String sql)throws Exception {var job=fixture.execute(owner,sql);assertEquals(1,job.info().getResultsCount());return Values.text(fixture.results.get(job.info().getResults(0).getResultId()).read(0).getValues(0));}
    private static void control(EngineFixture fixture,SessionRegistry.Session owner,SessionRegistry.Session observer,Capture capture,CacheWriter writer)throws Exception {
        try(var workers=Executors.newFixedThreadPool(2)){
            var lease=workers.submit(()->{boolean acquired=owner.lock.tryLock(250,TimeUnit.MILLISECONDS);if(acquired)owner.lock.unlock();return acquired;});assertTrue(lease.get(500,TimeUnit.MILLISECONDS),"Foreground schema capture retained its physical lease while waiting");
            var query=workers.submit(()->scalar(fixture,observer,"SELECT 1"));try{assertEquals("1",query.get(750,TimeUnit.MILLISECONDS),"The independent metadata writer blocked an interactive database command");}finally{if(!query.isDone())query.cancel(true);}
        }
        writer.pending();assertFalse(capture.result.isDone());
    }
    private static MetadataSettingsReply settings(MetadataPlatform platform,SessionRegistry.Session owner)throws Exception {return MetadataRpc.run(new Explorer(platform),owner,MetadataSettingsRequest.newBuilder().setSessionId(owner.id).setSessionRevision(owner.revision).setContextRevision(owner.contextRevision).setAction(MetadataSettingsAction.READ_METADATA_SETTINGS).setLimit(1).build());}
    private static long persistedRevision(EngineFixture fixture,SessionRegistry.Session owner)throws Exception {
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var query=db.prepareStatement("SELECT revision FROM publication WHERE source=?")){query.setString(1,owner.metadataSourceIdentity);try(var rows=query.executeQuery()){assertTrue(rows.next());long revision=rows.getLong(1);assertFalse(rows.next());return revision;}}
    }
    private static void persistedMarker(EngineFixture fixture,SessionRegistry.Session owner,boolean expected)throws Exception {
        var object=relation(fixture.metadata.metadataPlatform().publishedSnapshot(owner),owner,fixture.schema());
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var query=db.prepareStatement("SELECT value FROM property WHERE source=? AND identity=? AND name=?")){query.setString(1,owner.metadataSourceIdentity);query.setString(2,object.identity().key());query.setString(3,MARKER);try(var rows=query.executeQuery()){assertEquals(expected,rows.next());if(expected){assertEquals("held writer",rows.getString(1));assertFalse(rows.next());}}}
    }
    private record PersistedHeader(long revision,long configuration){}
    private static PersistedHeader persistedHeader(EngineFixture fixture,SessionRegistry.Session owner)throws Exception {
        try(var db=DriverManager.getConnection("jdbc:sqlite:"+fixture.metadata.root().resolve("metadata_catalog.sqlite"));var query=db.prepareStatement("SELECT revision,configuration_revision FROM publication WHERE source=?")){
            query.setQueryTimeout(2);query.setMaxRows(2);query.setString(1,owner.metadataSourceIdentity);
            try(var rows=query.executeQuery()){assertTrue(rows.next());var header=new PersistedHeader(rows.getLong(1),rows.getLong(2));assertFalse(rows.next());return header;}
        }
    }
    /** The preceding writer can still own native terminal cleanup after releasing Source.writer. */
    private static void cacheOutcome(Map<String,Object> report,EngineFixture fixture,SessionRegistry.Session owner,MetadataSnapshot held,MetadataSnapshot current,MetadataSettingsReply reply)throws Exception {
        var platform=fixture.metadata.metadataPlatform();var header=persistedHeader(fixture,owner);
        report.put("persistedRevision",header.revision());report.put("persistedConfigurationRevision",header.configuration());
        String health=reply.getCacheState();report.put("cacheState",Set.of("AVAILABLE","WRITE_UNAVAILABLE","WRITE_PENDING").contains(health)?health:"OTHER");
        var receipt=platform.cacheWriteReceipt(owner);report.put("currentReceiptObserved",receipt.isPresent());
        if(health.equals("AVAILABLE")){
            var observed=receipt.orElseThrow();assertTrue(observed.identity().matches(current));
            var completion=observed.completed().orElseThrow();assertFalse(observed.active());assertNull(completion.failure());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,completion.metrics().commitOutcome());
            assertTrue(platform.cacheFailure(owner).isEmpty());assertTrue(platform.cacheWriteMetrics(owner).orElseThrow().matches(current));
            assertEquals(current.revision(),header.revision());assertEquals(current.configurationRevision(),header.configuration());persistedMarker(fixture,owner,false);
            report.put("receiptSnapshotRevision",observed.identity().snapshotRevision());report.put("receiptConfigurationRevision",observed.identity().configurationRevision());report.put("receiptCommitOutcome",completion.metrics().commitOutcome().name());
        }else{
            assertEquals("WRITE_UNAVAILABLE",health);assertTrue(receipt.isEmpty());assertTrue(platform.cacheWriteMetrics(owner).isEmpty());
            var failure=platform.cacheFailure(owner).orElseThrow();boolean terminalBusy=failure.reason()==MetadataRepository.FailureReason.UNAVAILABLE&&"55000".equals(failure.sqlState())&&failure.vendorCode()==0;
            report.put("cacheFailureReason",failure.reason().name());report.put("terminalAdmission55000",terminalBusy);report.put("cacheFailureVendorCode",failure.vendorCode());
            assertTrue(terminalBusy,"Only exact no-queue terminal admission permits an older persisted header");
            assertEquals(held.revision(),header.revision());assertEquals(held.configurationRevision(),header.configuration());persistedMarker(fixture,owner,true);assertTrue(current.revision()>header.revision());
        }
        assertSame(current,platform.publishedSnapshot(owner));
    }
    private static void stale(Throwable problem){assertTrue(problem instanceof MetadataPlatform.SupersededRefresh||problem instanceof WorkbenchFailure&&((WorkbenchFailure)problem).reason()==WorkbenchFailure.Reason.STALE,()->"Wrong original-owner refusal: "+problem);}

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void independentForegroundCaptureWaitsWithoutBlockingPhysicalSessions(String engine)throws Exception {
        Path evidence=Files.createTempDirectory(Path.of("target"),"schema-capture-terminal-");var report=new LinkedHashMap<String,Object>();report.put("engine",engine);report.put("oldWriteReceiptObserved",false);Throwable problem=null;
        var connections=new Connections();try(var fixture=new EngineFixture(root,engine,connections::open)){
            var owner=fixture.open();var observer=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);var original=seed(fixture,owner,tools);var state=OwnerState.of(owner);
            report.put("initialSnapshotRevision",platform.publishedSnapshot(owner).revision());report.put("initialConfigurationRevision",platform.configuration(owner).revision());report.put("sessionRevision",state.revision());report.put("contextRevision",state.contextRevision());
            assertNotEquals(owner.id,observer.id);assertEquals(owner.metadataSourceIdentity,observer.metadataSourceIdentity);
            try(var writer=new CacheWriter(fixture,observer);var capture=new Capture(connections,owner,()->tools.capture(owner,fixture.schema()))){
                awaitForegroundWriter(capture,writer);assertNotNull(connections.view.get());assertFalse(connections.view.get().isClosed());control(fixture,owner,observer,capture,writer);state.unchanged(owner);
                var held=platform.publishedSnapshot(owner);assertEquals("held writer",relation(held,owner,fixture.schema()).properties().get(MARKER));
                report.put("heldPublicationRevision",held.revision());report.put("heldConfigurationRevision",held.configurationRevision());report.put("nativeWriteAndForegroundWaitObserved",true);report.put("interactiveCommandAndLeaseProgressed",true);
                writer.finish();var captured=capture.success();artifact(captured,fixture);assertEquals(original,captured);state.unchanged(owner);connections.independentClosed();
                var after=platform.publishedSnapshot(owner);assertTrue(after.revision()>held.revision());assertFalse(relation(after,owner,fixture.schema()).properties().containsKey(MARKER));assertTrue(after.complete(new MetadataScope(owner.context.catalog(),fixture.schema(),TABLE,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
                var reply=settings(platform,owner);assertEquals(owner.id,reply.getSessionId());assertEquals(state.revision(),reply.getSessionRevision());assertEquals(state.contextRevision(),reply.getContextRevision());assertEquals(after.revision(),reply.getSnapshotRevision());
                report.put("foregroundPublicationRevision",after.revision());report.put("foregroundConfigurationRevision",after.configurationRevision());report.put("cacheUnlocks",writer.releaseCount.get());report.put("automaticUnlock",writer.automaticRelease.get());report.put("independentViewsOpened",connections.opens.get());report.put("independentViewsClosed",connections.closes.get());
                cacheOutcome(report,fixture,owner,held,after,reply);
                assertEquals("held writer",relation(held,owner,fixture.schema()).properties().get(MARKER),"Held immutable metadata changed after publication");
                report.put("completed",true);
            }
        }catch(Throwable failure){problem=failure;report.put("completed",false);throw failure;}
        finally{report.put("failed",problem!=null);Files.writeString(evidence.resolve("result.json"),new GsonBuilder().setPrettyPrinting().create().toJson(report)+"\n");}
    }
    static Stream<Arguments> losingCaptures(){return Stream.of("POSTGRESQL","MYSQL","MARIADB").flatMap(engine->Stream.of("cancel","revision").map(race->Arguments.of(engine,race)));}
    @ParameterizedTest @MethodSource("losingCaptures")
    void cancellationOrRevisionChangeCannotRepublishTheWaitingCapture(String engine,String race)throws Exception {
        var connections=new Connections();try(var fixture=new EngineFixture(root,engine,connections::open)){
            var owner=fixture.open();var observer=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);seed(fixture,owner,tools);var state=OwnerState.of(owner);
            try(var writer=new CacheWriter(fixture,observer);var capture=new Capture(connections,owner,()->tools.capture(owner,fixture.schema()))){
                awaitForegroundWriter(capture,writer);var held=platform.publishedSnapshot(owner);assertEquals("held writer",relation(held,owner,fixture.schema()).properties().get(MARKER));
                if(race.equals("cancel")){
                    capture.context.cancel(null);assertInstanceOf(CancellationException.class,capture.refusal(500));writer.pending();state.unchanged(owner);
                }else{
                    assertEquals("1",scalar(fixture,owner,"SELECT 1"));assertTrue(owner.revision>state.revision());assertEquals(state.contextRevision(),owner.contextRevision);writer.pending();writer.finish();stale(capture.refusal(5000));
                }
                writer.finish();connections.independentClosed();assertSame(held,platform.publishedSnapshot(observer),"A losing capture must not mint a fresh publication owner");assertEquals(held.revision(),persistedRevision(fixture,owner));persistedMarker(fixture,owner,true);assertFalse(owner.physicalEnded());assertFalse(owner.connection.isClosed());assertTrue(owner.autoCommit);assertEquals(TransactionState.IDLE,owner.state);
            }
        }
    }
    static Stream<Arguments> openingCaptures(){return Stream.of("POSTGRESQL","MYSQL","MARIADB").flatMap(engine->Stream.of("revision","configuration","cancel").map(race->Arguments.of(engine,race)));}
    @ParameterizedTest @MethodSource("openingCaptures")
    void productionCaptureReservesItsOwnerBeforeOpeningTheIndependentView(String engine,String race)throws Exception {
        var connections=new Connections();try(var fixture=new EngineFixture(root,engine,connections::open)){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);seed(fixture,owner,tools);var state=OwnerState.of(owner);var held=platform.publishedSnapshot(owner);long configuration=platform.configuration(owner).revision();
            connections.gateNextOpen.set(true);
            try(var capture=new Capture(connections,owner,()->JsonParser.parseString(tools.run(owner,SchemaToolRequest.newBuilder().setSessionId(owner.id).setAction(SchemaToolAction.CAPTURE_SCHEMA).setSchema(fixture.schema()).build()).getSnapshot()).getAsJsonObject())){
                try{
                    assertTrue(connections.opening.await(5,TimeUnit.SECONDS),"The production action never reached its owned view-opening gate");assertTrue(owner.lock.tryLock(250,TimeUnit.MILLISECONDS));owner.lock.unlock();
                    switch(race){
                        case "revision"->{assertEquals("1",scalar(fixture,owner,"SELECT 1"));assertTrue(owner.revision>state.revision());}
                        case "configuration"->{
                            var old=platform.configuration(owner);var updated=new MetadataConfiguration(old.revision()+1,old.includedCatalogs(),old.excludedCatalogs(),Set.of(fixture.schema()),old.excludedSchemas(),old.systemObjects(),old.kinds(),old.includePatterns(),old.excludePatterns(),old.defaultLevel(),old.scopeLevels());
                            platform.configure(owner,updated);configuration=updated.revision();held=platform.publishedSnapshot(owner);assertEquals(configuration,held.configurationRevision());state.unchanged(owner);
                        }
                        case "cancel"->{capture.context.cancel(null);state.unchanged(owner);}
                        default->throw new AssertionError("Unknown view-opening race");
                    }
                }finally{connections.releaseOpen.countDown();}
                var refused=capture.refusal(5000);if(race.equals("cancel"))assertInstanceOf(CancellationException.class,refused);else stale(refused);
                assertEquals(0,connections.schemaReads.get(),"An invalid original owner must be rejected before schema acquisition");connections.independentClosed();assertSame(held,platform.publishedSnapshot(owner));assertEquals(held.revision(),persistedRevision(fixture,owner));
                var reply=settings(platform,owner);assertEquals(configuration,reply.getConfigurationRevision());assertEquals(held.revision(),reply.getSnapshotRevision());assertEquals(owner.id,reply.getSessionId());assertTrue(owner.autoCommit);assertEquals(TransactionState.IDLE,owner.state);assertFalse(owner.connection.isClosed());
            }finally{connections.releaseOpen.countDown();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void callerHeldAutocommitLeaseIsRejectedWithoutReleaseOrAcquisition(String engine)throws Exception {
        var connections=new Connections();try(var fixture=new EngineFixture(root,engine,connections::open)){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);seed(fixture,owner,tools);var state=OwnerState.of(owner);var held=platform.publishedSnapshot(owner);connections.arm(Thread.currentThread(),owner);
            owner.lock.lock();int count=owner.lock.getHoldCount();try{
                assertEquals(WorkbenchFailure.Reason.UNAVAILABLE,assertThrows(WorkbenchFailure.class,()->tools.capture(owner,fixture.schema())).reason());assertTrue(owner.lock.isHeldByCurrentThread());assertEquals(count,owner.lock.getHoldCount());assertEquals(0,connections.opens.get());assertEquals(0,connections.nativeCalls.get());assertEquals(0,connections.schemaReads.get());assertSame(held,platform.publishedSnapshot(owner));state.unchanged(owner);assertEquals(held.revision(),persistedRevision(fixture,owner));
            }finally{owner.lock.unlock();connections.foreground.set(null);}
            assertTrue(owner.lock.tryLock());owner.lock.unlock();assertEquals("1",scalar(fixture,owner,"SELECT 1"));
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void schemaInspectionCapabilityIsSingleUseAndCannotEscapeItsCallback(String engine)throws Exception {
        var connections=new Connections();try(var fixture=new EngineFixture(root,engine,connections::open)){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);var original=seed(fixture,owner,tools);var state=OwnerState.of(owner);
            var escaped=new AtomicReference<SchemaMetadataProjection.Capture>();var borrowed=new AtomicReference<Connection>();connections.arm(Thread.currentThread(),owner);
            try{
                var captured=platform.inspectSchema(owner,owner.context.catalog(),(view,capability)->{
                    assertTrue(view.isIndependentMetadataView());assertNotSame(owner,view);assertFalse(view.connection.isClosed());assertFalse(owner.lock.isHeldByCurrentThread());escaped.set(capability);borrowed.set(view.connection);
                    try(var workers=Executors.newSingleThreadExecutor()){
                        var rejected=workers.submit(()->assertThrows(WorkbenchFailure.class,()->capability.capture(fixture.schema(),null)));
                        assertEquals(WorkbenchFailure.Reason.INVALID_OWNER,rejected.get(1,TimeUnit.SECONDS).reason(),"A capability cannot be transferred to another thread");
                    }
                    var artifact=capability.capture(fixture.schema(),null);var held=platform.publishedSnapshot(owner);int before=connections.nativeCalls.get();
                    assertEquals(WorkbenchFailure.Reason.INVALID_OWNER,assertThrows(WorkbenchFailure.class,()->capability.capture(fixture.schema(),null)).reason());assertEquals(before,connections.nativeCalls.get());assertSame(held,platform.publishedSnapshot(owner));
                    // Designer validation legitimately uses the same native view
                    // after capture. Its lifetime ends at callback return.
                    assertFalse(view.connection.isClosed());try(var statement=view.connection.createStatement()){statement.setQueryTimeout(5);try(var rows=statement.executeQuery("SELECT 1")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertFalse(rows.next());}}
                    return artifact;
                });
                assertEquals(original,captured);connections.independentClosed();assertTrue(borrowed.get().isClosed());var held=platform.publishedSnapshot(owner);int before=connections.nativeCalls.get();
                assertEquals(WorkbenchFailure.Reason.INVALID_OWNER,assertThrows(WorkbenchFailure.class,()->escaped.get().capture(fixture.schema(),null)).reason());assertEquals(before,connections.nativeCalls.get());assertSame(held,platform.publishedSnapshot(owner));state.unchanged(owner);
            }finally{connections.foreground.set(null);}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void idleManualCaptureIsUnavailableWithoutStartingANativeTransactionOrChangingALease(String engine)throws Exception {
        var connections=new Connections();try(var fixture=new EngineFixture(root,engine,connections::open)){
            var owner=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);seed(fixture,owner,tools);
            fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.BEGIN).build());fixture.jobs.metadataRefresh().transaction(owner,SessionAction.BEGIN);
            assertFalse(owner.autoCommit);assertEquals(TransactionState.ACTIVE,owner.state);
            var rollback=fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.ROLLBACK).build());fixture.jobs.metadataRefresh().transaction(owner,SessionAction.ROLLBACK);
            assertTrue(rollback.getCommandAcknowledged());assertEquals(SessionAction.ROLLBACK,rollback.getAcknowledgedAction());assertFalse(owner.autoCommit);assertEquals(TransactionState.IDLE,owner.state);
            // This existing adapter witness reads pinned driver state only. A
            // catalog SELECT on the owner could start its manual PG transaction.
            assertEquals(TransactionState.IDLE,owner.adapter.transaction(owner.connection));var state=OwnerState.of(owner);var durable=platform.publishedSnapshot(owner);var owned=platform.capture(owner);long persisted=persistedRevision(fixture,owner);
            try{
                for(boolean preheld:List.of(false,true)){
                    connections.arm(Thread.currentThread(),owner);if(preheld){owner.lock.lock();owner.lock.lock();}int holds=owner.lock.getHoldCount();
                    try{
                        assertEquals(TransactionState.IDLE,owner.adapter.transaction(owner.connection));
                        assertEquals(WorkbenchFailure.Reason.UNAVAILABLE,assertThrows(WorkbenchFailure.class,()->tools.capture(owner,fixture.schema())).reason());
                        assertEquals(holds,owner.lock.getHoldCount());assertEquals(preheld,owner.lock.isHeldByCurrentThread());assertEquals(0,connections.opens.get());assertEquals(0,connections.nativeCalls.get());assertEquals(0,connections.schemaReads.get());
                        state.unchanged(owner);assertEquals(TransactionState.IDLE,owner.adapter.transaction(owner.connection),"Refused schema capture started a hidden native transaction");assertSame(durable,platform.publishedSnapshot(owner));assertSame(owned,platform.capture(owner));assertEquals(persisted,persistedRevision(fixture,owner));
                    }finally{if(preheld){owner.lock.unlock();owner.lock.unlock();}connections.foreground.set(null);}
                    assertEquals(0,owner.lock.getHoldCount());
                }
            }finally{
                connections.foreground.set(null);fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.AUTO_COMMIT_ON).build());
            }
            assertTrue(owner.autoCommit);assertEquals(TransactionState.IDLE,owner.adapter.transaction(owner.connection));assertFalse(owner.connection.isClosed());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void manualCaptureKeepsItsPhysicalLeaseAndUncommittedRowsInAnOwnedOverlay(String engine)throws Exception {
        var connections=new Connections();try(var fixture=new EngineFixture(root,engine,connections::open)){
            var owner=fixture.open();var observer=fixture.open();var platform=fixture.metadata.metadataPlatform();var tools=new SchemaTools(platform);
            boolean pg=fixture.engine==Engine.POSTGRESQL;
            if(!pg)fixture.execute(owner,"SET SESSION sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'");
            var original=seed(fixture,owner,tools);String table=owner.adapter.table(owner.context.catalog(),fixture.schema(),TABLE);
            fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.BEGIN).build());fixture.jobs.metadataRefresh().transaction(owner,SessionAction.BEGIN);
            try{
                fixture.execute(owner,"INSERT INTO "+table+"(id,n) VALUES(41,7)");assertEquals("0",scalar(fixture,observer,"SELECT COUNT(*) FROM "+table));var state=OwnerState.of(owner);
                try(var writer=new CacheWriter(fixture,observer)){
                    var held=platform.publishedSnapshot(observer);long diskBefore=persistedRevision(fixture,owner);connections.arm(Thread.currentThread(),owner);owner.lock.lock();int count=owner.lock.getHoldCount();
                    try{
                        String nativeMode=owner.adapter.context(owner.connection).sqlMode();assertEquals(owner.context.sqlMode(),nativeMode);assertEquals(TransactionState.ACTIVE,owner.adapter.transaction(owner.connection));
                        if(!pg)assertEquals(Set.of("ANSI_QUOTES","NO_BACKSLASH_ESCAPES"),new HashSet<>(Arrays.asList(nativeMode.split(","))));
                        var captured=tools.capture(owner,fixture.schema());assertEquals(original,captured);artifact(captured,fixture);assertTrue(owner.lock.isHeldByCurrentThread());assertEquals(count,owner.lock.getHoldCount());
                        if(pg){assertEquals(0,connections.opens.get());assertEquals(0,connections.closes.get());assertEquals(Connections.Purpose.UNCLASSIFIED,connections.purpose.get());assertTrue(connections.trace.get().isEmpty());assertNull(connections.view.get());}
                        else connections.descriptorClosed(count,nativeMode);
                        assertTrue(connections.schemaReads.get()>0,"Manual capture must actually inspect its owned native connection");state.unchanged(owner);
                        assertEquals(nativeMode,owner.adapter.context(owner.connection).sqlMode(),"Private descriptor normalization must never change the owning SQL mode");assertEquals(TransactionState.ACTIVE,owner.adapter.transaction(owner.connection));assertEquals(count,owner.lock.getHoldCount());
                        var owned=platform.capture(owner);assertTrue(owned.revision()>held.revision());assertFalse(relation(owned,owner,fixture.schema()).properties().containsKey(MARKER));assertSame(held,platform.publishedSnapshot(observer));assertEquals("held writer",relation(platform.capture(observer),observer,fixture.schema()).properties().get(MARKER));assertEquals(diskBefore,persistedRevision(fixture,owner));writer.pending();
                        try(var statement=owner.connection.createStatement()){statement.setQueryTimeout(5);try(var rows=statement.executeQuery("SELECT COUNT(*) FROM "+table)){assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertFalse(rows.next());}}
                        var reply=settings(platform,owner);assertEquals(owner.id,reply.getSessionId());assertEquals(state.revision(),reply.getSessionRevision());assertEquals(owned.revision(),reply.getSnapshotRevision());assertEquals("WRITE_PENDING",reply.getCacheState());
                    }finally{owner.lock.unlock();connections.foreground.set(null);}
                    assertEquals("0",scalar(fixture,observer,"SELECT COUNT(*) FROM "+table));writer.pending();writer.finish();assertEquals(held.revision(),persistedRevision(fixture,owner));persistedMarker(fixture,owner,true);state.unchanged(owner);
                }
            }finally{
                fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.ROLLBACK).build());fixture.jobs.metadataRefresh().transaction(owner,SessionAction.ROLLBACK);
            }
            assertFalse(owner.autoCommit);assertFalse(owner.connection.isClosed());assertEquals(TransactionState.IDLE,owner.state);fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.AUTO_COMMIT_ON).build());assertEquals("0",scalar(fixture,owner,"SELECT COUNT(*) FROM "+table));assertEquals("0",scalar(fixture,observer,"SELECT COUNT(*) FROM "+table));assertTrue(owner.autoCommit);assertEquals(TransactionState.IDLE,owner.state);
        }
    }
}
