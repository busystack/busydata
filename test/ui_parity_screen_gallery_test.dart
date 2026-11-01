import 'package:busydata/src/features/results/value_assignments.dart'
    as assignments;
// Source-bound production composition captures. Native menus, GTK/IME and
// database acceptance require the ordinary application and real facilities.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/app/linux/linux_busydata_app.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/features/workspace/documents.dart'
    show atomicWrite;
import 'package:busydata/src/platform/gtk_animation_settings_service.dart';
import 'package:busydata/src/platform/gtk_font_service.dart';
import 'package:busydata/src/platform/gtk_window_preferences_service.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/workbench_settings.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/ui/common/plan_view.dart';
import 'package:busydata/src/ui/common/schema_tools_view.dart';
import 'package:busydata/src/ui/common/transfer_document.dart';
import 'package:busydata/src/ui/common/privileges_view.dart';
import 'package:re_editor/re_editor.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/connection_widgets.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/schema_overview_fixture.dart';
import 'support/native_window.dart';

Future<void> realFonts() async {
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  final ubuntu = FontLoader('packages/yaru/Ubuntu');
  for (final weight in ['L', 'R', 'M', 'B']) {
    ubuntu.addFont(
      rootBundle.load('packages/yaru/assets/fonts/Ubuntu-$weight.ttf'),
    );
  }
  await ubuntu.load();
  for (final family in [
    'Ubuntu',
    'Ubuntu Sans',
    'Ubuntu Mono',
    'Noto Sans Arabic',
    'Noto Sans',
    'DejaVu Sans',
  ]) {
    final font = await Process.run('fc-match', ['--format=%{file}', family]);
    if (font.exitCode != 0 || (font.stdout as String).isEmpty) {
      throw StateError('Missing real font: $family');
    }
    await (FontLoader(family)..addFont(
          Future.value(
            ByteData.sublistView(File(font.stdout as String).readAsBytesSync()),
          ),
        ))
        .load();
  }
  await (FontLoader(
    'packages/yaru/YaruIcons',
  )..addFont(rootBundle.load('packages/yaru/assets/yaru_icons.otf'))).load();
}

