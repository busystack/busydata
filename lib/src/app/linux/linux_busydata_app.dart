import '../../ui/linux/linux_appearance.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';
import 'package:ubuntu_localizations/ubuntu_localizations.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/locale_resolution.dart';
import '../../platform/gtk_font_service.dart';
import '../../platform/gtk_header_icon_service.dart';
import '../../platform/gtk_animation_settings_service.dart';
import '../../platform/native_style.dart';
import '../../ui/common/workbench_view.dart';
import '../../ui/common/workbench_shortcut_scope.dart';
import '../../ui/common/workbench_close.dart';
import '../../ui/linux/linux_controls.dart';
import '../busydata_design.dart';
import '../busydata_window_close.dart';
import '../busydata_yaru_theme.dart';
import 'linux_window_host.dart';

class LinuxBusyDataApp extends ConsumerStatefulWidget {
  const LinuxBusyDataApp({super.key});
  @override
  ConsumerState<LinuxBusyDataApp> createState() => _LinuxBusyDataAppState();
}

class _LinuxBusyDataAppState extends ConsumerState<LinuxBusyDataApp> {
  final close = BusyDataWindowCloseCoordinator();
  @override
  Widget build(BuildContext context) {
    final model = ref.watch(workbenchProvider);
    final colors =
        ref.watch(gtkThemeColorsProvider).value ??
        ref.watch(initialGtkThemeColorsProvider);
    final animations = ref.watch(gtkAnimationsEnabledProvider).value ?? true;
    ThemeData theme(Brightness brightness, {bool contrast = false}) =>
        BusyDataYaruTheme.build(
          brightness: brightness,
          accentColor: contrast
              ? (brightness == Brightness.dark ? Colors.white : Colors.black)
              : colors?.accent ?? SystemTheme.accentColor.accent,
          gtkThemeColors: colors,
          highContrast: contrast,
        );
    return ValueListenableBuilder<(String, String?)>(
      valueListenable: model.appearancePreference,
      builder: (context, preference, _) => MaterialApp(
        themeMode: switch (preference.$1) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        locale: busyDataLocaleFromTag(preference.$2),
        title: 'BusyData',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        highContrastTheme: theme(Brightness.light, contrast: true),
        highContrastDarkTheme: theme(Brightness.dark, contrast: true),
        localizationsDelegates: const [
          ...AppLocalizations.localizationsDelegates,
          ...GlobalUbuntuLocalizations.delegates,
        ],
        localeListResolutionCallback: resolveBusyDataLocales,
        supportedLocales: busyDataSupportedLocales,
        builder: (context, child) {
          final colors = BusyDataSurfaceColors.of(context);
          unawaited(
            const NativeSurfaceStyleService().setTheme(
              BusyDataNativeSurfaceTheme(
                highContrast: MediaQuery.highContrastOf(context),
                windowBackgroundColor: colors.window,
                dialogBackgroundColor: colors.dialog,
                dialogOutlineColor: colors.dialogOutline,
                tooltipBackgroundColor: BusyDataTooltipStyle.background,
                tooltipForegroundColor: BusyDataTooltipStyle.foreground,
                tooltipBorderColor: BusyDataTooltipStyle.border,
                tooltipRadius: BusyDataRadius.tooltip,
                tooltipFontSize:
                    Theme.of(context).tooltipTheme.textStyle?.fontSize ?? 14,
                tooltipHorizontalPadding: BusyDataSpacing.tooltipHorizontal,
                tooltipVerticalPadding: BusyDataSpacing.tooltipVertical,
                tooltipMinimumHeight: BusyDataSizes.tooltipMinHeight,
              ),
            ),
          );
          return GtkHeaderIconScope(
            service: ref.watch(gtkHeaderIconServiceProvider),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations:
                    !animations || MediaQuery.disableAnimationsOf(context),
              ),
              child: LinuxAppearanceScope(
                child: LinuxWindowHost(closeCoordinator: close, child: child!),
              ),
            ),
          );
        },
        home: Builder(
          builder: (context) => BusyDataWindowCloseGuard(
            onCloseRequested: () =>
                requestWorkbenchClose(context, model, const LinuxControls()),
            child: WorkbenchShortcutScope(
              model: model,
              child: WorkbenchView(
                model: model,
                controls: const LinuxControls(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
