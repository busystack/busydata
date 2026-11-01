import 'dart:io';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  for (final layout in [(280.0, 1.0), (280.0, 2.0), (220.0, 2.0)]) {
    testWidgets(
      'Database labels fit width ${layout.$1} at scale ${layout.$2}',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('explorer-density-'),
        ))!;
        final backend = TestBackend();
        final profile = rpc.Profile(
          id: 'p',
          name: 'Source',
          engine: rpc.Engine.POSTGRESQL,
          database: 'db1',
        );
        final model = metadataFixture(
          WorkbenchModel(directory, presentationWrite: (_, _) async {})
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(profile)
            ..newDocument(),
        );
        model.explorerSessions['p'] = 'metadata';
        model.sessions['metadata'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'metadata',
          profile: profile,
          currentCatalog: 'db1',
          currentSchema: 'public',
        );
        backend.client.metadataAction = (r) async => rpc.SchemaObjects(
          complete: true,
          availability: 'available',
          defaultNamespace: r.kind == rpc.ObjectKind.CATALOG ? 'db1' : 'public',
          objects: switch (r.kind) {
            rpc.ObjectKind.CATALOG => [
              for (final name in ['db1', 'db2', 'db3', 'db4'])
                rpc.SchemaObject(kind: r.kind, name: name),
            ],
            rpc.ObjectKind.SCHEMA => [
              for (final name in [
                'public',
                'audit',
                'analytics',
                'pg_catalog',
                'information_schema',
              ])
                rpc.SchemaObject(kind: r.kind, name: name),
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
            theme: BusyDataYaruTheme.build(
              brightness: Brightness.light,
              accentColor: Colors.orange,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(layout.$2)),
              child: child!,
            ),
            home: Scaffold(
              body: SizedBox(
                width: layout.$1,
                child: DatabaseExplorer(
                  model: model,
                  controls: const LinuxControls(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final name in ['Source', 'db1']) {
          final expand = find.bySemanticsLabel('Expand $name');
          if (expand.evaluate().isNotEmpty) {
            await tester.tap(expand);
            await tester.pumpAndSettle();
          }
        }
        for (final label in ['New', '1 of 4', '1 of 5']) {
          final text = find.text(label);
          expect(text, findsOneWidget);
          expect(
            tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
            isFalse,
            reason:
                '$label must remain readable at the chosen native text scale',
          );
        }
        expect(tester.takeException(), isNull);
        expect(backend.client.executions, isEmpty);
        semantics.dispose();
      },
    );
  }
}
