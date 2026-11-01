package io.busystack.busydata;

import io.busystack.busydata.metadata.IntrospectionLevel;
import io.busystack.busydata.metadata.MetadataState;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.Assignments;
import io.busystack.busydata.schema.ChangePlanner;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.stream.Stream;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Session-local table resolution must never borrow a durable result identity. */
class ProcedureTemporaryMetadataIT {
    @TempDir Path root;

    static Stream<Arguments> enginesAndQualification() {
        return Stream.of("MYSQL", "MARIADB").flatMap(engine ->
            Stream.of(Arguments.of(engine, false), Arguments.of(engine, true)));
    }

    @ParameterizedTest @MethodSource("enginesAndQualification")
    void procedureTemporaryResultsRemainReadOnlyAfterRemoval(String engine, boolean qualified)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var owner=fixture.open();var other=fixture.open();
            fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
            fixture.execute(owner,"CREATE TABLE procedure_rows(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO procedure_rows VALUES(1,2)");
            other.lock.lock();
            try(var statement=other.connection.createStatement()) {
                statement.execute("CREATE PROCEDURE make_procedure_rows() SQL SECURITY DEFINER BEGIN CREATE TEMPORARY TABLE procedure_rows(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO procedure_rows VALUES(1,2); END");
                statement.execute("CREATE PROCEDURE remove_procedure_rows() SQL SECURITY DEFINER DROP TEMPORARY TABLE procedure_rows");
            }finally{other.lock.unlock();}
            fixture.warm(owner,"procedure_rows");
            String table=qualified?owner.adapter.table("busydata",fixture.schema(),"procedure_rows"):owner.adapter.quote("procedure_rows");
            var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());
            var persistent=result(fixture,owner,"SELECT id,n FROM "+table);
            assertTrue(persistent.metadataProof().available());
            assertTrue(planner.assess(owner,request(owner,persistent)).getEditable());

            fixture.execute(owner,"CALL make_procedure_rows()");
            assertFalse(planner.assess(owner,request(owner,persistent)).getEditable(),
                "A same-named temporary table cannot inherit a retained permanent table's editability");
            var temporary=result(fixture,owner,"SELECT id,n FROM "+table);
            assertEquals("2",temporary.read(0).getValues(1).getSignedInteger());
            assertFalse(temporary.metadataProof().capturedStructure(),
                "Durable InnoDB generation is never evidence for a physical temporary table");
            var assessment=planner.assess(owner,request(owner,temporary));
            assertFalse(assessment.getEditable());
            assertFalse(assessment.getReasonCode().isEmpty(),"Read-only provenance has an explicit structured reason");

            fixture.warm(other,"procedure_rows");
            var independent=result(fixture,other,"SELECT id,n FROM "+other.adapter.table("busydata",fixture.schema(),"procedure_rows"));
            assertTrue(independent.metadataProof().available(),"Session-local uncertainty cannot leak to another physical session");
            assertTrue(planner.assess(other,request(other,independent)).getEditable());
            assertFalse(temporary.metadataProof().capturedStructure(),"Independent durable refresh cannot certify a temporary result");

            fixture.execute(owner,"CALL remove_procedure_rows()");
            var afterRemoval=fixture.metadata.metadataPlatform().capture(owner);
            fixture.warm(owner,"procedure_rows");
            var beforeFresh=fixture.metadata.metadataPlatform().capture(owner);
            var freshlyInspected=beforeFresh.resolve("busydata","busydata",ObjectKind.TABLE,"","procedure_rows",true);
            assertEquals(1,freshlyInspected.size());assertEquals(MetadataState.AVAILABLE,freshlyInspected.getFirst().state(),()->"Explicit fragment inspection must publish fresh table facts: "+rawRelation(beforeFresh,owner));
            assertTrue(beforeFresh.catalogCoverage().get(new io.busystack.busydata.metadata.MetadataScope("busydata","busydata","procedure_rows",ObjectKind.COLUMN)).complete());
            var fresh=result(fixture,owner,"SELECT id,n FROM "+table);
            assertTrue(fresh.metadataProof().available(),()->{
                var snapshot=fixture.metadata.metadataPlatform().capture(owner);var current=io.busystack.busydata.metadata.RetainedMetadataProof.capture(snapshot,fresh.columns,owner.targetProfile(),owner.id,owner.context);
                return "Fresh retained proof="+fresh.metadataProof().state()+":"+fresh.metadataProof().availability()+" current="+current.state()+":"+current.availability()+" resolution="+snapshot.sessionResolution().state()+" epoch="+snapshot.sessionResolution().epoch()+" verified="+snapshot.sessionResolution().verified()+" snapshot="+snapshot.revision()+" nativeGeneration="+current.nativeGeneration()+" afterRemoval="+rawRelation(afterRemoval,owner)+" beforeFresh="+rawRelation(beforeFresh,owner)+" beforePreflight="+io.busystack.busydata.metadata.RetainedMetadataProof.sourceRelation(beforeFresh,owner.targetProfile(),owner.id,"SELECT id,n FROM "+table,owner.context).isPresent()+" currentRaw="+rawRelation(snapshot,owner)+" scopes="+snapshot.coverage().values().stream().filter(c->c.scope().parent().equals("procedure_rows")).map(c->c.scope().kind()+":"+c.state()+":"+c.complete()+":"+c.limitation()).toList();
            });
            assertTrue(planner.assess(owner,request(owner,fresh)).getEditable());
            assertFalse(temporary.metadataProof().capturedStructure(),"Removing the temporary table never upgrades an old result");
            assertFalse(planner.assess(owner,request(owner,temporary)).getEditable());
            var rejected=assertThrows(WorkbenchFailure.class,()->planner.preview(owner,update(owner,temporary,9)));
            assertTrue(java.util.Set.of(WorkbenchFailure.Reason.INCOMPLETE_METADATA,WorkbenchFailure.Reason.STALE,WorkbenchFailure.Reason.UNSUPPORTED).contains(rejected.reason()));
            assertEquals(2,durable(other));

            EditingIT.apply(planner,fixture.jobs,owner,update(owner,fresh,3));
            assertEquals(3,durable(other),"Normal permanent-table reviewed edits remain supported");
            assertFalse(temporary.metadataProof().capturedStructure());
        }
    }

    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void failedProcedureAndExplicitRollbackDoNotProveTemporaryAbsence(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine)) {
            var owner=fixture.open();var other=fixture.open();
            fixture.introspectionLevel(owner,IntrospectionLevel.STRUCTURE);
            fixture.execute(owner,"CREATE TABLE procedure_rows(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO procedure_rows VALUES(1,2)");
            other.lock.lock();
            try(var statement=other.connection.createStatement()) {
                statement.execute("CREATE PROCEDURE fail_make_procedure_rows() SQL SECURITY DEFINER BEGIN CREATE TEMPORARY TABLE procedure_rows(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO procedure_rows VALUES(1,2); SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='Controlled fixture failure'; END");
            }finally{other.lock.unlock();}
            fixture.warm(owner,"procedure_rows");
            String table=owner.adapter.table("busydata",fixture.schema(),"procedure_rows");
            var persistent=result(fixture,owner,"SELECT id,n FROM "+table);
            assertTrue(persistent.metadataProof().available());
            fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.BEGIN).build());
            var failed=fixture.submit(owner,"CALL fail_make_procedure_rows()");
            EditingIT.await(failed);assertEquals(JobState.FAILED,failed.state,failed.info().toString());
            var platform=fixture.metadata.metadataPlatform();
            assertEquals(MetadataState.UNKNOWN,platform.capture(owner).sessionResolution().state(),
                "A failed procedure may already have created nonrollbackable temporary structure");
            fixture.sessions.command(SessionRequest.newBuilder().setSessionId(owner.id).setAction(SessionAction.ROLLBACK).build());
            fixture.jobs.metadataRefresh().transaction(owner,SessionAction.ROLLBACK);
            var temporary=result(fixture,owner,"SELECT id,n FROM "+table);
            assertEquals(0,temporary.rows(),"Rollback removes the inserted rows but not the physical temporary table");
            assertFalse(temporary.metadataProof().capturedStructure());
            var planner=new ChangePlanner(fixture.safety,fixture.results,platform);
            assertFalse(planner.assess(owner,request(owner,persistent)).getEditable());
            assertFalse(planner.assess(owner,request(owner,temporary)).getEditable());
            assertEquals(2,durable(other));
        }
    }

    /** Pure failure-only raw evidence: no JDBC, values, or mutable model access. */
    private static String rawRelation(io.busystack.busydata.metadata.MetadataSnapshot snapshot,SessionRegistry.Session owner) {
        var candidates=new java.util.ArrayList<String>();
        for(var kind:java.util.List.of(ObjectKind.TABLE,ObjectKind.VIEW))for(var object:snapshot.resolve("busydata","busydata",kind,"","procedure_rows",true)) {
            var id=object.identity();candidates.add(kind+":"+id.key()+":owner="+id.sessionOwner()+":level="+object.level()+":state="+object.state()+":generation="+object.properties().getOrDefault("nativeGeneration","")+":generationState="+object.properties().getOrDefault("nativeGenerationAvailability","")+":temporary="+object.properties().getOrDefault("temporary",""));
        }
        var raw=snapshot.catalogCoverage().values().stream().filter(value->value.scope().catalog().equals("busydata")&&value.scope().schema().equals("busydata")&&(value.scope().parent().equals("procedure_rows")||value.scope().parent().isEmpty()&&(value.scope().kind()==ObjectKind.TABLE||value.scope().kind()==ObjectKind.VIEW)))
            .map(value->value.scope()+":"+value.level()+":"+value.state()+":"+value.complete()+":source="+value.sourceRevision()+":context="+value.contextRevision()+":"+value.limitation()).sorted().toList();
        return "revision="+snapshot.revision()+",epoch="+snapshot.sessionResolution().epoch()+",verified="+snapshot.sessionResolution().verified()+",candidates="+candidates+",coverage="+raw;
    }

    private static ResultStore.Result result(EngineFixture fixture,SessionRegistry.Session owner,String sql)throws Exception {
        return fixture.results.get(fixture.execute(owner,sql).info().getResults(0).getResultId());
    }
    private static ChangeRequest request(SessionRegistry.Session owner,ResultStore.Result result) {
        return ChangeRequest.newBuilder().setSessionId(owner.id).setCatalog("busydata").setSchema("busydata")
            .setTable("procedure_rows").setResultId(result.id).build();
    }
    private static ChangeRequest update(SessionRegistry.Session owner,ResultStore.Result result,int value) {
        return request(owner,result).toBuilder().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE)
            .setSourceRow(0).putValues(2,Assignments.value(EditingIT.integer(value)))).build();
    }
    private static int durable(SessionRegistry.Session owner)throws Exception {
        owner.lock.lock();
        try(var statement=owner.connection.createStatement();var rows=statement.executeQuery("SELECT n FROM busydata.procedure_rows WHERE id=1")) {
            assertTrue(rows.next());int value=rows.getInt(1);assertFalse(rows.next());return value;
        }finally{owner.lock.unlock();}
    }
}
