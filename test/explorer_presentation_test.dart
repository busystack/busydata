import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  for (final wrongSubtype in [false, true]) {
    testWidgets(
      'routine groups carry native scope and reject mismatched subtype: $wrongSubtype',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('tree-presentation-'),
        ))!;
        final backend = TestBackend();
        final profile = rpc.Profile(
          id: 'source',
          name: 'Source',
          engine: rpc.Engine.POSTGRESQL,
        );
        final model =
            WorkbenchModel(directory, presentationWrite: (_, _) async {})
              ..backend = backend
              ..draftRecovery = false
              ..profiles.add(profile)
              ..newDocument();
        model.explorerPreferences['separateRoutines'] = true;
        model.explorerPreferences['tableGroups'] = false;
        model.explorerSessions['source'] = 'metadata';
        model.sessions['metadata'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'metadata',
          profile: profile,
          currentCatalog: 'busydata',
          currentSchema: 'public',
        );
        var metadataRevision = 5;
        backend.client.metadataAction = (request) async => rpc.SchemaObjects(
          sessionRevision: Int64(metadataRevision),
          complete: true,
          objects: switch (request.kind) {
            rpc.ObjectKind.SCHEMA => [
              rpc.SchemaObject(kind: request.kind, name: 'public'),
            ],
            rpc.ObjectKind.TABLE => [
              rpc.SchemaObject(
                kind: request.kind,
                name: 'customers',
                subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
              ),
            ],
            rpc.ObjectKind.COLUMN => [
              rpc.SchemaObject(kind: request.kind, name: 'id'),
            ],
            rpc.ObjectKind.INDEX => [
              rpc.SchemaObject(kind: request.kind, name: 'customers_pk'),
            ],
            rpc.ObjectKind.ROUTINE => [
              rpc.SchemaObject(
                kind: request.kind,
                name: request.subtype == rpc.ObjectSubtype.PROCEDURE
                    ? 'write_customer'
                    : 'read_customer',
                subtype: wrongSubtype
                    ? rpc.ObjectSubtype.PROCEDURE
                    : request.subtype,
                identifier: request.subtype == rpc.ObjectSubtype.PROCEDURE
                    ? 'write_customer(integer)'
                    : 'read_customer(integer)',
              ),
            ],
            _ => [],
          },
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => directory.delete(recursive: true));
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
        await tester.tap(find.bySemanticsLabel('Expand Source'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Expand public'));
        await tester.pumpAndSettle();
        expect(find.text('Functions'), findsOneWidget);
        expect(find.text('Procedures'), findsOneWidget);
        expect(find.text('Routines'), findsNothing);
        await tester.tap(find.bySemanticsLabel('Expand Functions'));
        await tester.pumpAndSettle();
        expect(
          find.text('read_customer(integer)'),
          wrongSubtype ? findsNothing : findsOneWidget,
        );
        if (!wrongSubtype) {
          await tester.tap(find.text('Functions'));
          await tester.pumpAndSettle();
          expect(
            model
                .explorerCommandContext!
                .metadataSources['source']!
                .sessionRevision,
            5,
          );
          metadataRevision = 7;
          await tester.tap(find.byTooltip('Refresh'));
          await tester.pumpAndSettle();
          expect(
            model
                .explorerCommandContext!
                .metadataSources['source']!
                .sessionRevision,
            7,
          );
          expect(
            model.explorerCommandContext!.creationScope!.catalog,
            'busydata',
          );
        }
        expect(
          backend.client.metadataRequests
              .where((r) => r.kind == rpc.ObjectKind.ROUTINE)
              .every(
                (r) =>
                    r.catalog == 'busydata' &&
                    r.schema == 'public' &&
                    r.subtype != rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
              ),
          isTrue,
        );
        await tester.tap(find.bySemanticsLabel('Expand Tables'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Expand customers'));
        await tester.pumpAndSettle();
        expect(find.text('id'), findsOneWidget);
        expect(find.text('Columns'), findsNothing);
        expect(find.text('Indexes'), findsNothing);
        expect(find.text('customers_pk'), findsNothing);
        expect(backend.client.executions, isEmpty);
        semantics.dispose();
      },
    );
  }
}
