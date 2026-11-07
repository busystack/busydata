import 'dart:ui' as ui;
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/serialized_semantics_test_binding.dart';

void main() {
  SerializedSemanticsTestBinding();
  for (final row in [false, true]) {
    for (final longValue in [false, true]) {
      testWidgets(
        'choice tooltip retains its semantic owner and one labeled action: row=$row long=$longValue',
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          await tester.binding.setSurfaceSize(const Size(1024, 720));
          final semantics = tester.ensureSemantics();
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(10, 10));
          const label = 'Environment';
          final initial = longValue
              ? List.filled(
                  8,
                  'Development environment with full exact value',
                ).join(' ')
              : 'Development';
          final values = {initial: initial, 'Staging': 'Staging'};
          var selected = initial;
          var calls = 0;
          Future<void> frames(String phase) async {
            SerializedSemanticsTestBinding.phase = phase;
            for (final ms in [16, 16, 75, 150, 500]) {
              await tester.pump(Duration(milliseconds: ms));
            }
          }

          void expectOneLabeledAction() {
            final data = tester
                .getSemantics(find.bySemanticsLabel(RegExp('^Environment')))
                .getSemanticsData();
            expect(data.label, contains(label));
            expect(selected.allMatches(data.label), hasLength(1));
            expect(data.tooltip, isEmpty);
            expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
          }

          try {
            SerializedSemanticsTestBinding.resetRecorder();
            await tester.pumpWidget(
              fluent.FluentApp(
                home: fluent.ScaffoldPage(
                  content: StatefulBuilder(
                    builder: (context, setState) {
                      void changed(String value) => setState(() {
                        selected = value;
                        calls++;
                      });
                      return Center(
                        child: SizedBox(
                          width: 360,
                          child: row
                              ? const WindowsControls().comboRow(
                                  label,
                                  selected,
                                  values,
                                  changed,
                                )
                              : const WindowsControls().choice(
                                  selected,
                                  values,
                                  changed,
                                  label: label,
                                ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expectOneLabeledAction();
            final control = find.byType(fluent.ComboBox<String>);
            final visibleBefore = find.text(initial).evaluate().length;
            await mouse.moveTo(tester.getCenter(control));
            await frames('hover-choice');
            // Fluent's actual default wait is one second. Observe the real
            // tooltip after that deadline, including its opening transition.
            await tester.pump(const Duration(seconds: 2));
            await tester.pumpAndSettle();
            expect(
              find.text(initial).evaluate().length,
              greaterThan(visibleBefore),
              reason: 'The full-value tooltip must remain visible',
            );
            if (longValue) {
              final paragraph = tester.renderObject<RenderParagraph>(
                find.text(initial).last,
              );
              final glyphs = paragraph.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: initial.length),
              );
              expect(glyphs, isNotEmpty);
              for (final glyph in glyphs) {
                expect(
                  glyph.right,
                  lessThanOrEqualTo(paragraph.size.width + .5),
                );
                expect(
                  glyph.bottom,
                  lessThanOrEqualTo(paragraph.size.height + .5),
                );
              }
            }
            await tester.tap(control);
            await frames('open-choice');
            await tester.pumpAndSettle();
            await tester.tap(find.text('Staging').last.hitTestable());
            await frames('select-choice');
            await tester.pumpAndSettle();
            expect(selected, 'Staging');
            expect(calls, 1);
            expectOneLabeledAction();
            await mouse.moveTo(tester.getCenter(control));
            await frames('hover-new-value');
            await tester.pump(const Duration(seconds: 2));
            await tester.pumpAndSettle();
            await mouse.moveTo(const Offset(10, 10));
            await frames('retire-tooltip');
          } finally {
            SerializedSemanticsTestBinding.phase = 'dispose-owner';
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            semantics.dispose();
            await mouse.removePointer();
            await tester.binding.setSurfaceSize(null);
            debugDefaultTargetPlatformOverride = null;
          }
          expect(
            SerializedSemanticsTestBinding.orphanBatches,
            isEmpty,
            reason:
                'Every tooltip update must remain reachable from the engine root across hover, selection, retirement and owner disposal',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
