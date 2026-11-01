import 'dart:collection';
import 'dart:typed_data';
import 'package:busydata/src/features/results/complete_value.dart';
import 'package:busydata/src/features/results/hexadecimal_display.dart';
import 'package:busydata/src/features/results/value_document.dart';
import 'package:flutter_test/flutter_test.dart';

const _allBytesHex =
    '000102030405060708090a0b0c0d0e0f'
    '101112131415161718191a1b1c1d1e1f'
    '202122232425262728292a2b2c2d2e2f'
    '303132333435363738393a3b3c3d3e3f'
    '404142434445464748494a4b4c4d4e4f'
    '505152535455565758595a5b5c5d5e5f'
    '606162636465666768696a6b6c6d6e6f'
    '707172737475767778797a7b7c7d7e7f'
    '808182838485868788898a8b8c8d8e8f'
    '909192939495969798999a9b9c9d9e9f'
    'a0a1a2a3a4a5a6a7a8a9aaabacadaeaf'
    'b0b1b2b3b4b5b6b7b8b9babbbcbdbebf'
    'c0c1c2c3c4c5c6c7c8c9cacbcccdcecf'
    'd0d1d2d3d4d5d6d7d8d9dadbdcdddedf'
    'e0e1e2e3e4e5e6e7e8e9eaebecedeeef'
    'f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff';

Uint8List _fixture(int length) {
  final bytes = Uint8List(length);
  for (var index = 0; index < length; index++) {
    bytes[index] = index % 256;
  }
  return bytes;
}

void main() {
  test('empty input has an exact empty representation', () {
    expect(encodeHexDisplay(const []), '');
    expect(encodeHexDisplay(Uint8List(0)), '');
  });

  test('leading zeros and both nibbles remain exact lowercase', () {
    expect(
      encodeHexDisplay(const [0, 1, 15, 16, 127, 128, 254, 255]),
      '00010f107f80feff',
    );
  });

  test('every possible byte matches the complete fixed hexadecimal vector', () {
    expect(
      encodeHexDisplay(List.generate(256, (index) => index)),
      _allBytesHex,
    );
    expect(encodeHexDisplay(_fixture(256)), _allBytesHex);
  });

  test(
    'a byte view preserves its exact range and leaves the source unchanged',
    () {
      final source = Uint8List.fromList([17, 0, 255, 128, 34]);
      final view = Uint8List.sublistView(source, 1, 4).asUnmodifiableView();
      expect(encodeHexDisplay(view), '00ff80');
      expect(source, [17, 0, 255, 128, 34]);
    },
  );

  test('the entire retained chunk is encoded without truncation', () {
    final source = _fixture(ValueDocument.chunkBytes);
    final encoded = encodeHexDisplay(source);
    expect(encoded.length, ValueDocument.chunkBytes * 2);
    expect(encoded, _allBytesHex * (ValueDocument.chunkBytes ~/ 256));
    expect(source, orderedEquals(_fixture(ValueDocument.chunkBytes)));
  });

  test('the complete-value boundary retains every byte', () {
    final source = _fixture(completeValueByteLimit);
    final encoded = encodeHexDisplay(source);
    expect(encoded.length, completeValueByteLimit * 2);
    expect(encoded, _allBytesHex * (completeValueByteLimit ~/ 256));
  });

  test('an oversized input is rejected before its elements are read', () {
    expect(
      () => encodeHexDisplay(_UnreadableOversizedBytes()),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'VALUE_DISPLAY_LIMIT',
        ),
      ),
    );
  });

  test('invalid bytes are rejected rather than narrowed or transformed', () {
    for (final bytes in <List<int>>[
      [-1],
      [256],
      [0, 255, 65536],
      [0, -256, 255],
    ]) {
      final original = List<int>.of(bytes);
      expect(
        () => encodeHexDisplay(bytes),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'VALUE_BYTE_INVALID',
          ),
        ),
      );
      expect(bytes, original);
    }
  });
}

class _UnreadableOversizedBytes extends ListBase<int> {
  @override
  int get length => completeValueByteLimit + 1;
  @override
  set length(int value) => throw UnsupportedError('read-only');
  @override
  int operator [](int index) => throw StateError('Oversized input was read');
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('read-only');
}
