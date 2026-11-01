import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${controls.runtimeType} owned sessions reveals orphan uncertainty before idle consoles at $scale',
        (tester) async {
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('session-attention-'),
          ))!;
          final backend = TestBackend();
          final model = WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: 'SELECT local_only;');
          for (var i = 0; i < 8; i++) {
            model.sessions['s$i'] = rpc.SessionInfo(
              metadataSourceIdentity: fixtureMetadataSourceIdentity,
              sessionId: 's$i',
              profile: rpc.Profile(
                id: 'p$i',
                name: i == 7 ? 'Production orphan' : 'Idle connection $i',
                environment: i == 7
                    ? rpc.Environment.PRODUCTION
                    : rpc.Environment.STAGING,
              ),
              currentCatalog: 'catalog',
              currentSchema: 'public',
              autoCommit: true,
              transaction: i == 7
                  ? rpc.TransactionState.UNKNOWN_TRANSACTION
                  : i == 6
                  ? rpc.TransactionState.FAILED_TRANSACTION
                  : i == 5
                  ? rpc.TransactionState.ACTIVE
                  : rpc.TransactionState.IDLE,
            );
          }
          await tester.binding.setSurfaceSize(const Size(900, 600));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          Widget media(BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              highContrast: true,
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          );
          final view = WorkbenchView(model: model, controls: controls);
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(builder: media, home: view)
                : MaterialApp(
                    builder: media,
                    home: Scaffold(body: view),
                  ),
          );
          await tester.pumpAndSettle();
          final owner = model.activeOwner;
          await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
          await tester.pumpAndSettle();
          final command = find.byWidgetPredicate(
            (w) => w is EditableText && !w.readOnly,
          );
          await tester.enterText(command, 'Owned sessions');
          await tester.pumpAndSettle();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          final unknown = find.byKey(const ValueKey('owned-session:s7'));
          final label = find.textContaining('Production orphan · s7');
          expect(label, findsOneWidget);
          expect(tester.widget<Text>(label).data, contains('Outcome unknown'));
          expect(label.hitTestable(), findsOneWidget);
          final sessionList = find.ancestor(
            of: unknown,
            matching: find.byType(ListView),
          );
          final rows =
              (tester.widget<ListView>(sessionList).childrenDelegate
                      as SliverChildListDelegate)
                  .children;
          expect(rows.take(3).map((row) => row.key), [
            const ValueKey('owned-session:s7'),
            const ValueKey('owned-session:s6'),
            const ValueKey('owned-session:s5'),
          ]);
          // The complete uncertainty explanation can fill the viewport at
          // large text sizes. Other sessions remain reachable by scrolling.
          final failed = find.byKey(const ValueKey('owned-session:s6'));
          await tester.scrollUntilVisible(
            failed,
            120,
            scrollable: find.descendant(
              of: sessionList,
              matching: find.byType(Scrollable),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Idle connection 6 · s6').hitTestable(),
            findsOneWidget,
          );
          expect(model.activeOwner, same(owner));
          expect(model.document.sessionId, isNull);
          expect(model.sessions.length, 8);
          expect(backend.client.executions, isEmpty);
          expect(backend.client.opened, isEmpty);
          final close = find.text('Close').hitTestable();
          await tester.tap(close);
          await tester.pumpAndSettle();
          expect(
            model.sessions['s7']!.transaction,
            rpc.TransactionState.UNKNOWN_TRANSACTION,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeMenus = MethodChannel('busydata/native_menus');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          nativeMenus,
          (_) async => throw MissingPluginException(),
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeMenus, null),
  );
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} Problems uses original job targets and restores historical output',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('problems-'),
        ))!;
        final backend = TestBackend();
        final model = (await tester.runAsync(() async => WorkbenchModel(root)))!
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: 'SELECT original_history;');
        final a = model.activeOwner;
        final old = rpc.JobInfo(
          jobId: 'old',
          executionId: 'old',
          state: rpc.JobState.COMPLETED,
          results: [
            rpc.StatementResult(
              resultId: 'old-result',
              complete: true,
              fetchedRows: Int64.ONE,
              columns: [rpc.Column(name: 'evidence', typeName: 'integer')],
            ),
          ],
        );
        model.track(old, documentId: a.id);
        model.cache['old-result:0'] = rpc.Row(
          values: [rpc.Value(signedInteger: '7331')],
        );
        model.newDocument(text: 'SELECT independent;');
        final b = model.activeOwner;
        final failed = rpc.JobInfo(
          jobId: 'problem',
          executionId: 'problem-execution',
          state: rpc.JobState.FAILED,
          target: rpc.Profile(
            name: 'Original production',
            host: 'captured-endpoint',
            environment: rpc.Environment.PRODUCTION,
          ),
          messages: ['Actual SQLSTATE 23505'],
        );
        final unknown = rpc.JobInfo(
          jobId: 'unknown',
          executionId: 'unknown-execution',
          state: rpc.JobState.UNKNOWN_OUTCOME,
          target: rpc.Profile(name: 'Unknown original target'),
          messages: ['May have completed; do not replay'],
        );
        model.track(failed, documentId: b.id);
        model.track(unknown, documentId: b.id);
        model.track(
          rpc.JobInfo(
            jobId: 'cancelled',
            executionId: 'cancelled',
            state: rpc.JobState.CANCELLED,
            messages: ['Excluded cancelled evidence'],
          ),
          documentId: b.id,
        );
        model.sessions['orphan'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'orphan',
          transaction: rpc.TransactionState.UNKNOWN_TRANSACTION,
          profile: rpc.Profile(
            name: 'Orphan production',
            environment: rpc.Environment.PRODUCTION,
          ),
        );
        model.activateOwner(a.id);
        final resultView = model.resultView('old-result', owner: a)
          ..selectedColumn = 0;
        await tester.binding.setSurfaceSize(const Size(900, 600));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: WorkbenchView(model: model, controls: controls),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        final initialError = tester.takeException();
        expect(initialError, isNull, reason: initialError?.toString());
        expect(find.text('Outcome unknown 1'), findsOneWidget);
        expect(find.text('7331'), findsOneWidget);
        expect(
          tester
              .getSemantics(find.byKey(ValueKey('document-tab:${b.id}')))
              .label,
          contains('Outcome unknown'),
        );
        await tester.tap(find.text('Jobs 0'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Problems 2'));
        await tester.pumpAndSettle();
        expect(
          (model.globalToolOwner!.payload as GlobalToolData).kind,
          GlobalToolKind.problems,
        );
        expect(find.text('7331'), findsNothing);
        expect(find.text('Actual SQLSTATE 23505'), findsOneWidget);
        expect(
          find.textContaining(
            'Original production · Production · captured-endpoint',
          ),
          findsOneWidget,
        );
        expect(find.text('Excluded cancelled evidence'), findsNothing);
        expect(model.activeOwner, same(a));
        expect(model.currentResult!.resultId, 'old-result');
        expect(model.resultView('old-result', owner: a), same(resultView));
        await tester.tap(find.bySemanticsLabel('Close Problems'));
        await tester.pumpAndSettle();
        expect(model.globalToolOwner, isNull);
        expect(find.text('7331'), findsOneWidget);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.sessionCommands, isEmpty);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );

    for (final stale in [false, true]) {
      testWidgets(
        '${controls.runtimeType} physical disconnect ${stale ? "rejects changed context" : "keeps the selected orphan target"} through confirmation',
        (tester) async {
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('disconnect-ui-'),
          ))!;
          final backend = TestBackend();
          final model =
              (await tester.runAsync(() async => WorkbenchModel(root)))!
                ..draftRecovery = false
                ..backend = backend
                ..newDocument(text: 'SELECT unrelated;');
          model.sessions['orphan'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'orphan',
            transaction: rpc.TransactionState.UNKNOWN_TRANSACTION,
            profile: rpc.Profile(
              id: 'original',
              name: 'Original production',
              host: 'captured-endpoint',
              environment: rpc.Environment.PRODUCTION,
            ),
          );
          backend.client.sessionCommand = (request) async => rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: request.sessionId,
            profile: model.sessions[request.sessionId]!.profile,
            transaction: rpc.TransactionState.DISCONNECTED,
          );
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final view = WorkbenchView(model: model, controls: controls);
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(home: Scaffold(body: view)),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Outcome unknown 1'));
          await tester.pumpAndSettle();
          expect(find.text('Owned sessions'), findsOneWidget);
          await tester.tap(find.text('Disconnect'));
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              'Original production · Production · captured-endpoint',
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining('Unknown outcomes remain unknown'),
            findsOneWidget,
          );
          expect(backend.client.sessionCommands, isEmpty);
          if (stale) {
            model.sessions['orphan'] = model.sessions['orphan']!.deepCopy()
              ..contextRevision = Int64.ONE;
          } else {
            model.newDocument(text: 'SELECT another;');
          }
          await tester.tap(find.text('Disconnect').last);
          await tester.pumpAndSettle();
          if (stale) {
            expect(backend.client.sessionCommands, isEmpty);
            expect(model.sessions, contains('orphan'));
            expect(
              find.textContaining('execution context changed'),
              findsWidgets,
            );
          } else {
            expect(backend.client.sessionCommands.single.sessionId, 'orphan');
            expect(backend.client.sessionCommands.single.force, isTrue);
            expect(model.sessions, isEmpty);
            expect(model.document.editor.text, 'SELECT another;');
            expect(model.document.sessionId, isNull);
          }
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
