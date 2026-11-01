package io.busystack.busydata.schema;

import io.busystack.busydata.metadata.MetadataSnapshot.PhysicalRelationKind;
import java.io.*;
import java.sql.SQLException;
import java.util.concurrent.CancellationException;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class PhysicalRelationClassificationTest {
    @Test void nativeHeadersDistinguishPhysicalTemporaryAndPermanentTables()throws Exception {
        assertEquals(PhysicalRelationKind.PERSISTENT,kind("CREATE TABLE `TEMPORARY TABLE` (`id` int)"));
        assertEquals(PhysicalRelationKind.TEMPORARY,kind("CREATE TEMPORARY TABLE `t` (`id` int)"));
        assertEquals(PhysicalRelationKind.TEMPORARY,kind("CREATE OR REPLACE TEMPORARY TABLE `t` (`id` int)"));
        var view=NativeTableHeader.observe(new StringReader("CREATE ALGORITHM=UNDEFINED VIEW `t` AS SELECT 1"),io.busystack.busydata.protocol.Engine.MARIADB,io.busystack.busydata.analysis.LexicalSettings.DEFAULT,"","quote=1;gipk=N/A",()->{}).header();
        assertEquals(PhysicalRelationKind.PERSISTENT,view.kind());
        assertEquals(io.busystack.busydata.protocol.ObjectKind.VIEW,view.objectKind());
        assertNull(kind("/* CREATE TEMPORARY TABLE */ CREATE TABLE t(id int)"));
    }
    @Test void classificationDrainsLargeDefinitionsWithoutUsingTheSourceProjectionLimit()throws Exception {
        var reads=new AtomicInteger();String definition="CREATE TABLE `t` (`v` text DEFAULT '"+"x".repeat(100_000)+"')";
        assertEquals(PhysicalRelationKind.PERSISTENT,headerKind(new StringReader(definition),reads::incrementAndGet));
        assertTrue(reads.get()>20,"The native cell must be fully checked after recognizing its header");
    }
    @Test void validPrefixDoesNotHideLaterEncodingOrReadFailure() {
        var malformed=assertThrows(SQLException.class,()->kind("CREATE TABLE t(id int)"+"x".repeat(9000)+"\ud800"));
        assertEquals("22021",malformed.getSQLState());
        assertThrows(IOException.class,()->headerKind(new Reader(){boolean first=true;public int read(char[] buffer,int offset,int length)throws IOException{if(!first)throw new IOException("fixture read failed");first=false;String prefix="CREATE TABLE t(id int)";prefix.getChars(0,prefix.length(),buffer,offset);return prefix.length();}public void close(){}},()->{}));
    }
    @Test void cancellationAfterRecognizedHeaderNeverReturnsPhysicalEvidence() {
        var checks=new AtomicInteger();assertThrows(CancellationException.class,()->headerKind(new StringReader("CREATE TABLE t(id int)"+"x".repeat(20_000)),()->{if(checks.incrementAndGet()==2)throw new CancellationException();}));
        assertEquals(2,checks.get());
    }
    @Test void nativeCellReceiveBoundIsEnforcedWithoutRetainingItsBody() {
        assertThrows(SQLException.class,()->headerKind(new Reader(){long remaining=8_388_609;boolean header=true;public int read(char[] buffer,int offset,int length){if(remaining==0)return -1;int count=(int)Math.min(length,remaining);java.util.Arrays.fill(buffer,offset,offset+count,'x');if(header){String prefix="CREATE TABLE t(id int)";prefix.getChars(0,prefix.length(),buffer,offset);header=false;}remaining-=count;return count;}public void close(){}},()->{}));
    }
    @Test void generatedOperationsPreserveTheStructuredClassificationFailure(){
        for(var state:java.util.List.of(io.busystack.busydata.metadata.MetadataState.DENIED,io.busystack.busydata.metadata.MetadataState.TIMED_OUT,io.busystack.busydata.metadata.MetadataState.STALE,io.busystack.busydata.metadata.MetadataState.UNAVAILABLE,io.busystack.busydata.metadata.MetadataState.UNSUPPORTED)){
            var failure=assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->new OwnedTemporarySource.Classification(state,null).requirePersistent());
            assertEquals(state.name().toLowerCase(java.util.Locale.ROOT),failure.reason().wire());
            var proof=io.busystack.busydata.metadata.RetainedMetadataProof.unavailable(state,"Fixture unavailable observation");assertEquals(state,proof.state());assertFalse(proof.capturedStructure());
        }
        assertEquals(io.busystack.busydata.rpc.WorkbenchFailure.Reason.STALE,assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->new OwnedTemporarySource.Classification(io.busystack.busydata.metadata.MetadataState.AVAILABLE,PhysicalRelationKind.ABSENT).requirePersistent()).reason());
        assertEquals(io.busystack.busydata.rpc.WorkbenchFailure.Reason.UNSUPPORTED,assertThrows(io.busystack.busydata.rpc.WorkbenchFailure.class,()->new OwnedTemporarySource.Classification(io.busystack.busydata.metadata.MetadataState.AVAILABLE,PhysicalRelationKind.TEMPORARY).requirePersistent()).reason());
        assertThrows(IllegalArgumentException.class,()->io.busystack.busydata.metadata.RetainedMetadataProof.unavailable(io.busystack.busydata.metadata.MetadataState.AVAILABLE,"Invalid availability"));
    }
    private static PhysicalRelationKind headerKind(Reader reader,OwnedTemporarySource.Check check)throws Exception{return NativeTableHeader.observe(reader,io.busystack.busydata.protocol.Engine.MARIADB,io.busystack.busydata.analysis.LexicalSettings.DEFAULT,"","quote=1;gipk=N/A",check).header().kind();}
    private static PhysicalRelationKind kind(String text)throws Exception{return headerKind(new StringReader(text),()->{});}
}
