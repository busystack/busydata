import 'support/connection_widgets.dart';
import 'dart:io';
import 'package:busydata/src/app/linux/linux_busydata_app.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/gtk_font_service.dart';
import 'package:busydata/src/platform/gtk_window_preferences_service.dart';
import 'package:busydata/src/platform/gtk_animation_settings_service.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/native_window.dart';
import 'support/presentation_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadPresentationFonts);
  for (final brightness in Brightness.values) {
    testWidgets(
      'production Linux ${brightness.name} populated workbench and command rows',
      (tester) async {
        final semantics = tester.ensureSemantics();
        installNativeWindowFixture(tester);
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = true);
        tester.view.physicalSize = const Size(1366, 768);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('workbench-visual-'),
        ))!;
        final backend = TestBackend();
        final profile = rpc.Profile(
          id: 'warehouse',
          name: 'Warehouse',
          host: 'fixture.invalid',
          port: 5432,
          database: 'warehouse',
          engine: rpc.Engine.POSTGRESQL,
          environment: rpc.Environment.STAGING,
        );
        final model = metadataFixture(
          WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..profiles.add(profile)
            ..newDocument(
              text:
                  'select id, customer_name, total\nfrom public.orders\nwhere total > 100;',
            ),
        );
        final owner = model.activeOwner;
        owner.profileId = profile.id;
        owner.sessionId = 'query-session';
        for (final session in ['query-session', 'browsing-session']) {
          model.sessions[session] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: session,
            profile: profile,
            autoCommit: true,
            currentCatalog: 'warehouse',
            currentSchema: 'public',
            transaction: rpc.TransactionState.IDLE,
          );
        }
        model.explorerSessions[profile.id] = 'browsing-session';
        backend.client.metadataAction = (request) async => rpc.SchemaObjects(
          complete: true,
          availability: 'available',
          defaultNamespace: request.kind == rpc.ObjectKind.CATALOG
              ? 'warehouse'
              : 'public',
          objects: [
            for (final name in switch (request.kind) {
              rpc.ObjectKind.CATALOG => ['warehouse'],
              rpc.ObjectKind.SCHEMA => ['public', 'audit'],
              rpc.ObjectKind.TABLE => ['orders', 'customers'],
              rpc.ObjectKind.VIEW => ['open_orders'],
              _ => <String>[],
            })
              rpc.SchemaObject(kind: request.kind, name: name),
          ],
        );
        final result = rpc.StatementResult(
          resultId: 'orders-retained',
          complete: true,
          fetchedRows: Int64(3),
          columns: [
            rpc.Column(name: 'id', jdbcType: 4, typeName: 'int4'),
            rpc.Column(name: 'customer_name', jdbcType: 12, typeName: 'text'),
            rpc.Column(name: 'total', jdbcType: 3, typeName: 'numeric'),
          ],
        );
        model.track(
          rpc.JobInfo(
            jobId: 'orders-job',
            executionId: 'orders-execution',
            sessionId: 'query-session',
            target: profile,
            state: rpc.JobState.COMPLETED,
            results: [result],
          ),
          documentId: owner.id,
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
              rpc.Value(text: 'Long retained preview…', truncated: true),
              rpc.Value(decimal: '210.00'),
            ],
          ),
        ];
        for (final (index, row) in rows.indexed) {
          model.cache['orders-retained:$index'] = row;
        }
        backend.client.pages = (_) async => rpc.Page(
          rows: rows,
          complete: true,
          fetchedRows: Int64(3),
          nextOffset: Int64(3),
        );
        model.newDocument(
          text: '-- Independent query session\nselect current_database();',
        );
        model.newDocument(
          text: '-- Review only\nselect * from public.customers;',
        );
        model.activateOwner(owner.id);
        model.updateStatus('Ready');
        const nativeMenus = MethodChannel('busydata/native_menus');
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          nativeMenus,
          (_) async => throw MissingPluginException(),
        );
        addTearDown(
          () => messenger.setMockMethodCallHandler(nativeMenus, null),
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          model.dispose();
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.platformDispatcher.clearPlatformBrightnessTestValue();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        const font = GtkFontSettings(family: 'PresentationTest', size: 11);
        final colors = GtkThemeColors(
          brightness: brightness,
          accent: const Color(0xffe95420),
        );
        const boundary = ValueKey('production-visual');
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: ProviderScope(
              overrides: [
                workbenchProvider.overrideWithValue(model),
                initialGtkFontSettingsProvider.overrideWithValue(font),
                gtkFontSettingsProvider.overrideWith(
                  (ref) => Stream.value(font),
                ),
                initialGtkThemeColorsProvider.overrideWithValue(colors),
                gtkThemeColorsProvider.overrideWith(
                  (ref) => Stream.value(colors),
                ),
                gtkAnimationsEnabledProvider.overrideWith(
                  (ref) => Stream.value(false),
                ),
                gtkWindowPreferencesProvider.overrideWith(
                  (ref) => Stream.value(GtkWindowPreferences.defaults()),
                ),
              ],
              child: const LinuxBusyDataApp(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .getSemantics(find.text('Database'))
              .getSemanticsData()
              .flagsCollection
              .isHeader,
          isTrue,
        );
        final editorInput = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Visible SQL line')),
        );
        for (var node = editorInput; ; node = node.parent!) {
          expect(
            node.getSemanticsData().flagsCollection.isHeader,
            isFalse,
            reason:
                'The sidebar heading must not absorb the workbench '
                'inside the production window overlay.',
          );
          if (node.parent == null) break;
        }
        for (final name in ['Warehouse', 'warehouse', 'public', 'Tables']) {
          final disclosure = find.bySemanticsLabel('Expand $name');
          if (disclosure.evaluate().isNotEmpty) {
            await tester.tap(disclosure.first);
            await tester.pumpAndSettle();
          }
        }
        await tester.tap(find.text('Ada Lovelace'));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(backend.client.executions, isEmpty);
        expect(model.document.editor.text, contains('where total > 100;'));
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile(
            'app/goldens/linux_workbench_${brightness.name}.png',
          ),
        );

        final palette = model.commands!.invoke(
          'view.palette',
          model.commandContext,
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(boundary),
          matchesGoldenFile('app/goldens/linux_palette_${brightness.name}.png'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await palette;
        if (brightness == Brightness.light) {
          final manager = model.commands!.invoke(
            'connection.new',
            model.commandContext,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('connection-add-source')));
          await tester.pumpAndSettle();
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('connection-port'))).dy,
            closeTo(
              tester
                  .getTopLeft(find.byKey(const ValueKey('connection-host')))
                  .dy,
              1,
            ),
            reason: 'The compact numeric entry shares the host input baseline.',
          );
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('app/goldens/linux_connection_drafts.png'),
          );
          await selectConnectionPage(tester, 'SSH/SSL');
          await tester.pumpAndSettle();
          await expectLater(
            find.byKey(boundary),
            matchesGoldenFile('app/goldens/linux_connection_security.png'),
          );
          await tester.tap(find.text('Cancel').last);
          await tester.pumpAndSettle();
          await manager;
        }
        expect(find.byType(WorkbenchView), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(backend.client.executions, isEmpty);
        semantics.dispose();
        debugDisableShadows = true;
      },
      // Like the Linux button golden, these reviewed pixels belong to the
      // Linux font rasterizer. Native Windows/Fluent acceptance is separate.
      skip: !Platform.isLinux,
    );
  }
}
