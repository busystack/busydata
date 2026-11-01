package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import java.nio.file.Path;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;
class ProceduralScriptIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void nativeProceduralBodiesKeepTheirStatementBoundaries(String engine)throws Exception{
  try(var fixture=new EngineFixture(root,engine)){
   var session=fixture.open();
   String sql=fixture.engine==Engine.POSTGRESQL?"CREATE FUNCTION busy_script(n integer) RETURNS integer LANGUAGE SQL BEGIN ATOMIC SELECT CASE WHEN n > 0 THEN n ELSE 0 END; END; SELECT busy_script(7);":"CREATE PROCEDURE busy_script(IN n INTEGER) BEGIN IF n > 0 THEN SELECT IF(n=7,7,0) AS n; ELSE SELECT 0 AS n; END IF; END; CALL busy_script(7);";
   var parts=fixture.analysis.split(sql,fixture.engine);assertEquals(2,parts.size());assertTrue(parts.getFirst().text().contains(";"));
   var job=fixture.execute(session,sql);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
   var result=job.info().getResultsList().stream().filter(r->!r.getResultId().isEmpty()).reduce((a,b)->b).orElseThrow();
   assertEquals(1,result.getStatementIndex());assertEquals(0,result.getColumnsCount(),"Job summaries omit column metadata; the independent retained catalog owns it");assertEquals(1,fixture.results.get(result.getResultId()).columns.size());
   var page=fixture.results.page(PageRequest.newBuilder().setResultId(result.getResultId()).setLimit(10).setMaxBytes(262144).build());
   var value=page.getRows(0).getValues(0);assertEquals("7",io.busystack.busydata.results.Values.text(value));
  }
 }
}
