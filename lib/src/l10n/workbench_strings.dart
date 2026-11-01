import 'package:flutter/widgets.dart';
import '../backend/generated/busydata.pb.dart' as rpc;
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_en.dart';
import '../features/workspace/workbench_model.dart'
    show CapturedWorkbenchTarget;

AppLocalizations strings(BuildContext context) =>
    AppLocalizations.of(context) ?? AppLocalizationsEn();

String workbenchObjectType(
  BuildContext context,
  rpc.ObjectKind kind, [
  rpc.ObjectSubtype subtype = rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
]) {
  final l = strings(context);
  return switch (subtype) {
    rpc.ObjectSubtype.PARTITIONED_TABLE => l.partitionedTable,
    rpc.ObjectSubtype.FOREIGN_TABLE => l.foreignTable,
    rpc.ObjectSubtype.MATERIALIZED_VIEW => l.materializedView,
    rpc.ObjectSubtype.FUNCTION => l.functionObject,
    rpc.ObjectSubtype.PROCEDURE => l.procedureObject,
    _ => switch (kind) {
      rpc.ObjectKind.CATALOG => l.databases,
      rpc.ObjectKind.SCHEMA => l.schema,
      rpc.ObjectKind.TABLE => l.tables,
      rpc.ObjectKind.VIEW => l.views,
      rpc.ObjectKind.SEQUENCE => l.sequences,
      rpc.ObjectKind.TYPE => l.metadataType,
      rpc.ObjectKind.ROUTINE => l.routines,
      rpc.ObjectKind.COLUMN => l.columns,
      rpc.ObjectKind.INDEX => l.indexes,
      rpc.ObjectKind.CONSTRAINT => l.constraints,
      rpc.ObjectKind.FOREIGN_KEY => l.foreignKeys,
      rpc.ObjectKind.TRIGGER => l.triggers,
      _ => l.unavailable,
    },
  };
}

({String label, String value}) workbenchMetadataProperty(
  BuildContext context,
  rpc.ObjectKind kind,
  String key,
  String value, {
  bool nativeDefinition = false,
}) {
  final l = strings(context);
  bool? flag(String raw) => switch (raw.toUpperCase()) {
    'TRUE' || 'T' || 'YES' || '1' => true,
    'FALSE' || 'F' || 'NO' || '0' => false,
    _ => null,
  };
  final generated =
      key == 'generated' &&
      (nativeDefinition || flag(value) == null && value.isNotEmpty);
  final label = switch (key) {
    'column' => l.metadataColumn,
    'ordinal' => l.metadataPosition,
    'columnCount' || 'index_columns' => l.columns,
    'reference_columns' => l.metadataReferencedColumn,
    'accessible' => l.available,
    'startValue' => l.metadataStartValue,
    'minValue' => l.metadataMinimumValue,
    'maxValue' => l.metadataMaximumValue,
    'increment' => l.metadataIncrement,
    'cycle' => l.metadataCycle,
    'cacheSize' => l.metadataCacheSize,
    'lastValue' || 'lastValueAvailability' => l.metadataLastValue,
    'previewAvailability' => l.viewDetails,
    'nonUnique' => l.metadataUnique,
    'jdbcType' => l.metadataJdbcType,
    'autoIncrement' => l.metadataAutoIncrement,
    'referencedColumn' => l.metadataReferencedColumn,
    'referencedSchema' => l.referencedSchema,
    'referencedTable' => l.referencedTable,
    'remarks' || 'comment' => l.metadataComment,
    'type' => kind == rpc.ObjectKind.COLUMN ? l.columnType : l.metadataType,
    'defaultNamespace' => l.defaultNamespace,
    'event' => l.metadataEvent,
    'specificName' => l.metadataSpecificName,
    'options' || 'createOptions' => l.metadataOptions,
    'inheritance' => l.metadataInheritance,
    'nullable' => l.nullable,
    'default' => l.defaultExpression,
    'generated' => generated ? l.generatedExpression : l.generatedColumn,
    'special' => l.identityColumn,
    'engine' => l.storageEngine,
    'collation' => l.columnCollationProperty,
    'rowFormat' => l.rowFormat,
    'remarksAvailability' || 'definitionAvailability' => l.viewDetails,
    _ => key,
  };
  String displayed = value;
  if (const {
        'nullable',
        'accessible',
        'cycle',
        'autoIncrement',
        'nonUnique',
        'inheritance',
        'security_barrier',
        'security_invoker',
        'defaultNamespace',
      }.contains(key) ||
      key == 'generated' && !generated) {
    final known = flag(value);
    displayed = value.toLowerCase() == 'unsupported'
        ? l.unsupportedLabel
        : value.toLowerCase() == 'unavailable'
        ? l.unavailable
        : known == null
        ? l.unknownState
        : (key == 'nonUnique' ? !known : known)
        ? l.yes
        : l.no;
  } else if (key == 'previewAvailability' && value.startsWith('truncated')) {
    displayed = l.partial;
  } else if (key == 'lastValueAvailability' && value == 'unavailable') {
    displayed = l.unknownState;
  } else if (key == 'type' && kind == rpc.ObjectKind.CONSTRAINT) {
    displayed = switch (value.toUpperCase()) {
      'P' || 'PRIMARY KEY' => l.primaryKey,
      'U' || 'UNIQUE' => l.uniqueConstraint,
      'F' || 'FOREIGN KEY' => l.foreignKey,
      'C' || 'CHECK' => l.checkConstraint,
      _ => value,
    };
  } else if (key == 'type' && kind == rpc.ObjectKind.ROUTINE) {
    displayed = switch (value.toUpperCase()) {
      'F' || 'FUNCTION' => l.functionObject,
      'P' || 'PROCEDURE' => l.procedureObject,
      _ => value,
    };
  } else if (key == 'definitionAvailability' && value == 'available') {
    displayed = l.available;
  } else if (key == 'definitionAvailability' &&
      value == 'permission-or-language-unavailable') {
    displayed = l.unavailable;
  }
  return (label: label, value: displayed);
}

