import 'package:flutter/widgets.dart';
import '../../l10n/workbench_strings.dart';

/// Exact machine states only. Server prose and unknown codes are not rendered.
String resultOperationAvailability(BuildContext context, String code) {
  final l = strings(context);
  return switch (code) {
    'available' => l.available,
    'available-ordinal-text-order' => l.aggregateTextOrder,
    'incompatible-types' => l.aggregateMixedTypes,
    'unsupported-ordering' => l.aggregateUnsupportedOrder,
    'incomplete-metadata' => l.relatedRowsUnavailable,
    'unknown-provenance' || 'ambiguous-provenance' => l.relatedRowsUnavailable,
    'key-not-projected' => l.relatedKeyNotProjected,
    'null-key-component' => l.relatedNullKey,
    'unsupported-target' => l.relatedTargetUnavailable,
    'value-truncated-or-limited' => l.relatedValueLimited,
    'relationship-budget-exceeded' => l.limitReached,
    'denied' => l.permissionDenied,
    'stale' => l.staleContext,
    'cancelled' => l.cancelled,
    _ => l.unavailable,
  };
}
