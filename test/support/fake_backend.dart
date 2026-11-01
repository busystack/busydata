import 'dart:async';
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:busydata/src/backend/backend_process.dart';
import 'package:busydata/src/backend/generated/busydata.pbgrpc.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

// One declared mock-server source. Multi-source fixtures supply distinct ids.
const fixtureMetadataSourceIdentity =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

class MockCall<T> extends Mock implements ClientCall<dynamic, T> {}

ResponseFuture<T> response<T>(Future<T> future, {void Function()? onCancel}) {
  final call = MockCall<T>();
  when(() => call.response).thenAnswer((_) => future.asStream());
  when(() => call.cancel()).thenAnswer((_) async => onCancel?.call());
  return ResponseFuture<T>(call);
}

class FakeProcess extends Fake implements Process {
  final exit = Completer<int>();
  @override
  Future<int> get exitCode => exit.future;
}

class TestBackend extends Fake implements BackendConnection {
  TestBackend({this.instanceId = 'test-instance', TestClient? client})
    : client = client ?? TestClient();
  @override
  final String instanceId;
  @override
  final TestClient client;
  @override
  final FakeProcess process = FakeProcess();
  bool closed = false;
  @override
  Context context() => Context(
    instanceId: instanceId,
    protocolVersion: ProtocolVersion.BUSYDATA_PROTOCOL_VERSION.value,
    requestId: 'test-request',
  );
  @override
  Future<void> close() async {
    closed = true;
  }
}

class TestClient extends Fake implements WorkbenchClient {
  Future<HistoryList> Function(HistoryRequest)? historyCatalog;
  Future<HistorySqlChunk> Function(HistorySqlRequest)? historyText;
  final historyRequests = <HistoryRequest>[];
  final historySqlRequests = <HistorySqlRequest>[];
  @override
  ResponseFuture<HistoryList> history(
    HistoryRequest request, {
    CallOptions? options,
  }) {
    historyRequests.add(request.deepCopy());
    return response(historyCatalog!(request));
  }

  @override
  ResponseFuture<HistorySqlChunk> historySql(
    HistorySqlRequest request, {
    CallOptions? options,
  }) {
    historySqlRequests.add(request.deepCopy());
    return response(historyText!(request));
  }

  Future<ConnectionDescription> Function(ProfileRequest)? connectionDescription;
  @override
  ResponseFuture<ConnectionDescription> describeConnection(
    ProfileRequest request, {
    CallOptions? options,
  }) => response(
    connectionDescription?.call(request) ??
        Future.value(
          ConnectionDescription(
            jdbcUrl: 'jdbc:fixture://fixture/',
            driverClass: 'fixture.Driver',
            driverVersion: 'fixture',
          ),
        ),
  );
  Future<ConnectionInfo> Function(OpenRequest)? connectionTest;
  final connectionTests = <OpenRequest>[];
  int cancelledConnectionTests = 0;
  Future<SshTestReply> Function(SshTestRequest)? sshTest;
  final sshTests = <SshTestRequest>[];
  int cancelledSshTests = 0;
  @override
  ResponseFuture<SshTestReply> testSshConnection(
    SshTestRequest request, {
    CallOptions? options,
  }) {
    sshTests.add(request.deepCopy());
    return response(
      sshTest?.call(request) ??
          Future.value(
            SshTestReply(
              host: request.ssh.host,
              port: request.ssh.port,
              user: request.ssh.user,
              algorithm: 'ssh-ed25519',
              fingerprint: 'SHA256:reviewed-fixture',
            ),
          ),
      onCancel: () => cancelledSshTests++,
    );
  }

  final sshReviews = <SshTrustRequest>[];
  final sshAccepts = <SshTrustRequest>[];
  @override
  ResponseFuture<SshTrustReply> reviewSshHost(
    SshTrustRequest request, {
    CallOptions? options,
  }) {
    sshReviews.add(request.deepCopy());
    return response(
      Future.value(
        SshTrustReply(
          host: request.profile.ssh.host,
          port: request.profile.ssh.port,
          algorithm: 'ssh-ed25519',
          fingerprint: 'SHA256:reviewed-fixture',
          approvalToken: 'review-fixture',
        ),
      ),
    );
  }

  @override
  ResponseFuture<SshTrustReply> acceptSshHost(
    SshTrustRequest request, {
    CallOptions? options,
  }) {
    sshAccepts.add(request.deepCopy());
    return response(
      Future.value(
        SshTrustReply(
          trustRef: 'ssh-trust-fixture',
          algorithm: request.algorithm,
          fingerprint: request.fingerprint,
        ),
      ),
    );
  }

