import 'package:flutter/material.dart';
import 'package:yaru/yaru.dart';

import '../../app/busydata_surface_colors.dart';
import '../../app/busydata_design.dart'
    show BusyDataSyntaxColors, BusyDataTypography, BusyDataAlpha;
import '../common/desktop_appearance.dart';
import '../common/presentation_diagnostics.dart';

/// Resolve against the current app scope. Its retained value is invalidated by
/// effective native theme, font, scale, locale and direction dependencies.
DesktopAppearance linuxAppearance(BuildContext context) {
  PresentationDiagnostics.count('appearance-lookup');
  return context
          .dependOnInheritedWidgetOfExactType<_LinuxAppearance>()
          ?.value ??
      _resolveLinuxAppearance(context);
}

class LinuxAppearanceScope extends StatefulWidget {
  const LinuxAppearanceScope({super.key, required this.child});
  final Widget child;
  @override
  State<LinuxAppearanceScope> createState() => _LinuxAppearanceScopeState();
}

class _LinuxAppearanceScopeState extends State<LinuxAppearanceScope> {
  Object? _signature;
  DesktopAppearance? _value;
  @override
  Widget build(BuildContext context) {
    final signature = (
      Theme.of(context),
      BusyDataSurfaceColors.of(context),
      YaruColors.of(context),
      MediaQuery.highContrastOf(context),
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
      Localizations.maybeLocaleOf(context),
    );
    if (_signature != signature) {
      _signature = signature;
      _value = _resolveLinuxAppearance(context, measureLine: true);
    }
    return _LinuxAppearance(value: _value!, child: widget.child);
  }
}

class _LinuxAppearance extends InheritedWidget {
  const _LinuxAppearance({required this.value, required super.child});
  final DesktopAppearance value;
  @override
  bool updateShouldNotify(_LinuxAppearance oldWidget) =>
      !identical(value, oldWidget.value);
}

DesktopAppearance _resolveLinuxAppearance(
  BuildContext context, {
  bool measureLine = false,
}) {
  final watch = PresentationDiagnostics.start('appearance-resolution');
  final theme = Theme.of(context);
  final colors = BusyDataSurfaceColors.of(context);
  final scheme = theme.colorScheme;
  final contrast = scheme.isHighContrast || MediaQuery.highContrastOf(context);
  final native = YaruColors.of(context);
  final body = theme.textTheme.bodyMedium!;
  // These are deliberate native component layers, resolved once at the adapter.
  final selected = contrast
      ? scheme.primary
      : Color.alphaBlend(colors.controlActive, colors.sidebar);
  // GTK's active-toggle fill can be white on a white view. A pressed
  // control layer is the neutral unfocused-selection role, not toggle artwork.
  final unfocused = Color.alphaBlend(colors.controlActive, colors.view);
  final staged = Color.alphaBlend(
    native.warning.withValues(alpha: .12),
    colors.view,
  );
  final syntax = BusyDataSyntaxColors.of(context);
  final result = DesktopAppearance(
    sourceCaret: colors.foreground.withValues(
      alpha: BusyDataAlpha.sourceCursor,
    ),
    sourceLineHeight: BusyDataTypography.sourceEditorLineHeight,
    sourceLineNumberScale: BusyDataTypography.sourceLineNumberScale,
    sourceFoldWidth: 16,
    syntaxStyles: {
      'root': TextStyle(color: colors.foreground),
      'keyword': TextStyle(color: syntax.keyword),
      'built_in': TextStyle(color: syntax.tag),
      'type': TextStyle(color: syntax.tag),
      'attr': TextStyle(color: syntax.attribute),
      'string': TextStyle(color: syntax.string),
      'number': TextStyle(color: syntax.literal),
      'literal': TextStyle(color: syntax.literal),
      'symbol': TextStyle(color: syntax.link),
      'comment': TextStyle(color: syntax.comment),
      'punctuation': TextStyle(color: syntax.punctuation),
    },
    window: colors.window,
    view: colors.view,
    sidebar: colors.sidebar,
    header: colors.headerbarFlat,
    dialog: colors.dialog,
    popover: colors.popover,
    foreground: colors.foreground,
    secondaryForeground: contrast ? colors.foreground : colors.mutedForeground,
    disabledForeground: colors.disabledForeground,
    hover: Color.alphaBlend(colors.controlHover, colors.view),
    pressed: Color.alphaBlend(colors.controlActive, colors.view),
    selected: selected,
    selectedForeground: contrast ? scheme.onPrimary : colors.foreground,
    unfocusedSelection: contrast ? colors.controlActive : unfocused,
    unfocusedSelectionForeground: colors.foreground,
    separator: colors.divider,
    controlBorder: colors.border,
    gridLine: colors.divider,
    focus: scheme.primary,
    success: native.success,
    warning: native.warning,
    error: scheme.error,
    unknown: colors.mutedForeground,
    staged: staged,
    stagedForeground: colors.foreground,
    textSelection: contrast ? colors.controlActive : scheme.primaryContainer,
    body: body.copyWith(color: colors.foreground),
    heading: body.copyWith(
      color: colors.foreground,
      fontWeight: FontWeight.w700,
    ),
    caption: theme.textTheme.bodySmall!.copyWith(color: colors.mutedForeground),
    technical: body.copyWith(
      fontFamily: BusyDataTypography.monoFontFamily,
      fontFamilyFallback: BusyDataTypography.monoFontFamilyFallback,
      height: BusyDataTypography.codeLineHeight,
      leadingDistribution: TextLeadingDistribution.even,
      color: colors.foreground,
    ),
    highContrast: contrast,
    lineExtent: measureLine
        ? DesktopAppearance.measureLineHeight(context, body)
        : null,
  );
  PresentationDiagnostics.finish('appearance-resolution', watch);
  return result;
}
