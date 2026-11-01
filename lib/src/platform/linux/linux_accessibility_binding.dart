import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Linux has one native semantics producer: the owned GTK accessibility host.
/// The public SemanticsOwner tree, listeners and actions remain complete.
mixin LinuxAccessibilitySemanticsOutput on WidgetsBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      LinuxAccessibilityUpdateBuilder();
}

/// Must be initialized before plugins or runApp can create a default binding.
class LinuxAccessibilityBinding extends WidgetsFlutterBinding
    with LinuxAccessibilitySemanticsOutput {
  LinuxAccessibilityBinding._();

  static WidgetsBinding? get initializedBinding {
    final existing = _existingBinding();
    if (existing != null) {
      requireOwnedOutput(existing);
    }
    return existing;
  }

  static WidgetsBinding ensureInitialized() =>
      initializedBinding ?? LinuxAccessibilityBinding._();

  static void requireOwnedOutput(WidgetsBinding binding) {
    if (binding is! LinuxAccessibilitySemanticsOutput) {
      throw StateError(
        'Linux accessibility requires its owned binding before startup.',
      );
    }
  }

  static WidgetsBinding? _existingBinding() {
    // Flutter exposes an instance getter rather than a nullable lookup. Its
    // uninitialized debug getter reports FlutterError; release reports the
    // null assertion's TypeError. Existing or partially initialized bindings
    // must never be replaced by this startup method.
    try {
      return WidgetsBinding.instance;
    } on FlutterError {
      if (BindingBase.debugBindingType() != null) {
        rethrow;
      }
      return null;
    } on TypeError {
      if (kDebugMode) {
        rethrow;
      }
      return null;
    }
  }
}

/// Suppresses only the second, stock Linux projection of the semantics tree.
/// No node, string, attribute or action argument is retained or forwarded.
/// build returns a genuine empty engine update, whose disposal belongs to its
/// caller, and consumes this builder exactly once.
class LinuxAccessibilityUpdateBuilder implements ui.SemanticsUpdateBuilder {
  bool _built = false;

  void _requireOpen() {
    if (_built) {
      throw StateError('Semantics update builder was consumed.');
    }
  }

  @override
  void updateNode({
    required int id,
    required ui.SemanticsFlags flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required int traversalParent,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required ui.Rect rect,
    required String identifier,
    required String label,
    required List<ui.StringAttribute> labelAttributes,
    required String value,
    required List<ui.StringAttribute> valueAttributes,
    required String increasedValue,
    required List<ui.StringAttribute> increasedValueAttributes,
    required String decreasedValue,
    required List<ui.StringAttribute> decreasedValueAttributes,
    required String hint,
    required List<ui.StringAttribute> hintAttributes,
    required String tooltip,
    required ui.TextDirection? textDirection,
    required Float64List transform,
    required Float64List hitTestTransform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
    int headingLevel = 0,
    String linkUrl = '',
    ui.SemanticsRole role = ui.SemanticsRole.none,
    required List<String>? controlsNodes,
    ui.SemanticsValidationResult validationResult =
        ui.SemanticsValidationResult.none,
    ui.SemanticsHitTestBehavior hitTestBehavior =
        ui.SemanticsHitTestBehavior.defer,
    required ui.SemanticsInputType inputType,
    required ui.Locale? locale,
    required String minValue,
    required String maxValue,
  }) {
    _requireOpen();
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) {
    _requireOpen();
  }

  @override
  ui.SemanticsUpdate build() {
    _requireOpen();
    _built = true;
    return ui.SemanticsUpdateBuilder().build();
  }
}
