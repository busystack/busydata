package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.sessions.SessionRegistry;
import java.nio.file.Path;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real pinned engines; canonical labels are never inferred from display text.
 * Primary contracts: MySQL8.4 ENUM/SET numeric index/bit mask assignments and
 * MariaDB ENUM/SET type references. No JDBC mock substitutes for native storage. */
class EnumSetEditingIT {
    @TempDir Path root;
    private static final List<String> LABELS=List.of("quote'label","slash\\label","line\nlabel","Simple");
    private static String literal(String value){return "'"+value.replace("'","''")+"'";}
    private static String declaration(){return String.join(",",LABELS.stream().map(EnumSetEditingIT::literal).toList());}
    private static ChangeRequest request(EngineFixture f,SessionRegistry.Session session,String name,Map<Integer,ValueAssignment> values)throws Exception {
        String table=session.adapter.table(session.context.catalog(),f.schema(),name);
        var result=f.results.get(f.execute(session,"SELECT id,e,s FROM "+table+" ORDER BY id").info().getResults(0).getResultId());
        return ChangeRequest.newBuilder().setSessionId(session.id).setResultId(result.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable(name)
            .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putAllValues(values)).build();
    }
    private static ValueAssignment text(String value){return Assignments.value(Value.newBuilder().setText(value).build());}
    private static void verify(EngineFixture f,SessionRegistry.Session session,String name,String expectedEnum,String expectedSet)throws Exception {
        try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT e,s FROM "+session.adapter.table(session.context.catalog(),f.schema(),name)+" WHERE id=1")){
            assertTrue(rows.next());assertEquals(expectedEnum,rows.getString(1));assertEquals(expectedSet,rows.getString(2));
        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void canonicalLabelsRemainExactAcrossModesReviewApplyAndRecovery(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();f.execute(session,"SET SESSION sql_mode='ANSI_QUOTES,NO_BACKSLASH_ESCAPES'");
            f.execute(session,"CREATE TABLE enum_set_values(id INTEGER PRIMARY KEY,e ENUM("+declaration()+") CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,s SET("+declaration()+") CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL); INSERT INTO enum_set_values VALUES(1,1,0)");
            f.warm(session,"enum_set_values");var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            for(String label:LABELS){
                var change=request(f,session,"enum_set_values",Map.of(2,text(label)));
                var review=planner.preview(session,change);assertEquals(label,review.getChanges(0).getValuesOrThrow("e").getValue().getText());
                var draft=planner.captureDraft(session,change,"enum-label");assertEquals(label,draft.getChanges().getChanges(0).getValuesOrThrow(2).getValue().getText());
                EditingIT.apply(planner,f.jobs,session,change);verify(f,session,"enum_set_values",label,"");
            }
            String all=String.join(",",LABELS);
            for(String combination:List.of("",LABELS.getFirst(),LABELS.get(0)+","+LABELS.get(2),all)){
                var change=request(f,session,"enum_set_values",Map.of(3,text(combination)));
                assertEquals(combination,planner.preview(session,change).getChanges(0).getValuesOrThrow("s").getValue().getText());
                EditingIT.apply(planner,f.jobs,session,change);verify(f,session,"enum_set_values","Simple",combination);
            }
            for(String invalid:List.of(LABELS.get(1)+","+LABELS.get(0),LABELS.get(0)+","+LABELS.get(0),"unknown","simple","1")){
                var change=request(f,session,"enum_set_values",Map.of(3,text(invalid)));assertThrows(EditValues.Failure.class,()->planner.preview(session,change));
            }
            var wrongCase=request(f,session,"enum_set_values",Map.of(2,text("simple")));assertThrows(EditValues.Failure.class,()->planner.preview(session,wrongCase));
            var changes=request(f,session,"enum_set_values",Map.of(2,text(LABELS.getFirst()),3,text(LABELS.get(0)+","+LABELS.get(2))));
            var recovery=new EditDrafts(f.metadata,f.results,planner);
            var saved=recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(session.id).setDocumentId("enum-set-recovery").setChanges(changes).build());String id=saved.getDrafts(0).getDraftId();
            assertEquals(LABELS.getFirst(),f.metadata.editDraft(id).data().getChanges().getChanges(0).getValuesOrThrow(2).getValue().getText());
            f.sessions.close(session.id,true);f.results.dispose(changes.getResultId());var reopened=f.open();f.execute(reopened,"SET SESSION sql_mode=''");f.warm(reopened,"enum_set_values");
            int jobsBefore=f.jobs.list("").size();var rebound=recovery.run(f.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.REBIND_EDIT_DRAFT).setSessionId(reopened.id).setDocumentId("reopened-enum-set").setDraftId(id).build());assertEquals(jobsBefore,f.jobs.list("").size());
            verify(f,reopened,"enum_set_values","Simple",all);
            var review=planner.preview(reopened,rebound.getChanges());assertEquals(LABELS.getFirst(),review.getChanges(0).getValuesOrThrow("e").getValue().getText());
            var job=planner.apply(reopened,ApplyRequest.newBuilder().setSessionId(reopened.id).setPlanId(review.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs,f.metadata);EditingIT.await(job);assertEquals(JobState.COMPLETED,job.state,job.info().toString());
            verify(f,reopened,"enum_set_values",LABELS.getFirst(),LABELS.get(0)+","+LABELS.get(2));assertEquals("COMMITTED",f.metadata.editDraft(id).state());
            var bitMembers=new ArrayList<String>();for(int bit=0;bit<64;bit++)bitMembers.add(literal("m"+bit));
            f.execute(reopened,"CREATE TABLE high_set_members(id INTEGER PRIMARY KEY,e ENUM('ok') NOT NULL,s SET("+String.join(",",bitMembers)+") NOT NULL); INSERT INTO high_set_members VALUES(1,1,0)");f.warm(reopened,"high_set_members");
            for(var entry:Map.of("m63","9223372036854775808","m0,m63","9223372036854775809").entrySet()){
                var high=request(f,reopened,"high_set_members",Map.of(3,text(entry.getKey())));assertEquals(entry.getKey(),planner.preview(reopened,high).getChanges(0).getValuesOrThrow("s").getValue().getText());EditingIT.apply(planner,f.jobs,reopened,high);
                try(var statement=reopened.connection.createStatement();var rows=statement.executeQuery("SELECT s,CAST(s AS UNSIGNED) FROM "+reopened.adapter.table(reopened.context.catalog(),f.schema(),"high_set_members"))){assertTrue(rows.next());assertEquals(entry.getKey(),rows.getString(1));assertEquals(entry.getValue(),rows.getBigDecimal(2).toPlainString());}
            }

        }
    }
    @ParameterizedTest @ValueSource(strings={"MYSQL","MARIADB"})
    void collatedDistinctLabelsBindTheirExactOrdinalAndMaskAndAmbiguousEmptyLabelsAreUnavailable(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();f.execute(session,"SET SESSION sql_mode=''");
            f.execute(session,"CREATE TABLE collated_members(id INTEGER PRIMARY KEY,e ENUM('a','A') COLLATE utf8mb4_unicode_ci NOT NULL,s SET('a','A') COLLATE utf8mb4_unicode_ci NOT NULL); INSERT INTO collated_members VALUES(1,1,0)");
            f.warm(session,"collated_members");var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            var changes=request(f,session,"collated_members",Map.of(2,text("A"),3,text("a,A")));var review=planner.preview(session,changes);
            assertEquals("A",review.getChanges(0).getValuesOrThrow("e").getValue().getText());assertEquals("a,A",review.getChanges(0).getValuesOrThrow("s").getValue().getText());
            EditingIT.apply(planner,f.jobs,session,changes);verify(f,session,"collated_members","A","a,A");
            try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT e+0,CAST(s AS UNSIGNED) FROM "+session.adapter.table(session.context.catalog(),f.schema(),"collated_members"))){assertTrue(rows.next());assertEquals(2,rows.getInt(1));assertEquals(3,rows.getInt(2));}
            f.execute(session,"CREATE TABLE ambiguous_empty_members(id INTEGER PRIMARY KEY,e ENUM('','a'),s SET('a')); INSERT INTO ambiguous_empty_members VALUES(1,1,0)");f.warm(session,"ambiguous_empty_members");
            var empty=request(f,session,"ambiguous_empty_members",Map.of(2,text("a")));var unsupported=assertThrows(WorkbenchFailure.class,()->planner.preview(session,empty));assertEquals(WorkbenchFailure.Reason.UNSUPPORTED,unsupported.reason());
        }
    }
}
