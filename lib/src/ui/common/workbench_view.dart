import 'sql_editor_view.dart';
import '../../features/workspace/editor/sql_editor.dart';
import '../../backend/tool_admission_requests.dart';
import 'workbench_editor_menu.dart';
import 'presentation_diagnostics.dart';
import 'presentation_inputs.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show listEquals, mapEquals;
import 'package:flutter/material.dart' show SelectableText;
import 'package:re_editor/re_editor.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;
import '../../features/workspace/documents.dart';
import '../../features/workspace/connection_credentials.dart';
import '../../backend/connection_failure.dart';
import 'connection_form.dart';
import '../../platform/common/packaged_database_tools.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import '../../features/workspace/browse_target_selection.dart';
import '../../backend/workbench_failure.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'sql_presentation.dart';
import 'workspace_divider.dart';
import 'workspace_content_layout.dart';
import 'result_grid.dart';
import '../../features/results/value_assignments.dart';
import 'plan_view.dart';
import 'schema_tools_view.dart';
import 'privileges_view.dart';
import 'snippet_view.dart';
import 'editor_shortcuts.dart';
import 'workbench_shortcut_scope.dart';
import 'workbench_completion.dart';
import 'sql_diagnostics.dart';
import 'workbench_editor_scroll.dart';
import 'workbench_document_view.dart';
import 'workbench_tabs.dart';
import 'document_presentation.dart';
import 'structure_presentation.dart';
import 'workbench_search.dart';
import 'workbench_search_session.dart';
import 'workbench_sql_search.dart';
import 'history_view.dart';
import 'database_explorer.dart';
import 'metadata_settings_dialog.dart';
import 'workbench_settings.dart';
import 'modal_command_boundary.dart';
import 'transfer_document.dart';
import '../../l10n/workbench_strings.dart';

part 'workbench_actions.dart';

class WorkbenchView extends StatefulWidget {
  const WorkbenchView({super.key, required this.model, required this.controls});
  final WorkbenchModel model;
  final DesktopControls controls;
  @override
  State<WorkbenchView> createState() => _WorkbenchViewState();
}

class _WorkbenchViewState extends State<WorkbenchView> with WorkbenchActions {
  FocusScopeNode get editorFocus => model.documentFocus;
  FocusScopeNode get targetFocus => model.targetFocus;
  FocusScopeNode get outputFocus => model.outputFocus;
  FocusScopeNode get toolFocus => model.globalToolFocus;

  final _retained = <String, ({Object signature, Widget widget})>{};
  WorkbenchCommandRegistry? _commands;
  Object? _commandPresentation;
  Map<String, String>? _commandShortcuts;
  final _commandMenus =
      <
        String,
        ({
          Object target,
          WorkbenchDocument? owner,
          List<(WorkbenchCommand, String?)> entries,
          Widget widget,
        })
      >{};

  Widget _commandMenu(
    String key,
    String label,
    Iterable<WorkbenchCommand> commands,
    WorkbenchCommandContext target,
  ) {
    final signature = (
      ui,
      model.backend,
      target.owner,
      target.ownerRevision,
      target.object,
      target.profileId,
      target.sessionId,
      target.resultId,
      target.jobId,
      target.metadataInstance,
      target.metadataObject?.stableIdentity,
      target.metadataObject?.metadataSnapshotRevision,
      target.metadataConfigurationRevision,
      target.metadataSources[target.profileId],
      label,
    );
    // Evaluate current requirements on every update. Reuse only the native
    // presentation; invocation still passes through the live registry and its
    // captured-owner checks. These fixed menu slots retain one snapshot each.
    final entries = [
      for (final command in commands)
        (command, command.disabledReason?.call(target)),
    ];
    final previous = _commandMenus[key];
    if (previous?.target == signature &&
        listEquals(previous?.entries, entries)) {
      return previous!.widget;
    }
    final widget = ui.menu(label, [
      for (final (command, reason) in entries)
        DesktopMenuAction(
          command.label,
          () => invoke(command.id, target: target),
          shortcut: command.shortcutLabel,
          disabledReason: reason,
        ),
    ]);
    _commandMenus[key] = (
      target: signature,
      owner: target.owner,
      entries: entries,
      widget: widget,
    );
    return widget;
  }

  Widget _retain(String key, Object signature, Widget Function() create) {
    final previous = _retained[key];
    if (previous?.signature == signature) {
      PresentationDiagnostics.count('$key-retention-hit');
      return previous!.widget;
    }
    PresentationDiagnostics.count('$key-retention-miss');
    final widget = create();
    _retained[key] = (signature: signature, widget: widget);
    return widget;
  }

  @override
  void initState() {
    super.initState();
    model.addListener(searchContextChanged);
  }

