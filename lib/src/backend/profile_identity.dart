import 'generated/busydata.pb.dart';

/// Compare complete profile values across the Dart/Java protobuf boundary.
///
/// Java elides ordinary proto3 scalar defaults on the wire. Dart's generated
/// message equality also compares their in-memory presence. Those defaults
/// have no protocol presence, so compare their values explicitly. Optional
/// fields, submessages and unknown fields retain their exact presence/content.
bool sameProfileConfiguration(Profile? a, Profile? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  return a.id == b.id &&
      a.name == b.name &&
      a.engine == b.engine &&
      a.host == b.host &&
      a.port == b.port &&
      a.database == b.database &&
      a.user == b.user &&
      a.environment == b.environment &&
      a.readOnly == b.readOnly &&
      a.connectTimeoutSeconds == b.connectTimeoutSeconds &&
      a.queryTimeoutSeconds == b.queryTimeoutSeconds &&
      a.credentialRef == b.credentialRef &&
      a.options.length == b.options.length &&
      a.options.entries.every((entry) => b.options[entry.key] == entry.value) &&
      a.hasTls() == b.hasTls() &&
      (!a.hasTls() || _sameTls(a.tls, b.tls)) &&
      a.hasSsh() == b.hasSsh() &&
      (!a.hasSsh() || _sameSsh(a.ssh, b.ssh)) &&
      a.unknownFields == b.unknownFields;
}

bool _sameTls(Tls a, Tls b) =>
    a.mode == b.mode &&
    a.caFile == b.caFile &&
    a.clientCert == b.clientCert &&
    a.clientKey == b.clientKey &&
    a.hasJavaTrust() == b.hasJavaTrust() &&
    a.javaTrust == b.javaTrust &&
    a.hasSystemTrust() == b.hasSystemTrust() &&
    a.systemTrust == b.systemTrust &&
    a.keyCredentialRef == b.keyCredentialRef &&
    a.hasConfiguredMode() == b.hasConfiguredMode() &&
    a.configuredMode == b.configuredMode &&
    a.unknownFields == b.unknownFields;

bool _sameSsh(Ssh a, Ssh b) =>
    a.enabled == b.enabled &&
    a.host == b.host &&
    a.port == b.port &&
    a.user == b.user &&
    a.knownHosts == b.knownHosts &&
    a.privateKey == b.privateKey &&
    a.agent == b.agent &&
    a.agentSocket == b.agentSocket &&
    a.agentKeyFingerprint == b.agentKeyFingerprint &&
    a.trustRef == b.trustRef &&
    a.unknownFields == b.unknownFields;
