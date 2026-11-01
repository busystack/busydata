import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/complete_value.dart';
import 'package:busydata/src/features/results/value_document.dart';
import 'package:busydata/src/features/results/result_presentation.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

rpc.Value source(List<int> bytes, {bool binary = false, bool json = false}) =>
    binary
    ? rpc.Value(
        binary: bytes.take(4).toList(),
        valueId: 'owned',
        truncated: true,
        originalBytes: Int64(bytes.length),
      )
    : json
    ? rpc.Value(
        json: utf8
            .decode(bytes, allowMalformed: true)
            .substring(
              0,
              utf8.decode(bytes, allowMalformed: true).length.clamp(0, 4),
            ),
        valueId: 'owned',
        truncated: true,
        originalBytes: Int64(bytes.length),
      )
    : rpc.Value(
        text: utf8
            .decode(bytes, allowMalformed: true)
            .substring(
              0,
              utf8.decode(bytes, allowMalformed: true).length.clamp(0, 4),
            ),
        valueId: 'owned',
        truncated: true,
        originalBytes: Int64(bytes.length),
      );
Future<rpc.ValueChunk> page(List<int> bytes, int offset) async {
  final end = (offset + 65536).clamp(0, bytes.length);
  return rpc.ValueChunk(
    data: bytes.sublist(offset, end),
    totalBytes: Int64(bytes.length),
    complete: end == bytes.length,
  );
}

void main() {
  test(
    'empty binary oneof remains binary and malformed UTF16 is never transformed',
    () {
      final empty = rpc.Value(binary: const []);
      expect(editedValue(empty, '00ff', ValuePresentation.hexadecimal).binary, [
        0,
        255,
      ]);
      expect(
        editedValue(empty, '', ValuePresentation.hexadecimal).whichData(),
        rpc.Value_Data.binary,
      );
      expect(
        () => editedValue(
          rpc.Value(text: 'original'),
          String.fromCharCode(0xd800),
          ValuePresentation.raw,
        ),
        throwsFormatException,
      );
      expect(
        () => editedValue(
          rpc.Value(text: 'original'),
          String.fromCharCode(0xdc00),
          ValuePresentation.raw,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'explicit complete text joins split UTF8 exactly and keeps source provenance unchanged',
    () async {
      final text = '${'x' * 65535}😀漢\r\n${'y' * 70000}',
          bytes = utf8.encode(text),
          original = source(bytes);
      final encoded = original.writeToBuffer(), offsets = <int>[];
      final value = await readCompleteValue(original, (offset) {
        offsets.add(offset);
        return page(bytes, offset);
      }, () => true);
      expect(value.text, text);
      expect(value.truncated, isFalse);
      expect(value.valueId, isEmpty);
      expect(offsets, [0, 65536, 131072]);
      expect(original.writeToBuffer(), orderedEquals(encoded));
    },
  );
  test('JSON numeric lexemes and duplicate keys are not reformatted', () async {
    const text =
        '{"n":123456789012345678901234567890.0000000001,"n":-0.00000000001}';
    final bytes = utf8.encode(text);
    expect(
      (await readCompleteValue(
        source(bytes, json: true),
        (offset) => page(bytes, offset),
        () => true,
      )).json,
      text,
    );
  });
  test(
    'byte and UTF16 admission, malformed bytes and forged chunks fail explicitly',
    () async {
      expect(
        completeValueEligible(
          rpc.Value(
            text: 'preview',
            truncated: true,
            valueId: 'id',
            originalBytes: Int64(1048577),
          ),
        ),
        isFalse,
      );
      final text = utf8.encode('x' * 262145);
      await expectLater(
        readCompleteValue(
          source(text),
          (offset) => page(text, offset),
          () => true,
        ),
        throwsA(isA<CompleteValueLimit>()),
      );
      final correct = utf8.encode('exact full value');
      await expectLater(
        readCompleteValue(
          source(correct).deepCopy()..text = 'forged',
          (offset) => page(correct, offset),
          () => true,
        ),
        throwsStateError,
      );
      final malformed = [0xc0, 0x80];
      await expectLater(
        readCompleteValue(
          source(malformed),
          (offset) => page(malformed, offset),
          () => true,
        ),
        throwsFormatException,
      );
      await expectLater(
        readCompleteValue(
          source([1, 2]),
          (offset) async =>
              rpc.ValueChunk(data: [1], totalBytes: Int64(3), complete: false),
          () => true,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'superseded complete reads never request or apply another page',
    () async {
      final bytes = Uint8List(70000),
          pending = Completer<rpc.ValueChunk>(),
          offsets = <int>[];
      var current = true;
      final operation = readCompleteValue(source(bytes, binary: true), (
        offset,
      ) {
        offsets.add(offset);
        return pending.future;
      }, () => current);
      current = false;
      pending.complete(await page(bytes, 0));
      await expectLater(operation, throwsA(isA<RetainedValueOwnerChanged>()));
      expect(offsets, [0]);
    },
  );
  test(
    'binary pages preserve a full1MiB byte buffer with copy-on-write snapshots',
    () {
      final bytes = Uint8List.fromList(
            List.generate(1048576, (index) => index % 256),
          ),
          draft = BinaryValueDraft(bytes);
      final saved = draft.snapshot(
        'invalid draft retained',
        ValuePresentation.hexadecimal,
      );
      draft.replacePage(
        '00' * BinaryValueDraft.pageByteLimit,
        ValuePresentation.hexadecimal,
      );
      expect(draft.bytes[1], 0);
      expect(draft.bytes[BinaryValueDraft.pageByteLimit + 1], 1);
      expect(saved.bytes[1], 1);
      expect(bytes[1], 1);
      for (var index = 0; index < 63; index++) {
        draft.move(1);
      }
      expect(draft.offset, 1048576 - BinaryValueDraft.pageByteLimit);
      expect(draft.hasNext, isFalse);
      expect(
        draft.encodedPage(ValuePresentation.base64),
        base64Encode(bytes.sublist(1048576 - BinaryValueDraft.pageByteLimit)),
      );
      expect(() => draft.bytes[0] = 7, throwsUnsupportedError);
    },
  );
  test(
    'binary last page may resize but middle-page length and invalid encodings cannot change bytes',
    () {
      final draft = BinaryValueDraft(Uint8List(65537));
      expect(
        () => draft.replacePage('ff', ValuePresentation.hexadecimal),
        throwsFormatException,
      );
      expect(draft.bytes.length, 65537);
      for (var index = 0; index < 4; index++) {
        draft.move(1);
      }
      draft.replacePage('AP8=', ValuePresentation.base64);
      expect(draft.bytes.length, 65538);
      expect(draft.bytes.last, 255);
      expect(
        () => draft.replacePage('zz', ValuePresentation.hexadecimal),
        throwsFormatException,
      );
      expect(draft.bytes.last, 255);
    },
  );
  test(
    'binary retry drafts retain invalid page input within one shared presentation budget',
    () {
      final state = ResultPresentationState(),
          binary = BinaryValueDraft(Uint8List(1048576));
      state.retainBinaryDraft(
        1,
        1,
        binary.snapshot('zz', ValuePresentation.hexadecimal),
      );
      expect(state.binaryDraft(1, 1)!.input, 'zz');
      state.retainDraft(2, 1, 'x' * 262144);
      expect(() => state.retainDraft(3, 1, 'x' * 262144), throwsStateError);
      expect(state.binaryDraft(1, 1)!.bytes.length, 1048576);
      state.clearDraft(1, 1);
      expect(state.binaryDraft(1, 1), isNull);
    },
  );
}
