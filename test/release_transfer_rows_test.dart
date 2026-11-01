import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/release_transfer_rows.dart';

void main() {
  Uint8List oracle(int rows, int textBytes) => Uint8List.fromList(
    utf8.encode(
      '"id","text"\n${[for (var id = 1; id <= rows; id++) '"$id","${'x' * textBytes}"\n'].join()}',
    ),
  );

  void verify(List<int> bytes, {int rows = 1, int textBytes = 3}) {
    final expected = ReleaseTransferRows(
      expectedRows: rows,
      textBytes: textBytes,
    );
    expected.add(bytes);
    expected.finish();
  }

  for (final rows in [1, 9, 10, 99, 100, 32768]) {
    test('verifies every sequential ID through $rows', () {
      final bytes = oracle(rows, 3);
      final expected = ReleaseTransferRows(expectedRows: rows, textBytes: 3);
      for (var at = 0; at < bytes.length; at += 7) {
        final end = at + 7 < bytes.length ? at + 7 : bytes.length;
        expected.add(Uint8List.sublistView(bytes, at, end));
      }
      expected.finish();
    });
  }

  test('accepts every two-chunk boundary including empty chunks', () {
    final bytes = oracle(2, 5);
    for (var split = 0; split <= bytes.length; split++) {
      final expected = ReleaseTransferRows(expectedRows: 2, textBytes: 5);
      expected.add(Uint8List.sublistView(bytes, 0, split));
      expected.add([]);
      expected.add(Uint8List.sublistView(bytes, split));
      expected.finish();
    }
  });

  test('every incomplete prefix fails final verification', () {
    final bytes = oracle(2, 5);
    for (var end = 0; end < bytes.length; end++) {
      expect(
        () => verify(bytes.sublist(0, end), rows: 2, textBytes: 5),
        throwsStateError,
      );
    }
  });

  for (final offset in [0, 1, 32767, 65534, 65535]) {
    test(
      'compares a changed byte anywhere in a full 64KiB value at $offset',
      () {
        final bytes = oracle(1, 65536);
        bytes[utf8.encode('"id","text"\n"1","').length + offset] = 0x79;
        expect(() => verify(bytes, textBytes: 65536), throwsStateError);
      },
    );
  }

  test(
    'rejects malformed headers, quoting, IDs, lengths, line endings and extras',
    () {
      for (final csv in [
        '',
        '"wrong","text"\n"1","xxx"\n',
        '"id","text"\n"1","xxx"\r\n',
        '"id","text"\r\n"1","xxx"\n',
        '"id","text"\n1,"xxx"\n',
        '"id","text"\n"01","xxx"\n',
        '"id","text"\n"2","xxx"\n',
        '"id","text"\n"1",xxx\n',
        '"id","text"\n"1","xx"\n',
        '"id","text"\n"1","xxxx"\n',
        '"id","text"\n"1","xxx",NULL\n',
        '"id","text"\n"1","xxx"\n\n',
        '"id","text"\n"1","xxx"\n\u0000',
        '"id","text"\n"1","xxx"\n"2","xxx"\n',
      ]) {
        expect(() => verify(utf8.encode(csv)), throwsStateError);
      }
    },
  );

  test('rejects missing, duplicated or reordered rows', () {
    for (final ids in [
      [1],
      [1, 1],
      [2, 1],
      [1, 3],
      [1, 2, 3],
    ]) {
      final bytes = utf8.encode(
        '"id","text"\n${ids.map((id) => '"$id","xxx"\n').join()}',
      );
      expect(() => verify(bytes, rows: 2), throwsStateError);
    }
  });

  test('invalid fixture sizes fail before stream admission', () {
    for (final sizes in [(0, 1), (32769, 1), (1, 0), (1, 65537)]) {
      expect(
        () => ReleaseTransferRows(expectedRows: sizes.$1, textBytes: sizes.$2),
        throwsArgumentError,
      );
    }
  });

  test('unchanged native export workload has its exact recorded byte count', () {
    // ExportEncoder quotes both fields and writes LF after the header and rows.
    // Count the full workload without allocating its 2GiB byte representation.
    var bytes = utf8.encode('"id","text"\n').length;
    for (var id = 1; id <= 32768; id++) {
      bytes += '"$id","'.length + 65536 + '"\n'.length;
    }
    expect(bytes, 2147833002);
  });

  test('failed or finalized readers cannot resume or accept more data', () {
    final invalid = ReleaseTransferRows(expectedRows: 1, textBytes: 3);
    expect(() => invalid.add([0]), throwsStateError);
    expect(() => invalid.add(oracle(1, 3)), throwsStateError);
    expect(invalid.finish, throwsStateError);
    final complete = ReleaseTransferRows(expectedRows: 1, textBytes: 3);
    complete.add(oracle(1, 3));
    complete.finish();
    expect(() => complete.add([]), throwsStateError);
    expect(complete.finish, throwsStateError);
  });

  test(
    'hash is of exactly the verified complete bytes from one subscription',
    () async {
      final bytes = oracle(12, 5);
      var subscriptions = 0;
      Stream<List<int>> source() async* {
        subscriptions++;
        for (var at = 0; at < bytes.length; at++) {
          yield Uint8List.sublistView(bytes, at, at + 1);
        }
      }

      expect(
        await verifyReleaseTransferBytes(
          source(),
          expectedRows: 12,
          textBytes: 5,
        ),
        sha256.convert(bytes).toString(),
      );
      expect(subscriptions, 1);
    },
  );

  test(
    'stream errors, corruption and truncation cannot produce a verified hash',
    () async {
      for (final bytes in [
        oracle(1, 3).sublist(0, 10),
        [...oracle(1, 3), 0],
      ]) {
        await expectLater(
          verifyReleaseTransferBytes(
            Stream.value(bytes),
            expectedRows: 1,
            textBytes: 3,
          ),
          throwsStateError,
        );
      }
      final failure = StateError('fixture read failure');
      await expectLater(
        verifyReleaseTransferBytes(
          Stream.error(failure),
          expectedRows: 1,
          textBytes: 3,
        ),
        throwsA(same(failure)),
      );
    },
  );
}
