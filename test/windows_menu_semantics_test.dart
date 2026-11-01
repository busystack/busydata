import 'dart:convert';
import 'dart:ui' show CheckedState, SemanticsAction, SemanticsRole, Tristate;

import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _kinds = ['icon', 'text', 'split', 'bar', 'context', 'presenter'];

Future<VoidCallback> _openMenu(
  WidgetTester tester,
  String kind,
  List<DesktopMenuAction> actions, {
  List<DesktopMenu>? menus,
  TextDirection direction = TextDirection.ltr,
}) async {
  final semantics = tester.ensureSemantics();
  var semanticsDisposed = false;
  void disposeSemantics() {
    if (!semanticsDisposed) {
      semantics.dispose();
      semanticsDisposed = true;
    }
  }

  addTearDown(disposeSemantics);
  const controls = WindowsControls();
  final presenter = kind == 'presenter' ? controls.createMenuPresenter() : null;
  if (presenter != null) addTearDown(presenter.dispose);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
  await tester.pumpWidget(
    fluent.FluentApp(
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: fluent.ScaffoldPage(
        content: Directionality(
          textDirection: direction,
          child: Center(
            child: Builder(
              builder: (context) => switch (kind) {
                'icon' => controls.iconMenu('Data grid', actions),
                'text' => controls.menu('Commands', actions),
                'split' => controls.splitButton(
                  'Run',
                  () {},
                  'Run options',
                  actions,
                ),
                'bar' => controls.menuBar(
                  menus ?? [DesktopMenu('Data', actions)],
                ),
                'context' => controls.contextMenu(
                  const SizedBox(
                    width: 200,
                    height: 40,
                    child: Text('Context target'),
                  ),
                  actions,
                ),
                'presenter' => presenter!.anchor(
                  fluent.Button(
                    onPressed: () async {
                      final active = presenter;
                      final selected = await active.show(
                        context,
                        const Offset(200, 200),
                        actions,
                      );
                      if (selected != null) actions[selected].invoke();
                    },
                    child: const Text('Commands'),
                  ),
                ),
                _ => throw StateError('Unknown owned menu fixture'),
              },
            ),
          ),
        ),
      ),
    ),
  );
  switch (kind) {
    case 'icon':
      await tester.tap(find.bySemanticsLabel('Data grid'));
    case 'split':
      await tester.tap(find.bySemanticsLabel('Run options'));
    case 'bar':
      await tester.tap(find.text('Data'));
    case 'context':
      await tester.tap(
        find.text('Context target'),
        buttons: kSecondaryMouseButton,
      );
    default:
      await tester.tap(find.text('Commands'));
  }
  await tester.pumpAndSettle();
  return disposeSemantics;
}

void _expectMenuAncestor(SemanticsNode node) {
  var ancestor = node.parent;
  final roles = <String>[];
  while (ancestor != null &&
      ancestor.getSemanticsData().role != SemanticsRole.menu &&
      ancestor.getSemanticsData().role != SemanticsRole.menuBar) {
    roles.add(ancestor.getSemanticsData().role.name);
    ancestor = ancestor.parent;
  }
  if (ancestor == null) {
    debugPrint(
      jsonEncode({
        'missingMenuParent': node.getSemanticsData().label,
        'ancestorRoles': roles,
      }),
    );
  }
  expect(ancestor, isNotNull);
  expect(
    ancestor!.getSemanticsData().flagsCollection.isEnabled,
    Tristate.isTrue,
  );
}

