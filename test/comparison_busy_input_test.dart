import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;
import 'package:flutter/services.dart';
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} comparison target choices wait for capture completion',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('comparison-busy-capture-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)..draftRecovery = false;
        model.newDocument();
        model.backend = backend;
        final current = rpc.Profile(
          id: 'current',
          name: 'Current staging',
          engine: rpc.Engine.POSTGRESQL,
          environment: rpc.Environment.STAGING,
        );
        final desired = rpc.Profile(
          id: 'desired',
          name: 'Desired staging',
          engine: rpc.Engine.POSTGRESQL,
          environment: rpc.Environment.STAGING,
        );
        model.profiles.addAll([current, desired]);
        final metadata = model.connectionOwner(current)..sessionId = 'metadata';
        model.sessions['metadata'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'metadata',
          profile: current,
        );
        final owner = model.openTask(
          WorkbenchDocumentKind.comparison,
          'Schema comparison',
          profileId: current.id,
        );
        final data = ComparisonData(schema: 'public', profileId: current.id);
        owner.payload = data;
        final reply = Completer<rpc.SchemaToolResult>();
        backend.client.schemaTools = (_) => reply.future;
        final semantics = tester.ensureSemantics();
        const menuChannel = MethodChannel(nativeMenuChannelName);
        var menuPresentations = 0;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(menuChannel, (call) async {
              if (call.method != 'show') return null;
              menuPresentations++;
              final entries = (call.arguments as Map)['entries'] as List;
              final selected = entries.indexWhere(
                (entry) =>
                    (entry as Map)['label'] == 'Desired staging · Staging',
              );
              expect(selected, greaterThanOrEqualTo(0));
              return selected;
            });
        Finder picker(String label) => find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              (w.properties.label == label ||
                  w.properties.label?.startsWith('$label: ') == true),
        );
        Future<void> reveal(Finder finder) async {
          await tester.scrollUntilVisible(finder, 160);
          await tester.ensureVisible(finder);
          await tester.pump();
        }

        try {
          await tester.binding.setSurfaceSize(const Size(900, 600));
          final view = ComparisonDocument(
            model: model,
            owner: owner,
            data: data,
            controls: controls,
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(home: view),
          );
          final capture = find.text(
            'Capture schema · Current schema (to be changed)',
          );
          await reveal(capture);
          await tester.tap(capture);
          await tester.pump();
          expect(backend.client.schemaToolRequests, hasLength(1));
          expect(
            backend.client.schemaToolRequests.single.action,
            rpc.SchemaToolAction.CAPTURE_SCHEMA,
          );
          expect(
            backend.client.schemaToolRequests.single.sessionId,
            metadata.sessionId,
          );
          expect(data.busy, isTrue);
          for (final label in [
            'Current schema (to be changed)',
            'Desired schema',
            'Apply to',
          ]) {
            final target = picker(label);
            await reveal(target);
            final node = tester.getSemantics(target);
            expect(
              node.getSemanticsData().flagsCollection.isEnabled,
              Tristate.isFalse,
              reason:
                  '$label must report disabled while capture owns its inputs',
            );
            node.owner!.performAction(node.id, SemanticsAction.tap);
            await tester.pump();
            expect(data.currentProfile, current.id);
            expect(data.desiredProfile, current.id);
            expect(data.profileId, current.id);
            expect(menuPresentations, 0);
          }
          reply.complete(
            rpc.SchemaToolResult(complete: true, snapshot: 'captured-current'),
          );
          await tester.pump();
          await tester.pump();
          expect(data.busy, isFalse);
          expect(data.currentSnapshot, 'captured-current');
          final desiredPicker = picker('Desired schema');
          await reveal(desiredPicker);
          final enabled = tester.getSemantics(desiredPicker);
          expect(
            enabled.getSemanticsData().flagsCollection.isEnabled,
            Tristate.isTrue,
          );
          enabled.owner!.performAction(enabled.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          if (controls is WindowsControls) {
            await tester.tap(find.text('Desired staging · Staging').last);
            await tester.pumpAndSettle();
          } else {
            expect(menuPresentations, 1);
          }
          expect(data.desiredProfile, desired.id);
          expect(data.currentProfile, current.id);
          expect(backend.client.schemaToolRequests, hasLength(1));
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          if (!reply.isCompleted) {
            reply.complete(
              rpc.SchemaToolResult(
                complete: true,
                snapshot: 'captured-current',
              ),
            );
          }
          await tester.pump();
          await tester.pumpWidget(const SizedBox.shrink());
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(menuChannel, null);
          semantics.dispose();
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        }
      },
    );
  }
}
