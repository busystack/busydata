// Adapted from BusyMax bf986002; Apache-2.0. Provider records and legacy migrations excluded.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dbus/dbus.dart';
import 'package:path/path.dart' as p;
import 'package:posix/posix.dart' show chmod;
import '../common/database_secrets.dart';

const _encryptedCredentialStoreVersion = 1;
const secretStorageUnavailableMessage =
    'OS secure storage is unavailable. Select explicit session-only credentials.';

const _credentialFileLimit = 8 * 1024 * 1024;

Future<List<int>> _readCredentialBytes(File file, int limit) async {
  final handle = await file.open();
  try {
    if (await handle.length() > limit) {
      throw const SecretStoreException(
        'SecretStoreResourceLimit',
        'Encrypted credential storage exceeds its resource limit; existing credentials were preserved.',
      );
    }
    final output = BytesBuilder(copy: false);
    while (true) {
      final chunk = await handle.read(
        (limit - output.length + 1).clamp(1, 65536),
      );
      if (chunk.isEmpty) break;
      if (output.length + chunk.length > limit) {
        throw const SecretStoreException(
          'SecretStoreResourceLimit',
          'Credential storage grew beyond its resource limit; existing credentials were preserved.',
        );
      }
      output.add(chunk);
    }
    return output.takeBytes();
  } finally {
    await handle.close();
  }
}

Future<String> _readCredentialText(File file) async =>
    utf8.decode(await _readCredentialBytes(file, _credentialFileLimit));

Object? _credentialObject(String text) {
  var depth = 0, quoted = false, escaped = false;
  for (int offset = 0; offset < text.length; offset++) {
    final unit = text.codeUnitAt(offset);
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (unit == 92) {
        escaped = true;
      } else if (unit == 34) {
        quoted = false;
      }
    } else if (unit == 34) {
      quoted = true;
    } else if (unit == 123 || unit == 91) {
      if (++depth > 4) {
        throw const SecretStoreException(
          'SecretStoreResourceLimit',
          'Credential storage is excessively nested; existing credentials were preserved.',
        );
      }
    } else if (unit == 125 || unit == 93) {
      depth--;
    }
  }
  return jsonDecode(text);
}

void _validateCredential(String key, String value) {
  if (key.isEmpty || key.length > 256 || value.length > 4096) {
    throw const SecretStoreException(
      'SecretStoreResourceLimit',
      'Credential reference or value exceeds its resource limit; existing credentials were preserved.',
    );
  }
}

void _validateCredentials(Map<String, String> values) {
  if (values.length > 512) {
    throw const SecretStoreException(
      'SecretStoreResourceLimit',
      'Credential storage supports at most 512 bindings; remove unused bindings explicitly.',
    );
  }
  values.forEach(_validateCredential);
  int estimated = 2;
  for (final entry in values.entries) {
    estimated +=
        _jsonStringBytes(entry.key) + _jsonStringBytes(entry.value) + 2;
    if (estimated > 4 * 1024 * 1024) {
      throw const SecretStoreException(
        'SecretStoreResourceLimit',
        'Encrypted credential contents exceed 4MiB; existing credentials were preserved.',
      );
    }
  }
}

int _jsonStringBytes(String text) {
  int bytes = 2;
  for (int offset = 0; offset < text.length; offset++) {
    final unit = text.codeUnitAt(offset);
    if (unit == 34 || unit == 92 || const [8, 9, 10, 12, 13].contains(unit)) {
      bytes += 2;
    } else if (unit < 32) {
      bytes += 6;
    } else if (unit < 128) {
      bytes++;
    } else if (unit < 2048) {
      bytes += 2;
    } else if (unit >= 0xd800 &&
        unit <= 0xdbff &&
        offset + 1 < text.length &&
        text.codeUnitAt(offset + 1) >= 0xdc00 &&
        text.codeUnitAt(offset + 1) <= 0xdfff) {
      bytes += 4;
      offset++;
    } else if (unit >= 0xd800 && unit <= 0xdfff) {
      bytes += 6;
    } else {
      bytes += 3;
    }
  }
  return bytes;
}

class SecretStoreException implements Exception {
  const SecretStoreException(
    this.code,
    this.message, {
    this.primaryFailure,
    this.cleanupFailure,
  });
  final String code, message;
  final Object? primaryFailure, cleanupFailure;
  @override
  String toString() => '$code: $message';
}

