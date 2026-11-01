import 'package:flutter/widgets.dart';
import 'dart:math' as math;
import '../../features/workspace/workbench_model.dart';
import '../../features/workspace/documents.dart' show SqlDocument;
import 'desktop_controls.dart';
import '../../l10n/workbench_strings.dart';
import 'sql_parameter_information.dart';
import 'sql_editor_geometry.dart';
import 'sql_editor_view.dart';

class WorkbenchCompletion extends StatefulWidget {
  const WorkbenchCompletion({
    super.key,
    required this.model,
    required this.document,
    required this.controls,
    required this.scrollController,
    required this.child,
  });
  final WorkbenchModel model;
  final SqlDocument document;
  final DesktopControls controls;
  final SqlEditorScrollController scrollController;
  final Widget child;
  @override
  State<WorkbenchCompletion> createState() => _WorkbenchCompletionState();
}

class _WorkbenchCompletionState extends State<WorkbenchCompletion> {
  final viewportKey = GlobalKey();
  AcceptedAnalysis? displayed, dismissed;
  int selected = 0;
  WorkbenchModel get model => widget.model;
  SqlDocument get document => widget.document;
  DesktopControls get controls => widget.controls;
  AcceptedAnalysis? get current {
    final accepted = model.acceptedAnalysis;
    if (accepted == null ||
        identical(accepted, dismissed) ||
        !identical(accepted.binding.document, document) ||
        !model.analysisResultMatches(accepted) ||
        document.editor.isComposing ||
        accepted.result.completions.isEmpty) {
      return null;
    }
    return accepted;
  }

  @override
  void initState() {
    super.initState();
    widget.model.addListener(changed);
  }

  @override
  void didUpdateWidget(WorkbenchCompletion old) {
    super.didUpdateWidget(old);
    if (old.model != widget.model) {
      old.model.removeListener(changed);
      widget.model.addListener(changed);
    }
    if (old.document != document || old.model != widget.model) {
      displayed = null;
      dismissed = null;
      selected = 0;
    }
  }

  void releaseSuperseded() {
    if (!identical(model.acceptedAnalysis, dismissed)) dismissed = null;
  }

  void changed() {
    releaseSuperseded();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.model.removeListener(changed);
    super.dispose();
  }

  bool move(AxisDirection direction) {
    if (!mounted) return false;
    final accepted = current;
    if (accepted == null ||
        !{AxisDirection.up, AxisDirection.down}.contains(direction)) {
      return false;
    }
    final count = accepted.result.completions.length;
    setState(
      () => selected =
          (selected + (direction == AxisDirection.up ? -1 : 1)) % count,
    );
    return true;
  }

  bool commit([int? index]) {
    if (!mounted) return false;
    final accepted = current;
    if (accepted == null) return false;
    final at = index ?? selected;
    if (at < 0 || at >= accepted.result.completions.length) return false;
    final applied = model.applyCompletion(
      accepted,
      accepted.result.completions[at],
    );
    if (applied) {
      dismissed = accepted;
      widget.scrollController.geometry.focusEditor?.call();
      if (mounted) setState(() {});
    }
    return applied;
  }

  bool dismiss() {
    if (!mounted) return false;
    final accepted = current;
    if (accepted == null) return false;
    setState(() => dismissed = accepted);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    releaseSuperseded();
    final accepted = current;
    if (!identical(displayed, accepted)) {
      displayed = accepted;
      selected = 0;
    }
    return SqlCompletionKeyboardScope(
      active: accepted != null,
      move: move,
      commit: commit,
      dismiss: dismiss,
      child: LayoutBuilder(
        builder: (context, bounds) => Stack(
          key: viewportKey,
          children: [
            Column(
              children: [
                Expanded(child: widget.child),
                SqlParameterInformation(
                  model: model,
                  document: document,
                  controls: controls,
                ),
              ],
            ),
            if (accepted != null)
              ListenableBuilder(
                listenable: widget.scrollController.geometry,
                builder: (context, _) => popup(context, accepted, bounds),
              ),
          ],
        ),
      ),
    );
  }

