import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart'
    show
        Profile,
        SessionInfo,
        ConnectionInfo,
        Engine,
        Environment,
        TransactionState;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/database_explorer.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/ui/common/workbench_shortcut_scope.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:busydata/src/app/linux/linux_header_style.dart';
import 'package:busydata/src/platform/gtk_header_icon_service.dart';
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:re_editor/re_editor.dart';
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';

Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
  bool alt = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  if (alt) await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
  await tester.sendKeyEvent(key);
  if (alt) await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Linux header reflects live bindings without replacing its editor or accessible names',
    (tester) async {
      installNativeWindowFixture(tester);
      final semantics = tester.ensureSemantics();
      var disposed = false;
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('header-shortcuts-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument(text: 'SELECT unchanged_owner;');
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        if (!disposed) semantics.dispose();
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await tester.pumpAndSettle();
      final editor = tester.state(find.byType(CodeEditor));
      final controller = model.document.editor;
      final selection = controller.selection;
      final labels = await AppLocalizations.delegate.load(const Locale('en'));
      Finder button(BusyDataLinuxHeaderIcon icon) => find.byWidgetPredicate(
        (widget) =>
            widget is BusyDataLinuxHeaderIconButton && widget.icon == icon,
      );
      final search = button(BusyDataLinuxHeaderIcon.search);
      final sidebar = button(BusyDataLinuxHeaderIcon.sidebar);
      expect(
        find.byTooltip(
          '${labels.search} · ${model.commands!.command('view.palette').shortcutLabel}',
        ),
        findsOneWidget,
      );
      model.shortcuts['palette'] = 'Ctrl+Alt+K';
      model.shortcuts['explorer'] = 'Ctrl+Alt+E';
      model.updateStatus('Updated effective header shortcuts');
      await tester.pumpAndSettle();
      expect(find.byTooltip('${labels.search} · Ctrl+Alt+K'), findsOneWidget);
      expect(find.byTooltip('${labels.sidebar} · Ctrl+Alt+E'), findsOneWidget);
      expect(
        tester.getSemantics(search).getSemanticsData().label,
        labels.search,
      );
      expect(
        tester.getSemantics(sidebar).getSemanticsData().label,
        labels.sidebar,
      );
      expect(tester.state(find.byType(CodeEditor)), same(editor));
      expect(model.document.editor, same(controller));
      expect(controller.selection, selection);
      expect(controller.text, 'SELECT unchanged_owner;');
      expect(backend.client.executions, isEmpty);
      semantics.dispose();
      disposed = true;
    },
  );

  for (final locale in ['en', 'ar']) {
    testWidgets('shortcut metadata failures use safe $locale feedback', (
      tester,
    ) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('shortcut-feedback-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument();
      model.shortcuts['view.feedback'] = 'Ctrl+B';
      model.commands = WorkbenchCommandRegistry([
        WorkbenchCommand(
          id: 'view.feedback',
          label: 'Feedback',
          category: 'View',
          shortcut: 'Ctrl+B',
          invoke: (_) => throw GrpcError.custom(
            8,
            'private server detail',
            null,
            null,
            {'busydata-rpc-rejection': 'concurrency'},
          ),
        ),
      ]);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: WorkbenchShortcutScope(
            model: model,
            child: const Focus(autofocus: true, child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final localized = AppLocalizations.of(
        tester.element(find.byType(WorkbenchShortcutScope)),
      )!;
      await press(tester, LogicalKeyboardKey.keyB, control: true);
      expect(model.status, localized.backendBusy);
      expect(model.status, isNot(contains('private server detail')));
    });
  }
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} keyboard palette keeps the focused Explorer or SQL physical session',
      (tester) async {
        installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('palette-physical-owner-'),
        ))!;
        final backend = TestBackend();
        final profile = Profile(
          id: 'shared-source',
          name: 'Shared source',
          engine: Engine.POSTGRESQL,
          environment: Environment.STAGING,
          host: 'fixture.invalid',
          port: 5432,
          database: 'busydata',
        );
        const sqlSession = '11111111-1111-1111-1111-111111111111';
        const explorerSession = '22222222-2222-2222-2222-222222222222';
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..profiles.add(profile)
          ..newDocument(text: 'SELECT unchanged_owner;');
        final document = model.document
          ..profileId = profile.id
          ..sessionId = sqlSession;
        final sqlOwner = model.activeOwner;
        for (final entry in [
          (sqlSession, 'sql_schema', 7, 11),
          (explorerSession, 'explorer_schema', 19, 23),
        ]) {
          model.sessions[entry.$1] = SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: entry.$1,
            profile: profile,
            database: ConnectionInfo(product: 'PostgreSQL', version: 'fixture'),
            currentCatalog: 'busydata',
            currentSchema: entry.$2,
            searchPath: [entry.$2],
            contextRevision: Int64(entry.$3),
            sessionRevision: Int64(entry.$4),
            autoCommit: true,
            transaction: TransactionState.IDLE,
          );
        }
        model.explorerSessions[profile.id] = explorerSession;
        model.connectionOwner(profile)
          ..sessionId = explorerSession
          ..evidenceProfile = profile;
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final shell = WorkbenchShortcutScope(
          model: model,
          child: controls is LinuxControls
              ? WorkbenchView(model: model, controls: controls)
              : Row(
                  children: [
                    SizedBox(
                      width: 264,
                      child: DatabaseExplorer(model: model, controls: controls),
                    ),
                    Expanded(
                      child: WorkbenchView(model: model, controls: controls),
                    ),
                  ],
                ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: shell)
              : MaterialApp(home: Scaffold(body: shell)),
        );
        await tester.pumpAndSettle();
        final editorState = tester.state(find.byType(CodeEditor));
        final controller = document.editor;
        final selection = controller.selection;
        final version = document.version;
        final focusTrace = <Map<String, Object?>>[];
        void traceFocus(String phase) {
          final primary = FocusManager.instance.primaryFocus;
          final row = find
              .byWidgetPredicate(
                (widget) =>
                    widget is FocusableActionDetector &&
                    widget.focusNode?.debugLabel == 'Shared source',
              )
              .evaluate()
              .map(
                (element) =>
                    (element.widget as FocusableActionDetector).focusNode,
              )
              .firstOrNull;
          final dynamic state = tester.state(find.byType(WorkbenchView));
          final returnFocus = state.sharedSearch.returnFocus as FocusNode?;
          Map<String, Object?> node(FocusNode? value) => {
            'identity': value == null ? null : identityHashCode(value),
            'label': value?.debugLabel,
            'widget': value?.context?.widget.runtimeType.toString(),
            'mounted': value?.context?.mounted,
            'canRequestFocus': value?.canRequestFocus,
            'hasFocus': value?.hasFocus,
          };
          focusTrace.add({
            'phase': phase,
            'primary': node(primary),
            'returnFocus': node(returnFocus),
            'explorerRow': node(row),
            'explorerScope': node(model.explorerFocus),
            'rowExclusions': [
              for (final ancestor in row?.ancestors ?? <FocusNode>[])
                if (!ancestor.descendantsAreFocusable)
                  ancestor.debugLabel ?? ancestor.runtimeType.toString(),
            ],
            'activeOwner': model.activeOwner.id,
            'activeSession': model.activeOwner.sessionId,
            'editorHasFocus': model.documentFocus.hasFocus,
          });
        }

        Future<void> inspectPhysicalSession(
          String expectedSession,
          String expectedSchema, {
          required bool explorer,
        }) async {
          final origin = FocusManager.instance.primaryFocus;
          traceFocus('before-palette-$explorer');
          await press(
            tester,
            LogicalKeyboardKey.keyP,
            control: true,
            shift: true,
          );
          traceFocus('palette-open-$explorer');
          final palette = tester.widget<SearchResultList>(
            find.byType(SearchResultList),
          );
          if (explorer && controls is LinuxControls) {
            expect(origin?.context?.mounted, isTrue);
            expect(origin!.canRequestFocus, isFalse);
            origin.requestFocus();
            FocusManager.instance.applyFocusChangesIfNeeded();
            expect(model.explorerFocus.hasFocus, isFalse);
            expect(palette.queryFocus.hasFocus, isTrue);
          }
          final target = palette.target;
          await tester.enterText(
            find.byWidgetPredicate(
              (widget) =>
                  widget is EditableText && widget.controller == palette.query,
            ),
            'Session details',
          );
          await tester.pumpAndSettle();
          traceFocus('before-session-details-$explorer');
          await press(tester, LogicalKeyboardKey.enter);
          traceFocus('session-details-open-$explorer');
          expect(find.byType(SearchResultList), findsNothing);
          final details = tester.widget<SelectableText>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SelectableText &&
                  (widget.data?.contains('Physical session: ') ?? false),
            ),
          );
          expect(
            details.data,
            contains('Physical session: $expectedSession'),
            reason:
                'The actual connection.details registry command must use the keyboard palette origin',
          );
          expect(details.data, contains('Live schema: $expectedSchema'));
          expect(target.sessionId, expectedSession);
          if (explorer) {
            expect(target.owner, isNull);
            expect(target.metadataSources[profile.id], (
              sessionId: explorerSession,
              contextRevision: 19,
              sessionRevision: 23,
            ));
          } else {
            expect(target.owner, same(sqlOwner));
          }
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          traceFocus('after-cancel-$explorer');
          expect(
            explorer
                ? model.explorerFocus.hasFocus
                : model.documentFocus.hasFocus,
            isTrue,
            reason: jsonEncode(focusTrace),
          );
          expect(model.activeOwner, same(sqlOwner));
          expect(model.document, same(document));
          expect(document.editor, same(controller));
          expect(tester.state(find.byType(CodeEditor)), same(editorState));
          expect(controller.text, 'SELECT unchanged_owner;');
          expect(controller.selection, selection);
          expect(document.version, version);
          expect(document.sessionId, sqlSession);
          expect(model.explorerSessions[profile.id], explorerSession);
          expect(backend.client.opened, isEmpty);
          expect(backend.client.executions, isEmpty);
          expect(backend.client.browseRequests, isEmpty);
        }

        await tester.tap(
          find.descendant(
            of: find.byType(DatabaseExplorer),
            matching: find.text('Shared source'),
          ),
        );
        await tester.pumpAndSettle();
        expect(model.explorerFocus.hasFocus, isTrue);
        await inspectPhysicalSession(
          explorerSession,
          'explorer_schema',
          explorer: true,
        );
        if (controls is LinuxControls) {
          // Escape must observe the same real close rebuild as a command,
          // restoring the retained row without making hidden rows focusable.
          final origin = FocusManager.instance.primaryFocus;
          await press(
            tester,
            LogicalKeyboardKey.keyP,
            control: true,
            shift: true,
          );
          expect(origin!.canRequestFocus, isFalse);
          await press(tester, LogicalKeyboardKey.escape);
          expect(find.byType(SearchResultList), findsNothing);
          expect(FocusManager.instance.primaryFocus, same(origin));
          expect(model.explorerFocus.hasFocus, isTrue);

          await press(
            tester,
            LogicalKeyboardKey.keyP,
            control: true,
            shift: true,
          );
          final dynamic state = tester.state(find.byType(WorkbenchView));
          final directClose = state.closeActionSearch() as Future<bool>;
          expect(state.closeActionSearch(), same(directClose));
          expect(state.sharedSearch.closeFocus.hasPrimaryFocus, isTrue);
          await tester.pumpAndSettle();
          expect(await directClose, isTrue);
          expect(FocusManager.instance.primaryFocus, same(origin));

          await press(
            tester,
            LogicalKeyboardKey.keyP,
            control: true,
            shift: true,
          );
          void reopenFromRestoredOrigin() {
            if (origin.hasPrimaryFocus) state.openSharedSearch('actions');
          }

          origin.addListener(reopenFromRestoredOrigin);
          try {
            final superseded =
                state.activateSearchCommand('connection.details')
                    as Future<void>;
            await tester.pumpAndSettle();
            await superseded;
            expect(find.byType(SearchResultList), findsOneWidget);
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is SelectableText &&
                    (widget.data?.contains('Physical session: ') ?? false),
              ),
              findsNothing,
            );
          } finally {
            origin.removeListener(reopenFromRestoredOrigin);
          }
          // Explicitly retire the replacement interaction before the next
          // case. Suppressing restoration must not start another handoff.
          expect(
            await (state.closeActionSearch(restoreFocus: false)
                as Future<bool>),
            isTrue,
          );
          await tester.pumpAndSettle();
          origin.requestFocus();
          await tester.pumpAndSettle();

          await press(
            tester,
            LogicalKeyboardKey.keyP,
            control: true,
            shift: true,
          );
          final activation =
              state.activateSearchCommand('connection.details') as Future<void>;
          expect(state.sharedSearch.target, isNull);
          expect(state.sharedSearch.closeFocus.hasPrimaryFocus, isTrue);
          // A deliberate newer owner during that close frame retires the
          // queued command, rather than restoring Explorer or opening a modal.
          model.documentFocus.requestFocus();
          FocusManager.instance.applyFocusChangesIfNeeded();
          await tester.pumpAndSettle();
          await activation;
          expect(model.documentFocus.hasFocus, isTrue);
          expect(model.explorerFocus.hasFocus, isFalse);
          expect(find.byType(SearchResultList), findsNothing);
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is SelectableText &&
                  (widget.data?.contains('Physical session: ') ?? false),
            ),
            findsNothing,
          );
        }
        model.documentFocus.requestFocus();
        await tester.pumpAndSettle();
        expect(model.documentFocus.hasFocus, isTrue);
        await inspectPhysicalSession(sqlSession, 'sql_schema', explorer: false);
      },
    );
    testWidgets(
      '${controls.runtimeType} console chooser matches numbered tabs and disambiguates saved file names',
      (tester) async {
        installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('console-names-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend;
        model.profiles.addAll([
          Profile(id: 'saved', name: 'Saved connection'),
          Profile(id: 'other', name: 'Other connection'),
        ]);
        model.newDocument(text: 'SELECT first_unsaved');
        final first = model.document
          ..profileId = 'saved'
          ..connectionCatalog = 'busydata'
          ..connectionSchema = 'public';
        model.newDocument(text: 'SELECT unrelated');
        model.document.profileId = 'other';
        model.newDocument(text: 'SELECT second_unsaved');
        final second = model.document
          ..profileId = 'saved'
          ..connectionCatalog = 'busydata_desired'
          ..connectionSchema = 'public';
        for (final directory in ['one', 'two']) {
          model.newDocument(path: '${root.path}/$directory/query.sql');
          model.document
            ..profileId = 'saved'
            ..connectionCatalog = 'busydata'
            ..connectionSchema = 'public';
        }
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        final shell = WorkbenchShortcutScope(
          model: model,
          child: controls is LinuxControls
              ? WorkbenchView(model: model, controls: controls)
              : Row(
                  children: [
                    SizedBox(
                      width: 264,
                      child: DatabaseExplorer(model: model, controls: controls),
                    ),
                    Expanded(
                      child: WorkbenchView(model: model, controls: controls),
                    ),
                  ],
                ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: shell)
              : MaterialApp(home: Scaffold(body: shell)),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(DatabaseExplorer),
            matching: find.text('Saved connection'),
          ),
        );
        await press(tester, LogicalKeyboardKey.f10, control: true, shift: true);
        expect(find.text('Query 1 · busydata / public'), findsOneWidget);
        expect(
          find.text('Query 3 · busydata_desired / public'),
          findsOneWidget,
        );
        expect(find.textContaining('Untitled query ·'), findsNothing);
        expect(find.textContaining('Query 2 ·'), findsNothing);
        for (final directory in ['one', 'two']) {
          expect(
            find.text(
              'query.sql · ${root.path}/$directory/query.sql · busydata / public',
            ),
            findsOneWidget,
          );
        }
        await tester.tap(find.text('Query 1 · busydata / public'));
        await tester.pumpAndSettle();
        expect(model.document, same(first));
        expect(first.editor.text, 'SELECT first_unsaved');
        expect(second.editor.text, 'SELECT second_unsaved');
        expect(second.connectionCatalog, 'busydata_desired');
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened, isEmpty);
      },
    );
    testWidgets(
      '${controls.runtimeType} Explorer shares palette, remapped keys and pane traversal without running SQL',
      (tester) async {
        installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('shell-keys-'),
        ))!;
        final backend = TestBackend();
        final nativeMenus = <MethodCall>[];
        const nativeMenuChannel = MethodChannel(nativeMenuChannelName);
        if (controls is LinuxControls) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(nativeMenuChannel, (call) async {
                nativeMenus.add(call);
                return null;
              });
          addTearDown(
            () => TestDefaultBinaryMessengerBinding
                .instance
                .defaultBinaryMessenger
                .setMockMethodCallHandler(nativeMenuChannel, null),
          );
        }
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        model.profiles.add(Profile(id: 'saved', name: 'Saved connection'));
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        final shell = WorkbenchShortcutScope(
          model: model,
          child: ListenableBuilder(
            listenable: model,
            builder: (context, _) => controls is LinuxControls
                ? WorkbenchView(model: model, controls: controls)
                : Row(
                    children: [
                      if (model.explorerVisible)
                        SizedBox(
                          width: 264,
                          child: DatabaseExplorer(
                            model: model,
                            controls: controls,
                          ),
                        ),
                      Expanded(
                        child: WorkbenchView(model: model, controls: controls),
                      ),
                    ],
                  ),
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: shell)
              : MaterialApp(home: Scaffold(body: shell)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saved connection'));
        await tester.pump();
        expect(model.explorerFocus.hasFocus, isTrue);
        await press(tester, LogicalKeyboardKey.f10, control: true, shift: true);
        expect(find.text('Query consoles'), findsOneWidget);
        expect(
          find.text('Edit connection'),
          findsNothing,
          reason:
              'Ctrl+Shift+F10 must reach the console chooser, not the tree context menu',
        );
        expect(model.documents, hasLength(1));
        expect(backend.client.executions, isEmpty);
        expect(nativeMenus.where((call) => call.method == 'show'), isEmpty);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        tester
            .widget<FocusableActionDetector>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is FocusableActionDetector &&
                    widget.focusNode?.debugLabel == 'Saved connection',
              ),
            )
            .focusNode!
            .requestFocus();
        await tester.pump();
        await press(tester, LogicalKeyboardKey.f10, shift: true);
        if (controls is LinuxControls) {
          final opened = nativeMenus
              .where((call) => call.method == 'show')
              .single;
          expect(
            (opened.arguments as Map)['entries'],
            contains(containsPair('label', 'Edit connection')),
          );
        } else {
          expect(find.text('Edit connection'), findsOneWidget);
        }
        await press(tester, LogicalKeyboardKey.escape);
        tester
            .widget<FocusableActionDetector>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is FocusableActionDetector &&
                    widget.focusNode?.debugLabel == 'Saved connection',
              ),
            )
            .focusNode!
            .requestFocus();
        await tester.pump();
        await press(tester, LogicalKeyboardKey.enter, control: true);
        expect(backend.client.executions, isEmpty);
        await press(
          tester,
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
        );
        expect(find.byType(SearchResultList), findsOneWidget);
        await press(tester, LogicalKeyboardKey.keyT, control: true);
        expect(
          model.documents,
          hasLength(1),
          reason: 'A modal palette must isolate query creation',
        );
        await press(tester, LogicalKeyboardKey.escape);
        expect(find.byType(SearchResultList), findsNothing);
        model.shortcuts['palette'] = 'Ctrl+Shift+K';
        model.updateStatus('Remapped palette');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Saved connection'));
        await press(
          tester,
          LogicalKeyboardKey.keyK,
          control: true,
          shift: true,
        );
        expect(find.byType(SearchResultList), findsOneWidget);
        await press(tester, LogicalKeyboardKey.escape);
        await tester.tap(find.text('Saved connection'));
        await press(tester, LogicalKeyboardKey.f6);
        expect(model.targetFocus.hasFocus, isTrue);
        await press(tester, LogicalKeyboardKey.f6);
        expect(model.documentFocus.hasFocus, isTrue);
        model.setExplorerVisible(false);
        await tester.pumpAndSettle();
        expect(find.byType(DatabaseExplorer).hitTestable(), findsNothing);
        await press(tester, LogicalKeyboardKey.digit1, alt: true);
        expect(model.explorerFocus.hasFocus, isTrue);
        expect(backend.client.executions, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(() => root.delete(recursive: true));
      },
    );
  }
}
