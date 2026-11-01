import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

// Intentionally imports no BusyData code. Run this diagnostic with the exact
// approved SDK and lockfile to isolate upstream compilation compatibility.
void main() {
  test('official editor controller compiles on the approved Flutter SDK', () {
    final controller = CodeLineEditingController.fromText('select 1;');
    addTearDown(controller.dispose);
    expect(controller.text, 'select 1;');
  });
}
