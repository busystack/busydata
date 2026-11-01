// Adapted from BusyMark a5ee774 (Apache-2.0).
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';

/// Identifies local query input to the application's early keyboard route.
/// No ancestor lookup is needed while focus detaches during navigation.
class BusyDataSearchFocusNode extends FocusNode {
  BusyDataSearchFocusNode()
    : super(debugLabel: 'BusyDataSearchField text entry');
}

/// Keep input editing local without shadowing application navigation (for
/// example Alt+Left) with a second complete platform shortcut map.
class BusyDataLocalTextEditingShortcuts extends StatelessWidget {
  const BusyDataLocalTextEditingShortcuts({super.key, required this.child});

  final Widget child;
  static const bindings = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.keyA, control: true):
        SelectAllTextIntent(SelectionChangedCause.keyboard),
    SingleActivator(LogicalKeyboardKey.keyC, control: true):
        CopySelectionTextIntent.copy,
    SingleActivator(LogicalKeyboardKey.insert, control: true):
        CopySelectionTextIntent.copy,
    SingleActivator(LogicalKeyboardKey.keyX, control: true):
        CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
    SingleActivator(LogicalKeyboardKey.delete, shift: true):
        CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
    SingleActivator(LogicalKeyboardKey.keyV, control: true): PasteTextIntent(
      SelectionChangedCause.keyboard,
    ),
    SingleActivator(LogicalKeyboardKey.insert, shift: true): PasteTextIntent(
      SelectionChangedCause.keyboard,
    ),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoTextIntent(
      SelectionChangedCause.keyboard,
    ),
    SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        RedoTextIntent(SelectionChangedCause.keyboard),
  };

  @override
  Widget build(BuildContext context) =>
      Shortcuts(shortcuts: bindings, child: child);
}

/// Flutter counterpart to BusyData's native Linux `GtkSearchEntry`.
///
/// The native entry cannot be embedded in Flutter-owned layouts. This uses the
/// Yaru input theme shared by the rest of the application instead of
/// [YaruSearchField], whose borderless pill geometry is intended for Flutter
/// title bars rather than GTK-style entries inside a sidebar.
class BusyDataSearchField extends StatefulWidget {
  const BusyDataSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.autofocus = false,
    this.focusNode,
    this.focusRequest = 0,
    this.onChanged,
    this.onSubmitted,
    this.onMoveSelection,
    this.onClear,
    this.onEscape,
    this.clearButtonSemanticLabel,
    this.clearOnEscape = true,
  });

  final TextEditingController? controller;
  final String? hintText;
  final bool autofocus;
  final FocusNode? focusNode;

  /// Increment this value to focus the themed text entry again.
  final int focusRequest;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String?>? onSubmitted;
  final ValueChanged<int>? onMoveSelection;
  final VoidCallback? onClear;
  final VoidCallback? onEscape;
  final String? clearButtonSemanticLabel;
  final bool clearOnEscape;

  @override
  State<BusyDataSearchField> createState() => _BusyDataSearchFieldState();
}

class _BusyDataSearchFieldState extends State<BusyDataSearchField> {
  late TextEditingController _controller;
  late bool _textIsEmpty;
  final _ownedFocusNode = BusyDataSearchFocusNode();
  FocusNode get _focusNode => widget.focusNode ?? _ownedFocusNode;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant BusyDataSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _attachController();
    }
    if (oldWidget.focusRequest != widget.focusRequest) {
      _requestTextFocus();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    if (widget.controller == null) {
      _controller.dispose();
    }
    _ownedFocusNode.dispose();
    super.dispose();
  }

  void _attachController() {
    _controller = widget.controller ?? TextEditingController();
    _textIsEmpty = _controller.text.isEmpty;
    _controller.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    final textIsEmpty = _controller.text.isEmpty;
    if (textIsEmpty != _textIsEmpty) {
      setState(() => _textIsEmpty = textIsEmpty);
    }
  }

  void _requestTextFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _clear() {
    final hadText = _controller.text.isNotEmpty;
    if (!hadText) return;
    final onClear = widget.onClear;
    if (onClear != null) {
      onClear();
    }
    _controller.clear();
    if (onClear == null && hadText) {
      // TextField does not report programmatic controller changes through
      // onChanged, so keep onChanged-only search owners in sync.
      widget.onChanged?.call('');
    }
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    _focusNode.onKeyEvent = (_, event) {
      if ((event is! KeyDownEvent && event is! KeyRepeatEvent) ||
          _controller.value.composing.isValid) {
        return KeyEventResult.ignored;
      }
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.enter &&
          widget.onSubmitted != null) {
        widget.onSubmitted!(_controller.text);
        return KeyEventResult.handled;
      }
      if ((event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) &&
          widget.onMoveSelection != null) {
        widget.onMoveSelection!(
          event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1,
        );
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
    final theme = Theme.of(context);
    // Match InputDecorator's inline hint typography while keeping its
    // decorative text out of the editor's stable accessible name.
    final hintStyle =
        (theme.useMaterial3
                ? theme.textTheme.bodyLarge!
                : theme.textTheme.titleMedium!)
            .merge(
              TextStyle(
                color: theme.useMaterial3
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.hintColor,
              ),
            )
            .merge(
              WidgetStateProperty.resolveAs(
                theme.inputDecorationTheme.hintStyle,
                {if (_focusNode.hasFocus) WidgetState.focused},
              ),
            );
    final clearLabel =
        widget.clearButtonSemanticLabel ??
        MaterialLocalizations.of(context).clearButtonTooltip;
    return Focus(
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            !_controller.value.composing.isValid) {
          if (widget.clearOnEscape) _clear();
          widget.onEscape?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: SizedBox(
        height: math.max(
          kYaruTitleBarItemHeight,
          MediaQuery.textScalerOf(
                    context,
                  ).scale(theme.textTheme.bodyMedium?.fontSize ?? 14) *
                  1.2 +
              8,
        ),
        // Query editing stays local even if an application command acquires
        // one of the platform's ordinary text-editing combinations.
        child: Material(
          type: MaterialType.transparency,
          child: BusyDataLocalTextEditingShortcuts(
            child: Stack(
              alignment: AlignmentDirectional.centerEnd,
              children: [
                Semantics(
                  container: true,
                  label: widget.hintText,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    cursorWidth: 1,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    decoration: InputDecoration(
                      // The fading placeholder must never contribute a
                      // second field name while typing begins or Clear runs.
                      hint: widget.hintText == null
                          ? null
                          : ExcludeSemantics(
                              child: Text(widget.hintText!, style: hintStyle),
                            ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                      prefixIcon: const Icon(YaruIcons.search),
                      prefixIconConstraints: const BoxConstraints.tightFor(
                        width: kYaruTitleBarItemHeight,
                      ),
                      suffixIcon: _textIsEmpty
                          ? null
                          : const SizedBox(width: kYaruTitleBarItemHeight),
                      suffixIconConstraints: const BoxConstraints.tightFor(
                        width: kYaruTitleBarItemHeight,
                      ),
                    ),
                  ),
                ),
                if (!_textIsEmpty)
                  MergeSemantics(
                    child: Semantics(
                      label: clearLabel,
                      child: IconButton(
                        tooltip: clearLabel,
                        onPressed: _clear,
                        icon: const Icon(YaruIcons.edit_clear),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
