import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'package:busydata/src/ui/common/workbench_settings.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/app/busydata_design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const window = MethodChannel('yaru_window');
  const events = EventChannel('yaru_window/events');
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      window,
      (call) async => call.method == 'state' ? <String, Object?>{} : null,
    );
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(window, null);
    messenger.setMockStreamHandler(events, null);
  });
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} staged settings records assignments, reports conflicts and preserves recovery',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('settings-ui-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: 'SELECT settings_must_not_execute;');
        model.editDrafts.add(
          rpc.EditDraftInfo(
            draftId: 'unknown-private',
            state: 'UNKNOWN_OUTCOME',
          ),
        );
        final document = model.document, editor = model.document.editor;
        await tester.binding.setSurfaceSize(const Size(1280, 720));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is LinuxControls
              ? MaterialApp(home: Scaffold(body: view))
              : fluent.FluentApp(home: view),
        );
        await model.commands!.invoke('preferences', model.commandContext);
        await tester.pumpAndSettle();
        expect(find.byType(WorkbenchSettings), findsOneWidget);
        if (ui is LinuxControls) {
          expect(
            find.byKey(const ValueKey('settings-sidebar')),
            findsOneWidget,
          );
          expect(find.byType(DatabaseExplorer), findsNothing);
          expect(
            find.byType(DatabaseExplorer, skipOffstage: false),
            findsOneWidget,
          );
          expect(model.explorerWidth, 300);
        }
        await tester.tap(find.text('Keyboard shortcuts'));
        await tester.pumpAndSettle();
        if (ui is LinuxControls) {
          expect(find.byType(BusyDataKeyboardShortcutBadge), findsWidgets);
          final documents = model.documents.length;
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          expect(model.documents.length, documents);
          expect(backend.client.executions, isEmpty);
        }
        await tester.scrollUntilVisible(
          find.text('Run current statement'),
          300,
          scrollable: find
              .descendant(
                of: find.byType(WorkbenchSettings),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.text('Run current statement'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record shortcut'));
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(
          find.textContaining('not assigned to another action'),
          findsOneWidget,
        );
        expect(find.byType(SearchResultList), findsNothing);
        expect(model.shortcuts['execute'], 'Ctrl+Enter');
        await tester.tap(find.text('Record shortcut'));
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        // The modal now shows the reference's animated saving state. Let the
        // real durable writer acknowledge before waiting for animations to settle.
        await tester.pump();
        for (
          var attempt = 0;
          attempt < 250 && model.shortcuts['execute'] != 'Ctrl+Alt+Enter';
          attempt++
        ) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.pumpAndSettle();
        expect(find.text('Record shortcut'), findsNothing);
        expect(
          model.shortcuts['execute'],
          'Ctrl+Alt+Enter',
          reason: 'The dialog acknowledges durable acceptance',
        );
        if (ui is LinuxControls) {
          await tester.binding.setSurfaceSize(const Size(640, 540));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('settings-page-selector')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('settings-sidebar')).hitTestable(),
            findsNothing,
          );
          await tester.binding.setSurfaceSize(const Size(1280, 720));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('settings-sidebar')).hitTestable(),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('Execution options'));
        await tester.pumpAndSettle();
        final rows = find.descendant(
          of: find.byType(WorkbenchSettings),
          matching: find.byWidgetPredicate(
            (widget) => widget is EditableText && !widget.readOnly,
          ),
        );
        await tester.enterText(rows, '0');
        await tester.pump();
        await tester.tap(find.text('Save').last);
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a row limit from 1 to 1,000,000.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('not assigned to another action'),
          findsNothing,
        );
        await tester.enterText(rows, '500');
        await tester.pump();
        await tester.tap(find.text('Save').last);
        for (
          var retry = 0;
          retry < 250 && model.status != 'Settings saved';
          retry++
        ) {
          await tester.pump();
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        await tester.pumpAndSettle();
        expect(model.status, 'Settings saved');
        await tester.tap(find.text('Close').last);
        await tester.pumpAndSettle();
        expect(model.shortcuts['execute'], 'Ctrl+Alt+Enter');
        expect(model.editDrafts.single.draftId, 'unknown-private');
        expect(model.document, same(document));
        expect(model.document.editor, same(editor));
        expect(backend.client.executions, isEmpty);
        expect(backend.client.editRequests, isEmpty);
        final saved =
            (await tester.runAsync(
                  () async => jsonDecode(
                    await File('${root.path}/presentation.json').readAsString(),
                  ),
                ))
                as Map;
        expect((saved['shortcuts'] as Map)['execute'], 'Ctrl+Alt+Enter');
        expect(
          model.commands!.command('sql.run').shortcutLabel,
          'Ctrl+Alt+Enter',
        );
        expect(tester.takeException(), isNull);
      },
    );
    for (final stale in [false, true]) {
      testWidgets(
        '${ui.runtimeType} sharing ${stale ? "rejects changed context" : "stays with its initiating query"}',
        (tester) async {
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('sharing-ui-'),
          ))!;
          final model =
              (await tester.runAsync(() async => WorkbenchModel(root)))!
                ..draftRecovery = false
                ..backend = TestBackend()
                ..newDocument(text: '-- existing client');
          final backend = model.backend as TestBackend;
          model.document.sessionId = 'owned-session';
          model.document.profileId = 'original';
          model.sessions['owned-session'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'owned-session',
            autoCommit: false,
            contextRevision: Int64(1),
            sessionRevision: Int64(1),
            transaction: rpc.TransactionState.ACTIVE,
            profile: rpc.Profile(
              id: 'original',
              name: 'Existing staging',
              environment: rpc.Environment.STAGING,
            ),
          );
          model.newDocument(text: '-- initiating query');
          final initiating = model.document;
          await tester.binding.setSurfaceSize(const Size(1280, 960));
          await tester.pumpWidget(
            ui is WindowsControls
                ? fluent.FluentApp(
                    home: WorkbenchView(model: model, controls: ui),
                  )
                : MaterialApp(
                    home: WorkbenchView(model: model, controls: ui),
                  ),
          );
          final operation = model.commands!.invoke(
            'connection.share',
            model.commandContext,
          );
          final rejected = stale
              ? expectLater(operation, throwsStateError)
              : null;
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .textContaining('Existing staging · Staging · owned-session')
                .last,
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Existing staging · owned-session'),
            findsOneWidget,
          );
          expect(
            find.textContaining('Manual transaction · Transaction open'),
            findsOneWidget,
          );
          model.newDocument(text: '-- different active query');
          final other = model.document;
          if (stale) {
            model.sessions['owned-session']!.contextRevision = Int64(2);
          }
          await tester.tap(
            find.text('Share an existing session (advanced)').last,
          );
          await tester.pumpAndSettle();
          if (rejected != null) {
            await rejected;
            expect(initiating.sessionId, isNull);
          } else {
            await operation;
            expect(initiating.sessionId, 'owned-session');
            expect(initiating.profileId, 'original');
          }
          expect(other.sessionId, isNull);
          expect(model.document, same(other));
          expect(model.sessions['owned-session']!.autoCommit, isFalse);
          expect(backend.client.executions, isEmpty);
          expect(backend.client.sessionCommands, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        },
      );
    }
  }
}
