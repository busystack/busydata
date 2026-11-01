import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../../features/workspace/editor/sql_editor.dart';
import 'sql_editor_geometry.dart';

/// Native input has one owner and one validated surrounding-text window.
/// External editor changes replace the connection, so an old platform client
/// cannot submit an edit against a newer document even when the text is equal.
/// The upstream editor supplies layout and selection through its public APIs;
/// its private input client must be disabled by mounting it read-only.
class SqlEditorInput with TextInputClient, DeltaTextInputClient {
  SqlEditorInput({
    required SqlEditorController controller,
    required FocusNode focusNode,
    required SqlEditorGeometry geometry,
    required bool readOnly,
    required int viewId,
    required Brightness keyboardAppearance,
  }) : _controller = controller,
       _focus = focusNode,
       _geometry = geometry,
       _readOnly = readOnly,
       _viewId = viewId,
       _brightness = keyboardAppearance {
    _listen();
  }

  SqlEditorController _controller;
  FocusNode _focus;
  SqlEditorGeometry _geometry;
  bool _readOnly, _disposed = false, _applying = false;
  bool _openScheduled = false, _closedByPlatform = false;
  int _viewId;
  Brightness _brightness;
  TextInputConnection? _connection;
  _InputWindow? _window;
  TextEditingValue? _lastKnownRemote;
  int _rejectedDeltas = 0;
  int get rejectedDeltas => _rejectedDeltas;
  bool get attached => _connection?.attached == true;

  void _listen() {
    _controller.addListener(_editorChanged);
    _focus.addListener(_focusChanged);
    _geometry.addListener(_sendGeometry);
    _scheduleOpen();
  }

  void update({
    required SqlEditorController controller,
    required FocusNode focusNode,
    required SqlEditorGeometry geometry,
    required bool readOnly,
    required int viewId,
    required Brightness keyboardAppearance,
  }) {
    if (_disposed) return;
    if (identical(controller, _controller) &&
        identical(focusNode, _focus) &&
        identical(geometry, _geometry) &&
        readOnly == _readOnly &&
        viewId == _viewId &&
        keyboardAppearance == _brightness) {
      return;
    }
    final retiresOwner =
        !identical(controller, _controller) ||
        !identical(focusNode, _focus) ||
        viewId != _viewId ||
        !_readOnly && readOnly;
    if (!retiresOwner && readOnly == _readOnly) {
      // Appearance and layout keep the same logical/native edit owner. Updating
      // public configuration must not terminate or restart an active preedit.
      if (!identical(geometry, _geometry)) {
        _geometry.removeListener(_sendGeometry);
        _geometry = geometry;
        _geometry.addListener(_sendGeometry);
      }
      final appearanceChanged = keyboardAppearance != _brightness;
      _brightness = keyboardAppearance;
      if (appearanceChanged && attached) {
        _connection!.updateConfig(_configuration());
      }
      _sendGeometry();
      return;
    }
    _controller.removeListener(_editorChanged);
    _focus.removeListener(_focusChanged);
    _geometry.removeListener(_sendGeometry);
    _close();
    if (retiresOwner) _finishComposition(_controller);
    if (_disposed) return;
    _controller = controller;
    _focus = focusNode;
    _geometry = geometry;
    _readOnly = readOnly;
    _viewId = viewId;
    _brightness = keyboardAppearance;
    _closedByPlatform = false;
    _listen();
  }

  void _editorChanged() {
    if (_disposed || _applying) return;
    // Closing immediately invalidates the platform's old client ID. Reopening
    // waits until notification dispatch has finished; it never edits the text.
    _close();
    _scheduleOpen();
  }

  void _focusChanged() {
    if (_disposed) return;
    _closedByPlatform = false;
    if (!_focus.hasFocus || _readOnly) {
      _close();
      _finishComposition(_controller);
    } else {
      _scheduleOpen();
    }
  }

  void requestKeyboard() {
    if (_disposed || _readOnly) return;
    _closedByPlatform = false;
    _focus.requestFocus();
    _scheduleOpen();
  }

  TextInputConfiguration _configuration() => TextInputConfiguration(
    viewId: _viewId,
    inputType: TextInputType.multiline,
    inputAction: TextInputAction.newline,
    enableDeltaModel: true,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    smartDashesType: SmartDashesType.disabled,
    smartQuotesType: SmartQuotesType.disabled,
    keyboardAppearance: _brightness,
  );

