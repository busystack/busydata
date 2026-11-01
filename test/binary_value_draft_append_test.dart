import 'dart:convert';
import 'dart:typed_data';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/complete_value.dart';
import 'package:busydata/src/features/results/value_document.dart';
import 'package:flutter_test/flutter_test.dart';

const hex = ValuePresentation.hexadecimal;

Uint8List fixture(int length) =>
    Uint8List.fromList(List.generate(length, (index) => index % 256));

void main() {
  test(
    'aligned append preserves full bytes and empty-window recovery shape',
    () {
      final original = fixture(BinaryValueDraft.pageByteLimit);
      final draft = BinaryValueDraft(original);
      final before = draft.snapshot(draft.encodedPage(hex), hex);
      expect(draft.canAppend(draft.encodedPage(hex), hex), isTrue);
      expect(draft.offset, 0);
      draft.appendPage(draft.encodedPage(hex), hex);
      expect(draft.offset, original.length);
      expect(draft.bytes, orderedEquals(original));
      expect(draft.pageBytes, isEmpty);
      expect(draft.encodedPage(hex), isEmpty);
      expect(draft.hasNext, isFalse);
      final empty = draft.snapshot('', hex);
      final recovered = BinaryDraftSnapshot(
        empty.bytes,
        offset: empty.offset,
        input: empty.input,
        mode: empty.mode,
      );
      final restored = BinaryValueDraft(recovered.bytes)
        ..offset = recovered.offset;
      expect(restored.pageLength, 0);
      restored.replacePage('00ff80', hex);
      final expected = [...original, 0, 255, 128];
      expect(restored.bytes, orderedEquals(expected));
      final staged = rpc.Value(binary: restored.bytes);
      expect(rpc.Value.fromBuffer(staged.writeToBuffer()).binary, expected);
      expect(before.bytes, orderedEquals(original));
      expect(empty.bytes, orderedEquals(original));
      expect(draft.bytes, orderedEquals(original));
      expect(original, orderedEquals(fixture(original.length)));
    },
  );

  test('a partial last page can grow to alignment before explicit append', () {
    final draft = BinaryValueDraft([0, 255, 128]);
    expect(draft.canAppend('00ff80', hex), isFalse);
    expect(() => draft.appendPage('00ff80', hex), throwsFormatException);
    expect(draft.bytes, [0, 255, 128]);
    expect(draft.offset, 0);
    final fullPage = '${'ab' * (BinaryValueDraft.pageByteLimit - 3)}00ff80';
    expect(draft.canAppend(fullPage, hex), isTrue);
    expect(draft.bytes, [0, 255, 128]);
    draft.appendPage(fullPage, hex);
    expect(draft.bytes.length, BinaryValueDraft.pageByteLimit);
    expect(draft.offset, BinaryValueDraft.pageByteLimit);
    expect(draft.pageLength, 0);
    draft.replacePage('12', hex);
    expect(draft.bytes.last, 18);
    expect(draft.bytes.length, BinaryValueDraft.pageByteLimit + 1);
  });

  test(
    'append commits reviewed page and previous returns to its exact bytes',
    () {
      final draft = BinaryValueDraft(fixture(BinaryValueDraft.pageByteLimit));
      final original = draft.snapshot(draft.encodedPage(hex), hex);
      draft.appendPage('7f' * BinaryValueDraft.pageByteLimit, hex);
      expect(draft.offset, BinaryValueDraft.pageByteLimit);
      expect(draft.bytes.every((byte) => byte == 127), isTrue);
      draft.move(-1);
      expect(draft.offset, 0);
      expect(draft.encodedPage(hex), '7f' * BinaryValueDraft.pageByteLimit);
      expect(original.bytes, orderedEquals(fixture(original.bytes.length)));
    },
  );

  test('invalid current input never commits bytes or changes page offset', () {
    final draft = BinaryValueDraft(fixture(BinaryValueDraft.pageByteLimit));
    final before = draft.bytes.toList();
    for (final input in <String>[
      'not hex',
      '0',
      '00',
      'aa' * (BinaryValueDraft.pageByteLimit + 1),
    ]) {
      expect(draft.canAppend(input, hex), isFalse);
      expect(() => draft.appendPage(input, hex), throwsFormatException);
      expect(draft.bytes, orderedEquals(before));
      expect(draft.offset, 0);
    }
    expect(draft.canAppend('@@', ValuePresentation.base64), isFalse);
    expect(
      () => draft.appendPage('@@', ValuePresentation.base64),
      throwsFormatException,
    );
    expect(draft.bytes, orderedEquals(before));
  });

  test(
    'an append at full retained capacity is rejected before current edits',
    () {
      final draft = BinaryValueDraft(fixture(completeValueByteLimit));
      draft.offset = completeValueByteLimit - BinaryValueDraft.pageByteLimit;
      final before = draft.bytes.toList(), offset = draft.offset;
      final changed = '7f' * BinaryValueDraft.pageByteLimit;
      expect(draft.canAppend(changed, hex), isFalse);
      expect(() => draft.appendPage(changed, hex), throwsFormatException);
      expect(draft.bytes, orderedEquals(before));
      expect(draft.offset, offset);
    },
  );

  test(
    'empty append navigation never inserts padding or unbounded windows',
    () {
      final draft = BinaryValueDraft(fixture(BinaryValueDraft.pageByteLimit));
      draft.appendPage(draft.encodedPage(hex), hex);
      expect(draft.canAppend('', hex), isFalse);
      final before = draft.snapshot('', hex);
      for (var index = 0; index < 32; index++) {
        draft.appendPage('', hex);
      }
      expect(draft.offset, BinaryValueDraft.pageByteLimit);
      expect(draft.pageLength, 0);
      expect(draft.bytes, orderedEquals(before.bytes));
      final empty = BinaryValueDraft(const []);
      empty.appendPage('', hex);
      expect(empty.bytes, isEmpty);
      expect(empty.offset, 0);
      expect(empty.canAppend('', hex), isFalse);
    },
  );

  test(
    'base64 append binds exact decoded bytes and preserves prior snapshots',
    () {
      final original = fixture(BinaryValueDraft.pageByteLimit);
      final draft = BinaryValueDraft(original);
      draft.appendPage(base64Encode(original), ValuePresentation.base64);
      final saved = draft.snapshot(
        'failed draft retained',
        ValuePresentation.base64,
      );
      final tail = [0, 255, 128, 39, 92, 0];
      draft.replacePage(base64Encode(tail), ValuePresentation.base64);
      expect(draft.bytes, orderedEquals([...original, ...tail]));
      expect(saved.bytes, orderedEquals(original));
      expect(saved.offset, original.length);
      expect(saved.input, 'failed draft retained');
      expect(saved.mode, ValuePresentation.base64);
    },
  );

  test('interior page resizing cannot alter a later page during append', () {
    final original = fixture(BinaryValueDraft.pageByteLimit * 2);
    final draft = BinaryValueDraft(original);
    expect(draft.canAppend('00', hex), isFalse);
    expect(() => draft.appendPage('00', hex), throwsFormatException);
    expect(draft.bytes, orderedEquals(original));
    expect(draft.offset, 0);
    expect(draft.canAppend(draft.encodedPage(hex), hex), isTrue);
    draft.appendPage(draft.encodedPage(hex), hex);
    expect(draft.offset, original.length);
    expect(draft.bytes, orderedEquals(original));
  });
}
