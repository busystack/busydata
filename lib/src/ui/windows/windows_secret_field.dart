import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/generated/app_localizations_en.dart';
import 'windows_secret_editing_session.dart';

/// Fluent supplies the frame and traversal owner; Windows supplies the actual
/// protected editor and its accessibility provider. No Flutter input connection
/// is opened for this field, including when the native editor is unavailable.
class WindowsSecretField extends StatefulWidget {
  const WindowsSecretField({
    super.key,
    required this.controller,
    required this.label,
    this.focusNode,
    this.enabled = true,
    this.readOnly = false,
    this.technical = false,
    this.hasTrailing = false,
    this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final FocusNode? focusNode;
  final bool enabled, readOnly, technical, hasTrailing;

  @override
  State<WindowsSecretField> createState() => _WindowsSecretFieldState();
}

class _WindowsSecretFieldState extends State<WindowsSecretField> {
  final _anchor = GlobalKey();
  late FocusNode _focus;
  late final _NativeSecretOwner _owner;
  bool _ownsFocus = false, _hovered = false, _failed = false;

  @override
  void initState() {
    super.initState();
    _attachFocus();
    _owner = _NativeSecrets.instance.register(this, widget.controller);
  }

  void _attachFocus() {
    _ownsFocus = widget.focusNode == null;
    _focus =
        widget.focusNode ?? FocusNode(debugLabel: 'Windows protected input');
    _focus.addListener(_focusChanged);
  }

  void _detachFocus() {
    _focus.removeListener(_focusChanged);
    if (_ownsFocus) _focus.dispose();
  }

  void _focusChanged() {
    if (_focus.hasFocus) {
      unawaited(Scrollable.ensureVisible(context));
      _owner.requestFocus();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(WindowsSecretField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detachFocus();
      _attachFocus();
    }
    _owner.session.replaceController(widget.controller);
  }

  AppLocalizations get _strings =>
      AppLocalizations.of(context) ?? AppLocalizationsEn();

  void _failure(bool failed) {
    if (mounted && failed != _failed) setState(() => _failed = failed);
  }

  Map<String, Object>? _layout() {
    final box = _anchor.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final route = ModalRoute.of(context);
    var visible =
        (route?.isCurrent ?? true) &&
        (route?.animation == null || route!.animation!.isCompleted);
    var clip = Offset.zero & MediaQuery.sizeOf(context);
    RenderObject? child = box;
    while (child?.parent is RenderObject) {
      final parent = child!.parent!;
      if (parent is RenderOffstage && parent.offstage) visible = false;
      final localClip = parent.describeApproximatePaintClip(child);
      if (localClip != null) {
        clip = clip.intersect(
          MatrixUtils.transformRect(parent.getTransformTo(null), localClip),
        );
      }
      child = parent;
    }
    final position = box.localToGlobal(Offset.zero);
    final direction = widget.technical
        ? TextDirection.ltr
        : Directionality.of(context);
    var padding = kTextBoxPadding.resolve(direction);
    if (widget.hasTrailing) {
      padding = padding
          .add(
            direction == TextDirection.ltr
                ? const EdgeInsets.only(right: 38)
                : const EdgeInsets.only(left: 38),
          )
          .resolve(direction);
    }
    final bounds = padding.deflateRect(position & box.size);
    final clipped = clip.intersect(bounds);
    visible =
        visible && !clipped.isEmpty && bounds.width > 0 && bounds.height > 0;
    final theme = FluentTheme.of(context);
    final resources = theme.resources;
    final textStyle = theme.typography.body ?? const TextStyle(fontSize: 14);
    final fill = !widget.enabled
        ? resources.controlFillColorDisabled
        : _focus.hasFocus
        ? resources.controlFillColorInputActive
        : _hovered
        ? resources.controlFillColorSecondary
        : resources.controlFillColorDefault;
    final background = Color.alphaBlend(fill, theme.micaBackgroundColor);
    final foreground = widget.enabled
        ? resources.textFillColorPrimary
        : resources.textFillColorDisabled;
    final ratio = View.of(context).devicePixelRatio;
    final x = (bounds.left * ratio).round(), y = (bounds.top * ratio).round();
    Int32List rectangle(Rect rect) => Int32List.fromList([
      (rect.left * ratio).round() - x,
      (rect.top * ratio).round() - y,
      (rect.right * ratio).round() - x,
      (rect.bottom * ratio).round() - y,
    ]);
    return {
      'x': x,
      'y': y,
      'width': math.max(1, (bounds.width * ratio).round()),
      'height': math.max(1, (bounds.height * ratio).round()),
      'clip': rectangle(clipped.isEmpty ? bounds.topLeft & Size.zero : clipped),
      'exclusions': Int32List.fromList([
        for (final region in _NativeSecrets.instance.occlusions)
          if (region.attached && region.hasSize)
            ...rectangle(
              (region.localToGlobal(Offset.zero) & region.size).inflate(12),
            ),
      ]),
      'label': Int32List.fromList(widget.label.codeUnits),
      'hint': Int32List.fromList((widget.hint ?? '').codeUnits),
      'enabled': widget.enabled,
      'readOnly': widget.readOnly,
      'visible': visible,
      // The native provider reads the actual Windows contrast palette. Include
      // this signal even when Fluent's ordinary resource colors stay equal.
      'highContrast': MediaQuery.highContrastOf(context),
      'rtl': direction == TextDirection.rtl,
      'fontHeight': math.max(
        1,
        (MediaQuery.textScalerOf(context).scale(textStyle.fontSize ?? 14) *
                ratio)
            .round(),
      ),
      'fontFamily': Int32List.fromList(
        (textStyle.fontFamily ?? 'Segoe UI').codeUnits,
      ),
      'background': background.toARGB32(),
      'foreground': Color.alphaBlend(foreground, background).toARGB32(),
    };
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: ExcludeSemantics(
          child: TextBox(
            key: _anchor,
            controller: widget.controller,
            focusNode: _focus,
            obscureText: true,
            readOnly: true,
            showCursor: false,
            enableInteractiveSelection: false,
            autocorrect: false,
            enableSuggestions: false,
            textDirection: widget.technical ? TextDirection.ltr : null,
            suffix: widget.hasTrailing ? const SizedBox(width: 38) : null,
            enabled: widget.enabled,
            onTap: () {
              if (widget.enabled) {
                _focus.requestFocus();
                _owner.requestFocus();
              }
            },
          ),
        ),
      ),
      if (_failed)
        Row(
          children: [
            Expanded(child: Text(_strings.unavailable)),
            Button(
              onPressed: widget.enabled ? widget.controller.clear : null,
              child: Text(_strings.clear),
            ),
            Button(
              onPressed: widget.enabled ? _owner.retry : null,
              child: Text(_strings.retry),
            ),
          ],
        ),
    ],
  );

  @override
  void dispose() {
    _NativeSecrets.instance.unregister(_owner);
    _detachFocus();
    super.dispose();
  }
}

class _NativeSecretOwner {
  _NativeSecretOwner(this.field, int id, TextEditingController controller) {
    session = WindowsSecretEditingSession(
      id: id,
      controller: controller,
      send: (snapshot) {
        editing = snapshot;
        _NativeSecrets.instance.schedule(this);
      },
    );
  }
  final _WindowsSecretFieldState field;
  late final WindowsSecretEditingSession session;
  WindowsSecretEditingSnapshot? editing;
  Map<String, Object>? lastLayout;
  int acknowledged = -1, rejected = -1;
  bool focusRequested = false;
  void requestFocus() {
    focusRequested = true;
    _NativeSecrets.instance.schedule(this);
  }

