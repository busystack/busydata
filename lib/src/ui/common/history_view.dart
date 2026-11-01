import 'dart:async';
import 'package:grpc/grpc.dart' show ResponseFuture;
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:intl/date_symbol_data_local.dart';
import '../../l10n/workbench_strings.dart';
import 'package:flutter/material.dart' show SelectableText;
import '../../backend/backend_process.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'workbench_search_session.dart';

class HistoryInspectionState extends ChangeNotifier {
  BackendConnection? backendOwner;
  String? backendInstance, selected;
  String search = '', days = '';
  String? acceptedQuery;
  int offset = 0;
  double vertical = 0;
  rpc.HistoryList? list;
  int _revision = 0;
  // A mounted details view accepts explicit search handoffs. Older views and
  // retiring sidebar instances may not overwrite a newer accepted revision.
  int claim() => ++_revision;
  bool owns(int revision) => revision == _revision;
  void present() => notifyListeners();
}

class HistoryView extends StatefulWidget {
  const HistoryView({
    super.key,
    required this.model,
    required this.controls,
    this.inspection,
    this.admitEvidence,
    this.externalQuery,
    this.inspect,
  });
  final TextEditingController? externalQuery;
  final VoidCallback? inspect;
  final WorkbenchModel model;
  final DesktopControls controls;
  final HistoryInspectionState? inspection;
  final void Function(int units)? admitEvidence;
  @override
  State<HistoryView> createState() => HistoryViewState();
}

