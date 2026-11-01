import 'dart:io';
import 'dart:ui' as dart_ui;
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/result_presentation.dart';
import 'package:busydata/src/features/results/value_assignments.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
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

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} shared views retain drafts/source/selection $direction at $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            final backend = TestBackend();
            final model = WorkbenchModel(Directory('/unused'))
              ..draftRecovery = false
              ..backend = backend
              ..newDocument();
            try {
              final owner = model.activeOwner;
              final result = rpc.StatementResult(
                resultId: 'shared',
                fetchedRows: Int64(2),
                complete: true,
                columns: [
                  for (var i = 0; i < 1000; i++)
                    rpc.Column(
                      name: 'field$i',
                      ordinal: i + 1,
                      typeName: 'text',
                    ),
                ],
              );
              model.track(
                rpc.JobInfo(
                  jobId: 'j',
                  executionId: 'e',
                  state: rpc.JobState.COMPLETED,
                  results: [result],
                ),
                documentId: owner.id,
              );
              final first = rpc.Row(
                values: [
                  for (var i = 0; i < 1000; i++) rpc.Value(text: 'raw-$i'),
                ],
              );
              final second = rpc.Row(
                values: [
                  for (var i = 0; i < 1000; i++) rpc.Value(text: 'second-$i'),
                ],
              );
              model.cache['shared:0'] = first;
              model.cache['shared:1'] = second;
              final batch = model.batchFor(owner, 'shared');
              model.stageChange(
                batch,
                rpc.StagedChange(
                  kind: rpc.ChangeKind.UPDATE,
                  sourceRow: Int64.ZERO,
                  values: {
                    1: assignmentOf(rpc.Value(text: 'staged-first')),
                  }.entries,
                ),
                original: first,
              );
              final grid = ResultGrid(
                model: model,
                controls: controls,
                result: result,
              );
              final body = Directionality(
                textDirection: direction,
                child: MediaQuery(
                  data: MediaQueryData(
                    size: const Size(1280, 900),
                    textScaler: TextScaler.linear(scale),
                    highContrast: true,
                    disableAnimations: true,
                  ),
                  child: grid,
                ),
              );
              await tester.pumpWidget(
                controls is WindowsControls
                    ? fluent.FluentApp(home: body)
                    : MaterialApp(home: Scaffold(body: body)),
              );
              await tester.pumpAndSettle();
              final view = model.resultView('shared', owner: owner);
              for (final mode in ResultPresentation.values) {
                await model.resultActions[owner
                    .id]!['result.presentation.${mode.name}']!();
                await tester.pumpAndSettle();
                expect(view.presentation.mode, mode);
                expect(view.selectedRow, 0);
                expect(view.selectedColumn, 0);
                expect(identical(model.cache['shared:0'], first), isTrue);
                expect(
                  batch.changes.single.values[1]!.value.text,
                  'staged-first',
                );
                expect(first.values.first.text, 'raw-0');
                expect(backend.client.executions, isEmpty);
                expect(
                  find.byType(TableViewCell).evaluate().length,
                  lessThan(150),
                );
                expect(tester.takeException(), isNull);
              }
              await model.resultActions[owner
                  .id]!['result.presentation.transpose']!();
              await tester.pumpAndSettle();
              expect(
                find.text('pending change · staged-first'),
                findsOneWidget,
              );
              final transposeCell = find.bySemanticsLabel(
                'Row 1, field0: staged-first',
              );
              expect(transposeCell, findsOneWidget);
              await tester.tap(transposeCell);
              await tester.pumpAndSettle();
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
              await tester.pumpAndSettle();
              expect(view.selectedColumn, 1);
              expect(view.selectedRow, 0);
              expect(
                tester
                    .getSemantics(find.bySemanticsLabel('Row 1, field1: raw-1'))
                    .getSemanticsData()
                    .flagsCollection
                    .isSelected,
                dart_ui.Tristate.isTrue,
              );
              await model.resultActions[owner.id]!['result.record']!();
              await tester.pumpAndSettle();
              expect(find.text('Record View · Row 1'), findsOneWidget);
              final recordCell = find.descendant(
                of: find.byType(ListView),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label == 'Row 1, field1: raw-1',
                ),
              );
              await tester.ensureVisible(recordCell);
              await tester.tap(recordCell);
              await tester.pumpAndSettle();
              expect(
                tester
                    .getSemantics(recordCell)
                    .getSemanticsData()
                    .flagsCollection
                    .isFocused,
                dart_ui.Tristate.isTrue,
              );
              final transposeField = find.descendant(
                of: find.byType(TableView),
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is Semantics &&
                      widget.properties.label == 'Row 1, field1: raw-1',
                ),
              );
              expect(
                tester
                    .getSemantics(transposeField)
                    .getSemanticsData()
                    .flagsCollection
                    .isFocused,
                dart_ui.Tristate.isFalse,
              );
              final nextRecord = find.text('Next record');
              await tester.ensureVisible(nextRecord);
              expect(nextRecord.hitTestable(), findsOneWidget);
              expect(
                tester.getSemantics(nextRecord).getSemanticsData().label,
                contains('Next record'),
              );
              for (var attempt = 0; attempt < 32; attempt++) {
                if (tester
                        .getSemantics(nextRecord)
                        .getSemanticsData()
                        .flagsCollection
                        .isFocused ==
                    dart_ui.Tristate.isTrue) {
                  break;
                }
                await tester.sendKeyEvent(LogicalKeyboardKey.tab);
                await tester.pumpAndSettle();
              }
              expect(
                tester
                    .getSemantics(nextRecord)
                    .getSemanticsData()
                    .flagsCollection
                    .isFocused,
                dart_ui.Tristate.isTrue,
              );
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await tester.pumpAndSettle();
              expect(view.selectedRow, 1);
              expect(find.text('Record View · Row 2'), findsOneWidget);
              expect(find.text('field999 · text'), findsNothing);
              expect(tester.takeException(), isNull);
            } finally {
              await tester.pumpWidget(const SizedBox.shrink());
              model.dispose();
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
