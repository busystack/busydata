import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final delay in <int>[-2, -1, 0, 16, 150, 500]) {
    testWidgets(
      'Fluent menu retains exposed actions across opening rebuild $delay',
      (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final revision = ValueNotifier<int>(0);
          addTearDown(revision.dispose);
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
          });
          final calls = <int>[];
          await tester.pumpWidget(
            fluent.FluentApp(
              home: fluent.ScaffoldPage(
                content: Align(
                  alignment: Alignment.topLeft,
                  child: ValueListenableBuilder<int>(
                    valueListenable: revision,
                    builder: (context, value, _) =>
                        const WindowsControls().menuBar([
                          DesktopMenu('View', [
                            DesktopMenuAction(
                              'Owned menu action',
                              () => calls.add(value),
                            ),
                          ]),
                        ]),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('View'));
          if (delay == -2) {
            await tester.pumpAndSettle();
          } else if (delay >= 0) {
            await tester.pump(Duration(milliseconds: delay));
          }
          if (delay != -2) {
            revision.value = 1;
          }
          await tester.pumpAndSettle();
          expect(
            find.bySemanticsLabel('Owned menu action'),
            findsOneWidget,
            reason:
                'The action must remain exposed in actual current semantics after an owner notification during opening',
          );
          await tester.tap(find.text('Owned menu action'));
          await tester.pumpAndSettle();
          expect(calls.length, 1);
          revision.value = 2;
          await tester.pumpAndSettle();
          await tester.tap(find.text('View'));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Owned menu action'), findsOneWidget);
          await tester.tap(find.text('Owned menu action'));
          await tester.pumpAndSettle();
          expect(
            calls.last,
            2,
            reason:
                'A reopened stable root must use current actions, not the first callback',
          );
          expect(find.byType(fluent.MenuFlyout), findsNothing);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
