package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.Explorer;
import io.busystack.busydata.rpc.WorkbenchService;
import io.grpc.stub.StreamObserver;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.params.provider.CsvSource;
import static org.junit.jupiter.api.Assertions.*;

/** Native metadata gates control only ordering; rows always come from the pinned engine. */
class SmartQueuedRefreshIT {
    @TempDir Path root;
    private static Object invoke(Object target,Method method,Object[] arguments)throws Throwable{try{return method.invoke(target,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}}
    private static boolean catalogQuery(String sql){String lower=sql.toLowerCase(Locale.ROOT);return lower.contains("information_schema")||lower.contains("pg_class");}
    private static Object field(Object owner,String name)throws Exception {var member=owner.getClass().getDeclaredField(name);member.setAccessible(true);return member.get(owner);}
    /** Read only owned scheduling scalars; no production test hook or JDBC. */
    private static MetadataPlatform.QueuedRefreshOwner admitted(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception {
        var smart=fixture.jobs.metadataRefresh();synchronized(field(smart,"scheduled")){
            var intent=((Map<?,?>)field(smart,"ready")).get(session.id);assertNotNull(intent,"Known committed effects remain an explicit reconciliation intent");
            var owner=(MetadataPlatform.QueuedRefreshOwner)field(intent,"admittedOwner");assertNotNull(owner);
            assertEquals(session.revision,((Number)field(owner,"revision")).longValue(),"Admission must use the FINAL Jobs/command cleanup revision, not the earlier statement revision");
            assertEquals(session.contextRevision,((Number)field(owner,"context")).longValue());return owner;
        }
    }
    private static boolean hasReady(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session)throws Exception {var smart=fixture.jobs.metadataRefresh();synchronized(field(smart,"scheduled")){return ((Map<?,?>)field(smart,"ready")).containsKey(session.id);}}
    private static final class Reply<T> implements StreamObserver<T>{T value;Throwable error;public void onNext(T next){value=next;}public void onError(Throwable failure){error=failure;}public void onCompleted(){}}
    private static void command(WorkbenchService service,io.busystack.busydata.sessions.SessionRegistry.Session session,SessionAction action){
        var context=Context.newBuilder().setInstanceId(service.instance).setProtocolVersion(WorkbenchService.PROTOCOL).setRequestId(UUID.randomUUID().toString()).build();
        var request=SessionRequest.newBuilder().setContext(context).setSessionId(session.id).setAction(action).build();var approval=new Reply<Approval>();service.reviewSession(request,approval);assertNull(approval.error);
        var result=new Reply<SessionInfo>();service.session(request.toBuilder().setApprovalToken(approval.value.getToken()).build(),result);assertNull(result.error,()->String.valueOf(result.error));
    }
    private static final class Gate {
        final AtomicBoolean armed=new AtomicBoolean();final AtomicInteger connections=new AtomicInteger();
        final CountDownLatch[] entered={new CountDownLatch(1),new CountDownLatch(1),new CountDownLatch(1),new CountDownLatch(1)};
        final CountDownLatch[] release={new CountDownLatch(1),new CountDownLatch(1),new CountDownLatch(1),new CountDownLatch(1)};
        final AtomicBoolean failNext=new AtomicBoolean();
        final AtomicBoolean explicitArmed=new AtomicBoolean();
        final CountDownLatch explicitEntered=new CountDownLatch(1),explicitRelease=new CountDownLatch(1);
        final Map<String,AtomicInteger> byProfile=new ConcurrentHashMap<>();
        final Map<Integer,String> gateProfiles=new ConcurrentHashMap<>();
        final AtomicBoolean commandArmed=new AtomicBoolean();final CountDownLatch commandEntered=new CountDownLatch(1);
        final AtomicReference<Thread> contender=new AtomicReference<>();
        io.busystack.busydata.sessions.SessionRegistry.Session commandOwner;
        void awaitRead(int sequence,boolean explicit)throws SQLException,InterruptedException {
            if(explicit){explicitEntered.countDown();if(!explicitRelease.await(20,TimeUnit.SECONDS))throw new SQLTimeoutException("Fixture explicit metadata gate exceeded its bound");}
            else{
                if(failNext.compareAndSet(true,false))throw new SQLException("Controlled independent metadata failure","HY000");
                if(sequence<=entered.length){entered[sequence-1].countDown();if(!release[sequence-1].await(20,TimeUnit.SECONDS))throw new SQLTimeoutException("Fixture native metadata gate exceeded its bound");}
            }
        }
        Connection open(io.busystack.busydata.adapters.JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception {
            var physical=adapter.connect(request,port);
            int sequence=armed.get()&&request.getProfile().getReadOnly()&&Thread.currentThread().getName().startsWith("metadata-refresh-")?connections.incrementAndGet():0;
            if(sequence>0){byProfile.computeIfAbsent(request.getProfile().getId(),ignored->new AtomicInteger()).incrementAndGet();gateProfiles.put(sequence,request.getProfile().getId());}
            boolean explicit=request.getProfile().getReadOnly()&&Thread.currentThread().getName().startsWith("fixture-explicit-")&&explicitArmed.get();
            var once=new AtomicBoolean();
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object result=invoke(physical,method,args);
                if(method.getName().equals("getAutoCommit")&&Thread.currentThread().getName().startsWith("fixture-command-")&&commandArmed.compareAndSet(true,false)){
                    commandEntered.countDown();long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
                    while((contender.get()==null||!commandOwner.lock.hasQueuedThread(contender.get()))&&System.nanoTime()<deadline)java.util.concurrent.locks.LockSupport.parkNanos(100_000);
                    if(contender.get()==null||!commandOwner.lock.hasQueuedThread(contender.get()))throw new SQLTimeoutException("Fixture command contender did not queue on its physical owner");
                }
                if((sequence>0||explicit)&&method.getName().equals("getMetaData")){
                    var metadata=(DatabaseMetaData)result;
                    return Proxy.newProxyInstance(DatabaseMetaData.class.getClassLoader(),new Class[]{DatabaseMetaData.class},(proxyMetadata,operation,parameters)->{
                        if(operation.getName().equals("getExportedKeys")&&once.compareAndSet(false,true))awaitRead(sequence,explicit);
                        return invoke(metadata,operation,parameters);
                    });
                }
                if((sequence>0||explicit)&&method.getName().equals("prepareStatement")&&args[0] instanceof String sql&&catalogQuery(sql)){
                    var prepared=(PreparedStatement)result;
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(statement,operation,parameters)->{
                        if(operation.getName().equals("executeQuery")&&once.compareAndSet(false,true)){
                            awaitRead(sequence,explicit);
                        }
                        return invoke(prepared,operation,parameters);
                    });
                }return result;
            });
        }
        int connections(String profile){return byProfile.getOrDefault(profile,new AtomicInteger()).get();}
        void releaseAll(){explicitRelease.countDown();for(var latch:release)latch.countDown();}
    }
    private static io.busystack.busydata.sessions.SessionRegistry.Session marker(EngineFixture fixture,String id)throws Exception {
        var owner=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setId(id)).setPassword("fixture").build());
        var platform=fixture.metadata.metadataPlatform();var before=platform.configuration(owner);
        platform.configure(owner,new MetadataConfiguration(before.revision()+1,Set.of("busydata"),Set.of(),Set.of(fixture.schema()),Set.of(),false,Set.of(ObjectKind.TABLE,ObjectKind.COLUMN),List.of(),List.of(),IntrospectionLevel.STRUCTURE,Map.of()));
        return owner;
    }
    private static void setup(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session owner)throws Exception {
        owner.lock.lock();try{try(var command=owner.connection.createStatement()){command.execute("CREATE TABLE queued_rows(id INTEGER PRIMARY KEY)");}owner.refresh();owner.advanceRevision();}finally{owner.lock.unlock();}
        var platform=fixture.metadata.metadataPlatform();var before=platform.configuration(owner);
        platform.configure(owner,new MetadataConfiguration(before.revision()+1,Set.of("busydata"),Set.of(),Set.of(fixture.schema()),Set.of(),false,Set.of(ObjectKind.TABLE,ObjectKind.COLUMN),List.of(),List.of(),IntrospectionLevel.STRUCTURE,Map.of()));
        fixture.warm(owner,"queued_rows");
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void aQueuedEffectCannotReserveAfterAnExplicitRefreshStartsBeforeItPublishes(String engine)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::open);var explicit=Executors.newThreadPerTaskExecutor(Thread.ofVirtual().name("fixture-explicit-",0).factory())){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();var explorer=new Explorer(platform);
                var occupied=marker(fixture,"occupied-worker");var barrier=marker(fixture,"after-queued-batch");var drained=marker(fixture,"after-retired-attempts");var afterRead=marker(fixture,"after-explicit-read");
                gate.armed.set(true);fixture.jobs.metadataRefresh().connected(occupied);
                assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS),"The first native metadata task occupies the single Smart worker");
                fixture.execute(owner,"ALTER TABLE queued_rows ADD COLUMN added INTEGER");
                var originalOwner=admitted(fixture,owner);assertEquals(JobState.COMPLETED,fixture.execute(owner,"SELECT 1").state);var latestOwner=admitted(fixture,owner);assertNotSame(originalOwner,latestOwner);
                assertEquals(1,gate.connections.get(),"The acknowledged effect is queued behind the earlier metadata task");
                long published=platform.publicationRevision(owner).revision();gate.explicitArmed.set(true);
                var acquired=explicit.submit(()->explorer.refreshFragment(owner,"busydata",fixture.schema(),"queued_rows",ObjectKind.TABLE));
                assertTrue(gate.explicitEntered.await(10,TimeUnit.SECONDS),"The explicit fragment reserved before its incoming-dependency native query");
                assertEquals(published,platform.publicationRevision(owner).revision(),"Reservation must fence Smart even before any newer publication exists");
                fixture.jobs.metadataRefresh().connected(barrier);gate.release[0].countDown();
                assertTrue(gate.entered[1].await(15,TimeUnit.SECONDS));fixture.jobs.metadataRefresh().connected(drained);gate.release[1].countDown();
                assertTrue(gate.entered[2].await(15,TimeUnit.SECONDS),"The later native task proves both old and newly settled attempts were refused by explicit reservation");
                assertEquals(0,gate.connections(fixture.profile.getId()),"The obsolete owner cannot open even its first metadata connection");
                assertEquals(published,platform.publicationRevision(owner).revision());
                gate.explicitRelease.countDown();var refreshed=acquired.get(20,TimeUnit.SECONDS);
                var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);
                assertTrue(refreshed.complete(scope,IntrospectionLevel.STRUCTURE));assertEquals(1,refreshed.resolve("busydata",fixture.schema(),ObjectKind.COLUMN,"queued_rows","added",true).size());
                assertSame(refreshed,platform.capture(owner));assertEquals(JobState.COMPLETED,fixture.execute(owner,"SELECT 1").state);assertFalse(hasReady(fixture,owner),"An explicit publication prevents a later read settlement from reviving the old intent");
                fixture.jobs.metadataRefresh().connected(afterRead);gate.release[2].countDown();assertTrue(gate.entered[3].await(15,TimeUnit.SECONDS));assertEquals(0,gate.connections(fixture.profile.getId()));assertSame(refreshed,platform.capture(owner));
                assertEquals(3,fixture.jobs.list(owner.id).size(),"Only the explicit ALTER and two user reads are SQL; metadata never replays them");
            }finally{gate.releaseAll();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void anAcquiredOldTaskCannotReplaceOrPoisonANewerExplicitPublication(String engine)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::open)){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();var explorer=new Explorer(platform);var barrier=marker(fixture,"after-inflight-batch");
                gate.armed.set(true);fixture.jobs.metadataRefresh().connected(owner);assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS));
                var explicit=explorer.refreshFragment(owner,"busydata",fixture.schema(),"queued_rows",ObjectKind.TABLE);var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);var coverage=explicit.catalogCoverage().get(scope);var diagnostics=platform.diagnostics(owner).orElseThrow();
                fixture.jobs.metadataRefresh().connected(barrier);gate.release[0].countDown();assertTrue(gate.entered[1].await(15,TimeUnit.SECONDS));
                assertSame(explicit,platform.capture(owner),"The old acquired task cannot publish a new snapshot or stale the explicit one");assertSame(coverage,platform.capture(owner).catalogCoverage().get(scope));assertSame(diagnostics,platform.diagnostics(owner).orElseThrow());
                long revision=owner.revision;assertEquals(JobState.COMPLETED,fixture.execute(owner,"SELECT 1").state);assertTrue(owner.revision>revision);assertTrue(explicit.complete(scope,IntrospectionLevel.STRUCTURE));assertEquals(1,fixture.jobs.list(owner.id).size());
            }finally{gate.releaseAll();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void acknowledgedNewDdlWhileRunningKeepsItsOwnQueuedOwnerAndPublishesItsNewStructure(String engine)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::open)){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();var barrier=marker(fixture,"after-new-effect");
                gate.armed.set(true);fixture.jobs.metadataRefresh().connected(owner);assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS));
                fixture.execute(owner,"ALTER TABLE queued_rows ADD COLUMN added INTEGER");var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);assertFalse(platform.capture(owner).complete(scope,IntrospectionLevel.STRUCTURE));
                admitted(fixture,owner);
                gate.release[0].countDown();assertTrue(gate.entered[1].await(15,TimeUnit.SECONDS),"The separately acknowledged new effect acquires with its original admission owner");
                fixture.jobs.metadataRefresh().connected(barrier);gate.release[1].countDown();assertTrue(gate.entered[2].await(15,TimeUnit.SECONDS),"The fragment acquires its structural connection after dependency discovery");
                gate.release[2].countDown();assertTrue(gate.entered[3].await(15,TimeUnit.SECONDS),"The later worker barrier proves the new effect completed");
                var current=platform.capture(owner);assertTrue(current.complete(scope,IntrospectionLevel.STRUCTURE));assertEquals(1,current.resolve("busydata",fixture.schema(),ObjectKind.COLUMN,"queued_rows","added",true).size());assertEquals(1,fixture.jobs.list(owner.id).size());
            }finally{gate.releaseAll();}
        }
    }
    @ParameterizedTest @CsvSource({"POSTGRESQL,false","MYSQL,false","MARIADB,false","POSTGRESQL,true","MYSQL,true","MARIADB,true"})
    void aRealReadSettlementAdmitsANewAttemptWithoutRebasingTheRetiredOwner(String engine,boolean inFlight)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::open)){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();var occupied=marker(fixture,"read-occupied-worker");var barrier=marker(fixture,"after-read-settlement");
                gate.armed.set(true);
                if(!inFlight){fixture.jobs.metadataRefresh().connected(occupied);assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS));}
                fixture.execute(owner,"ALTER TABLE queued_rows ADD COLUMN added INTEGER");var retired=admitted(fixture,owner);
                if(inFlight)assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS),"The old admitted attempt is inside its native dependency query");
                assertEquals(JobState.COMPLETED,fixture.execute(owner,"SELECT 1").state);var replacement=admitted(fixture,owner);assertNotSame(retired,replacement);
                assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(owner,retired),"The old immutable owner remains invalid");
                gate.release[0].countDown();assertTrue(gate.entered[1].await(15,TimeUnit.SECONDS),"A NEW real settlement, not worker-finally recapture, admits the pending committed effect");
                fixture.jobs.metadataRefresh().connected(barrier);gate.release[1].countDown();assertTrue(gate.entered[2].await(15,TimeUnit.SECONDS));gate.release[2].countDown();assertTrue(gate.entered[3].await(15,TimeUnit.SECONDS));
                var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);var snapshot=platform.capture(owner);
                assertTrue(snapshot.complete(scope,IntrospectionLevel.STRUCTURE));assertEquals(1,snapshot.resolve("busydata",fixture.schema(),ObjectKind.COLUMN,"queued_rows","added",true).size());
                assertEquals(inFlight?3:2,gate.connections(fixture.profile.getId()),"Only the old in-flight dependency, if any, and the new fragment's two native connections ran");
                assertFalse(hasReady(fixture,owner));assertEquals(2,fixture.jobs.list(owner.id).size(),"User ALTER/SELECT each ran once");
            }finally{gate.releaseAll();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void rollbackPreservesPriorCommittedIntentIncludingImplicitDdlCommitAndOwnedTemps(String engine)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::open)){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();
                if(fixture.engine==Engine.POSTGRESQL){fixture.execute(owner,"CREATE TEMPORARY TABLE kept_temp(id INTEGER)");fixture.warm(owner,"queued_rows");}
                else {fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.AUTO_COMMIT_OFF).build());fixture.jobs.metadataRefresh().transaction(owner,SessionAction.AUTO_COMMIT_OFF);}
                var occupied=marker(fixture,"rollback-occupied-worker");var barrier=marker(fixture,"after-committed-rollback");
                gate.armed.set(true);fixture.jobs.metadataRefresh().connected(occupied);assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS));
                int jobsBefore=fixture.jobs.list(owner.id).size();
                fixture.execute(owner,(fixture.engine==Engine.POSTGRESQL?"":"START TRANSACTION; ")+"ALTER TABLE queued_rows ADD COLUMN added INTEGER");
                assertEquals(TransactionState.IDLE,owner.state,"MySQL/MariaDB ALTER really acknowledged its implicit commit");var beforeRollback=admitted(fixture,owner);
                fixture.execute(owner,fixture.engine==Engine.POSTGRESQL?"BEGIN; ROLLBACK":"ROLLBACK");var afterRollback=admitted(fixture,owner);assertNotSame(beforeRollback,afterRollback);
                gate.release[0].countDown();assertTrue(gate.entered[1].await(15,TimeUnit.SECONDS));fixture.jobs.metadataRefresh().connected(barrier);gate.release[1].countDown();assertTrue(gate.entered[2].await(15,TimeUnit.SECONDS));gate.release[2].countDown();assertTrue(gate.entered[3].await(15,TimeUnit.SECONDS));
                var current=platform.capture(owner);var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);
                assertTrue(current.complete(scope,IntrospectionLevel.STRUCTURE));assertEquals(1,current.resolve("busydata",fixture.schema(),ObjectKind.COLUMN,"queued_rows","added",true).size());
                if(fixture.engine==Engine.POSTGRESQL)assertTrue(current.identities().values().stream().anyMatch(object->object.identity().sessionOwner().equals(owner.id)&&object.identity().name().equals("kept_temp")),"Owned rollback maintenance preserves the actual temporary table");
                assertEquals(jobsBefore+2,fixture.jobs.list(owner.id).size());assertFalse(hasReady(fixture,owner));
            }finally{gate.releaseAll();}
        }
    }
    private static MetadataSnapshot awaitTransactionPublication(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session owner,boolean commit,Gate gate)throws Exception{
        var platform=fixture.metadata.metadataPlatform();var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(15);MetadataSnapshot current;
        do{
            current=platform.capture(owner);
            if(current.complete(scope,IntrospectionLevel.STRUCTURE)&&current.resolve("busydata",fixture.schema(),ObjectKind.COLUMN,"queued_rows","added",true).size()==(commit?1:0)&&!hasReady(fixture,owner))return current;
            Thread.sleep(10);
        }while(System.nanoTime()<deadline);
        var durable=platform.publishedSnapshot(owner);var owned=current.coverage(scope).orElse(null);var global=durable.coverage(scope).orElse(null);
        fail("Acknowledged transaction did not publish exact expected structure after all native gates were released; commit="+commit+"; gateProfiles="+gate.gateProfiles+"; ownerConnections="+gate.connections(fixture.profile.getId())+"; snapshot="+current.revision()+"; publication="+durable.revision()+"; ownedCoverage="+owned+"; durableCoverage="+global+"; physicalResolution="+current.sessionResolution().state()+"; overlays="+platform.sessionOverlayCount()+"; ready="+hasReady(fixture,owner)+"; jobs="+fixture.jobs.list(owner.id));return current;
    }
    @ParameterizedTest @ValueSource(booleans={false,true})
    void postgresManualTransactionOnlyPromotesAcknowledgedCommit(boolean commit)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",gate::open)){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();var occupied=marker(fixture,"transaction-occupied-worker");var barrier=marker(fixture,"after-transaction-boundary");
                gate.armed.set(true);fixture.jobs.metadataRefresh().connected(occupied);assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS));
                fixture.execute(owner,"BEGIN; ALTER TABLE queued_rows ADD COLUMN added INTEGER");assertEquals(TransactionState.ACTIVE,owner.state);assertFalse(hasReady(fixture,owner));assertEquals(0,gate.connections(fixture.profile.getId()));
                fixture.execute(owner,commit?"COMMIT":"ROLLBACK");assertEquals(TransactionState.IDLE,owner.state);
                if(commit)admitted(fixture,owner);else assertFalse(hasReady(fixture,owner));
                fixture.jobs.metadataRefresh().connected(barrier);gate.release[0].countDown();
                // ACK and cleanup admit distinct immutable revisions. An old
                // queued ACK attempt can retire before JDBC, appending its real
                // cleanup replacement behind the marker already in the FIFO.
                // Gate position is therefore not proof of which task finished.
                for(int index=1;index<=(commit?3:1);index++){
                    assertTrue(gate.entered[index].await(15,TimeUnit.SECONDS),()->"Every expected native phase must enter its bounded gate; profiles="+gate.gateProfiles);
                    gate.release[index].countDown();
                }
                var current=awaitTransactionPublication(fixture,owner,commit,gate);
                assertEquals(commit?2:0,gate.connections(fixture.profile.getId()),"Only committed work opens its dependency and structure metadata connections");
                owner.lock.lock();try(var rows=owner.connection.getMetaData().getColumns("busydata",fixture.schema(),"queued_rows","added")){assertEquals(commit,rows.next(),"The real engine's transactional DDL agrees with the published state");}finally{owner.lock.unlock();}
                assertEquals(2,fixture.jobs.list(owner.id).size());assertFalse(hasReady(fixture,owner));
            }finally{gate.releaseAll();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void reviewedCommitAdmitsItsIntentBeforeAQueuedPhysicalBeginCanRun(String engine)throws Exception {
        var gate=new Gate();var rollbackAllowed=new CountDownLatch(1);var began=new CountDownLatch(1);
        try(var fixture=new EngineFixture(root,engine,gate::open);var commands=Executors.newThreadPerTaskExecutor(Thread.ofVirtual().name("fixture-command-",0).factory())){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();var occupied=marker(fixture,"rpc-occupied-worker");var barrier=marker(fixture,"after-reviewed-command");
                var service=new WorkbenchService(fixture.sessions,fixture.jobs,fixture.results,fixture.metadata,fixture.safety,fixture.analysis,()->{});
                gate.armed.set(true);fixture.jobs.metadataRefresh().connected(occupied);assertTrue(gate.entered[0].await(10,TimeUnit.SECONDS));
                fixture.execute(owner,"BEGIN; ALTER TABLE queued_rows ADD COLUMN added INTEGER");assertFalse(hasReady(fixture,owner));
                gate.commandOwner=owner;gate.commandArmed.set(true);
                var contender=commands.submit(()->{
                    gate.contender.set(Thread.currentThread());assertTrue(gate.commandEntered.await(10,TimeUnit.SECONDS));owner.lock.lockInterruptibly();
                    try{admitted(fixture,owner);command(service,owner,SessionAction.BEGIN);began.countDown();assertTrue(rollbackAllowed.await(15,TimeUnit.SECONDS));command(service,owner,SessionAction.ROLLBACK);admitted(fixture,owner);}finally{owner.lock.unlock();}return null;
                });
                var committed=commands.submit(()->{command(service,owner,SessionAction.COMMIT);return null;});committed.get(20,TimeUnit.SECONDS);assertTrue(began.await(10,TimeUnit.SECONDS));rollbackAllowed.countDown();contender.get(20,TimeUnit.SECONDS);
                gate.release[0].countDown();assertTrue(gate.entered[1].await(15,TimeUnit.SECONDS));fixture.jobs.metadataRefresh().connected(barrier);gate.release[1].countDown();assertTrue(gate.entered[2].await(15,TimeUnit.SECONDS));gate.release[2].countDown();assertTrue(gate.entered[3].await(15,TimeUnit.SECONDS));
                var snapshot=platform.capture(owner);assertTrue(snapshot.complete(new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));assertEquals(1,snapshot.resolve("busydata",fixture.schema(),ObjectKind.COLUMN,"queued_rows","added",true).size());assertEquals(1,fixture.jobs.list(owner.id).size(),"Reviewed transaction controls are not replayed SQL jobs");
            }finally{rollbackAllowed.countDown();gate.releaseAll();}
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void immutableOwnersFenceReservationsConfigurationExecutionContextAndPhysicalSession(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)){
            var owner=fixture.open();setup(fixture,owner);var other=fixture.open();var platform=fixture.metadata.metadataPlatform();var snapshot=platform.capture(owner);var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);
            var queued=platform.queuedRefreshOwner(owner);assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(other,queued));
            var acquired=platform.reserveQueuedRefresh(owner,queued);platform.reserveRefresh(owner);
            assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.checkRefreshReservation(owner,acquired));
            assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.publish(owner,acquired,snapshot.rules(),Map.of(),null));
            assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(owner,queued));
            platform.markStaleIfQueuedOwner(owner,queued,"An obsolete queue admission failed");platform.markStaleIfRefreshReservation(owner,acquired,"An obsolete reserved task failed");assertSame(snapshot,platform.capture(owner));assertTrue(snapshot.complete(scope,IntrospectionLevel.STRUCTURE));
            owner.lock.lock();try{
                var effect=DdlEffect.newBuilder().setCatalog("busydata").setSchema(fixture.schema()).setName("queued_rows").setKind(ObjectKind.TABLE).setOperation("ALTER").build();
                var intent=platform.invalidateForReconciliation(owner,List.of(effect),"Known committed structure requires reconciliation");var oldAttempt=platform.settledReconciliationOwner(owner,intent);
                try(var maintenance=platform.ownedMaintenance(owner)){assertThrows(IllegalStateException.class,()->platform.ownedMaintenance(owner));platform.beginRefresh(owner);}
                assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(owner,oldAttempt),"Owned maintenance still retires an old exact-ticket attempt");
                assertNotNull(platform.settledReconciliationOwner(owner,intent),"A new real settlement may retain known intent across owned maintenance");
                platform.beginRefresh(owner);try(var maintenance=platform.ownedMaintenance(owner)){platform.beginRefresh(owner);}
                assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.settledReconciliationOwner(owner,intent),"A later owned ticket cannot conceal an intervening explicit reservation");
            }finally{owner.lock.unlock();}
            var execution=platform.queuedRefreshOwner(owner);assertEquals(JobState.COMPLETED,fixture.execute(owner,"SELECT 1").state);assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(owner,execution));
            var context=platform.queuedRefreshOwner(owner);owner.lock.lock();try{owner.contextRevision++;}finally{owner.lock.unlock();}assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(owner,context));
            var configuration=platform.queuedRefreshOwner(owner);var before=platform.configuration(owner);platform.configure(owner,new MetadataConfiguration(before.revision()+1,before.includedCatalogs(),before.excludedCatalogs(),before.includedSchemas(),before.excludedSchemas(),before.systemObjects(),before.kinds(),before.includePatterns(),before.excludePatterns(),before.defaultLevel(),before.scopeLevels()));
            assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(owner,configuration));
            var ended=platform.queuedRefreshOwner(owner);owner.close();assertThrows(MetadataPlatform.SupersededRefresh.class,()->platform.reserveQueuedRefresh(owner,ended));assertTrue(snapshot.complete(scope,IntrospectionLevel.STRUCTURE),"Held reader snapshots remain immutable through every owner change");
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void anEmptyConnectedRefreshFailureWithoutANewerPublicationStillMarksCachedCoverageStale(String engine)throws Exception {
        var gate=new Gate();
        try(var fixture=new EngineFixture(root,engine,gate::open)){
            try{
                var owner=fixture.open();setup(fixture,owner);var platform=fixture.metadata.metadataPlatform();
                var scope=new MetadataScope("busydata",fixture.schema(),"queued_rows",ObjectKind.COLUMN);assertTrue(platform.capture(owner).complete(scope,IntrospectionLevel.STRUCTURE));
                gate.failNext.set(true);gate.armed.set(true);fixture.jobs.metadataRefresh().connected(owner);
                long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(10);
                while(platform.capture(owner).coverage(scope).orElseThrow().state()!=MetadataState.STALE&&System.nanoTime()<deadline)Thread.sleep(10);
                assertEquals(MetadataState.STALE,platform.capture(owner).coverage(scope).orElseThrow().state());assertFalse(platform.capture(owner).complete(scope,IntrospectionLevel.STRUCTURE));assertTrue(fixture.jobs.list(owner.id).isEmpty());
            }finally{gate.releaseAll();}
        }
    }
}
