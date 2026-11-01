import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  testWidgets(
    'failed source move preserves membership and reports inside its dialog',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('folder-move-failure-'),
      ))!;
      var rejectWrites = false;
      final backend = TestBackend();
      final model =
          WorkbenchModel(
              root,
              presentationWrite: (_, _) async {
                if (rejectWrites) {
                  throw const FileSystemException('Write failed');
                }
              },
            )
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(rpc.Profile(id: 'p', name: 'Source'))
            ..newDocument(text: 'SELECT preserved');
      await model.saveSourceFolder('origin', 'Origin', '');
      await model.saveSourceFolder('destination', 'Destination', '');
      await model.moveSourceToFolder('p', 'origin');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      rejectWrites = true;
      final operation = model.commands!.invoke(
        'source.move',
        const WorkbenchCommandContext(profileId: 'p'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Destination').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(model.sourceFolderMembership['p'], 'origin');
      expect(find.text('Move to folder'), findsOneWidget);
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await operation;
    },
  );
  testWidgets(
    'failed rebinding keeps the local SQL and scope and reports inside its dialog',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('virtual-rebind-failure-'),
      ))!;
      var rejectWrites = false;
      final backend = TestBackend();
      final model =
          WorkbenchModel(
              root,
              presentationWrite: (_, _) async {
                if (rejectWrites) {
                  throw const FileSystemException('Write failed');
                }
              },
            )
            ..backend = backend
            ..draftRecovery = false
            ..profiles.add(rpc.Profile(id: 'p', name: 'Replacement'))
            ..profiles.add(rpc.Profile(id: 'deleted', name: 'Original'))
            ..newDocument(text: 'SELECT preserved');
      final original = VirtualViewDefinition(
        id: 'local',
        name: 'Report',
        sql: 'SELECT 17',
        scope: const DatabaseCreationScope(
          profileId: 'deleted',
          catalog: 'old',
          schema: 'public',
        ),
      );
      await model.saveVirtualView(original);
      model.profiles.removeWhere((p) => p.id == 'deleted');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      rejectWrites = true;
      final operation = model.commands!.invoke(
        'virtual.rebind',
        const WorkbenchCommandContext(
          profileId: 'p',
          creationScope: DatabaseCreationScope(
            profileId: 'p',
            catalog: 'other',
            schema: 'public',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report · old / public'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(model.virtualViews['local'], same(original));
      expect(find.text('Rebind local definition here'), findsOneWidget);
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await operation;
    },
  );
  for (final change in ['definition', 'binding', 'endpoint', 'policy']) {
    testWidgets('captured virtual action refuses a changed $change', (
      tester,
    ) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('virtual-captured-'),
      ))!;
      final backend = TestBackend();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Source',
        engine: rpc.Engine.POSTGRESQL,
        host: 'original.example',
        database: 'db',
      );
      final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
        ..backend = backend
        ..draftRecovery = false
        ..profiles.add(profile)
        ..newDocument(text: 'SELECT preserved');
      final original = VirtualViewDefinition(
        id: 'local',
        name: 'Report',
        sql: 'SELECT 17',
        scope: const DatabaseCreationScope(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
        ),
      );
      await model.saveVirtualView(original);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                SizedBox(
                  width: 280,
                  child: DatabaseExplorer(
                    model: model,
                    controls: const LinuxControls(),
                  ),
                ),
                Expanded(
                  child: WorkbenchView(
                    model: model,
                    controls: const LinuxControls(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['Source', 'Virtual views']) {
        await tester.tap(find.bySemanticsLabel('Expand $label'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('db / public / Report'));
      await tester.pumpAndSettle();
      final captured = model.explorerCommandContext!;
      expect(captured.virtualViewId, 'local');
      if (change == 'endpoint') {
        profile.host = 'replacement.example';
      } else if (change == 'policy') {
        profile.environment = rpc.Environment.PRODUCTION;
      } else {
        await model.saveVirtualView(
          VirtualViewDefinition(
            id: original.id,
            name: original.name,
            sql: change == 'definition' ? 'SELECT 29' : original.sql,
            scope: change == 'binding'
                ? const DatabaseCreationScope(
                    profileId: 'p',
                    catalog: 'other',
                    schema: 'public',
                  )
                : original.scope,
          ),
        );
      }
      final documents = model.documents.length;
      await expectLater(
        model.commands!.invoke('virtual.open', captured),
        throwsStateError,
      );
      expect(model.documents.length, documents);
      expect(backend.client.opened, isEmpty);
      expect(backend.client.reviews, isEmpty);
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT preserved');
      semantics.dispose();
    });
  }
  testWidgets(
    'Rename changes only the local virtual-view name without server work',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('virtual-rename-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
        ..backend = backend
        ..draftRecovery = false
        ..profiles.add(rpc.Profile(id: 'p', name: 'Source'))
        ..newDocument(text: 'SELECT preserved');
      const scope = DatabaseCreationScope(
        profileId: 'p',
        catalog: 'db',
        schema: 'public',
      );
      await model.saveVirtualView(
        VirtualViewDefinition(
          id: 'local',
          name: 'Report',
          sql: 'SELECT 17',
          scope: scope,
        ),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await tester.pumpAndSettle();
      final rename = model.commands!.invoke(
        'virtual.rename',
        WorkbenchCommandContext(
          profileId: 'p',
          virtualViewId: 'local',
          virtualView: model.virtualViews['local'],
          virtualSource: model.profiles.single.deepCopy(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rename virtual view'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Virtual view SQL definition'),
        findsNothing,
      );
      await tester.enterText(
        find.descendant(
          of: find.bySemanticsLabel('Virtual view name'),
          matching: find.byType(EditableText),
        ),
        'Renamed report',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      await rename;
      expect(model.virtualViews['local']!.name, 'Renamed report');
      expect(model.virtualViews['local']!.scope, scope);
      expect(model.virtualViews['local']!.sql, 'SELECT 17');
      expect(backend.client.metadataRequests, isEmpty);
      expect(backend.client.opened, isEmpty);
      expect(backend.client.reviews, isEmpty);
      expect(backend.client.executions, isEmpty);
      expect(model.document.editor.text, 'SELECT preserved');
    },
  );
  testWidgets(
    'virtual-view double-click and Enter invoke the normal scoped Run command',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('virtual-activate-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
        ..backend = backend
        ..draftRecovery = false
        ..profiles.add(rpc.Profile(id: 'p', name: 'Source'))
        ..newDocument(text: 'SELECT preserved');
      await model.saveVirtualView(
        VirtualViewDefinition(
          id: 'local',
          name: 'Report',
          sql: 'SELECT 17',
          scope: const DatabaseCreationScope(
            profileId: 'p',
            catalog: 'db',
            schema: 'public',
          ),
        ),
      );
      final runs = <WorkbenchCommandContext>[],
          opens = <WorkbenchCommandContext>[];
      model.commands = WorkbenchCommandRegistry([
        WorkbenchCommand(
          id: 'virtual.run',
          label: 'Run',
          category: 'Object',
          invoke: runs.add,
        ),
        WorkbenchCommand(
          id: 'virtual.open',
          label: 'Open SQL',
          category: 'Object',
          invoke: opens.add,
        ),
      ]);
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
      for (final label in ['Source', 'Virtual views']) {
        await tester.tap(find.bySemanticsLabel('Expand $label'));
        await tester.pumpAndSettle();
      }
      final name = find.text('db / public / Report');
      await tester.tap(name);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(name);
      await tester.pumpAndSettle();
      expect(runs, hasLength(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(runs, hasLength(2));
      for (final run in runs) {
        expect(run.virtualViewId, 'local');
        expect(
          run.creationScope,
          const DatabaseCreationScope(
            profileId: 'p',
            catalog: 'db',
            schema: 'public',
          ),
        );
      }
      expect(opens, isEmpty);
      expect(model.document.editor.text, 'SELECT preserved');
      expect(backend.client.executions, isEmpty);
      semantics.dispose();
    },
  );
}
