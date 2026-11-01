import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'sql_source.dart';

class SqlEditorValue extends CodeLineEditingValue {
  SqlEditorValue({
    required this.source,
    CodeLines? codeLines,
    super.selection = const CodeLineSelection.zero(),
    super.composing = TextRange.empty,
    List<CodeLineSelection> secondarySelections = const [],
    this.revision = 0,
  }) : secondarySelections = List.unmodifiable(secondarySelections),
       super(codeLines: _freeze(codeLines ?? source.codeLines));
  factory SqlEditorValue.fromText(String text) =>
      SqlEditorValue(source: SqlSource(text));
  final SqlSource source;
  final List<CodeLineSelection> secondarySelections;
  final int revision;
  @override
  SqlEditorValue copyWith({
    CodeLines? codeLines,
    CodeLineSelection? selection,
    TextRange? composing,
    List<CodeLineSelection>? secondarySelections,
    SqlSource? source,
    int? revision,
  }) => SqlEditorValue(
    source:
        source ??
        (codeLines == null || identical(codeLines, this.codeLines)
            ? this.source
            : this.source.rewriteProjection(codeLines)),
    codeLines:
        codeLines ??
        (source == null || identical(source, this.source)
            ? this.codeLines
            : source.codeLines),
    selection: selection ?? this.selection,
    composing: composing ?? this.composing,
    secondarySelections: secondarySelections ?? this.secondarySelections,
    revision: revision ?? this.revision,
  );
  SqlEditorValue withSource(
    String text, {
    CodeLineSelection? selection,
    List<CodeLineSelection>? secondarySelections,
    TextRange? composing,
  }) => SqlEditorValue(
    source: SqlSource(text),
    selection: selection ?? this.selection,
    secondarySelections: secondarySelections ?? this.secondarySelections,
    composing: composing ?? this.composing,
    revision: revision,
  );
  bool sameContent(SqlEditorValue other) =>
      source.contentEquals(other.source) &&
      (identical(codeLines, other.codeLines) ||
          codeLines.equals(other.codeLines)) &&
      _sameSelection(selection, other.selection) &&
      composing == other.composing &&
      secondarySelections.length == other.secondarySelections.length &&
      List.generate(
        secondarySelections.length,
        (index) => _sameSelection(
          secondarySelections[index],
          other.secondarySelections[index],
        ),
      ).every((same) => same);
  @override
  bool get isInitial =>
      source.text.isEmpty &&
      selection.isCollapsed &&
      selection.baseIndex == 0 &&
      selection.baseOffset == 0;
  static bool _sameSelection(CodeLineSelection a, CodeLineSelection b) {
    if (a != b) return false;
    if (a is SqlSourceSelection || b is SqlSourceSelection) {
      final aBase = a is SqlSourceSelection ? a.absoluteBase : null,
          bBase = b is SqlSourceSelection ? b.absoluteBase : null;
      final aExtent = a is SqlSourceSelection ? a.absoluteExtent : null,
          bExtent = b is SqlSourceSelection ? b.absoluteExtent : null;
      return aBase == bBase && aExtent == bExtent;
    }
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is SqlEditorValue &&
      revision == other.revision &&
      sameContent(other);
  @override
  int get hashCode => Object.hash(
    source.text,
    _selectionHash(selection),
    composing,
    Object.hashAll(secondarySelections.map(_selectionHash)),
    revision,
  );
  static int _selectionHash(CodeLineSelection range) => Object.hash(
    range.baseIndex,
    range.baseOffset,
    range.baseAffinity,
    range.extentIndex,
    range.extentOffset,
    range.extentAffinity,
    range is SqlSourceSelection ? range.absoluteBase : null,
    range is SqlSourceSelection ? range.absoluteExtent : null,
  );
}

CodeLines _freeze(CodeLines value) {
  if (value is _SqlCodeLines || value is SqlSourceCodeLines) return value;
  CodeLine line(CodeLine value) =>
      CodeLine(value.text, List.unmodifiable(value.chunks.map(line)));
  return _SqlCodeLines(
    List.unmodifiable(
      value.segments.map(
        (segment) => CodeLineSegment(
          codeLines: List.unmodifiable(segment.codeLines.map(line)),
          dirty: true,
        ),
      ),
    ),
  );
}

class _SqlCodeLines extends CodeLines {
  const _SqlCodeLines(super.segments);
}

/// Signed UTF-16 endpoints relative to the end of a verified native replacement.
/// Flutter's TextRange describes nonnegative document offsets and cannot model
/// these deltas. Null at the native-edit boundary means no composing region.
class SqlNativeComposingRange {
  const SqlNativeComposingRange({required this.start, required this.end});
  final int start, end;
  bool get isCollapsed => start == end;
}
