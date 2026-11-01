package io.busystack.busydata;

import io.busystack.busydata.transfers.ImportSources;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class ImportTest {
    @TempDir Path root;
    private ToolRequest request(Path file, String format) { return ToolRequest.newBuilder().setKind(format.equals("csv")?ToolKind.IMPORT_CSV:ToolKind.IMPORT_JSON).setFormat(format).setPath(file.toString()).build(); }
    @Test void sourceHashCancellationStopsBeforeOpeningAndBetweenBoundedChunks()throws Exception {
        Path missing=root.resolve("not-opened.csv");
        assertThrows(java.util.concurrent.CancellationException.class,()->ImportSources.hash(missing,()->true));
        Path source=root.resolve("cancelled.csv");byte[] bytes=new byte[512*1024];new java.util.Random(42).nextBytes(bytes);Files.write(source,bytes);
        var checks=new java.util.concurrent.atomic.AtomicInteger();
        assertThrows(java.util.concurrent.CancellationException.class,()->ImportSources.hash(source,()->checks.incrementAndGet()>=4));
        assertEquals(4,checks.get());assertArrayEquals(bytes,Files.readAllBytes(source));
        String expected=java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(bytes));
        assertEquals(expected,ImportSources.hash(source,()->false));
    }
    @Test void cancelledEmptySourceCannotPublishDigestAndGrpcCancellationIsCaptured()throws Exception {
        Path source=root.resolve("empty.csv");Files.createFile(source);
        var checks=new java.util.concurrent.atomic.AtomicInteger();
        assertThrows(java.util.concurrent.CancellationException.class,()->ImportSources.hash(source,()->checks.incrementAndGet()>=3));
        try(var context=io.grpc.Context.current().withCancellation()) {
            context.cancel(null);
            context.run(()->assertThrows(java.util.concurrent.CancellationException.class,()->ImportSources.hash(source)));
        }
    }
    @Test void quotedNullMarkerIsLiteralAndUnquotedMarkerIsNull()throws Exception {
        Path file=root.resolve("null-contract.csv");Files.writeString(file,"v\n\\N\n\"\\N\"\n\"\"\n\"漢😀\"\n");
        var rows=ImportSources.preview(request(file,"csv")).getRowsList();
        assertTrue(rows.get(0).getValues(0).hasNullValue());
        assertEquals("\\N",rows.get(1).getValues(0).getText());
        assertEquals("",rows.get(2).getValues(0).getText());
        assertEquals("漢😀",rows.get(3).getValues(0).getText());
    }
    @Test void ambiguousNullContractsAreRejectedAndJsonUsesOnlyJsonNull()throws Exception {
        Path file=root.resolve("null.csv");Files.writeString(file,"v\nvalue\n");
        for(String marker:java.util.List.of("a,b","\"NULL\"","a\nb"," NULL","NULL "))
            assertThrows(IllegalArgumentException.class,()->ImportSources.preview(request(file,"csv").toBuilder().setNullMarker(marker).build()));
        Path json=root.resolve("null.json");Files.writeString(json,"[{\"v\":null},{\"v\":\"\\\\N\"},{\"v\":\"\\u0000\"}]");
        var rows=ImportSources.preview(request(json,"json")).getRowsList();
        assertTrue(rows.get(0).getValues(0).hasNullValue());assertEquals("\\N",rows.get(1).getValues(0).getText());assertEquals("\0",rows.get(2).getValues(0).getText());
    }
    @Test void previewPreservesMultilineCsvNullsAndExactTextWithoutMutation()throws Exception {
        Path file=root.resolve("source.csv");Files.writeString(file,"a,b,c\n\"漢😀\nsecond line\",\\N,12345678901234567890.123456789\n");
        var preview=ImportSources.preview(request(file,"csv"));assertEquals(1,preview.getRowsCount());assertEquals("漢😀\nsecond line",preview.getRows(0).getValues(0).getText());assertTrue(preview.getRows(0).getValues(1).hasNullValue());assertEquals("12345678901234567890.123456789",preview.getRows(0).getValues(2).getText());assertFalse(preview.getLimited());
    }
    @Test void previewRowsBytesAndParserAllocationsAreBounded()throws Exception {
        Path file=root.resolve("source.ndjson");Files.writeString(file,("{\"a\":\""+"x".repeat(5000)+"\"}\n").repeat(30));
        var preview=ImportSources.preview(request(file,"ndjson"));assertEquals(20,preview.getRowsCount());assertTrue(preview.getLimited());assertTrue(preview.getSerializedSize()<262144);assertTrue(preview.getRows(0).getValues(0).getTruncated());
        Files.writeString(file,"{\"a\":\""+"x".repeat(262145)+"\"}");assertThrows(java.io.IOException.class,()->ImportSources.preview(request(file,"ndjson")));
        Path csv=root.resolve("huge.csv");Files.writeString(csv,"a\n\""+"x\n".repeat(150000)+"\"\n");assertThrows(Exception.class,()->ImportSources.preview(request(csv,"csv")));
        Files.writeString(csv,"a,a\n1,2\n");assertThrows(IllegalArgumentException.class,()->ImportSources.preview(request(csv,"csv")));
    }
    @Test void approvedSourceIsImmutableAndQuotaAccounted()throws Exception {
        Path file=root.resolve("source.csv");Files.writeString(file,"a\noriginal\n");var request=request(file,"csv");var preview=ImportSources.preview(request);var approved=request.toBuilder().setSourceSha256(preview.getSourceSha256()).build();
        try(var store=new ResultStore(root,1024)) {
            try(var snapshot=ImportSources.snapshot(approved,store)) {
                Files.writeString(file,"a\nchanged\n");assertEquals("a\noriginal\n",Files.readString(snapshot.temporary().path));assertTrue(store.transferBytes()>0);assertEquals(0,store.bytes());
            }
            assertEquals(0,store.transferBytes());assertThrows(IllegalStateException.class,()->ImportSources.snapshot(approved,store));assertEquals(0,store.transferBytes());
        }
    }
    @Test void diskReserveFailureDoesNotAdoptOrChargeAnIncompleteSource()throws Exception {
        Path source=root.resolve("reviewed.csv");Files.writeString(source,"value\n\"漢😀\"\n");
        var approved=request(source,"csv").toBuilder().setSourceSha256(ImportSources.hash(source)).build();
        var space=new java.util.concurrent.atomic.AtomicLong(64L*1024*1024);
        try(var store=new ResultStore(root,1024,Files::deleteIfExists,Files::createFile,path->space.get())) {
            var failure=assertThrows(java.io.IOException.class,()->ImportSources.snapshot(approved,store));
            assertEquals("IMPORT_SNAPSHOT_DISK_RESERVE",failure.getMessage());assertEquals(0,store.transferBytes());
            try(var paths=Files.list(root.resolve("results"))){assertEquals(0,paths.count());}
            assertEquals("value\n\"漢😀\"\n",Files.readString(source));
            space.set(128L*1024*1024);
            try(var snapshot=ImportSources.snapshot(approved,store)){
                assertEquals(Files.size(source),store.transferBytes());assertEquals(approved.getSourceSha256(),ImportSources.hash(snapshot.temporary().path));
            }
            assertEquals(0,store.transferBytes());
        }
    }
}