  Widget popup(
    BuildContext context,
    AcceptedAnalysis accepted,
    BoxConstraints bounds,
  ) {
    if (!identical(current, accepted)) return const SizedBox.shrink();
    final geometry = widget.scrollController.geometry,
        viewport = geometry.viewport;
    final anchor = geometry.contextMenuAnchor(document.editor.selection.extent);
    final render = viewportKey.currentContext?.findRenderObject();
    if (viewport == null ||
        anchor == null ||
        render is! RenderBox ||
        !render.hasSize ||
        render.size.isEmpty) {
      return const SizedBox.shrink();
    }
    final origin = render.localToGlobal(Offset.zero),
        look = controls.appearance(context);
    final area = viewport.shift(-origin).intersect(Offset.zero & render.size);
    if (area.isEmpty) return const SizedBox.shrink();
    final words = accepted.result.completions;
    final width = math.min(480.0, math.max(1.0, area.width - 16));
    var candidateHeight = look.rowHeight(context);
    for (final item in words.take(32)) {
      final measured = TextPainter(
        text: TextSpan(text: item.label, style: look.body),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout(maxWidth: math.max(1, width - 20));
      candidateHeight = math.max(candidateHeight, measured.height + 16);
      measured.dispose();
    }
    final limited = accepted.result.completionLimited;
    final height = math.min(
      area.height,
      math.min(
        280.0,
        candidateHeight * words.length.clamp(1, 6) +
            8 +
            (limited ? candidateHeight : 0),
      ),
    );
    final point = anchor - origin;
    final left = point.dx.clamp(
      area.left,
      math.max(area.left, area.right - width),
    );
    final below = point.dy + height <= area.bottom;
    final top = (below ? point.dy : point.dy - candidateHeight - height).clamp(
      area.top,
      math.max(area.top, area.bottom - height),
    );
    return Positioned(
      left: left.toDouble(),
      top: top.toDouble(),
      width: width,
      height: height,
      child: controls.completionSurface(
        Column(
          children: [
            if (limited)
              Padding(
                padding: const EdgeInsets.all(6),
                child: Text(
                  strings(context).completionLimited,
                  style: look.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Expanded(
              child: _CompletionRows(
                controls: controls,
                maxLines: 1,
                words: [for (final item in words) item.label],
                kinds: [
                  for (final item in words)
                    item.detail.isEmpty ? item.kind : item.detail,
                ],
                selected: selected.clamp(0, words.length - 1),
                select: (index) => commit(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionRows extends StatefulWidget {
  const _CompletionRows({
    required this.controls,
    required this.words,
    required this.kinds,
    required this.selected,
    required this.select,
    required this.maxLines,
  });
  final int maxLines;
  final DesktopControls controls;
  final List<String> words, kinds;
  final int selected;
  final ValueChanged<int> select;
  @override
  State<_CompletionRows> createState() => _CompletionRowsState();
}

class _CompletionRowsState extends State<_CompletionRows> {
  final scroll = ScrollController();
  final selectedKey = GlobalKey();
  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = selectedKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: .5,
          duration: Duration.zero,
        );
      }
    });
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final (i, word) in widget.words.indexed)
          KeyedSubtree(
            key: i == widget.selected ? selectedKey : ValueKey(i),
            child: widget.controls.completionRow(
              selected: i == widget.selected,
              onPressed: () => widget.select(i),
              child: Row(
                children: [
                  Expanded(
                    child: widget.controls.tooltip(
                      word,
                      Text(
                        word,
                        style: widget.controls.appearance(context).body,
                        textDirection: TextDirection.ltr,
                        maxLines: widget.maxLines,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: widget.controls.tooltip(
                      widget.kinds[i],
                      Text(
                        widget.kinds[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: widget.controls.appearance(context).caption,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
