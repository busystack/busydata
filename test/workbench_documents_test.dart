import 'package:busydata/src/features/results/value_assignments.dart'
    as assignments;
import 'dart:async';
import 'dart:io';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'support/fake_backend.dart';

void main() {
  late Directory directory;
  late WorkbenchModel model;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('typed-workbench-');
    model = WorkbenchModel(directory)
      ..draftRecovery = false
      ..newDocument();
    model.backend = TestBackend();
  });
  tearDown(() async {
    model.dispose();
    await directory.delete(recursive: true);
  });
  test(
    'failed table browse has a scoped error and a successful retry clears it',
    () {
      final table = model.openTask(
        WorkbenchDocumentKind.table,
        'table',
        reuse: false,
      );
      model.track(
        JobInfo(jobId: 'failed', executionId: 'first', state: JobState.FAILED),
        documentId: table.id,
      );
      expect(table.view.dataError, contains('Retry'));
      expect(model.activeOwner.view.dataError, table.view.dataError);
      model.newDocument();
      expect(model.activeOwner.view.dataError, isEmpty);
      model.track(
        JobInfo(
          jobId: 'retry',
          executionId: 'second',
          state: JobState.COMPLETED,
        ),
        documentId: table.id,
      );
      expect(table.view.dataError, isEmpty);
    },
  );
  test(
    'typed view cleanup remains pending until the physical session disconnect is acknowledged',
    () async {
      final backend = model.backend as TestBackend;
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'Selected object',
        reuse: false,
      )..sessionId = 'object-session';
      model.sessions['object-session'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'object-session',
        transaction: TransactionState.IDLE,
      );
      final entered = Completer<void>(), approval = Completer<Approval>();
      backend.client.sessionCommand = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: request.sessionId,
        transaction: request.action == SessionAction.DISCONNECT
            ? TransactionState.DISCONNECTED
            : TransactionState.IDLE,
      );
      backend.client.sessionReview = (_) {
        entered.complete();
        return approval.future;
      };
      final close = model.closeTask(owner, resolveSession: true);
      await entered.future;
      expect(model.pendingOperations, 1);
      expect(model.taskDocuments, contains(owner));
      expect(model.sessions, contains('object-session'));
      expect(
        () => model.shareSession(model.document, 'object-session'),
        throwsStateError,
      );
      approval.complete(Approval(token: 'reviewed-cleanup'));
      await close;
      expect(model.pendingOperations, 0);
      expect(model.taskDocuments, isNot(contains(owner)));
      expect(model.sessions, isEmpty);
      expect(
        backend.client.sessionCommands
            .where((request) => request.action == SessionAction.DISCONNECT)
            .single
            .sessionId,
        'object-session',
      );
      expect(backend.client.executions, isEmpty);
    },
  );
  test('closing SQL releases its owner and every empty result batch', () async {
    final old = model.document;
    final owner = model.activeOwner;
    final captured = model.captureTarget();
    model.batchFor(owner, 'retained-one');
    model.batchFor(owner, 'retained-two');
    await model.closeDocument(old, reviewedRevision: old.version);
    expect(model.editBatches, isEmpty);
    final restored = SqlDocument(id: old.id, text: '-- restored reference');
    model.adoptDocuments([restored]);
    expect(model.activeOwner, isNot(same(owner)));
    expect(model.activeOwner.sql, same(restored));
    expect(() => model.requireTarget(captured), throwsStateError);
  });
  test(
    'retained operations keep original provenance after saved target changes or deletion',
    () async {
      final backend = model.backend! as TestBackend;
      final retained = RetainedResult(
        result: StatementResult(resultId: 'retained'),
        target: Profile(
          id: 'p',
          name: 'Original production',
          engine: Engine.POSTGRESQL,
          host: 'original',
          environment: Environment.PRODUCTION,
        ),
      );
      model.profiles.add(
        Profile(
          id: 'p',
          engine: Engine.MYSQL,
          host: 'replacement',
          tls: Tls(mode: TlsMode.INSECURE),
          queryTimeoutSeconds: 60,
        ),
      );
      model.openRetainedResult(retained);
      final captured = model.captureTarget();
      backend.client.sqlCopy = (_) async =>
          CopySqlReply(text: '(exact original value)');
      final reply = await model.ownedRequest(
        captured,
        () => backend.client.copySql(
          CopySqlRequest(
            context: backend.context(),
            resultId: 'retained',
            rowCount: 1,
            columnCount: 1,
          ),
        ),
      );
      expect(reply.text, '(exact original value)');
      expect(captured.profile!.host, 'original');
      expect(captured.profile!.environment, Environment.PRODUCTION);
      model.profiles.clear();
      model.requireTarget(captured);
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'identical object names retain distinct captured connection configurations',
    () {
      final object = DatabaseObjectIdentity(
        profileId: 'p',
        catalog: 'db',
        schema: 'public',
        kind: ObjectKind.TABLE,
        name: 'same_name',
      );
      final first = Profile(id: 'p', host: 'first', engine: Engine.POSTGRESQL);
      final second = first.deepCopy()..host = 'second';
      for (final kind in [
        WorkbenchDocumentKind.table,
        WorkbenchDocumentKind.structure,
        WorkbenchDocumentKind.diagram,
      ]) {
        final a = model.openTask(
          kind,
          'same_name',
          object: object,
          evidenceProfile: first,
        );
        final b = model.openTask(
          kind,
          'same_name',
          object: object,
          evidenceProfile: second,
        );
        expect(b, isNot(same(a)));
        expect(a.evidenceProfile!.host, 'first');
        expect(b.evidenceProfile!.host, 'second');
        expect(
          model.openTask(
            kind,
            'same_name',
            object: object,
            evidenceProfile: second,
          ),
          same(b),
        );
        final renamed = second.deepCopy()..name = 'New visible name';
        expect(
          model.openTask(
            kind,
            'same_name',
            object: object,
            evidenceProfile: renamed,
          ),
          same(b),
        );
      }
      expect((model.backend! as TestBackend).client.executions, isEmpty);
    },
  );
  test(
    'expired acknowledged batches release state while recovery and unknown leases survive',
    () async {
      final backend = model.backend! as TestBackend;
      final owner = model.activeOwner;
      for (var i = 0; i < 400; i++) {
        model.batchFor(owner, 'expired-$i')
          ..sessionId = 'past-session'
          ..appliedSnapshot = true;
        model.resultView('expired-$i', owner: owner).selectedRow = i;
      }
      final pending = model.batchFor(owner, 'pending')
        ..sessionId = 'past-session';
      final ack = Completer<void>();
      final waiting = pending.trackRecovery(ack.future);
      final unknown = model.batchFor(owner, 'unknown')..outcomeUnknown = true;
      final failed = model.batchFor(owner, 'failed')
        ..saveError = StateError('No acknowledgement');
      final draft = model.batchFor(owner, 'recovery')
        ..draftId = 'private-record';
      await model.poll();
      expect(model.editBatches.values.toSet(), {
        pending,
        unknown,
        failed,
        draft,
      });
      expect(owner.view.results, isEmpty);
      expect(backend.client.executions, isEmpty);
      ack.complete();
      await waiting;
      await model.poll();
      expect(model.editBatches.values.toSet(), {unknown, failed, draft});
      expect(pending.pendingRecovery, 0);
    },
  );
  test(
    'a committed immutable snapshot cannot acquire another pending intention',
    () {
      final batch = model.batchFor(model.activeOwner, 'committed')
        ..appliedSnapshot = true;
      expect(
        () => model.stageChange(batch, StagedChange(kind: ChangeKind.INSERT)),
        throwsStateError,
      );
      expect(batch.changes, isEmpty);
    },
  );
  test(
    'closing waits for discard acknowledgement and keeps the owner on failure',
    () async {
      final backend = model.backend! as TestBackend;
      final owner = model.openTask(WorkbenchDocumentKind.table, 'table');
      final batch = model.batchFor(owner, 'source')
        ..draftId = 'private-recovery';
      final ack = Completer<EditDraftReply>();
      backend.client.edits = (r) =>
          r.action == EditDraftAction.DELETE_EDIT_DRAFT
          ? ack.future
          : Future.value(EditDraftReply());
      final discard = model.discardStagedEdits(batch: batch);
      final discarded = expectLater(discard, throwsStateError);
      expect(batch.discarding, isTrue);
      expect(
        () => model.stageChange(batch, StagedChange(kind: ChangeKind.INSERT)),
        throwsStateError,
      );
      var finished = false;
      final closing = expectLater(
        model.closeTask(owner),
        throwsStateError,
      ).then((_) => finished = true);
      await Future<void>.delayed(Duration.zero);
      expect(finished, isFalse);
      ack.completeError(StateError('Deletion acknowledgement lost'));
      await Future.wait([discarded, closing]);
      expect(model.taskDocuments, contains(owner));
      expect(model.editBatches.values, contains(batch));
      expect(batch.draftId, 'private-recovery');
      expect(batch.saveError, isNotNull);
      expect(batch.pendingRecovery, 0);
      expect(batch.discarding, isFalse);
    },
  );
  test(
    'failed empty-batch recovery keeps the task until acknowledged',
    () async {
      final owner = model.openTask(WorkbenchDocumentKind.table, 'items');
      final batch = model.batchFor(owner, 'retained');
      batch.saveError = StateError('Recovery removal acknowledgement lost');
      await expectLater(model.closeTask(owner), throwsStateError);
      expect(model.taskDocuments, contains(owner));
      expect(model.editBatches.values, contains(batch));
      batch.saveError = null;
      await model.closeTask(owner);
      expect(model.editBatches, isEmpty);
    },
  );
  test(
    'submission guards belong to the initiating owner, independently',
    () async {
      final a = model.activeOwner;
      model.newDocument();
      final b = model.activeOwner;
      final first = Completer<void>(), second = Completer<void>();
      final operationA = model.command(() => first.future, ownerId: a.id);
      expect(model.activeCommandPending, isFalse);
      final operationB = model.command(() => second.future, ownerId: b.id);
      expect(model.activeCommandPending, isTrue);
      first.complete();
      await operationA;
      expect(model.activeCommandPending, isTrue);
      second.complete();
      await operationB;
      expect(model.activeCommandPending, isFalse);
      expect(model.busy, isFalse);
    },
  );
  test(
    'object structure and retained result are typed and allocate no SQL editor or session',
    () {
      final object = DatabaseObjectIdentity(
        profileId: 'p',
        catalog: 'db',
        schema: 'public',
        kind: ObjectKind.TABLE,
        name: 'items',
      );
      final owner = model.openTask(
        WorkbenchDocumentKind.table,
        'items',
        object: object,
      );
      expect(owner.sql, isNull);
      expect(model.documents.length, 1);
      expect(owner.sessionId, isNull);
      expect(
        identical(
          model.openTask(WorkbenchDocumentKind.table, 'items', object: object),
          owner,
        ),
        isTrue,
      );
      model.openRetainedResult(
        RetainedResult(
          result: StatementResult(resultId: 'r'),
          executionId: 'e',
          target: Profile(id: 'p'),
        ),
      );
      expect(model.activeOwner.kind, WorkbenchDocumentKind.result);
      expect(model.activeOwner.sessionId, isNull);
      expect(model.documents.length, 1);
    },
  );
  test(
    'captured non-SQL owner survives switching but closing invalidates it',
    () async {
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'structure',
      );
      final captured = model.captureTarget();
      model.select(0);
      model.requireTarget(captured);
      await model.closeTask(owner);
      expect(() => model.requireTarget(captured), throwsStateError);
    },
  );
  test(
    'two batches coalesce per original row and exact reverts remove the intention',
    () {
      final first = model.activeOwner;
      model.stagedResult = 'one';
      model.staged.add(StagedChange(kind: ChangeKind.DELETE));
      final a = model.activeEditBatch;
      model.newDocument();
      model.stagedResult = 'two';
      model.staged.add(StagedChange(kind: ChangeKind.INSERT));
      expect(model.pendingEditCount, 2);
      expect(model.activeEditBatch, isNot(same(a)));
      model.activateOwner(first.id);
      expect(model.staged.single.kind, ChangeKind.DELETE);
      final batch = OwnedEditBatch('owner', 'r');
      final original = Row(
        values: [
          Value(signedInteger: '1'),
          Value(text: 'old'),
        ],
      );
      batch.stage(
        StagedChange(
          kind: ChangeKind.UPDATE,
          sourceRow: Int64(12),
          values: ({2: Value(text: 'new')}.entries).map(
            (entry) =>
                MapEntry(entry.key, assignments.assignmentOf(entry.value)),
          ),
        ),
        original: original,
      );
      batch.stage(
        StagedChange(
          kind: ChangeKind.UPDATE,
          sourceRow: Int64(12),
          values: ({1: Value(signedInteger: '2')}.entries).map(
            (entry) =>
                MapEntry(entry.key, assignments.assignmentOf(entry.value)),
          ),
        ),
        original: original,
      );
      expect(batch.changes.length, 1);
      expect(batch.changes.single.values.length, 2);
      batch.stage(
        StagedChange(
          kind: ChangeKind.UPDATE,
          sourceRow: Int64(12),
          values:
              ({
                1: Value(signedInteger: '1'),
                2: Value(text: 'old'),
              }.entries).map(
                (entry) =>
                    MapEntry(entry.key, assignments.assignmentOf(entry.value)),
              ),
        ),
        original: original,
      );
      expect(batch.changes, isEmpty);
    },
  );
  test('late acknowledgement preserves historical execution selection', () {
    final owner = model.activeOwner;
    model.selectedExecutions[owner.id] = 'historical';
    model.track(
      JobInfo(jobId: 'j', executionId: 'late', state: JobState.COMPLETED),
      documentId: owner.id,
    );
    expect(model.selectedExecutions[owner.id], 'historical');
  });
}
