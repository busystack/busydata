import '../../l10n/workbench_strings.dart';
import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart';
import '../../features/workspace/workbench_model.dart';
import 'desktop_controls.dart';

class PendingWorkbenchWork {
  PendingWorkbenchWork(WorkbenchModel model)
    : operations = model.pendingOperations,
      documents = model.workbenchDocuments
          .where((document) => document.dirty)
          .length,
      saves = model.documents.where((document) => document.saving).length,
      edits = model.pendingEditCount,
      jobs = model.jobs.values
          .where(
            (job) => const {
              JobState.QUEUED,
              JobState.EXECUTING,
              JobState.FETCHING,
              JobState.CANCELLING,
            }.contains(job.state),
          )
          .length,
      transactions = model.sessions.values
          .where(
            (session) =>
                session.transaction == TransactionState.ACTIVE ||
                session.transaction == TransactionState.FAILED_TRANSACTION,
          )
          .length,
      uncertain = model.jobs.values
          .where((job) => job.state == JobState.UNKNOWN_OUTCOME)
          .length,
      uncertainSessions = model.sessions.values
          .where(
            (session) =>
                session.transaction == TransactionState.UNKNOWN_TRANSACTION,
          )
          .length;
  final int operations,
      documents,
      saves,
      edits,
      jobs,
      transactions,
      uncertain,
      uncertainSessions;
  bool get pending =>
      operations +
          documents +
          saves +
          edits +
          jobs +
          transactions +
          uncertain +
          uncertainSessions >
      0;

  String describe(BuildContext context, WorkbenchModel model) {
    final l = strings(context);
    return '${l.closeWorkCounts('$operations', '$documents', '$saves', '$edits', '$jobs', '$transactions', '$uncertain', '$uncertainSessions')}\n'
        '${model.backend != null && !model.backendStatusVerified ? '${l.closeBackendUnverified}\n' : ''}'
        '${model.draftRecovery ? l.closeDraftSaved : l.closeDraftLost}\n'
        '${model.draftRecovery && model.taskDocuments.any((d) => d.dirty) ? '${l.closeDesignRecovery}\n' : ''}'
        '${l.closeCleanupReview}';
  }
}

Future<bool> requestWorkbenchClose(
  BuildContext context,
  WorkbenchModel model,
  DesktopControls controls,
) async {
  if (model.isDisposed || !context.mounted) return false;
  final reviewSettings = model.reviewSettingsDeparture;
  if (reviewSettings != null && !await reviewSettings()) return false;
  if (model.isDisposed || !context.mounted) return false;
  final l = strings(context);
  if (model.pendingOperations != 0) {
    model.updateStatus(l.closeWaitNotice);
    return false;
  }
  bool saveFailed = false;
  try {
    await Future.wait(
      model.documents.map((document) => document.savesFinished),
    );
  } catch (_) {
    saveFailed = true;
    model.updateStatus(l.saveFailedNotice);
  }
  if (model.isDisposed || !context.mounted) return false;
  await model.poll();
  if (model.isDisposed || !context.mounted) return false;
  if (saveFailed ||
      PendingWorkbenchWork(model).pending ||
      (model.backend != null && !model.backendStatusVerified)) {
    final approved = await controls.dialog<bool>(
      context,
      saveFailed ? l.saveFailedCloseTitle : strings(context).closeBusyData,
      ListenableBuilder(
        listenable: model,
        builder: (context, _) =>
            Text(PendingWorkbenchWork(model).describe(context, model)),
      ),
      [
        controls.button(
          strings(context).stay,
          () => Navigator.of(context).pop(false),
        ),
        controls.button(
          saveFailed
              ? strings(context).discardFailedSaveClose
              : model.draftRecovery
              ? strings(context).saveDraftsClose
              : strings(context).closeWithoutRecovery,
          () => Navigator.of(context).pop(true),
          destructive: saveFailed || !model.draftRecovery,
        ),
      ],
    );
    if (approved != true || model.isDisposed || !context.mounted) return false;
  }
  try {
    await model.savePresentation();
    if (model.isDisposed || !context.mounted) return false;
    await model.recoverNow();
  } catch (_) {
    if (model.isDisposed || !context.mounted) return false;
    model.updateStatus(l.closeRecoveryLoss);
    final discard = await controls.dialog<bool>(
      context,
      strings(context).recoveryFailed,
      Text(l.closeRecoveryLoss),
      [
        controls.button(
          strings(context).stay,
          () => Navigator.of(context).pop(false),
        ),
        controls.button(
          strings(context).closeWithoutSavingRecovery,
          () => Navigator.of(context).pop(true),
          destructive: true,
        ),
      ],
    );
    if (model.isDisposed || !context.mounted) return false;
    if (discard != true) {
      model.updateStatus(l.recoveryStayOpen);
      return false;
    }
  }
  if (model.isDisposed || !context.mounted) return false;
  try {
    await model.backend?.close();
    return !model.isDisposed;
  } catch (_) {
    model.updateStatus(l.closeCleanupFailed);
    return false;
  }
}
