import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/theme.dart';

import '../platform/gtk_font_service.dart';
import 'busydata_design.dart';
import 'busydata_surface_colors.dart';

export 'busydata_surface_colors.dart';

abstract final class BusyDataLinuxPalette {
  static const red3 = Color(0xFFE01B24);
  static const red5 = Color(0xFFA51D2D);
  static const light2 = Color(0xFFF6F5F4);
  static const light4 = Color(0xFFC0BFBC);
  static const dark5 = Color(0xFF000000);
}

class BusyDataYaruTheme {
  const BusyDataYaruTheme._();

  static ThemeData build({
    required Brightness brightness,
    required Color accentColor,
    GtkThemeColors? gtkThemeColors,
    bool highContrast = false,
  }) {
    final base = switch (brightness) {
      Brightness.light => createYaruLightTheme(primaryColor: accentColor),
      Brightness.dark => createYaruDarkTheme(
        primaryColor: accentColor,
        highContrast: highContrast,
      ),
    };
    final resolvedColors = busyDataFallbackSurfaceColors(brightness);
    final colors = highContrast
        ? _highContrastSurfaceColors(brightness)
        : resolvedColors;
    final surfaceContainers = _surfaceContainerLadder(colors, brightness);
    final sampledAccentForeground =
        gtkThemeColors?.brightness == brightness &&
            gtkThemeColors?.accent == accentColor
        ? gtkThemeColors?.accentForeground
        : null;
    final onAccent =
        sampledAccentForeground != null &&
            _contrastRatio(sampledAccentForeground, accentColor) >= 4.5
        ? sampledAccentForeground
        : contrastColor(accentColor);
    final accentContainer = Color.alphaBlend(
      accentColor.withValues(
        alpha: brightness == Brightness.dark ? 0.24 : 0.14,
      ),
      colors.view,
    );
    final colorScheme = base.colorScheme.copyWith(
      brightness: brightness,
      primary: accentColor,
      onPrimary: onAccent,
      primaryContainer: accentContainer,
      onPrimaryContainer: contrastColor(accentContainer),
      secondary: accentColor,
      error: base.colorScheme.error,
      onError:
          _contrastRatio(Colors.white, base.colorScheme.error) >=
              _contrastRatio(Colors.black, base.colorScheme.error)
          ? Colors.white
          : Colors.black,
      surface: colors.view,
      onSurface: colors.foreground,
      onSurfaceVariant: colors.mutedForeground,
      // Generic Material surfaces need opaque elevation roles. The translucent
      // control ladder belongs exclusively to interactive widget states.
      surfaceContainerLowest: surfaceContainers.lowest,
      surfaceContainerLow: surfaceContainers.low,
      surfaceContainer: surfaceContainers.container,
      surfaceContainerHigh: surfaceContainers.high,
      surfaceContainerHighest: surfaceContainers.highest,
      outline: colors.border,
      outlineVariant: colors.divider,
      scrim: BusyDataLinuxPalette.dark5,
    );
    const normalizer = _SemanticTextStyles();
    final textTheme = _busyDataTextTheme(
      base.textTheme,
      colors: colors,
      normalizer: normalizer,
    );
    final inputDecorationTheme = _semanticInputDecorationTheme(
      base.inputDecorationTheme,
      colors: colors,
      accentColor: accentColor,
      errorColor: colorScheme.error,
      normalizer: normalizer,
      textTheme: textTheme,
    );
    final dropdownInputDecorationTheme = _semanticInputDecorationTheme(
      base.dropdownMenuTheme.inputDecorationTheme ?? base.inputDecorationTheme,
      colors: colors,
      accentColor: accentColor,
      errorColor: colorScheme.error,
      normalizer: normalizer,
      textTheme: textTheme,
    );
    final outlinedButtonStyle = _semanticButtonStyle(
      base.outlinedButtonTheme.style,
      textStyle: _normalizeTextStyleProperty(
        base.outlinedButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: null,
      ),
      foreground: colors.foreground,
      background: Colors.transparent,
      disabledForeground: colors.disabledForeground,
      disabledBackground: Colors.transparent,
    );
    final filledButtonStyle = _semanticButtonStyle(
      base.filledButtonTheme.style,
      textStyle: _normalizeTextStyleProperty(
        base.filledButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: null,
      ),
      foreground: colors.foreground,
      background: colors.control,
      selectedBackground: colors.controlActive,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
    );
    final elevatedButtonStyle = _semanticButtonStyle(
      base.elevatedButtonTheme.style,
      textStyle: _normalizeTextStyleProperty(
        base.elevatedButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: null,
      ),
      foreground: onAccent,
      background: accentColor,
      disabledForeground: colors.disabledForeground,
      disabledBackground: colors.disabledControl,
    );
    final textButtonStyle = _semanticButtonStyle(
      base.textButtonTheme.style,
      textStyle: _normalizeTextStyleProperty(
        base.textButtonTheme.style?.textStyle,
        normalizer: normalizer,
        fallback: null,
      ),
      foreground: accentColor,
      background: Colors.transparent,
      disabledForeground: colors.disabledForeground,
      disabledBackground: Colors.transparent,
    );
    final popoverSurfaceSide = BorderSide(
      color: highContrast ? colors.border : colors.floatingBorder,
    );
    final dialogSurfaceSide = BorderSide(
      color: highContrast ? colors.border : colors.dialogOutline,
    );
    final menuStyle = _semanticMenuSurfaceStyle(
      base.menuTheme.style,
      color: colors.popover,
      shadowColor: colorScheme.shadow,
      side: popoverSurfaceSide,
    );
    final dropdownMenuStyle = _semanticMenuSurfaceStyle(
      base.dropdownMenuTheme.menuStyle,
      color: colors.popover,
      shadowColor: colorScheme.shadow,
      side: popoverSurfaceSide,
    );
    final cardTheme = base.cardTheme.copyWith(
      // Filled Flutter surfaces must be opaque. [colors.card] is the semantic
      // GTK layer precomposited over the window/editor surface by the resolver.
      // Card and Yaru continue to own elevation and shadow geometry.
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: colorScheme.shadow,
      elevation: BusyDataElevation.groupedCard,
      shape:
          base.cardTheme.shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(BusyDataRadius.lg),
          ),
    );
    final tooltipTheme = base.tooltipTheme.copyWith(
      decoration: BoxDecoration(
        color: BusyDataTooltipStyle.background,
        border: Border.all(color: BusyDataTooltipStyle.border),
        borderRadius: BusyDataTooltipStyle.borderRadius,
      ),
      textStyle: textTheme.bodyMedium?.copyWith(
        color: BusyDataTooltipStyle.foreground,
      ),
      padding: BusyDataTooltipStyle.padding,
      constraints: BusyDataTooltipStyle.constraints,
      waitDuration: BusyDataMotion.tooltipWait,
    );
    return base.copyWith(
      brightness: brightness,
      colorScheme: colorScheme,
      primaryColor: accentColor,
      shadowColor: colorScheme.shadow,
      scaffoldBackgroundColor: colors.window,
      canvasColor: colors.window,
      cardColor: colors.card,
      cardTheme: cardTheme,
      extensions: [
        ...base.extensions.values.where((e) => e is! BusyDataSurfaceColors),
        colors,
      ],
      dividerColor: colors.divider,
      appBarTheme: base.appBarTheme.copyWith(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colors.headerbar,
        foregroundColor: colors.foreground,
        surfaceTintColor: colors.headerbar,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: normalizer.apply(
          base.appBarTheme.titleTextStyle,
          fallback: textTheme.titleMedium,
        ),
      ),
      textTheme: textTheme,
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: colors.dialog,
        surfaceTintColor: colors.dialog,
        // Material 3 makes its default dialog shadow transparent. Restore the
        // semantic theme shadow while retaining the framework-owned elevation
        // and Yaru-owned dialog geometry.
        shadowColor: colorScheme.shadow,
        // Retain Yaru's dialog radius and geometry, but use the modern
        // libadwaita dialog outline instead of Yaru Flutter's conspicuous
        // dark-mode white outline. Popovers have a separate perimeter role.
        shape: _withOutlineSide(base.dialogTheme.shape, dialogSurfaceSide),
        titleTextStyle: normalizer.apply(
          base.dialogTheme.titleTextStyle,
          fallback: textTheme.titleLarge,
        ),
        contentTextStyle: normalizer.apply(
          base.dialogTheme.contentTextStyle,
          fallback: textTheme.bodyMedium,
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        selectedColor: colors.foreground,
        selectedTileColor: accentContainer,
        iconColor: colors.mutedForeground,
        textColor: colors.foreground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        titleTextStyle: normalizer.apply(
          base.listTileTheme.titleTextStyle,
          fallback: textTheme.bodyMedium,
        ),
        subtitleTextStyle: normalizer.apply(
          base.listTileTheme.subtitleTextStyle,
          fallback: textTheme.bodySmall,
        ),
        leadingAndTrailingTextStyle: normalizer.apply(
          base.listTileTheme.leadingAndTrailingTextStyle,
          fallback: textTheme.labelSmall,
        ),
      ),
      inputDecorationTheme: inputDecorationTheme,
      outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
      filledButtonTheme: FilledButtonThemeData(style: filledButtonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
      textButtonTheme: TextButtonThemeData(style: textButtonStyle),
      iconButtonTheme: IconButtonThemeData(
        style: _semanticButtonStyle(
          base.iconButtonTheme.style,
          foreground: colors.foreground,
          background: Colors.transparent,
          disabledForeground: colors.disabledForeground,
          disabledBackground: Colors.transparent,
          textStyle: _normalizeTextStyleProperty(
            base.iconButtonTheme.style?.textStyle,
            normalizer: normalizer,
            fallback: textTheme.labelLarge,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledForeground;
          }
          if (states.contains(WidgetState.selected)) {
            return onAccent;
          }
          return colors.view;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledControl;
          }
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.controlHover;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.border;
        }),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledControl;
          }
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.control;
        }),
        checkColor: WidgetStatePropertyAll(onAccent),
        side: BorderSide(color: colors.border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledForeground;
          }
          if (states.contains(WidgetState.selected)) {
            return accentColor;
          }
          return colors.mutedForeground;
        }),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: colors.popover,
        surfaceTintColor: colors.popover,
        shadowColor: colorScheme.shadow,
        textStyle: normalizer.apply(
          base.popupMenuTheme.textStyle,
          fallback: textTheme.bodyMedium,
          color: colors.foreground,
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return normalizer.apply(
            base.popupMenuTheme.labelTextStyle?.resolve(states),
            fallback: textTheme.bodyMedium,
            color: states.contains(WidgetState.disabled)
                ? colors.disabledForeground
                : colors.foreground,
          );
        }),
        shape: _withOutlineSide(base.popupMenuTheme.shape, popoverSurfaceSide),
      ),
      menuTheme: MenuThemeData(
        style: menuStyle,
        submenuIcon: base.menuTheme.submenuIcon,
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: normalizer.apply(
          base.chipTheme.labelStyle,
          fallback: textTheme.labelLarge,
        ),
        secondaryLabelStyle: normalizer.apply(
          base.chipTheme.secondaryLabelStyle,
          fallback: textTheme.labelLarge,
        ),
      ),
      tooltipTheme: tooltipTheme,
      snackBarTheme: base.snackBarTheme.copyWith(
        contentTextStyle: normalizer.apply(
          base.snackBarTheme.contentTextStyle,
          fallback: textTheme.bodyMedium,
        ),
      ),
      dataTableTheme: base.dataTableTheme.copyWith(
        headingTextStyle: normalizer.apply(
          base.dataTableTheme.headingTextStyle,
          fallback: textTheme.labelLarge,
        ),
        dataTextStyle: normalizer.apply(
          base.dataTableTheme.dataTextStyle,
          fallback: textTheme.bodyMedium,
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: (base.menuButtonTheme.style ?? const ButtonStyle()).copyWith(
          textStyle: _normalizeTextStyleProperty(
            base.menuButtonTheme.style?.textStyle,
            normalizer: normalizer,
            fallback: textTheme.labelLarge,
          ),
        ),
      ),
      dropdownMenuTheme: base.dropdownMenuTheme.copyWith(
        textStyle: normalizer.apply(
          base.dropdownMenuTheme.textStyle,
          fallback: textTheme.bodyMedium,
        ),
        inputDecorationTheme: dropdownInputDecorationTheme,
        menuStyle: dropdownMenuStyle,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelStyle: normalizer.apply(
          base.tabBarTheme.labelStyle,
          fallback: textTheme.labelLarge,
        ),
        unselectedLabelStyle: normalizer.apply(
          base.tabBarTheme.unselectedLabelStyle,
          fallback: textTheme.labelLarge,
        ),
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        selectedLabelTextStyle: normalizer.apply(
          base.navigationRailTheme.selectedLabelTextStyle,
          fallback: textTheme.labelMedium,
        ),
        unselectedLabelTextStyle: normalizer.apply(
          base.navigationRailTheme.unselectedLabelTextStyle,
          fallback: textTheme.labelMedium,
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        labelTextStyle: _normalizeTextStyleProperty(
          base.navigationBarTheme.labelTextStyle,
          normalizer: normalizer,
          fallback: textTheme.labelMedium,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: onAccent,
        elevation: 0,
        focusColor: accentColor.withValues(alpha: 0.18),
        hoverColor: accentColor.withValues(alpha: 0.08),
        splashColor: accentColor.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accentColor,
        circularTrackColor: colors.control,
        linearTrackColor: colors.control,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
        selectionColor: accentColor.withValues(alpha: 0.32),
        selectionHandleColor: accentColor,
      ),
    );
  }

  static TextTheme _busyDataTextTheme(
    TextTheme base, {
    required BusyDataSurfaceColors colors,
    required _SemanticTextStyles normalizer,
  }) {
    TextStyle? apply(TextStyle? style, {Color? color}) =>
        normalizer.apply(style, color: color);

    return base.copyWith(
      displayLarge: apply(base.displayLarge, color: colors.foreground),
      displayMedium: apply(base.displayMedium, color: colors.foreground),
      displaySmall: apply(base.displaySmall, color: colors.foreground),
      headlineLarge: apply(base.headlineLarge, color: colors.foreground),
      headlineMedium: apply(base.headlineMedium, color: colors.foreground),
      headlineSmall: apply(base.headlineSmall, color: colors.foreground),
      titleLarge: apply(base.titleLarge, color: colors.foreground),
      titleMedium: apply(base.titleMedium, color: colors.foreground),
      titleSmall: apply(base.titleSmall, color: colors.mutedForeground),
      bodyLarge: apply(base.bodyLarge, color: colors.foreground),
      bodyMedium: apply(base.bodyMedium, color: colors.foreground),
      bodySmall: apply(base.bodySmall, color: colors.mutedForeground),
      labelLarge: apply(base.labelLarge, color: colors.foreground),
      labelMedium: apply(base.labelMedium, color: colors.mutedForeground),
      labelSmall: apply(base.labelSmall, color: colors.mutedForeground),
    );
  }
}

