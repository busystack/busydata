import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  late Directory root;
  late TestBackend backend;
  late WorkbenchModel model;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('busydata-tab-close-');
    backend = TestBackend();
    model = WorkbenchModel(root)
      ..backend = backend
      ..draftRecovery = false
      ..newDocument();
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });
  void attached({TransactionState state = TransactionState.IDLE}) {
    model.document.sessionId = 'session';
    model.sessions['session'] = SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'session',
      transaction: state,
    );
    backend.client.sessionCommand = (r) async => SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: r.sessionId,
      transaction: r.action == SessionAction.ROLLBACK
          ? TransactionState.IDLE
          : r.action == SessionAction.DISCONNECT
          ? TransactionState.DISCONNECTED
          : state,
    );
  }

  test(
    'close captured tab retains another console and retained results without disconnecting the shared session',
    () async {
      attached();
      final target = model.document;
      model.newDocument();
      model.document.sessionId = 'session';
      await model.closeDocument(target, reviewedRevision: target.version);
      expect(model.documents, hasLength(1));
      expect(model.document.sessionId, 'session');
      expect(model.sessions.keys, ['session']);
      expect(backend.client.sessionCommands, isEmpty);
    },
  );
  test(
    'failed rollback never removes the last console or sends a disconnect',
    () async {
      attached(state: TransactionState.ACTIVE);
      final target = model.document;
      backend.client.sessionCommand = (r) async {
        if (r.action == SessionAction.ROLLBACK) {
          throw StateError('Rollback acknowledgement lost');
        }
        return SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'session',
          transaction: TransactionState.ACTIVE,
        );
      };
      await expectLater(
        model.closeDocument(
          target,
          reviewedRevision: target.version,
          resolveSession: true,
        ),
        throwsStateError,
      );
      expect(model.documents, contains(target));
      expect(target.sessionId, 'session');
      expect(
        backend.client.sessionCommands.where(
          (r) => r.action == SessionAction.DISCONNECT,
        ),
        isEmpty,
      );
    },
  );
  test(
    'unknown outcomes require an explicit force-disconnect review and never replay SQL',
    () async {
      attached(state: TransactionState.UNKNOWN_TRANSACTION);
      final target = model.document;
      await expectLater(
        model.closeDocument(target, reviewedRevision: target.version),
        throwsStateError,
      );
      expect(model.documents, contains(target));
      await model.closeDocument(
        target,
        reviewedRevision: target.version,
        disconnectUncertain: true,
      );
      expect(
        backend.client.sessionCommands.last.action,
        SessionAction.DISCONNECT,
      );
      expect(backend.client.sessionCommands.last.force, isTrue);
      expect(model.sessions, isEmpty);
    },
  );
  test(
    'queued opening is invalidated and its unused session disposed before a tab closes',
    () async {
      final entered = Completer<void>(), opened = Completer<SessionInfo>();
      backend.client.opening = (_) {
        entered.complete();
        return opened.future;
      };
      backend.client.sessionCommand = (request) async {
        expect(request.action, SessionAction.DISCONNECT);
        final owner = backend.client.openedSessionOwners[request.sessionId]!;
        return owner.deepCopy()..transaction = TransactionState.DISCONNECTED;
      };
      final target = model.document;
      final connect = model.connect(Profile(id: 'profile'), 'password');
      await entered.future;
      final close = model.closeDocument(
        target,
        reviewedRevision: target.version,
      );
      opened.complete(
        SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'unused',
          profile: Profile(id: 'profile'),
        ),
      );
      await connect;
      await close;
      expect(backend.client.sessionCommands.last.sessionId, 'unused');
      expect(
        backend.client.sessionCommands.last.action,
        SessionAction.DISCONNECT,
      );
      expect(model.sessions, isEmpty);
      expect(model.documents, isNot(contains(target)));
    },
  );
  test(
    'pending mutation acknowledgement blocks removal and is counted until completion',
    () async {
      attached();
      final target = model.captureTarget(), reply = Completer<JobInfo>();
      backend.client.tools = (_) => reply.future;
      final request = model.submitTool(
        target,
        ToolRequest(sessionId: 'session', kind: ToolKind.ACTIVITY),
      );
      expect(model.pendingOperations, 1);
      await expectLater(
        model.closeDocument(target.document, reviewedRevision: target.revision),
        throwsStateError,
      );
      reply.complete(
        JobInfo(
          jobId: 'job',
          executionId: 'execution',
          state: JobState.COMPLETED,
        ),
      );
      await request;
      expect(model.pendingOperations, 0);
      expect(model.jobDocuments['job'], target.document.id);
    },
  );
  test(
    'reviewed tool stays bound to its source tab and rejects edits or context changes',
    () async {
      attached();
      final captured = model.captureTarget();
      model.newDocument();
      backend.client.tools = (_) async =>
          JobInfo(jobId: 'job', executionId: 'execution');
      await model.submitTool(captured, ToolRequest(kind: ToolKind.ACTIVITY));
      expect(model.jobDocuments['job'], captured.document.id);
      captured.document.editor.selectAll();
      captured.document.editor.replaceSelection('SELECT 2');
      await expectLater(
        model.submitTool(
          captured,
          ToolRequest(kind: ToolKind.EXPLAIN),
          text: true,
        ),
        throwsStateError,
      );
      expect(backend.client.toolRequests, hasLength(1));
    },
  );
  test('recovery failure keeps the tab and dirty SQL accessible', () async {
    final blocker = File('${root.path}/not-directory');
    await blocker.writeAsString('preserve');
    model.dispose();
    model = WorkbenchModel(Directory(blocker.path))
      ..newDocument(text: 'SELECT 1;');
    final target = model.document;
    await expectLater(
      model.closeDocument(
        target,
        reviewedRevision: target.version,
        discardText: true,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(model.documents, contains(target));
    expect(target.editor.text, 'SELECT 1;');
    expect(target.dirty, isTrue);
    expect(await blocker.readAsString(), 'preserve');
  });
  test(
    'failed save keeps SQL until an explicit discard, without authorizing a normal close',
    () async {
      final target = model.document;
      target.editor.replaceSelection('SELECT recoverable;');
      target.lastSaveError = FileSystemException('Injected rename failure');
      await expectLater(
        model.closeDocument(target, reviewedRevision: target.version),
        throwsA(isA<FileSystemException>()),
      );
      expect(model.documents, contains(target));
      expect(target.dirty, isTrue);
      await model.closeDocument(
        target,
        reviewedRevision: target.version,
        discardText: true,
      );
      expect(model.documents, isNot(contains(target)));
    },
  );
  test(
    'transaction acknowledgement is bound to its original console and counted during review',
    () async {
      attached(state: TransactionState.ACTIVE);
      final reviewed = Completer<Approval>(), reply = Completer<SessionInfo>();
      backend.client.sessionReview = (_) => reviewed.future;
      backend.client.sessionCommand = (_) => reply.future;
      final target = model.document;
      final commit = model.transaction(SessionAction.COMMIT);
      expect(model.pendingOperations, 1);
      model.newDocument();
      reviewed.complete(Approval(token: 'review'));
      await Future<void>.delayed(Duration.zero);
      reply.complete(
        SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'session',
          transaction: TransactionState.UNKNOWN_TRANSACTION,
          commandAcknowledged: true,
          acknowledgedAction: SessionAction.COMMIT,
          commandWarning: 'COMMIT acknowledged; disconnect',
        ),
      );
      await commit;
      expect(backend.client.sessionCommands.single.sessionId, 'session');
      expect(model.sessions[target.sessionId]!.commandAcknowledged, isTrue);
      expect(model.status, 'COMMIT acknowledged; disconnect');
      expect(model.pendingOperations, 0);
    },
  );
}
