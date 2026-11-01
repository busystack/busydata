import 'dart:typed_data';
import 'complete_value.dart' show completeValueByteLimit;

const _hexadecimalDigits = '0123456789abcdef';

class HexDisplayLimit extends FormatException {
  const HexDisplayLimit() : super('VALUE_DISPLAY_LIMIT');
}

/// Exact lowercase display for one bounded value, chunk, or edit page.
///
/// The complete-value limit also admits the smaller retained chunks and binary
/// edit pages. Validate ordinary integer lists instead of silently narrowing
/// their contents to bytes.
String encodeHexDisplay(List<int> bytes) {
  final length = bytes.length;
  if (length > completeValueByteLimit) {
    throw const HexDisplayLimit();
  }
  final encoded = Uint8List(length * 2);
  for (var index = 0; index < length; index++) {
    final byte = bytes[index];
    if (byte < 0 || byte > 255) {
      throw const FormatException('VALUE_BYTE_INVALID');
    }
    encoded[index * 2] = _hexadecimalDigits.codeUnitAt(byte >> 4);
    encoded[index * 2 + 1] = _hexadecimalDigits.codeUnitAt(byte & 15);
  }
  return String.fromCharCodes(encoded);
}
