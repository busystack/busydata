import 'package:flutter/material.dart' show SelectableText;
import 'dart:async';
import 'dart:math' as math;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../backend/workbench_failure.dart';
import '../../features/workspace/metadata_reply_stamps.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'result_extractors.dart';
import 'result_operation_messages.dart';
import 'workbench_presentation.dart';

/// Generated operations capture one retained result and physical owner before
/// asynchronous work. No presentation constructs executable SQL or identifiers.
class ResultOperations {
  ResultOperations({
    required this.model,
    required this.controls,
    required this.context,
    required this.owner,
    required this.result,
    required this.selectedRow,
    required this.anchorRow,
    required this.selectedColumn,
    required this.anchorColumn,
    required this.visibleColumns,
    required this.current,
    this.editInsert,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final BuildContext context;
  final WorkbenchDocument owner;
  final rpc.StatementResult result;
  final int selectedRow, anchorRow, selectedColumn, anchorColumn;
  final List<int> visibleColumns;
  final bool Function() current;
  final Future<void> Function(OwnedEditBatch batch, int index)? editInsert;
  String get source => model.sourceResultId(result.resultId);
  void require(CapturedWorkbenchTarget target) {
    model.requireTarget(target);
    if (!context.mounted ||
        !current() ||
        model.disposedResults.contains(source) ||
        model.disposedResults.contains(result.resultId)) {
      throw StateError(strings(context).staleContext);
    }
  }

  Future<void> aggregate() async {
    final l = strings(context);
    if (model.backend == null) {
      model.updateStatus(l.retainedUnavailable);
      return;
    }
    final captured = model.captureTarget(owner: owner);
    final selected = visibleColumns.where(
      (c) =>
          c >= math.min(selectedColumn, anchorColumn) &&
          c <= math.max(selectedColumn, anchorColumn),
    );
    final count = result.fetchedRows.toInt() == 0
        ? 0
        : (selectedRow - anchorRow).abs() + 1;
    final call = captured.backend.client.resultAggregate(
      rpc.ResultAggregateRequest(
        context: captured.backend.context(),
        resultId: source,
        viewId: result.resultId == source ? '' : result.resultId,
        firstRow: Int64(math.min(selectedRow, anchorRow)),
        rowCount: count,
        ordinals: selected.map((c) => c + 1),
      ),
    );
    final response = call.then((reply) {
      require(captured);
      if (reply.resultId != source ||
          reply.viewId != (result.resultId == source ? '' : result.resultId)) {
        throw StateError(l.staleContext);
      }
      return reply;
    });
    try {
      await controls.dialog<void>(
        context,
        l.aggregateView,
        WorkbenchDialogBody(
          maxHeight: 480,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.selectedCellsScope),
              Text(l.aggregateStoredValues),
              if (result.limited || !result.complete)
                Text(l.partialRetainedScope),
              Expanded(
                child: FutureBuilder<rpc.ResultAggregateReply>(
                  future: response,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return SelectableText(l.unavailable);
                    final reply = snapshot.data;
                    if (reply == null) return controls.status(l.loading);
                    return ListView.builder(
                      itemCount: reply.columns.length,
                      itemBuilder: (context, index) {
                        final c = reply.columns[index];
                        final position = c.ordinal - 1;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              position >= 0 && position < result.columns.length
                                  ? result.columns[position].name
                                  : '${c.ordinal}',
                            ),
                            for (final entry in {
                              l.aggregateSelectedCount: '${c.selectedCount}',
                              l.aggregateNonNull: '${c.nonNullCount}',
                              l.aggregateNull: '${c.nullCount}',
                              l.aggregateDistinct: '${c.distinctCount}',
                              l.aggregateSum: c.sum,
                              l.aggregateAverage: c.average,
                              l.aggregateMinimum: c.hasMinimum()
                                  ? valueText(c.minimum)
                                  : '',
                              l.aggregateMaximum: c.hasMaximum()
                                  ? valueText(c.maximum)
                                  : '',
                            }.entries)
                              Text(
                                '${entry.key}: ${entry.value.isEmpty ? l.unavailable : entry.value}',
                              ),
                            if (c.availability.isNotEmpty)
                              Text(
                                resultOperationAvailability(
                                  context,
                                  c.availability,
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        [
          controls.button(l.close, () {
            unawaited(call.cancel());
            Navigator.of(context).pop();
          }),
        ],
        bodyScrolls: true,
      );
    } finally {
      unawaited(call.cancel());
    }
  }

  Future<void> clone() async {
    final l = strings(context);
    if (model.backend == null) {
      model.updateStatus(l.retainedUnavailable);
      return;
    }
    if (result.columns.isEmpty) return;
    final captured = model.captureTarget(owner: owner),
        column = result.columns.first;
    final sourceRow = model.sourceRow(result.resultId, selectedRow);
    final batch = model.batchFor(owner, source), revision = batch.revision;
    final change = await captured.backend.client.cloneRow(
      rpc.CloneRowRequest(
        context: captured.backend.context(),
        sessionId: captured.sessionId,
        resultId: source,
        sourceRow: Int64(sourceRow),
        catalog: column.catalog,
        schema: column.schema,
        table: column.table,
      ),
    );
    require(captured);
    if (batch.revision != revision ||
        model.sourceRow(result.resultId, selectedRow) != sourceRow ||
        change.kind != rpc.ChangeKind.INSERT) {
      throw StateError(l.staleContext);
    }
    batch.sessionId = captured.sessionId;
    batch.documentId = owner.id;
    batch.schema = column.schema.isEmpty ? column.catalog : column.schema;
    batch.table = column.table;
    model.stageChange(batch, change);
    await model.persistStagedEdits(batch: batch);
    model.updateStatus(l.stagedInsertReview);
    await editInsert?.call(batch, batch.changes.length - 1);
  }

  Future<void> related() async {
    final l = strings(context);
    if (model.backend == null) {
      model.updateStatus(l.retainedUnavailable);
      return;
    }
    final captured = model.captureTarget(owner: owner);
    if (captured.sessionId == null ||
        !model.sessions.containsKey(captured.sessionId)) {
      model.updateStatus(l.relatedRowsUnavailable);
      return;
    }
    final row = model.sourceRow(result.resultId, selectedRow);
    final reply = await model.relatedRows(
      rpc.RelatedRowsRequest(
        context: captured.backend.context(),
        sessionId: captured.sessionId,
        resultId: source,
        sourceRow: Int64(row),
        documentId: owner.id,
      ),
    );
    if (!context.mounted) return;
    final relatedSnapshot = relatedRowsMetadataStamp(reply);
    void requireRelatedSnapshot() {
      require(captured);
      if (!model.metadataRevisionIsCurrent(relatedSnapshot)) {
        throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
      }
    }

    requireRelatedSnapshot();
    final choice = await controls.dialog<rpc.RelatedRelationship>(
      context,
      l.relatedRows,
      WorkbenchDialogBody(
        maxHeight: 340,
        child: reply.relationships.isEmpty
            ? Text(
                reply.availability.isEmpty || reply.availability == 'available'
                    ? l.noRelatedRows
                    : resultOperationAvailability(context, reply.availability),
              )
            : ListView.builder(
                itemCount: reply.relationships.length,
                itemBuilder: (context, index) {
                  final relationship = reply.relationships[index];
                  return controls.tooltip(
                    relationship.availability.isEmpty ||
                            relationship.availability == 'available'
                        ? relationship.name
                        : resultOperationAvailability(
                            context,
                            relationship.availability,
                          ),
                    controls.textButton(
                      relationship.hasBrowse()
                          ? '${relationship.name} · ${relationship.incoming ? '←' : '→'} ${relationship.browse.catalog}.${relationship.browse.schema}.${relationship.browse.table}'
                          : '${relationship.name} · ${resultOperationAvailability(context, relationship.availability)}',
                      relationship.availability != 'available' ||
                              !relationship.hasBrowse() ||
                              relationship.browse.table.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(relationship),
                    ),
                  );
                },
              ),
      ),
      [controls.button(l.cancel, () => Navigator.of(context).pop())],
      bodyScrolls: true,
    );
    if (choice == null) return;
    requireRelatedSnapshot();
    final request = choice.browse.deepCopy()
      ..context = captured.backend.context()
      ..sessionId = captured.sessionId!
      ..executionId = const Uuid().v4()
      ..documentId = const Uuid().v4()
      ..rowLimit = Int64(owner.view.rowLimit ?? model.defaultRowLimit);
    final session = model.sessions[captured.sessionId];
    if (session == null ||
        session.profile.engine == rpc.Engine.POSTGRESQL &&
            request.catalog.isNotEmpty &&
            request.catalog != session.currentCatalog) {
      throw StateError(l.relatedRowsUnavailable);
    }
    final review = await captured.backend.client.reviewBrowse(request);
    if (!context.mounted) return;
    requireRelatedSnapshot();
    final accepted = await controls.dialog<bool>(
      context,
      l.relatedRows,
      SingleChildScrollView(
        child: SelectableText(
          '${choice.name}\n${l.sharingSessionReview}\n${workbenchTargetDescription(context, captured)}\n${review.risks.join('\n')}\n${review.statements.join('\n')}',
        ),
      ),
      [
        controls.button(l.cancel, () => Navigator.of(context).pop(false)),
        controls.button(
          l.openData,
          () => Navigator.of(context).pop(true),
          primary: true,
        ),
      ],
    );
    if (accepted != true) return;
    requireRelatedSnapshot();
    final destination = model.openTask(
      WorkbenchDocumentKind.table,
      '${l.relatedRows} · ${request.table} · ${choice.name}',
      object: DatabaseObjectIdentity(
        profileId: session.profile.id,
        catalog: request.catalog,
        schema: request.schema,
        kind: rpc.ObjectKind.TABLE,
        name: request.table,
      ),
      purpose: 'relationship:${choice.identity}:$source:$row',
      restoredId: request.documentId,
      evidenceProfile: session.profile,
      reuse: false,
    );
    destination.view.subview = 'data';
    model.shareSessionOwner(destination, captured.sessionId!);
    final target = model.captureTarget(owner: destination);
    request.approvalToken = review.token;
    model.submissions[request.executionId] = destination.id;
    final job = await model.ownedRequest(
      target,
      () => target.backend.client.browse(request),
    );
    model.requireTarget(target);
    final query = TableQueryState(request.conditions, request.order);
    destination.view.tableQueries[request.executionId] = query;
    destination.view.tableConditions = query.conditions;
    destination.view.tableOrder = query.order;
    model.track(job, documentId: destination.id);
    model.updateStatus('${l.relatedRows} · ${choice.name}');
  }
}
