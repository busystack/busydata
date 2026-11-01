import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show SelectableText;

import 'desktop_controls.dart';

/// Code syntax keeps its paragraph direction inside an RTL application. The
/// exact captured value remains selectable; this owns no document/controller.
class WorkbenchCodeEvidence extends StatelessWidget {
  const WorkbenchCodeEvidence({
    super.key,
    required this.controls,
    required this.text,
  });

  final DesktopControls controls;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    // Keep the exact read-only value separate from adjacent object headings.
    // Otherwise native static-text names can conceal the field's SQL value.
    container: true,
    child: SelectableText(
      text,
      textDirection: TextDirection.ltr,
      style: controls
          .appearance(context)
          .technical
          .copyWith(color: DefaultTextStyle.of(context).style.color),
    ),
  );
}

/// Workbench geometry grows with the native font and accessibility text scale.
/// The theme continues to own font families, colors and ordinary controls.
abstract final class WorkbenchMetrics {
  /// Measure a bounded set of UI labels, never database result rows/nodes.
  static double labelWidth(
    BuildContext context,
    DesktopControls controls,
    Iterable<String> labels,
  ) {
    var width = 0.0;
    for (final label in labels.take(32)) {
      final painter = TextPainter(
        text: TextSpan(text: label, style: controls.appearance(context).body),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (painter.width > width) width = painter.width;
      painter.dispose();
    }
    return width + 12;
  }

  static double line(BuildContext context, DesktopControls controls) =>
      controls.appearance(context).lineHeight(context);
  static double editorFont(BuildContext context, DesktopControls controls) =>
      (controls.textStyle(context).fontSize ?? 14);
  static TextStyle secondary(BuildContext context, DesktopControls controls) =>
      controls.appearance(context).caption;
}

class WorkbenchStrip extends StatelessWidget {
  const WorkbenchStrip({
    super.key,
    required this.controls,
    required this.child,
    this.minimumHeight = 38,
    this.padding = const EdgeInsets.symmetric(horizontal: 8),
    this.topBorder = false,
  });
  final DesktopControls controls;
  final Widget child;
  final double minimumHeight;
  final EdgeInsetsGeometry padding;
  final bool topBorder;
  @override
  Widget build(BuildContext context) => controls.strip(
    child,
    minimumHeight: minimumHeight,
    padding: padding,
    topBorder: topBorder,
  );
}

/// Section navigation uses the same selection vocabulary as document tabs.
class WorkbenchSection extends StatelessWidget {
  const WorkbenchSection({
    super.key,
    required this.controls,
    required this.label,
    required this.selected,
    required this.onPressed,
  });
  final DesktopControls controls;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: controls.section(label, selected, onPressed),
  );
}

/// Forms use readable line lengths without changing their scroll ownership.
class WorkbenchForm extends StatelessWidget {
  const WorkbenchForm({
    super.key,
    required this.child,
    this.maxWidth = 760,
    this.footer,
  });
  final Widget child;
  final double maxWidth;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: footer == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: child),
                footer!,
              ],
            ),
    ),
  );
}

/// Native forms keep related controls compact without running rows together.
class WorkbenchFormList extends StatelessWidget {
  const WorkbenchFormList({
    super.key,
    required this.children,
    required this.controls,
    this.padding = const EdgeInsets.all(12),
  });
  final List<Widget> children;
  final DesktopControls controls;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => controls.formList(children, padding);
}

class WorkbenchFormHeading extends StatelessWidget {
  const WorkbenchFormHeading({
    super.key,
    required this.controls,
    required this.label,
  });
  final DesktopControls controls;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      container: true,
      header: true,
      child: Text(label, style: controls.appearance(context).heading),
    ),
  );
}

