package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.schema.RelatedRows;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.rpc.WorkbenchService;
import io.grpc.stub.StreamObserver;

/** Capture the actual current owner for each explicit test lookup; no retry. */
final class RelatedRowsTestRequests {
    private RelatedRowsTestRequests(){}
    static RelatedRowsRequest capture(SessionRegistry.Session owner,RelatedRowsRequest request){return request.toBuilder().setExpectedSessionRevision(owner.revision).setExpectedContextRevision(owner.contextRevision).build();}
    static RelatedRowsReply list(RelatedRows related,SessionRegistry.Session owner,RelatedRowsRequest request)throws Exception{return related.list(owner,capture(owner,request));}
    static void call(WorkbenchService service,SessionRegistry.Session owner,RelatedRowsRequest request,StreamObserver<RelatedRowsReply> reply){service.relatedRows(capture(owner,request),reply);}
}
