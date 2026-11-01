import 'dart:async';
import 'dart:convert';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show CallOptions, ResponseFuture;
import '../../backend/generated/busydata.pb.dart';
import '../../backend/workbench_failure.dart';
import 'metadata_page.dart';
import 'workbench_model.dart';

Never _selectionFailure(WorkbenchFailureReason reason) =>
    throw LocalWorkbenchFailure(reason);

void _requireBrowseOwner(WorkbenchModel model, CapturedWorkbenchTarget target) {
  if (!identical(model.backend, target.backend)) {
    _selectionFailure(WorkbenchFailureReason.backendRestarted);
  }
  try {
    model.requireTarget(target, text: true, profile: true);
  } on StateError {
    _selectionFailure(WorkbenchFailureReason.stale);
  }
  final session = model.sessions[target.sessionId];
  if (session == null ||
      target.profile == null ||
      !model.profiles.any((profile) => profile.id == target.profileId) ||
      session.profile.id != target.profileId ||
      !WorkbenchModel.sameConnectionTarget(session.profile, target.profile!)) {
    _selectionFailure(WorkbenchFailureReason.invalidOwner);
  }
  if (session.transaction == TransactionState.UNKNOWN_TRANSACTION) {
    _selectionFailure(WorkbenchFailureReason.transactionUnknown);
  }
  if (session.transaction == TransactionState.DISCONNECTED ||
      model.jobs.values.any(
        (job) =>
            job.sessionId == target.sessionId &&
            !WorkbenchModel.terminalJob(job.state),
      )) {
    _selectionFailure(WorkbenchFailureReason.unavailable);
  }
}

DatabaseObjectIdentity _relationHint(String profile, SchemaObject object) =>
    DatabaseObjectIdentity(
      profileId: profile,
      catalog: object.catalog,
      schema: object.schema,
      kind: object.kind,
      subtype: object.subtype,
      name: object.name,
      identifier: object.identifier,
    );

void _requireRelationProjection(SchemaObject object) {
  if (![ObjectKind.TABLE, ObjectKind.VIEW].contains(object.kind) ||
      object.name.isEmpty ||
      object.stableIdentity.isEmpty ||
      utf8.encode(object.stableIdentity).length > 8192 ||
      object.metadataSnapshotRevision <= Int64.ZERO ||
      object.introspectionLevel < 1 ||
      object.metadataState != 'AVAILABLE' ||
      object.table.isNotEmpty ||
      object.writeToBuffer().length > 65536) {
    _selectionFailure(WorkbenchFailureReason.incompleteMetadata);
  }
}

/// Ephemeral Java-issued selection evidence from Explorer or SQL resolution.
/// It is never part of logical equality, preferences, drafts, or recovery.
class BrowseSelectionEvidence {
  BrowseSelectionEvidence({
    required this.source,
    required SchemaObject projection,
    required this.configurationRevision,
  }) : projection = projection.deepCopy()..freeze() {
    _requireRelationProjection(this.projection);
    if (source.profileId == null || source.sessionId == null) {
      _selectionFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (configurationRevision <= 0) {
      _selectionFailure(WorkbenchFailureReason.incompleteMetadata);
    }
  }
  final CapturedWorkbenchTarget source;
  final SchemaObject projection;
  final int configurationRevision;
  DatabaseObjectIdentity get object =>
      _relationHint(source.profileId!, projection);

  static BrowseSelectionEvidence? fromCommand(
    WorkbenchModel model,
    WorkbenchCommandContext command,
    DatabaseObjectIdentity logical,
  ) {
    final projected = command.metadataObject;
    if (projected == null) {
      return null; // Explicit name-only hint, not authority.
    }
    final backend = model.backend, id = command.sessionId;
    if (backend == null ||
        id == null ||
        command.metadataInstance != backend.instanceId ||
        command.profileId != logical.profileId) {
      _selectionFailure(WorkbenchFailureReason.invalidOwner);
    }
    final epoch = command.metadataSources[logical.profileId];
    final session = model.sessions[id];
    if (epoch == null ||
        session == null ||
        epoch.sessionId != id ||
        epoch.contextRevision != session.contextRevision.toInt() ||
        epoch.sessionRevision != session.sessionRevision.toInt()) {
      _selectionFailure(WorkbenchFailureReason.stale);
    }
    final result = BrowseSelectionEvidence(
      source: model.captureSessionTarget(id),
      projection: projected,
      configurationRevision: command.metadataConfigurationRevision ?? 0,
    );
    if (result.object != logical) {
      _selectionFailure(WorkbenchFailureReason.invalidOwner);
    }
    result.requireCurrent(model);
    return result;
  }

  void requireCurrent(WorkbenchModel model) {
    _requireBrowseOwner(model, source);
    final known = model.metadataRevisionForSession(source.sessionId!);
    if (known != null && known.configuration != configurationRevision) {
      _selectionFailure(WorkbenchFailureReason.invalidRevision);
    }
  }
}

class ResolvedWorkbenchObject {
  const ResolvedWorkbenchObject(this.object, this.evidence);
  final DatabaseObjectIdentity object;
  final BrowseSelectionEvidence? evidence;
}

/// Only this operation result can construct an ordinary reviewed browse target.
/// Retains one <=64KiB server projection and scalar revisions, no page cache.
class BrowseTargetSelection {
  BrowseTargetSelection._(
    this.owner,
    SchemaObject projection,
    this.configurationRevision,
    this.origin,
    this.current,
  ) : projection = projection.deepCopy()..freeze();
  final CapturedWorkbenchTarget owner;
  final SchemaObject projection;
  final int configurationRevision;
  final BrowseSelectionEvidence? origin;
  final bool Function()? current;
  DatabaseObjectIdentity get object =>
      _relationHint(owner.profileId!, projection);
  int get snapshotRevision => projection.metadataSnapshotRevision.toInt();

