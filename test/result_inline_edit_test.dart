import 'dart:io';
import 'dart:ui' show Tristate, SemanticsAction, SemanticsActionEvent;
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
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} F2 exposes a native field and coalesces exact row edits',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('inline-edit-'),
        ))!;
        final backend = TestBackend();
        final model = (await tester.runAsync(
          () async => WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(),
        ))!;
        final owner = model.activeOwner..sessionId = 'physical';
        model.sessions['physical'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'physical',
          autoCommit: true,
          transaction: rpc.TransactionState.IDLE,
        );
        final result = rpc.StatementResult(
          resultId: 'original',
          complete: true,
          fetchedRows: Int64.ONE,
          columns: [
            rpc.Column(
              name: 'id',
              baseColumn: 'id',
              ordinal: 1,
              jdbcType: 4,
              table: 'items',
              schema: 'public',
              provenanceKnown: true,
            ),
            rpc.Column(
              name: 'n',
              baseColumn: 'n',
              ordinal: 2,
              jdbcType: 12,
              table: 'items',
              schema: 'public',
              provenanceKnown: true,
            ),
          ],
        );
        model.track(
          rpc.JobInfo(
            jobId: 'j',
            executionId: 'e',
            sessionId: 'physical',
            state: rpc.JobState.COMPLETED,
            results: [result],
          ),
          documentId: owner.id,
        );
        model.cache['original:0'] = rpc.Row(
          values: [
            rpc.Value(signedInteger: '41'),
            rpc.Value(text: 'original'),
          ],
        );
        backend.client.editability = rpc.Editability(
          editable: true,
          editableColumns: [1, 2],
        );
        final grid = ResultGrid(
          model: model,
          controls: controls,
          result: result,
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: grid)
              : MaterialApp(home: Scaffold(body: grid)),
        );
        await tester.pumpAndSettle();
        await model.resultActions[owner.id]!['result.assess']!();
        await tester.pumpAndSettle();
        expect(
          tester.getSemantics(find.bySemanticsLabel('Row 1, n: original')).hint,
          contains('Editable'),
        );
        await tester.tap(find.text('original'));
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pumpAndSettle();
        final editor = find.byType(EditableText);
        expect(editor, findsOneWidget);
        final fields = find
            .bySemanticsLabel('n')
            .evaluate()
            .map(
              (e) => tester
                  .getSemantics(
                    find.byElementPredicate(
                      (candidate) => identical(candidate, e),
                    ),
                  )
                  .getSemanticsData(),
            )
            .where((data) => data.flagsCollection.isTextField)
            .toList();
        expect(fields, hasLength(1));
        final nativeField = fields.single;
        expect(nativeField.flagsCollection.isTextField, isTrue);
        expect(nativeField.label, 'n');
        expect(nativeField.value, 'original');
        expect(nativeField.flagsCollection.isFocused, Tristate.isTrue);
        await tester.enterText(editor, 'changed');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        final batch = model.batchFor(owner, 'original');
        expect(batch.changes.single.sourceRow, Int64.ZERO);
        expect(batch.changes.single.values[2]!.value.text, 'changed');
        expect(batch.changes.single.values[1], isNull);
        expect(
          find.bySemanticsLabel('Row 1, n: changed · pending change'),
          findsOneWidget,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), 'second intention');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(batch.changes, hasLength(1));
        expect(batch.changes.single.values[2]!.value.text, 'second intention');
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(EditableText),
          'cancelled local value',
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(batch.changes.single.values[2]!.value.text, 'second intention');
        expect(model.cache['original:0']!.values[1].text, 'original');
        expect(backend.client.executions, isEmpty);
        expect(model.jobs.keys, ['j']);
        final fresh = result.deepCopy()
          ..resultId = 'fresh'
          ..fetchedRows = Int64(2);
        model.track(
          rpc.JobInfo(
            jobId: 'j2',
            executionId: 'e2',
            sessionId: 'physical',
            state: rpc.JobState.COMPLETED,
            results: [fresh],
          ),
          documentId: owner.id,
        );
        model.cache['fresh:0'] = rpc.Row(
          values: [
            rpc.Value(signedInteger: '2'),
            rpc.Value(text: 'second'),
          ],
        );
        model.cache['fresh:1'] = rpc.Row(
          values: [
            rpc.Value(signedInteger: '41'),
            rpc.Value(text: 'replacement'),
          ],
        );
        final freshGrid = ResultGrid(
          model: model,
          controls: controls,
          result: fresh,
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: freshGrid)
              : MaterialApp(home: Scaffold(body: freshGrid)),
        );
        await tester.pumpAndSettle();
        await model.resultActions[owner.id]!['result.assess']!();
        await tester.pumpAndSettle();
        final node = tester.getSemantics(
          find.bySemanticsLabel('Row 2, n: replacement'),
        );
        tester.binding.performSemanticsAction(
          SemanticsActionEvent(
            viewId: tester.view.viewId,
            nodeId: node.id,
            type: SemanticsAction.focus,
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pumpAndSettle();
        expect(find.byType(EditableText), findsOneWidget);
        await tester.enterText(find.byType(EditableText), 'fresh intention');
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          model.batchFor(owner, 'fresh').changes.single.sourceRow,
          Int64.ONE,
        );
        expect(
          model.batchFor(owner, 'fresh').changes.single.values[2]!.value.text,
          'fresh intention',
        );
        expect(batch.changes.single.values[2]!.value.text, 'second intention');
        expect(backend.client.executions, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        semantics.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }
}
