import 'package:yaru/yaru.dart';

import 'busydata_design.dart';

abstract final class BusyDataLayoutRules {
  static const double sidebarBreakpoint =
      kYaruMasterDetailBreakpoint + BusyDataSizes.sidebarWidth / 4;
  static const double detailsBreakpoint = kYaruMasterDetailBreakpoint * 2;
  static const double taskPageMinWidth =
      kYaruMasterDetailBreakpoint - BusyDataSizes.sidebarWidth / 2;
  static const double settingsSidebarBreakpoint =
      BusyDataSizes.sidebarWidth + 520;

  static bool showSidebar(double width) => width >= sidebarBreakpoint;

  static bool showPersistentDetails(double width) => width >= detailsBreakpoint;

  static bool showSettingsSidebar(double width) =>
      width >= settingsSidebarBreakpoint;
}
