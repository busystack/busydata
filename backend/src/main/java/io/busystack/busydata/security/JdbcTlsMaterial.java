package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import io.busystack.busydata.results.ResultStore;
import java.nio.file.*;
import java.security.*;
import java.security.cert.*;
import java.util.*;
import org.bouncycastle.openssl.PEMParser;
import org.bouncycastle.openssl.PEMKeyPair;
import org.bouncycastle.openssl.jcajce.JcaPEMKeyConverter;
import org.bouncycastle.asn1.pkcs.PrivateKeyInfo;

/** Profile-scoped stores for JDBC handshakes; never changes JVM-wide trust. */
public final class JdbcTlsMaterial implements AutoCloseable {
    private final PrivateTemporaryFiles temporaryFiles;
    public JdbcTlsMaterial(PrivateTemporaryFiles temporaryFiles){this.temporaryFiles=temporaryFiles;}
    private final List<Path> files = new ArrayList<>();
    private final java.util.concurrent.atomic.AtomicBoolean closed=new java.util.concurrent.atomic.AtomicBoolean();
    private final char[] password = HexFormat.of().formatHex(random()).toCharArray();
    private static byte[] random() { byte[] bytes = new byte[32]; new SecureRandom().nextBytes(bytes); return bytes; }

    public void configure(Profile profile, Properties properties) throws Exception { configure(profile,properties,""); }
    public void configure(Profile profile, Properties properties, String keyPassword) throws Exception {
        Tls tls = profile.getTls();
        properties.setProperty("fallbackToSystemKeyStore","false");
        properties.setProperty("fallbackToSystemTrustStore","false");
        if(tls.getMode()==TlsMode.DISABLED || tls.getMode()==TlsMode.DRIVER_DEFAULT) {
            properties.remove("sslrootcert");properties.remove("serverSslCert");
            properties.setProperty("sslcert","");properties.setProperty("sslkey","");
            return; // Dormant paths and secrets are never opened.
        }
        if (tls.getClientCert().isEmpty() != tls.getClientKey().isEmpty()) throw new IllegalArgumentException("Select both a client certificate and private key");
        var selected=new HashMap<String,Path>();
        for(String path:List.of(tls.getCaFile(),tls.getClientCert(),tls.getClientKey()))if(!path.isEmpty()&&!selected.containsKey(path)) {
            byte[] bytes=SelectedFiles.read(Path.of(path),"certificate/key",1_048_576);
            try{Path copy=temporaryFiles.create("busydata-tls-selected-",".pem");files.add(copy);Files.write(copy,bytes);selected.put(path,copy);}finally{Arrays.fill(bytes,(byte)0);}
        }
        boolean legacyMaria=profile.getEngine()==Engine.MARIADB && tls.getMode()==TlsMode.VERIFY_FULL && tls.getCaFile().isEmpty() && !tls.hasJavaTrust() && !tls.hasSystemTrust();
        // Preserve the pinned driver's existing Java/deferred-identity verifier
        // for saved profiles that predate explicit trust-source selection.
        if(legacyMaria) properties.setProperty("fallbackToSystemTrustStore","true");
        boolean verify=!legacyMaria && (tls.getMode()==TlsMode.VERIFY_FULL || tls.getMode()==TlsMode.VERIFY_CA);
        if(verify) {
            var roots=roots(tls,tls.getCaFile().isEmpty()?null:selected.get(tls.getCaFile()));
            if(profile.getEngine()==Engine.MYSQL) {
                KeyStore trust=KeyStore.getInstance("PKCS12");trust.load(null,password);int index=0;
                for(var root:roots) trust.setCertificateEntry("ca-"+index++,root);
                Path file=store(trust);
                properties.setProperty("trustCertificateKeyStoreUrl",file.toUri().toString());
                properties.setProperty("trustCertificateKeyStoreType","PKCS12");
                properties.setProperty("trustCertificateKeyStorePassword",new String(password));
                properties.setProperty("fallbackToSystemTrustStore","false");
            } else {
                Path file=pemRoots(roots);
                properties.setProperty(profile.getEngine()==Engine.POSTGRESQL?"sslrootcert":"serverSslCert",file.toString());
            }
        } else {properties.remove("sslrootcert");properties.remove("serverSslCert");}
        if(profile.getEngine()==Engine.POSTGRESQL) {
            if(!tls.getClientKey().isEmpty()) {
                var chain=certificates(selected.get(tls.getClientCert()));
                PrivateKey key=key(selected.get(tls.getClientKey()),keyPassword);match(key,chain.iterator().next());
                Path file=temporaryFiles.create("busydata-tls-",".pk8");files.add(file);
                byte[] encoded=key.getEncoded();try{Files.write(file,encoded);}finally{Arrays.fill(encoded,(byte)0);}
                properties.setProperty("sslcert",selected.get(tls.getClientCert()).toString());properties.setProperty("sslkey",file.toString());
            }
            return;
        }
        if (tls.getClientCert().isEmpty() != tls.getClientKey().isEmpty())
            throw new IllegalArgumentException("Select both a client certificate and private key");
        if (!tls.getClientKey().isEmpty()) {
            var chain = certificates(selected.get(tls.getClientCert()));
            PrivateKey key=key(selected.get(tls.getClientKey()),keyPassword);
            match(key,chain.iterator().next());
            KeyStore identity = KeyStore.getInstance("PKCS12"); identity.load(null, password);
            identity.setKeyEntry("client", key, password, chain.toArray(java.security.cert.Certificate[]::new));
            Path file = store(identity);
            if (profile.getEngine() == Engine.MYSQL) {
                properties.setProperty("clientCertificateKeyStoreUrl", file.toUri().toString());
                properties.setProperty("clientCertificateKeyStoreType", "PKCS12");
                properties.setProperty("clientCertificateKeyStorePassword", new String(password));
            } else {
                properties.setProperty("keyStore", file.toString());
                properties.setProperty("keyStoreType", "PKCS12");
                properties.setProperty("keyStorePassword", new String(password));
            }
        }
    }
    /** The same explicit root snapshot encoded for native CLI clients, never a JSSE alias. */
    public Path nativeRoots(Profile profile)throws Exception {
        Tls tls=profile.getTls();
        if(tls.getMode()!=TlsMode.VERIFY_CA && tls.getMode()!=TlsMode.VERIFY_FULL) return null;
        Path selectedCa=null;
        if(!tls.getCaFile().isEmpty()) {
            byte[] bytes=SelectedFiles.read(Path.of(tls.getCaFile()),"CA certificate",1_048_576);
            try{selectedCa=temporaryFiles.create("busydata-native-ca-",".pem");files.add(selectedCa);Files.write(selectedCa,bytes);}finally{Arrays.fill(bytes,(byte)0);}
        }
        return pemRoots(roots(tls,selectedCa));
    }
    /** Private JSSE policy for the application-owned SSH/native relay. */
    public javax.net.ssl.SSLContext nativeContext(Profile profile,Path rootSnapshot)throws Exception {
        Tls tls=profile.getTls();
        javax.net.ssl.TrustManager[] trust;
        if(tls.getMode()==TlsMode.VERIFY_CA||tls.getMode()==TlsMode.VERIFY_FULL) {
            if(rootSnapshot==null)throw new IllegalArgumentException("Verified native TLS requires the reviewed root snapshot");
            KeyStore store=KeyStore.getInstance("PKCS12");store.load(null,password);int index=0;
            byte[] bytes=TrustRoots.read(rootSnapshot);
            try {
                var roots=java.security.cert.CertificateFactory.getInstance("X.509").generateCertificates(new java.io.ByteArrayInputStream(bytes));
                if(roots.isEmpty()||roots.size()>TrustRoots.MAX_ROOTS)throw new IllegalArgumentException("Native root snapshot exceeds its certificate budget");
                for(var certificate:roots)store.setCertificateEntry("root-"+index++,certificate);
            } finally {Arrays.fill(bytes,(byte)0);}
            var factory=javax.net.ssl.TrustManagerFactory.getInstance(javax.net.ssl.TrustManagerFactory.getDefaultAlgorithm());factory.init(store);trust=factory.getTrustManagers();
        } else {
            // Explicit INSECURE / MySQL PREFERRED semantics, scoped to this
            // connection. Never installs a permissive JVM-wide trust manager.
            trust=new javax.net.ssl.TrustManager[]{new javax.net.ssl.X509TrustManager(){
                public X509Certificate[] getAcceptedIssuers(){return new X509Certificate[0];}
                public void checkClientTrusted(X509Certificate[] chain,String auth){}
                public void checkServerTrusted(X509Certificate[] chain,String auth){}
            }};
        }
        javax.net.ssl.KeyManager[] identity=null;
        boolean active=tls.getMode()!=TlsMode.DISABLED&&tls.getMode()!=TlsMode.DRIVER_DEFAULT;
        if(active&&(!tls.getClientCert().isEmpty()||!tls.getClientKey().isEmpty())) {
            if(tls.getClientCert().isEmpty()||tls.getClientKey().isEmpty())throw new IllegalArgumentException("Select both a client certificate and private key");
            var selected=new ArrayList<Path>();
            for(String name:List.of(tls.getClientCert(),tls.getClientKey())) {
                byte[] bytes=SelectedFiles.read(Path.of(name),"client identity",1_048_576);
                try{Path copy=temporaryFiles.create("busydata-native-identity-",".pem");files.add(copy);Files.write(copy,bytes);selected.add(copy);}finally{Arrays.fill(bytes,(byte)0);}
            }
            var chain=certificates(selected.getFirst());PrivateKey key=key(selected.get(1),"");match(key,chain.iterator().next());
            KeyStore store=KeyStore.getInstance("PKCS12");store.load(null,password);store.setKeyEntry("client",key,password,chain.toArray(java.security.cert.Certificate[]::new));
            var factory=javax.net.ssl.KeyManagerFactory.getInstance(javax.net.ssl.KeyManagerFactory.getDefaultAlgorithm());factory.init(store,password);identity=factory.getKeyManagers();
        }
        var context=javax.net.ssl.SSLContext.getInstance("TLS");context.init(identity,trust,new SecureRandom());return context;
    }
    private static List<java.security.cert.Certificate> roots(Tls tls,Path selectedCa)throws Exception {
        var roots=new ArrayList<java.security.cert.Certificate>();
        if(selectedCa!=null) roots.addAll(certificates(selectedCa));
        boolean javaRoots=tls.hasJavaTrust()?tls.getJavaTrust():tls.getCaFile().isEmpty();
        if(javaRoots) roots.addAll(TrustRoots.javaRoots());
        if(tls.getSystemTrust()) roots.addAll(TrustRoots.systemRoots());
        if(roots.isEmpty()) throw new IllegalArgumentException("Select a CA file or a trust source for certificate verification");
        return roots;
    }
    private Path pemRoots(Collection<? extends java.security.cert.Certificate> roots)throws Exception {
        Path file=temporaryFiles.create("busydata-tls-roots-",".pem");files.add(file);
        try(var output=Files.newBufferedWriter(file)) {
            for(var root:roots) {output.write("-----BEGIN CERTIFICATE-----\n");output.write(Base64.getMimeEncoder(64,new byte[]{'\n'}).encodeToString(root.getEncoded()));output.write("\n-----END CERTIFICATE-----\n");}
        }
        return file;
    }
    private static PrivateKey key(Path value,String supplied)throws Exception {
        char[] secret=supplied.toCharArray();
        // The pinned provider is instance-scoped: no global Security registration.
        var provider=new org.bouncycastle.jce.provider.BouncyCastleProvider();
        try(var parser=new PEMParser(Files.newBufferedReader(value))) {
            Object pem=parser.readObject();
            if(parser.readObject()!=null) throw new IllegalArgumentException("Select one PEM private key");
            var converter=new JcaPEMKeyConverter().setProvider(provider);
            if(pem instanceof org.bouncycastle.openssl.PEMEncryptedKeyPair encrypted) {
                if(secret.length==0) throw new TlsMaterialFailure(TlsMaterialFailure.Reason.CLIENT_KEY_PASSWORD_OR_FORMAT);
                pem=encrypted.decryptKeyPair(new org.bouncycastle.openssl.jcajce.JcePEMDecryptorProviderBuilder().setProvider(provider).build(secret));
            }
            if(pem instanceof org.bouncycastle.pkcs.PKCS8EncryptedPrivateKeyInfo encrypted) {
                if(secret.length==0) throw new TlsMaterialFailure(TlsMaterialFailure.Reason.CLIENT_KEY_PASSWORD_OR_FORMAT);
                boundedKdf(encrypted);
                pem=encrypted.decryptPrivateKeyInfo(new org.bouncycastle.openssl.jcajce.JceOpenSSLPKCS8DecryptorProviderBuilder().setProvider(provider).build(secret));
            }
            if(pem instanceof PEMKeyPair pair)return converter.getKeyPair(pair).getPrivate();
            if(pem instanceof PrivateKeyInfo info)return converter.getPrivateKey(info);
            throw new IllegalArgumentException("Select a PEM PKCS#8 or OpenSSL private key");
        } catch(org.bouncycastle.openssl.EncryptionException | org.bouncycastle.pkcs.PKCSException error) {
            throw new TlsMaterialFailure(TlsMaterialFailure.Reason.CLIENT_KEY_PASSWORD_OR_FORMAT);
        } finally {Arrays.fill(secret,'\0');}
    }
    private static void boundedKdf(org.bouncycastle.pkcs.PKCS8EncryptedPrivateKeyInfo encrypted) {
        var algorithm=encrypted.getEncryptionAlgorithm();
        if(algorithm.getAlgorithm().equals(org.bouncycastle.asn1.pkcs.PKCSObjectIdentifiers.id_PBES2)) {
            var kdf=org.bouncycastle.asn1.pkcs.PBES2Parameters.getInstance(algorithm.getParameters()).getKeyDerivationFunc();
            if(kdf.getAlgorithm().equals(org.bouncycastle.asn1.pkcs.PKCSObjectIdentifiers.id_PBKDF2)) {
                var parameters=org.bouncycastle.asn1.pkcs.PBKDF2Params.getInstance(kdf.getParameters());
                if(parameters.getIterationCount().signum()<=0 || parameters.getIterationCount().compareTo(java.math.BigInteger.valueOf(1_000_000))>0 || parameters.getSalt().length>1024)
                    throw new TlsMaterialFailure(TlsMaterialFailure.Reason.CLIENT_KEY_WORK_LIMIT);
            } else if(kdf.getAlgorithm().equals(org.bouncycastle.asn1.misc.MiscObjectIdentifiers.id_scrypt)) {
                var parameters=org.bouncycastle.asn1.misc.ScryptParams.getInstance(kdf.getParameters());
                if(parameters.getCostParameter().compareTo(java.math.BigInteger.valueOf(32768))>0 || parameters.getBlockSize().compareTo(java.math.BigInteger.valueOf(8))>0 || parameters.getParallelizationParameter().compareTo(java.math.BigInteger.valueOf(2))>0 || parameters.getSalt().length>1024)
                    throw new TlsMaterialFailure(TlsMaterialFailure.Reason.CLIENT_KEY_WORK_LIMIT);
            } else throw new IllegalArgumentException("Unsupported encrypted client key derivation");
        } else {
            var parameters=org.bouncycastle.asn1.pkcs.PKCS12PBEParams.getInstance(algorithm.getParameters());
            if(parameters.getIterations().signum()<=0 || parameters.getIterations().compareTo(java.math.BigInteger.valueOf(1_000_000))>0 || parameters.getIV().length>1024)
                throw new TlsMaterialFailure(TlsMaterialFailure.Reason.CLIENT_KEY_WORK_LIMIT);
        }
    }
    private static void match(PrivateKey key,java.security.cert.Certificate certificate)throws Exception {
        String algorithm=switch(key.getAlgorithm()){case "RSA"->"SHA256withRSA";case "EC","ECDSA"->"SHA256withECDSA";case "Ed25519"->"Ed25519";case "Ed448"->"Ed448";default->throw new IllegalArgumentException("Unsupported client key algorithm");};
        byte[] challenge=random();
        try {Signature proof=Signature.getInstance(algorithm);proof.initSign(key);proof.update(challenge);byte[] signature=proof.sign();
            try {proof.initVerify(certificate);proof.update(challenge);if(!proof.verify(signature))throw new TlsMaterialFailure(TlsMaterialFailure.Reason.CLIENT_IDENTITY_MISMATCH);}
            finally{Arrays.fill(signature,(byte)0);}
        }finally{Arrays.fill(challenge,(byte)0);}
    }
    private static Collection<? extends java.security.cert.Certificate> certificates(Path value) throws Exception {
        try (var input = Files.newInputStream(value)) {
            var certificates = CertificateFactory.getInstance("X.509").generateCertificates(input);
            if (certificates.size()>64)throw new IllegalArgumentException("Certificate chain exceeds 64 entries");
            if (certificates.isEmpty()) throw new IllegalArgumentException("Certificate file is empty");
            return certificates;
        }
    }
    private Path store(KeyStore store) throws Exception {
        Path file = temporaryFiles.create("busydata-tls-", ".p12"); files.add(file);
        ResultStore.privateFile(file);
        try (var output = Files.newOutputStream(file)) { store.store(output, password); }
        return file;
    }
    @Override public void close() throws Exception {
        if(!closed.compareAndSet(false,true))return;
        Arrays.fill(password, '\0');
        Exception failure=null;for(Path file:files)try{Files.deleteIfExists(file);}catch(Exception cleanup){if(failure==null)failure=cleanup;else failure.addSuppressed(cleanup);}
        if(failure!=null)throw failure;
    }
}
