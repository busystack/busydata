import 'dart:async';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/app/linux/linux_application_media_query.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/busydata_dialogs.dart';
import 'package:busydata/src/app/linux/linux_window_host.dart';
import 'package:busydata/src/platform/gtk_header_icon_service.dart';
import 'package:busydata/src/app/linux/linux_header_style.dart';
import 'package:busydata/src/app/busydata_window_close.dart';
import 'package:busydata/src/platform/gtk_window_preferences_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';

class _LinuxWindowTestBinding extends AutomatedTestWidgetsFlutterBinding {
  final exitRequests = <(AppExitType, int)>[];
  AppExitResponse exitResponse = AppExitResponse.exit;
  Object? exitFailure;

  @override
  Future<AppExitResponse> exitApplication(
    AppExitType exitType, [
    int exitCode = 0,
  ]) async {
    // Observe the public application boundary. The pinned test binding
    // deliberately rejects required exits before reaching the platform channel.
    exitRequests.add((exitType, exitCode));
    if (exitFailure case final failure?) {
      throw failure;
    }
    return exitResponse;
  }
}

void main() {
  final binding = _LinuxWindowTestBinding();

  const yaruWindowChannel = MethodChannel('yaru_window');
  const yaruEventsChannel = EventChannel('yaru_window/events');
  const gtkSettingsChannel = MethodChannel(
    'io.busystack.busydata/gtk_settings',
  );
  late List<MethodCall> windowCalls;
  late List<MethodCall> gtkCalls;
  late Map<String, Object?> nativeState;
  late MockStreamHandlerEventSink eventSink;
  late int eventListenCount;
  late int eventCancelCount;

  setUp(() {
    windowCalls = [];
    binding.exitRequests.clear();
    binding.exitResponse = AppExitResponse.exit;
    binding.exitFailure = null;
    gtkCalls = [];
    nativeState = <String, Object?>{};
    eventListenCount = 0;
    eventCancelCount = 0;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(yaruWindowChannel, (call) async {
      windowCalls.add(call);
      return call.method == 'state' ? nativeState : null;
    });
    messenger.setMockMethodCallHandler(gtkSettingsChannel, (call) async {
      gtkCalls.add(call);
      return null;
    });
    messenger.setMockStreamHandler(
      yaruEventsChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          eventListenCount += 1;
          eventSink = sink;
        },
        onCancel: (_) {
          eventCancelCount += 1;
        },
      ),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(yaruWindowChannel, null);
    messenger.setMockMethodCallHandler(gtkSettingsChannel, null);
    messenger.setMockStreamHandler(yaruEventsChannel, null);
  });

  testWidgets('effective appearance synchronizes GTK without redundant calls', (
    tester,
  ) async {
    final harnessKey = GlobalKey<_HostHarnessState>();
    await _pumpHost(tester, harnessKey: harnessKey);
    List<Object?> preferences() => gtkCalls
        .where((call) => call.method == 'setGtkThemePreference')
        .map((call) => call.arguments)
        .toList();

    expect(preferences(), [false]);
    final host = tester.state(find.byType(LinuxWindowHost));
    harnessKey.currentState!
      ..rebuildParent()
      ..toggleLocale();
    await tester.pumpAndSettle();
    expect(preferences(), [false]);

    harnessKey.currentState!.toggleTheme();
    await tester.pumpAndSettle();
    expect(preferences(), [false, true]);
    harnessKey.currentState!.setDisableAnimations(true);
    await tester.pumpAndSettle();
    expect(preferences(), [false, true]);

    harnessKey.currentState!.toggleTheme();
    await tester.pumpAndSettle();
    expect(preferences(), [false, true, false]);
    expect(tester.state(find.byType(LinuxWindowHost)), same(host));
    expect(eventListenCount, 1);
    expect(eventCancelCount, 0);
    expect(_callCount(windowCalls, 'state'), 1);
  });

  testWidgets(
    'bootstrap decorations allocate the first frame before streaming',
    (tester) async {
      final updates = StreamController<GtkWindowPreferences>();
      addTearDown(updates.close);
      const initial = GtkWindowPreferences(
        decorationLayout: GtkDecorationLayout(
          left: [GtkWindowDecorationElement.close],
          right: [],
        ),
        doubleClick: GtkTitlebarAction.minimize,
        middleClick: GtkTitlebarAction.none,
        rightClick: GtkTitlebarAction.menu,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialGtkWindowPreferencesProvider.overrideWithValue(initial),
            gtkWindowPreferencesProvider.overrideWith((ref) => updates.stream),
          ],
          child: const _HostHarness(
            initialLocale: Locale('ar'),
            initialDisableAnimations: false,
            initialGtkAnimationsEnabled: true,
          ),
        ),
      );

      LinuxWindowMetricsScope metrics() => LinuxWindowMetricsScope.of(
        tester.element(find.byKey(const ValueKey('metrics-probe'))),
      );
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(LinuxWindowHost)),
        ).read(gtkWindowPreferencesProvider).isLoading,
        isTrue,
      );
      expect(
        metrics().leftControlInset,
        BusyDataLinuxWindowMetrics.clusterWidth(initial.decorationLayout.left),
      );
      expect(metrics().rightControlInset, 0);
      expect(metrics().preferences.doubleClick, GtkTitlebarAction.minimize);
      expect(find.byType(YaruWindowControl), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('linux-window-controls-left')),
          matching: find.byType(YaruWindowControl),
        ),
        findsOneWidget,
      );

      updates.add(_closePreferences);
      await tester.pump();
      expect(metrics().leftControlInset, 0);
      expect(
        metrics().rightControlInset,
        BusyDataLinuxWindowMetrics.clusterWidth(
          _closePreferences.decorationLayout.right,
        ),
      );
    },
  );

  testWidgets('icon uses its physical GTK side and contributes to the inset', (
    tester,
  ) async {
    const preferences = GtkWindowPreferences(
      decorationLayout: GtkDecorationLayout(
        left: [
          GtkWindowDecorationElement.windowIcon,
          GtkWindowDecorationElement.minimize,
        ],
        right: [GtkWindowDecorationElement.close],
      ),
      doubleClick: GtkTitlebarAction.toggleMaximize,
      middleClick: GtkTitlebarAction.none,
      rightClick: GtkTitlebarAction.menu,
    );

    await _pumpHost(
      tester,
      preferences: preferences,
      locale: const Locale('ar'),
    );

    final left = find.byKey(const ValueKey('linux-window-controls-left'));
    final right = find.byKey(const ValueKey('linux-window-controls-right'));
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(
      find.descendant(
        of: left,
        matching: find.byIcon(YaruIcons.drive_harddisk),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: right,
        matching: find.byIcon(YaruIcons.drive_harddisk),
      ),
      findsNothing,
    );
    expect(tester.getRect(left).left, 0);
    expect(tester.getRect(right).right, 800);

    final metrics = LinuxWindowMetricsScope.of(
      tester.element(find.byKey(const ValueKey('metrics-probe'))),
    );
    expect(
      metrics.leftControlInset,
      BusyDataLinuxWindowMetrics.clusterWidth(
        preferences.decorationLayout.left,
      ),
    );
    expect(
      metrics.rightControlInset,
      BusyDataLinuxWindowMetrics.clusterWidth(
        preferences.decorationLayout.right,
      ),
    );

    final leftControls = find.descendant(
      of: left,
      matching: find.byType(YaruWindowControl),
    );
    expect(leftControls, findsOneWidget);
    expect(
      tester.getCenter(find.byIcon(YaruIcons.drive_harddisk)).dx,
      lessThan(tester.getCenter(leftControls).dx),
    );
  });

  testWidgets(
    'fallback application menu is absent while titlebar menu still works',
    (tester) async {
      const preferences = GtkWindowPreferences(
        decorationLayout: GtkDecorationLayout(
          left: [GtkWindowDecorationElement.fallbackApplicationMenu],
          right: [GtkWindowDecorationElement.close],
        ),
        doubleClick: GtkTitlebarAction.toggleMaximize,
        middleClick: GtkTitlebarAction.none,
        rightClick: GtkTitlebarAction.menu,
      );
      await _pumpHost(
        tester,
        preferences: preferences,
        child: const LinuxTitlebarGestureRegion(
          child: SizedBox(
            key: ValueKey('titlebar-drag-region'),
            width: 180,
            height: 46,
          ),
        ),
      );

      expect(find.byIcon(Icons.menu), findsNothing);
      expect(windowCalls.where((call) => call.method == 'showMenu'), isEmpty);
      final metrics = LinuxWindowMetricsScope.of(
        tester.element(find.byKey(const ValueKey('metrics-probe'))),
      );
      expect(metrics.leftControlInset, 0);

      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('titlebar-drag-region'))),
        buttons: kSecondaryMouseButton,
      );
      await tester.pump();

      expect(
        windowCalls.where((call) => call.method == 'showMenu'),
        hasLength(1),
      );
    },
  );

  testWidgets('window-state stream survives unrelated host rebuilds', (
    tester,
  ) async {
    final preferences = StreamController<GtkWindowPreferences>();
    addTearDown(preferences.close);
    final harnessKey = GlobalKey<_HostHarnessState>();

    await _pumpHost(
      tester,
      preferencesStream: preferences.stream,
      harnessKey: harnessKey,
    );
    final initialStateCalls = _callCount(windowCalls, 'state');
    expect(initialStateCalls, 1);
    expect(eventListenCount, 1);

    preferences.add(
      const GtkWindowPreferences(
        decorationLayout: GtkDecorationLayout(
          left: [GtkWindowDecorationElement.windowIcon],
          right: [GtkWindowDecorationElement.maximize],
        ),
        doubleClick: GtkTitlebarAction.minimize,
        middleClick: GtkTitlebarAction.none,
        rightClick: GtkTitlebarAction.menu,
      ),
    );
    await tester.pump();
    await tester.pump();
    harnessKey.currentState!
      ..rebuildParent()
      ..toggleTheme()
      ..toggleLocale();
    await tester.pump();

    expect(_callCount(windowCalls, 'state'), initialStateCalls);
    expect(eventListenCount, 1);
    expect(eventCancelCount, 0);

    await _sendState(tester, eventSink, <String, Object?>{
      'active': true,
      'maximized': true,
      'restorable': true,
    });

    final control = tester.widget<YaruWindowControl>(
      find.byType(YaruWindowControl),
    );
    expect(control.type, YaruWindowControlType.restore);
    expect(_callCount(windowCalls, 'state'), initialStateCalls);
  });

  testWidgets(
    'owned Close reviews once before required exit; OS exit stays guarded',
    (tester) async {
      var allowClose = false;
      var closeRequests = 0;
      await _pumpHost(
        tester,
        child: BusyDataWindowCloseGuard(
          onCloseRequested: () {
            closeRequests += 1;
            return allowClose;
          },
          child: const SizedBox(),
        ),
      );

      await tester.tap(find.byType(YaruWindowControl));
      await tester.pump();

      expect(_callCount(windowCalls, 'close'), 0);
      expect(closeRequests, 1);
      expect(binding.exitRequests, isEmpty);
      expect(
        await tester.binding.handleRequestAppExit(),
        AppExitResponse.cancel,
      );
      expect(closeRequests, 2);

      allowClose = true;
      await tester.tap(find.byType(YaruWindowControl));
      await tester.pump();
      expect(closeRequests, 3);
      expect(binding.exitRequests, [(AppExitType.required, 0)]);
      expect(_callCount(windowCalls, 'close'), 0);
      expect(await tester.binding.handleRequestAppExit(), AppExitResponse.exit);
      expect(closeRequests, 4);
      expect(binding.exitRequests, hasLength(1));
    },
  );

  testWidgets('concurrent owned Close requests share review and one exit', (
    tester,
  ) async {
    final approved = Completer<bool>();
    var reviews = 0;
    await _pumpHost(
      tester,
      child: BusyDataWindowCloseGuard(
        onCloseRequested: () {
          reviews += 1;
          return approved.future;
        },
        child: const SizedBox(),
      ),
    );
    await tester.tap(find.byType(YaruWindowControl));
    await tester.pump();
    await tester.tap(find.byType(YaruWindowControl));
    await tester.pump();
    expect(reviews, 1);
    expect(binding.exitRequests, isEmpty);
    approved.complete(true);
    await tester.pump();
    await tester.pump();
    expect(reviews, 1);
    expect(binding.exitRequests, [(AppExitType.required, 0)]);
    expect(_callCount(windowCalls, 'close'), 0);
  });

  testWidgets('disposed owned window rejects late close approval', (
    tester,
  ) async {
    final approved = Completer<bool>();
    var reviews = 0;
    await _pumpHost(
      tester,
      child: BusyDataWindowCloseGuard(
        onCloseRequested: () {
          reviews += 1;
          return approved.future;
        },
        child: const SizedBox(),
      ),
    );
    await tester.tap(find.byType(YaruWindowControl));
    await tester.pump();
    expect(reviews, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    approved.complete(true);
    await tester.pump();
    expect(binding.exitRequests, isEmpty);
    expect(_callCount(windowCalls, 'close'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rebound close coordinator rejects previous owner approval', (
    tester,
  ) async {
    final key = GlobalKey<_HostHarnessState>();
    final original = BusyDataWindowCloseCoordinator();
    final replacement = BusyDataWindowCloseCoordinator();
    final approved = Completer<bool>();
    var reviews = 0;
    await _pumpHost(
      tester,
      harnessKey: key,
      closeCoordinator: original,
      child: BusyDataWindowCloseGuard(
        onCloseRequested: () {
          reviews += 1;
          return approved.future;
        },
        child: const SizedBox(),
      ),
    );
    await tester.tap(find.byType(YaruWindowControl));
    await tester.pump();
    expect(reviews, 1);
    key.currentState!.setCloseCoordinator(replacement);
    await tester.pump();
    approved.complete(true);
    await tester.pump();
    expect(binding.exitRequests, isEmpty);
    expect(_callCount(windowCalls, 'close'), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed close review cannot dispatch either exit path', (
    tester,
  ) async {
    await _pumpHost(
      tester,
      child: BusyDataWindowCloseGuard(
        onCloseRequested: () => throw StateError('Owned review failed'),
        child: const SizedBox(),
      ),
    );
    await tester.tap(find.byType(YaruWindowControl));
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(binding.exitRequests, isEmpty);
    expect(_callCount(windowCalls, 'close'), 0);
  });

  testWidgets(
    'public exit transport failure reports once with no native fallback',
    (tester) async {
      var reviews = 0;
      binding.exitFailure = PlatformException(code: 'exit-denied');
      await _pumpHost(
        tester,
        child: BusyDataWindowCloseGuard(
          onCloseRequested: () {
            reviews += 1;
            return true;
          },
          child: const SizedBox(),
        ),
      );
      await tester.tap(find.byType(YaruWindowControl));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isA<PlatformException>());
      expect(reviews, 1);
      expect(binding.exitRequests, [(AppExitType.required, 0)]);
      expect(_callCount(windowCalls, 'close'), 0);
      await tester.pump(const Duration(seconds: 1));
      expect(binding.exitRequests, hasLength(1));
      expect(find.byType(LinuxWindowHost), findsOneWidget);
    },
  );

  testWidgets('root dialogs retain the host close coordinator', (tester) async {
    final coordinator = BusyDataWindowCloseCoordinator();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gtkWindowPreferencesProvider.overrideWith(
            (ref) => Stream.value(
              const GtkWindowPreferences(
                decorationLayout: GtkDecorationLayout(left: [], right: []),
                doubleClick: GtkTitlebarAction.toggleMaximize,
                middleClick: GtkTitlebarAction.none,
                rightClick: GtkTitlebarAction.menu,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => LinuxWindowHost(
            closeCoordinator: coordinator,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showBusyDataModalDialog<void>(
                  context,
                  builder: (_) =>
                      const AlertDialog(content: Text('Window modal')),
                ),
              ),
              child: const Text('Open modal'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Open modal'));
    await tester.pumpAndSettle();

    expect(find.text('Window modal'), findsOneWidget);
    expect(coordinator.hasActiveHandler, isTrue);
    expect(await coordinator.requestClose(), isFalse);
  });

  for (final scenario
      in <(String, Map<String, Object?>, YaruWindowControlType, String)>[
        (
          'normal',
          <String, Object?>{'maximizable': true},
          YaruWindowControlType.maximize,
          'maximize',
        ),
        (
          'maximized',
          <String, Object?>{'maximized': true, 'restorable': true},
          YaruWindowControlType.restore,
          'restore',
        ),
        (
          'fullscreen',
          <String, Object?>{'fullscreen': true, 'restorable': true},
          YaruWindowControlType.restore,
          'restore',
        ),
      ]) {
    testWidgets('${scenario.$1} maximize decoration has matching behavior', (
      tester,
    ) async {
      nativeState = scenario.$2;
      await _pumpHost(tester, preferences: _maximizePreferences);

      final controlFinder = find.byType(YaruWindowControl);
      final control = tester.widget<YaruWindowControl>(controlFinder);
      expect(control.type, scenario.$3);
      expect(
        find.bySemanticsLabel(
          scenario.$3 == YaruWindowControlType.restore ? 'Restore' : 'Maximize',
        ),
        findsWidgets,
      );

      await tester.tap(controlFinder);
      await tester.pump();

      expect(_callCount(windowCalls, scenario.$4), 1);
      if (scenario.$1 == 'fullscreen') {
        expect(_callCount(windowCalls, 'maximize'), 0);
      }
    });
  }

  testWidgets('fullscreen titlebar double-click still restores', (
    tester,
  ) async {
    nativeState = <String, Object?>{'fullscreen': true, 'restorable': true};
    await _pumpHost(
      tester,
      preferences: _maximizePreferences,
      child: const LinuxTitlebarGestureRegion(
        child: SizedBox(
          key: ValueKey('titlebar-double-click-region'),
          width: 180,
          height: 46,
        ),
      ),
    );

    final region = find.byKey(const ValueKey('titlebar-double-click-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump(const Duration(milliseconds: 50));

    expect(_callCount(windowCalls, 'restore'), 1);
    expect(_callCount(windowCalls, 'maximize'), 0);
  });

  testWidgets('enabled motion retains the normal active-window fade', (
    tester,
  ) async {
    nativeState = <String, Object?>{'active': true};
    await _pumpHost(tester, preferences: _closePreferences);
    expect(_controlAnimatedOpacity(tester).duration, BusyDataMotion.fast);

    await _sendState(tester, eventSink, <String, Object?>{'active': false});
    await tester.pump(_half(BusyDataMotion.fast));

    expect(_renderedControlOpacity(tester), inExclusiveRange(.5, 1));
    await tester.pumpAndSettle();
    expect(_renderedControlOpacity(tester), .5);
  });

  testWidgets(
    'actual header title receives configured gestures through its text',
    (tester) async {
      nativeState = <String, Object?>{'active': true, 'maximized': false};
      await _pumpHost(
        tester,
        preferences: GtkWindowPreferences.defaults(),
        child: const BusyDataLinuxHeaderTitle('Ordinary document title'),
      );
      final title = find.text('Ordinary document title');
      await tester.tap(title);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(_callCount(windowCalls, 'maximize'), 1);
      await tester.drag(title, const Offset(50, 20));
      await tester.pumpAndSettle();
      expect(_callCount(windowCalls, 'drag'), 1);
    },
  );

  testWidgets('Flutter reduced motion settles the host fade immediately', (
    tester,
  ) async {
    nativeState = <String, Object?>{'active': true};
    await _pumpHost(
      tester,
      preferences: _closePreferences,
      disableAnimations: true,
    );

    await _sendState(tester, eventSink, <String, Object?>{'active': false});

    expect(_controlAnimatedOpacityFinder(), findsNothing);
    expect(_renderedControlOpacity(tester), .5);
  });

  testWidgets('GTK animation policy reaches the actual host overlay', (
    tester,
  ) async {
    nativeState = <String, Object?>{'active': true};
    await _pumpHost(
      tester,
      preferences: _closePreferences,
      gtkAnimationsEnabled: false,
    );

    final hostContext = tester.element(find.byType(LinuxWindowHost));
    expect(MediaQuery.disableAnimationsOf(hostContext), isTrue);
    expect(MediaQuery.alwaysUse24HourFormatOf(hostContext), isTrue);
    expect(_controlAnimatedOpacityFinder(), findsNothing);
  });

  testWidgets('reduced motion interrupts maximize morph at its final icon', (
    tester,
  ) async {
    nativeState = <String, Object?>{'active': true, 'maximized': false};
    final harnessKey = GlobalKey<_HostHarnessState>();
    await _pumpHost(
      tester,
      preferences: GtkWindowPreferences.defaults(),
      harnessKey: harnessKey,
    );
    Finder maximize() => find.byWidgetPredicate(
      (widget) =>
          widget is YaruWindowControl &&
          (widget.type == YaruWindowControlType.maximize ||
              widget.type == YaruWindowControlType.restore),
    );
    final before = tester.state(maximize());
    await _sendState(tester, eventSink, <String, Object?>{
      'active': true,
      'maximized': true,
    });
    await tester.pump(const Duration(milliseconds: 20));
    harnessKey.currentState!.setDisableAnimations(true);
    await tester.pump();
    expect(
      tester.widget<YaruWindowControl>(maximize()).type,
      YaruWindowControlType.restore,
    );
    expect(
      tester.widget<YaruWindowControl>(maximize()).key,
      const ValueKey(YaruWindowControlType.restore),
    );
    expect(tester.state(maximize()), isNot(same(before)));
    final settled = tester.state(maximize());
    await tester.pump(const Duration(milliseconds: 20));
    expect(tester.state(maximize()), same(settled));
    await _sendState(tester, eventSink, <String, Object?>{
      'active': true,
      'maximized': false,
    });
    expect(
      tester.widget<YaruWindowControl>(maximize()).type,
      YaruWindowControlType.maximize,
    );
    expect(
      tester.widget<YaruWindowControl>(maximize()).backgroundColor!.resolve({
        WidgetState.hovered,
      }),
      Colors.transparent,
    );
  });

  testWidgets('enabling reduced motion stops a fade and later fades can run', (
    tester,
  ) async {
    nativeState = <String, Object?>{'active': true};
    final harnessKey = GlobalKey<_HostHarnessState>();
    await _pumpHost(
      tester,
      preferences: _closePreferences,
      harnessKey: harnessKey,
    );

    await _sendState(tester, eventSink, <String, Object?>{'active': false});
    await tester.pump(_half(BusyDataMotion.fast));
    expect(_renderedControlOpacity(tester), inExclusiveRange(.5, 1));

    harnessKey.currentState!.setDisableAnimations(true);
    await tester.pump();
    expect(_controlAnimatedOpacityFinder(), findsNothing);
    expect(_renderedControlOpacity(tester), .5);

    harnessKey.currentState!.setDisableAnimations(false);
    await tester.pump();
    expect(_controlAnimatedOpacity(tester).duration, BusyDataMotion.fast);
    expect(_renderedControlOpacity(tester), .5);

    await _sendState(tester, eventSink, <String, Object?>{'active': true});
    await tester.pump(_half(BusyDataMotion.fast));
    expect(_renderedControlOpacity(tester), inExclusiveRange(.5, 1));
    await tester.pumpAndSettle();
    expect(_renderedControlOpacity(tester), 1);
  });

  testWidgets('Yaru active state drives application chrome exactly once', (
    tester,
  ) async {
    nativeState = <String, Object?>{'active': true};
    await _pumpHost(
      tester,
      preferences: _closePreferences,
      child: const Column(
        children: [
          BusyDataLinuxHeaderTitle('Header title'),
          BusyDataLinuxHeaderTitle('BusyData brand', brand: true),
          BusyDataLinuxHeaderIconButton(
            key: ValueKey('active-header-button'),
            icon: BusyDataLinuxHeaderIcon.search,
            tooltip: 'Enabled',
            onPressed: _noop,
          ),
          BusyDataLinuxHeaderIconButton(
            key: ValueKey('disabled-header-button'),
            icon: BusyDataLinuxHeaderIcon.create,
            tooltip: 'Disabled',
            onPressed: null,
          ),
        ],
      ),
    );

    Color titleColor(String text) =>
        tester.widget<Text>(find.text(text)).style!.color!;
    Color iconColor(String key, Set<WidgetState> states) => tester
        .widget<IconButton>(
          find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(IconButton),
          ),
        )
        .style!
        .foregroundColor!
        .resolve(states)!;

    expect(titleColor('Header title').a, 1);
    expect(titleColor('BusyData brand').a, 1);
    expect(iconColor('active-header-button', const {}).a, 1);
    expect(
      iconColor('disabled-header-button', const {WidgetState.disabled}).a,
      .38,
    );
    expect(_renderedControlOpacity(tester), 1);

    await _sendState(tester, eventSink, <String, Object?>{'active': false});
    await tester.pumpAndSettle();

    final metrics = LinuxWindowMetricsScope.of(
      tester.element(find.byKey(const ValueKey('metrics-probe'))),
    );
    expect(metrics.windowActive, isFalse);
    expect(titleColor('Header title').a, .50);
    expect(titleColor('BusyData brand').a, .50);
    expect(iconColor('active-header-button', const {}).a, .50);
    expect(
      iconColor('disabled-header-button', const {WidgetState.disabled}).a,
      .19,
    );
    expect(_renderedControlOpacity(tester), .50);
  });
}

void _noop() {}

const _maximizePreferences = GtkWindowPreferences(
  decorationLayout: GtkDecorationLayout(
    left: [],
    right: [GtkWindowDecorationElement.maximize],
  ),
  doubleClick: GtkTitlebarAction.toggleMaximize,
  middleClick: GtkTitlebarAction.none,
  rightClick: GtkTitlebarAction.menu,
);

const _closePreferences = GtkWindowPreferences(
  decorationLayout: GtkDecorationLayout(
    left: [],
    right: [GtkWindowDecorationElement.close],
  ),
  doubleClick: GtkTitlebarAction.toggleMaximize,
  middleClick: GtkTitlebarAction.none,
  rightClick: GtkTitlebarAction.menu,
);

Future<void> _pumpHost(
  WidgetTester tester, {
  GtkWindowPreferences? preferences,
  Stream<GtkWindowPreferences>? preferencesStream,
  GlobalKey<_HostHarnessState>? harnessKey,
  Widget? child,
  Locale locale = const Locale('en'),
  bool disableAnimations = false,
  bool gtkAnimationsEnabled = true,
  BusyDataWindowCloseCoordinator? closeCoordinator,
}) async {
  final stream =
      preferencesStream ?? Stream.value(preferences ?? _closePreferences);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [gtkWindowPreferencesProvider.overrideWith((ref) => stream)],
      child: _HostHarness(
        key: harnessKey,
        initialLocale: locale,
        initialDisableAnimations: disableAnimations,
        initialGtkAnimationsEnabled: gtkAnimationsEnabled,
        initialCloseCoordinator: closeCoordinator,
        child: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void _emitState(MockStreamHandlerEventSink sink, Map<String, Object?> state) {
  sink.success(<String, Object?>{'id': 0, 'type': 'state', ...state});
}

Future<void> _sendState(
  WidgetTester tester,
  MockStreamHandlerEventSink sink,
  Map<String, Object?> state,
) async {
  _emitState(sink, state);
  await tester.runAsync(pumpEventQueue);
  await tester.pump();
}

int _callCount(List<MethodCall> calls, String method) =>
    calls.where((call) => call.method == method).length;

Duration _half(Duration duration) =>
    Duration(microseconds: duration.inMicroseconds ~/ 2);

Finder _controlAnimatedOpacityFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is AnimatedOpacity &&
      widget.key == const ValueKey('linux-window-controls-opacity'),
);

AnimatedOpacity _controlAnimatedOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnimatedOpacity &&
            widget.key == const ValueKey('linux-window-controls-opacity'),
      ),
    );

double _renderedControlOpacity(WidgetTester tester) {
  final opacity = find.byWidgetPredicate(
    (widget) =>
        widget is Opacity &&
        widget.key == const ValueKey('linux-window-controls-opacity'),
  );
  if (opacity.evaluate().isNotEmpty) {
    return tester.widget<Opacity>(opacity).opacity;
  }
  return tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byKey(const ValueKey('linux-window-controls-opacity')),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;
}

class _HostHarness extends StatefulWidget {
  const _HostHarness({
    super.key,
    required this.initialLocale,
    required this.initialDisableAnimations,
    required this.initialGtkAnimationsEnabled,
    this.child,
    this.initialCloseCoordinator,
  });

  final Locale initialLocale;
  final bool initialDisableAnimations;
  final bool initialGtkAnimationsEnabled;
  final Widget? child;
  final BusyDataWindowCloseCoordinator? initialCloseCoordinator;

  @override
  State<_HostHarness> createState() => _HostHarnessState();
}

class _HostHarnessState extends State<_HostHarness> {
  late Locale locale = widget.initialLocale;
  late bool disableAnimations = widget.initialDisableAnimations;
  late bool gtkAnimationsEnabled = widget.initialGtkAnimationsEnabled;
  late BusyDataWindowCloseCoordinator? closeCoordinator =
      widget.initialCloseCoordinator;
  var dark = false;
  var rebuilds = 0;

  void rebuildParent() => setState(() => rebuilds += 1);
  void toggleTheme() => setState(() => dark = !dark);
  void toggleLocale() => setState(() {
    locale = locale.languageCode == 'en'
        ? const Locale('ar')
        : const Locale('en');
  });
  void setDisableAnimations(bool value) =>
      setState(() => disableAnimations = value);
  void setCloseCoordinator(BusyDataWindowCloseCoordinator value) =>
      setState(() => closeCoordinator = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: LinuxApplicationMediaQuery(
            alwaysUse24HourFormat: true,
            gtkAnimationsEnabled: gtkAnimationsEnabled,
            child: LinuxWindowHost(
              closeCoordinator: closeCoordinator,
              child: Scaffold(
                body: Stack(
                  children: [
                    Center(child: Text('$rebuilds')),
                    const SizedBox(
                      key: ValueKey('metrics-probe'),
                      width: 1,
                      height: 1,
                    ),
                    ?widget.child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