  @override
  ResponseFuture<ConnectionInfo> testConnection(
    OpenRequest request, {
    CallOptions? options,
  }) {
    connectionTests.add(request.deepCopy());
    return response(
      connectionTest!(request),
      onCancel: () => cancelledConnectionTests++,
    );
  }

  final executions = <ExecuteRequest>[];
  final reviews = <ExecuteRequest>[];
  Future<Approval> Function(ExecuteRequest)? sqlReview;
  @override
  ResponseFuture<Approval> review(
    ExecuteRequest request, {
    CallOptions? options,
  }) {
    reviews.add(request.deepCopy());
    return response(
      sqlReview?.call(request) ?? Future.value(Approval(token: 'sql-review')),
    );
  }

  @override
  ResponseFuture<JobInfo> execute(
    ExecuteRequest request, {
    CallOptions? options,
  }) {
    executions.add(request.deepCopy());
    return response(
      Future.value(
        JobInfo(
          jobId: 'sql-job',
          executionId: request.executionId,
          sessionId: request.sessionId,
        ),
      ),
    );
  }

  Future<SchemaObjects> Function(ExploreRequest)? metadataAction;
  SchemaObjects Function(ExploreRequest, SchemaObjects)? metadataEnvelope;
  final metadataRequests = <ExploreRequest>[];
  int cancelledMetadataRequests = 0;
  @override
  ResponseFuture<SchemaObjects> explore(
    ExploreRequest request, {
    CallOptions? options,
  }) {
    metadataRequests.add(request.deepCopy());
    return response(
      (metadataAction == null
              ? Future.value(SchemaObjects(complete: true))
              : metadataAction!(request))
          .then((reply) => metadataEnvelope?.call(request, reply) ?? reply),
      onCancel: () => cancelledMetadataRequests++,
    );
  }

  final browseRequests = <BrowseRequest>[];
  final browseReviews = <BrowseRequest>[];
  Future<Approval> Function(BrowseRequest)? browseReview;
  @override
  ResponseFuture<Approval> reviewBrowse(
    BrowseRequest request, {
    CallOptions? options,
  }) {
    browseReviews.add(request.deepCopy());
    return response(
      browseReview?.call(request) ??
          Future.value(Approval(token: 'browse-review')),
    );
  }

  @override
  ResponseFuture<JobInfo> browse(
    BrowseRequest request, {
    CallOptions? options,
  }) {
    browseRequests.add(request.deepCopy());
    return response(
      Future.value(
        JobInfo(
          jobId: 'browse-job',
          executionId: request.executionId,
          sessionId: request.sessionId,
        ),
      ),
    );
  }

  @override
  ResponseFuture<Editability> assessEditability(
    ChangeRequest request, {
    CallOptions? options,
  }) => response(
    Future.value(editability ?? Editability(reason: 'Fixture is read-only')),
  );
  Editability? editability;
  Future<ResultViewInfo> Function(ResultViewRequest)? viewCreate;
  final viewRequests = <ResultViewRequest>[];
  final disposedViews = <String>[];
  @override
  ResponseFuture<ResultViewInfo> createResultView(
    ResultViewRequest request, {
    CallOptions? options,
  }) {
    viewRequests.add(request.deepCopy());
    return response(viewCreate!(request));
  }

  @override
  ResponseFuture<Empty> disposeResultView(
    ResultViewRequest request, {
    CallOptions? options,
  }) {
    disposedViews.add(request.viewId);
    return response(Future.value(Empty()));
  }

  Future<CapabilityList> Function(CapabilityRequest)? capabilityAction;
  final capabilityRequests = <CapabilityRequest>[];
  @override
  ResponseFuture<CapabilityList> capabilities(
    CapabilityRequest request, {
    CallOptions? options,
  }) {
    capabilityRequests.add(request.deepCopy());
    return response(capabilityAction!(request));
  }

  Future<CopySqlReply> Function(CopySqlRequest)? sqlCopy;
  final sqlCopyRequests = <CopySqlRequest>[];
  @override
  ResponseFuture<CopySqlReply> copySql(
    CopySqlRequest request, {
    CallOptions? options,
  }) {
    sqlCopyRequests.add(request.deepCopy());
    return response(sqlCopy!(request));
  }

