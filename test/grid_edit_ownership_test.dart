import 'package:busydata/src/features/results/value_assignments.dart'
    as assignments;
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} visible Changes and Export commands retain the grid owner after another document becomes active',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('grid-toolbar-owner-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final a = model.activeOwner;
        final result = rpc.StatementResult(
          resultId: 'original',
          complete: true,
          fetchedRows: Int64.ONE,
          columns: [rpc.Column(name: 'n', typeName: 'text', jdbcType: 12)],
        );
        model.track(
          rpc.JobInfo(
            jobId: 'j',
            executionId: 'e',
            state: rpc.JobState.COMPLETED,
            results: [result],
          ),
          documentId: a.id,
        );
        model.cache['original:0'] = rpc.Row(
          values: [rpc.Value(text: 'before')],
        );
        final batch = model.batchFor(a, 'original')
          ..changes.add(
            rpc.StagedChange(
              kind: rpc.ChangeKind.UPDATE,
              sourceRow: Int64.ZERO,
              values: ([MapEntry(1, rpc.Value(text: 'after'))]).map(
                (entry) =>
                    MapEntry(entry.key, assignments.assignmentOf(entry.value)),
              ),
            ),
          );
        final invoked = <String, WorkbenchCommandContext>{};
        model.commands = WorkbenchCommandRegistry([
          for (final id in [
            'result.presentation.table',
            'result.presentation.transpose',
            'result.presentation.tree',
            'result.presentation.text',
            'result.record',
            'result.displayFormat',
            'result.aggregate',
            'result.related',
            'result.clone',
            'result.inserts',
            'result.details',
            'result.filter',
            'result.sort',
            'result.columns',
            'result.refresh',
            'result.assess',
            'result.provenance',
            'edit.insert',
            'edit.update',
            'edit.delete',
            'edit.apply',
            'edit.discard',
            'transfer.retained',
          ])
            WorkbenchCommand(
              id: id,
              label: id == 'transfer.retained' ? 'Export retained data' : id,
              category: 'Results',
              invoke: (c) => invoked[id] = c,
            ),
        ]);
        await tester.binding.setSurfaceSize(const Size(1440, 900));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        if (ui is LinuxControls) {
          const menus = MethodChannel('busydata/native_menus');
          final messenger = tester.binding.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(menus, (call) async {
            throw MissingPluginException();
          });
          addTearDown(() => messenger.setMockMethodCallHandler(menus, null));
        }
        final view = ResultGrid(model: model, controls: ui, result: result);
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        model.newDocument();
        await tester.tap(find.text('Review details'));
        await tester.pumpAndSettle();
        await tester.tap(
          ui is LinuxControls
              ? find
                    .descendant(
                      of: find.byKey(const ValueKey('result-actions-menu')),
                      matching: find.byType(IconButton),
                    )
                    .first
              : find.byKey(const ValueKey('result-actions-menu')),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Export retained data'));
        await tester.tap(find.text('Export retained data'));
        await tester.pumpAndSettle();
        expect(invoked.keys, ['edit.apply', 'transfer.retained']);
        expect(
          invoked.values.every(
            (c) => identical(c.owner, a) && c.resultId == 'original',
          ),
          isTrue,
        );
        expect(batch.changes, hasLength(1));
        expect(model.activeOwner, isNot(same(a)));
        expect(backend.client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${ui.runtimeType} F2 stages one owned row; stale assessment cannot stage',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('inline-owned-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)..draftRecovery = false;
        model.newDocument();
        model.backend = backend;
        final a = model.activeOwner;
        a.sessionId = 'source-session';
        model.sessions[a.sessionId!] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: a.sessionId,
          transaction: rpc.TransactionState.IDLE,
          contextRevision: Int64.ONE,
        );
        backend.client.editability = rpc.Editability(
          editable: true,
          editableColumns: [1],
        );
        final result = rpc.StatementResult(
          resultId: 'original',
          complete: true,
          fetchedRows: Int64.ONE,
          columns: [
            rpc.Column(
              name: 'n',
              ordinal: 1,
              baseColumn: 'n',
              table: 't',
              schema: 'public',
              jdbcType: 12,
              typeName: 'text',
            ),
          ],
        );
        model.cache['original:0'] = rpc.Row(
          values: [rpc.Value(text: 'before')],
        );
        final grid = ResultGrid(model: model, controls: ui, result: result);
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: grid)
              : MaterialApp(home: grid),
        );
        await tester.pump();
        await tester.tap(find.text('before'));
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pump();
        expect(find.byType(EditableText), findsOneWidget);
        await tester.enterText(find.byType(EditableText), 'after');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final batch = model.batchFor(a, 'original');
        expect(batch.changes.single.sourceRow, Int64.ZERO);
        expect(batch.changes.single.values[1]!.value.text, 'after');
        expect(batch.ownerId, a.id);
        expect(backend.client.executions, isEmpty);

        // Start an edit against the assessed context, then change that context.
        await tester.tap(find.text('after'));
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), 'must not stage');
        model.sessions[a.sessionId!]!.contextRevision = Int64(2);
        model.newDocument();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(batch.changes.single.values[1]!.value.text, 'after');
        expect(model.activeOwner.view.results, isEmpty);
        expect(model.editBatches.length, 1);
        expect(backend.client.executions, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 350));
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }
}
