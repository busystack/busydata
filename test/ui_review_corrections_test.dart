import 'dart:io';
import 'dart:ui' as ui;
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/connection_form.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/document_presentation.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/common/workbench_tabs.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/connection_widgets.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';
import 'ui_parity_screen_gallery_test.dart' show realFonts;

void main() {
  final destination = Platform.environment['BUSYDATA_REVIEW_GALLERY_OUTPUT'];
  if (destination != null) setUpAll(realFonts);
  Future<void> capture(
    WidgetTester tester,
    DesktopControls controls,
    String name,
  ) async {
    if (destination == null || controls is! LinuxControls) return;
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: name);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('review-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(destination)..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<WorkbenchModel> fixture(WidgetTester tester) async {
    installNativeWindowFixture(tester);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('busydata/native_menus'),
      (_) async => throw MissingPluginException(),
    );
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('ui-review-'),
    ))!;
    final model = WorkbenchModel(root)
      ..draftRecovery = false
      ..backend = TestBackend()
      ..newDocument();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.binding.setSurfaceSize(null);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('busydata/native_menus'),
        null,
      );
      await tester.runAsync(() => root.delete(recursive: true));
    });
    return model;
  }

  Widget app(DesktopControls controls, Widget child, {double scale = 1}) {
    Widget scaled(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
    return RepaintBoundary(
      key: const ValueKey('review-capture'),
      child: controls is WindowsControls
          ? fluent.FluentApp(
              debugShowCheckedModeBanner: false,
              builder: scaled,
              home: child,
            )
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: BusyDataYaruTheme.build(
                brightness: Brightness.dark,
                accentColor: const Color(0xff3584e4),
              ),
              builder: scaled,
              home: Scaffold(body: child),
            ),
    );
  }

  rpc.StatementResult result(String id) => rpc.StatementResult(
    resultId: id,
    complete: true,
    fetchedRows: Int64.ONE,
    columns: [rpc.Column(name: 'id', jdbcType: 4, typeName: 'INTEGER')],
  );

  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} Production console target survives selecting Development history',
      (tester) async {
        final model = await fixture(tester);
        final backend = model.backend! as TestBackend;
        final sql = model.document, owner = model.activeOwner;
        final development = rpc.Profile(
              id: 'dev',
              name: 'Development database',
              host: 'dev.example',
              port: 5432,
              database: 'analytics',
              environment: rpc.Environment.DEVELOPMENT,
            ),
            production = rpc.Profile(
              id: 'prod',
              name: 'Production database',
              host: 'prod.example',
              port: 5432,
              database: 'analytics',
              environment: rpc.Environment.PRODUCTION,
            );
        model.profiles.addAll([development, production]);
        for (final profile in [development, production]) {
          model.sessions[profile.id] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: profile.id,
            profile: profile,
            autoCommit: true,
            currentCatalog: 'analytics',
            currentSchema: 'public',
          );
        }
        sql
          ..profileId = 'dev'
          ..sessionId = 'dev';
        final oldResult = result('dev-result');
        model.track(
          rpc.JobInfo(
            jobId: 'dev-job',
            executionId: 'dev-execution',
            sessionId: 'dev',
            target: development,
            state: rpc.JobState.COMPLETED,
            results: [oldResult],
          ),
          documentId: owner.id,
        );
        model.retainedResults[oldResult.resultId] = rpc.RetainedResult(
          result: oldResult,
          target: development,
          sessionId: 'dev',
          executionId: 'dev-execution',
        );
        model.cache['dev-result:0'] = rpc.Row(
          values: [rpc.Value(signedInteger: '1')],
        );
        backend.client.sessionCommand = (request) async => rpc.SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: request.sessionId,
          profile: model.sessions[request.sessionId]!.profile,
          transaction: rpc.TransactionState.DISCONNECTED,
        );
        await tester.runAsync(() => model.disconnectRetainedSession('dev'));
        expect(sql.sessionId, isNull);
        // A disconnected console must also name its prospective target.
        sql.profileId = production.id;
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        final view = WorkbenchView(model: model, controls: controls);
        await tester.pumpWidget(app(controls, view));
        await tester.pumpAndSettle();
        final tab = find.byKey(ValueKey('document-tab:${owner.id}'));
        expect(
          find.descendant(of: tab, matching: find.text('Production')),
          findsOneWidget,
        );
        model.shareSession(sql, 'prod');
        model.selectExecution('dev-execution', owner: owner);
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: tab, matching: find.text('Production')),
          findsOneWidget,
        );
        final label = documentTabLabel(tester.element(tab), model, owner);
        expect(label.context, contains('Production database'));
        expect(label.context, isNot(contains('dev.example')));
        expect(
          find.textContaining('Development database').hitTestable(),
          findsWidgets,
        );
        expect(model.retainedResults['dev-result']!.target, development);
        expect(model.execution(rpc.ExecutionMode.SCRIPT).sessionId, 'prod');
        await capture(
          tester,
          controls,
          'console-production-with-development-result',
        );
        model.openRetainedResult(model.retainedResults['dev-result']!);
        await tester.pumpAndSettle();
        final retainedTab = find.byKey(
          ValueKey('document-tab:${model.activeOwner.id}'),
        );
        expect(
          documentTabLabel(
            tester.element(retainedTab),
            model,
            model.activeOwner,
          ).context,
          contains('Development database'),
        );
        expect(
          find.descendant(of: retainedTab, matching: find.text('Production')),
          findsNothing,
        );
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    for (final state in [
      rpc.JobState.FAILED,
      rpc.JobState.CANCELLED,
      rpc.JobState.COMPLETED,
    ]) {
      for (final compact in [false, true]) {
        testWidgets(
          '${controls.runtimeType} Data history A to ${state.name} B to A compact=$compact',
          (tester) async {
            final model = await fixture(tester);
            final backend = model.backend! as TestBackend;
            final owner = model.openTask(
              WorkbenchDocumentKind.table,
              'customers',
              object: const DatabaseObjectIdentity(
                profileId: 'p',
                catalog: 'db',
                schema: 'public',
                kind: rpc.ObjectKind.TABLE,
                name: 'customers',
              ),
            );
            owner.view.subview = 'data';
            model.track(
              rpc.JobInfo(
                jobId: 'a',
                executionId: 'a',
                state: rpc.JobState.COMPLETED,
                durationMs: Int64.ONE,
                results: [result('rows-a')],
              ),
              documentId: owner.id,
            );
            model.cache['rows-a:0'] = rpc.Row(
              values: [rpc.Value(signedInteger: '11')],
            );
            model.track(
              rpc.JobInfo(
                jobId: 'b',
                executionId: 'b',
                state: state,
                durationMs: Int64(2),
                messages: ['Execution B'],
                results: [
                  if (state == rpc.JobState.COMPLETED)
                    rpc.StatementResult(updateCount: Int64(3)),
                ],
              ),
              documentId: owner.id,
            );
            model.selectExecution('a', owner: owner);
            await tester.binding.setSurfaceSize(
              compact ? const Size(624, 360) : const Size(1280, 800),
            );
            await tester.pumpWidget(
              app(controls, WorkbenchView(model: model, controls: controls)),
            );
            await tester.pumpAndSettle();
            final history = find.byKey(
              ValueKey('table-execution-history:${owner.id}'),
            );
            expect(history.hitTestable(), findsOneWidget);
            await capture(
              tester,
              controls,
              'history-${state.name.toLowerCase()}-${compact ? 'compact' : 'normal'}-a',
            );
            await tester.tap(
              find.descendant(of: history, matching: find.text('Results')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.textContaining('2 ms').last);
            await tester.pumpAndSettle();
            expect(model.jobForOwner(owner)!.executionId, 'b');
            expect(find.byType(ResultGrid), findsNothing);
            expect(find.text('Execution B'), findsOneWidget);
            expect(history.hitTestable(), findsOneWidget);
            await capture(
              tester,
              controls,
              'history-${state.name.toLowerCase()}-${compact ? 'compact' : 'normal'}-b',
            );
            await tester.tap(
              find.descendant(of: history, matching: find.text('Results')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Completed · 1 ms').last);
            await tester.pumpAndSettle();
            expect(model.activeOwner, same(owner));
            expect(model.jobForOwner(owner)!.executionId, 'a');
            expect(model.resultForOwner(owner)!.resultId, 'rows-a');
            expect(find.byType(ResultGrid), findsOneWidget);
            expect(history.hitTestable(), findsOneWidget);
            await capture(
              tester,
              controls,
              'history-${state.name.toLowerCase()}-${compact ? 'compact' : 'normal'}-return-a',
            );
            expect(backend.client.executions, isEmpty);
            expect(backend.client.opened, isEmpty);
            owner.view.subview = 'structure';
            model.updateStatus('Structure');
            await tester.pumpAndSettle();
            expect(history, findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    for (final connectionNames in [false, true]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} rendered same-prefix ${connectionNames ? 'connections' : 'schemas'} stay distinct at $scale',
          (tester) async {
            final model = await fixture(tester);
            final owners = <WorkbenchDocument>[];
            for (final (index, scope) in [
              'customer_prod_eu',
              'customer_prod_us',
            ].indexed) {
              final id = connectionNames ? '$index' : 'p';
              if (!model.profiles.any((p) => p.id == id)) {
                model.profiles.add(
                  rpc.Profile(id: id, name: connectionNames ? scope : 'Shared'),
                );
              }
              owners.add(
                model.openTask(
                  WorkbenchDocumentKind.table,
                  'customers',
                  reuse: false,
                  profileId: id,
                  object: DatabaseObjectIdentity(
                    profileId: id,
                    catalog: 'db',
                    schema: connectionNames ? 'public' : scope,
                    kind: rpc.ObjectKind.TABLE,
                    name: 'customers',
                  ),
                ),
              );
            }
            await tester.binding.setSurfaceSize(const Size(624, 540));
            await tester.pumpWidget(
              app(
                controls,
                ListenableBuilder(
                  listenable: model,
                  builder: (_, _) => WorkbenchTabs(
                    model: model,
                    controls: controls,
                    close: (_) {},
                  ),
                ),
                scale: scale,
              ),
            );
            final visible = <String>{};
            for (final owner in owners) {
              model.activateOwner(owner.id);
              await tester.pumpAndSettle();
              final tab = find.byKey(ValueKey('document-tab:${owner.id}'));
              final label = documentTabLabel(tester.element(tab), model, owner);
              expect(label.instance, isNotEmpty);
              if (scale == 2) {
                final qualifier = find.descendant(
                  of: tab,
                  matching: find.text(label.qualifier),
                );
                expect(
                  tester
                      .renderObject<RenderParagraph>(qualifier)
                      .didExceedMaxLines,
                  isTrue,
                );
              }
              final marker = find.descendant(
                of: tab,
                matching: find.text(label.instance),
              );
              final text = tester.widget<Text>(marker);
              expect(text.overflow, isNull);
              final rect = tester.getRect(marker);
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(624));
              expect(marker.hitTestable(), findsOneWidget);
              visible.add(text.data!);
              await capture(
                tester,
                controls,
                'tabs-${connectionNames ? 'connections' : 'schemas'}-${(scale * 100).round()}-${visible.length}',
              );
            }
            expect(visible, hasLength(2));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      '${controls.runtimeType} General shrinks in tall windows and preserves scaled drafts',
      (tester) async {
        final model = await fixture(tester);
        var scale = 1.0;
        final view = WorkbenchView(model: model, controls: controls);
        await tester.binding.setSurfaceSize(const Size(1280, 1194));
        await tester.pumpWidget(app(controls, view));
        await tester.pumpAndSettle();
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
        controller.value = const TextEditingValue(
          text: 'Preserved draft',
          selection: TextSelection(baseOffset: 2, extentOffset: 6),
          composing: TextRange(start: 0, end: 9),
        );
        await tester.pumpAndSettle();
        final content = tester.getRect(
          find.byKey(const ValueKey('connection-page-content')),
        );
        final testButton = tester.getRect(find.text('Test connection'));
        expect(testButton.top - content.bottom, inInclusiveRange(0, 70));
        await capture(tester, controls, 'connection-general-tall');
        expect(
          tester
              .getRect(find.byKey(const ValueKey('connection-source-list')))
              .height,
          lessThan(800),
        );
        final editing = controller.value;
        for (final size in [const Size(1280, 800), const Size(1280, 1194)]) {
          await tester.binding.setSurfaceSize(size);
          for (scale in [1, 1.5, 2]) {
            await tester.pumpWidget(app(controls, view, scale: scale));
            await tester.pumpAndSettle();
            expect(
              tester.widget<EditableText>(field).controller,
              same(controller),
            );
            expect(controller.value, editing);
            if (scale == 1 && size.height == 800) {
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
                  reason: key,
                );
              }
              expect(find.text('Driver').hitTestable(), findsOneWidget);
              expect(
                find.text('Password storage').hitTestable(),
                findsOneWidget,
              );
            }
            expect(find.text('Test connection').hitTestable(), findsOneWidget);
            expect(find.text('Cancel').last.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
            await capture(
              tester,
              controls,
              'connection-${size.height.round()}-${(scale * 100).round()}',
            );
          }
        }
        for (final page in ['SSH/SSL', 'Options', 'General']) {
          await selectConnectionPage(tester, page);
          expect(controller.value, editing);
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        await opened;
        expect(find.byType(ConnectionForm), findsNothing);
      },
    );
  }
}
