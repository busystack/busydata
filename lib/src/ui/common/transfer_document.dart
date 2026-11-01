import '../../backend/tool_admission_requests.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'package:uuid/uuid.dart';
import 'package:grpc/grpc.dart' show ResponseFuture, GrpcError;

import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';
import '../../backend/connection_failure.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import '../../l10n/workbench_strings.dart';
import 'result_grid.dart';

class TransferDocumentData {
  TransferDocumentData(
    this.target,
    this.kind, {
    this.path = '',
    this.schema = '',
    this.table = '',
    this.resultId = '',
    this.sql = '',
    this.nativeTool = '',
    this.sourceTarget,
  });
  final CapturedWorkbenchTarget target;
  final rpc.Profile? sourceTarget;
  final rpc.ToolKind kind;
  final String resultId, sql, nativeTool;
  String path, schema, table;
  String format = 'csv',
      encoding = 'UTF-8',
      delimiter = ',',
      nullMarker = r'\N';
  bool overwrite = false;
  int batchRows = 256, errorLimit = 100, revision = 0;
  rpc.ImportPolicy policy = rpc.ImportPolicy.ATOMIC_IMPORT;
  final mapping = <String, String>{};
  rpc.ImportPreview? preview;
  rpc.ToolRequest? reviewed;
  rpc.Approval? approval;
  String? jobId;
  String status = '';
  bool busy = false;
  bool get importing =>
      kind == rpc.ToolKind.IMPORT_CSV || kind == rpc.ToolKind.IMPORT_JSON;
  bool get native => kind == rpc.ToolKind.DUMP || kind == rpc.ToolKind.RESTORE;
  void changed() {
    revision++;
    reviewed = null;
    approval = null;
    preview = null;
  }
}

class TransferDocument extends StatefulWidget {
  const TransferDocument({
    super.key,
    required this.model,
    required this.owner,
    required this.data,
    required this.controls,
  });
  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final TransferDocumentData data;
  final DesktopControls controls;
  @override
  State<TransferDocument> createState() => _TransferDocumentState();
}

class _TransferDocumentState extends State<TransferDocument> {
  TransferDocumentData get data => widget.data;
  final controllers = <String, TextEditingController>{};
  List<rpc.SchemaObject> columns = [];
  bool columnsComplete = false;
  bool columnsLoading = false;
  ResponseFuture<rpc.SchemaObjects>? columnsRequest;
  ResponseFuture<dynamic>? admissionRequest;
  @override
  void initState() {
    super.initState();
    if (data.importing) loadColumns();
  }

  @override
  void dispose() {
    columnsRequest?.cancel();
    admissionRequest?.cancel();
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    String key,
    String label,
    String value,
    void Function(String) save,
  ) {
    final c = controllers.putIfAbsent(key, () {
      final controller = TextEditingController(text: value);
      controller.addListener(() {
        save(controller.text);
        data.changed();
        if (mounted) setState(() {});
      });
      return controller;
    });
    return widget.controls.field(c, label);
  }

