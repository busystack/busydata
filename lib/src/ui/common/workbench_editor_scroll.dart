import 'package:flutter/widgets.dart';
import 'sql_editor_geometry.dart';
import '../../features/workspace/workbench_documents.dart';

/// Mounted SQL editors own their controllers; document views retain plain offsets.
class WorkbenchEditorScroll extends StatefulWidget {
  const WorkbenchEditorScroll({
    super.key,
    this.view,
    required this.builder,
    this.presentation,
  });
  final DocumentViewState? view;
  final Widget Function(SqlEditorScrollController) builder;
  final Object? presentation;
  @override
  State<WorkbenchEditorScroll> createState() => _WorkbenchEditorScrollState();
}

class _WorkbenchEditorScrollState extends State<WorkbenchEditorScroll> {
  late final vertical = ScrollController(
    initialScrollOffset: widget.view?.editorVertical ?? 0,
    keepScrollOffset: false,
  );
  late final horizontal = ScrollController(
    initialScrollOffset: widget.view?.editorHorizontal ?? 0,
    keepScrollOffset: false,
  );
  late final scroll = SqlEditorScrollController(
    verticalScroller: vertical,
    horizontalScroller: horizontal,
  );
  ({double vertical, double horizontal})? _appearanceOffsets;
  int _appearanceRevision = 0;
  bool _restoringAppearance = false;

  void _cancelAppearanceRestore() {
    _appearanceOffsets = null;
    _appearanceRevision++;
  }

  @override
  void didUpdateWidget(covariant WorkbenchEditorScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.presentation == widget.presentation || !vertical.hasClients) {
      return;
    }
    if (vertical.position.isScrollingNotifier.value ||
        (horizontal.hasClients &&
            horizontal.position.isScrollingNotifier.value)) {
      _cancelAppearanceRestore();
      return;
    }
    // Reflow corrects cached paragraph offsets during layout. Keep the actual
    // viewport through that correction, without replacing either controller.
    _appearanceOffsets ??= (
      vertical: vertical.offset,
      horizontal: horizontal.hasClients ? horizontal.offset : 0,
    );
    final revision = ++_appearanceRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != _appearanceRevision) return;
      final offsets = _appearanceOffsets;
      _appearanceOffsets = null;
      if (offsets == null) return;
      _restoringAppearance = true;
      try {
        for (final (controller, offset) in [
          (vertical, offsets.vertical),
          (horizontal, offsets.horizontal),
        ]) {
          if (!controller.hasClients ||
              !controller.position.hasContentDimensions) {
            continue;
          }
          final target = offset.clamp(
            controller.position.minScrollExtent,
            controller.position.maxScrollExtent,
          );
          if (controller.offset != target) controller.jumpTo(target);
        }
      } finally {
        _restoringAppearance = false;
      }
    });
  }

  void save() {
    final view = widget.view;
    if (view == null) return;
    if (vertical.hasClients) view.editorVertical = vertical.offset;
    if (horizontal.hasClients) view.editorHorizontal = horizontal.offset;
  }

  @override
  void initState() {
    super.initState();
    vertical.addListener(save);
    horizontal.addListener(save);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollStartNotification>(
        onNotification: (_) {
          // New pointer, keyboard or programmatic navigation owns the viewport.
          if (!_restoringAppearance) _cancelAppearanceRestore();
          return false;
        },
        child: widget.builder(scroll),
      );
  @override
  void dispose() {
    scroll.dispose();
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }
}
