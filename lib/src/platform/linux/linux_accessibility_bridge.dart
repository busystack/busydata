import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../ui/common/accessibility_text_geometry.dart';
import 'linux_accessibility_binding.dart';

/// A presentation-only boundary. No application controller or database model is
/// retained here. GTK receives public semantics and owns its own ATK objects.
class LinuxAccessibilityBridge with WidgetsBindingObserver {
  LinuxAccessibilityBridge({
    MethodChannel channel = const MethodChannel(
      'io.busystack.busydata/accessibility',
    ),
    RendererBinding? renderer,
  }) : _channel = channel,
       _renderer = renderer ?? RendererBinding.instance;

  static const version = 1;
  static const maxNodes = 16384;
  static const maxDepth = 128;
  static const maxTextUnits = 1048576;
  static const maxEncodedBytes = 8 * 1024 * 1024;
  static const maxPendingActions = 32;
  static const actionLifetime = Duration(seconds: 2);
  // The native contract owns one physical FlView. A replacement scope retires
  // its predecessor before taking the shared channel's callback ownership.
  static LinuxAccessibilityBridge? _active;
  final MethodChannel _channel;
  final RendererBinding _renderer;
  SemanticsHandle? _semantics;
  RenderView? _view;
  SemanticsOwner? _owner;
  LinuxAccessibilityProjection? _current;
  LinuxAccessibilityProjection? _issued;
  int _bridgeEpoch = 0, _ownerEpoch = 0, _revision = 0, _pending = 0;
  bool _started = false, _disposed = false, _dirty = false, _sending = false;
  bool _scheduled = false, _transportFailed = false;
  Future<void>? _flight;
  final Set<Completer<void>> _waiters = {};
  String _status = 'unavailable';
  String get status => _status;

  /// Acknowledged guards only. A bounded issued candidate can serve an exact
  /// native action before the publication reply reaches this isolate.
  int get currentNodeCount => _current?._nodes.length ?? 0;

