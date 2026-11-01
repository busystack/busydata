import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../busydata_design.dart';
import '../busydata_surface_colors.dart';
import '../../platform/gtk_header_icon_service.dart';
import 'linux_window_host.dart';

abstract final class BusyDataLinuxHeaderStyle {
  static const double symbolicIconSize = 16;
  static const double compoundButtonHorizontalPadding = 9;
  static const double compoundButtonVerticalPadding = 4;
  static const double viewIconGap = 6;
  static const double controlRadius = BusyDataRadius.headerButton;
  static const double activeForegroundOpacity = 1;
  static const double inactiveForegroundOpacity = .50;
  static const double disabledActiveForegroundOpacity = .38;
  static const double disabledInactiveForegroundOpacity = .19;
  static const double hoverBackgroundStrength = .07;
  static const double pressedBackgroundStrength = .16;
  static const double selectedBackgroundStrength = .10;
  static const double selectedHoverBackgroundStrength = .13;
  static const double selectedPressedBackgroundStrength = .19;
}

/// Physical window-control obstructions inside the current main header.
///
/// These remain physical in RTL because GTK's decoration layout is physical.
/// Application-header layouts consume them at their corresponding edge while
/// retaining the complete header as the title-centering coordinate system.
class LinuxPageHeaderInsetsScope extends InheritedWidget {
  const LinuxPageHeaderInsetsScope({
    super.key,
    required this.leftObstruction,
    required this.rightObstruction,
    required super.child,
  });

  final double leftObstruction;
  final double rightObstruction;

  static const _fallback = LinuxPageHeaderInsetsScope(
    leftObstruction: 0,
    rightObstruction: 0,
    child: SizedBox.shrink(),
  );

  static LinuxPageHeaderInsetsScope of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LinuxPageHeaderInsetsScope>() ??
      _fallback;

  @override
  bool updateShouldNotify(LinuxPageHeaderInsetsScope oldWidget) =>
      leftObstruction != oldWidget.leftObstruction ||
      rightObstruction != oldWidget.rightObstruction;
}

Color busyDataLinuxHeaderForeground(
  BuildContext context, {
  bool disabled = false,
}) {
  final active = LinuxWindowMetricsScope.of(context).windowActive;
  final opacity = switch ((active, disabled)) {
    (true, false) => BusyDataLinuxHeaderStyle.activeForegroundOpacity,
    (false, false) => BusyDataLinuxHeaderStyle.inactiveForegroundOpacity,
    (true, true) => BusyDataLinuxHeaderStyle.disabledActiveForegroundOpacity,
    (false, true) => BusyDataLinuxHeaderStyle.disabledInactiveForegroundOpacity,
  };
  final foreground = BusyDataSurfaceColors.of(context).foreground;
  return foreground.withValues(alpha: foreground.a * opacity);
}

TextStyle busyDataLinuxHeaderTitleStyle(BuildContext context) =>
    _busyDataLinuxHeaderTextStyle(context, busyDataHeaderTitleStyle(context));

TextStyle busyDataLinuxHeaderBrandStyle(BuildContext context) =>
    _busyDataLinuxHeaderTextStyle(context, busyDataHeaderBrandStyle(context));

TextStyle _busyDataLinuxHeaderTextStyle(BuildContext context, TextStyle style) {
  final baseColor = style.color ?? BusyDataSurfaceColors.of(context).foreground;
  final opacity = LinuxWindowMetricsScope.of(context).windowActive
      ? BusyDataLinuxHeaderStyle.activeForegroundOpacity
      : BusyDataLinuxHeaderStyle.inactiveForegroundOpacity;
  return style.copyWith(
    color: baseColor.withValues(alpha: baseColor.a * opacity),
  );
}

