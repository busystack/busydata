package io.busystack.busydata;

import io.busystack.busydata.analysis.*;
import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class DialectLexicalIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void nativeUnicodeIdentifiersAndDelimiterBoundariesSurviveFormatting(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();String table=session.adapter.table(session.context.catalog(),f.schema(),"lexical_boundaries");
            String special=session.adapter.quote("a\u2002b"),dollars=session.adapter.quote("foo$tag$"),leading=session.adapter.quote("\u2002x");
            f.execute(session,"CREATE TABLE "+table+"("+special+" INTEGER,"+dollars+" INTEGER,"+leading+" INTEGER); INSERT INTO "+table+" VALUES(2,3,6)");
            String sql="select a\u2002b,foo$tag$ from "+table;
            var original=f.results.get(f.execute(session,sql).info().getResults(0).getResultId()).read(0);
            assertEquals("2",original.getValues(0).getSignedInteger());assertEquals("3",original.getValues(1).getSignedInteger());
            var formatted=new SqlAnalysis().analyze(AnalysisRequest.newBuilder().setDocumentId("lexical-native").setEngine(f.engine).setOperation(AnalysisOperation.FORMAT).setSql(sql).setCaretUtf16(sql.length()).build());
            assertEquals("available",formatted.getAvailability());assertTrue(formatted.getFormattedSql().contains("a\u2002b"));assertTrue(formatted.getFormattedSql().contains("foo$tag$"));
            assertEquals(original,f.results.get(f.execute(session,formatted.getFormattedSql()).info().getResults(0).getResultId()).read(0));
            if(f.engine==Engine.POSTGRESQL){
                var value=f.results.get(f.execute(session,"SELECT $漢😀$one;two$漢😀$").info().getResults(0).getResultId()).read(0).getValues(0);assertEquals("one;two",value.getText());
                f.execute(session,"CREATE SEQUENCE execution_once; CREATE FUNCTION fail_after_nextval() RETURNS void LANGUAGE plpgsql AS $$ BEGIN PERFORM nextval('execution_once'); RAISE EXCEPTION USING ERRCODE='26000',MESSAGE='fixed test failure'; END $$");
                var failed=f.submit(session,"SELECT public.fail_after_nextval()");EditingIT.await(failed);assertEquals(JobState.FAILED,failed.state);
                assertEquals("1",f.results.get(f.execute(session,"SELECT last_value FROM public.execution_once").info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger(),"A driver reparse must never replay user SQL after a server error");
                f.execute(session,"CREATE TABLE public.space_columns(id INTEGER PRIMARY KEY,\" \" INTEGER); INSERT INTO public.space_columns VALUES(1,7)");f.warm(session,"space_columns");
                var spaceSource=f.results.get(f.execute(session,"SELECT id,\" \" FROM public.space_columns").info().getResults(0).getResultId());
                var planner=new io.busystack.busydata.schema.ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
                var change=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(spaceSource.id).setCatalog("busydata").setSchema("public").setTable("space_columns").addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setText("8").build()))).build();
                EditingIT.apply(planner,f.jobs,session,change);
                assertEquals("8",f.results.get(f.execute(session,"SELECT \" \" FROM public.space_columns").info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
            }else{
                var nativeComments=f.execute(session,"SELECT 2--\u2002x FROM "+table+"; SELECT 99");assertEquals(2,nativeComments.info().getResultsCount());
                assertEquals("8",f.results.get(nativeComments.info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
            }
        }
    }
}
