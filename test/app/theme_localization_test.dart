import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/constants.dart';
import 'package:yaru/theme.dart';
import 'package:yaru/widgets.dart' show YaruInfoType;
import 'package:busydata/src/app/app_theme.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/platform/gtk_font_service.dart';

void main() {
  test('builds with system accent and tokenized control surfaces', () {
    final light = _buildBusyDataTheme(brightness: Brightness.light);
    final dark = _buildBusyDataTheme(brightness: Brightness.dark);
    final alternate = _buildBusyDataTheme(
      brightness: Brightness.light,
      accentColor: _alternateTestAccentColor,
    );
    final selected = {WidgetState.selected};

    final lightSurfaceColors = light.extension<BusyDataSurfaceColors>()!;
    final yaruBase = createYaruLightTheme(primaryColor: _testAccentColor);

    expect(light.colorScheme.primary, _testAccentColor);
    expect(dark.colorScheme.primary, _testAccentColor);
    expect(light.primaryColor, _testAccentColor);
    expect(light.visualDensity, yaruBase.visualDensity);
    expect(light.splashFactory, yaruBase.splashFactory);
    expect(light.scaffoldBackgroundColor, isNot(_testAccentColor));
    expect(light.colorScheme.surface, alternate.colorScheme.surface);
    expect(
      light.colorScheme.surfaceContainerHighest,
      alternate.colorScheme.surfaceContainerHighest,
    );
    expect(light.colorScheme.secondary, _testAccentColor);
    expect(alternate.colorScheme.secondary, _alternateTestAccentColor);
    expect(light.switchTheme.trackColor?.resolve(selected), _testAccentColor);
    expect(light.radioTheme.fillColor?.resolve(selected), _testAccentColor);
    expect(light.checkboxTheme.fillColor?.resolve(selected), _testAccentColor);
    expect(
      light.colorScheme.primaryContainer,
      isNot(lightSurfaceColors.controlActive),
    );
    expect(
      light.listTileTheme.selectedTileColor,
      light.colorScheme.primaryContainer,
    );
    expect(
      light.textButtonTheme.style?.foregroundColor?.resolve({}),
      _testAccentColor,
    );
    expect(
      light.filledButtonTheme.style?.backgroundColor?.resolve({}),
      lightSurfaceColors.control,
    );
    expect(
      light.filledButtonTheme.style?.backgroundColor?.resolve(selected),
      lightSurfaceColors.controlActive,
    );
    expect(
      light.filledButtonTheme.style?.iconColor?.resolve({}),
      lightSurfaceColors.foreground,
    );
    expect(
      light.elevatedButtonTheme.style?.backgroundColor?.resolve({}),
      _testAccentColor,
    );
    expect(
      light.elevatedButtonTheme.style?.iconColor?.resolve({}),
      light.colorScheme.onPrimary,
    );
    for (final style in [
      light.filledButtonTheme.style,
      light.elevatedButtonTheme.style,
      light.outlinedButtonTheme.style,
      light.textButtonTheme.style,
    ]) {
      expect(
        style?.iconColor?.resolve({WidgetState.disabled}),
        lightSurfaceColors.disabledForeground,
      );
    }
    expect(light.toggleButtonsTheme, yaruBase.toggleButtonsTheme);
    expect(light.floatingActionButtonTheme.backgroundColor, _testAccentColor);
    expect(light.progressIndicatorTheme.color, _testAccentColor);
    expect(light.textSelectionTheme.cursorColor, _testAccentColor);

    final focusedBorder =
        light.inputDecorationTheme.focusedBorder as OutlineInputBorder;
    expect(focusedBorder.borderSide.color, _testAccentColor);

    final outlinedShape =
        light.outlinedButtonTheme.style?.shape?.resolve({})
            as RoundedRectangleBorder;
    expect(
      outlinedShape.borderRadius,
      BorderRadius.circular(kYaruButtonRadius),
    );

    expect(
      light.outlinedButtonTheme.style?.side?.resolve({}),
      yaruBase.outlinedButtonTheme.style?.side?.resolve({}),
    );
    for (final pair in [
      (light.outlinedButtonTheme.style, yaruBase.outlinedButtonTheme.style),
      (light.filledButtonTheme.style, yaruBase.filledButtonTheme.style),
      (light.elevatedButtonTheme.style, yaruBase.elevatedButtonTheme.style),
    ]) {
      expect(pair.$1?.shape?.resolve({}), pair.$2?.shape?.resolve({}));
      for (final states in [
        {WidgetState.hovered},
        {WidgetState.focused},
        {WidgetState.pressed},
      ]) {
        expect(
          pair.$1?.overlayColor?.resolve(states),
          pair.$2?.overlayColor?.resolve(states),
        );
      }
      expect(pair.$1?.splashFactory, pair.$2?.splashFactory);
      expect(pair.$1?.backgroundBuilder, pair.$2?.backgroundBuilder);
    }
  });

  testWidgets('desktop tooltips use one explicit natural-width geometry', (
    tester,
  ) async {
    Future<({Rect surface, Rect text})> measureTooltip({
      required Brightness brightness,
      required String message,
    }) async {
      final tooltipKey = GlobalKey<TooltipState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: _buildBusyDataTheme(brightness: brightness),
          home: Scaffold(
            body: Center(
              child: Tooltip(
                key: tooltipKey,
                message: message,
                child: const SizedBox.square(dimension: 32),
              ),
            ),
          ),
        ),
      );
      expect(tooltipKey.currentState!.ensureTooltipVisible(), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final messageFinder = find.text(message);
      expect(messageFinder, findsOneWidget);
      final textRect = tester.getRect(messageFinder);
      Rect? surfaceRect;
      tester.element(messageFinder).visitAncestorElements((element) {
        if (element.widget case final ConstrainedBox constrained
            when constrained.constraints == BusyDataTooltipStyle.constraints) {
          final box = element.renderObject! as RenderBox;
          surfaceRect = box.localToGlobal(Offset.zero) & box.size;
          return false;
        }
        return true;
      });
      expect(surfaceRect, isNotNull);
      return (surface: surfaceRect!, text: textRect);
    }

    for (final brightness in Brightness.values) {
      final short = await measureTooltip(
        brightness: brightness,
        message: 'Main menu',
      );
      final long = await measureTooltip(
        brightness: brightness,
        message: 'Show sidebar panel',
      );

      for (final measurement in [short, long]) {
        expect(
          measurement.surface.height,
          moreOrLessEquals(
            math.max(
              BusyDataSizes.tooltipMinHeight,
              measurement.text.height +
                  (BusyDataSpacing.tooltipVertical + BusyDataStroke.outline) *
                      2,
            ),
            epsilon: .01,
          ),
        );
        expect(
          measurement.surface.width,
          moreOrLessEquals(
            measurement.text.width +
                (BusyDataSpacing.tooltipHorizontal + BusyDataStroke.outline) *
                    2,
            epsilon: 0.01,
          ),
        );
      }
      expect(long.surface.width, greaterThan(short.surface.width));
    }
  });

  test('semantic theme retains Yaru component geometry and interactions', () {
    final theme = _buildBusyDataTheme(brightness: Brightness.light);
    final base = createYaruLightTheme(primaryColor: _testAccentColor);
    final colors = theme.extension<BusyDataSurfaceColors>()!;

    expect(theme.inputDecorationTheme.filled, base.inputDecorationTheme.filled);
    expect(
      theme.inputDecorationTheme.fillColor,
      base.inputDecorationTheme.fillColor,
    );
    expect(
      theme.inputDecorationTheme.contentPadding,
      base.inputDecorationTheme.contentPadding,
    );
    final inputShape =
        theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    final baseInputShape =
        base.inputDecorationTheme.enabledBorder as OutlineInputBorder;
    expect(inputShape.borderRadius, baseInputShape.borderRadius);
    expect(inputShape.borderSide.width, baseInputShape.borderSide.width);
    expect(
      inputShape.borderSide.strokeAlign,
      baseInputShape.borderSide.strokeAlign,
    );
    expect(inputShape.borderSide.color, colors.border);

    expect(theme.cardTheme.color, colors.card);
    expect(theme.cardTheme.color?.a, 1);
    expect(theme.cardTheme.surfaceTintColor, Colors.transparent);
    expect(theme.cardTheme.shadowColor, theme.colorScheme.shadow);
    expect(theme.cardTheme.elevation, BusyDataElevation.groupedCard);
    expect(theme.cardTheme.margin, base.cardTheme.margin);
    expect(theme.cardTheme.clipBehavior, base.cardTheme.clipBehavior);
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(BusyDataRadius.lg));
    expect(cardShape.side, BorderSide.none);

    expect(
      theme.dropdownMenuTheme.inputDecorationTheme?.constraints,
      base.dropdownMenuTheme.inputDecorationTheme?.constraints,
    );

    final dialogShape = theme.dialogTheme.shape! as RoundedRectangleBorder;
    final baseDialogShape = base.dialogTheme.shape! as RoundedRectangleBorder;
    expect(theme.dialogTheme.elevation, base.dialogTheme.elevation);
    expect(theme.dialogTheme.shadowColor, theme.colorScheme.shadow);
    expect(dialogShape.borderRadius, baseDialogShape.borderRadius);
    expect(dialogShape.borderRadius, BorderRadius.circular(kYaruWindowRadius));
    expect(dialogShape.side, BorderSide(color: colors.dialogOutline));
    expect(dialogShape.side, isNot(baseDialogShape.side));
    expect(BusyDataRadius.window, kYaruWindowRadius);

    for (final pair in [
      (theme.outlinedButtonTheme.style, base.outlinedButtonTheme.style),
      (theme.filledButtonTheme.style, base.filledButtonTheme.style),
      (theme.elevatedButtonTheme.style, base.elevatedButtonTheme.style),
      (theme.textButtonTheme.style, base.textButtonTheme.style),
    ]) {
      final padding = pair.$1?.padding?.resolve(const {})! as EdgeInsets;
      expect(padding, pair.$2?.padding?.resolve(const {}));
      expect(
        pair.$1?.minimumSize?.resolve(const {}),
        pair.$2?.minimumSize?.resolve(const {}),
      );
      expect(pair.$1?.visualDensity, pair.$2?.visualDensity);
      expect(pair.$1?.tapTargetSize, pair.$2?.tapTargetSize);
      expect(
        pair.$1?.elevation?.resolve(const {}),
        pair.$2?.elevation?.resolve(const {}),
      );
      expect(
        pair.$1?.surfaceTintColor?.resolve(const {}),
        pair.$2?.surfaceTintColor?.resolve(const {}),
      );
    }

    final checkboxShape = theme.checkboxTheme.shape! as RoundedRectangleBorder;
    final baseCheckboxShape =
        base.checkboxTheme.shape! as RoundedRectangleBorder;
    expect(checkboxShape.borderRadius, baseCheckboxShape.borderRadius);
    expect(checkboxShape.borderRadius, BorderRadius.circular(kYaruCheckRadius));

    final popupShape = theme.popupMenuTheme.shape! as OutlineInputBorder;
    final basePopupShape = base.popupMenuTheme.shape! as OutlineInputBorder;
    expect(popupShape.borderRadius, basePopupShape.borderRadius);
    expect(popupShape.borderSide, BorderSide(color: colors.floatingBorder));
    expect(theme.popupMenuTheme.elevation, base.popupMenuTheme.elevation);
    expect(
      theme.menuTheme.style?.elevation?.resolve(const {}),
      base.menuTheme.style?.elevation?.resolve(const {}),
    );
    expect(theme.popupMenuTheme.menuPadding, base.popupMenuTheme.menuPadding);
    expect(theme.popupMenuTheme.position, base.popupMenuTheme.position);
    expect(
      theme.menuTheme.style?.side?.resolve({}),
      BorderSide(color: colors.floatingBorder),
    );
    expect(
      theme.dropdownMenuTheme.menuStyle?.side?.resolve({}),
      BorderSide(color: colors.floatingBorder),
    );

    for (final style in [
      theme.textTheme.titleSmall,
      theme.textTheme.bodySmall,
      theme.textTheme.labelLarge,
      theme.textTheme.labelMedium,
      theme.textTheme.labelSmall,
    ]) {
      expect(
        style?.color,
        style == theme.textTheme.labelLarge
            ? colors.foreground
            : colors.mutedForeground,
      );
    }
  });

  testWidgets('semantic Yaru status colors do not follow the app accent', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      Map<YaruInfoType, Color>? colorsForFirstAccent;
      for (final accent in const [Color(0xFFE95420), Color(0xFF7764D8)]) {
        final theme = _buildBusyDataTheme(
          brightness: brightness,
          accentColor: accent,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            darkTheme: theme,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const Scaffold(
              body: SizedBox(key: ValueKey('status-color-probe')),
            ),
          ),
        );

        final context = tester.element(
          find.byKey(const ValueKey('status-color-probe')),
        );
        final semanticColors = YaruColors.of(context);
        final actual = <YaruInfoType, Color>{
          for (final type in YaruInfoType.values) type: type.getColor(context),
        };

        expect(actual, <YaruInfoType, Color>{
          YaruInfoType.information: semanticColors.link,
          YaruInfoType.success: semanticColors.success,
          YaruInfoType.important: YaruColors.purple,
          YaruInfoType.warning: semanticColors.warning,
          YaruInfoType.danger: semanticColors.error,
        });
        colorsForFirstAccent ??= actual;
        expect(actual, colorsForFirstAccent);
        expect(actual[YaruInfoType.information], isNot(accent));
      }
    }
  });

  test('shared push buttons expose semantic Yaru roles', () {
    final standard = BusyDataPushButton.standard(
      onPressed: () {},
      child: const Text('Standard'),
    );
    final suggested = BusyDataPushButton.suggested(
      onPressed: () {},
      child: const Text('Suggested'),
    );

    expect(standard, isA<FilledButton>());
    expect(suggested, isA<ElevatedButton>());
    expect(standard.style, isNull);
    expect(suggested.style, isNull);
  });

  test('BusyData Yaru theme exposes semantic fallback surfaces', () {
    final light = _buildBusyDataTheme(brightness: Brightness.light);
    final dark = _buildBusyDataTheme(brightness: Brightness.dark);

    final lightColors = light.extension<BusyDataSurfaceColors>()!;
    final darkColors = dark.extension<BusyDataSurfaceColors>()!;

    expect(lightColors.window, const Color(0xFFFAFAFA));
    expect(lightColors.view, const Color(0xFFFFFFFF));
    expect(lightColors.sidebar, const Color(0xFFEBEBEB));
    expect(lightColors.secondarySidebar, const Color(0xFFF0F0F0));
    expect(lightColors.headerbar, const Color(0xFFFAFAFA));
    expect(lightColors.headerbarFlat, lightColors.view);
    expect(lightColors.card, const Color(0xFFFFFFFF));
    expect(lightColors.groupedSurface, const Color(0xFFFFFFFF));
    expect(lightColors.dialog, const Color(0xFFFAFAFA));
    expect(lightColors.popover, const Color(0xFFFAFAFA));
    expect(lightColors.control, const Color.fromRGBO(0, 0, 0, 0.10));
    expect(lightColors.controlHover, const Color.fromRGBO(0, 0, 0, 0.14));
    expect(lightColors.controlActive, const Color.fromRGBO(0, 0, 0, 0.18));
    expect(lightColors.mutedForeground, const Color(0xFF666666));
    expect(
      lightColors.dialogOutline,
      const Color.fromRGBO(255, 255, 255, 0.07),
    );
    expect(lightColors.floatingBorder, const Color.fromRGBO(0, 0, 0, 0.14));
    expect(lightColors.sidebarBorder, const Color.fromRGBO(24, 24, 24, 0.08));
    expect(darkColors.window, const Color(0xFF2C2C2C));
    expect(darkColors.view, const Color(0xFF272727));
    expect(darkColors.sidebar, const Color(0xFF393939));
    expect(darkColors.secondarySidebar, const Color(0xFF323232));
    expect(darkColors.headerbar, const Color(0xFF393939));
    expect(darkColors.card, const Color(0xFF3D3D3D));
    expect(
      darkColors.groupedSurface,
      const Color.fromRGBO(255, 255, 255, 0.08),
    );
    expect(darkColors.dialog, const Color(0xFF3E3E3E));
    expect(darkColors.popover, const Color(0xFF3E3E3E));
    expect(darkColors.mutedForeground, const Color(0xFFB5B5B5));
    expect(darkColors.border, const Color.fromRGBO(0, 0, 0, 0.75));
    expect(darkColors.dialogOutline, const Color.fromRGBO(255, 255, 255, 0.07));
    expect(darkColors.floatingBorder, const Color.fromRGBO(0, 0, 0, 0.14));
    expect(darkColors.sidebarBorder, const Color.fromRGBO(16, 16, 16, 0.35));
    expect(
      Color.alphaBlend(darkColors.sidebarBorder, darkColors.sidebar).toARGB32(),
      const Color(0xFF2B2B2B).toARGB32(),
    );
    expect(darkColors.shade, const Color.fromRGBO(0, 0, 0, 0.25));
    expect(darkColors.groupedSurface.a, lessThan(1));
    expect(
      Color.alphaBlend(darkColors.groupedSurface, darkColors.window).toARGB32(),
      darkColors.card.toARGB32(),
    );
    expect(
      Color.alphaBlend(
        darkColors.groupedSurface,
        darkColors.dialog,
      ).computeLuminance(),
      greaterThan(darkColors.dialog.computeLuminance()),
    );
    for (final (theme, colors) in [(light, lightColors), (dark, darkColors)]) {
      _expectOpaqueMonotonicSurfaceContainers(theme);
      expect(theme.colorScheme.surfaceContainerLowest, colors.view);
      expect(theme.colorScheme.surfaceContainerLow, colors.window);
      expect(theme.colorScheme.surfaceContainer, colors.secondarySidebar);
      expect(theme.colorScheme.surfaceContainerHigh, colors.secondarySidebar);
      expect(theme.colorScheme.surfaceContainerHighest, colors.sidebar);
      expect(colors.mutedForeground.a, 1);
      final effectiveGroupedSurfaces = [
        for (final parent in [
          colors.window,
          colors.view,
          colors.dialog,
          colors.popover,
        ])
          Color.alphaBlend(colors.groupedSurface, parent),
      ];
      for (final surface in [
        colors.window,
        colors.view,
        colors.sidebar,
        colors.secondarySidebar,
        colors.headerbar,
        colors.headerbarFlat,
        colors.card,
        colors.dialog,
        colors.popover,
      ]) {
        _expectNeutralSurface(surface);
        expect(
          _contrastRatio(colors.mutedForeground, surface),
          greaterThanOrEqualTo(4.5),
          reason: 'Muted text must remain legible on $surface',
        );
      }
      for (final surface in effectiveGroupedSurfaces) {
        _expectNeutralSurface(surface);
        expect(
          _contrastRatio(colors.mutedForeground, surface),
          greaterThanOrEqualTo(4),
          reason:
              'Native contextual card layers must retain clear secondary text',
        );
      }
    }
    expect(light.scaffoldBackgroundColor, lightColors.window);
    expect(dark.scaffoldBackgroundColor, darkColors.window);
    expect(light.cardColor, lightColors.card);
    expect(dark.cardColor, darkColors.card);
    expect(light.cardTheme.color, lightColors.card);
    expect(dark.cardTheme.color, darkColors.card);
    expect(light.cardTheme.color?.a, 1);
    expect(dark.cardTheme.color?.a, 1);
    expect(light.cardTheme.elevation, BusyDataElevation.groupedCard);
    expect(dark.cardTheme.elevation, BusyDataElevation.groupedCard);
    expect(light.cardTheme.shadowColor, light.colorScheme.shadow);
    expect(dark.cardTheme.shadowColor, dark.colorScheme.shadow);
    expect(light.dialogTheme.backgroundColor, lightColors.dialog);
    expect(dark.dialogTheme.backgroundColor, darkColors.dialog);
    expect(light.dialogTheme.shadowColor, light.colorScheme.shadow);
    expect(dark.dialogTheme.shadowColor, dark.colorScheme.shadow);
    expect(light.popupMenuTheme.color, lightColors.popover);
    expect(dark.popupMenuTheme.color, darkColors.popover);
    expect(
      light.popupMenuTheme.labelTextStyle?.resolve(const {})?.color,
      lightColors.foreground,
    );
    expect(
      light.popupMenuTheme.labelTextStyle?.resolve(const {
        WidgetState.disabled,
      })?.color,
      lightColors.disabledForeground,
    );
    expect(
      dark.menuTheme.style?.backgroundColor?.resolve(const {}),
      darkColors.popover,
    );
    expect(
      dark.dropdownMenuTheme.menuStyle?.backgroundColor?.resolve(const {}),
      darkColors.popover,
    );
    final yaruDark = createYaruDarkTheme(primaryColor: _testAccentColor);
    for (final pair in [
      (dark.menuTheme.style, yaruDark.menuTheme.style),
      (dark.dropdownMenuTheme.menuStyle, yaruDark.dropdownMenuTheme.menuStyle),
    ]) {
      expect(
        pair.$1?.elevation?.resolve(const {}),
        pair.$2?.elevation?.resolve(const {}),
      );
      expect(
        pair.$1?.shape?.resolve(const {}),
        pair.$2?.shape?.resolve(const {}),
      );
      expect(
        pair.$1?.side?.resolve(const {}),
        BorderSide(color: darkColors.floatingBorder),
      );
      expect(
        pair.$1?.padding?.resolve(const {}),
        pair.$2?.padding?.resolve(const {}),
      );
    }
    final yaruLight = createYaruLightTheme(primaryColor: _testAccentColor);
    for (final theme in [light, dark]) {
      final decoration = theme.tooltipTheme.decoration! as BoxDecoration;
      final border = decoration.border! as Border;
      expect(decoration.color, BusyDataTooltipStyle.background);
      expect(decoration.borderRadius, BusyDataTooltipStyle.borderRadius);
      expect(border.top.color, BusyDataTooltipStyle.border);
      expect(
        theme.tooltipTheme.textStyle?.color,
        BusyDataTooltipStyle.foreground,
      );
      expect(theme.tooltipTheme.padding, BusyDataTooltipStyle.padding);
      expect(theme.tooltipTheme.constraints, BusyDataTooltipStyle.constraints);
      expect(theme.tooltipTheme.waitDuration, BusyDataMotion.tooltipWait);
    }
    expect(
      light.tooltipTheme.waitDuration,
      yaruLight.tooltipTheme.waitDuration,
    );
    expect(dark.tooltipTheme.waitDuration, yaruDark.tooltipTheme.waitDuration);
  });

  test('BusyDataSurfaceColors copyWith preserves and overrides fields', () {
    final base = _buildBusyDataTheme(
      brightness: Brightness.dark,
    ).extension<BusyDataSurfaceColors>()!;

    final updated = base.copyWith(
      window: const Color(0xFF010203),
      sidebar: const Color(0xFF040506),
      groupedSurface: const Color(0xFF060708),
      disabledForeground: const Color(0xFF070809),
      dialogOutline: const Color(0xFF090A0B),
      shade: const Color(0xFF0A0B0C),
    );

    expect(updated.window, const Color(0xFF010203));
    expect(updated.sidebar, const Color(0xFF040506));
    expect(updated.groupedSurface, const Color(0xFF060708));
    expect(updated.disabledForeground, const Color(0xFF070809));
    expect(updated.dialogOutline, const Color(0xFF090A0B));
    expect(updated.shade, const Color(0xFF0A0B0C));
    expect(updated.view, base.view);
    expect(updated.popover, base.popover);
  });

  test('BusyDataSurfaceColors lerp blends semantic fields', () {
    final start = _buildBusyDataTheme(
      brightness: Brightness.light,
    ).extension<BusyDataSurfaceColors>()!;
    final end = _buildBusyDataTheme(
      brightness: Brightness.dark,
    ).extension<BusyDataSurfaceColors>()!;

    final midpoint = start.lerp(end, 0.5);

    expect(midpoint.window, Color.lerp(start.window, end.window, 0.5));
    expect(midpoint.sidebar, Color.lerp(start.sidebar, end.sidebar, 0.5));
    expect(
      midpoint.groupedSurface,
      Color.lerp(start.groupedSurface, end.groupedSurface, 0.5),
    );
    expect(midpoint.dialog, Color.lerp(start.dialog, end.dialog, 0.5));
    expect(
      midpoint.dialogOutline,
      Color.lerp(start.dialogOutline, end.dialogOutline, 0.5),
    );
    expect(
      midpoint.disabledForeground,
      Color.lerp(start.disabledForeground, end.disabledForeground, 0.5),
    );
    expect(midpoint.shade, Color.lerp(start.shade, end.shade, 0.5));
  });

  test(
    'BusyData theme preserves Yaru typography when no GTK font is provided',
    () {
      final base = createYaruLightTheme(
        primaryColor: BusyDataLinuxPalette.light4,
      );
      final theme = _buildBusyDataTheme(brightness: Brightness.light);

      _expectTextThemeMetrics(
        actual: theme.textTheme,
        base: base.textTheme,
        expectedFamilyForAll: null,
      );
    },
  );

  test('BusyData component themes preserve reference Yaru typography', () {
    const scale = 1.0;
    final base = createYaruLightTheme(
      primaryColor: BusyDataLinuxPalette.light4,
    );
    final theme = _buildBusyDataTheme(brightness: Brightness.light);
    final gtkFamily = base.textTheme.bodyMedium!.fontFamily!;
    final textTheme = theme.textTheme;
    final buttonStates = <WidgetState>{};

    _expectComponentStyleUsesTypography(
      theme.appBarTheme.titleTextStyle,
      baseStyle: base.appBarTheme.titleTextStyle,
      fallback: textTheme.titleMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.popupMenuTheme.textStyle,
      baseStyle: base.popupMenuTheme.textStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.popupMenuTheme.labelTextStyle?.resolve(buttonStates),
      baseStyle: base.popupMenuTheme.labelTextStyle?.resolve(buttonStates),
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dialogTheme.titleTextStyle,
      baseStyle: base.dialogTheme.titleTextStyle,
      fallback: textTheme.titleLarge,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dialogTheme.contentTextStyle,
      baseStyle: base.dialogTheme.contentTextStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.listTileTheme.titleTextStyle,
      baseStyle: base.listTileTheme.titleTextStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.listTileTheme.subtitleTextStyle,
      baseStyle: base.listTileTheme.subtitleTextStyle,
      fallback: textTheme.bodySmall,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.labelStyle,
      baseStyle: base.inputDecorationTheme.labelStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.hintStyle,
      baseStyle: base.inputDecorationTheme.hintStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.helperStyle,
      baseStyle: base.inputDecorationTheme.helperStyle,
      fallback: textTheme.bodySmall,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.inputDecorationTheme.errorStyle,
      baseStyle: base.inputDecorationTheme.errorStyle,
      fallback: textTheme.bodySmall,
      scale: scale,
    );
    expect(
      theme.tooltipTheme.textStyle?.fontFamily,
      theme.textTheme.bodyMedium?.fontFamily,
    );
    expect(
      theme.tooltipTheme.textStyle?.fontSize,
      theme.textTheme.bodyMedium?.fontSize,
    );
    expect(
      theme.tooltipTheme.textStyle?.color,
      BusyDataTooltipStyle.foreground,
    );
    _expectComponentStyleUsesTypography(
      theme.snackBarTheme.contentTextStyle,
      baseStyle: base.snackBarTheme.contentTextStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dataTableTheme.headingTextStyle,
      baseStyle: base.dataTableTheme.headingTextStyle,
      fallback: textTheme.labelLarge,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dataTableTheme.dataTextStyle,
      baseStyle: base.dataTableTheme.dataTextStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );

    for (final style in [
      theme.outlinedButtonTheme.style,
      theme.filledButtonTheme.style,
      theme.elevatedButtonTheme.style,
      theme.textButtonTheme.style,
    ]) {
      final actual =
          style?.textStyle?.resolve(buttonStates) ?? textTheme.labelLarge;
      expect(actual?.fontFamily, gtkFamily);
      expect(actual?.fontSize, textTheme.labelLarge?.fontSize);
      expect(actual?.fontWeight, textTheme.labelLarge?.fontWeight);
      expect(actual?.letterSpacing, textTheme.labelLarge?.letterSpacing);
      expect(actual?.height, textTheme.labelLarge?.height);
    }

    _expectComponentStyleUsesTypography(
      theme.menuButtonTheme.style?.textStyle?.resolve(buttonStates),
      baseStyle: base.menuButtonTheme.style?.textStyle?.resolve(buttonStates),
      fallback: textTheme.labelLarge,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.dropdownMenuTheme.textStyle,
      baseStyle: base.dropdownMenuTheme.textStyle,
      fallback: textTheme.bodyMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.tabBarTheme.labelStyle,
      baseStyle: base.tabBarTheme.labelStyle,
      fallback: textTheme.labelLarge,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.navigationRailTheme.selectedLabelTextStyle,
      baseStyle: base.navigationRailTheme.selectedLabelTextStyle,
      fallback: textTheme.labelMedium,
      scale: scale,
    );
    _expectComponentStyleUsesTypography(
      theme.navigationBarTheme.labelTextStyle?.resolve(buttonStates),
      baseStyle: base.navigationBarTheme.labelTextStyle?.resolve(buttonStates),
      fallback: textTheme.labelMedium,
      scale: scale,
    );
  });

  test('BusyData theme uses GTK accent foreground when it is readable', () {
    const accent = Color(0xFF006B50);
    const accentForeground = Color(0xFFF5FFF9);
    const gtkColors = GtkThemeColors(
      brightness: Brightness.light,
      accent: accent,
      accentForeground: accentForeground,
    );
    final theme = _buildBusyDataTheme(
      brightness: Brightness.light,
      accentColor: accent,
      gtkThemeColors: gtkColors,
    );

    expect(theme.colorScheme.onPrimary, accentForeground);
    expect(
      theme.elevatedButtonTheme.style?.foregroundColor?.resolve({}),
      accentForeground,
    );
  });

  test(
    'current BusyMark neutral roles stay authoritative under GTK palette changes',
    () {
      for (final brightness in Brightness.values) {
        final fallback = busyDataFallbackSurfaceColors(brightness);
        for (final sample in [
          const Color(0xFF123456),
          const Color(0xFF000000),
          const Color(0xFFFFFFFF),
        ]) {
          final theme = _buildBusyDataTheme(
            brightness: brightness,
            gtkThemeColors: GtkThemeColors(
              brightness: brightness,
              window: sample,
              view: sample,
              sidebar: sample,
              secondarySidebar: sample,
              headerbar: sample,
              headerbarFlat: sample,
              card: sample,
              dialog: sample,
              popover: sample,
              foreground: sample,
              mutedForeground: sample,
              border: sample,
              divider: sample,
              control: sample,
              controlHover: sample,
              controlActive: sample,
              cardShade: sample,
              floatingBorder: sample,
              sidebarBorder: sample,
              shade: sample,
            ),
          );
          final colors = theme.extension<BusyDataSurfaceColors>()!;
          expect(colors.window, fallback.window);
          expect(colors.view, fallback.view);
          expect(colors.sidebar, fallback.sidebar);
          expect(colors.secondarySidebar, fallback.secondarySidebar);
          expect(colors.headerbar, fallback.headerbar);
          expect(colors.headerbarFlat, fallback.headerbarFlat);
          expect(colors.card, fallback.card);
          expect(colors.groupedSurface, fallback.groupedSurface);
          expect(colors.dialog, fallback.dialog);
          expect(colors.popover, fallback.popover);
          expect(colors.foreground, fallback.foreground);
          expect(colors.mutedForeground, fallback.mutedForeground);
          expect(colors.control, fallback.control);
          expect(colors.controlHover, fallback.controlHover);
          expect(colors.controlActive, fallback.controlActive);
          expect(colors.shade, fallback.shade);
          expect(colors.border, fallback.border);
          expect(colors.divider, fallback.divider);
          expect(colors.cardShade, fallback.cardShade);
          expect(colors.floatingBorder, fallback.floatingBorder);
          expect(colors.sidebarBorder, fallback.sidebarBorder);
        }
      }
    },
  );

  test('BusyData theme ignores GTK runtime colors for other brightness', () {
    const gtkColors = GtkThemeColors(
      brightness: Brightness.dark,
      window: Color(0xFF202020),
    );
    final theme = _buildBusyDataTheme(
      brightness: Brightness.light,
      gtkThemeColors: gtkColors,
    );

    expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAFA));
  });

  test(
    'BusyData Yaru theme derives text theme from Yaru instead of scratch',
    () {
      final source = File(
        'lib/src/app/busydata_yaru_theme.dart',
      ).readAsStringSync();

      expect(source, contains('_busyDataTextTheme('));
      expect(source, contains('base.copyWith('));
      expect(source, isNot(contains('return TextTheme(')));
      expect(source, isNot(contains('fontSize: 26')));
      expect(source, isNot(contains('fontSize: 15')));
    },
  );
}

