package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.security.PrivateTemporaryFiles;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.nio.file.*;
import java.sql.*;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.concurrent.atomic.*;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;
import static org.junit.jupiter.api.Assertions.*;

/** Genuine backend-owner restart; explicit rebind may inspect native metadata,
 * but neither rebind nor Review may replay the saved SELECT or mutate its row. */
class CompactInspectionRecoveryIT {
    private static final String TABLE="compact_recovery_rows";
    private static final String STAMPS="{\"2025-04-05 06:07:08.654321\",NULL}";
    private static final String ZONED="{\"2025-04-05 06:07:08.654321+05:30\",NULL}";
    @TempDir Path root;
    private static final class OriginalQueryCounter {
        volatile String original="",marker="";
        final AtomicInteger exactExecutions=new AtomicInteger(),markedExecutions=new AtomicInteger();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception{
            var actual=adapter.connect(request,port);
            // BusyData's native PostgreSQL raw path unwraps its transport owner
            // and bypasses JDBC Statement.execute. Observe that exact execute
            // boundary while delegating every original query/argument unchanged.
            var nativeOwner=request.getProfile().getEngine()==Engine.POSTGRESQL?observedNative(actual.unwrap(org.postgresql.core.BaseConnection.class)):null;
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if(nativeOwner!=null&&method.getName().equals("unwrap")&&args[0]==org.postgresql.core.BaseConnection.class)return nativeOwner;
                Object value=invoke(actual,method,args);
                if(method.getName().equals("createStatement")&&value instanceof Statement statement)return wrapped(statement,null);
                if(method.getName().equals("prepareStatement")&&args!=null&&args[0] instanceof String sql&&value instanceof PreparedStatement statement)return wrapped(statement,sql);
                return value;
            });
        }
        private org.postgresql.core.BaseConnection observedNative(org.postgresql.core.BaseConnection actual){
            var executor=actual.getQueryExecutor();
            var observed=(org.postgresql.core.QueryExecutor)Proxy.newProxyInstance(org.postgresql.core.QueryExecutor.class.getClassLoader(),new Class[]{org.postgresql.core.QueryExecutor.class},(proxy,method,args)->{
                if(method.getName().equals("execute")&&args!=null&&args.length>0){
                    if(args[0] instanceof org.postgresql.core.Query query)observed(query.getNativeSql());
                    else if(args[0] instanceof org.postgresql.core.Query[] queries)for(var query:queries)observed(query.getNativeSql());
                }
                return invoke(executor,method,args);
            });
            return (org.postgresql.core.BaseConnection)Proxy.newProxyInstance(org.postgresql.core.BaseConnection.class.getClassLoader(),new Class[]{org.postgresql.core.BaseConnection.class},(proxy,method,args)->{
                if(method.getName().equals("getQueryExecutor"))return observed;
                if(method.getName().equals("unwrap")&&args[0]==org.postgresql.core.BaseConnection.class)return proxy;
                return invoke(actual,method,args);
            });
        }
        private void observed(String sql){
            if(sql==null)return;
            if(!original.isEmpty()&&sql.equals(original))exactExecutions.incrementAndGet();
            if(!marker.isEmpty()&&sql.contains(marker))markedExecutions.incrementAndGet();
        }
        private Object wrapped(Statement statement,String preparedSql){
            Class<?> contract=statement instanceof PreparedStatement?PreparedStatement.class:Statement.class;
            return Proxy.newProxyInstance(contract.getClassLoader(),new Class[]{contract},(proxy,method,args)->{
                if(Set.of("execute","executeQuery","executeUpdate","executeLargeUpdate").contains(method.getName())){
                    String sql=args!=null&&args.length>0&&args[0] instanceof String text?text:preparedSql;
                    observed(sql);
                }
                return invoke(statement,method,args);
            });
        }
        void once(){assertEquals(1,exactExecutions.get(),"The exact original SELECT must execute only during initial retention");assertEquals(1,markedExecutions.get(),"No statement carrying the saved source marker may be replayed");}
    }
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable{
        try{return method.invoke(target,args);}catch(InvocationTargetException error){throw error.getCause();}
    }
    static Stream<Arguments> coldCaches(){return Stream.of("POSTGRESQL","MYSQL","MARIADB").flatMap(engine->Stream.of(false,true).map(empty->Arguments.of(engine,empty)));}
    static Stream<Arguments> postgresCaches(){return Stream.of(Arguments.of("POSTGRESQL",false),Arguments.of("POSTGRESQL",true));}
    private record Saved(String draft,StoredEditDraft data,String schema,String oldSession,Profile profile){}

    @ParameterizedTest(name="{index}: {0}, empty cache {1}") @MethodSource("coldCaches")
    void defaultAndNullDraftRebindsAfterRealOwnerRestartWithoutWarmingTheCache(String engine,boolean empty)throws Exception{
        run(engine,empty,false,false);
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void incompatibleNativeSchemaAfterRestartPreservesTheExactStagedRecord(String engine)throws Exception{
        run(engine,true,false,true);
    }
    @ParameterizedTest(name="{index}: {0}, empty cache {1}") @MethodSource("postgresCaches")
    void isoTemporalArrayIntentAndOriginalsRebindWithoutACachedTypeCatalog(String engine,boolean empty)throws Exception{
        run(engine,empty,true,false);
    }
    private Saved save(EngineFixture fixture,OriginalQueryCounter counter,boolean arrays)throws Exception{
        var owner=fixture.open();String table=owner.adapter.table("busydata",fixture.schema(),TABLE);
        owner.lock.lock();try(var statement=owner.connection.createStatement()){
            if(arrays){statement.execute("SET DateStyle='ISO, MDY'");statement.execute("SET TIME ZONE 'UTC'");statement.execute("SET array_nulls=on");}
            statement.execute("CREATE TABLE "+table+"(id INTEGER PRIMARY KEY,n DECIMAL(30,9) DEFAULT 7.125,note VARCHAR(100) DEFAULT 'server'"+(arrays?",stamps TIMESTAMP(6)[],zoned TIMESTAMPTZ(6)[]":"")+")");
            statement.execute("INSERT INTO "+table+" VALUES(1,1.250000000,'original'"+(arrays?",ARRAY[TIMESTAMP '2024-02-03 12:34:56.123456',NULL],ARRAY[TIMESTAMPTZ '2024-02-03 12:34:56.123456+05:30',NULL]":"")+")");owner.refresh();
        }finally{owner.lock.unlock();}
        // Raw setup and explicit introspection leave no queued Smart DDL work.
        fixture.warm(owner,TABLE);fixture.metadata.save(fixture.profile);
        counter.marker="compact-recovery-original-"+fixture.engine.name();
        counter.original="SELECT id,n,note"+(arrays?",stamps,zoned":"")+" /* "+counter.marker+" */ FROM "+table;
        var query=fixture.execute(owner,counter.original);var retained=fixture.results.get(query.info().getResults(0).getResultId());
        assertTrue(retained.metadataProof().available(),retained.metadataProof().availability());assertEquals(1,retained.rows());counter.once();
        var update=StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,Assignments.defaultValue()).putValues(3,Assignments.nullValue());
        if(arrays){update.putValues(4,Assignments.value(Value.newBuilder().setText(STAMPS).build()));update.putValues(5,Assignments.value(Value.newBuilder().setText(ZONED).build()));}
        var request=ChangeRequest.newBuilder().setSessionId(owner.id).setCatalog("busydata").setSchema(fixture.schema()).setTable(TABLE).setResultId(retained.id).addChanges(update).build();
        var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());var recovery=new EditDrafts(fixture.metadata,fixture.results,planner);int jobs=fixture.jobs.list("").size();
        var reply=recovery.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(owner.id).setDocumentId("saved-intent").setChanges(request).build());
        String id=reply.getDrafts(0).getDraftId();var saved=fixture.metadata.editDraft(id).data();assertEquals("STAGED",fixture.metadata.editDraft(id).state());
        assertTrue(saved.getChanges().getChanges(0).getValuesOrThrow(2).hasDefaultValue());assertTrue(saved.getChanges().getChanges(0).getValuesOrThrow(3).hasNullValue());
        assertEquals(counter.original,saved.getSourceSql());assertEquals(jobs,fixture.jobs.list("").size());counter.once();
        if(arrays){assertEquals(STAMPS,saved.getChanges().getChanges(0).getValuesOrThrow(4).getValue().getText());assertEquals(ZONED,saved.getChanges().getChanges(0).getValuesOrThrow(5).getValue().getText());assertTrue(saved.getRows(0).getRow().getValues(3).hasArray());assertTrue(saved.getRows(0).getRow().getValues(4).hasArray());}
        assertEquals(fixture.engine==Engine.MARIADB?1:0,PreparedMetadataWitness.retainedForSession(owner.id));
        assertEquals("AVAILABLE",fixture.metadata.metadataPlatform().cacheState(owner),"The restored-cache fixture requires an actual successful prior persistence");
        return new Saved(id,saved,fixture.schema(),owner.id,fixture.profile);
    }
    private static void closeOldOwners(EngineFixture fixture,Saved saved)throws Exception{
        fixture.jobs.close();fixture.results.close();fixture.sessions.close();fixture.metadata.close();
        assertEquals(0,PreparedMetadataWitness.retainedForSession(saved.oldSession()));
        assertTrue(Files.isRegularFile(fixture.metadata.root().resolve("metadata.sqlite")));
    }
    private static void invalidateOnlyRebuildableCache(Path root)throws Exception{
        for(String name:List.of("metadata_catalog.sqlite","metadata_catalog.sqlite-wal","metadata_catalog.sqlite-shm")){
            Path file=root.resolve(name);assertFalse(Files.isSymbolicLink(file));Files.deleteIfExists(file);
        }
        assertTrue(Files.isRegularFile(root.resolve("metadata.sqlite")),"Persistent recovery/user storage must remain untouched");
    }
    private static void assertCold(MetadataPlatform platform,SessionRegistry.Session owner,String schema,boolean empty){
        var snapshot=platform.capture(owner);var columns=new MetadataScope("busydata",schema,TABLE,ObjectKind.COLUMN);
        assertFalse(snapshot.complete(columns,IntrospectionLevel.STRUCTURE));
        if(empty){assertTrue(snapshot.identities().isEmpty());assertTrue(snapshot.catalogCoverage().isEmpty());}
        else{assertFalse(snapshot.identities().isEmpty());assertEquals(MetadataState.STALE,snapshot.coverage(columns).orElseThrow().state());}
    }
    private static int retained(ResultStore results){return results.list(RetainedRequest.newBuilder().setLimit(32).build()).getResultsCount();}
    private static void verifyDatabaseRow(SessionRegistry.Session owner,String schema,boolean arrays)throws Exception{
        String table=owner.adapter.table("busydata",schema,TABLE);owner.lock.lock();try(var statement=owner.connection.createStatement();var rows=statement.executeQuery("SELECT id,n,note"+(arrays?",stamps[1]::text,zoned[1] AT TIME ZONE 'UTC'":"")+" FROM "+table)){
            assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertEquals(0,new BigDecimal("1.250000000").compareTo(rows.getBigDecimal(2)));assertEquals(9,rows.getBigDecimal(2).scale());assertEquals("original",rows.getString(3));
            if(arrays){assertEquals("2024-02-03 12:34:56.123456",rows.getString(4));assertEquals("2024-02-03 07:04:56.123456",rows.getString(5));}assertFalse(rows.next());
        }finally{owner.lock.unlock();}
    }
    private static void verifyArrayReview(ChangePlan plan){
        var local=plan.getChanges(0).getValuesOrThrow("stamps").getValue().getArray();var zoned=plan.getChanges(0).getValuesOrThrow("zoned").getValue().getArray();
        assertEquals(STAMPS,local.getNativeLiteral());assertEquals(ZONED,zoned.getNativeLiteral());
        assertEquals("2025-04-05T06:07:08.654321",local.getValues(0).getTemporal().getIso());
        assertEquals(OffsetDateTime.parse("2025-04-05T06:07:08.654321+05:30").toInstant(),OffsetDateTime.parse(zoned.getValues(0).getTemporal().getIso()).toInstant());
        assertTrue(local.getValues(1).hasNullValue());assertTrue(zoned.getValues(1).hasNullValue());
    }
    private void run(String engine,boolean empty,boolean arrays,boolean incompatible)throws Exception{
        var counter=new OriginalQueryCounter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)){
            var saved=save(fixture,counter,arrays);Path storage=fixture.metadata.root();byte[] before=saved.data().toByteArray();
            closeOldOwners(fixture,saved);if(empty)invalidateOnlyRebuildableCache(storage);
            var analysis=new SqlAnalysis();var safety=new Safety(analysis);
            try(var metadata=new MetadataStore(storage);var scratch=PrivateTemporaryFiles.isolated();var sessions=new SessionRegistry(scratch,counter::connect);var results=new ResultStore(storage,64L*1024*1024);var jobs=new Jobs(results,metadata,analysis,safety)){
                assertArrayEquals(before,metadata.editDraft(saved.draft()).data().toByteArray());assertEquals("STAGED",metadata.editDraft(saved.draft()).state());assertEquals(List.of(saved.profile()),metadata.profiles());
                var owner=sessions.open(OpenRequest.newBuilder().setProfile(saved.profile()).setPassword("fixture").build());assertNotEquals(saved.oldSession(),owner.id);assertEquals(0,PreparedMetadataWitness.retainedForSession(owner.id));
                if(arrays){owner.lock.lock();try(var statement=owner.connection.createStatement()){statement.execute("SET DateStyle='ISO, MDY'");statement.execute("SET TIME ZONE 'UTC'");statement.execute("SET array_nulls=on");owner.refresh();}finally{owner.lock.unlock();}}
                var platform=metadata.metadataPlatform();assertCold(platform,owner,saved.schema(),empty);assertEquals(0,retained(results));assertTrue(jobs.list("").isEmpty());
                if(incompatible){owner.lock.lock();try(var statement=owner.connection.createStatement()){statement.execute("ALTER TABLE "+owner.adapter.table("busydata",saved.schema(),TABLE)+" ADD COLUMN incompatible INTEGER DEFAULT 5");}finally{owner.lock.unlock();}}
                var planner=new ChangePlanner(safety,results,platform);var recovery=new EditDrafts(metadata,results,planner);
                var request=EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setDraftId(saved.draft()).setSessionId(owner.id).setDocumentId("explicit-rebound-owner").build();
                if(incompatible){
                    assertThrows(IllegalStateException.class,()->recovery.run(sessions,request));
                    assertArrayEquals(before,metadata.editDraft(saved.draft()).data().toByteArray());assertEquals("STAGED",metadata.editDraft(saved.draft()).state());
                    assertEquals(0,retained(results));assertEquals(0,PreparedMetadataWitness.retainedForSession(owner.id));assertTrue(jobs.list("").isEmpty());counter.once();verifyDatabaseRow(owner,saved.schema(),false);return;
                }
                var rebound=recovery.run(sessions,request);var restored=results.get(rebound.getChanges().getResultId());
                assertTrue(restored.metadataProof().available(),restored.metadataProof().availability());assertEquals(owner.id,restored.sourceSessionId);assertEquals(saved.data().getRowsCount(),restored.rows());
                for(int index=0;index<saved.data().getRowsCount();index++)assertArrayEquals(saved.data().getRows(index).getRow().toByteArray(),restored.read(index).toByteArray());
                assertEquals(saved.data().getChanges().getChangesList(),rebound.getChanges().getChangesList());
                var refreshed=metadata.editDraft(saved.draft()).data();assertEquals("STAGED",metadata.editDraft(saved.draft()).state());assertEquals(saved.data().getRowsList(),refreshed.getRowsList());assertEquals(saved.data().getChanges().getChangesList(),refreshed.getChanges().getChangesList());
                assertArrayEquals(saved.data().getChanges().getChanges(0).getValuesOrThrow(2).toByteArray(),refreshed.getChanges().getChanges(0).getValuesOrThrow(2).toByteArray());assertArrayEquals(saved.data().getChanges().getChanges(0).getValuesOrThrow(3).toByteArray(),refreshed.getChanges().getChanges(0).getValuesOrThrow(3).toByteArray());
                assertEquals(saved.data().getSourceSql(),refreshed.getSourceSql());counter.once();assertTrue(jobs.list("").isEmpty());assertEquals(1,retained(results));
                int witnesses=fixture.engine==Engine.MARIADB?1:0;assertEquals(witnesses,PreparedMetadataWitness.retainedForSession(owner.id));
                var plan=planner.preview(owner,rebound.getChanges());assertTrue(plan.getChanges(0).getValuesOrThrow("n").hasDefaultValue());assertTrue(plan.getChanges(0).getValuesOrThrow("note").hasNullValue());if(arrays)verifyArrayReview(plan);
                assertEquals(witnesses,PreparedMetadataWitness.retainedForSession(owner.id));assertTrue(jobs.list("").isEmpty());counter.once();verifyDatabaseRow(owner,saved.schema(),arrays);
                assertFalse(platform.capture(owner).complete(new MetadataScope("busydata",saved.schema(),TABLE,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE),"Compact recovery must not secretly populate a global cached catalog to make its proof work");
                safety.discard(plan.getPlanId());results.dispose(restored.id);assertEquals(0,PreparedMetadataWitness.retainedForSession(owner.id));assertEquals(0,retained(results));
                sessions.close(owner.id,true);assertEquals(0,PreparedMetadataWitness.retainedForSession(owner.id));assertEquals("STAGED",metadata.editDraft(saved.draft()).state());counter.once();
            }
        }
    }
}
