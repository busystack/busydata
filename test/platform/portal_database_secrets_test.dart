import 'dart:io';
import 'package:busydata/src/platform/linux/portal_database_secrets.dart';
import 'package:flutter_test/flutter_test.dart';

class _Portal implements SecretPortalClient {
  _Portal({this.unavailable = false});
  final bool unavailable;
  @override
  Future<PortalSecret> retrieveSecret({String? token}) async {
    if (unavailable) {
      throw const SecretStoreException(
        'unavailable',
        secretStorageUnavailableMessage,
      );
    }
    return PortalSecret(
      bytes: List<int>.filled(32, 91),
      token: 'fixture-token',
    );
  }
}

void main() {
  test(
    'credential replacement retains both write and cleanup failures without exposing diagnostics',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busydata-secret-cleanup-',
      );
      try {
        final file = File('${directory.path}/secrets.json');
        await PortalDatabaseSecrets(
          file,
          portalClient: _Portal(),
        ).write('working', 'original');
        final before = await file.readAsBytes();
        final primary = FileSystemException(
          'private injected write diagnostic',
        );
        final cleanup = FileSystemException(
          'private injected cleanup diagnostic',
        );
        final broken = PortalDatabaseSecrets(
          file,
          portalClient: _Portal(),
          replaceTemporary: (_, _) async => throw primary,
          removeTemporary: (_) async => throw cleanup,
        );
        try {
          await broken.write('working', 'replacement');
          fail('Expected a write/cleanup failure');
        } on SecretStoreException catch (failure) {
          expect(failure.primaryFailure, same(primary));
          expect(failure.cleanupFailure, same(cleanup));
          expect(failure.toString(), isNot(contains('private injected')));
          expect(failure.toString(), isNot(contains('replacement')));
        }
        expect(await file.readAsBytes(), before);
        expect(
          await PortalDatabaseSecrets(
            file,
            portalClient: _Portal(),
          ).read('working'),
          'original',
        );
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'oversized or deeply nested credential files preserve the existing record',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busydata-secret-quota-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/secrets.json');
      final store = PortalDatabaseSecrets(file, portalClient: _Portal());
      await store.write('working', 'private existing credential');
      final before = await file.readAsBytes();
      await expectLater(
        store.write('new', 'x' * 4097),
        throwsA(isA<SecretStoreException>()),
      );
      expect(await file.readAsBytes(), before);
      expect(await store.read('working'), 'private existing credential');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(8 * 1024 * 1024 + 1);
      await handle.close();
      await expectLater(
        store.read('working'),
        throwsA(
          isA<SecretStoreException>().having(
            (e) => e.code,
            'code',
            'SecretStoreResourceLimit',
          ),
        ),
      );
      expect(await file.length(), 8 * 1024 * 1024 + 1);
      await file.writeAsString('${'[' * 5}0${']' * 5}');
      await expectLater(
        store.write('new', 'value'),
        throwsA(
          isA<SecretStoreException>().having(
            (e) => e.code,
            'code',
            'SecretStoreResourceLimit',
          ),
        ),
      );
      expect(await file.readAsString(), '${'[' * 5}0${']' * 5}');
      await file.writeAsBytes(before);
      expect(await store.read('working'), 'private existing credential');
    },
  );

  test(
    'portal record encrypts passwords and serializes concurrent changes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busydata-secret-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/secrets.json');
      final store = PortalDatabaseSecrets(file, portalClient: _Portal());
      await Future.wait([
        store.write('opaque-a', 'fixture-password-a'),
        store.write('opaque-b', 'fixture-password-b'),
      ]);
      final encoded = await file.readAsString();
      expect(encoded, isNot(contains('fixture-password')));
      expect(await store.read('opaque-a'), 'fixture-password-a');
      expect(await store.read('opaque-b'), 'fixture-password-b');
      await store.delete('opaque-a');
      expect(await store.read('opaque-a'), isNull);
      expect(await store.read('opaque-b'), 'fixture-password-b');
    },
  );
  test('unavailable portal does not write plaintext fallback', () async {
    final directory = await Directory.systemTemp.createTemp(
      'busydata-secret-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/secrets.json');
    await expectLater(
      PortalDatabaseSecrets(
        file,
        portalClient: _Portal(unavailable: true),
      ).write('opaque', 'fixture-sensitive'),
      throwsA(isA<SecretStoreException>()),
    );
    expect(await file.exists(), isFalse);
  });
}
