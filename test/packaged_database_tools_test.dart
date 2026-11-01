import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/platform/common/packaged_database_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('strict Snap selects the exact bundled client for each engine/action', () {
    final names = {
      Engine.POSTGRESQL: ['pg_dump', 'psql'],
      Engine.MYSQL: ['mysqldump', 'mysql'],
      Engine.MARIADB: ['mariadb-dump', 'mariadb'],
    };
    for (final entry in names.entries) {
      for (final restore in [false, true]) {
        expect(
          packagedDatabaseTool(
            entry.key,
            restore: restore,
            environment: {'SNAP': '/snap/busydata/42'},
          ),
          '/snap/busydata/42/backend/tools/${entry.key.name.toLowerCase()}/bin/${entry.value[restore ? 1 : 0]}',
        );
      }
    }
  });
  test(
    'unconfined desktop retains explicit selection and rejects malformed package paths',
    () {
      expect(
        packagedDatabaseTool(
          Engine.POSTGRESQL,
          restore: false,
          environment: {},
        ),
        isNull,
      );
      expect(
        () => packagedDatabaseTool(
          Engine.POSTGRESQL,
          restore: false,
          environment: {'SNAP': 'relative'},
        ),
        throwsStateError,
      );
    },
  );
}
