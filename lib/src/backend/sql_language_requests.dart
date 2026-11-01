import 'package:grpc/grpc.dart' show CallOptions, ResponseFuture;
import 'generated/busydata.pbgrpc.dart';

/// Each service has its own transport admission and cancellation lifetime.
ResponseFuture<Analysis> requestSqlAnalysis(
  WorkbenchClient client,
  AnalysisRequest request, {
  CallOptions? options,
}) => switch (request.operation) {
  AnalysisOperation.COMPLETION => client.completeSql(request, options: options),
  AnalysisOperation.DIAGNOSTICS => client.diagnoseSql(
    request,
    options: options,
  ),
  AnalysisOperation.PARAMETER_INFORMATION => client.sqlParameterInformation(
    request,
    options: options,
  ),
  AnalysisOperation.FORMAT => client.formatSql(request, options: options),
  AnalysisOperation.SYMBOL_RESOLUTION => client.resolveSqlSymbol(
    request,
    options: options,
  ),
  AnalysisOperation.DDL_IMPACT => client.sqlDdlImpact(
    request,
    options: options,
  ),
  _ => throw ArgumentError('Unknown SQL language operation'),
};