const _testAccentColor = Color(0xFF2E7D32);
const _alternateTestAccentColor = Color(0xFF8A1D61);

void _expectNeutralSurface(Color color) {
  final channels = color.toARGB32();
  final red = (channels >> 16) & 0xff;
  final green = (channels >> 8) & 0xff;
  final blue = channels & 0xff;
  expect(green, red, reason: '$color has a red/green surface tint');
  expect(blue, red, reason: '$color has a red/blue surface tint');
}

void _expectOpaqueMonotonicSurfaceContainers(ThemeData theme) {
  final containers = [
    theme.colorScheme.surfaceContainerLowest,
    theme.colorScheme.surfaceContainerLow,
    theme.colorScheme.surfaceContainer,
    theme.colorScheme.surfaceContainerHigh,
    theme.colorScheme.surfaceContainerHighest,
  ];
  for (final color in containers) {
    expect(
      color.a,
      1,
      reason: '${theme.brightness} surface containers must remain opaque',
    );
  }
  for (var index = 0; index < containers.length - 1; index++) {
    final current = containers[index].computeLuminance();
    final next = containers[index + 1].computeLuminance();
    expect(
      theme.brightness == Brightness.light ? current >= next : current <= next,
      isTrue,
      reason: '${theme.brightness} surface containers must follow elevation',
    );
  }
}

