import 'dart:io';
import 'package:posix/posix.dart' show chmod;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:system_theme/system_theme.dart';
import 'package:yaru/yaru.dart';
import 'src/app/linux/linux_busydata_app.dart';
import 'src/platform/linux/portal_database_secrets.dart';
import 'src/platform/linux/linux_accessibility_bridge.dart';
import 'src/platform/linux/linux_accessibility_binding.dart';
import 'src/platform/common/database_secrets.dart';
import 'src/features/workspace/workbench_model.dart';
import 'src/platform/gtk_font_service.dart';
import 'src/platform/gtk_header_icon_service.dart';
import 'src/platform/gtk_animation_settings_service.dart';
import 'src/platform/gtk_window_preferences_service.dart';

Future<void> main() async {
  await startLinux();
}

/// The native launcher and desktop acceptance entrypoints use the same startup.
Future<WorkbenchModel> startLinux({Directory? supportDirectory}) async {
  final binding = LinuxAccessibilityBinding.ensureInitialized();
  binding.deferFirstFrame();
  await YaruWindowTitleBar.ensureInitialized();
  final support =
      supportDirectory ??
      Directory(
        p.join((await getApplicationSupportDirectory()).path, 'busydata'),
      );
  await support.create(recursive: true);
  final model = WorkbenchModel(
    support,
    restrictLocalPath: (path, directory) =>
        chmod(path, directory ? '700' : '600'),
    secrets: Platform.environment.containsKey('SNAP')
        ? PortalDatabaseSecrets(
            File(p.join(support.path, 'database-secrets.v1.json')),
          )
        : const OsDatabaseSecrets(),
  );
  final icons = GtkHeaderIconService();
  final values = await Future.wait<Object?>([
    const GtkFontService().getGtkFont(),
    const GtkThemeService().getGtkThemeColors(),
    const GtkAnimationSettingsService().getAnimationsEnabled(),
    const GtkWindowPreferencesService().load(),
    SystemTheme.accentColor.load(),
    icons.initialize(),
  ]);
  await model.initialize();
  runApp(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        workbenchProvider.overrideWithValue(model),
        initialGtkFontSettingsProvider.overrideWithValue(
          values[0] as GtkFontSettings?,
        ),
        initialGtkThemeColorsProvider.overrideWithValue(
          values[1] as GtkThemeColors?,
        ),
        initialGtkAnimationsEnabledProvider.overrideWithValue(
          values[2] as bool?,
        ),
        initialGtkWindowPreferencesProvider.overrideWithValue(
          values[3] as GtkWindowPreferences?,
        ),
        gtkHeaderIconServiceProvider.overrideWithValue(icons),
      ],
      child: const LinuxAccessibilityBridgeScope(child: LinuxBusyDataApp()),
    ),
  );
  binding.allowFirstFrame();
  return model;
}