class PortalDatabaseSecrets implements DatabaseSecrets {
  PortalDatabaseSecrets(
    File file, {
    SecretPortalClient? portalClient,
    this.replaceTemporary,
    this.removeTemporary,
  }) : _storageFile = file,
       _portalClient = portalClient ?? XdgSecretPortalClient() {
    _mutationQueue = _mutationQueues.putIfAbsent(
      p.normalize(file.absolute.path),
      _SerializedMutationQueue.new,
    );
  }
  final File _storageFile;
  final Future<void> Function(File, File)? replaceTemporary;
  final Future<void> Function(File)? removeTemporary;
  final SecretPortalClient _portalClient;
  final AesGcm _cipher = AesGcm.with256bits();
  final Hkdf _kdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  PortalSecret? _cachedSecret;
  late final _SerializedMutationQueue _mutationQueue;
  static final _mutationQueues = <String, _SerializedMutationQueue>{};
  static const _kdfInfo = 'io.busystack.busydata.database-secrets.v1';
  @override
  Future<String?> read(String reference) => _read(reference);
  @override
  Future<void> write(String reference, String password) =>
      _write(reference, password);
  @override
  Future<void> delete(String reference) => _delete(reference);
  Future<String?> _read(String key) async {
    final values = await _readAll('read');
    return values[key];
  }

  Future<void> _write(String key, String value) async {
    await _mutationQueue.run(() => _writeWithoutLock(key, value));
  }

  Future<void> _writeWithoutLock(String key, String value) async {
    _validateCredential(key, value);
    final values = await _readAll('write');
    values[key] = value;
    _validateCredentials(values);
    await _writeAll(values, 'write');
  }

  Future<void> _delete(String key) async {
    await _mutationQueue.run(() => _deleteWithoutLock(key));
  }

  Future<void> _deleteWithoutLock(String key) async {
    final values = await _readAll('delete');
    if (!values.containsKey(key)) {
      return;
    }
    values.remove(key);
    await _writeAll(values, 'delete');
  }

  Future<Map<String, String>> _readAll(String operation) async {
    if (!await _storageFile.exists()) {
      return {};
    }

    try {
      await _restrictExistingStoragePermissions();
      final envelope = _asStringObjectMap(
        _credentialObject(await _readCredentialText(_storageFile)),
      );
      final secret = await _retrieveSecret(
        operation,
        token: envelope['portal_token'],
      );
      final salt = _decodeRequired(envelope, 'salt');
      final key = await _deriveKey(secret.bytes, salt);
      final box = SecretBox(
        _decodeRequired(envelope, 'ciphertext'),
        nonce: _decodeRequired(envelope, 'nonce'),
        mac: Mac(_decodeRequired(envelope, 'mac')),
      );
      final clearBytes = await _cipher.decrypt(box, secretKey: key);
      final values = _asStringMap(_credentialObject(utf8.decode(clearBytes)));
      _validateCredentials(values);
      return values;
    } on Object catch (error) {
      if (error is SecretStoreException) {
        rethrow;
      }
      throw _storageException(operation, error);
    }
  }

  Future<void> _writeAll(Map<String, String> values, String operation) async {
    File? tempFile;
    Object? primary;
    try {
      await _storageFile.parent.create(recursive: true);
      _restrictPermissions(_storageFile.parent.path, '700');
      final existing = await _readEnvelopeIfPresent();
      final salt = existing == null
          ? _randomBytes(16)
          : _decodeRequired(existing, 'salt');
      final secret = await _retrieveSecret(
        operation,
        token: existing?['portal_token'],
      );
      final key = await _deriveKey(secret.bytes, salt);
      final nonce = _cipher.newNonce();
      final box = await _cipher.encrypt(
        utf8.encode(jsonEncode(values)),
        secretKey: key,
        nonce: nonce,
      );
      final envelope = <String, Object?>{
        'version': _encryptedCredentialStoreVersion,
        'cipher': 'aes-256-gcm',
        'kdf': 'hkdf-sha256',
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'ciphertext': base64Encode(box.cipherText),
        'mac': base64Encode(box.mac.bytes),
        if (secret.token != null && secret.token!.isNotEmpty)
          'portal_token': secret.token,
      };
      tempFile = File('${_storageFile.path}.tmp.${_requestToken()}');
      await tempFile.create(exclusive: true);
      _restrictPermissions(tempFile.path, '600');
      final encoded = jsonEncode(envelope);
      if (utf8.encode(encoded).length > _credentialFileLimit) {
        throw const SecretStoreException(
          'SecretStoreResourceLimit',
          'Encrypted credential storage exceeds 8MiB; existing credentials were preserved.',
        );
      }
      await tempFile.writeAsString(encoded, flush: true);
      if (replaceTemporary == null) {
        await tempFile.rename(_storageFile.path);
      } else {
        await replaceTemporary!(tempFile, _storageFile);
      }
    } on Object catch (error) {
      primary = error;
      throw _storageException(operation, error);
    } finally {
      final abandonedTempFile = tempFile;
      if (abandonedTempFile != null) {
        try {
          if (removeTemporary != null) {
            await removeTemporary!(abandonedTempFile);
          } else if (await abandonedTempFile.exists()) {
            await abandonedTempFile.delete();
          }
        } catch (cleanup) {
          throw SecretStoreException(
            'SecretStoreCleanupFailed',
            primary == null
                ? 'Credential write completed, but temporary-file cleanup failed.'
                : 'Credential write failed and temporary-file cleanup also failed; existing credentials were preserved.',
            primaryFailure: primary,
            cleanupFailure: cleanup,
          );
        }
      }
    }
  }

