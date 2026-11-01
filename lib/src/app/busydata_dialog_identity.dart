import 'package:flutter/material.dart';

import 'busydata_design.dart';

/// Native Yaru chrome shared by BusyData's informational dialogs.
///
/// The title bar deliberately lives outside the scroll viewport. This keeps
/// its window control fixed, fully opaque, and at Yaru's native metric while
/// the dialog content remains usable in compact windows and at large text
/// scales.
class BusyDataInformationalDialog extends StatelessWidget {
  const BusyDataInformationalDialog({
    required this.closeLabel,
    required this.maxWidth,
    required this.child,
    this.maxHeight,
    super.key,
  });

  final String closeLabel;
  final double maxWidth;
  final double? maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dialogSurface = busyDataDialogSurfaceColor(context);
    return BusyDataSurfaceScope(
      role: BusyDataSurfaceRole.dialog,
      child: Builder(
        builder: (context) {
          return Dialog(
            backgroundColor: dialogSurface,
            surfaceTintColor: dialogSurface,
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: maxHeight ?? double.infinity,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BusyDataDialogTitleBar(closeSemanticLabel: closeLabel),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(BusyDataSpacing.lg),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Shared application identity treatment for informational dialogs.
///
/// The 128-pixel visual follows libadwaita's large application-icon metric.
/// Dialogs provide their own visual while this widget keeps its geometry and
/// title hierarchy consistent.
class BusyDataDialogIdentity extends StatelessWidget {
  const BusyDataDialogIdentity({
    required this.visual,
    required this.title,
    super.key,
  });

  static const visualExtent = 128.0;
  static const titleWeight = FontWeight.bold;

  final Widget visual;
  final String title;

  @override
  Widget build(BuildContext context) {
    final titleStyle =
        Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: titleWeight) ??
        const TextStyle(fontWeight: titleWeight);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BusyDataSpacing.md),
            child: SizedBox.square(dimension: visualExtent, child: visual),
          ),
        ),
        const SizedBox(height: BusyDataSpacing.md),
        Text(title, textAlign: TextAlign.center, style: titleStyle),
      ],
    );
  }
}
