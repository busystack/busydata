import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/structure_presentation.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show CallOptions, ResponseFuture;
import 'package:mocktail/mocktail.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/schema_overview_fixture.dart';

class _DelayedMetadataCancellationClient extends TestClient {
  Completer<void>? cancellation;

  @override
  ResponseFuture<rpc.SchemaObjects> explore(
    rpc.ExploreRequest request, {
    CallOptions? options,
  }) {
    final original = super.explore(request, options: options);
    final call = MockCall<rpc.SchemaObjects>();
    when(() => call.response).thenAnswer((_) => original.asStream());
    when(() => call.cancel()).thenAnswer((_) async {
      cancelledMetadataRequests++;
      await cancellation?.future;
    });
    return ResponseFuture(call);
  }
}

void main() {
  const controls = LinuxControls();
  Future<(WorkbenchModel, TestBackend, WorkbenchDocument)> mount(
    WidgetTester tester, {
    rpc.ObjectKind kind = rpc.ObjectKind.TABLE,
    String parent = '',
    String name = 'customers',
    TestClient? client,
  }) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('busydata/native_menus'),
      (_) async => throw MissingPluginException(),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('busydata/native_menus'),
        null,
      ),
    );
    final backend = TestBackend(client: client);
    final model = metadataFixture(
      WorkbenchModel(Directory('/unused'))
        ..backend = backend
        ..draftRecovery = false
        ..newDocument(),
    );
    final profile = rpc.Profile(
      id: 'p',
      engine: rpc.Engine.POSTGRESQL,
      database: 'db',
    );
    model.sessions['inspection'] = rpc.SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'inspection',
      profile: profile,
      currentCatalog: 'db',
      currentSchema: 'public',
      autoCommit: true,
    );
    model.connectionOwner(profile).sessionId = 'inspection';
    model.explorerSessions['p'] = 'inspection';
    final owner = model.openTask(
      WorkbenchDocumentKind.structure,
      name,
      object: DatabaseObjectIdentity(
        profileId: 'p',
        catalog: 'db',
        schema: 'public',
        kind: kind,
        name: name,
        parent: parent,
      ),
    );
    backend.client.metadataAction = (r) async => rpc.SchemaObjects(
      complete: true,
      availability: 'available',
      objects: schemaSectionFixture(r.kind),
    );
    backend.client.schemaTools = (r) async => rpc.SchemaToolResult(
      inspectedObject: rpc.SchemaObject(
        kind: kind,
        catalog: 'db',
        schema: 'public',
        table: parent,
        name: name,
      ),
      definition: 'CREATE ${kind.name} public.$name; -- exact evidence',
      provenance: 'native',
      snapshot: jsonEncode({
        'engine': 'POSTGRESQL',
        'objectDependencies': {
          'T:customers': ['V:customer_source'],
          'V:dependent_view': ['T:customers'],
        },
      }),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    });
    await tester.binding.setSurfaceSize(const Size(980, 650));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: model,
            builder: (_, _) => Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    width: 280,
                    child: StructureControls(
                      model: model,
                      owner: owner,
                      controls: controls,
                    ),
                  ),
                ),
                Expanded(
                  child: ObjectDocumentView(
                    model: model,
                    owner: owner,
                    controls: controls,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (model, backend, owner);
  }

  testWidgets(
    'five schema rows share one selected detail; reorder and removal retain exact identity',
    (tester) async {
      final (model, backend, owner) = await mount(tester);
      final sessions = model.sessions.keys.toList(),
          documents = model.workbenchDocuments.map((o) => o.id).toList();
      for (final column in customerColumns()) {
        expect(find.text(column.name).first.hitTestable(), findsOneWidget);
      }
      expect(find.byType(SchemaObjectDetails), findsOneWidget);
      expect(
        find.byType(WorkbenchReadOnlyProperty),
        findsNWidgets(customerColumns().first.properties.length),
      );
      expect(find.text('Available'), findsNothing);
      await tester.tap(find.text('email').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
            .object
            .name,
        'email',
      );
      final long = 'captured_default_${'value,' * 100}';
      backend.client.metadataAction = (_) async => rpc.SchemaObjects(
        complete: true,
        availability: 'available',
        objects: customerColumns().reversed.map((o) {
          if (o.name == 'email') {
            o.properties['default'] = long;
            o.properties['ordinal'] = '99';
          }
          return o;
        }),
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      final details = tester.widget<SchemaObjectDetails>(
        find.byType(SchemaObjectDetails),
      );
      expect(details.object.name, 'email');
      expect(details.object.properties['ordinal'], '99');
      expect(
        find.byWidgetPredicate((w) => w is SelectableText && w.data == long),
        findsOneWidget,
      );
      backend.client.metadataAction = (_) async => rpc.SchemaObjects(
        complete: true,
        availability: 'available',
        objects: customerColumns().where((o) => o.name != 'email'),
      );
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.byType(SchemaObjectDetails), findsNothing);
      expect(
        find.textContaining('previous selection is unavailable'),
        findsOneWidget,
      );
      expect(
        owner.view.structureSelections[rpc.ObjectKind.COLUMN.value],
        isNull,
      );
      expect(model.sessions.keys, sessions);
      expect(model.workbenchDocuments.map((o) => o.id), documents);
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
    },
  );
  testWidgets(
    'mutual dependencies have independent row selection and retain their direction on refresh',
    (tester) async {
      final (model, backend, owner) = await mount(tester);
      final sessions = model.sessions.keys.toList();
      backend.client.schemaTools = (_) async => rpc.SchemaToolResult(
        snapshot: jsonEncode({
          'engine': 'POSTGRESQL',
          'objectDependencies': {
            'T:customers': ['R:customer_lookup()'],
            'R:customer_lookup()': ['T:customers'],
          },
        }),
      );
      model.inspectStructureSection(owner, 10);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final rows = find.descendant(
        of: find.byType(SchemaOverview),
        matching: find.text('R:customer_lookup()'),
      );
      expect(rows, findsNWidgets(2));
      String direction() => tester
          .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
          .object
          .properties['Relationship']!;
      expect(direction(), 'Referenced by this object');
      await tester.tap(rows.at(1));
      await tester.pumpAndSettle();
      expect(direction(), 'Depends on this object');
      final selected = owner.view.structureSelections[10];
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(direction(), 'Depends on this object');
      expect(owner.view.structureSelections[10], selected);
      expect(model.sessions.keys, sessions);
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'every table inspection section retains exact properties and definition provenance',
    (tester) async {
      final (model, backend, owner) = await mount(tester);
      for (final kind in [
        rpc.ObjectKind.COLUMN,
        rpc.ObjectKind.INDEX,
        rpc.ObjectKind.CONSTRAINT,
        rpc.ObjectKind.FOREIGN_KEY,
        rpc.ObjectKind.TRIGGER,
      ]) {
        model.inspectStructureSection(owner, kind.value);
        await tester.pumpAndSettle();
        final expected = schemaSectionFixture(kind).first;
        expect(
          tester
              .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
              .object
              .name,
          expected.name,
        );
        expect(
          tester
              .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
              .object
              .properties,
          expected.properties,
        );
        if (kind == rpc.ObjectKind.INDEX) {
          expect(
            find.text('Yes'),
            findsWidgets,
            reason: 'nonUnique false means Unique Yes',
          );
          await tester.tap(find.text('customers_email_idx').first);
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
                .object
                .properties['nonUnique'],
            'true',
          );
        }
      }
      model.inspectStructureSection(owner, rpc.ObjectKind.TABLE.value);
      await tester.pumpAndSettle();
      expect(find.text('Captured native definition'), findsOneWidget);
      expect(find.byType(SchemaOverview), findsNothing);
      expect(find.textContaining('-- exact evidence'), findsOneWidget);
      model.inspectStructureSection(owner, 10);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('dynamic SQL is not inferred'),
        findsOneWidget,
      );
      expect(find.text('V:customer_source').first, findsOneWidget);
      expect(find.text('V:dependent_view'), findsOneWidget);
      expect(backend.client.executions, isEmpty);
    },
  );
  testWidgets(
    'unknown, unsupported, missing and empty captured values remain distinct',
    (tester) async {
      final (model, backend, owner) = await mount(tester);
      backend.client.metadataAction = (_) async => rpc.SchemaObjects(
        complete: true,
        availability: 'available',
        objects: customerColumns().map((column) {
          if (column.name == 'email') column.properties['nullable'] = 'UNKNOWN';
          if (column.name == 'status') {
            column.properties['nullable'] = 'unsupported';
          }
          if (column.name == 'created_at') column.properties.remove('nullable');
          return column;
        }),
      );
      model.inspectStructureSection(owner, rpc.ObjectKind.COLUMN.value);
      await tester.pumpAndSettle();
      for (final (name, expected) in [
        ('email', 'Unknown'),
        ('status', 'Unsupported'),
      ]) {
        await tester.tap(find.text(name).first);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(SchemaObjectDetails),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is WorkbenchReadOnlyProperty &&
                  w.label == 'Nullable' &&
                  w.value == expected,
            ),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('created_at').first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SchemaObjectDetails),
          matching: find.byWidgetPredicate(
            (w) => w is WorkbenchReadOnlyProperty && w.label == 'Nullable',
          ),
        ),
        findsNothing,
      );
      await tester.tap(find.text('name').first);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SchemaObjectDetails),
          matching: find.byWidgetPredicate(
            (w) =>
                w is WorkbenchReadOnlyProperty &&
                w.label == 'Default expression' &&
                w.value.isEmpty,
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('NULL'), findsNothing);
      expect(backend.client.executions, isEmpty);
    },
  );
  for (final kind in [
    rpc.ObjectKind.VIEW,
    rpc.ObjectKind.ROUTINE,
    rpc.ObjectKind.SEQUENCE,
  ]) {
    testWidgets('${kind.name} retains its supported sections', (tester) async {
      final (model, backend, owner) = await mount(tester, kind: kind);
      final context = tester.element(find.byType(ObjectDocumentView));
      expect(
        structureSections(context, owner).keys,
        kind == rpc.ObjectKind.VIEW
            ? [4, 2, 10]
            : kind == rpc.ObjectKind.ROUTINE
            ? [2, 10]
            : [2],
      );
      if (kind == rpc.ObjectKind.VIEW) {
        expect(find.text('created_at'), findsOneWidget);
      }
      expect(backend.client.executions, isEmpty);
      expect(model.activeOwner, same(owner));
    });
  }
  for (final kind in [
    rpc.ObjectKind.COLUMN,
    rpc.ObjectKind.INDEX,
    rpc.ObjectKind.CONSTRAINT,
    rpc.ObjectKind.FOREIGN_KEY,
    rpc.ObjectKind.TRIGGER,
  ]) {
    testWidgets(
      'direct ${kind.name} shares details and exact child definition',
      (tester) async {
        final expected = schemaSectionFixture(kind).first;
        final (model, backend, owner) = await mount(
          tester,
          kind: kind,
          parent: 'customers',
          name: expected.name,
        );
        expect(find.byType(SchemaOverview), findsNothing);
        expect(find.byType(SchemaObjectDetails), findsOneWidget);
        expect(
          tester
              .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
              .showName,
          isFalse,
        );
        expect(backend.client.metadataRequests.single.exactName, isTrue);
        expect(backend.client.metadataRequests.single.search, expected.name);
        model.inspectStructureSection(owner, rpc.ObjectKind.TABLE.value);
        await tester.pumpAndSettle();
        expect(find.textContaining('-- exact evidence'), findsOneWidget);
        expect(
          backend.client.schemaToolRequests.last.objectName,
          expected.name,
        );
        expect(backend.client.executions, isEmpty);
      },
    );
  }
  testWidgets(
    'Indexes to Definition clears old rows before delayed cancellation resumes',
    (tester) async {
      final client = _DelayedMetadataCancellationClient();
      final (model, backend, owner) = await mount(tester, client: client);
      model.inspectStructureSection(owner, rpc.ObjectKind.INDEX.value);
      await tester.pumpAndSettle();
      expect(find.byType(SchemaOverview), findsOneWidget);
      expect(find.text('customers_pkey').first, findsOneWidget);
      expect(find.text('customers_email_idx').first, findsOneWidget);
      await tester.tap(find.text('customers_email_idx').first);
      await tester.pumpAndSettle();
      final selectedIndex =
          owner.view.structureSelections[rpc.ObjectKind.INDEX.value];
      final beforeDefinitions = backend.client.schemaToolRequests.length;
      final cancelled = Completer<void>();
      client.cancellation = cancelled;
      model.inspectStructureSection(owner, rpc.ObjectKind.TABLE.value);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SchemaOverview), findsNothing);
      expect(find.byType(SchemaObjectDetails), findsNothing);
      expect(backend.client.schemaToolRequests.length, beforeDefinitions);
      expect(find.text('Loading'), findsOneWidget);
      cancelled.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final details = tester.widget<SchemaObjectDetails>(
        find.byType(SchemaObjectDetails),
      );
      expect(details.object.name, 'customers');
      expect(details.object.kind, rpc.ObjectKind.TABLE);
      expect(details.nativeDefinition, isTrue);
      expect(find.textContaining('-- exact evidence'), findsOneWidget);
      expect(backend.client.schemaToolRequests.length, beforeDefinitions + 1);
      client.cancellation = null;
      model.inspectStructureSection(owner, rpc.ObjectKind.INDEX.value);
      await tester.pumpAndSettle();
      expect(
        owner.view.structureSelections[rpc.ObjectKind.INDEX.value],
        selectedIndex,
      );
      expect(
        tester
            .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
            .object
            .name,
        'customers_email_idx',
      );
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
    },
  );
  testWidgets(
    'a superseded section waiting for cancellation never starts its definition request',
    (tester) async {
      final client = _DelayedMetadataCancellationClient();
      final (model, backend, owner) = await mount(tester, client: client);
      model.inspectStructureSection(owner, rpc.ObjectKind.INDEX.value);
      await tester.pumpAndSettle();
      final beforeDefinitions = backend.client.schemaToolRequests.length;
      final cancelled = Completer<void>();
      client.cancellation = cancelled;
      model.inspectStructureSection(owner, rpc.ObjectKind.TABLE.value);
      await tester.pump();
      expect(tester.takeException(), isNull);
      model.inspectStructureSection(owner, rpc.ObjectKind.COLUMN.value);
      await tester.pump();
      cancelled.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(backend.client.schemaToolRequests.length, beforeDefinitions);
      expect(
        tester
            .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
            .object
            .kind,
        rpc.ObjectKind.COLUMN,
      );
      expect(backend.client.executions, isEmpty);
    },
  );
  testWidgets(
    'ambiguous current direct evidence is unavailable without picking an object',
    (tester) async {
      final (model, backend, owner) = await mount(tester);
      model.inspectStructureSection(owner, rpc.ObjectKind.TABLE.value);
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(ObjectDocumentView));
      state.acceptObjects([
        rpc.SchemaObject(kind: rpc.ObjectKind.TABLE, name: 'customers'),
        rpc.SchemaObject(kind: rpc.ObjectKind.TABLE, name: 'other'),
      ]);
      model.updateStatus('Refresh current direct metadata');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SchemaObjectDetails), findsNothing);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(backend.client.executions, isEmpty);
    },
  );
  testWidgets(
    'changing sections rejects a delayed column response before its next frame',
    (tester) async {
      final (model, backend, owner) = await mount(tester);
      final delayed = Completer<rpc.SchemaObjects>();
      backend.client.metadataAction = (r) => r.kind == rpc.ObjectKind.COLUMN
          ? delayed.future
          : Future.value(
              rpc.SchemaObjects(
                complete: true,
                availability: 'available',
                objects: schemaSectionFixture(r.kind),
              ),
            );
      model.inspectStructureSection(owner, rpc.ObjectKind.COLUMN.value);
      await tester.pump();
      model.inspectStructureSection(owner, rpc.ObjectKind.INDEX.value);
      await tester.pump();
      delayed.complete(
        rpc.SchemaObjects(
          complete: true,
          objects: [rpc.SchemaObject(name: 'stale_column')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('stale_column'), findsNothing);
      expect(
        tester
            .widget<SchemaObjectDetails>(find.byType(SchemaObjectDetails))
            .object
            .kind,
        rpc.ObjectKind.INDEX,
      );
    },
  );
  testWidgets(
    'a section popup retains its owner and rejects a replaced inspection session',
    (tester) async {
      final (model, backend, owner) = await mount(tester);
      await tester.tap(find.text('Columns').first);
      await tester.pumpAndSettle();
      expect(find.text('Indexes').last.hitTestable(), findsOneWidget);
      model.newDocument();
      final other = model.activeOwner;
      await tester.pump();
      await tester.tap(find.text('Indexes').last);
      await tester.pumpAndSettle();
      expect(owner.view.structureSection, rpc.ObjectKind.INDEX.value);
      expect(other.view.structureSection, rpc.ObjectKind.COLUMN.value);
      expect(backend.client.metadataRequests.last.sessionId, 'inspection');
      final previous = backend.client.metadataRequests.length;
      await tester.tap(find.text('Indexes').first);
      await tester.pumpAndSettle();
      expect(find.text('Columns').last.hitTestable(), findsOneWidget);
      model.sessions['replacement'] = model.sessions['inspection']!.deepCopy()
        ..sessionId = 'replacement';
      owner.sessionId = 'replacement';
      model.activateOwner(owner.id);
      await tester.pump();
      await tester.tap(find.text('Columns').last);
      await tester.pumpAndSettle();
      expect(owner.view.structureSection, rpc.ObjectKind.INDEX.value);
      expect(backend.client.metadataRequests.length, previous);
      expect(
        model.status,
        'Inspection context changed. Refresh metadata explicitly.',
      );
      expect(backend.client.executions, isEmpty);
    },
  );
}
