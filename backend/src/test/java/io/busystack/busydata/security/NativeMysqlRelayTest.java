package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import java.io.*;
import java.net.*;
import java.nio.channels.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;
import javax.net.ssl.SSLContext;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class NativeMysqlRelayTest {
    @TempDir Path root;
    private static byte[] greeting(boolean ssl) {
        byte[] bytes=new byte[60];bytes[0]=10;bytes[1]='8';bytes[2]=0;
        bytes[16]=2;bytes[17]=(byte)(ssl?8:0);return bytes;
    }
    private static void packet(OutputStream out,int sequence,byte[] bytes)throws IOException {int n=bytes.length;out.write(new byte[]{(byte)n,(byte)(n>>8),(byte)(n>>16),(byte)sequence});out.write(bytes);out.flush();}
    private static byte[] packet(InputStream in,int sequence)throws IOException {byte[] h=in.readNBytes(4);assertEquals(4,h.length);assertEquals(sequence,h[3]&255);int n=(h[0]&255)|((h[1]&255)<<8)|((h[2]&255)<<16);byte[] body=in.readNBytes(n);assertEquals(n,body.length);return body;}
    private static Profile profile(TlsMode mode){return Profile.newBuilder().setEngine(Engine.MYSQL).setHost("reviewed.invalid").setPort(3306).setTls(Tls.newBuilder().setMode(mode)).build();}
    private ProcessBuilder endpoint(NativeMysqlRelay relay)throws Exception {NativeRelayFixture.launcher(root);var builder=new ProcessBuilder("reviewed-client","--defaults-file=/private/reviewed.cnf","--no-login-paths","--user=reviewed");relay.configure(builder,root);assertFalse(builder.environment().containsKey("LD_PRELOAD"));int offset=NativeRelayFixture.WINDOWS?1:0;assertEquals("--defaults-file=/private/reviewed.cnf",builder.command().get(1+offset));assertEquals("--no-login-paths",builder.command().get(2+offset));return builder;}

    @Test void privateTransportStreamsCommandBytesWithoutEditingOrResolverInterposition()throws Exception {
        try(var server=new ServerSocket(0,1,InetAddress.getLoopbackAddress());var relay=new NativeMysqlRelay(profile(TlsMode.DISABLED),server.getLocalPort(),SSLContext.getDefault(),NativeRelayFixture.WINDOWS)) {
            var completion=new CompletableFuture<Void>();byte[] command=new byte[262_144];new Random(17).nextBytes(command);command[0]=3;
            Thread.ofVirtual().start(()->{try(var remote=server.accept()){
                remote.setSoTimeout(5000);var in=remote.getInputStream();var out=remote.getOutputStream();packet(out,0,greeting(true));
                byte[] auth=packet(in,1);assertEquals(0,auth[1]&8);packet(out,2,new byte[]{0,0,0,2,0,0,0});
                assertArrayEquals(command,packet(in,0));packet(out,1,new byte[]{0,42,0,(byte)255});
                completion.complete(null);
            }catch(Throwable failure){completion.completeExceptionally(failure);}});
            var builder=endpoint(relay);if(!NativeRelayFixture.WINDOWS)assertEquals("rwx------",java.nio.file.attribute.PosixFilePermissions.toString(Files.getPosixFilePermissions(Path.of(NativeRelayFixture.endpoint(builder)).getParent())));
            try(var socket=NativeRelayFixture.connect(builder)) {
                var input=Channels.newInputStream(socket);var output=Channels.newOutputStream(socket);
                assertEquals(0,packet(input,0)[17]&8);byte[] auth=new byte[40];auth[1]=2;packet(output,1,auth);assertEquals(0,packet(input,2)[0]);
                packet(output,0,command);assertArrayEquals(new byte[]{0,42,0,(byte)255},packet(input,1));
            } catch(Throwable failure) {
                // A peer failure can close the client first. Retain both the
                // fixture's original cause and the relay failure alongside EOF.
                try { completion.get(5,TimeUnit.SECONDS); }
                catch(Throwable serverFailure) { failure.addSuppressed(serverFailure); }
                try { relay.check(); }
                catch(Throwable relayFailure) { failure.addSuppressed(relayFailure); }
                throw failure;
            }
            completion.get(5,TimeUnit.SECONDS);relay.check();
        }
    }

    @Test void requiredTlsRefusesUnsupportedServerWithoutSendingClientCredentials()throws Exception {
        try(var server=new ServerSocket(0,1,InetAddress.getLoopbackAddress());var relay=new NativeMysqlRelay(profile(TlsMode.VERIFY_FULL),server.getLocalPort(),SSLContext.getDefault(),NativeRelayFixture.WINDOWS)) {
            var completion=new CompletableFuture<Void>();
            Thread.ofVirtual().start(()->{try(var remote=server.accept()){remote.setSoTimeout(5000);packet(remote.getOutputStream(),0,greeting(false));assertEquals(-1,remote.getInputStream().read());completion.complete(null);}catch(Throwable failure){completion.completeExceptionally(failure);}});
            try(var socket=NativeRelayFixture.connect(endpoint(relay))) {var in=Channels.newInputStream(socket);var out=Channels.newOutputStream(socket);packet(in,0);byte[] auth=new byte[40];auth[1]=2;packet(out,1,auth);assertEquals(-1,in.read());}
            completion.get(5,TimeUnit.SECONDS);assertThrows(IOException.class,relay::check);
        }
    }

    @Test void closingAnUnconnectedOperationReleasesOnlyItsPrivateEndpoint()throws Exception {
        NativeMysqlRelay relay=new NativeMysqlRelay(profile(TlsMode.DISABLED),54321,SSLContext.getDefault(),NativeRelayFixture.WINDOWS);var builder=endpoint(relay);
        if(NativeRelayFixture.WINDOWS) {
            int port=Integer.parseInt(builder.environment().get("BUSYDATA_NATIVE_PORT"));relay.close();relay.close();assertThrows(ConnectException.class,()->{try(var socket=new Socket("127.0.0.1",port)) {fail("Closed relay accepted a connection");}});
        } else {
            Path path=Path.of(NativeRelayFixture.endpoint(builder));assertTrue(Files.exists(path));relay.close();relay.close();assertFalse(Files.exists(path.getParent()));
        }
    }

    @Test void inheritedTransportAndCredentialOverridesCannotRedirectTheReviewedClient() {
        var builder=new ProcessBuilder("client");for(String key:List.of("LD_PRELOAD","DYLD_INSERT_LIBRARIES","NSS_WRAPPER_HOSTS","BUSYDATA_FORWARD_HOST","BUSYDATA_NATIVE_TOKEN","MYSQL_PWD","PGHOSTADDR"))builder.environment().put(key,"unapproved");
        NativeToolTransport.sanitize(builder);for(String key:List.of("LD_PRELOAD","DYLD_INSERT_LIBRARIES","NSS_WRAPPER_HOSTS","BUSYDATA_FORWARD_HOST","BUSYDATA_NATIVE_TOKEN","MYSQL_PWD","PGHOSTADDR"))assertFalse(builder.environment().containsKey(key));
    }

    @Test void substitutedWindowsBridgeTokenCannotReachTheOwnedSshPort()throws Exception {
        Path directory=Files.createTempDirectory("busydata-relay-handoff-");
        try(var server=new ServerSocket(0,1,InetAddress.getLoopbackAddress());var relay=new NativeMysqlRelay(profile(TlsMode.DISABLED),server.getLocalPort(),SSLContext.getDefault(),true)) {
            Files.createFile(directory.resolve("busydata_tool_launcher.exe"));var builder=new ProcessBuilder("reviewed-client");relay.configure(builder,directory);
            try(var local=new Socket("127.0.0.1",Integer.parseInt(builder.environment().get("BUSYDATA_NATIVE_PORT")))) {
                local.setSoTimeout(5000);byte[] wrong=new byte[32];Arrays.fill(wrong,(byte)99);local.getOutputStream().write(wrong);local.getOutputStream().flush();assertEquals(-1,local.getInputStream().read());
            }
            server.setSoTimeout(150);assertThrows(SocketTimeoutException.class,server::accept);assertThrows(IOException.class,relay::check);
        } finally {Files.deleteIfExists(directory.resolve("busydata_tool_launcher.exe"));Files.delete(directory);}
    }
}
