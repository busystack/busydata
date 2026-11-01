import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  for (final engine in [
    rpc.Engine.POSTGRESQL,
    rpc.Engine.MYSQL,
    rpc.Engine.MARIADB,
  ]) {
    testWidgets('$engine namespace tools capture the selected schema scope', (
      tester,
    ) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('namespace-tools-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(id: 'p', name: 'Source', engine: engine);
      final schema = engine == rpc.Engine.POSTGRESQL ? 'public' : 'selected_db';
      final model = metadataFixture(
        WorkbenchModel(directory, presentationWrite: (_, _) async {})
          ..backend = backend
          ..draftRecovery = false
          ..profiles.add(profile)
          ..newDocument(text: 'SELECT preserved'),
      );
      model.explorerSessions['p'] = 'metadata';
      model.sessions['metadata'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'metadata',
        profile: profile,
        currentCatalog: 'selected_db',
        currentSchema: schema,
      );
      backend.client.metadataAction = (r) async => rpc.SchemaObjects(
        complete: true,
        availability: 'available',
        objects: switch (r.kind) {
          rpc.ObjectKind.CATALOG => [
            rpc.SchemaObject(kind: r.kind, name: 'selected_db'),
          ],
          rpc.ObjectKind.SCHEMA => [
            rpc.SchemaObject(kind: r.kind, name: 'public'),
          ],
          _ => [],
        },
      );
      WorkbenchCommandContext? captured;
      model.commands = WorkbenchCommandRegistry([
        for (final id in [
          'schema.snapshot',
          'schema.compare',
          'schema.diagram',
        ])
          WorkbenchCommand(
            id: id,
            label: id,
            category: 'Object',
            invoke: (target) => captured = target,
          ),
      ]);
      const menuChannel = MethodChannel('busydata/native_menus');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        menuChannel,
        (_) async => throw MissingPluginException(),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        messenger.setMockMethodCallHandler(menuChannel, null);
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      final semantics = tester.ensureSemantics();
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
      for (final name in ['Source', 'selected_db']) {
        final expand = find.bySemanticsLabel('Expand $name');
        if (expand.evaluate().isNotEmpty) {
          await tester.tap(expand);
          await tester.pumpAndSettle();
        }
      }
      final namespace = find.text(schema);
      for (final id in [
        'schema.snapshot',
        'schema.compare',
        'schema.diagram',
      ]) {
        await tester.tap(namespace);
        await tester.pumpAndSettle();
        expect(model.explorerCommandContext?.creationScope?.schema, schema);
        expect(model.commands?.commands.map((c) => c.id), contains(id));
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        expect(find.text(id), findsOneWidget);
        await tester.tap(find.text(id));
        await tester.pumpAndSettle();
        expect(captured?.profileId, 'p');
        expect(captured?.sessionId, 'metadata');
        expect(captured?.creationScope?.catalog, 'selected_db');
        expect(captured?.creationScope?.schema, schema);
        expect(captured?.object?.name, schema);
        expect(captured?.owner, isNull);
      }
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT preserved');
      semantics.dispose();
    });
  }
}
