package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.transfers.*;
import java.nio.file.*;
import java.util.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class TransferContractIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void csvAndTsvRoundTripNullLiteralMarkersAndExactValues(String engine)throws Exception {
        try(var f=new EngineFixture(root,engine)) {
            var s=f.open();f.execute(s,"CREATE TABLE transfer_values (id INTEGER PRIMARY KEY,v TEXT,n DECIMAL(30,9))");
            List<String> values=Arrays.asList(null,"","\\N","CUSTOM_NULL","quote\"comma,tab\tline\nnext","漢😀");
            try(var insert=s.connection.prepareStatement("INSERT INTO transfer_values VALUES(?,?,?)")) {
                for(int i=0;i<values.size();i++){insert.setInt(1,i);insert.setString(2,values.get(i));insert.setBigDecimal(3,new java.math.BigDecimal("12345678901234567890.123456789"));insert.executeUpdate();}
            }
            var selected=f.execute(s,"SELECT id,v,n FROM transfer_values ORDER BY id").info().getResults(0);
            var transfers=new Transfers(f.results);
            for(String format:List.of("csv","tsv"))for(String marker:List.of("\\N","CUSTOM_NULL")) {
                Path path=root.resolve(format+"-"+(marker.equals("\\N")?"default":"custom"));
                var export=ToolRequest.newBuilder().setKind(ToolKind.EXPORT_RESULT).setResultId(selected.getResultId()).setPath(path.toString()).setFormat(format).setNullMarker(marker).build();
                var exported=f.jobs.submitRetainedExport(f.results.get(selected.getResultId()),UUID.randomUUID().toString(),j->transfers.run(j,export));EditingIT.await(exported);assertEquals(JobState.COMPLETED,exported.state,exported.info().toString());
                var request=ToolRequest.newBuilder().setKind(ToolKind.IMPORT_CSV).setPath(path.toString()).setFormat(format).setNullMarker(marker).setSchema(f.schema()).setTable("transfer_values").addAllColumns(List.of("id","v","n")).build();
                var preview=ImportSources.preview(request);
                for(int i=0;i<values.size();i++)if(values.get(i)==null)assertTrue(preview.getRows(i).getValues(1).hasNullValue());else assertEquals(values.get(i),preview.getRows(i).getValues(1).getText());
                f.execute(s,"DELETE FROM transfer_values");
                var approved=request.toBuilder().setSourceSha256(preview.getSourceSha256()).build();
                var imported=f.jobs.submit(s,UUID.randomUUID().toString(),"",j->transfers.run(j,approved));EditingIT.await(imported);assertEquals(JobState.COMPLETED,imported.state,imported.info().toString());
                try(var statement=s.connection.createStatement();var rows=statement.executeQuery("SELECT id,v,n FROM transfer_values ORDER BY id")) {
                    for(int i=0;i<values.size();i++){assertTrue(rows.next());assertEquals(i,rows.getInt(1));assertEquals(values.get(i),rows.getString(2));assertEquals("12345678901234567890.123456789",rows.getBigDecimal(3).toPlainString());}assertFalse(rows.next());
                }
            }
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void directExportUsesExactContractAndQuotaFailurePreservesDestination(String engine)throws Exception{
        try(var f=new EngineFixture(root,engine)){
            var session=f.open();f.execute(session,"CREATE TABLE direct_values(id INTEGER PRIMARY KEY,v TEXT,n DECIMAL(30,9)); INSERT INTO direct_values VALUES(1,NULL,12345678901234567890.123456789),(2,'\\N',12345678901234567890.123456789)");
            var transfers=new Transfers(f.results);
            for(String format:List.of("csv","tsv","json","ndjson")){
                Path target=root.resolve("direct-"+format);
                var request=ToolRequest.newBuilder().setKind(ToolKind.EXPORT_QUERY).setPath(target.toString()).setFormat(format).setSql("SELECT id,v,n FROM direct_values ORDER BY id").build();
                var exported=f.jobs.submitSql(session,UUID.randomUUID().toString(),request.getSql(),job->transfers.run(job,request));EditingIT.await(exported);
                assertEquals(JobState.COMPLETED,exported.state,exported.info().toString());assertEquals(0,f.results.bytes());
                var preview=ImportSources.preview(request.toBuilder().setKind(Set.of("csv","tsv").contains(format)?ToolKind.IMPORT_CSV:ToolKind.IMPORT_JSON).build());
                assertTrue(preview.getRows(0).getValues(1).hasNullValue());assertEquals("12345678901234567890.123456789",preview.getRows(1).getValues(2).getText());
                String original=Files.readString(target);var quota=request.toBuilder().setOverwrite(true).setOutputLimitBytes(1).build();
                var failed=f.jobs.submitSql(session,UUID.randomUUID().toString(),request.getSql(),job->transfers.run(job,quota));EditingIT.await(failed);assertEquals(JobState.FAILED,failed.state);assertEquals(original,Files.readString(target));assertEquals(TransactionState.IDLE,session.state);
            }
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void importPoliciesDistinguishAtomicBatchesAndRejectedRows(String engine)throws Exception{
        try(var f=new EngineFixture(root,engine)){
            var s=f.open();f.execute(s,"CREATE TABLE policies(id INTEGER PRIMARY KEY,n INTEGER)");var transfers=new Transfers(f.results);
            Path source=root.resolve("policy.csv");Files.writeString(source,"id;n\n1;7\n2;8\n3;invalid\n4;9\n4;10\n5;11\n");
            var base=ToolRequest.newBuilder().setKind(ToolKind.IMPORT_CSV).setPath(source.toString()).setFormat("csv").setDelimiter(";").setSchema(f.schema()).setTable("policies").addAllColumns(List.of("id","n")).setBatchRows(2).build();
            for(var policy:List.of(ImportPolicy.ATOMIC_IMPORT,ImportPolicy.COMMIT_BATCHES,ImportPolicy.SKIP_INVALID_ROWS)){
                f.execute(s,"DELETE FROM policies");var request=base.toBuilder().setImportPolicy(policy).build();
                var imported=f.jobs.submit(s,UUID.randomUUID().toString(),"",j->transfers.run(j,request));EditingIT.await(imported);
                if(policy==ImportPolicy.ATOMIC_IMPORT){assertEquals(JobState.FAILED,imported.state);assertEquals(0,imported.committedRows);EditingIT.assertRows(s,"SELECT id,n FROM policies",new int[][]{});}
                else if(policy==ImportPolicy.COMMIT_BATCHES){assertEquals(JobState.FAILED,imported.state);assertEquals(2,imported.committedRows);EditingIT.assertRows(s,"SELECT id,n FROM policies ORDER BY id",new int[][]{{1,7},{2,8}});}
                else{assertEquals(JobState.COMPLETED,imported.state,imported.info().toString());assertEquals(2,imported.rejectedRows);assertEquals(4,imported.committedRows);EditingIT.assertRows(s,"SELECT id,n FROM policies ORDER BY id",new int[][]{{1,7},{2,8},{4,9},{5,11}});}
            }
        }
    }
}