WidgetStateProperty<Color?> busyDataLinuxHeaderControlBackground(
  BuildContext context,
) {
  final foreground = busyDataLinuxHeaderForeground(context);
  Color layer(double strength) =>
      foreground.withValues(alpha: foreground.a * strength);
  return WidgetStateProperty.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) return Colors.transparent;
    final selected = states.contains(WidgetState.selected);
    final pressed = states.contains(WidgetState.pressed);
    final hovered = states.contains(WidgetState.hovered);
    if (selected && pressed) {
      return layer(BusyDataLinuxHeaderStyle.selectedPressedBackgroundStrength);
    }
    if (selected && hovered) {
      return layer(BusyDataLinuxHeaderStyle.selectedHoverBackgroundStrength);
    }
    if (pressed) {
      return layer(BusyDataLinuxHeaderStyle.pressedBackgroundStrength);
    }
    if (selected) {
      return layer(BusyDataLinuxHeaderStyle.selectedBackgroundStrength);
    }
    if (hovered) {
      return layer(BusyDataLinuxHeaderStyle.hoverBackgroundStrength);
    }
    return Colors.transparent;
  });
}

class BusyDataLinuxHeaderIconButton extends StatelessWidget {
  const BusyDataLinuxHeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.focusNode,
    this.selected = false,
    this.selectedIcon,
    this.semanticLabel,
  });

  final BusyDataLinuxHeaderIcon icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool selected;
  final BusyDataLinuxHeaderIcon? selectedIcon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final button = BusyDataHeaderIconButton(
      icon: BusyDataGtkHeaderIcon(icon),
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      focusNode: focusNode,
      isSelected: selected,
      selectedIcon: selectedIcon == null
          ? null
          : BusyDataGtkHeaderIcon(selectedIcon!),
      iconSize: BusyDataLinuxHeaderStyle.symbolicIconSize,
      fixedSize: const Size.square(BusyDataSizes.headerIconButton),
      foregroundColor: busyDataLinuxHeaderForeground(context),
      disabledForegroundColor: busyDataLinuxHeaderForeground(
        context,
        disabled: true,
      ),
      backgroundColor: busyDataLinuxHeaderControlBackground(context),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          BusyDataLinuxHeaderStyle.controlRadius,
        ),
      ),
      focusBorderRadius: BusyDataLinuxHeaderStyle.controlRadius,
    );
    return button;
  }
}

class BusyDataLinuxHeaderMenuButton<T> extends StatelessWidget {
  const BusyDataLinuxHeaderMenuButton({
    super.key,
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    this.icon = BusyDataLinuxHeaderIcon.mainMenu,
    this.controller,
    this.enabled = true,
    this.highlightWhenOpen = true,
  });

  final String tooltip;
  final BusyDataLinuxHeaderIcon icon;
  final List<BusyDataMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final BusyDataMenuController? controller;
  final bool enabled;
  final bool highlightWhenOpen;

  @override
  Widget build(BuildContext context) {
    return BusyDataMenuButton<T>(
      tooltip: tooltip,
      icon: BusyDataGtkHeaderIcon(icon),
      entries: entries,
      onSelected: onSelected,
      controller: controller,
      enabled: enabled,
      highlightWhenOpen: highlightWhenOpen,
      triggerBuilder: (context, trigger) => trigger.anchor(
        child: BusyDataLinuxHeaderIconButton(
          icon: icon,
          tooltip: tooltip,
          focusNode: trigger.focusNode,
          selected: highlightWhenOpen && trigger.isOpen,
          onPressed: trigger.onPressed,
        ),
      ),
    );
  }
}

class BusyDataLinuxViewMenuButton<T> extends StatelessWidget {
  const BusyDataLinuxViewMenuButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.entries,
    required this.onSelected,
    this.controller,
    this.enabled = true,
  });

  final String tooltip;
  final BusyDataLinuxHeaderIcon icon;
  final List<BusyDataMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final BusyDataMenuController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return BusyDataMenuButton<T>(
      tooltip: tooltip,
      icon: BusyDataGtkHeaderIcon(icon),
      entries: entries,
      onSelected: onSelected,
      controller: controller,
      enabled: enabled,
      triggerBuilder: (context, trigger) => trigger.anchor(
        child: _BusyDataLinuxViewMenuTrigger(
          tooltip: tooltip,
          icon: icon,
          focusNode: trigger.focusNode,
          selected: trigger.isOpen,
          onPressed: trigger.onPressed,
        ),
      ),
    );
  }
}

