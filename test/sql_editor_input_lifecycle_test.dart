import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/features/workspace/documents.dart';
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

  Future<void> close(WidgetTester tester, {bool disposeEditor = true}) async {
    input.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
    focus.dispose();
    scroll.dispose();
    if (disposeEditor) editor.dispose();
    await tester.pump();
  }
}

void main() {
  void preedit(_InputHarness h) {
    h.input.updateEditingValueWithDeltas([
      TextEditingDeltaInsertion(
        oldText: h.input.currentTextEditingValue!.text,
        textInserted: '日',
        insertionOffset: 1,
        selection: const TextSelection.collapsed(offset: 2),
        composing: const TextRange(start: 1, end: 2),
      ),
    ]);
  }

  Future<void> stale(WidgetTester tester, int client) async {
    final reply = await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage(
          'flutter/textinput',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('TextInputClient.updateEditingStateWithDeltas', [
              client,
              {
                'deltas': [
                  {
                    'oldText': 'a日b',
                    'deltaText': 'stale',
                    'deltaStart': 1,
                    'deltaEnd': 2,
                    'selectionBase': 6,
                    'selectionExtent': 6,
                    'selectionAffinity': 'TextAffinity.downstream',
                    'selectionIsDirectional': false,
                    'composingBase': 1,
                    'composingExtent': 6,
                  },
                ],
              },
            ]),
          ),
          null,
        );
    expect(reply, isNotNull);
    const JSONMethodCodec().decodeEnvelope(reply!);
  }

  int clientId(WidgetTester tester) =>
      (tester.testTextInput.log
                      .lastWhere((call) => call.method == 'TextInput.setClient')
                      .arguments
                  as List)
              .first
          as int;

  testWidgets('blur commits accepted preedit and retires its platform client', (
    tester,
  ) async {
    final editor = SqlEditorController.fromText('ab\ncd');
    editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
    editor.addCaret(1);
    final h = await _InputHarness.mount(tester, editor);
    try {
      preedit(h);
      expect(editor.text, 'a日b\nc日d');
      expect(editor.isComposing, isTrue);
      final oldClient = clientId(tester);
      h.focus.unfocus();
      await tester.pump();
      expect(h.input.attached, isFalse);
      expect(
        editor.text,
        'a日b\nc日d',
        reason: 'Blur commits the accepted text; it never rolls it back',
      );
      expect(
        editor.isComposing,
        isFalse,
        reason: 'A retired platform client cannot keep owning an IME range',
      );
      final committed = editor.value;
      await stale(tester, oldClient);
      expect(editor.value, same(committed));
      h.focus.requestFocus();
      await tester.pump();
      expect(h.input.currentTextEditingValue!.composing, TextRange.empty);
      editor.undo();
      expect(editor.text, 'ab\ncd');
      editor.redo();
      expect(editor.text, 'a日b\nc日d');
      expect(editor.isComposing, isFalse);
    } finally {
      await h.close(tester);
    }
  }, variant: _desktop);

  testWidgets(
    'read-only handoff commits preedit without losing source or undo',
    (tester) async {
      final editor = SqlEditorController.fromText('ab');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        preedit(h);
        final oldClient = clientId(tester);
        h.input.update(
          controller: editor,
          focusNode: h.focus,
          geometry: h.scroll.geometry,
          readOnly: true,
          viewId: 0,
          keyboardAppearance: Brightness.light,
        );
        await tester.pump();
        expect(h.input.attached, isFalse);
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
        final committed = editor.value;
        await stale(tester, oldClient);
        expect(editor.value, same(committed));
        h.input.update(
          controller: editor,
          focusNode: h.focus,
          geometry: h.scroll.geometry,
          readOnly: false,
          viewId: 0,
          keyboardAppearance: Brightness.light,
        );
        await tester.pump();
        expect(h.input.currentTextEditingValue!.composing, TextRange.empty);
        editor.undo();
        expect(editor.text, 'ab');
        editor.redo();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'controller handoff commits only the previous owner composition',
    (tester) async {
      final editor = SqlEditorController.fromText('ab'),
          next = SqlEditorController.fromText('unrelated');
      addTearDown(next.dispose);
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        preedit(h);
        final oldClient = clientId(tester), nextBefore = next.value;
        h.input.update(
          controller: next,
          focusNode: h.focus,
          geometry: h.scroll.geometry,
          readOnly: false,
          viewId: 0,
          keyboardAppearance: Brightness.light,
        );
        await tester.pump();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
        expect(next.value, same(nextBefore));
        expect(h.input.currentTextEditingValue!.text, 'unrelated');
        await stale(tester, oldClient);
        expect(next.value, same(nextBefore));
        editor.undo();
        expect(editor.text, 'ab');
        editor.redo();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets('platform composition close preserves accepted text and undo', (
    tester,
  ) async {
    final editor = SqlEditorController.fromText('ab');
    editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
    final h = await _InputHarness.mount(tester, editor);
    try {
      preedit(h);
      h.input.connectionClosed();
      expect(editor.text, 'a日b');
      expect(editor.isComposing, isFalse);
      editor.undo();
      expect(editor.text, 'ab');
      editor.redo();
      expect(editor.text, 'a日b');
      expect(editor.isComposing, isFalse);
    } finally {
      await h.close(tester);
    }
  }, variant: _desktop);

  testWidgets(
    'input disposal commits accepted preedit after owner callbacks release',
    (tester) async {
      final editor = SqlEditorController.fromText('ab');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        preedit(h);
        final oldClient = clientId(tester);
        var closing = false, notifiedWhileClosing = false;
        editor.addListener(() {
          if (closing) notifiedWhileClosing = true;
        });
        closing = true;
        h.input.dispose();
        closing = false;
        expect(
          notifiedWhileClosing,
          isFalse,
          reason:
              'A view may be unmounting and must release its listeners before composition commits',
        );
        await tester.pump();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
        final committed = editor.value;
        await stale(tester, oldClient);
        expect(editor.value, same(committed));
        editor.undo();
        expect(editor.text, 'ab');
        editor.redo();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'input disposal during accepted publication never mutates reentrantly',
    (tester) async {
      final editor = SqlEditorController.fromText('ab');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        editor.addListener(h.input.dispose);
        preedit(h);
        await tester.pump();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
        expect(h.input.attached, isFalse);
        editor.undo();
        expect(editor.text, 'ab');
        editor.redo();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'deferred retired-owner cleanup cannot clear a newer composition',
    (tester) async {
      final editor = SqlEditorController.fromText('ab');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        preedit(h);
        h.input.dispose();
        editor.text = 'new owner';
        editor.composing = const TextRange(start: 0, end: 3);
        final next = editor.value;
        await tester.pump();
        expect(editor.value, same(next));
        expect(editor.text, 'new owner');
        expect(editor.composing, const TextRange(start: 0, end: 3));
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'appearance and geometry retain the same preedit and native owner',
    (tester) async {
      final editor = SqlEditorController.fromText('ab');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      final replacement = SqlEditorScrollController();
      try {
        preedit(h);
        final owner = editor.value, client = clientId(tester);
        h.input.update(
          controller: editor,
          focusNode: h.focus,
          geometry: h.scroll.geometry,
          readOnly: false,
          viewId: 0,
          keyboardAppearance: Brightness.dark,
        );
        await tester.pump();
        expect(editor.value, same(owner));
        expect(editor.isComposing, isTrue);
        expect(
          clientId(tester),
          client,
          reason: 'Changing appearance must not retire an IME session',
        );
        h.input.update(
          controller: editor,
          focusNode: h.focus,
          geometry: replacement.geometry,
          readOnly: false,
          viewId: 0,
          keyboardAppearance: Brightness.dark,
        );
        await tester.pump();
        expect(editor.value, same(owner));
        expect(
          h.input.currentTextEditingValue!.composing,
          const TextRange(start: 1, end: 2),
        );
        expect(clientId(tester), client);
        h.input.updateEditingValueWithDeltas([
          const TextEditingDeltaNonTextUpdate(
            oldText: 'a日b',
            selection: TextSelection.collapsed(offset: 2),
            composing: TextRange.empty,
          ),
        ]);
        expect(editor.isComposing, isFalse);
        editor.undo();
        expect(editor.text, 'ab');
        editor.redo();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
      } finally {
        await h.close(tester);
        replacement.dispose();
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'composition retirement is admitted at a full live workspace quota',
    (tester) async {
      final document = SqlDocument(text: 'ab');
      final editor = document.editor,
          budget = DocumentBudget(maxUnits: 128),
          occupied = Object();
      budget.attachAll([document]);
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        preedit(h);
        budget.auxiliary(occupied, budget.maxUnits - budget.units);
        expect(budget.units, budget.maxUnits);
        h.focus.unfocus();
        await tester.pump();
        expect(editor.text, 'a日b');
        expect(
          editor.isComposing,
          isFalse,
          reason:
              'Clearing an admitted range must not reject or strand the accepted draft at quota',
        );
        expect(budget.units, lessThanOrEqualTo(budget.maxUnits));
        editor.undo();
        expect(editor.text, 'ab');
        editor.redo();
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
      } finally {
        await h.close(tester, disposeEditor: false);
        budget.auxiliary(occupied, 0);
        document.dispose();
      }
      expect(budget.units, 0);
    },
    variant: _desktop,
  );

  testWidgets(
    'read-only retirement during a widget build defers notifications',
    (tester) async {
      final editor = SqlEditorController.fromText('ab');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      try {
        preedit(h);
        var insideUpdate = false, notifiedDuringBuildUpdate = false;
        editor.addListener(() {
          if (insideUpdate) notifiedDuringBuildUpdate = true;
        });
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) {
                insideUpdate = true;
                h.input.update(
                  controller: editor,
                  focusNode: h.focus,
                  geometry: h.scroll.geometry,
                  readOnly: true,
                  viewId: 0,
                  keyboardAppearance: Brightness.light,
                );
                insideUpdate = false;
                return Focus(
                  focusNode: h.focus,
                  child: const SizedBox(width: 200, height: 100),
                );
              },
            ),
          ),
        );
        await tester.pump();
        expect(notifiedDuringBuildUpdate, isFalse);
        expect(editor.text, 'a日b');
        expect(editor.isComposing, isFalse);
        expect(h.input.attached, isFalse);
        editor.undo();
        expect(editor.text, 'ab');
        editor.redo();
        expect(editor.text, 'a日b');
        expect(tester.takeException(), isNull);
      } finally {
        await h.close(tester);
      }
    },
    variant: _desktop,
  );

  testWidgets(
    'platform-closed input cannot act on a newer composition or client',
    (tester) async {
      final editor = SqlEditorController.fromText('ab');
      editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
      final h = await _InputHarness.mount(tester, editor);
      SqlEditorInput? newer;
      final other = SqlEditorController.fromText('XY');
      try {
        preedit(h);
        final retired = clientId(tester);
        h.input.connectionClosed();
        expect(editor.isComposing, isFalse);
        editor.composing = const TextRange(start: 0, end: 1);
        final nextComposition = editor.value;
        final reply = await tester.binding.defaultBinaryMessenger
            .handlePlatformMessage(
              'flutter/textinput',
              const JSONMethodCodec().encodeMethodCall(
                MethodCall('TextInputClient.performAction', [
                  retired,
                  'TextInputAction.done',
                ]),
              ),
              null,
            );
        expect(reply, isNotNull);
        const JSONMethodCodec().decodeEnvelope(reply!);
        expect(
          editor.value,
          same(nextComposition),
          reason:
              'A retired platform client ID cannot finish a later composition',
        );
        h.input.performAction(TextInputAction.done);
        expect(
          editor.value,
          same(nextComposition),
          reason:
              'The client entry point also verifies its current window owner',
        );
        editor.clearComposing();
        h.input.requestKeyboard();
        await tester.pump();
        expect(h.input.attached, isTrue);
        other.selection = const CodeLineSelection.collapsed(
          index: 0,
          offset: 2,
        );
        newer = SqlEditorInput(
          controller: other,
          focusNode: h.focus,
          geometry: h.scroll.geometry,
          readOnly: false,
          viewId: 0,
          keyboardAppearance: Brightness.light,
        );
        await tester.pump();
        expect(newer.attached, isTrue);
        expect(h.input.attached, isFalse);
        h.input.connectionClosed();
        expect(
          newer.attached,
          isTrue,
          reason:
              'An old close notification must not clear a newer unrelated platform connection',
        );
        final current = clientId(tester);
        final edit = await tester.binding.defaultBinaryMessenger
            .handlePlatformMessage(
              'flutter/textinput',
              const JSONMethodCodec().encodeMethodCall(
                MethodCall('TextInputClient.updateEditingStateWithDeltas', [
                  current,
                  {
                    'deltas': [
                      {
                        'oldText': 'XY',
                        'deltaText': '!',
                        'deltaStart': 2,
                        'deltaEnd': 2,
                        'selectionBase': 3,
                        'selectionExtent': 3,
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
        expect(edit, isNotNull);
        const JSONMethodCodec().decodeEnvelope(edit!);
        expect(other.text, 'XY!');
        expect(editor.text, 'a日b');
      } finally {
        newer?.dispose();
        await h.close(tester);
        other.dispose();
      }
    },
    variant: _desktop,
  );

  testWidgets('desktop native newline delta and action insert exactly one line', (
    tester,
  ) async {
    final editor = SqlEditorController.fromText('ab');
    editor.selection = const CodeLineSelection.collapsed(index: 0, offset: 1);
    final h = await _InputHarness.mount(tester, editor);
    try {
      h.input.updateEditingValueWithDeltas([
        const TextEditingDeltaInsertion(
          oldText: 'ab',
          textInserted: '\n',
          insertionOffset: 1,
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange.empty,
        ),
      ]);
      expect(editor.text, 'a\nb');
      final edited = editor.value;
      h.input.performAction(TextInputAction.newline);
      expect(
        editor.value,
        same(edited),
        reason:
            'Desktop text deltas own newline insertion; the action is not another edit',
      );
      editor.undo();
      expect(editor.text, 'ab');
      editor.redo();
      expect(editor.text, 'a\nb');
    } finally {
      await h.close(tester);
    }
  }, variant: _desktop);
}