/// Non-selectable evidence with independently actionable descendant controls.
/// Unlike a selectable record, it does not merge or replace their semantics.
class WorkbenchEvidenceRecord extends StatelessWidget {
  const WorkbenchEvidenceRecord({
    super.key,
    required this.controls,
    required this.child,
  });
  final DesktopControls controls;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: controls.appearance(context).view,
      border: Border(
        bottom: BorderSide(color: controls.appearance(context).separator),
      ),
    ),
    child: child,
  );
}

class WorkbenchRecord extends StatefulWidget {
  const WorkbenchRecord({
    super.key,
    required this.controls,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.child,
    this.selectionFocused,
    this.takeFocus = true,
    this.leading,
    this.onFocusChange,
  });
  final bool? selectionFocused;
  final bool takeFocus;
  final DesktopControls controls;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final Widget child;
  final DesktopIcon? leading;
  final ValueChanged<bool>? onFocusChange;
  @override
  State<WorkbenchRecord> createState() => WorkbenchRecordState();
}

/// Selection/focus paint for trees and other widgets that own their traversal.
class WorkbenchRowSurface extends StatelessWidget {
  const WorkbenchRowSurface({
    super.key,
    required this.controls,
    required this.selected,
    required this.focused,
    required this.child,
    this.hovered = false,
    this.base,
  });
  final DesktopControls controls;
  final bool selected, focused, hovered;
  final Color? base;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final look = controls.appearance(context);
    final foreground = look.rowForeground(selected: selected, focused: focused);
    return controls.rowSurface(
      selected: selected,
      focused: focused,
      hovered: hovered,
      base: base,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: child,
        ),
      ),
    );
  }
}

/// Native labels stack when their measured column would crowd the value.
class WorkbenchProperty extends StatelessWidget {
  const WorkbenchProperty({
    super.key,
    required this.controls,
    required this.label,
    required this.child,
    this.onLabel,
    this.labelWidth,
    this.minimumValueWidth,
    this.readOnly = false,
  });
  final DesktopControls controls;
  final String label;
  final Widget child;
  final VoidCallback? onLabel;
  final double? labelWidth;
  final double? minimumValueWidth;

  /// Read-only values need their visible property name in the same semantic
  /// record. Form inputs supply their own name and exclude the visual label.
  final bool readOnly;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final look = controls.appearance(context);
      final painter = TextPainter(
        text: TextSpan(text: label, style: look.body),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final naturalWidth = painter.width + 12;
      painter.dispose();
      final width = labelWidth ?? naturalWidth;
      final title = ExcludeSemantics(
        excluding: !readOnly,
        child: GestureDetector(
          onTap: onLabel,
          child: Text(
            label,
            style: look.body.copyWith(
              color: DefaultTextStyle.of(context).style.color,
            ),
          ),
        ),
      );
      final stack = minimumValueWidth == null
          ? width > bounds.maxWidth * .38 ||
                bounds.maxWidth < look.lineHeight(context) * 18
          : bounds.maxWidth < width + minimumValueWidth!;
      final Widget row;
      if (stack) {
        row = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty) ...[title, const SizedBox(height: 4)],
            child,
          ],
        );
      } else {
        row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: width, child: title),
            Expanded(child: child),
          ],
        );
      }
      return readOnly ? MergeSemantics(child: row) : row;
    },
  );
}

/// A selectable property value owns its real focus action. SelectableText's
/// default read-only semantics do not supply one to the native reader bridge.
/// Keep its editing state when the label changes between columns and a stack.
class WorkbenchReadOnlyProperty extends StatefulWidget {
  const WorkbenchReadOnlyProperty({
    super.key,
    required this.controls,
    required this.label,
    required this.value,
    this.labelWidth,
    this.keyboardTraversal = false,
  });
  final DesktopControls controls;
  final String label, value;
  final double? labelWidth;
  final bool keyboardTraversal;

  @override
  State<WorkbenchReadOnlyProperty> createState() =>
      _WorkbenchReadOnlyPropertyState();
}

