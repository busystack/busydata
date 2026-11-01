import 'package:flutter/widgets.dart';

/// Refuse an oversized edit before notifying renderers/listeners. Returning the
/// previous value preserves the user's text, selection and IME state; input is
/// never shortened into a different accepted value.
class BoundedTextController extends TextEditingController {
  BoundedTextController({
    super.text,
    required this.maxUnits,
    this.limit,
    this.maxUtf8Bytes,
    this.rejected,
  }) {
    if (maxUnits < 0 ||
        maxUtf8Bytes != null && maxUtf8Bytes! < 0 ||
        !_accepts(text)) {
      throw ArgumentError('TEXT_INPUT_LIMIT');
    }
  }
  final int maxUnits;
  final int Function()? limit;
  final int? maxUtf8Bytes;
  final VoidCallback? rejected;
  bool _accepts(String text) {
    final activeLimit = limit?.call() ?? maxUnits;
    if (text.length > maxUnits || text.length > activeLimit) return false;
    var bytes = 0;
    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      if (unit == 0) return false;
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index >= text.length) return false;
        final low = text.codeUnitAt(index);
        if (low < 0xdc00 || low > 0xdfff) return false;
        bytes += 4;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        return false;
      } else {
        bytes += unit < 128 ? 1 : (unit < 2048 ? 2 : 3);
      }
      if (maxUtf8Bytes != null && bytes > maxUtf8Bytes!) return false;
    }
    return true;
  }

  @override
  set value(TextEditingValue next) {
    if (!_accepts(next.text)) {
      rejected?.call();
      return;
    }
    super.value = next;
  }
}
