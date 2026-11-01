package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import java.sql.SQLException;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Required genuine-engine metadata acceptance. Missing Docker/images is a failure. */
class MetadataPlatformIT {
    @TempDir Path root;
    private static MetadataConfiguration level(MetadataConfiguration before,IntrospectionLevel level) {
        return new MetadataConfiguration(before.revision()+1,before.includedCatalogs(),before.excludedCatalogs(),before.includedSchemas(),before.excludedSchemas(),before.systemObjects(),before.kinds(),before.includePatterns(),before.excludePatterns(),level,before.scopeLevels());
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void levelsAtomicSnapshotsCompositeRelationshipsAndRoutineSignatures(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();String schema=fixture.schema();
            fixture.execute(session,"CREATE TABLE metadata_parent(a INTEGER,b INTEGER,PRIMARY KEY(a,b)); CREATE TABLE metadata_child(id INTEGER PRIMARY KEY,a INTEGER,b INTEGER,n DECIMAL(40,12) DEFAULT 1.25,CONSTRAINT metadata_fk FOREIGN KEY(a,b) REFERENCES metadata_parent(a,b)); CREATE VIEW metadata_view AS SELECT id,n FROM metadata_child");
            fixture.execute(session,fixture.engine==Engine.POSTGRESQL?"CREATE FUNCTION metadata_routine(a INTEGER,b TEXT DEFAULT 'x') RETURNS INTEGER LANGUAGE sql AS 'SELECT a'":"CREATE FUNCTION metadata_routine(a INTEGER) RETURNS INTEGER DETERMINISTIC RETURN a");
            platform.configure(session,level(platform.configuration(session),IntrospectionLevel.NAMES));
            var names=explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            assertEquals(2,names.namespace("busydata",schema,ObjectKind.TABLE,"").size());
            assertTrue(names.namespace("busydata",schema,ObjectKind.COLUMN,"metadata_child").isEmpty());
            assertTrue(names.coverage().values().stream().allMatch(c->c.level()==IntrospectionLevel.NAMES));
            platform.configure(session,level(platform.configuration(session),IntrospectionLevel.STRUCTURE));
            var structural=explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            assertEquals(4,structural.namespace("busydata",schema,ObjectKind.COLUMN,"metadata_child").size());
            assertTrue(names.namespace("busydata",schema,ObjectKind.COLUMN,"metadata_child").isEmpty(),"An already published snapshot is immutable");
            var numeric=structural.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_child","n",true).getFirst();assertEquals("40",numeric.properties().get("precision"));assertEquals("12",numeric.properties().get("scale"));
            var relationship=structural.outgoing("busydata",schema,"metadata_child").getFirst();assertEquals("2",relationship.properties().get("columnCount"));assertEquals("a",relationship.properties().get("column.0"));assertEquals("b",relationship.properties().get("referencedColumn.1"));assertEquals("true",relationship.properties().get("relationshipVerified"));
            assertEquals(1,structural.incoming("busydata",schema,"metadata_parent").size());assertTrue(structural.incomingComplete());
            var routine=structural.resolve("busydata",schema,ObjectKind.ROUTINE,"","metadata_routine",true).getFirst();assertFalse(routine.identity().signature().isEmpty());assertEquals("AVAILABLE",routine.properties().get("signatureAvailability"));assertEquals("a",routine.properties().get("parameter.0.name"));assertFalse(routine.properties().get("returnType").isBlank());
            if(fixture.engine==Engine.POSTGRESQL){assertEquals("2",routine.properties().get("parameterCount"));assertEquals("true",routine.properties().get("parameter.1.optional"));}
            var source=explorer.explore(session,ExploreRequest.newBuilder().setKind(ObjectKind.VIEW).setCatalog("busydata").setSchema(schema).setSearch("metadata_view").setExactName(true).setIntrospectionLevel(3).setIndependentMetadata(true).build());
            assertEquals(3,source.getIntrospectionLevel());assertFalse(source.getObjects(0).getDefinition().isBlank());assertFalse(source.getObjects(0).getPropertiesOrDefault("sourceProvenance","").isEmpty());
            var originalIdentity=structural.resolve("busydata",schema,ObjectKind.TABLE,"","metadata_child",true).getFirst().identity().key();
            explorer.explore(session,ExploreRequest.newBuilder().setGlobalSearch(true).setSearch("metadata_child").build());
            var afterSearch=platform.capture(session).resolve("busydata",schema,ObjectKind.TABLE,"","metadata_child",true);assertEquals(1,afterSearch.size());assertEquals(originalIdentity,afterSearch.getFirst().identity().key(),"Names-only search cannot replace a native identity or strip structural evidence");
            var external=fixture.open();external(fixture,external,"ALTER TABLE metadata_child ADD COLUMN fragment_added INTEGER");
            var fragmentRequest=ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setCatalog("busydata").setSchema(schema).setTable("metadata_child").setRefresh(true).setRefreshMode("FRAGMENT").build();
            var fragment=explorer.explore(session,fragmentRequest);assertEquals(5,fragment.getObjectsCount());assertEquals(1,platform.capture(session).outgoing("busydata",schema,"metadata_child").size());
            external(fixture,external,"ALTER TABLE metadata_child ADD COLUMN incremental_added INTEGER");
            assertEquals(6,explorer.explore(session,fragmentRequest.toBuilder().setRefreshMode("INCREMENTAL").build()).getObjectsCount());
            assertEquals(6,explorer.explore(session,fragmentRequest.toBuilder().setRefreshMode("FULL").build()).getObjectsCount());
            assertThrows(IllegalArgumentException.class,()->explorer.explore(session,fragmentRequest.toBuilder().setRefreshMode("UNRECOGNIZED").build()));
            assertEquals(TransactionState.IDLE,session.state);assertEquals(TransactionState.IDLE,session.adapter.transaction(session.connection));
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void incrementalScansSkipUnchangedDetailsAndDetectExternalDdl(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();var external=fixture.open();var explorer=new Explorer(fixture.metadata);String schema=fixture.schema();
            external(fixture,session,"CREATE TABLE incremental_a(id INTEGER PRIMARY KEY,n INTEGER); CREATE TABLE incremental_b(id INTEGER PRIMARY KEY)");
            explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);explorer.refreshContext(session);
            var unchanged=explorer.metadata().diagnostics(session).orElseThrow();assertTrue(unchanged.scannedScopes()>0);assertEquals(0,unchanged.fetchedScopes(),unchanged.toString());
            external(fixture,external,"ALTER TABLE incremental_a ADD COLUMN added_exact DECIMAL(30,10); CREATE TABLE incremental_added(id INTEGER)");
            var changed=explorer.refreshContext(session);assertEquals(1,changed.resolve("busydata",schema,ObjectKind.COLUMN,"incremental_a","added_exact",true).size());assertEquals(1,changed.resolve("busydata",schema,ObjectKind.TABLE,"","incremental_added",true).size());
            var work=explorer.metadata().diagnostics(session).orElseThrow();assertTrue(work.fetchedScopes()>0);assertTrue(work.fetchedScopes()<work.scannedScopes(),work.toString());
            external(fixture,external,"ALTER TABLE incremental_added RENAME TO incremental_renamed; DROP TABLE incremental_b");
            var renamed=explorer.refreshContext(session);assertTrue(renamed.resolve("busydata",schema,ObjectKind.TABLE,"","incremental_added",true).isEmpty());assertTrue(renamed.resolve("busydata",schema,ObjectKind.TABLE,"","incremental_b",true).isEmpty());assertEquals(1,renamed.resolve("busydata",schema,ObjectKind.TABLE,"","incremental_renamed",true).size());
            external(fixture,external,"ALTER TABLE incremental_a ADD COLUMN fragment_only INTEGER");
            var fragment=explorer.refreshFragment(session,"busydata",schema,"incremental_a",ObjectKind.TABLE);assertEquals(1,fragment.resolve("busydata",schema,ObjectKind.COLUMN,"incremental_a","fragment_only",true).size());assertEquals(MetadataPlatform.RefreshMode.FRAGMENT,explorer.metadata().diagnostics(session).orElseThrow().mode());
            external(fixture,external,"CREATE TABLE new_referencing(id INTEGER PRIMARY KEY,parent_id INTEGER,CONSTRAINT new_external_fk FOREIGN KEY(parent_id) REFERENCES incremental_a(id))");
            fragment=explorer.refreshFragment(session,"busydata",schema,"incremental_a",ObjectKind.TABLE);assertEquals(1,fragment.incoming("busydata",schema,"incremental_a").size(),"Fragment refresh must discover incoming edges absent from the old snapshot");
            external(fixture,external,"ALTER TABLE new_referencing DROP "+(fixture.engine==Engine.POSTGRESQL?"CONSTRAINT":"FOREIGN KEY")+" new_external_fk");
            fragment=explorer.refreshFragment(session,"busydata",schema,"incremental_a",ObjectKind.TABLE);assertTrue(fragment.incoming("busydata",schema,"incremental_a").isEmpty(),"Deleted incoming edges must be removed from their referencing owner");
            var cancelled=io.grpc.Context.current().withCancellation();cancelled.cancel(new CancellationException("superseded fixture"));long before=fragment.revision();assertThrows(CancellationException.class,()->cancelled.call(()->explorer.refreshContext(session)));assertEquals(before,explorer.metadata().capture(session).revision());
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void temporaryOverlaysAndTransactionOutcomesNeverLeakToAnotherSession(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();var other=fixture.open();var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();String schema=fixture.schema();
            fixture.execute(session,"CREATE TABLE persistent_base(id INTEGER PRIMARY KEY)");explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            {var smart=fixture.jobs.metadataRefresh();
                fixture.execute(session,"CREATE TEMPORARY TABLE temporary_owned(v INTEGER)");
                var owner=platform.capture(session);assertTrue(owner.identities().values().stream().anyMatch(o->o.identity().name().equals("temporary_owned")&&o.identity().sessionOwner().equals(session.id)));
                assertTrue(platform.capture(other).identities().values().stream().noneMatch(o->o.identity().name().equals("temporary_owned")));
                fixture.execute(session,"SELECT 1");assertTrue(platform.capture(session).identities().values().stream().anyMatch(o->o.identity().name().equals("temporary_owned")));
                fixture.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.BEGIN).build());
                fixture.execute(session,"CREATE TABLE pending_structure(id INTEGER)");
                if(fixture.engine==Engine.POSTGRESQL) {
                    assertTrue(platform.capture(other).resolve("busydata",schema,ObjectKind.TABLE,"","pending_structure",true).isEmpty());
                    fixture.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.ROLLBACK).build());smart.transaction(session,SessionAction.ROLLBACK);
                    assertTrue(platform.capture(session).identities().values().stream().noneMatch(o->o.identity().name().equals("pending_structure")));
                }else {
                    assertEquals(TransactionState.IDLE,session.state,"MySQL/MariaDB ordinary DDL implicitly commits");awaitRelation(platform,other,schema,"pending_structure");
                    fixture.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.ROLLBACK).build());smart.transaction(session,SessionAction.ROLLBACK);
                }
                assertTrue(platform.capture(session).identities().values().stream().anyMatch(o->o.identity().name().equals("temporary_owned")),"Existing temporary definitions survive ordinary rollback");
                String temporarySchema=fixture.engine==Engine.POSTGRESQL?session.context.temporarySchema():schema;
                assertTrue(platform.capture(session).complete(new MetadataScope("busydata",temporarySchema,"temporary_owned",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE),"Transaction resolution preserves the complete owned column branch");
                fixture.execute(session,"DROP TABLE temporary_owned");assertTrue(platform.capture(session).identities().values().stream().noneMatch(o->o.identity().name().equals("temporary_owned")));
                fixture.execute(session,"CREATE TEMPORARY TABLE closing_owned(v INTEGER)");assertTrue(platform.sessionOverlayCount()>0);
                fixture.sessions.close(session.id,true);assertEquals(0,platform.sessionOverlayCount(),"Physical close releases overlays without a later capture or RPC hook");
                platform.markSessionStale(session,"Late failed refresh after physical close");assertEquals(0,platform.sessionOverlayCount(),"A late failure cannot recreate an ended overlay");
                assertTrue(platform.capture(other).identities().values().stream().noneMatch(o->!o.identity().sessionOwner().isEmpty()));
            }
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void sourceConfigurationPersistsAcrossCacheRebuildAndFiltersIntrospection(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();var explorer=new Explorer(fixture.metadata);String schema=fixture.schema();
            fixture.execute(session,"CREATE TABLE allowed_table(id INTEGER); CREATE TABLE excluded_table(id INTEGER)");
            var config=new MetadataConfiguration(2,Set.of("busydata"),Set.of(),Set.of(schema),Set.of(),false,MetadataConfiguration.defaults().kinds(),List.of("allowed*"),List.of(),IntrospectionLevel.STRUCTURE,Map.of());
            explorer.metadata().configure(session,config);var snapshot=explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);assertEquals(List.of("allowed_table"),snapshot.namespace("busydata",schema,ObjectKind.TABLE,"").stream().map(o->o.identity().name()).toList());assertTrue(snapshot.namespace("busydata",schema,ObjectKind.COLUMN,"excluded_table").isEmpty());
            assertSame(explorer.metadata(),new Explorer(fixture.metadata).metadata(),"Every feature of one backend writer shares the same metadata authority");
            assertEquals(2,new Explorer(fixture.metadata).metadata().configuration(session).revision());
            fixture.jobs.close();fixture.metadata.close();
            java.nio.file.Files.delete(root.resolve("metadata_catalog.sqlite"));
            try(var reopened=new io.busystack.busydata.storage.MetadataStore(root)){var rebuilt=new Explorer(reopened);assertEquals(config,rebuilt.metadata().configuration(session));assertTrue(rebuilt.metadata().capture(session).objects().isEmpty());}
        }
    }
    private static void awaitRelation(MetadataPlatform platform,io.busystack.busydata.sessions.SessionRegistry.Session session,String schema,String name)throws Exception {
        long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(20);
        while(System.nanoTime()<deadline){if(!platform.capture(session).resolve("busydata",schema,ObjectKind.TABLE,"",name,true).isEmpty())return;Thread.sleep(20);}
        fail("Acknowledged durable DDL was not refreshed: "+name);
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void nativeTypesDefaultsGeneratedCollationsAndDomainsRemainEngineSpecific(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();var explorer=new Explorer(fixture.metadata);String schema=fixture.schema();
            if(fixture.engine==Engine.POSTGRESQL)fixture.execute(session,"CREATE TYPE metadata_mood AS ENUM ('plain','comma, quote''漢'); CREATE DOMAIN metadata_amount AS NUMERIC(40,12) DEFAULT 1.25 CHECK (VALUE>0); CREATE TABLE metadata_native(id INTEGER GENERATED ALWAYS AS IDENTITY, amount metadata_amount, mood metadata_mood, items INTEGER[], label TEXT COLLATE \"C\", calculated INTEGER GENERATED ALWAYS AS (1+1) STORED)");
            else fixture.execute(session,"CREATE TABLE metadata_native(id INTEGER AUTO_INCREMENT PRIMARY KEY,amount DECIMAL(40,12) DEFAULT 1.25,mood ENUM('plain','comma, quote''漢'),items SET('a','b'),label TEXT COLLATE utf8mb4_bin,calculated INTEGER GENERATED ALWAYS AS (1+1) STORED, unsigned_value BIGINT UNSIGNED)");
            var snapshot=explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);
            var calculated=snapshot.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_native","calculated",true).getFirst();assertEquals("YES",calculated.properties().get("generated"));
            var identity=snapshot.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_native","id",true).getFirst();assertEquals("YES",identity.properties().get("autoIncrement"));
            if(fixture.engine==Engine.POSTGRESQL){var array=snapshot.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_native","items",true).getFirst();assertEquals("23",array.properties().get("arrayElementTypeId"));assertEquals(",",array.properties().get("arrayElementDelimiter"));}
            var label=snapshot.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_native","label",true).getFirst();assertFalse(label.properties().get("collation").isEmpty());
            if(fixture.engine==Engine.POSTGRESQL) {
                var enumeration=snapshot.resolve("busydata",schema,ObjectKind.TYPE,"","metadata_mood",true).getFirst();assertEquals("e",enumeration.properties().get("nativeTypeKind"));assertEquals("comma, quote'漢",enumeration.properties().get("enumLabel.1"));
                var domain=snapshot.resolve("busydata",schema,ObjectKind.TYPE,"","metadata_amount",true).getFirst();assertEquals("numeric(40,12)",domain.properties().get("baseType"));assertEquals("1",domain.properties().get("domainConstraintCount"));
                assertEquals("d",snapshot.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_native","amount",true).getFirst().properties().get("nativeTypeKind"));
            }else {
                assertEquals("true",snapshot.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_native","unsigned_value",true).getFirst().properties().get("unsigned"));
                assertTrue(snapshot.resolve("busydata",schema,ObjectKind.COLUMN,"metadata_native","mood",true).getFirst().properties().get("type").startsWith("enum("));
                assertThrows(UnsupportedOperationException.class,()->explorer.explore(session,ExploreRequest.newBuilder().setKind(ObjectKind.TYPE).setSchema(schema).build()));
            }
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void equivalentRefreshesCoalesceCancelIndependentlyAndRejectOverlappingOlderPublications(String engine)throws Exception {
        var metadataOpens=new java.util.concurrent.atomic.AtomicInteger();var started=new CountDownLatch(1);var release=new CountDownLatch(1);
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            if(request.getProfile().getReadOnly()){metadataOpens.incrementAndGet();started.countDown();if(!release.await(20,TimeUnit.SECONDS))throw new SQLException("Fixture metadata admission gate expired");}
            return adapter.connect(request,port);
        })) {
            var session=fixture.open();external(fixture,session,"CREATE TABLE coalesced_table(id INTEGER PRIMARY KEY)");var explorer=new Explorer(fixture.metadata);var platform=explorer.metadata();
            try(var workers=Executors.newVirtualThreadPerTaskExecutor()) {
                var primary=workers.submit(()->explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL));assertTrue(started.await(10,TimeUnit.SECONDS));
                var cancelled=io.grpc.Context.current().withCancellation();var entered=new CountDownLatch(1);
                var joined=workers.submit(()->cancelled.call(()->{entered.countDown();return explorer.refreshContext(session,MetadataPlatform.RefreshMode.FULL);}));assertTrue(entered.await(5,TimeUnit.SECONDS));cancelled.cancel(new CancellationException("Superseded joined refresh"));
                assertInstanceOf(CancellationException.class,assertThrows(ExecutionException.class,()->joined.get(5,TimeUnit.SECONDS)).getCause());assertFalse(primary.isDone());assertEquals(1,metadataOpens.get());
                release.countDown();primary.get(20,TimeUnit.SECONDS);assertEquals(1,metadataOpens.get());
            }finally{release.countDown();}
            var broad=new MetadataScope("busydata",fixture.schema(),"",ObjectKind.TABLE);var exact=new MetadataScope("busydata",fixture.schema(),"",ObjectKind.TABLE,"coalesced_table",true,"",ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED);
            var values=platform.capture(session).select(exact).stream().map(platform.capture(session)::projection).toList();
            for(boolean olderBroad:new boolean[]{true,false}) {
                long older=platform.beginRefresh(session),newer=platform.beginRefresh(session);var newestScope=olderBroad?exact:broad;var oldScope=olderBroad?broad:exact;
                var newestCoverage=new MetadataCoverage(newestScope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"verified",session.revision,session.contextRevision,System.currentTimeMillis(),"");
                var current=platform.publish(session,newer,platform.capture(session).rules(),Map.of(newestScope,new MetadataPlatform.Branch(values,newestCoverage)),false);
                var oldCoverage=new MetadataCoverage(oldScope,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"older",session.revision,session.contextRevision,System.currentTimeMillis(),"");
                var unrelated=new MetadataScope("busydata",fixture.schema(),"",ObjectKind.VIEW);
                var unrelatedCoverage=new MetadataCoverage(unrelated,IntrospectionLevel.STRUCTURE,MetadataState.AVAILABLE,true,"empty",session.revision,session.contextRevision,System.currentTimeMillis(),"");
                assertThrows(IllegalStateException.class,()->platform.publish(session,older,current.rules(),Map.of(oldScope,new MetadataPlatform.Branch(values,oldCoverage),unrelated,new MetadataPlatform.Branch(List.of(),unrelatedCoverage)),false));
                assertSame(current,platform.capture(session),"No other branch of a rejected stale publication may become visible");
            }
        }finally{release.countDown();}
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void durableRecoveryShapeAndStrongReviewFingerprintsHaveSeparateStablePurposes(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var session=fixture.open();var external=fixture.open();
            fixture.execute(session,"CREATE TABLE fingerprint_rows(id INTEGER PRIMARY KEY,n DECIMAL(20,8) DEFAULT 1.25,CONSTRAINT fingerprint_check CHECK(n>=0)); INSERT INTO fingerprint_rows(id) VALUES(1)");
            // This test measures stable recovery/strong review fingerprints.
            // Explicit introspection owns its baseline; cold bootstrap and
            // concurrent reservation rejection have their dedicated controls.
            fixture.warm(session,"fingerprint_rows");
            TableStructure before;
            session.lock.lock();try{before=fixture.metadata.metadataPlatform().readTableStructure(session,"busydata",fixture.schema(),"fingerprint_rows");var fresh=fixture.metadata.metadataPlatform().readTableStructure(session,"busydata",fixture.schema(),"fingerprint_rows");assertEquals(before.signature(),fresh.signature());assertEquals(before.recoverySignature(),fresh.recoverySignature());}finally{session.lock.unlock();}
            var result=fixture.execute(session,"SELECT id,n FROM "+session.adapter.table("busydata",fixture.schema(),"fingerprint_rows")).info().getResults(0).getResultId();var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());
            var changes=ChangeRequest.newBuilder().setSessionId(session.id).setCatalog("busydata").setSchema(fixture.schema()).setTable("fingerprint_rows").setResultId(result)
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,Assignments.value(Value.newBuilder().setDecimal("1.50000000").build()))).build();
            var reviewed=planner.preview(session,changes);
            external(fixture,external,"ALTER TABLE fingerprint_rows DROP "+(fixture.engine==Engine.POSTGRESQL?"CONSTRAINT":fixture.engine==Engine.MYSQL?"CHECK":"CONSTRAINT")+" fingerprint_check; ALTER TABLE fingerprint_rows ADD CONSTRAINT fingerprint_check CHECK(n<2)");
            session.lock.lock();try{var changed=fixture.metadata.metadataPlatform().readTableStructure(session,"busydata",fixture.schema(),"fingerprint_rows");assertNotEquals(before.signature(),changed.signature(),"Native check rules invalidate prior review");assertEquals(before.recoverySignature(),changed.recoverySignature(),"Recovery preserves intentions and requires a new review rather than discarding user data");}finally{session.lock.unlock();}
            var applied=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(reviewed.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),fixture.jobs);
            assertEquals(JobState.FAILED,applied.finished.get(20,TimeUnit.SECONDS).getState());
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT n FROM fingerprint_rows WHERE id=1")){assertTrue(rows.next());assertEquals("1.25000000",rows.getBigDecimal(1).toPlainString());}
            if(fixture.engine==Engine.POSTGRESQL) {
                fixture.execute(session,"CREATE TYPE fingerprint_enum AS ENUM ('a','b'); CREATE DOMAIN fingerprint_domain AS INTEGER CHECK(VALUE>0); CREATE TABLE fingerprint_native(id INTEGER PRIMARY KEY,e fingerprint_enum,d fingerprint_domain)");
                var first=NativeStructureReader.inspect(session,"busydata",fixture.schema(),"fingerprint_native");
                external(fixture,external,"ALTER TYPE fingerprint_enum ADD VALUE 'c'; ALTER DOMAIN fingerprint_domain ADD CONSTRAINT new_domain_rule CHECK(VALUE<100)");
                var later=NativeStructureReader.inspect(session,"busydata",fixture.schema(),"fingerprint_native");assertNotEquals(first.signature(),later.signature());assertEquals(first.recoverySignature(),later.recoverySignature());
            }
        }
    }
    private static void external(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session,String sql)throws Exception {
        // Deliberately bypass BusyData execution hooks to model external DDL.
        for(var fragment:fixture.analysis.split(sql,fixture.engine,session.context.lexical()))try(var statement=session.connection.createStatement()){statement.execute(fragment.text());}
    }
    @org.junit.jupiter.api.Test void postgresTemporarySequencesRoutinesAndTypesHaveOnlyTheirPhysicalOwner()throws Exception {
        try(var fixture=new EngineFixture(root,"POSTGRESQL")){
            var session=fixture.open();var other=fixture.open();
            fixture.execute(session,"CREATE TEMPORARY SEQUENCE metadata_temp_sequence START WITH 41; CREATE FUNCTION pg_temp.metadata_temp_function(a INTEGER) RETURNS INTEGER LANGUAGE sql AS 'SELECT a'; CREATE TYPE pg_temp.metadata_temp_type AS ENUM ('exact, value','漢')");
            var platform=fixture.metadata.metadataPlatform();var snapshot=platform.capture(session);String temporary=session.context.temporarySchema();assertFalse(temporary.isEmpty());
            for(var target:Map.of(ObjectKind.SEQUENCE,"metadata_temp_sequence",ObjectKind.ROUTINE,"metadata_temp_function",ObjectKind.TYPE,"metadata_temp_type").entrySet()){
                var found=snapshot.resolve("busydata",temporary,target.getKey(),"",target.getValue(),true);assertEquals(1,found.size());assertEquals(session.id,found.getFirst().identity().sessionOwner());
                assertTrue(platform.capture(other).resolve("busydata",temporary,target.getKey(),"",target.getValue(),true).isEmpty());
            }
            assertEquals("41",snapshot.resolve("busydata",temporary,ObjectKind.SEQUENCE,"","metadata_temp_sequence",true).getFirst().properties().get("startValue"));
            var explorer=new Explorer(fixture.metadata);assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->explorer.explore(other,ExploreRequest.newBuilder().setCatalog("busydata").setSchema(temporary).setKind(ObjectKind.TYPE).build()));
            fixture.sessions.command(SessionRequest.newBuilder().setSessionId(session.id).setAction(SessionAction.DISCONNECT).build());platform.endSession(session.id);assertTrue(platform.capture(session).identities().values().stream().noneMatch(object->object.identity().sessionOwner().equals(session.id)));
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void deniedPhysicalGenerationDoesNotFabricateEditableProvenance(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var administrator=fixture.open();fixture.execute(administrator,"CREATE TABLE limited_generation(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO limited_generation VALUES(1,2)");
            try(var statement=administrator.connection.createStatement()){
                statement.execute("CREATE USER 'metadata_limited'@'%' IDENTIFIED BY 'fixture'");
                statement.execute("GRANT SELECT,INSERT,UPDATE,DELETE ON busydata.* TO 'metadata_limited'@'%'");
            }
            var restricted=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setId("limited-source").setUser("metadata_limited")).setPassword("fixture").build());
            var explorer=new Explorer(fixture.metadata);var snapshot=explorer.refreshFragment(restricted,"busydata","busydata","limited_generation",ObjectKind.TABLE);
            var relation=snapshot.resolve("busydata","busydata",ObjectKind.TABLE,"","limited_generation",true).getFirst();
            assertEquals("DENIED",relation.properties().get("nativeGenerationAvailability"));assertFalse(relation.properties().containsKey("nativeGeneration"));
            assertTrue(snapshot.complete(new MetadataScope("busydata","busydata","limited_generation",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
            var result=fixture.results.get(fixture.execute(restricted,"SELECT id,n FROM busydata.limited_generation").info().getResults(0).getResultId());
            assertTrue(result.complete);assertFalse(result.metadataProof().available());assertEquals(MetadataState.DENIED,result.metadataProof().state());
            var assessed=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform()).assess(restricted,ChangeRequest.newBuilder().setSessionId(restricted.id).setCatalog("busydata").setSchema("busydata").setTable("limited_generation").setResultId(result.id).build());
            assertFalse(assessed.getEditable());assertEquals("denied",assessed.getReasonCode());
        }
    }
}
