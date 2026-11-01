import 'package:flutter/material.dart';

import '../ui/common/modal_focus_restoration.dart';
import 'busydata_design.dart';
import 'busydata_shortcuts.dart';
import 'busydata_window_close.dart';

const _modalShortcuts = <ShortcutActivator, Intent>{
  BusyDataShortcutActivators.keyboardShortcuts:
      DoNothingAndStopPropagationIntent(),
  BusyDataShortcutActivators.settings: DoNothingAndStopPropagationIntent(),
  BusyDataShortcutActivators.back: DoNothingAndStopPropagationIntent(),
};

/// Prevents application-level navigation shortcuts from escaping a modal
/// surface while preserving shortcuts owned by that surface's descendants.
///
/// Use this for modal UI that is not presented by [showBusyDataModalDialog],
/// such as anchored popovers and in-page editor overlays.
class BusyDataModalShortcutBoundary extends StatelessWidget {
  const BusyDataModalShortcutBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(shortcuts: _modalShortcuts, child: child);
  }
}

Future<T?> showBusyDataModalDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  bool barrierDismissible = true,
}) async {
  final focus = ModalFocusRestoration.capture(context);
  final result = await _showBusyDataFlutterDialog<T>(
    context,
    builder: builder,
    barrierColor: barrierColor,
    barrierDismissible: barrierDismissible,
    onPopped: focus.restoreOnAcceptedPop,
  );
  // Retain valid final restoration if it could not be resolved at dismissal.
  // A newer route/leaf owner always wins, and restoration is requested once.
  focus.restoreAfterCompletion();
  return result;
}

Future<T?> _showBusyDataFlutterDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  bool barrierDismissible = true,
  required void Function(ModalRoute<dynamic>) onPopped,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final closeCoordinator = BusyDataWindowCloseScope.maybeOf(context);
  final route = _BusyDataDialogRoute<T>(
    context: context,
    builder: builder,
    themes: themes,
    closeCoordinator: closeCoordinator,
    fixedBarrierColor: barrierColor,
    initialBarrierColor: barrierColor ?? busyDataModalBarrierColor(context),
    barrierDismissible: barrierDismissible,
    onPopped: onPopped,
  );
  final result = await navigator.push<T>(route);
  await route.completed;
  return result;
}

class _BusyDataDialogRoute<T> extends DialogRoute<T> {
  _BusyDataDialogRoute({
    required super.context,
    required WidgetBuilder builder,
    required CapturedThemes themes,
    required BusyDataWindowCloseCoordinator? closeCoordinator,
    required Color? fixedBarrierColor,
    required Color initialBarrierColor,
    required super.barrierDismissible,
    required void Function(ModalRoute<dynamic>) onPopped,
  }) : _onPopped = onPopped,
       _fixedBarrierColor = fixedBarrierColor,
       _initialBarrierColor = initialBarrierColor,
       super(
         builder: (dialogContext) {
           final dialog = BusyDataWindowCloseGuard(
             onCloseRequested: () => false,
             child: BusyDataModalShortcutBoundary(
               child: builder(dialogContext),
             ),
           );
           return closeCoordinator == null
               ? dialog
               : BusyDataWindowCloseScope(
                   coordinator: closeCoordinator,
                   child: dialog,
                 );
         },
         themes: themes,
         barrierColor: initialBarrierColor,
         traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
       );

  final Color? _fixedBarrierColor;
  final Color _initialBarrierColor;
  final void Function(ModalRoute<dynamic>) _onPopped;

  @override
  bool didPop(T? result) {
    final accepted = super.didPop(result);
    if (accepted) _onPopped(this);
    return accepted;
  }

  /// Unlike [DialogRoute]'s constructor value, this getter is reevaluated
  /// when the Navigator's inherited theme changes.
  @override
  Color? get barrierColor {
    final fixedColor = _fixedBarrierColor;
    if (fixedColor != null) {
      return fixedColor;
    }
    final navigatorContext = navigator?.context;
    return navigatorContext == null
        ? _initialBarrierColor
        : busyDataModalBarrierColor(navigatorContext);
  }
}

Future<T?> showBusyDataModalEditorDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  Color? barrierColor,
  double maxWidth = BusyDataSizes.compactDetailsWidth,
  double? maxHeight = 760,
}) async {
  return showBusyDataModalDialog<T>(
    context,
    barrierColor: barrierColor,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BusyDataModalEditorSurface(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        insetPadding: const EdgeInsets.all(BusyDataSpacing.lg),
        child: builder(dialogContext),
      );
    },
  );
}

Future<String?> showBusyDataTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String actionLabel,
  String? initialValue,
  String? message,
  Color? barrierColor,
}) {
  return showBusyDataModalDialog<String>(
    context,
    barrierColor: barrierColor,
    barrierDismissible: false,
    builder: (dialogContext) => BusyDataPromptDialog(
      title: title,
      label: label,
      actionLabel: actionLabel,
      initialValue: initialValue,
      message: message,
    ),
  );
}

Future<bool> showBusyDataConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  Color? barrierColor,
}) async {
  final confirmed = await showBusyDataModalDialog<bool>(
    context,
    barrierColor: barrierColor,
    builder: (dialogContext) => BusyDataConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
  return confirmed == true;
}
