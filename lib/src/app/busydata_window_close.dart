import 'dart:async';

import 'package:flutter/widgets.dart';

typedef BusyDataWindowCloseHandler = FutureOr<bool> Function();

/// Coordinates destructive top-level window close requests with the active
/// modal surface that owns any transient editor state.
///
/// Handlers are ordered by presentation: the most recently mounted active
/// surface owns the decision. Concurrent close requests share one resolution
/// so they cannot open duplicate confirmation dialogs.
final class BusyDataWindowCloseCoordinator {
  final List<_BusyDataWindowCloseRegistration> _registrations = [];
  Future<bool>? _pendingRequest;

  bool get hasActiveHandler => _registrations.isNotEmpty;

  Future<bool> requestClose() {
    final pending = _pendingRequest;
    if (pending != null) return pending;

    final request = _resolveCloseRequest();
    _pendingRequest = request;
    return request.whenComplete(() {
      if (identical(_pendingRequest, request)) {
        _pendingRequest = null;
      }
    });
  }

  _BusyDataWindowCloseRegistration _register(
    BusyDataWindowCloseHandler handler,
  ) {
    final registration = _BusyDataWindowCloseRegistration(this, handler);
    _registrations.add(registration);
    return registration;
  }

  Future<bool> _resolveCloseRequest() async {
    if (_registrations case [..., final active]) {
      try {
        return await active.handler();
      } on Object catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'BusyData window close coordinator',
            context: ErrorDescription(
              'while asking the active surface to resolve a window close',
            ),
          ),
        );
        return false;
      }
    }
    return true;
  }

  void _unregister(_BusyDataWindowCloseRegistration registration) {
    _registrations.remove(registration);
  }
}

final class _BusyDataWindowCloseRegistration {
  _BusyDataWindowCloseRegistration(this._owner, this.handler);

  BusyDataWindowCloseCoordinator? _owner;
  final BusyDataWindowCloseHandler handler;

  void dispose() {
    _owner?._unregister(this);
    _owner = null;
  }
}

class BusyDataWindowCloseScope extends InheritedWidget {
  const BusyDataWindowCloseScope({
    super.key,
    required this.coordinator,
    required super.child,
  });

  final BusyDataWindowCloseCoordinator coordinator;

  static BusyDataWindowCloseCoordinator? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BusyDataWindowCloseScope>()
        ?.coordinator;
  }

  @override
  bool updateShouldNotify(BusyDataWindowCloseScope oldWidget) =>
      !identical(coordinator, oldWidget.coordinator);
}

/// Registers a close decision owned by an editor or modal surface while that
/// surface is mounted beneath [BusyDataWindowCloseScope].
class BusyDataWindowCloseGuard extends StatefulWidget {
  const BusyDataWindowCloseGuard({
    super.key,
    required this.onCloseRequested,
    required this.child,
  });

  final BusyDataWindowCloseHandler onCloseRequested;
  final Widget child;

  @override
  State<BusyDataWindowCloseGuard> createState() =>
      _BusyDataWindowCloseGuardState();
}

class _BusyDataWindowCloseGuardState extends State<BusyDataWindowCloseGuard> {
  BusyDataWindowCloseCoordinator? _coordinator;
  _BusyDataWindowCloseRegistration? _registration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = BusyDataWindowCloseScope.maybeOf(context);
    if (identical(coordinator, _coordinator)) return;
    _registration?.dispose();
    _coordinator = coordinator;
    _registration = coordinator?._register(() => widget.onCloseRequested());
  }

  @override
  void dispose() {
    _registration?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
