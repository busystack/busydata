import 'package:busydata/src/platform/linux/linux_accessibility_binding.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the Linux accessibility output contract through Flutter's public
/// automated-test binding while retaining its semantics owner and actions.
class LinuxAccessibilityTestBinding extends AutomatedTestWidgetsFlutterBinding
    with LinuxAccessibilitySemanticsOutput {
  LinuxAccessibilityTestBinding._();

  static LinuxAccessibilityTestBinding ensureInitialized() {
    final existing = LinuxAccessibilityBinding.initializedBinding;
    if (existing is LinuxAccessibilityTestBinding) return existing;
    if (existing != null) {
      throw StateError('Cannot replace another Linux test binding owner.');
    }
    return LinuxAccessibilityTestBinding._();
  }
}
