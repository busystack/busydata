import 'dart:ui' show TextAffinity;
import 'dart:collection';
import 'dart:typed_data';
import 'package:re_editor/re_editor.dart';

enum SqlEditorFailure {
  clipboardUnavailable,
  documentLimit,
  lineLimit,
  caretLimit,
  overlappingRanges,
  staleSelection,
  composing,
  reentrantMutation,
  foldedRegion,
  workLimit,
  rejectionOwnerLimit,
  clipboardBusy,
  clipboardLimit,
  clipboardNul,
  disposed,
  projectionMismatch,
}

class SqlEditorException implements Exception {
  const SqlEditorException(this.code);
  final SqlEditorFailure code;
  @override
  String toString() => 'SqlEditorException(${code.name})';
}

/// Exact source is stored in shared immutable chunks. Only the current source
/// materializes a flat String; undo retains its unchanged line objects and EOLs.
class SqlSource {
  factory SqlSource(String text) {
    if (text.length > maxUnits) {
      throw const SqlEditorException(SqlEditorFailure.documentLimit);
    }
    final chunks = <_SqlChunk>[], rows = <CodeLine>[], endings = <int>[];
    void add(String line, int ending) {
      rows.add(CodeLine(line));
      endings.add(ending);
      if (rows.length == 256) {
        chunks.add(_SqlChunk(rows, endings));
        rows.clear();
        endings.clear();
      }
    }

    var start = 0, count = 1;
    for (var index = 0; index < text.length; index++) {
      final unit = text.codeUnitAt(index);
      if (unit != 10 && unit != 13) continue;
      final crlf =
          unit == 13 &&
          index + 1 < text.length &&
          text.codeUnitAt(index + 1) == 10;
      add(
        text.substring(start, index),
        crlf
            ? 2
            : unit == 13
            ? 3
            : 1,
      );
      if (++count > maxLines) {
        throw const SqlEditorException(SqlEditorFailure.lineLimit);
      }
      start = index + (crlf ? 2 : 1);
      index = start - 1;
    }
    add(text.substring(start), 0);
    if (rows.isNotEmpty) chunks.add(_SqlChunk(rows, endings));
    return SqlSource._(chunks, text);
  }
  SqlSource._(List<_SqlChunk> chunks, [String? text])
    : _chunks = List.unmodifiable(chunks),
      _materialized = text {
    var units = 0, lines = 0;
    final lineStarts = <int>[], unitStarts = <int>[];
    for (final chunk in chunks) {
      lineStarts.add(lines);
      unitStarts.add(units);
      lines += chunk.rows.length;
      units += chunk.units;
    }
    if (units > maxUnits) {
      throw const SqlEditorException(SqlEditorFailure.documentLimit);
    }
    if (lines > maxLines) {
      throw const SqlEditorException(SqlEditorFailure.lineLimit);
    }
    _length = units;
    _lineCount = lines;
    _linePrefixes = List.unmodifiable(lineStarts);
    _unitPrefixes = List.unmodifiable(unitStarts);
  }
  static const maxUnits = 8000000, maxLines = 100000;
  final List<_SqlChunk> _chunks;
  late final List<int> _linePrefixes, _unitPrefixes;
  late final int _length, _lineCount;
  String? _materialized;
  bool _cacheText = true;
  late final CodeLines _projection = SqlSourceCodeLines._(
    List.unmodifiable(_chunks.map((chunk) => chunk.projection)),
  );
  String get text {
    final cached = _materialized;
    if (cached != null) return cached;
    if (_chunks.length == 1 &&
        _chunks.first.rows.length == 1 &&
        _chunks.first.endings.first == 0) {
      return _chunks.first.rows.first.text;
    }
    final out = StringBuffer();
    for (final chunk in _chunks) {
      for (var row = 0; row < chunk.rows.length; row++) {
        out.write(chunk.rows[row].text);
        out.write(_ending(chunk.endings[row]));
      }
    }
    final result = out.toString();
    if (_cacheText) _materialized = result;
    return result;
  }

  void dropMaterialization() {
    _materialized = null;
    _cacheText = false;
  }

  void activateMaterialization() {
    _cacheText = true;
  }

