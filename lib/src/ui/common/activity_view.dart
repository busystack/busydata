import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show SelectableText;
import '../../backend/generated/busydata.pbgrpc.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import '../../l10n/workbench_strings.dart';

class ActivityInspectionState {
  List<rpc.Activity> entries = [];
  rpc.Activity? selected;
  String availability = '', error = '';
  bool loaded = false;
  String filter = '';
  double scrollOffset = 0;
}

class ActivityView extends StatefulWidget {
  const ActivityView({
    super.key,
    required this.model,
    required this.target,
    required this.controls,
    required this.action,
    this.inspection,
  });
  final WorkbenchModel model;
  final CapturedWorkbenchTarget target;
  final DesktopControls controls;
  final Future<void> Function(rpc.Activity activity, bool terminate) action;
  final ActivityInspectionState? inspection;
  @override
  State<ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<ActivityView> {
  List<rpc.Activity> entries = [];
  rpc.Activity? selected;
  String availability = '', error = '';
  bool polling = false, busy = false, actionPending = false;
  Timer? timer;
  final filter = TextEditingController();
  late final ScrollController scroll;
  Future<void> refresh() async {
    if (busy || actionPending) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      widget.model.requireTarget(widget.target);
      final reply = await widget.target.backend.client.activities(
        rpc.ActivityRequest(
          context: widget.target.backend.context(),
          sessionId: widget.target.sessionId,
        ),
      );
      widget.model.requireTarget(widget.target);
      if (!mounted) return;
      if (reply.entries.length > 512 ||
          reply.writeToBuffer().length > 1048576) {
        throw StateError(strings(context).activityReplyTooLarge);
      }
      setState(() {
        final previous = selected;
        entries = reply.entries;
        selected = entries
            .where(
              (entry) =>
                  entry.id == previous?.id &&
                  entry.fingerprint == previous?.fingerprint,
            )
            .firstOrNull;
        availability = [
          reply.availability,
          if (reply.limited) strings(context).activityListLimited,
        ].where((value) => value.isNotEmpty).join(' ');
        if (previous != null && selected == null) {
          error = strings(context).activitySelectionChanged;
        }
        widget.inspection?.loaded = true;
      });
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    final saved = widget.inspection;
    scroll = ScrollController(
      initialScrollOffset: saved?.scrollOffset ?? 0,
      keepScrollOffset: false,
    );
    scroll.addListener(() {
      if (scroll.hasClients) widget.inspection?.scrollOffset = scroll.offset;
    });
    filter.text = saved?.filter ?? '';
    filter.addListener(() => setState(() {}));
    if (saved?.loaded == true) {
      entries = saved!.entries;
      selected = saved.selected;
      availability = saved.availability;
      error = saved.error;
    } else {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    final saved = widget.inspection;
    if (saved != null) {
      saved.entries = entries;
      saved.selected = selected;
      saved.availability = availability;
      saved.error = error;
      saved.filter = filter.text;
      if (scroll.hasClients) saved.scrollOffset = scroll.offset;
    }
    filter.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> act(bool terminate) async {
    final captured = selected;
    if (captured == null || actionPending) return;
    setState(() => actionPending = true);
    try {
      widget.model.requireTarget(widget.target);
      await widget.action(captured.deepCopy(), terminate);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) {
        setState(() => actionPending = false);
        await refresh();
      }
    }
  }

  void select(rpc.Activity? activity) {
    setState(() => selected = activity);
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.controls;
    final l = strings(context), query = filter.text.toLowerCase();
    final visible = entries
        .where(
          (entry) =>
              query.isEmpty ||
              '${entry.id} ${entry.principal} ${entry.database} ${entry.state} ${entry.wait} ${entry.queryPreview}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList();
    final selectedVisible = visible.any(
      (entry) =>
          entry.id == selected?.id &&
          entry.fingerprint == selected?.fingerprint,
    );
    final ordered = visible;
    return ListView.builder(
      controller: scroll,
      itemCount: ordered.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WorkbenchStrip(
                controls: ui,
                minimumHeight: 38,
                child: ui.tooltip(
                  workbenchTargetDescription(context, widget.target),
                  Text(workbenchTargetCaption(context, widget.target)),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  ui.button(
                    busy ? l.refreshing : l.refreshActivities,
                    busy || actionPending ? null : refresh,
                  ),
                  ui.choice(
                    polling,
                    {false: l.explicitRefresh, true: l.pollFiveSeconds},
                    (value) {
                      setState(() => polling = value);
                      timer?.cancel();
                      if (value) {
                        timer = Timer.periodic(
                          const Duration(seconds: 5),
                          (_) => refresh(),
                        );
                      }
                    },
                  ),
                  ui.button(
                    l.cancelSelectedActivity,
                    selected?.cancellable != true ||
                            !selectedVisible ||
                            actionPending
                        ? null
                        : () => act(false),
                  ),
                  ui.button(
                    l.terminateSelectedSession,
                    selected == null || !selectedVisible || actionPending
                        ? null
                        : () => act(true),
                  ),
                ],
              ),
              Text(availability),
              Semantics(
                container: true,
                child: ui.filterField(filter, l.filterActivities),
              ),
              if (error.isNotEmpty)
                Semantics(
                  liveRegion: true,
                  child: SelectableText(
                    error,
                    style: ui
                        .appearance(context)
                        .body
                        .copyWith(color: ui.appearance(context).error),
                  ),
                ),
              WorkbenchStrip(
                controls: ui,
                minimumHeight: 38,
                child: Row(
                  children: [
                    for (final heading in [
                      l.sessionMenu,
                      l.user,
                      l.database,
                      l.activityState,
                      l.activityWait,
                    ])
                      Expanded(
                        child: Text(
                          heading,
                          style: ui
                              .textStyle(context)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }
        final entry = ordered[index - 1];
        return Padding(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MergeSemantics(
                child: Semantics(
                  selected: selected?.id == entry.id,
                  child: WorkbenchRecord(
                    controls: ui,
                    label:
                        '${entry.id} · ${entry.principal} · ${entry.database} · ${entry.state} · ${entry.wait}',
                    selected: selected?.id == entry.id,
                    onPressed: () => select(entry),
                    child: Row(
                      children: [
                        for (final value in [
                          entry.id.toString(),
                          entry.principal,
                          entry.database,
                          entry.state,
                          entry.wait,
                        ])
                          Expanded(
                            child: ui.tooltip(
                              value,
                              Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (entry.blockers.isNotEmpty)
                Wrap(
                  spacing: 4,
                  children: [
                    Text(l.blockedBy),
                    for (final id in entry.blockers)
                      ui.textButton('$id', () {
                        final blocker = entries
                            .where((value) => value.id == id)
                            .firstOrNull;
                        setState(() {
                          if (blocker != null) {
                            filter.clear();
                          }
                          if (blocker == null) {
                            error = strings(
                              context,
                            ).activityBlockerUnavailable('$id');
                          }
                        });
                        select(blocker);
                      }),
                  ],
                ),
              if (selected?.id == entry.id && entry.queryPreview.isNotEmpty)
                MergeSemantics(
                  child: Semantics(
                    label: 'SQL',
                    child: WorkbenchCodeEvidence(
                      controls: ui,
                      text: entry.queryPreview,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
