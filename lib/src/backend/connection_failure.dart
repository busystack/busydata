import 'package:grpc/grpc.dart';
import 'workbench_failure.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_en.dart';

enum ConnectionFailureReason {
  authentication,
  tls,
  tlsMaterial,
  sshKey,
  endpoint,
  cancelled,
  settings,
  access,
  unavailable,
  timeout,
  busy,
  unknown,
  metadataStale,
  unsupported,
}

/// Only protocol codes and an allowlisted connection reason cross into feedback.
/// Arbitrary JDBC/server and exception strings never become diagnostics.
class ConnectionFailure {
  const ConnectionFailure(this.reason, this.details);
  final ConnectionFailureReason reason;
  final String details;
  String get summary => localizedSummary(AppLocalizationsEn());
  String localizedSummary(AppLocalizations l) => switch (reason) {
    ConnectionFailureReason.authentication => l.connectionFailureAuthentication,
    ConnectionFailureReason.tls => l.connectionFailureTls,
    ConnectionFailureReason.tlsMaterial => l.connectionFailureTlsMaterial,
    ConnectionFailureReason.sshKey => l.connectionFailureSshKey,
    ConnectionFailureReason.endpoint => l.connectionFailureEndpoint,
    ConnectionFailureReason.cancelled => l.connectionFailureCancelled,
    ConnectionFailureReason.settings => l.connectionFailureSettings,
    ConnectionFailureReason.access => l.connectionFailureAccess,
    ConnectionFailureReason.unavailable => l.connectionFailureUnavailable,
    ConnectionFailureReason.timeout => l.connectionFailureTimeout,
    ConnectionFailureReason.busy => l.backendBusy,
    ConnectionFailureReason.unknown => l.connectionFailureUnknown,
    ConnectionFailureReason.metadataStale => l.staleRefresh,
    ConnectionFailureReason.unsupported => l.unsupportedLabel,
  };
  factory ConnectionFailure.from(Object error) {
    if (error is ConnectionAttemptFailure) return error.failure;
    if (error is GrpcError) {
      if (error.trailers?['busydata-metadata-reason'] ==
          'restart-enumeration') {
        return const ConnectionFailure(
          ConnectionFailureReason.metadataStale,
          '',
        );
      }
      final reason = error.trailers?['busydata-connection-reason'];
      final typed = _admissionRejected(error)
          ? ConnectionFailureReason.busy
          : switch (reason) {
              'authentication' => ConnectionFailureReason.authentication,
              'tls-verification' => ConnectionFailureReason.tls,
              'tls-material' => ConnectionFailureReason.tlsMaterial,
              'ssh-host-key' => ConnectionFailureReason.sshKey,
              'ssh-authentication' => ConnectionFailureReason.access,
              'endpoint' => ConnectionFailureReason.endpoint,
              _ => switch (error.code) {
                StatusCode.cancelled => ConnectionFailureReason.cancelled,
                StatusCode.invalidArgument => ConnectionFailureReason.settings,
                StatusCode.permissionDenied => ConnectionFailureReason.access,
                StatusCode.unavailable => ConnectionFailureReason.unavailable,
                StatusCode.deadlineExceeded => ConnectionFailureReason.timeout,
                StatusCode.unimplemented => ConnectionFailureReason.unsupported,
                _ => ConnectionFailureReason.unknown,
              },
            };
      final safeReason =
          const {
            'authentication',
            'tls-verification',
            'ssh-host-key',
            'ssh-authentication',
            'endpoint',
          }.contains(reason)
          ? '\nReason: $reason'
          : '';
      final material = error.trailers?['busydata-tls-material'];
      final safeMaterial =
          const {
            'JAVA_ROOTS_UNAVAILABLE',
            'SYSTEM_ROOTS_UNAVAILABLE',
            'CLIENT_KEY_PASSWORD_OR_FORMAT',
            'CLIENT_KEY_WORK_LIMIT',
            'CLIENT_IDENTITY_MISMATCH',
          }.contains(material)
          ? '\nTLS material: $material'
          : '';
      return ConnectionFailure(
        typed,
        'RPC status: ${error.code}$safeReason$safeMaterial',
      );
    }
    return const ConnectionFailure(
      ConnectionFailureReason.unknown,
      'No additional safe diagnostic code was returned.',
    );
  }
}

bool _admissionRejected(GrpcError error) =>
    error.code == StatusCode.resourceExhausted &&
    error.trailers?['busydata-rpc-rejection'] == 'concurrency';

/// Remote messages are not user-facing diagnostics. Only the status code and
/// the backend's explicit admission reason are safe to classify here.
String operationFailureSummary(Object error, {AppLocalizations? locale}) {
  final l = locale ?? AppLocalizationsEn();
  if (error is LocalWorkbenchFailure) return error.reason.localized(l);
  if (error is ConnectionAttemptFailure) {
    return '${error.target}: ${error.failure.localizedSummary(l)}';
  }
  if (error is GrpcError) {
    final structured = WorkbenchFailureReason.fromError(error);
    if (structured != null) {
      return structured.localized(l);
    }
    if (_admissionRejected(error)) return l.backendBusy;
    if (error.code == StatusCode.cancelled) return l.cancelled;
    return l.rpcRequestUnconfirmed('${error.code}');
  }
  if (error is StateError) {
    return switch (error.message) {
      'Metadata inspection was superseded' ||
      'Metadata reply belongs to another object or inspection context' =>
        l.metadataContextChanged,
      'Metadata enumeration did not advance' ||
      'Metadata continuation did not advance; refresh this scope' =>
        l.staleRefresh,
      'Metadata is incomplete or unavailable; narrow the selected object scope' ||
      'Metadata resource budget reached; narrow the selected object scope' ||
      'Metadata request budget reached; narrow the selected object scope' =>
        l.metadataLimitScope,
      'Metadata object identity is ambiguous' => l.objectNotFound,
      'Target column metadata is incomplete; reload the import workflow' ||
      'Complete generated-column metadata is required before staging edits' =>
        l.completeColumnMetadataRequired,
      'Local Explorer objects exceed their storage budget' ||
      'Namespace selection scope budget exhausted' => l.limitReached,
      'Source or destination folder is unavailable' ||
      'Unknown folder order' ||
      'Choose an existing saved source' ||
      'Namespace source is no longer available' ||
      'The saved source for this object is unavailable' => l.selectTarget,
      'Move contained sources and folders before removing this folder' =>
        l.folderMustBeEmpty,
      'The local definition needs an explicit source binding' =>
        l.unboundVirtualView,
      _ => error.message,
    };
  }
  return l.operationUnconfirmed;
}

class ConnectionAttemptFailure implements Exception {
  ConnectionAttemptFailure(this.target, Object error)
    : failure = ConnectionFailure.from(error);
  final String target;
  final ConnectionFailure failure;
  @override
  String toString() => '$target: ${failure.summary}';
}
