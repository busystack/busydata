import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/results/result_presentation.dart';
import '../../features/results/structured_value.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'paged_selectable_text.dart';
import 'result_extractors.dart';
import 'workbench_presentation.dart';

typedef ResultCellReader = rpc.Value? Function(int row, int column);
typedef ResultAssignmentReader =
    rpc.ValueAssignment? Function(int row, int column);

String displayedResultValue(
  rpc.Value value,
  ColumnDisplayFormat format, {
  TemporalDisplayPattern? temporalPattern,
  String locale = 'en_US',
}) {
  if (value.truncated) return valueText(value);
  switch (format) {
    case ColumnDisplayFormat.temporalPattern:
      return value.hasTemporal()
          ? temporalPattern?.format(value.temporal, locale) ?? valueText(value)
          : valueText(value);
    case ColumnDisplayFormat.grouped:
      return groupExactNumber(valueText(value));
    case ColumnDisplayFormat.decimal2:
      return fixedDecimalDisplay(valueText(value), 2);
    case ColumnDisplayFormat.decimal4:
      return fixedDecimalDisplay(valueText(value), 4);
    case ColumnDisplayFormat.isoDate:
    case ColumnDisplayFormat.isoTime:
    case ColumnDisplayFormat.utc:
    case ColumnDisplayFormat.local:
      return value.hasTemporal()
          ? temporalDisplay(value.temporal, format)
          : valueText(value);
    case ColumnDisplayFormat.json:
      if (value.hasJson() || value.hasText()) {
        try {
          return StructuredJson.parse(
            value.hasJson() ? value.json : value.text,
          ).pretty();
        } on FormatException {
          return valueText(value);
        }
      }
    case ColumnDisplayFormat.base64:
      if (value.hasBinary()) return base64Encode(value.binary);
    case ColumnDisplayFormat.uuid:
      if (value.hasBinary() && value.binary.length == 16) {
        final hex = valueText(value);
        return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      }
    case ColumnDisplayFormat.canonical:
    case ColumnDisplayFormat.hexadecimal:
    case ColumnDisplayFormat.wrap:
      break;
  }
  return valueText(value);
}

/// Presentation bridge to the existing retained-result/page/draft owners. Every
/// mode reads the same cells and invokes the same source-mapped edit callback.
class ResultPresentationHost extends StatelessWidget {
  const ResultPresentationHost({
    super.key,
    required this.controls,
    required this.state,
    required this.result,
    required this.columns,
    required this.selectedRow,
    required this.selectedColumn,
    required this.anchorRow,
    required this.anchorColumn,
    required this.windowStart,
    required this.windowRows,
    required this.valueAt,
    required this.originalAt,
    required this.assignmentAt,
    required this.select,
    required this.activateCell,
    required this.cellFocused,
    required this.inspect,
    required this.edit,
    required this.table,
    required this.changed,
    required this.editReason,
    this.sqlText,
  });
  final DesktopControls controls;
  final ResultPresentationState state;
  final rpc.StatementResult result;
  final List<int> columns;
  final int selectedRow,
      selectedColumn,
      anchorRow,
      anchorColumn,
      windowStart,
      windowRows;
  final ResultCellReader valueAt, originalAt;
  final ResultAssignmentReader assignmentAt;
  final void Function(int, int) select, inspect, edit;
  final void Function(int row, int column, bool record) activateCell;
  final bool Function(bool record) cellFocused;
  final String? Function(int, int) editReason;
  final Widget Function() table;
  final VoidCallback changed;
  final Future<String> Function(int firstRow, int rowCount, List<int> columns)?
  sqlText;

  String shown(BuildContext context, int row, int column) {
    final assignment = assignmentAt(row, column);
    if (assignment?.hasDefaultValue() == true) {
      return strings(context).assignmentDefault;
    }
    final value = valueAt(row, column);
    return value == null
        ? strings(context).loading
        : displayedResultValue(
            value,
            state.formats[column] ?? ColumnDisplayFormat.canonical,
            temporalPattern: state.temporalPatterns[column],
            locale: Localizations.localeOf(context).toLanguageTag(),
          );
  }