  Future<Approval> Function(ToolRequest)? toolReview;
  Future<ImportPreview> Function(ToolRequest)? importPreview;
  final importPreviewRequests = <ToolRequest>[];
  @override
  ResponseFuture<ImportPreview> previewImport(
    ToolRequest request, {
    CallOptions? options,
  }) {
    importPreviewRequests.add(request.deepCopy());
    return response(importPreview!(request));
  }

  final toolReviewRequests = <ToolRequest>[];
  @override
  ResponseFuture<Approval> reviewTool(
    ToolRequest request, {
    CallOptions? options,
  }) {
    toolReviewRequests.add(request.deepCopy());
    return response(
      toolReview == null
          ? Future.value(Approval(token: 'tool-review'))
          : toolReview!(request),
    );
  }

  Future<SchemaToolResult> Function(SchemaToolRequest)? schemaTools;
  final schemaToolRequests = <SchemaToolRequest>[];
  int cancelledSchemaTools = 0;
  @override
  ResponseFuture<SchemaToolResult> schemaTool(
    SchemaToolRequest request, {
    CallOptions? options,
  }) {
    schemaToolRequests.add(request.deepCopy());
    return response(
      schemaTools!(request),
      onCancel: () => cancelledSchemaTools++,
    );
  }

  Future<ProfileList> Function(ProfileRequest)? profileAction;
  final profileRequests = <ProfileRequest>[];
  @override
  ResponseFuture<ProfileList> profiles(
    ProfileRequest request, {
    CallOptions? options,
  }) {
    profileRequests.add(request.deepCopy());
    return response(
      profileAction == null
          ? Future.value(ProfileList())
          : profileAction!(request),
    );
  }

  Future<ActivityList> Function(ActivityRequest)? activityAction;
  final activityRequests = <ActivityRequest>[];
  @override
  ResponseFuture<ActivityList> activities(
    ActivityRequest request, {
    CallOptions? options,
  }) {
    activityRequests.add(request.deepCopy());
    return response(activityAction!(request));
  }

  Future<JobInfo> Function(ToolRequest)? tools;
  final toolRequests = <ToolRequest>[];
  @override
  ResponseFuture<JobInfo> tool(ToolRequest request, {CallOptions? options}) {
    toolRequests.add(request.deepCopy());
    return response(tools!(request));
  }

  Future<JobInfo> Function(JobRequest)? cancelling;
  @override
  ResponseFuture<JobInfo> cancel(JobRequest request, {CallOptions? options}) =>
      response(cancelling!(request));
  final disposed = <String>[];
  @override
  ResponseFuture<Empty> disposeResult(
    PageRequest request, {
    CallOptions? options,
  }) {
    disposed.add(request.resultId);
    return response(Future.value(Empty()));
  }

  Future<EditDraftReply> Function(EditDraftRequest)? edits;
  final editRequests = <EditDraftRequest>[];
  @override
  ResponseFuture<EditDraftReply> editDraft(
    EditDraftRequest request, {
    CallOptions? options,
  }) {
    editRequests.add(request.deepCopy());
    return response(
      edits == null ? Future.value(EditDraftReply()) : edits!(request),
    );
  }

  JobList jobList = JobList(complete: true, catalogRevision: Int64(1));
  Future<JobList> Function(JobRequest)? jobPages;
  final jobRequests = <JobRequest>[];
  RetainedList retained = RetainedList(complete: true);
  @override
  ResponseFuture<RetainedList> retainedResults(
    RetainedRequest request, {
    CallOptions? options,
  }) => response(Future.value(retained));
  Future<SessionInfo> Function(OpenRequest)? opening;
  Future<SessionInfo> Function(SessionRequest)? sessionCommand;
  final opened = <OpenRequest>[], sessionCommands = <SessionRequest>[];
  final openedSessionOwners = <String, SessionInfo>{};
  @override
  ResponseFuture<SessionInfo> openSession(
    OpenRequest request, {
    CallOptions? options,
  }) {
    opened.add(request.deepCopy());
    return response(
      opening!(request).then((reply) {
        openedSessionOwners[reply.sessionId] = reply.deepCopy();
        return reply;
      }),
    );
  }

  @override
  ResponseFuture<SessionInfo> session(
    SessionRequest request, {
    CallOptions? options,
  }) {
    sessionCommands.add(request.deepCopy());
    return response(
      sessionCommand == null
          ? Future.value(
              openedSessionOwners[request.sessionId]?.deepCopy() ??
                  SessionInfo(
                    metadataSourceIdentity: fixtureMetadataSourceIdentity,
                    sessionId: request.sessionId,
                  ),
            )
          : sessionCommand!(request),
    );
  }

