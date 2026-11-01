package io.busystack.busydata;

import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.protocol.*;
import java.lang.reflect.*;
import java.nio.file.*;
import java.sql.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class MetadataFailureTest {
    @TempDir Path root;
    @Test void failedRollbackNeverRestoresAutoCommitOrReusesWriter()throws Exception {
        var restores=new AtomicInteger();
        try(var store=new MetadataStore(root,connection->(Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
            if(method.getName().equals("commit"))throw new SQLException("primary fixture failure","40001");
            if(method.getName().equals("rollback"))throw new SQLException("rollback fixture failure","HY000");
            if(method.getName().equals("setAutoCommit")&&Boolean.TRUE.equals(args[0]))restores.incrementAndGet();
            try{return method.invoke(connection,args);}catch(InvocationTargetException error){throw error.getCause();}
        }))){
            var failure=assertThrows(SQLException.class,()->store.started(JobInfo.newBuilder().setJobId("failed").setExecutionId("failed").build(),Profile.getDefaultInstance(),"",1,true));
            assertEquals("40001",failure.getSQLState());assertEquals(1,failure.getSuppressed().length);assertEquals(0,restores.get());
            assertThrows(SQLException.class,store::profiles);
        }
        try(var connection=DriverManager.getConnection("jdbc:sqlite:"+root.resolve("metadata.sqlite"));var statement=connection.createStatement();var rows=statement.executeQuery("SELECT count(*) FROM history")){assertTrue(rows.next());assertEquals(0,rows.getInt(1));}
    }
    @Test void failedRestorationPreservesAcknowledgedMetadataAndWriterLease()throws Exception {
        try(var store=new MetadataStore(root,connection->(Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
            if(method.getName().equals("setAutoCommit")&&Boolean.TRUE.equals(args[0]))throw new SQLException("restore fixture failure","08006");
            try{return method.invoke(connection,args);}catch(InvocationTargetException error){throw error.getCause();}
        }))){
            assertThrows(SQLException.class,()->store.started(JobInfo.newBuilder().setJobId("acknowledged").setExecutionId("one").build(),Profile.getDefaultInstance(),"",System.currentTimeMillis(),true));
            assertThrows(Exception.class,()->new MetadataStore(root));
            assertThrows(SQLException.class,store::profiles);
        }
        try(var store=new MetadataStore(root)){
            var history=store.history(HistoryRequest.getDefaultInstance());assertEquals(1,history.getEntriesCount());assertEquals(JobState.INTERRUPTED,history.getEntries(0).getState());
        }
    }
    @Test void profileLimitsPreservePreviouslySavedRecords()throws Exception {
        try(var store=new MetadataStore(root)){
            var profile=Profile.newBuilder().setId("existing").setName("Existing").build();store.save(profile);
            assertThrows(IllegalArgumentException.class,()->store.save(profile.toBuilder().setName("x".repeat(8192)).build()));
            assertEquals(profile,store.profiles().getFirst());
        }
    }
}