  void requireCurrent(WorkbenchModel model) {
    _requireBrowseOwner(model, owner);
    origin?.requireCurrent(model);
    if (current?.call() == false) {
      _selectionFailure(WorkbenchFailureReason.stale);
    }
    final known = model.metadataRevisionForSession(owner.sessionId!);
    if (known == null ||
        known.snapshot != snapshotRevision ||
        known.configuration != configurationRevision) {
      _selectionFailure(WorkbenchFailureReason.stale);
    }
  }

  BrowseRequest request(
    WorkbenchModel model, {
    required String executionId,
    required Int64 rowLimit,
    Iterable<RowCondition> conditions = const [],
    Iterable<RowOrder> order = const [],
  }) {
    requireCurrent(model);
    return BrowseRequest(
      context: owner.backend.context(),
      sessionId: owner.sessionId,
      executionId: executionId,
      documentId: owner.ownerId,
      catalog: projection.catalog,
      schema: projection.schema,
      table: projection.name,
      rowLimit: rowLimit,
      metadataObjectIdentity: projection.stableIdentity,
      metadataSnapshotRevision: projection.metadataSnapshotRevision,
      conditions: conditions.map((value) => value.deepCopy()),
      order: order.map((value) => value.deepCopy()),
    );
  }
}

/// Relation L2 -> one bounded COLUMN L2 acknowledgement -> cached relation L2.
/// No SQL, approval, retry loop, identifier normalization, or complete catalog.
class BrowseSelectionController {
  const BrowseSelectionController(this.model);
  final WorkbenchModel model;
  static const deadline = Duration(seconds: 30);

