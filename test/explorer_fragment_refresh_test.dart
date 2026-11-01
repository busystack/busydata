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
  for (final kind in [
    rpc.ObjectKind.SEQUENCE,
    rpc.ObjectKind.ROUTINE,
    rpc.ObjectKind.COLUMN,
  ]) {
    testWidgets(
      '$kind refresh updates its real parent group and exact related definitions',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('fragment-refresh-'),
        ))!;
        final backend = TestBackend();
        final profile = rpc.Profile(
          id: 'p',
          name: 'Source',
          engine: rpc.Engine.POSTGRESQL,
          database: 'db',
        );
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
          currentSchema: 'public',
        );
        final name = kind == rpc.ObjectKind.SEQUENCE
            ? 'sequence_target'
            : kind == rpc.ObjectKind.ROUTINE
            ? 'routine_target'
            : 'id';
        final label = kind == rpc.ObjectKind.ROUTINE ? '$name(integer)' : name;
        final added = kind == rpc.ObjectKind.ROUTINE
            ? 'added_routine()'
            : 'added_object';
        final parent = kind == rpc.ObjectKind.COLUMN ? 'customers' : '';
        final subtype = kind == rpc.ObjectKind.ROUTINE
            ? rpc.ObjectSubtype.FUNCTION
            : kind == rpc.ObjectKind.SEQUENCE
            ? rpc.ObjectSubtype.NATIVE_SEQUENCE
            : rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED;
        DatabaseObjectIdentity identity({
          String catalog = 'db',
          rpc.ObjectKind? asKind,
          String? nativeName,
          String? identifier,
          String? table,
        }) => DatabaseObjectIdentity(
          profileId: 'p',
          catalog: catalog,
          schema: 'public',
          kind: asKind ?? kind,
          name: nativeName ?? name,
          subtype: asKind == null
              ? subtype
              : rpc.ObjectSubtype.OBJECT_SUBTYPE_UNSPECIFIED,
          parent: table ?? parent,
          identifier:
              identifier ?? (kind == rpc.ObjectKind.ROUTINE ? label : ''),
        );
        WorkbenchDocument definition(
          String title,
          DatabaseObjectIdentity object,
        ) => model.openTask(
          WorkbenchDocumentKind.structure,
          title,
          object: object,
          purpose: 'definition',
          evidenceProfile: profile,
          activate: false,
        );
        final selected = definition('Selected definition', identity());
        final otherDatabase = definition(
          'Other database',
          identity(catalog: 'other'),
        );
        final sibling = definition(
          'Unrelated definition',
          kind == rpc.ObjectKind.ROUTINE
              ? identity(identifier: '$name(text)')
              : kind == rpc.ObjectKind.COLUMN
              ? identity(
                  asKind: rpc.ObjectKind.TABLE,
                  nativeName: 'invoices',
                  identifier: '',
                  table: '',
                )
              : identity(
                  asKind: rpc.ObjectKind.ROUTINE,
                  identifier: '$name()',
                  table: '',
                ),
        );
        final related = kind == rpc.ObjectKind.COLUMN
            ? definition(
                'Parent table',
                identity(
                  asKind: rpc.ObjectKind.TABLE,
                  nativeName: 'customers',
                  identifier: '',
                  table: '',
                ),
              )
            : null;
        final sameNameOtherKind = kind == rpc.ObjectKind.ROUTINE
            ? definition(
                'Same named relation',
                identity(
                  asKind: rpc.ObjectKind.TABLE,
                  identifier: '',
                  table: '',
                ),
              )
            : null;
        var refreshed = false;
        var removed = false;
        backend.client.metadataAction = (r) async {
          if (r.refresh) refreshed = true;
          final response = rpc.SchemaObjects(
            complete: true,
            availability: 'available',
            objects: switch (r.kind) {
              rpc.ObjectKind.CATALOG => [
                rpc.SchemaObject(kind: r.kind, name: 'db'),
              ],
              rpc.ObjectKind.SCHEMA => [
                rpc.SchemaObject(kind: r.kind, name: 'public'),
              ],
              rpc.ObjectKind.TABLE when kind == rpc.ObjectKind.COLUMN => [
                rpc.SchemaObject(
                  kind: r.kind,
                  name: 'customers',
                  subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
                ),
              ],
              _ when r.kind == kind => [
                if (!removed)
                  rpc.SchemaObject(
                    kind: kind,
                    name: name,
                    identifier: kind == rpc.ObjectKind.ROUTINE ? label : '',
                    subtype: subtype,
                  ),
                if (kind == rpc.ObjectKind.ROUTINE)
                  rpc.SchemaObject(
                    kind: kind,
                    name: name,
                    identifier: '$name(text)',
                    subtype: subtype,
                  ),
                if (refreshed)
                  rpc.SchemaObject(
                    kind: kind,
                    name: kind == rpc.ObjectKind.ROUTINE
                        ? 'added_routine'
                        : added,
                    identifier: kind == rpc.ObjectKind.ROUTINE ? added : '',
                    subtype: subtype,
                  ),
              ],
              _ => [],
            },
          );
          if (r.exactName) {
            response.objects.removeWhere(
              (o) =>
                  o.name != r.search ||
                  r.identifier.isNotEmpty && o.identifier != r.identifier,
            );
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
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        );
        for (final node in [
          'Source',
          'public',
          if (kind == rpc.ObjectKind.COLUMN) ...['Tables', 'customers'],
          kind == rpc.ObjectKind.SEQUENCE
              ? 'Sequences'
              : kind == rpc.ObjectKind.ROUTINE
              ? 'Routines'
              : 'Columns',
        ]) {
          await tester.tap(find.bySemanticsLabel('Expand $node'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(model.explorerCommandContext?.object?.kind, kind);
        await tester.tap(find.byTooltip('Refresh'));
        await tester.pumpAndSettle();
        expect(find.text(added), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(selected.view.metadataRevision, 1);
        expect(otherDatabase.view.metadataRevision, 0);
        expect(sibling.view.metadataRevision, 0);
        if (related != null) {
          expect(related.view.metadataRevision, 1);
        }
        if (sameNameOtherKind != null) {
          expect(sameNameOtherKind.view.metadataRevision, 0);
        }
        final requests = backend.client.metadataRequests
            .where((r) => r.refresh)
            .toList();
        expect(requests, hasLength(1));
        expect(requests.single.kind, kind);
        expect(requests.single.catalog, 'db');
        expect(requests.single.schema, 'public');
        expect(requests.single.table, parent);
        // A complete refreshed enumeration proves the selected object was
        // dropped. Keep the other objects visible instead of replacing the
        // whole group with an empty exact-name lookup window.
        removed = true;
        final beforeRemoval = backend.client.metadataRequests.length;
        await tester.tap(find.byTooltip('Refresh'));
        await tester.pumpAndSettle();
        expect(find.text(label), findsNothing);
        expect(find.text(added), findsOneWidget);
        expect(
          backend.client.metadataRequests
              .skip(beforeRemoval)
              .where((r) => r.exactName),
          isEmpty,
        );
        expect(model.explorerCommandContext?.object, isNull);
        expect(model.explorerCommandContext?.creationScope?.catalog, 'db');
        expect(selected.view.metadataRevision, 2);
        expect(otherDatabase.view.metadataRevision, 0);
        expect(sibling.view.metadataRevision, 0);
        expect(backend.client.opened, isEmpty);
        expect(backend.client.executions, isEmpty);
        expect(model.document.editor.text, 'SELECT preserved');
        semantics.dispose();
      },
    );
  }
}
