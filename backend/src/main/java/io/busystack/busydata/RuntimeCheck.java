package io.busystack.busydata;
import java.sql.*;
import java.security.*;
import java.nio.charset.Charset;
import com.google.gson.Gson;
import java.util.*;
/** Packaging smoke test for JDBC/SQLite, crypto and actual verified SSH forwarding. */
public final class RuntimeCheck {
 public static void main(String[] args)throws Exception {
  var drivers=DriverManager.drivers().map(d->d.getClass().getName()).sorted().toList();
  if(drivers.size()!=4)throw new IllegalStateException("Expected four bundled JDBC drivers, including internal SQLite");
  try(var db=DriverManager.getConnection("jdbc:sqlite::memory:");var s=db.createStatement();var r=s.executeQuery("SELECT 25")){if(!r.next()||r.getInt(1)!=25)throw new IllegalStateException("SQLite JNI failed");}
  KeyPairGenerator.getInstance("EC");javax.net.ssl.SSLContext.getInstance("TLSv1.3");Charset.forName("windows-1252");
  verifySshRuntime();
  System.out.println(new Gson().toJson(Map.of("java",System.getProperty("java.runtime.version"),"drivers",drivers,"tls","TLSv1.3","sqliteNative",true,"sshHostReview",true,"sshVerifiedForwarding",true)));
 }

 static void verifySshRuntime()throws Exception {
  // This temporary loopback fixture belongs exclusively to the packaging
  // smoke command. Main never creates an SSH server or a public listener.
  var root=java.nio.file.Files.createTempDirectory("busydata-runtime-check-");
  io.busystack.busydata.results.ResultStore.privateDirectory(root);
  try(var echo=new java.net.ServerSocket(0,1,java.net.InetAddress.getByName("127.0.0.1"));
      var server=org.apache.sshd.server.SshServer.setUpDefaultServer();
      var metadata=new io.busystack.busydata.storage.MetadataStore(root)) {
   echo.setSoTimeout(10000);
   var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);var key=generator.generateKeyPair();
   server.setHost("127.0.0.1");server.setPort(0);server.setKeyPairProvider(context->List.of(key));
   server.setPasswordAuthenticator((user,password,session)->user.equals("runtime-check")&&password.equals("disposable-runtime-fixture"));
   server.setForwardingFilter(org.apache.sshd.server.forward.AcceptAllForwardingFilter.INSTANCE);server.start();
   var profile=io.busystack.busydata.protocol.Profile.newBuilder().setId("runtime-check")
       .setHost("127.0.0.1").setPort(echo.getLocalPort()).setConnectTimeoutSeconds(5)
       .setSsh(io.busystack.busydata.protocol.Ssh.newBuilder().setEnabled(true).setHost("127.0.0.1").setPort(server.getPort()).setUser("runtime-check")).build();
   var trust=new io.busystack.busydata.security.SshTrust(metadata,new io.busystack.busydata.safety.Safety(new io.busystack.busydata.analysis.SqlAnalysis()));
   var request=io.busystack.busydata.protocol.SshTrustRequest.newBuilder().setProfile(profile).build();
   var review=trust.review(request);
   if(review.getKnown()||review.getChanged()||!review.getFingerprint().equals(org.apache.sshd.common.config.keys.KeyUtils.getFingerPrint(key.getPublic())))throw new IllegalStateException("Runtime SSH host review failed");
   var approved=trust.accept(request.toBuilder().setApprovalToken(review.getApprovalToken()).setAlgorithm(review.getAlgorithm()).setFingerprint(review.getFingerprint()).build());
   profile=profile.toBuilder().setSsh(profile.getSsh().toBuilder().setTrustRef(approved.getTrustRef())).build();
   var returned=new java.util.concurrent.CompletableFuture<Integer>();
   var worker=Thread.ofVirtual().start(()->{try(var incoming=echo.accept()){incoming.setSoTimeout(5000);int value=incoming.getInputStream().read();incoming.getOutputStream().write(value);returned.complete(value);}catch(Exception failure){returned.completeExceptionally(failure);}});
   try(var tunnel=new io.busystack.busydata.security.SshTunnel(io.busystack.busydata.protocol.OpenRequest.newBuilder().setProfile(profile).setSshPassword("disposable-runtime-fixture").build(),trust.resolve(profile));
       var socket=new java.net.Socket("127.0.0.1",tunnel.port())) {
    socket.setSoTimeout(5000);socket.getOutputStream().write(25);
    if(socket.getInputStream().read()!=25||returned.get(5,java.util.concurrent.TimeUnit.SECONDS)!=25)throw new IllegalStateException("Runtime SSH forwarding failed");
   }finally{echo.close();worker.join(1000);if(worker.isAlive())throw new IllegalStateException("Runtime SSH fixture did not stop");}
  }finally {
   try(var paths=java.nio.file.Files.walk(root)){for(var path:paths.sorted(Comparator.reverseOrder()).toList())java.nio.file.Files.delete(path);}
  }
 }
}
