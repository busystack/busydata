import 'package:flutter/semantics.dart';

/// Public layout observations supplied by the render object that owns a
/// semantic text node. Registrations never retain a render object or old tree.
abstract interface class AccessibilityTextGeometryProvider {
  Map<String, Object?>? captureAccessibilityTextGeometry(SemanticsNode node);
}

class AccessibilityTextGeometry {
  AccessibilityTextGeometry._();

  static const maximumBoxes = 4096;
  static final _sources =
      Expando<WeakReference<AccessibilityTextGeometryProvider>>();

  static void register(
    SemanticsNode node,
    AccessibilityTextGeometryProvider source,
  ) {
    _sources[node] = WeakReference(source);
  }

  static void unregister(
    SemanticsNode node,
    AccessibilityTextGeometryProvider source,
  ) {
    if (identical(_sources[node]?.target, source)) _sources[node] = null;
  }

  /// No label lookup, character-width estimate or stale layout fallback.
  static Map<String, Object?>? capture(SemanticsNode node) =>
      _sources[node]?.target?.captureAccessibilityTextGeometry(node);
}
