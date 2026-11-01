import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'support/sql_editor_fixture.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';

void main() {
  test(
    'native multiline replacement is one undo operation before multi-caret IME',
    () {
      final editor = SqlEditorController();
      addTearDown(editor.dispose);
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
      editor.addCaret(1);
      editor.edit(
        const TextEditingValue(
          text: 'firstxx日',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 7, end: 8),
        ),
      );
      editor.edit(
        const TextEditingValue(
          text: 'firstxx日',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      editor.setExtraSelections([]);
      editor.moveCursor(AxisDirection.down);
      expect(editor.extentLine.text, 'secondx日');
      editor.undo();
      expect(editor.text, 'firstxx\nsecondx');
      editor.setExtraSelections([]);
      editor.moveCursor(AxisDirection.down);
      expect(editor.extentLine.text, 'secondx');
      editor.moveCursorToPageStart();
      editor.undo();
      expect(editor.text, '');
    },
  );
  test(
    'a rejected undoable edit cannot turn subsequent navigation into an edit',
    () {
      final editor = SqlEditorController();
      addTearDown(editor.dispose);
      editor.text = 'x\ny';
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      editor.addCaret(1);
      editor.replaceSelection('日');
      editor.undo();
      editor.beforeChange = (_) =>
          throw StateError('Injected document admission failure');
      expect(() => editor.replaceSelection('!'), throwsStateError);
      editor.beforeChange = null;
      expect(editor.text, 'x\ny');
      editor.selection = const CodeLineSelection.collapsed(index: 1, offset: 1);
      expect(editor.canRedo, isTrue);
      editor.redo();
      expect(editor.text, 'x日\ny日');
    },
  );
  test(
    'a cancelled composition-only delta after undo is not an edit and keeps redo',
    () {
      final editor = SqlEditorController();
      addTearDown(editor.dispose);
      editor.text = 'firstxx\nsecondx';
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 7);
      editor.addCaret(1);
      editor.replaceSelection('日');
      editor.undo();
      editor.edit(
        const TextEditingValue(
          text: 'firstxx',
          selection: TextSelection.collapsed(offset: 7),
          composing: TextRange(start: 6, end: 7),
        ),
      );
      editor.edit(
        const TextEditingValue(
          text: 'firstxx',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(editor.text, 'firstxx\nsecondx');
      expect(editor.canRedo, isTrue);
      editor.undo();
      expect(editor.text, '');
    },
  );
  test(
    'navigation after undo preserves redo and does not add a phantom SQL edit',
    () {
      final editor = SqlEditorController();
      addTearDown(editor.dispose);
      editor.text = 'firstxx\nsecondx';
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 7);
      editor.addCaret(1);
      editor.replaceSelection('日');
      editor.undo();
      expect(editor.text, 'firstxx\nsecondx');
      expect(editor.canRedo, isTrue);
      editor.setExtraSelections([]);
      editor.selection = const CodeLineSelection.collapsed(index: 1, offset: 7);
      expect(editor.canRedo, isTrue);
      editor.redo();
      expect(editor.text, 'firstxx日\nsecondx日');
      editor.undo();
      editor.setExtraSelections([]);
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
      editor.undo();
      expect(editor.text, '');
    },
  );
  test(
    'a composition-only update after replacement cannot merge the next IME edit into earlier work',
    () {
      final editor = SqlEditorController();
      addTearDown(editor.dispose);
      editor.text = 'firstxx\nsecondx';
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 7);
      editor.addCaret(1);
      editor.edit(
        const TextEditingValue(
          text: 'firstxx',
          selection: TextSelection.collapsed(offset: 7),
          composing: TextRange(start: 6, end: 7),
        ),
      );
      editor.edit(
        const TextEditingValue(
          text: 'firstxx日',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 7, end: 8),
        ),
      );
      editor.edit(
        const TextEditingValue(
          text: 'firstxx日',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(editor.text, 'firstxx日\nsecondx日');
      editor.undo();
      expect(editor.text, 'firstxx\nsecondx');
      expect(editor.isComposing, isFalse);
      expect(editor.value.secondarySelections, hasLength(1));
      editor.redo();
      expect(editor.text, 'firstxx日\nsecondx日');
      expect(editor.isComposing, isFalse);
    },
  );
  test(
    'undo and redo restore SQL and selection without reviving transient IME composition',
    () {
      final editor = SqlEditorController.fromText('x');
      addTearDown(editor.dispose);
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      editor.edit(
        const TextEditingValue(
          text: 'x日',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      expect(editor.isComposing, isTrue);
      editor.text = 'replacement';
      editor.undo();
      expect(editor.text, 'x日');
      expect(editor.isComposing, isFalse);
      editor.redo();
      expect(editor.text, 'replacement');
      expect(editor.isComposing, isFalse);
    },
  );
  test(
    'mixed separators survive editing, selection, multiple carets and undo',
    () {
      const original = 'a😀\r\nb漢\nc\rd';
      final editor = SqlEditorController.fromText(
        original,
        const CodeLineOptions(lineBreak: TextLineBreak.crlf),
      );
      addTearDown(editor.dispose);
      expect(editor.text, original);
      editor.collapseChunk(1, 3);
      expect(editor.text, original);
      editor.collapseChunk(0, 3);
      expect(editor.text, original);
      editor.expandChunk(0);
      expect(editor.text, original);
      editor.expandChunk(1);
      expect(editor.text, original);
      editor.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 1,
        extentIndex: 3,
        extentOffset: 1,
      );
      expect(editor.selectedText, '😀\r\nb漢\nc\rd');
      editor.selection = const CodeLineSelection.collapsed(index: 1, offset: 2);
      editor.replaceSelection('!');
      expect(editor.text, 'a😀\r\nb漢!\nc\rd');
      editor.undo();
      expect(editor.text, original);
      editor.selection = const CodeLineSelection.collapsed(index: 1, offset: 0);
      editor.addCaret(1);
      editor.replaceSelection('x');
      expect(editor.text, 'a😀\r\nxb漢\nxc\rd');
      editor.undo();
      expect(editor.text, original);
      editor.selection = const CodeLineSelection.collapsed(index: 2, offset: 0);
      editor.setExtraSelections([
        const CodeLineSelection.collapsed(index: 3, offset: 0),
      ]);
      editor.deleteSelectionBoundaries(true, word: false);
      expect(editor.text, 'a😀\r\nb漢cd');
      editor.undo();
      expect(editor.text, original);
      editor.selection = const CodeLineSelection.collapsed(index: 1, offset: 1);
      editor.replaceSelection('new\r\ntext\n');
      expect(editor.text, 'a😀\r\nbnew\r\ntext\n漢\nc\rd');
      editor.undo();
      expect(editor.text, original);
    },
  );

  test('multi-caret edits are atomic, bounded, Unicode-aware and undoable', () {
    final editor = SqlEditorController.fromText(
      'a😀\na😀',
      const CodeLineOptions(indentSize: 4),
    );
    addTearDown(editor.dispose);
    editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 3);
    editor.addCaret(1);
    editor.replaceSelection('漢');
    expect(editor.text, 'a😀漢\na😀漢');
    expect(editor.value.secondarySelections.single.extentOffset, 4);
    editor.undo();
    expect(editor.text, 'a😀\na😀');
    expect(editor.value.secondarySelections.length, 1);
    editor.redo();
    editor.deleteBackward();
    expect(editor.text, 'a😀\na😀');
    editor.deleteBackward();
    expect(editor.text, 'a\na');
    editor.undo();
    expect(editor.text, 'a😀\na😀');
    editor.applyIndent();
    expect(editor.text, '    a😀\n    a😀');
    editor.undo();
    expect(editor.text, 'a😀\na😀');
    expect(
      () => editor.setExtraSelections(List.filled(64, editor.selection)),
      sqlEditorFailure(SqlEditorFailure.caretLimit),
    );
  });
  test(
    'IME replacements propagate to the same carets and one undo restores original',
    () {
      final editor = SqlEditorController.fromText('x\nx');
      addTearDown(editor.dispose);
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      editor.addCaret(1);
      editor.edit(
        const TextEditingValue(
          text: 'xk',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      expect(editor.text, 'xk\nxk');
      editor.edit(
        const TextEditingValue(
          text: 'x漢',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      expect(editor.text, 'x漢\nx漢');
      editor.edit(
        const TextEditingValue(
          text: 'x漢',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(editor.isComposing, isFalse);
      editor.undo();
      expect(editor.text, 'x\nx');
    },
  );
  test('paired insertion keeps every caret inside the brackets', () {
    final editor = SqlEditorController.fromText('x\nx');
    addTearDown(editor.dispose);
    editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
    editor.addCaret(1);
    editor.edit(
      const TextEditingValue(
        text: 'x()',
        selection: TextSelection.collapsed(offset: 2),
      ),
    );
    expect(editor.text, 'x()\nx()');
    expect(editor.selection.extentOffset, 2);
    expect(editor.value.secondarySelections.single.extentOffset, 2);
    editor.undo();
    expect(editor.text, 'x\nx');
  });
  test(
    'word and line deletion affect every caret in one undo record, including trailing whitespace',
    () {
      final editor = SqlEditorController.fromText('alpha beta\nalpha beta');
      addTearDown(editor.dispose);
      editor.selection = const CodeLineSelection.collapsed(
        index: 0,
        offset: 10,
      );
      editor.addCaret(1);
      editor.deleteWordBackward();
      expect(editor.text, 'alpha \nalpha ');
      editor.undo();
      expect(editor.text, 'alpha beta\nalpha beta');
      expect(editor.value.secondarySelections, hasLength(1));
      editor.deleteLineBackward();
      expect(editor.text, '\n');
      editor.undo();
      expect(editor.text, 'alpha beta\nalpha beta');
      editor.text = 'alpha   \nalpha   ';
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 5);
      editor.addCaret(1);
      editor.deleteWordForward();
      expect(editor.text, 'alpha\nalpha');
      editor.undo();
      expect(editor.text, 'alpha   \nalpha   ');
    },
  );
  test(
    'block comments preserve every selected SQL range and one undo restores all carets',
    () {
      final editor = SqlEditorController.fromText('SELECT a,b;\nSELECT c,d;');
      addTearDown(editor.dispose);
      editor.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 7,
        extentIndex: 0,
        extentOffset: 8,
      );
      editor.setExtraSelections([
        const CodeLineSelection(
          baseIndex: 0,
          baseOffset: 9,
          extentIndex: 0,
          extentOffset: 10,
        ),
        const CodeLineSelection(
          baseIndex: 1,
          baseOffset: 7,
          extentIndex: 1,
          extentOffset: 8,
        ),
      ]);
      final before = editor.value;
      editor.formatSelectionComments(
        DefaultCodeCommentFormatter(
          multiLinePrefix: '/*',
          multiLineSuffix: '*/',
        ),
        false,
      );
      expect(editor.text, 'SELECT /* a */,/* b */;\nSELECT /* c */,d;');
      expect(editor.selectedText, 'a');
      expect(editor.value.secondarySelections, hasLength(2));
      editor.undo();
      expectSqlSnapshotRestored(editor.value, before);
      editor.redo();
      expect(editor.text, 'SELECT /* a */,/* b */;\nSELECT /* c */,d;');
    },
  );
  test(
    'single-caret and IME edits reject oversized content before replacing SQL or undo',
    () {
      final editor = SqlEditorController.fromText('SELECT 1;');
      addTearDown(editor.dispose);
      editor.replaceSelection('/*start*/');
      final before = editor.value;
      expect(
        () => editor.text = 'x' * 8000001,
        sqlEditorFailure(SqlEditorFailure.documentLimit),
      );
      expect(editor.value, same(before));
      expect(
        () => editor.edit(TextEditingValue(text: '\n' * 100001)),
        sqlEditorFailure(SqlEditorFailure.lineLimit),
      );
      expect(editor.value, same(before));
      expect(
        () => editor.replaceSelection('\n' * 100001),
        sqlEditorFailure(SqlEditorFailure.lineLimit),
      );
      expect(editor.value, same(before));
      editor.undo();
      expect(editor.text, 'SELECT 1;');
    },
  );
  test(
    'undo retention is bounded across controllers and disposal restores available history',
    () {
      final editor = SqlEditorController.fromText('x' * 1000000);
      int edits = 0;
      while (edits < 24) {
        editor.text = '${edits++}${'x' * 1000000}';
      }
      int undos = 0;
      while (editor.canUndo) {
        editor.undo();
        undos++;
      }
      expect(undos, greaterThan(0));
      expect(undos, lessThan(24));
      editor.dispose();
      final fresh = SqlEditorController.fromText('SELECT 1;');
      fresh.text = 'SELECT 2;';
      fresh.undo();
      expect(fresh.text, 'SELECT 1;');
      fresh.dispose();
    },
  );
  testWidgets(
    'PageDown and PageUp navigate a real viewport without changing SQL',
    (tester) async {
      final focus = FocusNode();
      final text = List.generate(150, (i) => 'SELECT $i;').join('\n'),
          editor = SqlEditorController.fromText(
            List.generate(150, (i) => 'SELECT $i;').join('\n'),
          );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: SqlEditorTestView(
                controller: editor,
                focusNode: focus,
                autofocus: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pumpAndSettle();
      expect(editor.selection.extentIndex, greaterThan(5));
      expect(editor.selection.extentIndex, lessThan(50));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
      await tester.pumpAndSettle();
      expect(editor.selection.extentIndex, 0);
      expect(editor.text, text);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      editor.dispose();
      focus.dispose();
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
  testWidgets(
    'native editor draws added carets, moves them and Escape clears them',
    (tester) async {
      final editor = SqlEditorController.fromText('SELECT x;\nSELECT x;');
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SqlEditorTestView(
              controller: editor,
              focusNode: focus,
              autofocus: true,
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pumpAndSettle();
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 0);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(editor.value.secondarySelections.length, 1);
      await tester.pump();
      final view = tester.widget<WorkbenchSqlEditor>(
        find.byType(WorkbenchSqlEditor),
      );
      expect(view.controller, same(editor));
      final geometry = view.scrollController.geometry;
      final extraCaret = geometry.caret(
        editor.value.secondarySelections.single.extent,
      );
      expect(
        extraCaret,
        isNotNull,
        reason:
            'The application-owned extra caret must have an actual visible rendered position',
      );
      expect(geometry.viewport!.contains(extraCaret!.center), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(editor.selection.extentOffset, 1);
      expect(editor.value.secondarySelections.single.extentOffset, 1);
      editor.replaceSelection('漢');
      await tester.pump();
      expect(editor.text, 'S漢ELECT x;\nS漢ELECT x;');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(editor.value.secondarySelections, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      editor.dispose();
      focus.dispose();
    },
    variant: TargetPlatformVariant(const {
      TargetPlatform.linux,
      TargetPlatform.windows,
    }),
  );
}
