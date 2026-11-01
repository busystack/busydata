import 'package:busydata/src/ui/common/history_view.dart';
import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

class HistoryRouteObserver extends NavigatorObserver {
  int pops = 0;
  Route<dynamic>? applicationRoute;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == '/') applicationRoute = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (identical(route, applicationRoute)) pops++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const menus = MethodChannel('busydata/native_menus');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          menus,
          (_) async => throw MissingPluginException(),
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(menus, null),
  );
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final stale in [false, true]) {
      testWidgets(
        '${ui.runtimeType} history ${stale ? "rejects stale backend text" : "reopens disconnected SQL without popping the application"}',
        (tester) async {
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('busydata-history-'),
          ))!;
          final model = (await tester.runAsync(
            () async => WorkbenchModel(root),
          ))!;
          model.draftRecovery = false;
          model.newDocument(text: '-- existing unsaved SQL');
          final source = model.document;
          final originalUnits = model.documentBudget.units;
          final backend = TestBackend();
          final text = Completer<rpc.HistorySqlChunk>();
          backend.client.historyCatalog = (_) async => rpc.HistoryList(
            retainSql: false,
            retentionDays: 30,
            entries: [
              rpc.HistoryEntry(
                id: 'entry-1',
                target: 'Original production / public',
                state: rpc.JobState.COMPLETED,
                startedUnixMs: Int64(1000),
              ),
            ],
          );
          backend.client.historyText = (_) => text.future;
          model.backend = backend;
          final owner = WorkbenchDocument(
            id: 'global:history',
            kind: WorkbenchDocumentKind.administration,
            title: 'History',
            payload: GlobalToolData(GlobalToolKind.history),
          );
          model.showGlobalTool(owner);
          final observer = HistoryRouteObserver();
          final tool = Center(
            child: SizedBox(
              width: 620,
              height: 190,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: WorkbenchDocumentView(
                  model: model,
                  owner: owner,
                  controls: ui,
                ),
              ),
            ),
          );
          await tester.binding.setSurfaceSize(const Size(1000, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          addTearDown(() async {
            model.dispose();
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final app = ui is WindowsControls
              ? fluent.FluentApp(
                  navigatorObservers: [observer],
                  home: fluent.ScaffoldPage(content: tool),
                )
              : MaterialApp(
                  navigatorObservers: [observer],
                  home: Scaffold(body: tool),
                );
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();
          expect(observer.applicationRoute, isNotNull);
          expect(tester.takeException(), isNull);
          expect(backend.client.historyRequests.single.limit, 50);
          expect(model.documentBudget.units, greaterThan(originalUnits));
          expect(find.text('Search SQL or target'), findsNothing);
          // This focused view test exercises the reused query operation. The
          // global header/category route is covered by the shell/search suite.
          final historyState = tester.state<HistoryViewState>(
            find.byType(HistoryView),
          );
          historyState.search.text = 'Original';
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pumpAndSettle();
          expect(backend.client.historyRequests.last.search, 'Original');
          await tester.scrollUntilVisible(
            find.textContaining('Original production / public'),
            50,
            scrollable: find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Original production / public'),
            findsOneWidget,
          );
          await tester.tapAt(
            tester.getTopLeft(
                  find.textContaining('Original production / public'),
                ) +
                const Offset(4, 4),
          );
          await tester.pumpAndSettle();
          // Unmounting the view releases widgets, while its model preserves the
          // fetched page and selection. No second history request is required.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(app);
          await tester.pumpAndSettle();
          expect(backend.client.historyRequests, hasLength(2));
          expect((owner.payload as GlobalToolData).history.selected, 'entry-1');
          await tester.tap(find.text('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open as new SQL tab').last);
          await tester.pump();
          expect(backend.client.historySqlRequests.single.entryId, 'entry-1');
          if (stale) {
            model.backend = TestBackend(instanceId: 'replacement-backend');
          }
          text.complete(
            rpc.HistorySqlChunk(
              text: 'SELECT "never executed";',
              totalUnits: 24,
              complete: true,
            ),
          );
          await tester.pumpAndSettle();
          if (stale) {
            expect(model.documents, [source]);
            expect(find.textContaining('Backend changed'), findsOneWidget);
            expect(model.globalToolOwner, same(owner));
          } else {
            expect(model.documents, hasLength(2));
            expect(model.document.editor.text, 'SELECT "never executed";');
            expect(model.document.sessionId, isNull);
            expect(model.document.dirty, isTrue);
            expect(model.globalToolOwner, isNull);
            expect(
              model.documentBudget.units,
              originalUnits +
                  model.document.editor.text.length +
                  model.document.savedText.length,
            );
          }
          expect(source.editor.text, '-- existing unsaved SQL');
          expect(backend.client.executions, isEmpty);
          expect(backend.client.opened, isEmpty);
          expect(observer.pops, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
