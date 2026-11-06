import 'dart:io';

import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'package:busydata/src/ui/common/workbench_completion.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/presentation_fonts.dart';
import 'support/sql_editor_fixture.dart';

void main() {
  setUpAll(loadPresentationFonts);
  for (final windows in [false, true]) {
    for (final keyboard in [false, true]) {
      testWidgets('accepted completion stays closed and keeps analysis current '
          '(windows=$windows, keyboard=$keyboard)', (tester) async {
        debugDefaultTargetPlatformOverride = windows
            ? TargetPlatform.windows
            : TargetPlatform.linux;
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('accepted-completion-'),
        ))!;
        final backend = TestBackend();
        const prefix = 'SELECT p.';
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: prefix);
        model.document.selectOffsets(prefix.length, prefix.length);
        final scroll = SqlEditorScrollController();
        final focus = FocusNode();
        final controls = windows
            ? const WindowsControls()
            : const LinuxControls();

        rpc.Completion candidate([String name = 'amount']) => rpc.Completion(
          label: name,
          insertText: name,
          startUtf16: prefix.length,
          endUtf16: model.document.editor.text.length,
        );

        Future<void> completePending() async {
          for (var i = 0; i < backend.client.analyses.length; i++) {
            if (!backend.client.pendingAnalyses[i].isCompleted) {
              backend.client.completeAnalysis(i);
            }
          }
          await tester.pump();
        }

        try {
          final body = Center(
            child: SizedBox(
              width: 700,
              height: 360,
              child: WorkbenchCompletion(
                model: model,
                document: model.document,
                controls: controls,
                scrollController: scroll,
                child: SqlEditorTestView(
                  controller: model.document.editor,
                  scrollController: scroll,
                  focusNode: focus,
                  controls: controls,
                ),
              ),
            ),
          );
          await tester.pumpWidget(
            windows
                ? fluent.FluentApp(
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: body,
                  )
                : presentationHost(body),
          );
          await tester.pumpAndSettle();
          final initial = model.analyze(model.document);
          await tester.pump();
          backend.client.completeAnalysis(
            backend.client.analyses.length - 1,
            completions: [candidate()],
          );
          await initial;
          await completePending();
          await tester.pumpAndSettle();
          expect(find.text('amount'), findsOneWidget);

          final before = backend.client.analyses.length;
          if (keyboard) {
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          } else {
            await tester.tap(find.text('amount'));
          }
          await tester.pump(const Duration(milliseconds: 400));
          expect(model.document.editor.text, '${prefix}amount');
          final refreshed = backend.client.analyses.skip(before).toList();
          expect(
            refreshed.map((request) => request.operation),
            unorderedEquals([
              rpc.AnalysisOperation.DIAGNOSTICS,
              rpc.AnalysisOperation.PARAMETER_INFORMATION,
            ]),
            reason:
                'Accepting a suggestion must refresh diagnostics and hints '
                'without requesting the same completion again.',
          );
          for (final request in refreshed) {
            expect(request.sql, model.document.editor.text);
            expect(request.documentVersion.toInt(), model.document.version);
            expect(request.caretUtf16, model.document.caret);
          }
          await completePending();
          await tester.pumpAndSettle();
          expect(find.text('amount'), findsNothing);

          // An explicit request may reopen suggestions at the same source
          // revision; the acceptance suppression must not become sticky.
          final explicit = model.analyze(model.document);
          await tester.pump();
          backend.client.completeAnalysis(
            backend.client.analyses.length - 1,
            completions: [candidate()],
          );
          await explicit;
          await completePending();
          await tester.pumpAndSettle();
          expect(find.text('amount'), findsOneWidget);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();

          // Subsequent input still starts ordinary automatic completion.
          final beforeTyping = backend.client.analyses.length;
          model.document.editor.replaceSelection('x');
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            backend.client.analyses
                .skip(beforeTyping)
                .map((request) => request.operation),
            [rpc.AnalysisOperation.COMPLETION],
          );
          backend.client.completeAnalysis(
            backend.client.analyses.length - 1,
            completions: [candidate('amountx_value')],
          );
          await tester.pump();
          await completePending();
          await tester.pumpAndSettle();
          expect(find.text('amountx_value'), findsOneWidget);
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          scroll.dispose();
          focus.dispose();
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }
  }
}
