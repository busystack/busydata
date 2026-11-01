package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.Engine;
import java.io.*;
import java.lang.reflect.Proxy;
import java.nio.charset.StandardCharsets;
import java.sql.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class NativeRoutineSourceTest {
    private static final class Counting extends ByteArrayInputStream {
        int consumed;Counting(byte[] bytes){super(bytes);}
        @Override public synchronized int read(byte[] bytes,int off,int len){int n=super.read(bytes,off,len);if(n>0)consumed+=n;return n;}
    }
    private static Statement statement(AtomicInteger cancelled){return (Statement)Proxy.newProxyInstance(Statement.class.getClassLoader(),new Class[]{Statement.class},(p,m,a)->{if(m.getName().equals("cancel")){cancelled.incrementAndGet();return null;}throw new AssertionError("Unexpected statement operation: "+m.getName());});}
    private static ResultSet rows(InputStream input,ResultSetMetaData metadata){return (ResultSet)Proxy.newProxyInstance(ResultSet.class.getClassLoader(),new Class[]{ResultSet.class},(p,m,a)->switch(m.getName()){case "getBinaryStream"->input;case "getMetaData"->metadata;default->throw new AssertionError("Unexpected row operation: "+m.getName());});}
    private static ResultSetMetaData mysqlCharset(String charset){return new com.mysql.cj.jdbc.result.ResultSetMetaData(null,new com.mysql.cj.result.Field[0],false,false,null){@Override public String getColumnCharacterEncoding(int column){return charset;}};}
    private static long deadline(){return System.nanoTime()+TimeUnit.SECONDS.toNanos(10);}
    private static <T> T warningComponent(Class<T> type,SQLWarning warning){return type.cast(Proxy.newProxyInstance(type.getClassLoader(),new Class[]{type},(p,m,a)->{if(m.getName().equals("getWarnings"))return warning;throw new AssertionError("Unexpected warning operation: "+m.getName());}));}
    private static void warnings(Engine engine,boolean function,SQLWarning rows,SQLWarning statement,SQLWarning connection)throws SQLException {NativeRoutineSource.checkWarnings(engine,warningComponent(Statement.class,statement),warningComponent(Connection.class,connection),warningComponent(ResultSet.class,rows),function);}
    @Test void byteLimitReadsOnlyOneExtraByteAndNeverReturnsTruncatedSource()throws Exception {
        var input=new Counting(new byte[10000]);var calls=new AtomicInteger();
        var source=NativeRoutineSource.readDefinitionField(Engine.MARIADB,statement(calls),rows(input,null),3,100,deadline());
        assertEquals(101,input.consumed);assertEquals(101,source.bytesRead());assertEquals(MetadataState.LIMITED,source.state());assertEquals("",source.text());assertFalse(source.available());assertEquals(0,calls.get());
    }
    @Test void sqlNullEmptyAndMalformedSourceAreDifferentOutcomes()throws Exception {
        var query=statement(new AtomicInteger());
        var absent=NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,rows(null,null),3,100,deadline());
        assertNull(absent.text());assertEquals(MetadataState.UNAVAILABLE,absent.state());
        var empty=NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,rows(new ByteArrayInputStream(new byte[0]),null),3,100,deadline());
        assertEquals("",empty.text());assertEquals(MetadataState.UNAVAILABLE,empty.state());
        var malformed=rows(new ByteArrayInputStream(new byte[]{(byte)0xc3}),null);
        assertEquals("HY000",assertThrows(SQLException.class,()->NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,malformed,3,100,deadline())).getSQLState());
    }
    @Test void mysqlUsesItsPublicColumnCharsetInsteadOfAssumingUtf8()throws Exception {
        var query=statement(new AtomicInteger());byte[] latin1={(byte)0xe9};
        var source=NativeRoutineSource.readDefinitionField(Engine.MYSQL,query,rows(new ByteArrayInputStream(latin1),mysqlCharset("windows-1252")),3,100,deadline());
        assertEquals("é",source.text());assertEquals(1,source.bytesRead());assertTrue(source.available());
        assertThrows(SQLException.class,()->NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,rows(new ByteArrayInputStream(latin1),null),3,100,deadline()));
        assertThrows(SQLFeatureNotSupportedException.class,()->NativeRoutineSource.readDefinitionField(Engine.MYSQL,query,rows(new ByteArrayInputStream(latin1),mysqlCharset("unavailable-charset")),3,100,deadline()));
    }
    @Test void utf8RetentionLimitAppliesAfterAnExactNativeCharsetDecode()throws Exception {
        var source=NativeRoutineSource.readDefinitionField(Engine.MYSQL,statement(new AtomicInteger()),rows(new ByteArrayInputStream(new byte[]{(byte)0xe9,(byte)0xe9}),mysqlCharset("windows-1252")),3,2,deadline());
        assertEquals(MetadataState.LIMITED,source.state());assertEquals(2,source.bytesRead());assertEquals("",source.text());
    }
    @Test void deadlineAndCancellationCancelOnlyTheOwnedStatementBeforeReading()throws Exception {
        var calls=new AtomicInteger();var input=new Counting(new byte[]{1});var query=statement(calls);
        assertThrows(SQLTimeoutException.class,()->NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,rows(input,null),3,100,0));
        assertEquals(0,input.consumed);assertEquals(1,calls.get());
        var cancelled=io.grpc.Context.current().withCancellation();var previous=cancelled.attach();
        try{cancelled.cancel(null);assertThrows(CancellationException.class,()->NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,rows(input,null),3,100,deadline()));}
        finally{cancelled.detach(previous);cancelled.close();}
        assertEquals(0,input.consumed);assertEquals(2,calls.get());
    }
    @Test void artifactBudgetIsExplicitAndCannotBeReusedAsIntrospectionEvidence()throws Exception {
        byte[] bytes="x".repeat(70000).getBytes(StandardCharsets.UTF_8);var query=statement(new AtomicInteger());
        var artifact=NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,rows(new ByteArrayInputStream(bytes),null),3,NativeRoutineSource.MAX_ARTIFACT_BYTES,deadline());
        assertTrue(artifact.available());assertEquals(70000,artifact.bytesRead());
        assertThrows(IllegalArgumentException.class,()->new NativeRoutineSource(artifact.text(),"",MetadataState.AVAILABLE,artifact.bytesRead()));
        assertThrows(IllegalArgumentException.class,()->NativeRoutineSource.readDefinitionField(Engine.MARIADB,query,rows(null,null),3,NativeRoutineSource.MAX_ARTIFACT_BYTES+1,deadline()));
    }
    @Test void mariaNativeFunctionNameCollisionNoteIsTheOnlyAcceptedWarning()throws Exception {
        warnings(Engine.MARIADB,true,new SQLWarning("fixture",null,1585),new SQLWarning("fixture","",1585),new SQLWarning("fixture",null,1585));
        for(var engine:new Engine[]{Engine.MYSQL,Engine.POSTGRESQL})assertEquals("01000",assertThrows(SQLException.class,()->warnings(engine,true,new SQLWarning("fixture",null,1585),null,null)).getSQLState());
        assertThrows(SQLException.class,()->warnings(Engine.MARIADB,false,new SQLWarning("fixture",null,1585),null,null),"Preflight and procedures must keep the strict policy");
        for(String state:new String[]{"01000","HY000"," "})assertThrows(SQLException.class,()->warnings(Engine.MARIADB,true,new SQLWarning("fixture",state,1585),null,null));
        warnings(Engine.MARIADB,false,null,null,null);
    }
    @Test void acceptedMariaNoteCannotHideAnotherWarningInAnyComponent()throws Exception {
        for(int component=0;component<3;component++){
            var accepted=new SQLWarning("fixture",null,1585);accepted.setNextWarning(new SQLWarning("fixture","01000",1265));var parts=new SQLWarning[3];parts[component]=accepted;
            assertEquals("01000",assertThrows(SQLException.class,()->warnings(Engine.MARIADB,true,parts[0],parts[1],parts[2])).getSQLState());
        }
        var invalid=new SQLWarning("fixture",null,1585);invalid.setNextException(new SQLException("fixture",null,1585));assertThrows(SQLException.class,()->warnings(Engine.MARIADB,true,invalid,null,null));
    }
    @Test void nativeWarningChainsHaveBoundedLengthAndRejectCycles()throws Exception {
        var cyclic=new SQLWarning("fixture",null,1585);cyclic.setNextWarning(cyclic);assertThrows(SQLException.class,()->warnings(Engine.MARIADB,true,cyclic,null,null));
        var head=new SQLWarning("fixture",null,1585);var tail=head;for(int i=1;i<32;i++){var next=new SQLWarning("fixture",null,1585);tail.setNextWarning(next);tail=next;}
        warnings(Engine.MARIADB,true,head,null,null);tail.setNextWarning(new SQLWarning("fixture",null,1585));assertThrows(SQLException.class,()->warnings(Engine.MARIADB,true,head,null,null));
    }
}
