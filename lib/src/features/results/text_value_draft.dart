import 'complete_value.dart'
    show completeValueByteLimit, completeValueTextLimit;

const textValuePageUnits = 16384;

/// Exclusive end of one presentation page, without splitting a surrogate pair.
/// This helper does not impose the smaller editable-value admission limit.
int textValuePageEnd(
  String text,
  int start, {
  int maxUnits = textValuePageUnits,
}) {
  if (start < 0 || start > text.length || maxUnits < 2) {
    throw ArgumentError('TEXT_PAGE_RANGE');
  }
  if (start > 0 &&
      start < text.length &&
      _low(text.codeUnitAt(start)) &&
      _high(text.codeUnitAt(start - 1))) {
    throw ArgumentError('TEXT_PAGE_RANGE');
  }
  var end = (start + maxUnits).clamp(start, text.length);
  if (end < text.length &&
      _high(text.codeUnitAt(end - 1)) &&
      _low(text.codeUnitAt(end))) {
    end--;
  }
  return end;
}

bool _high(int unit) => unit >= 0xd800 && unit <= 0xdbff;
bool _low(int unit) => unit >= 0xdc00 && unit <= 0xdfff;

int _utf8Bytes(String text) {
  var bytes = 0;
  for (var index = 0; index < text.length; index++) {
    final unit = text.codeUnitAt(index);
    if (_high(unit)) {
      if (++index >= text.length || !_low(text.codeUnitAt(index))) {
        throw const FormatException('VALUE_TEXT_ENCODING');
      }
      bytes += 4;
    } else if (_low(unit)) {
      throw const FormatException('VALUE_TEXT_ENCODING');
    } else {
      bytes += unit < 128 ? 1 : (unit < 2048 ? 2 : 3);
    }
  }
  return bytes;
}

/// One exact bounded value with stable, independently editable page identities.
/// Emptying or resizing a page does not absorb its untouched neighbours. An
/// explicit append may repack a fragmented index; ordinary edits never do.
/// Only the active page is passed to a native control; recovery stays a String.
class TextValueDraft {
  TextValueDraft(String text) : _text = text {
    if (text.length > completeValueTextLimit) {
      throw const FormatException('VALUE_DRAFT_LIMIT');
    }
    _bytes = _utf8Bytes(text);
    if (_bytes > completeValueByteLimit) {
      throw const FormatException('VALUE_DRAFT_LIMIT');
    }
    _repage();
  }

  static const pageUnits = textValuePageUnits;
  // At most seventeen populated surrogate-safe pages plus a vacant append page.
  static const maxPages = 18;
  String _text;
  late int _bytes;
  final _bounds = <int>[];
  int _index = 0;

  String get fullText => _text;
  String get text => _text;
  int get pageIndex => _index;
  int get pageCount => _bounds.length - 1;
  int get pageStart => _bounds[_index];
  int get pageEnd => _bounds[_index + 1];
  String get pageText => _text.substring(pageStart, pageEnd);
  bool get hasPrevious => _index > 0;
  bool get hasNext => _index + 1 < pageCount;
  bool get canAppendPage => canAppend(pageText);
  int get estimatedBytes => 64 + _text.length * 2 + _bounds.length * 8;

  void _repage() {
    _bounds
      ..clear()
      ..add(0);
    while (_bounds.last < _text.length) {
      _bounds.add(textValuePageEnd(_text, _bounds.last));
    }
    if (_bounds.length == 1) _bounds.add(0);
  }

  ({String text, int bytes, int delta}) _project(String input) {
    if (input.length > pageUnits ||
        _text.length - (pageEnd - pageStart) + input.length >
            completeValueTextLimit) {
      throw const FormatException('VALUE_DRAFT_LIMIT');
    }
    final bytes = _bytes - _utf8Bytes(pageText) + _utf8Bytes(input);
    if (bytes > completeValueByteLimit) {
      throw const FormatException('VALUE_DRAFT_LIMIT');
    }
    return (
      text: input == pageText
          ? _text
          : '${_text.substring(0, pageStart)}$input${_text.substring(pageEnd)}',
      bytes: bytes,
      delta: input.length - (pageEnd - pageStart),
    );
  }

  /// Validate a pending page and return the exact full draft without committing.
  String projected(String input) => _project(input).text;
  String fullWithPage(String input) => projected(input);

  void replacePage(String input) {
    final next = _project(input);
    _text = next.text;
    _bytes = next.bytes;
    for (var index = _index + 1; index < _bounds.length; index++) {
      _bounds[index] += next.delta;
    }
  }

  /// Invalid input or navigation leaves both the draft and active page intact.
  void move(int direction, String currentInput) {
    if (direction.abs() != 1 ||
        _index + direction < 0 ||
        _index + direction >= pageCount) {
      throw StateError('TEXT_PAGE_UNAVAILABLE');
    }
    replacePage(currentInput);
    _index += direction;
  }

  bool canAppend(String currentInput) {
    try {
      final next = _project(currentInput);
      final finalPageLength =
          _bounds.last -
          _bounds[_bounds.length - 2] +
          (_index == pageCount - 1 ? next.delta : 0);
      if (finalPageLength == 0) return _index != pageCount - 1;
      return next.text.length < completeValueTextLimit;
    } on FormatException {
      return false;
    }
  }

  /// An explicit append action grows a small initial value without exposing a
  /// larger native input buffer. A vacant last page is reused instead of added.
  /// Fragmented short pages are repacked only here, so presentation cannot lower
  /// the whole-value capacity or grow an unbounded page index.
  void appendPage(String currentInput) {
    final next = _project(currentInput);
    final finalPageLength =
        _bounds.last -
        _bounds[_bounds.length - 2] +
        (_index == pageCount - 1 ? next.delta : 0);
    if (finalPageLength != 0 && next.text.length >= completeValueTextLimit) {
      throw const FormatException('VALUE_DRAFT_LIMIT');
    }
    replacePage(currentInput);
    if (finalPageLength != 0) {
      if (pageCount >= maxPages) _repage();
      _bounds.add(_text.length);
    }
    _index = pageCount - 1;
  }
}