class _WorkbenchReadOnlyPropertyState extends State<WorkbenchReadOnlyProperty> {
  final _focus = FocusNode(
    debugLabel: 'Read-only property',
    skipTraversal: true,
  );
  final _valueKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _focus.skipTraversal = !widget.keyboardTraversal;
  }

  @override
  void didUpdateWidget(covariant WorkbenchReadOnlyProperty oldWidget) {
    super.didUpdateWidget(oldWidget);
    _focus.skipTraversal = !widget.keyboardTraversal;
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _focus,
    builder: (context, _) => WorkbenchRowSurface(
      controls: widget.controls,
      selected: false,
      focused: _focus.hasFocus,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: WorkbenchProperty(
          controls: widget.controls,
          label: widget.label,
          labelWidth: widget.labelWidth,
          readOnly: true,
          child: Semantics(
            enabled: true,
            focusable: true,
            focused: _focus.hasFocus,
            onFocus: () {
              if (mounted &&
                  _focus.canRequestFocus &&
                  ModalRoute.of(context)?.isCurrent != false) {
                _focus.requestFocus();
              }
            },
            child: SelectableText(
              widget.value,
              key: _valueKey,
              focusNode: _focus,
              style: widget.controls.appearance(context).technical,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Dialogs with an inner viewport use the shell's remaining allocation.
class WorkbenchDialogBody extends StatelessWidget {
  const WorkbenchDialogBody({
    super.key,
    required this.child,
    this.maxHeight = 600,
    this.maxWidth = 760,
  });
  final Widget child;
  final double maxHeight, maxWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => SizedBox(
      width: bounds.maxWidth.clamp(0.0, maxWidth),
      height: bounds.maxHeight.clamp(0.0, maxHeight),
      child: child,
    ),
  );
}

class WorkbenchRecordState extends State<WorkbenchRecord> {
  bool hover = false, focus = false, pressed = false;
  final node = FocusNode(debugLabel: 'Workbench record');
  void requestFocus() {
    if (mounted && node.canRequestFocus) node.requestFocus();
  }

  void selectRecord() {
    if (widget.takeFocus) node.requestFocus();
    widget.onPressed?.call();
  }

  @override
  void dispose() {
    node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    selected: widget.selected,
    button: true,
    enabled: widget.onPressed != null,
    focusable: widget.onPressed != null,
    focused: node.hasFocus,
    label: widget.label,
    onTap: widget.onPressed == null ? null : selectRecord,
    onFocus: widget.onPressed == null ? null : node.requestFocus,
    child: FocusableActionDetector(
      focusNode: node,
      enabled: widget.onPressed != null,
      onFocusChange: (focused) {
        if (mounted) setState(() {});
        widget.onFocusChange?.call(focused);
      },
      onShowFocusHighlight: (value) => setState(() => focus = value),
      onShowHoverHighlight: (value) => setState(() => hover = value),
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            selectRecord();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTapDown: widget.onPressed == null
            ? null
            : (_) => setState(() => pressed = true),
        onTapUp: (_) => setState(() => pressed = false),
        onTapCancel: () => setState(() => pressed = false),
        onTap: widget.onPressed == null ? null : selectRecord,
        behavior: HitTestBehavior.opaque,
        child: widget.controls.rowSurface(
          selected: widget.selected,
          focused: widget.selectionFocused ?? node.hasFocus,
          focusVisible: focus,
          hovered: hover || pressed,
          child: widget.controls.recordContent(
            leading: widget.leading,
            DefaultTextStyle.merge(
              style: TextStyle(
                color: widget.controls
                    .appearance(context)
                    .rowForeground(
                      selected: widget.selected,
                      focused: widget.selectionFocused ?? node.hasFocus,
                      enabled: widget.onPressed != null,
                    ),
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: widget.controls
                      .appearance(context)
                      .rowForeground(
                        selected: widget.selected,
                        focused: widget.selectionFocused ?? node.hasFocus,
                        enabled: widget.onPressed != null,
                      ),
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
