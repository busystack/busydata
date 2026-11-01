import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/transfer_document.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show CallOptions, GrpcError, ResponseFuture;
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

class CancellableImportClient extends TestClient {
  CancellableImportClient({this.cancelPreview = true});
  final bool cancelPreview;
  final pending = Completer<rpc.ImportPreview>();
  final pendingJob = Completer<rpc.JobInfo>();
  int cancelled = 0;
  @override
  ResponseFuture<rpc.ImportPreview> previewImport(
    rpc.ToolRequest request, {
    CallOptions? options,
  }) {
    if (!cancelPreview) return super.previewImport(request, options: options);
    importPreviewRequests.add(request.deepCopy());
    return response(
      pending.future,
      onCancel: () {
        cancelled++;
        if (!pending.isCompleted) {
          pending.completeError(const GrpcError.cancelled());
        }
      },
    );
  }

  @override
  ResponseFuture<rpc.JobInfo> tool(
    rpc.ToolRequest request, {
    CallOptions? options,
  }) {
    if (cancelPreview) return super.tool(request, options: options);
    toolRequests.add(request.deepCopy());
    return response(
      pendingJob.future,
      onCancel: () {
        cancelled++;
        if (!pendingJob.isCompleted) {
          pendingJob.completeError(const GrpcError.cancelled());
        }
      },
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeMenus = MethodChannel('busydata/native_menus');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          nativeMenus,
          (_) async => throw MissingPluginException(),
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeMenus, null),
  );
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} palette exports disconnected table data without borrowing Explorer ownership',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('retained-export-owner-'),
        ))!;
        final backend = TestBackend();
        final model = (await tester.runAsync(() async => WorkbenchModel(root)))!
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final sql = model.document;
        final profile = rpc.Profile(
          id: 'p',
          name: 'Original production',
          host: 'original-host',
          port: 5432,
          environment: rpc.Environment.PRODUCTION,
        );
        model.profiles.add(profile);
        model.explorerSessions['p'] = 'inspection';
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: profile,
          autoCommit: true,
        );
        final owner = model.openTask(
          WorkbenchDocumentKind.table,
          'items',
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'db',
            schema: 'public',
            kind: rpc.ObjectKind.TABLE,
            name: 'items',
          ),
        );
        final result = rpc.StatementResult(
          resultId: 'original-retained',
          complete: true,
        );
        owner.view.subview = 'data';
        model.connectionOwner(profile).sessionId = 'inspection';
        model.track(
          rpc.JobInfo(
            jobId: 'j',
            executionId: 'e',
            state: rpc.JobState.COMPLETED,
            results: [result],
          ),
          documentId: owner.id,
        );
        model.retainedResults[result.resultId] = rpc.RetainedResult(
          result: result,
          target: profile,
          documentId: owner.id,
          executionId: 'e',
        );
        await tester.binding.setSurfaceSize(const Size(1280, 960));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: controls);
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        model.targetFocus.requestFocus();
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        final search = find.descendant(
          of: find.byType(SearchHeaderField),
          matching: find.byType(EditableText),
        );
        await tester.enterText(search, 'Export retained data');
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final data = model.activeOwner.payload as TransferDocumentData;
        expect(data.target.owner, same(owner));
        expect(data.target.sessionId, isNull);
        expect(data.resultId, 'original-retained');
        expect(data.sourceTarget!.host, 'original-host');
        expect(data.sourceTarget!.environment, rpc.Environment.PRODUCTION);
        expect(sql.sessionId, isNull);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.metadataRequests, isEmpty);
        expect(backend.client.toolRequests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    for (final scenario in [
      'import',
      'cancel preview',
      'cancel start',
      'later column',
      'incomplete columns',
      'unknown column flags',
      'retained',
      'stale preview',
    ]) {
      testWidgets(
        '${controls.runtimeType} transfer $scenario remains captured and explicitly reviewed',
        (tester) async {
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('transfer-document-'),
          ))!;
          final backend = TestBackend(
            client: scenario == 'cancel preview' || scenario == 'cancel start'
                ? CancellableImportClient(
                    cancelPreview: scenario == 'cancel preview',
                  )
                : null,
          );
          final model =
              (await tester.runAsync(() async => WorkbenchModel(root)))!
                ..draftRecovery = false
                ..backend = backend
                ..newDocument(text: 'SELECT original;');
          final source = model.activeOwner;
          if (scenario != 'retained') {
            source.sessionId = 'source-session';
            model.sessions['source-session'] = rpc.SessionInfo(
              metadataSourceIdentity: fixtureMetadataSourceIdentity,
              sessionId: 'source-session',
              autoCommit: true,
              profile: rpc.Profile(
                name: 'Original staging',
                environment: rpc.Environment.STAGING,
              ),
            );
          }
          final gate = Completer<rpc.ImportPreview>();
          rpc.ImportPreview sampled() => rpc.ImportPreview(
            sourceColumns: [
              'source_n',
              if (scenario == 'later column') 'source_id',
            ],
            limited: true,
            sourceSha256: 'a' * 64,
            rows: [
              rpc.Row(
                values: [
                  rpc.Value(text: 'quoted NULL literal'),
                  if (scenario == 'later column')
                    rpc.Value(text: 'required value'),
                ],
              ),
            ],
          );
          backend.client.importPreview = (_) => scenario == 'stale preview'
              ? gate.future
              : Future.value(sampled());
          var columnsReady = scenario != 'incomplete columns';
          backend.client.metadataAction = (r) async => rpc.SchemaObjects(
            complete: columnsReady,
            continuation: columnsReady ? '' : 'non-progressing',
            objects: scenario == 'later column'
                ? [
                    for (var i = 0; i < 160; i++)
                      rpc.SchemaObject(
                        name: 'c${i.toString().padLeft(3, '0')}',
                        kind: rpc.ObjectKind.COLUMN,
                        properties: {'ordinal': '${i + 1}'}.entries,
                      ),
                  ]
                : [
                    rpc.SchemaObject(
                      name: 'n',
                      kind: rpc.ObjectKind.COLUMN,
                      properties: scenario == 'unknown column flags'
                          ? {
                              'generated': 'UNKNOWN',
                              'autoIncrement': 'NO',
                            }.entries
                          : const <String, String>{}.entries,
                    ),
                  ],
          );
          metadataFixture(model);
          backend.client.tools = (request) async => rpc.JobInfo(
            jobId: 'transfer-job',
            executionId: request.executionId,
            state: rpc.JobState.QUEUED,
            target: rpc.Profile(name: 'Original staging'),
          );
          final data = TransferDocumentData(
            model.captureTarget(owner: source),
            scenario == 'retained'
                ? rpc.ToolKind.EXPORT_RESULT
                : rpc.ToolKind.IMPORT_CSV,
            path:
                '${root.path}/${scenario == 'retained' ? 'output.csv' : 'source.csv'}',
            schema: 'public',
            table: 'items',
            resultId: scenario == 'retained' ? 'retained-original' : '',
            sourceTarget: scenario == 'retained'
                ? rpc.Profile(
                    name: 'Disconnected original',
                    environment: rpc.Environment.PRODUCTION,
                  )
                : null,
          );
          final owner = model.openTask(
            WorkbenchDocumentKind.transfer,
            'Captured transfer',
            payload: data,
            reuse: false,
          );
          await tester.binding.setSurfaceSize(const Size(1280, 960));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final view = TransferDocument(
            model: model,
            owner: owner,
            data: data,
            controls: controls,
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(home: Scaffold(body: view)),
          );
          await tester.pumpAndSettle();
          expect(backend.client.executions, isEmpty);
          expect(backend.client.toolRequests, isEmpty);
          if (scenario == 'incomplete columns') {
            expect(backend.client.metadataRequests, hasLength(2));
            expect(data.mapping, isEmpty);
            expect(find.text('n'), findsNothing);
            await tester.ensureVisible(find.text('Preview source'));
            await tester.tap(find.text('Preview source'));
            await tester.pumpAndSettle();
            expect(backend.client.importPreviewRequests, isEmpty);
            expect(backend.client.toolReviewRequests, isEmpty);
            expect(
              data.status.toLowerCase(),
              contains('complete column metadata'),
            );
            await tester.scrollUntilVisible(
              find.text('Retry'),
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(WorkbenchFormList),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            columnsReady = true;
            await tester.tap(find.text('Retry'));
            await tester.pumpAndSettle();
            expect(backend.client.metadataRequests, hasLength(3));
          }
          if (scenario == 'retained') {
            expect(
              find.textContaining('Disconnected original'),
              findsOneWidget,
            );
            expect(
              find.textContaining('Fetched snapshot; SQL is not executed'),
              findsOneWidget,
            );
            expect(backend.client.metadataRequests, isEmpty);
          } else {
            await tester.ensureVisible(find.text('Preview source'));
            await tester.tap(find.text('Preview source'));
            await tester.pumpAndSettle();
            expect(
              backend.client.importPreviewRequests.single.sessionId,
              'source-session',
            );
            if (scenario == 'cancel preview') {
              expect(data.busy, isTrue);
              await tester.tap(find.text('Request cancellation'));
              await tester.pumpAndSettle();
              expect((backend.client as CancellableImportClient).cancelled, 1);
              expect(data.busy, isFalse);
              expect(data.preview, isNull);
              expect(data.approval, isNull);
              expect(backend.client.importPreviewRequests, hasLength(1));
              expect(backend.client.toolReviewRequests, isEmpty);
              expect(backend.client.toolRequests, isEmpty);
              expect(tester.takeException(), isNull);
              return;
            }
            if (scenario == 'stale preview') {
              final fields = find.byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              );
              await tester.enterText(fields.first, ';');
              gate.complete(sampled());
              await tester.pumpAndSettle();
              expect(
                data.status,
                contains('Transfer settings changed; review again'),
              );
              await tester.scrollUntilVisible(
                find.textContaining('Transfer settings changed; review again'),
                200,
                scrollable: find
                    .descendant(
                      of: find.byType(WorkbenchFormList),
                      matching: find.byType(Scrollable),
                    )
                    .first,
              );
              expect(data.preview, isNull);
              expect(data.approval, isNull);
              expect(backend.client.toolReviewRequests, isEmpty);
              expect(backend.client.toolRequests, isEmpty);
              return;
            }
            expect(data.preview!.rows, hasLength(1));
            final mappings = find.byKey(
              const ValueKey('transfer-column-mappings'),
            );
            await tester.scrollUntilVisible(
              mappings,
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(WorkbenchFormList),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await tester.ensureVisible(mappings);
            final mappingScroll = find.descendant(
              of: mappings,
              matching: find.byType(Scrollable),
            );
            if (scenario == 'later column') {
              if (controls is LinuxControls) {
                final semantics = tester.ensureSemantics();
                try {
                  await tester.pump();
                  // Built rows have one named control; later metadata pages
                  // remain virtualized until explicitly revealed.
                  expect(
                    find.bySemanticsLabel('c000: Omit / database default'),
                    findsOneWidget,
                  );
                  expect(
                    find.bySemanticsLabel('c159: Omit / database default'),
                    findsNothing,
                    reason: 'offscreen mappings must stay virtualized',
                  );
                } finally {
                  semantics.dispose();
                }
              }
              await tester.scrollUntilVisible(
                find.text('c000'),
                200,
                scrollable: mappingScroll,
              );
              final firstRow = find.byKey(
                const ValueKey('transfer-column-mapping-c000'),
              );
              // Settle both nested viewports before using the row's pointer
              // coordinates. Its cached child can exist before the outer
              // form has completed ensureVisible's layout.
              await tester.ensureVisible(firstRow);
              await tester.pumpAndSettle();
              await tester.tap(
                find.descendant(
                  of: firstRow,
                  matching: find.text('Omit / database default'),
                ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text('source_id').last);
              await tester.pumpAndSettle();
              expect(data.preview, isNotNull);
              expect(data.mapping, {'c000': 'source_id'});
              expect(
                backend.client.metadataRequests.map((r) => r.continuation),
                ['', 'fixture:128'],
              );
            }
            await tester.scrollUntilVisible(
              find.text(scenario == 'later column' ? 'c159' : 'n'),
              600,
              maxScrolls: 100,
              scrollable: mappingScroll,
            );
            final mappingRow = find.byKey(
              ValueKey(
                'transfer-column-mapping-${scenario == 'later column' ? 'c159' : 'n'}',
              ),
            );
            final omission = find.descendant(
              of: mappingRow,
              matching: find.text('Omit / database default'),
            );
            await tester.scrollUntilVisible(
              omission,
              200,
              scrollable: mappingScroll,
            );
            await tester.ensureVisible(omission);
            await tester.pumpAndSettle();
            await tester.tap(omission);
            await tester.pumpAndSettle();
            if (scenario == 'unknown column flags') {
              expect(data.mapping, isEmpty);
              expect(backend.client.toolReviewRequests, isEmpty);
              expect(backend.client.toolRequests, isEmpty);
              expect(find.text('source_n'), findsOneWidget);
              return;
            }
            await tester.tap(find.text('source_n').last);
            await tester.pumpAndSettle();
            expect(data.mapping, {
              if (scenario == 'later column') 'c000': 'source_id',
              scenario == 'later column' ? 'c159' : 'n': 'source_n',
            });
            expect(backend.client.importPreviewRequests, hasLength(1));
            expect(backend.client.toolReviewRequests, isEmpty);
          }
          await tester.scrollUntilVisible(
            find.text('Review transfer'),
            200,
            scrollable: find
                .descendant(
                  of: find.byType(WorkbenchFormList),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(find.text('Review transfer'));
          await tester.pumpAndSettle();
          expect(data.approval, isNotNull);
          final review = backend.client.toolReviewRequests.single;
          expect(
            review.resultId,
            scenario == 'retained' ? 'retained-original' : '',
          );
          expect(
            review.sessionId,
            scenario == 'retained' ? '' : 'source-session',
          );
          if (scenario == 'import' || scenario == 'later column') {
            expect(review.sourceSha256, 'a' * 64);
            expect(review.columnMapping, {
              if (scenario == 'later column') 'c000': 'source_id',
              scenario == 'later column' ? 'c159' : 'n': 'source_n',
            });
            expect(review.importPolicy, rpc.ImportPolicy.ATOMIC_IMPORT);
          }
          expect(backend.client.toolRequests, isEmpty);
          model.newDocument(text: 'SELECT unrelated;');
          final unrelated = model.activeOwner;
          final start = find.text(
            scenario == 'retained' ? 'Start export' : 'Start import',
          );
          await tester.scrollUntilVisible(
            start,
            200,
            scrollable: find
                .descendant(
                  of: find.byType(WorkbenchFormList),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(start);
          await tester.pumpAndSettle();
          if (scenario == 'cancel start') {
            expect(data.busy, isTrue);
            expect(data.reviewed, isNull);
            expect(data.approval, isNull);
            await tester.tap(find.text('Request cancellation'));
            await tester.pumpAndSettle();
            expect((backend.client as CancellableImportClient).cancelled, 1);
            expect(backend.client.toolRequests, hasLength(1));
            expect(data.busy, isFalse);
            expect(data.jobId, isNull);
            expect(data.approval, isNull);
            expect(data.mapping, {'n': 'source_n'});
            expect(model.jobs, isEmpty);
            expect(tester.takeException(), isNull);
            return;
          }
          expect(
            backend.client.toolRequests.single.approvalToken,
            'tool-review',
          );
          expect(
            backend.client.toolRequests.single.sessionId,
            review.sessionId,
          );
          expect(backend.client.toolRequests.single.resultId, review.resultId);
          expect(model.jobDocuments['transfer-job'], owner.id);
          expect(model.activeOwner, same(unrelated));
          expect(model.pendingOperations, 0);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(model.jobs['transfer-job']!.state, rpc.JobState.QUEUED);
          expect(backend.client.sessionCommands, isEmpty);
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
