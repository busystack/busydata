import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/accessibility_text_geometry.dart';
import 'package:busydata/src/ui/common/document_presentation.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
// The locked native file-selector interface is used only to verify dispatch.
// ignore: depend_on_referenced_packages
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';

class StartupFiles extends FileSelectorPlatform {
  int opens = 0;
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    opens++;
    return null;
  }
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} fresh launch keeps scratch ownership and dispatches existing workflows',
      (tester) async {
        // Native dialog title bars read window state even in this widget harness.
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-start-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root, launchBackend: (_) async => backend);
        await tester.runAsync(model.initialize);
        final scratch = model.document;
        expect(model.showStartSurface, isTrue);
        final files = StartupFiles();
        final originalFiles = FileSelectorPlatform.instance;
        FileSelectorPlatform.instance = files;
        addTearDown(() => FileSelectorPlatform.instance = originalFiles);
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final view = controls is LinuxControls
            ? WorkbenchView(model: model, controls: controls)
            : Row(
                children: [
                  SizedBox(
                    width: 280,
                    child: DatabaseExplorer(model: model, controls: controls),
                  ),
                  Expanded(
                    child: WorkbenchView(model: model, controls: controls),
                  ),
                ],
              );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Create'), findsOneWidget);
        expect(find.text('No connections yet'), findsOneWidget);
        expect(find.byType(EditableText), findsNothing);
        expect(find.text('No objects in this scope'), findsNothing);
        expect(
          tester
              .getSemantics(
                find.descendant(
                  of: find.byType(DatabaseExplorer),
                  matching: find.bySemanticsLabel('New connection'),
                ),
              )
              .getSemanticsData()
              .label,
          'New connection',
        );
        expect(
          tester
              .getSemantics(
                find.descendant(
                  of: find.byType(DatabaseExplorer),
                  matching: find.bySemanticsLabel('New connection'),
                ),
              )
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(find.byType(SearchResultList), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byType(SearchResultList), findsNothing);
        expect(model.showStartSurface, isTrue);
        await tester.tap(find.text('New connection').last);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('connection-name')), findsOneWidget);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open SQL file'));
        await tester.pumpAndSettle();
        expect(files.opens, 1);
        expect(model.showStartSurface, isTrue);
        await tester.tap(find.text('New query'));
        await tester.pumpAndSettle();
        expect(model.document, same(scratch));
        expect(model.documents.length, 1);
        expect(model.showStartSurface, isFalse);
        expect(find.byType(CodeEditor), findsOneWidget);
        expect(
          tester.widget<CodeEditor>(find.byType(CodeEditor)).controller,
          same(scratch.editor),
        );
        expect(find.text('No connection'), findsOneWidget);
        expect(
          model.commands!.command('sql.run').disabledReason!(
            model.commandContext,
          ),
          isNotNull,
        );
        model.document.editor.text = 'SELECT authored_draft;';
        await tester.pumpAndSettle();
        expect(model.document.editor.text, 'SELECT authored_draft;');
        final input = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Visible SQL line')),
        );
        final editorContext = tester.element(find.byType(WorkbenchSqlEditor));
        final l = strings(editorContext);
        final primary = model.document.editor.selection;
        final inputData = input.getSemanticsData();
        expect(
          inputData.label,
          '${l.sqlEditorLabel(documentName(editorContext, model, model.activeOwner))}\n'
          '${l.sqlVisibleLine(primary.extentIndex + 1, model.document.editor.codeLines.length, primary.extentOffset + 1)}',
          reason:
              'The native editable boundary must own its localized document '
              'title and current line together.',
        );
        expect(inputData.flagsCollection.isTextField, isTrue);
        expect(inputData.flagsCollection.isReadOnly, isFalse);
        expect(inputData.flagsCollection.isEnabled, ui.Tristate.isTrue);
        for (final action in [
          ui.SemanticsAction.setText,
          ui.SemanticsAction.setSelection,
          ui.SemanticsAction.focus,
        ]) {
          expect(inputData.hasAction(action), isTrue);
        }
        expect(AccessibilityTextGeometry.capture(input), isNotNull);
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: input.id,
            type: ui.SemanticsAction.setText,
            arguments: 'SELECT semantic_boundary_edit;',
          ),
        );
        await tester.pumpAndSettle();
        expect(model.document.editor.text, 'SELECT semantic_boundary_edit;');
        expect(model.jobs, isEmpty);
        model.document.editor.undo();
        await tester.pumpAndSettle();
        expect(model.document.editor.text, 'SELECT authored_draft;');
        final beforeRename = model.document.editor.value;
        model.document.path = '${root.path}/renamed_識別子.sql';
        model.select(model.selected);
        await tester.pumpAndSettle();
        final renamed = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Visible SQL line')),
        );
        expect(renamed.id, input.id);
        expect(
          renamed.getSemanticsData().label,
          startsWith('${l.sqlEditorLabel('renamed_識別子.sql')}\n'),
        );
        expect(model.document, same(scratch));
        expect(model.document.editor.value, same(beforeRename));
        expect(AccessibilityTextGeometry.capture(renamed), isNotNull);
        for (var node = input; ; node = node.parent!) {
          expect(
            node.getSemanticsData().flagsCollection.isHeader,
            isFalse,
            reason:
                'The Explorer heading must not turn the editor or its '
                'workbench ancestors into one flat-review heading.',
          );
          if (node.parent == null) break;
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
    testWidgets(
      '${controls.runtimeType} saved profiles guide connection selection without forced creation',
      (tester) async {
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-saved-start-'),
        ))!;
        final model = WorkbenchModel(
          root,
          launchBackend: (_) async => TestBackend(),
        );
        await tester.runAsync(model.initialize);
        model.profiles.add(
          rpc.Profile(
            id: 'saved',
            name: 'Saved connection',
            engine: rpc.Engine.POSTGRESQL,
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(
                  home: WorkbenchView(model: model, controls: controls),
                )
              : MaterialApp(
                  home: Scaffold(
                    body: WorkbenchView(model: model, controls: controls),
                  ),
                ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Create'), findsOneWidget);
        expect(find.text('New connection'), findsWidgets);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }
  for (final text in ['', 'SELECT user_restored_sql;']) {
    test(
      'restored SQL takes precedence including intentionally blank documents: $text',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'busydata-restored-start-',
        );
        await File('${root.path}/drafts.json').writeAsString(
          jsonEncode({
            'version': 1,
            'selected': 0,
            'documents': [
              {
                'id': 'restored',
                'text': text,
                'savedText': '',
                'path': null,
                'profileId': null,
                'diskHash': null,
              },
            ],
          }),
        );
        final model = WorkbenchModel(
          root,
          launchBackend: (_) async => TestBackend(),
        );
        await model.initialize();
        expect(model.showStartSurface, isFalse);
        expect(model.document.editor.text, text);
        expect(model.document.id, 'restored');
        model.dispose();
        await root.delete(recursive: true);
      },
    );
  }
}
