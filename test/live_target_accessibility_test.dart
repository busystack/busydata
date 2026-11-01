import 'support/fake_backend.dart';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/native_window.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} live target has an independent announcing node',
      (tester) async {
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-live-target-'),
        ))!;
        final model = WorkbenchModel(root)..draftRecovery = false;
        model.newDocument();
        await tester.binding.setSurfaceSize(const Size(1280, 960));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final view = WorkbenchView(model: model, controls: controls);
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        model.document.sessionId = 'session-only';
        model.sessions['session-only'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'session-only',
          profile: rpc.Profile(
            name: 'Production target',
            host: 'database.example',
            port: 5432,
            database: 'original',
            environment: rpc.Environment.PRODUCTION,
          ),
          currentCatalog: 'actual',
          currentSchema: 'quoted schema',
          transaction: rpc.TransactionState.IDLE,
          autoCommit: true,
        );
        model.updateStatus('Connected');
        await tester.pump();
        const label =
            'Production target · database.example:5432 · Production · Auto-commit · actual/quoted schema · session-only';
        final node = tester.getSemantics(
          find.byKey(const ValueKey('live-workbench-target')),
        );
        expect(node.getSemanticsData().label, label);
        expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
        expect(
          find.text('Disconnected · documents are recoverable'),
          findsNothing,
        );
        model.sessions['session-only'] =
            model.sessions['session-only']!.deepCopy()
              ..currentCatalog = 'new_actual'
              ..currentSchema = 'other'
              ..transaction = rpc.TransactionState.ACTIVE;
        model.updateStatus('Context changed');
        await tester.pump();
        const changed =
            'Production target · database.example:5432 · Production · Auto-commit · Transaction open · new_actual/other · session-only';
        expect(
          tester
              .getSemantics(find.byKey(const ValueKey('live-workbench-target')))
              .getSemanticsData()
              .label,
          changed,
        );
        expect(find.textContaining('new_actual / other'), findsWidgets);
        model.sessions['session-only']!.transaction =
            rpc.TransactionState.UNKNOWN_TRANSACTION;
        model.track(
          rpc.JobInfo(
            jobId: 'unknown-write',
            executionId: 'unknown-write',
            sessionId: 'session-only',
            state: rpc.JobState.UNKNOWN_OUTCOME,
            target: model.sessions['session-only']!.profile,
            messages: ['Captured database diagnostic'],
          ),
          documentId: model.document.id,
        );
        await tester.pumpAndSettle();
        const warning =
            'The operation may have completed. This session cannot run further SQL. Never retry automatically; reconcile the outcome before starting new work.';
        expect(find.textContaining(warning), findsOneWidget);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        await tester.enterText(
          find
              .byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              )
              .first,
          'Owned sessions',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(warning), findsOneWidget);
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        semantics.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }
}
