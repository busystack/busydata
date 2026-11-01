import 'dart:convert';
import 'package:flutter/material.dart'
    show AdaptiveTextSelectionToolbar, SelectableText;
import 'package:flutter/widgets.dart';
import '../../features/results/hexadecimal_display.dart';
import '../../features/results/text_value_draft.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';

/// A bounded native text field over an already bounded represented scope.
/// The complete string remains owned by its caller; paging changes no extractor,
/// retained value, selection, clipboard operation, or database operation.
class PagedSelectableText extends StatefulWidget {
  const PagedSelectableText({
    super.key,
    required this.controls,
    required this.text,
    this.padding = const EdgeInsets.all(8),
    this.pageUnits = textValuePageUnits,
  });
  final DesktopControls controls;
  final String text;
  final EdgeInsetsGeometry padding;
  final int pageUnits;
  @override
  State<PagedSelectableText> createState() => _PagedSelectableTextState();
}

class _PagedSelectableTextState extends State<PagedSelectableText> {
  static const representedUnits = 2097152;
  final starts = <int>[0];
  final nativeFocus = FocusNode(skipTraversal: true);
  final toolbarFocus = FocusScopeNode(
    traversalEdgeBehavior: TraversalEdgeBehavior.parentScope,
  );
  int page = 0;
  bool base64View = false;
  String represented = '';
  bool get containsNul => widget.text.contains('\u0000');
  @override
  void initState() {
    super.initState();
    nativeFocus.addListener(dismissUnfocusedToolbar);
    index();
  }

  @override
  void didUpdateWidget(covariant PagedSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.pageUnits != widget.pageUnits) {
      index();
    }
  }

  void index() {
    if (widget.pageUnits < 2 || widget.pageUnits > textValuePageUnits) {
      throw ArgumentError.value(widget.pageUnits, 'pageUnits');
    }
    resetNativePage();
    starts
      ..clear()
      ..add(0);
    page = 0;
    represented = widget.text;
    if (widget.text.length > representedUnits) return;
    if (containsNul) {
      final bytes = utf8.encode(widget.text);
      if (bytes.length > representedUnits ~/ 2) {
        represented = '';
        return;
      }
      represented = base64View ? base64Encode(bytes) : encodeHexDisplay(bytes);
    }
    while (starts.last < represented.length) {
      final end = textValuePageEnd(
        represented,
        starts.last,
        maxUnits: widget.pageUnits,
      );
      if (end == represented.length) break;
      starts.add(end);
    }
  }

  /// Resolve only the mounted field attached to this page owner's focus node.
  EditableTextState? get nativeField {
    final native = nativeFocus.context
        ?.findAncestorStateOfType<EditableTextState>();
    if (native == null ||
        !native.mounted ||
        !identical(native.widget.focusNode, nativeFocus)) {
      return null;
    }
    return native;
  }

  void dismissUnfocusedToolbar() {
    if (!nativeFocus.hasFocus) nativeField?.hideToolbar();
  }

  Widget buildToolbar(BuildContext context, EditableTextState native) =>
      FocusScope(
        node: toolbarFocus,
        parentNode: nativeFocus,
        child: AdaptiveTextSelectionToolbar.editableText(
          editableTextState: native,
        ),
      );

  /// Reset before replacing the page, retaining native render/gesture owners.
  /// Only public EditableText APIs are used, with no deferred reset or special
  /// case for adjacent equal-text pages.
  void resetNativePage() {
    final native = nativeField;
    if (native == null) return; // This owner has no mounted native field yet.
    native.hideToolbar();
    if (nativeFocus.hasFocus) {
      nativeFocus.unfocus(
        disposition: UnfocusDisposition.previouslyFocusedChild,
      );
    }
    native.widget.controller.selection = const TextSelection.collapsed(
      offset: 0,
    );
    final viewport = native.context.findRenderObject();
    if (viewport is RenderBox && viewport.hasSize) {
      native.bringIntoView(const TextPosition(offset: 0));
    }
  }

  void movePage(int direction) {
    final next = page + direction;
    if (!mounted || next < 0 || next >= starts.length) return;
    resetNativePage();
    setState(() => page = next);
  }

  @override
  void dispose() {
    nativeFocus.removeListener(dismissUnfocusedToolbar);
    toolbarFocus.dispose();
    nativeFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = strings(context);
    if (widget.text.length > representedUnits ||
        containsNul && represented.isEmpty) {
      return widget.controls.status(l.presentationScopeLimit);
    }
    final start = starts[page];
    final end = page + 1 < starts.length
        ? starts[page + 1]
        : represented.length;
    // Keep the native read-only field inside the actual viewport. An outer
    // vertical scroll view would give RenderEditable unbounded height, disabling
    // its own text scrolling and viewport clipping for the complete page.
    final content = Padding(
      padding: widget.padding,
      child: SelectableText(
        represented.substring(start, end),
        focusNode: nativeFocus,
        contextMenuBuilder: buildToolbar,
        style: widget.controls.appearance(context).technical,
      ),
    );
    // Retain the trailing native viewport when page/NUL controls appear or
    // disappear; changing the represented scope must not remount the field.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (containsNul) ...[
          widget.controls.tooltip(
            l.nativeTextNulUnavailable,
            Text(
              l.nativeTextNulUnavailable,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          widget.controls.choice(
            base64View,
            {false: l.utf8Hex, true: l.utf8Base64},
            (value) => setState(() {
              base64View = value;
              index();
            }),
            label: l.modeLabel,
          ),
        ],
        if (starts.length > 1)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                container: true,
                liveRegion: true,
                hint: l.textValuePagesScope,
                child: widget.controls.tooltip(
                  l.textValuePagesScope,
                  Text(l.textValuePage('${page + 1}', '${starts.length}')),
                ),
              ),
              widget.controls.textButton(
                l.textValuePreviousPage,
                page == 0 ? null : () => movePage(-1),
              ),
              widget.controls.textButton(
                l.textValueNextPage,
                page + 1 == starts.length ? null : () => movePage(1),
              ),
            ],
          ),
        Expanded(child: content),
      ],
    );
  }
}
