import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/features/workspace/browse_target_selection.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/browse_selection_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late TestBackend backend;
  late WorkbenchModel model;
  late WorkbenchDocument owner;
  late PreparedBrowseFixture fixture;
  const hint = DatabaseObjectIdentity(
    profileId: 'p',
    catalog: 'db',
    schema: 'public',
    kind: rpc.ObjectKind.TABLE,
    subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
    name: 'Orders',
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('browse-selection-');
    backend = TestBackend();
    final profile = rpc.Profile(id: 'p', engine: rpc.Engine.POSTGRESQL);
    model = WorkbenchModel(root)
      ..draftRecovery = false
      ..backend = backend
      ..profiles.add(profile)
      ..newDocument(text: 'SELECT untouched');
    owner = model.openTask(WorkbenchDocumentKind.table, hint.name, object: hint)
      ..sessionId = 's';
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
    fixture = PreparedBrowseFixture(
      relation: rpc.SchemaObject(
        kind: rpc.ObjectKind.TABLE,
        subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
        name: hint.name,
        catalog: hint.catalog,
        schema: hint.schema,
        stableIdentity: 'java-native-relation-A',
      ),
      columns: [
        for (final name in ['id', 'note'])
          rpc.SchemaObject(
            kind: rpc.ObjectKind.COLUMN,
            name: name,
            table: hint.name,
            catalog: hint.catalog,
            schema: hint.schema,
            stableIdentity: 'java-native-column-$name',
            parentIdentity: 'java-native-relation-A',
          ),
      ],
    );
    fixture.install(model, backend);
  });
  tearDown(() async {
    model.dispose();
    await root.delete(recursive: true);
  });
  Matcher failure(WorkbenchFailureReason reason) => isA<LocalWorkbenchFailure>()
      .having((error) => error.reason, 'typed reason', reason);
  Future<BrowseTargetSelection> prepare({BrowseSelectionEvidence? evidence}) =>
      BrowseSelectionController(
        model,
      ).prepare(model.captureTarget(owner: owner), hint, evidence: evidence);

  test(
    'cold structural enrichment precedes request creation and receives one column only',
    () async {
      final logicalKey = hint.key;
      final selected = await prepare();
      expect(backend.client.metadataRequests.map((request) => request.kind), [
        rpc.ObjectKind.TABLE,
        rpc.ObjectKind.COLUMN,
        rpc.ObjectKind.TABLE,
      ]);
      expect(backend.client.metadataRequests.map((request) => request.limit), [
        2,
        1,
        2,
      ]);
      expect(
        backend.client.metadataRequests.every(
          (request) => request.continuation.isEmpty,
        ),
        isTrue,
      );
      expect(
        backend.client.metadataRequests.map(
          (request) => request.introspectionLevel,
        ),
        [2, 2, 2],
      );
      expect(
        backend.client.metadataRequests.every(
          (request) =>
              request.expectedSessionRevision == Int64.ONE &&
              request.expectedContextRevision == Int64.ONE,
        ),
        isTrue,
      );
      expect(selected.snapshotRevision, 11);
      final request = selected.request(
        model,
        executionId: 'explicit-action',
        rowLimit: Int64(50),
      );
      expect(request.metadataObjectIdentity, 'java-native-relation-A');
      expect(request.metadataSnapshotRevision, Int64(11));
      expect(
        (request.catalog, request.schema, request.table),
        ('db', 'public', 'Orders'),
      );
      expect(request.originRelationshipIdentity, isEmpty);
      expect(hint.key, logicalKey);
      expect(backend.client.browseReviews, isEmpty);
      expect(backend.client.browseRequests, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );

  for (final (kind, subtype) in const [
    (rpc.ObjectKind.TABLE, rpc.ObjectSubtype.ORDINARY_TABLE),
    (rpc.ObjectKind.TABLE, rpc.ObjectSubtype.PARTITIONED_TABLE),
    (rpc.ObjectKind.TABLE, rpc.ObjectSubtype.FOREIGN_TABLE),
    (rpc.ObjectKind.VIEW, rpc.ObjectSubtype.REGULAR_VIEW),
    (rpc.ObjectKind.VIEW, rpc.ObjectSubtype.MATERIALIZED_VIEW),
  ]) {
    test(
      '$kind/$subtype lookup keeps descriptor subtype out of routine filters',
      () async {
        final relation = fixture.relation.deepCopy()
          ..kind = kind
          ..subtype = subtype;
        final prepared = PreparedBrowseFixture(
          relation: relation,
          columns: fixture.columns,
        );
        backend.client.metadataAction = (request) async =>
            prepared.reply(model, backend, request);
        final logical = DatabaseObjectIdentity(
          profileId: hint.profileId,
          catalog: hint.catalog,
          schema: hint.schema,
          name: hint.name,
          kind: kind,
          subtype: relation.subtype,
        );
        final selected = await BrowseSelectionController(
          model,
        ).prepare(model.captureTarget(owner: owner), logical);
        expect(selected.object.kind, kind);
        expect(selected.object.subtype, relation.subtype);
        expect(
          backend.client.metadataRequests.map((request) => request.subtype),
          List.filled(3, rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED),
        );
        expect(
          selected
              .request(model, executionId: 'readonly', rowLimit: Int64(5))
              .metadataObjectIdentity,
          relation.stableIdentity,
        );
      },
    );
  }

  for (final broken in [
    'denied',
    'limited',
    'no count',
    'zero columns',
    'wrong parent',
    'oversized projection',
    'wrong owner',
    'changed config',
    'publication after columns',
  ]) {
    test('preparation rejects $broken without Review or SQL', () async {
      var calls = 0;
      backend.client.metadataAction = (request) async {
        final reply = fixture.reply(model, backend, request);
        calls++;
        if (calls == 2) {
          switch (broken) {
            case 'denied':
              reply.metadataState = 'DENIED';
            case 'limited':
              reply.metadataState = 'LIMITED';
            case 'no count':
              reply.clearTotalCount();
            case 'zero columns':
              reply.objects.clear();
              reply.totalCount = Int64.ZERO;
            case 'wrong parent':
              reply.objects.single.parentIdentity = 'foreign-parent';
            case 'oversized projection':
              reply.objects.single.definition = 'x' * 65537;
            case 'wrong owner':
              reply.sessionId = 'foreign-session';
            case 'changed config':
              reply.metadataConfigurationRevision = Int64(3);
          }
        }
        if (calls == 3 && broken == 'publication after columns') {
          reply.metadataSnapshotRevision = Int64(12);
          reply.objects.single.metadataSnapshotRevision = Int64(12);
        }
        return reply;
      };
      await expectLater(prepare(), throwsA(isA<LocalWorkbenchFailure>()));
      expect(calls, lessThanOrEqualTo(3));
      expect(backend.client.browseReviews, isEmpty);
      expect(backend.client.browseRequests, isEmpty);
      expect(backend.client.executions, isEmpty);
    });
  }

  for (final changed in [
    'context',
    'session',
    'profile',
    'backend',
    'metadata',
    'document',
  ]) {
    test(
      'superseded $changed cancels one pending metadata request and never loops',
      () async {
        final pending = Completer<rpc.SchemaObjects>();
        backend.client.metadataAction = (_) => pending.future;
        final future = prepare();
        final outcome = expectLater(
          future,
          throwsA(isA<LocalWorkbenchFailure>()),
        );
        await Future<void>.delayed(Duration.zero);
        switch (changed) {
          case 'context':
            model.sessions['s']!.contextRevision = Int64(2);
          case 'session':
            owner.sessionId = 'different';
          case 'profile':
            model.sessions['s']!.profile =
                model.sessions['s']!.profile.deepCopy()..host = 'changed';
          case 'backend':
            model.backend = TestBackend(instanceId: 'restarted');
          case 'metadata':
            model.acceptMetadataSnapshotRevision(
              's',
              99,
              2,
              sourceIdentity: fixtureMetadataSourceIdentity,
            );
          case 'document':
            owner.sessionId = null;
        }
        model.updateStatus('Explicit owner change');
        await outcome;
        expect(
          backend.client.cancelledMetadataRequests,
          greaterThanOrEqualTo(1),
        );
        expect(backend.client.metadataRequests, hasLength(1));
        expect(backend.client.browseReviews, isEmpty);
        pending.complete(rpc.SchemaObjects());
      },
    );
  }

  test(
    'live selection cannot change stable identity during explicit resolution',
    () async {
      final original = fixture
          .reply(
            model,
            backend,
            rpc.ExploreRequest(
              sessionId: 's',
              catalog: 'db',
              schema: 'public',
              kind: rpc.ObjectKind.TABLE,
              exactName: true,
              search: hint.name,
              limit: 2,
            ),
          )
          .objects
          .single;
      final evidence = BrowseSelectionEvidence(
        source: model.captureSessionTarget('s'),
        projection: original,
        configurationRevision: 2,
      );
      backend.client.metadataAction = (request) async {
        final reply = fixture.reply(model, backend, request);
        reply.objects.single.stableIdentity = 'replacement-object';
        return reply;
      };
      await expectLater(
        prepare(evidence: evidence),
        throwsA(failure(WorkbenchFailureReason.stale)),
      );
      expect(backend.client.metadataRequests, hasLength(1));
      expect(backend.client.browseReviews, isEmpty);
    },
  );

  test(
    'prepared authority retires after another publication and is not serialized',
    () async {
      final first = await prepare();
      final beforeKey = hint.key, beforeHash = hint.hashCode;
      model.acceptMetadataSnapshotRevision(
        's',
        12,
        2,
        sourceIdentity: fixtureMetadataSourceIdentity,
      );
      expect(
        () => first.request(model, executionId: 'stale', rowLimit: Int64(5)),
        throwsA(failure(WorkbenchFailureReason.stale)),
      );
      final nextFixture = PreparedBrowseFixture(
        relation: fixture.relation,
        columns: fixture.columns,
        namesSnapshot: 12,
        structureSnapshot: 13,
      );
      backend.client.metadataAction = (request) async =>
          nextFixture.reply(model, backend, request);
      final second = await prepare();
      expect(first.object, second.object);
      expect(hint.key, beforeKey);
      expect(hint.hashCode, beforeHash);
      await model.savePresentation();
      final presentation = await File(
        '${root.path}/presentation.json',
      ).readAsString();
      expect(jsonDecode(presentation), isA<Map>());
      expect(presentation, isNot(contains('java-native-relation-A')));
      expect(presentation, isNot(contains('java-native-column-id')));
      expect(presentation, isNot(contains('metadataSnapshotRevision')));
    },
  );

  for (final state in [
    rpc.TransactionState.DISCONNECTED,
    rpc.TransactionState.UNKNOWN_TRANSACTION,
  ]) {
    test(
      'unavailable physical state $state cannot attach or begin preflight',
      () async {
        model.sessions['s']!.transaction = state;
        await expectLater(prepare(), throwsA(isA<LocalWorkbenchFailure>()));
        expect(backend.client.metadataRequests, isEmpty);
        expect(backend.client.opened, isEmpty);
      },
    );
  }
  test(
    'busy selected physical session cannot begin preflight or open another connection',
    () async {
      model.jobs['busy'] = rpc.JobInfo(
        jobId: 'busy',
        sessionId: 's',
        state: rpc.JobState.EXECUTING,
      );
      await expectLater(
        prepare(),
        throwsA(failure(WorkbenchFailureReason.unavailable)),
      );
      expect(backend.client.metadataRequests, isEmpty);
      expect(backend.client.opened, isEmpty);
    },
  );
  test(
    'only a newly created matching owner attaches the explicit selected physical session',
    () async {
      final sourceProjection = fixture
          .reply(
            model,
            backend,
            rpc.ExploreRequest(
              sessionId: 's',
              kind: rpc.ObjectKind.TABLE,
              catalog: 'db',
              schema: 'public',
              search: hint.name,
              exactName: true,
              limit: 2,
            ),
          )
          .objects
          .single;
      final evidence = BrowseSelectionEvidence(
        source: model.captureSessionTarget('s'),
        projection: sourceProjection,
        configurationRevision: 2,
      );
      final destination = model.openTask(
        WorkbenchDocumentKind.table,
        'new explicit owner',
        object: hint,
        reuse: false,
      );
      BrowseSelectionController(
        model,
      ).attachSelectedSession(destination, evidence, newlyCreated: true);
      expect(destination.sessionId, 's');
      expect(backend.client.opened, isEmpty);
      final restored = model.openTask(
        WorkbenchDocumentKind.table,
        'restored hint',
        object: hint,
        reuse: false,
      );
      expect(
        () => BrowseSelectionController(
          model,
        ).attachSelectedSession(restored, evidence, newlyCreated: false),
        throwsA(failure(WorkbenchFailureReason.invalidOwner)),
      );
      expect(restored.sessionId, isNull);
      final foreign = model.openTask(
        WorkbenchDocumentKind.table,
        'foreign bound owner',
        object: hint,
        reuse: false,
      )..sessionId = 'different';
      expect(
        () => BrowseSelectionController(
          model,
        ).attachSelectedSession(foreign, evidence, newlyCreated: true),
        throwsA(failure(WorkbenchFailureReason.invalidOwner)),
      );
      expect(foreign.sessionId, 'different');
      expect(backend.client.metadataRequests, isEmpty);
      // A restored name-only hint remains usable after a separate explicit
      // connection action has actually attached its chosen physical session.
      restored.sessionId = 's';
      final resolved = await BrowseSelectionController(
        model,
      ).prepare(model.captureTarget(owner: restored), hint);
      expect(resolved.projection.stableIdentity, 'java-native-relation-A');
      expect(backend.client.metadataRequests, hasLength(3));
    },
  );
  test(
    'missing live-selection configuration is incomplete and never becomes a name-only fallback',
    () {
      final projected = fixture
          .reply(
            model,
            backend,
            rpc.ExploreRequest(
              sessionId: 's',
              catalog: 'db',
              schema: 'public',
              kind: rpc.ObjectKind.TABLE,
              search: hint.name,
              exactName: true,
              limit: 2,
            ),
          )
          .objects
          .single;
      expect(
        () => BrowseSelectionEvidence.fromCommand(
          model,
          WorkbenchCommandContext(
            profileId: 'p',
            sessionId: 's',
            object: hint,
            metadataObject: projected,
            metadataInstance: backend.instanceId,
            metadataSources: const {
              'p': (sessionId: 's', contextRevision: 1, sessionRevision: 1),
            },
          ),
          hint,
        ),
        throwsA(failure(WorkbenchFailureReason.incompleteMetadata)),
      );
      expect(backend.client.metadataRequests, isEmpty);
      expect(backend.client.opened, isEmpty);
    },
  );
  testWidgets(
    'preparation has one bounded deadline and cancels the unfinished metadata read',
    (tester) async {
      final pending = Completer<rpc.SchemaObjects>();
      backend.client.metadataAction = (_) => pending.future;
      final operation = prepare();
      final outcome = expectLater(
        operation,
        throwsA(failure(WorkbenchFailureReason.timedOut)),
      );
      await tester.pump(const Duration(seconds: 31));
      await outcome;
      expect(backend.client.cancelledMetadataRequests, greaterThanOrEqualTo(1));
      expect(backend.client.metadataRequests, hasLength(1));
      expect(backend.client.browseReviews, isEmpty);
      pending.complete(rpc.SchemaObjects());
    },
  );

  test(
    'repeated user preparation observes existing owned-request backpressure',
    () async {
      final pending = Completer<rpc.SchemaObjects>();
      var first = true;
      backend.client.metadataAction = (request) async {
        if (first) {
          first = false;
          return pending.future;
        }
        return fixture.reply(model, backend, request);
      };
      final original = prepare();
      await Future<void>.delayed(Duration.zero);
      await expectLater(
        prepare(),
        throwsA(failure(WorkbenchFailureReason.unavailable)),
      );
      expect(backend.client.metadataRequests, hasLength(1));
      pending.complete(
        fixture.reply(model, backend, backend.client.metadataRequests.single),
      );
      expect((await original).snapshotRevision, 11);
      expect(model.pendingCommands[owner.id], isNull);
      expect(
        (await prepare()).projection.stableIdentity,
        'java-native-relation-A',
      );
      expect(backend.client.browseReviews, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );
}
