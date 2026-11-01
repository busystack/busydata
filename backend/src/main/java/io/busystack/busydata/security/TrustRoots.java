package io.busystack.busydata.security;

import java.io.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.*;
import java.util.*;

/** Read-only snapshots of identifiable public root providers, never identities. */
public final class TrustRoots {
    private TrustRoots() {}
    // Public root bundles are substantially larger than selected client chains.
    static final int MAX_BYTES=16*1024*1024, MAX_ROOTS=4096;
    public static Collection<? extends java.security.cert.Certificate> javaRoots() throws Exception {
        Path path=Path.of(System.getProperty("java.home"),"lib","security","cacerts");
        byte[] bytes=null;
        try {
            bytes=read(path);
            KeyStore store=KeyStore.getInstance("JKS");
            store.load(new ByteArrayInputStream(bytes),null);
            return entries(store);
        } catch(Exception error) { throw new TlsMaterialFailure(TlsMaterialFailure.Reason.JAVA_ROOTS_UNAVAILABLE); }
        finally { if(bytes!=null)Arrays.fill(bytes,(byte)0); }
    }
    public static Collection<? extends java.security.cert.Certificate> systemRoots() throws Exception {
        try {
            if(System.getProperty("os.name").startsWith("Windows")) {
                // ROOT contains trusted public certificates; MY is never opened.
                var result=new ArrayList<java.security.cert.Certificate>();
                for(String provider:List.of("Windows-ROOT-CURRENTUSER","Windows-ROOT-LOCALMACHINE")) {
                    KeyStore roots=KeyStore.getInstance(provider);roots.load(null,null);result.addAll(entries(roots));
                }
                return bounded(result);
            }
            if(!System.getProperty("os.name").equals("Linux")) throw new IOException("Unsupported system root provider");
            byte[] bytes=read(Path.of("/etc/ssl/certs/ca-certificates.crt"));
            try {return bounded(CertificateFactory.getInstance("X.509").generateCertificates(new ByteArrayInputStream(bytes)));}
            finally {Arrays.fill(bytes,(byte)0);}
        } catch(Exception error) {throw new TlsMaterialFailure(TlsMaterialFailure.Reason.SYSTEM_ROOTS_UNAVAILABLE);}
    }
    // Shared only with profile-scoped native TLS: this is a public-root bundle,
    // not a selected client key/chain governed by SelectedFiles' smaller cap.
    static byte[] read(Path requested) throws IOException {
        Path actual=requested.toRealPath();
        if(!Files.isRegularFile(actual,LinkOption.NOFOLLOW_LINKS)) throw new IOException("Root provider is unavailable");
        try(var channel=Files.newByteChannel(actual,StandardOpenOption.READ,LinkOption.NOFOLLOW_LINKS)) {
            if(channel.size()>MAX_BYTES) throw new IOException("Root provider exceeds its byte budget");
            byte[] bytes=java.nio.channels.Channels.newInputStream(channel).readNBytes(MAX_BYTES+1);
            if(bytes.length>MAX_BYTES){Arrays.fill(bytes,(byte)0);throw new IOException("Root provider changed or exceeds its byte budget");}
            return bytes;
        }
    }
    private static Collection<? extends java.security.cert.Certificate> entries(KeyStore store) throws Exception {
        var result=new ArrayList<java.security.cert.Certificate>();
        for(var aliases=store.aliases();aliases.hasMoreElements();) {
            String alias=aliases.nextElement();
            if(store.isCertificateEntry(alias)) result.add(store.getCertificate(alias));
            if(result.size()>MAX_ROOTS) throw new IllegalArgumentException("Root provider exceeds its certificate budget");
        }
        return bounded(result);
    }
    private static Collection<? extends java.security.cert.Certificate> bounded(Collection<? extends java.security.cert.Certificate> certificates) {
        if(certificates.isEmpty() || certificates.size()>MAX_ROOTS) throw new IllegalArgumentException("Root provider is empty or exceeds its certificate budget");
        return List.copyOf(certificates);
    }
}
