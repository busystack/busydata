import 'dart:io';
import 'dart:async';
import 'dart:ui' show Tristate;
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/native_window.dart';

void main() {
  testWidgets(
    'namespace Apply renews retained expanded branch continuations before paging',
    (tester) async {
      installNativeWindowFixture(tester);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('namespace-page-revision-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
      );
      final model =
          WorkbenchModel(directory, presentationWrite: (_, _) async {})
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(profile)
            ..newDocument(text: 'SELECT retained');
      model.explorerSessions['p'] = 'inspection';
      model.sessions['inspection'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'first',
        currentSchema: 'public',
      );
      await model.selectNamespaces(
        'p',
        '',
        NamespaceSelection(names: ['first']),
      );
      var staleRequests = 0;
      backend.client.metadataAction = (request) async {
        if (request.kind == rpc.ObjectKind.TABLE) {
          final revision = request.expectedSessionRevision.toString();
          if (request.continuation.isNotEmpty &&
              !request.continuation.startsWith('$revision/')) {
            staleRequests++;
            throw GrpcError.failedPrecondition('Previous metadata revision');
          }
          final start = request.continuation.isEmpty
              ? 0
              : int.parse(request.continuation.split('/').last);
          final end = (start + request.limit).clamp(0, 130);
          return rpc.SchemaObjects(
            availability: 'available',
            complete: end == 130,
            continuation: end == 130 ? '' : '$revision/$end',
            totalCount: Int64(130),
            countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
            objects: [
              for (var i = start; i < end; i++)
                rpc.SchemaObject(
                  kind: request.kind,
                  name: 't${i.toString().padLeft(3, '0')}',
                ),
            ],
          );
        }
        return rpc.SchemaObjects(
          complete: true,
          defaultNamespace: request.kind == rpc.ObjectKind.CATALOG
              ? 'first'
              : 'public',
          objects: [
            for (final name in switch (request.kind) {
              rpc.ObjectKind.CATALOG => ['first', 'second'],
              rpc.ObjectKind.SCHEMA => ['public'],
              _ => <String>[],
            })
              rpc.SchemaObject(kind: request.kind, name: name),
          ],
        );
      };
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
      for (final name in ['Source', 'public', 'Tables']) {
        await tester.tap(find.bySemanticsLabel('Expand $name'));
        await tester.pumpAndSettle();
      }
      expect(find.text('t000'), findsOneWidget);
      await tester.tap(find.text('1 of 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('second').last);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(model.sessions['inspection']!.sessionRevision, Int64.ONE);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(staleRequests, 0);
      expect(find.text('t129'), findsOneWidget);
      expect(model.document.editor.text, 'SELECT retained');
      expect(model.sessions['inspection']!.currentCatalog, 'first');
      expect(backend.client.executions, isEmpty);
      semantics.dispose();
    },
  );
  for (final failure in [
    'permission',
    'removed',
    'stale continuation',
    'disconnect',
    'profile',
  ]) {
    testWidgets(
      'namespace pending $failure retains the accepted rule and unrelated query',
      (tester) async {
        installNativeWindowFixture(tester);
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('namespace-failure-'),
        ))!;
        final backend = TestBackend();
        final profile = rpc.Profile(
          id: 'p',
          name: 'Source',
          host: 'original',
          engine: rpc.Engine.POSTGRESQL,
        );
        final model =
            WorkbenchModel(directory, presentationWrite: (_, _) async {})
              ..backend = backend
              ..draftRecovery = false
              ..profiles.add(profile)
              ..newDocument(text: 'SELECT retained');
        model.document
          ..profileId = 'p'
          ..sessionId = 'query'
          ..connectionCatalog = 'other_database'
          ..connectionSchema = 'audit';
        model.sessions['query'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'query',
          profile: profile.deepCopy(),
          currentCatalog: 'other_database',
          currentSchema: 'audit',
          transaction: rpc.TransactionState.ACTIVE,
        );
        model.explorerSessions['p'] = 'inspection';
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: profile.deepCopy(),
          currentCatalog: 'db',
          currentSchema: 's159',
        );
        await model.selectNamespaces(
          'p',
          '',
          NamespaceSelection(names: ['db']),
        );
        await model.selectNamespaces(
          'p',
          'db',
          NamespaceSelection(names: ['s159']),
        );
        var applying = false;
        final late = Completer<rpc.SchemaObjects>();
        backend.client.metadataAction = (r) async {
          if (applying && r.exactName && r.search == 's000') {
            if (failure == 'permission') {
              throw GrpcError.permissionDenied('Fixture metadata permission');
            }
            if (failure == 'removed') return rpc.SchemaObjects(complete: true);
            if (failure == 'stale continuation') {
              throw GrpcError.failedPrecondition(
                'Fixture continuation changed',
              );
            }
            return late.future;
          }
          return rpc.SchemaObjects(
            complete: true,
            defaultNamespace: r.kind == rpc.ObjectKind.CATALOG ? 'db' : 's159',
            objects: r.kind == rpc.ObjectKind.CATALOG
                ? [rpc.SchemaObject(kind: r.kind, name: 'db')]
                : [
                    for (var i = 0; i < 160; i++)
                      rpc.SchemaObject(
                        kind: r.kind,
                        name: 's${i.toString().padLeft(3, '0')}',
                      ),
                  ],
          );
        };
        metadataFixture(model);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => directory.delete(recursive: true));
        });
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                child: DatabaseExplorer(
                  model: model,
                  controls: const LinuxControls(),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.bySemanticsLabel('Expand Source'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('1 of 160'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('s000').last);
        applying = true;
        await tester.tap(find.text('Apply'));
        await tester.pump();
        if (failure == 'disconnect' || failure == 'profile') {
          if (failure == 'disconnect') {
            model.explorerSessions.remove('p');
          } else {
            profile.host = 'replacement';
          }
          model.updateStatus('Fixture source changed');
          late.complete(
            rpc.SchemaObjects(
              complete: true,
              objects: [
                rpc.SchemaObject(kind: rpc.ObjectKind.SCHEMA, name: 's000'),
              ],
            ),
          );
        }
        await tester.pumpAndSettle();
        expect(model.namespaceSelection('p', 'db')!.names, {'s159'});
        expect(model.document.sessionId, 'query');
        expect(model.document.connectionCatalog, 'other_database');
        expect(
          model.sessions['query']!.transaction,
          rpc.TransactionState.ACTIVE,
        );
        expect(model.sessions['query']!.profile.host, 'original');
        expect(model.document.editor.text, 'SELECT retained');
        expect(backend.client.opened, isEmpty);
        expect(backend.client.executions, isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        semantics.dispose();
      },
    );
  }
  for (final kind in [rpc.ObjectKind.COLUMN, rpc.ObjectKind.INDEX]) {
    for (final outcome in ['found', 'missing', 'denied', 'hidden', 'changed']) {
      testWidgets(
        'reveal view child through its actual relation: $kind $outcome',
        (tester) async {
          final directory = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('view-child-reveal-'),
          ))!;
          final backend = TestBackend();
          final profile = rpc.Profile(
            id: 'p',
            name: 'Source',
            engine: rpc.Engine.POSTGRESQL,
          );
          final model =
              WorkbenchModel(directory, presentationWrite: (_, _) async {})
                ..backend = backend
                ..draftRecovery = false
                ..profiles.add(profile)
                ..newDocument(text: 'SELECT unchanged');
          model.explorerSessions['p'] = 'inspection';
          model.sessions['inspection'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'inspection',
            profile: profile,
            currentCatalog: 'first',
            currentSchema: 'public',
          );
          await model.selectNamespaces(
            'p',
            '',
            NamespaceSelection(names: ['second']),
          );
          await model.selectNamespaces(
            'p',
            'second',
            NamespaceSelection(names: ['audit']),
          );
          final parentGate = Completer<rpc.SchemaObjects>();
          if (outcome == 'hidden') model.explorerObjectKinds.remove(kind);
          backend.client.metadataAction = (r) async {
            if (r.kind == rpc.ObjectKind.VIEW && r.exactName) {
              if (outcome == 'missing') {
                return rpc.SchemaObjects(complete: true);
              }
              if (outcome == 'denied') {
                throw GrpcError.permissionDenied(
                  'Fixture parent is not accessible',
                );
              }
              if (outcome == 'changed') return parentGate.future;
            }
            return rpc.SchemaObjects(
              complete: true,
              objects: switch (r.kind) {
                rpc.ObjectKind.CATALOG => [
                  rpc.SchemaObject(
                    kind: r.kind,
                    name: 'second',
                    catalog: 'second',
                  ),
                ],
                rpc.ObjectKind.SCHEMA => [
                  rpc.SchemaObject(kind: r.kind, name: 'audit'),
                ],
                rpc.ObjectKind.VIEW => [
                  rpc.SchemaObject(
                    kind: r.kind,
                    name: 'relation',
                    subtype: kind == rpc.ObjectKind.INDEX
                        ? rpc.ObjectSubtype.MATERIALIZED_VIEW
                        : rpc.ObjectSubtype.REGULAR_VIEW,
                  ),
                ],
                rpc.ObjectKind.COLUMN || rpc.ObjectKind.INDEX => [
                  if (r.kind == kind)
                    rpc.SchemaObject(kind: kind, name: 'later_child'),
                ],
                _ => [],
              },
            );
          };
          metadataFixture(model);
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
                  model: model,
                  controls: const LinuxControls(),
                ),
              ),
            ),
          );
          model.revealInExplorer(
            DatabaseObjectIdentity(
              profileId: 'p',
              catalog: 'second',
              schema: 'audit',
              kind: kind,
              name: 'later_child',
              parent: 'relation',
            ),
          );
          await tester.pumpAndSettle();
          if (outcome == 'changed') {
            expect(
              backend.client.metadataRequests.any(
                (r) => r.kind == rpc.ObjectKind.VIEW && r.exactName,
              ),
              isTrue,
            );
            model.sessions['inspection']!.contextRevision = Int64.ONE;
            model.updateStatus('Fixture context changed');
            parentGate.complete(
              rpc.SchemaObjects(
                complete: true,
                objects: [
                  rpc.SchemaObject(kind: rpc.ObjectKind.VIEW, name: 'relation'),
                ],
              ),
            );
            await tester.pumpAndSettle();
          }
          final row = find.bySemanticsLabel(
            RegExp(r'^later_child · level.*second / audit / relation'),
          );
          if (outcome == 'found') {
            expect(row, findsOneWidget);
            expect(
              tester.getSemantics(row).flagsCollection.isSelected,
              Tristate.isTrue,
            );
            expect(find.bySemanticsLabel('Collapse Views'), findsOneWidget);
          } else {
            expect(row, findsNothing);
            expect(
              model.status.toLowerCase(),
              contains(switch (outcome) {
                'denied' => 'access',
                'hidden' => 'hidden',
                'changed' => 'context',
                _ => 'not found',
              }),
            );
          }
          expect(backend.client.executions, isEmpty);
          expect(model.sessions['inspection']!.currentCatalog, 'first');
          semantics.dispose();
        },
      );
    }
  }
  for (final scenario in [
    'all-first',
    'all-later',
    'all-budget',
    'explicit-hidden',
    'explicit-visible',
  ]) {
    final all = scenario.startsWith('all');
    testWidgets('namespace edits survive replacement pages: $scenario', (
      tester,
    ) async {
      installNativeWindowFixture(tester);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('namespace-pending-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
      );
      final model =
          WorkbenchModel(directory, presentationWrite: (_, _) async {})
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(profile)
            ..newDocument(text: 'SELECT unchanged');
      model.showAllNamespaces = scenario == 'explicit-visible';
      model.explorerSessions['p'] = 'inspection';
      model.sessions['inspection'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'db',
        currentSchema: 's159',
      );
      await model.selectNamespaces('p', '', NamespaceSelection(names: ['db']));
      await model.selectNamespaces(
        'p',
        'db',
        NamespaceSelection(
          mode: all ? NamespaceSelectionMode.all : NamespaceSelectionMode.names,
          excluded: scenario == 'all-budget'
              ? List.generate(128, (i) => 's${i.toString().padLeft(3, '0')}')
              : [],
        ),
      );
      backend.client.metadataAction = (r) async => rpc.SchemaObjects(
        complete: true,
        defaultNamespace: r.kind == rpc.ObjectKind.SCHEMA ? 's159' : 'db',
        objects: switch (r.kind) {
          rpc.ObjectKind.CATALOG => [
            rpc.SchemaObject(kind: r.kind, name: 'db', catalog: 'db'),
          ],
          rpc.ObjectKind.SCHEMA => [
            for (var i = 0; i < 160; i++)
              if (!r.exactName ||
                  r.search == 's${i.toString().padLeft(3, '0')}')
                rpc.SchemaObject(
                  kind: r.kind,
                  name: 's${i.toString().padLeft(3, '0')}',
                ),
          ],
          _ => [],
        },
      );
      metadataFixture(model);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: DatabaseExplorer(
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Expand Source'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          scenario == 'all-budget'
              ? '32 of 160'
              : all
              ? '160 of 160'
              : '0 of 160',
        ),
      );
      await tester.pumpAndSettle();
      if (scenario == 'all-budget') {
        await tester.ensureVisible(find.text('Load more').last);
        await tester.tap(find.text('Load more').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('s129').last);
        await tester.tap(find.text('s129').last);
        await tester.pumpAndSettle();
        expect(find.text('Limit reached'), findsOneWidget);
        await tester.ensureVisible(find.text('Apply'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        final accepted = model.namespaceSelection('p', 'db')!;
        expect(accepted.excluded, hasLength(128));
        expect(accepted.excluded, isNot(contains('s129')));
        expect(backend.client.executions, isEmpty);
        semantics.dispose();
        return;
      }
      if (scenario != 'all-later') {
        await tester.tap(find.text('s000').last);
        await tester.pumpAndSettle();
      }
      if (scenario != 'all-first') {
        await tester.ensureVisible(find.text('Load more').last);
        await tester.tap(find.text('Load more').last);
        await tester.pumpAndSettle();
      }
      if (!all || scenario == 'all-later') {
        await tester.ensureVisible(find.text('s129').last);
        await tester.tap(find.text('s129').last);
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      final rule = model.namespaceSelection('p', 'db')!;
      if (all) {
        expect(rule.mode, NamespaceSelectionMode.all);
        expect(find.text('159 of 160'), findsOneWidget);
        expect(rule.excluded, {scenario == 'all-later' ? 's129' : 's000'});
        await tester.tap(find.text('Load more').last);
        await tester.pumpAndSettle();
        expect(
          find.bySemanticsLabel(
            RegExp(scenario == 'all-later' ? r'^s130 ·' : r'^s129 ·'),
          ),
          findsOneWidget,
        );
      } else {
        expect(rule.names, {'s000', 's129'});
        if (model.showAllNamespaces) {
          await tester.scrollUntilVisible(
            find.bySemanticsLabel(RegExp(r'^s000 ·')),
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(find.bySemanticsLabel(RegExp(r'^s000 ·')), findsOneWidget);
        if (model.showAllNamespaces) {
          await tester.scrollUntilVisible(
            find.bySemanticsLabel(RegExp(r'^s129 ·')),
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        expect(find.bySemanticsLabel(RegExp(r'^s129 ·')), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('2 of 160'),
          -500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('2 of 160'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('s000').last);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(model.namespaceSelection('p', 'db')!.names, {'s000', 's129'});
        await tester.tap(find.text('2 of 160'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Default'));
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
        expect(model.namespaceSelection('p', 'db')!.names, {'s159'});
      }
      expect(model.document.editor.text, 'SELECT unchanged');
      expect(backend.client.executions, isEmpty);
      semantics.dispose();
    });
  }
  for (final restoredSelection in [false, true]) {
    testWidgets(
      'connection discovers its default and retained selection beyond the first namespace page: $restoredSelection',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('default-page-'),
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
        model.explorerSessions[profile.id] = 'metadata';
        model.sessions['metadata'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'metadata',
          profile: profile,
          currentCatalog: 'z_default',
          currentSchema: 'public',
        );
        if (restoredSelection) {
          model.seedNamespaces(
            profile.id,
            '',
            NamespaceSelection(names: ['z_default', 'z_selected']),
          );
        }
        backend.client.metadataAction = (request) async =>
            request.kind == rpc.ObjectKind.CATALOG
            ? rpc.SchemaObjects(
                defaultNamespace: 'z_default',
                complete: request.exactName,
                continuation: request.exactName ? '' : 'next',
                countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
                totalCount: Int64(request.exactName ? 1 : 130),
                objects: request.exactName
                    ? [
                        rpc.SchemaObject(
                          kind: request.kind,
                          name: request.search,
                          catalog: request.search,
                        ),
                      ]
                    : [
                        for (var i = 0; i < request.limit; i++)
                          rpc.SchemaObject(
                            kind: request.kind,
                            name: 'a_$i',
                            catalog: 'a_$i',
                          ),
                      ],
              )
            : rpc.SchemaObjects(
                defaultNamespace: 'public',
                complete: true,
                objects: [rpc.SchemaObject(kind: request.kind, name: 'public')],
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
        expect(find.text('z_default'), findsOneWidget);
        expect(find.text('public'), findsNWidgets(restoredSelection ? 2 : 1));
        expect(
          find.text(restoredSelection ? '2 of 130' : '1 of 130'),
          findsOneWidget,
        );
        expect(
          find.text('z_selected'),
          restoredSelection ? findsOneWidget : findsNothing,
        );
        expect(
          backend.client.metadataRequests.where(
            (r) => r.exactName && r.search == 'z_default',
          ),
          hasLength(1),
        );
        expect(
          backend.client.metadataRequests
              .where((r) => r.kind == rpc.ObjectKind.SCHEMA)
              .every(
                (r) =>
                    r.catalog == 'z_default' ||
                    restoredSelection && r.catalog == 'z_selected',
              ),
          isTrue,
        );
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened, isEmpty);
        if (restoredSelection) {
          backend.client.metadataAction = (request) async => rpc.SchemaObjects(
            complete: true,
            defaultNamespace: request.kind == rpc.ObjectKind.CATALOG
                ? 'z_default'
                : 'public',
            objects: request.kind == rpc.ObjectKind.CATALOG
                ? [
                    rpc.SchemaObject(
                      kind: request.kind,
                      name: 'z_default',
                      catalog: 'z_default',
                    ),
                  ]
                : [rpc.SchemaObject(kind: request.kind, name: 'public')],
          );
          await tester.tap(find.text('Source'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Refresh'));
          await tester.pumpAndSettle();
          expect(find.text('2 of 1'), findsNothing);
          expect(find.text('z_selected'), findsNothing);
          expect(find.text('1 of 1'), findsAtLeastNWidgets(1));
        }
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'disconnected virtual views have real scoped nodes without acquiring metadata or sessions',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('offline-virtual-'),
      ))!;
      final backend = TestBackend();
      final model =
          WorkbenchModel(directory, presentationWrite: (_, _) async {})
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(rpc.Profile(id: 'source', name: 'Source'))
            ..newDocument();
      for (final catalog in ['first', 'second']) {
        await model.saveVirtualView(
          VirtualViewDefinition(
            id: catalog,
            name: 'Customers',
            scope: DatabaseCreationScope(
              profileId: 'source',
              catalog: catalog,
              schema: 'public',
            ),
            sql: 'SELECT * FROM public.customers',
          ),
        );
      }
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
              model: model,
              controls: const LinuxControls(),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Expand Source'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Expand Virtual views'));
      await tester.pumpAndSettle();
      expect(find.text('first / public / Customers'), findsOneWidget);
      expect(find.text('second / public / Customers'), findsOneWidget);
      expect(backend.client.metadataRequests, isEmpty);
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
      expect(model.sessions, isEmpty);
      semantics.dispose();
    },
  );
  for (final hidden in [false, true]) {
    testWidgets(
      'exact reveal targets the second database and respects namespace selection: hidden $hidden',
      (tester) async {
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('explorer-reveal-'),
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
              ..newDocument(text: 'SELECT untouched');
        model.explorerSessions[profile.id] = 'inspection';
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: profile,
          currentCatalog: 'first',
          currentSchema: 'public',
        );
        await model.selectNamespaces(
          profile.id,
          '',
          NamespaceSelection(names: hidden ? ['first'] : ['first', 'second']),
        );
        await model.selectNamespaces(
          profile.id,
          'second',
          NamespaceSelection(names: ['public']),
        );
        backend.client.metadataAction = (request) async => rpc.SchemaObjects(
          complete: true,
          objects: switch (request.kind) {
            rpc.ObjectKind.CATALOG => [
              for (final name in ['first', 'second'])
                rpc.SchemaObject(kind: request.kind, name: name, catalog: name),
            ],
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
        model.revealInExplorer(
          const DatabaseObjectIdentity(
            profileId: 'source',
            catalog: 'second',
            schema: 'public',
            kind: rpc.ObjectKind.TABLE,
            subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
            name: 'customers',
          ),
        );
        await tester.pumpAndSettle();
        if (hidden) {
          expect(model.status, contains('not selected'));
          expect(backend.client.metadataRequests, isEmpty);
        } else {
          final row = find.bySemanticsLabel(
            RegExp(r'^customers · level [0-9]+ · Source.*second / public'),
          );
          expect(row, findsOneWidget);
          expect(
            tester.getSemantics(row).flagsCollection.isSelected,
            Tristate.isTrue,
          );
          expect(
            backend.client.metadataRequests.where(
              (r) => r.kind == rpc.ObjectKind.TABLE && r.catalog == 'second',
            ),
            isNotEmpty,
          );
        }
        expect(model.document.editor.text, 'SELECT untouched');
        expect(model.document.sessionId, isNull);
        expect(model.sessions['inspection']!.currentCatalog, 'first');
        expect(
          model.namespaceSelection(profile.id, '')!.names.contains('second'),
          !hidden,
        );
        expect(backend.client.executions, isEmpty);
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'Speed Search keeps every character while paged column rows enter the viewport',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('speed-search-page-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
      );
      final model =
          WorkbenchModel(directory, presentationWrite: (_, _) async {})
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(profile);
      model.explorerSessions['p'] = 'inspection';
      model.sessions['inspection'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'db',
        currentSchema: 'public',
      );
      backend.client.metadataAction = (r) async => rpc.SchemaObjects(
        complete: true,
        objects: switch (r.kind) {
          rpc.ObjectKind.SCHEMA => [
            rpc.SchemaObject(kind: r.kind, name: 'public'),
          ],
          rpc.ObjectKind.TABLE => [
            rpc.SchemaObject(kind: r.kind, name: 'wide'),
          ],
          rpc.ObjectKind.COLUMN => [
            for (var i = 0; i < 160; i++)
              rpc.SchemaObject(
                kind: r.kind,
                name: 'c${i.toString().padLeft(3, '0')}',
                properties: [MapEntry('ordinal', '${i + 1}')],
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
            body: SizedBox(
              width: 400,
              height: 420,
              child: DatabaseExplorer(
                model: metadataFixture(model),
                controls: const LinuxControls(),
              ),
            ),
          ),
        ),
      );
      for (final name in ['Source', 'public', 'Tables', 'wide', 'Columns']) {
        await tester.ensureVisible(find.bySemanticsLabel('Expand $name'));
        await tester.tap(find.bySemanticsLabel('Expand $name'));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('Load more'));
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();
      final requests = backend.client.metadataRequests.length;
      for (final (key, character) in [
        (LogicalKeyboardKey.keyC, 'c'),
        (LogicalKeyboardKey.digit1, '1'),
        (LogicalKeyboardKey.digit5, '5'),
      ]) {
        await tester.sendKeyEvent(key, character: character);
        await tester.pump();
      }
      // The tree retains focus while virtualization replaces the matched row.
      // Do not depend on a platform frame's exact focus-attachment timing.
      await tester.pumpAndSettle();
      final previousFocus = tester.widget<FocusableActionDetector>(
        find.byWidgetPredicate(
          (widget) =>
              widget is FocusableActionDetector &&
              widget.focusNode?.debugLabel == 'c150',
        ),
      );
      model.explorerFocus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: '9');
      // A late native focus move must not take keyboard focus away from the
      // current search match.
      previousFocus.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(model.explorerCommandContext!.object!.name, 'c159');
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp(r'^c159 ·')))
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      expect(backend.client.metadataRequests.length, requests);
      expect(backend.client.executions, isEmpty);
      semantics.dispose();
    },
  );
  testWidgets(
    'Speed Search stays within expanded loaded nodes and cycles without metadata requests',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('speed-search-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
      );
      final model =
          WorkbenchModel(directory, presentationWrite: (_, bytes) async {})
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(profile)
            ..newDocument(text: 'SELECT 7;');
      model.explorerSessions['p'] = 'inspection';
      model.sessions['inspection'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'db',
        currentSchema: 'public',
      );
      backend.client.metadataAction = (request) async => rpc.SchemaObjects(
        complete: true,
        objects: switch (request.kind) {
          rpc.ObjectKind.SCHEMA => [
            rpc.SchemaObject(kind: request.kind, name: 'public'),
          ],
          rpc.ObjectKind.TABLE => [
            for (final name in ['apple', 'apricot'])
              rpc.SchemaObject(kind: request.kind, name: name),
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
      await tester.tap(find.text('Source'));
      await tester.pump();
      final before = backend.client.metadataRequests.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP, character: 'p');
      await tester.pumpAndSettle();
      expect(find.text('Expanded, loaded nodes only.'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^apple ·')), findsNothing);
      expect(backend.client.metadataRequests.length, before);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Expanded, loaded nodes only.'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Expand public'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Expand Tables'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tables'));
      await tester.pump();
      final loaded = backend.client.metadataRequests.length;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP, character: 'p');
      await tester.pumpAndSettle();
      expect(model.explorerCommandContext!.object!.name, 'apple');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(model.explorerCommandContext!.object!.name, 'apricot');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(model.explorerCommandContext!.object!.name, 'apple');
      expect(backend.client.metadataRequests.length, loaded);
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT 7;');
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
  testWidgets(
    'N of M selects a second physical database scope without changing a live query',
    (tester) async {
      const menuChannel = MethodChannel('busydata/native_menus');
      installNativeWindowFixture(tester);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        menuChannel,
        (_) async => throw MissingPluginException(),
      );
      addTearDown(() => messenger.setMockMethodCallHandler(menuChannel, null));
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('namespace-ui-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(
        id: 'source',
        name: 'Source',
        database: 'first',
        engine: rpc.Engine.POSTGRESQL,
      );
      final model =
          WorkbenchModel(directory, presentationWrite: (_, bytes) async {})
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(profile)
            ..newDocument(text: 'SELECT current_database();');
      final original = model.document;
      original.profileId = profile.id;
      original.connectionCatalog = 'first';
      original.connectionSchema = 'audit';
      original.sessionId = 'query';
      model.explorerSessions[profile.id] = 'inspection';
      model.sessions['inspection'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'first',
        currentSchema: 'public',
      );
      model.sessions['query'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'query',
        profile: profile,
        currentCatalog: 'first',
        currentSchema: 'audit',
        transaction: rpc.TransactionState.ACTIVE,
      );
      backend.client.metadataAction = (request) async {
        final objects = switch (request.kind) {
          rpc.ObjectKind.CATALOG => [
            for (final name in ['first', 'second'])
              rpc.SchemaObject(name: name, catalog: name, kind: request.kind),
          ],
          rpc.ObjectKind.SCHEMA => [
            for (final name in ['audit', 'public'])
              rpc.SchemaObject(
                name: name,
                catalog: request.catalog,
                schema: name,
                kind: request.kind,
              ),
          ],
          rpc.ObjectKind.TABLE => [
            rpc.SchemaObject(
              name: 'customers',
              catalog: request.catalog,
              schema: request.schema,
              kind: request.kind,
              subtype: rpc.ObjectSubtype.ORDINARY_TABLE,
            ),
          ],
          _ => <rpc.SchemaObject>[],
        };
        return rpc.SchemaObjects(
          objects: objects,
          complete: true,
          totalCount: Int64(objects.length),
          countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
        );
      };
      WorkbenchCommandContext? query;
      model.commands = WorkbenchCommandRegistry([
        WorkbenchCommand(
          id: 'file.new',
          label: 'New query',
          category: 'File',
          invoke: (context) => query = context,
        ),
      ]);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: DatabaseExplorer(
                model: metadataFixture(model),
                controls: const LinuxControls(),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Expand Source'));
      await tester.pumpAndSettle();
      expect(find.text('second'), findsNothing);
      await tester.tap(find.text('1 of 2').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Query consoles keep their execution context.'),
        findsOneWidget,
      );
      await tester.tap(find.text('second'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(model.namespaceSelection('source', '')!.names, {
        'first',
        'second',
      });
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.bySemanticsLabel('Collapse second'), findsOneWidget);
      final secondSchema = find.bySemanticsLabel(
        RegExp(r'^public · level.*second / public'),
      );
      await tester.tap(
        find.descendant(
          of: secondSchema,
          matching: find.bySemanticsLabel('Expand public'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tables'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New query'));
      await tester.pumpAndSettle();
      expect(query!.object, isNull);
      expect(
        query!.creationScope,
        const DatabaseCreationScope(
          profileId: 'source',
          catalog: 'second',
          schema: 'public',
        ),
      );
      expect(
        backend.client.metadataRequests
            .where(
              (r) => r.kind == rpc.ObjectKind.TABLE && r.catalog == 'second',
            )
            .single
            .schema,
        'public',
      );
      expect(original.connectionCatalog, 'first');
      expect(original.connectionSchema, 'audit');
      expect(original.sessionId, 'query');
      expect(model.sessions['query']!.transaction, rpc.TransactionState.ACTIVE);
      expect(original.editor.text, 'SELECT current_database();');
      expect(profile.database, 'first');
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
      final beforePattern = backend.client.metadataRequests.length;
      await tester.tap(find.text('2 of 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name pattern (regular expression)').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '(');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('The previous selection is retained.'),
        findsOneWidget,
      );
      expect(model.namespaceSelection('source', '')!.names, {
        'first',
        'second',
      });
      await tester.enterText(find.byType(TextField), r'^second$');
      await tester.tap(find.text('Apply'));
      for (
        var attempt = 0;
        attempt < 5 &&
            model.namespaceSelection('source', '')!.mode !=
                NamespaceSelectionMode.pattern;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        model.namespaceSelection('source', '')!.mode,
        NamespaceSelectionMode.pattern,
      );
      expect(model.namespaceSelection('source', '')!.pattern, r'^second$');
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsOneWidget);
      expect(
        backend.client.metadataRequests.length,
        greaterThan(beforePattern),
      );
      expect(
        backend.client.metadataRequests
            .skip(beforePattern)
            .every(
              (r) =>
                  r.sessionId == 'inspection' &&
                  (r.kind == rpc.ObjectKind.CATALOG || r.catalog == 'second'),
            ),
        isTrue,
      );
      expect(original.connectionCatalog, 'first');
      expect(model.sessions['query']!.transaction, rpc.TransactionState.ACTIVE);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
}
