package io.busystack.busydata;

import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.rpc.WorkbenchService;
import io.busystack.busydata.security.LaunchTls;
import io.grpc.*;
import io.grpc.netty.shaded.io.grpc.netty.*;
import com.google.gson.*;
import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;

public final class Main {
    private static String startupStage="BOOTSTRAP";
    public static void main(String[] args) {
        try{run(args);}catch(Exception error){var failure=new JsonObject();failure.addProperty("errorCode",startupStage.equals("SHUTDOWN")?"BACKEND_SHUTDOWN_CLEANUP":"BACKEND_STARTUP_"+startupStage);System.out.println(failure);System.out.flush();System.exit(1);}
    }
    private static void run(String[] args)throws Exception {
        if(args.length!=0)throw new IllegalArgumentException("Bootstrap uses private inherited pipes, no arguments");
        var input=new BufferedReader(new InputStreamReader(System.in,StandardCharsets.UTF_8));String line=boundedLine(input);
        if(line==null)throw new IllegalArgumentException("Bootstrap pipe closed");
        var bootstrap=JsonParser.parseString(line).getAsJsonObject();String token=bootstrap.get("secret").getAsString();
        if(token.length()!=64||!token.matches("[0-9a-f]+"))throw new IllegalArgumentException("Invalid launch secret");
        long parent=bootstrap.get("parentPid").getAsLong();var process=ProcessHandle.of(parent).orElseThrow();if(!process.isAlive())return;
        Path support=Path.of(bootstrap.get("supportDirectory").getAsString());if(!support.isAbsolute())throw new IllegalArgumentException("Absolute support path required");
        startupStage="METADATA";
        var metadata=new MetadataStore(support);startupStage="PRIVATE_STORAGE";var temporaryFiles=new io.busystack.busydata.security.PrivateTemporaryFiles(support.resolve("credential-scratch"));var results=new ResultStore(support,1024L*1024*1024);var analysis=new SqlAnalysis();var safety=new Safety(analysis);var sshTrust=new io.busystack.busydata.security.SshTrust(metadata,safety,temporaryFiles);var sessions=new SessionRegistry(temporaryFiles,(adapter,request,port)->adapter.connect(request,port),sshTrust,metadata::metadataSourceIdentity);var jobs=new Jobs(results,metadata,analysis,safety);
        var closing=new AtomicBoolean();var serverRef=new AtomicReference<Server>();var ended=new CountDownLatch(1);
        var cleanupFailure=new AtomicReference<Throwable>();
        Runnable close=()->{if(!closing.compareAndSet(false,true))return;var server=serverRef.get();
            try{if(server!=null)server.shutdown();}catch(Exception failure){retainCleanup(cleanupFailure,failure);}
            closeResource(jobs,cleanupFailure);closeResource(sessions,cleanupFailure);closeResource(results,cleanupFailure);closeResource(metadata,cleanupFailure);
            try{if(server!=null)server.shutdownNow();}catch(Exception failure){retainCleanup(cleanupFailure,failure);}finally{ended.countDown();}
        };
        Runtime.getRuntime().addShutdownHook(new Thread(close));
        startupStage="TLS";var tls=LaunchTls.create();var ssl=GrpcSslContexts.configure(io.grpc.netty.shaded.io.netty.handler.ssl.SslContextBuilder.forServer(tls.key(),tls.certificate())).build();
        var executor=Executors.newVirtualThreadPerTaskExecutor();
        var service=new WorkbenchService(sessions,jobs,results,metadata,safety,analysis,close,sshTrust);
        var auth=new io.busystack.busydata.rpc.LaunchAdmission(token);
        startupStage="LISTENER";var server=NettyServerBuilder.forAddress(new InetSocketAddress(InetAddress.getByName("127.0.0.1"),0)).sslContext(ssl).executor(executor).maxConcurrentCallsPerConnection(40).maxInboundMessageSize(16*1024*1024).addService(ServerInterceptors.intercept(io.busystack.busydata.rpc.RequestLimits.bind(service.bindService()),auth)).build().start();serverRef.set(server);
        var ready=new JsonObject();ready.addProperty("port",server.getPort());ready.addProperty("instanceId",service.instance);ready.addProperty("protocolVersion",WorkbenchService.PROTOCOL);ready.addProperty("version","0.1.0");ready.addProperty("certificatePem",tls.pem());
        System.out.println(ready);System.out.flush();
        process.onExit().thenRun(close);
        startInputMonitor(input,close);
        ended.await();executor.shutdownNow();startupStage="SHUTDOWN";if(cleanupFailure.get()!=null)throw new IllegalStateException("Backend resource cleanup failed",cleanupFailure.get());
    }
    static Thread startInputMonitor(Reader input,Runnable close){
        // The blocking parent pipe must not occupy a virtual-thread carrier
        // needed by status and cancellation RPCs while a result is spooling.
        return Thread.ofPlatform().daemon(true).name("busydata-parent-input").start(()->{try{while(boundedLine(input)!=null){} }catch(Exception ignored){}finally{close.run();}});
    }
    private static void closeResource(AutoCloseable resource,AtomicReference<Throwable> failure){try{resource.close();}catch(Exception cleanup){retainCleanup(failure,cleanup);}}
    private static void retainCleanup(AtomicReference<Throwable> failure,Throwable cleanup){var primary=failure.get();if(primary==null)failure.compareAndSet(null,cleanup);else primary.addSuppressed(cleanup);}
    private static String boundedLine(Reader r)throws IOException{var out=new StringBuilder();int c;while((c=r.read())!=-1){if(c=='\n')return out.toString();if(out.length()>=16_384)throw new IOException("Bootstrap too large");out.append((char)c);}return out.isEmpty()?null:out.toString();}
}
