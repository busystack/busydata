import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_editor_menu.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/ui/common/workbench_sql_search.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/workbench_settings.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'support/fake_backend.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'support/sql_editor_fixture.dart';
import 'package:yaru/yaru.dart';

void main() {
  testWidgets(
    'reference switch retains drag, state feedback and keyboard operation',
    (tester) async {
      var value = true, enabled = true;
      late StateSetter update;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: BusyDataYaruTheme.build(
            brightness: Brightness.light,
            accentColor: Colors.blue,
          ),
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return Center(
                child: Semantics(
                  label: 'Recovery preference',
                  child: BusyDataSwitch(
                    value: value,
                    autofocus: true,
                    focusNode: focus,
                    onChanged: enabled
                        ? (next) => update(() => value = next)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final normal = tester
          .widget<YaruSwitch>(find.byType(YaruSwitch))
          .selectedColor;
      final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await pointer.addPointer(location: const Offset(1, 1));
      await pointer.moveTo(tester.getCenter(find.byType(YaruSwitch)));
      await tester.pumpAndSettle();
      final hovered = tester
          .widget<YaruSwitch>(find.byType(YaruSwitch))
          .selectedColor;
      expect(hovered, isNot(normal));
      await pointer.down(tester.getCenter(find.byType(YaruSwitch)));
      await tester.pump();
      expect(
        tester.widget<YaruSwitch>(find.byType(YaruSwitch)).selectedColor,
        isNot(hovered),
      );
      await pointer.cancel();
      await pointer.removePointer();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(YaruSwitch), const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(value, isFalse);
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(value, isTrue);
      update(() => enabled = false);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(YaruSwitch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );
  test(
    'appearance and accepted shortcuts merge at the acknowledged write',
    () async {
      final firstWrite = Completer<void>();
      final writes = <Map<String, dynamic>>[];
      var fail = false;
      final model = WorkbenchModel(
        Directory('/tmp/parity-preferences'),
        presentationWrite: (_, bytes) async {
          if (writes.isEmpty) await firstWrite.future;
          if (fail) throw const FileSystemException('read-only fixture');
          writes.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        },
      )..draftRecovery = false;
      addTearDown(model.dispose);
      final appearance = model.saveAppearance('dark', 'de');
      final shortcut = model.saveShortcut('execute', 'Ctrl+Alt+Enter');
      final execution = model.saveExecutionPreferences(
        500,
        rpc.ErrorPolicy.CONTINUE_ON_ERROR,
        recovery: false,
      );
      expect(model.appearancePreference.value, ('system', null));
      expect(model.shortcuts['execute'], 'Ctrl+Enter');
      firstWrite.complete();
      await Future.wait([appearance, shortcut, execution]);
      expect(writes.last['rowLimit'], 500);
      expect(writes.last['continueOnError'], true);
      expect(writes.last['themeMode'], 'dark');
      expect(writes.last['locale'], 'de');
      expect((writes.last['shortcuts'] as Map)['execute'], 'Ctrl+Alt+Enter');
      fail = true;
      await expectLater(
        model.saveShortcut('execute', 'Ctrl+Alt+F9'),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        model.saveAppearance('light', 'fr'),
        throwsA(isA<FileSystemException>()),
      );
      expect(model.shortcuts['execute'], 'Ctrl+Alt+Enter');
      expect(model.appearancePreference.value, ('dark', 'de'));
      await expectLater(
        model.saveExecutionPreferences(
          900,
          rpc.ErrorPolicy.STOP_ON_ERROR,
          recovery: false,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(model.defaultRowLimit, 500);
      expect(model.defaultErrorPolicy, rpc.ErrorPolicy.CONTINUE_ON_ERROR);
    },
  );

  testWidgets('SQL search keeps its document and replacement is one undo step', (
    tester,
  ) async {
    final model = WorkbenchModel(Directory('/tmp/parity-search'))
      ..draftRecovery = false
      ..newDocument(text: 'select alpha, alpha;');
    final captured = model.document;
    model.newDocument(text: 'select beta;');
    final other = model.document;
    final query = TextEditingController(text: 'alpha');
    final focus = FocusNode();
    final key = GlobalKey<WorkbenchSqlSearchState>();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      query.dispose();
      focus.dispose();
      if (!model.isDisposed) model.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 300,
          child: WorkbenchSqlSearch(
            key: key,
            model: model,
            document: captured,
            controls: const LinuxControls(),
            query: query,
            queryFocus: focus,
            replacing: true,
          ),
        ),
      ),
    );
    query.value = const TextEditingValue(
      text: 'unfinished',
      composing: TextRange(start: 0, end: 10),
    );
    key.currentState!.replacement.text = 'gamma';
    key.currentState!.replaceSelection(all: true);
    expect(captured.editor.text, 'select alpha, alpha;');
    query.clear();
    await tester.pump();
    expect(find.text('Enter search text'), findsOneWidget);
    query.text = 'alpha';
    key.currentState!.replacement.value = const TextEditingValue(
      text: 'gamma',
      composing: TextRange(start: 0, end: 5),
    );
    key.currentState!.replaceSelection(all: true);
    expect(captured.editor.text, 'select alpha, alpha;');
    key.currentState!.replacement.value = const TextEditingValue(text: 'gamma');
    key.currentState!.replaceSelection(all: true);
    await tester.pump();
    expect(captured.editor.text, 'select gamma, gamma;');
    expect(other.editor.text, 'select beta;');
    captured.editor.undo();
    expect(captured.editor.text, 'select alpha, alpha;');
    // Closed owners cannot be selected or changed by an old search interaction.
    model.documents.remove(captured);
    key.currentState!.replaceSelection(all: true);
    expect(captured.editor.text, 'select alpha, alpha;');
    captured.dispose();
    model.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets(
    'large SQL search wraps to its last match with bounded mounted rows',
    (tester) async {
      final model = WorkbenchModel(Directory('/tmp/parity-large-search'))
        ..draftRecovery = false
        ..newDocument(text: List.filled(12000, 'select alpha;').join('\n'));
      final query = TextEditingController(text: 'alpha'), focus = FocusNode();
      final key = GlobalKey<WorkbenchSqlSearchState>();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        query.dispose();
        focus.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 300,
              height: 520,
              child: WorkbenchSqlSearch(
                key: key,
                model: model,
                document: model.document,
                controls: const LinuxControls(),
                query: query,
                queryFocus: focus,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(key.currentState!.matches, hasLength(12000));
      key.currentState!.move(-1);
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, 11999);
      final selected = find.byWidgetPredicate(
        (widget) => widget is WorkbenchRecord && widget.selected,
      );
      expect(selected, findsOneWidget);
      expect(
        tester
            .getRect(find.byType(WorkbenchSqlSearch))
            .contains(tester.getCenter(selected)),
        isTrue,
      );
      expect(find.byType(WorkbenchRecord).evaluate().length, lessThan(40));
      expect(key.currentState!.rowKeys.length, lessThan(100));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'header categories retain captured SQL and retire old history on backend change',
    (tester) async {
      final lateHistory = Completer<rpc.HistoryList>();
      final backend = TestBackend();
      backend.client.historyCatalog = (request) => request.search == 'slow'
          ? lateHistory.future
          : Future.value(rpc.HistoryList(retainSql: true));
      final model = WorkbenchModel(Directory('/tmp/parity-header-context'))
        ..draftRecovery = false
        ..backend = backend
        ..newDocument(text: 'select alpha, alpha;');
      final original = model.document, target = model.commandContext;
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await tester.pumpAndSettle();
      // A command's captured SQL context wins over a later Explorer focus.
      model.explorerCommandContext = const WorkbenchCommandContext(
        profileId: 'another-source',
      );
      model.explorerFocus.requestFocus();
      await tester.pump();
      await model.commands!.invoke('editor.find', target);
      await tester.pumpAndSettle();
      expect(
        tester.widget<SearchSidebar>(find.byType(SearchSidebar)).category,
        'sql',
      );
      final query = tester
          .widget<SearchHeaderField>(find.byType(SearchHeaderField))
          .query;
      expect(
        tester.widget<SearchHeaderField>(find.byType(SearchHeaderField)).hint,
        'Search current SQL…',
      );
      query.text = 'alpha';
      await tester.pumpAndSettle();
      model.newDocument(text: 'select beta;');
      model.updateStatus('New active document');
      await tester.pumpAndSettle();
      tester
          .state<WorkbenchSqlSearchState>(find.byType(WorkbenchSqlSearch))
          .activateSelection();
      await tester.pumpAndSettle();
      expect(original.editor.selectedText, 'alpha');
      expect(model.document, same(original));
      final rows = find.descendant(
        of: find.byType(WorkbenchSqlSearch),
        matching: find.byType(WorkbenchRecord),
      );
      tester.state<WorkbenchRecordState>(rows.first).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester
            .state<WorkbenchSqlSearchState>(find.byType(WorkbenchSqlSearch))
            .selected,
        1,
      );
      expect(
        tester.state<WorkbenchRecordState>(rows.last).node.hasFocus,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(original.editor.selectedText, 'alpha');
      expect(backend.client.executions, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await model.commands!.invoke('history.search', model.commandContext);
      await tester.pumpAndSettle();
      tester
              .widget<SearchHeaderField>(find.byType(SearchHeaderField))
              .query
              .text =
          'slow';
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(backend.client.historyRequests.last.search, 'slow');
      final replacement = TestBackend(instanceId: 'replacement');
      model.backend = replacement;
      model.updateStatus('Backend replaced');
      await tester.pumpAndSettle();
      expect(find.byType(SearchSidebar), findsNothing);
      lateHistory.complete(
        rpc.HistoryList(
          entries: [rpc.HistoryEntry(id: 'late', target: 'Old backend result')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Old backend result'), findsNothing);
      expect(replacement.client.historyRequests, isEmpty);
      expect(backend.client.executions, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  testWidgets(
    'settings departure retains invalid drafts and never executes hidden SQL',
    (tester) async {
      final model = WorkbenchModel(Directory('/tmp/parity-settings'))
        ..draftRecovery = false
        ..backend = TestBackend()
        ..newDocument(text: 'select keep_me;');
      final editor = model.document.editor;
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        if (!model.isDisposed) model.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await model.commands!.invoke('preferences', model.commandContext);
      await tester.pumpAndSettle();
      expect(find.text('Appearance'), findsWidgets);
      await tester.tap(find.text('Execution options').first);
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(WorkbenchSettings),
        matching: find.byWidgetPredicate(
          (w) => w is EditableText && !w.readOnly,
        ),
      );
      await tester.enterText(field, '0');
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stay').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(field.hitTestable()).controller.text,
        '0',
      );
      await tester.tap(find.text('Appearance').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Execution options').first);
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(field.hitTestable()).controller.text,
        '0',
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect((model.backend as TestBackend).client.executions, isEmpty);
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard pending changes').last);
      await tester.pumpAndSettle();
      expect(find.byType(WorkbenchSettings), findsNothing);
      expect(model.document.editor, same(editor));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.linux),
  );

  for (final readOnly in [false, true]) {
    testWidgets(
      'SQL text menu pointer and keyboard admission, readOnly=$readOnly',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final presenter = _Menu();
        final controls = _Controls(presenter);
        final editing = SqlEditorController.fromText('alpha beta');
        final scroll = SqlEditorScrollController();
        addTearDown(scroll.dispose);
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.hasStrings') return {'value': true};
          if (call.method == 'Clipboard.getData') return {'text': 'pasted'};
          return null;
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          editing.dispose();
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 500,
              height: 250,
              child: WorkbenchEditorMenu(
                scrollController: scroll,
                controls: controls,
                controller: editing,
                readOnly: readOnly,
                builder: (toolbar, focus, shortcuts) => SqlEditorTestView(
                  controls: controls,
                  shortcutsActivatorsBuilder: shortcuts,
                  controller: editing,
                  scrollController: scroll,
                  focusNode: focus,
                  readOnly: readOnly,
                  toolbarController: toolbar,
                  autofocus: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final textCaret = scroll.geometry.caret(
          const CodeLinePosition(index: 0, offset: 1),
        );
        expect(
          textCaret,
          isNotNull,
          reason:
              'The native menu pointer must target verified text, outside the measured gutter',
        );
        final position = textCaret!.center;
        await tester.tapAt(position, buttons: kSecondaryMouseButton);
        await tester.pumpAndSettle();
        expect(presenter.actions.map((a) => a.label), [
          'Cut',
          'Copy',
          'Paste',
          'Select all',
        ]);
        expect(presenter.actions[0].disabledReason != null, readOnly);
        expect(presenter.actions[2].disabledReason != null, readOnly);
        presenter.result.complete(null);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        expect(presenter.keyboard, isTrue);
        // A newer editing revision invalidates the old popup's eventual command.
        editing.replaceSelection('new');
        final changed = editing.text;
        presenter.result.complete(2);
        await tester.pumpAndSettle();
        expect(editing.text, changed);
        debugDefaultTargetPlatformOverride = null;
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }

  for (final delayDismiss in [false, true]) {
    testWidgets(
      'a delayed editor menu cannot open after focus leaves, dismiss=$delayDismiss',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.linux;
        final clipboard = Completer<Map<String, bool>>(), presenter = _Menu();
        final dismissal = Completer<void>();
        if (delayDismiss) presenter.dismissal = dismissal.future;
        final editing = SqlEditorController.fromText('retained SQL');
        final scroll = SqlEditorScrollController();
        addTearDown(scroll.dispose);
        final next = FocusNode();
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async =>
              call.method == 'Clipboard.hasStrings' ? clipboard.future : null,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          editing.dispose();
          next.dispose();
          debugDefaultTargetPlatformOverride = null;
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  Expanded(
                    child: WorkbenchEditorMenu(
                      scrollController: scroll,
                      controls: _Controls(presenter),
                      controller: editing,
                      builder: (toolbar, focus, shortcuts) => SqlEditorTestView(
                        controls: _Controls(presenter),
                        shortcutsActivatorsBuilder: shortcuts,
                        controller: editing,
                        scrollController: scroll,
                        focusNode: focus,
                        toolbarController: toolbar,
                        autofocus: true,
                      ),
                    ),
                  ),
                  TextField(focusNode: next),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pump();
        next.requestFocus();
        await tester.pump();
        clipboard.complete({'value': true});
        dismissal.complete();
        await tester.pumpAndSettle();
        expect(presenter.actions, isEmpty);
        expect(next.hasFocus, isTrue);
        expect(editing.text, 'retained SQL');
        debugDefaultTargetPlatformOverride = null;
      },
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
  }
}

class _Controls extends LinuxControls {
  const _Controls(this.presenter);
  final _Menu presenter;
  @override
  DesktopMenuPresenter createMenuPresenter() => presenter;
}

class _Menu extends DesktopMenuPresenter {
  List<DesktopMenuAction> actions = [];
  bool keyboard = false;
  Completer<int?> result = Completer<int?>();
  @override
  Future<int?> show(
    BuildContext context,
    Offset position,
    List<DesktopMenuAction> actions, {
    bool keyboard = false,
  }) {
    this.actions = actions;
    this.keyboard = keyboard;
    result = Completer<int?>();
    return result.future;
  }

  Future<void>? dismissal;
  @override
  Future<void> dismiss() async {
    await dismissal;
  }
}
