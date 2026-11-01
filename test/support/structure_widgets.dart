import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/structure_presentation.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:flutter/widgets.dart';

/// The production inspector and its relocated contextual controls.
class StructureInspection extends StatelessWidget {
  const StructureInspection({
    super.key,
    required this.model,
    required this.owner,
    required this.controls,
  });
  final WorkbenchModel model;
  final WorkbenchDocument owner;
  final DesktopControls controls;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (_, _) => Column(
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 280,
            child: StructureControls(
              model: model,
              owner: owner,
              controls: controls,
            ),
          ),
        ),
        Expanded(
          child: ObjectDocumentView(
            model: model,
            owner: owner,
            controls: controls,
          ),
        ),
      ],
    ),
  );
}
