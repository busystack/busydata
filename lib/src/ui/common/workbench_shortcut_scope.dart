import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'modal_command_boundary.dart';
import 'workbench_shortcut_capture.dart';
import '../../backend/connection_failure.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';

SingleActivator workbenchShortcut(String binding) {
  final parts = binding.split('+'), key = parts.last;
  final trigger = switch (key) {
    'Enter' => LogicalKeyboardKey.enter,
    'Slash' || '/' => LogicalKeyboardKey.slash,
    '1' => LogicalKeyboardKey.digit1,
    _ when RegExp(r'^F([1-9]|1[0-2])$').hasMatch(key) => <LogicalKeyboardKey>[
      LogicalKeyboardKey.f1,
      LogicalKeyboardKey.f2,
      LogicalKeyboardKey.f3,
      LogicalKeyboardKey.f4,
      LogicalKeyboardKey.f5,
      LogicalKeyboardKey.f6,
      LogicalKeyboardKey.f7,
      LogicalKeyboardKey.f8,
      LogicalKeyboardKey.f9,
      LogicalKeyboardKey.f10,
      LogicalKeyboardKey.f11,
      LogicalKeyboardKey.f12,
    ][int.parse(key.substring(1)) - 1],
    _ => LogicalKeyboardKey(key.toLowerCase().codeUnitAt(0)),
  };
  return SingleActivator(
    trigger,
    control: parts.contains('Ctrl'),
    shift: parts.contains('Shift'),
    alt: parts.contains('Alt'),
  );
}

/// One routing policy surrounds both native Explorer and central documents.
/// Dialog routes remain outside this scope and retain ModalCommandBoundary.
class WorkbenchShortcutScope extends StatelessWidget {
  const WorkbenchShortcutScope({
    super.key,
    required this.model,
    required this.child,
  });
  final WorkbenchModel model;
  final Widget child;

  Future<void> invoke(BuildContext context, String binding) async {
    if (WorkbenchShortcutCapture.suppressing ||
        WorkbenchLocalInputBoundary.hasFocus) {
      return;
    }
    final registry = model.commands;
    final command = registry?.commands
        .where((c) => c.shortcut == binding)
        .firstOrNull;
    if (registry == null || command == null) return;
    if ((command.id.startsWith('editor.') || command.id.startsWith('sql.')) &&
        !model.documentFocus.hasFocus) {
      return;
    }
    try {
      final contextual =
          command.id == 'file.new' ||
          command.id == 'view.palette' ||
          command.id.startsWith('object.') ||
          command.id.startsWith('connection.') ||
          command.id.startsWith('schema.');
      await registry.invoke(
        command.id,
        contextual ? model.focusedCommandContext : model.commandContext,
      );
    } catch (error) {
      if (context.mounted) {
        model.updateStatus(
          operationFailureSummary(error, locale: strings(context)),
        );
      }
    }
  }

  void traverse(bool backwards) {
    if (WorkbenchShortcutCapture.suppressing ||
        WorkbenchLocalInputBoundary.hasFocus) {
      return;
    }
    final panes = <FocusNode>[
      if (model.explorerVisible) model.explorerFocus,
      if (model.isSqlActive) model.targetFocus,
      model.documentFocus,
      if (model.globalToolOwner != null)
        model.globalToolFocus
      else if (model.isSqlActive && model.currentJob != null)
        model.outputFocus,
    ];
    final index = panes.indexWhere((pane) => pane.hasFocus);
    final pane = panes[(index + (backwards ? -1 : 1)) % panes.length];
    final remembered = pane is FocusScopeNode ? pane.focusedChild : null;
    final next = remembered?.canRequestFocus == true
        ? remembered
        : pane.traversalDescendants
              .where((node) => node.canRequestFocus && node is! FocusScopeNode)
              .firstOrNull;
    (next ?? pane).requestFocus();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => CallbackShortcuts(
      bindings: {
        for (final binding in model.shortcuts.values)
          workbenchShortcut(binding): () => invoke(context, binding),
        const SingleActivator(LogicalKeyboardKey.f6): () => traverse(false),
        const SingleActivator(LogicalKeyboardKey.f6, shift: true): () =>
            traverse(true),
      },
      child: child,
    ),
  );
}
