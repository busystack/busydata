import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:re_editor/re_editor.dart';
import '../../features/workspace/editor/sql_editor.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'editor_shortcuts.dart';
import 'sql_editor_geometry.dart';
import 'sql_editor_actions.dart';
import 'sql_editor_input.dart';
import 'accessibility_text_geometry.dart';

class SqlAddCaretIntent extends Intent {
  const SqlAddCaretIntent(this.direction);
  final int direction;
}

class SqlNextOccurrenceIntent extends Intent {
  const SqlNextOccurrenceIntent();
}

class SqlClearCaretsIntent extends Intent {
  const SqlClearCaretsIntent();
}

class SqlPageIntent extends Intent {
  const SqlPageIntent(this.down, this.extend);
  final bool down, extend;
}

class SqlCompletionKeyboardScope extends InheritedWidget {
  const SqlCompletionKeyboardScope({
    super.key,
    required this.active,
    required this.move,
    required this.commit,
    required this.dismiss,
    required super.child,
  });
  final bool active;
  final bool Function(AxisDirection) move;
  final bool Function() commit, dismiss;
  static SqlCompletionKeyboardScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SqlCompletionKeyboardScope>();
  @override
  bool updateShouldNotify(SqlCompletionKeyboardScope old) =>
      old.active != active ||
      old.move != move ||
      old.commit != commit ||
      old.dismiss != dismiss;
}

/// BusyData owns native input, extra ranges, accessibility and shortcuts.
/// The official editor supplies read-only primary layout and hit testing.
class WorkbenchSqlEditor extends StatefulWidget {
  const WorkbenchSqlEditor({
    super.key,
    required this.controls,
    required this.controller,
    required this.scrollController,
    required this.style,
    required this.indicatorBuilder,
    this.focusNode,
    this.toolbarController,
    this.shortcutsActivatorsBuilder,
    this.commentFormatter,
    this.semanticLabel,
    this.readOnly = false,
    this.autofocus = true,
    this.wordWrap = true,
  });
  final DesktopControls controls;
  final SqlEditorController controller;
  final SqlEditorScrollController scrollController;
  final CodeEditorStyle style;
  final CodeIndicatorBuilder indicatorBuilder;
  final FocusNode? focusNode;
  final SelectionToolbarController? toolbarController;
  final CodeShortcutsActivatorsBuilder? shortcutsActivatorsBuilder;
  final CodeCommentFormatter? commentFormatter;

  /// Localized control identity, on the same semantic node as its text/actions.
  final String? semanticLabel;
  final bool readOnly, autofocus, wordWrap;
  @override
  State<WorkbenchSqlEditor> createState() => _WorkbenchSqlEditorState();
}

class _WorkbenchSqlEditorState extends State<WorkbenchSqlEditor> {
  final paintKey = GlobalKey();
  final verticalViewportKey = GlobalKey();
  final horizontalViewportKey = GlobalKey();
  final indicatorKey = GlobalKey();
  final caretVisible = ValueNotifier<bool>(false);
  Timer? caretTimer;
  Object? caretConfiguration;
  late FocusNode focus;
  SqlEditorInput? input;
  SqlEditorFailure? rejected;
  int? rejectedRevision;
  int? paintedRevision;
  bool? paintedFocus;
  bool rebuildScheduled = false;
  bool reducedMotion = false;
  void navigatePage(bool down, bool extend) => widget.scrollController.geometry
      .navigatePage(widget.controller, down, extend);
  void configureInput() {
    final brightness =
        widget.controls.appearance(context).view.computeLuminance() < .5
        ? Brightness.dark
        : Brightness.light;
    final current = input;
    if (current == null) {
      input = SqlEditorInput(
        controller: widget.controller,
        focusNode: focus,
        geometry: widget.scrollController.geometry,
        readOnly: widget.readOnly,
        viewId: View.of(context).viewId,
        keyboardAppearance: brightness,
      );
    } else {
      current.update(
        controller: widget.controller,
        focusNode: focus,
        geometry: widget.scrollController.geometry,
        readOnly: widget.readOnly,
        viewId: View.of(context).viewId,
        keyboardAppearance: brightness,
      );
    }
  }

