import 'dart:async';

import 'package:busydata/src/backend/backend_process.dart';
import 'package:busydata/src/backend/generated/busydata.pbgrpc.dart';
import 'package:busydata/src/backend/tool_admission_requests.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

import 'support/fake_backend.dart' show response;

class AdmissionClient extends Fake implements WorkbenchClient {
  final requests = <ToolRequest>[];
  final options = <CallOptions?>[];
  late ResponseFuture<ImportPreview> preview = response(
    Future.value(ImportPreview(sourceSha256: 'source')),
  );
  late ResponseFuture<Approval> approval = response(
    Future.value(Approval(token: 'review')),
  );
  late ResponseFuture<JobInfo> job = response(
    Future.value(JobInfo(jobId: 'job')),
  );

  void record(ToolRequest request, CallOptions? option) {
    requests.add(request);
    options.add(option);
  }

  @override
  ResponseFuture<ImportPreview> previewImport(
    ToolRequest request, {
    CallOptions? options,
  }) {
    record(request, options);
    return preview;
  }

  @override
  ResponseFuture<Approval> reviewTool(
    ToolRequest request, {
    CallOptions? options,
  }) {
    record(request, options);
    return approval;
  }

  @override
  ResponseFuture<JobInfo> tool(ToolRequest request, {CallOptions? options}) {
    record(request, options);
    return job;
  }
}

void main() {
  for (final kind in [ToolKind.IMPORT_CSV, ToolKind.IMPORT_JSON]) {
    test(
      '$kind admission budgets each source hash and preserves ownership',
      () async {
        final client = AdmissionClient();
        final request = ToolRequest(
          kind: kind,
          sessionId: 'session',
          executionId: 'once',
          sourceSha256: 'reviewed-source',
          approvalToken: 'selected-review',
        );
        expect(client.previewImportAdmission(request), same(client.preview));
        expect(client.reviewToolAdmission(request), same(client.approval));
        expect(client.toolAdmission(request), same(client.job));
        await Future.wait([client.preview, client.approval, client.job]);
        expect(client.requests, [same(request), same(request), same(request)]);
        expect(
          client.options.map((option) => option!.timeout),
          everyElement(const Duration(minutes: 5)),
        );
        final defaults = CallOptions(
          timeout: BackendProcess.rpcTimeout,
          metadata: {'x-busydata-launch': 'private-launch'},
        );
        for (final option in client.options) {
          final merged = defaults.mergedWith(option);
          expect(merged.timeout, importAdmissionTimeout);
          expect(merged.metadata['x-busydata-launch'], 'private-launch');
        }
      },
    );
  }

  test('other tools inherit the normal unary deadline', () async {
    final client = AdmissionClient();
    for (final kind in ToolKind.values.where(
      (kind) => kind != ToolKind.IMPORT_CSV && kind != ToolKind.IMPORT_JSON,
    )) {
      final request = ToolRequest(kind: kind);
      await client.reviewToolAdmission(request);
      await client.toolAdmission(request);
    }
    expect(client.options, everyElement(isNull));
    expect(BackendProcess.rpcTimeout, const Duration(seconds: 30));
  });

  test(
    'admission cancellation reaches the exact transport and never resends',
    () async {
      final client = AdmissionClient();
      final pending = Completer<JobInfo>();
      var cancelled = 0;
      client.job = response(pending.future, onCancel: () => cancelled++);
      final call = client.toolAdmission(ToolRequest(kind: ToolKind.IMPORT_CSV));
      await call.cancel();
      expect(cancelled, 1);
      expect(client.requests, hasLength(1));
      pending.completeError(const GrpcError.cancelled());
      await expectLater(call, throwsA(isA<GrpcError>()));
      expect(client.requests, hasLength(1));
    },
  );

  test(
    'an admission deadline failure is returned without retry or a job',
    () async {
      final client = AdmissionClient();
      client.job = response(Future.error(const GrpcError.deadlineExceeded()));
      await expectLater(
        client.toolAdmission(ToolRequest(kind: ToolKind.IMPORT_JSON)),
        throwsA(
          isA<GrpcError>().having(
            (error) => error.code,
            'code',
            StatusCode.deadlineExceeded,
          ),
        ),
      );
      expect(client.requests, hasLength(1));
    },
  );
}
