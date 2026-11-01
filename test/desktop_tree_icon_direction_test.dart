import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        '${controls.runtimeType} collapsed tree glyph follows $direction children',
        (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Directionality(
                textDirection: direction,
                child: Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: controls.icon(DesktopIcon.expand),
                  ),
                ),
              ),
            ),
          );
          final glyph = find.descendant(
            of: find.byType(Icon),
            matching: find.byType(RichText),
          );
          expect(glyph, findsOneWidget);
          final box = tester.renderObject<RenderBox>(glyph);
          final first = box.localToGlobal(Offset.zero);
          final last = box.localToGlobal(Offset(box.size.width, 0));
          expect(
            last.dx - first.dx,
            direction == TextDirection.rtl ? isNegative : isPositive,
            reason:
                'The native collapsed chevron must point toward the indented children.',
          );
        },
      );
    }
  }
}
