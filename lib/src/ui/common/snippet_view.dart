import 'sql_editor_view.dart';
import '../../features/workspace/editor/sql_editor.dart';
import 'workbench_editor_menu.dart';
import '../../l10n/workbench_strings.dart';
import 'package:flutter/widgets.dart';
import 'desktop_controls.dart';
import 'sql_presentation.dart';
import 'workbench_editor_scroll.dart';
import 'workbench_presentation.dart';

class SnippetView extends StatefulWidget {
  const SnippetView({
    super.key,
    required this.controls,
    required this.snippets,
    required this.save,
    required this.insert,
  });
  final DesktopControls controls;
  final Map<String, String> snippets;
  final Future<void> Function(String, String, {bool remove}) save;
  final ValueChanged<String> insert;
  @override
  State<SnippetView> createState() => _SnippetViewState();
}

class _SnippetViewState extends State<SnippetView> {
  final name = TextEditingController(), sql = SqlEditorController();
  String selected = '', error = '';
  String sourceSql() => sql.text;
  bool busy = false;
  @override
  void dispose() {
    name.dispose();
    sql.dispose();
    super.dispose();
  }

  Future<void> save(bool remove) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
    });
    final savedName = name.text, savedSql = sourceSql();
    try {
      await widget.save(savedName, savedSql, remove: remove);
      if (mounted) setState(() => selected = remove ? '' : savedName);
    } catch (failure) {
      if (mounted) setState(() => error = '$failure');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      widget.controls.groupedList(
        title: strings(context).snippets,
        children: [
          widget.controls.comboRow(
            strings(context).snippets,

            selected,
            {
              '': strings(context).newSnippet,
              for (final key in widget.snippets.keys) key: key,
            },
            (String value) {
              if (busy) return;
              setState(() {
                selected = value;
                name.text = value;
                final text = widget.snippets[value] ?? '';
                sql.text = text;
              });
            },
          ),
          widget.controls.field(name, strings(context).snippetName),
        ],
      ),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Text(strings(context).snippetsNote),
      ),
      Expanded(
        child: WorkbenchEditorScroll(
          presentation: (
            sqlPresentationSignature(context, widget.controls),
            MediaQuery.textScalerOf(context),
          ),
          builder: (scroll) => WorkbenchEditorMenu(
            scrollController: scroll,
            controls: widget.controls,
            controller: sql,
            readOnly: busy,
            builder: (toolbar, menuFocus, shortcuts) => WorkbenchSqlEditor(
              semanticLabel: strings(context).snippetEditor,
              controls: widget.controls,
              shortcutsActivatorsBuilder: shortcuts,
              toolbarController: toolbar,
              focusNode: menuFocus,
              controller: sql,
              readOnly: busy,
              scrollController: scroll,
              style: sqlEditorStyle(context, widget.controls),
              indicatorBuilder: (context, editing, chunks, notifier) =>
                  sqlEditorIndicators(
                    context,
                    widget.controls,
                    editing,
                    chunks,
                    notifier,
                  ),
            ),
          ),
        ),
      ),
      if (error.isNotEmpty) widget.controls.status(error, error: true),
      WorkbenchStrip(
        controls: widget.controls,
        child: Wrap(
          spacing: 8,
          children: [
            widget.controls.button(
              strings(context).saveSnippet,
              busy ? null : () => save(false),
            ),
            widget.controls.button(
              strings(context).deleteSnippet,
              busy || selected.isEmpty ? null : () => save(true),
            ),
            widget.controls.button(
              strings(context).insertSnippet,
              busy
                  ? null
                  : () {
                      try {
                        widget.insert(sourceSql());
                      } catch (failure) {
                        setState(() => error = '$failure');
                      }
                    },
            ),
          ],
        ),
      ),
    ],
  );
}
