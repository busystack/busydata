// Shared presentation adapted from BusyMark a5ee774470dfcda546398a153800426f504691be
// (Apache-2.0). BusyData retains its owned dialog and native-menu lifecycles.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

import '../l10n/l10n.dart';
import '../platform/native_menu_service.dart';
import 'busydata_glyphs.dart';
import 'busydata_surface_colors.dart';
import 'common/busydata_design_values.dart';

export 'busydata_search_field.dart';
export 'common/busydata_design_values.dart' show BusyDataMotion;

abstract final class BusyDataSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double headerInset = 6;
  static const double sm = 8;
  static const double smPlus = 10;
  static const double md = 12;
  static const double mdPlus = 14;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double tooltipHorizontal = 10;
  static const double tooltipVertical = 6;
}

abstract final class BusyDataInsets {
  static const sidebarList = EdgeInsets.fromLTRB(
    BusyDataSpacing.sm,
    BusyDataSpacing.xxs,
    BusyDataSpacing.sm,
    BusyDataSpacing.smPlus,
  );
  static const settingsPage = EdgeInsets.fromLTRB(
    BusyDataSpacing.xl,
    BusyDataSpacing.mdPlus,
    BusyDataSpacing.xl,
    BusyDataSpacing.xxl,
  );
}

abstract final class BusyDataRadius {
  static const double sm = 4;
  static const double tooltip = kYaruButtonRadius;
  static const double md = 8;
  static const double lg = kYaruContainerRadius;
  static const double headerButton = kYaruButtonRadius;
  static const double window = kYaruWindowRadius;
  static const double pill = 999;
}

abstract final class BusyDataSizes {
  static const double contentWidth = 760;
  static const double paneHeaderHeight = 38;
  static const double documentStatusBarHeight = 28;
  static const double compactIconButton = 24;
  static const double compactIcon = 13;
  static const double sidebarTreeDepthIndent = 14;
  static const double sidebarTreeControl = 18;
  static const double sidebarTreeArrow = 14;
  static const double sidebarWidth = 300;
  static const double settingsSidebarBreakpoint = sidebarWidth + 520;
  static const double settingsControlBreakpoint = 560;
  static const double detailsWidth = 700;
  static const double compactDetailsWidth = 700;
  static const double comboWidth = 220;
  static const double selectorButtonMaxWidth = 256;
  static const double toolbarHeight = kYaruTitleBarHeight;
  static const double onboardingContentMaxWidth = 480;
  static const double sidebarRowHeight = 36;
  static const double taskRowMinHeight = 48;
  static const double iconSm = 16;
  static const double iconMd = kYaruIconSize;
  static const double iconLg = 22;
  static const double headerIconButton = kYaruTitleBarItemHeight;
  static const double headerIcon = kYaruIconSize;
  static const double sidebarActionButton = headerIconButton;
  static const double sidebarActionIcon = headerIcon;
  static const double popoverActionButton = kYaruTitleBarItemHeight;
  static const double popoverActionIcon = iconSm;
  static const double popoverArrowWidth = 18;
  static const double popoverArrowHeight = 10;
  static const double tooltipMinHeight = 30;
}

abstract final class BusyDataFormLayout {
  static const double comboInlineMaxFraction = 0.46;
}

/// BusyData's single deliberate adjustment to Yaru's surface depth.
///
/// Grouped cards need a little more separation from the application canvas.
/// Floating controls keep the elevations supplied by Yaru; feature widgets
/// must not define their own elevations or shadow geometry.
abstract final class BusyDataElevation {
  static const double surface = 2;
  static const double groupedCard = 2;
}

abstract final class BusyDataStroke {
  static const double hairline = 1;
  static const double outline = 1;
  static const double sourceCursor = 1.4;
}

abstract final class BusyDataTypography {
  static const monoFontFamily = 'Ubuntu Mono';
  static const monoFontFamilyFallback = [
    'Noto Sans Arabic',
    'Noto Sans Mono',
    'DejaVu Sans Mono',
    'DejaVu Sans',
  ];
  static const sourceEditorLineHeight = 1.6;
  static const codeLineHeight = 1.45;
  static const sourceLineNumberScale = .92;
}

abstract final class BusyDataAlpha {
  static const double sourceCursor = .82;
  static const double groupedRowLightHoverStrength = 0.50;
  static const double tooltipBackground = 0.80;
  static const double tooltipBorder = 0.10;
}

/// Cross-toolkit tooltip visuals.
///
/// Flutter chrome and retained GTK surfaces render separate tooltip widgets.
/// This contract keeps their surface geometry and palette identical while
/// allowing both toolkits to retain native positioning and accessibility.
abstract final class BusyDataTooltipStyle {
  static final Color background = Colors.black.withValues(
    alpha: BusyDataAlpha.tooltipBackground,
  );
  static const Color foreground = Colors.white;
  static final Color border = Colors.white.withValues(
    alpha: BusyDataAlpha.tooltipBorder,
  );
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: BusyDataSpacing.tooltipHorizontal,
    vertical: BusyDataSpacing.tooltipVertical,
  );
  static const BorderRadius borderRadius = BorderRadius.all(
    Radius.circular(BusyDataRadius.tooltip),
  );
  static const BoxConstraints constraints = BoxConstraints(
    minHeight: BusyDataSizes.tooltipMinHeight,
  );
}

enum BusyDataPopoverShadowRole { standard, details }

abstract final class BusyDataShadow {
  static const double floatingBlur = 24;
  static const Offset floatingOffset = Offset(0, 8);
  static const double windowMargin = 32;

  /// The native libadwaita/Yaru card depth used by `.card` and
  /// `list.boxed-list`.
  ///
  /// Flutter's physical elevation shadow is deliberately biased toward the
  /// bottom edge. Native boxed lists instead combine a quiet perimeter with
  /// two compact layers, which keeps the top edge legible without making the
  /// card look detached from the page.
  static List<BoxShadow> nativeCardShadows(Color semanticShadow) {
    Color layer(double opacity) {
      return semanticShadow.withValues(alpha: semanticShadow.a * opacity);
    }

    // Flutter paints later shadows over earlier ones, so keep the native CSS
    // perimeter last and the broadest layer first.
    return [
      BoxShadow(
        color: layer(0.03),
        blurRadius: 6,
        spreadRadius: 2,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: layer(0.07),
        blurRadius: 3,
        spreadRadius: 1,
        offset: const Offset(0, 1),
      ),
      BoxShadow(color: layer(0.03), spreadRadius: 1),
    ];
  }

  static List<BoxShadow> nativeCardShadowsFor(BuildContext context) {
    final theme = Theme.of(context);
    return nativeCardShadows(
      CardTheme.of(context).shadowColor ?? theme.colorScheme.shadow,
    );
  }

