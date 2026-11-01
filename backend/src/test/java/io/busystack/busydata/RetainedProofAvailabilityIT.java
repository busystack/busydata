package io.busystack.busydata;

import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.ChangePlanner;
import io.busystack.busydata.rpc.WorkbenchFailure;
import java.util.List;
import java.util.concurrent.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.concurrent.atomic.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class RetainedProofAvailabilityIT {
    @TempDir Path root;
    private static void assertReason(Editability assessment,WorkbenchFailure.Reason reason){assertFalse(assessment.getEditable());assertEquals(reason.wire(),assessment.getReasonCode());assertTrue(assessment.getReason().isEmpty(),"No raw exception or private proof text crosses assessment");assertEquals(0,assessment.getEditableColumnsCount());}
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void typedRetainedFailureRejectsBeforeReparseOrJdbcAndDoesNotDiscloseAnotherOwner(String engine)throws Exception {
        var armed=new AtomicBoolean();var jdbc=new AtomicInteger();var physical=new AtomicReference<Connection>();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var actual=adapter.connect(request,port);boolean owned=!request.getProfile().getReadOnly()&&physical.compareAndSet(null,actual);boolean policy=request.getProfile().getId().equals("readonly-assessment-owner");
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                if((owned||policy)&&armed.get()&&(method.getName().equals("createStatement")||method.getName().equals("prepareStatement"))){
                    jdbc.incrementAndGet();throw new AssertionError("Unavailable retained proof must reject before native JDBC acquisition");
                }
                try{return method.invoke(actual,args);}catch(InvocationTargetException failure){throw failure.getCause();}
            });
        })){
            var session=fixture.open();String generated=engine.equals("POSTGRESQL")?"INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY":"INTEGER AUTO_INCREMENT PRIMARY KEY";
            fixture.execute(session,"CREATE TABLE proof_availability(id "+generated+",n INTEGER); INSERT INTO proof_availability(n) VALUES(7)");fixture.warm(session,"proof_availability");
            var original=fixture.results.get(fixture.execute(session,"SELECT id,n FROM "+session.adapter.table("busydata",fixture.schema(),"proof_availability")).info().getResults(0).getResultId());
            var planner=new ChangePlanner(fixture.safety,fixture.results,fixture.metadata.metadataPlatform());
            var request=ChangeRequest.newBuilder().setSessionId(session.id).setCatalog("busydata").setSchema(fixture.schema()).setTable("proof_availability");int jobs=fixture.jobs.list("").size();
            var unchanged=planner.assess(session,request.setResultId(original.id).build());assertTrue(unchanged.getEditable(),unchanged.toString());
            var missingKey=fixture.results.get(fixture.execute(session,"SELECT n FROM "+session.adapter.table("busydata",fixture.schema(),"proof_availability")).info().getResults(0).getResultId());
            assertReason(planner.assess(session,request.setResultId(missingKey.id).build()),WorkbenchFailure.Reason.EDIT_IDENTITY_REQUIRED);
            // The real generated identity supplies the complete key, but no
            // writable column. Real execution also retains Maria's witness.
            var generatedSource=fixture.results.get(fixture.execute(session,"SELECT id FROM "+session.adapter.table("busydata",fixture.schema(),"proof_availability")).info().getResults(0).getResultId());
            assertReason(planner.assess(session,request.setResultId(generatedSource.id).build()),WorkbenchFailure.Reason.EDIT_COLUMNS_READ_ONLY);
            request.setResultId(original.id).setTable("proof_availability");
            var readOnly=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setId("readonly-assessment-owner").setReadOnly(true)).setPassword("fixture").build());
            jobs=fixture.jobs.list("").size();
            armed.set(true);
            try{
                // Fast session denials do not inspect or certify the requested result.
                assertReason(planner.assess(readOnly,request.clone().setSessionId(readOnly.id).build()),WorkbenchFailure.Reason.READ_ONLY_POLICY);
                session.state=TransactionState.UNKNOWN_TRANSACTION;
                try{assertReason(planner.assess(session,request.build()),WorkbenchFailure.Reason.TRANSACTION_UNKNOWN);}finally{session.state=TransactionState.IDLE;}
                var acquired=new CountDownLatch(1);var release=new CountDownLatch(1);var workerFailure=new AtomicReference<Throwable>();
                var holder=new Thread(()->{session.lock.lock();try{acquired.countDown();if(!release.await(5,TimeUnit.SECONDS))throw new AssertionError("Owned lock release deadline");}catch(Throwable failure){workerFailure.set(failure);}finally{session.lock.unlock();}},"assessment-lock-owner");
                holder.start();
                try{assertTrue(acquired.await(5,TimeUnit.SECONDS));assertReason(planner.assess(session,request.build()),WorkbenchFailure.Reason.SESSION_BUSY);}
                finally{release.countDown();holder.join(5000);assertFalse(holder.isAlive());}
                assertNull(workerFailure.get());
                var malformed=request.clone().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE)).build();
                assertEquals(WorkbenchFailure.Reason.MALFORMED_REQUEST,assertThrows(WorkbenchFailure.class,()->planner.assess(session,malformed)).reason());
                var pending=fixture.results.create(original.columns,session.targetProfile(),session.id,RetainedMetadataProof.unavailable(MetadataState.TIMED_OUT,"private diagnostic text"));
                assertReason(planner.assess(session,request.setResultId(pending.id).build()),WorkbenchFailure.Reason.EDIT_RESULT_NOT_READY);
                var badOrdinal=fixture.results.create(List.of(original.columns.getFirst().toBuilder().setOrdinal(9).build()),session.targetProfile(),session.id,RetainedMetadataProof.unavailable(MetadataState.DENIED,"private diagnostic text"));badOrdinal.fetchFinished=true;
                assertReason(planner.assess(session,request.setResultId(badOrdinal.id).build()),WorkbenchFailure.Reason.MALFORMED_REQUEST);
                var repeated=fixture.results.create(List.of(original.columns.getFirst(),original.columns.getFirst().toBuilder().setOrdinal(2).build()),session.targetProfile(),session.id,RetainedMetadataProof.unavailable(MetadataState.DENIED,"private diagnostic text"));repeated.fetchFinished=true;
                assertReason(planner.assess(session,request.setResultId(repeated.id).build()),WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
                var expression=fixture.results.create(List.of(original.columns.getFirst().toBuilder().clearBaseColumn().setProvenanceKnown(false).build()),session.targetProfile(),session.id,RetainedMetadataProof.unavailable(MetadataState.DENIED,"private diagnostic text"));expression.fetchFinished=true;
                assertReason(planner.assess(session,request.setResultId(expression.id).build()),WorkbenchFailure.Reason.EDIT_PROJECTION_UNSUPPORTED);
                assertReason(planner.assess(session,request.setResultId("unavailable-result").build()),WorkbenchFailure.Reason.RESULT_DISPOSED);
                Thread.currentThread().interrupt();
                try{assertReason(planner.assess(session,request.setResultId(original.id).build()),WorkbenchFailure.Reason.CANCELLED);assertTrue(Thread.currentThread().isInterrupted());}
                finally{Thread.interrupted();}
            }finally{armed.set(false);}

            for(var state:new MetadataState[]{MetadataState.TIMED_OUT,MetadataState.CANCELLED}){
                var retained=fixture.results.create(original.columns,session.targetProfile(),session.id,RetainedMetadataProof.unavailable(state,"An unrelated human description"));
                retained.append(original.read(0));retained.fetchFinished=true;retained.complete=true;
                // This deliberately unsupported syntax proves the earlier
                // typed failure wins without reaching a second parser attempt.
                retained.sourceSql="Not a SELECT";
                armed.set(true);
                try{
                    var assessment=planner.assess(session,request.setResultId(retained.id).build());
                    assertFalse(assessment.getEditable());assertEquals(state==MetadataState.TIMED_OUT?"timed_out":"cancelled",assessment.getReasonCode());assertTrue(assessment.getReason().isEmpty());
                    var wrongTable=planner.assess(session,request.setResultId(retained.id).setTable("another_table").build());
                    assertReason(wrongTable,WorkbenchFailure.Reason.MALFORMED_REQUEST);
                    request.setTable("proof_availability");
                    var foreign=fixture.results.create(original.columns,session.targetProfile(),"another-session",RetainedMetadataProof.unavailable(state,"Another unrelated description"));foreign.fetchFinished=true;foreign.complete=true;
                    var otherOwner=planner.assess(session,request.setResultId(foreign.id).build());
                    assertReason(otherOwner,WorkbenchFailure.Reason.INVALID_OWNER);
                }finally{armed.set(false);}
            }
            assertEquals(0,jdbc.get());assertEquals(jobs,fixture.jobs.list("").size(),"Assessment creates no generated SQL job and never replays the source query");
        }
    }
}
