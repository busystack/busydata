import 'dart:convert';
import '../../backend/generated/busydata.pb.dart';
import 'documents.dart';
import '../results/result_presentation.dart';
import '../results/value_assignments.dart';

enum NamespaceSelectionMode { names, all, pattern }

/// A local folder has no server identity or connection ownership.
class SourceFolder {
  const SourceFolder(this.id, this.name, {this.parentId = ''});
  final String id, name, parentId;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'parent': parentId};
  factory SourceFolder.fromJson(Map<String, dynamic> data) => SourceFolder(
    data['id'] as String,
    data['name'] as String,
    parentId: data['parent'] as String,
  );
}

/// User-authored SQL is local intent, never a server VIEW or execution approval.
class VirtualViewDefinition {
  VirtualViewDefinition({
    required this.id,
    required this.name,
    required this.scope,
    required this.sql,
  }) {
    if (id.isEmpty ||
        id.length > 128 ||
        name.trim().isEmpty ||
        name.length > 128 ||
        name.contains('\u0000') ||
        scope.profileId.isEmpty ||
        scope.profileId.length > 128 ||
        scope.catalog.isEmpty ||
        scope.catalog.length > 1024 ||
        scope.schema.isEmpty ||
        scope.schema.length > 1024 ||
        [
          scope.profileId,
          scope.catalog,
          scope.schema,
        ].any((v) => v.contains('\u0000')) ||
        sql.trim().isEmpty ||
        sql.contains('\u0000') ||
        utf8.encode(sql).length > 16384) {
      throw const FormatException('Invalid or oversized local virtual view');
    }
  }
  final String id, name, sql;
  final DatabaseCreationScope scope;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'profile': scope.profileId,
    'catalog': scope.catalog,
    'schema': scope.schema,
    'sql': sql,
  };
  factory VirtualViewDefinition.fromJson(Map<String, dynamic> data) =>
      VirtualViewDefinition(
        id: data['id'] as String,
        name: data['name'] as String,
        sql: data['sql'] as String,
        scope: DatabaseCreationScope(
          profileId: data['profile'] as String,
          catalog: data['catalog'] as String,
          schema: data['schema'] as String,
        ),
      );
}

/// A display/introspection rule, never a console's connection context.
class NamespaceSelection {
  NamespaceSelection({
    this.mode = NamespaceSelectionMode.names,
    Iterable<String> names = const [],
    Iterable<String> excluded = const [],
    this.pattern = '',
  }) : names = Set.unmodifiable(names),
       excluded = Set.unmodifiable(excluded) {
    if (this.names.length + this.excluded.length > 128 ||
        mode != NamespaceSelectionMode.all && this.excluded.isNotEmpty ||
        [...this.names, ...this.excluded].any(
          (name) =>
              name.isEmpty || name.length > 1024 || name.contains('\u0000'),
        ) ||
        pattern.length > 256) {
      throw const FormatException('Namespace selection exceeds its budget');
    }
    if (mode == NamespaceSelectionMode.pattern) RegExp(pattern, unicode: true);
  }
  final NamespaceSelectionMode mode;
  final Set<String> names, excluded;
  final String pattern;
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'names': names.toList(),
    'pattern': pattern,
    'excluded': excluded.toList(),
  };
  factory NamespaceSelection.fromJson(Map<String, dynamic> data) =>
      NamespaceSelection(
        mode: NamespaceSelectionMode.values.byName(data['mode'] as String),
        names: (data['names'] as List).cast<String>(),
        excluded: (data['excluded'] as List? ?? const []).cast<String>(),
        pattern: data['pattern'] as String,
      );
}

enum WorkbenchDocumentKind {
  sql,
  table,
  structure,
  result,
  comparison,
  diagram,
  administration,
  transfer,
  plan,
}

