import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/workbench_sql_search.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixnum/fixnum.dart';
import 'support/fake_backend.dart';

void main() {
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} first output and search preserve mounted editor, focus, SQL and undo',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('editor-output-lifecycle-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument(text: "SELECT '漢😀';\r\nSELECT 1;");
        var disposed = false;
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          if (!disposed) model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        final owner = model.activeOwner, document = model.document;
        final original = document.editor.text;
        document.editor.selectAll();
        document.editor.replaceSelection("SELECT '漢😀';\r\nSELECT 2;");
        await tester.pumpAndSettle();
        await tester.tap(find.byType(CodeEditor));
        await tester.pumpAndSettle();
        final mountedEditor = tester.state(find.byType(CodeEditor));
        final focused = FocusManager.instance.primaryFocus;
        final value = document.editor.value;
        model.track(
          rpc.JobInfo(
            jobId: 'first',
            executionId: 'first',
            state: rpc.JobState.COMPLETED,
            messages: ['Statement completed'],
          ),
          documentId: owner.id,
        );
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CodeEditor)), same(mountedEditor));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('workbench-operation-status')),
              )
              .data,
          'Completed · 0 ms',
        );
        model.openTask(
          WorkbenchDocumentKind.administration,
          'Connection overview',
          activate: false,
        );
        model.updateStatus('Connection overview');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('workbench-operation-status')),
              )
              .data,
          'Completed · 0 ms',
        );
        expect(model.status, 'Connection overview');
        model.updateStatus(
          'Submitted · cancellation does not undo acknowledged commits or published files',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('workbench-operation-status')),
              )
              .data,
          'Completed · 0 ms',
        );
        expect(FocusManager.instance.primaryFocus, same(focused));
        expect(document.editor.value, value);
        expect(find.text('Messages'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CodeEditor)), same(mountedEditor));
        expect(document.editor.value, value);
        expect(tester.takeException(), isNull);
        final fields = find.byWidgetPredicate(
          (w) => w is EditableText && !w.readOnly,
        );
        expect(
          tester
              .widget<SearchHeaderField>(find.byType(SearchHeaderField))
              .focusNode
              .hasFocus,
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(CodeEditor)), same(mountedEditor));
        expect(FocusManager.instance.primaryFocus, same(focused));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<SearchHeaderField>(find.byType(SearchHeaderField))
              .focusNode
              .hasFocus,
          isTrue,
        );
        final replacing = tester.state<WorkbenchSqlSearchState>(
          find.byType(WorkbenchSqlSearch),
        );
        final replacementField = find.byWidgetPredicate(
          (widget) =>
              widget is EditableText &&
              identical(widget.controller, replacing.replacement),
        );
        await tester.enterText(replacementField, 'replacement');
        expect(document.editor.value, value);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(fields, findsNothing);
        expect(tester.state(find.byType(CodeEditor)), same(mountedEditor));
        expect(FocusManager.instance.primaryFocus, same(focused));
        document.editor.undo();
        await tester.pumpAndSettle();
        expect(document.editor.text, original);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        disposed = true;
      },
    );
  }

  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} background completion preserves historical output, focused cell and owner',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('output-focus-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)..draftRecovery = false;
        model.newDocument(text: 'SELECT a;');
        model.backend = backend;
        final a = model.activeOwner;
        model.newDocument(text: 'SELECT b;');
        final b = model.activeOwner;
        rpc.StatementResult result(String id) => rpc.StatementResult(
          resultId: id,
          fetchedRows: Int64(2),
          complete: true,
          columns: [rpc.Column(name: 'value', typeName: 'integer')],
        );
        final old = rpc.JobInfo(
          jobId: 'old-a',
          executionId: 'old-a',
          state: rpc.JobState.COMPLETED,
          results: [result('old-result')],
        );
        final newer = rpc.JobInfo(
          jobId: 'new-a',
          executionId: 'new-a',
          state: rpc.JobState.COMPLETED,
          results: [result('new-result')],
        );
        final background = rpc.JobInfo(
          jobId: 'b-job',
          executionId: 'b-execution',
          state: rpc.JobState.EXECUTING,
          results: [result('b-result')],
        );
        model.track(old, documentId: a.id);
        model.track(newer, documentId: a.id);
        model.track(background, documentId: b.id);
        model.activateOwner(a.id);
        model.selectExecution('old-a');
        for (final r in [
          old.results.single,
          newer.results.single,
          background.results.single,
        ]) {
          model.cache['${r.resultId}:0'] = rpc.Row(
            values: [rpc.Value(signedInteger: '101')],
          );
          model.cache['${r.resultId}:1'] = rpc.Row(
            values: [rpc.Value(signedInteger: '202')],
          );
        }
        backend.client.retained = rpc.RetainedList(
          complete: true,
          results: [
            for (final job in [old, newer, background])
              rpc.RetainedResult(
                jobId: job.jobId,
                executionId: job.executionId,
                documentId: job == background ? b.id : a.id,
                result: job.results.single,
              ),
          ],
        );
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        final backgroundTab = find.byKey(ValueKey('document-tab:${b.id}'));
        expect(tester.getSemantics(backgroundTab).label, contains('Running'));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('workbench-operation-status')),
              )
              .data,
          'Showing a retained execution; SQL was not rerun',
        );
        final cell = find.byKey(const ValueKey('old-result:1:0'));
        await tester.tap(cell);
        await tester.pump();
        final focus = FocusManager.instance.primaryFocus;
        backend.client.jobList = rpc.JobList(
          complete: true,
          catalogRevision: Int64(2),
          jobs: [
            old,
            newer,
            background.deepCopy()..state = rpc.JobState.COMPLETED,
          ],
        );
        await tester.runAsync(() async {
          await model.poll();
          await Future<void>.delayed(const Duration(milliseconds: 110));
        });
        expect(model.jobs['b-job']!.state, rpc.JobState.COMPLETED);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('workbench-operation-status')),
              )
              .data,
          'Showing a retained execution; SQL was not rerun',
        );
        expect(model.activeOwner, same(a));
        expect(model.selectedExecutions[a.id], 'old-a');
        expect(model.currentResult!.resultId, 'old-result');
        expect(model.resultView(model.displayResult!.resultId).selectedRow, 1);
        expect(FocusManager.instance.primaryFocus, same(focus));
        expect(cell, findsOneWidget);
        expect(model.jobDocuments['b-job'], b.id);
        expect(tester.getSemantics(backgroundTab).label, contains('Completed'));
        expect(
          tester.getSemantics(backgroundTab).label,
          isNot(contains('Running')),
        );
        expect(backend.client.executions, isEmpty);
        semantics.dispose();
      },
    );
  }
}