  /// Current libadwaita popover depth, expressed as native CSS layers.
  ///
  /// A physical Material elevation uses a directional spot shadow and is
  /// therefore a poor match for an anchored Linux popover. These two restrained
  /// layers mirror libadwaita's popover profile: a defined near edge over a
  /// broad, low-opacity ambient shadow.
  static List<BoxShadow> nativePopoverShadows(
    Color semanticShadow, {
    BusyDataPopoverShadowRole role = BusyDataPopoverShadowRole.standard,
  }) {
    Color layer(double opacity) {
      return semanticShadow.withValues(alpha: semanticShadow.a * opacity);
    }

    final (ambientBlur, nearBlur) = switch (role) {
      BusyDataPopoverShadowRole.standard => (14.0, 5.0),
      // Details carry more visual content than a compact menu. Preserve the
      // same native depth and semantic color while tightening only the blur
      // by half a pixel.
      BusyDataPopoverShadowRole.details => (13.5, 4.5),
    };

    // ShapeDecoration paints in declaration order. Put the ambient layer
    // first so the defined near edge remains above it, matching CSS stacking.
    return [
      BoxShadow(
        color: layer(0.05),
        blurRadius: ambientBlur,
        spreadRadius: 3,
        offset: const Offset(0, 2),
      ),
      BoxShadow(
        color: layer(0.09),
        blurRadius: nearBlur,
        spreadRadius: 1,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> nativePopoverShadowsFor(
    BuildContext context, {
    BusyDataPopoverShadowRole role = BusyDataPopoverShadowRole.standard,
  }) {
    return nativePopoverShadows(
      Theme.of(context).colorScheme.shadow,
      role: role,
    );
  }

  /// Viewport space required for the farthest libadwaita popover shadow.
  ///
  /// Flutter's blur mask extends to roughly three standard deviations. Derive
  /// the reservation from the shared profile so geometry and paint cannot
  /// silently drift apart.
  static double get nativePopoverPaintMargin {
    final shadows = nativePopoverShadows(const Color(0xFF000000));
    final extent = shadows.fold<double>(0, (maximum, shadow) {
      final blurExtent = ui.Shadow.convertRadiusToSigma(shadow.blurRadius) * 3;
      final offsetExtent = math.max(
        shadow.offset.dx.abs(),
        shadow.offset.dy.abs(),
      );
      return math.max(maximum, blurExtent + shadow.spreadRadius + offsetExtent);
    });
    return extent.ceilToDouble();
  }

  static Color floatingColor(BuildContext context) {
    return BusyDataSurfaceColors.of(context).shade;
  }

  static List<BoxShadow> floatingShadows(Color color) {
    return [
      BoxShadow(color: color, blurRadius: floatingBlur, offset: floatingOffset),
    ];
  }

  static List<BoxShadow> floatingShadowsFor(BuildContext context) {
    return floatingShadows(floatingColor(context));
  }

  static List<BoxShadow> windowShadows(Color color) {
    return [
      BoxShadow(
        color: color.withValues(alpha: color.a * 0.75),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: color.withValues(alpha: color.a * 0.45),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
      BoxShadow(
        color: color.withValues(alpha: color.a * 0.25),
        blurRadius: 3,
        offset: const Offset(0, 1),
      ),
    ];
  }

  static List<BoxShadow> windowShadowsFor(BuildContext context) {
    return windowShadows(floatingColor(context));
  }

  static List<BoxShadow> edgeShadows(Color color, {required bool below}) {
    return [
      BoxShadow(
        color: color,
        blurRadius: floatingBlur / 2,
        offset: Offset(
          0,
          below ? floatingOffset.dy / 2 : -floatingOffset.dy / 2,
        ),
      ),
    ];
  }

  static List<BoxShadow> edgeShadowsFor(
    BuildContext context, {
    required bool below,
  }) {
    return edgeShadows(floatingColor(context), below: below);
  }
}

enum BusyDataPopoverArrowSide { top, bottom }

class BusyDataPopoverSurface extends StatelessWidget {
  const BusyDataPopoverSurface({
    super.key,
    required this.child,
    required this.color,
    this.outlineColor,
    this.arrowSide = BusyDataPopoverArrowSide.top,
    this.arrowAlignment = 0.5,
    this.padding = EdgeInsets.zero,
    this.shadowRole = BusyDataPopoverShadowRole.standard,
  });

  final Widget child;
  final Color color;
  final Color? outlineColor;
  final BusyDataPopoverArrowSide arrowSide;
  final double arrowAlignment;
  final EdgeInsetsGeometry padding;
  final BusyDataPopoverShadowRole shadowRole;

  @override
  Widget build(BuildContext context) {
    final arrowHeight = BusyDataSizes.popoverArrowHeight;
    final alignment = arrowAlignment.clamp(0.0, 1.0).toDouble();
    final shape = _BusyDataPopoverBorder(
      arrowSide: arrowSide,
      alignment: alignment,
    );
    final outlineShape = shape.copyWith(
      side: BorderSide(
        color: outlineColor ?? BusyDataSurfaceColors.of(context).floatingBorder,
        width: BusyDataStroke.outline,
        strokeAlign: BorderSide.strokeAlignInside,
      ),
    );
    final paddedChild = Padding(
      padding: EdgeInsets.only(
        top: arrowSide == BusyDataPopoverArrowSide.top ? arrowHeight : 0,
        bottom: arrowSide == BusyDataPopoverArrowSide.bottom ? arrowHeight : 0,
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shadows: BusyDataShadow.nativePopoverShadowsFor(
          context,
          role: shadowRole,
        ),
        shape: shape,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(shape: outlineShape),
          child: paddedChild,
        ),
      ),
    );
  }
}

/// A rich anchored-content adapter for the shared GTK-style popover surface.
///
/// GTK exposes one popover surface role irrespective of the child content.
/// This adapter contributes only details layout; [BusyDataPopoverSurface]
/// supplies the shared semantic fill, perimeter, and libadwaita shadow.
class BusyDataContentPopoverSurface extends StatelessWidget {
  const BusyDataContentPopoverSurface({
    super.key,
    required this.child,
    this.arrowSide = BusyDataPopoverArrowSide.top,
    this.arrowAlignment = 0.5,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BusyDataPopoverArrowSide arrowSide;
  final double arrowAlignment;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = BusyDataSurfaceColors.of(context);
    return BusyDataPopoverSurface(
      color: colors.popover,
      outlineColor: colors.floatingBorder,
      arrowSide: arrowSide,
      arrowAlignment: arrowAlignment,
      padding: padding,
      shadowRole: BusyDataPopoverShadowRole.details,
      child: child,
    );
  }
}

class _BusyDataPopoverBorder extends OutlinedBorder {
  const _BusyDataPopoverBorder({
    required this.arrowSide,
    required this.alignment,
    super.side = BorderSide.none,
  });

  final BusyDataPopoverArrowSide arrowSide;
  final double alignment;

  @override
  _BusyDataPopoverBorder copyWith({BorderSide? side}) {
    return _BusyDataPopoverBorder(
      arrowSide: arrowSide,
      alignment: alignment,
      side: side ?? this.side,
    );
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _busyDataPopoverPath(rect, side: arrowSide, alignment: alignment);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) {
      return;
    }
    final path = getOuterPath(rect, textDirection: textDirection);
    canvas
      ..save()
      ..clipPath(path)
      ..drawPath(
        path,
        side.toPaint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = side.width * 2,
      )
      ..restore();
  }

  @override
  _BusyDataPopoverBorder scale(double t) {
    return _BusyDataPopoverBorder(
      arrowSide: arrowSide,
      alignment: alignment,
      side: side.scale(t),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _BusyDataPopoverBorder &&
            other.arrowSide == arrowSide &&
            other.alignment == alignment &&
            other.side == side;
  }

  @override
  int get hashCode => Object.hash(arrowSide, alignment, side);
}

Path _busyDataPopoverPath(
  Rect rect, {
  required BusyDataPopoverArrowSide side,
  required double alignment,
}) {
  if (rect.isEmpty) {
    return Path();
  }
  final arrowHalfWidth = math.min(
    BusyDataSizes.popoverArrowWidth / 2,
    rect.width / 2,
  );
  final arrowHeight = math.min(
    BusyDataSizes.popoverArrowHeight,
    rect.height / 2,
  );
  final bodyHeight = rect.height - arrowHeight;
  final radius = Radius.circular(
    math.min(BusyDataRadius.md, math.min(rect.width, bodyHeight) / 2),
  );
  final bodyTop = side == BusyDataPopoverArrowSide.top
      ? rect.top + arrowHeight
      : rect.top;
  final bodyBottom = side == BusyDataPopoverArrowSide.bottom
      ? rect.bottom - arrowHeight
      : rect.bottom;
  final body = RRect.fromRectAndRadius(
    Rect.fromLTRB(rect.left, bodyTop, rect.right, bodyBottom),
    radius,
  );
  final preferredArrowInset = radius.x + arrowHalfWidth;
  final minArrowCenter = math.min(rect.width / 2, preferredArrowInset);
  final maxArrowCenter = math.max(minArrowCenter, rect.width - minArrowCenter);
  final arrowCenter =
      (rect.width * alignment)
          .clamp(minArrowCenter, maxArrowCenter)
          .toDouble() +
      rect.left;

  final bodyPath = Path()..addRRect(body);
  final arrowPath = Path();
  if (side == BusyDataPopoverArrowSide.top) {
    arrowPath
      ..moveTo(arrowCenter - arrowHalfWidth, bodyTop)
      ..lineTo(arrowCenter, rect.top)
      ..lineTo(arrowCenter + arrowHalfWidth, bodyTop)
      ..close();
  } else {
    arrowPath
      ..moveTo(arrowCenter - arrowHalfWidth, bodyBottom)
      ..lineTo(arrowCenter, rect.bottom)
      ..lineTo(arrowCenter + arrowHalfWidth, bodyBottom)
      ..close();
  }
  return Path.combine(PathOperation.union, bodyPath, arrowPath);
}

RoundedRectangleBorder busyDataHeaderButtonShape() {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(BusyDataRadius.headerButton),
  );
}

/// An icon button whose BusyData semantic state style remains authoritative.
///
/// `YaruIconButton` supplies excellent defaults, but in Yaru 10.2 its
/// internally complete [ButtonStyle] is merged ahead of the caller's style.
/// That makes caller-provided foreground, background, and overlay state
/// properties unreachable. This adapter keeps Flutter's native button
/// interaction model and Yaru's optional keyboard-focus border while allowing
/// the shared BusyData header style to resolve those semantic states.
class BusyDataHeaderControlStyleScope extends InheritedWidget {
  const BusyDataHeaderControlStyleScope({
    super.key,
    required this.foregroundColor,
    required this.disabledForegroundColor,
    required this.backgroundColor,
    required this.overlayColor,
    required super.child,
  });

  final Color foregroundColor;
  final Color disabledForegroundColor;
  final WidgetStateProperty<Color?> backgroundColor;
  final WidgetStateProperty<Color?> overlayColor;

  static BusyDataHeaderControlStyleScope? maybeOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<BusyDataHeaderControlStyleScope>();

  @override
  bool updateShouldNotify(BusyDataHeaderControlStyleScope oldWidget) =>
      foregroundColor != oldWidget.foregroundColor ||
      disabledForegroundColor != oldWidget.disabledForegroundColor ||
      backgroundColor != oldWidget.backgroundColor ||
      overlayColor != oldWidget.overlayColor;
}

class BusyDataHeaderIconButton extends StatelessWidget {
  const BusyDataHeaderIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.iconSize = BusyDataSizes.headerIcon,
    this.foregroundColor,
    this.backgroundColor,
    this.overlayColor,
    this.fixedSize,
    this.shape,
    this.focusNode,
    this.isSelected,
    this.selectedIcon,
    this.disabledForegroundColor,
    this.focusBorderRadius,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;
  final double iconSize;
  final Color? foregroundColor;
  final WidgetStateProperty<Color?>? backgroundColor;
  final WidgetStateProperty<Color?>? overlayColor;
  final Size? fixedSize;
  final OutlinedBorder? shape;
  final FocusNode? focusNode;
  final bool? isSelected;
  final Widget? selectedIcon;
  final Color? disabledForegroundColor;
  final double? focusBorderRadius;

  @override
  Widget build(BuildContext context) {
    final inherited = BusyDataHeaderControlStyleScope.maybeOf(context);
    final yaruDefaults = YaruIconButton(
      icon: const SizedBox.shrink(),
      iconSize: BusyDataSizes.headerIconButton,
    ).defaultStyleOf(context);
    final button = IconButton(
      tooltip: tooltip,
      icon: icon,
      iconSize: iconSize,
      onPressed: onPressed,
      focusNode: focusNode,
      isSelected: isSelected,
      selectedIcon: selectedIcon,
      style:
          busyDataHeaderIconButtonStyle(
                context,
                foregroundColor: foregroundColor ?? inherited?.foregroundColor,
                disabledForegroundColor:
                    disabledForegroundColor ??
                    inherited?.disabledForegroundColor,
                backgroundColor: backgroundColor ?? inherited?.backgroundColor,
                overlayColor: overlayColor ?? inherited?.overlayColor,
              )
              .copyWith(
                fixedSize: fixedSize == null
                    ? null
                    : WidgetStatePropertyAll(fixedSize),
                minimumSize: fixedSize == null
                    ? null
                    : WidgetStatePropertyAll(fixedSize),
                maximumSize: fixedSize == null
                    ? null
                    : WidgetStatePropertyAll(fixedSize),
                shape: shape == null ? null : WidgetStatePropertyAll(shape),
              )
              .merge(yaruDefaults),
    );
    final presented = YaruTheme.maybeOf(context)?.focusBorders == true
        ? YaruFocusBorder.primary(
            borderRadius: BorderRadius.circular(
              focusBorderRadius ??
                  (shape is CircleBorder ? 100 : BusyDataRadius.headerButton),
            ),
            child: button,
          )
        : button;
    return MergeSemantics(
      child: Semantics(label: semanticLabel ?? tooltip, child: presented),
    );
  }
}

ButtonStyle busyDataHeaderIconButtonStyle(
  BuildContext context, {
  Color? foregroundColor,
  Color? disabledForegroundColor,
  WidgetStateProperty<Color?>? backgroundColor,
  WidgetStateProperty<Color?>? overlayColor,
}) {
  final disabledForeground =
      disabledForegroundColor ??
      BusyDataSurfaceColors.of(context).disabledForeground;
  return ButtonStyle(
    fixedSize: const WidgetStatePropertyAll(
      Size.square(BusyDataSizes.headerIconButton),
    ),
    minimumSize: const WidgetStatePropertyAll(
      Size.square(BusyDataSizes.headerIconButton),
    ),
    maximumSize: const WidgetStatePropertyAll(
      Size.square(BusyDataSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(EdgeInsets.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    animationDuration: BusyDataMotion.fast,
    splashFactory: NoSplash.splashFactory,
    foregroundColor: foregroundColor == null
        ? null
        : WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? disabledForeground
                : foregroundColor;
          }),
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: WidgetStatePropertyAll(busyDataHeaderButtonShape()),
  );
}

ButtonStyle busyDataHeaderTextButtonStyle(
  BuildContext context, {
  Color? foregroundColor,
  WidgetStateProperty<Color?>? backgroundColor,
  WidgetStateProperty<Color?>? overlayColor,
}) {
  final disabledForeground = BusyDataSurfaceColors.of(
    context,
  ).disabledForeground;
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(BusyDataSizes.headerIconButton, BusyDataSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: BusyDataSpacing.md),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.disabled)
          ? disabledForeground
          : foregroundColor;
    }),
    backgroundColor: backgroundColor,
    overlayColor: overlayColor,
    side: const WidgetStatePropertyAll(BorderSide.none),
    shape: WidgetStatePropertyAll(busyDataHeaderButtonShape()),
  );
}

WidgetStateProperty<Color?> busyDataSubtleButtonBackground(
  BuildContext context,
) {
  final colorScheme = Theme.of(context).colorScheme;
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.pressed)) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.12);
    }
    if (states.contains(WidgetState.hovered)) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.08);
    }
    if (states.contains(WidgetState.focused)) {
      return colorScheme.onSurfaceVariant.withValues(alpha: 0.10);
    }
    return null;
  });
}

WidgetStateProperty<Color?> busyDataHeaderButtonBackground(
  BuildContext context,
) {
  final surfaceColors = BusyDataSurfaceColors.of(context);
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return surfaceColors.disabledControl;
    }
    if (states.contains(WidgetState.pressed) ||
        states.contains(WidgetState.selected)) {
      return surfaceColors.controlActive;
    }
    if (states.contains(WidgetState.hovered) ||
        states.contains(WidgetState.focused)) {
      return surfaceColors.controlHover;
    }
    return surfaceColors.control;
  });
}

/// Tracks focus-visible input modality for BusyData push buttons.
///
/// Desktop starts keyboard-visible so initial programmatic/autofocus remains
/// discoverable. A pointer press hides the ring before any focus request made
/// by that interaction; a hardware key restores it before traversal runs.
class _BusyDataKeyboardFocusVisibility extends ValueNotifier<bool> {
  _BusyDataKeyboardFocusVisibility() : super(true) {
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
  }

  static final instance = _BusyDataKeyboardFocusVisibility();

  FocusManager? _registeredFocusManager;

  void ensureRegistered() {
    final focusManager = FocusManager.instance;
    if (identical(_registeredFocusManager, focusManager)) {
      return;
    }
    _registeredFocusManager?.removeEarlyKeyEventHandler(_handleKeyEvent);
    focusManager.addEarlyKeyEventHandler(_handleKeyEvent);
    _registeredFocusManager = focusManager;
  }

  void _handlePointerEvent(PointerEvent event) {
    if (event is PointerDownEvent && value) {
      value = false;
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if ((event is KeyDownEvent || event is KeyRepeatEvent) && !value) {
      value = true;
    }
    return KeyEventResult.ignored;
  }
}

/// BusyData's shared Yaru-backed desktop search entry.
///
/// Flutter-owned Linux header layouts delegate geometry and interaction states
/// to Yaru instead of restyling a raw [TextField]. Header callers may supply
/// GTK-themed artwork through the optional leading and clear slots.
abstract final class BusyDataPushButton {
  /// A neutral desktop action. Yaru renders this with its standard filled
  /// control surface and native interaction geometry.
  static FilledButton standard({
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    return FilledButton(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }

  /// A suggested action. Yaru reserves the accent-filled elevated role for
  /// the single preferred action in a group.
  static ElevatedButton suggested({
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    return ElevatedButton(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: style,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }

  /// A destructive desktop action.
  ///
  /// Keep destructive emphasis on the final action in a confirmation dialog;
  /// ordinary destructive rows should continue to use semantic error
  /// foregrounds without becoming accent-filled buttons.
  static ElevatedButton destructive({
    required BuildContext context,
    required Widget child,
    required VoidCallback? onPressed,
    VoidCallback? onLongPress,
    ValueChanged<bool>? onHover,
    ValueChanged<bool>? onFocusChange,
    ButtonStyle? style,
    FocusNode? focusNode,
    bool autofocus = false,
    Clip clipBehavior = Clip.none,
    WidgetStatesController? statesController,
    Key? key,
  }) {
    final theme = Theme.of(context);
    final colors = BusyDataSurfaceColors.of(context);
    final background = theme.brightness == Brightness.dark
        ? const Color(0xFFC01C28)
        : theme.colorScheme.error;
    final foreground = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.colorScheme.onError;
    final destructiveStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.disabledControl
            : background,
      ),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.disabledForeground
            : foreground,
      ),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? colors.disabledForeground
            : foreground,
      ),
    ).merge(style);
    return ElevatedButton(
      key: key,
      onPressed: onPressed,
      onLongPress: onLongPress,
      onHover: onHover,
      onFocusChange: onFocusChange,
      style: destructiveStyle,
      focusNode: focusNode,
      autofocus: autofocus,
      clipBehavior: clipBehavior,
      statesController: statesController,
      child: child,
    );
  }
}

/// A contained circular action for compact popover toolbars.
///
/// Yaru owns focus, hover, press feedback, and desktop control geometry. The
/// outer semantic surface only adds the persistent containment used by Ubuntu
/// detail-popover actions.

Color busyDataSelectedBackground(BuildContext context) {
  return BusyDataSurfaceColors.of(context).controlActive;
}

Color busyDataHoverBackground(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Color.alphaBlend(
    colorScheme.onSurface.withValues(alpha: 0.06),
    colorScheme.surface,
  );
}

Color busyDataRowHoverColor(BuildContext context) {
  final theme = Theme.of(context);
  final hover = theme.hoverColor;
  if (theme.colorScheme.isHighContrast ||
      theme.colorScheme.brightness == Brightness.dark) {
    return hover;
  }
  return hover.withValues(
    alpha: hover.a * BusyDataAlpha.groupedRowLightHoverStrength,
  );
}

/// Input decoration inherited by controls hosted in a grouped-list row.
///
/// The enclosing [BusyDataGroupedList] owns the surface, outline, shadow,
/// padding, and separators. Yaru and Flutter entry controls continue to own
/// their editing behavior while this theme prevents a second input surface
/// from being painted inside the native grouped row.
Color busyDataModalBarrierColor(BuildContext context) {
  // The semantic shade already carries the toolkit's intended modal opacity.
  // Consumers must not multiply or cap it and thereby create mode-specific
  // dimming behavior.
  return BusyDataSurfaceColors.of(context).shade;
}

Color busyDataPanelBorder(BuildContext context) {
  return Theme.of(context).colorScheme.outlineVariant;
}

TextStyle? busyDataSectionHeaderStyle(BuildContext context) =>
    Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: BusyDataSurfaceColors.of(context).foreground,
      fontWeight: FontWeight.w700,
    );

