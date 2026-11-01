import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../features/workspace/workbench_model.dart';
import '../../backend/generated/busydata.pb.dart'
    show TransactionState, JobState, Environment;
import 'desktop_controls.dart';
import '../../l10n/workbench_strings.dart';
import 'document_presentation.dart';

class WorkbenchTabs extends StatefulWidget {
  const WorkbenchTabs({
    super.key,
    required this.model,
    required this.controls,
    required this.close,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final ValueChanged<WorkbenchDocument> close;
  @override
  State<WorkbenchTabs> createState() => _WorkbenchTabsState();
}

class _WorkbenchTabsState extends State<WorkbenchTabs> {
  WorkbenchModel get model => widget.model;
  DesktopControls get controls => widget.controls;
  final focusNodes = <String, FocusNode>{};
  final rowKeys = <String, GlobalKey>{};
  String? activeId, hoveredId;
  double? previousWidth, previousScale;
  @override
  void dispose() {
    for (final node in focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = model.workbenchDocuments.map((d) => d.id).toSet();
    for (final id
        in focusNodes.keys.where((id) => !live.contains(id)).toList()) {
      focusNodes.remove(id)!.dispose();
      rowKeys.remove(id);
    }
    return LayoutBuilder(
      builder: (context, bounds) {
        final scale = MediaQuery.textScalerOf(context).scale(14);
        if (activeId != model.activeOwner.id ||
            previousWidth != bounds.maxWidth ||
            previousScale != scale) {
          activeId = model.activeOwner.id;
          previousWidth = bounds.maxWidth;
          previousScale = scale;
          final selectedId = activeId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || activeId != selectedId) return;
            final target = rowKeys[selectedId]?.currentContext;
            if (target != null) {
              Scrollable.ensureVisible(
                target,
                alignment: .5,
                duration: Duration.zero,
              );
            }
          });
        }
        return DecoratedBox(
          decoration: BoxDecoration(
            color: controls.appearance(context).header,
            border: Border(
              bottom: BorderSide(color: controls.appearance(context).separator),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final owner in model.workbenchDocuments)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 4),
                    child: _tab(context, owner, bounds.maxWidth),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tab(
    BuildContext context,
    WorkbenchDocument owner,
    double maximumWidth,
  ) {
    final focus = focusNodes.putIfAbsent(
      owner.id,
      () => FocusNode(debugLabel: 'Document tab ${owner.id}'),
    );
    void activate() {
      focus.requestFocus();
      model.activateOwner(owner.id);
    }

    final selected = owner.id == model.activeOwner.id;
    final ownedJobs = model.jobs.values.where(
      (job) => model.jobDocuments[job.jobId] == owner.id,
    );
    final running = ownedJobs.any(
      (job) => !WorkbenchModel.terminalJob(job.state),
    );
    final sessionUnknown =
        owner.sessionId != null &&
        model.sessions[owner.sessionId]?.transaction ==
            TransactionState.UNKNOWN_TRANSACTION;
    final transaction = [
      TransactionState.ACTIVE,
      TransactionState.FAILED_TRANSACTION,
    ].contains(model.sessions[owner.sessionId]?.transaction);
    final latest = model
        .jobsForOwner(owner)
        .where((j) => j.executionId == model.latestExecutions[owner.id])
        .firstOrNull;
    final failed =
        latest != null &&
        [JobState.FAILED, JobState.INTERRUPTED].contains(latest.state);
    final unknown =
        sessionUnknown ||
        ownedJobs.any((job) => job.state == JobState.UNKNOWN_OUTCOME);
    final production =
        documentProfile(model, owner)?.environment == Environment.PRODUCTION;
    final presentation = documentTabLabel(context, model, owner);
    final target = presentation.context;
    final l = strings(context);
    final displayTitle = presentation.name;
    final baseTitle =
        '${owner.dirty ? '● ' : ''}${[displayTitle, presentation.qualifier, presentation.instance].where((s) => s.isNotEmpty).join(' · ')}';
    final badges = [
      if (production) l.production,
      if (unknown) l.outcomeUnknown,
    ];
    final states = [
      if (running) l.running else if (failed) l.failed,
      if (transaction)
        model.sessions[owner.sessionId]?.transaction ==
                TransactionState.FAILED_TRANSACTION
            ? l.failedTransaction
            : l.activeTransaction,
    ];
    final title = [
      baseTitle,
      ...badges,
      ...states,
      if (latest?.state == JobState.COMPLETED) l.completed,
      if (latest?.state == JobState.CANCELLED) l.cancelled,
    ].join(' · ');
    final badgeText = badges.join(' · ');
    final badgePainter = TextPainter(
      text: TextSpan(text: badgeText, style: controls.textStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final badgeWidth = badgePainter.width;
    badgePainter.dispose();
    // Target titles may shorten; consequential state remains readable. Tabs
    // can scroll when translated state labels exceed the available width.
    final titleExtent = math.max(
      40.0,
      math.min(180.0, maximumWidth - badgeWidth - 100),
    );
    final wrapCriticalState = unknown && badgeWidth > maximumWidth - 140;
    return controls.contextMenu(
      controls.tooltip(
        [title, target].where((s) => s.isNotEmpty).join('\n'),
        Semantics(
          key: ValueKey('document-tab:${owner.id}'),
          selected: selected,
          button: true,
          enabled: true,
          focusable: true,
          focused: focus.hasFocus,
          onFocus: focus.requestFocus,
          onTap: activate,
          label: [title, target].where((s) => s.isNotEmpty).join('\n'),
          child: KeyedSubtree(
            key: rowKeys.putIfAbsent(owner.id, GlobalKey.new),
            child: Listener(
              onPointerDown: (event) {
                if (event.buttons == kMiddleMouseButton) widget.close(owner);
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => hoveredId = owner.id),
                onExit: (_) => setState(() => hoveredId = null),
                child: controls.tabInteraction(
                  selected: selected,
                  hovered: hoveredId == owner.id,
                  focusNode: focus,
                  onFocusChange: (_) {
                    if (mounted) setState(() {});
                  },
                  onPressed: activate,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 112,
                      minHeight: 34,
                    ),
                    padding: const EdgeInsetsDirectional.only(
                      start: 8,
                      end: 4,
                      top: 0,
                      bottom: 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: controls.tabRadius,
                      border: Border.all(
                        color: selected
                            ? controls.tabBorder(context)
                            : const Color(0x00000000),
                      ),
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(
                        color: controls.tabForeground(context, selected),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ExcludeSemantics(
                            child: controls.tabLeading(switch (owner.kind) {
                              WorkbenchDocumentKind.sql => DesktopIcon.query,
                              WorkbenchDocumentKind.table ||
                              WorkbenchDocumentKind.result => DesktopIcon.table,
                              WorkbenchDocumentKind.structure =>
                                DesktopIcon.folder,
                              _ => DesktopIcon.tool,
                            }, owner.dirty),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: presentation.qualifier.isEmpty
                                  ? titleExtent
                                  : math.min(112, titleExtent),
                            ),
                            child: ExcludeSemantics(
                              child: Text(
                                displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: controls.tabLabelStyle(
                                  context,
                                  selected,
                                ),
                              ),
                            ),
                          ),
                          if (presentation.qualifier.isNotEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 6,
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: ExcludeSemantics(
                                  child: Text(
                                    presentation.qualifier,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: controls.tabLabelStyle(
                                      context,
                                      selected,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (presentation.instance.isNotEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 6,
                              ),
                              child: ExcludeSemantics(
                                child: Text(
                                  presentation.instance,
                                  style: controls.tabLabelStyle(
                                    context,
                                    selected,
                                  ),
                                ),
                              ),
                            ),
                          if (badges.isNotEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: wrapCriticalState
                                      ? math.max(
                                          80,
                                          maximumWidth - titleExtent - 100,
                                        )
                                      : double.infinity,
                                ),
                                child: ExcludeSemantics(
                                  child: Text(
                                    badgeText,
                                    maxLines: wrapCriticalState ? null : 1,
                                    softWrap: wrapCriticalState,
                                    style: controls.tabLabelStyle(
                                      context,
                                      selected,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (states.isNotEmpty)
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 6,
                              ),
                              child: controls.tooltip(
                                states.join(' · '),
                                ExcludeSemantics(
                                  child: controls.icon(
                                    running
                                        ? DesktopIcon.running
                                        : failed
                                        ? DesktopIcon.warning
                                        : DesktopIcon.transaction,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          controls.iconButton(
                            DesktopIcon.close,
                            '${l.closeTab} $displayTitle',
                            () => widget.close(owner),
                            compact: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      [DesktopMenuAction(strings(context).closeTab, () => widget.close(owner))],
    );
  }
}
