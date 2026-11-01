import 'package:grpc/grpc.dart' show CallOptions, ResponseFuture;

import 'generated/busydata.pbgrpc.dart';

/// Import admission hashes the selected, bounded source before starting a job.
/// This transport budget is separate from the job's execution deadline.
const importAdmissionTimeout = Duration(minutes: 5);

CallOptions? _options(ToolRequest request) => switch (request.kind) {
  ToolKind.IMPORT_CSV ||
  ToolKind.IMPORT_JSON => CallOptions(timeout: importAdmissionTimeout),
  _ => null,
};

/// Returns the transport future itself, preserving explicit cancellation.
extension ToolAdmissionRequests on WorkbenchClient {
  ResponseFuture<ImportPreview> previewImportAdmission(ToolRequest request) =>
      previewImport(request, options: _options(request));

  ResponseFuture<Approval> reviewToolAdmission(ToolRequest request) =>
      reviewTool(request, options: _options(request));

  ResponseFuture<JobInfo> toolAdmission(ToolRequest request) =>
      tool(request, options: _options(request));
}
