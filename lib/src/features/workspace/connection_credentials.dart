/// Secrets belong to one requested operation. Database and TLS client-key
/// passwords may use their separate, explicitly authorized OS bindings. SSH
/// secrets are supplied for the operation and are never stored.
class ConnectionCredentials {
  const ConnectionCredentials({
    required this.password,
    this.sshPassword = '',
    this.keyPassphrase = '',
    this.tlsKeyPassword = '',
  });
  final String password, sshPassword, keyPassphrase, tlsKeyPassword;
}
