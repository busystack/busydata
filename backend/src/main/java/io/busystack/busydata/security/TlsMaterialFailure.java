package io.busystack.busydata.security;

/** Allowlisted local material diagnostics, independent of provider/driver text. */
public final class TlsMaterialFailure extends IllegalArgumentException {
    public enum Reason { JAVA_ROOTS_UNAVAILABLE, SYSTEM_ROOTS_UNAVAILABLE, CLIENT_KEY_PASSWORD_OR_FORMAT, CLIENT_KEY_WORK_LIMIT, CLIENT_IDENTITY_MISMATCH }
    private final Reason reason;
    public TlsMaterialFailure(Reason reason){super("TLS material configuration requires correction");this.reason=reason;}
    public Reason reason(){return reason;}
}
