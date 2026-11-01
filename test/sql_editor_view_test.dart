import 'dart:ui' as ui;
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'support/sql_editor_fixture.dart';

SemanticsConfiguration sqlSemantics(WidgetTester tester) {
  final render = tester.allRenderObjects
      .whereType<RenderSemanticsAnnotations>()
      .toSet()
      .where(
        (render) =>
            render.properties.label?.startsWith('Visible SQL line') == true,
      )
      .single;
  final configuration = SemanticsConfiguration();
  render.describeSemanticsConfiguration(configuration);
  return configuration;
}

SqlEditorScrollController ownedScroll() {
  final vertical = ScrollController(), horizontal = ScrollController();
  final scroll = SqlEditorScrollController(
    verticalScroller: vertical,
    horizontalScroller: horizontal,
  );
  addTearDown(() {
    scroll.dispose();
    vertical.dispose();
    horizontal.dispose();
  });
  return scroll;
}

Widget surface(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  double scale = 1,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(scale),
      highContrast: true,
      disableAnimations: true,
    ),
    child: Directionality(
      textDirection: direction,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(width: 640, height: 360, child: child),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final key in [LogicalKeyboardKey.backspace, LogicalKeyboardKey.delete]) {
    testWidgets(
      'native CRLF-interior caret and ${key.keyLabel} delete only the separator',
      (tester) async {
        final editor = SqlEditorController.fromText('a\r\nbc');
        final focus = FocusNode();
        addTearDown(editor.dispose);
        addTearDown(focus.dispose);
        final scroll = ownedScroll();
        editor.selectOffsets(0, 5);
        await tester.pumpWidget(
          surface(
            SqlEditorTestView(
              controller: editor,
              scrollController: scroll,
              focusNode: focus,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.testTextInput.hasAnyClients, isTrue);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: 'a\r\nbc',
            selection: TextSelection.collapsed(offset: 2),
          ),
        );
        await tester.pump();
        expect(editor.offsetForPosition(editor.selection.extent), 2);
        await tester.sendKeyEvent(key);
        await tester.pump();
        expect(editor.text, 'abc');
        expect(editor.offsetForPosition(editor.selection.extent), 1);
        expect(tester.testTextInput.editingState!['text'], 'abc');
        editor.undo();
        await tester.pump();
        expect(editor.text, 'a\r\nbc');
        expect(editor.offsetForPosition(editor.selection.extent), 2);
        expect(tester.testTextInput.editingState!['text'], 'a\r\nbc');
        editor.redo();
        await tester.pump();
        expect(editor.text, 'abc');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant({
        TargetPlatform.linux,
        TargetPlatform.windows,
      }),
    );
  }

  testWidgets(
    'captured semantic callbacks cannot edit or focus a rebound editor owner',
    (tester) async {
      final releaseSemantics = retainSqlTestSemantics(tester);
      final first = SqlEditorController.fromText('SELECT first;');
      final second = SqlEditorController.fromText('SELECT second;');
      final firstFocus = FocusNode(),
          secondFocus = FocusNode(),
          other = FocusNode();
      for (final editor in [first, second]) {
        addTearDown(editor.dispose);
      }
      for (final focus in [firstFocus, secondFocus, other]) {
        addTearDown(focus.dispose);
      }
      final scroll = ownedScroll();
      Future<void> display(bool rebound) => tester.pumpWidget(
        surface(
          Column(
            children: [
              Expanded(
                child: SqlEditorTestView(
                  key: const ValueKey('same-editor-state'),
                  controller: rebound ? second : first,
                  scrollController: scroll,
                  focusNode: rebound ? secondFocus : firstFocus,
                ),
              ),
              TextField(focusNode: rebound ? firstFocus : other),
            ],
          ),
        ),
      );
      await display(false);
      await tester.pumpAndSettle();
      final oldNodeId = tester
          .getSemantics(find.bySemanticsLabel(RegExp('Visible SQL line')))
          .id;
      final actions = sqlSemantics(tester);
      final text = actions.getActionHandler(ui.SemanticsAction.setText)!;
      final selection = actions.getActionHandler(
        ui.SemanticsAction.setSelection,
      )!;
      final focus = actions.getActionHandler(ui.SemanticsAction.focus)!;
      final tap = actions.getActionHandler(ui.SemanticsAction.tap)!;
      final firstBefore = first.value, secondBefore = second.value;
      await display(true);
      secondFocus.requestFocus();
      await tester.pumpAndSettle();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel(RegExp('Visible SQL line')))
            .id,
        isNot(oldNodeId),
        reason:
            'A different document must retire the old native text-node identity',
      );
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: oldNodeId,
          type: ui.SemanticsAction.setText,
          arguments: 'retired native event',
        ),
      );
      text('stale replacement');
      selection({'base': 1, 'extent': 4});
      focus(null);
      tap(null);
      await tester.pump();
      expect(first.value, same(firstBefore));
      expect(second.value, same(secondBefore));
      expect(secondFocus.hasFocus, isTrue);
      expect(
        firstFocus.hasFocus,
        isFalse,
        reason:
            'A captured action must not focus its old node after that node belongs to another control',
      );
      expect(
        tester
            .widget<WorkbenchSqlEditor>(find.byType(WorkbenchSqlEditor))
            .controller,
        same(second),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      releaseSemantics();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'captured writable semantics cannot bypass a read-only view change',
    (tester) async {
      final releaseSemantics = retainSqlTestSemantics(tester);
      final editor = SqlEditorController.fromText('SELECT exact;');
      addTearDown(editor.dispose);
      Future<void> display(bool readOnly) => tester.pumpWidget(
        surface(SqlEditorTestView(controller: editor, readOnly: readOnly)),
      );
      await display(false);
      await tester.pumpAndSettle();
      final replace = sqlSemantics(
        tester,
      ).getActionHandler(ui.SemanticsAction.setText)!;
      final before = editor.value;
      await display(true);
      await tester.pumpAndSettle();
      expect(
        sqlSemantics(tester).getActionHandler(ui.SemanticsAction.setText),
        isNull,
      );
      replace('not admitted');
      expect(editor.value, same(before));
      expect(editor.canUndo, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      releaseSemantics();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'captured native semantic actions cannot interrupt current IME composition',
    (tester) async {
      final releaseSemantics = retainSqlTestSemantics(tester);
      final editor = SqlEditorController.fromText('SELECT exact;');
      addTearDown(editor.dispose);
      await tester.pumpWidget(surface(SqlEditorTestView(controller: editor)));
      await tester.pumpAndSettle();
      final previous = sqlSemantics(tester);
      final replace = previous.getActionHandler(ui.SemanticsAction.setText)!;
      final select = previous.getActionHandler(
        ui.SemanticsAction.setSelection,
      )!;
      editor.composing = const TextRange(start: 1, end: 3);
      final composing = editor.value;
      await tester.pumpAndSettle();
      expect(
        sqlSemantics(tester).getActionHandler(ui.SemanticsAction.setText),
        isNull,
      );
      final currentSelection = sqlSemantics(
        tester,
      ).getActionHandler(ui.SemanticsAction.setSelection);
      currentSelection?.call({'base': 0, 'extent': 1});
      replace('not admitted');
      select({'base': 0, 'extent': 1});
      expect(editor.value, same(composing));
      expect(editor.isComposing, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      releaseSemantics();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  for (final direction in TextDirection.values) {
    testWidgets(
      'native SQL preview keeps a boundary emoji intact in ${direction.name}',
      (tester) async {
        final releaseSemantics = retainSqlTestSemantics(tester);
        final source = '${'x' * 16383}😀 suffix';
        final editor = SqlEditorController.fromText(source);
        addTearDown(editor.dispose);
        final before = editor.value;
        await tester.pumpWidget(
          surface(SqlEditorTestView(controller: editor), direction: direction),
        );
        await tester.pumpAndSettle();
        final data = tester
            .getSemantics(find.bySemanticsLabel(RegExp('Visible SQL line')))
            .getSemanticsData();
        expect(data.value, 'x' * 16383);
        expect(data.label, contains('preview'));
        expect(data.hasAction(ui.SemanticsAction.setText), isFalse);
        expect(editor.value, same(before));
        expect(editor.text, source);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        releaseSemantics();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );

    testWidgets(
      'rendered scroll coordinates and popup anchors stay exact in ${direction.name}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final source = List.generate(
          180,
          (index) => 'SELECT ${'long_column_' * 30}$index;',
        ).join('\n');
        final editor = SqlEditorController.fromText(source);
        addTearDown(editor.dispose);
        final scroll = ownedScroll();
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          surface(
            SqlEditorTestView(
              controller: editor,
              scrollController: scroll,
              focusNode: focus,
              wordWrap: false,
            ),
            direction: direction,
            scale: 2,
          ),
        );
        final settled = await tester.pumpAndSettle(
          const Duration(milliseconds: 16),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 2),
        );
        expect(
          settled,
          lessThan(20),
          reason:
              'Binding immutable layout must not schedule an endless frame loop',
        );
        focus.requestFocus();
        editor.selection = const CodeLineSelection.collapsed(
          index: 4,
          offset: 10,
        );
        await tester.pumpAndSettle();
        scroll.verticalScroller.jumpTo(45);
        scroll.horizontalScroller.jumpTo(30);
        expect(scroll.geometry.current, isFalse);
        expect(
          scroll.geometry.contextMenuAnchor(
            const CodeLinePosition(index: 4, offset: 20),
          ),
          isNull,
        );
        await tester.pumpAndSettle();
        final geometry = scroll.geometry;
        expect(geometry.current, isTrue);
        const target = CodeLinePosition(index: 4, offset: 20);
        final caret = geometry.caret(target);
        expect(caret, isNotNull);
        final viewport = geometry.viewport!;
        expect(viewport.contains(caret!.center), isTrue);
        final offsets = (
          scroll.verticalScroller.offset,
          scroll.horizontalScroller.offset,
        );
        final selection = editor.selection;
        final anchor = geometry.contextMenuAnchor(target)!;
        expect(viewport.contains(anchor), isTrue);
        expect(anchor.dx, closeTo(caret.left, 0.01));
        expect(anchor.dy, closeTo(caret.bottom, 0.01));
        expect((
          scroll.verticalScroller.offset,
          scroll.horizontalScroller.offset,
        ), offsets);
        expect(editor.selection, selection);
        await tester.tapAt(caret.center);
        await tester.pumpAndSettle();
        expect(editor.selection.extentIndex, 4);
        expect(
          editor.selection.extentOffset,
          20,
          reason:
              'The owned geometry must identify the same glyph as the actual upstream pointer hit test',
        );
        expect(editor.text, source);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  testWidgets(
    'scroll owner replacement detaches prior layout and focus observations',
    (tester) async {
      final editor = SqlEditorController.fromText('SELECT one;\nSELECT two;');
      addTearDown(editor.dispose);
      final first = ownedScroll(), second = ownedScroll();
      Future<void> display(SqlEditorScrollController scroll) =>
          tester.pumpWidget(
            surface(
              SqlEditorTestView(
                key: const ValueKey('same-editor-state'),
                controller: editor,
                scrollController: scroll,
              ),
            ),
          );
      await display(first);
      await tester.pumpAndSettle();
      expect(first.geometry.current, isTrue);
      final before = editor.value;
      await display(second);
      await tester.pumpAndSettle();
      expect(first.geometry.current, isFalse);
      expect(first.geometry.viewport, isNull);
      expect(first.geometry.focusEditor, isNull);
      expect(
        first.contextMenuAnchor(const CodeLinePosition(index: 0, offset: 2)),
        isNull,
      );
      expect(second.geometry.current, isTrue);
      expect(
        second.geometry.caret(const CodeLinePosition(index: 0, offset: 2)),
        isNotNull,
      );
      expect(editor.value, same(before));
      final settled = await tester.pumpAndSettle(
        const Duration(milliseconds: 16),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 1),
      );
      expect(settled, lessThan(12));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
}
