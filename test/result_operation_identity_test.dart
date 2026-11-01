import 'dart:io';

import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// Capture the menu's operation boundary; native popup delivery has separate
// acceptance coverage. Selection still follows the real cell pointer path.
mixin _CaptureResultMenus on DesktopControls {
  List<DesktopMenuAction> currentActions = [];
  @override
  Widget contextMenu(Widget child, List<DesktopMenuAction> actions) => Listener(
    onPointerDown: (event) {
      if (event.buttons == kSecondaryButton) currentActions = actions;
    },
    child: child,
  );
}

class _LinuxResultControls extends LinuxControls with _CaptureResultMenus {}

class _WindowsResultControls extends WindowsControls with _CaptureResultMenus {}

void main() {
  for (final windows in [false, true]) {
    for (final tableData in [false, true]) {
      testWidgets(
        '${windows ? 'Fluent' : 'Yaru'} ${tableData ? 'server' : 'local'} cell operations use exact column identity and captured owner',
        (tester) async {
          final controls = windows
              ? _WindowsResultControls()
              : _LinuxResultControls();
          final menus = controls;
          final backend = TestBackend();
          final model = WorkbenchModel(Directory('/unused-result-identity'))
            ..draftRecovery = false
            ..backend = backend
            ..newDocument();
          final owner = tableData
              ? model.openTask(
                  WorkbenchDocumentKind.table,
                  'owned table',
                  reuse: false,
                  object: DatabaseObjectIdentity(
                    profileId: 'source',
                    catalog: 'db',
                    schema: 'public',
                    kind: rpc.ObjectKind.TABLE,
                    name: 'owned table',
                  ),
                )
              : model.activeOwner;
          final result = rpc.StatementResult(
            resultId: 'source-result',
            complete: true,
            fetchedRows: Int64.ONE,
            columns: [
              for (var index = 0; index < 2; index++)
                rpc.Column(
                  name: 'duplicate',
                  ordinal: index + 1,
                  baseColumn: index == 0 ? 'left raw' : 'right"raw',
                  typeName: 'numeric',
                  jdbcType: 2,
                ),
            ],
          );
          model.track(
            rpc.JobInfo(
              jobId: 'source-job',
              executionId: 'source-execution',
              state: rpc.JobState.COMPLETED,
              results: [result],
            ),
            documentId: owner.id,
          );
          final exact = rpc.Value(decimal: '12345678901234567890.1200');
          model.cache['source-result:0'] = rpc.Row(
            values: [
              rpc.Value(nullValue: rpc.Null()),
              exact,
            ],
          );
          final browses = <WorkbenchCommandContext>[];
          model.commands = WorkbenchCommandRegistry([
            for (final id in [
              'result.presentation.table',
              'result.presentation.transpose',
              'result.presentation.tree',
              'result.presentation.text',
              'result.record',
              'result.displayFormat',
              'result.aggregate',
              'result.related',
              'result.clone',
              'result.inserts',
              'result.details',
              'result.filter',
              'result.sort',
              'result.columns',
              'result.refresh',
              'result.reset',
              'result.assess',
              'result.provenance',
              'result.copy',
              'result.inspect',
              'edit.insert',
              'edit.update',
              'edit.delete',
              'edit.apply',
              'edit.discard',
              'transfer.retained',
            ])
              WorkbenchCommand(
                id: id,
                label: id,
                category: 'Results',
                invoke: (_) => fail('Unexpected command: $id'),
              ),
            WorkbenchCommand(
              id: 'object.refresh',
              label: 'Refresh',
              category: 'Object',
              invoke: (context) {
                browses.add(context);
                owner.view.tableOrder = context.tableOrder!;
              },
            ),
          ]);
          var viewSequence = 0;
          backend.client.viewCreate = (request) async => rpc.ResultViewInfo(
            resultId: request.resultId,
            viewId: 'view-${++viewSequence}',
            sourceRows: Int64.ONE,
            visibleRows: Int64.ONE,
          );
          await tester.binding.setSurfaceSize(const Size(1100, 800));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            await tester.binding.setSurfaceSize(null);
          });
          final grid = ResultGrid(
            model: model,
            controls: controls,
            result: result,
          );
          await tester.pumpWidget(
            windows
                ? fluent.FluentApp(home: grid)
                : MaterialApp(home: Scaffold(body: grid)),
          );
          await tester.pumpAndSettle();
          model.newDocument();
          final other = model.activeOwner;
          final header = find.byKey(const ValueKey('source-result:-1:1'));
          for (var descending = 0; descending < 2; descending++) {
            await tester.tap(header);
            await tester.pumpAndSettle();
            final order = tableData
                ? browses.last.tableOrder!
                : backend.client.viewRequests.last.order;
            expect(order.single.column, tableData ? 'right"raw' : '#2');
            expect(order.single.descending, descending == 1);
          }
          await tester.tap(
            find.byKey(const ValueKey('source-result:0:1')),
            buttons: kSecondaryButton,
          );
          await tester.pumpAndSettle();
          final filter = menus.currentActions.singleWhere(
            (action) => action.label == 'Filter by this value',
          );
          expect(filter.disabledReason, isNull);
          filter.invoke();
          await tester.pumpAndSettle();
          final condition = tableData
              ? browses.last.tableConditions!.single
              : backend.client.viewRequests.last.conditions.single;
          expect(condition.column, tableData ? 'right"raw' : '#2');
          expect(condition.predicate, rpc.ValuePredicate.EQUAL);
          expect(condition.value, exact);
          if (tableData) {
            expect(browses, hasLength(3));
            expect(
              browses.every((context) => identical(context.owner, owner)),
              isTrue,
            );
            expect(backend.client.viewRequests, isEmpty);
          } else {
            expect(backend.client.viewRequests, hasLength(3));
            expect(
              backend.client.viewRequests.every(
                (request) => request.resultId == result.resultId,
              ),
              isTrue,
            );
            expect(browses, isEmpty);
          }
          expect(other.view.results, isEmpty);
          expect(model.activeOwner, same(other));
          expect(backend.client.executions, isEmpty);
          expect(model.editBatches, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
