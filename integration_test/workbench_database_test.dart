import 'dart:io';
import 'package:busydata/main_linux.dart' as application;
import 'package:busydata/src/app/linux/linux_busydata_app.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaru/yaru.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import 'linux_accessibility_test_binding.dart';

void main() {
  LinuxAccessibilityIntegrationTestBinding.ensureInitialized();
  testWidgets('real Linux editor command renders exact PostgreSQL results', (
    tester,
  ) async {
    final port = int.parse(Platform.environment['BUSYDATA_TEST_PORT'] ?? '0');
    expect(
      port,
      greaterThan(0),
      reason:
          'Run tool/verify_database_ui.sh; missing fixture is a failure, not a skip.',
    );
    await application.main();
    await tester.pumpAndSettle();
    final element = tester.element(find.byType(LinuxBusyDataApp));
    final model = ProviderScope.containerOf(element).read(workbenchProvider);
    expect(model.backend, isNotNull, reason: model.status);
    Future<void> waitFor(bool Function() ready) async {
      for (var attempt = 0; attempt < 200; attempt++) {
        await tester.pump();
        if (ready()) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
      }
      fail(
        'The actual UI did not acknowledge its operation: ${model.status}; '
        'Explorer sessions: ${model.explorerSessions.length}; '
        'query session: ${model.document.sessionId != null}; '
        'active owner: ${model.activeOwner.id}; selected: ${model.selected}; '
        'start surface: ${model.showStartSurface}; '
        'editors: ${find.byType(CodeEditor, skipOffstage: false).evaluate().map((e) => {'key': '${e.widget.key}', 'current': identical((e.widget as CodeEditor).controller, model.document.editor)}).toList()}',
      );
    }

    Future<void> key(LogicalKeyboardKey key, {bool shift = false}) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(key);
      if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
    }

    Finder entry(String label) => find.descendant(
      of: find.bySemanticsLabel(label),
      matching: find.byType(EditableText),
    );

    Future<void> command(String label) async {
      await key(LogicalKeyboardKey.keyP, shift: true);
      final header = find.byType(SearchHeaderField);
      await waitFor(() => header.evaluate().isNotEmpty);
      expect(header, findsOneWidget);
      expect(
        tester.widget<SearchHeaderField>(header).hint,
        strings(tester.element(header)).searchActionsHint,
      );
      final query = find.descendant(
        of: header,
        matching: find.byType(EditableText),
      );
      expect(query.hitTestable(), findsOneWidget);
      await tester.enterText(query, label);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await waitFor(() => header.evaluate().isEmpty);
    }

    Future<void> pasteSql(String sql) async {
      await waitFor(
        () => find
            .byType(CodeEditor)
            .evaluate()
            .any(
              (element) => identical(
                (element.widget as CodeEditor).controller,
                model.document.editor,
              ),
            ),
      );
      await tester.tap(find.byType(CodeEditor));
      await key(LogicalKeyboardKey.keyA);
      await Clipboard.setData(ClipboardData(text: sql));
      await key(LogicalKeyboardKey.keyV);
      await waitFor(() => model.document.editor.text == sql);
    }

    await tester.tap(
      find.descendant(
        of: find.byType(DatabaseExplorer),
        matching: find.text('New connection'),
      ),
    );
    await tester.pump();
    Finder connectionField(String name) => find.descendant(
      of: find.byKey(ValueKey('connection-$name')),
      matching: find.byType(TextField),
    );
    await waitFor(() => connectionField('name').evaluate().isNotEmpty);
    for (final field in <String, String>{
      'name': 'Disposable UI fixture',
      'host': '127.0.0.1',
      'port': '$port',
      'database': 'postgres',
      'user': 'postgres',
      'password': 'busydata-ui-fixture',
    }.entries) {
      final target = connectionField(field.key);
      await tester.ensureVisible(target);
      await tester.enterText(target, field.value);
    }
    // The ordinary first-use route stays on General and uses the manager footer.
    // Hit testing and bounds reject an off-screen completion control.
    final complete = find.text('Save & connect');
    expect(complete.hitTestable(), findsOneWidget);
    final completeBounds = tester.getRect(complete);
    final viewport =
        Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
    expect(viewport.contains(completeBounds.topLeft), isTrue);
    expect(viewport.contains(completeBounds.bottomRight), isTrue);
    await tester.tap(complete);
    await waitFor(
      () =>
          model.explorerSessions.isNotEmpty &&
          connectionField('name').evaluate().isEmpty,
    );
    expect(model.profiles.single.tls.mode, rpc.TlsMode.DRIVER_DEFAULT);
    expect(model.document.sessionId, isNull);
    expect(model.document.profileId, model.profiles.single.id);
    await waitFor(() => find.byType(CodeEditor).evaluate().isNotEmpty);
    await pasteSql(
      'SELECT CAST(12345678901234567890.123456789 AS DECIMAL(38,9)) AS exact_value, NULL AS missing',
    );
    await tester.tap(find.text('Run').first);
    await waitFor(() => entry('Password').evaluate().isNotEmpty);
    await tester.enterText(entry('Password'), 'busydata-ui-fixture');
    await tester.tap(find.text('Connect').last);
    await waitFor(() => model.document.sessionId != null);
    expect(
      model.document.sessionId,
      isNot(model.explorerSessions.values.single),
    );
    await waitFor(() => model.currentJob?.state == rpc.JobState.COMPLETED);
    await waitFor(
      () => find.text('12345678901234567890.123456789').evaluate().isNotEmpty,
    );
    await tester.pump();
    expect(find.text('12345678901234567890.123456789'), findsOneWidget);
    expect(find.text('NULL'), findsOneWidget);
    expect(model.session?.transaction, rpc.TransactionState.IDLE);
    final sourceDocument = model.document;
    final sourceSql = sourceDocument.editor.text;
    final sourceSession = sourceDocument.sessionId!;
    await command('Begin transaction');
    await waitFor(
      () =>
          model.sessions[sourceSession]?.transaction ==
          rpc.TransactionState.ACTIVE,
    );
    final previousDocumentCount = model.documents.length;
    await command('New query');
    await waitFor(() => model.documents.length == previousDocumentCount + 1);
    await pasteSql('SELECT 2;');
    expect(sourceDocument.editor.text, sourceSql);
    expect(
      model.sessions[sourceSession]!.transaction,
      rpc.TransactionState.ACTIVE,
    );
    await tester.pump();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is YaruWindowControl &&
            widget.type == YaruWindowControlType.close,
      ),
    );
    for (int i = 0; i < 100; i++) {
      await tester.pump();
      if (find.text('Close BusyData').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
    }
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Transactions requiring cleanup: 1'),
      findsOneWidget,
    );
    expect(find.textContaining('Unsaved documents: 2'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.text('Close BusyData'), findsNothing);
    expect(model.selected, previousDocumentCount);
    expect(
      model.sessions[sourceSession]!.transaction,
      rpc.TransactionState.ACTIVE,
    );
    await tester.tap(find.byKey(ValueKey('document-tab:${sourceDocument.id}')));
    await tester.pump();
    await command('Roll back transaction');
    await waitFor(
      () =>
          model.sessions[sourceSession]?.transaction ==
          rpc.TransactionState.IDLE,
    );
    await tester.runAsync(() => model.backend!.close());
  });
}
