import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/paged_selectable_text.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  DesktopControls controls,
  TextDirection direction,
  double scale,
  Widget child,
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
      ? fluent.FluentApp(builder: builder, home: child)
      : MaterialApp(
          builder: builder,
          home: Scaffold(body: child),
        );
}

void _expectPageStart(EditableTextState native, ScrollableState scroll) {
  final pixel =
      1 / View.of(native.context).devicePixelRatio + precisionErrorTolerance;
  // The native caret snaps to physical pixels; fractional text scaling may
  // require a subpixel reveal offset rather than an exact logical zero.
  expect(scroll.position.pixels, inInclusiveRange(0, pixel));
  final caret = native.renderEditable.getLocalRectForCaret(
    const TextPosition(offset: 0),
  );
  expect(caret.top, greaterThanOrEqualTo(-pixel));
  expect(caret.bottom, greaterThan(0));
  expect(
    caret.bottom,
    lessThanOrEqualTo(native.renderEditable.size.height + pixel),
  );
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final configuration in [
      (TextDirection.ltr, 1.0),
      (TextDirection.rtl, 1.5),
      (TextDirection.rtl, 2.0),
    ]) {
      testWidgets(
        '${controls.runtimeType} readonly text owns its bounded native viewport '
        '${configuration.$1.name} ${configuration.$2}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          try {
            const ending = 'FIRST-PAGE-END';
            final first =
                ('0123456789abcdef\n' * 1000).substring(
                  0,
                  16384 - ending.length,
                ) +
                ending;
            final second = '${'second-page\n' * 900}SECOND-PAGE-END';
            await tester.pumpWidget(
              _host(
                controls,
                configuration.$1,
                configuration.$2,
                Center(
                  child: SizedBox(
                    width: 640,
                    height: 360,
                    child: PagedSelectableText(
                      controls: controls,
                      text: first + second,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final field = find.byType(EditableText);
            expect(field, findsOneWidget);
            final native = tester.widget<EditableText>(field);
            final nativeState = tester.state<EditableTextState>(field);
            final render = tester.allRenderObjects
                .whereType<RenderEditable>()
                .single;
            final scroll = tester.state<ScrollableState>(
              find.descendant(of: field, matching: find.byType(Scrollable)),
            );
            expect(native.readOnly, isTrue);
            expect(native.controller.text, first);
            expect(render.size.height, greaterThan(0));
            expect(render.size.height, lessThanOrEqualTo(344));
            expect(scroll.position.viewportDimension, render.size.height);
            expect(scroll.position.maxScrollExtent, greaterThan(0));
            final end = TextPosition(offset: first.length);
            expect(
              render.getLocalRectForCaret(end).top,
              greaterThan(render.size.height),
            );
            scroll.position.jumpTo(scroll.position.maxScrollExtent);
            await tester.pumpAndSettle();
            final endRect = render.getLocalRectForCaret(end);
            expect(endRect.bottom, greaterThan(0));
            expect(endRect.bottom, lessThanOrEqualTo(render.size.height + 1));

            native.focusNode.requestFocus();
            await tester.pump();
            await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
            await tester.pumpAndSettle();
            final selection = TextSelection(
              baseOffset: 0,
              extentOffset: first.length,
            );
            expect(native.controller.selection, selection);
            final data = tester.getSemantics(field).getSemanticsData();
            expect(data.flagsCollection.isTextField, isTrue);
            expect(data.flagsCollection.isReadOnly, isTrue);
            expect(data.value, first);
            expect(data.textSelection, selection);

            await tester.tap(find.text('Next text page'));
            await tester.pumpAndSettle();
            final next = tester.widget<EditableText>(field);
            expect(tester.state<EditableTextState>(field), same(nativeState));
            expect(
              tester.allRenderObjects.whereType<RenderEditable>().single,
              same(render),
            );
            final nextScroll = tester.state<ScrollableState>(
              find.descendant(of: field, matching: find.byType(Scrollable)),
            );
            expect(next.controller, isNot(same(native.controller)));
            expect(next.controller.text, second);
            expect(next.controller.selection.isCollapsed, isTrue);
            _expectPageStart(
              tester.state<EditableTextState>(field),
              nextScroll,
            );
            expect(nextScroll.position.maxScrollExtent, greaterThan(0));
            expect(tester.getSemantics(field).getSemanticsData().value, second);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
      testWidgets(
        '${controls.runtimeType} equal pages and value replacement reset only '
        'the owned native selection ${configuration.$1.name} ${configuration.$2}',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          final first = ('0123456789abcdef\n' * 1000).substring(0, 16384);
          final last = 'last-page\n' * 1000;
          final value = ValueNotifier(first + first + last);
          String? clipboard;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => switch (call.method) {
              'Clipboard.setData' =>
                clipboard = (call.arguments as Map)['text'] as String,
              'Clipboard.getData' => {'text': clipboard},
              'Clipboard.hasStrings' => {'value': clipboard != null},
              _ => null,
            },
          );
          try {
            await tester.pumpWidget(
              _host(
                controls,
                configuration.$1,
                configuration.$2,
                Center(
                  child: SizedBox(
                    width: 640,
                    height: 360,
                    child: ValueListenableBuilder<String>(
                      valueListenable: value,
                      builder: (context, text, _) =>
                          PagedSelectableText(controls: controls, text: text),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final field = find.byType(EditableText);
            final state = tester.state<EditableTextState>(field);
            final controller = state.widget.controller;
            final render = state.renderEditable;
            final scroll = tester.state<ScrollableState>(
              find.descendant(of: field, matching: find.byType(Scrollable)),
            );
            Future<void> selectAndCopy(String expected) async {
              state.widget.focusNode.requestFocus();
              await tester.pumpAndSettle();
              expect(state.widget.focusNode.hasPrimaryFocus, isTrue);
              // Start a fresh selection and clipboard operation. A widget test
              // can retain selection across blur before its lifecycle resumes.
              state.widget.controller.selection = const TextSelection.collapsed(
                offset: 0,
              );
              clipboard = 'pending explicit keyboard copy';
              await tester.pump();
              await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
              await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
              await tester.pumpAndSettle();
              expect(clipboard, expected);
              expect(
                state.widget.controller.selection.textInside(expected),
                expected,
              );
              scroll.position.jumpTo(scroll.position.maxScrollExtent);
              await tester.pump();
              expect(scroll.position.pixels, greaterThan(0));
            }

            await selectAndCopy(first);
            expect(state.showToolbar(), isTrue);
            await tester.pumpAndSettle();
            final copyFocus = Focus.of(tester.element(find.text('Copy')));
            copyFocus.requestFocus();
            await tester.pumpAndSettle();
            expect(FocusManager.instance.primaryFocus, same(copyFocus));
            expect(state.widget.focusNode.hasFocus, isTrue);
            expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
            clipboard = 'not copied until keyboard activation';
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(clipboard, first);
            expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

            // The overlay participates in this field's focus ownership, while
            // Tab must still leave its native toolbar for surrounding controls.
            await selectAndCopy(first);
            expect(state.showToolbar(), isTrue);
            await tester.pumpAndSettle();
            Focus.of(tester.element(find.text('Copy'))).requestFocus();
            await tester.pumpAndSettle();
            final toolbarStops = state.contextMenuButtonItems.length + 1;
            for (
              var step = 0;
              step < toolbarStops && state.widget.focusNode.hasFocus;
              step++
            ) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
            }
            expect(state.widget.focusNode.hasFocus, isFalse);
            expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);

            await selectAndCopy(first);
            state.showToolbar();
            await tester.pumpAndSettle();
            expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
            final next = find.text('Next text page');
            final buttonFocus = Focus.of(tester.element(next));
            buttonFocus.requestFocus();
            await tester.pumpAndSettle();
            expect(FocusManager.instance.primaryFocus, same(buttonFocus));
            expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
            clipboard = 'unchanged until explicit copy';
            await tester.tap(next);
            await tester.pumpAndSettle();
            expect(tester.state<EditableTextState>(field), same(state));
            expect(state.renderEditable, same(render));
            expect(state.widget.controller, same(controller));
            expect(state.widget.controller.text, first);
            expect(state.widget.controller.selection.isCollapsed, isTrue);
            _expectPageStart(state, scroll);
            expect(FocusManager.instance.primaryFocus, same(buttonFocus));
            expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
            expect(clipboard, 'unchanged until explicit copy');
            await selectAndCopy(first);

            // Change the represented value while the old native field still has
            // focus. The first replacement frame must show the new first page.
            expect(state.showToolbar(), isTrue);
            await tester.pumpAndSettle();
            final replacement = 'replacement 漢😀\r\n' * 1500;
            value.value = replacement;
            await tester.pump();
            expect(tester.state<EditableTextState>(field), same(state));
            final shown = tester
                .widget<SelectableText>(find.byType(SelectableText))
                .data!;
            expect(replacement.startsWith(shown), isTrue);
            expect(shown.length, lessThanOrEqualTo(16384));
            expect(state.widget.controller.text, shown);
            expect(state.widget.controller.selection.isCollapsed, isTrue);
            _expectPageStart(state, scroll);
            expect(tester.getSemantics(field).getSemanticsData().value, shown);
            await tester.pumpAndSettle();
            expect(state.widget.focusNode.hasFocus, isFalse);
            expect(find.byType(AdaptiveTextSelectionToolbar), findsNothing);
            await selectAndCopy(shown);
            // Preserve the same field when the page controls disappear and
            // reappear, as they do when a loaded byte chunk becomes hex text.
            const short = 'short exact 漢😀';
            value.value = short;
            await tester.pumpAndSettle();
            expect(tester.state<EditableTextState>(field), same(state));
            expect(state.renderEditable, same(render));
            expect(state.widget.controller.text, short);
            _expectPageStart(state, scroll);
            expect(scroll.position.maxScrollExtent, 0);
            value.value = replacement;
            await tester.pumpAndSettle();
            expect(tester.state<EditableTextState>(field), same(state));
            expect(state.renderEditable, same(render));
            expect(state.widget.controller.text, shown);
            _expectPageStart(state, scroll);
            await selectAndCopy(shown);
            expect(tester.takeException(), isNull);
            expect(state.showToolbar(), isTrue);
            await tester.pumpAndSettle();
            Focus.of(tester.element(find.text('Copy'))).requestFocus();
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pump();
            expect(tester.takeException(), isNull);
          } finally {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              null,
            );
            value.dispose();
            semantics.dispose();
          }
        },
      );
    }
  }
}