  Future<Map<String, String>?> _readEnvelopeIfPresent() async {
    if (!await _storageFile.exists()) {
      return null;
    }
    await _restrictExistingStoragePermissions();
    return _asStringObjectMap(
      _credentialObject(await _readCredentialText(_storageFile)),
    );
  }

  Future<void> _restrictExistingStoragePermissions() async {
    final type = await FileSystemEntity.type(
      _storageFile.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.file) {
      throw FileSystemException(
        'The encrypted credential path is not a regular file.',
        _storageFile.path,
      );
    }
    _restrictPermissions(_storageFile.parent.path, '700');
    _restrictPermissions(_storageFile.path, '600');
  }

  void _restrictPermissions(String path, String permissions) {
    if (Platform.isLinux) {
      chmod(path, permissions);
    }
  }

  Future<PortalSecret> _retrieveSecret(
    String operation, {
    String? token,
  }) async {
    final cached = _cachedSecret;
    if (cached != null) {
      return cached;
    }
    try {
      final secret = await _portalClient.retrieveSecret(token: token);
      if (secret.bytes.isEmpty ||
          secret.bytes.length > 4096 ||
          (secret.token?.length ?? 0) > 2048) {
        throw const SecretStoreException(
          'SecretStoreUnavailable',
          secretStorageUnavailableMessage,
        );
      }
      _cachedSecret = secret;
      return secret;
    } on Object catch (error) {
      throw _storageException('portal.retrieveSecret/$operation', error);
    }
  }

  Future<SecretKeyData> _deriveKey(List<int> secret, List<int> salt) {
    return _kdf.deriveKey(
      secretKey: SecretKey(secret),
      nonce: salt,
      info: utf8.encode(_kdfInfo),
    );
  }

  SecretStoreException _storageException(String operation, Object error) {
    if (error is SecretStoreException) {
      return error;
    }
    return const SecretStoreException(
      'SecretStoreUnavailable',
      secretStorageUnavailableMessage,
    );
  }
}

abstract interface class SecretPortalClient {
  Future<PortalSecret> retrieveSecret({String? token});
}

class PortalSecret {
  const PortalSecret({required this.bytes, this.token});

  final List<int> bytes;
  final String? token;
}

class XdgSecretPortalClient implements SecretPortalClient {
  XdgSecretPortalClient({DBusClient? client, Duration? timeout})
    : _client = client,
      _timeout = timeout ?? const Duration(minutes: 2);

  final DBusClient? _client;
  final Duration _timeout;

