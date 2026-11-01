import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  test(
    'F5 a byte-shortened page eventually loads the requested real cell',
    () async {
      final root = await Directory.systemTemp.createTemp('busydata-page-');
      final backend = TestBackend(),
          model = WorkbenchModel(root)
            ..draftRecovery = false
            ..newDocument();
      model.backend = backend;
      backend.client.pages = (request) async => Page(
        columns: [Column(name: 'wide')],
        firstOffset: request.offset,
        nextOffset: request.offset + Int64(4),
        state: PageState.PAGE_BYTE_LIMIT,
        fetchedRows: Int64(100),
        complete: true,
        rows: List.generate(
          4,
          (i) => Row(
            values: [
              Value(text: 'row-${request.offset.toInt() + i} ${'x' * 131072}'),
            ],
          ),
        ),
      );
      try {
        final changed = Completer<void>();
        void listen() {
          if (!changed.isCompleted) changed.complete();
        }

        model.addListener(listen);
        model.row('result', 12);
        await changed.future.timeout(const Duration(seconds: 5));
        model.removeListener(listen);
        final cell = model.row('result', 12);
        expect(
          cell?.values.single.text.startsWith('row-12 '),
          isTrue,
          reason:
              'A page must reach the requested row without replaying the fixed prefix',
        );
        expect(model.cacheBytes, lessThanOrEqualTo(2 * 1024 * 1024));
      } finally {
        model.dispose();
        await root.delete(recursive: true);
      }
    },
  );
  group('F5 controlled paging states', () {
    late Directory root;
    late TestBackend backend;
    late WorkbenchModel model;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('busydata-pages-');
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
    Future<void> request(int row) async {
      final changed = Completer<void>();
      void listener() {
        if (!changed.isCompleted) changed.complete();
      }

      model.addListener(listener);
      model.row('r', row);
      try {
        await changed.future.timeout(const Duration(seconds: 5));
      } finally {
        model.removeListener(listener);
      }
    }

    Page data(
      PageRequest request, {
      int count = 1,
      int total = 10000,
      String prefix = 'cell',
    }) => Page(
      firstOffset: request.offset,
      nextOffset: request.offset + Int64(count),
      fetchedRows: Int64(total),
      rows: List.generate(
        count,
        (i) =>
            Row(values: [Value(text: '$prefix-${request.offset.toInt() + i}')]),
      ),
    );
    test(
      'RPC failure is visible, does not spin, and explicit retry loads the cell',
      () async {
        backend.client.pages = (_) async =>
            throw const SocketException('unavailable');
        await request(72);
        expect(model.pageErrors['r']?.retryable, isTrue);
        for (var i = 0; i < 20; i++) {
          model.row('r', 72);
        }
        expect(backend.client.pageRequests.length, 1);
        backend.client.pages = (r) async => data(r);
        model.retryResultPage('r');
        await request(72);
        expect(model.row('r', 72)?.values.single.text, 'cell-72');
        expect(model.pageErrors, isEmpty);
      },
    );
    test(
      'waiting rows resume after growth while earlier available rows remain fetchable',
      () async {
        backend.client.pages = (r) async => Page(
          firstOffset: r.offset,
          nextOffset: r.offset,
          state: PageState.PAGE_WAITING,
          fetchedRows: Int64(250),
        );
        await request(350);
        model.row('r', 350);
        expect(backend.client.pageRequests.length, 1);
        backend.client.pages = (r) async => data(r, total: 250);
        await request(201);
        expect(model.row('r', 201)?.values.single.text, 'cell-201');
        backend.client.jobList = JobList(
          complete: true,
          catalogRevision: Int64(1),
          jobs: [
            JobInfo(
              jobId: 'j',
              results: [
                StatementResult(resultId: 'r', fetchedRows: Int64(400)),
              ],
            ),
          ],
        );
        await model.poll();
        backend.client.pages = (r) async => data(r, total: 400);
        await request(350);
        expect(model.row('r', 350)?.values.single.text, 'cell-350');
      },
    );
    test(
      'zero-progress data is an error and disposed pages cannot be retried',
      () async {
        backend.client.pages = (r) async =>
            Page(firstOffset: r.offset, nextOffset: r.offset);
        await request(1);
        expect(model.pageErrors['r']?.retryable, isTrue);
        model.retryResultPage('r');
        backend.client.pages = (r) async => Page(
          firstOffset: r.offset,
          nextOffset: r.offset,
          state: PageState.PAGE_DISPOSED,
        );
        await request(1);
        expect(model.disposedResults, contains('r'));
        final calls = backend.client.pageRequests.length;
        model.retryResultPage('r');
        model.row('r', 1);
        expect(backend.client.pageRequests.length, calls);
      },
    );
    test(
      'forward and backward refetch after eviction preserves real cells and byte quota',
      () async {
        backend.client.pages = (r) async => Page(
          firstOffset: r.offset,
          nextOffset: r.offset + Int64(4),
          state: PageState.PAGE_BYTE_LIMIT,
          fetchedRows: Int64(1000),
          rows: List.generate(
            4,
            (i) => Row(
              values: [
                Value(text: 'cell-${r.offset.toInt() + i} ${'x' * 131072}'),
              ],
            ),
          ),
        );
        for (final row in [0, 200, 400, 600, 800, 0]) {
          await request(row);
          expect(
            model.row('r', row)?.values.single.text.startsWith('cell-$row '),
            isTrue,
          );
          expect(model.cacheBytes, lessThanOrEqualTo(2 * 1024 * 1024));
        }
        expect(
          backend.client.pageRequests
              .where((r) => r.offset == Int64.ZERO)
              .length,
          2,
        );
      },
    );
    test(
      'late replies after disposal or backend replacement never enter the cache',
      () async {
        final reply = Completer<Page>();
        backend.client.pages = (_) => reply.future;
        model.row('r', 1);
        model.disposedResults.add('r');
        reply.complete(data(backend.client.pageRequests.single));
        await Future<void>.delayed(Duration.zero);
        expect(model.cache, isEmpty);
        model.disposedResults.clear();
        final restarted = Completer<Page>();
        backend.client.pages = (_) => restarted.future;
        await Future<void>.delayed(Duration.zero);
        model.row('r', 1);
        model.backend = TestBackend(instanceId: 'replacement');
        restarted.complete(data(backend.client.pageRequests.last));
        await Future<void>.delayed(Duration.zero);
        expect(model.cache, isEmpty);
      },
    );
  });
}
