package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.transfers.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.TimeUnit;
import com.google.gson.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Successful >2GiB transfers, separate from the existing result-quota failure fixture. */
class LargeTransferIT {
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void directExportAndImmutableImportSucceedAboveTwoGiB(String engine)throws Exception{
        Path root=Files.createTempDirectory(Path.of("target").toAbsolutePath(),"large-transfer-");
        try{
            assertTrue(Files.getFileStore(root).getUsableSpace()>=16L*1024*1024*1024,
                "Large transfers require capacity for input, immutable snapshot and database on the same store");
            try(var f=new EngineFixture(root,engine,LargeTransferStorage.prepare(root,Engine.valueOf(engine)))){
                storageEvidence(root,f,"before");
                assertTrue(Files.getFileStore(root).getUsableSpace()>=16L*1024*1024*1024,
                    "Large transfers require room for input, immutable snapshot, database/index/log and temporary copies; capacity receipt retained");
                try {
                var s=f.sessions.open(OpenRequest.newBuilder().setProfile(f.profile.toBuilder().setQueryTimeoutSeconds(1200)).setPassword("fixture").build());
                String source;
                if(f.engine==Engine.POSTGRESQL)source="SELECT n AS id,repeat('x',65536) AS v FROM generate_series(1,32768) n";
                else{
                    f.execute(s,"CREATE TABLE numbers(n INTEGER PRIMARY KEY)");
                    f.execute(s,"INSERT INTO numbers VALUES "+String.join(",",java.util.stream.IntStream.range(0,32).mapToObj(i->"("+i+")").toList()));
                    source="SELECT a.n*1024+b.n*32+c.n+1 AS id,repeat('x',65536) AS v FROM numbers a CROSS JOIN numbers b CROSS JOIN numbers c";
                }
                var transfers=new Transfers(f.results);Path destination=root.resolve("large 漢.csv");
                var export=ToolRequest.newBuilder().setKind(ToolKind.EXPORT_QUERY).setSql(source).setFormat("csv").setPath(destination.toString()).build();
                long started=System.nanoTime();var exported=f.jobs.submitSql(s,UUID.randomUUID().toString(),source,j->transfers.run(j,export));
                var exportedInfo=exported.finished.get(20,TimeUnit.MINUTES);assertEquals(JobState.COMPLETED,exportedInfo.getState(),exportedInfo.toString());
                assertEquals(32768,exported.progress);assertTrue(Files.size(destination)>2L*1024*1024*1024);assertEquals(0,f.results.bytes());assertEquals(0,exportedInfo.getResultsCount(),"Direct export must not spool an interactive result");
                String checksum=ImportSources.hash(destination);
                var seen=new BitSet(32768);String expected="x".repeat(65536);
                try(var reader=Files.newBufferedReader(destination,StandardCharsets.UTF_8);var parser=CsvContract.input(export).parse(reader)){
                    for(var row:parser){int id=Integer.parseInt(row.get("id"));assertTrue(id>=1&&id<=32768);assertFalse(seen.get(id-1));seen.set(id-1);assertEquals(expected,row.get("v"));}
                }
                assertEquals(32768,seen.cardinality());long exportNanos=System.nanoTime()-started;
                f.execute(s,"CREATE TABLE imported(id INTEGER PRIMARY KEY,v "+(f.engine==Engine.POSTGRESQL?"TEXT":"MEDIUMTEXT")+")");
                var request=ToolRequest.newBuilder().setKind(ToolKind.IMPORT_CSV).setFormat("csv").setPath(destination.toString()).setSchema(f.schema()).setTable("imported").addAllColumns(List.of("id","v")).setSourceSha256(checksum).build();
                started=System.nanoTime();var imported=f.jobs.submit(s,UUID.randomUUID().toString(),"",j->transfers.run(j,request));
                var importedInfo=imported.finished.get(20,TimeUnit.MINUTES);assertEquals(JobState.COMPLETED,importedInfo.getState(),importedInfo.toString());
                assertEquals(32768,importedInfo.getCommittedRows());assertEquals(0,f.results.transferBytes());
                String md5=HexFormat.of().formatHex(MessageDigest.getInstance("MD5").digest(expected.getBytes(StandardCharsets.UTF_8)));
                try(var statement=s.connection.prepareStatement("SELECT COUNT(*),SUM(id),SUM(OCTET_LENGTH(v)),SUM(CASE WHEN MD5(v)=? THEN 1 ELSE 0 END) FROM imported")){
                    statement.setString(1,md5);try(var rows=statement.executeQuery()){
                        assertTrue(rows.next());assertEquals(32768,rows.getLong(1));assertEquals(32768L*32769/2,rows.getLong(2));assertEquals(2L*1024*1024*1024,rows.getLong(3));assertEquals(32768,rows.getLong(4));
                    }
                }
                var evidence=new JsonObject();evidence.addProperty("engine",engine);evidence.addProperty("serverVersion",s.info().getDatabase().getVersion());evidence.addProperty("java",System.getProperty("java.runtime.version"));evidence.addProperty("rows",32768);evidence.addProperty("cellBytes",65536);evidence.addProperty("outputBytes",Files.size(destination));evidence.addProperty("outputSha256",checksum);evidence.addProperty("exportAndVerificationMs",exportNanos/1_000_000);evidence.addProperty("importAndVerificationMs",(System.nanoTime()-started)/1_000_000);evidence.addProperty("resultSpoolBytes",f.results.bytes());evidence.addProperty("remainingImportSnapshotBytes",f.results.transferBytes());
                Files.writeString(Path.of("target/large-transfer-"+engine.toLowerCase(Locale.ROOT)+".json"),new GsonBuilder().setPrettyPrinting().create().toJson(evidence));
                storageEvidence(root,f,"after");
                } catch(Throwable failure) {
                    try {storageEvidence(root,f,"failure");} catch(Exception diagnosticFailure) {failure.addSuppressed(diagnosticFailure);}
                    throw failure;
                }
            }
        }finally{try(var paths=Files.walk(root)){for(var path:paths.sorted(Comparator.reverseOrder()).toList())Files.deleteIfExists(path);}}
    }
    private static void storageEvidence(Path root,EngineFixture fixture,String phase)throws Exception {
        var evidence=new JsonObject();var store=Files.getFileStore(root);
        evidence.addProperty("engine",fixture.engine.name());evidence.addProperty("phase",phase);
        evidence.addProperty("fixtureTemporaryDirectory",root.toString());
        evidence.addProperty("hostFileStore",store.name());evidence.addProperty("hostFileStoreType",store.type());
        evidence.addProperty("hostUsableBytes",store.getUsableSpace());
        evidence.addProperty("plannedInputBytes",2147483648L);evidence.addProperty("plannedImmutableCopyBytes",2147483648L);
        evidence.addProperty("minimumAvailableHostBytes",16L*1024*1024*1024);
        var info=fixture.database.getContainerInfo();
        evidence.addProperty("containerStorageDriver",info.getDriver());
        evidence.add("containerStorageOptions",new Gson().toJsonTree(info.getHostConfig().getStorageOpt()));
        var mounts=new JsonArray();
        if(info.getMounts()!=null)for(var mount:info.getMounts()){
            var item=new JsonObject();item.addProperty("source",mount.getSource());item.addProperty("destination",mount.getDestination().getPath());
            item.addProperty("readWrite",mount.getRW());mounts.add(item);
        }
        evidence.add("containerMounts",mounts);
        String data=fixture.engine==Engine.POSTGRESQL?"/var/lib/postgresql/data":"/var/lib/mysql";
        var free=fixture.database.execInContainer("df","-Pk",data,"/tmp","/");
        evidence.addProperty("containerDfExit",free.getExitCode());evidence.addProperty("containerDf",free.getStdout());
        if(phase.equals("failure")){
            // Retain only fixed capacity-related server diagnostics, never full logs/auth exchanges.
            var lines=fixture.database.getLogs().lines().filter(line->line.contains("No space left on device") || line.contains("Disk is full") || line.contains("Errcode: 28")).limit(20).toList();
            evidence.add("serverCapacityDiagnostics",new Gson().toJsonTree(lines));
        }
        Files.writeString(Path.of("target/large-transfer-storage-"+fixture.engine.name().toLowerCase(Locale.ROOT)+"-"+phase+".json"),new GsonBuilder().setPrettyPrinting().create().toJson(evidence));
    }
}