/// A new object belongs to a creation scope; it does not identify an existing
/// server object or carry permission to apply recovered intentions.
class DatabaseCreationScope {
  const DatabaseCreationScope({
    required this.profileId,
    required this.catalog,
    required this.schema,
  });
  final String profileId, catalog, schema;
  String get key => '$profileId\u0000$catalog\u0000$schema';
  @override
  bool operator ==(Object other) =>
      other is DatabaseCreationScope && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

/// Exact catalog identity. Display names never become mutation proof.
class DatabaseObjectIdentity {
  const DatabaseObjectIdentity({
    required this.profileId,
    required this.catalog,
    required this.schema,
    required this.kind,
    required this.name,
    this.parent = '',
    this.identifier = '',
    this.subtype = ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
  });
  final String profileId, catalog, schema, name, parent, identifier;
  final ObjectKind kind;
  final ObjectSubtype subtype;
  String get key => [
    profileId,
    catalog,
    schema,
    parent,
    '${kind.value}',
    '${subtype.value}',
    name,
    identifier,
  ].join('\u0000');
  String get displayName => identifier.isEmpty ? name : identifier;
  String displayNameFor(Engine? engine) =>
      kind == ObjectKind.ROUTINE &&
          [Engine.MYSQL, Engine.MARIADB].contains(engine)
      ? name
      : displayName;
  String get breadcrumb => displayPath(null);
  String displayPath(Engine? engine) => [
    catalog,
    if (!(kind == ObjectKind.CATALOG && catalog == name) &&
        !([Engine.MYSQL, Engine.MARIADB].contains(engine) && schema == catalog))
      schema,
    parent,
    if (!(kind == ObjectKind.SCHEMA && schema == name) &&
        !(kind == ObjectKind.CATALOG && catalog == name))
      displayNameFor(engine),
  ].where((s) => s.isNotEmpty).join(' / ');
  @override
  bool operator ==(Object other) =>
      other is DatabaseObjectIdentity && key == other.key;
  @override
  int get hashCode => key.hashCode;
}

/// Local state survives widget disposal; it contains no retained row payload.
class DocumentViewState {
  bool acquiringData = false;
  bool metadataRequested = false;
  int metadataRevision = 0;
  String? metadataSessionId;
  String dataError = '';
  String subview = 'structure', output = 'results';
  int structureSection = 4, changeIndex = 0;

  /// Stable metadata identities only, scoped to this owner and section. A null
  /// entry records a removed selection, preventing silent selection replacement.
  final structureSelections = <int, String?>{};
  bool changeSql = false;
  double? editorFraction;
  double editorVertical = 0, editorHorizontal = 0;
  int? rowLimit;
  bool streaming = false;
  ErrorPolicy? errorPolicy;
  List<RowCondition> tableConditions = [];
  List<RowOrder> tableOrder = [];
  final tableQueries = <String, TableQueryState>{};
  final executionOutputs = <String, ExecutionOutputState>{};
  int executionSelectionRevision = 0;
  final results = <String, ResultViewState>{};
}

class ExecutionOutputState {
  ExecutionOutputState(this.output, this.resultId);
  final String output;
  final String? resultId;
}

/// Conditions belong to the submitted execution, including historical snapshots.
class TableQueryState {
  TableQueryState(Iterable<RowCondition> conditions, Iterable<RowOrder> order)
    : conditions = conditions.map((c) => c.deepCopy()).toList(),
      order = order.map((o) => o.deepCopy()).toList();
  final List<RowCondition> conditions;
  final List<RowOrder> order;
}

class ResultViewState {
  final presentation = ResultPresentationState();
  Object? planEvidence;
  int planEvidenceUnits = 0;
  ResultViewInfo? retainedView;
  List<RowCondition> conditions = [];
  List<RowOrder> order = [];
  int selectedRow = 0, selectedColumn = 0, anchorRow = 0, anchorColumn = 0;
  int windowStart = 0;
  double verticalOffset = 0, horizontalOffset = 0;
  final widths = <int, double>{};
  final hiddenColumns = <int>{};
}

/// Safe local reference only. Backend evidence and job/session handles expire.
class RestoredTaskReference {
  const RestoredTaskReference(this.commandId);
  final String commandId;
}

/// Private, bounded intentions; no approval, snapshot, credential or live handle.
class ObjectDesignerDraft {
  final fields = <String, String>{};
  final flags = <String, bool>{};
  final columns = <DesignedColumn>[];
  bool dirty = false;
  Map<String, Object> toJson() => {
    'fields': fields,
    'flags': flags,
    'columns': columns.map((c) => c.writeToJson()).toList(),
    'dirty': dirty,
  };
  int get bytes => utf8.encode(jsonEncode(toJson())).length;
  void validate() {
    if (fields.length > 20 ||
        flags.length > 8 ||
        columns.length > 128 ||
        fields.entries.any(
          (e) => e.key.length > 64 || e.value.contains('\u0000'),
        ) ||
        bytes > 1048576) {
      throw StateError(
        'Object designs share a bounded 1MiB recovery budget; generate and save SQL for larger definitions',
      );
    }
  }

  static ObjectDesignerDraft fromJson(Map<String, dynamic> data) {
    final draft = ObjectDesignerDraft();
    draft.fields.addAll(
      (data['fields'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as String),
      ),
    );
    draft.flags.addAll(
      (data['flags'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v as bool),
      ),
    );
    draft.columns.addAll(
      (data['columns'] as List).map(
        (v) => DesignedColumn.fromJson(v as String),
      ),
    );
    draft.dirty = data['dirty'] == true;
    draft.validate();
    return draft;
  }

