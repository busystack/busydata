package io.busystack.busydata;

import io.busystack.busydata.rpc.ConnectionErrors;
import io.grpc.Metadata;
import io.grpc.Status;
import java.sql.SQLException;
import java.security.cert.CertificateException;
import java.net.ConnectException;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ConnectionErrorsTest {
    private final Metadata.Key<String> reason = Metadata.Key.of("busydata-connection-reason", Metadata.ASCII_STRING_MARSHALLER);
    @Test void typedFailuresHaveNarrowSafeReasons() {
        assertEquals("authentication", ConnectionErrors.safe(new SQLException("secret", "28000")).getTrailers().get(reason));
        assertEquals("tls-verification", ConnectionErrors.safe(new SQLException("secret", new CertificateException("private identity"))).getTrailers().get(reason));
        assertEquals("endpoint", ConnectionErrors.safe(new ConnectException("private endpoint")).getTrailers().get(reason));
        var ssh = new org.apache.sshd.common.SshException(org.apache.sshd.common.SshConstants.SSH2_DISCONNECT_HOST_KEY_NOT_VERIFIABLE, "private key");
        assertEquals("ssh-host-key", ConnectionErrors.safe(ssh).getTrailers().get(reason));
    }
    @Test void broadRejectionDoesNotInventAuthenticationOrTlsCause() {
        var safe = ConnectionErrors.safe(new SQLException("password and certificate failed: secret", "08004"));
        assertEquals("rejected", safe.getTrailers().get(reason));
        assertEquals(Status.Code.UNAVAILABLE, safe.getStatus().getCode());
        assertFalse(safe.toString().contains("secret"));
    }
}
