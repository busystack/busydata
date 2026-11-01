package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.transfers.Transfers;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class ResultLifecycleIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void evictionDisconnectAndDisposalDoNotLoseAnActiveExport(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var session=f.open();f.execute(session,"CREATE TABLE lifecycle(id INTEGER PRIMARY KEY,n INTEGER); INSERT INTO lifecycle VALUES(1,7)");
            var original=f.execute(session,"SELECT id,n FROM lifecycle");var id=original.info().getResults(0).getResultId();
            for(int i=0;i<130;i++)f.execute(session,"UPDATE lifecycle SET n=n WHERE id=1");
            assertThrows(IllegalArgumentException.class,()->f.jobs.get(original.id));
            var listing=f.results.list(RetainedRequest.newBuilder().setLimit(32).build());assertEquals(id,listing.getResults(0).getResult().getResultId());
            assertEquals("7",f.results.get(id).read(0).getValues(1).getSignedInteger());
            f.sessions.close(session.id,true);
            var entered=new CountDownLatch(1);var release=new CountDownLatch(1);var result=f.results.get(id);
            Path output=root.resolve("retained-after-disconnect.csv");var request=ToolRequest.newBuilder().setKind(ToolKind.EXPORT_RESULT).setResultId(id).setFormat("csv").setPath(output.toString()).build();
            var transfer=new Transfers(f.results);
            var exporting=f.jobs.submitRetainedExport(result,UUID.randomUUID().toString(),job->{entered.countDown();if(!release.await(5,TimeUnit.SECONDS))throw new AssertionError("Export gate timed out");transfer.run(job,request);});
            assertTrue(entered.await(5,TimeUnit.SECONDS));long charged=f.results.bytes();
            try{result.close();assertEquals(charged,f.results.bytes());assertTrue(f.results.list(RetainedRequest.newBuilder().setLimit(32).build()).getResults(0).getDisposalPending());}
            finally{release.countDown();}
            EditingIT.await(exporting);assertEquals(JobState.COMPLETED,exporting.state,exporting.info().toString());
            assertEquals("\"id\",\"n\"\n\"1\",\"7\"\n",Files.readString(output));
            assertEquals(0,f.results.bytes());assertTrue(f.results.list(RetainedRequest.newBuilder().setLimit(32).build()).getResultsList().isEmpty());
        }
    }
}
