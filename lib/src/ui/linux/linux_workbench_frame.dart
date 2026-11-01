import 'package:flutter/material.dart';
import '../../app/busydata_design.dart';
import '../../app/busydata_motion_widgets.dart';
import '../../app/linux/linux_header_style.dart';
import '../../app/linux/linux_page_frame.dart';
import '../../platform/gtk_header_icon_service.dart';
import '../../l10n/workbench_strings.dart';
import '../common/desktop_controls.dart';

/// BusyMark's Flutter-owned header/sidebar composition, with BusyData commands.
/// The editor stays in the same body slot through header and sidebar changes.
class LinuxWorkbenchFrame extends StatelessWidget {
  const LinuxWorkbenchFrame({
    super.key,
    required this.body,
    required this.sidebar,
    required this.sidebarVisible,
    required this.sidebarGeneration,
    required this.sidebarWidth,
    required this.resizeSidebar,
    required this.toggleSidebar,
    required this.title,
    required this.menus,
    required this.search,
    required this.prepareSearch,
    required this.menuEntry,
    this.searchShortcut,
    this.sidebarShortcut,
    this.sidebarAvailable = true,
    this.sidebarResizable = true,
    this.showSearch = true,
    this.searchField,
    this.searchSidebar,
    this.contextualControls,
    this.back,
  });
  final Widget body, sidebar;
  final bool sidebarVisible;
  final bool sidebarAvailable, sidebarResizable, showSearch;
  final int sidebarGeneration;
  final double sidebarWidth;
  final ValueChanged<double> resizeSidebar;
  final VoidCallback toggleSidebar, search, prepareSearch;
  final BusyDataMenuEntry<DesktopMenuAction> Function(DesktopMenuAction)
  menuEntry;
  final String title;
  final String? searchShortcut, sidebarShortcut;
  final List<DesktopMenu> menus;
  final Widget? searchField, searchSidebar, contextualControls;
  final VoidCallback? back;

  @override
  Widget build(BuildContext context) {
    final l = strings(context);
    String hint(String label, String? shortcut) =>
        shortcut == null || shortcut.isEmpty ? label : '$label · $shortcut';
    return LayoutBuilder(
      builder: (context, bounds) {
        final canShowSidebar =
            sidebarAvailable &&
            bounds.maxWidth >= BusyDataSizes.sidebarWidth + 480;
        return LinuxPageFrame(
          sidebarAvailable: canShowSidebar || searchSidebar != null,
          sidebarOverlay: !canShowSidebar && searchSidebar != null,
          sidebarExpanded: sidebarVisible || searchSidebar != null,
          sidebarTransitionGeneration: sidebarGeneration,
          sidebarWidth: searchSidebar == null
              ? sidebarWidth
              : BusyDataSizes.sidebarWidth.clamp(0.0, bounds.maxWidth),
          onSidebarResize: sidebarResizable ? resizeSidebar : null,
          sidebarHeader: const BusyDataLinuxBrandHeader(),
          sidebarBody: BusyDataSidebarSurface(
            showEndBorder: false,
            child: IndexedStack(
              index: searchSidebar == null ? 0 : 1,
              children: [
                ExcludeFocus(excluding: searchSidebar != null, child: sidebar),
                searchSidebar ?? const SizedBox.shrink(),
              ],
            ),
          ),
          header: BusyDataLinuxHeaderLayout(
            centerAllocation: searchField == null
                ? BusyDataLinuxHeaderCenterAllocation.centered
                : BusyDataLinuxHeaderCenterAllocation.fillBetweenControls,
            leading: BusyDataLinuxHeaderControlGroup(
              children: [
                if (sidebarResizable)
                  BusyDataLinuxHeaderIconButton(
                    icon: BusyDataLinuxHeaderIcon.sidebar,
                    tooltip: hint(l.sidebar, sidebarShortcut),
                    semanticLabel: l.sidebar,
                    selected:
                        (sidebarVisible || searchSidebar != null) &&
                        canShowSidebar,
                    onPressed: canShowSidebar && searchSidebar == null
                        ? toggleSidebar
                        : null,
                  ),
                if (back != null && (searchField == null || !sidebarResizable))
                  BusyDataLinuxHeaderIconButton(
                    icon: BusyDataLinuxHeaderIcon.back,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: back,
                  ),
              ],
            ),
            title: _RetainedHeaderTitle(title: title, field: searchField),
            trailing: BusyDataLinuxHeaderControlGroup(
              children: [
                if (searchField == null && contextualControls != null)
                  contextualControls!,
                if (showSearch)
                  Listener(
                    onPointerDown: (_) => prepareSearch(),
                    child: BusyDataLinuxHeaderIconButton(
                      icon: BusyDataLinuxHeaderIcon.search,
                      tooltip: hint(l.search, searchShortcut),
                      semanticLabel: l.search,
                      selected: searchField != null,
                      onPressed: search,
                    ),
                  ),
                LinuxWorkbenchMainMenu(menus: menus, menuEntry: menuEntry),
              ],
            ),
          ),
          body: body,
        );
      },
    );
  }
}

/// One main-menu renderer also satisfies the generic desktop menu adapter.
class LinuxWorkbenchMainMenu extends StatelessWidget {
  const LinuxWorkbenchMainMenu({
    super.key,
    required this.menus,
    required this.menuEntry,
  });
  final List<DesktopMenu> menus;
  final BusyDataMenuEntry<DesktopMenuAction> Function(DesktopMenuAction)
  menuEntry;
  BusyDataMenuEntry<DesktopMenuAction> destination(DesktopMenu menu) =>
      BusyDataMenuEntry(
        value: DesktopMenuAction(menu.label, () {}),
        label: menu.label,
        children: [
          for (final action in menu.actions) menuEntry(action),
          for (final child in menu.children) destination(child),
        ],
      );
  @override
  Widget build(BuildContext context) => BusyDataMenuButton<DesktopMenuAction>(
    key: const ValueKey('workbench-main-menu'),
    tooltip: strings(context).mainMenu,
    entries: [
      for (final menu in menus.where(
        (menu) => menu.actions.isNotEmpty || menu.children.isNotEmpty,
      ))
        if (menu.label.isEmpty) ...[
          for (final action in menu.actions) menuEntry(action),
        ] else
          destination(menu),
    ],
    triggerBuilder: (context, trigger) => trigger.anchor(
      child: BusyDataHeaderIconButton(
        icon: const BusyDataGtkHeaderIcon(BusyDataLinuxHeaderIcon.mainMenu),
        tooltip: strings(context).mainMenu,
        focusNode: trigger.focusNode,
        onPressed: trigger.onPressed,
        isSelected: trigger.isOpen,
      ),
    ),
    onSelected: (action) => action.invoke(),
  );
}

// Keep the search entry mounted through title transitions, including its IME
// and text-selection state. Only the active page participates in focus/input.
class _RetainedHeaderTitle extends StatefulWidget {
  const _RetainedHeaderTitle({required this.title, required this.field});
  final String title;
  final Widget? field;
  @override
  State<_RetainedHeaderTitle> createState() => _RetainedHeaderTitleState();
}

class _RetainedHeaderTitleState extends State<_RetainedHeaderTitle> {
  Widget? _field;
  @override
  Widget build(BuildContext context) {
    _field = widget.field ?? _field;
    return BusyDataRetainedCrossfade(
      index: widget.field == null ? 0 : 1,
      children: [
        BusyDataLinuxHeaderTitle(widget.title),
        _field ?? const SizedBox.shrink(),
      ],
    );
  }
}