  void start() {
    if (_started || _disposed) return;
    LinuxAccessibilityBinding.requireOwnedOutput(WidgetsBinding.instance);
    _active?.dispose();
    _active = this;
    _started = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return _reply('malformed');
      return dispatchAction(call.arguments);
    });
    WidgetsBinding.instance.addObserver(this);
    _semantics = SemanticsBinding.instance.ensureSemantics();
    WidgetsBinding.instance.addPostFrameCallback(_frame);
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _frame(Duration _) {
    if (_disposed || _transportFailed) return;
    _syncView();
    if (_dirty && !_sending) _changed();
    // This watches frames requested by the application. It does not request an
    // animation or keep producing frames while the application is idle.
    WidgetsBinding.instance.addPostFrameCallback(_frame);
  }

  @override
  void didChangeMetrics() {
    if (_disposed || _transportFailed) return;
    ++_revision;
    _dirty = true;
    _current = null;
    _issued = null;
    // The next rendered frame supplies acknowledged geometry. Never publish
    // the old semantics rectangles against a newly resized native allocation.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _syncView() {
    if (_disposed || _transportFailed) return;
    final views = _renderer.renderViews.toList(growable: false);
    final next = views.length == 1 ? views.single : null;
    if (!identical(_view, next)) {
      final previous = _view;
      final epoch = _bridgeEpoch;
      _owner?.removeListener(_changed);
      _owner = null;
      _view = next;
      _current = null;
      _issued = null;
      _bridgeEpoch = 0;
      ++_ownerEpoch;
      ++_revision;
      if (previous != null && epoch > 0) {
        unawaited(_detach(previous.flutterView.viewId, epoch));
      }
      _changed();
    }
    final owner = next?.owner?.semanticsOwner;
    if (!identical(owner, _owner)) {
      _owner?.removeListener(_changed);
      _owner = owner;
      owner?.addListener(_changed);
      _current = null;
      _issued = null;
      ++_ownerEpoch;
      _changed();
    }
  }

  void _changed() {
    if (_disposed || _transportFailed) return;
    ++_revision;
    _current = null;
    _issued = null;
    _dirty = true;
    for (final waiter in _waiters.toList(growable: false)) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
    if (_scheduled || _sending) return;
    _scheduled = true;
    scheduleMicrotask(() {
      _scheduled = false;
      if (!_disposed && !_sending) {
        _flight = _publish();
      }
    });
  }

  /// Completes after the currently requested presentation has been sent. This
  /// does not acknowledge delivery of a user edit or a database operation.
  Future<void> synchronize() async {
    _syncView();
    if (_dirty && !_sending) _flight = _publish();
    await _flight;
  }

  Future<Object?> _invoke(
    String method,
    Map<String, Object?> args, {
    LinuxAccessibilityProjection? candidate,
  }) async {
    final encoded = _channel.codec.encodeMethodCall(MethodCall(method, args));
    if (encoded.lengthInBytes > maxEncodedBytes) {
      throw const _ProjectionFailure('limited', 'encoded-limit');
    }
    // Native can install this snapshot and send an exact action before its
    // publication reply is delivered. Admission begins only after wire bounds
    // pass and immediately before the public channel send.
    if (method == 'publish') _issued = candidate;
    final pending = _channel.binaryMessenger.send(_channel.name, encoded);
    if (pending == null) throw MissingPluginException();
    final reply = await pending.timeout(actionLifetime);
    if (reply == null) throw MissingPluginException();
    return _channel.codec.decodeEnvelope(reply);
  }

  bool _validReply(Object? reply, {int? epoch}) =>
      reply is Map &&
      reply['version'] is int &&
      reply['version'] == version &&
      reply['status'] == 'ok' &&
      reply['bridgeEpoch'] is int &&
      (reply['bridgeEpoch'] as int) > 0 &&
      (epoch == null || reply['bridgeEpoch'] == epoch);

  Future<void> _publish() async {
    if (_sending || _disposed || _transportFailed || !_dirty) return;
    final view = _view;
    if (view == null) return;
    _sending = true;
    _dirty = false;
    try {
      if (_bridgeEpoch == 0) {
        final attached = await _invoke('attach', {
          'version': version,
          'viewId': view.flutterView.viewId,
        });
        if (_disposed || !identical(view, _view)) return;
        if (!_validReply(attached)) {
          _disableTransport();
          return;
        }
        _bridgeEpoch = (attached as Map)['bridgeEpoch'] as int;
      }
      final owner = _owner;
      final revision = _revision;
      final ownerEpoch = _ownerEpoch;
      final root = owner?.rootSemanticsNode;
      LinuxAccessibilityProjection? captured;
      Map<String, Object?> body;
      try {
        if (owner == null || root == null) {
          throw const _ProjectionFailure(
            'unavailable',
            'semantics-unavailable',
          );
        }
        captured = LinuxAccessibilityProjection.capture(
          owner: owner,
          root: root,
          bridgeEpoch: _bridgeEpoch,
          viewId: view.flutterView.viewId,
          ownerEpoch: ownerEpoch,
          revision: revision,
          viewSize: view.size,
          devicePixelRatio: view.flutterView.devicePixelRatio,
        );
        body = captured.message;
        // Encoding once below also checks the exact StandardMethodCodec cap.
      } on _ProjectionFailure catch (failure) {
        body = _unavailable(view, failure.status, failure.reason);
      }
      Object? reply;
      try {
        reply = await _invoke('publish', body, candidate: captured);
      } on _ProjectionFailure catch (failure) {
        captured = null;
        body = _unavailable(view, failure.status, failure.reason);
        reply = await _invoke('publish', body);
      }
      if (_disposed ||
          !identical(view, _view) ||
          ownerEpoch != _ownerEpoch ||
          revision != _revision) {
        return;
      }
      if (!_validReply(reply, epoch: _bridgeEpoch)) {
        _disableTransport();
      } else {
        _current = captured;
        _status = body['status'] as String;
      }
    } on MissingPluginException {
      _disableTransport();
    } on PlatformException {
      _disableTransport();
    } on TimeoutException {
      _disableTransport();
    } finally {
      _issued = null;
      _sending = false;
      if (_dirty && !_disposed && !_transportFailed) _changed();
    }
  }

  void _disableTransport() {
    _current = null;
    _issued = null;
    _status = 'unavailable';
    _transportFailed = true;
    final view = _view;
    _owner?.removeListener(_changed);
    _owner = null;
    _view = null;
    WidgetsBinding.instance.removeObserver(this);
    if (view != null && _bridgeEpoch > 0) {
      unawaited(_detach(view.flutterView.viewId, _bridgeEpoch));
    }
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
  }

  Map<String, Object?> _unavailable(
    RenderView view,
    String status,
    String reason,
  ) => {
    'version': version,
    'bridgeEpoch': _bridgeEpoch,
    'viewId': view.flutterView.viewId,
    'ownerEpoch': _ownerEpoch,
    'revision': _revision,
    'status': status,
    'reason': reason,
    'rootId': -1,
    'viewWidth': view.size.width,
    'viewHeight': view.size.height,
    'nodes': <Object?>[],
  };

  Map<String, Object?> _reply(String status) => {
    'version': version,
    'status': status,
    'bridgeEpoch': _bridgeEpoch,
    'viewId': _view?.flutterView.viewId ?? -1,
    'ownerEpoch': _ownerEpoch,
    'revision': _revision,
  };

  /// The same strict entry point serves the native method channel and component
  /// tests. An acknowledgment means dispatch only, never successful editing.
  Future<Map<String, Object?>> dispatchAction(Object? arguments) async {
    if (_disposed) return _reply('disposed');
    if (_pending >= maxPendingActions) return _reply('limited');
    final current = _current ?? _issued;
    final owner = _owner;
    if (arguments is! Map ||
        arguments.length != 8 ||
        arguments.keys.any((key) => !_actionKeys.contains(key)) ||
        arguments['version'] is! int ||
        arguments['version'] != version ||
        const [
          'bridgeEpoch',
          'viewId',
          'ownerEpoch',
          'revision',
          'nodeId',
        ].any((key) => arguments[key] is! int) ||
        arguments['action'] is! String ||
        !arguments.containsKey('args')) {
      return _reply('malformed');
    }
    if (current == null ||
        owner == null ||
        arguments['bridgeEpoch'] != _bridgeEpoch ||
        arguments['viewId'] != _view?.flutterView.viewId ||
        arguments['ownerEpoch'] != _ownerEpoch ||
        arguments['revision'] != _revision ||
        current.revision != _revision) {
      return _reply('stale');
    }
    final guard = current._nodes[arguments['nodeId']];
    if (guard == null || !guard.current(owner)) return _reply('stale');
    final action = arguments['action'] as String;
    final args = arguments['args'];
    final permit = _ActionPermit(
      _bridgeEpoch,
      _ownerEpoch,
      _view!.flutterView.viewId,
    );
    ++_pending;
    try {
      final operation = _dispatch(current, guard, owner, action, args, permit);
      final status = await operation.timeout(actionLifetime);
      return _reply(status);
    } on TimeoutException {
      return _reply('cancelled');
    } on _ProjectionFailure catch (failure) {
      return _reply(failure.status);
    } finally {
      permit.active = false;
      --_pending;
    }
  }

  Future<String> _dispatch(
    LinuxAccessibilityProjection projection,
    _NodeGuard guard,
    SemanticsOwner owner,
    String name,
    Object? args,
    _ActionPermit permit,
  ) async {
    if (const {
      'copyRange',
      'cutRange',
      'pasteAt',
      'insertText',
      'deleteRange',
    }.contains(name)) {
      return _compound(projection, guard, owner, name, args, permit);
    }
    final action = _actions[name];
    if (action == null) return 'malformed';
    if (!guard.permits(action)) return 'unavailable';
    final value = guard.data.value;
    if (action == SemanticsAction.setSelection) {
      if (args is! Map ||
          args.length != 2 ||
          !_offset(value, args['base']) ||
          !_offset(value, args['extent'])) {
        return 'malformed';
      }
    } else if (action == SemanticsAction.setText) {
      if (args is! String ||
          args.length > maxTextUnits ||
          _textStatus(args) != 'available') {
        return 'malformed';
      }
    } else if (_movement.contains(name)) {
      if (args is! bool) return 'malformed';
    } else if (args != null) {
      return 'malformed';
    }
    if (!guard.current(owner) || !_activeProjection(projection)) {
      return 'stale';
    }
    owner.performAction(guard.node.id, action, args);
    return 'ok';
  }

  Future<String> _compound(
    LinuxAccessibilityProjection projection,
    _NodeGuard guard,
    SemanticsOwner owner,
    String action,
    Object? args,
    _ActionPermit permit,
  ) async {
    if (args is! Map ||
        args.length != 3 ||
        args['text'] is! String ||
        !_offset(guard.data.value, args['start']) ||
        !_offset(guard.data.value, args['end'])) {
      return 'malformed';
    }
    final start = args['start'] as int, end = args['end'] as int;
    final text = args['text'] as String, original = guard.data.value;
    if (end < start || _textStatus(text) != 'available') return 'malformed';
    if (!guard.permits(SemanticsAction.setSelection)) return 'unavailable';
    if (action == 'insertText' || action == 'deleteRange') {
      if (!guard.permits(SemanticsAction.setText) || guard.password) {
        return 'unavailable';
      }
      if ((action == 'insertText' && start != end) ||
          (action == 'deleteRange' && text.isNotEmpty) ||
          text.length > maxTextUnits - (original.length - (end - start))) {
        return 'malformed';
      }
      final changed = original.replaceRange(start, end, text);
      owner.performAction(guard.node.id, SemanticsAction.setText, changed);
      final caret = start + text.length;
      final status = await _awaitNode(
        guard,
        owner,
        permit,
        value: changed,
        previousValue: original,
      );
      if (status != 'ok') return status;
      final state = _compoundState(guard, owner, permit);
      if (state.failure != null) return state.failure!;
      final after = state.data!;
      if (after.value != changed) return 'stale';
      if (!_NodeGuard(
        guard.node,
        after,
        _textStatus(after.value),
      ).permits(SemanticsAction.setSelection)) {
        return 'unavailable';
      }
      owner.performAction(guard.node.id, SemanticsAction.setSelection, {
        'base': caret,
        'extent': caret,
      });
      return 'ok';
    }
    final operation = switch (action) {
      'copyRange' => SemanticsAction.copy,
      'cutRange' => SemanticsAction.cut,
      'pasteAt' => SemanticsAction.paste,
      _ => null,
    };
    if (operation == null || !guard.permits(operation) || text.isNotEmpty) {
      return 'unavailable';
    }
    if (action == 'pasteAt' && start != end) return 'malformed';
    if (action != 'pasteAt' && start == end) return 'unavailable';
    if (!guard.current(owner) || !_activeProjection(projection)) {
      return 'stale';
    }
    owner.performAction(guard.node.id, SemanticsAction.setSelection, {
      'base': start,
      'extent': end,
    });
    final status = await _awaitNode(
      guard,
      owner,
      permit,
      value: original,
      base: start,
      extent: end,
    );
    if (status != 'ok') return status;
    final state = _compoundState(guard, owner, permit);
    if (state.failure != null) return state.failure!;
    final data = state.data!;
    if (data.value != original ||
        data.textSelection?.baseOffset != start ||
        data.textSelection?.extentOffset != end) {
      return 'stale';
    }
    if (!_NodeGuard(
      guard.node,
      data,
      _textStatus(data.value),
    ).permits(operation)) {
      return 'unavailable';
    }
    owner.performAction(guard.node.id, operation);
    return 'ok';
  }

  ({SemanticsData? data, String? failure}) _compoundState(
    _NodeGuard guard,
    SemanticsOwner owner,
    _ActionPermit permit,
  ) {
    if (_disposed) return (data: null, failure: 'disposed');
    if (!_owns(permit) ||
        !identical(owner, _owner) ||
        !identical(owner.getSemanticsNode(guard.node.id), guard.node)) {
      return (data: null, failure: 'stale');
    }
    if (!permit.current) return (data: null, failure: 'cancelled');
    final data = guard.node.getSemanticsData();
    if (data.flagsCollection.isHidden ||
        data.flagsCollection.isEnabled == ui.Tristate.isFalse ||
        data.flagsCollection.isObscured != guard.password) {
      return (data: null, failure: 'unavailable');
    }
    if (data.identifier != guard.data.identifier ||
        data.role != guard.data.role) {
      return (data: null, failure: 'stale');
    }
    // A field's presentation label can describe the caret/selection changed by
    // this admitted operation. It is not the identity of that live field.
    return (data: data, failure: null);
  }

  Future<String> _awaitNode(
    _NodeGuard guard,
    SemanticsOwner owner,
    _ActionPermit permit, {
    required String value,
    String? previousValue,
    int? base,
    int? extent,
  }) async {
    while (true) {
      final state = _compoundState(guard, owner, permit);
      if (state.failure != null) return state.failure!;
      final data = state.data!;
      if (data.value != value && data.value != previousValue) {
        return 'stale';
      }
      if (data.value == value &&
          (base == null ||
              (data.textSelection?.baseOffset == base &&
                  data.textSelection?.extentOffset == extent))) {
        return 'ok';
      }
      final remaining = actionLifetime - permit.clock.elapsed;
      if (remaining <= Duration.zero) return 'cancelled';
      final waiter = Completer<void>();
      _waiters.add(waiter);
      try {
        await waiter.future.timeout(remaining);
      } finally {
        _waiters.remove(waiter);
      }
    }
  }

  bool _owns(_ActionPermit permit) =>
      permit.bridgeEpoch == _bridgeEpoch &&
      permit.ownerEpoch == _ownerEpoch &&
      permit.viewId == _view?.flutterView.viewId;

  bool _activeProjection(LinuxAccessibilityProjection projection) =>
      projection.revision == _revision &&
      (identical(projection, _current) || identical(projection, _issued));

  Future<void> _detach(int viewId, int epoch) async {
    try {
      await _invoke('detach', {
        'version': version,
        'viewId': viewId,
        'bridgeEpoch': epoch,
      });
    } on MissingPluginException {
      // The native host has already retired.
    } on PlatformException {
      // A retired host cannot accept a detach.
    } on TimeoutException {
      // Do not retain or retry a dead native owner.
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _owner?.removeListener(_changed);
    _semantics?.dispose();
    _semantics = null;
    WidgetsBinding.instance.removeObserver(this);
    if (identical(_active, this)) {
      _active = null;
      _channel.setMethodCallHandler(null);
    }
    final view = _view;
    if (view != null && _bridgeEpoch > 0) {
      unawaited(_detach(view.flutterView.viewId, _bridgeEpoch));
    }
    _current = null;
    _issued = null;
    _owner = null;
    _view = null;
    for (final waiter in _waiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _waiters.clear();
  }
}

/// Creates a bounded immutable presentation using only public semantics APIs.
class LinuxAccessibilityProjection {
  LinuxAccessibilityProjection._(this.message, this._nodes, this.revision);
  final Map<String, Object?> message;
  final Map<int, _NodeGuard> _nodes;
  final int revision;

  static LinuxAccessibilityProjection capture({
    required SemanticsOwner owner,
    required SemanticsNode root,
    required int bridgeEpoch,
    required int viewId,
    required int ownerEpoch,
    required int revision,
    required Size viewSize,
    double devicePixelRatio = 1,
  }) {
    if (!devicePixelRatio.isFinite ||
        devicePixelRatio <= 0 ||
        !viewSize.width.isFinite ||
        !viewSize.height.isFinite ||
        viewSize.width < 0 ||
        viewSize.height < 0) {
      throw const _ProjectionFailure('unavailable', 'invalid-geometry');
    }
    var textUnits = 0;
    final seen = <int>{};
    final preflight = <(SemanticsNode, int)>[(root, 0)];
    while (preflight.isNotEmpty) {
      final (node, depth) = preflight.removeLast();
      if (!identical(node.owner, owner) ||
          !identical(owner.getSemanticsNode(node.id), node)) {
        throw const _ProjectionFailure('unavailable', 'invalid-tree');
      }
      if (depth > LinuxAccessibilityBridge.maxDepth ||
          seen.length >= LinuxAccessibilityBridge.maxNodes) {
        throw const _ProjectionFailure('limited', 'node-limit');
      }
      if (!seen.add(node.id)) {
        throw const _ProjectionFailure('unavailable', 'invalid-tree');
      }
      for (final text in [node.label, node.value, node.hint, node.tooltip]) {
        textUnits += text.length;
        if (textUnits > LinuxAccessibilityBridge.maxTextUnits) {
          throw const _ProjectionFailure('limited', 'text-limit');
        }
      }
      node.visitChildren((child) {
        preflight.add((child, depth + 1));
        return true;
      });
    }
    final records = <Map<String, Object?>>[], guards = <int, _NodeGuard>{};
    final pending = <(SemanticsNode, int, Matrix4)>[
      (
        root,
        -1,
        Matrix4.diagonal3Values(1 / devicePixelRatio, 1 / devicePixelRatio, 1),
      ),
    ];
    textUnits = 0;
    while (pending.isNotEmpty) {
      final (node, parentId, parentTransform) = pending.removeLast();
      final data = node.getSemanticsData();
      final transform = parentTransform.clone();
      if (data.transform != null) transform.multiply(data.transform!);
      final bounds = MatrixUtils.transformRect(transform, data.rect);
      if (![
            bounds.left,
            bounds.top,
            bounds.width,
            bounds.height,
          ].every((n) => n.isFinite) ||
          bounds.width < 0 ||
          bounds.height < 0) {
        throw const _ProjectionFailure('unavailable', 'invalid-geometry');
      }
      var status = 'available';
      for (final text in [
        data.identifier,
        data.label,
        data.value,
        data.hint,
        data.tooltip,
      ]) {
        textUnits += text.length;
        if (textUnits > LinuxAccessibilityBridge.maxTextUnits) {
          throw const _ProjectionFailure('limited', 'text-limit');
        }
        final check = _textStatus(text);
        if (check != 'available') status = check;
      }
      final flags = data.flagsCollection;
      final guard = _NodeGuard(node, data, status);
      guards[node.id] = guard;
      final children = <SemanticsNode>[];
      if (!node.mergeAllDescendantsIntoThisNode) {
        node.visitChildren((child) {
          if (!child.isMergedIntoParent) children.add(child);
          return true;
        });
      }
      final keys = children.map((n) => n.sortKey).toList(growable: false);
      if (keys.isNotEmpty &&
          keys.first != null &&
          keys.every(
            (key) =>
                key?.runtimeType == keys.first.runtimeType &&
                key?.name == keys.first!.name,
          )) {
        final order = {
          for (var i = 0; i < children.length; ++i) children[i]: i,
        };
        children.sort((a, b) {
          final compared = a.sortKey!.compareTo(b.sortKey!);
          return compared != 0 ? compared : order[a]!.compareTo(order[b]!);
        });
      }
      for (final child in children.reversed) {
        pending.add((child, node.id, transform));
      }
      final selection = data.textSelection;
      final representable = status == 'available';
      final textGeometry = representable && !flags.isObscured
          ? AccessibilityTextGeometry.capture(node)
          : null;
      final value = flags.isObscured ? '•' * data.value.length : data.value;
      records.add({
        'id': node.id,
        'parentId': parentId,
        'children': [for (final child in children) child.id],
        'identifier': representable ? data.identifier : '',
        'label': representable ? data.label : '',
        'value': representable ? value : '',
        'hint': representable ? data.hint : '',
        'tooltip': representable ? data.tooltip : '',
        'role': data.role.name,
        'actions': [
          for (final action in _actions.values)
            if (guard.permits(action)) action.name,
        ],
        'flags': {
          'enabled': flags.isEnabled.toBoolOrNull(),
          'focusable':
              flags.isFocused != ui.Tristate.none ||
              data.actions & SemanticsAction.focus.index != 0,
          'focused': flags.isFocused.toBoolOrNull(),
          'selected': flags.isSelected.toBoolOrNull(),
          'checked': switch (flags.isChecked) {
            ui.CheckedState.isTrue => true,
            ui.CheckedState.isFalse => false,
            _ => null,
          },
          'mixed': flags.isChecked == ui.CheckedState.none
              ? null
              : flags.isChecked == ui.CheckedState.mixed,
          'expanded': flags.isExpanded.toBoolOrNull(),
          'readOnly': flags.isReadOnly,
          'textField': flags.isTextField,
          'password': flags.isObscured,
          'multiline': flags.isMultiline,
          'hidden': flags.isHidden,
          'link': flags.isLink,
          'button': flags.isButton,
          'liveRegion': flags.isLiveRegion,
          'header': flags.isHeader,
          'toggled': flags.isToggled.toBoolOrNull(),
        },
        'selectionBase':
            representable &&
                selection != null &&
                _offset(value, selection.baseOffset)
            ? selection.baseOffset
            : -1,
        'selectionExtent':
            representable &&
                selection != null &&
                _offset(value, selection.extentOffset)
            ? selection.extentOffset
            : -1,
        'rect': [bounds.left, bounds.top, bounds.width, bounds.height],
        'direction': data.textDirection?.name ?? 'unknown',
        'treeLevel': _treeLevel(data.identifier),
        'textStatus': status,
        'geometryPrecision': textGeometry == null
            ? 'field-bounds'
            : 'glyph-bounds',
        'textGeometry': ?textGeometry,
      });
    }
    return LinuxAccessibilityProjection._(
      _immutable({
            'version': LinuxAccessibilityBridge.version,
            'bridgeEpoch': bridgeEpoch,
            'viewId': viewId,
            'ownerEpoch': ownerEpoch,
            'revision': revision,
            'rootId': root.id,
            'viewWidth': viewSize.width,
            'viewHeight': viewSize.height,
            'status': 'ok',
            'reason': '',
            'nodes': List.unmodifiable(records),
          })
          as Map<String, Object?>,
      Map.unmodifiable(guards),
      revision,
    );
  }
}

class _NodeGuard {
  const _NodeGuard(this.node, this.data, this.textStatus);
  final SemanticsNode node;
  final SemanticsData data;
  final String textStatus;
  bool get password => data.flagsCollection.isObscured;
  bool current(SemanticsOwner owner) =>
      identical(owner.getSemanticsNode(node.id), node) &&
      data == node.getSemanticsData();
  bool permits(SemanticsAction action) {
    // RenderObject semantics provide a default showOnScreen handler through
    // SemanticsOwner.performAction even without an explicit action bit. Reveal
    // does not grant focus or text-edit permission to a still-hidden node.
    if ((action != SemanticsAction.showOnScreen &&
            data.actions & action.index == 0) ||
        (data.flagsCollection.isHidden &&
            action != SemanticsAction.showOnScreen) ||
        data.flagsCollection.isEnabled == ui.Tristate.isFalse) {
      return false;
    }
    if (password &&
        (action == SemanticsAction.copy || action == SemanticsAction.cut)) {
      return false;
    }
    if (data.flagsCollection.isReadOnly &&
        const [
          SemanticsAction.setText,
          SemanticsAction.cut,
          SemanticsAction.paste,
        ].contains(action)) {
      return false;
    }
    if (textStatus != 'available' && _textActions.contains(action.name)) {
      return false;
    }
    return true;
  }
}

Object? _immutable(Object? value) {
  if (value is Map<String, Object?>) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries) entry.key: _immutable(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_immutable));
  }
  return value;
}

