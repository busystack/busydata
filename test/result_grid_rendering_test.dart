import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets(
      'resize separator preserves bounds, rows and selection in $direction',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var semanticsDisposed = false;
        addTearDown(() {
          if (!semanticsDisposed) semantics.dispose();
        });
        final backend = TestBackend();
        final model = WorkbenchModel(Directory('/unused'))
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final owner = model.activeOwner;
        final result = rpc.StatementResult(
          resultId: 'resize',
          complete: true,
          fetchedRows: Int64(4),
          columns: [
            rpc.Column(name: 'id', typeName: 'int4'),
            rpc.Column(name: 'name', typeName: 'text'),
          ],
        );
        model.track(
          rpc.JobInfo(
            jobId: 'resize-job',
            executionId: 'resize-execution',
            state: rpc.JobState.COMPLETED,
            results: [result],
          ),
          documentId: owner.id,
        );
        for (var i = 0; i < 4; i++) {
          model.cache['resize:$i'] = rpc.Row(
            values: [
              rpc.Value(signedInteger: '$i'),
              rpc.Value(text: 'row $i'),
            ],
          );
        }
        await tester.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: direction,
              child: Scaffold(
                body: ResultGrid(
                  model: model,
                  controls: const LinuxControls(),
                  result: result,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final cell = find.byKey(const ValueKey('resize:0:0'));
        expect(cell, findsOneWidget);
        await tester.tap(cell);
        await tester.pumpAndSettle();
        final view = model.resultView('resize'),
            selected = (
              model.resultView('resize').selectedRow,
              model.resultView('resize').selectedColumn,
            );
        final rowHeight = tester.getSize(cell).height;
        final handle = find.bySemanticsLabel('Resize column id');
        expect(tester.getSize(handle).width, 10);
        final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
        await tester.drag(handle, Offset(80 * sign, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(cell).width, greaterThan(180));
        expect((view.selectedRow, view.selectedColumn), selected);
        expect(tester.getSize(cell).height, rowHeight);
        expect(find.text('row 3'), findsOneWidget);
        await tester.drag(handle, Offset(-1500 * sign, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(cell).width, 60);
        await tester.drag(handle, Offset(1500 * sign, 0));
        await tester.pumpAndSettle();
        expect(tester.getSize(cell).width, 800);
        expect(backend.client.executions, isEmpty);
        expect(find.byType(TableViewCell).evaluate().length, lessThan(30));
        semantics.dispose();
        semanticsDisposed = true;
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      },
    );
  }
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} column check labels toggle once and preserve one visible column without SQL',
      (tester) async {
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('grid-columns-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final owner = model.activeOwner;
        final result = rpc.StatementResult(
          resultId: 'columns-source',
          complete: true,
          columns: [
            rpc.Column(name: 'first', typeName: 'text'),
            rpc.Column(name: 'second', typeName: 'text'),
          ],
        );
        model.track(
          rpc.JobInfo(
            jobId: 'columns-job',
            results: [result],
            state: rpc.JobState.COMPLETED,
          ),
          documentId: owner.id,
        );
        final body = ResultGrid(
          model: model,
          controls: controls,
          result: result,
        );
        try {
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: body)
                : MaterialApp(home: Scaffold(body: body)),
          );
          await tester.pumpAndSettle();
          final opened = model.resultActions[owner.id]!['result.columns']!();
          await tester.pumpAndSettle();
          await tester.tap(find.text('first').last);
          await tester.pumpAndSettle();
          expect(model.resultView(result.resultId).hiddenColumns, {0});
          await tester.tap(find.text('second').last);
          await tester.pumpAndSettle();
          expect(model.resultView(result.resultId).hiddenColumns, {0});
          await tester.tap(find.text('first').last);
          await tester.pumpAndSettle();
          expect(model.resultView(result.resultId).hiddenColumns, isEmpty);
          await tester.tap(find.text('Close').last);
          await tester.pumpAndSettle();
          await opened;
          expect(backend.client.executions, isEmpty);
          expect(backend.client.viewRequests, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        }
      },
    );
    testWidgets(
      '${controls.runtimeType} compact conditions remain visible and reset without SQL',
      (tester) async {
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('grid-compact-reset-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final result = rpc.StatementResult(
          resultId: 'source',
          fetchedRows: Int64(1),
          complete: true,
          columns: [rpc.Column(name: 'n', typeName: 'text')],
        );
        model.track(
          rpc.JobInfo(
            jobId: 'job',
            results: [result],
            state: rpc.JobState.COMPLETED,
          ),
          documentId: model.activeOwner.id,
        );
        final view = model.resultView('source');
        view.conditions = [
          rpc.RowCondition(
            column: 'n',
            value: rpc.Value(text: 'visible value'),
          ),
        ];
        view.order = [rpc.RowOrder(column: 'n', descending: true)];
        backend.client.viewCreate = (_) async =>
            rpc.ResultViewInfo(viewId: 'reset', resultId: 'source');
        backend.client.pages = (_) async => rpc.Page(
          rows: [
            rpc.Row(values: [rpc.Value(text: 'visible value')]),
          ],
          fetchedRows: Int64(1),
          nextOffset: Int64(1),
          complete: true,
        );
        final body = Center(
          child: SizedBox(
            width: 750,
            height: 100,
            child: ListenableBuilder(
              listenable: model,
              builder: (_, _) =>
                  ResultGrid(model: model, controls: controls, result: result),
            ),
          ),
        );
        try {
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: body)
                : MaterialApp(home: Scaffold(body: body)),
          );
          await tester.pumpAndSettle();
          final menu = find.textContaining('More · n');
          expect(menu.hitTestable(), findsOneWidget);
          expect(tester.widget<Text>(menu).data, contains('visible value'));
          expect(tester.widget<Text>(menu).data, contains('Descending'));
          const menus = MethodChannel(nativeMenuChannelName);
          if (controls is LinuxControls) {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(menus, (call) async {
                  if (call.method != 'show') return null;
                  final entries = (call.arguments as Map)['entries'] as List;
                  final index = entries.indexWhere(
                    (e) => (e as Map)['label'] == 'Reset view',
                  );
                  expect(index, greaterThanOrEqualTo(0));
                  return index;
                });
            addTearDown(
              () => TestDefaultBinaryMessengerBinding
                  .instance
                  .defaultBinaryMessenger
                  .setMockMethodCallHandler(menus, null),
            );
          }
          await tester.tap(menu);
          await tester.pumpAndSettle();
          if (controls is WindowsControls) {
            await tester.tap(find.text('Reset view').hitTestable());
            await tester.pumpAndSettle();
          }
          expect(backend.client.viewRequests.single.conditions, isEmpty);
          expect(backend.client.viewRequests.single.order, isEmpty);
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        }
      },
    );
    testWidgets(
      '${controls.runtimeType} compact retained grid traverses distant rows without eager layout or SQL',
      (tester) async {
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('grid-rendering-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final semantics = tester.ensureSemantics();
        final result = rpc.StatementResult(
          resultId: 'retained',
          fetchedRows: Int64(10000),
          complete: true,
          columns: [rpc.Column(name: 'n', typeName: 'text')],
        );
        model.track(
          rpc.JobInfo(
            jobId: 'job',
            executionId: 'execution',
            state: rpc.JobState.COMPLETED,
            results: [result],
          ),
          documentId: model.activeOwner.id,
        );
        backend.client.pages = (request) async {
          final count = (10000 - request.offset.toInt()).clamp(
            0,
            request.limit,
          );
          return rpc.Page(
            firstOffset: request.offset,
            nextOffset: request.offset + Int64(count),
            fetchedRows: Int64(10000),
            complete: true,
            rows: [
              for (var i = 0; i < count; i++)
                rpc.Row(
                  values: [
                    rpc.Value(text: 'cell-${request.offset.toInt() + i}'),
                  ],
                ),
            ],
          );
        };
        final body = Center(
          child: SizedBox(
            width: 750,
            height: 300,
            child: ListenableBuilder(
              listenable: model,
              builder: (context, _) =>
                  ResultGrid(model: model, controls: controls, result: result),
            ),
          ),
        );
        try {
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: body)
                : MaterialApp(home: Scaffold(body: body)),
          );
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          expect(find.text('cell-0'), findsOneWidget);
          expect(find.byType(TableViewCell).evaluate().length, lessThan(60));
          await tester.tap(find.text('cell-0'));
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.end);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          final end = tester
              .getSemantics(find.bySemanticsLabel('Row 10000, n: cell-9999'))
              .getSemanticsData();
          expect(end.flagsCollection.isFocused, Tristate.isTrue);
          expect(end.flagsCollection.isSelected, Tristate.isTrue);
          expect(model.resultView('retained').selectedRow, 9999);
          expect(find.byType(TableViewCell).evaluate().length, lessThan(60));
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.home);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          expect(find.text('cell-0'), findsOneWidget);
          expect(model.resultView('retained').selectedRow, 0);
          expect(model.cacheBytes, lessThanOrEqualTo(2 * 1024 * 1024));
          expect(backend.client.executions, isEmpty);
          expect(model.currentJob?.executionId, 'execution');
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        }
      },
    );
  }
}
