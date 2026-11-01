package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.safety.Safety;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class EditRecoveryIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void recoveryRetainsVerifiedAliasIdentityAndRequiresFreshReviewWithoutReplayingSql(String engine)throws Exception{
  try(var f=new EngineFixture(root,engine)){
   var s=f.open();
   if(f.engine!=Engine.POSTGRESQL)f.execute(s,"SET SESSION sql_mode='ANSI_QUOTES,IGNORE_SPACE,PIPES_AS_CONCAT,HIGH_NOT_PRECEDENCE,NO_UNSIGNED_SUBTRACTION,REAL_AS_FLOAT,STRICT_TRANS_TABLES'");
   f.execute(s,"CREATE TABLE recovery_rows(id INTEGER PRIMARY KEY,n INTEGER NOT NULL)");f.execute(s,"INSERT INTO recovery_rows VALUES(1,2),(2,1)");
   f.warm(s,"recovery_rows");
   String table=s.adapter.table(s.context.catalog(),f.schema(),"recovery_rows");
   var query=f.execute(s,"SELECT n AS id,id AS n FROM "+table+" ORDER BY id");String result=query.info().getResults(0).getResultId();
   var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());var recovery=new EditDrafts(f.metadata,f.results,planner);
   var changes=ChangeRequest.newBuilder().setSessionId(s.id).setSchema(f.schema()).setTable("recovery_rows").setResultId(result)
      .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(1,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setSignedInteger("99").build()))).build();
   var saved=recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(s.id).setDocumentId("doc").setChanges(changes).build());String id=saved.getDrafts(0).getDraftId();
   var originalLexical=s.context.lexical();
   assertEquals(originalLexical.sqlMode(),f.metadata.editDraft(id).data().getSourceSqlMode(),"Recovery must retain the complete captured mode, including modes outside lexical quoting");
   if(f.engine!=Engine.POSTGRESQL){assertTrue(originalLexical.pipesAsConcat());assertTrue(originalLexical.highNotPrecedence());assertTrue(originalLexical.noUnsignedSubtraction());assertTrue(originalLexical.realAsFloat());assertTrue(originalLexical.sqlMode().contains("STRICT_TRANS_TABLES"));}
   int jobsBeforeRebind=f.jobs.list("").size();
   f.sessions.close(s.id,true);f.results.dispose(result);
   assertEquals("STAGED",recovery.run(f.sessions,EditDraftRequest.getDefaultInstance()).getDrafts(0).getState());
   var reopened=f.open();f.warm(reopened,"recovery_rows");var rebound=recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setDraftId(id).setSessionId(reopened.id).setDocumentId("new-document").build());
   // Rebinding retained data creates no execution job and no database write.
   assertEquals(jobsBeforeRebind,f.jobs.list("").size());
   assertEquals(originalLexical,f.results.get(rebound.getChanges().getResultId()).sourceLexical,"Rebound retained data keeps its original analysis and parsing modes");
   try(var st=reopened.connection.createStatement();var rows=st.executeQuery("SELECT n FROM recovery_rows WHERE id=2")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));}
   var plan=planner.preview(reopened,rebound.getChanges());var applied=planner.apply(reopened,ApplyRequest.newBuilder().setSessionId(reopened.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs,f.metadata);
   assertEquals(JobState.COMPLETED,applied.finished.get(30,TimeUnit.SECONDS).getState(),applied.info().toString());
   try(var st=reopened.connection.createStatement();var rows=st.executeQuery("SELECT id,n FROM recovery_rows ORDER BY id")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertEquals(2,rows.getInt(2));assertTrue(rows.next());assertEquals(2,rows.getInt(1));assertEquals(99,rows.getInt(2));}
   assertEquals("COMMITTED",f.metadata.editDraft(id).state());
   assertThrows(IllegalStateException.class,()->recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setDraftId(id).setSessionId(reopened.id).build()));
  }
 }
}
