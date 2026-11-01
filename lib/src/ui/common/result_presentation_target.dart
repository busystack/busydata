import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/workbench_model.dart';

/// Captures a retained presentation operation independently of polling summaries.
/// Equivalent summaries keep their owner; disposal, replaced native columns,
/// backend lifetimes and local-view definitions invalidate the operation.
class CapturedResultPresentation {
  CapturedResultPresentation(
    this.model,
    this.owner,
    rpc.StatementResult result,
    this.view,
  ) : resultId = result.resultId,
      sourceId = model.sourceResultId(result.resultId),
      backend = model.backend,
      ownerVersion = owner.version,
      sessionId = owner.sessionId,
      profileId = owner.profileId,
      localView = model.resultViews[result.resultId],
      viewDefinition = view.retainedView,
      columns = [for (final column in result.columns) column.deepCopy()] {
    retainedIdentity = _retainedIdentity();
    jobIdentity = _jobIdentity();
  }

  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final ResultViewState view;
  final String resultId, sourceId;
  final String? sessionId, profileId;
  final int ownerVersion;
  final Object? backend, localView, viewDefinition;
  final List<rpc.Column> columns;
  late final Object? retainedIdentity, jobIdentity;

  Object? _retainedIdentity() {
    final retained = model.retainedResults[sourceId];
    return retained == null
        ? null
        : (
            retained.jobId,
            retained.executionId,
            retained.documentId,
            retained.sessionId,
            retained.createdUnixMs,
            retained.target.deepCopy(),
            retained.sourceSchema,
          );
  }

  Object? _jobIdentity() {
    final jobs = model.jobs.values.where(
      (job) => job.results.any((result) => result.resultId == sourceId),
    );
    if (jobs.length != 1) return null;
    final job = jobs.single;
    return (
      job.jobId,
      job.executionId,
      job.sessionId,
      job.target.deepCopy(),
      job.sourceSchema,
      model.jobDocuments[job.jobId],
    );
  }

  bool _sameRetainedOwner() {
    if (retainedIdentity != null) {
      return _retainedIdentity() == retainedIdentity;
    }
    if (_jobIdentity() != jobIdentity) return false;
    final retained = model.retainedResults[sourceId];
    return retained == null ||
        (
              retained.jobId,
              retained.executionId,
              retained.sessionId,
              retained.target.deepCopy(),
              retained.sourceSchema,
              retained.documentId,
            ) ==
            jobIdentity;
  }

  bool matches({
    required WorkbenchModel model,
    required WorkbenchDocument owner,
    required rpc.StatementResult result,
    required ResultViewState view,
  }) {
    if (!identical(model, this.model) ||
        !identical(model.backend, backend) ||
        !identical(owner, this.owner) ||
        result.resultId != resultId ||
        model.sourceResultId(result.resultId) != sourceId ||
        !identical(view, this.view) ||
        !identical(owner.view.results[sourceId], view) ||
        !identical(model.resultViews[resultId], localView) ||
        !identical(view.retainedView, viewDefinition) ||
        !model.operationOwners.contains(owner) ||
        owner.version != ownerVersion ||
        owner.sessionId != sessionId ||
        owner.profileId != profileId ||
        model.disposedResults.contains(resultId) ||
        model.disposedResults.contains(sourceId) ||
        model.retainedResults[sourceId]?.disposalPending == true ||
        !_sameRetainedOwner() ||
        result.columns.length != columns.length) {
      return false;
    }
    for (var index = 0; index < columns.length; index++) {
      if (result.columns[index] != columns[index]) return false;
    }
    return true;
  }
}
