// Adapted from BusyMark a5ee774, shortcut_capture.dart (Apache-2.0).
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Intercepts before the focus tree and also gates hardware-level dispatch.
/// After capture closes, held keys must be released before normal dispatch.
abstract final class WorkbenchShortcutCapture {
  static Object? _owner;
  static void Function(String)? _onCandidate;
  static VoidCallback? _onCancel;
  static bool _installed = false;
  static bool get suppressing => _installed;

  static void begin(
    Object owner, {
    required void Function(String) onCandidate,
    required VoidCallback onCancel,
  }) {
    if (_owner != null && !identical(_owner, owner)) _onCancel?.call();
    _owner = owner;
    _onCandidate = onCandidate;
    _onCancel = onCancel;
    if (!_installed) {
      _installed = true;
      FocusManager.instance.addEarlyKeyEventHandler(_handle);
      HardwareKeyboard.instance.addHandler(_observeRelease);
    }
  }

  static void end(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _onCandidate = null;
    _onCancel = null;
    _releaseIfIdle();
  }

  static void _releaseIfIdle() {
    if (_owner == null &&
        HardwareKeyboard.instance.logicalKeysPressed.isEmpty &&
        _installed) {
      FocusManager.instance.removeEarlyKeyEventHandler(_handle);
      HardwareKeyboard.instance.removeHandler(_observeRelease);
      _installed = false;
    }
  }

  // Native delivery can omit the focus phase of an already handled release.
  // Observe releases independently of that phase so capture cannot keep command
  // dispatch suppressed after its owner and all held keys have gone away.
  static bool _observeRelease(KeyEvent event) {
    if (event is KeyUpEvent && _owner == null) {
      scheduleMicrotask(_releaseIfIdle);
    }
    return false;
  }

  static KeyEventResult _handle(KeyEvent event) {
    final focused = FocusManager.instance.primaryFocus?.context;
    final composing =
        focused
            ?.findAncestorStateOfType<EditableTextState>()
            ?.widget
            .controller
            .value
            .composing
            .isValid ==
        true;
    if (_owner != null && event is KeyDownEvent && !composing) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _onCancel?.call();
      } else if (workbenchBindingFromEvent(event) case final binding?) {
        _onCandidate?.call(binding);
      }
    }
    // The event that releases the last captured key is still consumed.
    _releaseIfIdle();
    return KeyEventResult.handled;
  }
}

String? workbenchBindingFromEvent(KeyEvent event) {
  final keyboard = HardwareKeyboard.instance;
  if (keyboard.isMetaPressed) return null;
  final name = switch (event.logicalKey) {
    LogicalKeyboardKey.enter => 'Enter',
    LogicalKeyboardKey.slash => 'Slash',
    final key => key.keyLabel.toUpperCase(),
  };
  if (!RegExp(r'^(?:[A-Z0-9]|Enter|Slash|F(?:[1-9]|1[0-2]))$').hasMatch(name)) {
    return null;
  }
  return [
    if (keyboard.isControlPressed) 'Ctrl',
    if (keyboard.isShiftPressed) 'Shift',
    if (keyboard.isAltPressed) 'Alt',
    name,
  ].join('+');
}
