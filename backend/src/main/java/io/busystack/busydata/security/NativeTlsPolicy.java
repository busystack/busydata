package io.busystack.busydata.security;

import io.busystack.busydata.protocol.*;
import java.nio.file.*;

/** Explicit native capability checks; unsupported guarantees never downgrade. */
public final class NativeTlsPolicy {
    private NativeTlsPolicy() {}
    public static String mysqlMode(TlsMode mode) {
        return switch(mode){case DISABLED->"DISABLED";case INSECURE->"REQUIRED";case VERIFY_CA->"VERIFY_CA";case VERIFY_FULL->"VERIFY_IDENTITY";case DRIVER_DEFAULT->"PREFERRED";default->throw new IllegalArgumentException("Invalid native TLS mode");};
    }
    public static String postgresMode(TlsMode mode) {
        return switch(mode){case DISABLED->"disable";case INSECURE->"require";case VERIFY_CA->"verify-ca";case VERIFY_FULL->"verify-full";case DRIVER_DEFAULT->"prefer";default->throw new IllegalArgumentException("Invalid native TLS mode");};
    }
    public static void preflight(Profile profile) throws Exception {
        Tls tls=profile.getTls();
        switch(tls.getMode()) {
            case DISABLED,DRIVER_DEFAULT -> {return;} // Dormant files are not inspected.
            case INSECURE,VERIFY_CA,VERIFY_FULL -> {}
            default -> throw new IllegalArgumentException("Invalid native TLS mode");
        }
        if(profile.getEngine()==Engine.MARIADB && (tls.getMode()==TlsMode.VERIFY_CA || tls.getMode()==TlsMode.INSECURE))
            throw new IllegalArgumentException("This MariaDB native client cannot represent the selected TLS guarantee; use a supported verified policy for this separate transfer");
        if(profile.getEngine()==Engine.MARIADB && tls.getMode()==TlsMode.VERIFY_FULL && tls.getCaFile().isEmpty() && !tls.hasJavaTrust() && !tls.hasSystemTrust())
            throw new IllegalArgumentException("The native client cannot represent this existing driver's deferred certificate verifier; select explicit trust roots for a separate native transfer");
        if(!tls.getClientKey().isEmpty()) {
            byte[] bytes=SelectedFiles.read(Path.of(tls.getClientKey()),"client key",1_048_576);
            try {
                String text=new String(bytes,java.nio.charset.StandardCharsets.US_ASCII);
                if(text.contains("ENCRYPTED")) throw new IllegalArgumentException("Encrypted client keys are supported by JDBC; this separate native transfer cannot obtain their password safely");
            } finally {java.util.Arrays.fill(bytes,(byte)0);}
        }
    }
}