class _BusyDataLinuxViewMenuTrigger extends StatelessWidget {
  const _BusyDataLinuxViewMenuTrigger({
    required this.tooltip,
    required this.icon,
    required this.focusNode,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final BusyDataLinuxHeaderIcon icon;
  final FocusNode focusNode;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = busyDataLinuxHeaderForeground(context);
    final disabledForeground = busyDataLinuxHeaderForeground(
      context,
      disabled: true,
    );
    final baseBackground = busyDataLinuxHeaderControlBackground(context);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(
        Size(0, BusyDataSizes.headerIconButton),
      ),
      maximumSize: const WidgetStatePropertyAll(
        Size(double.infinity, BusyDataSizes.headerIconButton),
      ),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(
          horizontal: BusyDataLinuxHeaderStyle.compoundButtonHorizontalPadding,
          vertical: BusyDataLinuxHeaderStyle.compoundButtonVerticalPadding,
        ),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? disabledForeground
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) => baseBackground.resolve({
          ...states,
          if (selected) WidgetState.selected,
        }),
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            BusyDataLinuxHeaderStyle.controlRadius,
          ),
        ),
      ),
      animationDuration: BusyDataMotion.fast,
      splashFactory: NoSplash.splashFactory,
    );
    final button = SizedBox(
      height: BusyDataSizes.headerIconButton,
      child: TextButton(
        focusNode: focusNode,
        onPressed: onPressed,
        style: style,
        child: Builder(
          builder: (context) => IconTheme(
            data: IconThemeData(
              color: DefaultTextStyle.of(context).style.color,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BusyDataGtkHeaderIcon(icon),
                const SizedBox(width: BusyDataLinuxHeaderStyle.viewIconGap),
                const BusyDataGtkHeaderIcon(
                  BusyDataLinuxHeaderIcon.viewMenuArrow,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final focused = YaruTheme.maybeOf(context)?.focusBorders == true
        ? YaruFocusBorder.primary(
            borderRadius: BorderRadius.circular(
              BusyDataLinuxHeaderStyle.controlRadius,
            ),
            child: button,
          )
        : button;
    return Tooltip(message: tooltip, child: focused);
  }
}

class BusyDataGtkHeaderIcon extends StatelessWidget {
  const BusyDataGtkHeaderIcon(this.icon, {super.key, this.direction});

  final BusyDataLinuxHeaderIcon icon;
  final TextDirection? direction;

  @override
  Widget build(BuildContext context) {
    final effectiveDirection = direction ?? Directionality.of(context);
    final asset = GtkHeaderIconScope.of(
      context,
    ).catalog.assetFor(icon, effectiveDirection);
    final glyph = switch (icon) {
      BusyDataLinuxHeaderIcon.back || BusyDataLinuxHeaderIcon.previous =>
        effectiveDirection == TextDirection.rtl
            ? YaruIcons.go_next
            : YaruIcons.go_previous,
      BusyDataLinuxHeaderIcon.next =>
        effectiveDirection == TextDirection.rtl
            ? YaruIcons.go_previous
            : YaruIcons.go_next,
      BusyDataLinuxHeaderIcon.sidebar => YaruIcons.sidebar,
      BusyDataLinuxHeaderIcon.search ||
      BusyDataLinuxHeaderIcon.searchEntryFind => YaruIcons.search,
      BusyDataLinuxHeaderIcon.searchClear ||
      BusyDataLinuxHeaderIcon.close => YaruIcons.window_close,
      BusyDataLinuxHeaderIcon.mainMenu => YaruIcons.view_more,
      BusyDataLinuxHeaderIcon.create => YaruIcons.plus,
      BusyDataLinuxHeaderIcon.refresh => YaruIcons.refresh,
      BusyDataLinuxHeaderIcon.viewMenuArrow => YaruIcons.pan_down,
      BusyDataLinuxHeaderIcon.filter => Icons.filter_list,
    };
    if (asset == null) {
      return Icon(
        glyph,
        size: BusyDataLinuxHeaderStyle.symbolicIconSize,
        textDirection: effectiveDirection,
      );
    }
    return ExcludeSemantics(
      child: Image.memory(
        asset.bytes,
        width: BusyDataLinuxHeaderStyle.symbolicIconSize,
        height: BusyDataLinuxHeaderStyle.symbolicIconSize,
        scale: asset.scale.toDouble(),
        color: IconTheme.of(context).color,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
      ),
    );
  }
}

class BusyDataLinuxHeaderControlGroup extends StatelessWidget {
  const BusyDataLinuxHeaderControlGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return BusyDataHeaderControlStyleScope(
      foregroundColor: busyDataLinuxHeaderForeground(context),
      disabledForegroundColor: busyDataLinuxHeaderForeground(
        context,
        disabled: true,
      ),
      backgroundColor: busyDataLinuxHeaderControlBackground(context),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: BusyDataSpacing.headerInset),
            children[index],
          ],
        ],
      ),
    );
  }
}

