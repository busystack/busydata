import 'dart:io';
import '../../backend/generated/busydata.pb.dart';

/// Strict Snap executes package-owned native clients. Desktop installations
/// outside confinement retain explicit selection of compatible native tools.
String? packagedDatabaseTool(
  Engine engine, {
  required bool restore,
  Map<String, String>? environment,
}) {
  final root = (environment ?? Platform.environment)['SNAP'];
  if (root == null || root.isEmpty) return null;
  if (!root.startsWith('/') || root.contains('\u0000')) {
    throw StateError('Installed package path is invalid');
  }
  final name = switch (engine) {
    Engine.POSTGRESQL => restore ? 'psql' : 'pg_dump',
    Engine.MYSQL => restore ? 'mysql' : 'mysqldump',
    Engine.MARIADB => restore ? 'mariadb' : 'mariadb-dump',
    _ => throw StateError('Choose a supported database engine'),
  };
  return '$root/backend/tools/${engine.name.toLowerCase()}/bin/$name';
}
