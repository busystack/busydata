import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/common/database_secrets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

class Secrets implements DatabaseSecrets {
  final values = <String, String>{'working': 'working-secret'};
  final deleted = <String>[];
  @override
  Future<String?> read(String ref) async => values[ref];
  @override
  Future<void> write(String ref, String password) async {
    values[ref] = password;
  }

  @override
  Future<void> delete(String ref) async {
    deleted.add(ref);
    values.remove(ref);
  }
}

void main() {
  late Directory root;
  late TestBackend backend;
  late Secrets secrets;
  late WorkbenchModel model;
  final original = Profile(
    id: 'profile',
    name: 'Original',
    credentialRef: 'working',
  );
  test(
    'TLS client key uses a separate consented binding and unrelated saves retain it',
    () async {
      final profile = original.deepCopy()
        ..tls = Tls(
          clientKey: '/selected/encrypted.pem',
          keyCredentialRef: 'old-tls',
        );
      secrets.values['old-tls'] = 'old key password';
      final saved = await model.saveProfileCredentials(
        profile,
        'new database password',
        remember: true,
        tlsKeyPassword: 'new key password',
        rememberTlsKey: true,
      );
      expect(saved.credentialRef, startsWith('busydata.database.'));
      expect(saved.tls.keyCredentialRef, startsWith('busydata.tls-key.'));
      expect(saved.tls.keyCredentialRef, isNot(saved.credentialRef));
      expect(secrets.values[saved.tls.keyCredentialRef], 'new key password');
      expect(secrets.deleted, containsAll(['working', 'old-tls']));
      final preserved = await model.saveProfileCredentials(
        saved,
        '',
        remember: true,
      );
      expect(preserved.tls.keyCredentialRef, saved.tls.keyCredentialRef);
      final cleared = await model.saveProfileCredentials(
        preserved,
        '',
        remember: true,
        rememberTlsKey: false,
      );
      expect(cleared.tls.keyCredentialRef, isEmpty);
      expect(secrets.deleted, contains(saved.tls.keyCredentialRef));
    },
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp(
      'busydata-credential-adoption-',
    );
    backend = TestBackend();
    secrets = Secrets();
    model = WorkbenchModel(root, secrets: secrets)..backend = backend;
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });
  test(
    'failed confirmed profile replacement preserves the working profile and credential',
    () async {
      backend.client.profileAction = (r) async {
        if (r.action == ProfileAction.SAVE_PROFILE) {
          throw StateError('Injected persistence failure');
        }
        return ProfileList(profiles: [original]);
      };
      await expectLater(
        model.saveProfileCredentials(
          original.deepCopy()..name = 'Changed',
          'replacement',
          remember: true,
        ),
        throwsStateError,
      );
      expect(secrets.values, {'working': 'working-secret'});
      expect(secrets.deleted, hasLength(1));
      expect(secrets.deleted.single, isNot('working'));
      expect(original.name, 'Original');
      expect(original.credentialRef, 'working');
    },
  );
  test(
    'lost acknowledgement reconciles the exact saved profile before deleting an obsolete credential',
    () async {
      Profile? saved;
      backend.client.profileAction = (r) async {
        if (r.action == ProfileAction.SAVE_PROFILE) {
          saved = r.profile.deepCopy();
          throw StateError('Lost response');
        }
        return ProfileList(profiles: [saved!]);
      };
      final result = await model.saveProfileCredentials(
        original,
        'replacement',
        remember: true,
      );
      expect(result, saved);
      expect(secrets.values, {result.credentialRef: 'replacement'});
      expect(secrets.deleted, ['working']);
      expect(model.profiles.single, result);
    },
  );
  test(
    'unavailable reconciliation keeps both credentials and requires an explicit later decision',
    () async {
      backend.client.profileAction = (r) async =>
          throw StateError('Backend unavailable');
      await expectLater(
        model.saveProfileCredentials(original, 'replacement', remember: true),
        throwsA(isA<ProfileSaveUncertain>()),
      );
      expect(
        secrets.values.values,
        containsAll(['working-secret', 'replacement']),
      );
      expect(secrets.deleted, isEmpty);
      expect(original.credentialRef, 'working');
    },
  );
  test(
    'empty password editing retains the binding and overlapping saves capture immutable profile values',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      var saves = 0;
      backend.client.profileAction = (r) async {
        if (r.action == ProfileAction.SAVE_PROFILE && saves++ == 0) {
          entered.complete();
          await release.future;
        }
        return ProfileList(profiles: [r.profile]);
      };
      final first = model.saveProfileCredentials(original, '', remember: true);
      await entered.future;
      final changing = original.deepCopy()..name = 'Captured';
      final second = model.saveProfileCredentials(changing, '', remember: true);
      changing.name = 'Later editor value';
      release.complete();
      await first;
      await second;
      expect(backend.client.profileRequests.map((r) => r.profile.name), [
        'Original',
        'Captured',
      ]);
      expect(secrets.values, {'working': 'working-secret'});
      expect(secrets.deleted, isEmpty);
    },
  );
}
