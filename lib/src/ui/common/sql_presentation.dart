import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'desktop_controls.dart';

/// The retained main editor invalidates appearance only when a consumed role
/// changes. Background database progress keeps the same live editor subtree.
Object sqlPresentationSignature(
  BuildContext context,
  DesktopControls controls,
) {
  final look = controls.appearance(context);
  return (
    look.view,
    look.foreground,
    look.secondaryForeground,
    look.textSelection,
    look.focus,
    look.staged,
    look.separator,
    look.technical,
    Object.hashAll(
      look.syntaxStyles?.entries.map((entry) => (entry.key, entry.value)) ??
          const [],
    ),
    look.highContrast,
    look.sourceCaret,
    look.sourceLineHeight,
    look.sourceLineNumberScale,
    look.sourceFoldWidth,
  );
}

/// Appearance only: callers retain their editor, controllers and scroll owner.
CodeEditorStyle sqlEditorStyle(BuildContext context, DesktopControls controls) {
  final look = controls.appearance(context);
  final syntax =
      look.syntaxStyles ??
      (look.view.computeLuminance() < .5
          ? atomOneDarkTheme
          : atomOneLightTheme);
  return CodeEditorStyle(
    fontSize: look.technical.fontSize,
    fontHeight: look.sourceLineHeight,
    fontFamily: look.technical.fontFamily,
    fontFamilyFallback: look.technical.fontFamilyFallback,
    textColor: look.foreground,
    hintTextColor: look.secondaryForeground,
    backgroundColor: look.view,
    selectionColor: look.textSelection,
    highlightColor: look.staged,
    cursorColor: look.sourceCaret ?? look.focus,
    cursorWidth: 1.4,
    cursorLineColor: look.separator,
    chunkIndicatorColor: look.secondaryForeground,
    codeTheme: CodeHighlightTheme(
      languages: {'sql': CodeHighlightThemeMode(mode: langSql)},
      theme: look.highContrast
          ? {
              'root': TextStyle(color: look.foreground),
              'keyword': TextStyle(
                color: look.foreground,
                fontWeight: FontWeight.bold,
              ),
              'comment': TextStyle(
                color: look.foreground,
                fontStyle: FontStyle.italic,
              ),
            }
          : {
              for (final entry in syntax.entries)
                entry.key: entry.value.copyWith(
                  color: _readable(
                    entry.value.color ?? look.foreground,
                    look.foreground,
                    look.view,
                  ),
                ),
              'root': TextStyle(color: look.foreground),
            },
    ),
  );
}

Widget sqlEditorIndicators(
  BuildContext context,
  DesktopControls controls,
  CodeLineEditingController editing,
  CodeChunkController chunks,
  CodeIndicatorValueNotifier notifier,
) {
  final look = controls.appearance(context);
  return ColoredBox(
    color: look.view,
    child: Row(
      children: [
        DefaultCodeLineNumber(
          controller: editing,
          notifier: notifier,
          textStyle: look.technical.copyWith(
            fontSize:
                MediaQuery.textScalerOf(
                  context,
                ).scale(look.technical.fontSize ?? 14) *
                look.sourceLineNumberScale,
            color: look.secondaryForeground,
          ),
          focusedTextStyle: look.technical.copyWith(
            fontSize:
                MediaQuery.textScalerOf(
                  context,
                ).scale(look.technical.fontSize ?? 14) *
                look.sourceLineNumberScale,
            fontWeight: FontWeight.w700,
          ),
        ),
        DefaultCodeChunkIndicator(
          width: look.sourceFoldWidth,
          controller: chunks,
          notifier: notifier,
          painter: DefaultCodeChunkIndicatorPainter(
            color: look.secondaryForeground,
          ),
        ),
      ],
    ),
  );
}

Color _readable(Color candidate, Color foreground, Color background) {
  double ratio(Color color) {
    final first = Color.alphaBlend(color, background).computeLuminance();
    final second = background.computeLuminance();
    return (math.max(first, second) + .05) / (math.min(first, second) + .05);
  }

  for (var step = 0; step <= 10; step++) {
    final color = Color.lerp(candidate, foreground, step / 10)!;
    if (ratio(color) >= 4.5) return color;
  }
  return foreground;
}
