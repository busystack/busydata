import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'support/sql_editor_fixture.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:busydata/src/ui/common/editor_shortcuts.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';

void main() {
  testWidgets(
    'multi-line selection keeps semantic range absent and exact SQL intact',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final editor = SqlEditorController.fromText("SELECT '漢😀';\r\nSELECT 2;");
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SqlEditorTestView(controller: editor)),
        ),
      );
      editor.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 1,
        extentIndex: 1,
        extentOffset: 6,
      );
      final captured = editor.value;
      await tester.pumpAndSettle();
      final node = tester
          .getSemantics(find.bySemanticsLabel(RegExp('Visible SQL line')))
          .getSemanticsData();
      expect(node.textSelection, isNull);
      expect(node.hasAction(ui.SemanticsAction.setText), isFalse);
      expect(editor.value, captured);
      expect(editor.text, "SELECT '漢😀';\r\nSELECT 2;");
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'GTK preedit clearing before commit preserves both multiline undo boundaries',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final editor = SqlEditorController();
      final focus = FocusNode();
      addTearDown(editor.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SqlEditorTestView(
              controller: editor,
              focusNode: focus,
              shortcutsActivatorsBuilder: const WorkbenchEditorShortcuts([]),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      Future<void> key(
        LogicalKeyboardKey key, {
        bool control = false,
        bool alt = false,
      }) async {
        if (control) {
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        }
        if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(key);
        if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        if (control) {
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        }
        await tester.pump();
      }

      Future<void> nativeDelta(
        String oldText,
        String replacement,
        int start,
        int end,
        int selection, {
        int composingStart = -1,
        int composingEnd = -1,
      }) async {
        final client =
            (tester.testTextInput.log
                        .lastWhere(
                          (call) => call.method == 'TextInput.setClient',
                        )
                        .arguments
                    as List)
                .first;
        final reply = await tester.binding.defaultBinaryMessenger
            .handlePlatformMessage(
              'flutter/textinput',
              const JSONMethodCodec().encodeMethodCall(
                MethodCall('TextInputClient.updateEditingStateWithDeltas', [
                  client,
                  {
                    'deltas': [
                      {
                        'oldText': oldText,
                        'deltaText': replacement,
                        'deltaStart': start,
                        'deltaEnd': end,
                        'selectionBase': selection,
                        'selectionExtent': selection,
                        'selectionAffinity': 'TextAffinity.downstream',
                        'selectionIsDirectional': false,
                        'composingBase': composingStart,
                        'composingExtent': composingEnd,
                      },
                    ],
                  },
                ]),
              ),
              null,
            );
        expect(reply, isNotNull);
        const JSONMethodCodec().decodeEnvelope(reply!);
        await tester.pump();
      }

      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Visible SQL line')),
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: ui.SemanticsAction.setText,
          arguments: 'firstxx\nsecondx',
        ),
      );
      await tester.pump();
      await key(LogicalKeyboardKey.home, control: true);
      await key(LogicalKeyboardKey.end);
      await key(LogicalKeyboardKey.arrowDown, control: true, alt: true);
      expect(editor.value.secondarySelections, hasLength(1));
      await nativeDelta(
        'firstxx',
        '日',
        7,
        7,
        8,
        composingStart: 7,
        composingEnd: 8,
      );
      // GTK input methods may empty the preedit range before delivering the
      // commit. This transient return to the original SQL is not a user edit.
      await nativeDelta('firstxx日', '', 7, 8, 7);
      expect(editor.text, 'firstxx\nsecondx');
      await nativeDelta('firstxx', '日', 7, 7, 8);
      await tester.pump();
      await key(LogicalKeyboardKey.escape);
      await key(LogicalKeyboardKey.arrowDown);
      expect(editor.extentLine.text, 'secondx日');
      await key(LogicalKeyboardKey.keyZ, control: true);
      expect(editor.text, 'firstxx\nsecondx');
      await key(LogicalKeyboardKey.escape);
      await key(LogicalKeyboardKey.arrowDown);
      expect(editor.extentLine.text, 'secondx');
      await key(LogicalKeyboardKey.home, control: true);
      expect(editor.selection.extentOffset, 0);
      expect(editor.canUndo, isTrue);
      await key(LogicalKeyboardKey.keyZ, control: true);
      expect(editor.text, '');
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  testWidgets(
    'matching batched native deltas commit Unicode at both carets and preserve undo',
    (tester) async {
      final editor = SqlEditorController.fromText('x\nx');
      final focus = FocusNode();
      addTearDown(editor.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SqlEditorTestView(controller: editor, focusNode: focus),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      editor.addCaret(1);
      // Programmatic selection changes retire the previous platform client.
      // Wait for the newly advertised owner before sending a matching batch.
      await tester.pump();
      expect(tester.testTextInput.editingState?['text'], 'x');
      expect(tester.testTextInput.editingState?['selectionExtent'], 1);
      final client =
          (tester.testTextInput.log
                      .lastWhere((call) => call.method == 'TextInput.setClient')
                      .arguments
                  as List)
              .first;
      Map<String, Object> delta(
        String oldText,
        String text,
        int start,
        int end,
        int composingStart,
        int composingEnd,
      ) => {
        'oldText': oldText,
        'deltaText': text,
        'deltaStart': start,
        'deltaEnd': end,
        'selectionBase': 2,
        'selectionExtent': 2,
        'selectionAffinity': 'TextAffinity.downstream',
        'selectionIsDirectional': false,
        'composingBase': composingStart,
        'composingExtent': composingEnd,
      };
      final reply = await tester.binding.defaultBinaryMessenger
          .handlePlatformMessage(
            'flutter/textinput',
            const JSONMethodCodec().encodeMethodCall(
              MethodCall('TextInputClient.updateEditingStateWithDeltas', [
                client,
                {
                  'deltas': [
                    delta('x', 'k', 1, 1, 1, 2),
                    delta('xk', '漢', 1, 2, 1, 2),
                    delta('x漢', '', -1, -1, -1, -1),
                  ],
                },
              ]),
            ),
            null,
          );
      expect(reply, isNotNull);
      const JSONMethodCodec().decodeEnvelope(reply!);
      await tester.pump();
      expect(editor.text, 'x漢\nx漢');
      expect(editor.isComposing, isFalse);
      editor.undo();
      expect(editor.text, 'x\nx');
      editor.redo();
      expect(editor.text, 'x漢\nx漢');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  for (final staleKind in ['selection', 'insertion']) {
    testWidgets(
      'delayed native $staleKind delta cannot restore SQL after undo',
      (tester) async {
        final editor = SqlEditorController();
        final focus = FocusNode();
        addTearDown(editor.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SqlEditorTestView(controller: editor, focusNode: focus),
            ),
          ),
        );
        focus.requestFocus();
        await tester.pump();
        final client =
            (tester.testTextInput.log
                        .lastWhere(
                          (call) => call.method == 'TextInput.setClient',
                        )
                        .arguments
                    as List)
                .first;
        editor.runRevocableOp(
          () => editor.edit(
            const TextEditingValue(
              text: 'firstxx\nsecondx',
              selection: TextSelection.collapsed(offset: 15),
            ),
          ),
        );
        editor.moveCursorToPageStart();
        editor.moveCursorToLineEnd();
        editor.undo();
        await tester.pump();
        expect(editor.text, '');
        final reply = await tester.binding.defaultBinaryMessenger
            .handlePlatformMessage(
              'flutter/textinput',
              const JSONMethodCodec().encodeMethodCall(
                MethodCall('TextInputClient.updateEditingStateWithDeltas', [
                  client,
                  {
                    'deltas': [
                      {
                        'oldText': 'firstxx',
                        'deltaText': staleKind == 'insertion' ? '日' : '',
                        'deltaStart': staleKind == 'insertion' ? 7 : -1,
                        'deltaEnd': staleKind == 'insertion' ? 7 : -1,
                        'selectionBase': staleKind == 'insertion' ? 8 : 7,
                        'selectionExtent': staleKind == 'insertion' ? 8 : 7,
                        'selectionAffinity': 'TextAffinity.downstream',
                        'selectionIsDirectional': false,
                        'composingBase': -1,
                        'composingExtent': -1,
                      },
                    ],
                  },
                ]),
              ),
              null,
            );
        expect(reply, isNotNull);
        const JSONMethodCodec().decodeEnvelope(reply!);
        await tester.pump();
        expect(editor.text, '');
        expect(editor.canRedo, isTrue);
        editor.redo();
        expect(editor.text, 'firstxx\nsecondx');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant(const {
        TargetPlatform.linux,
        TargetPlatform.windows,
      }),
    );
  }
  testWidgets(
    'multiline accessibility replacement and multi-caret IME undo retain separate atomic boundaries',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final editor = SqlEditorController();
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SqlEditorTestView(controller: editor, focusNode: focus),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Visible SQL line')),
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: ui.SemanticsAction.setText,
          arguments: 'firstxx\nsecondx',
        ),
      );
      await tester.pump();
      expect(editor.text, 'firstxx\nsecondx');
      editor.moveCursorToPageStart();
      editor.moveCursorToLineEnd();
      editor.addCaret(1);
      editor.edit(
        const TextEditingValue(
          text: 'firstxx日',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 7, end: 8),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(
              strings(
                tester.element(find.byType(SqlEditorTestView)),
              ).sqlCompositionActive,
            ),
          ),
        ),
        findsOneWidget,
      );
      editor.edit(
        const TextEditingValue(
          text: 'firstxx日',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      await tester.pump();
      expect(
        find.bySemanticsLabel(
          RegExp(
            RegExp.escape(
              strings(
                tester.element(find.byType(SqlEditorTestView)),
              ).sqlCompositionActive,
            ),
          ),
        ),
        findsNothing,
      );
      editor.setExtraSelections([]);
      editor.moveCursor(AxisDirection.down);
      expect(editor.extentLine.text, 'secondx日');
      editor.undo();
      await tester.pump();
      expect(editor.text, 'firstxx\nsecondx');
      editor.setExtraSelections([]);
      editor.moveCursor(AxisDirection.down);
      editor.moveCursorToPageStart();
      editor.undo();
      await tester.pump();
      expect(editor.text, '');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      focus.dispose();
      semantics.dispose();
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  testWidgets(
    'native accessibility can focus the editor without activating another action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final editor = SqlEditorController.fromText('SELECT 漢😀;');
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SqlEditorTestView(controller: editor, focusNode: focus),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Visible SQL line')),
      );
      expect(
        node.getSemanticsData().hasAction(ui.SemanticsAction.focus),
        isTrue,
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: ui.SemanticsAction.focus,
        ),
      );
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(editor.text, 'SELECT 漢😀;');
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      focus.dispose();
      semantics.dispose();
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  testWidgets(
    'native text replacement and its same-frame selection share an exact snapshot',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final editor = SqlEditorController.fromText('😀日');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SqlEditorTestView(controller: editor)),
        ),
      );
      await tester.pumpAndSettle();
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Visible SQL line')),
      );
      void action(ui.SemanticsAction type, Object value) =>
          tester.binding.performSemanticsAction(
            ui.SemanticsActionEvent(
              viewId: tester.view.viewId,
              nodeId: node.id,
              type: type,
              arguments: value,
            ),
          );
      action(ui.SemanticsAction.setText, '😀🧪日');
      action(ui.SemanticsAction.setSelection, {'base': 4, 'extent': 4});
      expect(editor.text, '😀🧪日');
      expect(editor.selection.extentOffset, 4);
      editor.undo();
      expect(editor.text, '😀日');
      await tester.pump();
      action(ui.SemanticsAction.setText, '😀🧪日');
      editor.text = 'intervening SQL';
      final untouched = editor.selection;
      action(ui.SemanticsAction.setSelection, {'base': 1, 'extent': 1});
      expect(editor.text, 'intervening SQL');
      expect(editor.selection, untouched);
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      semantics.dispose();
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  testWidgets(
    'reduced motion keeps the focused SQL cursor steady and responds to settings',
    (tester) async {
      final editor = SqlEditorController.fromText('SELECT 1;');
      final focus = FocusNode();
      Future<void> render(bool reduced) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: SqlEditorTestView(controller: editor, focusNode: focus),
            ),
          ),
        ),
      );
      await render(true);
      focus.requestFocus();
      await tester.pump();
      await tester.pump();
      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byWidgetPredicate(
                      (widget) =>
                          widget is CustomPaint &&
                          widget.painter is SqlExtraSelectionPainter,
                    ),
                  )
                  .painter!
              as SqlExtraSelectionPainter;
      final cursor = painter.caretVisible;
      expect(painter.controller, same(editor));
      expect(
        painter.geometry.caret(editor.selection.extent),
        isNotNull,
        reason:
            'The first-party steady caret must have a visible rendered position',
      );
      expect(painter.caretColor.a, greaterThan(0));
      expect(
        tester
            .widget<CodeEditor>(find.byType(CodeEditor))
            .style!
            .cursorColor!
            .a,
        0,
        reason:
            'The upstream blinking cursor must not compete with the application-owned caret',
      );
      expect(cursor.value, isTrue);
      await tester.pump(const Duration(milliseconds: 700));
      expect(cursor.value, isTrue);
      await render(false);
      await tester.pump(const Duration(milliseconds: 500));
      expect(cursor.value, isFalse);
      await render(true);
      expect(cursor.value, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(cursor.value, isTrue);
      focus.unfocus();
      await tester.pump();
      expect(cursor.value, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      focus.dispose();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'native editor exposes exact UTF-16 selection, safe accessibility edits and text scaling',
    (tester) async {
      final semantics = tester.ensureSemantics(),
          editor = SqlEditorController.fromText('SELECT 漢😀;');
      final focus = FocusNode();
      double? paragraphHeight;
      ValueNotifier<CodeIndicatorValue?>? observed;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: SqlEditorTestView(
                controller: editor,
                focusNode: focus,
                style: const CodeEditorStyle(fontSize: 14),
                indicatorBuilder: (context, editing, chunks, notifier) {
                  if (observed != notifier) {
                    observed = notifier;
                    void measure() {
                      final value = notifier.value;
                      if (value != null && value.paragraphs.isNotEmpty) {
                        paragraphHeight =
                            value.paragraphs.first.preferredLineHeight;
                      }
                    }

                    notifier.addListener(measure);
                    addTearDown(() => notifier.removeListener(measure));
                    measure();
                  }
                  return const SizedBox(width: 1);
                },
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      editor.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 8,
        extentIndex: 0,
        extentOffset: 10,
      );
      await tester.pump();
      final node = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Visible SQL line')),
      );
      final data = node.getSemanticsData();
      expect(data.value, 'SELECT 漢😀;');
      expect(
        data.textSelection,
        const TextSelection(baseOffset: 8, extentOffset: 10),
      );
      expect(data.hasAction(ui.SemanticsAction.setText), isTrue);
      expect(
        paragraphHeight,
        greaterThan(25),
        reason: 'The actual native paragraph must use the 2× text scale',
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: ui.SemanticsAction.setText,
          arguments: 'SELECT 2;',
        ),
      );
      await tester.pump();
      expect(editor.text, 'SELECT 2;');
      editor.undo();
      expect(editor.text, 'SELECT 漢😀;');
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      focus.dispose();
      semantics.dispose();
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  test(
    'workbench reserved keys remain available for execution, saving and comments',
    () {
      final builder = WorkbenchEditorShortcuts([
        const SingleActivator(LogicalKeyboardKey.enter, control: true),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true),
        const SingleActivator(LogicalKeyboardKey.slash, control: true),
      ]);
      expect(builder.build(CodeShortcutType.save), isEmpty);
      expect(builder.build(CodeShortcutType.singleLineComment), isEmpty);
      expect(
        builder
            .build(CodeShortcutType.newLine)!
            .any(
              (value) =>
                  value is SingleActivator &&
                  value.trigger == LogicalKeyboardKey.enter &&
                  value.control &&
                  !value.shift &&
                  !value.alt &&
                  !value.meta,
            ),
        isFalse,
      );
      expect(
        builder
            .build(CodeShortcutType.newLine)!
            .any(
              (value) =>
                  value is SingleActivator &&
                  value.trigger == LogicalKeyboardKey.enter &&
                  !value.control &&
                  !value.shift &&
                  !value.alt &&
                  !value.meta,
            ),
        isTrue,
      );
    },
  );
}
