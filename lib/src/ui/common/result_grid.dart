import 'result_display_format_dialog.dart';
import 'result_cell_identity.dart';
import 'result_presentation_target.dart';
import '../../backend/tool_admission_requests.dart';
import 'package:flutter/material.dart' show SelectableText;
import 'presentation_diagnostics.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart' show kPrimaryButton, kSecondaryButton;
import 'package:flutter/widgets.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../backend/workbench_failure.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'result_extractors.dart';
import 'exact_text_clipboard.dart';
import 'result_presentations.dart';
import 'result_value_editor.dart';
import 'result_operations.dart';
import 'result_staged_insert.dart';
import '../../features/results/result_presentation.dart';
import '../../features/results/value_assignments.dart';
import '../../features/results/complete_value.dart';
import '../../features/results/result_editability_request.dart';

export 'result_extractors.dart';

class ResultGrid extends StatefulWidget {
  const ResultGrid({
    super.key,
    required this.model,
    required this.controls,
    required this.result,
    this.outputControls,
    this.selectValueDestination,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final rpc.StatementResult result;

  /// Controls owned by the output container, also available without a grid.
  final Widget? outputControls;
  final Future<String?> Function(String suggestedName)? selectValueDestination;
  @override
  State<ResultGrid> createState() => _ResultGridState();
}

class _ResultGridState extends State<ResultGrid> {
  final _retainedControls = <String, ({Object signature, Widget widget})>{};
  Widget retainControls(
    String key,
    Object signature,
    Widget Function() create,
  ) {
    final previous = _retainedControls[key];
    if (previous?.signature == signature) {
      PresentationDiagnostics.count('grid-$key-retention-hit');
      return previous!.widget;
    }
    PresentationDiagnostics.count('grid-$key-retention-miss');
    final widget = create();
    _retainedControls[key] = (signature: signature, widget: widget);
    return widget;
  }

  late ResultViewState view;
  rpc.Editability? assessment;
  CapturedWorkbenchTarget? assessedTarget;
  int assessmentRevision = 0;
  ResultEditabilityRequest? _pendingAssessment;
  bool get canEdit {
    if (assessment?.editable != true || assessedTarget == null) return false;
    final batch = widget
        .model
        .editBatches['${owner.id}\u0000${widget.model.sourceResultId(widget.result.resultId)}'];
    if (batch != null &&
        (batch.appliedSnapshot ||
            batch.applying ||
            batch.discarding ||
            batch.outcomeUnknown)) {
      return false;
    }
    try {
      widget.model.requireTarget(assessedTarget!);
      final session = widget.model.sessions[assessedTarget!.sessionId];
      return session != null &&
          session.transaction != rpc.TransactionState.UNKNOWN_TRANSACTION &&
          session.transaction != rpc.TransactionState.DISCONNECTED;
    } catch (_) {
      return false;
    }
  }

  final cellEditor = TextEditingController();
  final cellFocus = FocusNode(debugLabel: 'Inline value editor');
  int? editingRow, editingColumn;
  late WorkbenchDocument owner;
  Future<void> assess() {
    final model = widget.model, process = widget.model.backend;
    final capturedOwner = owner;
    if (process == null ||
        owner.sessionId == null ||
        widget.result.columns.isEmpty) {
      assessmentRevision++;
      return Future<void>.value();
    }
    final resultId = widget.result.resultId;
    final source = model.sourceResultId(widget.result.resultId);
    final CapturedWorkbenchTarget captured;
    try {
      captured = model.captureTarget(owner: capturedOwner);
    } catch (error) {
      assessmentRevision++;
      if (mounted) _assessmentFailed(error);
      return Future<void>.value();
    }
    final metadata = model.metadataStampForSession(captured.sessionId ?? '');
    final previous = _pendingAssessment;
    if (previous != null &&
        previous.revision == assessmentRevision &&
        previous.matches(
          model: model,
          owner: capturedOwner,
          target: captured,
          resultId: resultId,
          sourceId: source,
          columns: widget.result.columns,
          metadata: metadata,
        )) {
      return previous.completion.future;
    }
    final pending = ResultEditabilityRequest(
      model: model,
      owner: capturedOwner,
      target: captured,
      resultId: resultId,
      sourceId: source,
      columns: widget.result.columns,
      metadata: metadata,
      revision: ++assessmentRevision,
    );
    _pendingAssessment = pending;
    unawaited(
      _assess(pending).then(
        (_) => pending.completion.complete(),
        onError: (Object error, StackTrace stack) =>
            pending.completion.completeError(error, stack),
      ),
    );
    return pending.completion.future;
  }

  void _assessmentFailed(Object error) {
    final reason = WorkbenchFailureReason.fromError(error);
    setState(() {
      assessment = rpc.Editability(
        reasonCode: reason?.wire ?? '',
        reason: reason == null
            ? strings(context).editAssessmentUnavailable
            : '',
      );
      assessedTarget = null;
    });
  }

  Future<void> _assess(ResultEditabilityRequest pending) async {
    final model = pending.model, process = pending.target.backend;
    bool current() {
      if (!mounted ||
          assessmentRevision != pending.revision ||
          !identical(widget.model, model) ||
          !identical(model.backend, process) ||
          !identical(owner, pending.owner) ||
          widget.result.resultId != pending.resultId ||
          model.sourceResultId(widget.result.resultId) != pending.sourceId ||
          widget.result.columns.isEmpty) {
        return false;
      }
      return pending.matches(
        model: model,
        owner: owner,
        target: model.captureTarget(owner: owner),
        resultId: widget.result.resultId,
        sourceId: model.sourceResultId(widget.result.resultId),
        columns: widget.result.columns,
        metadata: model.metadataStampForSession(pending.target.sessionId ?? ''),
      );
    }

    try {
      final reply = await process.client.assessEditability(
        rpc.ChangeRequest(
          context: process.context(),
          sessionId: pending.target.sessionId,
          resultId: pending.sourceId,
          catalog: pending.column.catalog,
          schema: pending.column.schema.isEmpty
              ? pending.column.catalog
              : pending.column.schema,
          table: pending.column.table,
        ),
      );
      if (!current()) return;
      model.requireTarget(pending.target);
      setState(() {
        assessment = reply;
        assessedTarget = pending.target;
      });
    } catch (error) {
      if (current()) _assessmentFailed(error);
    } finally {
      if (identical(_pendingAssessment, pending)) _pendingAssessment = null;
    }
  }

  bool editableCell(rpc.Value? value, rpc.Column column) =>
      value != null &&
      canEdit &&
      assessment!.editableColumns.contains(column.ordinal) &&
      !value.truncated &&
      !value.hasBinary() &&
      !value.hasArray() &&
      !value.hasEngineValue();

  String editDisabledReason(rpc.Value? value, rpc.Column column) {
    final l = strings(context);
    if (value == null) return l.loadValueFirst;
    if (!canEdit) {
      final code = assessment?.reasonCode ?? '';
      if (code.isNotEmpty) {
        return WorkbenchFailureReason.fromWire(code)?.localized(l) ??
            l.editUnavailable;
      }
      return assessment?.reason.isNotEmpty == true
          ? assessment!.reason
          : l.editUnavailable;
    }
    if (!assessment!.editableColumns.contains(column.ordinal) ||
        column.readOnly) {
      return l.readonlyCell;
    }
    return l.unsupportedEditValue;
  }

  void editCell(int row, int column) {
    final value = widget.model.row(widget.result.resultId, row)?.values[column];
    if (value == null) return;
    if (!editableCell(value, widget.result.columns[column])) {
      inspect(
        value,
        widget.result.columns[column],
        row: row,
        columnIndex: column,
      );
      return;
    }
    setState(() {
      editingRow = row;
      editingColumn = column;
      final source = widget.model.sourceResultId(widget.result.resultId);
      final sourceRow = widget.model.sourceRow(widget.result.resultId, row);
      final batch = widget.model.editBatches['${owner.id}\u0000$source'];
      final changed = batch?.changes
          .where(
            (c) =>
                c.kind == rpc.ChangeKind.UPDATE &&
                c.sourceRow.toInt() == sourceRow,
          )
          .firstOrNull
          ?.values[widget.result.columns[column].ordinal];
      final shown = assignmentValue(changed) ?? value;
      cellEditor.text =
          view.presentation.draft(
            sourceRow,
            widget.result.columns[column].ordinal,
          ) ??
          (shown.hasNullValue() ? '' : valueText(shown));
    });
    cellFocus.requestFocus();
  }

  rpc.ValueAssignment? assignmentAt(int row, int column) {
    final sourceRow = widget.model.sourceRow(widget.result.resultId, row);
    return widget
        .model
        .editBatches['${owner.id}\u0000${widget.model.sourceResultId(widget.result.resultId)}']
        ?.changes
        .where(
          (c) =>
              c.kind == rpc.ChangeKind.UPDATE &&
              c.sourceRow.toInt() == sourceRow,
        )
        .firstOrNull
        ?.values[widget.result.columns[column].ordinal];
  }

  rpc.Value? presentedValue(int row, int column) =>
      assignmentValue(assignmentAt(row, column)) ?? cellValue(row, column);

  Future<void> stageAssignment(
    int row,
    int column,
    rpc.ValueAssignment assignment,
  ) async {
    final model = widget.model, metadata = widget.result.columns[column];
    final original = model.row(widget.result.resultId, row);
    if (!canEdit ||
        original == null ||
        !assessment!.editableColumns.contains(metadata.ordinal) ||
        !model.operationOwners.contains(owner)) {
      throw StateError(strings(context).editContextChanged);
    }
    final source = model.sourceResultId(widget.result.resultId),
        sourceRow = model.sourceRow(widget.result.resultId, row);
    final batch = model.editBatches.putIfAbsent(
      '${owner.id}\u0000$source',
      () => OwnedEditBatch(owner.id, source),
    );
    batch.sessionId = owner.sessionId;
    batch.documentId = owner.id;
    batch.schema = metadata.schema.isEmpty ? metadata.catalog : metadata.schema;
    batch.table = metadata.table;
    model.stageChange(
      batch,
      rpc.StagedChange(
        kind: rpc.ChangeKind.UPDATE,
        sourceRow: Int64(sourceRow),
        values: {metadata.ordinal: assignment}.entries,
      ),
      original: original,
    );
    model.updateStatus(
      strings(context).pendingChangesCount('${batch.changes.length}'),
    );
    await model.persistStagedEdits(batch: batch);
    view.presentation.clearDraft(sourceRow, metadata.ordinal);
  }

  void stageCell({bool nullValue = false, bool defaultValue = false}) {
    final row = editingRow, column = editingColumn;
    if (row == null || column == null) return;
    if (cellEditor.text.length > 8192) {
      widget.model.updateStatus(strings(context).inlineValueLimit);
      return;
    }
    final retained = cellValue(row, column);
    final value =
        retained != null &&
            !retained.hasNullValue() &&
            cellEditor.text == valueText(retained)
        ? retained.deepCopy()
        : rpc.Value(text: cellEditor.text);
    final pending = stageAssignment(
      row,
      column,
      defaultValue
          ? assignmentDefault()
          : nullValue
          ? assignmentNull()
          : assignmentOf(value),
    );
    setState(() => editingRow = editingColumn = null);
    focus.requestFocus();
    pending.catchError((Object error) => widget.model.updateStatus('$error'));
  }

  Future<void> editStagedInsert(OwnedEditBatch batch, int index) async {
    if (!canEdit ||
        index < 0 ||
        index >= batch.changes.length ||
        batch.changes[index].kind != rpc.ChangeKind.INSERT) {
      return;
    }
    final captured = widget.model.captureTarget(owner: owner),
        resultId = widget.result.resultId;
    await widget.controls.dialog<void>(
      context,
      strings(context).stageInsert,
      StagedInsertEditor(
        model: widget.model,
        controls: widget.controls,
        batch: batch,
        index: index,
        columns: widget.result.columns,
        editableOrdinals: assessment!.editableColumns,
        validateOwner: () {
          widget.model.requireTarget(captured);
          if (!mounted || widget.result.resultId != resultId || !canEdit) {
            throw StateError(strings(context).staleContext);
          }
        },
      ),
      [
        widget.controls.button(
          strings(context).close,
          () => Navigator.of(context).pop(),
        ),
      ],
      bodyScrolls: true,
    );
  }

  Future<void> stagedInserts() async {
    final batch = widget
        .model
        .editBatches['${owner.id}\u0000${widget.model.sourceResultId(widget.result.resultId)}'];
    if (batch == null) return;
    final index = await widget.controls.dialog<int>(
      context,
      strings(context).stageInsert,
      WorkbenchDialogBody(
        maxHeight: 300,
        child: ListView(
          children: [
            for (var i = 0; i < batch.changes.length; i++)
              if (batch.changes[i].kind == rpc.ChangeKind.INSERT)
                widget.controls.textButton(
                  '${strings(context).stageInsert} ${i + 1}',
                  () => Navigator.of(context).pop(i),
                ),
          ],
        ),
      ),
      [
        widget.controls.button(
          strings(context).cancel,
          () => Navigator.of(context).pop(),
        ),
      ],
      bodyScrolls: true,
    );
    if (index != null && mounted) await editStagedInsert(batch, index);
  }

  ResultOperations operations() {
    final resultId = widget.result.resultId,
        row = selectedRow,
        column = selectedColumn,
        anchor = (anchorRow, anchorColumn);
    return ResultOperations(
      model: widget.model,
      controls: widget.controls,
      context: context,
      owner: owner,
      result: widget.result,
      selectedRow: row,
      selectedColumn: column,
      anchorRow: anchor.$1,
      anchorColumn: anchor.$2,
      visibleColumns: visibleColumnIndices,
      editInsert: editStagedInsert,
      current: () =>
          mounted &&
          widget.result.resultId == resultId &&
          selectedRow == row &&
          selectedColumn == column &&
          (anchorRow, anchorColumn) == anchor &&
          widget.model.operationOwners.contains(owner),
    );
  }

  Map<ResultPresentation, String> presentationNames() {
    final l = strings(context);
    return {
      ResultPresentation.table: l.resultTable,
      ResultPresentation.transpose: l.resultTranspose,
      ResultPresentation.tree: l.resultTree,
      ResultPresentation.text: l.resultText,
    };
  }

  void setPresentation(ResultPresentation mode) {
    if (editingRow != null && editingColumn != null) {
      view.presentation.retainDraft(
        widget.model.sourceRow(widget.result.resultId, editingRow!),
        widget.result.columns[editingColumn!].ordinal,
        cellEditor.text,
      );
      editingRow = editingColumn = null;
    }
    saveView();
    setState(() => view.presentation.mode = mode);
  }

  Map<ColumnDisplayFormat, String> displayFormatNames() {
    final l = strings(context);
    return {
      ColumnDisplayFormat.canonical: l.canonicalValue,
      ColumnDisplayFormat.grouped: l.groupedNumber,
      ColumnDisplayFormat.decimal2: l.numericScale2,
      ColumnDisplayFormat.decimal4: l.numericScale4,
      ColumnDisplayFormat.isoDate: l.temporalDate,
      ColumnDisplayFormat.isoTime: l.temporalTime,
      ColumnDisplayFormat.utc: l.temporalUtc,
      ColumnDisplayFormat.local: l.temporalLocal,
      ColumnDisplayFormat.json: l.jsonPretty,
      ColumnDisplayFormat.hexadecimal: l.binaryHex,
      ColumnDisplayFormat.base64: l.binaryBase64,
      ColumnDisplayFormat.uuid: l.uuidPresentation,
      ColumnDisplayFormat.wrap: l.wrapText,
      ColumnDisplayFormat.temporalPattern: l.temporalCustomPattern,
    };
  }

  String storedFormat(ColumnDisplayFormat format) => format.name;
  rpc.Profile? get presentationProfile =>
      widget
          .model
          .retainedResults[widget.model.sourceResultId(widget.result.resultId)]
          ?.target ??
      owner.evidenceProfile ??
      widget.model.sessions[owner.sessionId]?.profile;
  void loadDisplayFormats() {
    final model = widget.model;
    final profile = presentationProfile;
    if (profile == null) return;
    for (var i = 0; i < widget.result.columns.length; i++) {
      final key = model.resultDisplayFormatKey(
        profile,
        widget.result.columns[i],
      );
      final stored = model.resultDisplayFormats[key];
      if (stored == null) continue;
      final pattern = TemporalDisplayPattern.parse(stored);
      if (pattern != null) {
        view.presentation.formats[i] = ColumnDisplayFormat.temporalPattern;
        view.presentation.temporalPatterns[i] = pattern;
        continue;
      }
      view.presentation.formats[i] =
          ColumnDisplayFormat.values
              .where((format) => storedFormat(format) == stored)
              .firstOrNull ??
          ColumnDisplayFormat.canonical;
    }
  }

  Future<void> chooseDisplayFormat() async {
    final l = strings(context), model = widget.model;
    final capturedResult = widget.result, capturedView = view;
    final target = CapturedResultPresentation(
      model,
      owner,
      capturedResult,
      capturedView,
    );
    bool current() =>
        mounted &&
        target.matches(
          model: widget.model,
          owner: owner,
          result: widget.result,
          view: view,
        );
    final profile = presentationProfile?.deepCopy();
    final accepted = await widget.controls.dialog<ResultDisplayChoice>(
      context,
      l.displayFormat,
      ResultDisplayFormatDialog(
        controls: widget.controls,
        columns: capturedResult.columns,
        initialColumn: selectedColumn,
        formats: Map.of(capturedView.presentation.formats),
        patterns: Map.of(capturedView.presentation.temporalPatterns),
        names: displayFormatNames(),
      ),
      [],
    );
    if (accepted == null || !current()) {
      return;
    }
    final selected = accepted.column;
    if (profile != null) {
      await model.setResultDisplayFormat(
        profile,
        capturedResult.columns[selected],
        accepted.pattern?.stored ?? storedFormat(accepted.format),
      );
    }
    if (!current()) {
      return;
    }
    setState(() {
      view.presentation.formats[selected] = accepted.format;
      if (accepted.pattern != null) {
        view.presentation.temporalPatterns[selected] = accepted.pattern!;
      }
      widthVersion++;
    });
  }

  Future<void> retainedView(bool sort) async {
    final ui = widget.controls, model = widget.model;
    final l = strings(context);
    final source = model.sourceResultId(widget.result.resultId),
        backend = model.backend;
    final captured = owner.kind == WorkbenchDocumentKind.table
        ? model.captureTarget(owner: owner)
        : null;
    final value = TextEditingController();
    var selected = selectedColumn,
        descending = false,
        predicate = rpc.ValuePredicate.EQUAL;
    try {
      final accepted = await ui.dialog<bool>(
        context,
        owner.kind == WorkbenchDocumentKind.table
            ? (sort ? l.sortTable : l.filterTable)
            : (sort ? l.sortRetained : l.filterRetained),
        StatefulBuilder(
          builder: (context, set) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                owner.kind == WorkbenchDocumentKind.table
                    ? strings(context).tableFilterNote
                    : strings(context).retainedFilterNote,
              ),
              ui.choice(selected, {
                for (var i = 0; i < widget.result.columns.length; i++)
                  i: '${i + 1} · ${widget.result.columns[i].name}',
              }, (v) => set(() => selected = v)),
              if (sort)
                ui.choice(descending, {
                  false: l.ascending,
                  true: l.descending,
                }, (v) => set(() => descending = v))
              else ...[
                ui.choice(predicate, {
                  rpc.ValuePredicate.EQUAL: l.equals,
                  rpc.ValuePredicate.NOT_EQUAL: l.notEqual,
                  rpc.ValuePredicate.LESS: l.lessThan,
                  rpc.ValuePredicate.GREATER: l.greaterThan,
                  rpc.ValuePredicate.IS_NULL: l.isNull,
                  rpc.ValuePredicate.IS_NOT_NULL: l.isNotNull,
                }, (v) => set(() => predicate = v)),
                ui.field(value, l.exactValue),
              ],
            ],
          ),
        ),
        [
          ui.button(l.cancel, () => Navigator.of(context).pop(false)),
          ui.button(
            l.applyView,
            () => Navigator.of(context).pop(true),
            primary: true,
          ),
        ],
      );
      if (accepted != true || !mounted) return;
      if (!identical(backend, model.backend) ||
          !model.operationOwners.contains(owner)) {
        throw StateError(
          'The retained-view owner changed; reopen the controls',
        );
      }
      if (captured != null) model.requireTarget(captured);
      final state = model.resultView(
        model.sourceResultId(widget.result.resultId),
        owner: owner,
      );
      final tableData = owner.kind == WorkbenchDocumentKind.table;
      final condition = rpc.RowCondition(
        column: operationColumn(selected),
        predicate: predicate,
        value:
            sort ||
                predicate == rpc.ValuePredicate.IS_NULL ||
                predicate == rpc.ValuePredicate.IS_NOT_NULL
            ? rpc.Value(nullValue: rpc.Null())
            : tableData &&
                  const [
                    1111,
                    2003,
                    2002,
                    2006,
                  ].contains(widget.result.columns[selected].jdbcType) &&
                  !const ['json', 'jsonb'].contains(
                    widget.result.columns[selected].typeName.toLowerCase(),
                  )
            ? rpc.Value(text: value.text)
            : retainedFilterValue(widget.result.columns[selected], value.text),
      );
      if (tableData) {
        final conditions = sort ? owner.view.tableConditions : [condition];
        final order = sort
            ? [
                rpc.RowOrder(
                  column: widget.result.columns[selected].baseColumn,
                  descending: descending,
                ),
              ]
            : owner.view.tableOrder;
        await model.commands!.invoke(
          'object.refresh',
          WorkbenchCommandContext(
            owner: owner,
            object: owner.object,
            profileId: owner.profileId,
            sessionId: owner.sessionId,
            tableConditions: conditions,
            tableOrder: order,
          ),
        );
      } else {
        await model.createResultView(
          sort ? state.conditions : [condition],
          sort
              ? [
                  rpc.RowOrder(
                    column: operationColumn(selected),
                    descending: descending,
                  ),
                ]
              : state.order,
          targetOwner: owner,
          resultId: source,
        );
      }
    } finally {
      value.dispose();
    }
  }

  String operationColumn(int index) => owner.kind == WorkbenchDocumentKind.table
      ? widget.result.columns[index].baseColumn
      : '#${index + 1}';

  Future<void> sortColumn(int index) async {
    final column = operationColumn(index);
    final previous = owner.kind == WorkbenchDocumentKind.table
        ? owner.view.tableOrder
        : view.order;
    final order = [
      rpc.RowOrder(
        column: column,
        descending:
            previous.length == 1 &&
            previous.single.column == column &&
            !previous.single.descending,
      ),
    ];
    if (owner.kind == WorkbenchDocumentKind.table) {
      await widget.model.commands!.invoke(
        'object.refresh',
        WorkbenchCommandContext(
          owner: owner,
          object: owner.object,
          profileId: owner.profileId,
          sessionId: owner.sessionId,
          tableConditions: owner.view.tableConditions,
          tableOrder: order,
        ),
      );
    } else {
      await widget.model.createResultView(
        view.conditions,
        order,
        targetOwner: owner,
        resultId: widget.model.sourceResultId(widget.result.resultId),
      );
    }
  }

  Future<void> filterSelectedCell() async {
    final value = cellValue(selectedRow, selectedColumn);
    if (value == null || value.truncated) return;
    final condition = rpc.RowCondition(
      column: operationColumn(selectedColumn),
      predicate: value.hasNullValue()
          ? rpc.ValuePredicate.IS_NULL
          : rpc.ValuePredicate.EQUAL,
      value: value.deepCopy(),
    );
    if (owner.kind == WorkbenchDocumentKind.table) {
      await widget.model.commands!.invoke(
        'object.refresh',
        WorkbenchCommandContext(
          owner: owner,
          object: owner.object,
          profileId: owner.profileId,
          sessionId: owner.sessionId,
          tableConditions: [condition],
          tableOrder: owner.view.tableOrder,
        ),
      );
    } else {
      await widget.model.createResultView(
        [condition],
        view.order,
        targetOwner: owner,
        resultId: widget.model.sourceResultId(widget.result.resultId),
      );
    }
  }

  rpc.Value? cellValue(int row, int column) {
    if (column < 0 || column >= widget.result.columns.length) return null;
    final values = widget.model.row(widget.result.resultId, row)?.values;
    return values != null && column < values.length ? values[column] : null;
  }

  List<int> get visibleColumnIndices => [
    for (var column = 0; column < widget.result.columns.length; column++)
      if (!view.hiddenColumns.contains(column)) column,
  ];

  void normalizeSelection() {
    if (widget.result.columns.isEmpty) return;
    final before = (selectedRow, selectedColumn, anchorRow, anchorColumn);
    view.hiddenColumns.removeWhere(
      (column) => column < 0 || column >= widget.result.columns.length,
    );
    final visible = visibleColumnIndices;
    if (visible.isEmpty && widget.result.columns.isNotEmpty) {
      view.hiddenColumns.remove(0);
      visible.add(0);
    }
    int nearest(int column) => visible.isEmpty
        ? 0
        : visible.contains(column)
        ? column
        : visible.firstWhere(
            (candidate) => candidate >= column,
            orElse: () => visible.last,
          );
    selectedColumn = nearest(selectedColumn);
    anchorColumn = nearest(anchorColumn);
    final last = math.max(0, widget.result.fetchedRows.toInt() - 1);
    selectedRow = selectedRow.clamp(0, last);
    anchorRow = anchorRow.clamp(0, last);
    view.selectedColumn = selectedColumn;
    view.anchorColumn = anchorColumn;
    view.selectedRow = selectedRow;
    view.anchorRow = anchorRow;
    if (before != (selectedRow, selectedColumn, anchorRow, anchorColumn)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) revealSelection();
      });
    }
  }

  int selectedRow = 0, selectedColumn = 0, anchorRow = 0, anchorColumn = 0;
  final widths = <int, double>{};
  final focus = FocusNode(debugLabel: 'Result grid');
  final headerFocus = FocusScopeNode(debugLabel: 'Grid commands');
  bool recordCellFocused = false;
  bool get cellFocusActive =>
      focus.hasPrimaryFocus &&
      !headerFocus.hasFocus &&
      (!view.presentation.recordVisible || !recordCellFocused);
  final vertical = ScrollController(), horizontal = ScrollController();
  String format = 'text';
  double rowHeight = 32;
  double headerHeight = 32;
  int get windowRows => widget.model.resultWindowRows(widget.result.resultId);
  int _lastWindowRows = 256;
  int windowStart = 0;
  int widthVersion = 0;
  Object? tableSignature;
  Widget? retainedTable;
  Widget table(Object signature, Widget Function() create) {
    if (tableSignature == signature) return retainedTable!;
    tableSignature = signature;
    return retainedTable = create();
  }

  final jump = TextEditingController(text: '1');
  @override
  void initState() {
    super.initState();
    focus.addListener(_focusChanged);
    headerFocus.addListener(_focusChanged);
    owner = widget.model.activeOwner;
    view = widget.model.resultView(widget.result.resultId, owner: owner);
    assess();
    loadDisplayFormats();
    selectedRow = view.selectedRow;
    selectedColumn = view.selectedColumn;
    anchorRow = view.anchorRow;
    anchorColumn = view.anchorColumn;
    windowStart = view.windowStart;
    widths.addAll(view.widths);
    view.selectedRow = selectedRow;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (vertical.hasClients) {
        vertical.jumpTo(
          view.verticalOffset.clamp(0, vertical.position.maxScrollExtent),
        );
      }
      if (horizontal.hasClients) {
        horizontal.jumpTo(
          view.horizontalOffset.clamp(0, horizontal.position.maxScrollExtent),
        );
      }
    });
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ResultGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result.resultId == widget.result.resultId) {
      if ((!oldWidget.result.complete && widget.result.complete) ||
          oldWidget.result.columns.length != widget.result.columns.length) {
        assess();
      }
      return;
    }
    saveView();
    view = widget.model.resultView(widget.result.resultId, owner: owner);
    windowStart = view.windowStart;
    selectedRow = view.selectedRow;
    selectedColumn = view.selectedColumn;
    anchorRow = view.anchorRow;
    anchorColumn = view.anchorColumn;
    widths
      ..clear()
      ..addAll(view.widths);
    assessment = null;
    loadDisplayFormats();
    editingRow = editingColumn = null;
    assess();
    widthVersion++;
    jump.text = '1';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revealSelection();
    });
  }

  void saveView() {
    view.selectedRow = selectedRow;
    view.selectedColumn = selectedColumn;
    view.anchorRow = anchorRow;
    view.anchorColumn = anchorColumn;
    view.windowStart = windowStart;
    view.widths
      ..clear()
      ..addAll(widths);
    if (vertical.hasClients) view.verticalOffset = vertical.offset;
    if (horizontal.hasClients) view.horizontalOffset = horizontal.offset;
  }

  @override
  void dispose() {
    saveView();
    if (widget.model.resultActionSources[owner.id] == widget.result.resultId) {
      widget.model.resultActions.remove(owner.id);
      widget.model.resultActionSources.remove(owner.id);
    }
    cellEditor.dispose();
    cellFocus.dispose();
    focus.removeListener(_focusChanged);
    headerFocus.removeListener(_focusChanged);
    headerFocus.dispose();
    focus.dispose();
    vertical.dispose();
    horizontal.dispose();
    jump.dispose();
    super.dispose();
  }

  void revealSelection() {
    if (vertical.hasClients) {
      final position = vertical.position;
      final top = (selectedRow - windowStart) * rowHeight;
      final available = math.max(
        0.0,
        position.viewportDimension - headerHeight,
      );
      final desired = top < position.pixels
          ? top
          : top + rowHeight > position.pixels + available
          ? top + rowHeight - available
          : position.pixels;
      vertical.jumpTo(
        desired.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
    if (horizontal.hasClients) {
      final position = horizontal.position;
      final left = visibleColumnIndices
          .takeWhile((column) => column != selectedColumn)
          .fold(0.0, (sum, column) => sum + (widths[column] ?? 180.0));
      final right = left + (widths[selectedColumn] ?? 180.0);
      final desired = left < position.pixels
          ? left
          : right > position.pixels + position.viewportDimension
          ? right - position.viewportDimension
          : position.pixels;
      horizontal.jumpTo(
        desired.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }
  }

  Future<void> inspect(
    rpc.Value value,
    rpc.Column column, {
    int? row,
    int? columnIndex,
  }) async {
    final model = widget.model, backend = widget.model.backend;
    final resultId = widget.result.resultId;
    final capturedView = view;
    final presentationOwner = CapturedResultPresentation(
      model,
      owner,
      widget.result,
      capturedView,
    );
    final retainedSource = model.sourceResultId(resultId);
    final index = columnIndex ?? widget.result.columns.indexOf(column);
    final sourceRow = row == null ? null : model.sourceRow(resultId, row);
    final captured = backend == null ? null : model.captureTarget(owner: owner);
    void requireOwner() {
      if (captured != null) {
        try {
          model.requireTarget(captured);
        } catch (_) {
          throw const RetainedValueOwnerChanged();
        }
      }
      if (!mounted ||
          !presentationOwner.matches(
            model: widget.model,
            owner: owner,
            result: widget.result,
            view: view,
          ) ||
          !identical(model.backend, backend) ||
          widget.result.resultId != resultId ||
          model.disposedResults.contains(resultId) ||
          model.disposedResults.contains(retainedSource)) {
        throw const RetainedValueOwnerChanged();
      }
      if (row != null && sourceRow != model.sourceRow(resultId, row)) {
        throw const RetainedValueOwnerChanged();
      }
    }

    final editable =
        row != null &&
        index >= 0 &&
        canEdit &&
        assessment!.editableColumns.contains(column.ordinal) &&
        !column.readOnly &&
        (!value.truncated || completeValueEligible(value));
    Future<void> stage(rpc.ValueAssignment assignment) async {
      requireOwner();
      await stageAssignment(row!, index, assignment);
    }

    Future<void> Function()? cancelValueRead;
    await widget.controls.dialog<void>(
      context,
      '${column.name} · ${column.typeName}',
      ResultValueEditor(
        controls: widget.controls,
        value: value.deepCopy(),
        column: column,
        initialDraft: sourceRow == null
            ? null
            : capturedView.presentation.draft(sourceRow, column.ordinal),
        initialBinaryDraft: sourceRow == null
            ? null
            : capturedView.presentation.binaryDraft(sourceRow, column.ordinal),
        initialPresentation: sourceRow == null
            ? null
            : capturedView.presentation.draftFormat(sourceRow, column.ordinal),
        readChunk: captured == null
            ? null
            : (offset) async {
                requireOwner();
                final call = captured.backend.client.resultValue(
                  rpc.ValueRequest(
                    context: captured.backend.context(),
                    resultId: retainedSource,
                    valueId: value.valueId,
                    offset: Int64(offset),
                    maxBytes: 65536,
                  ),
                );
                cancelValueRead = call.cancel;
                final response = await call;
                requireOwner();
                return response;
              },
        cancelRead: () {
          final cancel = cancelValueRead;
          if (cancel != null) unawaited(cancel());
        },
        retainDraft: (text, format) {
          if (sourceRow != null) {
            capturedView.presentation.retainDraft(
              sourceRow,
              column.ordinal,
              text,
              format,
            );
          }
        },
        retainBinaryDraft: (draft) {
          if (sourceRow != null) {
            capturedView.presentation.retainBinaryDraft(
              sourceRow,
              column.ordinal,
              draft,
            );
          }
        },
        stage: editable ? (value) => stage(assignmentOf(value)) : null,
        stageNull: editable ? () => stage(assignmentNull()) : null,
        stageDefault: editable ? () => stage(assignmentDefault()) : null,
      ),
      [
        if (backend != null && value.valueId.isNotEmpty)
          widget.controls.button(
            '${strings(context).exportFullValue} (${strings(context).bytesCount(value.originalBytes.toString())})',
            () => saveValue(value),
          ),
        widget.controls.button(
          strings(context).close,
          () => Navigator.of(context).pop(),
        ),
      ],
      bodyScrolls: true,
    );
  }

  Future<void> copy() async {
    final l = strings(context);
    final lines = <List<rpc.Value>>[];
    normalizeSelection();
    if (widget.result.fetchedRows == Int64.ZERO ||
        visibleColumnIndices.isEmpty) {
      return;
    }
    final firstRow = math.min(selectedRow, anchorRow),
        lastRow = math.max(selectedRow, anchorRow);
    final firstCol = math.min(selectedColumn, anchorColumn),
        lastCol = math.max(selectedColumn, anchorColumn);
    final copyColumns = visibleColumnIndices
        .where((column) => column >= firstCol && column <= lastCol)
        .toList();
    if ((lastRow - firstRow + 1) * copyColumns.length > 10000) {
      widget.model.updateStatus(l.copyLimitNote);
      return;
    }
    if (format == 'sql') {
      final backend = widget.model.backend;
      final resultId = widget.result.resultId;
      if (backend == null) {
        widget.model.updateStatus(l.sqlCopyRequiresMetadata);
        return;
      }
      try {
        final groups = <List<int>>[];
        for (final column in copyColumns) {
          if (groups.isEmpty || groups.last.last + 1 != column) groups.add([]);
          groups.last.add(column);
        }
        final fragments = <List<String>>[];
        final output = ResultCopyBuffer();
        final incoming = ResultCopyBuffer();
        for (final columns in groups) {
          final copied = await backend.client.copySql(
            rpc.CopySqlRequest(
              context: backend.context(),
              resultId: resultId,
              firstRow: Int64(firstRow),
              rowCount: lastRow - firstRow + 1,
              firstColumn: columns.first,
              columnCount: columns.length,
            ),
          );
          if (!mounted ||
              !identical(widget.model.backend, backend) ||
              widget.result.resultId != resultId ||
              widget.model.disposedResults.contains(resultId)) {
            throw StateError(l.staleContext);
          }
          if (groups.length == 1) {
            output.append(copied.text);
          } else {
            incoming.account(copied.text);
            final tuples = splitGeneratedSqlCopyRows(copied.text);
            if (tuples.length != lastRow - firstRow + 1) {
              throw const FormatException('Generated SQL row count changed');
            }
            fragments.add(tuples);
          }
        }
        if (groups.length > 1) {
          for (var row = 0; row <= lastRow - firstRow; row++) {
            if (row > 0) output.append(',\n');
            output.append('(');
            for (var group = 0; group < fragments.length; group++) {
              if (group > 0) output.append(', ');
              output.append(fragments[group][row]);
            }
            output.append(')');
          }
        }
        await writeExactTextClipboard(output.text.toString());
      } on TextClipboardUnavailable catch (error) {
        widget.model.updateStatus(
          error.reason == TextClipboardUnavailableReason.embeddedNul
              ? l.textClipboardNulUnavailable
              : l.presentationScopeLimit,
        );
      } catch (error) {
        widget.model.updateStatus('SQL · ${l.copy} · ${l.failed}: $error');
      }
      return;
    }
    for (int r = firstRow; r <= lastRow; r++) {
      final row = widget.model.row(widget.result.resultId, r);
      if (row == null ||
          copyColumns.any((column) => column >= row.values.length)) {
        widget.model.status =
            'Copy requires fetched cells. Wait for the visible range to load.';
        widget.model.updateStatus(widget.model.status);
        return;
      }
      lines.add([for (final column in copyColumns) row.values[column]]);
    }
    try {
      final text = copyFetchedValues(lines, format);
      await writeExactTextClipboard(text);
    } on TextClipboardUnavailable catch (error) {
      widget.model.updateStatus(
        error.reason == TextClipboardUnavailableReason.embeddedNul
            ? l.textClipboardNulUnavailable
            : l.presentationScopeLimit,
      );
    } catch (error) {
      widget.model.updateStatus('${l.copy} · ${l.failed}: $error');
    }
  }

  Future<String> sqlPresentation(
    int firstRow,
    int rowCount,
    List<int> columns,
  ) async {
    final l = strings(context);
    final backend = widget.model.backend, resultId = widget.result.resultId;
    if (backend == null ||
        rowCount < 1 ||
        columns.isEmpty ||
        rowCount * columns.length > 10000) {
      throw StateError(l.sqlCopyRequiresMetadata);
    }
    final captured = widget.model.captureTarget(owner: owner);
    final groups = <List<int>>[];
    for (final column in columns) {
      if (groups.isEmpty || groups.last.last + 1 != column) groups.add([]);
      groups.last.add(column);
    }
    final pieces = <List<String>>[], admission = ResultCopyBuffer();
    for (final group in groups) {
      final reply = await backend.client.copySql(
        rpc.CopySqlRequest(
          context: backend.context(),
          resultId: resultId,
          firstRow: Int64(firstRow),
          rowCount: rowCount,
          firstColumn: group.first,
          columnCount: group.length,
        ),
      );
      widget.model.requireTarget(captured);
      if (!mounted ||
          widget.result.resultId != resultId ||
          widget.model.disposedResults.contains(resultId)) {
        throw StateError(l.staleContext);
      }
      admission.account(reply.text);
      final rows = splitGeneratedSqlCopyRows(reply.text);
      if (rows.length != rowCount) {
        throw StateError(l.staleContext);
      }
      pieces.add(rows);
    }
    final output = ResultCopyBuffer();
    for (var row = 0; row < rowCount; row++) {
      if (row > 0) output.append(',\n');
      output.append('(');
      for (var group = 0; group < pieces.length; group++) {
        if (group > 0) output.append(', ');
        output.append(pieces[group][row]);
      }
      output.append(')');
    }
    return output.text.toString();
  }

  Future<void> saveValue(rpc.Value value) async {
    final model = widget.model;
    await model.command(() async {
      if (model.backend == null) {
        throw StateError('Retained value export requires its owning backend');
      }
      final owned = model.captureTarget(owner: owner);
      final resultId = widget.result.resultId;
      final retainedValue = value.deepCopy();
      final sourceSession = model.jobForOwner(owner)?.sessionId;
      final destination = widget.selectValueDestination;
      void requireRetainedTarget() {
        model.requireTarget(owned);
        if (!mounted ||
            !identical(widget.model, model) ||
            widget.result.resultId != resultId ||
            model.disposedResults.contains(resultId) ||
            model.retainedResults[resultId]?.disposalPending == true) {
          throw StateError(
            'The retained value or view changed; select the value and review again',
          );
        }
      }

      requireRetainedTarget();
      final suggestedName = retainedValue.hasBinary()
          ? 'value.bin'
          : 'value.txt';
      final target = destination == null
          ? (await getSaveLocation(suggestedName: suggestedName))?.path
          : await destination(suggestedName);
      if (target == null) return;
      requireRetainedTarget();
      final request = rpc.ToolRequest(
        context: owned.backend.context(),
        sessionId: sourceSession,
        executionId: const Uuid().v4(),
        kind: rpc.ToolKind.EXPORT_RESULT,
        resultId: resultId,
        valueId: retainedValue.valueId,
        path: target,
        overwrite: true,
      );
      final review = await model.ownedRequest(
        owned,
        () => owned.backend.client.reviewToolAdmission(request),
      );
      requireRetainedTarget();
      if (!mounted) return;
      final ok = await widget.controls.dialog<bool>(
        context,
        strings(context).exportFullValue,
        Text(
          '${strings(context).valueExportReview(retainedValue.originalBytes.toString(), target)}\n${review.risks.join('\n')}',
        ),
        [
          widget.controls.button(
            strings(context).cancel,
            () => Navigator.of(context).pop(false),
          ),
          widget.controls.button(
            strings(context).startExport,
            () => Navigator.of(context).pop(true),
          ),
        ],
      );
      if (ok != true) return;
      requireRetainedTarget();
      request.approvalToken = review.token;
      await model.submitTool(owned, request);
    });
  }

  void selectCell(
    int row,
    int column, {
    bool requestFocus = true,
    bool recordCell = false,
  }) {
    if (requestFocus) {
      recordCellFocused = recordCell;
      focus.requestFocus();
    }
    view.selectedRow = row;
    view.selectedColumn = column;
    view.selectedRow = row;
    setState(() {
      selectedRow = row;
      selectedColumn = column;
      if (!HardwareKeyboard.instance.isShiftPressed) {
        anchorRow = row;
        anchorColumn = column;
      }
    });
  }

  void showRow(int row) {
    final fetched = widget.result.fetchedRows.toInt();
    if (row < 0 || row >= fetched) {
      widget.model.updateStatus(strings(context).retainedRowNote);
      return;
    }
    setState(() {
      windowStart = (row ~/ windowRows) * windowRows;
      selectedRow = anchorRow = row;
      selectedColumn = anchorColumn = visibleColumnIndices.firstOrNull ?? 0;
      view.selectedRow = row;
      jump.text = '${row + 1}';
    });
    focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) revealSelection();
    });
  }

  Future<void> details() async {
    final model = widget.model, result = widget.result;
    final l = strings(context);
    final source = model.sourceResultId(result.resultId);
    final retained = model.retainedResults[source];
    final job = model.jobs.values
        .where((job) => job.results.any((r) => r.resultId == source))
        .firstOrNull;
    final target = retained?.hasTarget() == true
        ? retained!.target
        : job?.hasTarget() == true
        ? job!.target
        : null;
    final error = model.pageErrors[result.resultId];
    final tableQuery =
        owner.view.tableQueries[retained?.executionId ?? job?.executionId];
    await widget.controls.dialog<void>(
      context,
      l.viewDetails,
      SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.retainedData),
            if (target != null)
              SelectableText(
                '${target.name} · ${target.environment == rpc.Environment.PRODUCTION
                    ? l.production
                    : target.environment == rpc.Environment.STAGING
                    ? l.staging
                    : l.development}\n${target.host}:${target.port}/${target.database}/${retained?.sourceSchema ?? job?.sourceSchema ?? ''}',
              ),
            Text('${l.fetchedRows}: ${result.fetchedRows}'),
            Text(
              model.resultViews[result.resultId]?.partial == true
                  ? l.fixedSnapshot
                  : result.limited
                  ? l.limitReached
                  : result.complete
                  ? l.completed
                  : l.partial,
            ),
            if (job != null) Text('${l.sqlExecution} · ${job.durationMs} ms'),
            Text(tableQuery == null ? l.retainedView : l.tableQuerySnapshot),
            SelectableText(
              '${model.resultViews[result.resultId]?.availability ?? l.originalResultNote}\n${(tableQuery?.conditions ?? view.conditions).map((c) => '${c.column} ${workbenchPredicate(context, c.predicate)} ${valueText(c.value)}').join('\n')}\n${(tableQuery?.order ?? view.order).map((o) => '${o.column} ${o.descending ? l.descending : l.ascending}').join('\n')}',
            ),
            if (error != null)
              SelectableText('${error.code}\n${error.message}'),
          ],
        ),
      ),
      [widget.controls.button(l.close, () => Navigator.of(context).pop())],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => _build(context, constraints),
  );

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final l = strings(context);
    final controls = widget.controls,
        model = widget.model,
        result = widget.result;
    final look = controls.appearance(context);
    final foreground = look.foreground,
        background = look.view,
        accent = look.focus;
    final lineMetrics = TextPainter(
      text: TextSpan(text: 'Mg ${l.row}', style: controls.textStyle(context)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final lineHeight = lineMetrics.height;
    rowHeight = math.max(32.0, lineHeight + 12);
    lineMetrics.dispose();
    final fetched = result.fetchedRows.toInt();
    final source = model.sourceResultId(result.resultId);
    if (_lastWindowRows != windowRows) {
      _lastWindowRows = windowRows;
      windowStart = (selectedRow ~/ windowRows) * windowRows;
    }
    final visibleRows = math.min(
      windowRows,
      math.max(0, fetched - windowStart),
    );
    normalizeSelection();
    final visibleColumns = visibleColumnIndices;
    final activeConditions = owner.kind == WorkbenchDocumentKind.table
        ? owner.view.tableConditions
        : view.conditions;
    final activeOrder = owner.kind == WorkbenchDocumentKind.table
        ? owner.view.tableOrder
        : view.order;
    final activeDescription = [
      ...activeConditions.map(
        (c) =>
            '${c.column} ${workbenchPredicate(context, c.predicate)} ${valueText(c.value)}',
      ),
      ...activeOrder.map(
        (o) => '${o.column} ${o.descending ? l.descending : l.ascending}',
      ),
    ].join(' · ');
    final compactLabel = activeDescription.isEmpty
        ? l.more
        : '${l.more} · ${activeDescription.length > 160 ? '${activeDescription.substring(0, 160)}…' : activeDescription}';
    Future<void> resetView() async {
      if (owner.kind == WorkbenchDocumentKind.table) {
        await model.commands!.invoke(
          'object.refresh',
          WorkbenchCommandContext(
            owner: owner,
            object: owner.object,
            profileId: owner.profileId,
            sessionId: owner.sessionId,
            tableConditions: [],
            tableOrder: [],
          ),
        );
      } else {
        await model.createResultView(
          [],
          [],
          targetOwner: owner,
          resultId: source,
        );
      }
    }

    final compactHeader =
        constraints.hasBoundedHeight &&
        constraints.maxHeight <
            (MediaQuery.textScalerOf(context).scale(14) > 21
                ? 420
                : rowHeight * 3 + lineHeight * 2 + 60) &&
        model.pageErrors[result.resultId]?.retryable != true;
    final more = compactHeader
        ? (TextPainter(
            text: TextSpan(
              text: compactLabel,
              style: controls.textStyle(context),
            ),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
          )..layout())
        : null;
    headerHeight = math.max(
      lineHeight * (compactHeader ? 1 : 2) + (compactHeader ? 6 : 12),
      more == null ? 0 : more.height + 8,
    );
    final rowNumberWidth = math.max(
      56.0,
      math.max(
        MediaQuery.textScalerOf(context).scale(14) * 5,
        more == null ? 0.0 : math.min(260.0, more.width + 64),
      ),
    );
    more?.dispose();

    final commandContext = WorkbenchCommandContext(
      owner: owner,
      object: owner.object,
      profileId: owner.profileId,
      sessionId: owner.sessionId,
      ownerRevision: owner.version,
      resultId: result.resultId,
    );
    final actions = <DesktopMenuAction>[
      DesktopMenuAction(l.viewDetails, details),
      DesktopMenuAction(l.filter, () => retainedView(false)),
      DesktopMenuAction(l.sort, () => retainedView(true)),
      if (activeDescription.isNotEmpty)
        DesktopMenuAction(l.resetView, resetView),
      DesktopMenuAction(l.refresh, () async {
        if (owner.kind == WorkbenchDocumentKind.table) {
          await model.commands!.invoke(
            'object.refresh',
            WorkbenchCommandContext(
              owner: owner,
              object: owner.object,
              profileId: owner.profileId,
              sessionId: owner.sessionId,
            ),
          );
        } else {
          await model.createResultView(
            view.conditions,
            view.order,
            targetOwner: owner,
            resultId: model.sourceResultId(result.resultId),
          );
        }
      }),
      if (model.retainedResults[source]?.hasSqlProvenance() == true)
        DesktopMenuAction(
          l.sqlProvenance,
          () => inspect(
            model.retainedResults[source]!.sqlProvenance,
            rpc.Column(name: 'SQL', typeName: 'text', jdbcType: 12),
          ),
        ),
      DesktopMenuAction(
        l.columns,
        () => controls.dialog<void>(
          context,
          l.visibleColumns,
          StatefulBuilder(
            builder: (context, set) => WorkbenchDialogBody(
              maxHeight: math.min(
                320,
                controls.appearance(context).controlHeight(context) *
                    result.columns.length,
              ),
              child: ListView.builder(
                itemCount: result.columns.length,
                itemBuilder: (context, i) => controls.tooltip(
                  result.columns[i].name,
                  controls.checkbox(
                    result.columns[i].name,
                    !view.hiddenColumns.contains(i),
                    !view.hiddenColumns.contains(i) &&
                            visibleColumnIndices.length <= 1
                        ? null
                        : (shown) {
                            set(() {
                              if (shown) {
                                view.hiddenColumns.remove(i);
                              } else if (visibleColumnIndices.length > 1) {
                                view.hiddenColumns.add(i);
                              }
                            });
                            setState(() {
                              normalizeSelection();
                              widthVersion++;
                            });
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) revealSelection();
                            });
                          },
                  ),
                ),
              ),
            ),
          ),
          [
            controls.button(
              strings(context).close,
              () => Navigator.of(context).pop(),
            ),
          ],
          bodyScrolls: true,
        ),
      ),
      DesktopMenuAction(l.assessEditing, assess),
      for (final option in {
        'text': l.textValue,
        'csv': 'CSV',
        'json': 'JSON',
        'sql': l.sqlValues,
      }.entries)
        DesktopMenuAction(l.copyFormat(option.value), () {
          setState(() => format = option.key);
          copy();
        }),
      DesktopMenuAction(
        strings(context).previousRows,
        () => showRow(math.max(0, windowStart - windowRows)),
        disabledReason: windowStart == 0 ? strings(context).firstWindow : null,
      ),
      DesktopMenuAction(
        strings(context).nextRows,
        () => showRow(windowStart + windowRows),
        disabledReason: windowStart + windowRows >= fetched
            ? strings(context).lastWindow
            : null,
      ),
      DesktopMenuAction(l.goToRetainedRow, () async {
        final accepted = await controls.dialog<bool>(
          context,
          strings(context).goToRetainedRow,
          controls.field(jump, strings(context).row),
          [
            controls.button(
              strings(context).cancel,
              () => Navigator.of(context).pop(false),
            ),
            controls.button(
              strings(context).go,
              () => Navigator.of(context).pop(true),
            ),
          ],
        );
        if (accepted == true) {
          final row = int.tryParse(jump.text);
          if (row != null) showRow(row - 1);
        }
      }),
      for (final mode in presentationNames().entries)
        DesktopMenuAction(
          '${l.resultPresentation} · ${mode.value}',
          () => setPresentation(mode.key),
          checked: view.presentation.mode == mode.key,
        ),
      DesktopMenuAction(
        l.recordView,
        () => setState(
          () => view.presentation.recordVisible =
              !view.presentation.recordVisible,
        ),
        checked: view.presentation.recordVisible,
      ),
      DesktopMenuAction(l.displayFormat, chooseDisplayFormat),
      DesktopMenuAction(
        l.aggregateView,
        () => model.command(() => operations().aggregate(), ownerId: owner.id),
        disabledReason: model.backend == null ? l.retainedUnavailable : null,
      ),
      DesktopMenuAction(
        l.relatedRows,
        () => model.command(() => operations().related(), ownerId: owner.id),
        disabledReason: model.backend == null
            ? l.retainedUnavailable
            : owner.sessionId == null
            ? l.relatedRowsUnavailable
            : null,
      ),
      DesktopMenuAction(
        l.editStagedInserts,
        stagedInserts,
        disabledReason: canEdit ? null : l.editUnavailable,
      ),
      DesktopMenuAction(
        l.cloneRow,
        () => model.command(() => operations().clone(), ownerId: owner.id),
        disabledReason: canEdit ? null : l.editUnavailable,
      ),
      if (editingRow != null)
        DesktopMenuAction(
          strings(context).setNull,
          () => stageCell(nullValue: true),
        ),
      for (final id in [
        'edit.insert',
        'edit.update',
        'edit.delete',
        'edit.apply',
        'edit.discard',
        'transfer.retained',
      ])
        if (model.commands != null)
          DesktopMenuAction(
            model.commands!.command(id).label,
            () => model.commands!.invoke(id, commandContext),
            disabledReason: model.commands!
                .command(id)
                .disabledReason
                ?.call(commandContext),
          ),
    ];
    final registered = <String, FutureOr<void> Function()>{
      'result.details': details,
      for (final mode in ResultPresentation.values)
        'result.presentation.${mode.name}': () => setPresentation(mode),
      'result.record': () => setState(
        () =>
            view.presentation.recordVisible = !view.presentation.recordVisible,
      ),
      'result.displayFormat': chooseDisplayFormat,
      'result.aggregate': () =>
          model.command(() => operations().aggregate(), ownerId: owner.id),
      'result.related': () =>
          model.command(() => operations().related(), ownerId: owner.id),
      'result.inserts': stagedInserts,
      'result.clone': () =>
          model.command(() => operations().clone(), ownerId: owner.id),
      'result.filter': () => retainedView(false),
      'result.sort': () => retainedView(true),
      'result.columns': actions.firstWhere((a) => a.label == l.columns).invoke,
      'result.refresh': actions.firstWhere((a) => a.label == l.refresh).invoke,
      'result.reset': resetView,
      'result.assess': assess,
      if (model.retainedResults[source]?.hasSqlProvenance() == true)
        'result.provenance': () => inspect(
          model.retainedResults[source]!.sqlProvenance,
          rpc.Column(name: 'SQL', typeName: 'text', jdbcType: 12),
        ),
      'result.copy': copy,
      'result.inspect': () {
        final value = cellValue(selectedRow, selectedColumn);
        if (value != null) {
          inspect(
            value,
            result.columns[selectedColumn],
            row: selectedRow,
            columnIndex: selectedColumn,
          );
        }
      },
    };
    model.resultActions[owner.id] = registered;
    model.resultActionSources[owner.id] = result.resultId;
    final gridCommandIds = {
      for (final mode in presentationNames().entries)
        '${l.resultPresentation} · ${mode.value}':
            'result.presentation.${mode.key.name}',
      l.recordView: 'result.record',
      l.displayFormat: 'result.displayFormat',
      l.aggregateView: 'result.aggregate',
      l.relatedRows: 'result.related',
      l.cloneRow: 'result.clone',
      l.editStagedInserts: 'result.inserts',
      l.viewDetails: 'result.details',
      l.filter: 'result.filter',
      l.sort: 'result.sort',
      l.columns: 'result.columns',
      l.refresh: 'result.refresh',
      l.resetView: 'result.reset',
      l.assessEditing: 'result.assess',
      l.sqlProvenance: 'result.provenance',
    };
    final menuActions = [
      for (final action in actions)
        if (model.commands != null && gridCommandIds.containsKey(action.label))
          DesktopMenuAction(
            model.commands!.command(gridCommandIds[action.label]!).label,
            () => model.commands!.invoke(
              gridCommandIds[action.label]!,
              commandContext,
            ),
            disabledReason:
                action.disabledReason ??
                model.commands!
                    .command(gridCommandIds[action.label]!)
                    .disabledReason
                    ?.call(commandContext),
          )
        else
          action,
    ];
    Widget resultButton(
      String label,
      String id,
      FutureOr<void> Function() fallback, {
      DesktopIcon? icon,
    }) {
      final command = model.commands?.command(id);
      final reason = command?.disabledReason?.call(commandContext);
      void invoke() {
        if (command == null) {
          fallback();
        } else {
          model.commands!.invoke(id, commandContext);
        }
      }

      final tooltip =
          reason ??
          '$label${command?.shortcutLabel == null ? '' : ' (${command!.shortcutLabel})'}';
      return controls.tooltip(
        tooltip,
        icon == null
            ? controls.textButton(label, reason == null ? invoke : null)
            : controls.iconButton(
                icon,
                tooltip,
                reason == null ? invoke : null,
                compact: true,
              ),
      );
    }

    final resultState = model.resultViews[result.resultId]?.partial == true
        ? l.fixedSnapshot
        : result.complete
        ? l.completed
        : result.limited
        ? l.limitReached
        : l.partial;
    final windowLabel =
        '${l.rowsLabel} ${visibleRows == 0 ? 0 : windowStart + 1}–${windowStart + visibleRows}';
    final fetchedLabel = controls.tooltip(
      '$windowLabel · ${l.fetchedRows} ${result.fetchedRows} · $resultState · ${l.retainedData}',
      Text(
        '$windowLabel / ${result.fetchedRows}${resultState == l.completed ? '' : ' · $resultState'} · ${owner.kind == WorkbenchDocumentKind.table ? l.serverDataOperations : l.localDataOperations}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: controls.textStyle(context),
      ),
    );
    final retry = model.pageErrors[result.resultId]?.retryable == true
        ? controls.button(
            strings(context).retryRows,
            () => model.retryResultPage(result.resultId),
          )
        : null;
    final pending = model.editBatches.values
        .where(
          (batch) =>
              batch.ownerId == owner.id &&
              batch.resultId == model.sourceResultId(result.resultId),
        )
        .firstOrNull;
    // In a short attached output, retain a complete header and data row.
    // Its overflow remains in the pinned selection header; row/status facts
    // remain inspectable through the same registered View details action.
    return Column(
      children: [
        if (pending?.changes.isNotEmpty == true)
          WorkbenchStrip(
            controls: controls,
            minimumHeight: 32,
            child: Row(
              children: [
                Expanded(
                  child: controls.tooltip(
                    l.pendingChangesCount('${pending!.changes.length}'),
                    Text(
                      l.pendingChangesCount('${pending.changes.length}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                controls.textButton(
                  l.reviewDetails,
                  model.commands == null ||
                          model.commands!
                                  .command('edit.apply')
                                  .disabledReason
                                  ?.call(commandContext) !=
                              null
                      ? null
                      : () => model.commands!.invoke(
                          'edit.apply',
                          commandContext,
                        ),
                ),
              ],
            ),
          ),
        if (compactHeader && widget.outputControls != null)
          WorkbenchStrip(
            controls: controls,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: widget.outputControls!,
            ),
          ),
        if (!compactHeader) ...[
          WorkbenchStrip(
            controls: controls,
            child: Row(
              children: [
                Expanded(child: fetchedLabel),
                if (constraints.maxWidth >= 740)
                  Flexible(
                    child: controls.menu(
                      '${l.resultPresentation} · ${presentationNames()[view.presentation.mode]}',
                      [
                        for (final mode in presentationNames().entries)
                          DesktopMenuAction(
                            mode.value,
                            () => setPresentation(mode.key),
                            checked: view.presentation.mode == mode.key,
                          ),
                      ],
                      compact: true,
                    ),
                  ),
                ?widget.outputControls,
                resultButton(
                  l.refresh,
                  'result.refresh',
                  actions
                      .firstWhere((action) => action.label == l.refresh)
                      .invoke,
                  icon: DesktopIcon.refresh,
                ),
                KeyedSubtree(
                  key: const ValueKey('result-actions-menu'),
                  child: controls.iconMenu(
                    l.gridMenu,
                    menuActions,
                    compact: true,
                  ),
                ),
                ?retry,
              ],
            ),
          ),
          if ((owner.kind == WorkbenchDocumentKind.table
              ? owner.view.tableConditions.isNotEmpty ||
                    owner.view.tableOrder.isNotEmpty
              : view.conditions.isNotEmpty || view.order.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        ...(owner.kind == WorkbenchDocumentKind.table
                                ? owner.view.tableConditions
                                : view.conditions)
                            .map(
                              (c) =>
                                  '${c.column} ${workbenchPredicate(context, c.predicate)} ${valueText(c.value)}',
                            ),
                        ...(owner.kind == WorkbenchDocumentKind.table
                                ? owner.view.tableOrder
                                : view.order)
                            .map(
                              (o) =>
                                  '${o.column} ${o.descending ? l.descending : l.ascending}',
                            ),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  resultButton(l.resetView, 'result.reset', resetView),
                ],
              ),
            ),
        ],
        if (model.pageErrors[result.resultId] case final error?)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(error.message, style: controls.textStyle(context)),
          ),
        Expanded(
          child: Focus(
            focusNode: focus,
            includeSemantics: false,
            onKeyEvent: (_, event) {
              if (event is! KeyDownEvent ||
                  !focus.hasPrimaryFocus ||
                  editingRow != null ||
                  headerFocus.hasFocus ||
                  visibleColumns.isEmpty ||
                  fetched == 0) {
                return KeyEventResult.ignored;
              }
              if (event.logicalKey == LogicalKeyboardKey.f2) {
                editCell(selectedRow, selectedColumn);
                return KeyEventResult.handled;
              }
              final shift = HardwareKeyboard.instance.isShiftPressed;
              if (HardwareKeyboard.instance.isControlPressed &&
                  event.logicalKey == LogicalKeyboardKey.keyC) {
                copy();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                final value = cellValue(selectedRow, selectedColumn);
                if (value != null) {
                  inspect(
                    value,
                    result.columns[selectedColumn],
                    row: selectedRow,
                    columnIndex: selectedColumn,
                  );
                }
                return KeyEventResult.handled;
              }
              int row = selectedRow, col = selectedColumn;
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                if (view.presentation.mode == ResultPresentation.transpose) {
                  col =
                      visibleColumns[(visibleColumns.indexOf(col) + 1).clamp(
                        0,
                        visibleColumns.length - 1,
                      )];
                } else {
                  row++;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                if (view.presentation.mode == ResultPresentation.transpose) {
                  col =
                      visibleColumns[(visibleColumns.indexOf(col) - 1).clamp(
                        0,
                        visibleColumns.length - 1,
                      )];
                } else {
                  row--;
                }
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
                  view.presentation.mode == ResultPresentation.transpose) {
                row++;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                  view.presentation.mode == ResultPresentation.transpose) {
                row--;
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                col =
                    visibleColumns[(visibleColumns.indexOf(col) + 1).clamp(
                      0,
                      visibleColumns.length - 1,
                    )];
              } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                col =
                    visibleColumns[(visibleColumns.indexOf(col) - 1).clamp(
                      0,
                      visibleColumns.length - 1,
                    )];
              } else if (event.logicalKey == LogicalKeyboardKey.pageDown) {
                row += vertical.hasClients
                    ? math.max(
                        1,
                        (vertical.position.viewportDimension / rowHeight)
                                .floor() -
                            1,
                      )
                    : 10;
              } else if (event.logicalKey == LogicalKeyboardKey.pageUp) {
                row -= vertical.hasClients
                    ? math.max(
                        1,
                        (vertical.position.viewportDimension / rowHeight)
                                .floor() -
                            1,
                      )
                    : 10;
              } else if (event.logicalKey == LogicalKeyboardKey.home) {
                col = visibleColumns.first;
                if (HardwareKeyboard.instance.isControlPressed) row = 0;
              } else if (event.logicalKey == LogicalKeyboardKey.end) {
                col = visibleColumns.last;
                if (HardwareKeyboard.instance.isControlPressed) {
                  row = result.fetchedRows.toInt() - 1;
                }
              } else {
                return KeyEventResult.ignored;
              }
              setState(() {
                selectedRow = row.clamp(
                  0,
                  math.max(0, result.fetchedRows.toInt() - 1),
                );
                selectedColumn = col.clamp(0, result.columns.length - 1);
                view.selectedRow = selectedRow;
                view.selectedColumn = selectedColumn;
                view.selectedRow = selectedRow;
                if (!shift) {
                  anchorRow = selectedRow;
                  anchorColumn = selectedColumn;
                }
              });
              if (selectedRow < windowStart ||
                  selectedRow >= windowStart + windowRows) {
                setState(
                  () => windowStart = (selectedRow ~/ windowRows) * windowRows,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) revealSelection();
                });
              } else {
                revealSelection();
              }
              return KeyEventResult.handled;
            },
            child: ResultPresentationHost(
              controls: controls,
              state: view.presentation,
              result: result,
              columns: visibleColumns,
              selectedRow: selectedRow,
              selectedColumn: selectedColumn,
              anchorRow: anchorRow,
              anchorColumn: anchorColumn,
              windowStart: windowStart,
              windowRows: windowRows,
              valueAt: presentedValue,
              originalAt: cellValue,
              assignmentAt: assignmentAt,
              activateCell: (row, column, record) =>
                  selectCell(row, column, recordCell: record),
              cellFocused: (record) =>
                  focus.hasPrimaryFocus &&
                  !headerFocus.hasFocus &&
                  (record
                      ? view.presentation.recordVisible && recordCellFocused
                      : !view.presentation.recordVisible || !recordCellFocused),
              select: (row, column) {
                selectCell(row, column, requestFocus: false);
                if (row < windowStart || row >= windowStart + windowRows) {
                  setState(
                    () => windowStart = (row ~/ windowRows) * windowRows,
                  );
                }
              },
              inspect: (row, column) {
                final value = presentedValue(row, column);
                if (value != null) {
                  inspect(
                    value,
                    result.columns[column],
                    row: row,
                    columnIndex: column,
                  );
                }
              },
              edit: (row, column) {
                final value = presentedValue(row, column);
                if (value != null) {
                  inspect(
                    value,
                    result.columns[column],
                    row: row,
                    columnIndex: column,
                  );
                }
              },
              editReason: (row, column) {
                final value = cellValue(row, column);
                return canEdit &&
                        value != null &&
                        !value.truncated &&
                        assessment!.editableColumns.contains(
                          result.columns[column].ordinal,
                        )
                    ? null
                    : editDisabledReason(value, result.columns[column]);
              },
              changed: () => setState(() {}),
              sqlText: sqlPresentation,
              table: () => table(
                (
                  result.resultId,
                  // Job summaries precede the retained column metadata.
                  result.columns.length,
                  windowStart,
                  visibleRows,
                  rowHeight,
                  foreground,
                  background,
                  look.header,
                  look.secondaryForeground,
                  look.controlBorder,
                  look.unfocusedSelectionForeground,
                  look.selected,
                  look.selectedForeground,
                  look.unfocusedSelection,
                  look.gridLine,
                  look.staged,
                  accent,
                  controls.textStyle(context),
                  MediaQuery.highContrastOf(context),
                  assessment,
                  canEdit,
                  model.cacheGeneration,
                  model
                      .editBatches['${owner.id}\u0000${model.sourceResultId(result.resultId)}']
                      ?.revision,
                  editingRow, editingColumn,
                  widthVersion,
                  selectedRow,
                  selectedColumn,
                  anchorRow,
                  anchorColumn,
                  cellFocusActive,
                  compactHeader,
                  headerHeight,
                  rowNumberWidth,
                  l.localeName,
                ),
                () => TableView.builder(
                  // Retained pages have their own shared cache. Keep native cell
                  // layout close to the viewport instead of the framework's
                  // 250-pixel default in both axes, especially in small outputs.
                  cacheExtent: rowHeight * 2,
                  verticalDetails: ScrollableDetails.vertical(
                    controller: vertical,
                  ),
                  horizontalDetails: ScrollableDetails.horizontal(
                    controller: horizontal,
                  ),
                  pinnedRowCount: 1,
                  pinnedColumnCount: 1,
                  rowCount: visibleRows + 1,
                  columnCount: visibleColumns.length + 1,
                  columnBuilder: (i) => TableSpan(
                    extent: FixedTableSpanExtent(
                      i == 0
                          ? rowNumberWidth
                          : widths[visibleColumns[i - 1]] ?? 180,
                    ),
                  ),
                  rowBuilder: (i) => TableSpan(
                    extent: FixedTableSpanExtent(
                      i == 0 ? headerHeight : rowHeight,
                    ),
                  ),
                  cellBuilder: (context, vicinity) {
                    PresentationDiagnostics.count('grid-visible-cell-build');
                    if (vicinity.column == 0) {
                      final row = windowStart + vicinity.row - 1;
                      return TableViewCell(
                        child: Semantics(
                          label: vicinity.row == 0
                              ? strings(context).rowSelection
                              : l.selectRow((row + 1).toString()),
                          button: vicinity.row != 0,
                          child: GestureDetector(
                            onTap: vicinity.row == 0
                                ? null
                                : () => selectCell(row, visibleColumns.first),
                            child: ColoredBox(
                              color: background,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: vicinity.row == 0 && compactHeader
                                      ? FocusScope(
                                          node: headerFocus,
                                          child: controls.tooltip(
                                            activeDescription.isEmpty
                                                ? l.gridMenu
                                                : '${l.gridMenu} · $activeDescription',
                                            controls.menu(
                                              compactLabel,
                                              menuActions,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          vicinity.row == 0
                                              ? '#'
                                              : '${row + 1}',
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final columnIndex = visibleColumns[vicinity.column - 1];
                    final column = result.columns[columnIndex];
                    final header = vicinity.row == 0;
                    final rowIndex = windowStart + vicinity.row - 1;
                    final value = header
                        ? null
                        : cellValue(rowIndex, columnIndex);
                    final batch = model
                        .editBatches['${owner.id}\u0000${model.sourceResultId(result.resultId)}'];
                    final sourceRow = header || value == null
                        ? null
                        : model.sourceRow(result.resultId, rowIndex);
                    final pending = sourceRow == null
                        ? null
                        : batch?.changes
                              .where(
                                (c) =>
                                    c.kind != rpc.ChangeKind.INSERT &&
                                    c.sourceRow.toInt() == sourceRow,
                              )
                              .firstOrNull;
                    final proposed = pending?.values[column.ordinal];
                    final dirty =
                        pending?.kind == rpc.ChangeKind.DELETE ||
                        proposed != null;
                    final shown = assignmentValue(proposed) ?? value;
                    final text = header
                        ? '${column.name} · ${column.typeName}'
                        : value == null
                        ? model.pageErrors.containsKey(result.resultId)
                              ? l.unavailable
                              : l.loading
                        : proposed?.hasDefaultValue() == true
                        ? l.assignmentDefault
                        : shown!.hasText() && shown.text.isEmpty
                        ? '""'
                        : displayedResultValue(
                            shown,
                            view.presentation.formats[columnIndex] ??
                                ColumnDisplayFormat.canonical,
                            temporalPattern:
                                view.presentation.temporalPatterns[columnIndex],
                            locale: Localizations.localeOf(
                              context,
                            ).toLanguageTag(),
                          );
                    final selected =
                        !header &&
                        rowIndex >= math.min(selectedRow, anchorRow) &&
                        rowIndex <= math.max(selectedRow, anchorRow) &&
                        columnIndex >= math.min(selectedColumn, anchorColumn) &&
                        columnIndex <= math.max(selectedColumn, anchorColumn);
                    final inlineEditing =
                        !header &&
                        editingRow == rowIndex &&
                        editingColumn == columnIndex;
                    final cell = Semantics(
                      key: ValueKey(
                        '${result.resultId}:$rowIndex:$columnIndex',
                      ),
                      identifier: header
                          ? null
                          : resultCellSemanticsIdentifier(
                              ownerDocumentId: owner.id,
                              sourceResultId: source,
                              displayResultId: result.resultId,
                              row: rowIndex,
                              column: columnIndex,
                            ),
                      label: header
                          ? l.columnHeader(text)
                          : '${l.row} ${rowIndex + 1}, ${column.name}: $text${dirty ? ' · ${l.pendingChange}' : ''}',
                      hint: header
                          ? null
                          : '${column.typeName} · ${editableCell(value, column) ? l.editableCell : l.readonlyCell}',
                      selected: selected,
                      // Cells provide selection and inspection actions. The
                      // Linux engine exposes an actionable button flag, while
                      // its generic panel role can suppress changed row speech.
                      button: !inlineEditing,
                      enabled: header || inlineEditing ? null : true,
                      focusable: !header && !inlineEditing,
                      focused:
                          !header &&
                          !inlineEditing &&
                          cellFocusActive &&
                          rowIndex == selectedRow &&
                          columnIndex == selectedColumn,
                      explicitChildNodes: inlineEditing,
                      excludeSemantics: !inlineEditing,
                      onFocus: header || inlineEditing
                          ? null
                          : () => selectCell(rowIndex, columnIndex),
                      onTap: header
                          ? () => sortColumn(columnIndex)
                          : inlineEditing
                          ? null
                          : () => selectCell(rowIndex, columnIndex),
                      onLongPress: value == null
                          ? null
                          : () => inspect(
                              value,
                              column,
                              row: rowIndex,
                              columnIndex: columnIndex,
                            ),
                      child: Listener(
                        onPointerDown: header || inlineEditing
                            ? null
                            : (_) => selectCell(rowIndex, columnIndex),
                        child: GestureDetector(
                          onTap: header ? () => sortColumn(columnIndex) : null,
                          onDoubleTap: value == null || inlineEditing
                              ? null
                              : () => editCell(rowIndex, columnIndex),
                          child: Container(
                            alignment:
                                !header &&
                                    const [
                                      -6,
                                      5,
                                      4,
                                      -5,
                                      2,
                                      3,
                                      6,
                                      7,
                                      8,
                                    ].contains(column.jdbcType)
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? look.rowBackground(
                                      selected: true,
                                      focused: cellFocusActive,
                                    )
                                  : dirty
                                  ? look.staged
                                  : header
                                  ? look.header
                                  : look.view,
                              border: BorderDirectional(
                                bottom: BorderSide(color: look.gridLine),
                                end: BorderSide(color: look.gridLine),
                              ),
                            ),
                            foregroundDecoration:
                                !header &&
                                    rowIndex == selectedRow &&
                                    columnIndex == selectedColumn
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: cellFocusActive
                                          ? look.rowForeground(
                                              selected: selected,
                                            )
                                          : look.controlBorder,
                                      width: cellFocusActive ? 2 : 1,
                                    ),
                                  )
                                : null,
                            child: inlineEditing
                                ? Focus(
                                    onKeyEvent: (_, event) {
                                      if (event is! KeyDownEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.enter) {
                                        stageCell();
                                        return KeyEventResult.handled;
                                      }
                                      if (event.logicalKey ==
                                          LogicalKeyboardKey.escape) {
                                        setState(
                                          () =>
                                              editingRow = editingColumn = null,
                                        );
                                        focus.requestFocus();
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: controls.inlineField(
                                      cellEditor,
                                      column.name,
                                      focusNode: cellFocus,
                                    ),
                                  )
                                : header
                                ? compactHeader
                                      ? Text.rich(
                                          TextSpan(
                                            text: column.name,
                                            style: look.body.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: ' · ${column.typeName}',
                                                style: look.caption,
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              column.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: look.body.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              column.typeName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: look.caption,
                                            ),
                                          ],
                                        )
                                : Text(
                                    text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: controls
                                        .textStyle(context)
                                        .copyWith(
                                          fontStyle:
                                              shown?.hasNullValue() == true
                                              ? FontStyle.italic
                                              : null,
                                          fontWeight: header || dirty
                                              ? FontWeight.w600
                                              : null,
                                          decoration:
                                              pending?.kind ==
                                                  rpc.ChangeKind.DELETE
                                              ? TextDecoration.lineThrough
                                              : null,
                                          color: selected
                                              ? look.rowForeground(
                                                  selected: true,
                                                  focused: cellFocusActive,
                                                )
                                              : value?.hasNullValue() == true
                                              ? look.secondaryForeground
                                              : foreground,
                                        ),
                                  ),
                          ),
                        ),
                      ),
                    );
                    final pointerCell = header || inlineEditing
                        ? cell
                        : Listener(
                            onPointerDown: (event) {
                              if ((event.buttons &
                                      (kPrimaryButton | kSecondaryButton)) ==
                                  0) {
                                return;
                              }
                              final insideSelection =
                                  rowIndex >=
                                      math.min(selectedRow, anchorRow) &&
                                  rowIndex <=
                                      math.max(selectedRow, anchorRow) &&
                                  columnIndex >=
                                      math.min(selectedColumn, anchorColumn) &&
                                  columnIndex <=
                                      math.max(selectedColumn, anchorColumn);
                              if ((event.buttons & kSecondaryButton) != 0 &&
                                  insideSelection) {
                                focus.requestFocus();
                              } else {
                                selectCell(rowIndex, columnIndex);
                              }
                              // Settle this explicit pointer target before the
                              // editor's outside-tap unfocus callback runs.
                              FocusManager.instance.applyFocusChangesIfNeeded();
                            },
                            child: cell,
                          );
                    final contextualCell = header
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              cell,
                              PositionedDirectional(
                                end: 0,
                                top: 0,
                                bottom: 0,
                                width: 10,
                                child: _ColumnResizeHandle(
                                  controls: controls,
                                  focused:
                                      cellFocusActive &&
                                      selectedColumn == columnIndex,
                                  label: l.resizeColumn(column.name),
                                  resize: (delta) => setState(() {
                                    widths[columnIndex] =
                                        ((widths[columnIndex] ?? 180) +
                                                delta *
                                                    (Directionality.of(
                                                              context,
                                                            ) ==
                                                            TextDirection.rtl
                                                        ? -1
                                                        : 1))
                                            .clamp(60, 800);
                                    widthVersion++;
                                  }),
                                ),
                              ),
                            ],
                          )
                        : controls.contextMenu(pointerCell, [
                            DesktopMenuAction(
                              l.filterCellValue,
                              () {
                                selectCell(rowIndex, columnIndex);
                                unawaited(filterSelectedCell());
                              },
                              disabledReason: value == null || value.truncated
                                  ? l.loadValueFirst
                                  : null,
                            ),
                            DesktopMenuAction(
                              l.inspectValue,
                              () {
                                if (value != null) {
                                  inspect(
                                    value,
                                    column,
                                    row: rowIndex,
                                    columnIndex: columnIndex,
                                  );
                                }
                              },
                              disabledReason: value == null
                                  ? strings(context).loadValueFirst
                                  : null,
                            ),
                            DesktopMenuAction(
                              strings(context).editCell,
                              () => editCell(rowIndex, columnIndex),
                              disabledReason: editableCell(value, column)
                                  ? null
                                  : editDisabledReason(value, column),
                            ),
                            DesktopMenuAction(
                              strings(context).setNull,
                              () {
                                editingRow = rowIndex;
                                editingColumn = columnIndex;
                                stageCell(nullValue: true);
                              },
                              disabledReason:
                                  canEdit &&
                                      assessment!.editableColumns.contains(
                                        column.ordinal,
                                      ) &&
                                      value != null &&
                                      !value.truncated &&
                                      !value.hasBinary() &&
                                      !value.hasArray() &&
                                      !value.hasEngineValue() &&
                                      value.valueId.isEmpty
                                  ? null
                                  : editDisabledReason(value, column),
                            ),
                            DesktopMenuAction(
                              l.setDefault,
                              () {
                                editingRow = rowIndex;
                                editingColumn = columnIndex;
                                stageCell(defaultValue: true);
                              },
                              disabledReason:
                                  canEdit &&
                                      assessment!.editableColumns.contains(
                                        column.ordinal,
                                      )
                                  ? null
                                  : editDisabledReason(value, column),
                            ),
                            if (pending != null)
                              DesktopMenuAction(l.revertChange, () async {
                                if (batch!.applying || batch.outcomeUnknown) {
                                  throw StateError(
                                    'Reconcile the application before reverting',
                                  );
                                }
                                batch.changes.remove(pending);
                                batch.revision++;
                                await model.persistStagedEdits(batch: batch);
                                model.updateStatus(l.rowChangeReverted);
                              }),
                            DesktopMenuAction(l.copyRange, copy),
                            for (final id in [
                              'edit.insert',
                              'edit.delete',
                              'edit.apply',
                              'transfer.retained',
                            ])
                              if (model.commands != null)
                                DesktopMenuAction(
                                  model.commands!.command(id).label,
                                  () => model.commands!.invoke(
                                    id,
                                    WorkbenchCommandContext(
                                      owner: owner,
                                      object: owner.object,
                                      profileId: owner.profileId,
                                      sessionId: owner.sessionId,
                                    ),
                                  ),
                                ),
                          ]);
                    return TableViewCell(
                      child: value == null || model.visibleCellObserver == null
                          ? contextualCell
                          : _VisibleCell(
                              model: model,
                              resultId: result.resultId,
                              row: rowIndex,
                              column: columnIndex,
                              value: value,
                              child: contextualCell,
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Reports only decoded cells intersecting the actual two-dimensional viewport.
/// No instrumentation widgets are allocated during ordinary use.
class _VisibleCell extends StatefulWidget {
  const _VisibleCell({
    required this.model,
    required this.resultId,
    required this.row,
    required this.column,
    required this.value,
    required this.child,
  });
  final WorkbenchModel model;
  final String resultId;
  final int row, column;
  final rpc.Value value;
  final Widget child;
  @override
  State<_VisibleCell> createState() => _VisibleCellState();
}

class _VisibleCellState extends State<_VisibleCell> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject();
      final viewport = context
          .findAncestorRenderObjectOfType<RenderTwoDimensionalViewport>();
      if (box is! RenderBox ||
          !box.hasSize ||
          viewport == null ||
          !viewport.hasSize) {
        return;
      }
      final rectangle = box.localToGlobal(Offset.zero) & box.size;
      final bounds = viewport.localToGlobal(Offset.zero) & viewport.size;
      if (!rectangle.overlaps(bounds)) return;
      widget.model.visibleCellObserver?.call(
        widget.resultId,
        widget.row,
        widget.column,
        widget.value,
      );
    });
    return widget.child;
  }
}

/// The separator remains quiet until the existing resize hit area is hovered
/// or focused. Geometry, directional deltas and width ownership stay in the grid.
class _ColumnResizeHandle extends StatefulWidget {
  const _ColumnResizeHandle({
    required this.controls,
    required this.label,
    required this.resize,
    required this.focused,
  });
  final DesktopControls controls;
  final String label;
  final ValueChanged<double> resize;
  final bool focused;
  @override
  State<_ColumnResizeHandle> createState() => _ColumnResizeHandleState();
}

class _ColumnResizeHandleState extends State<_ColumnResizeHandle> {
  bool hovered = false, dragging = false;
  @override
  Widget build(BuildContext context) {
    final look = widget.controls.appearance(context);
    return Semantics(
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => setState(() => dragging = true),
          onHorizontalDragEnd: (_) => setState(() => dragging = false),
          onHorizontalDragCancel: () => setState(() => dragging = false),
          onHorizontalDragUpdate: (event) => widget.resize(event.delta.dx),
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              width: hovered || dragging || widget.focused ? 2 : 1,
              color: hovered || dragging || widget.focused
                  ? look.focus
                  : look.gridLine,
            ),
          ),
        ),
      ),
    );
  }
}
