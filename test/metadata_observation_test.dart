import 'dart:async';
import 'package:busydata/l10n/generated/app_localizations_en.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/backend/workbench_failure.dart';
import 'package:busydata/src/features/workspace/browse_target_selection.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError, StatusCode;
import 'support/browse_selection_fixture.dart';
import 'support/fake_backend.dart';
import 'support/related_revision_fixture.dart';

AcceptedAnalysis acceptedAt(
  WorkbenchModel model,
  rpc.AnalysisOperation operation,
  int snapshot,
) => AcceptedAnalysis(
  model.analysisBinding(model.document),
  rpc.Analysis(
    operation: operation,
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

rpc.Analysis analysisReply(rpc.AnalysisRequest request, int snapshot) =>
    rpc.Analysis(
      operation: request.operation,
      documentId: request.documentId,
      documentVersion: request.documentVersion,
      backendInstance: request.context.instanceId,
      sessionId: request.sessionId,
      sessionRevision: request.sessionRevision,
      contextRevision: request.contextRevision,
      caretUtf16: request.caretUtf16,
      metadataSnapshotRevision: Int64(snapshot),
      metadataConfigurationRevision: Int64(2),
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      availability: 'available',
    );

const targetHint = DatabaseObjectIdentity(
  profileId: 'p',
  catalog: 'db',
  schema: 'public',
  kind: rpc.ObjectKind.TABLE,
  subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
  name: 'target',
);

PreparedBrowseFixture browseFixture(
  WorkbenchModel model, {
  int names = 10,
  int structure = 11,
  int configuration = 2,
}) {
  final fixture = PreparedBrowseFixture(
    namesSnapshot: names,
    structureSnapshot: structure,
    configuration: configuration,
    relation: rpc.SchemaObject(
      kind: rpc.ObjectKind.TABLE,
      subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
      catalog: 'db',
      schema: 'public',
      name: 'target',
      stableIdentity: 'native-target-identity',
    ),
    columns: [
      rpc.SchemaObject(
        kind: rpc.ObjectKind.COLUMN,
        catalog: 'db',
        schema: 'public',
        table: 'target',
        name: 'id',
        stableIdentity: 'native-target-id',
        parentIdentity: 'native-target-identity',
      ),
    ],
  );
  fixture.install(model, model.backend! as TestBackend);
  return fixture;
}

rpc.SchemaObjects explorerReply(
  rpc.ExploreRequest request, {
  required int snapshot,
  required List<String> names,
  int configuration = 2,
  bool complete = true,
  String defaultNamespace = '',
}) {
  final catalog = request.catalog.isEmpty ? 'db' : request.catalog;
  return rpc.SchemaObjects(
    instanceId: request.context.instanceId,
    profileId: 'p',
    sessionId: 's',
    sessionRevision: request.refresh ? Int64(8) : Int64(7),
    contextRevision: Int64.ONE,
    catalog: catalog,
    schema: request.schema,
    parent: request.table,
    kind: request.kind,
    subtype: request.subtype,
    complete: complete,
    continuation: complete ? '' : 'next-page',
    countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
    totalCount: Int64(complete ? names.length : names.length + 1),
    metadataSnapshotRevision: Int64(snapshot),
    metadataConfigurationRevision: Int64(configuration),
    metadataSourceIdentity: fixtureMetadataSourceIdentity,
    metadataState: 'AVAILABLE',
    availability: 'available',
    defaultNamespace: defaultNamespace,
    objects: [
      for (final (index, name) in names.indexed)
        rpc.SchemaObject(
          kind: request.kind,
          name: name,
          catalog: request.kind == rpc.ObjectKind.CATALOG ? name : catalog,
          schema: request.kind == rpc.ObjectKind.SCHEMA ? name : request.schema,
          table: request.table,
          metadataSnapshotRevision: Int64(snapshot),
          introspectionLevel: 2,
          metadataState: 'AVAILABLE',
          properties: {'ordinal': '${index + 1}', 'jdbcType': '4'}.entries,
        ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'newer related observation advances the shared snapshot minimum',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      model.acceptedAnalysis = acceptedAt(
        model,
        rpc.AnalysisOperation.COMPLETION,
        10,
      );
      model.acceptedDiagnostics = acceptedAt(
        model,
        rpc.AnalysisOperation.DIAGNOSTICS,
        10,
      );
      model.acceptedParameterInformation = acceptedAt(
        model,
        rpc.AnalysisOperation.PARAMETER_INFORMATION,
        10,
      );
      var notifications = 0;
      model.addListener(() => notifications++);
      final pending = model.relatedRows(relatedRequest());
      client.pending.complete(relatedReply(snapshot: 11));
      await pending;
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 11,
        configuration: 2,
      ));
      expect(model.acceptedAnalysis, isNull);
      expect(model.acceptedDiagnostics, isNull);
      expect(model.acceptedParameterInformation, isNull);
      expect(notifications, 1);
    },
  );

  test(
    'newer related observation rejects an older in-flight analysis',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final analysis = model.analyze(
        model.document,
        operation: rpc.AnalysisOperation.DIAGNOSTICS,
      );
      expect(client.analyses, hasLength(1));
      final related = model.relatedRows(relatedRequest());
      client.pending.complete(relatedReply(snapshot: 11));
      await related;
      client.pendingAnalyses.single.complete(
        analysisReply(client.analyses.single, 10),
      );
      expect(await analysis, isNull);
      expect(model.acceptedDiagnostics, isNull);
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 11,
        configuration: 2,
      ));
    },
  );

  test(
    'newer related reply rejects an older concurrent related reply',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final older = model.relatedRows(relatedRequest());
      final rejected = expectLater(
        older,
        throwsA(relatedFailure(WorkbenchFailureReason.stale)),
      );
      final newer = model.relatedRows(relatedRequest());
      client.additionalPending.single.complete(relatedReply(snapshot: 11));
      await newer;
      client.pending.complete(relatedReply());
      await rejected;
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 11,
        configuration: 2,
      ));
    },
  );

  test(
    'zero unavailable reply cannot precede a positive observed minimum',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final pending = model.relatedRows(relatedRequest());
      final checked = expectLater(
        pending,
        throwsA(relatedFailure(WorkbenchFailureReason.stale)),
      );
      client.pending.complete(
        relatedReply(snapshot: 0)
          ..relationships.clear()
          ..availability = 'incomplete-metadata',
      );
      await checked;
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 10,
        configuration: 2,
      ));
    },
  );

  for (final negativeConfiguration in [false, true]) {
    test(
      'negative ${negativeConfiguration ? 'configuration' : 'snapshot'} cannot enter the shared minima',
      () {
        final model = relatedWorkspace(
          RelatedRevisionClient(),
          observedMetadata: false,
        );
        addTearDown(model.dispose);
        expect(
          model.acceptMetadataSnapshotRevision(
            's',
            negativeConfiguration ? 1 : -1,
            negativeConfiguration ? -1 : 1,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isFalse,
        );
        expect(model.metadataRevisionForSession('s'), isNull);
      },
    );
  }

  test(
    'first stamped observation permits fresh exact browse acquisition',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client, observedMetadata: false);
      addTearDown(model.dispose);
      final related = model.relatedRows(relatedRequest());
      client.pending.complete(relatedReply(snapshot: 11, configuration: 3));
      await related;
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 11,
        configuration: 3,
      ));
      browseFixture(model, names: 11, structure: 12, configuration: 3);
      final selection = await BrowseSelectionController(
        model,
      ).prepare(model.captureTarget(), targetHint);
      final request = selection.request(
        model,
        executionId: 'explicit-browse',
        rowLimit: Int64(20),
      );
      expect(request.metadataSnapshotRevision, Int64(12));
      expect(request.metadataObjectIdentity, 'native-target-identity');
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 12,
        configuration: 3,
      ));
      expect(client.browseReviews, isEmpty);
      expect(client.browseRequests, isEmpty);
    },
  );

  test(
    'snapshot observation cannot authorize an existing prepared browse',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      browseFixture(model);
      final selection = await BrowseSelectionController(
        model,
      ).prepare(model.captureTarget(), targetHint);
      final related = model.relatedRows(relatedRequest());
      client.pending.complete(relatedReply(snapshot: 12));
      await related;
      expect(
        () => selection.request(
          model,
          executionId: 'retired',
          rowLimit: Int64(20),
        ),
        throwsA(relatedFailure(WorkbenchFailureReason.stale)),
      );
      expect(client.browseReviews, isEmpty);
      expect(client.browseRequests, isEmpty);
    },
  );

  test(
    'a higher actual configuration retires the preparation and permits a fresh one',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final related = model.relatedRows(relatedRequest());
      client.pending.complete(relatedReply(snapshot: 11));
      await related;
      browseFixture(model, names: 11, structure: 12, configuration: 3);
      await expectLater(
        BrowseSelectionController(
          model,
        ).prepare(model.captureTarget(), targetHint),
        throwsA(relatedFailure(WorkbenchFailureReason.invalidRevision)),
      );
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 11,
        configuration: 3,
      ));
      final selected = await BrowseSelectionController(
        model,
      ).prepare(model.captureTarget(), targetHint);
      expect(selected.configurationRevision, 3);
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 12,
        configuration: 3,
      ));
      expect(client.browseRequests, isEmpty);
    },
  );

  for (final changed in [
    'backend',
    'profile',
    'session',
    'context',
    'removed',
    'disconnected',
    'unknown',
  ]) {
    test('rejected $changed owner cannot observe a related snapshot', () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final accepted = acceptedAt(model, rpc.AnalysisOperation.DIAGNOSTICS, 10);
      model.acceptedDiagnostics = accepted;
      final pending = model.relatedRows(relatedRequest());
      final reason = switch (changed) {
        'backend' => WorkbenchFailureReason.backendRestarted,
        'session' || 'context' => WorkbenchFailureReason.invalidRevision,
        'unknown' => WorkbenchFailureReason.transactionUnknown,
        _ => WorkbenchFailureReason.invalidOwner,
      };
      final rejected = expectLater(pending, throwsA(relatedFailure(reason)));
      switch (changed) {
        case 'backend':
          model.backend = TestBackend();
        case 'profile':
          model.sessions['s'] = model.sessions['s']!.deepCopy()
            ..profile = (model.sessions['s']!.profile.deepCopy()
              ..database = 'different');
        case 'session':
          model.sessions['s'] = model.sessions['s']!.deepCopy()
            ..sessionRevision = Int64(8);
        case 'context':
          model.sessions['s'] = model.sessions['s']!.deepCopy()
            ..contextRevision = Int64(2);
        case 'removed':
          model.sessions.remove('s');
        case 'disconnected':
          model.sessions['s'] = model.sessions['s']!.deepCopy()
            ..transaction = rpc.TransactionState.DISCONNECTED;
        case 'unknown':
          model.sessions['s'] = model.sessions['s']!.deepCopy()
            ..transaction = rpc.TransactionState.UNKNOWN_TRANSACTION;
      }
      final beforeRevision = model.metadataRevisionForSession('s');
      // A removed owner has no new physical envelope to construct. Keep the
      // captured sentinel to prove the rejected reply cannot replace it.
      final currentAccepted = changed == 'removed'
          ? accepted
          : acceptedAt(model, rpc.AnalysisOperation.DIAGNOSTICS, 10);
      model.acceptedDiagnostics = currentAccepted;
      client.pending.complete(relatedReply(snapshot: 11));
      await rejected;
      expect(model.metadataRevisionForSession('s'), beforeRevision);
      expect(model.acceptedDiagnostics, same(currentAccepted));
    });
  }

  test('missing physical owner fails before any related RPC', () async {
    final client = RelatedRevisionClient();
    final model = relatedWorkspace(client);
    addTearDown(model.dispose);
    model.sessions.clear();
    await expectLater(
      model.relatedRows(relatedRequest()),
      throwsA(relatedFailure(WorkbenchFailureReason.invalidOwner)),
    );
    expect(client.requests, isEmpty);
  });

  for (final malformed in [
    'snapshot',
    'configuration',
    'session',
    'context',
    'instance',
    'profile',
    'owner',
    'older snapshot',
    'older configuration',
  ]) {
    test(
      'rejected $malformed metadata cannot advance physical revision or clear analysis',
      () {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final accepted = acceptedAt(
          model,
          rpc.AnalysisOperation.DIAGNOSTICS,
          10,
        );
        model.acceptedDiagnostics = accepted;
        final response = rpc.SchemaObjects(
          instanceId: model.backend!.instanceId,
          profileId: 'p',
          sessionId: 's',
          sessionRevision: Int64(8),
          contextRevision: Int64.ONE,
          metadataSnapshotRevision: Int64(11),
          metadataConfigurationRevision: Int64(2),
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
        );
        switch (malformed) {
          case 'snapshot':
            response.metadataSnapshotRevision = Int64(-1);
          case 'configuration':
            response.metadataConfigurationRevision = Int64(-1);
          case 'session':
            response.sessionRevision = Int64(-1);
          case 'context':
            response.contextRevision = Int64(-1);
          case 'instance':
            response.instanceId = 'other-backend';
          case 'profile':
            response.profileId = 'other-profile';
          case 'owner':
            response.sessionId = 'other-session';
          case 'older snapshot':
            response
              ..sessionRevision = Int64(7)
              ..metadataSnapshotRevision = Int64(9);
          case 'older configuration':
            response.metadataConfigurationRevision = Int64.ONE;
        }
        expect(model.acceptMetadataRevision('s', response), isFalse);
        expect(model.sessions['s']!.sessionRevision, Int64(7));
        expect(model.metadataRevisionForSession('s'), (
          snapshot: 10,
          configuration: 2,
        ));
        expect(model.acceptedDiagnostics, same(accepted));
      },
    );
  }

  for (final scenario in [
    'older',
    'equal',
    'newer',
    'related superseded',
    'newer epoch observed',
  ]) {
    testWidgets('Explorer $scenario page preserves exact adopted ownership', (
      tester,
    ) async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      model.explorerSessions['p'] = 's';
      model.namespaceSelections[model.namespaceScopeKey('p', '')] =
          NamespaceSelection(names: []);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatabaseExplorer(
              model: model,
              controls: const LinuxControls(),
            ),
          ),
        ),
      );
      await tester.pump();
      final dynamic state = tester.state(find.byType(DatabaseExplorer));
      final root = state.roots['p'] as ExplorerNode;
      final node = ExplorerNode(
        'tables',
        'p',
        'Tables',
        kind: rpc.ObjectKind.TABLE,
        catalog: 'db',
        schema: 'public',
        category: true,
      );
      final identity = const DatabaseObjectIdentity(
        profileId: 'p',
        catalog: 'db',
        schema: 'public',
        kind: rpc.ObjectKind.TABLE,
        name: 'kept',
      );
      final old =
          ExplorerNode(
              'tables\u0000object\u0000${identity.key}',
              'p',
              'kept',
              kind: rpc.ObjectKind.TABLE,
              catalog: 'db',
              schema: 'public',
              object: rpc.SchemaObject(
                kind: rpc.ObjectKind.TABLE,
                name: 'kept',
                catalog: 'db',
                schema: 'public',
                metadataSnapshotRevision: Int64(10),
              ),
            )
            ..loaded = true
            ..pageStart = 'child-start'
            ..continuation = 'child-next'
            ..previousPages.add('child-before');
      node
        ..children = [old]
        ..loaded = true
        ..complete = true
        ..totalCount = 1
        ..pageStart = 'old-start'
        ..previousPages.add('old-before');
      root.children = [node];
      final delayed = Completer<rpc.SchemaObjects>();
      client.metadataAction = (_) => delayed.future;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
      final Future<void> loading = state.load(
        node,
        refresh: scenario == 'newer epoch observed',
      );
      await tester.pump();
      expect(old.loaded, isTrue);
      expect(old.continuation, 'child-next');
      if (scenario == 'related superseded') {
        final related = model.relatedRows(relatedRequest());
        client.pending.complete(relatedReply(snapshot: 11));
        await related;
      }
      if (scenario == 'newer epoch observed') {
        model.sessions['s'] = model.sessions['s']!.deepCopy()
          ..sessionRevision = Int64(8);
        model.acceptMetadataSnapshotRevision(
          's',
          11,
          2,
          sourceIdentity: fixtureMetadataSourceIdentity,
        );
      }
      final snapshot = switch (scenario) {
        'older' => 9,
        'newer' => 11,
        _ => 10,
      };
      delayed.complete(
        explorerReply(
          client.metadataRequests.single,
          snapshot: snapshot,
          names: ['kept'],
        ),
      );
      await loading;
      await tester.pump();
      if (scenario == 'older' ||
          scenario == 'related superseded' ||
          scenario == 'newer epoch observed') {
        expect(node.children.single, same(old));
        expect(old.object!.metadataSnapshotRevision, Int64(10));
        expect(old.loaded, isTrue);
        expect(old.pageStart, 'child-start');
        expect(old.continuation, 'child-next');
        expect(old.previousPages, ['child-before']);
        expect(node.complete, isTrue);
        expect(node.totalCount, 1);
        expect(node.pageStart, 'old-start');
        expect(node.previousPages, ['old-before']);
        expect(node.availability, AppLocalizationsEn().staleRefresh);
        expect(
          model.sessions['s']!.sessionRevision,
          Int64(scenario == 'newer epoch observed' ? 8 : 7),
        );
      } else {
        expect(node.children.single, same(old));
        expect(old.object!.metadataSnapshotRevision, Int64(snapshot));
        expect(old.loaded, isTrue);
        expect(old.continuation, 'child-next');
        expect(node.complete, isTrue);
        expect(node.totalCount, 1);
        expect(node.pageStart, isEmpty);
        expect(model.sessions['s']!.sessionRevision, Int64(7));
      }
      expect(client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  for (final exactSnapshot in [10, 11, 12]) {
    testWidgets(
      'Explorer stages main11 and exact$exactSnapshot without mixing revisions',
      (tester) async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        model.explorerSessions['p'] = 's';
        model.namespaceSelections[model.namespaceScopeKey('p', '')] =
            NamespaceSelection(names: []);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DatabaseExplorer(
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        await tester.pump();
        final dynamic state = tester.state(find.byType(DatabaseExplorer));
        final node = state.roots['p'] as ExplorerNode;
        final logical = const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: '',
          kind: rpc.ObjectKind.CATALOG,
          name: 'db',
        );
        final old = ExplorerNode(
          'p\u0000object\u0000${logical.key}',
          'p',
          'db',
          kind: rpc.ObjectKind.CATALOG,
          catalog: 'db',
          object: rpc.SchemaObject(
            kind: rpc.ObjectKind.CATALOG,
            catalog: 'db',
            name: 'db',
            metadataSnapshotRevision: Int64(10),
          ),
        );
        node
          ..children = [old]
          ..loaded = true
          ..complete = true
          ..totalCount = 1
          ..defaultNamespace = 'db'
          ..pageStart = 'old-start'
          ..previousPages.add('old-before')
          ..verifiedSelectedNamespaces.add('db')
          ..missingNamespaces.add('old-missing')
          ..verifiedExcludedNamespaces.add('excluded')
          ..checkedExcludedNamespaces.add('excluded');
        final main = Completer<rpc.SchemaObjects>(),
            exact = Completer<rpc.SchemaObjects>();
        client.metadataAction = (request) =>
            request.exactName ? exact.future : main.future;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        });
        final Future<void> loading = state.load(node);
        await tester.pump();
        main.complete(
          explorerReply(
            client.metadataRequests.first,
            snapshot: 11,
            names: ['aaa'],
            complete: false,
            defaultNamespace: 'db',
          ),
        );
        await tester.pump();
        expect(client.metadataRequests, hasLength(2));
        expect(node.children, [old]);
        expect(old.object!.metadataSnapshotRevision, Int64(10));
        expect(node.complete, isTrue);
        expect(node.totalCount, 1);
        expect(node.missingNamespaces, {'old-missing'});
        exact.complete(
          explorerReply(
            client.metadataRequests.last,
            snapshot: exactSnapshot,
            names: ['db'],
          ),
        );
        await loading;
        await tester.pump();
        if (exactSnapshot == 11) {
          expect(node.children.map((child) => child.label), ['aaa', 'db']);
          expect(node.children.last, same(old));
          expect(old.object!.metadataSnapshotRevision, Int64(11));
          expect(node.complete, isFalse);
          expect(node.continuation, 'next-page');
          expect(node.totalCount, 2);
          expect(node.pageStart, isEmpty);
        } else {
          expect(node.children, [old]);
          expect(old.object!.metadataSnapshotRevision, Int64(10));
          expect(node.complete, isTrue);
          expect(node.totalCount, 1);
          expect(node.pageStart, 'old-start');
          expect(node.previousPages, ['old-before']);
          expect(node.missingNamespaces, {'old-missing'});
          expect(node.verifiedSelectedNamespaces, {'db'});
          expect(node.verifiedExcludedNamespaces, {'excluded'});
          expect(node.checkedExcludedNamespaces, {'excluded'});
          expect(node.availability, AppLocalizationsEn().staleRefresh);
        }
        expect(
          model.metadataRevisionForSession('s')!.snapshot,
          exactSnapshot > 11 ? exactSnapshot : 11,
        );
        expect(client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final changeContext in [false, true]) {
    testWidgets(
      'Structure reload ${changeContext ? 'clears changed authority' : 'retains rejected same authority'}',
      (tester) async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        model.explorerSessions['p'] = 's';
        final owner = model.openTask(
          WorkbenchDocumentKind.structure,
          'customers',
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'db',
            schema: 'public',
            kind: rpc.ObjectKind.TABLE,
            name: 'customers',
          ),
        );
        owner.view.structureSection = rpc.ObjectKind.COLUMN.value;
        client.metadataAction = (request) async =>
            explorerReply(request, snapshot: 10, names: ['old_field']);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        });
        await tester.binding.setSurfaceSize(const Size(1100, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ObjectDocumentView(
                model: model,
                owner: owner,
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final dynamic state = tester.state(find.byType(ObjectDocumentView));
        expect(
          (state.objects as List<rpc.SchemaObject>).single.name,
          'old_field',
        );
        final pending = Completer<rpc.SchemaObjects>();
        client.metadataAction = (_) => pending.future;
        if (changeContext) {
          model.sessions['s'] = model.sessions['s']!.deepCopy()
            ..contextRevision = Int64(2);
        }
        final Future<void> loading = state.load();
        await tester.pump();
        if (changeContext) {
          expect(state.objects, isEmpty);
        } else {
          expect(
            (state.objects as List<rpc.SchemaObject>).single.name,
            'old_field',
          );
          final related = model.relatedRows(relatedRequest());
          client.pending.complete(relatedReply(snapshot: 11));
          await related;
        }
        final response = explorerReply(
          client.metadataRequests.last,
          snapshot: changeContext ? 11 : 10,
          names: ['new_field'],
        );
        if (changeContext) response.contextRevision = Int64(2);
        pending.complete(response);
        await loading;
        await tester.pumpAndSettle();
        expect(
          (state.objects as List<rpc.SchemaObject>).single.name,
          changeContext ? 'new_field' : 'old_field',
        );
        expect(client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('cancelled Related Rows does not observe a source revision', () async {
    final client = RelatedRevisionClient();
    final model = relatedWorkspace(client);
    addTearDown(model.dispose);
    final accepted = acceptedAt(model, rpc.AnalysisOperation.DIAGNOSTICS, 10);
    model.acceptedDiagnostics = accepted;
    final pending = model.relatedRows(relatedRequest());
    final checked = expectLater(
      pending,
      throwsA(
        isA<GrpcError>().having(
          (error) => error.code,
          'cancelled',
          StatusCode.cancelled,
        ),
      ),
    );
    client.pending.completeError(const GrpcError.cancelled());
    await checked;
    expect(model.metadataRevisionForSession('s'), (
      snapshot: 10,
      configuration: 2,
    ));
    expect(model.acceptedDiagnostics, same(accepted));
  });

  test(
    'initial physical revision0 is sent with explicit optional presence',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client, observedMetadata: false);
      addTearDown(model.dispose);
      model.sessions['s'] = model.sessions['s']!.deepCopy()
        ..sessionRevision = Int64.ZERO;
      final pending = model.relatedRows(relatedRequest());
      expect(client.requests.single.hasExpectedSessionRevision(), isTrue);
      expect(client.requests.single.expectedSessionRevision, Int64.ZERO);
      expect(client.requests.single.hasExpectedContextRevision(), isTrue);
      expect(client.requests.single.expectedContextRevision, Int64.ONE);
      client.pending.complete(relatedReply(sessionRevision: 0));
      await pending;
      expect(model.metadataStampForSession('s')!.sessionRevision, 0);
    },
  );

  for (final changed in [
    'backend',
    'profile',
    'session',
    'context',
    'revision',
    'source',
    'source missing',
    'source size',
    'configuration missing',
    'configuration negative',
    'old configuration',
  ]) {
    test(
      'Related Rows rejects its stamped $changed mismatch without shared mutation',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final pending = model.relatedRows(relatedRequest());
        final expected = switch (changed) {
          'backend' => WorkbenchFailureReason.backendRestarted,
          'context' || 'revision' => WorkbenchFailureReason.invalidRevision,
          'source missing' ||
          'source size' ||
          'configuration missing' ||
          'configuration negative' => WorkbenchFailureReason.malformedRequest,
          'old configuration' => WorkbenchFailureReason.stale,
          _ => WorkbenchFailureReason.invalidOwner,
        };
        final checked = expectLater(pending, throwsA(relatedFailure(expected)));
        final reply = relatedReply(snapshot: 100);
        switch (changed) {
          case 'backend':
            reply.backendInstance = 'foreign';
          case 'profile':
            reply.profileId = 'foreign';
          case 'session':
            reply.sessionId = 'foreign';
          case 'context':
            reply.contextRevision = Int64(2);
          case 'revision':
            reply.sessionRevision = Int64(8);
          case 'source':
            reply.metadataSourceIdentity = 'b' * 64;
          case 'source missing':
            reply.clearMetadataSourceIdentity();
          case 'source size':
            reply.metadataSourceIdentity = 'a' * 65;
          case 'configuration missing':
            reply.clearMetadataConfigurationRevision();
          case 'configuration negative':
            reply.metadataConfigurationRevision = Int64(-1);
          case 'old configuration':
            reply.metadataConfigurationRevision = Int64.ONE;
        }
        client.pending.complete(reply);
        await checked;
        expect(model.metadataRevisionForSession('s'), (
          snapshot: 10,
          configuration: 2,
        ));
      },
    );
  }

  test(
    'rollback epoch accepts a lower retained durable snapshot through full metadata',
    () {
      final model = relatedWorkspace(RelatedRevisionClient());
      addTearDown(model.dispose);
      final response = rpc.SchemaObjects(
        instanceId: model.backend!.instanceId,
        profileId: 'p',
        sessionId: 's',
        sessionRevision: Int64(8),
        contextRevision: Int64.ONE,
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        metadataConfigurationRevision: Int64(2),
        metadataSnapshotRevision: Int64(5),
      );
      expect(model.acceptMetadataRevision('s', response), isTrue);
      expect(model.sessions['s']!.sessionRevision, Int64(8));
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 5,
        configuration: 2,
      ));
      final old = response.deepCopy()
        ..sessionRevision = Int64(7)
        ..metadataSnapshotRevision = Int64(100);
      expect(model.acceptMetadataRevision('s', old), isFalse);
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 5,
        configuration: 2,
      ));
    },
  );

  test(
    'actual configuration changes propagate across consoles despite lower snapshots',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      model.sessions['other'] = model.sessions['s']!.deepCopy()
        ..sessionId = 'other';
      model.acceptMetadataSnapshotRevision(
        'other',
        20,
        2,
        sourceIdentity: fixtureMetadataSourceIdentity,
      );
      final old = model.analyze(
        model.document,
        operation: rpc.AnalysisOperation.DIAGNOSTICS,
      );
      final related = model.relatedRows(
        relatedRequest(sessionId: 'other', resultId: 'other-result'),
      );
      client.pending.complete(
        relatedReply(
          sessionId: 'other',
          resultId: 'other-result',
          configuration: 3,
          snapshot: 4,
        ),
      );
      await related;
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 0,
        configuration: 3,
      ));
      expect(model.metadataRevisionForSession('other'), (
        snapshot: 4,
        configuration: 3,
      ));
      client.pendingAnalyses.single.complete(
        analysisReply(client.analyses.single, 100),
      );
      expect(await old, isNull);
      expect(
        model.acceptMetadataSnapshotRevision(
          's',
          100,
          2,
          sourceIdentity: fixtureMetadataSourceIdentity,
        ),
        isFalse,
      );
      expect(
        model.acceptMetadataSnapshotRevision(
          's',
          2,
          3,
          sourceIdentity: fixtureMetadataSourceIdentity,
        ),
        isTrue,
      );
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 2,
        configuration: 3,
      ));
    },
  );

  for (final otherSource in [false, true]) {
    testWidgets(
      'Explorer reloads only a changed actual source/configuration domain: other source $otherSource',
      (tester) async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        model.explorerSessions['p'] = 's';
        model.namespaceSelections[model.namespaceScopeKey('p', '')] =
            NamespaceSelection(names: []);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DatabaseExplorer(
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        await tester.pump();
        final dynamic state = tester.state(find.byType(DatabaseExplorer));
        final node = state.roots['p'] as ExplorerNode;
        node
          ..expanded = true
          ..loaded = true
          ..complete = true
          ..totalCount = 1
          ..children = [
            ExplorerNode(
              'old',
              'p',
              'old-db',
              kind: rpc.ObjectKind.CATALOG,
              catalog: 'old-db',
              object: rpc.SchemaObject(
                kind: rpc.ObjectKind.CATALOG,
                name: 'old-db',
                catalog: 'old-db',
              ),
            ),
          ];
        client.metadataAction = (request) async => explorerReply(
          request,
          snapshot: 4,
          names: ['db'],
          configuration: 3,
          defaultNamespace: 'db',
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        });
        model.sessions['other'] = model.sessions['s']!.deepCopy()
          ..sessionId = 'other'
          ..metadataSourceIdentity = otherSource
              ? 'b' * 64
              : fixtureMetadataSourceIdentity;
        final related = model.relatedRows(
          relatedRequest(sessionId: 'other', resultId: 'other-result'),
        );
        client.pending.complete(
          relatedReply(
            sessionId: 'other',
            resultId: 'other-result',
            configuration: 3,
            snapshot: 4,
            sourceIdentity: otherSource
                ? 'b' * 64
                : fixtureMetadataSourceIdentity,
          ),
        );
        await related;
        await tester.pumpAndSettle();
        if (otherSource) {
          expect(client.metadataRequests, isEmpty);
          expect(node.children.single.label, 'old-db');
          expect(node.contextStale, isFalse);
        } else {
          expect(client.metadataRequests, hasLength(1));
          expect(node.children.map((child) => child.label), ['db']);
          expect(node.contextStale, isFalse);
          expect(node.metadataConfigurationRevision, 3);
        }
        expect(client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Structure owner switch with the same section revision cannot borrow rows',
    (tester) async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      model.explorerSessions['p'] = 's';
      final first = model.openTask(
        WorkbenchDocumentKind.structure,
        'customers',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'customers',
        ),
      );
      first.view.structureSection = rpc.ObjectKind.COLUMN.value;
      client.metadataAction = (request) async =>
          explorerReply(request, snapshot: 10, names: ['customers_field']);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget view(WorkbenchDocument owner) => MaterialApp(
        home: Scaffold(
          body: ObjectDocumentView(
            model: model,
            owner: owner,
            controls: const LinuxControls(),
          ),
        ),
      );
      await tester.pumpWidget(view(first));
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ObjectDocumentView));
      expect(
        (state.objects as List<rpc.SchemaObject>).single.name,
        'customers_field',
      );
      final second = model.openTask(
        WorkbenchDocumentKind.structure,
        'orders',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'orders',
        ),
      );
      second.view.structureSection = rpc.ObjectKind.COLUMN.value;
      final delayed = Completer<rpc.SchemaObjects>();
      client.metadataAction = (_) => delayed.future;
      await tester.pumpWidget(view(second));
      await tester.pump();
      expect(state.objects, isEmpty);
      expect(client.metadataRequests.last.table, 'orders');
      delayed.complete(
        explorerReply(
          client.metadataRequests.last,
          snapshot: 11,
          names: ['orders_field'],
        ),
      );
      await tester.pumpAndSettle();
      expect(
        (state.objects as List<rpc.SchemaObject>).single.name,
        'orders_field',
      );
      expect(client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Structure queues one bounded read after another console changes source configuration',
    (tester) async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      model.explorerSessions['p'] = 's';
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'customers',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'customers',
        ),
      );
      owner.view.structureSection = rpc.ObjectKind.COLUMN.value;
      client.metadataAction = (request) async => explorerReply(
        request,
        snapshot: client.metadataRequests.length == 1 ? 10 : 4,
        configuration: client.metadataRequests.length == 1 ? 2 : 3,
        names: [
          client.metadataRequests.length == 1 ? 'old_field' : 'new_field',
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ObjectDocumentView(
              model: model,
              owner: owner,
              controls: const LinuxControls(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ObjectDocumentView));
      expect(
        (state.objects as List<rpc.SchemaObject>).single.name,
        'old_field',
      );
      model.sessions['other'] = model.sessions['s']!.deepCopy()
        ..sessionId = 'other';
      final related = model.relatedRows(
        relatedRequest(sessionId: 'other', resultId: 'other-result'),
      );
      client.pending.complete(
        relatedReply(
          sessionId: 'other',
          resultId: 'other-result',
          configuration: 3,
          snapshot: 4,
        ),
      );
      await related;
      await tester.pumpAndSettle();
      expect(client.metadataRequests, hasLength(2));
      expect(
        (state.objects as List<rpc.SchemaObject>).single.name,
        'new_field',
      );
      expect(state.metadataCurrent, isTrue);
      expect(model.metadataRevisionForSession('s'), (
        snapshot: 4,
        configuration: 3,
      ));
      expect(client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  for (final terminal in [
    rpc.TransactionState.UNKNOWN_TRANSACTION,
    rpc.TransactionState.DISCONNECTED,
  ]) {
    test(
      'equal-counter terminal status rejects accepted and pending language authority: $terminal',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final oldOwner = model.sessions['s']!.deepCopy();
        final oldStamp = model.metadataStampForSession('s')!;
        model.sessions['healthy'] = oldOwner.deepCopy()..sessionId = 'healthy';
        final accepted = acceptedAt(
          model,
          rpc.AnalysisOperation.COMPLETION,
          10,
        );
        model.acceptedAnalysis = accepted;
        model.acceptedDiagnostics = acceptedAt(
          model,
          rpc.AnalysisOperation.DIAGNOSTICS,
          10,
        );
        model.acceptedParameterInformation = acceptedAt(
          model,
          rpc.AnalysisOperation.PARAMETER_INFORMATION,
          10,
        );
        final pending = model.analyze(
          model.document,
          operation: rpc.AnalysisOperation.DIAGNOSTICS,
        );
        final request = client.analyses.single;
        client.sessionCommand = (request) async =>
            model.sessions[request.sessionId]!.deepCopy()
              ..transaction = request.sessionId == 's'
                  ? terminal
                  : rpc.TransactionState.IDLE;
        await model.poll();
        expect(model.sessions['s']!.sessionRevision, oldOwner.sessionRevision);
        expect(model.sessions['s']!.contextRevision, oldOwner.contextRevision);
        expect(model.sessions['s']!.transaction, terminal);
        expect(model.metadataStampForSession('s'), isNull);
        expect(model.metadataRevisionIsCurrent(oldStamp), isFalse);
        expect(model.analysisResultMatches(accepted), isFalse);
        expect(model.acceptedAnalysis, isNull);
        expect(model.acceptedDiagnostics, isNull);
        expect(model.acceptedParameterInformation, isNull);
        expect(client.cancelledAnalyses, 1);
        final obsolete = analysisReply(request, 100)
          ..metadataConfigurationRevision = Int64(4);
        client.pendingAnalyses.single.complete(obsolete);
        expect(await pending, isNull);
        expect(
          model.acceptMetadataSnapshotRevision(
            's',
            100,
            4,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isFalse,
        );
        final metadata = rpc.SchemaObjects(
          instanceId: model.backend!.instanceId,
          profileId: 'p',
          sessionId: 's',
          sessionRevision: Int64(8),
          contextRevision: Int64.ONE,
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          metadataConfigurationRevision: Int64(4),
          metadataSnapshotRevision: Int64(100),
        );
        expect(model.acceptMetadataRevision('s', metadata), isFalse);
        expect(model.sessions['s']!.sessionRevision, oldOwner.sessionRevision);
        expect(model.sessions['s']!.transaction, terminal);
        expect(
          model.acceptMetadataSnapshotRevision(
            'healthy',
            4,
            2,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isTrue,
          reason:
              'Rejected terminal replies cannot advance the source configuration floor',
        );
        expect(await model.analyze(model.document), isNull);
        expect(client.analyses, hasLength(1));
        expect(client.metadataRequests, isEmpty);
        expect(client.opened, isEmpty);
        expect(client.executions, isEmpty);
      },
    );

    test(
      'terminal owners retain their actual source floor without lending authority: $terminal',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        final target = model.captureTarget();
        model.sessions['healthy'] = model.sessions['s']!.deepCopy()
          ..sessionId = 'healthy';
        expect(
          model.acceptMetadataSnapshotRevision(
            's',
            4,
            3,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isTrue,
        );
        final stamp = model.metadataStampForSession('s')!;
        model.sessions['s']!.transaction = terminal;
        expect(model.metadataStampForSession('s'), isNull);
        expect(model.metadataRevisionIsCurrent(stamp), isFalse);
        expect(
          model.acceptMetadataSnapshotRevision(
            'healthy',
            100,
            2,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isFalse,
        );
        expect(
          model.acceptMetadataSnapshotRevision(
            'healthy',
            4,
            3,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isTrue,
        );
        await expectLater(
          model.readMetadata(
            target,
            rpc.ExploreRequest(kind: rpc.ObjectKind.TABLE),
          ),
          throwsA(
            relatedFailure(
              terminal == rpc.TransactionState.UNKNOWN_TRANSACTION
                  ? WorkbenchFailureReason.transactionUnknown
                  : WorkbenchFailureReason.unavailable,
            ),
          ),
        );
        expect(client.metadataRequests, isEmpty);
        expect(client.opened, isEmpty);
        expect(client.executions, isEmpty);
      },
    );

    test(
      'prepared browse loses authority on equal-counter quarantine: $terminal',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        browseFixture(model);
        final prepared = await BrowseSelectionController(
          model,
        ).prepare(model.captureTarget(), targetHint);
        final source = model.metadataStampForSession('s')!;
        final owner = model.sessions['s']!;
        model.sessions['s'] = owner.deepCopy()..transaction = terminal;
        expect(model.metadataRevisionIsCurrent(source), isFalse);
        expect(
          () => prepared.request(
            model,
            executionId: 'must-not-submit',
            rowLimit: Int64(20),
          ),
          throwsA(
            relatedFailure(
              terminal == rpc.TransactionState.UNKNOWN_TRANSACTION
                  ? WorkbenchFailureReason.transactionUnknown
                  : WorkbenchFailureReason.unavailable,
            ),
          ),
        );
        expect(client.browseReviews, isEmpty);
        expect(client.browseRequests, isEmpty);
        expect(client.opened, isEmpty);
        expect(client.executions, isEmpty);
      },
    );
  }

  for (final surface in ['Explorer', 'Structure']) {
    testWidgets(
      '$surface cannot reload or reconnect a quarantined owner after source configuration changes',
      (tester) async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        model.explorerSessions['p'] = 's';
        model.namespaceSelections[model.namespaceScopeKey('p', '')] =
            NamespaceSelection(names: []);
        model.sessions['healthy'] = model.sessions['s']!.deepCopy()
          ..sessionId = 'healthy';
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        });
        await tester.binding.setSurfaceSize(const Size(1100, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        dynamic state;
        ExplorerNode? root;
        if (surface == 'Explorer') {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: DatabaseExplorer(
                  model: model,
                  controls: const LinuxControls(),
                ),
              ),
            ),
          );
          await tester.pump();
          state = tester.state(find.byType(DatabaseExplorer));
          root = state.roots['p'] as ExplorerNode;
          root
            ..expanded = true
            ..loaded = true
            ..complete = true
            ..totalCount = 1
            ..children = [
              ExplorerNode(
                'old',
                'p',
                'old-db',
                kind: rpc.ObjectKind.CATALOG,
                catalog: 'old-db',
                object: rpc.SchemaObject(
                  kind: rpc.ObjectKind.CATALOG,
                  name: 'old-db',
                  catalog: 'old-db',
                ),
              ),
            ];
        } else {
          final owner = model.openTask(
            WorkbenchDocumentKind.structure,
            'customers',
            object: const DatabaseObjectIdentity(
              profileId: 'p',
              catalog: 'db',
              schema: 'public',
              kind: rpc.ObjectKind.TABLE,
              name: 'customers',
            ),
          );
          owner.view.structureSection = rpc.ObjectKind.COLUMN.value;
          owner.view.metadataRequested = true;
          client.metadataAction = (request) async =>
              explorerReply(request, snapshot: 10, names: ['old_field']);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ObjectDocumentView(
                  model: model,
                  owner: owner,
                  controls: const LinuxControls(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          state = tester.state(find.byType(ObjectDocumentView));
          expect(
            (state.objects as List<rpc.SchemaObject>).single.name,
            'old_field',
          );
        }
        final initialRequests = client.metadataRequests.length;
        client.sessionCommand = (request) async =>
            model.sessions[request.sessionId]!.deepCopy()
              ..transaction = request.sessionId == 's'
                  ? rpc.TransactionState.UNKNOWN_TRANSACTION
                  : rpc.TransactionState.IDLE;
        await model.poll();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        final changed = model.relatedRows(
          relatedRequest(sessionId: 'healthy', resultId: 'healthy-result'),
        );
        client.pending.complete(
          relatedReply(
            sessionId: 'healthy',
            resultId: 'healthy-result',
            configuration: 3,
            snapshot: 4,
          ),
        );
        await changed;
        await tester.pumpAndSettle();
        expect(client.metadataRequests, hasLength(initialRequests));
        expect(client.opened, isEmpty);
        expect(client.executions, isEmpty);
        expect(model.metadataStampForSession('s'), isNull);
        expect(model.metadataRevisionForSession('healthy'), (
          snapshot: 4,
          configuration: 3,
        ));
        if (surface == 'Explorer') {
          final node = root!;
          expect(node.contextStale, isTrue);
          expect(node.children.single.label, 'old-db');
          expect(node.availability, AppLocalizationsEn().outcomeUnknownNote);
          await state.load(node);
        } else {
          expect(state.metadataCurrent, isFalse);
          expect(state.availability, AppLocalizationsEn().outcomeUnknownNote);
          await state.load();
        }
        await tester.pumpAndSettle();
        expect(client.metadataRequests, hasLength(initialRequests));
        expect(client.opened, isEmpty);
        expect(client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final terminal in [
    rpc.TransactionState.UNKNOWN_TRANSACTION,
    rpc.TransactionState.DISCONNECTED,
  ]) {
    for (final surface in ['Explorer', 'Structure', 'Definition']) {
      testWidgets(
        '$surface cold metadata acquisition cancels immediately on equal-counter $terminal',
        (tester) async {
          final client = RelatedRevisionClient();
          final model = relatedWorkspace(client, observedMetadata: false);
          model.explorerSessions['p'] = 's';
          model.namespaceSelections[model.namespaceScopeKey('p', '')] =
              NamespaceSelection(names: []);
          final metadata = Completer<rpc.SchemaObjects>();
          final definition = Completer<rpc.SchemaToolResult>();
          client.metadataAction = (_) => metadata.future;
          client.schemaTools = (_) => definition.future;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
          });
          await tester.binding.setSurfaceSize(const Size(1100, 850));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          dynamic state;
          ExplorerNode? root;
          Future<void>? explorerLoad;
          if (surface == 'Explorer') {
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: DatabaseExplorer(
                    model: model,
                    controls: const LinuxControls(),
                  ),
                ),
              ),
            );
            await tester.pump();
            state = tester.state(find.byType(DatabaseExplorer));
            root = state.roots['p'] as ExplorerNode;
            root.expanded = true;
            explorerLoad = state.load(root) as Future<void>;
          } else {
            final owner = model.openTask(
              WorkbenchDocumentKind.structure,
              'customers',
              object: const DatabaseObjectIdentity(
                profileId: 'p',
                catalog: 'db',
                schema: 'public',
                kind: rpc.ObjectKind.TABLE,
                name: 'customers',
              ),
            );
            owner.view.structureSection = surface == 'Definition'
                ? rpc.ObjectKind.TABLE.value
                : rpc.ObjectKind.COLUMN.value;
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: ObjectDocumentView(
                    model: model,
                    owner: owner,
                    controls: const LinuxControls(),
                  ),
                ),
              ),
            );
            state = tester.state(find.byType(ObjectDocumentView));
          }
          await tester.pump();
          expect(model.metadataStampForSession('s'), isNull);
          if (surface == 'Definition') {
            expect(client.schemaToolRequests, hasLength(1));
          } else {
            expect(client.metadataRequests, hasLength(1));
          }
          final before = model.sessions['s']!;
          model.sessions['s'] = before.deepCopy()..transaction = terminal;
          model.updateStatus('Observed terminal physical state');
          await tester.pump();
          final reason = terminal == rpc.TransactionState.UNKNOWN_TRANSACTION
              ? WorkbenchFailureReason.transactionUnknown
              : WorkbenchFailureReason.unavailable;
          if (surface == 'Explorer') {
            final node = root!;
            expect(node.contextStale, isTrue);
            expect(node.loading, isFalse);
            expect(node.availability, reason.localized(AppLocalizationsEn()));
          } else {
            expect(state.metadataCurrent, isFalse);
            expect(state.availability, reason.localized(AppLocalizationsEn()));
          }
          if (surface == 'Definition') {
            expect(client.cancelledSchemaTools, greaterThanOrEqualTo(1));
            definition.complete(
              rpc.SchemaToolResult(
                complete: true,
                definition: 'obsolete definition',
                inspectedObject: rpc.SchemaObject(
                  kind: rpc.ObjectKind.TABLE,
                  catalog: 'db',
                  schema: 'public',
                  name: 'customers',
                ),
              ),
            );
          } else {
            expect(client.cancelledMetadataRequests, greaterThanOrEqualTo(1));
            metadata.complete(
              explorerReply(
                client.metadataRequests.single,
                snapshot: 10,
                names: surface == 'Explorer' ? ['db'] : ['obsolete_field'],
              ),
            );
          }
          if (explorerLoad != null) await explorerLoad;
          await tester.pumpAndSettle();
          if (surface == 'Explorer') {
            final node = root!;
            expect(node.children, isEmpty);
            expect(node.contextStale, isTrue);
          } else {
            expect(state.objects, isEmpty);
            expect(state.metadataCurrent, isFalse);
          }
          expect(model.sessions['s']!.sessionRevision, before.sessionRevision);
          expect(model.sessions['s']!.contextRevision, before.contextRevision);
          expect(model.metadataStampForSession('s'), isNull);
          expect(client.opened, isEmpty);
          expect(client.executions, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'Structure reload and remount cannot reconnect a reviewed retired owner',
    (tester) async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      final sqlOwner = model.activeOwner;
      model.explorerSessions['p'] = 's';
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'customers',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'customers',
        ),
      );
      owner.view.structureSection = rpc.ObjectKind.COLUMN.value;
      owner.view.metadataRequested = true;
      owner.view.metadataSessionId = 's';
      var connectInvocations = 0;
      model.commands = WorkbenchCommandRegistry([
        WorkbenchCommand(
          id: 'connection.connect',
          label: 'Connect',
          category: 'Connection',
          invoke: (_) {
            connectInvocations++;
          },
        ),
      ]);
      client.metadataAction = (request) async =>
          explorerReply(request, snapshot: 10, names: ['old_field']);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
      });
      await tester.binding.setSurfaceSize(const Size(1100, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      Widget view(String key) => MaterialApp(
        home: Scaffold(
          body: ObjectDocumentView(
            key: ValueKey(key),
            model: model,
            owner: owner,
            controls: const LinuxControls(),
          ),
        ),
      );
      await tester.pumpWidget(view('original'));
      await tester.pumpAndSettle();
      dynamic state = tester.state(find.byType(ObjectDocumentView));
      expect(
        (state.objects as List<rpc.SchemaObject>).single.name,
        'old_field',
      );
      client.sessionCommand = (request) async =>
          model.sessions[request.sessionId]!.deepCopy()
            ..transaction = rpc.TransactionState.DISCONNECTED;
      await model.transaction(
        rpc.SessionAction.DISCONNECT,
        target: model.captureTarget(owner: sqlOwner),
      );
      await tester.pumpAndSettle();
      expect(model.sessions.containsKey('s'), isFalse);
      expect(
        state.metadataUnavailableReason,
        WorkbenchFailureReason.unavailable,
      );
      await state.load();
      await tester.pumpAndSettle();
      expect(state.availability, AppLocalizationsEn().unavailable);
      await tester.pumpWidget(view('remounted'));
      await tester.pumpAndSettle();
      state = tester.state(find.byType(ObjectDocumentView));
      expect(
        state.metadataUnavailableReason,
        WorkbenchFailureReason.unavailable,
      );
      expect(state.availability, AppLocalizationsEn().unavailable);
      expect(connectInvocations, 0);
      expect(client.metadataRequests, hasLength(1));
      expect(client.opened, isEmpty);
      expect(client.executions, isEmpty);
      expect(
        client.sessionCommands.single.action,
        rpc.SessionAction.DISCONNECT,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'same-source H without prior metadata retains config floor after S disconnect and unrelated prune',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      model.sessions['h'] = model.sessions['s']!.deepCopy()..sessionId = 'h';
      model.sessions['u'] = model.sessions['s']!.deepCopy()
        ..sessionId = 'u'
        ..metadataSourceIdentity = 'b' * 64;
      model.newDocument(text: 'SELECT delayed');
      model.document
        ..profileId = 'p'
        ..sessionId = 'h';
      final pending = model.analyze(
        model.document,
        operation: rpc.AnalysisOperation.DIAGNOSTICS,
      );
      expect(model.metadataStampForSession('h'), isNull);
      expect(
        model.acceptMetadataSnapshotRevision(
          's',
          4,
          3,
          sourceIdentity: fixtureMetadataSourceIdentity,
        ),
        isTrue,
      );
      expect(model.metadataRevisionForSession('h'), (
        snapshot: 0,
        configuration: 3,
      ));
      client.sessionCommand = (request) async =>
          model.sessions[request.sessionId]!.deepCopy()
            ..transaction = rpc.TransactionState.DISCONNECTED;
      await model.transaction(
        rpc.SessionAction.DISCONNECT,
        target: model.captureSessionTarget('s'),
      );
      expect(model.sessions.containsKey('s'), isFalse);
      expect(
        model.acceptMetadataSnapshotRevision(
          'u',
          7,
          1,
          sourceIdentity: 'b' * 64,
        ),
        isTrue,
      );
      expect(
        model.acceptMetadataSnapshotRevision(
          'u',
          8,
          1,
          sourceIdentity: 'b' * 64,
        ),
        isTrue,
      );
      client.pendingAnalyses.single.complete(
        analysisReply(client.analyses.single, 100),
      );
      expect(await pending, isNull);
      expect(model.metadataRevisionForSession('h'), (
        snapshot: 0,
        configuration: 3,
      ));
      final newer = rpc.SchemaObjects(
        instanceId: model.backend!.instanceId,
        profileId: 'p',
        sessionId: 'h',
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        contextRevision: Int64.ONE,
        sessionRevision: Int64(8),
        metadataConfigurationRevision: Int64(2),
        metadataSnapshotRevision: Int64(100),
      );
      expect(model.acceptMetadataRevision('h', newer), isFalse);
      newer
        ..metadataConfigurationRevision = Int64(3)
        ..metadataSnapshotRevision = Int64(2);
      expect(model.acceptMetadataRevision('h', newer), isTrue);
      expect(model.metadataRevisionForSession('h'), (
        snapshot: 2,
        configuration: 3,
      ));
      expect(
        client.sessionCommands.single.action,
        rpc.SessionAction.DISCONNECT,
      );
      expect(client.executions, isEmpty);
    },
  );

  test(
    'pending Open and Adopt cannot issue metadata before registration',
    () async {
      final client = RelatedRevisionClient();
      final model = relatedWorkspace(client);
      addTearDown(model.dispose);
      final profile = model.profiles.single;
      model.newDocument(text: 'SELECT future_owner');
      model.document.profileId = 'p';
      final document = model.document;
      final opening = Completer<rpc.SessionInfo>(),
          openedStarted = Completer<void>();
      final adoption = Completer<rpc.SessionInfo>(),
          adoptionStarted = Completer<void>();
      final owner = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'h',
        profile: profile.deepCopy(),
        sessionRevision: Int64.ZERO,
        contextRevision: Int64.ONE,
        currentCatalog: 'db',
        currentSchema: 'public',
        transaction: rpc.TransactionState.IDLE,
      );
      client.opening = (_) {
        openedStarted.complete();
        return opening.future;
      };
      client.sessionCommand = (request) {
        if (request.action == rpc.SessionAction.ADOPT_SESSION) {
          adoptionStarted.complete();
          return adoption.future;
        }
        return Future.value(
          model.sessions[request.sessionId]!.deepCopy()
            ..transaction = rpc.TransactionState.DISCONNECTED,
        );
      };
      final connection = model.connect(profile, '', targetDocument: document);
      await openedStarted.future;
      expect(model.sessions.containsKey('h'), isFalse);
      expect(document.sessionId, isNull);
      expect(
        model.acceptMetadataSnapshotRevision(
          's',
          4,
          3,
          sourceIdentity: fixtureMetadataSourceIdentity,
        ),
        isTrue,
      );
      opening.complete(owner);
      await adoptionStarted.future;
      expect(model.sessions.containsKey('h'), isFalse);
      expect(document.sessionId, isNull);
      expect(client.metadataRequests, isEmpty);
      expect(client.analyses, isEmpty);
      await model.transaction(
        rpc.SessionAction.DISCONNECT,
        target: model.captureSessionTarget('s'),
      );
      adoption.complete(owner.deepCopy());
      await connection;
      expect(document.sessionId, 'h');
      expect(
        model.sessions['h']!.metadataSourceIdentity,
        fixtureMetadataSourceIdentity,
      );
      client.metadataAction = (request) async =>
          explorerReply(request, snapshot: 4, configuration: 3, names: [])
            ..sessionId = 'h'
            ..sessionRevision = Int64.ZERO;
      final reply = await model.readMetadata(
        model.captureTarget(),
        rpc.ExploreRequest(
          kind: rpc.ObjectKind.TABLE,
          catalog: 'db',
          schema: 'public',
        ),
      );
      expect(reply.metadataConfigurationRevision, Int64(3));
      expect(client.metadataRequests.single.sessionId, 'h');
      expect(model.metadataRevisionForSession('h'), (
        snapshot: 4,
        configuration: 3,
      ));
      expect(client.executions, isEmpty);
    },
  );

  for (final closing in ['SQL status', 'task rollback']) {
    test(
      'a retired physical owner cannot be reinserted by delayed $closing acknowledgement',
      () async {
        final client = RelatedRevisionClient();
        final model = relatedWorkspace(client);
        addTearDown(model.dispose);
        model.sessions['h'] = model.sessions['s']!.deepCopy()..sessionId = 'h';
        final delayed = Completer<rpc.SessionInfo>(),
            started = Completer<void>();
        late Future<void> closingRequest;
        if (closing == 'SQL status') {
          model.newDocument(text: 'SELECT keep_draft');
          model.document
            ..profileId = 'p'
            ..sessionId = 'h';
          final document = model.document;
          client.sessionCommand = (request) {
            if (request.sessionId == 'h' &&
                request.action == rpc.SessionAction.SESSION_STATUS) {
              started.complete();
              return delayed.future;
            }
            return Future.value(
              model.sessions[request.sessionId]!.deepCopy()
                ..transaction = rpc.TransactionState.DISCONNECTED,
            );
          };
          closingRequest = model.closeDocument(
            document,
            reviewedRevision: document.version,
            discardText: true,
            resolveSession: true,
          );
        } else {
          model.sessions['h']!.transaction = rpc.TransactionState.ACTIVE;
          final task = model.openTask(
            WorkbenchDocumentKind.administration,
            'Owned task',
            profileId: 'p',
          );
          task.sessionId = 'h';
          client.sessionCommand = (request) {
            if (request.action == rpc.SessionAction.ROLLBACK) {
              started.complete();
              return delayed.future;
            }
            final reply = model.sessions[request.sessionId]!.deepCopy();
            if (request.action == rpc.SessionAction.DISCONNECT) {
              reply
                ..sessionRevision = Int64(8)
                ..transaction = rpc.TransactionState.DISCONNECTED;
            }
            return Future.value(reply);
          };
          closingRequest = model.closeTask(task, resolveSession: true);
        }
        final rejected = expectLater(
          closingRequest,
          throwsA(relatedFailure(WorkbenchFailureReason.invalidOwner)),
        );
        await started.future;
        final old = model.sessions['h']!.deepCopy()
          ..transaction = rpc.TransactionState.IDLE;
        if (closing == 'task rollback') old.sessionRevision = Int64(8);
        await model.disconnectRetainedSession('h');
        expect(model.sessions.containsKey('h'), isFalse);
        expect(
          model.acceptMetadataSnapshotRevision(
            's',
            4,
            3,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isTrue,
        );
        await model.transaction(
          rpc.SessionAction.DISCONNECT,
          target: model.captureSessionTarget('s'),
        );
        delayed.complete(old);
        await rejected;
        expect(model.sessions.containsKey('h'), isFalse);
        expect(
          model.acceptMetadataSnapshotRevision(
            'h',
            100,
            2,
            sourceIdentity: fixtureMetadataSourceIdentity,
          ),
          isFalse,
        );
        expect(model.metadataStampForSession('h'), isNull);
        expect(client.executions, isEmpty);
        expect(
          client.sessionCommands.where(
            (r) => r.action == rpc.SessionAction.ROLLBACK,
          ),
          hasLength(closing == 'task rollback' ? 1 : 0),
        );
      },
    );
  }
}
