import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:re_editor/re_editor.dart';

/// Workbench commands retain ownership of their remappable keys inside the editor.
class WorkbenchEditorShortcuts extends DefaultCodeShortcutsActivatorsBuilder {
  const WorkbenchEditorShortcuts(this.reserved);
  final List<SingleActivator> reserved;
  Set<Object> get reservationKeys => {
    for (final key in reserved)
      (key.trigger, key.control, key.shift, key.alt, key.meta),
  };
  bool sameReservations(WorkbenchEditorShortcuts other) =>
      setEquals(reservationKeys, other.reservationKeys);

  /// Hints come from the same filtered activators dispatched by CodeEditor.
  /// In particular, do not advertise ordinary-field clipboard alternatives
  /// which re_editor does not bind.
  String? labelFor(CodeShortcutType type) {
    final key = build(type)?.whereType<SingleActivator>().firstOrNull;
    if (key == null) return null;
    return [
      if (key.control) 'Ctrl',
      if (key.alt) 'Alt',
      if (key.shift) 'Shift',
      if (key.meta) 'Meta',
      key.trigger.keyLabel.toUpperCase(),
    ].join('+');
  }

  @override
  List<ShortcutActivator>? build(CodeShortcutType type) => super
      .build(type)
      ?.where(
        (candidate) =>
            candidate is! SingleActivator ||
            !reserved.any(
              (key) =>
                  key.trigger == candidate.trigger &&
                  key.control == candidate.control &&
                  key.shift == candidate.shift &&
                  key.alt == candidate.alt &&
                  key.meta == candidate.meta,
            ),
      )
      .toList();
}
