package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class RetainedLobEditingIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void boundedFullOriginalsProtectOptimisticEditsAndSurviveRecoveryWithoutSourceReplay(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();var external=f.open();String textType=f.engine==Engine.POSTGRESQL?"TEXT":"LONGTEXT",binaryType=f.engine==Engine.POSTGRESQL?"BYTEA":"LONGBLOB";
            f.execute(session,"CREATE TABLE retained_lob_values(id INTEGER PRIMARY KEY,body "+textType+",doc JSON,bits "+binaryType+",n INTEGER)");
            String body="text漢😀".repeat(12000),json="{\"n\":12345678901234567890.000000001,\"text\":\""+"j".repeat(150000)+"\"}";byte[] binary=new byte[160000];new Random(37).nextBytes(binary);
            try(var insert=session.connection.prepareStatement("INSERT INTO retained_lob_values VALUES(?,?,?,?,?)")){insert.setInt(1,1);insert.setString(2,body);if(f.engine==Engine.POSTGRESQL)insert.setObject(3,json,Types.OTHER);else insert.setString(3,json);insert.setBytes(4,binary);insert.setInt(5,10);assertEquals(1,insert.executeUpdate());}
            f.warm(session,"retained_lob_values");String table=session.adapter.table(session.context.catalog(),f.schema(),"retained_lob_values");
            var source=f.results.get(f.execute(session,"SELECT id,body,doc,bits,n FROM "+table).info().getResults(0).getResultId());var stored=source.read(0);assertTrue(stored.getValues(1).getTruncated());assertTrue(stored.getValues(2).getTruncated());assertTrue(stored.getValues(3).getTruncated());
            String nativeJson;try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT doc FROM retained_lob_values")){assertTrue(rows.next());nativeJson=rows.getString(1);}
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());var base=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("retained_lob_values");
            var change=base.clone().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(5,Assignments.value(Value.newBuilder().setSignedInteger("11").build()))).build();var plan=planner.preview(session,change);
            var clone=planner.cloneRow(session,CloneRowRequest.newBuilder().setSessionId(session.id).setResultId(source.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("retained_lob_values").setSourceRow(0).build());
            assertFalse(clone.containsValues(1));assertEquals(body,Values.text(clone.getValuesOrThrow(2).getValue()));assertEquals(nativeJson,Values.text(clone.getValuesOrThrow(3).getValue()));assertArrayEquals(binary,clone.getValuesOrThrow(4).getValue().getBinary().toByteArray());assertFalse(clone.getValuesOrThrow(4).getValue().getTruncated());
            assertEquals(body,Values.text(plan.getChanges(0).getOriginalOrThrow("body")));assertEquals(nativeJson,Values.text(plan.getChanges(0).getOriginalOrThrow("doc")));assertArrayEquals(binary,plan.getChanges(0).getOriginalOrThrow("bits").getBinary().toByteArray());assertEquals(stored,source.read(0),"Review must not replace retained previews or source row identity");
            String changed=body.substring(0,body.length()-2)+"changed after preview";
            try(var update=external.connection.prepareStatement("UPDATE retained_lob_values SET body=? WHERE id=1")){update.setString(1,changed);assertEquals(1,update.executeUpdate());}
            var conflict=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs);EditingIT.await(conflict);assertEquals(JobState.FAILED,conflict.state);assertEquals("SQLSTATE_40001",conflict.info().getErrorCode());verify(session,changed,nativeJson,binary,10);
            try(var update=external.connection.prepareStatement("UPDATE retained_lob_values SET body=? WHERE id=1")){update.setString(1,body);assertEquals(1,update.executeUpdate());}
            var replacement=base.clone().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.value(Value.newBuilder().setText("new exact 漢😀").build()))).build();var recovery=new EditDrafts(f.metadata,f.results,planner);
            var saved=recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(session.id).setDocumentId("lob-source").setChanges(replacement).build());String draft=saved.getDrafts(0).getDraftId();
            var durable=f.metadata.editDraft(draft).data().getRows(0).getRow();assertEquals(body,Values.text(durable.getValues(1)));assertArrayEquals(binary,durable.getValues(3).getBinary().toByteArray());assertTrue(durable.getValuesList().stream().noneMatch(Value::getTruncated));
            f.sessions.close(session.id,true);f.results.dispose(source.id);var reopened=f.open();f.warm(reopened,"retained_lob_values");int jobs=f.jobs.list("").size();
            var rebound=recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setSessionId(reopened.id).setDocumentId("lob-rebound").setDraftId(draft).build());assertEquals(jobs,f.jobs.list("").size());
            var restored=f.results.get(rebound.getChanges().getResultId());assertTrue(restored.read(0).getSerializedSize()<262144);assertTrue(restored.read(0).getValues(3).getTruncated());assertNotEquals(stored.getValues(3).getValueId(),restored.read(0).getValues(3).getValueId());verify(reopened,body,nativeJson,binary,10);
            var reviewed=planner.preview(reopened,rebound.getChanges());var applied=planner.apply(reopened,ApplyRequest.newBuilder().setSessionId(reopened.id).setPlanId(reviewed.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs,f.metadata);EditingIT.await(applied);assertEquals(JobState.COMPLETED,applied.state,applied.info().toString());assertEquals("COMMITTED",f.metadata.editDraft(draft).state());verify(reopened,"new exact 漢😀",nativeJson,binary,10);
            var fresh=f.results.get(f.execute(reopened,"SELECT id,body,doc,bits,n FROM "+table).info().getResults(0).getResultId());
            var overBudget=base.clone().setSessionId(reopened.id).setResultId(fresh.id).addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(2,Assignments.value(Value.newBuilder().setText("漢".repeat(250000)).build()))).build();
            assertEquals(WorkbenchFailure.Reason.VALUE_TRUNCATED,assertThrows(WorkbenchFailure.class,()->planner.preview(reopened,overBudget)).reason());verify(reopened,"new exact 漢😀",nativeJson,binary,10);
        }
    }
    private static void verify(io.busystack.busydata.sessions.SessionRegistry.Session session,String body,String json,byte[] binary,int number)throws SQLException {
        try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT body,doc,bits,n FROM retained_lob_values WHERE id=1")){assertTrue(rows.next());assertEquals(body,rows.getString(1));assertEquals(json,rows.getString(2));assertArrayEquals(binary,rows.getBytes(3));assertEquals(number,rows.getInt(4));}
    }
}
