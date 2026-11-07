import 'dart:io';
import 'package:busydata/src/app/busydata_window_close.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/app/windows/windows_busydata_app.dart';

void main() {
  for (final invocation in ['keyboard', 'menu']) {
    testWidgets(
      'Windows panes and editor focus survive $invocation command search',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await tester.binding.setSurfaceSize(const Size(1024, 720));
        final semantics = tester.ensureSemantics();
        final model =
            WorkbenchModel(Directory('/unused-windows-pane-regression'))
              ..draftRecovery = false
              ..newDocument(text: 'SELECT current_document;');
        final close = BusyDataWindowCloseCoordinator();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
        });
        try {
          await tester.pumpWidget(
            fluent.FluentApp(
              localizationsDelegates: const [AppLocalizations.delegate],
              supportedLocales: AppLocalizations.supportedLocales,
              home: WindowsWorkspaceShell(model: model, close: close),
            ),
          );
          await tester.pumpAndSettle();
          SemanticsNode pane(String identifier) =>
              tester.getSemantics(find.bySemanticsIdentifier(identifier));
          final explorer = pane('busydata.windows.explorer');
          final workbench = pane('busydata.windows.workbench');
          final explorerParent = explorer.parent;
          final workbenchParent = workbench.parent;
          await tester.tap(find.byType(CodeEditor));
          await tester.pumpAndSettle();
          final origin = FocusManager.instance.primaryFocus;
          expect(origin, isNotNull);
          final editor = tester.state(find.byType(CodeEditor));
          final controller = model.document.editor;
          Future<void> toggleSearch() async {
            if (invocation == 'menu') {
              await tester.tap(find.text('View').hitTestable());
              await tester.pumpAndSettle();
              await tester.tap(find.text('Commands').last.hitTestable());
            } else {
              await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
              await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
            }
            await tester.pumpAndSettle();
          }

          void stablePanes() {
            expect(pane('busydata.windows.explorer'), same(explorer));
            expect(pane('busydata.windows.workbench'), same(workbench));
            expect(explorer.parent, same(explorerParent));
            expect(workbench.parent, same(workbenchParent));
            expect(
              explorer.getSemanticsData().identifier,
              'busydata.windows.explorer',
            );
            expect(
              workbench.getSemanticsData().identifier,
              'busydata.windows.workbench',
            );
            expect(tester.state(find.byType(CodeEditor)), same(editor));
            expect(model.document.editor, same(controller));
            expect(controller.text, 'SELECT current_document;');
          }

          await toggleSearch();
          expect(find.bySemanticsLabel('Search actions…'), findsOneWidget);
          stablePanes();
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Search actions…'), findsNothing);
          stablePanes();
          expect(FocusManager.instance.primaryFocus, same(origin));
          final offset = controller.selection.extentOffset;
          final direction = offset == 0
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft;
          await tester.sendKeyEvent(direction);
          await tester.pumpAndSettle();
          expect(
            controller.selection.extentOffset,
            offset == 0 ? 1 : offset - 1,
          );
          expect(controller.text, 'SELECT current_document;');
          await toggleSearch();
          expect(find.bySemanticsLabel('Search actions…'), findsOneWidget);
          stablePanes();
        } finally {
          semantics.dispose();
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
