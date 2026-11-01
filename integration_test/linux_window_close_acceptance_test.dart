import 'dart:async';

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/busydata_dialogs.dart';
import 'package:busydata/src/app/busydata_window_close.dart';
import 'package:busydata/src/app/linux/linux_window_host.dart';
import 'package:busydata/src/platform/gtk_window_preferences_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yaru/yaru.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(YaruWindowTitleBar.ensureInitialized);

  testWidgets('native Linux close request can be cancelled by an editor', (
    tester,
  ) async {
    final coordinator = BusyDataWindowCloseCoordinator();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gtkWindowPreferencesProvider.overrideWith(
            (ref) => Stream.value(_closePreferences),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => LinuxWindowHost(
            closeCoordinator: coordinator,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const _CloseProbe(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final closeControl = find.byWidgetPredicate(
      (widget) =>
          widget is YaruWindowControl &&
          widget.type == YaruWindowControlType.close,
    );
    expect(closeControl, findsOneWidget);

    await tester.tap(closeControl);
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Close requests: 1'), findsOneWidget);

    final cancelButton = find.descendant(
      of: find.byType(BusyDataConfirmDialog),
      matching: find.byType(FilledButton),
    );
    expect(cancelButton, findsOneWidget);
    await tester.tap(cancelButton);
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsNothing);
    expect(find.text('Editor remains mounted'), findsOneWidget);
  });
}

const _closePreferences = GtkWindowPreferences(
  decorationLayout: GtkDecorationLayout(
    left: [],
    right: [GtkWindowDecorationElement.close],
  ),
  doubleClick: GtkTitlebarAction.toggleMaximize,
  middleClick: GtkTitlebarAction.none,
  rightClick: GtkTitlebarAction.menu,
);

class _CloseProbe extends StatefulWidget {
  const _CloseProbe();

  @override
  State<_CloseProbe> createState() => _CloseProbeState();
}

class _CloseProbeState extends State<_CloseProbe> {
  var _closeRequests = 0;

  Future<bool> _confirmClose() async {
    setState(() => _closeRequests += 1);
    return showBusyDataConfirm(
      context,
      title: 'Discard changes?',
      message: 'The editor contains an unsaved draft.',
      confirmLabel: 'Discard',
      destructive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BusyDataWindowCloseGuard(
      onCloseRequested: _confirmClose,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Editor remains mounted'),
              Text('Close requests: $_closeRequests'),
            ],
          ),
        ),
      ),
    );
  }
}
