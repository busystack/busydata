import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/app/busydata_window_close.dart';
import 'package:busydata/src/app/windows/windows_busydata_app.dart';
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'support/fake_backend.dart';
import 'support/browse_selection_fixture.dart';
import 'support/native_window.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    late Directory root;
    late WorkbenchModel model;
    late TestBackend backend;
    late PreparedBrowseFixture metadata;
    late WorkbenchCommandContext source;
    const logical = DatabaseObjectIdentity(
      profileId: 'p',
      catalog: 'db',
      schema: 'public',
      kind: rpc.ObjectKind.TABLE,
      subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
      name: 'Orders',
    );
    Future<void> mount(WidgetTester tester) async {
      installNativeWindowFixture(tester);
      root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('browse-command-'),
      ))!;
      backend = TestBackend();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
      );
      model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..profiles.add(profile)
        ..newDocument(text: 'SELECT original_owner');
      model.sessions['s'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 's',
        profile: profile,
        currentCatalog: 'db',
        currentSchema: 'public',
        contextRevision: Int64.ONE,
        sessionRevision: Int64.ONE,
        transaction: rpc.TransactionState.IDLE,
        autoCommit: true,
      );
      model.explorerSessions['p'] = 's';
      model.connectionOwner(profile)
        ..sessionId = 's'
        ..evidenceProfile = profile;
      metadata = PreparedBrowseFixture(
        relation: rpc.SchemaObject(
          kind: rpc.ObjectKind.TABLE,
          subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
          name: 'Orders',
          catalog: 'db',
          schema: 'public',
          stableIdentity: 'java-command-relation',
        ),
        columns: [
          rpc.SchemaObject(
            kind: rpc.ObjectKind.COLUMN,
            name: 'id',
            table: 'Orders',
            catalog: 'db',
            schema: 'public',
            stableIdentity: 'java-command-column',
            parentIdentity: 'java-command-relation',
          ),
        ],
      );
      metadata.install(model, backend);
      source = WorkbenchCommandContext(
        profileId: 'p',
        sessionId: 's',
        object: logical,
        metadataObject: metadata.relation.deepCopy()
          ..metadataSnapshotRevision = Int64(10)
          ..introspectionLevel = 1
          ..metadataState = 'AVAILABLE',
        metadataConfigurationRevision: 2,
        metadataInstance: backend.instanceId,
        metadataSources: const {
          'p': (sessionId: 's', contextRevision: 1, sessionRevision: 1),
        },
      );
      backend.client.browseReview = (request) async {
        expectSync(
          backend.client.browseRequests.where(
            (submitted) => submitted.executionId == request.executionId,
          ),
          isEmpty,
          reason: 'Browse must wait for its exact reviewed approval token.',
        );
        return rpc.Approval(
          token: 'one-review',
          statements: ['SELECT * FROM "public"."Orders"'],
        );
      };
      final close = BusyDataWindowCloseCoordinator();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        expect(close.hasActiveHandler, isFalse);
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final view = WorkbenchView(model: model, controls: controls);
      await tester.pumpWidget(
        controls is WindowsControls
            ? fluent.FluentApp(
                home: WindowsWorkspaceShell(model: model, close: close),
              )
            : MaterialApp(home: Scaffold(body: view)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      '${controls.runtimeType} Explorer double-click uses its live selected session and exact prepared proof',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await mount(tester);
          final original = model.document;
          final prepared = backend.client.metadataAction!;
          backend.client.metadataAction = (request) async {
            if (metadata.matches(request)) return prepared(request);
            final session = model.sessions['s']!;
            final objects = switch (request.kind) {
              rpc.ObjectKind.CATALOG => [
                rpc.SchemaObject(
                  kind: rpc.ObjectKind.CATALOG,
                  name: 'db',
                  catalog: 'db',
                  stableIdentity: 'java-command-catalog',
                ),
              ],
              rpc.ObjectKind.SCHEMA => [
                rpc.SchemaObject(
                  kind: rpc.ObjectKind.SCHEMA,
                  name: 'public',
                  catalog: 'db',
                  schema: 'public',
                  stableIdentity: 'java-command-schema',
                ),
              ],
              rpc.ObjectKind.TABLE => [metadata.relation.deepCopy()],
              _ => <rpc.SchemaObject>[],
            };
            for (final object in objects) {
              object
                ..metadataSnapshotRevision = Int64(10)
                ..introspectionLevel = 1
                ..metadataState = 'AVAILABLE';
            }
            return rpc.SchemaObjects(
              instanceId: backend.instanceId,
              profileId: 'p',
              sessionId: 's',
              contextRevision: session.contextRevision,
              sessionRevision: session.sessionRevision,
              catalog: request.catalog.isEmpty ? 'db' : request.catalog,
              schema: request.schema,
              parent: request.table,
              kind: request.kind,
              subtype: request.subtype,
              objects: objects,
              complete: true,
              availability: 'available',
              metadataState: 'AVAILABLE',
              introspectionLevel: 1,
              metadataSnapshotRevision: Int64(10),
              metadataConfigurationRevision: Int64(2),
              metadataSourceIdentity: fixtureMetadataSourceIdentity,
              countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
              totalCount: Int64(objects.length),
              defaultNamespace: request.kind == rpc.ObjectKind.CATALOG
                  ? 'db'
                  : request.kind == rpc.ObjectKind.SCHEMA
                  ? 'public'
                  : '',
            );
          };
          await tester.tap(find.bySemanticsLabel('Expand Source'));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('Expand public'));
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('Expand Tables'));
          await tester.pumpAndSettle();
          final relation = find.byWidgetPredicate(
            (widget) => widget is Text && widget.data == 'Orders',
          );
          expect(relation.hitTestable(), findsOneWidget);
          await tester.tap(relation);
          await tester.pump(const Duration(milliseconds: 80));
          expect(backend.client.browseReviews, isEmpty);
          expect(backend.client.browseRequests, isEmpty);
          await tester.tap(relation);
          await tester.pumpAndSettle();
          expect(backend.client.opened, isEmpty);
          expect(backend.client.browseReviews, hasLength(1));
          expect(backend.client.browseRequests, hasLength(1));
          final review = backend.client.browseReviews.single;
          expect(review.sessionId, 's');
          expect(review.catalog, 'db');
          expect(review.schema, 'public');
          expect(review.table, 'Orders');
          expect(review.metadataObjectIdentity, 'java-command-relation');
          expect(review.metadataSnapshotRevision, Int64(11));
          final submitted = backend.client.browseRequests.single;
          expect(submitted.deepCopy()..clearApprovalToken(), review);
          expect(submitted.approvalToken, 'one-review');
          expect(
            backend.client.metadataRequests
                .where(metadata.matches)
                .map((request) => request.introspectionLevel),
            [2, 2, 2],
          );
          expect(
            backend.client.metadataRequests
                .where(metadata.matches)
                .where((request) => request.kind == rpc.ObjectKind.COLUMN)
                .single
                .limit,
            1,
          );
          expect(model.activeOwner.kind, WorkbenchDocumentKind.table);
          expect(model.activeOwner.object, logical);
          expect(model.activeOwner.sessionId, 's');
          expect(model.connectionOwner(model.profiles.single).sessionId, 's');
          expect(original.editor.text, 'SELECT original_owner');
          expect(original.sessionId, isNull);
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
    for (final command in ['object.data', 'object.sql']) {
      testWidgets(
        '${controls.runtimeType} $command preserves live source proof and opens no connection',
        (tester) async {
          await mount(tester);
          final original = model.document;
          final operation = model.commands!.invoke(command, source);
          await tester.pumpAndSettle();
          await operation;
          expect(backend.client.opened, isEmpty);
          expect(
            backend.client.metadataRequests.where(metadata.matches).length,
            3,
          );
          expect(
            backend.client.metadataRequests
                .where(metadata.matches)
                .map((request) => request.introspectionLevel),
            [2, 2, 2],
          );
          final review = backend.client.browseReviews.single;
          expect(review.sessionId, 's');
          expect(review.metadataObjectIdentity, 'java-command-relation');
          expect(review.metadataSnapshotRevision, Int64(11));
          expect(original.editor.text, 'SELECT original_owner');
          if (command == 'object.data') {
            expect(model.activeOwner.sessionId, 's');
            expect(model.activeOwner.object, logical);
            final submitted = backend.client.browseRequests.single;
            expect(submitted.deepCopy()..clearApprovalToken(), review);
            expect(submitted.approvalToken, 'one-review');
          } else {
            expect(backend.client.browseRequests, isEmpty);
            expect(model.documents.length, 2);
            expect(
              model.document.editor.text,
              'SELECT * FROM "public"."Orders"',
            );
          }
          expect(backend.client.executions, isEmpty);
        },
      );
    }
    testWidgets(
      '${controls.runtimeType} stale Open SQL review never creates a generated document',
      (tester) async {
        await mount(tester);
        final pending = Completer<rpc.Approval>();
        backend.client.browseReview = (_) => pending.future;
        final operation = model.commands!.invoke('object.sql', source);
        final outcome = expectLater(
          operation,
          throwsA(isA<LocalWorkbenchFailure>()),
        );
        await tester.pump();
        expect(backend.client.browseReviews, hasLength(1));
        model.sessions['s']!.contextRevision = Int64(2);
        model.updateStatus('Context changed');
        pending.complete(
          rpc.Approval(token: 'retired', statements: ['SELECT wrong_owner']),
        );
        await tester.pump();
        await outcome;
        expect(model.documents, hasLength(1));
        expect(model.document.editor.text, 'SELECT original_owner');
        expect(backend.client.browseRequests, isEmpty);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.browseReviews, hasLength(1));
      },
    );
    testWidgets(
      '${controls.runtimeType} failed Refresh preserves retained mapping filters selection and a draft staged during review',
      (tester) async {
        await mount(tester);
        final owner =
            model.openTask(
                WorkbenchDocumentKind.table,
                'Orders',
                object: logical,
              )
              ..sessionId = 's'
              ..view.subview = 'data';
        model.track(
          rpc.JobInfo(
            jobId: 'old-job',
            executionId: 'old-execution',
            sessionId: 's',
            state: rpc.JobState.COMPLETED,
            results: [
              rpc.StatementResult(
                resultId: 'old-result',
                fetchedRows: Int64.ONE,
                complete: true,
                columns: [rpc.Column(name: 'id', ordinal: 1)],
              ),
            ],
          ),
          documentId: owner.id,
        );
        model.cache['old-result:0'] = rpc.Row(
          values: [rpc.Value(signedInteger: '7')],
        );
        model.selectedExecutions[owner.id] = 'old-execution';
        model.resultView('old-result', owner: owner).selectedRow = 0;
        final oldQuery = owner.view.tableConditions.toList(),
            oldOrder = owner.view.tableOrder.toList();
        final pending = Completer<rpc.Approval>();
        backend.client.browseReview = (_) => pending.future;
        final operation = model.commands!.invoke(
          'object.refresh',
          model.commandContext,
        );
        await tester.pump();
        expect(backend.client.browseReviews, hasLength(1));
        final batch = model.batchFor(owner, 'old-result');
        model.stageChange(
          batch,
          rpc.StagedChange(
            kind: rpc.ChangeKind.UPDATE,
            sourceRow: Int64.ZERO,
            values: [
              MapEntry(
                1,
                rpc.ValueAssignment(value: rpc.Value(signedInteger: '9')),
              ),
            ],
          ),
        );
        final staged = batch.changes.single.writeToBuffer(),
            revision = batch.revision;
        pending.complete(rpc.Approval(token: 'retired'));
        await tester.pump();
        await operation;
        expect(backend.client.browseRequests, isEmpty);
        expect(backend.client.browseReviews, hasLength(1));
        expect(model.resultForOwner(owner)!.resultId, 'old-result');
        expect(model.selectedExecutions[owner.id], 'old-execution');
        expect(model.resultView('old-result', owner: owner).selectedRow, 0);
        expect(owner.view.tableConditions, oldQuery);
        expect(owner.view.tableOrder, oldOrder);
        expect(batch.changes.single.writeToBuffer(), staged);
        expect(batch.revision, revision);
        expect(owner.view.dataError, isNotEmpty);
        expect(backend.client.executions, isEmpty);
      },
    );
    testWidgets(
      '${controls.runtimeType} SQL-symbol Open Data carries the original exact candidate into the shared preflight',
      (tester) async {
        await mount(tester);
        final document = model.document;
        document.profileId = 'p';
        document.sessionId = 's';
        document.editor.text = 'SELECT * FROM Orders';
        document.editor.selection = const CodeLineSelection.collapsed(
          index: 0,
          offset: 20,
        );
        final sqlOwner = model.workbenchDocuments.firstWhere(
          (owner) => identical(owner.sql, document),
        );
        model.activateOwner(sqlOwner.id);
        final operation = model.commands!.invoke(
          'object.data',
          model.commandContext,
        );
        await tester.pump();
        final index = backend.client.analyses.indexWhere(
          (request) =>
              request.operation == rpc.AnalysisOperation.SYMBOL_RESOLUTION,
        );
        expect(index, greaterThanOrEqualTo(0));
        final request = backend.client.analyses[index];
        final candidate = metadata.relation.deepCopy()
          ..metadataSnapshotRevision = Int64(10)
          ..introspectionLevel = 1
          ..metadataState = 'AVAILABLE';
        backend.client.pendingAnalyses[index].complete(
          rpc.Analysis(
            documentId: request.documentId,
            documentVersion: request.documentVersion,
            backendInstance: request.context.instanceId,
            sessionId: request.sessionId,
            contextRevision: request.contextRevision,
            sessionRevision: request.sessionRevision,
            caretUtf16: request.caretUtf16,
            operation: request.operation,
            metadataSnapshotRevision: Int64(10),
            metadataConfigurationRevision: Int64(2),
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            symbol: rpc.ResolvedSymbol(
              span: rpc.Span(startUtf16: 14, endUtf16: 20),
              profileId: 'p',
              catalog: 'db',
              schema: 'public',
              complete: true,
              availability: 'exact',
              candidates: [candidate],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await operation;
        expect(backend.client.opened, isEmpty);
        expect(backend.client.browseReviews, hasLength(1));
        expect(
          backend.client.browseRequests.single.metadataObjectIdentity,
          candidate.stableIdentity,
        );
        expect(backend.client.browseRequests.single.sessionId, 's');
        expect(document.editor.text, 'SELECT * FROM Orders');
        expect(document.sessionId, 's');
      },
    );
  }
}
