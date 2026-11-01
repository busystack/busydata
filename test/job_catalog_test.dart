import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  test('an older catalog cannot detach work submitted while polling', () async {
    final root = await Directory.systemTemp.createTemp(
      'busydata-catalog-race-',
    );
    final backend = TestBackend();
    final model = WorkbenchModel(root)
      ..draftRecovery = false
      ..newDocument();
    model.backend = backend;
    addTearDown(() async {
      model.dispose();
      await root.delete(recursive: true);
    });
    final first = Completer<JobList>();
    final started = Completer<void>();
    var requests = 0;
    final job = JobInfo(
      jobId: 'new-job',
      executionId: 'new-execution',
      state: JobState.QUEUED,
      results: [StatementResult(resultId: 'retained-cell')],
    );
    backend.client.jobPages = (request) {
      if (requests++ == 0) {
        started.complete();
        return first.future;
      }
      return Future.value(
        JobList(
          catalogRevision: Int64(2),
          complete: true,
          jobs: [job.deepCopy()..state = JobState.COMPLETED],
        ),
      );
    };
    final polling = model.poll();
    await started.future;
    model.track(job);
    backend.client.retained = RetainedList(
      complete: true,
      results: [
        RetainedResult(
          jobId: job.jobId,
          executionId: job.executionId,
          documentId: model.document.id,
          result: StatementResult(
            resultId: 'retained-cell',
            columns: [Column(name: 'n')],
            fetchedRows: Int64(1),
          ),
        ),
      ],
    );
    first.complete(JobList(catalogRevision: Int64(1), complete: true));
    await polling;
    expect(model.jobs[job.jobId]?.state, JobState.COMPLETED);
    expect(model.jobDocuments[job.jobId], model.document.id);
    expect(model.currentResult?.columns.single.name, 'n');
    expect(model.backendStatusVerified, isTrue);
    expect(
      requests,
      2,
      reason: 'Only the read catalog is refreshed; SQL is never replayed',
    );
  });
  test(
    'bounded summary pages progress and retain real column identity through the independent catalog',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-job-catalog-',
      );
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument();
      model.backend = backend;
      addTearDown(() async {
        model.dispose();
        await root.delete(recursive: true);
      });
      backend.client.jobPages = (request) async => JobList(
        catalogRevision: Int64(7),
        complete: request.offset == 1,
        nextOffset: request.offset + 1,
        jobs: [
          JobInfo(
            jobId: 'job-${request.offset}',
            executionId: 'execution-${request.offset}',
            state: JobState.COMPLETED,
            results: [
              StatementResult(
                resultId: 'result-${request.offset}',
                fetchedRows: Int64(1),
              ),
            ],
          ),
        ],
      );
      backend.client.retained = RetainedList(
        complete: true,
        results: [
          RetainedResult(
            jobId: 'job-0',
            executionId: 'execution-0',
            documentId: model.document.id,
            result: StatementResult(
              resultId: 'result-0',
              fetchedRows: Int64(1),
              columns: [
                Column(
                  name: 'alias',
                  baseColumn: 'actual_base',
                  ordinal: 1,
                  provenanceKnown: true,
                ),
              ],
            ),
          ),
        ],
      );
      model.latestExecutions[model.document.id] = 'execution-0';
      await model.poll();
      expect(backend.client.jobRequests.map((request) => request.offset), [
        0,
        1,
      ]);
      expect(backend.client.jobRequests.last.catalogRevision, Int64(7));
      expect(model.jobs.length, 2);
      expect(model.currentResult?.columns.single.baseColumn, 'actual_base');
    },
  );
  test(
    'zero-progress and missing-revision job replies cannot become a passing empty catalog',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-job-errors-',
      );
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument();
      model.backend = backend;
      addTearDown(() async {
        model.dispose();
        await root.delete(recursive: true);
      });
      backend.client.jobList = JobList(catalogRevision: Int64(1));
      await model.poll();
      expect(model.backendStatusVerified, isFalse);
      expect(backend.client.jobRequests.length, 1);
      backend.client.jobList = JobList(complete: true);
      await model.poll();
      expect(model.backendStatusVerified, isFalse);
    },
  );
}
