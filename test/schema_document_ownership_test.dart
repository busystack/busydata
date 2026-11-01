import 'dart:async';
import 'dart:io';
import 'package:fixnum/fixnum.dart';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/ui/common/plan_view.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/object_designer.dart';
import 'package:busydata/src/ui/common/schema_tools_view.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/structure_widgets.dart';
import 'package:busydata/src/ui/common/structure_presentation.dart';

void main() {
  for (final exactChild in [false, true]) {
    testWidgets(
      'structure reaches column 159 with exact scope: child $exactChild',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('structure-pages-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..backend = backend
          ..draftRecovery = false
          ..newDocument();
        final profile = rpc.Profile(id: 'p', engine: rpc.Engine.POSTGRESQL);
        model.sessions['metadata'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'metadata',
          profile: profile,
          currentCatalog: 'second',
          currentSchema: 'audit',
        );
        model.connectionOwner(profile).sessionId = 'metadata';
        model.explorerSessions['p'] = 'metadata';
        final owner = model.openTask(
          WorkbenchDocumentKind.structure,
          'Columns',
          object: DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'second',
            schema: 'audit',
            kind: exactChild ? rpc.ObjectKind.COLUMN : rpc.ObjectKind.TABLE,
            name: exactChild ? 'c159' : 'wide',
            parent: exactChild ? 'wide' : '',
          ),
        );
        backend.client.metadataAction = (r) async => rpc.SchemaObjects(
          complete: r.exactName || r.continuation.isNotEmpty,
          continuation: r.exactName || r.continuation.isNotEmpty ? '' : 'later',
          availability: 'available',
          objects: [
            for (
              var i = r.exactName
                  ? 159
                  : r.continuation.isEmpty
                  ? 0
                  : 128;
              i < (r.exactName || r.continuation.isNotEmpty ? 160 : 128);
              i++
            )
              rpc.SchemaObject(
                kind: rpc.ObjectKind.COLUMN,
                name: 'c${i.toString().padLeft(3, '0')}',
                properties: {
                  'ordinal': '${160 - i}',
                  'type': 'integer',
                }.entries,
              ),
          ],
        );
        metadataFixture(model);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StructureInspection(
                model: model,
                owner: owner,
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (exactChild) {
          expect(backend.client.metadataRequests.single.exactName, isTrue);
          expect(backend.client.metadataRequests.single.search, 'c159');
        } else {
          expect(backend.client.metadataRequests.map((r) => r.continuation), [
            '',
            'later',
          ]);
        }
        expect(
          backend.client.metadataRequests.every(
            (r) =>
                r.catalog == 'second' &&
                r.schema == 'audit' &&
                r.table == 'wide',
          ),
          isTrue,
        );
        if (exactChild) {
          expect(
            tester
                .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
                .object
                .name,
            'c159',
          );
        } else {
          await tester.scrollUntilVisible(
            find.text('c159').first,
            600,
            maxScrolls: 100,
            scrollable: find
                .byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down,
                )
                .first,
          );
          expect(find.text('c159'), findsWidgets);
          await tester.tap(find.text('c159').first);
          await tester.pumpAndSettle();
        }
        expect(find.text('integer'), findsAtLeastNWidgets(1));
        expect(backend.client.executions, isEmpty);
      },
    );
  }
  testWidgets(
    'structure hides stale evidence and rejects replies after explicit replacement',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('structure-rebind-'),
      ))!;
      final backend = TestBackend();
      final model = (await tester.runAsync(
        () async => WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(),
      ))!;
      final original = rpc.Profile(id: 'p', host: 'original');
      final replacement = original.deepCopy()..host = 'replacement';
      model.sessions['original'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'original',
        profile: original,
      );
      model.sessions['replacement'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'replacement',
        profile: replacement,
      );
      final owner = model.openTask(
        WorkbenchDocumentKind.table,
        'items',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: '',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'items',
        ),
        evidenceProfile: original,
      )..sessionId = 'original';
      Completer<rpc.SchemaObjects>? late;
      metadataFixture(model);
      backend.client.metadataAction = (request) async => late == null
          ? rpc.SchemaObjects(
              complete: true,
              objects: [rpc.SchemaObject(name: '${request.sessionId}_column')],
            )
          : late.future;
      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: model,
            builder: (_, _) => StructureInspection(
              model: model,
              owner: owner,
              controls: const LinuxControls(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('original_column'), findsAtLeastNWidgets(1));
      owner.sessionId = 'replacement';
      owner.evidenceProfile = replacement.deepCopy();
      model.activateOwner(owner.id);
      await tester.pump();
      expect(find.text('original_column'), findsNothing);
      expect(
        find.text('Inspection context changed. Refresh metadata explicitly.'),
        findsOneWidget,
      );
      expect(backend.client.metadataRequests, hasLength(1));
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('replacement_column'), findsAtLeastNWidgets(1));
      expect(backend.client.metadataRequests.last.sessionId, 'replacement');
      late = Completer<rpc.SchemaObjects>();
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pump();
      owner.sessionId = 'original';
      owner.evidenceProfile = original.deepCopy();
      model.activateOwner(owner.id);
      late.complete(
        rpc.SchemaObjects(
          complete: true,
          objects: [rpc.SchemaObject(name: 'late_wrong_column')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('late_wrong_column'), findsNothing);
      expect(backend.client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets(
    'late plan evidence stays with its execution and reuses retained SQL without rerun',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('plan-owner-'),
      ))!;
      final backend = TestBackend();
      final model = (await tester.runAsync(
        () async => WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(),
      ))!;
      final a = model.activeOwner;
      final result = rpc.StatementResult(
        resultId: 'plan-result',
        plan: true,
        complete: true,
        fetchedRows: Int64.ONE,
      );
      model.track(
        rpc.JobInfo(
          jobId: 'plan-job',
          executionId: 'plan-execution',
          state: rpc.JobState.COMPLETED,
          results: [result],
        ),
        documentId: a.id,
      );
      final retained = rpc.RetainedResult(
        jobId: 'plan-job',
        executionId: 'plan-execution',
        documentId: a.id,
        result: result,
        sourceSchema: 'original_schema',
        target: rpc.Profile(id: 'old', name: 'Original staging'),
        sqlProvenance: rpc.Value(text: 'EXPLAIN SELECT original_sql'),
      );
      model.retainedResults[result.resultId] = retained;
      final page = Completer<rpc.Page>();
      backend.client.pages = (_) => page.future;
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final tools = SchemaToolsView(model, const LinuxControls(), owner: a);
      final reading = tools.plan(context);
      expect(backend.client.pageRequests, hasLength(1));
      model.newDocument(text: 'SELECT another_target');
      final b = model.activeOwner;
      final focus = FocusManager.instance.primaryFocus;
      page.complete(
        rpc.Page(
          state: rpc.PageState.PAGE_END,
          rows: [
            rpc.Row(
              values: [rpc.Value(text: '{"Plan":{"Node Type":"Result"}}')],
            ),
          ],
        ),
      );
      await reading;
      expect(model.activeOwner, same(b));
      expect(FocusManager.instance.primaryFocus, same(focus));
      final state = a.view.results[result.resultId]!;
      expect(state.planEvidence, isA<PlanData>());
      expect(a.view.output, 'plan');
      expect(b.view.output, isNot('plan'));
      expect(state.planEvidenceUnits, greaterThan(0));
      expect(
        model.documentBudget.units,
        greaterThan(model.document.editor.text.length),
      );
      await tools.plan(context, openDocument: true);
      final independent = model.activeOwner;
      expect(independent.kind, WorkbenchDocumentKind.plan);
      expect(independent.sql, isNull);
      expect(independent.payload, isNot(same(state.planEvidence)));
      (independent.payload! as PlanData).selected = 2;
      expect((state.planEvidence! as PlanData).selected, 0);
      expect(independent.sessionId, isNull);
      expect(independent.retained!.sourceSchema, 'original_schema');
      expect(
        independent.retained!.sqlProvenance.text,
        contains('original_sql'),
      );
      expect(backend.client.pageRequests, hasLength(1));
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
      final charged = model.documentBudget.units;
      await tester.runAsync(() => model.closeTask(independent));
      expect(model.documentBudget.units, lessThan(charged));
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );

  testWidgets(
    'plan approval is unavailable on ordinary retained data and disposed evidence is rejected',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('plan-disposal-'),
      ))!;
      final backend = TestBackend();
      final budget = DocumentBudget(maxUnits: 300);
      final model = WorkbenchModel(root, documentBudget: budget)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      final owner = model.activeOwner;
      final result = rpc.StatementResult(resultId: 'source', complete: true);
      model.track(
        rpc.JobInfo(jobId: 'j', executionId: 'e', results: [result]),
        documentId: owner.id,
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final tools = SchemaToolsView(model, const LinuxControls(), owner: owner);
      await expectLater(tools.plan(context), throwsStateError);
      expect(backend.client.pageRequests, isEmpty);
      final planResult = result.deepCopy()..plan = true;
      final reply = model.jobs['j']!.toBuilder() as rpc.JobInfo;
      reply.results[0] = planResult;
      model.jobs['j'] = reply;
      model.retainedResults['source'] = rpc.RetainedResult(result: planResult);
      final page = Completer<rpc.Page>();
      backend.client.pages = (_) => page.future;
      final reading = tools.plan(context);
      model.disposedResults.add('source');
      page.complete(
        rpc.Page(
          state: rpc.PageState.PAGE_END,
          rows: [
            rpc.Row(values: [rpc.Value(text: '-> Result')]),
          ],
        ),
      );
      await expectLater(reading, throwsStateError);
      expect(owner.view.results['source']?.planEvidence, isNull);
      model.disposedResults.clear();
      final before = budget.units;
      expect(
        () => model.reserveResultEvidence(owner, 'source', 301),
        throwsA(isA<DocumentResourceLimit>()),
      );
      expect(budget.units, before);
      expect(owner.view.results['source']!.planEvidenceUnits, 0);
      expect(backend.client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );

  testWidgets(
    'designer reinspection preserves its replacement session and rejects stale generation',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('design-context-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      final profile = rpc.Profile(id: 'p', name: 'Staging');
      model.profiles.add(profile);
      final source = model.activeOwner
        ..profileId = 'p'
        ..sessionId = 'initial';
      for (final id in ['initial', 'replacement']) {
        model.sessions[id] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: id,
          profile: profile,
          currentSchema: 'public',
        );
      }
      backend.client.schemaTools = (_) async => rpc.SchemaToolResult(
        complete: true,
        snapshot: '{"tables":{},"views":{},"routines":{}}',
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      final tools = SchemaToolsView(
        model,
        const LinuxControls(),
        owner: source,
      );
      await tools.designer(context);
      final owner = model.activeOwner;
      expect(owner.sql, isNull);
      expect(owner.sessionId, 'initial');
      final old = owner.payload;
      owner.designDraft.fields['name'] = 'uncommitted intention';
      owner.sessionId = 'replacement';
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchDocumentView(
            model: model,
            owner: owner,
            controls: const LinuxControls(),
          ),
        ),
      );
      final stale = tester.widget<ObjectDesignerForm>(
        find.byType(ObjectDesignerForm),
      );
      await expectLater(
        stale.generate(
          rpc.SchemaToolRequest(
            sessionId: 'initial',
            context: backend.context(),
          ),
        ),
        throwsStateError,
      );
      expect(backend.client.schemaToolRequests, hasLength(1));
      await tools.designer(tester.element(find.byType(ObjectDesignerForm)));
      expect(model.activeOwner, same(owner));
      expect(owner.sessionId, 'replacement');
      expect(backend.client.schemaToolRequests.last.sessionId, 'replacement');
      expect(owner.payload, isNot(same(old)));
      expect(owner.designDraft.fields['name'], 'uncommitted intention');
      expect(backend.client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );

  testWidgets(
    'diagram documents reuse exact scopes and reject incomplete relationships',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('diagram-context-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      final profile = rpc.Profile(id: 'p', name: 'Staging');
      model.profiles.add(profile);
      final source = model.activeOwner
        ..profileId = 'p'
        ..sessionId = 'metadata';
      model.sessions['metadata'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'metadata',
        profile: profile,
        currentSchema: 'public',
      );
      var incomplete = false;
      metadataFixture(model);
      backend.client.metadataAction = (r) async => rpc.SchemaObjects(
        complete: !incomplete,
        availability: incomplete ? 'limited' : '',
        objects: r.kind == rpc.ObjectKind.TABLE
            ? [rpc.SchemaObject(name: 'a'), rpc.SchemaObject(name: 'b')]
            : [],
      );
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      DatabaseObjectIdentity scope(String table) => DatabaseObjectIdentity(
        profileId: 'p',
        catalog: '',
        schema: 'public',
        kind: rpc.ObjectKind.TABLE,
        name: table,
      );
      final a = SchemaToolsView(
        model,
        const LinuxControls(),
        owner: source,
        object: scope('a'),
      );
      await a.diagram(context);
      final first = model.activeOwner;
      final requests = backend.client.metadataRequests.length;
      await a.diagram(context);
      expect(model.activeOwner, same(first));
      expect(backend.client.metadataRequests, hasLength(requests));
      await SchemaToolsView(
        model,
        const LinuxControls(),
        owner: source,
        object: scope('b'),
      ).diagram(context);
      expect(model.taskDocuments, hasLength(2));
      expect(model.activeOwner.object!.name, 'b');
      expect(model.activeOwner.evidenceProfile!.name, 'Staging');
      expect(model.documentBudget.units, greaterThan(0));
      final replacement = profile.deepCopy()..host = 'different-endpoint';
      model.sessions['metadata']!.profile = replacement;
      await a.diagram(context);
      final differentTarget = model.activeOwner;
      expect(differentTarget, isNot(same(first)));
      expect(differentTarget.evidenceProfile!.host, 'different-endpoint');
      expect(first.evidenceProfile!.host, isEmpty);
      final replacementRequests = backend.client.metadataRequests.length;
      await a.diagram(context);
      expect(model.activeOwner, same(differentTarget));
      expect(backend.client.metadataRequests, hasLength(replacementRequests));
      incomplete = true;
      await expectLater(
        SchemaToolsView(
          model,
          const LinuxControls(),
          owner: source,
          object: scope('c'),
        ).diagram(context),
        throwsStateError,
      );
      expect(model.taskDocuments, hasLength(3));
      for (final total in [160, 10001]) {
        backend.client.metadataAction = (r) async {
          if (r.kind == rpc.ObjectKind.TABLE) {
            return rpc.SchemaObjects(
              complete: true,
              objects: [rpc.SchemaObject(kind: r.kind, name: r.table)],
            );
          }
          final start = r.continuation.isEmpty ? 0 : int.parse(r.continuation);
          final end = (start + r.limit).clamp(0, total);
          return rpc.SchemaObjects(
            complete: end == total,
            continuation: end == total ? '' : '$end',
            availability: 'available',
            objects: [
              for (var i = start; i < end; i++)
                rpc.SchemaObject(
                  kind: r.kind,
                  name: 'fk_$i',
                  table: r.table,
                  properties: {'referencedTable': 'other'}.entries,
                ),
            ],
          );
        };
        final run = SchemaToolsView(
          model,
          const LinuxControls(),
          owner: source,
          object: scope('paged_$total'),
        ).diagram(context);
        if (total == 160) {
          await run;
          expect(
            (model.activeOwner.payload as DiagramDocumentData).edges,
            hasLength(160),
          );
        } else {
          await expectLater(run, throwsStateError);
          expect(model.taskDocuments, hasLength(4));
        }
      }
      backend.client.metadataAction = (r) async => rpc.SchemaObjects(
        complete: true,
        objects: [
          for (var i = 0; i < 101; i++)
            rpc.SchemaObject(kind: rpc.ObjectKind.TABLE, name: 'table_$i'),
        ],
      );
      await expectLater(
        SchemaToolsView(
          model,
          const LinuxControls(),
          owner: source,
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: '',
            schema: 'public',
            kind: rpc.ObjectKind.SCHEMA,
            name: 'public',
          ),
        ).diagram(context),
        throwsStateError,
      );
      expect(model.taskDocuments, hasLength(4));
      expect(backend.client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