({Color lowest, Color low, Color container, Color high, Color highest})
_surfaceContainerLadder(BusyDataSurfaceColors colors, Brightness brightness) {
  var ladder = <Color>[
    colors.view,
    colors.window,
    colors.secondarySidebar,
    colors.secondarySidebar,
    colors.sidebar,
  ];
  if (!_isOpaqueMonotonicLadder(ladder, brightness)) {
    var candidates = <Color>[
      colors.view,
      colors.window,
      colors.secondarySidebar,
      colors.sidebar,
    ];
    if (candidates.any((color) => color.a < 1)) {
      final fallback = busyDataFallbackSurfaceColors(brightness);
      candidates = [
        fallback.view,
        fallback.window,
        fallback.secondarySidebar,
        fallback.sidebar,
      ];
    }
    candidates.sort((first, second) {
      final luminanceOrder = first.computeLuminance().compareTo(
        second.computeLuminance(),
      );
      if (luminanceOrder != 0) {
        return brightness == Brightness.dark ? luminanceOrder : -luminanceOrder;
      }
      return first.toARGB32().compareTo(second.toARGB32());
    });
    ladder = [
      candidates[0],
      candidates[1],
      candidates[2],
      candidates[2],
      candidates[3],
    ];
  }

  return (
    lowest: ladder[0],
    low: ladder[1],
    container: ladder[2],
    high: ladder[3],
    highest: ladder[4],
  );
}

