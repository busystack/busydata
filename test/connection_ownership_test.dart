import 'dart:async';
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:busydata/src/backend/connection_failure.dart';
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  late Directory root;
  late WorkbenchModel model;
  late TestBackend backend;

  SessionInfo sessionReply(SessionInfo owner, SessionRequest request) {
    expect(request.sessionId, owner.sessionId);
    final reply = owner.deepCopy();
    if (request.action == SessionAction.DISCONNECT) {
      reply.transaction = TransactionState.DISCONNECTED;
    }
    return reply;
  }

  SessionInfo openedSessionReply(SessionRequest request) {
    // This is the captured backend's physical fixture owner, independent of
    // the model's current backend or a same-ID replacement in its UI map.
    final owner = backend.client.openedSessionOwners[request.sessionId];
    if (owner == null) throw StateError('Missing opened fixture owner');
    return sessionReply(owner, request);
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('busydata-connect-');
    backend = TestBackend();
    model = WorkbenchModel(root)
      ..draftRecovery = false
      ..newDocument();
    model.backend = backend;
    backend.client.sessionCommand = (request) async =>
        openedSessionReply(request);
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });
  test(
    'rebound metadata owner cancels a pending later page and releases its prefix',
    () async {
      final owner = model.activeOwner
        ..profileId = 'p'
        ..sessionId = 's';
      model.sessions['s'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 's',
        profile: Profile(id: 'p', engine: Engine.POSTGRESQL),
        currentCatalog: 'second',
        currentSchema: 'audit',
      );
      metadataFixture(model);
      final late = Completer<SchemaObjects>();
      backend.client.metadataAction = (r) => r.continuation.isEmpty
          ? Future.value(
              SchemaObjects(
                complete: false,
                continuation: 'next',
                objects: [SchemaObject(kind: ObjectKind.COLUMN, name: 'first')],
              ),
            )
          : late.future;
      final before = model.documentBudget.units;
      final read = model.readMetadata(
        model.captureTarget(owner: owner),
        ExploreRequest(
          kind: ObjectKind.COLUMN,
          catalog: 'second',
          schema: 'audit',
          table: 'wide',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(backend.client.metadataRequests, hasLength(2));
      owner.sessionId = 'replacement';
      model.updateStatus('Owner changed');
      late.complete(
        SchemaObjects(
          complete: true,
          objects: [SchemaObject(kind: ObjectKind.COLUMN, name: 'late')],
        ),
      );
      await expectLater(read, throwsStateError);
      expect(backend.client.cancelledMetadataRequests, greaterThanOrEqualTo(1));
      expect(model.documentBudget.units, before);
      expect(backend.client.executions, isEmpty);
    },
  );
  for (final scenario in [
    'short byte page',
    'repeated cursor',
    'duplicate object',
    'revision changed',
    'wrong scope',
    'resource limit',
    'unavailable',
  ]) {
    test(
      'bounded metadata $scenario retains its captured owner and never adopts a prefix',
      () async {
        final owner = model.activeOwner
          ..profileId = 'p'
          ..sessionId = 's';
        model.sessions['s'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 's',
          profile: Profile(id: 'p', engine: Engine.POSTGRESQL),
          currentCatalog: 'second',
          currentSchema: 'audit',
          contextRevision: Int64.ONE,
          sessionRevision: Int64.ONE,
        );
        metadataFixture(model);
        backend.client.metadataAction = (r) async {
          if (r.continuation.isNotEmpty && scenario == 'revision changed') {
            model.sessions['s']!.contextRevision = Int64(2);
          }
          return SchemaObjects(
            complete:
                r.continuation.isNotEmpty && scenario != 'repeated cursor',
            continuation:
                r.continuation.isEmpty || scenario == 'repeated cursor'
                ? 'next'
                : '',
            availability: scenario == 'unavailable'
                ? 'limited: narrow scope'
                : 'available',
            catalog: scenario == 'wrong scope' ? 'other' : 'second',
            objects: [
              SchemaObject(
                name: r.continuation.isEmpty || scenario == 'duplicate object'
                    ? 'c0'
                    : 'c1',
                kind: ObjectKind.COLUMN,
                properties: {
                  'ordinal': r.continuation.isEmpty ? '2' : '1',
                  'default': 'x' * 16000,
                }.entries,
              ),
            ],
          );
        };
        final before = model.documentBudget.units;
        final read = model.readMetadata(
          model.captureTarget(owner: owner),
          ExploreRequest(
            kind: ObjectKind.COLUMN,
            catalog: 'second',
            schema: 'audit',
            table: 'wide',
          ),
          maxBytes: scenario == 'resource limit' ? 100 : 65536,
        );
        if (scenario == 'short byte page') {
          final reply = await read;
          expect(reply.complete, isTrue);
          expect(reply.objects.map((o) => o.name), ['c1', 'c0']);
          expect(backend.client.metadataRequests.map((r) => r.continuation), [
            '',
            'next',
          ]);
        } else {
          await expectLater(read, throwsStateError);
        }
        expect(model.documentBudget.units, before);
        expect(
          backend.client.metadataRequests.every(
            (r) =>
                r.expectedContextRevision == Int64.ONE &&
                r.expectedSessionRevision == Int64.ONE &&
                r.catalog == 'second' &&
                r.schema == 'audit' &&
                r.table == 'wide',
          ),
          isTrue,
        );
        expect(backend.client.executions, isEmpty);
      },
    );
  }
  test(
    'acknowledged default console scope survives disconnect and disconnected recovery',
    () async {
      final profile = Profile(
        id: 'p',
        engine: Engine.POSTGRESQL,
        database: 'configured',
      );
      model.profiles.add(profile);
      backend.client.opening = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'owned',
        profile: profile,
      );
      backend.client.sessionCommand = (request) async {
        final owner =
            model.sessions[request.sessionId] ??
            backend.client.openedSessionOwners[request.sessionId]!;
        final reply = sessionReply(owner, request);
        if (request.action != SessionAction.DISCONNECT) {
          reply.currentCatalog = 'actual_database';
          reply.currentSchema = 'public';
        }
        return reply;
      };
      final document = model.document;
      await model.connect(profile, '');
      expect(document.connectionCatalog, 'actual_database');
      expect(document.connectionSchema, 'public');
      model.sessions['owned'] = model.sessions['owned']!.deepCopy()
        ..currentSchema = 'audit'
        ..contextRevision = Int64(2);
      await model.disconnectRetainedSession('owned');
      expect(document.sessionId, isNull);
      expect(document.connectionCatalog, 'actual_database');
      expect(document.connectionSchema, 'audit');
      final store = model.drafts;
      await store.save([document], 0);
      final restored = await store.load();
      try {
        expect(restored.single.connectionCatalog, 'actual_database');
        expect(restored.single.connectionSchema, 'audit');
        expect(restored.single.sessionId, isNull);
        expect(restored.single.profileId, profile.id);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened, hasLength(1));
      } finally {
        for (final draft in restored) {
          draft.dispose();
        }
      }
    },
  );
  test(
    'ordinary console disconnect retains its last acknowledged schema without changing other documents',
    () async {
      final first = model.document;
      first.profileId = 'p';
      first.sessionId = 'owned';
      model.sessions['owned'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'owned',
        profile: Profile(id: 'p'),
        currentCatalog: 'second_database',
        currentSchema: 'audit',
      );
      model.newDocument();
      final unrelated = model.document;
      unrelated.connectionCatalog = 'unrelated';
      final physicalOwner = model.sessions['owned']!.deepCopy();
      backend.client.sessionCommand = (request) async =>
          sessionReply(physicalOwner, request);
      await model.transaction(
        SessionAction.DISCONNECT,
        target: model.captureTarget(owner: model.workbenchDocuments.first),
      );
      expect(first.connectionCatalog, 'second_database');
      expect(first.connectionSchema, 'audit');
      expect(first.sessionId, isNull);
      expect(unrelated.connectionCatalog, 'unrelated');
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'independent table acquisition sends the exact catalog and PostgreSQL schema',
    () async {
      final profile = Profile(id: 'p', engine: Engine.POSTGRESQL);
      final table = model.openTask(
        WorkbenchDocumentKind.table,
        'duplicate',
        object: DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'configured_database',
          schema: 'audit',
          name: 'duplicate',
          kind: ObjectKind.TABLE,
        ),
      );
      backend.client.opening = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'table-owned',
        profile: request.profile,
      );
      await model.connect(profile, '', targetOwner: table);
      expect(backend.client.opened.single.catalog, 'configured_database');
      expect(backend.client.opened.single.schema, 'audit');
      expect(table.sessionId, 'table-owned');
      expect(model.document.sessionId, isNull);
    },
  );
  test(
    'choosing another saved profile clears the former offline catalog/schema intent',
    () {
      model.profiles.addAll([Profile(id: 'a'), Profile(id: 'b')]);
      model.bindUnconnectedProfile(model.activeOwner, 'a');
      model.document.connectionCatalog = 'old_database';
      model.document.connectionSchema = 'old_schema';
      model.bindUnconnectedProfile(model.activeOwner, 'b');
      expect(model.document.connectionCatalog, '');
      expect(model.document.connectionSchema, '');
      expect(backend.client.opened, isEmpty);
    },
  );
  test(
    'an unattached uncertain session disconnects independently of an unrelated closing SQL owner',
    () async {
      final original = model.document;
      model.sessions['orphan'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'orphan',
        transaction: TransactionState.UNKNOWN_TRANSACTION,
        profile: Profile(
          id: 'original-profile',
          name: 'Original production',
          environment: Environment.PRODUCTION,
        ),
      );
      final captured = model.captureSessionTarget('orphan');
      final gate = Completer<Approval>();
      backend.client.sessionReview = (_) => gate.future;
      final physicalOwner = model.sessions['orphan']!.deepCopy();
      backend.client.sessionCommand = (request) async =>
          sessionReply(physicalOwner, request);
      final operation = model.disconnectRetainedSession(
        'orphan',
        reviewedTarget: captured,
      );
      expect(model.pendingCommands.keys, ['session:orphan']);
      model.newDocument();
      await model.closeDocument(original, reviewedRevision: original.version);
      model.requireTarget(captured);
      gate.complete(Approval(token: 'orphan-disconnect-review'));
      await operation;
      expect(backend.client.sessionCommands.single.sessionId, 'orphan');
      expect(backend.client.sessionCommands.single.force, isTrue);
      expect(model.sessions, isEmpty);
      expect(model.document.sessionId, isNull);
      expect(model.pendingOperations, 0);
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'session cleanup review rejects a changed backend and changed live context without dispatch',
    () async {
      model.sessions['orphan'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'orphan',
        transaction: TransactionState.UNKNOWN_TRANSACTION,
      );
      final captured = model.captureSessionTarget('orphan');
      final gate = Completer<Approval>();
      backend.client.sessionReview = (_) => gate.future;
      final operation = model.disconnectRetainedSession(
        'orphan',
        reviewedTarget: captured,
      );
      final rejected = expectLater(operation, throwsStateError);
      model.backend = TestBackend(instanceId: 'replacement');
      gate.complete(Approval(token: 'obsolete-review'));
      await rejected;
      expect(backend.client.sessionCommands, isEmpty);
      expect(model.sessions, contains('orphan'));
      expect(model.pendingOperations, 0);
      model.backend = backend;
      model.sessions['orphan'] = model.sessions['orphan']!.deepCopy()
        ..contextRevision += 1;
      expect(() => model.requireTarget(captured), throwsStateError);
      expect(() => model.captureSessionTarget('missing'), throwsStateError);
    },
  );
  test(
    'unconnected profile rebinding invalidates captured operations without opening a session',
    () async {
      model.profiles.addAll([Profile(id: 'a'), Profile(id: 'b')]);
      final owner = model.activeOwner;
      model.bindUnconnectedProfile(owner, 'a');
      final captured = model.captureTarget(owner: owner);
      model.bindUnconnectedProfile(owner, 'b');
      expect(() => model.requireTarget(captured), throwsStateError);
      var sent = false;
      await expectLater(
        model.ownedRequest(captured, () async {
          sent = true;
        }),
        throwsStateError,
      );
      expect(sent, isFalse);
      expect(owner.sessionId, isNull);
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'generated and object evidence reject a changed independent target but existing sessions retain ownership',
    () async {
      final original = Profile(
        id: 'p',
        name: 'Production',
        engine: Engine.POSTGRESQL,
        host: 'original',
        environment: Environment.PRODUCTION,
      );
      final replacement = original.deepCopy()..host = 'replacement';
      model.profiles.add(replacement);
      final owner = model.activeOwner;
      owner.profileId = 'p';
      owner.evidenceProfile = original.deepCopy();
      expect(() => model.connect(replacement, 'secret'), throwsStateError);
      expect(backend.client.opened, isEmpty);
      expect(owner.sessionId, isNull);
      final captured = model.captureTarget(owner: owner);
      expect(captured.profile!.host, 'original');
      expect(
        () => model.requireTarget(captured, profile: true),
        throwsStateError,
      );

      owner.sessionId = 'live';
      model.sessions['live'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'live',
        profile: original,
      );
      final live = model.captureTarget(owner: owner);
      model.requireTarget(live);
      expect(live.profile!.host, 'original');
      owner.sessionId = null;
      model.bindUnconnectedProfile(owner, 'p');
      expect(owner.evidenceProfile, isNull);
      model.requireTarget(model.captureTarget(owner: owner));
    },
  );
  test(
    'a saved target change invalidates captured connection acquisition while name and credential rotation do not',
    () {
      final profile = Profile(id: 'p', host: 'original');
      model.profiles.add(profile);
      model.document.profileId = profile.id;
      final captured = model.captureTarget();
      profile.name = 'Renamed';
      profile.credentialRef = 'private-new-record';
      model.requireTarget(captured, profile: true);
      profile.host = 'replacement';
      expect(
        () => model.requireTarget(captured, profile: true),
        throwsStateError,
      );
      expect(backend.client.opened, isEmpty);
    },
  );
  test(
    'F10 closing an opening target disposes the unused new session',
    () async {
      final reply = Completer<SessionInfo>(), started = Completer<void>();
      backend.client.opening = (_) {
        started.complete();
        return reply.future;
      };
      final target = model.document;
      final connecting = model.connect(Profile(id: 'p'), 'secret');
      await started.future;
      model.newDocument();
      model.documents.remove(target);
      target.dispose();
      model.selected = 0;
      reply.complete(
        SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'new',
          profile: Profile(id: 'p'),
          autoCommit: true,
        ),
      );
      await connecting;
      expect(model.sessions, isEmpty);
      expect(
        backend.client.sessionCommands
            .where((r) => r.action == SessionAction.DISCONNECT)
            .map((r) => r.sessionId),
        contains('new'),
      );
      expect(model.document.sessionId, isNull);
    },
  );
  void existing({TransactionState state = TransactionState.IDLE}) {
    model.document.sessionId = 'old';
    model.document.profileId = 'original';
    model.sessions['old'] = SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'old',
      profile: Profile(id: 'original'),
      transaction: state,
      contextRevision: Int64.ONE,
      sessionRevision: Int64(7),
      autoCommit: true,
    );
    final physicalOwner = model.sessions['old']!.deepCopy();
    backend.client.sessionCommand = (request) async =>
        request.sessionId == 'old'
        ? sessionReply(physicalOwner, request)
        : openedSessionReply(request);
  }

  test(
    'a duplicate Open identity cannot clean up an already-known current handle',
    () async {
      existing();
      final previousOwner = model.sessions['old']!.deepCopy();
      backend.client.opening = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'old',
        profile: request.profile.deepCopy(),
        autoCommit: true,
      );
      await expectLater(
        model.connect(Profile(id: 'new'), 'secret'),
        throwsA(
          isA<LocalWorkbenchFailure>().having(
            (failure) => failure.reason,
            'reason',
            WorkbenchFailureReason.invalidOwner,
          ),
        ),
      );
      expect(model.document.sessionId, 'old');
      expect(model.document.profileId, 'original');
      expect(model.sessions.keys, ['old']);
      expect(model.sessions['old'], previousOwner);
      expect(backend.client.opened, hasLength(1));
      expect(
        backend.client.sessionCommands.where(
          (request) => request.action != SessionAction.SESSION_STATUS,
        ),
        isEmpty,
      );
      expect(backend.client.executions, isEmpty);
    },
  );
  test(
    'failed reconnect preserves the existing session and profile association',
    () async {
      existing();
      backend.client.opening = (_) async =>
          throw const SocketException('connection failure');
      await expectLater(
        model.connect(Profile(id: 'replacement'), 'secret'),
        throwsA(isA<ConnectionAttemptFailure>()),
      );
      expect(model.document.sessionId, 'old');
      expect(model.document.profileId, 'original');
      expect(model.sessions.keys, ['old']);
      expect(
        backend.client.sessionCommands.where(
          (r) => r.action == SessionAction.DISCONNECT,
        ),
        isEmpty,
      );
    },
  );
  test(
    'transactions, running jobs, and staged edits must be explicitly resolved before opening',
    () async {
      existing(state: TransactionState.ACTIVE);
      await expectLater(
        model.connect(Profile(id: 'replacement'), 'secret'),
        throwsStateError,
      );
      expect(backend.client.opened, isEmpty);
      expect(model.document.sessionId, 'old');
      existing();
      model.jobs['j'] = JobInfo(
        jobId: 'j',
        sessionId: 'old',
        state: JobState.EXECUTING,
      );
      await expectLater(
        model.connect(Profile(id: 'replacement'), 'secret'),
        throwsStateError,
      );
      expect(backend.client.opened, isEmpty);
      model.jobs.clear();
      model.stagedSession = 'old';
      model.staged.add(StagedChange());
      await expectLater(
        model.connect(Profile(id: 'replacement'), 'secret'),
        throwsStateError,
      );
      expect(backend.client.opened, isEmpty);
    },
  );
  test(
    'a newer request wins while the unused opened session is disposed',
    () async {
      existing();
      final started = Completer<void>(), firstReply = Completer<SessionInfo>();
      backend.client.opening = (r) {
        if (r.profile.id == 'first') {
          started.complete();
          return firstReply.future;
        }
        return Future.value(
          SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'second',
            profile: r.profile.deepCopy(),
            autoCommit: true,
          ),
        );
      };
      final first = model.connect(Profile(id: 'first'), 'a');
      await started.future;
      final second = model.connect(Profile(id: 'second'), 'b');
      firstReply.complete(
        SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'first',
          profile: Profile(id: 'first'),
          autoCommit: true,
        ),
      );
      await first;
      await second;
      expect(model.document.sessionId, 'second');
      expect(model.sessions.keys, ['second']);
      expect(
        backend.client.sessionCommands
            .where((r) => r.action == SessionAction.DISCONNECT)
            .map((r) => r.sessionId),
        ['first', 'old'],
      );
    },
  );
  test(
    'switching tabs during opening attaches the captured target and keeps shared sessions reachable',
    () async {
      existing();
      final target = model.document;
      model.newDocument();
      model.document.sessionId = 'old';
      model.select(0);
      final started = Completer<void>(), reply = Completer<SessionInfo>();
      backend.client.opening = (_) {
        started.complete();
        return reply.future;
      };
      final connecting = model.connect(Profile(id: 'new'), 'secret');
      await started.future;
      model.select(1);
      reply.complete(
        SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'new',
          profile: Profile(id: 'new'),
          autoCommit: true,
        ),
      );
      await connecting;
      expect(target.sessionId, 'new');
      expect(model.document.sessionId, 'old');
      expect(model.sessions.keys.toSet(), {'new', 'old'});
      expect(
        backend.client.sessionCommands.where(
          (r) => r.action == SessionAction.DISCONNECT,
        ),
        isEmpty,
      );
    },
  );
  test(
    'failed old-session disconnect disposes replacement and preserves association',
    () async {
      existing();
      final previousOwner = model.sessions['old']!.deepCopy();
      backend.client.opening = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'new',
        profile: request.profile.deepCopy(),
        autoCommit: true,
      );
      backend.client.sessionCommand = (r) async {
        if (r.sessionId == 'old' && r.action == SessionAction.DISCONNECT) {
          throw StateError('transaction began');
        }
        return r.sessionId == 'old'
            ? sessionReply(previousOwner, r)
            : openedSessionReply(r);
      };
      await expectLater(
        model.connect(Profile(id: 'new'), 'secret'),
        throwsStateError,
      );
      expect(model.document.sessionId, 'old');
      expect(model.sessions.keys, ['old']);
      expect(
        backend.client.sessionCommands
            .where((r) => r.action == SessionAction.DISCONNECT)
            .map((r) => r.sessionId),
        ['old', 'new'],
      );
    },
  );
  for (final rebind in [false, true]) {
    test(
      'late ${rebind ? 'rebind' : 'cancellation'} after acknowledged old disconnect cannot adopt a replacement',
      () async {
        existing();
        final previousOwner = model.sessions['old']!.deepCopy();
        late SessionRequest disconnectRequest;
        final started = Completer<void>(), reply = Completer<SessionInfo>();
        var allowed = true;
        backend.client.opening = (request) async => SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'replacement',
          profile: request.profile.deepCopy(),
          autoCommit: true,
        );
        backend.client.sessionCommand = (r) async {
          if (r.sessionId == 'old' && r.action == SessionAction.DISCONNECT) {
            disconnectRequest = r.deepCopy();
            started.complete();
            return reply.future;
          }
          return r.sessionId == 'old'
              ? sessionReply(previousOwner, r)
              : openedSessionReply(r);
        };
        final attempt = model.connect(
          Profile(id: 'new'),
          'secret',
          mayAdopt: () => allowed,
        );
        await started.future;
        if (rebind) {
          model.profiles.add(Profile(id: 'other'));
          model.document.sessionId = null;
          model.bindUnconnectedProfile(model.activeOwner, 'other');
        } else {
          allowed = false;
        }
        reply.complete(sessionReply(previousOwner, disconnectRequest));
        await attempt;
        expect(model.document.sessionId, isNull);
        expect(model.document.profileId, rebind ? 'other' : 'original');
        expect(model.sessions, isEmpty);
        expect(
          backend.client.sessionCommands
              .where((r) => r.action == SessionAction.DISCONNECT)
              .map((r) => r.sessionId),
          ['old', 'replacement'],
        );
      },
    );
  }
  test(
    'backend replacement rejects adoption and cleans up the specific opened session',
    () async {
      final started = Completer<void>(), reply = Completer<SessionInfo>();
      backend.client.opening = (_) {
        started.complete();
        return reply.future;
      };
      final connecting = model.connect(Profile(id: 'new'), 'secret');
      await started.future;
      final replacementBackend = TestBackend(instanceId: 'restart');
      model.backend = replacementBackend;
      final replacementOwner = SessionInfo(
        metadataSourceIdentity:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        sessionId: 'new',
        profile: Profile(id: 'new-backend-profile'),
        contextRevision: Int64(9),
        sessionRevision: Int64(12),
        transaction: TransactionState.IDLE,
      );
      final expectedReplacement = replacementOwner.deepCopy();
      model.sessions['new'] = replacementOwner;
      reply.complete(
        SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'new',
          profile: Profile(id: 'new'),
          autoCommit: true,
        ),
      );
      await connecting;
      expect(model.document.sessionId, isNull);
      expect(model.sessions.keys, ['new']);
      expect(model.sessions['new'], same(replacementOwner));
      expect(replacementOwner, expectedReplacement);
      expect(replacementBackend.client.sessionCommands, isEmpty);
      expect(
        backend.client.sessionCommands
            .where((r) => r.action == SessionAction.DISCONNECT)
            .map((r) => r.sessionId),
        ['new'],
      );
    },
  );
  test(
    'failed unused-session cleanup retains a visible quarantined owner and preserves the primary reconnect failure',
    () async {
      model.document.sessionId = 'previous';
      model.sessions['previous'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'previous',
        transaction: TransactionState.IDLE,
      );
      final previousOwner = model.sessions['previous']!.deepCopy();
      backend.client.opening = (request) async => SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'replacement',
        profile: request.profile.deepCopy(),
      );
      backend.client.sessionCommand = (request) async {
        if (request.action == SessionAction.DISCONNECT) {
          throw StateError(
            request.sessionId == 'previous'
                ? 'Primary disconnect failure'
                : 'Cleanup failed',
          );
        }
        return request.sessionId == 'previous'
            ? sessionReply(previousOwner, request)
            : openedSessionReply(request);
      };
      await expectLater(
        model.connect(Profile(id: 'profile'), 'password'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'primary',
            'Primary disconnect failure',
          ),
        ),
      );
      expect(model.document.sessionId, 'previous');
      expect(model.sessions.keys, containsAll(['previous', 'replacement']));
      expect(
        model.sessions['replacement']!.transaction,
        TransactionState.UNKNOWN_TRANSACTION,
      );
      final quarantinedOwner = model.sessions['replacement']!.deepCopy();
      backend.client.sessionCommand = (request) async =>
          sessionReply(quarantinedOwner, request);
      await model.disconnectRetainedSession('replacement');
      expect(backend.client.sessionCommands.last.force, isTrue);
      expect(model.sessions.keys, ['previous']);
    },
  );
}
