import '../../backend/tool_admission_requests.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show ResponseFuture, GrpcError, CallOptions;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show FocusNode, FocusScopeNode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:re_editor/re_editor.dart';

import '../../backend/backend_process.dart';
import '../../backend/sql_language_requests.dart';
import '../../backend/connection_failure.dart';
import '../../backend/workbench_failure.dart';
import '../../backend/profile_identity.dart';
import '../../backend/generated/busydata.pbgrpc.dart';
import 'documents.dart';
import '../results/result_presentation.dart'
    show resultColumnPreferenceKey, validResultDisplayFormat;
import 'sql_language_preferences.dart';
export 'sql_language_preferences.dart';
import 'workbench_documents.dart';
export 'workbench_documents.dart';
import 'workbench_commands.dart';
import 'metadata_page.dart';
import 'metadata_revisions.dart';
import 'metadata_reply_stamps.dart';
export 'metadata_revisions.dart';
export 'workbench_commands.dart';
import '../../platform/common/database_secrets.dart';
import '../../l10n/locale_resolution.dart';
import '../../platform/common/output_commit.dart' show OutputDestination;

final workbenchProvider = Provider<WorkbenchModel>(
  (ref) => throw StateError('Workbench must be explicitly bootstrapped'),
);

class WorkbenchModel extends ChangeNotifier {
  WorkbenchModel(
    this.support, {
    this.secrets = const OsDatabaseSecrets(),
    this.restrictLocalPath,
    this.launchBackend = BackendProcess.start,
    this.presentationWrite = atomicWrite,
    this.recoveryWrite,
    DocumentBudget? documentBudget,
  }) : documentBudget = documentBudget ?? DocumentBudget();
  final DocumentBudget documentBudget;
  final DatabaseSecrets secrets;
  final void Function(String, bool)? restrictLocalPath;
  DraftStore get drafts => DraftStore(
    support,
    restrictPath: restrictLocalPath,
    write: recoveryWrite,
  );
  final Directory support;
  final Future<BackendConnection> Function(Directory) launchBackend;
  final Future<void> Function(File, List<int>) presentationWrite;
  final Future<void> Function(File, List<int>)? recoveryWrite;
  BackendConnection? backend;

  /// Optional acceptance instrumentation; values originate in laid-out cells.
  void Function(String resultId, int row, int column, Value value)?
  visibleCellObserver;
  final documents = <SqlDocument>[];
  int _querySequence = 0;
  final appearancePreference = ValueNotifier<(String, String?)>((
    'system',
    null,
  ));
  Future<bool> Function()? reviewSettingsDeparture;
  Future<void> _preferenceMutation = Future<void>.value();
  Future<void> _changePreferences(Future<void> Function() operation) {
    final pending = _preferenceMutation.then((_) => operation());
    _preferenceMutation = pending.catchError((_) {});
    return pending;
  }

  Future<void> saveAppearance(String theme, String? locale) =>
      _changePreferences(() async {
        if (!const {'system', 'light', 'dark'}.contains(theme)) {
          throw ArgumentError.value(theme);
        }
        final normalized = normalizeBusyDataLocaleTag(locale);
        await _savePresentation(
          theme: theme,
          locale: normalized,
          appearance: true,
          acknowledged: () {
            appearancePreference.value = (theme, normalized);
          },
        );
      });
  Future<void> saveShortcut(String key, String assignment) =>
      _changePreferences(() async {
        if (!shortcuts.containsKey(key)) throw ArgumentError.value(key);
        final proposed = validateWorkbenchShortcuts({
          ...shortcuts,
          key: assignment,
        });
        await _savePresentation(
          proposedShortcuts: proposed,
          acknowledged: () {
            shortcuts
              ..clear()
              ..addAll(proposed);
            if (!_disposed) notifyListeners();
          },
        );
      });

  String? _startupScratchId;
  final _unadoptedSqlDrafts = <dynamic>[];
  String? get untouchedStartupScratchId =>
      documents.any(
        (d) =>
            d.id == _startupScratchId &&
            d.path == null &&
            d.editor.text.isEmpty &&
            d.version == 1 &&
            d.profileId == null &&
            d.sessionId == null,
      )
      ? _startupScratchId
      : null;

  /// Only the scratch document created by this launch can be covered by the
  /// start surface. Restored files and drafts, including blank ones, are data.
  bool _startRequested = false;
  void showWelcome() {
    _startRequested = true;
    notifyListeners();
  }

  void showWorkbench() {
    _startRequested = false;
    _startupScratchId = null;
    notifyListeners();
  }

  bool get showStartSurface => _startRequested || _untouchedStart;
  bool get _untouchedStart =>
      _startupScratchId != null &&
      documents.length == 1 &&
      taskDocuments.isEmpty &&
      globalToolOwner == null &&
      document.id == _startupScratchId &&
      document.path == null &&
      document.editor.text.isEmpty &&
      document.version == 1 &&
      document.profileId == null &&
      document.sessionId == null &&
      currentJob == null;

  void newQuery() {
    if (_untouchedStart) {
      _startRequested = false;
      _startupScratchId = null;
      notifyListeners();
    } else {
      _startRequested = false;
      newDocument();
    }
  }

  final _sqlOwners = <String, WorkbenchDocument>{};
  final taskDocuments = <WorkbenchDocument>[];
  final _unadoptedObjectHints = <dynamic>[];
  final _unadoptedTaskHints = <dynamic>[];
  final _unadoptedDesigns = <String, dynamic>{};
  String? activeTaskId;
  WorkbenchDocument? globalToolOwner;
  void showGlobalTool(WorkbenchDocument? owner) {
    if (owner != null) _startRequested = false;
    if (globalToolOwner != null && !identical(globalToolOwner, owner)) {
      documentBudget.auxiliary(globalToolOwner!, 0);
    }
    globalToolOwner = owner;
    notifyListeners();
  }

  final explorerSessions = <String, String>{};
  final namespaceSelections = <String, NamespaceSelection>{};
  int namespaceSelectionRevision = 0;
  bool showAllNamespaces = false;
  bool showEmptyGroups = false;
  final explorerPreferences = <String, bool>{
    'namespaceGroups': true,
    'schemaGroups': true,
    'tableGroups': true,
    'separateRoutines': false,
    'alphabetic': false,
    'virtual': true,
    'comments': false,
  };
  final explorerObjectKinds = <ObjectKind>{...ObjectKind.values};
  final explorerExpanded = <String>{};
  String explorerSelection = '';
  String explorerNameFilter = '';
  String namespaceScopeKey(String profile, String catalog) =>
      '$profile\u0000$catalog';
  NamespaceSelection? namespaceSelection(String profile, String catalog) =>
      namespaceSelections[namespaceScopeKey(profile, catalog)];
  void seedNamespaces(
    String profile,
    String catalog,
    NamespaceSelection selection,
  ) {
    final key = namespaceScopeKey(profile, catalog);
    if (namespaceSelections.containsKey(key) ||
        namespaceSelections.length >= 128) {
      return;
    }
    namespaceSelections[key] = selection;
    namespaceSelectionRevision++;
    unawaited(
      savePresentation().catchError((Object error) {
        if (!_disposed) updateStatus(operationFailureSummary(error));
      }),
    );
  }

  Future<void> selectNamespaces(
    String profile,
    String catalog,
    NamespaceSelection selection, {
    bool Function()? mayAdopt,
  }) async {
    if (mayAdopt?.call() == false) {
      throw StateError('Namespace source is no longer available');
    }
    if (!profiles.any((p) => p.id == profile) ||
        profile.length > 128 ||
        catalog.length > 1024) {
      throw StateError('Namespace source is no longer available');
    }
    final key = namespaceScopeKey(profile, catalog);
    if (!namespaceSelections.containsKey(key) &&
        namespaceSelections.length >= 128) {
      throw StateError('Namespace selection scope budget exhausted');
    }
    final previous = namespaceSelections[key];
    namespaceSelections[key] = selection;
    var written = false;
    try {
      await savePresentation();
      written = true;
      if (mayAdopt?.call() == false) {
        throw StateError('Namespace source is no longer available');
      }
    } catch (_) {
      if (identical(namespaceSelections[key], selection)) {
        if (previous == null) {
          namespaceSelections.remove(key);
        } else {
          namespaceSelections[key] = previous;
        }
        if (written) await savePresentation();
      }
      rethrow;
    }
    namespaceSelectionRevision++;
    notifyListeners();
  }

  final connectionOwners = <String, WorkbenchDocument>{};
  Iterable<WorkbenchDocument> get operationOwners => [
    ...workbenchDocuments,
    ...connectionOwners.values,
  ];
  WorkbenchDocument connectionOwner(Profile profile) =>
      connectionOwners.putIfAbsent(
        profile.id,
        () => WorkbenchDocument(
          id: 'connection:${profile.id}',
          kind: WorkbenchDocumentKind.administration,
          title: profile.name,
          profileId: profile.id,
        ),
      );
  Future<void> connectExplorer(
    Profile profile,
    String password, {
    String sshPassword = '',
    String keyPassphrase = '',
    String tlsKeyPassword = '',
    bool Function()? mayAdopt,
  }) async {
    final owner = connectionOwner(profile);
    await connect(
      profile,
      password,
      targetOwner: owner,
      sshPassword: sshPassword,
      keyPassphrase: keyPassphrase,
      tlsKeyPassword: tlsKeyPassword,
      mayAdopt: mayAdopt,
    );
    if (owner.sessionId != null) {
      explorerSessions[profile.id] = owner.sessionId!;
    }
    notifyListeners();
  }

