package io.busystack.busydata.security;

/** An acknowledged false SSH authentication result, without server messages. */
public final class SshAuthenticationFailure extends java.io.IOException {
    public SshAuthenticationFailure(){super("SSH authentication rejected");}
}
