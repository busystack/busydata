package io.busystack.busydata.rpc;

import io.grpc.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Set;
import java.util.concurrent.Semaphore;
import java.util.concurrent.atomic.AtomicBoolean;

/** Authenticate before admitting work. Editor analysis cannot consume the user
 * command reservation, and neither can consume cancellation/control capacity. */
public final class LaunchAdmission implements ServerInterceptor {
    private static final Set<String> CONTROL=Set.of("Cancel","Jobs","Session","Shutdown","Ping","RuntimeStats");
    private final byte[] secret;
    private final Semaphore requests=new Semaphore(24),control=new Semaphore(8),commands=new Semaphore(1);
    private final java.util.Map<String,Semaphore> language=java.util.stream.Stream.of("CompleteSql","DiagnoseSql","SqlParameterInformation","FormatSql","ResolveSqlSymbol","SqlDdlImpact").collect(java.util.stream.Collectors.toUnmodifiableMap(name->name,name->new Semaphore(1)));
    public LaunchAdmission(String secret){this.secret=secret.getBytes(StandardCharsets.US_ASCII);}
    @Override public <Req,Resp> ServerCall.Listener<Req> interceptCall(ServerCall<Req,Resp> call,Metadata headers,ServerCallHandler<Req,Resp> next){
        String supplied=headers.get(Metadata.Key.of("x-busydata-launch",Metadata.ASCII_STRING_MARSHALLER));
        if(supplied==null||!MessageDigest.isEqual(secret,supplied.getBytes(StandardCharsets.US_ASCII))){call.close(Status.UNAUTHENTICATED,new Metadata());return new ServerCall.Listener<>(){};}
        String method=call.getMethodDescriptor().getBareMethodName();
        Semaphore capacity=language.containsKey(method)?language.get(method):RequestLimits.LARGE.contains(method)?commands:CONTROL.contains(method)?control:requests;
        if(!capacity.tryAcquire()){var trailers=new Metadata();trailers.put(Metadata.Key.of("busydata-rpc-rejection",Metadata.ASCII_STRING_MARSHALLER),"concurrency");call.close(Status.RESOURCE_EXHAUSTED.withDescription("RPC concurrency limit reached"),trailers);return new ServerCall.Listener<>(){};}
        var released=new AtomicBoolean();
        Runnable release=()->{if(released.compareAndSet(false,true))capacity.release();};
        var forwarded=new ForwardingServerCall.SimpleForwardingServerCall<Req,Resp>(call){
            @Override public void close(Status status,Metadata trailers){
                // Business work has completed. Release before publishing the
                // terminal acknowledgement: a client may immediately submit
                // its reviewed follow-on command on another transport thread.
                release.run();super.close(status,trailers);
            }
        };
        try{return new ForwardingServerCallListener.SimpleForwardingServerCallListener<Req>(next.startCall(forwarded,headers)){
            @Override public void onCancel(){try{super.onCancel();}finally{release.run();}}
            @Override public void onComplete(){try{super.onComplete();}finally{release.run();}}
        };}catch(RuntimeException|Error failure){release.run();throw failure;}
    }
}