  Future<void> closeTask(
    WorkbenchDocument owner, {
    bool preserveEdits = false,
    bool resolveSession = false,
  }) async {
    if (!taskDocuments.contains(owner)) return;
    if ((pendingCommands[owner.id] ?? 0) != 0 ||
        _commandOwners.contains(owner.id)) {
      throw StateError(
        'Wait for the document operation acknowledgement before closing',
      );
    }
    if (!closingDocuments.add(owner.id)) {
      throw StateError('Document close is already pending');
    }
    try {
      final batches = editBatches.values
          .where((b) => b.ownerId == owner.id)
          .toList();
      for (final batch in batches) {
        if ((batch.changes.isNotEmpty && !preserveEdits) || batch.applying) {
          throw StateError(
            'Resolve or preserve pending changes before closing',
          );
        }
        await awaitStagedSave(batch: batch);
        if (batch.changes.isNotEmpty && batch.draftId == null) {
          throw StateError(
            'Private edit recovery is unavailable; the document remains open',
          );
        }
      }
      if (owner.sessionId != null &&
          !operationOwners.any(
            (d) => d.id != owner.id && d.sessionId == owner.sessionId,
          )) {
        final process = backend!, id = owner.sessionId!;
        final active = jobs.values
            .where((j) => j.sessionId == id && !terminalJob(j.state))
            .toList();
        if (active.isNotEmpty && !resolveSession) {
          throw StateError(
            'Resolve the active job before closing its final session owner',
          );
        }
        for (final job in active) {
          jobs[job.jobId] = await process.client.cancel(
            JobRequest(context: process.context(), jobId: job.jobId),
          );
        }
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (jobs.values.any(
          (j) => j.sessionId == id && !terminalJob(j.state),
        )) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError(
              'Cancellation acknowledgement is pending; the document remains open',
            );
          }
          await poll();
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        final physicalOwner = sessions[id]?.deepCopy();
        final state = await process.client.session(
          SessionRequest(context: process.context(), sessionId: id),
        );
        _requireSessionSource(process, state, id: id, previous: physicalOwner);
        if ([
          TransactionState.ACTIVE,
          TransactionState.FAILED_TRANSACTION,
        ].contains(state.transaction)) {
          if (!resolveSession) {
            throw StateError('Review transaction cleanup before closing');
          }
          final rollback = SessionRequest(
            context: process.context(),
            sessionId: id,
            action: SessionAction.ROLLBACK,
          );
          rollback.approvalToken = (await process.client.reviewSession(
            rollback,
          )).token;
          final rolledBack = await process.client.session(rollback);
          _requireSessionSource(process, rolledBack, id: id, previous: state);
          sessions[id] = rolledBack;
        } else if (state.transaction == TransactionState.UNKNOWN_TRANSACTION &&
            !resolveSession) {
          throw StateError(
            'Review disconnecting the quarantined session without replay',
          );
        }
        if (!identical(backend, process)) {
          throw StateError(
            'Backend changed during cleanup; the document remains open',
          );
        }
        final disconnect = SessionRequest(
          context: process.context(),
          sessionId: id,
          action: SessionAction.DISCONNECT,
          force: state.transaction == TransactionState.UNKNOWN_TRANSACTION,
        );
        disconnect.approvalToken = (await process.client.reviewSession(
          disconnect,
        )).token;
        final closed = await process.client.session(disconnect);
        _requireSessionSource(
          process,
          closed,
          id: id,
          previous: state,
          disconnectAcknowledgement: true,
        );
        if (closed.transaction != TransactionState.DISCONNECTED) {
          throw StateError(
            'Disconnect was not acknowledged; keep the document open',
          );
        }
        sessions.remove(id);
        owner.sessionId = null;
      }
      await disposeOwnerViews(owner);
      await saveObjectDesigns();
      await savePresentation();
      taskDocuments.remove(owner);
      editBatches.removeWhere((_, batch) => batch.ownerId == owner.id);
      browseReplacements.remove(owner.id);
      documentBudget.auxiliary(owner, 0);
      _retainedViews.remove(owner.id);
      selectedExecutions.remove(owner.id);
      selectedResults.remove(owner.id);
      if (activeTaskId == owner.id) activeTaskId = taskDocuments.lastOrNull?.id;
      notifyListeners();
    } finally {
      closingDocuments.remove(owner.id);
    }
  }

  void shareSession(SqlDocument target, String sessionId) {
    final owner = operationOwners
        .where((owner) => identical(owner.sql, target))
        .firstOrNull;
    if (owner == null) throw StateError('Document owner is unavailable');
    shareSessionOwner(owner, sessionId);
  }

  void shareSessionOwner(WorkbenchDocument target, String sessionId) {
    final session = sessions[sessionId];
    if (!operationOwners.contains(target) ||
        target.sessionId != null ||
        session == null ||
        closingDocuments.contains(target.id) ||
        operationOwners.any(
          (owner) =>
              owner.sessionId == sessionId &&
              closingDocuments.contains(owner.id),
        ) ||
        session.transaction == TransactionState.UNKNOWN_TRANSACTION ||
        session.transaction == TransactionState.DISCONNECTED ||
        session.profile.engine == Engine.POSTGRESQL &&
            target.object != null &&
            target.object!.catalog.isNotEmpty &&
            target.object!.catalog != session.currentCatalog) {
      throw StateError(
        'Session sharing requires a disconnected document and a known live session in its database',
      );
    }
    target.sessionId = sessionId;
    target.profileId = session.profile.id;
    invalidateAnalysis();
    notifyListeners();
  }

  int get defaultRowLimit => _defaultRowLimit;
  ErrorPolicy get defaultErrorPolicy => _defaultErrorPolicy;
  void executionDefaults(int rows, ErrorPolicy policy) {
    _defaultRowLimit = rows;
    _defaultErrorPolicy = policy;
  }

  final favoriteProfiles = <String>{};
  final sourceFolders = <String, SourceFolder>{};
  final sourceFolderMembership = <String, String>{};
  final explorerOrder = <String>[];
  final virtualViews = <String, VirtualViewDefinition>{};
  final _virtualViewDocuments = <String, String>{};
  int localExplorerRevision = 0;

  String folderPath(String id) {
    final names = <String>[];
    final seen = <String>{};
    while (id.isNotEmpty && seen.add(id)) {
      final folder = sourceFolders[id];
      if (folder == null) break;
      names.insert(0, folder.name);
      id = folder.parentId;
    }
    return names.join(' / ');
  }

  bool folderCanMove(String id, String parent) {
    if (parent.isNotEmpty && !sourceFolders.containsKey(parent)) return false;
    final seen = <String>{id};
    var depth = 0;
    while (parent.isNotEmpty) {
      if (!seen.add(parent) || ++depth > 7) return false;
      parent = sourceFolders[parent]?.parentId ?? '';
    }
    // Include the moved subtree in the depth budget.
    int descendants(String current, Set<String> visited) {
      if (!visited.add(current)) return 9;
      var deepest = 0;
      for (final child in sourceFolders.values.where(
        (f) => f.parentId == current,
      )) {
        final height = 1 + descendants(child.id, {...visited});
        if (height > deepest) deepest = height;
      }
      return deepest;
    }

    return depth + descendants(id, {}) < 8;
  }

  Future<void> _localExplorerSave = Future<void>.value();
  Future<void> _changeLocalExplorer(void Function() change) {
    final pending = _localExplorerSave.then((_) async {
      final folders = Map<String, SourceFolder>.of(sourceFolders);
      final membership = Map<String, String>.of(sourceFolderMembership);
      final order = explorerOrder.toList();
      final views = Map<String, VirtualViewDefinition>.of(virtualViews);
      try {
        change();
        if (sourceFolders.length > 64 ||
            sourceFolderMembership.length > 64 ||
            explorerOrder.length > 128 ||
            virtualViews.length > 32 ||
            utf8
                    .encode(
                      jsonEncode(
                        virtualViews.values.map((v) => v.toJson()).toList(),
                      ),
                    )
                    .length >
                32768) {
          throw StateError(
            'Local Explorer objects exceed their storage budget',
          );
        }
        await savePresentation();
      } catch (_) {
        sourceFolders
          ..clear()
          ..addAll(folders);
        sourceFolderMembership
          ..clear()
          ..addAll(membership);
        explorerOrder
          ..clear()
          ..addAll(order);
        virtualViews
          ..clear()
          ..addAll(views);
        rethrow;
      }
      localExplorerRevision++;
      notifyListeners();
    });
    _localExplorerSave = pending.catchError((_) {});
    return pending;
  }

  Future<void> saveSourceFolder(String id, String name, String parent) =>
      _changeLocalExplorer(() {
        if (id.isEmpty ||
            id.length > 128 ||
            name.trim().isEmpty ||
            name.length > 128 ||
            name.contains('\u0000') ||
            name.contains('/') ||
            !folderCanMove(id, parent)) {
          throw const FormatException(
            'Invalid folder name or cyclic/deep folder move',
          );
        }
        if (sourceFolders.values.any(
          (f) => f.id != id && f.parentId == parent && f.name == name.trim(),
        )) {
          throw const FormatException(
            'A folder with this name already exists here',
          );
        }
        sourceFolders[id] = SourceFolder(id, name.trim(), parentId: parent);
      });
  Future<void> createSourceFolderPath(String path, String parent) =>
      _changeLocalExplorer(() {
        final parts = path.split('/').map((name) => name.trim()).toList();
        if (parts.isEmpty ||
            parts.length > 8 ||
            parts.any(
              (name) =>
                  name.isEmpty || name.length > 128 || name.contains('\u0000'),
            )) {
          throw const FormatException('Invalid source folder path');
        }
        for (final name in parts) {
          final existing = sourceFolders.values
              .where((f) => f.parentId == parent && f.name == name)
              .firstOrNull;
          if (existing != null) {
            parent = existing.id;
            continue;
          }
          final id = const Uuid().v4();
          if (!folderCanMove(id, parent)) {
            throw const FormatException('Source folder depth exceeded');
          }
          sourceFolders[id] = SourceFolder(id, name, parentId: parent);
          parent = id;
        }
      });
  Future<void> moveSourceToFolder(String profileId, String folderId) =>
      _changeLocalExplorer(() {
        if (!profiles.any((p) => p.id == profileId) ||
            folderId.isNotEmpty && !sourceFolders.containsKey(folderId)) {
          throw StateError('Source or destination folder is unavailable');
        }
        folderId.isEmpty
            ? sourceFolderMembership.remove(profileId)
            : sourceFolderMembership[profileId] = folderId;
      });
  Future<void> removeSourceFolder(String id) => _changeLocalExplorer(() {
    sourceFolderMembership.removeWhere(
      (profile, _) => !profiles.any((p) => p.id == profile),
    );
    if (sourceFolders.values.any((f) => f.parentId == id) ||
        sourceFolderMembership.containsValue(id)) {
      throw StateError(
        'Move contained sources and folders before removing this folder',
      );
    }
    sourceFolders.remove(id);
    explorerOrder.remove('f:$id');
  });
  List<String> explorerSiblings(String parent) {
    final keys = [
      for (final folder in sourceFolders.values.where(
        (f) => f.parentId == parent,
      ))
        'f:${folder.id}',
      for (final profile in profiles.where(
        (p) => (sourceFolderMembership[p.id] ?? '') == parent,
      ))
        's:${profile.id}',
    ];
    final original = {for (var i = 0; i < keys.length; i++) keys[i]: i};
    keys.sort((a, b) {
      final ai = explorerOrder.indexOf(a), bi = explorerOrder.indexOf(b);
      if (ai >= 0 || bi >= 0) {
        return (ai < 0 ? 129 : ai).compareTo(bi < 0 ? 129 : bi);
      }
      return original[a]!.compareTo(original[b]!);
    });
    return keys;
  }

  Future<void> reorderExplorer(String key, int direction) =>
      _changeLocalExplorer(() {
        final parent = key.startsWith('f:')
            ? sourceFolders[key.substring(2)]?.parentId
            : sourceFolderMembership[key.substring(2)] ?? '';
        if (parent == null || direction.abs() != 1) {
          throw StateError('Unknown folder order');
        }
        final siblings = explorerSiblings(parent),
            index = explorerSiblings(parent).indexOf(key);
        if (index < 0 ||
            index + direction < 0 ||
            index + direction >= siblings.length) {
          return;
        }
        final other = siblings[index + direction];
        siblings[index + direction] = key;
        siblings[index] = other;
        explorerOrder.removeWhere(siblings.contains);
        explorerOrder.addAll(siblings);
      });
  Future<void> saveVirtualView(VirtualViewDefinition definition) =>
      _changeLocalExplorer(() {
        if (!profiles.any((p) => p.id == definition.scope.profileId)) {
          throw StateError('Choose an existing saved source');
        }
        if (virtualViews.values.any(
          (v) =>
              v.id != definition.id &&
              v.scope == definition.scope &&
              v.name == definition.name,
        )) {
          throw const FormatException(
            'A virtual view with this name already exists in this namespace',
          );
        }
        virtualViews[definition.id] = definition;
      });
  Future<void> removeVirtualView(String id) async {
    await _changeLocalExplorer(() {
      virtualViews.remove(id);
    });
    _virtualViewDocuments.remove(id);
  }

  SqlDocument openVirtualView(String id) {
    final view = virtualViews[id];
    final profile = profiles
        .where((p) => p.id == view?.scope.profileId)
        .firstOrNull;
    if (view == null || profile == null) {
      throw StateError('The local definition needs an explicit source binding');
    }
    final existing = documents
        .where((d) => d.id == _virtualViewDocuments[id])
        .firstOrNull;
    final live = sessions[existing?.sessionId];
    final original = live?.profile ?? _sqlOwners[existing?.id]?.evidenceProfile;
    if (existing != null &&
        (original == null || sameConnectionTarget(original, profile)) &&
        existing.editor.text == view.sql &&
        existing.profileId == view.scope.profileId &&
        existing.connectionCatalog == view.scope.catalog &&
        existing.connectionSchema == view.scope.schema &&
        (live == null ||
            live.currentCatalog == view.scope.catalog &&
                live.currentSchema == view.scope.schema)) {
      select(documents.indexOf(existing));
      return existing;
    }
    newDocument(text: view.sql);
    document.profileId = view.scope.profileId;
    document.connectionCatalog = view.scope.catalog;
    document.connectionSchema = view.scope.schema;
    activeOwner.evidenceProfile = profile.deepCopy();
    _virtualViewDocuments[id] = document.id;
    return document;
  }

  double explorerWidth = 300;
  bool explorerVisible = true;
  int explorerTransitionGeneration = 0;
  void setExplorerVisible(bool visible) {
    if (explorerVisible == visible) return;
    explorerVisible = visible;
    explorerTransitionGeneration++;
    notifyListeners();
  }

  final explorerFocus = FocusNode(debugLabel: 'Database Explorer');
  final documentFocus = FocusScopeNode(debugLabel: 'Document content'),
      targetFocus = FocusScopeNode(debugLabel: 'Document target'),
      outputFocus = FocusScopeNode(debugLabel: 'Document output'),
      globalToolFocus = FocusScopeNode(debugLabel: 'Global workbench tool');
  List<WorkbenchDocument> get workbenchDocuments => [
    for (final sql in documents)
      _sqlOwners.putIfAbsent(sql.id, () => WorkbenchDocument.sql(sql)),
    ...taskDocuments,
  ];
  WorkbenchDocument get activeOwner =>
      taskDocuments.where((d) => d.id == activeTaskId).firstOrNull ??
      _sqlOwners.putIfAbsent(
        document.id,
        () => WorkbenchDocument.sql(document),
      );
  bool get isSqlActive => activeOwner.kind == WorkbenchDocumentKind.sql;
  void activateOwner(String id) {
    _startRequested = false;
    final index = documents.indexWhere((d) => d.id == id);
    if (index >= 0) {
      select(index);
      return;
    }
    if (!taskDocuments.any((d) => d.id == id)) return;
    activeTaskId = id;
    invalidateAnalysis();
    notifyListeners();
  }

  WorkbenchDocument openTask(
    WorkbenchDocumentKind kind,
    String title, {
    DatabaseObjectIdentity? object,
    DatabaseCreationScope? creationScope,
    RetainedResult? retained,
    Object? payload,
    String? profileId,
    Profile? evidenceProfile,
    bool reuse = true,
    bool activate = true,
    String purpose = '',
    String? restoredId,
  }) {
    final existing = taskDocuments
        .where(
          (d) =>
              d.kind == kind &&
              d.purpose == purpose &&
              (evidenceProfile == null ||
                  documentMatchesProfile(d, evidenceProfile)) &&
              (object != null
                  ? d.object == object
                  : creationScope != null
                  ? d.creationScope == creationScope
                  : retained != null
                  ? d.retained?.result.resultId == retained.result.resultId
                  : d.title == title && d.profileId == profileId),
        )
        .firstOrNull;
    if (reuse && existing != null) {
      if (activate) activateOwner(existing.id);
      return existing;
    }
    if (taskDocuments.length >= 32) {
      throw StateError(
        'Close a tool document before opening another (32 tool document limit)',
      );
    }
    final owner = WorkbenchDocument(
      id:
          restoredId != null &&
              restoredId.length <= 128 &&
              restoredId.isNotEmpty &&
              !operationOwners.any((d) => d.id == restoredId)
          ? restoredId
          : const Uuid().v4(),
      kind: kind,
      purpose: purpose,
      title: title,
      object: object,
      creationScope: creationScope,
      retained: retained,
      payload: payload,
      profileId: profileId ?? object?.profileId,
    );
    owner.evidenceProfile = evidenceProfile?.deepCopy();
    taskDocuments.add(owner);
    if (activate) activateOwner(owner.id);
    return owner;
  }

  ResultViewState resultView(String resultId, {WorkbenchDocument? owner}) =>
      (owner ?? activeOwner).view.results.putIfAbsent(
        sourceResultId(resultId),
        ResultViewState.new,
      );
  void resizeExplorer(double width) {
    explorerWidth = width.clamp(220, 480);
    notifyListeners();
  }

  WorkbenchCommandRegistry? commands;
  WorkbenchCommandContext? explorerCommandContext;
  DatabaseObjectIdentity? explorerReveal;
  Profile? explorerRevealProfile;
  int explorerRevealRevision = 0;
  bool explorerSourceMatches(DatabaseObjectIdentity object, Profile expected) {
    final actual =
        sessions[explorerSessions[object.profileId]]?.profile ??
        profiles.where((p) => p.id == object.profileId).firstOrNull;
    if (actual == null) return false;
    // Namespace defaults do not identify a physical endpoint. The object
    // already carries its exact database/schema, independently of defaults.
    Profile scoped(Profile profile) =>
        profile.deepCopy()..database = object.catalog;
    return sameConnectionTarget(scoped(actual), scoped(expected));
  }

  void revealInExplorer(
    DatabaseObjectIdentity object, {
    Profile? evidenceProfile,
  }) {
    if (!profiles.any((p) => p.id == object.profileId)) {
      throw StateError('The saved source for this object is unavailable');
    }
    explorerReveal = object;
    explorerRevealProfile = evidenceProfile?.deepCopy();
    explorerRevealRevision++;
    explorerVisible = true;
    notifyListeners();
  }

  WorkbenchCommandContext get focusedCommandContext =>
      explorerFocus.hasFocus && explorerCommandContext != null
      ? explorerCommandContext!
      : commandContext;
  WorkbenchCommandContext get commandContext => WorkbenchCommandContext(
    owner: activeOwner,
    object: activeOwner.object,
    profileId: activeOwner.profileId,
    sessionId:
        activeOwner.sessionId ??
        (activeOwner.object == null
            ? null
            : explorerSessions[activeOwner.profileId]),
    ownerRevision: activeOwner.version,
    resultId: displayResultForOwner(activeOwner)?.resultId,
    jobId: cancellableJobForOwner(activeOwner)?.jobId,
  );
  final profiles = <Profile>[];
  final sessions = <String, SessionInfo>{};
  final _connectionGeneration = <String, int>{};
  final _connectionTails = <String, Future<void>>{};
  final closingDocuments = <String>{};
  final pendingCommands = <String, int>{};
  int get pendingOperations =>
      pendingCommands.values.fold(0, (a, b) => a + b) +
      _commandOwners.length +
      (_recoveryChangePending ? 1 : 0) +
      _connectionTails.length +
      closingDocuments.length +
      _pendingProfileSaves;

  CapturedWorkbenchTarget captureTarget({WorkbenchDocument? owner}) {
    final selectedOwner = owner ?? activeOwner;
    return CapturedWorkbenchTarget.owner(
      backend!,
      selectedOwner,
      selectedOwner.version,
      selectedOwner.sessionId,
      sessions[selectedOwner.sessionId]?.contextRevision ?? Int64.ZERO,
      sessions[selectedOwner.sessionId]?.sessionRevision ?? Int64.ZERO,
      profile:
          selectedOwner.retained?.target.deepCopy() ??
          sessions[selectedOwner.sessionId]?.profile.deepCopy() ??
          selectedOwner.evidenceProfile?.deepCopy() ??
          profiles
              .where((p) => p.id == selectedOwner.profileId)
              .firstOrNull
              ?.deepCopy(),
      session: sessions[selectedOwner.sessionId]?.deepCopy(),
    );
  }

  CapturedWorkbenchTarget captureSessionTarget(String id) {
    final session = sessions[id], process = backend;
    if (id.isEmpty || session == null || process == null) {
      throw StateError(
        'The owned session is unavailable; inspect its current state',
      );
    }
    return CapturedWorkbenchTarget.ownedSession(process, session.deepCopy());
  }

  void requireTarget(
    CapturedWorkbenchTarget target, {
    bool text = false,
    bool profile = false,
  }) => _requireTarget(target, text: text, profile: profile);

  void _requireTarget(
    CapturedWorkbenchTarget target, {
    bool text = false,
    bool profile = false,
    String? acknowledgedRetiredSession,
  }) {
    // Only connect's acknowledged retirement can exempt physical metadata.
    // Owner/backend/profile/SQL checks still apply, including its old attachment.
    final retired =
        !target.sessionOnly &&
        target.sessionId != null &&
        target.sessionId == acknowledgedRetiredSession &&
        !sessions.containsKey(target.sessionId);
    if (_disposed ||
        !identical(backend, target.backend) ||
        !(target.sessionOnly
            ? sessions.containsKey(target.sessionId)
            : operationOwners.any(target.references)) ||
        closingDocuments.contains(target.ownerId) ||
        target.currentSessionId != target.sessionId ||
        (!retired &&
            target.session != null &&
            sessions[target.sessionId]?.metadataSourceIdentity !=
                target.session!.metadataSourceIdentity) ||
        target.currentProfileId != target.profileId ||
        (!retired &&
            ((sessions[target.sessionId]?.contextRevision ?? Int64.ZERO) !=
                    target.contextRevision ||
                (target.sessionRevision != null &&
                    (sessions[target.sessionId]?.sessionRevision ??
                            Int64.ZERO) !=
                        target.sessionRevision))) ||
        (text && target.currentRevision != target.revision)) {
      throw StateError(
        'The reviewed document, session, or execution context changed; request a fresh review',
      );
    }
    if (profile && target.sessionId == null && target.profile != null) {
      final current = profiles
          .where((p) => p.id == target.profileId)
          .firstOrNull;
      if (current == null || !sameConnectionTarget(current, target.profile!)) {
        throw StateError(
          'The saved connection changed; explicitly choose the target and request a fresh review',
        );
      }
    }
  }

  /// Names and credential record rotation do not change the reviewed endpoint.
  static bool sameConnectionTarget(Profile a, Profile b) {
    Profile identity(Profile p) {
      final value = p.deepCopy()
        ..clearName()
        ..clearCredentialRef();
      value.tls = p.tls.deepCopy()
        ..clearKeyCredentialRef()
        ..clearConfiguredMode();
      return value;
    }

    return sameProfileConfiguration(identity(a), identity(b));
  }

  bool documentMatchesProfile(WorkbenchDocument owner, Profile profile) {
    final original =
        sessions[owner.sessionId]?.profile ?? owner.evidenceProfile;
    return original != null && sameConnectionTarget(original, profile);
  }

  void requireDocumentTarget(WorkbenchDocument owner, Profile profile) {
    final evidence = owner.evidenceProfile;
    if (evidence != null && !sameConnectionTarget(evidence, profile)) {
      throw StateError(
        'This document was opened for a different connection configuration. Reconnect its original target or explicitly choose the new target before continuing.',
      );
    }
  }

  Future<T> ownedRequest<T>(
    CapturedWorkbenchTarget target,
    Future<T> Function() send, {
    bool text = false,
  }) async {
    requireTarget(target, text: text);
    final id = target.ownerId;
    pendingCommands[id] = (pendingCommands[id] ?? 0) + 1;
    notifyListeners();
    try {
      return await send();
    } finally {
      final remaining = pendingCommands[id]! - 1;
      if (remaining == 0) {
        pendingCommands.remove(id);
      } else {
        pendingCommands[id] = remaining;
      }
      if (!_disposed) notifyListeners();
    }
  }

  /// Enumerate one explicitly scoped metadata surface. A transport page is
  /// never completeness evidence. No page history survives this operation.
  Future<SchemaObjects> readMetadata(
    CapturedWorkbenchTarget target,
    ExploreRequest scope, {
    int maxObjects = 2048,
    int maxBytes = 4194304,
    bool Function()? current,
    void Function(ResponseFuture<SchemaObjects>)? onRequest,
  }) async {
    if (maxObjects < 0 ||
        maxObjects > 10000 ||
        maxBytes < 1 ||
        maxBytes > 4194304) {
      throw ArgumentError(
        'Metadata surface exceeds the existing resource budgets',
      );
    }
    requireTarget(target);
    final liveSession = sessions[target.sessionId];
    if (liveSession == null) {
      throw StateError('Metadata inspection was superseded');
    }
    final unavailable = metadataSessionUnavailableReason(target.sessionId);
    if (unavailable != null) throw LocalWorkbenchFailure(unavailable);
    final session = liveSession.deepCopy();
    final request = bindMetadataRequest(
      scope,
      target.backend.context(),
      session,
    );
    final objects = <SchemaObject>[];
    final identities = <String>{}, cursors = <String>{};
    final reservation = Object();
    ResponseFuture<SchemaObjects>? pending;
    var pendingSettled = true;
    var bytes = 0;
    void requireCurrent() {
      requireTarget(target);
      final unavailable = metadataSessionUnavailableReason(target.sessionId);
      if (unavailable != null) throw LocalWorkbenchFailure(unavailable);
      if (current?.call() == false) {
        throw StateError('Metadata inspection was superseded');
      }
    }

    void changed() {
      try {
        requireCurrent();
      } catch (_) {
        unawaited(pending?.cancel());
      }
    }

    addListener(changed);
    try {
      for (var page = 0; page < 128; page++) {
        requireCurrent();
        request.limit = (maxObjects - objects.length + 1).clamp(1, 128);
        pending = target.backend.client.explore(request.deepCopy());
        pendingSettled = false;
        onRequest?.call(pending);
        final reply = await ownedRequest(target, () => pending!);
        pendingSettled = true;
        requireCurrent();
        validateMetadataPage(
          reply,
          request,
          session,
          target.backend.instanceId,
        );
        if (reply.availability.startsWith('limited') ||
            !reply.complete && reply.continuation.isEmpty ||
            reply.complete && reply.continuation.isNotEmpty) {
          throw StateError(
            'Metadata is incomplete or unavailable; narrow the selected object scope',
          );
        }
        if (!acceptMetadataSnapshotRevision(
          session.sessionId,
          reply.metadataSnapshotRevision.toInt(),
          reply.metadataConfigurationRevision.toInt(),
          sourceIdentity: reply.metadataSourceIdentity,
        )) {
          throw StateError('Metadata inspection was superseded');
        }
        for (final object in reply.objects) {
          final key = DatabaseObjectIdentity(
            profileId: session.profile.id,
            catalog: object.catalog,
            schema: object.schema,
            kind: object.kind,
            name: object.name,
            parent: object.table,
            identifier: object.identifier,
            subtype: object.subtype,
          ).key;
          if (!identities.add(key)) {
            throw StateError('Metadata enumeration did not advance');
          }
          bytes += object.writeToBuffer().length;
        }
        if (objects.length + reply.objects.length > maxObjects ||
            bytes > maxBytes) {
          throw StateError(
            'Metadata resource budget reached; narrow the selected object scope',
          );
        }
        documentBudget.auxiliary(
          reservation,
          bytes * 4 + cursors.fold<int>(0, (n, c) => n + c.length * 2),
        );
        objects.addAll(reply.objects);
        if (reply.complete) {
          if (request.exactName && objects.length > 1) {
            throw StateError('Metadata object identity is ambiguous');
          }
          if (request.kind == ObjectKind.COLUMN &&
              objects.every(
                (o) => (int.tryParse(o.properties['ordinal'] ?? '') ?? 0) > 0,
              )) {
            // Keyset transport sorts native names. Column surfaces retain the
            // server's ordinal order rather than changing positional meaning.
            objects.sort(
              (a, b) => (int.tryParse(a.properties['ordinal'] ?? '') ?? 0)
                  .compareTo(int.tryParse(b.properties['ordinal'] ?? '') ?? 0),
            );
          }
          return reply.deepCopy()
            ..objects.clear()
            ..objects.addAll(objects);
        }
        if (reply.objects.isEmpty || !cursors.add(reply.continuation)) {
          throw StateError(
            'Metadata continuation did not advance; refresh this scope',
          );
        }
        request.continuation = reply.continuation;
        request.refresh = false;
      }
      throw StateError(
        'Metadata request budget reached; narrow the selected object scope',
      );
    } finally {
      removeListener(changed);
      if (!pendingSettled) await pending?.cancel();
      documentBudget.auxiliary(reservation, 0);
    }
  }

  Future<void> submitTool(
    CapturedWorkbenchTarget target,
    ToolRequest request, {
    bool text = false,
    String? documentId,
  }) async {
    submissions[request.executionId] = documentId ?? target.ownerId;
    final owner = workbenchDocuments
        .where((d) => d.id == (documentId ?? target.ownerId))
        .firstOrNull;
    if (owner != null &&
        (documentId != null ||
            request.kind == ToolKind.EXPLAIN ||
            request.kind == ToolKind.EXPLAIN_ANALYZE)) {
      _selectExecutionOutput(owner, request.executionId);
    }
    final job = await ownedRequest(
      target,
      () => target.backend.client.toolAdmission(request),
      text: text,
    );
    if (!identical(backend, target.backend)) {
      throw StateError('Backend changed; operation outcome may be unknown');
    }
    track(job, documentId: documentId ?? target.ownerId);
  }

  final resultActions = <String, Map<String, FutureOr<void> Function()>>{};
  final resultActionSources = <String, String>{};
  final jobs = <String, JobInfo>{};
  final retainedResults = <String, RetainedResult>{};
  final _retainedViews = <String, Set<String>>{};
  final jobDocuments = <String, String>{};
  final submissions = <String, String>{};
  final latestExecutions = <String, String>{};
  final selectedExecutions = <String, String>{};
  final browseReplacements =
      <String, ({String execution, String previous, int selectionRevision})>{};
  final cache = <String, Row>{};
  final loading = <String>{};
  final pageErrors = <String, ResultPageError>{};
  final _waitingPageRows = <String, int>{};
  final _knownFetchedRows = <String, int>{};
  final _maximumRowBytes = <String, int>{};
  final editBatches = <String, OwnedEditBatch>{};
  OwnedEditBatch get activeEditBatch =>
      batchFor(activeOwner, currentResult?.resultId ?? '');
  OwnedEditBatch batchFor(WorkbenchDocument owner, String resultId) {
    final key = '${owner.id}\u0000$resultId';
    return editBatches.putIfAbsent(
      key,
      () => OwnedEditBatch(owner.id, resultId),
    );
  }

  void stageChange(OwnedEditBatch batch, StagedChange change, {Row? original}) {
    final candidate = OwnedEditBatch(batch.ownerId, batch.resultId)
      ..changes.addAll(batch.changes.map((c) => c.deepCopy()))
      ..applying = batch.applying
      ..discarding = batch.discarding
      ..appliedSnapshot = batch.appliedSnapshot
      ..outcomeUnknown = batch.outcomeUnknown;
    candidate.stage(change.deepCopy(), original: original);
    final other = editBatches.values.where((b) => !identical(b, batch));
    final count =
        other.fold(0, (n, b) => n + b.changes.length) +
        candidate.changes.length;
    final bytes =
        other.fold(
          0,
          (n, b) =>
              n + b.changes.fold(0, (m, c) => m + c.writeToBuffer().length),
        ) +
        candidate.changes.fold(0, (n, c) => n + c.writeToBuffer().length);
    if (count > 1000 || bytes > 1024 * 1024) {
      throw StateError(
        'Pending changes share a 1MiB / 1,000-change budget across all documents',
      );
    }
    batch.changes
      ..clear()
      ..addAll(candidate.changes);
    batch.revision++;
  }

  void replaceStagedInsert(
    OwnedEditBatch batch,
    int index,
    StagedChange change,
    int expectedRevision,
  ) {
    if (batch.revision != expectedRevision ||
        index < 0 ||
        index >= batch.changes.length ||
        batch.changes[index].kind != ChangeKind.INSERT ||
        change.kind != ChangeKind.INSERT ||
        batch.applying ||
        batch.discarding ||
        batch.outcomeUnknown ||
        batch.appliedSnapshot) {
      throw StateError('Staged insert owner or revision changed');
    }
    final previous = batch.changes.removeAt(index);
    try {
      stageChange(batch, change);
    } catch (_) {
      batch.changes.insert(index, previous);
      rethrow;
    }
    final inserted = batch.changes.removeLast();
    batch.changes.insert(index, inserted);
    notifyListeners();
  }

  int get pendingEditCount =>
      editBatches.values.fold(0, (n, batch) => n + batch.changes.length);
  List<StagedChange> get staged => activeEditBatch.changes;
  final editDrafts = <EditDraftInfo>[];
  String? get stagedDraftId => activeEditBatch.draftId;
  set stagedDraftId(String? value) => activeEditBatch.draftId = value;
  String? get stagedDocumentId => activeEditBatch.documentId;
  set stagedDocumentId(String? value) => activeEditBatch.documentId = value;
  int get stagedRevision => activeEditBatch.revision;
  set stagedRevision(int value) => activeEditBatch.revision = value;
  Object? get stagedSaveError => activeEditBatch.saveError;
  set stagedSaveError(Object? value) => activeEditBatch.saveError = value;
  SqlLanguagePreferences sqlLanguagePreferences = SqlLanguagePreferences();
  Future<void> saveSqlLanguagePreferences(
    SqlLanguagePreferences proposed,
  ) async {
    proposed.validate();
    final captured = proposed.deepCopy();
    await _savePresentation(
      proposedSqlLanguage: captured,
      acknowledged: () {
        sqlLanguagePreferences = captured;
        invalidateAnalysis();
      },
    );
    notifyListeners();
  }

  final resultDisplayFormats = <String, String>{};
  String? resultDisplayFormatKey(Profile profile, Column column) =>
      resultColumnPreferenceKey(profile.id, column);

  Future<void> setResultDisplayFormat(
    Profile profile,
    Column column,
    String format,
  ) async {
    final key = resultDisplayFormatKey(profile, column);
    if (key == null) return;
    if (!validResultDisplayFormat(format)) {
      throw ArgumentError('Unknown result display format');
    }
    final previous = Map<String, String>.of(resultDisplayFormats);
    if (format == 'canonical') {
      resultDisplayFormats.remove(key);
    } else {
      resultDisplayFormats[key] = format;
    }
    if (resultDisplayFormats.length > 128 ||
        utf8.encode(jsonEncode(resultDisplayFormats)).length > 16384) {
      resultDisplayFormats
        ..clear()
        ..addAll(previous);
      throw StateError('Result display preference budget exceeded');
    }
    try {
      await savePresentation();
    } catch (_) {
      resultDisplayFormats
        ..clear()
        ..addAll(previous);
      rethrow;
    }
    notifyListeners();
  }

  Future<ResultAggregateReply> resultAggregate(
    ResultAggregateRequest request,
  ) async {
    final process = backend;
    if (process == null) throw StateError('Backend unavailable');
    final response = await process.client.resultAggregate(
      request.deepCopy()..context = process.context(),
    );
    if (!identical(backend, process) ||
        response.resultId != request.resultId ||
        response.viewId != request.viewId ||
        disposedResults.contains(request.resultId)) {
      throw StateError('Aggregate result owner changed');
    }
    return response;
  }

  Future<RelatedRowsReply> relatedRows(RelatedRowsRequest request) async {
    final process = backend;
    if (process == null) throw StateError('Backend unavailable');
    final submitted = request.deepCopy()..context = process.context();
    final owner = sessions[submitted.sessionId];
    if (owner == null ||
        owner.sessionId != submitted.sessionId ||
        owner.transaction == TransactionState.DISCONNECTED) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (owner.transaction == TransactionState.UNKNOWN_TRANSACTION) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.transactionUnknown,
      );
    }
    final unavailable = metadataSessionUnavailableReason(submitted.sessionId);
    if (unavailable != null) throw LocalWorkbenchFailure(unavailable);
    final profile = owner.profile.deepCopy()..freeze();
    final sourceIdentity = owner.metadataSourceIdentity;
    final sessionRevision = owner.sessionRevision;
    final contextRevision = owner.contextRevision;
    if (submitted.snapshotRevision.isNegative ||
        submitted.hasExpectedSessionRevision() &&
            submitted.expectedSessionRevision.isNegative ||
        submitted.hasExpectedContextRevision() &&
            submitted.expectedContextRevision.isNegative) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.malformedRequest,
      );
    }
    if (submitted.hasExpectedSessionRevision() &&
            submitted.expectedSessionRevision != sessionRevision ||
        submitted.hasExpectedContextRevision() &&
            submitted.expectedContextRevision != contextRevision) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidRevision);
    }
    submitted
      ..expectedSessionRevision = sessionRevision
      ..expectedContextRevision = contextRevision;
    final response = await process.client.relatedRows(submitted);
    if (!identical(backend, process)) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.backendRestarted,
      );
    }
    final current = sessions[submitted.sessionId];
    if (current == null ||
        current.sessionId != submitted.sessionId ||
        !sameProfileConfiguration(current.profile, profile) ||
        current.metadataSourceIdentity != sourceIdentity ||
        current.transaction == TransactionState.DISCONNECTED) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (current.contextRevision != contextRevision ||
        current.sessionRevision != sessionRevision) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidRevision);
    }
    if (current.transaction == TransactionState.UNKNOWN_TRANSACTION) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.transactionUnknown,
      );
    }
    if (response.resultId != submitted.resultId ||
        response.sourceRow != submitted.sourceRow ||
        disposedResults.contains(submitted.resultId)) {
      throw StateError('Related row owner changed');
    }
    final stamp = relatedRowsMetadataStamp(response);
    if (!stamp.wellFormed) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.malformedRequest,
      );
    }
    if (stamp.backendInstance != process.instanceId) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.backendRestarted,
      );
    }
    if (stamp.profileId != profile.id ||
        stamp.sessionId != submitted.sessionId ||
        stamp.sourceIdentity != sourceIdentity) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (stamp.sessionRevision != sessionRevision.toInt() ||
        stamp.contextRevision != contextRevision.toInt()) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidRevision);
    }
    if (submitted.snapshotRevision != Int64.ZERO &&
        response.snapshotRevision != submitted.snapshotRevision) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidRevision);
    }
    _publishMetadataRevision(stamp);
    return response;
  }

  Future<StagedChange> cloneRow(CloneRowRequest request) async {
    final process = backend;
    if (process == null) throw StateError('Backend unavailable');
    final response = await process.client.cloneRow(
      request.deepCopy()..context = process.context(),
    );
    if (!identical(backend, process) ||
        disposedResults.contains(request.resultId) ||
        response.kind != ChangeKind.INSERT) {
      throw StateError('Clone row owner changed');
    }
    return response;
  }

  final selectedResults = <String, String>{};
  final disposedResults = <String>{};
  String? get stagedSession => activeEditBatch.sessionId;
  set stagedSession(String? value) => activeEditBatch.sessionId = value;
  String? get stagedSchema => activeEditBatch.schema;
  set stagedSchema(String? value) => activeEditBatch.schema = value;
  String? get stagedTable => activeEditBatch.table;
  set stagedTable(String? value) => activeEditBatch.table = value;
  String? get stagedResult => activeEditBatch.resultId;
  set stagedResult(String? value) => activeEditBatch.resultId = value ?? '';
  String status = 'Starting backend';
  int selected = 0, cacheBytes = 0;
  int cacheGeneration = 0;
  bool busy = false;
  bool get streaming => documents.isNotEmpty && activeOwner.view.streaming;
  set streaming(bool value) => activeOwner.view.streaming = value;
  bool backendStatusVerified = false;
  bool draftRecovery = true;
  int _defaultRowLimit = 10000;
  double _defaultEditorFraction = 5 / 9;
  ErrorPolicy _defaultErrorPolicy = ErrorPolicy.STOP_ON_ERROR;
  int get rowLimit => documents.isEmpty
      ? _defaultRowLimit
      : activeOwner.view.rowLimit ?? _defaultRowLimit;
  set rowLimit(int value) {
    if (documents.isEmpty) {
      _defaultRowLimit = value;
    } else {
      activeOwner.view.rowLimit = value;
    }
  }

  double get editorFraction => documents.isEmpty
      ? _defaultEditorFraction
      : activeOwner.view.editorFraction ?? _defaultEditorFraction;
  set editorFraction(double value) {
    if (documents.isEmpty) {
      _defaultEditorFraction = value;
    } else {
      activeOwner.view.editorFraction = value;
    }
  }

  ErrorPolicy get errorPolicy => documents.isEmpty
      ? _defaultErrorPolicy
      : activeOwner.view.errorPolicy ?? _defaultErrorPolicy;
  set errorPolicy(ErrorPolicy value) {
    if (documents.isEmpty) {
      _defaultErrorPolicy = value;
    } else {
      activeOwner.view.errorPolicy = value;
    }
  }

  final snippets = <String, String>{
    'Select': 'SELECT *\nFROM table_name\nWHERE condition;\n',
    'Insert': 'INSERT INTO table_name (column_name)\nVALUES (value);\n',
    'Update': 'UPDATE table_name\nSET column_name = value\nWHERE condition;\n',
    'Transaction': 'BEGIN;\n\nROLLBACK;\n',
  };
  static void validateSnippets(Map<String, String> values) {
    if (values.length > 32 ||
        values.keys.any((name) => name.isEmpty || name.length > 64) ||
        values.values.any(
          (text) => text.length > 4096 || text.contains('\u0000'),
        ) ||
        values.entries.fold<int>(
              0,
              (size, item) =>
                  size +
                  utf8.encode(item.key).length +
                  utf8.encode(item.value).length,
            ) >
            32768) {
      throw StateError(
        'Snippets support 32 named entries, 4096 UTF-16 units each and 32KiB total',
      );
    }
  }

  Future<void> _snippetSave = Future<void>.value();
  Future<void> saveSnippet(String name, String text, {bool remove = false}) {
    final pending = _snippetSave.then((_) async {
      final before = Map<String, String>.of(snippets),
          changed = Map<String, String>.of(snippets);
      if (remove) {
        changed.remove(name);
      } else {
        changed[name] = text;
      }
      validateSnippets(changed);
      snippets
        ..clear()
        ..addAll(changed);
      try {
        await savePresentation();
      } catch (_) {
        snippets
          ..clear()
          ..addAll(before);
        rethrow;
      }
      notifyListeners();
    });
    _snippetSave = pending.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return pending;
  }

  final shortcuts = <String, String>{
    'execute': 'Ctrl+Enter',
    'script': 'Ctrl+Shift+Enter',
    'save': 'Ctrl+S',
    'new': 'Ctrl+T',
    'close': 'Ctrl+W',
    'find': 'Ctrl+F',
    'comment': 'Ctrl+Slash',
    'palette': 'Ctrl+Shift+P',
    'explorer': 'Alt+1',
    'objects': 'Ctrl+Shift+O',
    'replace': 'Ctrl+H',
    'data': 'F4',
    'ddl': 'Ctrl+B',
    'documentation': 'Ctrl+Q',
    'reveal': 'Alt+Shift+B',
    'consoles': 'Ctrl+Shift+F10',
  };
  Timer? _poll, _draftTimer, _analysisTimer, _backendPaint;
  AcceptedAnalysis? acceptedAnalysis;
  AcceptedAnalysis? acceptedDiagnostics;
  AcceptedAnalysis? acceptedParameterInformation;
  Analysis? get analysis {
    final completion = acceptedAnalysis;
    final diagnostics = acceptedDiagnostics;
    if (completion != null && analysisResultMatches(completion)) {
      if (diagnostics != null && analysisResultMatches(diagnostics)) {
        return completion.result.deepCopy()
          ..diagnostics.clear()
          ..diagnostics.addAll(diagnostics.result.diagnostics);
      }
      return completion.result;
    }
    return diagnostics != null && analysisResultMatches(diagnostics)
        ? diagnostics.result
        : null;
  }

  SqlDocument get document => documents[selected];
  SessionInfo? get session => sessions[activeOwner.sessionId];
  List<JobInfo> get documentJobs => jobsForOwner(activeOwner);
  List<JobInfo> jobsForOwner(WorkbenchDocument owner) {
    // The acknowledgement path composes immutable jobs once. Ordinary status,
    // eligibility and rendering reads reuse those snapshots; late retained
    // inspection can still overlay metadata without changing the source list.
    final owned = <String, JobInfo>{
      for (final job in jobs.values.where(
        (j) => jobDocuments[j.jobId] == owner.id,
      ))
        job.jobId: job,
    };
    for (final retained in retainedResults.values) {
      if (retained.disposalPending ||
          disposedResults.contains(retained.result.resultId)) {
        continue;
      }
      final belongs =
          retained.documentId == owner.id ||
          jobDocuments[retained.jobId] == owner.id ||
          (_retainedViews[owner.id]?.contains(retained.result.resultId) ??
              false);
      if (!belongs) continue;
      final knownJob = owned[retained.jobId] ?? jobs[retained.jobId];
      if (knownJob != null) {
        var existing = owned[retained.jobId] ?? knownJob;
        owned[retained.jobId] = existing;
        final index = existing.results.indexWhere(
          (r) => r.resultId == retained.result.resultId,
        );
        if (index < 0 || !identical(existing.results[index], retained.result)) {
          existing = existing.toBuilder() as JobInfo;
          owned[retained.jobId] = existing;
          if (index < 0) {
            existing.results.add(retained.result);
          } else {
            existing.results[index] = retained.result;
          }
        }
      } else {
        owned[retained.jobId] = JobInfo(
          jobId: retained.jobId,
          sessionId: retained.sessionId,
          executionId: retained.executionId,
          state: retained.state,
          target: retained.target,
          sourceSchema: retained.sourceSchema,
          results: [retained.result],
          messages: [
            'Retained data survives job-summary eviction. ${retained.availability}',
          ],
        );
      }
    }
    return owned.values.map((job) => job..freeze()).toList().reversed.toList();
  }

  JobInfo _acknowledgedJob(JobInfo job, Map<String, RetainedResult> catalog) {
    var snapshot = job;
    var copied = false;
    for (final retained in catalog.values) {
      if (retained.jobId != job.jobId ||
          retained.disposalPending ||
          disposedResults.contains(retained.result.resultId)) {
        continue;
      }
      final index = snapshot.results.indexWhere(
        (r) => r.resultId == retained.result.resultId,
      );
      if (index >= 0 && identical(snapshot.results[index], retained.result)) {
        continue;
      }
      if (!copied) {
        snapshot = job.toBuilder() as JobInfo;
        copied = true;
      }
      if (index < 0) {
        snapshot.results.add(retained.result);
      } else {
        snapshot.results[index] = retained.result;
      }
    }
    return snapshot..freeze();
  }

  JobInfo? get currentJob => jobForOwner(activeOwner);
  JobInfo? cancellableJobForOwner(WorkbenchDocument owner) =>
      jobsForOwner(owner).where((job) => !terminalJob(job.state)).firstOrNull;
  JobInfo? jobForOwner(WorkbenchDocument owner) => jobsForOwner(owner)
      .where(
        (j) =>
            j.executionId ==
            (selectedExecutions[owner.id] ?? latestExecutions[owner.id]),
      )
      .firstOrNull;

  void openRetainedResult(RetainedResult retained) {
    if (retained.disposalPending ||
        disposedResults.contains(retained.result.resultId)) {
      return;
    }
    openTask(
      WorkbenchDocumentKind.result,
      'Result · ${retained.target.name}',
      retained: retained,
      profileId: retained.target.id,
    );
    activeOwner.reopenCommandId = 'view.results';
    _retainedViews[activeOwner.id] = {retained.result.resultId};
    selectedExecutions[activeOwner.id] = retained.executionId;
    selectedResults[activeOwner.id] = retained.result.resultId;
    updateStatus(
      'Retained result from ${retained.target.host}:${retained.target.port}/${retained.target.database}; SQL was not executed',
    );
  }

  Future<void> disposeRetainedResult(String id) async {
    if (editBatches.values.any(
      (b) => b.changes.isNotEmpty && b.resultId == id,
    )) {
      throw StateError(
        'Apply or explicitly discard staged edits before disposing their source result',
      );
    }
    final process = backend!;
    for (final owner in workbenchDocuments) {
      final state = owner.view.results[id];
      if (state?.retainedView != null) {
        await disposeView(state!.retainedView!.viewId);
        state.retainedView = null;
      }
    }
    await process.client.disposeResult(
      PageRequest(context: process.context(), resultId: id),
    );
    if (!identical(backend, process)) return;
    disposedResults.add(id);
    for (final key in cache.keys.where((k) => k.startsWith('$id:')).toList()) {
      cacheBytes -= cache.remove(key)!.writeToBuffer().length;
    }
    cacheGeneration++;
    updateStatus(
      'Disposal requested; active exports retain their files until completion. SQL was not rerun.',
    );
  }

  void selectExecution(String executionId, {WorkbenchDocument? owner}) {
    owner ??= activeOwner;
    if (!jobsForOwner(owner).any((job) => job.executionId == executionId)) {
      return;
    }
    owner.view.executionSelectionRevision++;
    _selectExecutionOutput(owner, executionId);
    updateStatus('Showing a retained execution; SQL was not rerun');
  }

  void _selectExecutionOutput(WorkbenchDocument owner, String executionId) {
    final previous = jobForOwner(owner)?.executionId;
    if (previous == executionId) return;
    if (previous != null) {
      owner.view.executionOutputs[previous] = ExecutionOutputState(
        owner.view.output,
        selectedResults[owner.id],
      );
    }
    selectedExecutions[owner.id] = executionId;
    final state = owner.view.executionOutputs[executionId];
    owner.view.output = state?.output ?? 'results';
    if (state?.resultId case final id?) {
      selectedResults[owner.id] = id;
    } else {
      selectedResults.remove(owner.id);
    }
  }

  StatementResult? get currentResult => resultForOwner(activeOwner);
  StatementResult? resultForOwner(WorkbenchDocument owner) {
    final all =
        jobForOwner(owner)?.results
            .where(
              (r) =>
                  r.resultId.isNotEmpty &&
                  !disposedResults.contains(r.resultId),
            )
            .toList() ??
        [];
    return all
            .where((r) => r.resultId == selectedResults[owner.id])
            .firstOrNull ??
        all.lastOrNull;
  }

  final resultViews = <String, ResultViewInfo>{};
  final sourceRowMappings = <String, int>{};
  String sourceResultId(String id) => resultViews[id]?.resultId ?? id;
  int sourceRow(String id, int visibleRow) => resultViews.containsKey(id)
      ? sourceRowMappings['$id:$visibleRow'] ??
            (throw StateError('Load this retained row before editing'))
      : visibleRow;
  StatementResult? get displayResult => displayResultForOwner(activeOwner);
  StatementResult? displayResultForOwner(WorkbenchDocument owner) {
    final source = resultForOwner(owner);
    if (source == null) return null;
    final view = owner.view.results[source.resultId]?.retainedView;
    return view == null
        ? source
        : (source.deepCopy()
            ..resultId = view.viewId
            ..fetchedRows = view.visibleRows
            ..complete = true
            ..limited = view.partial);
  }

  final _viewRequests = <String, ResponseFuture<ResultViewInfo>>{};
  final _viewGenerations = <String, Object>{};
  Future<void> disposeView(String id) async {
    final process = backend;
    if (process == null) return;
    await process.client.disposeResultView(
      ResultViewRequest(context: process.context(), viewId: id),
    );
    if (!identical(backend, process)) return;
    resultViews.remove(id);
    sourceRowMappings.removeWhere((key, _) => key.startsWith('$id:'));
    for (final key in cache.keys.where((k) => k.startsWith('$id:')).toList()) {
      cacheBytes -= cache.remove(key)!.writeToBuffer().length;
    }
    disposedResults.add(id);
    cacheGeneration++;
  }

  Future<void> disposeOwnerViews(WorkbenchDocument owner) async {
    for (final entry in owner.view.results.entries) {
      final key = '${owner.id}\u0000${entry.key}';
      _viewGenerations.remove(key);
      await _viewRequests.remove(key)?.cancel();
      final retained = entry.value.retainedView;
      if (retained != null) {
        await disposeView(retained.viewId);
        entry.value.retainedView = null;
      }
    }
  }

  Future<void> createResultView(
    List<RowCondition> conditions,
    List<RowOrder> order, {
    WorkbenchDocument? targetOwner,
    String? resultId,
  }) async {
    final owner = targetOwner ?? activeOwner;
    final source = sourceResultId(resultId ?? resultForOwner(owner)!.resultId);
    final process = backend!;
    final state = owner.view.results.putIfAbsent(source, ResultViewState.new);
    final key = '${owner.id}\u0000$source';
    final generation = Object();
    _viewGenerations[key] = generation;
    await _viewRequests.remove(key)?.cancel();
    final pending = process.client.createResultView(
      ResultViewRequest(
        context: process.context(),
        resultId: source,
        conditions: conditions,
        order: order,
      ),
    );
    _viewRequests[key] = pending;
    try {
      final info = await pending;
      if (!identical(backend, process) ||
          !workbenchDocuments.contains(owner) ||
          closingDocuments.contains(owner.id) ||
          !identical(_viewGenerations[key], generation)) {
        if (identical(backend, process)) await disposeView(info.viewId);
        return;
      }
      final previous = state.retainedView;
      state.retainedView = info;
      state.conditions = conditions.map((v) => v.deepCopy()).toList();
      state.order = order.map((v) => v.deepCopy()).toList();
      state.selectedRow = state.anchorRow = state.windowStart = 0;
      state.verticalOffset = 0;
      resultViews[info.viewId] = info;
      if (previous != null) await disposeView(previous.viewId);
      updateStatus(info.availability);
    } catch (_) {
      if (identical(_viewGenerations[key], generation) &&
          identical(backend, process)) {
        rethrow;
      }
    } finally {
      if (identical(_viewRequests[key], pending)) {
        _viewRequests.remove(key);
        _viewGenerations.remove(key);
      }
    }
  }

  Context get context => backend!.context();

  Future<void> initialize() async {
    Map<String, dynamic> views = {};
    List<dynamic> hints = [];
    List<dynamic> taskHints = [];
    Map<String, dynamic> designRecords = {};
    try {
      final file = File('${support.path}/presentation.json');
      if (await file.exists()) {
        final data =
            jsonDecode(utf8.decode(await readBoundedFile(file, 65536)))
                as Map<String, dynamic>;
        if (data['version'] != 1) {
          throw const FormatException('Unsupported presentation settings');
        }
        if (data['snippets'] case final Map<String, dynamic> stored) {
          final restored = stored.map(
            (key, value) => MapEntry(key, value as String),
          );
          validateSnippets(restored);
          snippets
            ..clear()
            ..addAll(restored);
        }
        sqlLanguagePreferences = SqlLanguagePreferences.fromJson(
          data['sqlLanguage'],
        );
        if (data['resultDisplayFormats']
            case final Map<String, dynamic> stored) {
          final formats = stored.map(
            (key, value) => MapEntry(key, value as String),
          );
          if (formats.length > 128 ||
              formats.values.any(
                (format) => !validResultDisplayFormat(format),
              ) ||
              utf8.encode(jsonEncode(formats)).length > 16384) {
            throw const FormatException(
              'Result display settings exceed budget',
            );
          }
          resultDisplayFormats.addAll(formats);
        }
        rowLimit = (data['rowLimit'] as int).clamp(1, 1000000);
        if (data['querySequence'] case final int sequence
            when sequence >= 0 && sequence <= 1000000000) {
          if (sequence > _querySequence) _querySequence = sequence;
        }
        if (data['documentViews'] is Map<String, dynamic>) {
          views = data['documentViews'] as Map<String, dynamic>;
        }
        if (data['objectHints'] is List) hints = data['objectHints'] as List;
        if (data['taskHints'] is List) taskHints = data['taskHints'] as List;
        draftRecovery = data['draftRecovery'] != false;
        if (data['favoriteProfiles'] case final List<dynamic> favorites) {
          favoriteProfiles.addAll(
            favorites
                .whereType<String>()
                .where((id) => id.length <= 128)
                .take(64),
          );
        }
        if (data['sourceFolders'] case final List<dynamic> folders) {
          if (folders.length > 64) {
            throw const FormatException('Too many source folders');
          }
          for (final record in folders) {
            final folder = SourceFolder.fromJson(
              record as Map<String, dynamic>,
            );
            if (folder.id.isEmpty ||
                folder.id.length > 128 ||
                folder.name.trim().isEmpty ||
                folder.name.length > 128 ||
                folder.name.contains('/') ||
                folder.name.contains('\u0000') ||
                sourceFolders.containsKey(folder.id)) {
              throw const FormatException('Invalid source folder');
            }
            sourceFolders[folder.id] = folder;
          }
          for (final folder in sourceFolders.values) {
            if (!folderCanMove(folder.id, folder.parentId)) {
              sourceFolders.clear();
              throw const FormatException('Cyclic or missing source folder');
            }
          }
          final membership =
              data['sourceFolderMembership'] as Map<String, dynamic>? ?? {};
          for (final entry in membership.entries.take(64)) {
            if (entry.key.length <= 128 &&
                entry.value is String &&
                sourceFolders.containsKey(entry.value)) {
              sourceFolderMembership[entry.key] = entry.value as String;
            }
          }
        } else if (data['profileGroups']
            case final Map<String, dynamic> groups) {
          // One-time migration. Old sorting labels are no longer written.
          final byName = <String, String>{};
          for (final entry in groups.entries.take(64)) {
            if (entry.key.length > 128 || entry.value is! String) continue;
            final name = (entry.value as String).trim();
            if (name.isEmpty || name.length > 128 || name.contains('\u0000')) {
              continue;
            }
            final id = byName.putIfAbsent(name, () => const Uuid().v4());
            sourceFolders[id] = SourceFolder(id, name.replaceAll('/', '∕'));
            sourceFolderMembership[entry.key] = id;
          }
        }
        if (data['explorerOrder'] case final List<dynamic> order) {
          explorerOrder.addAll(
            order
                .whereType<String>()
                .where(
                  (k) =>
                      k.length <= 130 &&
                      (k.startsWith('f:') || k.startsWith('s:')),
                )
                .toSet()
                .take(128),
          );
        }
        if (data['virtualViews'] case final List<dynamic> views) {
          if (views.length > 32 ||
              utf8.encode(jsonEncode(views)).length > 32768) {
            throw const FormatException('Virtual view storage budget exceeded');
          }
          for (final record in views) {
            final view = VirtualViewDefinition.fromJson(
              record as Map<String, dynamic>,
            );
            if (virtualViews.containsKey(view.id)) {
              throw const FormatException('Duplicate local identity');
            }
            virtualViews[view.id] = view;
          }
        }
        showAllNamespaces = data['showAllNamespaces'] == true;
        showEmptyGroups = data['showEmptyGroups'] == true;
        if (data['explorerPreferences']
            case final Map<String, dynamic> preferences) {
          for (final key in explorerPreferences.keys.toList()) {
            if (preferences[key] case final bool value) {
              explorerPreferences[key] = value;
            }
          }
        }
        if (data['explorerObjectKinds'] case final List<dynamic> kinds) {
          explorerObjectKinds
            ..clear()
            ..addAll(
              kinds
                  .whereType<int>()
                  .map(ObjectKind.valueOf)
                  .whereType<ObjectKind>(),
            );
        }
        if (data['explorerExpanded'] case final List<dynamic> expanded) {
          var bytes = 0;
          for (final key in expanded.whereType<String>().take(256)) {
            bytes += utf8.encode(key).length;
            if (key.length <= 2048 && bytes <= 8192) explorerExpanded.add(key);
          }
        }
        if (data['explorerSelection'] case final String key
            when key.length <= 2048) {
          explorerSelection = key;
        }
        if (data['explorerNameFilter'] case final String name
            when name.length <= 256) {
          explorerNameFilter = name;
        }
        if (data['namespaceSelections']
            case final Map<String, dynamic> stored) {
          for (final entry in stored.entries.take(128)) {
            if (entry.key.length > 1153 ||
                entry.value is! Map<String, dynamic>) {
              continue;
            }
            try {
              namespaceSelections[entry.key] = NamespaceSelection.fromJson(
                entry.value as Map<String, dynamic>,
              );
            } on FormatException {
              // A rejected rule cannot select or connect a server namespace.
            } on ArgumentError {
              // Preserve the remaining independently valid display scopes.
            } on TypeError {
              // Presentation files are untrusted local input.
            }
          }
        }
        final storedTheme = data['themeMode'];
        final storedLocale = data['locale'];
        appearancePreference.value = (
          const {'system', 'light', 'dark'}.contains(storedTheme)
              ? storedTheme as String
              : 'system',
          storedLocale is String
              ? normalizeBusyDataLocaleTag(storedLocale)
              : null,
        );
        final width = data['explorerWidth'];
        if (data['explorerVisible'] case final bool visible) {
          explorerVisible = visible;
        }
        if (width is num && width.isFinite) {
          explorerWidth = width.toDouble().clamp(220, 480);
        }
        final fraction = data['editorFraction'];
        if (fraction is num && fraction.isFinite) {
          editorFraction = fraction.toDouble().clamp(.15, .85);
        }
        errorPolicy = data['continueOnError'] == true
            ? ErrorPolicy.CONTINUE_ON_ERROR
            : ErrorPolicy.STOP_ON_ERROR;
        if (data['shortcuts'] case final Map<String, dynamic> stored) {
          final cohort = validateWorkbenchShortcuts({
            ...shortcuts,
            for (final entry in stored.entries)
              if (shortcuts.containsKey(entry.key))
                entry.key: entry.value as String,
          });
          shortcuts
            ..clear()
            ..addAll(cohort);
        }
      }
    } catch (_) {
      status = 'Presentation settings unavailable; safe defaults restored';
    }
    try {
      final file = File('${support.path}/object-designs.json');
      if (draftRecovery && await file.exists()) {
        final data =
            jsonDecode(utf8.decode(await readBoundedFile(file, 2097152)))
                as Map<String, dynamic>;
        if (data['version'] != 1 ||
            data['documents'] is! Map<String, dynamic>) {
          throw const FormatException('Invalid object design recovery');
        }
        designRecords = data['documents'] as Map<String, dynamic>;
        if (designRecords.length > 32) {
          throw const FormatException('Object design recovery count exceeded');
        }
      }
    } on DocumentResourceLimit {
      status =
          'Object design recovery exceeds its bounded file limit; original file preserved';
    } catch (_) {
      final file = File('${support.path}/object-designs.json');
      if (await file.exists()) {
        final quarantine = await OutputDestination.newDestination(
          File('${file.path}.corrupt-${const Uuid().v4()}'),
        );
        await quarantine.commit(file);
      }
      status =
          'Corrupt object design recovery preserved; inspect metadata explicitly';
    }
    try {
      if (draftRecovery) {
        final store = drafts;
        final restored = await store.load();
        for (final draft in restored) {
          final number = draft.untitledNumber;
          if (number != null && number > _querySequence) {
            _querySequence = number;
          }
        }
        _unadoptedSqlDrafts.addAll(store.unadoptedRecords);
        for (final draft in restored) {
          try {
            adoptDocuments([draft], notify: false);
          } catch (_) {
            _unadoptedSqlDrafts.add(store.restoredRecords[draft.id]);
          }
        }
        // A restored blank document is user data, never launch scratch.
        selected = store.restoredSelection.clamp(
          0,
          documents.isEmpty ? 0 : documents.length - 1,
        );
      }
    } catch (_) {
      status = 'Corrupt recovery file preserved; start a new SQL document';
    }
    if (documents.isEmpty) {
      newDocument();
      _startupScratchId = document.id;
    }
    await restart();
    for (final sql in documents) {
      final saved = views[sql.id];
      if (saved is Map<String, dynamic>) {
        final owner = workbenchDocuments.firstWhere((d) => d.id == sql.id);
        final split = saved['editorFraction'], limit = saved['rowLimit'];
        final vertical = saved['editorVertical'],
            horizontal = saved['editorHorizontal'];
        if (vertical is num &&
            vertical.isFinite &&
            vertical >= 0 &&
            vertical <= 1000000000) {
          owner.view.editorVertical = vertical.toDouble();
        }
        if (horizontal is num &&
            horizontal.isFinite &&
            horizontal >= 0 &&
            horizontal <= 1000000000) {
          owner.view.editorHorizontal = horizontal.toDouble();
        }
        if (split is num && split.isFinite) {
          owner.view.editorFraction = split.toDouble().clamp(.15, .85);
        }
        if (limit is int && limit >= 1 && limit <= 1000000) {
          owner.view.rowLimit = limit;
        }
      }
    }
    _unadoptedObjectHints.addAll(hints.take(32));
    _unadoptedTaskHints.addAll(taskHints.take(32));
    _unadoptedDesigns.addAll(designRecords);
    for (final hint in hints.take(32)) {
      try {
        if (hint is! Map<String, dynamic> ||
            !['table', 'structure'].contains(hint['kind'])) {
          continue;
        }
        final values = [
          'profile',
          'catalog',
          'schema',
          'name',
          'parent',
        ].map((k) => hint[k]);
        if (values.any((v) => v is! String || v.length > 1024) ||
            !profiles.any((p) => p.id == hint['profile'])) {
          continue;
        }
        final creating = hint['creation'] == true;
        final objectKind = ObjectKind.valueOf(
          hint['objectKind'] is int ? hint['objectKind'] as int : -1,
        );
        if (objectKind == null && !creating) continue;
        final identifier = hint['identifier'] ?? '';
        if (identifier is! String ||
            identifier.contains('\u0000') ||
            utf8.encode(identifier).length > 8192) {
          continue;
        }
        final object = creating
            ? null
            : DatabaseObjectIdentity(
                profileId: hint['profile'] as String,
                catalog: hint['catalog'] as String,
                schema: hint['schema'] as String,
                name: hint['name'] as String,
                parent: hint['parent'] as String,
                kind: objectKind!,
                subtype:
                    ObjectSubtype.valueOf(
                      hint['subtype'] is int ? hint['subtype'] as int : 0,
                    ) ??
                    ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
                identifier: identifier,
              );
        final owner = openTask(
          hint['kind'] == 'table'
              ? WorkbenchDocumentKind.table
              : WorkbenchDocumentKind.structure,
          object?.displayName ?? 'New object design',
          object: object,
          creationScope: creating
              ? DatabaseCreationScope(
                  profileId: hint['profile'] as String,
                  catalog: hint['catalog'] as String,
                  schema: hint['schema'] as String,
                )
              : null,
          profileId: hint['profile'] as String,
          purpose: hint['purpose'] == 'design' ? 'design' : '',
          restoredId: hint['id'] is String ? hint['id'] as String : null,
        );
        owner.view.subview = 'structure';
        owner.referenceSchema = hint['schema'] as String;
        _unadoptedObjectHints.remove(hint);
        final section = hint['structureSection'];
        if (section is int && section >= 0 && section <= 10) {
          owner.view.structureSection = section;
        }
        if (draftRecovery &&
            designRecords[hint['id']] is Map<String, dynamic>) {
          try {
            final draft = ObjectDesignerDraft.fromJson(
              designRecords[hint['id']] as Map<String, dynamic>,
            );
            if (!admitDesignDraft(owner, draft)) {
              throw const FormatException('Shared design budget exceeded');
            }
            owner.designDraft.replace(draft);
            owner.contentDirty = draft.dirty;
            _unadoptedDesigns.remove(hint['id']);
          } catch (_) {
            status =
                'Invalid object design recovery preserved; current metadata must be inspected explicitly';
          }
        }
      } catch (_) {
        status =
            'A document could not be restored; its recovery record is preserved.';
      }
    }
    for (final hint in taskHints.take(32)) {
      try {
        if (hint is! Map<String, dynamic> ||
            hint['id'] is! String ||
            (hint['id'] as String).length > 128 ||
            hint['title'] is! String ||
            (hint['title'] as String).length > 256 ||
            hint['profile'] is! String ||
            !profiles.any((p) => p.id == hint['profile'])) {
          continue;
        }
        final kind = WorkbenchDocumentKind.values
            .where(
              (k) =>
                  k.name == hint['kind'] &&
                  ![
                    WorkbenchDocumentKind.sql,
                    WorkbenchDocumentKind.table,
                    WorkbenchDocumentKind.structure,
                  ].contains(k),
            )
            .firstOrNull;
        if (kind == null || taskDocuments.length >= 32) continue;
        const allowed = {
          'schema.compare',
          'schema.diagram',
          'connection.activity',
          'connection.capabilities',
          'connection.principals',
          'transfer.import',
          'transfer.retained',
          'transfer.sql',
          'backup.dump',
          'backup.restore',
          'view.results',
          'result.plan',
        };
        final command = hint['command'];
        final owner = openTask(
          kind,
          hint['title'] as String,
          profileId: hint['profile'] as String,
          restoredId: hint['id'] as String,
          reuse: false,
          payload: RestoredTaskReference(
            command is String && allowed.contains(command) ? command : '',
          ),
        );
        owner.reopenCommandId = command is String && allowed.contains(command)
            ? command
            : '';
        final schema = hint['schema'];
        if (schema is String &&
            schema.length <= 1024 &&
            !schema.contains('\u0000')) {
          owner.referenceSchema = schema;
        }
        _unadoptedTaskHints.remove(hint);
      } catch (_) {
        status =
            'A tool document could not be restored; its recovery record is preserved.';
      }
    }
    activeTaskId = null;
    notifyListeners();
  }

  Future<void> restart() async {
    invalidateAnalysis();
    backendStatusVerified = false;
    _backendPaint?.cancel();
    _backendPaint = null;
    final previous = backend;
    backend = null;
    await previous?.close();
    sessions.clear();
    explorerSessions.clear();
    for (final owner in operationOwners) {
      owner.sessionId = null;
    }
    cache.clear();
    sourceRowMappings.clear();
    resultViews.clear();
    cacheGeneration++;
    cacheBytes = 0;
    loading.clear();
    pageErrors.clear();
    _waitingPageRows.clear();
    _knownFetchedRows.clear();
    _maximumRowBytes.clear();
    selectedResults.clear();
    disposedResults.clear();
    jobs.clear();
    retainedResults.clear();
    _retainedViews.clear();
    jobDocuments.clear();
    submissions.clear();
    latestExecutions.clear();
    selectedExecutions.clear();
    browseReplacements.clear();
    for (final d in documents) {
      d.sessionId = null;
    }
    try {
      backend = await launchBackend(support);
      final launched = backend!;
      launched.process.exitCode.then((_) {
        if (_disposed || !identical(backend, launched)) return;
        backend = null;
        invalidateAnalysis();
        sessions.clear();
        for (final entry in jobs.entries.toList()) {
          if ([
            'QUEUED',
            'EXECUTING',
            'FETCHING',
            'CANCELLING',
          ].contains(entry.value.state.name)) {
            jobs[entry.key] = entry.value.deepCopy()
              ..state = JobState.UNKNOWN_OUTCOME;
          }
        }
        for (final d in operationOwners) {
          d.sessionId = null;
        }
        explorerSessions.clear();
        for (final batch in editBatches.values) {
          if (batch.applying) {
            batch.outcomeUnknown = true;
            batch.applying = false;
          }
        }
        status =
            'Backend exited. Sessions disconnected; writes may have unknown outcomes. Drafts preserved. Restart never replays SQL.';
        notifyListeners();
      });
      profiles
        ..clear()
        ..addAll(
          (await backend!.client.profiles(
            ProfileRequest(context: context),
          )).profiles,
        );
      await refreshEditDrafts();
      status = 'Ready';
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(milliseconds: 500), (_) => poll());
    } catch (e) {
      status = 'Backend startup failed: ${operationFailureSummary(e)}';
    }
    notifyListeners();
  }

  void newDocument({String text = '', String? path}) {
    _startRequested = false;
    documentBudget.requireAdditional(1, text.length * (path == null ? 1 : 2));
    final d = SqlDocument(text: text, path: path);
    adoptDocuments([d], notify: false);
    if (text.isNotEmpty || documents.length > 1) {
      _queueDraftRecovery();
    }
    notifyListeners();
  }

  /// Presentation navigation only. The mounted inspector retains request and
  /// session validation, generation admission and evidence ownership.
  void inspectStructureSection(WorkbenchDocument owner, int section) {
    if (!taskDocuments.contains(owner) || owner.object == null) return;
    owner.view.structureSection = section;
    owner.view.metadataRevision++;
    notifyListeners();
  }

  /// Takes the entire disconnected cohort or disposes it without changing tabs.
  void adoptDocuments(List<SqlDocument> incoming, {bool notify = true}) {
    try {
      if (_disposed ||
          incoming.any((d) => d.sessionId != null) ||
          incoming.map((d) => d.id).toSet().length != incoming.length ||
          incoming.any((d) => documents.any((old) => old.id == d.id))) {
        throw StateError(
          'Cannot adopt closed, duplicate, or connected documents',
        );
      }
      documentBudget.attachAll(incoming);
    } catch (_) {
      for (final document in incoming) {
        if (!documents.contains(document)) document.dispose();
      }
      rethrow;
    }
    documents.addAll(incoming);
    // Admit restored names before allocating any missing legacy names. Closing
    // or reordering another document can never change an assigned name.
    for (final document in incoming) {
      final number = document.untitledNumber;
      if (number != null && number > _querySequence) _querySequence = number;
    }
    for (final document in incoming) {
      if (document.path == null && document.untitledNumber == null) {
        document.untitledNumber = ++_querySequence;
      }
      _listen(document);
    }
    if (incoming.isNotEmpty) {
      selected = documents.length - 1;
      activeTaskId = null;
      // Adoption selects a new SQL owner just as an explicit tab switch does.
      // Cancel every operation for the previous owner, including formatting,
      // while keeping independent services concurrent within the active owner.
      invalidateAnalysis();
    }
    if (notify) {
      _queueDraftRecovery();
      notifyListeners();
    }
  }

  Future<void> closeDocument(
    SqlDocument target, {
    required int reviewedRevision,
    bool discardText = false,
    bool resolveSession = false,
    bool disconnectUncertain = false,
    bool preserveEdits = false,
  }) async {
    if (!documents.contains(target) || !closingDocuments.add(target.id)) return;
    final process = backend;
    try {
      await target.writesFinished;
      if (!discardText && target.lastSaveError != null) {
        throw target.lastSaveError!;
      }
      if (target.version != reviewedRevision ||
          (target.dirty && !discardText)) {
        throw StateError(
          'SQL changed or remains unsaved; review this tab again before closing',
        );
      }
      if ((pendingCommands[target.id] ?? 0) != 0) {
        throw StateError(
          'Wait for the operation acknowledgement before closing this tab',
        );
      }
      _connectionGeneration[target.id] =
          (_connectionGeneration[target.id] ?? 0) + 1;
      await _connectionTails[target.id]?.timeout(const Duration(seconds: 30));
      if (!identical(backend, process)) {
        throw StateError(
          'Backend changed while closing; inspect uncertain sessions',
        );
      }
      final ownedBatches = editBatches.values
          .where((b) => b.ownerId == target.id)
          .toList();
      for (final batch in ownedBatches) {
        if ((batch.changes.isNotEmpty && !preserveEdits) || batch.applying) {
          throw StateError(
            'Apply, preserve, or explicitly discard this tab’s staged edits first',
          );
        }
        await awaitStagedSave(batch: batch);
        if (batch.changes.isNotEmpty && batch.draftId == null) {
          throw StateError(
            'Staged edit recovery is unavailable; this tab remains open',
          );
        }
      }
      final id = target.sessionId;
      final ownsSession =
          id != null &&
          !operationOwners.any((d) => d.id != target.id && d.sessionId == id);
      if (ownsSession && process != null) {
        final active = jobs.values
            .where((j) => j.sessionId == id && !terminalJob(j.state))
            .toList();
        if (active.isNotEmpty && !resolveSession) {
          throw StateError(
            'Resolve active jobs before closing their last console',
          );
        }
        for (final job in active) {
          jobs[job.jobId] = await process.client.cancel(
            JobRequest(context: process.context(), jobId: job.jobId),
          );
        }
        final deadline = DateTime.now().add(const Duration(seconds: 10));
        while (jobs.values.any(
          (j) => j.sessionId == id && !terminalJob(j.state),
        )) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError(
              'Cancellation is still pending; the tab remains open',
            );
          }
          await poll();
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        final physicalOwner = sessions[id]?.deepCopy();
        var state = await process.client.session(
          SessionRequest(context: process.context(), sessionId: id),
        );
        _requireSessionSource(process, state, id: id, previous: physicalOwner);
        sessions[id] = state;
        if (state.transaction == TransactionState.ACTIVE ||
            state.transaction == TransactionState.FAILED_TRANSACTION) {
          if (!resolveSession) {
            throw StateError(
              'Rollback or commit this transaction before closing its last console',
            );
          }
          final rollback = SessionRequest(
            context: process.context(),
            sessionId: id,
            action: SessionAction.ROLLBACK,
          );
          rollback.approvalToken = (await process.client.reviewSession(
            rollback,
          )).token;
          try {
            final beforeRollback = state;
            state = await process.client.session(rollback);
            _requireSessionSource(
              process,
              state,
              id: id,
              previous: beforeRollback,
            );
            sessions[id] = state;
          } catch (_) {
            await poll();
            rethrow;
          }
        }
        if (state.transaction == TransactionState.UNKNOWN_TRANSACTION &&
            !disconnectUncertain) {
          throw StateError(
            'The transaction outcome is unknown; explicitly review disconnecting without replay',
          );
        }
        final disconnect = SessionRequest(
          context: process.context(),
          sessionId: id,
          action: SessionAction.DISCONNECT,
          force:
              state.transaction == TransactionState.UNKNOWN_TRANSACTION &&
              disconnectUncertain,
        );
        disconnect.approvalToken = (await process.client.reviewSession(
          disconnect,
        )).token;
        final closed = await process.client.session(disconnect);
        _requireSessionSource(
          process,
          closed,
          id: id,
          previous: state,
          disconnectAcknowledgement: true,
        );
        sessions.remove(id);
        target.sessionId = null;
      }
      if (target.version != reviewedRevision) {
        throw StateError('SQL changed during cleanup; this tab remains open');
      }
      final remaining = documents.where((d) => !identical(d, target)).toList();
      if (draftRecovery) {
        await drafts.save(
          remaining,
          selected.clamp(0, remaining.isEmpty ? 0 : remaining.length - 1),
          startupScratchId: untouchedStartupScratchId,
          unadopted: _unadoptedSqlDrafts,
        );
      }
      if (target.version != reviewedRevision) {
        await recoverNow();
        throw StateError(
          'SQL changed while saving recovery; this tab remains open',
        );
      }
      final selectedDocument = document;
      await disposeOwnerViews(
        _sqlOwners.putIfAbsent(target.id, () => WorkbenchDocument.sql(target)),
      );
      documents.remove(target);
      final closedOwner = _sqlOwners.remove(target.id);
      if (closedOwner != null) documentBudget.auxiliary(closedOwner, 0);
      editBatches.removeWhere((_, batch) => batch.ownerId == target.id);
      _retainedViews.remove(target.id);
      selectedResults.remove(target.id);
      selectedExecutions.remove(target.id);
      latestExecutions.remove(target.id);
      invalidateAnalysis();
      _analysisTimer?.cancel();
      target.dispose();
      if (documents.isEmpty) {
        newDocument();
      } else {
        selected = identical(selectedDocument, target)
            ? selected.clamp(0, documents.length - 1)
            : documents.indexOf(selectedDocument);
      }
      updateStatus(
        'SQL tab closed. Retained results remain available; SQL and transactions were not replayed.',
      );
    } finally {
      closingDocuments.remove(target.id);
      if (!_disposed) notifyListeners();
    }
  }

  void _listen(SqlDocument d) {
    d.editor.onChangeRejected = (error) {
      if (error is! DocumentResourceLimit) return false;
      updateStatus(error.message);
      return true;
    };
    var text = d.editor.text;
    var caret = d.caret;
    var secondarySelections = List.of(d.editor.value.secondarySelections);
    d.editor.addListener(() {
      final textChanged = text != d.editor.text;
      final caretChanged = caret != d.caret;
      final secondaryChanged = !listEquals(
        secondarySelections,
        d.editor.value.secondarySelections,
      );
      if (!textChanged && !caretChanged && !secondaryChanged) return;
      if (identical(d, document)) invalidateAnalysis();
      text = d.editor.text;
      caret = d.caret;
      secondarySelections = List.of(d.editor.value.secondarySelections);
      if (textChanged) {
        _queueDraftRecovery();
      }
      _analysisTimer?.cancel();
      _analysisTimer = Timer(
        const Duration(milliseconds: 350),
        () => analyze(d),
      );
      if (textChanged) notifyListeners();
    });
  }

  void select(int index) {
    _startRequested = false;
    activeTaskId = null;
    invalidateAnalysis();
    selected = index;
    if (documents.length > 1 || document.editor.text.isNotEmpty) {
      _queueDraftRecovery();
    }
    notifyListeners();
  }

  void _queueDraftRecovery() {
    _draftTimer?.cancel();
    if (!draftRecovery || _disposed) return;
    _draftTimer = Timer(const Duration(milliseconds: 400), () {
      recoverNow().catchError((_) {
        if (!_disposed) {
          status = 'Draft recovery save failed';
          notifyListeners();
        }
      });
    });
  }

  void bindUnconnectedProfile(WorkbenchDocument owner, String profileId) {
    if (!operationOwners.contains(owner) ||
        owner.sessionId != null ||
        !profiles.any((p) => p.id == profileId)) {
      throw StateError(
        'The document must be unconnected before choosing its saved profile',
      );
    }
    if (owner.profileId != profileId && owner.sql != null) {
      owner.sql!.connectionCatalog = '';
      owner.sql!.connectionSchema = '';
    }
    owner.profileId = profileId;
    owner.evidenceProfile = null;
    invalidateAnalysis();
    _queueDraftRecovery();
    notifyListeners();
  }

  final _commandOwners = <String>{};
  bool commandPendingForOwner(String id) => _commandOwners.contains(id);
  bool get activeCommandPending => _commandOwners.contains(
    documents.isEmpty && taskDocuments.isEmpty ? 'application' : activeOwner.id,
  );
  Future<void> command(
    Future<void> Function() operation, {
    String? ownerId,
    String Function(Object)? errorText,
  }) async {
    final owner =
        ownerId ??
        (documents.isEmpty && taskDocuments.isEmpty
            ? 'application'
            : activeOwner.id);
    if (!_commandOwners.add(owner)) return;
    busy = true;
    notifyListeners();
    try {
      await operation();
    } catch (e) {
      status = errorText?.call(e) ?? operationFailureSummary(e);
    } finally {
      _commandOwners.remove(owner);
      busy = _commandOwners.isNotEmpty;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> saveProfile(Profile profile) async {
    final process = backend!;
    final result = await process.client.profiles(
      ProfileRequest(
        context: process.context(),
        action: ProfileAction.SAVE_PROFILE,
        profile: profile.deepCopy(),
      ),
    );
    if (!identical(backend, process)) {
      throw StateError(
        'Backend changed while saving the profile; inspect the saved profile before changing credentials',
      );
    }
    profiles
      ..clear()
      ..addAll(result.profiles);
  }

  Future<void> _profileSave = Future<void>.value();
  int _pendingProfileSaves = 0;
  Future<Profile> saveProfileCredentials(
    Profile profile,
    String password, {
    required bool remember,
    String tlsKeyPassword = '',
    bool? rememberTlsKey,
  }) {
    final captured = profile.deepCopy(), process = backend!;
    if (rememberTlsKey != null) {
      captured.tls = captured.tls.deepCopy();
    }
    _pendingProfileSaves++;
    notifyListeners();
    final operation = _profileSave.then((_) async {
      if (!identical(backend, process)) {
        throw StateError('Backend changed before profile saving');
      }
      final previous = <String, String>{
        'database': captured.credentialRef,
        'tls-key': captured.tls.keyCredentialRef,
      };
      final replacements = <String, String>{};
      var metadataAttempted = false, confirmed = false;
      try {
        for (final purpose in previous.keys) {
          final persist = purpose == 'database' ? remember : rememberTlsKey;
          if (persist == null) {
            continue; // Existing callers preserve unrelated bindings.
          }
          final supplied = purpose == 'database' ? password : tlsKeyPassword;
          String binding = previous[purpose]!;
          if (persist && (supplied.isNotEmpty || binding.isEmpty)) {
            binding = 'busydata.$purpose.${const Uuid().v4()}';
            replacements[purpose] = binding;
            await secrets.write(binding, supplied);
          } else if (!persist) {
            binding = '';
          }
          if (purpose == 'database') {
            captured.credentialRef = binding;
          } else {
            captured.tls.keyCredentialRef = binding;
          }
        }
        if (!identical(backend, process)) {
          throw StateError('Backend changed before profile persistence');
        }
        metadataAttempted = true;
        await saveProfile(captured);
        confirmed = true;
      } catch (primary) {
        if (metadataAttempted) {
          try {
            if (!identical(backend, process)) {
              throw StateError('Backend replaced');
            }
            final current = await process.client.profiles(
              ProfileRequest(context: process.context()),
            );
            if (!identical(backend, process)) {
              throw StateError('Backend replaced');
            }
            final persisted = current.profiles
                .where((p) => p.id == captured.id)
                .firstOrNull;
            if (persisted != null &&
                sameProfileConfiguration(persisted, captured)) {
              profiles
                ..clear()
                ..addAll(current.profiles);
              confirmed = true;
            } else if (persisted != null &&
                replacements.values.any(
                  (binding) =>
                      persisted.credentialRef == binding ||
                      persisted.tls.keyCredentialRef == binding,
                )) {
              throw StateError('Replacement credential is still bound');
            }
          } catch (_) {
            // A lost acknowledgement must not delete a password that may now be
            // referenced by Java's committed profile. Keep both records safely.
            throw ProfileSaveUncertain(primary);
          }
        }
        if (!confirmed) {
          for (final replacement in replacements.values) {
            try {
              await secrets.delete(replacement);
            } catch (_) {
              /* Unbound record retained; never delete the working binding. */
            }
          }
          if (!metadataAttempted && primary is! StateError) {
            throw CredentialStorageFailure(primary);
          }
          rethrow;
        }
      }
      for (final purpose in previous.keys) {
        final current = purpose == 'database'
            ? captured.credentialRef
            : captured.tls.keyCredentialRef;
        if (previous[purpose]!.isNotEmpty && previous[purpose] != current) {
          try {
            await secrets.delete(previous[purpose]!);
          } catch (_) {
            /* Keep acknowledged profile usable if obsolete-record cleanup fails. */
          }
        }
      }
      return captured;
    });
    _profileSave = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation.whenComplete(() {
      _pendingProfileSaves--;
      if (!_disposed) notifyListeners();
    });
  }

  Future<void> _disconnectOwned(
    BackendConnection process,
    String id,
    SessionInfo expected, {
    bool unpublished = false,
  }) async {
    final captured = expected.deepCopy();
    final request = SessionRequest(
      context: process.context(),
      sessionId: id,
      action: SessionAction.DISCONNECT,
    );
    request.approvalToken = (await process.client.reviewSession(request)).token;
    final closed = await process.client.session(request);
    if (unpublished) {
      // A verified unused Open belongs to this captured physical channel even
      // after the UI moves to a replacement backend. This never admits state.
      _requireSessionEnvelope(process, closed, id: id, previous: captured);
    } else {
      _requireSessionSource(
        process,
        closed,
        id: id,
        previous: captured,
        disconnectAcknowledgement: true,
      );
    }
    if (closed.transaction != TransactionState.DISCONNECTED) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.unavailable);
    }
  }

  void _rememberConsoleScope(SqlDocument? document, SessionInfo? acknowledged) {
    if (document == null ||
        acknowledged == null ||
        acknowledged.currentCatalog.isEmpty) {
      return;
    }
    document.connectionCatalog = acknowledged.currentCatalog;
    document.connectionSchema = acknowledged.currentSchema;
  }

  Future<void> connect(
    Profile profile,
    String password, {
    String sshPassword = '',
    String keyPassphrase = '',
    String tlsKeyPassword = '',
    SqlDocument? targetDocument,
    WorkbenchDocument? targetOwner,
    BackendConnection? expectedBackend,
    CapturedWorkbenchTarget? intendedTarget,
    bool Function()? mayAdopt,
  }) {
    final target =
            targetOwner ??
            _sqlOwners.putIfAbsent(
              (targetDocument ?? document).id,
              () => WorkbenchDocument.sql(targetDocument ?? document),
            ),
        process = backend!;
    final capturedProfile = profile.deepCopy();
    final requestedOwnerProfile = target.profileId,
        requestedOwnerSession = target.sessionId;
    final requestedScope = (
      target.sql?.connectionCatalog,
      target.sql?.connectionSchema,
    );
    if (intendedTarget != null && !intendedTarget.references(target)) {
      throw StateError('The connection intent belongs to another document');
    }
    bool intentCurrent({bool retired = false}) {
      if (intendedTarget == null) return true;
      try {
        _requireTarget(
          intendedTarget,
          text: true,
          acknowledgedRetiredSession: retired ? requestedOwnerSession : null,
        );
        return requestedScope ==
            (target.sql?.connectionCatalog, target.sql?.connectionSchema);
      } catch (_) {
        return false;
      }
    }

    if (target.sessionId == null) {
      requireDocumentTarget(target, capturedProfile);
    }
    if (expectedBackend != null && !identical(expectedBackend, process)) {
      throw StateError(
        'Backend changed during credential retrieval; explicitly reconnect again',
      );
    }
    final generation = (_connectionGeneration[target.id] ?? 0) + 1;
    _connectionGeneration[target.id] = generation;
    final previous = _connectionTails[target.id] ?? Future<void>.value();
    bool current() =>
        !_disposed &&
        identical(backend, process) &&
        operationOwners.any((d) => identical(d, target)) &&
        !closingDocuments.contains(target.id) &&
        target.profileId == requestedOwnerProfile &&
        target.sessionId == requestedOwnerSession &&
        (mayAdopt?.call() ?? true) &&
        intentCurrent() &&
        _connectionGeneration[target.id] == generation;
    final operation = previous.then((_) async {
      if (!current()) return;
      final existing = target.sessionId;
      if (existing != null) {
        final previousOwner = sessions[existing]?.deepCopy();
        final state = await process.client.session(
          SessionRequest(context: process.context(), sessionId: existing),
        );
        if (!current()) return;
        _requireSessionSource(
          process,
          state,
          id: existing,
          previous: previousOwner,
        );
        sessions[existing] = state;
        if (state.transaction != TransactionState.IDLE ||
            jobs.values.any(
              (j) => j.sessionId == existing && !terminalJob(j.state),
            ) ||
            (editBatches.values.any(
              (b) => b.changes.isNotEmpty && b.sessionId == existing,
            ))) {
          throw StateError(
            'Resolve the existing transaction, jobs, and staged changes before reconnecting. The current session remains attached.',
          );
        }
      }
      if (sessions.length >= 8) {
        throw StateError(
          'All eight owned session slots are in use, including uncertain sessions. Resolve or disconnect a session before connecting independently.',
        );
      }
      final opened = await process.client
          .openSession(
            OpenRequest(
              context: process.context(),
              profile: capturedProfile,
              password: password,
              sshPassword: sshPassword,
              keyPassphrase: keyPassphrase,
              tlsKeyPassword: tlsKeyPassword,
              catalog:
                  target.sql?.connectionCatalog ??
                  target.object?.catalog ??
                  target.creationScope?.catalog ??
                  '',
              schema:
                  target.sql?.connectionSchema ??
                  (capturedProfile.engine == Engine.POSTGRESQL
                      ? target.object?.schema ??
                            target.creationScope?.schema ??
                            ''
                      : ''),
            ),
          )
          .catchError(
            (Object failure) =>
                throw ConnectionAttemptFailure(capturedProfile.name, failure),
          );
      // Verify the reply on its captured channel before acquiring cleanup
      // ownership. UI adoption below still requires the current backend.
      _requireSessionEnvelope(
        process,
        opened,
        id: opened.sessionId,
        profile: capturedProfile,
      );
      if (identical(backend, process) &&
          sessions.containsKey(opened.sessionId)) {
        throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
      }
      bool adopted = false, disconnectedExisting = false;
      Object? primaryFailure;
      try {
        if (!current()) return;
        final accepted = await process.client.session(
          SessionRequest(
            context: process.context(),
            sessionId: opened.sessionId,
            action: SessionAction.ADOPT_SESSION,
          ),
        );
        if (!current()) return;
        _requireSessionSource(
          process,
          accepted,
          id: opened.sessionId,
          previous: opened,
          profile: opened.profile,
          pendingOpen: true,
        );
        if (existing != null &&
            !operationOwners.any(
              (d) => !identical(d, target) && d.sessionId == existing,
            )) {
          // Reviewed disconnect rejects a transaction or intervening SQL that
          // began during opening; failure preserves the previous association.
          await _disconnectOwned(process, existing, sessions[existing]!);
          disconnectedExisting = true;
          if (identical(backend, process)) sessions.remove(existing);
        }
        // Revalidate intent after retirement without requiring metadata for
        // the physical session this operation has acknowledged removing.
        if (_disposed ||
            !(mayAdopt?.call() ?? true) ||
            !intentCurrent(retired: disconnectedExisting) ||
            _connectionGeneration[target.id] != generation ||
            !identical(backend, process) ||
            !operationOwners.any((d) => identical(d, target)) ||
            closingDocuments.contains(target.id) ||
            target.profileId != requestedOwnerProfile ||
            target.sessionId != requestedOwnerSession) {
          // The old disconnect is an acknowledged effect even if the caller
          // cancelled or rebound while waiting. Do not retain its stale ID,
          // attach the replacement elsewhere, or alter a newer backend owner.
          if (!_disposed &&
              identical(backend, process) &&
              operationOwners.any((d) => identical(d, target)) &&
              disconnectedExisting &&
              target.sessionId == existing) {
            target.sessionId = null;
            invalidateAnalysis();
            _queueDraftRecovery();
            notifyListeners();
          }
          return;
        }
        sessions[opened.sessionId] = accepted;
        target.sessionId = opened.sessionId;
        target.profileId = capturedProfile.id;
        target.evidenceProfile = capturedProfile.deepCopy();
        _rememberConsoleScope(target.sql, accepted);
        if (identical(target.sql, document)) {
          invalidateAnalysis();
        }
        adopted = true;
        status =
            'Connected ${opened.database.product} ${opened.database.version} · ${opened.currentCatalog}/${opened.currentSchema}';
        _queueDraftRecovery();
        notifyListeners();
      } catch (failure) {
        primaryFailure = failure;
        rethrow;
      } finally {
        if (!adopted) {
          try {
            await _disconnectOwned(
              process,
              opened.sessionId,
              opened,
              unpublished: true,
            );
          } catch (cleanup, stack) {
            if (!_disposed &&
                identical(backend, process) &&
                !sessions.containsKey(opened.sessionId)) {
              sessions[opened.sessionId] = opened.deepCopy()
                ..transaction = TransactionState.UNKNOWN_TRANSACTION;
              status =
                  'Unused connection cleanup was not acknowledged. The session remains visible in Connections for reviewed disconnect; SQL is prohibited.';
              notifyListeners();
            }
            if (primaryFailure == null) {
              Error.throwWithStackTrace(cleanup, stack);
            }
          }
        }
      }
    });
    // Preserve each caller's failure while allowing a later explicit attempt.
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _connectionTails[target.id] = tail;
    tail.whenComplete(() {
      if (identical(_connectionTails[target.id], tail)) {
        _connectionTails.remove(target.id);
      }
    });
    return operation.catchError((Object error) {
      if (error is GrpcError) {
        throw ConnectionAttemptFailure(capturedProfile.name, error);
      }
      throw error;
    });
  }

  Future<void> disconnectRetainedSession(
    String id, {
    CapturedWorkbenchTarget? reviewedTarget,
  }) async {
    final captured = reviewedTarget ?? captureSessionTarget(id),
        process = captured.backend;
    if (!captured.sessionOnly || captured.sessionId != id) {
      throw StateError('Disconnect requires its captured physical session');
    }
    await ownedRequest(captured, () async {
      final request = SessionRequest(
        context: process.context(),
        sessionId: id,
        action: SessionAction.DISCONNECT,
        force:
            sessions[id]?.transaction == TransactionState.UNKNOWN_TRANSACTION,
      );
      request.approvalToken = (await process.client.reviewSession(
        request,
      )).token;
      requireTarget(captured);
      final closed = await process.client.session(request);
      _requireSessionSource(
        process,
        closed,
        id: id,
        previous: captured.session,
        disconnectAcknowledgement: true,
      );
      if (!identical(backend, process) ||
          closed.transaction != TransactionState.DISCONNECTED) {
        throw StateError(
          'Disconnect was not acknowledged; the session remains visible',
        );
      }
      sessions.remove(id);
      explorerSessions.removeWhere((_, value) => value == id);
      for (final doc in operationOwners.where((doc) => doc.sessionId == id)) {
        _rememberConsoleScope(doc.sql, captured.session);
        doc.sessionId = null;
      }
      invalidateAnalysis();
      _queueDraftRecovery();
      status = closed.commandWarning.isEmpty
          ? 'Physical session disconnected'
          : closed.commandWarning;
    });
  }

  static bool terminalJob(JobState state) => const [
    JobState.COMPLETED,
    JobState.FAILED,
    JobState.CANCELLED,
    JobState.INTERRUPTED,
    JobState.UNKNOWN_OUTCOME,
  ].contains(state);

  static bool problemJob(JobState state) => const {
    JobState.FAILED,
    JobState.INTERRUPTED,
    JobState.UNKNOWN_OUTCOME,
  }.contains(state);

  ExecuteRequest execution(ExecutionMode mode, {SqlDocument? document}) {
    document ??= this.document;
    final view = workbenchDocuments
        .firstWhere((d) => d.id == document!.id)
        .view;
    final sql = mode == ExecutionMode.SELECTION
        ? document.editor.selectedText
        : document.editor.text;
    validateSqlUnicode(sql, maxUtf8Bytes: maxSqlRpcBytes);
    return ExecuteRequest(
      context: context,
      sessionId: document.sessionId,
      executionId: const Uuid().v4(),
      sql: sql,
      documentId: document.id,
      documentVersion: Int64(document.version),
      mode: mode,
      caretUtf16: document.caret,
      rowLimit: Int64(view.rowLimit ?? _defaultRowLimit),
      errorPolicy: view.errorPolicy ?? _defaultErrorPolicy,
      streamingRead: view.streaming,
    );
  }

  void track(JobInfo job, {String? documentId}) {
    _jobOwnershipRevision++;
    if (job.sessionId == document.sessionId) invalidateAnalysis();
    jobs[job.jobId] = _acknowledgedJob(job, retainedResults);
    jobDocuments[job.jobId] = documentId ?? document.id;
    latestExecutions[documentId ?? document.id] = job.executionId;
    _tableDataOutcome(job, documentId ?? document.id);

    status = 'Execution submitted';
    notifyListeners();
  }

  void _tableDataOutcome(JobInfo job, String? ownerId) {
    final owner = taskDocuments.where((d) => d.id == ownerId).firstOrNull;
    if (owner?.kind != WorkbenchDocumentKind.table ||
        latestExecutions[ownerId] != job.executionId ||
        !terminalJob(job.state)) {
      return;
    }
    owner!.view.dataError = job.state == JobState.COMPLETED
        ? ''
        : job.state == JobState.UNKNOWN_OUTCOME
        ? 'Table operation outcome is unknown. Resolve the owned session before retrying.'
        : 'Table data could not be loaded. Retry the request or inspect its messages.';
  }

  Future<void> submit(ExecuteRequest request) async {
    final process = backend!;
    final targetDocument = documents
        .where((d) => d.id == request.documentId)
        .firstOrNull;
    if (targetDocument == null ||
        closingDocuments.contains(targetDocument.id) ||
        request.context.instanceId != process.instanceId ||
        targetDocument.sessionId != request.sessionId ||
        targetDocument.version != request.documentVersion.toInt()) {
      throw StateError('Execution target changed; request a fresh review');
    }
    final target = CapturedWorkbenchTarget(
      process,
      targetDocument,
      targetDocument.version,
      targetDocument.sessionId,
      sessions[targetDocument.sessionId]?.contextRevision ?? Int64.ZERO,
    );
    submissions[request.executionId] = request.documentId;
    final job = await ownedRequest(
      target,
      () => process.client.execute(request),
      text: true,
    );
    if (!identical(backend, process)) {
      throw StateError('Backend changed; execution outcome may be unknown');
    }
    _selectExecutionOutput(
      _sqlOwners.putIfAbsent(
        targetDocument.id,
        () => WorkbenchDocument.sql(targetDocument),
      ),
      request.executionId,
    );
    track(job, documentId: request.documentId);
  }

  Future<void>? _pollRequest;
  int _jobOwnershipRevision = 0;
  Future<void> poll() => _pollRequest ??= _pollFreshCatalog().whenComplete(
    () => _pollRequest = null,
  );

  Future<void> _pollFreshCatalog() async {
    // A submission can complete while an older read-only catalog RPC is in
    // flight. Never apply that older snapshot over the newly owned job. One
    // bounded refresh resolves the usual race; continuous submissions leave
    // status unverified until a later poll rather than replaying any operation.
    for (var attempt = 0; attempt < 2; attempt++) {
      final revision = _jobOwnershipRevision;
      await _pollOnce(revision);
      if (_disposed || backend == null || revision == _jobOwnershipRevision) {
        return;
      }
    }
  }

  Future<void> _pollOnce(int ownershipRevision) async {
    final process = backend;
    if (process == null) return;
    backendStatusVerified = false;
    try {
      final list = JobList();
      int jobOffset = 0, jobBytes = 0;
      Int64 jobRevision = Int64.ZERO;
      final jobIds = <String>{};
      while (true) {
        final page = await process.client.jobs(
          JobRequest(
            context: process.context(),
            offset: jobOffset,
            limit: 32,
            catalogRevision: jobRevision,
          ),
        );
        if (!identical(backend, process) || _disposed) return;
        if (page.writeToBuffer().length > 1048576) {
          throw StateError('Job catalog page exceeds 1MiB');
        }
        jobRevision = page.catalogRevision;
        for (final job in page.jobs) {
          jobBytes += job.writeToBuffer().length;
          if (jobIds.length >= 128 ||
              jobBytes > 8 * 1024 * 1024 ||
              !jobIds.add(job.jobId)) {
            throw StateError(
              'Job catalog exceeds its bounded ownership budget',
            );
          }
          list.jobs.add(job);
        }
        if (page.catalogRevision == Int64.ZERO) {
          throw StateError('Job catalog has no backend revision');
        }
        if (page.complete) break;
        if (page.nextOffset <= jobOffset) {
          throw StateError('Job catalog did not advance');
        }
        jobOffset = page.nextOffset;
      }
      if (!identical(backend, process)) return;
      final catalog = <String, RetainedResult>{};
      int offset = 0, retainedBytes = 0;
      Int64 revision = Int64.ZERO;
      while (true) {
        final page = await process.client.retainedResults(
          RetainedRequest(
            context: process.context(),
            offset: offset,
            limit: 32,
            catalogRevision: revision,
          ),
        );
        if (!identical(backend, process) || _disposed) return;
        if (page.writeToBuffer().length > 1048576) {
          throw StateError('Retained catalog page exceeds byte budget');
        }
        revision = page.catalogRevision;
        for (final entry in page.results) {
          if (catalog.containsKey(entry.result.resultId)) {
            throw StateError('Duplicate retained result');
          }
          retainedBytes += entry.writeToBuffer().length;
          if (catalog.length >= 64 || retainedBytes > 17 * 1024 * 1024) {
            throw StateError('Retained catalog budget exceeded');
          }
          catalog[entry.result.resultId] = entry;
        }
        if (page.complete) break;
        if (page.nextOffset <= offset) {
          throw StateError('Retained catalog did not advance');
        }
        offset = page.nextOffset;
      }
      if (ownershipRevision != _jobOwnershipRevision ||
          !identical(backend, process) ||
          _disposed) {
        return;
      }
      for (final j in list.jobs) {
        jobs[j.jobId] = _acknowledgedJob(j, catalog);
        for (final result in j.results) {
          final known = _knownFetchedRows[result.resultId] ?? 0;
          if (result.fetchedRows.toInt() > known) {
            _knownFetchedRows[result.resultId] = result.fetchedRows.toInt();
          }
        }
        final owner = submissions[j.executionId] ?? jobDocuments[j.jobId];
        if (owner != null) jobDocuments[j.jobId] = owner;
        _tableDataOutcome(j, owner);
        final replacement = browseReplacements[owner];
        if (replacement != null &&
            replacement.execution == j.executionId &&
            (j.results.any(
                  (r) =>
                      r.resultId.isNotEmpty &&
                      r.columns.isNotEmpty &&
                      (r.fetchedRows > Int64.ZERO || r.complete),
                ) ||
                terminalJob(j.state))) {
          final document = workbenchDocuments
              .where((d) => d.id == owner)
              .firstOrNull;
          if (document != null &&
              document.view.executionSelectionRevision ==
                  replacement.selectionRevision &&
              selectedExecutions[owner] == replacement.previous &&
              j.results.any((r) => r.resultId.isNotEmpty)) {
            _selectExecutionOutput(document, j.executionId);
          }
          browseReplacements.remove(owner);
        }
      }
      retainedResults
        ..clear()
        ..addAll(catalog);
      final retained = list.jobs.map((j) => j.jobId).toSet();
      jobs.removeWhere((id, job) => !retained.contains(id));
      jobDocuments.removeWhere(
        (id, owner) =>
            !retained.contains(id) && !catalog.values.any((r) => r.jobId == id),
      );
      final executions = {
        ...list.jobs.map((j) => j.executionId),
        ...catalog.values.map((r) => r.executionId),
      };
      selectedExecutions.removeWhere((_, id) => !executions.contains(id));
      for (final owner in workbenchDocuments) {
        owner.view.tableQueries.removeWhere(
          (id, _) => !executions.contains(id),
        );
        owner.view.executionOutputs.removeWhere(
          (id, _) => !executions.contains(id),
        );
      }
      submissions.removeWhere(
        (id, owner) =>
            !executions.contains(id) && latestExecutions[owner] != id,
      );
      final liveResults = {
        ...catalog.keys,
        ...list.jobs.expand((j) => j.results.map((r) => r.resultId)),
        ...resultViews.keys,
        ...resultViews.values.map((v) => v.resultId),
        ...workbenchDocuments
            .map((d) => d.retained?.result.resultId)
            .whereType<String>(),
        ...editBatches.values.where((b) => b.unresolved).map((b) => b.resultId),
        ...loading.map((key) => key.substring(0, key.lastIndexOf(':'))),
      };
      // A past session association is not a retention lease. Keep every actual
      // intention, recovery record, pending acknowledgement and unknown outcome.
      editBatches.removeWhere(
        (_, b) => !liveResults.contains(b.resultId) && !b.unresolved,
      );
      disposedResults.removeWhere((id) => !liveResults.contains(id));
      pageErrors.removeWhere((id, _) => !liveResults.contains(id));
      _knownFetchedRows.removeWhere((id, _) => !liveResults.contains(id));
      _maximumRowBytes.removeWhere((id, _) => !liveResults.contains(id));
      _waitingPageRows.removeWhere(
        (key, _) =>
            !liveResults.contains(key.substring(0, key.lastIndexOf(':'))),
      );
      for (final owner in workbenchDocuments) {
        final removed = owner.view.results.entries
            .where((e) => !liveResults.contains(e.key))
            .any((e) => e.value.planEvidenceUnits != 0);
        owner.view.results.removeWhere((id, _) => !liveResults.contains(id));
        if (removed) _chargeOwnerEvidence(owner);
      }
      var sessionStatusesVerified = true;
      for (final id in sessions.keys.toList()) {
        final requested = sessions[id];
        if (requested == null) {
          sessionStatusesVerified = false;
          continue;
        }
        final profile = requested.profile.deepCopy();
        final sourceIdentity = requested.metadataSourceIdentity;
        final requestedRevision = requested.sessionRevision;
        final requestedContext = requested.contextRevision;
        final requestedState = requested.transaction;
        final s = await process.client.session(
          SessionRequest(context: process.context(), sessionId: id),
        );
        if (!identical(backend, process) || _disposed) return;
        final prior = sessions[id];
        bool terminalStateRevived(TransactionState state) =>
            state == TransactionState.DISCONNECTED
            ? s.transaction != TransactionState.DISCONNECTED
            : state == TransactionState.UNKNOWN_TRANSACTION &&
                  s.transaction != TransactionState.UNKNOWN_TRANSACTION &&
                  s.transaction != TransactionState.DISCONNECTED;
        // A read begun before an acknowledgement must not regress its owner,
        // revive a retired session, or clear sticky uncertainty. A later
        // ordinary status poll can reconcile without replaying any operation.
        if (prior == null ||
            prior.sessionId != id ||
            s.sessionId != id ||
            !sameProfileConfiguration(prior.profile, profile) ||
            !sameProfileConfiguration(s.profile, profile) ||
            prior.metadataSourceIdentity != sourceIdentity ||
            s.metadataSourceIdentity != sourceIdentity ||
            !_metadataPhysicalOwner(requested, process).wellFormed ||
            !_metadataPhysicalOwner(s, process).wellFormed ||
            s.sessionRevision.isNegative ||
            s.contextRevision.isNegative ||
            s.sessionRevision < requestedRevision ||
            s.contextRevision < requestedContext ||
            s.sessionRevision < prior.sessionRevision ||
            s.contextRevision < prior.contextRevision ||
            terminalStateRevived(requestedState) ||
            terminalStateRevived(prior.transaction)) {
          sessionStatusesVerified = false;
          continue;
        }
        sessions[id] = s;
        final terminalStateObserved =
            (s.transaction == TransactionState.UNKNOWN_TRANSACTION ||
                s.transaction == TransactionState.DISCONNECTED) &&
            (requestedState != s.transaction ||
                prior.transaction != s.transaction);
        if ((prior.contextRevision != s.contextRevision ||
                prior.sessionRevision != s.sessionRevision ||
                terminalStateObserved) &&
            document.sessionId == id) {
          invalidateAnalysis();
        }
      }
      backendStatusVerified =
          sessionStatusesVerified && ownershipRevision == _jobOwnershipRevision;
      _notifyBackendUpdate();
    } catch (_) {
      backendStatusVerified = false;
    }
  }

  Future<void> transaction(
    SessionAction action, {
    bool force = false,
    CapturedWorkbenchTarget? target,
  }) async {
    final captured = target ?? captureTarget(), process = captured.backend;
    final id = captured.sessionId;
    if (id == null) {
      throw StateError(
        'Connect this console before changing transaction state',
      );
    }
    final request = SessionRequest(
      context: process.context(),
      sessionId: id,
      action: action,
      force: force,
    );
    await ownedRequest(captured, () async {
      request.approvalToken = (await process.client.reviewSession(
        request,
      )).token;
      requireTarget(captured);
      final s = await process.client.session(request);
      _requireSessionSource(
        process,
        s,
        id: id,
        previous: captured.session,
        disconnectAcknowledgement: action == SessionAction.DISCONNECT,
      );
      if (!identical(backend, process)) {
        throw StateError(
          'Backend changed before the transaction acknowledgement; inspect the outcome, never repeat the command automatically',
        );
      }
      if (s.transaction == TransactionState.DISCONNECTED) {
        sessions.remove(id);
        for (final d in documents.where((d) => d.sessionId == id)) {
          _rememberConsoleScope(d, captured.session);
          d.sessionId = null;
        }
        _queueDraftRecovery();
      } else {
        sessions[id] = s;
      }
      invalidateAnalysis();
      status = s.commandWarning.isNotEmpty
          ? s.commandWarning
          : s.commandAcknowledged
          ? 'Session action acknowledged'
          : 'Session state updated';
    });
  }

  final _metadataRevisions = MetadataRevisionRegistry();

  MetadataPhysicalOwner _metadataPhysicalOwner(
    SessionInfo session,
    BackendConnection process,
  ) => MetadataPhysicalOwner(
    backendInstance: process.instanceId,
    profileId: session.profile.id,
    sourceIdentity: session.metadataSourceIdentity,
    sessionId: session.sessionId,
    sessionRevision: session.sessionRevision.toInt(),
    contextRevision: session.contextRevision.toInt(),
  );

  // Pure envelope validation confers no authority to publish UI or metadata
  // state. It also validates cleanup replies from the captured physical channel.
  void _requireSessionEnvelope(
    BackendConnection process,
    SessionInfo reply, {
    required String id,
    SessionInfo? previous,
    Profile? profile,
  }) {
    if (!_metadataPhysicalOwner(reply, process).wellFormed) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.malformedRequest,
      );
    }
    if (reply.sessionId != id ||
        profile != null && !sameProfileConfiguration(reply.profile, profile) ||
        previous != null &&
            (previous.sessionId != id ||
                !_metadataPhysicalOwner(previous, process).wellFormed ||
                reply.metadataSourceIdentity !=
                    previous.metadataSourceIdentity ||
                !sameProfileConfiguration(reply.profile, previous.profile))) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (previous == null) return;
    if (reply.sessionRevision < previous.sessionRevision ||
        reply.contextRevision < previous.contextRevision) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidRevision);
    }
    final revives = previous.transaction == TransactionState.DISCONNECTED
        ? reply.transaction != TransactionState.DISCONNECTED
        : previous.transaction == TransactionState.UNKNOWN_TRANSACTION &&
              reply.transaction != TransactionState.UNKNOWN_TRANSACTION &&
              reply.transaction != TransactionState.DISCONNECTED;
    if (revives) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.transactionUnknown,
      );
    }
  }

  void _requireSessionSource(
    BackendConnection process,
    SessionInfo reply, {
    required String id,
    SessionInfo? previous,
    Profile? profile,
    bool pendingOpen = false,
    bool disconnectAcknowledgement = false,
  }) {
    if (!identical(backend, process)) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.backendRestarted,
      );
    }
    _requireSessionEnvelope(
      process,
      reply,
      id: id,
      previous: previous,
      profile: profile,
    );
    if (pendingOpen) {
      if (sessions.containsKey(id)) {
        throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
      }
      return;
    }
    final current = sessions[id];
    if (previous == null ||
        current == null &&
            !(disconnectAcknowledgement &&
                reply.transaction == TransactionState.DISCONNECTED)) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (current == null) {
      return; // An exact reviewed disconnect is already retired; never reinsert it.
    }
    _requireSessionEnvelope(process, reply, id: id, previous: current);
  }

  WorkbenchFailureReason? metadataSessionUnavailableReason(String? sessionId) {
    final owner = sessions[sessionId];
    if (backend == null || owner == null || owner.sessionId != sessionId) {
      return WorkbenchFailureReason.unavailable;
    }
    if (!_metadataPhysicalOwner(owner, backend!).wellFormed) {
      return WorkbenchFailureReason.malformedRequest;
    }
    return switch (owner.transaction) {
      TransactionState.UNKNOWN_TRANSACTION =>
        WorkbenchFailureReason.transactionUnknown,
      TransactionState.DISCONNECTED => WorkbenchFailureReason.unavailable,
      _ => null,
    };
  }

  bool metadataSessionUsable(String? sessionId) =>
      metadataSessionUnavailableReason(sessionId) == null;

  MetadataRevisionStamp? metadataStampForSession(String sessionId) {
    final process = backend, owner = sessions[sessionId];
    if (process == null || owner == null || !metadataSessionUsable(sessionId)) {
      return null;
    }
    return _metadataRevisions.current(
      backendInstance: process.instanceId,
      profileId: owner.profile.id,
      sessionId: sessionId,
      sourceIdentity: owner.metadataSourceIdentity,
      sessionRevision: owner.sessionRevision.toInt(),
      contextRevision: owner.contextRevision.toInt(),
    );
  }

  /// Actual source configuration, with snapshot0 explicitly unobserved after
  /// a physical/context/transaction epoch or source configuration changes.
  ({int snapshot, int configuration})? metadataRevisionForSession(
    String sessionId,
  ) {
    final stamp = metadataStampForSession(sessionId);
    return stamp == null
        ? null
        : (snapshot: stamp.snapshot, configuration: stamp.configuration);
  }

  bool metadataRevisionIsCurrent(MetadataRevisionStamp stamp) {
    final process = backend, owner = sessions[stamp.sessionId];
    return process != null &&
        stamp.backendInstance == process.instanceId &&
        owner != null &&
        metadataSessionUsable(stamp.sessionId) &&
        stamp.profileId == owner.profile.id &&
        stamp.sourceIdentity == owner.metadataSourceIdentity &&
        stamp.sessionRevision == owner.sessionRevision.toInt() &&
        stamp.contextRevision == owner.contextRevision.toInt() &&
        _metadataRevisions.isCurrent(stamp);
  }

  bool acceptMetadataSnapshotRevision(
    String sessionId,
    int snapshot,
    int configuration, {
    required String sourceIdentity,
  }) {
    if (sessionId.isEmpty) {
      return snapshot == 0 && configuration == 0 && sourceIdentity.isEmpty;
    }
    final process = backend, owner = sessions[sessionId];
    if (process == null || owner == null) return false;
    try {
      _publishMetadataRevision(
        MetadataRevisionStamp(
          backendInstance: process.instanceId,
          profileId: owner.profile.id,
          sourceIdentity: sourceIdentity,
          sessionId: sessionId,
          sessionRevision: owner.sessionRevision.toInt(),
          contextRevision: owner.contextRevision.toInt(),
          configuration: configuration,
          snapshot: snapshot,
        ),
      );
      return true;
    } on LocalWorkbenchFailure {
      return false;
    }
  }

  bool _analysisMetadataCurrent(AcceptedAnalysis accepted) {
    if (accepted.result.sessionId.isEmpty) {
      return accepted.result.metadataSourceIdentity.isEmpty &&
          accepted.result.metadataSnapshotRevision == Int64.ZERO &&
          accepted.result.metadataConfigurationRevision == Int64.ZERO;
    }
    return metadataRevisionIsCurrent(
      analysisMetadataStamp(
        accepted.result,
        profileId:
            accepted.binding.profile?.id ?? accepted.binding.profileId ?? '',
      ),
    );
  }

  void _publishMetadataRevision(
    MetadataRevisionStamp stamp, {
    SessionInfo? acknowledgedSession,
  }) {
    if (!stamp.wellFormed) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.malformedRequest,
      );
    }
    final process = backend, current = sessions[stamp.sessionId];
    if (process == null || stamp.backendInstance != process.instanceId) {
      throw const LocalWorkbenchFailure(
        WorkbenchFailureReason.backendRestarted,
      );
    }
    if (current == null ||
        current.sessionId != stamp.sessionId ||
        current.profile.id != stamp.profileId ||
        current.metadataSourceIdentity != stamp.sourceIdentity) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    final unavailable = metadataSessionUnavailableReason(stamp.sessionId);
    if (unavailable != null) throw LocalWorkbenchFailure(unavailable);
    final owner = acknowledgedSession ?? current;
    if (acknowledgedSession != null &&
        (owner.sessionId != current.sessionId ||
            !sameProfileConfiguration(owner.profile, current.profile) ||
            owner.metadataSourceIdentity != current.metadataSourceIdentity ||
            owner.contextRevision != current.contextRevision ||
            owner.sessionRevision < current.sessionRevision)) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (stamp.contextRevision != owner.contextRevision.toInt() ||
        stamp.sessionRevision != owner.sessionRevision.toInt()) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.invalidRevision);
    }
    final prepared = _metadataRevisions.prepare(
      stamp,
      backendInstance: process.instanceId,
      liveOwners: sessions.entries.map((entry) {
        if (entry.key != entry.value.sessionId) {
          throw const LocalWorkbenchFailure(
            WorkbenchFailureReason.invalidOwner,
          );
        }
        final session =
            acknowledgedSession != null && entry.key == stamp.sessionId
            ? acknowledgedSession
            : entry.value;
        return _metadataPhysicalOwner(session, process);
      }),
    );
    // Admission is complete before either scalar owner is published. No await
    // or user callback separates these assignments or the notification below.
    var changed = _metadataRevisions.publish(prepared);
    if (acknowledgedSession != null) {
      sessions[stamp.sessionId] = acknowledgedSession;
      changed = true;
    }
    if (acceptedAnalysis != null &&
        !_analysisMetadataCurrent(acceptedAnalysis!)) {
      acceptedAnalysis = null;
      changed = true;
    }
    if (acceptedDiagnostics != null &&
        !_analysisMetadataCurrent(acceptedDiagnostics!)) {
      acceptedDiagnostics = null;
      changed = true;
    }
    if (acceptedParameterInformation != null &&
        !_analysisMetadataCurrent(acceptedParameterInformation!)) {
      acceptedParameterInformation = null;
      changed = true;
    }
    if (changed && !_disposed) notifyListeners();
  }

  bool analysisResultMatches(AcceptedAnalysis accepted) =>
      analysisMatches(accepted.binding) && _analysisMetadataCurrent(accepted);

  bool acceptMetadataRevision(String sessionId, SchemaObjects response) {
    final current = sessions[sessionId], process = backend;
    if (current == null ||
        process == null ||
        response.instanceId != process.instanceId ||
        response.profileId != current.profile.id ||
        response.sessionId != sessionId ||
        response.contextRevision != current.contextRevision ||
        response.sessionRevision.isNegative ||
        response.sessionRevision < current.sessionRevision) {
      return false;
    }
    final acknowledged = response.sessionRevision > current.sessionRevision
        ? (current.deepCopy()..sessionRevision = response.sessionRevision)
        : null;
    try {
      _publishMetadataRevision(
        schemaMetadataStamp(response),
        acknowledgedSession: acknowledged,
      );
      return true;
    } on LocalWorkbenchFailure {
      return false;
    }
  }

  void invalidateAnalysis() {
    final hadAnalysis =
        acceptedAnalysis != null ||
        acceptedDiagnostics != null ||
        acceptedParameterInformation != null;
    acceptedAnalysis = null;
    acceptedDiagnostics = null;
    acceptedParameterInformation = null;
    _analysisTimer?.cancel();
    _analysisRequestEpoch++;
    for (final request in _analysisRequests.values) {
      unawaited(request.cancel());
    }
    _analysisRequests.clear();
    _resolvingSymbol = false;
    // Caret and metadata changes need to remove visible actions immediately,
    // even when neither the document text nor another model field changed.
    if (hadAnalysis && !_disposed) notifyListeners();
  }

  Profile? _analysisProfile(SqlDocument d) =>
      sessions[d.sessionId]?.profile ??
      profiles.where((profile) => profile.id == d.profileId).firstOrNull;

  Profile? _analysisProfileSnapshot(SqlDocument d) {
    final profile = _analysisProfile(d);
    return profile == null ? null : (profile.deepCopy()..freeze());
  }

  AnalysisBinding analysisBinding(SqlDocument d) => AnalysisBinding(
    d,
    d.version,
    d.editor.text,
    d.caret,
    backend?.instanceId ?? '',
    d.sessionId,
    sessions[d.sessionId]?.contextRevision.toInt() ?? 0,
    sessions[d.sessionId]?.sessionRevision.toInt() ?? 0,
    sessions[d.sessionId]?.metadataSourceIdentity ?? '',
    List.unmodifiable([
      d.editor.selection,
      ...d.editor.value.secondarySelections,
    ]),
    d.profileId,
    _analysisProfileSnapshot(d),
    _analysisProfile(d)?.engine ?? Engine.POSTGRESQL,
  );

  bool analysisMatches(AnalysisBinding binding) =>
      !_disposed &&
      documents.contains(binding.document) &&
      identical(document, binding.document) &&
      binding.instance == (backend?.instanceId ?? '') &&
      binding.document.version == binding.version &&
      binding.document.editor.text == binding.text &&
      binding.document.caret == binding.caret &&
      binding.document.sessionId == binding.session &&
      (binding.session == null ||
          binding.session!.isEmpty ||
          metadataSessionUsable(binding.session)) &&
      binding.document.profileId == binding.profileId &&
      binding.sourceIdentity ==
          (sessions[binding.session]?.metadataSourceIdentity ?? '') &&
      sameProfileConfiguration(
        binding.profile,
        _analysisProfile(binding.document),
      ) &&
      binding.contextRevision ==
          (sessions[binding.session]?.contextRevision.toInt() ?? 0) &&
      binding.sessionRevision ==
          (sessions[binding.session]?.sessionRevision.toInt() ?? 0) &&
      listEquals(binding.selections, [
        binding.document.editor.selection,
        ...binding.document.editor.value.secondarySelections,
      ]);

  final _analysisRequests = <AnalysisOperation, ResponseFuture<Analysis>>{};
  final _analysisOperationEpochs = <AnalysisOperation, int>{};
  int _analysisRequestEpoch = 0;
  bool _resolvingSymbol = false;

  Future<Analysis?> analyze(
    SqlDocument d, {
    bool resolveSymbol = false,
    AnalysisOperation operation = AnalysisOperation.COMPLETION,
    int? formatStart,
    int? formatEnd,
    bool currentStatement = false,
  }) async {
    final process = backend;
    if (process == null ||
        !documents.contains(d) ||
        d.sessionId?.isNotEmpty == true &&
            !metadataSessionUsable(d.sessionId) ||
        !resolveSymbol && _resolvingSymbol) {
      return null;
    }
    final kind = resolveSymbol
        ? AnalysisOperation.SYMBOL_RESOLUTION
        : operation;
    final binding = analysisBinding(d), generation = _analysisRequestEpoch;
    final epoch = (_analysisOperationEpochs[kind] ?? 0) + 1;
    _analysisOperationEpochs[kind] = epoch;
    if (resolveSymbol) {
      _resolvingSymbol = true;
      _analysisOperationEpochs[AnalysisOperation.COMPLETION] =
          (_analysisOperationEpochs[AnalysisOperation.COMPLETION] ?? 0) + 1;
      unawaited(
        _analysisRequests.remove(AnalysisOperation.COMPLETION)?.cancel(),
      );
    }
    bool current() =>
        generation == _analysisRequestEpoch &&
        _analysisOperationEpochs[kind] == epoch &&
        identical(backend, process) &&
        analysisMatches(binding);
    final previous = _analysisRequests.remove(kind);
    final started = Stopwatch()..start();
    try {
      if (previous != null) await previous.cancel();
      if (!current()) return null;
      validateSqlUnicode(binding.text, maxUtf8Bytes: maxSqlRpcBytes);
      late Analysis result;
      for (var attempt = 0; ; attempt++) {
        if (!current()) return null;
        final remaining = BackendProcess.rpcTimeout - started.elapsed;
        if (remaining <= Duration.zero) {
          throw const GrpcError.deadlineExceeded();
        }
        final request = requestSqlAnalysis(
          process.client,
          AnalysisRequest(
            context: process.context(),
            documentId: d.id,
            documentVersion: Int64(binding.version),
            sql: binding.text,
            caretUtf16: binding.caret,
            sessionId: binding.session,
            contextRevision: Int64(binding.contextRevision),
            sessionRevision: Int64(binding.sessionRevision),
            engine: binding.engine,
            operation: kind,
            formatCurrentStatement: currentStatement,
            snippets: kind == AnalysisOperation.COMPLETION
                ? snippets.entries
                : null,
            formatSettings:
                sqlLanguagePreferences.formatFor(
                    binding.engine,
                    binding.profileId,
                  )
                  ..startUtf16 = formatStart ?? 0
                  ..endUtf16 = formatEnd ?? 0,
            inspections: sqlLanguagePreferences.inspectionsFor(
              binding.engine,
              binding.profileId,
            ),
          ),
          options: CallOptions(timeout: remaining),
        );
        _analysisRequests[kind] = request;
        try {
          result = await request;
          break;
        } on GrpcError catch (error) {
          final delay = Duration(milliseconds: 50 << attempt);
          if (!resolveSymbol ||
              attempt >= 5 ||
              ConnectionFailure.from(error).reason !=
                  ConnectionFailureReason.busy ||
              BackendProcess.rpcTimeout - started.elapsed <= delay) {
            rethrow;
          }
          await Future<void>.delayed(delay);
        }
      }
      if (current() &&
          result.operation == kind &&
          result.documentId == d.id &&
          result.documentVersion.toInt() == binding.version &&
          result.backendInstance == binding.instance &&
          result.sessionId == (binding.session ?? '') &&
          result.contextRevision.toInt() == binding.contextRevision &&
          result.sessionRevision.toInt() == binding.sessionRevision &&
          result.metadataSourceIdentity == binding.sourceIdentity &&
          result.caretUtf16 == binding.caret &&
          acceptMetadataSnapshotRevision(
            binding.session ?? '',
            result.metadataSnapshotRevision.toInt(),
            result.metadataConfigurationRevision.toInt(),
            sourceIdentity: result.metadataSourceIdentity,
          )) {
        if (!resolveSymbol) {
          final accepted = AcceptedAnalysis(binding, result);
          if (kind == AnalysisOperation.DIAGNOSTICS) {
            acceptedDiagnostics = accepted;
          } else if (kind == AnalysisOperation.PARAMETER_INFORMATION) {
            acceptedParameterInformation = accepted;
          } else {
            acceptedAnalysis = accepted;
          }
          notifyListeners();
          if (kind == AnalysisOperation.COMPLETION) {
            unawaited(analyze(d, operation: AnalysisOperation.DIAGNOSTICS));
            unawaited(
              analyze(d, operation: AnalysisOperation.PARAMETER_INFORMATION),
            );
          }
        }
        return result;
      }
    } catch (_) {
      if (resolveSymbol && current()) rethrow;
    } finally {
      if (_analysisOperationEpochs[kind] == epoch) {
        _analysisRequests.remove(kind);
        if (resolveSymbol) _resolvingSymbol = false;
      }
    }
    return null;
  }

  bool applyFormatting(AcceptedAnalysis accepted) {
    if (!analysisResultMatches(accepted) ||
        accepted.result.formattedSql.isEmpty) {
      return false;
    }
    final target = accepted.binding.document, source = accepted.binding.text;
    // The Java lexer changes whitespace and preserves literal token contents.
    // Replacing newlines here would also rewrite multiline SQL values.
    final formatted = accepted.result.formattedSql;
    final tokens = accepted.result.formatTokens;
    if (tokens.length > 100000 || tokens.isEmpty && source.trim().isNotEmpty) {
      return false;
    }
    var priorSource = 0, priorFormatted = 0;
    for (final token in tokens) {
      final start = token.sourceStartUtf16,
          end = token.sourceEndUtf16,
          next = token.formattedStartUtf16;
      if (start < priorSource ||
          end <= start ||
          end > source.length ||
          next < priorFormatted ||
          next + end - start > formatted.length) {
        return false;
      }
      priorSource = end;
      priorFormatted = next + end - start;
    }
    int map(int offset) {
      var sourceEnd = 0, formattedEnd = 0;
      for (final token in tokens) {
        final start = token.sourceStartUtf16,
            end = token.sourceEndUtf16,
            next = token.formattedStartUtf16;
        if (offset < start) {
          return source.substring(sourceEnd, start) ==
                  formatted.substring(formattedEnd, next)
              ? formattedEnd + offset - sourceEnd
              : next;
        }
        if (offset <= end) return next + offset - start;
        sourceEnd = end;
        formattedEnd = next + end - start;
      }
      return source.substring(sourceEnd) == formatted.substring(formattedEnd)
          ? formattedEnd + offset - sourceEnd
          : formatted.length;
    }

    return target.replaceWithMappedPositions(formatted, map);
  }

  bool applyCompletion(AcceptedAnalysis accepted, Completion completion) {
    if (!analysisResultMatches(accepted) ||
        completion.startUtf16 < 0 ||
        completion.startUtf16 > completion.endUtf16 ||
        completion.endUtf16 > accepted.binding.text.length ||
        !utf16Boundary(accepted.binding.text, completion.startUtf16) ||
        !utf16Boundary(accepted.binding.text, completion.endUtf16) ||
        !accepted.result.completions.contains(completion)) {
      return false;
    }
    final target = accepted.binding.document;
    target.selectOffsets(completion.startUtf16, completion.endUtf16);
    target.editor.replaceSelection(completion.insertText);
    if (target.editor.text !=
        accepted.binding.text.replaceRange(
          completion.startUtf16,
          completion.endUtf16,
          completion.insertText,
        )) {
      return false;
    }
    // The accepted edit must not immediately suggest the same identifier again.
    // Keep diagnostics and parameter information current for the inserted text.
    _analysisTimer?.cancel();
    unawaited(analyze(target, operation: AnalysisOperation.DIAGNOSTICS));
    unawaited(
      analyze(target, operation: AnalysisOperation.PARAMETER_INFORMATION),
    );
    return true;
  }

  Row? row(String result, int index) {
    final key = '$result:$index';
    final cached = cache.remove(key);
    if (cached != null) {
      cache[key] = cached;
      return cached;
    }
    final process = backend;
    if (process == null) return null;
    if (index < 0 ||
        disposedResults.contains(result) ||
        pageErrors.containsKey(result)) {
      return null;
    }
    // Coalesce visible cells while a bounded request is in flight, but address
    // an actual missing row. A byte-shortened reply never promises 200 rows.
    final pageKey = '$result:${index ~/ 200}';
    final waiting = _waitingPageRows[pageKey];
    if (waiting != null &&
        index >= (_knownFetchedRows[result] ?? waiting) &&
        (_knownFetchedRows[result] ?? waiting) <= waiting) {
      return null;
    }
    if (!loading.contains(pageKey) && loading.length < 4) {
      loading.add(pageKey);
      _loadPage(process, result, index, pageKey).whenComplete(() {
        if (identical(backend, process)) loading.remove(pageKey);
      });
    }
    return null;
  }

  Future<void> _loadPage(
    BackendConnection process,
    String result,
    int offset,
    String pageKey,
  ) async {
    try {
      final page = await process.client.resultPage(
        PageRequest(
          context: process.context(),
          resultId: result,
          offset: Int64(offset),
          limit: 200,
          maxBytes: 1048576,
        ),
      );
      if (_disposed ||
          !identical(backend, process) ||
          disposedResults.contains(result)) {
        return;
      }
      final known = _knownFetchedRows[result] ?? 0;
      if (page.fetchedRows.toInt() > known) {
        _knownFetchedRows[result] = page.fetchedRows.toInt();
      }
      if (page.state == PageState.PAGE_WAITING ||
          page.state == PageState.PAGE_END) {
        _waitingPageRows[pageKey] = page.fetchedRows.toInt();
      } else if (page.state == PageState.PAGE_DATA ||
          page.state == PageState.PAGE_BYTE_LIMIT) {
        if (page.rows.isEmpty ||
            page.firstOffset.toInt() != offset ||
            page.nextOffset.toInt() != offset + page.rows.length ||
            page.writeToBuffer().length > 1048576) {
          throw StateError('Invalid or zero-progress result page');
        }
        _waitingPageRows.remove(pageKey);
        for (int index = 0; index < page.rows.length; index++) {
          final key = '$result:${page.firstOffset.toInt() + index}',
              value = page.rows[index];
          final previous = cache.remove(key);
          if (previous != null) cacheBytes -= previous.writeToBuffer().length;
          cache[key] = value;
          if (resultViews.containsKey(result)) {
            if (page.sourceRows.length != page.rows.length) {
              throw StateError("Retained view omitted its source identity");
            }
            sourceRowMappings[key] = page.sourceRows[index].toInt();
          }
          cacheBytes += value.writeToBuffer().length;
          final size = value.writeToBuffer().length;
          if (size > (_maximumRowBytes[result] ?? 0)) {
            _maximumRowBytes[result] = size;
          }
        }
        while ((cacheBytes > 2 * 1024 * 1024 || cache.length > 1000) &&
            cache.isNotEmpty) {
          final evicted = cache.keys.first;
          final value = cache.remove(evicted)!;
          sourceRowMappings.remove(evicted);
          cacheBytes -= value.writeToBuffer().length;
        }
      } else {
        pageErrors[result] = ResultPageError(
          page.state.name,
          page.availability.isEmpty
              ? 'Retained rows are unavailable'
              : page.availability,
          page.state == PageState.PAGE_FAILED,
        );
        if (page.state == PageState.PAGE_DISPOSED) disposedResults.add(result);
      }
    } catch (_) {
      if (!_disposed &&
          identical(backend, process) &&
          !disposedResults.contains(result)) {
        pageErrors[result] = const ResultPageError(
          'RPC_OR_PAGE_FAILURE',
          'Result page failed. Retry loads retained rows without executing SQL.',
          true,
        );
      }
    }
    if (!_disposed && identical(backend, process)) {
      cacheGeneration++;
      if (pageErrors.containsKey(result)) status = pageErrors[result]!.message;
      _notifyBackendUpdate();
    }
  }

  void retryResultPage(String result) {
    if (pageErrors[result]?.retryable != true ||
        disposedResults.contains(result)) {
      return;
    }
    pageErrors.remove(result);
    _waitingPageRows.removeWhere((key, _) => key.startsWith('$result:'));
    cacheGeneration++;
    notifyListeners();
  }

  int resultWindowRows(String result) {
    final bytes = _maximumRowBytes[result] ?? 0;
    return bytes == 0 ? 256 : ((2 * 1024 * 1024) ~/ bytes).clamp(1, 256);
  }

  void _notifyBackendUpdate() {
    if (_disposed || _backendPaint?.isActive == true) return;
    _backendPaint = Timer(const Duration(milliseconds: 100), () {
      if (!_disposed) notifyListeners();
    });
  }

  void updateStatus(String value) {
    if (_disposed) return;
    status = value;
    notifyListeners();
  }

  bool admitDesignDraft(WorkbenchDocument owner, ObjectDesignerDraft draft) {
    try {
      draft.validate();
      final otherBytes = taskDocuments
          .where((d) => d.id != owner.id)
          .fold<int>(
            0,
            (n, d) => n + (d.designDraft.dirty ? d.designDraft.bytes : 0),
          );
      if (otherBytes + draft.bytes > 1048576) return false;
      documentBudget.auxiliary(
        owner,
        owner.evidenceUnits +
            owner.view.results.values.fold<int>(
              0,
              (n, state) => n + state.planEvidenceUnits,
            ) +
            draft.bytes * 2,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void reserveDocumentEvidence(WorkbenchDocument owner, int units) {
    if (!operationOwners.contains(owner) &&
        !identical(globalToolOwner, owner)) {
      throw StateError('The evidence owner was closed');
    }
    documentBudget.auxiliary(
      owner,
      units +
          owner.view.results.values.fold<int>(
            0,
            (n, state) => n + state.planEvidenceUnits,
          ) +
          owner.designDraft.bytes * 2,
    );
    owner.evidenceUnits = units;
  }

  void _chargeOwnerEvidence(WorkbenchDocument owner) {
    final evidence =
        owner.evidenceUnits +
        owner.view.results.values.fold<int>(
          0,
          (n, state) => n + state.planEvidenceUnits,
        );
    documentBudget.auxiliary(
      owner,
      evidence +
          ((evidence != 0 || owner.designDraft.dirty)
              ? owner.designDraft.bytes * 2
              : 0),
    );
  }

  void reserveResultEvidence(
    WorkbenchDocument owner,
    String resultId,
    int units,
  ) {
    if (!workbenchDocuments.contains(owner) || units < 0) {
      throw StateError(
        'The evidence owner was closed or the charge is invalid',
      );
    }
    final state = resultView(resultId, owner: owner),
        prior = state.planEvidenceUnits;
    state.planEvidenceUnits = units;
    try {
      _chargeOwnerEvidence(owner);
    } catch (_) {
      state.planEvidenceUnits = prior;
      rethrow;
    }
  }

  void recordDesignChange(WorkbenchDocument owner) {
    owner.revision++;
    updateStatus('Pending object design; database unchanged');
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 300), () {
      recoverNow().catchError(
        (Object error) => updateStatus(
          'Object design recovery failed: ${operationFailureSummary(error)}',
        ),
      );
    });
  }

  Future<void> _presentationSave = Future<void>.value();
  Future<void> savePresentation() => _savePresentation();
  Future<void> _savePresentation({
    String? theme,
    String? locale,
    bool appearance = false,
    Map<String, String>? proposedShortcuts,
    SqlLanguagePreferences? proposedSqlLanguage,
    ({int rows, ErrorPolicy policy})? proposedExecution,
    bool? proposedRecovery,
    VoidCallback? acknowledged,
  }) {
    final pending = _presentationSave.then((_) async {
      final bytes = utf8.encode(
        jsonEncode({
          'version': 1,
          'themeMode': appearance ? theme : appearancePreference.value.$1,
          'querySequence': _querySequence,
          'locale': appearance ? locale : appearancePreference.value.$2,
          'rowLimit': proposedExecution?.rows ?? _defaultRowLimit,
          'draftRecovery': proposedRecovery ?? draftRecovery,
          'continueOnError':
              (proposedExecution?.policy ?? _defaultErrorPolicy) ==
              ErrorPolicy.CONTINUE_ON_ERROR,
          'shortcuts': proposedShortcuts ?? shortcuts,
          'snippets': snippets,
          'sqlLanguage': (proposedSqlLanguage ?? sqlLanguagePreferences)
              .toJson(),
          'resultDisplayFormats': resultDisplayFormats,
          'editorFraction': editorFraction,
          'explorerWidth': explorerWidth,
          'explorerVisible': explorerVisible,
          'favoriteProfiles': favoriteProfiles.take(64).toList(),
          'sourceFolders': sourceFolders.values.map((f) => f.toJson()).toList(),
          'sourceFolderMembership': sourceFolderMembership,
          'explorerOrder': explorerOrder,
          'virtualViews': virtualViews.values.map((v) => v.toJson()).toList(),
          'showAllNamespaces': showAllNamespaces,
          'showEmptyGroups': showEmptyGroups,
          'explorerPreferences': explorerPreferences,
          'explorerObjectKinds': explorerObjectKinds
              .map((kind) => kind.value)
              .toList(),
          'explorerExpanded': explorerExpanded.take(256).toList(),
          'explorerSelection': explorerSelection,
          'explorerNameFilter': explorerNameFilter,
          'namespaceSelections': {
            for (final entry in namespaceSelections.entries.take(128))
              entry.key: entry.value.toJson(),
          },
          'documentViews': {
            for (final owner in workbenchDocuments.take(100))
              owner.id: {
                'editorFraction': owner.view.editorFraction,
                'rowLimit': owner.view.rowLimit,
                'editorVertical': owner.view.editorVertical,
                'editorHorizontal': owner.view.editorHorizontal,
              },
          },
          'objectHints': [
            ..._unadoptedObjectHints,
            for (final owner
                in taskDocuments
                    .where(
                      (d) =>
                          (d.object != null || d.creationScope != null) &&
                          !closingDocuments.contains(d.id) &&
                          [
                            WorkbenchDocumentKind.table,
                            WorkbenchDocumentKind.structure,
                          ].contains(d.kind),
                    )
                    .take(32))
              {
                'kind': owner.kind.name,
                'profile':
                    owner.object?.profileId ?? owner.creationScope!.profileId,
                'catalog':
                    owner.object?.catalog ?? owner.creationScope!.catalog,
                'schema': owner.object?.schema ?? owner.creationScope!.schema,
                'name': owner.object?.name ?? '',
                'parent': owner.object?.parent ?? '',
                if (owner.object?.identifier.isNotEmpty == true)
                  'identifier': owner.object!.identifier,
                if (owner.object != null)
                  'objectKind': owner.object!.kind.value,
                if (owner.object != null)
                  'subtype': owner.object!.subtype.value,
                if (owner.creationScope != null) 'creation': true,
                'id': owner.id,
                'purpose': owner.purpose,
                'structureSection': owner.view.structureSection,
              },
          ],
          'taskHints': [
            ..._unadoptedTaskHints,
            for (final owner
                in taskDocuments
                    .where(
                      (d) =>
                          d.object == null &&
                          !closingDocuments.contains(d.id) &&
                          ![
                            WorkbenchDocumentKind.table,
                            WorkbenchDocumentKind.structure,
                          ].contains(d.kind),
                    )
                    .take(32))
              {
                'id': owner.id,
                'kind': owner.kind.name,
                'title': String.fromCharCodes(
                  owner.displayTitle.runes.take(128),
                ),
                'profile': owner.profileId ?? '',
                'command': owner.reopenCommandId,
                'schema': owner.referenceSchema,
              },
          ],
        }),
      );
      if (bytes.length > 65536) {
        return Future<void>.error(
          StateError('Presentation settings exceed the shared 64KiB budget'),
        );
      }
      await presentationWrite(File('${support.path}/presentation.json'), bytes);
      acknowledged?.call();
    });
    _presentationSave = pending.catchError((_) {});
    return pending;
  }

  void resizeEditor(double fraction) {
    editorFraction = fraction.clamp(.15, .85);
    notifyListeners();
  }

  bool _recoveryChangePending = false;
  Future<void> saveExecutionPreferences(
    int rows,
    ErrorPolicy policy, {
    required bool recovery,
    SqlLanguagePreferences? sqlLanguage,
  }) => _changePreferences(() {
    if (rows < 1 || rows > 1000000) throw ArgumentError.value(rows);
    sqlLanguage?.validate();
    return _setDraftRecovery(
      recovery,
      execution: (rows: rows, policy: policy),
      sqlLanguage: sqlLanguage?.deepCopy(),
    );
  });
  Future<void> setDraftRecovery(bool enabled) =>
      _changePreferences(() => _setDraftRecovery(enabled));
  Future<void> _setDraftRecovery(
    bool enabled, {
    ({int rows, ErrorPolicy policy})? execution,
    SqlLanguagePreferences? sqlLanguage,
  }) async {
    final previous = draftRecovery;
    final previousLanguage = sqlLanguagePreferences.deepCopy();
    final previousExecution = (
      rows: _defaultRowLimit,
      policy: _defaultErrorPolicy,
    );
    Future<void> persist(
      bool recovery,
      ({int rows, ErrorPolicy policy})? execution,
      SqlLanguagePreferences? language,
    ) => _savePresentation(
      proposedRecovery: recovery,
      proposedExecution: execution,
      proposedSqlLanguage: language,
      acknowledged: () {
        draftRecovery = recovery;
        if (language != null) {
          sqlLanguagePreferences = language;
          invalidateAnalysis();
        }
        if (execution != null) {
          executionDefaults(execution.rows, execution.policy);
        }
      },
    );
    if (enabled == draftRecovery) {
      await persist(enabled, execution, sqlLanguage);
      return;
    }
    if (_recoveryChangePending) {
      throw StateError(
        'A recovery privacy decision is awaiting acknowledgement',
      );
    }
    _recoveryChangePending = true;
    _draftTimer?.cancel();
    notifyListeners();
    var acknowledged = false;
    try {
      if (!enabled) {
        await _draftSave;
        final batches = List<OwnedEditBatch>.of(editBatches.values);
        await Future.wait(batches.map((b) => awaitStagedSave(batch: b)));
        void requireResolved() {
          if (editBatches.values.any((b) => b.applying || b.outcomeUnknown) ||
              editDrafts.any(
                (d) => d.state == 'APPLYING' || d.state == 'UNKNOWN_OUTCOME',
              )) {
            throw StateError(
              'Reconcile applying or unknown changes before disabling recovery; discard records through their explicit review',
            );
          }
        }

        requireResolved();
        final process = backend;
        if (process != null) {
          final revisions = {for (final b in batches) b: b.revision};
          void requirePrivacyTarget() {
            if (_disposed ||
                !identical(backend, process) ||
                revisions.entries.any((e) => e.key.revision != e.value) ||
                editBatches.values.any((b) => b.pendingRecovery != 0)) {
              throw StateError(
                'Recovery ownership changed during the privacy review; inspect the records again',
              );
            }
            requireResolved();
          }

          final reply = await process.client.editDraft(
            EditDraftRequest(context: process.context()),
          );
          if (_disposed || !identical(backend, process)) {
            throw StateError(
              'Backend changed while inspecting recovery privacy',
            );
          }
          editDrafts
            ..clear()
            ..addAll(reply.drafts);
          requirePrivacyTarget();
          for (final draft in List<EditDraftInfo>.of(editDrafts)) {
            requirePrivacyTarget();
            await process.client.editDraft(
              EditDraftRequest(
                context: process.context(),
                action: EditDraftAction.DELETE_EDIT_DRAFT,
                draftId: draft.draftId,
              ),
            );
            requirePrivacyTarget();
            editDrafts.removeWhere((d) => d.draftId == draft.draftId);
            for (final batch in editBatches.values) {
              if (batch.draftId == draft.draftId) batch.draftId = null;
            }
          }
        } else if (editDrafts.isNotEmpty) {
          throw StateError(
            'The backend is unavailable; recovery records cannot be discarded safely',
          );
        }
      }
      await persist(enabled, execution, sqlLanguage);
      acknowledged = true;
      if (enabled) {
        await recoverNow();
      } else {
        await saveObjectDesigns();
        final file = File('${support.path}/drafts.json');
        if (await file.exists()) await file.delete();
      }
    } catch (failure) {
      if (acknowledged) {
        try {
          await persist(previous, previousExecution, previousLanguage);
        } catch (rollback) {
          throw StateError(
            'Settings cleanup failed: ${operationFailureSummary(failure)}. Restoring preferences failed: ${operationFailureSummary(rollback)}. The last acknowledged settings remain active.',
          );
        }
      }
      rethrow;
    } finally {
      _recoveryChangePending = false;
      if (!_disposed) notifyListeners();
    }
  }

  ChangeRequest stagedRequest({OwnedEditBatch? batch}) {
    final owned = batch ?? activeEditBatch;
    return ChangeRequest(
      context: context,
      sessionId: owned.sessionId,
      schema: owned.schema,
      table: owned.table,
      resultId: owned.resultId,
      recoveryId: owned.draftId,
      changes: owned.changes.map((change) => change.deepCopy()),
    );
  }

  Future<void> refreshEditDrafts() async {
    final process = backend;
    if (process == null) return;
    final reply = await process.client.editDraft(
      EditDraftRequest(context: process.context()),
    );
    if (!identical(backend, process) || _disposed) return;
    editDrafts
      ..clear()
      ..addAll(reply.drafts);
    notifyListeners();
  }

  Future<void> discardRecoveryRecord(
    EditDraftInfo reviewed, {
    required BackendConnection process,
  }) async {
    void requireBackend() {
      if (_disposed || !identical(backend, process)) {
        throw StateError(
          'Backend changed during recovery review; inspect the original record again',
        );
      }
    }

    requireBackend();
    final snapshot = reviewed.deepCopy();
    final records = await process.client.editDraft(
      EditDraftRequest(context: process.context()),
    );
    requireBackend();
    final current = records.drafts
        .where((d) => d.draftId == snapshot.draftId)
        .firstOrNull;
    if (current == null ||
        current != snapshot ||
        current.state == 'APPLYING' ||
        editBatches.values.any(
          (b) => b.draftId == snapshot.draftId && b.applying,
        )) {
      throw StateError(
        'Recovery state changed or application is pending; inspect and review the record again',
      );
    }
    await process.client.editDraft(
      EditDraftRequest(
        context: process.context(),
        action: EditDraftAction.DELETE_EDIT_DRAFT,
        draftId: snapshot.draftId,
      ),
    );
    requireBackend();
    editDrafts.removeWhere((d) => d.draftId == snapshot.draftId);
    for (final batch in editBatches.values) {
      if (batch.draftId == snapshot.draftId) batch.draftId = null;
    }
    notifyListeners();
  }

  Future<void> persistStagedEdits({OwnedEditBatch? batch}) {
    final owned = batch ?? activeEditBatch;
    owned.revision++;
    final totalBytes = editBatches.values.fold<int>(
      0,
      (n, b) =>
          n +
          b.changes.fold<int>(0, (sum, c) => sum + c.writeToBuffer().length),
    );
    if (pendingEditCount > 1000 || totalBytes > 1048576) {
      return Future<void>.error(
        StateError(
          'Pending edits exceed the shared 1MiB / 1,000 change budget',
        ),
      );
    }
    if (!draftRecovery) return Future<void>.value();
    if (owned.changes.isEmpty) {
      final process = backend;
      final pending = owned.trackRecovery(
        owned.save.then((_) async {
          if (owned.draftId == null) return;
          if (process == null || !identical(backend, process)) {
            throw StateError('Backend changed before empty recovery cleanup');
          }
          await process.client.editDraft(
            EditDraftRequest(
              context: process.context(),
              action: EditDraftAction.DELETE_EDIT_DRAFT,
              draftId: owned.draftId,
            ),
          );
          owned.draftId = null;
          await refreshEditDrafts();
        }),
      );
      owned.save = pending.then(
        (_) {
          owned.saveError = null;
          if (!_disposed) notifyListeners();
        },
        onError: (Object error) {
          owned.saveError = error;
          if (!_disposed) notifyListeners();
        },
      );
      return pending;
    }
    final process = backend!;
    final snapshot = stagedRequest(batch: owned);
    final pending = owned.trackRecovery(
      owned.save.then((_) async {
        if (!identical(backend, process)) {
          throw StateError(
            'Backend changed; staged edits remain in memory and require explicit recovery',
          );
        }
        final reply = await process.client.editDraft(
          EditDraftRequest(
            context: process.context(),
            action: EditDraftAction.SAVE_EDIT_DRAFT,
            sessionId: snapshot.sessionId,
            documentId: owned.documentId ?? owned.ownerId,
            draftId: owned.draftId,
            changes: snapshot,
          ),
        );
        if (!identical(backend, process)) return;
        owned.draftId = reply.drafts.single.draftId;
        await refreshEditDrafts();
      }),
    );
    owned.save = pending.then(
      (_) {
        owned.saveError = null;
        if (!_disposed) notifyListeners();
      },
      onError: (Object failure, StackTrace trace) {
        owned.saveError = failure;
        if (!_disposed) notifyListeners();
      },
    );
    return pending;
  }

  Future<void> awaitStagedSave({OwnedEditBatch? batch}) async {
    final owned = batch ?? activeEditBatch;
    await owned.save;
    if (owned.saveError != null) {
      throw StateError(
        'Staged edit recovery failed; keep the application open and retry saving the batch',
      );
    }
  }

  Future<void> discardStagedEdits({OwnedEditBatch? batch}) {
    final owned = batch ?? activeEditBatch;
    if (owned.discarding) {
      return Future<void>.error(
        StateError('Recovery discard acknowledgement is pending'),
      );
    }
    final previous = owned.save, process = backend;
    owned.discarding = true;
    final pending = owned
        .trackRecovery(() async {
          await previous;
          final id = owned.draftId;
          if (id != null) {
            if (process == null || !identical(backend, process)) {
              throw StateError(
                'Recovery cleanup requires the original backend acknowledgement',
              );
            }
            await process.client.editDraft(
              EditDraftRequest(
                context: process.context(),
                action: EditDraftAction.DELETE_EDIT_DRAFT,
                draftId: id,
              ),
            );
            if (!identical(backend, process)) {
              throw StateError('Backend changed during recovery cleanup');
            }
          }
          owned.changes.clear();
          owned.saveError = null;
          owned.draftId = null;
          owned.documentId = null;
          owned.revision++;
          await refreshEditDrafts();
          updateStatus('Staged edits discarded');
        }())
        .whenComplete(() => owned.discarding = false);
    owned.save = pending.then(
      (_) {},
      onError: (Object error) {
        owned.saveError = error;
      },
    );
    return pending;
  }

  Future<void> rebindEditDraft(
    EditDraftInfo draft, {
    SqlDocument? targetDocument,
  }) async {
    final target = targetDocument ?? document;
    if (editBatches.values.any(
      (b) =>
          b.ownerId == target.id &&
          b.changes.isNotEmpty &&
          b.draftId != draft.draftId,
    )) {
      throw StateError('Apply or discard the current edit batch first');
    }
    final process = backend!;
    final sessionId = target.sessionId;
    if (sessionId == null) {
      throw StateError(
        'Explicitly connect a writable console to the original target before rebinding recovery',
      );
    }
    final reply = await process.client.editDraft(
      EditDraftRequest(
        context: process.context(),
        action: EditDraftAction.REBIND_EDIT_DRAFT,
        draftId: draft.draftId,
        sessionId: sessionId,
        documentId: target.id,
      ),
    );
    if (!identical(backend, process) ||
        !documents.contains(target) ||
        target.sessionId != sessionId) {
      if (identical(backend, process)) {
        await process.client.disposeResult(
          PageRequest(
            context: process.context(),
            resultId: reply.result.result.resultId,
          ),
        );
      }
      throw StateError(
        'The recovery target changed; saved edits remain recoverable',
      );
    }
    final key = '${target.id}\u0000${reply.changes.resultId}';
    final batch = editBatches.putIfAbsent(
      key,
      () => OwnedEditBatch(target.id, reply.changes.resultId),
    );
    batch.changes
      ..clear()
      ..addAll(reply.changes.changes);
    batch.sessionId = sessionId;
    batch.schema = reply.changes.schema;
    batch.table = reply.changes.table;
    batch.draftId = draft.draftId;
    batch.documentId = target.id;
    batch.revision++;
    retainedResults[reply.result.result.resultId] = reply.result;
    _retainedViews[target.id] = {reply.result.result.resultId};
    selectedExecutions[target.id] = reply.result.executionId;
    selectedResults[target.id] = reply.result.result.resultId;
    await refreshEditDrafts();
    updateStatus(
      'Verified staged rows recovered. Source SQL was not executed; a fresh change preview is required.',
    );
  }

  Future<void> _designSave = Future<void>.value();
  Future<void> saveObjectDesigns() {
    final data = {
      'version': 1,
      'documents': {
        ..._unadoptedDesigns,
        for (final owner in taskDocuments)
          if (draftRecovery &&
              owner.designDraft.dirty &&
              !closingDocuments.contains(owner.id))
            owner.id: owner.designDraft.toJson(),
      },
    };
    final bytes = utf8.encode(jsonEncode(data));
    if (bytes.length > 2097152) {
      throw const DocumentResourceLimit(
        'Object design recovery exceeds the aggregate 2MiB file bound',
      );
    }
    final release = SaveCaptureBudget.shared.reserve(bytes.length * 2);
    final pending = _designSave
        .then(
          (_) => (recoveryWrite ?? atomicWrite)(
            File('${support.path}/object-designs.json'),
            bytes,
          ),
        )
        .whenComplete(release);
    _designSave = pending.catchError((_) {});
    return pending;
  }

  Future<void> _draftSave = Future<void>.value();
  Future<void> recoverNow() {
    final pending = _draftSave.then((_) async {
      if (draftRecovery && !_disposed) {
        await Future.wait(
          List<OwnedEditBatch>.of(
            editBatches.values,
          ).map((batch) => awaitStagedSave(batch: batch)),
        );
        if (_disposed) return;
        await drafts.save(
          documents,
          selected,
          startupScratchId: untouchedStartupScratchId,
          unadopted: _unadoptedSqlDrafts,
        );
        await saveObjectDesigns();
        if (taskDocuments.any((d) => d.designDraft.dirty)) {
          await savePresentation();
        }
      }
    });
    _draftSave = pending.catchError((_) {});
    return pending;
  }

  bool _disposed = false;
  bool get isDisposed => _disposed;
  @override
  void dispose() {
    appearancePreference.dispose();
    _analysisRequestEpoch++;
    for (final request in _analysisRequests.values) {
      unawaited(request.cancel());
    }
    _analysisRequests.clear();
    for (final request in _viewRequests.values) {
      unawaited(request.cancel());
    }
    _viewRequests.clear();
    _backendPaint?.cancel();
    _disposed = true;
    _poll?.cancel();
    _draftTimer?.cancel();
    _analysisTimer?.cancel();
    if (globalToolOwner case final owner?) {
      documentBudget.auxiliary(owner, 0);
      globalToolOwner = null;
    }
    for (final owner in taskDocuments) {
      documentBudget.auxiliary(owner, 0);
    }
    for (final d in documents) {
      d.dispose();
    }
    _sqlOwners.clear();
    editBatches.clear();
    unawaited(backend?.close());
    explorerFocus.dispose();
    documentFocus.dispose();
    targetFocus.dispose();
    outputFocus.dispose();
    globalToolFocus.dispose();
    super.dispose();
  }
}

