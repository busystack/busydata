package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import java.util.concurrent.locks.LockSupport;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real PostgreSQL owner and SQLite operations; catalog facts are synthetic.
 * Gates pause native cache COMMIT and the real essential preference CAS only. */
class MetadataCacheTerminalOwnershipIT {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static final String CONFIGURATION_CAS="INSERT INTO metadata_configuration VALUES(?,?,?) ON CONFLICT(source) DO UPDATE SET revision=excluded.revision,payload=excluded.payload WHERE metadata_configuration.revision=?";
    private static long until(){return System.nanoTime()+TimeUnit.SECONDS.toNanos(10);}
    private static Object invoke(Object target,Method method,Object[] arguments)throws Throwable{
        try{return method.invoke(target,arguments);}catch(InvocationTargetException failure){throw failure.getCause();}
    }
    private static void gate(CountDownLatch release)throws SQLException{
        try{if(!release.await(20,TimeUnit.SECONDS))throw new SQLTimeoutException("Owned cache fixture gate was not released","57014");}
        catch(InterruptedException interrupted){Thread.currentThread().interrupt();throw new SQLTransientException("Owned cache fixture gate interrupted","57014",interrupted);}
    }
    private static final class CommitGate {
        final AtomicBoolean armed=new AtomicBoolean();final AtomicInteger opens=new AtomicInteger();
        final CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);
        Connection open(Path file,Properties options)throws SQLException{
            opens.incrementAndGet();return new GatedConnection(file,options,this);
        }
    }
    /** Actual SQLiteConnection subclass: native handlers reject generic proxies. */
    private static final class GatedConnection extends org.sqlite.jdbc4.JDBC4Connection {
        private final CommitGate gate;
        GatedConnection(Path file,Properties options,CommitGate gate)throws SQLException{super("jdbc:sqlite:"+file,file.toString(),options);this.gate=gate;}
        @Override public void setAutoCommit(boolean enabled)throws SQLException{
            if(gate!=null&&enabled&&!super.getAutoCommit()&&gate.armed.compareAndSet(true,false)){
                gate.entered.countDown();gate(gate.release);
            }
            super.setAutoCommit(enabled);
        }
    }
    private static final class PolicyGate {
        final AtomicBoolean armed=new AtomicBoolean();final AtomicInteger attempts=new AtomicInteger();boolean fail;
        final CountDownLatch entered=new CountDownLatch(1),release=new CountDownLatch(1);
        Connection decorate(Connection connection){
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class<?>[]{Connection.class},(proxy,method,arguments)->{
                var result=invoke(connection,method,arguments);
                if(method.getName().equals("prepareStatement")&&arguments!=null&&arguments.length>0&&CONFIGURATION_CAS.equals(arguments[0])){
                    var statement=(PreparedStatement)result;
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class<?>[]{PreparedStatement.class},(unused,operation,values)->{
                        if(operation.getName().equals("executeUpdate")){
                            attempts.incrementAndGet();if(armed.compareAndSet(true,false)){entered.countDown();gate(release);if(fail)throw new SQLTransactionRollbackException("Owned preference CAS fixture refusal","40001");}
                        }
                        return invoke(statement,operation,values);
                    });
                }
                return result;
            });
        }
    }
    private static Map<MetadataScope,MetadataPlatform.Branch> branch(SessionRegistry.Session owner,String name){
        var scope=new MetadataScope(owner.context.catalog(),"terminal_fixture","",ObjectKind.TABLE);
        var object=SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog(owner.context.catalog()).setSchema(scope.schema()).setName(name).putProperties("nativeId",name).build();
        var coverage=new MetadataCoverage(scope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,name,owner.revision,owner.contextRevision,System.currentTimeMillis(),"");
        return Map.of(scope,new MetadataPlatform.Branch(List.of(object),coverage));
    }
    private static MetadataRepository.WriteReceipt receipt(MetadataPlatform platform,SessionRegistry.Session owner){
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(3);
        do{var receipt=platform.cacheWriteReceipt(owner);if(receipt.isPresent())return receipt.orElseThrow();LockSupport.parkNanos(TimeUnit.MILLISECONDS.toNanos(1));}while(System.nanoTime()<deadline);
        throw new AssertionError("Exact cache receipt was not registered");
    }
    private static void identity(MetadataRepository.WriteReceipt receipt,MetadataSnapshot snapshot,SessionRegistry.Session owner){
        var id=receipt.identity();assertTrue(id.attemptId()>0);assertTrue(id.sourceOwner()>0);assertTrue(id.matches(snapshot));assertEquals(owner.metadataSourceIdentity,id.source());assertEquals(owner.profile.getId(),id.profileId());
        assertEquals(snapshot.revision(),id.snapshotRevision());assertEquals(snapshot.configurationRevision(),id.configurationRevision());assertEquals(snapshot.rules().fingerprint(),id.rulesFingerprint());
    }
    private static MetadataConfiguration next(MetadataConfiguration value){
        var excluded=new HashSet<>(value.excludedSchemas());excluded.add("unrelated_terminal_fixture");
        return new MetadataConfiguration(value.revision()+1,value.includedCatalogs(),value.excludedCatalogs(),value.includedSchemas(),excluded,value.systemObjects(),value.kinds(),value.includePatterns(),value.excludePatterns(),value.defaultLevel(),value.scopeLevels());
    }
    private static void physicalFree(SessionRegistry.Session owner)throws Exception{
        assertTrue(owner.lock.tryLock(500,TimeUnit.MILLISECONDS),"Cache terminal ownership must not retain the PostgreSQL command lease");owner.lock.unlock();
    }
    private static void stop(ExecutorService workers,CommitGate cache,PolicyGate policy)throws Exception{
        cache.release.countDown();policy.release.countDown();workers.shutdownNow();assertTrue(workers.awaitTermination(10,TimeUnit.SECONDS),"Owned fixture workers did not terminate");
    }

    @ParameterizedTest @ValueSource(booleans={false,true})
    void essentialConfigurationCasRemainsIndependentAndOldCompletionCannotMisreportItsOutcome(boolean failCas)throws Exception{
        var cache=new CommitGate();var policy=new PolicyGate();var workers=Executors.newFixedThreadPool(2);
        try(var fixture=new EngineFixture(root.resolve("physical"),"POSTGRESQL");var store=new MetadataStore(root.resolve("policy"),policy::decorate)){
            try{
                var owner=fixture.open();var platform=MetadataCacheTestAccess.platform(store,cache::open);var before=platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"prior"),false);
                receipt(platform,owner).await(until());var configuration=platform.configuration(owner);var next=next(configuration);long physicalRevision=owner.revision,contextRevision=owner.contextRevision;var state=owner.state;boolean autoCommit=owner.autoCommit;
                cache.armed.set(true);var publication=workers.submit(()->platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"blocked"),false));
                assertTrue(cache.entered.await(5,TimeUnit.SECONDS));var blocked=platform.publishedSnapshot(owner);var oldReceipt=receipt(platform,owner);identity(oldReceipt,blocked,owner);assertTrue(blocked.revision()>before.revision());assertTrue(oldReceipt.active());physicalFree(owner);
                int connections=cache.opens.get();policy.fail=failCas;policy.armed.set(true);var configure=workers.submit(()->{platform.configure(owner,next);return true;});
                assertTrue(policy.entered.await(5,TimeUnit.SECONDS),"Essential CAS must execute while the older native cache COMMIT is blocked");
                assertEquals(configuration,platform.configuration(owner));assertSame(blocked,platform.publishedSnapshot(owner));assertEquals(MetadataState.STALE,platform.proofAdmissionState(owner,platform.proofFence(owner)));physicalFree(owner);
                if(failCas){
                    cache.release.countDown();var completion=oldReceipt.awaitCompletion(until());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,completion.metrics().commitOutcome());assertNull(completion.failure());publication.get(5,TimeUnit.SECONDS);
                    policy.release.countDown();var failure=assertThrows(ExecutionException.class,()->configure.get(5,TimeUnit.SECONDS));assertEquals("40001",assertInstanceOf(SQLException.class,failure.getCause()).getSQLState());
                    assertSame(blocked,platform.publishedSnapshot(owner));assertEquals(configuration,platform.configuration(owner));assertTrue(store.metadataConfigurations().isEmpty());
                    assertEquals("AVAILABLE",platform.cacheState(owner),"A failed essential CAS must settle the older still-current successful cache completion");assertTrue(platform.cacheFailure(owner).isEmpty());assertTrue(platform.cacheWriteMetrics(owner).orElseThrow().matches(blocked));
                }else{
                    policy.release.countDown();assertTrue(configure.get(5,TimeUnit.SECONDS));var configured=platform.publishedSnapshot(owner);assertEquals(next,platform.configuration(owner));assertEquals(next,store.metadataConfigurations().get(owner.metadataSourceIdentity));
                    assertTrue(configured.revision()>blocked.revision());assertEquals(next.revision(),configured.configurationRevision());assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner));var newerFailure=platform.cacheFailure(owner).orElseThrow();assertFalse(oldReceipt.identity().matches(configured));assertTrue(platform.cacheWriteReceipt(owner).isEmpty());
                    cache.release.countDown();var completion=oldReceipt.awaitCompletion(until());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,completion.metrics().commitOutcome());assertNull(completion.failure());publication.get(5,TimeUnit.SECONDS);
                    assertSame(configured,platform.publishedSnapshot(owner));assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner));assertEquals(newerFailure,platform.cacheFailure(owner).orElseThrow());assertTrue(platform.cacheWriteMetrics(owner).isEmpty());
                }
                assertEquals(1,policy.attempts.get());assertEquals(connections,cache.opens.get(),"Rejected cache persistence must not open another native connection");assertEquals(physicalRevision,owner.revision);assertEquals(contextRevision,owner.contextRevision);assertEquals(state,owner.state);assertEquals(autoCommit,owner.autoCommit);physicalFree(owner);
            }finally{stop(workers,cache,policy);}
        }
    }

    @Test void lateAcknowledgementCannotClearANewerRejectedPublicationOrAlterItsCurrentModel()throws Exception{
        var cache=new CommitGate();var policy=new PolicyGate();var workers=Executors.newFixedThreadPool(2);
        try(var fixture=new EngineFixture(root.resolve("physical"),"POSTGRESQL");var store=new MetadataStore(root.resolve("policy"))){
            try{
                var owner=fixture.open();var platform=MetadataCacheTestAccess.platform(store,cache::open);platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"prior"),false);receipt(platform,owner).await(until());
                cache.armed.set(true);var older=workers.submit(()->platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"blocked"),false));assertTrue(cache.entered.await(5,TimeUnit.SECONDS));var blocked=platform.publishedSnapshot(owner);var oldReceipt=receipt(platform,owner);identity(oldReceipt,blocked,owner);int connections=cache.opens.get();
                var newer=workers.submit(()->platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"newer"),false)).get(5,TimeUnit.SECONDS);assertTrue(newer.revision()>blocked.revision());assertEquals("newer",newer.objects().getFirst().getName());assertFalse(oldReceipt.identity().matches(newer));
                assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner));var failure=platform.cacheFailure(owner).orElseThrow();assertTrue(platform.cacheWriteReceipt(owner).isEmpty());assertTrue(oldReceipt.active());physicalFree(owner);
                cache.release.countDown();var terminal=oldReceipt.awaitCompletion(until());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,terminal.metrics().commitOutcome());assertNull(terminal.failure());older.get(5,TimeUnit.SECONDS);
                assertSame(newer,platform.publishedSnapshot(owner));assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner));assertEquals(failure,platform.cacheFailure(owner).orElseThrow());assertTrue(platform.cacheWriteMetrics(owner).isEmpty());assertEquals(connections,cache.opens.get());
                try(var db=DriverManager.getConnection("jdbc:sqlite:"+store.root().resolve("metadata_catalog.sqlite"));var query=db.prepareStatement("SELECT revision,configuration_revision FROM publication WHERE source=?")){
                    query.setString(1,oldReceipt.identity().source());try(var rows=query.executeQuery()){assertTrue(rows.next());assertEquals(blocked.revision(),rows.getLong(1));assertEquals(blocked.configurationRevision(),rows.getLong(2));assertFalse(rows.next());}
                }
            }finally{stop(workers,cache,policy);}
        }
    }

    @Test void invalidationWithoutANewCacheSubmissionCannotBecomePendingOrAvailableAfterAnOlderAcknowledgement()throws Exception{
        var cache=new CommitGate();var policy=new PolicyGate();var workers=Executors.newFixedThreadPool(2);
        try(var fixture=new EngineFixture(root.resolve("physical"),"POSTGRESQL");var store=new MetadataStore(root.resolve("policy"))){
            try{
                var owner=fixture.open();var platform=MetadataCacheTestAccess.platform(store,cache::open);platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"prior"),false);receipt(platform,owner).await(until());
                cache.armed.set(true);var publication=workers.submit(()->platform.publish(owner,platform.beginRefresh(owner),RULES,branch(owner,"blocked"),false));assertTrue(cache.entered.await(5,TimeUnit.SECONDS));var blocked=platform.publishedSnapshot(owner);var oldReceipt=receipt(platform,owner);identity(oldReceipt,blocked,owner);int connections=cache.opens.get();
                platform.markStale(owner,"Owned external DDL invalidation fixture");var stale=platform.publishedSnapshot(owner);assertTrue(stale.revision()>blocked.revision());assertEquals(blocked.identities(),stale.identities());assertTrue(stale.coverage().values().stream().allMatch(value->value.state()==MetadataState.STALE&&!value.complete()));
                assertFalse(oldReceipt.identity().matches(stale));assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner));assertTrue(platform.cacheWriteReceipt(owner).isEmpty());assertTrue(oldReceipt.active());physicalFree(owner);
                cache.release.countDown();var completion=oldReceipt.awaitCompletion(until());assertNull(completion.failure());assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,completion.metrics().commitOutcome());publication.get(5,TimeUnit.SECONDS);assertFalse(oldReceipt.active());
                assertSame(stale,platform.publishedSnapshot(owner));assertEquals(blocked.identities(),stale.identities());assertTrue(stale.coverage().values().stream().allMatch(value->value.state()==MetadataState.STALE&&!value.complete()));
                assertEquals("WRITE_UNAVAILABLE",platform.cacheState(owner),"A completed obsolete cache receipt cannot imply a pending or current cache");assertTrue(platform.cacheWriteReceipt(owner).isEmpty());assertTrue(platform.cacheWriteMetrics(owner).isEmpty());assertEquals(connections,cache.opens.get(),"Invalidation and receipt settlement must not submit another cache write");physicalFree(owner);
            }finally{stop(workers,cache,policy);}
        }
    }
}