  @override
  void didUpdateWidget(WorkbenchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, model)) {
      oldWidget.model.removeListener(searchContextChanged);
      model.addListener(searchContextChanged);
      closeActionSearch(restoreFocus: false);
    }
  }

  @override
  Widget build(BuildContext context) => Focus.withExternalFocusNode(
    focusNode: sharedSearch.closeFocus,
    includeSemantics: false,
    child: _buildWorkbench(context),
  );

  Widget _buildWorkbench(BuildContext context) => LayoutBuilder(
    builder: (context, viewport) => ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        PresentationDiagnostics.count('workbench-model-build');
        final l = strings(context);
        final commandPresentation = (model, ui, l.localeName);
        if (_commandPresentation != commandPresentation ||
            !mapEquals(_commandShortcuts, model.shortcuts)) {
          _commands = buildRegistry();
          _commandMenus.clear();
          _commandPresentation = commandPresentation;
          _commandShortcuts = Map.of(model.shortcuts);
        }
        model.commands = _commands;
        if (!model.isSqlActive) _retained.clear();
        final target = model.commandContext, owner = model.activeOwner;
        _commandMenus.removeWhere((_, menu) => menu.owner != owner);
        if (!model.isSqlActive) {
          _commandMenus.remove('run');
          _commandMenus.remove('session');
        }
        final style = ui.textStyle(context);
        final look = ui.appearance(context);
        final categories = [
          l.fileMenu,
          l.editMenu,
          l.viewMenu,
          l.connectionMenu,
          l.objectMenu,
          l.runMenu,
        ];
        List<DesktopMenuAction> categoryActions(String category) => [
          for (final command in model.commands!.visibleCommands(target))
            if (command.category == category &&
                !const {
                  'preferences',
                  'view.start',
                  'view.workbench',
                }.contains(command.id))
              menuAction(command, target),
        ];
        final menus = ui.hasWindowHeader
            ? [
                DesktopMenu('', [
                  DesktopMenuAction(
                    settingsVisible
                        ? (model.showStartSurface
                              ? l.startTitle
                              : l.databaseWorkbench)
                        : model.showStartSurface
                        ? l.databaseWorkbench
                        : l.startTitle,
                    () {
                      if (settingsVisible) {
                        closeSettings();
                      } else if (model.showStartSurface) {
                        model.showWorkbench();
                      } else {
                        model.showWelcome();
                      }
                    },
                  ),
                  if (!settingsVisible)
                    menuAction(model.commands!.command('preferences'), target),
                ]),
                if (!settingsVisible) ...[
                  DesktopMenu(l.documentsMenu, categoryActions(l.fileMenu)),
                  DesktopMenu(
                    l.sqlExecution,
                    const [],
                    children: [
                      DesktopMenu(l.editMenu, categoryActions(l.editMenu)),
                      DesktopMenu(l.runMenu, categoryActions(l.runMenu)),
                    ],
                  ),
                  DesktopMenu(
                    l.database,
                    const [],
                    children: [
                      DesktopMenu(
                        l.connectionMenu,
                        categoryActions(l.connectionMenu),
                      ),
                      DesktopMenu(l.objectMenu, categoryActions(l.objectMenu)),
                    ],
                  ),
                  DesktopMenu(l.viewMenu, categoryActions(l.viewMenu)),
                ],
              ]
            : [
                for (final category in categories)
                  DesktopMenu(category, [
                    for (final command
                        in model.commands!
                            .visibleCommands(target)
                            .where((c) => c.category == category))
                      menuAction(command, target),
                  ]),
              ];

        final workbench = ColoredBox(
          color: look.view,
          child: DefaultTextStyle(
            style: style,
            child: WorkbenchShortcutScope(
              model: model,
              child: FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!ui.hasWindowHeader)
                      WorkbenchStrip(
                        controls: ui,
                        minimumHeight: 32,
                        key: const ValueKey('application-menu-bar'),
                        child: ui.menuBar(menus),
                      ),
                    if (!model.showStartSurface)
                      Row(
                        key: const ValueKey('workbench-document-tabs'),
                        children: [
                          Expanded(
                            child: WorkbenchTabs(
                              model: model,
                              controls: ui,
                              close: (owner) => closeTab(owner: owner),
                            ),
                          ),
                          ui.iconButton(
                            DesktopIcon.add,
                            l.newSql,
                            () => invoke('file.new'),
                            compact: true,
                          ),
                        ],
                      ),
                    if (!model.showStartSurface && model.isSqlActive)
                      _targetRow(context, owner),
                    if (!model.showStartSurface &&
                        !model.isSqlActive &&
                        owner.kind != WorkbenchDocumentKind.comparison &&
                        (owner.object != null ||
                            owner.retained != null ||
                            owner.referenceSchema.isNotEmpty))
                      _objectTarget(context, owner),
                    Expanded(
                      key: const ValueKey('workbench-working-content'),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Offstage(
                            offstage: model.showStartSurface,
                            child: ExcludeFocus(
                              excluding: model.showStartSurface,
                              child: model.isSqlActive
                                  ? _sqlBody(context)
                                  : _taskBody(context, owner),
                            ),
                          ),
                          if (model.showStartSurface) _startSurface(context),
                        ],
                      ),
                    ),
                    if (!model.showStartSurface ||
                        model.backend == null ||
                        model.jobs.values.any(
                          (job) => WorkbenchModel.problemJob(job.state),
                        ) ||
                        model.editDrafts.isNotEmpty)
                      _statusBar(context),
                  ],
                ),
              ),
            ),
          ),
        );
        final settingsSidebarAvailable =
            ui.hasWindowHeader &&
            viewport.maxWidth >= ui.settingsSidebarBreakpoint;
        final content = Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: settingsVisible,
              child: ExcludeFocus(excluding: settingsVisible, child: workbench),
            ),
            if (settingsVisible)
              WorkbenchSettings(
                key: settingsKey,
                model: model,
                controls: ui,
                categoryController: settingsCategory,
                usesWindowSidebar: ui.hasWindowHeader,
                windowSidebarVisible: settingsSidebarAvailable,
                close: closeSettings,
                confirmRecovery: () => confirm(
                  l.disableSqlRecovery,
                  l.disableRecoveryReview,
                  destructive: true,
                ),
              ),
          ],
        );
        return WorkbenchLocalInputBoundary(
          enabled: settingsVisible,
          child: ValueListenableBuilder<String>(
            valueListenable: settingsCategory,
            child: content,
            builder: (context, category, content) => ui.applicationFrame(
              body: content!,
              sidebar: IndexedStack(
                index: settingsVisible ? 1 : 0,
                children: [
                  ExcludeFocus(
                    excluding: settingsVisible,
                    child: _retain('database-explorer', (
                      model,
                      ui,
                    ), () => DatabaseExplorer(model: model, controls: ui)),
                  ),
                  if (settingsVisible)
                    WorkbenchSettingsNavigation(
                      controls: ui,
                      category: settingsCategory,
                    )
                  else
                    const SizedBox.shrink(),
                ],
              ),
              sidebarAvailable: !settingsVisible || settingsSidebarAvailable,
              sidebarVisible: settingsVisible
                  ? settingsSidebarAvailable
                  : model.explorerVisible,
              sidebarResizable: !settingsVisible,
              showSearch: !settingsVisible,
              sidebarGeneration: model.explorerTransitionGeneration,
              sidebarWidth: settingsVisible
                  ? ui.defaultSidebarWidth
                  : model.explorerWidth,
              resizeSidebar: model.resizeExplorer,
              toggleSidebar: () =>
                  model.setExplorerVisible(!model.explorerVisible),
              title: settingsVisible
                  ? workbenchSettingsCategories(context)[category]!
                  : model.showStartSurface
                  ? 'BusyData'
                  : documentName(context, model, owner),
              menus: menus,
              search: palette,
              prepareSearch: prepareActionSearch,
              searchShortcut: model.commands!
                  .command('view.palette')
                  .shortcutLabel,
              sidebarShortcut: model.commands!
                  .command('view.explorer')
                  .shortcutLabel,
              back: !ui.hasWindowHeader
                  ? null
                  : settingsVisible
                  ? closeSettings
                  : model.showStartSurface
                  ? null
                  : model.showWelcome,
              contextualControls:
                  settingsVisible ||
                      model.showStartSurface ||
                      owner.kind != WorkbenchDocumentKind.table
                  ? null
                  : ui.headerModeSwitcher(owner.view.subview, {
                      for (final entry in {
                        'data': l.data,
                        'structure': l.structure,
                      }.entries)
                        entry.key: DesktopMenuAction(
                          entry.value,
                          () => invoke(
                            entry.key == 'data'
                                ? 'object.data'
                                : 'object.structure',
                            target: target,
                          ),
                          shortcut: model.commands!
                              .command(
                                entry.key == 'data'
                                    ? 'object.data'
                                    : 'object.structure',
                              )
                              .shortcutLabel,
                          disabledReason: model.commands!
                              .command(
                                entry.key == 'data'
                                    ? 'object.data'
                                    : 'object.structure',
                              )
                              .disabledReason
                              ?.call(target),
                          icon: entry.key == 'data'
                              ? DesktopIcon.table
                              : DesktopIcon.folder,
                        ),
                    }, l.viewMenu),
              searchField: sharedSearch.target == null
                  ? null
                  : SearchHeaderField(
                      controls: ui,
                      hint: switch (sharedSearch.category) {
                        'sql' => l.searchCurrentSqlHint,
                        'objects' => l.searchObjectsHint,
                        'history' => l.searchHistoryHint,
                        _ => l.searchActionsHint,
                      },
                      query: sharedSearch.query,
                      focusNode: sharedSearch.focus,
                      close: closeActionSearch,
                      move: moveSearch,
                      submit: submitSearch,
                    ),
              searchSidebar: sharedSearch.target == null
                  ? null
                  : SearchSidebar(
                      controls: ui,
                      close: closeActionSearch,
                      move: moveSearch,
                      submit: submitSearch,
                      category: sharedSearch.category,
                      categories: {
                        if (sharedSearch.target!.owner?.sql != null &&
                            model.documents.contains(
                              sharedSearch.target!.owner!.sql,
                            ))
                          'sql': l.currentSql,
                        if (objectSearchAvailable) 'objects': l.searchObjects,
                        if (model.backend != null &&
                            identical(sharedSearch.backend, model.backend))
                          'history': l.history,
                        'actions': l.actionsCategory,
                      },
                      selectCategory: (value) => openSharedSearch(value),
                      child: sharedSearch.error.isNotEmpty
                          ? ui.status(sharedSearch.error, error: true)
                          : switch (sharedSearch.category) {
                              'sql'
                                  when sharedSearch.target!.owner?.sql !=
                                      null =>
                                WorkbenchSqlSearch(
                                  key: sqlSearchKey,
                                  model: model,
                                  document: sharedSearch.target!.owner!.sql!,
                                  controls: ui,
                                  query: sharedSearch.query,
                                  queryFocus: sharedSearch.focus,
                                  replacing: sharedSearch.replacing,
                                ),
                              'objects'
                                  when identical(
                                        sharedSearch.backend,
                                        model.backend,
                                      ) &&
                                      searchInspectionOwner?.payload
                                          is ObjectSearchData =>
                                DatabaseObjectSearch(
                                  key: objectSearchKey,
                                  model: model,
                                  controls: ui,
                                  owner: searchInspectionOwner!,
                                  target:
                                      searchInspectionOwner!.payload
                                          as ObjectSearchData,
                                  externalQuery: sharedSearch.query,
                                ),
                              'history'
                                  when model.backend != null &&
                                      identical(
                                        sharedSearch.backend,
                                        model.backend,
                                      ) =>
                                HistoryView(
                                  key: historySearchKey,
                                  model: model,
                                  controls: ui,
                                  inspection: searchHistory!.history,
                                  externalQuery: sharedSearch.query,
                                  admitEvidence: (units) =>
                                      model.reserveDocumentEvidence(
                                        searchHistoryOwner!,
                                        units,
                                      ),
                                  inspect: () {
                                    final owner = searchHistoryOwner!;
                                    closeActionSearch();
                                    if (model.operationOwners.contains(owner)) {
                                      model.activateOwner(owner.id);
                                    }
                                  },
                                ),
                              'sql' || 'objects' || 'history' => ui.status(
                                l.metadataContextChanged,
                                error: true,
                              ),
                              _ => SearchResultList(
                                key: searchResultsKey,
                                registry: model.commands!,
                                target: sharedSearch.target!,
                                controls: ui,
                                query: sharedSearch.query,
                                queryFocus: sharedSearch.focus,
                                contextChanges: model,
                                disabledReason: searchCommandDisabledReason,
                                close: closeActionSearch,
                                select: activateSearchCommand,
                              ),
                            },
                    ),
            ),
          ),
        );
      },
    ),
  );

  Widget _taskBody(BuildContext context, WorkbenchDocument owner) => Column(
    children: [
      Expanded(
        flex: 3,
        child: FocusScope(
          node: editorFocus,
          child: WorkbenchDocumentView(
            key: ValueKey(owner.id),
            model: model,
            owner: owner,
            controls: ui,
          ),
        ),
      ),
      if (model.globalToolOwner case final tool?)
        Expanded(
          flex: 2,
          child: Column(
            children: [
              _toolHeader(context, tool),
              Expanded(
                child: FocusScope(
                  node: toolFocus,
                  child: WorkbenchDocumentView(
                    model: model,
                    owner: tool,
                    controls: ui,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _toolHeader(BuildContext context, WorkbenchDocument tool) =>
      WorkbenchStrip(
        controls: ui,
        minimumHeight: 34,
        child: Row(
          children: [
            Expanded(
              child: Text(
                tool.displayTitle,
                style: ui
                    .textStyle(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ui.iconButton(
              DesktopIcon.close,
              '${strings(context).close} ${tool.displayTitle}',
              () => model.showGlobalTool(null),
            ),
          ],
        ),
      );

  Widget _startSurface(BuildContext context) {
    final l = strings(context);
    return FocusScope(
      child: Focus(
        autofocus: true,
        child: KeyedSubtree(
          key: const ValueKey('workbench-start-surface'),
          child: ui.contentClamp(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ui.groupedList(
                  title: l.createSection,
                  children: [
                    ui.actionRow(
                      title: l.newConnection,
                      subtitle: l.newConnectionDescription,
                      leading: ui.icon(DesktopIcon.connection),
                      trailing: ui.icon(DesktopIcon.expand),
                      onPressed: () => invoke('connection.new'),
                    ),
                    ui.actionRow(
                      title: l.newSql,
                      subtitle: l.newQueryDescription,
                      leading: ui.icon(DesktopIcon.query),
                      onPressed: () => invoke('file.new'),
                    ),
                  ],
                ),
                ui.groupedList(
                  title: l.open,
                  children: [
                    ui.actionRow(
                      title: l.openSqlFile,
                      subtitle: l.openSqlDescription,
                      leading: ui.icon(DesktopIcon.folder),
                      trailing: ui.icon(DesktopIcon.expand),
                      onPressed: () => invoke('file.open'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _targetRow(BuildContext context, WorkbenchDocument owner) {
    final l = strings(context), session = model.session;
    final target = model.commandContext;
    final profile =
        session?.profile ??
        owner.evidenceProfile ??
        model.profiles.where((p) => p.id == owner.profileId).firstOrNull;
    final spokenState =
        '${session == null && profile != null ? strings(context).connectsWhenRun : workbenchSessionState(context, session)}${session == null ? '' : ' · ${session.currentCatalog}/${session.currentSchema}'}';
    final environment = profile == null
        ? ''
        : workbenchEnvironment(context, profile.environment);
    final policy = profile?.readOnly == true ? ' · ${l.readOnlyPolicy}' : '';
    final details =
        '${profile?.name ?? l.noConnection} · ${profile?.host ?? ''}:${profile?.port ?? ''} · $environment · $spokenState$policy${session == null ? '' : ' · ${session.sessionId}'}';
    final critical =
        session?.transaction == rpc.TransactionState.UNKNOWN_TRANSACTION ||
        profile?.environment == rpc.Environment.PRODUCTION;
    final runCommand = model.commands!.command('sql.run');
    final runCommands = model.commands!.commands
        .where((c) => c.category == l.runMenu)
        .toList(growable: false);
    final sessionMenu = _commandMenu(
      'session',
      l.sessionMenu,
      model.commands!.commands.where(
        (c) =>
            c.id.startsWith('session.') ||
            [
              'connection.connect',
              'connection.disconnect',
              'connection.details',
              'connection.share',
            ].contains(c.id),
      ),
      target,
    );
    // Progress counters do not change these controls. Reevaluate requirements
    // on every update, and retain only when all captured owners and displayed
    // values still match. Mutable protobuf inputs are copied for comparison.
    return _retain(
      'sql-target-controls',
      PresentationInputs([
        ui,
        model.backend,
        model.commands,
        owner,
        target.ownerRevision,
        target.profileId,
        target.sessionId,
        target.resultId,
        target.jobId,
        target.object,
        session?.deepCopy(),
        profile?.deepCopy(),
        l.localeName,
        model.activeCommandPending,
        sessionMenu,
        runCommand.disabledReason?.call(target),
        model.commands!
            .command('connection.new-query')
            .disabledReason
            ?.call(target),
        for (final command in runCommands)
          (command, command.disabledReason?.call(target)),
        for (final profile in model.profiles) profile.deepCopy(),
      ]),
      () => FocusScope(
        node: targetFocus,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final compact =
                bounds.maxWidth /
                    math.max(1.0, WorkbenchMetrics.line(context, ui) / 20) <
                660;
            final liveState = ui.tooltip(
              details,
              Semantics(
                key: const ValueKey('live-workbench-target'),
                container: true,
                liveRegion: true,
                label: details,
                excludeSemantics: true,
                child: Text(
                  [
                    if (session != null)
                      [
                        session.currentCatalog,
                        session.currentSchema,
                      ].where((s) => s.isNotEmpty).join(' / '),
                    if (!compact || critical) environment,
                    if (!compact || critical)
                      session == null && profile != null
                          ? strings(context).connectsWhenRun
                          : workbenchSessionState(context, session),
                    if (profile?.readOnly == true) l.readOnlyPolicy,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: critical && compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: WorkbenchMetrics.secondary(context, ui),
                ),
              ),
            );
            return WorkbenchStrip(
              controls: ui,
              minimumHeight: 42,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              flex: 2,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: math.min(
                                    260,
                                    bounds.maxWidth * .32,
                                  ),
                                ),
                                child: ui
                                    .menu(profile?.name ?? l.noConnection, [
                                      for (final p in model.profiles)
                                        DesktopMenuAction(p.name, () async {
                                          if (owner.sessionId == null) {
                                            model.bindUnconnectedProfile(
                                              owner,
                                              p.id,
                                            );
                                            model.updateStatus(
                                              strings(context).connectsWhenRun,
                                            );
                                          } else {
                                            await connectContext(
                                              WorkbenchCommandContext(
                                                owner: owner,
                                                profileId: p.id,
                                                sessionId: owner.sessionId,
                                              ),
                                            );
                                          }
                                        }),
                                      menuAction(
                                        model.commands!.command(
                                          'connection.new-query',
                                        ),
                                        target,
                                      ),
                                      if (profile != null)
                                        menuAction(
                                          model.commands!.command(
                                            'connection.connect',
                                          ),
                                          target,
                                        ),
                                    ]),
                              ),
                            ),
                            if (!compact)
                              Expanded(
                                flex: 3,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    start: 8,
                                  ),
                                  child: liveState,
                                ),
                              )
                            else
                              const Spacer(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (target.jobId != null)
                        ui.button(
                          l.cancel,
                          () => invoke('job.cancel', target: target),
                          primary: true,
                        )
                      else
                        ui.splitButton(
                          l.run,
                          model.backend == null ||
                                  runCommand.disabledReason?.call(target) !=
                                      null ||
                                  model.activeCommandPending ||
                                  session?.transaction ==
                                      rpc.TransactionState.UNKNOWN_TRANSACTION
                              ? null
                              : () => invoke('sql.run', target: target),
                          l.runMenu,
                          [
                            for (final command in runCommands)
                              menuAction(command, target),
                          ],
                        ),
                      sessionMenu,
                    ],
                  ),
                  if (compact)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 10,
                        bottom: 3,
                      ),
                      child: liveState,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _objectTarget(BuildContext context, WorkbenchDocument owner) {
    final l = strings(context), target = model.commandContext;
    final session = model.sessions[target.sessionId];
    final result = model.resultForOwner(owner);
    final original =
        owner.retained?.target ??
        (owner.view.subview == 'data' && result != null
            ? model.retainedResults[result.resultId]?.target
            : null);
    final profile =
        original ??
        session?.profile ??
        owner.evidenceProfile ??
        model.profiles.where((p) => p.id == owner.profileId).firstOrNull;
    final identity =
        '${profile?.name ?? l.noConnection} / ${owner.object?.displayPath(profile?.engine) ?? owner.referenceSchema}';
    final structure =
        owner.object != null &&
        owner.purpose != 'design' &&
        owner.payload == null &&
        owner.view.subview != 'data';
    final representation = structure
        ? l.structure
        : owner.view.subview == 'data'
        ? l.data
        : '';
    final environment = profile == null
        ? ''
        : workbenchEnvironment(context, profile.environment);
    final state =
        '${workbenchSessionState(context, session)}${profile?.readOnly == true ? ' · ${l.readOnlyPolicy}' : ''}';
    final identityControl = ui.tooltip(
      '$identity · $environment · $state${session == null ? '' : ' · ${session.sessionId}'}',
      Text(
        '${representation.isEmpty ? '' : '$representation · '}$identity',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final stateControl = Wrap(
      spacing: 8,
      runSpacing: 2,
      children: [
        if (environment.isNotEmpty) Text(environment),
        Text(state, style: WorkbenchMetrics.secondary(context, ui)),
      ],
    );
    final actions = <Widget>[
      if (structure)
        SizedBox(
          width: math.min(
            240,
            ui.choiceWidth(
                  context,
                  structureSections(context, owner)[structureSection(
                    context,
                    owner,
                  )]!,
                ) +
                40,
          ),
          child: StructureControls(model: model, owner: owner, controls: ui),
        ),
      if (owner.object != null)
        ui.iconButton(
          DesktopIcon.sidebar,
          l.revealInExplorer,
          () => invoke('object.reveal', target: target),
          compact: true,
        ),
      if (owner.view.subview == 'data' &&
          result == null &&
          owner.kind == WorkbenchDocumentKind.table)
        ui.iconButton(
          DesktopIcon.refresh,
          l.refresh,
          () => invoke('object.refresh', target: target),
          compact: true,
        ),
      if (!ui.hasWindowHeader && owner.kind == WorkbenchDocumentKind.table)
        SizedBox(
          width: 130,
          child: ui.modeSwitcher(
            owner.view.subview,
            {'data': l.data, 'structure': l.structure},
            (value) => invoke(
              value == 'data' ? 'object.data' : 'object.structure',
              target: target,
            ),
            label: l.viewMenu,
          ),
        ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: ui.menu(l.sessionMenu, [
          for (final command in model.commands!.commands.where(
            (c) =>
                c.id.startsWith('session.') ||
                [
                  'connection.connect',
                  'connection.disconnect',
                  'connection.details',
                ].contains(c.id),
          ))
            menuAction(command, target),
        ]),
      ),
      if (target.jobId != null)
        ui.button(l.cancel, () => invoke('job.cancel', target: target)),
    ];
    return FocusScope(
      node: targetFocus,
      child: WorkbenchStrip(
        controls: ui,
        minimumHeight: 42,
        child: LayoutBuilder(
          builder: (context, bounds) {
            final compact =
                bounds.maxWidth /
                    math.max(1, WorkbenchMetrics.line(context, ui) / 20) <
                860;
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identityControl,
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        stateControl,
                        for (final action in actions)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(start: 8),
                            child: action,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(flex: 3, child: identityControl),
                const SizedBox(width: 12),
                Flexible(flex: 2, child: stateControl),
                const SizedBox(width: 12),
                ...actions,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sqlBody(BuildContext context) {
    final output = model.currentJob != null || model.globalToolOwner != null;
    final children = <Widget>[
      Expanded(
        key: const ValueKey('sql-editor-pane'),
        flex: output ? (model.editorFraction * 1000).round() : 1,
        child: FocusScope(node: editorFocus, child: _editor(context)),
      ),
      if (model.analysis?.diagnostics.isNotEmpty == true)
        ui.textButton(
          strings(
            context,
          ).sqlDiagnosticCount(model.analysis!.diagnostics.length),
          () => invoke('editor.inspections', target: model.commandContext),
        ),
      if (output) WorkspaceDivider(model: model, controls: ui),
      if (output)
        Expanded(
          key: const ValueKey('sql-output-pane'),
          flex: ((1 - model.editorFraction) * 1000).round(),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (model.currentJob != null)
                Offstage(
                  offstage: model.globalToolOwner != null,
                  child: ExcludeFocus(
                    excluding: model.globalToolOwner != null,
                    child: FocusScope(
                      node: outputFocus,
                      child: _output(context),
                    ),
                  ),
                ),
              if (model.globalToolOwner case final tool?)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _toolHeader(context, tool),
                    Expanded(
                      child: FocusScope(
                        node: toolFocus,
                        child: WorkbenchDocumentView(
                          model: model,
                          owner: tool,
                          controls: ui,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
    ];
    final scaledLine = MediaQuery.textScalerOf(
      context,
    ).scale(ui.textStyle(context).fontSize ?? 14);
    return WorkspaceContentLayout(
      minimumEditorExtent: scaledLine + 20,
      minimumResultExtent: output
          ? math.max(
              model.activeOwner.view.output == 'plan' ? 220 : 180,
              math.max(scaledLine, WorkbenchMetrics.line(context, ui)) * 4 +
                  130,
            )
          : 0,
      children: children,
    );
  }

  Widget _editor(BuildContext context) {
    final document = model.document, owner = model.activeOwner;
    return _retain(
      'editor',
      (
        ui,
        document.id,
        documentName(context, model, model.activeOwner),
        strings(context).localeName,
        sqlPresentationSignature(context, ui),
        MediaQuery.textScalerOf(context),
        Object.hashAll(
          model.shortcuts.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      ),
      () => WorkbenchEditorScroll(
        key: ValueKey(document.id),
        view: owner.view,
        presentation: (
          sqlPresentationSignature(context, ui),
          MediaQuery.textScalerOf(context),
        ),
        builder: (scroll) => WorkbenchCompletion(
          scrollController: scroll,
          model: model,
          document: document,
          controls: ui,
          child: WorkbenchEditorMenu(
            scrollController: scroll,
            controls: ui,
            controller: document.editor,
            shortcuts: WorkbenchEditorShortcuts([
              for (final key in model.shortcuts.keys) shortcut(key),
            ]),
            readOnly: false,
            builder: (toolbar, menuFocus, shortcuts) => WorkbenchSqlEditor(
              semanticLabel: strings(
                context,
              ).sqlEditorLabel(documentName(context, model, model.activeOwner)),
              controls: ui,
              shortcutsActivatorsBuilder: shortcuts,
              toolbarController: toolbar,
              focusNode: menuFocus,
              key: ValueKey(document.id),
              controller: document.editor,
              scrollController: scroll,

              commentFormatter: DefaultCodeCommentFormatter(
                singleLinePrefix: "--",
                multiLinePrefix: "/*",
                multiLineSuffix: "*/",
              ),
              autofocus: true,
              style: sqlEditorStyle(context, ui),
              indicatorBuilder: (context, editing, chunks, notifier) =>
                  sqlEditorIndicators(context, ui, editing, chunks, notifier),
            ),
          ),
        ),
      ),
    );
  }

  Widget _output(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _outputBody(context, constraints),
  );

  Widget _outputBody(BuildContext context, BoxConstraints constraints) {
    final l = strings(context),
        job = model.currentJob!,
        result = model.displayResult;
    final owner = model.activeOwner;
    final outputTarget = model.commandContext;
    final history = model.documentJobs;
    final retained = result == null
        ? null
        : model.retainedResults[model.sourceResultId(result.resultId)];
    final original = retained?.target ?? (job.hasTarget() ? job.target : null);
    final lineMetrics = TextPainter(
      text: TextSpan(text: l.results, style: ui.textStyle(context)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final compact = constraints.maxHeight < lineMetrics.height * 4 + 120;
    lineMetrics.dispose();
    final resultSets = job.results.where(
      (r) =>
          r.resultId.isNotEmpty && !model.disposedResults.contains(r.resultId),
    );
    void showOutput(String page, [rpc.StatementResult? selected]) {
      if (!model.workbenchDocuments.contains(owner)) return;
      if (selected != null &&
          model.disposedResults.contains(selected.resultId)) {
        return;
      }
      if (selected != null) model.selectedResults[owner.id] = selected.resultId;
      owner.view.output = page;
      model.updateStatus(page == 'messages' ? l.messages : l.results);
    }

    final contextActions = <DesktopMenuAction>[
      for (var i = 0; i < history.length; i++)
        DesktopMenuAction(
          '${history.length - i} · ${jobState(context, history[i].state)} · ${history[i].durationMs} ms',
          () => model.selectExecution(history[i].executionId, owner: owner),
        ),
      for (final command in model.commands!.commands.where(
        (c) =>
            [l.results, l.changes].contains(c.category) ||
            c.id == 'result.plan',
      ))
        menuAction(command, outputTarget),
    ];
    final originalLabel = original == null
        ? ''
        : '${original.name} · ${workbenchEnvironment(context, original.environment)} · ${original.host}:${original.port}/${original.database}/${retained?.sourceSchema ?? job.sourceSchema}';
    final outputLabel = owner.view.output == 'messages' || result == null
        ? l.messages
        : owner.view.output == 'plan'
        ? l.plan
        : '${l.results} ${result.statementIndex + 1}';
    final representations = <String, String>{
      for (final r in resultSets)
        'result:${r.resultId}': '${l.results} ${r.statementIndex + 1}',
      'messages': l.messages,
      if (result?.plan == true) 'plan': l.plan,
    };
    final representation = owner.view.output == 'messages' || result == null
        ? 'messages'
        : owner.view.output == 'plan'
        ? 'plan'
        : 'result:${result.resultId}';
    void selectRepresentation(String value) {
      if (value == 'messages') {
        showOutput('messages');
      } else if (value == 'plan') {
        invoke('result.plan', target: outputTarget);
      } else {
        final selected = resultSets.where(
          (r) => 'result:${r.resultId}' == value,
        );
        if (selected.isNotEmpty) showOutput('results', selected.first);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ui.hasWindowHeader)
          WorkbenchStrip(
            controls: ui,
            child: Row(
              children: [
                Flexible(
                  child: KeyedSubtree(
                    key: const ValueKey('execution-output-selector'),
                    child: ui.modeSwitcher(
                      representations.containsKey(representation)
                          ? representation
                          : representations.keys.first,
                      representations,
                      selectRepresentation,
                      label: l.results,
                    ),
                  ),
                ),
                if (original != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ui.tooltip(
                      originalLabel,
                      Text(
                        compact
                            ? '${workbenchEnvironment(context, original.environment)} · ${original.name}'
                            : originalLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ] else
                  const Spacer(),
                ui.iconMenu(l.executionOptions, contextActions, compact: true),
              ],
            ),
          ),
        if (!ui.hasWindowHeader && compact)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 8,
              vertical: MediaQuery.textScalerOf(context).scale(14) > 21 ? 0 : 4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: ui.tooltip(
                    originalLabel.isEmpty ? outputLabel : originalLabel,
                    Text(
                      original == null
                          ? outputLabel
                          : '$outputLabel · ${workbenchEnvironment(context, original.environment)} · ${original.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ui.iconMenu(l.executionOptions, [
                  for (final r in resultSets)
                    DesktopMenuAction(
                      '${l.results} ${r.statementIndex + 1}',
                      () => showOutput('results', r),
                    ),
                  DesktopMenuAction(l.messages, () => showOutput('messages')),
                  if (result?.plan == true)
                    DesktopMenuAction(
                      l.plan,
                      () => invoke('result.plan', target: outputTarget),
                    ),
                  ...contextActions,
                ]),
              ],
            ),
          ),
        if (!ui.hasWindowHeader && !compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final r in resultSets)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 4),
                            child: WorkbenchSection(
                              controls: ui,
                              label: '${l.results} ${r.statementIndex + 1}',
                              onPressed: () => showOutput('results', r),
                              selected:
                                  owner.view.output == 'results' &&
                                  model.sourceResultId(r.resultId) ==
                                      model.sourceResultId(
                                        result?.resultId ?? '',
                                      ),
                            ),
                          ),
                        WorkbenchSection(
                          controls: ui,
                          label: l.messages,
                          selected: owner.view.output == 'messages',
                          onPressed: () => showOutput('messages'),
                        ),
                        if (result?.plan == true)
                          WorkbenchSection(
                            controls: ui,
                            label: l.plan,
                            selected: owner.view.output == 'plan',
                            onPressed: () =>
                                invoke('result.plan', target: outputTarget),
                          ),
                      ],
                    ),
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * .45,
                  ),
                  child: ui.menu(l.executionOptions, contextActions),
                ),
              ],
            ),
          ),
        if (!ui.hasWindowHeader && !compact && original != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              originalLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Expanded(
          key: const ValueKey('execution-output-content'),
          child: owner.view.output == 'messages' || result == null
              ? SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SelectableText(
                      '${jobState(context, job.state)} · ${job.durationMs} ms\n${job.state == rpc.JobState.UNKNOWN_OUTCOME ? '${l.outcomeUnknownNote}\n' : ''}${job.results.where((r) => r.resultId.isEmpty).map((r) => l.affectedRowCount('${r.updateCount}')).join('\n')}\n${job.errorCode}\n${job.messages.join('\n')}',
                    ),
                  ),
                )
              : owner.view.output == 'plan' &&
                    owner
                            .view
                            .results[model.sourceResultId(result.resultId)]
                            ?.planEvidence
                        is PlanData
              ? PlanEvidenceView(
                  model: model,
                  controls: ui,
                  data:
                      owner
                              .view
                              .results[model.sourceResultId(result.resultId)]!
                              .planEvidence!
                          as PlanData,
                  retained: model
                      .retainedResults[model.sourceResultId(result.resultId)],
                )
              : ResultGrid(
                  key: ValueKey(result.resultId),
                  model: model,
                  controls: ui,
                  result: result,
                ),
        ),
      ],
    );
  }

  String jobState(BuildContext context, rpc.JobState state) => switch (state) {
    rpc.JobState.QUEUED => strings(context).queued,
    rpc.JobState.EXECUTING || rpc.JobState.FETCHING => strings(context).running,
    rpc.JobState.CANCELLING => strings(context).cancelRequested,
    rpc.JobState.COMPLETED => strings(context).completed,
    rpc.JobState.CANCELLED => strings(context).cancelled,
    rpc.JobState.UNKNOWN_OUTCOME => strings(context).outcomeUnknown,
    _ => strings(context).failed,
  };
  Widget _statusBar(BuildContext context) {
    final l = strings(context);
    final latest = model
        .jobsForOwner(model.activeOwner)
        .where(
          (job) =>
              job.executionId == model.latestExecutions[model.activeOwner.id],
        )
        .firstOrNull;
    final operation = model.cancellableJobForOwner(model.activeOwner) ?? latest;
    final documentStatus =
        model.status == 'Execution submitted' ||
        model.status == l.transferSubmittedNotice ||
        model.workbenchDocuments.any(
          (owner) => owner.displayTitle == model.status,
        );
    final status = documentStatus
        ? operation == null
              ? l.idle
              : '${workbenchJobState(context, operation.state)}${WorkbenchModel.terminalJob(operation.state) ? ' · ${operation.durationMs} ms' : ''}'
        : model.status.startsWith('Connected ')
        ? (model.sessions[model.activeOwner.sessionId] == null
              ? model.activeOwner.profileId == null
                    ? l.noConnection
                    : strings(context).connectsWhenRun
              : workbenchSessionState(
                  context,
                  model.sessions[model.activeOwner.sessionId],
                ))
        : model.status;
    final active = model.jobs.values
        .where((j) => !WorkbenchModel.terminalJob(j.state))
        .length;
    final unresolved = model.sessions.values
        .where(
          (s) => [
            rpc.TransactionState.ACTIVE,
            rpc.TransactionState.FAILED_TRANSACTION,
            rpc.TransactionState.UNKNOWN_TRANSACTION,
          ].contains(s.transaction),
        )
        .length;
    final uncertain = model.sessions.values
        .where(
          (session) =>
              session.transaction == rpc.TransactionState.UNKNOWN_TRANSACTION,
        )
        .length;
    final problems = model.jobs.values
        .where((job) => WorkbenchModel.problemJob(job.state))
        .length;
    final session = model.session;
    final profile =
        session?.profile ??
        model.profiles
            .where((p) => p.id == model.activeOwner.profileId)
            .firstOrNull;
    final identity = [
      profile?.name,
      session?.currentCatalog,
      session?.currentSchema,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' / ');
    return WorkbenchStrip(
      controls: ui,
      minimumHeight: 28,
      topBorder: true,
      child: DefaultTextStyle(
        style: WorkbenchMetrics.secondary(context, ui),
        child: LayoutBuilder(
          builder: (context, bounds) {
            final compact =
                bounds.maxWidth /
                    math.max(1.0, WorkbenchMetrics.line(context, ui) / 14) <
                700;
            return Row(
              children: [
                Expanded(
                  child: ui.tooltip(
                    model.status,
                    Text(
                      status,
                      key: const ValueKey('workbench-operation-status'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                ui.iconButton(
                  DesktopIcon.more,
                  l.details,
                  () => ui.dialog<void>(
                    context,
                    l.details,
                    SelectableText(model.status),
                    [ui.button(l.close, () => Navigator.of(context).pop())],
                  ),
                  compact: true,
                ),
                if (!compact && identity.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: bounds.maxWidth * .4),
                    child: ui.tooltip(
                      identity,
                      Text(
                        identity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                if (!compact && session != null)
                  ui.textButton(
                    workbenchSessionState(context, session),
                    () => invoke('view.sessions'),
                    compact: true,
                  ),
                if (unresolved > 0)
                  Flexible(
                    child: ui.textButton(
                      uncertain > 0
                          ? '${l.outcomeUnknown} $uncertain'
                          : '${l.unresolvedSessions} $unresolved',
                      () => invoke('view.sessions'),
                      compact: true,
                    ),
                  ),
                ui.menu('${l.jobs} $active', [
                  DesktopMenuAction(
                    '${l.jobs} $active',
                    () => invoke('view.jobs'),
                  ),
                  DesktopMenuAction(
                    '${l.problems} $problems',
                    () => invoke('view.problems'),
                  ),
                  DesktopMenuAction(
                    '${l.ownedSessions} ${model.sessions.length}',
                    () => invoke('view.sessions'),
                  ),
                  if (model.backend == null)
                    DesktopMenuAction(
                      l.restartBackend,
                      () => invoke('backend.restart'),
                    ),
                ], compact: true),
                if (!compact && problems > 0)
                  ui.textButton(
                    '${l.problems} $problems',
                    () => invoke('view.problems'),
                    compact: true,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