double _contrastRatio(Color foreground, Color background) {
  final effectiveForeground = foreground.a < 1
      ? Color.alphaBlend(foreground, background)
      : foreground;
  final foregroundLuminance = effectiveForeground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

ThemeData _buildBusyDataTheme({
  required Brightness brightness,
  Color accentColor = _testAccentColor,
  GtkThemeColors? gtkThemeColors,
}) {
  return buildBusyDataTheme(
    brightness: brightness,
    accentColor: accentColor,

    gtkThemeColors: gtkThemeColors,
  );
}

class _TextThemeRole {
  const _TextThemeRole(this.name, this.actual, this.base);

  final String name;
  final TextStyle? actual;
  final TextStyle? base;
}

List<_TextThemeRole> _textThemeRoles(TextTheme actual, TextTheme base) {
  return [
    _TextThemeRole('displayLarge', actual.displayLarge, base.displayLarge),
    _TextThemeRole('displayMedium', actual.displayMedium, base.displayMedium),
    _TextThemeRole('displaySmall', actual.displaySmall, base.displaySmall),
    _TextThemeRole('headlineLarge', actual.headlineLarge, base.headlineLarge),
    _TextThemeRole(
      'headlineMedium',
      actual.headlineMedium,
      base.headlineMedium,
    ),
    _TextThemeRole('headlineSmall', actual.headlineSmall, base.headlineSmall),
    _TextThemeRole('titleLarge', actual.titleLarge, base.titleLarge),
    _TextThemeRole('titleMedium', actual.titleMedium, base.titleMedium),
    _TextThemeRole('titleSmall', actual.titleSmall, base.titleSmall),
    _TextThemeRole('bodyLarge', actual.bodyLarge, base.bodyLarge),
    _TextThemeRole('bodyMedium', actual.bodyMedium, base.bodyMedium),
    _TextThemeRole('bodySmall', actual.bodySmall, base.bodySmall),
    _TextThemeRole('labelLarge', actual.labelLarge, base.labelLarge),
    _TextThemeRole('labelMedium', actual.labelMedium, base.labelMedium),
    _TextThemeRole('labelSmall', actual.labelSmall, base.labelSmall),
  ];
}

void _expectTextThemeMetrics({
  required TextTheme actual,
  required TextTheme base,
  required String? expectedFamilyForAll,
  double expectedScale = 1,
}) {
  for (final role in _textThemeRoles(actual, base)) {
    final actualStyle = role.actual;
    final baseStyle = role.base;
    expect(actualStyle, isNotNull, reason: '${role.name} should exist.');
    expect(baseStyle, isNotNull, reason: '${role.name} base should exist.');
    if (actualStyle == null || baseStyle == null) {
      continue;
    }

    if (expectedFamilyForAll == null) {
      expect(
        actualStyle.fontFamily,
        baseStyle.fontFamily,
        reason: '${role.name} should preserve the Yaru font family.',
      );
      expect(actualStyle.fontFamilyFallback, baseStyle.fontFamilyFallback);
    } else {
      expect(
        actualStyle.fontFamily,
        expectedFamilyForAll,
        reason: '${role.name} should use the GTK font family.',
      );
      expect(actualStyle.fontFamilyFallback, isNull);
    }

    if (baseStyle.fontSize == null) {
      expect(actualStyle.fontSize, isNull, reason: role.name);
    } else {
      expect(
        actualStyle.fontSize,
        moreOrLessEquals(baseStyle.fontSize! * expectedScale, epsilon: 0.0001),
        reason: '${role.name} should preserve Yaru size with GTK scaling.',
      );
    }

    expect(actualStyle.fontWeight, baseStyle.fontWeight, reason: role.name);
    expect(actualStyle.fontStyle, baseStyle.fontStyle, reason: role.name);
    expect(
      actualStyle.letterSpacing,
      baseStyle.letterSpacing,
      reason: role.name,
    );
    expect(actualStyle.height, baseStyle.height, reason: role.name);
    expect(actualStyle.wordSpacing, baseStyle.wordSpacing, reason: role.name);
    expect(actualStyle.textBaseline, baseStyle.textBaseline, reason: role.name);
    expect(
      actualStyle.leadingDistribution,
      baseStyle.leadingDistribution,
      reason: role.name,
    );
    expect(actualStyle.fontFeatures, baseStyle.fontFeatures, reason: role.name);
    expect(
      actualStyle.fontVariations,
      baseStyle.fontVariations,
      reason: role.name,
    );
    expect(actualStyle.decoration, baseStyle.decoration, reason: role.name);
    expect(
      actualStyle.decorationColor,
      baseStyle.decorationColor,
      reason: role.name,
    );
    expect(
      actualStyle.decorationStyle,
      baseStyle.decorationStyle,
      reason: role.name,
    );
    expect(
      actualStyle.decorationThickness,
      baseStyle.decorationThickness,
      reason: role.name,
    );
  }
}

void _expectComponentStyleUsesTypography(
  TextStyle? actual, {
  required TextStyle? baseStyle,
  required TextStyle? fallback,
  required double scale,
}) {
  expect(actual, isNotNull);
  expect(baseStyle ?? fallback, isNotNull);
  if (actual == null) {
    return;
  }
  final expected = baseStyle ?? fallback;
  if (expected == null) {
    return;
  }
  final expectedScale = baseStyle == null ? 1.0 : scale;

  expect(actual.fontFamily, expected.fontFamily);
  expect(actual.fontFamilyFallback, expected.fontFamilyFallback);
  if (expected.fontSize == null) {
    expect(actual.fontSize, isNull);
  } else {
    expect(
      actual.fontSize,
      moreOrLessEquals(expected.fontSize! * expectedScale, epsilon: 0.0001),
    );
  }
  expect(actual.fontWeight, expected.fontWeight);
  expect(actual.letterSpacing, expected.letterSpacing);
  expect(actual.height, expected.height);
}
