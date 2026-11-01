package io.busystack.busydata;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.results.*;
import java.nio.file.*;
import java.util.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class CoreTest {
 @TempDir Path root;
 @Test void historyPrivacyChangesDoNotRetroactivelyRetainSqlOrResurrectDeletedActiveEntries()throws Exception {
  try(var store=new MetadataStore(root)){
   var profile=Profile.newBuilder().setName("target").build();long now=System.currentTimeMillis();
   var job=JobInfo.newBuilder().setJobId("active").setExecutionId("active-id").setState(JobState.QUEUED).build();
   store.started(job,profile,"SELECT 'private'",now,true);
   store.history(HistoryRequest.newBuilder().setAction(HistoryAction.SET_PRIVACY).setRetainSql(true).setRetentionDays(30).build());
   store.history(job.toBuilder().setState(JobState.COMPLETED).build(),profile,"SELECT 'private'",now);
   assertEquals("",store.history(HistoryRequest.getDefaultInstance()).getEntries(0).getSql());
   job=job.toBuilder().setJobId("deleted").setExecutionId("deleted-id").build();store.started(job,profile,"SELECT 'also private'",now,true);
   store.history(HistoryRequest.newBuilder().setAction(HistoryAction.DELETE_HISTORY_ENTRY).setEntryId("deleted").build());
   store.history(job.toBuilder().setState(JobState.COMPLETED).build(),profile,"SELECT 'also private'",now);
   assertTrue(store.history(HistoryRequest.getDefaultInstance()).getEntriesList().stream().noneMatch(entry->entry.getId().equals("deleted")));
  }
 }
 @Test void privateCredentialScratchCleansCrashArtifactsWithoutFollowingLinks()throws Exception {
  Path scratch=root.resolve("credential-scratch"),unrelated=root.resolve("unrelated.pem");Files.createDirectories(scratch);Files.writeString(unrelated,"keep");Files.writeString(scratch.resolve("old-native.pgpass"),"old credential");
  if(!System.getProperty("os.name").startsWith("Windows"))Files.createSymbolicLink(scratch.resolve("stale-link"),unrelated);
  try(var files=new io.busystack.busydata.security.PrivateTemporaryFiles(scratch)) {
   assertEquals("keep",Files.readString(unrelated));try(var entries=Files.list(scratch)){assertEquals(0,entries.count());}
   Path selected=files.create("tls-",".private");Files.writeString(selected,"fixture key");
   if(!System.getProperty("os.name").startsWith("Windows"))assertEquals(java.nio.file.attribute.PosixFilePermissions.fromString("rw-------"),Files.getPosixFilePermissions(selected));
  }
  assertFalse(Files.exists(scratch));assertEquals("keep",Files.readString(unrelated));
 }
 @Test void unsupportedMetadataVersionIsPreservedAndReleasesWriterLease()throws Exception {
  try(var initial=new MetadataStore(root)){}
  try(var db=java.sql.DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement()){statement.execute("DELETE FROM migration");statement.execute("INSERT INTO migration VALUES(999)");}
  assertThrows(IllegalStateException.class,()->new MetadataStore(root));
  try(var db=java.sql.DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement();var version=statement.executeQuery("SELECT version FROM migration")){assertTrue(version.next());assertEquals(999,version.getInt(1));}
  try(var db=java.sql.DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=db.createStatement()){statement.execute("DELETE FROM migration");statement.execute("INSERT INTO migration VALUES(1)");statement.execute("DROP TABLE metadata_source_identity");}
  try(var reopened=new MetadataStore(root)){assertTrue(reopened.profiles().isEmpty());}
 }
 @Test void restartMarksPendingOperationsUncertainWithoutRestoringSessions()throws Exception {
  var p=Profile.newBuilder().setName("fixture").setEngine(Engine.POSTGRESQL).build();
  try(var store=new MetadataStore(root)){store.started(JobInfo.newBuilder().setJobId("write").setExecutionId("write-id").build(),p,"INSERT INTO t VALUES(1)",System.currentTimeMillis(),false);store.started(JobInfo.newBuilder().setJobId("read").setExecutionId("read-id").build(),p,"SELECT 1",System.currentTimeMillis(),true);}
  try(var store=new MetadataStore(root)){var entries=store.history(HistoryRequest.getDefaultInstance()).getEntriesList();assertEquals(JobState.UNKNOWN_OUTCOME,entries.stream().filter(e->e.getId().equals("write")).findFirst().orElseThrow().getState());assertEquals(JobState.INTERRUPTED,entries.stream().filter(e->e.getId().equals("read")).findFirst().orElseThrow().getState());assertTrue(entries.stream().allMatch(e->e.getSql().isEmpty()));}
 }
 @Test void splitsOriginalSqlAndDollarProcedures() {
  var a=new SqlAnalysis();
  var f=a.split("SELECT 'a;b', \"semi;column\"; /* outer /* inner ; */ */ DO $body$ BEGIN PERFORM 1; END; $body$; SELECT '😀';",Engine.POSTGRESQL);
  assertEquals(3,f.size());assertTrue(f.get(1).text().contains("PERFORM 1;"));
  assertEquals("SELECT '😀'",f.get(2).text());
 }
 @Test void mysqlDelimiterAndEscapedString() {
  var f=new SqlAnalysis().split("DELIMITER $$\nCREATE PROCEDURE p() BEGIN SELECT 'a;'; SELECT 2; END$$\nDELIMITER ;\nSELECT 'escaped\\\';x';",Engine.MYSQL);
  assertEquals(2,f.size());assertTrue(f.get(0).text().contains("SELECT 2;"));
 }
 @Test void unknownSyntaxIsNeverSafeAndIncompleteAnalysisIsVersioned() {
  var a=new SqlAnalysis();assertFalse(a.readOnly("NONSENSE UPDATE"));assertFalse(a.readOnly("WITH x AS (DELETE FROM t RETURNING *) SELECT * FROM x"));
  var analysis=a.analyze(AnalysisRequest.newBuilder().setOperation(AnalysisOperation.DIAGNOSTICS).setSql("SELECT 😀 FROM ").setDocumentId("doc").setDocumentVersion(4).setEngine(Engine.POSTGRESQL).build());
  assertEquals(4,analysis.getDocumentVersion());assertFalse(analysis.getDiagnosticsList().isEmpty());
 }
 @Test void staleAndChangedApprovalRejected() {
  var safety=new Safety(new SqlAnalysis());var p=Profile.newBuilder().setEngine(Engine.POSTGRESQL).build();
  var r=ExecuteRequest.newBuilder().setSessionId("s").setSql("DELETE FROM t").setDocumentVersion(3).build();
  var permit=safety.review(r,p,0);var approved=r.toBuilder().setApprovalToken(permit.getToken()).build();
  assertThrows(IllegalArgumentException.class,()->safety.authorize(approved,p,1));
  permit=safety.review(r,p,0);var changed=r.toBuilder().setApprovalToken(permit.getToken()).setSql("DELETE FROM other").build();
  assertThrows(IllegalArgumentException.class,()->safety.authorize(changed,p,0));
  permit=safety.review(r,p,0);var exact=r.toBuilder().setApprovalToken(permit.getToken()).build();safety.authorize(exact,p,0);assertThrows(IllegalArgumentException.class,()->safety.authorize(exact,p,0));
 }
 @Test void historyDefaultsToNoSqlAndDisablingRetentionRemovesText()throws Exception {
  try(var store=new MetadataStore(root)) {
   var job=JobInfo.newBuilder().setJobId("job").setState(JobState.COMPLETED).build();var p=Profile.newBuilder().setName("test").build();
   store.history(job,p,"SELECT 'secret'",System.currentTimeMillis());assertEquals("",store.history(HistoryRequest.getDefaultInstance()).getEntries(0).getSql());
   store.history(HistoryRequest.newBuilder().setAction(HistoryAction.SET_PRIVACY).setRetainSql(true).setRetentionDays(30).build());
   store.history(job,p,"SELECT 'private'",System.currentTimeMillis());assertEquals("SELECT 'private'",store.history(HistoryRequest.getDefaultInstance()).getEntries(0).getSql());
   store.history(HistoryRequest.newBuilder().setAction(HistoryAction.SET_PRIVACY).setRetentionDays(30).build());assertEquals("",store.history(HistoryRequest.getDefaultInstance()).getEntries(0).getSql());
  }
 }
 @Test void historyPagesUnicodePreviewsRetrievesExactChunksAndDeletesEntries()throws Exception {
  try(var store=new MetadataStore(root)) {
   store.history(HistoryRequest.newBuilder().setAction(HistoryAction.SET_PRIVACY).setRetainSql(true).setRetentionDays(10).build());
   var profile=Profile.newBuilder().setName("target").build();String sql="SELECT '"+"😀漢".repeat(5000)+"';";
   for(int i=0;i<4;i++)store.history(JobInfo.newBuilder().setJobId("history-"+i).setState(JobState.COMPLETED).build(),profile,sql,System.currentTimeMillis()+i);
   var page=store.history(HistoryRequest.newBuilder().setLimit(2).setSearch("target").build());assertEquals(2,page.getEntriesCount());assertTrue(page.getLimited());assertTrue(page.getEntries(0).getSqlTruncated());
   assertEquals(2,store.history(HistoryRequest.newBuilder().setLimit(2).setOffset(page.getNextOffset()).build()).getEntriesCount());
   var exact=new StringBuilder();int offset=0;while(true){var chunk=store.historySql(HistorySqlRequest.newBuilder().setEntryId("history-3").setOffsetUtf16(offset).setMaxUnits(4097).build());exact.append(chunk.getText());assertTrue(chunk.getNextOffsetUtf16()>offset);if(chunk.getComplete())break;offset=chunk.getNextOffsetUtf16();}assertEquals(sql,exact.toString());
   store.history(HistoryRequest.newBuilder().setAction(HistoryAction.DELETE_HISTORY_ENTRY).setEntryId("history-3").build());assertThrows(IllegalArgumentException.class,()->store.historySql(HistorySqlRequest.newBuilder().setEntryId("history-3").build()));
   assertThrows(IllegalArgumentException.class,()->store.history(HistoryRequest.newBuilder().setLimit(-1).build()));
  }
 }
 @Test void exactValuesAndQuotaControlledRandomAccess()throws Exception {
  try(var store=new ResultStore(root,512)) {
   var r=store.create(List.of(Column.newBuilder().setName("exact").setTypeName("numeric").build()));
   var row=Row.newBuilder().addValues(Value.newBuilder().setDecimal("123456789012345678901234567890.123456789")).addValues(Values.nil()).addValues(Value.newBuilder().setUnsignedInteger("18446744073709551615")).build();
   r.append(row);assertEquals(row,r.read(0));
   var page=r.page(PageRequest.newBuilder().setLimit(10).setMaxBytes(262144).build());assertEquals(row,page.getRows(0));
   assertThrows(java.io.IOException.class,()->r.append(Row.newBuilder().addValues(Value.newBuilder().setText("x".repeat(512))).build()));
   r.close();assertEquals(0,store.bytes());assertThrows(IllegalArgumentException.class,()->store.get(r.id));
  }
 }
}
