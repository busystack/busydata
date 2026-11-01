import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import '../../l10n/workbench_strings.dart';

/// Only display labels change; profile IDs, names and selection are untouched.
Map<String, String> connectionDisplayNames(
  BuildContext context,
  Iterable<(String, String)> sources,
) {
  final groups = <String, List<String>>{};
  for (final (id, name) in sources) {
    final label = name.trim().isEmpty ? strings(context).newConnection : name;
    (groups[label] ??= []).add(id);
  }
  final numbers = NumberFormat.decimalPattern(strings(context).localeName);
  return {
    for (final group in groups.entries)
      for (final (index, id) in group.value.indexed)
        id: group.value.length == 1
            ? group.key
            : '${group.key} · ${numbers.format(index + 1)}',
  };
}
