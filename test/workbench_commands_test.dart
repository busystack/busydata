import 'dart:async';
import 'dart:convert';
import 'package:re_editor/re_editor.dart';
import 'support/presentation_fonts.dart';
import 'dart:io';
import 'dart:ui' show Tristate, SemanticsAction;
import 'dart:ui' as engine show KeyData, KeyEventType;

import 'package:busydata/src/backend/generated/busydata.pb.dart' hide Column;
import 'package:busydata/src/backend/generated/busydata.pb.dart'
    as rpc
    show Row, Column;
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart'
    show ComparisonDocument;
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:fixnum/fixnum.dart';
import 'package:grpc/grpc.dart' show GrpcError;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/browse_selection_fixture.dart';
import 'support/connection_widgets.dart';

void main() {
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final throughSearch in [false, true]) {
      for (final (deferredRouteFocus, keyboardDismiss, synchronousBurst) in [
        (false, false, false),
        (false, true, false),
        (true, true, false),
        (false, true, true),
      ]) {
        for (final reducedMotion in [false, true]) {
          testWidgets(
            '${ui.runtimeType} retiring Owned sessions preserves palette focus, reduced motion $reducedMotion, deferred route focus $deferredRouteFocus, through search $throughSearch, keyboard dismissal $keyboardDismiss, synchronous burst $synchronousBurst',
            (tester) async {
              final root = (await tester.runAsync(
                () => Directory.systemTemp.createTemp('rapid-palette-'),
              ))!;
              final model = WorkbenchModel(root)
                ..draftRecovery = false
                ..newDocument(text: 'SELECT original_owner');
              final document = model.document;
              addTearDown(() async {
                await tester.pumpWidget(const SizedBox.shrink());
                model.dispose();
                await tester.runAsync(() => root.delete(recursive: true));
              });
              Widget withMotion(BuildContext context, Widget? child) =>
                  MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(disableAnimations: reducedMotion),
                    child: child!,
                  );
              await tester.pumpWidget(
                ui is LinuxControls
                    ? MaterialApp(
                        theme: presentationTheme(Brightness.light),
                        builder: withMotion,
                        onGenerateRoute: (_) => MaterialPageRoute<void>(
                          requestFocus: !deferredRouteFocus,
                          builder: (_) => Scaffold(
                            body: WorkbenchView(model: model, controls: ui),
                          ),
                        ),
                      )
                    : fluent.FluentApp(
                        builder: withMotion,
                        onGenerateRoute: (_) => _TestFluentPageRoute<void>(
                          requestFocus: !deferredRouteFocus,
                          builder: (_) =>
                              WorkbenchView(model: model, controls: ui),
                        ),
                      ),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.byType(CodeEditor));
              await tester.pump();
              final editorFocus = FocusManager.instance.primaryFocus!;
              final original = document.editor.value;
              void trace(String phase) {
                final focus = FocusManager.instance.primaryFocus;
                final route = focus?.context == null
                    ? null
                    : ModalRoute.of(focus!.context!);
                debugPrint(
                  jsonEncode({
                    'phase': phase,
                    'document': document.id,
                    'focus': focus?.debugLabel,
                    'focusIdentity': identityHashCode(focus),
                    'route': route?.runtimeType.toString(),
                    'routeIdentity': identityHashCode(route),
                    'routeCurrent': route?.isCurrent,
                    'disableAnimations': focus?.context == null
                        ? null
                        : MediaQuery.disableAnimationsOf(focus!.context!),
                    'deferredRouteFocus': deferredRouteFocus,
                    'sql': document.editor.text,
                    'selectionBase': document.editor.value.selection.baseOffset,
                    'selectionExtent':
                        document.editor.value.selection.extentOffset,
                  }),
                );
              }

              Future<void> shortcut() async {
                await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
                await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
                await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
                await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
                await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
              }

              void closeAndShortcutBurst() {
                final keys = [
                  (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter, true),
                  (LogicalKeyboardKey.enter, PhysicalKeyboardKey.enter, false),
                  (
                    LogicalKeyboardKey.controlLeft,
                    PhysicalKeyboardKey.controlLeft,
                    true,
                  ),
                  (
                    LogicalKeyboardKey.shiftLeft,
                    PhysicalKeyboardKey.shiftLeft,
                    true,
                  ),
                  (LogicalKeyboardKey.keyP, PhysicalKeyboardKey.keyP, true),
                  (LogicalKeyboardKey.keyP, PhysicalKeyboardKey.keyP, false),
                  (
                    LogicalKeyboardKey.shiftLeft,
                    PhysicalKeyboardKey.shiftLeft,
                    false,
                  ),
                  (
                    LogicalKeyboardKey.controlLeft,
                    PhysicalKeyboardKey.controlLeft,
                    false,
                  ),
                ];
                // Deliver the same paired native channels as Flutter's public
                // key simulator, without awaiting replies between events.
                for (final (index, (logical, physical, down)) in keys.indexed) {
                  tester.platformDispatcher.onKeyData!(
                    engine.KeyData(
                      timeStamp: Duration(microseconds: index + 1),
                      type: down
                          ? engine.KeyEventType.down
                          : engine.KeyEventType.up,
                      physical: physical.usbHidUsage,
                      logical: logical.keyId,
                      synthesized: false,
                      character: down && logical == LogicalKeyboardKey.keyP
                          ? 'p'
                          : null,
                    ),
                  );
                  tester.binding.channelBuffers.push(
                    SystemChannels.keyEvent.name,
                    SystemChannels.keyEvent.codec.encodeMessage(
                      KeyEventSimulator.getKeyData(
                        logical,
                        platform: 'linux',
                        physicalKey: physical,
                        isDown: down,
                      ),
                    ),
                    (_) {},
                  );
                  if (down && logical == LogicalKeyboardKey.enter) {
                    trace('burst-close-dispatched');
                  } else if (down && logical == LogicalKeyboardKey.keyP) {
                    trace('burst-palette-dispatched');
                  }
                }
                expect(HardwareKeyboard.instance.logicalKeysPressed, isEmpty);
              }

              for (var attempt = 0; attempt < 3; attempt++) {
                Future<void>? sessions;
                if (throughSearch) {
                  await shortcut();
                  await tester.pumpAndSettle();
                  final query = find.descendant(
                    of: find.byType(SearchHeaderField),
                    matching: find.byType(EditableText),
                  );
                  await tester.enterText(query, 'Owned sessions');
                  await tester.pump();
                  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
                } else {
                  sessions = model.commands!.invoke(
                    'view.sessions',
                    model.commandContext,
                  );
                }
                await tester.pumpAndSettle();
                final retiringRoute = ModalRoute.of(
                  tester.element(find.text('Close').last),
                )!;
                expect(
                  MediaQuery.disableAnimationsOf(
                    FocusManager.instance.primaryFocus!.context!,
                  ),
                  reducedMotion,
                );
                trace('before-dismiss-$attempt');
                if (keyboardDismiss) {
                  final closeFocus = Focus.of(
                    tester.element(find.text('Close').last),
                  );
                  closeFocus.requestFocus();
                  await tester
                      .pump(); // Establish Close focus before dismissal.
                  expect(FocusManager.instance.primaryFocus, same(closeFocus));
                  expect(
                    ModalRoute.of(closeFocus.context!),
                    same(retiringRoute),
                  );
                  expect(retiringRoute.isCurrent, isTrue);
                  expect(document.editor.value, original);
                  trace('close-ready-$attempt');
                  if (synchronousBurst) {
                    closeAndShortcutBurst();
                  } else {
                    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
                  }
                  // No frame between dismissal and the next shortcut. Some
                  // variants also disable the page route's automatic focus.
                } else {
                  await tester.tap(find.text('Close').last);
                  await tester.pump(); // Retirement begins; do not settle.
                }
                trace('retiring-$attempt');
                if (!synchronousBurst) await shortcut();
                await tester.pump();
                await tester.pump(const Duration(milliseconds: 30));
                expect(find.byType(SearchResultList), findsOneWidget);
                expect(
                  MediaQuery.disableAnimationsOf(
                    tester.element(find.byType(SearchResultList)),
                  ),
                  reducedMotion,
                );
                trace('palette-open-$attempt');
                final query = find.descendant(
                  of: find.byType(SearchHeaderField),
                  matching: find.byType(EditableText),
                );
                expect(
                  tester.widget<EditableText>(query).focusNode.hasFocus,
                  isTrue,
                );
                tester.testTextInput.enterText('sn');
                await tester.pump();
                trace('first-characters-$attempt');
                await tester.pump(const Duration(milliseconds: 250));
                await (sessions ?? retiringRoute.completed);
                trace('older-route-completed-$attempt');
                // The older route completes after the newer route has taken focus.
                expect(
                  tester.widget<EditableText>(query).focusNode.hasFocus,
                  isTrue,
                );
                tester.testTextInput.enterText('snp');
                await tester.pump();
                expect(
                  tester.widget<EditableText>(query).controller.text,
                  'snp',
                );
                expect(document.editor.value, original);
                expect(model.document, same(document));
                await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
                await tester.sendKeyEvent(LogicalKeyboardKey.escape);
                await tester.pumpAndSettle();
                trace('palette-closed-$attempt');
                expect(editorFocus.hasFocus, isTrue);
                expect(document.editor.value, original);
              }
            },
          );
        }
      }
    }
  }
  testWidgets(
    'Quick Documentation closes with Escape without loading a schema or submitting SQL',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('quick-doc-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..profiles.add(Profile(id: 'source', name: 'Source'))
        ..newDocument(text: 'SELECT untouched');
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final pending = model.commands!.invoke(
        'object.documentation',
        WorkbenchCommandContext(
          profileId: 'source',
          object: const DatabaseObjectIdentity(
            profileId: 'source',
            catalog: 'second',
            schema: 'audit',
            kind: ObjectKind.TABLE,
            name: 'customers',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Source / second / audit / customers'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await pending;
      expect(find.text('Source / second / audit / customers'), findsNothing);
      expect(backend.client.metadataRequests, isEmpty);
      expect(backend.client.schemaToolRequests, isEmpty);
      expect(backend.client.executions, isEmpty);
      for (final subtype in [
        ObjectSubtype.PARTITIONED_TABLE,
        ObjectSubtype.FOREIGN_TABLE,
      ]) {
        final unavailable = WorkbenchCommandContext(
          profileId: 'source',
          object: DatabaseObjectIdentity(
            profileId: 'source',
            catalog: 'second',
            schema: 'audit',
            kind: ObjectKind.TABLE,
            subtype: subtype,
            name: 'customers',
          ),
        );
        expect(
          model.commands!.command('object.ddl').disabledReason!(unavailable),
          contains('no supported native definition'),
        );
        await expectLater(
          model.commands!.invoke('object.ddl', unavailable),
          throwsStateError,
        );
      }
      expect(backend.client.schemaToolRequests, isEmpty);
    },
  );
  testWidgets(
    'captured tree scope cannot create a console after a source session replacement',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('stale-tree-command-'),
      ))!;
      final backend = TestBackend();
      final profile = Profile(id: 'source', name: 'Source');
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..profiles.add(profile)
        ..newDocument(text: 'SELECT retained');
      model.explorerSessions[profile.id] = 'old';
      model.sessions['old'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'old',
        profile: profile,
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final captured = WorkbenchCommandContext(
        profileId: profile.id,
        sessionId: 'old',
        metadataInstance: backend.instanceId,
        metadataSources: {
          'source': (sessionId: 'old', contextRevision: 0, sessionRevision: 0),
        },
        creationScope: const DatabaseCreationScope(
          profileId: 'source',
          catalog: 'first',
          schema: 'public',
        ),
      );
      model.sessions['new'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'new',
        profile: profile,
        currentCatalog: 'second',
      );
      model.explorerSessions[profile.id] = 'new';
      await expectLater(
        model.commands!.invoke('file.new', captured),
        throwsStateError,
      );
      expect(model.documents.length, 1);
      expect(model.document.editor.text, 'SELECT retained');
      expect(backend.client.opened, isEmpty);
      expect(backend.client.executions, isEmpty);
    },
  );
  testWidgets(
    'two-table compare captures exact databases and generates a scoped console without execution',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('scoped-compare-'),
      ))!;
      final backend = TestBackend();
      final profile = Profile(
        id: 'source',
        name: 'Source',
        engine: Engine.POSTGRESQL,
        database: 'saved_default',
      );
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..profiles.add(profile)
        ..newDocument(text: 'SELECT preserved');
      model.connectionOwner(profile).sessionId = 'inspection';
      model.explorerSessions[profile.id] = 'inspection';
      model.sessions['inspection'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'inspection',
        profile: profile,
        currentCatalog: 'saved_default',
        currentSchema: 'public',
      );
      backend.client.schemaTools = (request) async =>
          request.action == SchemaToolAction.CAPTURE_SCHEMA
          ? SchemaToolResult(
              snapshot: '{"database":"${request.catalog}"}',
              inspectedObject: SchemaObject(
                catalog: request.catalog,
                schema: request.schema,
                name: request.table,
                kind: ObjectKind.TABLE,
                subtype: ObjectSubtype.ORDINARY_TABLE,
              ),
            )
          : SchemaToolResult(
              complete: true,
              sql: [
                'ALTER TABLE public.customers ADD COLUMN reviewed integer;',
              ],
              differences: [
                SchemaDifference(
                  name: 'customers',
                  kind: 'tables',
                  state: 'changed',
                ),
              ],
            );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await tester.pumpAndSettle();
      const current = DatabaseObjectIdentity(
        profileId: 'source',
        catalog: 'first',
        schema: 'public',
        kind: ObjectKind.TABLE,
        subtype: ObjectSubtype.ORDINARY_TABLE,
        name: 'customers',
      );
      const desired = DatabaseObjectIdentity(
        profileId: 'source',
        catalog: 'second',
        schema: 'public',
        kind: ObjectKind.TABLE,
        subtype: ObjectSubtype.ORDINARY_TABLE,
        name: 'customers',
      );
      const command = WorkbenchCommandContext(
        profileId: 'source',
        objects: [current, desired],
      );
      expect(
        model.commands!.command('object.compare').disabledReason!(command),
        isNull,
      );
      await model.commands!.invoke('object.compare', command);
      await tester.pumpAndSettle();
      final captures = backend.client.schemaToolRequests
          .where((r) => r.action == SchemaToolAction.CAPTURE_SCHEMA)
          .toList();
      expect(captures.map((r) => r.catalog), ['first', 'second']);
      expect(
        captures.every((r) => r.schema == 'public' && r.table == 'customers'),
        isTrue,
      );
      final compare = backend.client.schemaToolRequests.singleWhere(
        (r) => r.action == SchemaToolAction.COMPARE_SCHEMA,
      );
      expect(compare.sourceSnapshot, contains('first'));
      expect(compare.targetSnapshot, contains('second'));
      await tester.scrollUntilVisible(
        find.text('Open SQL'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ComparisonDocument),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(
        find.text('ALTER TABLE public.customers ADD COLUMN reviewed integer;'),
        findsOneWidget,
      );
      await tester.tap(find.text('Open SQL').last);
      await tester.pumpAndSettle();
      expect(model.document.profileId, profile.id);
      expect(model.document.connectionCatalog, 'first');
      expect(model.document.connectionSchema, 'public');
      expect(model.document.sessionId, isNull);
      expect(model.documents.first.editor.text, 'SELECT preserved');
      expect(model.sessions['inspection']!.currentCatalog, 'saved_default');
      expect(backend.client.executions, isEmpty);
      expect(
        model.commands!.command('object.compare').disabledReason!(
          const WorkbenchCommandContext(objects: [current]),
        ),
        isNotNull,
      );
    },
  );
  for (final wrongDatabase in [false, true]) {
    testWidgets(
      'object definition retains exact database identity; wrong reply $wrongDatabase',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('exact-definition-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: 'SELECT 71;');
        final profile = Profile(
          id: 'source',
          name: 'Source',
          engine: Engine.POSTGRESQL,
          database: 'first_database',
        );
        model.profiles.add(profile);
        model.connectionOwner(profile).sessionId = 'inspection';
        model.explorerSessions['source'] = 'inspection';
        model.sessions['inspection'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'inspection',
          profile: profile,
          currentCatalog: 'first_database',
          currentSchema: 'public',
        );
        var nativeDefinition =
            'CREATE TABLE public.customers (second_database integer);';
        backend.client.schemaTools = (request) async => SchemaToolResult(
          inspectedObject: SchemaObject(
            name: request.table,
            kind: request.kind,
            catalog: wrongDatabase ? 'first_database' : request.catalog,
            schema: request.schema,
            identifier: request.identifier,
          ),
          definition: nativeDefinition,
          provenance: 'native',
          complete: true,
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.pumpWidget(
          MaterialApp(
            home: WorkbenchView(model: model, controls: const LinuxControls()),
          ),
        );
        await tester.pumpAndSettle();
        final scoped = const WorkbenchCommandContext(
          profileId: 'source',
          sessionId: 'inspection',
          object: DatabaseObjectIdentity(
            profileId: 'source',
            catalog: 'second_database',
            schema: 'public',
            kind: ObjectKind.TABLE,
            name: 'customers',
          ),
        );
        expect(
          model.commands!
              .command('schema.designer')
              .disabledReason
              ?.call(scoped),
          contains('second_database'),
        );
        await model.commands!.invoke(
          'object.ddl',
          const WorkbenchCommandContext(
            profileId: 'source',
            sessionId: 'inspection',
            object: DatabaseObjectIdentity(
              profileId: 'source',
              catalog: 'second_database',
              schema: 'public',
              kind: ObjectKind.TABLE,
              name: 'customers',
            ),
          ),
        );
        await tester.pumpAndSettle();
        final request = backend.client.schemaToolRequests.single;
        expect(request.action, SchemaToolAction.OBJECT_DEFINITION);
        expect(request.catalog, 'second_database');
        expect(request.schema, 'public');
        expect(request.table, 'customers');
        expect(
          find.textContaining('CREATE TABLE public.customers'),
          wrongDatabase ? findsNothing : findsOneWidget,
        );
        if (!wrongDatabase) {
          nativeDefinition =
              'CREATE TABLE public.customers (external_change text);';
          await model.commands!.invoke('object.ddl', scoped);
          await tester.pumpAndSettle();
          expect(backend.client.schemaToolRequests, hasLength(2));
          expect(find.textContaining('external_change'), findsOneWidget);
        }
        expect(model.document.editor.text, 'SELECT 71;');
        expect(backend.client.executions, isEmpty);
      },
    );
  }
  testWidgets('category New Query preserves scope and the existing document', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('category-query-'),
    ))!;
    final backend = TestBackend();
    final model = WorkbenchModel(root)
      ..draftRecovery = false
      ..backend = backend
      ..newDocument(text: 'SELECT 71;');
    final previous = model.document;
    previous.profileId = 'other-source';
    model.profiles.add(Profile(id: 'selected-source'));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    });
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchView(model: model, controls: const LinuxControls()),
      ),
    );
    await tester.pumpAndSettle();
    await model.commands!.invoke(
      'file.new',
      const WorkbenchCommandContext(
        profileId: 'selected-source',
        creationScope: DatabaseCreationScope(
          profileId: 'selected-source',
          catalog: 'second_database',
          schema: 'Quoted scope',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(model.document, isNot(same(previous)));
    expect(model.document.profileId, 'selected-source');
    expect(model.document.connectionCatalog, 'second_database');
    expect(model.document.connectionSchema, 'Quoted scope');
    expect(model.document.sessionId, isNull);
    expect(previous.editor.text, 'SELECT 71;');
    expect(previous.profileId, 'other-source');
    expect(backend.client.executions, isEmpty);
  });
  for (final entry in <(GrpcError, String)>[
    (
      GrpcError.custom(8, 'private server text', null, null, {
        'busydata-rpc-rejection': 'concurrency',
      }),
      'The backend is busy. Wait for the current request, then try again.',
    ),
    (
      GrpcError.resourceExhausted(
        'RPC concurrency limit reached; private server text',
      ),
      'The request was not confirmed (RPC 8).',
    ),
    (
      GrpcError.unavailable('wrong password; TLS invalid; private server text'),
      'The request was not confirmed (RPC 14).',
    ),
  ]) {
    testWidgets(
      'Run rejection keeps prior output and shows safe feedback: ${entry.$2}',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('run-feedback-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(text: 'SELECT 23');
        final profile = Profile(
          id: 'p',
          name: 'Scoped source',
          engine: Engine.POSTGRESQL,
        );
        model.profiles.add(profile);
        model.document.profileId = 'p';
        model.document.sessionId = 's';
        model.profiles.add(Profile(id: 'p', name: 'Captured target'));
        model.sessions['s'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 's',
          profile: profile,
          transaction: TransactionState.IDLE,
          autoCommit: true,
        );
        final owner = model.activeOwner;
        model.track(
          JobInfo(
            jobId: 'previous-job',
            executionId: 'previous-execution',
            state: JobState.COMPLETED,
            results: [
              StatementResult(
                resultId: 'previous-result',
                complete: true,
                fetchedRows: Int64.ONE,
                columns: [rpc.Column(name: 'n', jdbcType: 4, typeName: 'int4')],
              ),
            ],
          ),
          documentId: owner.id,
        );
        model.cache['previous-result:0'] = rpc.Row(
          values: [Value(signedInteger: '23')],
        );
        model.selectedExecutions[owner.id] = 'previous-execution';
        backend.client.sqlReview = (_) async => throw entry.$1;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        await tester.pumpWidget(
          MaterialApp(
            home: WorkbenchView(model: model, controls: const LinuxControls()),
          ),
        );
        await tester.pumpAndSettle();
        await model.commands!.invoke('sql.run', model.commandContext);
        await tester.pumpAndSettle();
        expect(model.status, entry.$2);
        expect(find.text(entry.$2), findsWidgets);
        expect(find.textContaining('private server text'), findsNothing);
        expect(find.textContaining('gRPC Error'), findsNothing);
        expect(model.document.editor.text, 'SELECT 23');
        expect(model.selectedExecutions[owner.id], 'previous-execution');
        expect(model.resultForOwner(owner)?.resultId, 'previous-result');
        expect(backend.client.reviews, hasLength(1));
        expect(backend.client.executions, isEmpty);
      },
    );
  }

  testWidgets(
    'table browsing waits for its replacement while retained SQL viewing stays available',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('table-browse-pending-'),
      ))!;
      final backend = TestBackend();
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = backend
        ..newDocument();
      final profile = Profile(id: 'p', engine: Engine.POSTGRESQL);
      model.profiles.add(profile);
      final owner = model.openTask(
        WorkbenchDocumentKind.table,
        't',
        object: DatabaseObjectIdentity(
          profileId: 'p',
          catalog: 'db',
          schema: 'public',
          name: 't',
          kind: ObjectKind.TABLE,
        ),
      );
      owner.view.subview = 'data';
      owner.sessionId = 's';
      model.sessions['s'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 's',
        profile: profile,
        transaction: TransactionState.IDLE,
        autoCommit: true,
        contextRevision: Int64.ONE,
        currentCatalog: 'db',
        currentSchema: 'public',
      );
      PreparedBrowseFixture(
        relation: SchemaObject(
          kind: ObjectKind.TABLE,
          name: 't',
          catalog: 'db',
          schema: 'public',
          stableIdentity: 'prepared-filter-table',
        ),
        columns: [
          SchemaObject(
            kind: ObjectKind.COLUMN,
            name: 'n',
            table: 't',
            catalog: 'db',
            schema: 'public',
            stableIdentity: 'prepared-filter-column',
            parentIdentity: 'prepared-filter-table',
          ),
        ],
      ).install(model, backend);
      final result = StatementResult(
        resultId: 'old',
        fetchedRows: Int64.ONE,
        complete: true,
        columns: [
          rpc.Column(
            name: 'n',
            baseColumn: 'n',
            typeName: 'text',
            jdbcType: 12,
          ),
        ],
      );
      model.track(
        JobInfo(
          jobId: 'old-job',
          executionId: 'old-execution',
          state: JobState.COMPLETED,
          results: [result],
        ),
        documentId: owner.id,
      );
      model.cache['old:0'] = rpc.Row(values: [Value(text: 'before')]);
      model.track(
        JobInfo(
          jobId: 'replacement',
          executionId: 'replacement-execution',
          state: JobState.EXECUTING,
        ),
        documentId: owner.id,
      );
      model.selectedExecutions[owner.id] = 'old-execution';
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      await tester.pumpAndSettle();
      final captured = model.commandContext;
      for (final id in [
        'object.refresh',
        'result.filter',
        'result.sort',
        'result.refresh',
        'result.reset',
      ]) {
        expect(
          model.commands!.command(id).disabledReason!(captured),
          contains('operation'),
        );
      }
      await expectLater(
        model.commands!.invoke('result.filter', captured),
        throwsStateError,
      );
      await tester.pumpAndSettle();
      expect(find.text('Filter table data'), findsNothing);
      expect(backend.client.browseRequests, isEmpty);
      model.jobs['replacement'] = model.jobs['replacement']!.deepCopy()
        ..state = JobState.COMPLETED;
      model.updateStatus('Completed');
      await tester.pumpAndSettle();
      expect(
        model.commands!.command('result.filter').disabledReason!(captured),
        isNull,
      );
      final filtered = model.commands!.invoke('result.filter', captured);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.bySemanticsLabel('Exact value'),
          matching: find.byType(EditableText),
        ),
        'next',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      await filtered;
      expect(
        backend.client.browseRequests.single.conditions.single.value.text,
        'next',
      );
      expect(backend.client.executions, isEmpty);
      model.newDocument();
      final query = model.activeOwner;
      model.track(
        JobInfo(
          jobId: 'query-old',
          executionId: 'query-old-execution',
          state: JobState.COMPLETED,
          results: [
            StatementResult(
              resultId: 'query-source',
              complete: true,
              fetchedRows: Int64.ONE,
              columns: result.columns,
            ),
          ],
        ),
        documentId: query.id,
      );
      model.cache['query-source:0'] = rpc.Row(
        values: [Value(text: 'retained')],
      );
      model.track(
        JobInfo(
          jobId: 'query-running',
          executionId: 'query-running-execution',
          state: JobState.EXECUTING,
        ),
        documentId: query.id,
      );
      model.selectedExecutions[query.id] = 'query-old-execution';
      model.updateStatus('Running');
      await tester.pumpAndSettle();
      expect(
        model.commands!.command('result.filter').disabledReason!(
          model.commandContext,
        ),
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Fluent execution menu native focus, activation and Escape restore palette routing',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('fluent-menu-keys-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument()
        ..backend = TestBackend();
      model.track(
        JobInfo(
          jobId: 'job',
          executionId: 'execution',
          state: JobState.COMPLETED,
          results: [
            StatementResult(
              resultId: 'rows',
              complete: true,
              fetchedRows: Int64(1),
              columns: [rpc.Column(name: 'n', typeName: 'text')],
            ),
          ],
        ),
        documentId: model.document.id,
      );
      model.cache['rows:0'] = rpc.Row(values: [Value(text: 'retained')]);
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        fluent.FluentApp(
          home: WorkbenchView(model: model, controls: const WindowsControls()),
        ),
      );
      await tester.pumpAndSettle();
      final menu = find.widgetWithText(
        fluent.DropDownButton,
        'Execution options',
      );
      final node = tester.getSemantics(menu);
      expect(node.getSemanticsData().hasAction(SemanticsAction.focus), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.focus);
      await tester.pumpAndSettle();
      tester
          .getSemantics(menu)
          .owner!
          .performAction(tester.getSemantics(menu).id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(
        tester.state<fluent.DropDownButtonState>(menu).isOpen,
        isTrue,
        reason:
            'Focus ${FocusManager.instance.primaryFocus?.debugLabel}; texts ${tester.widgetList<Text>(find.byType(Text)).map((text) => text.data).toList()}',
      );
      expect(find.text('1 · Completed · 0 ms'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('1 · Completed · 0 ms'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(SearchResultList), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    },
  );
  WorkbenchCommand item(int i) => WorkbenchCommand(
    id: 'c$i',
    label: 'Command ${i.toString().padLeft(3, '0')}',
    category: 'Workbench',
    invoke: (_) {},
  );

  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} registry keeps live requirements while refreshing bindings and language',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('registry-poll-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = TestBackend()
          ..newDocument(text: 'SELECT 1;');
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        Future<void> display(String locale) => tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(
                  locale: Locale(locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: WorkbenchView(model: model, controls: controls),
                )
              : MaterialApp(
                  locale: Locale(locale),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: Scaffold(
                    body: WorkbenchView(model: model, controls: controls),
                  ),
                ),
        );
        await display('en');
        await tester.pumpAndSettle();
        final registry = model.commands!;
        Element nativeMenu(String label) => tester.element(
          controls is LinuxControls
              ? find.byKey(const ValueKey('workbench-main-menu'))
              : find.byType(fluent.MenuBar),
        );
        final originalLabel = registry.command('file.new').label;
        expect(
          registry.command('sql.run').disabledReason!(model.commandContext),
          isNotNull,
        );
        model.document.profileId = 'p';
        model.document.sessionId = 's';
        model.sessions['s'] = SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 's',
          profile: Profile(id: 'p', name: 'Captured target'),
          transaction: TransactionState.IDLE,
        );
        model.updateStatus('Background acknowledgement');
        await tester.pumpAndSettle();
        expect(model.commands, same(registry));
        expect(
          registry.command('sql.run').disabledReason!(model.commandContext),
          isNull,
        );
        final fileMenu = nativeMenu('File');
        final connectionMenu = nativeMenu('Connection');
        model.updateStatus('More fetched rows');
        await tester.pumpAndSettle();
        expect(nativeMenu('File'), same(fileMenu));
        expect(nativeMenu('Connection'), same(connectionMenu));
        model.sessions['s']!.transaction = TransactionState.UNKNOWN_TRANSACTION;
        model.updateStatus('Uncertain background outcome');
        await tester.pumpAndSettle();
        expect(model.commands, same(registry));
        expect(
          registry.command('sql.run').disabledReason!(model.commandContext),
          'Outcome unknown',
        );
        expect(nativeMenu('Connection'), same(connectionMenu));
        model.shortcuts['execute'] = 'Alt+Enter';
        model.updateStatus('Updated binding');
        await tester.pumpAndSettle();
        expect(model.commands, isNot(same(registry)));
        expect(model.commands!.command('sql.run').shortcut, 'Alt+Enter');
        await display('de');
        await tester.pumpAndSettle();
        expect(model.commands!.command('file.new').label, isNot(originalLabel));
        expect(model.commands!.command('sql.run').shortcut, 'Alt+Enter');
        expect(
          model.sessions['s']!.transaction,
          TransactionState.UNKNOWN_TRANSACTION,
        );
        expect((model.backend as TestBackend).client.executions, isEmpty);
        await display('en');
        await tester.pumpAndSettle();
        final originalOwner = model.activeOwner;
        model.newDocument();
        model.document.profileId = 'another-target';
        model.profiles.add(Profile(id: 'another-target'));
        model.updateStatus('Changed menu owner');
        await tester.pumpAndSettle();
        expect(nativeMenu('File'), same(fileMenu));
        final beforeNewQuery = model.documents.length;
        const menus = MethodChannel(nativeMenuChannelName);
        if (controls is LinuxControls) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(menus, (call) async {
                if (call.method != 'show') return null;
                final entries = flattenNativeMenu(
                  (call.arguments as Map)['entries'] as List,
                );
                final index = entries.indexWhere(
                  (entry) => entry['label'] == originalLabel,
                );
                expect(index, greaterThanOrEqualTo(0));
                return index; // The host selected New query in this captured menu.
              });
          addTearDown(() {
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(menus, null);
          });
        }
        await tester.tap(
          controls is LinuxControls
              ? find.byKey(const ValueKey('workbench-main-menu'))
              : find.text('File'),
        );
        await tester.pumpAndSettle();
        if (controls is WindowsControls) {
          await tester.tap(find.text(originalLabel).last);
          await tester.pumpAndSettle();
        }
        expect(model.documents.length, beforeNewQuery + 1);
        expect(model.document.profileId, 'another-target');
        expect(model.document.sessionId, isNull);
        expect(originalOwner.sessionId, 's');
        expect(
          model.sessions['s']!.transaction,
          TransactionState.UNKNOWN_TRANSACTION,
        );
        expect((model.backend as TestBackend).client.executions, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  test('palette equal-ranked matches retain registration order', () {
    final registry = WorkbenchCommandRegistry(List.generate(128, item));
    const context = WorkbenchCommandContext();
    expect(
      registry.search('', context).map((c) => c.id),
      List.generate(128, (i) => 'c$i'),
    );
    expect(
      registry.search('Workbench', context).map((c) => c.id),
      List.generate(128, (i) => 'c$i'),
    );
    expect(registry.search('Command 010', context).first.id, 'c10');
    expect(
      registry.search('Command 01', context).map((c) => c.id),
      List.generate(10, (i) => 'c${i + 10}'),
    );
  });
  test('temporary measured palette catalog is bounded', () {
    expect(
      WorkbenchCommandRegistry(
        List.generate(WorkbenchCommandRegistry.maximumCommands, item),
      ).commands.length,
      256,
    );
    expect(
      () => WorkbenchCommandRegistry(
        List.generate(WorkbenchCommandRegistry.maximumCommands + 1, item),
      ),
      throwsArgumentError,
    );
  });

  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        '${ui.runtimeType} $direction palette keyboard visibility in native dialog',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(900, 600));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final invoked = <String>[];
          final commands = WorkbenchCommandRegistry([
            for (var i = 0; i < 40; i++)
              WorkbenchCommand(
                id: 'c$i',
                label:
                    'Command ${i.toString().padLeft(2, '0')} with a long translated interface label',
                category: 'Workbench',
                disabledReason: i.isEven
                    ? (_) =>
                          'Select the original connection and document before invoking this contextual operation'
                    : null,
                invoke: (_) {},
              ),
          ]);
          Widget media(BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
              highContrast: true,
            ),
            child: Directionality(textDirection: direction, child: child!),
          );
          final home = Builder(
            builder: (context) => Center(
              child: ui.button(
                'Commands',
                () => ui.dialog<void>(
                  context,
                  'Commands',
                  SizedBox(
                    width: 600,
                    height: 400,
                    child: _SharedSearchFixture(
                      registry: commands,
                      target: const WorkbenchCommandContext(),
                      controls: ui,
                      select: invoked.add,
                    ),
                  ),
                  [ui.button('Cancel', () => Navigator.of(context).pop())],
                ),
              ),
            ),
          );
          await tester.pumpWidget(
            ui is WindowsControls
                ? fluent.FluentApp(builder: media, home: home)
                : MaterialApp(
                    builder: media,
                    home: Scaffold(body: home),
                  ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Commands'));
          await tester.pumpAndSettle();
          final field = find.byType(EditableText);
          expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);
          void visible(int index) {
            final command = find.text(
              'Command ${index.toString().padLeft(2, '0')} with a long translated interface label',
            );
            final selected = find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.selected == true,
              skipOffstage: false,
            );
            expect(
              find.descendant(of: selected, matching: command),
              findsOneWidget,
            );
            final row = tester.getRect(command);
            expect(row.top, greaterThanOrEqualTo(0));
            expect(row.bottom, lessThanOrEqualTo(600));
            expect(
              command.hitTestable(),
              findsOneWidget,
              reason: 'selected $index at $row must be visible',
            );
            expect(
              tester.widget<EditableText>(field).focusNode.hasFocus,
              isTrue,
            );
          }

          visible(0);
          for (var i = 1; i <= 15; i++) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            await tester.pumpAndSettle();
            visible(i);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(invoked, ['c15']);
          for (var i = 14; i >= 0; i--) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
            await tester.pumpAndSettle();
            visible(i);
          }
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
          await tester.pumpAndSettle();
          visible(39);
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          visible(0);
          await tester.enterText(field, 'Command 25');
          await tester.pumpAndSettle();
          visible(25);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(invoked, ['c15', 'c25']);
          await tester.enterText(field, '');
          await tester.pumpAndSettle();
          visible(0);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          expect(invoked, ['c15', 'c25']);
          expect(tester.takeException(), isNull);
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
          expect(find.byType(SearchResultList), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} palette updates live disabled reasons without changing filter, focus or selection',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var invocations = 0;
        String? reason = 'Outcome unknown';
        final changes = ChangeNotifier();
        final palette = _SharedSearchFixture(
          contextChanges: changes,
          registry: WorkbenchCommandRegistry([
            WorkbenchCommand(
              id: 'sql.run',
              label: 'Run current statement',
              category: 'Run options',
              shortcut: 'Ctrl+Enter',
              disabledReason: (_) => reason,
              invoke: (_) => invocations++,
            ),
          ]),
          target: const WorkbenchCommandContext(),
          controls: ui,
          select: (_) => invocations++,
        );
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: palette)
              : MaterialApp(home: palette),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(EditableText),
          'Run current statement',
        );
        await tester.pumpAndSettle();
        final node = tester
            .getSemantics(
              find.bySemanticsLabel(
                RegExp(r'^Run options · Run current statement.*Ctrl\+Enter'),
              ),
            )
            .getSemanticsData();
        expect(node.label, contains('Run current statement'));
        expect(node.label, contains('Ctrl+Enter'));
        expect(node.label, contains('Outcome unknown'));
        expect(node.flagsCollection.isButton, isTrue);
        expect(node.flagsCollection.isEnabled, Tristate.isFalse);
        expect(node.flagsCollection.isSelected, Tristate.isTrue);
        expect(node.hasAction(SemanticsAction.tap), isFalse);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(invocations, 0);
        expect(find.byType(SearchResultList), findsOneWidget);
        final search = tester.widget<EditableText>(find.byType(EditableText));
        final paletteState = tester.state(find.byType(SearchResultList));
        reason = null;
        changes.notifyListeners();
        await tester.pumpAndSettle();
        expect(tester.state(find.byType(SearchResultList)), same(paletteState));
        expect(search.controller.text, 'Run current statement');
        expect(search.focusNode.hasFocus, isTrue);
        final enabled = tester
            .getSemantics(
              find.bySemanticsLabel(
                RegExp(r'^Run options · Run current statement.*Ctrl\+Enter'),
              ),
            )
            .getSemanticsData();
        expect(enabled.flagsCollection.isEnabled, Tristate.isTrue);
        expect(enabled.flagsCollection.isSelected, Tristate.isTrue);
        expect(enabled.hasAction(SemanticsAction.tap), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(invocations, 1);
        reason = 'A document operation is awaiting acknowledgement';
        changes.notifyListeners();
        await tester.pumpAndSettle();
        expect(find.text(reason), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        expect(invocations, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        changes.notifyListeners();
        changes.dispose();
        semantics.dispose();
      },
    );
  }
  test(
    'physical shortcut collisions reject reordered modifiers and slash spellings',
    () {
      expect(
        canonicalWorkbenchShortcut('Alt+Shift+Ctrl+P'),
        'Ctrl+Shift+Alt+P',
      );
      expect(canonicalWorkbenchShortcut('Ctrl+/'), 'Ctrl+Slash');
      for (final pair in [
        ['Ctrl+Shift+P', 'Shift+Ctrl+P'],
        ['Ctrl+/', 'Ctrl+Slash'],
      ]) {
        expect(
          () =>
              validateWorkbenchShortcuts({'one': pair.first, 'two': pair.last}),
          throwsArgumentError,
        );
      }
      for (final invalid in [
        'Ctrl+Ctrl+P',
        'F6',
        'Shift+F6',
        'Alt++P',
        'Meta+P',
      ]) {
        expect(() => canonicalWorkbenchShortcut(invalid), throwsArgumentError);
      }
      expect(
        () => WorkbenchCommandRegistry([
          for (final binding in ['Ctrl+Shift+P', 'Shift+Ctrl+P'])
            WorkbenchCommand(
              id: binding,
              label: binding,
              category: 'View',
              shortcut: binding,
              invoke: (_) {},
            ),
        ]),
        throwsArgumentError,
      );
    },
  );
  testWidgets(
    'Data commands require a table or view and submission state stays local',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('command-context-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = TestBackend()
        ..newDocument();
      final a = model.activeOwner..profileId = 'p';
      model.profiles.add(Profile(id: 'p', name: 'Saved connection'));
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      WorkbenchCommandContext object(ObjectKind kind) =>
          WorkbenchCommandContext(
            owner: a,
            object: DatabaseObjectIdentity(
              profileId: 'p',
              catalog: 'db',
              schema: 'public',
              kind: kind,
              name: 'same name',
            ),
          );
      for (final kind in [
        ObjectKind.SCHEMA,
        ObjectKind.COLUMN,
        ObjectKind.INDEX,
        ObjectKind.ROUTINE,
      ]) {
        expect(
          model.commands!.command('object.data').disabledReason!(object(kind)),
          'Select a table or view',
        );
      }
      for (final kind in [ObjectKind.TABLE, ObjectKind.VIEW]) {
        expect(
          model.commands!.command('object.data').disabledReason!(object(kind)),
          isNull,
        );
      }
      expect(
        model.commands!.command('transfer.import').disabledReason!(
          model.commandContext,
        ),
        'Select a table or view',
      );
      expect(
        model.commands!.command('connection.activity').label,
        isNot(
          model.commands!
              .command('diagnostics.${ToolKind.ACTIVITY.value}')
              .label,
        ),
      );
      expect(
        model.commands!.command('connection.principals').label,
        isNot(
          model.commands!.command('diagnostics.${ToolKind.ROLES.value}').label,
        ),
      );
      final gate = Completer<void>();
      final operation = model.command(() => gate.future, ownerId: a.id);
      expect(
        model.commands!.command('sql.run').disabledReason!(
          model.commandContext,
        ),
        contains('awaiting acknowledgement'),
      );
      model.newDocument();
      model.activeOwner.profileId = 'p';
      expect(
        model.commands!.command('sql.run').disabledReason!(
          model.commandContext,
        ),
        isNull,
      );
      final availableBackend = model.backend;
      model.backend = null;
      expect(
        model.commands!.command('sql.run').disabledReason!(
          model.commandContext,
        ),
        'Restart backend',
      );
      model.backend = availableBackend;
      model.document.sessionId = 'independent';
      model.sessions['independent'] = SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'independent',
        transaction: TransactionState.IDLE,
        profile: Profile(id: 'p'),
      );
      expect(
        model.commands!.command('sql.run').disabledReason!(
          model.commandContext,
        ),
        isNull,
      );
      for (final kind in [ObjectKind.TABLE, ObjectKind.VIEW]) {
        expect(
          model.commands!.command('transfer.import').disabledReason!(
            WorkbenchCommandContext(
              owner: model.activeOwner,
              sessionId: 'independent',
              object: object(kind).object,
            ),
          ),
          isNull,
        );
      }
      gate.complete();
      await operation;
      expect(model.commandPendingForOwner(a.id), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  testWidgets('cancellation keeps its original job after changing documents', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('cancel-command-'),
    ))!;
    final backend = TestBackend();
    final model = WorkbenchModel(root)
      ..draftRecovery = false
      ..backend = backend
      ..newDocument();
    final original = model.activeOwner;
    final job = JobInfo(
      jobId: 'original-job',
      executionId: 'original-execution',
      state: JobState.FETCHING,
    );
    model.track(job, documentId: original.id);
    final reply = Completer<JobInfo>();
    final requests = <String>[];
    backend.client.cancelling = (request) {
      requests.add(request.jobId);
      return reply.future;
    };
    await tester.pumpWidget(
      MaterialApp(
        home: WorkbenchView(model: model, controls: const LinuxControls()),
      ),
    );
    final captured = model.commandContext;
    final operation = model.commands!.invoke('job.cancel', captured);
    model.newDocument();
    final other = model.activeOwner;
    reply.complete(job.deepCopy()..state = JobState.CANCELLING);
    await operation;
    expect(requests, ['original-job']);
    expect(model.activeOwner, same(other));
    expect(model.jobs['original-job']!.state, JobState.CANCELLING);
    expect(
      model.commands!
          .command('job.cancel')
          .disabledReason
          ?.call(model.commandContext),
      isNotNull,
    );
    expect(backend.client.executions, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
    await tester.runAsync(() => root.delete(recursive: true));
  });
  testWidgets(
    'result menus reject a changed retained source instead of retargeting',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('result-command-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..newDocument();
      model.backend = TestBackend();
      final owner = model.activeOwner;
      model.track(
        JobInfo(
          jobId: 'j',
          executionId: 'e',
          results: [
            StatementResult(resultId: 'first'),
            StatementResult(resultId: 'second'),
          ],
        ),
        documentId: owner.id,
      );
      model.selectedResults[owner.id] = 'first';
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final captured = model.commandContext;
      expect(captured.resultId, 'first');
      expect(
        model.commands!.command('result.plan').disabledReason!(captured),
        contains('Explain'),
      );
      // Acknowledged nested execution evidence is read-only. Simulate a new
      // backend reply rather than modifying a previously displayed snapshot.
      model.jobs['j'] = model.jobs['j']!.deepCopy()..results.first.plan = true;
      expect(
        model.commands!.command('result.plan').disabledReason!(captured),
        isNull,
      );
      expect(
        model.commands!.command('result.planDocument').disabledReason!(
          captured,
        ),
        isNull,
      );
      model.selectedResults[owner.id] = 'second';
      for (final id in [
        'transfer.retained',
        'result.dispose',
        'edit.update',
        'edit.apply',
        'edit.discard',
        'result.filter',
        'result.plan',
        'result.planDocument',
      ]) {
        expect(
          model.commands!.command(id).disabledReason?.call(captured),
          isNotNull,
          reason: id,
        );
        await expectLater(
          model.commands!.invoke(id, captured),
          throwsStateError,
          reason: id,
        );
      }
      expect((model.backend as TestBackend).client.executions, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.runAsync(() => root.delete(recursive: true));
    },
  );
  test(
    'registry enforces contextual reasons and filters immediately',
    () async {
      var invocations = 0;
      final registry = WorkbenchCommandRegistry([
        WorkbenchCommand(
          id: 'sql.run',
          label: 'Run',
          category: 'SQL',
          shortcut: 'Ctrl+Enter',
          disabledReason: (c) => c.owner == null ? 'Requires SQL' : null,
          invoke: (_) {
            invocations++;
          },
        ),
      ]);
      const context = WorkbenchCommandContext();
      expect(registry.search('sql r', context).single.id, 'sql.run');
      await expectLater(registry.invoke('sql.run', context), throwsStateError);
      expect(invocations, 0);
    },
  );
  test('duplicate IDs and shortcut collisions are rejected', () {
    WorkbenchCommand command(String id) => WorkbenchCommand(
      id: id,
      label: id,
      category: 'File',
      shortcut: 'Ctrl+S',
      invoke: (_) {},
    );
    expect(
      () => WorkbenchCommandRegistry([command('one'), command('one')]),
      throwsArgumentError,
    );
    expect(
      () => WorkbenchCommandRegistry([command('one'), command('two')]),
      throwsArgumentError,
    );
  });
}

