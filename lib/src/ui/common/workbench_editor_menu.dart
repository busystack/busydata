// Interaction adapted from BusyMark 8b9aa85 editor_text_context_menu.dart.
// BusyData owns bounded document editing and clipboard intent through the public editor interface.
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'editor_shortcuts.dart';
import 'sql_editor_geometry.dart';
import '../../features/workspace/editor/sql_editor.dart';

class WorkbenchEditorMenu extends StatefulWidget {
  const WorkbenchEditorMenu({
    super.key,
    required this.controls,
    required this.controller,
    required this.builder,
    required this.scrollController,
    this.readOnly = false,
    this.shortcuts = const WorkbenchEditorShortcuts([]),
  });
  final DesktopControls controls;
  final SqlEditorController controller;
  final bool readOnly;
  final WorkbenchEditorShortcuts shortcuts;
  final SqlEditorScrollController scrollController;
  final Widget Function(
    SelectionToolbarController toolbar,
    FocusNode focus,
    WorkbenchEditorShortcuts shortcuts,
  )
  builder;
  @override
  State<WorkbenchEditorMenu> createState() => _WorkbenchEditorMenuState();
}

class _WorkbenchEditorMenuState extends State<WorkbenchEditorMenu>
    with WidgetsBindingObserver
    implements SelectionToolbarController {
  final focus = FocusNode(debugLabel: 'SQL text menu owner');
  late final presenter = widget.controls.createMenuPresenter();
  int generation = 0;
  bool keyboard = false;
  FocusNode? pendingClipboardFocus;
  int? clipboardRequest;
  int? menuFocusHandoff;
  CodeLineEditingValue? menuRevision;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FocusManager.instance.addListener(focusChanged);
  }

  void focusChanged() {
    if (clipboardRequest != null &&
        !focus.hasFocus &&
        FocusManager.instance.primaryFocus != pendingClipboardFocus) {
      retire();
    }
  }

  @override
  void didUpdateWidget(WorkbenchEditorMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller ||
        oldWidget.readOnly != widget.readOnly ||
        !oldWidget.shortcuts.sameReservations(widget.shortcuts)) {
      retire();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) retire();
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(focusChanged);
    presenter.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  void hide(BuildContext context) {
    // A real popup takes focus from CodeEditor, whose focus listener retires
    // selection toolbars. Admit exactly that handoff, using the presenter's
    // actual popup route. Text changes, scrolling and newer focus still retire.
    if (menuFocusHandoff == generation &&
        menuRevision == widget.controller.value &&
        !focus.hasFocus &&
        presenter.ownsFocus(FocusManager.instance.primaryFocus)) {
      menuFocusHandoff = null;
      return;
    }
    retire();
  }

  void retire() {
    generation++;
    clipboardRequest = null;
    pendingClipboardFocus = null;
    menuFocusHandoff = null;
    menuRevision = null;
    unawaited(presenter.dismiss());
  }

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    // Complete the initiating pointer's editor focus before popup preparation.
    focus.requestFocus();
    FocusManager.instance.applyFocusChangesIfNeeded();
    unawaited(open(anchors.primaryAnchor, widget.controller));
  }

  Future<void> open(Offset anchor, SqlEditorController controller) async {
    final request = ++generation, captured = controller.value;
    final readOnly = widget.readOnly, fromKeyboard = keyboard;
    final openingFocus = FocusManager.instance.primaryFocus;
    keyboard = false;
    await presenter.dismiss();
    bool current() =>
        mounted && request == generation && controller.value == captured;
    if (!current()) return;
    if (!focus.hasFocus &&
        !identical(FocusManager.instance.primaryFocus, openingFocus)) {
      return;
    }
    clipboardRequest = request;
    pendingClipboardFocus = FocusManager.instance.primaryFocus;
    bool canPaste = false;
    try {
      canPaste = await Clipboard.hasStrings();
    } catch (_) {
      /* Availability remains false. */
    }
    if (clipboardRequest == request) {
      clipboardRequest = null;
      pendingClipboardFocus = null;
    }
    if (!mounted || !current()) return;
    final l = strings(context);
    final unavailable = l.noSelection;
    final hasText = controller.text.isNotEmpty;
    final actions = [
      DesktopMenuAction(
        l.cut,
        controller.cut,
        shortcut: widget.shortcuts.labelFor(CodeShortcutType.cut),
        disabledReason: readOnly || !hasText
            ? (readOnly ? l.readOnlyPolicy : unavailable)
            : null,
      ),
      DesktopMenuAction(
        l.copy,
        () => controller.copy(),
        shortcut: widget.shortcuts.labelFor(CodeShortcutType.copy),
        disabledReason: hasText ? null : unavailable,
      ),
      DesktopMenuAction(
        l.paste,
        controller.paste,
        shortcut: widget.shortcuts.labelFor(CodeShortcutType.paste),
        disabledReason: readOnly || !canPaste
            ? (readOnly ? l.readOnlyPolicy : l.clipboardEmpty)
            : null,
      ),
      DesktopMenuAction(
        l.selectAll,
        controller.selectAll,
        shortcut: widget.shortcuts.labelFor(CodeShortcutType.selectAll),
        disabledReason: hasText ? null : unavailable,
      ),
    ];
    menuFocusHandoff = request;
    menuRevision = captured;
    final selected = await presenter.show(
      context,
      anchor,
      actions,
      keyboard: fromKeyboard,
    );
    if (menuFocusHandoff == request) menuFocusHandoff = null;
    if (request == generation) menuRevision = null;
    if (!current() || selected == null) return;
    // Clipboard operations retain the vendored controller's asynchronous value
    // checks and budgets. Revalidate the live read-only state after dismissal.
    if (widget.readOnly && (selected == 0 || selected == 2)) return;
    actions[selected].invoke();
  }

  @override
  Widget build(BuildContext context) => presenter.anchor(
    Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent || widget.controller.isComposing) {
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          retire();
          return KeyEventResult.ignored;
        }
        if (event.logicalKey == LogicalKeyboardKey.contextMenu ||
            event.logicalKey == LogicalKeyboardKey.f10 &&
                HardwareKeyboard.instance.isShiftPressed &&
                !HardwareKeyboard.instance.isControlPressed &&
                !HardwareKeyboard.instance.isAltPressed &&
                !HardwareKeyboard.instance.isMetaPressed) {
          final anchor = widget.scrollController.contextMenuAnchor(
            widget.controller.selection.extent,
          );
          if (anchor != null) {
            keyboard = true;
            unawaited(open(anchor, widget.controller));
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: widget.builder(this, focus, widget.shortcuts),
    ),
  );
}