String workbenchMetadataAvailability(
  BuildContext context,
  String state, {
  bool empty = false,
}) {
  final l = strings(context);
  if (state.startsWith(
    'limited: catalog byte/row budget reached; narrow the object scope',
  )) {
    return state.contains('; Persistent objects in the live context;')
        ? '${l.metadataLimitScope} ${l.metadataSessionScope}'
        : l.metadataLimitScope;
  }
  return switch (state) {
    'available' =>
      empty ? strings(context).availableEmpty : strings(context).available,
    'Captured native definition' => strings(context).metadataDefinitionCaptured,
    'Persistent objects in the current database context; temporary/session-local objects remain in console navigation' =>
      l.metadataPersistentScope,
    'Persistent objects in the live context; busy/idle-manual console-local objects require a session refresh after execution' =>
      l.metadataSessionScope,
    'Definition unavailable in the captured metadata' => strings(
      context,
    ).metadataDefinitionUnavailable,
    'Captured object has no supported native definition' => strings(
      context,
    ).metadataDefinitionUnsupported,
    'Connect this connection explicitly to inspect metadata' => strings(
      context,
    ).notConnected,
    _ => state,
  };
}

String workbenchCapturedOwner(
  BuildContext context,
  CapturedWorkbenchTarget target,
) =>
    '${target.ownerTitle} · ${target.sessionId ?? strings(context).disconnected}';

String workbenchPredicate(BuildContext context, rpc.ValuePredicate predicate) =>
    switch (predicate) {
      rpc.ValuePredicate.EQUAL => strings(context).equals,
      rpc.ValuePredicate.NOT_EQUAL => strings(context).notEqual,
      rpc.ValuePredicate.LESS => strings(context).lessThan,
      rpc.ValuePredicate.GREATER => strings(context).greaterThan,
      rpc.ValuePredicate.IS_NULL => strings(context).isNull,
      rpc.ValuePredicate.IS_NOT_NULL => strings(context).isNotNull,
      _ => strings(context).unknownState,
    };

String workbenchTargetDescription(
  BuildContext context,
  CapturedWorkbenchTarget target,
) {
  final profile = target.profile,
      session = target.session,
      l = strings(context);
  final transaction = workbenchSessionState(context, session);
  return '${workbenchCapturedOwner(context, target)}\n${profile?.name ?? l.selectTarget} · ${profile == null ? '' : workbenchEnvironment(context, profile.environment)} · ${profile?.host ?? ''}:${profile?.port ?? ''}/${profile?.database ?? ''}\n${session?.currentCatalog ?? ''}/${session?.currentSchema ?? ''} · $transaction${profile?.readOnly == true ? ' · ${l.readOnlyPolicy}' : ''}';
}

