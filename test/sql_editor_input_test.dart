import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:busydata/src/ui/common/sql_editor_input.dart';

final _desktop = TargetPlatformVariant({
  TargetPlatform.linux,
  TargetPlatform.windows,
});

class _InputHarness {
  _InputHarness(this.editor, this.focus, this.scroll, this.input);
  final SqlEditorController editor;
  final FocusNode focus;
  final SqlEditorScrollController scroll;
  final SqlEditorInput input;
  static Future<_InputHarness> mount(
    WidgetTester tester,
    SqlEditorController editor,
  ) async {
    final focus = FocusNode(), scroll = SqlEditorScrollController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Focus(
          focusNode: focus,
          child: const SizedBox(width: 200, height: 100),
        ),
      ),
    );
    final input = SqlEditorInput(
      controller: editor,
      focusNode: focus,
      geometry: scroll.geometry,
      readOnly: false,
      viewId: 0,
      keyboardAppearance: Brightness.light,
    );
    focus.requestFocus();
    await tester.pump();
    expect(input.attached, isTrue);
    return _InputHarness(editor, focus, scroll, input);
  }

  Future<void> close(WidgetTester tester) async {
    input.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
    scroll.dispose();
    editor.dispose();
    await tester.pump();
  }
}

void main() {
  testWidgets(
    'accepted native preedit refreshes ownership without echoing its state',
    (tester) async {
      final editor = SqlEditorController();
      final h = await _InputHarness.mount(tester, editor);
      try {
        tester.testTextInput.log.clear();
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: '日',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);
        expect(editor.isComposing, isTrue);
        expect(h.input.currentTextEditingValue!.text, '日');
        final preeditOwner = editor.value;
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: '日',
            replacementText: '日本',
            replacedRange: TextRange(start: 0, end: 1),
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 0, end: 2),
          ),
        ]);
        expect(editor.value, isNot(same(preeditOwner)));
        expect(editor.text, '日本');
        expect(h.input.rejectedDeltas, 0);
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: '日本',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.isComposing, isFalse);
        expect(h.input.currentTextEditingValue!.composing, TextRange.empty);
        expect(
          tester.testTextInput.log.where(
            (call) => call.method == 'TextInput.setEditingState',
          ),
          isEmpty,
        );
        editor.undo();
        expect(editor.text, '');
        expect(editor.canUndo, isFalse);
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'a rejected native chain force-synchronizes the unchanged preedit owner',
    (tester) async {
      final editor = SqlEditorController();
      final h = await _InputHarness.mount(tester, editor);
      try {
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: '日',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange(start: 0, end: 1),
          ),
        ]);
        final accepted = editor.value;
        tester.testTextInput.log.clear();
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: 'stale platform state',
            selection: TextSelection.collapsed(offset: 0),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.value, same(accepted));
        expect(editor.text, '日');
        expect(editor.isComposing, isTrue);
        expect(h.input.rejectedDeltas, 1);
        final corrections = tester.testTextInput.log
            .where((call) => call.method == 'TextInput.setEditingState')
            .toList();
        expect(corrections, hasLength(1));
        expect(
          corrections.single.arguments,
          h.input.currentTextEditingValue!.toJSON(),
        );
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'a shifted native window sends its correction then accepts the new chain',
    (tester) async {
      final editor = SqlEditorController();
      final h = await _InputHarness.mount(tester, editor);
      try {
        tester.testTextInput.log.clear();
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '',
            textInserted: '\n日',
            insertionOffset: 0,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.text, '\n日');
        expect(h.input.currentTextEditingValue!.text, '日');
        final corrections = tester.testTextInput.log
            .where((call) => call.method == 'TextInput.setEditingState')
            .toList();
        expect(corrections, hasLength(1));
        expect(
          corrections.single.arguments,
          h.input.currentTextEditingValue!.toJSON(),
        );
        tester.testTextInput.log.clear();
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: '日',
            textInserted: '本',
            insertionOffset: 1,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.text, '\n日本');
        expect(h.input.rejectedDeltas, 0);
        expect(
          tester.testTextInput.log.where(
            (call) => call.method == 'TextInput.setEditingState',
          ),
          isEmpty,
        );
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'a new native client receives even an equal accepted field state',
    (tester) async {
      final editor = SqlEditorController.fromText('same');
      final h = await _InputHarness.mount(tester, editor);
      try {
        final previous = h.input.currentTextEditingValue!;
        final oldClient = tester.testTextInput.log.lastWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        tester.testTextInput.log.clear();
        editor.clearHistory();
        await tester.pump();
        final nextClient = tester.testTextInput.log.lastWhere(
          (call) => call.method == 'TextInput.setClient',
        );
        expect(
          (nextClient.arguments as List).first,
          isNot((oldClient.arguments as List).first),
        );
        expect(h.input.currentTextEditingValue, previous);
        final corrections = tester.testTextInput.log
            .where((call) => call.method == 'TextInput.setEditingState')
            .toList();
        expect(corrections, hasLength(1));
        expect(corrections.single.arguments, previous.toJSON());
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'native insertion retains its exact repeated-character span for every caret',
    (tester) async {
      final editor = SqlEditorController.fromText('aaaa\nbbbb');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      editor.addCaret(1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        final old = h.input.currentTextEditingValue!;
        expect(old.text, 'aaaa');
        h.input.updateEditingValueWithDeltas([
          TextEditingDeltaInsertion(
            oldText: old.text,
            textInserted: 'a',
            insertionOffset: 1,
            selection: const TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.text, 'aaaaa\nbabbb');
        expect(editor.selection.extentOffset, 2);
        expect(editor.value.secondarySelections.single.extentOffset, 2);
        editor.undo();
        expect(editor.text, 'aaaa\nbbbb');
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'the entire old-text chain is checked before publishing any edit',
    (tester) async {
      final editor = SqlEditorController.fromText('abc');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        final owner = editor.value;
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'abc',
            textInserted: 'X',
            insertionOffset: 1,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
          const TextEditingDeltaNonTextUpdate(
            oldText: 'unrelated',
            selection: TextSelection.collapsed(offset: 1),
            composing: TextRange.empty,
          ),
        ]);
        expect(identical(editor.value, owner), isTrue);
        expect(editor.text, 'abc');
        expect(editor.canUndo, isFalse);
        expect(h.input.rejectedDeltas, 1);
        expect(h.input.currentTextEditingValue!.text, 'abc');
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets('delayed native composition cannot restore SQL after undo', (
    tester,
  ) async {
    final editor = SqlEditorController.fromText('firstxx');
    editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 7);
    final h = await _InputHarness.mount(tester, editor);
    try {
      h.input.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: 'firstxx',
          textInserted: '日',
          insertionOffset: 7,
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange.empty,
        ),
      ]);
      expect(editor.text, 'firstxx日');
      editor.undo();
      await tester.pump();
      final owner = editor.value;
      h.input.updateEditingValueWithDeltas([
        const TextEditingDeltaNonTextUpdate(
          oldText: 'firstxx日',
          selection: TextSelection.collapsed(offset: 8),
          composing: TextRange(start: 7, end: 8),
        ),
      ]);
      expect(identical(editor.value, owner), isTrue);
      expect(editor.text, 'firstxx');
      expect(editor.canRedo, isTrue);
      expect(h.input.rejectedDeltas, 1);
    } finally {
      await h.close(tester);
    }
  }, variant: _desktop);

  testWidgets(
    'native composition supports signed relative ranges and one committed undo',
    (tester) async {
      final editor = SqlEditorController.fromText('abc');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 3);
      final h = await _InputHarness.mount(tester, editor);
      try {
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaReplacement(
            oldText: 'abc',
            replacementText: '日',
            replacedRange: TextRange(start: 1, end: 3),
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange(start: 1, end: 2),
          ),
        ]);
        expect(editor.text, 'a日');
        expect(editor.isComposing, isTrue);
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: 'a日',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.isComposing, isFalse);
        editor.undo();
        expect(editor.text, 'abc');
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets('native typing preserves an exact caret inside a CRLF pair', (
    tester,
  ) async {
    final editor = SqlEditorController.fromText('a\r\nb');
    editor.selectOffsets(2, 2);
    final h = await _InputHarness.mount(tester, editor);
    try {
      expect(h.input.currentTextEditingValue!.text, 'a\r\nb');
      h.input.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: 'a\r\nb',
          textInserted: 'X',
          insertionOffset: 2,
          selection: TextSelection.collapsed(offset: 3),
          composing: TextRange.empty,
        ),
      ]);
      expect(editor.text, 'a\rX\nb');
      expect(editor.offsetForPosition(editor.selection.extent), 3);
      editor.undo();
      expect(editor.text, 'a\r\nb');
    } finally {
      await h.close(tester);
    }
  }, variant: _desktop);

  testWidgets(
    'a verified multi-delta batch publishes once and undo restores every caret',
    (tester) async {
      final editor = SqlEditorController.fromText('ab\ncd');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      editor.addCaret(1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        var notifications = 0;
        editor.addListener(() {
          notifications++;
        });
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaInsertion(
            oldText: 'ab',
            textInserted: 'X',
            insertionOffset: 1,
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
          const TextEditingDeltaInsertion(
            oldText: 'aXb',
            textInserted: 'Y',
            insertionOffset: 2,
            selection: TextSelection.collapsed(offset: 3),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.text, 'aXYb\ncXYd');
        expect(notifications, 1);
        editor.undo();
        expect(editor.text, 'ab\ncd');
        expect(editor.value.secondarySelections, hasLength(1));
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );
}