/// The semantic title style used by Flutter-rendered window headers.
///
/// Linux applies GTK's `title` style class to the native header label. The
/// Flutter fallback keeps the theme's title geometry and color, and mirrors
/// only that semantic emphasis.
TextStyle busyDataHeaderTitleStyle(BuildContext context) {
  return (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.bold,
  );
}

/// The stronger GTK-sized wordmark used only by the Linux sidebar header.
TextStyle busyDataHeaderBrandStyle(BuildContext context) {
  return (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
    fontWeight: FontWeight.w800,
  );
}

Widget _busyDataGroupedRowSubtitle(
  BuildContext context,
  Widget child, {
  bool enabled = true,
}) {
  final colors = BusyDataSurfaceColors.of(context);
  return DefaultTextStyle.merge(
    style: TextStyle(
      color: enabled ? colors.mutedForeground : colors.disabledForeground,
    ),
    child: child,
  );
}

class BusyDataClamp extends StatelessWidget {
  const BusyDataClamp({
    super.key,
    required this.child,
    this.maxWidth = BusyDataSizes.contentWidth,
    this.scrollable = true,
    this.center = true,
    this.padding = EdgeInsets.zero,
    this.margin = const EdgeInsets.all(BusyDataSpacing.lg),
    this.controller,
  });

  final Widget child;
  final double maxWidth;
  final bool scrollable;
  final bool center;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final clamped = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: margin,
      padding: padding,
      child: child,
    );

    final body = center
        ? Align(alignment: Alignment.topCenter, child: clamped)
        : clamped;

    return scrollable
        ? SingleChildScrollView(controller: controller, child: body)
        : body;
  }
}

/// Semantic parent surfaces that can contain a grouped card.
///
/// GTK's card role is a contextual layer in dark themes. Keeping the parent
/// role explicit lets the shared grouped-card adapter resolve one opaque paint
/// color for Flutter's elevated [Material] without tying every card to the
/// main window background.
enum BusyDataSurfaceRole { window, view, sidebar, dialog, popover }

class BusyDataSurfaceScope extends InheritedWidget {
  const BusyDataSurfaceScope({
    super.key,
    required this.role,
    required super.child,
  });

  final BusyDataSurfaceRole role;

  static BusyDataSurfaceRole roleOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<BusyDataSurfaceScope>()
            ?.role ??
        BusyDataSurfaceRole.window;
  }

  @override
  bool updateShouldNotify(BusyDataSurfaceScope oldWidget) {
    return role != oldWidget.role;
  }
}

Color busyDataGroupedSurfaceColor(
  BuildContext context, {
  BusyDataSurfaceRole? parentRole,
}) {
  final colors = BusyDataSurfaceColors.of(context);
  final role = parentRole ?? BusyDataSurfaceScope.roleOf(context);
  if (role == BusyDataSurfaceRole.window) {
    // The native bridge already resolves the opaque card role against the
    // window. Reuse that authoritative value exactly instead of recomputing
    // an equivalent color with different floating-point channel values.
    return colors.card;
  }
  final parent = switch (role) {
    BusyDataSurfaceRole.window => colors.window,
    BusyDataSurfaceRole.view => colors.view,
    BusyDataSurfaceRole.sidebar => colors.sidebar,
    BusyDataSurfaceRole.dialog => colors.dialog,
    BusyDataSurfaceRole.popover => colors.popover,
  };
  return Color.alphaBlend(colors.groupedSurface, parent);
}

class BusyDataGroupedList extends StatelessWidget {
  const BusyDataGroupedList({
    super.key,
    this.title,
    this.description,
    this.titleStyle,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: BusyDataSpacing.xs),
    this.filled = false,
  });

  final String? title;
  final String? description;
  final TextStyle? titleStyle;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        top: title == null && (description == null || description!.isEmpty)
            ? BusyDataSpacing.md
            : BusyDataSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: padding,
              child: Semantics(
                container: true,
                header: true,
                child: Text(
                  title!,
                  style: titleStyle ?? busyDataSectionHeaderStyle(context),
                ),
              ),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: BusyDataSpacing.xs),
              Padding(
                padding: padding,
                child: Text(
                  description!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            const SizedBox(height: BusyDataSpacing.sm),
          ],
          _BusyDataGroupedListSurface(filled: filled, children: children),
        ],
      ),
    );
  }
}

class BusyDataSurface extends StatelessWidget {
  const BusyDataSurface({
    super.key,
    required this.child,
    this.filled = true,
    this.color,
    this.side,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final bool filled;
  final Color? color;
  final BorderSide? side;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final cardTheme = CardTheme.of(context);
    final surfaceColors = BusyDataSurfaceColors.of(context);
    final fallbackShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(BusyDataRadius.lg),
    );
    final themedShape = cardTheme.shape;
    final ShapeBorder shape;
    if (themedShape is OutlinedBorder) {
      shape = side == null ? themedShape : themedShape.copyWith(side: side);
    } else if (themedShape != null && side == null) {
      shape = themedShape;
    } else {
      shape = fallbackShape.copyWith(side: side ?? BorderSide.none);
    }
    final surfaceColor = filled
        ? color ?? cardTheme.color ?? surfaceColors.card
        : Colors.transparent;
    if (filled) {
      final shadowShape = shape is OutlinedBorder
          ? shape.copyWith(side: BorderSide.none)
          : shape;
      return DecoratedBox(
        decoration: ShapeDecoration(
          shape: shadowShape,
          shadows: BusyDataShadow.nativeCardShadowsFor(context),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          semanticContainer: false,
          color: surfaceColor,
          // Native card depth is painted once by the shared ShapeDecoration
          // above. Keep Card for Yaru geometry, clipping, and semantics while
          // suppressing Material's directional duplicate.
          shadowColor: Colors.transparent,
          shape: shape,
          clipBehavior: clipBehavior,
          child: child,
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      elevation: 0,
      surfaceTintColor: cardTheme.surfaceTintColor ?? Colors.transparent,
      shape: shape,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class BusyDataGroupedSurface extends StatelessWidget {
  const BusyDataGroupedSurface({
    super.key,
    required this.child,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return BusyDataSurface(
      color: busyDataGroupedSurfaceColor(context),
      side: highContrast
          ? BorderSide(color: Theme.of(context).colorScheme.outline)
          : null,
      clipBehavior: clipBehavior,
      child: child,
    );
  }
}

class BusyDataSidebarSurface extends StatelessWidget {
  const BusyDataSidebarSurface({
    super.key,
    required this.child,
    this.showEndBorder = true,
  });

  final Widget child;
  final bool showEndBorder;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyDataSurfaceColors.of(context);
    final content = showEndBorder
        ? DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: BorderDirectional(
                end: BorderSide(
                  color: surfaceColors.sidebarBorder,
                  width: BusyDataStroke.outline,
                ),
              ),
            ),
            child: child,
          )
        : child;
    return Material(color: surfaceColors.sidebar, child: content);
  }
}

/// A GTK-style navigation list for a persistent desktop sidebar.
///
/// The list delegates row interaction, focus handling, and selection geometry
/// to Yaru's master-detail controls while mapping their visual states to
/// BusyData's semantic surface roles.
class _BusyDataGroupedListSurface extends StatelessWidget {
  const _BusyDataGroupedListSurface({
    required this.filled,
    required this.children,
  });

  final bool filled;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surfaceColors = BusyDataSurfaceColors.of(context);
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index < children.length - 1)
            Divider(height: 1, thickness: 1, color: surfaceColors.cardShade),
        ],
      ],
    );
    if (!filled) {
      return list;
    }
    return BusyDataGroupedSurface(child: list);
  }
}

typedef BusyDataRowActivationCallback =
    void Function(BuildContext context, Offset? globalPosition);

class BusyDataActionRow extends StatefulWidget {
  const BusyDataActionRow({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.subtitleWidget,
    this.leading,
    this.trailing,
    this.onTap,
    this.onActivated,
    this.enabled = true,
    this.tooltip,
    this.destructive = false,
    this.autofocus = false,
    this.hoverColor,
  }) : assert(onTap == null || onActivated == null);

  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? subtitleWidget;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final BusyDataRowActivationCallback? onActivated;
  final bool enabled;
  final String? tooltip;
  final bool destructive;
  final bool autofocus;
  final Color? hoverColor;

  @override
  State<BusyDataActionRow> createState() => _BusyDataActionRowState();
}

class _BusyDataActionRowState extends State<BusyDataActionRow> {
  final _focus = FocusNode(debugLabel: 'Action row');
  int? _primaryPointer;
  Offset? _pointerDownPosition;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant BusyDataActionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || widget.onActivated == null) {
      _clearPointer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final colors = BusyDataSurfaceColors.of(context);
    final titleStyle = widget.destructive
        ? TextStyle(
            color: widget.enabled
                ? colorScheme.error
                : colors.disabledForeground,
          )
        : null;
    final subtitle =
        widget.subtitleWidget ??
        (widget.subtitle == null || widget.subtitle!.isEmpty
            ? null
            : Text(
                widget.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ));
    final interactive =
        widget.enabled && (widget.onTap != null || widget.onActivated != null);
    final row = YaruListTile.square(
      leading: widget.leading,
      title:
          widget.titleWidget ??
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: titleStyle,
          ),
      subtitle: subtitle == null
          ? null
          : _busyDataGroupedRowSubtitle(
              context,
              subtitle,
              enabled: widget.enabled,
            ),
      trailing: widget.trailing,
      enabled: widget.enabled,
      focusNode: _focus,
      autofocus: widget.autofocus,
      hoverColor: widget.hoverColor ?? busyDataRowHoverColor(context),
      onTap: interactive ? _activate : null,
    );

    final trackedRow = widget.onActivated == null
        ? row
        : Listener(
            onPointerDown: widget.enabled ? _handlePointerDown : null,
            onPointerUp: widget.enabled ? _handlePointerUp : null,
            onPointerCancel: widget.enabled ? _handlePointerCancel : null,
            child: row,
          );

    final accessibleRow = Semantics(
      onFocus: interactive ? _focus.requestFocus : null,
      child: trackedRow,
    );
    if (widget.enabled || widget.tooltip == null) {
      return accessibleRow;
    }

    return Tooltip(
      message: widget.tooltip!,
      child: Opacity(opacity: 0.6, child: IgnorePointer(child: accessibleRow)),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) {
      return;
    }
    _primaryPointer = event.pointer;
    _pointerDownPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_primaryPointer != event.pointer) {
      return;
    }
    final pointer = event.pointer;
    scheduleMicrotask(() {
      if (mounted && _primaryPointer == pointer) {
        _clearPointer();
      }
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_primaryPointer == event.pointer) {
      _clearPointer();
    }
  }

  void _activate() {
    final onActivated = widget.onActivated;
    if (onActivated == null) {
      widget.onTap?.call();
      return;
    }
    final globalPosition = _pointerDownPosition;
    _clearPointer();
    onActivated(context, globalPosition);
  }

  void _clearPointer() {
    _primaryPointer = null;
    _pointerDownPosition = null;
  }
}

// GTK exposes a button's label but omits its string value. Keep the field and
// selected value together in one accessible name, without duplicate children.
String busyDataSelectedValueLabel(String field, String selected) =>
    field == selected || field.isEmpty ? selected : '$field: $selected';

class BusyDataComboRow<T> extends StatelessWidget {
  BusyDataComboRow({
    super.key,
    required this.title,
    required List<T> values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.subtitle,
    this.errorText,
    this.leading,
    this.enabled = true,
    this.tooltip,
    this.width = BusyDataSizes.comboWidth,
    this.trailingAction,
    this.selectorLeadingBuilder,
  }) : values = List<T>.unmodifiable(values) {
    if (this.values.isEmpty) {
      throw ArgumentError.value(
        values,
        'values',
        'A combo row requires at least one value.',
      );
    }
    if (this.values.toSet().length != this.values.length) {
      throw ArgumentError.value(
        values,
        'values',
        'A combo row requires unique values.',
      );
    }
    if (!this.values.contains(selected)) {
      throw ArgumentError.value(
        selected,
        'selected',
        'The selected value must be present in values.',
      );
    }
    if (!width.isFinite || width <= 0) {
      throw ArgumentError.value(
        width,
        'width',
        'The maximum value width must be finite and positive.',
      );
    }
  }

