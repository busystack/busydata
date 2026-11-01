import 'package:busydata/src/platform/linux/linux_accessibility_binding.dart';
import 'package:integration_test/integration_test.dart';

/// Keeps native integration tests on the production Linux semantics output
/// path while preserving Flutter's integration-test reporting and frame owner.
class LinuxAccessibilityIntegrationTestBinding
    extends IntegrationTestWidgetsFlutterBinding
    with LinuxAccessibilitySemanticsOutput {
  LinuxAccessibilityIntegrationTestBinding._();

  static LinuxAccessibilityIntegrationTestBinding ensureInitialized() {
    final existing = LinuxAccessibilityBinding.initializedBinding;
    if (existing is LinuxAccessibilityIntegrationTestBinding) return existing;
    if (existing != null) {
      throw StateError(
        'Cannot replace another Linux integration binding owner.',
      );
    }
    return LinuxAccessibilityIntegrationTestBinding._();
  }
}