  void _scheduleOpen() {
    if (_disposed || _openScheduled || _readOnly || _closedByPlatform) return;
    _openScheduled = true;
    scheduleMicrotask(() {
      _openScheduled = false;
      if (_disposed || _readOnly || _closedByPlatform || !_focus.hasFocus) {
        return;
      }
      if (!attached) {
        _connection = TextInput.attach(this, _configuration());
        _lastKnownRemote = null;
      }
      _synchronize();
      _connection?.show();
    });
  }

  void _close() {
    _window = null;
    _lastKnownRemote = null;
    _connection?.close();
    _connection = null;
  }

  /// Retiring a platform owner commits its accepted preedit; it never removes
  /// source text. A normal synchronization close deliberately keeps composition.
  /// The retained revision prevents deferred cleanup from touching a newer edit.
  void _finishComposition(SqlEditorController owner, {bool deferred = false}) {
    final accepted = owner.value;
    if (!owner.isComposing) return;
    void finish() {
      if (!identical(owner.value, accepted) || !owner.isComposing) return;
      try {
        owner.clearComposing();
      } on SqlEditorException catch (failure) {
        // A document may close before deferred input-view cleanup runs.
        if (failure.code != SqlEditorFailure.disposed) rethrow;
      }
    }

    if (deferred ||
        SchedulerBinding.instance.schedulerPhase ==
            SchedulerPhase.persistentCallbacks) {
      scheduleMicrotask(finish);
      return;
    }
    try {
      finish();
    } on SqlEditorException catch (failure) {
      // Disposal/owner handoff can originate inside a controller notification.
      // Finish once after that synchronous publication has ended, still fenced
      // by the captured immutable owner, without another notification cycle.
      if (failure.code != SqlEditorFailure.reentrantMutation) rethrow;
      scheduleMicrotask(finish);
    }
  }

  void _synchronize({bool force = false}) {
    if (_disposed || !attached || _readOnly || !_focus.hasFocus) return;
    final window = _InputWindow.capture(_controller);
    _window = window;
    // A native update already describes the platform state. Echoing an equal
    // accepted preedit back into the IME is unnecessary. Always refresh the
    // owned window even when no platform correction is required.
    if (force || window.remote != _lastKnownRemote) {
      _connection!.setEditingState(window.remote);
    }
    // Keep the current owned window's strings rather than an obsolete native
    // input value after a document/window transformation.
    _lastKnownRemote = window.remote;
    _sendGeometry();
  }

  bool _owns(_InputWindow window) =>
      !_disposed &&
      !_readOnly &&
      _focus.hasFocus &&
      attached &&
      identical(_window, window) &&
      identical(_controller.value, window.owner);