class _SharedSearchFixture extends StatefulWidget {
  const _SharedSearchFixture({
    required this.registry,
    required this.target,
    required this.controls,
    required this.select,
    this.contextChanges,
  });
  final WorkbenchCommandRegistry registry;
  final WorkbenchCommandContext target;
  final DesktopControls controls;
  final ValueChanged<String> select;
  final Listenable? contextChanges;
  @override
  State<_SharedSearchFixture> createState() => _SharedSearchFixtureState();
}

class _SharedSearchFixtureState extends State<_SharedSearchFixture> {
  final query = TextEditingController();
  final focus = FocusNode();
  final results = GlobalKey<SearchResultListState>();
  @override
  void dispose() {
    query.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SearchHeaderField(
        hint: 'Search actions…',
        controls: widget.controls,
        query: query,
        focusNode: focus,
        close: () => Navigator.of(context).maybePop(),
        submit: () => results.currentState?.activateSelection(),
        move: (delta) => results.currentState?.move(delta),
      ),
      Expanded(
        child: SearchResultList(
          key: results,
          registry: widget.registry,
          target: widget.target,
          controls: widget.controls,
          contextChanges: widget.contextChanges,
          select: widget.select,
          query: query,
          queryFocus: focus,
          close: () => Navigator.of(context).maybePop(),
        ),
      ),
    ],
  );
}

class _TestFluentPageRoute<T> extends fluent.FluentPageRoute<T> {
  _TestFluentPageRoute({required super.builder, required bool requestFocus})
    : _requestFocus = requestFocus;
  final bool _requestFocus;
  @override
  bool get requestFocus => _requestFocus;
}
