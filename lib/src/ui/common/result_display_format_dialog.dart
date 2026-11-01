import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;
import '../../features/results/result_presentation.dart';
import '../../l10n/workbench_strings.dart';
import 'bounded_text_controller.dart';
import 'desktop_controls.dart';

typedef ResultDisplayChoice = ({
  int column,
  ColumnDisplayFormat format,
  TemporalDisplayPattern? pattern,
});

class ResultDisplayFormatDialog extends StatefulWidget {
  const ResultDisplayFormatDialog({
    super.key,
    required this.controls,
    required this.columns,
    required this.initialColumn,
    required this.formats,
    required this.patterns,
    required this.names,
  });
  final DesktopControls controls;
  final List<rpc.Column> columns;
  final int initialColumn;
  final Map<int, ColumnDisplayFormat> formats;
  final Map<int, TemporalDisplayPattern> patterns;
  final Map<ColumnDisplayFormat, String> names;
  @override
  State<ResultDisplayFormatDialog> createState() =>
      _ResultDisplayFormatDialogState();
}

class _ResultDisplayFormatDialogState extends State<ResultDisplayFormatDialog> {
  late int column = widget.initialColumn;
  late ColumnDisplayFormat format =
      widget.formats[column] ?? ColumnDisplayFormat.canonical;
  late TemporalDisplayZone zone =
      widget.patterns[column]?.zone ?? TemporalDisplayZone.source;
  late final pattern = BoundedTextController(
    text: widget.patterns[column]?.pattern ?? 'yyyy-MM-dd HH:mm:ss.SSSSSS',
    maxUnits: 128,
  );
  final focus = FocusNode(debugLabel: 'Temporal display pattern');
  String? error;
  @override
  void dispose() {
    pattern.dispose();
    focus.dispose();
    super.dispose();
  }

  void apply() {
    TemporalDisplayPattern? configured;
    if (format == ColumnDisplayFormat.temporalPattern) {
      try {
        configured = TemporalDisplayPattern(pattern.text, zone);
      } on FormatException {
        setState(() => error = strings(context).temporalPatternInvalid);
        focus.requestFocus();
        return;
      }
    }
    Navigator.of(context).pop<ResultDisplayChoice>((
      column: column,
      format: format,
      pattern: configured,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context), ui = widget.controls;
    return SingleChildScrollView(
      primary: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ui.choice(
            column,
            {
              for (var i = 0; i < widget.columns.length; i++)
                i: widget.columns[i].name,
            },
            (selected) => setState(() {
              column = selected;
              format = widget.formats[column] ?? ColumnDisplayFormat.canonical;
              pattern.text =
                  widget.patterns[column]?.pattern ??
                  'yyyy-MM-dd HH:mm:ss.SSSSSS';
              zone =
                  widget.patterns[column]?.zone ?? TemporalDisplayZone.source;
              error = null;
            }),
          ),
          ui.choice(
            format,
            widget.names,
            (selected) => setState(() => format = selected),
          ),
          if (format == ColumnDisplayFormat.temporalPattern) ...[
            ui.field(
              pattern,
              l.temporalPattern,
              focusNode: focus,
              technical: true,
            ),
            ui.choice(
              zone,
              {
                TemporalDisplayZone.source: l.temporalSourceZone,
                TemporalDisplayZone.utc: l.temporalUtc,
                TemporalDisplayZone.local: l.temporalLocal,
              },
              (selected) => setState(() => zone = selected),
              label: l.temporalZone,
            ),
            Text(l.temporalPatternHelp),
            if (error != null) ui.status(error!, error: true),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.end,
            children: [
              ui.button(l.cancel, () => Navigator.of(context).pop()),
              ui.button(l.applyView, apply),
            ],
          ),
        ],
      ),
    );
  }
}
