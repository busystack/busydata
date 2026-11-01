import 'dart:convert';
import 'dart:io';

import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_cell_identity.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

import 'support/fake_backend.dart';

const _prefix = 'busydata.result.cell.v1:';

List<dynamic> _identity(
  WidgetTester tester,
  String result,
  int row,
  int column,
) {
  final data = tester
      .getSemantics(find.byKey(ValueKey('$result:$row:$column')))
      .getSemanticsData();
  expect(data.identifier, startsWith(_prefix));
  return jsonDecode(data.identifier.substring(_prefix.length)) as List<dynamic>;
}

void main() {
  test(
    'cell identity serializes only opaque handles and exact coordinates',
    () {
      final identifier = resultCellSemanticsIdentifier(
        ownerDocumentId: 'document:"\\😀',
        sourceResultId: 'source:\n漢',
        displayResultId: 'view:source',
        row: 17,
        column: 9,
      );
      expect(
        identifier,
        '$_prefix["document:\\"\\\\😀","source:\\n漢","view:source",17,9]',
      );
      expect(jsonDecode(identifier.substring(_prefix.length)), [
        'document:"\\😀',
        'source:\n漢',
        'view:source',
        17,
        9,
      ]);
    },
  );

  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} actual cell identity distinguishes source, view and document',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1100, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        final backend = TestBackend();
        final model = WorkbenchModel(Directory('/unused'))
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final firstOwner = model.activeOwner;
        rpc.StatementResult result(String id) => rpc.StatementResult(
          resultId: id,
          complete: true,
          fetchedRows: Int64(2),
          columns: [
            rpc.Column(name: 'id', ordinal: 1, typeName: 'int4'),
            rpc.Column(name: 'n', ordinal: 2, typeName: 'text'),
          ],
        );
        void retain(rpc.StatementResult source, String execution) {
          model.track(
            rpc.JobInfo(
              jobId: 'job-$execution',
              executionId: execution,
              state: rpc.JobState.COMPLETED,
              results: [source],
            ),
            documentId: model.activeOwner.id,
          );
          for (var row = 0; row < 2; row++) {
            model.cache['${source.resultId}:$row'] = rpc.Row(
              values: [
                rpc.Value(signedInteger: '${row + 1}'),
                rpc.Value(text: row == 0 ? '漢😀' : 'second'),
              ],
            );
          }
        }

        Future<void> render() async {
          final grid = ResultGrid(
            key: ValueKey(model.activeOwner.id),
            model: model,
            controls: controls,
            result: model.displayResultForOwner(model.activeOwner)!,
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: grid)
                : MaterialApp(home: Scaffold(body: grid)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        try {
          final source = result('base-first');
          retain(source, 'original');
          await render();
          expect(_identity(tester, 'base-first', 0, 0), [
            firstOwner.id,
            'base-first',
            'base-first',
            0,
            0,
          ]);
          expect(_identity(tester, 'base-first', 1, 1), [
            firstOwner.id,
            'base-first',
            'base-first',
            1,
            1,
          ]);
          final initial = tester
              .getSemantics(find.byKey(const ValueKey('base-first:0:1')))
              .getSemanticsData();
          expect(initial.label, 'Row 1, n: 漢😀');
          expect(initial.hint, contains('text'));
          expect(
            tester
                .getSemantics(find.byKey(const ValueKey('base-first:-1:0')))
                .getSemanticsData()
                .identifier,
            isEmpty,
          );
          final renderedCells = find.byType(TableViewCell).evaluate().length;

          backend.client.viewCreate = (request) async => rpc.ResultViewInfo(
            viewId: 'local-view',
            resultId: request.resultId,
            sourceRows: Int64(2),
            visibleRows: Int64(2),
          );
          await model.createResultView(
            [],
            [rpc.RowOrder(column: '#1')],
            targetOwner: firstOwner,
            resultId: source.resultId,
          );
          for (var row = 0; row < 2; row++) {
            model.cache['local-view:$row'] = model.cache['base-first:$row']!;
            model.sourceRowMappings['local-view:$row'] = row;
          }
          await render();
          expect(model.sourceResultId('local-view'), 'base-first');
          expect(_identity(tester, 'local-view', 0, 0), [
            firstOwner.id,
            'base-first',
            'local-view',
            0,
            0,
          ]);
          final local = tester
              .getSemantics(find.byKey(const ValueKey('local-view:0:1')))
              .getSemanticsData();
          expect(local.label, initial.label);
          expect(local.hint, initial.hint);
          expect(find.byType(TableViewCell).evaluate().length, renderedCells);

          retain(result('base-replacement'), 'server-replacement');
          await render();
          expect(_identity(tester, 'base-replacement', 0, 0), [
            firstOwner.id,
            'base-replacement',
            'base-replacement',
            0,
            0,
          ]);
          expect(find.text('漢😀'), findsOneWidget);

          model.newDocument();
          final otherOwner = model.activeOwner;
          retain(result('base-replacement'), 'other-document');
          await render();
          expect(otherOwner.id, isNot(firstOwner.id));
          expect(_identity(tester, 'base-replacement', 1, 1), [
            otherOwner.id,
            'base-replacement',
            'base-replacement',
            1,
            1,
          ]);
          expect(backend.client.executions, isEmpty);
          expect(backend.client.browseRequests, isEmpty);
          expect(backend.client.viewRequests, hasLength(1));
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          semantics.dispose();
          model.dispose();
        }
      },
    );
  }
}
