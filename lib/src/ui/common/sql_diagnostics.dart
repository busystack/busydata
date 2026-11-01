import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/workspace/documents.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'workbench_presentation.dart';

/// Presentation of stable diagnostic codes; remote prose is never a UI message.
String sqlInspectionLabel(BuildContext context, String code) {
  final l = strings(context);
  return switch (code) {
    'inspection.unrestricted-update' => l.sqlInspectionUpdateWhere,
    'inspection.unrestricted-delete' => l.sqlInspectionDeleteWhere,
    'binding.unresolved-relation' => l.sqlInspectionRelation,
    'binding.unresolved-column' => l.sqlInspectionColumn,
    'binding.ambiguous-column' => l.sqlInspectionAmbiguous,
    'binding.invalid-derived-reference' => l.sqlInspectionDerived,
    'binding.duplicate-alias' => l.sqlInspectionDuplicateAlias,
    'binding.duplicate-cte' => l.sqlInspectionDuplicateCte,
    'binding.duplicate-insert-column' => l.sqlInspectionDuplicateInsert,
    'binding.unknown-target-column' => l.sqlInspectionInsertTarget,
    'binding.unknown-update-column' => l.sqlInspectionUpdateTarget,
    'binding.duplicate-using-column' => l.sqlInspectionDuplicateUsingColumn,
    'binding.unresolved-using-column' => l.sqlInspectionUnresolvedUsingColumn,
    'binding.ambiguous-using-column' => l.sqlInspectionAmbiguousUsingColumn,
    'binding.output-column-count' => l.sqlInspectionOutputColumnCount,
    'routine.argument-count' => l.sqlInspectionArguments,
    'routine.no-matching-overload' => l.sqlInspectionOverload,
    'routine.ambiguous-overload' => l.sqlInspectionAmbiguousOverload,
    'routine.unknown-function' ||
    'routine.unknown' => l.sqlInspectionUnknownFunction,
    'analysis.limit' => l.limitReached,
    'expression.invalid-aggregate' => l.sqlInspectionAggregate,
    'type.incompatible-comparison' => l.sqlInspectionComparison,
    'type.incompatible-assignment' => l.sqlInspectionAssignment,
    'type.invalid-boolean' => l.sqlInspectionBooleanType,
    'type.incompatible-operator' => l.sqlInspectionOperatorTypes,
    'type.incompatible-array' => l.sqlInspectionArrayTypes,
    'type.invalid-case-condition' => l.sqlInspectionCaseConditionType,
    'type.incompatible-case' => l.sqlInspectionCaseResultTypes,
    'type.incompatible-coalesce' => l.sqlInspectionCoalesceTypes,
    'type.set-column-count' => l.sqlInspectionSetColumnCount,
    'type.incompatible-set' => l.sqlInspectionSetTypes,
    'type.recursive-cte-mismatch' => l.sqlInspectionRecursiveCteType,
    'metadata.incomplete' => l.sqlInspectionMetadata,
    'dialect.cte-dml' ||
    'dialect.full-join' ||
    'dialect.lateral' ||
    'dialect.returning' => l.sqlInspectionDialect,
    'syntax.expected-expression' ||
    'syntax.expected-alias' ||
    'syntax.expected-insert-source' ||
    'syntax.expected-projection' ||
    'syntax.expected-relation' ||
    'syntax.expected-set' ||
    'syntax.expected-using-columns' ||
    'syntax.using-column' ||
    'syntax.incomplete-token' ||
    'syntax.missing-close' ||
    'syntax.unexpected-close' => l.sqlInspectionSyntax,
    _ => l.sqlInspectionUnavailable,
  };
}

