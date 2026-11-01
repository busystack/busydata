import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pbgrpc.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'support/fake_backend.dart';
import 'value_editor_test_actions.dart';

class ValueClient extends TestClient {
  final pending = Completer<rpc.ValueChunk>();
  final reads = <rpc.ValueRequest>[];
  @override
  ResponseFuture<rpc.ValueChunk> resultValue(
    rpc.ValueRequest request, {
    CallOptions? options,
  }) {
    reads.add(request.deepCopy());
    return response(pending.future);
  }
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final change in [
      'equivalent',
      'columns',
      'view',
      'schema',
      'disposed',
      'backend',
      'reused',
      'disconnected',
    ]) {
      testWidgets(
        '${controls.runtimeType} Value Editor retained owner $change',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final client = ValueClient(),
              backend = TestBackend(client: ValueClient());
          final connected = TestBackend(client: client);
          final model = WorkbenchModel(Directory('/unused'))
            ..draftRecovery = false
            ..backend = change == 'disconnected' ? null : connected
            ..newDocument();
          final owner = model.activeOwner;
          var result = rpc.StatementResult(
            resultId: 'owned-result',
            fetchedRows: Int64.ONE,
            complete: true,
            columns: [
              rpc.Column(
                name: 'value',
                ordinal: 1,
                typeName: 'text',
                metadataIdentity: 'column-1',
              ),
            ],
          );
          final original = rpc.Value(
            text: 'pre',
            valueId: 'cell-1',
            truncated: true,
            originalBytes: Int64(6),
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
          model.cache['owned-result:0'] = rpc.Row(values: [original]);
          model.retainedResults[result.resultId] = rpc.RetainedResult(
            result: result.deepCopy(),
            jobId: 'job',
            executionId: 'execution',
            documentId: owner.id,
            createdUnixMs: Int64.ONE,
            sourceSchema: 'source',
          );
          final view = model.resultView(result.resultId, owner: owner);
          late VoidCallback replace;
          final body = StatefulBuilder(
            builder: (context, update) {
              replace = () => update(() {
                result = result.deepCopy();
                switch (change) {
                  case 'equivalent':
                    model.retainedResults[result.resultId] =
                        model.retainedResults[result.resultId]!.deepCopy()
                          ..leases = 2;
                  case 'columns':
                    result.columns[0].metadataIdentity = 'replaced';
                  case 'view':
                    view.retainedView = rpc.ResultViewInfo(
                      viewId: 'new-generation',
                      resultId: result.resultId,
                    );
                  case 'schema':
                    model.retainedResults[result.resultId] =
                        model.retainedResults[result.resultId]!.deepCopy()
                          ..sourceSchema = 'changed';
                  case 'disposed':
                    model.disposedResults.add(result.resultId);
                  case 'backend':
                    model.backend = backend;
                  case 'reused':
                    model.retainedResults[result.resultId] =
                        model.retainedResults[result.resultId]!.deepCopy()
                          ..executionId = 'reused';
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
          model.resultActions[owner.id]!['result.inspect']!();
          await tester.pumpAndSettle();
          expect(find.text('pre'), findsWidgets);
          if (change == 'disconnected') {
            expect(
              find.textContaining('Retained data unavailable'),
              findsOneWidget,
            );
            expect(client.reads, isEmpty);
          } else {
            await valueEditorAction(tester, controls, 'Load next 64 KiB');
            expect(client.reads, hasLength(1));
            expect(client.reads.single.resultId, 'owned-result');
            expect(client.reads.single.valueId, 'cell-1');
            replace();
            await tester.pumpAndSettle();
            client.pending.complete(
              rpc.ValueChunk(
                data: utf8.encode('prefix'),
                totalBytes: Int64(6),
                complete: true,
              ),
            );
            await tester.pumpAndSettle();
            expect(
              find.text('prefix'),
              change == 'equivalent' ? findsOneWidget : findsNothing,
            );
            if (change != 'equivalent') {
              expect(find.text('pre'), findsWidgets);
              expect(find.textContaining('context'), findsOneWidget);
            }
          }
          expect(original.text, 'pre');
          expect(client.executions, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        },
      );
    }
  }
}
