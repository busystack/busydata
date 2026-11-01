package io.busystack.busydata;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.sessions.SessionRegistry;
import io.busystack.busydata.storage.MetadataStore;
import io.busystack.busydata.results.ResultStore;
import io.busystack.busydata.analysis.SqlAnalysis;
import io.busystack.busydata.safety.Safety;
import io.busystack.busydata.jobs.Jobs;
import io.busystack.busydata.transfers.Transfers;
import io.busystack.busydata.security.NativeToolTransport;
import io.busystack.busydata.security.PrivateTemporaryFiles;
import java.nio.file.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.math.BigInteger;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.TimeUnit;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.*;
import org.bouncycastle.cert.jcajce.*;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.openssl.jcajce.JcaPEMWriter;
import org.apache.sshd.server.SshServer;
import org.apache.sshd.server.forward.AcceptAllForwardingFilter;
import org.apache.sshd.common.config.keys.PublicKeyEntry;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.*;
import static org.junit.jupiter.api.Assertions.*;

class NativeBackupTlsIT {
 @TempDir Path root;
 private record Identity(KeyPair key,X509Certificate certificate){}
 private Identity identity(String name,Identity issuer,boolean authority)throws Exception{
  var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);var key=generator.generateKeyPair();
  var subject=new X500Name("CN="+name);long now=System.currentTimeMillis();
  var builder=new JcaX509v3CertificateBuilder(issuer==null?subject:new X500Name(issuer.certificate.getSubjectX500Principal().getName()),new BigInteger(120,new SecureRandom()),new Date(now-60000),new Date(now+86400000),subject,key.getPublic());
  builder.addExtension(Extension.basicConstraints,true,new BasicConstraints(authority));
  builder.addExtension(Extension.keyUsage,true,new KeyUsage(authority?KeyUsage.keyCertSign|KeyUsage.cRLSign:KeyUsage.digitalSignature|KeyUsage.keyEncipherment));
  if(!authority){builder.addExtension(Extension.extendedKeyUsage,false,new ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuth));builder.addExtension(Extension.subjectAlternativeName,false,new GeneralNames(new GeneralName(GeneralName.dNSName,"localhost")));}
  var signer=new JcaContentSignerBuilder("SHA256withRSA").build(issuer==null?key.getPrivate():issuer.key.getPrivate());
  return new Identity(key,new JcaX509CertificateConverter().getCertificate(builder.build(signer)));
 }
 private Path pem(String name,Object value)throws Exception{Path file=root.resolve(name);Files.createFile(file);ResultStore.privateFile(file);try(var writer=new JcaPEMWriter(Files.newBufferedWriter(file))){writer.writeObject(value);}return file;}
 @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
 void nativeClientsRetainOriginalHostnameAcrossOwnedSshAndVerifyCertificates(String name)throws Exception {
  Engine engine=Engine.valueOf(name);boolean postgres=engine==Engine.POSTGRESQL;int port=postgres?5432:3306;
  var ca=identity("Fixture CA",null,true);var server=identity("localhost",ca,false);
  Path caFile=pem("ca.pem",ca.certificate),certificate=pem("server.pem",server.certificate),key=pem("server-key.pem",server.key.getPrivate());
  String image=postgres?"postgres:17.11":engine==Engine.MYSQL?"mysql:8.4.10":"mariadb:11.8.9";
  try(var db=new GenericContainer<>(DockerImageName.parse(image)).withExposedPorts(port).withStartupTimeout(Duration.ofMinutes(3))
    .withCopyFileToContainer(MountableFile.forHostPath(caFile,0644),"/tls/ca.pem").withCopyFileToContainer(MountableFile.forHostPath(certificate,0644),"/tls/server.pem").withCopyFileToContainer(MountableFile.forHostPath(key,0600),"/tls/server-key.pem");
    var ssh=SshServer.setUpDefaultServer()){
   db.withCreateContainerCmdModifier(command->command.withEntrypoint("bash","-c"));
   if(postgres)db.withEnv("POSTGRES_USER","busydata").withEnv("POSTGRES_PASSWORD","database-fixture").withEnv("POSTGRES_DB","busydata").withCommand(new String[]{"chown postgres:postgres /tls/server-key.pem; exec docker-entrypoint.sh postgres -c ssl=on -c ssl_cert_file=/tls/server.pem -c ssl_key_file=/tls/server-key.pem -c ssl_ca_file=/tls/ca.pem"}).waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\n",2));
   else db.withEnv(engine==Engine.MYSQL?"MYSQL_ROOT_PASSWORD":"MARIADB_ROOT_PASSWORD","database-fixture").withEnv(engine==Engine.MYSQL?"MYSQL_DATABASE":"MARIADB_DATABASE","busydata").withCommand(new String[]{"chown mysql:mysql /tls/server-key.pem; exec docker-entrypoint.sh "+(engine==Engine.MYSQL?"mysqld":"mariadbd")+" --ssl-ca=/tls/ca.pem --ssl-cert=/tls/server.pem --ssl-key=/tls/server-key.pem --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci"}).waitingFor(engine==Engine.MARIADB?Wait.forLogMessage(".*ready for connections.*\\n",2):Wait.forListeningPort());
   db.start();var hostKey=identity("SSH fixture",null,true).key;
   ssh.setHost("127.0.0.1");ssh.setPort(0);ssh.setKeyPairProvider(context->List.of(hostKey));ssh.setPasswordAuthenticator((user,password,session)->user.equals("selected")&&password.equals("independent-ssh-fixture"));ssh.setForwardingFilter(AcceptAllForwardingFilter.INSTANCE);ssh.start();
   Path known=root.resolve("known_hosts");Files.writeString(known,"[127.0.0.1]:"+ssh.getPort()+" "+PublicKeyEntry.toString(hostKey.getPublic())+"\n");
   var profile=Profile.newBuilder().setId("native-tls").setName("Disposable native TLS/SSH fixture").setEngine(engine).setHost("localhost").setPort(db.getMappedPort(port)).setDatabase("busydata").setUser(postgres?"busydata":"root").setTls(Tls.newBuilder().setMode(TlsMode.VERIFY_FULL).setCaFile(caFile.toString()).setJavaTrust(true).setSystemTrust(true)).setConnectTimeoutSeconds(10).setQueryTimeoutSeconds(60).build();
   try(var sessions=new SessionRegistry(PrivateTemporaryFiles.isolated());var metadata=new MetadataStore(root);var results=new ResultStore(root,16L*1024*1024)){
    var analysis=new SqlAnalysis();var safety=new Safety(analysis);try(var jobs=new Jobs(results,metadata,analysis,safety)){
     var direct=sessions.open(OpenRequest.newBuilder().setProfile(profile).setPassword("database-fixture").build());
     assertThrows(Exception.class,()->sessions.open(OpenRequest.newBuilder().setProfile(profile.toBuilder().setHost("127.0.0.1")).setPassword("database-fixture").build()),"Loopback address must not match the DNS-only database certificate");
     var tunneled=sessions.open(OpenRequest.newBuilder().setProfile(profile.toBuilder().setSsh(Ssh.newBuilder().setEnabled(true).setHost("127.0.0.1").setPort(ssh.getPort()).setUser("selected").setKnownHosts(known.toString()))).setPassword("database-fixture").setSshPassword("independent-ssh-fixture").build());
     try(var statement=direct.connection.createStatement()){statement.execute("CREATE TABLE native_tls(id INTEGER PRIMARY KEY,t VARCHAR(100))");statement.execute("INSERT INTO native_tls VALUES(1,'verified 漢')");}
     Path tools=Path.of(System.getProperty("busydata.native.tools.root",Path.of(System.getProperty("basedir")).resolve("target/native-tools").toString())).resolve(name.toLowerCase(Locale.ROOT));if(Files.isDirectory(tools.resolve("bin")))tools=tools.resolve("bin");
     var transfers=new Transfers(results,new NativeToolTransport(Path.of(System.getProperty("basedir")).resolve("target/native-build")));
     Path file=root.resolve("TLS 漢 through SSH.sql");
     var dump=ToolRequest.newBuilder().setKind(ToolKind.DUMP).setPath(file.toString()).setNativeToolPath(tools.resolve(postgres?"pg_dump":engine==Engine.MYSQL?"mysqldump":"mariadb-dump").toString()).build();
     var job=jobs.submit(tunneled,UUID.randomUUID().toString(),"",operation->transfers.run(operation,dump));assertEquals(JobState.COMPLETED,job.finished.get(60,TimeUnit.SECONDS).getState(),job.info().toString());
     try(var statement=direct.connection.createStatement()){statement.execute("DROP TABLE native_tls");}
     var restore=dump.toBuilder().setKind(ToolKind.RESTORE).setNativeToolPath(tools.resolve(postgres?"psql":engine==Engine.MYSQL?"mysql":"mariadb").toString()).build();
     job=jobs.submit(tunneled,UUID.randomUUID().toString(),"",operation->transfers.run(operation,restore));assertEquals(JobState.COMPLETED,job.finished.get(60,TimeUnit.SECONDS).getState(),job.info().toString());
     try(var statement=direct.connection.createStatement();var row=statement.executeQuery("SELECT id,t FROM native_tls")){assertTrue(row.next());assertEquals(1,row.getInt(1));assertEquals("verified 漢",row.getString(2));assertFalse(row.next());}
    }
   }
  }
 }
}
