package io.busystack.busydata;

import io.busystack.busydata.adapters.JdbcAdapter;
import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import java.nio.file.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.math.BigInteger;
import java.util.*;
import java.time.Duration;
import org.bouncycastle.asn1.x500.X500Name;
import org.bouncycastle.asn1.x509.*;
import org.bouncycastle.cert.jcajce.*;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.openssl.jcajce.JcaPEMWriter;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.wait.strategy.Wait;
import org.testcontainers.utility.*;
import org.junit.jupiter.api.io.TempDir;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import static org.junit.jupiter.api.Assertions.*;

class DatabaseTlsIT {
    @TempDir Path root;
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void freshDriverDefaultsUseActualEngineNegotiationAndIgnoreDormantFiles(String name)throws Exception {
        try(var fixture=new EngineFixture(root,name)) {
            var selected=fixture.profile.toBuilder().setTls(Tls.newBuilder().setMode(TlsMode.DRIVER_DEFAULT)
                .setCaFile("/missing/dormant-ca").setClientCert("/missing/dormant-cert").setClientKey("/missing/dormant-key"));
            var session=fixture.sessions.open(OpenRequest.newBuilder().setProfile(selected).setPassword("fixture").build());
            try(var statement=session.connection.createStatement()) {
                if(fixture.engine==Engine.POSTGRESQL) {
                    try(var rows=statement.executeQuery("SELECT ssl FROM pg_stat_ssl WHERE pid=pg_backend_pid()")) {
                        assertTrue(rows.next());assertFalse(rows.getBoolean(1),"The ordinary PostgreSQL fixture has no TLS configured");
                    }
                } else {
                    try(var rows=statement.executeQuery("SHOW SESSION STATUS LIKE 'Ssl_cipher'")) {
                        assertTrue(rows.next());assertEquals(fixture.engine==Engine.MYSQL,!rows.getString(2).isEmpty(),
                            "MySQL defaults negotiate its ordinary server TLS; MariaDB defaults disable TLS");
                    }
                }
            }
        }
    }
    @ParameterizedTest @ValueSource(strings={"POSTGRESQL","MYSQL","MARIADB"})
    void explicitRequireCannotConnectToAnUnencryptedServer(String name)throws Exception {
        try(var fixture=new EngineFixture(root,name,database->{
            if(name.equals("POSTGRESQL")) database.withCommand("postgres","-c","ssl=off");
            else database.withCommand("--character-set-server=utf8mb4","--collation-server=utf8mb4_unicode_ci","--ssl=OFF");
        })) {
            var request=OpenRequest.newBuilder().setPassword("fixture").setProfile(fixture.profile.toBuilder()
                .setTls(Tls.newBuilder().setMode(TlsMode.INSECURE))).build();
            assertThrows(java.sql.SQLException.class,()->fixture.sessions.open(request));
        }
    }
    private record Identity(KeyPair pair, X509Certificate certificate) {}
    private Identity identity(String name, Identity issuer, boolean authority, boolean server) throws Exception {
        var generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048); var pair = generator.generateKeyPair();
        var subject = new X500Name("CN=" + name); long now = System.currentTimeMillis();
        var builder = new JcaX509v3CertificateBuilder(issuer == null ? subject : new X500Name(issuer.certificate.getSubjectX500Principal().getName()), new BigInteger(120, new SecureRandom()), new Date(now - 60000), new Date(now + 86400000), subject, pair.getPublic());
        builder.addExtension(Extension.basicConstraints, true, new BasicConstraints(authority));
        builder.addExtension(Extension.keyUsage, true, new KeyUsage(authority ? KeyUsage.keyCertSign | KeyUsage.cRLSign : KeyUsage.digitalSignature | KeyUsage.keyEncipherment));
        if (!authority) builder.addExtension(Extension.extendedKeyUsage, false, new ExtendedKeyUsage(server ? KeyPurposeId.id_kp_serverAuth : KeyPurposeId.id_kp_clientAuth));
        if (server) builder.addExtension(Extension.subjectAlternativeName, false, new GeneralNames(new GeneralName(GeneralName.iPAddress, "127.0.0.1")));
        var signer = new JcaContentSignerBuilder("SHA256withRSA").build(issuer == null ? pair.getPrivate() : issuer.pair.getPrivate());
        return new Identity(pair, new JcaX509CertificateConverter().getCertificate(builder.build(signer)));
    }
    private Path pem(String name, Object value) throws Exception {
        Path file = root.resolve(name); Files.createFile(file); ResultStore.privateFile(file);
        try (var writer = new JcaPEMWriter(Files.newBufferedWriter(file))) { writer.writeObject(value); }
        return file;
    }
    private Path encrypted(String name,PrivateKey key,boolean pkcs8) throws Exception {
        Path path=root.resolve(name);var provider=new org.bouncycastle.jce.provider.BouncyCastleProvider();
        try(var writer=new JcaPEMWriter(Files.newBufferedWriter(path))) {
            if(pkcs8) {
                var encryptor=new org.bouncycastle.openssl.jcajce.JceOpenSSLPKCS8EncryptorBuilder(org.bouncycastle.openssl.PKCS8Generator.AES_256_CBC).setProvider(provider).setRandom(new SecureRandom()).setPassword("selected-tls-key-password".toCharArray()).setIterationCount(2048).build();
                writer.writeObject(new org.bouncycastle.openssl.jcajce.JcaPKCS8Generator(key,encryptor));
            } else writer.writeObject(key,new org.bouncycastle.openssl.jcajce.JcePEMEncryptorBuilder("AES-256-CBC").setProvider(provider).build("selected-tls-key-password".toCharArray()));
        }
        ResultStore.privateFile(path);return path;
    }
    private void encryptedClient(JdbcAdapter adapter,OpenRequest request,Profile profile,Path cert,PrivateKey key) throws Exception {
        for(boolean pkcs8:new boolean[]{true,false}) {
            Path encrypted=encrypted(pkcs8?"client-encrypted-pkcs8.pem":"client-encrypted-openssl.pem",key,pkcs8);
            var selected=profile.toBuilder().setTls(profile.getTls().toBuilder().setClientCert(cert.toString()).setClientKey(encrypted.toString())).build();
            var protectedRequest=request.toBuilder().setProfile(selected).setTlsKeyPassword("selected-tls-key-password").build();
            try(var connection=adapter.connect(protectedRequest,null);var statement=connection.createStatement();var rows=statement.executeQuery("SELECT 3")) {assertTrue(rows.next());assertEquals(3,rows.getInt(1));}
            assertThrows(Exception.class,()->adapter.connect(protectedRequest.toBuilder().setTlsKeyPassword("incorrect").build(),null));
            assertThrows(Exception.class,()->adapter.connect(protectedRequest.toBuilder().clearTlsKeyPassword().build(),null));
        }
    }
    @ParameterizedTest @ValueSource(strings = {"POSTGRESQL", "MYSQL", "MARIADB"})
    void certificatesHostnamesAndSelectedClientIdentity(String engineName) throws Exception {
        Engine engine = Engine.valueOf(engineName); Identity ca = identity("Fixture CA", null, true, false), server = identity("Fixture server", ca, false, true), client = identity("busydata", ca, false, false);
        Path caFile = pem("ca.pem", ca.certificate), serverCert = pem("server.pem", server.certificate), serverKey = pem("server-key.pem", server.pair.getPrivate());
        Path clientCert = pem("client.pem", client.certificate), clientKey = pem("client-key.pem", client.pair.getPrivate()), badCa = pem("unrelated.pem", identity("Other CA", null, true, false).certificate);
        int port = engine == Engine.POSTGRESQL ? 5432 : 3306;
        String image = engine == Engine.POSTGRESQL ? "postgres:17.11" : engine == Engine.MYSQL ? "mysql:8.4.10" : "mariadb:11.8.9";
        try (var database = new GenericContainer<>(DockerImageName.parse(image)).withExposedPorts(port)
                .withCopyFileToContainer(MountableFile.forHostPath(caFile, 0644), "/tls/ca.pem")
                .withCopyFileToContainer(MountableFile.forHostPath(serverCert, 0644), "/tls/server.pem")
                .withCopyFileToContainer(MountableFile.forHostPath(serverKey, 0600), "/tls/server-key.pem")) {
            if (engine == Engine.POSTGRESQL) database.withEnv("POSTGRES_USER", "busydata").withEnv("POSTGRES_PASSWORD", "fixture-password").withEnv("POSTGRES_DB", "busydata")
                .withCreateContainerCmdModifier(cmd -> cmd.withEntrypoint("bash", "-c"))
                .withCommand(new String[]{"chown postgres:postgres /tls/server-key.pem; exec docker-entrypoint.sh postgres -c ssl=on -c ssl_cert_file=/tls/server.pem -c ssl_key_file=/tls/server-key.pem -c ssl_ca_file=/tls/ca.pem"})
                .waitingFor(Wait.forLogMessage(".*database system is ready to accept connections.*\\n", 2));
            else database.withEnv(engine == Engine.MYSQL ? "MYSQL_ROOT_PASSWORD" : "MARIADB_ROOT_PASSWORD", "fixture-password").withEnv(engine == Engine.MYSQL ? "MYSQL_DATABASE" : "MARIADB_DATABASE", "busydata")
                .withCreateContainerCmdModifier(cmd -> cmd.withEntrypoint("bash", "-c"))
                .withCommand(new String[]{"chown mysql:mysql /tls/server-key.pem; exec docker-entrypoint.sh "+(engine==Engine.MARIADB?"mariadbd":"mysqld")+" --ssl-ca=/tls/ca.pem --ssl-cert=/tls/server.pem --ssl-key=/tls/server-key.pem"})
                .waitingFor(engine == Engine.MARIADB ? Wait.forLogMessage(".*ready for connections.*\\n", 2) : Wait.forListeningPort());
            database.withStartupTimeout(Duration.ofMinutes(3));
            try {database.start();}catch(Exception failure){Files.writeString(Path.of(System.getProperty("basedir")).resolve("target/tls-"+engine+".log"),database.getLogs());throw failure;}
            Profile profile = Profile.newBuilder().setId("tls").setName("Disposable TLS fixture").setEngine(engine).setHost("127.0.0.1").setPort(database.getMappedPort(port)).setDatabase("busydata").setUser(engine == Engine.POSTGRESQL ? "busydata" : "root").setConnectTimeoutSeconds(5).setTls(Tls.newBuilder().setMode(TlsMode.VERIFY_FULL).setCaFile(caFile.toString())).build();
            try(var scratch=new io.busystack.busydata.security.PrivateTemporaryFiles(root.resolve("tls-scratch"))) {
            JdbcAdapter adapter = new JdbcAdapter(engine,scratch); OpenRequest request = OpenRequest.newBuilder().setProfile(profile).setPassword("fixture-password").build();
            java.sql.Connection connection = null; Exception last = null;
            for (int attempt = 0; attempt < 30; attempt++) {
                try { connection = adapter.connect(request, null); break; } catch (Exception error) { last = error; Thread.sleep(1000); }
            }
            if (connection == null) { Files.writeString(Path.of(System.getProperty("basedir")).resolve("target/tls-"+engine+".log"), database.getLogs()); throw last; }
            try (var ready = connection; var statement = ready.createStatement(); var rows = statement.executeQuery("SELECT 1")) { assertTrue(rows.next()); }
            // Driver-owned cancellation may need a fresh verified handshake
            // after the initial handshake's private TLS scratch was removed.
            try(var sessions=new io.busystack.busydata.sessions.SessionRegistry(new io.busystack.busydata.security.PrivateTemporaryFiles(root.resolve("cancel-scratch")));
                    var metadata=new io.busystack.busydata.storage.MetadataStore(root.resolve("cancel-metadata"));
                    var results=new io.busystack.busydata.results.ResultStore(root.resolve("cancel-results"),64L*1024*1024)) {
                var analysis=new io.busystack.busydata.analysis.SqlAnalysis();
                var safety=new io.busystack.busydata.safety.Safety(analysis);
                try(var jobs=new io.busystack.busydata.jobs.Jobs(results,metadata,analysis,safety)) {
                    CancellationControlIT.assertPromptCancellation(sessions,jobs,safety,results,request);
                }
            }
            Profile trusted = profile;
            for(boolean system:new boolean[]{false,true}) {
                var publicRoots=profile.toBuilder().setTls(Tls.newBuilder().setMode(TlsMode.VERIFY_FULL)
                    .setJavaTrust(!system).setSystemTrust(system)).build();
                assertThrows(Exception.class,()->adapter.connect(request.toBuilder().setProfile(publicRoots).build(),null),
                    "The unselected fixture CA cannot be substituted for public Java/System roots");
            }
            var caOnly=request.toBuilder().setProfile(profile.toBuilder().setHost("localhost").setTls(profile.getTls().toBuilder().setMode(TlsMode.VERIFY_CA))).build();
            try(var caVerified=adapter.connect(caOnly,null);var statement=caVerified.createStatement();var rows=statement.executeQuery("SELECT 1")){assertTrue(rows.next());}
            encryptedClient(adapter,request,profile,clientCert,client.pair.getPrivate());
            var inactive=profile.toBuilder().setTls(Tls.newBuilder().setMode(TlsMode.DISABLED).setCaFile("/missing/dormant-ca").setClientCert("/missing/dormant-cert").setClientKey("/missing/dormant-key")).build();
            var props=new java.util.Properties();try(var material=new io.busystack.busydata.security.JdbcTlsMaterial(scratch)){material.configure(inactive,props,"unused secret");}
            try(var selectedFiles=Files.list(root.resolve("tls-scratch"))){assertEquals(0,selectedFiles.count(),"Selected and decrypted TLS scratch must be removed after success/error");}
            var badCertificate=assertThrows(Exception.class, () -> adapter.connect(request.toBuilder().setProfile(trusted.toBuilder().setTls(trusted.getTls().toBuilder().setCaFile(badCa.toString()))).build(), null));
            var reason=io.grpc.Metadata.Key.of("busydata-connection-reason",io.grpc.Metadata.ASCII_STRING_MARSHALLER);
            assertEquals("tls-verification",io.busystack.busydata.rpc.ConnectionErrors.safe(badCertificate).getTrailers().get(reason));
            var badPassword=assertThrows(Exception.class,()->adapter.connect(request.toBuilder().setPassword("wrong-fixture-password").build(),null));
            assertEquals("authentication",io.busystack.busydata.rpc.ConnectionErrors.safe(badPassword).getTrailers().get(reason));
            int closedPort;try(var reserved=new java.net.ServerSocket(0,1,java.net.InetAddress.getLoopbackAddress())){closedPort=reserved.getLocalPort();}
            var unreachable=assertThrows(Exception.class,()->adapter.connect(request.toBuilder().setProfile(trusted.toBuilder().setPort(closedPort)).build(),null));
            assertEquals("endpoint",io.busystack.busydata.rpc.ConnectionErrors.safe(unreachable).getTrailers().get(reason));
            assertThrows(Exception.class, () -> adapter.connect(request.toBuilder().setProfile(trusted.toBuilder().setHost("localhost")).build(), null));
            if (engine != Engine.POSTGRESQL) {
                var selected = profile.toBuilder().setTls(profile.getTls().toBuilder().setClientCert(clientCert.toString()).setClientKey(clientKey.toString())).build();
                try (var mutual = adapter.connect(request.toBuilder().setProfile(selected).build(), null); var statement = mutual.createStatement()) {
                    statement.execute("ALTER USER 'root'@'%' REQUIRE X509");
                }
                assertThrows(Exception.class, () -> adapter.connect(request, null));
                try (var mutual = adapter.connect(request.toBuilder().setProfile(selected).build(), null); var statement = mutual.createStatement(); var rows = statement.executeQuery("SELECT 2")) { assertTrue(rows.next()); assertEquals(2, rows.getInt(1)); }
                encryptedClient(adapter,request,profile,clientCert,client.pair.getPrivate());
            }else{
                var command=database.execInContainer("bash","-c","printf 'hostssl all all 0.0.0.0/0 scram-sha-256 clientcert=verify-full\\n' > /tmp/selected-hba; cat /var/lib/postgresql/data/pg_hba.conf >> /tmp/selected-hba; cp /tmp/selected-hba /var/lib/postgresql/data/pg_hba.conf; chown postgres:postgres /var/lib/postgresql/data/pg_hba.conf");assertEquals(0,command.getExitCode());
                try(var admin=adapter.connect(request,null);var statement=admin.createStatement()){statement.execute("SELECT pg_reload_conf()");}Thread.sleep(300);
                assertThrows(Exception.class,()->adapter.connect(request,null));
                var selected=profile.toBuilder().setTls(profile.getTls().toBuilder().setClientCert(clientCert.toString()).setClientKey(clientKey.toString())).build();
                try(var mutual=adapter.connect(request.toBuilder().setProfile(selected).build(),null);var statement=mutual.createStatement();var rows=statement.executeQuery("SELECT 2")){assertTrue(rows.next());assertEquals(2,rows.getInt(1));}
                encryptedClient(adapter,request,profile,clientCert,client.pair.getPrivate());
            }
            }
        }
    }
}
