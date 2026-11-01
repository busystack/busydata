import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} renders completed result after column metadata arrives',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-metadata-grid-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        model.track(
          rpc.JobInfo(
            jobId: 'plan-job',
            executionId: 'plan-execution',
            state: rpc.JobState.COMPLETED,
            results: [
              rpc.StatementResult(
                resultId: 'plan-result',
                fetchedRows: Int64.ONE,
                complete: true,
              ),
            ],
          ),
        );
        backend.client.pages = (request) async => rpc.Page(
          firstOffset: Int64.ZERO,
          nextOffset: Int64.ONE,
          fetchedRows: Int64.ONE,
          complete: true,
          rows: [
            rpc.Row(
              values: [rpc.Value(text: '{"Plan":{"Node Type":"Index Scan"}}')],
            ),
          ],
        );
        Widget grid() => SizedBox(
          width: 750,
          height: 400,
          child: ResultGrid(
            key: const ValueKey('plan-result'),
            model: model,
            controls: controls,
            result: model.currentResult!,
          ),
        );
        Widget body() => ListenableBuilder(
          listenable: model,
          builder: (context, _) => grid(),
        );
        Widget app() => controls is WindowsControls
            ? fluent.FluentApp(home: body())
            : MaterialApp(home: Scaffold(body: body()));
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(model.currentResult!.columns, isEmpty);
        expect(backend.client.pageRequests, isEmpty);
        model.retainedResults['plan-result'] = rpc.RetainedResult(
          jobId: 'plan-job',
          executionId: 'plan-execution',
          result: rpc.StatementResult(
            resultId: 'plan-result',
            fetchedRows: Int64.ONE,
            complete: true,
            columns: [rpc.Column(name: 'QUERY PLAN', typeName: 'json')],
          ),
        );
        model.updateStatus('Retained plan metadata received');
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(find.text('QUERY PLAN'), findsOneWidget);
        expect(find.text('json'), findsOneWidget);
        expect(
          find.text('{"Plan":{"Node Type":"Index Scan"}}'),
          findsOneWidget,
        );
        expect(backend.client.pageRequests, hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