void main() {
  final destination = Platform.environment['BUSYDATA_SCREEN_GALLERY_OUTPUT'];
  if (destination != null && Platform.isLinux) setUpAll(realFonts);
  for (final brightness in Brightness.values) {
    testWidgets('production screen inventory ${brightness.name}', (
      tester,
    ) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      installNativeWindowFixture(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.hasStrings'
            ? <String, Object>{'value': false}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final semantics = tester.ensureSemantics();
      var semanticsDisposed = false;
      addTearDown(() {
        if (!semanticsDisposed) semantics.dispose();
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('busydata/native_menus'),
        (_) async => throw MissingPluginException(),
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('busydata/native_menus'),
          null,
        ),
      );
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('busydata-screen-gallery-'),
      ))!;
      final backend = TestBackend();
      Completer<void>? pendingPreferenceWrite;
      var preferenceWriteWaiting = false;
      final model = metadataFixture(
        WorkbenchModel(
            root,
            presentationWrite: (file, bytes) async {
              final pending = pendingPreferenceWrite;
              if (pending != null) {
                preferenceWriteWaiting = true;
                await pending.future;
              }
              await atomicWrite(file, bytes);
            },
          )
          ..draftRecovery = false
          ..backend = backend
          ..newDocument(
            text:
                'select id, customer_name, total\nfrom public.orders\nwhere total > 100;',
          ),
      );
      final profile = rpc.Profile(
        id: 'warehouse',
        name: 'Warehouse',
        host: 'db.example.test',
        port: 5432,
        engine: rpc.Engine.POSTGRESQL,
        database: 'warehouse',
        environment: rpc.Environment.STAGING,
      );
      model.profiles.add(profile);
      model.document
        ..profileId = profile.id
        ..sessionId = 'query';
      model.sessions['query'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'query',
        profile: profile,
        autoCommit: true,
        transaction: rpc.TransactionState.IDLE,
        currentCatalog: 'warehouse',
        currentSchema: 'public',
      );
      model.connectionOwner(profile).sessionId = 'query';
      model.explorerSessions[profile.id] = 'query';
      backend.client.metadataAction = (request) async => rpc.SchemaObjects(
        complete: true,
        availability: 'available',
        objects: request.globalSearch
            ? [
                rpc.SchemaObject(
                  name: 'orders',
                  kind: rpc.ObjectKind.TABLE,
                  catalog: 'warehouse',
                  schema: 'public',
                ),
              ]
            : request.kind == rpc.ObjectKind.COLUMN
            ? customerColumns()
            : [
                for (final name in switch (request.kind) {
                  rpc.ObjectKind.CATALOG => ['warehouse'],
                  rpc.ObjectKind.SCHEMA => ['public', 'audit'],
                  rpc.ObjectKind.TABLE => ['orders', 'customers'],
                  rpc.ObjectKind.COLUMN => ['id', 'customer_name', 'total'],
                  _ => <String>[],
                })
                  rpc.SchemaObject(name: name, kind: request.kind),
              ],
      );
      backend.client.historyCatalog = (_) async => rpc.HistoryList(
        retainSql: true,
        retentionDays: 30,
        entries: [
          rpc.HistoryEntry(
            id: 'h1',
            target: 'Warehouse / public',
            sql: 'select id, customer_name from public.orders;',
            state: rpc.JobState.COMPLETED,
            durationMs: Int64(12),
          ),
        ],
      );
      backend.client.capabilityAction = (request) async => rpc.CapabilityList(
        backendInstance: backend.instanceId,
        sessionId: request.sessionId,
        contextRevision: request.contextRevision,
        sessionRevision: request.sessionRevision,
        product: 'PostgreSQL',
        version: 'fixture',
        availability: 'available',
      );
      backend.client.activityAction = (_) async => rpc.ActivityList(
        availability: 'available',
        entries: [
          rpc.Activity(
            id: Int64(1001),
            principal: 'analyst',
            database: 'warehouse',
            state: 'idle',
            queryPreview: 'select current_database();',
          ),
        ],
      );
      backend.client.schemaTools = (_) async => rpc.SchemaToolResult(
        complete: true,
        snapshot: jsonEncode({
          'engine': 'POSTGRESQL',
          'schema': 'public',
          'tables': {},
          'views': {},
          'routines': {},
        }),
      );
      model.snippets['Customer lookup'] =
          'select * from public.customers where id = 1;';
      final sqlOwner = model.activeOwner;
      final captured = model.captureTarget(owner: sqlOwner);
      final result = rpc.StatementResult(
        resultId: 'orders',
        complete: true,
        fetchedRows: Int64(3),
        columns: [
          rpc.Column(name: 'id', jdbcType: 4, typeName: 'int4'),
          rpc.Column(name: 'customer_name', jdbcType: 12, typeName: 'text'),
          rpc.Column(name: 'total', jdbcType: 3, typeName: 'numeric'),
        ],
      );
      final rows = [
        rpc.Row(
          values: [
            rpc.Value(signedInteger: '1001'),
            rpc.Value(text: 'Ada Lovelace'),
            rpc.Value(decimal: '182.40'),
          ],
        ),
        rpc.Row(
          values: [
            rpc.Value(signedInteger: '1002'),
            rpc.Value(text: ''),
            rpc.Value(nullValue: rpc.Null()),
          ],
        ),
        rpc.Row(
          values: [
            rpc.Value(signedInteger: '1003'),
            rpc.Value(text: 'Retained preview…', truncated: true),
            rpc.Value(decimal: '210.00'),
          ],
        ),
      ];
      backend.client.pages = (_) async => rpc.Page(
        rows: rows,
        complete: true,
        fetchedRows: Int64(3),
        nextOffset: Int64(3),
      );
      model.track(
        rpc.JobInfo(
          jobId: 'orders-job',
          executionId: 'orders-execution',
          sessionId: 'query',
          target: profile,
          state: rpc.JobState.COMPLETED,
          results: [result],
        ),
        documentId: sqlOwner.id,
      );
      for (final (index, row) in rows.indexed) {
        model.cache['orders:$index'] = row;
      }
      final boundary = GlobalKey();
      final output = Directory('$destination/${brightness.name}')
        ..createSync(recursive: true);
      final entries = <String>[];
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        model.dispose();
        debugDisableShadows = previousShadows;
        tester.view.reset();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ProviderScope(
            overrides: [
              workbenchProvider.overrideWithValue(model),
              initialGtkFontSettingsProvider.overrideWithValue(
                const GtkFontSettings(family: 'Ubuntu Sans', size: 11),
              ),
              gtkThemeColorsProvider.overrideWith(
                (_) => Stream.value(
                  GtkThemeColors(
                    brightness: brightness,
                    accent: const Color(0xff3584e4),
                  ),
                ),
              ),
              gtkAnimationsEnabledProvider.overrideWith(
                (_) => Stream.value(false),
              ),
              gtkWindowPreferencesProvider.overrideWith(
                (_) => Stream.value(GtkWindowPreferences.defaults()),
              ),
            ],
            child: const LinuxBusyDataApp(),
          ),
        ),
      );
      Future<void> capture(String name, {bool settle = true}) async {
        if (settle) {
          await tester.pumpAndSettle();
        } else {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(tester.takeException(), isNull, reason: name);
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await render.toImage();
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$name.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
        entries.add(name);
      }

      Future<void> task(
        String name,
        WorkbenchDocumentKind kind,
        Object payload,
      ) async {
        model.openTask(kind, name, payload: payload, profileId: profile.id);
        await capture(name);
      }

      model.showWelcome();
      await capture('welcome');
      model.showWorkbench();
      for (final label in ['Warehouse', 'warehouse', 'public', 'Tables']) {
        final disclosure = find.bySemanticsLabel('Expand $label');
        if (disclosure.evaluate().isNotEmpty) {
          await tester.tap(disclosure.first);
          await tester.pumpAndSettle();
        }
      }
      await capture('sql-results-explorer');
      await tester.tapAt(
        tester.getTopLeft(find.byType(CodeEditor).hitTestable()) +
            const Offset(90, 24),
        buttons: 2,
      );
      await tester.pumpAndSettle();
      expect(find.text('Cut'), findsOneWidget);
      await capture('sql-text-menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await model.commands!.invoke('editor.find', model.commandContext);
      await tester.pumpAndSettle();
      tester
              .widget<SearchHeaderField>(find.byType(SearchHeaderField))
              .query
              .text =
          'public';
      await capture('search-current-sql');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await model.commands!.invoke('view.palette', model.commandContext);
      await capture('search-actions');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await model.commands!.invoke('connection.search', model.commandContext);
      await tester.pumpAndSettle();
      tester
              .widget<SearchHeaderField>(find.byType(SearchHeaderField))
              .query
              .text =
          'orders';
      await tester.pump(const Duration(milliseconds: 200));
      await capture('search-objects');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await model.commands!.invoke('history.search', model.commandContext);
      await capture('search-history');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await model.commands!.invoke('preferences', model.commandContext);
      await tester.pumpAndSettle();
      final settings = tester.state<WorkbenchSettingsState>(
        find.byType(WorkbenchSettings),
      );
      for (final category in [
        'appearance',
        'execution',
        'recovery',
        'shortcuts',
      ]) {
        settings.selectCategory(category);
        await capture('settings-$category');
      }
      final assignment = settings.assign('execute');
      await capture('shortcut-editor');
      pendingPreferenceWrite = Completer<void>();
      await tester.tap(find.text('Apply'));
      for (
        var attempt = 0;
        !preferenceWriteWaiting && attempt < 100;
        attempt++
      ) {
        await tester.pump();
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
      }
      expect(preferenceWriteWaiting, isTrue);
      await capture('shortcut-saving', settle: false);
      pendingPreferenceWrite.completeError(
        const FileSystemException('Gallery write failure'),
      );
      await capture('shortcut-save-error');
      pendingPreferenceWrite = null;
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await assignment;
      settings.widget.close();
      await tester.pumpAndSettle();
      model.activateOwner(sqlOwner.id);
      final manager = model.commands!.invoke(
        'connection.new',
        model.commandContext,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('connection-add-source')));
      await tester.pumpAndSettle();
      await capture('connection-general');
      for (final page in ['SSH/SSL', 'Options']) {
        await selectConnectionPage(tester, page);
        await capture('connection-${page.replaceAll('/', '-').toLowerCase()}');
      }
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await manager;
      await task(
        'plan',
        WorkbenchDocumentKind.plan,
        PlanData.parse(
          '{"Plan":{"Node Type":"Seq Scan","Relation Name":"orders","Plan Rows":120,"Actual Rows":3}}',
        ),
      );
      await task(
        'history',
        WorkbenchDocumentKind.administration,
        GlobalToolData(GlobalToolKind.history),
      );
      await task(
        'capabilities',
        WorkbenchDocumentKind.administration,
        AdministrationData(captured),
      );
      final structure = model.openTask(
        WorkbenchDocumentKind.structure,
        'Structure · customers',
        object: DatabaseObjectIdentity(
          profileId: profile.id,
          catalog: 'warehouse',
          schema: 'public',
          kind: rpc.ObjectKind.TABLE,
          name: 'customers',
        ),
      );
      structure.view.subview = 'structure';
      await capture('structure');
      final retainedTable = model.openTask(
        WorkbenchDocumentKind.table,
        'Data · orders',
        object: structure.object,
        profileId: profile.id,
      )..sessionId = 'query';
      model.showWelcome();
      await capture('welcome-retained-table');
      model.showWorkbench();
      expect(model.activeOwner, same(retainedTable));
      model.activateOwner(structure.id);
      await task(
        'designer',
        WorkbenchDocumentKind.structure,
        DesignerData(
          captured,
          rpc.SchemaToolRequest(
            sessionId: 'query',
            schema: 'public',
            table: 'orders',
          ),
          rpc.SchemaToolResult(
            snapshot: jsonEncode({
              'engine': 'POSTGRESQL',
              'schema': 'public',
              'tables': {
                'orders': {
                  'columns': {
                    'id': {'type': 'integer'},
                    'total': {'type': 'numeric'},
                  },
                },
              },
              'views': {},
              'routines': {},
            }),
          ),
          ObjectDesignerDraft(),
        ),
      );
      await task(
        'privileges',
        WorkbenchDocumentKind.administration,
        PrivilegesDocumentData(
          rpc.Engine.POSTGRESQL,
          rpc.PrivilegeReply(
            principals: [rpc.Principal(name: 'analyst', kind: 'role')],
          ),
          'public',
          'orders',
          true,
          (_) async => rpc.PrivilegeReply(),
          (_) async {},
          (_) {},
          target: captured,
        ),
      );
      final batch = model.batchFor(sqlOwner, result.resultId);
      await task(
        'changes-review',
        WorkbenchDocumentKind.structure,
        ChangesReviewData(
          captured,
          batch,
          batch.revision,
          rpc.ChangePlan(
            target: profile,
            changes: [
              rpc.ReviewedChange(
                kind: rpc.ChangeKind.UPDATE,
                sourceRow: Int64.ZERO,
                original: {'total': rpc.Value(decimal: '182.40')}.entries,
                values: ({'total': rpc.Value(decimal: '190.00')}.entries).map(
                  (entry) => MapEntry(
                    entry.key,
                    assignments.assignmentOf(entry.value),
                  ),
                ),
              ),
            ],
            sql: ['UPDATE public.orders SET total=? WHERE id=?;'],
          ),
          () async {},
        ),
      );
      model.editDrafts.add(
        rpc.EditDraftInfo(
          draftId: 'retained',
          documentId: sqlOwner.id,
          target: profile,
          schema: 'public',
          table: 'orders',
          changes: 1,
          state: 'STAGED',
        ),
      );
      await task(
        'recovery',
        WorkbenchDocumentKind.administration,
        RecoveryDocumentData(sqlOwner.sql, (_) async {}, (_) async {}),
      );
      await task(
        'activity',
        WorkbenchDocumentKind.administration,
        AdministrationData(
          captured,
          activities: true,
          activityAction: (_, _) async {},
        ),
      );
      await task(
        'transfer',
        WorkbenchDocumentKind.transfer,
        TransferDocumentData(
          captured,
          rpc.ToolKind.EXPORT_RESULT,
          resultId: result.resultId,
          sourceTarget: profile,
          path: '/tmp/reviewed-export.csv',
        ),
      );
      await task(
        'backup',
        WorkbenchDocumentKind.transfer,
        TransferDocumentData(
          captured,
          rpc.ToolKind.DUMP,
          path: '/tmp/reviewed-backup.sql',
          nativeTool: '/usr/bin/pg_dump',
        ),
      );
      await task(
        'comparison',
        WorkbenchDocumentKind.comparison,
        ComparisonData(schema: 'public', profileId: profile.id),
      );
      await task(
        'diagram',
        WorkbenchDocumentKind.diagram,
        DiagramDocumentData(
          [
            rpc.SchemaObject(name: 'orders', kind: rpc.ObjectKind.TABLE),
            rpc.SchemaObject(name: 'customers', kind: rpc.ObjectKind.TABLE),
          ],
          [],
          profileId: profile.id,
          catalog: 'warehouse',
          schema: 'public',
        ),
      );
      await task(
        'jobs',
        WorkbenchDocumentKind.administration,
        GlobalToolData(GlobalToolKind.jobs),
      );
      await task(
        'problems-empty',
        WorkbenchDocumentKind.administration,
        GlobalToolData(GlobalToolKind.problems),
      );
      model.jobs['failed'] = rpc.JobInfo(
        jobId: 'failed',
        state: rpc.JobState.FAILED,
        messages: [
          'The connection closed before the request was acknowledged. Inspect the retained evidence before retrying.',
        ],
      );
      model.updateStatus('Retained diagnostic');
      await task(
        'problems-error',
        WorkbenchDocumentKind.administration,
        GlobalToolData(GlobalToolKind.problems),
      );
      model.activateOwner(sqlOwner.id);
      final snippet = model.commands!.invoke(
        'editor.snippets',
        model.commandContext,
      );
      await capture('snippets');
      await tester.tap(find.text('Close').last);
      await tester.pumpAndSettle();
      await snippet;
      for (final scale in [1.5, 2.0]) {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        tester.view.physicalSize = const Size(760, 720);
        model.showWelcome();
        await capture('compact-welcome-${(scale * 100).round()}');
        model.showWorkbench();
        await model.commands!.invoke('view.palette', model.commandContext);
        await capture('compact-search-${(scale * 100).round()}');
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      }
      tester.view.physicalSize = const Size(1280, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      for (final locale in ['de', 'ar']) {
        await tester.runAsync(() => model.saveAppearance('system', locale));
        model.showWelcome();
        await capture('welcome-$locale-150');
        await model.commands!.invoke('preferences', model.commandContext);
        await tester.pumpAndSettle();
        tester
            .state<WorkbenchSettingsState>(find.byType(WorkbenchSettings))
            .selectCategory('appearance');
        await capture('settings-$locale-150');
        tester
            .state<WorkbenchSettingsState>(find.byType(WorkbenchSettings))
            .widget
            .close();
        await tester.pumpAndSettle();
      }
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
            highContrast: true,
            disableAnimations: true,
          );
      model.showWelcome();
      await capture('welcome-ar-high-contrast-150');
      expect(backend.client.executions, isEmpty);
      await tester.runAsync(
        () => File(
          '${output.path}/captions.json',
        ).writeAsString(jsonEncode(entries)),
      );
      semantics.dispose();
      semanticsDisposed = true;
      debugDisableShadows = previousShadows;
      debugDefaultTargetPlatformOverride = previousPlatform;
    }, skip: destination == null || !Platform.isLinux);
  }
}
