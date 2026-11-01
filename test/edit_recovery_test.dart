import 'package:busydata/src/features/results/value_assignments.dart'
    as assignments;
import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  for (final scenario in [
    'staged',
    'unknown reviewed',
    'applying',
    'changed',
    'restarted',
  ]) {
    test(
      'explicit recovery discard revalidates $scenario and never runs SQL',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'busydata-recovery-discard-',
        );
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument();
        final backend = TestBackend();
        model.backend = backend;
        addTearDown(() async {
          model.dispose();
          await root.delete(recursive: true);
        });
        final reviewed = EditDraftInfo(
          draftId: 'original',
          schema: 'public',
          table: 'rows',
          changes: 2,
          state: scenario == 'unknown reviewed'
              ? 'UNKNOWN_OUTCOME'
              : scenario == 'applying'
              ? 'APPLYING'
              : 'STAGED',
        );
        backend.client.edits = (request) async {
          if (request.action == EditDraftAction.DELETE_EDIT_DRAFT) {
            return EditDraftReply();
          }
          if (scenario == 'restarted') {
            model.backend = TestBackend();
          }
          return EditDraftReply(
            drafts: [
              reviewed.deepCopy()
                ..state = scenario == 'changed'
                    ? 'UNKNOWN_OUTCOME'
                    : reviewed.state,
            ],
          );
        };
        if (scenario == 'staged' || scenario == 'unknown reviewed') {
          await model.discardRecoveryRecord(reviewed, process: backend);
          expect(
            backend.client.editRequests
                .where((r) => r.action == EditDraftAction.DELETE_EDIT_DRAFT)
                .single
                .draftId,
            'original',
          );
        } else {
          await expectLater(
            model.discardRecoveryRecord(reviewed, process: backend),
            throwsStateError,
          );
          expect(
            backend.client.editRequests.where(
              (r) => r.action == EditDraftAction.DELETE_EDIT_DRAFT,
            ),
            isEmpty,
          );
        }
        expect(backend.client.executions, isEmpty);
        expect(backend.client.sessionCommands, isEmpty);
      },
    );
  }

  for (final state in [
    'APPLYING',
    'UNKNOWN_OUTCOME',
    'backend changed',
    'STAGED',
  ]) {
    test(
      'recovery privacy acknowledges $state without replay or uncertain deletion',
      () async {
        final root = await Directory.systemTemp.createTemp(
          'busydata-recovery-privacy-',
        );
        final model = WorkbenchModel(root)
          ..newDocument(text: 'SELECT private_text;');
        final backend = TestBackend();
        model.backend = backend;
        addTearDown(() async {
          model.dispose();
          await root.delete(recursive: true);
        });
        await model.recoverNow();
        backend.client.edits = (request) async {
          if (request.action == EditDraftAction.DELETE_EDIT_DRAFT) {
            return EditDraftReply();
          }
          if (state == 'backend changed') {
            model.backend = TestBackend();
          }
          return EditDraftReply(
            drafts: [
              EditDraftInfo(
                draftId: 'original-private',
                state: state == 'backend changed' ? 'STAGED' : state,
              ),
            ],
          );
        };
        if (state == 'STAGED') {
          await model.setDraftRecovery(false);
          expect(model.draftRecovery, isFalse);
          expect(await File('${root.path}/drafts.json').exists(), isFalse);
          expect(
            backend.client.editRequests
                .where((r) => r.action == EditDraftAction.DELETE_EDIT_DRAFT)
                .single
                .draftId,
            'original-private',
          );
        } else {
          await expectLater(model.setDraftRecovery(false), throwsStateError);
          expect(model.draftRecovery, isTrue);
          expect(await File('${root.path}/drafts.json').exists(), isTrue);
          expect(
            backend.client.editRequests.where(
              (r) => r.action == EditDraftAction.DELETE_EDIT_DRAFT,
            ),
            isEmpty,
          );
        }
        expect(backend.client.executions, isEmpty);
        expect(model.document.editor.text, 'SELECT private_text;');
        expect(model.pendingOperations, 0);
      },
    );
  }
  test(
    'saving unchanged recovery preference preserves private records',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-recovery-unchanged-',
      );
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument();
      final backend = TestBackend();
      model.backend = backend;
      addTearDown(() async {
        model.dispose();
        await root.delete(recursive: true);
      });
      model.editDrafts.add(
        EditDraftInfo(draftId: 'unknown', state: 'UNKNOWN_OUTCOME'),
      );
      await model.setDraftRecovery(false);
      expect(model.editDrafts.single.draftId, 'unknown');
      expect(backend.client.editRequests, isEmpty);
    },
  );

  test(
    'staged recovery serializes captured batches and failed recovery prevents an ordinary close save',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-edit-recovery-',
      );
      final backend = TestBackend();
      final model = WorkbenchModel(root)..newDocument();
      model.backend = backend;
      addTearDown(() async {
        model.dispose();
        await root.delete(recursive: true);
      });
      model.stagedSession = 'physical';
      model.stagedResult = 'retained';
      model.stagedSchema = 'public';
      model.stagedTable = 'rows';
      model.stagedDocumentId = model.document.id;
      final batch = model.activeEditBatch;
      final recoveryStates = <(int, bool)>[];
      model.addListener(() {
        recoveryStates.add((batch.pendingRecovery, batch.saveError != null));
      });
      final first = Completer<EditDraftReply>();
      int saves = 0;
      backend.client.edits = (request) async {
        if (request.action == EditDraftAction.SAVE_EDIT_DRAFT) {
          if (saves++ == 0) return first.future;
          return EditDraftReply(
            drafts: [EditDraftInfo(draftId: 'owned-draft')],
          );
        }
        return EditDraftReply();
      };
      model.staged.add(
        StagedChange(
          kind: ChangeKind.UPDATE,
          values: ({1: Value(text: 'first')}.entries).map(
            (entry) =>
                MapEntry(entry.key, assignments.assignmentOf(entry.value)),
          ),
        ),
      );
      final saving = model.persistStagedEdits();
      await Future<void>.delayed(Duration.zero);
      model.staged.add(
        StagedChange(
          kind: ChangeKind.INSERT,
          values: ({1: Value(text: 'second')}.entries).map(
            (entry) =>
                MapEntry(entry.key, assignments.assignmentOf(entry.value)),
          ),
        ),
      );
      final newer = model.persistStagedEdits();
      await Future<void>.delayed(Duration.zero);
      expect(saves, 1);
      expect(backend.client.editRequests.first.changes.changes.length, 1);
      first.complete(
        EditDraftReply(drafts: [EditDraftInfo(draftId: 'owned-draft')]),
      );
      await saving;
      await newer;
      final recorded = backend.client.editRequests
          .where((r) => r.action == EditDraftAction.SAVE_EDIT_DRAFT)
          .toList();
      expect(recorded.last.draftId, 'owned-draft');
      expect(recorded.last.changes.changes.length, 2);
      expect(recoveryStates.last, (0, false));
      backend.client.edits = (_) async =>
          throw StateError('denied private metadata file');
      await expectLater(model.persistStagedEdits(), throwsStateError);
      await expectLater(model.awaitStagedSave(), throwsStateError);
      expect(recoveryStates.last, (0, true));
      await expectLater(model.recoverNow(), throwsStateError);
      expect(model.staged.length, 2);
    },
  );
  test(
    'rebinding is explicit and closing a target while recovering disposes only the unused result',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'busydata-edit-rebind-',
      );
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument();
      model.backend = backend;
      model.document.sessionId = 'new-physical';
      addTearDown(() async {
        model.dispose();
        await root.delete(recursive: true);
      });
      final opening = Completer<EditDraftReply>();
      backend.client.edits = (_) => opening.future;
      final target = model.document;
      final rebinding = model.rebindEditDraft(EditDraftInfo(draftId: 'draft'));
      model.documents.remove(target);
      model.newDocument();
      opening.complete(
        EditDraftReply(
          result: RetainedResult(result: StatementResult(resultId: 'unused')),
        ),
      );
      await expectLater(rebinding, throwsStateError);
      expect(model.staged, isEmpty);
      expect(backend.client.disposed.single, 'unused');
      target.dispose();
    },
  );
}