  void bindRejections() {
    final owner = widget.controller;
    owner.addRejectionHandler(this, (error) {
      if (!mounted || !identical(widget.controller, owner)) return false;
      if (error is! SqlEditorException) return false;
      if (mounted) {
        setState(() {
          rejected = error.code;
          rejectedRevision = widget.controller.value.revision;
        });
      }
      return true;
    });
  }

  void releaseRejections(SqlEditorController controller) {
    controller.removeRejectionHandler(this);
  }

  void configureCaret(bool reduced) {
    final next = (
      widget.controller,
      widget.controller.value.revision,
      focus.hasFocus,
      reduced,
    );
    if (caretConfiguration == next) return;
    caretConfiguration = next;
    caretTimer?.cancel();
    caretTimer = null;
    caretVisible.value = focus.hasFocus;
    if (focus.hasFocus && !reduced) {
      caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        caretVisible.value = !caretVisible.value;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    focus = widget.focusNode ?? FocusNode(debugLabel: 'SQL editor');
    widget.controller.addListener(changed);
    widget.controller.pageNavigation = navigatePage;
    bindRejections();
    focus.addListener(changed);
  }

  void changed() {
    if (mounted) configureCaret(reducedMotion);
    if (!mounted ||
        (paintedRevision == widget.controller.value.revision &&
            paintedFocus == focus.hasFocus)) {
      return;
    }
    void refresh() {
      if (!mounted) return;
      setState(() {
        if (rejectedRevision != null &&
            rejectedRevision != widget.controller.value.revision) {
          rejected = null;
          rejectedRevision = null;
        }
      });
    }

    // The official public delegate announces itself while its child mounts.
    // Retain every accepted notification while deferring parent visual work
    // until that build/layout phase has finished.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (rebuildScheduled) return;
      rebuildScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        rebuildScheduled = false;
        refresh();
      });
    } else {
      refresh();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    configureInput();
  }

  @override
  void didUpdateWidget(WorkbenchSqlEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    FocusNode? retiredFocus;
    if (oldWidget.controller != widget.controller ||
        oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.geometry.detach(oldWidget.controller);
    }
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller.pageNavigation == navigatePage) {
        oldWidget.controller.pageNavigation = null;
      }
      releaseRejections(oldWidget.controller);
      oldWidget.controller.removeListener(changed);
      widget.controller.addListener(changed);
      widget.controller.pageNavigation = navigatePage;
      rejected = null;
      rejectedRevision = null;
      bindRejections();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      focus.removeListener(changed);
      if (oldWidget.focusNode == null) retiredFocus = focus;
      focus = widget.focusNode ?? FocusNode(debugLabel: 'SQL editor');
      focus.addListener(changed);
    }
    configureInput();
    retiredFocus?.dispose();
  }

  @override
  void dispose() {
    input?.dispose();
    if (widget.controller.pageNavigation == navigatePage) {
      widget.controller.pageNavigation = null;
    }
    widget.controller.removeListener(changed);
    releaseRejections(widget.controller);
    widget.scrollController.geometry.detach(widget.controller);
    caretTimer?.cancel();
    caretVisible.dispose();
    focus.removeListener(changed);
    if (widget.focusNode == null) focus.dispose();
    super.dispose();
  }

  String failureMessage(BuildContext context, SqlEditorFailure reason) {
    final l = strings(context);
    return switch (reason) {
      SqlEditorFailure.documentLimit => l.sqlEditorDocumentLimit,
      SqlEditorFailure.lineLimit => l.sqlEditorLineLimit,
      SqlEditorFailure.caretLimit => l.sqlEditorCaretLimit,
      SqlEditorFailure.composing => l.sqlEditorFinishComposition,
      SqlEditorFailure.clipboardLimit => l.sqlEditorClipboardLimit,
      SqlEditorFailure.clipboardUnavailable => l.sqlEditorClipboardUnavailable,
      SqlEditorFailure.clipboardNul => l.textClipboardNulUnavailable,
      _ => l.sqlEditorSelectionUnavailable,
    };
  }

  bool reserved(SingleActivator key) =>
      widget.shortcutsActivatorsBuilder is WorkbenchEditorShortcuts &&
      (widget.shortcutsActivatorsBuilder as WorkbenchEditorShortcuts).reserved
          .any(
            (other) =>
                other.trigger == key.trigger &&
                other.control == key.control &&
                other.alt == key.alt &&
                other.shift == key.shift &&
                other.meta == key.meta,
          );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller, captured = controller.value;
    paintedRevision = captured.revision;
    paintedFocus = focus.hasFocus;
    final capturedFocus = focus;
    void requestOwnedFocus() {
      if (mounted &&
          identical(widget.controller, controller) &&
          identical(focus, capturedFocus)) {
        capturedFocus.requestFocus();
        input?.requestKeyboard();
      }
    }

    final geometry = widget.scrollController.geometry;
    geometry.attachViewportKeys(
      verticalViewportKey,
      horizontalViewportKey,
      indicatorKey,
    );
    geometry.focusEditor = focus.requestFocus;
    geometry.configure((
      widget.style,
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
      widget.wordWrap,
    ));
    final completion = SqlCompletionKeyboardScope.maybeOf(context);
    final look = widget.controls.appearance(context);
    final scaler = MediaQuery.textScalerOf(context);
    reducedMotion = MediaQuery.disableAnimationsOf(context);
    configureCaret(reducedMotion);
    final sourceStyle = widget.style;
    final scaledStyle = CodeEditorStyle(
      fontSize: scaler.scale(sourceStyle.fontSize ?? 13),
      fontFamily: sourceStyle.fontFamily,
      fontFamilyFallback: sourceStyle.fontFamilyFallback,
      fontHeight: sourceStyle.fontHeight,
      textColor: sourceStyle.textColor,
      hintTextColor: sourceStyle.hintTextColor,
      backgroundColor: sourceStyle.backgroundColor,
      selectionColor: sourceStyle.selectionColor,
      highlightColor: sourceStyle.highlightColor,
      // The visible caret belongs to the first-party layer. The upstream
      // paragraph remains unmodified and layout-only; our client owns input.
      cursorColor: const Color(0x00000000),
      cursorWidth: sourceStyle.cursorWidth,
      cursorLineColor: sourceStyle.cursorLineColor,
      chunkIndicatorColor: sourceStyle.chunkIndicatorColor,
      codeTheme: sourceStyle.codeTheme,
    );
    final primary = captured.selection;
    final line = captured.codeLines[primary.extentIndex].text;
    final complete = line.length <= 16384;
    var previewEnd = 16384;
    if (!complete &&
        line.codeUnitAt(previewEnd - 1) >= 0xd800 &&
        line.codeUnitAt(previewEnd - 1) <= 0xdbff &&
        line.codeUnitAt(previewEnd) >= 0xdc00 &&
        line.codeUnitAt(previewEnd) <= 0xdfff) {
      previewEnd--;
    }
    final shown = complete ? line : line.substring(0, previewEnd);
    final sameLine = primary.isSameLine;
    SqlEditorValue? semanticReplacement;
    bool current() =>
        mounted &&
        identical(widget.controller, controller) &&
        identical(controller.value, captured);
    final detail = [
      strings(context).sqlVisibleLine(
        primary.extentIndex + 1,
        captured.codeLines.length,
        primary.extentOffset + 1,
      ),
      if (!complete) strings(context).sqlLinePreviewTruncated,
      if (captured.secondarySelections.isNotEmpty)
        strings(
          context,
        ).sqlActiveCarets(captured.secondarySelections.length + 1),
      if (controller.isComposing) strings(context).sqlCompositionActive,
    ].join('; ');
    final title = widget.semanticLabel;
    final label = title == null || title.isEmpty ? detail : '$title\n$detail';
    final shortcuts = <ShortcutActivator, Intent>{};
    final activators =
        widget.shortcutsActivatorsBuilder ??
        const DefaultCodeShortcutsActivatorsBuilder();
    for (final type in CodeShortcutType.values) {
      final intent = kCodeShortcutIntents[type];
      if (intent == null) continue;
      for (final key in activators.build(type) ?? const <ShortcutActivator>[]) {
        shortcuts[key] = intent;
      }
    }
    void add(SingleActivator key, Intent intent) {
      if (!reserved(key)) shortcuts[key] = intent;
    }

    add(
      const SingleActivator(
        LogicalKeyboardKey.arrowUp,
        control: true,
        alt: true,
      ),
      const SqlAddCaretIntent(-1),
    );
    add(
      const SingleActivator(
        LogicalKeyboardKey.arrowDown,
        control: true,
        alt: true,
      ),
      const SqlAddCaretIntent(1),
    );
    add(
      const SingleActivator(LogicalKeyboardKey.keyD, control: true),
      const SqlNextOccurrenceIntent(),
    );
    add(
      const SingleActivator(LogicalKeyboardKey.pageUp),
      const CodeShortcutCursorMovePageIntent(false),
    );
    add(
      const SingleActivator(LogicalKeyboardKey.pageDown),
      const CodeShortcutCursorMovePageIntent(true),
    );
    add(
      const SingleActivator(LogicalKeyboardKey.pageUp, shift: true),
      const SqlPageIntent(false, true),
    );
    add(
      const SingleActivator(LogicalKeyboardKey.pageDown, shift: true),
      const SqlPageIntent(true, true),
    );
    if (captured.secondarySelections.isNotEmpty) {
      add(
        const SingleActivator(LogicalKeyboardKey.escape),
        const SqlClearCaretsIntent(),
      );
    }
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        geometry.scheduleLayout();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: Shortcuts(
          shortcuts: shortcuts,
          child: Actions(
            actions: {
              SqlAddCaretIntent: CallbackAction<SqlAddCaretIntent>(
                onInvoke: (intent) {
                  if (!controller.isComposing) {
                    controller.addCaret(intent.direction);
                  }
                  return null;
                },
              ),
              SqlNextOccurrenceIntent: CallbackAction<SqlNextOccurrenceIntent>(
                onInvoke: (_) {
                  if (!controller.isComposing) {
                    controller.selectNextOccurrence();
                  }
                  return null;
                },
              ),
              SqlClearCaretsIntent: CallbackAction<SqlClearCaretsIntent>(
                onInvoke: (_) {
                  if (completion?.dismiss() == true) return null;
                  if (!controller.isComposing) {
                    controller.setExtraSelections(const []);
                  }
                  return null;
                },
              ),
              SqlPageIntent: CallbackAction<SqlPageIntent>(
                onInvoke: (intent) {
                  if (!controller.isComposing) {
                    navigatePage(intent.down, intent.extend);
                  }
                  return null;
                },
              ),
            },
            child: _SqlEditorSemantics(
              key: ObjectKey(controller),
              geometry: geometry,
              controller: controller,
              valueOwner: captured,
              lineIndex: primary.extentIndex,
              direction: Directionality.of(context),
              selection: complete && sameLine
                  ? TextSelection(
                      baseOffset: primary.baseOffset,
                      extentOffset: primary.extentOffset,
                    )
                  : null,
              properties: SemanticsProperties(
                enabled: true,
                textField: true,
                multiline: true,
                focused: focus.hasFocus,
                readOnly: widget.readOnly,
                label: label,
                value: shown,
                onTap: requestOwnedFocus,
                onFocus: requestOwnedFocus,
                onSetSelection: complete
                    ? (selection) {
                        final expected = semanticReplacement ?? captured;
                        if (mounted &&
                            identical(widget.controller, controller) &&
                            identical(controller.value, expected) &&
                            !controller.isComposing &&
                            expected.selection.extentIndex ==
                                primary.extentIndex) {
                          final length = expected
                              .codeLines[primary.extentIndex]
                              .text
                              .length;
                          controller.selection = CodeLineSelection(
                            baseIndex: primary.extentIndex,
                            baseOffset: selection.baseOffset.clamp(0, length),
                            extentIndex: primary.extentIndex,
                            extentOffset: selection.extentOffset.clamp(
                              0,
                              length,
                            ),
                          );
                        }
                      }
                    : null,
                onSetText:
                    complete &&
                        sameLine &&
                        !widget.readOnly &&
                        !controller.isComposing
                    ? (replacement) {
                        if (!current() ||
                            widget.readOnly ||
                            controller.isComposing) {
                          return;
                        }
                        controller.replaceSelection(
                          replacement,
                          CodeLineSelection(
                            baseIndex: primary.extentIndex,
                            baseOffset: 0,
                            extentIndex: primary.extentIndex,
                            extentOffset: line.length,
                          ),
                        );
                        semanticReplacement = controller.value;
                      }
                    : null,
              ),
              child: Stack(
                children: [
                  Listener(
                    onPointerDown: (_) {
                      if (mounted && !widget.readOnly) input?.requestKeyboard();
                    },
                    child: CodeEditor(
                      controller: controller,
                      scrollController: widget.scrollController,
                      focusNode: focus,
                      toolbarController: widget.toolbarController,
                      // Dynamic maps belong to this first-party Shortcuts owner. The
                      // upstream widget remains mounted and consumes its public actions.
                      shortcutsActivatorsBuilder:
                          const _NoSqlShortcutBindings(),
                      shortcutOverrideActions: sqlEditorActions(
                        controller: controller,
                        owned: () =>
                            mounted && identical(widget.controller, controller),
                        readOnly: () => widget.readOnly,
                        completionActive: () => completion?.active == true,
                        completionMove: (direction) =>
                            completion?.move(direction) ?? false,
                        completionCommit: () => completion?.commit() ?? false,
                        completionDismiss: () => completion?.dismiss() ?? false,
                        commentFormatter: widget.commentFormatter,
                      ),
                      commentFormatter: widget.commentFormatter,
                      // The app's native client validates old-text and owner
                      // chains before publication. Upstream remains layout-only.
                      readOnly: true,
                      showCursorWhenReadOnly: false,
                      autofocus: widget.autofocus,
                      wordWrap: widget.wordWrap,
                      style: scaledStyle,
                      indicatorBuilder: (context, editing, chunks, notifier) {
                        geometry.bind(
                          controller,
                          notifier,
                          Directionality.of(context),
                          widget.wordWrap,
                        );
                        return KeyedSubtree(
                          key: geometry.indicatorKey,
                          child: widget.indicatorBuilder(
                            context,
                            editing,
                            chunks,
                            notifier,
                          ),
                        );
                      },
                      scrollbarBuilder: (context, child, details) {
                        final horizontal =
                            details.direction == AxisDirection.right;
                        final observed = KeyedSubtree(
                          key: horizontal
                              ? geometry.horizontalViewportKey
                              : geometry.verticalViewportKey,
                          child: child,
                        );
                        final scroll = details.controller;
                        return scroll == null
                            ? observed
                            : widget.controls.scrollbar(
                                controller: scroll,
                                child: observed,
                              );
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        key: paintKey,
                        painter: SqlExtraSelectionPainter(
                          geometry: geometry,
                          controller: controller,
                          origin: () {
                            final render = paintKey.currentContext
                                ?.findRenderObject();
                            return render is RenderBox && render.hasSize
                                ? render.localToGlobal(Offset.zero)
                                : Offset.zero;
                          },
                          selectionColor: look.textSelection,
                          caretColor: look.sourceCaret ?? look.focus,
                          caretWidth: widget.style.cursorWidth ?? 1.4,
                          caretVisible: caretVisible,
                          focused: () => focus.hasFocus,
                        ),
                      ),
                    ),
                  ),
                  if (rejected case final reason?)
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: 0,
                      child: Semantics(
                        liveRegion: true,
                        child: widget.controls.status(
                          failureMessage(context, reason),
                          error: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoSqlShortcutBindings extends CodeShortcutsActivatorsBuilder {
  const _NoSqlShortcutBindings();
  @override
  List<ShortcutActivator>? build(CodeShortcutType type) => null;
}

class _SqlEditorSemantics extends SingleChildRenderObjectWidget {
  const _SqlEditorSemantics({
    super.key,
    required this.properties,
    required this.selection,
    required this.direction,
    required this.geometry,
    required this.controller,
    required this.valueOwner,
    required this.lineIndex,
    required super.child,
  });
  final SemanticsProperties properties;
  final TextSelection? selection;
  final TextDirection direction;
  final SqlEditorGeometry geometry;
  final SqlEditorController controller;
  final SqlEditorValue valueOwner;
  final int lineIndex;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SqlEditorSemanticsRender(
        properties,
        selection,
        direction,
        geometry,
        controller,
        valueOwner,
        lineIndex,
      );
  @override
  void updateRenderObject(
    BuildContext context,
    _SqlEditorSemanticsRender render,
  ) {
    render
      ..properties = properties
      ..textDirection = direction;
    render.updateSelection(selection);
    render.updateGeometry(geometry, controller, valueOwner, lineIndex);
  }
}

class _SqlEditorSemanticsRender extends RenderSemanticsAnnotations
    implements AccessibilityTextGeometryProvider {
  _SqlEditorSemanticsRender(
    SemanticsProperties properties,
    this.selection,
    TextDirection direction,
    this.geometry,
    this.controller,
    this.valueOwner,
    this.lineIndex,
  ) : super(properties: properties, textDirection: direction, container: true);
  TextSelection? selection;
  SqlEditorGeometry geometry;
  SqlEditorController controller;
  SqlEditorValue valueOwner;
  int lineIndex;
  WeakReference<SemanticsNode>? _nativeNode;

  void _geometryChanged() {
    if (attached) markNeedsSemanticsUpdate();
  }

  void updateGeometry(
    SqlEditorGeometry nextGeometry,
    SqlEditorController nextController,
    SqlEditorValue nextOwner,
    int nextLine,
  ) {
    if (identical(geometry, nextGeometry) &&
        identical(controller, nextController) &&
        identical(valueOwner, nextOwner) &&
        lineIndex == nextLine) {
      return;
    }
    if (attached && !identical(geometry, nextGeometry)) {
      geometry.removeListener(_geometryChanged);
      nextGeometry.addListener(_geometryChanged);
    }
    geometry = nextGeometry;
    controller = nextController;
    valueOwner = nextOwner;
    lineIndex = nextLine;
    markNeedsSemanticsUpdate();
  }

  void _retireNode() {
    final old = _nativeNode?.target;
    if (old != null) AccessibilityTextGeometry.unregister(old, this);
    _nativeNode = null;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    geometry.addListener(_geometryChanged);
  }

  @override
  void detach() {
    _retireNode();
    geometry.removeListener(_geometryChanged);
    super.detach();
  }

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    super.assembleSemanticsNode(node, config, children);
    _retireNode();
    _nativeNode = WeakReference(node);
    AccessibilityTextGeometry.register(node, this);
  }

  @override
  Map<String, Object?>? captureAccessibilityTextGeometry(SemanticsNode node) {
    if (!attached ||
        !node.attached ||
        !identical(_nativeNode?.target, node) ||
        !identical(controller.value, valueOwner) ||
        node.getSemanticsData().value != properties.value) {
      return null;
    }
    return geometry.semanticTextGeometry(
      controller,
      valueOwner,
      lineIndex,
      properties.value?.length ?? 0,
    );
  }

  void updateSelection(TextSelection? next) {
    if (selection != next) {
      selection = next;
      markNeedsSemanticsUpdate();
    }
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    if (selection case final range?) config.textSelection = range;
  }
}
