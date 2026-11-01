import 'dart:async';
import 'dart:io';

import 'linux_accessibility_test_binding.dart';

/// Flutter's integration runner initializes its binding before calling the
/// test's main. Install our output owner at the supported configuration hook,
/// before that runner initialization, rather than replacing an existing owner.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isLinux) {
    LinuxAccessibilityIntegrationTestBinding.ensureInitialized();
  }
  await testMain();
}
