package io.busystack.busydata.security;
import java.security.*;
import java.security.cert.X509Certificate;
import java.math.BigInteger;
import java.util.Date;
import java.net.InetAddress;
import java.io.*;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.*;
import org.bouncycastle.cert.jcajce.*;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.openssl.jcajce.JcaPEMWriter;
public record LaunchTls(PrivateKey key,X509Certificate certificate,String pem) {
    public static LaunchTls create()throws Exception {
        var generator=KeyPairGenerator.getInstance("EC");generator.initialize(256,new SecureRandom());var pair=generator.generateKeyPair();var now=System.currentTimeMillis();
        var name=new X500Name("CN=BusyData private backend");
        var builder=new JcaX509v3CertificateBuilder(name,new BigInteger(128,new SecureRandom()),new Date(now-30_000),new Date(now+365L*86_400_000),name,pair.getPublic());
        builder.addExtension(Extension.subjectAlternativeName,false,new GeneralNames(new GeneralName[]{new GeneralName(GeneralName.iPAddress,"127.0.0.1"),new GeneralName(GeneralName.dNSName,"localhost")}));
        builder.addExtension(Extension.basicConstraints,true,new BasicConstraints(false));
        builder.addExtension(Extension.keyUsage,true,new KeyUsage(KeyUsage.digitalSignature));
        var signer=new JcaContentSignerBuilder("SHA256withECDSA").build(pair.getPrivate());
        var cert=new JcaX509CertificateConverter().getCertificate(builder.build(signer));cert.verify(pair.getPublic());
        var text=new StringWriter();try(var writer=new JcaPEMWriter(text)){writer.writeObject(cert);}return new LaunchTls(pair.getPrivate(),cert,text.toString());
    }
}
