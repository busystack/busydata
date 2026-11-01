import 'dart:io';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'support/fake_backend.dart';

void main() {
  for (final secondary in [false, true]) {
    testWidgets(
      'stale caret completion popup disappears immediately after ${secondary ? 'secondary selection' : 'caret'} changes',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-completion-strip-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)..draftRecovery = false;
        model.newDocument(text: 'select 1;');
        model.backend = backend;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.binding.setSurfaceSize(const Size(1400, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: BusyDataYaruTheme.build(
              brightness: Brightness.light,
              accentColor: const Color(0xFFE95420),
            ),
            home: WorkbenchView(model: model, controls: const LinuxControls()),
          ),
        );
        final pending = model.analyze(model.document);
        backend.client.completeAnalysis(
          0,
          completions: [
            Completion(label: 'Bound completion', insertText: 'SELECT'),
          ],
        );
        await pending;
        await tester.pump();
        await tester.pump();
        expect(find.text('Bound completion'), findsOneWidget);
        if (secondary) {
          model.document.editor.setExtraSelections([
            const CodeLineSelection.collapsed(index: 0, offset: 2),
          ]);
        } else {
          model.document.selectOffsets(2, 2);
        }
        await tester.pump();
        expect(model.acceptedAnalysis, isNull);
        expect(find.text('Bound completion'), findsNothing);
        expect(model.document.editor.text, 'select 1;');
        model.invalidateAnalysis();
      },
    );
  }
  for (final switchTab in [true, false]) {
    testWidgets(
      'format action does not borrow accepted analysis after ${switchTab ? 'tab switch' : 'edit'}',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-format-action-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)..draftRecovery = false;
        model.newDocument(text: 'select 1;');
        model.backend = backend;
        final target = model.document;
        await tester.binding.setSurfaceSize(const Size(1400, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: BusyDataYaruTheme.build(
              brightness: Brightness.light,
              accentColor: const Color(0xFFE95420),
            ),
            home: WorkbenchView(model: model, controls: const LinuxControls()),
          ),
        );
        final dynamic state = tester.state(find.byType(WorkbenchView));
        final Future<void> formatting = state.formatSql();
        if (switchTab) {
          model.newDocument(text: 'select 2;');
        } else {
          target.editor.text = 'select 2;';
        }
        final newer = model.analyze(model.document);
        await tester.pump();
        expect(backend.client.cancelledAnalyses, greaterThanOrEqualTo(1));
        expect(backend.client.analyses, hasLength(2));
        backend.client.completeAnalysis(1, formatted: 'SELECT 2;');
        await newer;
        backend.client.completeAnalysis(0, formatted: 'SELECT 1;');
        await tester.pump();
        final borrowed = find.text(
          'Review details · Format SQL · ${target.title}',
        );
        final borrowedDialogWasShown = borrowed.evaluate().isNotEmpty;
        if (borrowed.evaluate().isNotEmpty) {
          Navigator.of(tester.element(borrowed)).pop(false);
          await tester.pump();
        }
        await formatting;
        expect(borrowedDialogWasShown, isFalse);
        expect(model.status, contains('Original SQL preserved'));
        expect(model.document.editor.text, 'select 2;');
        if (switchTab) expect(target.editor.text, 'select 1;');
        expect(tester.takeException(), isNull);
        model.invalidateAnalysis();
      },
    );
  }
}
