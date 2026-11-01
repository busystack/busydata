import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  late Directory root;
  late WorkbenchModel model;
  late TestBackend backend;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('busydata-retained-');
    backend = TestBackend();
    model = WorkbenchModel(root)
      ..draftRecovery = false
      ..newDocument();
    model.backend = backend;
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });
  RetainedResult retained(String id, String doc) => RetainedResult(
    jobId: 'evicted',
    executionId: 'old-execution',
    documentId: doc,
    sessionId: 'disconnected',
    state: JobState.COMPLETED,
    target: Profile(
      engine: Engine.POSTGRESQL,
      host: 'localhost',
      database: 'context_at_execution',
    ),
    result: StatementResult(
      resultId: id,
      columns: [Column(name: 'actual')],
      fetchedRows: Int64(1),
      complete: true,
    ),
  );
  test(
    'owned presentation shares acknowledged metadata without mutable aliases',
    () {
      final original = JobInfo(
        jobId: 'job',
        executionId: 'execution',
        state: JobState.FETCHING,
        target: Profile(id: 'source', name: 'Original source'),
        results: [
          StatementResult(
            resultId: 'result',
            columns: [Column(name: 'n')],
          ),
        ],
      );
      model.track(original, documentId: model.document.id);
      final first = model.currentJob!;
      final second = model.currentJob!;
      expect(
        second,
        same(first),
        reason: 'Reads reuse the acknowledged job snapshot.',
      );
      expect(first.target, same(original.target));
      expect(second.target, same(first.target));
      expect(
        first.results.single.columns.single,
        same(original.results.single.columns.single),
      );
      expect(first.isFrozen, isTrue);
      expect(() => first.target.name = 'Changed', throwsUnsupportedError);
      expect(original.target.name, 'Original source');
      expect(model.documentJobs.single.executionId, 'execution');
      expect(backend.client.executions, isEmpty);
    },
  );

  test(
    'retained presentation overlays an independent results list and preserves the source summary',
    () {
      final original = JobInfo(
        jobId: 'evicted',
        executionId: 'old-execution',
        state: JobState.FETCHING,
        target: Profile(name: 'Acknowledged source'),
        messages: ['Original progress'],
        results: [StatementResult(resultId: 'result')],
      );
      model.track(original, documentId: model.document.id);
      final entry = retained('result', model.document.id);
      model.retainedResults['result'] = entry;
      final view = model.currentJob!;
      expect(view.results.single, same(entry.result));
      expect(view.results.single.columns.single.name, 'actual');
      expect(original.results.single.columns, isEmpty);
      expect(original.messages, ['Original progress']);
      expect(() => view.results.clear(), throwsUnsupportedError);
      model.retainedResults.remove('result');
      expect(model.currentJob!.results.single.columns, isEmpty);
      model.jobs.remove('evicted');
      model.retainedResults['result'] = entry;
      expect(model.currentJob!.results.single.columns.single.name, 'actual');
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'a fresh acknowledgement replaces the snapshot while old output stays immutable',
    () async {
      final owner = model.activeOwner;
      model.track(
        JobInfo(
          jobId: 'job',
          executionId: 'execution',
          state: JobState.FETCHING,
          results: [
            StatementResult(
              resultId: 'result',
              columns: [Column(name: 'old')],
            ),
          ],
        ),
        documentId: owner.id,
      );
      final old = model.currentJob!;
      final metadata = RetainedResult(
        jobId: 'job',
        executionId: 'execution',
        documentId: owner.id,
        state: JobState.COMPLETED,
        result: StatementResult(
          resultId: 'result',
          complete: true,
          fetchedRows: Int64(200),
          columns: [Column(name: 'acknowledged')],
        ),
      );
      backend.client.retained = RetainedList(
        results: [metadata],
        complete: true,
      );
      backend.client.jobList = JobList(
        catalogRevision: Int64.ONE,
        complete: true,
        jobs: [
          JobInfo(
            jobId: 'job',
            executionId: 'execution',
            state: JobState.COMPLETED,
            results: [StatementResult(resultId: 'result')],
          ),
        ],
      );
      await model.poll();
      final current = model.currentJob!;
      expect(current, isNot(same(old)));
      expect(model.currentJob, same(current));
      expect(current.results.single, same(metadata.result));
      expect(current.state, JobState.COMPLETED);
      expect(current.results.single.fetchedRows, Int64(200));
      expect(old.state, JobState.FETCHING);
      expect(old.results.single.columns.single.name, 'old');
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'catalog expiry releases empty inspection state while preserving owned recovery and unknown work',
    () async {
      final owner = model.activeOwner;
      model.batchFor(owner, 'obsolete');
      final recovering = model.batchFor(owner, 'recovery')
        ..sessionId = 'source'
        ..draftId = 'record';
      final unknown = model.batchFor(owner, 'uncertain')..outcomeUnknown = true;
      owner.view.results['obsolete'] = ResultViewState()..widths[0] = 300;
      model.disposedResults.add('obsolete');
      await model.poll();
      expect(model.editBatches.values, containsAll([recovering, unknown]));
      expect(
        model.editBatches.values.any((b) => b.resultId == 'obsolete'),
        isFalse,
      );
      expect(owner.view.results.containsKey('obsolete'), isFalse);
      expect(model.disposedResults, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'F11 results remain selectable and fetch real cells after their job summary is evicted',
    () async {
      final first = retained('result', model.document.id);
      backend.client.retained = RetainedList(results: [first], complete: true);
      model.latestExecutions[model.document.id] = 'old-execution';
      await model.poll();
      expect(model.jobs, isEmpty);
      expect(model.documentJobs.single.executionId, 'old-execution');
      expect(model.currentResult?.resultId, 'result');
      backend.client.pages = (r) async => Page(
        firstOffset: r.offset,
        nextOffset: r.offset + Int64(1),
        fetchedRows: Int64(1),
        rows: [
          Row(values: [Value(text: 'verified retained cell')]),
        ],
      );
      final notification = Completer<void>();
      void listener() {
        if (!notification.isCompleted) notification.complete();
      }

      model.addListener(listener);
      model.row('result', 0);
      await notification.future.timeout(const Duration(seconds: 5));
      model.removeListener(listener);
      expect(
        model.row('result', 0)?.values.single.text,
        'verified retained cell',
      );
      model.selectExecution('old-execution');
      expect(model.currentResult?.columns.single.name, 'actual');
    },
  );
  test(
    'closed-document results stay globally reachable and opening them executes no SQL or connection',
    () async {
      final entry = retained('result', 'closed-document');
      backend.client.retained = RetainedList(results: [entry], complete: true);
      await model.poll();
      expect(model.documentJobs, isEmpty);
      model.openRetainedResult(entry);
      expect(model.currentResult?.resultId, 'result');
      expect(model.document.sessionId, isNull);
      expect(backend.client.opened, isEmpty);
      expect(model.document.editor.text, isEmpty);
    },
  );
  test(
    'staged work prevents disposal and pending disposal remains visible for cleanup',
    () async {
      final entry = retained('result', model.document.id)
        ..disposalPending = true
        ..availability = 'Disposal waits for active readers';
      backend.client.retained = RetainedList(results: [entry], complete: true);
      await model.poll();
      expect(model.retainedResults['result']?.disposalPending, isTrue);
      model.openRetainedResult(entry);
      expect(model.documents.length, 1);
      model.stagedResult = 'result';
      model.staged.add(StagedChange());
      await expectLater(
        model.disposeRetainedResult('result'),
        throwsStateError,
      );
      expect(model.disposedResults, isEmpty);
    },
  );
}