  void retry() {
    rejected = -1;
    acknowledged = -1;
    session.synchronize();
  }
}

/// One platform channel for this isolate, one current snapshot per mounted
/// field, and one in-flight operation. Layout updates never retain old values.
class _NativeSecrets {
  _NativeSecrets() {
    final random = math.Random.secure();
    owner = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    channel.setMethodCallHandler(_receive);
    WidgetsBinding.instance.addPersistentFrameCallback((_) {
      if (fields.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          pending.addAll(fields.keys);
          unawaited(_pump());
        });
      }
    });
  }
  static final instance = _NativeSecrets();
  static const channel = MethodChannel(
    'org.busystack.busydata/windows_secret_input',
  );
  late final String owner;
  final fields = <int, _NativeSecretOwner>{};
  final pending = <int>{}, disposed = <int>{};
  final occlusions = <RenderBox>{};
  int _nextId = 0;
  bool _running = false, _initialized = false, _postFrameQueued = false;

  _NativeSecretOwner register(
    _WindowsSecretFieldState field,
    TextEditingController controller,
  ) {
    final entry = _NativeSecretOwner(field, ++_nextId, controller);
    fields[entry.session.id] = entry;
    entry.session.synchronize();
    return entry;
  }

  void unregister(_NativeSecretOwner field) {
    final id = field.session.id;
    fields.remove(id);
    pending.remove(id);
    disposed.add(id);
    field.editing = null;
    field.session.dispose();
    unawaited(_pump());
  }

  void schedule(_NativeSecretOwner field) {
    if (field.session.disposed) return;
    pending.add(field.session.id);
    // Synchronizing a controller can happen during build. Resolve its geometry
    // only after the frame, without requesting additional idle frames.
    if (!_postFrameQueued) {
      _postFrameQueued = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _postFrameQueued = false;
        unawaited(_pump());
      });
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  Map<String, Object> identity(_NativeSecretOwner field) => {
    'owner': owner,
    'id': field.session.id,
    'generation': field.session.generation,
  };
  bool _same(Map<String, Object>? first, Map<String, Object> second) {
    if (first == null || first.length != second.length) return false;
    for (final key in first.keys) {
      final a = first[key], b = second[key];
      if (a is Int32List && b is Int32List) {
        if (a.length != b.length) return false;
        for (var i = 0; i < a.length; i++) {
          if (a[i] != b[i]) return false;
        }
      } else if (a != b) {
        return false;
      }
    }
    return true;
  }

  Future<void> _pump() async {
    if (_running) return;
    _running = true;
    try {
      if (!_initialized) {
        await channel.invokeMethod<void>('initialize', {'owner': owner});
        _initialized = true;
      }
      while (disposed.isNotEmpty || pending.isNotEmpty) {
        if (disposed.isNotEmpty) {
          final id = disposed.first;
          disposed.remove(id);
          await channel.invokeMethod<void>('dispose', {
            'owner': owner,
            'id': id,
          });
          continue;
        }
        final id = pending.first;
        pending.remove(id);
        final entry = fields[id];
        if (entry == null || entry.session.disposed) continue;
        final layout = entry.field._layout();
        if (layout == null) continue;
        entry.session.setAdmission(
          layout['visible'] == true &&
              layout['enabled'] == true &&
              layout['readOnly'] == false,
        );
        final snapshot = entry.editing!;
        if (entry.rejected == snapshot.generation) continue;
        try {
          if (!_same(entry.lastLayout, layout) ||
              entry.acknowledged != snapshot.generation) {
            await channel.invokeMethod<void>('configure', {
              ...identity(entry),
              ...layout,
              'acceptsInput': snapshot.acceptsInput,
              if (entry.acknowledged != snapshot.generation) ...{
                'utf16': snapshot.utf16,
                'base': snapshot.selection.baseOffset,
                'extent': snapshot.selection.extentOffset,
              },
            });
            if (entry.session.disposed ||
                snapshot.generation != entry.session.generation) {
              continue;
            }
            if (entry.acknowledged < 0 && entry.field._focus.hasFocus) {
              entry.focusRequested = true;
            }
            entry.lastLayout = layout;
            entry.acknowledged = snapshot.generation;
            entry.field._failure(false);
          }
          if (entry.focusRequested &&
              entry.field._focus.hasFocus &&
              layout['visible'] == true &&
              layout['enabled'] == true) {
            entry.focusRequested = false;
            await channel.invokeMethod<void>('focus', identity(entry));
          }
        } on PlatformException {
          if (!entry.session.disposed &&
              snapshot.generation == entry.session.generation) {
            entry.rejected = snapshot.generation;
            entry.field._failure(true);
          }
        }
      }
    } on PlatformException {
      for (final field in fields.values) {
        field.field._failure(true);
      }
      pending.clear();
      disposed.clear();
    } on MissingPluginException {
      for (final field in fields.values) {
        field.field._failure(true);
      }
      pending.clear();
      disposed.clear();
    } finally {
      _running = false;
    }
  }

  Future<void> _receive(MethodCall call) async {
    final data = call.arguments;
    if (data is! Map || data['owner'] != owner) return;
    final entry = fields[data['id']];
    if (entry == null ||
        entry.session.disposed ||
        data['generation'] != entry.session.generation) {
      return;
    }
    switch (call.method) {
      case 'editing':
        entry.session.acceptNative(
          fieldId: data['id'] as int,
          generation: data['generation'] as int,
          serial: data['serial'] as int,
          utf16: data['utf16'] as Int32List,
          selectionBase: data['base'] as int,
          selectionExtent: data['extent'] as int,
        );
      case 'focusChanged':
        if (data['focused'] == true && !entry.field._focus.hasFocus) {
          entry.field._focus.requestFocus();
        }
      case 'traverse':
        entry.focusRequested = false;
        if (data['backwards'] == true) {
          entry.field._focus.previousFocus();
        } else {
          entry.field._focus.nextFocus();
        }
    }
  }
}

