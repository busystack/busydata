import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final count in [3, 40]) {
    testWidgets(
      'dropdown keeps its menu semantic parent through animation, $count items',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        await tester.binding.setSurfaceSize(const Size(1024, 720));
        final semantics = tester.ensureSemantics();
        final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
        final menuIds = <int>{};
        var observing = false;
        var updates = 0;
        var calls = 0;

        void observe() {
          if (!observing) return;
          updates++;
          void visit(SemanticsNode node) {
            if (node.getSemanticsData().role == SemanticsRole.menu) {
              menuIds.add(node.id);
            }
            node.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          final root = owner.rootSemanticsNode;
          if (root != null) visit(root);
        }

        owner.addListener(observe);
        try {
          await tester.pumpWidget(
            fluent.FluentApp(
              home: fluent.ScaffoldPage(
                content: Align(
                  alignment: const Alignment(-.35, .5),
                  child: const WindowsControls().menu('More', [
                    for (var i = 0; i < count; i++)
                      DesktopMenuAction('Action $i', () => calls++),
                  ]),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          observing = true;
          await tester.tap(find.text('More'));
          await tester.pump();
          for (var frame = 0; frame < 20; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          await tester.pumpAndSettle();
          observing = false;

          expect(updates, greaterThan(0));
          expect(
            menuIds,
            hasLength(1),
            reason:
                'Completing the transition must keep the semantic menu parent of '
                'retained scrollable nodes alive',
          );
          final action = tester.getSemantics(find.text('Action 0'));
          expect(action.getSemanticsData().role, SemanticsRole.menuItem);
          action.owner!.performAction(action.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(calls, 1);
          expect(find.byType(fluent.MenuFlyout), findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          observing = false;
          owner.removeListener(observe);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          semantics.dispose();
          await tester.binding.setSurfaceSize(null);
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