const _movement = {
  'moveCursorForwardByCharacter',
  'moveCursorBackwardByCharacter',
  'moveCursorForwardByWord',
  'moveCursorBackwardByWord',
};
const _actionKeys = {
  'version',
  'bridgeEpoch',
  'viewId',
  'ownerEpoch',
  'revision',
  'nodeId',
  'action',
  'args',
};
const _textActions = {
  'setSelection',
  'setText',
  'copy',
  'cut',
  'paste',
  ..._movement,
};
final _actions = <String, SemanticsAction>{
  for (final action in [
    SemanticsAction.tap,
    SemanticsAction.longPress,
    SemanticsAction.focus,
    SemanticsAction.setSelection,
    SemanticsAction.setText,
    SemanticsAction.copy,
    SemanticsAction.cut,
    SemanticsAction.paste,
    SemanticsAction.scrollLeft,
    SemanticsAction.scrollRight,
    SemanticsAction.scrollUp,
    SemanticsAction.scrollDown,
    SemanticsAction.increase,
    SemanticsAction.decrease,
    SemanticsAction.showOnScreen,
    SemanticsAction.dismiss,
    SemanticsAction.moveCursorForwardByCharacter,
    SemanticsAction.moveCursorBackwardByCharacter,
    SemanticsAction.moveCursorForwardByWord,
    SemanticsAction.moveCursorBackwardByWord,
    SemanticsAction.expand,
    SemanticsAction.collapse,
    SemanticsAction.didGainAccessibilityFocus,
    SemanticsAction.didLoseAccessibilityFocus,
  ])
    action.name: action,
};