  Widget cell(
    BuildContext context,
    int row,
    int column, {
    bool vertical = false,
  }) {
    final l = strings(context), metadata = result.columns[column];
    final value = valueAt(row, column), assignment = assignmentAt(row, column);
    final text = shown(context, row, column);
    final selected = row == selectedRow && column == selectedColumn;
    final look = controls.appearance(context);
    final focused = selected && cellFocused(vertical);
    void activate() => activateCell(row, column, vertical);
    void inspectCell() {
      activate();
      inspect(row, column);
    }

    return Semantics(
      label: '${l.row} ${row + 1}, ${metadata.name}: $text',
      selected: selected,
      button: true,
      enabled: value != null,
      focusable: true,
      focused: focused,
      excludeSemantics: true,
      onFocus: activate,
      onTap: activate,
      onLongPress: value == null ? null : inspectCell,
      child: controls.contextMenu(
        Listener(
          onPointerDown: (_) => activate(),
          child: GestureDetector(
            onDoubleTap: inspectCell,
            child: controls.rowSurface(
              selected: selected,
              focused: focused,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '${assignment == null ? '' : '${l.pendingChange} · '}$text',
                    maxLines:
                        vertical ||
                            state.formats[column] == ColumnDisplayFormat.wrap
                        ? 4
                        : 1,
                    overflow: TextOverflow.ellipsis,
                    style: controls
                        .textStyle(context)
                        .copyWith(
                          color: look.rowForeground(
                            selected: selected,
                            focused: focused,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
        [
          DesktopMenuAction(
            l.inspectValue,
            inspectCell,
            disabledReason: value == null ? l.loadValueFirst : null,
          ),
          DesktopMenuAction(l.editCell, () {
            activate();
            edit(row, column);
          }, disabledReason: editReason(row, column)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (state.mode) {
      ResultPresentation.table => table(),
      ResultPresentation.transpose => _transpose(context),
      ResultPresentation.tree => _ResultTree(host: this),
      ResultPresentation.text => _ResultText(host: this),
    };
    if (!state.recordVisible ||
        result.columns.isEmpty ||
        result.fetchedRows.toInt() == 0) {
      return body;
    }
    return LayoutBuilder(
      builder: (context, size) {
        final record = _record(context);
        if (size.maxWidth < 720) return record;
        return Row(
          children: [
            Expanded(child: body),
            SizedBox(width: math.min(420, size.maxWidth * .42), child: record),
          ],
        );
      },
    );
  }

  Widget _record(BuildContext context) {
    final l = strings(context), look = controls.appearance(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(start: BorderSide(color: look.gridLine)),
      ),
      child: Column(
        children: [
          WorkbenchStrip(
            controls: controls,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${l.recordView} · ${l.row} ${selectedRow + 1}',
                        maxLines: 2,
                      ),
                    ),
                    controls.iconButton(DesktopIcon.close, l.close, () {
                      state.recordVisible = false;
                      changed();
                    }),
                  ],
                ),
                Wrap(
                  spacing: 4,
                  children: [
                    controls.textButton(
                      l.previousRecord,
                      selectedRow == 0
                          ? null
                          : () => select(selectedRow - 1, selectedColumn),
                    ),
                    controls.textButton(
                      l.nextRecord,
                      selectedRow + 1 >= result.fetchedRows.toInt()
                          ? null
                          : () => select(selectedRow + 1, selectedColumn),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: columns.length,
              itemBuilder: (context, index) {
                final column = columns[index],
                    metadata = result.columns[column];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 0),
                      child: Text(
                        '${metadata.name} · ${metadata.typeName} · ${metadata.nullable ? l.nullable : l.requiredColumn}',
                        style: controls.textStyle(context),
                      ),
                    ),
                    if (assignmentAt(selectedRow, column) != null &&
                        originalAt(selectedRow, column) != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${l.originalValue}: ${valueText(originalAt(selectedRow, column)!)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    cell(context, selectedRow, column, vertical: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          controls.textButton(
                            l.inspectValue,
                            valueAt(selectedRow, column) == null
                                ? null
                                : () => inspect(selectedRow, column),
                          ),
                          controls.tooltip(
                            editReason(selectedRow, column) ?? l.editCell,
                            controls.textButton(
                              l.editCell,
                              editReason(selectedRow, column) == null
                                  ? () => edit(selectedRow, column)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _transpose(BuildContext context) {
    final l = strings(context);
    final start = math.min(selectedRow, anchorRow),
        total = (selectedRow - anchorRow).abs() + 1;
    final rows = math.min(32, total);
    return Column(
      children: [
        if (total > rows) Text(l.transposeSelectionLimit),
        Expanded(
          child: TableView.builder(
            cacheExtent: 64,
            pinnedRowCount: 1,
            pinnedColumnCount: 1,
            rowCount: columns.length + 1,
            columnCount: rows + 1,
            columnBuilder: (i) =>
                TableSpan(extent: FixedTableSpanExtent(i == 0 ? 220 : 240)),
            rowBuilder: (i) =>
                const TableSpan(extent: FixedTableSpanExtent(48)),
            cellBuilder: (context, position) {
              final column = position.row == 0
                  ? null
                  : columns[position.row - 1];
              final row = start + position.column - 1;
              return TableViewCell(
                child: position.column == 0 || column == null
                    ? controls.recordContent(
                        Text(
                          column == null
                              ? (position.column == 0
                                    ? l.columns
                                    : '${l.row} ${row + 1}')
                              : '${result.columns[column].name} · ${result.columns[column].typeName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : cell(context, row, column),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultText extends StatefulWidget {
  const _ResultText({required this.host});
  final ResultPresentationHost host;
  @override
  State<_ResultText> createState() => _ResultTextState();
}

class _ResultTextState extends State<_ResultText> {
  Future<String>? sql;
  Object? sqlKey;
  @override
  Widget build(BuildContext context) {
    final h = widget.host, l = strings(context);
    final window = h.state.textScope == ResultTextScope.window;
    final first = window ? h.windowStart : math.min(h.selectedRow, h.anchorRow);
    final count = window
        ? math.min(h.windowRows, h.result.fetchedRows.toInt() - first)
        : (h.selectedRow - h.anchorRow).abs() + 1;
    final columns = window
        ? h.columns
        : h.columns
              .where(
                (c) =>
                    c >= math.min(h.selectedColumn, h.anchorColumn) &&
                    c <= math.max(h.selectedColumn, h.anchorColumn),
              )
              .toList();
    String? text;
    if (count * columns.length > 10000) {
      text = l.presentationScopeLimit;
    } else if (h.state.extractor != 'sql') {
      final rows = <List<rpc.Value>>[];
      for (var row = first; row < first + count; row++) {
        final values = <rpc.Value>[];
        for (final column in columns) {
          final value = h.valueAt(row, column);
          if (value == null ||
              h.assignmentAt(row, column)?.hasDefaultValue() == true) {
            text = value == null ? l.loading : l.assignmentDefault;
            break;
          }
          values.add(value);
        }
        if (text != null) break;
        rows.add(values);
      }
      if (text == null) {
        try {
          text = copyFetchedValues(rows, h.state.extractor);
        } catch (_) {
          text = l.presentationScopeLimit;
        }
      }
    }
    final key = (h.result.resultId, first, count, columns.join(','));
    if (h.state.extractor == 'sql' && text == null && sqlKey != key) {
      sqlKey = key;
      sql = h.sqlText?.call(first, count, columns);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WorkbenchStrip(
          controls: h.controls,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              h.controls.choice(
                h.state.textScope,
                {
                  ResultTextScope.selection: l.selectedCellsScope,
                  ResultTextScope.window: l.retainedWindowScope,
                },
                (v) {
                  h.state.textScope = v;
                  h.changed();
                },
              ),
              h.controls.choice(
                h.state.extractor,
                {
                  'text': l.textValue,
                  'csv': 'CSV',
                  'json': 'JSON',
                  if (h.sqlText != null) 'sql': l.sqlValues,
                },
                (v) {
                  h.state.extractor = v;
                  h.changed();
                },
              ),
            ],
          ),
        ),
        Text(
          '${l.rowsLabel} ${count == 0 ? 0 : first + 1}–${first + count} · ${l.retainedData}',
        ),
        if (h.result.limited || !h.result.complete)
          Text(l.partialRetainedScope),
        Expanded(
          child: text != null
              ? PagedSelectableText(controls: h.controls, text: text)
              : FutureBuilder<String>(
                  future: sql,
                  builder: (context, snapshot) => PagedSelectableText(
                    controls: h.controls,
                    text: snapshot.hasError
                        ? l.sqlCopyRequiresMetadata
                        : snapshot.data ?? l.loading,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ResultTree extends StatefulWidget {
  const _ResultTree({required this.host});
  final ResultPresentationHost host;
  @override
  State<_ResultTree> createState() => _ResultTreeState();
}

class _ResultTreeState extends State<_ResultTree> {
  final parsed = <String, StructuredJson>{};
  @override
  Widget build(BuildContext context) {
    final h = widget.host,
        l = strings(context),
        entries = <Widget Function()>[];
    final end = math.min(
      h.windowStart + h.windowRows,
      h.result.fetchedRows.toInt(),
    );
    var exhausted = false;
    void toggle(String key) => setState(() {
      if (!h.state.expanded.remove(key)) {
        if (h.state.expanded.length >= 512) {
          h.state.expanded.remove(h.state.expanded.first);
        }
        h.state.expanded.add(key);
      }
    });
    void addJson(
      StructuredJson data,
      JsonValueNode node,
      String name,
      String key,
      int depth,
    ) {
      if (entries.length >= 4096) {
        exhausted = true;
        return;
      }
      entries.add(
        () => Padding(
          padding: EdgeInsetsDirectional.only(start: depth * 16.0),
          child: h.controls.textButton(
            node.branch
                ? '${h.state.expanded.contains(key) ? '▾' : '▸'} $name'
                : '$name: ${data.raw(node)}',
            node.branch ? () => toggle(key) : null,
          ),
        ),
      );
      if (node.branch && h.state.expanded.contains(key)) {
        for (var i = 0; i < node.children.length; i++) {
          final child = node.children[i];
          addJson(data, child.node, child.name, '$key/$i', depth + 1);
          if (exhausted) break;
        }
      }
    }

    void addArray(rpc.Value value, String name, String key, int depth) {
      if (entries.length >= 4096 || depth > 32) {
        exhausted = true;
        return;
      }
      entries.add(
        () => Padding(
          padding: EdgeInsetsDirectional.only(start: depth * 16.0),
          child: h.controls.textButton(
            value.hasArray()
                ? '${h.state.expanded.contains(key) ? '▾' : '▸'} $name'
                : '$name: ${valueText(value)}',
            value.hasArray() ? () => toggle(key) : null,
          ),
        ),
      );
      if (value.hasArray() && h.state.expanded.contains(key)) {
        for (var i = 0; i < value.array.values.length; i++) {
          addArray(value.array.values[i], '$i', '$key/$i', depth + 1);
          if (exhausted) break;
        }
      }
    }

    for (var row = h.windowStart; row < end && !exhausted; row++) {
      final key = 'r:$row';
      entries.add(
        () => h.controls.textButton(
          '${h.state.expanded.contains(key) ? '▾' : '▸'} ${l.row} ${row + 1}',
          () => toggle(key),
        ),
      );
      if (!h.state.expanded.contains(key)) continue;
      for (final column in h.columns) {
        if (entries.length >= 4096) {
          exhausted = true;
          break;
        }
        final value = h.valueAt(row, column), fieldKey = '$key:$column';
        final name = h.result.columns[column].name;
        final structured =
            value?.hasArray() == true || value?.hasJson() == true;
        entries.add(
          () => Padding(
            padding: const EdgeInsetsDirectional.only(start: 16),
            child: Row(
              children: [
                if (structured)
                  h.controls.iconButton(
                    h.state.expanded.contains(fieldKey)
                        ? DesktopIcon.collapse
                        : DesktopIcon.expand,
                    name,
                    () => toggle(fieldKey),
                  ),
                Expanded(
                  child: h.controls.textButton(
                    '$name: ${h.shown(context, row, column)}',
                    () => h.select(row, column),
                  ),
                ),
                h.controls.textButton(
                  l.inspectValue,
                  value == null ? null : () => h.inspect(row, column),
                ),
              ],
            ),
          ),
        );
        if (!h.state.expanded.contains(fieldKey) || value == null) continue;
        if (value.hasArray()) {
          for (var i = 0; i < value.array.values.length; i++) {
            addArray(value.array.values[i], '$i', '$fieldKey/$i', 2);
            if (exhausted) break;
          }
        } else if (value.hasJson() && !value.truncated) {
          try {
            var data = parsed[fieldKey];
            if (data == null || data.source != value.json) {
              if (value.json.length +
                      parsed.values.fold<int>(
                        0,
                        (n, p) => n + p.source.length,
                      ) >
                  262144) {
                parsed.clear();
              }
              data = parsed[fieldKey] = StructuredJson.parse(value.json);
            }
            for (var i = 0; i < data.root.children.length; i++) {
              final child = data.root.children[i];
              addJson(data, child.node, child.name, '$fieldKey/$i', 2);
              if (exhausted) break;
            }
          } on FormatException {
            entries.add(
              () => Padding(
                padding: const EdgeInsetsDirectional.only(start: 32),
                child: Text(l.structuredParseError),
              ),
            );
          }
        } else if (value.truncated) {
          entries.add(() => Text(l.valueTruncated));
        }
      }
    }
    return Column(
      children: [
        Text(
          '${l.retainedWindowScope} · ${l.rowsLabel} ${h.windowStart + 1}–$end',
        ),
        if (exhausted) Text(l.structuredValueLimit),
        Expanded(
          child: ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) => entries[index](),
          ),
        ),
      ],
    );
  }
}