/// Registers the actual painted tooltip extent, so a native child cannot cover
/// Flutter overlay content. The tooltip retains its complete text and semantics.
class WindowsSecretInputOcclusion extends SingleChildRenderObjectWidget {
  const WindowsSecretInputOcclusion({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _Occlusion();
}

class _Occlusion extends RenderProxyBox {
  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _NativeSecrets.instance.occlusions.add(this);
  }

  @override
  void detach() {
    _NativeSecrets.instance.occlusions.remove(this);
    super.detach();
  }
}

/// A tooltip keeps its original spoken/plain text while its visible text also
/// provides a render object for clipping native siblings. Placeholder offsets
/// used for painting retain the standard WidgetSpan representation.
class WindowsSecretTooltipSpan extends WidgetSpan {
  WindowsSecretTooltipSpan(this.message, {TextStyle? style})
    : super(
        child: WindowsSecretInputOcclusion(child: Text(message, style: style)),
      );
  final String message;
  @override
  void computeToPlainText(
    StringBuffer buffer, {
    bool includeSemanticsLabels = true,
    bool includePlaceholders = true,
  }) {
    if (includeSemanticsLabels) {
      buffer.write(message);
    } else {
      super.computeToPlainText(
        buffer,
        includeSemanticsLabels: false,
        includePlaceholders: includePlaceholders,
      );
    }
  }
}