/// One accepted response is the authority for every index, span and correction.
/// This object never owns an execution request or performs database work.
class SqlDiagnosticActions {
  SqlDiagnosticActions(this.model, this.accepted);
  bool limited = false;
  final WorkbenchModel model;
  final AcceptedAnalysis accepted;
  bool get current =>
      accepted.result.diagnostics.length <= 64 &&
      identical(model.acceptedDiagnostics, accepted) &&
      accepted.result.operation == rpc.AnalysisOperation.DIAGNOSTICS &&
      model.analysisResultMatches(accepted);
  bool validSpan(int start, int end) =>
      start >= 0 &&
      end >= start &&
      end <= accepted.binding.text.length &&
      _editorBoundary(start) &&
      _editorBoundary(end);
  bool _editorBoundary(int offset) {
    final text = accepted.binding.text;
    return utf16Boundary(text, offset) &&
        !(offset > 0 &&
            offset < text.length &&
            text.codeUnitAt(offset - 1) == 13 &&
            text.codeUnitAt(offset) == 10);
  }

  rpc.Diagnostic? diagnostic(int index) =>
      index >= 0 && index < accepted.result.diagnostics.length && index < 64
      ? accepted.result.diagnostics[index]
      : null;
  bool canSelect(int index) {
    final item = diagnostic(index);
    return current && item != null && validSpan(item.startUtf16, item.endUtf16);
  }

  bool select(int index) {
    if (!canSelect(index)) return false;
    final item = diagnostic(index)!;
    accepted.binding.document.selectOffsets(item.startUtf16, item.endUtf16);
    return true;
  }

  rpc.QuickFix? fix(int index, int fixIndex) {
    final item = diagnostic(index);
    if (item == null ||
        item.incomplete ||
        item.fixes.length > 64 ||
        fixIndex < 0 ||
        fixIndex >= item.fixes.length) {
      return null;
    }
    return item.fixes[fixIndex];
  }

  bool canApply(int index, int fixIndex) {
    final correction = fix(index, fixIndex);
    if (!current ||
        correction == null ||
        accepted.binding.document.editor.isComposing ||
        correction.replacement.length > 8192 ||
        !validSpan(correction.startUtf16, correction.endUtf16)) {
      return false;
    }
    try {
      validateSqlUnicode(correction.replacement, maxUtf8Bytes: 32768);
      return true;
    } on FormatException {
      return false;
    }
  }

  bool apply(int index, int fixIndex) {
    if (!canApply(index, fixIndex)) return false;
    final correction = fix(index, fixIndex)!;
    final start = correction.startUtf16, end = correction.endUtf16;
    final next = accepted.binding.text.replaceRange(
      start,
      end,
      correction.replacement,
    );
    final delta = correction.replacement.length - (end - start);
    limited = false;
    try {
      return accepted.binding.document.replaceWithMappedPositions(next, (
        offset,
      ) {
        if (offset <= start) return offset;
        if (offset >= end) return offset + delta;
        return start + correction.replacement.length;
      });
    } on DocumentResourceLimit {
      limited = true;
      return false;
    }
  }
}

Future<void> showSqlDiagnostics(
  BuildContext context,
  DesktopControls controls,
  WorkbenchModel model,
  SqlDocument document,
) async {
  final l = strings(context), binding = model.analysisBinding(document);
  var accepted = model.acceptedDiagnostics;
  if (accepted == null ||
      accepted.result.operation != rpc.AnalysisOperation.DIAGNOSTICS ||
      !identical(accepted.binding.document, document) ||
      !model.analysisResultMatches(accepted)) {
    await model.analyze(document, operation: rpc.AnalysisOperation.DIAGNOSTICS);
    accepted = model.acceptedDiagnostics;
  }
  if (!context.mounted) return;
  if (!model.analysisMatches(binding)) {
    model.updateStatus(l.sqlDiagnosticStale);
    return;
  }
  if (accepted == null ||
      accepted.result.operation != rpc.AnalysisOperation.DIAGNOSTICS ||
      !identical(accepted.binding.document, document) ||
      !model.analysisResultMatches(accepted)) {
    model.updateStatus(l.sqlDiagnosticUnavailable);
    return;
  }
  final changed = await controls.dialog<bool>(
    context,
    l.sqlInspections,
    SqlDiagnostics(model: model, controls: controls, accepted: accepted),
    [controls.button(l.close, () => Navigator.of(context).pop(false))],
    bodyScrolls: true,
  );
  if (changed == true && identical(model.activeOwner.sql, document)) {
    model.documentFocus.requestFocus();
  }
}

