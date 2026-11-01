package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.util.*;
import org.apache.sshd.client.SshClient;
import org.apache.sshd.client.session.ClientSession;
import org.apache.sshd.client.keyverifier.*;
import org.apache.sshd.common.util.net.SshdSocketAddress;
import org.apache.sshd.common.keyprovider.FileKeyPairProvider;

public final class SshTunnel implements AutoCloseable {
    private final java.util.concurrent.atomic.AtomicBoolean closed=new java.util.concurrent.atomic.AtomicBoolean();
    private final List<Path> selectedFiles=new ArrayList<>();
    private final PrivateTemporaryFiles temporaryFiles;
    private final SshClient client;private ClientSession session;private SshdSocketAddress local;
    public SshTunnel(OpenRequest r)throws Exception {
        this(r,null);
    }
    public SshTunnel(OpenRequest r,java.security.PublicKey trusted)throws Exception {this(r,trusted,null);}
    public SshTunnel(OpenRequest r,java.security.PublicKey trusted,PrivateTemporaryFiles temporaryFiles)throws Exception {
        this(r,trusted,temporaryFiles,true,()->false);
    }
    public static SshTunnel authenticate(SshTestRequest r,java.security.PublicKey trusted,PrivateTemporaryFiles temporaryFiles,java.util.function.BooleanSupplier cancelled)throws Exception {
        var profile=Profile.newBuilder().setId(r.getProfileId()).setSsh(r.getSsh()).setConnectTimeoutSeconds(10).build();
        return new SshTunnel(OpenRequest.newBuilder().setProfile(profile).setSshPassword(r.getSshPassword()).setKeyPassphrase(r.getKeyPassphrase()).build(),trusted,temporaryFiles,false,cancelled);
    }
    private SshTunnel(OpenRequest r,java.security.PublicKey trusted,PrivateTemporaryFiles temporaryFiles,boolean forward,java.util.function.BooleanSupplier cancelled)throws Exception {
        this.temporaryFiles=temporaryFiles;
        var ssh=r.getProfile().getSsh();
        if(trusted==null&&(ssh.getKnownHosts().isBlank()||!Path.of(ssh.getKnownHosts()).isAbsolute()||!Files.isRegularFile(Path.of(ssh.getKnownHosts()))||Files.size(Path.of(ssh.getKnownHosts()))>1024*1024))throw new IllegalArgumentException("Review this profile's SSH host key or select an absolute known_hosts file at most 1MiB");
        client=SshClient.setUpDefaultClient();
        try {
        client.setServerKeyVerifier(trusted==null?new KnownHostsServerKeyVerifier(RejectAllServerKeyVerifier.INSTANCE,snapshot(ssh.getKnownHosts(),"known_hosts")):(session,address,key)->org.apache.sshd.common.config.keys.KeyUtils.compareKeys(trusted,key));
        client.setKeyIdentityProvider(context->List.of());client.setPasswordIdentityProvider(context->List.of());
        client.setAgentFactory(ssh.getAgent()?new org.apache.sshd.agent.SshAgentFactory(){
            public List<org.apache.sshd.common.channel.ChannelFactory> getChannelForwardingFactories(org.apache.sshd.common.FactoryManager manager){return List.of();}
            public org.apache.sshd.agent.SshAgent createClient(org.apache.sshd.common.session.Session session,org.apache.sshd.common.FactoryManager manager)throws java.io.IOException{return new SelectedAgent(ssh.getAgentSocket(),ssh.getAgentKeyFingerprint(),r.getProfile().getConnectTimeoutSeconds());}
            public org.apache.sshd.agent.SshAgentServer createServer(org.apache.sshd.common.session.ConnectionService service)throws java.io.IOException{throw new java.io.IOException("SSH agent forwarding is disabled");}
        }:null);
            client.start();
            long timeout=Math.max(1,r.getProfile().getConnectTimeoutSeconds())*1000L;
            long deadline=System.nanoTime()+java.util.concurrent.TimeUnit.MILLISECONDS.toNanos(timeout);
            var connecting=client.connect(ssh.getUser(),ssh.getHost(),ssh.getPort()==0?22:ssh.getPort());
            session=(forward?connecting.verify(timeout):verifyTest(connecting,deadline,cancelled)).getSession();
            if(ssh.getAgent()) { if(!ssh.getPrivateKey().isBlank()||!r.getSshPassword().isBlank())throw new IllegalArgumentException("Agent authentication cannot offer additional keys or passwords"); }
            else if(!ssh.getPrivateKey().isBlank()) {
                Path selected=snapshot(ssh.getPrivateKey(),"private key");
                var keys=new FileKeyPairProvider(selected);
                keys.setPasswordFinder((s,p,i)->r.getKeyPassphrase());
                for(var key:keys.loadKeys(session))session.addPublicKeyIdentity(key);
            } else if(!r.getSshPassword().isEmpty())session.addPasswordIdentity(r.getSshPassword());
            else throw new IllegalArgumentException("Select an SSH identity");
            var auth=session.auth();
            if(forward)auth.verify(timeout);
            else {
                awaitTest(auth,deadline,cancelled);
                if(auth.isFailure())throw new SshAuthenticationFailure();
                verifyTest(auth,deadline,cancelled);
            }
            if(forward)local=session.startLocalPortForwarding(new SshdSocketAddress("127.0.0.1",0),new SshdSocketAddress(r.getProfile().getHost(),r.getProfile().getPort()));
        } catch(Exception e) {try{close();}catch(Exception cleanup){e.addSuppressed(cleanup);}throw e;}
    }
    public SshTestReply authenticatedInfo(Ssh ssh) {
        var key=session.getServerKey();
        return SshTestReply.newBuilder().setHost(ssh.getHost()).setPort(ssh.getPort()==0?22:ssh.getPort()).setUser(session.getUsername())
            .setAlgorithm(org.apache.sshd.common.config.keys.KeyUtils.getKeyType(key)).setFingerprint(org.apache.sshd.common.config.keys.KeyUtils.getFingerPrint(key)).build();
    }
    private static void awaitTest(org.apache.sshd.common.future.WaitableFuture future,long deadline,java.util.function.BooleanSupplier cancelled)throws Exception {
        while(true) {
            if(cancelled.getAsBoolean())throw new java.util.concurrent.CancellationException("SSH test cancelled");
            long remaining=java.util.concurrent.TimeUnit.NANOSECONDS.toMillis(deadline-System.nanoTime());
            if(remaining<=0)throw new java.net.SocketTimeoutException("SSH test deadline reached");
            if(future.isDone())return;
            future.await(Math.min(remaining,50));
        }
    }
    private static <T extends org.apache.sshd.common.future.SshFuture<T> & org.apache.sshd.common.future.VerifiableFuture<T>> T verifyTest(T future,long deadline,java.util.function.BooleanSupplier cancelled)throws Exception {
        awaitTest(future,deadline,cancelled);
        return future.verify(Math.max(1,java.util.concurrent.TimeUnit.NANOSECONDS.toMillis(deadline-System.nanoTime())));
    }
    private Path snapshot(String value,String description)throws Exception {
        byte[] bytes=SelectedFiles.read(Path.of(value),"SSH "+description,1_048_576);
        try{Path file=temporaryFiles==null?Files.createTempFile("busydata-ssh-selected-",".pem"):temporaryFiles.create("busydata-ssh-selected-",".pem");selectedFiles.add(file);io.busystack.busydata.results.ResultStore.privateFile(file);Files.write(file,bytes);return file;}
        finally{Arrays.fill(bytes,(byte)0);}
    }
    public int port(){return local.getPort();}
    public void close(){
        if(!closed.compareAndSet(false,true))return;
        Exception primary=null;
        if(session!=null){
            try{if(local!=null)session.stopLocalPortForwarding(local);}catch(Exception failure){primary=failure;}
            try{session.close();}catch(Exception failure){if(primary==null)primary=failure;else primary.addSuppressed(failure);}
        }
        try{client.stop();}catch(Exception failure){if(primary==null)primary=failure;else primary.addSuppressed(failure);}
        for(Path file:selectedFiles)try{Files.deleteIfExists(file);}catch(Exception failure){if(primary==null)primary=failure;else primary.addSuppressed(failure);}
        if(primary!=null)throw new IllegalStateException("SSH forwarding cleanup failed",primary);
    }
}
