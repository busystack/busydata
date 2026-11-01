package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Real SQLite outcomes and exact attribution; no clock hooks or cache policy. */
class MetadataWriteMetricsTest {
    @TempDir Path root;
    private static final IdentifierRules RULES=new IdentifierRules(Engine.POSTGRESQL,0);
    private static MetadataSnapshot snapshot(long revision,long configuration){
        var object=MetadataObject.from("source","profile","",RULES,SchemaObject.newBuilder().setKind(ObjectKind.TABLE).setCatalog("db").setSchema("public").setName("retained").build(),IntrospectionLevel.STRUCTURE,1,1);
        return new MetadataSnapshot("source","profile",revision,configuration,revision,RULES,List.of(object),Map.of());
    }
    private static MetadataSnapshot empty(){return MetadataSnapshot.empty("source","profile",RULES);}
    private long deadline(){return System.nanoTime()+TimeUnit.SECONDS.toNanos(30);}
    private Connection open()throws SQLException{return DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata_catalog.sqlite"));}
    private void sql(String text)throws SQLException{try(var db=open();var statement=db.createStatement()){statement.execute(text);}}
    private static void boundedDurations(MetadataRepository.WriteMetrics value){
        long sum=0;for(long duration:new long[]{value.admissionNanos(),value.openAndSetupNanos(),value.dataMutationNanos(),value.commitNanos(),value.callbackDetachNanos(),value.connectionCloseNanos(),value.rollbackNanos()}){assertTrue(duration>=0);sum+=duration;}
        assertTrue(value.totalNanos()>=sum,"Exclusive measured phases cannot exceed the complete call");
    }
    @Test void acknowledgedWriteRecordsExactIdentityAndEveryNativeTerminalPhase()throws Exception {
        var repository=new MetadataRepository(root);var snapshot=snapshot(7,3);var receipt=repository.publish(snapshot,empty(),deadline());
        var metrics=receipt.await(deadline());assertNotNull(metrics);assertTrue(metrics.matches(snapshot));assertEquals("source",metrics.source());assertEquals("profile",metrics.profileId());assertEquals(7,metrics.snapshotRevision());assertEquals(3,metrics.configurationRevision());
        assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,metrics.commitOutcome());assertFalse(metrics.terminalCloseFailed());assertFalse(metrics.deadlineOverrun());
        for(long duration:new long[]{metrics.admissionNanos(),metrics.openAndSetupNanos(),metrics.dataMutationNanos(),metrics.commitNanos(),metrics.callbackDetachNanos(),metrics.connectionCloseNanos()})assertTrue(duration>0);
        assertEquals(0,metrics.rollbackNanos());boundedDurations(metrics);assertEquals(7,repository.loadNewest().getFirst().revision());
        assertSame(metrics,receipt.await(deadline()),"Reading a completed receipt must never repeat its native write");
    }
    @Test void admissionTimeoutPreservesItsSqlExceptionAndDoesNotOpenOrReserveAWriter()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot(1,1);repository.publish(before,empty()).await(deadline());
        var failure=assertThrows(SQLTimeoutException.class,()->repository.publish(snapshot(2,1),before,System.nanoTime()-1));assertEquals("57014",failure.getSQLState());assertTrue(repository.activeReceipt().isEmpty());
        assertEquals(before.identities(),repository.loadNewest().getFirst().identities());assertEquals(1,repository.loadNewest().getFirst().revision());
    }
    @Test void deferredConstraintFailureKeepsCommitUnacknowledgedAndMeasuresRealRollbackCleanup()throws Exception {
        var repository=new MetadataRepository(root);var before=snapshot(1,1);repository.publish(before,empty()).await(deadline());
        sql("CREATE TABLE deferred_parent(id INTEGER PRIMARY KEY)");sql("CREATE TABLE deferred_child(id INTEGER REFERENCES deferred_parent(id) DEFERRABLE INITIALLY DEFERRED)");
        sql("CREATE TRIGGER reject_commit AFTER UPDATE ON publication WHEN NEW.revision=2 BEGIN INSERT INTO deferred_child VALUES(99); END");
        var receipt=repository.publish(snapshot(2,1),before,deadline());var failure=assertThrows(SQLException.class,()->receipt.await(deadline()));assertEquals(19,failure.getErrorCode()&255);
        var completion=receipt.awaitCompletion(deadline());assertEquals(19,completion.failure().primary().vendorCode()&255);var metrics=completion.metrics();assertEquals(MetadataRepository.CommitOutcome.UNKNOWN,metrics.commitOutcome());assertFalse(metrics.terminalCloseFailed());assertTrue(metrics.commitNanos()>0);assertTrue(metrics.rollbackNanos()>0);assertTrue(metrics.callbackDetachNanos()>0);assertTrue(metrics.connectionCloseNanos()>0);boundedDurations(metrics);
        assertEquals(1,repository.loadNewest().getFirst().revision());try(var db=open();var statement=db.createStatement();var rows=statement.executeQuery("SELECT COUNT(*) FROM deferred_child")){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}
    }
    @Test void sourceOwnerSnapshotConfigurationAndProfileAllFenceMetricAttribution()throws Exception {
        var repository=new MetadataRepository(root);var current=snapshot(1,1);var metrics=repository.publish(current,empty(),deadline()).await(deadline());var owner=new MetadataPlatform.Source(current);
        assertTrue(MetadataPlatform.cacheMetricsCurrent(owner,owner,owner.owner,current,metrics));assertFalse(MetadataPlatform.cacheMetricsCurrent(owner,owner,owner.owner+1,current,metrics));
        assertFalse(MetadataPlatform.cacheMetricsCurrent(owner,new MetadataPlatform.Source(current),owner.owner,current,metrics));assertFalse(MetadataPlatform.cacheMetricsCurrent(owner,owner,owner.owner,snapshot(1,2),metrics));
        owner.snapshot.set(snapshot(2,1));assertFalse(MetadataPlatform.cacheMetricsCurrent(owner,owner,owner.owner,current,metrics));
        assertFalse(metrics.matches(new MetadataSnapshot("source","different-profile",1,1,1,RULES,List.of(),Map.of())));assertFalse(metrics.matches(MetadataSnapshot.empty("different-source","profile",RULES)));
    }
    @Test void acknowledgedLateCommitAndCloseFailureRemainDistinctFromRollbackOrAnUnknownCommit()throws Exception {
        var value=snapshot(1,1);var attemptType=Class.forName(MetadataRepository.class.getName()+"$WriteAttempt");var constructor=attemptType.getDeclaredConstructor(MetadataSnapshot.class,long.class);constructor.setAccessible(true);var attempt=constructor.newInstance(value,System.nanoTime()-1);
        var commit=attemptType.getDeclaredMethod("commit",Connection.class);commit.setAccessible(true);var close=MetadataRepository.class.getDeclaredMethod("closeConnection",Connection.class,attemptType);close.setAccessible(true);var finish=attemptType.getDeclaredMethod("finish");finish.setAccessible(true);
        var closeFailure=new SQLTimeoutException("Owned fixture terminal failure","57014");
        try(var db=open()){
            try(var statement=db.createStatement()){statement.execute("CREATE TABLE terminal_proof(value INTEGER)");}db.setAutoCommit(false);try(var statement=db.createStatement()){statement.executeUpdate("INSERT INTO terminal_proof VALUES(7)");}
            commit.invoke(attempt,db);
            var closing=(Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{try{var result=method.invoke(db,args);if(method.getName().equals("close"))throw closeFailure;return result;}catch(InvocationTargetException failure){throw failure.getCause();}});
            assertSame(closeFailure,assertThrows(InvocationTargetException.class,()->close.invoke(null,closing,attempt)).getCause());assertTrue(db.isClosed());
        }
        var metrics=(MetadataRepository.WriteMetrics)finish.invoke(attempt);assertEquals(MetadataRepository.CommitOutcome.ACKNOWLEDGED,metrics.commitOutcome());assertTrue(metrics.deadlineOverrun());assertTrue(metrics.terminalCloseFailed());assertEquals(0,metrics.rollbackNanos());boundedDurations(metrics);
        try(var db=open();var statement=db.createStatement();var rows=statement.executeQuery("SELECT value FROM terminal_proof")){assertTrue(rows.next());assertEquals(7,rows.getInt(1));assertFalse(rows.next());}
    }
    @Test void submissionFailureWithoutAReceiptCannotExposePreviousSuccessfulCacheHealth(){
        var owner=new MetadataPlatform.Source(snapshot(2,1));owner.cacheState="AVAILABLE";owner.cacheWriteNanos=9;
        MetadataPlatform.cacheSubmissionFailed(owner,new IllegalStateException("private fixture detail"),12);
        assertEquals("WRITE_UNAVAILABLE",owner.cacheState);assertNull(owner.cacheAttempt);assertNull(owner.cacheMetrics);assertEquals(12,owner.cacheWriteNanos);assertEquals(MetadataRepository.FailureReason.UNAVAILABLE,owner.cacheFailure.reason());assertFalse(owner.cacheFailure.toString().contains("private"));
    }
}
