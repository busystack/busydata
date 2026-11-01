import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/result_presentation.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_display_format_dialog.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget nativeMatrixApp(
  DesktopControls controls,
  Widget body,
  TextDirection direction,
  double scale,
) {
  Widget builder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      highContrast: true,
      disableAnimations: true,
    ),
    child: Directionality(textDirection: direction, child: child!),
  );
  return controls is WindowsControls
      ? fluent.FluentApp(builder: builder, home: body)
      : MaterialApp(
          builder: builder,
          home: Scaffold(body: body),
        );
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} Value Editor keyboard, focus and exact edit '
          '${direction.name} $scale high contrast reduced motion',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            try {
              final trigger = FocusNode();
              addTearDown(trigger.dispose);
              rpc.Value? staged;
              final body = Builder(
                builder: (context) => Center(
                  child: controls.button('Open Value Editor', () {
                    controls.dialog<void>(
                      context,
                      'value · text',
                      ResultValueEditor(
                        controls: controls,
                        value: rpc.Value(text: 'exact 漢😀'),
                        column: rpc.Column(name: 'value', typeName: 'text'),
                        retainDraft: (_, _) {},
                        cancelRead: () {},
                        stage: (value) async => staged = value,
                      ),
                      [
                        controls.button(
                          'Close',
                          () => Navigator.of(context).pop(),
                        ),
                      ],
                      bodyScrolls: true,
                    );
                  }, focusNode: trigger),
                ),
              );
              await tester.pumpWidget(
                nativeMatrixApp(controls, body, direction, scale),
              );
              await tester.pumpAndSettle();
              trigger.requestFocus();
              await tester.pump();
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await tester.pumpAndSettle();
              expect(find.text('exact 漢😀'), findsOneWidget);
              final edit = find.text('Edit cell');
              await tester.ensureVisible(edit);
              expect(edit.hitTestable(), findsOneWidget);
              await tester.tap(edit);
              await tester.pumpAndSettle();
              final input = find.byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              );
              await tester.ensureVisible(input);
              await tester.tap(input);
              await tester.enterText(input, 'changed exact 漢😀');
              expect(
                tester.widget<EditableText>(input).focusNode.hasFocus,
                isTrue,
              );
              expect(
                tester.getSemantics(input).getSemanticsData().label,
                contains('Exact value'),
              );
              final stage = find.text('Stage change');
              await tester.ensureVisible(stage);
              expect(stage.hitTestable(), findsOneWidget);
              await tester.tap(stage);
              await tester.pumpAndSettle();
              expect(staged!.text, 'changed exact 漢😀');
              expect(find.byType(ResultValueEditor), findsNothing);
              expect(trigger.hasFocus, isTrue);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
        testWidgets(
          '${controls.runtimeType} temporal dialog keyboard validation '
          '${direction.name} $scale high contrast reduced motion',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            try {
              final trigger = FocusNode();
              addTearDown(trigger.dispose);
              ResultDisplayChoice? accepted;
              final body = Builder(
                builder: (context) => Center(
                  child: controls.button('Open display format', () async {
                    accepted = await controls.dialog<ResultDisplayChoice>(
                      context,
                      'Display format',
                      ResultDisplayFormatDialog(
                        controls: controls,
                        columns: [
                          rpc.Column(name: 'timestamp', typeName: 'timestamp'),
                        ],
                        initialColumn: 0,
                        formats: {0: ColumnDisplayFormat.temporalPattern},
                        patterns: {
                          0: TemporalDisplayPattern(
                            'yyyy-MM-dd',
                            TemporalDisplayZone.source,
                          ),
                        },
                        names: {
                          ColumnDisplayFormat.temporalPattern:
                              'Temporal · custom pattern',
                        },
                      ),
                      [],
                      bodyScrolls: true,
                    );
                  }, focusNode: trigger),
                ),
              );
              await tester.pumpWidget(
                nativeMatrixApp(controls, body, direction, scale),
              );
              await tester.pumpAndSettle();
              trigger.requestFocus();
              await tester.pump();
              await tester.sendKeyEvent(LogicalKeyboardKey.enter);
              await tester.pumpAndSettle();
              final input = find.byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              );
              await tester.ensureVisible(input);
              await tester.enterText(input, 'yyyy z');
              final apply = find.text('Apply');
              await tester.ensureVisible(apply);
              expect(apply.hitTestable(), findsOneWidget);
              await tester.tap(apply);
              await tester.pumpAndSettle();
              expect(accepted, isNull);
              expect(
                tester.widget<EditableText>(input).focusNode.hasFocus,
                isTrue,
              );
              await tester.enterText(input, 'dd/MM/yyyy HH:mm:ss.SSSSSS');
              await tester.ensureVisible(apply);
              await tester.tap(apply);
              await tester.pumpAndSettle();
              expect(accepted!.pattern!.pattern, 'dd/MM/yyyy HH:mm:ss.SSSSSS');
              expect(trigger.hasFocus, isTrue);
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
