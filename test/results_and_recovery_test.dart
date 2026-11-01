import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} grid exposes the actual focused cell during keyboard navigation',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final directory = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-native-grid-'),
        ))!;
        final model = WorkbenchModel(directory)
          ..draftRecovery = false
          ..newDocument();
        final result = rpc.StatementResult(
          resultId: 'native',
          fetchedRows: Int64(2),
          complete: true,
          columns: [rpc.Column(name: 'n', typeName: 'text')],
        );
        model.cache['native:0'] = rpc.Row(values: [rpc.Value(text: '漢😀')]);
        model.cache['native:1'] = rpc.Row(values: [rpc.Value(text: 'second')]);
        final view = Center(
          child: SizedBox(
            width: 800,
            height: 400,
            child: ResultGrid(model: model, controls: controls, result: result),
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        final first = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Row 1, n: 漢😀')),
        );
        expect(first.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(
          first.getSemanticsData().flagsCollection.isEnabled,
          ui.Tristate.isTrue,
        );
        expect(
          first.getSemanticsData().hasAction(ui.SemanticsAction.focus),
          isTrue,
        );
        tester.binding.performSemanticsAction(
          ui.SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: first.id,
            type: ui.SemanticsAction.focus,
          ),
        );
        await tester.pump();
        expect(
          first.getSemanticsData().flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        final second = tester.getSemantics(
          find.bySemanticsLabel(RegExp('^Row 2, n: second')),
        );
        expect(
          second.getSemanticsData().flagsCollection.isFocused,
          ui.Tristate.isTrue,
        );
        expect(
          second.getSemanticsData().flagsCollection.isSelected,
          ui.Tristate.isTrue,
        );
        expect(
          first.getSemanticsData().flagsCollection.isFocused,
          ui.Tristate.isFalse,
        );
        expect(
          second.getSemanticsData().label,
          'Row 2, n: second',
          reason: 'The value is announced once',
        );
        expect(model.resultView(result.resultId).selectedRow, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        semantics.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      },
    );
  }
  testWidgets(
    'high contrast renders NULL at full foreground contrast in a retained grid',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busydata-grid-contrast-'),
      ))!;
      final model = WorkbenchModel(directory)
        ..draftRecovery = false
        ..newDocument();
      addTearDown(() async {
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      final result = rpc.StatementResult(
        resultId: 'contrast',
        fetchedRows: Int64(1),
        complete: true,
        columns: [
          rpc.Column(name: 'id'),
          rpc.Column(name: 'nullable_column'),
        ],
      );
      model.cache['contrast:0'] = rpc.Row(
        values: [
          rpc.Value(text: '1'),
          rpc.Value(nullValue: rpc.Null()),
        ],
      );
      Future<void> display(bool contrast) => tester.pumpWidget(
        MaterialApp(
          theme: BusyDataYaruTheme.build(
            brightness: Brightness.light,
            accentColor: const Color(0xFFE95420),
          ),
          home: MediaQuery(
            data: MediaQueryData(highContrast: contrast),
            child: Center(
              child: SizedBox(
                width: 800,
                height: 400,
                child: ResultGrid(
                  model: model,
                  controls: const LinuxControls(),
                  result: result,
                ),
              ),
            ),
          ),
        ),
      );
      final cell = find.descendant(
        of: find.byType(TableView),
        matching: find.text('NULL'),
      );
      await display(false);
      final ordinary = tester.widget<Text>(cell).style!.color!;
      final context = tester.element(cell);
      expect(
        ordinary,
        isNot(const LinuxControls().appearance(context).foreground),
      );
      await display(true);
      expect(
        tester.widget<Text>(cell).style!.color,
        const LinuxControls().appearance(tester.element(cell)).foreground,
      );
      expect(tester.widget<Text>(cell).style!.fontStyle, FontStyle.italic);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
    },
  );
  test(
    'prefilled tabs and tab selection recover without a text edit',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busydata-autorecovery-',
      );
      final model = WorkbenchModel(directory);
      try {
        model.newDocument(text: 'SELECT 1;');
        model.newDocument(text: "SELECT '😀漢';");
        model.select(0);
        final recovery = File('${directory.path}/drafts.json');
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (!await recovery.exists() && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(await recovery.exists(), isTrue);
        final store = DraftStore(directory);
        final documents = await store.load();
        expect(store.restoredSelection, 0);
        expect(documents.map((d) => d.editor.text), [
          'SELECT 1;',
          "SELECT '😀漢';",
        ]);
        expect(documents.every((d) => d.dirty && d.sessionId == null), isTrue);
        for (final document in documents) {
          document.dispose();
        }
        final writes = [model.recoverNow(), model.recoverNow()];
        await Future<void>.delayed(Duration.zero);
        await model.setDraftRecovery(false);
        await Future.wait(writes);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        expect(
          await recovery.exists(),
          isFalse,
          reason: 'Queued writes must not recreate opted-out SQL recovery',
        );
      } finally {
        model.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  testWidgets(
    'million-row grid retains a bounded layout and jumps by global row identity',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busydata-window-'),
      ))!;
      final model = WorkbenchModel(directory)..newDocument();
      addTearDown(() async {
        model.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      final result = rpc.StatementResult(
        resultId: 'million',
        fetchedRows: Int64(1000000),
        limited: true,
        columns: [rpc.Column(name: 'n', typeName: 'bigint')],
      );
      model.cache['million:0'] = rpc.Row(
        values: [rpc.Value(signedInteger: '1')],
      );
      model.cache['million:999999'] = rpc.Row(
        values: [rpc.Value(signedInteger: '1000000')],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: BusyDataYaruTheme.build(
            brightness: Brightness.light,
            accentColor: const Color(0xFFE95420),
          ),
          home: Center(
            child: SizedBox(
              width: 800,
              height: 400,
              child: ResultGrid(
                model: model,
                controls: const LinuxControls(),
                result: result,
              ),
            ),
          ),
        ),
      );
      expect(
        (tester.widget<TableView>(find.byType(TableView)).delegate
                as TableCellBuilderDelegate)
            .rowCount,
        257,
      );
      await tester.tap(find.bySemanticsLabel('Row 1, n: 1'));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(model.resultView(result.resultId).selectedRow, 999999);
      expect(find.bySemanticsLabel('Row 1000000, n: 1000000'), findsOneWidget);
      expect(
        (tester.widget<TableView>(find.byType(TableView)).delegate
                as TableCellBuilderDelegate)
            .rowCount,
        65,
      );
      expect(find.textContaining('999937–1000000'), findsOneWidget);
    },
  );
  test(
    'previous execution results remain selectable after file jobs and disconnection',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busydata-retained-',
      );
      final model = WorkbenchModel(directory)..newDocument();
      try {
        model.track(
          rpc.JobInfo(
            jobId: 'query',
            executionId: 'execution-query',
            sessionId: 'closed-session',
            state: rpc.JobState.COMPLETED,
            results: [
              rpc.StatementResult(resultId: 'retained-result', complete: true),
            ],
          ),
        );
        model.track(
          rpc.JobInfo(
            jobId: 'file',
            executionId: 'execution-file',
            sessionId: 'closed-session',
            state: rpc.JobState.COMPLETED,
          ),
        );
        expect(model.currentResult, isNull);
        model.selectExecution('execution-query');
        expect(model.currentResult!.resultId, 'retained-result');
        expect(model.currentJob!.sessionId, 'closed-session');
        expect(model.session, isNull);
        model.newDocument();
        expect(model.documentJobs, isEmpty);
        model.select(0);
        expect(model.currentResult!.resultId, 'retained-result');
        expect(model.jobs.length, 2);
      } finally {
        model.dispose();
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'drafts recover the selected tab and privacy removes stored SQL',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'busydata-recovery-',
      );
      final model = WorkbenchModel(directory);
      try {
        model.newDocument(text: 'SELECT 1;');
        model.newDocument(text: "SELECT '😀漢';");
        await model.recoverNow();
        final store = DraftStore(directory);
        final restored = await store.load();
        expect(store.restoredSelection, 1);
        expect(restored[1].editor.text, "SELECT '😀漢';");
        expect(restored.every((d) => d.sessionId == null), isTrue);
        for (final document in restored) {
          document.dispose();
        }
        await model.setDraftRecovery(false);
        await model.recoverNow();
        expect(await File('${directory.path}/drafts.json').exists(), isFalse);
        await model.setDraftRecovery(true);
        expect(await File('${directory.path}/drafts.json').exists(), isTrue);
      } finally {
        model.dispose();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets(
    'grid keyboard navigation reveals cells and updates the edit target',
    (tester) async {
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busydata-grid-'),
      ))!;
      final model = WorkbenchModel(directory)..newDocument();
      addTearDown(() async {
        model.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      final result = rpc.StatementResult(
        resultId: 'retained',
        fetchedRows: Int64(100),
        complete: true,
        columns: List.generate(
          10,
          (i) => rpc.Column(name: 'column$i', typeName: 'integer'),
        ),
      );
      for (var row = 0; row < 100; row++) {
        model.cache['retained:$row'] = rpc.Row(
          values: List.generate(
            10,
            (column) => rpc.Value(signedInteger: '$row:$column'),
          ),
        );
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: BusyDataYaruTheme.build(
            brightness: Brightness.light,
            accentColor: const Color(0xFFE95420),
          ),
          home: Center(
            child: SizedBox(
              width: 600,
              height: 400,
              child: ResultGrid(
                model: model,
                controls: const LinuxControls(),
                result: result,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('0:0'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      expect(model.resultView(result.resultId).selectedRow, greaterThan(0));
      await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
      await tester.pump();
      final table = tester.widget<TableView>(find.byType(TableView));
      expect(table.verticalDetails.controller!.offset, greaterThan(0));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(model.resultView(result.resultId).selectedRow, 99);
      expect(table.horizontalDetails.controller!.offset, greaterThan(0));
      expect(find.text('99:9'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('column9 · integer'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
