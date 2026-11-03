import 'dart:async';
import 'dart:ui' show AppExitResponse;
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/locale_resolution.dart';
import '../../platform/windows/windows_system_appearance_source.dart';
import '../../ui/common/workbench_view.dart';
import '../../ui/common/workbench_shortcut_scope.dart';
import '../../ui/common/database_explorer.dart';
import '../../ui/common/workbench_close.dart';
import '../../ui/windows/windows_controls.dart';
import '../busydata_window_close.dart';
import '../../../l10n/generated/app_localizations.dart';

class WindowsBusyDataApp extends ConsumerStatefulWidget {
  const WindowsBusyDataApp({super.key});
  @override
  ConsumerState<WindowsBusyDataApp> createState() => _WindowsBusyDataAppState();
}

class _WindowsBusyDataAppState extends ConsumerState<WindowsBusyDataApp>
    with WidgetsBindingObserver {
  final appearance = WindowsSystemAppearanceSource();
  final close = BusyDataWindowCloseCoordinator();
  static const desktop = MethodChannel(
    'org.busystack.busydata/windows_desktop',
  );
  StreamSubscription<void>? changes;
  late final AppLifecycleListener lifecycle;
  late final GoRouter router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => WindowsWorkspaceShell(
          model: ref.read(workbenchProvider),
          close: close,
        ),
      ),
    ],
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    desktop.setMethodCallHandler((call) async {
      if (call.method == 'requestClose' && await close.requestClose()) {
        await desktop.invokeMethod<void>('quit');
      }
    });
    changes = appearance.changes.listen((_) {
      if (mounted) setState(() {});
    });
    lifecycle = AppLifecycleListener(
      onExitRequested: () async => await close.requestClose()
          ? AppExitResponse.exit
          : AppExitResponse.cancel,
    );
  }

  @override
  void didChangePlatformBrightness() => setState(() {});
  @override
  void didChangeAccessibilityFeatures() => setState(() {});
  @override
  void dispose() {
    lifecycle.dispose();
    desktop.setMethodCallHandler(null);
    router.dispose();
    unawaited(changes?.cancel());
    unawaited(appearance.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = ref.watch(workbenchProvider);
    final highContrast = appearance.highContrast;
    final reduced = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    FluentThemeData theme(Brightness brightness) {
      final defaults = Typography.fromBrightness(brightness: brightness);
      TextStyle? font(TextStyle? style) => style?.copyWith(
        fontFamily: 'Segoe UI Variable',
        fontFamilyFallback: const ['Segoe UI'],
      );
      final background = brightness == Brightness.dark
          ? Colors.black
          : Colors.white;
      final foreground = brightness == Brightness.dark
          ? Colors.white
          : Colors.black;
      return FluentThemeData(
        brightness: brightness,
        accentColor: highContrast
            ? foreground.toAccentColor()
            : appearance.accentColor.toAccentColor(),
        activeColor: highContrast ? background : null,
        inactiveColor: highContrast ? foreground : null,
        scaffoldBackgroundColor: highContrast ? background : null,
        cardColor: highContrast ? background : null,
        menuColor: highContrast ? background : null,
        shadowColor: highContrast ? foreground : null,
        typography: Typography.raw(
          display: font(defaults.display),
          titleLarge: font(defaults.titleLarge),
          title: font(defaults.title),
          subtitle: font(defaults.subtitle),
          bodyLarge: font(defaults.bodyLarge),
          bodyStrong: font(defaults.bodyStrong),
          body: font(defaults.body),
          caption: font(defaults.caption),
        ),
        fasterAnimationDuration: reduced ? Duration.zero : null,
        fastAnimationDuration: reduced ? Duration.zero : null,
        mediumAnimationDuration: reduced ? Duration.zero : null,
        slowAnimationDuration: reduced ? Duration.zero : null,
      );
    }

    return ValueListenableBuilder<(String, String?)>(
      valueListenable: model.appearancePreference,
      builder: (context, preference, _) => FluentApp.router(
        themeMode: switch (preference.$1) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        },
        locale: busyDataLocaleFromTag(preference.$2),
        title: 'BusyData',
        debugShowCheckedModeBanner: false,
        routerConfig: router,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        localizationsDelegates: const [AppLocalizations.delegate],
        localeListResolutionCallback: resolveBusyDataLocales,
        supportedLocales: busyDataSupportedLocales,
      ),
    );
  }
}

class WindowsWorkspaceShell extends StatelessWidget {
  const WindowsWorkspaceShell({
    super.key,
    required this.model,
    required this.close,
  });
  final WorkbenchModel model;
  final BusyDataWindowCloseCoordinator close;
  @override
  Widget build(BuildContext context) => BusyDataWindowCloseScope(
    coordinator: close,
    child: BusyDataWindowCloseGuard(
      onCloseRequested: () =>
          requestWorkbenchClose(context, model, const WindowsControls()),
      child: WorkbenchShortcutScope(
        model: model,
        child: NavigationView(
          content: ListenableBuilder(
            listenable: model,
            builder: (context, _) => Row(
              children: [
                Offstage(
                  offstage: !model.explorerVisible,
                  child: ExcludeFocus(
                    excluding: !model.explorerVisible,
                    child: SizedBox(
                      width: model.explorerWidth,
                      child: Semantics(
                        container: true,
                        explicitChildNodes: true,
                        identifier: 'busydata.windows.explorer',
                        child: DatabaseExplorer(
                          model: model,
                          controls: const WindowsControls(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (model.explorerVisible)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onHorizontalDragUpdate: (details) => model.resizeExplorer(
                        model.explorerWidth +
                            details.delta.dx *
                                (Directionality.of(context) == TextDirection.ltr
                                    ? 1
                                    : -1),
                      ),
                      child: const SizedBox(width: 4, height: double.infinity),
                    ),
                  ),
                Expanded(
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    identifier: 'busydata.windows.workbench',
                    child: WorkbenchView(
                      model: model,
                      controls: const WindowsControls(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
