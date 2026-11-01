package io.busystack.busydata.schema;

import io.busystack.busydata.analysis.LexicalSettings;
import io.busystack.busydata.metadata.*;
import io.busystack.busydata.protocol.Engine;
import java.io.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.SQLException;
import java.util.*;
import java.util.concurrent.CancellationException;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class NativeTableDefinitionTest {
    private static String renderer(Engine engine){return engine==Engine.MYSQL?"quote=1;gipk=1":"quote=1;gipk=N/A";}
    private static NativeTableHeader.Observation read(String text,Engine engine,String mode)throws Exception{return NativeTableHeader.observe(new StringReader(text),engine,LexicalSettings.mysql(mode),mode,renderer(engine),()->{});}
    private static String digest(String value)throws Exception{return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));}
    @Test void fullBodyBeyondHeaderBudgetDeterminesTheDigest()throws Exception{
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){
            String head="CREATE TEMPORARY TABLE `t` (`n` text COMMENT '"+"x".repeat(5000),first=head+"a')",second=head+"b')";
            var before=read(first,engine,"");var after=read(second,engine,"");assertEquals("t",before.header().name());assertEquals(MetadataState.AVAILABLE,before.header().nameAvailability());assertTrue(before.definition().complete());assertEquals(digest(first),before.definition().sha256());assertEquals(first.getBytes(StandardCharsets.UTF_8).length,before.definition().bytes());assertNotEquals(before.definition().sha256(),after.definition().sha256());assertEquals(NativeDefinitionEvidence.PROVENANCE,before.definition().provenance());
        }
    }
    @Test void exactUtf8ScalarsAcrossChunksAreHashedWithoutReplacement()throws Exception{
        String header="CREATE TEMPORARY TABLE `t` (`n` text COMMENT '",value=header+"x".repeat(4095-header.length())+"🙂é中')";
        var observed=read(value,Engine.MYSQL,"NO_BACKSLASH_ESCAPES");assertEquals(digest(value),observed.definition().sha256());assertEquals(value.getBytes(StandardCharsets.UTF_8).length,observed.definition().bytes());
    }
    private static Reader boundedAscii(long size,AtomicInteger closes){
        String header="CREATE TEMPORARY TABLE `t` (`n` text COMMENT '";
        return new Reader(){long at;@Override public int read(char[] buffer,int offset,int length){if(at==size)return -1;int count=(int)Math.min(length,size-at);for(int i=0;i<count;i++,at++)buffer[offset+i]=at<header.length()?header.charAt((int)at):at==size-2?'\'':at==size-1?')':'x';return count;}@Override public void close(){closes.incrementAndGet();}};
    }
    @Test void exactEightMiBIsDrainedAndOneExtraByteNeverReturnsEvidence()throws Exception{
        var closed=new AtomicInteger();try(var reader=boundedAscii(NativeTableHeader.MAX_CELL_BYTES,closed)){var value=NativeTableHeader.observe(reader,Engine.MYSQL,LexicalSettings.DEFAULT,"",renderer(Engine.MYSQL),()->{});assertTrue(value.definition().complete());assertEquals(NativeTableHeader.MAX_CELL_BYTES,value.definition().bytes());}assertEquals(1,closed.get());
        try(var reader=boundedAscii(NativeTableHeader.MAX_CELL_BYTES+1,closed)){var limited=assertThrows(SQLException.class,()->NativeTableHeader.observe(reader,Engine.MYSQL,LexicalSettings.DEFAULT,"",renderer(Engine.MYSQL),()->{}));assertEquals("54000",limited.getSQLState());}assertEquals(2,closed.get());
    }
    @Test void cancellationAndMalformedUtf16CannotProduceAnyObservation(){
        var checks=new AtomicInteger();assertThrows(CancellationException.class,()->NativeTableHeader.observe(new StringReader("CREATE TEMPORARY TABLE t(n text)"+"x".repeat(9000)),Engine.MYSQL,LexicalSettings.DEFAULT,"",renderer(Engine.MYSQL),()->{if(checks.incrementAndGet()==2)throw new CancellationException();}));
        for(String suffix:List.of("\ud800","\udc00","\ud800x")){var invalid=assertThrows(SQLException.class,()->read("CREATE TEMPORARY TABLE t(n text)"+suffix,Engine.MYSQL,""));assertEquals("22021",invalid.getSQLState());}
    }
    @Test void completeHeadersDoNotPromoteOmittedNativeOptionsToFullEvidence()throws Exception{
        for(String mode:List.of("NO_FIELD_OPTIONS","NO_KEY_OPTIONS","NO_TABLE_OPTIONS","MYSQL323","MYSQL40","ANSI","ORACLE","POSTGRESQL","MSSQL","DB2","MAXDB")){
            var observed=read("CREATE TEMPORARY TABLE `t` (`n` int)",Engine.MARIADB,mode);assertEquals(MetadataState.AVAILABLE,observed.header().nameAvailability());assertEquals(MetadataState.PARTIAL,observed.definition().availability());assertTrue(observed.definition().sha256().isEmpty());assertFalse(observed.definition().complete());
        }
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB)){var observed=read("CREATE TEMPORARY TABLE \"t\" (\"n\" int)",engine,"ANSI_QUOTES");assertEquals("t",observed.header().name());assertTrue(observed.definition().complete());}
        for(var engine:List.of(Engine.MYSQL,Engine.MARIADB))for(String mode:List.of("ANSI","NO_DIR_IN_CREATE")){var partial=read("CREATE TEMPORARY TABLE `t` (`n` int)",engine,mode);assertEquals(MetadataState.PARTIAL,partial.definition().availability());assertTrue(partial.definition().sha256().isEmpty());}
        var hidden=NativeTableHeader.observe(new StringReader("CREATE TEMPORARY TABLE `t` (`n` int)"),Engine.MYSQL,LexicalSettings.DEFAULT,"","quote=1;gipk=0",()->{});assertEquals(MetadataState.PARTIAL,hidden.definition().availability());assertTrue(hidden.definition().sha256().isEmpty());
    }
    @Test void unavailableNamesAndUnknownRendererNeverExposeAPrefixHash()throws Exception{
        var cut=read("CREATE TEMPORARY TABLE `"+"x".repeat(3000),Engine.MYSQL,"");assertEquals(MetadataState.LIMITED,cut.header().nameAvailability());assertFalse(cut.definition().complete());assertTrue(cut.definition().sha256().isEmpty());
        var unknown=NativeTableHeader.observe(new StringReader("CREATE TEMPORARY TABLE `t` (n int)"),Engine.MYSQL,LexicalSettings.DEFAULT,"","",()->{});assertEquals(MetadataState.AVAILABLE,unknown.header().nameAvailability());assertFalse(unknown.definition().complete());assertTrue(unknown.definition().sha256().isEmpty());
        assertThrows(IllegalArgumentException.class,()->new NativeDefinitionEvidence(MetadataState.PARTIAL,"a".repeat(64),100,"","quote=1;gipk=N/A",NativeDefinitionEvidence.PROVENANCE));
        var complete=read("CREATE TEMPORARY TABLE `t` (n int)",Engine.MARIADB,"").definition();assertEquals(complete,NativeDefinitionEvidence.from(complete.properties()));var corrupted=new HashMap<>(complete.properties());corrupted.put("nativeDefinitionProvenance","prefix");assertFalse(NativeDefinitionEvidence.from(corrupted).complete());assertTrue(NativeDefinitionEvidence.from(corrupted).sha256().isEmpty());
    }
}