  Future<Approval> Function(SessionRequest)? sessionReview;
  @override
  ResponseFuture<Approval> reviewSession(
    SessionRequest request, {
    CallOptions? options,
  }) => response(
    sessionReview == null
        ? Future.value(Approval(token: 'review'))
        : sessionReview!(request),
  );
  Future<Page> Function(PageRequest)? pages;
  final pageRequests = <PageRequest>[];
  @override
  ResponseFuture<Page> resultPage(PageRequest request, {CallOptions? options}) {
    pageRequests.add(request.deepCopy());
    return response(pages!(request));
  }

  final analyses = <AnalysisRequest>[],
      pendingAnalyses = <Completer<Analysis>>[];
  int cancelledAnalyses = 0;
  final analysisOptions = <CallOptions?>[];
  @override
  ResponseFuture<Analysis> completeSql(
    AnalysisRequest request, {
    CallOptions? options,
  }) => analyze(request, options: options);
  @override
  ResponseFuture<Analysis> diagnoseSql(
    AnalysisRequest request, {
    CallOptions? options,
  }) => analyze(request, options: options);
  @override
  ResponseFuture<Analysis> sqlParameterInformation(
    AnalysisRequest request, {
    CallOptions? options,
  }) => analyze(request, options: options);
  @override
  ResponseFuture<Analysis> formatSql(
    AnalysisRequest request, {
    CallOptions? options,
  }) => analyze(request, options: options);
  @override
  ResponseFuture<Analysis> resolveSqlSymbol(
    AnalysisRequest request, {
    CallOptions? options,
  }) => analyze(request, options: options);
  @override
  ResponseFuture<Analysis> sqlDdlImpact(
    AnalysisRequest request, {
    CallOptions? options,
  }) => analyze(request, options: options);
  ResponseFuture<Analysis> analyze(
    AnalysisRequest request, {
    CallOptions? options,
  }) {
    analyses.add(request.deepCopy());
    analysisOptions.add(options);
    final pending = Completer<Analysis>();
    pendingAnalyses.add(pending);
    return response(pending.future, onCancel: () => cancelledAnalyses++);
  }

  void completeAnalysis(
    int index, {
    String formatted = 'SELECT 1;\n',
    List<Completion> completions = const [],
    ResolvedSymbol? symbol,
  }) {
    final r = analyses[index];
    pendingAnalyses[index].complete(
      Analysis(
        documentId: r.documentId,
        documentVersion: r.documentVersion,
        backendInstance: r.context.instanceId,
        sessionId: r.sessionId,
        contextRevision: r.contextRevision,
        sessionRevision: r.sessionRevision,
        caretUtf16: r.caretUtf16,
        formattedSql: formatted,
        operation: r.operation,
        metadataSourceIdentity: r.sessionId.isEmpty
            ? ''
            : fixtureMetadataSourceIdentity,
        metadataSnapshotRevision: r.sessionId.isEmpty ? Int64.ZERO : Int64.ONE,
        metadataConfigurationRevision: r.sessionId.isEmpty
            ? Int64.ZERO
            : Int64.ONE,
        formatTokens: fakeFormatTokens(r.sql, formatted),
        completions: completions,
        symbol: symbol,
      ),
    );
  }

  @override
  ResponseFuture<JobList> jobs(JobRequest request, {CallOptions? options}) {
    jobRequests.add(request.deepCopy());
    return response(
      jobPages == null ? Future.value(jobList) : jobPages!(request),
    );
  }
}

// Deterministic test responses can also change keyword case. Production maps
// come from Java's lossless lexer, which preserves every token verbatim.
List<FormatToken> fakeFormatTokens(String before, String after) {
  final result = <FormatToken>[];
  var next = 0;
  for (var index = 0; index < before.length; index++) {
    if (before[index].trim().isEmpty) continue;
    while (next < after.length && after[next].trim().isEmpty) {
      next++;
    }
    if (next >= after.length ||
        before[index].toLowerCase() != after[next].toLowerCase()) {
      return [];
    }
    result.add(
      FormatToken(
        sourceStartUtf16: index,
        sourceEndUtf16: index + 1,
        formattedStartUtf16: next++,
      ),
    );
  }
  return result;
}
