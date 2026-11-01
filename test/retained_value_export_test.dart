import 'dart:async';
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
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      'switch during picker',
      'close during picker',
      'restart during review',
      'dispose during confirmation',
      'switch during confirmation',
      'review failure',
      'export failure',
    ]) {
      testWidgets('${controls.runtimeType} retained value $scenario', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1280, 960));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-value-export-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(directory)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final original = model.document;
        // Retained values remain exportable after the source session is gone.
        model.track(
          rpc.JobInfo(
            jobId: 'source-job',
            executionId: 'source-execution',
            sessionId: 'disconnected-source',
            state: rpc.JobState.COMPLETED,
          ),
        );
        expect(original.sessionId, isNull);
        final result = rpc.StatementResult(
          resultId: 'retained-source',
          fetchedRows: Int64.ONE,
          complete: true,
          columns: [rpc.Column(name: 'n', typeName: 'text')],
        );
        model.cache['retained-source:0'] = rpc.Row(
          values: [
            rpc.Value(
              text: 'preview',
              valueId: 'retained-value',
              originalBytes: Int64(90000),
              truncated: true,
            ),
          ],
        );
        final destination = Completer<String?>();
        final review = Completer<rpc.Approval>();
        backend.client.toolReview = (_) => review.future;
        backend.client.tools = (request) async {
          if (scenario == 'export failure') {
            throw StateError('Destination denied');
          }
          return rpc.JobInfo(
            jobId: 'value-export',
            executionId: request.executionId,
            state: rpc.JobState.QUEUED,
          );
        };
        final view = Center(
          child: SizedBox(
            width: 900,
            height: 450,
            child: ResultGrid(
              model: model,
              controls: controls,
              result: result,
              selectValueDestination: (suggestedName) {
                expect(suggestedName, 'value.txt');
                return destination.future;
              },
            ),
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => directory.delete(recursive: true));
        });
        await tester.pumpAndSettle();
        await tester.tap(find.text('preview … [preview only]'));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Export full retained value (90000 bytes)'));
        await tester.pump();
        if (scenario == 'switch during picker') model.newDocument();
        if (scenario == 'close during picker') {
          await model.closeDocument(
            original,
            reviewedRevision: original.version,
          );
        }
        destination.complete('/reviewed/value.txt');
        await tester.pump();
        if (scenario == 'close during picker') {
          expect(backend.client.toolReviewRequests, isEmpty);
          expect(model.status, contains('changed'));
        } else {
          expect(backend.client.toolReviewRequests, hasLength(1));
          final request = backend.client.toolReviewRequests.single;
          expect(request.resultId, 'retained-source');
          expect(request.valueId, 'retained-value');
          expect(request.sessionId, 'disconnected-source');
          expect(request.path, '/reviewed/value.txt');
          if (scenario == 'restart during review') {
            model.backend = TestBackend(instanceId: 'replacement');
          }
          if (scenario == 'review failure') {
            review.completeError(StateError('Review unavailable'));
            await tester.pumpAndSettle();
            expect(model.status, contains('Review unavailable'));
          } else {
            review.complete(rpc.Approval(token: 'exact-value-review'));
            await tester.pumpAndSettle();
            if (scenario == 'restart during review') {
              expect(find.text('Export full retained value'), findsNothing);
              expect(model.status, contains('changed'));
            } else {
              expect(find.text('Export full retained value'), findsOneWidget);
              if (scenario == 'dispose during confirmation') {
                model.disposedResults.add('retained-source');
              }
              if (scenario == 'switch during confirmation') model.newDocument();
              await tester.tap(find.text('Start export'));
              await tester.pumpAndSettle();
              if (scenario == 'dispose during confirmation') {
                expect(backend.client.toolRequests, isEmpty);
                expect(model.status, contains('changed'));
              } else {
                expect(backend.client.toolRequests, hasLength(1));
                expect(
                  backend.client.toolRequests.single.approvalToken,
                  'exact-value-review',
                );
                if (scenario == 'export failure') {
                  expect(model.status, contains('Destination denied'));
                } else {
                  expect(model.jobDocuments['value-export'], original.id);
                  expect(
                    model.latestExecutions[original.id],
                    backend.client.toolRequests.single.executionId,
                  );
                }
              }
            }
          }
        }
        await tester.pumpAndSettle();
        expect(model.busy, isFalse);
        expect(model.pendingOperations, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
