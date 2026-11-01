import 'package:busydata/src/ui/common/snippet_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:flutter/material.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('busydata/native_menus');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw MissingPluginException(),
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} saved snippets use the native SQL editor and explicit insertion',
      (tester) async {
        String? inserted;
        final snippets = {'Exact SQL': 'SELECT \'漢😀\';\r\n'};
        final view = SizedBox(
          width: 650,
          height: 480,
          child: SnippetView(
            controls: ui,
            snippets: snippets,
            save: (name, text, {remove = false}) async {
              if (remove) {
                snippets.remove(name);
              } else {
                snippets[name] = text;
              }
            },
            insert: (text) => inserted = text,
          ),
        );
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: view))
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.tap(find.text('New snippet'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Exact SQL').last);
        await tester.pumpAndSettle();
        expect(inserted, isNull);
        await tester.tap(find.text('Insert into SQL document'));
        await tester.pumpAndSettle();
        expect(inserted, "SELECT '漢😀';\r\n");
        expect(tester.takeException(), isNull);
      },
    );
  }
}
