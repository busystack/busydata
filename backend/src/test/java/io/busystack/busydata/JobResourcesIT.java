package io.busystack.busydata;

import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.transfers.Transfers;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Terminal summaries retain immutable identities, never physical resources. */
class JobResourcesIT {
    @TempDir Path root;

    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void terminalSummaryReleasesSessionsAndKeepsDisconnectedDataExportable(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();
            var success=f.execute(session,"SELECT 17 AS retained_value");
            assertDetached(success);
            var failed=f.submit(session,"SELECT nonexistent_busydata_column");
            failed.finished.get(10,TimeUnit.SECONDS);
            assertEquals(JobState.FAILED,failed.state);
            assertDetached(failed);
            session.lock.lock();
            try {
                var queued=f.jobs.submit(session,UUID.randomUUID().toString(),"SELECT 99",job->fail("Cancelled queued work must not run"));
                f.jobs.cancel(queued.id);
                assertEquals(JobState.CANCELLED,queued.finished.get(2,TimeUnit.SECONDS).getState());
                assertDetached(queued);
            }finally {session.lock.unlock();}
            f.sessions.close(session.id,true);
            assertEquals(0,f.sessions.size());
            var result=f.results.get(success.info().getResults(0).getResultId());
            assertEquals(session.id,result.sourceSessionId);
            assertEquals("17",result.read(0).getValues(0).getSignedInteger());
            Path output=root.resolve("disconnected-summary.csv");
            var request=ToolRequest.newBuilder().setKind(ToolKind.EXPORT_RESULT).setResultId(result.id).setPath(output.toString()).setFormat("csv").build();
            var transfer=new Transfers(f.results);
            var export=f.jobs.submitRetainedExport(result,UUID.randomUUID().toString(),job->transfer.run(job,request));
            assertEquals(JobState.COMPLETED,export.finished.get(10,TimeUnit.SECONDS).getState());
            assertDetached(export);
            assertEquals("\"retained_value\"\n\"17\"\n",Files.readString(output));
            result.close();assertEquals(0,f.results.bytes());
            assertEquals(JobState.COMPLETED,f.jobs.cancel(success.id).getState());
            assertEquals(JobState.COMPLETED,f.jobs.cancel(export.id).getState());
            var replacement=f.open();
            assertEquals("23",f.results.get(f.execute(replacement,"SELECT 23").info().getResults(0).getResultId()).read(0).getValues(0).getSignedInteger());
        }
    }

    @Test void mysqlClosedPacketBuffersAreNotRetainedByRepeatedJobSummaries()throws Exception {
        try(var f=new EngineFixture(root,"MYSQL")) {
            long actualClosedBufferBytes=0;
            var retainedIds=new ArrayList<String>();
            var completed=new ArrayList<Jobs.Job>();
            for(int i=0;i<6;i++) {
                var session=f.open();
                var driver=session.connection.unwrap(com.mysql.cj.jdbc.JdbcConnection.class);
                var job=f.execute(session,"SELECT repeat('r',524288) AS retained_value");
                retainedIds.add(job.info().getResults(0).getResultId());completed.add(job);
                f.sessions.close(session.id,true);
                assertTrue(driver.isClosed());
                // Public pinned-driver inspection measures the actual retained
                // packet allocation; no GC timing or invented heap estimate.
                int bytes=((com.mysql.cj.NativeSession)driver.getSession()).getProtocol().getReusablePacket().getByteBuffer().length;
                assertTrue(bytes>=524288,"Fixture must exercise a real wide-row driver allocation");
                actualClosedBufferBytes+=bytes;
            }
            assertTrue(actualClosedBufferBytes>=6L*524288);
            assertEquals(0,f.sessions.size());
            long retainedDriverBytes=0;
            for(var job:completed) {
                if(job.session!=null)retainedDriverBytes+=((com.mysql.cj.NativeSession)job.session.connection.unwrap(com.mysql.cj.jdbc.JdbcConnection.class).getSession()).getProtocol().getReusablePacket().getByteBuffer().length;
            }
            assertEquals(0,retainedDriverBytes,"Terminal summaries must not retain closed connections or their driver packet allocations");
            for(var job:completed)assertDetached(job);
            assertEquals(6,f.jobs.list("").size());
            assertEquals(6,f.results.list(RetainedRequest.newBuilder().setLimit(32).build()).getResultsCount());
            for(var id:retainedIds) {
                var result=f.results.get(id);var value=result.read(0).getValues(0);
                assertTrue(value.getTruncated());assertEquals(524288,value.getOriginalBytes());
                assertEquals("r".repeat(16384),value.getText());
                assertEquals(524288,Files.size(result.cell(value.getValueId())));
                result.close();
            }
            assertEquals(0,f.results.bytes());
        }
    }

    private static void assertDetached(Jobs.Job job) {
        assertTrue(Jobs.terminal(job.state));
        assertNull(job.session,"Terminal summary retains the source session identifier, not its physical connection");
        assertNull(job.statementSession,"A closed independent cancellation/metadata connection must also be released");
        assertNull(job.statement);assertNull(job.process);
        assertFalse(job.info().getSessionId().isBlank());
    }
}
