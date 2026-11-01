import 'package:flutter/widgets.dart';

abstract final class BusyDataDimensions {
  static const double minimumWindowWidth = 900;
  static const double minimumWindowHeight = 600;
  static const double initialWindowWidth = 1280;
  static const double initialWindowHeight = 800;
  static const double navigationCompactWidth = 48;
  static const double navigationOpenWidth = 240;
  static const double sourcePaneWidth = 264;
  static const double editorWidth = 440;
  static const double contentMaximumWidth = 1120;
}

abstract final class BusyDataBreakpoints {
  static const double compact = 720;
  static const double sourcePane = 980;
  static const double wide = 1280;

  static bool showsSourcePane(double width) => width >= sourcePane;
}

abstract final class BusyDataMotion {
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 167);
  static const Duration slow = Duration(milliseconds: 250);

  static const Duration dialogInsets = Duration(milliseconds: 160);
  static const Curve dialogInsetsCurve = Curves.easeOutCubic;

  /// Behavioral delay; unlike presentation durations this is never disabled.
  static const Duration tooltipWait = Duration(milliseconds: 500);

  static const Duration sidebar = Duration(milliseconds: 200);
  static const Duration search = Duration(milliseconds: 160);
  static const Duration workspaceTransition = Duration(milliseconds: 200);
  static const Duration crossfade = Duration(milliseconds: 140);
  static const Curve presentationCurve = Curves.easeOutCubic;
}

@immutable
final class BusyDataPaneState {
  const BusyDataPaneState({
    required this.availableWidth,
    required this.sourcePaneRequested,
  });

  final double availableWidth;
  final bool sourcePaneRequested;

  bool get showsSourcePane =>
      sourcePaneRequested &&
      BusyDataBreakpoints.showsSourcePane(availableWidth);
}
