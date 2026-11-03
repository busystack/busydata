package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;
import java.util.Properties;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import static org.junit.jupiter.api.Assertions.*;

class SelectedMaterialTest {
 @TempDir Path root;
 @Test void selectedBytesAreBoundedAndIndependentOfLaterReplacement()throws Exception {
  Path source=root.resolve("selected.pem");Files.writeString(source,"reviewed certificate bytes");
  var exact=SelectedFiles.read(source,"fixture",64);Files.writeString(source,"replaced");
  assertEquals("reviewed certificate bytes",new String(exact,java.nio.charset.StandardCharsets.UTF_8));
  Files.write(source,new byte[65]);assertThrows(java.io.IOException.class,()->SelectedFiles.read(source,"fixture",64));
  assertThrows(java.io.IOException.class,()->SelectedFiles.read(Path.of("relative.pem"),"fixture",64));
  assertThrows(java.io.IOException.class,()->SelectedFiles.read(root,"fixture",64));
 }
 @Test void postgresUsesImmutableOwnedCertificatePathsAndCleanupIsIdempotent()throws Exception {
  Path source=root.resolve("selected-ca.pem");
  var generator=java.security.KeyPairGenerator.getInstance("RSA");generator.initialize(2048);var pair=generator.generateKeyPair();
  var subject=new org.bouncycastle.asn1.x500.X500Name("CN=Selected fixture CA");long now=System.currentTimeMillis();
  var builder=new org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder(subject,java.math.BigInteger.ONE,new java.util.Date(now-60000),new java.util.Date(now+3600000),subject,pair.getPublic());
  builder.addExtension(org.bouncycastle.asn1.x509.Extension.basicConstraints,true,new org.bouncycastle.asn1.x509.BasicConstraints(true));
  var certificate=new org.bouncycastle.cert.jcajce.JcaX509CertificateConverter().getCertificate(builder.build(new org.bouncycastle.operator.jcajce.JcaContentSignerBuilder("SHA256withRSA").build(pair.getPrivate())));
  try(var writer=new org.bouncycastle.openssl.jcajce.JcaPEMWriter(Files.newBufferedWriter(source))){writer.writeObject(certificate);}
  try(var scratch=new PrivateTemporaryFiles(root.resolve("scratch"))) {
   var material=new JdbcTlsMaterial(scratch);var properties=new Properties();
   material.configure(Profile.newBuilder().setEngine(Engine.POSTGRESQL).setTls(Tls.newBuilder().setCaFile(source.toString()).setMode(TlsMode.VERIFY_FULL)).build(),properties);
   Path copied=Path.of(properties.getProperty("sslrootcert"));assertNotEquals(source,copied);
   byte[] reviewed=Files.readAllBytes(copied);
   assertFalse(new String(reviewed,java.nio.charset.StandardCharsets.US_ASCII).contains("\r"),"Owned certificate bundles use canonical LF on both platforms");
   Files.writeString(source,"replacement CA");assertArrayEquals(reviewed,Files.readAllBytes(copied));
   try(var input=Files.newInputStream(copied)) {
    var retained=java.security.cert.CertificateFactory.getInstance("X.509").generateCertificates(input);
    assertEquals(1,retained.size());assertArrayEquals(certificate.getEncoded(),retained.iterator().next().getEncoded());
   }
   material.close();material.close();assertFalse(Files.exists(copied));assertEquals("replacement CA",Files.readString(source));
  }
 }
 @Test void cleanupContinuesAfterOneFailureAndRetainsThatFailure()throws Exception {
  Path ca=root.resolve("ca.pem"),certificate=root.resolve("client.pem"),key=root.resolve("key.pem");
  Files.writeString(ca,"ca");Files.writeString(certificate,"invalid selected certificate");Files.writeString(key,"invalid selected key");
  try(var scratch=new PrivateTemporaryFiles(root.resolve("scratch"))) {
   var material=new JdbcTlsMaterial(scratch);
   assertThrows(Exception.class,()->material.configure(Profile.newBuilder().setEngine(Engine.POSTGRESQL).setTls(Tls.newBuilder().setCaFile(ca.toString()).setClientCert(certificate.toString()).setClientKey(key.toString())).build(),new Properties()));
   java.util.List<Path> copies;try(var files=Files.list(root.resolve("scratch"))){copies=files.sorted().toList();}
   assertEquals(3,copies.size());Path failing=copies.getFirst();Files.delete(failing);Files.createDirectory(failing);Files.writeString(failing.resolve("fault"),"owned fixture");
   assertThrows(DirectoryNotEmptyException.class,material::close);
   for(Path file:copies.subList(1,copies.size()))assertFalse(Files.exists(file),"A failed deletion must not skip remaining owned files");
   material.close();Files.delete(failing.resolve("fault"));Files.delete(failing);
  }
 }
}
