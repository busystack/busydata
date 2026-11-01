import '../../l10n/workbench_strings.dart';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import '../../features/workspace/documents.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';

class PlanEntry {
  PlanEntry(this.label, this.depth, this.branch, this.parent);
  final String label;
  final int depth;
  final bool branch;
  final int? parent;
}

/// Only server evidence is rendered. Text plans retain their original metrics.
class PlanData {
  PlanData(this.raw, this.entries);
  final String raw;
  final List<PlanEntry> entries;
  final collapsed = <int>{}, previousRawPages = <int>[];
  bool showRaw = false;
  int selected = 0, rawOffset = 0;
  double scrollOffset = 0;
  static PlanData parse(String raw) {
    if (raw.length > 1048576 || utf8.encode(raw).length > 1048576) {
      throw StateError(
        'Plan exceeds the 1MiB inspector budget; use retained-cell inspection or export',
      );
    }
    final entries = <PlanEntry>[];
    void add(String label, int depth, bool branch, int? parent) {
      if (entries.length >= 4096 || depth > 32) {
        throw StateError(
          'Plan exceeds 4096 nodes or 32 levels; raw evidence remains retained',
        );
      }
      entries.add(
        PlanEntry(
          label.length > 8192
              ? '${label.substring(0, 8192)}… (full value in raw output)'
              : label,
          depth,
          branch,
          parent,
        ),
      );
    }

    final trimmed = raw.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      checkJsonNesting(raw);
      final pending = <({Object? value, String name, int depth, int? parent})>[
        (value: jsonDecode(raw), name: 'Plan', depth: 0, parent: null),
      ];
      while (pending.isNotEmpty) {
        final item = pending.removeLast(), value = item.value;
        final children = value is Map
            ? value.entries.map((e) => MapEntry('${e.key}', e.value)).toList()
            : value is List
            ? [for (int i = 0; i < value.length; i++) MapEntry('$i', value[i])]
            : <MapEntry<String, Object?>>[];
        final index = entries.length;
        final nodeName = value is Map && value['Node Type'] != null
            ? '${item.name}: ${value['Node Type']}'
            : item.name;
        add(
          children.isEmpty ? '$nodeName: $value' : nodeName,
          item.depth,
          children.isNotEmpty,
          item.parent,
        );
        for (final child in children.reversed) {
          pending.add((
            value: child.value,
            name: child.key,
            depth: item.depth + 1,
            parent: index,
          ));
        }
      }
    } else {
      final parents = <({int indent, int index})>[];
      for (final line in const LineSplitter().convert(raw)) {
        if (line.trim().isEmpty) continue;
        final indent = line.length - line.trimLeft().length;
        while (parents.isNotEmpty && parents.last.indent >= indent) {
          parents.removeLast();
        }
        final index = entries.length;
        add(line.trimLeft(), parents.length, true, parents.lastOrNull?.index);
        parents.add((indent: indent, index: index));
      }
    }
    return PlanData(raw, List.unmodifiable(entries));
  }
}

