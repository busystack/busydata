package io.busystack.busydata;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.administration.DiagnosticTools;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;
class DiagnosticsIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void reportsRealIndexEvidenceAndDistinguishesUnavailableQueryInstrumentation(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();f.execute(s,"CREATE TABLE diagnostics(id INTEGER PRIMARY KEY,n INTEGER);CREATE INDEX diagnostics_n ON diagnostics(n);INSERT INTO diagnostics VALUES(1,7);SELECT n FROM diagnostics WHERE n=7");
   var query=ToolRequest.newBuilder().setKind(ToolKind.QUERY_STATISTICS).build();
   if(f.engine==Engine.POSTGRESQL)assertTrue(assertThrows(UnsupportedOperationException.class,()->DiagnosticTools.sql(s,query)).getMessage().contains("not installed"));
   else {try(var st=s.connection.createStatement();var rows=st.executeQuery("SELECT @@performance_schema")){assertTrue(rows.next());boolean enabled=rows.getBoolean(1);if(!enabled){assertThrows(UnsupportedOperationException.class,()->DiagnosticTools.sql(s,query));return;}}
    var actual=f.execute(s,DiagnosticTools.sql(s,query));assertEquals(JobState.COMPLETED,actual.state,actual.info().toString());assertTrue(f.results.get(actual.info().getResults(0).getResultId()).columns.stream().anyMatch(c->c.getName().equalsIgnoreCase("total_seconds")));
   }
   var indexes=f.execute(s,DiagnosticTools.sql(s,ToolRequest.newBuilder().setKind(ToolKind.INDEX_DIAGNOSTICS).build()));assertEquals(JobState.COMPLETED,indexes.state,indexes.info().toString());
   var result=f.results.get(indexes.info().getResults(0).getResultId());boolean found=false;for(long i=0;i<result.rows();i++)for(var v:result.read(i).getValuesList())if(v.getText().equals("diagnostics_n"))found=true;assertTrue(found,"Actual indexed table must appear in server evidence");
  }
 }
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void enabledInstrumentationReturnsActualStatisticsAndIndexUsage(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine,c->{
   if(engine.equals("POSTGRESQL"))c.withCommand("postgres","-c","shared_preload_libraries=pg_stat_statements");
   else c.withCommand("--performance-schema=ON","--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci");
  })) {
   var s=f.open();
   if(f.engine==Engine.POSTGRESQL)f.execute(s,"CREATE SCHEMA \"Instrumentation 漢\"; CREATE EXTENSION pg_stat_statements WITH SCHEMA \"Instrumentation 漢\"");
   f.execute(s,"CREATE TABLE measured_statistics(id INTEGER PRIMARY KEY,n INTEGER); CREATE INDEX measured_statistics_n ON measured_statistics(n); INSERT INTO measured_statistics VALUES(1,123); SELECT n FROM measured_statistics WHERE n=123");
   var statistics=f.execute(s,DiagnosticTools.sql(s,ToolRequest.newBuilder().setKind(ToolKind.QUERY_STATISTICS).build()));
   assertEquals(JobState.COMPLETED,statistics.state,statistics.info().toString());
   var result=f.results.get(statistics.info().getResults(0).getResultId());boolean observed=false;
   for(long i=0;i<result.rows();i++)for(var value:result.read(i).getValuesList())if(value.getText().toLowerCase(java.util.Locale.ROOT).contains("measured_statistics"))observed=true;
   assertTrue(observed,"Server instrumentation must contain the workload, including a non-default PostgreSQL extension schema");
   var indexes=f.execute(s,DiagnosticTools.sql(s,ToolRequest.newBuilder().setKind(ToolKind.INDEX_DIAGNOSTICS).build()));
   assertEquals(JobState.COMPLETED,indexes.state,indexes.info().toString());
   result=f.results.get(indexes.info().getResults(0).getResultId());observed=false;
   for(long i=0;i<result.rows();i++)for(var value:result.read(i).getValuesList())if(value.getText().equals("measured_statistics_n"))observed=true;
   assertTrue(observed,"Enabled real-engine index evidence must include the created index");
  }
 }

}
