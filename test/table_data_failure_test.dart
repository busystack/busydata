import 'dart:io';

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'test_localized_app.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final locale in ['en', 'ar']) {
      testWidgets(
        '${controls.runtimeType} $locale table failures use only the latest owned typed reason and preserve drafts',
        (tester) async {
          final backend = TestBackend();
          final model = WorkbenchModel(Directory('/unused-table-failure'))
            ..draftRecovery = false
            ..backend = backend
            ..newDocument();
          final scratch = model.document;
          const sql = 'SELECT draft_漢😀;';
          scratch.editor.text = sql;
          final editor = scratch.editor;
          WorkbenchDocument table(String name) => model.openTask(
            WorkbenchDocumentKind.table,
            name,
            reuse: false,
            object: DatabaseObjectIdentity(
              profileId: 'fixture',
              catalog: 'busydata',
              schema: 'public',
              kind: rpc.ObjectKind.TABLE,
              name: name,
            ),
          )..view.subview = 'data';
          final owner = table('selected_table');
          final other = table('other_table');
          final batch = model.batchFor(owner, 'retained-source');
          model.stageChange(
            batch,
            rpc.StagedChange(
              kind: rpc.ChangeKind.UPDATE,
              values: [
                MapEntry(
                  1,
                  rpc.ValueAssignment(value: rpc.Value(text: 'pending 漢😀')),
                ),
              ],
            ),
          );
          final staged = batch.changes.single.writeToBuffer();
          final batchRevision = batch.revision;
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
          });
          late String stale;
          Future<void> show(WorkbenchDocument document) async {
            final child = Builder(
              builder: (context) {
                stale = strings(context).staleRefresh;
                return ListenableBuilder(
                  listenable: model,
                  builder: (_, _) => WorkbenchDocumentView(
                    model: model,
                    owner: document,
                    controls: controls,
                  ),
                );
              },
            );
            await tester.pumpWidget(
              controls is WindowsControls
                  ? fluent.FluentApp(
                      locale: Locale(locale),
                      localizationsDelegates: const [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      home: fluent.ScaffoldPage(content: child),
                    )
                  : localizedTestApp(
                      locale: Locale(locale),
                      child: Scaffold(body: child),
                    ),
            );
            await tester.pumpAndSettle();
          }

          // A different document's genuine typed failure cannot relabel this
          // document, nor can a human message synthesize a typed reason.
          model.track(
            rpc.JobInfo(
              jobId: 'unknown',
              executionId: 'unknown',
              state: rpc.JobState.FAILED,
              errorCode: 'STALE',
              messages: ['Workbench request failed: stale'],
            ),
            documentId: owner.id,
          );
          model.track(
            rpc.JobInfo(
              jobId: 'foreign',
              executionId: 'foreign',
              state: rpc.JobState.FAILED,
              errorCode: 'stale',
            ),
            documentId: other.id,
          );
          final fallback = owner.view.dataError;
          expect(fallback, isNotEmpty);
          await show(owner);
          expect(find.text(fallback), findsOneWidget);
          expect(find.text(stale), findsNothing);
          expect(
            Directionality.of(
              tester.element(find.byType(WorkbenchDocumentView)),
            ),
            locale == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          );

          model.track(
            rpc.JobInfo(
              jobId: 'owned',
              executionId: 'owned',
              state: rpc.JobState.FAILED,
              errorCode: 'stale',
            ),
            documentId: owner.id,
          );
          await tester.pumpAndSettle();
          expect(find.text(stale), findsOneWidget);
          expect(find.text(fallback), findsNothing);
          expect(model.jobForOwner(owner)?.jobId, 'owned');
          expect(model.jobForOwner(other)?.jobId, 'foreign');

          // An old typed error cannot override a newer unknown outcome code.
          model.track(
            rpc.JobInfo(
              jobId: 'latest',
              executionId: 'latest',
              state: rpc.JobState.FAILED,
              errorCode: 'UNRECOGNIZED',
              messages: ['Review required or approval stale'],
            ),
            documentId: owner.id,
          );
          await tester.pumpAndSettle();
          expect(find.text(fallback), findsOneWidget);
          expect(find.text(stale), findsNothing);
          await tester.pump(const Duration(seconds: 2));
          expect(backend.client.executions, isEmpty);
          expect(backend.client.browseRequests, isEmpty);
          expect(scratch.editor, same(editor));
          expect(editor.text, sql);
          expect(model.batchFor(owner, 'retained-source'), same(batch));
          expect(batch.changes.single.writeToBuffer(), staged);
          expect(batch.revision, batchRevision);
          expect(batch.applying, isFalse);
          expect(batch.outcomeUnknown, isFalse);

          // The existing global Jobs surface also localizes allowlisted codes;
          // this changes presentation, not table selection or job execution.
          final jobs = WorkbenchDocument(
            id: 'global:jobs',
            kind: WorkbenchDocumentKind.administration,
            title: 'Jobs',
            payload: GlobalToolData(GlobalToolKind.jobs),
          );
          await show(jobs);
          expect(find.text(stale), findsWidgets);
          expect(backend.client.executions, isEmpty);
          expect(backend.client.browseRequests, isEmpty);
          expect(editor.text, sql);
          expect(batch.changes.single.writeToBuffer(), staged);
        },
      );
    }
  }
}