  int get length => _length;
  int get lineCount => _lineCount;
  List<String> get lines => _SourceStrings(this, false);
  List<String> get endings => _SourceStrings(this, true);
  List<int> get starts => _SourceStarts(this);
  String get preferredEnding {
    for (final chunk in _chunks) {
      for (final code in chunk.endings) {
        if (code != 0) return _ending(code);
      }
    }
    return '\n';
  }

  CodeLines get codeLines => _projection;
  static String _ending(int code) => const ['', '\n', '\r\n', '\r'][code];
  (int, int) _row(int index) {
    if (index < 0 || index >= lineCount) {
      throw const SqlEditorException(SqlEditorFailure.staleSelection);
    }
    var low = 0, high = _linePrefixes.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (_linePrefixes[middle] <= index) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    return (high, index - _linePrefixes[high]);
  }

  int _start(int index) {
    final location = _row(index);
    var offset = _unitPrefixes[location.$1];
    final chunk = _chunks[location.$1];
    for (var row = 0; row < location.$2; row++) {
      offset += chunk.rows[row].length + _ending(chunk.endings[row]).length;
    }
    return offset;
  }

  (int chunk, int row, int within, int line) _at(int offset) {
    if (offset < 0 || offset > length) {
      throw const SqlEditorException(SqlEditorFailure.staleSelection);
    }
    var low = 0, high = _unitPrefixes.length - 1;
    while (low <= high) {
      final middle = (low + high) >> 1;
      if (_unitPrefixes[middle] <= offset) {
        low = middle + 1;
      } else {
        high = middle - 1;
      }
    }
    final index = high < 0 ? 0 : high, chunk = _chunks[index];
    var position = _unitPrefixes[index];
    for (var row = 0; row < chunk.rows.length; row++) {
      final size = chunk.rows[row].length,
          ending = _ending(chunk.endings[row]).length;
      if (offset <= position + size ||
          offset < position + size + ending ||
          row == chunk.rows.length - 1 && index == _chunks.length - 1) {
        return (index, row, offset - position, _linePrefixes[index] + row);
      }
      position += size + ending;
    }
    throw const SqlEditorException(SqlEditorFailure.staleSelection);
  }

  int offsetForPosition(CodeLinePosition position) {
    if (position is SqlSourcePosition) {
      if (!identical(position.source, this) ||
          position.absoluteOffset < 0 ||
          position.absoluteOffset > length) {
        throw const SqlEditorException(SqlEditorFailure.staleSelection);
      }
      return position.absoluteOffset;
    }
    final location = _row(position.index),
        line = _chunks[location.$1].rows[location.$2];
    if (position.offset < 0 || position.offset > line.length) {
      throw const SqlEditorException(SqlEditorFailure.staleSelection);
    }
    return _start(position.index) + position.offset;
  }

  CodeLinePosition positionForOffset(int offset) {
    final at = _at(offset), line = _chunks[at.$1].rows[at.$2];
    return SqlSourcePosition(
      source: this,
      absoluteOffset: offset,
      projection: CodeLinePosition(
        index: at.$4,
        offset: at.$3 > line.length ? line.length : at.$3,
      ),
    );
  }

  bool contentEquals(SqlSource other) {
    if (identical(this, other)) return true;
    if (length != other.length || lineCount != other.lineCount) return false;
    if (_chunks.length == other._chunks.length &&
        List.generate(
          _chunks.length,
          (index) => identical(_chunks[index], other._chunks[index]),
        ).every((same) => same)) {
      return true;
    }
    if (_chunks.length == other._chunks.length &&
        List.generate(
          _chunks.length,
          (index) =>
              _chunks[index].rows.length == other._chunks[index].rows.length,
        ).every((same) => same)) {
      for (var index = 0; index < _chunks.length; index++) {
        final a = _chunks[index], b = other._chunks[index];
        if (identical(a, b)) continue;
        for (var row = 0; row < a.rows.length; row++) {
          if (a.rows[row].text != b.rows[row].text ||
              a.endings[row] != b.endings[row]) {
            return false;
          }
        }
      }
      return true;
    }
    final aLines = lines,
        bLines = other.lines,
        aEndings = endings,
        bEndings = other.endings;
    for (var index = 0; index < lineCount; index++) {
      if (aLines[index] != bLines[index] ||
          aEndings[index] != bEndings[index]) {
        return false;
      }
    }
    return true;
  }

