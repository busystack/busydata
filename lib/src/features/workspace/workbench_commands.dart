import 'dart:async';

import '../../backend/generated/busydata.pb.dart';
import 'workbench_documents.dart';

String canonicalWorkbenchShortcut(String binding) {
  if (binding.isEmpty || binding.length > 64) {
    throw ArgumentError('Invalid shortcut');
  }
  final parts = binding.split('+');
  final key = parts.removeLast();
  final trigger = key == '/' ? 'Slash' : key;
  if (!RegExp(
        r'^(?:[A-Z0-9]|Enter|Slash|F(?:[1-9]|1[0-2]))$',
      ).hasMatch(trigger) ||
      parts.any(
        (modifier) => !const {'Ctrl', 'Shift', 'Alt'}.contains(modifier),
      ) ||
      parts.toSet().length != parts.length) {
    throw ArgumentError('Invalid shortcut');
  }
  final result = [
    for (final modifier in ['Ctrl', 'Shift', 'Alt'])
      if (parts.contains(modifier)) modifier,
    trigger,
  ].join('+');
  if (result == 'F6' || result == 'Shift+F6') {
    throw ArgumentError('F6 and Shift+F6 are reserved for pane traversal');
  }
  return result;
}

Map<String, String> validateWorkbenchShortcuts(Map<String, String> bindings) {
  final result = {
    for (final entry in bindings.entries)
      entry.key: canonicalWorkbenchShortcut(entry.value),
  };
  if (result.values.toSet().length != result.length) {
    throw ArgumentError('Command shortcuts collide');
  }
  return result;
}

typedef ExplorerCommandEpoch = ({
  String? sessionId,
  int? contextRevision,
  int? sessionRevision,
});

class WorkbenchCommandContext {
  const WorkbenchCommandContext({
    this.owner,
    this.object,
    this.creationScope,
    this.folderId,
    this.virtualViewId,
    this.virtualView,
    this.virtualSource,
    this.objects = const [],
    this.metadataObject,
    this.profileId,
    this.sessionId,
    this.ownerRevision,
    this.resultId,
    this.jobId,
    this.tableConditions,
    this.tableOrder,
    this.metadataInstance,
    this.metadataConfigurationRevision,
    this.metadataSources = const {},
  });
  final WorkbenchDocument? owner;
  final DatabaseObjectIdentity? object;

  /// A category or namespace can create a query without inventing an object.
  final DatabaseCreationScope? creationScope;
  final String? folderId, virtualViewId;

  /// Immutable local intent plus the saved physical source at invocation.
  /// Neither is persisted as a backend handle or execution approval.
  final VirtualViewDefinition? virtualView;
  final Profile? virtualSource;
  final List<DatabaseObjectIdentity> objects;
  final SchemaObject? metadataObject;
  final String? profileId, sessionId;
  final int? ownerRevision;

  /// The visible retained source/view when this menu or palette was opened.
  final String? resultId;
  final String? jobId;
  final List<RowCondition>? tableConditions;
  final List<RowOrder>? tableOrder;
  final String? metadataInstance;
  final int? metadataConfigurationRevision;
  final Map<String, ExplorerCommandEpoch> metadataSources;
}

class WorkbenchCommand {
  const WorkbenchCommand({
    required this.id,
    required this.label,
    required this.category,
    required this.invoke,
    this.disabledReason,
    this.shortcut,
    this.shortcutKey,
    this.visible,
  });
  final String id, label, category;
  final String? shortcut;
  final String? shortcutKey;
  String? get shortcutLabel => shortcut?.replaceAll('Slash', '/');
  final String? Function(WorkbenchCommandContext)? disabledReason;
  final bool Function(WorkbenchCommandContext)? visible;
  final FutureOr<void> Function(WorkbenchCommandContext) invoke;
}

/// Shared invocation contract for menu, palette, shortcuts and context controls.
class WorkbenchCommandRegistry {
  WorkbenchCommandRegistry(
    Iterable<WorkbenchCommand> commands, {
    this.validateContext,
  }) : commands = List.unmodifiable(commands.take(maximumCommands + 1)) {
    if (this.commands.length > maximumCommands) {
      throw ArgumentError('Command catalog exceeds $maximumCommands entries');
    }
    if (this.commands.map((c) => c.id).toSet().length != this.commands.length) {
      throw ArgumentError('Command IDs must be unique');
    }
    final shortcuts = this.commands
        .map((c) => c.shortcut)
        .whereType<String>()
        .map(canonicalWorkbenchShortcut)
        .toList();
    if (shortcuts.toSet().length != shortcuts.length) {
      throw ArgumentError('Command shortcuts collide');
    }
    if (shortcuts.any((key) => key == 'F6' || key == 'Shift+F6')) {
      throw ArgumentError('F6 and Shift+F6 are reserved for pane traversal');
    }
  }
  static const maximumCommands = 256;
  final List<WorkbenchCommand> commands;
  final void Function(WorkbenchCommandContext)? validateContext;
  Iterable<WorkbenchCommand> visibleCommands(WorkbenchCommandContext context) =>
      commands.where((command) => command.visible?.call(context) ?? true);
  List<WorkbenchCommand> search(String query, WorkbenchCommandContext context) {
    final matched = visibleCommands(context)
        .where(
          (c) => '${c.category} ${c.label}'.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    int rank(WorkbenchCommand c) => c.label.toLowerCase() == query.toLowerCase()
        ? 0
        : c.label.toLowerCase().startsWith(query.toLowerCase())
        ? 1
        : 2;
    matched.sort((a, b) {
      final ranked = rank(a).compareTo(rank(b));
      return ranked != 0
          ? ranked
          : commands.indexOf(a).compareTo(commands.indexOf(b));
    });
    return matched;
  }

  WorkbenchCommand command(String id) => commands.firstWhere((c) => c.id == id);
  Future<void> invoke(String id, WorkbenchCommandContext context) async {
    validateContext?.call(context);
    if (context.ownerRevision != null &&
        context.owner?.version != context.ownerRevision) {
      throw StateError('The command owner changed; select it again');
    }
    final action = command(id);
    final reason = action.disabledReason?.call(context);
    if (reason != null) throw StateError(reason);
    await action.invoke(context);
  }
}
