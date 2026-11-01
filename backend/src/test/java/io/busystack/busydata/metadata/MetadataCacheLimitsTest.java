package io.busystack.busydata.metadata;

import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.*;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

/** Real pinned SQLite; lower helper bounds avoid a half-gigabyte unit fixture. */
class MetadataCacheLimitsTest {
    @TempDir Path root;
    private Connection open()throws SQLException{return DriverManager.getConnection("jdbc:sqlite:"+root.resolve("page-limit.sqlite"));}
    private static long pragma(Connection db,String name)throws SQLException{try(var statement=db.createStatement();var rows=statement.executeQuery("PRAGMA "+name)){assertTrue(rows.next());return rows.getLong(1);}}
    private static AutoCloseable prepare(Connection db)throws Exception{
        var method=MetadataRepository.class.getDeclaredMethod("prepareWriter",Connection.class,long.class);method.setAccessible(true);
        return (AutoCloseable)method.invoke(null,db,System.nanoTime()+TimeUnit.SECONDS.toNanos(2));
    }
    @Test void everyProductionWriterInstallsAndVerifiesItsOwnPageMaximum()throws Exception{
        for(int attempt=0;attempt<2;attempt++)try(var db=open();var guard=prepare(db)){
            assertEquals(MetadataRepository.MAX_CACHE_BYTES/pragma(db,"page_size"),pragma(db,"max_page_count"));
            try(var statement=db.createStatement()){statement.execute("CREATE TABLE IF NOT EXISTS retained(value INTEGER)");}
        }
        // Proves the policy cannot be set once on initialization's connection.
        try(var db=open()){assertNotEquals(MetadataRepository.MAX_CACHE_BYTES/pragma(db,"page_size"),pragma(db,"max_page_count"));}
    }
    @Test void sqliteFullAtALowerTestBoundRollsBackAndPreservesPriorRows()throws Exception{
        try(var db=open();var statement=db.createStatement()){
            statement.execute("CREATE TABLE retained(value BLOB)");statement.execute("INSERT INTO retained VALUES(X'010203')");
            long bound=(pragma(db,"page_count")+2)*pragma(db,"page_size");MetadataRepository.enforcePageLimit(db,bound);db.setAutoCommit(false);
            try{var failure=assertThrows(SQLException.class,()->statement.executeUpdate("INSERT INTO retained VALUES(zeroblob(131072))"));assertEquals(13,failure.getErrorCode()&255);assertEquals(MetadataRepository.FailureReason.LIMITED,MetadataRepository.writeFailure(failure).reason());}
            finally{try{db.rollback();}catch(SQLException ended){assertTrue(db.getAutoCommit()||ended.getErrorCode()==1);}}
            try(var rows=statement.executeQuery("SELECT count(*),hex(min(value)) FROM retained")){assertTrue(rows.next());assertEquals(1,rows.getInt(1));assertEquals("010203",rows.getString(2));}
            assertTrue(pragma(db,"page_count")*pragma(db,"page_size")<=bound);
        }
    }
    @Test void anAlreadyOversizedCacheIsRefusedWithoutChangingOrCopyingIt()throws Exception{
        try(var db=open();var statement=db.createStatement()){
            statement.execute("CREATE TABLE retained(value BLOB)");statement.execute("INSERT INTO retained VALUES(zeroblob(65536))");long pages=pragma(db,"page_count"),size=pragma(db,"page_size");
            var failure=assertThrows(SQLException.class,()->MetadataRepository.enforcePageLimit(db,(pages-1)*size));assertEquals(MetadataRepository.FailureReason.LIMITED,MetadataRepository.writeFailure(failure).reason());
            assertEquals(pages,pragma(db,"page_count"));try(var rows=statement.executeQuery("SELECT length(value) FROM retained")){assertTrue(rows.next());assertEquals(65536,rows.getInt(1));assertFalse(rows.next());}
        }
    }
    @Test void failureEvidenceIsTypedBoundedAndContainsNoDriverProse(){
        var reason=MetadataRepository.writeFailure(new SQLException("sensitive SQL and values","untrusted state",13));assertEquals(MetadataRepository.FailureReason.LIMITED,reason.reason());assertEquals("",reason.sqlState());assertEquals(13,reason.vendorCode());assertFalse(reason.toString().contains("sensitive"));
        assertEquals(MetadataRepository.FailureReason.TIMED_OUT,MetadataRepository.writeFailure(new SQLTimeoutException("private detail","57014")).reason());
        assertEquals(MetadataRepository.FailureReason.CANCELLED,MetadataRepository.writeFailure(new SQLTransientException("private detail","57014")).reason());
        assertEquals(MetadataRepository.FailureReason.IO,MetadataRepository.writeFailure(new SQLException("private path","",10)).reason());
        assertEquals(MetadataRepository.FailureReason.DENIED,MetadataRepository.writeFailure(new SQLException("private path","",8)).reason());
    }
}
