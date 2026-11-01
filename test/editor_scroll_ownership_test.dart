import 'dart:io';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'support/fake_backend.dart';
import 'support/presentation_fonts.dart';

void main() {
  setUpAll(loadPresentationFonts);
  testWidgets(
    'font reflow preserves the SQL viewport and respects newer navigation',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('editor-font-scroll-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument(
          text: List.generate(
            100,
            (i) => '-- preserved viewport line $i',
          ).join('\n'),
        );
      final backend = TestBackend();
      model.backend = backend;
      final owner = model.activeOwner;
      final controller = model.document.editor;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> display(double points) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: presentationTheme(Brightness.light, fontSize: points),
            themeAnimationDuration: Duration.zero,
            home: Scaffold(
              body: WorkbenchView(
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      CodeEditor editor() => tester.widget<CodeEditor>(find.byType(CodeEditor));
      await display(10.5);
      final state = tester.state(find.byType(CodeEditor));
      final scroll = editor().scrollController!;
      final fontSize = editor().style!.fontSize!;
      await tester.tap(find.byType(CodeEditor));
      await tester.pumpAndSettle();
      final focus = FocusManager.instance.primaryFocus;
      controller.selection = const CodeLineSelection(
        baseIndex: 99,
        baseOffset: 2,
        extentIndex: 99,
        extentOffset: 6,
      );
      await tester.pumpAndSettle();
      scroll.verticalScroller.jumpTo(
        scroll.verticalScroller.position.maxScrollExtent,
      );
      await tester.pumpAndSettle();
      final vertical = scroll.verticalScroller.offset;
      final selection = controller.selection;
      expect(vertical, greaterThan(0));
      expect(scroll.horizontalScroller.hasClients, isFalse);

      await display(12);
      expect(editor().style!.fontSize, greaterThan(fontSize));
      expect(scroll.verticalScroller.offset, closeTo(vertical, .01));
      await display(10.5);
      expect(scroll.verticalScroller.offset, closeTo(vertical, .01));
      expect(editor().controller, same(controller));
      expect(editor().scrollController, same(scroll));
      expect(tester.state(find.byType(CodeEditor)), same(state));
      expect(controller.selection, selection);
      expect(FocusManager.instance.primaryFocus, same(focus));

      // A newer navigation arrives before the queued appearance correction.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scroll.verticalScroller.jumpTo(320);
      });
      await display(12);
      expect(scroll.verticalScroller.offset, closeTo(320, .01));
      expect(model.activeOwner, same(owner));
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} switches documents without losing editor scroll or executing SQL',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('editor-scroll-owner-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument(
            text: List.generate(200, (i) => 'SELECT $i;').join('\n'),
          );
        final backend = TestBackend();
        model.backend = backend;
        final a = model.activeOwner;
        model.newDocument(text: '-- second document');
        final b = model.activeOwner;
        model.activateOwner(a.id);
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final workbench = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: workbench)
              : MaterialApp(home: workbench),
        );
        await tester.pumpAndSettle();
        final scroll = tester
            .widget<CodeEditor>(find.byType(CodeEditor))
            .scrollController!;
        scroll.verticalScroller.jumpTo(350);
        await tester.pump();
        expect(a.view.editorVertical, 350);
        model.activateOwner(b.id);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CodeEditor>(find.byType(CodeEditor))
              .scrollController!
              .verticalScroller
              .offset,
          0,
        );
        model.activateOwner(a.id);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<CodeEditor>(find.byType(CodeEditor))
              .scrollController!
              .verticalScroller
              .offset,
          350,
        );
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
