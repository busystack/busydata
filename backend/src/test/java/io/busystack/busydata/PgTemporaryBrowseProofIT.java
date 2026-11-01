package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.*;
import static org.junit.jupiter.api.Assertions.*;

/** Real TEMP browsing: native observations must not make unchanged approvals stale,
 * and raw structural changes must not borrow a previously approved shape. */
class PgTemporaryBrowseProofIT {
    private static final String TABLE="browse_temp_rows";
    @TempDir Path root;
    private static final class Counter {
        final AtomicReference<Connection> physical=new AtomicReference<>();
        final AtomicInteger prepared=new AtomicInteger(),executed=new AtomicInteger(),nativeReads=new AtomicInteger();
        final AtomicReference<Runnable> secondNativeClose=new AtomicReference<>();
        Connection connect(JdbcAdapter adapter,OpenRequest request,Integer port)throws Exception{
            var actual=adapter.connect(request,port);boolean owned=!request.getProfile().getReadOnly()&&physical.compareAndSet(null,actual);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                Object value=invoke(actual,method,args);
                if(owned&&method.getName().equals("prepareStatement")&&args!=null&&args[0] instanceof String sql&&value instanceof PreparedStatement statement
                    &&sql.startsWith("SELECT * FROM ")&&sql.contains(TABLE)&&!sql.endsWith(" LIMIT 0")){
                    prepared.incrementAndGet();
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(selected,operation,parameters)->{
                        if(operation.getName().equals("executeQuery"))executed.incrementAndGet();return invoke(statement,operation,parameters);
                    });
                }
                if(owned&&method.getName().equals("prepareStatement")&&args!=null&&args[0] instanceof String sql&&value instanceof PreparedStatement statement
                    &&sql.startsWith("SELECT c.oid::text,pg_catalog.pg_relation_filenode(c.oid)::text FROM")){
                    return Proxy.newProxyInstance(PreparedStatement.class.getClassLoader(),new Class[]{PreparedStatement.class},(selected,operation,parameters)->{
                        Object result=invoke(statement,operation,parameters);
                        if(operation.getName().equals("executeQuery")&&result instanceof ResultSet rows){int sequence=nativeReads.incrementAndGet();
                            return Proxy.newProxyInstance(ResultSet.class.getClassLoader(),new Class[]{ResultSet.class},(record,read,arguments)->{
                                Object answer=invoke(rows,read,arguments);if(read.getName().equals("close")&&sequence==2){var effect=secondNativeClose.getAndSet(null);if(effect!=null)effect.run();}return answer;
                            });
                        }return result;
                    });
                }
                return value;
            });
        }
    }
    private static Object invoke(Object target,Method method,Object[] args)throws Throwable{
        try{return method.invoke(target,args);}catch(InvocationTargetException error){throw error.getCause();}
    }
    static Stream<Arguments> modes(){return Stream.of(
        Arguments.of("POSTGRESQL",false),Arguments.of("MYSQL",false),Arguments.of("MARIADB",false),
        Arguments.of("MYSQL",true),Arguments.of("MARIADB",true));}
    private static void setup(EngineFixture fixture,SessionRegistry.Session owner,boolean ansi)throws Exception{
        fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
        if(ansi)fixture.execute(owner,"SET SESSION sql_mode=CONCAT(@@sql_mode,',ANSI_QUOTES')");
        String permanent=owner.adapter.table("busydata",fixture.schema(),TABLE);
        fixture.execute(owner,"CREATE TABLE "+permanent+"(id INTEGER PRIMARY KEY,marker INTEGER); INSERT INTO "+permanent+" VALUES(99,999)");
        fixture.warm(owner,TABLE);
        fixture.execute(owner,"CREATE TEMPORARY TABLE "+owner.adapter.quote(TABLE)+"(id INTEGER PRIMARY KEY,marker VARCHAR(40)); INSERT INTO "+owner.adapter.quote(TABLE)+" VALUES(1,'temp')");
        refreshOwned(fixture,owner);
    }
    private static void refreshOwned(EngineFixture fixture,SessionRegistry.Session owner)throws Exception{
        var explorer=new Explorer(fixture.metadata);owner.lock.lock();try{
            if(fixture.engine==Engine.POSTGRESQL)explorer.refreshSessionOverlay(owner);
            else explorer.refreshTemporary(owner,"busydata","busydata",TABLE);
        }finally{owner.lock.unlock();}
    }
    private static BrowseRequest selected(EngineFixture fixture,SessionRegistry.Session owner){
        var snapshot=fixture.metadata.metadataPlatform().capture(owner);
        String schema=fixture.engine==Engine.POSTGRESQL?owner.context.temporarySchema():"busydata";assertFalse(schema.isEmpty());
        var relations=snapshot.resolve("busydata",schema,ObjectKind.TABLE,"",TABLE,true);assertEquals(1,relations.size());var relation=relations.getFirst();
        assertEquals(owner.id,relation.identity().sessionOwner());assertEquals("true",relation.properties().get("temporary"));
        assertTrue(snapshot.complete(new MetadataScope("busydata",schema,TABLE,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
        return BrowseRequest.newBuilder().setSessionId(owner.id).setDocumentId("native-temp-browse").setCatalog("busydata").setSchema(schema).setTable(TABLE).setRowLimit(10)
            .setMetadataSnapshotRevision(snapshot.revision()).setMetadataObjectIdentity(relation.identity().key())
            .addConditions(RowCondition.newBuilder().setColumn("marker").setPredicate(ValuePredicate.EQUAL).setValue(Value.newBuilder().setText("temp"))).build();
    }
    private static void assertPermanentUntouched(EngineFixture fixture,SessionRegistry.Session observer)throws Exception{
        EditingIT.assertRows(observer,"SELECT id,marker FROM "+observer.adapter.table("busydata",fixture.schema(),TABLE),new int[][]{{99,999}});
        var global=fixture.metadata.metadataPlatform().publishedSnapshot(observer);
        var permanent=global.resolve("busydata",fixture.schema(),ObjectKind.TABLE,"",TABLE,true);assertEquals(1,permanent.size());assertTrue(permanent.getFirst().identity().sessionOwner().isEmpty());
        assertTrue(global.identities().values().stream().allMatch(value->value.identity().sessionOwner().isEmpty()),"No physical owner's TEMP identity may enter durable metadata");
    }

    @ParameterizedTest @ValueSource(booleans={false,true})
    void rawChangedTemporaryShapeIsRejectedBeforeIssuingApproval(boolean recreate)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);
            var explorer=new Explorer(fixture.metadata);var request=selected(fixture,owner);
            int jobs=fixture.jobs.list(owner.id).size();long revision=owner.revision,context=owner.contextRevision;
            mutate(owner,request,recreate,true);
            assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);
            assertEquals(request.getMetadataSnapshotRevision(),fixture.metadata.metadataPlatform().capture(owner).revision(),"This regression must exercise cached-old/native-new evidence");
            var failure=assertThrows(WorkbenchFailure.class,()->TableBrowse.review(owner,request,explorer,fixture.safety));
            assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());
            assertEquals(jobs,fixture.jobs.list(owner.id).size());assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());
            assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void sameShapeRecreationCannotReuseThePreviousNativeIdentity(String engine)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);
            var explorer=new Explorer(fixture.metadata);var request=selected(fixture,owner);
            var approval=TableBrowse.review(owner,request,explorer,fixture.safety);int jobs=fixture.jobs.list(owner.id).size();
            String oldId=fixture.metadata.metadataPlatform().capture(owner).identity(request.getMetadataObjectIdentity()).orElseThrow().identity().nativeKey();
            mutate(owner,request,true,false);
            owner.lock.lock();try {
                assertNotEquals(oldId,NativeRelationReader.inspect(owner,request.getCatalog(),request.getSchema(),TABLE).get("nativeId"));
            }finally{owner.lock.unlock();}
            var failure=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs));
            assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());assertEquals(jobs,fixture.jobs.list(owner.id).size());
            assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void rowOnlyChangeKeepsApprovedTemporaryStructureAndExecutesOnce(String engine)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);
            var explorer=new Explorer(fixture.metadata);var request=selected(fixture,owner);
            var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            owner.lock.lock();try(var statement=owner.connection.createStatement()) {
                statement.execute("INSERT INTO "+owner.adapter.table(request.getCatalog(),request.getSchema(),TABLE)+" VALUES(2,'temp')");
            }finally{owner.lock.unlock();}
            var job=TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
            EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
            assertEquals(1,counter.prepared.get());assertEquals(1,counter.executed.get());
            var result=fixture.results.get(job.info().getResults(0).getResultId());assertEquals(2,result.rows());assertEquals(2,result.columns.size());
            assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(booleans={false,true})
    void queuedTemporaryBrowseRejectsRawShapeChangeBeforeGeneratedSql(boolean recreate)throws Exception {
        var counter=new Counter();
        try(var dispatch=new JobDispatchGate();var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect,database->{},dispatch::decorate)) {
            dispatch.attach(fixture.jobs);
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);
            var explorer=new Explorer(fixture.metadata);var request=selected(fixture,owner);
            var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            int before=fixture.jobs.list(owner.id).size();String execution=UUID.randomUUID().toString();Jobs.Job accepted;
            dispatch.arm();
            try {
                accepted=TableBrowse.submit(owner,request.toBuilder().setExecutionId(execution).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
                dispatch.assertHeld(accepted);assertSame(accepted,fixture.jobs.get(accepted.id));assertEquals(execution,accepted.execution);
                mutate(owner,request,recreate,true);
                assertEquals(request.getMetadataSnapshotRevision(),fixture.metadata.metadataPlatform().capture(owner).revision(),"Native shape changed without a central publication");
                assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());
            }finally{dispatch.release();}
            EditingIT.await(accepted);assertEquals(JobState.FAILED,accepted.state,accepted.info().toString());
            assertEquals("stale",accepted.info().getErrorCode());assertEquals(0,accepted.info().getResultsCount());
            assertEquals(before+1,fixture.jobs.list(owner.id).size(),"The one accepted job fails without replacement or replay");
            assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(booleans={false,true})
    void nativeNamedTypeDependencyChangeRejectsApprovalWhenTheColumnsDidNotChange(boolean domain)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,"POSTGRESQL",counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);
            String type=owner.adapter.quote(fixture.schema())+"."+owner.adapter.quote("browse_marker_type");
            String target=owner.adapter.table("busydata",owner.context.temporarySchema(),TABLE);
            fixture.execute(owner,(domain?"CREATE DOMAIN "+type+" AS VARCHAR(40)":"CREATE TYPE "+type+" AS ENUM('temp')")
                +"; ALTER TABLE "+target+" ALTER COLUMN marker TYPE "+type+" USING marker::text::"+type);
            var explorer=new Explorer(fixture.metadata);
            // The TEMP overlay owns this table, but its enum is a distinct
            // persistent TYPE. Acquire its authoritative L2 labels explicitly
            // before the initial filtered review; no post-mutation refresh.
            if(!domain)explorer.refreshFragment(owner,"busydata",fixture.schema(),"browse_marker_type",ObjectKind.TYPE);
            refreshOwned(fixture,owner);var request=selected(fixture,owner);
            if(!domain){
                var configured=fixture.metadata.metadataPlatform().capture(owner);
                var marker=configured.select(new MetadataScope("busydata",request.getSchema(),TABLE,ObjectKind.COLUMN)).stream().filter(column->column.identity().name().equals("marker")).findFirst().orElseThrow();
                var types=configured.resolve("busydata",fixture.schema(),ObjectKind.TYPE,"","browse_marker_type",true);assertEquals(1,types.size());
                assertEquals(MetadataState.AVAILABLE,types.getFirst().state());assertTrue(types.getFirst().level().includes(IntrospectionLevel.STRUCTURE));
                assertEquals(marker.properties().get("nativeTypeId"),types.getFirst().identity().nativeKey());
                var evidence=EditTypeEvidence.forColumn(configured,configured.projection(marker));
                assertEquals("AVAILABLE",evidence.getPropertiesOrDefault("enumLabelsAvailability",""));assertEquals("1",evidence.getPropertiesOrDefault("enumLabelCount",""));assertEquals("temp",evidence.getPropertiesOrDefault("enumLabel.0",""));
            }
            var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            var before=fixture.metadata.metadataPlatform().capture(owner);
            String dependencies=before.identity(request.getMetadataObjectIdentity()).orElseThrow().properties().get("typeDependenciesFingerprint");
            var columnScope=new MetadataScope("busydata",request.getSchema(),TABLE,ObjectKind.COLUMN);
            String columns=MetadataFingerprint.objects(before.select(columnScope).stream().map(before::projection).toList());
            int jobs=fixture.jobs.list(owner.id).size();long revision=owner.revision,context=owner.contextRevision;
            owner.lock.lock();try(var statement=owner.connection.createStatement()) {
                statement.execute(domain?"ALTER DOMAIN "+type+" ADD CONSTRAINT marker_guard CHECK (VALUE <> 'blocked')":"ALTER TYPE "+type+" ADD VALUE 'next'");
                var fresh=explorer.fetchBranch(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(request.getSchema()).setTable(TABLE).setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).setLimit(500).build(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
                var normalized=fresh.stream().map(column->MetadataObject.from(before.source(),before.profileId(),owner.id,before.rules(),column,IntrospectionLevel.STRUCTURE,owner.revision,owner.contextRevision).projection(0,0)).toList();
                assertEquals(columns,MetadataFingerprint.objects(normalized),"This case must isolate type dependency evidence from column projection evidence");
                assertNotEquals(dependencies,NativeTypeReader.namespaceFingerprints(owner,request.getSchema(),TABLE,System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10)).get(TABLE));
            }finally{owner.lock.unlock();}
            assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);assertEquals(before.revision(),fixture.metadata.metadataPlatform().capture(owner).revision());
            var rejected=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs));
            assertEquals(WorkbenchFailure.Reason.STALE,rejected.reason());assertEquals(jobs,fixture.jobs.list(owner.id).size());
            assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void rejectedNativeShapeRetiresOnlyTheOwnerAndKeepsRetainedRowsAndDraftBytes(String engine)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);var platform=fixture.metadata.metadataPlatform();
            String target=owner.adapter.table("busydata",owner.context.temporarySchema(),TABLE);
            var retained=fixture.results.get(fixture.execute(owner,"SELECT id,marker FROM "+target).info().getResults(0).getResultId());
            var planner=new ChangePlanner(fixture.safety,fixture.results,platform);var drafts=new EditDrafts(fixture.metadata,fixture.results,planner);
            var changes=ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(retained.id).setCatalog("busydata").setSchema(owner.context.temporarySchema()).setTable(TABLE)
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,Assignments.value(Value.newBuilder().setText("edited").build()))).build();
            var saved=drafts.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(owner.id).setDocumentId("temp-native-proof-draft").setChanges(changes).build());
            String draftId=saved.getDrafts(0).getDraftId();var draft=fixture.metadata.editDraft(draftId).data().toByteArray();
            var explorer=new Explorer(platform);var request=selected(fixture,owner);var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            var durable=platform.publishedSnapshot(owner);long observerRevision=platform.capture(observer).revision();
            mutate(owner,request,false,true);
            var rejected=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs));
            assertEquals(WorkbenchFailure.Reason.STALE,rejected.reason());
            assertFalse(platform.capture(owner).complete(new MetadataScope("busydata",request.getSchema(),TABLE,ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE),"Known changed native shape cannot remain available");
            assertSame(durable,platform.publishedSnapshot(owner));assertEquals(observerRevision,platform.capture(observer).revision());
            assertSame(retained,fixture.results.get(retained.id));assertEquals("temp",retained.read(0).getValues(1).getText());
            assertArrayEquals(draft,fixture.metadata.editDraft(draftId).data().toByteArray());assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void partitionedTemporaryBrowseKeepsTheNativeOidWithoutInventingAFileGeneration(String engine)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);
            fixture.execute(owner,"DROP TABLE "+owner.adapter.quote(TABLE)+"; CREATE TEMPORARY TABLE "+owner.adapter.quote(TABLE)+"(id INTEGER,marker VARCHAR(40)) PARTITION BY RANGE(id)"
                +"; CREATE TEMPORARY TABLE browse_temp_partition PARTITION OF "+owner.adapter.quote(TABLE)+" FOR VALUES FROM(0) TO(100); INSERT INTO "+owner.adapter.quote(TABLE)+" VALUES(1,'temp')");
            refreshOwned(fixture,owner);var explorer=new Explorer(fixture.metadata);var request=selected(fixture,owner);
            var relation=fixture.metadata.metadataPlatform().capture(owner).identity(request.getMetadataObjectIdentity()).orElseThrow();
            assertEquals(ObjectSubtype.PARTITIONED_TABLE,relation.identity().subtype());assertFalse(relation.identity().nativeKey().isEmpty());
            assertEquals("UNAVAILABLE",relation.properties().get("nativeGenerationAvailability"));assertTrue(relation.properties().getOrDefault("nativeGeneration","").isEmpty());
            var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            var accepted=TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
            EditingIT.await(accepted);assertEquals(JobState.COMPLETED,accepted.state,accepted.info().toString());
            assertEquals(1,counter.prepared.get());assertEquals(1,counter.executed.get());
            var result=fixture.results.get(accepted.info().getResults(0).getResultId());assertEquals(1,result.rows());assertEquals(2,result.columns.size());assertPermanentUntouched(fixture,observer);
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void unchangedOwnedTemporaryViewRemainsReadonlyAndCanBeBrowsedTwice(String engine)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);setupView(fixture,owner);
            var explorer=new Explorer(fixture.metadata);String identity=selectedView(fixture,owner).getMetadataObjectIdentity();
            for(int round=1;round<=2;round++) {
                var request=selectedView(fixture,owner);assertEquals(identity,request.getMetadataObjectIdentity());
                var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
                var accepted=TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs);
                EditingIT.await(accepted);assertEquals(JobState.COMPLETED,accepted.state,accepted.info().toString());
                var retained=fixture.results.get(accepted.info().getResults(0).getResultId());assertEquals(1,retained.rows());assertEquals("temp",retained.read(0).getValues(1).getText());
                var assessment=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform()).assess(owner,ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(retained.id).setCatalog("busydata").setSchema(request.getSchema()).setTable(TABLE).build());
                assertFalse(assessment.getEditable(),"A browse proof for a view does not authorize writing a rewritten base table");
                assertEquals(round,counter.prepared.get());assertEquals(round,counter.executed.get());assertPermanentUntouched(fixture,observer);
            }
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void replacingTemporaryViewBodyRejectsApprovalDespiteSameOidAndOutputColumns(String engine)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);setupView(fixture,owner);
            var explorer=new Explorer(fixture.metadata);var request=selectedView(fixture,owner);var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            int jobs=fixture.jobs.list(owner.id).size();var snapshot=fixture.metadata.metadataPlatform().capture(owner);var relation=snapshot.identity(request.getMetadataObjectIdentity()).orElseThrow();
            String columns=MetadataFingerprint.objects(snapshot.select(new MetadataScope("busydata",request.getSchema(),TABLE,ObjectKind.COLUMN)).stream().map(snapshot::projection).toList());
            owner.lock.lock();try(var statement=owner.connection.createStatement()) {
                var identity=NativeRelationReader.inspect(owner,"busydata",request.getSchema(),TABLE);
                statement.execute("CREATE OR REPLACE TEMPORARY VIEW "+owner.adapter.quote(TABLE)+" AS SELECT id,marker FROM "+owner.adapter.quote("browse_temp_backing")+" WHERE id=999");
                assertEquals(identity,NativeRelationReader.inspect(owner,"busydata",request.getSchema(),TABLE),"Native view identity and unavailable filenode alone cannot detect replacement");
                var fresh=explorer.fetchBranch(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(request.getSchema()).setTable(TABLE).setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).setLimit(500).build(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
                var normalized=fresh.stream().map(column->MetadataObject.from(snapshot.source(),snapshot.profileId(),owner.id,snapshot.rules(),column,IntrospectionLevel.STRUCTURE,owner.revision,owner.contextRevision).projection(0,0)).toList();
                assertEquals(columns,MetadataFingerprint.objects(normalized));
                var marker=explorer.fetchBranch(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(request.getSchema()).setKind(ObjectKind.VIEW).setSearch(TABLE).setExactName(true).setIntrospectionLevel(1).setLimit(1).build(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
                assertEquals(1,marker.size());assertNotEquals(relation.properties().get("catalogFingerprint"),marker.getFirst().getPropertiesOrThrow("catalogFingerprint"));
            }finally{owner.lock.unlock();}
            assertEquals(snapshot.revision(),fixture.metadata.metadataPlatform().capture(owner).revision());
            var rejected=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs));
            assertEquals(WorkbenchFailure.Reason.STALE,rejected.reason());assertEquals(jobs,fixture.jobs.list(owner.id).size());assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());assertPermanentUntouched(fixture,observer);
        }
    }
    private static void setupView(EngineFixture fixture,SessionRegistry.Session owner)throws Exception {
        fixture.execute(owner,"ALTER TABLE "+owner.adapter.quote(TABLE)+" RENAME TO browse_temp_backing; CREATE TEMPORARY VIEW "+owner.adapter.quote(TABLE)+" AS SELECT id,marker FROM browse_temp_backing WHERE id=1");
        refreshOwned(fixture,owner);
    }
    private static BrowseRequest selectedView(EngineFixture fixture,SessionRegistry.Session owner) {
        var snapshot=fixture.metadata.metadataPlatform().capture(owner);String schema=owner.context.temporarySchema();
        var relations=snapshot.resolve("busydata",schema,ObjectKind.VIEW,"",TABLE,true);assertEquals(1,relations.size());var relation=relations.getFirst();
        assertEquals(owner.id,relation.identity().sessionOwner());assertEquals(ObjectSubtype.REGULAR_VIEW,relation.identity().subtype());assertEquals("UNAVAILABLE",relation.properties().get("nativeGenerationAvailability"));
        return BrowseRequest.newBuilder().setSessionId(owner.id).setDocumentId("native-temp-view-browse").setCatalog("busydata").setSchema(schema).setTable(TABLE).setRowLimit(10)
            .setMetadataSnapshotRevision(snapshot.revision()).setMetadataObjectIdentity(relation.identity().key())
            .addConditions(RowCondition.newBuilder().setColumn("marker").setPredicate(ValuePredicate.EQUAL).setValue(Value.newBuilder().setText("temp"))).build();
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL"})
    void failedCoverageRetirementCannotKeepKnownChangedTemporaryAuthorityAvailable(String engine)throws Exception {
        var counter=new Counter();
        try(var fixture=new EngineFixture(root,engine,counter::connect)) {
            var owner=fixture.open();var observer=fixture.open();setup(fixture,owner,false);var platform=fixture.metadata.metadataPlatform();
            String target=owner.adapter.table("busydata",owner.context.temporarySchema(),TABLE);
            var retained=fixture.results.get(fixture.execute(owner,"SELECT id,marker FROM "+target).info().getResults(0).getResultId());
            var planner=new ChangePlanner(fixture.safety,fixture.results,platform);var drafts=new EditDrafts(fixture.metadata,fixture.results,planner);
            var changes=ChangeRequest.newBuilder().setSessionId(owner.id).setResultId(retained.id).setCatalog("busydata").setSchema(owner.context.temporarySchema()).setTable(TABLE)
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,Assignments.value(Value.newBuilder().setText("edited").build()))).build();
            var saved=drafts.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(owner.id).setDocumentId("temp-capacity-draft").setChanges(changes).build());
            String draftId=saved.getDrafts(0).getDraftId();byte[] draft=fixture.metadata.editDraft(draftId).data().toByteArray();
            var explorer=new Explorer(platform);var request=selected(fixture,owner);var approval=TableBrowse.review(owner,request,explorer,fixture.safety);
            var durable=platform.publishedSnapshot(owner);long observerRevision=platform.capture(observer).revision();int jobs=fixture.jobs.list(owner.id).size();
            var cached=platform.capture(owner);var cachedRelation=cached.identity(request.getMetadataObjectIdentity()).orElseThrow();
            var cachedColumnScope=new MetadataScope("busydata",request.getSchema(),TABLE,ObjectKind.COLUMN);
            String cachedColumns=MetadataFingerprint.objects(cached.select(cachedColumnScope).stream().map(cached::projection).toList());
            long revision=owner.revision,context=owner.contextRevision;
            owner.lock.lock();try(var statement=owner.connection.createStatement()){
                var nativeIdentity=NativeRelationReader.inspect(owner,"busydata",request.getSchema(),TABLE);
                // A column-only comment preserves relation generation and the
                // early relation marker, then fails the late column digest.
                statement.execute("COMMENT ON COLUMN "+target+"."+owner.adapter.quote("marker")+" IS 'capacity-retirement-probe'");
                assertEquals(nativeIdentity,NativeRelationReader.inspect(owner,"busydata",request.getSchema(),TABLE));
                var markers=explorer.fetchBranch(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(request.getSchema()).setKind(ObjectKind.TABLE).setSearch(TABLE).setExactName(true).setIntrospectionLevel(1).setLimit(1).build(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
                assertEquals(1,markers.size());assertEquals(cachedRelation.properties().get("catalogFingerprint"),markers.getFirst().getPropertiesOrThrow("catalogFingerprint"),"The pressure fixture must reach past the early relation marker guard");
                var columns=explorer.fetchBranch(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(request.getSchema()).setTable(TABLE).setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).setLimit(500).build(),System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(10));
                var normalized=columns.stream().map(column->MetadataObject.from(cached.source(),cached.profileId(),owner.id,cached.rules(),column,IntrospectionLevel.STRUCTURE,owner.revision,owner.contextRevision).projection(0,0)).toList();
                assertNotEquals(cachedColumns,MetadataFingerprint.objects(normalized),"A genuine late column digest mismatch must remain");
            }finally{owner.lock.unlock();}
            assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);assertEquals(cached.revision(),platform.capture(owner).revision(),"The raw metadata reads do not publish or warm the changed shape");
            var reservation=new AtomicReference<MetadataPlatform.AcquisitionAdmission>();counter.nativeReads.set(0);
            counter.secondNativeClose.set(()->{try{reservation.set(reserveRemaining(platform));}catch(Exception failed){throw new AssertionError("Failed to reserve actual remaining metadata admission",failed);}});
            try {
                var rejected=assertThrows(WorkbenchFailure.class,()->TableBrowse.submit(owner,request.toBuilder().setExecutionId(UUID.randomUUID().toString()).setApprovalToken(approval.getToken()).build(),explorer,fixture.safety,fixture.jobs));
                assertEquals(WorkbenchFailure.Reason.STALE,rejected.reason());assertNotNull(reservation.get(),"The capacity guard must fire after native reads, before coverage retirement");
                assertTrue(rejected.getSuppressed().length>0,"Fallible coverage retirement must actually fail under exhausted admission");
                var current=platform.capture(owner);var scope=new MetadataScope("busydata",request.getSchema(),TABLE,ObjectKind.COLUMN);
                assertEquals(MetadataState.UNKNOWN,current.sessionResolution().state());assertFalse(current.scopeResolutionAvailable(scope));assertFalse(current.complete(scope,IntrospectionLevel.STRUCTURE));
                var page=explorer.explore(owner,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(request.getSchema()).setTable(TABLE).setKind(ObjectKind.COLUMN).setIntrospectionLevel(2).setLimit(500).build());
                assertFalse(page.getComplete(),"Explorer and SQL consume the same unavailable resolution state");
                assertSame(durable,platform.publishedSnapshot(owner));assertEquals(observerRevision,platform.capture(observer).revision());
                assertEquals(jobs,fixture.jobs.list(owner.id).size());assertEquals(0,counter.prepared.get());assertEquals(0,counter.executed.get());
                assertEquals("temp",retained.read(0).getValues(1).getText());assertArrayEquals(draft,fixture.metadata.editDraft(draftId).data().toByteArray());
            }finally{counter.secondNativeClose.set(null);var held=reservation.get();if(held!=null)held.close();}
            assertPermanentUntouched(fixture,observer);
        }
    }
    /** Existing reservation API only; no ledger mutation, memory allocation or SQL retry. */
    private static MetadataPlatform.AcquisitionAdmission reserveRemaining(MetadataPlatform platform)throws Exception {
        var reservation=platform.admitAcquisition();boolean returned=false;
        try {
            var lockField=MetadataPlatform.class.getDeclaredField("admissionLock");lockField.setAccessible(true);
            var resident=MetadataPlatform.class.getDeclaredMethod("residentEstimate");resident.setAccessible(true);
            var ledger=MetadataPlatform.class.getDeclaredField("acquisitions");ledger.setAccessible(true);
            var reserve=MetadataPlatform.AcquisitionAdmission.class.getDeclaredMethod("reserveAdditional",long.class);reserve.setAccessible(true);
            synchronized(lockField.get(platform)) {
                long used=(Long)resident.invoke(platform);for(var bytes:((Map<?,?>)ledger.get(platform)).values())used+=(Long)bytes;
                long remaining=MetadataPlatform.MAX_TOTAL_BYTES-used;assertTrue(remaining>0);reserve.invoke(reservation,remaining);
            }
            returned=true;return reservation;
        }finally{if(!returned)reservation.close();}
    }
    private static void mutate(SessionRegistry.Session owner,BrowseRequest request,boolean recreate,boolean extra)throws Exception {
        String target=owner.adapter.table(request.getCatalog(),request.getSchema(),TABLE);
        owner.lock.lock();try(var statement=owner.connection.createStatement()) {
            if(recreate) {
                statement.execute("DROP TABLE "+target);
                statement.execute("CREATE TEMPORARY TABLE "+owner.adapter.quote(TABLE)+"(id INTEGER PRIMARY KEY,marker VARCHAR(40)"+(extra?",extra INTEGER DEFAULT 5":"")+")");
                statement.execute("INSERT INTO "+owner.adapter.quote(TABLE)+"(id,marker) VALUES(1,'temp')");
            }else statement.execute("ALTER TABLE "+target+" ADD COLUMN extra INTEGER DEFAULT 5");
        }finally{owner.lock.unlock();}
    }
}
