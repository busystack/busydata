import 'dart:ui' as ui;
import 'dart:io';
import 'dart:math' as math;
import 'support/presentation_fonts.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/plan_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('plan disclosure keys follow ${direction.name}', (
      tester,
    ) async {
      final data = PlanData.parse('{"Plan":{"Node Type":"Result"}}');
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: direction,
            child: PlanView(data: data, controls: const LinuxControls()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final collapse = direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowLeft
          : LogicalKeyboardKey.arrowRight;
      final expand = direction == TextDirection.ltr
          ? LogicalKeyboardKey.arrowRight
          : LogicalKeyboardKey.arrowLeft;
      await tester.sendKeyEvent(collapse);
      await tester.pumpAndSettle();
      expect(data.collapsed.contains(0), isTrue);
      await tester.sendKeyEvent(expand);
      await tester.pumpAndSettle();
      expect(data.collapsed.contains(0), isFalse);
    });
  }

  setUpAll(loadPresentationFonts);
  for (final brightness in Brightness.values) {
    testWidgets(
      'selected branch icons follow ${brightness.name} high contrast selection and focus',
      (tester) async {
        const controls = LinuxControls();
        final data = PlanData.parse('{"Plan":{"Node Type":"Result"}}');
        final outside = FocusNode();
        addTearDown(outside.dispose);
        await tester.pumpWidget(
          presentationHost(
            Column(
              children: [
                TextField(focusNode: outside),
                Expanded(
                  child: PlanView(data: data, controls: controls),
                ),
              ],
            ),
            brightness: brightness,
            contrast: true,
          ),
        );
        await tester.pumpAndSettle();
        final row = find.bySemanticsLabel(RegExp('^Level 1, Plan'));
        await tester.tap(row); // select the branch and collapse it
        await tester.pumpAndSettle();
        void verify({required bool focused, required bool collapsed}) {
          final context = tester.element(row);
          final look = controls.appearance(context);
          final fg = look.rowForeground(selected: true, focused: focused);
          final bg = look.rowBackground(selected: true, focused: focused);
          final icon = find
              .descendant(of: row, matching: find.byType(Icon))
              .first;
          expect(IconTheme.of(tester.element(icon)).color, fg);
          expect(
            tester
                .widget<Text>(
                  find.descendant(of: row, matching: find.text('Plan')),
                )
                .style!
                .color,
            fg,
          );
          final a = fg.computeLuminance(), b = bg.computeLuminance();
          expect(
            (math.max(a, b) + .05) / (math.min(a, b) + .05),
            greaterThanOrEqualTo(4.5),
          );
          final paint = tester.widget<Container>(
            find
                .descendant(
                  of: row,
                  matching: find.byWidgetPredicate(
                    (w) => w is Container && w.decoration is BoxDecoration,
                  ),
                )
                .first,
          );
          expect((paint.decoration! as BoxDecoration).color, bg);
          expect(data.collapsed.contains(0), collapsed);
        }

        verify(focused: true, collapsed: true);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        verify(focused: true, collapsed: false);
        final ordinary = find.bySemanticsLabel(RegExp('^Level 2, Plan'));
        final ordinaryIcon = find
            .descendant(of: ordinary, matching: find.byType(Icon))
            .first;
        expect(
          IconTheme.of(tester.element(ordinaryIcon)).color,
          controls.appearance(tester.element(ordinary)).foreground,
        );
        outside.requestFocus();
        await tester.pumpAndSettle();
        verify(focused: false, collapsed: false);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('plans preserve server estimates, actuals, Unicode and raw text', () {
    const raw =
        '[{"Plan":{"Node Type":"Seq Scan","Relation Name":"漢","Plan Rows":12,"Actual Rows":7,"Plans":[{"Node Type":"Result"}]}}]';
    final plan = PlanData.parse(raw);
    expect(plan.raw, raw);
    expect(
      plan.entries.map((e) => e.label),
      containsAll(['Plan Rows: 12', 'Actual Rows: 7', 'Relation Name: 漢']),
    );
    final text = PlanData.parse(
      '-> Limit: 10 row(s) (cost=2 rows=10) (actual time=1..2 rows=7 loops=1)\n    -> Table scan on 漢 (cost=1 rows=12)\n',
    );
    expect(text.entries, hasLength(2));
    expect(text.entries.last.parent, 0);
    expect(text.entries.last.depth, 1);
  });
  test(
    'oversized/deep plans fail before an unbounded widget tree is created',
    () {
      expect(() => PlanData.parse('x' * 1048577), throwsStateError);
      expect(
        () => PlanData.parse('${'[' * 33}0${']' * 33}'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => PlanData.parse(List.generate(4097, (i) => '-> $i').join('\n')),
        throwsStateError,
      );
    },
  );
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} compact plan inspects original SQL and target without rerunning it',
      (tester) async {
        const channel = MethodChannel('busydata/native_menus');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              channel,
              (_) async => throw MissingPluginException(),
            );
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('compact-plan-'),
        ))!;
        final backend = TestBackend();
        final model = (await tester.runAsync(
          () async => WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(),
        ))!;
        model.document.profileId = 'different-active-target';
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final retained = rpc.RetainedResult(
          target: rpc.Profile(
            name: 'Original production',
            environment: rpc.Environment.PRODUCTION,
            host: 'original-host',
            port: 5543,
            database: 'original-db',
          ),
          sqlProvenance: rpc.Value(text: 'EXPLAIN SELECT original_sql'),
        );
        final content = MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 500,
              height: 190,
              child: PlanEvidenceView(
                model: model,
                data: PlanData.parse('{"Plan":{"Node Type":"Result"}}'),
                controls: controls,
                retained: retained,
              ),
            ),
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: content)
              : MaterialApp(home: Scaffold(body: content)),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('EXPLAIN SELECT original_sql'),
          findsNothing,
        );
        await tester.tap(
          find
              .byWidgetPredicate(
                (widget) =>
                    widget is Semantics &&
                    widget.properties.label == 'Plan details',
              )
              .first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('SQL provenance'));
        await tester.pumpAndSettle();
        expect(find.text('EXPLAIN SELECT original_sql'), findsOneWidget);
        expect(
          find.textContaining('Original production · Production'),
          findsOneWidget,
        );
        expect(
          find.textContaining('original-host:5543/original-db'),
          findsOneWidget,
        );
        expect(backend.client.executions, isEmpty);
        expect(backend.client.pageRequests, isEmpty);
        expect(model.document.profileId, 'different-active-target');
        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(find.text('EXPLAIN SELECT original_sql'), findsNothing);
        expect(find.bySemanticsLabel(RegExp('^Level 1, Plan')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${controls.runtimeType} plan exposes its focused original-evidence row to native readers',
      (tester) async {
        final semantics = tester.ensureSemantics();
        const nativeMenus = MethodChannel('busydata/native_menus');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeMenus,
          (_) async => throw MissingPluginException(),
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            nativeMenus,
            null,
          ),
        );
        final data = PlanData.parse(
          '{"Plan":{"Node Type":"Seq Scan","Actual Rows":7}}',
        );
        final view = SizedBox(
          width: 700,
          height: 500,
          child: PlanView(data: data, controls: controls),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        final root = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Level 1, Plan')),
        );
        expect(root.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          root.getSemanticsData().flagsCollection.isEnabled,
          ui.Tristate.isTrue,
        );
        expect(root.getSemanticsData().label, endsWith(', expanded'));
        expect(
          root.getSemanticsData().hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
        expect(
          root.getSemanticsData().hasAction(ui.SemanticsAction.focus),
          isTrue,
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: root.id,
            type: ui.SemanticsAction.focus,
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        final next = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Level 2, Plan')),
        );
        expect(
          next.getSemanticsData().flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        expect(
          next.getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        expect(
          root.getSemanticsData().flagsCollection.isFocused,
          ui.Tristate.isFalse,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      },
    );
    testWidgets(
      '${controls.runtimeType} plan tree supports keyboard folding and raw evidence',
      (tester) async {
        const nativeMenus = MethodChannel('busydata/native_menus');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeMenus,
          (_) async => throw MissingPluginException(),
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            nativeMenus,
            null,
          ),
        );
        final data = PlanData.parse(
          '{"Plan":{"Node Type":"Seq Scan","Actual Rows":7}}',
        );
        final view = SizedBox(
          width: 700,
          height: 500,
          child: PlanView(data: data, controls: controls),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('Actual Rows: 7'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(find.textContaining('Actual Rows: 7'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(find.textContaining('Actual Rows: 7'), findsOneWidget);
        await tester.tap(find.text('Structured tree'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Raw output'));
        await tester.pumpAndSettle();
        expect(find.text(data.raw), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
