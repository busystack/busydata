import 'package:flutter/widgets.dart';

/// Returns focus once to a captured modal origin, unless a newer owner wins.
class ModalFocusRestoration {
  factory ModalFocusRestoration.capture(BuildContext context) {
    final previousFocus = FocusManager.instance.primaryFocus;
    return ModalFocusRestoration._(
      previousFocus,
      ModalRoute.of(previousFocus?.context ?? context),
      previousFocus?.enclosingScope,
    );
  }

  ModalFocusRestoration._(
    this._previousFocus,
    this._previousRoute,
    this._previousScope,
  );

  final FocusNode? _previousFocus;
  final ModalRoute<dynamic>? _previousRoute;
  final FocusScopeNode? _previousScope;
  bool _restored = false;

  void restoreOnAcceptedPop(ModalRoute<dynamic> route) => _restore(route);

  void restoreAfterCompletion() => _restore(null);

  void _restore(ModalRoute<dynamic>? retiringRoute) {
    final previousFocus = _previousFocus;
    final previousRoute = _previousRoute;
    final previousScope = _previousScope;
    // During didPop the accepted top route is still marked current until
    // Navigator finishes updating its history synchronously.
    final acceptingCurrentPop = retiringRoute?.isCurrent == true;
    if (_restored ||
        (previousRoute?.isCurrent == false && !acceptingCurrentPop) ||
        previousFocus?.context?.mounted != true ||
        !previousFocus!.canRequestFocus) {
      return;
    }
    // Apply a newer intentional request before deciding who owns focus. It
    // must not be overwritten just because its notification is still pending.
    FocusManager.instance.applyFocusChangesIfNeeded();
    final current = FocusManager.instance.primaryFocus;
    final currentRoute = current?.context == null
        ? null
        : ModalRoute.of(current!.context!);
    final retiringOwnsFocus =
        retiringRoute != null &&
        (acceptingCurrentPop || !retiringRoute.isActive) &&
        identical(currentRoute, retiringRoute);
    if (current != null &&
        !identical(current, previousScope) &&
        !identical(current, previousFocus) &&
        !retiringOwnsFocus) {
      return;
    }
    _restored = true;
    if (!identical(current, previousFocus)) {
      previousFocus.requestFocus();
    }
    // Native key events can arrive before the next frame. Resolve the valid
    // owner's pending focus at route dismissal, rather than leave a shortcut
    // attached to an inactive dialog while its exit animation runs.
    FocusManager.instance.applyFocusChangesIfNeeded();
  }
}
