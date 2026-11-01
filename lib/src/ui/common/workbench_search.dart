import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/workspace/workbench_commands.dart';

import 'desktop_controls.dart';
import 'workbench_presentation.dart';
import 'modal_command_boundary.dart';
import '../../l10n/workbench_strings.dart';

class SearchResultList extends StatefulWidget {
  const SearchResultList({
    super.key,
    required this.registry,
    required this.target,
    required this.controls,
    required this.select,
    this.contextChanges,
    this.disabledReason,
    required this.query,
    required this.queryFocus,
    required this.close,
  });
  final WorkbenchCommandRegistry registry;
  final WorkbenchCommandContext target;
  final DesktopControls controls;
  final ValueChanged<String> select;
  final Listenable? contextChanges;
  final String? Function(WorkbenchCommand command)? disabledReason;
  final TextEditingController query;
  final FocusNode queryFocus;
  final VoidCallback close;
  @override
  State<SearchResultList> createState() => SearchResultListState();
}

class SearchResultListState extends State<SearchResultList> {
  TextEditingController get query => widget.query;
  final scroll = ScrollController();
  FocusNode get queryFocus => widget.queryFocus;
  int selected = 0;
  final viewportKey = GlobalKey();
  final rowKeys = <String, GlobalKey<WorkbenchRecordState>>{};
  Size? viewportSize;
  List<(String, String?)> presentation = [];
  List<WorkbenchCommand> get matches {
    final matches = widget.registry.search(query.text, widget.target);
    if (query.text.trim().isNotEmpty) return matches;
    final groups = <String, List<WorkbenchCommand>>{};
    for (final command in matches) {
      (groups[command.category] ??= []).add(command);
    }
    return [for (final group in groups.values) ...group];
  }

