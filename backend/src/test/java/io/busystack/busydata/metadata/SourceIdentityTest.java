package io.busystack.busydata.metadata;

import com.google.protobuf.ByteString;
import com.google.protobuf.UnknownFieldSet;
import io.busystack.busydata.protocol.*;
import java.util.*;
import java.util.function.Consumer;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.MethodSource;
import static org.junit.jupiter.api.Assertions.*;

class SourceIdentityTest {
    static Profile profile(){return Profile.newBuilder().setId("profile").setEngine(Engine.POSTGRESQL).setHost("localhost").setPort(5432).setDatabase("data").setUser("reader").setTls(Tls.getDefaultInstance()).setSsh(Ssh.getDefaultInstance()).build();}
    @Test void optionMapOrderAndWireRoundTripDoNotChangeFingerprint()throws Exception {
        var first=profile().toBuilder().putOptions("tcpKeepAlive","true").putOptions("applicationName","BusyData").build();
        var second=profile().toBuilder().putOptions("applicationName","BusyData").putOptions("tcpKeepAlive","true").build();
        assertEquals(first,second);assertFalse(Arrays.equals(first.toByteArray(),second.toByteArray()),"Exercise the actual serialization-order defect");
        assertEquals(SourceIdentity.fingerprint(first),SourceIdentity.fingerprint(second));
        assertEquals(SourceIdentity.fingerprint(first),SourceIdentity.fingerprint(Profile.parseFrom(second.toByteArray())));
    }
    @Test void cosmeticAndTimeoutPolicyChangesKeepSourceIdentity(){
        assertEquals(SourceIdentity.fingerprint(profile()),SourceIdentity.fingerprint(profile().toBuilder().setName("Renamed").setEnvironment(Environment.PRODUCTION).setConnectTimeoutSeconds(15).setQueryTimeoutSeconds(30).build()));
    }
    static Stream<Consumer<Profile.Builder>> ownerChanges(){return Stream.of(
        p->p.setId("other"),p->p.setEngine(Engine.MARIADB),p->p.setHost("other"),p->p.setPort(5433),p->p.setDatabase("other"),p->p.setUser("other"),p->p.setReadOnly(true),p->p.setCredentialRef("other"),
        p->p.putOptions("tcpKeepAlive","true"),p->p.putOptions("tcpKeepAlive",""),
        p->p.getTlsBuilder().setMode(TlsMode.VERIFY_CA),p->p.getTlsBuilder().setCaFile("ca"),p->p.getTlsBuilder().setClientCert("cert"),p->p.getTlsBuilder().setClientKey("key"),
        p->p.getTlsBuilder().setJavaTrust(false),p->p.getTlsBuilder().setSystemTrust(false),p->p.getTlsBuilder().setKeyCredentialRef("key-ref"),p->p.getTlsBuilder().setConfiguredMode(TlsMode.VERIFY_FULL),
        p->p.getSshBuilder().setEnabled(true),p->p.getSshBuilder().setHost("ssh"),p->p.getSshBuilder().setPort(22),p->p.getSshBuilder().setUser("ssh-user"),p->p.getSshBuilder().setKnownHosts("hosts"),
        p->p.getSshBuilder().setPrivateKey("selected-key"),p->p.getSshBuilder().setAgent(true),p->p.getSshBuilder().setAgentSocket("socket"),p->p.getSshBuilder().setAgentKeyFingerprint("fingerprint"),p->p.getSshBuilder().setTrustRef("trust"),
        p->p.setUnknownFields(unknown(100)),p->p.getTlsBuilder().setUnknownFields(unknown(100)),p->p.getSshBuilder().setUnknownFields(unknown(100))
    );}
    @ParameterizedTest @MethodSource("ownerChanges") void everyOwnerFieldAffectsFingerprint(Consumer<Profile.Builder> change){
        var modified=profile().toBuilder();change.accept(modified);assertNotEquals(SourceIdentity.fingerprint(profile()),SourceIdentity.fingerprint(modified.build()));
    }
    @Test void optionalFalseAndAbsentAreDifferentEvenWhenMessageExists(){
        var base=profile().toBuilder().setTls(Tls.getDefaultInstance()).build();
        assertNotEquals(SourceIdentity.fingerprint(base),SourceIdentity.fingerprint(base.toBuilder().setTls(base.getTls().toBuilder().setJavaTrust(false)).build()));
        assertNotEquals(SourceIdentity.fingerprint(base),SourceIdentity.fingerprint(base.toBuilder().setTls(base.getTls().toBuilder().setSystemTrust(false)).build()));
        assertNotEquals(SourceIdentity.fingerprint(base),SourceIdentity.fingerprint(base.toBuilder().setTls(base.getTls().toBuilder().setConfiguredMode(TlsMode.VERIFY_FULL)).build()));
    }
    @Test void submessagePresenceRemainsSignificant(){
        assertNotEquals(SourceIdentity.fingerprint(profile()),SourceIdentity.fingerprint(profile().toBuilder().clearTls().build()));
        assertNotEquals(SourceIdentity.fingerprint(profile()),SourceIdentity.fingerprint(profile().toBuilder().clearSsh().build()));
    }
    @Test void unknownFieldValuesAndRepeatedOrderRemainDistinct(){
        var first=UnknownFieldSet.newBuilder().addField(100,UnknownFieldSet.Field.newBuilder().addVarint(1).addVarint(2).addFixed32(3).addFixed64(4).addLengthDelimited(ByteString.copyFromUtf8("raw")).addGroup(unknown(101)).build()).build();
        var second=first.toBuilder().clearField(100).addField(100,UnknownFieldSet.Field.newBuilder().addVarint(2).addVarint(1).build()).build();
        assertNotEquals(SourceIdentity.fingerprint(profile().toBuilder().setUnknownFields(first).build()),SourceIdentity.fingerprint(profile().toBuilder().setUnknownFields(second).build()));
    }
    @Test void oversizedAndDeepUnknownProfilesAreRejectedBeforeFingerprinting(){
        assertThrows(IllegalArgumentException.class,()->SourceIdentity.fingerprint(profile().toBuilder().setHost("x".repeat(8193)).build()));
        var value=UnknownFieldSet.getDefaultInstance();for(int i=0;i<34;i++)value=UnknownFieldSet.newBuilder().addField(100,UnknownFieldSet.Field.newBuilder().addGroup(value).build()).build();
        var deep=profile().toBuilder().setUnknownFields(value).build();assertThrows(IllegalArgumentException.class,()->SourceIdentity.fingerprint(deep));
    }
    @Test void schemaChangesRequireExplicitFingerprintReview(){
        assertEquals(Set.of("id","name","engine","host","port","database","user","environment","read_only","connect_timeout_seconds","query_timeout_seconds","tls","ssh","credential_ref","options"),names(Profile.getDescriptor()));
        assertEquals(Set.of("mode","ca_file","client_cert","client_key","java_trust","system_trust","key_credential_ref","configured_mode"),names(Tls.getDescriptor()));
        assertEquals(Set.of("enabled","host","port","user","known_hosts","private_key","agent","agent_socket","agent_key_fingerprint","trust_ref"),names(Ssh.getDescriptor()));
    }
    static UnknownFieldSet unknown(int number){return UnknownFieldSet.newBuilder().addField(number,UnknownFieldSet.Field.newBuilder().addVarint(1).build()).build();}
    static Set<String> names(com.google.protobuf.Descriptors.Descriptor descriptor){var out=new HashSet<String>();for(var field:descriptor.getFields())out.add(field.getName());return out;}
}
