import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:yaru/yaru.dart';
import '../../app/busydata_design.dart';
import '../../app/busydata_motion_widgets.dart';
import '../../app/busydata_dialogs.dart';
import '../../app/busydata_surface_colors.dart';
import '../common/desktop_controls.dart';
import '../common/modal_command_boundary.dart';
import '../common/presentation_diagnostics.dart';
import '../common/workbench_presentation.dart';
import 'linux_appearance.dart';
import 'linux_database_icon.dart';
import 'linux_workbench_frame.dart';

class LinuxControls extends DesktopControls {
  const LinuxControls();
  @override
  DesktopMenuPresenter createMenuPresenter() => _LinuxMenuPresenter(this);
  @override
  Widget sidebarNavigation(List<Widget> children) =>
      BusyDataSidebarNavigation(children: children);
  @override
  Widget sidebarNavigationTile({
    required bool selected,
    required Widget leading,
    required String title,
    required VoidCallback onPressed,
  }) => BusyDataSidebarNavigationTile(
    selected: selected,
    leading: leading,
    title: Text(title),
    onTap: onPressed,
  );
  @override
  Widget completionSurface(Widget child) => Builder(
    builder: (context) => Material(
      key: const ValueKey('sql-completion-popup'),
      color: BusyDataSurfaceColors.of(context).popover,
      elevation: BusyDataElevation.surface,
      borderRadius: BorderRadius.circular(BusyDataRadius.headerButton),
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );

  @override
  bool get hasWindowHeader => true;
  @override
  double get defaultSidebarWidth => BusyDataSizes.sidebarWidth;
  @override
  double get formContentWidth => BusyDataSizes.contentWidth;
  @override
  double get settingsSidebarBreakpoint =>
      BusyDataSizes.settingsSidebarBreakpoint;
  @override
  EdgeInsetsGeometry get settingsPagePadding => BusyDataInsets.settingsPage;
  @override
  EdgeInsetsGeometry get sidebarListPadding => BusyDataInsets.sidebarList;
  @override
  Widget settingsTransition(Object category, Widget child) =>
      BusyDataKeyedCrossfade(transitionKey: category, child: child);
  @override
  Widget recordContent(Widget child, {DesktopIcon? leading}) => ConstrainedBox(
    constraints: const BoxConstraints(
      minHeight: BusyDataSizes.sidebarRowHeight,
    ),
    child: Row(
      children: [
        const SizedBox(width: BusyDataSpacing.sm),
        if (leading != null) ...[
          icon(leading, size: BusyDataSizes.iconSm),
          const SizedBox(width: BusyDataSpacing.sm),
        ],
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: BusyDataSpacing.xs),
            child: child,
          ),
        ),
        const SizedBox(width: BusyDataSpacing.sm),
      ],
    ),
  );
  @override
  Widget preferenceRow<T>(
    String title,
    DesktopIcon leading,
    T value,
    Map<T, String> values,
    ValueChanged<T> changed, {
    bool enabled = true,
  }) => LayoutBuilder(
    builder: (context, bounds) {
      final selector = BusyDataPopupSelector<T>(
        value: value,
        label: values[value] ?? title,
        tooltip: title,
        options: [
          for (final entry in values.entries)
            BusyDataPopupSelectorOption(value: entry.key, label: entry.value),
        ],
        onSelected: changed,
        enabled: enabled,
      );
      if (bounds.maxWidth < BusyDataSizes.settingsControlBreakpoint) {
        return Padding(
          padding: const EdgeInsets.all(BusyDataSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  icon(leading, size: BusyDataSizes.iconMd),
                  const SizedBox(width: BusyDataSpacing.md),
                  Expanded(child: Text(title)),
                ],
              ),
              const SizedBox(height: BusyDataSpacing.sm),
              selector,
            ],
          ),
        );
      }
      return BusyDataActionRow(
        title: title,
        leading: icon(leading, size: BusyDataSizes.iconMd),
        trailing: SizedBox(
          width: BusyDataSizes.selectorButtonMaxWidth,
          child: selector,
        ),
      );
    },
  );
  @override
  double get treeMenuWidth => BusyDataSizes.headerIconButton;
  @override
  Widget tabLeading(DesktopIcon iconValue, bool dirty) => dirty
      ? Builder(
          builder: (context) => Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        )
      : icon(iconValue);
  @override
  Widget completionRow({
    required Widget child,
    required bool selected,
    required VoidCallback onPressed,
  }) => Builder(
    builder: (context) => Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        canRequestFocus: false,
        onTap: onPressed,
        child: ColoredBox(
          color: selected
              ? BusyDataSurfaceColors.of(context).controlActive
              : Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: child,
          ),
        ),
      ),
    ),
  );
  @override
  Widget shortcutBadge(String label) => BusyDataKeyboardShortcutBadge(label);
  @override
  Widget contentClamp(
    Widget child, {
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => BusyDataClamp(margin: EdgeInsets.zero, padding: padding, child: child);
  @override
  Widget strip(
    Widget child, {
    double minimumHeight = 38,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8),
    bool topBorder = false,
  }) => BusyDataToolbar(
    minimumHeight: minimumHeight,
    padding: padding,
    topBorder: topBorder,
    child: child,
  );
  @override
  Widget rowSurface({
    required Widget child,
    required bool selected,
    required bool focused,
    bool hovered = false,
    bool? focusVisible,
    Color? base,
  }) => BusyDataSidebarRowSurface(
    selected: selected,
    focused: focused,
    focusVisible: focusVisible,
    hovered: hovered,
    base: base,
    child: child,
  );
  @override
  Widget modeSwitcher<T>(
    T value,
    Map<T, String> values,
    ValueChanged<T> changed, {
    String? label,
  }) => LayoutBuilder(
    builder: (context, bounds) => SizedBox(
      width: choiceWidth(context, values[value]!)
          .clamp(0.0, BusyDataSizes.selectorButtonMaxWidth)
          .clamp(0.0, bounds.maxWidth)
          .toDouble(),
      child: BusyDataModeSwitcher<T>(
        values: values.keys.toList(),
        selected: value,
        labelFor: (value) => values[value]!,
        onSelected: changed,
        tooltip: label,
      ),
    ),
  );
  @override
  Widget treeExpander(bool expanded, String label, VoidCallback toggle) =>
      BusyDataSidebarTreeControl(
        expanded: expanded,
        label: label,
        onToggle: toggle,
      );
  @override
  Widget headerModeSwitcher<T>(
    T value,
    Map<T, DesktopMenuAction> modes,
    String label,
  ) => BusyDataMenuButton<T>(
    tooltip: label,
    entries: [
      for (final entry in modes.entries)
        BusyDataMenuEntry(
          value: entry.key,
          label: entry.value.label,
          shortcut: entry.value.shortcut,
          role: BusyDataMenuEntryRole.radio,
          selected: entry.key == value,
          enabled: entry.value.disabledReason == null,
          tooltip: entry.value.disabledReason,
          nativeIconName: entry.value.icon == DesktopIcon.table
              ? 'view-grid-symbolic'
              : 'folder-symbolic',
        ),
    ],
    onSelected: (value) => modes[value]!.invoke(),
    triggerBuilder: (_, trigger) => trigger.anchor(
      child: BusyDataHeaderIconButton(
        tooltip: '$label: ${modes[value]!.label}',
        icon: icon(modes[value]!.icon ?? DesktopIcon.tool),
        focusNode: trigger.focusNode,
        isSelected: trigger.isOpen,
        onPressed: trigger.onPressed,
      ),
    ),
  );
  @override
  Widget propertyRow(String label, Widget value) => Builder(
    builder: (context) => LayoutBuilder(
      builder: (context, bounds) =>
          bounds.maxWidth < 480 ||
              MediaQuery.textScalerOf(context).scale(14) > 21
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (label.isNotEmpty) Text(label), value],
              ),
            )
          : YaruListTile.square(
              title: Text(label),
              trailing: SizedBox(width: bounds.maxWidth * .55, child: value),
            ),
    ),
  );
  @override
  Widget scrollbar({
    required ScrollController controller,
    required Widget child,
    bool alwaysVisible = false,
  }) => Builder(
    builder: (context) => ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: alwaysVisible,
        child: child,
      ),
    ),
  );
  @override
  Widget tabInteraction({
    required Widget child,
    required VoidCallback onPressed,
    FocusNode? focusNode,
    ValueChanged<bool>? onFocusChange,
    bool selected = false,
    bool hovered = false,
  }) => Builder(
    builder: (context) => Material(
      color: tabBackground(context, selected, false),
      borderRadius: tabRadius,
      child: InkWell(
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        onTap: onPressed,
        borderRadius: tabRadius,
        hoverColor: BusyDataSurfaceColors.of(context).controlHover,
        child: child,
      ),
    ),
  );
  @override
  Color tabBorder(BuildContext context) =>
      BusyDataSurfaceColors.of(context).subtleBorder;
  @override
  Color tabBackground(BuildContext context, bool selected, bool hovered) =>
      selected
      ? BusyDataSurfaceColors.of(context).view
      : hovered
      ? BusyDataSurfaceColors.of(context).controlHover
      : Colors.transparent;
  @override
  Color tabForeground(BuildContext context, bool selected) => selected
      ? BusyDataSurfaceColors.of(context).foreground
      : BusyDataSurfaceColors.of(context).mutedForeground;
  @override
  TextStyle tabLabelStyle(BuildContext context, bool selected) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(
        color: tabForeground(context, selected),
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      );
  @override
  BorderRadius get rowRadius => BorderRadius.circular(BusyDataRadius.md);
  @override
  BorderRadius get tabRadius =>
      const BorderRadius.vertical(top: Radius.circular(BusyDataRadius.sm));
  @override
  double get treeIndent => BusyDataSizes.sidebarTreeDepthIndent;
  @override
  double get treeControl => BusyDataSizes.sidebarTreeControl;
  @override
  Widget applicationFrame({
    required Widget body,
    required Widget sidebar,
    required bool sidebarVisible,
    required int sidebarGeneration,
    required double sidebarWidth,
    required ValueChanged<double> resizeSidebar,
    required VoidCallback toggleSidebar,
    required String title,
    required List<DesktopMenu> menus,
    required VoidCallback search,
    required VoidCallback prepareSearch,
    String? searchShortcut,
    String? sidebarShortcut,
    bool sidebarAvailable = true,
    bool sidebarResizable = true,
    bool showSearch = true,
    Widget? searchField,
    Widget? searchSidebar,
    Widget? contextualControls,
    VoidCallback? back,
  }) => LinuxWorkbenchFrame(
    menuEntry: (action) => _menuEntry(action, action),
    body: body,
    sidebar: sidebar,
    sidebarVisible: sidebarVisible,
    sidebarGeneration: sidebarGeneration,
    sidebarWidth: sidebarWidth,
    resizeSidebar: resizeSidebar,
    toggleSidebar: toggleSidebar,
    title: title,
    menus: menus,
    search: search,
    prepareSearch: prepareSearch,
    searchShortcut: searchShortcut,
    sidebarShortcut: sidebarShortcut,
    sidebarAvailable: sidebarAvailable,
    sidebarResizable: sidebarResizable,
    showSearch: showSearch,
    searchField: searchField,
    searchSidebar: searchSidebar,
    contextualControls: contextualControls,
    back: back,
  );

  BusyDataMenuEntry<T> _menuEntry<T>(DesktopMenuAction action, T value) =>
      BusyDataMenuEntry(
        value: value,
        label: action.label,
        shortcut: action.shortcut,
        enabled: action.disabledReason == null,
        tooltip: action.disabledReason,
        icon: action.destructive ? YaruIcons.trash : _linuxGlyphs[action.icon],
        destructive: action.destructive,
        role: action.checked == null
            ? BusyDataMenuEntryRole.command
            : BusyDataMenuEntryRole.toggle,
        selected: action.checked == true,
      );
  @override
  Widget groupedList({String? title, required List<Widget> children}) =>
      BusyDataGroupedList(title: title, filled: true, children: children);
  @override
  Widget actionRow({
    required String title,
    String? semanticValue,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    required VoidCallback? onPressed,
  }) => MergeSemantics(
    child: Semantics(
      label: semanticValue == null || semanticValue.isEmpty
          ? title
          : busyDataSelectedValueLabel(title, semanticValue),
      hint: subtitle,
      button: true,
      enabled: onPressed != null,
      child: BusyDataActionRow(
        title: title,
        subtitle: subtitle,
        titleWidget: ExcludeSemantics(
          child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        subtitleWidget: subtitle == null
            ? null
            : ExcludeSemantics(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
        leading: leading == null ? null : ExcludeSemantics(child: leading),
        trailing: trailing == null ? null : ExcludeSemantics(child: trailing),
        onTap: onPressed,
        enabled: onPressed != null,
      ),
    ),
  );
  @override
  Widget switchRow(
    String title,
    bool value,
    ValueChanged<bool>? changed, {
    String? subtitle,
  }) => BusyDataSwitchRow(
    title: title,
    subtitle: subtitle,
    value: value,
    onChanged: changed ?? (_) {},
    enabled: changed != null,
  );
  @override
  Widget comboRow<T>(
    String title,
    T value,
    Map<T, String> values,
    ValueChanged<T> changed, {
    bool enabled = true,
  }) => Material(
    type: MaterialType.transparency,
    child: BusyDataComboRow<T>(
      title: title,
      values: values.keys.toList(),
      selected: value,
      labelFor: (value) => values[value]!,
      onSelected: changed,
      enabled: enabled,
    ),
  );
  @override
  Widget section(String label, bool selected, VoidCallback pressed) => Builder(
    builder: (context) => TextButton(
      style: Theme.of(context).outlinedButtonTheme.style?.copyWith(
        backgroundColor: WidgetStatePropertyAll(
          selected
              ? BusyDataSurfaceColors.of(context).controlActive
              : Colors.transparent,
        ),
      ),
      onPressed: pressed,
      child: Text(label),
    ),
  );
  @override
  Widget formList(List<Widget> children, EdgeInsetsGeometry padding) {
    final groups = <Widget>[];
    String? title;
    var rows = <Widget>[];
    void flush() {
      if (rows.isNotEmpty) {
        groups.add(
          BusyDataGroupedList(title: title, filled: true, children: rows),
        );
      }
      rows = <Widget>[];
    }

    for (final child in children) {
      if (child is WorkbenchFormHeading) {
        flush();
        title = child.label;
      } else {
        rows.add(child);
      }
    }
    flush();
    return BusyDataClamp(
      margin: EdgeInsets.zero,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: groups,
      ),
    );
  }

  @override
  Widget status(String message, {bool error = false, bool success = false}) =>
      BusyDataStatusBox(
        message: message,
        kind: error
            ? BusyDataStatusKind.error
            : success
            ? BusyDataStatusKind.success
            : BusyDataStatusKind.information,
      );
  @override
  Widget tooltip(String message, Widget child) =>
      Tooltip(message: message, excludeFromSemantics: true, child: child);
  @override
  Widget contextMenu(Widget child, List<DesktopMenuAction> actions) => Builder(
    builder: (context) {
      Future<void> open(Offset position, {bool keyboard = false}) async {
        final selected = await showBusyDataMenu<int>(
          context: context,
          anchorPoint: position,
          focusFirst: keyboard,
          entries: [
            for (var i = 0; i < actions.length; i++) _menuEntry(actions[i], i),
          ],
        );
        if (PresentationDiagnostics.enabled) {
          debugPrint(
            'BusyDataMenuKey retired keyboard=$keyboard '
            'menuDown=${HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.contextMenu)} '
            'f10Down=${HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.f10)} '
            'shiftDown=${HardwareKeyboard.instance.isShiftPressed} '
            'focus=${FocusManager.instance.primaryFocus?.context?.widget.runtimeType}',
          );
        }
        if (selected != null) actions[selected.value].invoke();
      }

      return Focus(
        canRequestFocus: false,
        onKeyEvent: (_, event) {
          if (PresentationDiagnostics.enabled &&
              event.logicalKey == LogicalKeyboardKey.contextMenu) {
            debugPrint(
              'BusyDataMenuKey ${event.runtimeType} '
              'focus=${FocusManager.instance.primaryFocus?.context?.widget.runtimeType}',
            );
          }
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                  event.logicalKey == LogicalKeyboardKey.f10 &&
                      HardwareKeyboard.instance.isShiftPressed &&
                      !HardwareKeyboard.instance.isControlPressed &&
                      !HardwareKeyboard.instance.isAltPressed &&
                      !HardwareKeyboard.instance.isMetaPressed)) {
            final box = context.findRenderObject() as RenderBox?;
            if (box != null) {
              open(
                box.localToGlobal(Offset(0, box.size.height)),
                keyboard: true,
              );
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onSecondaryTapUp: (event) => open(event.globalPosition),
          child: child,
        ),
      );
    },
  );
  @override
  Widget splitButton(
    String label,
    VoidCallback? action,
    String optionsLabel,
    List<DesktopMenuAction> options,
  ) => BusyDataMenuButton<int>(
    tooltip: optionsLabel,
    entries: [
      for (var i = 0; i < options.length; i++)
        BusyDataMenuEntry(
          value: i,
          label: options[i].label,
          shortcut: options[i].shortcut,
          enabled: options[i].disabledReason == null,
          tooltip: options[i].disabledReason,
        ),
    ],
    onSelected: (i) => options[i].invoke(),
    triggerBuilder: (_, trigger) => YaruSplitButton(
      onPressed: action,
      onOptionsPressed: trigger.onPressed,
      iconSemanticLabel: optionsLabel,
      icon: trigger.anchor(child: const Icon(YaruIcons.pan_down, size: 12)),
      child: Text(label),
    ),
  );
  @override
  Widget iconMenu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  }) => BusyDataMenuButton<int>(
    tooltip: label,
    entries: [
      for (var i = 0; i < actions.length; i++) _menuEntry(actions[i], i),
    ],
    onSelected: (i) => actions[i].invoke(),
    triggerBuilder: (context, trigger) => trigger.anchor(
      child: MergeSemantics(
        child: Semantics(
          label: label,
          child: IconButton(
            tooltip: label,
            focusNode: trigger.focusNode,
            onPressed: trigger.onPressed,
            icon: icon(DesktopIcon.more),
            style: _actionStyle(context, compact: compact, iconOnly: true),
          ),
        ),
      ),
    ),
  );
  @override
  Widget menuBar(List<DesktopMenu> menus) => LinuxWorkbenchMainMenu(
    menus: menus,
    menuEntry: (action) => _menuEntry(action, action),
  );
  @override
  Widget menu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  }) => _menu(label, actions, compact: compact);
  Widget _menu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  }) => BusyDataMenuButton<int>(
    tooltip: label,
    entries: [
      for (var i = 0; i < actions.length; i++) _menuEntry(actions[i], i),
    ],
    onSelected: (i) => actions[i].invoke(),
    triggerBuilder: (context, trigger) => TextButton(
      onPressed: trigger.onPressed,
      focusNode: trigger.focusNode,
      style: _actionStyle(context, compact: compact),
      child: trigger.anchor(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            ...[
              const SizedBox(width: 6),
              const Icon(YaruIcons.pan_down, size: 12),
            ],
          ],
        ),
      ),
    ),
  );
  @override
  Widget icon(DesktopIcon icon, {double size = 16}) {
    if (const {
      DesktopIcon.table,
      DesktopIcon.view,
      DesktopIcon.column,
      DesktopIcon.routine,
    }.contains(icon)) {
      return LinuxDatabaseIcon(icon, size: size);
    }
    final glyph = Icon(_linuxGlyphs[icon]!, size: size);
    if (icon != DesktopIcon.expand) return glyph;
    // Yaru's pan_end glyph lacks IconData.matchTextDirection. Mirror this
    // native glyph so its direction agrees with the RTL tree key map.
    return Builder(
      builder: (context) => Transform.flip(
        flipX: Directionality.of(context) == TextDirection.rtl,
        child: glyph,
      ),
    );
  }

  @override
  Widget iconButton(
    DesktopIcon value,
    String label,
    VoidCallback? action, {
    bool compact = false,
  }) {
    final glyph = compact && value == DesktopIcon.close
        ? YaruIcons.edit_clear
        : _linuxGlyphs[value];
    if (compact && glyph != null) {
      return BusyDataCompactIconButton(
        tooltip: label,
        icon: glyph,
        onPressed: action,
      );
    }
    return BusyDataHeaderIconButton(
      icon: icon(value),
      tooltip: label,
      onPressed: action,
    );
  }

  @override
  Widget textButton(
    String label,
    VoidCallback? action, {
    bool compact = false,
  }) => Builder(
    builder: (context) => TextButton(
      onPressed: action,
      style: _actionStyle(context, compact: compact),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
  @override
  Widget searchField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
    required VoidCallback submit,
    required VoidCallback close,
    required ValueChanged<int> move,
  }) => BusyDataSearchField(
    controller: controller,
    hintText: label,
    focusNode: focusNode,
    autofocus: true,
    clearOnEscape: false,
    onSubmitted: (_) => submit(),
    onMoveSelection: move,
    onEscape: close,
  );
  @override
  Widget filterField(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
    bool autofocus = false,
    bool clearOnEscape = true,
    ValueChanged<String>? onChanged,
  }) => BusyDataSearchField(
    controller: controller,
    hintText: label,
    focusNode: focusNode,
    autofocus: autofocus,
    clearOnEscape: clearOnEscape,
    onChanged: onChanged,
  );
  @override
  Widget button(
    String label,
    VoidCallback? action, {
    bool primary = false,
    bool destructive = false,
    FocusNode? focusNode,
  }) {
    assert(!primary || !destructive);
    if (destructive) {
      return Builder(
        builder: (context) => BusyDataPushButton.destructive(
          context: context,
          onPressed: action,
          focusNode: focusNode,
          child: Text(label),
        ),
      );
    }
    return primary
        ? BusyDataPushButton.suggested(
            onPressed: action,
            focusNode: focusNode,
            child: Text(label),
          )
        : BusyDataPushButton.standard(
            onPressed: action,
            focusNode: focusNode,
            child: Text(label),
          );
  }

  @override
  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    bool enabled = true,
    FocusNode? focusNode,
    bool showLabel = true,
    bool readOnly = false,
    bool technical = false,
    Widget? trailing,
    String? errorText,
  }) => Builder(
    builder: (context) => BusyDataGroupedTextEntry(
      controller: controller,
      label: label,
      focusNode: focusNode,
      errorText: errorText,
      obscureText: secret,
      enabled: enabled,
      readOnly: readOnly,
      autocorrect: !secret && !technical && !readOnly,
      enableSuggestions: !secret && !technical && !readOnly,
      textDirection: technical || readOnly ? TextDirection.ltr : null,
      textStyle: technical || readOnly ? appearance(context).technical : null,
      trailing: trailing,
    ),
  );

  @override
  Widget inlineField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
  }) => Builder(
    builder: (context) => Material(
      type: MaterialType.transparency,
      child: Semantics(
        label: label,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          style: appearance(context).body,
          textAlignVertical: TextAlignVertical.center,
          decoration: const InputDecoration(
            isCollapsed: true,
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
      ),
    ),
  );
  @override
  Widget multilineField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
    bool expands = false,
  }) => BusyDataGroupedTextEntry(
    controller: controller,
    label: label,
    focusNode: focusNode,
    minLines: 6,
    maxLines: 20,
    expands: expands,
    autocorrect: false,
    enableSuggestions: false,
  );
  @override
  Widget choice<T>(
    T value,
    Map<T, String> choices,
    ValueChanged<T> changed, {
    String? label,
    bool enabled = true,
  }) => BusyDataPopupSelector<T>(
    value: value,
    label: choices[value]!,
    tooltip: label ?? choices[value]!,
    enabled: enabled,
    fullWidth: true,
    options: [
      for (final entry in choices.entries)
        BusyDataPopupSelectorOption(value: entry.key, label: entry.value),
    ],
    onSelected: changed,
  );

  @override
  double choiceWidth(BuildContext context, String label) {
    final theme = Theme.of(context);
    final style = theme.outlinedButtonTheme.style;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: style?.textStyle?.resolve({}) ?? theme.textTheme.labelLarge,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final padding = style?.padding?.resolve({}) ?? const EdgeInsets.all(16);
    final width = painter.width + padding.horizontal + BusyDataSpacing.sm + 16;
    painter.dispose();
    return width.ceilToDouble();
  }

  @override
  Widget checkbox(String label, bool value, ValueChanged<bool>? changed) =>
      BusyDataCheckbox(
        value: value,
        onChanged: changed == null ? null : (value) => changed(value ?? false),
        label: label,
      );
  @override
  Widget surface(Widget child) => BusyDataSurface(child: child);
  @override
  Future<T?> formDialog<T>(BuildContext context, WidgetBuilder builder) =>
      showBusyDataModalDialog<T>(
        context,
        barrierDismissible: false,
        builder: (context) => ModalCommandBoundary(child: builder(context)),
      );
  @override
  Widget editorShell({
    required String title,
    required String cancelLabel,
    required String saveLabel,
    required VoidCallback onCancel,
    required VoidCallback? onSave,
    required Widget body,
    FocusNode? saveFocus,
    bool saving = false,
    bool cancelEnabled = true,
  }) => BusyDataModalEditorSurface(
    maxWidth: 760,
    insetPadding: const EdgeInsets.all(16),
    child: BusyDataModalEditorScaffold(
      title: title,
      cancelLabel: cancelLabel,
      saveLabel: saveLabel,
      onCancel: onCancel,
      onSave: onSave,
      saveFocus: saveFocus,
      saving: saving,
      cancelEnabled: cancelEnabled,
      children: [body],
    ),
  );
  @override
  Widget formShell(
    String title,
    Widget body,
    List<Widget> actions, {
    bool scrollBody = true,
    double maxWidth = 760,
  }) => BusyDataDialogShell(
    title: title,
    maxWidth: maxWidth,
    scrollBody: scrollBody,
    contentPadding: scrollBody ? 16 : 8,
    actions: actions,
    children: [body],
  );
  @override
  Future<T?> dialog<T>(
    BuildContext context,
    String title,
    Widget body,
    List<Widget> actions, {
    bool bodyScrolls = false,
  }) => showBusyDataModalDialog<T>(
    context,
    barrierDismissible: false,
    builder: (_) => ModalCommandBoundary(
      child: BusyDataDialogShell(
        title: title,
        maxWidth: 640,
        scrollBody: !bodyScrolls,
        actions: actions,
        children: [body],
      ),
    ),
  );
  @override
  DesktopAppearance appearance(BuildContext context) =>
      linuxAppearance(context);
  @override
  Color background(BuildContext context) =>
      BusyDataSurfaceColors.of(context).window;
  @override
  Color foreground(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  @override
  Color accent(BuildContext context) => Theme.of(context).colorScheme.primary;
  @override
  TextStyle textStyle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;
}

