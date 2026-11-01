import 'package:flutter/widgets.dart';
import 'presentation_diagnostics.dart';

/// Resolved platform colors are paired with the surfaces they are painted on.
/// Database widgets never infer native selection or separators from opacity.
@immutable
class DesktopAppearance {
  const DesktopAppearance({
    required this.window,
    required this.view,
    required this.sidebar,
    required this.header,
    required this.dialog,
    required this.popover,
    required this.foreground,
    required this.secondaryForeground,
    required this.disabledForeground,
    required this.hover,
    required this.pressed,
    required this.selected,
    required this.selectedForeground,
    required this.unfocusedSelection,
    required this.unfocusedSelectionForeground,
    required this.separator,
    required this.controlBorder,
    required this.gridLine,
    required this.focus,
    required this.success,
    required this.warning,
    required this.error,
    required this.unknown,
    required this.staged,
    required this.stagedForeground,
    required this.textSelection,
    required this.body,
    required this.heading,
    required this.caption,
    required this.technical,
    required this.highContrast,
    this.lineExtent,
    this.syntaxStyles,
    this.sourceCaret,
    this.sourceLineHeight,
    this.sourceLineNumberScale = 1,
    this.sourceFoldWidth = 20,
  });

  final Color window, view, sidebar, header, dialog, popover;
  final Color foreground, secondaryForeground, disabledForeground;
  final Color hover, pressed, selected, selectedForeground;
  final Color unfocusedSelection, unfocusedSelectionForeground;
  final Color separator, controlBorder, gridLine, focus;
  final Color success, warning, error, unknown, staged, stagedForeground;

  /// Selection beneath editor glyphs, whose foreground cannot be inverted.
  final Color textSelection;
  final TextStyle body, heading, caption, technical;
  final bool highContrast;

  /// A platform scope may measure this once for its exact inherited typography.
  /// Standalone controls still measure against their own current allocation.
  final double? lineExtent;
  final Map<String, TextStyle>? syntaxStyles;
  final Color? sourceCaret;
  final double? sourceLineHeight;
  final double sourceLineNumberScale, sourceFoldWidth;

  Color rowBackground({
    required bool selected,
    bool focused = true,
    bool hovered = false,
    bool pressed = false,
    Color? base,
  }) => selected
      ? focused
            ? this.selected
            : unfocusedSelection
      : pressed
      ? this.pressed
      : hovered
      ? hover
      : base ?? view;

  Color rowForeground({
    required bool selected,
    bool focused = true,
    bool enabled = true,
  }) => !enabled && !selected
      ? disabledForeground
      : selected
      ? focused
            ? selectedForeground
            : unfocusedSelectionForeground
      : foreground;

  /// Measure one representative line, never all rows in a database result.
  double lineHeight(BuildContext context) =>
      lineExtent ?? measureLineHeight(context, body);

  static double measureLineHeight(BuildContext context, TextStyle style) {
    final watch = PresentationDiagnostics.start('line-metric-layout');
    final painter = TextPainter(
      text: TextSpan(text: 'Ag国', style: style),
      locale: Localizations.maybeLocaleOf(context),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final height = painter.height;
    painter.dispose();
    PresentationDiagnostics.finish('line-metric-layout', watch);
    return height;
  }

  double rowHeight(BuildContext context) =>
      (lineHeight(context) + 12).clamp(28, double.infinity);
  double controlHeight(BuildContext context) =>
      (lineHeight(context) + 12).clamp(32, double.infinity);
}