  /// Only a newly created unbound destination can adopt an explicitly
  /// selected live physical session. Existing/restored owners never switch.
  void attachSelectedSession(
    WorkbenchDocument destination,
    BrowseSelectionEvidence evidence, {
    required bool newlyCreated,
  }) {
    evidence.requireCurrent(model);
    if (destination.profileId != evidence.source.profileId ||
        destination.sessionId != null &&
            destination.sessionId != evidence.source.sessionId) {
      _selectionFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (destination.evidenceProfile != null &&
        !WorkbenchModel.sameConnectionTarget(
          destination.evidenceProfile!,
          evidence.source.profile!,
        )) {
      _selectionFailure(WorkbenchFailureReason.invalidOwner);
    }
    if (destination.sessionId == null) {
      if (!newlyCreated) _selectionFailure(WorkbenchFailureReason.invalidOwner);
      destination.evidenceProfile ??= evidence.source.profile!.deepCopy();
      destination.sessionId = evidence.source.sessionId;
    }
  }

  Future<BrowseTargetSelection> prepare(
    CapturedWorkbenchTarget owner,
    DatabaseObjectIdentity hint, {
    BrowseSelectionEvidence? evidence,
    bool Function()? current,
  }) async {
    _requireBrowseOwner(model, owner);
    // Reuse existing operation ownership/backpressure, with no second cache
    // or coordination registry. Every phase settles its owned RPC first.
    if ((model.pendingCommands[owner.ownerId] ?? 0) != 0) {
      _selectionFailure(WorkbenchFailureReason.unavailable);
    }
    if (hint.profileId != owner.profileId ||
        ![ObjectKind.TABLE, ObjectKind.VIEW].contains(hint.kind) ||
        hint.parent.isNotEmpty ||
        hint.name.isEmpty ||
        [
          hint.catalog,
          hint.schema,
          hint.name,
        ].any((part) => part.length > 256 || part.contains('\u0000'))) {
      _selectionFailure(WorkbenchFailureReason.invalidOwner);
    }
    evidence?.requireCurrent(model);
    if (evidence != null &&
        (evidence.object != hint ||
            !identical(evidence.source.backend, owner.backend) ||
            evidence.source.sessionId != owner.sessionId ||
            evidence.source.contextRevision != owner.contextRevision ||
            evidence.source.sessionRevision != owner.sessionRevision)) {
      _selectionFailure(WorkbenchFailureReason.invalidOwner);
    }
    final session = model.sessions[owner.sessionId]!.deepCopy()..freeze();
    var expectedKnown = model.metadataRevisionForSession(session.sessionId);
    int? configuration =
        evidence?.configurationRevision ?? expectedKnown?.configuration;
    final stopped = Completer<SchemaObjects>();
    final clock = Stopwatch()..start();
    ResponseFuture<SchemaObjects>? pending;
    var pendingSettled = true;
    final timer = Timer(deadline, () {
      if (!stopped.isCompleted) {
        stopped.completeError(
          const LocalWorkbenchFailure(WorkbenchFailureReason.timedOut),
        );
      }
      unawaited(pending?.cancel());
    });
    void requireCurrent() {
      _requireBrowseOwner(model, owner);
      evidence?.requireCurrent(model);
      if (current?.call() == false) {
        _selectionFailure(WorkbenchFailureReason.stale);
      }
      if (model.metadataRevisionForSession(session.sessionId) !=
          expectedKnown) {
        _selectionFailure(WorkbenchFailureReason.stale);
      }
    }

    void changed() {
      try {
        requireCurrent();
      } catch (failure, stack) {
        if (!stopped.isCompleted) stopped.completeError(failure, stack);
        unawaited(pending?.cancel());
      }
    }

    Future<SchemaObjects> page(ExploreRequest scope) async {
      requireCurrent();
      final remaining = deadline - clock.elapsed;
      if (remaining <= Duration.zero) {
        _selectionFailure(WorkbenchFailureReason.timedOut);
      }
      final request = bindMetadataRequest(
        scope,
        owner.backend.context(),
        session,
      );
      pending = owner.backend.client.explore(
        request,
        options: CallOptions(timeout: remaining),
      );
      pendingSettled = false;
      final reply = await model.ownedRequest(
        owner,
        () => Future.any<SchemaObjects>([pending!, stopped.future]),
      );
      pendingSettled = true;
      requireCurrent();
      try {
        validateMetadataPage(reply, request, session, owner.backend.instanceId);
      } on StateError {
        _selectionFailure(WorkbenchFailureReason.malformedRequest);
      }
      _requireAvailable(reply.metadataState);
      if (reply.metadataSnapshotRevision <= Int64.ZERO ||
          reply.metadataConfigurationRevision <= Int64.ZERO ||
          reply.introspectionLevel < request.introspectionLevel ||
          reply.introspectionLevel > 3 ||
          reply.countAvailability != MetadataCount.AUTHORITATIVE_TOTAL ||
          !reply.hasTotalCount() ||
          reply.complete && reply.continuation.isNotEmpty ||
          !reply.complete && reply.continuation.isEmpty ||
          reply.objects.any(
            (object) =>
                object.metadataSnapshotRevision !=
                    reply.metadataSnapshotRevision ||
                object.introspectionLevel < request.introspectionLevel ||
                object.metadataState != 'AVAILABLE' ||
                object.stableIdentity.isEmpty,
          )) {
        _selectionFailure(WorkbenchFailureReason.incompleteMetadata);
      }
      final actualConfiguration = reply.metadataConfigurationRevision.toInt();
      expectedKnown = (
        snapshot: reply.metadataSnapshotRevision.toInt(),
        configuration: actualConfiguration,
      );
      if (!model.acceptMetadataSnapshotRevision(
        session.sessionId,
        expectedKnown!.snapshot,
        actualConfiguration,
        sourceIdentity: reply.metadataSourceIdentity,
      )) {
        _selectionFailure(WorkbenchFailureReason.stale);
      }
      // The scalar source fact is authoritative even when this exact operation
      // must stop and obtain a fresh preparation under the changed policy.
      if (configuration != null && configuration != actualConfiguration) {
        _selectionFailure(WorkbenchFailureReason.invalidRevision);
      }
      configuration ??= actualConfiguration;
      requireCurrent();
      return reply;
    }

    model.addListener(changed);
    try {
      // Explore's subtype filter is routine-only. Relation descriptors keep
      // their native subtype and stable identity in the verified reply.
      final names = await page(
        ExploreRequest(
          kind: hint.kind,
          catalog: hint.catalog,
          schema: hint.schema,
          search: hint.name,
          exactName: true,
          identifier: hint.identifier,
          introspectionLevel: 2,
          limit: 2,
        ),
      );
      final first = _oneRelation(names);
      if (evidence != null &&
          (first.stableIdentity != evidence.projection.stableIdentity ||
              first.kind != evidence.projection.kind ||
              first.metadataSnapshotRevision <
                  evidence.projection.metadataSnapshotRevision)) {
        _selectionFailure(WorkbenchFailureReason.stale);
      }
      final columns = await page(
        ExploreRequest(
          kind: ObjectKind.COLUMN,
          catalog: first.catalog,
          schema: first.schema,
          table: first.name,
          introspectionLevel: 2,
          limit: 1,
        ),
      );
      if (columns.objects.length != 1 ||
          columns.totalCount < Int64.ONE ||
          columns.totalCount > Int64(2048) ||
          columns.objects.single.parentIdentity != first.stableIdentity) {
        _selectionFailure(WorkbenchFailureReason.incompleteMetadata);
      }
      // A continuation deliberately remains unconsumed. This acknowledges
      // central acquisition, not full enumeration of column projections.
      final finalNames = await page(
        ExploreRequest(
          kind: first.kind,
          catalog: first.catalog,
          schema: first.schema,
          search: first.name,
          exactName: true,
          identifier: first.identifier,
          introspectionLevel: 2,
          limit: 2,
        ),
      );
      final selected = _oneRelation(finalNames);
      if (finalNames.metadataSnapshotRevision !=
              columns.metadataSnapshotRevision ||
          selected.stableIdentity != first.stableIdentity ||
          selected.kind != first.kind ||
          selected.subtype != first.subtype ||
          selected.name != first.name ||
          selected.catalog != first.catalog ||
          selected.schema != first.schema ||
          selected.identifier != first.identifier) {
        _selectionFailure(WorkbenchFailureReason.stale);
      }
      final result = BrowseTargetSelection._(
        owner,
        selected,
        configuration!,
        evidence,
        current,
      );
      result.requireCurrent(model);
      return result;
    } finally {
      timer.cancel();
      model.removeListener(changed);
      if (!pendingSettled) await pending?.cancel();
      clock.stop();
    }
  }

  static SchemaObject _oneRelation(SchemaObjects names) {
    if (!names.complete ||
        names.continuation.isNotEmpty ||
        names.totalCount != Int64.ONE ||
        names.objects.length != 1) {
      _selectionFailure(WorkbenchFailureReason.incompleteMetadata);
    }
    final object = names.objects.single;
    _requireRelationProjection(object);
    return object;
  }

  static void _requireAvailable(String state) {
    if (state == 'AVAILABLE') return;
    _selectionFailure(switch (state) {
      'DENIED' => WorkbenchFailureReason.denied,
      'STALE' => WorkbenchFailureReason.stale,
      'CANCELLED' => WorkbenchFailureReason.cancelled,
      'TIMED_OUT' => WorkbenchFailureReason.timedOut,
      'UNSUPPORTED' => WorkbenchFailureReason.unsupported,
      'UNAVAILABLE' ||
      'FAILED' ||
      'INVISIBLE' => WorkbenchFailureReason.unavailable,
      _ => WorkbenchFailureReason.incompleteMetadata,
    });
  }
}
