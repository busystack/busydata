import 'dart:async';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

CodeLineSelection caret(int index, int offset) =>
    CodeLineSelection.collapsed(index: index, offset: offset);

void main() {
  final deletions = <String, void Function(SqlEditorController)>{
    'backspace': (editor) => editor.deleteBackward(),
    'delete': (editor) => editor.deleteForward(),
    'word backward': (editor) => editor.deleteWordBackward(),
    'word forward': (editor) => editor.deleteWordForward(),
    'line backward': (editor) => editor.deleteLineBackward(),
    'line forward': (editor) => editor.deleteLineForward(),
  };
  for (final command in deletions.entries) {
    test('${command.key} removes only the containing CRLF grapheme', () {
      for (final (original, at) in [
        ('a\r\nbc', 2),
        ('😀\r\n𝄞z', 3),
        ('e\u0301\r\n👨‍👩‍👦', 3),
      ]) {
        final editor = SqlEditorController.fromText(original);
        addTearDown(editor.dispose);
        editor.selectOffsets(at, at);
        final expected = original.replaceRange(at - 1, at + 1, '');
        command.value(editor);
        expect(editor.text, expected);
        expect(editor.offsetForPosition(editor.selection.extent), at - 1);
        editor.undo();
        expect(editor.text, original);
        expect(editor.offsetForPosition(editor.selection.base), at);
        expect(editor.offsetForPosition(editor.selection.extent), at);
        editor.redo();
        expect(editor.text, expected);
        expect(editor.offsetForPosition(editor.selection.extent), at - 1);
      }
    });

    test(
      '${command.key} keeps exact selected CRLF endpoints and direction',
      () {
        for (final (base, extent, expected) in [
          (1, 2, 'a\nbc'),
          (2, 3, 'a\rbc'),
          (4, 2, 'a\rc'),
        ]) {
          const original = 'a\r\nbc';
          final editor = SqlEditorController.fromText(original);
          addTearDown(editor.dispose);
          editor.selectOffsets(base, extent);
          command.value(editor);
          expect(editor.text, expected);
          editor.undo();
          expect(editor.text, original);
          expect(editor.offsetForPosition(editor.selection.base), base);
          expect(editor.offsetForPosition(editor.selection.extent), extent);
          editor.redo();
          expect(editor.text, expected);
        }
      },
    );

    test(
      '${command.key} preserves exact primary and extra deletion ranges',
      () {
        const original = 'a\r\nbc\r\ndef';
        for (final selected in [false, true]) {
          final editor = SqlEditorController.fromText(original);
          addTearDown(editor.dispose);
          final base = selected ? 7 : 6, extent = 6;
          const extraBase = 2;
          final extraExtent = selected ? 1 : 2;
          editor.selectOffsets(base, extent);
          editor.setExtraSelections([
            SqlSourceSelection(
              source: editor.value.source,
              base: editor.positionForOffset(extraBase),
              extent: editor.positionForOffset(extraExtent),
            ),
          ]);
          final expected = selected ? 'a\nbc\rdef' : 'abcdef';
          command.value(editor);
          expect(editor.text, expected);
          expect(editor.value.secondarySelections, hasLength(1));
          expect(
            editor.offsetForPosition(editor.selection.extent),
            selected ? 5 : 3,
          );
          expect(
            editor.offsetForPosition(
              editor.value.secondarySelections.single.extent,
            ),
            1,
          );
          editor.undo();
          expect(editor.text, original);
          expect(editor.offsetForPosition(editor.selection.base), base);
          expect(editor.offsetForPosition(editor.selection.extent), extent);
          final extra = editor.value.secondarySelections.single;
          expect(editor.offsetForPosition(extra.base), extraBase);
          expect(editor.offsetForPosition(extra.extent), extraExtent);
          editor.redo();
          expect(editor.text, expected);
        }
      },
    );
  }

  test('merged boundary deletion retains an endpoint inside CRLF', () {
    for (final command in deletions.entries.skip(2)) {
      final editor = SqlEditorController.fromText('xa\r\nbc');
      addTearDown(editor.dispose);
      editor.selectOffsets(3, 2);
      editor.setExtraSelections([
        SqlSourceSelection(
          source: editor.value.source,
          base: editor.positionForOffset(2),
          extent: editor.positionForOffset(1),
        ),
      ]);
      command.value(editor);
      expect(editor.text, 'x\nbc');
      expect(editor.value.secondarySelections, isEmpty);
      editor.undo();
      expect(editor.text, 'xa\r\nbc');
      expect(editor.offsetForPosition(editor.selection.base), 3);
      expect(editor.offsetForPosition(editor.selection.extent), 2);
      final extra = editor.value.secondarySelections.single;
      expect(editor.offsetForPosition(extra.base), 2);
      expect(editor.offsetForPosition(extra.extent), 1);
      editor.redo();
      expect(editor.text, 'x\nbc');
    }
  });

  test(
    'rejected exact separator deletion preserves accepted state and redo',
    () {
      final editor = SqlEditorController.fromText('a\r\nbc');
      addTearDown(editor.dispose);
      editor.selectOffsets(5, 5);
      editor.replaceSelection('!');
      editor.undo();
      editor.selectOffsets(2, 2);
      final accepted = editor.value, refusal = StateError('workspace budget');
      var publications = 0, admissions = 0;
      editor.addListener(() => publications++);
      editor.admitChange = (candidate, auxiliary) {
        admissions++;
        expect(candidate.source.text, 'abc');
        expect(auxiliary, 0);
        throw refusal;
      };
      expect(editor.deleteForward, throwsA(same(refusal)));
      expect(admissions, 1);
      expect(publications, 0);
      expect(editor.value, same(accepted));
      expect(editor.canUndo, isFalse);
      expect(editor.canRedo, isTrue);
      editor.admitChange = null;
      editor.redo();
      expect(editor.text, 'a\r\nbc!');
      editor.undo();
      expect(editor.text, 'a\r\nbc');
      expect(editor.offsetForPosition(editor.selection.extent), 2);
    },
  );

  test('equal independently projected values obey the HashSet contract', () {
    final a = SqlSource('a\r\nb\rc\n'), b = SqlSource('a\r\nb\rc\n');
    SqlEditorValue make(SqlSource source) => SqlEditorValue(
      source: source,
      codeLines: CodeLines.from(source.codeLines),
      selection: SqlSourceSelection(
        source: source,
        base: source.positionForOffset(2),
        extent: source.positionForOffset(4),
      ),
      secondarySelections: [
        SqlSourceSelection(
          source: source,
          base: source.positionForOffset(5),
          extent: source.positionForOffset(6),
        ),
      ],
    );
    final first = make(a), second = make(b);
    expect(first, second);
    expect(first.hashCode, second.hashCode);
    expect({first, second}, hasLength(1));
    a.dropMaterialization();
    b.dropMaterialization();
    expect(first.hashCode, second.hashCode);
  });

  test(
    'mixed endings and separator-interior selections survive atomic history',
    () {
      final editor = SqlEditorController.fromText('a\r\nb\rc\n');
      addTearDown(editor.dispose);
      editor.selectOffsets(2, 3);
      expect(editor.selectedText, '\n');
      editor.replaceSelections('Z\r\n');
      expect(editor.text, 'a\rZ\r\nb\rc\n');
      expect(editor.preValue, isNull);
      editor.undo();
      expect(editor.text, 'a\r\nb\rc\n');
      expect(editor.offsetForPosition(editor.selection.base), 2);
      expect(editor.offsetForPosition(editor.selection.extent), 3);
      editor.value.source.dropMaterialization();
      editor.redo();
      expect(editor.text, 'a\rZ\r\nb\rc\n');
      for (var offset = 0; offset <= editor.text.length; offset++) {
        expect(
          editor.offsetForPosition(editor.positionForOffset(offset)),
          offset,
        );
      }
    },
  );

  test(
    'multi-caret edit publishes once and undo restores all original ranges',
    () {
      final editor = SqlEditorController.fromText('one\r\none\rtwo');
      addTearDown(editor.dispose);
      editor.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 3,
      );
      editor.setExtraSelections([
        const CodeLineSelection(
          baseIndex: 1,
          baseOffset: 0,
          extentIndex: 1,
          extentOffset: 3,
        ),
      ]);
      var notifications = 0;
      editor.addListener(() => notifications++);
      editor.replaceSelections('X');
      expect(notifications, 1);
      expect(editor.text, 'X\r\nX\rtwo');
      expect(editor.value.secondarySelections, hasLength(1));
      editor.undo();
      expect(editor.text, 'one\r\none\rtwo');
      expect(editor.selectedText, 'one');
      expect(editor.value.secondarySelections.single.extentOffset, 3);
      editor.redo();
      expect(editor.text, 'X\r\nX\rtwo');
    },
  );

  test(
    'budget rejection preserves published value history and resynchronizes IME',
    () {
      final editor = SqlEditorController.fromText('ok');
      addTearDown(editor.dispose);
      editor.selection = caret(0, 2);
      final accepted = editor.value;
      var rejected = 0, notifications = 0;
      editor.beforeChange = (next) {
        if (next.codeLines.asString(TextLineBreak.lf).length > 2) {
          throw StateError('budget');
        }
      };
      editor.onChangeRejected = (_) {
        rejected++;
        return true;
      };
      editor.addListener(() {
        notifications++;
        expect(identical(editor.value, accepted), isTrue);
      });
      editor.edit(
        const TextEditingValue(
          text: 'oops',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        ),
      );
      expect(rejected, 1);
      expect(notifications, 1);
      expect(editor.text, 'ok');
      expect(editor.composing, TextRange.empty);
      expect(editor.canUndo, isFalse);
    },
  );

  test('composition commits as one undo unit and cancel preserves redo', () {
    final editor = SqlEditorController.fromText('a');
    addTearDown(editor.dispose);
    editor.selection = caret(0, 1);
    editor.edit(
      const TextEditingValue(
        text: 'ab',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
    );
    editor.edit(
      const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
        composing: TextRange(start: 1, end: 3),
      ),
    );
    editor.edit(
      const TextEditingValue(
        text: 'abc',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    editor.undo();
    expect(editor.text, 'a');
    expect(editor.canRedo, isTrue);
    editor.edit(
      const TextEditingValue(
        text: 'ax',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
    );
    editor.edit(
      const TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    expect(editor.canRedo, isTrue);
    editor.redo();
    expect(editor.text, 'abc');
  });

  test('same-text IME caret movement updates every owned caret', () {
    final editor = SqlEditorController.fromText('abcd\nabcd');
    addTearDown(editor.dispose);
    editor.selection = caret(0, 2);
    editor.setExtraSelections([caret(1, 2)]);
    editor.edit(
      const TextEditingValue(
        text: 'abcd',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    expect(editor.selection.extentOffset, 3);
    expect(editor.value.secondarySelections.single.extentOffset, 3);
    expect(editor.canUndo, isFalse);
  });

  test(
    'borrowed previous value is consistent only within accepted notification',
    () {
      final editor = SqlEditorController.fromText('a\r\nb');
      addTearDown(editor.dispose);
      final previous = editor.value;
      var calls = 0;
      editor.addListener(() {
        calls++;
        expect(identical(editor.preValue, previous), isTrue);
        expect(editor.value.source.text, 'Xa\r\nb');
        expect(
          () => editor.replaceSelections('bad'),
          throwsA(
            isA<SqlEditorException>().having(
              (e) => e.code,
              'code',
              SqlEditorFailure.reentrantMutation,
            ),
          ),
        );
      });
      editor.replaceSelections('X');
      expect(calls, 1);
      expect(editor.preValue, isNull);
      expect(previous.source.materializedUnits, 0);
    },
  );

  test(
    'dispose during notification clears borrowed state safely after listeners',
    () {
      final editor = SqlEditorController.fromText('old');
      editor.addListener(() {
        expect(editor.preValue?.codeLines.asString(TextLineBreak.lf), 'old');
        editor.dispose();
      });
      editor.replaceSelections('X');
      expect(editor.preValue, isNull);
      expect(
        () => editor.replaceSelections('Y'),
        throwsA(
          isA<SqlEditorException>().having(
            (e) => e.code,
            'code',
            SqlEditorFailure.disposed,
          ),
        ),
      );
    },
  );

  test(
    'a handled rejection inside a compound edit rolls back the whole transaction',
    () {
      final editor = SqlEditorController.fromText('old');
      addTearDown(editor.dispose);
      editor.onChangeRejected = (_) => true;
      editor.runRevocableOp(() {
        editor.replaceSelections('first');
        editor.setExtraSelections(List.generate(64, (_) => caret(0, 0)));
      });
      expect(editor.text, 'old');
      expect(editor.canUndo, isFalse);
    },
  );

  test(
    'workspace admission does not evict independently bounded undo history',
    () {
      final editor = SqlEditorController.fromText('a');
      addTearDown(editor.dispose);
      editor.admitChange = (next, auxiliary) {
        if (next.source.length + auxiliary > 8) throw StateError('budget');
      };
      editor.replaceSelections('b');
      editor.replaceSelections('c');
      editor.replaceSelections('d');
      editor.replaceSelections('e');
      expect(editor.text, 'bcdea');
      expect(editor.chargedUnits + editor.text.length, lessThanOrEqualTo(8));
      expect(editor.historyLimited, isFalse);
      expect(editor.canUndo, isTrue);
      editor.clearHistory();
      expect(editor.chargedUnits, 0);
    },
  );

  test(
    'the shared history cap bounds old states across independent editors',
    () {
      final first = SqlEditorController.fromText('a' * 200000);
      final second = SqlEditorController.fromText('b' * 200000);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      for (var index = 0; index < 100; index++) {
        final owner = index.isEven ? first : second;
        owner.text = '${index.isEven ? 'a' : 'b'}${'x' * 199998}$index';
      }
      expect(first.historyLimited || second.historyLimited, isTrue);
      expect(first.chargedUnits, 0);
      expect(second.chargedUnits, 0);
      var restored = 0;
      for (final editor in [first, second]) {
        while (editor.canUndo) {
          editor.undo();
          restored++;
        }
      }
      expect(restored, greaterThan(1));
      expect(restored, lessThan(100));
    },
  );

  test(
    'asynchronous paste rejects stale owners and serializes pending reads',
    () async {
      final editor = SqlEditorController.fromText('a\r\nb');
      addTearDown(editor.dispose);
      final pending = Completer<String?>();
      editor.readClipboard = () => pending.future;
      editor.paste();
      expect(
        () => editor.paste(),
        throwsA(
          isA<SqlEditorException>().having(
            (e) => e.code,
            'code',
            SqlEditorFailure.clipboardBusy,
          ),
        ),
      );
      editor.selection = caret(1, 1);
      pending.complete('late');
      await Future<void>.delayed(Duration.zero);
      expect(editor.text, 'a\r\nb');
      expect(editor.chargedUnits, 0);
    },
  );

  test(
    'cut deletes only after successful clipboard ownership remains current',
    () async {
      final editor = SqlEditorController.fromText('abc\r\nnext');
      addTearDown(editor.dispose);
      final pending = Completer<void>();
      String? copied;
      editor.writeClipboard = (text) {
        copied = text;
        return pending.future;
      };
      editor.cut();
      expect(copied, 'abc\r\n');
      expect(editor.text, 'abc\r\nnext');
      editor.selection = caret(1, 0);
      pending.complete();
      await Future<void>.delayed(Duration.zero);
      expect(editor.text, 'abc\r\nnext');
      expect(editor.chargedUnits, 0);
    },
  );

  test(
    'clipboard NUL and UTF-8 limits reject before any native write',
    () async {
      final editor = SqlEditorController.fromText('a\u0000b');
      addTearDown(editor.dispose);
      var writes = 0;
      editor.writeClipboard = (_) async {
        writes++;
      };
      await expectLater(
        editor.copy(),
        throwsA(
          isA<SqlEditorException>().having(
            (e) => e.code,
            'code',
            SqlEditorFailure.clipboardNul,
          ),
        ),
      );
      editor.text = '漢' * 400000;
      await expectLater(
        editor.copy(),
        throwsA(
          isA<SqlEditorException>().having(
            (e) => e.code,
            'code',
            SqlEditorFailure.clipboardLimit,
          ),
        ),
      );
      expect(writes, 0);
    },
  );

  test(
    'queued source loads retain one generation and do not overwrite newer edits',
    () async {
      final editor = SqlEditorController.fromText('old');
      addTearDown(editor.dispose);
      editor.textAsync = 'first\r\n';
      editor.textAsync = 'second\r';
      editor.replaceSelections('X');
      await Future<void>.delayed(Duration.zero);
      expect(editor.text, 'Xold');
      expect(editor.chargedUnits, lessThan(100));
      editor.clearHistory();
      expect(editor.chargedUnits, 0);
    },
  );

  test(
    'paired deletion and exact line joining form one reviewed editing unit',
    () {
      final editor = SqlEditorController.fromText('()\r\nnext');
      addTearDown(editor.dispose);
      editor.selection = caret(0, 1);
      editor.deleteBackward();
      expect(editor.text, '\r\nnext');
      editor.selection = caret(1, 0);
      editor.deleteBackward();
      expect(editor.text, 'next');
      editor.undo();
      expect(editor.text, '\r\nnext');
    },
  );
  test(
    'synchronous clipboard errors release ownership and permit the next operation',
    () async {
      final editor = SqlEditorController.fromText('abc');
      addTearDown(editor.dispose);
      final errors = <Object>[];
      editor.onChangeRejected = (error) {
        errors.add(error);
        return true;
      };
      editor.readClipboard = () => throw StateError('read unavailable');
      editor.paste();
      await Future<void>.delayed(Duration.zero);
      expect(editor.chargedUnits, 0);
      expect(editor.text, 'abc');
      editor.writeClipboard = (_) => throw StateError('write unavailable');
      editor.cut();
      await Future<void>.delayed(Duration.zero);
      expect(editor.chargedUnits, 0);
      expect(editor.text, 'abc');
      expect(errors, hasLength(2));
      editor.readClipboard = () async => 'X';
      editor.paste();
      await Future<void>.delayed(Duration.zero);
      expect(editor.text, 'Xabc');
    },
  );

  test('disposed clipboard owner never performs a native write', () async {
    final editor = SqlEditorController.fromText('abc');
    var writes = 0;
    editor.writeClipboard = (_) async {
      writes++;
    };
    editor.dispose();
    await expectLater(
      editor.copy(),
      throwsA(
        isA<SqlEditorException>().having(
          (error) => error.code,
          'code',
          SqlEditorFailure.disposed,
        ),
      ),
    );
    expect(writes, 0);
  });

  test(
    'published projections detach mutable caller-owned empty child lists',
    () {
      final children = <CodeLine>[];
      final editor = SqlEditorController(
        codeLines: CodeLines.of([CodeLine('row', children)]),
      );
      addTearDown(editor.dispose);
      final published = editor.value;
      children.add(CodeLine('injected'));
      expect(published.codeLines.lineCount, 1);
      expect(editor.text, 'row');
      expect(
        () => published.codeLines.first.chunks.add(CodeLine('bad')),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'duplicate explicit caret ranges reject before source or history changes',
    () {
      final editor = SqlEditorController.fromText('row');
      addTearDown(editor.dispose);
      final before = editor.value;
      expect(
        () => editor.replaceSelections('X', ranges: [caret(0, 1), caret(0, 1)]),
        throwsA(
          isA<SqlEditorException>().having(
            (error) => error.code,
            'code',
            SqlEditorFailure.overlappingRanges,
          ),
        ),
      );
      expect(editor.value, same(before));
      expect(editor.canUndo, isFalse);
    },
  );

  test(
    'programmatic source replacement commits preedit before its separate undo unit',
    () {
      final editor = SqlEditorController.fromText('x');
      addTearDown(editor.dispose);
      editor.selection = caret(0, 1);
      editor.edit(
        const TextEditingValue(
          text: 'x日',
          selection: TextSelection.collapsed(offset: 2),
          composing: TextRange(start: 1, end: 2),
        ),
      );
      editor.runRevocableOp(() => editor.text = 'replacement\r\n');
      editor.undo();
      expect(editor.text, 'x日');
      expect(editor.composing, TextRange.empty);
      editor.undo();
      expect(editor.text, 'x');
      editor.redo();
      expect(editor.text, 'x日');
      editor.redo();
      expect(editor.text, 'replacement\r\n');
    },
  );

  test(
    'public word-forward commands handle a trailing-space boundary safely',
    () {
      final editor = SqlEditorController.fromText('alpha   \r\n  ');
      addTearDown(editor.dispose);
      editor.selection = caret(0, 5);
      editor.moveCursorToWordBoundaryForward();
      expect(editor.selection, caret(0, 8));
      editor.extendSelectionToWordBoundaryForward();
      expect(editor.selection.baseOffset, 8);
      expect(editor.selection.extentIndex, 1);
      expect(editor.selection.extentOffset, 2);
      expect(editor.selectedText, '\r\n  ');
      expect(editor.canUndo, isFalse);
    },
  );
  test('native edit uses exact CRLF-interior source ownership', () {
    final editor = SqlEditorController.fromText('a\r\nb');
    addTearDown(editor.dispose);
    editor.selectOffsets(2, 2);
    final accepted = editor.applyNativeEdit(
      expectedOwner: editor.value,
      start: 2,
      end: 2,
      replacement: 'X',
      selectionDelta: 0,
      extentDelta: 0,
    );
    expect(accepted, isTrue);
    expect(editor.text, 'a\rX\nb');
    expect(editor.offsetForPosition(editor.selection.extent), 3);
    editor.undo();
    expect(editor.text, 'a\r\nb');
    expect(editor.offsetForPosition(editor.selection.extent), 2);
  });

  test(
    'native multi-caret edit maps composition after lower-position shifts',
    () {
      final editor = SqlEditorController.fromText('a\r\nb\r\nc');
      addTearDown(editor.dispose);
      editor.selection = caret(1, 1);
      editor.setExtraSelections([caret(0, 1)]);
      expect(
        editor.applyNativeEdit(
          expectedOwner: editor.value,
          start: 4,
          end: 4,
          replacement: '日',
          selectionDelta: 0,
          extentDelta: 0,
          composingDeltas: const SqlNativeComposingRange(start: -1, end: 0),
        ),
        isTrue,
      );
      expect(editor.text, 'a日\r\nb日\r\nc');
      expect(editor.selection, caret(1, 2));
      expect(editor.composing, const TextRange(start: 1, end: 2));
      expect(editor.value.secondarySelections.single, caret(0, 2));
      expect(
        editor.applyNativeEdit(
          expectedOwner: editor.value,
          start: 6,
          end: 6,
          replacement: '',
          selectionDelta: 0,
          extentDelta: 0,
        ),
        isTrue,
      );
      editor.undo();
      expect(editor.text, 'a\r\nb\r\nc');
      expect(editor.value.secondarySelections.single, caret(0, 1));
    },
  );

  test('native non-text selection changes retain each selection endpoint', () {
    final editor = SqlEditorController.fromText('abcdef\nabcdef');
    addTearDown(editor.dispose);
    editor.selection = const CodeLineSelection(
      baseIndex: 0,
      baseOffset: 2,
      extentIndex: 0,
      extentOffset: 4,
    );
    editor.setExtraSelections([
      const CodeLineSelection(
        baseIndex: 1,
        baseOffset: 1,
        extentIndex: 1,
        extentOffset: 3,
      ),
    ]);
    expect(
      editor.applyNativeEdit(
        expectedOwner: editor.value,
        start: 4,
        end: 4,
        replacement: '',
        selectionDelta: -2,
        extentDelta: 1,
      ),
      isTrue,
    );
    expect(editor.selection.baseOffset, 2);
    expect(editor.selection.extentOffset, 5);
    expect(editor.value.secondarySelections.single.baseOffset, 1);
    expect(editor.value.secondarySelections.single.extentOffset, 4);
    expect(editor.text, 'abcdef\nabcdef');
    expect(editor.canUndo, isFalse);
  });

  test('a stale native edit cannot reuse a superseded selection owner', () {
    final editor = SqlEditorController.fromText('abc');
    addTearDown(editor.dispose);
    final stale = editor.value;
    editor.selection = caret(0, 2);
    final current = editor.value;
    expect(
      editor.applyNativeEdit(
        expectedOwner: stale,
        start: 0,
        end: 0,
        replacement: 'late',
        selectionDelta: 0,
        extentDelta: 0,
      ),
      isFalse,
    );
    expect(editor.value, same(current));
    expect(editor.text, 'abc');
  });

  test('cross-line native composition is refused before any publication', () {
    final editor = SqlEditorController.fromText('');
    addTearDown(editor.dispose);
    final original = editor.value;
    expect(
      () => editor.applyNativeEdit(
        expectedOwner: original,
        start: 0,
        end: 0,
        replacement: 'a\r\nb',
        selectionDelta: 0,
        extentDelta: 0,
        composingDeltas: const SqlNativeComposingRange(start: -4, end: 0),
      ),
      throwsA(
        isA<SqlEditorException>().having(
          (error) => error.code,
          'code',
          SqlEditorFailure.composing,
        ),
      ),
    );
    expect(editor.value, same(original));
    expect(editor.canUndo, isFalse);
  });

  test(
    'native admission refusal returns false without changing an accepted owner',
    () {
      final editor = SqlEditorController.fromText('abc');
      addTearDown(editor.dispose);
      final original = editor.value;
      editor.beforeChange = (_) => throw StateError('budget');
      editor.onChangeRejected = (_) => true;
      expect(
        editor.applyNativeEdit(
          expectedOwner: original,
          start: 0,
          end: 0,
          replacement: 'X',
          selectionDelta: 0,
          extentDelta: 0,
        ),
        isFalse,
      );
      expect(editor.value, same(original));
      expect(editor.canUndo, isFalse);
    },
  );

  test(
    'native cross-line replication refuses incompatible EOL spans atomically',
    () {
      const original = 'a\r\nb\nc\nd';
      final editor = SqlEditorController.fromText(original);
      addTearDown(editor.dispose);
      editor.selection = caret(1, 0);
      editor.setExtraSelections([caret(3, 0)]);
      final before = editor.value;
      expect(
        () => editor.applyNativeEdit(
          expectedOwner: before,
          start: 1,
          end: 3,
          replacement: '',
          selectionDelta: 0,
          extentDelta: 0,
        ),
        throwsA(
          isA<SqlEditorException>().having(
            (error) => error.code,
            'code',
            SqlEditorFailure.staleSelection,
          ),
        ),
      );
      expect(editor.value, same(before));
      expect(editor.text, original);
      expect(editor.canUndo, isFalse);
      editor.deleteBackward();
      expect(editor.text, 'ab\ncd');
      editor.undo();
      expect(editor.text, original);
      expect(editor.value.secondarySelections.single, caret(3, 0));
    },
  );

  test(
    'whole final-line clipboard copy has a terminator while explicit selection is exact',
    () async {
      final editor = SqlEditorController.fromText(
        'row',
        const CodeLineOptions(lineBreak: TextLineBreak.crlf),
      );
      addTearDown(editor.dispose);
      final copied = <String>[];
      editor.writeClipboard = (text) async {
        copied.add(text);
      };
      await editor.copy();
      expect(copied.single, 'row\r\n');
      editor.selectOffsets(0, 3);
      await editor.copy();
      expect(copied.last, 'row');
      expect(editor.text, 'row');
    },
  );
  test(
    'current native resource refusal reaches owned presentation once without mutation',
    () {
      final editor = SqlEditorController.fromText('row');
      addTearDown(editor.dispose);
      editor.replaceSelections('X');
      final before = editor.value;
      var calls = 0, notifications = 0;
      final owner = Object();
      editor.addRejectionHandler(owner, (error) {
        calls++;
        expect(
          error,
          isA<SqlEditorException>().having(
            (error) => error.code,
            'reason',
            SqlEditorFailure.documentLimit,
          ),
        );
        return true;
      });
      editor.addListener(() => notifications++);
      expect(
        editor.rejectNativeInput(
          expectedOwner: before,
          reason: SqlEditorFailure.documentLimit,
        ),
        isTrue,
      );
      expect(calls, 1);
      expect(notifications, 0);
      expect(editor.value, same(before));
      editor.undo();
      expect(editor.text, 'row');
    },
  );

  test(
    'a superseded native refusal cannot notify the current presentation owner',
    () {
      final editor = SqlEditorController.fromText('row');
      addTearDown(editor.dispose);
      final stale = editor.value;
      editor.selection = caret(0, 1);
      final current = editor.value;
      var calls = 0;
      editor.addRejectionHandler(Object(), (_) {
        calls++;
        return true;
      });
      expect(
        editor.rejectNativeInput(
          expectedOwner: stale,
          reason: SqlEditorFailure.documentLimit,
        ),
        isFalse,
      );
      expect(calls, 0);
      expect(editor.value, same(current));
      expect(editor.canUndo, isFalse);
    },
  );
  test(
    'verified native delta batches publish once and use each staged owner',
    () {
      final editor = SqlEditorController.fromText('row');
      addTearDown(editor.dispose);
      var notifications = 0;
      editor.addListener(() => notifications++);
      editor.runRevocableOp(() {
        final first = editor.value;
        expect(
          editor.applyNativeEdit(
            expectedOwner: first,
            start: 0,
            end: 0,
            replacement: 'X',
            selectionDelta: 0,
            extentDelta: 0,
          ),
          isTrue,
        );
        final staged = editor.value;
        expect(staged, isNot(same(first)));
        expect(
          editor.applyNativeEdit(
            expectedOwner: first,
            start: 0,
            end: 0,
            replacement: 'stale',
            selectionDelta: 0,
            extentDelta: 0,
          ),
          isFalse,
        );
        expect(
          editor.applyNativeEdit(
            expectedOwner: staged,
            start: 1,
            end: 1,
            replacement: 'Y',
            selectionDelta: 0,
            extentDelta: 0,
          ),
          isTrue,
        );
        expect(notifications, 0);
      });
      expect(notifications, 1);
      expect(editor.text, 'XYrow');
      editor.undo();
      expect(editor.text, 'row');
      expect(editor.canUndo, isFalse);
    },
  );

  test('one native batch commits multi-caret composition as one undo unit', () {
    final editor = SqlEditorController.fromText('x\r\nx');
    addTearDown(editor.dispose);
    editor.selection = caret(0, 1);
    editor.setExtraSelections([caret(1, 1)]);
    var notifications = 0;
    editor.addListener(() => notifications++);
    editor.runRevocableOp(() {
      expect(
        editor.applyNativeEdit(
          expectedOwner: editor.value,
          start: 1,
          end: 1,
          replacement: '日',
          selectionDelta: 0,
          extentDelta: 0,
          composingDeltas: const SqlNativeComposingRange(start: -1, end: 0),
        ),
        isTrue,
      );
      expect(
        editor.applyNativeEdit(
          expectedOwner: editor.value,
          start: 1,
          end: 2,
          replacement: '日本',
          selectionDelta: 0,
          extentDelta: 0,
          composingDeltas: const SqlNativeComposingRange(start: -2, end: 0),
        ),
        isTrue,
      );
      expect(
        editor.applyNativeEdit(
          expectedOwner: editor.value,
          start: 3,
          end: 3,
          replacement: '',
          selectionDelta: 0,
          extentDelta: 0,
        ),
        isTrue,
      );
    });
    expect(notifications, 1);
    expect(editor.text, 'x日本\r\nx日本');
    expect(editor.composing, TextRange.empty);
    editor.undo();
    expect(editor.text, 'x\r\nx');
    expect(editor.value.secondarySelections.single, caret(1, 1));
    expect(editor.canUndo, isFalse);
  });

  test('a refused second native delta rolls back the entire staged batch', () {
    final editor = SqlEditorController.fromText('row');
    addTearDown(editor.dispose);
    final original = editor.value;
    var notifications = 0, refusals = 0;
    editor.addListener(() => notifications++);
    editor.onChangeRejected = (_) {
      refusals++;
      return true;
    };
    editor.runRevocableOp(() {
      expect(
        editor.applyNativeEdit(
          expectedOwner: editor.value,
          start: 0,
          end: 0,
          replacement: 'X',
          selectionDelta: 0,
          extentDelta: 0,
        ),
        isTrue,
      );
      expect(
        editor.applyNativeEdit(
          expectedOwner: editor.value,
          start: 1,
          end: 1,
          replacement: 'a' * SqlSource.maxUnits,
          selectionDelta: 0,
          extentDelta: 0,
        ),
        isFalse,
      );
    });
    expect(refusals, 1);
    expect(notifications, 0);
    expect(editor.value, same(original));
    expect(editor.text, 'row');
    expect(editor.canUndo, isFalse);
  });
}
