import 'package:crypto/crypto.dart';

/// Hash and verify the same complete byte stream, without decoding its rows.
Future<String> verifyReleaseTransferBytes(
  Stream<List<int>> source, {
  required int expectedRows,
  required int textBytes,
}) async {
  final expected = ReleaseTransferRows(
    expectedRows: expectedRows,
    textBytes: textBytes,
  );
  final digest = await sha256
      .bind(
        source.map((bytes) {
          expected.add(bytes);
          return bytes;
        }),
      )
      .single;
  expected.finish();
  return digest.toString();
}

/// Exact byte verifier for the release benchmark's two-column CSV fixture.
///
/// This recognizes only its declared sequential integer IDs and ASCII x values,
/// including the exact header, quoting and LF endings from ExportEncoder.
/// It retains counters and one small prefix, never a decoded row or an input
/// chunk. The benchmark
/// supplies 32,768 rows of 65,536 bytes; smaller fixtures support focused tests.
class ReleaseTransferRows {
  ReleaseTransferRows({required this.expectedRows, required this.textBytes}) {
    if (expectedRows < 1 ||
        expectedRows > 32768 ||
        textBytes < 1 ||
        textBytes > 65536) {
      throw ArgumentError('Release transfer fixture bounds');
    }
  }

  final int expectedRows;
  final int textBytes;
  _TransferPart _part = _TransferPart.header;
  String _token = '"id","text"\n';
  int _tokenOffset = 0, _remaining = 0, _rows = 0;
  bool _closed = false, _failed = false;

  void add(List<int> bytes) {
    if (_closed || _failed) _reject();
    var at = 0;
    while (at < bytes.length) {
      if (_part == _TransferPart.payload) {
        final available = bytes.length - at;
        final count = available < _remaining ? available : _remaining;
        final end = at + count;
        while (at < end) {
          if (bytes[at++] != 0x78) _reject();
        }
        _remaining -= count;
        if (_remaining == 0) {
          _part = _TransferPart.ending;
          _token = '"\n';
          _tokenOffset = 0;
        }
      } else {
        if (_part == _TransferPart.done ||
            bytes[at++] != _token.codeUnitAt(_tokenOffset++)) {
          _reject();
        }
        if (_tokenOffset != _token.length) continue;
        switch (_part) {
          case _TransferPart.header:
            _prefix();
          case _TransferPart.prefix:
            _part = _TransferPart.payload;
            _remaining = textBytes;
          case _TransferPart.ending:
            _rows++;
            if (_rows == expectedRows) {
              _part = _TransferPart.done;
            } else {
              _prefix();
            }
          case _TransferPart.payload:
          case _TransferPart.done:
            _reject();
        }
      }
    }
  }

  void finish() {
    if (_closed || _failed || _part != _TransferPart.done) _reject();
    _closed = true;
  }

  void _prefix() {
    _part = _TransferPart.prefix;
    _token = '"${_rows + 1}","';
    _tokenOffset = 0;
  }

  Never _reject() {
    _failed = true;
    throw StateError('Exported fixture bytes differ or are incomplete');
  }
}

enum _TransferPart { header, prefix, payload, ending, done }
