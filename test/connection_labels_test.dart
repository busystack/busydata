import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/connection_presentation.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  testWidgets(
    'manager and Explorer use the same source IDs after duplicate, rename, add and delete',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('connection-labels-'),
      ))!;
      final backend = TestBackend();
      final profiles = {
        for (final id in ['a', 'b'])
          id: rpc.Profile(
            id: id,
            name: 'New connection',
            engine: rpc.Engine.POSTGRESQL,
            host: 'localhost',
            port: 5432,
            user: 'fixture',
            connectTimeoutSeconds: 10,
            queryTimeoutSeconds: 60,
          ),
      };
      backend.client.profileAction = (r) async {
        if (r.action == rpc.ProfileAction.SAVE_PROFILE) {
          profiles[r.profile.id] = r.profile.deepCopy();
        }
        if (r.action == rpc.ProfileAction.DELETE_PROFILE) {
          profiles.remove(r.profile.id);
        }
        return rpc.ProfileList(profiles: profiles.values);
      };
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      model.profiles.addAll(profiles.values);
      model.document.profileId = 'a';
      model.explorerSelection = 'b';
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New connection · 1'), findsOneWidget);
      expect(find.text('New connection · 2'), findsOneWidget);
      final opened = model.commands!.invoke(
        'connection.edit',
        model.commandContext,
      );
      await tester.pumpAndSettle();
      Future<void> enter(String key, String value) async {
        final field = find.descendant(
          of: find.byKey(ValueKey('connection-$key')),
          matching: find.byType(EditableText),
        );
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
        await tester.pump();
      }

      Future<void> apply() async {
        await tester.tap(find.text('Apply').last);
        await tester.pumpAndSettle();
      }

      void consistent() {
        final names = connectionDisplayNames(
          tester.element(find.byType(WorkbenchView)),
          model.profiles.map((p) => (p.id, p.name)),
        );
        for (final p in model.profiles) {
          expect(
            tester
                .widget<WorkbenchRecord>(
                  find.descendant(
                    of: find.byKey(ValueKey(p.id)),
                    matching: find.byType(WorkbenchRecord),
                  ),
                )
                .label,
            names[p.id],
          );
          expect(
            p.name,
            profiles[p.id]!.name,
            reason: 'Qualifiers never rename stored profiles',
          );
        }
        expect(model.explorerSelection, 'b');
        expect(model.document.profileId, 'a');
      }

      consistent();
      await tester.tap(
        find.byKey(const ValueKey('connection-duplicate-source')),
      );
      await tester.pumpAndSettle();
      await enter('name', 'New connection');
      await apply();
      expect(model.profiles, hasLength(3));
      consistent();
      await tester.tap(find.byKey(const ValueKey('b')));
      await tester.pumpAndSettle();
      await enter('name', 'Reporting');
      await apply();
      consistent();
      await tester.tap(find.byKey(const ValueKey('connection-add-source')));
      await tester.pumpAndSettle();
      await enter('user', 'fixture');
      await apply();
      expect(model.profiles, hasLength(4));
      consistent();
      await tester.tap(find.byKey(const ValueKey('a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete connection').last);
      await tester.pumpAndSettle();
      await apply();
      expect(model.profiles, hasLength(3));
      consistent();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await opened;
      expect(find.text('Reporting'), findsOneWidget);
      expect(find.text('New connection · 1'), findsOneWidget);
      expect(find.text('New connection · 2'), findsOneWidget);
      expect(model.explorerSelection, 'b');
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
    },
  );
}