  void replace(ObjectDesignerDraft candidate) {
    fields
      ..clear()
      ..addAll(candidate.fields);
    flags
      ..clear()
      ..addAll(candidate.flags);
    columns
      ..clear()
      ..addAll(candidate.columns.map((c) => c.deepCopy()));
    dirty = candidate.dirty;
  }
}

class WorkbenchDocument {
  WorkbenchDocument.sql(this.sql)
    : id = sql!.id,
      kind = WorkbenchDocumentKind.sql,
      title = '',
      purpose = '',
      _profileId = sql.profileId,
      object = null,
      creationScope = null,
      retained = null,
      payload = null;
  WorkbenchDocument({
    required this.id,
    required this.kind,
    required this.title,
    this.purpose = '',
    String? profileId,
    this.object,
    this.creationScope,
    this.retained,
    this.payload,
  }) : sql = null,
       _profileId = profileId;
  final String id, purpose;
  final WorkbenchDocumentKind kind;
  final SqlDocument? sql;
  final DatabaseObjectIdentity? object;
  final DatabaseCreationScope? creationScope;
  final RetainedResult? retained;
  Object? payload;
  String reopenCommandId = '';
  String referenceSchema = '';
  final view = DocumentViewState();
  final designDraft = ObjectDesignerDraft();
  int evidenceUnits = 0;
  Profile? evidenceProfile;
  String title;
  String? _profileId;
  String? get profileId => sql?.profileId ?? _profileId;
  set profileId(String? value) {
    if (sql != null) {
      sql!.profileId = value;
    } else {
      _profileId = value;
    }
  }

  String? _sessionId;
  int revision = 0;
  bool contentDirty = false;
  String get displayTitle => sql?.title ?? title;
  String? get sessionId => sql?.sessionId ?? _sessionId;
  set sessionId(String? value) {
    if (sql != null) {
      sql!.sessionId = value;
    } else {
      _sessionId = value;
      revision++;
    }
  }

  int get version => sql?.version ?? revision;
  bool get dirty => sql?.dirty ?? contentDirty;
}

/// A batch is bound to immutable retained source rows and one physical session.
class OwnedEditBatch {
  OwnedEditBatch(this.ownerId, this.resultId);
  final String ownerId;
  String resultId;
  final changes = <StagedChange>[];
  String? sessionId, schema, table, draftId, documentId;
  int revision = 0;
  Future<void> save = Future<void>.value();
  int pendingRecovery = 0;
  Future<T> trackRecovery<T>(Future<T> request) {
    pendingRecovery++;
    return request.whenComplete(() => pendingRecovery--);
  }

  bool get unresolved =>
      changes.isNotEmpty ||
      draftId != null ||
      saveError != null ||
      pendingRecovery != 0 ||
      applying ||
      outcomeUnknown;
  Object? saveError;
  bool applying = false,
      discarding = false,
      outcomeUnknown = false,
      appliedSnapshot = false;

  /// One final intention per original row. Inserts remain independent.
  void stage(StagedChange change, {Row? original}) {
    if (appliedSnapshot) {
      throw StateError(
        'This is the pre-change snapshot. Refresh explicitly before staging further edits.',
      );
    }
    if (applying || discarding || outcomeUnknown) {
      throw StateError(
        'Reconcile the pending or unknown application before changing this batch',
      );
    }
    if (change.kind == ChangeKind.INSERT) {
      changes.add(change);
      revision++;
      return;
    }
    final index = changes.indexWhere(
      (old) =>
          old.kind != ChangeKind.INSERT && old.sourceRow == change.sourceRow,
    );
    if (index < 0) {
      if (original != null) {
        change.values.removeWhere(
          (ordinal, value) =>
              ordinal > 0 &&
              ordinal <= original.values.length &&
              assignmentValue(value) == original.values[ordinal - 1],
        );
      }
      if (change.kind == ChangeKind.DELETE || change.values.isNotEmpty) {
        changes.add(change);
      }
    } else if (change.kind == ChangeKind.DELETE) {
      changes[index] = change;
    } else {
      final previous = changes[index];
      if (previous.kind == ChangeKind.DELETE) {
        throw StateError('Revert the staged deletion before editing this row');
      }
      previous.values.addAll(change.values);
      if (original != null) {
        previous.values.removeWhere(
          (ordinal, value) =>
              ordinal > 0 &&
              ordinal <= original.values.length &&
              assignmentValue(value) == original.values[ordinal - 1],
        );
        if (previous.values.isEmpty) changes.removeAt(index);
      }
    }
    revision++;
  }
}