enum _BusyDataLinuxHeaderSlot { leading, title, trailing }

enum BusyDataLinuxHeaderCenterAllocation { centered, fillBetweenControls }

/// GTK-style application header geometry with an explicit center allocation.
class BusyDataLinuxHeaderLayout extends StatelessWidget {
  const BusyDataLinuxHeaderLayout({
    super.key,
    required this.leading,
    required this.title,
    required this.trailing,
    this.maxContentWidth,
    this.centerAllocation = BusyDataLinuxHeaderCenterAllocation.centered,
  });

  final Widget leading;
  final Widget title;
  final Widget trailing;
  final double? maxContentWidth;
  final BusyDataLinuxHeaderCenterAllocation centerAllocation;

  @override
  Widget build(BuildContext context) {
    final insets = LinuxPageHeaderInsetsScope.of(context);
    final direction = Directionality.of(context);
    return SizedBox(
      height: BusyDataSizes.toolbarHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const LinuxTitlebarGestureRegion(child: SizedBox.expand()),
          CustomMultiChildLayout(
            delegate: _BusyDataLinuxHeaderLayoutDelegate(
              direction: direction,
              leftObstruction: insets.leftObstruction,
              rightObstruction: insets.rightObstruction,
              maxContentWidth: maxContentWidth,
              centerAllocation: centerAllocation,
            ),
            children: [
              LayoutId(id: _BusyDataLinuxHeaderSlot.leading, child: leading),
              LayoutId(id: _BusyDataLinuxHeaderSlot.title, child: title),
              LayoutId(id: _BusyDataLinuxHeaderSlot.trailing, child: trailing),
            ],
          ),
        ],
      ),
    );
  }
}

class _BusyDataLinuxHeaderLayoutDelegate extends MultiChildLayoutDelegate {
  _BusyDataLinuxHeaderLayoutDelegate({
    required this.direction,
    required this.leftObstruction,
    required this.rightObstruction,
    required this.maxContentWidth,
    required this.centerAllocation,
  });

  final TextDirection direction;
  final double leftObstruction;
  final double rightObstruction;
  final double? maxContentWidth;
  final BusyDataLinuxHeaderCenterAllocation centerAllocation;

  @override
  void performLayout(Size size) {
    final centeredInset = maxContentWidth == null
        ? 0.0
        : math.max(0.0, (size.width - maxContentWidth!) / 2);
    final leftInset = math.max(
      leftObstruction + BusyDataSpacing.headerInset,
      centeredInset,
    );
    final rightInset = math.max(
      rightObstruction + BusyDataSpacing.headerInset,
      centeredInset,
    );
    final sideConstraints = BoxConstraints.loose(size);
    final leadingSize = layoutChild(
      _BusyDataLinuxHeaderSlot.leading,
      sideConstraints,
    );
    final trailingSize = layoutChild(
      _BusyDataLinuxHeaderSlot.trailing,
      sideConstraints,
    );

    late final Offset leadingOffset;
    late final Offset trailingOffset;
    late final double leftOccupiedEdge;
    late final double rightOccupiedEdge;
    if (direction == TextDirection.ltr) {
      leadingOffset = Offset(leftInset, (size.height - leadingSize.height) / 2);
      trailingOffset = Offset(
        size.width - rightInset - trailingSize.width,
        (size.height - trailingSize.height) / 2,
      );
      leftOccupiedEdge = leadingOffset.dx + leadingSize.width;
      rightOccupiedEdge = trailingOffset.dx;
    } else {
      leadingOffset = Offset(
        size.width - rightInset - leadingSize.width,
        (size.height - leadingSize.height) / 2,
      );
      trailingOffset = Offset(
        leftInset,
        (size.height - trailingSize.height) / 2,
      );
      leftOccupiedEdge = trailingOffset.dx + trailingSize.width;
      rightOccupiedEdge = leadingOffset.dx;
    }
    positionChild(_BusyDataLinuxHeaderSlot.leading, leadingOffset);
    positionChild(_BusyDataLinuxHeaderSlot.trailing, trailingOffset);

    final safeLeftEdge = leftOccupiedEdge + BusyDataSpacing.headerInset;
    final safeRightEdge = rightOccupiedEdge - BusyDataSpacing.headerInset;
    switch (centerAllocation) {
      case BusyDataLinuxHeaderCenterAllocation.centered:
        final centerX = (safeLeftEdge + safeRightEdge) / 2;
        final availableWidth = math.max(0.0, safeRightEdge - safeLeftEdge);
        final titleSize = layoutChild(
          _BusyDataLinuxHeaderSlot.title,
          BoxConstraints.loose(Size(availableWidth, size.height)),
        );
        positionChild(
          _BusyDataLinuxHeaderSlot.title,
          Offset(
            centerX - titleSize.width / 2,
            (size.height - titleSize.height) / 2,
          ),
        );
      case BusyDataLinuxHeaderCenterAllocation.fillBetweenControls:
        final availableWidth = math.max(0.0, safeRightEdge - safeLeftEdge);
        final titleSize = layoutChild(
          _BusyDataLinuxHeaderSlot.title,
          BoxConstraints(
            minWidth: availableWidth,
            maxWidth: availableWidth,
            minHeight: 0,
            maxHeight: size.height,
          ),
        );
        positionChild(
          _BusyDataLinuxHeaderSlot.title,
          Offset(safeLeftEdge, (size.height - titleSize.height) / 2),
        );
    }
  }

