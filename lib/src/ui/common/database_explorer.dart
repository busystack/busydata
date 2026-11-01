import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:grpc/grpc.dart' show ResponseFuture, GrpcError;
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../backend/connection_failure.dart';
import '../../backend/workbench_failure.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'connection_presentation.dart';

void _matchNamespaces(List<Object> arguments) {
  final reply = arguments[0] as SendPort;
  try {
    final expression = RegExp(arguments[1] as String, unicode: true);
    reply.send(
      (arguments[2] as List<String>).where(expression.hasMatch).toList(),
    );
  } catch (_) {
    reply.send(null);
  }
}

enum ExplorerLocalKind { folder, virtualGroup, virtualView, unboundGroup }

class ExplorerNode {
  ExplorerNode(
    this.key,
    this.profileId,
    this.label, {
    this.kind,
    this.catalog = '',
    this.schema = '',
    this.table = '',
    this.object,
    this.category = false,
    this.routineSubtype = rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
    this.localKind,
    this.localId = '',
  });
  final String key, profileId, catalog, schema, table;
  late final semanticsIdentity = sha256.convert(utf8.encode(key)).toString();
  String label;
  final rpc.ObjectKind? kind;
  rpc.SchemaObject? object;
  final bool category;
  final rpc.ObjectSubtype routineSubtype;
  final ExplorerLocalKind? localKind;
  final String localId;
  bool get isSource => localKind == null && key == profileId;
  bool expanded = false, loading = false, loaded = false, failed = false;
  String availability = '', continuation = '';
  String lookup = '';
  String lookupIdentifier = '', defaultNamespace = '';
  final verifiedSelectedNamespaces = <String>{};
  final missingNamespaces = <String>{};
  final verifiedExcludedNamespaces = <String>{},
      checkedExcludedNamespaces = <String>{};
  int? totalCount;
  bool complete = false;
  bool contextStale = false;
  bool localExpansionRestored = false;
  final previousPages = <String>[];
  String pageStart = '';
  Set<String>? selectedNamespaces;
  int generation = 0;
  int metadataConfigurationRevision = 0;
  List<ExplorerNode> children = [];
  ResponseFuture<rpc.SchemaObjects>? request;
}

class _TreeMove extends Intent {
  const _TreeMove(this.direction);
  final int direction;
}

class DatabaseExplorer extends StatefulWidget {
  const DatabaseExplorer({
    super.key,
    required this.model,
    required this.controls,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  @override
  State<DatabaseExplorer> createState() => _DatabaseExplorerState();
}

class _DatabaseExplorerState extends State<DatabaseExplorer> {
  // Server windows leave space for local folder/presentation nodes inside the
  // existing 2,048-node ceiling. A name page remains at most 128 entries.
  static const metadataNodeBudget = 1024;
  final filter = TextEditingController();
  final speed = TextEditingController();
  final speedFocus = FocusNode(canRequestFocus: false);
  final scroll = ScrollController();
  bool showFilter = false;
  bool speedActive = false, speedFilter = false;
  List<({ExplorerNode node, int depth})> visibleRows = [];
  final roots = <String, ExplorerNode>{};
  final localNodes = <String, ExplorerNode>{};
  final rowFocus = <String, FocusNode>{};
  String? selected, hovered;
  String? _pendingRestoredSelection;
  final selectedObjects = <String>{};
  Object? backend;
  final contexts =
      <String, (String?, Object?, String?, int?, WorkbenchFailureReason?)>{};
  List<Object?> _modelPresentation = [];
  int _revealRevision = 0;
  Timer? _presentationTimer;

  void modelChanged() {
    final model = widget.model;
    final presentation = <Object?>[
      model.backend,
      model.commands,
      model.namespaceSelectionRevision,
      model.showAllNamespaces,
      model.showEmptyGroups,
      model.localExplorerRevision,
      model.explorerRevealRevision,
      model.explorerPreferences.values.toList().join(','),
      model.explorerObjectKinds.map((k) => k.value).join(','),
      for (final profile in model.profiles)
        (
          profile.id,
          profile.name,
          profile.engine,
          profile.environment,
          profile.readOnly,
          profile.host,
          profile.port,
          profile.user,
          profile.database,
          model.favoriteProfiles.contains(profile.id),
          model.explorerSessions[profile.id],
        ),
      for (final session in model.sessions.values)
        (
          session.sessionId,
          session.profile.id,
          session.profile.engine,
          session.profile.environment,
          session.profile.readOnly,
          session.transaction,
          session.contextRevision,
          session.currentCatalog,
          session.currentSchema,
          model.metadataStampForSession(session.sessionId)?.sourceIdentity,
          model.metadataStampForSession(session.sessionId)?.configuration,
        ),
    ];
    if (listEquals(_modelPresentation, presentation)) return;
    _modelPresentation = presentation;
    changed();
    if (_revealRevision != model.explorerRevealRevision) {
      _revealRevision = model.explorerRevealRevision;
      final object = model.explorerReveal;
      if (object != null) {
        scheduleMicrotask(() => reveal(object, _revealRevision));
      }
    }
  }

  void syncRoots() {
    for (final profile in widget.model.profiles) {
      roots.putIfAbsent(
        profile.id,
        () => ExplorerNode(profile.id, profile.id, profile.name),
      );
    }
  }

  ExplorerNode localNode(
    String key,
    String profile,
    String label,
    ExplorerLocalKind kind, {
    String id = '',
    String catalog = '',
    String schema = '',
  }) {
    final node = localNodes.putIfAbsent(
      key,
      () => ExplorerNode(
        key,
        profile,
        label,
        localKind: kind,
        localId: id,
        catalog: catalog,
        schema: schema,
      )..expanded = widget.model.explorerExpanded.contains(key),
    );
    node.label = label;
    node.loaded = true;
    return node;
  }

  List<ExplorerNode> get presentationRoots {
    final model = widget.model;
    final folders = <String, ExplorerNode>{};
    for (final folder in model.sourceFolders.values) {
      folders[folder.id] = localNode(
        'folder:${folder.id}',
        '',
        folder.name,
        ExplorerLocalKind.folder,
        id: folder.id,
      );
    }
    ExplorerNode? item(String key) => key.startsWith('f:')
        ? folders[key.substring(2)]
        : roots[key.substring(2)];
    for (final folder in model.sourceFolders.values) {
      folders[folder.id]!.children = model
          .explorerSiblings(folder.id)
          .map(item)
          .whereType<ExplorerNode>()
          .toList();
    }
    final top = model
        .explorerSiblings('')
        .map(item)
        .whereType<ExplorerNode>()
        .toList();
    final unbound = model.virtualViews.values
        .where((v) => !model.profiles.any((p) => p.id == v.scope.profileId))
        .toList();
    ExplorerNode viewNode(
      VirtualViewDefinition view, {
      bool qualified = false,
    }) => localNode(
      'virtual:${view.id}:${view.scope.key}',
      view.scope.profileId,
      qualified
          ? [
              view.scope.catalog,
              if (view.scope.schema != view.scope.catalog ||
                  model.profiles
                          .where((p) => p.id == view.scope.profileId)
                          .firstOrNull
                          ?.engine ==
                      rpc.Engine.POSTGRESQL)
                view.scope.schema,
              view.name,
            ].join(' / ')
          : view.name,
      ExplorerLocalKind.virtualView,
      id: view.id,
      catalog: view.scope.catalog,
      schema: view.scope.schema,
    );
    final placed = <String>{};
    bool scopeSelected(ExplorerNode node) {
      ExplorerNode? current = node;
      while (current != null) {
        if (!namespaceSelected(current)) return false;
        current = nodes
            .where((parent) => parent.children.contains(current))
            .firstOrNull;
      }
      return true;
    }

    for (final node in nodes.toList()) {
      if (node.localKind != null ||
          !node.loaded ||
          node.object == null ||
          node.contextStale ||
          !scopeSelected(node) ||
          !(node.kind == rpc.ObjectKind.SCHEMA ||
              node.kind == rpc.ObjectKind.CATALOG &&
                  model.profiles
                          .where((p) => p.id == node.profileId)
                          .firstOrNull
                          ?.engine !=
                      rpc.Engine.POSTGRESQL)) {
        continue;
      }
      final views = model.virtualViews.values
          .where(
            (v) =>
                v.scope ==
                DatabaseCreationScope(
                  profileId: node.profileId,
                  catalog: node.catalog,
                  schema: node.schema,
                ),
          )
          .toList();
      node.children.removeWhere(
        (n) => n.localKind == ExplorerLocalKind.virtualGroup,
      );
      if (model.explorerPreferences['virtual'] == true &&
          (views.isNotEmpty || model.showEmptyGroups)) {
        final group = localNode(
          '${node.key}:virtual',
          node.profileId,
          strings(context).virtualViews,
          ExplorerLocalKind.virtualGroup,
          catalog: node.catalog,
          schema: node.schema,
        );
        group.children = views.map(viewNode).toList();
        placed.addAll(views.map((v) => v.id));
        group.totalCount = views.length;
        node.children.add(group);
      }
    }
    for (final profile in model.profiles) {
      final source = roots[profile.id]!;
      source.children.removeWhere(
        (n) => n.localKind == ExplorerLocalKind.virtualGroup,
      );
      final remaining = model.virtualViews.values
          .where(
            (v) => v.scope.profileId == profile.id && !placed.contains(v.id),
          )
          .toList();
      if (remaining.isNotEmpty &&
          model.explorerPreferences['virtual'] == true) {
        final group = localNode(
          'source-virtual:${profile.id}',
          profile.id,
          strings(context).virtualViews,
          ExplorerLocalKind.virtualGroup,
        );
        group.children = remaining
            .map((view) => viewNode(view, qualified: true))
            .toList();
        source.children.add(group);
        if (!source.localExpansionRestored) {
          source.localExpansionRestored = true;
          if (model.explorerExpanded.contains(source.key)) {
            source.expanded = true;
          }
        }
      }
    }
    if (unbound.isNotEmpty && model.explorerPreferences['virtual'] == true) {
      final group = localNode(
        'unbound-virtual',
        '',
        strings(context).unboundVirtualView,
        ExplorerLocalKind.unboundGroup,
      );
      group.children = unbound
          .map((view) => viewNode(view, qualified: true))
          .toList();
      top.add(group);
    }
    final retained = <String>{};
    void collect(ExplorerNode node) {
      if (!retained.add(node.key)) return;
      for (final child in node.children) {
        collect(child);
      }
    }

    for (final root in top) {
      collect(root);
    }
    localNodes.removeWhere((key, _) => !retained.contains(key));
    return top;
  }

  @override
  void initState() {
    super.initState();
    selected = widget.model.explorerSelection.isEmpty
        ? null
        : widget.model.explorerSelection;
    _pendingRestoredSelection = selected;
    filter.text = widget.model.explorerNameFilter;
    showFilter = filter.text.isNotEmpty;
    filter.addListener(filterChanged);
    widget.model.addListener(modelChanged);
    backend = widget.model.backend;
    syncRoots();
    for (final root in roots.values) {
      final sessionId = widget.model.explorerSessions[root.profileId];
      final stamp = sessionId == null
          ? null
          : widget.model.metadataStampForSession(sessionId);
      contexts[root.profileId] = (
        sessionId,
        widget.model.sessions[sessionId]?.contextRevision,
        stamp?.sourceIdentity,
        stamp?.configuration,
        sessionId == null
            ? null
            : widget.model.metadataSessionUnavailableReason(sessionId),
      );
    }
    scheduleMicrotask(modelChanged);
  }

  void filterChanged() {
    changed();
    saveTreePresentation();
  }

  void saveTreePresentation() {
    _presentationTimer?.cancel();
    _presentationTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      final model = widget.model;
      var bytes = 0;
      model.explorerExpanded.clear();
      for (final node in nodes.where((n) => n.expanded).take(256)) {
        bytes += utf8.encode(node.key).length;
        if (node.key.length <= 2048 && bytes <= 8192) {
          model.explorerExpanded.add(node.key);
        }
      }
      model.explorerSelection = selected != null && selected!.length <= 2048
          ? selected!
          : '';
      model.explorerNameFilter = String.fromCharCodes(
        filter.text.runes.take(256),
      );
      try {
        await model.savePresentation();
      } catch (failure) {
        if (mounted) {
          model.updateStatus(
            operationFailureSummary(failure, locale: strings(context)),
          );
        }
      }
    });
  }

