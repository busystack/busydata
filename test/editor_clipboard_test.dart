import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';

void main() {
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  for (final operation in ['cut', 'paste']) {
    testWidgets('$operation ignores a clipboard reply after a document edit', (
      tester,
    ) async {
      final editor = SqlEditorController.fromText('SELECT 1;'),
          response = Completer<Object?>(),
          invoked = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) {
            if (call.method.startsWith('Clipboard.')) {
              invoked.complete();
              return response.future;
            }
            return Future.value();
          });
      editor.selection = const CodeLineSelection(
        baseIndex: 0,
        baseOffset: 0,
        extentIndex: 0,
        extentOffset: 9,
      );
      if (operation == 'cut') {
        editor.cut();
      } else {
        editor.paste();
      }
      await tester.pump();
      expect(invoked.isCompleted, isTrue);
      editor.text = 'SELECT 2;';
      response.complete(operation == 'paste' ? {'text': 'STALE'} : null);
      await tester.pump();
      expect(editor.text, 'SELECT 2;');
      expect(tester.takeException(), isNull);
      editor.dispose();
    });
  }
  testWidgets(
    'clipboard write denial retains SQL and reports a controlled failure',
    (tester) async {
      final editor = SqlEditorController.fromText('SELECT 1;');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            throw PlatformException(code: 'denied');
          });
      Object? rejection;
      editor.onChangeRejected = (error) {
        rejection = error;
        return true;
      };
      final before = editor.value;
      editor.cut();
      await tester.pump();
      expect(
        rejection,
        isA<SqlEditorException>().having(
          (error) => error.code,
          'reason',
          SqlEditorFailure.clipboardUnavailable,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(editor.value, same(before));
      expect(editor.canUndo, isFalse);
      expect(editor.text, 'SELECT 1;');
      editor.dispose();
    },
  );
  testWidgets('oversized Unicode paste is rejected before modifying SQL', (
    tester,
  ) async {
    final editor = SqlEditorController.fromText('SELECT 1;');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => {'text': '漢' * 400000},
        );
    Object? rejection;
    editor.onChangeRejected = (error) {
      rejection = error;
      return true;
    };
    final before = editor.value;
    editor.paste();
    await tester.pump();
    expect(
      rejection,
      isA<SqlEditorException>().having(
        (error) => error.code,
        'reason',
        SqlEditorFailure.clipboardLimit,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(editor.value, same(before));
    expect(editor.canUndo, isFalse);
    expect(editor.text, 'SELECT 1;');
    editor.dispose();
  });
}
