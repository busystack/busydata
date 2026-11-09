import 'dart:io' show Platform;
import 'dart:ui' show SemanticsRole;
import 'package:re_editor/re_editor.dart' show CodeEditorTapRegion;
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../common/desktop_controls.dart';
import '../../l10n/workbench_strings.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as glyphs;
import '../common/modal_command_boundary.dart';
import '../common/modal_focus_restoration.dart';
import 'windows_secret_field.dart';

Widget _dialogTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) => FadeTransition(
  opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
  child: child,
);

Future<T?> _showWorkbenchFluentDialog<T>(
  BuildContext context,
  WidgetBuilder builder,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final focus = ModalFocusRestoration.capture(context);
  final result = await navigator.push<T>(
    _WorkbenchFluentDialogRoute<T>(
      context: context,
      builder: (context) => ModalCommandBoundary(child: builder(context)),
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      focus: focus,
    ),
  );
  focus.restoreAfterCompletion();
  return result;
}

class _WorkbenchFluentDialogRoute<T> extends FluentDialogRoute<T> {
  _WorkbenchFluentDialogRoute({
    required super.context,
    required super.builder,
    required super.themes,
    required this.focus,
  }) : super(
         barrierDismissible: false,
         dismissWithEsc: false,
         transitionBuilder: _dialogTransition,
         transitionDuration:
             FluentTheme.maybeOf(context)?.fastAnimationDuration ??
             const Duration(milliseconds: 300),
       );

  final ModalFocusRestoration focus;

  @override
  bool didPop(T? result) {
    final accepted = super.didPop(result);
    if (accepted) {
      focus.restoreOnAcceptedPop(this);
    }
    return accepted;
  }
}

// Menu gestures retain the editor input owner until the command deliberately
// moves focus; both the menu bar and its actual popup share this public group.
Widget _menuScope(Widget child, {bool bar = false}) => CodeEditorTapRegion(
  child: Semantics(
    container: true,
    explicitChildNodes: true,
    role: bar ? SemanticsRole.menuBar : SemanticsRole.menu,
    enabled: true,
    child: child,
  ),
);

// Keep this non-container annotation on the text: official menu cloning
// retains it, and HoverButton merges it with the real focus/tap callbacks.
Widget _menuItemLabel(String label, {bool enabled = true, bool? checked}) =>
    Semantics(
      role: checked == null
          ? SemanticsRole.menuItem
          : SemanticsRole.menuItemCheckbox,
      enabled: enabled,
      checked: checked,
      child: Text(label),
    );

DropDownButton _menuDropDown({
  required List<MenuFlyoutItemBase> items,
  DropDownButtonBuilder? buttonBuilder,
  Widget? title,
}) {
  return DropDownButton(
    items: items,
    buttonBuilder: buttonBuilder,
    title: title,
    // A clipped slide can expose an empty menu and replace the semantic parent
    // of retained scroll nodes on completion. Fade the official popup under one
    // stable boundary, keeping its menu items exposed throughout the transition.
    transitionBuilder: (context, animation, placement, flyout) => _menuScope(
      FadeTransition(
        opacity: animation.drive(
          CurveTween(curve: FluentTheme.of(context).animationCurve),
        ),
        alwaysIncludeSemantics: true,
        child: flyout,
      ),
    ),
  );
}

// MenuBar exposes an item builder rather than a popup builder. One root group
// supplies the menu scope; the public Flyout proxy carries that scope into real
// submenu transitions without replacing their item lists or close-key chains.
Widget _menuBarGroup(BuildContext context, List<MenuFlyoutItemBase> items) {
  final parent = Flyout.of(context);
  final appearance = context.findAncestorWidgetOfExactType<MenuFlyout>()!;
  return Flyout(
    root: parent.widget.root,
    rootFlyout: parent.widget.rootFlyout,
    menuKey: parent.widget.menuKey,
    additionalOffset: parent.additionalOffset,
    margin: parent.margin,
    transitionDuration: parent.transitionDuration,
    reverseTransitionDuration: parent.reverseTransitionDuration,
    placementMode: parent.placementMode,
    transitionBuilder: (context, animation, placement, flyout) {
      // Submenus inherit the nearest MenuFlyout's appearance. The inner root
      // below adds no frame or shadow because MenuBar already supplies its chrome;
      // restore that original appearance on each real descendant popup while
      // retaining its actual key and items for the official close-key chain.
      final menu = flyout as MenuFlyout;
      return parent.transitionBuilder(
        context,
        animation,
        placement,
        _menuScope(
          MenuFlyout(
            key: menu.key,
            items: menu.items,
            constraints: menu.constraints,
            itemMargin: menu.itemMargin,
            color: appearance.color,
            shape: appearance.shape,
            shadowColor: appearance.shadowColor,
            elevation: appearance.elevation,
          ),
        ),
      );
    },
    builder: (_) => _menuScope(
      MenuFlyout(
        items: items,
        color: appearance.color ?? FluentTheme.of(context).menuColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(),
      ),
    ),
  );
}

