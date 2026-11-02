package io.busystack.busydata;

import com.google.gson.Gson;
import io.busystack.busydata.results.ResultStore;
import java.nio.file.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.math.BigInteger;
import java.time.Duration;
import java.util.*;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.*;
import org.bouncycastle.cert.jcajce.*;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.openssl.jcajce.JcaPEMWriter;
import org.apache.sshd.server.SshServer;
import org.apache.sshd.server.forward.AcceptAllForwardingFilter;
import org.apache.sshd.common.config.keys.KeyUtils;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.*;

/** External disposable test infrastructure. Never included in the product jar. */
public final class InstalledPackageFixture {
    private record Identity(KeyPair key,X509Certificate certificate){}
    private static KeyPair key()throws Exception {var generator=KeyPairGenerator.getInstance("RSA");generator.initialize(2048);return generator.generateKeyPair();}
    private static Identity identity(String name,Identity issuer,boolean authority)throws Exception {
        var key=key();var subject=new X500Name("CN="+name);long now=System.currentTimeMillis();
        var builder=new JcaX509v3CertificateBuilder(issuer==null?subject:new X500Name(issuer.certificate.getSubjectX500Principal().getName()),new BigInteger(120,new SecureRandom()),new Date(now-60000),new Date(now+86400000),subject,key.getPublic());
        builder.addExtension(Extension.basicConstraints,true,new BasicConstraints(authority));
        builder.addExtension(Extension.keyUsage,true,new KeyUsage(authority?KeyUsage.keyCertSign|KeyUsage.cRLSign:KeyUsage.digitalSignature|KeyUsage.keyEncipherment));
        if(!authority){builder.addExtension(Extension.extendedKeyUsage,false,new ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuth));builder.addExtension(Extension.subjectAlternativeName,false,new GeneralNames(new GeneralName(GeneralName.dNSName,"localhost")));}
        var signer=new JcaContentSignerBuilder("SHA256withRSA").build(issuer==null?key.getPrivate():issuer.key.getPrivate());
        return new Identity(key,new JcaX509CertificateConverter().getCertificate(builder.build(signer)));
    }
    private static Path pem(Path root,String name,Object value)throws Exception {Path file=root.resolve(name);Files.createFile(file);ResultStore.privateFile(file);try(var writer=new JcaPEMWriter(Files.newBufferedWriter(file))){writer.writeObject(value);}return file;}
    public static void main(String[] arguments)throws Exception {
        if(arguments.length!=1)throw new IllegalArgumentException("One private disposable fixture directory is required");
        Path root=Path.of(arguments[0]).toAbsolutePath();Files.createDirectories(root);ResultStore.privateDirectory(root);
        var databases=new ArrayList<GenericContainer<?>>();var ssh=SshServer.setUpDefaultServer();
        try {
            var ca=identity("Installed fixture CA",null,true);var server=identity("localhost",ca,false);
            Path caFile=pem(root,"ca.pem",ca.certificate),certificate=pem(root,"server.pem",server.certificate),serverKey=pem(root,"server-key.pem",server.key.getPrivate());
            pem(root,"unrelated-ca.pem",identity("Unrelated fixture CA",null,true).certificate);
            var selected=key();pem(root,"selected-key",selected);
            var hostKey=new java.util.concurrent.atomic.AtomicReference<>(key());ssh.setHost("127.0.0.1");ssh.setPort(0);ssh.setKeyPairProvider(context->List.of(hostKey.get()));
            ssh.setPasswordAuthenticator((user,password,session)->user.equals("selected")&&password.equals("installed-ssh-fixture"));
            ssh.setPublickeyAuthenticator((user,key,session)->user.equals("selected")&&KeyUtils.compareKeys(key,selected.getPublic()));
            ssh.setForwardingFilter(AcceptAllForwardingFilter.INSTANCE);ssh.start();
            var engines=new ArrayList<Map<String,Object>>();
            for(String engine:List.of("POSTGRESQL","MYSQL","MARIADB")) {
                boolean postgres=engine.equals("POSTGRESQL");int port=postgres?5432:3306;
                String image=postgres?"postgres:17.11":engine.equals("MYSQL")?"mysql:8.4.10":"mariadb:11.8.9";
                var database=new GenericContainer<>(DockerImageName.parse(image)).withExposedPorts(port)
                    .withCopyFileToContainer(MountableFile.forHostPath(caFile,0644),"/tls/ca.pem").withCopyFileToContainer(MountableFile.forHostPath(certificate,0644),"/tls/server.pem").withCopyFileToContainer(MountableFile.forHostPath(serverKey,0600),"/tls/server-key.pem")
                    .withCreateContainerCmdModifier(command->command.withEntrypoint("bash","-c"));
                databases.add(database);
                if(postgres)database.withEnv("POSTGRES_USER","busydata").withEnv("POSTGRES_PASSWORD","installed-database-fixture").withEnv("POSTGRES_DB","busydata").withCommand(new String[]{"chown postgres:postgres /tls/server-key.pem; exec docker-entrypoint.sh postgres -c ssl=on -c ssl_cert_file=/tls/server.pem -c ssl_key_file=/tls/server-key.pem -c ssl_ca_file=/tls/ca.pem"}).waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\n",2));
                else database.withEnv(engine.equals("MYSQL")?"MYSQL_ROOT_PASSWORD":"MARIADB_ROOT_PASSWORD","installed-database-fixture").withEnv(engine.equals("MYSQL")?"MYSQL_DATABASE":"MARIADB_DATABASE","busydata").withCommand(new String[]{"chown mysql:mysql /tls/server-key.pem; exec docker-entrypoint.sh "+(engine.equals("MYSQL")?"mysqld":"mariadbd")+" --ssl-ca=/tls/ca.pem --ssl-cert=/tls/server.pem --ssl-key=/tls/server-key.pem --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci"}).waitingFor(engine.equals("MARIADB")?Wait.forLogMessage(".*ready for connections.*\\n",2):Wait.forListeningPort());
                database.withStartupTimeout(Duration.ofMinutes(3));
                database.start();engines.add(Map.of("engine",engine,"port",database.getMappedPort(port),"image",image,"imageId",database.getDockerClient().inspectImageCmd(image).exec().getId()));
            }
            System.out.println(new Gson().toJson(Map.of("version",1,"root",root.toString(),"engines",engines,"sshPort",ssh.getPort(),"selectedFingerprint",KeyUtils.getFingerPrint(selected.getPublic()))));System.out.flush();
            // EOF owns shutdown. No public listener or product-control endpoint.
            var input=new java.io.BufferedReader(new java.io.InputStreamReader(System.in,java.nio.charset.StandardCharsets.UTF_8));
            for(String command;(command=input.readLine())!=null;) {
                if(!command.equals("rotate-host-key"))throw new IllegalArgumentException("Unknown fixture control");
                hostKey.set(key());
                Files.writeString(root.resolve("host-key-rotated"),"ready\n");
            }
        }finally {
            ssh.close();for(var database:databases.reversed())database.close();
        }
    }
}
