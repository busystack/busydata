import 'dart:io';
import 'dart:ui' as dart_ui;
import 'package:busydata/src/app/busydata_design.dart'
    show BusyDataPopupSelector, busyDataSelectedValueLabel;
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/plan_view.dart';
import 'package:busydata/src/platform/native_menu_service.dart';
import 'support/fake_backend.dart';
import 'package:busydata/src/ui/common/workspace_divider.dart';
import 'package:busydata/src/ui/common/workspace_content_layout.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window'),
      (call) async => call.method == 'state' ? <String, Object?>{} : null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('yaru_window/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window'),
      null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('yaru_window/events'),
      null,
    );
  });
  testWidgets('fractional pane minima keep feasible layout bounds', (
    tester,
  ) async {
    const editorKey = ValueKey('fractional-editor');
    const resultKey = ValueKey('fractional-result');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 300,
            height: 180.3,
            child: WorkspaceContentLayout(
              minimumEditorExtent: 41.32,
              minimumResultExtent: 230.6,
              children: [
                Expanded(flex: 556, child: SizedBox(key: editorKey)),
                Expanded(flex: 444, child: SizedBox(key: resultKey)),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final editor = tester.getRect(find.byKey(editorKey));
    final result = tester.getRect(find.byKey(resultKey));
    expect(editor.height, closeTo(41.32, .000001));
    expect(result.height, closeTo(138.98, .000001));
    expect(editor.bottom, closeTo(result.top, .000001));
  });
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${controls.runtimeType} attached plan keeps an operator visible at 900×600 and $scale text',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('plan-layout-'),
          ))!;
          final backend = TestBackend();
          final model = WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: 'SELECT original_sql');
          final owner = model.activeOwner;
          final result = rpc.StatementResult(
            resultId: 'plan',
            plan: true,
            complete: true,
            fetchedRows: Int64.ONE,
          );
          model.track(
            rpc.JobInfo(
              jobId: 'plan-job',
              executionId: 'plan-execution',
              state: rpc.JobState.COMPLETED,
              results: [result],
            ),
            documentId: owner.id,
          );
          final data = PlanData.parse(
            '{"Plan":{"Node Type":"Index Scan","Plan Rows":2}}',
          );
          model.reserveResultEvidence(owner, result.resultId, 200);
          owner.view.results[result.resultId]!.planEvidence = data;
          owner.view.output = 'plan';
          model.retainedResults[result.resultId] = rpc.RetainedResult(
            result: result,
            target: rpc.Profile(
              name: 'Original target',
              environment: rpc.Environment.PRODUCTION,
            ),
            sqlProvenance: rpc.Value(text: 'EXPLAIN SELECT original_sql'),
          );
          await tester.binding.setSurfaceSize(const Size(900, 600));
          final view = MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: scale == 2 ? TextDirection.rtl : TextDirection.ltr,
              child: WorkbenchView(model: model, controls: controls),
            ),
          );
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
          expect(tester.takeException(), isNull);
          final operator = find.bySemanticsLabel(RegExp('^Level 1, Plan'));
          expect(operator, findsOneWidget);
          final rect = tester.getRect(operator);
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.bottom, lessThanOrEqualTo(600));
          expect(rect.height, greaterThanOrEqualTo(32));
          expect(backend.client.executions, isEmpty);
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          semantics.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        },
      );
    }
    for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
      testWidgets(
        '${controls.runtimeType} 200% ${direction.name} keeps real headers/cells and scaled controls in their viewports',
        (tester) async {
          final semantics = tester.ensureSemantics();
          var semanticsDisposed = false;
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('busydata-scaled-layout-'),
          ))!;
          final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
            ..draftRecovery = false
            ..newDocument(
              text: 'SELECT id,n FROM native_atspi_fixture ORDER BY id;',
            );
          model.document.sessionId = 'live-session';
          model.sessions['live-session'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'live-session',
            profile: rpc.Profile(
              name: 'Native accessibility fixture',
              host: '127.0.0.1',
              port: 32843,
              database: 'busydata',
              environment: rpc.Environment.DEVELOPMENT,
            ),
            currentCatalog: 'busydata',
            currentSchema: 'public',
            transaction: rpc.TransactionState.IDLE,
            autoCommit: true,
          );
          final result = rpc.StatementResult(
            resultId: 'scaled-result',
            fetchedRows: Int64(2),
            complete: true,
            columns: [
              rpc.Column(name: 'id', typeName: 'bigint'),
              rpc.Column(name: 'n', typeName: 'text'),
            ],
          );
          model.jobs['job'] = rpc.JobInfo(
            jobId: 'job',
            executionId: 'execution',
            sessionId: 'live-session',
            state: rpc.JobState.COMPLETED,
            durationMs: Int64(146),
            results: [result],
            messages: [
              'PostgreSQL auto-commit uses bounded row count, not cursor streaming. Choose streaming read for large SELECTs.',
            ],
          );
          model.jobDocuments['job'] = model.document.id;
          model.latestExecutions[model.document.id] = 'execution';
          model.cache['scaled-result:0'] = rpc.Row(
            values: [
              rpc.Value(signedInteger: '101'),
              rpc.Value(text: 'first 漢😀'),
            ],
          );
          model.cache['scaled-result:1'] = rpc.Row(
            values: [
              rpc.Value(signedInteger: '202'),
              rpc.Value(text: 'second exact'),
            ],
          );
          model.updateStatus('Completed execution · selected database target');
          await tester.binding.setSurfaceSize(const Size(980, 674));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            if (!semanticsDisposed) semantics.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final view = MediaQuery(
            data: const MediaQueryData(
              size: Size(980, 674),
              textScaler: TextScaler.linear(2),
              highContrast: true,
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: direction,
              child: WorkbenchView(model: model, controls: controls),
            ),
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(
                    theme: BusyDataYaruTheme.build(
                      brightness: direction == TextDirection.rtl
                          ? Brightness.dark
                          : Brightness.light,
                      accentColor: const Color(0xffe95420),
                    ),
                    home: Scaffold(body: view),
                  ),
          );
          await tester.pumpAndSettle();
          final table = find.byType(TableView);
          expect(table, findsOneWidget);
          final first = find.bySemanticsLabel('Row 1, id: 101');
          final header = find.bySemanticsLabel('Column id · bigint');
          expect(
            first,
            findsOneWidget,
            reason:
                'Completed server-retained data must have an actual visible viewport',
          );
          expect(header, findsOneWidget);
          final tableRect = tester.getRect(table);
          expect(tableRect.height, greaterThanOrEqualTo(80));
          expect(tableRect.contains(tester.getCenter(first)), isTrue);
          expect(tableRect.contains(tester.getCenter(header)), isTrue);
          expect(
            tester
                .getRect(
                  find.text('Completed execution · selected database target'),
                )
                .top,
            greaterThanOrEqualTo(tableRect.bottom),
          );
          final gridMenu = find.text('Data grid').evaluate().isNotEmpty
              ? find.text('Data grid')
              : find.descendant(of: table, matching: find.text('More'));
          expect(gridMenu, findsOneWidget);
          final target = tester.getSemantics(
            find.byKey(const ValueKey('live-workbench-target')),
          );
          expect(
            target.getSemanticsData().flagsCollection.isLiveRegion,
            isTrue,
          );
          expect(target.getSemanticsData().label, contains('127.0.0.1:32843'));
          Future<void> outputPage(String page) async {
            if (controls is WindowsControls &&
                find.text(page).evaluate().isNotEmpty) {
              await tester.tap(find.text(page));
            } else {
              const channel = MethodChannel(nativeMenuChannelName);
              if (controls is LinuxControls) {
                TestDefaultBinaryMessengerBinding
                    .instance
                    .defaultBinaryMessenger
                    .setMockMethodCallHandler(channel, (call) async {
                      if (call.method != 'show') return null;
                      final entries =
                          (call.arguments as Map)['entries'] as List;
                      final selected = entries.indexWhere(
                        (entry) => (entry as Map)['label'] == page,
                      );
                      expect(selected, greaterThanOrEqualTo(0));
                      return selected;
                    });
              }
              final options = controls is LinuxControls
                  ? find.byKey(const ValueKey('execution-output-selector'))
                  : find.bySemanticsLabel('Execution options');
              expect(options, findsOneWidget);
              var actionableOptions = options;
              if (controls is LinuxControls) {
                final selector = tester.widget<BusyDataPopupSelector<String>>(
                  find.descendant(
                    of: options,
                    matching: find.byType(BusyDataPopupSelector<String>),
                  ),
                );
                final selectedLabel = busyDataSelectedValueLabel(
                  selector.tooltip,
                  selector.label,
                );
                actionableOptions = find.descendant(
                  of: options,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Semantics &&
                        widget.properties.label == selectedLabel &&
                        widget.properties.button == true,
                  ),
                );
                expect(actionableOptions, findsOneWidget);
                final data = tester
                    .getSemantics(actionableOptions)
                    .getSemanticsData();
                expect(data.label, selectedLabel);
                expect(data.flagsCollection.isButton, isTrue);
                expect(data.flagsCollection.isHidden, isFalse);
                expect(
                  data.flagsCollection.isFocused,
                  isNot(dart_ui.Tristate.none),
                );
                expect(data.flagsCollection.isEnabled, dart_ui.Tristate.isTrue);
                expect(
                  tester
                      .getRect(find.byType(WorkbenchView))
                      .contains(tester.getCenter(actionableOptions)),
                  isTrue,
                );
              }
              expect(
                tester
                    .getSemantics(actionableOptions)
                    .getSemanticsData()
                    .hasAction(dart_ui.SemanticsAction.tap),
                isTrue,
              );
              await tester.tap(actionableOptions);
              await tester.pumpAndSettle();
              if (controls is WindowsControls) {
                await tester.tap(find.text(page));
              } else {
                TestDefaultBinaryMessengerBinding
                    .instance
                    .defaultBinaryMessenger
                    .setMockMethodCallHandler(channel, null);
              }
            }
            await tester.pumpAndSettle();
          }

          await outputPage('Messages');
          final notice = find.textContaining(
            'PostgreSQL auto-commit uses bounded row count',
          );
          expect(notice, findsOneWidget);
          expect(
            tester.widget<EditableText>(notice).maxLines,
            isNull,
            reason:
                'All notices remain available through the bounded scrollable message area',
          );
          await outputPage('Results 1');
          final divider = find.byType(WorkspaceDivider);
          final mouse = find
              .descendant(of: divider, matching: find.byType(MouseRegion))
              .first;
          final initialFraction = model.editorFraction;
          Focus.of(tester.element(mouse)).requestFocus();
          await tester.pump();
          for (var index = 0; index < 5; index++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
            await tester.pump();
          }
          expect(model.editorFraction, closeTo(initialFraction - .25, .00001));
          await tester.tap(first);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          final second = find.bySemanticsLabel('Row 2, id: 202');
          expect(second, findsOneWidget);
          expect(
            tester.getRect(table).contains(tester.getCenter(second)),
            isTrue,
          );
          expect(
            tester
                .getSemantics(second)
                .getSemanticsData()
                .flagsCollection
                .isFocused,
            dart_ui.Tristate.isTrue,
          );
          expect(
            model.resultView(model.displayResult!.resultId).selectedRow,
            1,
          );
          expect(tester.takeException(), isNull);

          // A second completed execution adds the retained-job selector after
          // the editor and tools already have established layout positions.
          final plan = rpc.StatementResult(
            resultId: 'scaled-plan',
            fetchedRows: Int64(2),
            complete: true,
            columns: [rpc.Column(name: 'QUERY PLAN', typeName: 'text')],
          );
          model.jobs['second-job'] = rpc.JobInfo(
            jobId: 'second-job',
            executionId: 'latest-execution',
            sessionId: 'live-session',
            state: rpc.JobState.COMPLETED,
            durationMs: Int64(27),
            results: [plan],
          );
          model.jobDocuments['second-job'] = model.document.id;
          model.latestExecutions[model.document.id] = 'latest-execution';
          model.cache['scaled-plan:0'] = rpc.Row(
            values: [rpc.Value(text: 'Index Scan using fixture_pk')],
          );
          model.cache['scaled-plan:1'] = rpc.Row(
            values: [rpc.Value(text: 'Planning Time: 0.25 ms')],
          );
          model.updateStatus(
            'Completed second execution · exact current target',
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final planCell = find.bySemanticsLabel(
            'Row 1, QUERY PLAN: Index Scan using fixture_pk',
          );
          final planHeader = find.bySemanticsLabel('Column QUERY PLAN · text');
          expect(planCell, findsOneWidget);
          expect(planHeader, findsOneWidget);
          var currentTable = tester.getRect(find.byType(TableView));
          expect(currentTable.height, greaterThanOrEqualTo(80));
          expect(currentTable.contains(tester.getCenter(planCell)), isTrue);
          expect(currentTable.contains(tester.getCenter(planHeader)), isTrue);
          // Prior executions are reachable through the output menu, leaving
          // the result viewport available at large text sizes.
          const menuLabel = 'Execution options';
          final outputMenu = controls is WindowsControls
              ? find.widgetWithText(fluent.DropDownButton, menuLabel)
              : find.byTooltip(menuLabel);
          expect(outputMenu, findsOneWidget);
          expect(
            tester
                .getRect(find.byType(WorkbenchView))
                .contains(tester.getCenter(outputMenu)),
            isTrue,
          );
          expect(
            tester
                .getRect(
                  find.text(
                    'Completed second execution · exact current target',
                  ),
                )
                .top,
            greaterThanOrEqualTo(currentTable.bottom),
          );
          await tester.tap(planCell);
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          final secondPlanCell = find.bySemanticsLabel(
            'Row 2, QUERY PLAN: Planning Time: 0.25 ms',
          );
          expect(secondPlanCell, findsOneWidget);
          expect(
            tester
                .getRect(find.byType(TableView))
                .contains(tester.getCenter(secondPlanCell)),
            isTrue,
          );
          expect(
            model.resultView(model.displayResult!.resultId).selectedRow,
            1,
          );

          // The same retained execution can contain multiple result sets.
          // The second selector must preserve both native controls and the
          // selected real plan rather than starving or overlaying its grid.
          final other = rpc.StatementResult(
            resultId: 'scaled-other',
            statementIndex: 1,
            fetchedRows: Int64(1),
            complete: true,
            columns: [rpc.Column(name: 'value', typeName: 'text')],
          );
          model.jobs['second-job'] =
              model.jobs['second-job']!.toBuilder() as rpc.JobInfo
                ..results.add(other);
          model.selectedResults[model.document.id] = 'scaled-plan';
          model.cache['scaled-other:0'] = rpc.Row(
            values: [rpc.Value(text: 'retained exact 漢😀')],
          );
          model.updateStatus('Showing retained result · no SQL rerun');
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          currentTable = tester.getRect(find.byType(TableView));
          expect(currentTable.height, greaterThanOrEqualTo(80));
          expect(planCell, findsOneWidget);
          expect(currentTable.contains(tester.getCenter(planCell)), isTrue);
          final retainedSelector = find.text('Results 1');
          expect(retainedSelector, findsOneWidget);
          expect(
            tester
                .getRect(find.byType(WorkbenchView))
                .contains(tester.getCenter(retainedSelector)),
            isTrue,
          );
          expect(
            tester
                .getRect(find.text('Showing retained result · no SQL rerun'))
                .top,
            greaterThanOrEqualTo(currentTable.bottom),
          );
          model.selectedResults[model.document.id] = 'scaled-other';
          model.updateStatus('Showing second retained set · no SQL rerun');
          await tester.pumpAndSettle();
          final otherCell = find.bySemanticsLabel(
            'Row 1, value: retained exact 漢😀',
          );
          expect(otherCell, findsOneWidget);
          expect(
            tester
                .getRect(find.byType(TableView))
                .contains(tester.getCenter(otherCell)),
            isTrue,
          );
          model.selectExecution('execution');
          await tester.pumpAndSettle();
          expect(first, findsOneWidget);
          expect(
            tester
                .getRect(find.byType(TableView))
                .contains(tester.getCenter(first)),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          semantics.dispose();
          semanticsDisposed = true;
        },
      );
    }
  }
}
