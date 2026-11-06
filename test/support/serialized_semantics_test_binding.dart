// Capture the supported engine-bound semantics contract, including incremental
// updates that a final public SemanticsNode tree inspection cannot detect.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

class SerializedSemanticsTestBinding
    extends AutomatedTestWidgetsFlutterBinding {
  static String phase = 'initial';
  static final batches = <Map<String, Object?>>[];
  static final graph = <int, Map<String, Object?>>{};
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() =>
      RecordingSemanticsBuilder();
  static void resetRecorder() {
    batches.clear();
    graph.clear();
    phase = 'initial';
  }

  static List<Map<String, Object?>> get orphanBatches => batches
      .where(
        (batch) => (batch['updatedUnreachableFromRoot']! as List).isNotEmpty,
      )
      .toList();
}

class RecordingSemanticsBuilder implements ui.SemanticsUpdateBuilder {
  final delegate = ui.SemanticsUpdateBuilder();
  final updates = <Map<String, Object?>>[];
  @override
  void updateNode({
    required int id,
    required ui.SemanticsFlags flags,
    required int actions,
    required int maxValueLength,
    required int currentValueLength,
    required int textSelectionBase,
    required int textSelectionExtent,
    required int platformViewId,
    required int scrollChildren,
    required int scrollIndex,
    required int traversalParent,
    required double scrollPosition,
    required double scrollExtentMax,
    required double scrollExtentMin,
    required ui.Rect rect,
    required String identifier,
    required String label,
    required List<ui.StringAttribute> labelAttributes,
    required String value,
    required List<ui.StringAttribute> valueAttributes,
    required String increasedValue,
    required List<ui.StringAttribute> increasedValueAttributes,
    required String decreasedValue,
    required List<ui.StringAttribute> decreasedValueAttributes,
    required String hint,
    required List<ui.StringAttribute> hintAttributes,
    required String tooltip,
    required ui.TextDirection? textDirection,
    required Float64List transform,
    required Float64List hitTestTransform,
    required Int32List childrenInTraversalOrder,
    required Int32List childrenInHitTestOrder,
    required Int32List additionalActions,
    int headingLevel = 0,
    String linkUrl = '',
    ui.SemanticsRole role = ui.SemanticsRole.none,
    required List<String>? controlsNodes,
    ui.SemanticsValidationResult validationResult =
        ui.SemanticsValidationResult.none,
    ui.SemanticsHitTestBehavior hitTestBehavior =
        ui.SemanticsHitTestBehavior.defer,
    required ui.SemanticsInputType inputType,
    required ui.Locale? locale,
    required String minValue,
    required String maxValue,
  }) {
    updates.add({
      'id': id,
      'label': label,
      'identifier': identifier,
      'traversalParent': traversalParent,
      'children': childrenInTraversalOrder.toList(),
      'hitChildren': childrenInHitTestOrder.toList(),
    });
    delegate.updateNode(
      id: id,
      flags: flags,
      actions: actions,
      maxValueLength: maxValueLength,
      currentValueLength: currentValueLength,
      textSelectionBase: textSelectionBase,
      textSelectionExtent: textSelectionExtent,
      platformViewId: platformViewId,
      scrollChildren: scrollChildren,
      scrollIndex: scrollIndex,
      traversalParent: traversalParent,
      scrollPosition: scrollPosition,
      scrollExtentMax: scrollExtentMax,
      scrollExtentMin: scrollExtentMin,
      rect: rect,
      identifier: identifier,
      label: label,
      labelAttributes: labelAttributes,
      value: value,
      valueAttributes: valueAttributes,
      increasedValue: increasedValue,
      increasedValueAttributes: increasedValueAttributes,
      decreasedValue: decreasedValue,
      decreasedValueAttributes: decreasedValueAttributes,
      hint: hint,
      hintAttributes: hintAttributes,
      tooltip: tooltip,
      textDirection: textDirection,
      transform: transform,
      hitTestTransform: hitTestTransform,
      childrenInTraversalOrder: childrenInTraversalOrder,
      childrenInHitTestOrder: childrenInHitTestOrder,
      additionalActions: additionalActions,
      headingLevel: headingLevel,
      linkUrl: linkUrl,
      role: role,
      controlsNodes: controlsNodes,
      validationResult: validationResult,
      hitTestBehavior: hitTestBehavior,
      inputType: inputType,
      locale: locale,
      minValue: minValue,
      maxValue: maxValue,
    );
  }

  @override
  void updateCustomAction({
    required int id,
    String? label,
    String? hint,
    int overrideId = -1,
  }) => delegate.updateCustomAction(
    id: id,
    label: label,
    hint: hint,
    overrideId: overrideId,
  );
  @override
  ui.SemanticsUpdate build() {
    final graph = SerializedSemanticsTestBinding.graph;
    for (final n in updates) {
      graph[n['id']! as int] = n;
    }
    final reachable = <int>{};
    void visit(int id) {
      if (!reachable.add(id)) return;
      for (final c in (graph[id]?['children'] as List<int>?) ?? <int>[]) {
        visit(c);
      }
    }

    visit(0);
    final orphans = updates.where((n) => !reachable.contains(n['id'])).toList();
    SerializedSemanticsTestBinding.batches.add({
      'phase': SerializedSemanticsTestBinding.phase,
      'updates': updates,
      'updatedUnreachableFromRoot': orphans,
    });
    graph.removeWhere((id, n) => !reachable.contains(id));
    return delegate.build();
  }
}