ButtonStyle _actionStyle(
  BuildContext context, {
  bool compact = false,
  bool iconOnly = false,
}) {
  final look = linuxAppearance(context);
  final height = iconOnly
      ? compact
            ? 24.0
            : 32.0
      : compact
      ? 24.0
      : look.controlHeight(context);
  final foreground = WidgetStateProperty.resolveWith<Color?>(
    (states) => states.contains(WidgetState.disabled)
        ? look.disabledForeground
        : (iconOnly
                  ? IconTheme.of(context).color
                  : DefaultTextStyle.of(context).style.color) ??
              look.foreground,
  );
  return ButtonStyle(
    textStyle: WidgetStatePropertyAll(DefaultTextStyle.of(context).style),
    foregroundColor: foreground,
    iconColor: foreground,
    minimumSize: WidgetStatePropertyAll(Size(iconOnly ? height : 0, height)),
    // Yaru's nominal icon-button fixed/max size must not constrain a measured
    // larger font, or override the compact action's own minimum geometry.
    fixedSize: const WidgetStatePropertyAll(Size.infinite),
    maximumSize: const WidgetStatePropertyAll(Size.infinite),
    padding: WidgetStatePropertyAll(
      EdgeInsets.symmetric(
        horizontal: iconOnly ? 4 : 8,
        vertical: compact ? 0 : 3,
      ),
    ),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kYaruButtonRadius),
      ),
    ),
  );
}

