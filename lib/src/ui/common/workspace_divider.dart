import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../features/workspace/workbench_model.dart';
import 'desktop_controls.dart';
import '../../l10n/workbench_strings.dart';

class WorkspaceDivider extends StatefulWidget {
  const WorkspaceDivider({
    super.key,
    required this.model,
    required this.controls,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  @override
  State<WorkspaceDivider> createState() => _WorkspaceDividerState();
}

class _WorkspaceDividerState extends State<WorkspaceDivider> {
  bool focused = false;
  void resize(double fraction, {bool save = false}) {
    widget.model.resizeEditor(fraction);
    if (save) widget.model.command(widget.model.savePresentation);
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    enabled: true,
    label: strings(context).editorResultsDivider,
    value: strings(
      context,
    ).editorExtent('${(widget.model.editorFraction * 100).round()}'),
    increasedValue: strings(context).largerEditor,
    decreasedValue: strings(context).smallerEditor,
    onIncrease: () => resize(widget.model.editorFraction + .05, save: true),
    onDecrease: () => resize(widget.model.editorFraction - .05, save: true),
    child: Focus(
      onFocusChange: (value) => setState(() => focused = value),
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          resize(widget.model.editorFraction - .05, save: true);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          resize(widget.model.editorFraction + .05, save: true);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (event) => resize(
            widget.model.editorFraction +
                event.delta.dy / MediaQuery.sizeOf(context).height,
          ),
          onVerticalDragEnd: (_) =>
              widget.model.command(widget.model.savePresentation),
          child: SizedBox(
            height: 12,
            child: Center(
              child: Container(
                height: focused || MediaQuery.highContrastOf(context) ? 3 : 1,
                color: focused
                    ? widget.controls.accent(context)
                    : widget.controls.appearance(context).separator,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
