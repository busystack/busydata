// This is a generated file - do not edit.
//
// Generated from busydata.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'busydata.pb.dart' as $0;

export 'busydata.pb.dart';

@$pb.GrpcServiceName('busydata.v1.Workbench')
class WorkbenchClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  WorkbenchClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.BackendInfo> ping(
    $0.Context request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$ping, request, options: options);
  }

  $grpc.ResponseFuture<$0.ProfileList> profiles(
    $0.ProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$profiles, request, options: options);
  }

  $grpc.ResponseFuture<$0.ConnectionInfo> testConnection(
    $0.OpenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$testConnection, request, options: options);
  }

  $grpc.ResponseFuture<$0.SshTestReply> testSshConnection(
    $0.SshTestRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$testSshConnection, request, options: options);
  }

  $grpc.ResponseFuture<$0.ConnectionDescription> describeConnection(
    $0.ProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$describeConnection, request, options: options);
  }

  $grpc.ResponseFuture<$0.SshTrustReply> reviewSshHost(
    $0.SshTrustRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reviewSshHost, request, options: options);
  }

  $grpc.ResponseFuture<$0.SshTrustReply> acceptSshHost(
    $0.SshTrustRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$acceptSshHost, request, options: options);
  }

  $grpc.ResponseFuture<$0.SessionInfo> openSession(
    $0.OpenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$openSession, request, options: options);
  }

  $grpc.ResponseFuture<$0.SessionInfo> session(
    $0.SessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$session, request, options: options);
  }

  $grpc.ResponseFuture<$0.Approval> reviewSession(
    $0.SessionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reviewSession, request, options: options);
  }

  $grpc.ResponseFuture<$0.Approval> review(
    $0.ExecuteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$review, request, options: options);
  }

  $grpc.ResponseFuture<$0.JobInfo> execute(
    $0.ExecuteRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$execute, request, options: options);
  }

  $grpc.ResponseFuture<$0.Approval> reviewBrowse(
    $0.BrowseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reviewBrowse, request, options: options);
  }

  $grpc.ResponseFuture<$0.JobInfo> browse(
    $0.BrowseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$browse, request, options: options);
  }

  $grpc.ResponseFuture<$0.JobList> jobs(
    $0.JobRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$jobs, request, options: options);
  }

  $grpc.ResponseFuture<$0.RetainedList> retainedResults(
    $0.RetainedRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$retainedResults, request, options: options);
  }

  $grpc.ResponseFuture<$0.JobInfo> cancel(
    $0.JobRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cancel, request, options: options);
  }

  $grpc.ResponseFuture<$0.Page> resultPage(
    $0.PageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resultPage, request, options: options);
  }

  $grpc.ResponseFuture<$0.ValueChunk> resultValue(
    $0.ValueRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resultValue, request, options: options);
  }

  $grpc.ResponseFuture<$0.CopySqlReply> copySql(
    $0.CopySqlRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$copySql, request, options: options);
  }

  $grpc.ResponseFuture<$0.ResultAggregateReply> resultAggregate(
    $0.ResultAggregateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resultAggregate, request, options: options);
  }

  $grpc.ResponseFuture<$0.RelatedRowsReply> relatedRows(
    $0.RelatedRowsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$relatedRows, request, options: options);
  }

  $grpc.ResponseFuture<$0.StagedChange> cloneRow(
    $0.CloneRowRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cloneRow, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> disposeResult(
    $0.PageRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$disposeResult, request, options: options);
  }

  $grpc.ResponseFuture<$0.ResultViewInfo> createResultView(
    $0.ResultViewRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createResultView, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> disposeResultView(
    $0.ResultViewRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$disposeResultView, request, options: options);
  }

  $grpc.ResponseFuture<$0.Analysis> completeSql(
    $0.AnalysisRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$completeSql, request, options: options);
  }

  $grpc.ResponseFuture<$0.Analysis> diagnoseSql(
    $0.AnalysisRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$diagnoseSql, request, options: options);
  }

  $grpc.ResponseFuture<$0.Analysis> sqlParameterInformation(
    $0.AnalysisRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sqlParameterInformation, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.Analysis> formatSql(
    $0.AnalysisRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$formatSql, request, options: options);
  }

  $grpc.ResponseFuture<$0.Analysis> resolveSqlSymbol(
    $0.AnalysisRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resolveSqlSymbol, request, options: options);
  }

  $grpc.ResponseFuture<$0.Analysis> sqlDdlImpact(
    $0.AnalysisRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sqlDdlImpact, request, options: options);
  }

  $grpc.ResponseFuture<$0.SchemaObjects> explore(
    $0.ExploreRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$explore, request, options: options);
  }

  $grpc.ResponseFuture<$0.MetadataSettingsReply> metadataSettings(
    $0.MetadataSettingsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$metadataSettings, request, options: options);
  }

  $grpc.ResponseFuture<$0.SchemaToolResult> schemaTool(
    $0.SchemaToolRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$schemaTool, request, options: options);
  }

  $grpc.ResponseFuture<$0.PrivilegeReply> privilegeTool(
    $0.PrivilegeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$privilegeTool, request, options: options);
  }

  $grpc.ResponseFuture<$0.Approval> reviewAuthentication(
    $0.AuthenticationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reviewAuthentication, request, options: options);
  }

  $grpc.ResponseFuture<$0.JobInfo> authentication(
    $0.AuthenticationRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$authentication, request, options: options);
  }

  $grpc.ResponseFuture<$0.ChangePlan> previewChanges(
    $0.ChangeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$previewChanges, request, options: options);
  }

  $grpc.ResponseFuture<$0.Editability> assessEditability(
    $0.ChangeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$assessEditability, request, options: options);
  }

  $grpc.ResponseFuture<$0.JobInfo> applyChanges(
    $0.ApplyRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$applyChanges, request, options: options);
  }

  $grpc.ResponseFuture<$0.EditDraftReply> editDraft(
    $0.EditDraftRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$editDraft, request, options: options);
  }

  $grpc.ResponseFuture<$0.Approval> reviewTool(
    $0.ToolRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reviewTool, request, options: options);
  }

  $grpc.ResponseFuture<$0.ActivityList> activities(
    $0.ActivityRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$activities, request, options: options);
  }

  $grpc.ResponseFuture<$0.CapabilityList> capabilities(
    $0.CapabilityRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$capabilities, request, options: options);
  }

  $grpc.ResponseFuture<$0.ImportPreview> previewImport(
    $0.ToolRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$previewImport, request, options: options);
  }

  $grpc.ResponseFuture<$0.JobInfo> tool(
    $0.ToolRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$tool, request, options: options);
  }

  $grpc.ResponseFuture<$0.HistoryList> history(
    $0.HistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$history, request, options: options);
  }

  $grpc.ResponseFuture<$0.HistorySqlChunk> historySql(
    $0.HistorySqlRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$historySql, request, options: options);
  }

  $grpc.ResponseFuture<$0.Empty> shutdown(
    $0.Context request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$shutdown, request, options: options);
  }

  $grpc.ResponseFuture<$0.RuntimeStatsReply> runtimeStats(
    $0.Context request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$runtimeStats, request, options: options);
  }

  // method descriptors

  static final _$ping = $grpc.ClientMethod<$0.Context, $0.BackendInfo>(
      '/busydata.v1.Workbench/Ping',
      ($0.Context value) => value.writeToBuffer(),
      $0.BackendInfo.fromBuffer);
  static final _$profiles =
      $grpc.ClientMethod<$0.ProfileRequest, $0.ProfileList>(
          '/busydata.v1.Workbench/Profiles',
          ($0.ProfileRequest value) => value.writeToBuffer(),
          $0.ProfileList.fromBuffer);
  static final _$testConnection =
      $grpc.ClientMethod<$0.OpenRequest, $0.ConnectionInfo>(
          '/busydata.v1.Workbench/TestConnection',
          ($0.OpenRequest value) => value.writeToBuffer(),
          $0.ConnectionInfo.fromBuffer);
  static final _$testSshConnection =
      $grpc.ClientMethod<$0.SshTestRequest, $0.SshTestReply>(
          '/busydata.v1.Workbench/TestSshConnection',
          ($0.SshTestRequest value) => value.writeToBuffer(),
          $0.SshTestReply.fromBuffer);
  static final _$describeConnection =
      $grpc.ClientMethod<$0.ProfileRequest, $0.ConnectionDescription>(
          '/busydata.v1.Workbench/DescribeConnection',
          ($0.ProfileRequest value) => value.writeToBuffer(),
          $0.ConnectionDescription.fromBuffer);
  static final _$reviewSshHost =
      $grpc.ClientMethod<$0.SshTrustRequest, $0.SshTrustReply>(
          '/busydata.v1.Workbench/ReviewSshHost',
          ($0.SshTrustRequest value) => value.writeToBuffer(),
          $0.SshTrustReply.fromBuffer);
  static final _$acceptSshHost =
      $grpc.ClientMethod<$0.SshTrustRequest, $0.SshTrustReply>(
          '/busydata.v1.Workbench/AcceptSshHost',
          ($0.SshTrustRequest value) => value.writeToBuffer(),
          $0.SshTrustReply.fromBuffer);
  static final _$openSession =
      $grpc.ClientMethod<$0.OpenRequest, $0.SessionInfo>(
          '/busydata.v1.Workbench/OpenSession',
          ($0.OpenRequest value) => value.writeToBuffer(),
          $0.SessionInfo.fromBuffer);
  static final _$session =
      $grpc.ClientMethod<$0.SessionRequest, $0.SessionInfo>(
          '/busydata.v1.Workbench/Session',
          ($0.SessionRequest value) => value.writeToBuffer(),
          $0.SessionInfo.fromBuffer);
  static final _$reviewSession =
      $grpc.ClientMethod<$0.SessionRequest, $0.Approval>(
          '/busydata.v1.Workbench/ReviewSession',
          ($0.SessionRequest value) => value.writeToBuffer(),
          $0.Approval.fromBuffer);
  static final _$review = $grpc.ClientMethod<$0.ExecuteRequest, $0.Approval>(
      '/busydata.v1.Workbench/Review',
      ($0.ExecuteRequest value) => value.writeToBuffer(),
      $0.Approval.fromBuffer);
  static final _$execute = $grpc.ClientMethod<$0.ExecuteRequest, $0.JobInfo>(
      '/busydata.v1.Workbench/Execute',
      ($0.ExecuteRequest value) => value.writeToBuffer(),
      $0.JobInfo.fromBuffer);
  static final _$reviewBrowse =
      $grpc.ClientMethod<$0.BrowseRequest, $0.Approval>(
          '/busydata.v1.Workbench/ReviewBrowse',
          ($0.BrowseRequest value) => value.writeToBuffer(),
          $0.Approval.fromBuffer);
  static final _$browse = $grpc.ClientMethod<$0.BrowseRequest, $0.JobInfo>(
      '/busydata.v1.Workbench/Browse',
      ($0.BrowseRequest value) => value.writeToBuffer(),
      $0.JobInfo.fromBuffer);
  static final _$jobs = $grpc.ClientMethod<$0.JobRequest, $0.JobList>(
      '/busydata.v1.Workbench/Jobs',
      ($0.JobRequest value) => value.writeToBuffer(),
      $0.JobList.fromBuffer);
  static final _$retainedResults =
      $grpc.ClientMethod<$0.RetainedRequest, $0.RetainedList>(
          '/busydata.v1.Workbench/RetainedResults',
          ($0.RetainedRequest value) => value.writeToBuffer(),
          $0.RetainedList.fromBuffer);
  static final _$cancel = $grpc.ClientMethod<$0.JobRequest, $0.JobInfo>(
      '/busydata.v1.Workbench/Cancel',
      ($0.JobRequest value) => value.writeToBuffer(),
      $0.JobInfo.fromBuffer);
  static final _$resultPage = $grpc.ClientMethod<$0.PageRequest, $0.Page>(
      '/busydata.v1.Workbench/ResultPage',
      ($0.PageRequest value) => value.writeToBuffer(),
      $0.Page.fromBuffer);
  static final _$resultValue =
      $grpc.ClientMethod<$0.ValueRequest, $0.ValueChunk>(
          '/busydata.v1.Workbench/ResultValue',
          ($0.ValueRequest value) => value.writeToBuffer(),
          $0.ValueChunk.fromBuffer);
  static final _$copySql =
      $grpc.ClientMethod<$0.CopySqlRequest, $0.CopySqlReply>(
          '/busydata.v1.Workbench/CopySql',
          ($0.CopySqlRequest value) => value.writeToBuffer(),
          $0.CopySqlReply.fromBuffer);
  static final _$resultAggregate =
      $grpc.ClientMethod<$0.ResultAggregateRequest, $0.ResultAggregateReply>(
          '/busydata.v1.Workbench/ResultAggregate',
          ($0.ResultAggregateRequest value) => value.writeToBuffer(),
          $0.ResultAggregateReply.fromBuffer);
  static final _$relatedRows =
      $grpc.ClientMethod<$0.RelatedRowsRequest, $0.RelatedRowsReply>(
          '/busydata.v1.Workbench/RelatedRows',
          ($0.RelatedRowsRequest value) => value.writeToBuffer(),
          $0.RelatedRowsReply.fromBuffer);
  static final _$cloneRow =
      $grpc.ClientMethod<$0.CloneRowRequest, $0.StagedChange>(
          '/busydata.v1.Workbench/CloneRow',
          ($0.CloneRowRequest value) => value.writeToBuffer(),
          $0.StagedChange.fromBuffer);
  static final _$disposeResult = $grpc.ClientMethod<$0.PageRequest, $0.Empty>(
      '/busydata.v1.Workbench/DisposeResult',
      ($0.PageRequest value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
  static final _$createResultView =
      $grpc.ClientMethod<$0.ResultViewRequest, $0.ResultViewInfo>(
          '/busydata.v1.Workbench/CreateResultView',
          ($0.ResultViewRequest value) => value.writeToBuffer(),
          $0.ResultViewInfo.fromBuffer);
  static final _$disposeResultView =
      $grpc.ClientMethod<$0.ResultViewRequest, $0.Empty>(
          '/busydata.v1.Workbench/DisposeResultView',
          ($0.ResultViewRequest value) => value.writeToBuffer(),
          $0.Empty.fromBuffer);
  static final _$completeSql =
      $grpc.ClientMethod<$0.AnalysisRequest, $0.Analysis>(
          '/busydata.v1.Workbench/CompleteSql',
          ($0.AnalysisRequest value) => value.writeToBuffer(),
          $0.Analysis.fromBuffer);
  static final _$diagnoseSql =
      $grpc.ClientMethod<$0.AnalysisRequest, $0.Analysis>(
          '/busydata.v1.Workbench/DiagnoseSql',
          ($0.AnalysisRequest value) => value.writeToBuffer(),
          $0.Analysis.fromBuffer);
  static final _$sqlParameterInformation =
      $grpc.ClientMethod<$0.AnalysisRequest, $0.Analysis>(
          '/busydata.v1.Workbench/SqlParameterInformation',
          ($0.AnalysisRequest value) => value.writeToBuffer(),
          $0.Analysis.fromBuffer);
  static final _$formatSql =
      $grpc.ClientMethod<$0.AnalysisRequest, $0.Analysis>(
          '/busydata.v1.Workbench/FormatSql',
          ($0.AnalysisRequest value) => value.writeToBuffer(),
          $0.Analysis.fromBuffer);
  static final _$resolveSqlSymbol =
      $grpc.ClientMethod<$0.AnalysisRequest, $0.Analysis>(
          '/busydata.v1.Workbench/ResolveSqlSymbol',
          ($0.AnalysisRequest value) => value.writeToBuffer(),
          $0.Analysis.fromBuffer);
  static final _$sqlDdlImpact =
      $grpc.ClientMethod<$0.AnalysisRequest, $0.Analysis>(
          '/busydata.v1.Workbench/SqlDdlImpact',
          ($0.AnalysisRequest value) => value.writeToBuffer(),
          $0.Analysis.fromBuffer);
  static final _$explore =
      $grpc.ClientMethod<$0.ExploreRequest, $0.SchemaObjects>(
          '/busydata.v1.Workbench/Explore',
          ($0.ExploreRequest value) => value.writeToBuffer(),
          $0.SchemaObjects.fromBuffer);
  static final _$metadataSettings =
      $grpc.ClientMethod<$0.MetadataSettingsRequest, $0.MetadataSettingsReply>(
          '/busydata.v1.Workbench/MetadataSettings',
          ($0.MetadataSettingsRequest value) => value.writeToBuffer(),
          $0.MetadataSettingsReply.fromBuffer);
  static final _$schemaTool =
      $grpc.ClientMethod<$0.SchemaToolRequest, $0.SchemaToolResult>(
          '/busydata.v1.Workbench/SchemaTool',
          ($0.SchemaToolRequest value) => value.writeToBuffer(),
          $0.SchemaToolResult.fromBuffer);
  static final _$privilegeTool =
      $grpc.ClientMethod<$0.PrivilegeRequest, $0.PrivilegeReply>(
          '/busydata.v1.Workbench/PrivilegeTool',
          ($0.PrivilegeRequest value) => value.writeToBuffer(),
          $0.PrivilegeReply.fromBuffer);
  static final _$reviewAuthentication =
      $grpc.ClientMethod<$0.AuthenticationRequest, $0.Approval>(
          '/busydata.v1.Workbench/ReviewAuthentication',
          ($0.AuthenticationRequest value) => value.writeToBuffer(),
          $0.Approval.fromBuffer);
  static final _$authentication =
      $grpc.ClientMethod<$0.AuthenticationRequest, $0.JobInfo>(
          '/busydata.v1.Workbench/Authentication',
          ($0.AuthenticationRequest value) => value.writeToBuffer(),
          $0.JobInfo.fromBuffer);
  static final _$previewChanges =
      $grpc.ClientMethod<$0.ChangeRequest, $0.ChangePlan>(
          '/busydata.v1.Workbench/PreviewChanges',
          ($0.ChangeRequest value) => value.writeToBuffer(),
          $0.ChangePlan.fromBuffer);
  static final _$assessEditability =
      $grpc.ClientMethod<$0.ChangeRequest, $0.Editability>(
          '/busydata.v1.Workbench/AssessEditability',
          ($0.ChangeRequest value) => value.writeToBuffer(),
          $0.Editability.fromBuffer);
  static final _$applyChanges = $grpc.ClientMethod<$0.ApplyRequest, $0.JobInfo>(
      '/busydata.v1.Workbench/ApplyChanges',
      ($0.ApplyRequest value) => value.writeToBuffer(),
      $0.JobInfo.fromBuffer);
  static final _$editDraft =
      $grpc.ClientMethod<$0.EditDraftRequest, $0.EditDraftReply>(
          '/busydata.v1.Workbench/EditDraft',
          ($0.EditDraftRequest value) => value.writeToBuffer(),
          $0.EditDraftReply.fromBuffer);
  static final _$reviewTool = $grpc.ClientMethod<$0.ToolRequest, $0.Approval>(
      '/busydata.v1.Workbench/ReviewTool',
      ($0.ToolRequest value) => value.writeToBuffer(),
      $0.Approval.fromBuffer);
  static final _$activities =
      $grpc.ClientMethod<$0.ActivityRequest, $0.ActivityList>(
          '/busydata.v1.Workbench/Activities',
          ($0.ActivityRequest value) => value.writeToBuffer(),
          $0.ActivityList.fromBuffer);
  static final _$capabilities =
      $grpc.ClientMethod<$0.CapabilityRequest, $0.CapabilityList>(
          '/busydata.v1.Workbench/Capabilities',
          ($0.CapabilityRequest value) => value.writeToBuffer(),
          $0.CapabilityList.fromBuffer);
  static final _$previewImport =
      $grpc.ClientMethod<$0.ToolRequest, $0.ImportPreview>(
          '/busydata.v1.Workbench/PreviewImport',
          ($0.ToolRequest value) => value.writeToBuffer(),
          $0.ImportPreview.fromBuffer);
  static final _$tool = $grpc.ClientMethod<$0.ToolRequest, $0.JobInfo>(
      '/busydata.v1.Workbench/Tool',
      ($0.ToolRequest value) => value.writeToBuffer(),
      $0.JobInfo.fromBuffer);
  static final _$history =
      $grpc.ClientMethod<$0.HistoryRequest, $0.HistoryList>(
          '/busydata.v1.Workbench/History',
          ($0.HistoryRequest value) => value.writeToBuffer(),
          $0.HistoryList.fromBuffer);
  static final _$historySql =
      $grpc.ClientMethod<$0.HistorySqlRequest, $0.HistorySqlChunk>(
          '/busydata.v1.Workbench/HistorySql',
          ($0.HistorySqlRequest value) => value.writeToBuffer(),
          $0.HistorySqlChunk.fromBuffer);
  static final _$shutdown = $grpc.ClientMethod<$0.Context, $0.Empty>(
      '/busydata.v1.Workbench/Shutdown',
      ($0.Context value) => value.writeToBuffer(),
      $0.Empty.fromBuffer);
  static final _$runtimeStats =
      $grpc.ClientMethod<$0.Context, $0.RuntimeStatsReply>(
          '/busydata.v1.Workbench/RuntimeStats',
          ($0.Context value) => value.writeToBuffer(),
          $0.RuntimeStatsReply.fromBuffer);
}

@$pb.GrpcServiceName('busydata.v1.Workbench')
abstract class WorkbenchServiceBase extends $grpc.Service {
  $core.String get $name => 'busydata.v1.Workbench';

  WorkbenchServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.Context, $0.BackendInfo>(
        'Ping',
        ping_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Context.fromBuffer(value),
        ($0.BackendInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ProfileRequest, $0.ProfileList>(
        'Profiles',
        profiles_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ProfileRequest.fromBuffer(value),
        ($0.ProfileList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.OpenRequest, $0.ConnectionInfo>(
        'TestConnection',
        testConnection_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.OpenRequest.fromBuffer(value),
        ($0.ConnectionInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SshTestRequest, $0.SshTestReply>(
        'TestSshConnection',
        testSshConnection_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SshTestRequest.fromBuffer(value),
        ($0.SshTestReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ProfileRequest, $0.ConnectionDescription>(
        'DescribeConnection',
        describeConnection_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ProfileRequest.fromBuffer(value),
        ($0.ConnectionDescription value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SshTrustRequest, $0.SshTrustReply>(
        'ReviewSshHost',
        reviewSshHost_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SshTrustRequest.fromBuffer(value),
        ($0.SshTrustReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SshTrustRequest, $0.SshTrustReply>(
        'AcceptSshHost',
        acceptSshHost_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SshTrustRequest.fromBuffer(value),
        ($0.SshTrustReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.OpenRequest, $0.SessionInfo>(
        'OpenSession',
        openSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.OpenRequest.fromBuffer(value),
        ($0.SessionInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SessionRequest, $0.SessionInfo>(
        'Session',
        session_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SessionRequest.fromBuffer(value),
        ($0.SessionInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SessionRequest, $0.Approval>(
        'ReviewSession',
        reviewSession_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SessionRequest.fromBuffer(value),
        ($0.Approval value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ExecuteRequest, $0.Approval>(
        'Review',
        review_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ExecuteRequest.fromBuffer(value),
        ($0.Approval value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ExecuteRequest, $0.JobInfo>(
        'Execute',
        execute_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ExecuteRequest.fromBuffer(value),
        ($0.JobInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BrowseRequest, $0.Approval>(
        'ReviewBrowse',
        reviewBrowse_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BrowseRequest.fromBuffer(value),
        ($0.Approval value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BrowseRequest, $0.JobInfo>(
        'Browse',
        browse_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.BrowseRequest.fromBuffer(value),
        ($0.JobInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.JobRequest, $0.JobList>(
        'Jobs',
        jobs_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.JobRequest.fromBuffer(value),
        ($0.JobList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RetainedRequest, $0.RetainedList>(
        'RetainedResults',
        retainedResults_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RetainedRequest.fromBuffer(value),
        ($0.RetainedList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.JobRequest, $0.JobInfo>(
        'Cancel',
        cancel_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.JobRequest.fromBuffer(value),
        ($0.JobInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PageRequest, $0.Page>(
        'ResultPage',
        resultPage_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PageRequest.fromBuffer(value),
        ($0.Page value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ValueRequest, $0.ValueChunk>(
        'ResultValue',
        resultValue_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ValueRequest.fromBuffer(value),
        ($0.ValueChunk value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CopySqlRequest, $0.CopySqlReply>(
        'CopySql',
        copySql_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CopySqlRequest.fromBuffer(value),
        ($0.CopySqlReply value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ResultAggregateRequest, $0.ResultAggregateReply>(
            'ResultAggregate',
            resultAggregate_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ResultAggregateRequest.fromBuffer(value),
            ($0.ResultAggregateReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RelatedRowsRequest, $0.RelatedRowsReply>(
        'RelatedRows',
        relatedRows_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RelatedRowsRequest.fromBuffer(value),
        ($0.RelatedRowsReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CloneRowRequest, $0.StagedChange>(
        'CloneRow',
        cloneRow_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CloneRowRequest.fromBuffer(value),
        ($0.StagedChange value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PageRequest, $0.Empty>(
        'DisposeResult',
        disposeResult_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PageRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ResultViewRequest, $0.ResultViewInfo>(
        'CreateResultView',
        createResultView_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ResultViewRequest.fromBuffer(value),
        ($0.ResultViewInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ResultViewRequest, $0.Empty>(
        'DisposeResultView',
        disposeResultView_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ResultViewRequest.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AnalysisRequest, $0.Analysis>(
        'CompleteSql',
        completeSql_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AnalysisRequest.fromBuffer(value),
        ($0.Analysis value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AnalysisRequest, $0.Analysis>(
        'DiagnoseSql',
        diagnoseSql_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AnalysisRequest.fromBuffer(value),
        ($0.Analysis value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AnalysisRequest, $0.Analysis>(
        'SqlParameterInformation',
        sqlParameterInformation_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AnalysisRequest.fromBuffer(value),
        ($0.Analysis value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AnalysisRequest, $0.Analysis>(
        'FormatSql',
        formatSql_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AnalysisRequest.fromBuffer(value),
        ($0.Analysis value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AnalysisRequest, $0.Analysis>(
        'ResolveSqlSymbol',
        resolveSqlSymbol_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AnalysisRequest.fromBuffer(value),
        ($0.Analysis value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AnalysisRequest, $0.Analysis>(
        'SqlDdlImpact',
        sqlDdlImpact_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.AnalysisRequest.fromBuffer(value),
        ($0.Analysis value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ExploreRequest, $0.SchemaObjects>(
        'Explore',
        explore_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ExploreRequest.fromBuffer(value),
        ($0.SchemaObjects value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.MetadataSettingsRequest,
            $0.MetadataSettingsReply>(
        'MetadataSettings',
        metadataSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.MetadataSettingsRequest.fromBuffer(value),
        ($0.MetadataSettingsReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SchemaToolRequest, $0.SchemaToolResult>(
        'SchemaTool',
        schemaTool_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SchemaToolRequest.fromBuffer(value),
        ($0.SchemaToolResult value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PrivilegeRequest, $0.PrivilegeReply>(
        'PrivilegeTool',
        privilegeTool_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.PrivilegeRequest.fromBuffer(value),
        ($0.PrivilegeReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AuthenticationRequest, $0.Approval>(
        'ReviewAuthentication',
        reviewAuthentication_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AuthenticationRequest.fromBuffer(value),
        ($0.Approval value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AuthenticationRequest, $0.JobInfo>(
        'Authentication',
        authentication_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AuthenticationRequest.fromBuffer(value),
        ($0.JobInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ChangeRequest, $0.ChangePlan>(
        'PreviewChanges',
        previewChanges_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ChangeRequest.fromBuffer(value),
        ($0.ChangePlan value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ChangeRequest, $0.Editability>(
        'AssessEditability',
        assessEditability_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ChangeRequest.fromBuffer(value),
        ($0.Editability value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ApplyRequest, $0.JobInfo>(
        'ApplyChanges',
        applyChanges_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ApplyRequest.fromBuffer(value),
        ($0.JobInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.EditDraftRequest, $0.EditDraftReply>(
        'EditDraft',
        editDraft_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.EditDraftRequest.fromBuffer(value),
        ($0.EditDraftReply value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ToolRequest, $0.Approval>(
        'ReviewTool',
        reviewTool_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ToolRequest.fromBuffer(value),
        ($0.Approval value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ActivityRequest, $0.ActivityList>(
        'Activities',
        activities_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ActivityRequest.fromBuffer(value),
        ($0.ActivityList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CapabilityRequest, $0.CapabilityList>(
        'Capabilities',
        capabilities_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CapabilityRequest.fromBuffer(value),
        ($0.CapabilityList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ToolRequest, $0.ImportPreview>(
        'PreviewImport',
        previewImport_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ToolRequest.fromBuffer(value),
        ($0.ImportPreview value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ToolRequest, $0.JobInfo>(
        'Tool',
        tool_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ToolRequest.fromBuffer(value),
        ($0.JobInfo value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.HistoryRequest, $0.HistoryList>(
        'History',
        history_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.HistoryRequest.fromBuffer(value),
        ($0.HistoryList value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.HistorySqlRequest, $0.HistorySqlChunk>(
        'HistorySql',
        historySql_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.HistorySqlRequest.fromBuffer(value),
        ($0.HistorySqlChunk value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Context, $0.Empty>(
        'Shutdown',
        shutdown_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Context.fromBuffer(value),
        ($0.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.Context, $0.RuntimeStatsReply>(
        'RuntimeStats',
        runtimeStats_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.Context.fromBuffer(value),
        ($0.RuntimeStatsReply value) => value.writeToBuffer()));
  }

  $async.Future<$0.BackendInfo> ping_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Context> $request) async {
    return ping($call, await $request);
  }

  $async.Future<$0.BackendInfo> ping(
      $grpc.ServiceCall call, $0.Context request);

  $async.Future<$0.ProfileList> profiles_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ProfileRequest> $request) async {
    return profiles($call, await $request);
  }

  $async.Future<$0.ProfileList> profiles(
      $grpc.ServiceCall call, $0.ProfileRequest request);

  $async.Future<$0.ConnectionInfo> testConnection_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.OpenRequest> $request) async {
    return testConnection($call, await $request);
  }

  $async.Future<$0.ConnectionInfo> testConnection(
      $grpc.ServiceCall call, $0.OpenRequest request);

  $async.Future<$0.SshTestReply> testSshConnection_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SshTestRequest> $request) async {
    return testSshConnection($call, await $request);
  }

  $async.Future<$0.SshTestReply> testSshConnection(
      $grpc.ServiceCall call, $0.SshTestRequest request);

  $async.Future<$0.ConnectionDescription> describeConnection_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ProfileRequest> $request) async {
    return describeConnection($call, await $request);
  }

  $async.Future<$0.ConnectionDescription> describeConnection(
      $grpc.ServiceCall call, $0.ProfileRequest request);

  $async.Future<$0.SshTrustReply> reviewSshHost_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SshTrustRequest> $request) async {
    return reviewSshHost($call, await $request);
  }

  $async.Future<$0.SshTrustReply> reviewSshHost(
      $grpc.ServiceCall call, $0.SshTrustRequest request);

  $async.Future<$0.SshTrustReply> acceptSshHost_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SshTrustRequest> $request) async {
    return acceptSshHost($call, await $request);
  }

  $async.Future<$0.SshTrustReply> acceptSshHost(
      $grpc.ServiceCall call, $0.SshTrustRequest request);

  $async.Future<$0.SessionInfo> openSession_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.OpenRequest> $request) async {
    return openSession($call, await $request);
  }

  $async.Future<$0.SessionInfo> openSession(
      $grpc.ServiceCall call, $0.OpenRequest request);

  $async.Future<$0.SessionInfo> session_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SessionRequest> $request) async {
    return session($call, await $request);
  }

  $async.Future<$0.SessionInfo> session(
      $grpc.ServiceCall call, $0.SessionRequest request);

  $async.Future<$0.Approval> reviewSession_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SessionRequest> $request) async {
    return reviewSession($call, await $request);
  }

  $async.Future<$0.Approval> reviewSession(
      $grpc.ServiceCall call, $0.SessionRequest request);

  $async.Future<$0.Approval> review_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ExecuteRequest> $request) async {
    return review($call, await $request);
  }

  $async.Future<$0.Approval> review(
      $grpc.ServiceCall call, $0.ExecuteRequest request);

  $async.Future<$0.JobInfo> execute_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ExecuteRequest> $request) async {
    return execute($call, await $request);
  }

  $async.Future<$0.JobInfo> execute(
      $grpc.ServiceCall call, $0.ExecuteRequest request);

  $async.Future<$0.Approval> reviewBrowse_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BrowseRequest> $request) async {
    return reviewBrowse($call, await $request);
  }

  $async.Future<$0.Approval> reviewBrowse(
      $grpc.ServiceCall call, $0.BrowseRequest request);

  $async.Future<$0.JobInfo> browse_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.BrowseRequest> $request) async {
    return browse($call, await $request);
  }

  $async.Future<$0.JobInfo> browse(
      $grpc.ServiceCall call, $0.BrowseRequest request);

  $async.Future<$0.JobList> jobs_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.JobRequest> $request) async {
    return jobs($call, await $request);
  }

  $async.Future<$0.JobList> jobs($grpc.ServiceCall call, $0.JobRequest request);

  $async.Future<$0.RetainedList> retainedResults_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RetainedRequest> $request) async {
    return retainedResults($call, await $request);
  }

  $async.Future<$0.RetainedList> retainedResults(
      $grpc.ServiceCall call, $0.RetainedRequest request);

  $async.Future<$0.JobInfo> cancel_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.JobRequest> $request) async {
    return cancel($call, await $request);
  }

  $async.Future<$0.JobInfo> cancel(
      $grpc.ServiceCall call, $0.JobRequest request);

  $async.Future<$0.Page> resultPage_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PageRequest> $request) async {
    return resultPage($call, await $request);
  }

  $async.Future<$0.Page> resultPage(
      $grpc.ServiceCall call, $0.PageRequest request);

  $async.Future<$0.ValueChunk> resultValue_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ValueRequest> $request) async {
    return resultValue($call, await $request);
  }

  $async.Future<$0.ValueChunk> resultValue(
      $grpc.ServiceCall call, $0.ValueRequest request);

  $async.Future<$0.CopySqlReply> copySql_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CopySqlRequest> $request) async {
    return copySql($call, await $request);
  }

  $async.Future<$0.CopySqlReply> copySql(
      $grpc.ServiceCall call, $0.CopySqlRequest request);

  $async.Future<$0.ResultAggregateReply> resultAggregate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ResultAggregateRequest> $request) async {
    return resultAggregate($call, await $request);
  }

  $async.Future<$0.ResultAggregateReply> resultAggregate(
      $grpc.ServiceCall call, $0.ResultAggregateRequest request);

  $async.Future<$0.RelatedRowsReply> relatedRows_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RelatedRowsRequest> $request) async {
    return relatedRows($call, await $request);
  }

  $async.Future<$0.RelatedRowsReply> relatedRows(
      $grpc.ServiceCall call, $0.RelatedRowsRequest request);

  $async.Future<$0.StagedChange> cloneRow_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CloneRowRequest> $request) async {
    return cloneRow($call, await $request);
  }

  $async.Future<$0.StagedChange> cloneRow(
      $grpc.ServiceCall call, $0.CloneRowRequest request);

  $async.Future<$0.Empty> disposeResult_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.PageRequest> $request) async {
    return disposeResult($call, await $request);
  }

  $async.Future<$0.Empty> disposeResult(
      $grpc.ServiceCall call, $0.PageRequest request);

  $async.Future<$0.ResultViewInfo> createResultView_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ResultViewRequest> $request) async {
    return createResultView($call, await $request);
  }

  $async.Future<$0.ResultViewInfo> createResultView(
      $grpc.ServiceCall call, $0.ResultViewRequest request);

  $async.Future<$0.Empty> disposeResultView_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ResultViewRequest> $request) async {
    return disposeResultView($call, await $request);
  }

  $async.Future<$0.Empty> disposeResultView(
      $grpc.ServiceCall call, $0.ResultViewRequest request);

  $async.Future<$0.Analysis> completeSql_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AnalysisRequest> $request) async {
    return completeSql($call, await $request);
  }

  $async.Future<$0.Analysis> completeSql(
      $grpc.ServiceCall call, $0.AnalysisRequest request);

  $async.Future<$0.Analysis> diagnoseSql_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AnalysisRequest> $request) async {
    return diagnoseSql($call, await $request);
  }

  $async.Future<$0.Analysis> diagnoseSql(
      $grpc.ServiceCall call, $0.AnalysisRequest request);

  $async.Future<$0.Analysis> sqlParameterInformation_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.AnalysisRequest> $request) async {
    return sqlParameterInformation($call, await $request);
  }

  $async.Future<$0.Analysis> sqlParameterInformation(
      $grpc.ServiceCall call, $0.AnalysisRequest request);

  $async.Future<$0.Analysis> formatSql_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AnalysisRequest> $request) async {
    return formatSql($call, await $request);
  }

  $async.Future<$0.Analysis> formatSql(
      $grpc.ServiceCall call, $0.AnalysisRequest request);

  $async.Future<$0.Analysis> resolveSqlSymbol_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AnalysisRequest> $request) async {
    return resolveSqlSymbol($call, await $request);
  }

  $async.Future<$0.Analysis> resolveSqlSymbol(
      $grpc.ServiceCall call, $0.AnalysisRequest request);

  $async.Future<$0.Analysis> sqlDdlImpact_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AnalysisRequest> $request) async {
    return sqlDdlImpact($call, await $request);
  }

  $async.Future<$0.Analysis> sqlDdlImpact(
      $grpc.ServiceCall call, $0.AnalysisRequest request);

  $async.Future<$0.SchemaObjects> explore_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ExploreRequest> $request) async {
    return explore($call, await $request);
  }

  $async.Future<$0.SchemaObjects> explore(
      $grpc.ServiceCall call, $0.ExploreRequest request);

  $async.Future<$0.MetadataSettingsReply> metadataSettings_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.MetadataSettingsRequest> $request) async {
    return metadataSettings($call, await $request);
  }

  $async.Future<$0.MetadataSettingsReply> metadataSettings(
      $grpc.ServiceCall call, $0.MetadataSettingsRequest request);

  $async.Future<$0.SchemaToolResult> schemaTool_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SchemaToolRequest> $request) async {
    return schemaTool($call, await $request);
  }

  $async.Future<$0.SchemaToolResult> schemaTool(
      $grpc.ServiceCall call, $0.SchemaToolRequest request);

  $async.Future<$0.PrivilegeReply> privilegeTool_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PrivilegeRequest> $request) async {
    return privilegeTool($call, await $request);
  }

  $async.Future<$0.PrivilegeReply> privilegeTool(
      $grpc.ServiceCall call, $0.PrivilegeRequest request);

  $async.Future<$0.Approval> reviewAuthentication_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AuthenticationRequest> $request) async {
    return reviewAuthentication($call, await $request);
  }

  $async.Future<$0.Approval> reviewAuthentication(
      $grpc.ServiceCall call, $0.AuthenticationRequest request);

  $async.Future<$0.JobInfo> authentication_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AuthenticationRequest> $request) async {
    return authentication($call, await $request);
  }

  $async.Future<$0.JobInfo> authentication(
      $grpc.ServiceCall call, $0.AuthenticationRequest request);

  $async.Future<$0.ChangePlan> previewChanges_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ChangeRequest> $request) async {
    return previewChanges($call, await $request);
  }

  $async.Future<$0.ChangePlan> previewChanges(
      $grpc.ServiceCall call, $0.ChangeRequest request);

  $async.Future<$0.Editability> assessEditability_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ChangeRequest> $request) async {
    return assessEditability($call, await $request);
  }

  $async.Future<$0.Editability> assessEditability(
      $grpc.ServiceCall call, $0.ChangeRequest request);

  $async.Future<$0.JobInfo> applyChanges_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ApplyRequest> $request) async {
    return applyChanges($call, await $request);
  }

  $async.Future<$0.JobInfo> applyChanges(
      $grpc.ServiceCall call, $0.ApplyRequest request);

  $async.Future<$0.EditDraftReply> editDraft_Pre($grpc.ServiceCall $call,
      $async.Future<$0.EditDraftRequest> $request) async {
    return editDraft($call, await $request);
  }

  $async.Future<$0.EditDraftReply> editDraft(
      $grpc.ServiceCall call, $0.EditDraftRequest request);

  $async.Future<$0.Approval> reviewTool_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ToolRequest> $request) async {
    return reviewTool($call, await $request);
  }

  $async.Future<$0.Approval> reviewTool(
      $grpc.ServiceCall call, $0.ToolRequest request);

  $async.Future<$0.ActivityList> activities_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ActivityRequest> $request) async {
    return activities($call, await $request);
  }

  $async.Future<$0.ActivityList> activities(
      $grpc.ServiceCall call, $0.ActivityRequest request);

  $async.Future<$0.CapabilityList> capabilities_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CapabilityRequest> $request) async {
    return capabilities($call, await $request);
  }

  $async.Future<$0.CapabilityList> capabilities(
      $grpc.ServiceCall call, $0.CapabilityRequest request);

  $async.Future<$0.ImportPreview> previewImport_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ToolRequest> $request) async {
    return previewImport($call, await $request);
  }

  $async.Future<$0.ImportPreview> previewImport(
      $grpc.ServiceCall call, $0.ToolRequest request);

  $async.Future<$0.JobInfo> tool_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.ToolRequest> $request) async {
    return tool($call, await $request);
  }

  $async.Future<$0.JobInfo> tool(
      $grpc.ServiceCall call, $0.ToolRequest request);

  $async.Future<$0.HistoryList> history_Pre($grpc.ServiceCall $call,
      $async.Future<$0.HistoryRequest> $request) async {
    return history($call, await $request);
  }

  $async.Future<$0.HistoryList> history(
      $grpc.ServiceCall call, $0.HistoryRequest request);

  $async.Future<$0.HistorySqlChunk> historySql_Pre($grpc.ServiceCall $call,
      $async.Future<$0.HistorySqlRequest> $request) async {
    return historySql($call, await $request);
  }

  $async.Future<$0.HistorySqlChunk> historySql(
      $grpc.ServiceCall call, $0.HistorySqlRequest request);

  $async.Future<$0.Empty> shutdown_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Context> $request) async {
    return shutdown($call, await $request);
  }

  $async.Future<$0.Empty> shutdown($grpc.ServiceCall call, $0.Context request);

  $async.Future<$0.RuntimeStatsReply> runtimeStats_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.Context> $request) async {
    return runtimeStats($call, await $request);
  }

  $async.Future<$0.RuntimeStatsReply> runtimeStats(
      $grpc.ServiceCall call, $0.Context request);
}
