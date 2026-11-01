import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/sql_editor_view.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:busydata/src/ui/common/sql_presentation.dart';
import 'package:busydata/src/ui/common/workbench_editor_scroll.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

/// Exercises BusyData's source/selection/semantics owner through its production
/// view. The unmodified upstream widget remains a nested text-layout/input peer.
class SqlEditorTestView extends StatelessWidget {
  const SqlEditorTestView({
    super.key,
    required this.controller,
    this.focusNode,
    this.toolbarController,
    this.scrollController,
    this.style,
    this.indicatorBuilder,
    this.shortcutsActivatorsBuilder,
    this.autofocus = true,
    this.readOnly = false,
    this.semanticLabel,
    this.wordWrap = true,
    this.controls = const LinuxControls(),
  });
  final SqlEditorController controller;
  final FocusNode? focusNode;
  final SelectionToolbarController? toolbarController;
  final SqlEditorScrollController? scrollController;
  final CodeEditorStyle? style;
  final CodeIndicatorBuilder? indicatorBuilder;
  final CodeShortcutsActivatorsBuilder? shortcutsActivatorsBuilder;
  final bool autofocus, readOnly, wordWrap;
  final String? semanticLabel;
  final DesktopControls controls;

  @override
  Widget build(BuildContext context) {
    Widget editor(SqlEditorScrollController scroll) => WorkbenchSqlEditor(
      controls: controls,
      controller: controller,
      scrollController: scroll,
      focusNode: focusNode,
      toolbarController: toolbarController,
      style: style ?? sqlEditorStyle(context, controls),
      indicatorBuilder:
          indicatorBuilder ??
          (context, editing, chunks, notifier) =>
              sqlEditorIndicators(context, controls, editing, chunks, notifier),
      shortcutsActivatorsBuilder: shortcutsActivatorsBuilder,
      autofocus: autofocus,
      readOnly: readOnly,
      semanticLabel: semanticLabel,
      wordWrap: wordWrap,
    );
    final supplied = scrollController;
    return supplied != null
        ? editor(supplied)
        : WorkbenchEditorScroll(
            presentation: sqlPresentationSignature(context, controls),
            builder: editor,
          );
  }
}

/// Undo restores source, fold projection, selection and every extra range;
/// its new revision must continue to invalidate previously captured work.
void expectSqlSnapshotRestored(SqlEditorValue actual, SqlEditorValue before) {
  expect(actual.source.text, before.source.text);
  expect(actual.selection, before.selection);
  expect(actual.composing, before.composing);
  expect(actual.secondarySelections, orderedEquals(before.secondarySelections));
  expect(actual.codeLines.equals(before.codeLines), isTrue);
  expect(actual.revision, greaterThan(before.revision));
}

Matcher sqlEditorFailure(SqlEditorFailure reason) => throwsA(
  isA<SqlEditorException>().having((failure) => failure.code, 'code', reason),
);

/// Release before Flutter verifies test-body invariants, and also on assertion
/// failure so one failed case cannot leak its handle into the following case.
VoidCallback retainSqlTestSemantics(WidgetTester tester) {
  final handle = tester.ensureSemantics();
  var open = true;
  void release() {
    if (!open) return;
    open = false;
    handle.dispose();
  }

  addTearDown(release);
  return release;
}
