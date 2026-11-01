import 'dart:async';
import 'dart:io';
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:busydata/src/app/busydata_design.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/metadata_settings_dialog.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'support/fake_backend.dart';

class MetadataSettingsClient extends TestClient {
  final requests = <rpc.MetadataSettingsRequest>[];
  Future<rpc.MetadataSettingsReply> Function(rpc.MetadataSettingsRequest)? run;
  int cancelled = 0;
  @override
  ResponseFuture<rpc.MetadataSettingsReply> metadataSettings(
    rpc.MetadataSettingsRequest request, {
    CallOptions? options,
  }) {
    requests.add(request.deepCopy());
    return response(run!(request), onCancel: () => cancelled++);
  }
}

rpc.MetadataSettingsReply reply(rpc.MetadataSettingsRequest request) =>
    rpc.MetadataSettingsReply(
      backendInstance: 'test-instance',
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      profileId: 'p',
      sessionId: 'physical',
      sessionRevision: Int64.ONE,
      contextRevision: Int64(2),
      configurationRevision:
          request.action == rpc.MetadataSettingsAction.SAVE_METADATA_SETTINGS
          ? Int64(6)
          : Int64(5),
      snapshotRevision: Int64(10),
      configuration:
          request.action == rpc.MetadataSettingsAction.SAVE_METADATA_SETTINGS
          ? request.configuration
          : rpc.MetadataIntrospectionConfiguration(
              includedCatalogs: ['catalog/one', 'catalog\nwith newline'],
              includedSchemas: ['same'],
              kinds: [rpc.ObjectKind.VIEW, rpc.ObjectKind.TABLE],
              defaultLevel: 2,
              scopeLevels: [
                rpc.MetadataScopeLevel(
                  catalog: 'catalog/one',
                  schema: 'same',
                  level: 3,
                ),
              ],
            ),
      cacheState: 'AVAILABLE',
      complete: true,
    );

