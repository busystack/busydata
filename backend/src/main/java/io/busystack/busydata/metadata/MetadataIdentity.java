package io.busystack.busydata.metadata;

import io.busystack.busydata.protocol.*;
import java.nio.charset.StandardCharsets;
import java.security.*;
import java.util.*;

/** Exact names are executable identities; labels and quoted previews are not. */
public record MetadataIdentity(String source,String profileId,String catalog,String schema,
        ObjectKind kind,ObjectSubtype subtype,String parent,String name,String signature,String sessionOwner,String nativeKey,String key) {
    public MetadataIdentity(String source,String profileId,String catalog,String schema,ObjectKind kind,ObjectSubtype subtype,String parent,String name,String signature,String sessionOwner){this(source,profileId,catalog,schema,kind,subtype,parent,name,signature,sessionOwner,"");}
    public MetadataIdentity(String source,String profileId,String catalog,String schema,ObjectKind kind,ObjectSubtype subtype,String parent,String name,String signature,String sessionOwner,String nativeKey){this(source,profileId,catalog,schema,kind,subtype,parent,name,signature,sessionOwner,nativeKey,null);}
    public MetadataIdentity {
        for(String value:List.of(source,profileId,catalog,schema,parent,name,signature,sessionOwner,nativeKey))
            if(value.indexOf('\0')>=0||value.getBytes(StandardCharsets.UTF_8).length>8192)throw new IllegalArgumentException("Metadata identity exceeds its budget");
        Objects.requireNonNull(kind);Objects.requireNonNull(subtype);
        String derived=nativeKey.isEmpty()?digest(source,profileId,catalog,schema,kind.name(),subtype.name(),parent,name,signature,sessionOwner):digest(source,profileId,catalog,kind.name(),"native",nativeKey,sessionOwner);
        if(key!=null&&!key.equals(derived))throw new IllegalArgumentException("Metadata identity key is not canonical");key=derived;
    }
    public long estimatedCharacters(){return (long)source.length()+profileId.length()+catalog.length()+schema.length()+parent.length()+name.length()+signature.length()+sessionOwner.length()+nativeKey.length()+key.length()+kind.name().length()+subtype.name().length();}
    public static String digest(String... components) {
        try {
            var digest=MessageDigest.getInstance("SHA-256");
            for(String part:components){byte[] bytes=part.getBytes(StandardCharsets.UTF_8);int length=bytes.length;digest.update((byte)(length>>>24));digest.update((byte)(length>>>16));digest.update((byte)(length>>>8));digest.update((byte)length);digest.update(bytes);}
            return HexFormat.of().formatHex(digest.digest());
        }catch(NoSuchAlgorithmException impossible){throw new AssertionError(impossible);}
    }
}