  String? reason(WorkbenchCommand command) =>
      widget.disabledReason?.call(command) ??
      command.disabledReason?.call(widget.target);
  @override
  void initState() {
    super.initState();
    queryFocus.addListener(focusChanged);
    query.addListener(queryChanged);
    presentation = currentPresentation();
    widget.contextChanges?.addListener(contextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) queryFocus.requestFocus();
    });
  }

  void queryChanged() {
    setState(() => selected = 0);
    presentation = currentPresentation();
    revealSelection();
  }

  void focusChanged() {
    if (mounted) setState(() {});
  }

  List<(String, String?)> currentPresentation() => [
    for (final command in matches) (command.id, reason(command)),
  ];

  void contextChanged() {
    final current = currentPresentation();
    if (listEquals(current, presentation)) return;
    setState(() {
      presentation = current;
      selected = selected.clamp(0, current.isEmpty ? 0 : current.length - 1);
    });
    revealSelection();
  }

  @override
  void didUpdateWidget(covariant SearchResultList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.contextChanges, widget.contextChanges)) {
      oldWidget.contextChanges?.removeListener(contextChanged);
      widget.contextChanges?.addListener(contextChanged);
    }
    presentation = currentPresentation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    revealSelection();
  }

  @override
  void dispose() {
    widget.contextChanges?.removeListener(contextChanged);
    query.removeListener(queryChanged);
    queryFocus.removeListener(focusChanged);
    scroll.dispose();

    super.dispose();
  }

  void move(int delta) {
    if (matches.isEmpty) return;
    final rowFocus = !queryFocus.hasFocus;
    setState(() => selected = (selected + delta) % matches.length);
    revealSelection(takeFocus: rowFocus);
  }

  void revealSelection({bool takeFocus = false}) {
    final focusOwner = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || matches.isEmpty || selected >= matches.length) return;
      final rowContext = rowKeys[matches[selected].id]?.currentContext;
      final viewport = viewportKey.currentContext?.findRenderObject();
      final row = rowContext?.findRenderObject();
      if (rowContext == null ||
          row is! RenderBox ||
          viewport is! RenderBox ||
          !row.hasSize ||
          !viewport.hasSize) {
        return;
      }
      final rowBounds = row.localToGlobal(Offset.zero) & row.size;
      if (takeFocus &&
          identical(FocusManager.instance.primaryFocus, focusOwner)) {
        rowKeys[matches[selected].id]?.currentState?.requestFocus();
      }
      final viewportBounds =
          viewport.localToGlobal(Offset.zero) & viewport.size;
      if (rowBounds.top >= viewportBounds.top &&
          rowBounds.bottom <= viewportBounds.bottom) {
        return;
      }
      Scrollable.ensureVisible(
        rowContext,
        alignment:
            rowBounds.height > viewportBounds.height ||
                rowBounds.top < viewportBounds.top
            ? 0
            : 1,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 80),
        curve: Curves.linear,
      );
    });
  }

  void activateSelection() {
    if (matches.isEmpty || selected >= matches.length) return;
    final command = matches[selected];
    if (reason(command) == null) {
      widget.select(command.id);
    }
  }

  Widget buildRow(int i, WorkbenchCommand command) {
    final reason = this.reason(command);
    return WorkbenchRecord(
      key: rowKeys.putIfAbsent(command.id, GlobalKey.new),
      controls: widget.controls,
      leading: DesktopIcon.keyboard,
      onFocusChange: (focused) {
        if (focused) setState(() => selected = i);
      },
      label:
          '${command.category} · ${command.label}${command.shortcutLabel == null ? '' : '   ${command.shortcutLabel}'}${reason == null ? '' : ' · $reason'}',
      selected: i == selected,
      selectionFocused: queryFocus.hasFocus ? true : null,
      onPressed: reason == null ? () => widget.select(command.id) : null,
      child: LayoutBuilder(
        builder: (context, bounds) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(command.label),
                  if (reason != null || query.text.trim().isNotEmpty)
                    Text(
                      reason ?? command.category,
                      style: widget.controls.appearance(context).caption,
                    ),
                ],
              ),
            ),
            if (command.shortcutLabel != null) ...[
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: widget.controls.shortcutBadge(command.shortcutLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: (_, event) {
      if (event is! KeyDownEvent || query.value.composing.isValid) {
        return KeyEventResult.ignored;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        move(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        move(-1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        widget.close();
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.enter &&
          matches.isNotEmpty &&
          selected < matches.length) {
        final command = matches[selected];
        if (reason(command) == null) {
          widget.select(command.id);
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              if (viewportSize != size) {
                viewportSize = size;
                revealSelection();
              }
              // The bounded registry keeps these temporary measured rows small.
              // Native wrapping and text scaling determine the scroll distance.
              return SingleChildScrollView(
                key: viewportKey,
                controller: scroll,
                padding: widget.controls.sidebarListPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(strings(context).searchNoResults),
                      ),
                    for (final (i, command) in matches.indexed) ...[
                      if (query.text.trim().isEmpty &&
                          (i == 0 ||
                              matches[i - 1].category != command.category))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                          child: Text(
                            command.category,
                            style: widget.controls.appearance(context).caption,
                          ),
                        ),
                      buildRow(i, command),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

/// BusyMark's single header query and sidebar category/result hierarchy.
class SearchHeaderField extends StatelessWidget {
  const SearchHeaderField({
    super.key,
    required this.controls,
    required this.query,
    required this.focusNode,
    required this.close,
    required this.submit,
    required this.move,
    required this.hint,
  });
  final DesktopControls controls;
  final TextEditingController query;
  final FocusNode focusNode;
  final VoidCallback close, submit;
  final ValueChanged<int> move;
  final String hint;
  @override
  Widget build(BuildContext context) => WorkbenchLocalInputBoundary(
    child: controls.searchField(
      query,
      hint,
      focusNode: focusNode,
      submit: submit,
      close: close,
      move: move,
    ),
  );
}

class SearchSidebar extends StatelessWidget {
  const SearchSidebar({
    super.key,
    required this.controls,
    required this.child,
    required this.category,
    required this.categories,
    required this.selectCategory,
    required this.close,
    required this.move,
    required this.submit,
  });
  final String category;
  final Map<String, String> categories;
  final ValueChanged<String> selectCategory;
  final VoidCallback close;
  final ValueChanged<int> move;
  final VoidCallback submit;
  final DesktopControls controls;
  final Widget child;
  @override
  Widget build(BuildContext context) => WorkbenchLocalInputBoundary(
    child: Focus(
      onKeyEvent: (_, event) {
        final primary = FocusManager.instance.primaryFocus;
        final editing = primary?.context
            ?.findAncestorStateOfType<EditableTextState>();
        final record = primary?.context
            ?.findAncestorStateOfType<WorkbenchRecordState>();
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            editing?.widget.controller.value.composing.isValid != true) {
          close();
          return KeyEventResult.handled;
        }
        if (event is KeyDownEvent &&
            editing == null &&
            record != null &&
            identical(record.node, primary) &&
            !HardwareKeyboard.instance.isControlPressed &&
            !HardwareKeyboard.instance.isAltPressed &&
            !HardwareKeyboard.instance.isMetaPressed) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
              event.logicalKey == LogicalKeyboardKey.arrowUp) {
            move(event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.enter) {
            submit();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                controls.icon(DesktopIcon.search),
                const SizedBox(width: 4),
                Text(strings(context).search),
                const SizedBox(width: 4),
                Expanded(
                  child: controls.choice(
                    categories.containsKey(category) ? category : 'actions',
                    categories,
                    selectCategory,
                    label: strings(context).search,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
