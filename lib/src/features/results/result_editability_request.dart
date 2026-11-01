import 'dart:async';
import 'package:flutter/foundation.dart' show listEquals;
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../workspace/workbench_model.dart';

/// One pending read-only assessment, never reusable after completion. Only
/// bounded projection metadata and captured ownership are copied; no rows or
/// database semantics are cached here.
class ResultEditabilityRequest {
  ResultEditabilityRequest({
    required this.model,
    required this.owner,
    required this.target,
    required this.resultId,
    required this.sourceId,
    required List<rpc.Column> columns,
    required this.metadata,
    required this.revision,
  }) : columns = List.unmodifiable(columns.map((column) => column.deepCopy()));

  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final CapturedWorkbenchTarget target;
  final String resultId, sourceId;
  final List<rpc.Column> columns;
  rpc.Column get column => columns.first;
  final MetadataRevisionStamp? metadata;
  final int revision;
  final completion = Completer<void>();

  bool matches({
    required WorkbenchModel model,
    required WorkbenchDocument owner,
    required CapturedWorkbenchTarget target,
    required String resultId,
    required String sourceId,
    required List<rpc.Column> columns,
    required MetadataRevisionStamp? metadata,
  }) =>
      identical(this.model, model) &&
      identical(this.owner, owner) &&
      identical(this.target.backend, target.backend) &&
      this.target.ownerId == target.ownerId &&
      // SQL draft text is independent of this immutable retained result.
      // Physical execution/context changes remain exact ownership boundaries.
      this.target.profileId == target.profileId &&
      this.target.profile == target.profile &&
      this.target.session?.profile == target.session?.profile &&
      this.target.sessionId == target.sessionId &&
      this.target.sessionRevision == target.sessionRevision &&
      this.target.contextRevision == target.contextRevision &&
      this.target.session?.metadataSourceIdentity ==
          target.session?.metadataSourceIdentity &&
      this.target.session?.transaction == target.session?.transaction &&
      this.resultId == resultId &&
      this.sourceId == sourceId &&
      listEquals(this.columns, columns) &&
      (this.metadata == null
          ? metadata == null
          : metadata != null && this.metadata!.sameValue(metadata));
}