  @override
  Future<PortalSecret> retrieveSecret({String? token}) async {
    final ownsClient = _client == null;
    final client = _client ?? DBusClient.session();
    Directory? tempDir;
    RandomAccessFile? fd;
    try {
      // Establish Hello/uniqueName without enumerating the session bus.
      // The standard strict Snap D-Bus policy permits NameHasOwner and denies
      // ListNames; requesting broader keyring or bus permissions is unnecessary.
      await client.nameHasOwner('org.freedesktop.portal.Desktop');
      final handleToken = _requestToken();
      final sender = _portalSenderName(client.uniqueName);
      final expectedPath = DBusObjectPath(
        '/org/freedesktop/portal/desktop/request/$sender/$handleToken',
      );
      final requestObject = DBusRemoteObject(
        client,
        name: 'org.freedesktop.portal.Desktop',
        path: expectedPath,
      );
      final responseFuture = DBusRemoteObjectSignalStream(
        object: requestObject,
        interface: 'org.freedesktop.portal.Request',
        name: 'Response',
        signature: DBusSignature('ua{sv}'),
      ).first.timeout(_timeout);

      tempDir = await Directory.systemTemp.createTemp(
        'busydata-secret-portal-',
      );
      final secretFile = File(p.join(tempDir.path, 'secret'));
      fd = await secretFile.open(mode: FileMode.write);

      final portalObject = DBusRemoteObject(
        client,
        name: 'org.freedesktop.portal.Desktop',
        path: DBusObjectPath('/org/freedesktop/portal/desktop'),
      );
      final options = <String, DBusValue>{
        'handle_token': DBusString(handleToken),
        if (token != null && token.isNotEmpty) 'token': DBusString(token),
      };
      final response = await portalObject.callMethod(
        'org.freedesktop.portal.Secret',
        'RetrieveSecret',
        [
          DBusUnixFd(ResourceHandle.fromFile(fd)),
          DBusDict.stringVariant(options),
        ],
        replySignature: DBusSignature('o'),
      );
      final returnedPath = response.returnValues[0].asObjectPath();
      final DBusSignal signal;
      if (returnedPath.value == expectedPath.value) {
        signal = await responseFuture;
      } else {
        unawaited(
          responseFuture.catchError(
            (Object _) => DBusSignal(
              sender: null,
              path: expectedPath,
              interface: 'org.freedesktop.portal.Request',
              name: 'Response',
            ),
          ),
        );
        signal = await DBusRemoteObjectSignalStream(
          object: DBusRemoteObject(
            client,
            name: 'org.freedesktop.portal.Desktop',
            path: returnedPath,
          ),
          interface: 'org.freedesktop.portal.Request',
          name: 'Response',
          signature: DBusSignature('ua{sv}'),
        ).first.timeout(_timeout);
      }

      final responseCode = signal.values[0].asUint32();
      final results = signal.values[1].asStringVariantDict();
      if (responseCode == 1) {
        throw const SecretPortalException(
          code: 'PortalUserCancelled',
          message: 'The Secret portal request was cancelled.',
        );
      }
      if (responseCode != 0) {
        throw SecretPortalException(
          code: 'PortalResponse$responseCode',
          message: 'The Secret portal did not return a secret.',
        );
      }

      await fd.close();
      fd = null;
      final secretBytes = await _readCredentialBytes(secretFile, 4096);
      if (secretBytes.isEmpty) {
        throw const SecretPortalException(
          code: 'PortalEmptySecret',
          message: 'The Secret portal returned an empty secret.',
        );
      }
      return PortalSecret(
        bytes: secretBytes,
        token: results['token']?.asString(),
      );
    } finally {
      await fd?.close();
      await tempDir?.delete(recursive: true);
      if (ownsClient) {
        await client.close();
      }
    }
  }
}

class SecretPortalException implements Exception {
  const SecretPortalException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

Map<String, String> _asStringMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Encrypted token store payload is not a map.');
  }
  return value.map((key, value) {
    if (key is! String || value is! String) {
      throw const FormatException(
        'Encrypted token store payload has invalid entries.',
      );
    }
    return MapEntry(key, value);
  });
}

Map<String, String> _asStringObjectMap(Object? value) {
  if (value is! Map) {
    throw const FormatException('Encrypted token store envelope is not a map.');
  }
  final version = value['version'];
  if (version != _encryptedCredentialStoreVersion) {
    throw FormatException(
      'Unsupported encrypted token store version $version.',
    );
  }
  return value.map((key, value) {
    if (key is! String) {
      throw const FormatException(
        'Encrypted token store envelope has invalid keys.',
      );
    }
    return MapEntry(key, value?.toString() ?? '');
  });
}

List<int> _decodeRequired(Map<String, String> envelope, String key) {
  final value = envelope[key];
  if (value == null || value.isEmpty) {
    throw FormatException('Encrypted token store missing $key.');
  }
  return base64Decode(value);
}

List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List<int>.generate(length, (_) => random.nextInt(256));
}

String _requestToken() {
  final bytes = _randomBytes(16);
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'busydata_$hex';
}

String generatePortalRequestTokenForTesting() => _requestToken();

String _portalSenderName(String uniqueName) {
  final trimmed = uniqueName.startsWith(':')
      ? uniqueName.substring(1)
      : uniqueName;
  return trimmed.replaceAll('.', '_');
}

final class _SerializedMutationQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() mutation) {
    final predecessor = _tail;
    final released = Completer<void>();
    _tail = released.future;

    return () async {
      await predecessor;
      try {
        return await mutation();
      } finally {
        released.complete();
      }
    }();
  }
}
