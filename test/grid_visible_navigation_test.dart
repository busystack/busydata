import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/connection_widgets.dart';
import 'support/native_window.dart';

Future<void> key(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
}) async {
  await tester.pump();
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Home and End select visible underlying columns with hidden edges',
    (tester) async {
      final f = await GridFixture.create(tester);
      final view = f.model.resultView(f.result.resultId)
        ..hiddenColumns.addAll([0, 3]);
      await f.mount(tester);
      f.focus(tester);
      await key(tester, LogicalKeyboardKey.end);
      expect(view.selectedColumn, 2);
      await key(tester, LogicalKeyboardKey.home);
      expect(view.selectedColumn, 1);
      await key(tester, LogicalKeyboardKey.end, control: true, shift: true);
      expect(
        (view.selectedRow, view.selectedColumn, view.anchorColumn),
        (1, 2, 1),
      );
      await key(tester, LogicalKeyboardKey.home, control: true, shift: true);
      expect(
        (view.selectedRow, view.selectedColumn, view.anchorColumn),
        (0, 1, 1),
      );
      await key(tester, LogicalKeyboardKey.end, shift: true);
      await key(tester, LogicalKeyboardKey.keyC, control: true);
      expect(f.clipboard.single, '0:1\t0:2');
      expect(f.backend.client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'hiding the selected and anchor columns normalizes copy inspect and edit',
    (tester) async {
      installNativeWindowFixture(tester);
      final f = await GridFixture.create(tester);
      final view = f.model.resultView(f.result.resultId)
        ..selectedColumn = 1
        ..anchorColumn = 0;
      await f.mount(tester);
      final dialog = f.model.resultActions[f.owner.id]!['result.columns']!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('column1').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('column0').last);
      await tester.pumpAndSettle();
      expect((view.selectedColumn, view.anchorColumn), (2, 2));
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await dialog;
      f.focus(tester);
      await key(tester, LogicalKeyboardKey.keyC, control: true);
      expect(f.clipboard.single, '0:2');
      final inspect = f.model.resultActions[f.owner.id]!['result.inspect']!();
      await tester.pumpAndSettle();
      expect(find.text('0:2'), findsWidgets);
      expect(find.text('column2 · text'), findsOneWidget);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await inspect;
      await f.model.resultActions[f.owner.id]!['result.assess']!();
      await tester.pumpAndSettle();
      f.focus(tester);
      await key(tester, LogicalKeyboardKey.f2);
      final editor = find.byType(EditableText);
      expect(tester.widget<EditableText>(editor).controller.text, '0:2');
      await tester.enterText(editor, 'exact revised value');
      await key(tester, LogicalKeyboardKey.enter);
      final change = f.model
          .batchFor(f.owner, f.result.resultId)
          .changes
          .single;
      expect(change.sourceRow, Int64.ZERO);
      expect(change.values.keys.single, 3); // Protocol ordinals are one-based.
      expect(change.values.values.single.value.text, 'exact revised value');
      expect(f.backend.client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disjoint visible SQL spans retain backend serialization and exclude hidden values',
    (tester) async {
      final f = await GridFixture.create(tester);
      f.model.resultView(f.result.resultId)
        ..hiddenColumns.add(1)
        ..anchorColumn = 0
        ..selectedColumn = 3
        ..selectedRow = 1;
      f.backend.client.sqlCopy = (request) async => rpc.CopySqlReply(
        text: request.firstColumn == 0
            ? "('0:0'),\n('1:0')"
            : "('0:2', decode('abcd', 'hex')),\n('1:2', '漢字')",
      );
      await f.mount(tester);
      const menus = MethodChannel('busydata/native_menus');
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(menus, (call) async {
        if (call.method != 'show') return null;
        final entries = flattenNativeMenu(
          (call.arguments as Map)['entries'] as List,
        );
        final index = entries.indexWhere(
          (entry) => entry['label'] == 'Copy SQL values',
        );
        expect(index, greaterThanOrEqualTo(0));
        return index;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(menus, null));
      await tester.tap(find.bySemanticsLabel('Data grid'));
      await tester.pumpAndSettle();
      expect(
        f.backend.client.sqlCopyRequests.map(
          (r) => (r.firstColumn, r.columnCount, r.firstRow, r.rowCount),
        ),
        [(0, 1, Int64.ZERO, 2), (2, 2, Int64.ZERO, 2)],
      );
      expect(
        f.clipboard.single,
        "('0:0', '0:2', decode('abcd', 'hex')),\n('1:0', '1:2', '漢字')",
      );
      expect(f.backend.client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'zero and delayed metadata retain intent without indexing unavailable cells',
    (tester) async {
      final f = await GridFixture.create(tester, metadata: false, rows: 0);
      final view = f.model.resultView(f.result.resultId)
        ..hiddenColumns.addAll([0, 3])
        ..selectedColumn = 3
        ..anchorColumn = 1;
      await f.mount(tester);
      f.focus(tester);
      for (final k in [
        LogicalKeyboardKey.home,
        LogicalKeyboardKey.end,
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.f2,
      ]) {
        await key(tester, k, control: k == LogicalKeyboardKey.keyC);
      }
      expect(view.selectedColumn, 3);
      expect(f.clipboard, isEmpty);
      f.result = f.result.deepCopy()..columns.addAll(GridFixture.columns());
      await f.mount(tester);
      expect((view.selectedColumn, view.anchorColumn), (2, 1));
      expect(view.selectedRow, 0);
      expect(tester.takeException(), isNull);
      expect(f.backend.client.executions, isEmpty);
    },
  );

  test(
    'SQL tuple splitting respects quoted delimiters escapes functions and Unicode',
    () {
      expect(
        splitGeneratedSqlCopyRows(
          r"('a),(''b', CONVERT('c\\d', CHAR)), (decode('00ff', 'hex'), '漢字')",
        ),
        [r"'a),(''b', CONVERT('c\\d', CHAR)", "decode('00ff', 'hex'), '漢字'"],
      );
      expect(
        () => splitGeneratedSqlCopyRows("('unterminated)"),
        throwsFormatException,
      );
      expect(
        () => splitGeneratedSqlCopyRows('(1),garbage'),
        throwsFormatException,
      );
    },
  );
}

class GridFixture {
  GridFixture(this.root, this.model, this.backend, this.result);
  final Directory root;
  final WorkbenchModel model;
  final TestBackend backend;
  rpc.StatementResult result;
  final clipboard = <String>[];
  WorkbenchDocument get owner => model.activeOwner;
  static List<rpc.Column> columns() => [
    for (var i = 0; i < 4; i++)
      rpc.Column(
        name: 'column$i',
        baseColumn: 'column$i',
        ordinal: i + 1,
        typeName: 'text',
        jdbcType: 12,
        table: 'items',
        schema: 'public',
        provenanceKnown: true,
      ),
  ];
  static Future<GridFixture> create(
    WidgetTester tester, {
    bool metadata = true,
    int rows = 2,
  }) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('visible-grid-'),
    ))!;
    final backend = TestBackend();
    final model = WorkbenchModel(root)
      ..draftRecovery = false
      ..backend = backend
      ..newDocument();
    model.activeOwner.sessionId = 'physical';
    model.sessions['physical'] = rpc.SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'physical',
      autoCommit: true,
      transaction: rpc.TransactionState.IDLE,
    );
    final result = rpc.StatementResult(
      resultId: 'visible',
      complete: true,
      fetchedRows: Int64(rows),
      columns: metadata ? columns() : [],
    );
    model.track(
      rpc.JobInfo(
        jobId: 'visible-job',
        executionId: 'execution',
        sessionId: 'physical',
        state: rpc.JobState.COMPLETED,
        results: [result],
      ),
      documentId: model.activeOwner.id,
    );
    for (var row = 0; row < rows; row++) {
      model.cache['visible:$row'] = rpc.Row(
        values: [
          for (var col = 0; col < 4; col++) rpc.Value(text: '$row:$col'),
        ],
      );
    }
    backend.client.editability = rpc.Editability(
      editable: true,
      editableColumns: [1, 2, 3, 4],
    );
    backend.client.pages = (_) async => rpc.Page(
      complete: true,
      fetchedRows: Int64(rows),
      nextOffset: Int64(rows),
    );
    final fixture = GridFixture(root, model, backend, result);
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        fixture.clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      await tester.runAsync(() => root.delete(recursive: true));
    });
    return fixture;
  }

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResultGrid(
            model: model,
            controls: const LinuxControls(),
            result: result,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void focus(WidgetTester tester) => tester
      .widgetList<Focus>(find.byType(Focus))
      .map((w) => w.focusNode)
      .whereType<FocusNode>()
      .firstWhere((n) => n.debugLabel == 'Result grid')
      .requestFocus();
}
