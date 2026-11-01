import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class DatabaseSecrets {
  Future<String?> read(String reference);
  Future<void> write(String reference, String password);
  Future<void> delete(String reference);
}

class OsDatabaseSecrets implements DatabaseSecrets {
  const OsDatabaseSecrets();
  static const storage = FlutterSecureStorage();
  @override
  Future<String?> read(String reference) => storage.read(key: reference);
  @override
  Future<void> write(String reference, String password) =>
      storage.write(key: reference, value: password);
  @override
  Future<void> delete(String reference) => storage.delete(key: reference);
}
