package io.busystack.busydata;

import io.busystack.busydata.analysis.SqlParsing;
import io.busystack.busydata.analysis.SqlParsingTestAccess;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.schema.*;
import io.busystack.busydata.sessions.SessionRegistry;
import java.lang.reflect.*;
import java.math.BigDecimal;
import java.nio.file.*;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** A genuine queued JSQLParser deadline must remain a pre-mutation refusal,
 * distinguishable from metadata deadlines without retaining SQL or exceptions. */
class ChangePlanTimeoutOriginIT {
    @TempDir Path root;
    private static final String TABLE="high_set_timeout_origin";
    private static boolean dml(String sql){String upper=sql.stripLeading().toUpperCase(Locale.ROOT);return List.of("UPDATE ","INSERT ","DELETE ","REPLACE ").stream().anyMatch(upper::startsWith);}
    /** Native statements still run through the pinned driver; only actual DML
     * execute calls after preview are counted. Preparing is not execution. */
    private static Statement observedStatement(Statement statement,String preparedSql,AtomicBoolean observing,AtomicInteger executions){
        Class<?> type=statement instanceof PreparedStatement?PreparedStatement.class:Statement.class;
        return (Statement)Proxy.newProxyInstance(type.getClassLoader(),new Class[]{type},(proxy,method,args)->{
            if(observing.get()&&Set.of("execute","executeUpdate","executeLargeUpdate","executeBatch","executeLargeBatch").contains(method.getName())){
                String sql=preparedSql!=null?preparedSql:args!=null&&args.length>0&&args[0] instanceof String text?text:"";if(dml(sql))executions.incrementAndGet();
            }
            try{return method.invoke(statement,args);}catch(InvocationTargetException failure){throw failure.getCause();}
        });
    }
    private static Connection observed(Connection connection,AtomicBoolean observing,AtomicInteger executions){
        return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
            Object result;try{result=method.invoke(connection,args);}catch(InvocationTargetException failure){throw failure.getCause();}
            if(result instanceof Statement statement&&(method.getName().equals("createStatement")||method.getName().equals("prepareStatement")))return observedStatement(statement,method.getName().equals("prepareStatement")?(String)args[0]:null,observing,executions);
            return result;
        });
    }
    /** Observe the existing BusyData permit without consuming, replacing or
     * disclosing it. A failed source check precedes approval consumption. */
    private static boolean permitPresent(Safety safety,String plan)throws Exception {var field=Safety.class.getDeclaredField("permits");field.setAccessible(true);return ((Map<?,?>)field.get(safety)).containsKey(plan);}
    private static void nativeValues(SessionRegistry.Session session,String table)throws Exception {
        assertTrue(session.lock.tryLock());try(var statement=session.connection.createStatement()){
            statement.setQueryTimeout(5);try(var rows=statement.executeQuery("SELECT id,e,s,CAST(s AS UNSIGNED) FROM "+table+" ORDER BY id")){
                assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertEquals("ok",rows.getString(2));assertEquals("",rows.getString(3));assertEquals(0,BigDecimal.ZERO.compareTo(rows.getBigDecimal(4)));assertFalse(rows.next());
            }
        }finally{session.lock.unlock();}
    }
    @Test void sharedParserTimeoutReportsItsOriginWithoutExecutingTheReviewedHighSetChange()throws Exception {
        var observing=new AtomicBoolean();var executions=new AtomicInteger();
        try(var fixture=new EngineFixture(root,"MYSQL",(adapter,request,port)->observed(adapter.connect(request,port),observing,executions))){
            var session=fixture.open();String table=session.adapter.table(session.context.catalog(),fixture.schema(),TABLE);var members=new ArrayList<String>();for(int bit=0;bit<64;bit++)members.add("'m"+bit+"'");
            fixture.execute(session,"CREATE TABLE "+table+"(id INTEGER PRIMARY KEY,e ENUM('ok') NOT NULL,s SET("+String.join(",",members)+") NOT NULL); INSERT INTO "+table+" VALUES(1,1,0)");fixture.warm(session,TABLE);
            var source=fixture.execute(session,"SELECT id,e,s FROM "+table+" ORDER BY id");var retained=fixture.results.get(source.info().getResults(0).getResultId());var row=retained.read(0);var proof=retained.metadataProof();assertTrue(proof.capturedStructure());
            var change=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(retained.id).setCatalog(session.context.catalog()).setSchema(fixture.schema()).setTable(TABLE)
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,Assignments.value(Value.newBuilder().setText("m63").build()))).build();
            var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());var drafts=new EditDrafts(fixture.metadata,fixture.results,planner);
            var saved=drafts.run(fixture.sessions,EditDraftRequest.newBuilder().setAction(EditDraftAction.SAVE_EDIT_DRAFT).setSessionId(session.id).setDocumentId("source-timeout-draft").setChanges(change).build());String draftId=saved.getDrafts(0).getDraftId();var draft=fixture.metadata.editDraft(draftId);assertEquals("STAGED",draft.state());
            var reviewed=change.toBuilder().setRecoveryId(draftId).build();var plan=planner.preview(session,reviewed);assertEquals("m63",plan.getChanges(0).getValuesOrThrow("s").getValue().getText());assertTrue(permitPresent(fixture.safety,plan.getPlanId()));
            long revision=session.revision,contextRevision=session.contextRevision;var context=session.context;assertTrue(session.autoCommit);assertEquals(TransactionState.IDLE,session.state);assertEquals(TransactionState.IDLE,session.adapter.transaction(session.connection));
            int jobsBefore=fixture.jobs.list("").size();String execution=UUID.randomUUID().toString();Jobs.Job job;var evidence=new LinkedHashMap<String,Object>();
            observing.set(true);
            try(var gate=SqlParsingTestAccess.occupySharedCpu()){
                assertEquals(2,gate.occupiedWorkers());job=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(plan.getPlanId()).setExecutionId(execution).build(),fixture.jobs,fixture.metadata);
                var outcome=job.finished.get(10,TimeUnit.SECONDS);gate.held();assertEquals(JobState.FAILED,outcome.getState(),outcome.toString());assertEquals("timed_out",outcome.getErrorCode());assertEquals(WorkbenchFailure.Origin.SOURCE_PARSE,job.failureOrigin());
                assertEquals(execution,outcome.getExecutionId());assertEquals(0,outcome.getResultsCount());assertEquals(0,outcome.getCommittedRows());assertEquals(jobsBefore+1,fixture.jobs.list("").size(),"No execution may be retried automatically");assertEquals(0,executions.get(),"A source-parser refusal must precede every native DML execute call");assertTrue(permitPresent(fixture.safety,plan.getPlanId()),"Approval must not be consumed before source verification");
                assertSame(retained,fixture.results.get(retained.id));assertEquals(row,retained.read(0));assertSame(proof,retained.metadataProof());assertTrue(retained.complete);assertTrue(retained.fetchFinished);assertEquals(draft,fixture.metadata.editDraft(draftId));
                assertTrue(session.revision>revision,"Normal job cleanup still advances the physical execution revision");assertEquals(contextRevision,session.contextRevision);assertEquals(context,session.context);assertTrue(session.autoCommit);assertTrue(session.connection.getAutoCommit());assertEquals(TransactionState.IDLE,session.state);assertEquals(TransactionState.IDLE,session.adapter.transaction(session.connection));assertFalse(session.connection.isClosed());nativeValues(session,table);assertEquals(0,executions.get());
                evidence.put("engine","MYSQL");evidence.put("origin",job.failureOrigin().name());evidence.put("errorCode",outcome.getErrorCode());evidence.put("state",outcome.getState().name());evidence.put("durationMs",outcome.getDurationMs());evidence.put("sourceUtf16Units",retained.sourceSql.length());evidence.put("heldParserWorkers",gate.occupiedWorkers());evidence.put("nativeDmlExecutions",executions.get());evidence.put("jobCountDelta",fixture.jobs.list("").size()-jobsBefore);evidence.put("draftState",fixture.metadata.editDraft(draftId).state());evidence.put("reviewPermitRetained",permitPresent(fixture.safety,plan.getPlanId()));
            }finally{observing.set(false);}
            // Releasing only the two owned gate tasks must leave the production
            // parser usable. This checks syntax only; Apply is never repeated.
            assertInstanceOf(net.sf.jsqlparser.statement.select.PlainSelect.class,SqlParsing.parse("SELECT 1",Engine.MYSQL));nativeValues(session,table);assertEquals(draft,fixture.metadata.editDraft(draftId));assertEquals(jobsBefore+1,fixture.jobs.list("").size());
            evidence.put("parserRecovered",true);evidence.put("status","passed");Files.writeString(Files.createTempFile(Path.of("target"),"change-plan-timeout-origin-",".json"),new com.google.gson.GsonBuilder().setPrettyPrinting().create().toJson(evidence)+"\n");
        }
    }
}