class SqlDiagnostics extends StatefulWidget {
  const SqlDiagnostics({
    super.key,
    required this.model,
    required this.controls,
    required this.accepted,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final AcceptedAnalysis accepted;
  @override
  State<SqlDiagnostics> createState() => _SqlDiagnosticsState();
}

class _SqlDiagnosticsState extends State<SqlDiagnostics> {
  int selected = 0;
  late final actions = SqlDiagnosticActions(widget.model, widget.accepted);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final ui = widget.controls, l = strings(context);
      final items = widget.accepted.result.diagnostics;
      final selectedIndex = selected;
      final item = actions.diagnostic(selectedIndex);
      final availability = switch (widget.accepted.result.availability) {
        'available' => l.available,
        'incomplete-metadata' => l.columnMetadataUnavailable,
        'limited' => l.partial,
        'cancelled' => l.cancelled,
        _ => l.unavailable,
      };
      String severity(String value) => switch (value) {
        'error' => l.sqlSeverityError,
        'warning' => l.sqlSeverityWarning,
        'information' => l.sqlSeverityInformation,
        'hint' => l.sqlSeverityHint,
        _ => l.unknownState,
      };
      void completed(bool success) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          widget.model.updateStatus(
            actions.limited ? l.limitReached : l.sqlDiagnosticStale,
          );
        }
      }

      return WorkbenchDialogBody(
        maxHeight: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${l.sqlDiagnosticCount(items.length)} · $availability'),
            if (!actions.current) ui.status(l.sqlDiagnosticStale, error: true),
            if (items.length > 64)
              ui.status(l.limitReached, error: true)
            else if (items.isEmpty)
              ui.status(l.sqlDiagnosticsEmpty)
            else ...[
              Expanded(
                flex: 2,
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => KeyedSubtree(
                    key: ValueKey('sql-diagnostic-$index'),
                    child: ui.section(
                      '${index + 1} · ${severity(items[index].severity)} · ${sqlInspectionLabel(context, items[index].code)}',
                      index == selected,
                      () => setState(() => selected = index),
                    ),
                  ),
                ),
              ),
              if (item != null)
                Expanded(
                  flex: 3,
                  child: ListView(
                    children: [
                      Text(sqlInspectionLabel(context, item.code)),
                      Text(
                        '${workbenchEngine(item.engine)} · ${item.code}',
                        style: ui.appearance(context).technical,
                      ),
                      Text(
                        l.sqlDiagnosticSpan(
                          item.startUtf16,
                          item.endUtf16,
                          item.source,
                        ),
                      ),
                      if (item.incomplete) ui.status(l.sqlInspectionMetadata),
                      if (actions.validSpan(item.startUtf16, item.endUtf16))
                        WorkbenchCodeEvidence(
                          controls: ui,
                          text: widget.accepted.binding.text.substring(
                            item.startUtf16,
                            item.endUtf16,
                          ),
                        ),
                      ui.textButton(
                        l.sqlDiagnosticGo,
                        actions.canSelect(selectedIndex)
                            ? () => completed(actions.select(selectedIndex))
                            : null,
                      ),
                      if (item.fixes.length > 64)
                        ui.status(l.limitReached, error: true)
                      else
                        for (final (index, correction) in item.fixes.indexed)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                l.sqlDiagnosticSpan(
                                  correction.startUtf16,
                                  correction.endUtf16,
                                  item.source,
                                ),
                              ),
                              Text(l.sqlDiagnosticReplacement),
                              if (correction.replacement.length <= 8192)
                                WorkbenchCodeEvidence(
                                  controls: ui,
                                  text: correction.replacement,
                                )
                              else
                                ui.status(l.limitReached, error: true),
                              KeyedSubtree(
                                key: ValueKey(
                                  'sql-diagnostic-fix-$selectedIndex-$index',
                                ),
                                child: ui.textButton(
                                  l.sqlDiagnosticFix,
                                  actions.canApply(selectedIndex, index)
                                      ? () => completed(
                                          actions.apply(selectedIndex, index),
                                        )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}
