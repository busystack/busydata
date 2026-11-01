import 'dart:io';
import 'dart:ui' as ui;
import 'package:fixnum/fixnum.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/activity_view.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} activity inspection retains scroll and selection at 200% RTL without refresh on reopening',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('activity-scroll-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..backend = backend
          ..draftRecovery = false
          ..newDocument();
        model.document.sessionId = 'source';
        model.sessions['source'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'source',
        );
        backend.client.activityAction = (_) async => ActivityList(
          entries: List.generate(
            100,
            (i) => Activity(
              id: Int64(i + 1),
              principal: 'Long translated principal $i',
              database: 'database',
              state: 'active',
              queryPreview: 'SELECT captured_$i',
              fingerprint: '$i'.padLeft(64, 'a'),
              cancellable: true,
            ),
          ),
        );
        final inspection = ActivityInspectionState();
        final target = model.captureTarget();
        await tester.binding.setSurfaceSize(const Size(900, 600));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        Future<void> show() async {
          final view = MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              highContrast: true,
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: ActivityView(
                model: model,
                target: target,
                controls: controls,
                inspection: inspection,
                action: (_, _) async {},
              ),
            ),
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: view)
                : MaterialApp(home: Scaffold(body: view)),
          );
          await tester.pumpAndSettle();
        }

        await show();
        expect(tester.takeException(), isNull);
        final row = find.byWidgetPredicate(
          (w) =>
              w is WorkbenchRecord &&
              w.label ==
                  '90 · Long translated principal 89 · database · active · ',
        );
        final bodyScroll = find
            .descendant(
              of: find.byType(ActivityView),
              matching: find.byType(Scrollable),
            )
            .first;
        await tester.scrollUntilVisible(
          row,
          400,
          scrollable: bodyScroll,
          maxScrolls: 60,
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        final selectedOffset = tester
            .state<ScrollableState>(bodyScroll)
            .position
            .pixels;
        final visibleOrder = tester
            .widgetList<WorkbenchRecord>(find.byType(WorkbenchRecord))
            .map((record) => record.label)
            .toList();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(bodyScroll).position.pixels,
          selectedOffset,
          reason: 'Selecting an activity must not jump to the first record',
        );
        expect(
          tester
              .widgetList<WorkbenchRecord>(find.byType(WorkbenchRecord))
              .map((record) => record.label)
              .toList(),
          visibleOrder,
          reason: 'Selection preserves the current virtualized record order',
        );
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is WorkbenchRecord &&
                w.label.startsWith('90 · Long translated principal 89'),
          ),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('SELECT captured_89'),
          100,
          scrollable: bodyScroll,
        );
        await tester.pumpAndSettle();
        final offset = tester
            .state<ScrollableState>(bodyScroll)
            .position
            .pixels;
        expect(offset, greaterThan(0));
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(inspection.selected!.id.toInt(), 90);
        expect(inspection.scrollOffset, offset);
        await show();
        expect(
          tester.state<ScrollableState>(bodyScroll).position.pixels,
          offset,
        );
        expect(backend.client.activityRequests, hasLength(1));
        expect(backend.client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${controls.runtimeType} activity actions use the selected live fingerprint and blockers',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-activity-ui-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..backend = backend
          ..draftRecovery = false
          ..newDocument();
        model.document.sessionId = 'source';
        model.sessions['source'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'source',
        );
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        var generation = 0;
        Activity? acted;
        backend.client.activityAction = (_) async => ActivityList(
          entries: [
            Activity(
              id: Int64(5),
              principal: 'user',
              database: 'database',
              state: 'blocked',
              queryPreview: 'SELECT exact_target',
              fingerprint: 'a' * 64,
              cancellable: true,
              blockers: [Int64(6)],
            ),
            Activity(
              id: Int64(6),
              principal: 'blocker',
              database: 'database',
              state: 'active',
              queryPreview: 'UPDATE exact_row',
              fingerprint: (generation == 0 ? 'b' : 'c') * 64,
              cancellable: true,
            ),
          ],
        );
        final view = SizedBox(
          width: 800,
          height: 550,
          child: ActivityView(
            model: model,
            target: model.captureTarget(),
            controls: controls,
            action: (value, terminate) async => acted = value,
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        expect(backend.client.activityRequests.single.sessionId, 'source');
        final filterSemantics = tester
            .getSemantics(find.byType(EditableText))
            .getSemanticsData();
        expect(filterSemantics.label, 'Filter current activities');
        expect(filterSemantics.flagsCollection.isTextField, isTrue);
        expect(filterSemantics.flagsCollection.isReadOnly, isFalse);
        final activityNode = tester.getSemantics(
          find.byWidgetPredicate(
            (w) =>
                w is WorkbenchRecord &&
                w.label == '5 · user · database · blocked · ',
          ),
        );
        expect(
          activityNode.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(
          activityNode.getSemanticsData().hasAction(ui.SemanticsAction.focus),
          isTrue,
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: activityNode.id,
            type: ui.SemanticsAction.focus,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          activityNode.getSemanticsData().flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: activityNode.id,
            type: ui.SemanticsAction.tap,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('SELECT exact_target'), findsOneWidget);
        final querySemantics = tester
            .getSemantics(find.text('SELECT exact_target'))
            .getSemanticsData();
        expect(querySemantics.flagsCollection.isTextField, isTrue);
        expect(querySemantics.flagsCollection.isReadOnly, isTrue);
        expect(querySemantics.label, 'SQL');
        expect(querySemantics.value, 'SELECT exact_target');
        expect(
          tester
              .getSemantics(
                find.byWidgetPredicate(
                  (w) =>
                      w is WorkbenchRecord &&
                      w.label == '5 · user · database · blocked · ',
                ),
              )
              .getSemanticsData()
              .flagsCollection
              .isSelected,
          ui.Tristate.isTrue,
        );
        await tester.enterText(
          find.byWidgetPredicate((w) => w is EditableText && !w.readOnly),
          'exact_target',
        );
        await tester.pumpAndSettle();
        expect(find.text('UPDATE exact_row'), findsNothing);
        await tester.tap(find.text('6'));
        await tester.pumpAndSettle();
        expect(find.text('UPDATE exact_row'), findsOneWidget);
        expect(
          tester
              .widget<EditableText>(
                find
                    .byWidgetPredicate((w) => w is EditableText && !w.readOnly)
                    .first,
              )
              .controller
              .text,
          isEmpty,
        );
        await tester.tap(find.text('Cancel selected activity'));
        await tester.pumpAndSettle();
        expect(acted!.id.toInt(), 6);
        expect(acted!.fingerprint, 'b' * 64);
        expect(acted!.queryPreview, 'UPDATE exact_row');
        final requests = backend.client.activityRequests.length;
        acted = null;
        await tester.enterText(
          find.byWidgetPredicate((w) => w is EditableText && !w.readOnly),
          'exact_target',
        );
        await tester.pumpAndSettle();
        final populatedFilter = tester
            .getSemantics(
              find.byWidgetPredicate((w) => w is EditableText && !w.readOnly),
            )
            .getSemanticsData();
        expect(populatedFilter.label, 'Filter current activities');
        expect(populatedFilter.value, 'exact_target');
        expect(populatedFilter.flagsCollection.isTextField, isTrue);
        expect(find.textContaining('6 · blocker'), findsNothing);
        await tester.tap(find.text('Cancel selected activity'));
        await tester.pumpAndSettle();
        expect(acted, isNull);
        expect(backend.client.activityRequests.length, requests);
        expect(backend.client.executions, isEmpty);
        await tester.enterText(
          find.byWidgetPredicate((w) => w is EditableText && !w.readOnly),
          '',
        );
        await tester.pumpAndSettle();
        generation++;
        await tester.tap(find.text('Refresh activities'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('selected activity ended or changed'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
