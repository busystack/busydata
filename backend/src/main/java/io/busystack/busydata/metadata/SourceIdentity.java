package io.busystack.busydata.metadata;

import com.google.protobuf.ByteString;
import com.google.protobuf.UnknownFieldSet;
import io.busystack.busydata.protocol.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;

/** Field-explicit configuration fingerprint, independent of protobuf wire order.
 * A durable binding assigns the opaque source ID; sessions capture that ID once.
 */
public final class SourceIdentity {
    private SourceIdentity() {}

    public static String fingerprint(Profile profile) {
        if(profile.getSerializedSize()>8192)throw new IllegalArgumentException("Profile exceeds 8KiB");
        var out=new Fingerprint();out.part("busydata-source-configuration-v1");
        out.part(profile.getId());out.part(profile.getEngineValue());
        out.part(profile.getHost());out.part(profile.getPort());
        out.part(profile.getDatabase());out.part(profile.getUser());
        out.part(profile.getReadOnly());out.part(profile.getCredentialRef());
        // Name, environment and connection/query timeouts are presentation or
        // execution policy, not a different catalog. All other fields matter.
        out.part(profile.hasTls());
        if(profile.hasTls()) {
            var tls=profile.getTls();out.part(tls.getModeValue());out.part(tls.getCaFile());
            out.part(tls.getClientCert());out.part(tls.getClientKey());
            out.part(tls.hasJavaTrust());out.part(tls.getJavaTrust());
            out.part(tls.hasSystemTrust());out.part(tls.getSystemTrust());
            out.part(tls.getKeyCredentialRef());out.part(tls.hasConfiguredMode());
            out.part(tls.getConfiguredModeValue());out.unknown(tls.getUnknownFields(),0);
        }
        out.part(profile.hasSsh());
        if(profile.hasSsh()) {
            var ssh=profile.getSsh();out.part(ssh.getEnabled());out.part(ssh.getHost());
            out.part(ssh.getPort());out.part(ssh.getUser());out.part(ssh.getKnownHosts());
            out.part(ssh.getPrivateKey());out.part(ssh.getAgent());out.part(ssh.getAgentSocket());
            out.part(ssh.getAgentKeyFingerprint());out.part(ssh.getTrustRef());
            out.unknown(ssh.getUnknownFields(),0);
        }
        out.part(profile.getOptionsCount());
        for(var entry:new TreeMap<>(profile.getOptionsMap()).entrySet()) {
            out.part(entry.getKey());out.part(entry.getValue());
        }
        out.unknown(profile.getUnknownFields(),0);
        return HexFormat.of().formatHex(out.digest.digest());
    }

    private static final class Fingerprint {
        final MessageDigest digest;
        Fingerprint(){try{digest=MessageDigest.getInstance("SHA-256");}catch(NoSuchAlgorithmException impossible){throw new AssertionError(impossible);}}
        void part(boolean value){part(value?"1":"0");}
        void part(long value){part(Long.toString(value));}
        void part(String value){bytes(value.getBytes(StandardCharsets.UTF_8));}
        void bytes(byte[] value){int length=value.length;digest.update((byte)(length>>>24));digest.update((byte)(length>>>16));digest.update((byte)(length>>>8));digest.update((byte)length);digest.update(value);}
        void unknown(UnknownFieldSet value,int depth) {
            if(depth>32)throw new IllegalArgumentException("Profile unknown-field nesting exceeds its budget");
            part(value.asMap().size());
            for(var entry:new TreeMap<>(value.asMap()).entrySet()) {
                part(entry.getKey());var field=entry.getValue();
                part(field.getVarintList().size());for(long item:field.getVarintList())part(Long.toUnsignedString(item));
                part(field.getFixed32List().size());for(int item:field.getFixed32List())part(Integer.toUnsignedString(item));
                part(field.getFixed64List().size());for(long item:field.getFixed64List())part(Long.toUnsignedString(item));
                part(field.getLengthDelimitedList().size());for(ByteString item:field.getLengthDelimitedList())bytes(item.toByteArray());
                part(field.getGroupList().size());for(var item:field.getGroupList())unknown(item,depth+1);
            }
        }
    }
}
