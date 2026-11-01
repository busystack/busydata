import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} comparison exposes distinct actionable current desired and apply targets at 200 percent',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('comparison-target-labels-'),
        ))!;
        final model = (await tester.runAsync(() async => WorkbenchModel(root)))!
          ..draftRecovery = false
          ..backend = TestBackend()
          ..newDocument();
        final backend = model.backend as TestBackend;
        final current = rpc.Profile(
          id: 'current',
          name: 'Current staging',
          environment: rpc.Environment.STAGING,
        );
        final desired = rpc.Profile(id: 'desired', name: 'Desired reference');
        model.profiles.addAll([current, desired]);
        final owner = model.openTask(
          WorkbenchDocumentKind.comparison,
          'Schema comparison',
        );
        final data = ComparisonData(schema: 'public', profileId: current.id);
        owner.payload = data;
        final semantics = tester.ensureSemantics();
        await tester.binding.setSurfaceSize(const Size(900, 600));
        final view = MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ComparisonDocument(
            model: model,
            owner: owner,
            data: data,
            controls: controls,
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: view),
        );
        for (final label in [
          'Current schema (to be changed)',
          'Desired schema',
          'Apply to',
        ]) {
          final picker = find.byWidgetPredicate(
            (w) =>
                w is Semantics &&
                (w.properties.label == label ||
                    w.properties.label?.startsWith('$label: ') == true),
          );
          await tester.scrollUntilVisible(picker, 160);
          await tester.ensureVisible(picker);
          await tester.pump();
          final node = tester.getSemantics(picker).getSemanticsData();
          expect(node.label, contains(label));
          expect('${node.label} ${node.value}', contains('Current staging'));
          expect(
            node.hasAction(SemanticsAction.tap),
            isTrue,
            reason: '$label must retain its native selection action',
          );
        }
        expect(backend.client.executions, isEmpty);
        expect(backend.client.schemaToolRequests, isEmpty);
        expect(tester.takeException(), isNull);
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }

  testWidgets(
    'current to desired comparison stays owned; opening SQL does not execute',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('comparison-owner-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)..draftRecovery = false;
      model.newDocument();
      model.backend = backend;
      final profile = rpc.Profile(
        id: 'staging',
        name: 'Staging',
        engine: rpc.Engine.POSTGRESQL,
        environment: rpc.Environment.STAGING,
      );
      model.profiles.add(profile);
      final metadata = model.connectionOwner(profile)..sessionId = 'metadata';
      model.sessions['metadata'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'metadata',
        profile: profile,
      );
      final owner = model.openTask(
        WorkbenchDocumentKind.comparison,
        'Schema comparison',
        profileId: profile.id,
      );
      final data = ComparisonData(schema: 'public', profileId: profile.id)
        ..current = 'Before'
        ..desired = 'After'
        ..currentSnapshot = 'before-evidence'
        ..desiredSnapshot = 'after-evidence';
      owner.payload = data;
      final reply = Completer<rpc.SchemaToolResult>();
      backend.client.schemaTools = (_) => reply.future;
      Widget app() => MaterialApp(
        home: ComparisonDocument(
          model: model,
          owner: owner,
          controls: const LinuxControls(),
          data: data,
        ),
      );
      await tester.pumpWidget(app());
      await tester.scrollUntilVisible(find.text('Compare schemas'), 300);
      await tester.tap(find.text('Compare schemas'));
      await tester.pump();
      final request = backend.client.schemaToolRequests.single;
      expect(request.sourceSnapshot, 'before-evidence');
      expect(request.targetSnapshot, 'after-evidence');
      expect(request.sessionId, metadata.sessionId);
      model.newDocument();
      final other = model.activeOwner;
      reply.complete(
        rpc.SchemaToolResult(
          complete: true,
          sql: ['ALTER TABLE "public"."t" ADD COLUMN "n" text;'],
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(data.result!.sql, hasLength(1));
      expect(data.resultEngine, rpc.Engine.POSTGRESQL);
      expect(model.activeOwner, same(other));
      Future<void> revealSql() => tester.scrollUntilVisible(
        find.text('Open SQL'),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await revealSql();
      model.profiles[0] = profile.deepCopy()..engine = rpc.Engine.MYSQL;
      await tester.pumpWidget(app());
      await tester.pump();
      await revealSql();
      await tester.tap(find.text('Open SQL'));
      await tester.pump();
      expect(model.activeOwner, same(other));
      expect(model.documents, hasLength(2));
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
      model.profiles[0] = profile;
      await tester.pumpWidget(app());
      await tester.pump();
      await revealSql();
      await tester.tap(find.text('Open SQL'));
      await tester.pump();
      expect(model.document.editor.text, contains('ALTER TABLE'));
      expect(model.document.profileId, profile.id);
      expect(model.document.sessionId, isNull);
      expect(model.activeOwner.evidenceProfile!.engine, rpc.Engine.POSTGRESQL);
      expect(model.document.dirty, isTrue);
      expect(backend.client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
}