bool _isOpaqueMonotonicLadder(List<Color> ladder, Brightness brightness) {
  if (ladder.any((color) => color.a < 1)) {
    return false;
  }
  for (var index = 0; index < ladder.length - 1; index++) {
    final current = ladder[index].computeLuminance();
    final next = ladder[index + 1].computeLuminance();
    if (brightness == Brightness.light ? current < next : current > next) {
      return false;
    }
  }
  return true;
}

BusyDataSurfaceColors _highContrastSurfaceColors(Brightness brightness) {
  final background = brightness == Brightness.dark
      ? Colors.black
      : Colors.white;
  final foreground = contrastColor(background);
  Color layer(double opacity) =>
      Color.alphaBlend(foreground.withValues(alpha: opacity), background);

  // High contrast is an accessibility contract, so it intentionally uses one
  // coherent palette instead of retaining GTK surfaces that may have mixed
  // luminance. Normal themes use the current shared BusyMark neutral roles.
  return BusyDataSurfaceColors(
    window: background,
    view: background,
    sidebar: background,
    secondarySidebar: background,
    headerbar: background,
    headerbarFlat: background,
    card: background,
    groupedSurface: background,
    dialog: background,
    popover: background,
    control: layer(0.10),
    controlHover: layer(0.18),
    controlActive: layer(0.28),
    activeToggle: layer(0.22),
    foreground: foreground,
    mutedForeground: foreground,
    disabledForeground: layer(0.55),
    disabledControl: layer(0.06),
    border: foreground,
    divider: foreground,
    cardShade: foreground,
    dialogOutline: foreground,
    floatingBorder: foreground,
    sidebarBorder: foreground,
    shade: Colors.black.withValues(alpha: 0.50),
  );
}

