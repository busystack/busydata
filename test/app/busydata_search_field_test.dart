import 'package:busydata/src/app/busydata_search_field.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Widget child, {
  Brightness brightness = Brightness.light,
  double scale = 1,
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: BusyDataYaruTheme.build(
    brightness: brightness,
    accentColor: Colors.orange,
  ),
  builder: (context, body) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: Directionality(textDirection: direction, child: body!),
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 400, child: child)),
  ),
);

void main() {
  testWidgets(
    'shared search names the editor once and exposes Clear independently',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final controller = TextEditingController(text: 'exact query');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final changes = <String>[];
      await tester.pumpWidget(
        host(
          BusyDataSearchField(
            controller: controller,
            focusNode: focus,
            hintText: 'Find action',
            onChanged: changes.add,
          ),
        ),
      );
      final field = tester.getSemantics(find.bySemanticsLabel('Find action'));
      expect(field.getSemanticsData().value, 'exact query');
      final clear = tester.getSemantics(find.bySemanticsLabel('Clear text'));
      for (var node = clear.parent; node != null; node = node.parent) {
        expect(node.getSemanticsData().flagsCollection.isTextField, isFalse);
      }
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(changes, ['']);
      expect(focus.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'typed query');
      for (final elapsed in [
        Duration.zero,
        const Duration(milliseconds: 50),
        const Duration(milliseconds: 250),
      ]) {
        await tester.pump(elapsed);
        final field = tester.getSemantics(find.byType(TextField));
        expect(field.getSemanticsData().label, 'Find action');
      }
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(changes, ['', 'typed query', '']);
      semantics.dispose();
    },
  );

  testWidgets(
    'Enter and selection keys stay local and defer to active composition',
    (tester) async {
      final controller = TextEditingController(text: 'query');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      var submitted = 0, moved = 0, escaped = 0;
      await tester.pumpWidget(
        host(
          BusyDataSearchField(
            controller: controller,
            focusNode: focus,
            autofocus: true,
            hintText: 'Actions',
            clearOnEscape: false,
            onSubmitted: (_) => submitted++,
            onMoveSelection: (n) => moved += n,
            onEscape: () => escaped++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(moved, 1);
      expect(submitted, 1);
      controller.value = const TextEditingValue(
        text: '漢',
        composing: TextRange(start: 0, end: 1),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      controller.value = const TextEditingValue(
        text: '漢',
        composing: TextRange(start: 0, end: 1),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(moved, 1);
      expect(escaped, 0);
      expect(controller.text, '漢');
      controller.value = const TextEditingValue(text: '漢');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(escaped, 1);
      expect(controller.text, '漢');
    },
  );

  testWidgets(
    'appearance, text scale and direction retain controller focus and selection',
    (tester) async {
      final controller = TextEditingController(text: 'planning review');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      Widget field() => BusyDataSearchField(
        controller: controller,
        focusNode: focus,
        hintText: 'Search',
      );
      await tester.pumpWidget(host(field()));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 8,
      );
      final before = tester.state<EditableTextState>(find.byType(EditableText));
      await tester.pumpWidget(
        host(
          field(),
          brightness: Brightness.dark,
          scale: 2,
          direction: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(before));
      expect(focus.hasFocus, isTrue);
      expect(
        controller.selection,
        const TextSelection(baseOffset: 2, extentOffset: 8),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'clear callback owns one publication and unmount retains external owners',
    (tester) async {
      final controller = TextEditingController(text: 'x');
      final focus = FocusNode();
      var clears = 0, changes = 0;
      await tester.pumpWidget(
        host(
          BusyDataSearchField(
            controller: controller,
            focusNode: focus,
            hintText: 'Search',
            onClear: () {
              clears++;
              controller.clear();
            },
            onChanged: (_) => changes++,
          ),
        ),
      );
      await tester.tap(find.byTooltip('Clear text'));
      await tester.pump();
      expect(clears, 1);
      expect(changes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.text = 'still owned';
      expect(focus.canRequestFocus, isTrue);
      controller.dispose();
      focus.dispose();
    },
  );
}
