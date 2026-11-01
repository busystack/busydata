package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class ResultLifecycleTest {
    @TempDir Path root;
    @Test void sqlProvenanceIsBoundedExactImmutableAndDisposedWithItsSource()throws Exception {
        String sql="SELECT '"+"漢😀".repeat(70000)+"';";
        try(var store=new ResultStore(root,8L*1024*1024)) {
            var result=store.create(List.of(Column.newBuilder().setName("v").build()));
            result.captureSql(sql);
            var value=result.retained().getSqlProvenance();
            assertTrue(value.getTruncated());assertTrue(value.getText().codePointCount(0,value.getText().length())<=1024);
            assertTrue(result.retained().getSerializedSize()<8192);
            assertEquals(sql,Files.readString(result.cell(value.getValueId())));
            assertEquals(sql.getBytes(java.nio.charset.StandardCharsets.UTF_8).length,value.getOriginalBytes());
            assertThrows(IllegalStateException.class,()->result.captureSql("different SQL"));
            var lease=result.lease();long bytes=store.bytes();result.close();assertEquals(bytes,store.bytes());
            lease.close();assertEquals(0,store.bytes());assertTrue(store.list(RetainedRequest.newBuilder().setLimit(32).build()).getResultsList().isEmpty());
        }
    }
    @Test void disposalWaitsForReadersAndBlocksNewOwnership()throws Exception {
        try(var store=new ResultStore(root,1024)) {
            var result=store.create(List.of(Column.newBuilder().setName("v").build()));result.append(Row.newBuilder().addValues(Value.newBuilder().setText("retained value")).build());result.fetchFinished=true;
            long charged=store.bytes();var lease=result.lease();result.close();result.close();
            assertEquals(charged,store.bytes());assertThrows(IllegalStateException.class,result::lease);
            var entry=store.list(RetainedRequest.newBuilder().setLimit(32).build()).getResults(0);
            assertTrue(entry.getDisposalPending());assertEquals(1,entry.getLeases());assertEquals("retained value",result.read(0).getValues(0).getText());
            lease.close();lease.close();assertEquals(0,store.bytes());assertTrue(store.list(RetainedRequest.newBuilder().setLimit(32).build()).getResultsList().isEmpty());
            assertEquals(0,Files.list(root.resolve("results")).count());
        }
    }
    @Test void cleanupFailureRemainsDiscoverableChargedAndRetryable()throws Exception {
        var denied=new AtomicBoolean(true);
        try(var store=new ResultStore(root,1024,path->{if(denied.get()&&path.toString().endsWith(".rows"))throw new java.nio.file.AccessDeniedException("injected");Files.deleteIfExists(path);})) {
            var result=store.create(List.of(Column.newBuilder().setName("v").build()));result.append(Row.newBuilder().addValues(Value.newBuilder().setText("payload")).build());result.fetchFinished=true;
            long bytes=store.bytes();assertThrows(java.io.IOException.class,result::close);assertEquals(bytes,store.bytes());
            var entry=store.list(RetainedRequest.newBuilder().setLimit(32).build()).getResults(0);assertTrue(entry.getAvailability().contains("cleanup failed"));
            denied.set(false);result.close();result.close();assertEquals(0,store.bytes());assertTrue(store.list(RetainedRequest.newBuilder().setLimit(32).build()).getComplete());
        }
    }
    @Test void failedSnapshotDisposalRemainsQuotaChargedAndHasRetryableOwnership()throws Exception {
        var denied=new AtomicBoolean(true);
        try(var store=new ResultStore(root,1024,path->{if(denied.get()&&path.toString().endsWith(".private"))throw new AccessDeniedException("injected");Files.deleteIfExists(path);})) {
            var temporary=store.temporary();try(var output=temporary.output()){output.write(new byte[128]);}
            assertEquals(128,store.transferBytes());assertThrows(java.io.IOException.class,temporary::close);
            store.retryTemporaryCleanup();assertEquals(128,store.transferBytes());assertTrue(Files.exists(temporary.path));
            denied.set(false);store.retryTemporaryCleanup();temporary.close();assertEquals(0,store.transferBytes());assertFalse(Files.exists(temporary.path));
        }
    }
    @Test void independentCatalogPagesKeepEveryResultReachableWithinByteLimits()throws Exception {
        try(var store=new ResultStore(root,1024)) {
            for(int i=0;i<64;i++){var result=store.create(List.of(Column.newBuilder().setName("x".repeat(120000)).build()));result.executionId="execution-"+i;result.fetchFinished=true;}
            assertThrows(IllegalStateException.class,()->store.create(List.of(Column.newBuilder().setName("v").build())));
            int offset=0;var found=new HashSet<String>();
            while(true){var page=store.list(RetainedRequest.newBuilder().setOffset(offset).setLimit(32).build());assertTrue(page.getSerializedSize()<=1_048_576);for(var entry:page.getResultsList())assertTrue(found.add(entry.getResult().getResultId()));if(page.getComplete())break;assertTrue(page.getNextOffset()>offset);offset=page.getNextOffset();}
            assertEquals(64,found.size());for(String id:found)store.get(id).close();assertEquals(0,store.bytes());
            var replacement=store.create(List.of(Column.newBuilder().setName("available").build()));replacement.close();
        }
    }
    @Test void partialCreationCleanupIsDiscoverableBoundedAndRetryable()throws Exception {
        var denied=new AtomicBoolean(true);var failCreate=new AtomicBoolean(true);
        try(var store=new ResultStore(root,1024,path->{if(denied.get()&&path.toString().endsWith(".rows"))throw new AccessDeniedException("injected cleanup");Files.deleteIfExists(path);},path->{if(failCreate.get()&&path.toString().endsWith(".index"))throw new java.io.IOException("injected second-file failure");Files.createFile(path);})){
            var failure=assertThrows(java.io.IOException.class,()->store.create(List.of(Column.newBuilder().setName("v").build())));assertEquals("injected second-file failure",failure.getMessage());assertEquals(1,failure.getSuppressed().length);
            var pending=store.list(RetainedRequest.newBuilder().setLimit(32).build()).getResults(0);assertTrue(pending.getDisposalPending());assertTrue(pending.getAvailability().contains("cleanup failed"));assertEquals(JobState.FAILED,pending.getState());assertEquals(0,store.bytes());assertEquals(1,Files.list(root.resolve("results")).count());
            for(int i=1;i<64;i++)assertThrows(java.io.IOException.class,()->store.create(List.of(Column.newBuilder().setName("v").build())));
            assertThrows(IllegalStateException.class,()->store.create(List.of(Column.newBuilder().setName("v").build())));
            denied.set(false);int offset=0;var ids=new ArrayList<String>();while(true){var page=store.list(RetainedRequest.newBuilder().setLimit(32).setOffset(offset).build());page.getResultsList().forEach(entry->ids.add(entry.getResult().getResultId()));if(page.getComplete())break;offset=page.getNextOffset();}for(String id:ids)store.dispose(id);
            assertEquals(0,Files.list(root.resolve("results")).count());failCreate.set(false);var available=store.create(List.of(Column.newBuilder().setName("v").build()));available.close();assertEquals(0,store.bytes());
        }
    }
    @Test void restartCleanupPreservesUnrelatedFilesAndDeletesOnlyOwnedRegularFiles()throws Exception {
        var directory=root.resolve("results");Files.createDirectories(directory);var unrelated=directory.resolve("user-notes.txt");Files.writeString(unrelated,"unrelated data");var stale=directory.resolve(UUID.randomUUID()+".rows");Files.writeString(stale,"stale private spool");
        try(var store=new ResultStore(root,1024)){assertEquals("unrelated data",Files.readString(unrelated));assertFalse(Files.exists(stale));}
    }

}