  @override
  bool shouldRelayout(_BusyDataLinuxHeaderLayoutDelegate oldDelegate) =>
      direction != oldDelegate.direction ||
      leftObstruction != oldDelegate.leftObstruction ||
      rightObstruction != oldDelegate.rightObstruction ||
      maxContentWidth != oldDelegate.maxContentWidth ||
      centerAllocation != oldDelegate.centerAllocation;
}

class BusyDataLinuxHeaderTitle extends StatelessWidget {
  const BusyDataLinuxHeaderTitle(this.text, {super.key, this.brand = false});

  final String text;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    return LinuxTitlebarGestureRegion(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BusyDataSpacing.md),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: brand
              ? busyDataLinuxHeaderBrandStyle(context)
              : busyDataLinuxHeaderTitleStyle(context),
        ),
      ),
    );
  }
}

/// The bounded center-slot presentation corresponding to the former native
/// `GtkSearchEntry` title-stack child.
ButtonStyle busyDataLinuxHeaderTextButtonStyle(
  BuildContext context, {
  required bool suggested,
}) {
  final geometry = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(BusyDataSizes.headerIconButton, BusyDataSizes.headerIconButton),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: BusyDataSpacing.md),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    textStyle: WidgetStatePropertyAll(
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.normal,
      ),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          BusyDataLinuxHeaderStyle.controlRadius,
        ),
      ),
    ),
    animationDuration: BusyDataMotion.fast,
    splashFactory: NoSplash.splashFactory,
  );
  if (suggested) return geometry;
  return geometry.copyWith(
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? busyDataLinuxHeaderForeground(context, disabled: true)
          : busyDataLinuxHeaderForeground(context),
    ),
    backgroundColor: busyDataLinuxHeaderControlBackground(context),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    elevation: const WidgetStatePropertyAll(0),
    shadowColor: const WidgetStatePropertyAll(Colors.transparent),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

class BusyDataLinuxHeaderTextButton extends StatelessWidget {
  const BusyDataLinuxHeaderTextButton.standard({
    super.key,
    required this.label,
    required this.onPressed,
  }) : suggested = false;

  const BusyDataLinuxHeaderTextButton.suggested({
    super.key,
    required this.label,
    required this.onPressed,
  }) : suggested = true;

  final String label;
  final VoidCallback? onPressed;
  final bool suggested;

  @override
  Widget build(BuildContext context) {
    final style = busyDataLinuxHeaderTextButtonStyle(
      context,
      suggested: suggested,
    );
    return suggested
        ? BusyDataPushButton.suggested(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          )
        : BusyDataPushButton.standard(
            onPressed: onPressed,
            style: style,
            child: Text(label),
          );
  }
}
