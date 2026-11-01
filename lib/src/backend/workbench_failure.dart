import 'package:grpc/grpc.dart';
import '../../l10n/generated/app_localizations.dart';

/// Allowlisted protocol reasons. RPC failures require the typed trailer and its
/// matching status; admitted jobs carry the same reason in their error code.
/// Human-readable messages and broad transport status codes are never parsed.
enum WorkbenchFailureReason {
  unsupported('unsupported', StatusCode.unimplemented),
  unavailable('unavailable', StatusCode.unavailable),
  denied('denied', StatusCode.permissionDenied),
  stale('stale', StatusCode.failedPrecondition),
  cancelled('cancelled', StatusCode.cancelled),
  timedOut('timed_out', StatusCode.deadlineExceeded),
  incompleteMetadata('incomplete_metadata', StatusCode.failedPrecondition),
  invalidOwner('invalid_owner', StatusCode.permissionDenied),
  invalidRevision('invalid_revision', StatusCode.failedPrecondition),
  malformedRequest('malformed_request', StatusCode.invalidArgument),
  resultDisposed('result_disposed', StatusCode.notFound),
  valueTruncated('value_truncated', StatusCode.failedPrecondition),
  rowNoLongerCurrent('row_no_longer_current', StatusCode.aborted),
  transactionUnknown('transaction_unknown', StatusCode.failedPrecondition),
  backendRestarted('backend_restarted', StatusCode.failedPrecondition),
  readOnlyPolicy('read_only_policy', StatusCode.failedPrecondition),
  sessionBusy('session_busy', StatusCode.failedPrecondition),
  editIdentityRequired('edit_identity_required', StatusCode.failedPrecondition),
  editColumnsReadOnly('edit_columns_read_only', StatusCode.failedPrecondition),
  editResultNotReady('edit_result_not_ready', StatusCode.failedPrecondition),
  editProjectionUnsupported(
    'edit_projection_unsupported',
    StatusCode.failedPrecondition,
  );

  const WorkbenchFailureReason(this.wire, this.statusCode);
  final String wire;
  final int statusCode;

  String localized(AppLocalizations l) => switch (this) {
    WorkbenchFailureReason.unsupported => l.unsupportedLabel,
    WorkbenchFailureReason.unavailable => l.unavailable,
    WorkbenchFailureReason.denied ||
    WorkbenchFailureReason.invalidOwner => l.permissionDenied,
    WorkbenchFailureReason.stale => l.staleRefresh,
    WorkbenchFailureReason.cancelled => l.cancelled,
    WorkbenchFailureReason.timedOut => l.connectionFailureTimeout,
    WorkbenchFailureReason.incompleteMetadata => l.columnMetadataUnavailable,
    WorkbenchFailureReason.invalidRevision => l.metadataContextChanged,
    WorkbenchFailureReason.malformedRequest => l.connectionFailureSettings,
    WorkbenchFailureReason.resultDisposed ||
    WorkbenchFailureReason.backendRestarted => l.retainedUnavailable,
    WorkbenchFailureReason.valueTruncated => l.valueTruncated,
    WorkbenchFailureReason.rowNoLongerCurrent => l.editTargetChanged,
    WorkbenchFailureReason.transactionUnknown => l.outcomeUnknownNote,
    WorkbenchFailureReason.readOnlyPolicy => l.readonlyChanges,
    WorkbenchFailureReason.sessionBusy => l.editSessionBusy,
    WorkbenchFailureReason.editIdentityRequired => l.editIdentityRequired,
    WorkbenchFailureReason.editColumnsReadOnly => l.editColumnsReadOnly,
    WorkbenchFailureReason.editResultNotReady => l.editResultNotReady,
    WorkbenchFailureReason.editProjectionUnsupported =>
      l.editProjectionUnsupported,
  };

  static WorkbenchFailureReason? fromWire(String wire) {
    for (final reason in values) {
      if (reason.wire == wire) return reason;
    }
    return null;
  }

  static WorkbenchFailureReason? fromError(Object error) {
    if (error is! GrpcError) return null;
    final reason = fromWire(error.trailers?['busydata-workbench-reason'] ?? '');
    return reason?.statusCode == error.code ? reason : null;
  }
}

/// Local protocol-shape/ownership rejection uses the same allowlisted reason
/// and localization without fabricating a remote gRPC trailer.
class LocalWorkbenchFailure implements Exception {
  const LocalWorkbenchFailure(this.reason);
  final WorkbenchFailureReason reason;
  @override
  String toString() => reason.wire;
}