  void changed() {
    if (!mounted) return;
    final sourceNames = connectionDisplayNames(
      context,
      widget.model.profiles.map((p) => (p.id, p.name)),
    );
    syncRoots();
    if (!identical(backend, widget.model.backend)) {
      for (final node in nodes) {
        node.generation++;
        node.request?.cancel();
        node.loading = false;
        node.loaded = false;
        node.contextStale = true;
        node.totalCount = null;
        node.selectedNamespaces = null;
        node.verifiedSelectedNamespaces.clear();
        node.availability = strings(context).staleRefresh;
      }
      backend = widget.model.backend;
    }
    for (final root in roots.values) {
      final sessionId = widget.model.explorerSessions[root.profileId];
      final session = widget.model.sessions[sessionId];
      final stamp = sessionId == null
          ? null
          : widget.model.metadataStampForSession(sessionId);
      final current = (
        sessionId,
        session?.contextRevision,
        stamp?.sourceIdentity,
        stamp?.configuration,
        sessionId == null
            ? null
            : widget.model.metadataSessionUnavailableReason(sessionId),
      );
      final previous = contexts[root.profileId];
      final ownerChanged =
          previous?.$1 != current.$1 ||
          previous?.$2 != current.$2 ||
          previous?.$5 != current.$5;
      // First authority observation belongs to the current acquisition. Only a
      // previously observed source/configuration change invalidates its pages.
      final configurationChanged =
          previous?.$3 != null &&
          (previous?.$3 != current.$3 || previous?.$4 != current.$4);
      if (ownerChanged || configurationChanged) {
        for (final node in nodes.where((n) => n.profileId == root.profileId)) {
          node.generation++;
          node.request?.cancel();
          node.loading = false;
          node.loaded = false;
          node.contextStale = true;
          node.totalCount = null;
          node.selectedNamespaces = null;
          node.verifiedSelectedNamespaces.clear();
          node.availability =
              session != null && !widget.model.metadataSessionUsable(sessionId)
              ? widget.model
                    .metadataSessionUnavailableReason(sessionId)!
                    .localized(strings(context))
              : strings(context).staleContext;
        }
        if (session != null &&
            session.transaction != rpc.TransactionState.DISCONNECTED &&
            session.transaction != rpc.TransactionState.UNKNOWN_TRANSACTION) {
          if (previous?.$1 == null) {
            root.expanded = true;
            selected = root.key;
          }
          scheduleMicrotask(() {
            if (mounted &&
                widget.model.metadataSessionUsable(
                  widget.model.explorerSessions[root.profileId],
                )) {
              reloadVisible(root);
            }
          });
        }
      }
      if (previous != current && session == null) {
        root.expanded = false;
        root.children = root.children
            .where((node) => node.localKind != null)
            .toList();
        if (nodes.any(
          (node) => node.key == selected && node.profileId == root.profileId,
        )) {
          selectNode(root);
        }
      }
      contexts[root.profileId] = current;
      final profile = widget.model.profiles
          .where((p) => p.id == root.profileId)
          .firstOrNull;
      if (profile != null) {
        root.label = sourceNames[profile.id]!;
      }
    }
    final retainedKeys = nodes.map((n) => n.key).toSet();
    for (final key
        in rowFocus.keys.where((key) => !retainedKeys.contains(key)).toList()) {
      rowFocus.remove(key)?.dispose();
    }
    setState(() {});
  }

  Future<void> reloadVisible(ExplorerNode node) async {
    if (!mounted || !node.expanded) return;
    if (!node.loaded && !node.loading) await load(node);
    if (!mounted || !node.loaded) return;
    for (final child in List<ExplorerNode>.of(node.children)) {
      if (child.expanded) await reloadVisible(child);
    }
  }

  Iterable<ExplorerNode> get nodes sync* {
    Iterable<ExplorerNode> walk(ExplorerNode node) sync* {
      yield node;
      for (final child in node.children) {
        yield* walk(child);
      }
    }

    final seen = <String>{};
    for (final root in [...roots.values, ...localNodes.values]) {
      for (final node in walk(root)) {
        if (seen.add(node.key)) yield node;
      }
    }
  }

  @override
  void dispose() {
    _presentationTimer?.cancel();
    speed.dispose();
    speedFocus.dispose();
    scroll.dispose();
    for (final focus in rowFocus.values) {
      focus.dispose();
    }
    widget.model.removeListener(modelChanged);
    filter.removeListener(filterChanged);
    filter.dispose();
    for (final node in nodes) {
      node.request?.cancel();
    }
    super.dispose();
  }

  rpc.Engine? sourceEngine(String profileId) =>
      widget
          .model
          .sessions[widget.model.explorerSessions[profileId]]
          ?.profile
          .engine ??
      widget.model.profiles
          .where((profile) => profile.id == profileId)
          .firstOrNull
          ?.engine;

  List<ExplorerNode> categories(ExplorerNode parent) => [
    for (final kind in [
      rpc.ObjectKind.TABLE,
      rpc.ObjectKind.VIEW,
      if ((widget
                  .model
                  .sessions[widget.model.explorerSessions[parent.profileId]]
                  ?.profile
                  .engine ??
              widget.model.profiles
                  .firstWhere((p) => p.id == parent.profileId)
                  .engine) !=
          rpc.Engine.MYSQL)
        rpc.ObjectKind.SEQUENCE,
      rpc.ObjectKind.ROUTINE,
      if (sourceEngine(parent.profileId) == rpc.Engine.POSTGRESQL)
        rpc.ObjectKind.TYPE,
    ])
      for (final subtype
          in kind == rpc.ObjectKind.ROUTINE &&
                  widget.model.explorerPreferences['separateRoutines'] == true
              ? [rpc.ObjectSubtype.FUNCTION, rpc.ObjectSubtype.PROCEDURE]
              : [rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED])
        ExplorerNode(
          '${parent.key}:${kind.value}${subtype == rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED ? '' : ':${subtype.value}'}',
          parent.profileId,
          switch (kind) {
            rpc.ObjectKind.TABLE => strings(context).tables,
            rpc.ObjectKind.VIEW => strings(context).views,
            rpc.ObjectKind.SEQUENCE => strings(context).sequences,
            rpc.ObjectKind.TYPE => strings(context).metadataType,
            _ =>
              subtype == rpc.ObjectSubtype.FUNCTION
                  ? strings(context).functions
                  : subtype == rpc.ObjectSubtype.PROCEDURE
                  ? strings(context).procedures
                  : strings(context).routines,
          },
          kind: kind,
          catalog: parent.catalog,
          schema: parent.schema,
          category: true,
          routineSubtype: subtype,
        ),
  ];
  DatabaseObjectIdentity identity(ExplorerNode node) => DatabaseObjectIdentity(
    profileId: node.profileId,
    catalog: node.object?.catalog.isNotEmpty == true
        ? node.object!.catalog
        : node.catalog,
    schema: node.object?.schema.isNotEmpty == true
        ? node.object!.schema
        : node.schema,
    kind: node.object?.kind ?? node.kind!,
    subtype:
        node.object?.subtype ?? rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
    name: node.object?.name ?? node.label,
    identifier: node.object?.identifier ?? '',
    parent:
        [
          rpc.ObjectKind.COLUMN,
          rpc.ObjectKind.INDEX,
          rpc.ObjectKind.CONSTRAINT,
          rpc.ObjectKind.FOREIGN_KEY,
          rpc.ObjectKind.TRIGGER,
        ].contains(node.kind)
        ? node.table
        : '',
  );
  WorkbenchCommandContext target(ExplorerNode node) => WorkbenchCommandContext(
    profileId: node.profileId.isEmpty ? null : node.profileId,
    metadataInstance: node.localKind == null
        ? widget.model.backend?.instanceId
        : null,
    metadataSources: node.localKind != null
        ? const {}
        : Map.unmodifiable({
            for (final id in {
              node.profileId,
              ...nodes
                  .where((n) => selectedObjects.contains(n.key))
                  .map((n) => n.profileId),
            })
              id: (
                sessionId: widget.model.explorerSessions[id],
                contextRevision: widget
                    .model
                    .sessions[widget.model.explorerSessions[id]]
                    ?.contextRevision
                    .toInt(),
                sessionRevision: widget
                    .model
                    .sessions[widget.model.explorerSessions[id]]
                    ?.sessionRevision
                    .toInt(),
              ),
          }),
    folderId: node.localKind == ExplorerLocalKind.folder ? node.localId : null,
    virtualViewId: node.localKind == ExplorerLocalKind.virtualView
        ? node.localId
        : null,
    virtualView: node.localKind == ExplorerLocalKind.virtualView
        ? widget.model.virtualViews[node.localId]
        : null,
    virtualSource: node.localKind == ExplorerLocalKind.virtualView
        ? widget.model.profiles
              .where((profile) => profile.id == node.profileId)
              .firstOrNull
              ?.deepCopy()
        : null,
    sessionId: widget.model.explorerSessions[node.profileId],
    object: node.object == null ? null : identity(node),
    objects: List.unmodifiable([
      for (final key in selectedObjects)
        if (nodes.where((n) => n.key == key && n.object != null).firstOrNull
            case final chosen?)
          identity(chosen),
    ]),
    metadataObject: node.object?.deepCopy(),
    metadataConfigurationRevision: node.metadataConfigurationRevision,
    creationScope: DatabaseCreationScope(
      profileId: node.profileId,
      catalog: node.catalog,
      schema: node.schema,
    ),
  );
  String openCommand(ExplorerNode node) => node.kind == rpc.ObjectKind.SEQUENCE
      ? 'object.ddl'
      : [rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW].contains(node.kind)
      ? 'object.data'
      : 'object.structure';
  void selectNode(ExplorerNode node, {bool additive = false}) {
    // Presentation recovery belongs to initial loading. Once the user chooses
    // a row, an older persisted selection cannot supersede that live intent.
    _pendingRestoredSelection = null;
    if (!additive && !selectedObjects.contains(node.key)) {
      selectedObjects.clear();
    }
    if (node.object != null &&
        ![rpc.ObjectKind.CATALOG, rpc.ObjectKind.SCHEMA].contains(node.kind)) {
      if (additive && selectedObjects.contains(node.key)) {
        selectedObjects.remove(node.key);
      } else {
        if (selectedObjects.length >= 2 &&
            !selectedObjects.contains(node.key)) {
          selectedObjects.remove(selectedObjects.first);
        }
        selectedObjects.add(node.key);
      }
    } else {
      selectedObjects.clear();
    }
    selected = node.key;
    widget.model.explorerCommandContext = target(node);
    saveTreePresentation();
  }

  void activateNode(ExplorerNode node) {
    if (node.localKind == ExplorerLocalKind.virtualView) {
      invoke('virtual.run', node);
    } else if (node.object == null ||
        [rpc.ObjectKind.CATALOG, rpc.ObjectKind.SCHEMA].contains(node.kind)) {
      expand(node);
    } else {
      invoke(openCommand(node), node);
    }
  }

  bool speedMatch(ExplorerNode node) =>
      speed.text.isNotEmpty &&
      node.label.toLowerCase().contains(speed.text.toLowerCase());

