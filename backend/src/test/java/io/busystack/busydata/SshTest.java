package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.security.SshTunnel;
import io.busystack.busydata.security.SelectedAgent;
import java.nio.file.*;
import java.net.*;
import java.security.*;
import java.util.*;
import java.util.concurrent.atomic.AtomicInteger;
import org.apache.sshd.server.SshServer;
import org.apache.sshd.server.forward.AcceptAllForwardingFilter;
import org.apache.sshd.common.config.keys.PublicKeyEntry;
import org.bouncycastle.openssl.jcajce.JcaPEMWriter;
import org.junit.jupiter.api.*;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class SshTest {
    @TempDir Path root;
    @Test void unixAgentOffersOnlyTheReviewedFingerprint()throws Exception {
        if(!System.getProperty("os.name").equals("Linux")){assertThrows(java.io.IOException.class,()->new SelectedAgent("/selected/socket","SHA256:"+"x".repeat(43),2));return;}
        var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);var host=generator.generateKeyPair();var selected=generator.generateKeyPair();var unrelated=generator.generateKeyPair();
        // AF_UNIX addresses must remain short even when bulk test data lives
        // on a deeply mounted external source path. Only this private IPC socket
        // uses the OS directory; key material and evidence stay under root.
        Path socketDirectory=Files.createTempDirectory(Path.of("/tmp"),"bda-");
        io.busystack.busydata.results.ResultStore.privateDirectory(socketDirectory);
        Path socket=socketDirectory.resolve("agent");Process agent;
        try{agent=new ProcessBuilder("ssh-agent","-D","-a",socket.toString()).redirectOutput(ProcessBuilder.Redirect.DISCARD).redirectError(root.resolve("ssh-agent.log").toFile()).start();}
        catch(Exception failure){Files.deleteIfExists(socket);Files.delete(socketDirectory);throw failure;}
        try(var server=SshServer.setUpDefaultServer()){
            long deadline=System.nanoTime()+java.util.concurrent.TimeUnit.SECONDS.toNanos(5);while(!Files.exists(socket)&&agent.isAlive()&&System.nanoTime()<deadline)Thread.sleep(10);assertTrue(Files.exists(socket),"ssh-agent failed to start");
            for(var identity:List.of(selected,unrelated)){Path key=Files.createTempFile(root,"identity-",".pem");io.busystack.busydata.results.ResultStore.privateFile(key);try(var pem=new JcaPEMWriter(Files.newBufferedWriter(key))){pem.writeObject(identity.getPrivate());}var add=new ProcessBuilder("ssh-add",key.toString()).redirectError(ProcessBuilder.Redirect.DISCARD).redirectOutput(ProcessBuilder.Redirect.DISCARD);add.environment().put("SSH_AUTH_SOCK",socket.toString());var loaded=add.start();assertTrue(loaded.waitFor(5,java.util.concurrent.TimeUnit.SECONDS));assertEquals(0,loaded.exitValue());}
            String fingerprint=org.apache.sshd.common.config.keys.KeyUtils.getFingerPrint(selected.getPublic());
            try(var client=new SelectedAgent(socket.toString(),fingerprint,2)){var identities=new ArrayList<java.util.Map.Entry<PublicKey,String>>();client.getIdentities().forEach(identities::add);assertEquals(1,identities.size());assertArrayEquals(selected.getPublic().getEncoded(),identities.getFirst().getKey().getEncoded());assertThrows(java.io.IOException.class,()->client.sign(null,unrelated.getPublic(),"rsa-sha2-256",new byte[]{1}));}
            server.setHost("127.0.0.1");server.setPort(0);server.setKeyPairProvider(context->List.of(host));server.setForwardingFilter(AcceptAllForwardingFilter.INSTANCE);var offers=new AtomicInteger();
            server.setPublickeyAuthenticator((user,key,session)->{offers.incrementAndGet();assertArrayEquals(selected.getPublic().getEncoded(),key.getEncoded());return user.equals("fixture");});server.start();
            Path known=root.resolve("known_hosts");Files.writeString(known,"[127.0.0.1]:"+server.getPort()+" "+PublicKeyEntry.toString(host.getPublic())+"\n");
            var profile=Profile.newBuilder().setEngine(Engine.POSTGRESQL).setHost("127.0.0.1").setPort(5432).setConnectTimeoutSeconds(2).setSsh(Ssh.newBuilder().setEnabled(true).setHost("127.0.0.1").setPort(server.getPort()).setUser("fixture").setKnownHosts(known.toString()).setAgent(true).setAgentSocket(socket.toString()).setAgentKeyFingerprint(fingerprint)).build();
            try(var tunnel=new SshTunnel(OpenRequest.newBuilder().setProfile(profile).build())){assertTrue(tunnel.port()>0);}assertTrue(offers.get()>0);
            try(var authenticated=SshTunnel.authenticate(SshTestRequest.newBuilder().setProfileId("selected-agent-test").setSsh(profile.getSsh()).build(),null,null,()->false)) {
                assertEquals("fixture",authenticated.authenticatedInfo(profile.getSsh()).getUser());
            }
            assertThrows(Exception.class,()->new SshTunnel(OpenRequest.newBuilder().setProfile(profile.toBuilder().setSsh(profile.getSsh().toBuilder().setAgentKeyFingerprint("SHA256:"+"x".repeat(43)))).build()));
        }finally{
            agent.destroy();if(!agent.waitFor(3,java.util.concurrent.TimeUnit.SECONDS)){agent.destroyForcibly();assertTrue(agent.waitFor(3,java.util.concurrent.TimeUnit.SECONDS),"Owned ssh-agent did not exit");}
            Files.deleteIfExists(socket);Files.delete(socketDirectory);
        }
    }
    @Test void selectedPasswordAndKeyForwardingRejectUnknownAndChangedHosts()throws Exception {
        var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);var host=generator.generateKeyPair();var selected=generator.generateKeyPair();var unrelated=generator.generateKeyPair();var offered=new AtomicInteger();
        try(var target=new ServerSocket(0,10,InetAddress.getLoopbackAddress());var server=SshServer.setUpDefaultServer()) {
            server.setHost("127.0.0.1");server.setPort(0);server.setKeyPairProvider(context->List.of(host));
            server.setPasswordAuthenticator((user,password,session)->user.equals("fixture")&&password.equals("ssh-fixture"));
            server.setPublickeyAuthenticator((user,key,session)->{offered.incrementAndGet();assertArrayEquals(selected.getPublic().getEncoded(),key.getEncoded(),"An unrelated identity was offered");return user.equals("fixture");});
            server.setForwardingFilter(AcceptAllForwardingFilter.INSTANCE);server.start();
            Path known=root.resolve("known_hosts");Files.writeString(known,"[127.0.0.1]:"+server.getPort()+" "+PublicKeyEntry.toString(host.getPublic())+"\n");
            var profile=Profile.newBuilder().setName("SSH fixture").setEngine(Engine.POSTGRESQL).setHost("127.0.0.1").setPort(target.getLocalPort()).setConnectTimeoutSeconds(10).setSsh(Ssh.newBuilder().setEnabled(true).setHost("127.0.0.1").setPort(server.getPort()).setUser("fixture").setKnownHosts(known.toString())).build();
            var password=OpenRequest.newBuilder().setProfile(profile).setSshPassword("ssh-fixture").build();
            int forwardingPort;
            try(var tunnel=new SshTunnel(password)) {
                forwardingPort=tunnel.port();var response=java.util.concurrent.CompletableFuture.supplyAsync(()->{try(var peer=target.accept()){return peer.getInputStream().read();}catch(Exception error){throw new RuntimeException(error);}});
                try(var socket=new Socket("127.0.0.1",tunnel.port())){socket.getOutputStream().write(47);socket.getOutputStream().flush();assertEquals(47,response.get(3,java.util.concurrent.TimeUnit.SECONDS));}
            }
            assertThrows(java.io.IOException.class,()->new Socket("127.0.0.1",forwardingPort));
            var repeated=new SshTunnel(password);int repeatedPort=repeated.port();repeated.close();repeated.close();
            assertThrows(java.io.IOException.class,()->new Socket("127.0.0.1",repeatedPort));
            Path key=root.resolve("selected.pem");try(var pem=new JcaPEMWriter(Files.newBufferedWriter(key))){pem.writeObject(selected.getPrivate());}
            var keyed=password.toBuilder().clearSshPassword().setProfile(profile.toBuilder().setSsh(profile.getSsh().toBuilder().setPrivateKey(key.toString()))).build();
            try(var tunnel=new SshTunnel(keyed)){assertTrue(tunnel.port()>0);}assertTrue(offered.get()>0);
            var encryptor=new org.bouncycastle.openssl.jcajce.JcePEMEncryptorBuilder("AES-256-CBC").build("selected fixture phrase".toCharArray());
            try(var pem=new JcaPEMWriter(Files.newBufferedWriter(key))){pem.writeObject(new org.bouncycastle.openssl.jcajce.JcaMiscPEMGenerator(selected.getPrivate(),encryptor));}
            try(var tunnel=new SshTunnel(keyed.toBuilder().setKeyPassphrase("selected fixture phrase").build())){assertTrue(tunnel.port()>0);}
            int before=offered.get();assertThrows(Exception.class,()->new SshTunnel(keyed.toBuilder().setKeyPassphrase("wrong phrase").build()));assertEquals(before,offered.get(),"An unreadable selected key must not try another identity or method");
            var reason=io.grpc.Metadata.Key.of("busydata-connection-reason",io.grpc.Metadata.ASCII_STRING_MARSHALLER);
            Files.writeString(known,"[127.0.0.1]:"+server.getPort()+" "+PublicKeyEntry.toString(unrelated.getPublic())+"\n");
            var changed=assertThrows(Exception.class,()->new SshTunnel(password));assertEquals("ssh-host-key",io.busystack.busydata.rpc.ConnectionErrors.safe(changed).getTrailers().get(reason));
            Files.writeString(known,"");var unknown=assertThrows(Exception.class,()->new SshTunnel(password));assertEquals("ssh-host-key",io.busystack.busydata.rpc.ConnectionErrors.safe(unknown).getTrailers().get(reason));
            Files.writeString(known,"[127.0.0.1]:"+server.getPort()+" "+PublicKeyEntry.toString(host.getPublic())+"\n");assertThrows(Exception.class,()->new SshTunnel(password.toBuilder().setSshPassword("wrong").build()));
        }
    }
}