  @override
  TextEditingValue? get currentTextEditingValue => _window?.remote;
  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    final window = _window;
    if (window == null || !_owns(window)) return;
    if (deltas.length > 256) {
      _refuse(SqlEditorFailure.workLimit);
      return;
    }
    var next = window.remote;
    var workUnits = 0;
    final verified = <(TextEditingValue, TextEditingValue, _NativeChange)>[];
    try {
      for (final delta in deltas) {
        if (delta.oldText != next.text || !_validDelta(delta)) {
          _refuse();
          return;
        }
        final change = _NativeChange.fromDelta(delta);
        if (next.text.length -
                (change.end - change.start) +
                change.text.length >
            SqlSource.maxUnits) {
          _refuse(SqlEditorFailure.documentLimit);
          return;
        }
        workUnits += next.text.length * 2 + change.text.length;
        if (workUnits > 32 * 1024 * 1024) {
          _refuse(SqlEditorFailure.workLimit);
          return;
        }
        final previous = next;
        next = delta.apply(next);
        if (!_validValue(next)) {
          _refuse();
          return;
        }
        verified.add((previous, next, change));
      }
    } on ArgumentError {
      _refuse();
      return;
    }
    _apply(window, verified);
  }

  /// Flutter also exposes a complete editing-state method. It uses the same
  /// current connection/window owner and application path, never a second model.
  @override
  void updateEditingValue(TextEditingValue value) {
    final window = _window;
    if (window == null || !_owns(window)) return;
    if (value.text.length > SqlSource.maxUnits) {
      _refuse(SqlEditorFailure.documentLimit);
      return;
    }
    if (!_validValue(value)) {
      _refuse();
      return;
    }
    final previous = window.remote;
    if (previous.text == value.text) {
      _apply(window, [(previous, value, const _NativeChange(0, 0, '', false))]);
      return;
    }
    // A complete state has no explicit edit span. Keep its unchanged context
    // outside the old/new selections; unlike delta input this is a complete
    // current-window replacement, not evidence about a previous client.
    var prefix = 0;
    final beforeSelection = math.min(
      previous.selection.start,
      value.selection.start,
    );
    while (prefix < beforeSelection &&
        prefix < previous.text.length &&
        prefix < value.text.length &&
        previous.text.codeUnitAt(prefix) == value.text.codeUnitAt(prefix)) {
      prefix++;
    }
    var suffix = 0;
    final afterSelection = math.min(
      previous.text.length - previous.selection.end,
      value.text.length - value.selection.end,
    );
    while (suffix < afterSelection &&
        suffix < previous.text.length - prefix &&
        suffix < value.text.length - prefix &&
        previous.text.codeUnitAt(previous.text.length - suffix - 1) ==
            value.text.codeUnitAt(value.text.length - suffix - 1)) {
      suffix++;
    }
    _apply(window, [
      (
        previous,
        value,
        _NativeChange(
          prefix,
          previous.text.length - suffix,
          value.text.substring(prefix, value.text.length - suffix),
          true,
        ),
      ),
    ]);
  }

  static bool _validValue(TextEditingValue value) =>
      value.text.length <= SqlSource.maxUnits &&
      value.selection.isValid &&
      value.selection.start <= value.text.length &&
      value.selection.end <= value.text.length &&
      (value.composing == TextRange.empty ||
          value.composing.isValid && value.composing.end <= value.text.length);

  static bool _validDelta(TextEditingDelta delta) {
    final length = delta.oldText.length;
    if (length > SqlSource.maxUnits) return false;
    bool range(TextRange value) => value.isValid && value.end <= length;
    if (delta is TextEditingDeltaInsertion) {
      return delta.insertionOffset >= 0 &&
          delta.insertionOffset <= length &&
          delta.textInserted.length <= SqlSource.maxUnits;
    }
    if (delta is TextEditingDeltaDeletion) return range(delta.deletedRange);
    if (delta is TextEditingDeltaReplacement) {
      return range(delta.replacedRange) &&
          delta.replacementText.length <= SqlSource.maxUnits;
    }
    return delta is TextEditingDeltaNonTextUpdate;
  }

  void _apply(
    _InputWindow window,
    List<(TextEditingValue, TextEditingValue, _NativeChange)> updates,
  ) {
    if (!_owns(window)) return;
    _lastKnownRemote = updates.isEmpty ? window.remote : updates.last.$2;
    _applying = true;
    var rejected = false;
    try {
      // Validate the entire platform chain before entering one owned undo
      // transaction. Explicit delta spans retain repeated-character insertion
      // positions and never copy unrelated primary text into another caret.
      _controller.runRevocableOp(() {
        for (final (previous, next, change) in updates) {
          final owner = _controller.value;
          final int start, end, anchor;
          if (change.editsText) {
            start =
                _controller.offsetForPosition(owner.selection.start) +
                change.start -
                previous.selection.start;
            end =
                _controller.offsetForPosition(owner.selection.end) +
                change.end -
                previous.selection.end;
            anchor = change.start + change.text.length;
          } else {
            start = _controller.offsetForPosition(owner.selection.extent);
            end = start;
            anchor = previous.selection.extentOffset;
          }
          final composing =
              next.composing.isValid && !next.composing.isCollapsed
              ? SqlNativeComposingRange(
                  start: next.composing.start - anchor,
                  end: next.composing.end - anchor,
                )
              : null;
          final accepted = _controller.applyNativeEdit(
            expectedOwner: owner,
            start: start,
            end: end,
            replacement: change.text,
            selectionDelta: next.selection.baseOffset - anchor,
            extentDelta: next.selection.extentOffset - anchor,
            composingDeltas: composing,
          );
          if (!accepted) {
            _rejectedDeltas++;
            rejected = true;
            return;
          }
        }
      });
    } on SqlEditorException {
      // The controller owns typed rejection and retains the accepted draft.
      _rejectedDeltas++;
      rejected = true;
    } finally {
      _applying = false;
      _synchronize(force: rejected);
    }
  }

  void _refuse([SqlEditorFailure? reason]) {
    _rejectedDeltas++;
    try {
      final owner = _window?.owner;
      if (reason != null && owner != null) {
        _controller.rejectNativeInput(expectedOwner: owner, reason: reason);
      }
    } on SqlEditorException {
      // Unhandled typed input rejection remains observable through this client;
      // mounted workbench surfaces install the controller's localized handler.
    } finally {
      _synchronize(force: true);
    }
  }

  void _sendGeometry() {
    final connection = _connection, bounds = _geometry.viewport;
    if (_disposed || connection?.attached != true || bounds == null) return;
    connection!.setEditableSizeAndTransform(
      bounds.size,
      Matrix4.translationValues(bounds.left, bounds.top, 0),
    );
    final caret = _geometry.caret(_controller.selection.extent);
    if (caret != null) connection.setCaretRect(caret.shift(-bounds.topLeft));
    final composing = _controller.composing;
    if (!composing.isValid || composing.isCollapsed) return;
    Rect? box;
    for (final paragraph in _geometry.paragraphs) {
      if (paragraph.index != _controller.selection.baseIndex) continue;
      for (final rect in paragraph.getRangeRects(composing)) {
        final local = rect.shift(paragraph.offset);
        box = box == null ? local : box.expandToInclude(local);
      }
    }
    if (box != null) connection.setComposingRect(box);
  }

  @override
  void performAction(TextInputAction action) {
    final window = _window;
    if (window == null || !_owns(window)) return;
    // Linux/Windows text deltas (or the desktop keyboard action) own newline
    // insertion. A native newline action must not insert it a second time.
    if (action == TextInputAction.done) {
      _finishComposition(_controller);
    }
  }

  @override
  bool onFocusReceived() {
    requestKeyboard();
    return _focus.hasFocus;
  }

  @override
  void connectionClosed() {
    final connection = _connection;
    if (connection?.attached == true) {
      connection!.connectionClosedReceived();
    }
    _connection = null;
    _window = null;
    _lastKnownRemote = null;
    _closedByPlatform = true;
    if (!_disposed) _finishComposition(_controller);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    // No private platform command is authorized to change a SQL document.
  }
  @override
  void showAutocorrectionPromptRect(int start, int end) {
    // SQL input deliberately disables autocorrection.
  }
  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    // Mobile floating-cursor input is outside the Linux/Windows product scope.
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _controller.removeListener(_editorChanged);
    _focus.removeListener(_focusChanged);
    _geometry.removeListener(_sendGeometry);
    _close();
    // Parent widgets may be unmounting, or a controller may be notifying its
    // listeners. Commit after those owners have released their callbacks.
    _finishComposition(_controller, deferred: true);
  }
}

