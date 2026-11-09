// Controller ownership for the Windows protected input adapter.
import 'dart:typed_data';
import 'package:flutter/widgets.dart';

typedef SendWindowsSecretState =
    void Function(WindowsSecretEditingSnapshot snapshot);

class WindowsSecretEditingSnapshot {
  WindowsSecretEditingSnapshot(
    this.id,
    this.generation,
    TextEditingValue value, {
    required this.acceptsInput,
  }) : utf16 = Int32List.fromList(value.text.codeUnits).asUnmodifiableView(),
       selection = value.selection;
  final int id, generation;
  final Int32List utf16;
  final TextSelection selection;
  final bool acceptsInput;
}

/// One field's controller ownership. Native messages never address another
/// controller, resurrect a disposed owner, or override newer programmatic edits.
class WindowsSecretEditingSession {
  WindowsSecretEditingSession({
    required this.id,
    required TextEditingController controller,
    required this.send,
  }) : _controller = controller {
    if (id <= 0) throw ArgumentError('Positive field identity required');
    _controller.addListener(_changed);
  }
  final int id;
  final SendWindowsSecretState send;
  TextEditingController _controller;
  int _generation = 0, _serial = 0;
  bool _disposed = false, _applyingNative = false, _acceptsInput = true;
  int get generation => _generation;
  bool get disposed => _disposed;
  WindowsSecretEditingSnapshot get snapshot => WindowsSecretEditingSnapshot(
    id,
    _generation,
    _controller.value,
    acceptsInput: _acceptsInput,
  );

  void synchronize() {
    if (_disposed) return;
    _generation++;
    _serial = 0;
    send(snapshot);
  }

  void _changed() {
    if (!_applyingNative) synchronize();
  }

  void setAdmission(bool acceptsInput) {
    if (_disposed || acceptsInput == _acceptsInput) return;
    _acceptsInput = acceptsInput;
    synchronize();
  }

  void replaceController(TextEditingController controller) {
    if (_disposed || identical(controller, _controller)) return;
    _controller.removeListener(_changed);
    _controller = controller;
    _controller.addListener(_changed);
    synchronize();
  }

  bool acceptNative({
    required int fieldId,
    required int generation,
    required int serial,
    required List<int> utf16,
    required int selectionBase,
    required int selectionExtent,
  }) {
    if (_disposed ||
        !_acceptsInput ||
        fieldId != id ||
        generation != _generation ||
        serial <= _serial) {
      return false;
    }
    if (utf16.any((unit) => unit < 0 || unit > 0xffff) ||
        serial < 1 ||
        selectionBase < -1 ||
        selectionExtent < -1 ||
        selectionBase > utf16.length ||
        selectionExtent > utf16.length ||
        (selectionBase < 0) != (selectionExtent < 0)) {
      throw const FormatException('Invalid native editing state');
    }
    final value = TextEditingValue(
      text: String.fromCharCodes(utf16),
      selection: TextSelection(
        baseOffset: selectionBase,
        extentOffset: selectionExtent,
      ),
    );
    _serial = serial;
    final controller = _controller;
    _applyingNative = true;
    try {
      controller.value = value;
    } finally {
      _applyingNative = false;
    }
    // A parent listener can replace/dispose this owner or normalize its value
    // during notification. Do not discard that newer application intent.
    if (!_disposed &&
        identical(controller, _controller) &&
        controller.value != value) {
      synchronize();
    }
    return true;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _controller.removeListener(_changed);
  }
}
