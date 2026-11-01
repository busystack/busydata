import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/results/value_assignments.dart';
import '../../features/results/value_document.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'bounded_text_controller.dart';
import 'result_extractors.dart';
import 'workbench_presentation.dart';

class StagedInsertEditor extends StatefulWidget {
  const StagedInsertEditor({
    super.key,
    required this.model,
    required this.controls,
    required this.batch,
    required this.index,
    required this.columns,
    required this.editableOrdinals,
    required this.validateOwner,
  });
  final WorkbenchModel model;
  final DesktopControls controls;
  final OwnedEditBatch batch;
  final int index;
  final List<rpc.Column> columns;
  final List<int> editableOrdinals;
  final VoidCallback validateOwner;
  @override
  State<StagedInsertEditor> createState() => _StagedInsertEditorState();
}

class _StagedInsertEditorState extends State<StagedInsertEditor> {
  late int revision = widget.batch.revision;
  late final original = widget.batch.changes[widget.index].deepCopy();
  final controllers = <int, TextEditingController>{};
  late final assignments = <int, String>{
    for (final column in widget.columns)
      column.ordinal: _state(original.values[column.ordinal]),
  };
  bool saving = false;
  String? error;
  static String _state(rpc.ValueAssignment? value) => value == null
      ? 'unset'
      : switch (value.whichAssignment()) {
          rpc.ValueAssignment_Assignment.value => 'value',
          rpc.ValueAssignment_Assignment.nullValue => 'null',
          rpc.ValueAssignment_Assignment.defaultValue => 'default',
          _ => 'unset',
        };
  TextEditingController controller(int ordinal) => controllers.putIfAbsent(
    ordinal,
    () => BoundedTextController(
      maxUnits: 262144,
      rejected: () {
        if (mounted) setState(() => error = strings(context).valueDraftLimit);
      },
      text: assignmentValue(original.values[ordinal]) == null
          ? ''
          : valueText(assignmentValue(original.values[ordinal])!),
    ),
  );
  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> stage() async {
    final l = strings(context);
    setState(() {
      saving = true;
      error = null;
    });
    try {
      widget.validateOwner();
      final proposed = original.deepCopy()..values.clear();
      for (final column in widget.columns) {
        if (!widget.editableOrdinals.contains(column.ordinal)) continue;
        final state = assignments[column.ordinal];
        if (state == 'null') {
          proposed.values[column.ordinal] = assignmentNull();
        } else if (state == 'default') {
          proposed.values[column.ordinal] = assignmentDefault();
        } else if (state == 'value') {
          final retained = assignmentValue(original.values[column.ordinal]);
          final text = controller(column.ordinal).text;
          if (text.length > 262144) throw StateError(l.valueDraftLimit);
          proposed.values[column.ordinal] =
              retained != null && text == valueText(retained)
              ? assignmentOf(retained)
              : assignmentOf(
                  editedValue(
                    retained ?? rpc.Value(text: ''),
                    text,
                    retained?.hasBinary() == true
                        ? ValuePresentation.hexadecimal
                        : ValuePresentation.raw,
                  ),
                );
        }
      }
      widget.model.replaceStagedInsert(
        widget.batch,
        widget.index,
        proposed,
        revision,
      );
      final persisted = widget.model.persistStagedEdits(batch: widget.batch);
      revision = widget.batch.revision;
      await persisted;
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = l.valueDraftPreserved;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context), ui = widget.controls;
    return WorkbenchDialogBody(
      maxHeight: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ui.status(error!, error: true),
          Expanded(
            child: ListView.builder(
              itemCount: widget.columns.length,
              itemBuilder: (context, index) {
                final column = widget.columns[index],
                    editable = widget.editableOrdinals.contains(column.ordinal);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ui.field(
                      controller(column.ordinal),
                      '${column.name} · ${column.typeName}',
                      enabled:
                          editable &&
                          !saving &&
                          assignments[column.ordinal] == 'value',
                    ),
                    if (!editable)
                      Text(l.readonlyCell)
                    else
                      ui.choice(
                        assignments[column.ordinal]!,
                        {
                          'unset': l.assignmentUnset,
                          'value': l.assignmentValue,
                          'null': l.assignmentNull,
                          'default': l.assignmentDefault,
                        },
                        (value) =>
                            setState(() => assignments[column.ordinal] = value),
                        enabled: !saving,
                      ),
                  ],
                );
              },
            ),
          ),
          ui.button(l.stageChange, saving ? null : stage, primary: true),
        ],
      ),
    );
  }
}
