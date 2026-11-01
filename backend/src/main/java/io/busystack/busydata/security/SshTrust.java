package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.storage.MetadataStore;
import java.nio.file.*;
import java.security.PublicKey;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicReference;
import org.apache.sshd.client.SshClient;
import org.apache.sshd.client.keyverifier.*;
import org.apache.sshd.common.config.keys.*;

/** Profile-specific pins are machine-local public trust records, never credentials. */
public final class SshTrust {
    private record Review(Profile profile,PublicKey key,SshTrustReply reply,long expires){}
    private final MetadataStore metadata;private final Safety safety;
    private final Map<String,Review> reviews=new ConcurrentHashMap<>();private final Semaphore probes=new Semaphore(2,true);
    private final PrivateTemporaryFiles temporaryFiles;
    public SshTrust(MetadataStore metadata,Safety safety){this(metadata,safety,null);}
    public SshTrust(MetadataStore metadata,Safety safety,PrivateTemporaryFiles temporaryFiles){this.metadata=metadata;this.safety=safety;this.temporaryFiles=temporaryFiles;}
    private static int port(Ssh ssh){return ssh.getPort()==0?22:ssh.getPort();}
    public SshTestReply test(SshTestRequest request,java.util.function.BooleanSupplier cancelled)throws Exception {
        var ssh=request.getSsh();
        if(request.getProfileId().isBlank()||request.getProfileId().length()>256||!ssh.getEnabled()||ssh.getHost().isBlank()||ssh.getHost().length()>256||!ssh.getHost().matches("[A-Za-z0-9_.:\\[\\]-]+")||ssh.getUser().isBlank()||port(ssh)<1||port(ssh)>65535)
            throw new IllegalArgumentException("Choose a profile identity and a valid SSH endpoint and user");
        if(ssh.getAgent()&&(ssh.getAgentSocket().isBlank()||ssh.getAgentKeyFingerprint().isBlank()||!ssh.getPrivateKey().isEmpty()||!request.getSshPassword().isEmpty()||!request.getKeyPassphrase().isEmpty()))
            throw new IllegalArgumentException("Select only the reviewed agent identity");
        if(!ssh.getPrivateKey().isEmpty()&&!request.getSshPassword().isEmpty())throw new IllegalArgumentException("Select only the private key identity");
        if(!probes.tryAcquire())throw new IllegalStateException("SSH probe limit reached");
        try {
            if(cancelled.getAsBoolean())throw new CancellationException("SSH test cancelled");
            var profile=Profile.newBuilder().setId(request.getProfileId()).setSsh(ssh).build();
            try(var connection=SshTunnel.authenticate(request,resolve(profile),temporaryFiles,cancelled)) {
                if(cancelled.getAsBoolean())throw new CancellationException("SSH test cancelled");
                return connection.authenticatedInfo(ssh);
            }
        } finally {probes.release();}
    }
    public PublicKey resolve(Profile profile)throws Exception{
        var ssh=profile.getSsh();if(ssh.getTrustRef().isEmpty())return null;
        var binding=metadata.sshTrust(ssh.getTrustRef());
        if(!binding.profile().equals(profile.getId())||!binding.host().equals(ssh.getHost())||binding.port()!=port(ssh))throw new IllegalArgumentException("SSH trust belongs to a different profile or endpoint; review the exact target");
        return PublicKeyEntry.parsePublicKeyEntry(binding.key()).resolvePublicKey(null,Map.of(),PublicKeyEntryResolver.FAILING);
    }
    public SshTrustReply review(SshTrustRequest request)throws Exception{
        var profile=request.getProfile();var ssh=profile.getSsh();
        if(profile.getId().isBlank()||!ssh.getEnabled()||ssh.getHost().isBlank()||ssh.getHost().length()>256||port(ssh)>65535)throw new IllegalArgumentException("Choose a saved profile identity and an exact SSH endpoint");
        if(!probes.tryAcquire())throw new IllegalStateException("SSH host review limit reached");
        Path snapshot=null;Throwable primary=null;
        try{
            var observed=new AtomicReference<PublicKey>();var previous=new AtomicReference<PublicKey>();var known=new java.util.concurrent.atomic.AtomicBoolean();
            PublicKey pinned;
            try{pinned=resolve(profile);}catch(IllegalArgumentException changedTarget){pinned=null;}
            final PublicKey existingPin=pinned;
            KnownHostsServerKeyVerifier verifier=null;
            if(pinned==null&&!ssh.getKnownHosts().isEmpty()){
                Path path=Path.of(ssh.getKnownHosts());if(!path.isAbsolute()||Files.isSymbolicLink(path)||!Files.isRegularFile(path)||Files.size(path)>1_048_576)throw new IllegalArgumentException("Select an ordinary absolute known_hosts file at most 1MiB");
                byte[] bytes=SelectedFiles.read(path,"SSH known_hosts",1_048_576);
                try{snapshot=temporaryFiles==null?Files.createTempFile("busydata-ssh-review-",".hosts"):temporaryFiles.create("busydata-ssh-review-",".hosts");io.busystack.busydata.results.ResultStore.privateFile(snapshot);Files.write(snapshot,bytes);}finally{Arrays.fill(bytes,(byte)0);}
                verifier=new KnownHostsServerKeyVerifier(RejectAllServerKeyVerifier.INSTANCE,snapshot);
                verifier.setModifiedServerKeyAcceptor((session,address,entry,oldKey,newKey)->{previous.set(oldKey);return false;});
            }
            var selected=verifier;
            try(var client=SshClient.setUpDefaultClient()){
                client.setKeyIdentityProvider(context->List.of());client.setPasswordIdentityProvider(context->List.of());client.setAgentFactory(null);
                client.setServerKeyVerifier((session,address,key)->{
                    observed.set(key);
                    if(existingPin!=null){previous.set(existingPin);known.set(KeyUtils.compareKeys(existingPin,key));return known.get();}
                    boolean accepted=selected!=null&&selected.verifyServerKey(session,address,key);known.set(accepted);return accepted;
                });client.start();
                try(var session=client.connect(ssh.getUser().isEmpty()?"busydata-host-review":ssh.getUser(),ssh.getHost(),port(ssh)).verify(Math.max(1,Math.min(120,profile.getConnectTimeoutSeconds()))*1000L).getSession()){
                    // No authentication, identities, database work, or forwarding.
                    session.waitFor(EnumSet.of(org.apache.sshd.client.session.ClientSession.ClientSessionEvent.WAIT_AUTH,org.apache.sshd.client.session.ClientSession.ClientSessionEvent.CLOSED),Math.max(1,Math.min(120,profile.getConnectTimeoutSeconds()))*1000L);
                }catch(Exception failure){if(observed.get()==null)throw failure;}
            }
            var key=observed.get();if(key==null)throw new IllegalStateException("SSH host did not present a key");
            String old=previous.get()==null?"":KeyUtils.getFingerPrint(previous.get());
            var reply=SshTrustReply.newBuilder().setHost(ssh.getHost()).setPort(port(ssh)).setAlgorithm(KeyUtils.getKeyType(key)).setFingerprint(KeyUtils.getFingerPrint(key)).setPreviousFingerprint(old).setKnown(known.get()).setChanged(!old.isEmpty()&&!known.get());
            String token=safety.issue(fingerprint(profile,key));reply.setApprovalToken(token);
            reviews.entrySet().removeIf(entry->entry.getValue().expires()<System.currentTimeMillis());if(reviews.size()>=256)throw new IllegalStateException("Too many SSH reviews");
            var built=reply.build();reviews.put(token,new Review(profile,key,built,System.currentTimeMillis()+120_000));return built;
        }catch(Exception failure){primary=failure;throw failure;}
        finally{try{if(snapshot!=null)Files.deleteIfExists(snapshot);}catch(Exception cleanup){if(primary!=null)primary.addSuppressed(cleanup);else throw new java.io.IOException("SSH review scratch cleanup failed",cleanup);}finally{probes.release();}}
    }
    public SshTrustReply accept(SshTrustRequest request)throws Exception{
        var review=reviews.remove(request.getApprovalToken());
        if(review==null||review.expires()<System.currentTimeMillis()||!review.profile().equals(request.getProfile())||!review.reply().getAlgorithm().equals(request.getAlgorithm())||!review.reply().getFingerprint().equals(request.getFingerprint()))throw new IllegalArgumentException("SSH review is stale or its host, port, profile, algorithm, or fingerprint changed");
        if(review.reply().getChanged()&&!request.getReplaceChangedKey())throw new IllegalArgumentException("Changed SSH key rejected; verify the fingerprint independently and explicitly approve replacement");
        safety.consume(request.getApprovalToken(),fingerprint(review.profile(),review.key()));
        String reference=metadata.sshTrust(new MetadataStore.SshHost(review.profile().getId(),review.reply().getHost(),review.reply().getPort(),PublicKeyEntry.toString(review.key())));
        return review.reply().toBuilder().clearApprovalToken().setTrustRef(reference).build();
    }
    private static String fingerprint(Profile profile,PublicKey key){return profile.toString()+"\n"+PublicKeyEntry.toString(key);}
}
