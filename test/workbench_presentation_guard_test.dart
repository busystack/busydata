import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/check_platform_boundaries.dart';

void main() {
  test('feature guard keeps themed Material primitives and rejects bypasses', () {
    final root = Directory.systemTemp.createTempSync('presentation-guard-');
    addTearDown(() => root.deleteSync(recursive: true));
    final directory = Directory('${root.path}/lib/src/ui/common')
      ..createSync(recursive: true);
    final feature = File('${directory.path}/feature.dart');
    feature.writeAsStringSync(
      'MaterialApp(home: Material(child: TextField())); Dialog(child: FilledButton());',
    );
    expect(findWorkbenchPresentationViolations(root), isEmpty);
    for (final path in ['ui/common/nested', 'ui/linux', 'app/linux']) {
      final nested = Directory('${root.path}/lib/src/$path')
        ..createSync(recursive: true);
      final bypass = File('${nested.path}/bypass.dart')
        ..writeAsStringSync("TextStyle(fontFamily: 'Unowned');");
      expect(
        findWorkbenchPresentationViolations(root),
        contains(contains('$path/bypass.dart')),
      );
      bypass.deleteSync();
    }
    File('${root.path}/lib/src/app/linux/header.dart').writeAsStringSync(
      'final hover = foreground.withValues(alpha: .1); window.showMenu();',
    );
    expect(findWorkbenchPresentationViolations(root), isEmpty);
    for (final source in [
      'final fill = Color(0xffabcdef);',
      'showMenu(context: context, items: []);',
      "TextStyle(fontFamily: 'Fixed UI', fontSize: 14);",
    ]) {
      feature.writeAsStringSync(source);
      expect(findWorkbenchPresentationViolations(root), isNotEmpty);
    }
    feature.writeAsStringSync('final emptyPaint = Color(0x00000000);');
    File('${directory.path}/er_diagram_export.dart').writeAsStringSync(
      "TextStyle(fontSize: 14); final printInk = Color(0xff000000);",
    );
    expect(findWorkbenchPresentationViolations(root), isEmpty);
  });
}
