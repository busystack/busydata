package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.security.*;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.safety.Safety;
import java.nio.file.Path;
import java.security.*;
import java.util.*;
import java.util.concurrent.atomic.*;
import org.apache.sshd.server.SshServer;
import org.apache.sshd.server.forward.AcceptAllForwardingFilter;
import org.apache.sshd.common.config.keys.KeyUtils;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class SshTrustTest {
    @TempDir Path root;
    @Test void newAndChangedKeysRequireExactReviewWithoutOfferingCredentials()throws Exception{
        var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);var first=generator.generateKeyPair();var second=generator.generateKeyPair();var current=new AtomicReference<>(first);var offers=new AtomicInteger();
        String trustRef;
        try(var metadata=new MetadataStore(root);var server=SshServer.setUpDefaultServer()){
            server.setHost("127.0.0.1");server.setPort(0);server.setKeyPairProvider(context->List.of(current.get()));server.setForwardingFilter(AcceptAllForwardingFilter.INSTANCE);
            server.setPasswordAuthenticator((user,password,session)->{offers.incrementAndGet();return password.equals("selected-secret");});server.start();
            var profile=Profile.newBuilder().setId("selected-profile").setHost("127.0.0.1").setPort(5432).setEngine(Engine.POSTGRESQL).setConnectTimeoutSeconds(3).setSsh(Ssh.newBuilder().setEnabled(true).setHost("127.0.0.1").setPort(server.getPort()).setUser("selected-user")).build();
            var trust=new SshTrust(metadata,new Safety(new SqlAnalysis()));
            var request=SshTrustRequest.newBuilder().setProfile(profile).build();var review=trust.review(request);
            assertFalse(review.getKnown());assertFalse(review.getChanged());assertEquals(KeyUtils.getFingerPrint(first.getPublic()),review.getFingerprint());assertEquals(0,offers.get());
            var wrong=request.toBuilder().setApprovalToken(review.getApprovalToken()).setAlgorithm(review.getAlgorithm()).setFingerprint("SHA256:"+"x".repeat(43)).build();assertThrows(IllegalArgumentException.class,()->trust.accept(wrong));
            review=trust.review(request);var accepted=trust.accept(approval(request,review,false));trustRef=accepted.getTrustRef();assertFalse(trustRef.isEmpty());
            profile=profile.toBuilder().setSsh(profile.getSsh().toBuilder().setTrustRef(trustRef)).build();
            var open=OpenRequest.newBuilder().setProfile(profile).setSshPassword("selected-secret").build();
            try(var tunnel=new SshTunnel(open,trust.resolve(profile))){assertTrue(tunnel.port()>0);}assertEquals(1,offers.get());
            assertThrows(IllegalArgumentException.class,()->trust.resolve(open.getProfile().toBuilder().setId("another-profile").build()));
            assertThrows(IllegalArgumentException.class,()->trust.resolve(open.getProfile().toBuilder().setSsh(open.getProfile().getSsh().toBuilder().setHost("localhost")).build()));
            current.set(second);assertThrows(Exception.class,()->new SshTunnel(open,trust.resolve(open.getProfile())));assertEquals(1,offers.get());
            request=request.toBuilder().setProfile(profile).build();review=trust.review(request);assertTrue(review.getChanged());assertEquals(KeyUtils.getFingerPrint(first.getPublic()),review.getPreviousFingerprint());assertEquals(KeyUtils.getFingerPrint(second.getPublic()),review.getFingerprint());assertEquals(1,offers.get());
            var rejection=approval(request,review,false);assertThrows(IllegalArgumentException.class,()->trust.accept(rejection));
            review=trust.review(request);var replacement=trust.accept(approval(request,review,true));
            var replaced=profile.toBuilder().setSsh(profile.getSsh().toBuilder().setTrustRef(replacement.getTrustRef())).build();
            try(var tunnel=new SshTunnel(open.toBuilder().setProfile(replaced).build(),trust.resolve(replaced))){assertTrue(tunnel.port()>0);}assertEquals(2,offers.get());
            assertEquals(KeyUtils.getFingerPrint(first.getPublic()),KeyUtils.getFingerPrint(trust.resolve(profile)),"Replacement does not erase the previous valid profile binding");
        }
        try(var metadata=new MetadataStore(root)){assertEquals("selected-profile",metadata.sshTrust(trustRef).profile());}
    }
    private static SshTrustRequest approval(SshTrustRequest request,SshTrustReply review,boolean changed){return request.toBuilder().setApprovalToken(review.getApprovalToken()).setAlgorithm(review.getAlgorithm()).setFingerprint(review.getFingerprint()).setReplaceChangedKey(changed).build();}
}
