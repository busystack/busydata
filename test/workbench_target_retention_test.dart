import 'dart:io';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets('${controls.runtimeType} keeps target controls during progress '
        'and refreshes exact target and command changes', (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('target-retention-'),
      ))!;
      final backend = TestBackend();
      var disposed = false;
      final model =
          WorkbenchModel(directory, presentationWrite: (_, _) async {})
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: 'SELECT 1');
      final profile = rpc.Profile(
        id: 'target',
        name: 'Current target',
        engine: rpc.Engine.POSTGRESQL,
        host: '127.0.0.1',
        port: 32843,
      );
      model.profiles.add(profile);
      model.document.sessionId = 'session';
      model.document.profileId = profile.id;
      model.sessions['session'] = rpc.SessionInfo(
        sessionId: 'session',
        profile: profile.deepCopy(),
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        currentCatalog: 'busydata',
        currentSchema: 'public',
        contextRevision: Int64.ONE,
        sessionRevision: Int64.ONE,
        autoCommit: true,
        transaction: rpc.TransactionState.IDLE,
      );
      final result = rpc.StatementResult(
        resultId: 'result',
        fetchedRows: Int64(1000),
        columns: [rpc.Column(ordinal: 1, name: 'n', typeName: 'bigint')],
      );
      model.jobs['job'] = rpc.JobInfo(
        jobId: 'job',
        executionId: 'execution',
        sessionId: 'session',
        state: rpc.JobState.FETCHING,
        results: [result],
      );
      model.jobDocuments['job'] = model.document.id;
      model.latestExecutions[model.document.id] = 'execution';
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!disposed) model.dispose();
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      final view = WorkbenchView(model: model, controls: controls);
      await tester.pumpWidget(
        controls is WindowsControls
            ? fluent.FluentApp(home: view)
            : MaterialApp(
                theme: BusyDataYaruTheme.build(
                  brightness: Brightness.light,
                  accentColor: Colors.orange,
                ),
                home: Scaffold(body: view),
              ),
      );
      await tester.pumpAndSettle();
      final target = find.byKey(const ValueKey('live-workbench-target'));
      Semantics currentTarget() => tester.widget<Semantics>(target);
      final original = currentTarget();
      expect(original.properties.label, contains('public'));
      model.targetFocus.requestFocus();
      await tester.pump();
      for (final count in [10000, 100000, 1000000]) {
        model.jobs['job'] = model.jobs['job']!.deepCopy()
          ..results[0].fetchedRows = Int64(count);
        model.updateStatus('Received $count rows');
        await tester.pump();
        expect(currentTarget(), same(original));
        expect(model.targetFocus.hasFocus, isTrue);
        expect(find.text('Received $count rows'), findsOneWidget);
      }
      model.sessions['session']!.sessionRevision = Int64(2);
      model.updateStatus('Physical owner revision changed');
      await tester.pump();
      expect(currentTarget(), isNot(same(original)));
      final revisedOwner = currentTarget();
      // Mutate the protobuf in place: retained comparison inputs must be copies.
      model.sessions['session']!
        ..currentSchema = 'audit'
        ..contextRevision = Int64(2);
      model.updateStatus('Schema changed');
      await tester.pump();
      expect(currentTarget(), isNot(same(revisedOwner)));
      expect(currentTarget().properties.label, contains('audit'));
      final schemaTarget = currentTarget();
      model.jobs['job'] = model.jobs['job']!.deepCopy()
        ..state = rpc.JobState.COMPLETED;
      model.updateStatus('Completed');
      await tester.pump();
      expect(currentTarget(), isNot(same(schemaTarget)));
      expect(model.commandContext.jobId, isNull);
      final completed = currentTarget();
      model.sessions['session']!.profile.host = 'new-host';
      model.updateStatus('Profile display changed');
      await tester.pump();
      expect(currentTarget(), isNot(same(completed)));
      expect(currentTarget().properties.label, contains('new-host'));
      final beforeTextChange = currentTarget();
      model.document.editor.text = 'SELECT 2';
      await tester.pump();
      expect(currentTarget(), isNot(same(beforeTextChange)));
      expect(model.document.editor.text, 'SELECT 2');
      expect(backend.client.executions, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      disposed = true;
    });
  }
}