class PlanView extends StatefulWidget {
  const PlanView({
    super.key,
    required this.data,
    required this.controls,
    this.contextActions = const [],
  });
  final PlanData data;
  final DesktopControls controls;
  final List<DesktopMenuAction> contextActions;
  @override
  State<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends State<PlanView> {
  late final collapsed = widget.data.collapsed;
  final rowKeys = <int, GlobalKey>{};
  late final scroll = ScrollController(
    initialScrollOffset: widget.data.scrollOffset,
  );
  late final previousRawPages = widget.data.previousRawPages;
  final focus = FocusNode(debugLabel: 'Execution plan navigation');
  late bool raw = widget.data.showRaw;
  late int selected = widget.data.selected, rawOffset = widget.data.rawOffset;
  List<int> get visible {
    final list = <int>[];
    for (int i = 0; i < widget.data.entries.length; i++) {
      int? parent = widget.data.entries[i].parent;
      bool hidden = false;
      while (parent != null) {
        if (collapsed.contains(parent)) {
          hidden = true;
          break;
        }
        parent = widget.data.entries[parent].parent;
      }
      if (!hidden) list.add(i);
    }
    return list;
  }

  @override
  void dispose() {
    widget.data.showRaw = raw;
    widget.data.selected = selected;
    widget.data.rawOffset = rawOffset;
    if (scroll.hasClients) widget.data.scrollOffset = scroll.offset;
    focus.dispose();
    scroll.dispose();
    super.dispose();
  }

  KeyEventResult key(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final rows = visible, offset = rows.indexOf(selected);
    if (rows.isEmpty) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      activateNode(selected);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(
        () => selected =
            rows[(offset +
                    (event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1))
                .clamp(0, rows.length - 1)],
      );
    } else if (event.logicalKey ==
        (Directionality.of(context) == TextDirection.ltr
            ? LogicalKeyboardKey.arrowLeft
            : LogicalKeyboardKey.arrowRight)) {
      setState(() {
        if (widget.data.entries[selected].branch &&
            !collapsed.contains(selected)) {
          collapsed.add(selected);
        } else {
          selected = widget.data.entries[selected].parent ?? selected;
        }
      });
    } else if (event.logicalKey ==
        (Directionality.of(context) == TextDirection.ltr
            ? LogicalKeyboardKey.arrowRight
            : LogicalKeyboardKey.arrowLeft)) {
      setState(() {
        if (collapsed.remove(selected)) return;
        if (offset + 1 < rows.length &&
            widget.data.entries[rows[offset + 1]].parent == selected) {
          selected = rows[offset + 1];
        }
      });
    } else {
      return KeyEventResult.ignored;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final row = rowKeys[selected]?.currentContext;
      if (row != null) {
        Scrollable.ensureVisible(row, alignment: 0.5, duration: Duration.zero);
      }
    });
    return KeyEventResult.handled;
  }

  void activateNode(int index) {
    setState(() {
      selected = index;
      if (widget.data.entries[index].branch && !collapsed.add(index)) {
        collapsed.remove(index);
      }
    });
    focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final look = widget.controls.appearance(context);
      final compact =
          constraints.maxHeight < 260 ||
          MediaQuery.textScalerOf(context).scale(14) > 21;
      final rows = visible;
      var end = (rawOffset + 16384).clamp(0, widget.data.raw.length);
      if (end < widget.data.raw.length &&
          end > rawOffset &&
          widget.data.raw.codeUnitAt(end - 1) >= 0xD800 &&
          widget.data.raw.codeUnitAt(end - 1) <= 0xDBFF) {
        end--;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              widget.controls.modeSwitcher<bool>(
                raw,
                {
                  false: strings(context).structuredTree,
                  true: strings(context).rawOutput,
                },
                (value) => setState(() => raw = value),
                label: strings(context).plan,
              ),
              widget.controls.iconMenu(strings(context).planDetails, [
                ...widget.contextActions,
                DesktopMenuAction(strings(context).planDetails, details),
              ], compact: compact),
              if (raw) ...[
                widget.controls.button(
                  strings(context).previousTextPage,
                  rawOffset == 0
                      ? null
                      : () => setState(
                          () => rawOffset = previousRawPages.removeLast(),
                        ),
                ),
                widget.controls.button(
                  strings(context).nextTextPage,
                  end == widget.data.raw.length
                      ? null
                      : () => setState(() {
                          previousRawPages.add(rawOffset);
                          rawOffset = end;
                        }),
                ),
                Text(
                  strings(context).planTextPage(
                    '$rawOffset',
                    '$end',
                    '${widget.data.raw.length}',
                  ),
                ),
              ],
            ],
          ),
          Expanded(
            child: raw
                ? SingleChildScrollView(
                    child: WorkbenchCodeEvidence(
                      controls: widget.controls,
                      text: widget.data.raw.substring(rawOffset, end),
                    ),
                  )
                : Focus(
                    focusNode: focus,
                    autofocus: true,
                    includeSemantics: false,
                    onFocusChange: (_) {
                      if (mounted) setState(() {});
                    },
                    onKeyEvent: key,
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: rows.length,
                      itemBuilder: (context, offset) {
                        final index = rows[offset],
                            node = widget.data.entries[index];
                        final foreground = look.rowForeground(
                          selected: selected == index,
                          focused: focus.hasFocus,
                        );
                        return Semantics(
                          key: rowKeys.putIfAbsent(index, GlobalKey.new),
                          selected: selected == index,
                          button: true,
                          enabled: true,
                          focusable: true,
                          focused: selected == index && focus.hasFocus,
                          onFocus: () {
                            setState(() => selected = index);
                            focus.requestFocus();
                          },
                          excludeSemantics: true,
                          onTap: () => activateNode(index),
                          label:
                              '${strings(context).level} ${node.depth + 1}, ${node.label}${node.branch ? ', ${collapsed.contains(index) ? strings(context).collapsed : strings(context).expanded}' : ''}',
                          expanded: node.branch
                              ? !collapsed.contains(index)
                              : null,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => activateNode(index),
                            child: WorkbenchRowSurface(
                              controls: widget.controls,
                              selected: selected == index,
                              focused: selected == index && focus.hasFocus,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 32,
                                ),
                                padding: EdgeInsetsDirectional.only(
                                  start:
                                      8 +
                                      node.depth * widget.controls.treeIndent,
                                  end: 8,
                                  top: 4,
                                  bottom: 4,
                                ),
                                child: IconTheme.merge(
                                  data: IconThemeData(color: foreground),
                                  child: Row(
                                    children: [
                                      if (node.branch)
                                        widget.controls.treeExpander(
                                          !collapsed.contains(index),
                                          node.label,
                                          () => activateNode(index),
                                        )
                                      else
                                        SizedBox(
                                          width: widget.controls.treeControl,
                                        ),
                                      Expanded(
                                        child: Text(
                                          node.label,
                                          style: look.technical.copyWith(
                                            color: foreground,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      );
    },
  );

  Future<void> details() => widget.controls.dialog<void>(
    context,
    strings(context).planDetails,
    Text(strings(context).planMetricsNote),
    [
      widget.controls.button(
        strings(context).close,
        () => Navigator.of(context).pop(),
      ),
    ],
  );
}
