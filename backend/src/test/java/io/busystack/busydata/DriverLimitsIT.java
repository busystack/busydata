package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class DriverLimitsIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void driverRejectsOversizedRowsAndKeepsSupportedWideCursorResultsExact(String engine)throws Exception{
  try(var f=new EngineFixture(root,engine)){
   var s=f.open();String columns=String.join(",",java.util.stream.IntStream.range(0,64).mapToObj(i->"repeat('w',4000) AS c"+i).toList());
   String source=f.engine==Engine.POSTGRESQL?" FROM generate_series(1,200)": " FROM (WITH RECURSIVE n AS (SELECT 1 AS id UNION ALL SELECT id+1 FROM n WHERE id<200) SELECT id FROM n) AS fixture";
   var request=ExecuteRequest.newBuilder().setSessionId(s.id).setExecutionId(UUID.randomUUID().toString()).setSql("SELECT "+columns+source).setStreamingRead(true).setRowLimit(200).build();
   var wide=f.jobs.execute(s,request.toBuilder().setApprovalToken(f.safety.review(request,s).getToken()).build());
   wide.finished.get(60,TimeUnit.SECONDS);assertEquals(JobState.COMPLETED,wide.state,wide.info().toString());
   var result=f.results.get(wide.info().getResults(0).getResultId());assertEquals(200,result.rows());assertEquals("w".repeat(4000),result.read(199).getValues(63).getText());result.close();
   var oversized=f.submit(s,"SELECT repeat('x',9437184) AS too_large");oversized.finished.get(30,TimeUnit.SECONDS);
   // Each pinned driver aborts its protocol connection before accepting this
   // row. This is an interrupted read, distinct from a reusable SQL failure.
   assertEquals(JobState.INTERRUPTED,oversized.state,oversized.info().toString());assertTrue(oversized.info().getErrorCode().startsWith("SQLSTATE_"));assertFalse(oversized.info().getMessagesList().stream().anyMatch(m->m.contains("xxx")));
   assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state,"Protocol rejection quarantines the physical connection without replay");
   var fresh=f.open();var healthy=f.execute(fresh,"SELECT 7");assertEquals("7",f.results.get(healthy.info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
  }
 }
}
