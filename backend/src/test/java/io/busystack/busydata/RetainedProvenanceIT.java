package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Native incarnation and query-source evidence cannot be acquired retroactively. */
class RetainedProvenanceIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void cachedProofProtectsUnknownOriginsReplacementAndViewBoundaries(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();f.introspectionLevel(session,io.busystack.busydata.metadata.IntrospectionLevel.NAMES);f.execute(session,"CREATE TABLE proof_rows(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO proof_rows VALUES(1,2)");
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            String unknown=f.execute(session,"SELECT id,n FROM proof_rows").info().getResults(0).getResultId();
            var request=ChangeRequest.newBuilder().setSessionId(session.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("proof_rows");
            f.introspectionLevel(session,io.busystack.busydata.metadata.IntrospectionLevel.STRUCTURE);f.warm(session,"proof_rows");
            assertFalse(planner.assess(session,request.setResultId(unknown).build()).getEditable(),"Later introspection cannot prove an earlier query's physical source");
            String known=f.execute(session,"SELECT id,n FROM "+session.adapter.table(session.context.catalog(),f.schema(),"proof_rows")).info().getResults(0).getResultId();
            assertTrue(planner.assess(session,request.setResultId(known).build()).getEditable());
            var change=request.build().toBuilder().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,Assignments.value(EditingIT.integer(9)))).build();
            var reviewed=planner.preview(session,change);
            var external=f.open();try(var statement=external.connection.createStatement()){
                statement.execute("DROP TABLE proof_rows");statement.execute("CREATE TABLE proof_rows(id INTEGER PRIMARY KEY,n INTEGER)");statement.execute("INSERT INTO proof_rows VALUES(1,2)");
            }
            assertFalse(planner.assess(session,request.build()).getEditable(),"Identical names, types and rows cannot substitute another physical table");
            assertThrows(RuntimeException.class,()->planner.preview(session,change));
            var failed=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(reviewed.getPlanId()).setExecutionId(java.util.UUID.randomUUID().toString()).build(),f.jobs);EditingIT.await(failed);assertEquals(JobState.FAILED,failed.state);
            EditingIT.assertRows(session,"SELECT id,n FROM proof_rows",new int[][]{{1,2}});
            f.execute(session,"CREATE VIEW proof_projection AS SELECT id,n FROM proof_rows WHERE n>0 WITH CHECK OPTION");
            f.warm(session,"proof_rows");new Explorer(f.metadata).refreshFragment(session,session.context.catalog(),f.schema(),"proof_projection",ObjectKind.VIEW);
            String view=f.execute(session,"SELECT id,n FROM proof_projection").info().getResults(0).getResultId();
            assertFalse(planner.assess(session,request.setResultId(view).build()).getEditable(),"A view's CHECK OPTION cannot be bypassed by writing its rewritten base table");
        }
    }
}
