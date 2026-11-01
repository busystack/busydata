import 'dart:io';
import 'package:flutter/material.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';

/// Bounded inspection of the mounted workbench's effective platform inputs.
/// No document, result, controller or database values are read.
Map<String, Object?> presentationEnvironment() {
  Element? workbench;
  var visited = 0;
  void visit(Element element) {
    if (workbench != null || ++visited > 4096) return;
    if (element.widget is WorkbenchView) {
      workbench = element;
    } else {
      element.visitChildren(visit);
    }
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  final context = workbench;
  if (context == null) return {'available': false};
  final media = MediaQuery.of(context), theme = Theme.of(context);
  final body = theme.textTheme.bodyMedium!;
  return {
    'available': true,
    'viewport': {'width': media.size.width, 'height': media.size.height},
    'displayScale': media.devicePixelRatio,
    'textScaleAt14': media.textScaler.scale(14),
    'brightness': theme.brightness.name,
    'highContrast': media.highContrast,
    'disableAnimations': media.disableAnimations,
    'direction': Directionality.of(context).name,
    'locale': Localizations.localeOf(context).toLanguageTag(),
    'bodyFont': {
      'family': body.fontFamily,
      'fallback': body.fontFamilyFallback,
      'size': body.fontSize,
      'height': body.height,
    },
    'desktopEnvironment': {
      for (final name in [
        'GDK_BACKEND',
        'GDK_SCALE',
        'GDK_DPI_SCALE',
        'GTK_THEME',
        'LANG',
        'LANGUAGE',
        'LC_ALL',
      ])
        name: Platform.environment[name],
    },
  };
}
