package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.*;
import java.nio.file.Path;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Native MariaDB table-share observers supplement dictionary incarnation evidence. */
class MariaMetadataWitnessIT {
    @TempDir Path root;
    @Test void instantReplacementCannotReuseAnApprovedRetainedRowAndObserversCloseWithResults()throws Exception {
        var counter=new OwnedJdbcOperationCounter();
        try(var f=new EngineFixture(root,"MARIADB",counter::connect)){
            var session=f.open();var other=f.open();
            f.execute(session,"CREATE TABLE witness_rows(id INTEGER PRIMARY KEY,n INTEGER DEFAULT 2); INSERT INTO witness_rows VALUES(1,2),(2,7)");
            f.warm(session,"witness_rows");String table=session.adapter.table(session.context.catalog(),f.schema(),"witness_rows");
            var retained=f.results.get(f.execute(session,"SELECT id,n FROM "+table+" ORDER BY id").info().getResults(0).getResultId());
            assertTrue(retained.metadataProof().available(),retained.metadataProof().toString());assertEquals(1,PreparedMetadataWitness.retainedForSession(session.id));
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());
            var request=ChangeRequest.newBuilder().setSessionId(session.id).setResultId(retained.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("witness_rows")
                .addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).setSourceRow(0).putValues(2,Assignments.value(EditingIT.integer(9)))).build();
            var reviewed=planner.preview(session,request);
            try(var statement=other.connection.createStatement()){statement.execute("ALTER TABLE witness_rows DROP COLUMN n, ADD COLUMN n INTEGER DEFAULT 2, ALGORITHM=INSTANT");}
            try(var statement=session.connection.createStatement()){statement.execute("FLUSH STATUS");}
            session.lock.lock();try{var failure=assertThrows(WorkbenchFailure.class,()->retained.verifyMetadataWitness(session,null));assertEquals(WorkbenchFailure.Reason.STALE,failure.reason());assertEquals(WorkbenchFailure.Origin.NATIVE_WITNESS,failure.origin());}finally{session.lock.unlock();}
            counter.begin();try{
                var apply=planner.apply(session,ApplyRequest.newBuilder().setSessionId(session.id).setPlanId(reviewed.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),f.jobs);EditingIT.await(apply);assertEquals(JobState.FAILED,apply.state);
                assertTrue(java.util.Set.of(WorkbenchFailure.Origin.NATIVE_WITNESS,WorkbenchFailure.Origin.RETAINED_PROOF).contains(apply.failureOrigin()));
            }finally{counter.end();}counter.noGeneratedDmlOrCommit();
            EditingIT.assertRows(session,"SELECT id,n FROM witness_rows ORDER BY id",new int[][]{{1,2},{2,2}});
            assertEquals("7",io.busystack.busydata.results.Values.text(retained.read(1).getValues(1)),"Retained values remain exact after invalidation");
            f.results.dispose(retained.id);assertEquals(0,PreparedMetadataWitness.retainedForSession(session.id));
            f.warm(session,"witness_rows");var fresh=f.results.get(f.execute(session,"SELECT id,n FROM "+table+" ORDER BY id").info().getResults(0).getResultId());
            assertTrue(fresh.metadataProof().available(),fresh.metadataProof().toString());assertTrue(planner.assess(session,request.toBuilder().setResultId(fresh.id).clearChanges().build()).getEditable(),"A new execution receives a newly prepared observer rather than an old cached packet");
            f.sessions.close(session.id,true);assertEquals(0,PreparedMetadataWitness.retainedForSession(session.id));assertEquals(2,fresh.read(0).getValuesCount());
        }
    }
    @Test void preparingAnObserverDoesNotStartAManualTransactionAndTemporaryRollbackDoesNotHideDurableProof()throws Exception {
        try(var f=new EngineFixture(root,"MARIADB")){
            var session=f.open();
            f.execute(session,"CREATE TEMPORARY TABLE witness_temporary(n INTEGER); INSERT INTO witness_temporary VALUES(7)");
            f.execute(session,"BEGIN; INSERT INTO witness_temporary VALUES(8)");f.execute(session,"ROLLBACK");
            f.execute(session,"CREATE TABLE after_temporary(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO after_temporary VALUES(1,2)");f.warm(session,"after_temporary");
            String sql="SELECT id,n FROM "+session.adapter.table(session.context.catalog(),f.schema(),"after_temporary");
            var retained=f.results.get(f.execute(session,sql).info().getResults(0).getResultId());assertTrue(retained.metadataProof().available(),retained.metadataProof().toString());
            var planner=new ChangePlanner(f.safety,f.results,f.metadata.metadataPlatform());assertTrue(planner.assess(session,ChangeRequest.newBuilder().setSessionId(session.id).setResultId(retained.id).setCatalog(session.context.catalog()).setSchema(f.schema()).setTable("after_temporary").build()).getEditable());
            session.lock.lock();try{
                session.connection.setAutoCommit(false);session.autoCommit=false;session.refresh();assertEquals(TransactionState.IDLE,session.state);
                try(var observer=PreparedMetadataWitness.capture(session,f.metadata.metadataPlatform().capture(session),sql,null)){
                    assertNotNull(observer);assertEquals(TransactionState.IDLE,session.adapter.transaction(session.connection),"Preparing native metadata must not execute the generated query");
                    var unavailable=assertThrows(WorkbenchFailure.class,()->observer.verify(session,null));assertEquals(WorkbenchFailure.Reason.INCOMPLETE_METADATA,unavailable.reason());assertEquals(TransactionState.IDLE,session.adapter.transaction(session.connection));
                }
                session.connection.setAutoCommit(true);session.autoCommit=true;session.refresh();
            }finally{session.lock.unlock();}
            f.results.dispose(retained.id);assertEquals(0,PreparedMetadataWitness.retainedForSession(session.id));
        }
    }
}
