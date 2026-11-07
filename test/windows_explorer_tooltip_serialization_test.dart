import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/app/windows/windows_busydata_app.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/serialized_semantics_test_binding.dart';

void main() {
  SerializedSemanticsTestBinding();
  testWidgets(
    'Explorer tooltip anchors survive connection adoption and expansion',
    (tester) async {
      SerializedSemanticsTestBinding.resetRecorder();
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await tester.binding.setSurfaceSize(const Size(1024, 720));
      final semantics = tester.ensureSemantics();
      final backend = TestBackend();
      final model = metadataFixture(
        WorkbenchModel(Directory('/unused-explorer-tooltip-serialization'))
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: 'SELECT 1;'),
      );
      final profile = rpc.Profile(
        id: 'serialization-pg',
        name: 'Serialization PostgreSQL',
        engine: rpc.Engine.POSTGRESQL,
        host: 'localhost',
        port: 5432,
        user: 'fixture',
        database: 'busydata',
      );
      model.profiles.add(profile);
      final opened = rpc.SessionInfo(
        sessionId: 'serialization-explorer',
        profile: profile,
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        currentCatalog: 'busydata',
        currentSchema: 'public',
        autoCommit: true,
        transaction: rpc.TransactionState.IDLE,
      );
      backend.client.opening = (_) async => opened.deepCopy();
      backend.client.sessionCommand = (request) async =>
          opened.deepCopy()
            ..transaction = request.action == rpc.SessionAction.DISCONNECT
                ? rpc.TransactionState.DISCONNECTED
                : rpc.TransactionState.IDLE;
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(20, 20));
      Future<void> frames(String phase) async {
        SerializedSemanticsTestBinding.phase = phase;
        // Include initial/animated incremental updates, not just the settled tree.
        for (final ms in [16, 16, 75, 150, 500, 1500]) {
          await tester.pump(Duration(milliseconds: ms));
        }
      }

      Future<void> hoverAnchors(String phase) async {
        final anchors = find
            .descendant(
              of: find.byType(DatabaseExplorer),
              matching: find.byType(fluent.Tooltip),
            )
            .hitTestable();
        final count = anchors.evaluate().length;
        expect(count, inInclusiveRange(1, 24));
        for (var index = 0; index < count; index++) {
          await mouse.moveTo(tester.getCenter(anchors.at(index)));
          await frames('$phase-hover-$index');
        }
        await mouse.moveTo(const Offset(1000, 700));
        await frames('$phase-retire');
      }

      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [workbenchProvider.overrideWith((_) => model)],
            child: const WindowsBusyDataApp(),
          ),
        );
        await tester.pumpAndSettle();
        await hoverAnchors('disconnected');
        await model.connectExplorer(profile, 'synthetic-fixture');
        await frames('adopt-explorer-connection');
        expect(model.explorerSessions[profile.id], opened.sessionId);
        await hoverAnchors('connected');
        // Connection adoption opens the source. Verify its ordinary collapse
        // control before testing the tooltip and expansion again.
        final initialCollapse = find.bySemanticsLabel(
          'Collapse ${profile.name}',
        );
        expect(initialCollapse, findsOneWidget);
        await tester.tap(initialCollapse);
        await frames('collapse-adopted-source');
        final expand = find.bySemanticsLabel('Expand ${profile.name}');
        expect(expand, findsOneWidget);
        final button = tester.getSemantics(expand).getSemanticsData();
        expect(button.flagsCollection.isButton, isTrue);
        expect(button.hasAction(ui.SemanticsAction.tap), isTrue);
        await mouse.moveTo(tester.getCenter(expand));
        await frames('show-expander-tooltip');
        expect(
          find.text('Expand ${profile.name}'),
          findsOneWidget,
          reason:
              'Preserve the visible tooltip rather than removing the feature',
        );
        await tester.tap(expand);
        await frames('expand-connected-source');
        final collapse = find.bySemanticsLabel('Collapse ${profile.name}');
        expect(collapse, findsOneWidget);
        expect(backend.client.metadataRequests, isNotEmpty);
        await tester.tap(collapse);
        await frames('collapse-connected-source');
        expect(find.bySemanticsLabel('Expand ${profile.name}'), findsOneWidget);
        expect(backend.client.executions, isEmpty);
        await hoverAnchors('selected-source');
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        semantics.dispose();
        await mouse.removePointer();
        await tester.binding.setSurfaceSize(null);
        debugDefaultTargetPlatformOverride = null;
      }
      expect(SerializedSemanticsTestBinding.batches, isNotEmpty);
      expect(
        SerializedSemanticsTestBinding.orphanBatches,
        isEmpty,
        reason:
            'Every engine-bound updated node must remain reachable from root while an Explorer tooltip appears, retires or its row changes',
      );
    },
  );
}
