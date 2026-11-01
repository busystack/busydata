import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'sql_editor_value.dart';
import 'sql_source.dart';

class _Edit {
  const _Edit(this.start, this.end, this.owner);
  final int start, end, owner;
}

class _History {
  _History(this.value) : tick = ++SqlEditorController._clock;
  final SqlEditorValue value;
  final int tick;
  int get units =>
      value.source.length +
      value.source.lineCount * 64 +
      value.secondarySelections.length * 64 +
      128;
}

/// BusyData owns source, editing transactions, admission and history. Official
/// re_editor controllers are unmodified public command/geometry helpers only.
class SqlEditorController extends ChangeNotifier
    implements CodeLineEditingController {
  SqlEditorController({
    String text = '',
    CodeLines? codeLines,
    this.options = const CodeLineOptions(),
    this.spanBuilder,
  }) : _value = SqlEditorValue(
         source: SqlSource(
           text.isEmpty && codeLines != null
               ? codeLines.asString(options.lineBreak)
               : text,
         ),
         codeLines: codeLines,
       ),
       _scratch = CodeLineEditingController(options: options),
       _navigation = CodeLineEditingController(options: options) {
    _owners.add(this);
    _syncNavigation();
  }
  factory SqlEditorController.fromText(
    String? text, [
    CodeLineOptions options = const CodeLineOptions(),
  ]) => SqlEditorController(text: text ?? '', options: options);
  factory SqlEditorController.fromTextAsync(
    String? text, [
    CodeLineOptions options = const CodeLineOptions(),
  ]) {
    final controller = SqlEditorController(options: options);
    if (text != null) controller.textAsync = text;
    return controller;
  }
  @override
  final CodeLineOptions options;
  final CodeLineSpanBuilder? spanBuilder;
  final CodeLineEditingController _scratch, _navigation;
  SqlEditorValue _value;
  SqlEditorValue? _preValue, _staged, _compositionBase;
  SqlSource? _pendingSource;
  bool _sourceScheduled = false, _clipboardBusy = false;
  int _pendingSourceGeneration = 0, _clipboardUnits = 0;
  final _undo = <_History>[], _redo = <_History>[];
  static final _owners = <SqlEditorController>{};
  static int _clock = 0;
  static const _maxHistoryUnits = 16 * 1024 * 1024,
      _maxClipboardBytes = 1048576;
  bool _disposed = false,
      _restoring = false,
      _notifying = false,
      _admitting = false,
      _disposePending = false;
  int _depth = 0, _generation = 0, _guardDepth = 0;
  bool _transactionFailed = false, _stagedCommitComposition = false;
  final _reported = Set<Object>.identity();
  final _rejectionHandlers = Map<Object, bool Function(Object)>.identity();
  void Function(bool down, bool extend)? pageNavigation;
  bool historyLimited = false;
  void Function(CodeLineEditingValue)? beforeChange;
  bool Function(Object)? onChangeRejected;

  /// The workspace atomically admits live text and these auxiliary units.
  void Function(SqlEditorValue next, int auxiliaryUnits)? admitChange;
  Future<String?> Function()? readClipboard;
  Future<void> Function(String text)? writeClipboard;

  /// Live/pending workspace text and independently capped Undo history have
  /// different owners. Restoring an Undo still admits its resulting live text.
  int get chargedUnits => _auxiliary(value, _compositionBase);
  int _auxiliary(SqlEditorValue live, SqlEditorValue? composition) {
    var units =
        _clipboardUnits +
        (_pendingSource == null ? 0 : _pendingSource!.length * 2);
    if (composition != null && !identical(composition.source, live.source)) {
      units += composition.source.retainedUnits;
    }
    return units;
  }

  void addRejectionHandler(Object owner, bool Function(Object) handler) {
    if (_disposed) throw const SqlEditorException(SqlEditorFailure.disposed);
    if (_rejectionHandlers.length >= 8 &&
        !_rejectionHandlers.containsKey(owner)) {
      throw const SqlEditorException(SqlEditorFailure.rejectionOwnerLimit);
    }
    _rejectionHandlers[owner] = handler;
  }

  void removeRejectionHandler(Object owner) => _rejectionHandlers.remove(owner);
  bool _handleRejection(Object error) {
    if (onChangeRejected?.call(error) == true) return true;
    for (final handler in _rejectionHandlers.values.toList(growable: false)) {
      if (handler(error)) return true;
    }
    return false;
  }

  void _guard(VoidCallback action) {
    if (_disposed) throw const SqlEditorException(SqlEditorFailure.disposed);
    if (_notifying || _admitting) {
      throw const SqlEditorException(SqlEditorFailure.reentrantMutation);
    }
    _guardDepth++;
    try {
      action();
    } catch (error) {
      if (_depth > 0) _transactionFailed = true;
      if (_reported.add(error) && _handleRejection(error)) return;
      rethrow;
    } finally {
      if (--_guardDepth == 0) _reported.clear();
    }
  }

  @override
  SqlEditorValue get value => _staged ?? _value;
  @override
  set value(CodeLineEditingValue next) => _guard(() {
    final candidate = next is SqlEditorValue
        ? next
        : value.copyWith(
            codeLines: next.codeLines,
            selection: next.selection,
            composing: next.composing,
          );
    _accept(candidate);
  });
  void _accept(SqlEditorValue candidate, {bool commitComposition = false}) {
    _validate(candidate);
    if (value.sameContent(candidate)) return;
    if (_depth > 0) {
      _staged = candidate;
      _stagedCommitComposition = _stagedCommitComposition || commitComposition;
      return;
    }
    _publish(candidate, commitComposition: commitComposition);
  }

  bool _publish(
    SqlEditorValue candidate, {
    bool record = true,
    List<_History>? undoPlan,
    List<_History>? redoPlan,
    bool resetComposition = false,
    bool commitComposition = false,
  }) {
    final previous = _value;
    candidate = candidate.copyWith(revision: previous.revision + 1);
    final undo = List<_History>.of(undoPlan ?? _undo),
        redo = List<_History>.of(redoPlan ?? _redo);
    var composition = resetComposition ? null : _compositionBase;
    final changed = !previous.source.contentEquals(candidate.source);
    if (record && !_restoring) {
      if (commitComposition && changed && composition != null) {
        if (!composition.source.contentEquals(previous.source)) {
          undo.add(_History(composition.copyWith(composing: TextRange.empty)));
        }
        composition = null;
      }
      if (candidate.composing.isValid && !candidate.composing.isCollapsed) {
        composition ??= previous;
      } else if (composition != null) {
        if (!composition.source.contentEquals(candidate.source)) {
          undo.add(_History(composition));
          redo.clear();
        }
        composition = null;
      } else if (changed) {
        undo.add(_History(previous));
        redo.clear();
      }
    }
    while (undo.fold<int>(0, (sum, entry) => sum + entry.units) +
            redo.fold<int>(0, (sum, entry) => sum + entry.units) >
        _maxHistoryUnits) {
      historyLimited = true;
      if (undo.isNotEmpty &&
          (redo.isEmpty || undo.first.tick < redo.first.tick)) {
        undo.removeAt(0);
      } else if (redo.isNotEmpty) {
        redo.removeAt(0);
      } else {
        break;
      }
    }
    _admitting = true;
    try {
      beforeChange?.call(candidate);
      admitChange?.call(candidate, _auxiliary(candidate, composition));
    } finally {
      _admitting = false;
    }
    if (_disposed) throw const SqlEditorException(SqlEditorFailure.disposed);
    _value = candidate;
    _compositionBase = composition;
    _undo
      ..clear()
      ..addAll(undo);
    _redo
      ..clear()
      ..addAll(redo);
    _generation++;
    candidate.source.activateMaterialization();
    _syncNavigation();
    _trimGlobal();
    _announce(previous);
    return true;
  }

  /// The previous value is borrowed only during this synchronous notification.
  /// Stable historical states belong to the bounded first-party undo owner.
  @override
  void notifyListeners() {
    if (_disposed) return;
    _announce(_value);
  }

  void _announce(SqlEditorValue previous) {
    if (_notifying) {
      throw const SqlEditorException(SqlEditorFailure.reentrantMutation);
    }
    _preValue = previous;
    _notifying = true;
    try {
      super.notifyListeners();
    } finally {
      _preValue = null;
      _notifying = false;
      if (!identical(previous.source, _value.source)) {
        previous.source.dropMaterialization();
      }
      if (_disposePending) {
        _finishDispose();
        super.dispose();
      }
    }
  }

  static void _trimGlobal() {
    int units() => _owners.fold(
      0,
      (sum, owner) =>
          sum +
          owner._undo.fold<int>(0, (sum, entry) => sum + entry.units) +
          owner._redo.fold<int>(0, (sum, entry) => sum + entry.units),
    );
    while (units() > _maxHistoryUnits) {
      SqlEditorController? owner;
      _History? oldest;
      bool redo = false;
      for (final candidate in _owners) {
        for (final entries in [candidate._undo, candidate._redo]) {
          if (entries.isNotEmpty &&
              (oldest == null || entries.first.tick < oldest.tick)) {
            owner = candidate;
            oldest = entries.first;
            redo = identical(entries, candidate._redo);
          }
        }
      }
      if (owner == null) break;
      (redo ? owner._redo : owner._undo).removeAt(0);
      owner.historyLimited = true;
    }
  }

  void _validate(SqlEditorValue next) {
    if (next.secondarySelections.length >= 64) {
      throw const SqlEditorException(SqlEditorFailure.caretLimit);
    }
    if (next.source.length > SqlSource.maxUnits ||
        next.source.lineCount > SqlSource.maxLines) {
      throw const SqlEditorException(SqlEditorFailure.documentLimit);
    }
    if (!(identical(next.codeLines, value.codeLines) &&
            identical(next.source, value.source)) &&
        next.codeLines.asString(TextLineBreak.lf) !=
            next.source.lines.join('\n')) {
      throw const SqlEditorException(SqlEditorFailure.projectionMismatch);
    }
    for (final selection in [next.selection, ...next.secondarySelections]) {
      _offset(selection.base, next);
      _offset(selection.extent, next);
    }
  }

  int _offset(CodeLinePosition position, SqlEditorValue next) {
    if (position.index < 0 ||
        position.index >= next.codeLines.length ||
        position.offset < 0 ||
        position.offset > next.codeLines[position.index].length) {
      throw const SqlEditorException(SqlEditorFailure.staleSelection);
    }
    if (position is SqlSourcePosition) {
      final absolute = next.source.offsetForPosition(position),
          logical = next.source.positionForOffset(absolute);
      final visible = next.codeLines.lineIndex2Index(logical.index);
      if (visible.index != position.index ||
          visible.chunkIndex >= 0 ||
          position.offset != logical.offset) {
        throw const SqlEditorException(SqlEditorFailure.staleSelection);
      }
      return absolute;
    }
    final line = next.codeLines.index2lineIndex(position.index);
    return next.source.offsetForPosition(
      CodeLinePosition(index: line, offset: position.offset),
    );
  }

  int offsetForPosition(CodeLinePosition position) => _offset(position, value);
  CodeLinePosition positionForOffset(int offset) {
    final raw = value.source.positionForOffset(offset),
        visible = codeLines.lineIndex2Index(raw.index);
    if (visible.index < 0 || visible.chunkIndex >= 0) {
      throw const SqlEditorException(SqlEditorFailure.staleSelection);
    }
    return SqlSourcePosition(
      source: value.source,
      absoluteOffset: offset,
      projection: CodeLinePosition(index: visible.index, offset: raw.offset),
    );
  }

  void selectOffsets(int start, int end) => _guard(() {
    final source = value.source;
    source.positionForOffset(start);
    source.positionForOffset(end);
    for (var depth = 0; depth < 64; depth++) {
      final a = codeLines.lineIndex2Index(
            source.positionForOffset(start).index,
          ),
          b = codeLines.lineIndex2Index(source.positionForOffset(end).index);
      if (a.chunkIndex < 0 && b.chunkIndex < 0) break;
      expandChunk(a.chunkIndex >= 0 ? a.index : b.index);
    }
    _accept(
      value.copyWith(
        selection: SqlSourceSelection(
          source: source,
          base: positionForOffset(start),
          extent: positionForOffset(end),
        ),
        secondarySelections: const [],
        composing: TextRange.empty,
      ),
    );
  });
  void _syncNavigation() {
    final projected = CodeLineEditingValue(
      codeLines: value.codeLines,
      selection: value.selection,
      composing: value.composing,
    );
    _navigation.value = projected;
    _navigation.value = projected;
    _navigation.clearHistory();
  }

  void _navigate(
    void Function(CodeLineEditingController controller) command, {
    bool secondary = false,
  }) => _guard(() {
    _syncNavigation();
    command(_navigation);
    _accept(
      value.copyWith(
        selection: _navigation.selection,
        composing: _navigation.composing,
        secondarySelections: secondary ? value.secondarySelections : const [],
      ),
    );
  });
  void _wordForward(CodeLineEditingController controller) {
    var line = controller.selection.extentIndex;
    var offset = controller.selection.extentOffset;
    if (offset == controller.codeLines[line].length &&
        line + 1 < controller.codeLines.length) {
      line++;
      offset = 0;
    }
    final text = controller.codeLines[line].text;
    var at = offset;
    while (at < text.length && text.codeUnitAt(at) == 32) {
      at++;
    }
    if (at == text.length && at > offset) {
      controller.selection = CodeLineSelection.collapsed(
        index: line,
        offset: at,
      );
      controller.makeCursorVisible();
    } else {
      controller.moveCursorToWordBoundaryForward();
    }
  }

  void _extendWordForward(CodeLineEditingController controller) {
    final original = controller.selection;
    _wordForward(controller);
    final extent = controller.selection.extent;
    controller.selection = original.copyWith(
      extentIndex: extent.index,
      extentOffset: extent.offset,
      extentAffinity: extent.affinity,
    );
  }

  void _stage(void Function(CodeLineEditingController controller) command) =>
      _guard(() {
        final before = value;
        try {
          _scratch.value = CodeLineEditingValue(
            codeLines: CodeLines.from(before.codeLines),
            selection: before.selection,
            composing: before.composing,
          );
          _scratch.clearHistory();
          command(_scratch);
          final result = _scratch.value;
          _accept(
            before.copyWith(
              source: before.source.rewriteProjection(
                result.codeLines,
                newLineEnding: options.lineBreak.value,
              ),
              codeLines: result.codeLines,
              selection: result.selection,
              composing: result.composing,
              secondarySelections: const [],
            ),
          );
        } finally {
          const empty = CodeLineEditingValue.empty();
          _scratch.value = empty;
          _scratch.value = empty;
          _scratch.clearHistory();
        }
      });
  @override
  CodeLineEditingValue? get preValue => _preValue;
  @override
  CodeLines get codeLines => value.codeLines;
  @override
  set codeLines(CodeLines lines) => value = value.copyWith(codeLines: lines);
  @override
  CodeLineSelection get selection => value.selection;
  @override
  set selection(CodeLineSelection selection) => value = value.copyWith(
    selection: selection,
    secondarySelections: const [],
    composing: TextRange.empty,
  );
  @override
  TextRange get composing => value.composing;
  @override
  set composing(TextRange range) => value = value.copyWith(composing: range);
  @override
  String get text => value.source.text;
  @override
  set text(String text) => _guard(
    () => _accept(
      SqlEditorValue(source: SqlSource(text)),
      commitComposition: true,
    ),
  );
  @override
  set textAsync(String text) => _guard(() {
    final candidate = SqlSource(text), previous = _pendingSource;
    _pendingSource = candidate;
    try {
      admitChange?.call(_value, chargedUnits);
    } catch (_) {
      _pendingSource = previous;
      rethrow;
    }
    _pendingSourceGeneration = _generation;
    if (_sourceScheduled) return;
    _sourceScheduled = true;
    scheduleMicrotask(() {
      _sourceScheduled = false;
      final candidate = _pendingSource, generation = _pendingSourceGeneration;
      _pendingSource = null;
      if (_disposed) return;
      try {
        if (candidate != null && generation == _generation) {
          _guard(
            () => _accept(
              SqlEditorValue(source: candidate),
              commitComposition: true,
            ),
          );
        }
      } finally {
        if (!_disposed) admitChange?.call(_value, chargedUnits);
      }
    });
  });
  @override
  String get selectedText => text.substring(
    offsetForPosition(selection.start),
    offsetForPosition(selection.end),
  );
  @override
  CodeLine get baseLine => codeLines[selection.baseIndex];
  @override
  CodeLine get extentLine => codeLines[selection.extentIndex];
  @override
  CodeLine get startLine => codeLines[selection.startIndex];
  @override
  CodeLine get endLine => codeLines[selection.endIndex];
  @override
  bool get isComposing => composing.isValid && !composing.isCollapsed;
  @override
  int get lineCount => value.source.lineCount;
  @override
  bool get isEmpty => text.isEmpty;
  @override
  bool get isAllSelected =>
      offsetForPosition(selection.start) == 0 &&
      offsetForPosition(selection.end) == text.length;
  @override
  bool get canUndo => _undo.isNotEmpty || _compositionBase != null;
  @override
  bool get canRedo => _redo.isNotEmpty;
  @override
  CodeLineSelection get unfoldLineSelection => selection.copyWith(
    baseIndex: index2lineIndex(selection.baseIndex),
    extentIndex: index2lineIndex(selection.extentIndex),
  );
  @override
  int index2lineIndex(int index) => codeLines.index2lineIndex(index);
  @override
  CodeLineIndex lineIndex2Index(int index) => codeLines.lineIndex2Index(index);
  @override
  void bindEditor(GlobalKey key) => _navigation.bindEditor(key);
  @override
  void makeCursorVisible() => _navigation.makeCursorVisible();
  @override
  void makeCursorCenterIfInvisible() =>
      _navigation.makeCursorCenterIfInvisible();
  @override
  void makePositionVisible(CodeLinePosition position) =>
      _navigation.makePositionVisible(position);
  @override
  void makePositionCenterIfInvisible(CodeLinePosition position) =>
      _navigation.makePositionCenterIfInvisible(position);
  @override
  void forceRepaint() => _navigation.forceRepaint();
  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required int index,
    required TextSpan textSpan,
    required TextStyle style,
  }) =>
      spanBuilder?.call(
        context: context,
        index: index,
        codeLine: codeLines[index],
        textSpan: textSpan,
        style: style,
      ) ??
      textSpan;

  @override
  void runRevocableOp(VoidCallback operation) => _guard(() {
    if (_depth > 0) {
      operation();
      return;
    }
    _staged = _value;
    _transactionFailed = false;
    _stagedCommitComposition = false;
    _depth++;
    SqlEditorValue? candidate;
    try {
      operation();
      candidate = _staged;
    } finally {
      _depth--;
      _staged = null;
    }
    if (!_transactionFailed &&
        candidate != null &&
        !_value.sameContent(candidate)) {
      _publish(candidate, commitComposition: _stagedCommitComposition);
    }
  });
  bool replaceSource(String replacement, int Function(int offset) map) {
    if (isComposing) return false;
    var accepted = false;
    _guard(() {
      final source = SqlSource(replacement);
      CodeLineSelection mapped(CodeLineSelection old) {
        final base = source.positionForOffset(map(offsetForPosition(old.base))),
            extent = source.positionForOffset(
              map(offsetForPosition(old.extent)),
            );
        return SqlSourceSelection(source: source, base: base, extent: extent);
      }

      accepted = _publish(
        SqlEditorValue(
          source: source,
          selection: mapped(selection),
          secondarySelections: value.secondarySelections.map(mapped).toList(),
        ),
      );
    });
    return accepted;
  }

  /// Reports a current native resource refusal through the same owned UI hooks.
  /// Malformed or superseded native chains should instead resynchronize quietly.
  bool rejectNativeInput({
    required SqlEditorValue expectedOwner,
    required SqlEditorFailure reason,
  }) {
    if (_disposed || !identical(expectedOwner, value)) return false;
    _guard(() => throw SqlEditorException(reason));
    return true;
  }

  /// Accepts one native delta only for its exact immutable captured owner.
  ///
  /// [start]/[end] address the original UTF-16 source. Selection and composing
  /// deltas address the end of the replacement, before shifts from other carets.
  /// The native client must validate the entire old-text chain before this call.
  /// A stale owner returns false and never publishes or replays an edit.
  bool applyNativeEdit({
    required SqlEditorValue expectedOwner,
    required int start,
    required int end,
    required String replacement,
    required int selectionDelta,
    required int extentDelta,
    SqlNativeComposingRange? composingDeltas,
    bool replicate = true,
  }) {
    if (_disposed || !identical(expectedOwner, value)) return false;
    var accepted = false;
    _guard(() {
      final before = value;
      if (start < 0 || end < start || end > before.source.length) {
        throw const SqlEditorException(SqlEditorFailure.staleSelection);
      }
      if (start == end && replacement.isEmpty) {
        final primaryBase = start + selectionDelta;
        final primaryExtent = start + extentDelta;
        final baseDelta = primaryBase - _offset(before.selection.base, before);
        final extentShift =
            primaryExtent - _offset(before.selection.extent, before);
        final ranges = <CodeLineSelection>[];
        for (final range in [
          before.selection,
          if (replicate) ...before.secondarySelections,
        ]) {
          final base = positionForOffset(
            _offset(range.base, before) + baseDelta,
          );
          final extent = positionForOffset(
            _offset(range.extent, before) + extentShift,
          );
          ranges.add(
            SqlSourceSelection(
              source: before.source,
              base: base,
              extent: extent,
            ),
          );
        }
        _accept(
          before.copyWith(
            selection: ranges.first,
            secondarySelections: ranges.skip(1).toList(),
            composing: _nativeComposing(
              before.source,
              start,
              composingDeltas,
              primaryBase,
              primaryExtent,
            ),
          ),
        );
      } else {
        final leading = start - _offset(before.selection.start, before);
        final trailing = end - _offset(before.selection.end, before);
        final ranges = <CodeLineSelection>[
          SqlSourceSelection(
            source: before.source,
            base: positionForOffset(start),
            extent: positionForOffset(end),
          ),
        ];
        if (replicate && before.secondarySelections.isNotEmpty) {
          final primaryStart = before.source.positionForOffset(start);
          final primaryEnd = before.source.positionForOffset(end);
          final selectedStart = before.source.positionForOffset(
            _offset(before.selection.start, before),
          );
          final selectedEnd = before.source.positionForOffset(
            _offset(before.selection.end, before),
          );
          if (leading != 0 && primaryStart.index != selectedStart.index ||
              trailing != 0 && primaryEnd.index != selectedEnd.index) {
            throw const SqlEditorException(SqlEditorFailure.staleSelection);
          }
          for (final range in before.secondarySelections) {
            final originalStart = _offset(range.start, before);
            final originalEnd = _offset(range.end, before);
            final a = originalStart + leading;
            final b = originalEnd + trailing;
            if (leading != 0 &&
                    before.source.positionForOffset(a).index !=
                        before.source.positionForOffset(originalStart).index ||
                trailing != 0 &&
                    before.source.positionForOffset(b).index !=
                        before.source.positionForOffset(originalEnd).index) {
              throw const SqlEditorException(SqlEditorFailure.staleSelection);
            }
            ranges.add(
              SqlSourceSelection(
                source: before.source,
                base: positionForOffset(a),
                extent: positionForOffset(b),
              ),
            );
          }
        }
        _replace(
          replacement,
          ranges,
          selectionDelta: selectionDelta,
          extentDelta: extentDelta,
          composingDeltas: composingDeltas,
        );
      }
      accepted = true;
    });
    return accepted;
  }

  TextRange _nativeComposing(
    SqlSource source,
    int replacementEnd,
    SqlNativeComposingRange? deltas,
    int selectionBase,
    int selectionExtent,
  ) {
    if (deltas == null || deltas.isCollapsed) return TextRange.empty;
    final start = replacementEnd + deltas.start,
        end = replacementEnd + deltas.end;
    if (start < 0 ||
        end < start ||
        end > source.length ||
        selectionBase < 0 ||
        selectionBase > source.length ||
        selectionExtent < 0 ||
        selectionExtent > source.length) {
      throw const SqlEditorException(SqlEditorFailure.composing);
    }
    final a = source.positionForOffset(start),
        b = source.positionForOffset(end);
    final base = source.positionForOffset(selectionBase);
    final extent = source.positionForOffset(selectionExtent);
    if (a.index != b.index ||
        a.index != base.index ||
        a.index != extent.index ||
        b.offset - a.offset != end - start) {
      throw const SqlEditorException(SqlEditorFailure.composing);
    }
    return TextRange(start: a.offset, end: b.offset);
  }

  void _replace(
    String replacement,
    List<CodeLineSelection> ranges, {
    TextRange composing = TextRange.empty,
    int selectionDelta = 0,
    int? extentDelta,
    SqlNativeComposingRange? composingDeltas,
  }) {
    if (ranges.length > 64 || ranges.isEmpty) {
      throw const SqlEditorException(SqlEditorFailure.caretLimit);
    }
    final before = value;
    final edits = [
      for (var index = 0; index < ranges.length; index++)
        _Edit(
          _offset(ranges[index].start, before),
          _offset(ranges[index].end, before),
          index,
        ),
    ]..sort((a, b) => a.start.compareTo(b.start));
    var projected = before.source.length, previousEnd = -1, previousStart = -1;
    for (final edit in edits) {
      if (edit.start < previousEnd ||
          edit.start == previousStart && edit.end == previousEnd) {
        throw const SqlEditorException(SqlEditorFailure.overlappingRanges);
      }
      previousEnd = edit.end;
      previousStart = edit.start;
      projected += replacement.length - (edit.end - edit.start);
    }
    if (projected > SqlSource.maxUnits) {
      throw const SqlEditorException(SqlEditorFailure.documentLimit);
    }
    final offsets = List<int>.filled(ranges.length, 0);
    var shift = 0;
    for (final edit in edits) {
      offsets[edit.owner] = edit.start + shift + replacement.length;
      shift += replacement.length - (edit.end - edit.start);
    }
    var source = before.source;
    for (final edit in edits.reversed) {
      source = source.replace(edit.start, edit.end, replacement);
    }
    final selections = offsets.map((offset) {
      final base = source.positionForOffset(offset + selectionDelta),
          extent = source.positionForOffset(
            offset + (extentDelta ?? selectionDelta),
          );
      return SqlSourceSelection(source: source, base: base, extent: extent);
    }).toList();
    if (composingDeltas != null) {
      composing = _nativeComposing(
        source,
        offsets.first,
        composingDeltas,
        offsets.first + selectionDelta,
        offsets.first + (extentDelta ?? selectionDelta),
      );
    }
    _accept(
      SqlEditorValue(
        source: source,
        selection: selections.first,
        secondarySelections: selections.skip(1).toList(),
        composing: composing,
      ),
    );
  }

  void replaceSelections(
    String replacement, {
    List<CodeLineSelection>? ranges,
    bool recordUndo = true,
    TextRange composing = TextRange.empty,
  }) => _guard(() {
    final wasRestoring = _restoring;
    if (!recordUndo) _restoring = true;
    try {
      _replace(
        replacement,
        ranges ?? [selection, ...value.secondarySelections],
        composing: composing,
      );
    } finally {
      _restoring = wasRestoring;
    }
  });
  @override
  void replaceSelection(String replacement, [CodeLineSelection? range]) =>
      replaceSelections(replacement, ranges: range == null ? null : [range]);
  @override
  void replaceAll(Pattern pattern, String replacement) => _guard(() {
    final matches = pattern.allMatches(text);
    var projected = text.length;
    for (final match in matches) {
      projected += replacement.length - (match.end - match.start);
    }
    if (projected > SqlSource.maxUnits) {
      throw const SqlEditorException(SqlEditorFailure.documentLimit);
    }
    final changed = text.replaceAll(pattern, replacement);
    _accept(SqlEditorValue(source: SqlSource(changed)));
  });

  @override
  void edit(TextEditingValue incoming) {
    final generation = _generation;
    try {
      _guard(() {
        final before = value;
        if (incoming.text.length > SqlSource.maxUnits) {
          throw const SqlEditorException(SqlEditorFailure.documentLimit);
        }
        if (before.secondarySelections.isNotEmpty &&
            before.selection.isSameLine &&
            !incoming.text.contains('\n') &&
            !incoming.text.contains('\r')) {
          final old = before.codeLines[before.selection.baseIndex].text,
              next = incoming.text;
          var prefix = 0;
          while (prefix < old.length &&
              prefix < next.length &&
              old.codeUnitAt(prefix) == next.codeUnitAt(prefix)) {
            prefix++;
          }
          var suffix = 0;
          while (suffix < old.length - prefix &&
              suffix < next.length - prefix &&
              old.codeUnitAt(old.length - suffix - 1) ==
                  next.codeUnitAt(next.length - suffix - 1)) {
            suffix++;
          }
          if (old == next) {
            final baseDelta =
                incoming.selection.baseOffset - before.selection.baseOffset;
            final extentDelta =
                incoming.selection.extentOffset - before.selection.extentOffset;
            final ranges = [before.selection, ...before.secondarySelections]
                .map(
                  (range) => range.copyWith(
                    baseOffset: range.baseOffset + baseDelta,
                    extentOffset: range.extentOffset + extentDelta,
                  ),
                )
                .toList();
            _accept(
              before.copyWith(
                selection: ranges.first,
                secondarySelections: ranges.skip(1).toList(),
                composing: incoming.composing,
              ),
            );
            return;
          }
          final replacement = next.substring(prefix, next.length - suffix);
          final ranges = [before.selection, ...before.secondarySelections]
              .map(
                (range) => range.copyWith(
                  baseOffset:
                      range.startOffset + prefix - before.selection.startOffset,
                  extentOffset:
                      range.endOffset +
                      old.length -
                      suffix -
                      before.selection.endOffset,
                ),
              )
              .toList();
          _replace(
            replacement,
            ranges,
            composing: incoming.composing,
            selectionDelta:
                incoming.selection.baseOffset - prefix - replacement.length,
            extentDelta:
                incoming.selection.extentOffset - prefix - replacement.length,
          );
          return;
        }
        final baseText = before.codeLines[before.selection.baseIndex].text;
        final start = _offset(before.selection.start, before),
            end = _offset(before.selection.end, before);
        final localStart = before.selection.isSameLine
            ? before.selection.startOffset
            : before.selection.baseIndex < before.selection.extentIndex
            ? before.selection.baseOffset
            : 0;
        final localEnd = before.selection.isSameLine
            ? before.selection.endOffset
            : before.selection.baseIndex < before.selection.extentIndex
            ? baseText.length
            : before.selection.baseOffset;
        final prefix = baseText.substring(0, localStart),
            suffix = baseText.substring(localEnd);
        String replacement;
        int from = start, until = end, anchor;
        if (before.selection.isSameLine) {
          from = _offset(
            CodeLinePosition(index: before.selection.baseIndex, offset: 0),
            before,
          );
          until = from + baseText.length;
          replacement = incoming.text;
          anchor = from;
        } else if (incoming.text.startsWith(prefix) &&
            incoming.text.endsWith(suffix) &&
            incoming.text.length >= prefix.length + suffix.length) {
          replacement = incoming.text.substring(
            prefix.length,
            incoming.text.length - suffix.length,
          );
          anchor = before.selection.baseIndex < before.selection.extentIndex
              ? start - prefix.length
              : start;
        } else {
          throw const SqlEditorException(SqlEditorFailure.staleSelection);
        }
        final source = before.source.replace(from, until, replacement);
        final a = source.positionForOffset(
              anchor + incoming.selection.baseOffset,
            ),
            b = source.positionForOffset(
              anchor + incoming.selection.extentOffset,
            );
        _accept(
          SqlEditorValue(
            source: source,
            selection: SqlSourceSelection(source: source, base: a, extent: b),
            composing: incoming.composing,
          ),
        );
      });
    } finally {
      if (!_disposed && !_notifying && generation == _generation) {
        notifyListeners();
      }
    }
  }

  void setExtraSelections(List<CodeLineSelection> ranges) => _guard(() {
    if (ranges.length >= 64) {
      throw const SqlEditorException(SqlEditorFailure.caretLimit);
    }
    if (List.generate(
      codeLines.length,
      (index) => codeLines[index],
    ).any((line) => line.chunkParent)) {
      throw const SqlEditorException(SqlEditorFailure.foldedRegion);
    }
    final accepted = <CodeLineSelection>[];
    for (final range in [selection, ...ranges]) {
      final start = offsetForPosition(range.start),
          end = offsetForPosition(range.end);
      if (accepted.any((other) {
        final a = offsetForPosition(other.start),
            b = offsetForPosition(other.end);
        return start == a && end == b || start < b && end > a;
      })) {
        continue;
      }
      accepted.add(range);
    }
    _accept(value.copyWith(secondarySelections: accepted.skip(1).toList()));
  });
  void addCaret(int direction) {
    if (isComposing) return;
    final last = value.secondarySelections.isEmpty
        ? selection
        : value.secondarySelections.last;
    final line = last.extentIndex + direction;
    if (line < 0 || line >= codeLines.length) return;
    setExtraSelections([
      ...value.secondarySelections,
      CodeLineSelection.collapsed(
        index: line,
        offset: math.min(last.extentOffset, codeLines[line].length),
      ),
    ]);
  }

  void selectNextOccurrence() {
    if (isComposing) return;
    runRevocableOp(() {
      if (selectedText.isEmpty) {
        _navigate((worker) => worker.moveCursorToWordBoundaryBackward());
        _navigate((worker) => _extendWordForward(worker));
      }
      final selected = selectedText;
      if (selected.isEmpty) return;
      final all = [selection, ...value.secondarySelections];
      final from = all
          .map((range) => offsetForPosition(range.end))
          .reduce((a, b) => math.max(a, b));
      var at = text.indexOf(selected, from);
      if (at < 0) at = text.indexOf(selected);
      if (at < 0) return;
      final a = positionForOffset(at),
          b = positionForOffset(at + selected.length);
      setExtraSelections([
        ...value.secondarySelections,
        CodeLineSelection(
          baseIndex: a.index,
          baseOffset: a.offset,
          extentIndex: b.index,
          extentOffset: b.offset,
        ),
      ]);
    });
  }

  void moveSelections(VoidCallback action) {
    if (isComposing) return;
    final original = [selection, ...value.secondarySelections],
        updated = <CodeLineSelection>[];
    runRevocableOp(() {
      for (final range in original) {
        selection = range;
        action();
        updated.add(selection);
      }
      _accept(
        value.copyWith(
          selection: updated.first,
          secondarySelections: updated.skip(1).toList(),
        ),
      );
    });
  }

  void indentSelections(bool outdent) => _guard(() {
    if (isComposing) throw const SqlEditorException(SqlEditorFailure.composing);
    final before = value, ranges = [selection, ...value.secondarySelections];
    final selected = <int>{};
    for (final range in ranges) {
      for (
        var index = range.startIndex;
        index <=
            range.endIndex -
                (!range.isCollapsed && range.endOffset == 0 ? 1 : 0);
        index++
      ) {
        selected.add(index2lineIndex(index));
      }
    }
    var projected = text.length;
    final deltas = <int, int>{};
    for (final index in selected) {
      final line = before.source.lines[index];
      var removed = 0;
      if (outdent) {
        if (line.startsWith('\t')) {
          removed = 1;
        } else {
          while (removed < options.indentSize &&
              removed < line.length &&
              line.codeUnitAt(removed) == 32) {
            removed++;
          }
        }
      }
      final delta = outdent ? -removed : options.indent.length;
      deltas[index] = delta;
      projected += delta;
    }
    if (projected > SqlSource.maxUnits) {
      throw const SqlEditorException(SqlEditorFailure.documentLimit);
    }
    final output = StringBuffer();
    for (var index = 0; index < before.source.lines.length; index++) {
      final line = before.source.lines[index], delta = deltas[index] ?? 0;
      output.write(
        delta < 0
            ? line.substring(-delta)
            : delta > 0
            ? options.indent + line
            : line,
      );
      output.write(before.source.endings[index]);
    }
    final source = SqlSource(output.toString());
    CodeLineSelection mapped(CodeLineSelection range) => range.copyWith(
      baseIndex: index2lineIndex(range.baseIndex),
      extentIndex: index2lineIndex(range.extentIndex),
      baseOffset: math.max(
        0,
        range.baseOffset + (deltas[index2lineIndex(range.baseIndex)] ?? 0),
      ),
      extentOffset: math.max(
        0,
        range.extentOffset + (deltas[index2lineIndex(range.extentIndex)] ?? 0),
      ),
    );
    final selections = ranges.map(mapped).toList();
    _accept(
      SqlEditorValue(
        source: source,
        selection: selections.first,
        secondarySelections: selections.skip(1).toList(),
      ),
    );
  });
  SqlSourceSelection _exactSelection(int start, int end) => SqlSourceSelection(
    source: value.source,
    base: positionForOffset(start),
    extent: positionForOffset(end),
  );

  // A projected line-end caret can be between CR and LF in the exact source.
  // Delete its containing separator as one grapheme, without reaching into
  // neighboring text or replacing its source-owned position with the projection.
  TextRange? _containingSeparator(int offset) {
    final source = value.source, position = source.positionForOffset(offset);
    final lineEnd =
        source.starts[position.index] + source.lines[position.index].length;
    if (offset <= lineEnd) return null;
    return TextRange(
      start: lineEnd,
      end: lineEnd + source.endings[position.index].length,
    );
  }

  void deleteSelections(bool backward) => _guard(() {
    final ranges = [selection, ...value.secondarySelections].map((range) {
      if (!range.isCollapsed) return range;
      var start = offsetForPosition(range.start), end = start;
      final separator = _containingSeparator(start);
      if (separator != null) {
        return _exactSelection(separator.start, separator.end);
      }
      final line = codeLines[range.extentIndex].text;
      if (backward && range.extentOffset == 0 && start > 0) {
        start -=
            value.source.endings[index2lineIndex(range.extentIndex) - 1].length;
      } else if (!backward &&
          range.extentOffset == line.length &&
          end < text.length) {
        end += value.source.endings[index2lineIndex(range.extentIndex)].length;
      } else if (range.extentOffset > 0 &&
          range.extentOffset < line.length &&
          const {'(': ')', '[': ']', '{': '}', "'": "'", '"': '"'}[line
                  .substring(range.extentOffset - 1, range.extentOffset)] ==
              line.substring(range.extentOffset, range.extentOffset + 1)) {
        start--;
        end++;
      } else if (backward && range.extentOffset > 0) {
        start -= CodeLine(
          line.substring(0, range.extentOffset),
        ).takeLastCharacter(1).length;
      } else if (!backward && range.extentOffset < line.length) {
        end += CodeLine(
          line.substring(range.extentOffset),
        ).takeCharacter(1).length;
      }
      return _exactSelection(start, end);
    }).toList();
    _replace('', ranges);
  });
  void deleteSelectionBoundaries(
    bool backward, {
    bool word = true,
  }) => _guard(() {
    final ranges = <CodeLineSelection>[];
    for (final range in [selection, ...value.secondarySelections]) {
      if (!range.isCollapsed) {
        ranges.add(range);
        continue;
      }
      var start = offsetForPosition(range.start), end = start;
      final separator = _containingSeparator(start);
      if (separator != null) {
        ranges.add(_exactSelection(separator.start, separator.end));
        continue;
      }
      if (backward && range.extentOffset == 0 && start > 0) {
        start -=
            value.source.endings[index2lineIndex(range.extentIndex) - 1].length;
      } else if (!backward &&
          range.extentOffset == codeLines[range.extentIndex].length &&
          end < text.length) {
        end += value.source.endings[index2lineIndex(range.extentIndex)].length;
      } else if (word) {
        _syncNavigation();
        _navigation.selection = range;
        if (backward) {
          _navigation.moveCursorToWordBoundaryBackward();
          start = offsetForPosition(_navigation.selection.extent);
        } else {
          _wordForward(_navigation);
          end = offsetForPosition(_navigation.selection.extent);
        }
      } else if (backward) {
        start -= range.extentOffset;
      } else {
        end += codeLines[range.extentIndex].length - range.extentOffset;
      }
      ranges.add(_exactSelection(start, end));
    }
    final primary = ranges.first;
    ranges.sort(
      (a, b) =>
          offsetForPosition(a.start).compareTo(offsetForPosition(b.start)),
    );
    final merged = <CodeLineSelection>[];
    for (final range in ranges) {
      if (merged.isNotEmpty &&
          offsetForPosition(range.start) <=
              offsetForPosition(merged.last.end)) {
        final previous = merged.removeLast(),
            end = offsetForPosition(range.end) > offsetForPosition(previous.end)
                ? range.end
                : previous.end;
        merged.add(
          _exactSelection(
            offsetForPosition(previous.start),
            offsetForPosition(end),
          ),
        );
      } else {
        merged.add(range);
      }
    }
    final primaryIndex = merged.indexWhere(
      (range) =>
          offsetForPosition(range.start) <= offsetForPosition(primary.start) &&
          offsetForPosition(range.end) >= offsetForPosition(primary.end),
    );
    if (primaryIndex > 0) merged.insert(0, merged.removeAt(primaryIndex));
    _replace('', merged);
  });
  void formatSelectionComments(
    CodeCommentFormatter formatter,
    bool single,
  ) => _guard(() {
    if (isComposing) throw const SqlEditorException(SqlEditorFailure.composing);
    final ranges = [selection, ...value.secondarySelections];
    if (text.length * ranges.length > 32000000) {
      throw const SqlEditorException(SqlEditorFailure.workLimit);
    }
    runRevocableOp(() {
      var working = value;
      final mapped = List<CodeLineSelection>.of(ranges);
      final order = List<int>.generate(ranges.length, (index) => index)
        ..sort(
          (a, b) => _offset(
            ranges[b].start,
            working,
          ).compareTo(_offset(ranges[a].start, working)),
        );
      for (final owner in order) {
        final before = working,
            offsets = mapped
                .map(
                  (range) => MapEntry(
                    _offset(range.base, before),
                    _offset(range.extent, before),
                  ),
                )
                .toList();
        final formatted = formatter.format(
          CodeLineEditingValue(
            codeLines: CodeLines.from(before.codeLines),
            selection: mapped[owner],
          ),
          options.indent,
          single,
        );
        final source = before.source.rewriteProjection(
          formatted.codeLines,
          newLineEnding: options.lineBreak.value,
        );
        var prefix = 0;
        while (prefix < before.source.length &&
            prefix < source.length &&
            before.source.text.codeUnitAt(prefix) ==
                source.text.codeUnitAt(prefix)) {
          prefix++;
        }
        var suffix = 0;
        while (suffix < before.source.length - prefix &&
            suffix < source.length - prefix &&
            before.source.text.codeUnitAt(before.source.length - suffix - 1) ==
                source.text.codeUnitAt(source.length - suffix - 1)) {
          suffix++;
        }
        int map(int offset) => offset <= prefix
            ? offset
            : offset >= before.source.length - suffix
            ? offset + source.length - before.source.length
            : source.length - suffix;
        for (var index = 0; index < mapped.length; index++) {
          if (index == owner) {
            mapped[index] = formatted.selection;
          } else {
            final a = source.positionForOffset(map(offsets[index].key)),
                b = source.positionForOffset(map(offsets[index].value));
            mapped[index] = CodeLineSelection(
              baseIndex: a.index,
              baseOffset: a.offset,
              extentIndex: b.index,
              extentOffset: b.offset,
            );
          }
        }
        working = SqlEditorValue(
          source: source,
          codeLines: formatted.codeLines,
          selection: mapped.first,
          secondarySelections: mapped.skip(1).toList(),
        );
      }
      _accept(working);
    });
  });
  @override
  void applyNewLine() => _guard(() {
    if (value.secondarySelections.isNotEmpty) {
      _replace(options.lineBreak.value, [
        selection,
        ...value.secondarySelections,
      ]);
      return;
    }
    final before = startLine.text.substring(0, selection.startOffset),
        after = endLine.text.substring(selection.endOffset);
    final indent = RegExp(r'^[ \t]*').stringMatch(before) ?? '';
    final open = before.trimRight().isEmpty
        ? ''
        : before.trimRight().substring(before.trimRight().length - 1);
    final close = after.trimLeft().isEmpty
        ? ''
        : after.trimLeft().substring(0, 1);
    final pair = const {'(': ')', '[': ']', '{': '}'}[open] == close;
    final inserted =
        options.lineBreak.value +
        indent +
        (const ['(', '[', '{'].contains(open) ? options.indent : '');
    _replace(
      pair ? inserted + options.lineBreak.value + indent : inserted,
      [selection],
      selectionDelta: pair
          ? -options.lineBreak.value.length - indent.length
          : 0,
    );
  });
  @override
  void applyIndent() {
    if (selection.isCollapsed && value.secondarySelections.isEmpty) {
      replaceSelection(options.indent);
    } else {
      indentSelections(false);
    }
  }

  @override
  void applyOutdent() => indentSelections(true);
  @override
  void deleteSelection() {
    if (!selection.isCollapsed || value.secondarySelections.isNotEmpty) {
      replaceSelections('');
    }
  }

  @override
  void deleteBackward() => deleteSelections(true);
  @override
  void deleteForward() => deleteSelections(false);
  @override
  void deleteWordBackward() => deleteSelectionBoundaries(true);
  @override
  void deleteWordForward() => deleteSelectionBoundaries(false);
  @override
  void deleteLineBackward() => deleteSelectionBoundaries(true, word: false);
  @override
  void deleteLineForward() => deleteSelectionBoundaries(false, word: false);
  @override
  void deleteSelectionLines([bool keepExtentOffset = true]) =>
      _stage((worker) => worker.deleteSelectionLines(keepExtentOffset));
  @override
  void transposeCharacters() =>
      _stage((worker) => worker.transposeCharacters());
  @override
  void moveSelectionLinesUp() =>
      _stage((worker) => worker.moveSelectionLinesUp());
  @override
  void moveSelectionLinesDown() =>
      _stage((worker) => worker.moveSelectionLinesDown());
  @override
  void collapseChunk(int start, int end) =>
      _stage((worker) => worker.collapseChunk(start, end));
  @override
  void expandChunk(int index) => _stage((worker) => worker.expandChunk(index));

  @override
  void undo() => _guard(() {
    if (_compositionBase != null) {
      final original = _compositionBase!;
      _publish(
        original.copyWith(composing: TextRange.empty),
        record: false,
        resetComposition: true,
      );
      return;
    }
    if (_undo.isEmpty) return;
    final undo = List<_History>.of(_undo), target = undo.removeLast();
    final redo = [..._redo, _History(_value)];
    _publish(
      target.value.copyWith(composing: TextRange.empty),
      record: false,
      undoPlan: undo,
      redoPlan: redo,
      resetComposition: true,
    );
  });
  @override
  void redo() => _guard(() {
    if (_redo.isEmpty || isComposing) return;
    final redo = List<_History>.of(_redo), target = redo.removeLast();
    final undo = [..._undo, _History(_value)];
    _publish(
      target.value.copyWith(composing: TextRange.empty),
      record: false,
      undoPlan: undo,
      redoPlan: redo,
      resetComposition: true,
    );
  });
  @override
  void clearHistory() => _guard(() {
    admitChange?.call(_value, _auxiliary(_value, null));
    _undo.clear();
    _redo.clear();
    _compositionBase = null;
    _preValue = null;
    _navigation.clearHistory();
    _scratch.clearHistory();
    notifyListeners();
  });
  @override
  void clearComposing() => composing = TextRange.empty;
  String _copyText() {
    final output = StringBuffer();
    var bytes = 0, count = 0;
    for (final range in [selection, ...value.secondarySelections]) {
      if (count++ > 0) {
        bytes = _clipboardBytes(
          options.lineBreak.value,
          0,
          options.lineBreak.value.length,
          bytes,
        );
        output.write(options.lineBreak.value);
      }
      var start = offsetForPosition(range.start),
          end = offsetForPosition(range.end);
      if (range.isCollapsed) {
        final line = index2lineIndex(range.extentIndex);
        start = value.source.starts[line];
        end = line + 1 < value.source.lineCount
            ? value.source.starts[line + 1]
            : value.source.length;
      }
      bytes = _clipboardBytes(text, start, end, bytes);
      output.write(text.substring(start, end));
      if (range.isCollapsed &&
          index2lineIndex(range.extentIndex) == value.source.lineCount - 1) {
        bytes = _clipboardBytes(
          options.lineBreak.value,
          0,
          options.lineBreak.value.length,
          bytes,
        );
        output.write(options.lineBreak.value);
      }
    }
    return output.toString();
  }

  int _clipboardBytes(String text, int start, int end, int bytes) {
    for (var index = start; index < end; index++) {
      final unit = text.codeUnitAt(index);
      if (unit == 0) {
        throw const SqlEditorException(SqlEditorFailure.clipboardNul);
      }
      if (unit >= 0xd800 && unit <= 0xdbff) {
        if (++index >= end ||
            text.codeUnitAt(index) < 0xdc00 ||
            text.codeUnitAt(index) > 0xdfff) {
          throw const FormatException();
        }
        bytes += 4;
      } else if (unit >= 0xdc00 && unit <= 0xdfff) {
        throw const FormatException();
      } else {
        bytes += unit < 128
            ? 1
            : unit < 2048
            ? 2
            : 3;
      }
      if (bytes > _maxClipboardBytes) {
        throw const SqlEditorException(SqlEditorFailure.clipboardLimit);
      }
    }
    return bytes;
  }

  void _startClipboard(int units) {
    if (_disposed) {
      throw const SqlEditorException(SqlEditorFailure.disposed);
    }
    if (_clipboardBusy) {
      throw const SqlEditorException(SqlEditorFailure.clipboardBusy);
    }
    admitChange?.call(_value, chargedUnits + units);
    _clipboardBusy = true;
    _clipboardUnits = units;
  }

  void _finishClipboard() {
    _clipboardBusy = false;
    _clipboardUnits = 0;
    if (!_disposed) admitChange?.call(_value, chargedUnits);
  }

  Object _clipboardFailure(Object error) => error is PlatformException
      ? const SqlEditorException(SqlEditorFailure.clipboardUnavailable)
      : error;

  @override
  Future<void> copy() async {
    var started = false;
    try {
      if (_disposed) {
        throw const SqlEditorException(SqlEditorFailure.disposed);
      }
      if (_notifying || _admitting) {
        throw const SqlEditorException(SqlEditorFailure.reentrantMutation);
      }
      final output = _copyText();
      _startClipboard(output.length);
      started = true;
      await (writeClipboard?.call(output) ??
          Clipboard.setData(ClipboardData(text: output)));
    } catch (error, stack) {
      final failure = _clipboardFailure(error);
      if (!_handleRejection(failure)) Error.throwWithStackTrace(failure, stack);
    } finally {
      if (started) _finishClipboard();
    }
  }

  @override
  void cut() => _guard(() {
    final owner = _generation, output = _copyText();
    final offsets = [selection, ...value.secondarySelections].map((range) {
      if (!range.isCollapsed) {
        return (offsetForPosition(range.start), offsetForPosition(range.end));
      }
      final line = index2lineIndex(range.extentIndex);
      return (
        value.source.starts[line],
        line + 1 < value.source.lineCount
            ? value.source.starts[line + 1]
            : value.source.length,
      );
    }).toList();
    _startClipboard(output.length);
    unawaited(
      Future<void>.sync(
            () =>
                writeClipboard?.call(output) ??
                Clipboard.setData(ClipboardData(text: output)),
          )
          .then((_) {
            if (_disposed || owner != _generation) return;
            final ranges = offsets
                .map(
                  (range) => SqlSourceSelection(
                    source: value.source,
                    base: positionForOffset(range.$1),
                    extent: positionForOffset(range.$2),
                  ),
                )
                .toList();
            replaceSelections('', ranges: ranges);
          })
          .catchError((Object error, StackTrace stack) {
            if (!_disposed && owner == _generation) {
              _guard(
                () =>
                    Error.throwWithStackTrace(_clipboardFailure(error), stack),
              );
            }
          })
          .whenComplete(_finishClipboard),
    );
  });
  @override
  void paste() => _guard(() {
    final owner = _generation;
    _startClipboard(_maxClipboardBytes);
    unawaited(
      Future<String?>.sync(
            () =>
                readClipboard?.call() ??
                Clipboard.getData(
                  Clipboard.kTextPlain,
                ).then((value) => value?.text),
          )
          .then((text) {
            if (text == null || _disposed || owner != _generation) return;
            _guard(() {
              _clipboardBytes(text, 0, text.length, 0);
              _replace(text, [selection, ...value.secondarySelections]);
            });
          })
          .catchError((Object error, StackTrace stack) {
            if (!_disposed && owner == _generation) {
              _guard(
                () =>
                    Error.throwWithStackTrace(_clipboardFailure(error), stack),
              );
            }
          })
          .whenComplete(_finishClipboard),
    );
  });
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _owners.remove(this);
    if (_notifying) {
      _disposePending = true;
      return;
    }
    _finishDispose();
    super.dispose();
  }

  void _finishDispose() {
    _disposePending = false;
    _undo.clear();
    _redo.clear();
    _compositionBase = null;
    _pendingSource = null;
    _preValue = null;
    _staged = null;
    _value = SqlEditorValue.fromText('');
    const empty = CodeLineEditingValue.empty();
    for (final helper in [_scratch, _navigation]) {
      helper.value = empty;
      helper.value = empty;
      helper.clearHistory();
      helper.dispose();
    }
    admitChange = null;
    beforeChange = null;
    onChangeRejected = null;
    pageNavigation = null;
    _rejectionHandlers.clear();
    readClipboard = null;
    writeClipboard = null;
  }

  @override
  void selectLine(int index) => _navigate((worker) => worker.selectLine(index));
  @override
  void selectLines(int base, int extent) =>
      _navigate((worker) => worker.selectLines(base, extent));
  @override
  void selectAll() => _navigate((worker) => worker.selectAll());
  @override
  void cancelSelection() => _navigate((worker) => worker.cancelSelection());
  @override
  void moveCursor(AxisDirection direction) {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(() => _navigate((worker) => worker.moveCursor(direction)));
    } else {
      _navigate((worker) => worker.moveCursor(direction));
    }
  }

  @override
  void moveCursorToLineStart() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.moveCursorToLineStart()),
      );
    } else {
      _navigate((worker) => worker.moveCursorToLineStart());
    }
  }

  @override
  void moveCursorToLineEnd() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(() => _navigate((worker) => worker.moveCursorToLineEnd()));
    } else {
      _navigate((worker) => worker.moveCursorToLineEnd());
    }
  }

  @override
  void moveCursorToPageStart() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.moveCursorToPageStart()),
      );
    } else {
      _navigate((worker) => worker.moveCursorToPageStart());
    }
  }

  @override
  void moveCursorToPageEnd() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(() => _navigate((worker) => worker.moveCursorToPageEnd()));
    } else {
      _navigate((worker) => worker.moveCursorToPageEnd());
    }
  }

  @override
  void moveCursorToPageUp() => pageNavigation?.call(false, false);
  @override
  void moveCursorToPageDown() => pageNavigation?.call(true, false);
  @override
  void moveCursorToWordBoundaryForward() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(() => _navigate((worker) => _wordForward(worker)));
    } else {
      _navigate((worker) => _wordForward(worker));
    }
  }

  @override
  void moveCursorToWordBoundaryBackward() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.moveCursorToWordBoundaryBackward()),
      );
    } else {
      _navigate((worker) => worker.moveCursorToWordBoundaryBackward());
    }
  }

  @override
  void extendSelection(AxisDirection direction) {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.extendSelection(direction)),
      );
    } else {
      _navigate((worker) => worker.extendSelection(direction));
    }
  }

  @override
  void extendSelectionToLineStart() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.extendSelectionToLineStart()),
      );
    } else {
      _navigate((worker) => worker.extendSelectionToLineStart());
    }
  }

  @override
  void extendSelectionToLineEnd() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.extendSelectionToLineEnd()),
      );
    } else {
      _navigate((worker) => worker.extendSelectionToLineEnd());
    }
  }

  @override
  void extendSelectionToPageStart() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.extendSelectionToPageStart()),
      );
    } else {
      _navigate((worker) => worker.extendSelectionToPageStart());
    }
  }

  @override
  void extendSelectionToPageEnd() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate((worker) => worker.extendSelectionToPageEnd()),
      );
    } else {
      _navigate((worker) => worker.extendSelectionToPageEnd());
    }
  }

  @override
  void extendSelectionToWordBoundaryForward() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(() => _navigate((worker) => _extendWordForward(worker)));
    } else {
      _navigate((worker) => _extendWordForward(worker));
    }
  }

  @override
  void extendSelectionToWordBoundaryBackward() {
    if (value.secondarySelections.isNotEmpty && !isComposing) {
      moveSelections(
        () => _navigate(
          (worker) => worker.extendSelectionToWordBoundaryBackward(),
        ),
      );
    } else {
      _navigate((worker) => worker.extendSelectionToWordBoundaryBackward());
    }
  }
}
