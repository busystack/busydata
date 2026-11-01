import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workspace_divider.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  test(
    'Layout saves are serialized and restoration never opens a database',
    () async {
      final root = await Directory.systemTemp.createTemp('busydata-layout-');
      final model = WorkbenchModel(root);
      final backend = TestBackend();
      final restored = WorkbenchModel(
        root,
        launchBackend: (_) async => backend,
      );
      try {
        model.resizeEditor(.65);
        final first = model.savePresentation();
        model.resizeEditor(.75);
        final last = model.savePresentation();
        await Future.wait([first, last]);
        final data =
            jsonDecode(
                  await File('${root.path}/presentation.json').readAsString(),
                )
                as Map<String, dynamic>;
        expect(data['editorFraction'], .75);
        await restored.initialize();
        expect(restored.editorFraction, .75);
        expect(restored.sessions, isEmpty);
        expect(backend.client.opened, isEmpty);
        restored.resizeEditor(2);
        expect(restored.editorFraction, .85);
        restored.resizeEditor(-1);
        expect(restored.editorFraction, .15);
      } finally {
        model.dispose();
        restored.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} divider has keyboard focus and accessible resizing',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-divider-'),
        ))!;
        final model = (await tester.runAsync(
          () async => WorkbenchModel(
            root,
            presentationWrite: (file, bytes) {
              file.writeAsBytesSync(bytes, flush: true);
              return Future<void>.value();
            },
          ),
        ))!;
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final divider = WorkspaceDivider(model: model, controls: ui);
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: divider))
              : MaterialApp(home: Scaffold(body: divider)),
        );
        final semantics = tester.ensureSemantics();
        try {
          expect(
            find.bySemanticsLabel('Editor and results divider'),
            findsOneWidget,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final before = model.editorFraction;
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pump();
          expect(model.editorFraction, greaterThan(before));
          await tester.runAsync(() async {
            await Future<void>.delayed(Duration.zero);
          });
          await tester.pumpAndSettle();
          expect(File('${root.path}/presentation.json').existsSync(), isTrue);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
