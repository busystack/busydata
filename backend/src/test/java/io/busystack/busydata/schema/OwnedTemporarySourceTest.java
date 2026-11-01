package io.busystack.busydata.schema;
import java.io.*;
import java.sql.SQLException;
import java.util.concurrent.CancellationException;
import java.util.concurrent.atomic.AtomicInteger;
import io.busystack.busydata.rpc.WorkbenchFailure;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class OwnedTemporarySourceTest {
    @Test void exactAsciiByteLimitIsCompleteAndOverflowIsExplicit()throws Exception{String exact="x".repeat(65536);assertEquals(exact,OwnedTemporarySource.bounded(new StringReader(exact),()->{}));assertNull(OwnedTemporarySource.bounded(new StringReader(exact+"x"),()->{}));}
    @Test void utf16PairsAcrossReaderChunksKeepExactNativeText()throws Exception{String exact="x".repeat(4095)+"🙂"+"y".repeat(65536-4095-4);assertEquals(65536,exact.getBytes(java.nio.charset.StandardCharsets.UTF_8).length);assertEquals(exact,OwnedTemporarySource.bounded(new StringReader(exact),()->{}));assertNull(OwnedTemporarySource.bounded(new StringReader(exact+"x"),()->{}));}
    @Test void cancellationStopsBeforeMaterializingTheDocument(){var checks=new AtomicInteger();assertThrows(CancellationException.class,()->OwnedTemporarySource.bounded(new StringReader("x".repeat(200000)),()->{if(checks.incrementAndGet()==1)throw new CancellationException();}));assertEquals(1,checks.get());}
    @Test void malformedNativeEncodingIsNotSilentlyReplaced(){var invalid=assertThrows(SQLException.class,()->OwnedTemporarySource.bounded(new StringReader("x\ud800"),()->{}));assertEquals("22021",invalid.getSQLState());}
    @Test void transactionUnknownRetainsOriginalNativeCauseAndRedactsWire(){
        var nativeFailure=new SQLException("fixture private restore detail","HY000");
        var unknown=OwnedTemporarySource.transactionUnknown(nativeFailure);
        assertEquals(WorkbenchFailure.Reason.TRANSACTION_UNKNOWN,unknown.reason());assertSame(nativeFailure,unknown.getCause());
        var wire=unknown.asStatusRuntimeException();assertEquals(io.grpc.Status.Code.FAILED_PRECONDITION,wire.getStatus().getCode());
        assertEquals(WorkbenchFailure.Reason.TRANSACTION_UNKNOWN.wire(),wire.getTrailers().get(io.grpc.Metadata.Key.of(WorkbenchFailure.TRAILER,io.grpc.Metadata.ASCII_STRING_MARSHALLER)));
        assertFalse(wire.getStatus().getDescription().contains("private restore"));
    }
    @Test void nestedUnknownPreservesSameFailureAndSuppressedCleanup(){
        var nativeFailure=new SQLException("fixture private restore detail","HY000");
        var unknown=OwnedTemporarySource.transactionUnknown(nativeFailure);var cleanup=new SQLException("fixture private later cleanup","HY000");unknown.addSuppressed(cleanup);
        assertSame(unknown,OwnedTemporarySource.transactionUnknown(unknown),"A nested native envelope must preserve the first typed error");
        assertSame(nativeFailure,unknown.getCause());assertArrayEquals(new Throwable[]{cleanup},unknown.getSuppressed());
        assertFalse(unknown.asStatusRuntimeException().getStatus().getDescription().contains("private"));
    }
    @Test void unknownPhysicalOutcomeDoesNotPreserveOtherDefiniteReasons(){
        for(var reason:java.util.List.of(WorkbenchFailure.Reason.CANCELLED,WorkbenchFailure.Reason.STALE,WorkbenchFailure.Reason.DENIED)){
            var definite=new WorkbenchFailure(reason);var unknown=OwnedTemporarySource.transactionUnknown(definite);
            assertNotSame(definite,unknown);assertEquals(WorkbenchFailure.Reason.TRANSACTION_UNKNOWN,unknown.reason());assertSame(definite,unknown.getCause());
        }
    }
}
