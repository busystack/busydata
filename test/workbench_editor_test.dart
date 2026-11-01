import 'dart:io';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';
import 'support/sql_editor_fixture.dart';

void main() {
  test(
    'line comments preserve CRLF, folded SQL, multi-caret selection and undo',
    () {
      final document = SqlDocument(
        text: '  SELECT 漢;\r\n  SELECT 2;\r\n  -- kept',
      );
      addTearDown(document.dispose);
      document.editor.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 11,
      );
      document.editor.addCaret(1);
      final original = document.editor.value;
      document.toggleLineComments();
      expect(
        document.editor.text,
        '  -- SELECT 漢;\r\n  -- SELECT 2;\r\n  -- kept',
      );
      expect(document.editor.value.secondarySelections, hasLength(1));
      document.editor.undo();
      expectSqlSnapshotRestored(document.editor.value, original);
      document.editor.redo();
      document.toggleLineComments();
      expect(document.editor.text, '  SELECT 漢;\r\n  SELECT 2;\r\n  -- kept');
      document.editor.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 2,
        extentOffset: 0,
      );
      document.toggleLineComments();
      expect(
        document.editor.text,
        '  -- SELECT 漢;\r\n  -- SELECT 2;\r\n  -- kept',
      );
    },
  );
  testWidgets(
    'high contrast changes editor highlighting without changing SQL or undo',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busydata-editor-contrast-'),
      ))!;
      final model = WorkbenchModel(directory)
        ..draftRecovery = false
        ..newDocument(text: 'SELECT 1;');
      addTearDown(() async {
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Future<void> display(bool contrast) => tester.pumpWidget(
        MaterialApp(
          theme: BusyDataYaruTheme.build(
            brightness: Brightness.light,
            accentColor: const Color(0xFFE95420),
          ),
          home: MediaQuery(
            data: MediaQueryData(highContrast: contrast),
            child: WorkbenchView(model: model, controls: const LinuxControls()),
          ),
        ),
      );
      await display(false);
      final original = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .style!
          .codeTheme!;
      expect(
        original.theme.values
            .map((s) => s.color)
            .whereType<Color>()
            .toSet()
            .length,
        greaterThan(1),
      );
      model.document.editor.selectAll();
      model.document.editor.replaceSelection('SELECT 2;');
      await display(true);
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(
        editor.style!.codeTheme!.theme.values.every(
          (s) => s.color == editor.style!.textColor,
        ),
        isTrue,
      );
      expect(model.document.editor.text, 'SELECT 2;');
      model.document.editor.undo();
      await tester.pump();
      expect(model.document.editor.text, 'SELECT 1;');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  testWidgets(
    'editor attaches without changing the document and retains undo',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busydata-editor-test-'),
      ))!;
      final file = File('${directory.path}/fixture.sql');
      await tester.runAsync(() => file.writeAsString('SELECT \'漢😀\';'));
      final model = WorkbenchModel(directory)
        ..newDocument(text: 'SELECT \'漢😀\';', path: file.path);
      bool disposed = false;
      addTearDown(() async {
        if (!disposed) model.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: BusyDataYaruTheme.build(
            brightness: Brightness.light,
            accentColor: const Color(0xFFE95420),
          ),
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(model.document.version, 1);
      expect(model.document.dirty, isFalse);
      expect(
        tester.getSize(find.byType(WorkbenchSqlEditor)).height,
        greaterThan(100),
      );
      expect(
        tester
            .widget<WorkbenchSqlEditor>(find.byType(WorkbenchSqlEditor))
            .controller,
        same(model.document.editor),
      );
      model.document.editor.selectAll();
      expect(
        model.document.version,
        1,
        reason: 'Selection is not a document modification',
      );
      model.document.editor.replaceSelection('SELECT 2;');
      await tester.pump();
      expect(model.document.dirty, isTrue);
      expect(model.document.version, 2);
      model.document.editor.undo();
      await tester.pump();
      expect(model.document.editor.text, 'SELECT \'漢😀\';');
      expect(model.document.dirty, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      disposed = true;
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
