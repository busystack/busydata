import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  test(
    'each historical execution preserves its result tab and output surface',
    () async {
      final root = await Directory.systemTemp.createTemp('execution-output-');
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument();
      final owner = model.activeOwner;
      model.track(
        JobInfo(
          jobId: 'a',
          executionId: 'a',
          results: [
            StatementResult(resultId: 'a1'),
            StatementResult(resultId: 'a2'),
          ],
        ),
        documentId: owner.id,
      );
      model.selectedResults[owner.id] = 'a1';
      owner.view.output = 'messages';
      model.track(
        JobInfo(
          jobId: 'b',
          executionId: 'b',
          results: [
            StatementResult(resultId: 'b1'),
            StatementResult(resultId: 'b2'),
          ],
        ),
        documentId: owner.id,
      );
      // Track does not select completion. Explicit user selection does.
      model.selectedExecutions[owner.id] = 'a';
      model.selectExecution('b', owner: owner);
      expect(owner.view.output, 'results');
      model.selectedResults[owner.id] = 'b2';
      model.selectExecution('a', owner: owner);
      expect(owner.view.output, 'messages');
      expect(model.resultForOwner(owner)!.resultId, 'a1');
      model.selectExecution('b', owner: owner);
      expect(model.resultForOwner(owner)!.resultId, 'b2');
      model.dispose();
      await root.delete(recursive: true);
    },
  );
  for (final chooseHistory in [false, true]) {
    test(
      'table replacement retains prior rows until available; history selection=$chooseHistory',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'table-replacement-',
        );
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument();
        model.backend = backend;
        final owner = model.openTask(
          WorkbenchDocumentKind.table,
          't',
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'db',
            schema: 'public',
            kind: ObjectKind.TABLE,
            name: 't',
          ),
        );
        final old = JobInfo(
          jobId: 'old',
          executionId: 'old-execution',
          state: JobState.COMPLETED,
          results: [
            StatementResult(
              resultId: 'old-rows',
              complete: true,
              fetchedRows: Int64.ONE,
              columns: [Column(name: 'id')],
            ),
          ],
        );
        var fresh = JobInfo(
          jobId: 'fresh',
          executionId: 'fresh-execution',
          state: JobState.QUEUED,
        );
        model.track(old, documentId: owner.id);
        model.selectedExecutions[owner.id] = old.executionId;
        model.browseReplacements[owner.id] = (
          execution: fresh.executionId,
          previous: old.executionId,
          selectionRevision: owner.view.executionSelectionRevision,
        );
        model.track(fresh, documentId: owner.id);
        backend.client.jobList = JobList(
          complete: true,
          catalogRevision: Int64.ONE,
          jobs: [old, fresh],
        );
        await model.poll();
        expect(model.resultForOwner(owner)!.resultId, 'old-rows');
        if (chooseHistory) model.selectExecution(old.executionId, owner: owner);
        // Metadata without rows is not a replacement snapshot yet.
        // Each backend reply is a new snapshot; displayed nested metadata is
        // immutable rather than an alias through which the fake server updates.
        fresh = fresh.deepCopy()..state = JobState.FETCHING;
        fresh.results.add(
          StatementResult(
            resultId: 'fresh-rows',
            columns: [Column(name: 'id')],
          ),
        );
        backend.client.jobList = JobList(
          complete: true,
          catalogRevision: Int64.ONE,
          jobs: [old, fresh],
        );
        await model.poll();
        expect(model.resultForOwner(owner)!.resultId, 'old-rows');
        model.resultView('old-rows', owner: owner).selectedRow = 17;
        fresh = fresh.deepCopy()..state = JobState.COMPLETED;
        fresh.results.single.complete = true;
        backend.client.jobList = JobList(
          complete: true,
          catalogRevision: Int64.ONE,
          jobs: [old, fresh],
        );
        await model.poll();
        expect(
          model.resultForOwner(owner)!.resultId,
          chooseHistory ? 'old-rows' : 'fresh-rows',
        );
        expect(model.browseReplacements, isEmpty);
        model.selectExecution(old.executionId, owner: owner);
        expect(model.resultView('old-rows', owner: owner).selectedRow, 17);
        expect(backend.client.executions, isEmpty);
        model.dispose();
        await root.delete(recursive: true);
      },
    );
  }
}
