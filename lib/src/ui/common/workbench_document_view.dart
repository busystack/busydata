import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:grpc/grpc.dart' show ResponseFuture, GrpcError;
import 'package:flutter/material.dart' show SelectableText;
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../backend/connection_failure.dart';
import '../../backend/workbench_failure.dart';
import '../../features/workspace/workbench_model.dart';
import '../../features/workspace/documents.dart'
    show SqlDocument, readBoundedFile;
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'structure_presentation.dart';
import 'workbench_search_session.dart';
import 'history_view.dart';
import 'capabilities_view.dart';
import 'activity_view.dart';
import 'result_grid.dart';
import '../../features/results/value_assignments.dart';
import 'plan_view.dart';
import 'object_designer.dart';
import 'schema_tools_view.dart';
import 'privileges_view.dart';
import 'transfer_document.dart';

String _objectPath(WorkbenchModel model, WorkbenchDocument owner) {
  final profile =
      owner.retained?.target ??
      model.sessions[owner.sessionId]?.profile ??
      owner.evidenceProfile ??
      model.profiles.where((p) => p.id == owner.profileId).firstOrNull;
  return owner.object?.displayPath(profile?.engine) ?? owner.displayTitle;
}

class ChangesReviewData {
  const ChangesReviewData(
    this.target,
    this.batch,
    this.revision,
    this.plan,
    this.apply,
  );
  final CapturedWorkbenchTarget target;
  final OwnedEditBatch batch;
  final int revision;
  final rpc.ChangePlan plan;
  final Future<void> Function() apply;
}

enum GlobalToolKind { jobs, problems, history, retained }

class GlobalToolData {
  GlobalToolData(this.kind);
  final GlobalToolKind kind;
  final history = HistoryInspectionState();
}

class AdministrationData {
  AdministrationData(
    this.target, {
    this.activities = false,
    this.activityAction,
  });
  final CapturedWorkbenchTarget target;
  final bool activities;
  final Future<void> Function(rpc.Activity, bool)? activityAction;
  final activityInspection = ActivityInspectionState();
  final capabilityInspection = CapabilityInspectionState();
}

class ComparisonData {
  ComparisonData({required this.schema, required this.profileId})
    : currentProfile = profileId,
      desiredProfile = profileId;
  String filter = '';
  rpc.SchemaDifference? selected;
  String current = '', desired = '', currentSnapshot = '', desiredSnapshot = '';
  String? profileId, currentProfile, desiredProfile;
  String schema;
  DatabaseObjectIdentity? currentObject, desiredObject;
  bool automaticCaptureRequested = false;
  rpc.SchemaToolResult? result;
  rpc.Engine? resultEngine;
  int revision = 0;
  bool busy = false;
  String error = '';
  void changed() {
    revision++;
    result = null;
    resultEngine = null;
    selected = null;
  }
}

class RecoveryDocumentData {
  RecoveryDocumentData(SqlDocument? owner, this.rebind, this.discard)
    : _owner = owner == null ? null : WeakReference(owner);
  final WeakReference<SqlDocument>? _owner;
  SqlDocument? get owner => _owner?.target;
  final Future<void> Function(rpc.EditDraftInfo) rebind, discard;
}

class ExecutionDocumentData {
  const ExecutionDocumentData(this.target, this.label);
  final CapturedWorkbenchTarget target;
  final String label;
}

class DesignerData {
  DesignerData(this.target, this.request, this.inspected, this.draft);
  final ObjectDesignerDraft draft;
  final CapturedWorkbenchTarget target;
  final rpc.SchemaToolRequest request;
  final rpc.SchemaToolResult inspected;
  final referenceState = ObjectDesignerReferenceState();
  int referenceEvidenceUnits = 0;
}

