import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:re_editor/re_editor.dart';
import '../../features/workspace/editor/sql_editor.dart';

/// First-party dispatch keeps editing permission with the current view while
/// the unmodified upstream widget supplies read-only layout and hit testing.
Map<Type, Action<Intent>> sqlEditorActions({
  required SqlEditorController controller,
  required bool Function() owned,
  required bool Function() readOnly,
  required bool Function() completionActive,
  required bool Function(AxisDirection) completionMove,
  required bool Function() completionCommit,
  required bool Function() completionDismiss,
  CodeCommentFormatter? commentFormatter,
}) {
  Action<T> command<T extends Intent>(
    void Function(T) invoke, {
    bool changesText = false,
  }) => CallbackAction<T>(
    onInvoke: (intent) {
      if (!owned() || controller.isComposing || (changesText && readOnly())) {
        return null;
      }
      invoke(intent);
      return null;
    },
  );
  return {
    CodeShortcutSelectAllIntent: command<CodeShortcutSelectAllIntent>(
      (_) => controller.selectAll(),
    ),
    CodeShortcutLineSelectIntent: command<CodeShortcutLineSelectIntent>(
      (_) => controller.selectLines(
        controller.selection.baseIndex,
        controller.selection.extentIndex,
      ),
    ),
    CodeShortcutCopyIntent: command<CodeShortcutCopyIntent>(
      (_) => unawaited(controller.copy()),
    ),
    CodeShortcutCutIntent: command<CodeShortcutCutIntent>(
      (_) => controller.cut(),
      changesText: true,
    ),
    CodeShortcutPasteIntent: command<CodeShortcutPasteIntent>(
      (_) => controller.paste(),
      changesText: true,
    ),
    CodeShortcutUndoIntent: command<CodeShortcutUndoIntent>(
      (_) => controller.undo(),
      changesText: true,
    ),
    CodeShortcutRedoIntent: command<CodeShortcutRedoIntent>(
      (_) => controller.redo(),
      changesText: true,
    ),
    ShortcutLineDeleteIntent: command<ShortcutLineDeleteIntent>(
      (_) => controller.deleteSelectionLines(),
      changesText: true,
    ),
    ShortcutLineDeleteDirectionIntent:
        command<ShortcutLineDeleteDirectionIntent>(
          (intent) => intent.forward
              ? controller.deleteLineForward()
              : controller.deleteLineBackward(),
          changesText: true,
        ),
    ShortcutLineMoveIntent: command<ShortcutLineMoveIntent>(
      (intent) => intent.direction == VerticalDirection.up
          ? controller.moveSelectionLinesUp()
          : controller.moveSelectionLinesDown(),
      changesText: true,
    ),
    ShortcutWordDeleteDirectionIntent:
        command<ShortcutWordDeleteDirectionIntent>(
          (intent) => intent.forward
              ? controller.deleteWordForward()
              : controller.deleteWordBackward(),
          changesText: true,
        ),
    CodeShortcutDeleteIntent: command<CodeShortcutDeleteIntent>(
      (intent) => intent.forward
          ? controller.deleteForward()
          : controller.deleteBackward(),
      changesText: true,
    ),
    CodeShortcutIndentIntent: command<CodeShortcutIndentIntent>((_) {
      if (!completionCommit()) controller.applyIndent();
    }, changesText: true),
    CodeShortcutOutdentIntent: command<CodeShortcutOutdentIntent>(
      (_) => controller.applyOutdent(),
      changesText: true,
    ),
    CodeShortcutNewLineIntent: command<CodeShortcutNewLineIntent>((_) {
      if (!completionCommit()) controller.applyNewLine();
    }, changesText: true),
    CodeShortcutTransposeCharactersIntent:
        command<CodeShortcutTransposeCharactersIntent>(
          (_) => controller.transposeCharacters(),
          changesText: true,
        ),
    CodeShortcutCommentIntent: command<CodeShortcutCommentIntent>((intent) {
      final formatter = commentFormatter;
      if (formatter != null) {
        controller.formatSelectionComments(formatter, intent.single);
      }
    }, changesText: true),
    CodeShortcutCursorMoveIntent: command<CodeShortcutCursorMoveIntent>((
      intent,
    ) {
      if (!completionMove(intent.direction)) {
        controller.moveCursor(intent.direction);
      }
    }),
    CodeShortcutCursorMoveLineEdgeIntent:
        command<CodeShortcutCursorMoveLineEdgeIntent>(
          (intent) => intent.forward
              ? controller.moveCursorToLineEnd()
              : controller.moveCursorToLineStart(),
        ),
    CodeShortcutCursorMoveDocEdgeIntent:
        command<CodeShortcutCursorMoveDocEdgeIntent>(
          (intent) => intent.forward
              ? controller.moveCursorToPageEnd()
              : controller.moveCursorToPageStart(),
        ),
    CodeShortcutCursorMovePageIntent: command<CodeShortcutCursorMovePageIntent>(
      (intent) => intent.forward
          ? controller.moveCursorToPageDown()
          : controller.moveCursorToPageUp(),
    ),
    CodeShortcutCursorMoveWordBoundaryIntent:
        command<CodeShortcutCursorMoveWordBoundaryIntent>(
          (intent) => intent.forward
              ? controller.moveCursorToWordBoundaryForward()
              : controller.moveCursorToWordBoundaryBackward(),
        ),
    CodeShortcutSelectionExtendIntent:
        command<CodeShortcutSelectionExtendIntent>(
          (intent) => controller.extendSelection(intent.direction),
        ),
    CodeShortcutSelectionExtendLineEdgeIntent:
        command<CodeShortcutSelectionExtendLineEdgeIntent>(
          (intent) => intent.forward
              ? controller.extendSelectionToLineEnd()
              : controller.extendSelectionToLineStart(),
        ),
    CodeShortcutSelectionExtendPageEdgeIntent:
        command<CodeShortcutSelectionExtendPageEdgeIntent>(
          (intent) => intent.forward
              ? controller.extendSelectionToPageEnd()
              : controller.extendSelectionToPageStart(),
        ),
    CodeShortcutSelectionExtendWordBoundaryIntent:
        command<CodeShortcutSelectionExtendWordBoundaryIntent>(
          (intent) => intent.forward
              ? controller.extendSelectionToWordBoundaryForward()
              : controller.extendSelectionToWordBoundaryBackward(),
        ),
    CodeShortcutEscIntent: _SqlEscapeAction(
      enabled: () =>
          owned() &&
          !controller.isComposing &&
          (completionActive() ||
              !controller.selection.isCollapsed ||
              controller.value.secondarySelections.isNotEmpty),
      onInvoke: () {
        if (!owned() || controller.isComposing || completionDismiss()) return;
        if (controller.value.secondarySelections.isNotEmpty) {
          controller.setExtraSelections(const []);
        }
        if (!controller.selection.isCollapsed) controller.cancelSelection();
      },
    ),
  };
}

class _SqlEscapeAction extends Action<CodeShortcutEscIntent> {
  _SqlEscapeAction({required this.enabled, required this.onInvoke});
  final bool Function() enabled;
  final VoidCallback onInvoke;
  @override
  bool isEnabled(CodeShortcutEscIntent intent) => enabled();
  @override
  Object? invoke(CodeShortcutEscIntent intent) {
    onInvoke();
    return null;
  }
}
