package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.rpc.WorkbenchFailure;
import io.busystack.busydata.schema.RelatedRows;
import java.lang.reflect.*;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.concurrent.CancellationException;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

/** Real engine/session. Only public Connection-entry counts are observed;
 * no claim covers autonomous driver/server work. Invalid owners never reach
 * the deliberately absent retained result, witness or catalog acquisition. */
class RelatedRowsOwnershipIT {
    @TempDir Path root;
    private static void reason(RelatedRows related,io.busystack.busydata.sessions.SessionRegistry.Session session,RelatedRowsRequest request,WorkbenchFailure.Reason expected){assertEquals(expected,assertThrows(WorkbenchFailure.class,()->related.list(session,request)).reason());}
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void supersededMalformedAndCancelledOwnersRejectBeforeJdbcOrRetainedAccess(String engine)throws Exception{
        var calls=new AtomicInteger();
        try(var fixture=new EngineFixture(root,engine,(adapter,request,port)->{
            var physical=adapter.connect(request,port);
            return (Connection)Proxy.newProxyInstance(Connection.class.getClassLoader(),new Class[]{Connection.class},(proxy,method,args)->{
                calls.incrementAndGet();try{return method.invoke(physical,args);}catch(InvocationTargetException failure){throw failure.getCause();}
            });
        })){
            var owner=fixture.open();var related=new RelatedRows(fixture.metadata.metadataPlatform(),fixture.results);
            long revision=owner.revision,context=owner.contextRevision;int before=calls.get();
            var missing=RelatedRowsRequest.newBuilder().setSessionId(owner.id).setDocumentId("owned-related-document").setResultId("deliberately-absent-result").build();
            var current=RelatedRowsTestRequests.capture(owner,missing);
            reason(related,owner,missing,WorkbenchFailure.Reason.MALFORMED_REQUEST);
            reason(related,owner,current.toBuilder().clearExpectedContextRevision().build(),WorkbenchFailure.Reason.MALFORMED_REQUEST);
            reason(related,owner,current.toBuilder().clearExpectedSessionRevision().build(),WorkbenchFailure.Reason.MALFORMED_REQUEST);
            reason(related,owner,current.toBuilder().setExpectedSessionRevision(revision+1).build(),WorkbenchFailure.Reason.INVALID_REVISION);
            reason(related,owner,current.toBuilder().setExpectedContextRevision(context+1).build(),WorkbenchFailure.Reason.INVALID_REVISION);
            reason(related,owner,current.toBuilder().setExpectedSessionRevision(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST);
            reason(related,owner,current.toBuilder().setExpectedContextRevision(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST);
            reason(related,owner,current.toBuilder().setSnapshotRevision(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST);
            reason(related,owner,current.toBuilder().setSourceRow(-1L).build(),WorkbenchFailure.Reason.MALFORMED_REQUEST);
            reason(related,owner,current.toBuilder().setSessionId("another-physical-owner").build(),WorkbenchFailure.Reason.INVALID_OWNER);
            try(var cancelled=io.grpc.Context.current().withCancellation()){
                cancelled.cancel(null);cancelled.run(()->assertThrows(CancellationException.class,()->related.list(owner,current)));
            }
            Thread.currentThread().interrupt();
            try{assertThrows(CancellationException.class,()->related.list(owner,current));assertTrue(Thread.currentThread().isInterrupted());}finally{Thread.interrupted();}
            assertEquals(before,calls.get(),"Owner admission must not enter the public JDBC connection");assertEquals(revision,owner.revision);assertEquals(context,owner.contextRevision);assertTrue(fixture.jobs.list(owner.id).isEmpty());
            owner.quarantine(new java.sql.SQLException("Injected unknown owner", "08006"));
            int afterPhysicalClose=calls.get();
            reason(related,owner,RelatedRowsTestRequests.capture(owner,current),WorkbenchFailure.Reason.TRANSACTION_UNKNOWN);
            assertEquals(afterPhysicalClose,calls.get(),"Known transaction uncertainty must be reported without entering JDBC again");
        }
    }
}
