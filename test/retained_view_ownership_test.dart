import 'package:busydata/src/features/results/value_assignments.dart'
    as assignments;
import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  late Directory root;
  late WorkbenchModel model;
  late TestBackend backend;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('retained-view-owner-');
    backend = TestBackend();
    model = WorkbenchModel(root)..draftRecovery = false;
    model.newDocument();
    model.backend = backend;
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });

  test(
    'superseded view cannot overwrite newer view, switching tabs does not retarget',
    () async {
      final owner = model.activeOwner;
      final first = Completer<ResultViewInfo>(),
          second = Completer<ResultViewInfo>();
      var count = 0;
      backend.client.viewCreate = (_) =>
          count++ == 0 ? first.future : second.future;
      final a = model.createResultView(
        [],
        [],
        targetOwner: owner,
        resultId: 'source',
      );
      await Future<void>.delayed(Duration.zero);
      final b = model.createResultView(
        [],
        [RowOrder(column: '#1')],
        targetOwner: owner,
        resultId: 'source',
      );
      await Future<void>.delayed(Duration.zero);
      model.newDocument();
      second.complete(ResultViewInfo(viewId: 'newer', resultId: 'source'));
      await b;
      first.complete(ResultViewInfo(viewId: 'superseded', resultId: 'source'));
      await a;
      expect(owner.view.results['source']!.retainedView!.viewId, 'newer');
      expect(model.activeOwner.view.results, isEmpty);
      expect(backend.client.disposedViews, contains('superseded'));
      expect(backend.client.executions, isEmpty);
      expect(backend.client.viewRequests.map((r) => r.resultId), [
        'source',
        'source',
      ]);
    },
  );

  test(
    'closing typed owner disposes view; late reply also releases its lease',
    () async {
      final owner = model.openTask(WorkbenchDocumentKind.result, 'Retained');
      backend.client.viewCreate = (_) async =>
          ResultViewInfo(viewId: 'owned-view', resultId: 'source');
      await model.createResultView(
        [],
        [],
        targetOwner: owner,
        resultId: 'source',
      );
      final late = Completer<ResultViewInfo>();
      backend.client.viewCreate = (_) => late.future;
      final pending = model.createResultView(
        [],
        [],
        targetOwner: owner,
        resultId: 'source',
      );
      await Future<void>.delayed(Duration.zero);
      await model.closeTask(owner);
      late.complete(ResultViewInfo(viewId: 'late-view', resultId: 'source'));
      await pending;
      expect(
        backend.client.disposedViews,
        containsAll(['owned-view', 'late-view']),
      );
      expect(model.resultViews, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );

  test('shared batch admission rejects growth atomically across documents', () {
    final a = model.batchFor(model.activeOwner, 'a');
    model.stageChange(
      a,
      StagedChange(
        kind: ChangeKind.INSERT,
        values: ({1: Value(text: 'a' * 600000)}.entries).map(
          (entry) => MapEntry(entry.key, assignments.assignmentOf(entry.value)),
        ),
      ),
    );
    model.newDocument();
    final b = model.batchFor(model.activeOwner, 'b');
    expect(
      () => model.stageChange(
        b,
        StagedChange(
          kind: ChangeKind.INSERT,
          values: ({1: Value(text: 'b' * 600000)}.entries).map(
            (entry) =>
                MapEntry(entry.key, assignments.assignmentOf(entry.value)),
          ),
        ),
      ),
      throwsStateError,
    );
    expect(b.changes, isEmpty);
    expect(a.changes.single.values[1]!.value.text.length, 600000);
  });
}
