import 'dart:convert';
import 'dart:typed_data';
import '../../backend/generated/busydata.pb.dart' as rpc;

enum ValuePresentation {
  raw,
  json,
  tree,
  xml,
  hexadecimal,
  base64,
  uuid,
  image,
}

/// The inspector retains one byte page, never an entire unbounded LOB. SQL/JDBC
/// conversion remains in Java. User-selected binary interpretations are exact.
class ValueDocument {
  ValueDocument(this.original);
  final rpc.Value original;
  Uint8List? chunk;
  int offset = 0, totalBytes = 0;
  bool complete = false;
  static const chunkBytes = 65536;
  // Presentation windows bound native paragraph layout independently of the
  // retained byte chunk and the larger independently staged editing pages.
  static const nativeTextPageUnits = 8192;
  void accept(rpc.ValueChunk reply, int requestedOffset) {
    final total = reply.totalBytes.toInt();
    if ((chunk != null &&
            (requestedOffset != nextOffset ||
                total != totalBytes ||
                complete)) ||
        (original.originalBytes > 0 &&
            total != original.originalBytes.toInt()) ||
        reply.data.length > chunkBytes ||
        total < requestedOffset + reply.data.length ||
        (reply.complete && total != requestedOffset + reply.data.length) ||
        (reply.data.isEmpty && !reply.complete)) {
      throw StateError('VALUE_CHUNK_INVALID');
    }
    chunk = Uint8List.fromList(reply.data);
    offset = requestedOffset;
    totalBytes = total;
    complete = reply.complete;
  }

  int get nextOffset => chunk == null ? 0 : offset + chunk!.length;
  void reset() {
    chunk = null;
    offset = totalBytes = 0;
    complete = false;
  }
}

rpc.Value editedValue(
  rpc.Value original,
  String input,
  ValuePresentation mode,
) {
  if (input.length > 262144) throw const FormatException('VALUE_DRAFT_LIMIT');
  for (var index = 0; index < input.length; index++) {
    final unit = input.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++index >= input.length ||
          input.codeUnitAt(index) < 0xdc00 ||
          input.codeUnitAt(index) > 0xdfff) {
        throw const FormatException('VALUE_TEXT_ENCODING');
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw const FormatException('VALUE_TEXT_ENCODING');
    }
  }
  if (original.whichData() == rpc.Value_Data.binary) {
    if (mode == ValuePresentation.base64) {
      return rpc.Value(binary: base64.decode(input));
    }
    final hex = mode == ValuePresentation.uuid
        ? input.replaceAll('-', '')
        : input;
    if (hex.length.isOdd ||
        !RegExp(r'^[0-9a-fA-F]*$').hasMatch(hex) ||
        (mode == ValuePresentation.uuid && hex.length != 32)) {
      throw const FormatException('BINARY_INPUT_ERROR');
    }
    return rpc.Value(
      binary: [
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ],
    );
  }
  // Textual input is intentionally transported as text for Java's authoritative
  // column conversion, including exact decimals, temporals and native values.
  if (original.hasJson()) return rpc.Value(json: input);
  return rpc.Value(text: input);
}

({int width, int height})? recognizedImageSize(List<int> bytes) {
  if (bytes.isEmpty || bytes.length > 1048576) return null;
  int be(int at, int count) {
    var value = 0;
    for (var i = at; i < at + count; i++) {
      value = value * 256 + bytes[i];
    }
    return value;
  }

  int width = 0, height = 0;
  if (bytes.length >= 24 &&
      const [
        137,
        80,
        78,
        71,
        13,
        10,
        26,
        10,
      ].asMap().entries.every((e) => bytes[e.key] == e.value) &&
      be(8, 4) == 13 &&
      ascii.decode(bytes.sublist(12, 16)) == 'IHDR') {
    width = be(16, 4);
    height = be(20, 4);
  } else if (bytes.length >= 10 &&
      (ascii.decode(bytes.sublist(0, 6), allowInvalid: true) == 'GIF87a' ||
          ascii.decode(bytes.sublist(0, 6), allowInvalid: true) == 'GIF89a')) {
    width = bytes[6] + bytes[7] * 256;
    height = bytes[8] + bytes[9] * 256;
  } else if (bytes.length >= 4 && bytes[0] == 255 && bytes[1] == 216) {
    var position = 2;
    while (position + 3 < bytes.length) {
      if (bytes[position++] != 255) return null;
      while (position < bytes.length && bytes[position] == 255) {
        position++;
      }
      if (position >= bytes.length) return null;
      final marker = bytes[position++];
      if (marker == 217 || marker == 218) break;
      if (marker == 1 || marker >= 208 && marker <= 215) continue;
      if (position + 2 > bytes.length) return null;
      final size = be(position, 2);
      if (size < 2 || position + size > bytes.length) return null;
      if (const [
        192,
        193,
        194,
        195,
        197,
        198,
        199,
        201,
        202,
        203,
        205,
        206,
        207,
      ].contains(marker)) {
        if (size < 8) return null;
        height = be(position + 3, 2);
        width = be(position + 5, 2);
        break;
      }
      position += size;
    }
  }
  return width > 0 &&
          height > 0 &&
          width <= 4096 &&
          height <= 4096 &&
          width * height <= 4194304
      ? (width: width, height: height)
      : null;
}
