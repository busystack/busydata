import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  for (final engine in [
    rpc.Engine.POSTGRESQL,
    rpc.Engine.MYSQL,
    rpc.Engine.MARIADB,
  ]) {
    testWidgets(
      '$engine separates real functions and procedures without duplicating namespaces',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('routine-groups-'),
        ))!;
        final backend = TestBackend();
        final profile = rpc.Profile(
          id: 'p',
          name: 'Source',
          engine: engine,
          database: 'db',
        );
        final schema = engine == rpc.Engine.POSTGRESQL ? 'public' : 'db';
        final model = metadataFixture(
          WorkbenchModel(root, presentationWrite: (_, _) async {})
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
          currentCatalog: 'db',
          currentSchema: schema,
        );
        backend.client.metadataAction = (r) async => rpc.SchemaObjects(
          complete: true,
          availability: 'available',
          objects: switch (r.kind) {
            rpc.ObjectKind.CATALOG => [
              rpc.SchemaObject(kind: r.kind, name: 'db'),
            ],
            rpc.ObjectKind.SCHEMA => [
              rpc.SchemaObject(kind: r.kind, name: 'public'),
            ],
            rpc.ObjectKind.ROUTINE => [
              for (final subtype in [
                rpc.ObjectSubtype.FUNCTION,
                rpc.ObjectSubtype.PROCEDURE,
              ])
                if (r.subtype == subtype ||
                    r.subtype == rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED)
                  rpc.SchemaObject(
                    kind: r.kind,
                    name: subtype == rpc.ObjectSubtype.FUNCTION ? 'f' : 'p',
                    identifier: engine == rpc.Engine.POSTGRESQL
                        ? (subtype == rpc.ObjectSubtype.FUNCTION
                              ? 'f()'
                              : 'p()')
                        : (subtype == rpc.ObjectSubtype.FUNCTION
                              ? 'FUNCTION:f'
                              : 'PROCEDURE:p'),
                    subtype: subtype,
                  ),
            ],
            _ => [],
          },
        );
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
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final name in [
          'Source',
          'db',
          if (engine == rpc.Engine.POSTGRESQL) 'public',
        ]) {
          final expand = find.bySemanticsLabel('Expand $name');
          if (expand.evaluate().isNotEmpty) {
            await tester.tap(expand);
            await tester.pumpAndSettle();
          }
        }
        expect(find.text('Routines'), findsOneWidget);
        if (find.byTooltip('View options').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('View options'));
        } else {
          await tester.tap(find.byTooltip('More').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('View options'));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text('Separate procedures and functions'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(find.text('Functions'), findsOneWidget);
        expect(find.text('Procedures'), findsOneWidget);
        expect(find.text('Routines'), findsNothing);
        for (final name in ['Functions', 'Procedures']) {
          await tester.tap(find.bySemanticsLabel('Expand $name'));
          await tester.pumpAndSettle();
        }
        expect(
          find.text(engine == rpc.Engine.POSTGRESQL ? 'f()' : 'f'),
          findsOneWidget,
        );
        expect(
          find.text(engine == rpc.Engine.POSTGRESQL ? 'p()' : 'p'),
          findsOneWidget,
        );
        await tester.tap(
          find.text(engine == rpc.Engine.POSTGRESQL ? 'f()' : 'f'),
        );
        await tester.pumpAndSettle();
        expect(
          model.explorerCommandContext?.object?.identifier,
          engine == rpc.Engine.POSTGRESQL ? 'f()' : 'FUNCTION:f',
        );
        expect(
          model.explorerCommandContext?.object?.displayPath(engine),
          engine == rpc.Engine.POSTGRESQL ? 'db / public / f()' : 'db / f',
        );
        expect(
          backend.client.metadataRequests
              .where((r) => r.kind == rpc.ObjectKind.ROUTINE)
              .map((r) => r.subtype)
              .toSet(),
          containsAll([
            rpc.ObjectSubtype.FUNCTION,
            rpc.ObjectSubtype.PROCEDURE,
          ]),
        );
        if (engine != rpc.Engine.POSTGRESQL) {
          expect(
            backend.client.metadataRequests.where(
              (r) => r.kind == rpc.ObjectKind.SCHEMA,
            ),
            isEmpty,
          );
        }
        expect(backend.client.opened, isEmpty);
        expect(backend.client.executions, isEmpty);
        expect(model.document.editor.text, 'SELECT preserved');
        semantics.dispose();
      },
    );
  }
}
