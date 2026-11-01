// Private visual acceptance entrypoint: the actual Fluent workbench on Linux.
// This is rendering evidence only; Win32 behavior requires Windows acceptance.
import 'dart:convert';
import 'dart:io';
import 'package:busydata/main_linux.dart' as application;
import 'package:busydata/src/app/windows/windows_busydata_app.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/linux/linux_accessibility_bridge.dart';
import 'package:busydata/src/platform/linux/linux_accessibility_binding.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  LinuxAccessibilityBinding.ensureInitialized();
  final model = await application.startLinux();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [workbenchProvider.overrideWithValue(model)],
      child: const LinuxAccessibilityBridgeScope(child: WindowsBusyDataApp()),
    ),
  );
  final output = File(
    Platform.environment['BUSYDATA_NATIVE_COMPOSITION_OUTPUT']!,
  );
  final deadline = DateTime.now().add(const Duration(seconds: 25));
  while (DateTime.now().isBefore(deadline)) {
    WidgetsBinding.instance.scheduleFrame();
    await WidgetsBinding.instance.endOfFrame;
    Element? workbench;
    bool shell = false;
    void visit(Element element) {
      if (element.widget is WindowsWorkspaceShell) shell = true;
      if (element.widget is WorkbenchView) workbench = element;
      element.visitChildElements(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildElements(visit);
    if (!shell || workbench == null) continue;
    final element = workbench!;
    final box = element.findRenderObject();
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) continue;
    final media = MediaQuery.of(element);
    final theme = fluent.FluentTheme.of(element);
    await output.writeAsString(
      '${jsonEncode({
        'version': 1,
        'entrypoint': 'integration_test/fluent_composition_linux.dart',
        'composition': 'Linux-host Fluent',
        'hostPlatform': Platform.operatingSystem,
        'releaseMode': kReleaseMode,
        'actualWindowsWorkspaceShell': shell,
        'actualFluentTheme': true,
        'actualPinnedBackend': model.backend != null,
        'textScale': media.textScaler.scale(16) / 16,
        'direction': Directionality.of(element).name,
        'resolvedLocale': Localizations.localeOf(element).toLanguageTag(),
        'themeBrightness': theme.brightness.name,
        'workspaceRenderBox': {'width': box.size.width, 'height': box.size.height},
        'windowsNativeAcceptance': false,
      })}\n',
      flush: true,
    );
    return;
  }
  throw StateError(
    'Actual Fluent workbench composition did not become visible',
  );
}
