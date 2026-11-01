import 'dart:async';
import 'dart:io';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/value_assignments.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_staged_insert.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/native_window.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final clone in [false, true]) {
      for (final retry in [false, true]) {
        testWidgets(
          '${controls.runtimeType} ${clone ? 'cloned' : 'new'} insert failed validation ${retry ? 'retry replaces one intention' : 'cancel preserves intention'}',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 900));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            if (controls is LinuxControls) installNativeWindowFixture(tester);
            final backend = TestBackend();
            final model = metadataFixture(
              WorkbenchModel(Directory('/unused'))
                ..draftRecovery = false
                ..backend = backend
                ..newDocument(),
            );
            final owner = model.activeOwner
              ..sessionId = 'physical'
              ..profileId = 'p';
            final profile = rpc.Profile(
              id: 'p',
              name: 'source',
              engine: rpc.Engine.POSTGRESQL,
              database: 'db',
            );
            model.profiles.add(profile);
            model.sessions['physical'] = rpc.SessionInfo(
              metadataSourceIdentity: fixtureMetadataSourceIdentity,
              sessionId: 'physical',
              profile: profile,
              currentCatalog: 'db',
              currentSchema: 'public',
              contextRevision: Int64.ONE,
              sessionRevision: Int64.ONE,
              autoCommit: true,
              transaction: rpc.TransactionState.IDLE,
            );
            final result = rpc.StatementResult(
              resultId: 'source',
              fetchedRows: Int64.ONE,
              complete: true,
              columns: [
                rpc.Column(
                  name: 'n',
                  baseColumn: 'n',
                  ordinal: 1,
                  typeName: 'integer',
                  jdbcType: 4,
                  catalog: 'db',
                  schema: 'public',
                  table: 'items',
                  provenanceKnown: true,
                ),
              ],
            );
            model.track(
              rpc.JobInfo(
                jobId: 'source-job',
                executionId: 'source-execution',
                sessionId: 'physical',
                state: rpc.JobState.COMPLETED,
                results: [result],
              ),
              documentId: owner.id,
            );
            model.cache['source:0'] = rpc.Row(
              values: [rpc.Value(signedInteger: '1')],
            );
            backend.client.editability = rpc.Editability(
              editable: true,
              editableColumns: [1],
            );
            backend.client.metadataAction = (request) async =>
                rpc.SchemaObjects(
                  complete: true,
                  objects: request.kind == rpc.ObjectKind.COLUMN
                      ? [
                          rpc.SchemaObject(
                            name: 'n',
                            kind: rpc.ObjectKind.COLUMN,
                            properties: {
                              'generated': 'NO',
                              'autoIncrement': 'NO',
                              'type': 'integer',
                              'jdbcType': '4',
                            }.entries,
                          ),
                        ]
                      : [],
                );
            var saves = 0;
            final record = rpc.EditDraftInfo(
              draftId: 'verified',
              documentId: owner.id,
              state: 'STAGED',
              changes: 1,
            );
            backend.client.edits = (request) async {
              if (request.action == rpc.EditDraftAction.SAVE_EDIT_DRAFT) {
                saves++;
                if (saves == 1) {
                  throw const GrpcError.invalidArgument(
                    'Typed edit validation failed',
                  );
                }
                return rpc.EditDraftReply(drafts: [record]);
              }
              return rpc.EditDraftReply(drafts: [if (saves > 1) record]);
            };
            final batch = model.batchFor(owner, 'source')
              ..sessionId = 'physical'
              ..documentId = owner.id
              ..schema = 'public'
              ..table = 'items';
            if (clone) {
              model.stageChange(
                batch,
                rpc.StagedChange(
                  kind: rpc.ChangeKind.INSERT,
                  values: {
                    1: assignmentOf(rpc.Value(text: 'invalid integer')),
                  }.entries,
                ),
              );
            }
            final Widget content = clone
                ? Builder(
                    builder: (context) => controls.button(
                      'Open clone',
                      () => controls.dialog<void>(
                        context,
                        'Clone',
                        StagedInsertEditor(
                          model: model,
                          controls: controls,
                          batch: batch,
                          index: 0,
                          columns: result.columns,
                          editableOrdinals: [1],
                          validateOwner: () {},
                        ),
                        [
                          controls.button(
                            'Close',
                            () => Navigator.of(context).pop(),
                          ),
                        ],
                        bodyScrolls: true,
                      ),
                    ),
                  )
                : WorkbenchView(model: model, controls: controls);
            await tester.pumpWidget(
              controls is WindowsControls
                  ? fluent.FluentApp(home: content)
                  : MaterialApp(home: Scaffold(body: content)),
            );
            await tester.pumpAndSettle();
            model.draftRecovery = true;
            if (clone) {
              await tester.tap(find.text('Open clone'));
            } else {
              unawaited(
                model.commands!.invoke('edit.insert', model.commandContext),
              );
            }
            await tester.pumpAndSettle();
            if (!clone) {
              if (controls is LinuxControls) {
                final selector = find.byWidgetPredicate(
                  (w) =>
                      w is BusyDataPopupSelector<String> &&
                      w.options.any((o) => o.value == 'unset'),
                );
                tester
                    .widget<BusyDataPopupSelector<String>>(selector)
                    .onSelected('value');
              } else {
                final selector = find.byWidgetPredicate(
                  (w) =>
                      w is fluent.ComboBox<String> &&
                      w.items?.any((o) => o.value == 'unset') == true,
                );
                tester.widget<fluent.ComboBox<String>>(selector).onChanged!(
                  'value',
                );
              }
              await tester.pumpAndSettle();
              await tester.enterText(
                find.byType(EditableText).last,
                'invalid integer',
              );
            }
            await tester.tap(find.text('Stage change'));
            await tester.pumpAndSettle();
            expect(saves, 1);
            expect(batch.changes, hasLength(1));
            expect(
              batch.changes.single.values[1]!.value.text,
              'invalid integer',
            );
            expect(
              find.text('Value draft preserved; stored value is unchanged.'),
              findsOneWidget,
            );
            if (retry) {
              await tester.enterText(find.byType(EditableText).last, '42');
              await tester.tap(find.text('Stage change'));
              await tester.pumpAndSettle();
              expect(saves, 2);
              expect(batch.changes, hasLength(1));
              expect(batch.changes.single.values[1]!.value.text, '42');
              expect(batch.draftId, 'verified');
              expect(
                find.text('Value draft preserved; stored value is unchanged.'),
                findsNothing,
              );
            } else {
              await tester.tap(find.text(clone ? 'Close' : 'Cancel'));
              await tester.pumpAndSettle();
              expect(batch.changes, hasLength(1));
              expect(batch.saveError, isNotNull);
            }
            final requests = backend.client.editRequests
                .where((r) => r.action == rpc.EditDraftAction.SAVE_EDIT_DRAFT)
                .toList();
            expect(
              requests.every(
                (r) =>
                    r.changes.changes.length == 1 &&
                    r.changes.changes.single.kind == rpc.ChangeKind.INSERT,
              ),
              isTrue,
            );
            expect(backend.client.executions, isEmpty);
            expect(model.jobs.keys, ['source-job']);
            expect(model.cache['source:0']!.values.single.signedInteger, '1');
            expect(tester.takeException(), isNull);
            model.draftRecovery = false;
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
          },
        );
      }
    }
  }
}
