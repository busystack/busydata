import 'dart:io';

import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

void main() {
  for (final scenario in ['apply', 'cancel', 'new-focus']) {
    testWidgets(
      'Edit-menu formatting preserves keyboard ownership: $scenario',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('format-menu-focus-'),
        ))!;
        final backend = TestBackend();
        const original = 'select id,n from native_windows_parent where id=1;';
        const formatted =
            'select id, n\nfrom native_windows_parent\nwhere id = 1;';
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: original);
        final target = model.document;
        target.selectOffsets(original.length, original.length);
        final newerFocus = FocusNode(debugLabel: 'New intentional control');
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            fluent.FluentApp(
              home: Column(
                children: [
                  fluent.Button(
                    focusNode: newerFocus,
                    onPressed: () {},
                    child: const Text('Other control'),
                  ),
                  Expanded(
                    child: WorkbenchView(
                      model: model,
                      controls: const WindowsControls(),
                    ),
                  ),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit').hitTestable());
          await tester.pumpAndSettle();
          await tester.tap(find.text('Format SQL').last.hitTestable());
          await tester.pumpAndSettle();
          if (scenario == 'new-focus') {
            newerFocus.requestFocus();
            await tester.pumpAndSettle();
            expect(newerFocus.hasPrimaryFocus, isTrue);
          }
          backend.client.completeAnalysis(
            backend.client.analyses.length - 1,
            formatted: formatted,
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Review details · Format SQL'),
            findsOneWidget,
          );
          await tester.tap(
            find
                .text(scenario == 'cancel' ? 'Cancel' : 'Format SQL')
                .last
                .hitTestable(),
          );
          await tester.pumpAndSettle();
          expect(
            target.editor.text,
            scenario == 'cancel' ? original : formatted,
          );
          if (scenario == 'new-focus') {
            expect(newerFocus.hasPrimaryFocus, isTrue);
          } else {
            final editor = FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<WorkbenchSqlEditor>();
            expect(editor?.controller, same(target.editor));
            if (scenario == 'apply') {
              await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
              await tester.pumpAndSettle();
              expect(target.editor.text, original);
            } else {
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
              await tester.pumpAndSettle();
              expect(target.editor.selection.extentOffset, original.length - 1);
              expect(target.editor.text, original);
            }
          }
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          semantics.dispose();
          newerFocus.dispose();
          debugDefaultTargetPlatformOverride = null;
          await tester.runAsync(() => root.delete(recursive: true));
        }
      },
    );
  }
}