class ProfileSaveUncertain implements Exception {
  const ProfileSaveUncertain(this.primary);
  final Object primary;
  @override
  String toString() =>
      'Profile save acknowledgement is unavailable. Existing and replacement credentials were retained; inspect the saved profile after reconnecting before deleting either binding.';
}

class CredentialStorageFailure implements Exception {
  const CredentialStorageFailure(this.primary);
  final Object primary;
  @override
  String toString() =>
      'OS secure storage could not save the replacement credential. The existing profile and credential remain intact; choose session-only credentials explicitly if storage is unavailable.';
}

class AnalysisBinding {
  const AnalysisBinding(
    this.document,
    this.version,
    this.text,
    this.caret,
    this.instance,
    this.session,
    this.contextRevision,
    this.sessionRevision,
    this.sourceIdentity,
    this.selections,
    this.profileId,
    this.profile,
    this.engine,
  );
  final SqlDocument document;
  final Profile? profile;
  final Engine engine;
  final int version, caret, contextRevision, sessionRevision;
  final String text, instance, sourceIdentity;
  final String? session;
  final String? profileId;
  final List<CodeLineSelection> selections;
}

bool utf16Boundary(String text, int offset) =>
    offset == 0 ||
    offset == text.length ||
    !(text.codeUnitAt(offset - 1) >= 0xd800 &&
        text.codeUnitAt(offset - 1) <= 0xdbff &&
        text.codeUnitAt(offset) >= 0xdc00 &&
        text.codeUnitAt(offset) <= 0xdfff);