class _WindowsMenuBar extends StatefulWidget {
  const _WindowsMenuBar({required this.menus});
  final List<DesktopMenu> menus;

  @override
  State<_WindowsMenuBar> createState() => _WindowsMenuBarState();
}

class _WindowsMenuBarState extends State<_WindowsMenuBar> {
  final menuBar = GlobalKey<MenuBarState>();
  // Fluent associates controllers and opening animations with root item identity.
  // Keep those roots through ordinary workbench rebuilds; resolve live commands
  // from the current widget when each popup is constructed.
  final rootItems = <int, MenuBarItem>{};

  MenuBarItem rootItem(int index) {
    final title = widget.menus[index].label;
    final existing = rootItems[index];
    if (existing != null && existing.title == title) return existing;
    return rootItems[index] = MenuBarItem(
      title: title,
      items: [
        MenuFlyoutItemBuilder(
          builder: (_) => Builder(
            builder: (context) {
              if (index >= widget.menus.length ||
                  widget.menus[index].label != title) {
                return const SizedBox.shrink();
              }
              return _menuBarGroup(context, items(widget.menus[index]));
            },
          ),
        ),
      ],
    );
  }

  List<MenuFlyoutItemBase> items(DesktopMenu menu) => [
    for (final action in menu.actions)
      MenuFlyoutItem(
        text: _menuItemLabel(
          action.label,
          enabled: action.disabledReason == null,
          checked: action.checked,
        ),
        trailing: action.shortcut == null ? null : Text(action.shortcut!),
        closeAfterClick: false,
        onPressed: action.disabledReason == null
            ? () {
                final current = menuBar.currentState;
                if (!mounted || current == null) return;
                current.closeFlyout();
                action.invoke();
              }
            : null,
      ),
    for (final child in menu.children)
      MenuFlyoutSubItem(
        text: _menuItemLabel(child.label),
        items: (_) => items(child),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    rootItems.removeWhere((index, _) => index >= widget.menus.length);
    return _menuScope(
      MenuBar(
        key: menuBar,
        overflowBehavior: MenuBarOverflowBehavior.scroll,
        items: [
          for (var index = 0; index < widget.menus.length; index++)
            rootItem(index),
        ],
      ),
      bar: true,
    );
  }
}

class WindowsControls extends DesktopControls {
  const WindowsControls();
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
  }) => _WindowsTabInteraction(
    controls: this,
    onPressed: onPressed,
    focusNode: focusNode,
    onFocusChange: onFocusChange,
    selected: selected,
    hovered: hovered,
    child: child,
  );
  @override
  DesktopMenuPresenter createMenuPresenter() => _WindowsMenuPresenter();
  @override
  Widget tooltip(String message, Widget child) => _WindowsTooltipAnchor(
    message: message,
    excludeFromSemantics: true,
    child: child,
  );
  @override
  Widget contextMenu(Widget child, List<DesktopMenuAction> actions) =>
      _WindowsContextMenu(actions: actions, child: child);
  List<MenuFlyoutItemBase> _items(List<DesktopMenuAction> actions) => [
    for (final action in actions)
      MenuFlyoutItemBuilder(
        builder: (context) => MenuFlyoutItem(
          text: _menuItemLabel(
            action.label,
            enabled: action.disabledReason == null,
            checked: action.checked,
          ),
          trailing: action.shortcut == null ? null : Text(action.shortcut!),
          closeAfterClick: false,
          onPressed: action.disabledReason == null
              ? () {
                  // Retire this route before an action can push its dialog.
                  // An unawaited maybePop can leave the flyout beneath it.
                  Flyout.of(context).close();
                  action.invoke();
                }
              : null,
        ).build(context),
      ),
  ];
  @override
  Widget splitButton(
    String label,
    VoidCallback? action,
    String optionsLabel,
    List<DesktopMenuAction> options,
  ) => SplitButton(
    onInvoked: action,
    secondaryBuilder: (context, show, controller) => FlyoutTarget(
      controller: controller,
      child: _WindowsTooltipAnchor(
        message: optionsLabel,
        excludeFromSemantics: true,
        child: MergeSemantics(
          child: Semantics(
            label: optionsLabel,
            child: IconButton(
              icon: const Icon(FluentIcons.chevron_down, size: 10),
              onPressed: show,
            ),
          ),
        ),
      ),
    ),
    flyout: _menuScope(MenuFlyout(items: _items(options))),
    child: Padding(padding: kDefaultButtonPadding, child: Text(label)),
  );
  @override
  Widget iconMenu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  }) => _menuDropDown(
    buttonBuilder: (context, open) =>
        iconButton(DesktopIcon.more, label, open, compact: compact),
    items: _items(actions),
  );
  @override
  Widget menuBar(List<DesktopMenu> menus) => _WindowsMenuBar(menus: menus);
  @override
  Widget menu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  }) => actions.isEmpty
      ? textButton(label, null)
      : _menuDropDown(
          title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          buttonBuilder: (context, open) => HyperlinkButton(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.isDisabled
                    ? FluentTheme.of(context).resources.textFillColorDisabled
                    : FluentTheme.of(context).typography.body!.color,
              ),
            ),
            onPressed: open,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(FluentIcons.chevron_down, size: 10),
              ],
            ),
          ),
          items: _items(actions),
        );
  @override
  Widget icon(DesktopIcon icon, {double size = 16}) => Icon(switch (icon) {
    DesktopIcon.add => glyphs.FluentIcons.add_16_regular,
    DesktopIcon.close => glyphs.FluentIcons.dismiss_16_regular,
    DesktopIcon.expand => glyphs.FluentIcons.chevron_right_16_regular,
    DesktopIcon.collapse => glyphs.FluentIcons.chevron_down_16_regular,
    DesktopIcon.connection => glyphs.FluentIcons.database_16_regular,
    DesktopIcon.table => glyphs.FluentIcons.table_16_regular,
    DesktopIcon.view => glyphs.FluentIcons.table_16_regular,
    DesktopIcon.routine => glyphs.FluentIcons.code_16_regular,
    DesktopIcon.column => glyphs.FluentIcons.column_20_regular,
    DesktopIcon.sequence => FluentIcons.number_sequence,
    DesktopIcon.folder => glyphs.FluentIcons.folder_16_regular,
    DesktopIcon.query => glyphs.FluentIcons.code_16_regular,
    DesktopIcon.copy => glyphs.FluentIcons.copy_16_regular,
    DesktopIcon.tool => glyphs.FluentIcons.wrench_16_regular,
    DesktopIcon.sidebar => glyphs.FluentIcons.panel_left_16_regular,
    DesktopIcon.more => glyphs.FluentIcons.more_horizontal_16_regular,
    DesktopIcon.search => glyphs.FluentIcons.search_16_regular,
    DesktopIcon.refresh => glyphs.FluentIcons.arrow_sync_16_regular,
    DesktopIcon.running => glyphs.FluentIcons.hourglass_16_regular,
    DesktopIcon.warning => glyphs.FluentIcons.warning_16_regular,
    DesktopIcon.transaction => glyphs.FluentIcons.arrow_swap_20_regular,
    DesktopIcon.dirty => glyphs.FluentIcons.circle_12_filled,
    DesktopIcon.connected => FluentIcons.plug_connected,
    DesktopIcon.disconnected => FluentIcons.plug_disconnected,
    DesktopIcon.favorite => glyphs.FluentIcons.star_16_regular,
    DesktopIcon.settings => glyphs.FluentIcons.settings_16_regular,
    DesktopIcon.privacy => glyphs.FluentIcons.shield_16_regular,
    DesktopIcon.keyboard => glyphs.FluentIcons.keyboard_16_regular,
    DesktopIcon.appearance => glyphs.FluentIcons.paint_brush_16_regular,
    DesktopIcon.language => glyphs.FluentIcons.translate_16_regular,
    DesktopIcon.history => glyphs.FluentIcons.history_16_regular,
  }, size: size);
  @override
  Widget iconButton(
    DesktopIcon value,
    String label,
    VoidCallback? action, {
    bool compact = false,
  }) => _WindowsTooltipAnchor(
    message: label,
    excludeFromSemantics: true,
    child: MergeSemantics(
      child: Semantics(
        label: label,
        child: IconButton(
          icon: icon(value),
          onPressed: action,
          style: compact
              ? ButtonStyle(
                  padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
                )
              : null,
        ),
      ),
    ),
  );
  @override
  Widget textButton(
    String label,
    VoidCallback? action, {
    bool compact = false,
  }) => Builder(
    builder: (context) => HyperlinkButton(
      onPressed: action,
      style: ButtonStyle(
        padding: compact
            ? const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              )
            : null,
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? FluentTheme.of(context).resources.textFillColorDisabled
              : FluentTheme.of(context).typography.body?.color,
        ),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
  @override
  Widget filterField(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
    bool autofocus = false,
    bool clearOnEscape = true,
    ValueChanged<String>? onChanged,
  }) => _WindowsSearchEntry(
    controller: controller,
    label: label,
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
        builder: (context) {
          final resources = FluentTheme.of(context).resources;
          return FilledButton(
            onPressed: action,
            focusNode: focusNode,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? resources.controlFillColorDisabled
                    : resources.systemFillColorCritical,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.disabled)
                    ? resources.textFillColorDisabled
                    : resources.textOnAccentFillColorPrimary,
              ),
            ),
            child: Text(label),
          );
        },
      );
    }
    return primary
        ? FilledButton(
            onPressed: action,
            focusNode: focusNode,
            child: Text(label),
          )
        : Button(onPressed: action, focusNode: focusNode, child: Text(label));
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
  }) {
    final input = secret && Platform.isWindows
        ? WindowsSecretField(
            controller: controller,
            label: label,
            focusNode: focusNode,
            enabled: enabled,
            readOnly: readOnly,
            technical: technical,
            hasTrailing: trailing != null,
            hint: errorText,
          )
        : MergeSemantics(
            child: Semantics(
              label: label,
              hint: errorText,
              child: TextBox(
                controller: controller,
                focusNode: focusNode,
                obscureText: secret,
                readOnly: readOnly,
                textDirection: technical ? TextDirection.ltr : null,
                autocorrect: !secret && !technical,
                enableSuggestions: !secret && !technical,
                // TextBox merges its suffix semantics into the editor. Reserve the
                // native icon allocation and overlay the independent browse action.
                suffix: trailing == null ? null : const SizedBox(width: 38),
                enabled: enabled,
              ),
            ),
          );
    final field = trailing == null
        ? input
        : Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              input,
              PositionedDirectional(
                end: 0,
                child: ExcludeFocus(
                  excluding: !enabled,
                  child: IgnorePointer(ignoring: !enabled, child: trailing),
                ),
              ),
            ],
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: showLabel ? InfoLabel(label: label, child: field) : field,
    );
  }

  @override
  Widget multilineField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
    bool expands = false,
  }) => MergeSemantics(
    child: Semantics(
      label: label,
      child: TextBox(
        controller: controller,
        focusNode: focusNode,
        minLines: expands ? null : 6,
        maxLines: expands ? null : 20,
        expands: expands,
        autocorrect: false,
        enableSuggestions: false,
      ),
    ),
  );

  @override
  Widget inlineField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
  }) => Builder(
    builder: (context) => MergeSemantics(
      child: Semantics(
        label: label,
        child: TextBox(
          controller: controller,
          focusNode: focusNode,
          autofocus: true,
          padding: EdgeInsets.zero,
          style: appearance(context).body,
          decoration: const WidgetStatePropertyAll(BoxDecoration()),
        ),
      ),
    ),
  );

  @override
  Widget comboRow<T>(
    String title,
    T value,
    Map<T, String> values,
    ValueChanged<T> changed, {
    bool enabled = true,
  }) => Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ExcludeSemantics(
            child: Text(title, style: FluentTheme.of(context).typography.body),
          ),
        ),
        choice(value, values, changed, label: title, enabled: enabled),
      ],
    ),
  );

  @override
  Widget choice<T>(
    T value,
    Map<T, String> choices,
    ValueChanged<T> changed, {
    String? label,
    bool enabled = true,
  }) => LayoutBuilder(
    builder: (context, bounds) {
      final control = ComboBox<T>(
        value: value,
        isExpanded: bounds.hasBoundedWidth,
        items: choices.entries
            .map(
              (e) => ComboBoxItem(
                value: e.key,
                child: Text(
                  e.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: enabled
            ? (v) {
                if (v != null) changed(v);
              }
            : null,
      );
      // The tooltip overlay refers to its semantic anchor. Keep that boundary
      // outside the label/value merge so its traversal parent remains exposed.
      return _WindowsTooltipAnchor(
        message: choices[value]!,
        excludeFromSemantics: true,
        child: label == null
            ? control
            : MergeSemantics(
                child: Semantics(label: label, child: control),
              ),
      );
    },
  );

  @override
  double choiceWidth(BuildContext context, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: FluentTheme.of(context).typography.body,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // Pinned Fluent ComboBox: aligned horizontal padding 11+15,
    // arrow 12 and its leading space 8.
    final width = painter.width + 26 + 12 + 8;
    painter.dispose();
    return width.ceilToDouble();
  }

  @override
  Widget checkbox(
    String label,
    bool value,
    ValueChanged<bool>? changed,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final margin = CheckboxTheme.of(
        context,
      ).margin?.resolve(Directionality.of(context));
      // The pinned Fluent Checkbox reserves 20 logical pixels for its box
      // and 8 for the content gap. Its content receives unconstrained width;
      // bound our label so native focus, activation and semantics stay intact.
      final width = constraints.hasBoundedWidth
          ? (constraints.maxWidth - 28 - (margin?.horizontal ?? 0)).clamp(
              0.0,
              double.infinity,
            )
          : double.infinity;
      return Checkbox(
        checked: value,
        onChanged: changed == null ? null : (v) => changed(v ?? false),
        content: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width),
          child: Text(label),
        ),
      );
    },
  );
  @override
  Widget surface(Widget child) => Card(child: child);
  @override
  Future<T?> formDialog<T>(BuildContext context, WidgetBuilder builder) =>
      _showWorkbenchFluentDialog<T>(context, builder);

  @override
  Widget formShell(
    String title,
    Widget body,
    List<Widget> actions, {
    bool scrollBody = true,
    double maxWidth = 760,
  }) => Semantics(
    container: true,
    explicitChildNodes: true,
    scopesRoute: true,
    namesRoute: true,
    role: SemanticsRole.dialog,
    label: title,
    child: ContentDialog(
      title: Semantics(container: true, header: true, child: Text(title)),
      constraints: BoxConstraints(maxWidth: maxWidth),
      content: scrollBody ? SingleChildScrollView(child: body) : body,
      actions: [
        OverflowBar(
          spacing: 8,
          overflowSpacing: 8,
          alignment: MainAxisAlignment.end,
          children: actions,
        ),
      ],
    ),
  );
  @override
  Future<T?> dialog<T>(
    BuildContext context,
    String title,
    Widget body,
    List<Widget> actions, {
    bool bodyScrolls = false,
  }) => _showWorkbenchFluentDialog<T>(
    context,
    (_) => Semantics(
      container: true,
      explicitChildNodes: true,
      scopesRoute: true,
      namesRoute: true,
      role: SemanticsRole.dialog,
      label: title,
      child: ContentDialog(
        title: Semantics(container: true, header: true, child: Text(title)),
        constraints: const BoxConstraints(maxWidth: 700),
        content: SizedBox(width: 600, child: body),
        actions: actions,
      ),
    ),
  );

  @override
  DesktopAppearance appearance(BuildContext context) {
    final theme = FluentTheme.of(context),
        r = FluentTheme.of(context).resources;
    final body = theme.typography.body!;
    final contrast = MediaQuery.highContrastOf(context);
    final view = r.solidBackgroundFillColorSecondary;
    return DesktopAppearance(
      window: theme.scaffoldBackgroundColor,
      view: view,
      sidebar: r.solidBackgroundFillColorBase,
      header: r.solidBackgroundFillColorTertiary,
      dialog: r.solidBackgroundFillColorSecondary,
      popover: r.solidBackgroundFillColorSecondary,
      foreground: r.textFillColorPrimary,
      secondaryForeground: r.textFillColorSecondary,
      disabledForeground: r.textFillColorDisabled,
      hover: Color.alphaBlend(r.subtleFillColorSecondary, view),
      pressed: Color.alphaBlend(r.subtleFillColorTertiary, view),
      selected: theme.accentColor,
      selectedForeground: r.textOnAccentFillColorSelectedText,
      unfocusedSelection: Color.alphaBlend(
        r.controlAltFillColorQuarternary,
        view,
      ),
      unfocusedSelectionForeground: r.textFillColorPrimary,
      separator: r.dividerStrokeColorDefault,
      gridLine: r.dividerStrokeColorDefault,
      controlBorder: r.controlStrokeColorDefault,
      focus: r.focusStrokeColorOuter,
      success: r.systemFillColorSuccess,
      warning: r.systemFillColorCaution,
      error: r.systemFillColorCritical,
      unknown: r.systemFillColorNeutral,
      staged: Color.alphaBlend(r.systemFillColorCautionBackground, view),
      stagedForeground: r.textFillColorPrimary,
      textSelection: Color.alphaBlend(
        theme.accentColor.withValues(alpha: .25),
        view,
      ),
      body: body,
      heading: body.copyWith(fontWeight: FontWeight.w600),
      caption: theme.typography.caption!.copyWith(
        color: r.textFillColorSecondary,
      ),
      technical: body.copyWith(fontFamily: 'monospace'),
      highContrast: contrast,
    );
  }

  @override
  Color background(BuildContext context) =>
      FluentTheme.of(context).scaffoldBackgroundColor;
  @override
  Color foreground(BuildContext context) =>
      FluentTheme.of(context).typography.body!.color!;
  @override
  Color accent(BuildContext context) => FluentTheme.of(context).accentColor;
  @override
  TextStyle textStyle(BuildContext context) =>
      FluentTheme.of(context).typography.body!;
}

