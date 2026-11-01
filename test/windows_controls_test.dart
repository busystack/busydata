import 'dart:ui' show CheckedState, SemanticsAction;

import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('Fluent checkbox wraps and activates at $direction $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        const label = 'Include system objects in the selected metadata scope';
        var checked = false;
        var changes = 0;
        await tester.pumpWidget(
          fluent.FluentApp(
            home: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(scale),
                highContrast: true,
                disableAnimations: true,
              ),
              child: Directionality(
                textDirection: direction,
                child: Center(
                  child: SizedBox(
                    width: 280,
                    child: StatefulBuilder(
                      builder: (context, set) => const WindowsControls()
                          .checkbox(label, checked, (value) {
                            set(() => checked = value);
                            changes++;
                          }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getSize(find.text(label)).width, lessThanOrEqualTo(252));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(checked, isTrue);
        expect(changes, 1);
        final data = tester
            .getSemantics(find.bySemanticsLabel(label))
            .getSemanticsData();
        expect(data.flagsCollection.isChecked, CheckedState.isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(checked, isFalse);
        expect(changes, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        semantics.dispose();
      });
    }
  }
  for (final callerOwnsFocus in [false, true]) {
    testWidgets(
      'Fluent search keeps its field name and clear focus ($callerOwnsFocus)',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final controller = TextEditingController();
        final callerFocus = callerOwnsFocus ? FocusNode() : null;
        final changes = <String>[];
        await tester.pumpWidget(
          fluent.FluentApp(
            home: fluent.ScaffoldPage(
              content: const WindowsControls().filterField(
                controller,
                'Filter records',
                focusNode: callerFocus,
                onChanged: changes.add,
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(EditableText), 'target');
        await tester.pumpAndSettle();
        final focus = tester
            .widget<EditableText>(find.byType(EditableText))
            .focusNode;
        final field = tester
            .getSemantics(find.byType(EditableText))
            .getSemanticsData();
        expect(field.label, 'Filter records');
        expect(field.value, 'target');
        expect(field.flagsCollection.isTextField, isTrue);
        final clear = find.bySemanticsLabel('Clear');
        expect(clear.hitTestable(), findsOneWidget);
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        expect(changes, ['target', '']);
        expect(focus.hasFocus, isTrue);
        expect(
          tester
              .getSemantics(find.byType(EditableText))
              .getSemanticsData()
              .label,
          'Filter records',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
        callerFocus?.dispose();
        semantics.dispose();
      },
    );
  }

  testWidgets('Fluent inline browse keeps field and action identifiable', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final controller = TextEditingController();
    var browses = 0;
    const ui = WindowsControls();
    await tester.pumpWidget(
      fluent.FluentApp(
        home: fluent.ScaffoldPage(
          content: ui.field(
            controller,
            'CA certificate file',
            showLabel: false,
            trailing: ui.iconButton(
              DesktopIcon.folder,
              'Choose file',
              () => browses++,
            ),
          ),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.byType(EditableText)).getSemanticsData().label,
      'CA certificate file',
    );
    final browse = find.bySemanticsLabel('Choose file');
    expect(browse.hitTestable(), findsOneWidget);
    await tester.tap(browse);
    await tester.pumpAndSettle();
    expect(browses, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    controller.dispose();
    semantics.dispose();
  });

  testWidgets('Fluent labeled choices announce their label and value once', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      fluent.FluentApp(
        home: Center(
          child: SizedBox(
            width: 360,
            child: const WindowsControls().choice(
              'Development',
              const {'Development': 'Development', 'Staging': 'Staging'},
              (_) {},
              label: 'Environment',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final data = tester
        .getSemantics(find.bySemanticsLabel(RegExp('^Environment')))
        .getSemanticsData();
    expect(data.label, contains('Environment'));
    expect('Development'.allMatches(data.label), hasLength(1));
    expect(data.tooltip, isEmpty);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  for (final scale in [1.0, 2.0]) {
    for (final connected in [true, false]) {
      testWidgets('Fluent Run and options at $scale, connected $connected', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        var runs = 0, selections = 0;
        await tester.pumpWidget(
          fluent.FluentApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: fluent.ScaffoldPage(
                content: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const WindowsControls().splitButton(
                        'Run',
                        connected ? () => runs++ : null,
                        'Run options',
                        [
                          DesktopMenuAction(
                            'Run selection',
                            () => selections++,
                            disabledReason: connected ? null : 'No connection',
                          ),
                          DesktopMenuAction('Execution settings', () {}),
                        ],
                      ),
                      fluent.Button(
                        onPressed: () {},
                        child: const Text('Ordinary action'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(fluent.SplitButton)).height,
          closeTo(tester.getSize(find.byType(fluent.Button)).height, 2),
        );
        await tester.tap(find.text('Run'));
        await tester.pumpAndSettle();
        expect(runs, connected ? 1 : 0);
        final options = find.bySemanticsLabel('Run options');
        expect(options, findsOneWidget);
        expect(
          tester
              .getSemantics(options)
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );
        if (connected) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(runs, 2);
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text('Execution settings'), findsOneWidget);
        await tester.tap(find.text('Run selection'));
        await tester.pumpAndSettle();
        expect(selections, connected ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        semantics.dispose();
      });
    }
  }
}