class ResultPageError {
  const ResultPageError(this.code, this.message, this.retryable);
  final String code, message;
  final bool retryable;
}

class AcceptedAnalysis {
  const AcceptedAnalysis(this.binding, this.result);
  final AnalysisBinding binding;
  final Analysis result;
}

class CapturedWorkbenchTarget {
  CapturedWorkbenchTarget(
    this.backend,
    SqlDocument document,
    this.revision,
    this.sessionId,
    this.contextRevision,
  ) : _document = WeakReference(document),
      sessionOnly = false,
      _owner = null,
      ownerId = document.id,
      _title = document.title,
      sessionRevision = null,
      profile = null,
      session = null,
      profileId = document.profileId;
  CapturedWorkbenchTarget.owner(
    this.backend,
    WorkbenchDocument owner,
    this.revision,
    this.sessionId,
    this.contextRevision,
    this.sessionRevision, {
    this.profile,
    this.session,
  }) : _document = null,
       sessionOnly = false,
       _owner = WeakReference(owner),
       ownerId = owner.id,
       _title = owner.displayTitle,
       profileId = owner.profileId;
  CapturedWorkbenchTarget.ownedSession(this.backend, SessionInfo snapshot)
    : _document = null,
      _owner = null,
      sessionOnly = true,
      ownerId = 'session:${snapshot.sessionId}',
      _title = snapshot.profile.name,
      revision = 0,
      sessionId = snapshot.sessionId,
      contextRevision = snapshot.contextRevision,
      sessionRevision = snapshot.sessionRevision,
      profileId = snapshot.profile.id,
      profile = snapshot.profile,
      session = snapshot;
  final BackendConnection backend;
  final bool sessionOnly;
  final Profile? profile;
  final SessionInfo? session;
  // Task evidence must not keep a closed editor/undo tree alive outside the
  // shared document budget. The model owns live clients; captures reference it.
  final WeakReference<SqlDocument>? _document;
  final WeakReference<WorkbenchDocument>? _owner;
  WorkbenchDocument? get owner => _owner?.target;
  SqlDocument get document =>
      _document?.target ??
      owner?.sql ??
      (throw StateError('The captured SQL owner was released'));
  final String ownerId, _title;
  bool references(WorkbenchDocument candidate) =>
      !sessionOnly &&
      candidate.id == ownerId &&
      (_owner != null
          ? identical(_owner.target, candidate)
          : identical(_document?.target, candidate.sql));
  String? get currentSessionId => sessionOnly
      ? sessionId
      : owner != null
      ? owner!.sessionId
      : document.sessionId;
  final String? profileId;
  String? get currentProfileId => sessionOnly
      ? profileId
      : owner != null
      ? owner!.profileId
      : document.profileId;
  int get currentRevision =>
      sessionOnly ? 0 : owner?.version ?? document.version;
  final Int64? sessionRevision;
  final int revision;
  final String? sessionId;
  final Int64 contextRevision;
  String get ownerTitle => _title;
  String get description => '$_title · ${sessionId ?? "Disconnected"}';
}