void main() {
  for (final kind in _kinds) {
    for (final caption in ['Sort', 'Filter']) {
      for (final keyboard in [false, true]) {
        testWidgets(
          'Fluent $kind $caption has menu semantics and activates once, keyboard $keyboard',
          (tester) async {
            final calls = <String>[];
            final disposeSemantics = await _openMenu(tester, kind, [
              DesktopMenuAction('Sort', () => calls.add('Sort')),
              DesktopMenuAction('Filter', () => calls.add('Filter')),
            ]);
            var node = tester.getSemantics(find.text(caption));
            final data = node.getSemanticsData();
            debugPrint(
              jsonEncode({
                'kind': kind,
                'caption': caption,
                'role': data.role.name,
                'button': data.flagsCollection.isButton,
                'enabled': data.flagsCollection.isEnabled.name,
                'focused': data.flagsCollection.isFocused.name,
                'selected': data.flagsCollection.isSelected.name,
                'tap': data.hasAction(SemanticsAction.tap),
                'focus': data.hasAction(SemanticsAction.focus),
              }),
            );
            expect(data.role, SemanticsRole.menuItem);
            expect(data.flagsCollection.isButton, isFalse);
            expect(data.flagsCollection.isEnabled, Tristate.isTrue);
            expect(data.hasAction(SemanticsAction.tap), isTrue);
            expect(data.hasAction(SemanticsAction.focus), isTrue);
            _expectMenuAncestor(node);
            final id = node.id;
            node.owner!.performAction(id, SemanticsAction.focus);
            await tester.pumpAndSettle();
            node = tester.getSemantics(find.text(caption));
            expect(node.id, id);
            expect(
              node.getSemanticsData().flagsCollection.isFocused,
              Tristate.isTrue,
            );
            expect(
              node.getSemanticsData().flagsCollection.isSelected,
              data.flagsCollection.isSelected,
            );
            if (keyboard) {
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            } else {
              node.owner!.performAction(id, SemanticsAction.tap);
            }
            await tester.pumpAndSettle();
            expect(calls, [caption]);
            expect(find.byType(fluent.MenuFlyout), findsNothing);
            disposeSemantics();
          },
        );
      }
    }
    testWidgets('Fluent $kind keeps checked and disabled menu permissions', (
      tester,
    ) async {
      final calls = <String>[];
      final disposeSemantics = await _openMenu(tester, kind, [
        DesktopMenuAction(
          'Unavailable',
          () => calls.add('unavailable'),
          disabledReason: 'Captured owner unavailable',
        ),
        DesktopMenuAction('Checked', () => calls.add('checked'), checked: true),
        DesktopMenuAction(
          'Unchecked',
          () => calls.add('unchecked'),
          checked: false,
        ),
      ]);
      final disabled = tester.getSemantics(find.text('Unavailable'));
      final disabledData = disabled.getSemanticsData();
      expect(disabledData.role, SemanticsRole.menuItem);
      expect(disabledData.flagsCollection.isEnabled, Tristate.isFalse);
      // Stock Fluent's guarded tap-down/up callbacks can advertise tap even
      // when disabled. The permission and callback must still reject it.
      disabled.owner!.performAction(disabled.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      _expectMenuAncestor(disabled);
      for (final (caption, checked) in [
        ('Checked', CheckedState.isTrue),
        ('Unchecked', CheckedState.isFalse),
      ]) {
        final node = tester.getSemantics(find.text(caption));
        final data = node.getSemanticsData();
        expect(data.role, SemanticsRole.menuItemCheckbox);
        expect(data.flagsCollection.isChecked, checked);
        expect(data.flagsCollection.isEnabled, Tristate.isTrue);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        _expectMenuAncestor(node);
      }
      expect(calls, isEmpty);
      final checked = tester.getSemantics(find.text('Checked'));
      checked.owner!.performAction(checked.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(calls, ['checked']);
      expect(find.byType(fluent.MenuFlyout), findsNothing);
      disposeSemantics();
    });
  }
  for (final direction in TextDirection.values) {
    testWidgets(
      'Fluent nested menu preserves role, owner and action in $direction',
      (tester) async {
        final calls = <String>[];
        final disposeSemantics = await _openMenu(
          tester,
          'bar',
          [],
          direction: direction,
          menus: [
            DesktopMenu(
              'Data',
              [],
              children: [
                DesktopMenu('Nested', [
                  DesktopMenuAction('Sort', () => calls.add('Sort')),
                ]),
              ],
            ),
          ],
        );
        final nested = tester.getSemantics(find.text('Nested'));
        expect(
          Directionality.of(tester.element(find.text('Nested'))),
          direction,
        );
        expect(nested.getSemanticsData().role, SemanticsRole.menuItem);
        _expectMenuAncestor(nested);
        nested.owner!.performAction(nested.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        final sort = tester.getSemantics(find.text('Sort'));
        expect(Directionality.of(tester.element(find.text('Sort'))), direction);
        expect(sort.getSemanticsData().role, SemanticsRole.menuItem);
        expect(sort.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        _expectMenuAncestor(sort);
        sort.owner!.performAction(sort.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        expect(calls, ['Sort']);
        disposeSemantics();
      },
    );
  }

  testWidgets('Fluent deepest submenu closes with its ancestor and sibling', (
    tester,
  ) async {
    final calls = <String>[];
    final disposeSemantics = await _openMenu(
      tester,
      'bar',
      [],
      menus: [
        DesktopMenu(
          'Data',
          [],
          children: [
            DesktopMenu(
              'First',
              [],
              children: [
                DesktopMenu('Deep', [
                  DesktopMenuAction('Leaf', () => calls.add('leaf')),
                ]),
              ],
            ),
            DesktopMenu('Second', [
              DesktopMenuAction('Sibling', () => calls.add('sibling')),
            ]),
          ],
        ),
      ],
    );
    Future<void> keyboardOpen(String label) async {
      final node = tester.getSemantics(find.text(label));
      expect(node.getSemanticsData().role, SemanticsRole.menuItem);
      _expectMenuAncestor(node);
      node.owner!.performAction(node.id, SemanticsAction.focus);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.text(label))
            .getSemanticsData()
            .flagsCollection
            .isFocused,
        Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
    }

    await keyboardOpen('First');
    await keyboardOpen('Deep');
    _expectMenuAncestor(tester.getSemantics(find.text('Leaf')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Second')));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Leaf'), findsNothing);
    expect(find.text('Deep'), findsNothing);
    expect(find.text('Sibling'), findsOneWidget);
    _expectMenuAncestor(tester.getSemantics(find.text('Sibling')));
    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();
    expect(find.byType(fluent.MenuFlyout), findsNothing);
    expect(calls, isEmpty);
    await mouse.moveTo(Offset.zero);
    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();
    await keyboardOpen('First');
    await keyboardOpen('Deep');
    expect(find.text('Leaf'), findsOneWidget);
    await tester.tap(find.text('Data'));
    await tester.pumpAndSettle();
    expect(find.byType(fluent.MenuFlyout), findsNothing);
    expect(find.text('Leaf'), findsNothing);
    expect(calls, isEmpty);
    disposeSemantics();
  });
}
