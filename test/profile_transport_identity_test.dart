import 'dart:convert';
import 'dart:io';

import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/backend/profile_identity.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// Serialized by the pinned Java 25 / protobuf-java 4.36.2 generated Profile
// builder with the same values as formProfile(). Java omits implicit-presence
// proto3 defaults, while the form explicitly assigns them. The optional TLS
// false and enum-zero values remain present in this cross-language fixture.
const _javaProfile =
    'CgFwEgxXaXJlIGZpeHR1cmUYASIJbG9jYWxob3N0KLgqMghidXN5ZGF0YToIYnVzeWRhdGFQClgeYggIBCgAMAFAAGoCGBZ6GwoPYXBwbGljYXRpb25OYW1lEghidXN5ZGF0YQ==';

Profile formProfile() => Profile(
  id: 'p',
  name: 'Wire fixture',
  engine: Engine.POSTGRESQL,
  host: 'localhost',
  port: 5432,
  database: 'busydata',
  user: 'busydata',
  environment: Environment.DEVELOPMENT,
  readOnly: false,
  connectTimeoutSeconds: 10,
  queryTimeoutSeconds: 30,
  credentialRef: '',
  options: const [MapEntry('applicationName', 'busydata')],
  tls: Tls(
    mode: TlsMode.DRIVER_DEFAULT,
    caFile: '',
    clientCert: '',
    clientKey: '',
    javaTrust: false,
    systemTrust: true,
    keyCredentialRef: '',
    configuredMode: TlsMode.VERIFY_FULL,
  ),
  ssh: Ssh(
    enabled: false,
    host: '',
    port: 22,
    user: '',
    knownHosts: '',
    privateKey: '',
    agent: false,
    agentSocket: '',
    agentKeyFingerprint: '',
    trustRef: '',
  ),
);

