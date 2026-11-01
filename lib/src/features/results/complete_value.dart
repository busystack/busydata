import 'dart:convert';
import 'dart:typed_data';
import '../../backend/generated/busydata.pb.dart' as rpc;
import 'value_document.dart';

const completeValueByteLimit = 1048576;
const completeValueTextLimit = 262144;

class CompleteValueLimit implements Exception {
  const CompleteValueLimit();
}

class RetainedValueOwnerChanged implements Exception {
  const RetainedValueOwnerChanged();
}

bool completeValueEligible(rpc.Value value) =>
    value.truncated &&
    value.valueId.isNotEmpty &&
    value.originalBytes > 0 &&
    value.originalBytes <= completeValueByteLimit &&
    const {
      rpc.Value_Data.text,
      rpc.Value_Data.json,
      rpc.Value_Data.binary,
    }.contains(value.whichData());

/// Explicit bounded acquisition only. The caller verifies retained ownership on
/// each RPC and cancels its current transport when this operation is superseded.
Future<rpc.Value> readCompleteValue(
  rpc.Value original,
  Future<rpc.ValueChunk> Function(int offset) read,
  bool Function() current,
) async {
  if (!completeValueEligible(original)) {
    throw const CompleteValueLimit();
  }
  final pages = ValueDocument(original), bytes = BytesBuilder(copy: false);
  for (var count = 0; count < 32; count++) {
    if (!current()) throw const RetainedValueOwnerChanged();
    final offset = pages.nextOffset, reply = await read(pages.nextOffset);
    if (!current()) throw const RetainedValueOwnerChanged();
    pages.accept(reply, offset);
    if (pages.totalBytes > completeValueByteLimit ||
        bytes.length + reply.data.length > completeValueByteLimit) {
      throw const CompleteValueLimit();
    }
    bytes.add(reply.data);
    if (!pages.complete) continue;
    final complete = bytes.takeBytes();
    if (complete.length != original.originalBytes.toInt()) {
      throw StateError('VALUE_CHUNK_INVALID');
    }
    if (original.whichData() == rpc.Value_Data.binary) {
      if (original.binary.length > complete.length ||
          !original.binary.asMap().entries.every(
            (entry) => complete[entry.key] == entry.value,
          )) {
        throw StateError('VALUE_CHUNK_INVALID');
      }
      return rpc.Value(binary: complete);
    }
    final text = utf8.decode(complete, allowMalformed: false);
    if (text.length > completeValueTextLimit) {
      throw const CompleteValueLimit();
    }
    final prefix = original.whichData() == rpc.Value_Data.json
        ? original.json
        : original.text;
    if (!text.startsWith(prefix)) throw StateError('VALUE_CHUNK_INVALID');
    return original.whichData() == rpc.Value_Data.json
        ? rpc.Value(json: text)
        : rpc.Value(text: text);
  }
  throw StateError('VALUE_CHUNK_INVALID');
}

class BinaryDraftSnapshot {
  BinaryDraftSnapshot(
    List<int> bytes, {
    required this.offset,
    required this.input,
    required this.mode,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView() {
    if (bytes.length > completeValueByteLimit ||
        offset < 0 ||
        offset > bytes.length ||
        offset % BinaryValueDraft.pageByteLimit != 0 ||
        input.length > completeValueTextLimit) {
      throw StateError('VALUE_DRAFT_LIMIT');
    }
  }
  final Uint8List bytes;
  final int offset;
  final String input;
  final ValuePresentation mode;
  int get estimatedBytes => bytes.length + input.length * 2;
  BinaryDraftSnapshot._(
    this.bytes, {
    required this.offset,
    required this.input,
    required this.mode,
  });
}

/// One full bounded byte buffer, with one native-safe16KiB edit page.
class BinaryValueDraft {
  static const pageByteLimit = 16384;
  BinaryValueDraft(List<int> bytes) : _bytes = Uint8List.fromList(bytes) {
    if (bytes.length > completeValueByteLimit) {
      throw const CompleteValueLimit();
    }
  }
  Uint8List _bytes;
  int offset = 0;
  Uint8List get bytes => _bytes.asUnmodifiableView();
  Uint8List get pageBytes => Uint8List.sublistView(
    _bytes,
    offset,
    offset + pageLength,
  ).asUnmodifiableView();
  BinaryDraftSnapshot snapshot(String input, ValuePresentation mode) {
    if (input.length > completeValueTextLimit) {
      throw StateError('VALUE_DRAFT_LIMIT');
    }
    return BinaryDraftSnapshot._(
      _bytes.asUnmodifiableView(),
      offset: offset,
      input: input,
      mode: mode,
    );
  }

  int get pageLength => (_bytes.length - offset).clamp(0, pageByteLimit);
  bool get hasNext => offset + pageLength < _bytes.length;
  String encodedPage(ValuePresentation mode) {
    final page = Uint8List.sublistView(_bytes, offset, offset + pageLength);
    if (mode == ValuePresentation.base64) return base64Encode(page);
    final hex = page
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return mode == ValuePresentation.uuid && page.length == 16
        ? '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}'
        : hex;
  }

  ({List<int> page, int remaining, int length}) _edit(
    String input,
    ValuePresentation mode,
  ) {
    final page = editedValue(rpc.Value(binary: const []), input, mode).binary;
    final remaining = _bytes.length - offset - pageLength;
    if (page.length > pageByteLimit ||
        remaining > 0 && page.length != pageLength ||
        offset + page.length + remaining > completeValueByteLimit) {
      throw const FormatException('BINARY_PAGE_SIZE');
    }
    return (
      page: page,
      remaining: remaining,
      length: offset + page.length + remaining,
    );
  }

  void replacePage(String input, ValuePresentation mode) {
    final edit = _edit(input, mode);
    _apply(edit);
  }

  void _apply(({List<int> page, int remaining, int length}) edit) {
    final page = edit.page, remaining = edit.remaining;
    if (page.length == pageLength) {
      _bytes = Uint8List.fromList(_bytes)
        ..setRange(offset, offset + page.length, page);
      return;
    }
    final next = Uint8List(offset + page.length + remaining)
      ..setRange(0, offset, _bytes)
      ..setRange(offset, offset + page.length, page);
    if (remaining > 0) {
      next.setRange(
        offset + page.length,
        next.length,
        _bytes,
        offset + pageLength,
      );
    }
    _bytes = next;
  }

  bool canAppend(String input, ValuePresentation mode) {
    try {
      final edit = _edit(input, mode);
      return edit.length < completeValueByteLimit &&
          edit.length % pageByteLimit == 0 &&
          !(offset == edit.length && edit.page.isEmpty);
    } on FormatException {
      return false;
    }
  }

  /// Commit a valid page and expose an empty aligned window at the exact end.
  /// Navigation does not pad or add bytes. A partial last page must be filled
  /// before another page can be appended, preserving the recovery offset shape.
  void appendPage(String input, ValuePresentation mode) {
    final edit = _edit(input, mode);
    if (edit.length >= completeValueByteLimit) {
      throw const FormatException('BINARY_PAGE_SIZE');
    }
    if (edit.length % pageByteLimit != 0) {
      throw const FormatException('BINARY_PAGE_ALIGNMENT');
    }
    _apply(edit);
    offset = _bytes.length;
  }

  void move(int direction) {
    final target = offset + direction * pageByteLimit;
    if (direction.abs() != 1 || target < 0 || target >= _bytes.length) {
      throw StateError('BINARY_PAGE_UNAVAILABLE');
    }
    offset = target;
  }
}
