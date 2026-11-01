package io.busystack.busydata.rpc;

import io.grpc.Metadata;
import io.grpc.Status;
import io.grpc.StatusRuntimeException;
import java.sql.SQLException;
import java.net.ConnectException;
import java.net.UnknownHostException;
import java.security.cert.CertificateException;
import java.security.cert.CertPathValidatorException;
import javax.net.ssl.SSLPeerUnverifiedException;

/** Narrow connection-only diagnostics. Never forwards driver/server messages. */
public final class ConnectionErrors {
    private ConnectionErrors() {}
    private static final Metadata.Key<String> REASON = Metadata.Key.of("busydata-connection-reason", Metadata.ASCII_STRING_MARSHALLER);
    public static StatusRuntimeException safe(Exception error) {
        if(error instanceof io.busystack.busydata.security.TlsMaterialFailure material) {
            var metadata=new Metadata();metadata.put(REASON,"tls-material");
            metadata.put(Metadata.Key.of("busydata-tls-material",Metadata.ASCII_STRING_MARSHALLER),material.reason().name());
            return Status.INVALID_ARGUMENT.withDescription("TLS material configuration requires correction").asRuntimeException(metadata);
        }
        String reason = "rejected";
        Status status = Status.UNAVAILABLE;
        for (Throwable cause = error; cause != null; cause = cause.getCause()) {
            if(cause instanceof io.busystack.busydata.security.SshAuthenticationFailure){reason="ssh-authentication";status=Status.PERMISSION_DENIED;break;}
            if(cause instanceof java.net.SocketTimeoutException){status=Status.DEADLINE_EXCEEDED;}
            if (cause instanceof CertificateException || cause instanceof CertPathValidatorException || cause instanceof SSLPeerUnverifiedException) { reason = "tls-verification"; break; }
            if (cause instanceof org.apache.sshd.common.SshException ssh && ssh.getDisconnectCode() == org.apache.sshd.common.SshConstants.SSH2_DISCONNECT_HOST_KEY_NOT_VERIFIABLE) { reason = "ssh-host-key"; break; }
            if (cause instanceof SQLException sql && sql.getSQLState() != null && sql.getSQLState().startsWith("28")) { reason = "authentication"; status = Status.PERMISSION_DENIED; break; }
            if (cause instanceof ConnectException || cause instanceof UnknownHostException) reason = "endpoint";
        }
        if (error instanceof java.util.concurrent.CancellationException) status = Status.CANCELLED;
        else if (error instanceof IllegalArgumentException) status = Status.INVALID_ARGUMENT;
        else if (error instanceof IllegalStateException) status = Status.FAILED_PRECONDITION;
        var metadata = new Metadata(); metadata.put(REASON, reason);
        return status.withDescription("Connection attempt failed; review the endpoint, credentials and SSH/SSL settings.").asRuntimeException(metadata);
    }
}