  SqlSource replace(int start, int end, String replacement) {
    if (start < 0 || end < start || end > length) {
      throw const SqlEditorException(SqlEditorFailure.staleSelection);
    }
    if (length - (end - start) + replacement.length > maxUnits) {
      throw const SqlEditorException(SqlEditorFailure.documentLimit);
    }
    if (start == end && replacement.isEmpty) return this;
    final a = _at(start),
        b = _at(end),
        first = _chunks[a.$1],
        last = _chunks[b.$1];
    if (a.$4 == b.$4 &&
        a.$3 == 0 &&
        b.$3 == first.rows[a.$2].length &&
        first.rows[a.$2].text == replacement) {
      return this;
    }
    final left = first.rows[a.$2].text + _ending(first.endings[a.$2]),
        right = last.rows[b.$2].text + _ending(last.endings[b.$2]);
    final fragment = SqlSource(
      left.substring(0, a.$3) + replacement + right.substring(b.$3),
    );
    final chunks = <_SqlChunk>[];
    void append(_SqlChunk chunk) {
      if (chunk.rows.isEmpty) return;
      if (chunks.isNotEmpty &&
          chunks.last.rows.length + chunk.rows.length <= 256) {
        final previous = chunks.removeLast();
        chunks.add(
          _SqlChunk(
            [...previous.rows, ...chunk.rows],
            [...previous.endings, ...chunk.endings],
          ),
        );
      } else {
        chunks.add(chunk);
      }
    }

    for (var index = 0; index < a.$1; index++) {
      append(_chunks[index]);
    }
    if (a.$2 > 0) append(first.slice(0, a.$2));
    for (var index = 0; index < fragment._chunks.length; index++) {
      var chunk = fragment._chunks[index];
      if (index == fragment._chunks.length - 1 &&
          b.$4 < lineCount - 1 &&
          chunk.rows.last.text.isEmpty &&
          chunk.endings.last == 0) {
        chunk = chunk.slice(0, chunk.rows.length - 1);
      }
      append(chunk);
    }
    if (b.$2 + 1 < last.rows.length) {
      append(last.slice(b.$2 + 1, last.rows.length));
    }
    for (var index = b.$1 + 1; index < _chunks.length; index++) {
      append(_chunks[index]);
    }
    if (chunks.isEmpty) chunks.add(_SqlChunk([CodeLine.empty], [0]));
    return SqlSource._(chunks);
  }

  SqlSource rewriteProjection(CodeLines projection, {String? newLineEnding}) {
    final after = projection.asString(TextLineBreak.lf),
        before = lines.join('\n');
    if (before == after) return this;
    var prefix = 0;
    while (prefix < before.length &&
        prefix < after.length &&
        before.codeUnitAt(prefix) == after.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < before.length - prefix &&
        suffix < after.length - prefix &&
        before.codeUnitAt(before.length - suffix - 1) ==
            after.codeUnitAt(after.length - suffix - 1)) {
      suffix++;
    }
    int originalOffset(int normalized) {
      var consumed = 0;
      for (var index = 0; index < lineCount; index++) {
        if (normalized <= consumed + lines[index].length) {
          return _start(index) + normalized - consumed;
        }
        consumed += lines[index].length + 1;
      }
      return length;
    }

    final oldEnd = before.length - suffix, oldBreaks = <String>[];
    var consumed = 0;
    for (var index = 0; index < lineCount - 1; index++) {
      consumed += lines[index].length;
      if (consumed >= prefix && consumed < oldEnd) {
        oldBreaks.add(endings[index]);
      }
      consumed++;
    }
    var at = 0;
    final insertion = after
        .substring(prefix, after.length - suffix)
        .replaceAllMapped(
          RegExp('\n'),
          (_) => at < oldBreaks.length
              ? oldBreaks[at++]
              : newLineEnding ?? preferredEnding,
        );
    return replace(originalOffset(prefix), originalOffset(oldEnd), insertion);
  }

  /// Conservatively charge one retained logical text per historical generation.
  /// Its actual line objects remain shared; no historical flat String is cached.
  int get retainedUnits => length;
  int get chunkCount => _chunks.length;
  int get materializedUnits => _materialized?.length ?? 0;
}