// BusyMark app_theme preserves the resolved Yaru families, fallback chains,
// role sizes and metrics. Text scaling belongs to MediaQuery, not GTK points.
class _SemanticTextStyles {
  const _SemanticTextStyles();
  TextStyle? apply(TextStyle? style, {TextStyle? fallback, Color? color}) =>
      (style ?? fallback)?.copyWith(color: color);
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

WidgetStateProperty<TextStyle?> _normalizeTextStyleProperty(
  WidgetStateProperty<TextStyle?>? property, {
  required _SemanticTextStyles normalizer,
  required TextStyle? fallback,
}) {
  return WidgetStateProperty.resolveWith((states) {
    return normalizer.apply(property?.resolve(states), fallback: fallback);
  });
}

/// Applies semantic colors and reference typography while retaining the input
/// geometry supplied by Yaru, including component-specific constraints.
InputDecorationThemeData _semanticInputDecorationTheme(
  InputDecorationThemeData base, {
  required BusyDataSurfaceColors colors,
  required Color accentColor,
  required Color errorColor,
  required _SemanticTextStyles normalizer,
  required TextTheme textTheme,
}) {
  final disabledBorderColor = colors.border.withValues(
    alpha: colors.border.a * 0.6,
  );

  InputBorder? borderWithColor(InputBorder? border, Color color) {
    return border?.copyWith(
      borderSide: border.borderSide.copyWith(color: color),
    );
  }

  return base.copyWith(
    border: borderWithColor(base.border, colors.border),
    enabledBorder: borderWithColor(base.enabledBorder, colors.border),
    focusedBorder: borderWithColor(base.focusedBorder, accentColor),
    errorBorder: borderWithColor(base.errorBorder, errorColor),
    focusedErrorBorder: borderWithColor(base.focusedErrorBorder, errorColor),
    disabledBorder: borderWithColor(base.disabledBorder, disabledBorderColor),
    activeIndicatorBorder: base.activeIndicatorBorder?.copyWith(
      color: accentColor,
    ),
    outlineBorder: base.outlineBorder?.copyWith(color: colors.border),
    iconColor: colors.foreground,
    labelStyle: normalizer.apply(
      base.labelStyle,
      fallback: textTheme.bodyMedium,
    ),
    floatingLabelStyle: normalizer.apply(
      base.floatingLabelStyle,
      fallback: textTheme.bodyMedium,
      color: accentColor,
    ),
    hintStyle: normalizer.apply(
      base.hintStyle,
      fallback: textTheme.bodyMedium,
      color: colors.mutedForeground,
    ),
    helperStyle: normalizer.apply(
      base.helperStyle,
      fallback: textTheme.bodySmall,
    ),
    errorStyle: normalizer.apply(
      base.errorStyle,
      fallback: textTheme.bodySmall,
      color: errorColor,
    ),
    counterStyle: normalizer.apply(
      base.counterStyle,
      fallback: textTheme.bodySmall,
    ),
  );
}

ShapeBorder? _withOutlineSide(ShapeBorder? shape, BorderSide side) {
  return switch (shape) {
    final InputBorder input => input.copyWith(borderSide: side),
    final OutlinedBorder outlined => outlined.copyWith(side: side),
    _ => shape,
  };
}

/// Applies only the semantic floating-surface roles and retains Yaru's menu
/// geometry, item states, padding, and motion.
MenuStyle _semanticMenuSurfaceStyle(
  MenuStyle? base, {
  required Color color,
  required Color shadowColor,
  required BorderSide side,
}) {
  return (base ?? const MenuStyle()).copyWith(
    backgroundColor: WidgetStatePropertyAll(color),
    surfaceTintColor: WidgetStatePropertyAll(color),
    shadowColor: WidgetStatePropertyAll(shadowColor),
    side: WidgetStatePropertyAll(side),
  );
}

/// Applies runtime semantic colors and typography without replacing Yaru's
/// geometry, focus treatment, hover/press overlays, or motion defaults.
ButtonStyle _semanticButtonStyle(
  ButtonStyle? base, {
  required Color foreground,
  required Color background,
  Color? selectedBackground,
  required Color disabledForeground,
  required Color disabledBackground,
  WidgetStateProperty<TextStyle?>? textStyle,
}) {
  return (base ?? const ButtonStyle()).copyWith(
    textStyle: textStyle,
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledForeground;
      }
      return foreground;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledForeground;
      }
      return foreground;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return disabledBackground;
      }
      if (selectedBackground != null && states.contains(WidgetState.selected)) {
        return selectedBackground;
      }
      return background;
    }),
  );
}