int _treeLevel(String identifier) {
  const prefix = 'busydata.database.item.';
  if (!identifier.startsWith(prefix)) return 0;
  final separator = identifier.indexOf('.', prefix.length);
  if (separator < 0) return 0;
  final level = int.tryParse(identifier.substring(prefix.length, separator));
  return level != null && level > 0 && level <= 64 ? level : 0;
}

bool _offset(String text, Object? value) =>
    value is int &&
    value >= 0 &&
    value <= text.length &&
    (value == 0 ||
        value == text.length ||
        !(_high(text.codeUnitAt(value - 1)) && _low(text.codeUnitAt(value))));
bool _high(int unit) => unit >= 0xd800 && unit <= 0xdbff;
bool _low(int unit) => unit >= 0xdc00 && unit <= 0xdfff;
String _textStatus(String text) {
  for (var i = 0; i < text.length; ++i) {
    final unit = text.codeUnitAt(i);
    if (unit == 0) return 'unavailable-nul';
    if (_high(unit)) {
      if (++i >= text.length || !_low(text.codeUnitAt(i))) {
        return 'unavailable-encoding';
      }
    } else if (_low(unit)) {
      return 'unavailable-encoding';
    }
  }
  return 'available';
}

class _ProjectionFailure implements Exception {
  const _ProjectionFailure(this.status, this.reason);
  final String status, reason;
}

class _ActionPermit {
  _ActionPermit(this.bridgeEpoch, this.ownerEpoch, this.viewId);
  final int bridgeEpoch, ownerEpoch, viewId;
  final clock = Stopwatch()..start();
  bool active = true;
  bool get current =>
      active && clock.elapsed < LinuxAccessibilityBridge.actionLifetime;
}

/// Owns the bridge for one mounted Linux application, including test/restart
/// teardown. Missing native support stays unavailable rather than falling back.
class LinuxAccessibilityBridgeScope extends StatefulWidget {
  const LinuxAccessibilityBridgeScope({super.key, required this.child});
  final Widget child;
  @override
  State<LinuxAccessibilityBridgeScope> createState() =>
      _LinuxAccessibilityBridgeScopeState();
}

class _LinuxAccessibilityBridgeScopeState
    extends State<LinuxAccessibilityBridgeScope> {
  late final bridge = LinuxAccessibilityBridge();
  @override
  void initState() {
    super.initState();
    bridge.start();
  }

  @override
  void dispose() {
    bridge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