  final String title;
  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final String? subtitle;
  final String? errorText;
  final Widget? leading;
  final bool enabled;
  final String? tooltip;
  final double width;
  final Widget? trailingAction;
  final Widget Function(BuildContext context, T value)? selectorLeadingBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasError = errorText?.isNotEmpty ?? false;
        final subtitleWidget = hasError
            ? Text(
                errorText!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            : subtitle == null
            ? null
            : Text(subtitle!);
        final styledSubtitle = subtitleWidget == null
            ? null
            : _busyDataGroupedRowSubtitle(
                context,
                subtitleWidget,
                enabled: enabled,
              );
        final actionAllowance = trailingAction == null
            ? 0.0
            : BusyDataSizes.headerIconButton + BusyDataSpacing.xs;
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : width + BusyDataSpacing.md * 2 + actionAllowance;
        final maximumValueWidth =
            (availableWidth * BusyDataFormLayout.comboInlineMaxFraction -
                    actionAllowance)
                .clamp(0.0, width)
                .toDouble();
        final menuButton = BusyDataMenuButton<T>(
          tooltip: tooltip ?? title,
          entries: [
            for (final value in values)
              BusyDataMenuEntry(
                value: value,
                label: labelFor(value),
                role: BusyDataMenuEntryRole.radio,
                selected: value == selected,
              ),
          ],
          onSelected: (value) {
            if (value != selected) {
              onSelected(value);
            }
          },
          enabled: enabled,
          triggerBuilder: (context, trigger) {
            final colors = BusyDataSurfaceColors.of(context);
            final valueForeground = enabled
                ? colors.foreground
                : colors.disabledForeground;
            final value = ExcludeSemantics(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maximumValueWidth),
                child: DefaultTextStyle.merge(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: valueForeground),
                  child: IconTheme.merge(
                    data: IconThemeData(
                      color: valueForeground,
                      size: BusyDataSizes.iconSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (selectorLeadingBuilder?.call(context, selected)
                            case final selectedLeading?) ...[
                          selectedLeading,
                          const SizedBox(width: BusyDataSpacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            labelFor(selected),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: BusyDataSpacing.sm),
                        trigger.anchor(child: const Icon(YaruIcons.pan_down)),
                      ],
                    ),
                  ),
                ),
              ),
            );
            final row = YaruListTile.square(
              leading: leading == null
                  ? null
                  : ExcludeSemantics(child: leading!),
              title: ExcludeSemantics(child: Text(title)),
              subtitle: styledSubtitle == null
                  ? null
                  : ExcludeSemantics(child: styledSubtitle),
              trailing: value,
              onTap: trigger.onPressed,
              focusNode: trigger.focusNode,
              hoverColor: busyDataRowHoverColor(context),
              enabled: enabled,
            );
            final semanticRow = Semantics(
              container: true,
              button: true,
              enabled: enabled,
              expanded: trigger.isOpen,
              focusable: enabled,
              focused: trigger.focusNode.hasFocus,
              onFocus: enabled ? trigger.focusNode.requestFocus : null,
              onTap: enabled ? trigger.onPressed : null,
              label:
                  '${busyDataSelectedValueLabel(title, labelFor(selected))}${hasError
                      ? ', $errorText'
                      : subtitle == null || subtitle!.isEmpty
                      ? ''
                      : ', $subtitle'}',
              liveRegion: hasError,
              validationResult: hasError
                  ? ui.SemanticsValidationResult.invalid
                  : ui.SemanticsValidationResult.valid,
              child: ExcludeSemantics(
                child: BusyDataYaruFocusBorder(
                  focusNode: trigger.focusNode,
                  borderStrokeAlign: BorderSide.strokeAlignInside,
                  builder: (_, _) => row,
                ),
              ),
            );
            final interactionRow = trailingAction == null
                ? semanticRow
                : Row(
                    children: [
                      Expanded(child: semanticRow),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: BusyDataSpacing.md,
                        ),
                        child: trailingAction!,
                      ),
                    ],
                  );
            final statefulRow = ColoredBox(
              color: trigger.isOpen
                  ? busyDataRowHoverColor(context)
                  : Colors.transparent,
              child: interactionRow,
            );
            final boundedRow = constraints.hasBoundedWidth
                ? statefulRow
                : SizedBox(width: availableWidth, child: statefulRow);
            return tooltip == null
                ? boundedRow
                : Tooltip(
                    message: tooltip!,
                    excludeFromSemantics: true,
                    child: boundedRow,
                  );
          },
        );
        return menuButton;
      },
    );
  }
}

typedef BusyDataYaruFocusedControlBuilder =
    Widget Function(BuildContext context, FocusNode focusNode);

/// Presents Yaru's outline around the existing focus target during keyboard
/// navigation without adding another focus node or interaction handler.
///
/// Yaru 10.2.0's selection controls and toggle list tiles do not propagate
/// their internal target's focus to the [YaruFocusBorder] installed by
/// `hasFocusBorder`. Driving the same outline from the target's [FocusNode]
/// keeps the supported presentation while preserving traversal and gestures.
class BusyDataYaruFocusBorder extends StatefulWidget {
  const BusyDataYaruFocusBorder({
    super.key,
    required this.builder,
    this.focusNode,
    this.borderStrokeAlign,
  });

  final BusyDataYaruFocusedControlBuilder builder;
  final FocusNode? focusNode;
  final double? borderStrokeAlign;

  @override
  State<BusyDataYaruFocusBorder> createState() =>
      _BusyDataYaruFocusBorderState();
}

class _BusyDataYaruFocusBorderState extends State<BusyDataYaruFocusBorder> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _updateFocusNode();
  }

  @override
  void didUpdateWidget(covariant BusyDataYaruFocusBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _updateFocusNode();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _updateFocusNode() {
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final focusVisibility = _BusyDataKeyboardFocusVisibility.instance
      ..ensureRegistered();
    return ValueListenableBuilder<bool>(
      valueListenable: focusVisibility,
      builder: (context, keyboardInput, child) => YaruFocusBorder.primary(
        focused: true,
        onFocusChange: (_) {},
        borderColor: _focusNode.hasPrimaryFocus && keyboardInput
            ? null
            : Colors.transparent,
        borderStrokeAlign: widget.borderStrokeAlign,
        child: child!,
      ),
      child: widget.builder(context, _focusNode),
    );
  }
}

/// A Yaru switch with Libadwaita-style state colors and no external halo.
class BusyDataSwitch extends StatefulWidget {
  const BusyDataSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
    this.mouseCursor,
    this.onOffShapes,
    this.hasFocusBorder,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final FocusNode? focusNode;
  final bool autofocus;
  final MouseCursor? mouseCursor;
  final bool? onOffShapes;
  final bool? hasFocusBorder;

  @override
  State<BusyDataSwitch> createState() => _BusyDataSwitchState();
}

class _BusyDataSwitchState extends State<BusyDataSwitch> {
  bool _hovered = false;
  int? _pressedPointer;

  bool get _pressed => _pressedPointer != null;

  @override
  void didUpdateWidget(BusyDataSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null) {
      _pressedPointer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inheritedSwitchTheme = YaruSwitchTheme.of(context);
    final checkedTrackColor = _busyDataCheckedSwitchColor(
      theme.colorScheme.primary,
      brightness: theme.brightness,
      hovered: _hovered,
      pressed: _pressed,
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: widget.onChanged == null ? null : _handlePointerDown,
        onPointerUp: widget.onChanged == null ? null : _handlePointerUp,
        onPointerCancel: widget.onChanged == null ? null : _handlePointerCancel,
        child: YaruSwitchTheme(
          data: inheritedSwitchTheme.copyWith(
            indicatorColor: const WidgetStatePropertyAll<Color?>(
              Colors.transparent,
            ),
          ),
          child: YaruSwitch(
            value: widget.value,
            onChanged: widget.onChanged,
            selectedColor: checkedTrackColor,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            mouseCursor: widget.mouseCursor,
            onOffShapes: widget.onOffShapes,
            hasFocusBorder: widget.hasFocusBorder,
          ),
        ),
      ),
    );
  }

  void _setHovered(bool hovered) {
    if (_hovered != hovered) {
      setState(() => _hovered = hovered);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pressedPointer != null || event.buttons != kPrimaryButton) {
      return;
    }
    setState(() => _pressedPointer = event.pointer);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pressedPointer == event.pointer) {
      setState(() => _pressedPointer = null);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_pressedPointer == event.pointer) {
      setState(() => _pressedPointer = null);
    }
  }
}

Color _busyDataCheckedSwitchColor(
  Color accent, {
  required Brightness brightness,
  required bool hovered,
  required bool pressed,
}) {
  final normalLightnessDelta = brightness == Brightness.light ? 0.05 : 0.0;
  final stateLightnessDelta = pressed ? -0.07 : (hovered ? 0.07 : 0.0);
  final hsl = HSLColor.fromColor(accent);
  return hsl
      .withLightness(
        (hsl.lightness + normalLightnessDelta + stateLightnessDelta).clamp(
          0.0,
          1.0,
        ),
      )
      .toColor();
}

/// A Yaru radio button with GTK-style state colors and no external halo.
class BusyDataRadioButton<T> extends StatefulWidget {
  const BusyDataRadioButton({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.contentPadding,
    this.autofocus = false,
    this.focusNode,
    this.mouseCursor,
    this.hasFocusBorder,
  });

  final T value;
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget title;
  final Widget? subtitle;
  final EdgeInsetsGeometry? contentPadding;
  final bool autofocus;
  final FocusNode? focusNode;
  final MouseCursor? mouseCursor;
  final bool? hasFocusBorder;

  @override
  State<BusyDataRadioButton<T>> createState() => _BusyDataRadioButtonState<T>();
}

class _BusyDataRadioButtonState<T> extends State<BusyDataRadioButton<T>> {
  bool _hovered = false;
  int? _pressedPointer;

  bool get _pressed => _pressedPointer != null;

  @override
  void didUpdateWidget(BusyDataRadioButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChanged == null) {
      _pressedPointer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inheritedRadioTheme = YaruRadioTheme.of(context);
    final checkedColor = _busyDataCheckedRadioColor(
      theme.colorScheme.primary,
      brightness: theme.brightness,
      hovered: _hovered,
      pressed: _pressed,
    );

    return MouseRegion(
      onEnter: (_) => _setHovered(true),
      onExit: (_) => _setHovered(false),
      child: Listener(
        onPointerDown: widget.onChanged == null ? null : _handlePointerDown,
        onPointerUp: widget.onChanged == null ? null : _handlePointerUp,
        onPointerCancel: widget.onChanged == null ? null : _handlePointerCancel,
        child: YaruRadioTheme(
          data: inheritedRadioTheme.copyWith(
            color: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return inheritedRadioTheme.color?.resolve(states);
              }
              if (states.contains(WidgetState.selected)) {
                return checkedColor;
              }
              return inheritedRadioTheme.color?.resolve(states);
            }),
            indicatorColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          child: YaruRadioButton<T>(
            value: widget.value,
            groupValue: widget.groupValue,
            onChanged: widget.onChanged,
            title: widget.title,
            subtitle: widget.subtitle,
            contentPadding: widget.contentPadding,
            autofocus: widget.autofocus,
            focusNode: widget.focusNode,
            mouseCursor: widget.mouseCursor,
            hasFocusBorder: widget.hasFocusBorder,
          ),
        ),
      ),
    );
  }

  void _setHovered(bool hovered) {
    if (_hovered != hovered) {
      setState(() => _hovered = hovered);
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_pressedPointer != null || event.buttons != kPrimaryButton) {
      return;
    }
    setState(() => _pressedPointer = event.pointer);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_pressedPointer == event.pointer) {
      setState(() => _pressedPointer = null);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_pressedPointer == event.pointer) {
      setState(() => _pressedPointer = null);
    }
  }
}

Color _busyDataCheckedRadioColor(
  Color accent, {
  required Brightness brightness,
  required bool hovered,
  required bool pressed,
}) {
  final normalLightnessDelta = brightness == Brightness.light ? 0.05 : 0.0;
  final stateLightnessDelta = pressed ? -0.07 : (hovered ? 0.07 : 0.0);
  final hsl = HSLColor.fromColor(accent);
  return hsl
      .withLightness(
        (hsl.lightness + normalLightnessDelta + stateLightnessDelta).clamp(
          0.0,
          1.0,
        ),
      )
      .toColor();
}

class BusyDataSwitchRow extends StatelessWidget {
  const BusyDataSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveOnChanged = enabled ? onChanged : null;
    return BusyDataYaruFocusBorder(
      borderStrokeAlign: BorderSide.strokeAlignInside,
      builder: (context, rowFocusNode) => YaruSwitchListTile(
        value: value,
        onChanged: effectiveOnChanged,
        focusNode: rowFocusNode,
        control: BusyDataYaruFocusBorder(
          builder: (context, controlFocusNode) => BusyDataSwitch(
            value: value,
            onChanged: effectiveOnChanged,
            focusNode: controlFocusNode,
            hasFocusBorder: false,
          ),
        ),
        secondary: leading,
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : _busyDataGroupedRowSubtitle(
                context,
                Text(subtitle!),
                enabled: enabled,
              ),
        shape: const RoundedRectangleBorder(),
        hoverColor: busyDataRowHoverColor(context),
        hasFocusBorder: false,
      ),
    );
  }
}

