import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('context command changes document after its native menu retires', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    var calls = 0;
    var menuPresentWhenInvoked = false;
    var tableActive = false;
    try {
      await tester.pumpWidget(
        fluent.FluentApp(
          home: StatefulBuilder(
            builder: (context, set) => fluent.ScaffoldPage(
              content: Column(
                children: [
                  const WindowsControls().contextMenu(
                    fluent.Button(
                      onPressed: () {},
                      child: const Text('Source table'),
                    ),
                    [
                      DesktopMenuAction('Open data', () {
                        calls++;
                        menuPresentWhenInvoked = find
                            .byType(fluent.MenuFlyout)
                            .evaluate()
                            .isNotEmpty;
                        set(() => tableActive = true);
                      }),
                    ],
                  ),
                  Expanded(
                    child: tableActive
                        ? const Column(
                            children: [
                              Text('Table editor'),
                              Text('Row 1, n: 漢😀'),
                            ],
                          )
                        : const Text('SQL editor'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(
        tester.getCenter(find.text('Source table')),
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      expect(find.text('Open data'), findsOneWidget);
      await tester.tap(find.text('Open data'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Table editor'), findsOneWidget);
      expect(find.byType(fluent.MenuFlyout), findsNothing);
      expect(
        menuPresentWhenInvoked,
        isFalse,
        reason:
            'A document transition must not mutate the underlying semantics while the retiring flyout still owns its route.',
      );
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });

  testWidgets('retiring context command does not outlive its owner', (
    tester,
  ) async {
    var calls = 0;
    var showSource = true;
    late StateSetter update;
    await tester.pumpWidget(
      fluent.FluentApp(
        home: StatefulBuilder(
          builder: (context, set) {
            update = set;
            return fluent.ScaffoldPage(
              content: showSource
                  ? const WindowsControls().contextMenu(
                      const Text('Source table'),
                      [DesktopMenuAction('Open data', () => calls++)],
                    )
                  : const Text('Source removed'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.text('Source table')),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open data'));
    update(() => showSource = false);
    await tester.pumpAndSettle();
    expect(find.text('Source removed'), findsOneWidget);
    expect(calls, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
