package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.SchemaTools;
import io.busystack.busydata.transfers.Transfers;
import io.busystack.busydata.security.NativeToolTransport;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class NativeBackupIT {
 @TempDir Path root;
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void realSelectedClientsRestoreSchemaAndExactRepresentativeData(String name)throws Exception {
  try(var fixture=new EngineFixture(root,name)){
   var session=fixture.open();boolean postgres=fixture.engine==Engine.POSTGRESQL;
   Path tools=Path.of(System.getProperty("busydata.native.tools.root",Path.of(System.getProperty("basedir")).resolve("target/native-tools").toString())).resolve(name.toLowerCase(Locale.ROOT));if(Files.isDirectory(tools.resolve("bin")))tools=tools.resolve("bin");
   Path dump=tools.resolve(postgres?"pg_dump":fixture.engine==Engine.MYSQL?"mysqldump":"mariadb-dump"),restore=tools.resolve(postgres?"psql":fixture.engine==Engine.MYSQL?"mysql":"mariadb");
   assertTrue(Files.isExecutable(dump),"Prepare real selected native fixture tools; missing tools fail this required stage");assertTrue(Files.isExecutable(restore));
   fixture.execute(session,"CREATE TABLE backup_data(id INTEGER PRIMARY KEY,n DECIMAL(30,12),t VARCHAR(300),b "+(postgres?"BYTEA":"LONGBLOB")+"); CREATE INDEX backup_n ON backup_data(n); CREATE VIEW backup_view AS SELECT id,n,t FROM backup_data;");
   try(var statement=session.connection.prepareStatement("INSERT INTO backup_data VALUES(?,?,?,?)")) {
    for(int id=1;id<=100;id++){statement.setInt(1,id);statement.setBigDecimal(2,new java.math.BigDecimal("123456789012345.123456789012"));statement.setString(3,"Unicode 漢😀 quote ' tab\t newline\n"+id);statement.setBytes(4,new byte[]{0,1,(byte)255,39,92});statement.addBatch();}statement.executeBatch();
   }
   var schema=new SchemaTools(fixture.metadata.metadataPlatform());String before=schema.run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.CAPTURE_SCHEMA).setSchema(fixture.schema()).build()).getSnapshot();
   var transfers=new Transfers(fixture.results,new NativeToolTransport(Path.of(System.getProperty("basedir")).resolve("target/native-build")));
   Path file=root.resolve("Unicode 漢 🌍 backup.sql");
   run(fixture,session,transfers,ToolRequest.newBuilder().setKind(ToolKind.DUMP).setPath(file.toString()).setNativeToolPath(dump.toString()).build());
   assertTrue(Files.size(file)>1000);
   fixture.execute(session,"DROP VIEW backup_view; DROP TABLE backup_data;");
   run(fixture,session,transfers,ToolRequest.newBuilder().setKind(ToolKind.RESTORE).setPath(file.toString()).setNativeToolPath(restore.toString()).build());
   String after=schema.run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.CAPTURE_SCHEMA).setSchema(fixture.schema()).build()).getSnapshot();
   Path evidence=Path.of(System.getProperty("basedir")).resolve("target/native-backup-evidence");Files.createDirectories(evidence);
   Files.writeString(evidence.resolve(name+"-before.json"),before);Files.writeString(evidence.resolve(name+"-after.json"),after);
   Files.copy(file,evidence.resolve(name+"-fixture.sql"),StandardCopyOption.REPLACE_EXISTING);
   var difference=schema.run(session,SchemaToolRequest.newBuilder().setAction(SchemaToolAction.COMPARE_SCHEMA).setSourceSnapshot(after).setTargetSnapshot(before).build());
   assertTrue(difference.getEquivalent(),difference.toString());
   try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT id,n,t,b FROM backup_data ORDER BY id")){
    int count=0;while(rows.next()){int id=++count;assertEquals(id,rows.getInt(1));assertEquals(new java.math.BigDecimal("123456789012345.123456789012"),rows.getBigDecimal(2));assertEquals("Unicode 漢😀 quote ' tab\t newline\n"+id,rows.getString(3));assertArrayEquals(new byte[]{0,1,(byte)255,39,92},rows.getBytes(4));}assertEquals(100,count);
   }
   Files.writeString(evidence.resolve(name+"-native-roundtrip.json"),"{\"engine\":\""+name+"\",\"rows\":100,\"dumpBytes\":"+Files.size(file)+",\"canonicalSchemaEquivalent\":true}");
   Path malformed=root.resolve("Unicode 漢 partial.sql");
   Files.writeString(malformed,"CREATE TABLE partial_restore(id INTEGER PRIMARY KEY);\nINSERT INTO partial_restore VALUES(1);\nDELIBERATELY_INVALID_SQL;\nINSERT INTO partial_restore VALUES(2);\n");
   var partial=fixture.jobs.submit(session,UUID.randomUUID().toString(),"",operation->transfers.run(operation,ToolRequest.newBuilder().setKind(ToolKind.RESTORE).setPath(malformed.toString()).setNativeToolPath(restore.toString()).build()));
   assertEquals(JobState.UNKNOWN_OUTCOME,partial.finished.get(60,TimeUnit.SECONDS).getState(),partial.info().toString());
   try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT id FROM partial_restore ORDER BY id")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertFalse(rows.next(),"The native client stops at the first failure; already committed data is reported accurately");}
   assertTrue(partial.info().getMessagesList().stream().anyMatch(m->m.contains("partial")||m.contains("committed")));
   assertFalse(partial.info().getMessagesList().stream().anyMatch(m->m.contains("DELIBERATELY_INVALID_SQL")||m.contains("fixture")));

  }
 }

 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void databaseIdentifiersCannotBecomeNativeOptionsOrConnectionSettings(String name)throws Exception {
  try(var fixture=new EngineFixture(root,name)){
   var initial=fixture.open();boolean pg=fixture.engine==Engine.POSTGRESQL;String database=pg?"dbname=missing user=unapproved 漢":"--execute=SELECT wrong 漢";
   fixture.execute(initial,"CREATE DATABASE "+initial.adapter.quote(database));
   var session=fixture.sessions.open(OpenRequest.newBuilder().setProfile(fixture.profile.toBuilder().setDatabase(database)).setPassword("fixture").build());
   fixture.execute(session,"CREATE TABLE exact_target(id INTEGER PRIMARY KEY,t VARCHAR(100)); INSERT INTO exact_target VALUES(1,'Unicode 漢😀')");
   Path tools=Path.of(System.getProperty("busydata.native.tools.root",Path.of(System.getProperty("basedir")).resolve("target/native-tools").toString())).resolve(name.toLowerCase(Locale.ROOT));if(Files.isDirectory(tools.resolve("bin")))tools=tools.resolve("bin");
   Path dump=tools.resolve(pg?"pg_dump":fixture.engine==Engine.MYSQL?"mysqldump":"mariadb-dump"),restore=tools.resolve(pg?"psql":fixture.engine==Engine.MYSQL?"mysql":"mariadb");
   var transfers=new Transfers(fixture.results,new NativeToolTransport(Path.of(System.getProperty("basedir")).resolve("target/native-build")));Path file=root.resolve("native option target.sql");
   run(fixture,session,transfers,ToolRequest.newBuilder().setKind(ToolKind.DUMP).setPath(file.toString()).setNativeToolPath(dump.toString()).build());
   fixture.execute(session,"DROP TABLE exact_target");
   run(fixture,session,transfers,ToolRequest.newBuilder().setKind(ToolKind.RESTORE).setPath(file.toString()).setNativeToolPath(restore.toString()).build());
   try(var statement=session.connection.createStatement();var rows=statement.executeQuery("SELECT t FROM exact_target WHERE id=1")){assertTrue(rows.next());assertEquals("Unicode 漢😀",rows.getString(1));assertFalse(rows.next());}
   assertEquals(database,session.context.catalog());
  }
 }
 private static JobsResult run(EngineFixture fixture,io.busystack.busydata.sessions.SessionRegistry.Session session,Transfers transfers,ToolRequest request)throws Exception {
  var job=fixture.jobs.submit(session,UUID.randomUUID().toString(),"",operation->transfers.run(operation,request));var outcome=job.finished.get(60,TimeUnit.SECONDS);
  String diagnostic="";
  if(outcome.getState()!=JobState.COMPLETED&&fixture.engine==Engine.MARIADB&&request.getKind()==ToolKind.RESTORE){
   diagnostic=NativeBackupLockEvidence.capture(fixture,session);
   try{Path evidence=Path.of(System.getProperty("basedir")).resolve("target/native-backup-evidence");Files.createDirectories(evidence);Files.writeString(evidence.resolve("MARIADB-restore-failure-"+UUID.randomUUID()+".json"),diagnostic);}catch(java.io.IOException unavailable){diagnostic="{\"availability\":\"EVIDENCE_FILE_UNAVAILABLE\"}";}
  }
  assertEquals(JobState.COMPLETED,outcome.getState(),"Native "+request.getKind()+" engine="+fixture.engine+" state="+outcome.getState()+" code="+outcome.getErrorCode()+"; lock evidence="+diagnostic);return new JobsResult(outcome);
 }
 private record JobsResult(JobInfo info){}
}
