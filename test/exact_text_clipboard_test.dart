import 'dart:convert';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/exact_text_clipboard.dart';
import 'package:busydata/src/ui/common/result_extractors.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final writes = <String>[];
  const previous = 'previous clipboard · 漢😀';
  late String clipboard;

  setUp(() {
    clipboard = previous;
    writes.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
            writes.add(clipboard);
          }
          if (call.method == 'Clipboard.getData') return {'text': clipboard};
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  for (final text in [
    '\u0000',
    '\u0000after',
    'before\u0000after',
    'before\u0000',
  ]) {
    test(
      'NUL at ${text.indexOf('\u0000')} of ${text.length} is rejected before platform write',
      () async {
        await expectLater(
          writeExactTextClipboard(text),
          throwsA(
            isA<TextClipboardUnavailable>().having(
              (error) => error.reason,
              'reason',
              TextClipboardUnavailableReason.embeddedNul,
            ),
          ),
        );
        expect(writes, isEmpty);
        expect((await Clipboard.getData(Clipboard.kTextPlain))!.text, previous);
      },
    );
  }

  test('native-admissible text is written without transformation', () async {
    const text = '漢😀\r\n\t"\\9007199254740993.000000001';
    await writeExactTextClipboard(text);
    expect(writes, [text]);
    expect(clipboard.codeUnits, orderedEquals(text.codeUnits));
  });

  test('exact UTF-8 byte ceiling remains admitted', () async {
    final text =
        '漢' * (resultClipboardByteLimit ~/ 3) +
        'a' * (resultClipboardByteLimit % 3);
    expect(utf8.encode(text), hasLength(resultClipboardByteLimit));
    await writeExactTextClipboard(text);
    expect(writes, [text]);
  });

  test(
    'oversized ASCII and multibyte payloads preserve the clipboard',
    () async {
      for (final text in [
        'a' * (resultClipboardByteLimit + 1),
        '漢' * (resultClipboardByteLimit ~/ 3 + 1),
        '😀' * (resultClipboardByteLimit ~/ 4 + 1),
      ]) {
        await expectLater(
          writeExactTextClipboard(text),
          throwsA(
            isA<TextClipboardUnavailable>().having(
              (error) => error.reason,
              'reason',
              TextClipboardUnavailableReason.byteLimit,
            ),
          ),
        );
        expect(writes, isEmpty);
        expect(clipboard, previous);
      }
    },
  );

  test(
    'extractor selection stays explicit and the retained NUL stays exact',
    () async {
      final value = rpc.Value(text: 'before\u0000after');
      final original = value.writeToBuffer();
      final rows = [
        [value],
      ];
      for (final format in ['text', 'csv']) {
        final payload = copyFetchedValues(rows, format);
        expect(payload, contains('\u0000'));
        await expectLater(
          writeExactTextClipboard(payload),
          throwsA(isA<TextClipboardUnavailable>()),
        );
        expect(clipboard, previous);
        expect(writes, isEmpty);
      }
      final json = copyFetchedValues(rows, 'json');
      expect(json, isNot(contains('\u0000')));
      await writeExactTextClipboard(json);
      expect(jsonDecode(clipboard), [
        ['before\u0000after'],
      ]);
      expect(value.writeToBuffer(), orderedEquals(original));
    },
  );
}
