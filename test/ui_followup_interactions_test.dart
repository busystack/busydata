import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/l10n/locale_resolution.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/history_view.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/workbench_editor_menu.dart';
import 'package:busydata/src/ui/common/workbench_presentation.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/ui/common/workbench_settings.dart';
import 'package:busydata/src/ui/common/workbench_sql_search.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:busydata/src/ui/common/sql_editor_geometry.dart';
import 'support/sql_editor_fixture.dart';
import 'support/fake_backend.dart';

const controls = LinuxControls();
Widget app(Widget child) => MaterialApp(
  theme: BusyDataYaruTheme.build(
    brightness: Brightness.light,
    accentColor: Colors.blue,
  ),
  home: Scaffold(body: child),
);

Future<void> enterOnButton(WidgetTester tester, String label) async {
  final button = find
      .ancestor(of: find.text(label), matching: find.byType(FilledButton))
      .last;
  Focus.of(
    tester.element(find.descendant(of: button, matching: find.text(label))),
  ).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window'),
      (call) async => call.method == 'state' ? <String, Object?>{} : null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('yaru_window/events'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('busydata/native_menus'),
      (_) async => throw MissingPluginException(),
    );
  });
  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('yaru_window'),
      null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('yaru_window/events'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('busydata/native_menus'),
      null,
    );
  });

  linuxTestWidgets(
    'sidebar Enter invokes Replace all; query and result keys stay scoped',
    (tester) async {
      final backend = TestBackend();
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..backend = backend
        ..newDocument(text: 'select alpha, alpha;');
      final document = model.document;
      final query = TextEditingController(text: 'alpha'), focus = FocusNode();
      final key = GlobalKey<WorkbenchSqlSearchState>();
      var submitted = 0;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        query.dispose();
        focus.dispose();
        model.dispose();
      });
      await tester.pumpWidget(
        app(
          Column(
            children: [
              SearchHeaderField(
                controls: controls,
                query: query,
                focusNode: focus,
                close: () {},
                submit: () {
                  submitted++;
                  key.currentState!.activateSelection();
                },
                move: (delta) => key.currentState!.move(delta),
                hint: 'Current SQL',
              ),
              Expanded(
                child: SearchSidebar(
                  controls: controls,
                  category: 'sql',
                  categories: const {'sql': 'Current SQL'},
                  selectCategory: (_) {},
                  close: () {},
                  submit: () => submitted++,
                  move: (delta) => key.currentState!.move(delta),
                  child: WorkbenchSqlSearch(
                    key: key,
                    model: model,
                    document: document,
                    controls: controls,
                    query: query,
                    queryFocus: focus,
                    replacing: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      key.currentState!.replacement.text = 'beta';
      await tester.pump();
      await enterOnButton(tester, 'Replace all');
      expect(document.editor.text, 'select beta, beta;');
      expect(submitted, 0);
      document.editor.undo();
      expect(document.editor.text, 'select alpha, alpha;');
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(submitted, 1);
      expect(document.editor.selectedText, 'alpha');
      final result = tester.state<WorkbenchRecordState>(
        find
            .descendant(
              of: find.byType(WorkbenchSqlSearch),
              matching: find.byType(WorkbenchRecord),
            )
            .first,
      );
      result.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(key.currentState!.selected, 1);
      expect(backend.client.executions, isEmpty);
    },
  );

  linuxTestWidgets('sidebar Enter pages History without activating a result', (
    tester,
  ) async {
    final backend = TestBackend();
    backend.client.historyCatalog = (request) async => rpc.HistoryList(
      entries: [rpc.HistoryEntry(id: 'a', target: 'A')],
      limited: true,
      nextOffset: request.offset + 50,
    );
    final model = WorkbenchModel(Directory('/unused'))
      ..draftRecovery = false
      ..backend = backend
      ..newDocument();
    final query = TextEditingController(text: 'alpha');
    final key = GlobalKey<HistoryViewState>();
    var activated = 0;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      query.dispose();
      model.dispose();
    });
    await tester.pumpWidget(
      app(
        SearchSidebar(
          controls: controls,
          category: 'history',
          categories: const {'history': 'History'},
          selectCategory: (_) {},
          close: () {},
          move: (delta) => key.currentState!.move(delta),
          submit: () => activated++,
          child: HistoryView(
            key: key,
            model: model,
            controls: controls,
            externalQuery: query,
            inspect: () => activated++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await enterOnButton(tester, 'Next');
    expect(backend.client.historyRequests.map((request) => request.offset), [
      0,
      50,
    ]);
    await enterOnButton(tester, 'Previous');
    expect(backend.client.historyRequests.last.offset, 0);
    expect(activated, 0);
  });

  linuxTestWidgets(
    'sidebar Enter requests Objects More without opening the selected object',
    (tester) async {
      final backend = TestBackend();
      final profile = rpc.Profile(id: 'p', engine: rpc.Engine.POSTGRESQL);
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      model.document.sessionId = 's';
      model.sessions['s'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 's',
        profile: profile,
        currentCatalog: 'db',
        currentSchema: 'public',
      );
      final data =
          ObjectSearchData(
              'p',
              model.captureTarget(),
              catalog: 'db',
              schema: 'public',
            )
            ..query = 'alpha'
            ..acceptedQuery = 'alpha'
            ..continuation = 'next-page';
      final owner = model.openTask(
        WorkbenchDocumentKind.structure,
        'Objects',
        payload: data,
        activate: false,
      );
      backend.client.metadataAction = (request) async => rpc.SchemaObjects(
        instanceId: backend.instanceId,
        sessionId: 's',
        catalog: 'db',
        schema: 'public',
        complete: true,
        availability: 'available',
      );
      final query = TextEditingController(text: 'alpha');
      final key = GlobalKey<DatabaseObjectSearchState>();
      var activated = 0;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        query.dispose();
        model.dispose();
      });
      await tester.pumpWidget(
        app(
          SearchSidebar(
            controls: controls,
            category: 'objects',
            categories: const {'objects': 'Database Objects'},
            selectCategory: (_) {},
            close: () {},
            move: (delta) => key.currentState!.move(delta),
            submit: () => activated++,
            child: DatabaseObjectSearch(
              key: key,
              model: model,
              controls: controls,
              owner: owner,
              target: data,
              externalQuery: query,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await enterOnButton(tester, 'More');
      expect(backend.client.metadataRequests.single.continuation, 'next-page');
      expect(activated, 0);
    },
  );

  linuxTestWidgets(
    'mounted History details observe B handoff and only reopen B disconnected',
    (tester) async {
      final backend = TestBackend();
      backend.client.historyCatalog = (_) async => rpc.HistoryList(
        entries: [
          rpc.HistoryEntry(id: 'a', target: 'History A'),
          rpc.HistoryEntry(id: 'b', target: 'History B'),
        ],
      );
      backend.client.historyText = (request) async => rpc.HistorySqlChunk(
        text: 'SELECT ${request.entryId};',
        complete: true,
        totalUnits: 9,
      );
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        app(WorkbenchView(model: model, controls: controls)),
      );
      Future<void> choose(String target) async {
        await model.commands!.invoke('history.search', model.commandContext);
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(SearchSidebar),
            matching: find.text(target),
          ),
        );
        await tester.pumpAndSettle();
      }

      await choose('History A');
      final details = tester.state<HistoryViewState>(find.byType(HistoryView));
      final owner = model.activeOwner;
      expect(details.selected, 'a');
      await choose('History B');
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)),
        same(details),
      );
      expect(model.activeOwner, same(owner));
      expect(details.selected, 'b');
      expect((owner.payload as GlobalToolData).history.selected, 'b');
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open as new SQL tab').last);
      await tester.pumpAndSettle();
      expect(backend.client.historySqlRequests.single.entryId, 'b');
      expect(model.document.editor.text, 'SELECT b;');
      expect(model.document.sessionId, isNull);
      expect(backend.client.executions, isEmpty);
      expect(backend.client.opened, isEmpty);
      model.activateOwner(owner.id);
      await tester.pumpAndSettle();
      expect((owner.payload as GlobalToolData).history.selected, 'b');
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).selected,
        'b',
      );
    },
  );

  for (final initiallyEmpty in [false, true]) {
    linuxTestWidgets(
      'reopening shared History refreshes ${initiallyEmpty ? "an empty" : "a cached"} page',
      (tester) async {
        final backend = TestBackend();
        final a = rpc.HistoryEntry(id: 'a', target: 'History A');
        final b = rpc.HistoryEntry(id: 'b', target: 'History B');
        backend.client.historyCatalog = (_) async =>
            rpc.HistoryList(entries: initiallyEmpty ? [] : [a]);
        final model = WorkbenchModel(Directory('/unused'))
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          app(WorkbenchView(model: model, controls: controls)),
        );
        await model.commands!.invoke('history.search', model.commandContext);
        await tester.pumpAndSettle();
        expect(backend.client.historyRequests, hasLength(1));
        tester.widget<SearchSidebar>(find.byType(SearchSidebar)).close();
        await tester.pumpAndSettle();

        final refreshed = Completer<rpc.HistoryList>();
        backend.client.historyCatalog = (_) => refreshed.future;
        await model.commands!.invoke('history.search', model.commandContext);
        await tester.pump();
        await tester.pump();
        expect(backend.client.historyRequests, hasLength(2));
        expect(backend.client.historyRequests.last.search, isEmpty);
        final state = tester.state<HistoryViewState>(find.byType(HistoryView));
        expect(state.busy, isTrue);
        expect(
          state.list!.entries.map((entry) => entry.id),
          initiallyEmpty ? isEmpty : ['a'],
        );
        expect(
          find.text('History A'),
          initiallyEmpty ? findsNothing : findsOneWidget,
        );
        refreshed.complete(
          rpc.HistoryList(entries: initiallyEmpty ? [b] : [a, b]),
        );
        await tester.pumpAndSettle();
        expect(find.text('History B'), findsOneWidget);
        expect(state.busy, isFalse);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened, isEmpty);
      },
    );
  }

  linuxTestWidgets(
    'reopening shared History refreshes its matching page offset',
    (tester) async {
      final backend = TestBackend();
      backend.client.historyCatalog = (request) async => rpc.HistoryList(
        entries: [rpc.HistoryEntry(id: 'a', target: 'History A')],
        limited: true,
        nextOffset: request.offset + 50,
      );
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        app(WorkbenchView(model: model, controls: controls)),
      );
      await model.commands!.invoke('history.search', model.commandContext);
      await tester.pumpAndSettle();
      await enterOnButton(tester, 'Next');
      expect(backend.client.historyRequests.last.offset, 50);
      tester.widget<SearchSidebar>(find.byType(SearchSidebar)).close();
      await tester.pumpAndSettle();
      backend.client.historyCatalog = (_) async => rpc.HistoryList(
        entries: [rpc.HistoryEntry(id: 'b', target: 'History B')],
      );
      await model.commands!.invoke('history.search', model.commandContext);
      await tester.pumpAndSettle();
      expect(backend.client.historyRequests.map((request) => request.offset), [
        0,
        50,
        50,
      ]);
      expect(backend.client.historyRequests.last.search, isEmpty);
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).offset,
        50,
      );
      expect(find.text('History B'), findsOneWidget);
    },
  );

  linuxTestWidgets(
    'History pagination belongs to its query across categories and reopen',
    (tester) async {
      final backend = TestBackend();
      backend.client.historyCatalog = (request) async => rpc.HistoryList(
        limited: true,
        nextOffset: request.offset + 50,
        entries: [
          rpc.HistoryEntry(
            id: '${request.search}-${request.offset}',
            target: 'match',
          ),
        ],
      );
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        app(WorkbenchView(model: model, controls: controls)),
      );
      await model.commands!.invoke('history.search', model.commandContext);
      await tester.pumpAndSettle();
      final query = tester
          .widget<HistoryView>(find.byType(HistoryView))
          .externalQuery!;
      query.text = 'alpha';
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      await enterOnButton(tester, 'Next');
      expect(backend.client.historyRequests.last.offset, 50);
      tester
          .widget<SearchSidebar>(find.byType(SearchSidebar))
          .selectCategory('actions');
      await tester.pumpAndSettle();
      tester
          .widget<SearchSidebar>(find.byType(SearchSidebar))
          .selectCategory('history');
      await tester.pumpAndSettle();
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).offset,
        50,
      );
      tester
          .widget<SearchSidebar>(find.byType(SearchSidebar))
          .selectCategory('actions');
      await tester.pumpAndSettle();
      query.text = 'beta';
      await tester.pumpAndSettle();
      tester
          .widget<SearchSidebar>(find.byType(SearchSidebar))
          .selectCategory('history');
      await tester.pumpAndSettle();
      expect(backend.client.historyRequests.last.search, 'beta');
      expect(backend.client.historyRequests.last.offset, 0);
      expect(
        tester.state<HistoryViewState>(find.byType(HistoryView)).selected,
        isNull,
      );
      await enterOnButton(tester, 'Next');
      tester.widget<SearchSidebar>(find.byType(SearchSidebar)).close();
      await tester.pumpAndSettle();
      await model.commands!.invoke('history.search', model.commandContext);
      await tester.pumpAndSettle();
      expect(backend.client.historyRequests.last.offset, 0);
      final reopened = tester.state<HistoryViewState>(find.byType(HistoryView));
      reopened.search.text = 'gamma';
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(backend.client.historyRequests.last.search, 'gamma');
      expect(backend.client.historyRequests.last.offset, 0);
    },
  );

  linuxTestWidgets(
    'shortcut proposal freezes while saving and retries the same failed proposal',
    (tester) async {
      final writes = <Completer<void>>[], proposals = <Map<String, dynamic>>[];
      final model =
          WorkbenchModel(
              Directory('/unused'),
              presentationWrite: (_, bytes) {
                proposals.add(
                  jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
                );
                final pending = Completer<void>();
                writes.add(pending);
                return pending.future;
              },
            )
            ..draftRecovery = false
            ..newDocument(text: 'SELECT never_execute;');
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        app(WorkbenchView(model: model, controls: controls)),
      );
      await model.commands!.invoke('preferences', model.commandContext);
      await tester.pumpAndSettle();
      final settings = tester.state<WorkbenchSettingsState>(
        find.byType(WorkbenchSettings),
      );
      unawaited(settings.assign('execute'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record shortcut'));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(writes, hasLength(1));
      final shell = tester.widget<BusyDataModalEditorScaffold>(
        find.byType(BusyDataModalEditorScaffold),
      );
      expect(shell.saving, isTrue);
      expect(shell.cancelEnabled, isFalse);
      expect(
        tester
            .widget<BusyDataActionRow>(
              find.ancestor(
                of: find.text('Record shortcut'),
                matching: find.byType(BusyDataActionRow),
              ),
            )
            .onTap,
        isNull,
      );
      final cancel = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Cancel').last,
          matching: find.byType(FilledButton),
        ),
      );
      expect(cancel.onPressed, isNull);
      await tester.tap(find.text('Record shortcut'));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(BusyDataModalEditorScaffold), findsOneWidget);
      expect(model.shortcuts['execute'], 'Ctrl+Enter');
      writes.first.completeError(
        const FileSystemException('temporary preferences write failure'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('The operation could not be completed.'),
        findsOneWidget,
      );
      expect(model.shortcuts['execute'], 'Ctrl+Enter');
      final apply = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Apply'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(apply.onPressed, isNotNull);
      await tester.tap(find.text('Apply'));
      await tester.pump();
      expect(writes, hasLength(2));
      expect((proposals[0]['shortcuts'] as Map)['execute'], 'Ctrl+Alt+Enter');
      expect(proposals[1]['shortcuts'], proposals[0]['shortcuts']);
      writes.last.complete();
      await tester.pumpAndSettle();
      expect(model.shortcuts['execute'], 'Ctrl+Alt+Enter');
      expect(find.byType(BusyDataModalEditorScaffold), findsNothing);
    },
  );

  linuxTestWidgets(
    'shortcut action exposes command, binding, focus and activation as one accessible row',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var presses = 0;
      await tester.pumpWidget(
        app(
          controls.actionRow(
            title: 'Run current statement',
            semanticValue: 'Ctrl+Enter',
            trailing: controls.shortcutBadge('Ctrl+Enter'),
            onPressed: () => presses++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.bySemanticsLabel('Run current statement: Ctrl+Enter');
      expect(row, findsOneWidget);
      expect(find.bySemanticsLabel('Ctrl+Enter'), findsNothing);
      final node = tester.getSemantics(row);
      final data = node.getSemanticsData();
      expect(data.label, 'Run current statement: Ctrl+Enter');
      expect(data.value, isEmpty);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      expect(data.hasAction(ui.SemanticsAction.focus), isTrue);
      tester.binding.performSemanticsAction(
        ui.SemanticsActionEvent(
          viewId: tester.view.viewId,
          nodeId: node.id,
          type: ui.SemanticsAction.focus,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        node.getSemanticsData().flagsCollection.isFocused,
        ui.Tristate.isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(presses, 1);
      semantics.dispose();
    },
  );

  test(
    'supported appearance normalization is shared by save and lookup',
    () async {
      final writes = <Map<String, dynamic>>[];
      final model = WorkbenchModel(
        Directory('/unused'),
        presentationWrite: (_, bytes) async =>
            writes.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>),
      );
      addTearDown(model.dispose);
      for (final (input, expected) in <(String?, String?)>[
        ('en-US', 'en'),
        ('fr_CA', 'fr'),
        ('DE-de', 'de'),
        ('zh-TW', 'zh-Hant'),
        ('zh-CN', 'zh-Hans'),
        ('pt-PT', 'pt-PT'),
        ('pt-BR', null),
        ('pt', null),
        ('xx-US', null),
        ('en--US', null),
        ('en-Latn-US-extra', null),
        (null, null),
      ]) {
        expect(normalizeBusyDataLocaleTag(input), expected, reason: '$input');
        await model.saveAppearance('dark', input);
        expect(writes.last['locale'], expected);
        expect(model.appearancePreference.value, ('dark', expected));
        expect(busyDataLocaleFromTag(input)?.toLanguageTag(), expected);
      }
    },
  );

  test(
    'restored regional language is normalized before later preference saves',
    () async {
      for (final (tag, expected) in [
        ('en-US', 'en'),
        ('fr-CA', 'fr'),
        ('unknown', null),
      ]) {
        final root = await Directory.systemTemp.createTemp(
          'appearance-region-',
        );
        final model = WorkbenchModel(
          root,
          launchBackend: (_) async => TestBackend(),
        );
        try {
          await File('${root.path}/presentation.json').writeAsString(
            jsonEncode({
              'version': 1,
              'rowLimit': 200,
              'draftRecovery': false,
              'themeMode': 'dark',
              'locale': tag,
            }),
          );
          await model.initialize();
          expect(model.appearancePreference.value, ('dark', expected));
          await model.saveShortcut('execute', 'Ctrl+Alt+Enter');
          final persisted =
              jsonDecode(
                    await File('${root.path}/presentation.json').readAsString(),
                  )
                  as Map;
          expect(persisted['locale'], expected);
        } finally {
          model.dispose();
          await root.delete(recursive: true);
        }
      }
    },
  );

  linuxTestWidgets(
    'Appearance safely displays a retained regional or unsupported locale',
    (tester) async {
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..commands = WorkbenchCommandRegistry([]);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
      });
      for (final tag in ['en-US', 'fr-CA', 'xx-US']) {
        model.appearancePreference.value = ('system', tag);
        await tester.pumpWidget(
          app(
            WorkbenchSettings(
              model: model,
              controls: controls,
              close: () {},
              confirmRecovery: () async => false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            tag == 'en-US'
                ? 'English'
                : tag == 'fr-CA'
                ? 'Français'
                : 'System',
          ),
          findsWidgets,
        );
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  linuxTestWidgets(
    'SQL menu shortcuts match dispatch after Settings reserve Ctrl X C V',
    (tester) async {
      final menu = _Menu();
      final model =
          WorkbenchModel(
              Directory('/unused'),
              presentationWrite: (_, _) async {},
            )
            ..draftRecovery = false
            ..newDocument(text: 'alpha beta');
      final control = model.document.editor;
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      final messenger = tester.binding.defaultBinaryMessenger;
      var clipboard = 'initial';
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'Clipboard.getData') return {'text': clipboard};
        if (call.method == 'Clipboard.hasStrings') {
          return {'value': clipboard.isNotEmpty};
        }
        return null;
      });
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      await tester.pumpWidget(
        app(WorkbenchView(model: model, controls: _Controls(menu))),
      );
      await tester.pumpAndSettle();
      await model.commands!.invoke('preferences', model.commandContext);
      await tester.pumpAndSettle();
      final settings = tester.state<WorkbenchSettingsState>(
        find.byType(WorkbenchSettings),
      );
      for (final (key, trigger) in [
        ('save', LogicalKeyboardKey.keyX),
        ('execute', LogicalKeyboardKey.keyC),
        ('script', LogicalKeyboardKey.keyV),
      ]) {
        unawaited(settings.assign(key));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Record shortcut'));
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(trigger);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply'));
        await tester.pumpAndSettle();
      }
      tester.widget<WorkbenchSettings>(find.byType(WorkbenchSettings)).close();
      await tester.pumpAndSettle();
      tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .focusNode!
          .requestFocus();
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      expect(
        menu.actions.take(3).map((action) => action.shortcut),
        everyElement(isNull),
      );
      expect(menu.actions[3].shortcut, 'Ctrl+A');
      menu.result.complete(null);
      await tester.pumpAndSettle();
      final original = control.text;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(control.selectedText, original);
      await model.saveShortcut('save', 'Ctrl+S');
      await model.saveShortcut('execute', 'Ctrl+Enter');
      await model.saveShortcut('script', 'Ctrl+Shift+Enter');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();
      expect(menu.actions.map((action) => action.shortcut), [
        'Ctrl+X',
        'Ctrl+C',
        'Ctrl+V',
        'Ctrl+A',
      ]);
      menu.result.complete(null);
      await tester.pumpAndSettle();
      Future<void> press(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await press(LogicalKeyboardKey.keyC);
      expect(clipboard, original);
      expect(control.text, original);
      await press(LogicalKeyboardKey.keyX);
      expect(clipboard, original);
      expect(control.text, '');
      control.undo();
      expect(control.text, original);
      control.selectAll();
      clipboard = 'replacement';
      await press(LogicalKeyboardKey.keyV);
      expect(control.text, 'replacement');
      control.undo();
      expect(control.text, original);
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  for (final popupControls in <DesktopControls>[
    controls,
    const WindowsControls(),
  ]) {
    testWidgets(
      '${popupControls.runtimeType} real text menu owns focus and invokes Copy after entering an unfocused editor',
      (tester) async {
        final control = SqlEditorController.fromText('select retained;'),
            scroll = SqlEditorScrollController();
        final other = FocusNode();
        var clipboard = '';
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return call.method == 'Clipboard.hasStrings' ? {'value': true} : null;
        });
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          control.dispose();
          scroll.dispose();
          other.dispose();
          messenger.setMockMethodCallHandler(SystemChannels.platform, null);
        });
        final content = Column(
          children: [
            popupControls.button('Other control', () {}, focusNode: other),
            Expanded(
              child: WorkbenchEditorMenu(
                controls: popupControls,
                controller: control,
                scrollController: scroll,
                builder: (toolbar, focus, shortcuts) => SqlEditorTestView(
                  controls: popupControls,
                  controller: control,
                  scrollController: scroll,
                  toolbarController: toolbar,
                  focusNode: focus,
                  shortcutsActivatorsBuilder: shortcuts,
                ),
              ),
            ),
          ],
        );
        await tester.pumpWidget(
          popupControls is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: content))
              : app(content),
        );
        other.requestFocus();
        await tester.pumpAndSettle();
        await tester.tapAt(
          tester.getTopLeft(find.byType(CodeEditor)) + const Offset(90, 24),
          buttons: kSecondaryMouseButton,
        );
        await tester.pumpAndSettle();
        expect(find.text('Cut'), findsOneWidget);
        expect(find.text('Copy'), findsOneWidget);
        await tester.tap(find.text('Copy'));
        await tester.pumpAndSettle();
        expect(clipboard, 'select retained;\n');
        expect(control.text, 'select retained;');
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        expect(find.text('Cut'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      },
      variant: TargetPlatformVariant.only(
        popupControls is WindowsControls
            ? TargetPlatform.windows
            : TargetPlatform.linux,
      ),
    );
  }

  linuxTestWidgets(
    'keyboard SQL menus follow visible caret geometry and clamp offscreen without scrolling',
    (tester) async {
      final menu = _Menu(),
          control = SqlEditorController.fromText(
            List.generate(
              200,
              (i) => 'select distant_column_$i from retained_table;',
            ).join('\n'),
          );
      final scroll = SqlEditorScrollController();
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async =>
            call.method == 'Clipboard.hasStrings' ? {'value': false} : null,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        control.dispose();
        scroll.dispose();
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      await tester.pumpWidget(
        app(
          Center(
            child: SizedBox(
              width: 600,
              height: 300,
              child: WorkbenchEditorMenu(
                controls: _Controls(menu),
                controller: control,
                scrollController: scroll,
                builder: (toolbar, focus, shortcuts) => SqlEditorTestView(
                  controls: _Controls(menu),
                  controller: control,
                  scrollController: scroll,
                  toolbarController: toolbar,
                  focusNode: focus,
                  autofocus: true,
                  shortcutsActivatorsBuilder: shortcuts,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<Offset> showAt(int index, int offset) async {
        control.selection = CodeLineSelection.collapsed(
          index: index,
          offset: offset,
        );
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
        await tester.pumpAndSettle();
        final anchor = menu.position;
        menu.result.complete(null);
        await tester.pumpAndSettle();
        return anchor;
      }

      final first = await showAt(0, 1), second = await showAt(5, 25);
      expect(second.dx, greaterThan(first.dx + 50));
      expect(second.dy, greaterThan(first.dy + 40));
      // Leave the caret on line 5 and scroll its viewport far below that line.
      scroll.verticalScroller.jumpTo(1500);
      await tester.pumpAndSettle();
      final before = scroll.verticalScroller.offset;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(scroll.verticalScroller.offset, before);
      expect(
        tester.getRect(find.byType(CodeEditor)).contains(menu.position),
        isTrue,
      );
      menu.result.complete(null);
      await tester.pumpAndSettle();
      expect(scroll.verticalScroller.offset, before);
    },
  );

  linuxTestWidgets(
    'Welcome hides retained table chrome and returns to the same owner',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final model = WorkbenchModel(Directory('/unused'))
        ..draftRecovery = false
        ..newDocument();
      final profile = rpc.Profile(
        id: 'p',
        name: 'Retained database',
        engine: rpc.Engine.POSTGRESQL,
      );
      model.profiles.add(profile);
      model.sessions['s'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 's',
        profile: profile,
        transaction: rpc.TransactionState.IDLE,
      );
      final owner = model.openTask(
        WorkbenchDocumentKind.table,
        'items',
        object: const DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'items',
        ),
      )..sessionId = 's';
      owner.view.subview = 'data';
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        app(WorkbenchView(model: model, controls: controls)),
      );
      await tester.pumpAndSettle();
      final selector = find.byWidgetPredicate(
        (widget) =>
            widget is BusyDataHeaderIconButton &&
            widget.tooltip?.endsWith(': Data') == true,
      );
      expect(selector, findsOneWidget);
      expect(
        find.text('Data · Retained database / db / public / items'),
        findsOneWidget,
      );
      final state = owner.view;
      model.showWelcome();
      await tester.pumpAndSettle();
      expect(find.text('Create'), findsOneWidget);
      expect(selector, findsNothing);
      expect(
        find.text('Data · Retained database / db / public / items'),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel('Data · Retained database / db / public / items'),
        findsNothing,
      );
      expect(model.activeOwner, same(owner));
      expect(owner.view, same(state));
      model.showWorkbench();
      await tester.pumpAndSettle();
      expect(model.activeOwner, same(owner));
      expect(model.sessions['s']!.profile, same(profile));
      expect(selector, findsOneWidget);
      expect(
        find.text('Data · Retained database / db / public / items'),
        findsOneWidget,
      );
      semantics.dispose();
    },
  );
}

class _Controls extends LinuxControls {
  const _Controls(this.presenter);
  final _Menu presenter;
  @override
  DesktopMenuPresenter createMenuPresenter() => presenter;
}

class _Menu extends DesktopMenuPresenter {
  List<DesktopMenuAction> actions = [];
  Offset position = Offset.zero;
  Completer<int?> result = Completer<int?>();
  @override
  Future<int?> show(
    BuildContext context,
    Offset position,
    List<DesktopMenuAction> actions, {
    bool keyboard = false,
  }) {
    this.position = position;
    this.actions = actions;
    result = Completer<int?>();
    return result.future;
  }

  @override
  Future<void> dismiss() async {}
}

void linuxTestWidgets(String description, WidgetTesterCallback callback) =>
    testWidgets(
      description,
      callback,
      variant: TargetPlatformVariant.only(TargetPlatform.linux),
    );
