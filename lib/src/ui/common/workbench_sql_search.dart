import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import '../../features/workspace/documents.dart';
import '../../features/workspace/workbench_model.dart';
import '../../l10n/workbench_strings.dart';
import 'desktop_controls.dart';
import 'modal_command_boundary.dart';
import 'workbench_presentation.dart';
import 'document_presentation.dart';

class WorkbenchSqlSearch extends StatefulWidget {
  const WorkbenchSqlSearch({
    super.key,
    required this.model,
    required this.document,
    required this.controls,
    required this.query,
    required this.queryFocus,
    this.replacing = false,
  });
  final WorkbenchModel model;
  final SqlDocument document;
  final DesktopControls controls;
  final TextEditingController query;
  final FocusNode queryFocus;
  final bool replacing;
  @override
  State<WorkbenchSqlSearch> createState() => WorkbenchSqlSearchState();
}

class WorkbenchSqlSearchState extends State<WorkbenchSqlSearch> {
  final replacement = TextEditingController();
  final scroll = ScrollController();
  final rowKeys = <int, GlobalKey<WorkbenchRecordState>>{};
  bool pruningKeys = false;
  GlobalKey<WorkbenchRecordState> rowKey(int index) {
    if (!pruningKeys) {
      pruningKeys = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        pruningKeys = false;
        if (mounted) {
          rowKeys.removeWhere((_, key) => key.currentContext == null);
        }
      });
    }
    return rowKeys.putIfAbsent(index, GlobalKey.new);
  }

  List<Match> matches = [];
  String searchedText = '', searchedQuery = '';
  CodeLineEditingValue? revision;
  int selected = 0, total = 0;
  double rowExtent = 0;
  bool get current =>
      !widget.model.isDisposed &&
      widget.model.documents.contains(widget.document);
  bool get matchesCurrent =>
      current &&
      !widget.query.value.composing.isValid &&
      widget.query.text == searchedQuery &&
      revision == widget.document.editor.value &&
      !widget.document.editor.isComposing;
  @override
  void initState() {
    super.initState();
    widget.query.addListener(queryChanged);
    replacement.addListener(replacementChanged);
    widget.document.editor.addListener(documentChanged);
    recompute();
  }

  void queryChanged() {
    if (widget.query.value.composing.isValid) {
      setState(() {});
      return;
    }
    setState(() {
      selected = 0;
      recompute();
    });
  }

  void replacementChanged() => setState(() {});

  void documentChanged() {
    // Selecting a result changes the editing value but not its text. Do not
    // rebuild a large document's search just because its caret moved.
    if (revision?.codeLines == widget.document.editor.value.codeLines) {
      revision = widget.document.editor.value;
      return;
    }
    if (mounted) setState(recompute);
  }

  void recompute() {
    matches = [];
    searchedText = '';
    searchedQuery = widget.query.text;
    total = 0;
    if (!current || widget.query.text.isEmpty) return;
    revision = widget.document.editor.value;
    searchedText = widget.document.editor.text;
    for (final match in RegExp(
      RegExp.escape(widget.query.text),
    ).allMatches(searchedText)) {
      matches.add(match);
      total++;
    }
    selected = selected.clamp(0, matches.isEmpty ? 0 : matches.length - 1);
  }

  void move(int delta) {
    if (!matchesCurrent || matches.isEmpty) return;
    final rowFocus = !widget.queryFocus.hasFocus;
    final focusOwner = FocusManager.instance.primaryFocus;
    setState(() => selected = (selected + delta) % matches.length);
    if (scroll.hasClients && rowExtent > 0) {
      scroll.jumpTo(
        (selected * rowExtent).clamp(0, scroll.position.maxScrollExtent),
      );
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = rowKeys[selected]?.currentContext;
      if (mounted && row != null) {
        Scrollable.ensureVisible(row, alignment: .5, duration: Duration.zero);
        if (rowFocus &&
            identical(FocusManager.instance.primaryFocus, focusOwner)) {
          rowKeys[selected]?.currentState?.requestFocus();
        }
      }
    });
  }

  void activateSelection() {
    if (!matchesCurrent || selected >= matches.length) {
      return;
    }
    final match = matches[selected];
    widget.model.activateOwner(widget.document.id);
    widget.document.selectOffsets(match.start, match.end);
    // Selecting SQL never requests editor input focus or executes a statement.
  }

  void replaceSelection({bool all = false}) {
    if (!matchesCurrent ||
        matches.isEmpty ||
        replacement.value.composing.isValid) {
      return;
    }
    if (all) {
      widget.document.editor.selectAll();
      widget.document.editor.replaceSelection(
        widget.document.editor.text.replaceAll(
          widget.query.text,
          replacement.text,
        ),
      );
    } else {
      activateSelection();
      widget.document.editor.replaceSelection(replacement.text);
    }
  }

  @override
  void dispose() {
    widget.query.removeListener(queryChanged);
    widget.document.editor.removeListener(documentChanged);
    replacement.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui = widget.controls, l = strings(context);
    rowExtent = ui.appearance(context).lineHeight(context) * 3 + 16;
    return WorkbenchLocalInputBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(sqlDocumentName(context, widget.document)),
          ),
          if (widget.replacing) ...[
            ui.field(replacement, l.replaceText),
            Wrap(
              spacing: 8,
              children: [
                ui.button(
                  l.replaceSelection,
                  matchesCurrent &&
                          matches.isNotEmpty &&
                          !replacement.value.composing.isValid
                      ? () => replaceSelection()
                      : null,
                ),
                ui.button(
                  l.replaceAll,
                  matchesCurrent &&
                          matches.isNotEmpty &&
                          !replacement.value.composing.isValid
                      ? () => replaceSelection(all: true)
                      : null,
                ),
              ],
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              l.searchMatchCount(
                '${matches.isEmpty ? 0 : selected + 1}',
                '$total',
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              padding: ui.sidebarListPadding,
              itemExtent: rowExtent,
              itemCount: matches.isEmpty ? 1 : matches.length,
              itemBuilder: (context, index) {
                if (matches.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      widget.query.text.isEmpty
                          ? l.enterSearchText
                          : l.noSearchMatches,
                    ),
                  );
                }
                final match = matches[index], text = searchedText;
                final start = (match.start - 32).clamp(0, text.length),
                    end = (match.end + 64).clamp(0, text.length);
                final preview = text.substring(start, end);
                return WorkbenchRecord(
                  key: rowKey(index),
                  controls: ui,
                  leading: DesktopIcon.query,
                  onFocusChange: (focused) {
                    if (focused) setState(() => selected = index);
                  },
                  label: '${match.start + 1}: $preview',
                  selected: index == selected,
                  selectionFocused: widget.queryFocus.hasFocus ? true : null,
                  takeFocus: false,
                  onPressed: matchesCurrent
                      ? () {
                          setState(() => selected = index);
                          activateSelection();
                        }
                      : null,
                  child: Text(
                    preview,
                    textDirection: TextDirection.ltr,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
