package io.busystack.busydata;

import io.busystack.busydata.protocol.WorkbenchGrpc;
import io.busystack.busydata.rpc.LaunchAdmission;
import io.grpc.*;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class LaunchAdmissionTest {
    static final String SECRET="b".repeat(64);
    static class Call<Req,Resp> extends ServerCall<Req,Resp>{
        final MethodDescriptor<Req,Resp> method;Status status;Metadata trailers;
        Call(MethodDescriptor<Req,Resp> method){this.method=method;}
        public void request(int count){} public void sendHeaders(Metadata headers){} public void sendMessage(Resp message){}
        public void close(Status status,Metadata trailers){this.status=status;this.trailers=trailers;}
        public boolean isCancelled(){return false;} public MethodDescriptor<Req,Resp> getMethodDescriptor(){return method;}
    }
    Metadata headers(){var headers=new Metadata();headers.put(Metadata.Key.of("x-busydata-launch",Metadata.ASCII_STRING_MARSHALLER),SECRET);return headers;}
    @Test void blockedAnalysisDoesNotDenyExplicitExecutionOrCancellationAndReleasesExactlyOnce(){
        var admission=new LaunchAdmission(SECRET);
        var analyze=new Call<>(WorkbenchGrpc.getCompleteSqlMethod());
        var heldAnalyze=new AtomicReference<ServerCall<io.busystack.busydata.protocol.AnalysisRequest,io.busystack.busydata.protocol.Analysis>>();
        var analysisListener=admission.interceptCall(analyze,headers(),(call,h)->{heldAnalyze.set(call);return new ServerCall.Listener<>(){};});
        assertNotNull(heldAnalyze.get());
        var second=new Call<>(WorkbenchGrpc.getCompleteSqlMethod());
        admission.interceptCall(second,headers(),(call,h)->{fail("Second analysis exceeded its reservation");return null;});
        assertEquals(Status.Code.RESOURCE_EXHAUSTED,second.status.getCode());
        var execute=new Call<>(WorkbenchGrpc.getExecuteMethod());
        var heldExecute=new AtomicReference<ServerCall<io.busystack.busydata.protocol.ExecuteRequest,io.busystack.busydata.protocol.JobInfo>>();
        var executionListener=admission.interceptCall(execute,headers(),(call,h)->{heldExecute.set(call);return new ServerCall.Listener<>(){};});
        assertNotNull(heldExecute.get());
        var cancel=new Call<>(WorkbenchGrpc.getCancelMethod());
        admission.interceptCall(cancel,headers(),(call,h)->{call.close(Status.OK,new Metadata());return new ServerCall.Listener<>(){};});
        assertEquals(Status.Code.OK,cancel.status.getCode());
        heldAnalyze.get().close(Status.OK,new Metadata());analysisListener.onComplete();analysisListener.onCancel();
        heldExecute.get().close(Status.OK,new Metadata());executionListener.onCancel();executionListener.onComplete();
        var next=new Call<>(WorkbenchGrpc.getCompleteSqlMethod());
        admission.interceptCall(next,headers(),(call,h)->new ServerCall.Listener<>(){});
        assertNull(next.status);
        var overflow=new Call<>(WorkbenchGrpc.getCompleteSqlMethod());
        admission.interceptCall(overflow,headers(),(call,h)->{fail("Duplicate release inflated admission");return null;});
        assertEquals(Status.Code.RESOURCE_EXHAUSTED,overflow.status.getCode());
        assertEquals("concurrency",overflow.trailers.get(Metadata.Key.of("busydata-rpc-rejection",Metadata.ASCII_STRING_MARSHALLER)));
    }
    @Test void latencySensitiveLanguageOperationsHaveIndependentBoundedReservations(){
        var admission=new LaunchAdmission(SECRET);
        for(var method:java.util.List.of(WorkbenchGrpc.getCompleteSqlMethod(),WorkbenchGrpc.getDiagnoseSqlMethod(),WorkbenchGrpc.getSqlParameterInformationMethod(),WorkbenchGrpc.getFormatSqlMethod(),WorkbenchGrpc.getResolveSqlSymbolMethod(),WorkbenchGrpc.getSqlDdlImpactMethod())) {
            var call=new Call<>(method);admission.interceptCall(call,headers(),(held,h)->new ServerCall.Listener<>(){});assertNull(call.status);
            var overflow=new Call<>(method);admission.interceptCall(overflow,headers(),(held,h)->{fail("Language operation exceeded its own reservation");return null;});assertEquals(Status.Code.RESOURCE_EXHAUSTED,overflow.status.getCode());
        }
    }
    @Test void acknowledgedReviewAdmitsTheNextCommandBeforeItsTransportCloseReturns(){
        var admission=new LaunchAdmission(SECRET);
        var next=new Call<>(WorkbenchGrpc.getExecuteMethod());
        var review=new Call<>(WorkbenchGrpc.getReviewMethod()){
            @Override public void close(Status status,Metadata trailers){
                super.close(status,trailers);
                admission.interceptCall(next,headers(),(call,h)->new ServerCall.Listener<>(){});
                assertNull(next.status,"A client receiving terminal review acknowledgement can submit once");
            }
        };
        admission.interceptCall(review,headers(),(call,h)->{
            call.close(Status.OK,new Metadata());return new ServerCall.Listener<>(){};
        });
        var overflow=new Call<>(WorkbenchGrpc.getExecuteMethod());
        admission.interceptCall(overflow,headers(),(call,h)->{fail("The command reservation is still exactly one");return null;});
        assertEquals(Status.Code.RESOURCE_EXHAUSTED,overflow.status.getCode());
    }
    @Test void handlerFailureAndUnauthenticatedCallsCannotLeakOrAcquirePermits(){
        var admission=new LaunchAdmission(SECRET);
        var denied=new Call<>(WorkbenchGrpc.getExecuteMethod());
        admission.interceptCall(denied,new Metadata(),(call,h)->{fail("Unauthenticated handler reached");return null;});
        assertEquals(Status.Code.UNAUTHENTICATED,denied.status.getCode());
        assertThrows(IllegalStateException.class,()->admission.interceptCall(new Call<>(WorkbenchGrpc.getExecuteMethod()),headers(),(call,h)->{throw new IllegalStateException("fixture");}));
        var available=new Call<>(WorkbenchGrpc.getExecuteMethod());
        admission.interceptCall(available,headers(),(call,h)->{call.close(Status.OK,new Metadata());return new ServerCall.Listener<>(){};});
        assertEquals(Status.Code.OK,available.status.getCode());
    }
}
