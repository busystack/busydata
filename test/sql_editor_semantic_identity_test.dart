import 'dart:ui' as ui;
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:busydata/src/ui/common/accessibility_text_geometry.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'support/sql_editor_fixture.dart';

void main() {
  for (final language in ['en', 'de', 'ar']) {
    for (final readOnly in [false, true]) {
      testWidgets(
        'localized $language title, line and ${readOnly ? 'readonly' : 'editable'} actions share one glyph owner',
        (tester) async {
          final release = retainSqlTestSemantics(tester);
          const source = 'SELECT first;\nSELECT 漢😀;';
          const title = 'public.識別子-مخطط.sql';
          final editor = SqlEditorController.fromText(source);
          editor.selection = const CodeLineSelection.collapsed(
            index: 1,
            offset: 8,
          );
          final focus = FocusNode();
          final vertical = ScrollController(), horizontal = ScrollController();
          final scroll = SqlEditorScrollController(
            verticalScroller: vertical,
            horizontalScroller: horizontal,
          );
          addTearDown(editor.dispose);
          addTearDown(focus.dispose);
          addTearDown(scroll.dispose);
          addTearDown(vertical.dispose);
          addTearDown(horizontal.dispose);
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) => Scaffold(
                  body: MediaQuery(
                    data: const MediaQueryData(disableAnimations: true),
                    child: SizedBox(
                      width: 640,
                      height: 360,
                      child: SqlEditorTestView(
                        controller: editor,
                        focusNode: focus,
                        scrollController: scroll,
                        semanticLabel: strings(context).sqlEditorLabel(title),
                        readOnly: readOnly,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(WorkbenchSqlEditor));
          final l = strings(context);
          final label =
              '${l.sqlEditorLabel(title)}\n${l.sqlVisibleLine(2, 2, 9)}';
          final node = tester.getSemantics(find.bySemanticsLabel(label));
          final data = node.getSemanticsData();
          expect(data.label, label);
          expect(data.value, 'SELECT 漢😀;');
          expect(data.flagsCollection.isTextField, isTrue);
          expect(data.flagsCollection.isReadOnly, readOnly);
          expect(data.flagsCollection.isEnabled, ui.Tristate.isTrue);
          expect(data.hasAction(ui.SemanticsAction.focus), isTrue);
          expect(data.hasAction(ui.SemanticsAction.setSelection), isTrue);
          expect(data.hasAction(ui.SemanticsAction.setText), !readOnly);
          final glyphs = AccessibilityTextGeometry.capture(node)!;
          expect(glyphs['start'], 0);
          expect(glyphs['end'], 11);
          final before = editor.value;
          tester.binding.performSemanticsAction(
            ui.SemanticsActionEvent(
              viewId: tester.view.viewId,
              nodeId: node.id,
              type: ui.SemanticsAction.setText,
              arguments: 'SELECT 2;',
            ),
          );
          await tester.pumpAndSettle();
          if (readOnly) {
            expect(editor.value, same(before));
            expect(editor.text, source);
            expect(editor.canUndo, isFalse);
          } else {
            expect(editor.text, 'SELECT first;\nSELECT 2;');
            editor.undo();
            expectSqlSnapshotRestored(editor.value, before);
            expect(editor.text, source);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          release();
        },
        variant: TargetPlatformVariant.only(TargetPlatform.linux),
      );
    }
  }
}
