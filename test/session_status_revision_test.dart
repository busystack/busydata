import 'dart:async';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/related_revision_fixture.dart';

AcceptedAnalysis currentAnalysis(WorkbenchModel model, int snapshot) =>
    AcceptedAnalysis(
      model.analysisBinding(model.document),
      rpc.Analysis(
        operation: rpc.AnalysisOperation.COMPLETION,
        documentId: model.document.id,
        documentVersion: Int64(model.document.version),
        backendInstance: model.backend!.instanceId,
        sessionId: 's',
        sessionRevision: model.sessions['s']!.sessionRevision,
        contextRevision: model.sessions['s']!.contextRevision,
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        metadataSnapshotRevision: Int64(snapshot),
        metadataConfigurationRevision: Int64(2),
      ),
    );

void main() {
  for (final acknowledgement in ['metadata', 'transaction']) {
    test(
      'delayed status cannot regress a $acknowledgement acknowledgement',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final oldStatus = model.sessions['s']!.deepCopy();
        final started = Completer<void>();
        final pending = Completer<rpc.SessionInfo>();
        client.sessionCommand = (request) {
          if (request.action == rpc.SessionAction.SESSION_STATUS) {
            started.complete();
            return pending.future;
          }
          return Future.value(
            oldStatus.deepCopy()
              ..sessionRevision = Int64(8)
              ..commandAcknowledged = true
              ..acknowledgedAction = request.action,
          );
        };
        final polling = model.poll();
        await started.future;
        if (acknowledgement == 'metadata') {
          expect(
            model.acceptMetadataRevision(
              's',
              rpc.SchemaObjects(
                instanceId: model.backend!.instanceId,
                profileId: 'p',
                sessionId: 's',
                sessionRevision: Int64(8),
                contextRevision: Int64.ONE,
                metadataSourceIdentity: fixtureMetadataSourceIdentity,
                metadataConfigurationRevision: Int64(2),
                metadataSnapshotRevision: Int64(5),
              ),
            ),
            isTrue,
          );
        } else {
          await model.transaction(rpc.SessionAction.COMMIT);
          expect(
            model.acceptMetadataSnapshotRevision(
              's',
              5,
              2,
              sourceIdentity: fixtureMetadataSourceIdentity,
            ),
            isTrue,
          );
        }
        final acknowledged = model.sessions['s'];
        final stamp = model.metadataStampForSession('s')!;
        final analysis = currentAnalysis(model, 5);
        model.acceptedAnalysis = analysis;
        pending.complete(oldStatus);
        await polling;
        expect(model.sessions['s'], same(acknowledged));
        expect(model.sessions['s']!.sessionRevision, Int64(8));
        expect(model.metadataStampForSession('s')!.sameValue(stamp), isTrue);
        expect(model.acceptedAnalysis, same(analysis));
        expect(model.analysisResultMatches(analysis), isTrue);
        expect(model.backendStatusVerified, isFalse);
        expect(
          client.sessionCommands.where(
            (r) => r.action == rpc.SessionAction.SESSION_STATUS,
          ),
          hasLength(1),
        );
        expect(client.executions, isEmpty);
        client.sessionCommand = (_) async => acknowledged!.deepCopy();
        await model.poll();
        expect(model.backendStatusVerified, isTrue);
        expect(model.acceptedAnalysis, same(analysis));
        expect(
          client.sessionCommands.where(
            (r) => r.action == rpc.SessionAction.SESSION_STATUS,
          ),
          hasLength(2),
        );
      },
    );
  }

  test(
    'status after reviewed disconnect cannot restore a retired session',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final oldStatus = model.sessions['s']!.deepCopy();
      final started = Completer<void>();
      final pending = Completer<rpc.SessionInfo>();
      client.sessionCommand = (request) {
        if (request.action == rpc.SessionAction.SESSION_STATUS) {
          started.complete();
          return pending.future;
        }
        expect(request.action, rpc.SessionAction.DISCONNECT);
        return Future.value(
          model.sessions['s']!.deepCopy()
            ..transaction = rpc.TransactionState.DISCONNECTED,
        );
      };
      final polling = model.poll();
      await started.future;
      await model.transaction(rpc.SessionAction.DISCONNECT);
      expect(model.sessions.containsKey('s'), isFalse);
      expect(model.document.sessionId, isNull);
      pending.complete(oldStatus);
      await polling;
      expect(model.sessions.containsKey('s'), isFalse);
      expect(model.document.sessionId, isNull);
      expect(model.metadataStampForSession('s'), isNull);
      expect(model.backendStatusVerified, isFalse);
      expect(client.sessionCommands.map((r) => r.action), [
        rpc.SessionAction.SESSION_STATUS,
        rpc.SessionAction.DISCONNECT,
      ]);
      expect(client.executions, isEmpty);
    },
  );

  for (final terminal in [
    rpc.TransactionState.UNKNOWN_TRANSACTION,
    rpc.TransactionState.DISCONNECTED,
  ]) {
    test(
      'equal-revision status cannot clear newly observed $terminal',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final oldStatus = model.sessions['s']!.deepCopy()
          ..transaction = rpc.TransactionState.ACTIVE;
        final started = Completer<void>();
        final pending = Completer<rpc.SessionInfo>();
        client.sessionCommand = (_) {
          started.complete();
          return pending.future;
        };
        final polling = model.poll();
        await started.future;
        model.sessions['s']!.transaction = terminal;
        final prior = model.sessions['s'];
        expect(model.metadataStampForSession('s'), isNull);
        pending.complete(oldStatus);
        await polling;
        expect(model.sessions['s'], same(prior));
        expect(model.sessions['s']!.transaction, terminal);
        expect(model.metadataStampForSession('s'), isNull);
        expect(model.backendStatusVerified, isFalse);
        client.sessionCommand = (_) async => prior!.deepCopy();
        await model.poll();
        expect(model.backendStatusVerified, isTrue);
        expect(model.sessions['s']!.transaction, terminal);
        expect(client.executions, isEmpty);
      },
    );
  }

  for (final invalid in [
    'reply id',
    'reply profile',
    'changed profile',
    'negative physical',
    'negative context',
    'older physical',
    'older context',
  ]) {
    test(
      'status $invalid rejects before owner or analysis assignment',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final reply = model.sessions['s']!.deepCopy();
        final started = Completer<void>();
        final pending = Completer<rpc.SessionInfo>();
        client.sessionCommand = (_) {
          started.complete();
          return pending.future;
        };
        final polling = model.poll();
        await started.future;
        switch (invalid) {
          case 'reply id':
            reply.sessionId = 'other';
          case 'reply profile':
            reply.profile.id = 'other';
          case 'changed profile':
            model.sessions['s']!.profile.name = 'Changed owner';
          case 'negative physical':
            reply.sessionRevision = Int64(-1);
          case 'negative context':
            reply.contextRevision = Int64(-1);
          case 'older physical':
            reply.sessionRevision = Int64(6);
            reply.contextRevision = Int64(2);
          case 'older context':
            reply.sessionRevision = Int64(8);
            reply.contextRevision = Int64.ZERO;
        }
        final prior = model.sessions['s'];
        final analysis = currentAnalysis(model, 10);
        model.acceptedAnalysis = analysis;
        pending.complete(reply);
        await polling;
        expect(model.sessions.keys, ['s']);
        expect(model.sessions['s'], same(prior));
        expect(model.acceptedAnalysis, same(analysis));
        expect(model.metadataRevisionForSession('s'), (
          snapshot: 10,
          configuration: 2,
        ));
        expect(model.backendStatusVerified, isFalse);
        expect(client.executions, isEmpty);
      },
    );
  }

  for (final valid in ['equal', 'new physical', 'new context', 'unknown']) {
    test('current $valid status remains a verified read', () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final reply = model.sessions['s']!.deepCopy();
      final accepted = currentAnalysis(model, 10);
      model.acceptedAnalysis = accepted;
      switch (valid) {
        case 'new physical':
          reply.sessionRevision = Int64(8);
        case 'new context':
          reply.contextRevision = Int64(2);
        case 'unknown':
          reply.transaction = rpc.TransactionState.UNKNOWN_TRANSACTION;
      }
      client.sessionCommand = (_) async => reply;
      await model.poll();
      expect(model.sessions['s'], same(reply));
      expect(model.backendStatusVerified, isTrue);
      expect(
        model.acceptedAnalysis,
        valid != 'equal' ? isNull : same(accepted),
      );
      expect(
        model.metadataRevisionForSession('s'),
        valid == 'unknown'
            ? null
            : (
                snapshot: valid == 'new physical' || valid == 'new context'
                    ? 0
                    : 10,
                configuration: 2,
              ),
      );
      expect(
        client.sessionCommands.single.action,
        rpc.SessionAction.SESSION_STATUS,
      );
      expect(client.executions, isEmpty);
    });
  }
  test(
    'unknown becoming disconnected remains a physical fact without resolving draft outcomes',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      model.sessions['s']!.transaction =
          rpc.TransactionState.UNKNOWN_TRANSACTION;
      final batch = OwnedEditBatch(model.document.id, 'retained-result')
        ..sessionId = 's'
        ..draftId = 'unknown-draft'
        ..outcomeUnknown = true;
      model.editBatches['retained-result'] = batch;
      model.editDrafts.add(
        rpc.EditDraftInfo(draftId: 'unknown-draft', state: 'UNKNOWN_OUTCOME'),
      );
      client.sessionCommand = (_) async =>
          model.sessions['s']!.deepCopy()
            ..transaction = rpc.TransactionState.DISCONNECTED;
      await model.poll();
      expect(
        model.sessions['s']!.transaction,
        rpc.TransactionState.DISCONNECTED,
      );
      expect(model.backendStatusVerified, isTrue);
      expect(model.metadataStampForSession('s'), isNull);
      expect(model.editBatches['retained-result'], same(batch));
      expect(batch.outcomeUnknown, isTrue);
      expect(batch.draftId, 'unknown-draft');
      expect(model.editDrafts.single.state, 'UNKNOWN_OUTCOME');
      expect(
        model.document.sessionId,
        's',
        reason:
            'Observing status is not an explicit reviewed disconnect acknowledgement',
      );
      expect(
        client.sessionCommands.single.action,
        rpc.SessionAction.SESSION_STATUS,
      );
      expect(client.executions, isEmpty);
    },
  );

  for (final source in ['', 'x' * 64, 'b' * 64]) {
    test(
      'status with non-authoritative source $source cannot change the physical owner',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final prior = model.sessions['s']!,
            stamp = model.metadataStampForSession('s')!;
        final accepted = currentAnalysis(model, 10);
        model.acceptedAnalysis = accepted;
        client.sessionCommand = (_) async =>
            prior.deepCopy()..metadataSourceIdentity = source;
        await model.poll();
        expect(model.sessions['s'], same(prior));
        expect(model.acceptedAnalysis, same(accepted));
        expect(model.metadataStampForSession('s')!.sameValue(stamp), isTrue);
        expect(model.backendStatusVerified, isFalse);
        expect(client.executions, isEmpty);
      },
    );
  }
}
