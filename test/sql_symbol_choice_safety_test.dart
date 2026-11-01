import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

const _lower =
    '52e718b782be830a10b4ea5a023941fa95328005c56128d609df421287336168';
const _mixed =
    '263b6075344c7aebb067439a92c8512c22647e8b1f429336520b20483a4a891f';
const _sql = 'SELECT * FROM audit.CUSTOMERS';

class _Outcome {
  _Outcome(Future<void> operation) {
    done = operation.then<void>(
      (_) {
        settled = true;
      },
      onError: (Object error, StackTrace stack) {
        failure = error;
        settled = true;
      },
    );
  }
  late final Future<void> done;
  bool settled = false;
  Object? failure;
}

Future<(WorkbenchModel, TestBackend)> _mount(WidgetTester tester) async {
  final root = (await tester.runAsync(
    () => Directory.systemTemp.createTemp('symbol-choice-safety-'),
  ))!;
  final backend = TestBackend();
  final profile = Profile(id: 'source', name: 'Source', engine: Engine.MYSQL);
  final model = WorkbenchModel(root)
    ..draftRecovery = false
    ..backend = backend
    ..profiles.add(profile)
    ..newDocument(text: _sql);
  model.document
    ..profileId = profile.id
    ..sessionId = 'physical'
    ..selectOffsets(_sql.length - 2, _sql.length - 2);
  model.sessions['physical'] = SessionInfo(
    metadataSourceIdentity: fixtureMetadataSourceIdentity,
    sessionId: 'physical',
    profile: profile,
    currentCatalog: 'first',
    currentSchema: 'first',
    contextRevision: Int64.ONE,
    sessionRevision: Int64.ONE,
    transaction: TransactionState.IDLE,
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
    await tester.runAsync(() => root.delete(recursive: true));
  });
  await tester.pumpWidget(
    MaterialApp(
      home: WorkbenchView(model: model, controls: const LinuxControls()),
    ),
  );
  return (model, backend);
}

void _completeChoice(
  TestBackend backend, {
  String state = 'AVAILABLE',
  bool invalidIdentity = false,
}) {
  final index = backend.client.analyses.indexWhere(
    (request) => request.operation == AnalysisOperation.SYMBOL_RESOLUTION,
  );
  expect(index, greaterThanOrEqualTo(0));
  final request = backend.client.analyses[index];
  backend.client.pendingAnalyses[index].complete(
    Analysis(
      documentId: request.documentId,
      documentVersion: request.documentVersion,
      backendInstance: request.context.instanceId,
      sessionId: request.sessionId,
      contextRevision: request.contextRevision,
      sessionRevision: request.sessionRevision,
      caretUtf16: request.caretUtf16,
      operation: request.operation,
      metadataSnapshotRevision: Int64(7),
      metadataConfigurationRevision: Int64(2),
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      symbol: ResolvedSymbol(
        profileId: 'source',
        catalog: 'audit',
        schema: 'audit',
        complete: state == 'AVAILABLE' && !invalidIdentity,
        availability: state == 'AVAILABLE' && !invalidIdentity
            ? 'choose-native-case'
            : 'incomplete-metadata',
        span: Span(
          startUtf16: _sql.indexOf('CUSTOMERS'),
          endUtf16: _sql.length,
        ),
        candidates: [
          SchemaObject(
            catalog: 'audit',
            schema: 'audit',
            name: 'customers',
            kind: ObjectKind.TABLE,
            subtype: ObjectSubtype.ORDINARY_TABLE,
            stableIdentity: _lower,
            metadataSnapshotRevision: Int64(7),
            introspectionLevel: 1,
            metadataState: 'AVAILABLE',
          ),
          SchemaObject(
            catalog: 'audit',
            schema: 'audit',
            name: 'Customers',
            kind: ObjectKind.TABLE,
            subtype: ObjectSubtype.ORDINARY_TABLE,
            stableIdentity: invalidIdentity ? '' : _mixed,
            metadataSnapshotRevision: Int64(7),
            introspectionLevel: 1,
            metadataState: state,
          ),
        ],
      ),
    ),
  );
}

void _noDatabaseAction(WorkbenchModel model, TestBackend backend) {
  expect(model.explorerReveal, isNull);
  expect(backend.client.opened, isEmpty);
  expect(backend.client.executions, isEmpty);
  expect(backend.client.metadataRequests, isEmpty);
  expect(backend.client.browseReviews, isEmpty);
  expect(backend.client.browseRequests, isEmpty);
  expect(backend.client.schemaToolRequests, isEmpty);
}

void main() {
  for (final state in ['STALE', 'PARTIAL', 'UNKNOWN', 'invalid-identity']) {
    testWidgets(
      'symbol choice rejects $state before opening a modal and settles its command',
      (tester) async {
        final (model, backend) = await _mount(tester);
        final outcome = _Outcome(
          model.commands!.invoke('object.reveal', model.commandContext),
        );
        _completeChoice(
          backend,
          state: state == 'invalid-identity' ? 'AVAILABLE' : state,
          invalidIdentity: state == 'invalid-identity',
        );
        await tester.pumpAndSettle();
        // Check settlement before awaiting: a regression fails promptly rather
        // than waiting for the widget test's global timeout with an open modal.
        expect(outcome.settled, isTrue);
        await outcome.done;
        expect(
          outcome.failure,
          isA<LocalWorkbenchFailure>().having(
            (failure) => failure.reason,
            'reason',
            WorkbenchFailureReason.incompleteMetadata,
          ),
        );
        expect(find.text('Source / audit / Customers'), findsNothing);
        expect(find.text('Source / audit / customers'), findsNothing);
        expect(model.document.editor.text, _sql);
        expect(model.document.sessionId, 'physical');
        expect(model.sessions['physical']!.contextRevision, Int64.ONE);
        expect(model.sessions['physical']!.currentCatalog, 'first');
        _noDatabaseAction(model, backend);
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final change in ['context', 'document', 'disconnected']) {
    testWidgets(
      'symbol choice closes and settles a stale $change owner without a callback exception',
      (tester) async {
        final (model, backend) = await _mount(tester);
        final document = model.document;
        final outcome = _Outcome(
          model.commands!.invoke('object.reveal', model.commandContext),
        );
        _completeChoice(backend);
        await tester.pumpAndSettle();
        expect(find.text('Source / audit / Customers'), findsOneWidget);
        expect(outcome.settled, isFalse);
        if (change == 'context') {
          model.sessions['physical']!.contextRevision = Int64(2);
        } else if (change == 'document') {
          document.editor.text = 'SELECT preserved_user_change';
        } else {
          model.sessions['physical']!.transaction =
              TransactionState.DISCONNECTED;
        }
        final text = document.editor.text;
        final contextRevision = model.sessions['physical']!.contextRevision;
        final transaction = model.sessions['physical']!.transaction;
        await tester.tap(find.text('Source / audit / Customers'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(outcome.settled, isTrue);
        await outcome.done;
        expect(
          outcome.failure,
          change == 'disconnected'
              ? isA<LocalWorkbenchFailure>().having(
                  (failure) => failure.reason,
                  'reason',
                  WorkbenchFailureReason.unavailable,
                )
              : isA<StateError>(),
        );
        expect(find.text('Source / audit / Customers'), findsNothing);
        expect(document.editor.text, text);
        expect(document.sessionId, 'physical');
        expect(model.sessions['physical']!.contextRevision, contextRevision);
        expect(model.sessions['physical']!.transaction, transaction);
        expect(model.sessions['physical']!.currentCatalog, 'first');
        _noDatabaseAction(model, backend);
      },
    );
  }
}