class _WindowsTabInteraction extends StatefulWidget {
  const _WindowsTabInteraction({
    required this.controls,
    required this.child,
    required this.onPressed,
    this.focusNode,
    this.onFocusChange,
    required this.selected,
    required this.hovered,
  });
  final WindowsControls controls;
  final Widget child;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final ValueChanged<bool>? onFocusChange;
  final bool selected, hovered;
  @override
  State<_WindowsTabInteraction> createState() => _WindowsTabInteractionState();
}

class _WindowsTabInteractionState extends State<_WindowsTabInteraction> {
  bool showFocus = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    focusNode: widget.focusNode,
    onFocusChange: widget.onFocusChange,
    onShowFocusHighlight: (value) => setState(() => showFocus = value),
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onPressed();
          return null;
        },
      ),
    },
    child: FocusBorder(
      focused: showFocus,
      renderOutside: false,
      child: ColoredBox(
        color: widget.controls.tabBackground(
          context,
          widget.selected,
          widget.hovered,
        ),
        child: GestureDetector(onTap: widget.onPressed, child: widget.child),
      ),
    ),
  );
}

class _WindowsSearchEntry extends StatefulWidget {
  const _WindowsSearchEntry({
    required this.controller,
    required this.label,
    this.focusNode,
    required this.autofocus,
    required this.clearOnEscape,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final FocusNode? focusNode;
  final bool autofocus, clearOnEscape;
  final ValueChanged<String>? onChanged;
  @override
  State<_WindowsSearchEntry> createState() => _WindowsSearchEntryState();
}

class _WindowsSearchEntryState extends State<_WindowsSearchEntry> {
  final localFocus = FocusNode(debugLabel: 'Workbench search');
  FocusNode get focus => widget.focusNode ?? localFocus;
  void clear() {
    if (widget.controller.text.isEmpty) return;
    widget.controller.clear();
    widget.onChanged?.call('');
    focus.requestFocus();
  }

  @override
  void dispose() {
    localFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) => Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (widget.clearOnEscape &&
                value.text.isNotEmpty &&
                event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              clear();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            alignment: AlignmentDirectional.centerEnd,
            children: [
              MergeSemantics(
                child: Semantics(
                  label: value.text.isEmpty ? null : widget.label,
                  child: TextBox(
                    controller: widget.controller,
                    focusNode: focus,
                    autofocus: widget.autofocus,
                    onChanged: widget.onChanged,
                    placeholder: widget.label,
                    prefix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: const WindowsControls().icon(DesktopIcon.search),
                    ),
                    suffix: value.text.isEmpty
                        ? null
                        : const SizedBox(width: 38),
                  ),
                ),
              ),
              if (value.text.isNotEmpty)
                PositionedDirectional(
                  end: 0,
                  child: const WindowsControls().iconButton(
                    DesktopIcon.close,
                    strings(context).clear,
                    clear,
                    compact: true,
                  ),
                ),
            ],
          ),
        ),
      );
}

