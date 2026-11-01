// Private release acceptance entrypoint. Uses the unchanged native application;
// it never overrides MediaQuery, theme, locale, providers or platform settings.
import 'dart:convert';
import 'dart:io';
import 'package:busydata/main_linux.dart' as application;
import 'package:busydata/src/platform/gtk_animation_settings_service.dart';
import 'package:busydata/src/platform/gtk_font_service.dart';
import 'package:busydata/src/platform/linux/linux_accessibility_binding.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:yaru/theme.dart';

Element? _workbench() {
  Element? found;
  void visit(Element element) {
    if (element.widget is WorkbenchView) found = element;
    if (found == null) element.visitChildElements(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return found;
}

Future<void> main() async {
  LinuxAccessibilityBinding.ensureInitialized();
  final input = File(Platform.environment['BUSYDATA_NATIVE_SETTINGS_INPUT']!);
  final output = File(Platform.environment['BUSYDATA_NATIVE_SETTINGS_OUTPUT']!);
  if (await input.length() > 4096) {
    throw StateError('Private settings input bound');
  }
  final expected =
      jsonDecode(await input.readAsString()) as Map<String, dynamic>;
  await application.startLinux();
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  Map<String, Object?> receipt = {};
  while (DateTime.now().isBefore(deadline)) {
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    final element = _workbench();
    if (element == null) continue;
    final media = MediaQuery.of(element);
    final theme = Theme.of(element);
    final nativeFont = await const GtkFontService().getGtkFont();
    final animations = await const GtkAnimationSettingsService()
        .getAnimationsEnabled();
    final box = element.findRenderObject();
    receipt = {
      'version': 1,
      'entrypoint': 'integration_test/platform_settings_linux.dart',
      'releaseMode': kReleaseMode,
      'platformBrightness': media.platformBrightness.name,
      'composedThemeBrightness': theme.brightness.name,
      'textScale': media.textScaler.scale(16) / 16,
      'devicePixelRatio': media.devicePixelRatio,
      'highContrast': media.highContrast,
      'yaruHighContrast': theme.colorScheme.isHighContrast,
      'disableAnimations': media.disableAnimations,
      'nativeGtkAnimationsEnabled': animations,
      'direction': Directionality.of(element).name,
      'resolvedLocale': Localizations.localeOf(element).toLanguageTag(),
      'platformLocales': WidgetsBinding.instance.platformDispatcher.locales
          .map((locale) => locale.toLanguageTag())
          .toList(),
      'nativeGtkFont': {'family': nativeFont?.family, 'size': nativeFont?.size},
      'composedFontFamily': theme.textTheme.bodyMedium?.fontFamily,
      'composedFontSize': theme.textTheme.bodyMedium?.fontSize,
      'renderedFontSize': media.textScaler.scale(
        theme.textTheme.bodyMedium?.fontSize ?? 0,
      ),
      'primaryArgb': theme.colorScheme.primary.toARGB32(),
      'surfaceArgb': theme.colorScheme.surface.toARGB32(),
      'onSurfaceArgb': theme.colorScheme.onSurface.toARGB32(),
      'workspaceRenderBox': box is RenderBox && box.hasSize
          ? {'width': box.size.width, 'height': box.size.height}
          : null,
    };
    final passed =
        kReleaseMode &&
        receipt['platformBrightness'] == expected['brightness'] &&
        receipt['composedThemeBrightness'] == expected['brightness'] &&
        receipt['textScale'] == expected['textScale'] &&
        (expected['devicePixelRatio'] == null ||
            receipt['devicePixelRatio'] == expected['devicePixelRatio']) &&
        receipt['highContrast'] == expected['highContrast'] &&
        receipt['yaruHighContrast'] == expected['highContrast'] &&
        receipt['disableAnimations'] == !expected['animations'] &&
        animations == expected['animations'] &&
        receipt['direction'] == expected['direction'] &&
        (receipt['resolvedLocale'] as String).startsWith(
          expected['language'] as String,
        ) &&
        nativeFont != null &&
        receipt['workspaceRenderBox'] != null;
    if (passed) {
      receipt['passed'] = true;
      await output.writeAsString('${jsonEncode(receipt)}\n', flush: true);
      // The external controller now exercises the actual native controls.
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  receipt['passed'] = false;
  await output.writeAsString('${jsonEncode(receipt)}\n', flush: true);
  exit(1);
}
