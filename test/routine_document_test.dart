import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/structure_presentation.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  test('category breadcrumbs elide only redundant category identities', () {
    DatabaseObjectIdentity object(rpc.ObjectKind kind, String name) =>
        DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: kind,
          name: name,
        );
    expect(object(rpc.ObjectKind.SCHEMA, 'public').breadcrumb, 'db / public');
    expect(
      object(rpc.ObjectKind.TABLE, 'public').breadcrumb,
      'db / public / public',
    );
  });
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} Structure presents exact JDBC flags without SQL at 200% RTL',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('structure-properties-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: rpc.Profile(id: 'p'),
        );
        model.connectionOwner(rpc.Profile(id: 'p')).sessionId = 'inspection';
        model.explorerSessions['p'] = 'inspection';
        final owner = model.openTask(
          WorkbenchDocumentKind.structure,
          'Structure · db.public.t',
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'db',
            schema: 'public',
            kind: rpc.ObjectKind.TABLE,
            name: 't',
          ),
        )..view.structureSection = rpc.ObjectKind.INDEX.value;
        metadataFixture(model);
        backend.client.metadataAction = (_) async => rpc.SchemaObjects(
          complete: true,
          availability: 'available',
          objects: [
            rpc.SchemaObject(
              name: 'exact_key',
              kind: rpc.ObjectKind.INDEX,
              properties: {
                'column': 'quoted column',
                'ordinal': '2',
                'nonUnique': 'f',
              }.entries,
            ),
          ],
        );
        await tester.binding.setSurfaceSize(const Size(900, 600));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = ObjectDocumentView(
          model: model,
          owner: owner,
          controls: controls,
        );
        Widget scale(BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(builder: scale, home: view)
              : MaterialApp(
                  builder: scale,
                  home: Scaffold(body: view),
                ),
        );
        await tester.pumpAndSettle();
        final details = find.byType(SchemaObjectDetails);
        for (final value in [
          'Column',
          'Position',
          'Unique',
          'Yes',
          'quoted column',
        ]) {
          expect(
            find.descendant(of: details, matching: find.text(value)),
            findsOneWidget,
          );
        }
        expect(find.text('Available'), findsNothing);
        expect(find.text('nonUnique'), findsNothing);
        expect(find.text('f'), findsNothing);
        final context = tester.element(find.byType(ObjectDocumentView));
        for (final (raw, displayed) in [
          ('0', 'No'),
          ('1', 'Yes'),
          ('2', 'Unknown'),
          ('', 'Unknown'),
        ]) {
          expect(
            workbenchMetadataProperty(
              context,
              rpc.ObjectKind.COLUMN,
              'nullable',
              raw,
            ).value,
            displayed,
          );
        }
        expect(
          workbenchMetadataProperty(
            context,
            rpc.ObjectKind.INDEX,
            'nonUnique',
            'true',
          ).value,
          'No',
        );
        expect(
          workbenchMetadataProperty(
            context,
            rpc.ObjectKind.INDEX,
            'nonUnique',
            'unavailable',
          ).value,
          'Unavailable',
        );
        expect(
          workbenchMetadataProperty(
            context,
            rpc.ObjectKind.COLUMN,
            'generated',
            'price * 1.125',
          ).value,
          'price * 1.125',
        );
        expect(
          workbenchMetadataProperty(
            context,
            rpc.ObjectKind.COLUMN,
            'generated',
            'false',
            nativeDefinition: true,
          ).value,
          'false',
        );
        expect(
          workbenchMetadataProperty(
            context,
            rpc.ObjectKind.CONSTRAINT,
            'type',
            'p',
          ).value,
          'Primary key',
        );
        expect(
          workbenchMetadataProperty(
            context,
            rpc.ObjectKind.COLUMN,
            'type',
            'numeric(38,12)',
          ).value,
          'numeric(38,12)',
        );
        expect(
          backend.client.metadataRequests.single.kind,
          rpc.ObjectKind.INDEX,
        );
        expect(backend.client.executions, isEmpty);
        expect(owner.sessionId, isNull);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${controls.runtimeType} server search cancels superseded pages and opens the exact routine identity',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('routine-search-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          currentCatalog: 'db',
          currentSchema: 'public',
          profile: rpc.Profile(id: 'p'),
        );
        final source = model.connectionOwner(rpc.Profile(id: 'p'))
          ..sessionId = 'inspection';
        final data = ObjectSearchData('p', model.captureTarget(owner: source));
        final owner = model.openTask(
          WorkbenchDocumentKind.structure,
          'Search database objects',
          profileId: 'p',
          payload: data,
        );
        WorkbenchCommandContext? opened;
        model.commands = WorkbenchCommandRegistry([
          WorkbenchCommand(
            id: 'object.structure',
            label: 'Inspect',
            category: 'Object',
            invoke: (c) => opened = c,
          ),
        ]);
        final late = Completer<rpc.SchemaObjects>();
        metadataFixture(model);
        backend.client.metadataAction = (r) {
          if (r.search == 'old') return late.future;
          return Future.value(
            rpc.SchemaObjects(
              complete: true,
              objects: [
                r.search == 'view_child'
                    ? rpc.SchemaObject(
                        name: 'view_child',
                        table: 'native_view',
                        kind: rpc.ObjectKind.COLUMN,
                        catalog: 'db',
                        schema: 'public',
                      )
                    : rpc.SchemaObject(
                        name: 'same',
                        identifier: 'same(x text)',
                        kind: rpc.ObjectKind.ROUTINE,
                        catalog: 'db',
                        schema: 'public',
                      ),
              ],
            ),
          );
        };
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final query = TextEditingController();
        addTearDown(query.dispose);
        final searchKey = GlobalKey<DatabaseObjectSearchState>();
        final view = DatabaseObjectSearch(
          key: searchKey,
          model: model,
          controls: controls,
          target: data,
          owner: owner,
          externalQuery: query,
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        query.text = 'old';
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        query.text = 'same';
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        expect(backend.client.cancelledMetadataRequests, 1);
        late.complete(
          rpc.SchemaObjects(
            complete: true,
            objects: [rpc.SchemaObject(name: 'late_unrelated')],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('late_unrelated'), findsNothing);
        await tester.tap(find.text('db/public/same(x text)'));
        await tester.pumpAndSettle();
        expect(opened!.object!.identifier, 'same(x text)');
        expect(opened!.sessionId, 'inspection');
        expect(
          backend.client.metadataRequests.every((r) => r.globalSearch),
          isTrue,
        );
        expect(model.document.sessionId, isNull);
        expect(backend.client.executions, isEmpty);
        var requests = backend.client.metadataRequests.length;
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        expect(find.text('db/public/same(x text)'), findsOneWidget);
        expect(query.text, 'same');
        expect(backend.client.metadataRequests.length, requests);
        query.text = 'view_child';
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
        await tester.tap(find.text('db/public/native_view/view_child'));
        await tester.pumpAndSettle();
        expect(opened!.object!.kind, rpc.ObjectKind.COLUMN);
        expect(opened!.object!.parent, 'native_view');
        expect(opened!.object!.catalog, 'db');
        expect(opened!.object!.schema, 'public');
        requests = backend.client.metadataRequests.length;
        source.sessionId = 'replacement';
        await searchKey.currentState!.search();
        await tester.pumpAndSettle();
        expect(backend.client.metadataRequests.length, requests);
        expect(
          find.textContaining('execution context changed'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${controls.runtimeType} composite index structure targets the selected name and retains ordered columns',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('index-doc-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        model.document.sessionId = 'inspection';
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: rpc.Profile(id: 'p'),
        );
        final owner = model.openTask(
          WorkbenchDocumentKind.structure,
          'composite',
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'db',
            schema: 'public',
            parent: 'items',
            kind: rpc.ObjectKind.INDEX,
            name: 'composite',
          ),
        )..sessionId = 'inspection';
        metadataFixture(model);
        backend.client.metadataAction = (_) async => rpc.SchemaObjects(
          complete: true,
          objects: [
            rpc.SchemaObject(
              name: 'composite',
              kind: rpc.ObjectKind.INDEX,
              properties: {'column': 'a, b', 'columnCount': '2'}.entries,
            ),
            rpc.SchemaObject(
              name: 'unrelated',
              kind: rpc.ObjectKind.INDEX,
              properties: {'column': 'wrong'}.entries,
            ),
          ],
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = ObjectDocumentView(
          model: model,
          owner: owner,
          controls: controls,
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        expect(
          backend.client.metadataRequests.single.kind,
          rpc.ObjectKind.INDEX,
        );
        expect(backend.client.metadataRequests.single.table, 'items');
        expect(backend.client.metadataRequests.single.exactName, isTrue);
        expect(backend.client.metadataRequests.single.search, 'composite');
        expect(find.text('a, b'), findsOneWidget);
        expect(find.text('wrong'), findsNothing);
        expect(find.text('unrelated'), findsNothing);
        expect(backend.client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${controls.runtimeType} routine documents preserve overload identity and exact native definition',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('routine-doc-'),
        ))!;
        final backend = TestBackend();
        final model = (await tester.runAsync(() async => WorkbenchModel(root)))!
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final originalSql = model.document;
        final profile = rpc.Profile(
          id: 'p',
          name: 'Explicit staging',
          host: 'original',
        );
        model.profiles.add(profile);
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: profile,
        );
        model.explorerSessions['p'] = 'inspection';
        model.connectionOwner(profile).sessionId = 'inspection';
        DatabaseObjectIdentity identity(String arguments) =>
            DatabaseObjectIdentity(
              profileId: 'p',
              catalog: 'db',
              schema: 'public',
              kind: rpc.ObjectKind.ROUTINE,
              name: 'same',
              identifier: 'same($arguments)',
            );
        final a = identity('x integer'), b = identity('x text');
        final ownerA = model.openTask(
          WorkbenchDocumentKind.structure,
          a.displayName,
          object: a,
        );
        final ownerB = model.openTask(
          WorkbenchDocumentKind.structure,
          b.displayName,
          object: b,
        );
        expect(ownerA.id, isNot(ownerB.id));
        expect(
          model.openTask(
            WorkbenchDocumentKind.structure,
            a.displayName,
            object: a,
          ),
          same(ownerA),
        );
        backend.client.schemaTools = (request) async =>
            request.action == rpc.SchemaToolAction.OBJECT_DEFINITION
            ? rpc.SchemaToolResult(
                complete: true,
                provenance: 'native',
                inspectedObject: rpc.SchemaObject(
                  kind: request.kind,
                  catalog: request.catalog,
                  schema: request.schema,
                  name: request.table,
                  identifier: request.identifier,
                ),
                definition: request.identifier == a.identifier
                    ? r'CREATE FUNCTION public.same(x integer) RETURNS integer AS $$ SELECT 7 $$ LANGUAGE SQL'
                    : r'CREATE FUNCTION public.same(x text) RETURNS text AS $$ SELECT x $$ LANGUAGE SQL',
              )
            : rpc.SchemaToolResult(
                snapshot: jsonEncode({
                  'engine': 'POSTGRESQL',
                  'routines': {
                    a.identifier: {
                      'definition':
                          r'CREATE FUNCTION public.same(x integer) RETURNS integer AS $$ SELECT 7 $$ LANGUAGE SQL',
                      'kind': 'f',
                      'arguments': 'x integer',
                      'returnType': 'integer',
                    },
                    b.identifier: {
                      'definition':
                          r'CREATE FUNCTION public.same(x text) RETURNS text AS $$ SELECT x $$ LANGUAGE SQL',
                      'kind': 'f',
                      'arguments': 'x text',
                      'returnType': 'text',
                    },
                  },
                  'objectDependencies': {
                    'R:${a.identifier}': ['T:integer_dependency'],
                    'R:${b.identifier}': ['T:text_dependency'],
                  },
                }),
              );
        await tester.binding.setSurfaceSize(const Size(1000, 700));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        Future<void> show(WorkbenchDocument owner) async {
          final view = ObjectDocumentView(
            key: ValueKey(owner.id),
            model: model,
            owner: owner,
            controls: controls,
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(home: Scaffold(body: view)),
          );
          await tester.pumpAndSettle();
        }

        await show(ownerA);
        expect(find.textContaining('SELECT 7'), findsOneWidget);
        expect(find.textContaining('SELECT x'), findsNothing);
        expect(find.text('Columns'), findsNothing);
        expect(find.text('Indexes'), findsNothing);
        await show(ownerB);
        expect(find.textContaining('SELECT x'), findsOneWidget);
        expect(find.textContaining('SELECT 7'), findsNothing);
        expect(ownerA.sessionId, isNull);
        expect(ownerB.sessionId, isNull);
        expect(originalSql.sessionId, isNull);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.metadataRequests, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
