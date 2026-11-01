part of 'workbench_view.dart';

enum ConnectionManagementInvocation {
  createSource,
  createQueryTarget,
  reconnect,
}

mixin WorkbenchActions on State<WorkbenchView> {
  final sharedSearch = WorkbenchSearchSession();
  final searchResultsKey = GlobalKey<SearchResultListState>();
  var sqlSearchKey = GlobalKey<WorkbenchSqlSearchState>();
  var objectSearchKey = GlobalKey<DatabaseObjectSearchState>();
  var historySearchKey = GlobalKey<HistoryViewState>();
  WorkbenchDocument? searchInspectionOwner, searchHistoryOwner;
  GlobalToolData? searchHistory;
  WorkbenchCommandContext? pendingActionTarget;
  CapturedWorkbenchTarget? pendingMetadataTarget, pendingExecutionTarget;
  FocusNode? pendingActionFocus;
  bool settingsVisible = false;
  final settingsCategory = ValueNotifier<String>('appearance');
  final settingsKey = GlobalKey<WorkbenchSettingsState>();
  FocusNode? settingsReturnFocus;

  WorkbenchModel get model => widget.model;
  DesktopControls get ui => widget.controls;
  void showEditorSearch({
    bool replacing = false,
    WorkbenchCommandContext? target,
  }) => openSharedSearch(
    'sql',
    target: target ?? model.focusedCommandContext,
    replacing: replacing,
    rebind: true,
  );
  void moveSearch(int delta) {
    switch (sharedSearch.category) {
      case 'sql':
        sqlSearchKey.currentState?.move(delta);
      case 'objects':
        objectSearchKey.currentState?.move(delta);
      case 'history':
        historySearchKey.currentState?.move(delta);
      default:
        searchResultsKey.currentState?.move(delta);
    }
  }

  void submitSearch() {
    switch (sharedSearch.category) {
      case 'sql':
        sqlSearchKey.currentState?.activateSelection();
      case 'objects':
        objectSearchKey.currentState?.activateSelection();
      case 'history':
        historySearchKey.currentState?.activateSelection();
      default:
        searchResultsKey.currentState?.activateSelection();
    }
  }

  @override
  void dispose() {
    model.removeListener(searchContextChanged);
    settingsCategory.dispose();
    sharedSearch.dispose();
    super.dispose();
  }

  bool get objectSearchAvailable {
    final target = sharedSearch.objectsTarget;
    if (target == null) return false;
    try {
      model.requireTarget(target);
      return true;
    } catch (_) {
      return false;
    }
  }

  void searchContextChanged() {
    if (sharedSearch.target == null) return;
    final invalid = switch (sharedSearch.category) {
      'sql' => !model.documents.contains(sharedSearch.target!.owner?.sql),
      'objects' => !objectSearchAvailable,
      'history' => !identical(sharedSearch.backend, model.backend),
      _ => false,
    };
    if (invalid) closeActionSearch();
  }

  String? searchCommandDisabledReason(WorkbenchCommand command) {
    if (const {
      'connection.new',
      'preferences',
      'view.start',
      'view.workbench',
    }.contains(command.id)) {
      return null;
    }
    final target = sharedSearch.executionTarget;
    if (target == null) return null;
    try {
      model.requireTarget(target, text: true);
      return null;
    } catch (error) {
      return operationFailureSummary(error, locale: strings(context));
    }
  }

  Future<bool> confirm(
    String title,
    String body, {
    String? actionLabel,
    bool destructive = false,
  }) async =>
      await ui.dialog<bool>(context, title, SelectableText(body), [
        ui.button(
          strings(context).cancel,
          () => Navigator.of(context).pop(false),
        ),
        ui.button(
          actionLabel ?? title,
          () => Navigator.of(context).pop(true),
          primary: !destructive,
          destructive: destructive,
        ),
      ]) ??
      false;

  Future<void> editSourceFolder(
    WorkbenchCommandContext c, {
    bool rename = false,
  }) async {
    final l = strings(context), existing = model.sourceFolders[c.folderId];
    if (rename && existing == null) throw StateError(l.selectTarget);
    final name = TextEditingController(text: rename ? existing!.name : '');
    var error = '', working = false;
    try {
      await ui.dialog<void>(
        context,
        rename ? l.renameSourceFolder : l.newSourceFolder,
        StatefulBuilder(
          builder: (context, update) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ui.field(name, l.sourceFolderName, enabled: !working),
              if (!rename) Text(l.sourceFolderPathNotice),
              if (error.isNotEmpty) Text(error),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ui.button(
                  l.saveProfile,
                  working
                      ? null
                      : () async {
                          update(() {
                            working = true;
                            error = '';
                          });
                          try {
                            if (rename) {
                              if (!identical(
                                model.sourceFolders[existing!.id],
                                existing,
                              )) {
                                throw StateError(l.staleContext);
                              }
                              await model.saveSourceFolder(
                                existing.id,
                                name.text,
                                existing.parentId,
                              );
                            } else {
                              await model.createSourceFolderPath(
                                name.text,
                                c.folderId ?? '',
                              );
                            }
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (failure) {
                            if (context.mounted) {
                              update(() {
                                error = operationFailureSummary(
                                  failure,
                                  locale: l,
                                );
                                working = false;
                              });
                            }
                          }
                        },
                  primary: true,
                ),
              ),
            ],
          ),
        ),
        [ui.button(l.cancel, () => Navigator.of(context).pop())],
      );
    } finally {
      name.dispose();
    }
  }

  Future<void> moveToFolder(WorkbenchCommandContext c) async {
    final l = strings(context), folder = model.sourceFolders[c.folderId];
    var working = false, error = '';
    await ui.dialog<void>(
      context,
      l.moveToFolder,
      StatefulBuilder(
        builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error.isNotEmpty) Text(error),
            ui.textButton(
              l.newSourceFolder,
              working
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await editSourceFolder(c);
                      if (mounted) await moveToFolder(c);
                    },
            ),
            for (final id in ['', ...model.sourceFolders.keys])
              if (folder == null || model.folderCanMove(folder.id, id))
                ui.textButton(
                  id.isEmpty ? l.topLevel : model.folderPath(id),
                  working
                      ? null
                      : () async {
                          update(() {
                            working = true;
                            error = '';
                          });
                          try {
                            if (folder == null) {
                              await model.moveSourceToFolder(c.profileId!, id);
                            } else {
                              if (!identical(
                                model.sourceFolders[folder.id],
                                folder,
                              )) {
                                throw StateError(l.staleContext);
                              }
                              await model.saveSourceFolder(
                                folder.id,
                                folder.name,
                                id,
                              );
                            }
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (failure) {
                            if (context.mounted) {
                              update(() {
                                error = operationFailureSummary(
                                  failure,
                                  locale: l,
                                );
                                working = false;
                              });
                            }
                          }
                        },
                ),
          ],
        ),
      ),
      [ui.button(l.cancel, () => Navigator.of(context).pop())],
    );
  }

  Future<void> editVirtualView(
    WorkbenchCommandContext c, {
    bool rename = false,
  }) async {
    final l = strings(context), existing = model.virtualViews[c.virtualViewId];
    final scope = existing?.scope ?? c.creationScope!;
    final name = TextEditingController(text: existing?.name ?? '');
    final sql = SqlEditorController.fromText(existing?.sql ?? '');
    final profile = model.profiles
        .where((p) => p.id == scope.profileId)
        .firstOrNull;
    var error = '', working = false;
    try {
      await ui.dialog<void>(
        context,
        rename
            ? l.renameVirtualView
            : existing == null
            ? l.newVirtualView
            : l.editVirtualDefinition,
        StatefulBuilder(
          builder: (context, update) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${profile?.name ?? l.unboundVirtualView} / ${scope.catalog} / ${scope.schema}',
              ),
              Text(l.localVirtualViewNotice),
              ui.field(name, l.virtualViewName, enabled: !working),
              if (!rename)
                SizedBox(
                  height: 240,
                  child: WorkbenchEditorScroll(
                    presentation: (
                      sqlPresentationSignature(context, ui),
                      MediaQuery.textScalerOf(context),
                    ),
                    builder: (scroll) => WorkbenchEditorMenu(
                      scrollController: scroll,
                      controls: ui,
                      controller: sql,
                      readOnly: working,
                      builder: (toolbar, menuFocus, shortcuts) =>
                          WorkbenchSqlEditor(
                            semanticLabel: l.virtualViewSql,
                            controls: ui,
                            shortcutsActivatorsBuilder: shortcuts,
                            toolbarController: toolbar,
                            focusNode: menuFocus,
                            controller: sql,
                            scrollController: scroll,
                            readOnly: working,
                            style: sqlEditorStyle(context, ui),
                            indicatorBuilder:
                                (context, editing, chunks, notifier) =>
                                    sqlEditorIndicators(
                                      context,
                                      ui,
                                      editing,
                                      chunks,
                                      notifier,
                                    ),
                          ),
                    ),
                  ),
                ),
              if (error.isNotEmpty) Text(error),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ui.button(
                  l.saveProfile,
                  working || profile == null
                      ? null
                      : () async {
                          update(() {
                            working = true;
                            error = '';
                          });
                          try {
                            if (existing != null &&
                                !identical(
                                  model.virtualViews[existing.id],
                                  existing,
                                )) {
                              throw StateError(l.staleContext);
                            }
                            await model.saveVirtualView(
                              VirtualViewDefinition(
                                id: existing?.id ?? const Uuid().v4(),
                                name: name.text.trim(),
                                scope: scope,
                                sql: sql.text,
                              ),
                            );
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (failure) {
                            if (context.mounted) {
                              update(() {
                                error = operationFailureSummary(
                                  failure,
                                  locale: l,
                                );
                                working = false;
                              });
                            }
                          }
                        },
                  primary: true,
                ),
              ),
            ],
          ),
        ),
        [ui.button(l.cancel, () => Navigator.of(context).pop())],
      );
    } finally {
      name.dispose();
      sql.dispose();
    }
  }

  Future<void> rebindVirtualView(WorkbenchCommandContext c) async {
    final l = strings(context), scope = c.creationScope!;
    var error = '', working = false;
    await ui.dialog<void>(
      context,
      l.rebindVirtualView,
      StatefulBuilder(
        builder: (context, update) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${scope.catalog} / ${scope.schema}'),
            if (error.isNotEmpty) Text(error),
            for (final view in model.virtualViews.values.where(
              (v) => !model.profiles.any((p) => p.id == v.scope.profileId),
            ))
              ui.textButton(
                '${view.name} · ${view.scope.catalog} / ${view.scope.schema}',
                working
                    ? null
                    : () async {
                        update(() {
                          working = true;
                          error = '';
                        });
                        try {
                          model.commands!.validateContext?.call(c);
                          if (!identical(model.virtualViews[view.id], view) ||
                              !model.profiles.any(
                                (p) => p.id == scope.profileId,
                              )) {
                            throw StateError(l.staleContext);
                          }
                          await model.saveVirtualView(
                            VirtualViewDefinition(
                              id: view.id,
                              name: view.name,
                              scope: scope,
                              sql: view.sql,
                            ),
                          );
                          if (context.mounted) Navigator.of(context).pop();
                        } catch (failure) {
                          if (context.mounted) {
                            update(() {
                              error = operationFailureSummary(
                                failure,
                                locale: l,
                              );
                              working = false;
                            });
                          }
                        }
                      },
              ),
          ],
        ),
      ),
      [ui.button(l.cancel, () => Navigator.of(context).pop())],
    );
  }

  Future<ResolvedWorkbenchObject?> sqlSymbolTarget(
    WorkbenchCommandContext c,
  ) async {
    final l = strings(context), owner = c.owner;
    if (owner?.sql == null || owner!.sessionId == null) {
      throw StateError(l.requireSession);
    }
    final captured = model.captureTarget(owner: owner),
        profile = model.sessions[owner.sessionId]?.profile;
    if (profile == null ||
        owner.profileId != profile.id ||
        !model.profiles.any((p) => p.id == profile.id)) {
      throw StateError(l.selectTarget);
    }
    final result = await model.analyze(owner.sql!, resolveSymbol: true);
    model.requireTarget(captured, text: true);
    if (result == null || !result.hasSymbol()) {
      throw StateError(l.sqlSymbolUnavailable);
    }
    final symbol = result.symbol;
    if (symbol.availability == 'ambiguous') {
      throw StateError(l.sqlSymbolAmbiguous);
    }
    if (symbol.candidates.isEmpty) throw StateError(l.sqlSymbolUnavailable);
    if (symbol.profileId != profile.id ||
        symbol.candidates.length > 32 ||
        symbol.writeToBuffer().length > 65536 ||
        !symbol.hasSpan() ||
        symbol.span.startUtf16 >= symbol.span.endUtf16 ||
        result.caretUtf16 < symbol.span.startUtf16 ||
        result.caretUtf16 > symbol.span.endUtf16 ||
        symbol.span.endUtf16 > owner.sql!.editor.text.length ||
        symbol.candidates.any(
          (o) =>
              ![
                rpc.ObjectKind.TABLE,
                rpc.ObjectKind.VIEW,
                rpc.ObjectKind.SEQUENCE,
              ].contains(o.kind) ||
              o.name.isEmpty ||
              o.catalog != symbol.catalog ||
              o.schema != symbol.schema ||
              profile.engine == rpc.Engine.POSTGRESQL &&
                  o.catalog != captured.session?.currentCatalog,
        )) {
      throw StateError(l.sqlSymbolUnavailable);
    }
    DatabaseObjectIdentity identity(rpc.SchemaObject object) =>
        DatabaseObjectIdentity(
          profileId: profile.id,
          catalog: object.catalog,
          schema: object.schema,
          kind: object.kind,
          subtype: object.subtype,
          name: object.name,
          identifier: object.identifier,
        );
    ResolvedWorkbenchObject selected(rpc.SchemaObject object) =>
        ResolvedWorkbenchObject(
          identity(object),
          [rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW].contains(object.kind)
              ? BrowseSelectionEvidence(
                  source: captured,
                  projection: object,
                  configurationRevision: result.metadataConfigurationRevision
                      .toInt(),
                )
              : null,
        );
    if (symbol.candidates.any(
      (object) =>
          object.metadataSnapshotRevision != result.metadataSnapshotRevision,
    )) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
    }
    // Construct every bounded projection before opening a native selector.
    // Invalid metadata must fail the awaited command, not a button callback.
    final choices = symbol.candidates.map(selected).toList(growable: false);
    if (symbol.complete &&
        symbol.availability == 'exact' &&
        choices.length == 1) {
      return choices.single;
    }
    if (!mounted) return null;
    (Object, StackTrace)? failure;
    final choice = await ui.dialog<ResolvedWorkbenchObject>(
      context,
      l.selectTarget,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!symbol.complete) Text(l.partial),
          Text(l.sqlSymbolAmbiguous),
          for (final candidate in choices)
            ui.textButton(
              '${profile.name} / ${candidate.object.displayPath(profile.engine)}',
              () {
                try {
                  model.requireTarget(captured, text: true);
                  candidate.evidence?.requireCurrent(model);
                } catch (error, stack) {
                  failure = (error, stack);
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pop(candidate);
              },
            ),
        ],
      ),
      [ui.button(l.cancel, () => Navigator.of(context).pop())],
    );
    final rejected = failure;
    if (rejected != null) {
      Error.throwWithStackTrace(rejected.$1, rejected.$2);
    }
    if (choice != null) {
      model.requireTarget(captured, text: true);
      choice.evidence?.requireCurrent(model);
    }
    return choice;
  }

  String? deactivateSourceReason(String? profileId) {
    final l = strings(context);
    if (!model.profiles.any((p) => p.id == profileId)) return l.selectTarget;
    final live = model.sessions.values
        .where(
          (s) =>
              s.profile.id == profileId &&
              s.transaction != rpc.TransactionState.DISCONNECTED,
        )
        .toList();
    if (live.isEmpty) return l.requireSession;
    final sessionIds = live.map((s) => s.sessionId).toSet();
    final owners = model.operationOwners
        .where((owner) => owner.profileId == profileId)
        .map((o) => o.id)
        .toSet();
    if (live.any(
          (s) => s.transaction == rpc.TransactionState.UNKNOWN_TRANSACTION,
        ) ||
        model.jobs.values.any(
          (j) =>
              owners.contains(model.jobDocuments[j.jobId]) &&
              j.state == rpc.JobState.UNKNOWN_OUTCOME,
        )) {
      return l.outcomeUnknown;
    }
    if (live.any((s) => s.transaction == rpc.TransactionState.ACTIVE)) {
      return l.activeTransaction;
    }
    if (live.any(
      (s) => s.transaction == rpc.TransactionState.FAILED_TRANSACTION,
    )) {
      return l.failedTransaction;
    }
    if (model.jobs.values.any(
      (j) =>
          sessionIds.contains(j.sessionId) &&
          !WorkbenchModel.terminalJob(j.state),
    )) {
      return l.operationPending;
    }
    if (model.editBatches.values.any(
      (batch) =>
          owners.contains(batch.ownerId) &&
          (batch.changes.isNotEmpty || batch.applying || batch.outcomeUnknown),
    )) {
      return l.recoveryReconcileFirst;
    }
    return null;
  }

  Future<void> deactivateSource(WorkbenchCommandContext c) async {
    final l = strings(context), profileId = c.profileId!;
    final targets = model.sessions.values
        .where(
          (s) =>
              s.profile.id == profileId &&
              s.transaction != rpc.TransactionState.DISCONNECTED,
        )
        .map((s) => model.captureSessionTarget(s.sessionId))
        .toList();
    final ids = targets.map((t) => t.sessionId).toSet();
    void requireGroup() {
      final reason = deactivateSourceReason(profileId);
      if (reason != null) throw StateError(reason);
      final current = model.sessions.values
          .where(
            (s) =>
                s.profile.id == profileId &&
                s.transaction != rpc.TransactionState.DISCONNECTED,
          )
          .map((s) => s.sessionId)
          .toSet();
      if (current.length != ids.length || !current.containsAll(ids)) {
        throw StateError(l.staleContext);
      }
      for (final target in targets) {
        model.requireTarget(target);
      }
    }

    requireGroup();
    final description = targets
        .map(
          (target) =>
              '${workbenchTargetDescription(context, target)}\n${model.operationOwners.where((o) => o.sessionId == target.sessionId).map((o) => documentName(context, model, o)).join(', ')}',
        )
        .join('\n\n');
    if (!await confirm(
      l.deactivateSource,
      '$description\n\n${l.disconnectSessionNote}',
      actionLabel: l.deactivateSource,
    )) {
      return;
    }
    requireGroup();
    await model.command(() async {
      final remaining = ids.toSet();
      for (final target in targets) {
        // Each close uses the existing reviewed lifecycle; a newly busy
        // remaining session stops the group without forcing it.
        final reason = deactivateSourceReason(profileId);
        if (reason != null) throw StateError(reason);
        final current = model.sessions.values
            .where(
              (s) =>
                  s.profile.id == profileId &&
                  s.transaction != rpc.TransactionState.DISCONNECTED,
            )
            .map((s) => s.sessionId)
            .toSet();
        if (current.length != remaining.length ||
            !current.containsAll(remaining)) {
          throw StateError(l.staleContext);
        }
        model.requireTarget(target);
        await model.disconnectRetainedSession(
          target.sessionId!,
          reviewedTarget: target,
        );
        remaining.remove(target.sessionId);
      }
      if (model.sessions.values.any(
        (s) =>
            s.profile.id == profileId &&
            s.transaction != rpc.TransactionState.DISCONNECTED,
      )) {
        throw StateError(l.staleContext);
      }
    }, ownerId: 'connection:$profileId');
  }

  String connectionErrorText(Object error) => error is ConnectionAttemptFailure
      ? '${error.target}: ${mounted ? error.failure.localizedSummary(strings(context)) : error.failure.summary}'
      : operationFailureSummary(
          error,
          locale: mounted ? strings(context) : null,
        );
  Future<void> execute(
    rpc.ExecutionMode mode, {
    SqlDocument? owner,
  }) => model.command(
    () async {
      final document = owner ?? model.document;
      final runLabel = strings(context).run;
      final revision = document.version, selected = document.editor.value;
      await ensureSqlSession(document);
      if (!model.documents.contains(document) ||
          document.version != revision ||
          document.editor.value.selection != selected.selection ||
          !listEquals(
            document.editor.value.secondarySelections,
            selected.secondarySelections,
          )) {
        throw StateError(
          'SQL or selection changed during connection; run again to execute the intended text',
        );
      }
      final typedOwner = model.workbenchDocuments.firstWhere(
        (d) => d.id == document.id,
      );
      final target = model.captureTarget(owner: typedOwner);
      final request = model.execution(mode, document: document);
      final review = await target.backend.client.review(request);
      if (!mounted) return;
      model.requireTarget(target, text: true);
      if (review.risks.isNotEmpty &&
          !await confirm(
            strings(context).reviewDetails,
            '${workbenchTargetDescription(context, target)}\n${review.risks.join('\n')}\n\n${review.statements.join('\n\n')}',
            actionLabel: runLabel,
          )) {
        return;
      }
      model.requireTarget(target, text: true);
      request.approvalToken = review.token;
      await model.submit(request);
    },
    ownerId: (owner ?? model.document).id,
    errorText: connectionErrorText,
  );
  Future<void> tool(
    rpc.ToolKind kind, {
    WorkbenchCommandContext? commandTarget,
  }) => model.command(
    () async {
      final c = commandTarget ?? model.commandContext;
      final owner = ownerFor(c);
      final explain =
          kind == rpc.ToolKind.EXPLAIN || kind == rpc.ToolKind.EXPLAIN_ANALYZE;
      if (explain) {
        final before = owner.sql!.editor.value, revision = owner.version;
        await ensureSqlSession(owner.sql!);
        if (owner.version != revision ||
            owner.sql!.editor.value.selection != before.selection ||
            !listEquals(
              owner.sql!.editor.value.secondarySelections,
              before.secondarySelections,
            )) {
          throw StateError(
            'SQL or selection changed during connection; request Explain again',
          );
        }
      }
      if (!mounted) return;
      final target = model.captureTarget(owner: owner);
      final targetLabel = workbenchCapturedOwner(context, target);
      final actionLabel = toolLabel(kind);
      final reviewLabel = strings(context).reviewDetails;
      String sql = '';
      if (explain) {
        final selected = model.execution(
          owner.sql!.editor.selectedText.isEmpty
              ? rpc.ExecutionMode.CURRENT_STATEMENT
              : rpc.ExecutionMode.SELECTION,
          document: owner.sql,
        );
        final statement = await target.backend.client.review(selected);
        model.requireTarget(target, text: true);
        if (statement.statements.length != 1) {
          throw StateError(
            'Explain requires one selected or current statement',
          );
        }
        sql = statement.statements.single;
      }
      final request = rpc.ToolRequest(
        context: model.context,
        sessionId: target.sessionId,
        executionId: const Uuid().v4(),
        kind: kind,
        sql: sql,
        schema:
            c.object?.schema ?? model.sessions[target.sessionId]?.currentSchema,
        table: c.object?.name,
      );
      final review = await target.backend.client.reviewToolAdmission(request);
      if (!mounted) return;
      model.requireTarget(target, text: explain);
      if (!await confirm(
        '$reviewLabel · $actionLabel',
        '${workbenchTargetDescription(context, target)}\n${review.risks.join('\n')}\n${review.statements.join('\n')}\n\n${kind == rpc.ToolKind.EXPLAIN || kind == rpc.ToolKind.EXPLAIN_ANALYZE ? request.sql : ''}',
        actionLabel: actionLabel,
      )) {
        return;
      }
      request.approvalToken = review.token;
      WorkbenchDocument? detail;
      if (!explain) {
        detail = model.openTask(
          WorkbenchDocumentKind.administration,
          '$actionLabel · $targetLabel',
          profileId: owner.profileId,
          reuse: false,
          payload: ExecutionDocumentData(target, actionLabel),
        );
        detail.sessionId = target.sessionId;
      }
      await model.submitTool(
        target,
        request,
        text: explain,
        documentId: detail?.id,
      );
    },
    ownerId: ownerFor(commandTarget ?? model.commandContext).id,
    errorText: connectionErrorText,
  );
  Future<void> backup(
    bool restore, {
    WorkbenchCommandContext? commandTarget,
  }) => model.command(() async {
    final target = model.captureTarget(
      owner: ownerFor(commandTarget ?? model.commandContext),
    );
    final targetLabel = workbenchCapturedOwner(context, target),
        actionLabel = restore
            ? strings(context).restore
            : strings(context).backup,
        chooseTool =
            '${strings(context).chooseFile} · ${strings(context).nativeTool}',
        chooseRestore =
            '${strings(context).chooseSource} · ${strings(context).restore}';
    final bundled = packagedDatabaseTool(
      model.sessions[target.sessionId]!.profile.engine,
      restore: restore,
    );
    final selected = bundled == null
        ? await openFile(confirmButtonText: chooseTool)
        : null;
    final executablePath = bundled ?? selected?.path;
    if (executablePath == null) return;
    if (bundled != null && !await File(bundled).exists()) {
      throw StateError(
        'The installed package is missing its native database client; repair the BusyData package before dump/restore',
      );
    }
    final input = restore
        ? await openFile(confirmButtonText: chooseRestore)
        : null;
    final output = !restore
        ? await getSaveLocation(suggestedName: 'database.sql')
        : null;
    final path = restore ? input?.path : output?.path;
    if (path == null) return;
    model.requireTarget(target);
    final r = rpc.ToolRequest(
      context: target.backend.context(),
      sessionId: target.sessionId,
      executionId: const Uuid().v4(),
      kind: restore ? rpc.ToolKind.RESTORE : rpc.ToolKind.DUMP,
      path: path,
      nativeToolPath: executablePath,
      overwrite: !restore,
    );
    final owner = model.openTask(
      WorkbenchDocumentKind.transfer,
      '$actionLabel · $targetLabel',
      profileId: target.owner?.profileId,
      reuse: false,
      payload: TransferDocumentData(
        target,
        r.kind,
        path: path,
        nativeTool: executablePath,
      ),
    );
    owner.sessionId = target.sessionId;
    owner.reopenCommandId = restore ? 'backup.restore' : 'backup.dump';
  }, ownerId: ownerFor(commandTarget ?? model.commandContext).id);
  Future<void> formatSql({bool currentStatement = false}) async {
    final l = strings(context);
    final target = model.document,
        binding = model.analysisBinding(model.document);
    final targetName = sqlDocumentName(context, target);
    final result = await model.analyze(
      target,
      operation: rpc.AnalysisOperation.FORMAT,
      currentStatement: currentStatement,
      formatStart: target.selectionUtf16.$1 == target.selectionUtf16.$2
          ? null
          : target.selectionUtf16.$1,
      formatEnd: target.selectionUtf16.$1 == target.selectionUtf16.$2
          ? null
          : target.selectionUtf16.$2,
    );
    final accepted = model.acceptedAnalysis;
    if (result == null ||
        accepted == null ||
        !identical(accepted.result, result) ||
        !model.analysisMatches(binding)) {
      model.updateStatus(l.formatSqlChanged);
      return;
    }
    final formatted = accepted.result.formattedSql;
    if (formatted.isEmpty) {
      model.updateStatus(l.formatSqlUnavailable);
      return;
    }
    if (await confirm(
      '${l.reviewDetails} · ${l.formatSql} · $targetName',
      formatted,
      actionLabel: l.formatSql,
    )) {
      if (!model.applyFormatting(accepted)) {
        model.updateStatus(l.formatSqlChanged);
      }
    }
  }

  SingleActivator shortcut(String command) =>
      workbenchShortcut(model.shortcuts[command]!);

  Future<void> preferences() async {
    if (settingsVisible) return;
    if (sharedSearch.target != null && !await closeActionSearch()) return;
    settingsReturnFocus =
        model.documentFocus.focusedChild ?? FocusManager.instance.primaryFocus;
    settingsCategory.value = 'appearance';
    setState(() => settingsVisible = true);
  }

  Future<void> closeSettings() async {
    if (settingsKey.currentState != null &&
        !await settingsKey.currentState!.mayLeave()) {
      return;
    }
    if (!mounted) return;
    final target = settingsReturnFocus;
    final retiringFocus = FocusManager.instance.primaryFocus;
    setState(() => settingsVisible = false);
    settingsReturnFocus = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || settingsVisible || sharedSearch.target != null) return;
      final current = FocusManager.instance.primaryFocus;
      if (current != retiringFocus &&
          current != target &&
          current?.context?.mounted == true &&
          current is! FocusScopeNode) {
        return;
      }
      if (target?.context?.mounted == true && target!.canRequestFocus) {
        target.requestFocus();
      }
    });
  }

  Future<void> snippets() async {
    final target = model.document, revision = target.version;
    await ui.dialog<void>(
      context,
      strings(context).snippets,
      WorkbenchDialogBody(
        maxHeight: 480,
        child: SnippetView(
          controls: ui,
          snippets: model.snippets,
          save: model.saveSnippet,
          insert: (text) {
            if (!model.documents.contains(target) ||
                target.version != revision) {
              throw StateError(
                'The target SQL changed or closed; reopen snippets for a fresh insertion',
              );
            }
            target.editor.replaceSelection(text);
            Navigator.of(context).pop();
          },
        ),
      ),
      [ui.button(strings(context).close, () => Navigator.of(context).pop())],
      bodyScrolls: true,
    );
  }

  WorkbenchDocument ownerFor(WorkbenchCommandContext c) {
    if (c.owner?.object != null &&
        c.owner?.sessionId == null &&
        c.sessionId != null) {
      return model.connectionOwner(
        model.profiles.firstWhere((p) => p.id == c.profileId),
      );
    }
    if (c.owner != null) return c.owner!;
    final profile = model.profiles.firstWhere((p) => p.id == c.profileId);
    return model.connectionOwner(profile);
  }

  SchemaToolsView schemaTools(WorkbenchCommandContext c) => SchemaToolsView(
    model,
    ui,
    owner: ownerFor(c),
    object: c.object,
    creationScope: c.creationScope,
  );
  WorkbenchCommandRegistry buildRegistry() {
    bool unsupportedDefinition(DatabaseObjectIdentity object) =>
        object.kind == rpc.ObjectKind.TABLE &&
        [
          rpc.ObjectSubtype.PARTITIONED_TABLE,
          rpc.ObjectSubtype.FOREIGN_TABLE,
        ].contains(object.subtype);
    final l = strings(context);
    String? newQueryReason(WorkbenchCommandContext c) {
      final id = c.creationScope?.profileId ?? c.profileId;
      if (c.folderId != null || id == '') return l.selectTarget;
      if (c.creationScope != null &&
          c.profileId != null &&
          c.creationScope!.profileId != c.profileId) {
        return l.staleContext;
      }
      if (id == null) return null;
      final saved = model.profiles.where((p) => p.id == id).firstOrNull;
      if (saved == null) return l.selectTarget;
      final actual =
          model.sessions[c.sessionId]?.profile ?? c.owner?.evidenceProfile;
      if (actual == null) return null;
      // A selected namespace supplies the console database independently of
      // the source's saved default. Endpoint and safety settings must agree.
      rpc.Profile scoped(rpc.Profile p) =>
          p.deepCopy()
            ..database = c.creationScope?.catalog ?? c.object?.catalog ?? '';
      return actual.id != id ||
              !WorkbenchModel.sameConnectionTarget(
                scoped(actual),
                scoped(saved),
              )
          ? l.staleContext
          : null;
    }

    String? sql(WorkbenchCommandContext c) =>
        c.owner?.sql == null ? l.requireSql : null;
    String? executableSql(WorkbenchCommandContext c) =>
        sql(c) ??
        (model.commandPendingForOwner(c.owner!.id)
            ? l.operationPending
            : null) ??
        (model.backend == null ? l.restartBackend : null) ??
        (c.sessionId == null &&
                model
                    .jobsForOwner(c.owner!)
                    .any((job) => job.state == rpc.JobState.UNKNOWN_OUTCOME)
            ? l.outcomeUnknown
            : null) ??
        (c.sessionId == null
            ? model.profiles.any((p) => p.id == c.profileId)
                  ? null
                  : l.selectTarget
            : c.sessionId != null &&
                  model.sessions[c.sessionId]?.transaction ==
                      rpc.TransactionState.UNKNOWN_TRANSACTION
            ? l.outcomeUnknown
            : model.sessions[c.sessionId] == null ||
                  model.sessions[c.sessionId]?.transaction ==
                      rpc.TransactionState.DISCONNECTED
            ? l.requireSession
            : null);
    String? live(WorkbenchCommandContext c) {
      final session = model.sessions[c.sessionId];
      if (session?.transaction == rpc.TransactionState.UNKNOWN_TRANSACTION) {
        return l.outcomeUnknown;
      }
      if (model.backend == null ||
          session == null ||
          session.transaction == rpc.TransactionState.DISCONNECTED) {
        return l.requireSession;
      }
      return null;
    }

    String? scopedLive(WorkbenchCommandContext c) {
      final unavailable = live(c);
      if (unavailable != null) return unavailable;
      final session = model.sessions[c.sessionId]!;
      final catalog = c.object?.catalog ?? c.creationScope?.catalog;
      return session.profile.engine == rpc.Engine.POSTGRESQL &&
              catalog != null &&
              catalog.isNotEmpty &&
              catalog != session.currentCatalog
          ? '${l.requireSession} · $catalog'
          : null;
    }

    String? result(WorkbenchCommandContext c) =>
        c.owner == null ||
            model.resultForOwner(c.owner!) == null ||
            (c.resultId != null &&
                model.displayResultForOwner(c.owner!)?.resultId != c.resultId)
        ? l.requireResult
        : null;
    String? tableBusy(WorkbenchCommandContext c) =>
        c.owner?.kind == WorkbenchDocumentKind.table &&
            (model.commandPendingForOwner(c.owner!.id) ||
                model.cancellableJobForOwner(c.owner!) != null)
        ? l.operationPending
        : null;
    String? plan(WorkbenchCommandContext c) =>
        result(c) ??
        (model.resultForOwner(c.owner!)!.plan ? null : l.requirePlan);
    String? applyContext(WorkbenchCommandContext c) =>
        live(c) ??
        (model.sessions[c.sessionId]?.autoCommit != true ||
                model.sessions[c.sessionId]?.transaction !=
                    rpc.TransactionState.IDLE ||
                model.jobs.values.any(
                  (j) =>
                      j.sessionId == c.sessionId &&
                      !WorkbenchModel.terminalJob(j.state),
                )
            ? l.applyRequiresAutoCommit
            : null);
    String? batchContext(WorkbenchCommandContext c) {
      final batch = model.batchFor(
        c.owner!,
        model.resultForOwner(c.owner!)?.resultId ?? '',
      );
      if (batch.appliedSnapshot) return l.preChangeSnapshot;
      if (batch.outcomeUnknown) return l.outcomeUnknown;
      if (batch.applying || batch.pendingRecovery != 0) {
        return l.operationPending;
      }
      return applyContext(c);
    }

    String? object(WorkbenchCommandContext c) =>
        c.object == null ? l.requireObject : null;
    String? reorderReason(WorkbenchCommandContext c, int direction) {
      final folder = model.sourceFolders[c.folderId];
      if (c.folderId != null && folder == null ||
          c.folderId == null &&
              !model.profiles.any((p) => p.id == c.profileId)) {
        return l.selectTarget;
      }
      final parent =
          folder?.parentId ?? model.sourceFolderMembership[c.profileId] ?? '';
      final siblings = model.explorerSiblings(parent);
      final index = siblings.indexOf(
        c.folderId != null ? 'f:${c.folderId}' : 's:${c.profileId}',
      );
      return index < 0 ||
              index + direction < 0 ||
              index + direction >= siblings.length
          ? l.unavailable
          : null;
    }

    String? tableObject(WorkbenchCommandContext c) =>
        c.object == null ||
            ![
              rpc.ObjectKind.TABLE,
              rpc.ObjectKind.VIEW,
            ].contains(c.object!.kind)
        ? l.requireTableOrView
        : null;
    String? browseObjectTarget(WorkbenchCommandContext c) => c.object != null
        ? tableObject(c)
        : c.owner?.sql != null && c.sessionId != null
        ? null
        : l.requireTableOrView;
    WorkbenchCommand action(
      String id,
      String label,
      String category,
      FutureOr<void> Function(WorkbenchCommandContext) invoke, {
      String? Function(WorkbenchCommandContext)? requirement,
      bool Function(WorkbenchCommandContext)? visible,
      String? key,
    }) => WorkbenchCommand(
      id: id,
      label: label,
      category: category,
      invoke: invoke,
      disabledReason: requirement,
      visible: visible,
      shortcut: key == null ? null : model.shortcuts[key],
      shortcutKey: key,
    );
    return WorkbenchCommandRegistry(
      [
        action(
          'connection.consoles',
          l.queryConsoles,
          l.connectionMenu,
          (c) async {
            final profile = c.profileId!;
            final consoles = model.documents
                .where((d) => d.profileId == profile)
                .toList();
            String consoleTitle(SqlDocument document) {
              if (document.path == null) {
                return sqlDocumentName(context, document);
              }
              return consoles.any(
                    (other) =>
                        !identical(other, document) &&
                        other.path != null &&
                        other.title == document.title,
                  )
                  ? '${document.title} · ${document.path}'
                  : document.title;
            }

            await ui.dialog<void>(
              context,
              l.queryConsoles,
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final document in consoles)
                    ui.textButton(
                      '${consoleTitle(document)} · ${model.sessions[document.sessionId]?.currentCatalog ?? document.connectionCatalog} / ${model.sessions[document.sessionId]?.currentSchema ?? document.connectionSchema}',
                      () {
                        final index = model.documents.indexOf(document);
                        if (index < 0 || document.profileId != profile) {
                          model.updateStatus(l.selectTarget);
                          return;
                        }
                        Navigator.of(context).pop();
                        model.select(index);
                      },
                    ),
                  ui.textButton(l.newSql, () {
                    Navigator.of(context).pop();
                    model.commands?.invoke('file.new', c);
                  }),
                ],
              ),
              [ui.button(l.cancel, () => Navigator.of(context).pop())],
            );
          },
          requirement: (c) => model.profiles.any((p) => p.id == c.profileId)
              ? null
              : l.selectTarget,
          key: 'consoles',
        ),
        action(
          'file.new',
          l.newSql,
          l.fileMenu,
          (c) {
            final scope = c.creationScope;
            final id = scope?.profileId ?? c.profileId;
            final source = model.profiles
                .where((p) => p.id == id)
                .firstOrNull
                ?.deepCopy();
            model.newQuery();
            model.document.profileId = id;
            final object = c.object;
            model.document.connectionCatalog =
                scope?.catalog ??
                (object?.kind == rpc.ObjectKind.CATALOG
                    ? object!.name
                    : object?.catalog ?? '');
            model.document.connectionSchema =
                scope?.schema ?? object?.schema ?? '';
            model.activeOwner.evidenceProfile = source;
          },
          requirement: newQueryReason,
          key: 'new',
        ),
        action(
          'job.cancel',
          l.cancel,
          l.runMenu,
          (c) async {
            final backend = model.backend!, id = c.jobId!;
            final reply = await backend.client.cancel(
              rpc.JobRequest(context: backend.context(), jobId: id),
            );
            if (identical(model.backend, backend)) {
              model.jobs[id] = reply;
              model.updateStatus(l.cancelRequested);
            }
          },
          requirement: (c) =>
              model.backend == null ||
                  c.jobId == null ||
                  model.jobs[c.jobId] == null ||
                  WorkbenchModel.terminalJob(model.jobs[c.jobId]!.state)
              ? l.jobs
              : null,
        ),
        action('file.open', l.openSqlFile, l.fileMenu, (_) => open()),
        action(
          'file.save',
          l.saveSql,
          l.fileMenu,
          (c) => save(owner: c.owner?.sql),
          requirement: sql,
          key: 'save',
        ),
        action(
          'file.close',
          l.closeTab,
          l.fileMenu,
          (c) => closeTab(owner: c.owner),
          key: 'close',
        ),
        action(
          'workspace.open',
          l.openWorkspace,
          l.fileMenu,
          (_) => workspace(true),
        ),
        action(
          'workspace.save',
          l.saveWorkspace,
          l.fileMenu,
          (_) => workspace(false),
        ),
        action('preferences', l.settings, l.fileMenu, (_) => preferences()),
        action(
          'editor.find',
          l.findText,
          l.editMenu,
          (c) => showEditorSearch(target: c),
          requirement: sql,
          key: 'find',
        ),
        action(
          'editor.replace',
          l.replaceText,
          l.editMenu,
          (c) => showEditorSearch(target: c, replacing: true),
          requirement: sql,
          key: 'replace',
        ),
        action(
          'editor.inspections',
          l.sqlInspections,
          l.editMenu,
          (c) => showSqlDiagnostics(context, ui, model, c.owner!.sql!),
          requirement: sql,
        ),
        action(
          'editor.formatStatement',
          l.formatCurrentStatement,
          l.editMenu,
          (_) => formatSql(currentStatement: true),
          requirement: sql,
        ),
        action(
          'editor.format',
          l.formatSql,
          l.editMenu,
          (_) => formatSql(),
          requirement: sql,
        ),
        action(
          'editor.comment',
          l.lineComments,
          l.editMenu,
          (c) {
            c.owner!.sql!.toggleLineComments();
          },
          requirement: sql,
          key: 'comment',
        ),
        action(
          'editor.snippets',
          l.snippets,
          l.editMenu,
          (_) => snippets(),
          requirement: sql,
        ),
        action(
          'view.palette',
          l.commands,
          l.viewMenu,
          (target) => palette(target),
          key: 'palette',
        ),
        action('view.explorer', l.databaseExplorer, l.viewMenu, (_) {
          model.setExplorerVisible(true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              final focus = model.explorerFocus.traversalDescendants
                  .where(
                    (node) => node.canRequestFocus && node is! FocusScopeNode,
                  )
                  .firstOrNull;
              (focus ?? model.explorerFocus).requestFocus();
            }
          });
        }, key: 'explorer'),
        action(
          'view.start',
          l.startTitle,
          l.viewMenu,
          (_) => model.showWelcome(),
        ),
        action(
          'view.workbench',
          l.databaseWorkbench,
          l.viewMenu,
          (_) => model.showWorkbench(),
        ),
        action('view.history', l.history, l.viewMenu, (_) => history()),
        action(
          'history.search',
          l.searchSqlTarget,
          l.viewMenu,
          (c) => openSharedSearch('history', target: c, rebind: true),
          requirement: (_) => model.backend == null ? l.noConnection : null,
        ),
        action(
          'view.results',
          l.retainedResults,
          l.viewMenu,
          (_) => retainedResults(),
        ),
        action('view.jobs', l.jobs, l.viewMenu, (_) {
          model.showGlobalTool(
            WorkbenchDocument(
              id: 'global:jobs',
              kind: WorkbenchDocumentKind.administration,
              title: l.jobs,
              payload: GlobalToolData(GlobalToolKind.jobs),
            ),
          );
        }),
        action('view.problems', l.problems, l.viewMenu, (_) {
          model.showGlobalTool(
            WorkbenchDocument(
              id: 'global:problems',
              kind: WorkbenchDocumentKind.administration,
              title: l.problems,
              payload: GlobalToolData(GlobalToolKind.problems),
            ),
          );
        }),
        action(
          'view.sessions',
          l.ownedSessions,
          l.viewMenu,
          (_) => connections(),
        ),
        action(
          'backend.restart',
          l.restartBackend,
          l.viewMenu,
          (_) => model.command(model.restart, ownerId: 'application'),
          requirement: (_) => model.backend != null
              ? l.unavailable
              : model.pendingOperations != 0
              ? l.operationPending
              : null,
          visible: (_) => model.backend == null,
        ),
        action(
          'view.recovery',
          l.recoverEdits,
          l.viewMenu,
          (_) => recoverEdits(),
        ),
        action(
          'connection.new',
          l.newConnection,
          l.connectionMenu,
          (_) => profile(),
        ),
        action(
          'connection.new-query',
          l.newConnection,
          l.connectionMenu,
          (c) => profile(
            queryDestination: c.owner,
            invocation: ConnectionManagementInvocation.createQueryTarget,
          ),
          requirement: (c) => c.owner?.sql == null ? l.selectTarget : null,
          visible: (_) => false,
        ),
        action(
          'connection.edit',
          l.editConnection,
          l.connectionMenu,
          (c) => profile(
            initial: model.profiles
                .where((p) => p.id == c.profileId)
                .firstOrNull,
            queryDestination: c.owner?.sql != null ? c.owner : null,
            invocation: ConnectionManagementInvocation.reconnect,
          ),
          requirement: (c) => model.profiles.any((p) => p.id == c.profileId)
              ? null
              : l.selectTarget,
        ),
        action('connection.favorite', l.favorite, l.connectionMenu, (c) async {
          final id = c.profileId!;
          if (!model.favoriteProfiles.remove(id)) {
            model.favoriteProfiles.add(id);
          }
          await model.savePresentation();
          model.updateStatus(l.favorite);
        }, requirement: (c) => c.profileId == null ? l.selectTarget : null),
        action(
          'folder.new',
          l.newSourceFolder,
          l.connectionMenu,
          (c) => editSourceFolder(c),
        ),
        action(
          'folder.rename',
          l.renameSourceFolder,
          l.connectionMenu,
          (c) => editSourceFolder(c, rename: true),
          requirement: (c) => model.sourceFolders.containsKey(c.folderId)
              ? null
              : l.selectTarget,
        ),
        action(
          'source.move',
          l.moveToFolder,
          l.connectionMenu,
          moveToFolder,
          requirement: (c) =>
              c.folderId != null ||
                  model.profiles.any((p) => p.id == c.profileId)
              ? null
              : l.selectTarget,
        ),
        action(
          'source.up',
          l.moveUp,
          l.connectionMenu,
          (c) => model.reorderExplorer(
            c.folderId != null ? 'f:${c.folderId}' : 's:${c.profileId}',
            -1,
          ),
          requirement: (c) => reorderReason(c, -1),
        ),
        action(
          'source.down',
          l.moveDown,
          l.connectionMenu,
          (c) => model.reorderExplorer(
            c.folderId != null ? 'f:${c.folderId}' : 's:${c.profileId}',
            1,
          ),
          requirement: (c) => reorderReason(c, 1),
        ),
        action(
          'folder.remove',
          l.remove,
          l.connectionMenu,
          (c) => model.removeSourceFolder(c.folderId!),
          requirement: (c) => !model.sourceFolders.containsKey(c.folderId)
              ? l.selectTarget
              : model.profiles.any(
                      (p) => model.sourceFolderMembership[p.id] == c.folderId,
                    ) ||
                    model.sourceFolders.values.any(
                      (f) => f.parentId == c.folderId,
                    )
              ? l.folderMustBeEmpty
              : null,
        ),
        action(
          'virtual.new',
          l.newVirtualView,
          l.objectMenu,
          (c) => editVirtualView(c),
          requirement: (c) =>
              c.creationScope?.catalog.isNotEmpty == true &&
                  c.creationScope?.schema.isNotEmpty == true &&
                  model.profiles.any((p) => p.id == c.creationScope?.profileId)
              ? null
              : l.selectTarget,
        ),
        action(
          'virtual.edit',
          l.editVirtualDefinition,
          l.objectMenu,
          (c) => editVirtualView(c),
          requirement: (c) => switch (model.virtualViews[c.virtualViewId]) {
            final view?
                when model.profiles.any((p) => p.id == view.scope.profileId) =>
              null,
            _ => l.unboundVirtualView,
          },
        ),
        action(
          'virtual.rename',
          l.renameVirtualView,
          l.objectMenu,
          (c) => editVirtualView(c, rename: true),
          requirement: (c) => switch (model.virtualViews[c.virtualViewId]) {
            final view?
                when model.profiles.any((p) => p.id == view.scope.profileId) =>
              null,
            _ => l.unboundVirtualView,
          },
        ),
        action(
          'virtual.open',
          l.openSql,
          l.objectMenu,
          (c) {
            model.openVirtualView(c.virtualViewId!);
          },
          requirement: (c) => switch (model.virtualViews[c.virtualViewId]) {
            final view?
                when model.profiles.any((p) => p.id == view.scope.profileId) =>
              null,
            _ => l.unboundVirtualView,
          },
        ),
        action(
          'virtual.run',
          l.run,
          l.objectMenu,
          (c) async {
            final document = model.openVirtualView(c.virtualViewId!);
            if (model.jobs.values.any(
              (job) =>
                  model.jobDocuments[job.jobId] == document.id &&
                  !WorkbenchModel.terminalJob(job.state),
            )) {
              throw StateError(l.operationPending);
            }
            await execute(rpc.ExecutionMode.SCRIPT, owner: document);
          },
          requirement: (c) => switch (model.virtualViews[c.virtualViewId]) {
            final view?
                when model.profiles.any((p) => p.id == view.scope.profileId) =>
              null,
            _ => l.unboundVirtualView,
          },
        ),
        action(
          'virtual.remove',
          l.remove,
          l.objectMenu,
          (c) async {
            final view = model.virtualViews[c.virtualViewId];
            if (view != null &&
                await confirm(
                  l.remove,
                  '${view.name}\n${l.localVirtualViewNotice}',
                )) {
              if (!identical(model.virtualViews[view.id], view)) {
                throw StateError(l.expiredChangeReview);
              }
              await model.removeVirtualView(view.id);
            }
          },
          requirement: (c) => model.virtualViews.containsKey(c.virtualViewId)
              ? null
              : l.selectTarget,
        ),
        action(
          'virtual.rebind',
          l.rebindVirtualView,
          l.objectMenu,
          rebindVirtualView,
          requirement: (c) =>
              c.creationScope?.catalog.isNotEmpty == true &&
                  c.creationScope?.schema.isNotEmpty == true &&
                  model.virtualViews.values.any(
                    (v) =>
                        !model.profiles.any((p) => p.id == v.scope.profileId),
                  )
              ? null
              : l.selectTarget,
        ),
        action(
          'connection.connect',
          l.connect,
          l.connectionMenu,
          (c) => model.command(
            () => connectContext(c),
            ownerId: c.owner?.id ?? 'connection:${c.profileId}',
            errorText: connectionErrorText,
          ),
        ),
        action(
          'connection.deactivate',
          l.deactivateSource,
          l.connectionMenu,
          deactivateSource,
          requirement: (c) => deactivateSourceReason(c.profileId),
        ),
        action(
          'connection.disconnect',
          l.disconnect,
          l.connectionMenu,
          (c) => disconnectPhysicalSession(c.sessionId!),
          requirement: (c) =>
              c.sessionId == null || model.sessions[c.sessionId] == null
              ? l.requireSession
              : null,
        ),
        action(
          'connection.share',
          l.sessionSharing,
          l.connectionMenu,
          (c) => shareSession(owner: c.owner),
          requirement: (c) =>
              sql(c) ?? (model.backend == null ? l.requireSession : null),
        ),
        action(
          'connection.search',
          l.searchObjects,
          l.connectionMenu,
          (c) => searchObjects(c),
          key: 'objects',
        ),
        action(
          'connection.details',
          l.sessionDetails,
          l.connectionMenu,
          (c) => sessionDetails(c),
        ),
        action(
          'sql.options',
          l.executionOptions,
          l.runMenu,
          (c) => executionOptions(c.owner!),
          requirement: sql,
        ),
        action(
          'connection.metadata',
          l.metadataSettings,
          l.connectionMenu,
          (c) => model.command(
            () => showMetadataSettings(context, ui, model, c.sessionId!),
            ownerId: ownerFor(c).id,
          ),
          requirement: live,
        ),
        action(
          'connection.capabilities',
          l.connectionCapabilities,
          l.connectionMenu,
          (c) => capabilities(target: c),
          requirement: live,
        ),
        action(
          'connection.activity',
          l.sessionsAndLocks,
          l.connectionMenu,
          (c) => activityAction(false, target: c),
          requirement: live,
        ),
        action(
          'connection.principals',
          l.usersAndRoles,
          l.connectionMenu,
          (c) => model.command(
            () =>
                showPrivileges(context, model, ui, ownerDocument: ownerFor(c)),
            ownerId: ownerFor(c).id,
          ),
          requirement: live,
        ),
        action(
          'schema.snapshot',
          l.saveSnapshot,
          l.objectMenu,
          (c) => model.command(
            () => schemaTools(c).snapshot(context),
            ownerId: ownerFor(c).id,
          ),
          requirement: scopedLive,
        ),
        action(
          'schema.compare',
          l.compareSchemas,
          l.objectMenu,
          (c) => schemaTools(c).compare(context),
          requirement: (c) => c.profileId == null ? l.selectTarget : null,
        ),
        action(
          'object.compare',
          l.compareStructure,
          l.objectMenu,
          (c) {
            final current = c.objects[0], desired = c.objects[1];
            final owner = model.openTask(
              WorkbenchDocumentKind.comparison,
              '${l.compareStructure} · ${current.displayNameFor(model.sessions[c.sessionId]?.profile.engine)}',
              profileId: current.profileId,
              reuse: false,
            );
            owner.payload =
                ComparisonData(
                    schema: current.schema,
                    profileId: current.profileId,
                  )
                  ..currentObject = current
                  ..desiredObject = desired
                  ..desiredProfile = desired.profileId;
          },
          requirement: (c) {
            if (c.objects.length != 2) return l.selectTwoCompatibleObjects;
            final a = c.objects[0], b = c.objects[1];
            final pa = model.profiles
                .where((p) => p.id == a.profileId)
                .firstOrNull;
            final pb = model.profiles
                .where((p) => p.id == b.profileId)
                .firstOrNull;
            return a == b ||
                    pa == null ||
                    pb == null ||
                    pa.engine != pb.engine ||
                    a.kind != rpc.ObjectKind.TABLE ||
                    b.kind != rpc.ObjectKind.TABLE ||
                    ![
                      rpc.ObjectSubtype.ORDINARY_TABLE,
                      rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
                    ].contains(a.subtype) ||
                    ![
                      rpc.ObjectSubtype.ORDINARY_TABLE,
                      rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
                    ].contains(b.subtype) ||
                    a.schema != b.schema ||
                    a.name != b.name
                ? l.scopedComparisonRestriction
                : null;
          },
        ),
        action(
          'connection.duplicate',
          l.duplicateConnection,
          l.connectionMenu,
          (c) async {
            final saved = model.profiles
                .where((profile) => profile.id == c.profileId)
                .firstOrNull;
            if (saved == null) throw StateError(l.selectTarget);
            await profile(
              initial: saved.deepCopy()
                ..id = const Uuid().v4()
                ..name = '${saved.name} · ${l.copy}'
                ..credentialRef = ''
                ..tls = (saved.tls.deepCopy()..clearKeyCredentialRef())
                ..ssh = (saved.ssh.deepCopy()..clearTrustRef()),
            );
          },
          requirement: (c) => c.profileId == null ? l.selectTarget : null,
        ),
        action(
          'connection.delete',
          l.deleteConnection,
          l.connectionMenu,
          (c) => model.command(() async {
            final saved = model.profiles
                .where((profile) => profile.id == c.profileId)
                .firstOrNull
                ?.deepCopy();
            if (saved == null) throw StateError(l.selectTarget);
            final target = model.captureTarget(owner: ownerFor(c));
            final review =
                '${l.deleteConnectionReview(saved.name)}\n${workbenchEnvironment(context, saved.environment)} · ${saved.host}:${saved.port}/${saved.database}';
            if (!await confirm(
              l.deleteConnection,
              review,
              actionLabel: l.deleteConnection,
            )) {
              return;
            }
            model.requireTarget(target);
            if (model.profiles
                    .where((profile) => profile.id == saved.id)
                    .firstOrNull !=
                saved) {
              throw StateError(l.expiredChangeReview);
            }
            final reply = await model.ownedRequest(
              target,
              () => target.backend.client.profiles(
                rpc.ProfileRequest(
                  context: target.backend.context(),
                  action: rpc.ProfileAction.DELETE_PROFILE,
                  profile: saved,
                ),
              ),
            );
            model.profiles
              ..clear()
              ..addAll(reply.profiles);
            model.sourceFolderMembership.remove(saved.id);
            model.explorerOrder.remove('s:${saved.id}');
            model.favoriteProfiles.remove(saved.id);
            await model.savePresentation();
            model.updateStatus(l.deleteConnection);
          }, ownerId: ownerFor(c).id),
          requirement: (c) => c.profileId == null
              ? l.selectTarget
              : model.backend == null
              ? l.unavailable
              : null,
        ),
        action(
          'schema.designer',
          l.objectDesigner,
          l.objectMenu,
          (c) => model.command(
            () => schemaTools(c).designer(context),
            ownerId: ownerFor(c).id,
          ),
          requirement: scopedLive,
        ),
        action(
          'schema.diagram',
          l.diagram,
          l.objectMenu,
          (c) => model.command(
            () => schemaTools(c).diagram(context),
            ownerId: ownerFor(c).id,
          ),
          requirement: scopedLive,
        ),
        action(
          'object.structure',
          l.inspectStructure,
          l.objectMenu,
          (c) => openObject(c, data: false),
          requirement: (c) =>
              c.object == null ||
                  [
                    rpc.ObjectKind.CATALOG,
                    rpc.ObjectKind.SCHEMA,
                  ].contains(c.object!.kind)
              ? l.requireObject
              : null,
        ),
        action(
          'object.reveal',
          l.revealInExplorer,
          l.objectMenu,
          (c) async {
            final profile =
                (model.sessions[c.sessionId]?.profile ??
                        c.owner?.evidenceProfile)
                    ?.deepCopy();
            final target = c.object ?? (await sqlSymbolTarget(c))?.object;
            if (target != null) {
              model.revealInExplorer(target, evidenceProfile: profile);
            }
          },
          requirement: (c) => c.object != null
              ? null
              : c.owner?.sql != null && c.sessionId != null
              ? null
              : l.requireObject,
          key: 'reveal',
        ),
        action(
          'object.documentation',
          l.quickDocumentation,
          l.objectMenu,
          (c) async {
            final object = c.object!;
            final profile = model.profiles
                .where((p) => p.id == object.profileId)
                .firstOrNull;
            if (profile == null) throw StateError(l.selectTarget);
            final properties =
                c.metadataObject?.properties.entries.take(12) ??
                const <MapEntry<String, String>>[];
            await ui.formDialog<void>(
              context,
              (dialogContext) => CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape): () =>
                      Navigator.of(dialogContext).pop(),
                },
                child: Focus(
                  autofocus: true,
                  child: ui.formShell(
                    l.quickDocumentation,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          workbenchObjectType(
                            context,
                            object.kind,
                            object.subtype,
                          ),
                        ),
                        SelectableText(
                          '${profile.name} / ${object.displayPath(profile.engine)}',
                        ),
                        for (final property in properties)
                          Builder(
                            builder: (context) {
                              final displayed = workbenchMetadataProperty(
                                context,
                                object.kind,
                                property.key,
                                property.value,
                              );
                              return SelectableText(
                                '${displayed.label}: ${String.fromCharCodes(displayed.value.runes.take(1024))}',
                              );
                            },
                          ),
                      ],
                    ),
                    [
                      ui.button(
                        l.close,
                        () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                    maxWidth: 500,
                  ),
                ),
              ),
            );
          },
          requirement: object,
          key: 'documentation',
        ),
        action(
          'object.ddl',
          l.openDefinition,
          l.objectMenu,
          (c) async {
            final selected = c.object ?? (await sqlSymbolTarget(c))?.object;
            if (selected == null) return;
            if (unsupportedDefinition(selected)) {
              throw StateError(l.metadataDefinitionUnsupported);
            }
            final owner = model.openTask(
              WorkbenchDocumentKind.structure,
              '${l.definition} · ${selected.displayNameFor(model.sessions[c.sessionId]?.profile.engine)}',
              object: selected,
              purpose: 'definition',
              evidenceProfile: model.sessions[c.sessionId]?.profile,
            );
            owner.view.metadataRequested = true;
            owner.view.metadataSessionId = c.sessionId;
            owner.view.metadataRevision++;
            owner.view.structureSection = rpc.ObjectKind.TABLE.value;
          },
          requirement: (c) => c.object == null
              ? (c.owner?.sql != null && c.sessionId != null
                    ? null
                    : l.metadataDefinitionUnsupported)
              : unsupportedDefinition(c.object!) ||
                    ![
                      rpc.ObjectKind.TABLE,
                      rpc.ObjectKind.VIEW,
                      rpc.ObjectKind.ROUTINE,
                      rpc.ObjectKind.SEQUENCE,
                      rpc.ObjectKind.COLUMN,
                      rpc.ObjectKind.INDEX,
                      rpc.ObjectKind.CONSTRAINT,
                      rpc.ObjectKind.FOREIGN_KEY,
                      rpc.ObjectKind.TRIGGER,
                    ].contains(c.object!.kind)
              ? l.metadataDefinitionUnsupported
              : null,
          key: 'ddl',
        ),
        action(
          'object.data',
          l.openData,
          l.objectMenu,
          (c) => openObject(c, data: true),
          requirement: browseObjectTarget,
          key: 'data',
        ),
        action(
          'object.refresh',
          l.refresh,
          l.objectMenu,
          (c) => model.command(
            () => browseObject(
              c.owner!,
              conditions: c.tableConditions,
              order: c.tableOrder,
            ),
            ownerId: c.owner!.id,
          ),
          requirement: (c) => c.owner?.kind != WorkbenchDocumentKind.table
              ? l.requireObject
              : tableBusy(c),
        ),
        action('object.sql', l.openSql, l.objectMenu, (c) async {
          final selected = await selectedBrowseObject(c);
          if (selected == null) return;
          final destination = ownerFor(c);
          if (destination.sessionId == null) await connectContext(c);
          final captured = model.captureTarget(owner: destination);
          final selection = await BrowseSelectionController(
            model,
          ).prepare(captured, selected.object, evidence: selected.evidence);
          final request = selection.request(
            model,
            executionId: const Uuid().v4(),
            rowLimit: Int64(c.owner?.view.rowLimit ?? model.defaultRowLimit),
          );
          final generated = await model.ownedRequest(
            captured,
            () => captured.backend.client.reviewBrowse(request),
          );
          selection.requireCurrent(model);
          model.newDocument(text: generated.statements.join('\n'));
          model.document.profileId = selection.object.profileId;
          model.activeOwner.evidenceProfile = captured.profile?.deepCopy();
        }, requirement: (c) => browseObjectTarget(c) ?? scopedLive(c)),
        action('object.copy', l.copyQualifiedName, l.objectMenu, (c) {
          final engine =
              model.sessions[c.sessionId]?.profile.engine ??
              c.owner?.evidenceProfile?.engine ??
              model.profiles
                  .firstWhere((p) => p.id == c.object!.profileId)
                  .engine;
          final quote = engine == rpc.Engine.POSTGRESQL ? '"' : '`';
          final o = c.object!;
          final names = [
            engine == rpc.Engine.POSTGRESQL
                ? o.schema
                : (o.schema.isEmpty ? o.catalog : o.schema),
            o.parent,
            o.name,
          ].where((n) => n.isNotEmpty);
          return Clipboard.setData(
            ClipboardData(
              text: names
                  .map(
                    (n) => '$quote${n.replaceAll(quote, quote + quote)}$quote',
                  )
                  .join('.'),
            ),
          );
        }, requirement: object),
        action(
          'sql.run',
          l.runStatement,
          l.runMenu,
          (c) => execute(
            c.owner!.sql!.editor.selectedText.isEmpty
                ? rpc.ExecutionMode.CURRENT_STATEMENT
                : rpc.ExecutionMode.SELECTION,
            owner: c.owner!.sql,
          ),
          requirement: executableSql,
          key: 'execute',
        ),
        action(
          'sql.selection',
          l.runSelection,
          l.runMenu,
          (c) => execute(rpc.ExecutionMode.SELECTION, owner: c.owner!.sql),
          requirement: executableSql,
        ),
        action(
          'sql.script',
          l.runScript,
          l.runMenu,
          (c) => execute(rpc.ExecutionMode.SCRIPT, owner: c.owner!.sql),
          requirement: executableSql,
          key: 'script',
        ),
        action(
          'sql.explain',
          l.explain,
          l.runMenu,
          (_) => tool(rpc.ToolKind.EXPLAIN),
          requirement: executableSql,
        ),
        action(
          'sql.analyze',
          l.explainAnalyze,
          l.runMenu,
          (_) => tool(rpc.ToolKind.EXPLAIN_ANALYZE),
          requirement: executableSql,
        ),
        for (final entry in <rpc.SessionAction, String>{
          rpc.SessionAction.BEGIN: l.beginTransaction,
          rpc.SessionAction.COMMIT: l.commitTransaction,
          rpc.SessionAction.ROLLBACK: l.rollbackTransaction,
          rpc.SessionAction.AUTO_COMMIT_ON: l.enableAutoCommit,
          rpc.SessionAction.AUTO_COMMIT_OFF: l.disableAutoCommit,
        }.entries)
          action('session.${entry.key.value}', entry.value, l.connectionMenu, (
            c,
          ) async {
            final captured = model.captureTarget(owner: c.owner);
            if (entry.key == rpc.SessionAction.COMMIT &&
                !await confirm(
                  l.commitTransaction,
                  '${workbenchTargetDescription(context, captured)}\n${l.commitUncertaintyNote}',
                )) {
              return;
            }
            model.requireTarget(captured);
            await model.transaction(entry.key, target: captured);
          }, requirement: live),
        action(
          'result.plan',
          l.plan,
          l.viewMenu,
          (c) => model.command(
            () => schemaTools(c).plan(context),
            ownerId: ownerFor(c).id,
          ),
          requirement: plan,
        ),
        action(
          'result.planDocument',
          l.openPlanDocument,
          l.results,
          (c) => model.command(
            () => schemaTools(c).plan(context, openDocument: true),
            ownerId: ownerFor(c).id,
          ),
          requirement: plan,
        ),
        action(
          'edit.insert',
          l.stageInsert,
          l.changes,
          (c) => edit(rpc.ChangeKind.INSERT, commandTarget: c),
          requirement: result,
        ),
        action(
          'edit.update',
          l.stageUpdate,
          l.changes,
          (c) => edit(rpc.ChangeKind.UPDATE, commandTarget: c),
          requirement: result,
        ),
        action(
          'edit.delete',
          l.stageDelete,
          l.changes,
          (c) => edit(rpc.ChangeKind.DELETE, commandTarget: c),
          requirement: result,
        ),
        action(
          'edit.apply',
          l.applyAndCommit,
          l.changes,
          (c) => applyEdits(commandTarget: c),
          requirement: (c) =>
              result(c) != null ||
                  model
                      .batchFor(
                        c.owner!,
                        model.resultForOwner(c.owner!)?.resultId ?? '',
                      )
                      .changes
                      .isEmpty
              ? l.requireResult
              : batchContext(c),
        ),
        action('edit.discard', l.discardChanges, l.changes, (c) async {
          final batch = model.batchFor(
            c.owner!,
            model.resultForOwner(c.owner!)?.resultId ?? '',
          );
          final captured = model.captureTarget(owner: c.owner);
          final revision = batch.revision;
          if (await confirm(
            l.discardChanges,
            batch.outcomeUnknown
                ? l.unknownBatch
                : l.discardChangesCount('${batch.changes.length}'),
          )) {
            model.requireTarget(captured);
            if (batch.revision != revision) {
              throw StateError(
                'Pending changes changed during the discard review; request a fresh decision',
              );
            }
            await model.discardStagedEdits(batch: batch);
          }
        }, requirement: result),
        for (final entry in {
          'result.details': l.viewDetails,
          'result.presentation.table':
              '${l.resultPresentation} · ${l.resultTable}',
          'result.presentation.transpose':
              '${l.resultPresentation} · ${l.resultTranspose}',
          'result.presentation.tree':
              '${l.resultPresentation} · ${l.resultTree}',
          'result.presentation.text':
              '${l.resultPresentation} · ${l.resultText}',
          'result.record': l.recordView,
          'result.displayFormat': l.displayFormat,
          'result.aggregate': l.aggregateView,
          'result.related': l.relatedRows,
          'result.clone': l.cloneRow,
          'result.inserts': l.editStagedInserts,
          'result.filter': l.filter,
          'result.sort': l.sort,
          'result.columns': l.columns,
          'result.refresh': l.refresh,
          'result.reset': l.resetView,
          'result.copy': l.copyRange,
          'result.inspect': l.inspectValue,
          'result.assess': l.assessEditing,
          'result.provenance': l.sqlProvenance,
        }.entries)
          action(
            entry.key,
            entry.value,
            l.results,
            (c) async {
              final invoke = model.resultActions[c.owner?.id]?[entry.key];
              if (invoke == null ||
                  result(c) != null ||
                  (c.resultId != null &&
                      model.resultActionSources[c.owner?.id] != c.resultId)) {
                throw StateError(l.requireResult);
              }
              await invoke();
            },
            requirement: (c) =>
                result(c) != null ||
                    (c.resultId != null &&
                        model.resultActionSources[c.owner?.id] != c.resultId) ||
                    model.resultActions[c.owner!.id]?[entry.key] == null
                ? l.requireResult
                : const {
                        'result.aggregate',
                        'result.related',
                        'result.clone',
                      }.contains(entry.key) &&
                      model.backend == null
                ? l.retainedUnavailable
                : const {
                        'result.related',
                        'result.clone',
                      }.contains(entry.key) &&
                      live(c) != null
                ? live(c)
                : const {
                    'result.filter',
                    'result.sort',
                    'result.refresh',
                    'result.reset',
                  }.contains(entry.key)
                ? tableBusy(c)
                : null,
          ),
        action(
          'result.dispose',
          l.disposeResult,
          l.results,
          (c) => model.command(
            () => model.disposeRetainedResult(
              model.resultForOwner(c.owner!)!.resultId,
            ),
            ownerId: c.owner!.id,
          ),
          requirement: result,
        ),
        action(
          'transfer.import',
          l.importData,
          l.objectMenu,
          (c) => transfer(true, commandTarget: c),
          requirement: (c) => tableObject(c) ?? scopedLive(c),
        ),
        action(
          'transfer.retained',
          l.exportRetained,
          l.results,
          (c) => transfer(false, commandTarget: c),
          requirement: result,
        ),
        action(
          'transfer.sql',
          l.exportSql,
          l.runMenu,
          (c) => transfer(false, directExport: true, commandTarget: c),
          requirement: sql,
        ),
        action(
          'backup.dump',
          l.backup,
          l.connectionMenu,
          (c) => backup(false, commandTarget: c),
          requirement: scopedLive,
        ),
        action(
          'backup.restore',
          l.restore,
          l.connectionMenu,
          (c) => backup(true, commandTarget: c),
          requirement: scopedLive,
        ),
        for (final kind in [
          rpc.ToolKind.ACTIVITY,
          rpc.ToolKind.LOCKS,
          rpc.ToolKind.STATISTICS,
          rpc.ToolKind.QUERY_STATISTICS,
          rpc.ToolKind.INDEX_DIAGNOSTICS,
          rpc.ToolKind.ROLES,
          rpc.ToolKind.GRANTS,
          rpc.ToolKind.SNAPSHOT,
        ])
          action(
            'diagnostics.${kind.value}',
            '${toolLabel(kind)} — ${l.rawOutput}',
            l.connectionMenu,
            (c) => tool(kind, commandTarget: c),
            requirement: scopedLive,
          ),
      ],
      validateContext: (c) {
        if (c.virtualViewId != null) {
          final view = c.virtualView;
          if (view == null ||
              !identical(model.virtualViews[c.virtualViewId], view)) {
            throw StateError(l.staleContext);
          }
          final actual = model.profiles
              .where((p) => p.id == view.scope.profileId)
              .firstOrNull;
          final expected = c.virtualSource;
          rpc.Profile scoped(rpc.Profile p) =>
              p.deepCopy()..database = view.scope.catalog;
          if ((actual == null) != (expected == null) ||
              actual != null &&
                  !WorkbenchModel.sameConnectionTarget(
                    scoped(actual),
                    scoped(expected!),
                  )) {
            throw StateError(l.staleContext);
          }
        }
        if (c.metadataInstance == null) return;
        if (model.backend?.instanceId != c.metadataInstance) {
          throw StateError(l.staleContext);
        }
        for (final entry in c.metadataSources.entries) {
          final expected = entry.value,
              session = model.sessions[entry.value.sessionId];
          if (!model.profiles.any((p) => p.id == entry.key) ||
              model.explorerSessions[entry.key] != expected.sessionId ||
              session?.contextRevision.toInt() != expected.contextRevision ||
              session?.sessionRevision.toInt() != expected.sessionRevision) {
            throw StateError(l.staleContext);
          }
        }
      },
    );
  }

  String toolLabel(rpc.ToolKind kind) => workbenchToolLabel(context, kind);
  Future<void> invoke(String id, {WorkbenchCommandContext? target}) async {
    try {
      // Global source creation has no document destination, including when a
      // cached menu/palette outlives its former active tab. Other commands keep
      // their captured ownership and revision checks.
      final captured =
          const {
            'connection.new',
            'preferences',
            'view.start',
            'view.workbench',
          }.contains(id)
          ? const WorkbenchCommandContext()
          : target ?? model.focusedCommandContext;
      if (captured.owner != null &&
          !model.operationOwners.contains(captured.owner)) {
        throw StateError('Command owner closed; request a fresh action');
      }
      await model.commands!.invoke(id, captured);
    } catch (error) {
      model.updateStatus(connectionErrorText(error));
    }
  }

  DesktopMenuAction menuAction(
    WorkbenchCommand action,
    WorkbenchCommandContext target,
  ) => DesktopMenuAction(
    action.label,
    () => invoke(action.id, target: target),
    shortcut: action.shortcutLabel,
    disabledReason: action.disabledReason?.call(target),
    icon: action.id == 'connection.favorite'
        ? DesktopIcon.favorite
        : action.id == 'file.open'
        ? DesktopIcon.folder
        : action.id == 'file.new' || action.id.startsWith('sql.')
        ? DesktopIcon.query
        : action.id.startsWith('connection.')
        ? DesktopIcon.connection
        : action.id == 'view.explorer'
        ? DesktopIcon.sidebar
        : action.id == 'view.palette'
        ? DesktopIcon.search
        : action.id.startsWith('result.')
        ? DesktopIcon.table
        : DesktopIcon.tool,
    checked: action.id == 'connection.favorite'
        ? model.favoriteProfiles.contains(target.profileId)
        : null,
    destructive: action.id == 'connection.delete',
  );
  CapturedWorkbenchTarget? captureMetadataSearch(
    WorkbenchCommandContext context,
  ) {
    final profileId = context.profileId ?? context.owner?.profileId;
    final sessionId =
        model.explorerSessions[profileId] ??
        context.sessionId ??
        context.owner?.sessionId;
    if (sessionId == null || model.backend == null) return null;
    final owner = model.operationOwners
        .where((owner) => owner.sessionId == sessionId)
        .firstOrNull;
    if (owner == null) return null;
    return model.captureTarget(owner: owner);
  }

  void prepareActionSearch() {
    pendingActionTarget = model.focusedCommandContext;
    pendingActionFocus = FocusManager.instance.primaryFocus;
    pendingMetadataTarget = captureMetadataSearch(pendingActionTarget!);
    pendingExecutionTarget =
        pendingActionTarget!.owner != null && model.backend != null
        ? model.captureTarget(owner: pendingActionTarget!.owner)
        : null;
  }

  Future<void> palette([WorkbenchCommandContext? commandTarget]) async {
    if (sharedSearch.target == null) {
      openSharedSearch('actions', target: commandTarget);
      return;
    }
    if (settingsVisible) return;
    if (sharedSearch.target != null) {
      await closeActionSearch();
      return;
    }
  }

  void openSharedSearch(
    String category, {
    WorkbenchCommandContext? target,
    bool replacing = false,
    bool rebind = false,
  }) {
    if (settingsVisible) return;
    sharedSearch.invalidateFocusHandoff();
    if (rebind && sharedSearch.target != null) {
      closeActionSearch(restoreFocus: false);
    }
    if (sharedSearch.target == null) {
      sharedSearch.returnFocus =
          pendingActionFocus ?? FocusManager.instance.primaryFocus;
      final captured =
          target ?? pendingActionTarget ?? model.focusedCommandContext;
      pendingActionTarget = null;
      pendingActionFocus = null;
      sharedSearch.target = captured;
      sharedSearch.backend = model.backend;
      sharedSearch.objectsTarget = target == null
          ? pendingMetadataTarget ?? captureMetadataSearch(captured)
          : captureMetadataSearch(captured);
      pendingMetadataTarget = null;
      sqlSearchKey = GlobalKey<WorkbenchSqlSearchState>();
      objectSearchKey = GlobalKey<DatabaseObjectSearchState>();
      historySearchKey = GlobalKey<HistoryViewState>();
      searchHistory = null;
      sharedSearch.executionTarget =
          (target == null ? pendingExecutionTarget : null) ??
          (captured.owner != null && model.backend != null
              ? model.captureTarget(owner: captured.owner)
              : null);
      pendingExecutionTarget = null;
      sharedSearch.query.clear();
    }
    sharedSearch.error = '';
    try {
      if (category == 'objects') prepareObjectSearch(sharedSearch.target!);
      if (category == 'history') {
        if (sharedSearch.backend == null ||
            !identical(sharedSearch.backend, model.backend)) {
          throw StateError(strings(context).metadataContextChanged);
        }
        searchHistoryOwner = model.openTask(
          WorkbenchDocumentKind.administration,
          strings(context).history,
          purpose: 'search-history:${sharedSearch.backend!.instanceId}',
          activate: false,
          payload: GlobalToolData(GlobalToolKind.history),
        );
        searchHistory = searchHistoryOwner!.payload as GlobalToolData;
      }
    } catch (error) {
      sharedSearch.error = operationFailureSummary(
        error,
        locale: strings(context),
      );
    }
    setState(() {
      sharedSearch.category = category;
      sharedSearch.replacing = replacing;
    });
    sharedSearch.focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && sharedSearch.target != null) {
        sharedSearch.focus.requestFocus();
      }
    });
  }

  Future<bool> closeActionSearch({bool restoreFocus = true}) {
    if (!mounted || sharedSearch.target == null) {
      if (!mounted || !restoreFocus) sharedSearch.invalidateFocusHandoff();
      return sharedSearch.pendingClose ?? Future.value(false);
    }
    final revision = sharedSearch.invalidateFocusHandoff();
    final origin = sharedSearch.returnFocus;
    sharedSearch.returnFocus = null;
    try {
      setState(() => sharedSearch.target = null);
      if (!restoreFocus || origin == null || origin.context?.mounted != true) {
        return Future.value(true);
      }
      final capturedModel = model;
      final owner = model.activeOwner;
      final ownerVersion = owner.version;
      final backend = model.backend;
      final route = ModalRoute.of(context);
      bool current() =>
          mounted &&
          identical(model, capturedModel) &&
          sharedSearch.focusRevision == revision &&
          sharedSearch.target == null &&
          identical(model.activeOwner, owner) &&
          owner.version == ownerVersion &&
          identical(model.backend, backend) &&
          identical(ModalRoute.of(context), route) &&
          route?.isCurrent != false &&
          origin.context?.mounted == true;
      void restoreOriginFocus() {
        // The captured origin was primary. A scope must receive focus itself;
        // following its history can return to the closing palette descendant.
        if (origin is FocusScopeNode) {
          origin.requestScopeFocus();
        } else {
          origin.requestFocus();
        }
      }

      if (origin.canRequestFocus) {
        restoreOriginFocus();
        // A command can open a modal before the next frame. Capture its
        // intended return owner before pushing the modal route.
        FocusManager.instance.applyFocusChangesIfNeeded();
        return Future.value(current() && origin.hasFocus);
      }

      // Linux retains the Explorer beneath an excluded search sidebar. Its
      // row becomes requestable only when the search-close rebuild completes.
      // Keep an explicit owner outside that exclusion while observing this
      // required frame, so a newer focus request can cancel the handoff.
      final handoff = sharedSearch.closeFocus;
      if (handoff.context?.mounted != true || !handoff.canRequestFocus) {
        return Future.value(false);
      }
      handoff.requestFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      if (!current() || !handoff.hasPrimaryFocus) return Future.value(false);
      return sharedSearch.afterCloseFrame(() {
        try {
          if (!current() || !origin.canRequestFocus) return false;
          FocusManager.instance.applyFocusChangesIfNeeded();
          if (!current() || !handoff.hasPrimaryFocus) return false;
          restoreOriginFocus();
          FocusManager.instance.applyFocusChangesIfNeeded();
          return current() && origin.hasFocus;
        } catch (error) {
          if (mounted) model.updateStatus(connectionErrorText(error));
          return false;
        }
      });
    } catch (error) {
      // Close callbacks are also used without awaiting their result.
      if (mounted) model.updateStatus(connectionErrorText(error));
      return Future.value(false);
    }
  }

  Future<void> activateSearchCommand(String id) async {
    final target = sharedSearch.target;
    if (target == null) return;
    final capturedModel = model;
    final owner = model.activeOwner;
    final ownerVersion = owner.version;
    final backend = model.backend;
    final route = ModalRoute.of(context);
    final origin = sharedSearch.returnFocus;
    final executionTarget = sharedSearch.executionTarget;
    final requiresTarget = !const {
      'connection.new',
      'preferences',
      'view.start',
      'view.workbench',
    }.contains(id);
    try {
      if (requiresTarget && executionTarget != null) {
        model.requireTarget(executionTarget, text: true);
      }
      final closing = closeActionSearch();
      final revision = sharedSearch.focusRevision;
      bool current() =>
          mounted &&
          identical(model, capturedModel) &&
          sharedSearch.focusRevision == revision &&
          sharedSearch.target == null &&
          identical(model.activeOwner, owner) &&
          owner.version == ownerVersion &&
          identical(model.backend, backend) &&
          identical(ModalRoute.of(context), route) &&
          route?.isCurrent != false &&
          (origin == null || origin.hasPrimaryFocus);
      if (!await closing || !current()) return;
      if (requiresTarget && executionTarget != null) {
        model.requireTarget(executionTarget, text: true);
      }
      FocusManager.instance.applyFocusChangesIfNeeded();
      if (!current()) return;
      await invoke(id, target: target);
    } catch (error) {
      model.updateStatus(connectionErrorText(error));
    }
  }

  Future<ConnectionCredentials?> credentials(rpc.Profile profile) async {
    final l = strings(context);
    String? stored, storedTls;
    final needsTlsKey =
        profile.tls.mode != rpc.TlsMode.DISABLED &&
        profile.tls.mode != rpc.TlsMode.DRIVER_DEFAULT &&
        profile.tls.clientKey.isNotEmpty;
    bool storageUnavailable = false;
    if (profile.credentialRef.isNotEmpty) {
      try {
        stored = await model.secrets.read(profile.credentialRef);
      } catch (_) {
        storageUnavailable = true;
      }
    }
    if (needsTlsKey && profile.tls.keyCredentialRef.isNotEmpty) {
      try {
        storedTls = await model.secrets.read(profile.tls.keyCredentialRef);
      } catch (_) {
        storageUnavailable = true;
      }
    }
    if (!mounted) return null;
    final needsSshPassword =
        profile.ssh.enabled &&
        !profile.ssh.agent &&
        profile.ssh.privateKey.isEmpty;
    final needsPassphrase =
        profile.ssh.enabled &&
        !profile.ssh.agent &&
        profile.ssh.privateKey.isNotEmpty;
    if (stored != null &&
        !needsSshPassword &&
        !needsPassphrase &&
        (!needsTlsKey || storedTls != null)) {
      return ConnectionCredentials(
        password: stored,
        tlsKeyPassword: storedTls ?? '',
      );
    }
    final password = TextEditingController(),
        sshPassword = TextEditingController(),
        passphrase = TextEditingController(),
        tlsPassword = TextEditingController();
    try {
      return await ui.dialog<ConnectionCredentials>(
        context,
        '${l.connect} · ${profile.name}',
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (storageUnavailable) Text(l.connectionStorageUnavailable),
            if (stored == null) ui.field(password, l.password, secret: true),
            if (needsSshPassword)
              ui.field(sshPassword, l.sshPassword, secret: true),
            if (needsPassphrase)
              ui.field(passphrase, l.keyPassphrase, secret: true),
            if (needsTlsKey && storedTls == null)
              ui.field(tlsPassword, l.clientKeyPasswordLabel, secret: true),
          ],
        ),
        [
          ui.button(l.cancel, () => Navigator.of(context).pop()),
          ui.button(
            l.connect,
            () => Navigator.of(context).pop(
              ConnectionCredentials(
                password: stored ?? password.text,
                sshPassword: sshPassword.text,
                keyPassphrase: passphrase.text,
                tlsKeyPassword: storedTls ?? tlsPassword.text,
              ),
            ),
            primary: true,
          ),
        ],
      );
    } finally {
      for (final field in [password, sshPassword, passphrase, tlsPassword]) {
        field.clear();
        field.dispose();
      }
    }
  }

  Future<void> ensureSqlSession(SqlDocument document) async {
    if (document.sessionId != null) {
      final session = model.sessions[document.sessionId];
      if (session == null ||
          [
            rpc.TransactionState.UNKNOWN_TRANSACTION,
            rpc.TransactionState.DISCONNECTED,
          ].contains(session.transaction)) {
        throw StateError(
          'The owned session is unavailable or uncertain; inspect and explicitly resolve it before reconnecting. SQL was not replayed.',
        );
      }
      return;
    }
    if (model
        .jobsForOwner(
          model.workbenchDocuments.firstWhere((d) => d.id == document.id),
        )
        .any((job) => job.state == rpc.JobState.UNKNOWN_OUTCOME)) {
      throw StateError(
        'The previous operation outcome is unknown; inspect it and explicitly resolve the connection before running again.',
      );
    }
    final backend = model.backend!;
    final owner = model.workbenchDocuments.firstWhere(
      (d) => d.id == document.id,
    );
    final captured = model.captureTarget(owner: owner);
    final intendedScope = (
      document.connectionCatalog,
      document.connectionSchema,
    );
    final profile = model.profiles
        .where((p) => p.id == document.profileId)
        .firstOrNull
        ?.deepCopy();
    if (profile == null) {
      throw StateError(
        'Choose a saved connection for this query before running',
      );
    }
    model.requireDocumentTarget(owner, profile);
    final secret = await credentials(profile);
    if (secret == null) throw StateError('Connection cancelled; SQL preserved');
    model.requireTarget(captured, profile: true, text: true);
    if (intendedScope !=
        (document.connectionCatalog, document.connectionSchema)) {
      throw StateError('Query context changed; request a fresh execution');
    }
    await model.connect(
      profile,
      secret.password,
      sshPassword: secret.sshPassword,
      keyPassphrase: secret.keyPassphrase,
      tlsKeyPassword: secret.tlsKeyPassword,
      targetDocument: document,
      expectedBackend: backend,
      mayAdopt: () {
        if (!mounted) return false;
        try {
          model.requireTarget(captured, profile: true, text: true);
          return intendedScope ==
              (document.connectionCatalog, document.connectionSchema);
        } catch (_) {
          return false;
        }
      },
    );
  }

  Future<void> connectContext(WorkbenchCommandContext c) async {
    final profile = model.profiles
        .where((p) => p.id == c.profileId)
        .firstOrNull
        ?.deepCopy();
    if (profile == null) {
      await connections();
      return;
    }
    final backend = model.backend!;
    final captured = c.owner == null
        ? null
        : model.captureTarget(owner: c.owner);
    final secret = await credentials(profile);
    if (secret == null) return;
    if (!identical(model.backend, backend)) {
      throw StateError('Backend changed; request a fresh connection');
    }
    if (captured != null) model.requireTarget(captured, profile: true);
    final current = model.profiles.where((p) => p.id == profile.id).firstOrNull;
    if (current == null ||
        !WorkbenchModel.sameConnectionTarget(profile, current)) {
      throw StateError(
        'The saved connection changed; request a fresh connection',
      );
    }
    if (c.owner?.sql != null) {
      await model.connect(
        profile,
        secret.password,
        sshPassword: secret.sshPassword,
        keyPassphrase: secret.keyPassphrase,
        tlsKeyPassword: secret.tlsKeyPassword,
        targetDocument: c.owner!.sql,
        expectedBackend: backend,
      );
    } else if (c.owner != null) {
      await model.connect(
        profile,
        secret.password,
        sshPassword: secret.sshPassword,
        keyPassphrase: secret.keyPassphrase,
        tlsKeyPassword: secret.tlsKeyPassword,
        targetOwner: c.owner,
        expectedBackend: backend,
      );
    } else {
      await model.connectExplorer(
        profile,
        secret.password,
        sshPassword: secret.sshPassword,
        keyPassphrase: secret.keyPassphrase,
        tlsKeyPassword: secret.tlsKeyPassword,
      );
    }
  }

  Future<void> shareSession({WorkbenchDocument? owner}) async {
    final initiatingOwner = owner ?? model.activeOwner, l = strings(context);
    final document = initiatingOwner.sql!;
    final initiatingTarget = model.captureTarget(owner: initiatingOwner);
    if (document.sessionId != null) {
      throw StateError(
        'Disconnect this query before explicitly sharing a session',
      );
    }
    final candidates = model.sessions.values
        .where(
          (s) =>
              s.transaction != rpc.TransactionState.UNKNOWN_TRANSACTION &&
              s.transaction != rpc.TransactionState.DISCONNECTED &&
              !model.operationOwners.any(
                (o) =>
                    o.sessionId == s.sessionId &&
                    model.closingDocuments.contains(o.id),
              ),
        )
        .map((s) => s.deepCopy())
        .toList();
    if (candidates.isEmpty) throw StateError(l.requireSession);
    final selected = await ui.dialog<String>(
      context,
      l.sessionSharing,
      WorkbenchDialogBody(
        maxHeight: 260,
        child: ListView(
          children: [
            for (final session in candidates)
              WorkbenchRecord(
                controls: ui,
                label:
                    '${session.profile.name} · ${workbenchEnvironment(context, session.profile.environment)} · ${session.sessionId} · ${workbenchSessionState(context, session)} · ${model.operationOwners.where((o) => o.sessionId == session.sessionId).map((o) => documentName(context, model, o)).join(', ')}',
                selected: session.sessionId == document.sessionId,
                onPressed: () => Navigator.of(context).pop(session.sessionId),
                child: Text(
                  '${session.profile.name} · ${workbenchEnvironment(context, session.profile.environment)} · ${session.sessionId} · ${workbenchSessionState(context, session)} · ${model.operationOwners.where((o) => o.sessionId == session.sessionId).map((o) => documentName(context, model, o)).join(', ')}',
                ),
              ),
          ],
        ),
      ),
      [ui.button(l.cancel, () => Navigator.of(context).pop())],
      bodyScrolls: true,
    );
    if (!mounted || selected == null) return;
    model.requireTarget(initiatingTarget, text: true);
    final capturedSession = model.captureSessionTarget(selected);
    final clients = model.operationOwners
        .where((o) => o.sessionId == selected)
        .map((o) => documentName(context, model, o))
        .join(', ');
    final review =
        '${workbenchTargetDescription(context, capturedSession)}\n${l.ownedSessions}: $clients\n${l.sharingSessionReview}';
    if (!await confirm(l.sessionSharing, review)) return;
    model.requireTarget(initiatingTarget, text: true);
    model.requireTarget(capturedSession);
    model.shareSession(document, selected);
  }

  Future<void> executionOptions(WorkbenchDocument owner) async {
    final l = strings(context),
        rows = TextEditingController(
          text: '${owner.view.rowLimit ?? model.defaultRowLimit}',
        );
    var streaming = owner.view.streaming;
    var continueErrors =
        owner.view.errorPolicy == rpc.ErrorPolicy.CONTINUE_ON_ERROR;
    try {
      final accepted = await ui.dialog<bool>(
        context,
        l.executionOptions,
        StatefulBuilder(
          builder: (context, set) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ui.field(rows, l.resultRowLimit),
              ui.choice(streaming, {
                false: l.boundedRead,
                true: l.streamingRead,
              }, (v) => set(() => streaming = v)),
              ui.choice(continueErrors, {
                false: l.stopOnError,
                true: l.continueOnError,
              }, (v) => set(() => continueErrors = v)),
            ],
          ),
        ),
        [
          ui.button(l.cancel, () => Navigator.of(context).pop(false)),
          ui.button(l.executionOptions, () => Navigator.of(context).pop(true)),
        ],
      );
      if (accepted != true) return;
      if (!model.workbenchDocuments.contains(owner)) {
        throw StateError('The document was closed; settings were not applied');
      }
      final limit = int.tryParse(rows.text);
      if (limit == null || limit < 1 || limit > 1000000) {
        throw StateError(l.resultRowLimit);
      }
      owner.view.rowLimit = limit;
      owner.view.streaming = streaming;
      owner.view.errorPolicy = continueErrors
          ? rpc.ErrorPolicy.CONTINUE_ON_ERROR
          : rpc.ErrorPolicy.STOP_ON_ERROR;
      await model.savePresentation();
      model.updateStatus(l.executionOptions);
    } finally {
      rows.dispose();
    }
  }

  Future<void> sessionDetails(WorkbenchCommandContext c) async {
    final session = model.sessions[c.sessionId];
    if (session == null) {
      model.updateStatus(strings(context).notConnected);
      return;
    }
    await ui.dialog<void>(
      context,
      strings(context).sessionDetails,
      SelectableText(
        '${session.profile.name} · ${workbenchEnvironment(context, session.profile.environment)}\n${session.database.product} ${session.database.version}\n'
        '${session.profile.host}:${session.profile.port}\n${strings(context).liveCatalogLabel}: ${session.currentCatalog}\n${strings(context).liveSchemaLabel}: ${session.currentSchema}\n'
        '${strings(context).searchPathLabel}: ${session.searchPath.join(', ')}\n${strings(context).physicalSessionLabel}: ${session.sessionId}\n'
        '${workbenchSessionState(context, session)}\n'
        '${strings(context).queryTimeoutDetail('${session.profile.queryTimeoutSeconds}', '${c.owner?.view.rowLimit ?? model.defaultRowLimit}')}\n'
        '${session.profile.readOnly ? strings(context).readOnlyPolicy : ''}',
      ),
      [ui.button(strings(context).cancel, () => Navigator.of(context).pop())],
    );
  }

  Future<void> searchObjects(WorkbenchCommandContext c) async =>
      openSharedSearch('objects', target: c, rebind: true);

  void prepareObjectSearch(WorkbenchCommandContext c) {
    final profile = model.profiles
        .where((p) => p.id == c.profileId)
        .firstOrNull;
    if (profile == null) {
      throw StateError(
        'Choose a connection in Database Explorer before searching',
      );
    }
    final captured = sharedSearch.objectsTarget;
    if (captured == null) throw StateError(strings(context).noConnection);
    model.requireTarget(captured);
    final sessionId = captured.sessionId;
    searchInspectionOwner = model.openTask(
      WorkbenchDocumentKind.structure,
      strings(context).searchObjects,
      activate: false,
      profileId: profile.id,
      purpose:
          'search:${captured.backend.instanceId}:$sessionId:${captured.contextRevision}:${captured.sessionRevision}:${jsonEncode([c.object?.catalog ?? c.creationScope?.catalog ?? '', c.object?.schema ?? c.creationScope?.schema ?? ''])}',
      payload: ObjectSearchData(
        profile.id,
        captured,
        catalog: c.object?.catalog ?? c.creationScope?.catalog ?? '',
        schema: c.object?.schema ?? c.creationScope?.schema ?? '',
      ),
    );
  }

  Future<ResolvedWorkbenchObject?> selectedBrowseObject(
    WorkbenchCommandContext command,
  ) async {
    final logical = command.object;
    final selected = logical == null
        ? await sqlSymbolTarget(command)
        : ResolvedWorkbenchObject(
            logical,
            BrowseSelectionEvidence.fromCommand(model, command, logical),
          );
    if (selected != null &&
        ![
          rpc.ObjectKind.TABLE,
          rpc.ObjectKind.VIEW,
        ].contains(selected.object.kind)) {
      throw const LocalWorkbenchFailure(WorkbenchFailureReason.unsupported);
    }
    return selected;
  }

  Future<void> openObject(
    WorkbenchCommandContext c, {
    required bool data,
  }) async {
    final selected = data ? await selectedBrowseObject(c) : null;
    if (data && selected == null) return;
    final object = selected?.object ?? c.object!;
    final existing = model.taskDocuments.toSet();
    final owner = model.openTask(
      [rpc.ObjectKind.TABLE, rpc.ObjectKind.VIEW].contains(object.kind)
          ? WorkbenchDocumentKind.table
          : WorkbenchDocumentKind.structure,
      object.displayNameFor(model.sessions[c.sessionId]?.profile.engine),
      object: object,
      evidenceProfile: model.sessions[c.sessionId]?.profile,
    );
    if (data && selected!.evidence != null) {
      BrowseSelectionController(model).attachSelectedSession(
        owner,
        selected.evidence!,
        newlyCreated: !existing.contains(owner),
      );
    }
    owner.evidenceProfile ??= model.sessions[c.sessionId]?.profile.deepCopy();
    owner.view.subview = data ? 'data' : 'structure';
    owner.view.metadataRequested = !data;
    if (!data &&
        owner.sessionId == null &&
        model.explorerSessions[owner.profileId] == null) {
      await connectContext(
        WorkbenchCommandContext(
          owner: owner,
          object: owner.object,
          profileId: owner.profileId,
        ),
      );
    }
    if (data &&
        !model.jobs.values.any(
          (j) => model.jobDocuments[j.jobId] == owner.id,
        )) {
      await model.command(
        () => browseObject(owner, selectionEvidence: selected?.evidence),
        ownerId: owner.id,
        errorText: connectionErrorText,
      );
    }
  }

  Future<void> browseObject(
    WorkbenchDocument owner, {
    List<rpc.RowCondition>? conditions,
    List<rpc.RowOrder>? order,
    BrowseSelectionEvidence? selectionEvidence,
  }) async {
    if (owner.view.acquiringData) return;
    final connectionLabels = strings(context);
    owner.view.acquiringData = true;
    owner.view.dataError = '';
    model.updateStatus(strings(context).loading);
    try {
      if (owner.sessionId == null &&
          model
              .jobsForOwner(owner)
              .any((job) => job.state == rpc.JobState.UNKNOWN_OUTCOME)) {
        throw StateError(
          'The previous table operation outcome is unknown; explicitly resolve the connection before retrying.',
        );
      }
      if (model.editBatches.values.any(
        (b) => b.ownerId == owner.id && b.changes.isNotEmpty,
      )) {
        throw StateError(
          'Review, preserve or discard this table’s pending changes before replacing its data snapshot',
        );
      }
      final c = WorkbenchCommandContext(
        owner: owner,
        object: owner.object,
        profileId: owner.profileId,
        sessionId: owner.sessionId,
      );
      if (owner.sessionId == null) await connectContext(c);
      if (owner.sessionId == null) {
        throw StateError('Connection cancelled; table data can be retried');
      }
      final session = model.sessions[owner.sessionId];
      if (session == null ||
          [
            rpc.TransactionState.DISCONNECTED,
            rpc.TransactionState.UNKNOWN_TRANSACTION,
          ].contains(session.transaction)) {
        throw StateError(
          'The owned table session is unavailable or uncertain; resolve it explicitly before retrying',
        );
      }
      final captured = model.captureTarget(owner: owner);
      final previousExecution = model.jobForOwner(owner)?.executionId;
      final originalConditions = owner.view.tableConditions
          .map((value) => value.deepCopy())
          .toList();
      final originalOrder = owner.view.tableOrder
          .map((value) => value.deepCopy())
          .toList();
      final selectedConditions = (conditions ?? originalConditions)
          .map((value) => value.deepCopy())
          .toList();
      final selectedOrder = (order ?? originalOrder)
          .map((value) => value.deepCopy())
          .toList();
      final selectedLimit = owner.view.rowLimit ?? model.defaultRowLimit;
      bool replacementCurrent() =>
          !model.editBatches.values.any(
            (batch) => batch.ownerId == owner.id && batch.changes.isNotEmpty,
          ) &&
          listEquals(owner.view.tableConditions, originalConditions) &&
          listEquals(owner.view.tableOrder, originalOrder) &&
          (owner.view.rowLimit ?? model.defaultRowLimit) == selectedLimit;
      final selectionRevision = owner.view.executionSelectionRevision;
      final selection = await BrowseSelectionController(model).prepare(
        captured,
        owner.object!,
        evidence: selectionEvidence,
        current: replacementCurrent,
      );
      final request = selection.request(
        model,
        executionId: const Uuid().v4(),
        rowLimit: Int64(selectedLimit),
        conditions: selectedConditions,
        order: selectedOrder,
      );
      final review = await model.ownedRequest(
        captured,
        () => captured.backend.client.reviewBrowse(request),
      );
      selection.requireCurrent(model);
      if (!mounted) return;
      if (review.risks.isNotEmpty &&
          !await confirm(
            strings(context).openData,
            '${workbenchTargetDescription(context, captured)}\n${review.risks.join('\n')}\n${review.statements.join('\n')}\n${request.conditions.map((c) => '${c.column} ${workbenchPredicate(context, c.predicate)} ${valueText(c.value)}').join('\n')}\n${request.order.map((o) => '${o.column} ${o.descending ? strings(context).descending : strings(context).ascending}').join('\n')}',
          )) {
        return;
      }
      selection.requireCurrent(model);
      request.approvalToken = review.token;
      model.submissions[request.executionId] = owner.id;
      final job = await model.ownedRequest(
        captured,
        () => captured.backend.client.browse(request),
      );
      if (identical(model.backend, captured.backend)) {
        final query = TableQueryState(request.conditions, request.order);
        owner.view.tableQueries[request.executionId] = query;
        while (owner.view.tableQueries.length > 32) {
          owner.view.tableQueries.remove(owner.view.tableQueries.keys.first);
        }
        owner.view.tableConditions = query.conditions;
        owner.view.tableOrder = query.order;
        if (previousExecution != null) {
          model.selectedExecutions[owner.id] = previousExecution;
          model.browseReplacements[owner.id] = (
            execution: request.executionId,
            previous: previousExecution,
            selectionRevision: selectionRevision,
          );
        } else {
          model.selectedExecutions.remove(owner.id);
        }
        model.track(job, documentId: owner.id);
      }
    } catch (error) {
      owner.view.dataError = operationFailureSummary(
        error,
        locale: connectionLabels,
      );
      rethrow;
    } finally {
      owner.view.acquiringData = false;
      if (!model.isDisposed) {
        model.updateStatus(
          owner.view.dataError.isEmpty
              ? owner.displayTitle
              : owner.view.dataError,
        );
      }
    }
  }

  Future<void> capabilities({WorkbenchCommandContext? target}) async {
    final c = target ?? model.commandContext;
    if (c.sessionId == null) {
      throw StateError('Connect before inspecting capabilities');
    }
    final owner = model.openTask(
      WorkbenchDocumentKind.administration,
      strings(context).connectionCapabilities,
      profileId: c.profileId,
      payload: null,
    );
    owner.sessionId = c.sessionId;
    final captured = model.captureTarget(owner: owner);
    owner.payload = AdministrationData(captured);
    owner.reopenCommandId = 'connection.capabilities';
    model.updateStatus(owner.displayTitle);
  }

  Future<void> activityAction(
    bool terminate, {
    WorkbenchCommandContext? target,
  }) async {
    final c = target ?? model.commandContext;
    if (c.sessionId == null) {
      throw StateError('Connect before inspecting activities');
    }
    final owner = model.openTask(
      WorkbenchDocumentKind.administration,
      strings(context).sessionsAndLocks,
      profileId: c.profileId,
    );
    owner.sessionId = c.sessionId;
    final captured = model.captureTarget(owner: owner);
    owner.payload = AdministrationData(
      captured,
      activities: true,
      activityAction: (activity, terminate) async {
        final request = rpc.ToolRequest(
          context: captured.backend.context(),
          sessionId: captured.sessionId,
          executionId: const Uuid().v4(),
          kind: terminate
              ? rpc.ToolKind.TERMINATE_ACTIVITY
              : rpc.ToolKind.CANCEL_ACTIVITY,
          targetId: activity.id,
          activityFingerprint: activity.fingerprint,
        );
        model.requireTarget(captured);
        final approval = await captured.backend.client.reviewToolAdmission(
          request,
        );
        if (!mounted) return;
        model.requireTarget(captured);
        if (!await confirm(
          strings(context).reviewDetails,
          '${workbenchTargetDescription(context, captured)}\n${activity.principal} · ${activity.database}\n${activity.queryPreview}\n${strings(context).activityFingerprintNote}',
          actionLabel: terminate
              ? strings(context).terminateSelectedSession
              : strings(context).cancelSelectedActivity,
        )) {
          return;
        }
        request.approvalToken = approval.token;
        await model.submitTool(captured, request);
      },
    );
    owner.reopenCommandId = 'connection.activity';
    model.updateStatus(owner.displayTitle);
  }

  Future<void> profile({
    rpc.Profile? initial,
    WorkbenchDocument? queryDestination,
    ConnectionManagementInvocation invocation =
        ConnectionManagementInvocation.createSource,
  }) async {
    // Only the query selector and explicit SQL-context edit supply an owner.
    // Global creation keeps every existing document's target intact.
    final destination = queryDestination;
    var captured = destination == null
        ? null
        : model.captureTarget(owner: destination);
    var scope = (
      destination?.sql?.connectionCatalog,
      destination?.sql?.connectionSchema,
    );
    final backend = model.backend!;
    await ui.formDialog<void>(
      context,
      (_) => ConnectionForm(
        model: model,
        controls: ui,
        initial: initial,
        reviewHost: (title, body) => confirm(title, body),
        connect: (saved, secrets, current) async {
          if (!current() || !identical(model.backend, backend)) return;
          if (destination != null) {
            // Saving this form intentionally updates its configuration. Keep
            // fencing the captured owner/SQL rather than rejecting our own
            // acknowledged saved settings on a correction/retry.
            model.requireTarget(captured!, text: true);
            if (scope !=
                (
                  destination.sql?.connectionCatalog,
                  destination.sql?.connectionSchema,
                )) {
              throw StateError(
                'The initiating query context changed; choose its target again.',
              );
            }
            if (destination.sessionId == null) {
              model.bindUnconnectedProfile(destination, saved.id);
              captured = model.captureTarget(owner: destination);
              scope = (
                destination.sql?.connectionCatalog,
                destination.sql?.connectionSchema,
              );
            }
            bool destinationCurrent() {
              return current() &&
                  scope ==
                      (
                        destination.sql?.connectionCatalog,
                        destination.sql?.connectionSchema,
                      );
            }

            final previousSession = destination.sessionId;
            await model.connect(
              saved,
              secrets.password,
              sshPassword: secrets.sshPassword,
              keyPassphrase: secrets.keyPassphrase,
              tlsKeyPassword: secrets.tlsKeyPassword,
              targetOwner: destination,
              expectedBackend: backend,
              intendedTarget: captured,
              mayAdopt: destinationCurrent,
            );
            if (!model.operationOwners.contains(destination) ||
                destination.profileId != saved.id ||
                destination.sessionId == null ||
                destination.sessionId == previousSession) {
              throw StateError(
                'The initiating query changed or closed. Choose its saved connection explicitly to continue.',
              );
            }
          } else {
            await model.connectExplorer(
              saved,
              secrets.password,
              sshPassword: secrets.sshPassword,
              keyPassphrase: secrets.keyPassphrase,
              tlsKeyPassword: secrets.tlsKeyPassword,
              mayAdopt: current,
            );
            if (!current()) return;
            if (invocation == ConnectionManagementInvocation.createSource) {
              // Creation never commandeers an intentional blank or restored draft.
              model.newDocument();
              model.bindUnconnectedProfile(model.activeOwner, saved.id);
            }
          }
        },
      ),
    );
  }

  Future<void> disconnectPhysicalSession(String id) async {
    final target = model.captureSessionTarget(id);
    final l = strings(context);
    final clients = model.operationOwners
        .where((owner) => owner.sessionId == id)
        .map((owner) => owner.displayTitle)
        .join(', ');
    final review =
        '${workbenchTargetDescription(context, target)}\n${l.ownedSessions}: $clients\n${l.disconnectSessionNote}';
    if (!await confirm(l.disconnect, review, actionLabel: l.disconnect)) return;
    model.requireTarget(target);
    await model.command(
      () => model.disconnectRetainedSession(id, reviewedTarget: target),
      ownerId: target.ownerId,
    );
  }

  Future<void> connections() async {
    await ui.dialog<void>(
      context,
      strings(context).ownedSessions,
      WorkbenchDialogBody(
        maxHeight: 340,
        child: ListenableBuilder(
          listenable: model,
          builder: (_, _) {
            final sessions = model.sessions.values.toList();
            final originalOrder = model.sessions.keys.toList();
            int priority(rpc.SessionInfo session) =>
                switch (session.transaction) {
                  rpc.TransactionState.UNKNOWN_TRANSACTION => 0,
                  rpc.TransactionState.FAILED_TRANSACTION => 1,
                  rpc.TransactionState.ACTIVE => 2,
                  _ => 3,
                };
            sessions.sort((a, b) {
              final attention = priority(a).compareTo(priority(b));
              return attention != 0
                  ? attention
                  : originalOrder
                        .indexOf(a.sessionId)
                        .compareTo(originalOrder.indexOf(b.sessionId));
            });
            return ListView(
              children: [
                for (final live in sessions)
                  Padding(
                    key: ValueKey('owned-session:${live.sessionId}'),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${live.profile.name} · ${live.sessionId} · ${workbenchEnvironment(context, live.profile.environment)} · ${live.currentCatalog}/${live.currentSchema} · ${workbenchSessionState(context, live)}',
                        ),
                        Text(
                          model.operationOwners
                              .where((doc) => doc.sessionId == live.sessionId)
                              .map((doc) => documentName(context, model, doc))
                              .join(', '),
                        ),
                        if (live.transaction ==
                            rpc.TransactionState.UNKNOWN_TRANSACTION)
                          Text(strings(context).outcomeUnknownNote),
                        ui.textButton(
                          strings(context).disconnect,
                          () => invoke(
                            'connection.disconnect',
                            target: WorkbenchCommandContext(
                              profileId: live.profile.id,
                              sessionId: live.sessionId,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      [ui.button(strings(context).close, () => Navigator.of(context).pop())],
      bodyScrolls: true,
    );
  }

  Future<void> recoverEdits() async {
    final sqlOwner = model.activeOwner.sql, process = model.backend!;
    await model.refreshEditDrafts();
    if (!mounted) return;
    if (!identical(model.backend, process)) {
      throw StateError(strings(context).metadataContextChanged);
    }
    model.openTask(
      WorkbenchDocumentKind.structure,
      strings(context).recoverEdits,
      payload: RecoveryDocumentData(
        sqlOwner,
        (draft) => model.rebindEditDraft(draft, targetDocument: sqlOwner),
        (draft) async {
          final captured = draft.deepCopy(), l = strings(context);
          if (!identical(model.backend, process)) {
            throw StateError(l.metadataContextChanged);
          }
          final target = captured.target;
          final review =
              '${target.name} · ${workbenchEnvironment(context, target.environment)} · ${target.host}:${target.port}/${target.database}\n${captured.schema}.${captured.table} · ${l.changes}: ${captured.changes} · ${workbenchDraftState(context, captured.state)}\n${l.recoveryDiscardReview}';
          if (!await confirm(
            l.discardRecoveryRecord,
            review,
            destructive: true,
          )) {
            return;
          }
          await model.discardRecoveryRecord(captured, process: process);
        },
      ),
      reuse: false,
    );
  }

  Future<void> retainedResults() async {
    model.showGlobalTool(
      WorkbenchDocument(
        id: 'global:results',
        kind: WorkbenchDocumentKind.administration,
        title: strings(context).retainedResults,
        payload: GlobalToolData(GlobalToolKind.retained),
      ),
    );
  }

  Future<void> history() async {
    model.showGlobalTool(
      WorkbenchDocument(
        id: 'global:history',
        kind: WorkbenchDocumentKind.administration,
        title: strings(context).history,
        payload: GlobalToolData(GlobalToolKind.history),
      ),
    );
  }

  Future<void> edit(
    rpc.ChangeKind kind, {
    WorkbenchCommandContext? commandTarget,
  }) async {
    final l = strings(context);
    final targetDocument = ownerFor(commandTarget ?? model.commandContext);
    final result = model.resultForOwner(targetDocument);
    final batch = model.batchFor(targetDocument, result?.resultId ?? '');
    final targetBackend = model.backend;
    final targetSession = targetDocument.sessionId;
    final displayed = model.displayResultForOwner(targetDocument);
    if (result == null || result.columns.isEmpty) return;
    final tables = result.columns
        .map((c) => '${c.catalog}\u0000${c.schema}\u0000${c.table}')
        .toSet();
    if (tables.length != 1 ||
        result.columns.first.table.isEmpty ||
        result.columns.any((c) => !c.provenanceKnown || c.baseColumn.isEmpty)) {
      model.updateStatus(
        'Editing requires columns belonging to one base table; joins and expressions are not editable.',
      );
      return;
    }
    final selectedRow = model
        .resultView(displayed!.resultId, owner: targetDocument)
        .selectedRow;
    final row = model.row(displayed.resultId, selectedRow);
    final targetSchema = result.columns.first.schema.isEmpty
        ? result.columns.first.catalog
        : result.columns.first.schema;
    if (batch.changes.isNotEmpty &&
        (batch.sessionId != targetSession ||
            batch.resultId != result.resultId ||
            batch.schema != targetSchema ||
            batch.table != result.columns.first.table)) {
      model.updateStatus(
        'Apply or discard the existing staged edits before editing a different session or table.',
      );
      return;
    }
    if (kind != rpc.ChangeKind.INSERT && row == null) return;
    final sourceRow = model.sourceRow(displayed.resultId, selectedRow);
    final captured = model.captureTarget(owner: targetDocument);
    final evidence = await model.ownedRequest(
      captured,
      () => captured.backend.client.assessEditability(
        rpc.ChangeRequest(
          context: captured.backend.context(),
          sessionId: targetSession,
          resultId: result.resultId,
          schema: targetSchema,
          table: result.columns.first.table,
        ),
      ),
    );
    model.requireTarget(captured);
    if (!evidence.editable) throw StateError(evidence.reason);
    final metadata = await model.readMetadata(
      captured,
      rpc.ExploreRequest(
        context: captured.backend.context(),
        sessionId: targetSession,
        kind: rpc.ObjectKind.COLUMN,
        catalog: result.columns.first.catalog,
        schema: result.columns.first.schema,
        table: result.columns.first.table,
      ),
    );
    model.requireTarget(captured);
    if (result.columns.any(
      (column) => !metadata.objects.any(
        (m) =>
            m.name == column.baseColumn &&
            ['YES', 'NO'].contains(m.properties['generated']) &&
            ['YES', 'NO'].contains(m.properties['autoIncrement']),
      ),
    )) {
      throw StateError(
        'Complete generated-column metadata is required before staging edits',
      );
    }
    final generated = metadata.objects
        .where(
          (column) =>
              column.properties['generated'] == 'YES' ||
              column.properties['autoIncrement'] == 'YES',
        )
        .map((column) => column.name)
        .toSet();
    if (!mounted) return;
    final assignments = [
      for (var i = 0; i < result.columns.length; i++)
        kind == rpc.ChangeKind.INSERT
            ? 'unset'
            : row!.values[i].hasNullValue()
            ? 'null'
            : 'value',
    ];
    final values = [
      for (final c in result.columns)
        TextEditingController(
          text: kind == rpc.ChangeKind.INSERT
              ? ''
              : valueText(row!.values[result.columns.indexOf(c)]),
        ),
    ];
    var stagedRevision = batch.revision;
    int? provisionalInsertIndex;
    var dialogOpen = true;
    final saving = ValueNotifier(false),
        draftError = ValueNotifier<String?>(null);
    try {
      await ui.dialog<void>(
        context,
        '${switch (kind) {
          rpc.ChangeKind.INSERT => strings(context).stageInsert,
          rpc.ChangeKind.DELETE => strings(context).stageDelete,
          _ => strings(context).stageUpdate,
        }} · ${result.columns.first.table}',
        StatefulBuilder(
          builder: (_, set) => ValueListenableBuilder<bool>(
            valueListenable: saving,
            builder: (_, busy, _) => SizedBox(
              height: 350,
              child: Column(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: draftError,
                    builder: (_, error, _) => error == null
                        ? const SizedBox.shrink()
                        : ui.status(error, error: true),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (int i = 0; i < result.columns.length; i++) ...[
                          ui.field(
                            values[i],
                            '${result.columns[i].name} · ${result.columns[i].typeName}',
                            enabled:
                                !busy &&
                                kind != rpc.ChangeKind.DELETE &&
                                !generated.contains(
                                  result.columns[i].baseColumn,
                                ) &&
                                !result.columns[i].readOnly &&
                                assignments[i] == 'value',
                          ),
                          if (generated.contains(
                                result.columns[i].baseColumn,
                              ) ||
                              result.columns[i].readOnly)
                            Text(strings(context).readonlyCell)
                          else if (kind != rpc.ChangeKind.DELETE)
                            ui.choice(
                              assignments[i],
                              {
                                'unset': l.assignmentUnset,
                                'value': l.assignmentValue,
                                'null': l.assignmentNull,
                                'default': l.assignmentDefault,
                              },
                              (value) => set(() => assignments[i] = value),
                              enabled: !busy,
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        [
          ValueListenableBuilder<bool>(
            valueListenable: saving,
            builder: (_, busy, _) => ui.button(
              l.cancel,
              busy ? null : () => Navigator.of(context).pop(),
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: saving,
            builder: (_, busy, _) => ui.button(
              l.stageChange,
              busy
                  ? null
                  : () async {
                      final change = rpc.StagedChange(
                        kind: kind,
                        sourceRow: Int64(sourceRow),
                      );
                      for (int i = 0; i < result.columns.length; i++) {
                        final c = result.columns[i];
                        if (kind != rpc.ChangeKind.DELETE &&
                            !generated.contains(c.baseColumn) &&
                            !c.readOnly) {
                          final text = values[i].text;
                          final assignment = switch (assignments[i]) {
                            'null' => assignmentNull(),
                            'default' => assignmentDefault(),
                            'value' => assignmentOf(
                              kind != rpc.ChangeKind.INSERT &&
                                      !row!.values[i].hasNullValue() &&
                                      text == valueText(row.values[i])
                                  ? row.values[i].deepCopy()
                                  : rpc.Value(text: text),
                            ),
                            _ => null,
                          };
                          if (assignment != null) {
                            change.values[c.ordinal] = assignment;
                          }
                        }
                      }
                      try {
                        model.requireTarget(captured);
                      } catch (_) {
                        model.updateStatus(strings(context).editTargetChanged);
                        return;
                      }
                      if (batch.revision != stagedRevision ||
                          !identical(model.backend, targetBackend) ||
                          !model.operationOwners.contains(targetDocument) ||
                          targetDocument.sessionId != targetSession) {
                        model.updateStatus(strings(context).editTargetChanged);
                        return;
                      }
                      try {
                        if (kind == rpc.ChangeKind.INSERT &&
                            provisionalInsertIndex != null) {
                          model.replaceStagedInsert(
                            batch,
                            provisionalInsertIndex!,
                            change,
                            stagedRevision,
                          );
                        } else {
                          final nextIndex = batch.changes.length;
                          model.stageChange(batch, change, original: row);
                          if (kind == rpc.ChangeKind.INSERT) {
                            provisionalInsertIndex = nextIndex;
                          }
                        }
                        stagedRevision = batch.revision;
                      } catch (error) {
                        model.updateStatus(connectionErrorText(error));
                        return;
                      }
                      batch.documentId = targetDocument.id;
                      batch.sessionId = targetSession;
                      batch.schema = targetSchema;
                      batch.table = result.columns.first.table;
                      model.updateStatus(
                        strings(
                          context,
                        ).pendingChangesCount('${batch.changes.length}'),
                      );
                      saving.value = true;
                      draftError.value = null;
                      try {
                        final persisted = model.persistStagedEdits(
                          batch: batch,
                        );
                        // Persistence advances the draft revision synchronously, even if
                        // Java rejects conversion or storage. Retrying replaces this one
                        // provisional insert; it must never append a second intention.
                        stagedRevision = batch.revision;
                        await persisted;
                        model.requireTarget(captured);
                        if (batch.revision != stagedRevision) {
                          throw StateError(l.editTargetChanged);
                        }
                        if (dialogOpen && mounted && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (_) {
                        model.updateStatus(l.recoveryStayOpen);
                        if (dialogOpen) {
                          draftError.value = l.valueDraftPreserved;
                        }
                      } finally {
                        if (dialogOpen) saving.value = false;
                      }
                    },
            ),
          ),
        ],
      );
    } finally {
      dialogOpen = false;
      saving.dispose();
      draftError.dispose();
      for (final value in values) {
        value.dispose();
      }
    }
  }

  Future<void> applyEdits({
    WorkbenchCommandContext? commandTarget,
  }) => model.command(() async {
    final l = strings(context);
    final initiatingOwner = ownerFor(commandTarget ?? model.commandContext);
    final batch = model.batchFor(
      initiatingOwner,
      model.resultForOwner(initiatingOwner)?.resultId ?? '',
    );
    void requireBatch() {
      if (batch.applying || batch.outcomeUnknown || batch.appliedSnapshot) {
        throw StateError(
          'The batch is applying, unresolved or already committed. Reconcile an unknown outcome or explicitly refresh committed data; never replay the batch.',
        );
      }
    }

    requireBatch();
    final session = model.sessions[batch.sessionId];
    if (session == null ||
        !session.autoCommit ||
        session.transaction != rpc.TransactionState.IDLE) {
      throw StateError(
        'Apply and commit requires an idle console with auto-commit enabled. Resolve the manual SQL transaction through its separate Commit or Rollback action.',
      );
    }
    if (batch.sessionId != initiatingOwner.sessionId) {
      throw StateError(
        'Reconnect does not transfer staged changes to a new physical session. Review or discard these edits.',
      );
    }
    await model.awaitStagedSave(batch: batch);
    requireBatch();
    final process = model.backend!;
    final target =
        model.operationOwners
            .where((doc) => doc.id == batch.documentId)
            .firstOrNull ??
        initiatingOwner;
    final stagedRevision = batch.revision;
    final request = model.stagedRequest(batch: batch);
    final captured = model.captureTarget(owner: target);
    final plan = await process.client.previewChanges(request);
    model.requireTarget(captured);
    if (!mounted) return;
    final evidenceUnits = plan.writeToBuffer().length * 4;
    model.documentBudget.requireAdditional(0, evidenceUnits);
    final reviewOwner = model.openTask(
      WorkbenchDocumentKind.structure,
      '${strings(context).changes} — ${batch.table}',
      profileId: target.profileId,
      reuse: false,
      payload: ChangesReviewData(captured, batch, stagedRevision, plan, () async {
        model.requireTarget(captured);
        final target = captured.owner!;
        if (batch.revision != stagedRevision ||
            batch.applying ||
            batch.outcomeUnknown) {
          throw StateError(
            'This batch changed or its application is unresolved; request a fresh review',
          );
        }
        final live = model.sessions[request.sessionId];
        if (live == null ||
            !live.autoCommit ||
            live.transaction != rpc.TransactionState.IDLE) {
          throw StateError(
            'Apply and commit requires an idle auto-commit console; resolve manual SQL transactions separately',
          );
        }
        batch.applying = true;
        model.updateStatus('${l.running} · ${l.applyAndCommit}');
        try {
          final executionId = const Uuid().v4();
          model.submissions[executionId] = target.id;
          final job = await model.ownedRequest(
            captured,
            () => process.client.applyChanges(
              rpc.ApplyRequest(
                context: process.context(),
                sessionId: request.sessionId,
                executionId: executionId,
                planId: plan.planId,
              ),
            ),
          );
          if (target.kind == WorkbenchDocumentKind.table) {
            final sourceExecution = model
                .jobsForOwner(target)
                .where(
                  (j) => j.results.any((r) => r.resultId == batch.resultId),
                )
                .firstOrNull
                ?.executionId;
            if (sourceExecution != null) {
              model.selectedExecutions[target.id] = sourceExecution;
            }
          }
          model.track(job, documentId: target.id);
          unawaited(
            waitForBatch(job, process, batch, stagedRevision).catchError((
              Object error,
            ) {
              batch.outcomeUnknown = true;
              model.updateStatus(
                '${l.outcomeUnknown} · ${operationFailureSummary(error, locale: l)}',
              );
            }),
          );
        } catch (error) {
          // An unacknowledged dispatch cannot authorize a replay. A fresh backend
          // catalog/recovery check determines whether the reviewed batch ran.
          batch.outcomeUnknown =
              error is! GrpcError ||
              ![
                StatusCode.invalidArgument,
                StatusCode.failedPrecondition,
                StatusCode.permissionDenied,
                StatusCode.resourceExhausted,
                StatusCode.unauthenticated,
              ].contains(error.code);
          batch.applying = false;
          rethrow;
        }
      }),
    );
    model.reserveDocumentEvidence(reviewOwner, evidenceUnits);
  }, ownerId: ownerFor(commandTarget ?? model.commandContext).id);
  Future<void> waitForBatch(
    rpc.JobInfo job,
    dynamic process,
    OwnedEditBatch batch,
    int stagedRevision,
  ) async {
    final unknownNotice = strings(context).unknownBatch;
    final pendingLabel =
        '${strings(context).changes}: ${strings(context).pendingChange}';
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!identical(model.backend, process)) {
        throw StateError(
          'Backend changed during application; recover only after reconciling the unknown outcome',
        );
      }
      final status = (await process.client.jobs(
        rpc.JobRequest(context: process.context(), jobId: job.jobId),
      )).jobs.single;
      if ([
        'COMPLETED',
        'FAILED',
        'CANCELLED',
        'INTERRUPTED',
        'UNKNOWN_OUTCOME',
      ].contains(status.state.name)) {
        batch.applying = false;
        batch.outcomeUnknown = status.state == rpc.JobState.UNKNOWN_OUTCOME;
        if (status.state == rpc.JobState.COMPLETED) {
          batch.appliedSnapshot = true;
          if (batch.revision == stagedRevision) {
            await model.discardStagedEdits(batch: batch);
          }
        } else {
          model.updateStatus(
            batch.outcomeUnknown
                ? unknownNotice
                : '$pendingLabel · ${status.messages.join('\n')}',
          );
        }
        break;
      }
    }
  }

  Future<void> closeTab({WorkbenchDocument? owner}) async {
    final l = strings(context);
    final selectedOwner = owner ?? model.activeOwner;
    if (selectedOwner.sql == null) {
      final pending = model.editBatches.values
          .where((b) => b.ownerId == selectedOwner.id && b.changes.isNotEmpty)
          .toList();
      final finalSessionOwner =
          selectedOwner.sessionId != null &&
          !model.operationOwners.any(
            (d) =>
                d.id != selectedOwner.id &&
                d.sessionId == selectedOwner.sessionId,
          );
      if (pending.isNotEmpty || finalSessionOwner || selectedOwner.dirty) {
        final captured = model.backend == null
            ? null
            : model.captureTarget(owner: selectedOwner);
        final targetDescription = captured == null
            ? l.notConnected
            : workbenchTargetDescription(context, captured);
        if (!await confirm(
          '${strings(context).close} ${documentName(context, model, selectedOwner)}',
          '$targetDescription\n${selectedOwner.dirty ? '${l.closeObjectDesignDiscard}\n' : ''}${l.changes}: ${pending.fold(0, (n, b) => n + b.changes.length)}\n${pending.isNotEmpty ? '${l.closeStagedRecovery}\n' : ''}${finalSessionOwner
              ? l.closeCleanupReview
              : selectedOwner.sessionId != null
              ? l.closeSharedSession
              : l.notConnected}',
        )) {
          return;
        }
        if (captured != null) model.requireTarget(captured, text: true);
      }
      await model.closeTask(
        selectedOwner,
        preserveEdits: pending.isNotEmpty,
        resolveSession: true,
      );
      return;
    }
    await model.command(() async {
      final target = selectedOwner.sql!;
      await target.writesFinished;
      if (!mounted) return;
      final revision = target.version;
      final state = model.sessions[target.sessionId];
      final ownsSession =
          target.sessionId != null &&
          !model.operationOwners.any(
            (d) => d.id != target.id && d.sessionId == target.sessionId,
          );
      final active = model.jobs.values
          .where(
            (j) =>
                j.sessionId == target.sessionId &&
                !WorkbenchModel.terminalJob(j.state),
          )
          .length;
      final edits = model.editBatches.values
          .where((b) => b.ownerId == target.id && b.changes.isNotEmpty)
          .fold(0, (n, b) => n + b.changes.length);
      final hasEdits = edits != 0;
      final captured = model.backend == null
          ? null
          : model.captureTarget(owner: selectedOwner);
      final targetDescription = captured == null
          ? l.notConnected
          : workbenchTargetDescription(context, captured);
      final decision = await ui.dialog<String>(
        context,
        '${strings(context).closeSqlTab} · ${sqlDocumentName(context, target)}',
        SelectableText(
          '$targetDescription\n${target.lastSaveError == null ? '' : '${l.saveFailedNotice}\n'}${l.closeSqlSummary(target.dirty ? l.yes : l.no, '$edits', '$active')}\n${workbenchSessionState(context, state)}\n'
          '${ownsSession
              ? l.closeCleanupReview
              : target.sessionId != null
              ? l.closeSharedSession
              : l.notConnected}\n'
          '${hasEdits ? l.closeStagedRecovery : ''}',
        ),
        [
          ui.button(strings(context).stay, () => Navigator.of(context).pop()),
          if (target.dirty)
            ui.button(
              strings(context).saveSqlClose,
              () => Navigator.of(context).pop('save'),
            ),
          ui.button(
            target.dirty
                ? strings(context).discardSqlClose
                : strings(context).closeTab,
            () => Navigator.of(context).pop('close'),
          ),
        ],
      );
      if (decision == null) return;
      if (captured != null) model.requireTarget(captured, text: true);
      if (!model.documents.contains(target) || target.version != revision) {
        throw StateError(
          'SQL changed during close review; this tab remains open',
        );
      }
      if (decision == 'save') {
        final path =
            target.path ??
            (await getSaveLocation(suggestedName: '${target.title}.sql'))?.path;
        if (path == null) return;
        if (target.version != revision) {
          throw StateError(
            'SQL changed during file selection; review closing again',
          );
        }
        await target.save(path);
        if (target.dirty) {
          throw StateError('SQL changed while saving; this tab remains open');
        }
      }
      await model.closeDocument(
        target,
        reviewedRevision: revision,
        discardText: decision == 'close',
        resolveSession: true,
        disconnectUncertain:
            state?.transaction == rpc.TransactionState.UNKNOWN_TRANSACTION,
        preserveEdits: hasEdits,
      );
    }, ownerId: selectedOwner.id);
  }

  Future<void> save({SqlDocument? owner}) => model.command(() async {
    final document = owner ?? model.document;
    final target =
        document.path ??
        (await getSaveLocation(suggestedName: '${document.title}.sql'))?.path;
    if (target != null) {
      if (!model.documents.contains(document)) {
        throw StateError('Save target was closed');
      }
      await document.save(target);
      await model.recoverNow();
    }
  }, ownerId: (owner ?? model.document).id);
  Future<void> open() => model.command(() async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'SQL', extensions: ['sql']),
      ],
    );
    if (file != null) {
      final existing = model.documents.indexWhere(
        (document) =>
            document.path != null &&
            path.equals(
              path.absolute(document.path!),
              path.absolute(file.path),
            ),
      );
      if (existing >= 0) {
        model.select(existing);
        return;
      }
      final bytes = await readBoundedFile(File(file.path), maxSqlFileBytes);
      model.newDocument(text: utf8.decode(bytes), path: file.path);
      model.document.diskHash = sha256.convert(bytes).toString();
    }
  }, ownerId: 'application');
  Future<void> workspace(bool opening) => model.command(() async {
    final l = strings(context);
    final path = opening
        ? (await openFile(confirmButtonText: l.openWorkspace))?.path
        : (await getSaveLocation(
            suggestedName: 'workbench.busydata.json',
          ))?.path;
    if (path == null) return;
    if (opening) {
      model.adoptDocuments(await PortableWorkspace.load(File(path)));
      model.updateStatus('${l.openWorkspace} · ${l.completed}');
    } else {
      await PortableWorkspace.save(File(path), model.documents);
      model.updateStatus('${l.saveWorkspace} · ${l.completed}');
    }
  }, ownerId: 'application');
  Future<void> transfer(
    bool importing, {
    bool directExport = false,
    WorkbenchCommandContext? commandTarget,
  }) async {
    final l = strings(context);
    final capturedContext = commandTarget ?? model.commandContext;
    final retainedExport = !importing && !directExport;
    // Retained data belongs to its document even when the object's database
    // console is disconnected. An Explorer inspection owner has no such data.
    final original = retainedExport
        ? (capturedContext.owner ?? (throw StateError(l.requireResult)))
        : ownerFor(capturedContext);
    if (directExport) await ensureSqlSession(original.sql!);
    final target = model.captureTarget(owner: original);
    final source = model.displayResultForOwner(original);
    if (retainedExport &&
        (source == null || source.resultId != capturedContext.resultId)) {
      throw StateError(l.requireResult);
    }
    final object = commandTarget?.object ?? original.object;
    final sql = directExport
        ? (original.sql!.editor.selectedText.isNotEmpty
              ? original.sql!.editor.selectedText
              : original.sql!.editor.text)
        : '';
    final schema =
        object?.schema ?? model.sessions[target.sessionId]?.currentSchema ?? '';
    final table = object?.name ?? (source?.columns.firstOrNull?.table ?? '');
    final kind = importing
        ? rpc.ToolKind.IMPORT_CSV
        : directExport
        ? rpc.ToolKind.EXPORT_QUERY
        : rpc.ToolKind.EXPORT_RESULT;
    final owner = model.openTask(
      WorkbenchDocumentKind.transfer,
      importing
          ? '${l.importData} · $table'
          : directExport
          ? l.exportSql
          : l.exportRetained,
      profileId: original.profileId,
      reuse: false,
      payload: TransferDocumentData(
        target,
        kind,
        schema: schema,
        table: table,
        sql: sql,
        resultId: source?.resultId ?? '',
        sourceTarget: model
            .retainedResults[model.sourceResultId(source?.resultId ?? '')]
            ?.target
            .deepCopy(),
      ),
    );
    if (importing || directExport) owner.sessionId = target.sessionId;
    owner.reopenCommandId = importing
        ? 'transfer.import'
        : directExport
        ? 'transfer.sql'
        : 'transfer.retained';
  }
}
