import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'ordinary native source rows remain compact without constraining text scaling',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('tree-density-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..profiles.add(rpc.Profile(id: 'p', name: 'Density source'))
        ..newDocument();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: BusyDataYaruTheme.build(
            brightness: Brightness.light,
            accentColor: Colors.orange,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 280,
              child: DatabaseExplorer(
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        ),
      );
      final row = find.bySemanticsLabel(RegExp(r'^Density source · level 1'));
      expect(
        tester.getSize(row).height,
        lessThanOrEqualTo(BusyDataSizes.headerIconButton),
      );
      semantics.dispose();
    },
  );
  testWidgets(
    'bounded tree pages reach objects past the node budget and return to a previous page',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('tree-page-budget-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument(text: 'SELECT 7');
      final profile = rpc.Profile(
        id: 'p',
        name: 'Paged source',
        engine: rpc.Engine.POSTGRESQL,
        database: 'db',
      );
      model.profiles.add(profile);
      model.explorerSessions['p'] = 'inspection';
      model.sessions['inspection'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'db',
        currentSchema: 'public',
      );
      backend.client.metadataAction = (request) async {
        expect(request.independentMetadata, isTrue);
        if (request.kind == rpc.ObjectKind.SCHEMA) {
          return rpc.SchemaObjects(
            complete: true,
            objects: [
              rpc.SchemaObject(
                kind: rpc.ObjectKind.SCHEMA,
                name: 'public',
                catalog: 'db',
                schema: 'public',
              ),
            ],
          );
        }
        if (request.kind == rpc.ObjectKind.CATALOG) {
          return rpc.SchemaObjects(
            complete: true,
            objects: [
              rpc.SchemaObject(kind: request.kind, name: 'db', catalog: 'db'),
            ],
          );
        }
        if (request.kind != rpc.ObjectKind.TABLE) {
          return rpc.SchemaObjects(complete: true);
        }
        final offset = int.tryParse(request.continuation) ?? 0;
        final end = (offset + request.limit).clamp(0, 2305);
        return rpc.SchemaObjects(
          complete: end == 2305,
          totalCount: Int64(2305),
          countAvailability: rpc.MetadataCount.AUTHORITATIVE_TOTAL,
          continuation: end == 2305 ? '' : '$end',
          objects: [
            for (var index = offset; index < end; index++)
              rpc.SchemaObject(
                kind: request.kind,
                catalog: 'db',
                schema: 'public',
                name: 'item_$index',
              ),
          ],
        );
      };
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
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
      await tester.tap(find.bySemanticsLabel('Expand Paged source'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Expand public'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Expand Tables'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('item_8'),
        80,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      final visiblePosition = tester.getTopLeft(find.text('item_8'));
      await tester.tap(find.text('item_8'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('item_8')),
        visiblePosition,
        reason: 'Selecting a visible row must preserve the second click target',
      );
      for (var page = 0; page < 18; page++) {
        await tester.scrollUntilVisible(
          find.text('Load more'),
          -320,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 200,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('item_2304'),
        320,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 200,
      );
      await tester.pumpAndSettle();
      expect(find.text('item_2304'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Previous page'),
        -320,
        scrollable: find.byType(Scrollable).last,
        maxScrolls: 200,
      );
      await tester.pumpAndSettle();
      expect(find.text('2305'), findsOneWidget);
      expect(
        (tester.state(find.byType(DatabaseExplorer)) as dynamic).nodes.length,
        lessThan(2048),
      );
      await tester.tap(find.text('Previous page'));
      await tester.pumpAndSettle();
      expect(backend.client.metadataRequests.last.continuation, '2176');
      expect(find.text('item_2176'), findsOneWidget);
      expect(
        (tester.state(find.byType(DatabaseExplorer)) as dynamic)
            .rowFocus
            .length,
        lessThan(2048),
      );
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT 7');
      semantics.dispose();
    },
  );
  testWidgets('Explorer retains its tree during unrelated result progress', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('explorer-progress-'),
    ))!;
    final model = WorkbenchModel(root)..newDocument();
    addTearDown(model.dispose);
    addTearDown(() => root.delete(recursive: true));
    final profile = rpc.Profile(
      id: 'source',
      name: 'Progress source',
      engine: rpc.Engine.POSTGRESQL,
    );
    model.profiles.add(profile);
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
    model.updateStatus('Initial catalog acknowledgement');
    await tester.pump();
    final header = tester.widget(find.text('Database'));
    for (var row = 0; row < 10; row++) {
      model.updateStatus('Fetched rows: $row');
      await tester.pump();
      expect(identical(tester.widget(find.text('Database')), header), isTrue);
    }
    model.sessions['query'] = rpc.SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'query',
      profile: profile,
      transaction: rpc.TransactionState.ACTIVE,
    );
    model.updateStatus('Acknowledged independent transaction');
    await tester.pump();
    expect(identical(tester.widget(find.text('Database')), header), isFalse);
    expect(find.textContaining('Transaction open'), findsWidgets);
  });
  for (final engine in [rpc.Engine.MYSQL, rpc.Engine.MARIADB]) {
    testWidgets(
      '$engine Explorer separates the catalog list from exact database identities',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('explorer-catalog-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final profile = rpc.Profile(
          id: 'p',
          name: 'Catalog source',
          engine: engine,
        );
        model.profiles.add(profile);
        model.namespaceSelections[model.namespaceScopeKey('p', '')] =
            NamespaceSelection(mode: NamespaceSelectionMode.all);
        model.explorerSessions['p'] = 'inspection';
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: profile,
          currentCatalog: 'busydata',
        );
        backend.client.metadataAction = (request) async => rpc.SchemaObjects(
          complete: true,
          objects: switch (request.kind) {
            rpc.ObjectKind.CATALOG => [
              for (final catalog in ['busydata', 'other'])
                rpc.SchemaObject(
                  kind: request.kind,
                  name: catalog,
                  catalog: catalog,
                ),
            ],
            rpc.ObjectKind.TABLE => [
              rpc.SchemaObject(
                kind: request.kind,
                name: 'items',
                catalog: request.catalog,
                schema: request.schema,
              ),
            ],
            _ => [],
          },
        );
        WorkbenchCommandContext? opened;
        model.commands = WorkbenchCommandRegistry([
          for (final id in [
            'file.new',
            'connection.connect',
            'connection.disconnect',
            'connection.edit',
            'connection.duplicate',
            'connection.delete',
            'connection.favorite',
            'connection.group',
            'connection.capabilities',
            'connection.search',
            'connection.activity',
            'connection.principals',
            'schema.snapshot',
            'schema.compare',
            'schema.diagram',
            'backup.dump',
            'backup.restore',
            'object.data',
            'object.structure',
            'object.sql',
            'object.copy',
            'schema.designer',
            'transfer.import',
          ])
            WorkbenchCommand(
              id: id,
              label: id,
              category: 'Object',
              invoke: (target) {
                if (id == 'object.data') opened = target;
              },
            ),
        ]);
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
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
        await tester.tap(find.bySemanticsLabel('Expand Catalog source'));
        await tester.pumpAndSettle();
        expect(find.text('Databases'), findsNothing);
        expect(find.text('busydata'), findsOneWidget);
        expect(
          backend.client.metadataRequests.where(
            (request) => request.kind == rpc.ObjectKind.SCHEMA,
          ),
          isEmpty,
        );
        await tester.tap(find.bySemanticsLabel('Expand other'));
        await tester.pumpAndSettle();
        await tester.tap(find.bySemanticsLabel('Expand Tables'));
        await tester.pumpAndSettle();
        final row = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^items · level')),
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: row.id,
            type: ui.SemanticsAction.focus,
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Tooltip &&
                widget.message == 'Catalog source / other / items',
          ),
          findsOneWidget,
        );
        expect(opened?.object?.catalog, 'other');
        expect(opened?.object?.schema, 'other');
        expect(opened?.object?.name, 'items');
        semantics.dispose();
      },
    );
  }
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        '${controls.runtimeType} Explorer keyboard reveals lazy rows at 200% $direction',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('explorer-keyboard-'),
          ))!;
          final backend = TestBackend();
          final model = WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: '-- keep this unbound');
          final owner = model.activeOwner;
          final profile = rpc.Profile(
            id: 'p',
            name: 'Staging',
            engine: rpc.Engine.POSTGRESQL,
          );
          model.profiles.add(profile);
          model.explorerSessions['p'] = 'inspection';
          model.sessions['inspection'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'inspection',
            profile: profile,
            currentCatalog: 'db',
          );
          backend.client.metadataAction = (request) async => rpc.SchemaObjects(
            complete: true,
            objects: switch (request.kind) {
              rpc.ObjectKind.SCHEMA => [
                rpc.SchemaObject(name: 'public', kind: request.kind),
              ],
              rpc.ObjectKind.TABLE => [
                for (var i = 0; i < 32; i++)
                  rpc.SchemaObject(
                    name: 'item_${i.toString().padLeft(2, '0')}',
                    schema: 'public',
                    kind: request.kind,
                  ),
              ],
              _ => [],
            },
          );
          await tester.binding.setSurfaceSize(const Size(900, 600));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final view = MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: direction,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 264,
                  child: DatabaseExplorer(
                    model: metadataFixture(model),
                    controls: controls,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(home: Scaffold(body: view)),
          );
          await tester.pumpAndSettle();
          for (final name in ['Staging', 'public', 'Tables']) {
            final expand = find.bySemanticsLabel('Expand $name');
            await tester.scrollUntilVisible(
              expand,
              120,
              scrollable: find.descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(expand);
            await tester.pumpAndSettle();
          }
          final tables = find.bySemanticsLabel(RegExp('^Tables · level'));
          await tester.ensureVisible(tables);
          await tester.pumpAndSettle();
          final node = tester.getSemantics(tables);
          node.owner!.performAction(node.id, ui.SemanticsAction.focus);
          await tester.pumpAndSettle();
          int focusedNodes(SemanticsNode current) {
            var count =
                current.getSemanticsData().flagsCollection.isFocused ==
                    ui.Tristate.isTrue
                ? 1
                : 0;
            current.visitChildren((child) {
              count += focusedNodes(child);
              return true;
            });
            return count;
          }

          void expectRowFocus(SemanticsNode row) {
            try {
              expect(
                focusedNodes(row),
                1,
                reason:
                    'A tree row must announce one focused object with its '
                    'stable identity and tree role, without an anonymous focused '
                    'panel competing for the screen reader focus.',
              );
              final data = row.getSemanticsData();
              expect(data.identifier, startsWith('busydata.database.item.'));
              expect(data.hasAction(ui.SemanticsAction.focus), isTrue);
              expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
            } catch (_) {
              semantics.dispose();
              rethrow;
            }
          }

          expectRowFocus(node);
          final requests = backend.client.metadataRequests.length;
          for (var i = 0; i < 12; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            await tester.pumpAndSettle();
          }
          final destination = find.bySemanticsLabel(RegExp('^item_11 · level'));
          expect(destination, findsOneWidget);
          expectRowFocus(tester.getSemantics(destination));
          expect(
            tester
                .getSemantics(destination)
                .getSemanticsData()
                .flagsCollection
                .isFocused,
            ui.Tristate.isTrue,
          );
          final viewport = tester.getRect(find.byType(ListView));
          final row = tester.getRect(destination);
          expect(row.top, greaterThanOrEqualTo(viewport.top));
          expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
          expect(model.activeOwner, same(owner));
          expect(model.document.sessionId, isNull);
          expect(model.document.editor.text, '-- keep this unbound');
          expect(backend.client.metadataRequests.length, requests);
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          semantics.dispose();
        },
      );
    }
    testWidgets(
      '${controls.runtimeType} Explorer keeps overloads separate and coalesces composite index rows',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('explorer-identities-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final profile = rpc.Profile(
          id: 'p',
          name: 'Saved staging',
          engine: rpc.Engine.POSTGRESQL,
        );
        model.profiles.add(profile);
        model.explorerSessions['p'] = 'inspection';
        model.sessions['inspection'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: profile,
          currentCatalog: 'db',
        );
        WorkbenchCommandContext? opened;
        model.commands = WorkbenchCommandRegistry([
          for (final id in [
            'file.new',
            'connection.connect',
            'connection.disconnect',
            'connection.edit',
            'connection.duplicate',
            'connection.delete',
            'connection.favorite',
            'connection.group',
            'connection.capabilities',
            'connection.search',
            'connection.activity',
            'connection.principals',
            'schema.snapshot',
            'schema.compare',
            'schema.diagram',
            'backup.dump',
            'backup.restore',
            'object.data',
            'object.sql',
            'object.copy',
            'schema.designer',
            'transfer.import',
          ])
            WorkbenchCommand(
              id: id,
              label: id,
              category: 'Object',
              invoke: (_) {},
            ),
          WorkbenchCommand(
            id: 'object.structure',
            label: 'Inspect structure',
            category: 'Object',
            invoke: (c) => opened = c,
          ),
        ]);
        backend.client.metadataAction = (r) async => rpc.SchemaObjects(
          complete: true,
          objects: switch (r.kind) {
            rpc.ObjectKind.SCHEMA => [
              rpc.SchemaObject(name: 'public', kind: r.kind),
            ],
            rpc.ObjectKind.ROUTINE => [
              for (final args in ['x integer', 'x text'])
                rpc.SchemaObject(
                  name: 'same',
                  identifier: 'same($args)',
                  kind: r.kind,
                  schema: 'public',
                ),
            ],
            rpc.ObjectKind.TABLE => [
              rpc.SchemaObject(name: 'items', kind: r.kind, schema: 'public'),
            ],
            rpc.ObjectKind.INDEX => [
              for (final column in ['a', 'b'])
                rpc.SchemaObject(
                  name: 'composite',
                  kind: r.kind,
                  schema: 'public',
                  table: 'items',
                  properties: {'column': column}.entries,
                ),
            ],
            _ => [],
          },
        );
        await tester.binding.setSurfaceSize(const Size(1000, 900));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = DatabaseExplorer(
          model: metadataFixture(model),
          controls: controls,
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        Future<void> expand(String name) async {
          await tester.tap(find.bySemanticsLabel('Expand $name'));
          await tester.pumpAndSettle();
        }

        await expand('Saved staging');
        await expand('public');
        await expand('Routines');
        for (final args in ['x integer', 'x text']) {
          expect(find.text('same($args)'), findsOneWidget);
          final row = tester.getSemantics(
            find.bySemanticsLabel(RegExp('^same\\($args\\) · level')),
          );
          tester.binding.performSemanticsAction(
            ui.SemanticsActionEvent(
              viewId: tester.view.viewId,
              nodeId: row.id,
              type: ui.SemanticsAction.focus,
            ),
          );
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          expect(opened!.object!.identifier, 'same($args)');
          expect(opened!.object!.name, 'same');
        }
        await expand('Tables');
        await expand('items');
        await expand('Indexes');
        expect(find.text('composite'), findsOneWidget);
        expect(backend.client.executions, isEmpty);
        expect(model.document.sessionId, isNull);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'Explorer exposes inactive unknown and transaction clients on their connection',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('explorer-client-states-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      model.profiles.add(
        rpc.Profile(
          id: 'p',
          name: 'Saved staging',
          environment: rpc.Environment.STAGING,
        ),
      );
      for (final state in [
        rpc.TransactionState.UNKNOWN_TRANSACTION,
        rpc.TransactionState.ACTIVE,
        rpc.TransactionState.FAILED_TRANSACTION,
      ]) {
        model.sessions[state.name] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: state.name,
          transaction: state,
          profile: rpc.Profile(
            id: 'p',
            name: 'Original production',
            environment: rpc.Environment.PRODUCTION,
          ),
        );
      }
      var opened = 0;
      model.commands = WorkbenchCommandRegistry([
        for (final id in [
          'file.new',
          'connection.connect',
          'connection.disconnect',
          'connection.edit',
          'connection.duplicate',
          'connection.delete',
          'connection.favorite',
          'connection.group',
          'connection.capabilities',
          'connection.search',
          'connection.activity',
          'connection.principals',
          'schema.snapshot',
          'schema.compare',
          'schema.diagram',
          'backup.dump',
          'backup.restore',
        ])
          WorkbenchCommand(
            id: id,
            label: id,
            category: 'Connection',
            invoke: (_) {},
          ),
        WorkbenchCommand(
          id: 'view.sessions',
          label: 'Owned sessions',
          category: 'View',
          invoke: (_) => opened++,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 264,
            height: 600,
            child: DatabaseExplorer(
              model: metadataFixture(model),
              controls: const LinuxControls(),
            ),
          ),
        ),
      );
      final row = tester
          .getSemantics(find.bySemanticsLabel(RegExp('^Saved staging · level')))
          .getSemanticsData();
      expect(row.label, contains('Outcome unknown 1 · Production'));
      expect(row.label, contains('Transaction open 1'));
      expect(row.label, contains('Transaction failed 1'));
      await tester.tap(find.text('Outcome unknown 1 · Production'));
      await tester.pump();
      expect(opened, 1);
      expect(model.document.sessionId, isNull);
      expect(backend.client.executions, isEmpty);
      expect(backend.client.metadataRequests, isEmpty);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets(
    'Explorer names live production policy after editing a saved profile',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('explorer-production-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      model.profiles.add(
        rpc.Profile(
          id: 'p',
          name: 'Edited staging profile',
          engine: rpc.Engine.MYSQL,
          environment: rpc.Environment.STAGING,
        ),
      );
      model.explorerSessions['p'] = 'original-session';
      model.sessions['original-session'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'original-session',
        profile: rpc.Profile(
          id: 'p',
          name: 'Original production',
          engine: rpc.Engine.POSTGRESQL,
          environment: rpc.Environment.PRODUCTION,
          readOnly: true,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: DatabaseExplorer(
            model: metadataFixture(model),
            controls: const LinuxControls(),
          ),
        ),
      );
      final row = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Edited staging profile · level')),
      );
      expect(
        row.getSemanticsData().label,
        contains('PostgreSQL · Explorer connected · Production'),
      );
      expect(
        row.getSemanticsData().label,
        contains('BusyData read-only policy'),
      );
      expect(model.document.sessionId, isNull);
      expect(backend.client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      semantics.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets(
    'tree lazily pages metadata, filters only loaded names, rejects changed context',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('explorer-ui-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root, presentationWrite: (_, bytes) async {})
        ..draftRecovery = false;
      model.newDocument(text: '-- unrelated SQL remains unbound');
      model.backend = backend;
      final profile = rpc.Profile(
        id: 'connection',
        name: 'Staging database',
        engine: rpc.Engine.POSTGRESQL,
        environment: rpc.Environment.STAGING,
      );
      model.profiles.add(profile);
      model.explorerSessions[profile.id] = 'inspection';
      model.sessions['inspection'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'db',
        contextRevision: Int64(1),
      );
      final delayed = Completer<rpc.SchemaObjects>();
      backend.client.metadataAction = (r) async {
        if (r.kind == rpc.ObjectKind.SCHEMA) {
          return rpc.SchemaObjects(
            complete: true,
            contextRevision: Int64(1),
            objects: [
              rpc.SchemaObject(kind: rpc.ObjectKind.SCHEMA, name: 'public'),
            ],
          );
        }
        if (r.kind == rpc.ObjectKind.TABLE) {
          if (r.continuation.isEmpty) {
            return rpc.SchemaObjects(
              continuation: 'next',
              contextRevision: Int64(1),
              objects: [
                rpc.SchemaObject(
                  kind: rpc.ObjectKind.TABLE,
                  name: 'first_table',
                  schema: 'public',
                ),
              ],
            );
          }
          return delayed.future;
        }
        return rpc.SchemaObjects(complete: true, contextRevision: Int64(1));
      };
      const menuChannel = MethodChannel('busydata/native_menus');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            menuChannel,
            (_) async => throw MissingPluginException(),
          );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(menuChannel, null);
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: DatabaseExplorer(
                model: metadataFixture(model),
                controls: const LinuxControls(),
              ),
            ),
          ),
        ),
      );
      expect(backend.client.metadataRequests, isEmpty);
      final expansion = tester.getSemantics(
        find.bySemanticsLabel('Expand Staging database'),
      );
      expect(
        expansion.getSemanticsData().flagsCollection.isEnabled,
        ui.Tristate.isTrue,
      );
      expect(
        expansion.getSemanticsData().hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
      final connection = tester.getSemantics(
        find.bySemanticsLabel(RegExp('^Staging database · level')),
      );
      expect(
        connection.getSemanticsData().hasAction(ui.SemanticsAction.focus),
        isTrue,
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: connection.id,
          type: ui.SemanticsAction.focus,
        ),
      );
      await tester.pump();
      expect(
        connection.getSemanticsData().flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );
      await tester.tap(find.bySemanticsLabel('Expand Staging database'));
      await tester.pumpAndSettle();
      expect(backend.client.metadataRequests.map((r) => r.kind).toList(), [
        rpc.ObjectKind.CATALOG,
        rpc.ObjectKind.SCHEMA,
      ]);
      await tester.tap(find.bySemanticsLabel('Expand public'));
      await tester.pumpAndSettle();
      final tablesRow = find
          .ancestor(of: find.text('Tables'), matching: find.byType(Row))
          .first;
      await tester.tap(
        find.descendant(
          of: tablesRow,
          matching: find.bySemanticsLabel('Expand Tables'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'first_table'),
        findsOneWidget,
      );
      expect(backend.client.metadataRequests.last.limit, 128);
      final beforeFilter = backend.client.metadataRequests.length;
      if (find.byTooltip('View options').evaluate().isNotEmpty) {
        await tester.tap(find.byTooltip('View options'));
      } else {
        await tester.tap(find.byTooltip('More').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('View options'));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filter connections and objects'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'first_table');
      await tester.pump();
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'first_table'),
        findsOneWidget,
      );
      expect(backend.client.metadataRequests.length, beforeFilter);
      expect(find.text('Filters loaded tree objects'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == 'Filters loaded tree objects',
        ),
        findsOneWidget,
      );
      WorkbenchCommandContext? opened;
      model.commands = WorkbenchCommandRegistry([
        for (final id in [
          'file.new',
          'connection.connect',
          'connection.disconnect',
          'connection.edit',
          'connection.duplicate',
          'connection.delete',
          'connection.favorite',
          'connection.group',
          'connection.capabilities',
          'connection.search',
          'connection.activity',
          'connection.principals',
          'backup.dump',
          'backup.restore',
          'object.data',
          'object.sql',
          'object.copy',
          'schema.designer',
          'schema.diagram',
          'schema.snapshot',
          'schema.compare',
          'transfer.import',
        ])
          WorkbenchCommand(
            id: id,
            label: id,
            category: 'Object',
            invoke: (context) {
              if (id == 'schema.snapshot' ||
                  id == 'object.copy' ||
                  id == 'file.new' ||
                  id == 'object.data') {
                opened = context;
              }
            },
          ),
        WorkbenchCommand(
          id: 'object.structure',
          label: 'Inspect structure',
          category: 'Object',
          invoke: (context) => opened = context,
        ),
      ]);
      final tableNode = tester.getSemantics(
        find.bySemanticsLabel(RegExp('first_table · level')),
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: tableNode.id,
          type: ui.SemanticsAction.focus,
        ),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(opened?.object?.name, 'first_table');
      expect(opened?.sessionId, 'inspection');
      expect(opened?.owner, isNull);
      opened = null;
      final pointerTarget = find.byWidgetPredicate(
        (w) => w is Text && w.data == 'first_table',
      );
      expect(pointerTarget.hitTestable(), findsOneWidget);
      await tester.tap(pointerTarget);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(pointerTarget);
      await tester.pumpAndSettle();
      expect(opened?.object?.name, 'first_table');
      expect(opened?.object?.schema, 'public');
      expect(opened?.profileId, profile.id);
      opened = null;
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: tableNode.id,
          type: ui.SemanticsAction.tap,
        ),
      );
      await tester.pump();
      expect(opened?.object?.name, 'first_table');
      opened = null;
      await tester.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'first_table'),
      );
      await tester.pumpAndSettle();
      expect(
        opened,
        isNull,
        reason: 'A pointer single-click only selects the object',
      );
      for (final command in ['object.copy', 'file.new']) {
        final pointer = await tester.startGesture(
          tester.getCenter(
            find.byWidgetPredicate((w) => w is Text && w.data == 'first_table'),
          ),
          kind: ui.PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await pointer.up();
        await tester.pumpAndSettle();
        await tester.tap(find.text(command));
        await tester.pumpAndSettle();
        expect(opened?.object?.schema, 'public');
        expect(opened?.object?.name, 'first_table');
        expect(opened?.profileId, 'connection');
        expect(opened?.sessionId, 'inspection');
        expect(opened?.owner, isNull);
        expect(model.document.sessionId, isNull);
        expect(backend.client.executions, isEmpty);
      }
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('Load more'));
      await tester.pump();
      expect(backend.client.metadataRequests.last.continuation, 'next');
      model.sessions['inspection'] = model.sessions['inspection']!.deepCopy()
        ..contextRevision = Int64(2);
      model.updateStatus('Context changed');
      await tester.pump();
      delayed.complete(
        rpc.SchemaObjects(
          complete: true,
          contextRevision: Int64(1),
          objects: [
            rpc.SchemaObject(kind: rpc.ObjectKind.TABLE, name: 'stale_table'),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('stale_table'), findsNothing);
      expect(model.document.sessionId, isNull);
      semantics.dispose();
      expect(model.document.editor.text, '-- unrelated SQL remains unbound');
      expect(backend.client.executions, isEmpty);
    },
  );
}