class WorkbenchDocumentView extends StatelessWidget {
  const WorkbenchDocumentView({
    super.key,
    required this.model,
    required this.owner,
    required this.controls,
  });
  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final DesktopControls controls;
  @override
  Widget build(BuildContext context) {
    final payload = owner.payload;
    if (payload is RestoredTaskReference) {
      final command = model.commands?.commands
          .where((c) => c.id == payload.commandId)
          .firstOrNull;
      final reason = command?.disabledReason?.call(model.commandContext);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(owner.displayTitle),
          Text(strings(context).restoredTaskState),
          if (reason != null) Text(reason),
          if (owner.sessionId == null && owner.profileId != null)
            controls.button(
              strings(context).connect,
              () => model.commands!.invoke(
                'connection.connect',
                model.commandContext,
              ),
            ),
          if (command != null)
            controls.button(
              command.label,
              reason == null
                  ? () => model.commands!.invoke(
                      payload.commandId,
                      model.commandContext,
                    )
                  : null,
            ),
        ],
      );
    }
    if (payload is RecoveryDocumentData) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(strings(context).recoveryNoExecution),
          Text(
            '${strings(context).selectTarget}: ${payload.owner?.title ?? strings(context).notConnected} · ${payload.owner?.sessionId ?? strings(context).notConnected}',
          ),
          controls.textButton(
            strings(context).refresh,
            () => model.command(model.refreshEditDrafts, ownerId: owner.id),
          ),
          if (model.editDrafts.isEmpty) Text(strings(context).empty),
          for (final draft in model.editDrafts)
            WorkbenchEvidenceRecord(
              controls: controls,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${draft.target.name} · ${workbenchEnvironment(context, draft.target.environment)} · ${draft.target.host}:${draft.target.port}/${draft.target.database} · ${draft.schema}.${draft.table} · ${strings(context).changes}: ${draft.changes} · ${workbenchDraftState(context, draft.state)}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      controls.textButton(
                        strings(context).rebindVerifiedEdits,
                        draft.state == 'STAGED' &&
                                payload.owner?.sessionId != null
                            ? () => model.command(
                                () => payload.rebind(draft),
                                ownerId: owner.id,
                              )
                            : null,
                      ),
                      controls.textButton(
                        strings(context).discardRecoveryRecord,
                        () => model.command(
                          () => payload.discard(draft),
                          ownerId: owner.id,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (payload is ExecutionDocumentData) {
      final job = model.jobForOwner(owner),
          result = model.displayResultForOwner(owner);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${payload.label} · ${workbenchCapturedOwner(context, payload.target)}',
            ),
          ),
          if (job != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '${workbenchJobState(context, job.state)} · ${job.durationMs} ms',
              ),
            ),
          if (result != null)
            Expanded(
              child: ResultGrid(
                key: ValueKey(result.resultId),
                model: model,
                controls: controls,
                result: result,
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    job?.messages.join('\n') ?? strings(context).loading,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    if (payload is TransferDocumentData) {
      return TransferDocument(
        model: model,
        owner: owner,
        data: payload,
        controls: controls,
      );
    }
    if (payload is ChangesReviewData) {
      return ChangesDocumentView(
        model: model,
        owner: owner,
        controls: controls,
        review: payload,
      );
    }
    if (payload is PrivilegesDocumentData) {
      return PrivilegesForm(
        target: payload.target,
        controls: controls,
        engine: payload.engine,
        initial: payload.initial,
        schema: payload.schema,
        table: payload.table,
        writable: payload.writable,
        request: payload.request,
        account: payload.account,
        openSql: payload.openSql,
      );
    }
    if (owner.kind == WorkbenchDocumentKind.result) {
      final result = model.displayResultForOwner(owner);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${owner.retained!.target.name} · ${owner.retained!.target.host}:${owner.retained!.target.port}/${owner.retained!.target.database} · ${workbenchEnvironment(context, owner.retained!.target.environment)}',
            ),
          ),
          if (result == null) Text(strings(context).retainedUnavailable),
          if (result != null)
            Expanded(
              child:
                  owner.view.output == 'plan' &&
                      owner
                              .view
                              .results[model.sourceResultId(result.resultId)]
                              ?.planEvidence
                          is PlanData
                  ? PlanEvidenceView(
                      model: model,
                      controls: controls,
                      retained: owner.retained,
                      data:
                          owner
                                  .view
                                  .results[model.sourceResultId(
                                    result.resultId,
                                  )]!
                                  .planEvidence!
                              as PlanData,
                    )
                  : ResultGrid(
                      model: model,
                      controls: controls,
                      result: result,
                    ),
            ),
        ],
      );
    }
    if (payload is ObjectSearchData) {
      return DatabaseObjectSearch(
        model: model,
        controls: controls,
        target: payload,
        owner: owner,
      );
    }
    if (payload is AdministrationData) {
      return payload.activities
          ? ActivityView(
              model: model,
              target: payload.target,
              controls: controls,
              action: payload.activityAction!,
              inspection: payload.activityInspection,
            )
          : CapabilitiesView(
              model: model,
              target: payload.target,
              controls: controls,
              inspection: payload.capabilityInspection,
            );
    }
    if (payload is GlobalToolData) {
      return switch (payload.kind) {
        GlobalToolKind.history => HistoryView(
          model: model,
          controls: controls,
          inspection: payload.history,
          admitEvidence: (units) => model.reserveDocumentEvidence(owner, units),
        ),
        GlobalToolKind.retained => ListView(
          children: [
            for (final retained in model.retainedResults.values)
              WorkbenchEvidenceRecord(
                controls: controls,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${retained.target.name} · ${retained.target.host}:${retained.target.port}/${retained.target.database} · ${strings(context).rowsLabel}: ${retained.result.fetchedRows} · ${retained.availability}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        controls.textButton(
                          strings(context).results,
                          retained.disposalPending
                              ? null
                              : () => model.openRetainedResult(retained),
                        ),
                        controls.textButton(
                          strings(context).disposeResult,
                          () => model.command(
                            () => model.disposeRetainedResult(
                              retained.result.resultId,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
        GlobalToolKind.jobs || GlobalToolKind.problems => ListView(
          children: [
            if (payload.kind == GlobalToolKind.problems &&
                !model.jobs.values.any(
                  (job) => WorkbenchModel.problemJob(job.state),
                ))
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(strings(context).noProblems),
              ),
            for (final job in model.jobs.values)
              if (payload.kind == GlobalToolKind.jobs ||
                  WorkbenchModel.problemJob(job.state))
                WorkbenchEvidenceRecord(
                  controls: controls,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${model.workbenchDocuments.where((d) => d.id == model.jobDocuments[job.jobId]).firstOrNull?.displayTitle ?? strings(context).jobs} · ${workbenchJobState(context, job.state)} · ${job.durationMs} ms',
                      ),
                      Text(
                        job.hasToolKind()
                            ? workbenchToolLabel(context, job.toolKind)
                            : strings(context).sqlExecution,
                      ),
                      if (job.hasTarget())
                        Text(
                          '${job.target.name} · ${workbenchEnvironment(context, job.target.environment)} · ${job.target.host}:${job.target.port}/${job.target.database}/${job.sourceSchema}${job.target.readOnly ? ' · ${strings(context).readOnlyPolicy}' : ''}',
                        ),
                      if (job.progressRows.toInt() != 0)
                        Text(
                          '${strings(context).rowsLabel}: ${job.progressRows}',
                        ),
                      if (job.messages.isNotEmpty)
                        SelectableText(job.messages.join('\n')),
                      if (WorkbenchFailureReason.fromWire(job.errorCode)
                          case final reason?)
                        Text(reason.localized(strings(context))),
                      if (job.state == rpc.JobState.UNKNOWN_OUTCOME)
                        controls.status(
                          strings(context).outcomeUnknownNote,
                          error: true,
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (model.jobDocuments[job.jobId] case final String id
                              when model.workbenchDocuments.any(
                                (document) => document.id == id,
                              ))
                            controls.textButton(
                              strings(context).openOwner,
                              () => model.activateOwner(id),
                            ),
                          for (final evidence
                              in model.retainedResults.values
                                  .where(
                                    (result) =>
                                        result.jobId == job.jobId &&
                                        !result.disposalPending,
                                  )
                                  .take(1))
                            controls.textButton(
                              strings(context).retainedData,
                              () => model.openRetainedResult(evidence),
                            ),
                          if (!WorkbenchModel.terminalJob(job.state))
                            controls.textButton(
                              strings(context).cancel,
                              () async {
                                await model.commands!.invoke(
                                  'job.cancel',
                                  WorkbenchCommandContext(jobId: job.jobId),
                                );
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
          ],
        ),
      };
    }
    if (payload is ComparisonData) {
      return ComparisonDocument(
        model: model,
        controls: controls,
        data: payload,
        owner: owner,
      );
    }
    if (payload is DesignerData) {
      return ObjectDesignerForm(
        key: ObjectKey(payload),
        controls: controls,
        inspected: payload.inspected,
        draft: payload.draft,
        admitDraft: (candidate) => model.admitDesignDraft(owner, candidate),
        onChanged: () {
          owner.contentDirty = payload.draft.dirty;
          model.recordDesignChange(owner);
        },
        target: payload.request,
        referenceState: payload.referenceState,
        inspectReferenceSchema: (schema) async {
          final changedContextLabel = strings(context).metadataContextChanged;
          model.requireTarget(payload.target);
          final captured = model.captureTarget(owner: owner);
          final result = await model.ownedRequest(
            captured,
            () => captured.backend.client.schemaTool(
              rpc.SchemaToolRequest(
                context: captured.backend.context(),
                sessionId: captured.sessionId,
                schema: schema,
                action: rpc.SchemaToolAction.CAPTURE_SCHEMA,
              ),
            ),
            text: true,
          );
          model.requireTarget(captured, text: true);
          final originalUnits = owner.evidenceUnits;
          final baseUnits = originalUnits - payload.referenceEvidenceUnits;
          // Parsing and retained names use the same aggregate document budget.
          model.reserveDocumentEvidence(
            owner,
            baseUnits + result.snapshot.length * 4,
          );
          try {
            final snapshot =
                jsonDecode(result.snapshot) as Map<String, dynamic>;
            if (snapshot['schema'] != schema ||
                snapshot['engine'] !=
                    jsonDecode(payload.inspected.snapshot)['engine']) {
              throw StateError(changedContextLabel);
            }
            final tables = snapshot['tables'] as Map<String, dynamic>;
            final columns = <String, List<String>>{
              for (final entry in tables.entries)
                entry.key:
                    ((entry.value as Map<String, dynamic>)['columns']
                            as Map<String, dynamic>)
                        .keys
                        .toList(),
            };
            final units = jsonEncode(columns).length * 4;
            model.reserveDocumentEvidence(owner, baseUnits + units);
            payload.referenceEvidenceUnits = units;
            payload.referenceState
              ..schema = schema
              ..columns = columns;
            return columns;
          } catch (_) {
            model.reserveDocumentEvidence(owner, originalUnits);
            rethrow;
          }
        },
        generate: (request) async {
          model.requireTarget(payload.target);
          final captured = model.captureTarget(owner: owner);
          if (request.sessionId != captured.sessionId ||
              request.context.instanceId != captured.backend.instanceId) {
            throw StateError(
              'The captured design target changed; inspect metadata again',
            );
          }
          final result = await model.ownedRequest(
            captured,
            () => captured.backend.client.schemaTool(request),
            text: true,
          );
          model.requireTarget(captured, text: true);
          return result;
        },
        openSql: (plan) {
          model.requireTarget(payload.target);
          final profile = model.sessions[payload.target.sessionId]?.profile.id;
          model.newDocument(
            text: '-- ${plan.risks.join('\n-- ')}\n${plan.sql.join('\n')}',
          );
          model.document.profileId = profile;
          model.activeOwner.evidenceProfile = payload.target.profile
              ?.deepCopy();
        },
      );
    }
    if (owner.purpose == 'design' && payload == null) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(_objectPath(model, owner)),
          Text(strings(context).recoveredDesign),
          if (owner.sessionId == null)
            controls.button(
              strings(context).connect,
              () => model.commands!.invoke(
                'connection.connect',
                model.commandContext,
              ),
            ),
          controls.button(
            strings(context).objectDesigner,
            owner.sessionId == null
                ? null
                : () => model.commands!.invoke(
                    'schema.designer',
                    model.commandContext,
                  ),
          ),
          for (final entry in owner.designDraft.fields.entries)
            if (entry.value.isNotEmpty)
              SelectableText('${entry.key}: ${entry.value}'),
        ],
      );
    }
    if (payload is PlanData) {
      return PlanEvidenceView(
        model: model,
        data: payload,
        retained: owner.retained,
        controls: controls,
      );
    }
    if (payload is DiagramDocumentData) {
      return DiagramDocumentView(
        model: model,
        tables: payload.tables,
        edges: payload.edges,
        state: payload,
        ui: controls,
      );
    }
    if (owner.object != null) {
      final result = model.displayResultForOwner(owner);
      final history =
          owner.view.subview == 'data' &&
              owner.kind == WorkbenchDocumentKind.table &&
              model.jobsForOwner(owner).isNotEmpty
          ? ConstrainedBox(
              key: ValueKey('table-execution-history:${owner.id}'),
              constraints: const BoxConstraints(maxWidth: 240),
              child: controls.menu(strings(context).results, [
                for (final job in model.jobsForOwner(owner))
                  DesktopMenuAction(
                    '${workbenchJobState(context, job.state)} · ${job.durationMs} ms',
                    () => model.selectExecution(job.executionId, owner: owner),
                  ),
              ]),
            )
          : null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (owner.view.subview == 'data' && result == null && history != null)
            WorkbenchStrip(
              controls: controls,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: history,
              ),
            ),
          if (owner.view.acquiringData ||
              model.browseReplacements.containsKey(owner.id))
            Text(strings(context).loading),
          if (owner.view.dataError.isNotEmpty) ...[
            Text(
              WorkbenchFailureReason.fromWire(
                    model.jobForOwner(owner)?.errorCode ?? '',
                  )?.localized(strings(context)) ??
                  owner.view.dataError,
            ),
            controls.button(
              strings(context).retry,
              owner.view.acquiringData
                  ? null
                  : () => model.commands!.invoke(
                      'object.refresh',
                      WorkbenchCommandContext(
                        owner: owner,
                        object: owner.object,
                        profileId: owner.profileId,
                        sessionId: owner.sessionId,
                      ),
                    ),
            ),
          ],
          if (result != null &&
              model
                      .editBatches['${owner.id}\u0000${model.sourceResultId(result.resultId)}']
                      ?.appliedSnapshot ==
                  true)
            Text(strings(context).preChangeSnapshot),
          Expanded(
            child: owner.view.subview == 'data' && result == null
                ? SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        owner.view.acquiringData
                            ? strings(context).loading
                            : model.jobForOwner(owner)?.messages.join('\n') ??
                                  '${strings(context).openData} · ${strings(context).refresh}',
                      ),
                    ),
                  )
                : owner.view.subview == 'data' && result != null
                ? ResultGrid(
                    key: ValueKey(result.resultId),
                    model: model,
                    controls: controls,
                    result: result,
                    outputControls: history,
                  )
                : ObjectDocumentView(
                    model: model,
                    owner: owner,
                    controls: controls,
                  ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class PlanEvidenceView extends StatelessWidget {
  const PlanEvidenceView({
    super.key,
    required this.model,
    required this.data,
    required this.controls,
    this.retained,
  });
  final WorkbenchModel model;
  final PlanData data;
  final DesktopControls controls;
  final rpc.RetainedResult? retained;
  Future<void> inspectProvenance(
    BuildContext context,
    rpc.RetainedResult evidence,
  ) => controls.dialog<void>(
    context,
    strings(context).sqlProvenance,
    SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${evidence.target.name} · ${workbenchEnvironment(context, evidence.target.environment)} · ${evidence.target.host}:${evidence.target.port}/${evidence.target.database}',
          ),
          WorkbenchCodeEvidence(
            controls: controls,
            text: valueText(evidence.sqlProvenance),
          ),
        ],
      ),
    ),
    [
      controls.button(
        strings(context).close,
        () => Navigator.of(context).pop(),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxHeight < 260 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (retained case final evidence? when !compact)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${strings(context).sqlProvenance}: ${valueText(evidence.sqlProvenance)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  controls.button(
                    strings(context).retainedData,
                    () => model.openRetainedResult(evidence),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PlanView(
              data: data,
              controls: controls,
              contextActions: [
                if (retained case final evidence?)
                  DesktopMenuAction(
                    strings(context).sqlProvenance,
                    () => inspectProvenance(context, evidence),
                  ),
                if (retained case final evidence?)
                  DesktopMenuAction(
                    strings(context).retainedData,
                    () => model.openRetainedResult(evidence),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class ObjectDocumentView extends StatefulWidget {
  const ObjectDocumentView({
    super.key,
    required this.model,
    required this.owner,
    required this.controls,
  });
  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final DesktopControls controls;
  @override
  State<ObjectDocumentView> createState() => _ObjectDocumentViewState();
}

class _ObjectDocumentViewState extends State<ObjectDocumentView> {
  ResponseFuture<rpc.SchemaObjects>? metadataRequest;
  ResponseFuture<rpc.SchemaToolResult>? definitionRequest;
  @override
  void dispose() {
    widget.model.removeListener(metadataDomainChanged);
    generation++;
    metadataRequest?.cancel();
    definitionRequest?.cancel();
    super.dispose();
  }

  late rpc.ObjectKind section;
  bool dependencies = false;
  List<rpc.SchemaObject> objects = [];
  int? objectsSectionKey;
  String availability = '';
  int generation = 0;
  bool initialized = false;
  int metadataRevision = 0;
  CapturedWorkbenchTarget? metadataContext, metadataOwner;
  String? metadataSessionId;
  ({String source, int configuration})? metadataDomain, observedDomain;
  WorkbenchFailureReason? observedUnavailability;
  bool domainReloadQueued = false;
  int domainReloadGeneration = 0;
  ({String source, int configuration})? get currentMetadataDomain {
    final sessionId = inspectionSessionId;
    final stamp = sessionId == null
        ? null
        : widget.model.metadataStampForSession(sessionId);
    return stamp == null
        ? null
        : (source: stamp.sourceIdentity, configuration: stamp.configuration);
  }

  String? get inspectionSessionId =>
      structureInspectionSessionId(widget.model, widget.owner);

  WorkbenchFailureReason? get metadataUnavailableReason {
    if (inspectionSessionId != null) return null;
    for (final id in [
      widget.owner.sessionId,
      widget.owner.view.metadataSessionId,
      metadataSessionId,
      widget.model.explorerSessions[widget.owner.object!.profileId],
    ]) {
      if (id == null || id.isEmpty) continue;
      final session = widget.model.sessions[id];
      if (session == null ||
          session.profile.id != widget.owner.object!.profileId) {
        return WorkbenchFailureReason.unavailable;
      }
      final reason = widget.model.metadataSessionUnavailableReason(id);
      if (reason != null) return reason;
    }
    return null;
  }

  bool get metadataCurrent {
    if (metadataUnavailableReason != null) return false;
    if (metadataContext == null || metadataOwner == null) return true;
    if (!metadataOwner!.references(widget.owner) ||
        metadataDomain != currentMetadataDomain) {
      return false;
    }
    try {
      widget.model.requireTarget(metadataContext!);
      widget.model.requireTarget(metadataOwner!);
      return inspectionSessionId == metadataSessionId &&
          widget.model.sessions[metadataSessionId]?.profile ==
              metadataContext!.profile;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    metadataRevision = widget.owner.view.metadataRevision;
    observedDomain = currentMetadataDomain;
    observedUnavailability = metadataUnavailableReason;
    widget.model.addListener(metadataDomainChanged);
  }

  void metadataDomainChanged() {
    if (!mounted) return;
    final next = currentMetadataDomain;
    final unavailable = metadataUnavailableReason;
    if (next == observedDomain && unavailable == observedUnavailability) return;
    final previous = observedDomain;
    observedDomain = next;
    observedUnavailability = unavailable;
    if (previous == null && metadataContext == null && unavailable == null) {
      return;
    }
    generation++;
    domainReloadGeneration = generation;
    unawaited(metadataRequest?.cancel());
    unawaited(definitionRequest?.cancel());
    setState(
      () => availability =
          unavailable?.localized(strings(context)) ??
          strings(context).staleRefresh,
    );
    // No automatic connection or transaction recovery. Only an already owned
    // source/configuration domain can schedule this ordinary metadata read.
    if (next == null ||
        !widget.model.metadataSessionUsable(inspectionSessionId) ||
        domainReloadQueued) {
      return;
    }
    domainReloadQueued = true;
    final owner = widget.owner, model = widget.model;
    scheduleMicrotask(() {
      domainReloadQueued = false;
      if (mounted &&
          identical(widget.owner, owner) &&
          identical(widget.model, model) &&
          currentMetadataDomain != null &&
          model.metadataSessionUsable(inspectionSessionId) &&
          generation == domainReloadGeneration) {
        unawaited(load());
      }
    });
  }

  int get sectionKey => dependencies ? 10 : section.value;
  void acceptObjects(List<rpc.SchemaObject> incoming) {
    objects = incoming;
    objectsSectionKey = sectionKey;
    final selections = widget.owner.view.structureSelections;
    if (!selections.containsKey(sectionKey)) {
      selections[sectionKey] = incoming.isEmpty
          ? null
          : schemaObjectSelection(incoming.first);
    } else if (!incoming.any(
      (o) => schemaObjectSelection(o) == selections[sectionKey],
    )) {
      selections[sectionKey] = null;
    }
  }

  @override
  void didUpdateWidget(covariant ObjectDocumentView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ownerChanged =
        !identical(oldWidget.owner, widget.owner) ||
        !identical(oldWidget.model, widget.model);
    if (!identical(oldWidget.model, widget.model)) {
      oldWidget.model.removeListener(metadataDomainChanged);
      widget.model.addListener(metadataDomainChanged);
    }
    if (ownerChanged) {
      observedDomain = currentMetadataDomain;
      observedUnavailability = metadataUnavailableReason;
    }
    if (ownerChanged ||
        metadataRevision != widget.owner.view.metadataRevision) {
      metadataRevision = widget.owner.view.metadataRevision;
      final value = structureSection(context, widget.owner);
      dependencies = value == 10;
      section = rpc.ObjectKind.valueOf(value) ?? rpc.ObjectKind.TABLE;
      // Invalidate synchronously: an older reply must not enter the newly
      // selected section between this build and a later frame callback.
      unawaited(load());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!initialized) {
      initialized = true;
      final value = structureSection(context, widget.owner);
      dependencies = value == 10;
      section = rpc.ObjectKind.valueOf(value) ?? rpc.ObjectKind.TABLE;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) load();
      });
    }
  }

  Future<void> load() async {
    final requested = ++generation, object = widget.owner.object!;
    // Preserve a complete page only under its existing presentation authority.
    // A new section, physical context, backend, profile or owner clears it now.
    final preserveObjects =
        objectsSectionKey == sectionKey &&
        metadataContext != null &&
        metadataOwner?.references(widget.owner) == true &&
        metadataCurrent;
    setState(() {
      availability = strings(context).loading;
      if (!preserveObjects) {
        objects = [];
        objectsSectionKey = null;
        metadataContext = metadataOwner = null;
      }
    });
    await metadataRequest?.cancel();
    await definitionRequest?.cancel();
    if (!mounted || requested != generation) return;
    final model = widget.model, backend = widget.model.backend;
    final sessionId = inspectionSessionId;
    final unavailable = metadataUnavailableReason;
    if (unavailable != null) {
      setState(() => availability = unavailable.localized(strings(context)));
      return;
    }
    if (backend != null &&
        sessionId == null &&
        widget.owner.view.metadataRequested &&
        model.commands != null) {
      setState(() => availability = strings(context).loading);
      await model.commands!.invoke(
        'connection.connect',
        WorkbenchCommandContext(
          owner: widget.owner,
          object: widget.owner.object,
          profileId: widget.owner.profileId,
        ),
      );
      if (!mounted || requested != generation) return;
      if (inspectionSessionId != null) {
        await load();
        return;
      }
    }
    if (backend == null || sessionId == null) {
      setState(
        () => availability =
            'Connect this connection explicitly to inspect metadata',
      );
      return;
    }
    final connectionOwner = model.operationOwners.firstWhere(
      (d) => d.sessionId == sessionId,
    );
    final captured = model.captureTarget(owner: connectionOwner);
    final ownerCapture = model.captureTarget(owner: widget.owner);
    void requireInspection() {
      model.requireTarget(captured);
      model.requireTarget(ownerCapture);
      if (inspectionSessionId != sessionId) {
        throw StateError('The metadata inspection session changed');
      }
      if (widget.owner.object != object) {
        throw StateError(
          'Metadata reply belongs to another object or inspection context',
        );
      }
    }

    void rememberInspection() {
      metadataContext = model.captureTarget(owner: connectionOwner);
      metadataOwner = model.captureTarget(owner: widget.owner);
      metadataSessionId = sessionId;
      metadataDomain = currentMetadataDomain;
    }

    try {
      model.requireDocumentTarget(
        widget.owner,
        model.sessions[sessionId]!.profile,
      );
      if (dependencies ||
          section == rpc.ObjectKind.TABLE ||
          object.kind == rpc.ObjectKind.ROUTINE ||
          object.kind == rpc.ObjectKind.SEQUENCE) {
        final inspected = await model.ownedRequest(
          captured,
          () => definitionRequest = backend.client.schemaTool(
            rpc.SchemaToolRequest(
              context: backend.context(),
              sessionId: sessionId,
              action: dependencies
                  ? rpc.SchemaToolAction.INSPECT_OBJECT
                  : rpc.SchemaToolAction.OBJECT_DEFINITION,
              catalog: object.catalog,
              schema: object.schema,
              table: object.parent.isEmpty ? object.name : object.parent,
              objectName: object.name,
              kind: object.kind,
              identifier: object.identifier,
            ),
          ),
        );
        requireInspection();
        if (!mounted || requested != generation) return;
        rememberInspection();
        if (!dependencies) {
          final actual = inspected.inspectedObject;
          if (actual.catalog != object.catalog ||
              actual.schema != object.schema ||
              actual.name != object.name ||
              actual.kind != object.kind ||
              object.subtype != rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED &&
                  actual.subtype != object.subtype ||
              actual.table != object.parent ||
              actual.identifier != object.identifier) {
            throw StateError('The definition reply belongs to another object');
          }
          setState(() {
            acceptObjects([
              actual.deepCopy()..definition = inspected.definition,
            ]);
            availability = inspected.definition.isEmpty
                ? strings(context).metadataDefinitionUnavailable
                : inspected.provenance == 'native'
                ? strings(context).metadataDefinitionCaptured
                : '${strings(context).generatedSql} · ${strings(context).partial}';
          });
          return;
        }
        final snapshot = jsonDecode(inspected.snapshot) as Map<String, dynamic>;
        if (dependencies) {
          final graph =
              snapshot['objectDependencies'] as Map<String, dynamic>? ?? {};
          final key =
              '${object.kind == rpc.ObjectKind.VIEW
                  ? 'V'
                  : object.kind == rpc.ObjectKind.ROUTINE
                  ? 'R'
                  : 'T'}:${object.kind == rpc.ObjectKind.ROUTINE ? object.identifier : object.name}';
          final dependents = graph.entries
              .where((e) => e.value is List && (e.value as List).contains(key))
              .map((e) => e.key)
              .toList();
          final outgoing = graph[key] is List
              ? (graph[key] as List).map((v) => '$v').toList()
              : <String>[];
          setState(() {
            acceptObjects([
              for (final name in outgoing)
                rpc.SchemaObject(
                  name: name,
                  properties: {
                    'Relationship': 'Referenced by this object',
                  }.entries,
                ),
              for (final name in dependents)
                rpc.SchemaObject(
                  name: name,
                  properties: {
                    'Relationship': 'Depends on this object',
                  }.entries,
                ),
            ]);
            availability = snapshot['engine'] == 'POSTGRESQL'
                ? 'Captured native dependencies in this schema; dynamic SQL is not inferred'
                : 'Native routine dependencies are unavailable for this engine; use captured view and foreign-key metadata';
          });
          return;
        }
      }
      final response = await model.readMetadata(
        captured,
        rpc.ExploreRequest(
          context: backend.context(),
          sessionId: sessionId,
          catalog: object.catalog,
          schema: object.schema,
          table: object.parent.isEmpty ? object.name : object.parent,
          kind: section,
          exactName: object.parent.isNotEmpty,
          search: object.parent.isNotEmpty ? object.name : '',
          identifier: object.parent.isNotEmpty ? object.identifier : '',
        ),
        maxObjects: object.parent.isNotEmpty
            ? 1
            : section == rpc.ObjectKind.COLUMN
            ? 2048
            : 10000,
        current: () {
          requireInspection();
          return mounted && requested == generation;
        },
        onRequest: (request) => metadataRequest = request,
      );
      requireInspection();
      if (!mounted ||
          requested != generation ||
          !model.taskDocuments.contains(widget.owner)) {
        return;
      }
      if (!model.acceptMetadataRevision(sessionId, response)) {
        throw const LocalWorkbenchFailure(WorkbenchFailureReason.stale);
      }
      rememberInspection();
      model.reserveDocumentEvidence(
        widget.owner,
        response.writeToBuffer().length * 4,
      );
      setState(() {
        acceptObjects(response.objects);
        availability = response.availability;
      });
    } catch (error) {
      if (mounted && requested == generation) {
        setState(
          () => availability = error is GrpcError
              ? ConnectionFailure.from(error).localizedSummary(strings(context))
              : operationFailureSummary(error, locale: strings(context)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = metadataCurrent;
    final direct =
        widget.owner.object!.parent.isNotEmpty ||
        section == rpc.ObjectKind.TABLE;
    final ambiguous = direct && objects.length > 1;
    final selectedId = widget.owner.view.structureSelections[sectionKey];
    final selected = current
        ? objects
              .where((o) => schemaObjectSelection(o) == selectedId)
              .firstOrNull
        : null;
    final controls = widget.controls;
    final status =
        metadataUnavailableReason?.localized(strings(context)) ??
        (!current
            ? strings(context).metadataContextChanged
            : ambiguous
            ? strings(context).unavailable
            : workbenchMetadataAvailability(
                context,
                availability,
                empty: objects.isEmpty,
              ));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!current ||
            ambiguous ||
            availability.toLowerCase() != 'available' ||
            objects.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: controls.status(status),
          ),
        Expanded(
          child: !current || objects.isEmpty || ambiguous
              ? const SizedBox.shrink()
              : direct
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: SchemaObjectDetails(
                    controls: controls,
                    object: objects.single,
                    nativeDefinition: section == rpc.ObjectKind.TABLE,
                    showName: false,
                  ),
                )
              : LayoutBuilder(
                  builder: (context, bounds) {
                    final row = math.max(
                      36.0,
                      controls.appearance(context).rowHeight(context) + 4,
                    );
                    final overviewHeight = math.min(
                      (objects.length + 1) * row + 12,
                      bounds.maxHeight * .5,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: overviewHeight,
                          child: SchemaOverview(
                            controls: controls,
                            objects: objects,
                            kind: dependencies
                                ? rpc.ObjectKind.CATALOG
                                : section,
                            selected: selectedId,
                            select: (object) {
                              setState(
                                () =>
                                    widget
                                            .owner
                                            .view
                                            .structureSelections[sectionKey] =
                                        schemaObjectSelection(object),
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            key: ValueKey('schema-details:$selectedId'),
                            padding: const EdgeInsets.all(12),
                            child: selected == null
                                ? Text(
                                    strings(
                                      context,
                                    ).metadataSelectionUnavailable,
                                  )
                                : SchemaObjectDetails(
                                    controls: controls,
                                    object: selected,
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class ObjectSearchData {
  ObjectSearchData(
    this.profileId,
    this.target, {
    this.catalog = '',
    this.schema = '',
  });
  final String profileId;
  final String catalog, schema;
  final CapturedWorkbenchTarget target;
  String get sessionId => target.sessionId!;
  String query = '', continuation = '', availability = '';
  double scrollOffset = 0;
  List<rpc.SchemaObject> objects = [];
  String? acceptedQuery;
  CapturedWorkbenchTarget? acceptedOwner;
}

class DatabaseObjectSearch extends StatefulWidget {
  const DatabaseObjectSearch({
    super.key,
    required this.model,
    required this.controls,
    required this.target,
    required this.owner,
    this.externalQuery,
  });
  final TextEditingController? externalQuery;
  final WorkbenchModel model;
  final DesktopControls controls;
  final ObjectSearchData target;
  final WorkbenchDocument owner;
  @override
  State<DatabaseObjectSearch> createState() => DatabaseObjectSearchState();
}

class DatabaseObjectSearchState extends State<DatabaseObjectSearch> {
  bool get searchTargetCurrent {
    try {
      widget.model.requireTarget(widget.target.target);
      if (acceptedOwner != null) widget.model.requireTarget(acceptedOwner!);
      return true;
    } catch (_) {
      return false;
    }
  }

  late final query = widget.externalQuery ?? TextEditingController();
  Timer? debounce;
  int selected = 0;
  final rowKeys = <rpc.SchemaObject, GlobalKey<WorkbenchRecordState>>{};
  CapturedWorkbenchTarget? acceptedOwner;
  late final ScrollController scroll;
  ResponseFuture<rpc.SchemaObjects>? request;
  List<rpc.SchemaObject> objects = [];
  String continuation = '', availability = '';
  int generation = 0;
  @override
  void initState() {
    super.initState();
    if (widget.externalQuery == null) query.text = widget.target.query;
    query.addListener(queryChanged);
    objects = widget.target.objects;
    acceptedOwner = widget.target.acceptedOwner;
    if (widget.externalQuery != null &&
        widget.target.acceptedQuery != query.text) {
      objects = [];
    }
    continuation = widget.target.continuation;
    availability = widget.target.availability;
    scroll = ScrollController(initialScrollOffset: widget.target.scrollOffset);
    if (widget.externalQuery != null &&
        query.text.isNotEmpty &&
        !query.value.composing.isValid &&
        widget.target.acceptedQuery != query.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) search();
      });
    }
    scroll.addListener(() {
      if (scroll.hasClients) widget.target.scrollOffset = scroll.offset;
    });
  }

  Future<void> retireRequest() async {
    final previous = request;
    request = null;
    try {
      await previous?.cancel();
    } catch (_) {
      /* Late replies still fail generation admission. */
    }
  }

  Future<void> search({bool next = false}) async {
    final requested = ++generation;
    await retireRequest();
    if (!mounted || requested != generation) return;
    setState(() => availability = strings(context).loading);
    ResponseFuture<rpc.SchemaObjects>? ownedCall;
    try {
      final model = widget.model, captured = widget.target.target;
      model.requireTarget(captured);
      final ownerCapture = model.captureTarget(owner: widget.owner);
      final backend = captured.backend,
          session = model.sessions[captured.sessionId]!;
      final expectedCatalog = widget.target.catalog.isNotEmpty
          ? widget.target.catalog
          : session.profile.engine != rpc.Engine.POSTGRESQL &&
                widget.target.schema.isNotEmpty
          ? widget.target.schema
          : session.currentCatalog;
      final requestedContinuation = next ? continuation : '';
      if (query.text.length > 256) {
        throw StateError('Object search text exceeds 256 characters');
      }
      final call = backend.client.explore(
        rpc.ExploreRequest(
          context: backend.context(),
          sessionId: session.sessionId,
          globalSearch: true,
          catalog: widget.target.catalog,
          schema: widget.target.schema,
          expectedSessionRevision: session.sessionRevision,
          expectedContextRevision: session.contextRevision,
          search: query.text,
          continuation: requestedContinuation,
          limit: 200,
        ),
      );
      request = ownedCall = call;
      final response = await model.ownedRequest(captured, () => call);
      model.requireTarget(ownerCapture);
      if (!mounted ||
          generation != requested ||
          !identical(backend, widget.model.backend) ||
          widget.model.sessions[session.sessionId]?.contextRevision !=
              session.contextRevision ||
          widget.model.sessions[session.sessionId]?.sessionRevision !=
              session.sessionRevision) {
        return;
      }
      if (response.instanceId != backend.instanceId ||
          response.profileId != session.profile.id ||
          response.sessionId != session.sessionId ||
          response.contextRevision != session.contextRevision ||
          response.sessionRevision != session.sessionRevision ||
          response.catalog != expectedCatalog ||
          response.schema != widget.target.schema) {
        throw StateError(
          'Metadata reply belongs to another object or inspection context',
        );
      }
      if (response.complete && response.continuation.isNotEmpty ||
          !response.complete &&
              (response.continuation.isEmpty ||
                  response.objects.isEmpty ||
                  response.continuation == requestedContinuation)) {
        throw StateError(
          'Metadata continuation did not advance; refresh this scope',
        );
      }
      if (response.objects.length > 200 ||
          response.writeToBuffer().length > 524288 ||
          response.continuation.length > 24576 ||
          response.objects.any(
            (object) => utf8.encode(object.identifier).length > 8192,
          )) {
        throw StateError(
          'Metadata resource budget reached; narrow the selected object scope',
        );
      }
      model.reserveDocumentEvidence(
        widget.owner,
        response.writeToBuffer().length * 2 + query.text.length * 2,
      );
      acceptedOwner = ownerCapture;
      widget.target.acceptedOwner = ownerCapture;
      widget.target.acceptedQuery = query.text;
      setState(() {
        selected = 0;
        rowKeys.clear();
        objects = response.objects;
        continuation = response.continuation;
        availability = response.availability;
        widget.target.objects = objects;
        widget.target.continuation = continuation;
        widget.target.availability = availability;
      });
    } catch (error) {
      if (mounted && requested == generation) {
        setState(
          () => availability = operationFailureSummary(
            error,
            locale: strings(context),
          ),
        );
      }
    } finally {
      if (identical(request, ownedCall)) request = null;
    }
  }

  void queryChanged() {
    if (query.value.composing.isValid) return;
    generation++;
    unawaited(retireRequest());
    debounce?.cancel();
    setState(() {
      objects = [];
      selected = 0;
      continuation = '';
    });
    if (query.text.isEmpty) {
      availability = '';
      widget.target.objects = [];
      widget.target.acceptedQuery = null;
      widget.target.acceptedOwner = acceptedOwner = null;
      return;
    }
    debounce = Timer(const Duration(milliseconds: 160), () => search());
  }

  void move(int delta) {
    if (objects.isEmpty) return;
    final rowFocus =
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorWidgetOfExactType<WorkbenchRecord>() !=
        null;
    final focusOwner = FocusManager.instance.primaryFocus;
    setState(() => selected = (selected + delta) % objects.length);
    final snapshot = objects, index = selected;
    unawaited(
      revealSearchRecord(
        scroll: scroll,
        keys: rowKeys,
        identity: objects[index],
        index: index,
        indexOf: snapshot.indexOf,
        current: () =>
            mounted && identical(objects, snapshot) && selected == index,
        focusOwner: focusOwner,
        takeFocus: rowFocus,
      ),
    );
  }

  void activateSelection() {
    if (selected < objects.length && searchTargetCurrent) {
      activateObject(objects[selected]);
    }
  }

  Future<void> activateObject(rpc.SchemaObject object) async {
    final identity = DatabaseObjectIdentity(
      profileId: widget.target.profileId,
      catalog: object.catalog,
      schema: object.schema,
      kind: object.kind,
      subtype: object.subtype,
      name: object.name,
      parent:
          [
            rpc.ObjectKind.COLUMN,
            rpc.ObjectKind.INDEX,
            rpc.ObjectKind.CONSTRAINT,
            rpc.ObjectKind.FOREIGN_KEY,
            rpc.ObjectKind.TRIGGER,
          ].contains(object.kind)
          ? object.table
          : '',
      identifier: object.identifier,
    );
    final l = strings(context);
    final sourceProfile = widget
        .model
        .sessions[widget.target.target.sessionId]
        ?.profile
        .deepCopy();
    try {
      if (acceptedOwner != null) widget.model.requireTarget(acceptedOwner!);
      widget.model.requireTarget(widget.target.target);
      await widget.model.commands?.invoke(
        'object.structure',
        WorkbenchCommandContext(
          sessionId: widget.target.target.sessionId,
          profileId: widget.target.profileId,
          object: identity,
          metadataObject: object.deepCopy(),
          creationScope: DatabaseCreationScope(
            profileId: identity.profileId,
            catalog: identity.catalog,
            schema: identity.schema,
          ),
        ),
      );
      if (widget.model.profiles.any((p) => p.id == identity.profileId)) {
        widget.model.requireTarget(widget.target.target);
        widget.model.revealInExplorer(identity, evidenceProfile: sourceProfile);
      } else {
        widget.model.updateStatus(l.selectTarget);
      }
    } catch (error) {
      if (mounted) {
        widget.model.updateStatus(operationFailureSummary(error, locale: l));
      }
    }
  }

  @override
  void dispose() {
    generation++;
    unawaited(retireRequest());
    widget.target.query = query.text;
    scroll.dispose();
    debounce?.cancel();
    query.removeListener(queryChanged);
    if (widget.externalQuery == null) query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: widget.controls.tooltip(
          workbenchTargetDescription(context, widget.target.target),
          Text(
            workbenchTargetCaption(context, widget.target.target),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      if (widget.externalQuery == null)
        widget.controls.button(
          strings(context).searchObjects,
          () => widget.model.commands?.invoke(
            'connection.search',
            WorkbenchCommandContext(
              profileId: widget.target.profileId,
              sessionId: widget.target.sessionId,
            ),
          ),
        ),
      if (continuation.isNotEmpty)
        widget.controls.button(strings(context).more, () => search(next: true)),
      Text(workbenchMetadataAvailability(context, availability)),
      if (objects.isEmpty && availability != strings(context).loading)
        widget.controls.status(
          query.text.isEmpty
              ? strings(context).enterSearchText
              : strings(context).searchNoResults,
        ),
      if (!searchTargetCurrent) Text(strings(context).metadataContextChanged),
      Expanded(
        child: ListView(
          controller: scroll,
          padding: widget.controls.sidebarListPadding,
          children: [
            for (final object in objects)
              WorkbenchRecord(
                key: rowKeys.putIfAbsent(object, GlobalKey.new),
                controls: widget.controls,
                onFocusChange: (focused) {
                  if (focused) {
                    setState(() => selected = objects.indexOf(object));
                  }
                },
                leading: switch (object.kind) {
                  rpc.ObjectKind.TABLE => DesktopIcon.table,
                  rpc.ObjectKind.VIEW => DesktopIcon.view,
                  rpc.ObjectKind.COLUMN => DesktopIcon.column,
                  rpc.ObjectKind.ROUTINE => DesktopIcon.routine,
                  _ => DesktopIcon.folder,
                },
                label:
                    '${object.catalog}/${object.schema}/${[rpc.ObjectKind.COLUMN, rpc.ObjectKind.INDEX, rpc.ObjectKind.CONSTRAINT, rpc.ObjectKind.FOREIGN_KEY, rpc.ObjectKind.TRIGGER].contains(object.kind) ? '${object.table}/' : ''}${object.identifier.isEmpty ? object.name : object.identifier}',
                selected: objects.indexOf(object) == selected,
                takeFocus: widget.externalQuery == null,
                onPressed: !searchTargetCurrent
                    ? null
                    : () {
                        setState(() => selected = objects.indexOf(object));
                        activateObject(object);
                      },
                child: Text(
                  '${object.catalog}/${object.schema}/${[rpc.ObjectKind.COLUMN, rpc.ObjectKind.INDEX, rpc.ObjectKind.CONSTRAINT, rpc.ObjectKind.FOREIGN_KEY, rpc.ObjectKind.TRIGGER].contains(object.kind) ? '${object.table}/' : ''}${object.identifier.isEmpty ? object.name : object.identifier}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class ComparisonDocument extends StatefulWidget {
  const ComparisonDocument({
    super.key,
    required this.model,
    required this.controls,
    required this.data,
    required this.owner,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final ComparisonData data;
  final WorkbenchDocument owner;
  @override
  State<ComparisonDocument> createState() => _ComparisonDocumentState();
}

class _ComparisonDocumentState extends State<ComparisonDocument> {
  final filter = TextEditingController();
  rpc.SchemaDifference? selected;
  @override
  void initState() {
    super.initState();
    final data = widget.data;
    filter.text = data.filter;
    selected = data.selected;
    filter.addListener(() => setState(() {}));
    if (data.currentObject != null && !data.automaticCaptureRequested) {
      data.automaticCaptureRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await input(true, true);
        if (!mounted || data.error.isNotEmpty || data.currentSnapshot.isEmpty) {
          return;
        }
        await input(false, true);
        if (!mounted || data.error.isNotEmpty || data.desiredSnapshot.isEmpty) {
          return;
        }
        await compare();
      });
    }
  }

  Future<void> input(bool current, bool live) async {
    final data = widget.data, model = widget.model, owner = widget.owner;
    final revision = data.revision, backend = model.backend;
    if (data.busy) return;
    setState(() {
      data.busy = true;
      data.error = '';
    });
    try {
      String snapshot, label;
      if (live) {
        final object = current ? data.currentObject : data.desiredObject;
        final profileId = current ? data.currentProfile : data.desiredProfile;
        final profile = model.profiles
            .where((p) => p.id == profileId)
            .firstOrNull;
        if (profile == null) {
          throw StateError('Choose a connection for this input');
        }
        final metadataOwner = model.connectionOwner(profile);
        if (metadataOwner.sessionId == null) {
          await model.commands!.invoke(
            'connection.connect',
            WorkbenchCommandContext(
              owner: metadataOwner,
              profileId: profile.id,
            ),
          );
        }
        if (metadataOwner.sessionId == null) return;
        final captured = model.captureTarget(owner: metadataOwner);
        final reply = await model.ownedRequest(
          captured,
          () => captured.backend.client.schemaTool(
            rpc.SchemaToolRequest(
              context: captured.backend.context(),
              sessionId: captured.sessionId,
              action: rpc.SchemaToolAction.CAPTURE_SCHEMA,
              schema: data.schema,
              catalog: object?.catalog ?? '',
              table: object?.name ?? '',
              kind: object?.kind,
            ),
          ),
        );
        model.requireTarget(captured);
        if (object != null &&
            (!reply.hasInspectedObject() ||
                reply.inspectedObject.catalog != object.catalog ||
                reply.inspectedObject.schema != object.schema ||
                reply.inspectedObject.name != object.name ||
                reply.inspectedObject.kind != object.kind ||
                reply.inspectedObject.subtype !=
                    rpc.ObjectSubtype.ORDINARY_TABLE)) {
          throw StateError(
            'The scoped comparison reply identifies another object',
          );
        }
        if (!mounted) return;
        snapshot = reply.snapshot;
        final actual = captured.profile ?? profile;
        label =
            '${actual.name} · ${workbenchEnvironment(context, actual.environment)} · ${actual.host}:${actual.port}/${object?.catalog ?? captured.session?.currentCatalog ?? actual.database} / ${data.schema}${object == null ? '' : ' / ${object.name}'}';
      } else {
        final file = await openFile(
          confirmButtonText: current
              ? strings(context).currentSchema
              : strings(context).desiredSchema,
        );
        if (file == null) return;
        snapshot = utf8.decode(await readBoundedFile(File(file.path), 8388608));
        label = file.path;
      }
      if (!model.operationOwners.contains(owner) ||
          !identical(backend, model.backend) ||
          data.revision != revision) {
        throw StateError(
          'Comparison input changed; choose or capture it again',
        );
      }
      final total =
          snapshot.length +
          (current ? data.desiredSnapshot.length : data.currentSnapshot.length);
      model.documentBudget.auxiliary(owner, total * 2);
      if (current) {
        data.currentSnapshot = snapshot;
        data.current = label;
      } else {
        data.desiredSnapshot = snapshot;
        data.desired = label;
      }
      data.changed();
    } catch (e) {
      data.error = operationFailureSummary(
        e,
        locale: mounted ? strings(context) : null,
      );
    } finally {
      data.busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> compare() async {
    final data = widget.data, model = widget.model;
    if (data.busy) return;
    final revision = data.revision;
    setState(() {
      data.busy = true;
      data.error = '';
    });
    try {
      final profile = model.profiles.firstWhere(
        (p) => p.id == data.currentProfile,
      );
      final metadataOwner = model.connectionOwner(profile);
      if (metadataOwner.sessionId == null) {
        await model.commands!.invoke(
          'connection.connect',
          WorkbenchCommandContext(owner: metadataOwner, profileId: profile.id),
        );
      }
      if (metadataOwner.sessionId == null) return;
      final target = model.captureTarget(owner: metadataOwner);
      final result = await model.ownedRequest(
        target,
        () => target.backend.client.schemaTool(
          rpc.SchemaToolRequest(
            context: target.backend.context(),
            sessionId: target.sessionId,
            action: rpc.SchemaToolAction.COMPARE_SCHEMA,
            schema: data.schema,
            sourceSnapshot: data.currentSnapshot,
            targetSnapshot: data.desiredSnapshot,
          ),
        ),
      );
      model.requireTarget(target);
      if (!model.operationOwners.contains(widget.owner) ||
          revision != data.revision) {
        throw StateError('Comparison inputs changed; compare again');
      }
      final evidence =
          result.sql.fold<int>(0, (n, sql) => n + sql.length) +
          result.differences.fold<int>(
            0,
            (n, d) =>
                n +
                d.beforeDefinition.length +
                d.afterDefinition.length +
                d.name.length +
                64,
          ) +
          [
            ...result.risks,
            ...result.unsupported,
            ...result.dependencies,
          ].fold<int>(0, (n, s) => n + s.length);
      model.documentBudget.auxiliary(
        widget.owner,
        (data.currentSnapshot.length + data.desiredSnapshot.length + evidence) *
            2,
      );
      data.result = result;
      data.resultEngine = target.profile?.engine;
    } catch (e) {
      data.error = operationFailureSummary(
        e,
        locale: mounted ? strings(context) : null,
      );
    } finally {
      data.busy = false;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    widget.data.filter = filter.text;
    widget.data.selected = selected;
    filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data,
        ui = widget.controls,
        model = widget.model,
        l = strings(context),
        result = data.result;
    final applyProfile = model.profiles
        .where((p) => p.id == data.profileId)
        .firstOrNull;
    final engineMismatch =
        result != null &&
        applyProfile != null &&
        applyProfile.engine != data.resultEngine;
    final items = (result?.differences ?? <rpc.SchemaDifference>[]).where(
      (d) => '${d.kind} ${d.name} ${d.state}'.toLowerCase().contains(
        filter.text.toLowerCase(),
      ),
    );
    return WorkbenchFormList(
      controls: ui,
      padding: const EdgeInsets.all(12),
      children: [
        Text(
          '${l.currentSchema}: ${data.current}\n${l.desiredSchema}: ${data.desired}\n${l.applyTo}: ${model.profiles.where((p) => p.id == data.profileId).firstOrNull?.name ?? l.notConnected}',
        ),
        const SizedBox(height: 8),
        for (final current in [true, false]) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                current ? l.currentSchema : l.desiredSchema,
                style: ui
                    .textStyle(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (data.currentObject == null)
            ui.comboRow<String>(
              current ? l.currentSchema : l.desiredSchema,
              current ? data.currentProfile ?? '' : data.desiredProfile ?? '',
              {
                '': l.selectTarget,
                for (final p in model.profiles)
                  p.id:
                      '${p.name} · ${workbenchEnvironment(context, p.environment)}',
              },
              (id) {
                if (data.busy) return;
                setState(() {
                  if (current) {
                    data.currentProfile = id;
                  } else {
                    data.desiredProfile = id;
                  }
                  data.changed();
                });
              },
            ),
          Wrap(
            spacing: 8,
            children: [
              if (data.currentObject == null)
                ui.button(
                  '${l.chooseSnapshot} · ${current ? l.currentSchema : l.desiredSchema}',
                  data.busy ? null : () => input(current, false),
                ),
              ui.button(
                '${l.captureSchema} · ${current ? l.currentSchema : l.desiredSchema}',
                data.busy ? null : () => input(current, true),
              ),
            ],
          ),
        ],
        Text(l.applyTo),
        if (data.currentObject == null)
          ui.comboRow<String>(
            l.applyTo,
            data.profileId ?? '',
            {
              '': l.selectTarget,
              for (final p in model.profiles)
                p.id:
                    '${p.name} · ${workbenchEnvironment(context, p.environment)}',
            },
            (id) {
              if (!data.busy) setState(() => data.profileId = id);
            },
          ),
        if (engineMismatch) Text(l.migrationEngineMismatch),
        Text(l.sameSchemaRestriction),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ui.button(
            l.compareSchemas,
            data.busy ||
                    data.currentSnapshot.isEmpty ||
                    data.desiredSnapshot.isEmpty
                ? null
                : compare,
            primary: true,
          ),
        ),
        if (data.busy) Text(l.loading),
        if (data.error.isNotEmpty) ui.status(data.error, error: true),
        if (result != null) ...[
          const SizedBox(height: 8),
          Text(
            result.equivalent
                ? strings(context).schemasEquivalent
                : result.complete
                ? strings(context).migrationComplete
                : strings(context).migrationPartial,
          ),
          if (result.differencesLimited)
            Text(strings(context).differencesLimited),
          ui.filterField(filter, strings(context).filterChangedObjects),
          for (final difference in items)
            WorkbenchRecord(
              controls: ui,
              label:
                  '${switch (difference.state) {
                    'added' => l.differenceAdded,
                    'removed' => l.differenceRemoved,
                    'changed' => l.differenceChanged,
                    _ => difference.state,
                  }} · ${switch (difference.kind) {
                    'tables' => l.tables,
                    'views' => l.views,
                    'routines' => l.routines,
                    _ => difference.kind,
                  }} · ${difference.name}',
              selected: identical(selected, difference),
              onPressed: () => setState(() => selected = difference),
              child: Text(
                '${switch (difference.state) {
                  'added' => l.differenceAdded,
                  'removed' => l.differenceRemoved,
                  'changed' => l.differenceChanged,
                  _ => difference.state,
                }} · ${switch (difference.kind) {
                  'tables' => l.tables,
                  'views' => l.views,
                  'routines' => l.routines,
                  _ => difference.kind,
                }} · ${difference.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (selected case final difference?) ...[
            const SizedBox(height: 12),
            Text(
              l.currentSchema,
              style: ui
                  .textStyle(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            if (difference.beforeDefinition.isEmpty)
              SelectableText(strings(context).absent)
            else
              WorkbenchCodeEvidence(
                controls: ui,
                text: difference.beforeDefinition,
              ),
            const SizedBox(height: 8),
            Text(
              l.desiredSchema,
              style: ui
                  .textStyle(context)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            if (difference.afterDefinition.isEmpty)
              SelectableText(strings(context).absent)
            else
              WorkbenchCodeEvidence(
                controls: ui,
                text: difference.afterDefinition,
              ),
            if (difference.presentationLimited)
              Text(strings(context).definitionPreviewLimited),
          ],
          const SizedBox(height: 16),
          Text(strings(context).migrationBatchNote),
          for (final dependency in result.dependencies) Text(dependency),
          for (final risk in result.risks) Text(risk),
          for (final unsupported in result.unsupported)
            Text('${l.unsupportedLabel}: $unsupported'),
          for (final sql in result.sql)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: WorkbenchCodeEvidence(controls: ui, text: sql),
            ),
          Wrap(
            spacing: 8,
            children: [
              ui.button(
                l.openSql,
                engineMismatch
                    ? null
                    : () {
                        model.newDocument(
                          text:
                              '-- Review the current target and unsupported differences before execution.\n${result.sql.join('\n')}',
                        );
                        model.document.profileId = data.profileId;
                        model.document.connectionCatalog =
                            data.currentObject?.catalog ?? '';
                        model.document.connectionSchema =
                            data.currentObject?.schema ?? data.schema;
                        model.activeOwner.evidenceProfile = applyProfile
                            ?.deepCopy();
                      },
              ),
              ui.button(
                l.saveSql,
                () => model.command(
                  () => saveMigrationSql(context, ui, result.sql.join('\n')),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class ChangesDocumentView extends StatefulWidget {
  const ChangesDocumentView({
    super.key,
    required this.model,
    required this.owner,
    required this.controls,
    required this.review,
  });
  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final DesktopControls controls;
  final ChangesReviewData review;
  @override
  State<ChangesDocumentView> createState() => _ChangesDocumentViewState();
}

class _ChangesDocumentViewState extends State<ChangesDocumentView> {
  String kind(rpc.ChangeKind kind) => switch (kind) {
    rpc.ChangeKind.INSERT => strings(context).stageInsert,
    rpc.ChangeKind.DELETE => strings(context).stageDelete,
    _ => strings(context).stageUpdate,
  };
  @override
  Widget build(BuildContext context) {
    final model = widget.model, owner = widget.owner, review = widget.review;
    final ui = widget.controls,
        batch = review.batch,
        plan = review.plan,
        l = strings(context);
    bool current = true;
    try {
      model.requireTarget(review.target);
    } catch (_) {
      current = false;
    }
    final expired =
        plan.expiresUnixMs.toInt() != 0 &&
        plan.expiresUnixMs.toInt() < DateTime.now().millisecondsSinceEpoch;
    final index = plan.changes.isEmpty
        ? 0
        : owner.view.changeIndex.clamp(0, plan.changes.length - 1);
    final selected = plan.changes.isEmpty ? null : plan.changes[index];
    final columns = selected == null
        ? <String>[]
        : {...selected.original.keys, ...selected.values.keys}.toList();
    final stale = !current || expired || batch.revision != review.revision;
    final live = model.sessions[review.target.sessionId];
    final canApply =
        live?.autoCommit == true &&
        live?.transaction == rpc.TransactionState.IDLE;
    String shownValue(rpc.Value value) =>
        value.hasText() && value.text.isEmpty ? '""' : valueText(value);
    String proposed(String name) {
      if (selected!.kind == rpc.ChangeKind.DELETE) return l.stageDelete;
      final value = selected.values[name];
      if (value != null) {
        return value.hasDefaultValue()
            ? l.assignmentDefault
            : assignmentValue(value) == null
            ? l.assignmentUnset
            : shownValue(assignmentValue(value)!);
      }
      final original = selected.original[name];
      return original == null
          ? l.defaultOmit
          : '${l.unchanged} · ${shownValue(original)}';
    }

    Widget evidenceValue(String label, String value) => MergeSemantics(
      child: Semantics(
        label: label,
        child: SelectableText(value, style: ui.appearance(context).technical),
      ),
    );

    Future<void> details() async => ui.dialog<void>(
      context,
      l.changes,
      SelectableText(
        [
          workbenchTargetDescription(context, review.target),
          '${batch.schema}/${batch.table} · ${batch.resultId}',
          l.applyCommitExplanation,
          ...plan.risks,
        ].join('\n\n'),
      ),
      [ui.button(l.close, () => Navigator.of(context).pop())],
    );
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${plan.target.name} · ${workbenchEnvironment(context, plan.target.environment)} · ${plan.target.host}:${plan.target.port}/${plan.target.database}',
            style: ui.textStyle(context).copyWith(fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(workbenchSessionState(context, live)),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              ui.button(
                l.applyAndCommit,
                stale ||
                        !canApply ||
                        plan.changes.isEmpty ||
                        batch.applying ||
                        batch.outcomeUnknown ||
                        batch.appliedSnapshot
                    ? null
                    : () async {
                        try {
                          await review.apply();
                        } catch (e) {
                          model.updateStatus(
                            operationFailureSummary(e, locale: l),
                          );
                        }
                      },
                primary: true,
              ),
              ui.button(
                l.cancel,
                batch.applying || model.commands == null
                    ? null
                    : () => model.commands!.invoke(
                        'file.close',
                        WorkbenchCommandContext(
                          owner: owner,
                          profileId: owner.profileId,
                          sessionId: owner.sessionId,
                        ),
                      ),
              ),
              ui.modeSwitcher(
                owner.view.changeSql,
                {false: l.changes, true: l.generatedSql},
                (value) => setState(() => owner.view.changeSql = value),
                label: l.changes,
              ),
              ui.iconMenu(l.more, [
                DesktopMenuAction(l.reviewDetails, details),
                DesktopMenuAction(
                  l.revertChange,
                  () async {
                    batch.changes.removeAt(index);
                    batch.revision++;
                    await model.persistStagedEdits(batch: batch);
                    model.updateStatus(l.changeReverted);
                  },
                  disabledReason:
                      selected == null ||
                          stale ||
                          batch.applying ||
                          batch.outcomeUnknown ||
                          batch.appliedSnapshot
                      ? l.expiredChangeReview
                      : null,
                ),
              ]),
            ],
          ),
          if (batch.outcomeUnknown) Text(l.outcomeUnknown),
          if (batch.appliedSnapshot) Text(l.completed),
          if (stale && !batch.appliedSnapshot)
            Text(
              l.expiredChangeReview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final operations = ListView.builder(
                  itemCount: plan.changes.length,
                  itemBuilder: (context, i) {
                    final c = plan.changes[i];
                    final label =
                        '${kind(c.kind)} · ${c.kind == rpc.ChangeKind.INSERT ? l.newRow : l.sourceRow((c.sourceRow + 1).toString())}';
                    return WorkbenchRecord(
                      controls: ui,
                      label: label,
                      selected: i == index,
                      onPressed: () =>
                          setState(() => owner.view.changeIndex = i),
                      child: Text(label),
                    );
                  },
                );
                final evidence = owner.view.changeSql
                    ? ListView.builder(
                        itemCount: plan.sql.length,
                        itemBuilder: (context, i) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: evidenceValue(
                            '${l.generatedSql} · ${i + 1}',
                            plan.sql[i],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: columns.length + 4,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            return Text(
                              '${batch.schema}/${batch.table} · ${l.changeCounts(plan.changes.where((c) => c.kind == rpc.ChangeKind.INSERT).length, plan.changes.where((c) => c.kind == rpc.ChangeKind.UPDATE).length, plan.changes.where((c) => c.kind == rpc.ChangeKind.DELETE).length)}',
                            );
                          }
                          if (i == 1) return Text(l.applyRequiresAutoCommit);
                          if (i == 2) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SelectableText(plan.risks.join('\n')),
                                if (batch.outcomeUnknown) Text(l.unknownBatch),
                                if (batch.appliedSnapshot)
                                  Text(l.preChangeSnapshot),
                              ],
                            );
                          }
                          if (i == 3) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Semantics(
                                    container: true,
                                    child: Text(l.columns),
                                  ),
                                ),
                                Expanded(
                                  child: Semantics(
                                    container: true,
                                    child: Text(l.original),
                                  ),
                                ),
                                Expanded(
                                  child: Semantics(
                                    container: true,
                                    child: Text(l.proposed),
                                  ),
                                ),
                              ],
                            );
                          }
                          final name = columns[i - 4];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: SelectableText(name)),
                                Expanded(
                                  child: evidenceValue(
                                    '${l.original} · $name',
                                    selected!.original[name] == null
                                        ? l.defaultOmit
                                        : shownValue(selected.original[name]!),
                                  ),
                                ),
                                Expanded(
                                  child: evidenceValue(
                                    '${l.proposed} · $name',
                                    proposed(name),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                return bounds.maxWidth < 620
                    ? Column(
                        children: [
                          SizedBox(
                            height: (bounds.maxHeight * .25).clamp(0, 80),
                            child: operations,
                          ),
                          const SizedBox(height: 8),
                          Expanded(child: evidence),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 180, child: operations),
                          const SizedBox(width: 12),
                          Expanded(child: evidence),
                        ],
                      );
              },
            ),
          ),
        ],
      ),
    );
  }
}
