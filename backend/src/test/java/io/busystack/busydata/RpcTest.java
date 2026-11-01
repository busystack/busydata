package io.busystack.busydata;

import com.google.gson.*;
import io.busystack.busydata.protocol.*;
import io.grpc.*;
import io.grpc.netty.shaded.io.grpc.netty.*;
import io.grpc.stub.MetadataUtils;
import java.io.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class RpcTest {
 @TempDir Path root;
 private ProcessBuilder child(){
  // Child JVMs do not inherit the parent JVM's java.io.tmpdir property. Keep
  // SQLite JNI / TLS extraction inside the same test-owned Maven directory,
  // established before either VM initializes its temporary-file machinery.
  return new ProcessBuilder(Path.of(System.getProperty("java.home"),"bin","java").toString(),
      "--enable-native-access=ALL-UNNAMED","-Djava.io.tmpdir="+System.getProperty("java.io.tmpdir"),
      "-cp",System.getProperty("surefire.test.class.path"),Main.class.getName());
 }
 @Test void privateBootstrapTlsAuthenticationStaleHandlesAndParentPipeExit()throws Exception {
  var process=child().start();
  Thread.ofVirtual().start(()->{try{process.getErrorStream().transferTo(OutputStream.nullOutputStream());}catch(IOException ignored){}});
  ManagedChannel channel=null;
  try {
   String secret="a".repeat(64);var bootstrap=new JsonObject();bootstrap.addProperty("secret",secret);bootstrap.addProperty("parentPid",ProcessHandle.current().pid());bootstrap.addProperty("supportDirectory",root.toString());
   var input=new PrintWriter(process.getOutputStream(),true);input.println(bootstrap);
   var output=new BufferedReader(new InputStreamReader(process.getInputStream()));
   String ready=CompletableFuture.supplyAsync(()->{try{return output.readLine();}catch(IOException e){throw new RuntimeException(e);}}).get(30,TimeUnit.SECONDS);
   assertNotNull(ready);var data=JsonParser.parseString(ready).getAsJsonObject();assertFalse(ready.contains(secret));
   assertTrue(data.has("certificatePem"),()->"Private child startup failed: "+data.get("errorCode"));
   var duplicate=child().redirectError(ProcessBuilder.Redirect.DISCARD).start();
   try{new PrintWriter(duplicate.getOutputStream(),true).println(bootstrap);String failure=new BufferedReader(new InputStreamReader(duplicate.getInputStream())).readLine();assertEquals("BACKEND_STARTUP_METADATA",JsonParser.parseString(failure).getAsJsonObject().get("errorCode").getAsString());assertFalse(failure.contains(secret));assertTrue(duplicate.waitFor(5,TimeUnit.SECONDS));assertEquals(1,duplicate.exitValue());}finally{duplicate.destroyForcibly();}
   var ssl=GrpcSslContexts.forClient().trustManager(new ByteArrayInputStream(data.get("certificatePem").getAsString().getBytes(java.nio.charset.StandardCharsets.UTF_8))).build();
   channel=NettyChannelBuilder.forAddress("127.0.0.1",data.get("port").getAsInt()).sslContext(ssl).disableRetry().build();
   assertEquals(ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber(),data.get("protocolVersion").getAsInt());
   var c=io.busystack.busydata.protocol.Context.newBuilder().setInstanceId(data.get("instanceId").getAsString()).setRequestId("request").setProtocolVersion(ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber()).build();
   var unauthenticated=WorkbenchGrpc.newBlockingStub(channel).withDeadlineAfter(5,TimeUnit.SECONDS);
   assertEquals(Status.Code.UNAUTHENTICATED,assertThrows(StatusRuntimeException.class,()->unauthenticated.ping(c)).getStatus().getCode());
   var headers=new Metadata();headers.put(Metadata.Key.of("x-busydata-launch",Metadata.ASCII_STRING_MARSHALLER),secret);
   var client=WorkbenchGrpc.newBlockingStub(channel).withInterceptors(MetadataUtils.newAttachHeadersInterceptor(headers)).withDeadlineAfter(5,TimeUnit.SECONDS);
   assertEquals(c.getInstanceId(),client.ping(c).getInstanceId());
   var stats=client.runtimeStats(c);assertEquals(c.getInstanceId(),stats.getInstanceId());assertTrue(stats.getJavaVersion().startsWith("25."));assertFalse(stats.getGarbageCollectorsList().isEmpty());assertEquals(0,stats.getPhysicalSessions());
   assertEquals(Status.Code.UNAUTHENTICATED,assertThrows(StatusRuntimeException.class,()->unauthenticated.capabilities(CapabilityRequest.newBuilder().setContext(c).build())).getStatus().getCode());
   var unrelated=io.busystack.busydata.security.LaunchTls.create();
   var wrongTrust=NettyChannelBuilder.forAddress("127.0.0.1",data.get("port").getAsInt()).sslContext(GrpcSslContexts.forClient().trustManager(new ByteArrayInputStream(unrelated.pem().getBytes(java.nio.charset.StandardCharsets.UTF_8))).build()).disableRetry().build();
   try{assertEquals(Status.Code.UNAVAILABLE,assertThrows(StatusRuntimeException.class,()->WorkbenchGrpc.newBlockingStub(wrongTrust).withDeadlineAfter(3,TimeUnit.SECONDS).ping(c)).getStatus().getCode());}finally{wrongTrust.shutdownNow();}
   var wrongHost=NettyChannelBuilder.forAddress("127.0.0.1",data.get("port").getAsInt()).overrideAuthority("wrong-host.invalid").sslContext(ssl).disableRetry().build();
   try{assertEquals(Status.Code.UNAVAILABLE,assertThrows(StatusRuntimeException.class,()->WorkbenchGrpc.newBlockingStub(wrongHost).withDeadlineAfter(3,TimeUnit.SECONDS).ping(c)).getStatus().getCode());}finally{wrongHost.shutdownNow();}
   assertEquals(Status.Code.FAILED_PRECONDITION,assertThrows(StatusRuntimeException.class,()->client.ping(c.toBuilder().setInstanceId("old").build())).getStatus().getCode());
   for(int incompatible:new int[]{0,1,ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber()-1,ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber()+1})assertEquals(Status.Code.FAILED_PRECONDITION,assertThrows(StatusRuntimeException.class,()->client.ping(c.toBuilder().setProtocolVersion(incompatible).build())).getStatus().getCode());
   assertEquals(Status.Code.FAILED_PRECONDITION,assertThrows(StatusRuntimeException.class,()->client.capabilities(CapabilityRequest.newBuilder().setContext(c.toBuilder().setInstanceId("old")).build())).getStatus().getCode());
   assertEquals(Status.Code.INVALID_ARGUMENT,assertThrows(StatusRuntimeException.class,()->client.profiles(ProfileRequest.newBuilder().setContext(c).setAction(ProfileAction.SAVE_PROFILE).build())).getStatus().getCode());
   process.getOutputStream().close();assertTrue(process.waitFor(10,TimeUnit.SECONDS));assertEquals(0,process.exitValue());
  }finally{if(channel!=null)channel.shutdownNow();process.destroyForcibly();}
 }
}