class HistoryViewState extends State<HistoryView> {
  late final BackendConnection backend = widget.model.backend!;
  late final search = widget.externalQuery ?? TextEditingController();
  Timer? debounce;
  int generation = 0;
  final searchRowKeys = <String, GlobalKey<WorkbenchRecordState>>{};
  ResponseFuture<rpc.HistoryList>? request;
  final days = TextEditingController();
  rpc.HistoryList? list;
  String? selected;
  String? acceptedQuery;
  int offset = 0;
  bool busy = false;
  String error = '';
  late final inspection = widget.inspection ?? HistoryInspectionState();
  late final ScrollController rows;
  late int inspectionRevision;
  bool synchronizing = false;
  late String observedQuery;
  DesktopControls get ui => widget.controls;
  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    if (widget.externalQuery == null) search.text = inspection.search;
    observedQuery = search.text;
    final sameBackend =
        identical(inspection.backendOwner, backend) &&
        inspection.backendInstance == backend.instanceId;
    final samePage =
        sameBackend &&
        inspection.search == search.text &&
        (inspection.list == null || inspection.acceptedQuery == search.text);
    inspectionRevision = inspection.claim();
    rows = ScrollController(
      initialScrollOffset: samePage ? inspection.vertical : 0,
    );
    search.addListener(queryChanged);
    inspection.addListener(handoffChanged);
    days.text = sameBackend ? inspection.days : '';
    offset = samePage ? inspection.offset : 0;
    selected = samePage ? inspection.selected : null;
    list = samePage ? inspection.list : null;
    acceptedQuery = samePage ? inspection.acceptedQuery : null;
    if (!samePage) inspection.vertical = 0;
    persist();
    // Reopening shared search must include newly recorded history. Keep the
    // matching accepted page visible while refreshing its captured offset.
    if ((list == null || widget.externalQuery != null) &&
        !search.value.composing.isValid) {
      load();
    }
  }

  @override
  void dispose() {
    persist();
    inspection.removeListener(handoffChanged);
    rows.dispose();
    generation++;
    unawaited(retireRequest());
    debounce?.cancel();
    search.removeListener(queryChanged);
    if (widget.externalQuery == null) search.dispose();
    days.dispose();
    super.dispose();
  }

  void persist({bool presenting = false}) {
    if (!inspection.owns(inspectionRevision)) return;
    inspection
      ..backendOwner = backend
      ..backendInstance = backend.instanceId
      ..search = search.text
      ..days = days.text
      ..offset = offset
      ..selected = selected
      ..list = list
      ..acceptedQuery = acceptedQuery
      ..vertical = rows.hasClients
          ? rows.offset.clamp(0, 1000000000)
          : inspection.vertical;
    if (presenting) inspection.present();
  }

  void handoffChanged() {
    if (!mounted ||
        widget.externalQuery != null ||
        inspection.owns(inspectionRevision) ||
        !identical(inspection.backendOwner, backend)) {
      return;
    }
    generation++;
    unawaited(retireRequest());
    debounce?.cancel();
    synchronizing = true;
    try {
      inspectionRevision = inspection.claim();
      search.text = inspection.search;
      observedQuery = search.text;
      days.text = inspection.days;
      setState(() {
        list = inspection.list;
        acceptedQuery = inspection.acceptedQuery;
        selected = inspection.selected;
        offset = inspection.offset;
        busy = false;
        error = '';
      });
      final ids = list?.entries.map((entry) => entry.id).toSet() ?? <String>{};
      searchRowKeys.removeWhere((id, _) => !ids.contains(id));
    } finally {
      synchronizing = false;
    }
    final revision = inspectionRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !inspection.owns(revision) || !rows.hasClients) return;
      rows.jumpTo(inspection.vertical.clamp(0, rows.position.maxScrollExtent));
      revealSelected();
    });
  }

  Future<void> retireRequest() async {
    final previous = request;
    request = null;
    try {
      await previous?.cancel();
    } catch (_) {
      /* Generation retires late replies. */
    }
  }

  Future<void> run(Future<void> Function() operation) async {
    if (busy) return;
    final revision = generation;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      requireBackend();
      await operation();
    } catch (e) {
      if (mounted && revision == generation) setState(() => error = '$e');
    } finally {
      if (mounted && revision == generation) setState(() => busy = false);
    }
  }

  void requireBackend() {
    if (widget.model.isDisposed || !identical(backend, widget.model.backend)) {
      throw StateError('Backend changed. Reopen history.');
    }
  }

  void acceptList(rpc.HistoryList response, {required String query}) {
    requireBackend();
    if (response.entries.length > 50 ||
        response.writeToBuffer().length > 1048576) {
      throw StateError('History page exceeds its bounded catalog limit');
    }
    widget.admitEvidence?.call(response.writeToBuffer().length * 4);
    list = response;
    acceptedQuery = query;
    final ids = response.entries.map((entry) => entry.id).toSet();
    searchRowKeys.removeWhere((id, _) => !ids.contains(id));
  }

  void queryChanged() {
    if (synchronizing || search.value.composing.isValid) return;
    if (search.text == observedQuery) return;
    observedQuery = search.text;
    inspectionRevision = inspection.claim();
    generation++;
    unawaited(retireRequest());
    debounce?.cancel();
    setState(() {
      selected = null;
      list = null;
      acceptedQuery = null;
      offset = 0;
    });
    if (rows.hasClients) rows.jumpTo(0);
    inspection.vertical = 0;
    persist();
    debounce = Timer(const Duration(milliseconds: 160), () => load());
  }

  void move(int delta) {
    final entries = list?.entries ?? [];
    if (entries.isEmpty) return;
    final rowFocus =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<WorkbenchRecord>() !=
        null;
    final focusOwner = FocusManager.instance.primaryFocus;
    final index = entries.indexWhere((e) => e.id == selected);
    final next = (index + delta) % entries.length;
    setState(() => selected = entries[next].id);
    revealSelected(takeFocus: rowFocus, focusOwner: focusOwner);
  }

  void revealSelected({bool takeFocus = false, FocusNode? focusOwner}) {
    final entries = list?.entries ?? [];
    final next = entries.indexWhere((entry) => entry.id == selected);
    if (next < 0) return;
    final id = selected!;
    unawaited(
      revealSearchRecord(
        scroll: rows,
        keys: searchRowKeys,
        identity: id,
        index: next,
        indexOf: (key) => entries.indexWhere((entry) => entry.id == key),
        current: () =>
            mounted && identical(list?.entries, entries) && selected == id,
        focusOwner: focusOwner,
        takeFocus: takeFocus,
      ),
    );
  }

  void activateSelection() {
    if (selected == null ||
        widget.inspect == null ||
        busy ||
        search.value.composing.isValid ||
        acceptedQuery != search.text ||
        list?.entries.any((entry) => entry.id == selected) != true) {
      return;
    }
    requireBackend();
    inspectionRevision = inspection.claim();
    persist(presenting: true);
    widget.inspect!();
  }

  Future<void> load() async {
    final requested = ++generation;
    final query = search.text, pageOffset = offset;
    await retireRequest();
    if (!mounted || requested != generation) return;
    setState(() {
      busy = true;
      error = '';
    });
    try {
      requireBackend();
      request = backend.client.history(
        rpc.HistoryRequest(
          context: backend.context(),
          search: query,
          offset: pageOffset,
          limit: 50,
        ),
      );
      final response = await request!;
      requireBackend();
      if (!mounted || requested != generation) return;
      setState(() {
        acceptList(response, query: query);
        selected = null;
        days.text = '${response.retentionDays}';
      });
      persist();
    } catch (failure) {
      if (mounted && requested == generation) {
        setState(() => error = '$failure');
      }
    } finally {
      if (requested == generation) request = null;
      if (mounted && requested == generation) setState(() => busy = false);
    }
  }

  Future<bool> confirm(
    String title,
    String text, {
    String? actionLabel,
    bool destructive = false,
  }) async =>
      await ui.dialog<bool>(context, title, Text(text), [
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

  Future<void> privacy() => run(() async {
    final revision = generation, query = search.text;
    final l = strings(context);
    final retention = int.tryParse(days.text);
    if (retention == null || retention < 1 || retention > 3650) {
      throw ArgumentError(l.historyRetentionRange);
    }
    final retain = !(list?.retainSql ?? false);
    if (!await confirm(
      l.historyPrivacy,
      retain ? l.historyRetainSqlReview('$retention') : l.historyStopSqlReview,
      actionLabel: retain ? l.enableSqlHistory : l.stopSqlHistory,
      destructive: !retain,
    )) {
      return;
    }
    if (revision != generation) return;
    requireBackend();
    final response = await backend.client.history(
      rpc.HistoryRequest(
        context: backend.context(),
        action: rpc.HistoryAction.SET_PRIVACY,
        retainSql: retain,
        retentionDays: retention,
        search: query,
      ),
    );
    if (mounted && revision == generation) {
      setState(() {
        acceptList(response, query: query);
        offset = 0;
        selected = null;
      });
      persist();
    }
  });

  Future<void> retention() => run(() async {
    final revision = generation, query = search.text;
    final value = int.tryParse(days.text);
    if (value == null || value < 1 || value > 3650) {
      throw ArgumentError(strings(context).historyRetentionRange);
    }
    final response = await backend.client.history(
      rpc.HistoryRequest(
        context: backend.context(),
        action: rpc.HistoryAction.SET_PRIVACY,
        retainSql: list?.retainSql ?? false,
        retentionDays: value,
        search: query,
      ),
    );
    if (mounted && revision == generation) {
      setState(() {
        acceptList(response, query: query);
        offset = 0;
        selected = null;
      });
      persist();
    }
  });

  Future<void> remove({bool all = false}) => run(() async {
    final revision = generation, query = search.text, id = selected;
    if (!await confirm(
      all ? strings(context).clearHistory : strings(context).deleteHistoryEntry,
      all
          ? strings(context).historyClearReview
          : strings(context).historyDeleteReview,
      destructive: true,
    )) {
      return;
    }
    if (revision != generation) return;
    requireBackend();
    final response = await backend.client.history(
      rpc.HistoryRequest(
        context: backend.context(),
        action: all
            ? rpc.HistoryAction.CLEAR_HISTORY
            : rpc.HistoryAction.DELETE_HISTORY_ENTRY,
        entryId: id,
        search: query,
      ),
    );
    if (mounted && revision == generation) {
      setState(() {
        acceptList(response, query: query);
        offset = 0;
        selected = null;
      });
      persist();
    }
  });

  Future<void> reopen() => run(() async {
    final id = selected!;
    final revision = generation;
    final text = StringBuffer();
    var start = 0;
    while (true) {
      final chunk = await backend.client.historySql(
        rpc.HistorySqlRequest(
          context: backend.context(),
          entryId: id,
          offsetUtf16: start,
          maxUnits: 65536,
        ),
      );
      requireBackend();
      if (!mounted || revision != generation || selected != id) return;
      if (chunk.totalUnits > 8000000) {
        throw StateError('History SQL exceeds editor limit');
      }
      text.write(chunk.text);
      if (chunk.complete) break;
      if (chunk.nextOffsetUtf16 <= start) {
        throw StateError('Invalid history chunk');
      }
      start = chunk.nextOffsetUtf16;
    }
    if (text.isEmpty) throw StateError('No SQL text retained for this entry');
    if (!mounted || revision != generation || selected != id) return;
    requireBackend();
    widget.model.newDocument(text: text.toString());
    widget.model.showGlobalTool(null);
  });

  Future<void> settings() => ui.dialog<void>(
    context,
    strings(context).historyPrivacy,
    StatefulBuilder(
      builder: (dialogContext, set) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings(context).historyMetadataRetained),
          Text(
            list?.retainSql == true
                ? strings(context).sqlTextRetained
                : strings(context).sqlTextDisabled,
          ),
          ui.field(days, strings(context).retentionDays),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ui.button(
                strings(context).saveRetention,
                busy
                    ? null
                    : () async {
                        await retention();
                        if (dialogContext.mounted) set(() {});
                      },
              ),
              ui.button(
                list?.retainSql == true
                    ? strings(context).disableSqlRetention
                    : strings(context).enableSqlRetention,
                busy
                    ? null
                    : () async {
                        await privacy();
                        if (dialogContext.mounted) set(() {});
                      },
              ),
            ],
          ),
          if (error.isNotEmpty)
            SelectableText(
              error,
              style: ui
                  .appearance(context)
                  .body
                  .copyWith(color: ui.appearance(context).error),
            ),
        ],
      ),
    ),
    [ui.button(strings(context).close, () => Navigator.of(context).pop())],
  );

  Widget searchResults(BuildContext context) {
    final l = strings(context), look = ui.appearance(context);
    final entries = list?.entries ?? <rpc.HistoryEntry>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) ui.status(l.loading),
        if (error.isNotEmpty) ui.status(error, error: true),
        if (!busy && entries.isEmpty) ui.status(l.searchNoResults),
        Expanded(
          child: ListView.builder(
            controller: rows,
            padding: ui.sidebarListPadding,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return WorkbenchRecord(
                key: searchRowKeys.putIfAbsent(entry.id, GlobalKey.new),
                controls: ui,
                leading: DesktopIcon.history,
                label: entry.target,
                selected: selected == entry.id,
                takeFocus: false,
                onFocusChange: (focused) {
                  if (focused) setState(() => selected = entry.id);
                },
                onPressed: busy
                    ? null
                    : () {
                        setState(() => selected = entry.id);
                        activateSelection();
                      },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      entry.target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${workbenchJobState(context, entry.state)} · ${entry.durationMs} ms',
                      style: look.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      String.fromCharCodes(entry.sql.runes.take(256)),
                      style: look.technical,
                      textDirection: TextDirection.ltr,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (offset > 0)
              ui.button(
                l.previous,
                busy
                    ? null
                    : () {
                        offset = (offset - 50).clamp(0, 1000000);
                        load();
                      },
              ),
            if (list?.limited == true)
              ui.button(
                l.next,
                busy
                    ? null
                    : () {
                        offset = list!.nextOffset;
                        load();
                      },
              ),
            ui.button(
              l.reviewDetails,
              selected == null || busy ? null : activateSelection,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (widget.externalQuery != null) return searchResults(context);
      return Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ui.button(
                strings(context).search,
                () => widget.model.commands?.invoke(
                  'history.search',
                  widget.model.commandContext,
                ),
              ),
              if (widget.inspect != null)
                ui.button(
                  strings(context).reviewDetails,
                  selected == null ? null : activateSelection,
                ),
              const SizedBox(width: 8),
              ui.menu(strings(context).more, [
                DesktopMenuAction(
                  strings(context).openHistoryQuery,
                  reopen,
                  disabledReason: busy
                      ? strings(context).running
                      : selected == null
                      ? strings(context).selectHistoryEntry
                      : null,
                ),
                DesktopMenuAction(
                  strings(context).deleteSelected,
                  () => remove(),
                  disabledReason: busy
                      ? strings(context).running
                      : selected == null
                      ? strings(context).selectHistoryEntry
                      : null,
                ),
                if (offset > 0)
                  DesktopMenuAction(strings(context).previous, () {
                    offset = (offset - 50).clamp(0, 1000000);
                    load();
                  }, disabledReason: busy ? strings(context).running : null),
                if (list?.limited == true)
                  DesktopMenuAction(strings(context).next, () {
                    offset = list!.nextOffset;
                    load();
                  }, disabledReason: busy ? strings(context).running : null),
                DesktopMenuAction(
                  strings(context).historyPrivacy,
                  settings,
                  disabledReason: busy ? strings(context).running : null,
                ),
                DesktopMenuAction(
                  strings(context).clearHistory,
                  () => remove(all: true),
                  disabledReason: busy ? strings(context).running : null,
                ),
              ]),
            ],
          ),
          Expanded(
            child: ListView.builder(
              controller: rows,
              itemCount: (list?.entries.length ?? 0) + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${list?.retainSql == true ? strings(context).sqlTextRetained : strings(context).sqlTextDisabled} · ${strings(context).retentionDays}: ${list?.retentionDays ?? '…'}',
                      ),
                      if (error.isNotEmpty)
                        SelectableText(
                          error,
                          style: ui
                              .appearance(context)
                              .body
                              .copyWith(color: ui.appearance(context).error),
                        ),
                    ],
                  );
                }
                final entry = list!.entries[index - 1];
                return Semantics(
                  selected: selected == entry.id,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WorkbenchRecord(
                          key: searchRowKeys.putIfAbsent(
                            entry.id,
                            GlobalKey.new,
                          ),
                          controls: ui,
                          label: entry.target,
                          selected: selected == entry.id,
                          onPressed: busy
                              ? null
                              : () {
                                  setState(() => selected = entry.id);
                                  inspectionRevision = inspection.claim();
                                  persist();
                                  if (widget.inspect != null) {
                                    activateSelection();
                                  }
                                },
                          child: Text(
                            entry.target,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${DateFormat.yMMMd(strings(context).localeName).add_jms().format(DateTime.fromMillisecondsSinceEpoch(entry.startedUnixMs.toInt()))} · ${workbenchJobState(context, entry.state)} · ${entry.durationMs} ms',
                        ),
                        WorkbenchCodeEvidence(
                          controls: ui,
                          text:
                              '${entry.sql}${entry.sqlTruncated ? '\n[${strings(context).historyPreviewNote}]' : ''}',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );
    },
  );
}
