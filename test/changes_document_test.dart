import 'package:busydata/src/features/results/value_assignments.dart'
    as assignments;
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/workbench_tabs.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} review is lazy, names original/proposed, and never resolves a manual transaction',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('changes-view-'),
        ))!;
        final model = (await tester.runAsync(
          () async => WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = TestBackend()
            ..newDocument(),
        ))!;
        final source = model.activeOwner..sessionId = 'source';
        model.sessions['source'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'source',
          autoCommit: true,
          contextRevision: Int64.ONE,
        );
        final captured = model.captureTarget(owner: source),
            batch = model.batchFor(source, 'result');
        final plan = rpc.ChangePlan(
          target: rpc.Profile(
            name: 'Production',
            environment: rpc.Environment.PRODUCTION,
            host: 'original',
          ),
          changes: [
            for (var i = 0; i < 1000; i++)
              rpc.ReviewedChange(
                kind: rpc.ChangeKind.UPDATE,
                sourceRow: Int64(i),
                original: {'n': rpc.Value(text: 'original $i')}.entries,
                values: ({'n': rpc.Value(text: 'proposed $i')}.entries).map(
                  (entry) => MapEntry(
                    entry.key,
                    assignments.assignmentOf(entry.value),
                  ),
                ),
              ),
          ],
          sql: [
            for (var i = 0; i < 1000; i++)
              'UPDATE quoted_table SET n=? WHERE id=?; -- $i',
          ],
        );
        var applied = 0;
        final review = ChangesReviewData(
          captured,
          batch,
          batch.revision,
          plan,
          () async {
            applied++;
          },
        );
        final owner = model.openTask(
          WorkbenchDocumentKind.structure,
          'Changes',
          payload: review,
        );
        Widget app(Widget child) => controls is WindowsControls
            ? fluent.FluentApp(
                home: DefaultTextStyle(
                  style: const TextStyle(fontSize: 14),
                  child: child,
                ),
              )
            : MaterialApp(home: Scaffold(body: child));
        await tester.binding.setSurfaceSize(const Size(900, 600));
        await tester.pumpWidget(
          app(
            ListenableBuilder(
              listenable: model,
              builder: (_, _) => ChangesDocumentView(
                model: model,
                owner: owner,
                controls: controls,
                review: review,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Original'), findsOneWidget);
        expect(find.text('Proposed'), findsOneWidget);
        expect(find.text('original 0'), findsOneWidget);
        expect(find.text('proposed 0'), findsOneWidget);
        for (final label in ['Original', 'Proposed']) {
          final evidence = tester
              .getSemantics(find.bySemanticsLabel('$label · n').first)
              .getSemanticsData();
          expect(evidence.flagsCollection.isTextField, isTrue);
          expect(evidence.flagsCollection.isReadOnly, isTrue);
          expect(
            evidence.value,
            label == 'Original' ? 'original 0' : 'proposed 0',
          );
        }
        expect(find.text('original 999'), findsNothing);
        expect(find.text('Edit row · Source row 999'), findsNothing);
        expect(find.textContaining('1000 updates'), findsOneWidget);
        Future<void> chooseEvidence(bool sql) async {
          if (controls is LinuxControls) {
            // GTK owns this popup outside the widget tree. Its actual native
            // selection is exercised by the ordinary product acceptance.
            final choice = tester.widget<BusyDataMenuButton<bool>>(
              find.byType(BusyDataMenuButton<bool>),
            );
            expect(choice.entries.map((e) => e.label), [
              'Changes',
              'Generated SQL',
            ]);
            choice.onSelected(sql);
          } else {
            await tester.tap(find.text(sql ? 'Changes' : 'Generated SQL'));
            await tester.pumpAndSettle();
            await tester.tap(find.text(sql ? 'Generated SQL' : 'Changes').last);
          }
          await tester.pumpAndSettle();
        }

        await chooseEvidence(true);
        await tester.pumpAndSettle();
        final sqlEvidence = tester
            .getSemantics(find.bySemanticsLabel('Generated SQL · 1').first)
            .getSemanticsData();
        expect(sqlEvidence.value, plan.sql.first);
        expect(sqlEvidence.flagsCollection.isReadOnly, isTrue);
        await chooseEvidence(false);
        await tester.tap(find.text('Apply and commit'));
        await tester.pumpAndSettle();
        expect(applied, 1);
        model.sessions['source']!
          ..autoCommit = false
          ..transaction = rpc.TransactionState.ACTIVE;
        model.updateStatus('Manual transaction retained');
        await tester.pump();
        await tester.tap(find.text('Apply and commit'));
        await tester.pump();
        expect(applied, 1);
        expect(
          find.text('Manual transaction · Transaction open'),
          findsOneWidget,
        );
        expect((model.backend! as TestBackend).client.sessionCommands, isEmpty);
        expect((model.backend! as TestBackend).client.executions, isEmpty);
        await tester.pumpWidget(
          app(
            Center(
              child: SizedBox(
                width: 636,
                height: 410,
                child: MediaQuery(
                  data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ChangesDocumentView(
                      model: model,
                      owner: owner,
                      controls: controls,
                      review: review,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(find.text('Apply and commit')).bottom,
          lessThanOrEqualTo(600),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        semantics.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
        await tester.binding.setSurfaceSize(null);
      },
    );
    testWidgets(
      '${controls.runtimeType} duplicate object tabs show short endpoint qualifiers and complete captured context',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('target-tabs-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument();
        final object = DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'same_db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'same_table',
        );
        for (final endpoint in ['original', 'replacement']) {
          model.openTask(
            WorkbenchDocumentKind.table,
            object.name,
            object: object,
            reuse: false,
            evidenceProfile: rpc.Profile(
              id: 'p',
              name: 'Same profile',
              host: endpoint,
              port: 5432,
              database: 'same_db',
            ),
          );
        }
        final view = WorkbenchTabs(
          model: model,
          controls: controls,
          close: (_) {},
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: view),
        );
        await tester.pumpAndSettle();
        for (final endpoint in ['original', 'replacement']) {
          expect(find.text(endpoint), findsOneWidget);
          final owner = model.taskDocuments.singleWhere(
            (d) => d.evidenceProfile?.host == endpoint,
          );
          expect(
            tester
                .getSemantics(find.byKey(ValueKey('document-tab:${owner.id}')))
                .label,
            contains('Same profile · $endpoint:5432/same_db'),
          );
        }
        expect(find.text('same_table'), findsNWidgets(2));
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        semantics.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
    testWidgets(
      '${controls.runtimeType} resizing keeps the active document tab visible without focus changes',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('tab-resize-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument();
        for (var i = 0; i < 8; i++) {
          model.openTask(
            WorkbenchDocumentKind.structure,
            'Long object document $i',
          );
        }
        Widget app(Widget child) => controls is WindowsControls
            ? fluent.FluentApp(home: child)
            : MaterialApp(home: child);
        await tester.binding.setSurfaceSize(const Size(1920, 400));
        await tester.pumpWidget(
          app(
            Align(
              alignment: Alignment.topLeft,
              child: WorkbenchTabs(
                model: model,
                controls: controls,
                close: (_) {},
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        final before = FocusManager.instance.primaryFocus;
        await tester.binding.setSurfaceSize(const Size(900, 400));
        await tester.pump();
        await tester.pump();
        final rect = tester.getRect(find.text('Long object document 7'));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(900));
        expect(FocusManager.instance.primaryFocus, same(before));
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
        await tester.binding.setSurfaceSize(null);
      },
    );
  }
}
