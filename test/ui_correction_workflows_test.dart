// Production composition and realistic metadata. Rendering evidence supplements
// the ordinary native tours; these fixtures do not certify native acceptance.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:busydata/src/app/linux/linux_busydata_app.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/gtk_animation_settings_service.dart';
import 'package:busydata/src/platform/gtk_font_service.dart';
import 'package:busydata/src/platform/gtk_window_preferences_service.dart';
import 'package:busydata/src/ui/common/workbench_document_view.dart';
import 'package:busydata/src/ui/common/connection_form.dart';
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/connection_widgets.dart';
import 'support/fake_backend.dart';
import 'support/metadata_fixture.dart';
import 'support/native_window.dart';
import 'support/schema_overview_fixture.dart';
import 'ui_parity_screen_gallery_test.dart' show realFonts;

void main() {
  final destination =
      Platform.environment['BUSYDATA_CORRECTION_GALLERY_OUTPUT'];
  if (destination != null) setUpAll(realFonts);
  for (final brightness in Brightness.values) {
    testWidgets('assembled correction workflows ${brightness.name}', (
      tester,
    ) async {
      final previousPlatform = debugDefaultTargetPlatformOverride;
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      installNativeWindowFixture(tester);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('busydata/native_menus'),
        (_) async => throw MissingPluginException(),
      );
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('correction-workflows-'),
      ))!;
      final backend = TestBackend();
      backend.client.connectionDescription = (request) async {
        final profile = request.profile;
        final engine = switch (profile.engine) {
          rpc.Engine.POSTGRESQL => 'postgresql',
          rpc.Engine.MARIADB => 'mariadb',
          _ => 'mysql',
        };
        return rpc.ConnectionDescription(
          jdbcUrl:
              'jdbc:$engine://${profile.host}:${profile.port}/${profile.database}',
          driverClass: engine == 'mysql'
              ? 'com.mysql.cj.jdbc.Driver'
              : engine == 'mariadb'
              ? 'org.mariadb.jdbc.Driver'
              : 'org.postgresql.Driver',
          driverVersion: 'test fixture',
        );
      };
      final model = metadataFixture(
        WorkbenchModel(root)
          ..backend = backend
          ..draftRecovery = false
          ..newDocument(),
      );
      final profile = rpc.Profile(
        id: 'warehouse',
        name: 'testdb mysql',
        engine: rpc.Engine.MYSQL,
        host: 'db.example.test',
        port: 3306,
        database: 'testdb',
        user: 'analyst',
        environment: rpc.Environment.DEVELOPMENT,
      );
      model.profiles.addAll([
        profile,
        rpc.Profile(id: 'new-1', name: 'New connection'),
        rpc.Profile(id: 'new-2', name: 'New connection'),
      ]);
      model.sessions['query'] = rpc.SessionInfo(
        metadataSourceIdentity: fixtureMetadataSourceIdentity,
        sessionId: 'query',
        profile: profile,
        autoCommit: true,
        currentCatalog: 'testdb',
        currentSchema: 'testdb',
      );
      model.connectionOwner(profile).sessionId = 'query';
      model.explorerSessions[profile.id] = 'query';
      model.document
        ..profileId = profile.id
        ..sessionId = 'query';
      backend.client.metadataAction = (request) async => rpc.SchemaObjects(
        complete: true,
        availability: 'available',
        objects: switch (request.kind) {
          rpc.ObjectKind.CATALOG => [
            rpc.SchemaObject(name: 'testdb', kind: request.kind),
          ],
          rpc.ObjectKind.SCHEMA => [
            for (final name in ['testdb', 'audit'])
              rpc.SchemaObject(name: name, kind: request.kind),
          ],
          rpc.ObjectKind.TABLE => [
            for (final name in ['customers', 'order_items'])
              rpc.SchemaObject(name: name, kind: request.kind),
          ],
          rpc.ObjectKind.VIEW => [
            rpc.SchemaObject(name: 'order_totals', kind: request.kind),
          ],
          _ => schemaSectionFixture(request.kind),
        },
      );
      backend.client.schemaTools = (request) async => rpc.SchemaToolResult(
        inspectedObject: rpc.SchemaObject(
          kind: request.kind,
          catalog: request.catalog,
          schema: request.schema,
          name: request.objectName,
          table: request.kind == rpc.ObjectKind.TABLE ? '' : request.table,
          identifier: request.identifier,
        ),
        definition:
            "CREATE TABLE customers (\n  id bigint unsigned NOT NULL AUTO_INCREMENT,\n  name varchar(120) NOT NULL,\n  email varchar(255) NOT NULL,\n  status char(8) NOT NULL DEFAULT 'active',\n  created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,\n  PRIMARY KEY (id), UNIQUE KEY email (email)\n);",
        provenance: 'native',
        snapshot: jsonEncode({
          'engine': 'MYSQL',
          'objectDependencies': {
            'T:customers': [],
            'V:order_totals': ['T:customers'],
          },
        }),
      );
      final boundary = GlobalKey();
      final shadows = debugDisableShadows;
      final highlight = FocusManager.instance.highlightStrategy;
      debugDisableShadows = false;
      tester.view
        ..physicalSize = const Size(1280, 800)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        debugDefaultTargetPlatformOverride = previousPlatform;
        debugDisableShadows = shadows;
        FocusManager.instance.highlightStrategy = highlight;
        tester.view.reset();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('busydata/native_menus'),
          null,
        );
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
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        if (destination == null) return;
        final render =
            boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final folder = Directory('$destination/${brightness.name}')
            ..createSync(recursive: true);
          final image = await render.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${folder.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      WorkbenchDocument object(
        String name, {
        String schema = 'testdb',
        rpc.ObjectKind kind = rpc.ObjectKind.TABLE,
        String parent = '',
      }) => model.openTask(
        kind == rpc.ObjectKind.COLUMN
            ? WorkbenchDocumentKind.structure
            : WorkbenchDocumentKind.table,
        name,
        object: DatabaseObjectIdentity(
          profileId: profile.id,
          catalog: 'testdb',
          schema: schema,
          name: name,
          kind: kind,
          parent: parent,
        ),
        profileId: profile.id,
        reuse: false,
      )..sessionId = 'query';
      void result(
        WorkbenchDocument owner,
        String id,
        int count, {
        bool orders = false,
        bool view = false,
      }) {
        final columns = orders
            ? [
                rpc.Column(
                  name: 'order_id',
                  jdbcType: -5,
                  typeName: 'BIGINT UNSIGNED',
                ),
                rpc.Column(
                  name: 'product_id',
                  jdbcType: -5,
                  typeName: 'BIGINT UNSIGNED',
                ),
                rpc.Column(name: 'quantity', jdbcType: 4, typeName: 'INT'),
                rpc.Column(
                  name: 'unit_price',
                  jdbcType: 3,
                  typeName: 'DECIMAL',
                ),
              ]
            : view
            ? [
                rpc.Column(
                  name: 'order_id',
                  jdbcType: -5,
                  typeName: 'BIGINT UNSIGNED',
                ),
                rpc.Column(
                  name: 'customer_email',
                  jdbcType: 12,
                  typeName: 'VARCHAR',
                ),
                rpc.Column(name: 'status', jdbcType: 1, typeName: 'CHAR'),
                rpc.Column(
                  name: 'ordered_at',
                  jdbcType: 93,
                  typeName: 'DATETIME',
                ),
                rpc.Column(name: 'total', jdbcType: 3, typeName: 'DECIMAL'),
              ]
            : [
                rpc.Column(
                  name: 'id',
                  jdbcType: -5,
                  typeName: 'BIGINT UNSIGNED',
                ),
                rpc.Column(name: 'name', jdbcType: 12, typeName: 'VARCHAR'),
                rpc.Column(name: 'email', jdbcType: 12, typeName: 'VARCHAR'),
                rpc.Column(name: 'status', jdbcType: 1, typeName: 'CHAR'),
                rpc.Column(
                  name: 'created_at',
                  jdbcType: 93,
                  typeName: 'TIMESTAMP',
                ),
              ];
        final result = rpc.StatementResult(
          resultId: id,
          complete: true,
          fetchedRows: Int64(count),
          columns: columns,
        );
        model.track(
          rpc.JobInfo(
            jobId: '$id-job',
            executionId: '$id-execution',
            sessionId: 'query',
            target: profile,
            state: rpc.JobState.COMPLETED,
            results: [result],
          ),
          documentId: owner.id,
        );
        const items = [
          (1, 1, 1, '89.99'),
          (1, 5, 2, '12.99'),
          (2, 2, 1, '34.50'),
          (2, 3, 1, '59.00'),
          (3, 4, 1, '42.75'),
          (4, 5, 3, '12.99'),
        ];
        const names = [
          'Avery Chen',
          'Jordan Patel',
          'Morgan Reyes',
          'Sam Okafor',
        ];
        const emails = [
          'avery@example.test',
          'jordan@example.test',
          'morgan@example.test',
          'sam@example.test',
        ];
        const created = [
          '2026-09-01T09:15',
          '2026-09-03T13:40',
          '2026-09-08T08:05',
          '2026-09-12T17:20',
        ];
        for (var i = 0; i < count; i++) {
          model.cache['$id:$i'] = rpc.Row(
            values: orders
                ? [
                    rpc.Value(unsignedInteger: '${items[i].$1}'),
                    rpc.Value(unsignedInteger: '${items[i].$2}'),
                    rpc.Value(signedInteger: '${items[i].$3}'),
                    rpc.Value(decimal: items[i].$4),
                  ]
                : view
                ? [
                    rpc.Value(unsignedInteger: '${i + 1}'),
                    rpc.Value(text: emails[[0, 1, 0, 3][i]]),
                    rpc.Value(
                      text: ['paid', 'shipped', 'pending', 'cancelled'][i],
                    ),
                    rpc.Value(
                      text: [
                        '2026-10-01T10:30',
                        '2026-10-03T14:10',
                        '2026-10-08T16:45',
                        '2026-10-09T11:25',
                      ][i],
                    ),
                    rpc.Value(
                      decimal: ['115.97', '93.50', '42.75', '38.97'][i],
                    ),
                  ]
                : [
                    rpc.Value(unsignedInteger: '${i + 1}'),
                    rpc.Value(text: names[i]),
                    rpc.Value(text: emails[i]),
                    rpc.Value(text: i == 2 ? 'inactive' : 'active'),
                    rpc.Value(text: created[i]),
                  ],
          );
        }
        owner.view.subview = 'data';
      }

      final customers = object('customers');
      final orders = object('order_items');
      final query1 = model.documents.first;
      model.newDocument();
      model.document.profileId = profile.id;
      model.newDocument();
      model.document.profileId = profile.id;
      await capture('01-empty-query');
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      final queryTab = find.byKey(
        ValueKey('document-tab:${model.activeOwner.id}'),
      );
      await tester.tap(queryTab);
      await capture('01-tab-pointer-selected');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      tester
          .widget<InkWell>(
            find.descendant(of: queryTab, matching: find.byType(InkWell)).first,
          )
          .focusNode!
          .requestFocus();
      await capture('01-tab-keyboard-focused');
      FocusManager.instance.highlightStrategy = highlight;
      tester.view.physicalSize = const Size(1280, 720);
      await capture('01-empty-query-short');
      tester.view.physicalSize = const Size(1280, 800);
      model.activateOwner(customers.id);
      customers.view.subview = 'structure';
      await capture('02-customers-structure');
      // Refreshing/reordering is tested separately; this is the assembled form.
      tester.view.physicalSize = const Size(1280, 1194);
      await capture('02-customers-structure-tall');
      for (final section in [
        rpc.ObjectKind.INDEX.value,
        rpc.ObjectKind.CONSTRAINT.value,
        rpc.ObjectKind.FOREIGN_KEY.value,
        rpc.ObjectKind.TRIGGER.value,
        rpc.ObjectKind.TABLE.value,
        10,
      ]) {
        model.inspectStructureSection(customers, section);
        await capture('structure-section-$section');
      }
      model.inspectStructureSection(customers, rpc.ObjectKind.COLUMN.value);

      tester.view.physicalSize = const Size(1280, 800);
      result(customers, 'customers-four', 4);
      model.activateOwner(customers.id);
      await capture('03-customers-data-four');
      tester.view.physicalSize = const Size(1280, 1194);
      await capture('03-customers-data-four-tall');
      tester.view.physicalSize = const Size(1280, 800);
      result(orders, 'orders-six', 6, orders: true);
      model.activateOwner(orders.id);
      await capture('04-orders-data-six');
      tester.view.physicalSize = const Size(1280, 1194);
      await capture('04-orders-data-six-tall');
      tester.view.physicalSize = const Size(1280, 800);
      object('email', kind: rpc.ObjectKind.COLUMN, parent: 'customers');
      await capture('05-column-structure');
      tester.view.physicalSize = const Size(1280, 1194);
      await capture('05-column-structure-tall');
      tester.view.physicalSize = const Size(1280, 800);
      final view = object('order_totals', kind: rpc.ObjectKind.VIEW);
      result(view, 'view-result', 4, view: true);
      model.activateOwner(view.id);
      await capture('06-view-results');
      tester.view.physicalSize = const Size(1280, 1194);
      await capture('06-view-results-tall');
      tester.view.physicalSize = const Size(1280, 800);
      object('customers', schema: 'audit');
      final independent = object('customers');
      model.sessions['customer-second'] = model.sessions['query']!.deepCopy()
        ..sessionId = 'customer-second';
      independent.sessionId = 'customer-second';
      model.select(model.documents.length - 1);
      await capture('07-queries-duplicate-objects');
      tester.view.physicalSize = const Size(1280, 1194);
      await capture('07-queries-duplicate-objects-tall');
      tester.view.physicalSize = const Size(1280, 800);
      model.activateOwner(independent.id);
      await capture('07-independent-customer-selected');
      model.select(model.documents.indexOf(query1));
      final manager = model.commands!.invoke(
        'connection.edit',
        model.commandContext,
      );
      await tester.pumpAndSettle();
      Future<void> fill(String key, String value) => tester.enterText(
        find.descendant(
          of: find.byKey(ValueKey('connection-$key')),
          matching: find.byType(EditableText),
        ),
        value,
      );
      await fill('name', 'testdb mysql');
      if (find.text('PostgreSQL').evaluate().isNotEmpty) {
        await tester.tap(find.text('PostgreSQL').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('MySQL').last);
        await tester.pumpAndSettle();
      }
      await fill('host', 'localhost');
      await fill('user', 'tester');
      await fill('password', 'test');
      await tester.tap(find.text('Never').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OS secure storage').last);
      await tester.pumpAndSettle();
      await fill('database', 'testdb');
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(const ValueKey('connection-settings-body')),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .jumpTo(0);
      for (final key in [
        'name',
        'host',
        'port',
        'user',
        'password',
        'database',
      ]) {
        expect(
          find.byKey(ValueKey('connection-$key')).hitTestable(),
          findsOneWidget,
          reason: 'Initial General page must show $key at 1280×800',
        );
      }
      expect(find.text('OS secure storage').hitTestable(), findsOneWidget);
      await capture('08-connection-general');
      tester.view.physicalSize = const Size(1280, 1194);
      await capture('08-connection-general-tall');
      for (final page in ['SSH/SSL', 'Options']) {
        await selectConnectionPage(tester, page);
        await capture(
          '08-connection-${page.replaceAll('/', '-').toLowerCase()}',
        );
      }
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await manager;
      model.activateOwner(customers.id);
      customers.view.subview = 'structure';
      for (final scale in [1.0, 1.5, 2.0]) {
        tester.view.physicalSize = const Size(960, 720);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await capture('structure-small-${(scale * 100).round()}');
      }
      for (final locale in ['de', 'ar']) {
        await tester.runAsync(() => model.saveAppearance('system', locale));
        await tester.pumpAndSettle();
        await capture('structure-$locale-200');
        final opened = model.commands!.invoke(
          'connection.new',
          model.commandContext,
        );
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byKey(const ValueKey('connection-name')),
          matching: find.byType(EditableText),
        );
        final controller = tester.widget<EditableText>(field).controller;
        await fill('name', 'Database · preserved draft');
        for (final scale in [1.5, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await capture('connection-$locale-${(scale * 100).round()}');
          expect(
            tester.widget<EditableText>(field).controller,
            same(controller),
          );
          expect(controller.text, 'Database · preserved draft');
        }
        final l = strings(tester.element(find.byType(ConnectionForm)));
        await tester.ensureVisible(find.text(l.cancel).last);
        await tester.tap(find.text(l.cancel).last);
        await tester.pumpAndSettle();
        await opened;
      }
      expect(
        backend.client.executions,
        isEmpty,
        reason: 'presentation fixtures never execute SQL',
      );
      expect(find.byType(ObjectDocumentView), findsOneWidget);
      debugDefaultTargetPlatformOverride = previousPlatform;
      debugDisableShadows = shadows;
    });
  }
}
