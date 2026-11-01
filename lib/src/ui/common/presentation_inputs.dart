import 'package:flutter/foundation.dart';

/// Value equality for one bounded presentation slot. Inputs must be immutable
/// values or copies; this key never represents database metadata or approval.
@immutable
class PresentationInputs {
  PresentationInputs(Iterable<Object?> values)
    : values = List<Object?>.unmodifiable(values);

  final List<Object?> values;

  @override
  bool operator ==(Object other) =>
      other is PresentationInputs && listEquals(values, other.values);

  @override
  int get hashCode => Object.hashAll(values);
}
