import 'dart:io';

import 'package:busydata/src/app/linux/linux_header_style.dart';
import 'package:busydata/src/platform/gtk_header_icon_service.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linux resolves the live GTK header-icon catalog', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    final service = GtkHeaderIconService();
    addTearDown(service.dispose);

    expect(await service.initialize(), isTrue);
    final catalog = service.catalog;
    expect(catalog.scale, greaterThanOrEqualTo(1));
    for (final icon in const [
      BusyDataLinuxHeaderIcon.back,
      BusyDataLinuxHeaderIcon.previous,
      BusyDataLinuxHeaderIcon.next,
      BusyDataLinuxHeaderIcon.search,
      BusyDataLinuxHeaderIcon.searchEntryFind,
      BusyDataLinuxHeaderIcon.searchClear,
      BusyDataLinuxHeaderIcon.mainMenu,
      BusyDataLinuxHeaderIcon.create,
      BusyDataLinuxHeaderIcon.refresh,
      BusyDataLinuxHeaderIcon.viewMenuArrow,
      BusyDataLinuxHeaderIcon.close,
    ]) {
      final asset = catalog.assetFor(icon, TextDirection.ltr);
      expect(asset, isNotNull, reason: 'GTK did not resolve ${icon.gtkNames}');
      expect(asset!.bytes, isNotEmpty);
      expect(asset.pixelWidth, greaterThan(0));
      expect(asset.pixelHeight, greaterThan(0));
      expect(asset.scale, catalog.scale);
    }
    for (final role in const {
      BusyDataLinuxHeaderIcon.search: 'system-search-symbolic',
      BusyDataLinuxHeaderIcon.searchEntryFind: 'edit-find-symbolic',
      BusyDataLinuxHeaderIcon.searchClear: 'edit-clear-symbolic',
    }.entries) {
      expect(
        catalog.assetFor(role.key, TextDirection.ltr)!.resolvedName,
        role.value,
      );
    }
    debugPrint(
      'GTK header icon catalog: '
      '${{
        for (final icon in const [BusyDataLinuxHeaderIcon.search, BusyDataLinuxHeaderIcon.searchEntryFind, BusyDataLinuxHeaderIcon.searchClear, BusyDataLinuxHeaderIcon.filter]) icon.name: catalog.assetFor(icon, TextDirection.ltr)?.resolvedName ?? 'missing-optional',
      }}',
    );

    await tester.pumpWidget(
      GtkHeaderIconScope(
        service: service,
        child: const MaterialApp(
          home: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BusyDataGtkHeaderIcon(BusyDataLinuxHeaderIcon.search),
                BusyDataGtkHeaderIcon(BusyDataLinuxHeaderIcon.searchEntryFind),
                BusyDataGtkHeaderIcon(BusyDataLinuxHeaderIcon.searchClear),
              ],
            ),
          ),
        ),
      ),
    );
    for (final icon in tester.widgetList<BusyDataGtkHeaderIcon>(
      find.byType(BusyDataGtkHeaderIcon),
    )) {
      expect(
        tester.getSize(find.byWidget(icon)),
        const Size.square(BusyDataLinuxHeaderStyle.symbolicIconSize),
      );
    }
    expect(find.byType(Image), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(BusyDataGtkHeaderIcon),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('native popup returns opening key releases to the existing view', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    final rowFocus = FocusNode();
    var invoked = 0;
    Future<List<String>> windows({bool main = false}) async {
      final result = await tester.runAsync(
        () => Process.run('xdotool', [
          'search',
          '--onlyvisible',
          '--pid',
          '$pid',
          if (main) ...['--name', '^BusyData\$'],
        ]),
      );
      if (result!.exitCode == 1) return [];
      expect(result.exitCode, 0, reason: '${result.stderr}');
      return '${result.stdout}'
          .trim()
          .split('\n')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    Future<void> keyboard(List<String> arguments) async {
      final result = await tester.runAsync(
        () => Process.run('xdotool', arguments),
      );
      expect(result!.exitCode, 0, reason: '${result.stderr}');
    }

    Future<void> until(Future<bool> Function() predicate, String reason) async {
      final watch = Stopwatch()..start();
      while (watch.elapsed < const Duration(seconds: 5)) {
        await tester.pump();
        if (await predicate()) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      fail(reason);
    }

    addTearDown(() async {
      // Only cleanup an owned native popup if an assertion interrupted the tour.
      await keyboard(['key', '--clearmodifiers', 'Escape']);
      await tester.pumpWidget(const SizedBox.shrink());
      rowFocus.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: BusyDataYaruTheme.build(
          brightness: Brightness.light,
          accentColor: Colors.orange,
        ),
        home: Material(
          child: const LinuxControls().contextMenu(
            Focus(
              focusNode: rowFocus,
              autofocus: true,
              child: const Center(child: Text('Scoped fixture row')),
            ),
            [DesktopMenuAction('Inspect scoped fixture', () => invoked++)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final main = await windows(main: true);
    expect(main, hasLength(1));
    await keyboard(['windowfocus', '--sync', main.single]);
    final ordinary = (await windows()).toSet();
    for (final key in ['Menu', 'Menu', 'shift+F10', 'Menu']) {
      final before = invoked;
      if (key == 'shift+F10') {
        // Use the existing physical F-key helper: libxdo's higher-level XKB
        // lookup adds Alt on this map, which would test a different shortcut.
        final result = await tester.runAsync(
          () => Process.run('/usr/bin/python3', [
            '-c',
            "import sys;sys.path.insert(0,'tool');import gi;"
                "gi.require_version('Gdk','3.0');from gi.repository import Gdk;"
                "Gdk.init([]);from native_workbench_acceptance import native_function_key;"
                "native_function_key('F10',shift=True)",
          ]),
        );
        expect(result!.exitCode, 0, reason: '${result.stderr}');
      } else {
        await keyboard(['key', '--clearmodifiers', key]);
      }
      await until(
        () async => (await windows()).any((id) => !ordinary.contains(id)),
        'The scoped native popup did not map for $key',
      );
      await until(
        () async =>
            !HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.contextMenu,
            ) &&
            !HardwareKeyboard.instance.isLogicalKeyPressed(
              LogicalKeyboardKey.f10,
            ) &&
            !HardwareKeyboard.instance.isShiftPressed,
        'GTK consumed an opening key release for $key',
      );
      await keyboard(['key', '--clearmodifiers', 'Return']);
      await until(
        () async => invoked == before + 1,
        'The captured native action did not return for $key',
      );
      await until(
        () async => (await windows()).every(ordinary.contains),
        'The native popup did not retire for $key',
      );
      expect(rowFocus.hasPrimaryFocus, isTrue);
    }
    expect(invoked, 4);
  });
}
