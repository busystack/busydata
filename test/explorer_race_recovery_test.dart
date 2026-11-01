import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  testWidgets('completed reveal cannot reclaim a newer pointer selection', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('reveal-new-selection-'),
    ))!;
    final backend = TestBackend();
    final profile = rpc.Profile(
      id: 'p',
      name: 'Source',
      engine: rpc.Engine.POSTGRESQL,
    );
    final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
      ..backend = backend
      ..draftRecovery = false
      ..profiles.add(profile)
      ..newDocument(text: 'SELECT unchanged');
    model.explorerSessions['p'] = 'inspection';
    model.sessions['inspection'] = rpc.SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'inspection',
      profile: profile,
      currentCatalog: 'db',
      currentSchema: 'public',
    );
    await model.selectNamespaces('p', '', NamespaceSelection(names: ['db']));
    await model.selectNamespaces(
      'p',
      'db',
      NamespaceSelection(names: ['public']),
    );
    backend.client.metadataAction = (r) async => rpc.SchemaObjects(
      complete: true,
      objects: switch (r.kind) {
        rpc.ObjectKind.CATALOG => [rpc.SchemaObject(kind: r.kind, name: 'db')],
        rpc.ObjectKind.SCHEMA => [
          rpc.SchemaObject(kind: r.kind, name: 'public'),
        ],
        rpc.ObjectKind.TABLE => [
          for (final name in ['customers', 'invoices'])
            rpc.SchemaObject(kind: r.kind, name: name),
        ],
        _ => [],
      },
    );
    metadataFixture(model);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    });
    final semantics = tester.ensureSemantics();
    try {
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
      model.revealInExplorer(
        const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'customers',
        ),
      );
      for (
        var frame = 0;
        frame < 20 && model.explorerCommandContext?.object?.name != 'customers';
        frame++
      ) {
        await tester.pump();
      }
      expect(model.explorerCommandContext?.object?.name, 'customers');
      await tester.tap(find.bySemanticsLabel(RegExp(r'^invoices · level')));
      await tester.pumpAndSettle();
      expect(model.explorerCommandContext?.object?.name, 'invoices');
      final tables = find.bySemanticsLabel(RegExp(r'^Tables · level'));
      final tableNode = tester.getSemantics(tables);
      tableNode.owner!.performAction(tableNode.id, ui.SemanticsAction.focus);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tables).flagsCollection.isExpanded,
        ui.Tristate.isTrue,
      );
      expect(
        tester.getSemantics(tables).flagsCollection.isSelected,
        ui.Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tables).flagsCollection.isExpanded,
        ui.Tristate.isFalse,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(tables).flagsCollection.isExpanded,
        ui.Tristate.isTrue,
      );
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT unchanged');
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'reveal refuses a replacement connection and accepts a display rename on the original target',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('reveal-source-change-'),
      ))!;
      final backend = TestBackend();
      final original = rpc.Profile(
        id: 'p',
        name: 'Original',
        host: 'original-host',
        engine: rpc.Engine.POSTGRESQL,
      );
      final replacement = original.deepCopy()..host = 'replacement-host';
      final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
        ..backend = backend
        ..draftRecovery = false
        ..profiles.add(replacement)
        ..newDocument();
      model.explorerSessions['p'] = 'replacement-metadata';
      model.sessions['replacement-metadata'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'replacement-metadata',
        profile: replacement,
        currentCatalog: 'db',
        currentSchema: 'public',
      );
      backend.client.metadataAction = (request) async =>
          rpc.SchemaObjects(complete: true);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
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
      await tester.pumpAndSettle();
      model.revealInExplorer(
        const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'customers',
        ),
        evidenceProfile: original,
      );
      await tester.pumpAndSettle();
      expect(backend.client.metadataRequests, isEmpty);
      expect(backend.client.opened, isEmpty);
      expect(model.status, contains('context changed'));
      expect(
        model.explorerSourceMatches(
          const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'other_db',
            schema: 'audit',
            kind: rpc.ObjectKind.TABLE,
            name: 'customers',
          ),
          replacement.deepCopy()..name = 'Renamed',
        ),
        isTrue,
      );
      expect(backend.client.executions, isEmpty);
    },
  );
  testWidgets(
    'refresh preserves an exact selected object outside the first page without replaying SQL',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('tree-refresh-selection-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
        database: 'db',
      );
      final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
        ..draftRecovery = false
        ..backend = backend
        ..profiles.add(profile)
        ..newDocument(text: 'SELECT preserved');
      model.explorerSessions['p'] = 'metadata';
      model.sessions['metadata'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'metadata',
        profile: profile,
        currentCatalog: 'db',
        currentSchema: 'public',
        sessionRevision: Int64.ONE,
      );
      var revision = 1;
      backend.client.metadataAction = (request) async {
        if (request.refresh) revision++;
        final response = rpc.SchemaObjects(
          complete: true,
          sessionRevision: Int64(revision),
        );
        if (request.kind == rpc.ObjectKind.CATALOG ||
            request.kind == rpc.ObjectKind.SCHEMA) {
          response.objects.add(
            rpc.SchemaObject(
              kind: request.kind,
              name: request.kind == rpc.ObjectKind.CATALOG ? 'db' : 'public',
            ),
          );
        } else if (request.kind == rpc.ObjectKind.TABLE) {
          final start = int.tryParse(request.continuation) ?? 0;
          final end = (start + request.limit).clamp(0, 260);
          response.totalCount = Int64(request.exactName ? 1 : 260);
          response.countAvailability = rpc.MetadataCount.AUTHORITATIVE_TOTAL;
          response.complete = request.exactName || end == 260;
          response.continuation = response.complete ? '' : '$end';
          response.objects.addAll([
            if (request.exactName)
              rpc.SchemaObject(kind: request.kind, name: request.search)
            else
              for (var index = start; index < end; index++)
                rpc.SchemaObject(
                  kind: request.kind,
                  name: 'item_${index.toString().padLeft(4, '0')}',
                ),
          ]);
        }
        return response;
      };
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DatabaseExplorer(
              model: metadataFixture(model),
              controls: const LinuxControls(),
            ),
          ),
        ),
      );
      for (final name in ['Source', 'public', 'Tables']) {
        await tester.tap(find.bySemanticsLabel('Expand $name'));
        await tester.pumpAndSettle();
      }
      for (var page = 0; page < 2; page++) {
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('item_0259'));
      await tester.pumpAndSettle();
      expect(model.explorerCommandContext?.object?.name, 'item_0259');
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('item_0259'), findsOneWidget);
      expect(model.explorerCommandContext?.object?.name, 'item_0259');
      expect(model.explorerCommandContext?.object?.catalog, 'db');
      expect(model.explorerCommandContext?.object?.schema, 'public');
      expect(model.sessions['metadata']!.sessionRevision, Int64(2));
      expect(backend.client.metadataRequests.last.exactName, isTrue);
      expect(backend.client.metadataRequests.last.search, 'item_0259');
      expect(backend.client.metadataRequests.last.catalog, 'db');
      expect(backend.client.metadataRequests.last.schema, 'public');
      expect(
        backend.client.metadataRequests.where((r) => r.refresh),
        hasLength(1),
      );
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT preserved');
      semantics.dispose();
    },
  );
  for (final inFolder in [false, true]) {
    testWidgets(
      'reopening ${inFolder ? 'a source folder' : 'a source'} resumes canceled expanded metadata without connecting or running SQL',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('tree-cancel-resume-'),
        ))!;
        final backend = TestBackend();
        final profile = rpc.Profile(
          id: 'p',
          name: 'Source',
          engine: rpc.Engine.POSTGRESQL,
          database: 'db',
        );
        final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
          ..draftRecovery = false
          ..backend = backend
          ..profiles.add(profile)
          ..newDocument(text: 'SELECT preserved');
        model.explorerSessions[profile.id] = 'metadata';
        model.sessions['metadata'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'metadata',
          profile: profile,
          currentCatalog: 'db',
          currentSchema: 'public',
        );
        if (inFolder) {
          await model.createSourceFolderPath('Lab', '');
          await model.moveSourceToFolder(
            profile.id,
            model.sourceFolders.keys.single,
          );
        }
        final oldReply = Completer<rpc.SchemaObjects>();
        var fullLoads = 0;
        rpc.SchemaObjects table(String name) => rpc.SchemaObjects(
          complete: true,
          totalCount: Int64.ONE,
          countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
          objects: [rpc.SchemaObject(kind: rpc.ObjectKind.TABLE, name: name)],
        );
        backend.client.metadataAction = (request) async =>
            switch (request.kind) {
              rpc.ObjectKind.CATALOG => rpc.SchemaObjects(
                complete: true,
                objects: [rpc.SchemaObject(kind: request.kind, name: 'db')],
              ),
              rpc.ObjectKind.SCHEMA => rpc.SchemaObjects(
                complete: true,
                objects: [rpc.SchemaObject(kind: request.kind, name: 'public')],
              ),
              rpc.ObjectKind.TABLE when request.limit == 1 => table('fresh'),
              rpc.ObjectKind.TABLE =>
                ++fullLoads == 1 ? oldReply.future : table('fresh'),
              _ => rpc.SchemaObjects(complete: true),
            };
        addTearDown(() async {
          if (!oldReply.isCompleted) oldReply.complete(table('late_old'));
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DatabaseExplorer(
                model: metadataFixture(model),
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        if (inFolder) {
          await tester.tap(find.bySemanticsLabel('Expand Lab'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.bySemanticsLabel('Expand Source'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Expand public'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Expand Tables'));
        await tester.pump();
        expect(fullLoads, 1);
        final parent = inFolder ? 'Lab' : 'Source';
        await tester.tap(find.bySemanticsLabel('Collapse $parent'));
        await tester.pumpAndSettle();
        expect(backend.client.cancelledMetadataRequests, greaterThan(0));
        await tester.tap(find.bySemanticsLabel('Expand $parent'));
        await tester.pumpAndSettle();
        expect(fullLoads, 2);
        expect(find.text('fresh'), findsOneWidget);
        oldReply.complete(table('late_old'));
        await tester.pumpAndSettle();
        expect(find.text('late_old'), findsNothing);
        expect(find.text('fresh'), findsOneWidget);
        expect(model.document.editor.text, 'SELECT preserved');
        expect(backend.client.opened, isEmpty);
        expect(backend.client.executions, isEmpty);
        semantics.dispose();
      },
    );
  }
}
