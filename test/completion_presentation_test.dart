import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_completion.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/ui/common/sql_presentation.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/presentation_fonts.dart';
import 'support/sql_editor_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPresentationFonts);
  for (final single in [false, true]) {
    testWidgets(
      single
          ? 'single completion fits its candidate without reserving empty rows'
          : 'large-font completion keeps its selected long candidate inside the editor viewport',
      (tester) async {
        const controls = LinuxControls();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('completion-presentation-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: 'sel');
        model.document.selectOffsets(3, 3);
        final scroll = SqlEditorScrollController();
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          scroll.dispose();
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        const viewport = ValueKey('completion-viewport');
        await tester.pumpWidget(
          presentationHost(
            Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                key: viewport,
                width: 420,
                height: 180,
                child: WorkbenchCompletion(
                  model: model,
                  document: model.document,
                  controls: controls,
                  scrollController: scroll,
                  child: Builder(
                    builder: (context) => SqlEditorTestView(
                      controller: model.document.editor,
                      scrollController: scroll,
                      autofocus: true,
                      style: sqlEditorStyle(context, controls),
                    ),
                  ),
                ),
              ),
            ),
            fontSize: 18,
            scale: 2,
          ),
        );
        await tester.pumpAndSettle();
        final pending = model.analyze(model.document);
        await tester.pump();
        backend.client.completeAnalysis(
          backend.client.analyses.length - 1,
          completions: [
            for (var i = 0; i < (single ? 1 : 40); i++)
              rpc.Completion(
                label: single
                    ? 'coalesce()'
                    : 'Candidate $i with a long qualified database object name',
                insertText: 'candidate_$i',
                startUtf16: 0,
                endUtf16: 3,
              ),
          ],
        );
        await pending;
        await tester.pumpAndSettle();
        for (var i = 0; i < (single ? 1 : 12); i++) {
          final selected = find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.selected == true,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Material &&
                  widget.elevation == BusyDataElevation.surface,
            ),
            findsWidgets,
          );
          expect(selected, findsOneWidget);
          final editor = tester.getRect(find.byKey(viewport));
          final row = tester.getRect(selected);
          expect(editor.contains(row.topLeft), isTrue);
          expect(
            editor.contains(row.bottomRight - const Offset(.01, .01)),
            isTrue,
            reason: 'Selected row $row must fit editor viewport $editor',
          );
          if (single) {
            final popup = tester.getRect(
              find.byKey(const ValueKey('sql-completion-popup')),
            );
            expect(popup.height, lessThan(row.height * 2));
            expect(popup.contains(row.topLeft), isTrue);
            expect(
              popup.contains(row.bottomRight - const Offset(.01, .01)),
              isTrue,
            );
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
        }
        expect(model.document.editor.text, 'sel');
        expect(backend.client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
