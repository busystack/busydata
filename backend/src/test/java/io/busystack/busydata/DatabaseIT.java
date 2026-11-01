package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.results.*;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.schema.*;
import java.nio.file.*;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.junit.jupiter.api.io.TempDir;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.DockerImageName;
import static org.junit.jupiter.api.Assertions.*;

class DatabaseIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void realSessionsTypedResultsTransactionsCancellationAndSafeEdits(String name)throws Exception {
  Engine engine=Engine.valueOf(name);int port=engine==Engine.POSTGRESQL?5432:3306;
  String image=switch(engine){case POSTGRESQL->"postgres:17.11";case MYSQL->"mysql:8.4.10";case MARIADB->"mariadb:11.8.9";default->throw new AssertionError();};
  try(var database=new GenericContainer<>(DockerImageName.parse(image)).withExposedPorts(port).withStartupTimeout(Duration.ofMinutes(3))) {
   if(engine==Engine.POSTGRESQL)database.withEnv("POSTGRES_PASSWORD","busydata-test").withEnv("POSTGRES_USER","busydata").withEnv("POSTGRES_DB","busydata").waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\n",2));
   else database.withEnv(engine==Engine.MYSQL?"MYSQL_ROOT_PASSWORD":"MARIADB_ROOT_PASSWORD","busydata-test").withEnv(engine==Engine.MYSQL?"MYSQL_DATABASE":"MARIADB_DATABASE","busydata").withCommand("--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci").waitingFor(Wait.forListeningPort());
   database.start();
   var profile=Profile.newBuilder().setId("profile").setName("Disposable fixture").setEngine(engine).setHost(database.getHost()).setPort(database.getMappedPort(port)).setDatabase("busydata").setUser(engine==Engine.POSTGRESQL?"busydata":"root").setTls(Tls.newBuilder().setMode(engine==Engine.MYSQL?TlsMode.INSECURE:TlsMode.DISABLED)).setConnectTimeoutSeconds(10).setQueryTimeoutSeconds(10).build();
   try(var sessions=new SessionRegistry();var metadata=new MetadataStore(root);var results=new ResultStore(root,64*1024*1024)) {
    var a=new SqlAnalysis();var safety=new Safety(a);try(var jobs=new Jobs(results,metadata,a,safety)) {
     SessionRegistry.Session s=null;Exception last=null;
     for(int i=0;i<30;i++){try{s=sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("busydata-test").build());break;}catch(Exception e){last=e;Thread.sleep(1000);}}
     if(s==null)throw last;
     run(jobs,safety,s,"CREATE TEMPORARY TABLE busydata_temp (n INTEGER); INSERT INTO busydata_temp VALUES(7)");
     var typed=run(jobs,safety,s,"SELECT n, CAST(12345678901234567890.123456789 AS DECIMAL(38,9)) AS exact_value, NULL AS nothing FROM busydata_temp");
     var page=results.get(typed.results().getFirst().getResultId()).page(PageRequest.newBuilder().setLimit(5).setMaxBytes(262144).build());
     assertEquals("7",Values.text(page.getRows(0).getValues(0)));assertEquals("12345678901234567890.123456789",page.getRows(0).getValues(1).getDecimal());assertTrue(page.getRows(0).getValues(2).hasNullValue());
     if(engine==Engine.POSTGRESQL){
       var exact=run(jobs,safety,s,"SELECT CAST('-9223372036854775808' AS bigint), decode('00ff','hex'), CAST('2001-02-03 04:05:06.123456' AS timestamp), CAST('2001-02-03 04:05:06+05:30' AS timestamptz), ARRAY[1.25::float8,NULL,2.5::float8], CAST('infinity' AS timestamptz)");
       var values=results.get(exact.results().getFirst().getResultId()).read(0).getValuesList();assertEquals("-9223372036854775808",values.get(0).getSignedInteger());assertArrayEquals(new byte[]{0,(byte)255},values.get(1).getBinary().toByteArray());assertEquals("2001-02-03T04:05:06.123456",values.get(2).getTemporal().getIso());assertEquals(java.time.OffsetDateTime.parse("2001-02-03T04:05:06+05:30").toInstant(),java.time.OffsetDateTime.parse(values.get(3).getTemporal().getIso()).toInstant());assertEquals(1.25,values.get(4).getArray().getValues(0).getReal());assertTrue(values.get(4).getArray().getValues(1).hasNullValue());assertEquals("infinity",values.get(5).getEngineValue().getText());
     }else{
       run(jobs,safety,s,"CREATE TEMPORARY TABLE busydata_types (u BIGINT UNSIGNED, bits BIT(8), binary_value VARBINARY(8), local_time DATETIME(6)); INSERT INTO busydata_types VALUES(18446744073709551615,b'10101010',X'00ff','2001-02-03 04:05:06.123456')");
       var exact=run(jobs,safety,s,"SELECT u,bits,binary_value,local_time FROM busydata_types");var values=results.get(exact.results().getFirst().getResultId()).read(0).getValuesList();assertEquals("18446744073709551615",values.get(0).getUnsignedInteger());assertArrayEquals(new byte[]{(byte)170},values.get(1).getBinary().toByteArray());assertArrayEquals(new byte[]{0,(byte)255},values.get(2).getBinary().toByteArray());assertEquals("2001-02-03T04:05:06.123456",values.get(3).getTemporal().getIso());
     }
     String copyColumns="id INTEGER PRIMARY KEY, t VARCHAR(1000), bytes_value "+(engine==Engine.POSTGRESQL?"BYTEA":"VARBINARY(8)")+", flag BOOLEAN, amount DECIMAL(38,9), local_time "+(engine==Engine.POSTGRESQL?"TIMESTAMP":"DATETIME(6)");
     run(jobs,safety,s,"CREATE TEMPORARY TABLE busydata_copy ("+copyColumns+"); CREATE TEMPORARY TABLE busydata_copy_target ("+copyColumns+")");
     try(var insert=s.connection.prepareStatement("INSERT INTO busydata_copy VALUES(?,?,?,?,?,?)")){insert.setInt(1,1);insert.setString(2,"漢😀\\backslash'quote\n");insert.setBytes(3,new byte[]{0,(byte)255});insert.setBoolean(4,true);insert.setBigDecimal(5,new java.math.BigDecimal("12345678901234567890.123456789"));insert.setObject(6,java.time.LocalDateTime.parse("2001-02-03T04:05:06.123456"));insert.executeUpdate();}
     var copySource=run(jobs,safety,s,"SELECT * FROM busydata_copy");var copyResult=results.get(copySource.results().getFirst().getResultId());String valuesSql=SqlCopy.range(copyResult,CopySqlRequest.newBuilder().setRowCount(1).setColumnCount(6).build());
     run(jobs,safety,s,"INSERT INTO busydata_copy_target VALUES "+valuesSql);
     var pasted=run(jobs,safety,s,"SELECT * FROM busydata_copy_target");assertEquals(copyResult.read(0),results.get(pasted.results().getFirst().getResultId()).read(0),"Copy as SQL must preserve actual exact values through the source engine");
     run(jobs,safety,s,"BEGIN; INSERT INTO busydata_temp VALUES(8)");assertEquals(TransactionState.ACTIVE,s.state);
     var streamingRequest=ExecuteRequest.newBuilder().setSessionId(s.id).setExecutionId(UUID.randomUUID().toString()).setSql("SELECT COUNT(*) FROM busydata_temp").setStreamingRead(true).setRowLimit(1000).build();var streamingReview=safety.review(streamingRequest,s);var manualRead=jobs.execute(s,streamingRequest.toBuilder().setApprovalToken(streamingReview.getToken()).build());await(manualRead);
     assertEquals(engine==Engine.POSTGRESQL?JobState.FAILED:JobState.COMPLETED,manualRead.state,manualRead.info().toString());assertEquals(TransactionState.ACTIVE,s.state,"A streaming request must not roll back or change an existing direct-SQL transaction");
     var uncommitted=run(jobs,safety,s,"SELECT COUNT(*) FROM busydata_temp");assertEquals("2",Values.text(results.get(uncommitted.results().getFirst().getResultId()).read(0).getValues(0)));
     run(jobs,safety,s,"ROLLBACK");var count=run(jobs,safety,s,"SELECT COUNT(*) FROM busydata_temp");assertEquals("1",Values.text(results.get(count.results().getFirst().getResultId()).read(0).getValues(0)));
     if(engine==Engine.POSTGRESQL){run(jobs,safety,s,"BEGIN");var failed=submit(jobs,safety,s,"SELECT * FROM no_such_table");await(failed);assertEquals(JobState.FAILED,failed.info().getState());assertEquals(TransactionState.FAILED_TRANSACTION,s.state);run(jobs,safety,s,"ROLLBACK");}
     var slow=submit(jobs,safety,s,engine==Engine.POSTGRESQL?"SELECT pg_sleep(10)":"SELECT SLEEP(10)");
     long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(5);while(slow.statement==null&&System.nanoTime()<deadline)Thread.sleep(10);
     long statusStart=System.nanoTime();assertFalse(sessions.command(SessionRequest.newBuilder().setSessionId(s.id).build()).getDatabase().getProduct().isBlank());assertTrue(System.nanoTime()-statusStart<TimeUnit.MILLISECONDS.toNanos(500),"Status must not wait for executing JDBC or the session lock");
     long start=System.nanoTime();jobs.cancel(slow.id);await(slow);assertEquals(JobState.CANCELLED,slow.info().getState());assertTrue(System.nanoTime()-start<TimeUnit.SECONDS.toNanos(5));
     assertEquals(TransactionState.IDLE,s.state,slow.info().toString());
     for(int race=0;race<5;race++){var racing=submit(jobs,safety,s,engine==Engine.POSTGRESQL?"SELECT pg_sleep(0.02)":"SELECT SLEEP(0.02)");if(race%2==1)Thread.sleep(30);jobs.cancel(racing.id);await(racing);assertTrue(Set.of(JobState.CANCELLED,JobState.COMPLETED).contains(racing.state),racing.info().toString());assertEquals(TransactionState.IDLE,s.state,racing.info().toString());}
     var unique=ExecuteRequest.newBuilder().setExecutionId(UUID.randomUUID().toString()).setSql("SELECT 1").build();var once=jobs.execute(s,unique);await(once);var owner=s;assertThrows(IllegalArgumentException.class,()->jobs.execute(owner,unique));
     run(jobs,safety,s,"CREATE TABLE busydata_edit (a INTEGER, b INTEGER, v VARCHAR(100), PRIMARY KEY(a,b)); INSERT INTO busydata_edit VALUES(1,2,'original')");
     EngineFixture.warm(metadata,s,"busydata_edit");
     String editTable=s.adapter.table(s.context.catalog(),engine==Engine.POSTGRESQL?"public":s.context.catalog(),"busydata_edit");
     var source=run(jobs,safety,s,"SELECT a,b,v FROM "+editTable);
     assertTrue(results.get(source.results().getFirst().getResultId()).metadataProof().available(),results.get(source.results().getFirst().getResultId()).metadataProof().toString());
     var request=ChangeRequest.newBuilder().setSessionId(s.id).setResultId(source.results().getFirst().getResultId()).setTable("busydata_edit").setSchema(engine==Engine.POSTGRESQL?"public":"busydata").addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setText("updated").build()))).build();
     var planner=new ChangePlanner(safety,results,metadata.metadataPlatform());var editOwner=s;
     assertEquals(io.busystack.busydata.rpc.WorkbenchFailure.Reason.MALFORMED_REQUEST,assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->planner.preview(editOwner,request.toBuilder().setChanges(0,request.getChanges(0).toBuilder().putValues(99,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setText("forged").build()))).build())).reason());
     var joined=run(jobs,safety,s,"SELECT l.a,l.b,l.v FROM "+editTable+" l JOIN "+editTable+" r ON l.a=r.a");
     assertEquals(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->planner.preview(editOwner,request.toBuilder().setResultId(joined.results().getFirst().getResultId()).build())).reason(),"Joined retained sources are rejected through the structured workbench error contract");
     var plan=planner.preview(s,request);assertEquals("updated",plan.getChanges(0).getValuesOrThrow("v").getValue().getText());assertEquals("original",plan.getChanges(0).getOriginalOrThrow("v").getText());var edit=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(plan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(edit);assertEquals(JobState.COMPLETED,edit.info().getState());
     var changed=run(jobs,safety,s,"SELECT v FROM busydata_edit WHERE a=1 AND b=2");assertEquals("updated",Values.text(results.get(changed.results().getFirst().getResultId()).read(0).getValues(0)));
     var stalePlan=planner.preview(s,request);var conflict=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(stalePlan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(conflict);assertEquals(JobState.FAILED,conflict.state,"A retained original row must not overwrite a concurrent change");
     String identity=engine==Engine.POSTGRESQL?"INTEGER GENERATED ALWAYS AS IDENTITY":"INTEGER AUTO_INCREMENT";
     run(jobs,safety,s,"CREATE TABLE busydata_defaults (id "+identity+" PRIMARY KEY, n INTEGER NOT NULL DEFAULT 7, twice INTEGER GENERATED ALWAYS AS (n*2) STORED)");
     EngineFixture.warm(metadata,s,"busydata_defaults");
     String defaultsTable=s.adapter.table(s.context.catalog(),engine==Engine.POSTGRESQL?"public":s.context.catalog(),"busydata_defaults");
     var emptySource=run(jobs,safety,s,"SELECT id,n,twice FROM "+defaultsTable);
     var insertRequest=ChangeRequest.newBuilder().setSessionId(s.id).setResultId(emptySource.results().getFirst().getResultId()).setTable("busydata_defaults").setSchema(engine==Engine.POSTGRESQL?"public":"busydata").addChanges(StagedChange.newBuilder().setKind(ChangeKind.INSERT)).build();
     var insertPlan=planner.preview(s,insertRequest);var inserted=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(insertPlan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(inserted);assertEquals(JobState.COMPLETED,inserted.state,inserted.info().toString());
     var generatedSource=run(jobs,safety,s,"SELECT id,n,twice FROM "+defaultsTable);var generatedResult=results.get(generatedSource.results().getFirst().getResultId());var generatedRow=generatedResult.read(0);assertEquals("7",Values.text(generatedRow.getValues(1)));assertEquals("14",Values.text(generatedRow.getValues(2)));
     var originals=new HashMap<String,Value>();for(int i=0;i<generatedResult.columns.size();i++)originals.put(generatedResult.columns.get(i).getName(),generatedRow.getValues(i));
     var generatedRequest=insertRequest.toBuilder().setResultId(generatedResult.id).clearChanges().addChanges(StagedChange.newBuilder().setKind(ChangeKind.UPDATE).putValues(3,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setSignedInteger("99").build()))).build();
     assertThrows(IllegalArgumentException.class,()->planner.preview(editOwner,generatedRequest));
     var validUpdate=generatedRequest.toBuilder().setChanges(0,generatedRequest.getChanges(0).toBuilder().clearValues().putValues(2,io.busystack.busydata.schema.Assignments.value(Value.newBuilder().setSignedInteger("8").build()))).build();
     var updatePlan=planner.preview(s,validUpdate);var updated=planner.apply(s,ApplyRequest.newBuilder().setSessionId(s.id).setPlanId(updatePlan.getPlanId()).setExecutionId(UUID.randomUUID().toString()).build(),jobs);await(updated);assertEquals(JobState.COMPLETED,updated.state,updated.info().toString());
     var derived=run(jobs,safety,s,"SELECT twice FROM busydata_defaults");assertEquals("16",Values.text(results.get(derived.results().getFirst().getResultId()).read(0).getValues(0)));
     var metadataResult=new Explorer(metadata).explore(s,ExploreRequest.newBuilder().setKind(ObjectKind.COLUMN).setSchema(engine==Engine.POSTGRESQL?"public":"busydata").setTable("busydata_edit").build());assertEquals(3,metadataResult.getObjectsCount());
     var tools=new SchemaTools(metadata.metadataPlatform());String schema=engine==Engine.POSTGRESQL?"public":"busydata";
     var before=tools.run(s,SchemaToolRequest.newBuilder().setSchema(schema).build()).getSnapshot();
     run(jobs,safety,s,"ALTER TABLE busydata_edit ADD COLUMN added_text TEXT");
     var intended=tools.run(s,SchemaToolRequest.newBuilder().setSchema(schema).build()).getSnapshot();
     run(jobs,safety,s,"ALTER TABLE busydata_edit DROP COLUMN added_text");
     var diff=tools.run(s,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSourceSnapshot(before).setTargetSnapshot(intended).build());
     assertTrue(diff.getUnsupportedList().isEmpty(),diff.toString());assertEquals(1,diff.getSqlCount());
     run(jobs,safety,s,String.join("\n",diff.getSqlList()));
     assertEquals(com.google.gson.JsonParser.parseString(intended),com.google.gson.JsonParser.parseString(tools.run(s,SchemaToolRequest.newBuilder().setSchema(schema).build()).getSnapshot()));
     String large="漢😀\"z\n".repeat(5000);try(var st=s.connection.prepareStatement("UPDATE busydata_edit SET added_text=?")){st.setString(1,large);st.executeUpdate();}
     var largeJob=run(jobs,safety,s,"SELECT added_text FROM busydata_edit");var retained=results.get(largeJob.results().getFirst().getResultId());var cell=retained.read(0).getValues(0);
     assertTrue(cell.getTruncated());assertFalse(cell.getValueId().isEmpty());assertEquals(large,Files.readString(retained.cell(cell.getValueId())));
     assertTrue(retained.value(ValueRequest.newBuilder().setValueId(cell.getValueId()).setMaxBytes(65536).build()).getData().size()<=65536);
     var transfers=new io.busystack.busydata.transfers.Transfers(results);
     for(String format:List.of("csv","json")){Path output=root.resolve("export."+format);var export=jobs.submit(s,UUID.randomUUID().toString(),"",j->transfers.run(j,ToolRequest.newBuilder().setKind(ToolKind.EXPORT_RESULT).setResultId(retained.id).setPath(output.toString()).setFormat(format).build()));await(export);assertEquals(JobState.COMPLETED,export.state,export.info().toString());
       if(format.equals("json"))assertEquals(large,com.google.gson.JsonParser.parseString(Files.readString(output)).getAsJsonArray().get(0).getAsJsonObject().get("added_text").getAsString());
       else try(var reader=Files.newBufferedReader(output);var csv=org.apache.commons.csv.CSVFormat.DEFAULT.builder().setHeader().get().parse(reader)){assertEquals(large,csv.getRecords().getFirst().get("added_text"));}
     }
     run(jobs,safety,s,"CREATE TABLE busydata_import (id INTEGER PRIMARY KEY, text_value VARCHAR(100), nullable_value INTEGER)");
     var sources=new io.busystack.busydata.transfers.ImportSources();
     for(String format:List.of("csv","json","ndjson")) {
       Path input=root.resolve("input."+format);int id=format.equals("csv")?1:format.equals("json")?2:3;
       String payload=format.equals("csv")?"source_id,source_text,source_null\n"+id+",\"漢😀,value\",\\N\n":format.equals("json")?"[{\"source_id\":"+id+",\"source_text\":\"漢😀,value\",\"source_null\":null}]":"{\"source_id\":"+id+",\"source_text\":\"漢😀,value\",\"source_null\":null}\n";
       Files.writeString(input,payload);
       var transfer=ToolRequest.newBuilder().setKind(format.equals("csv")?ToolKind.IMPORT_CSV:ToolKind.IMPORT_JSON).setFormat(format).setPath(input.toString()).setSchema(schema).setTable("busydata_import").setEncoding("UTF-8").setNullMarker("\\N").addAllColumns(List.of("id","text_value","nullable_value")).putColumnMapping("id","source_id").putColumnMapping("text_value","source_text").putColumnMapping("nullable_value","source_null").build();
       var preview=io.busystack.busydata.transfers.ImportSources.preview(transfer);assertEquals(1,preview.getRowsCount());assertTrue(preview.getRows(0).getValues(2).hasNullValue());assertEquals("漢😀,value",preview.getRows(0).getValues(1).getText());
       var approved=transfer.toBuilder().setSourceSha256(preview.getSourceSha256()).build();var imported=jobs.submit(s,UUID.randomUUID().toString(),"",j->transfers.run(j,approved));await(imported);assertEquals(JobState.COMPLETED,imported.state,imported.info().toString());
     }
     var importedCount=run(jobs,safety,s,"SELECT COUNT(*) FROM busydata_import");assertEquals("3",Values.text(results.get(importedCount.results().getFirst().getResultId()).read(0).getValues(0)));
     Path bad=root.resolve("bad.csv");Files.writeString(bad,"id,text_value,nullable_value\n4,valid,1\n5,bad,not_an_integer\n");
     var badTransfer=ToolRequest.newBuilder().setKind(ToolKind.IMPORT_CSV).setPath(bad.toString()).setSchema(schema).setTable("busydata_import").addAllColumns(List.of("id","text_value","nullable_value")).build();
     var failedImport=jobs.submit(s,UUID.randomUUID().toString(),"",j->transfers.run(j,badTransfer));await(failedImport);assertEquals(JobState.FAILED,failedImport.state);assertEquals(TransactionState.IDLE,s.state);assertTrue(s.autoCommit);
     var stillThree=run(jobs,safety,s,"SELECT COUNT(*) FROM busydata_import");assertEquals("3",Values.text(results.get(stillThree.results().getFirst().getResultId()).read(0).getValues(0)));
     if(engine!=Engine.POSTGRESQL){
       run(jobs,safety,s,"SET GLOBAL local_infile=ON");
       var enabled=run(jobs,safety,s,"SHOW GLOBAL VARIABLES LIKE 'local_infile'");assertEquals("ON",Values.text(results.get(enabled.results().getFirst().getResultId()).read(0).getValues(1)));
       Path unrelated=root.resolve("unrelated-private.csv");Files.writeString(unrelated,"99,unrelated-private-data,1\n");
       var localFile=submit(jobs,safety,s,"LOAD DATA LOCAL INFILE '"+unrelated.toString().replace("'","''")+"' INTO TABLE busydata_import FIELDS TERMINATED BY ','");await(localFile);assertEquals(JobState.FAILED,localFile.state,"An enabled server must not read local files through the disabled JDBC mechanism");
       var denied=run(jobs,safety,s,"SELECT COUNT(*) FROM busydata_import WHERE id=99");assertEquals("0",Values.text(results.get(denied.results().getFirst().getResultId()).read(0).getValues(0)));
     }
     // Inspect/draft/review/apply/re-inspect grants and native role membership.
     var privileges=new io.busystack.busydata.administration.PrivilegeTools();
     String recipientName="BusyData'Read漢",roleName="busydata_fixture_role";
     String recipient=s.adapter.quote(recipientName)+(engine==Engine.POSTGRESQL?"":"@`%`");
     String role=s.adapter.quote(roleName)+(engine==Engine.MYSQL?"@`%`":"");
     run(jobs,safety,s,engine==Engine.POSTGRESQL?"CREATE ROLE "+recipient+" LOGIN PASSWORD 'busydata-fixture'":"CREATE USER "+recipient+" IDENTIFIED BY 'busydata-fixture'");
     run(jobs,safety,s,"CREATE ROLE "+role);
     var listed=privileges.run(s,PrivilegeRequest.newBuilder().setSearch("BusyData'").build());
     assertEquals(1,listed.getPrincipalsCount());var receiver=listed.getPrincipals(0);
     var inspected=privileges.run(s,PrivilegeRequest.newBuilder().setGrantee(receiver).build());
     assertFalse(inspected.getDefinition().contains("busydata-fixture"));assertFalse(inspected.getDefinition().contains("authentication_string"));assertFalse(inspected.getDefinition().contains("IDENTIFIED"));
     var grantRequest=PrivilegeRequest.newBuilder().setAction(PrivilegeAction.DESIGN_PRIVILEGE).setGrantee(receiver).setScope(PrivilegeScope.TABLE_PRIVILEGE).setSchema(schema).setTable("busydata_import").addPrivileges("SELECT").build();
     run(jobs,safety,s,privileges.run(s,grantRequest).getSql(0));
     var granted=privileges.run(s,PrivilegeRequest.newBuilder().setGrantee(receiver).build());
     assertTrue(com.google.gson.JsonParser.parseString(granted.getDefinition()).getAsJsonObject().getAsJsonArray("tablePrivileges").asList().stream().anyMatch(v->v.toString().contains("busydata_import")&&v.toString().contains("SELECT")),granted.getDefinition());
     run(jobs,safety,s,privileges.run(s,grantRequest.toBuilder().setRevoke(true).build()).getSql(0));
     var revoked=privileges.run(s,PrivilegeRequest.newBuilder().setGrantee(receiver).build());
     assertFalse(com.google.gson.JsonParser.parseString(revoked.getDefinition()).getAsJsonObject().getAsJsonArray("tablePrivileges").asList().stream().anyMatch(v->v.toString().contains("busydata_import")),revoked.getDefinition());
     var roles=privileges.run(s,PrivilegeRequest.newBuilder().setSearch(roleName).build());assertEquals(1,roles.getPrincipalsCount());
     var membership=PrivilegeRequest.newBuilder().setAction(PrivilegeAction.DESIGN_PRIVILEGE).setGrantee(receiver).setScope(PrivilegeScope.ROLE_MEMBERSHIP).setRole(roles.getPrincipals(0)).setDelegation(true).build();
     run(jobs,safety,s,privileges.run(s,membership).getSql(0));
     var joinedRole=privileges.run(s,PrivilegeRequest.newBuilder().setGrantee(receiver).build());assertTrue(joinedRole.getDefinition().contains(roleName),joinedRole.getDefinition());
     run(jobs,safety,s,privileges.run(s,membership.toBuilder().setRevoke(true).setDelegation(false).build()).getSql(0));
     assertFalse(privileges.run(s,PrivilegeRequest.newBuilder().setGrantee(receiver).build()).getDefinition().contains(roleName));
     if(engine==Engine.POSTGRESQL){
       for(var scope:List.of(PrivilegeScope.SCHEMA_PRIVILEGE,PrivilegeScope.DATABASE_PRIVILEGE)){
         var scopeGrant=grantRequest.toBuilder().setScope(scope).setSchema(scope==PrivilegeScope.SCHEMA_PRIVILEGE?"public":"busydata").clearTable().clearPrivileges().addPrivileges(scope==PrivilegeScope.SCHEMA_PRIVILEGE?"USAGE":"CONNECT").build();
         run(jobs,safety,s,privileges.run(s,scopeGrant).getSql(0));
         var explicit=privileges.run(s,PrivilegeRequest.newBuilder().setGrantee(receiver).build());
         assertFalse(com.google.gson.JsonParser.parseString(explicit.getDefinition()).getAsJsonObject().getAsJsonArray(scope==PrivilegeScope.SCHEMA_PRIVILEGE?"schemaPrivileges":"databasePrivileges").isEmpty(),explicit.getDefinition());
         run(jobs,safety,s,privileges.run(s,scopeGrant.toBuilder().setRevoke(true).build()).getSql(0));
       }
     }else{
       run(jobs,safety,s,"CREATE DATABASE busy_data; CREATE DATABASE busyXdata; CREATE TABLE busy_data.probe (n INTEGER); CREATE TABLE busyXdata.probe (n INTEGER)");
       var databaseGrant=grantRequest.toBuilder().setScope(PrivilegeScope.DATABASE_PRIVILEGE).setSchema("busy_data").clearTable().build();
       run(jobs,safety,s,privileges.run(s,databaseGrant).getSql(0));
       var restricted=sessions.open(OpenRequest.newBuilder().setProfile(profile.toBuilder().setDatabase("busy_data").setUser(recipientName)).setPassword("busydata-fixture").build());
       run(jobs,safety,restricted,"SELECT * FROM probe");
       var unrelated=submit(jobs,safety,restricted,"SELECT * FROM busyXdata.probe");await(unrelated);assertEquals(JobState.FAILED,unrelated.state,"Escaped database grants must not authorize a wildcard-matching database");sessions.close(restricted.id,true);
       if(engine==Engine.MYSQL){
         run(jobs,safety,s,"SET GLOBAL partial_revokes=ON");
         String exact=privileges.run(s,databaseGrant).getSql(0);assertTrue(exact.contains("`busy_data`.*"),exact);run(jobs,safety,s,exact);
         var partial=sessions.open(OpenRequest.newBuilder().setProfile(profile.toBuilder().setDatabase("busy_data").setUser(recipientName)).setPassword("busydata-fixture").build());
         run(jobs,safety,partial,"SELECT * FROM probe");var deniedOther=submit(jobs,safety,partial,"SELECT * FROM busyXdata.probe");await(deniedOther);assertEquals(JobState.FAILED,deniedOther.state);sessions.close(partial.id,true);
       }
     }
     var readOnly=sessions.open(OpenRequest.newBuilder().setProfile(profile.toBuilder().setReadOnly(true)).setPassword("busydata-test").build());
     assertThrows(Exception.class,()->{try(var statement=readOnly.connection.createStatement()){statement.execute("INSERT INTO busydata_import VALUES(20,'blocked',NULL)");}});sessions.close(readOnly.id,true);
     if(engine!=Engine.POSTGRESQL){run(jobs,safety,s,"BEGIN; INSERT INTO busydata_import VALUES(6,'implicit',NULL); CREATE TABLE busydata_implicit (id INTEGER)");assertEquals(TransactionState.IDLE,s.state);run(jobs,safety,s,"ROLLBACK");var implicit=run(jobs,safety,s,"SELECT COUNT(*) FROM busydata_import WHERE id=6");assertEquals("1",Values.text(results.get(implicit.results().getFirst().getResultId()).read(0).getValues(0)));}
     String lossSql=engine==Engine.POSTGRESQL?"INSERT INTO busydata_import SELECT 50,'uncertain',NULL FROM pg_sleep(30)":"INSERT INTO busydata_import SELECT 50,CONCAT('uncertain',SLEEP(30)),NULL";
     var uncertain=submit(jobs,safety,s,lossSql);long started=System.nanoTime();while(uncertain.statement==null&&System.nanoTime()-started<TimeUnit.SECONDS.toNanos(5))Thread.sleep(10);
     database.stop();await(uncertain);assertEquals(JobState.UNKNOWN_OUTCOME,uncertain.state,uncertain.info().toString());assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state);
     var rejected=submit(jobs,safety,s,"SELECT 1");await(rejected);assertEquals(JobState.FAILED,rejected.state);assertEquals(TransactionState.UNKNOWN_TRANSACTION,s.state);
     // Retained-file export must survive both uncertain writes and explicit disconnection.
     var service=new io.busystack.busydata.rpc.WorkbenchService(sessions,jobs,results,metadata,safety,a,()->{});
     var context=io.busystack.busydata.protocol.Context.newBuilder().setProtocolVersion(io.busystack.busydata.protocol.ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber()).setInstanceId(service.instance).setRequestId(UUID.randomUUID().toString()).build();
     sessions.close(s.id,true);
     var exportRequest=ToolRequest.newBuilder().setContext(context).setSessionId(s.id).setKind(ToolKind.EXPORT_RESULT).setResultId(retained.id).setExecutionId(UUID.randomUUID().toString()).setPath(root.resolve("after-disconnect.json").toString()).setFormat("json").build();
     Approval approval=rpc(out->service.reviewTool(exportRequest,out));
     JobInfo exported=rpc(out->service.tool(exportRequest.toBuilder().setApprovalToken(approval.getToken()).build(),out));
     await(jobs.get(exported.getJobId()));assertEquals(JobState.COMPLETED,jobs.get(exported.getJobId()).state);
     assertEquals(large,com.google.gson.JsonParser.parseString(Files.readString(root.resolve("after-disconnect.json"))).getAsJsonArray().get(0).getAsJsonObject().get("added_text").getAsString());
     assertThrows(IllegalArgumentException.class,()->sessions.get(exportRequest.getSessionId()));
    }
   }
  }
 }
 private record Completed(List<StatementResult> results){}
 private static <T> T rpc(java.util.function.Consumer<io.grpc.stub.StreamObserver<T>> call)throws Exception {var future=new CompletableFuture<T>();call.accept(new io.grpc.stub.StreamObserver<T>(){public void onNext(T value){future.complete(value);}public void onError(Throwable error){future.completeExceptionally(error);}public void onCompleted(){}});return future.get(10,TimeUnit.SECONDS);}
 private static Jobs.Job submit(Jobs jobs,Safety safety,SessionRegistry.Session s,String sql)throws Exception {var r=ExecuteRequest.newBuilder().setSessionId(s.id).setExecutionId(UUID.randomUUID().toString()).setSql(sql).setRowLimit(1000).build();var review=safety.review(r,s);return jobs.execute(s,r.toBuilder().setApprovalToken(review.getToken()).build());}
 private static Completed run(Jobs jobs,Safety safety,SessionRegistry.Session s,String sql)throws Exception {var job=submit(jobs,safety,s,sql);await(job);assertEquals(JobState.COMPLETED,job.info().getState(),job.info().toString());return new Completed(job.info().getResultsList());}
 private static void await(Jobs.Job j)throws Exception {long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(30);while(!Jobs.terminal(j.state)&&System.nanoTime()<deadline)Thread.sleep(10);assertTrue(Jobs.terminal(j.state),"Job did not terminate");}
}
