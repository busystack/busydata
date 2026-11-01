import 'dart:io';

import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/platform/gtk_font_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter owns modal shading and native header barriers are absent', () {
    final runner = File('linux/runner/my_application.cc').readAsStringSync();
    final dialogs = File(
      'lib/src/app/busydata_dialogs.dart',
    ).readAsStringSync();
    final workspace = File(
      'lib/src/app/linux/linux_busydata_app.dart',
    ).readAsStringSync();

    expect(runner, isNot(contains('set_header_bar_modal_barrier')));
    expect(runner, isNot(contains('titlebar_modal_barrier')));
    expect(dialogs, contains('initialBarrierColor'));
    expect(dialogs, contains('await route.completed'));
    expect(workspace, contains('WorkbenchView('));
    expect(
      File('lib/src/ui/linux/linux_workbench_frame.dart').readAsStringSync(),
      contains('LinuxPageFrame('),
    );
    expect(workspace, isNot(contains('ModalBarrier(')));
  });

  for (final (brightness, expectedAlpha) in [
    (Brightness.light, 0.07),
    (Brightness.dark, 0.25),
  ]) {
    testWidgets(
      '$brightness modal barrier follows the native semantic shade role',
      (tester) async {
        final theme = BusyDataYaruTheme.build(
          brightness: brightness,
          accentColor: const Color(0xFF3584E4),
        );
        late Color barrier;

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Builder(
              builder: (context) {
                barrier = busyDataModalBarrierColor(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );

        final shade = theme.extension<BusyDataSurfaceColors>()!.shade;
        expect(barrier.a, closeTo(expectedAlpha, 0.0001));
        expect(barrier.r, shade.r);
        expect(barrier.g, shade.g);
        expect(barrier.b, shade.b);
      },
    );
  }

  testWidgets('high-contrast shade remains a translucent modal layer', (
    tester,
  ) async {
    final theme = BusyDataYaruTheme.build(
      brightness: Brightness.light,
      accentColor: const Color(0xFF3584E4),
      highContrast: true,
    );
    late Color barrier;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) {
            barrier = busyDataModalBarrierColor(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(barrier, theme.extension<BusyDataSurfaceColors>()!.shade);
    expect(barrier.a, 0.50);
    expect(barrier.a, lessThan(1));
  });

  testWidgets(
    'a GTK3 palette without semantic shade keeps restrained light dimming',
    (tester) async {
      const gtkColors = GtkThemeColors(
        brightness: Brightness.light,
        window: Color(0xFFFAFAFA),
        popover: Color(0xFFFAFAFA),
      );
      final theme = BusyDataYaruTheme.build(
        brightness: Brightness.light,
        accentColor: const Color(0xFF3584E4),
        gtkThemeColors: gtkColors,
      );
      late Color barrier;

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              barrier = busyDataModalBarrierColor(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        theme.extension<BusyDataSurfaceColors>()!.shade,
        busyDataFallbackSurfaceColors(Brightness.light).shade,
      );
      expect(barrier.a, closeTo(0.07, 0.0001));
    },
  );
}