void main() {
  test('Java default-field elision preserves connection target values', () {
    final form = formProfile();
    final wire = Profile.fromBuffer(base64Decode(_javaProfile));
    expect(form.readOnly, wire.readOnly);
    expect(form.hasReadOnly(), isTrue);
    expect(wire.hasReadOnly(), isFalse);
    expect(wire.tls.hasJavaTrust(), isTrue);
    expect(wire.tls.javaTrust, isFalse);
    expect(wire.tls.hasConfiguredMode(), isTrue);
    expect(form, isNot(wire));
    expect(sameProfileConfiguration(form, wire), isTrue);
    expect(WorkbenchModel.sameConnectionTarget(form, wire), isTrue);
  });

  test(
    'Java canonical Open and Adopt retain the exact physical owner',
    () async {
      final root = await Directory.systemTemp.createTemp('profile-wire-');
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      final profile = formProfile();
      final opened = SessionInfo(
        sessionId: 'physical',
        profile: Profile.fromBuffer(base64Decode(_javaProfile)),
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        currentCatalog: 'busydata',
        transaction: TransactionState.IDLE,
      );
      backend.client.opening = (_) async => opened.deepCopy();
      backend.client.sessionCommand = (r) async =>
          opened.deepCopy()
            ..transaction = r.action == SessionAction.DISCONNECT
                ? TransactionState.DISCONNECTED
                : TransactionState.IDLE;
      addTearDown(() async {
        model.dispose();
        await root.delete(recursive: true);
      });

      await model.connectExplorer(profile, 'fixture');

      expect(model.explorerSessions[profile.id], 'physical');
      expect(
        model.sessions['physical']!.metadataSourceIdentity,
        fixtureMetadataSourceIdentity,
      );
      expect(backend.client.sessionCommands.map((r) => r.action), [
        SessionAction.ADOPT_SESSION,
      ]);
      expect(backend.client.executions, isEmpty);
    },
  );

  test('every generated profile field participates in transport identity', () {
    expect(
      Profile().info_.fieldInfo.keys,
      unorderedEquals(List.generate(15, (index) => index + 1)),
    );
    expect(
      Tls().info_.fieldInfo.keys,
      unorderedEquals(List.generate(8, (index) => index + 1)),
    );
    expect(
      Ssh().info_.fieldInfo.keys,
      unorderedEquals(List.generate(10, (index) => index + 1)),
    );
  });

  final changes = <String, void Function(Profile)>{
    'profile id': (p) => p.id = 'other',
    'display name': (p) => p.name = 'other',
    'engine': (p) => p.engine = Engine.MYSQL,
    'host': (p) => p.host = 'other',
    'port': (p) => p.port = 3306,
    'database': (p) => p.database = 'other',
    'principal': (p) => p.user = 'other',
    'environment': (p) => p.environment = Environment.PRODUCTION,
    'read-only policy': (p) => p.readOnly = true,
    'connection timeout': (p) => p.connectTimeoutSeconds = 11,
    'query timeout': (p) => p.queryTimeoutSeconds = 31,
    'credential binding': (p) => p.credentialRef = 'other',
    'option value': (p) => p.options['applicationName'] = 'other',
    'option addition': (p) => p.options['other'] = 'value',
    'TLS mode': (p) => p.tls.mode = TlsMode.DISABLED,
    'TLS CA': (p) => p.tls.caFile = 'other',
    'TLS certificate': (p) => p.tls.clientCert = 'other',
    'TLS key': (p) => p.tls.clientKey = 'other',
    'Java trust value': (p) => p.tls.javaTrust = true,
    'Java trust presence': (p) => p.tls.clearJavaTrust(),
    'system trust value': (p) => p.tls.systemTrust = false,
    'system trust presence': (p) => p.tls.clearSystemTrust(),
    'TLS key credential': (p) => p.tls.keyCredentialRef = 'other',
    'configured TLS value': (p) => p.tls.configuredMode = TlsMode.VERIFY_CA,
    'configured TLS presence': (p) => p.tls.clearConfiguredMode(),
    'SSH enabled': (p) => p.ssh.enabled = true,
    'SSH host': (p) => p.ssh.host = 'other',
    'SSH port': (p) => p.ssh.port = 23,
    'SSH principal': (p) => p.ssh.user = 'other',
    'SSH known hosts': (p) => p.ssh.knownHosts = 'other',
    'SSH private key': (p) => p.ssh.privateKey = 'other',
    'SSH agent': (p) => p.ssh.agent = true,
    'SSH agent socket': (p) => p.ssh.agentSocket = 'other',
    'SSH agent key': (p) => p.ssh.agentKeyFingerprint = 'other',
    'SSH trust binding': (p) => p.ssh.trustRef = 'other',
    'TLS message presence': (p) => p.clearTls(),
    'SSH message presence': (p) => p.clearSsh(),
    'profile unknown fields': (p) => p.unknownFields.mergeFromUnknownFieldSet(
      Profile.fromBuffer(const [248, 7, 1]).unknownFields,
    ),
    'TLS unknown fields': (p) => p.tls.unknownFields.mergeFromUnknownFieldSet(
      Tls.fromBuffer(const [248, 7, 1]).unknownFields,
    ),
    'SSH unknown fields': (p) => p.ssh.unknownFields.mergeFromUnknownFieldSet(
      Ssh.fromBuffer(const [248, 7, 1]).unknownFields,
    ),
  };
  for (final change in changes.entries) {
    test('transport identity rejects changed ${change.key}', () {
      final original = formProfile();
      final forged = original.deepCopy();
      change.value(forged);
      expect(sameProfileConfiguration(original, forged), isFalse);
      expect(sameProfileConfiguration(forged, original), isFalse);
    });
  }

  test('empty submessages and optional false values retain presence', () {
    expect(sameProfileConfiguration(Profile(), Profile(tls: Tls())), isFalse);
    expect(sameProfileConfiguration(Profile(), Profile(ssh: Ssh())), isFalse);
    expect(
      sameProfileConfiguration(
        Profile(tls: Tls(systemTrust: false)),
        Profile(tls: Tls()),
      ),
      isFalse,
    );
  });

  test('map order and ordinary scalar presence confer no new values', () {
    final a = formProfile()..options['other'] = 'value';
    final b = formProfile()
      ..options.clear()
      ..options.addAll({'other': 'value', 'applicationName': 'busydata'});
    expect(sameProfileConfiguration(a, b), isTrue);
    expect(
      sameProfileConfiguration(Profile(), Profile(readOnly: false)),
      isTrue,
    );
    expect(sameProfileConfiguration(null, null), isTrue);
    expect(sameProfileConfiguration(null, a), isFalse);
    expect(sameProfileConfiguration(a, null), isFalse);
  });
}
