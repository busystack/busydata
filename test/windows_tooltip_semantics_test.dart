import 'dart:io';
import 'package:busydata/src/app/windows/windows_busydata_app.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final overflow in [false, true]) {
    testWidgets(
      'tooltip overlays preserve workbench semantic ancestry, overflow=$overflow',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        await tester.binding.setSurfaceSize(const Size(1024, 720));
        final semantics = tester.ensureSemantics();
        final model =
            WorkbenchModel(Directory('/unused-windows-tooltip-semantics'))
              ..draftRecovery = false
              ..backend = TestBackend()
              ..newDocument(text: 'SELECT id, n FROM native_windows_parent;');
        final profile = rpc.Profile(
          id: 'p',
          name: 'PostgreSQL fixture',
          engine: rpc.Engine.POSTGRESQL,
          host: '10.0.2.2',
          port: 5432,
          database: 'busydata',
          user: 'fixture',
        );
        model.profiles.add(profile);
        model.sessions['s'] = rpc.SessionInfo(
          sessionId: 's',
          profile: profile,
          autoCommit: true,
          currentCatalog: 'busydata',
          currentSchema: 'public',
        );
        (model.backend! as TestBackend).client.editability = rpc.Editability(
          editable: true,
          editableColumns: [2, 3, 4, 5],
        );
        if (overflow) {
          for (var i = 1; i < 6; i++) {
            model.newDocument(text: 'SELECT id, n FROM native_windows_parent;');
            model.activeOwner.profileId = 'p';
            model.activeOwner.sessionId = 's';
          }
        }
        final sql = model.activeOwner
          ..profileId = 'p'
          ..sessionId = 's';
        rpc.StatementResult result(String id) => rpc.StatementResult(
          resultId: id,
          complete: true,
          fetchedRows: Int64(2),
          columns: [
            for (final c in [
              (1, 'id', 'serial'),
              (2, 'n', 'text'),
              (3, 'note', 'text'),
              (4, 'amount', 'numeric'),
              (5, 'bytes', 'bytea'),
            ])
              rpc.Column(
                name: c.$2,
                typeName: c.$3,
                ordinal: c.$1,
                baseColumn: c.$2,
                schema: 'public',
                table: 'native_windows_parent',
                provenanceKnown: true,
              ),
          ],
        );
        void track(WorkbenchDocument owner, String suffix) {
          model.track(
            rpc.JobInfo(
              jobId: 'j-$suffix',
              executionId: 'e-$suffix',
              sessionId: 's',
              state: rpc.JobState.COMPLETED,
              results: [result('r-$suffix')],
            ),
            documentId: owner.id,
          );
          model.cache['r-$suffix:0'] = rpc.Row(
            values: [
              rpc.Value(signedInteger: '1'),
              rpc.Value(text: '漢😀'),
              rpc.Value(nullValue: rpc.Null()),
              rpc.Value(decimal: '12345678901234567890.123456789012345678'),
              rpc.Value(binary: [0, 1, 254, 255]),
            ],
          );
          model.cache['r-$suffix:1'] = rpc.Row(
            values: [
              rpc.Value(signedInteger: '2'),
              rpc.Value(text: 'second'),
              rpc.Value(text: 'original'),
              rpc.Value(decimal: '-0.000000000000000001'),
              rpc.Value(binary: [255, 255, 0, 0]),
            ],
          );
        }

        track(sql, 'sql');
        final prepared = model.openTask(
          WorkbenchDocumentKind.table,
          'native_windows_parent',
          object: const DatabaseObjectIdentity(
            profileId: 'p',
            catalog: 'busydata',
            schema: 'public',
            kind: rpc.ObjectKind.TABLE,
            name: 'native_windows_parent',
          ),
          evidenceProfile: profile,
        );
        prepared.profileId = 'p';
        prepared.sessionId = 's';
        prepared.view.subview = 'structure';
        model.activateOwner(sql.id);
        final owner = tester.binding.renderViews.single.owner!.semanticsOwner!;
        var watching = false;
        final ancestryUpdates = <List<int>>[];
        List<int> workbenchAncestry() {
          SemanticsNode? workbench;
          void visit(SemanticsNode node) {
            if (node.getSemanticsData().identifier ==
                'busydata.windows.workbench') {
              expect(workbench, isNull);
              workbench = node;
            }
            node.visitChildren((child) {
              visit(child);
              return true;
            });
          }

          visit(owner.rootSemanticsNode!);
          expect(workbench, isNotNull);
          return [
            for (
              SemanticsNode? node = workbench;
              node != null;
              node = node.parent
            )
              node.id,
          ];
        }

        void observe() {
          if (watching) ancestryUpdates.add(workbenchAncestry());
        }

        owner.addListener(observe);
        try {
          await tester.pumpWidget(
            ProviderScope(
              retry: (_, _) => null,
              overrides: [workbenchProvider.overrideWithValue(model)],
              child: const WindowsBusyDataApp(),
            ),
          );
          await tester.pumpAndSettle();
          final table = model.openTask(
            WorkbenchDocumentKind.table,
            'native_windows_parent',
            object: const DatabaseObjectIdentity(
              profileId: 'p',
              catalog: 'busydata',
              schema: 'public',
              kind: rpc.ObjectKind.TABLE,
              name: 'native_windows_parent',
            ),
            evidenceProfile: profile,
          );
          table.profileId = 'p';
          table.sessionId = 's';
          table.view.subview = 'data';
          await tester.pumpAndSettle();
          track(table, 'table');
          await tester.pumpAndSettle();
          final originalAncestry = workbenchAncestry();
          watching = true;
          final more = find
              .byWidgetPredicate(
                (w) =>
                    w is fluent.Tooltip &&
                    (w.message ?? w.richMessage?.toPlainText()) == 'More',
              )
              .hitTestable();
          expect(more, findsWidgets);
          final beforeTooltip = find.text('More').evaluate().length;
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: const Offset(1, 1));
          await tester.pump();
          await mouse.moveTo(tester.getCenter(more.first));
          await tester.pump(const Duration(seconds: 2));
          await tester.pumpAndSettle();
          expect(
            find.text('More').evaluate().length,
            greaterThan(beforeTooltip),
            reason: 'Actual mouse hover must display the tooltip',
          );
          await mouse.removePointer();
          await tester.pumpAndSettle();
          watching = false;
          expect(ancestryUpdates, isNotEmpty);
          for (final ancestry in ancestryUpdates) {
            expect(
              ancestry,
              orderedEquals(originalAncestry),
              reason:
                  'Showing and retiring a tooltip must keep the workbench under its stable route ancestors',
            );
          }
          expect(tester.takeException(), isNull);
        } finally {
          watching = false;
          owner.removeListener(observe);
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          semantics.dispose();
          await tester.binding.setSurfaceSize(null);
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  }
}