class _WindowsContextMenu extends StatefulWidget {
  const _WindowsContextMenu({required this.child, required this.actions});
  final Widget child;
  final List<DesktopMenuAction> actions;
  @override
  State<_WindowsContextMenu> createState() => _WindowsContextMenuState();
}

class _WindowsContextMenuState extends State<_WindowsContextMenu> {
  final controller = FlyoutController();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void open(Offset position) => controller.showFlyout(
    position: position,
    builder: (context) => _menuScope(
      MenuFlyout(
        items: [
          for (final action in widget.actions)
            MenuFlyoutItem(
              text: _menuItemLabel(
                action.label,
                enabled: action.disabledReason == null,
                checked: action.checked,
              ),
              trailing: action.shortcut == null ? null : Text(action.shortcut!),
              closeAfterClick: false,
              onPressed: action.disabledReason == null
                  ? () async {
                      final route = ModalRoute.of(context)!;
                      if (!route.isCurrent) return;
                      Flyout.of(context).close();
                      // Retire the menu and restore the underlying semantics
                      // before a command replaces a document or opens a dialog.
                      await route.completed;
                      await WidgetsBinding.instance.endOfFrame;
                      if (mounted) action.invoke();
                    }
                  : null,
            ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => FlyoutTarget(
    controller: controller,
    child: Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.contextMenu ||
                event.logicalKey == LogicalKeyboardKey.f10 &&
                    HardwareKeyboard.instance.isShiftPressed &&
                    !HardwareKeyboard.instance.isControlPressed &&
                    !HardwareKeyboard.instance.isAltPressed &&
                    !HardwareKeyboard.instance.isMetaPressed)) {
          final box = context.findRenderObject() as RenderBox?;
          if (box != null) open(box.localToGlobal(Offset(0, box.size.height)));
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onSecondaryTapUp: (event) => open(event.globalPosition),
        child: widget.child,
      ),
    ),
  );
}

class _WindowsMenuPresenter extends DesktopMenuPresenter {
  final _controller = FlyoutController();
  BuildContext? _menuContext;
  Object? _focusOwner;
  @override
  bool ownsFocus(FocusNode? focus) {
    final context = _menuContext;
    if (context?.mounted != true || focus?.context == null) return false;
    final route = ModalRoute.of(context!);
    return route != null &&
        route.isCurrent &&
        identical(ModalRoute.of(focus!.context!), route);
  }

  @override
  Widget anchor(Widget child) =>
      FlyoutTarget(controller: _controller, child: child);
  @override
  Future<int?> show(
    BuildContext context,
    Offset position,
    List<DesktopMenuAction> actions, {
    bool keyboard = false,
  }) async {
    final owner = Object();
    _focusOwner = owner;
    try {
      return await _controller.showFlyout<int>(
        position: position,
        builder: (context) {
          if (identical(_focusOwner, owner)) _menuContext = context;
          return _menuScope(
            MenuFlyout(
              items: [
                for (final (i, action) in actions.indexed)
                  MenuFlyoutItem(
                    text: _menuItemLabel(
                      action.label,
                      enabled: action.disabledReason == null,
                      checked: action.checked,
                    ),
                    closeAfterClick: false,
                    trailing: action.shortcut == null
                        ? null
                        : Text(action.shortcut!),
                    onPressed: action.disabledReason == null
                        ? () => _controller.close<int>(i)
                        : null,
                  ),
              ],
            ),
          );
        },
      );
    } finally {
      if (identical(_focusOwner, owner)) {
        _focusOwner = null;
        _menuContext = null;
      }
    }
  }

  @override
  Future<void> dismiss() async {
    if (_controller.isOpen) _controller.close();
  }

  @override
  void dispose() {
    _focusOwner = null;
    _menuContext = null;
    _controller.dispose();
  }
}

// Keep tooltip traversal anchors distinct from surrounding control semantics.
class _WindowsTooltipAnchor extends StatelessWidget {
  const _WindowsTooltipAnchor({
    required this.message,
    required this.child,
    this.excludeFromSemantics = false,
  });
  final String message;
  final Widget child;
  final bool excludeFromSemantics;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    child: Tooltip(
      message: Platform.isWindows ? null : message,
      richMessage: Platform.isWindows
          ? WindowsSecretTooltipSpan(
              message,
              style: TooltipTheme.of(context).textStyle,
            )
          : null,
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    ),
  );
}
