package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.security.*;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.rpc.WorkbenchService;
import io.busystack.busydata.rpc.ConnectionErrors;
import io.grpc.*;
import io.grpc.stub.StreamObserver;
import java.nio.file.*;
import java.security.*;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.*;
import org.apache.sshd.server.SshServer;
import org.apache.sshd.common.config.keys.KeyUtils;
import org.apache.sshd.common.config.keys.PublicKeyEntry;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class SshConnectionTest {
    @TempDir Path root;
    static final class Fixture implements AutoCloseable {
        final SshServer server=SshServer.setUpDefaultServer();
        final AtomicInteger authentications=new AtomicInteger(), forwards=new AtomicInteger();
        final KeyPair host, identity;
        final Path known;
        final String password;
        Fixture(Path directory,String password)throws Exception {
            this.password=password;
            var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);
            host=generator.generateKeyPair();identity=generator.generateKeyPair();
            server.setHost("127.0.0.1");server.setPort(0);server.setKeyPairProvider(c->List.of(host));
            server.setPasswordAuthenticator((user,secret,session)->{authentications.incrementAndGet();return user.equals("ssh-user")&&secret.equals(password);});
            server.setPublickeyAuthenticator((user,key,session)->{authentications.incrementAndGet();return user.equals("ssh-user")&&KeyUtils.compareKeys(identity.getPublic(),key);});
            server.setForwardingFilter(new org.apache.sshd.server.forward.AcceptAllForwardingFilter(){
                @Override public boolean canConnect(Type type,org.apache.sshd.common.util.net.SshdSocketAddress address,org.apache.sshd.common.session.Session session){forwards.incrementAndGet();return true;}
            });
            server.start();known=directory.resolve("known_hosts");Files.writeString(known,"[127.0.0.1]:"+server.getPort()+" "+PublicKeyEntry.toString(host.getPublic())+"\n");
        }
        SshTestRequest request(){return SshTestRequest.newBuilder().setProfileId("ssh-only-source").setSsh(Ssh.newBuilder().setEnabled(true).setHost("127.0.0.1").setPort(server.getPort()).setUser("ssh-user").setKnownHosts(known.toString())).setSshPassword(password).build();}
        void assertClosed()throws Exception {
            long deadline=System.nanoTime()+TimeUnit.SECONDS.toNanos(3);
            while(!server.getActiveSessions().isEmpty()&&System.nanoTime()<deadline)Thread.sleep(10);
            assertTrue(server.getActiveSessions().isEmpty(),"SSH test resources must be closed before subsequent use");
            assertEquals(0,forwards.get(),"An authentication test must not request database forwarding");
        }
        @Override public void close()throws Exception{server.close();}
    }
    private SshTrust trust(MetadataStore metadata,PrivateTemporaryFiles scratch){return new SshTrust(metadata,new Safety(new SqlAnalysis()),scratch);}

    @Test void rpcAuthenticatesWithoutGeneralFieldsForwardingOrJdbcSessions()throws Exception {
        var attemptedJdbc=new AtomicInteger();
        try(var fixture=new Fixture(root," selected SSH secret ");var metadata=new MetadataStore(root.resolve("support"));
            var scratch=new PrivateTemporaryFiles(root.resolve("scratch"));var results=new ResultStore(root.resolve("results"),16*1024*1024);
            var sessions=new SessionRegistry(scratch,(adapter,request,port)->{attemptedJdbc.incrementAndGet();throw new AssertionError("SSH-only RPC attempted JDBC");});
            var jobs=new Jobs(results,metadata,new SqlAnalysis(),new Safety(new SqlAnalysis()))) {
            var service=new WorkbenchService(sessions,jobs,results,metadata,new Safety(new SqlAnalysis()),new SqlAnalysis(),()->{},trust(metadata,scratch));
            var context=io.busystack.busydata.protocol.Context.newBuilder().setInstanceId(service.instance).setRequestId("ssh-test").setProtocolVersion(ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.getNumber());
            var reply=new AtomicReference<SshTestReply>();var failure=new AtomicReference<Throwable>();
            service.testSshConnection(fixture.request().toBuilder().setContext(context).build(),new StreamObserver<>(){
                public void onNext(SshTestReply value){reply.set(value);}public void onError(Throwable error){failure.set(error);}public void onCompleted(){}
            });
            assertNull(failure.get());assertNotNull(reply.get());assertEquals("ssh-user",reply.get().getUser());
            assertEquals(KeyUtils.getFingerPrint(fixture.host.getPublic()),reply.get().getFingerprint());
            assertEquals(0,attemptedJdbc.get());assertEquals(0,sessions.size());assertEquals(0,sessions.physicalSessionCount());fixture.assertClosed();
            try(var files=Files.list(root.resolve("scratch"))){assertEquals(0,files.count());}
        }
    }

    @Test void rejectedCredentialsUnknownAndChangedKeysNeverFallBack()throws Exception {
        try(var fixture=new Fixture(root,"selected");var metadata=new MetadataStore(root.resolve("support"));var scratch=new PrivateTemporaryFiles(root.resolve("scratch"))) {
            var trust=trust(metadata,scratch);var request=fixture.request();
            var failure=assertThrows(SshAuthenticationFailure.class,()->trust.test(request.toBuilder().setSshPassword("wrong").build(),()->false));
            assertEquals(Status.Code.PERMISSION_DENIED,ConnectionErrors.safe(failure).getStatus().getCode());fixture.assertClosed();
            int attempts=fixture.authentications.get();
            Files.writeString(fixture.known,"");assertThrows(Exception.class,()->trust.test(request,()->false));assertEquals(attempts,fixture.authentications.get());fixture.assertClosed();
            Files.writeString(fixture.known,"[127.0.0.1]:"+fixture.server.getPort()+" "+PublicKeyEntry.toString(fixture.identity.getPublic())+"\n");
            assertThrows(Exception.class,()->trust.test(request,()->false));assertEquals(attempts,fixture.authentications.get());fixture.assertClosed();
            Files.writeString(fixture.known,"[127.0.0.1]:"+fixture.server.getPort()+" "+PublicKeyEntry.toString(fixture.host.getPublic())+"\n");
            assertEquals("ssh-user",trust.test(request,()->false).getUser());fixture.assertClosed();
        }
    }

    @Test void selectedEncryptedKeyAndReviewedProfilePinWorkWithoutDatabaseConfiguration()throws Exception {
        try(var fixture=new Fixture(root,"selected");var metadata=new MetadataStore(root.resolve("support"));var scratch=new PrivateTemporaryFiles(root.resolve("scratch"))) {
            Path key=root.resolve("selected.pem");
            try(var pem=new org.bouncycastle.openssl.jcajce.JcaPEMWriter(Files.newBufferedWriter(key))){pem.writeObject(new org.bouncycastle.openssl.jcajce.JcaMiscPEMGenerator(fixture.identity.getPrivate(),new org.bouncycastle.openssl.jcajce.JcePEMEncryptorBuilder("AES-256-CBC").build(" selected key phrase ".toCharArray())));}
            ResultStore.privateFile(key);
            var trust=trust(metadata,scratch);var endpoint=fixture.request().getSsh().toBuilder().clearKnownHosts();
            var profile=Profile.newBuilder().setId("ssh-only-source").setSsh(endpoint).setConnectTimeoutSeconds(3).build();
            var review=trust.review(SshTrustRequest.newBuilder().setProfile(profile).build());assertEquals(0,fixture.authentications.get());
            var accepted=trust.accept(SshTrustRequest.newBuilder().setProfile(profile).setApprovalToken(review.getApprovalToken()).setAlgorithm(review.getAlgorithm()).setFingerprint(review.getFingerprint()).build());
            var request=fixture.request().toBuilder().clearSshPassword().setKeyPassphrase(" selected key phrase ").setSsh(endpoint.setTrustRef(accepted.getTrustRef()).setPrivateKey(key.toString())).build();
            assertEquals("ssh-user",trust.test(request,()->false).getUser());fixture.assertClosed();
            assertThrows(Exception.class,()->trust.test(request.toBuilder().setKeyPassphrase("wrong").build(),()->false));fixture.assertClosed();
            assertThrows(IllegalArgumentException.class,()->trust.test(request.toBuilder().setProfileId("different-source").build(),()->false));
            try(var files=Files.list(root.resolve("scratch"))){assertEquals(0,files.count());}
        }
    }

    @Test void cancellationDuringAuthenticationReleasesTheExistingProbeBudget()throws Exception {
        try(var fixture=new Fixture(root,"selected");var metadata=new MetadataStore(root.resolve("support"));var scratch=new PrivateTemporaryFiles(root.resolve("scratch"))) {
            var arrived=new CountDownLatch(1);var release=new CountDownLatch(1);var cancelled=new AtomicBoolean();
            fixture.server.setPasswordAuthenticator((user,password,session)->{arrived.countDown();try{return release.await(4,TimeUnit.SECONDS);}catch(InterruptedException interrupted){return false;}});
            var trust=trust(metadata,scratch);
            var pending=CompletableFuture.runAsync(()->{try{trust.test(fixture.request(),cancelled::get);throw new AssertionError("Cancelled test succeeded");}catch(CancellationException expected){}catch(Exception error){throw new CompletionException(error);}});
            assertTrue(arrived.await(3,TimeUnit.SECONDS));cancelled.set(true);pending.get(2,TimeUnit.SECONDS);release.countDown();fixture.assertClosed();
            fixture.server.setPasswordAuthenticator((user,password,session)->true);
            for(int i=0;i<3;i++){assertNotNull(trust.test(fixture.request(),()->false));fixture.assertClosed();}
            try(var files=Files.list(root.resolve("scratch"))){assertEquals(0,files.count());}
        }
    }
}
