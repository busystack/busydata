package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.UUID;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real-server collation and native-output regression; never replaced by JDBC mocks. */
class OptimisticValuesIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void changedTextNeverMatchesOnlyBecauseOfCollation(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var external=f.open();
            if(f.engine==Engine.POSTGRESQL)f.execute(session,"CREATE COLLATION optimistic_ci (provider=icu,locale='und-u-ks-level2',deterministic=false)");
            String collation=f.engine==Engine.POSTGRESQL?"optimistic_ci":"utf8mb4_unicode_ci";
            f.execute(session,"CREATE TABLE optimistic_values(id INTEGER PRIMARY KEY,note VARCHAR(100) COLLATE "+collation+",n INTEGER); INSERT INTO optimistic_values VALUES(1,'Case漢😀',10),(2,NULL,20)");
            new Explorer(f.metadata).refreshFragment(session,session.context.catalog(),f.schema(),"optimistic_values",ObjectKind.TABLE);
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            String table=session.adapter.table(session.context.catalog(),f.schema(),"optimistic_values");
            var source=f.results.get(f.execute(session,"SELECT id,note,n FROM "+table+" ORDER BY id").info().getResults(0).getResultId());
            var request=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("optimistic_values")
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,Assignments.value(Value.newBuilder().setSignedInteger("11").build()))).build();
            var plan=planner.preview(session,request);
            f.execute(external,"UPDATE optimistic_values SET note='case漢😀' WHERE id=1");
            try(var statement=session.connection.prepareStatement("SELECT note=? FROM optimistic_values WHERE id=1")){statement.setString(1,"Case漢😀");try(var rows=statement.executeQuery()){assertTrue(rows.next());assertTrue(rows.getBoolean(1),"Fixture must prove ordinary equality ignores the external case change");}}
            var job=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setPlanId(plan.getPlanId()).build(),f.jobs);EditingIT.await(job);
            assertEquals(JobState.FAILED,job.state,job.info().toString());assertEquals("SQLSTATE_40001",job.info().getErrorCode());
            assertEquals("10",f.results.get(f.execute(session,"SELECT n FROM optimistic_values WHERE id=1").info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
            var fresh=f.results.get(f.execute(session,"SELECT id,note,n FROM "+table+" ORDER BY id").info().getResults(0).getResultId());
            EditingIT.apply(planner,f.jobs,session,request.toBuilder().setResultId(fresh.id).build());
            // SQL NULL is a predicate, never a byte/string parameter.
            var nulls=f.results.get(f.execute(session,"SELECT id,note,n FROM "+table+" WHERE id=2").info().getResults(0).getResultId());
            EditingIT.apply(planner,f.jobs,session,request.toBuilder().setResultId(nulls.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,Assignments.value(Value.newBuilder().setSignedInteger("21").build()))).build());
            if(f.engine==Engine.POSTGRESQL){jsonXmlAndFixedPadding(f,session,external);arrayCollationAndBounds(f,session,external);}
        }
    }
    private static void jsonXmlAndFixedPadding(EngineFixture f,SessionRegistry.Session session,SessionRegistry.Session external)throws Exception {
        f.execute(session,"CREATE TABLE optimistic_structured(id INTEGER PRIMARY KEY,js JSON,doc XML,fixed CHAR(5),n INTEGER); INSERT INTO optimistic_structured VALUES(1,'{\"n\":1,\"keep\":\"漢\"}','<root a=\"x\">value</root>','x',1)");
        new Explorer(f.metadata).refreshFragment(session,session.context.catalog(),f.schema(),"optimistic_structured",ObjectKind.TABLE);
        var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
        String table=session.adapter.table(session.context.catalog(),f.schema(),"optimistic_structured");
        var source=f.results.get(f.execute(session,"SELECT id,js,doc,fixed,n FROM "+table).info().getResults(0).getResultId());
        assertEquals("x    ",source.read(0).getValues(3).getText(),"Retained bpchar padding is part of its exact native output");
        var request=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("optimistic_structured")
            .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(5,Assignments.value(Value.newBuilder().setSignedInteger("2").build()))).build();
        var plan=planner.preview(session,request);assertTrue(plan.getSql(0).contains("pg_catalog.format('%s',"));
        var applied=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setPlanId(plan.getPlanId()).build(),f.jobs);EditingIT.await(applied);assertEquals(JobState.COMPLETED,applied.state,applied.info().toString());
        source=f.results.get(f.execute(session,"SELECT id,js,doc,fixed,n FROM "+table).info().getResults(0).getResultId());
        request=request.toBuilder().setResultId(source.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(5,Assignments.value(Value.newBuilder().setSignedInteger("3").build()))).build();plan=planner.preview(session,request);
        f.execute(external,"UPDATE optimistic_structured SET js=' { \"n\": 1, \"keep\": \"漢\" } ' WHERE id=1");
        var conflict=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setPlanId(plan.getPlanId()).build(),f.jobs);EditingIT.await(conflict);assertEquals(JobState.FAILED,conflict.state,conflict.info().toString());assertEquals("SQLSTATE_40001",conflict.info().getErrorCode());
        assertEquals("2",f.results.get(f.execute(session,"SELECT n FROM optimistic_structured").info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
    }
    private static void arrayCollationAndBounds(EngineFixture f,SessionRegistry.Session session,SessionRegistry.Session external)throws Exception {
        f.execute(session,"CREATE TABLE optimistic_arrays(id INTEGER PRIMARY KEY,a TEXT[] COLLATE optimistic_ci,n INTEGER); INSERT INTO optimistic_arrays VALUES(1,'[0:1]={Case漢😀,NULL}'::text[],1)");
        new Explorer(f.metadata).refreshFragment(session,session.context.catalog(),f.schema(),"optimistic_arrays",ObjectKind.TABLE);
        var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
        String table=session.adapter.table(session.context.catalog(),f.schema(),"optimistic_arrays");
        var source=f.results.get(f.execute(session,"SELECT id,a,n FROM "+table).info().getResults(0).getResultId());
        var request=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("optimistic_arrays")
            .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,Assignments.value(Value.newBuilder().setSignedInteger("2").build()))).build();
        EditingIT.apply(planner,f.jobs,session,request);
        source=f.results.get(f.execute(session,"SELECT id,a,n FROM "+table).info().getResults(0).getResultId());
        request=request.toBuilder().setResultId(source.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,Assignments.value(Value.newBuilder().setSignedInteger("3").build()))).build();var plan=planner.preview(session,request);
        f.execute(external,"UPDATE optimistic_arrays SET a[0]='case漢😀' WHERE id=1");
        var conflict=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setPlanId(plan.getPlanId()).build(),f.jobs);EditingIT.await(conflict);assertEquals(JobState.FAILED,conflict.state,conflict.info().toString());assertEquals("SQLSTATE_40001",conflict.info().getErrorCode());
        var durable=f.results.get(f.execute(session,"SELECT n,array_lower(a,1),a[0] FROM optimistic_arrays").info().getResults(0).getResultId()).read(0);
        assertEquals("2",durable.getValues(0).getSignedInteger());assertEquals("0",durable.getValues(1).getSignedInteger());assertEquals("case漢😀",durable.getValues(2).getText());
    }
}