class BusyDataMenuEntry<T> {
  const BusyDataMenuEntry({
    required this.value,
    required this.label,
    this.icon,
    this.nativeIconName,
    this.child,
    this.shortcut,
    this.enabled = true,
    this.role = BusyDataMenuEntryRole.command,
    this.selected = false,
    this.tooltip,
    this.destructive = false,
    this.children,
    this.separator = false,
    this.gtkAccelerator,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData? icon;
  final String? nativeIconName;
  final Widget? child;
  final String? shortcut;
  final bool enabled;
  final BusyDataMenuEntryRole role;
  final bool selected;
  final String? tooltip;
  final bool destructive;
  final List<BusyDataMenuEntry<T>>? children;
  final bool separator;
  final String? gtkAccelerator;
  final Color? iconColor;
}

enum BusyDataMenuEntryRole { command, radio, toggle }

@immutable
final class BusyDataMenuSelection<T> {
  const BusyDataMenuSelection(this.value);

  final T value;
}

/// Owns one native or Flutter fallback menu presentation.
///
/// A session may be dismissed safely after its owner is disposed. Native
/// dismissal is identity-checked by the host, while fallback dismissal
/// removes only the exact popup route captured for this presentation.
final class BusyDataMenuSession {
  BusyDataMenuSession() : _nativeSession = NativeMenuSession();

  final NativeMenuSession _nativeSession;
  final GlobalKey _fallbackRouteKey = GlobalKey();
  NativeMenuService _nativeMenuService = const NativeMenuService();
  Route<dynamic>? _fallbackRoute;
  bool _started = false;
  bool _dismissRequested = false;

  bool get _isDismissed => _dismissRequested;

  bool ownsFocus(FocusNode? focus) {
    if (_dismissRequested || focus?.context == null) return false;
    final itemContext = _fallbackRouteKey.currentContext;
    final route =
        _fallbackRoute ??
        (itemContext == null ? null : ModalRoute.of(itemContext));
    return route != null &&
        route.isCurrent &&
        identical(ModalRoute.of(focus!.context!), route);
  }

  Future<void> dismiss() async {
    if (_dismissRequested) {
      return;
    }
    _dismissRequested = true;
    _removeFallbackRoute();
    await _nativeMenuService.dismiss(_nativeSession);
  }

  void _beginPresentation(NativeMenuService nativeMenuService) {
    if (_started) {
      throw StateError('A BusyDataMenuSession can present only one menu.');
    }
    _started = true;
    _nativeMenuService = nativeMenuService;
  }

  void _captureFallbackRoute() {
    final itemContext = _fallbackRouteKey.currentContext;
    if (itemContext == null) {
      return;
    }
    final route = ModalRoute.of(itemContext);
    if (route == null) {
      return;
    }
    _fallbackRoute = route;
    if (_dismissRequested) {
      _removeFallbackRoute();
    }
  }

  void _releaseFallbackRoute() {
    _fallbackRoute = null;
  }

  void _removeFallbackRoute() {
    final route = _fallbackRoute;
    final navigator = route?.navigator;
    if (route != null && navigator != null && route.isActive) {
      navigator.removeRoute(route);
    }
    _fallbackRoute = null;
  }
}

/// Presents a semantic menu at [anchorRect], [anchorContext], or [anchorPoint].
///
/// Linux delegates the menu surface, rows, focus, keyboard navigation, and
/// dismissal to GTK. The Flutter route exists only for hosts where that
/// bridge is unavailable and inherits Yaru's popup-menu theme unchanged.
Future<BusyDataMenuSelection<T>?> showBusyDataMenu<T>({
  required BuildContext context,
  required List<BusyDataMenuEntry<T>> entries,
  BuildContext? anchorContext,
  Offset? anchorPoint,
  Rect? anchorRect,
  NativeMenuService nativeMenuService = const NativeMenuService(),
  BusyDataMenuSession? session,
  bool focusFirst = false,
  bool preferAbove = false,
  double? fallbackMenuWidth,
}) async {
  assert(
    anchorRect == null || (anchorContext == null && anchorPoint == null),
    'anchorRect cannot be combined with anchorContext or anchorPoint.',
  );
  if (entries.isEmpty) {
    return null;
  }
  final entrySnapshot = List<BusyDataMenuEntry<T>>.unmodifiable(entries);
  _validateBusyDataMenuEntries(entrySnapshot);
  final presentation = session ?? BusyDataMenuSession();
  if (presentation._isDismissed) {
    return null;
  }
  presentation._beginPresentation(nativeMenuService);
  final anchor =
      anchorRect ??
      _busyDataMenuAnchorRect(
        anchorContext ?? context,
        anchorPoint: anchorPoint,
      );
  final nativeResult = await nativeMenuService.show(
    session: presentation._nativeSession,
    anchor: anchor,
    entries: _nativeMenuEntries(entrySnapshot),
    focusFirst: focusFirst,
    preferAbove: preferAbove,
    textDirection: Directionality.of(context),
  );
  if (presentation._isDismissed) {
    return null;
  }
  if (nativeResult.available) {
    return _busyDataMenuValueAt(entrySnapshot, nativeResult.selectedIndex);
  }
  if (!context.mounted) {
    return null;
  }
  final selectedIndex = await _showBusyDataFlutterMenu(
    context: context,
    anchor: anchor,
    entries: entrySnapshot,
    session: presentation,
    focusFirst: focusFirst,
    width: fallbackMenuWidth,
  );
  if (presentation._isDismissed) {
    return null;
  }
  return _busyDataMenuValueAt(entrySnapshot, selectedIndex);
}

void _validateBusyDataMenuEntries<T>(List<BusyDataMenuEntry<T>> entries) {
  for (final entry in entries) {
    if (entry.children != null) _validateBusyDataMenuEntries(entry.children!);
  }
  if (entries.any(
    (entry) => entry.role == BusyDataMenuEntryRole.command && entry.selected,
  )) {
    throw ArgumentError.value(
      entries,
      'entries',
      'Command menu entries cannot be selected.',
    );
  }
  final radioEntries = entries
      .where((entry) => entry.role == BusyDataMenuEntryRole.radio)
      .toList(growable: false);
  if (radioEntries.isNotEmpty &&
      radioEntries.where((entry) => entry.selected).length != 1) {
    throw ArgumentError.value(
      entries,
      'entries',
      'A single-choice menu must have exactly one selected radio entry.',
    );
  }
}

Rect _busyDataMenuAnchorRect(
  BuildContext anchorContext, {
  Offset? anchorPoint,
}) {
  if (anchorPoint != null) {
    return Rect.fromLTWH(anchorPoint.dx, anchorPoint.dy, 0, 0);
  }
  final renderObject = anchorContext.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) {
    return Rect.zero;
  }
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

Rect _busyDataMenuControlAnchorRect({
  required BuildContext triggerContext,
  required BuildContext? affordanceContext,
}) {
  final triggerRect = _busyDataMenuAnchorRect(triggerContext);
  if (affordanceContext == null) {
    return triggerRect;
  }
  final affordanceRect = _busyDataMenuAnchorRect(affordanceContext);
  if (triggerRect.isEmpty || affordanceRect.isEmpty) {
    return triggerRect;
  }
  return affordanceRect;
}

List<NativeMenuEntry> _nativeMenuEntries<T>(
  List<BusyDataMenuEntry<T>> entries,
) {
  return [
    for (final entry in entries)
      NativeMenuEntry(
        label: entry.label,
        iconName:
            entry.nativeIconName ??
            BusyDataGlyphs.nativeMenuIconName(entry.icon),
        enabled: entry.enabled,
        role: switch (entry.role) {
          BusyDataMenuEntryRole.command => NativeMenuEntryRole.command,
          BusyDataMenuEntryRole.radio => NativeMenuEntryRole.radio,
          BusyDataMenuEntryRole.toggle => NativeMenuEntryRole.toggle,
        },
        selected: entry.selected,
        tooltip: entry.tooltip,
        shortcut: entry.shortcut,
        gtkAccelerator: entry.gtkAccelerator,
        iconColorArgb: entry.iconColor?.toARGB32(),
        separator: entry.separator,
        children: entry.children == null
            ? null
            : _nativeMenuEntries(entry.children!),
      ),
  ];
}

Iterable<(BusyDataMenuEntry<T>, bool)> _flattenBusyDataMenu<T>(
  List<BusyDataMenuEntry<T>> entries, [
  bool enabled = true,
]) sync* {
  for (final entry in entries) {
    yield (entry, enabled && entry.enabled && !entry.separator);
    if (entry.children != null) {
      yield* _flattenBusyDataMenu(entry.children!, enabled && entry.enabled);
    }
  }
}

BusyDataMenuSelection<T>? _busyDataMenuValueAt<T>(
  List<BusyDataMenuEntry<T>> entries,
  int? index,
) {
  final flattened = _flattenBusyDataMenu(entries).toList();
  if (index == null || index < 0 || index >= flattened.length) return null;
  final (entry, enabled) = flattened[index];
  return enabled && entry.children == null
      ? BusyDataMenuSelection(entry.value)
      : null;
}

Future<int?> _showBusyDataFlutterMenu<T>({
  required BuildContext context,
  required Rect anchor,
  required List<BusyDataMenuEntry<T>> entries,
  required BusyDataMenuSession session,
  required bool focusFirst,
  double? width,
}) async {
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay?.context.findRenderObject();
  if (overlay is! RenderBox || !overlay.hasSize) {
    return null;
  }
  final localAnchor = Rect.fromPoints(
    overlay.globalToLocal(anchor.topLeft),
    overlay.globalToLocal(anchor.bottomRight),
  );
  final menuAnchor = Rect.fromLTWH(
    localAnchor.left,
    localAnchor.bottom,
    localAnchor.width,
    0,
  );
  final firstEnabledIndex = entries.indexWhere((entry) => entry.enabled);
  final firstEnabledKey = focusFirst && firstEnabledIndex >= 0
      ? GlobalKey()
      : null;
  final routeKey = session._fallbackRouteKey;
  final menuHoverColor = BusyDataSurfaceColors.of(context).controlHover;
  final selection = showMenu<int>(
    context: context,
    constraints: width == null ? null : BoxConstraints.tightFor(width: width),
    position: RelativeRect.fromRect(menuAnchor, Offset.zero & overlay.size),
    items: [
      for (var index = 0; index < entries.length; index += 1)
        if (entries[index].separator)
          const PopupMenuDivider()
        else
          _BusyDataPopupMenuItem<int>(
            value: index,
            enabled: entries[index].enabled,
            hoverColor: menuHoverColor,
            child: _busyDataFocusableFallbackEntry(
              context,
              entries[index],
              selectionIndicator:
                  entries[index].role == BusyDataMenuEntryRole.command
                  ? null
                  : Visibility.maintain(
                      visible: entries[index].selected,
                      child: const Icon(
                        YaruIcons.checkmark,
                        size: BusyDataSizes.iconSm,
                      ),
                    ),
              focusKey: index == firstEnabledIndex ? firstEnabledKey : null,
              routeKey: index == 0 ? routeKey : null,
            ),
          ),
    ],
    requestFocus: true,
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    session._captureFallbackRoute();
    if (firstEnabledKey != null && !session._isDismissed) {
      final itemContext = firstEnabledKey.currentContext;
      if (itemContext != null) {
        Focus.of(itemContext).requestFocus();
      }
    }
  });
  int? picked;
  Route<dynamic>? route;
  try {
    picked = await selection;
    route = session._fallbackRoute;
  } finally {
    session._releaseFallbackRoute();
  }
  if (picked == null) return null;
  var offset = 0;
  for (var i = 0; i < picked; i++) {
    offset += _flattenBusyDataMenu([entries[i]]).length;
  }
  final children = entries[picked].children;
  if (children == null) return offset;
  if (route is TransitionRoute) await route.completed;
  if (!context.mounted || session._isDismissed) return null;
  final nested = await _showBusyDataFlutterMenu(
    context: context,
    anchor: anchor,
    entries: children,
    session: session,
    focusFirst: true,
  );
  return nested == null ? null : offset + 1 + nested;
}

/// A framework popup row with BusyData's GTK menu-hover role in scope.
///
/// [PopupMenuItem] otherwise reads the application-wide Material hover color,
/// which is intentionally much quieter than GTK's menu-row state. Subclassing
/// keeps the framework's menu semantics, focus handling, keyboard navigation,
/// geometry, and ink response intact; only the inherited semantic state color
/// is narrowed to this row.
class _BusyDataPopupMenuItem<T> extends PopupMenuItem<T> {
  const _BusyDataPopupMenuItem({
    required super.value,
    required super.enabled,
    required this.hoverColor,
    required super.child,
  });

  final Color hoverColor;

  @override
  PopupMenuItemState<T, _BusyDataPopupMenuItem<T>> createState() =>
      _BusyDataPopupMenuItemState<T>();
}

class _BusyDataPopupMenuItemState<T>
    extends PopupMenuItemState<T, _BusyDataPopupMenuItem<T>> {
  @override
  Widget build(BuildContext context) {
    final menuTheme = Theme.of(context).copyWith(hoverColor: widget.hoverColor);
    return Theme(
      data: menuTheme,
      child: Builder(builder: (context) => super.build(context)),
    );
  }
}

Widget _busyDataFocusableFallbackEntry<T>(
  BuildContext context,
  BusyDataMenuEntry<T> entry, {
  required Widget? selectionIndicator,
  required GlobalKey? focusKey,
  required GlobalKey? routeKey,
}) {
  Widget child = _busyDataFallbackMenuEntry(
    context,
    entry,
    selectionIndicator: selectionIndicator,
  );
  switch (entry.role) {
    case BusyDataMenuEntryRole.command:
      break;
    case BusyDataMenuEntryRole.radio:
      child = Semantics(
        selected: entry.selected,
        inMutuallyExclusiveGroup: true,
        child: child,
      );
    case BusyDataMenuEntryRole.toggle:
      child = Semantics(checked: entry.selected, child: child);
  }
  if (focusKey != null) {
    child = KeyedSubtree(key: focusKey, child: child);
  }
  if (routeKey != null) {
    child = KeyedSubtree(key: routeKey, child: child);
  }
  return child;
}

Widget _busyDataFallbackMenuEntry<T>(
  BuildContext context,
  BusyDataMenuEntry<T> entry, {
  required Widget? selectionIndicator,
}) {
  final foreground = entry.destructive
      ? Theme.of(context).colorScheme.error
      : null;
  final label =
      entry.child ??
      Text(
        entry.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: foreground == null ? null : TextStyle(color: foreground),
      );
  final shortcut = entry.shortcut == null || entry.shortcut!.isEmpty
      ? null
      : Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            entry.shortcut!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        );
  final content =
      entry.icon == null && selectionIndicator == null && shortcut == null
      ? label
      : Row(
          children: [
            if (entry.icon != null) ...[
              Icon(entry.icon, color: foreground, size: BusyDataSizes.iconSm),
              const SizedBox(width: BusyDataSpacing.sm),
            ],
            Expanded(child: label),
            if (shortcut != null) ...[
              const SizedBox(width: BusyDataSpacing.sm),
              shortcut,
            ],
            if (selectionIndicator != null) ...[
              const SizedBox(width: BusyDataSpacing.sm),
              selectionIndicator,
            ],
            if (entry.children != null) ...[
              const SizedBox(width: BusyDataSpacing.sm),
              const Icon(YaruIcons.pan_end, size: BusyDataSizes.iconSm),
            ],
          ],
        );
  if (entry.enabled || entry.tooltip == null) {
    return content;
  }
  return Tooltip(message: entry.tooltip!, child: content);
}

