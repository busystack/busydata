import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'desktop_appearance.dart';

export 'desktop_appearance.dart';

abstract class DesktopControls {
  const DesktopControls();

  DesktopMenuPresenter createMenuPresenter() => DesktopMenuPresenter();
  Widget scrollbar({
    required ScrollController controller,
    required Widget child,
    bool alwaysVisible = false,
  }) => Builder(
    builder: (context) => RawScrollbar(
      controller: controller,
      thumbVisibility: alwaysVisible,
      thumbColor: appearance(context).secondaryForeground,
      child: child,
    ),
  );
  Widget sidebarNavigation(List<Widget> children) =>
      ListView(children: children);
  Widget sidebarNavigationTile({
    required bool selected,
    required Widget leading,
    required String title,
    required VoidCallback onPressed,
  }) => section(title, selected, onPressed);
  Widget completionSurface(Widget child) => Builder(
    builder: (context) => DecoratedBox(
      decoration: BoxDecoration(
        color: appearance(context).popover,
        borderRadius: rowRadius,
      ),
      child: child,
    ),
  );

  /// Presentation capabilities, implemented by the platform adapter. Database
  /// workflows supply content and callbacks without importing a desktop toolkit.
  bool get hasWindowHeader => false;
  double get defaultSidebarWidth => 300;
  double get formContentWidth => 640;
  double get settingsSidebarBreakpoint => defaultSidebarWidth + 520;
  EdgeInsetsGeometry get settingsPagePadding =>
      const EdgeInsets.fromLTRB(24, 8, 24, 24);
  EdgeInsetsGeometry get sidebarListPadding => EdgeInsets.zero;
  Widget settingsTransition(Object category, Widget child) => child;
  Widget recordContent(Widget child, {DesktopIcon? leading}) => Builder(
    builder: (context) => Container(
      alignment: AlignmentDirectional.centerStart,
      constraints: BoxConstraints(
        minHeight: appearance(context).rowHeight(context),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: leading == null
          ? child
          : Row(
              children: [
                icon(leading),
                const SizedBox(width: 8),
                Expanded(child: child),
              ],
            ),
    ),
  );
  Widget preferenceRow<T>(
    String title,
    DesktopIcon leading,
    T value,
    Map<T, String> values,
    ValueChanged<T> changed, {
    bool enabled = true,
  }) => comboRow(title, value, values, changed, enabled: enabled);
  Widget shortcutBadge(String label) =>
      Text(label, textDirection: TextDirection.ltr);
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
  }) => Column(
    children: [
      if (searchField != null || back != null)
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              if (back != null) textButton(title, back),
              if (searchField != null) Expanded(child: searchField),
            ],
          ),
        ),
      Expanded(
        key: const ValueKey('desktop-workbench-content'),
        child: Row(
          children: [
            if (searchSidebar != null)
              SizedBox(width: 300, child: searchSidebar),
            Expanded(
              key: const ValueKey('desktop-workbench-body'),
              child: body,
            ),
          ],
        ),
      ),
    ],
  );

  Widget groupedList({String? title, required List<Widget> children}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [if (title != null) Text(title), ...children],
  );
  Widget actionRow({
    required String title,
    String? semanticValue,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    required VoidCallback? onPressed,
  }) => MergeSemantics(
    child: Semantics(value: semanticValue, child: textButton(title, onPressed)),
  );
  Widget switchRow(
    String title,
    bool value,
    ValueChanged<bool>? changed, {
    String? subtitle,
  }) => checkbox(title, value, changed);
  Widget comboRow<T>(
    String title,
    T value,
    Map<T, String> values,
    ValueChanged<T> changed, {
    bool enabled = true,
  }) => choice(value, values, changed, label: title, enabled: enabled);
  Widget section(String label, bool selected, VoidCallback pressed) =>
      textButton(label, pressed);
  Widget formList(List<Widget> children, EdgeInsetsGeometry padding) =>
      ListView.separated(
        padding: padding,
        itemCount: children.length,
        itemBuilder: (_, index) => children[index],
        separatorBuilder: (_, _) => const SizedBox(height: 6),
      );
  Widget status(String message, {bool error = false, bool success = false}) =>
      Text(message);
  Widget searchField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
    required VoidCallback submit,
    required VoidCallback close,
    required ValueChanged<int> move,
  }) => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent || controller.value.composing.isValid) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        submit();
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        close();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        move(1);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        move(-1);
      } else {
        return KeyEventResult.ignored;
      }
      return KeyEventResult.handled;
    },
    child: filterField(
      controller,
      label,
      focusNode: focusNode,
      autofocus: true,
      clearOnEscape: false,
    ),
  );
  Widget strip(
    Widget child, {
    double minimumHeight = 38,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8),
    bool topBorder = false,
  }) => Builder(
    builder: (context) => Container(
      constraints: BoxConstraints(minHeight: minimumHeight),
      padding: padding,
      decoration: BoxDecoration(
        color: appearance(context).header,
        border: Border(
          top: topBorder
              ? BorderSide(color: appearance(context).separator)
              : BorderSide.none,
          bottom: topBorder
              ? BorderSide.none
              : BorderSide(color: appearance(context).separator),
        ),
      ),
      child: child,
    ),
  );
  Widget rowSurface({
    required Widget child,
    required bool selected,
    required bool focused,
    bool hovered = false,
    bool? focusVisible,
    Color? base,
  }) => Builder(
    builder: (context) {
      final look = appearance(context);
      return Container(
        decoration: BoxDecoration(
          borderRadius: rowRadius,
          color: look.rowBackground(
            selected: selected,
            focused: focused,
            hovered: hovered,
            base: base,
          ),
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: rowRadius,
          border: Border.all(
            width: 2,
            color: !(focusVisible ?? focused)
                ? const Color(0x00000000)
                : selected && focused
                ? look.selectedForeground
                : look.focus,
          ),
        ),
        child: child,
      );
    },
  );
  Widget modeSwitcher<T>(
    T value,
    Map<T, String> values,
    ValueChanged<T> changed, {
    String? label,
  }) => choice(value, values, changed, label: label);

  Widget headerModeSwitcher<T>(
    T value,
    Map<T, DesktopMenuAction> modes,
    String label,
  ) => modeSwitcher(
    value,
    {for (final entry in modes.entries) entry.key: entry.value.label},
    (value) => modes[value]!.invoke(),
    label: label,
  );
  Widget treeExpander(bool expanded, String label, VoidCallback toggle) =>
      iconButton(
        expanded ? DesktopIcon.collapse : DesktopIcon.expand,
        label,
        toggle,
        compact: true,
      );
  Widget propertyRow(String label, Widget value) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [Text(label), value],
  );
  Widget tabInteraction({
    required Widget child,
    required VoidCallback onPressed,
    FocusNode? focusNode,
    ValueChanged<bool>? onFocusChange,
    bool selected = false,
    bool hovered = false,
  }) => FocusableActionDetector(
    focusNode: focusNode,
    onFocusChange: onFocusChange,
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          onPressed();
          return null;
        },
      ),
    },
    child: Builder(
      builder: (context) => ColoredBox(
        color: tabBackground(context, selected, hovered),
        child: GestureDetector(onTap: onPressed, child: child),
      ),
    ),
  );
  Color tabBorder(BuildContext context) => appearance(context).separator;
  Color tabBackground(BuildContext context, bool selected, bool hovered) =>
      appearance(context).rowBackground(
        selected: selected,
        hovered: hovered,
        base: appearance(context).header,
      );
  Color tabForeground(BuildContext context, bool selected) =>
      appearance(context).rowForeground(selected: selected);
  TextStyle tabLabelStyle(BuildContext context, bool selected) => appearance(
    context,
  ).body.copyWith(color: tabForeground(context, selected));
  BorderRadius get rowRadius => BorderRadius.zero;
  BorderRadius get tabRadius => BorderRadius.zero;
  double get treeIndent => 16;
  double get treeControl => 24;
  double get treeMenuWidth => 24;
  Widget tabLeading(DesktopIcon iconValue, bool dirty) =>
      icon(dirty ? DesktopIcon.dirty : iconValue, size: dirty ? 7 : 16);
  Widget completionRow({
    required Widget child,
    required bool selected,
    required VoidCallback onPressed,
  }) => Builder(
    builder: (context) => Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onPressed,
        child: rowSurface(
          selected: selected,
          focused: selected,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: child,
          ),
        ),
      ),
    ),
  );

  double get contentWidth => 760;
  Widget contentClamp(
    Widget child, {
    EdgeInsetsGeometry padding = EdgeInsets.zero,
  }) => SingleChildScrollView(
    child: Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: BoxConstraints(maxWidth: contentWidth),
        padding: padding,
        child: child,
      ),
    ),
  );
  Widget menuBar(List<DesktopMenu> menus);
  Widget splitButton(
    String label,
    VoidCallback? action,
    String optionsLabel,
    List<DesktopMenuAction> options,
  );
  Widget menu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  });
  Widget iconMenu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  });
  Widget icon(DesktopIcon icon, {double size = 16});
  Widget iconButton(
    DesktopIcon icon,
    String label,
    VoidCallback? action, {
    bool compact = false,
  });
  Widget textButton(String label, VoidCallback? action, {bool compact = false});
  Widget filterField(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
    bool autofocus = false,
    bool clearOnEscape = true,
    ValueChanged<String>? onChanged,
  });
  Widget contextMenu(Widget child, List<DesktopMenuAction> actions);
  Widget tooltip(String message, Widget child);
  Widget button(
    String label,
    VoidCallback? action, {
    bool primary = false,
    bool destructive = false,
    FocusNode? focusNode,
  });
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
  });
  Widget inlineField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
  });
  Widget multilineField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
    bool expands = false,
  }) => field(controller, label, focusNode: focusNode, technical: true);
  Widget choice<T>(
    T value,
    Map<T, String> choices,
    ValueChanged<T> changed, {
    String? label,
    bool enabled = true,
  });

  /// Natural width of one selected choice, including native padding/arrow.
  double choiceWidth(BuildContext context, String label);
  Widget checkbox(String label, bool value, ValueChanged<bool>? changed);
  Widget surface(Widget child);
  Future<T?> formDialog<T>(BuildContext context, WidgetBuilder builder);
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
  }) => formShell(title, body, [
    button(cancelLabel, cancelEnabled ? onCancel : null),
    button(
      saveLabel,
      saving ? null : onSave,
      primary: true,
      focusNode: saveFocus,
    ),
    if (saving) status(saveLabel),
  ]);
  Widget formShell(
    String title,
    Widget body,
    List<Widget> actions, {
    bool scrollBody = true,
    double maxWidth = 760,
  });
  Future<T?> dialog<T>(
    BuildContext context,
    String title,
    Widget body,
    List<Widget> actions, {
    // A body with its own scrolling must receive the dialog's bounded space.
    bool bodyScrolls = false,
  });
  Color background(BuildContext context);
  Color foreground(BuildContext context);
  Color accent(BuildContext context);
  TextStyle textStyle(BuildContext context);
  DesktopAppearance appearance(BuildContext context);
}

