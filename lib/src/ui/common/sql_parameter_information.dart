import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import '../../features/workspace/documents.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';

/// Independent parameter requests never replace completion or move editor focus.
class SqlParameterInformation extends StatelessWidget {
  const SqlParameterInformation({
    super.key,
    required this.model,
    required this.document,
    required this.controls,
  });
  final WorkbenchModel model;
  final SqlDocument document;
  final DesktopControls controls;
  @override
  Widget build(BuildContext context) {
    final accepted = model.acceptedParameterInformation;
    if (accepted == null ||
        !identical(accepted.binding.document, document) ||
        !model.analysisResultMatches(accepted)) {
      return const SizedBox.shrink();
    }
    final information = accepted.result.parameterInformation;
    if (information.overloads.isEmpty) return const SizedBox.shrink();
    final look = controls.appearance(context), l = strings(context);
    final notice = switch (information.availability) {
      'available' => null,
      'limited' => l.parameterInformationLimited,
      'partial-signatures' ||
      'incomplete-metadata' => '${l.parameterInformation} · ${l.partial}',
      _ => '${l.parameterInformation} · ${l.unavailable}',
    };
    final headerRows = notice == null ? 1 : 2;
    final height =
        look.rowHeight(context) *
        math.min(3, information.overloads.length + headerRows);
    return Semantics(
      container: true,
      label: l.parameterInformation,
      child: controls.completionSurface(
        SizedBox(
          height: height,
          child: ListView.builder(
            primary: false,
            itemCount: information.overloads.length + headerRows,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
              child: Text(
                index == 0
                    ? l.activeArgument(information.activeArgument + 1)
                    : notice != null && index == 1
                    ? notice
                    : information.overloads[index - headerRows].signature,
                style: index < headerRows ? look.body : look.technical,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