/// A working-surface caption; the precise captured session remains available
/// in reviews and diagnostic tooltips through [workbenchTargetDescription].
String workbenchTargetCaption(
  BuildContext context,
  CapturedWorkbenchTarget target,
) {
  final profile = target.profile,
      session = target.session,
      l = strings(context);
  return [
    [
      profile?.name ?? l.selectTarget,
      session?.currentCatalog ?? profile?.database ?? '',
      session?.currentSchema ?? '',
    ].where((value) => value.isNotEmpty).join(' / '),
    if (profile != null) workbenchEnvironment(context, profile.environment),
    workbenchSessionState(context, session),
    if (profile?.readOnly == true) l.readOnlyPolicy,
  ].join(' · ');
}

String workbenchSessionState(BuildContext context, rpc.SessionInfo? session) {
  final l = strings(context);
  if (session == null ||
      session.transaction == rpc.TransactionState.DISCONNECTED) {
    return l.disconnected;
  }
  if (session.transaction == rpc.TransactionState.UNKNOWN_TRANSACTION) {
    return l.outcomeUnknown;
  }
  final state = switch (session.transaction) {
    rpc.TransactionState.ACTIVE => l.activeTransaction,
    rpc.TransactionState.FAILED_TRANSACTION => l.failedTransaction,
    _ => l.idle,
  };
  return '${session.autoCommit ? l.autoCommit : l.manualTransaction}${state == l.idle ? '' : ' · $state'}';
}

String workbenchJobState(BuildContext context, rpc.JobState state) =>
    switch (state) {
      rpc.JobState.QUEUED => strings(context).queued,
      rpc.JobState.EXECUTING ||
      rpc.JobState.FETCHING => strings(context).running,
      rpc.JobState.CANCELLING => strings(context).cancelRequested,
      rpc.JobState.COMPLETED => strings(context).completed,
      rpc.JobState.CANCELLED => strings(context).cancelled,
      rpc.JobState.UNKNOWN_OUTCOME => strings(context).outcomeUnknown,
      _ => strings(context).failed,
    };
String workbenchEnvironment(
  BuildContext context,
  rpc.Environment environment,
) => switch (environment) {
  rpc.Environment.PRODUCTION => strings(context).production,
  rpc.Environment.STAGING => strings(context).staging,
  _ => strings(context).development,
};

String workbenchToolLabel(BuildContext context, rpc.ToolKind kind) {
  final l = strings(context);
  return switch (kind) {
    rpc.ToolKind.EXPLAIN => l.explain,
    rpc.ToolKind.EXPLAIN_ANALYZE => l.explainAnalyze,
    rpc.ToolKind.ACTIVITY => l.sessionsAndLocks,
    rpc.ToolKind.LOCKS => l.locks,
    rpc.ToolKind.STATISTICS => l.statistics,
    rpc.ToolKind.QUERY_STATISTICS => l.queryStatistics,
    rpc.ToolKind.INDEX_DIAGNOSTICS => l.indexDiagnostics,
    rpc.ToolKind.ROLES => l.usersAndRoles,
    rpc.ToolKind.GRANTS => l.grants,
    rpc.ToolKind.DEFINITION => l.definition,
    rpc.ToolKind.SNAPSHOT => l.saveSnapshot,
    rpc.ToolKind.IMPORT_CSV || rpc.ToolKind.IMPORT_JSON => l.importData,
    rpc.ToolKind.EXPORT_RESULT => l.exportRetained,
    rpc.ToolKind.EXPORT_QUERY => l.exportSql,
    rpc.ToolKind.DUMP => l.backup,
    rpc.ToolKind.RESTORE => l.restore,
    rpc.ToolKind.CANCEL_ACTIVITY => l.cancel,
    rpc.ToolKind.TERMINATE_ACTIVITY => l.terminateActivity,
    _ => l.jobs,
  };
}

String workbenchDraftState(BuildContext context, String state) =>
    switch (state) {
      'STAGED' => strings(context).pendingChange,
      'APPLYING' =>
        '${strings(context).running} · ${strings(context).applyAndCommit}',
      'COMMITTED' => strings(context).completed,
      'UNKNOWN_OUTCOME' => strings(context).outcomeUnknown,
      _ => strings(context).unknownState,
    };

String workbenchEngine(rpc.Engine engine) => switch (engine) {
  rpc.Engine.POSTGRESQL => 'PostgreSQL',
  rpc.Engine.MYSQL => 'MySQL',
  rpc.Engine.MARIADB => 'MariaDB',
  _ => engine.name,
};
