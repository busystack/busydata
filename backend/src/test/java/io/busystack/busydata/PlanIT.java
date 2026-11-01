package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.Values;
import java.nio.file.Path;
import java.util.UUID;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;
class PlanIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void supportedPlansContainActualServerEstimatesAndMeasuredExecution(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();f.execute(s,"CREATE TABLE plan_data(id INTEGER PRIMARY KEY,n INTEGER);INSERT INTO plan_data VALUES(1,2),(2,4),(3,6)");
   for(var kind:new ToolKind[]{ToolKind.EXPLAIN,ToolKind.EXPLAIN_ANALYZE}) {
    String sql=s.adapter.toolSql(ToolRequest.newBuilder().setKind(kind).setSql("SELECT * FROM plan_data WHERE n>2").build());
    var job=f.jobs.submitSql(s,UUID.randomUUID().toString(),sql,operation->{operation.plan=true;try(var statement=s.adapter.rawStatement(s.connection,false,30,1000)){operation.statement=statement;try(var rows=statement.executeQuery(sql)){f.jobs.fetch(operation,rows,0,1000);}}});
    assertEquals(JobState.COMPLETED,job.finished.get(30,TimeUnit.SECONDS).getState(),job.info().toString());
    var result=f.results.get(job.info().getResults(0).getResultId());assertTrue(result.retained().getResult().getPlan());assertEquals(sql,Values.text(result.retained().getSqlProvenance()));assertEquals(f.schema(),result.retained().getSourceSchema());var raw=new StringBuilder();
    for(long i=0;i<result.rows();i++)raw.append(Values.text(result.read(i).getValues(0))).append('\n');
    assertTrue(raw.toString().contains("plan_data"),raw.toString());
    if(kind==ToolKind.EXPLAIN_ANALYZE)assertTrue(raw.toString().contains(f.engine==Engine.POSTGRESQL?"Actual Rows":f.engine==Engine.MYSQL?"actual time":"r_rows"),raw.toString());
    else assertFalse(raw.toString().contains("Actual Rows"));result.close();
   }
  }
 }
}
