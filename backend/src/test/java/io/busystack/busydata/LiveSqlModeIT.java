package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.*;
import io.busystack.busydata.analysis.language.SemanticDocument;
import io.busystack.busydata.metadata.*;
import java.nio.file.Path;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class LiveSqlModeIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void modeChangesWithinScriptsUseTheActualSessionAndIndependentAnalysisContext(String engine)throws Exception{
  try(var f=new EngineFixture(root,engine)){
   var s=f.open();long revision=s.contextRevision;
   String script=f.engine==Engine.POSTGRESQL?"SET standard_conforming_strings=off; SELECT 'a\\'b;c' AS text; SELECT 2 AS n":"SET sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'; SELECT 'a\\' AS text; SELECT 2 AS n";
   var job=f.execute(s,script);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
   var data=job.info().getResultsList().stream().filter(r->!r.getResultId().isEmpty()).toList();assertEquals(2,data.size());
   assertEquals(f.engine==Engine.POSTGRESQL?"a'b;c":"a\\",f.results.get(data.getFirst().getResultId()).read(0).getValues(0).getText());
   assertEquals("2",f.results.get(data.getLast().getResultId()).read(0).getValues(0).getSignedInteger());
   assertTrue(s.contextRevision>revision);assertEquals(TransactionState.IDLE,s.state);
   s.metadata(view->{assertEquals(s.context.lexical(),view.context.lexical());return null;});
   if(f.engine!=Engine.POSTGRESQL){
    f.execute(s,"CREATE TABLE mode_test(`Odd\\漢` INTEGER PRIMARY KEY); INSERT INTO mode_test VALUES (17)");
    var selected=f.execute(s,"SELECT \"Odd\\漢\" FROM mode_test");assertEquals("17",f.results.get(selected.info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
    assertTrue(s.info().getSqlMode().contains("ANSI_QUOTES"));
    f.warm(s,"mode_test");var snapshot=f.metadata.metadataPlatform().capture(s);
    var analysisContext=new io.busystack.busydata.analysis.language.ResolutionContext(s.context.catalog(),s.context.schema(),s.context.searchPath(),true,snapshot.revision(),snapshot.configurationRevision(),snapshot.rules(),snapshot,s.context.temporarySchema());
    String query="SELECT t.\"Odd\\漢\" FROM mode_test t";
    assertTrue(new SemanticDocument(query,f.engine,s.context.lexical()).complete(query.indexOf("漢")+1,analysisContext).stream().anyMatch(c->c.getLabel().equals("Odd\\漢")));
   }else{
    assertFalse(s.info().getStandardConformingStrings());
    f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.BEGIN).build());
    f.execute(s,"SET LOCAL standard_conforming_strings=on");assertTrue(s.info().getStandardConformingStrings());
    f.sessions.command(SessionRequest.newBuilder().setSessionId(s.id).setAction(SessionAction.ROLLBACK).build());
    assertFalse(s.info().getStandardConformingStrings());assertEquals(TransactionState.IDLE,s.state);
   }
  }
 }
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void reviewUsesLiveQuotingAndRejectsApprovalsAfterContextChanges(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();
   f.execute(s,f.engine==Engine.POSTGRESQL?"SET standard_conforming_strings=off":"SET sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'");
   String sql=f.engine==Engine.POSTGRESQL?"SELECT 'a\\'b;c' AS text; SELECT 2":"SELECT 'a\\' AS text; SELECT 2";
   var request=ExecuteRequest.newBuilder().setSessionId(s.id).setSql(sql).setExecutionId(java.util.UUID.randomUUID().toString()).build();
   var review=f.safety.review(request,s);assertEquals(2,review.getStatementsCount());
   f.execute(s,f.engine==Engine.POSTGRESQL?"SET standard_conforming_strings=on":"SET sql_mode=''");
   assertThrows(IllegalArgumentException.class,()->f.safety.authorize(request.toBuilder().setApprovalToken(review.getToken()).build(),s));
  }
 }

 @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
 void editableAliasedProjectionsKeepTheirOriginalQuotingContext(String engine)throws Exception {
  try(var f=new EngineFixture(root,engine)) {
   var s=f.open();f.execute(s,"CREATE TABLE quote_mode(id INTEGER PRIMARY KEY,n INTEGER);INSERT INTO quote_mode VALUES(1,2),(2,1);SET sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'");
   f.warm(s,"quote_mode");
   String table=s.adapter.table(s.context.catalog(),f.schema(),"quote_mode");
   String sourceSql="SELECT q.\"n\" AS \"id\",q.\"id\" AS \"n\" FROM "+table+" q ORDER BY q.\"id\"";
   var source=f.execute(s,sourceSql);
   var result=f.results.get(source.info().getResults(0).getResultId());var originalLexical=result.sourceLexical;var originalProof=result.metadataProof();
   assertTrue(originalLexical.ansiQuotes());assertTrue(originalLexical.noBackslashEscapes());assertTrue(originalProof.available());assertEquals(sourceSql,result.sourceSql);assertEquals(2,result.rows());
   var originalColumns=java.util.List.copyOf(result.columns);var originalFirst=result.read(0);var originalSecond=result.read(1);
   assertEquals(java.util.List.of("id","n"),originalColumns.stream().map(Column::getName).toList());assertEquals(java.util.List.of("n","id"),originalColumns.stream().map(Column::getBaseColumn).toList());
   assertEquals(java.util.List.of("2","1"),originalFirst.getValuesList().stream().map(Value::getSignedInteger).toList());assertEquals(java.util.List.of("1","2"),originalSecond.getValuesList().stream().map(Value::getSignedInteger).toList());
   long originalContext=s.contextRevision;
   f.execute(s,"SET sql_mode=''");
   assertEquals("",s.context.sqlMode());assertFalse(s.context.lexical().ansiQuotes());assertFalse(s.context.lexical().noBackslashEscapes());assertTrue(s.contextRevision>originalContext);
   // SET acknowledges a new live context and schedules independent metadata
   // reconciliation. Explicit current-context acquisition supersedes the older
   // queued intent; a finished SQL job is not a metadata-publication barrier.
   // This does not execute/replay the retained SELECT or rebind its proof.
   int beforeWarm=f.jobs.list(s.id).size();long liveRevision=s.revision,liveContext=s.contextRevision;var physical=s.connection;
   f.warm(s,"quote_mode");
   assertEquals(beforeWarm,f.jobs.list(s.id).size());assertEquals(liveRevision,s.revision);assertEquals(liveContext,s.contextRevision);assertSame(physical,s.connection);assertEquals("",s.context.sqlMode());
   assertSame(originalLexical,result.sourceLexical);assertSame(originalProof,result.metadataProof());assertEquals(sourceSql,result.sourceSql);assertEquals(originalColumns,result.columns);assertEquals(originalFirst,result.read(0));assertEquals(originalSecond,result.read(1));
   var current=f.metadata.metadataPlatform().capture(s);assertTrue(current.complete(new MetadataScope(s.context.catalog(),f.schema(),"quote_mode",ObjectKind.COLUMN),IntrospectionLevel.STRUCTURE));
   var currentProof=RetainedMetadataProof.capture(current,result.columns,s.targetProfile(),s.id,s.context);assertTrue(currentProof.available());assertTrue(originalProof.samePhysicalStructure(currentProof),"Live-context acquisition must not reinterpret the retained swapped aliases or source structure");
   var planner=new io.busystack.busydata.schema.ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
   var request=ChangeRequest.newBuilder().setSessionId(s.id).setResultId(result.id).setSchema(f.schema()).setTable("quote_mode").addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(1,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setSignedInteger("9").build()))).build();
   int beforeApply=f.jobs.list(s.id).size();var review=planner.preview(s,request);assertEquals(beforeApply,f.jobs.list(s.id).size());var job=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(review.getPlanId()).setExecutionId(java.util.UUID.randomUUID().toString()).build(),f.jobs);
   job.finished.get(30,java.util.concurrent.TimeUnit.SECONDS);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
   assertEquals(beforeApply+1,f.jobs.list(s.id).size(),"The original reviewed batch is applied once, without a replacement job or replay");assertSame(originalLexical,result.sourceLexical);assertEquals(sourceSql,result.sourceSql);assertEquals(originalColumns,result.columns);assertEquals(originalFirst,result.read(0));assertEquals(originalSecond,result.read(1));assertEquals("",s.context.sqlMode());
   EditingIT.assertRows(s,"SELECT id,n FROM quote_mode ORDER BY id",new int[][]{{1,9},{2,1}});
  }
 }

}