typedef BusyDataMenuTriggerBuilder =
    Widget Function(BuildContext context, BusyDataMenuTriggerDetails trigger);

/// Interaction and geometry supplied to a custom [BusyDataMenuButton] trigger.
///
/// The trigger may make a larger control clickable while marking the native
/// relative widget with [anchor]. Menus are positioned from that widget's
/// exact geometry, matching `GtkPopover.relative-to`.
@immutable
class BusyDataMenuTriggerDetails {
  const BusyDataMenuTriggerDetails._({
    required this.onPressed,
    required this.focusNode,
    required this.isOpen,
    required GlobalKey menuAnchorKey,
  }) : _menuAnchorKey = menuAnchorKey;

  final VoidCallback? onPressed;
  final FocusNode focusNode;
  final bool isOpen;
  final GlobalKey _menuAnchorKey;

  /// Marks the visual affordance used as the menu's native relative widget.
  ///
  /// A custom trigger should call this exactly once. When omitted, the shared
  /// menu adapter safely falls back to the complete trigger bounds.
  Widget anchor({required Widget child}) {
    return KeyedSubtree(key: _menuAnchorKey, child: child);
  }
}

/// Controls keyboard-driven opening of a [BusyDataMenuButton].
///
/// Pointer activation remains owned by the button so a mouse click does not
/// paint a keyboard focus ring. Commands and shortcuts use
/// [openForKeyboard], which transfers focus to the first enabled menu item.
class BusyDataMenuController {
  Object? _owner;
  bool Function()? _openForKeyboard;
  VoidCallback? _close;
  bool Function()? _isOpen;

  bool get isAttached => _owner != null;

  bool get isOpen => _isOpen?.call() ?? false;

  /// Opens the attached menu in keyboard modality.
  ///
  /// Returns false when the menu is not attached, is disabled, or is already
  /// open.
  bool openForKeyboard() {
    final open = _openForKeyboard;
    if (open == null) {
      return false;
    }
    return open();
  }

  void close() => _close?.call();

  void _attach({
    required Object owner,
    required bool Function() openForKeyboard,
    required VoidCallback close,
    required bool Function() isOpen,
  }) {
    // Flutter can mount a replacement responsive subtree before disposing its
    // predecessor. Point commands at the newest attachment; the owner check
    // in [_detach] prevents the retiring state from detaching its successor.
    _owner = owner;
    _openForKeyboard = openForKeyboard;
    _close = close;
    _isOpen = isOpen;
  }

  void _detach(Object owner) {
    if (!identical(_owner, owner)) {
      return;
    }
    _owner = null;
    _openForKeyboard = null;
    _close = null;
    _isOpen = null;
  }
}

class BusyDataMenuButton<T> extends StatefulWidget {
  const BusyDataMenuButton({
    super.key,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    this.icon = const Icon(YaruIcons.view_more),
    this.triggerBuilder,
    this.controller,
    this.enabled = true,
    this.highlightWhenOpen = true,
    this.fallbackMenuWidth,
    this.nativeMenuService = const NativeMenuService(),
  });

  final String tooltip;
  final Widget icon;
  final List<BusyDataMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final BusyDataMenuTriggerBuilder? triggerBuilder;
  final BusyDataMenuController? controller;
  final bool enabled;
  final bool highlightWhenOpen;
  final double? fallbackMenuWidth;
  final NativeMenuService nativeMenuService;

  @override
  State<BusyDataMenuButton<T>> createState() => _BusyDataMenuButtonState<T>();
}

class _BusyDataMenuButtonState<T> extends State<BusyDataMenuButton<T>> {
  final _triggerKey = GlobalKey();
  final _menuAnchorKey = GlobalKey();
  late final FocusNode _triggerFocusNode;
  BusyDataMenuSession? _activeMenuSession;
  bool _menuOpen = false;

  @override
  void initState() {
    super.initState();
    _triggerFocusNode = FocusNode(
      debugLabel: 'BusyData menu trigger',
      onKeyEvent: _handleTriggerKeyEvent,
    );
    _triggerFocusNode.addListener(_focusChanged);
    _attachExternalController();
  }

  void _focusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant BusyDataMenuButton<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      _attachExternalController();
    }
    if (oldWidget.enabled && !widget.enabled && _menuOpen) {
      _closeMenu();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    final session = _activeMenuSession;
    _activeMenuSession = null;
    if (session != null) {
      unawaited(session.dismiss());
    }
    _triggerFocusNode.removeListener(_focusChanged);
    _triggerFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final triggerBuilder = widget.triggerBuilder;
    final triggerDetails = BusyDataMenuTriggerDetails._(
      onPressed: widget.enabled ? _toggleMenu : null,
      focusNode: _triggerFocusNode,
      isOpen: _menuOpen,
      menuAnchorKey: _menuAnchorKey,
    );
    final trigger = triggerBuilder != null
        ? triggerBuilder(context, triggerDetails)
        : triggerDetails.anchor(
            child: YaruIconButton(
              tooltip: widget.tooltip,
              icon: widget.icon,
              focusNode: _triggerFocusNode,
              isSelected: widget.highlightWhenOpen && _menuOpen,
              onPressed: widget.enabled ? _toggleMenu : null,
            ),
          );
    return KeyedSubtree(
      key: _triggerKey,
      child: triggerBuilder == null
          ? Semantics(expanded: _menuOpen, child: trigger)
          : trigger,
    );
  }

  KeyEventResult _handleTriggerKeyEvent(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (!_menuOpen) {
        _openForKeyboard();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape && _menuOpen) {
      _closeMenu();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleMenu() {
    if (_menuOpen) {
      _closeMenu();
      return;
    }
    unawaited(_openMenu());
  }

  Future<void> _openMenu({bool focusFirst = false}) async {
    final triggerContext = _triggerKey.currentContext;
    if (!widget.enabled ||
        _menuOpen ||
        triggerContext == null ||
        widget.entries.isEmpty) {
      return;
    }
    final entries = List<BusyDataMenuEntry<T>>.unmodifiable(widget.entries);
    final onSelected = widget.onSelected;
    final nativeMenuService = widget.nativeMenuService;
    final session = BusyDataMenuSession();
    _activeMenuSession = session;
    setState(() {
      _menuOpen = true;
    });

    BusyDataMenuSelection<T>? selection;
    try {
      final anchor = _busyDataMenuControlAnchorRect(
        triggerContext: triggerContext,
        affordanceContext: _menuAnchorKey.currentContext,
      );
      selection = await showBusyDataMenu<T>(
        context: triggerContext,
        anchorRect: anchor,
        entries: entries,
        nativeMenuService: nativeMenuService,
        fallbackMenuWidth: widget.fallbackMenuWidth,
        session: session,
        focusFirst: focusFirst,
      );
    } finally {
      if (mounted && identical(_activeMenuSession, session)) {
        setState(() {
          _activeMenuSession = null;
          _menuOpen = false;
        });
      }
    }
    if (mounted && !session._isDismissed && selection != null) {
      onSelected(selection.value);
    }
  }

  bool _openForKeyboard() {
    if (!widget.enabled || _menuOpen || widget.entries.isEmpty) {
      return false;
    }
    _triggerFocusNode.requestFocus();
    unawaited(_openMenu(focusFirst: true));
    return true;
  }

  void _closeMenu() {
    final session = _activeMenuSession;
    if (session == null) {
      return;
    }
    // Release the trigger synchronously. Native dismissal and the matching
    // `show` response travel over separate platform messages, so waiting for
    // that response would leave this button looking open and make a quick
    // second click dismiss the same session again instead of reopening.
    setState(() {
      _activeMenuSession = null;
      _menuOpen = false;
    });
    unawaited(session.dismiss());
  }

  void _attachExternalController() {
    widget.controller?._attach(
      owner: this,
      openForKeyboard: _openForKeyboard,
      close: _closeMenu,
      isOpen: () => _menuOpen,
    );
  }
}

/// Pane/status surface extracted from BusyMark's pane headers and status bar.
class BusyDataToolbar extends StatelessWidget {
  const BusyDataToolbar({
    super.key,
    required this.child,
    this.minimumHeight = 38,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.topBorder = false,
  });
  final Widget child;
  final double minimumHeight;
  final EdgeInsetsGeometry padding;
  final bool topBorder;
  @override
  Widget build(BuildContext context) {
    final colors = BusyDataSurfaceColors.of(context);
    return Container(
      constraints: BoxConstraints(minHeight: minimumHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: colors.headerbarFlat,
        border: Border(
          top: topBorder ? BorderSide(color: colors.divider) : BorderSide.none,
          bottom: topBorder
              ? BorderSide.none
              : BorderSide(color: colors.divider),
        ),
      ),
      child: child,
    );
  }
}

/// BusyMark's rounded sidebar surface, with interaction owned by the existing
/// tree/record focus target. This adds no traversal target or activation path.
class BusyDataSidebarRowSurface extends StatelessWidget {
  const BusyDataSidebarRowSurface({
    super.key,
    required this.child,
    required this.selected,
    required this.focused,
    this.hovered = false,
    this.focusVisible,
    this.base,
  });
  final Widget child;
  final bool selected, focused, hovered;
  final bool? focusVisible;
  final Color? base;
  @override
  Widget build(BuildContext context) {
    final colors = BusyDataSurfaceColors.of(context);
    final parent = base ?? colors.window;
    final contrast =
        MediaQuery.highContrastOf(context) ||
        Theme.of(context).colorScheme.isHighContrast;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: BusyDataStroke.hairline),
      child: Container(
        alignment: Alignment.center,
        constraints: const BoxConstraints(
          minHeight: kYaruTitleBarItemHeight - 2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BusyDataRadius.md),
          color: selected
              ? contrast && focused
                    ? Theme.of(context).colorScheme.primary
                    : Color.alphaBlend(colors.controlActive, parent)
              : hovered
              ? Color.alphaBlend(busyDataRowHoverColor(context), parent)
              : base ?? Colors.transparent,
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(BusyDataRadius.md),
          border: Border.all(
            width: 2,
            color: (focusVisible ?? focused)
                ? selected && contrast
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.primary
                : Colors.transparent,
          ),
        ),
        child: child,
      ),
    );
  }
}

class BusyDataEditorHeader extends StatelessWidget {
  const BusyDataEditorHeader({
    super.key,
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
    this.saving = false,
    this.cancelEnabled = true,
    this.saveFocus,
  });