class _SqlChunk {
  factory _SqlChunk(List<CodeLine> rows, Iterable<int> endings) {
    final frozen = List<CodeLine>.unmodifiable(rows),
        codes = Uint8List.fromList(endings.toList(growable: false));
    var units = 0;
    for (var index = 0; index < frozen.length; index++) {
      units += frozen[index].length + SqlSource._ending(codes[index]).length;
    }
    return _SqlChunk._(
      frozen,
      codes,
      CodeLineSegment(codeLines: frozen, dirty: true),
      units,
    );
  }
  const _SqlChunk._(this.rows, this.endings, this.projection, this.units);
  final List<CodeLine> rows;
  final Uint8List endings;
  final CodeLineSegment projection;
  final int units;
  _SqlChunk slice(int start, int end) => start == 0 && end == rows.length
      ? this
      : _SqlChunk(rows.sublist(start, end), endings.sublist(start, end));
}

class SqlSourceCodeLines extends CodeLines {
  const SqlSourceCodeLines._(super.segments);
}

class _SourceStrings extends ListBase<String> {
  _SourceStrings(this.source, this.ending);
  final SqlSource source;
  final bool ending;
  @override
  int get length => source.lineCount;
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  String operator [](int index) {
    final at = source._row(index), chunk = source._chunks[at.$1];
    return ending
        ? SqlSource._ending(chunk.endings[at.$2])
        : chunk.rows[at.$2].text;
  }

  @override
  void operator []=(int index, String value) =>
      throw UnsupportedError('immutable');
}

class _SourceStarts extends ListBase<int> {
  _SourceStarts(this.source);
  final SqlSource source;
  @override
  int get length => source.lineCount;
  @override
  set length(int value) => throw UnsupportedError('immutable');
  @override
  int operator [](int index) => source._start(index);
  @override
  void operator []=(int index, int value) =>
      throw UnsupportedError('immutable');
}

/// Native layout uses [index]/[offset]; source ownership retains an exact point
/// even between the CR and LF code units of one displayed line separator.
class SqlSourcePosition extends CodeLinePosition {
  SqlSourcePosition({
    required this.source,
    required this.absoluteOffset,
    required CodeLinePosition projection,
  }) : super(
         index: projection.index,
         offset: projection.offset,
         affinity: projection.affinity,
       );
  final SqlSource source;
  final int absoluteOffset;
}

class SqlSourceSelection extends CodeLineSelection {
  SqlSourceSelection({
    required this.source,
    required CodeLinePosition base,
    required CodeLinePosition extent,
  }) : _base = base,
       _extent = extent,
       super(
         baseIndex: base.index,
         baseOffset: base.offset,
         baseAffinity: base.affinity,
         extentIndex: extent.index,
         extentOffset: extent.offset,
         extentAffinity: extent.affinity,
       );
  final SqlSource source;
  final CodeLinePosition _base, _extent;
  @override
  CodeLinePosition get base => _base;
  @override
  CodeLinePosition get extent => _extent;
  int get absoluteBase => source.offsetForPosition(_base);
  int get absoluteExtent => source.offsetForPosition(_extent);
  @override
  CodeLinePosition get start => absoluteBase <= absoluteExtent ? base : extent;
  @override
  CodeLinePosition get end => absoluteBase <= absoluteExtent ? extent : base;
  @override
  bool get isCollapsed => absoluteBase == absoluteExtent;
  @override
  CodeLineSelection copyWith({
    int? baseIndex,
    int? extentIndex,
    int? baseOffset,
    int? extentOffset,
    TextAffinity? baseAffinity,
    TextAffinity? extentAffinity,
  }) {
    if (baseIndex == null &&
        extentIndex == null &&
        baseOffset == null &&
        extentOffset == null &&
        baseAffinity == null &&
        extentAffinity == null) {
      return this;
    }
    return super.copyWith(
      baseIndex: baseIndex,
      extentIndex: extentIndex,
      baseOffset: baseOffset,
      extentOffset: extentOffset,
      baseAffinity: baseAffinity,
      extentAffinity: extentAffinity,
    );
  }
}
