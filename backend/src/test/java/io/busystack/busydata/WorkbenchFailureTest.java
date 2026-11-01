package io.busystack.busydata;

import io.busystack.busydata.rpc.WorkbenchFailure;
import io.grpc.Metadata;
import java.util.*;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class WorkbenchFailureTest {
    @Test void everyAllowlistedFailureHasItsExactTypedReasonAndStatus(){
        var key=Metadata.Key.of("busydata-workbench-reason",Metadata.ASCII_STRING_MARSHALLER);var seen=new HashSet<String>();
        for(var reason:WorkbenchFailure.Reason.values()){
            var failure=new WorkbenchFailure(reason);var mapped=failure.asStatusRuntimeException();
            assertEquals(reason.status().getCode(),mapped.getStatus().getCode());assertEquals(reason.wire(),mapped.getTrailers().get(key));assertEquals(Optional.of(reason),WorkbenchFailure.Reason.parse(reason.wire()));assertTrue(seen.add(reason.wire()));assertEquals(reason,failure.reason());
        }
    }
    @Test void unknownReasonsAndHumanMessagesCannotBecomeTypedFailures(){
        for(String value:List.of("","INVALID_OWNER","invalid-owner","unknown","denied: secret","transaction_unknown\nsecret"))assertTrue(WorkbenchFailure.Reason.parse(value).isEmpty(),value);
        assertTrue(WorkbenchFailure.Reason.parse(null).isEmpty());
        var failure=new WorkbenchFailure(WorkbenchFailure.Reason.INVALID_OWNER);assertEquals("Workbench request failed: invalid_owner",failure.asStatusRuntimeException().getStatus().getDescription());assertNull(failure.getCause());
    }
    @Test void internalOriginCannotChangeTheWireReasonOrRetainOriginalFailureText(){
        var key=Metadata.Key.of(WorkbenchFailure.TRAILER,Metadata.ASCII_STRING_MARSHALLER);
        assertEquals(WorkbenchFailure.Origin.UNCLASSIFIED,new WorkbenchFailure(WorkbenchFailure.Reason.TIMED_OUT).origin());
        for(var origin:WorkbenchFailure.Origin.values()){
            var failure=new WorkbenchFailure(WorkbenchFailure.Reason.TIMED_OUT,origin);var wire=failure.asStatusRuntimeException();
            assertSame(origin,failure.origin());assertEquals(WorkbenchFailure.Reason.TIMED_OUT,failure.reason());
            assertEquals(io.grpc.Status.Code.DEADLINE_EXCEEDED,wire.getStatus().getCode());assertEquals("timed_out",wire.getTrailers().get(key));
            assertEquals(Set.of(WorkbenchFailure.TRAILER),wire.getTrailers().keys());assertEquals("Workbench request failed: timed_out",wire.getStatus().getDescription());
            assertNull(failure.getCause());assertEquals(0,failure.getSuppressed().length);
        }
    }

}
