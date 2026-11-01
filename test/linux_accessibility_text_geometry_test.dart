import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/ui/common/accessibility_text_geometry.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'support/sql_editor_fixture.dart';

Widget geometrySurface(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      disableAnimations: true,
      highContrast: true,
    ),
    child: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(width: 640, height: 360, child: child),
        ),
      ),
    ),
  ),
);

SemanticsNode nativeLine(WidgetTester tester) =>
    tester.getSemantics(find.bySemanticsLabel(RegExp('Visible SQL line')));

Rect glyphRect(Map<String, Object?> box) {
  final rect = (box['rect']! as List).cast<double>();
  return Rect.fromLTWH(rect[0], rect[1], rect[2], rect[3]);
}

List<Map<String, Object?>> glyphs(Map<String, Object?> geometry) =>
    (geometry['boxes']! as List).cast<Map<String, Object?>>();

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'native glyph ranges retain Unicode and actual layout in ${direction.name} at $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 800));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final release = retainSqlTestSemantics(tester);
          final editor = SqlEditorController.fromText('😀日abc');
          final scroll = SqlEditorScrollController();
          addTearDown(editor.dispose);
          addTearDown(scroll.dispose);
          await tester.pumpWidget(
            geometrySurface(
              SqlEditorTestView(controller: editor, scrollController: scroll),
              direction: direction,
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final before = editor.value;
          final node = nativeLine(tester);
          final observed = AccessibilityTextGeometry.capture(node)!;
          expect(observed['start'], 0);
          expect(observed['end'], 6);
          final boxes = glyphs(observed);
          expect(boxes.map((box) => (box['start'], box['end'])), [
            (0, 2),
            (2, 3),
            (3, 4),
            (4, 5),
            (5, 6),
          ]);
          final first = glyphRect(boxes[0]), second = glyphRect(boxes[1]);
          expect(first, isNot(second));
          final bounds = scroll.geometry.viewport!;
          for (final box in boxes) {
            final rect = glyphRect(box);
            expect(rect.isFinite && !rect.isEmpty, isTrue);
            expect(rect.intersect(bounds), rect);
            expect(rect.width, lessThan(bounds.width));
          }
          // A whole-field rectangle cannot satisfy actual independent glyph
          // hit testing or the surrogate-safe UTF-16 range above.
          final paragraph = scroll.geometry.paragraphs.single;
          final point = second.center - bounds.topLeft - paragraph.offset;
          final hit = paragraph.getPosition(point);
          expect(hit.index, 0);
          expect(hit.offset, anyOf(2, 3));
          expect(editor.value, same(before));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          expect(AccessibilityTextGeometry.capture(node), isNull);
          release();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
      );
    }
  }

  testWidgets('text and scroll invalidate old geometry before the next frame', (
    tester,
  ) async {
    final release = retainSqlTestSemantics(tester);
    final editor = SqlEditorController.fromText(
      List.generate(80, (index) => '😀日${'column' * 80}$index').join('\n'),
    );
    final scroll = SqlEditorScrollController();
    addTearDown(editor.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      geometrySurface(
        SqlEditorTestView(
          controller: editor,
          scrollController: scroll,
          wordWrap: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    editor.selection = const CodeLineSelection.collapsed(index: 4, offset: 40);
    await tester.pumpAndSettle();
    final original = nativeLine(tester);
    expect(AccessibilityTextGeometry.capture(original), isNotNull);
    scroll.horizontalScroller.jumpTo(80);
    expect(AccessibilityTextGeometry.capture(original), isNull);
    await tester.pumpAndSettle();
    expect(scroll.horizontalScroller.offset, 80);
    final current = nativeLine(tester);
    final scrolled = AccessibilityTextGeometry.capture(current)!;
    expect(
      glyphs(scrolled).every((box) => (box['start']! as int) > 2),
      isTrue,
      reason:
          'Only actual visible glyphs: scroll=${scroll.horizontalScroller.offset}, '
          'viewport=${scroll.geometry.viewport}, '
          'paragraph=${scroll.geometry.paragraphs.first.offset}, '
          'boxes=${glyphs(scrolled).take(3).toList()}',
    );
    final beforeVertical = glyphRect(glyphs(scrolled).first);
    final selected = editor.selection;
    scroll.verticalScroller.jumpTo(30);
    expect(AccessibilityTextGeometry.capture(current), isNull);
    await tester.pumpAndSettle();
    expect(scroll.verticalScroller.offset, 30);
    expect(scroll.horizontalScroller.offset, 80);
    final afterVertical = glyphRect(
      glyphs(AccessibilityTextGeometry.capture(nativeLine(tester))!).first,
    );
    expect(afterVertical.top, closeTo(beforeVertical.top - 30, .01));
    expect(afterVertical.left, closeTo(beforeVertical.left, .01));
    expect(editor.selection, selected);
    editor.text = 'replacement';
    expect(AccessibilityTextGeometry.capture(current), isNull);
    await tester.pumpAndSettle();
    expect(AccessibilityTextGeometry.capture(nativeLine(tester))!['end'], 11);
    await tester.pumpWidget(const SizedBox.shrink());
    release();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets('controller and scroll rebind retire exact native glyph owners', (
    tester,
  ) async {
    final release = retainSqlTestSemantics(tester);
    final first = SqlEditorController.fromText('😀日');
    final second = SqlEditorController.fromText('second');
    final firstScroll = SqlEditorScrollController();
    final secondScroll = SqlEditorScrollController();
    for (final editor in [first, second]) {
      addTearDown(editor.dispose);
    }
    for (final scroll in [firstScroll, secondScroll]) {
      addTearDown(scroll.dispose);
    }
    Future<void> display(bool next) => tester.pumpWidget(
      geometrySurface(
        SqlEditorTestView(
          key: const ValueKey('same-mounted-editor'),
          controller: next ? second : first,
          scrollController: next ? secondScroll : firstScroll,
        ),
      ),
    );
    await display(false);
    await tester.pumpAndSettle();
    final old = nativeLine(tester);
    expect(AccessibilityTextGeometry.capture(old)!['end'], 3);
    await display(true);
    await tester.pumpAndSettle();
    final current = nativeLine(tester);
    expect(current.id, isNot(old.id));
    expect(AccessibilityTextGeometry.capture(old), isNull);
    expect(AccessibilityTextGeometry.capture(current)!['end'], 6);
    expect(first.text, '😀日');
    expect(second.text, 'second');
    expect(firstScroll.geometry.current, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    release();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));
}
