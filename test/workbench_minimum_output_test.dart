import 'dart:io';
import 'dart:ui' show Tristate;
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:re_editor/re_editor.dart';
import 'support/fake_backend.dart';

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
  });
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      (TextDirection.ltr, 'en'),
      (TextDirection.rtl, 'en'),
      (TextDirection.rtl, 'ar'),
    ]) {
      final (direction, language) = scenario;
      testWidgets(
        '${controls.runtimeType} minimum native allocation at 200% ${direction.name} $language keeps retained rows usable',
        (tester) async {
          final semantics = tester.ensureSemantics();
          final locale = Locale(language);
          final l = await AppLocalizations.delegate.load(locale);
          var disposed = false;
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('busydata-minimum-output-'),
          ))!;
          final backend = TestBackend();
          final model = WorkbenchModel(root, presentationWrite: (_, _) async {})
            ..draftRecovery = false
            ..backend = backend
            ..newDocument(text: 'SELECT retained_source;');
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            if (!disposed) semantics.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          model.document.sessionId = 'new-session';
          model.sessions['new-session'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'new-session',
            autoCommit: true,
            transaction: rpc.TransactionState.IDLE,
            profile: rpc.Profile(
              id: 'new-profile',
              name: 'New target',
              host: 'new.example',
              database: 'new',
              environment: rpc.Environment.STAGING,
            ),
            currentCatalog: 'new',
            currentSchema: 'public',
          );
          model.profiles.add(model.sessions['new-session']!.profile);
          model.document.profileId = 'new-profile';
          final original = rpc.Profile(
            name: 'Original source',
            host: 'original.example',
            database: 'original',
            environment: rpc.Environment.PRODUCTION,
          );
          final result = rpc.StatementResult(
            resultId: 'snapshot',
            fetchedRows: Int64(2),
            complete: true,
            columns: [
              rpc.Column(name: 'id', typeName: 'bigint'),
              rpc.Column(name: 'n', typeName: 'text'),
            ],
          );
          model.track(
            rpc.JobInfo(
              jobId: 'job',
              executionId: 'execution',
              sessionId: 'old-session',
              target: original,
              sourceSchema: 'public',
              state: rpc.JobState.COMPLETED,
              durationMs: Int64(146),
              results: [result],
            ),
            documentId: model.document.id,
          );
          model.retainedResults[result.resultId] = rpc.RetainedResult(
            result: result,
            executionId: 'execution',
            sessionId: 'old-session',
            target: original,
            sourceSchema: 'public',
          );
          for (var i = 0; i < 2; i++) {
            model.cache['snapshot:$i'] = rpc.Row(
              values: [
                rpc.Value(signedInteger: '${i + 1}'),
                rpc.Value(text: 'exact retained ${i + 1}'),
              ],
            );
          }
          model.updateStatus('Retained snapshot selected');
          // The 900×600 Linux host also reserves its native header and 264px
          // Explorer. Test the actual remaining allocation, including provenance.
          await tester.binding.setSurfaceSize(const Size(624, 540));
          final view = MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              highContrast: true,
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: direction,
              child: WorkbenchView(model: model, controls: controls),
            ),
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(
                    locale: locale,
                    localizationsDelegates: const [AppLocalizations.delegate],
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme: fluent.FluentThemeData(
                      typography:
                          fluent.Typography.fromBrightness(
                            brightness: Brightness.light,
                          ).merge(
                            const fluent.Typography.raw(
                              body: TextStyle(
                                fontSize: 14,
                                height: 1.9,
                                color: Colors.black,
                              ),
                            ),
                          ),
                    ),
                    home: view,
                  )
                : MaterialApp(
                    locale: locale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    theme:
                        BusyDataYaruTheme.build(
                          brightness: Brightness.light,
                          accentColor: Colors.orange,
                        ).copyWith(
                          textTheme: ThemeData().textTheme.copyWith(
                            bodyMedium: const TextStyle(
                              fontSize: 14,
                              height: 1.9,
                            ),
                          ),
                        ),
                    home: Scaffold(body: view),
                  ),
          );
          await tester.pumpAndSettle();
          final error = tester.takeException();
          expect(
            error,
            isNull,
            reason: error is FlutterError
                ? error.diagnostics.map((d) => d.toStringDeep()).join("\n")
                : null,
          );
          final table = find.byType(TableView);
          final first = find.bySemanticsLabel('${l.row} 1, id: 1');
          expect(first, findsOneWidget);
          final bounds = tester.getRect(table);
          expect(
            bounds.height,
            greaterThanOrEqualTo(88),
            reason:
                'Editor ${tester.getRect(find.byType(CodeEditor))}; '
                'row ${tester.getRect(first)}; menus ${tester.getRect(find.bySemanticsLabel(l.executionOptions))}; '
                'More ${find.text(l.more).evaluate().map((e) => tester.getRect(find.byWidget(e.widget))).toList()}',
          );
          expect(tester.getRect(first).top, greaterThanOrEqualTo(bounds.top));
          expect(
            tester.getRect(first).bottom,
            lessThanOrEqualTo(bounds.bottom),
          );
          expect(
            tester.getRect(find.text('Retained snapshot selected')).top,
            greaterThanOrEqualTo(bounds.bottom),
          );
          expect(find.textContaining('Original source'), findsOneWidget);
          await tester.tap(first);
          await tester.pump();
          expect(
            tester
                .getSemantics(first)
                .getSemanticsData()
                .flagsCollection
                .isFocused,
            Tristate.isTrue,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
          await tester.pumpAndSettle();
          final second = find.bySemanticsLabel('${l.row} 2, id: 2');
          expect(second, findsOneWidget);
          expect(
            tester.getRect(table).contains(tester.getCenter(second)),
            isTrue,
          );
          expect(model.resultView(result.resultId).selectedRow, 1);
          final editorState = tester.state(find.byType(CodeEditor));
          final focused = FocusManager.instance.primaryFocus;
          await tester.binding.setSurfaceSize(const Size(624, 740));
          await tester.pumpAndSettle();
          expect(tester.state(find.byType(CodeEditor)), same(editorState));
          expect(FocusManager.instance.primaryFocus, same(focused));
          await tester.binding.setSurfaceSize(const Size(624, 540));
          await tester.pumpAndSettle();
          expect(tester.state(find.byType(CodeEditor)), same(editorState));
          expect(FocusManager.instance.primaryFocus, same(focused));
          expect(model.resultView(result.resultId).selectedRow, 1);
          final gridMenu = find.descendant(
            of: table,
            matching: find.text(l.more),
          );
          expect(gridMenu, findsOneWidget);
          if (controls is LinuxControls) {
            const menus = MethodChannel(nativeMenuChannelName);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(menus, (call) async {
                  if (call.method != 'show') return null;
                  final entries = (call.arguments as Map)['entries'] as List;
                  expect((entries.first as Map)['label'], l.viewDetails);
                  expect(
                    entries.where(
                      (entry) => (entry as Map)['label'] == l.viewDetails,
                    ),
                    hasLength(1),
                  );
                  return 0; // Select the actual captured GTK menu entry.
                });
            addTearDown(() {
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                  .setMockMethodCallHandler(menus, null);
            });
          }
          await tester.tap(gridMenu);
          await tester.pumpAndSettle();
          if (controls is WindowsControls) {
            await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            await tester.pumpAndSettle();
            expect(model.resultView(result.resultId).selectedRow, 1);
            await tester.tap(find.text(l.viewDetails));
            await tester.pumpAndSettle();
          }
          expect(find.textContaining('Original source'), findsNWidgets(2));
          expect(
            find.widgetWithText(
              SelectableText,
              'Original source · ${l.production}\noriginal.example:0/original/public',
            ),
            findsOneWidget,
          );
          expect(find.text('${l.fetchedRows}: 2'), findsOneWidget);
          expect(find.textContaining('146 ms'), findsOneWidget);
          await tester.tap(find.text(l.close));
          await tester.pumpAndSettle();
          expect(model.resultView(result.resultId).selectedRow, 1);
          expect(model.document.editor.text, 'SELECT retained_source;');
          expect(model.document.sessionId, 'new-session');
          expect(backend.client.executions, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          semantics.dispose();
          disposed = true;
        },
      );
    }
  }
}
