import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../features/workspace/workbench_model.dart';
import '../../backend/backend_process.dart';
import 'workbench_presentation.dart';

/// BusyMark's lazy search-row reveal, restricted to the existing bounded
/// metadata/history page. A newer selection or focus owner retires the request.
Future<void> revealSearchRecord<K>({
  required ScrollController scroll,
  required Map<K, GlobalKey<WorkbenchRecordState>> keys,
  required K identity,
  required int index,
  required int Function(K) indexOf,
  required bool Function() current,
  required FocusNode? focusOwner,
  required bool takeFocus,
}) async {
  while (current() && scroll.hasClients) {
    final target = keys[identity]?.currentContext;
    if (target != null && target.mounted) {
      await Scrollable.ensureVisible(
        target,
        alignment: .5,
        duration: MediaQuery.disableAnimationsOf(target)
            ? Duration.zero
            : const Duration(milliseconds: 80),
      );
      if (current() &&
          takeFocus &&
          identical(FocusManager.instance.primaryFocus, focusOwner)) {
        keys[identity]?.currentState?.requestFocus();
      }
      return;
    }
    final mounted = keys.entries
        .where((entry) => entry.value.currentContext != null)
        .map((entry) => indexOf(entry.key))
        .where((value) => value >= 0);
    final first = mounted.isEmpty
        ? index
        : mounted.reduce((a, b) => a < b ? a : b);
    final position = scroll.position;
    final next =
        (position.pixels +
                position.viewportDimension * (index < first ? -.8 : .8))
            .clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) return;
    scroll.jumpTo(next);
    await WidgetsBinding.instance.endOfFrame;
  }
}

/// One global search interaction. Context is frozen before the header takes
/// focus. Category adapters retain their existing operation/inspection owners.
class WorkbenchSearchSession {
  final query = TextEditingController();
  final focus = FocusNode(debugLabel: 'Shared workbench search');
  final closeFocus = FocusNode(
    debugLabel: 'Workbench search close handoff',
    skipTraversal: true,
  );
  int focusRevision = 0;
  Completer<bool>? _pendingClose;
  bool Function()? _pendingRestore;
  bool _closeFrameObserved = false;
  WorkbenchCommandContext? target;
  CapturedWorkbenchTarget? executionTarget, objectsTarget;
  BackendConnection? backend;
  FocusNode? returnFocus;
  String category = 'actions';
  String error = '';
  bool replacing = false;
  Future<bool>? get pendingClose => _pendingClose?.future;

  int invalidateFocusHandoff() {
    focusRevision++;
    _pendingClose?.complete(false);
    _pendingClose = null;
    _pendingRestore = null;
    return focusRevision;
  }

  /// Observe the close rebuild without scheduling another frame. There is at
  /// most one pending restoration and one observer, even while frames pause.
  Future<bool> afterCloseFrame(bool Function() restore) {
    final completion = Completer<bool>();
    _pendingClose?.complete(false);
    _pendingClose = completion;
    _pendingRestore = restore;
    if (!_closeFrameObserved) {
      _closeFrameObserved = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _closeFrameObserved = false;
        final pending = _pendingClose;
        final action = _pendingRestore;
        _pendingClose = null;
        _pendingRestore = null;
        if (pending != null) {
          try {
            pending.complete(action?.call() ?? false);
          } catch (_) {
            pending.complete(false);
          }
        }
      });
    }
    return completion.future;
  }

  void dispose() {
    invalidateFocusHandoff();
    query.dispose();
    focus.dispose();
    closeFocus.dispose();
  }
}
