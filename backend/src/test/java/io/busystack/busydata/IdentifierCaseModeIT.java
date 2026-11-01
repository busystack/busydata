package io.busystack.busydata;

import io.busystack.busydata.analysis.language.ResolutionContext;
import io.busystack.busydata.metadata.IntrospectionLevel;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import java.util.UUID;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Native nondefault case rules must agree across exploration, analysis and edits. */
class IdentifierCaseModeIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void lowerCaseTableNamesOneKeepsOneIdentityAcrossAllMetadataConsumers(String engine)throws Exception {
        try(var fixture=new EngineFixture(root,engine,database->database.withCommand(
                "--lower_case_table_names=1","--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci"))){
            var session=fixture.open();fixture.introspectionLevel(session,IntrospectionLevel.STRUCTURE);
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT @@lower_case_table_names")){
                assertTrue(rows.next());assertEquals(1,rows.getInt(1),"The real server must use the requested initialization setting");
            }
            fixture.execute(session,"CREATE TABLE `CaSe_PaReNt` (`Id` INTEGER PRIMARY KEY); CREATE TABLE `CaSe_ChIlD` (`Id` INTEGER PRIMARY KEY, `ParentId` INTEGER, CONSTRAINT `CaSe_Fk` FOREIGN KEY (`ParentId`) REFERENCES `CaSe_PaReNt` (`Id`)); INSERT INTO `CaSe_PaReNt` VALUES(1); INSERT INTO `CaSe_ChIlD` VALUES(7,1)");
            fixture.execute(session,"CREATE FUNCTION `CaSe_FuN`(amount INTEGER) RETURNS INTEGER DETERMINISTIC RETURN amount");
            var explorer=new Explorer(fixture.metadata);explorer.refreshContext(session);var snapshot=explorer.metadata().capture(session);
            assertEquals(1,snapshot.rules().lowerCaseTableNames());
            var child=snapshot.resolve("busydata","busydata",ObjectKind.TABLE,"","CASE_CHILD",true).getFirst();
            assertEquals("case_child",child.identity().name());assertSame(child,snapshot.resolve("busydata","busydata",ObjectKind.TABLE,"","case_child",false).getFirst());
            var relationship=snapshot.outgoing("busydata","busydata","case_child").getFirst();assertTrue(snapshot.relationshipComplete(relationship));assertEquals(1,snapshot.incoming("busydata","busydata","case_parent").size());
            var captured=new ResolutionContext(session.context.catalog(),session.context.schema(),session.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot);
            String marked="SELECT c.PAR| FROM BUSYDATA.CASE_CHILD c";int caret=marked.indexOf('|');
            var completion=fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.COMPLETION).setSql(marked.replace("|","")).setCaretUtf16(caret).build(),session.context.lexical(),captured);
            assertTrue(completion.getCompletionsList().stream().anyMatch(item->item.getLabel().equals("ParentId")),completion.toString());
            String call="SELECT BUSYDATA.CASE_FU";
            var functions=fixture.analysis.analyze(AnalysisRequest.newBuilder().setEngine(fixture.engine).setOperation(AnalysisOperation.COMPLETION).setSql(call).setCaretUtf16(call.length()).build(),session.context.lexical(),captured);
            assertTrue(functions.getCompletionsList().stream().anyMatch(item->item.getKind().equals("function")&&item.getLabel().equalsIgnoreCase("case_fun()")),functions.toString());
            var query=fixture.execute(session,"SELECT c.ID,c.PARENTID FROM BUSYDATA.CASE_CHILD c");
            var retained=fixture.results.get(query.info().getResults(0).getResultId());assertTrue(retained.metadataProof().available());assertEquals(1,retained.rows());
            var browseSnapshot=explorer.metadata().capture(session);
            var browse=BrowseRequest.newBuilder().setSessionId(session.id).setExecutionId(UUID.randomUUID().toString()).setDocumentId("case-mode-browse").setCatalog("busydata").setSchema("busydata").setTable(child.identity().name()).setMetadataObjectIdentity(child.identity().key()).setMetadataSnapshotRevision(browseSnapshot.revision()).setRowLimit(1000).build();
            var review=TableBrowse.review(session,browse,explorer,fixture.safety);
            var job=TableBrowse.submit(session,browse.toBuilder().setApprovalToken(review.getToken()).build(),explorer,fixture.safety,fixture.jobs);EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
            var result=fixture.results.get(job.info().getResults(0).getResultId());
            var changes=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(result.id).setSchema("busydata").setTable(child.identity().name()).build();
            var planner=new ChangePlanner(fixture.safety,fixture.results,explorer.metadata());var assessment=planner.assess(session,changes);assertTrue(assessment.getEditable(),assessment.toString());
            var update=changes.toBuilder().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(1,Assignments.value(Value.newBuilder().setSignedInteger("8").build()))).build();
            var plan=planner.preview(session,update);var applied=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),fixture.jobs);EditingIT.await(applied);assertEquals(JobState.COMPLETED,applied.state,applied.info().toString());
            EditingIT.assertRows(session,"SELECT ID,PARENTID FROM BUSYDATA.CASE_CHILD",new int[][]{{8,1}});
        }
    }
}