  Future<void> loadColumns() async {
    if (columnsLoading) return;
    setState(() {
      columnsLoading = true;
      columnsComplete = false;
      columns = [];
    });
    try {
      final target = data.target;
      final schema = data.schema, table = data.table;
      final reply = await widget.model.readMetadata(
        target,
        rpc.ExploreRequest(
          context: target.backend.context(),
          sessionId: target.sessionId,
          kind: rpc.ObjectKind.COLUMN,
          catalog: target.session?.currentCatalog,
          schema: schema,
          table: table,
        ),
        current: () =>
            mounted &&
            data.schema == schema &&
            data.table == table &&
            widget.model.taskDocuments.contains(widget.owner),
        onRequest: (request) => columnsRequest = request,
      );
      widget.model.requireTarget(target);
      if (mounted) {
        widget.model.reserveDocumentEvidence(
          widget.owner,
          reply.writeToBuffer().length * 4,
        );
        setState(() {
          columns = reply.objects;
          columnsComplete = true;
        });
      }
    } catch (error) {
      if (mounted) {
        data.status = error is GrpcError
            ? ConnectionFailure.from(error).localizedSummary(strings(context))
            : operationFailureSummary(error, locale: strings(context));
      }
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => columnsLoading = false);
    }
  }

  rpc.ToolRequest request() {
    if (data.importing && !columnsComplete) {
      throw StateError(
        'Target column metadata is incomplete; reload the import workflow',
      );
    }
    if (data.importing &&
        data.mapping.keys.any(
          (name) => !columns.any(
            (column) =>
                column.name == name &&
                column.properties['generated'] == 'NO' &&
                column.properties['autoIncrement'] == 'NO',
          ),
        )) {
      throw StateError(
        'Target column metadata is incomplete; reload the import workflow',
      );
    }
    widget.model.requireTarget(
      data.target,
      text: data.kind == rpc.ToolKind.EXPORT_QUERY,
    );
    return rpc.ToolRequest(
      context: data.target.backend.context(),
      sessionId: data.target.sessionId,
      executionId: const Uuid().v4(),
      kind: data.importing
          ? (data.format == 'csv' || data.format == 'tsv'
                ? rpc.ToolKind.IMPORT_CSV
                : rpc.ToolKind.IMPORT_JSON)
          : data.kind,
      path: data.path,
      schema: data.schema,
      table: data.table,
      format: data.native ? '' : data.format,
      sql: data.sql,
      resultId: data.resultId,
      nativeToolPath: data.nativeTool,
      overwrite: data.overwrite,
      encoding: data.encoding,
      nullMarker: data.nullMarker,
      delimiter: data.format == 'tsv' ? '\t' : data.delimiter,
      importPolicy: data.policy,
      batchRows: data.batchRows,
      errorLimit: data.errorLimit,
      columns: data.mapping.keys,
      columnMapping: data.mapping.entries,
    );
  }

  Future<void> operation(Future<void> Function() perform) async {
    if (data.busy) return;
    final l = strings(context);
    widget.model.pendingCommands[widget.owner.id] =
        (widget.model.pendingCommands[widget.owner.id] ?? 0) + 1;
    setState(() {
      data.busy = true;
      data.status = '';
    });
    try {
      await perform();
    } catch (error) {
      data.status = error is GrpcError
          ? ConnectionFailure.from(error).localizedSummary(l)
          : operationFailureSummary(error, locale: l);
    } finally {
      final remaining = widget.model.pendingCommands[widget.owner.id]! - 1;
      if (remaining == 0) {
        widget.model.pendingCommands.remove(widget.owner.id);
      } else {
        widget.model.pendingCommands[widget.owner.id] = remaining;
      }
      data.busy = false;
      if (mounted) setState(() {});
      widget.model.updateStatus(data.status);
    }
  }

  Future<void> preview({bool review = false}) => operation(() async {
    final l = strings(context);
    final revision = data.revision, target = data.target, value = request();
    rpc.ImportPreview? sampled;
    if (data.importing) {
      sampled = await widget.model.ownedRequest(
        target,
        () => admission(target.backend.client.previewImportAdmission(value)),
      );
      value.sourceSha256 = sampled!.sourceSha256;
    }
    final approval = review
        ? await widget.model.ownedRequest(
            target,
            () => admission(target.backend.client.reviewToolAdmission(value)),
            text: data.kind == rpc.ToolKind.EXPORT_QUERY,
          )
        : null;
    widget.model.requireTarget(
      target,
      text: data.kind == rpc.ToolKind.EXPORT_QUERY,
    );
    if (data.revision != revision) {
      throw StateError(l.transferSettingsChanged);
    }
    data.preview = sampled;
    if (review) {
      data.reviewed = value;
      data.approval = approval;
    }
    data.status = review ? l.transferReviewReady : l.sourcePreviewNotice;
  });
  Future<void> start() => operation(() async {
    final l = strings(context);
    final value = data.reviewed?.deepCopy(), approval = data.approval;
    if (value == null || approval == null) {
      throw StateError(l.transferRequiresReview);
    }
    widget.model.requireTarget(
      data.target,
      text: data.kind == rpc.ToolKind.EXPORT_QUERY,
    );
    value.approvalToken = approval.token;
    data.reviewed = null;
    data.approval = null;
    widget.model.submissions[value.executionId] = widget.owner.id;
    final job = await widget.model.ownedRequest(
      data.target,
      () => admission(data.target.backend.client.toolAdmission(value)),
      text: data.kind == rpc.ToolKind.EXPORT_QUERY,
    );
    data.jobId = job.jobId;
    widget.model.track(job, documentId: widget.owner.id);
    data.status = l.transferSubmittedNotice;
  });
  Future<T> admission<T>(ResponseFuture<T> request) async {
    admissionRequest = request;
    try {
      return await request;
    } finally {
      if (identical(admissionRequest, request)) admissionRequest = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.controls,
        job = widget.model.jobs[data.jobId],
        l = strings(context);
    Widget formAction(
      String label,
      VoidCallback? callback, {
      bool primary = false,
    }) => Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: ui.button(label, callback, primary: primary),
    );
    return WorkbenchForm(
      maxWidth: ui.formContentWidth,
      footer: WorkbenchStrip(
        controls: ui,
        topBorder: true,
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            formAction(
              strings(context).reviewTransfer,
              data.busy || data.path.isEmpty || data.jobId != null
                  ? null
                  : () => preview(review: true),
            ),
            formAction(
              data.importing
                  ? strings(context).startImport
                  : data.kind == rpc.ToolKind.RESTORE
                  ? strings(context).startRestore
                  : strings(context).startExport,
              data.busy || data.approval == null || data.jobId != null
                  ? null
                  : start,
              primary: true,
            ),
            if (data.busy && admissionRequest != null)
              formAction(l.requestCancel, () => admissionRequest?.cancel()),
            if (job != null && !WorkbenchModel.terminalJob(job.state))
              formAction(
                strings(context).requestCancel,
                () => operation(() async {
                  if (!identical(widget.model.backend, data.target.backend)) {
                    throw StateError('The job belongs to a previous backend');
                  }
                  await widget.model.commands!.invoke(
                    'job.cancel',
                    WorkbenchCommandContext(jobId: job.jobId),
                  );
                  data.status = l.transferCancellationNotice;
                }),
              ),
          ],
        ),
      ),
      child: WorkbenchFormList(
        controls: ui,
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            data.importing || data.sourceTarget == null
                ? workbenchTargetCaption(context, data.target)
                : '${data.sourceTarget!.name} · ${data.sourceTarget!.host}:${data.sourceTarget!.port}/${data.sourceTarget!.database} · ${workbenchEnvironment(context, data.sourceTarget!.environment)} · ${strings(context).exportRetained}',
            style: ui.textStyle(context).copyWith(fontWeight: FontWeight.w600),
          ),
          Text(
            data.native
                ? '${l.nativeTool} · ${data.nativeTool}'
                : data.importing
                ? strings(context).sourceMapping
                : data.kind == rpc.ToolKind.EXPORT_QUERY
                ? '${l.exportSql} · ${l.sqlExportExecutionNote}'
                : '${l.exportRetained} · ${data.resultId} · ${l.retainedExportSnapshotNote}',
          ),
          if (data.kind == rpc.ToolKind.RESTORE)
            Text(l.restorePartialCommitNote),
          if (data.sql.isNotEmpty)
            WorkbenchCodeEvidence(controls: ui, text: data.sql),
          if (data.importing && !columnsComplete)
            columnsLoading
                ? Text(l.loading)
                : ui.textButton(l.retry, loadColumns),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(data.path),
          ),
          formAction(
            data.importing || data.kind == rpc.ToolKind.RESTORE
                ? strings(context).chooseSource
                : strings(context).chooseDestination,
            data.jobId != null || data.busy
                ? null
                : () => operation(() async {
                    final revision = data.revision;
                    final path =
                        data.importing || data.kind == rpc.ToolKind.RESTORE
                        ? (await openFile())?.path
                        : (await getSaveLocation(
                            suggestedName: data.native
                                ? 'database.sql'
                                : 'result.csv',
                          ))?.path;
                    if (path != null && mounted) {
                      widget.model.requireTarget(
                        data.target,
                        text: data.kind == rpc.ToolKind.EXPORT_QUERY,
                      );
                      if (revision != data.revision) {
                        throw StateError(l.transferSettingsChanged);
                      }
                      setState(() {
                        data.path = path;
                        data.changed();
                      });
                    }
                  }),
          ),
          if (!data.native)
            ui.comboRow(
              l.fileFormatLabel,
              data.format,
              const {
                'csv': 'CSV',
                'tsv': 'TSV',
                'json': 'JSON array',
                'ndjson': 'NDJSON',
              },
              (v) => setState(() {
                data.format = v;
                data.changed();
              }),
            ),
          if (data.format == 'csv' && !data.native)
            field(
              'delimiter',
              strings(context).delimiterField,
              data.delimiter,
              (s) => data.delimiter = s,
            ),
          if (data.importing) ...[
            Text('${data.schema} / ${data.table}'),
            ui.comboRow(
              l.encodingLabel,
              data.encoding,
              const {
                'UTF-8': 'UTF-8',
                'UTF-16LE': 'UTF-16 LE',
                'UTF-16BE': 'UTF-16 BE',
                'windows-1252': 'Windows 1252',
                'ISO-8859-1': 'ISO 8859-1',
              },
              (v) => setState(() {
                data.encoding = v;
                data.changed();
              }),
            ),
            ui.comboRow(
              l.importPolicyLabel,
              data.policy,
              {
                rpc.ImportPolicy.ATOMIC_IMPORT: l.importAtomicPolicy,
                rpc.ImportPolicy.COMMIT_BATCHES: l.importBatchPolicy,
                rpc.ImportPolicy.SKIP_INVALID_ROWS: l.importSkipPolicy,
              },
              (v) => setState(() {
                data.policy = v;
                data.changed();
              }),
            ),
            field(
              'batch',
              strings(context).batchRowsField,
              '${data.batchRows}',
              (v) => data.batchRows = int.tryParse(v) ?? 0,
            ),
            if (data.policy == rpc.ImportPolicy.SKIP_INVALID_ROWS)
              field(
                'rejects',
                strings(context).rejectedLimit,
                '${data.errorLimit}',
                (v) => data.errorLimit = int.tryParse(v) ?? 0,
              ),
            formAction(
              strings(context).previewSource,
              data.busy || data.path.isEmpty || data.jobId != null
                  ? null
                  : preview,
            ),
            if (data.preview case final sampled?) ...[
              Text(l.immutableSourceHash(sampled.sourceSha256)),
              for (final warning in sampled.warnings) Text(warning),
              SizedBox(
                height: 240,
                child: TableView.builder(
                  pinnedRowCount: 1,
                  rowCount: sampled.rows.length + 1,
                  columnCount: sampled.sourceColumns.length,
                  rowBuilder: (_) => TableSpan(
                    extent: FixedTableSpanExtent(
                      ui.appearance(context).rowHeight(context),
                    ),
                  ),
                  columnBuilder: (_) =>
                      const TableSpan(extent: FixedTableSpanExtent(180)),
                  cellBuilder: (context, vicinity) {
                    final header = vicinity.row == 0;
                    final text = header
                        ? sampled.sourceColumns[vicinity.column]
                        : valueText(
                            sampled.rows[vicinity.row - 1].values[vicinity
                                .column],
                          );
                    return TableViewCell(
                      child: Semantics(
                        label: header
                            ? l.sourceColumnLabel(text)
                            : l.previewRowLabel(
                                '${vicinity.row}',
                                sampled.sourceColumns[vicinity.column],
                                text,
                              ),
                        child: Container(
                          alignment: AlignmentDirectional.centerStart,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: header
                                ? ui.appearance(context).header
                                : ui.appearance(context).view,
                            border: BorderDirectional(
                              bottom: BorderSide(
                                color: ui.appearance(context).gridLine,
                              ),
                              end: BorderSide(
                                color: ui.appearance(context).gridLine,
                              ),
                            ),
                          ),
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ui
                                .textStyle(context)
                                .copyWith(
                                  fontWeight: header ? FontWeight.w600 : null,
                                ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (sampled.limited) Text(l.sourcePreviewLimit),
              SizedBox(
                height: (MediaQuery.sizeOf(context).height / 3).clamp(200, 360),
                child: ListView.separated(
                  key: const ValueKey('transfer-column-mappings'),
                  primary: false,
                  itemCount: columns.length,
                  separatorBuilder: (context, _) => SizedBox(
                    height: 1,
                    child: ColoredBox(color: ui.appearance(context).separator),
                  ),
                  itemBuilder: (context, index) {
                    final column = columns[index];
                    return KeyedSubtree(
                      key: ValueKey('transfer-column-mapping-${column.name}'),
                      child: Semantics(
                        hint:
                            column.properties['generated'] == 'YES' ||
                                column.properties['autoIncrement'] == 'YES'
                            ? l.readonlyCell
                            : column.properties['generated'] != 'NO' ||
                                  column.properties['autoIncrement'] != 'NO'
                            ? l.columnMetadataUnavailable
                            : null,
                        child: ui.tooltip(
                          column.properties['generated'] == 'YES' ||
                                  column.properties['autoIncrement'] == 'YES'
                              ? l.readonlyCell
                              : column.properties['generated'] != 'NO' ||
                                    column.properties['autoIncrement'] != 'NO'
                              ? l.columnMetadataUnavailable
                              : l.sourceMapping,
                          ui.comboRow(
                            column.name,
                            data.mapping[column.name] ?? '',
                            {
                              '': strings(context).defaultOmit,
                              for (final source in sampled.sourceColumns)
                                source: source,
                            },
                            (source) => setState(() {
                              if (source.isEmpty) {
                                data.mapping.remove(column.name);
                              } else {
                                data.mapping[column.name] = source;
                              }
                              data.revision++;
                              data.reviewed = null;
                              data.approval = null;
                            }),
                            enabled:
                                column.properties['generated'] == 'NO' &&
                                column.properties['autoIncrement'] == 'NO',
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            Text(l.importBatchSafetyNote),
          ],
          if (!data.native && (data.format == 'csv' || data.format == 'tsv'))
            field(
              'null',
              l.nullMarkerLiteralNote,
              data.nullMarker,
              (v) => data.nullMarker = v,
            ),
          if (!data.importing && data.kind != rpc.ToolKind.RESTORE)
            ui.choice(
              data.overwrite,
              {
                false: strings(context).overwriteNever,
                true: strings(context).overwriteExisting,
              },
              (v) => setState(() {
                data.overwrite = v;
                data.changed();
              }),
            ),
          if (data.approval case final approval?) ...[
            for (final sql in approval.statements)
              WorkbenchCodeEvidence(controls: ui, text: sql),
            for (final risk in approval.risks) Text(risk),
            Text(l.sourceMapping),
            for (final entry in data.mapping.entries)
              Text('${entry.key} → ${entry.value}'),
            Text(l.immutableSourceHash(data.reviewed?.sourceSha256 ?? '')),
          ],
          Text(data.status),
          if (job != null) ...[
            Text(
              '${workbenchJobState(context, job.state)} · ${job.durationMs} ms · ${l.transferProgress('${job.progressRows}', '${job.committedRows}', '${job.rejectedRows}')} ',
            ),
            for (final message in job.messages) SelectableText(message),
          ],
        ],
      ),
    );
  }
}