  void focusRow(ExplorerNode node) {
    setState(() => selectNode(node));
    var extent = 32.0;
    for (final row in visibleRows) {
      final rowContext = rowFocus[row.node.key]?.context;
      if (rowContext?.mounted != true) continue;
      final box = rowContext!.findRenderObject();
      if (row.node.object != null &&
          !row.node.expanded &&
          box is RenderBox &&
          box.hasSize) {
        extent = box.size.height;
        break;
      }
    }
    final focus = rowFocus.putIfAbsent(
      node.key,
      () => FocusNode(debugLabel: node.label),
    );
    if (focus.context?.mounted != true && scroll.hasClients) {
      // Keep keyboard events in the tree while its virtualized row mounts.
      // Requesting focus on a detached node can lose the next search character
      // or let an older match claim focus after a newer match is selected.
      widget.model.explorerFocus.requestFocus();
      final index = visibleRows.indexWhere((row) => row.node.key == node.key);
      scroll.jumpTo((index * extent).clamp(0, scroll.position.maxScrollExtent));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            selected == node.key &&
            rowFocus[node.key] == focus &&
            focus.context?.mounted == true) {
          focus.requestFocus();
        }
      });
    } else {
      focus.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && selected == node.key && focus.hasFocus) {
        focus.context?.findRenderObject()?.showOnScreen();
      }
    });
  }

  Future<void> reveal(DatabaseObjectIdentity object, int revision) async {
    final model = widget.model, l = strings(context);
    final process = model.backend;
    final expectedProfile = model.explorerRevealProfile?.deepCopy();
    bool sourceMatches() =>
        expectedProfile == null ||
        model.explorerSourceMatches(object, expectedProfile);
    bool current() =>
        mounted &&
        model.explorerRevealRevision == revision &&
        identical(process, model.backend) &&
        model.profiles.any((p) => p.id == object.profileId);
    try {
      final root = roots[object.profileId];
      if (root == null) throw StateError(l.selectTarget);
      if (!sourceMatches()) throw StateError(l.metadataContextChanged);
      // Reveal never changes the accepted namespace selection.
      if (model.namespaceSelection(object.profileId, '') case final rule?
          when rule.mode == NamespaceSelectionMode.names &&
                  !rule.names.contains(object.catalog) ||
              rule.mode == NamespaceSelectionMode.all &&
                  rule.excluded.contains(object.catalog)) {
        throw StateError(l.namespaceNotSelected);
      }
      if (model.namespaceSelection(object.profileId, object.catalog)
          case final rule?
          when rule.mode == NamespaceSelectionMode.names &&
                  !rule.names.contains(object.schema) ||
              rule.mode == NamespaceSelectionMode.all &&
                  rule.excluded.contains(object.schema)) {
        throw StateError(l.namespaceNotSelected);
      }
      if (model.explorerSessions[object.profileId] == null) {
        await invoke('connection.connect', root);
      }
      if (!current()) return;
      final sessionId = model.explorerSessions[object.profileId];
      bool ownerCurrent() =>
          current() &&
          sourceMatches() &&
          model.explorerSessions[object.profileId] == sessionId;
      Future<ExplorerNode> child(
        ExplorerNode parent,
        bool Function(ExplorerNode) matches, {
        String name = '',
        String identifier = '',
      }) async {
        if (!ownerCurrent()) throw StateError(l.metadataContextChanged);
        parent.expanded = true;
        if (!parent.loaded) await load(parent);
        if (!ownerCurrent()) throw StateError(l.staleContext);
        if (parent.failed) throw StateError(parent.availability);
        var found = parent.children.where(matches).firstOrNull;
        if (found == null && name.isNotEmpty) {
          cancelBranch(parent, invalidate: true);
          parent.lookup = name;
          parent.lookupIdentifier = identifier;
          await load(parent);
          if (!ownerCurrent()) throw StateError(l.staleContext);
          if (parent.failed) throw StateError(parent.availability);
          found = parent.children.where(matches).firstOrNull;
          // Substring lookup can still contain multiple overload pages.
          var pages = 0;
          while (found == null &&
              parent.continuation.isNotEmpty &&
              ++pages < 32) {
            await load(parent, append: true);
            if (!ownerCurrent()) throw StateError(l.staleContext);
            if (parent.failed) throw StateError(parent.availability);
            found = parent.children.where(matches).firstOrNull;
          }
        }
        if (found == null) {
          throw StateError(
            parent.continuation.isNotEmpty
                ? l.partialTreeLimit
                : l.objectNotFound,
          );
        }
        return found;
      }

      final database = await child(
        root,
        (n) => n.object?.name == object.catalog,
        name: object.catalog,
      );
      if (!namespaceSelected(database)) {
        throw StateError(l.namespaceNotSelected);
      }
      final engine =
          model.sessions[sessionId]?.profile.engine ??
          model.profiles.firstWhere((p) => p.id == object.profileId).engine;
      ExplorerNode namespace = database;
      if (engine == rpc.Engine.POSTGRESQL &&
          object.kind != rpc.ObjectKind.CATALOG) {
        namespace = await child(
          database,
          (n) => n.object?.name == object.schema,
          name: object.schema,
        );
        if (!namespaceSelected(namespace)) {
          throw StateError(l.namespaceNotSelected);
        }
      }
      ExplorerNode result = namespace;
      if (object.kind != rpc.ObjectKind.SCHEMA &&
          object.kind != rpc.ObjectKind.CATALOG) {
        final childKind = [
          rpc.ObjectKind.COLUMN,
          rpc.ObjectKind.INDEX,
          rpc.ObjectKind.CONSTRAINT,
          rpc.ObjectKind.FOREIGN_KEY,
          rpc.ObjectKind.TRIGGER,
        ].contains(object.kind);
        var parent = namespace;
        if (childKind) {
          final captured = model.captureSessionTarget(sessionId!);
          final relations = <rpc.SchemaObject>[];
          for (final kind in [rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW]) {
            final reply = await model.readMetadata(
              captured,
              rpc.ExploreRequest(
                independentMetadata: true,
                kind: kind,
                catalog: object.catalog,
                schema: object.schema,
                search: object.parent,
                exactName: true,
              ),
              maxObjects: 1,
              current: ownerCurrent,
            );
            relations.addAll(reply.objects);
          }
          if (relations.length != 1) throw StateError(l.objectNotFound);
          final relation = relations.single;
          final tables = await child(
            namespace,
            (n) => n.category && n.kind == relation.kind,
          );
          parent = await child(
            tables,
            (n) =>
                n.object?.name == object.parent &&
                n.object?.kind == relation.kind &&
                n.object?.subtype == relation.subtype,
            name: object.parent,
          );
        }
        final group = await child(
          parent,
          (n) =>
              n.category &&
              n.kind == object.kind &&
              (n.routineSubtype ==
                      rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED ||
                  n.routineSubtype == object.subtype),
        );
        result = await child(
          group,
          (n) =>
              n.object != null &&
              identity(n).profileId == object.profileId &&
              identity(n).catalog == object.catalog &&
              identity(n).schema == object.schema &&
              identity(n).kind == object.kind &&
              identity(n).name == object.name &&
              identity(n).parent == object.parent &&
              identity(n).identifier == object.identifier &&
              (object.subtype == rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED ||
                  identity(n).subtype == object.subtype),
          name: object.name,
          identifier: object.identifier,
        );
      }
      if (!ownerCurrent()) return;
      if (!visible(result) ||
          !model.explorerObjectKinds.contains(object.kind) ||
          speedFilter && speed.text.isNotEmpty && !speedMatch(result)) {
        throw StateError(l.objectHiddenByFilter);
      }
      // Open local source-folder ancestors without acquiring any connections.
      var folder = model.sourceFolderMembership[object.profileId] ?? '';
      while (folder.isNotEmpty) {
        localNodes['folder:$folder']?.expanded = true;
        folder = model.sourceFolders[folder]?.parentId ?? '';
      }
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ownerCurrent()) return;
        focusRow(result);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (ownerCurrent() && selected == result.key) {
            rowFocus[result.key]?.requestFocus();
          }
        });
      });
    } catch (failure) {
      if (current()) {
        model.updateStatus(
          failure is GrpcError
              ? ConnectionFailure.from(failure).localizedSummary(l)
              : operationFailureSummary(failure, locale: l),
        );
      }
    }
  }

  KeyEventResult treeKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyF &&
        keyboard.isControlPressed) {
      setState(() => speedActive = true);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape && speedActive) {
      setState(() {
        speedActive = false;
        speed.clear();
        speedFilter = false;
      });
      return KeyEventResult.handled;
    }
    if (!rowFocus.values.any((focus) => focus.hasFocus) &&
        !(speedActive && widget.model.explorerFocus.hasPrimaryFocus)) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace && speedActive) {
      setState(
        () => speed.text = String.fromCharCodes(
          speed.text.runes.take((speed.text.runes.length - 1).clamp(0, 256)),
        ),
      );
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (character == null ||
        character.isEmpty ||
        character.codeUnitAt(0) < 32 ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return KeyEventResult.ignored;
    }
    if (speed.text.length + character.length > 256) {
      return KeyEventResult.handled;
    }
    setState(() {
      speedActive = true;
      speed.text += character;
    });
    final matched = visibleRows
        .where((row) => speedMatch(row.node))
        .firstOrNull;
    if (matched != null) focusRow(matched.node);
    return KeyEventResult.handled;
  }

  double labelWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: widget.controls
            .textStyle(context)
            .copyWith(fontWeight: FontWeight.w600),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  Widget namespaceControl(ExplorerNode node, String badge, double width) =>
      widget.controls.tooltip(
        '$badge\n${strings(context).namespaceSelectionNotice}',
        SizedBox(
          width: width,
          child: widget.controls.textButton(
            badge,
            node.loading ? null : () => namespaceSelector(node),
            compact: true,
          ),
        ),
      );

  Widget nodeText(ExplorerNode node, String label) {
    if (!speedMatch(node)) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final match = RegExp(
      RegExp.escape(speed.text),
      caseSensitive: false,
    ).firstMatch(label);
    if (match == null) {
      return Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label.substring(0, match.start)),
          TextSpan(
            text: label.substring(match.start, match.end),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
              color: null,
            ),
          ),
          TextSpan(text: label.substring(match.end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Future<void> invoke(
    String id,
    ExplorerNode? node, {
    WorkbenchCommandContext? captured,
  }) async {
    try {
      await widget.model.commands?.invoke(
        id,
        captured ??
            (node == null ? const WorkbenchCommandContext() : target(node)),
      );
    } catch (error) {
      widget.model.updateStatus('$error');
    }
  }

  Future<void> expand(ExplorerNode node) async {
    setState(() => node.expanded = !node.expanded);
    saveTreePresentation();
    if (!node.expanded) {
      cancelBranch(node);
      return;
    }
    if (node.localKind != null) {
      await reloadVisible(node);
      return;
    }
    if (node.isSource &&
        widget.model.explorerSessions[node.profileId] == null &&
        widget.model.virtualViews.values.any(
          (v) => v.scope.profileId == node.profileId,
        )) {
      setState(() => node.availability = strings(context).explorerDisconnected);
      return;
    }
    if (node.loaded) {
      await reloadVisible(node);
      return;
    }
    if (widget.model.explorerSessions[node.profileId] == null) {
      setState(() => node.availability = strings(context).connectionConnecting);
      await invoke('connection.connect', node);
      if (!mounted || !node.expanded || node.loaded || node.loading) return;
    }
    await load(node);
  }

  void cancelBranch(ExplorerNode node, {bool invalidate = false}) {
    node.generation++;
    unawaited(node.request?.cancel());
    if (node.loading) node.availability = strings(context).cancelled;
    node.loading = false;
    if (invalidate) {
      node.loaded = false;
      node.continuation = '';
      node.previousPages.clear();
      node.pageStart = '';
    }
    for (final child in node.children) {
      cancelBranch(child, invalidate: invalidate);
    }
  }

  void releaseCollapsedMetadata(ExplorerNode protected, int needed) {
    if (nodes.length + needed <= metadataNodeBudget) return;
    bool contains(ExplorerNode node, ExplorerNode target) => node.children.any(
      (child) => identical(child, target) || contains(child, target),
    );
    for (final node in nodes.toList()) {
      if (nodes.length + needed <= metadataNodeBudget) break;
      if (node.localKind != null ||
          node.expanded ||
          node.children.isEmpty ||
          identical(node, protected) ||
          contains(node, protected)) {
        continue;
      }
      cancelBranch(node, invalidate: true);
      node.children = node.children
          .where((child) => child.localKind != null)
          .toList();
    }
  }

  Future<void> refreshTree(
    ExplorerNode node, {
    DatabaseObjectIdentity? definitionScope,
  }) async {
    if (node.localKind != null) return;
    node.lookup = '';
    node.lookupIdentifier = '';
    if (node.object != null &&
        ![rpc.ObjectKind.CATALOG, rpc.ObjectKind.SCHEMA].contains(node.kind)) {
      final parent = nodes
          .where((entry) => entry.children.contains(node))
          .firstOrNull;
      if (parent != null) {
        await refreshTree(parent, definitionScope: identity(node));
        return;
      }
    }
    cancelBranch(node);
    int? appliedGeneration;
    await load(
      node,
      refresh: true,
      restoreSelection: true,
      onApplied: (generation) => appliedGeneration = generation,
    );
    if (!mounted || node.failed || node.generation != appliedGeneration) return;
    await reloadVisible(node);
    if (!mounted || node.generation != appliedGeneration) return;
    bool relatedToRelation(DatabaseObjectIdentity object, String relation) =>
        object.parent == relation ||
        [rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW].contains(object.kind) &&
            object.name == relation;
    bool matchesDefinition(DatabaseObjectIdentity object) {
      final scope = definitionScope;
      if (scope == null) return true;
      if (scope.parent.isNotEmpty) {
        return relatedToRelation(object, scope.parent);
      }
      if ([rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW].contains(scope.kind) &&
          relatedToRelation(object, scope.name)) {
        return true;
      }
      return object.kind == scope.kind &&
          object.name == scope.name &&
          (scope.identifier.isEmpty || object.identifier == scope.identifier);
    }

    for (final owner in widget.model.taskDocuments) {
      final object = owner.object;
      if (object == null ||
          object.profileId != node.profileId ||
          node.catalog.isNotEmpty && object.catalog != node.catalog ||
          node.schema.isNotEmpty && object.schema != node.schema ||
          node.table.isNotEmpty && !relatedToRelation(object, node.table) ||
          !matchesDefinition(object)) {
        continue;
      }
      owner.view.metadataRevision++;
    }
    widget.model.updateStatus(strings(context).refresh);
  }

  Future<void> load(
    ExplorerNode node, {
    bool refresh = false,
    bool append = false,
    bool previousPage = false,
    bool namesOnly = false,
    bool restoreSelection = false,
    void Function(int)? onApplied,
    NamespaceSelection? pendingSelection,
    bool Function()? mayAdopt,
  }) async {
    if (node.localKind != null) return;
    final model = widget.model, process = widget.model.backend;
    final sessionId = model.explorerSessions[node.profileId];
    if (process == null ||
        sessionId == null ||
        !model.sessions.containsKey(sessionId)) {
      setState(() => node.availability = strings(context).explorerDisconnected);
      return;
    }
    final session = model.sessions[sessionId]!,
        contextRevision = session.contextRevision;
    final unavailable = model.metadataSessionUnavailableReason(sessionId);
    if (unavailable != null) {
      node.generation++;
      unawaited(node.request?.cancel());
      setState(() {
        node.loading = false;
        node.loaded = false;
        node.contextStale = true;
        node.availability = unavailable.localized(strings(context));
      });
      return;
    }
    if (node.object != null &&
        [rpc.ObjectKind.CATALOG, rpc.ObjectKind.SCHEMA].contains(node.kind) &&
        !namespaceSelected(node)) {
      setState(() {
        node.loading = false;
        node.availability = strings(context).namespaceNotSelected;
      });
      return;
    }
    final requested = ++node.generation;
    await node.request?.cancel();
    if (!mounted) return;
    if (refresh) {
      // Stop descendant acquisitions while preserving the last adopted page.
      // A rejected refresh cannot retire its cursors before publication.
      for (final child in node.children) {
        cancelBranch(child);
      }
    }
    setState(() {
      node.loading = true;
      node.failed = false;
      node.availability = strings(context).loading;
    });
    try {
      final namespaceList =
          node.kind == null ||
          (node.kind == rpc.ObjectKind.CATALOG &&
              node.object != null &&
              session.profile.engine == rpc.Engine.POSTGRESQL);
      if (!namespaceList &&
          node.object != null &&
          [rpc.ObjectKind.SCHEMA, rpc.ObjectKind.CATALOG].contains(node.kind)) {
        final previous = {for (final child in node.children) child.key: child};
        releaseCollapsedMetadata(node, 4);
        if (nodes.length +
                categories(
                  node,
                ).where((child) => !previous.containsKey(child.key)).length >
            metadataNodeBudget) {
          throw StateError(strings(context).partialTreeLimit);
        }
        node.children = [
          for (final child in categories(node)) previous[child.key] ?? child,
        ];
        var first = true;
        for (final child in node.children) {
          if (!mounted || requested != node.generation) return;
          if (child.localKind == null && (!child.loaded || refresh)) {
            await load(child, refresh: refresh && first, namesOnly: true);
            child.loaded = false;
            if (model.explorerPreferences['schemaGroups'] == false) {
              child.expanded = true;
              await load(child);
            }
          }
          first = false;
        }
        node.availability = '';
        node.complete = true;
      } else if (node.object != null &&
          [rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW].contains(node.kind)) {
        final previous = {for (final child in node.children) child.key: child};
        final groups = [
          for (final kind in [
            rpc.ObjectKind.COLUMN,
            rpc.ObjectKind.INDEX,
            rpc.ObjectKind.CONSTRAINT,
            rpc.ObjectKind.FOREIGN_KEY,
            rpc.ObjectKind.TRIGGER,
          ])
            ExplorerNode(
              '${node.key}:${kind.value}',
              node.profileId,
              switch (kind) {
                rpc.ObjectKind.COLUMN => strings(context).columns,
                rpc.ObjectKind.INDEX => strings(context).indexes,
                rpc.ObjectKind.CONSTRAINT => strings(context).constraints,
                rpc.ObjectKind.FOREIGN_KEY => strings(context).foreignKeys,
                _ => strings(context).triggers,
              },
              kind: kind,
              catalog: node.catalog,
              schema: node.schema,
              table: node.object!.name,
              category: true,
            ),
        ];
        releaseCollapsedMetadata(node, groups.length);
        if (nodes.length +
                groups
                    .where((child) => !previous.containsKey(child.key))
                    .length >
            metadataNodeBudget) {
          throw StateError(strings(context).partialTreeLimit);
        }
        node.children = [
          for (final group in groups) previous[group.key] ?? group,
        ];
        var first = true;
        for (final child in node.children) {
          if (!mounted || requested != node.generation) return;
          if (!child.loaded || refresh) {
            await load(child, refresh: refresh && first, namesOnly: true);
            child.loaded = false;
            if (model.explorerPreferences['tableGroups'] == false &&
                child.kind == rpc.ObjectKind.COLUMN) {
              child.expanded = true;
              await load(child);
            }
          }
          first = false;
        }
        node.availability = '';
        node.complete = true;
      } else {
        releaseCollapsedMetadata(node, 128 - node.children.length);
        final room =
            (metadataNodeBudget -
                    nodes.length +
                    node.children.length -
                    (namespaceList ? 1 : 0))
                .clamp(0, 128);
        if (room == 0) {
          setState(() {
            node.loading = false;
            node.availability = strings(context).partialTreeLimit;
          });
          return;
        }
        final requestedStart = previousPage
            ? node.previousPages.last
            : append
            ? node.continuation
            : '';
        node.request = process.client.explore(
          rpc.ExploreRequest(
            independentMetadata: true,
            context: process.context(),
            sessionId: sessionId,
            kind: node.kind == null
                ? rpc.ObjectKind.CATALOG
                : namespaceList
                ? rpc.ObjectKind.SCHEMA
                : node.kind,
            catalog: node.kind == null ? '' : node.catalog,
            schema: node.schema,
            table: node.table,
            search: node.lookup,
            exactName: node.lookup.isNotEmpty,
            identifier: node.lookupIdentifier,
            subtype: node.routineSubtype,
            refresh: refresh,
            continuation: requestedStart,
            limit: namesOnly ? 1 : room,
            expectedSessionRevision: session.sessionRevision,
            expectedContextRevision: session.contextRevision,
          ),
        );
        final response = await node.request!;
        if (!mounted ||
            mayAdopt?.call() == false ||
            requested != node.generation ||
            !identical(model.backend, process) ||
            model.explorerSessions[node.profileId] != sessionId ||
            model.sessions[sessionId]?.contextRevision != contextRevision) {
          return;
        }
        final requestedKind = node.kind == null
            ? rpc.ObjectKind.CATALOG
            : namespaceList
            ? rpc.ObjectKind.SCHEMA
            : node.kind;
        final requestedCatalog = node.kind == null
            ? session.currentCatalog
            : node.catalog;
        if (response.instanceId != process.instanceId ||
            response.profileId != node.profileId ||
            response.sessionId != sessionId ||
            response.contextRevision != contextRevision ||
            response.sessionRevision <
                model.sessions[sessionId]!.sessionRevision ||
            response.catalog != requestedCatalog ||
            response.schema != node.schema ||
            response.parent != node.table ||
            response.kind != requestedKind ||
            response.subtype != node.routineSubtype ||
            response.objects.length > (namesOnly ? 1 : room) ||
            response.writeToBuffer().length > 1048576 ||
            response.continuation.length > 24576 ||
            response.complete && response.continuation.isNotEmpty ||
            !response.complete &&
                response.continuation.isEmpty &&
                !response.availability.startsWith('limited') ||
            response.continuation.isNotEmpty &&
                (response.continuation == requestedStart ||
                    append &&
                        node.previousPages.contains(response.continuation)) ||
            response.defaultNamespace.length > 256 ||
            response.defaultNamespace.contains('\u0000') ||
            response.objects.any(
              (object) =>
                  object.kind != requestedKind ||
                  node.routineSubtype !=
                          rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED &&
                      object.subtype != node.routineSubtype ||
                  utf8.encode(object.identifier).length > 8192 ||
                  requestedKind != rpc.ObjectKind.CATALOG &&
                      object.catalog != requestedCatalog ||
                  requestedKind != rpc.ObjectKind.CATALOG &&
                      requestedKind != rpc.ObjectKind.SCHEMA &&
                      object.schema != node.schema ||
                  node.table.isNotEmpty && object.table != node.table,
            )) {
          throw StateError(strings(context).metadataContextChanged);
        }
        if (!model.acceptMetadataRevision(sessionId, response)) {
          throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
        }
        // Keep the current native selection attached while replacing a page.
        // A fresh enumeration invalidates its old cursor, so use the existing
        // bounded exact-object window if the object is outside the first page.
        // Ordinary paging never restores an object from a previous window.
        final retainedSelection = restoreSelection && node.category
            ? node.children
                  .where(
                    (child) => child.key == selected && child.object != null,
                  )
                  .firstOrNull
            : null;
        if (retainedSelection != null &&
            !response.complete &&
            !response.objects.any(
              (object) =>
                  object.kind == retainedSelection.kind &&
                  object.name == retainedSelection.object!.name &&
                  object.identifier == retainedSelection.object!.identifier &&
                  object.subtype == retainedSelection.object!.subtype,
            )) {
          node.lookup = retainedSelection.object!.name;
          node.lookupIdentifier = retainedSelection.object!.identifier;
          await load(node, onApplied: onApplied);
          return;
        }
        final previous = {for (final child in node.children) child.key: child};
        final available =
            (metadataNodeBudget - nodes.length + node.children.length).clamp(
              0,
              metadataNodeBudget,
            );
        final children = <String, ExplorerNode>{};
        final stagedMetadata =
            <ExplorerNode, ({rpc.SchemaObject object, int configuration})>{};
        var limited = false;
        for (final object in response.objects) {
          final key =
              '${node.key}\u0000object\u0000${DatabaseObjectIdentity(profileId: node.profileId, catalog: object.catalog.isEmpty ? node.catalog : object.catalog, schema: object.schema.isEmpty ? node.schema : object.schema, kind: object.kind, subtype: object.subtype, name: object.name, parent: object.table, identifier: object.identifier).key}';
          // JDBC index/FK rows describe each column of one logical object.
          // One tree node represents that object; Structure keeps ordered rows.
          if (children.containsKey(key)) continue;
          if (children.length >= available) {
            limited = true;
            break;
          }
          children[key] =
              previous[key] ??
              ExplorerNode(
                key,
                node.profileId,
                object.kind == rpc.ObjectKind.ROUTINE &&
                        session.profile.engine == rpc.Engine.POSTGRESQL &&
                        object.identifier.isNotEmpty
                    ? object.identifier
                    : object.name,
                kind: object.kind,
                catalog: object.catalog.isEmpty ? node.catalog : object.catalog,
                schema:
                    object.kind == rpc.ObjectKind.SCHEMA ||
                        object.kind == rpc.ObjectKind.CATALOG &&
                            session.profile.engine != rpc.Engine.POSTGRESQL
                    ? object.name
                    : object.schema.isEmpty
                    ? node.schema
                    : object.schema,
                table: object.table,
                object: object,
              );
          stagedMetadata[children[key]!] = (
            object: object,
            configuration: response.metadataConfigurationRevision.toInt(),
          );
        }
        final stagedChildren = children.values.toList();
        final stagedDefault = response.defaultNamespace;
        final resetEvidence = namespaceList && requestedStart.isEmpty;
        final stagedVerifiedSelected = resetEvidence
            ? <String>{}
            : Set<String>.of(node.verifiedSelectedNamespaces);
        final stagedMissing = resetEvidence
            ? <String>{}
            : Set<String>.of(node.missingNamespaces);
        final stagedVerifiedExcluded = resetEvidence
            ? <String>{}
            : Set<String>.of(node.verifiedExcludedNamespaces);
        final stagedCheckedExcluded = resetEvidence
            ? <String>{}
            : Set<String>.of(node.checkedExcludedNamespaces);
        if (namespaceList &&
            (!response.complete || requestedStart.isNotEmpty)) {
          final accepted =
              pendingSelection ??
              model.namespaceSelection(
                node.profileId,
                node.kind == null ? '' : node.catalog,
              );
          final requestedNames = <String>{
            if (stagedDefault.isNotEmpty) stagedDefault,
            if (accepted?.mode == NamespaceSelectionMode.names)
              ...accepted!.names,
            if (accepted?.mode == NamespaceSelectionMode.all)
              ...accepted!.excluded,
          };
          for (final wanted
              in requestedNames
                  .where(
                    (name) =>
                        stagedChildren.every((child) => child.label != name),
                  )
                  .take(129)) {
            if (nodes.length - node.children.length + stagedChildren.length >=
                metadataNodeBudget) {
              break;
            }
            node.request = process.client.explore(
              rpc.ExploreRequest(
                independentMetadata: true,
                context: process.context(),
                sessionId: sessionId,
                kind: requestedKind,
                catalog: node.kind == null ? '' : node.catalog,
                schema: node.schema,
                search: wanted,
                exactName: true,
                limit: 1,
                expectedSessionRevision:
                    model.sessions[sessionId]!.sessionRevision,
                expectedContextRevision: contextRevision,
              ),
            );
            final exact = await node.request!;
            if (!mounted ||
                mayAdopt?.call() == false ||
                requested != node.generation ||
                !identical(model.backend, process) ||
                model.explorerSessions[node.profileId] != sessionId ||
                model.sessions[sessionId]?.contextRevision != contextRevision) {
              return;
            }
            if (exact.instanceId != process.instanceId ||
                exact.profileId != node.profileId ||
                exact.sessionId != sessionId ||
                exact.contextRevision != contextRevision ||
                exact.sessionRevision !=
                    model.sessions[sessionId]!.sessionRevision ||
                exact.catalog != requestedCatalog ||
                exact.schema != node.schema ||
                exact.parent.isNotEmpty ||
                exact.kind != requestedKind ||
                exact.objects.length > 1 ||
                !exact.complete ||
                exact.continuation.isNotEmpty ||
                exact.writeToBuffer().length > 65536 ||
                exact.objects.any(
                  (o) =>
                      o.name != wanted ||
                      o.kind != requestedKind ||
                      o.catalog !=
                          (requestedKind == rpc.ObjectKind.CATALOG
                              ? wanted
                              : requestedCatalog),
                )) {
              throw StateError(strings(context).staleContext);
            }
            if (!model.acceptMetadataRevision(sessionId, exact)) {
              throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
            }
            if (exact.objects.isNotEmpty &&
                nodes.length - node.children.length + stagedChildren.length <
                    metadataNodeBudget) {
              final object = exact.objects.single;
              final catalog = requestedKind == rpc.ObjectKind.CATALOG
                  ? object.name
                  : node.catalog;
              final schema =
                  requestedKind == rpc.ObjectKind.SCHEMA ||
                      session.profile.engine != rpc.Engine.POSTGRESQL
                  ? object.name
                  : '';
              final key =
                  '${node.key}\u0000object\u0000${DatabaseObjectIdentity(profileId: node.profileId, catalog: object.catalog, schema: object.schema, kind: object.kind, name: object.name).key}';
              final child =
                  previous[key] ??
                  ExplorerNode(
                    key,
                    node.profileId,
                    object.name,
                    kind: object.kind,
                    catalog: catalog,
                    schema: schema,
                    object: object,
                  );
              stagedChildren.add(child);
              stagedMetadata[child] = (
                object: object,
                configuration: exact.metadataConfigurationRevision.toInt(),
              );
            }
            if (exact.objects.isEmpty) stagedMissing.add(wanted);
            if (accepted?.mode == NamespaceSelectionMode.all &&
                accepted!.excluded.contains(wanted)) {
              stagedCheckedExcluded.add(wanted);
              if (exact.objects.isNotEmpty) {
                stagedVerifiedExcluded.add(wanted);
              }
            }
          }
        }
        // All acquisition awaits precede the single presentation adoption.
        // A newer exact lookup cannot mix its rows with an older main page.
        if (!model.acceptMetadataRevision(sessionId, response)) {
          throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
        }
        if (!mounted ||
            mayAdopt?.call() == false ||
            requested != node.generation ||
            !identical(model.backend, process) ||
            model.explorerSessions[node.profileId] != sessionId ||
            model.sessions[sessionId]?.contextRevision != contextRevision) {
          return;
        }
        if (nodes.length - node.children.length + stagedChildren.length >
            metadataNodeBudget) {
          throw StateError(strings(context).partialTreeLimit);
        }
        if (refresh) {
          for (final child in stagedChildren) {
            cancelBranch(child, invalidate: true);
          }
        }
        for (final entry in stagedMetadata.entries) {
          entry.key.object = entry.value.object;
          entry.key.metadataConfigurationRevision = entry.value.configuration;
        }
        node.children = stagedChildren;
        node.metadataConfigurationRevision = response
            .metadataConfigurationRevision
            .toInt();
        node.defaultNamespace = stagedDefault;
        node.verifiedSelectedNamespaces
          ..clear()
          ..addAll(stagedVerifiedSelected);
        node.missingNamespaces
          ..clear()
          ..addAll(stagedMissing);
        node.verifiedExcludedNamespaces
          ..clear()
          ..addAll(stagedVerifiedExcluded);
        node.checkedExcludedNamespaces
          ..clear()
          ..addAll(stagedCheckedExcluded);
        // A concurrent branch can consume the remaining widget budget while
        // this request is in flight. Never advance beyond uninstantiated names.
        node.continuation = limited ? requestedStart : response.continuation;
        if (!limited) {
          if (previousPage) {
            node.previousPages.removeLast();
          } else if (append) {
            if (node.previousPages.length >= 32) {
              node.previousPages.removeAt(0);
            }
            node.previousPages.add(node.pageStart);
          } else {
            node.previousPages.clear();
          }
          node.pageStart = requestedStart;
        }
        node.complete = response.complete && !limited;
        node.totalCount = node.lookup.isNotEmpty
            ? null
            : response.hasTotalCount() &&
                  response.countAvailability ==
                      rpc.MetadataCount.AUTHORITATIVE_TOTAL
            ? response.totalCount.toInt()
            : response.complete && !limited && requestedStart.isEmpty
            ? children.length
            : null;
        node.availability = node.lookup.isNotEmpty
            ? response.objects.isEmpty && response.complete
                  ? strings(context).objectNotFound
                  : strings(context).revealFilterNotice
            : limited
            ? strings(context).partialTreeLimit
            : response.availability;
        for (final child in node.children) {
          child.contextStale = false;
        }
        final retained = nodes.map((n) => n.key).toSet();
        for (final key
            in rowFocus.keys.where((key) => !retained.contains(key)).toList()) {
          rowFocus.remove(key)?.dispose();
        }
        if (selected != null && !retained.contains(selected)) selectNode(node);
        if (namespaceList) {
          await updateNamespaceSelection(
            node,
            session,
            selectionOverride: pendingSelection,
          );
          if (!mounted || requested != node.generation) return;
          final acceptedSelection =
              pendingSelection ??
              model.namespaceSelection(
                node.profileId,
                node.kind == null ? '' : node.catalog,
              );
          if (acceptedSelection?.mode == NamespaceSelectionMode.names &&
              acceptedSelection!.names.isEmpty &&
              (node.totalCount ?? 0) > 0) {
            node.availability = strings(context).namespaceNotSelected;
          }
          if ((node.kind == null ||
                  model.explorerPreferences['namespaceGroups'] == false) &&
              !append &&
              !previousPage) {
            for (final child in node.children.where(
              (n) => node.selectedNamespaces?.contains(n.label) == true,
            )) {
              if (!mounted || requested != node.generation || !node.expanded) {
                return;
              }
              if (session.profile.engine == rpc.Engine.POSTGRESQL ||
                  model.explorerPreferences['namespaceGroups'] == false) {
                child.expanded = true;
                await load(child);
              }
            }
          }
        }
      }
      for (final child in node.children) {
        if (model.explorerExpanded.contains(child.key)) child.expanded = true;
        if (child.key == _pendingRestoredSelection) {
          selected = child.key;
          _pendingRestoredSelection = null;
        }
        if (child.expanded &&
            !child.loaded &&
            !child.loading &&
            namespaceSelected(child)) {
          await load(child);
        }
      }
      if (mounted && requested == node.generation) {
        setState(() {
          node.loaded = true;
          node.contextStale = false;
          node.loading = false;
        });
        onApplied?.call(requested);
      }
    } catch (error) {
      if (mounted && requested == node.generation) {
        setState(() {
          node.loading = false;
          node.failed = true;
          if (error is LocalWorkbenchFailure &&
              error.reason == WorkbenchFailureReason.stale) {
            // Keep the last adopted page and its exact count/cursor evidence.
            node.contextStale = true;
            node.availability = operationFailureSummary(
              error,
              locale: strings(context),
            );
          } else {
            node.totalCount = null;
            node.complete = false;
            node.continuation = '';
            node.availability = ConnectionFailure.from(
              error,
            ).localizedSummary(strings(context));
          }
        });
      }
    }
  }

  Future<void> updateNamespaceSelection(
    ExplorerNode node,
    rpc.SessionInfo session, {
    NamespaceSelection? selectionOverride,
  }) async {
    final model = widget.model;
    final catalog = node.kind == null ? '' : node.catalog;
    var selection =
        selectionOverride ?? model.namespaceSelection(node.profileId, catalog);
    if (selection == null) {
      final wanted = node.defaultNamespace.isNotEmpty
          ? node.defaultNamespace
          : node.kind == null
          ? session.currentCatalog
          : node.children
                    .where(
                      (child) => [
                        'true',
                        '1',
                      ].contains(child.object?.properties['defaultNamespace']),
                    )
                    .firstOrNull
                    ?.label ??
                (node.catalog == session.currentCatalog
                    ? session.currentSchema
                    : '');
      final known = node.children
          .where((n) => n.localKind == null)
          .map((n) => n.label)
          .toSet();
      final fallback = catalog.isNotEmpty && known.contains('public')
          ? 'public'
          : '';
      selection = NamespaceSelection(
        names: wanted.isNotEmpty
            ? [wanted]
            : fallback.isNotEmpty
            ? [fallback]
            : [],
      );
      model.seedNamespaces(node.profileId, catalog, selection);
    }
    node.selectedNamespaces = await selectedNames(
      selection,
      node.children
          .where((n) => n.localKind == null)
          .map((n) => n.label)
          .toList(),
    );
    if (selection.mode == NamespaceSelectionMode.names) {
      node.verifiedSelectedNamespaces.removeWhere(
        (name) => !selection!.names.contains(name),
      );
      node.verifiedSelectedNamespaces.addAll(node.selectedNamespaces!);
    } else {
      node.verifiedSelectedNamespaces.clear();
      final known = node.children
          .where((n) => n.localKind == null)
          .map((n) => n.label)
          .toSet();
      node.verifiedExcludedNamespaces.removeWhere(
        (n) => !selection!.excluded.contains(n),
      );
      node.checkedExcludedNamespaces.removeWhere(
        (n) => !selection!.excluded.contains(n),
      );
      node.verifiedExcludedNamespaces.addAll(
        selection.excluded.intersection(known),
      );
      node.checkedExcludedNamespaces.addAll(
        selection.excluded.intersection(known),
      );
      if (node.pageStart.isEmpty && node.complete) {
        node.checkedExcludedNamespaces.addAll(selection.excluded);
      }
    }
  }

  Future<Set<String>> selectedNames(
    NamespaceSelection selection,
    List<String> names,
  ) async {
    if (selection.mode == NamespaceSelectionMode.all) {
      return names.toSet().difference(selection.excluded);
    }
    if (selection.mode == NamespaceSelectionMode.names) {
      return selection.names.intersection(names.toSet());
    }
    final port = ReceivePort();
    Isolate? worker;
    try {
      worker = await Isolate.spawn(_matchNamespaces, <Object>[
        port.sendPort,
        selection.pattern,
        names,
      ]);
      final result = await port.first.timeout(
        const Duration(milliseconds: 200),
      );
      if (result is! List) {
        throw const FormatException('Invalid namespace pattern');
      }
      return result.cast<String>().toSet();
    } finally {
      worker?.kill(priority: Isolate.immediate);
      port.close();
    }
  }

  Future<void> namespaceSelector(ExplorerNode node) async {
    final model = widget.model, ui = widget.controls, l = strings(context);
    if (model.explorerSessions[node.profileId] == null) {
      await invoke('connection.connect', node);
      if (!mounted || model.explorerSessions[node.profileId] == null) return;
    }
    if (!node.loaded) await load(node);
    if (!mounted || node.failed) return;
    final catalog = node.kind == null ? '' : node.catalog;
    final initial =
        model.namespaceSelection(node.profileId, catalog) ??
        NamespaceSelection();
    var mode = initial.mode;
    var chosen = Set<String>.of(initial.names);
    var excluded = Set<String>.of(initial.excluded);
    final pattern = TextEditingController(text: initial.pattern);
    var working = false, error = '';
    var pendingApplied = false;
    final sourceSession = model.explorerSessions[node.profileId];
    final sourceProfile = model.profiles
        .firstWhere((p) => p.id == node.profileId)
        .deepCopy();
    final sourceTarget = model.captureSessionTarget(sourceSession!);
    bool sourceCurrent() =>
        mounted &&
        identical(model.backend, sourceTarget.backend) &&
        model.sessions[sourceSession]?.contextRevision ==
            sourceTarget.contextRevision &&
        model.explorerSessions[node.profileId] == sourceSession &&
        model.profiles.any(
          (p) =>
              p.id == node.profileId &&
              WorkbenchModel.sameConnectionTarget(p, sourceProfile),
        );
    try {
      await ui.formDialog<void>(
        context,
        (dialogContext) => StatefulBuilder(
          builder: (context, update) {
            final known = node.children
                .where((child) => child.localKind == null)
                .map((child) => child.label)
                .toList();
            return ui.formShell(
              l.namespaceSelection,
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${node.label}\n${l.namespaceSelectionNotice}'),
                  ui.choice(
                    mode,
                    {
                      NamespaceSelectionMode.names: l.selected,
                      NamespaceSelectionMode.all: l.allNamespaces,
                      NamespaceSelectionMode.pattern: l.namespacePattern,
                    },
                    (value) => update(() {
                      mode = value;
                      if (value == NamespaceSelectionMode.all) excluded = {};
                    }),
                    enabled: !working,
                  ),
                  if (mode == NamespaceSelectionMode.pattern)
                    ui.field(pattern, l.namespacePattern, enabled: !working),
                  for (final child in node.children.where(
                    (child) => child.localKind == null,
                  ))
                    ui.checkbox(
                      child.label,
                      mode == NamespaceSelectionMode.all &&
                              !excluded.contains(child.label) ||
                          mode == NamespaceSelectionMode.names &&
                              chosen.contains(child.label),
                      working || mode == NamespaceSelectionMode.pattern
                          ? null
                          : (checked) => update(() {
                              final pending = mode == NamespaceSelectionMode.all
                                  ? excluded
                                  : chosen;
                              final adding = mode == NamespaceSelectionMode.all
                                  ? !checked
                                  : checked;
                              if (adding &&
                                  !pending.contains(child.label) &&
                                  pending.length >= 128) {
                                error = l.limitReached;
                                return;
                              }
                              error = '';
                              if (mode == NamespaceSelectionMode.all) {
                                checked
                                    ? excluded.remove(child.label)
                                    : excluded.add(child.label);
                              } else {
                                checked
                                    ? chosen.add(child.label)
                                    : chosen.remove(child.label);
                              }
                            }),
                    ),
                  if (!node.complete) Text(l.partial),
                  if (node.continuation.isNotEmpty)
                    ui.textButton(
                      l.loadMore,
                      working
                          ? null
                          : () async {
                              update(() => working = true);
                              await load(node, append: true);
                              if (context.mounted) {
                                update(() {
                                  working = false;
                                  error = node.failed ? node.availability : '';
                                });
                              }
                            },
                    ),
                  if (node.previousPages.isNotEmpty)
                    ui.textButton(
                      l.previousPage,
                      working
                          ? null
                          : () async {
                              update(() => working = true);
                              await load(node, previousPage: true);
                              if (context.mounted) {
                                update(() {
                                  working = false;
                                  error = node.failed ? node.availability : '';
                                });
                              }
                            },
                    ),
                  if (error.isNotEmpty) Text(error),
                  if (node.failed)
                    ui.textButton(
                      l.retry,
                      working
                          ? null
                          : () async {
                              update(() => working = true);
                              await load(node);
                              if (context.mounted) {
                                update(() {
                                  working = false;
                                  error = node.failed ? node.availability : '';
                                });
                              }
                            },
                    ),
                ],
              ),
              [
                ui.button(
                  l.cancel,
                  working ? null : () => Navigator.of(context).pop(),
                ),
                ui.button(
                  l.defaultNamespace,
                  working
                      ? null
                      : () {
                          final session = model.sessions[sourceSession];
                          final wanted = node.defaultNamespace.isNotEmpty
                              ? node.defaultNamespace
                              : catalog.isEmpty
                              ? session?.currentCatalog
                              : node.children
                                        .where(
                                          (child) => ['true', '1'].contains(
                                            child
                                                .object
                                                ?.properties['defaultNamespace'],
                                          ),
                                        )
                                        .firstOrNull
                                        ?.label ??
                                    session?.currentSchema;
                          update(() {
                            mode = NamespaceSelectionMode.names;
                            chosen = wanted?.isNotEmpty == true
                                ? {wanted!}
                                : {};
                          });
                        },
                ),
                ui.button(
                  l.applyView,
                  working
                      ? null
                      : () async {
                          update(() {
                            working = true;
                            error = '';
                          });
                          try {
                            final selection = NamespaceSelection(
                              mode: mode,
                              names: mode == NamespaceSelectionMode.names
                                  ? chosen
                                  : [],
                              pattern: mode == NamespaceSelectionMode.pattern
                                  ? pattern.text
                                  : '',
                              excluded: mode == NamespaceSelectionMode.all
                                  ? excluded
                                  : [],
                            );
                            await selectedNames(selection, known);
                            if (!sourceCurrent()) {
                              throw StateError(l.metadataContextChanged);
                            }
                            // Validate pending explicit names in their real scope,
                            // including names selected on a previous discovery page.
                            for (final name
                                in selection.mode ==
                                        NamespaceSelectionMode.names
                                    ? selection.names
                                    : selection.excluded) {
                              final exact = await model.readMetadata(
                                sourceTarget,
                                rpc.ExploreRequest(
                                  independentMetadata: true,
                                  kind: node.kind == null
                                      ? rpc.ObjectKind.CATALOG
                                      : rpc.ObjectKind.SCHEMA,
                                  catalog: catalog,
                                  search: name,
                                  exactName: true,
                                ),
                                maxObjects: 1,
                                current: () =>
                                    sourceCurrent() && context.mounted,
                                onRequest: (request) => node.request = request,
                              );
                              if (selection.mode ==
                                      NamespaceSelectionMode.names &&
                                  exact.objects.isEmpty) {
                                throw StateError(l.objectNotFound);
                              }
                            }
                            if (!mounted ||
                                !context.mounted ||
                                model.explorerSessions[node.profileId] !=
                                    sourceSession) {
                              return;
                            }
                            var applied = false;
                            pendingApplied = true;
                            await load(
                              node,
                              refresh: true,
                              pendingSelection: selection,
                              mayAdopt: () =>
                                  sourceCurrent() && context.mounted,
                              onApplied: (_) => applied = true,
                            );
                            if (!sourceCurrent() || !context.mounted) return;
                            if (!applied || node.failed) {
                              throw StateError(node.availability);
                            }
                            if (selection.mode ==
                                NamespaceSelectionMode.names) {
                              if (node.missingNamespaces
                                  .intersection(selection.names)
                                  .isNotEmpty) {
                                throw StateError(l.objectNotFound);
                              }
                              if (!node.verifiedSelectedNamespaces.containsAll(
                                selection.names,
                              )) {
                                throw StateError(l.partialTreeLimit);
                              }
                            }
                            await model.selectNamespaces(
                              node.profileId,
                              catalog,
                              selection,
                              mayAdopt: () =>
                                  sourceCurrent() && context.mounted,
                            );
                            pendingApplied = false;
                            if (!mounted || !context.mounted) return;
                            setState(() {});
                            Navigator.of(context).pop();
                          } on FormatException {
                            if (context.mounted) {
                              update(() => error = l.patternRejected);
                            }
                          } on TimeoutException {
                            if (context.mounted) {
                              update(() => error = l.patternRejected);
                            }
                          } catch (failure) {
                            if (pendingApplied && sourceCurrent()) {
                              await load(node);
                              pendingApplied = false;
                            }
                            if (context.mounted) {
                              update(
                                () => error = failure is GrpcError
                                    ? ConnectionFailure.from(
                                        failure,
                                      ).localizedSummary(l)
                                    : operationFailureSummary(
                                        failure,
                                        locale: l,
                                      ),
                              );
                            }
                          } finally {
                            if (context.mounted) update(() => working = false);
                          }
                        },
                  primary: true,
                ),
              ],
              maxWidth: 500,
            );
          },
        ),
      );
    } finally {
      if (working) await node.request?.cancel();
      if (pendingApplied && sourceCurrent()) await load(node);
      pattern.dispose();
    }
  }

  String? namespaceBadge(ExplorerNode node) {
    if (node.selectedNamespaces == null || node.totalCount == null) return null;
    final selection = widget.model.namespaceSelection(
      node.profileId,
      node.kind == null ? '' : node.catalog,
    );
    final selected = selection?.mode == NamespaceSelectionMode.all
        ? node.totalCount! - node.verifiedExcludedNamespaces.length
        : selection?.mode == NamespaceSelectionMode.names
        ? node.verifiedSelectedNamespaces.length
        : node.selectedNamespaces!.length;
    return node.pageStart.isEmpty && node.complete ||
            selection?.mode == NamespaceSelectionMode.all &&
                node.checkedExcludedNamespaces.containsAll(
                  selection!.excluded,
                ) ||
            selection?.mode == NamespaceSelectionMode.names &&
                node.verifiedSelectedNamespaces.containsAll(selection!.names)
        ? strings(context).namespaceCount(selected, node.totalCount!)
        : '${strings(context).selected} $selected · ${strings(context).partial}';
  }

  DesktopMenuAction? commandAction(String id, ExplorerNode? node) {
    final command = widget.model.commands?.commands
        .where((c) => c.id == id)
        .firstOrNull;
    if (command == null) return null;
    final captured = node == null
        ? const WorkbenchCommandContext()
        : target(node);
    return DesktopMenuAction(
      command.label,
      () => invoke(id, node, captured: captured),
      shortcut: command.shortcutLabel,
      disabledReason:
          node == null &&
              !['connection.new', 'folder.new', 'file.new'].contains(id)
          ? strings(context).selectTarget
          : command.disabledReason?.call(captured),
    );
  }

  Future<void> viewOptions() async {
    final ui = widget.controls, model = widget.model, l = strings(context);
    var all = model.showAllNamespaces, empty = model.showEmptyGroups;
    final preferences = Map<String, bool>.of(model.explorerPreferences);
    final kinds = model.explorerObjectKinds.toSet();
    var nameFilter = showFilter;
    final accepted = await ui.formDialog<bool>(
      context,
      (_) => StatefulBuilder(
        builder: (context, update) => ui.formShell(
          l.viewOptions,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ui.checkbox(
                l.allNamespaces,
                all,
                (value) => update(() => all = value),
              ),
              ui.checkbox(
                l.showEmptyGroups,
                empty,
                (value) => update(() => empty = value),
              ),
              ui.checkbox(
                l.filterTree,
                nameFilter,
                (value) => update(() => nameFilter = value),
              ),
              for (final entry in {
                'namespaceGroups': l.groupNamespaces,
                'schemaGroups': l.groupSchemaObjects,
                'tableGroups': l.groupTableElements,
                'separateRoutines': l.separateProceduresFunctions,
                'alphabetic': l.sortAlphabetically,
                'virtual': l.showVirtualObjects,
                'comments': l.showObjectComments,
              }.entries)
                ui.checkbox(
                  entry.value,
                  preferences[entry.key]!,
                  (value) => update(() => preferences[entry.key] = value),
                ),
              Text(l.objectTypeFilter),
              for (final kind in rpc.ObjectKind.values.where(
                (kind) =>
                    kind != rpc.ObjectKind.CATALOG &&
                    kind != rpc.ObjectKind.SCHEMA &&
                    (kind != rpc.ObjectKind.TYPE ||
                        model.profiles.any(
                          (p) => p.engine == rpc.Engine.POSTGRESQL,
                        )) &&
                    (kind != rpc.ObjectKind.SEQUENCE ||
                        model.profiles.any(
                          (p) => p.engine != rpc.Engine.MYSQL,
                        )),
              ))
                ui.checkbox(
                  workbenchObjectType(context, kind),
                  kinds.contains(kind),
                  (value) => update(() {
                    value ? kinds.add(kind) : kinds.remove(kind);
                  }),
                ),
            ],
          ),
          [
            ui.button(l.cancel, () => Navigator.of(context).pop(false)),
            ui.button(
              l.applyView,
              () => Navigator.of(context).pop(true),
              primary: true,
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final previousAll = model.showAllNamespaces,
        previousEmpty = model.showEmptyGroups;
    final previousPreferences = Map<String, bool>.of(model.explorerPreferences),
        previousKinds = model.explorerObjectKinds.toSet();
    model.showAllNamespaces = all;
    model.showEmptyGroups = empty;
    model.explorerPreferences
      ..clear()
      ..addAll(preferences);
    model.explorerObjectKinds
      ..clear()
      ..addAll(kinds);
    try {
      await model.savePresentation();
      if (mounted) {
        setState(() {
          showFilter = nameFilter;
          if (!nameFilter) filter.clear();
        });
        if (previousPreferences['separateRoutines'] !=
            preferences['separateRoutines']) {
          for (final node in nodes.toList().where(
            // PostgreSQL owns groups under schemas; MySQL/MariaDB own
            // them directly under databases. Reload only actual group owners.
            (n) =>
                n.object != null &&
                [
                  rpc.ObjectKind.SCHEMA,
                  rpc.ObjectKind.CATALOG,
                ].contains(n.kind) &&
                n.children.any((child) => child.category),
          )) {
            cancelBranch(node, invalidate: true);
            if (node.expanded) await load(node);
          }
        }
        for (final node in nodes.toList().where(
          (n) =>
              n.localKind == null &&
              n.object == null &&
              n.category &&
              kinds.contains(n.kind),
        )) {
          final parent = nodes
              .where((p) => p.children.contains(node))
              .firstOrNull;
          final grouped = node.table.isEmpty
              ? preferences['schemaGroups']!
              : preferences['tableGroups']!;
          if (!grouped &&
              (node.table.isEmpty || node.kind == rpc.ObjectKind.COLUMN) &&
              parent?.expanded == true &&
              !node.loaded) {
            node.expanded = true;
            await load(node);
          }
        }
      }
    } catch (failure) {
      model.showAllNamespaces = previousAll;
      model.showEmptyGroups = previousEmpty;
      model.explorerPreferences
        ..clear()
        ..addAll(previousPreferences);
      model.explorerObjectKinds
        ..clear()
        ..addAll(previousKinds);
      model.updateStatus(operationFailureSummary(failure, locale: l));
    }
  }

  Widget toolbar() => LayoutBuilder(
    builder: (context, constraints) {
      final ui = widget.controls, l = strings(context);
      final node = visibleRows
          .map((row) => row.node)
          .where((n) => n.key == selected)
          .firstOrNull;
      final actions = <({DesktopIcon icon, DesktopMenuAction action})>[
        if (commandAction('connection.edit', node) case final action?)
          (icon: DesktopIcon.tool, action: action),
        (
          icon: DesktopIcon.refresh,
          action: DesktopMenuAction(
            l.refresh,
            () {
              if (node != null) refreshTree(node);
            },
            disabledReason: node == null || node.localKind != null
                ? l.selectTarget
                : null,
          ),
        ),
        if (commandAction('connection.deactivate', node) case final action?)
          (icon: DesktopIcon.close, action: action),
        if (commandAction('connection.consoles', node) case final action?)
          (icon: DesktopIcon.query, action: action),
        if (commandAction('object.data', node) case final action?)
          (icon: DesktopIcon.table, action: action),
        if (commandAction('object.ddl', node) case final action?)
          (icon: DesktopIcon.query, action: action),
        if (commandAction('object.compare', node) case final action?)
          (icon: DesktopIcon.tool, action: action),
        (
          icon: DesktopIcon.more,
          action: DesktopMenuAction(l.viewOptions, viewOptions),
        ),
      ];
      var newWidth = (constraints.maxWidth * .35).clamp(60.0, 120.0);
      final translatedWidth = labelWidth(l.newMenu) + 64;
      if (newWidth < translatedWidth) newWidth = translatedWidth;
      newWidth = newWidth.clamp(
        0.0,
        (constraints.maxWidth - 40).clamp(0.0, double.infinity),
      );
      final visible = ((constraints.maxWidth - newWidth - 40) / 40)
          .floor()
          .clamp(0, actions.length);
      return Row(
        children: [
          SizedBox(
            width: newWidth,
            child: ui.menu(l.newMenu, [
              ?commandAction('connection.new', null),
              ?commandAction('folder.new', node),
              if (node?.localKind != ExplorerLocalKind.folder &&
                  node?.localKind != ExplorerLocalKind.unboundGroup)
                ?commandAction('file.new', node),
              if (node?.schema.isNotEmpty == true) ...[
                ?commandAction('schema.designer', node),
                ?commandAction('virtual.new', node),
                ?commandAction('virtual.rebind', node),
              ],
            ]),
          ),
          for (final item in actions.take(visible))
            if (item.action.disabledReason == null)
              ui.iconButton(item.icon, item.action.label, item.action.invoke)
            else
              ui.tooltip(
                item.action.disabledReason!,
                ui.iconButton(item.icon, item.action.label, null),
              ),
          if (visible < actions.length)
            ui.iconMenu(l.more, [
              for (final item in actions.skip(visible)) item.action,
            ]),
        ],
      );
    },
  );

  bool namespaceSelected(ExplorerNode node) {
    if (node.localKind != null) return true;
    final parent = nodes.where((n) => n.children.contains(node)).firstOrNull;
    return parent?.selectedNamespaces == null ||
        parent!.selectedNamespaces!.contains(node.label);
  }

  bool visible(ExplorerNode node) =>
      filter.text.isEmpty ||
      node.label.toLowerCase().contains(filter.text.toLowerCase()) ||
      node.children.any(visible);
  Iterable<({ExplorerNode node, int depth})> rows(
    ExplorerNode node,
    int depth,
  ) sync* {
    if (!visible(node)) return;
    final model = widget.model;
    if (node.table.isNotEmpty &&
        node.kind != rpc.ObjectKind.COLUMN &&
        model.explorerPreferences['tableGroups'] == false) {
      return;
    }
    if (node.kind != null &&
        ![rpc.ObjectKind.CATALOG, rpc.ObjectKind.SCHEMA].contains(node.kind) &&
        !model.explorerObjectKinds.contains(node.kind)) {
      return;
    }
    final flattenGroup =
        node.category &&
        node.loaded &&
        node.complete &&
        node.pageStart.isEmpty &&
        model.explorerPreferences[node.table.isEmpty
                ? 'schemaGroups'
                : 'tableGroups'] ==
            false;
    final flattenNamespace =
        node.object != null &&
        [rpc.ObjectKind.CATALOG, rpc.ObjectKind.SCHEMA].contains(node.kind) &&
        node.expanded &&
        node.loaded &&
        node.complete &&
        namespaceSelected(node) &&
        model.explorerPreferences['namespaceGroups'] == false;
    final flattened = flattenGroup || flattenNamespace;
    if (!flattened) yield (node: node, depth: depth);
    if ((node.expanded || flattened) && namespaceSelected(node)) {
      final children = node.children.toList();
      if (model.explorerPreferences['alphabetic'] == true) {
        children.sort(
          (a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()),
        );
      }
      for (final child in children) {
        if (node.contextStale && child.localKind == null) continue;
        if (child.category &&
            child.totalCount == 0 &&
            !widget.model.showEmptyGroups) {
          continue;
        }
        if (child.localKind == null &&
            node.selectedNamespaces != null &&
            !widget.model.showAllNamespaces &&
            !node.selectedNamespaces!.contains(child.label)) {
          continue;
        }
        yield* rows(child, flattened ? depth : depth + 1);
      }
    }
  }

  List<DesktopMenuAction> menu(ExplorerNode node) {
    if (node.localKind != null) {
      final ids = switch (node.localKind!) {
        ExplorerLocalKind.folder => [
          'folder.new',
          'folder.rename',
          'source.move',
          'source.up',
          'source.down',
          'folder.remove',
        ],
        ExplorerLocalKind.virtualView => [
          'virtual.run',
          'virtual.open',
          'virtual.edit',
          'virtual.rename',
          'virtual.remove',
        ],
        ExplorerLocalKind.virtualGroup => [
          'virtual.new',
          'virtual.rebind',
          'file.new',
        ],
        ExplorerLocalKind.unboundGroup => <String>[],
      };
      return [for (final id in ids) ?commandAction(id, node)];
    }
    final source = node.kind == null;
    final namespace = [
      rpc.ObjectKind.CATALOG,
      rpc.ObjectKind.SCHEMA,
    ].contains(node.kind);
    final relation =
        node.object != null &&
        [rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW].contains(node.kind);
    final ids = [
      'file.new',
      'connection.consoles',
      if (source) ...[
        'connection.connect',
        'connection.deactivate',
        'connection.edit',
        'connection.duplicate',
        'connection.delete',
        'connection.favorite',
        'source.move',
        'source.up',
        'source.down',
        'connection.metadata',
        'connection.capabilities',
        'connection.activity',
        'connection.principals',
        'backup.dump',
        'backup.restore',
      ],
      if (relation) 'object.data',
      if (relation) 'object.compare',
      if (node.object != null && !namespace) ...[
        'object.structure',
        'object.ddl',
        'object.documentation',
        'object.copy',
      ],
      if (relation) ...['object.sql', 'schema.designer', 'transfer.import'],
      if (namespace || node.category) 'schema.designer',
      if (namespace && node.schema.isNotEmpty) ...[
        'schema.snapshot',
        'schema.compare',
        'schema.diagram',
      ],
      if (node.schema.isNotEmpty) ...['virtual.new', 'virtual.rebind'],
      'connection.search',
    ];
    return [
      for (final id in ids) ?commandAction(id, node),
      if (source ||
          node.kind == rpc.ObjectKind.CATALOG &&
              widget.model.profiles
                      .firstWhere((p) => p.id == node.profileId)
                      .engine ==
                  rpc.Engine.POSTGRESQL)
        DesktopMenuAction(
          strings(context).namespaceSelection,
          () => namespaceSelector(node),
        ),
      DesktopMenuAction(strings(context).refresh, () => refreshTree(node)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model, ui = widget.controls, l = strings(context);
    final sourceNames = connectionDisplayNames(
      context,
      model.profiles.map((p) => (p.id, p.name)),
    );
    for (final profile in model.profiles) {
      roots.putIfAbsent(
        profile.id,
        () => ExplorerNode(profile.id, profile.id, profile.name),
      );
      roots[profile.id]!.label = sourceNames[profile.id]!;
    }
    roots.removeWhere((id, root) {
      if (model.profiles.any((p) => p.id == id)) return false;
      void cancel(ExplorerNode node) {
        node.generation++;
        node.request?.cancel();
        for (final child in node.children) {
          cancel(child);
        }
      }

      cancel(root);
      return true;
    });
    final allRows = [for (final root in presentationRoots) ...rows(root, 0)];
    visibleRows = allRows;
    final flat = speedFilter && speed.text.isNotEmpty
        ? [
            for (var index = 0; index < allRows.length; index++)
              if (speedMatch(allRows[index].node) ||
                  allRows
                      .skip(index + 1)
                      .takeWhile((row) => row.depth > allRows[index].depth)
                      .any((row) => speedMatch(row.node)))
                allRows[index],
          ]
        : allRows;
    final selectedNode = flat
        .map((row) => row.node)
        .where((n) => n.key == selected)
        .firstOrNull;
    // A refresh can acknowledge a new metadata revision without moving focus.
    // Keyboard commands must capture that accepted owner just like the toolbar.
    model.explorerCommandContext = selectedNode == null
        ? null
        : target(selectedNode);
    return DefaultTextStyle(
      style: ui.textStyle(context),
      child: Focus(
        focusNode: model.explorerFocus,
        onKeyEvent: (_, event) => treeKey(event),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 6, 4),
              child: Semantics(
                container: true,
                header: true,
                child: Text(
                  l.database,
                  style: ui
                      .textStyle(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 4),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                identifier: 'busydata.database.toolbar',
                label: l.databaseExplorer,
                child: toolbar(),
              ),
            ),
            if (showFilter)
              Padding(
                padding: const EdgeInsets.all(8),
                child: ui.tooltip(
                  l.treeFilterScope,
                  ui.filterField(filter, l.filterTree),
                ),
              ),
            if (speedActive)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.speedSearchScope,
                      style: WorkbenchMetrics.secondary(context, ui),
                    ),
                    ui.field(
                      speed,
                      l.speedSearch,
                      readOnly: true,
                      focusNode: speedFocus,
                    ),
                    ui.checkbox(
                      l.filter,
                      speedFilter,
                      (value) => setState(() => speedFilter = value),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: flat.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            model.profiles.isEmpty
                                ? l.noConnections
                                : l.noFilterMatches,
                          ),
                          if (model.profiles.isEmpty)
                            ui.button(
                              l.newConnection,
                              () => invoke('connection.new', null),
                            ),
                        ],
                      ),
                    )
                  : Semantics(
                      identifier: 'busydata.database.tree',
                      label: l.database,
                      container: true,
                      explicitChildNodes: true,
                      child: ListView.builder(
                        controller: scroll,
                        itemCount: flat.length,
                        itemBuilder: (context, index) {
                          final node = flat[index].node,
                              depth = flat[index].depth;
                          final profile =
                              model.profiles
                                  .where((p) => p.id == node.profileId)
                                  .firstOrNull ??
                              rpc.Profile(
                                id: node.profileId,
                                name: l.unboundVirtualView,
                              );
                          final liveProfile = node.localKind != null
                              ? profile
                              : model
                                        .sessions[model.explorerSessions[profile
                                            .id]]
                                        ?.profile ??
                                    profile;
                          final environment = workbenchEnvironment(
                            context,
                            liveProfile.environment,
                          );
                          final endpoint = liveProfile.host.isEmpty
                              ? ''
                              : '${liveProfile.user.isEmpty ? '' : '${liveProfile.user}@'}${liveProfile.host}:${liveProfile.port}';
                          final clients = model.sessions.values
                              .where((s) => s.profile.id == profile.id)
                              .toList();
                          final uncertain = clients
                              .where(
                                (s) =>
                                    s.transaction ==
                                    rpc.TransactionState.UNKNOWN_TRANSACTION,
                              )
                              .toList();
                          final open = clients
                              .where(
                                (s) =>
                                    s.transaction ==
                                    rpc.TransactionState.ACTIVE,
                              )
                              .length;
                          final failed = clients
                              .where(
                                (s) =>
                                    s.transaction ==
                                    rpc.TransactionState.FAILED_TRANSACTION,
                              )
                              .length;
                          final badges = [
                            if (uncertain.isNotEmpty)
                              '${l.outcomeUnknown} ${uncertain.length}${uncertain.any((s) => s.profile.environment == rpc.Environment.PRODUCTION) ? ' · ${l.production}' : ''}',
                            if (open != 0) '${l.activeTransaction} $open',
                            if (failed != 0) '${l.failedTransaction} $failed',
                          ];
                          final metadataSession = model
                              .sessions[model.explorerSessions[profile.id]];
                          final connected =
                              metadataSession?.transaction ==
                                  rpc.TransactionState.UNKNOWN_TRANSACTION
                              ? l.outcomeUnknown
                              : metadataSession != null &&
                                    metadataSession.transaction !=
                                        rpc.TransactionState.DISCONNECTED
                              ? l.explorerConnected
                              : l.explorerDisconnected;
                          final queries = clients
                              .where(
                                (session) =>
                                    session.sessionId !=
                                        metadataSession?.sessionId &&
                                    session.transaction !=
                                        rpc.TransactionState.DISCONNECTED,
                              )
                              .length;
                          final rowContext =
                              node.localKind == ExplorerLocalKind.folder
                              ? '${l.sourceFolderName} · ${model.folderPath(node.localId)}'
                              : node.localKind ==
                                        ExplorerLocalKind.virtualView ||
                                    node.localKind ==
                                        ExplorerLocalKind.virtualGroup
                              ? '${l.virtualViews} · ${profile.name}${endpoint.isEmpty ? '' : ' · $endpoint'} / ${[node.catalog, if (node.schema != node.catalog || profile.engine == rpc.Engine.POSTGRESQL) node.schema].where((name) => name.isNotEmpty).join(' / ')}'
                              : node.localKind != null
                              ? node.label
                              : node.isSource
                              ? '${workbenchEngine(liveProfile.engine)} · $connected${endpoint.isEmpty ? '' : ' · $endpoint'} · $environment${queries == 0 ? '' : ' · ${l.querySessionCount('$queries')}'}${liveProfile.readOnly ? ' · ${l.readOnlyPolicy}' : ''}'
                              : '${profile.name}${endpoint.isEmpty ? '' : ' · $endpoint'} · $environment · ${[node.catalog, node.schema, node.table].where((name) => name.isNotEmpty).join(' / ')}${node.object == null ? '' : ' · ${workbenchObjectType(context, node.object!.kind, node.object!.subtype)}'}';
                          final expandable =
                              node.localKind != ExplorerLocalKind.virtualView &&
                              (node.object == null ||
                                  [
                                    rpc.ObjectKind.SCHEMA,
                                    rpc.ObjectKind.CATALOG,
                                    rpc.ObjectKind.TABLE,
                                    rpc.ObjectKind.VIEW,
                                  ].contains(node.kind));
                          final focus = rowFocus.putIfAbsent(
                            node.key,
                            () => FocusNode(debugLabel: node.label),
                          );
                          final row = Semantics(
                            identifier:
                                'busydata.database.item.${depth + 1}.${node.semanticsIdentity}',
                            button: true,
                            enabled: true,
                            focusable: true,
                            focused: focus.hasFocus,
                            onFocus: () {
                              focus.requestFocus();
                              setState(() => selectNode(node));
                            },
                            onTap: () {
                              activateNode(node);
                            },
                            selected:
                                selected == node.key ||
                                selectedObjects.contains(node.key),
                            expanded: expandable ? node.expanded : null,
                            container: true,
                            label:
                                '${node.label} · ${l.treeLevel} ${depth + 1} · $rowContext · ${node.loading ? l.loading : workbenchMetadataAvailability(context, node.availability)}${node.isSource && badges.isNotEmpty ? ' · ${badges.join(' · ')}' : ''}',
                            child: FocusableActionDetector(
                              focusNode: focus,
                              // The enclosing row owns focus, its tree role and
                              // stable identity for assistive technology. Keep
                              // the keyboard detector from also announcing an
                              // anonymous focused descendant of that row.
                              includeFocusSemantics: false,
                              onFocusChange: (focused) {
                                // A late acknowledgement must not select or
                                // scroll a superseded Speed Search match.
                                if (focused &&
                                    speedActive &&
                                    speed.text.isNotEmpty &&
                                    !speedMatch(node) &&
                                    selected != node.key) {
                                  final requested = visibleRows
                                      .where((row) => row.node.key == selected)
                                      .firstOrNull;
                                  if (requested != null) {
                                    focusRow(requested.node);
                                  }
                                  return;
                                }
                                if (mounted) {
                                  setState(() {
                                    if (focused) selectNode(node);
                                  });
                                }
                                // Keyboard navigation reveals from focusRow;
                                // pointer selection leaves the click target fixed.
                              },
                              shortcuts: {
                                const SingleActivator(LogicalKeyboardKey.enter):
                                    const ActivateIntent(),
                                const SingleActivator(LogicalKeyboardKey.space):
                                    const _TreeMove(3),
                                const SingleActivator(
                                  LogicalKeyboardKey.arrowUp,
                                ): const _TreeMove(
                                  -1,
                                ),
                                const SingleActivator(
                                  LogicalKeyboardKey.arrowDown,
                                ): const _TreeMove(
                                  1,
                                ),
                                const SingleActivator(
                                  LogicalKeyboardKey.arrowLeft,
                                ): _TreeMove(
                                  Directionality.of(context) ==
                                          TextDirection.rtl
                                      ? 2
                                      : -2,
                                ),
                                const SingleActivator(
                                  LogicalKeyboardKey.arrowRight,
                                ): _TreeMove(
                                  Directionality.of(context) ==
                                          TextDirection.rtl
                                      ? -2
                                      : 2,
                                ),
                              },
                              actions: {
                                _TreeMove: CallbackAction<_TreeMove>(
                                  onInvoke: (intent) {
                                    final current = flat.indexWhere(
                                      (row) => row.node.key == selected,
                                    );
                                    final position = current < 0
                                        ? index
                                        : current;
                                    if (intent.direction == 3 && expandable) {
                                      expand(node);
                                    } else if (intent.direction == 2) {
                                      if (expandable && !node.expanded) {
                                        expand(node);
                                      } else if (position + 1 < flat.length &&
                                          flat[position + 1].depth > depth) {
                                        focusRow(flat[position + 1].node);
                                      }
                                    } else if (intent.direction == -2) {
                                      if (node.expanded) {
                                        expand(node);
                                      } else {
                                        final parents = flat
                                            .take(position)
                                            .where((row) => row.depth < depth);
                                        if (parents.isNotEmpty) {
                                          focusRow(parents.last.node);
                                        }
                                      }
                                    } else if (intent.direction.abs() == 1) {
                                      final candidates =
                                          speedActive && speed.text.isNotEmpty
                                          ? flat
                                                .where(
                                                  (row) => speedMatch(row.node),
                                                )
                                                .toList()
                                          : flat;
                                      if (candidates.isEmpty) return null;
                                      final match = candidates.indexWhere(
                                        (row) => row.node.key == selected,
                                      );
                                      final next =
                                          speedActive && speed.text.isNotEmpty
                                          ? (match + intent.direction) %
                                                candidates.length
                                          : (position + intent.direction).clamp(
                                              0,
                                              candidates.length - 1,
                                            );
                                      focusRow(candidates[next].node);
                                    }
                                    return null;
                                  },
                                ),
                                ActivateIntent: CallbackAction<ActivateIntent>(
                                  onInvoke: (_) {
                                    activateNode(node);
                                    return null;
                                  },
                                ),
                              },
                              child: MouseRegion(
                                onEnter: (_) =>
                                    setState(() => hovered = node.key),
                                onExit: (_) => setState(() => hovered = null),
                                child: Listener(
                                  onPointerDown: (event) {
                                    rowFocus[node.key]?.requestFocus();
                                    setState(
                                      () => selectNode(
                                        node,
                                        additive: HardwareKeyboard
                                            .instance
                                            .isControlPressed,
                                      ),
                                    );
                                  },
                                  onPointerUp: (event) {
                                    rowFocus[node.key]?.requestFocus();
                                  },
                                  child: GestureDetector(
                                    child: WorkbenchRowSurface(
                                      controls: ui,
                                      selected:
                                          selected == node.key ||
                                          selectedObjects.contains(node.key),
                                      focused: focus.hasFocus,
                                      hovered: hovered == node.key,
                                      base: ui.appearance(context).sidebar,
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.only(
                                          start: 4 + depth * ui.treeIndent,
                                          end: 4,
                                          top: 1,
                                          bottom: 1,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            LayoutBuilder(
                                              builder: (context, rowConstraints) {
                                                final badge = namespaceBadge(
                                                  node,
                                                );
                                                final badgeWidth = badge == null
                                                    ? 0.0
                                                    : (labelWidth(badge) + 40)
                                                          .clamp(
                                                            76.0,
                                                            double.infinity,
                                                          );
                                                // Reserve the native expand/object icons, context affordance,
                                                // connection marker and enough title space. Larger text may
                                                // put the selector on its own line rather than eliding counts.
                                                final titleSpace =
                                                    MediaQuery.textScalerOf(
                                                      context,
                                                    ).scale(32);
                                                final inlineBadge =
                                                    badgeWidth +
                                                        46 +
                                                        32 +
                                                        (node.isSource
                                                            ? 16
                                                            : 0) +
                                                        titleSpace <=
                                                    rowConstraints.maxWidth;
                                                return Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        if (expandable)
                                                          Semantics(
                                                            container: true,
                                                            excludeSemantics:
                                                                true,
                                                            button: true,
                                                            enabled: true,
                                                            label:
                                                                '${node.expanded ? l.collapse : l.expand} ${node.label}',
                                                            onTap: () =>
                                                                expand(node),
                                                            child: ui.treeExpander(
                                                              node.expanded,
                                                              '${node.expanded ? l.collapse : l.expand} ${node.label}',
                                                              () =>
                                                                  expand(node),
                                                            ),
                                                          )
                                                        else
                                                          SizedBox(
                                                            width:
                                                                ui.treeControl,
                                                          ),
                                                        ExcludeSemantics(
                                                          child: ui.icon(
                                                            node.localKind !=
                                                                    null
                                                                ? node.localKind ==
                                                                          ExplorerLocalKind
                                                                              .virtualView
                                                                      ? DesktopIcon
                                                                            .query
                                                                      : DesktopIcon
                                                                            .folder
                                                                : node.kind ==
                                                                      null
                                                                ? DesktopIcon
                                                                      .connection
                                                                : node.category
                                                                ? DesktopIcon
                                                                      .folder
                                                                : switch (node
                                                                      .kind) {
                                                                    rpc
                                                                        .ObjectKind
                                                                        .TABLE =>
                                                                      DesktopIcon
                                                                          .table,
                                                                    rpc
                                                                        .ObjectKind
                                                                        .VIEW =>
                                                                      DesktopIcon
                                                                          .view,
                                                                    rpc
                                                                        .ObjectKind
                                                                        .ROUTINE =>
                                                                      DesktopIcon
                                                                          .routine,
                                                                    rpc
                                                                        .ObjectKind
                                                                        .COLUMN =>
                                                                      DesktopIcon
                                                                          .column,
                                                                    rpc
                                                                        .ObjectKind
                                                                        .SEQUENCE =>
                                                                      DesktopIcon
                                                                          .sequence,
                                                                    _ =>
                                                                      DesktopIcon
                                                                          .folder,
                                                                  },
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Expanded(
                                                          child: GestureDetector(
                                                            onDoubleTap: () =>
                                                                activateNode(
                                                                  node,
                                                                ),
                                                            child: ui.tooltip(
                                                              node.object ==
                                                                      null
                                                                  ? '${node.label}${endpoint.isEmpty ? '' : ' · $endpoint'}${node.isSource
                                                                        ? ' / ${metadataSession?.currentCatalog ?? liveProfile.database}'
                                                                        : node.catalog.isEmpty
                                                                        ? ''
                                                                        : ' / ${node.catalog} / ${node.schema}'}'
                                                                  : '${profile.name}${endpoint.isEmpty ? '' : ' · $endpoint'} / ${identity(node).displayPath(liveProfile.engine)}',
                                                              nodeText(
                                                                node,
                                                                model.explorerPreferences['comments'] ==
                                                                            true &&
                                                                        (node.object?.properties['remarks']?.isNotEmpty ??
                                                                            false)
                                                                    ? '${node.label} · ${node.object!.properties['remarks']}'
                                                                    : node.isSource
                                                                    ? [
                                                                        node.label,
                                                                        if (liveProfile.environment ==
                                                                            rpc.Environment.PRODUCTION)
                                                                          l.production,
                                                                        if (liveProfile
                                                                            .readOnly)
                                                                          l.readOnlyPolicy,
                                                                      ].join(
                                                                        ' · ',
                                                                      )
                                                                    : node.label,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        if (badge != null &&
                                                            inlineBadge)
                                                          namespaceControl(
                                                            node,
                                                            badge,
                                                            badgeWidth,
                                                          ),
                                                        if (node.failed)
                                                          ui.tooltip(
                                                            workbenchMetadataAvailability(
                                                              context,
                                                              node.availability,
                                                            ),
                                                            ui.icon(
                                                              DesktopIcon
                                                                  .warning,
                                                            ),
                                                          ),
                                                        if (node.category &&
                                                            node.totalCount !=
                                                                null)
                                                          Text(
                                                            '${node.totalCount}',
                                                          ),
                                                        if (node.isSource &&
                                                            model
                                                                .favoriteProfiles
                                                                .contains(
                                                                  profile.id,
                                                                ))
                                                          ui.icon(
                                                            DesktopIcon
                                                                .favorite,
                                                            size: 12,
                                                          ),
                                                        if (node.isSource)
                                                          ui.tooltip(
                                                            rowContext,
                                                            Semantics(
                                                              label: rowContext,
                                                              child: ui.icon(
                                                                metadataSession ==
                                                                            null ||
                                                                        metadataSession.transaction ==
                                                                            rpc.TransactionState.DISCONNECTED
                                                                    ? DesktopIcon
                                                                          .disconnected
                                                                    : DesktopIcon
                                                                          .connected,
                                                                size: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        Visibility(
                                                          visible:
                                                              hovered ==
                                                                  node.key ||
                                                              focus.hasFocus ||
                                                              model.explorerSelection ==
                                                                  node.key,
                                                          maintainSize: true,
                                                          maintainAnimation:
                                                              true,
                                                          maintainState: true,
                                                          child: SizedBox(
                                                            width: ui
                                                                .treeMenuWidth,
                                                            child: Center(
                                                              child: ui
                                                                  .iconMenu(
                                                                    l.more,
                                                                    menu(node),
                                                                    compact:
                                                                        true,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    if (badge != null &&
                                                        !inlineBadge)
                                                      Align(
                                                        alignment:
                                                            AlignmentDirectional
                                                                .centerEnd,
                                                        child: namespaceControl(
                                                          node,
                                                          badge,
                                                          badgeWidth.clamp(
                                                            0.0,
                                                            rowConstraints
                                                                .maxWidth,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            ),
                                            if (node.isSource) ...[
                                              if (badges.isNotEmpty)
                                                Wrap(
                                                  spacing: 4,
                                                  children: [
                                                    for (final badge in badges)
                                                      ui.textButton(
                                                        badge,
                                                        () => model.commands
                                                            ?.invoke(
                                                              'view.sessions',
                                                              model
                                                                  .commandContext,
                                                            ),
                                                      ),
                                                  ],
                                                ),
                                            ],
                                            if (node.expanded &&
                                                node.continuation.isNotEmpty)
                                              ui.button(
                                                strings(context).loadMore,
                                                node.loading
                                                    ? null
                                                    : () => load(
                                                        node,
                                                        append: true,
                                                      ),
                                              ),
                                            if (node.expanded &&
                                                node.previousPages.isNotEmpty)
                                              ui.textButton(
                                                l.previousPage,
                                                node.loading
                                                    ? null
                                                    : () => load(
                                                        node,
                                                        previousPage: true,
                                                      ),
                                              ),
                                            if (node.expanded && node.failed)
                                              ui.textButton(
                                                l.retry,
                                                () => load(node, refresh: true),
                                              ),
                                            if (node.expanded &&
                                                node.lookup.isNotEmpty)
                                              ui.textButton(
                                                l.clearObjectFilter,
                                                () async {
                                                  node.lookup = '';
                                                  node.lookupIdentifier = '';
                                                  cancelBranch(
                                                    node,
                                                    invalidate: true,
                                                  );
                                                  await load(node);
                                                },
                                              ),
                                            if (node.loading ||
                                                (node.expanded &&
                                                    (node.children.isEmpty ||
                                                        node
                                                                .availability
                                                                .isNotEmpty &&
                                                            node.availability !=
                                                                'available')))
                                              Text(
                                                node.availability.isEmpty ||
                                                        node.availability ==
                                                            'available'
                                                    ? l.empty
                                                    : workbenchMetadataAvailability(
                                                        context,
                                                        node.availability,
                                                      ),
                                                style:
                                                    WorkbenchMetrics.secondary(
                                                      context,
                                                      ui,
                                                    ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                          return ui.contextMenu(row, menu(node));
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
