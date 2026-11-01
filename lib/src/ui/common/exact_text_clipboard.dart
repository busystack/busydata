import 'package:flutter/services.dart';
import 'result_extractors.dart' show ResultCopyBuffer, resultClipboardByteLimit;

enum TextClipboardUnavailableReason { embeddedNul, byteLimit }

final class TextClipboardUnavailable implements Exception {
  const TextClipboardUnavailable(this.reason);

  final TextClipboardUnavailableReason reason;

  @override
  String toString() => 'text_clipboard_unavailable.${reason.name}';
}

/// Admit an exact result-text payload before touching the native clipboard.
/// Both pinned desktop implementations use NUL-terminated text. A NUL cannot
/// round-trip through that contract, even when the Dart string retains it.
Future<void> writeExactTextClipboard(String text) async {
  if (text.length > resultClipboardByteLimit) {
    throw const TextClipboardUnavailable(
      TextClipboardUnavailableReason.byteLimit,
    );
  }
  if (text.contains('\u0000')) {
    throw const TextClipboardUnavailable(
      TextClipboardUnavailableReason.embeddedNul,
    );
  }
  try {
    ResultCopyBuffer().account(text);
  } on StateError {
    throw const TextClipboardUnavailable(
      TextClipboardUnavailableReason.byteLimit,
    );
  }
  await Clipboard.setData(ClipboardData(text: text));
}
