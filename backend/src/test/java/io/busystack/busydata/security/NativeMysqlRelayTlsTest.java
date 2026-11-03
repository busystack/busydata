package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import java.io.*;
import java.math.BigInteger;
import java.net.*;
import java.nio.channels.*;
import java.nio.file.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.util.*;
import java.util.concurrent.*;
import javax.net.ssl.*;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.*;
import org.bouncycastle.cert.jcajce.*;
import org.bouncycastle.openssl.jcajce.JcaPEMWriter;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class NativeMysqlRelayTlsTest {
    @TempDir Path root;
    private record Identity(KeyPair key,X509Certificate certificate){}
    private Identity identity(String name,Identity issuer,boolean authority,boolean server)throws Exception {
        var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);var key=generator.generateKeyPair();long now=System.currentTimeMillis();var subject=new X500Name("CN="+name);
        var builder=new JcaX509v3CertificateBuilder(issuer==null?subject:new X500Name(issuer.certificate.getSubjectX500Principal().getName()),new BigInteger(120,new SecureRandom()),new Date(now-60000),new Date(now+86400000),subject,key.getPublic());
        builder.addExtension(Extension.basicConstraints,true,new BasicConstraints(authority));builder.addExtension(Extension.keyUsage,true,new KeyUsage(authority?KeyUsage.keyCertSign|KeyUsage.cRLSign:KeyUsage.digitalSignature|KeyUsage.keyEncipherment));
        if(!authority)builder.addExtension(Extension.extendedKeyUsage,false,new ExtendedKeyUsage(server?KeyPurposeId.id_kp_serverAuth:KeyPurposeId.id_kp_clientAuth));
        if(server)builder.addExtension(Extension.subjectAlternativeName,false,new GeneralNames(new GeneralName(GeneralName.dNSName,"localhost")));
        var signer=new JcaContentSignerBuilder("SHA256withRSA").build(issuer==null?key.getPrivate():issuer.key.getPrivate());return new Identity(key,new JcaX509CertificateConverter().getCertificate(builder.build(signer)));
    }
    private Path pem(String name,Object value)throws Exception {Path file=root.resolve(name);try(var writer=new JcaPEMWriter(Files.newBufferedWriter(file))){writer.writeObject(value);}return file;}
    private static SSLContext serverContext(Identity server,Identity ca)throws Exception {
        char[] password="isolated-fixture".toCharArray();KeyStore store=KeyStore.getInstance("PKCS12");store.load(null,password);store.setKeyEntry("server",server.key.getPrivate(),password,new java.security.cert.Certificate[]{server.certificate,ca.certificate});
        var keys=KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm());keys.init(store,password);
        KeyStore roots=KeyStore.getInstance("PKCS12");roots.load(null,password);roots.setCertificateEntry("fixture",ca.certificate);var trust=TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm());trust.init(roots);
        var context=SSLContext.getInstance("TLS");context.init(keys.getKeyManagers(),trust.getTrustManagers(),new SecureRandom());return context;
    }
    private static void packet(OutputStream out,int sequence,byte[] bytes)throws IOException {int n=bytes.length;out.write(new byte[]{(byte)n,(byte)(n>>8),(byte)(n>>16),(byte)sequence});out.write(bytes);out.flush();}
    private static byte[] packet(InputStream in,int sequence)throws IOException {byte[] header=in.readNBytes(4);assertEquals(4,header.length);assertEquals(sequence,header[3]&255);int n=(header[0]&255)|((header[1]&255)<<8)|((header[2]&255)<<16);byte[] body=in.readNBytes(n);assertEquals(n,body.length);return body;}
    private void exchange(String host,TlsMode mode,boolean wrongRoot,boolean mutual,boolean success)throws Exception {
        var ca=identity("Relay CA",null,true,false);var serverIdentity=identity("localhost",ca,false,true);var clientIdentity=identity("native client",ca,false,false);
        var selected=Tls.newBuilder().setMode(mode).setJavaTrust(false).setSystemTrust(false).setCaFile(pem("roots.pem",wrongRoot?identity("Wrong CA",null,true,false).certificate:ca.certificate).toString());
        if(mutual)selected.setClientCert(pem("client.pem",clientIdentity.certificate).toString()).setClientKey(pem("client-key.pem",clientIdentity.key.getPrivate()).toString());
        Profile profile=Profile.newBuilder().setEngine(Engine.MYSQL).setHost(host).setPort(3306).setTls(selected).build();SSLContext context=serverContext(serverIdentity,ca);
        try(var scratch=new PrivateTemporaryFiles(root.resolve("private"));var material=new JdbcTlsMaterial(scratch);var server=new ServerSocket(0,1,InetAddress.getLoopbackAddress());var relay=new NativeMysqlRelay(profile,server.getLocalPort(),material.nativeContext(profile,material.nativeRoots(profile)),NativeRelayFixture.WINDOWS)) {
            var result=new CompletableFuture<Void>();
            Thread.ofVirtual().start(()->{try(var remote=server.accept()) {
                remote.setSoTimeout(5000);byte[] greeting=new byte[60];greeting[0]=10;greeting[1]='8';greeting[16]=2;greeting[17]=8;packet(remote.getOutputStream(),0,greeting);
                byte[] request=packet(remote.getInputStream(),1);assertEquals(32,request.length);assertEquals(8,request[1]&8);
                try(var secure=(SSLSocket)context.getSocketFactory().createSocket(remote,"localhost",3306,true)) {
                    secure.setUseClientMode(false);secure.setNeedClientAuth(mutual);secure.startHandshake();
                    if(mutual)assertEquals(clientIdentity.certificate,secure.getSession().getPeerCertificates()[0]);
                    var in=secure.getInputStream();var out=secure.getOutputStream();byte[] auth=packet(in,2);assertEquals(8,auth[1]&8);
                    // Multiple server packets before a response exercise real duplex
                    // plugin authentication; no alternating-packet assumption.
                    packet(out,3,new byte[]{1,7});packet(out,4,new byte[]{1,8});assertArrayEquals(new byte[]{42,43},packet(in,5));
                    packet(out,6,new byte[]{0,0,0,2,0,0,0});assertArrayEquals(new byte[]{3,0,(byte)255,10},packet(in,0));packet(out,1,new byte[]{0,99});
                    result.complete(null);
                }
            }catch(Throwable failure){result.completeExceptionally(failure);}});
            NativeRelayFixture.launcher(root);var builder=new ProcessBuilder("native","--defaults-file=/reviewed.cnf");relay.configure(builder,root);
            try(var local=NativeRelayFixture.connect(builder)) {
                var in=Channels.newInputStream(local);var out=Channels.newOutputStream(local);assertEquals(0,packet(in,0)[17]&8);byte[] auth=new byte[40];auth[1]=2;packet(out,1,auth);
                if(success) {assertArrayEquals(new byte[]{1,7},packet(in,2));assertArrayEquals(new byte[]{1,8},packet(in,3));packet(out,4,new byte[]{42,43});assertEquals(0,packet(in,5)[0]);packet(out,0,new byte[]{3,0,(byte)255,10});assertArrayEquals(new byte[]{0,99},packet(in,1));}
                else assertEquals(-1,in.read(),"Certificate failure must disconnect before native credentials reach the server");
            }
            if(success){result.get(5,TimeUnit.SECONDS);relay.check();}
            else {assertThrows(ExecutionException.class,()->result.get(5,TimeUnit.SECONDS));assertThrows(IOException.class,relay::check);}
        }
    }
    @Test void verifiedTlsPreservesDuplexAuthenticationAndCommandSequence()throws Exception {exchange("localhost",TlsMode.VERIFY_FULL,false,false,true);}
    @Test void hostnameVerificationUsesOriginalDestinationInsteadOfLoopback()throws Exception {exchange("wrong.invalid",TlsMode.VERIFY_FULL,false,false,false);}
    @Test void wrongTrustRootNeverFallsBackToPlaintext()throws Exception {exchange("localhost",TlsMode.VERIFY_FULL,true,false,false);}
    @Test void certificateOnlyPolicyDoesNotClaimHostnameVerification()throws Exception {exchange("wrong.invalid",TlsMode.VERIFY_CA,false,false,true);}
    @Test void explicitlySelectedClientIdentitySurvivesTheOwnedSshTransport()throws Exception {exchange("localhost",TlsMode.VERIFY_FULL,false,true,true);}
    @Test void publicRootBundleUsesRootProviderBudgetInsteadOfClientChainLimit()throws Exception {
        var ca=identity("Public root fixture",null,true,false);Path single=pem("one-root.pem",ca.certificate),bundle=root.resolve("reviewed-roots.pem");Files.writeString(bundle,Files.readString(single).repeat(65));
        var profile=Profile.newBuilder().setEngine(Engine.MYSQL).setTls(Tls.newBuilder().setMode(TlsMode.VERIFY_FULL)).build();
        try(var scratch=new PrivateTemporaryFiles(root.resolve("private"));var material=new JdbcTlsMaterial(scratch)){assertNotNull(material.nativeContext(profile,bundle));}
    }
}