class _InputWindow {
  const _InputWindow(this.owner, this.start, this.remote);
  final SqlEditorValue owner;
  final int start;
  final TextEditingValue remote;
  static _InputWindow capture(SqlEditorController controller) {
    final owner = controller.value;
    final source = owner.source, selection = owner.selection;
    final base = controller.offsetForPosition(selection.base),
        extent = controller.offsetForPosition(selection.extent);
    final lineIndex = owner.codeLines.index2lineIndex(selection.baseIndex);
    final lineStart = source.starts[lineIndex],
        line = owner.codeLines[selection.baseIndex].text;
    // Reuse existing immutable strings. A normal field is the active line;
    // an explicit cross-line/CRLF-interior selection uses the exact existing
    // document string. Both are hard bounded by the 8M document admission and
    // neither retains a separate selected-text copy outside that owner.
    final withinLine =
        selection.isSameLine &&
        base >= lineStart &&
        extent >= lineStart &&
        base <= lineStart + line.length &&
        extent <= lineStart + line.length;
    final start = withinLine ? lineStart : 0;
    final text = withinLine ? line : source.text, composing = owner.composing;
    final compStart = lineStart + composing.start - start,
        compEnd = lineStart + composing.end - start;
    final region =
        composing.isValid &&
            !composing.isCollapsed &&
            compStart >= 0 &&
            compEnd <= text.length
        ? TextRange(start: compStart, end: compEnd)
        : TextRange.empty;
    return _InputWindow(
      owner,
      start,
      TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: base - start,
          extentOffset: extent - start,
          affinity: selection.extent.affinity,
        ),
        composing: region,
      ),
    );
  }
}

class _NativeChange {
  const _NativeChange(this.start, this.end, this.text, this.editsText);
  final int start, end;
  final String text;
  final bool editsText;
  factory _NativeChange.fromDelta(TextEditingDelta delta) {
    if (delta is TextEditingDeltaInsertion) {
      return _NativeChange(
        delta.insertionOffset,
        delta.insertionOffset,
        delta.textInserted,
        true,
      );
    }
    if (delta is TextEditingDeltaDeletion) {
      return _NativeChange(
        delta.deletedRange.start,
        delta.deletedRange.end,
        '',
        true,
      );
    }
    if (delta is TextEditingDeltaReplacement) {
      return _NativeChange(
        delta.replacedRange.start,
        delta.replacedRange.end,
        delta.replacementText,
        true,
      );
    }
    return const _NativeChange(0, 0, '', false);
  }
}
