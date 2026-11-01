import 'dart:io';

import 'package:busydata/src/platform/linux/linux_accessibility_binding.dart';
import 'package:busydata/src/platform/linux/linux_accessibility_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/linux_accessibility_test_binding.dart';
import '../integration_test/platform_settings_linux.dart' as native_settings;
import 'support/linux_accessibility_test_binding.dart';

void main() {
  final ordinary = TestWidgetsFlutterBinding.ensureInitialized();

  test('startup refuses an already initialized default binding', () {
    expect(
      () => LinuxAccessibilityBinding.initializedBinding,
      throwsStateError,
    );
    expect(LinuxAccessibilityBinding.ensureInitialized, throwsStateError);
    expect(TestWidgetsFlutterBinding.instance, same(ordinary));
  });

  test(
    'bridge refuses a foreign binding before attaching a native channel',
    () {
      final bridge = LinuxAccessibilityBridge();
      expect(bridge.start, throwsStateError);
      expect(bridge.status, 'unavailable');
      expect(bridge.currentNodeCount, 0);
      bridge.dispose();
      expect(TestWidgetsFlutterBinding.instance, same(ordinary));
    },
  );

  test('test bootstrap helpers cannot replace a foreign global binding', () {
    expect(LinuxAccessibilityTestBinding.ensureInitialized, throwsStateError);
    expect(
      LinuxAccessibilityIntegrationTestBinding.ensureInitialized,
      throwsStateError,
    );
    expect(TestWidgetsFlutterBinding.instance, same(ordinary));
  });

  test(
    'settings startup rejects a foreign binding before fixture I/O',
    () async {
      var fileAttempts = 0;
      final startup = IOOverrides.runZoned(
        native_settings.main,
        createFile: (path) {
          fileAttempts++;
          throw const FileSystemException(
            'Fixture I/O must follow owner admission',
          );
        },
      );
      await expectLater(
        startup,
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains(
              'Linux accessibility requires its owned binding before startup',
            ),
          ),
        ),
      );
      expect(fileAttempts, 0);
      expect(TestWidgetsFlutterBinding.instance, same(ordinary));
    },
  );
}