Future<void> selectMetadataSection(
  WidgetTester tester,
  DesktopControls controls,
  String section,
) async {
  if (controls is WindowsControls) {
    final picker = tester
        .widgetList<fluent.ComboBox<String>>(
          find.byWidgetPredicate((widget) => widget is fluent.ComboBox<String>),
        )
        .singleWhere(
          (widget) => widget.items!.any((item) => item.value == 'status'),
        );
    expect(picker.onChanged, isNotNull);
    picker.onChanged!(section);
  } else {
    final picker = tester
        .widgetList<BusyDataPopupSelector<String>>(
          find.byWidgetPredicate(
            (widget) => widget is BusyDataPopupSelector<String>,
          ),
        )
        .singleWhere(
          (widget) => widget.options.any((item) => item.value == 'status'),
        );
    expect(picker.enabled, isTrue);
    picker.onSelected(section);
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} cache failure keeps metadata drafts at $locale $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 1000));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final client = MetadataSettingsClient();
            client.run = (request) async =>
                reply(request)..cacheState = 'WRITE_UNAVAILABLE';
            final model = WorkbenchModel(Directory('/unused'))
              ..draftRecovery = false
              ..backend = TestBackend(client: client)
              ..newDocument();
            model.sessions['physical'] = rpc.SessionInfo(
              metadataSourceIdentity: fixtureMetadataSourceIdentity,
              sessionId: 'physical',
              profile: rpc.Profile(id: 'p', name: 'source'),
              contextRevision: Int64(2),
              sessionRevision: Int64.ONE,
              transaction: rpc.TransactionState.IDLE,
            );
            final l = lookupAppLocalizations(locale);
            final rtl = locale.languageCode == 'ar';
            Widget presentation(BuildContext context, Widget? child) =>
                MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    highContrast: rtl,
                    disableAnimations: rtl,
                  ),
                  child: Directionality(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: child!,
                  ),
                );
            final content = Builder(
              builder: (context) => controls.button(
                'Open metadata',
                () =>
                    showMetadataSettings(context, controls, model, 'physical'),
              ),
            );
            await tester.pumpWidget(
              controls is WindowsControls
                  ? fluent.FluentApp(
                      locale: locale,
                      localizationsDelegates: const [AppLocalizations.delegate],
                      supportedLocales: AppLocalizations.supportedLocales,
                      builder: presentation,
                      home: content,
                    )
                  : MaterialApp(
                      locale: locale,
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      supportedLocales: AppLocalizations.supportedLocales,
                      builder: presentation,
                      home: Scaffold(body: content),
                    ),
            );
            await tester.tap(find.text('Open metadata'));
            await tester.pumpAndSettle();
            final catalog = find
                .byWidgetPredicate(
                  (widget) =>
                      widget is EditableText &&
                      widget.controller.text == 'catalog/one',
                )
                .first;
            await tester.enterText(catalog, 'draft catalog');
            await selectMetadataSection(tester, controls, 'status');
            expect(find.text(l.metadataCacheWriteUnavailable), findsOneWidget);
            final notice = tester.element(
              find.text(l.metadataCacheWriteUnavailable),
            );
            expect(
              Directionality.of(notice),
              rtl ? TextDirection.rtl : TextDirection.ltr,
            );
            expect(MediaQuery.textScalerOf(notice).scale(10), scale * 10);
            expect(MediaQuery.highContrastOf(notice), rtl);
            expect(MediaQuery.disableAnimationsOf(notice), rtl);
            expect(find.textContaining('WRITE_UNAVAILABLE'), findsNothing);
            expect(find.textContaining(l.failed), findsOneWidget);
            await selectMetadataSection(tester, controls, 'configuration');
            expect(
              find.byWidgetPredicate(
                (widget) =>
                    widget is EditableText &&
                    widget.controller.text == 'draft catalog',
              ),
              findsOneWidget,
            );
            expect(client.requests, hasLength(1));
            expect(client.executions, isEmpty);
            expect(tester.takeException(), isNull);
            await tester.tap(find.text(l.close));
            await tester.pumpAndSettle();
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
          },
        );
      }
    }
  }
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets(
        '${controls.runtimeType} metadata exact configuration and cancellable refresh at $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1280, 1000));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final client = MetadataSettingsClient();
          final ownedBackend = TestBackend(client: client);
          final model = WorkbenchModel(Directory('/unused'))
            ..draftRecovery = false
            ..backend = ownedBackend
            ..newDocument();
          model.sessions['physical'] = rpc.SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'physical',
            profile: rpc.Profile(id: 'p', name: 'source'),
            contextRevision: Int64(2),
            sessionRevision: Int64.ONE,
            transaction: rpc.TransactionState.IDLE,
          );
          final refresh = Completer<rpc.MetadataSettingsReply>();
          client.run = (request) async =>
              request.action == rpc.MetadataSettingsAction.FULL_METADATA_REFRESH
              ? refresh.future
              : reply(request);
          final content = Builder(
            builder: (context) => controls.button(
              'Open metadata',
              () => showMetadataSettings(context, controls, model, 'physical'),
            ),
          );
          final body = MediaQuery(
            data: MediaQueryData(
              size: const Size(1280, 1000),
              textScaler: TextScaler.linear(scale),
            ),
            child: content,
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(home: body)
                : MaterialApp(home: Scaffold(body: body)),
          );
          await tester.tap(find.text('Open metadata'));
          await tester.pumpAndSettle();
          expect(client.requests.single.sessionRevision, Int64.ONE);
          expect(find.text('catalog/one'), findsOneWidget);
          await tester.tap(find.text('Incremental refresh'));
          await tester.pumpAndSettle();
          expect(
            client.requests.last.action,
            rpc.MetadataSettingsAction.INCREMENTAL_METADATA_REFRESH,
            reason:
                'Unordered server kind sets must not dirty untouched settings',
          );
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
          final save = client.requests.last;
          expect(
            save.action,
            rpc.MetadataSettingsAction.SAVE_METADATA_SETTINGS,
          );
          expect(save.expectedConfigurationRevision, Int64(5));
          expect(save.configuration.includedCatalogs, [
            'catalog/one',
            'catalog\nwith newline',
          ]);
          expect(save.configuration.scopeLevels.single.catalog, 'catalog/one');
          expect(save.configuration.scopeLevels.single.level, 3);
          await tester.tap(find.text('Full refresh'));
          await tester.pump();
          expect(client.requests.last.expectedConfigurationRevision, Int64(6));
          await tester.tap(find.text('Cancel'));
          await tester.pump();
          expect(client.cancelled, 1);
          refresh.complete(reply(client.requests.last));
          await tester.pumpAndSettle();
          expect(find.text('Cancelled'), findsOneWidget);
          expect(client.executions, isEmpty);
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
        },
      );
    }
  }
  testWidgets('stale metadata settings response never replaces current owner', (
    tester,
  ) async {
    final client = MetadataSettingsClient();
    final model = WorkbenchModel(Directory('/unused'))
      ..draftRecovery = false
      ..backend = TestBackend(client: client)
      ..newDocument();
    model.sessions['physical'] = rpc.SessionInfo(
      metadataSourceIdentity: fixtureMetadataSourceIdentity,
      sessionId: 'physical',
      profile: rpc.Profile(id: 'p'),
      contextRevision: Int64(2),
      sessionRevision: Int64.ONE,
    );
    final pending = Completer<rpc.MetadataSettingsReply>();
    client.run = (_) => pending.future;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showMetadataSettings(
                context,
                const LinuxControls(),
                model,
                'physical',
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    model.sessions['physical']!.contextRevision = Int64(3);
    pending.complete(reply(client.requests.single));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Metadata configuration changed; reopen to review current settings',
      ),
      findsOneWidget,
    );
    expect(find.text('catalog/one'), findsNothing);
    expect(client.executions, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    model.dispose();
  });
}
