import 'dart:io';

import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/result_presentation.dart';
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
    for (final replacement in [
      'none',
      'same',
      'other',
      'columns',
      'disposed',
      'view',
      'owner',
      'reused',
      'backend',
      'late-catalog',
      'forged-catalog',
      'catalog-summary',
      'catalog-reused',
      'catalog-schema',
    ]) {
      testWidgets(
        '${controls.runtimeType} applies temporal display to the retained grid '
        'with replacement $replacement',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final backend = TestBackend();
          final model = WorkbenchModel(Directory('/unused'))
            ..draftRecovery = false
            ..backend = backend
            ..newDocument();
          final owner = model.activeOwner;
          var result = rpc.StatementResult(
            resultId: 'format-result',
            fetchedRows: Int64.ONE,
            complete: true,
            columns: [
              rpc.Column(
                name: 'observed',
                ordinal: 1,
                typeName: 'timestamp',
                jdbcType: 93,
              ),
            ],
          );
          model.track(
            rpc.JobInfo(
              jobId: 'job',
              executionId: 'execution',
              state: rpc.JobState.COMPLETED,
              results: [result],
            ),
            documentId: owner.id,
          );
          final original = rpc.Value(
            temporal: rpc.Temporal(iso: '2026-10-24T13:14:15.123456'),
          );
          model.cache['format-result:0'] = rpc.Row(values: [original]);
          rpc.RetainedResult retained() => rpc.RetainedResult(
            result: result.deepCopy(),
            jobId: 'job',
            executionId: 'execution',
            documentId: owner.id,
            createdUnixMs: Int64.ONE,
          );
          if (replacement.startsWith('catalog-')) {
            model.retainedResults[result.resultId] = retained();
          }
          final view = model.resultView('format-result', owner: owner);
          view.presentation.formats[0] = ColumnDisplayFormat.temporalPattern;
          late VoidCallback replace;
          final body = StatefulBuilder(
            builder: (context, update) {
              replace = () => update(() {
                result = result.deepCopy();
                switch (replacement) {
                  case 'other':
                    result.resultId = 'different-result';
                    model.cache['different-result:0'] = rpc.Row(
                      values: [original],
                    );
                  case 'columns':
                    result.columns[0].metadataIdentity = 'different-column';
                  case 'disposed':
                    model.disposedResults.add(result.resultId);
                  case 'view':
                    view.retainedView = rpc.ResultViewInfo(
                      viewId: 'new-view',
                      resultId: result.resultId,
                    );
                  case 'owner':
                    owner.sql!.version++;
                  case 'reused':
                    model.track(
                      rpc.JobInfo(
                        jobId: 'job',
                        executionId: 'reused',
                        state: rpc.JobState.COMPLETED,
                        results: [result],
                      ),
                      documentId: owner.id,
                    );
                  case 'backend':
                    model.backend = TestBackend();
                  case 'late-catalog':
                    model.retainedResults[result.resultId] = retained();
                  case 'forged-catalog':
                    model.retainedResults[result.resultId] = retained()
                      ..documentId = 'another-owner';
                  case 'catalog-summary':
                    model.retainedResults[result.resultId] = retained()
                      ..leases = 2;
                  case 'catalog-reused':
                    model.retainedResults[result.resultId] = retained()
                      ..executionId = 'reused';
                  case 'catalog-schema':
                    model.retainedResults[result.resultId] = retained()
                      ..sourceSchema = 'another-schema';
                }
              });
              return ResultGrid(
                model: model,
                controls: controls,
                result: result,
              );
            },
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: body)
                : MaterialApp(home: Scaffold(body: body)),
          );
          await tester.pumpAndSettle();
          final pending =
              model.resultActions[owner.id]!['result.displayFormat']!();
          await tester.pumpAndSettle();
          if (replacement != 'none') {
            replace();
            await tester.pumpAndSettle();
          }
          await tester.enterText(
            find.byWidgetPredicate(
              (widget) => widget is EditableText && !widget.readOnly,
            ),
            'dd/MM/yyyy HH:mm:ss.SSSSSS',
          );
          await tester.tap(find.text('Apply'));
          await tester.pumpAndSettle();
          await pending;
          final accepted = const {
            'none',
            'same',
            'late-catalog',
            'catalog-summary',
          }.contains(replacement);
          expect(
            find.text('24/10/2026 13:14:15.123456'),
            accepted ? findsOneWidget : findsNothing,
          );
          expect(
            view.presentation.temporalPatterns[0]?.pattern,
            accepted ? 'dd/MM/yyyy HH:mm:ss.SSSSSS' : null,
          );
          expect(original.temporal.iso, '2026-10-24T13:14:15.123456');
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        },
      );
    }
  }
}
