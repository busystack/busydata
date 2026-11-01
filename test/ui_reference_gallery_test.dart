// Current-source production component comparison; no feature models are copied.

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/app_theme.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_tabs.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!Platform.isLinux) return;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    final ubuntu = FontLoader('packages/yaru/Ubuntu');
    for (final name in ['L', 'R', 'M', 'B']) {
      ubuntu.addFont(
        rootBundle.load('packages/yaru/assets/fonts/Ubuntu-$name.ttf'),
      );
    }
    await ubuntu.load();
    for (final family in [
      'Ubuntu',
      'Ubuntu Sans',
      'Ubuntu Mono',
      'Noto Sans Arabic',
      'Noto Sans',
      'DejaVu Sans',
    ]) {
      final resolved = await Process.run('fc-match', [
        '--format=%{file}',
        family,
      ]);
      if (resolved.exitCode != 0 || (resolved.stdout as String).isEmpty) {
        throw StateError('Missing real comparison font: $family');
      }
      await (FontLoader(family)..addFont(
            Future.value(
              ByteData.sublistView(
                File(resolved.stdout as String).readAsBytesSync(),
              ),
            ),
          ))
          .load();
    }
    await (FontLoader(
      'packages/yaru/YaruIcons',
    )..addFont(rootBundle.load('packages/yaru/assets/yaru_icons.otf'))).load();
  });
  for (final brightness in Brightness.values) {
    testWidgets('current production components ${brightness.name}', (
      tester,
    ) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      await tester.binding.setSurfaceSize(const Size(860, 1120));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      addTearDown(() => debugDisableShadows = true);
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window'),
        (_) async => <String, Object>{},
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window/events'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('busydata/native_menus'),
        (_) async => throw MissingPluginException(),
      );
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          const MethodChannel('busydata/native_menus'),
          null,
        ),
      );
      final directory = Directory(
        Platform.environment['BUSYDATA_UI_REFERENCE_GALLERY_OUTPUT'] ??
            'build/ui-parity/gallery/busydata',
      )..createSync(recursive: true);
      final boundary = GlobalKey();
      final host = TextEditingController(text: 'db.example.test');
      final menuController = BusyDataMenuController();
      final model = WorkbenchModel(directory)
        ..draftRecovery = false
        ..newDocument(path: 'Orders.sql')
        ..newDocument(path: 'Query.sql');
      final stateOwners = <WidgetStatesController, Set<WidgetState>>{};
      Widget button(BuildContext context, int role, Set<WidgetState> states) {
        final state = WidgetStatesController(states);
        stateOwners[state] = states;
        final action = states.contains(WidgetState.disabled) ? null : () {};
        return switch (role) {
          0 => BusyDataPushButton.standard(
            onPressed: action,
            statesController: state,
            child: const Text('Test connection'),
          ),
          1 => BusyDataPushButton.suggested(
            onPressed: action,
            statesController: state,
            child: const Text('Save & connect'),
          ),
          _ => BusyDataPushButton.destructive(
            context: context,
            onPressed: action,
            statesController: state,
            child: const Text('Delete connection'),
          ),
        };
      }

      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${directory.path}/${brightness.name}-$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }

      Widget app(WidgetBuilder builder) => RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildBusyDataTheme(
            brightness: brightness,
            accentColor: const Color(0xffe95420),
          ),
          home: Scaffold(body: Builder(builder: builder)),
        ),
      );
      await tester.pumpWidget(
        app(
          (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Grouped entries, selectors and action rows',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                BusyDataGroupedList(
                  title: 'Connection',
                  filled: true,
                  children: [
                    BusyDataGroupedTextEntry(controller: host, label: 'Host'),
                    BusyDataComboRow<String>(
                      title: 'Driver',
                      values: const ['postgres', 'mysql'],
                      selected: 'postgres',
                      labelFor: (v) => v == 'postgres' ? 'PostgreSQL' : 'MySQL',
                      onSelected: (_) {},
                    ),
                    BusyDataSwitchRow(
                      title: 'Read-only policy',
                      value: true,
                      onChanged: (_) {},
                    ),
                    BusyDataActionRow(
                      title: 'New connection',
                      subtitle: 'Configure a database connection',
                      leading: const Icon(YaruIcons.server),
                      onTap: () {},
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Normal · hover · pressed · keyboard focus · disabled',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final states in <Set<WidgetState>>[
                  {},
                  {WidgetState.hovered},
                  {WidgetState.pressed},
                  {WidgetState.focused},
                  {WidgetState.disabled},
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var role = 0; role < 3; role++)
                          button(context, role, states),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Sidebar selection and tree geometry',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                for (final selected in [false, true])
                  BusyDataSidebarRowSurface(
                    selected: selected,
                    focused: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 1),
                      child: Row(
                        children: [
                          const SizedBox(width: 18),
                          BusyDataSidebarTreeControl(
                            expanded: true,
                            label: 'Orders',
                            onToggle: () {},
                          ),
                          const SizedBox(width: 4),
                          const Icon(YaruIcons.folder, size: 16),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('Orders')),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  'Document tabs',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                WorkbenchTabs(
                  model: model,
                  controls: const LinuxControls(),
                  close: (_) {},
                ),
                const SizedBox(height: 20),
                BusyDataPopupSelector<String>(
                  value: 'postgres',
                  label: 'PostgreSQL',
                  tooltip: 'Driver',
                  enabled: false,
                  options: const [
                    BusyDataPopupSelectorOption(
                      value: 'postgres',
                      label: 'PostgreSQL',
                    ),
                  ],
                  onSelected: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final entry in stateOwners.entries) {
        for (final state in entry.value) {
          entry.key.update(state, true);
        }
      }
      await capture('components');
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer();
      final previousStrategy = FocusManager.instance.highlightStrategy;
      final tab = find.byKey(
        ValueKey('document-tab:${model.workbenchDocuments.first.id}'),
      );
      await mouse.moveTo(tester.getCenter(tab));
      await mouse.down(tester.getCenter(tab));
      await mouse.up();
      await mouse.moveTo(const Offset(1, 1));
      await capture('tabs-pointer');
      final tabFocus = Focus.of(
        tester.element(
          find.descendant(of: tab, matching: find.byType(Text)).first,
        ),
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      tabFocus.requestFocus();
      await capture('tabs-keyboard');
      tabFocus.unfocus();

      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      for (final (role, target) in [
        (
          'standard',
          find.widgetWithText(FilledButton, 'Test connection').first,
        ),
        (
          'suggested',
          find.widgetWithText(ElevatedButton, 'Save & connect').first,
        ),
        (
          'destructive',
          find.widgetWithText(ElevatedButton, 'Delete connection').first,
        ),
      ]) {
        final position = tester.getCenter(target);
        await mouse.moveTo(position);
        await capture('button-$role-hover');
        await mouse.down(position);
        await capture('button-$role-pressed');
        await mouse.up();
        await mouse.moveTo(const Offset(1, 1));
        final buttonFocus = Focus.of(
          tester.element(
            find.descendant(of: target, matching: find.byType(Text)).first,
          ),
        );
        buttonFocus.requestFocus();
        await capture('button-$role-focus');
        buttonFocus.unfocus();
      }
      FocusManager.instance.highlightStrategy = previousStrategy;
      await mouse.removePointer();

      await tester.runAsync(() async {
        await File(
          '${directory.path}/${brightness.name}-metrics.txt',
        ).writeAsString(
          '${tester.getSize(find.text('Test connection').first)}\n'
          '${DefaultTextStyle.of(tester.element(find.text('Test connection').first)).style}\n'
          '${Theme.of(tester.element(find.text('Test connection').first)).filledButtonTheme.style}\n',
        );
      });
      await tester.pumpWidget(
        app(
          (context) => Center(
            child: BusyDataMenuButton<String>(
              controller: menuController,
              tooltip: 'Actions',
              entries: const [
                BusyDataMenuEntry(
                  value: 'copy',
                  label: 'Copy',
                  icon: YaruIcons.copy,
                  shortcut: 'Ctrl+C',
                ),
                BusyDataMenuEntry(
                  value: 'selected',
                  label: 'Selected value',
                  role: BusyDataMenuEntryRole.radio,
                  selected: true,
                ),
                BusyDataMenuEntry(
                  value: 'disabled',
                  label: 'Unavailable action',
                  enabled: false,
                ),
                BusyDataMenuEntry(
                  value: 'separator',
                  label: '',
                  separator: true,
                ),
                BusyDataMenuEntry(
                  value: 'more',
                  label: 'More',
                  children: [
                    BusyDataMenuEntry(value: 'nested', label: 'Nested action'),
                  ],
                ),
              ],
              onSelected: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      for (final label in [
        'Copy',
        'Selected value',
        'Unavailable action',
        'More',
      ]) {
        expect(find.text(label).hitTestable(), findsOneWidget);
      }
      await capture('menu');
      menuController.close();
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        app(
          (context) => BusyDataDialogShell(
            title: 'Review connection',
            actions: [
              BusyDataPushButton.standard(
                onPressed: () {},
                child: const Text('Cancel'),
              ),
              BusyDataPushButton.suggested(
                onPressed: () {},
                child: const Text('Save & connect'),
              ),
              BusyDataPushButton.destructive(
                context: context,
                onPressed: () {},
                child: const Text('Delete'),
              ),
            ],
            children: const [
              Text('The selected destination will be saved and connected.'),
            ],
          ),
        ),
      );
      expect(find.text('Review connection'), findsOneWidget);
      await capture('dialog');
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      debugDisableShadows = previousShadows;
      debugDefaultTargetPlatformOverride = previousPlatform;
      host.dispose();
      for (final owner in stateOwners.keys) {
        owner.dispose();
      }
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window'),
        null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('yaru_window/events'),
        null,
      );
    }, skip: !Platform.isLinux);
  }
}