enum DesktopIcon {
  add,
  close,
  expand,
  collapse,
  connection,
  table,
  view,
  routine,
  column,
  sequence,
  folder,
  query,
  copy,
  tool,
  sidebar,
  more,
  search,
  refresh,
  running,
  warning,
  transaction,
  dirty,
  favorite,
  connected,
  disconnected,
  settings,
  privacy,
  keyboard,
  appearance,
  language,
  history,
}

class DesktopMenu {
  const DesktopMenu(this.label, this.actions, {this.children = const []});
  final String label;
  final List<DesktopMenuAction> actions;
  final List<DesktopMenu> children;
}

class DesktopMenuAction {
  const DesktopMenuAction(
    this.label,
    this.invoke, {
    this.shortcut,
    this.disabledReason,
    this.icon,
    this.checked,
    this.destructive = false,
  });
  final String label;
  final VoidCallback invoke;
  final String? shortcut, disabledReason;
  final DesktopIcon? icon;
  final bool? checked;
  final bool destructive;
}

/// A single owned popup. Platform adapters retain their own native/flyout
/// retirement and focus rules; cancelling this object cannot dismiss a newer one.
class DesktopMenuPresenter {
  Widget anchor(Widget child) => child;

  /// True only while this presentation's popup owns the given Flutter focus.
  bool ownsFocus(FocusNode? focus) => false;
  Future<int?> show(
    BuildContext context,
    Offset position,
    List<DesktopMenuAction> actions, {
    bool keyboard = false,
  }) async => null;
  Future<void> dismiss() async {}
  void dispose() {}
}
