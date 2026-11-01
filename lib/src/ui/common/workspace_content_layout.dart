import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Measures the existing controls before dividing the remaining workspace.
/// A large text scale must leave room for retained result headers and a row.
class WorkspaceContentLayout extends StatelessWidget {
  const WorkspaceContentLayout({
    super.key,
    required this.children,
    required this.minimumEditorExtent,
    required this.minimumResultExtent,
  });
  final List<Widget> children;
  final double minimumEditorExtent, minimumResultExtent;

  @override
  Widget build(BuildContext context) {
    final panes = <int, int>{
      for (var index = 0; index < children.length; index++)
        if (children[index] case final Expanded pane) index: pane.flex,
    };
    assert(panes.isNotEmpty && panes.length <= 2);
    return CustomMultiChildLayout(
      delegate: _WorkspaceContentDelegate(
        children.length,
        panes,
        minimumEditorExtent,
        minimumResultExtent,
      ),
      children: [
        for (var index = 0; index < children.length; index++)
          LayoutId(
            key: children[index].key,
            id: index,
            child: children[index] is Expanded
                ? (children[index] as Expanded).child
                : children[index],
          ),
      ],
    );
  }
}

class _WorkspaceContentDelegate extends MultiChildLayoutDelegate {
  _WorkspaceContentDelegate(
    this.count,
    this.panes,
    this.minimumEditorExtent,
    this.minimumResultExtent,
  );
  final int count;
  final Map<int, int> panes;
  final double minimumEditorExtent, minimumResultExtent;

  @override
  void performLayout(Size size) {
    final heights = <int, double>{};
    var fixedExtent = 0.0;
    for (var index = 0; index < count; index++) {
      if (panes.containsKey(index)) continue;
      final extent = layoutChild(
        index,
        BoxConstraints.tightFor(width: size.width),
      ).height;
      heights[index] = extent;
      fixedExtent += extent;
    }
    final available = math.max(0.0, size.height - fixedExtent);
    if (panes.length == 1) {
      heights[panes.keys.single] = available;
      layoutChild(
        panes.keys.single,
        BoxConstraints.tight(Size(size.width, available)),
      );
    } else {
      final editor = panes.keys.first, result = panes.keys.last;
      final fraction = panes[editor]! / panes.values.reduce((a, b) => a + b);
      final editorMinimum = math.min(minimumEditorExtent, available);
      final resultMinimum = math.min(
        minimumResultExtent,
        math.max(0.0, available - editorMinimum),
      );
      // Subtracting the reserved result minimum can round below the editor
      // minimum by a few ulps. Keep the mathematically feasible interval ordered
      // so dynamic controls never abort the positioning pass.
      final editorMaximum = math.max(editorMinimum, available - resultMinimum);
      final editorExtent = (available * fraction).clamp(
        editorMinimum,
        editorMaximum,
      );
      heights[editor] = editorExtent;
      heights[result] = available - editorExtent;
      for (final index in panes.keys) {
        layoutChild(
          index,
          BoxConstraints.tight(Size(size.width, heights[index]!)),
        );
      }
    }
    var position = 0.0;
    for (var index = 0; index < count; index++) {
      positionChild(index, Offset(0, position));
      position += heights[index]!;
    }
  }

  @override
  bool shouldRelayout(_WorkspaceContentDelegate oldDelegate) =>
      count != oldDelegate.count ||
      minimumEditorExtent != oldDelegate.minimumEditorExtent ||
      minimumResultExtent != oldDelegate.minimumResultExtent ||
      panes.toString() != oldDelegate.panes.toString();
}
