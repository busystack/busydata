import 'dart:math' as math;

import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/linux/linux_header_style.dart';
import 'package:busydata/src/app/linux/linux_window_host.dart';
import 'package:busydata/src/platform/gtk_header_icon_service.dart';
import 'package:busydata/src/platform/gtk_window_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  group('Linux header centers in available control gap', () {
    for (final testCase in const [
      _LayoutCase('small leading and large trailing', 34, 154, 0, 0, false),
      _LayoutCase('large leading and small trailing', 154, 34, 0, 0, false),
      _LayoutCase('system controls on the right', 68, 102, 0, 110, false),
      _LayoutCase('system controls on the left', 102, 68, 110, 0, false),
      _LayoutCase('partially presented sidebar', 102, 102, 42, 110, false),
      _LayoutCase('RTL', 68, 154, 93, 0, true),
    ]) {
      testWidgets(testCase.label, (tester) async {
        await _pumpLayout(tester, testCase);

        final header = tester.getRect(find.byKey(_headerKey));
        final title = tester.getRect(find.byKey(_titleKey));
        final leading = tester.getRect(find.byKey(_leadingKey));
        final trailing = tester.getRect(find.byKey(_trailingKey));
        expect(
          title.center.dx,
          closeTo(
            (leading.center.dx < trailing.center.dx
                    ? leading.right + trailing.left
                    : trailing.right + leading.left) /
                2,
            .001,
          ),
        );
        expect(title.overlaps(leading), isFalse);
        expect(title.overlaps(trailing), isFalse);

        final physicalLeft = testCase.rtl ? trailing : leading;
        final physicalRight = testCase.rtl ? leading : trailing;
        expect(
          physicalLeft.left,
          greaterThanOrEqualTo(
            testCase.leftObstruction + BusyDataSpacing.headerInset,
          ),
        );
        expect(
          physicalRight.right,
          lessThanOrEqualTo(
            header.width -
                testCase.rightObstruction -
                BusyDataSpacing.headerInset,
          ),
        );
        final leftGap = title.left - physicalLeft.right;
        final rightGap = physicalRight.left - title.right;
        expect(leftGap, greaterThanOrEqualTo(BusyDataSpacing.headerInset));
        expect(rightGap, greaterThanOrEqualTo(BusyDataSpacing.headerInset));
        expect(
          math.min(leftGap, rightGap),
          closeTo(BusyDataSpacing.headerInset, .001),
        );
      });
    }
  });

  group('Linux header fill-between-controls allocation', () {
    for (final testCase in const [
      _LayoutCase('small leading and large trailing', 34, 154, 0, 0, false),
      _LayoutCase('large leading and small trailing', 154, 34, 0, 0, false),
      _LayoutCase('empty leading group', 0, 154, 0, 0, false),
      _LayoutCase('system controls on the right', 68, 102, 0, 110, false),
      _LayoutCase('system controls on the left', 102, 68, 110, 0, false),
      _LayoutCase('RTL', 68, 154, 93, 0, true),
    ]) {
      testWidgets(testCase.label, (tester) async {
        await _pumpLayout(
          tester,
          testCase,
          centerAllocation:
              BusyDataLinuxHeaderCenterAllocation.fillBetweenControls,
        );

        final title = tester.getRect(find.byKey(_titleKey));
        final leading = tester.getRect(find.byKey(_leadingKey));
        final trailing = tester.getRect(find.byKey(_trailingKey));
        final physicalLeft = testCase.rtl ? trailing : leading;
        final physicalRight = testCase.rtl ? leading : trailing;

        expect(
          title.left,
          closeTo(physicalLeft.right + BusyDataSpacing.headerInset, .001),
        );
        expect(
          title.right,
          closeTo(physicalRight.left - BusyDataSpacing.headerInset, .001),
        );
        expect(title.overlaps(leading), isFalse);
        expect(title.overlaps(trailing), isFalse);
      });
    }

    testWidgets('uses actual groups placed by maxContentWidth', (tester) async {
      const testCase = _LayoutCase('max content width', 34, 154, 0, 0, false);
      await _pumpLayout(
        tester,
        testCase,
        centerAllocation:
            BusyDataLinuxHeaderCenterAllocation.fillBetweenControls,
        maxContentWidth: 600,
      );

      final title = tester.getRect(find.byKey(_titleKey));
      final leading = tester.getRect(find.byKey(_leadingKey));
      final trailing = tester.getRect(find.byKey(_trailingKey));
      expect(
        title.left,
        closeTo(leading.right + BusyDataSpacing.headerInset, .001),
      );
      expect(
        title.right,
        closeTo(trailing.left - BusyDataSpacing.headerInset, .001),
      );
    });

    testWidgets('uses zero width when the safe edges cross', (tester) async {
      const testCase = _LayoutCase(
        'pathological narrow width',
        68,
        68,
        0,
        0,
        false,
      );
      await _pumpLayout(
        tester,
        testCase,
        centerAllocation:
            BusyDataLinuxHeaderCenterAllocation.fillBetweenControls,
        headerWidth: 100,
      );

      expect(tester.getSize(find.byKey(_titleKey)).width, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('relayouts when the allocation policy changes', (tester) async {
      const testCase = _LayoutCase('policy change', 34, 154, 0, 0, false);
      await _pumpLayout(tester, testCase, titleWidth: 140);
      final centeredWidth = tester.getSize(find.byKey(_titleKey)).width;

      await _pumpLayout(
        tester,
        testCase,
        titleWidth: 140,
        centerAllocation:
            BusyDataLinuxHeaderCenterAllocation.fillBetweenControls,
      );
      final fillWidth = tester.getSize(find.byKey(_titleKey)).width;

      expect(fillWidth, greaterThan(centeredWidth));
    });
  });

  testWidgets('title and brand use GTK body role with distinct emphasis', (
    tester,
  ) async {
    const bodyStyle = TextStyle(
      color: Color(0xFF284664),
      fontFamily: 'GTK body',
      fontSize: 14.25,
    );
    await tester.pumpWidget(
      _testApp(
        windowActive: true,
        theme: ThemeData(
          textTheme: const TextTheme(
            bodyMedium: bodyStyle,
            titleMedium: TextStyle(fontSize: 30, fontFamily: 'Wrong role'),
          ),
        ),
        child: const Row(
          children: [
            BusyDataLinuxHeaderTitle('June 2026'),
            BusyDataLinuxHeaderTitle('BusyData', brand: true),
          ],
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('June 2026'));
    final brand = tester.widget<Text>(find.text('BusyData'));
    expect(title.style?.fontSize, bodyStyle.fontSize);
    expect(title.style?.fontFamily, bodyStyle.fontFamily);
    expect(title.style?.color, bodyStyle.color);
    expect(title.style?.fontWeight, FontWeight.bold);
    expect(brand.style?.fontSize, bodyStyle.fontSize);
    expect(brand.style?.fontFamily, bodyStyle.fontFamily);
    expect(brand.style?.color, bodyStyle.color);
    expect(brand.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('active and inactive foreground metrics match native chrome', (
    tester,
  ) async {
    const bodyColor = Color(0xFF204060);
    Future<(Color?, Color?, Color?, Color?)> pump(bool active) async {
      await tester.pumpWidget(
        _testApp(
          windowActive: active,
          theme: ThemeData(
            textTheme: const TextTheme(bodyMedium: TextStyle(color: bodyColor)),
          ),
          child: const Column(
            children: [
              BusyDataLinuxHeaderTitle('Title', key: ValueKey('title')),
              BusyDataLinuxHeaderTitle(
                'Brand',
                key: ValueKey('brand'),
                brand: true,
              ),
              BusyDataLinuxHeaderIconButton(
                key: ValueKey('enabled'),
                icon: BusyDataLinuxHeaderIcon.search,
                tooltip: 'Enabled',
                onPressed: _noop,
              ),
              BusyDataLinuxHeaderIconButton(
                key: ValueKey('disabled'),
                icon: BusyDataLinuxHeaderIcon.create,
                tooltip: 'Disabled',
                onPressed: null,
              ),
            ],
          ),
        ),
      );
      final enabled = _iconButton(tester, const ValueKey('enabled'));
      final disabled = _iconButton(tester, const ValueKey('disabled'));
      return (
        tester.widget<Text>(find.text('Title')).style?.color,
        tester.widget<Text>(find.text('Brand')).style?.color,
        enabled.style?.foregroundColor?.resolve(const {}),
        disabled.style?.foregroundColor?.resolve(const {WidgetState.disabled}),
      );
    }

    final active = await pump(true);
    expect(active.$1, bodyColor);
    expect(active.$2, bodyColor);
    expect(active.$3?.a, 1);
    expect(active.$4?.a, .38);

    final inactive = await pump(false);
    expect(inactive.$1?.a, .50);
    expect(inactive.$2?.a, .50);
    expect(inactive.$3?.a, .50);
    expect(inactive.$4?.a, .19);
  });

  testWidgets('application control states use neutral current-color layers', (
    tester,
  ) async {
    late BuildContext testContext;
    await tester.pumpWidget(
      _testApp(
        windowActive: true,
        theme: ThemeData(colorSchemeSeed: const Color(0xFFFF00FF)),
        child: YaruTheme(
          data: const YaruThemeData(focusBorders: true),
          child: Builder(
            builder: (context) {
              testContext = context;
              return const BusyDataLinuxHeaderIconButton(
                icon: BusyDataLinuxHeaderIcon.mainMenu,
                tooltip: 'Menu',
                selected: true,
                onPressed: _noop,
              );
            },
          ),
        ),
      ),
    );

    final foreground = busyDataLinuxHeaderForeground(testContext);
    final background = busyDataLinuxHeaderControlBackground(testContext);
    Color? resolve(Set<WidgetState> states) => background.resolve(states);
    expect(resolve(const {}), Colors.transparent);
    expect(resolve(const {WidgetState.focused}), Colors.transparent);
    expect(resolve(const {WidgetState.disabled}), Colors.transparent);
    expect(
      resolve(const {WidgetState.hovered}),
      foreground.withValues(alpha: foreground.a * .07),
    );
    expect(
      resolve(const {WidgetState.pressed}),
      foreground.withValues(alpha: foreground.a * .16),
    );
    expect(
      resolve(const {WidgetState.selected}),
      foreground.withValues(alpha: foreground.a * .10),
    );
    expect(
      resolve(const {WidgetState.selected, WidgetState.hovered}),
      foreground.withValues(alpha: foreground.a * .13),
    );
    expect(
      resolve(const {WidgetState.selected, WidgetState.pressed}),
      foreground.withValues(alpha: foreground.a * .19),
    );

    final button = tester.widget<IconButton>(find.byType(IconButton));
    expect(button.style?.splashFactory, NoSplash.splashFactory);
    expect(
      button.style?.overlayColor?.resolve(const {WidgetState.pressed}),
      Colors.transparent,
    );
    expect(
      button.style?.foregroundColor?.resolve(const {WidgetState.selected}),
      isNot(Theme.of(testContext).colorScheme.primary),
    );
    final focusBorder = tester.widget<YaruFocusBorder>(
      find.byType(YaruFocusBorder),
    );
    expect(
      focusBorder.borderRadius,
      BorderRadius.circular(BusyDataLinuxHeaderStyle.controlRadius),
    );
  });
}

const _headerKey = ValueKey('header');
const _titleKey = ValueKey('title');
const _leadingKey = ValueKey('leading');
const _trailingKey = ValueKey('trailing');

void _noop() {}

Future<void> _pumpLayout(
  WidgetTester tester,
  _LayoutCase testCase, {
  BusyDataLinuxHeaderCenterAllocation centerAllocation =
      BusyDataLinuxHeaderCenterAllocation.centered,
  double headerWidth = 1000,
  double? maxContentWidth,
  double titleWidth = double.infinity,
}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = Size(headerWidth, 200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _testApp(
      direction: testCase.rtl ? TextDirection.rtl : TextDirection.ltr,
      child: LinuxPageHeaderInsetsScope(
        leftObstruction: testCase.leftObstruction,
        rightObstruction: testCase.rightObstruction,
        child: SizedBox(
          key: _headerKey,
          width: headerWidth,
          child: BusyDataLinuxHeaderLayout(
            centerAllocation: centerAllocation,
            maxContentWidth: maxContentWidth,
            leading: SizedBox(
              key: _leadingKey,
              width: testCase.leadingWidth,
              height: BusyDataSizes.headerIconButton,
            ),
            title: SizedBox(
              key: _titleKey,
              width: titleWidth,
              child: BusyDataLinuxHeaderTitle('Centered title'),
            ),
            trailing: SizedBox(
              key: _trailingKey,
              width: testCase.trailingWidth,
              height: BusyDataSizes.headerIconButton,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _testApp({
  required Widget child,
  bool windowActive = true,
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme,
    home: LinuxWindowMetricsScope(
      leftControlInset: 0,
      rightControlInset: 0,
      windowActive: windowActive,
      preferences: GtkWindowPreferences.defaults(),
      child: Directionality(
        textDirection: direction,
        child: Scaffold(body: child),
      ),
    ),
  );
}

class _LayoutCase {
  const _LayoutCase(
    this.label,
    this.leadingWidth,
    this.trailingWidth,
    this.leftObstruction,
    this.rightObstruction,
    this.rtl,
  );

  final String label;
  final double leadingWidth;
  final double trailingWidth;
  final double leftObstruction;
  final double rightObstruction;
  final bool rtl;
}

IconButton _iconButton(WidgetTester tester, Key key) =>
    tester.widget<IconButton>(
      find.descendant(of: find.byKey(key), matching: find.byType(IconButton)),
    );
