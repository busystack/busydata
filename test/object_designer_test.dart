import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/documents.dart'
    show atomicWrite;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/object_designer.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const menus = MethodChannel('busydata/native_menus');
  setUp(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          menus,
          (_) async => throw MissingPluginException(),
        ),
  );
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(menus, null),
  );
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} explicitly loads referenced schema and rejects edited late reviews',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1400, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final reference = ObjectDesignerReferenceState();
        final metadata = <String>[];
        var pendingMetadata = Completer<Map<String, List<String>>>();
        var pendingPlan = Completer<rpc.SchemaToolResult>();
        final requests = <rpc.SchemaToolRequest>[];
        final opened = <rpc.SchemaToolResult>[];
        final form = ObjectDesignerForm(
          controls: ui,
          referenceState: reference,
          inspected: rpc.SchemaToolResult(
            snapshot: jsonEncode({
              'engine': 'POSTGRESQL',
              'schema': 'current schema',
              'tables': {
                'local table': {
                  'columns': {
                    'id': {'type': 'integer'},
                  },
                },
              },
              'views': {},
              'routines': {},
            }),
          ),
          target: rpc.SchemaToolRequest(
            sessionId: 'captured-session',
            schema: 'current schema',
            table: 'local table',
          ),
          inspectReferenceSchema: (schema) {
            metadata.add(schema);
            return pendingMetadata.future;
          },
          generate: (request) {
            requests.add(request.deepCopy());
            return pendingPlan.future;
          },
          openSql: opened.add,
        );
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: form))
              : MaterialApp(home: Scaffold(body: form)),
        );
        Finder field(String label) {
          final container = ui is WindowsControls
              ? find.byWidgetPredicate(
                  (w) =>
                      w is fluent.InfoLabel && w.label.toPlainText() == label,
                )
              : find.bySemanticsLabel(label);
          return find.descendant(
            of: container,
            matching: find.byType(EditableText),
          );
        }

        Future<void> choose(String current, String desired) async {
          await tester.tap(find.text(current).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(desired).last);
          await tester.pumpAndSettle();
        }

        await choose('Edit column properties', 'Keys and constraints');
        await choose('Unique constraint', 'Foreign key');
        await tester.enterText(
          field('Referenced schema / database'),
          'other schema',
        );
        await tester.pumpAndSettle();
        expect(metadata, isEmpty);
        expect(requests, isEmpty);
        expect(reference.schema, 'current schema');
        await tester.tap(
          find.text('Inspect structure · Referenced schema / database'),
        );
        await tester.pump();
        expect(metadata, ['other schema']);
        await tester.enterText(
          field('Referenced schema / database'),
          'desired schema',
        );
        pendingMetadata.complete({
          'stale table': ['stale column'],
        });
        await tester.pumpAndSettle();
        expect(reference.schema, 'current schema');
        expect(reference.columns.containsKey('stale table'), isFalse);
        expect(
          find.textContaining('Inspection context changed'),
          findsOneWidget,
        );
        pendingMetadata = Completer<Map<String, List<String>>>();
        await tester.tap(
          find.text('Inspect structure · Referenced schema / database'),
        );
        await tester.pump();
        pendingMetadata.complete({
          'remote, table': ['quoted, id', '二'],
        });
        await tester.pumpAndSettle();
        expect(metadata, ['other schema', 'desired schema']);
        expect(reference.schema, 'desired schema');
        await choose('Referenced table', 'remote, table');
        await choose('Add column', 'id');
        await tester.tap(find.text('Add column').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('quoted, id').last);
        await tester.pumpAndSettle();
        await tester.enterText(
          field('Object / column name'),
          'safe foreign key',
        );
        await tester.tap(find.text('Generate reviewed DDL'));
        await tester.pump();
        expect(requests.single.referenceSchema, 'desired schema');
        expect(requests.single.referenceTable, 'remote, table');
        expect(requests.single.referenceColumns, ['quoted, id']);
        expect(requests.single.objectColumns, ['id']);
        expect(requests.single.sessionId, 'captured-session');
        await tester.enterText(
          field('Object / column name'),
          'changed while generating',
        );
        pendingPlan.complete(
          rpc.SchemaToolResult(complete: true, sql: ['ALTER TABLE captured;']),
        );
        await tester.pumpAndSettle();
        expect(opened, isEmpty);
        expect(find.textContaining('review expired'), findsOneWidget);
        pendingPlan = Completer<rpc.SchemaToolResult>();
        await tester.tap(find.text('Generate reviewed DDL'));
        await tester.pump();
        pendingPlan.complete(
          rpc.SchemaToolResult(complete: true, sql: ['ALTER TABLE fresh;']),
        );
        await tester.pumpAndSettle();
        expect(opened.single.sql, ['ALTER TABLE fresh;']);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${ui.runtimeType} opens Create table from a connected empty schema without executing SQL',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-empty-designer-'),
        ))!;
        final backend = TestBackend();
        backend.client.schemaTools = (_) async => rpc.SchemaToolResult(
          complete: true,
          snapshot: jsonEncode({
            'engine': 'POSTGRESQL',
            'schema': 'empty schema',
            'tables': {},
            'views': {},
            'routines': {},
          }),
        );
        ({File file, List<int> bytes})? recoveryWrite, presentationWrite;
        final recoverySaved = Completer<void>();
        final presentationSaved = Completer<void>();
        final model = WorkbenchModel(
          root,
          recoveryWrite: (file, bytes) {
            expect(recoveryWrite, isNull);
            recoveryWrite = (file: file, bytes: List<int>.of(bytes));
            return recoverySaved.future;
          },
          presentationWrite: (file, bytes) {
            expect(presentationWrite, isNull);
            presentationWrite = (file: file, bytes: List<int>.of(bytes));
            return presentationSaved.future;
          },
        )..draftRecovery = false;
        model.newDocument(text: '-- keep this draft');
        model.backend = backend;
        model.document.sessionId = 'owned-session';
        model.sessions['owned-session'] = rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'owned-session',
          currentSchema: 'empty schema',
          profile: rpc.Profile(name: 'Development', database: 'test'),
          transaction: rpc.TransactionState.IDLE,
          autoCommit: true,
        );
        expect(model.activeOwner.object, isNull);
        await tester.binding.setSurfaceSize(const Size(1400, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        addTearDown(() async {
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(
                  theme: BusyDataYaruTheme.build(
                    brightness: Brightness.light,
                    accentColor: const Color(0xFFE95420),
                  ),
                  home: view,
                ),
        );
        if (ui is LinuxControls) {
          await tester.tap(find.byKey(const ValueKey('workbench-main-menu')));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Database').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Object').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Object designer'));
        await tester.pumpAndSettle();
        expect(backend.client.schemaToolRequests, hasLength(1));
        final inspected = backend.client.schemaToolRequests.single;
        expect(inspected.action, rpc.SchemaToolAction.INSPECT_OBJECT);
        expect(inspected.sessionId, 'owned-session');
        expect(inspected.schema, 'empty schema');
        expect(inspected.table, isEmpty);
        expect(find.text('Create table'), findsOneWidget);
        expect(find.text('New table name'), findsOneWidget);
        expect(model.document.editor.text, '-- keep this draft');
        expect(backend.client.jobRequests, isEmpty);
        await tester.tap(
          find.bySemanticsLabel(RegExp('^Close tab .*Object designer')),
        );
        await tester.pumpAndSettle();
        // Run native output workers outside widget fake time and acknowledge
        // each real save before expecting the designer to close.
        expect(recoveryWrite, isNotNull);
        expect(presentationWrite, isNull);
        expect(find.byType(ObjectDesignerForm), findsOneWidget);
        await tester.runAsync(
          () => atomicWrite(recoveryWrite!.file, recoveryWrite!.bytes),
        );
        recoverySaved.complete();
        await tester.pumpAndSettle();
        expect(presentationWrite, isNotNull);
        expect(find.byType(ObjectDesignerForm), findsOneWidget);
        await tester.runAsync(
          () => atomicWrite(presentationWrite!.file, presentationWrite!.bytes),
        );
        presentationSaved.complete();
        await tester.pumpAndSettle();
        expect(find.byType(ObjectDesignerForm), findsNothing);
        expect(model.pendingOperations, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '${ui.runtimeType} designs nullable changes with captured metadata and target',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final snapshot = jsonEncode({
          'engine': 'POSTGRESQL',
          'schema': 'quoted schema',
          'tables': {
            'quoted table': {
              'columns': {
                'id': {
                  'type': 'integer',
                  'nullable': false,
                  'default': null,
                  'special': '',
                  'generated': '',
                  'ordinal': 1,
                },
              },
              'indexes': {},
              'constraints': {},
              'properties': {},
              'triggers': {},
            },
          },
          'views': {},
          'routines': {},
        });
        rpc.SchemaToolRequest? captured;
        rpc.SchemaToolResult? opened;
        final form = SizedBox(
          width: 650,
          height: 1000,
          child: ObjectDesignerForm(
            controls: ui,
            inspected: rpc.SchemaToolResult(
              snapshot: snapshot,
              definition: 'captured definition',
            ),
            target: rpc.SchemaToolRequest(
              sessionId: 'captured-session',
              schema: 'quoted schema',
              table: 'quoted table',
            ),
            generate: (request) async {
              captured = request;
              return rpc.SchemaToolResult(
                complete: true,
                sql: ['ALTER TABLE ...;'],
              );
            },
            openSql: (plan) => opened = plan,
          ),
        );
        await tester.pumpWidget(
          ui is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: form))
              : MaterialApp(home: Scaffold(body: form)),
        );
        await tester.tap(find.text('Choose existing object').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('id').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Column type'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nullable / NOT NULL').last);
        await tester.pumpAndSettle();
        // Nullable is a boolean preference; toggling it preserves the captured
        // metadata and target used by the generated review.
        await tester.tap(find.text('Nullable').last);
        await tester.pumpAndSettle();
        expect(captured, isNull);
        await tester.tap(find.text('Generate reviewed DDL'));
        await tester.pumpAndSettle();
        expect(captured!.sessionId, 'captured-session');
        expect(captured!.schema, 'quoted schema');
        expect(captured!.table, 'quoted table');
        expect(captured!.sourceSnapshot, snapshot);
        expect(captured!.column, 'id');
        expect(captured!.value, 'true');
        expect(opened!.sql, ['ALTER TABLE ...;']);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