  final String title;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool saving;
  final bool cancelEnabled;
  final FocusNode? saveFocus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        BusyDataSpacing.headerInset,
        BusyDataSpacing.headerInset,
        BusyDataSpacing.headerInset,
        BusyDataSpacing.headerInset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              heightFactor: 1,
              child: BusyDataPushButton.standard(
                onPressed: cancelEnabled ? onCancel : null,
                child: Text(cancelLabel),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              heightFactor: 1,
              child: BusyDataPushButton.suggested(
                onPressed: onSave,
                focusNode: saveFocus,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: saving ? 0 : 1,
                      alwaysIncludeSemantics: true,
                      child: Text(saveLabel),
                    ),
                    if (saving)
                      const ExcludeSemantics(
                        child: SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// BusyMark's document view selector, backed by the shared popup adapter.
class BusyDataModeSwitcher<T> extends StatelessWidget {
  const BusyDataModeSwitcher({
    super.key,
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.tooltip,
  });
  final List<T> values;
  final T selected;
  final String Function(T) labelFor;
  final ValueChanged<T> onSelected;
  final String? tooltip;
  @override
  Widget build(BuildContext context) => BusyDataPopupSelector<T>(
    value: selected,
    label: labelFor(selected),
    tooltip: tooltip ?? labelFor(selected),
    options: [
      for (final value in values)
        BusyDataPopupSelectorOption(value: value, label: labelFor(value)),
    ],
    onSelected: onSelected,
  );
}

class BusyDataEditorScrollBody extends StatelessWidget {
  const BusyDataEditorScrollBody({
    super.key,
    required this.child,
    this.maxWidth = 640,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return YaruScrollViewUndershoot.builder(
      endUndershoot: false,
      builder: (context, controller) => BusyDataClamp(
        maxWidth: maxWidth,
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.fromLTRB(
          BusyDataSpacing.lg,
          BusyDataSpacing.headerInset,
          BusyDataSpacing.lg,
          BusyDataSpacing.lg,
        ),
        controller: controller,
        child: child,
      ),
    );
  }
}

class BusyDataModalEditorScaffold extends StatelessWidget {
  const BusyDataModalEditorScaffold({
    super.key,
    required this.title,
    required this.cancelLabel,
    required this.saveLabel,
    required this.onCancel,
    required this.onSave,
    required this.children,
    this.saving = false,
    this.cancelEnabled = true,
    this.contentMaxWidth = 640,
    this.saveFocus,
  });

  final String title;
  final String cancelLabel;
  final String saveLabel;
  final VoidCallback onCancel;
  final VoidCallback? onSave;
  final bool saving;
  final bool cancelEnabled;
  final double contentMaxWidth;
  final FocusNode? saveFocus;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BusyDataEditorHeader(
            title: title,
            cancelLabel: cancelLabel,
            saveLabel: saveLabel,
            onCancel: onCancel,
            onSave: onSave,
            saving: saving,
            cancelEnabled: cancelEnabled,
            saveFocus: saveFocus,
          ),
          Flexible(
            child: BusyDataEditorScrollBody(
              maxWidth: contentMaxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BusyDataModalEditorSurface extends StatelessWidget {
  const BusyDataModalEditorSurface({
    super.key,
    required this.child,
    this.minWidth = 0,
    this.maxWidth = BusyDataSizes.compactDetailsWidth,
    this.maxHeight,
    this.insetPadding = EdgeInsets.zero,
  });

  final Widget child;
  final double minWidth;
  final double maxWidth;
  final double? maxHeight;
  final EdgeInsets insetPadding;

  @override
  Widget build(BuildContext context) {
    final editorSurface = Theme.of(context).scaffoldBackgroundColor;
    final effectiveMaxWidth = maxWidth.isFinite
        ? maxWidth.clamp(0.0, double.infinity).toDouble()
        : maxWidth;
    final effectiveMinWidth = minWidth
        .clamp(
          0.0,
          effectiveMaxWidth.isFinite ? effectiveMaxWidth : double.infinity,
        )
        .toDouble();
    final effectiveMaxHeight = maxHeight == null
        ? double.infinity
        : maxHeight!.clamp(0.0, double.infinity).toDouble();

    return BusyDataSurfaceScope(
      role: BusyDataSurfaceRole.window,
      child: Dialog(
        backgroundColor: editorSurface,
        surfaceTintColor: editorSurface,
        insetPadding: insetPadding,
        insetAnimationDuration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : BusyDataMotion.dialogInsets,
        insetAnimationCurve: BusyDataMotion.dialogInsetsCurve,
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: effectiveMinWidth,
            maxWidth: effectiveMaxWidth,
            maxHeight: effectiveMaxHeight,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Yaru dialog chrome bound to BusyData's semantic dialog surface.
///
/// Yaru otherwise falls back to [ThemeData.scaffoldBackgroundColor], which is
/// the application window role and can differ from [DialogThemeData.backgroundColor].
/// Keeping this adapter shared prevents a dialog title bar and body from
/// resolving different native surface roles.
Color busyDataDialogSurfaceColor(BuildContext context) {
  return DialogTheme.of(context).backgroundColor ??
      BusyDataSurfaceColors.of(context).dialog;
}

class BusyDataDialogTitleBar extends StatelessWidget {
  const BusyDataDialogTitleBar({
    super.key,
    this.title,
    this.centerTitle = true,
    this.closeSemanticLabel,
    this.showDividerInHighContrast = true,
  });

  final Widget? title;
  final bool centerTitle;
  final String? closeSemanticLabel;
  final bool showDividerInHighContrast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BusyDataSurfaceColors.of(context);
    final dialogSurface = busyDataDialogSurfaceColor(context);
    return Theme(
      data: theme.copyWith(
        appBarTheme: theme.appBarTheme.copyWith(
          backgroundColor: dialogSurface,
          surfaceTintColor: dialogSurface,
          shadowColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      child: YaruDialogTitleBar(
        title: title,
        centerTitle: centerTitle,
        isActive: true,
        backgroundColor: dialogSurface,
        border: showDividerInHighContrast && theme.colorScheme.isHighContrast
            ? BorderSide(color: colors.divider)
            : BorderSide.none,
        closeSemanticLabel: closeSemanticLabel,
        heroTag: null,
      ),
    );
  }
}

class BusyDataDialogShell extends StatelessWidget {
  const BusyDataDialogShell({
    super.key,
    required this.title,
    required this.children,
    this.maxWidth = 520,
    this.header,
    this.actions = const [],
    this.scrollBody = true,
    this.contentPadding = BusyDataSpacing.lg,
  }) : assert(scrollBody || children.length == 1);

  final String title;
  final List<Widget> children;
  final double maxWidth;
  final Widget? header;
  final List<Widget> actions;

  /// A body with its own viewport receives bounded space directly, so focus
  /// can reveal fields inside the actual dialog rather than a nested viewport.
  final bool scrollBody;
  final double contentPadding;

  @override
  Widget build(BuildContext context) {
    final dialogSurface = busyDataDialogSurfaceColor(context);
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: title,
      child: BusyDataSurfaceScope(
        role: BusyDataSurfaceRole.dialog,
        child: Dialog(
          backgroundColor: dialogSurface,
          surfaceTintColor: dialogSurface,
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: LayoutBuilder(
              builder: (context, bounds) {
                final style = Theme.of(context).textTheme.bodyMedium;
                final line =
                    MediaQuery.textScalerOf(
                      context,
                    ).scale(style?.fontSize ?? 14) *
                    (style?.height ?? 1.4);
                final headerExtent = math.max(
                  kYaruTitleBarItemHeight,
                  line + 12,
                );
                final bodyReserve = math.min(
                  bounds.maxHeight / 4,
                  line + contentPadding * 2,
                );
                final actionLimit = math.max(
                  0.0,
                  bounds.maxHeight - headerExtent - bodyReserve,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header ?? BusyDataDialogTitleBar(title: Text(title)),
                    Flexible(
                      child: scrollBody
                          ? SingleChildScrollView(
                              key: const ValueKey('busydata-dialog-body'),
                              primary: false,
                              padding: EdgeInsets.all(contentPadding),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: children,
                              ),
                            )
                          : Padding(
                              padding: EdgeInsets.all(contentPadding),
                              child: children.single,
                            ),
                    ),
                    if (actions.isNotEmpty)
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: actionLimit),
                        child: SingleChildScrollView(
                          key: const ValueKey('busydata-dialog-actions'),
                          primary: false,
                          child: Padding(
                            padding: EdgeInsets.all(contentPadding),
                            child: OverflowBar(
                              alignment: MainAxisAlignment.end,
                              spacing: BusyDataSpacing.sm,
                              overflowSpacing: BusyDataSpacing.sm,
                              children: actions,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class BusyDataPromptDialog extends StatefulWidget {
  const BusyDataPromptDialog({
    super.key,
    required this.title,
    required this.label,
    required this.actionLabel,
    this.initialValue,
    this.message,
  });

  final String title;
  final String label;
  final String actionLabel;
  final String? initialValue;
  final String? message;

  @override
  State<BusyDataPromptDialog> createState() => _BusyDataPromptDialogState();
}

class _BusyDataPromptDialogState extends State<BusyDataPromptDialog> {
  late final TextEditingController _controller;
  late bool _canSubmit;

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialValue ?? '';
    _controller = TextEditingController(text: initialValue)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialValue.length,
      )
      ..addListener(_handleTextChanged);
    _canSubmit = _hasValue;
  }

  bool get _hasValue => _controller.text.trim().isNotEmpty;

  void _handleTextChanged() {
    final canSubmit = _hasValue;
    if (canSubmit != _canSubmit) {
      setState(() => _canSubmit = canSubmit);
    }
  }

  void _submit() {
    if (_hasValue) {
      Navigator.of(context).pop(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BusyDataDialogShell(
      title: widget.title,
      header: BusyDataEditorHeader(
        title: widget.title,
        cancelLabel: context.l10n.cancel,
        saveLabel: widget.actionLabel,
        onCancel: () => Navigator.of(context).pop(),
        onSave: _canSubmit ? _submit : null,
      ),
      children: [
        if (widget.message != null && widget.message!.isNotEmpty)
          Text(widget.message!),
        BusyDataGroupedList(
          filled: true,
          children: [
            YaruListTile.square(
              title: TextFormField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: busyDataGroupedTextFieldDecoration(
                  context,
                  labelText: widget.label,
                ),
                onFieldSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class BusyDataConfirmDialog extends StatelessWidget {
  const BusyDataConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return BusyDataDialogShell(
      title: title,
      actions: [
        BusyDataPushButton.standard(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        if (destructive)
          BusyDataPushButton.destructive(
            context: context,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          )
        else
          BusyDataPushButton.suggested(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
      ],
      children: [Text(message)],
    );
  }
}

// Adapted from BusyMark a5ee774, busymark_design.dart (Apache-2.0).
class BusyDataPopupSelectorOption<T> {
  const BusyDataPopupSelectorOption({
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.shortcut,
    this.gtkAccelerator,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final String? shortcut;
  final String? gtkAccelerator;
}

/// The shared desktop selector used by Settings-style control rows.
class BusyDataPopupSelector<T> extends StatelessWidget {
  const BusyDataPopupSelector({
    super.key,
    required this.value,
    required this.label,
    required this.tooltip,
    required this.options,
    required this.onSelected,
    this.enabled = true,
    this.popupMinWidth = 220,
    this.popupMaxWidth = 280,
    this.buttonMaxWidth = BusyDataSizes.selectorButtonMaxWidth,
    this.leading,
    this.fullWidth = false,
    this.maxLabelLines = 1,
  });

  final T? value;
  final String label;
  final String tooltip;
  final List<BusyDataPopupSelectorOption<T>> options;
  final ValueChanged<T> onSelected;
  final bool enabled;
  final double popupMinWidth;
  final double popupMaxWidth;
  final double buttonMaxWidth;
  final Widget? leading;
  final bool fullWidth;
  final int maxLabelLines;
  @override
  Widget build(BuildContext context) {
    // Inherit borderless button geometry and interaction states while keeping
    // the neutral control foreground rather than an action-link accent.
    final neutralButtonStyle = Theme.of(context).outlinedButtonTheme.style;
    final selectorEnabled = enabled && options.isNotEmpty;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: fullWidth ? double.infinity : buttonMaxWidth,
        ),
        child: BusyDataMenuButton<T>(
          tooltip: tooltip,
          enabled: selectorEnabled,
          fallbackMenuWidth: (fullWidth ? popupMaxWidth : buttonMaxWidth).clamp(
            popupMinWidth,
            popupMaxWidth,
          ),
          onSelected: onSelected,
          entries: [
            for (final option in options)
              BusyDataMenuEntry<T>(
                value: option.value,
                label: option.label,
                icon: option.icon,

                shortcut: option.shortcut,

                role: BusyDataMenuEntryRole.radio,
                selected: option.value == value,
              ),
          ],
          triggerBuilder: (context, trigger) {
            return trigger.anchor(
              child: Tooltip(
                message: tooltip,
                excludeFromSemantics: true,
                child: Semantics(
                  container: true,
                  label: busyDataSelectedValueLabel(tooltip, label),
                  button: true,
                  enabled: selectorEnabled,
                  focusable: selectorEnabled,
                  focused: trigger.focusNode.hasFocus,
                  onFocus: selectorEnabled
                      ? trigger.focusNode.requestFocus
                      : null,
                  excludeSemantics: true,
                  onTap: trigger.onPressed,
                  expanded: trigger.isOpen,
                  child: TextButton(
                    style: ButtonStyle(
                      foregroundColor: neutralButtonStyle?.foregroundColor,
                      iconColor: neutralButtonStyle?.iconColor,
                    ),
                    onPressed: trigger.onPressed,
                    focusNode: trigger.focusNode,
                    child: Row(
                      mainAxisSize: fullWidth
                          ? MainAxisSize.max
                          : MainAxisSize.min,
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: BusyDataSpacing.sm),
                        ],
                        if (fullWidth)
                          Expanded(
                            child: Text(
                              label,
                              maxLines: maxLabelLines,
                              overflow: TextOverflow.ellipsis,
                              softWrap: maxLabelLines > 1,
                            ),
                          )
                        else
                          Flexible(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: math.max(
                                  0,
                                  buttonMaxWidth -
                                      BusyDataSizes.headerIconButton -
                                      10,
                                ),
                              ),
                              child: Text(
                                label,
                                maxLines: maxLabelLines,
                                overflow: TextOverflow.ellipsis,
                                softWrap: maxLabelLines > 1,
                              ),
                            ),
                          ),
                        const SizedBox(width: BusyDataSpacing.sm),
                        const Icon(
                          YaruIcons.pan_down,
                          size: BusyDataSizes.iconSm,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Input decoration inherited by controls hosted in a grouped-list row.
///
/// The grouped list owns the surface, outline, padding, and separators. Yaru
/// and Flutter continue to own editing behavior without painting a second
/// Material input surface inside the native desktop row.
InputDecorationThemeData busyDataGroupedInputDecorationTheme(
  BuildContext context,
) {
  final theme = Theme.of(context);
  final labelColor = theme.colorScheme.onSurfaceVariant;
  final labelStyle = theme.textTheme.bodyMedium?.copyWith(color: labelColor);

  return theme.inputDecorationTheme.copyWith(
    filled: false,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
    labelStyle: labelStyle,
    floatingLabelStyle: labelStyle,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
  );
}

InputDecoration busyDataGroupedTextFieldDecoration(
  BuildContext context, {
  required String labelText,
  String? hintText,
  String? errorText,
  bool alignLabelWithHint = false,
}) {
  final decoration = InputDecoration(
    labelText: labelText,
    hintText: hintText,
    errorText: errorText,
    alignLabelWithHint: alignLabelWithHint,
  );
  final defaults = busyDataGroupedInputDecorationTheme(context);
  final resolved = decoration.applyDefaults(defaults);
  if (errorText == null) {
    return resolved;
  }
  final errorLabelStyle = Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error);
  return resolved.copyWith(
    labelStyle: errorLabelStyle,
    floatingLabelStyle: errorLabelStyle,
  );
}

/// A text entry hosted by the native grouped-list form surface.
///
/// The row owns the background, outline, padding, and separators while
/// [TextFormField] continues to own editing, validation, and focus behavior.
class BusyDataGroupedTextEntry extends StatefulWidget {
  const BusyDataGroupedTextEntry({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.errorText,
    this.hintText,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.focusNode,
    this.keyboardType,
    this.inputFormatters,
    this.minLines = 1,
    this.maxLines = 1,
    this.expands = false,
    this.textInputAction,
    this.textDirection,
    this.textStyle,
    this.alignLabelWithHint = false,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
  }) : assert(controller == null || initialValue == null),
       assert(minLines > 0),
       assert(maxLines >= minLines);

  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? errorText;
  final String? hintText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int minLines;
  final int maxLines;
  final bool expands;
  final TextInputAction? textInputAction;
  final TextDirection? textDirection;
  final TextStyle? textStyle;
  final bool alignLabelWithHint;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<BusyDataGroupedTextEntry> createState() =>
      _BusyDataGroupedTextEntryState();
}

class _BusyDataGroupedTextEntryState extends State<BusyDataGroupedTextEntry> {
  final _fieldKey = GlobalKey<FormFieldState<String>>();

  @override
  Widget build(BuildContext context) {
    final row = _buildRow(context);
    if (!widget.enabled || widget.onSubmitted == null) {
      return row;
    }
    // Linux physical key events are not always translated into the text-input
    // action that drives TextFormField.onFieldSubmitted. Keep that callback for
    // IME actions and bind the desktop Enter keys explicitly as well.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter): _submit,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _submit,
      },
      child: row,
    );
  }

  Widget _buildRow(BuildContext context) {
    // Keep suffix actions outside the tile's merged editor semantics.
    Widget row({double? height}) => Row(
      crossAxisAlignment: widget.expands
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: YaruListTile.square(
            contentPadding: widget.expands ? EdgeInsets.zero : null,
            title: SizedBox(
              height: height,
              child: TextFormField(
                key: _fieldKey,
                controller: widget.controller,
                initialValue: widget.initialValue,
                enabled: widget.enabled,
                readOnly: widget.readOnly,
                autofocus: widget.autofocus,
                focusNode: widget.focusNode,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                minLines: widget.expands ? null : widget.minLines,
                maxLines: widget.expands ? null : widget.maxLines,
                expands: widget.expands,
                textInputAction: widget.textInputAction,
                textDirection: widget.textDirection,
                obscureText: widget.obscureText,
                enableSuggestions: widget.enableSuggestions,
                autocorrect: widget.autocorrect,
                style: widget.textStyle,
                onChanged: widget.enabled ? widget.onChanged : null,
                onFieldSubmitted: widget.enabled ? widget.onSubmitted : null,
                decoration: busyDataGroupedTextFieldDecoration(
                  context,
                  labelText: widget.label,
                  hintText: widget.hintText,
                  errorText: widget.errorText,
                  alignLabelWithHint: widget.alignLabelWithHint,
                ),
              ),
            ),
          ),
        ),
        if (widget.trailing case final trailing?)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: trailing,
          ),
      ],
    );
    return widget.expands
        ? LayoutBuilder(
            builder: (context, bounds) => row(height: bounds.maxHeight),
          )
        : row();
  }

  void _submit() {
    final value =
        widget.controller?.text ??
        _fieldKey.currentState?.value ??
        widget.initialValue ??
        '';
    widget.onSubmitted?.call(value);
  }
}

class BusyDataCompactIconButton extends StatelessWidget {
  const BusyDataCompactIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = BusyDataSizes.compactIconButton,
    this.glyphSize = BusyDataSizes.compactIcon,
    this.foregroundColor,
    this.focusNode,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double glyphSize;
  final Color? foregroundColor;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final colors = BusyDataSurfaceColors.of(context);
    final semanticStyle = ButtonStyle(
      foregroundColor: foregroundColor == null
          ? null
          : WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return colors.disabledForeground;
              }
              return foregroundColor;
            }),
    );
    final yaruDefaults = YaruIconButton(
      icon: const SizedBox.shrink(),
      iconSize: size,
    ).defaultStyleOf(context);
    final button = IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: glyphSize),
      constraints: BoxConstraints.tightFor(width: size, height: size),
      padding: EdgeInsets.zero,
      style: semanticStyle.merge(yaruDefaults),
      focusNode: focusNode,
      onPressed: onPressed,
    );
    final presented = YaruTheme.maybeOf(context)?.focusBorders == true
        ? YaruFocusBorder.primary(
            borderRadius: BorderRadius.circular(BusyDataRadius.pill),
            child: button,
          )
        : button;
    return MergeSemantics(
      child: Semantics(label: tooltip, child: presented),
    );
  }
}

class BusyDataCheckbox extends StatelessWidget {
  const BusyDataCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.tooltip,
    this.tristate = false,
    this.label,
  });

  final bool? value;
  final bool tristate;
  final String? tooltip;
  final String? label;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (label case final title?) {
      return YaruCheckButton(
        value: value,
        tristate: tristate,
        onChanged: onChanged,
        title: Text(title),
        contentPadding: EdgeInsets.zero,
        hasFocusBorder: true,
      );
    }
    final checkbox = YaruCheckbox(
      value: value,
      tristate: tristate,
      onChanged: onChanged,
    );
    final message = tooltip;
    if (message == null || message.isEmpty) {
      return checkbox;
    }
    return Tooltip(message: message, child: checkbox);
  }
}

enum BusyDataStatusKind { information, success, warning, error }

Color busyDataStatusColor(BuildContext context, BusyDataStatusKind kind) {
  final colors = YaruColors.of(context);
  return switch (kind) {
    BusyDataStatusKind.information => colors.link,
    BusyDataStatusKind.success => colors.success,
    BusyDataStatusKind.warning => colors.warning,
    BusyDataStatusKind.error => colors.error,
  };
}

/// Adapted from BusyMark's keyboard_shortcut_badge.dart (Apache-2.0).
class BusyDataKeyboardShortcutBadge extends StatelessWidget {
  const BusyDataKeyboardShortcutBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = BusyDataSurfaceColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.control,
        borderRadius: BorderRadius.circular(BusyDataRadius.sm),
        border: Border.all(color: colors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: BusyDataSpacing.sm,
          vertical: BusyDataSpacing.xxs,
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            label.replaceAll('+', '+\u200B'),
            semanticsLabel: label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: BusyDataTypography.monoFontFamily,
              fontFamilyFallback: BusyDataTypography.monoFontFamilyFallback,
              color: colors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class BusyDataStatusBox extends StatelessWidget {
  const BusyDataStatusBox({
    super.key,
    required this.message,
    this.kind = BusyDataStatusKind.information,
  });

  final String message;
  final BusyDataStatusKind kind;

  @override
  Widget build(BuildContext context) {
    return YaruInfoBox(
      yaruInfoType: switch (kind) {
        BusyDataStatusKind.information => YaruInfoType.information,
        BusyDataStatusKind.success => YaruInfoType.success,
        BusyDataStatusKind.warning => YaruInfoType.warning,
        BusyDataStatusKind.error => YaruInfoType.danger,
      },
      subtitle: SelectableText(message),
    );
  }
}

class BusyDataSyntaxColors extends ThemeExtension<BusyDataSyntaxColors> {
  const BusyDataSyntaxColors({
    required this.heading,
    required this.keyword,
    required this.tag,
    required this.attribute,
    required this.string,
    required this.literal,
    required this.link,
    required this.comment,
    required this.punctuation,
  });

  factory BusyDataSyntaxColors.fromSurfaceColors(
    Brightness brightness,
    BusyDataSurfaceColors colors,
  ) {
    final dark = brightness == Brightness.dark;
    return BusyDataSyntaxColors(
      heading: dark ? _darkHeading : _lightHeading,
      keyword: dark ? _darkKeyword : _lightKeyword,
      tag: dark ? _darkTag : _lightTag,
      attribute: dark ? _darkAttribute : _lightAttribute,
      string: dark ? _darkString : _lightString,
      literal: dark ? _darkLiteral : _lightLiteral,
      link: dark ? _darkLink : _lightLink,
      comment: colors.mutedForeground.withValues(alpha: dark ? .82 : .76),
      punctuation: colors.mutedForeground,
    );
  }

  static BusyDataSyntaxColors of(BuildContext context) {
    return Theme.of(context).extension<BusyDataSyntaxColors>() ??
        BusyDataSyntaxColors.fromSurfaceColors(
          Theme.of(context).brightness,
          BusyDataSurfaceColors.of(context),
        );
  }

  static const _darkHeading = Color(0xFF99C1F1);
  static const _lightHeading = Color(0xFF1A5FB4);
  static const _darkKeyword = Color(0xFFFFBE6F);
  static const _lightKeyword = Color(0xFF9C6B00);
  static const _darkTag = Color(0xFF8FF0A4);
  static const _lightTag = Color(0xFF2A7B43);
  static const _darkAttribute = Color(0xFFF9F06B);
  static const _lightAttribute = Color(0xFF865E00);
  static const _darkString = Color(0xFFF66151);
  static const _lightString = Color(0xFFC01C28);
  static const _darkLiteral = Color(0xFFDC8ADD);
  static const _lightLiteral = Color(0xFF813D9C);
  static const _darkLink = Color(0xFF62A0EA);
  static const _lightLink = Color(0xFF1C71D8);

  final Color heading;
  final Color keyword;
  final Color tag;
  final Color attribute;
  final Color string;
  final Color literal;
  final Color link;
  final Color comment;
  final Color punctuation;

  @override
  BusyDataSyntaxColors copyWith({
    Color? heading,
    Color? keyword,
    Color? tag,
    Color? attribute,
    Color? string,
    Color? literal,
    Color? link,
    Color? comment,
    Color? punctuation,
  }) {
    return BusyDataSyntaxColors(
      heading: heading ?? this.heading,
      keyword: keyword ?? this.keyword,
      tag: tag ?? this.tag,
      attribute: attribute ?? this.attribute,
      string: string ?? this.string,
      literal: literal ?? this.literal,
      link: link ?? this.link,
      comment: comment ?? this.comment,
      punctuation: punctuation ?? this.punctuation,
    );
  }

  @override
  BusyDataSyntaxColors lerp(covariant BusyDataSyntaxColors? other, double t) {
    if (other == null) {
      return this;
    }
    return BusyDataSyntaxColors(
      heading: Color.lerp(heading, other.heading, t)!,
      keyword: Color.lerp(keyword, other.keyword, t)!,
      tag: Color.lerp(tag, other.tag, t)!,
      attribute: Color.lerp(attribute, other.attribute, t)!,
      string: Color.lerp(string, other.string, t)!,
      literal: Color.lerp(literal, other.literal, t)!,
      link: Color.lerp(link, other.link, t)!,
      comment: Color.lerp(comment, other.comment, t)!,
      punctuation: Color.lerp(punctuation, other.punctuation, t)!,
    );
  }
}

/// The 18px expander slot and 14px directional arrow from BusyMark's tree row.
/// Its containing Explorer row retains keyboard focus and activation ownership.
class BusyDataSidebarTreeControl extends StatelessWidget {
  const BusyDataSidebarTreeControl({
    super.key,
    required this.expanded,
    required this.label,
    required this.onToggle,
  });
  final bool expanded;
  final String label;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: BusyDataSizes.sidebarTreeControl,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: AnimatedRotation(
            turns: expanded
                ? rtl
                      ? -.25
                      : .25
                : 0,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 120),
            child: Transform.flip(
              flipX: rtl,
              child: const Icon(
                YaruIcons.pan_end,
                size: BusyDataSizes.sidebarTreeArrow,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A GTK-style navigation list for a persistent desktop sidebar.
class BusyDataSidebarNavigation extends StatelessWidget {
  const BusyDataSidebarNavigation({
    super.key,
    required this.children,
    this.surfaceColor,
  });

  final List<Widget> children;
  final Color? surfaceColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = BusyDataSurfaceColors.of(context);
    final masterDetailTheme = YaruMasterDetailTheme.of(context);

    return Theme(
      data: theme.copyWith(
        listTileTheme: theme.listTileTheme.copyWith(
          selectedColor: colors.foreground,
          selectedTileColor: Color.alphaBlend(
            colors.control,
            surfaceColor ?? colors.sidebar,
          ),
          tileColor: Colors.transparent,
          iconColor: colors.mutedForeground,
          textColor: colors.foreground,
          titleTextStyle: theme.textTheme.bodyMedium,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: BusyDataSpacing.sm,
          ),
          horizontalTitleGap: BusyDataSpacing.sm,
          minVerticalPadding: 0,
          minLeadingWidth: BusyDataSizes.iconSm,
          minTileHeight: BusyDataSizes.sidebarRowHeight,
          visualDensity: VisualDensity.standard,
          titleAlignment: ListTileTitleAlignment.center,
        ),
      ),
      child: ListView.separated(
        padding:
            masterDetailTheme.listPadding ??
            const EdgeInsets.symmetric(vertical: BusyDataSpacing.sm),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
        separatorBuilder: (context, index) => SizedBox(
          height: masterDetailTheme.tileSpacing ?? BusyDataSpacing.xxs,
        ),
      ),
    );
  }
}

/// A selectable row for [BusyDataSidebarNavigation].
class BusyDataSidebarNavigationTile extends StatelessWidget {
  const BusyDataSidebarNavigationTile({
    super.key,
    required this.selected,
    required this.leading,
    required this.title,
    required this.onTap,
  });

  final bool selected;
  final Widget leading;
  final Widget title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return YaruMasterTile(
      selected: selected,
      leading: IconTheme.merge(
        data: const IconThemeData(size: BusyDataSizes.iconSm),
        child: leading,
      ),
      title: title,
      onTap: onTap,
    );
  }
}
