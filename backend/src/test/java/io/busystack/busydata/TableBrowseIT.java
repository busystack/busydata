package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class TableBrowseIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void generatedBrowseBindsValuesAndUsesRealEditabilityWithoutMutation(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var explorer=new Explorer(f.metadata);
            String table=session.adapter.quote("Quoted table"),value=session.adapter.quote("Quoted value");
            f.execute(session,"CREATE TABLE "+table+" (id INTEGER PRIMARY KEY,"+value+" VARCHAR(100)); INSERT INTO "+table+" VALUES(1,'literal '' ; DROP TABLE unsafe'),(2,'second')");
            f.warm(session,"Quoted table");
            var snapshot=explorer.metadata().capture(session);var target=snapshot.resolve("busydata",f.schema(),ObjectKind.TABLE,"","Quoted table",true).getFirst();
            var request=BrowseRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setDocumentId("table-owner").setCatalog("busydata").setSchema(f.schema()).setTable("Quoted table").setMetadataObjectIdentity(target.identity().key()).setMetadataSnapshotRevision(snapshot.revision()).setRowLimit(1000)
                .addConditions(RowCondition.newBuilder().setColumn("Quoted value").setPredicate(ValuePredicate.EQUAL).setValue(Value.newBuilder().setText("literal ' ; DROP TABLE unsafe")))
                .addOrder(RowOrder.newBuilder().setColumn("id").setDescending(true)).build();
            var review=TableBrowse.review(session,request,explorer,f.safety);
            assertTrue(review.getStatements(0).contains("?"));assertFalse(review.getStatements(0).contains("DROP TABLE"));
            var job=TableBrowse.submit(session,request.toBuilder().setApprovalToken(review.getToken()).build(),explorer,f.safety,f.jobs);
            EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
            var result=f.results.get(job.info().getResults(0).getResultId());assertEquals(1,result.rows());assertEquals("1",result.read(0).getValues(0).getSignedInteger());
            var changes=ChangeRequest.newBuilder().setSessionId(session.id).setSchema(f.schema()).setTable("Quoted table").setResultId(result.id).build();
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());long assessmentStarted=System.nanoTime();var assessment=planner.assess(session,changes);
            long assessmentMillis=TimeUnit.NANOSECONDS.toMillis(System.nanoTime()-assessmentStarted);var retainedProof=result.metadataProof();
            assertTrue(assessment.getEditable(),assessment+" engine="+engine+" retainedState="+retainedProof.state()+" retainedAvailability="+retainedProof.availability()+" assessmentMillis="+assessmentMillis);assertEquals(2,assessment.getEditableColumnsCount());
            EditingIT.assertRows(session,"SELECT id FROM "+table+" ORDER BY id",new int[][]{{1},{2}});
            assertThrows(IllegalArgumentException.class,()->TableBrowse.prepare(session,request.toBuilder().setConditions(0,RowCondition.newBuilder().setColumn("id; DROP TABLE unsafe").setPredicate(ValuePredicate.IS_NULL)).build(),explorer));
            var pending=changes.toBuilder().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setText("changed").build()))).build();
            var plan=planner.preview(session,pending);
            f.execute(session,"BEGIN");
            var rejected=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs);
            EditingIT.await(rejected);assertEquals(JobState.FAILED,rejected.state);
            assertEquals(TransactionState.ACTIVE,session.state);
            f.execute(session,"ROLLBACK");
        }
    }
}