// One finite symbolic catalog, also consumed by the Linux release recorder to
// verify every required glyph in the actual packaged font subset.
const _linuxGlyphs = <DesktopIcon, IconData>{
  DesktopIcon.add: YaruIcons.plus,
  DesktopIcon.close: YaruIcons.window_close,
  DesktopIcon.expand: YaruIcons.pan_end,
  DesktopIcon.collapse: YaruIcons.pan_down,
  DesktopIcon.connection: YaruIcons.server,
  DesktopIcon.sequence: YaruIcons.ordered_list,
  DesktopIcon.folder: YaruIcons.folder,
  DesktopIcon.query: YaruIcons.terminal,
  DesktopIcon.copy: YaruIcons.copy,
  DesktopIcon.tool: YaruIcons.wrench,
  DesktopIcon.sidebar: YaruIcons.sidebar,
  DesktopIcon.more: YaruIcons.view_more_horizontal,
  DesktopIcon.search: YaruIcons.search,
  DesktopIcon.refresh: YaruIcons.refresh,
  DesktopIcon.running: YaruIcons.hourglass,
  DesktopIcon.warning: YaruIcons.warning,
  DesktopIcon.transaction: YaruIcons.sync,
  DesktopIcon.dirty: YaruIcons.media_record,
  DesktopIcon.connected: YaruIcons.network_wired_filled,
  DesktopIcon.disconnected: YaruIcons.network_wired,
  DesktopIcon.favorite: YaruIcons.star,
  DesktopIcon.settings: YaruIcons.settings,
  DesktopIcon.privacy: YaruIcons.shield_warning,
  DesktopIcon.keyboard: YaruIcons.keyboard_shortcuts,
  DesktopIcon.appearance: YaruIcons.desktop_appearance,
  DesktopIcon.language: YaruIcons.symbols,
  DesktopIcon.history: YaruIcons.history,
};

class _LinuxMenuPresenter extends DesktopMenuPresenter {
  _LinuxMenuPresenter(this.controls);
  final LinuxControls controls;
  BusyDataMenuSession? _session;
  @override
  bool ownsFocus(FocusNode? focus) => _session?.ownsFocus(focus) == true;
  @override
  Future<int?> show(
    BuildContext context,
    Offset position,
    List<DesktopMenuAction> actions, {
    bool keyboard = false,
  }) async {
    await dismiss();
    if (!context.mounted) return null;
    final session = BusyDataMenuSession();
    _session = session;
    final result = await showBusyDataMenu<int>(
      context: context,
      session: session,
      anchorPoint: position,
      focusFirst: keyboard,
      entries: [
        for (var i = 0; i < actions.length; i++)
          controls._menuEntry(actions[i], i),
      ],
    );
    if (!identical(_session, session)) return null;
    _session = null;
    return result?.value;
  }

  @override
  Future<void> dismiss() async {
    final session = _session;
    _session = null;
    await session?.dismiss();
  }

  @override
  void dispose() {
    dismiss();
  }
}
