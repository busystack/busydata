import 'support/windows_secret_input.dart';
import 'support/connection_widgets.dart';
import 'dart:async';
import 'dart:io';
import 'dart:ui' show SemanticsRole;
import 'package:busydata/l10n/generated/app_localizations.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:busydata/src/ui/common/workbench_search.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  setUpWindowsSecretInputFixture();
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} fitting manager has a named bounded field scope',
      (tester) async {
        if (ui is LinuxControls) installNativeWindowFixture(tester);
        final semantics = tester.ensureSemantics();
        var semanticsDisposed = false;
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('manager-scope-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = TestBackend()
          ..newDocument();
        await tester.binding.setSurfaceSize(const Size(1920, 1080));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          if (!semanticsDisposed) semantics.dispose();
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is LinuxControls
              ? MaterialApp(home: view)
              : fluent.FluentApp(home: view),
        );
        final opened = model.commands!.invoke(
          'connection.new',
          model.commandContext,
        );
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: find.byKey(const ValueKey('connection-password')),
          matching: find.byType(EditableText),
        );
        var node = tester.getSemantics(field).parent;
        while (node != null &&
            node.getSemanticsData().label != 'Data Sources and Drivers') {
          node = node.parent;
        }
        expect(
          node,
          isNotNull,
          reason:
              'The field needs an identifiable form scope even when its body does not scroll.',
        );
        expect(node!.rect.width, lessThan(1920));
        expect(node.rect.height, lessThan(1080));
        for (final editable in tester.widgetList<EditableText>(
          find.byType(EditableText),
        )) {
          var ancestor = tester.getSemantics(find.byWidget(editable)).parent;
          final dialogs = <SemanticsNode>[];
          while (ancestor != null) {
            if (ancestor.getSemanticsData().role == SemanticsRole.dialog) {
              dialogs.add(ancestor);
            }
            ancestor = ancestor.parent;
          }
          expect(dialogs, hasLength(1));
          if (ui is WindowsControls) {
            final dialog = dialogs.single.getSemanticsData();
            expect(dialog.label, 'Data Sources and Drivers');
            expect(dialog.flagsCollection.scopesRoute, isTrue);
            expect(dialog.flagsCollection.namesRoute, isTrue);
          }
        }
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        await opened;
        semantics.dispose();
        semanticsDisposed = true;
      },
    );
  }

  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} manager completion follows Arabic locale at enlarged text',
      (tester) async {
        if (ui is LinuxControls) installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('manager-locale-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = TestBackend()
          ..newDocument();
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        Widget scaled(BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        );
        const locale = Locale('ar');
        final view = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is LinuxControls
              ? MaterialApp(
                  locale: locale,
                  builder: scaled,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: view,
                )
              : fluent.FluentApp(
                  locale: locale,
                  builder: scaled,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: view,
                ),
        );
        final opened = model.commands!.invoke(
          'connection.new',
          model.commandContext,
        );
        await tester.pumpAndSettle();
        expect(find.text('تطبيق').hitTestable(), findsOneWidget);
        expect(find.text('Apply'), findsNothing);
        final name = find.descendant(
          of: find.byKey(const ValueKey('connection-name')),
          matching: find.byType(EditableText),
        );
        expect(tester.getSemantics(name).getSemanticsData().label, 'الاسم');
        await tester.tap(find.text('إلغاء').last);
        await tester.pumpAndSettle();
        await opened;
      },
    );
  }

  testWidgets(
    'source manager keeps source list, pages, test strip and completion separate',
    (tester) async {
      installNativeWindowFixture(tester);
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('source-manager-'),
      ))!;
      final model = WorkbenchModel(root)
        ..draftRecovery = false
        ..backend = TestBackend()
        ..newDocument();
      await tester.binding.setSurfaceSize(const Size(1366, 768));
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        model.dispose();
        await tester.binding.setSurfaceSize(null);
        await tester.runAsync(() => root.delete(recursive: true));
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WorkbenchView(model: model, controls: const LinuxControls()),
        ),
      );
      final opened = model.commands!.invoke(
        'connection.new',
        model.commandContext,
      );
      await tester.pumpAndSettle();
      expect(find.text('Data Sources and Drivers'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connection-source-list')),
        findsOneWidget,
      );
      for (final label in [
        'General',
        'Test connection',
        'Save & connect',
        'Cancel',
        'Apply',
      ]) {
        expect(
          find.text(label).last.hitTestable(),
          findsOneWidget,
          reason: label,
        );
      }
      expect(find.text('Connection type: Default (TCP)'), findsOneWidget);
      expect(find.text('Authentication: User & Password'), findsOneWidget);
      expect(find.text('URL'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('connection-page-selector')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('connection-add-source')));
      await tester.pumpAndSettle();
      expect(find.text('New connection · 1 *'), findsOneWidget);
      expect(find.text('New connection · 2 *'), findsOneWidget);
      expect(
        find.textContaining('Save & connect · New connection ·'),
        findsOneWidget,
        reason: 'The original completion destination remains explicit',
      );
      final name = tester.widget<EditableText>(
        find.descendant(
          of: find.byKey(const ValueKey('connection-name')),
          matching: find.byType(EditableText),
        ),
      );
      expect(name.controller.text, 'New connection');
      expect(model.profiles, isEmpty);
      expect((model.backend as TestBackend).client.opened, isEmpty);
      expect((model.backend as TestBackend).client.executions, isEmpty);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      await opened;
    },
  );
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${ui.runtimeType} independent manager drafts Apply and Cancel preserve saved baselines and destination',
      (tester) async {
        final f = await FormRouteFixture.mount(
          tester,
          ui,
          ownerKind: 'offline',
        );
        final stored = {for (final p in f.model.profiles) p.id: p.deepCopy()};
        f.backend.client.profileAction = (request) async {
          if (request.action == ProfileAction.SAVE_PROFILE) {
            stored[request.profile.id] = request.profile.deepCopy();
          }
          return ProfileList(profiles: stored.values);
        };
        await f.open(tester, 'menu');
        await f.enter(tester, 'name', 'Draft B');
        await f.enter(tester, 'user', 'fixture');
        await f.enter(tester, 'port', '5555');
        await tester.ensureVisible(find.text('PostgreSQL'));
        expect(find.text('PostgreSQL').hitTestable(), findsOneWidget);
        f.nativeSelection = 'MySQL';
        await tester.tap(find.text('PostgreSQL'));
        await tester.pumpAndSettle();
        if (ui is WindowsControls) {
          await tester.tap(find.text('MySQL').last);
        }
        await tester.pumpAndSettle();
        EditableText input(String key) => tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(ValueKey('connection-$key')),
            matching: find.byType(EditableText),
          ),
        );
        expect(input('port').controller.text, '5555');
        expect(input('name').controller.text, 'Draft B');
        await tester.tap(find.byKey(const ValueKey('connection-add-source')));
        await tester.pumpAndSettle();
        await f.enter(tester, 'name', 'Draft C');
        await f.enter(tester, 'user', 'fixture');
        await tester.tap(find.text('Draft B *'));
        await tester.pumpAndSettle();
        expect(input('port').controller.text, '5555');
        expect(input('name').controller.text, 'Draft B');
        await tester.tap(find.text('Draft C *'));
        await tester.pumpAndSettle();
        expect(input('name').controller.text, 'Draft C');
        await tester.tap(find.text('Apply').last);
        await tester.pumpAndSettle();
        expect(
          stored.values.map((p) => p.name),
          containsAll(['Draft B', 'Draft C']),
        );
        expect(
          stored.values.where((p) => p.name == 'Draft B').single.tls.mode,
          TlsMode.DRIVER_DEFAULT,
        );
        expect(f.backend.client.opened, isEmpty);
        expect(f.backend.client.executions, isEmpty);
        await f.enter(tester, 'name', 'Discard this edit');
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        expect(
          stored.values.map((p) => p.name),
          isNot(contains('Discard this edit')),
        );
        expect(f.original.profileId, f.profile.id);
        expect(f.model.explorerSessions, isEmpty);
        expect(f.model.documents, hasLength(1));
      },
    );
    testWidgets(
      '${ui.runtimeType} partial OK saves identify the failed draft and retain acknowledged baselines without reconnecting',
      (tester) async {
        final f = await FormRouteFixture.mount(tester, ui);
        final old = f.model.sessions['old'];
        final stored = {f.profile.id: f.profile.deepCopy()};
        bool rejectSecond = true;
        f.backend.client.profileAction = (request) async {
          if (request.action == ProfileAction.SAVE_PROFILE) {
            if (request.profile.name == 'Draft C' && rejectSecond) {
              throw GrpcError.permissionDenied(
                'private persistence diagnostic',
              );
            }
            stored[request.profile.id] = request.profile.deepCopy();
          }
          return ProfileList(profiles: stored.values);
        };
        await f.open(tester, 'menu', edit: true);
        await f.enter(tester, 'name', 'Updated A');
        await tester.tap(find.byKey(const ValueKey('connection-add-source')));
        await tester.pumpAndSettle();
        await f.enter(tester, 'name', 'Draft C');
        await f.enter(tester, 'user', 'fixture');
        await tester.tap(find.text('Updated A *'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save & connect').last.hitTestable());
        await tester.pumpAndSettle();
        final name = find.descendant(
          of: find.byKey(const ValueKey('connection-name')),
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(name).controller.text, 'Draft C');
        expect(
          find.textContaining('Configuration applied: Updated A.'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Draft C: The server rejected access'),
          findsOneWidget,
        );
        expect(find.textContaining('Connection attempt failed'), findsNothing);
        expect(
          find.textContaining('private persistence diagnostic'),
          findsNothing,
        );
        expect(stored.values.map((p) => p.name), ['Updated A']);
        expect(f.model.sessions['old'], same(old));
        expect(f.original.sessionId, 'old');
        expect(f.backend.client.opened, isEmpty);
        expect(f.backend.client.executions, isEmpty);
        rejectSecond = false;
        await tester.tap(find.text('Apply').last.hitTestable());
        await tester.pumpAndSettle();
        expect(
          stored.values.map((p) => p.name),
          containsAll(['Updated A', 'Draft C']),
        );
        expect(stored, hasLength(2));
        expect(f.backend.client.opened, isEmpty);
        await tester.tap(find.text('Cancel').last.hitTestable());
        await tester.pumpAndSettle();
      },
    );
    for (final outcome in ['cancel-test', 'general-invalid']) {
      testWidgets(
        '${ui.runtimeType} nested SSH editor $outcome keeps live actions and scoped validation',
        (tester) async {
          final f = await FormRouteFixture.mount(
            tester,
            ui,
            ownerKind: 'offline',
          );
          f.profile.ssh = Ssh(
            enabled: true,
            host: 'jump.example',
            port: 22,
            user: 'fixture',
            knownHosts: '/reviewed/known_hosts',
          );
          final pending = Completer<SshTestReply>();
          f.backend.client.sshTest = (_) => pending.future;
          await f.open(tester, 'menu', edit: true);
          if (outcome == 'general-invalid') await f.enter(tester, 'user', '');
          await selectConnectionPage(tester, 'SSH/SSL');
          await tester.pumpAndSettle();
          await tester.tap(
            find
                .byWidgetPredicate(
                  (w) =>
                      w is Semantics &&
                      w.properties.label == 'SSH configuration',
                )
                .hitTestable(),
          );
          await tester.pumpAndSettle();
          await f.enter(tester, 'sshPassword', ' selected SSH secret ');
          await tester.tap(find.text('Test connection').last.hitTestable());
          await tester.pumpAndSettle();
          if (outcome == 'cancel-test') {
            expect(find.text('Cancel test').hitTestable(), findsOneWidget);
            expect(
              f.backend.client.sshTests.single.sshPassword,
              ' selected SSH secret ',
            );
            await tester.tap(find.text('Cancel test').hitTestable());
            await tester.pumpAndSettle();
            expect(f.backend.client.cancelledSshTests, 1);
            expect(
              find.text('Test connection').last.hitTestable(),
              findsOneWidget,
            );
            pending.complete(SshTestReply(host: 'Late reply must be fenced'));
            await tester.pumpAndSettle();
            expect(find.textContaining('Late reply'), findsNothing);
            await tester.tap(find.text('OK').last.hitTestable());
            await tester.pumpAndSettle();
          } else {
            pending.complete(
              SshTestReply(host: 'jump.example', port: 22, user: 'fixture'),
            );
            await tester.pumpAndSettle();
            expect(f.backend.client.sshTests, hasLength(1));
            expect(f.backend.client.connectionTests, isEmpty);
            expect(
              find.byKey(const ValueKey('connection-sshHost')).hitTestable(),
              findsOneWidget,
            );
            await tester.tap(find.text('OK').last.hitTestable());
            await tester.pumpAndSettle();
            // Only invoking the main database test validates General.
            await tester.tap(find.text('Test connection').last.hitTestable());
            await tester.pumpAndSettle();
            final input = find.descendant(
              of: find.byKey(const ValueKey('connection-user')),
              matching: find.byType(EditableText),
            );
            expect(
              tester.widget<EditableText>(input).focusNode.hasFocus,
              isTrue,
            );
            expect(input.hitTestable(), findsOneWidget);
          }
          expect(f.backend.client.opened, isEmpty);
          expect(f.backend.client.executions, isEmpty);
          await tester.tap(find.text('Cancel').last.hitTestable());
          await tester.pumpAndSettle();
        },
      );
    }
    for (final mode in [TlsMode.VERIFY_FULL, TlsMode.DISABLED]) {
      testWidgets(
        '${ui.runtimeType} unrelated Apply and duplication preserve saved $mode policy without copying consent',
        (tester) async {
          final f = await FormRouteFixture.mount(tester, ui);
          f.profile.tls = Tls(
            mode: mode,
            configuredMode: TlsMode.VERIFY_CA,
            caFile: '/dormant-or-selected/ca.pem',
            clientCert: '/dormant-or-selected/cert.pem',
            clientKey: '/dormant-or-selected/key.pem',
            keyCredentialRef: 'existing-tls-binding',
          );
          f.profile.options['tcpKeepAlive'] = 'false';
          await f.open(tester, 'menu', edit: true);
          await f.enter(tester, 'name', 'Renamed A');
          await tester.tap(find.text('Apply').last);
          await tester.pumpAndSettle();
          final saved = f.model.profiles.single;
          expect(saved.tls.mode, mode);
          expect(saved.tls.configuredMode, TlsMode.VERIFY_CA);
          expect(saved.tls.hasJavaTrust(), isFalse);
          expect(saved.tls.hasSystemTrust(), isFalse);
          expect(saved.tls.keyCredentialRef, 'existing-tls-binding');
          expect(saved.options['tcpKeepAlive'], 'false');
          await tester.tap(
            find.byKey(const ValueKey('connection-duplicate-source')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Apply').last);
          await tester.pumpAndSettle();
          final copy = f.model.profiles.firstWhere((p) => p.id != f.profile.id);
          expect(copy.tls.mode, mode);
          expect(copy.tls.configuredMode, TlsMode.VERIFY_CA);
          expect(copy.tls.keyCredentialRef, isEmpty);
          expect(copy.credentialRef, isEmpty);
          expect(copy.options, saved.options);
          expect(f.original.sessionId, 'old');
          expect(f.backend.client.opened, isEmpty);
          expect(f.backend.client.executions, isEmpty);
          await tester.tap(find.text('Cancel').last);
          await tester.pumpAndSettle();
        },
      );
    }
    globalCreationRoutes(ui);
    liveFormReconnectRoutes(ui);
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${ui.runtimeType} General failure/retry keeps reachable actions at $scale text scale',
        (tester) async {
          if (ui is LinuxControls) installNativeWindowFixture(tester);
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('connection-form-route-'),
          ))!;
          final backend = TestBackend();
          final model = WorkbenchModel(root)
            ..draftRecovery = false
            ..backend = backend
            ..newDocument();
          final intentional = model.document;
          await tester.binding.setSurfaceSize(const Size(1366, 768));
          addTearDown(() async {
            await tester.pumpWidget(const SizedBox.shrink());
            model.dispose();
            await tester.binding.setSurfaceSize(null);
            await tester.runAsync(() => root.delete(recursive: true));
          });
          final view = WorkbenchView(model: model, controls: ui);
          Widget scaled(BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: scale == 2 ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            ),
          );
          await tester.pumpWidget(
            ui is LinuxControls
                ? MaterialApp(builder: scaled, home: view)
                : fluent.FluentApp(builder: scaled, home: view),
          );
          final opened = model.commands!.invoke(
            'connection.new',
            const WorkbenchCommandContext(),
          );
          await tester.pumpAndSettle();
          Finder input(String key) => find.descendant(
            of: find.byKey(ValueKey('connection-$key')),
            matching: find.byType(EditableText),
          );
          Future<void> enter(String key, String value) async {
            await tester.ensureVisible(input(key));
            await enterDesktopText(tester, input(key), value);
          }

          void actionsReachable() {
            for (final label in [
              'Test connection',
              'Cancel',
              'Apply',
              'Save & connect',
            ]) {
              final action = find.text(label).last;
              expect(
                action.hitTestable(),
                findsOneWidget,
                reason: '$label must receive real pointer input',
              );
              final bounds = tester.getRect(action);
              expect(bounds.top, greaterThanOrEqualTo(0));
              expect(bounds.bottom, lessThanOrEqualTo(768));
              final viewports = find.ancestor(
                of: action,
                matching: find.byType(SingleChildScrollView),
              );
              for (final viewport in viewports.evaluate()) {
                expect(
                  viewport.widget.key,
                  const ValueKey('busydata-dialog-actions'),
                );
                final scrollable = find.descendant(
                  of: find.byWidget(viewport.widget),
                  matching: find.byType(Scrollable),
                );
                expect(
                  tester
                      .state<ScrollableState>(scrollable)
                      .position
                      .maxScrollExtent,
                  0,
                  reason:
                      'Fitting completion actions stay pinned while fields scroll',
                );
              }
            }
          }

          actionsReachable();
          await enter('name', 'Disposable fixture');
          await enter('user', 'postgres');
          await enter('password', 'wrong');
          backend.client.connectionTest = (_) async =>
              throw GrpcError.permissionDenied(
                'private server message ' * 1000,
              );
          await tester.tap(find.text('Test connection'));
          await tester.pumpAndSettle();
          expect(find.textContaining('server rejected access'), findsOneWidget);
          expect(find.textContaining('private server message'), findsNothing);
          expect(
            tester.widget<EditableText>(input('password')).controller.text,
            'wrong',
          );
          actionsReachable();
          await tester.tap(find.text('Details').last);
          await tester.pumpAndSettle();
          final diagnostic = find.text('RPC status: 7');
          expect(diagnostic.hitTestable(), findsOneWidget);
          final body = tester.getRect(
            find.byKey(const ValueKey('connection-settings-body')),
          );
          final diagnosticBounds = tester.getRect(diagnostic);
          expect(diagnosticBounds.top, greaterThanOrEqualTo(body.top));
          expect(diagnosticBounds.bottom, lessThanOrEqualTo(body.bottom));
          actionsReachable();
          await tester.tap(find.text('Details').last);
          await tester.pumpAndSettle();
          await enter('password', 'correct');
          backend.client.connectionTest = (_) async => ConnectionInfo(
            product: 'PostgreSQL',
            version: 'fixture',
            host: 'localhost',
            port: 5432,
            database: 'actual_database',
          );
          await tester.tap(find.text('Test connection'));
          await tester.pumpAndSettle();
          expect(find.textContaining('actual_database'), findsOneWidget);
          expect(model.profiles, isEmpty);
          expect(backend.client.opened, isEmpty);
          await enter('password', 'correct revision');
          await tester.pump();
          expect(find.textContaining('Settings changed'), findsOneWidget);
          backend.client.profileAction = (r) async =>
              ProfileList(profiles: [r.profile]);
          backend.client.opening = (_) async =>
              throw GrpcError.unavailable('private connection dump');
          await tester.tap(find.text('Save & connect'));
          await tester.pumpAndSettle();
          final savedId = model.profiles.single.id;
          expect(
            find.textContaining('Connection saved: Disposable fixture'),
            findsOneWidget,
          );
          expect(find.textContaining('private connection dump'), findsNothing);
          actionsReachable();
          backend.client.opening = (r) async => SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: 'explorer',
            profile: r.profile,
            transaction: TransactionState.IDLE,
          );
          backend.client.sessionCommand = (r) async => SessionInfo(
            metadataSourceIdentity: fixtureMetadataSourceIdentity,
            sessionId: r.sessionId,
            transaction: TransactionState.IDLE,
            profile: model.profiles.single,
          );
          await tester.tap(find.text('Save & connect'));
          await tester.pumpAndSettle();
          await opened;
          expect(model.profiles.single.id, savedId);
          expect(
            backend.client.profileRequests.map((r) => r.profile.id).toSet(),
            {savedId},
          );
          expect(model.explorerSessions[savedId], 'explorer');
          expect(model.documents, hasLength(2));
          expect(model.documents.first, same(intentional));
          expect(intentional.profileId, isNull);
          expect(model.document.profileId, savedId);
          expect(model.document.sessionId, isNull);
          expect(backend.client.executions, isEmpty);
        },
      );
    }
    testWidgets(
      '${ui.runtimeType} query-target creation retries its own saved binding and preserves the initiating SQL',
      (tester) async {
        if (ui is LinuxControls) installNativeWindowFixture(tester);
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('query-target-retry-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final original = model.activeOwner;
        original.sql!.editor.text = 'SELECT original_text;';
        await tester.binding.setSurfaceSize(const Size(1366, 768));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: ui);
        await tester.pumpWidget(
          ui is LinuxControls
              ? MaterialApp(home: view)
              : fluent.FluentApp(home: view),
        );
        final opened = model.commands!.invoke(
          'connection.new-query',
          WorkbenchCommandContext(owner: original),
        );
        await tester.pumpAndSettle();
        Finder input(String key) => find.descendant(
          of: find.byKey(ValueKey('connection-$key')),
          matching: find.byType(EditableText),
        );
        await enterDesktopText(tester, input('name'), 'Query fixture');
        await enterDesktopText(tester, input('user'), 'fixture');
        backend.client.profileAction = (r) async =>
            ProfileList(profiles: [r.profile]);
        backend.client.opening = (_) async =>
            throw GrpcError.unavailable('private failure');
        await tester.tap(find.text('Save & connect'));
        await tester.pumpAndSettle();
        final id = model.profiles.single.id;
        expect(original.profileId, id);
        expect(original.sessionId, isNull);
        expect(
          find.textContaining('Connection saved: Query fixture'),
          findsOneWidget,
        );
        model.newDocument();
        final unrelated = model.activeOwner;
        await enterDesktopText(tester, input('host'), 'corrected-host');
        backend.client.opening = (r) async => SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: 'query-owned',
          profile: r.profile,
          transaction: TransactionState.IDLE,
        );
        backend.client.sessionCommand = (r) async => SessionInfo(
          metadataSourceIdentity: fixtureMetadataSourceIdentity,
          sessionId: r.sessionId,
          profile: model.profiles.single,
          transaction: TransactionState.IDLE,
        );
        await tester.tap(find.text('Save & connect'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('connection-name')), findsNothing);
        await opened;
        expect(model.profiles.single.id, id);
        expect(original.sessionId, 'query-owned');
        expect(original.sql!.editor.text, 'SELECT original_text;');
        expect(unrelated.profileId, isNull);
        expect(model.documents, hasLength(2));
        expect(model.explorerSessions, isEmpty);
        expect(backend.client.executions, isEmpty);
        expect(backend.client.opened.map((r) => r.profile.id).toSet(), {id});
      },
    );
  }
}

class FormRouteFixture {
  FormRouteFixture(this.model, this.backend, this.original, this.profile);
  final WorkbenchModel model;
  final TestBackend backend;
  final WorkbenchDocument original;
  final Profile profile;
  String? nativeSelection;
  FocusNode? paletteOrigin;
  final paletteFocusTrace = <Map<String, Object?>>[];

  void capturePaletteFocus(WidgetTester tester, String phase) {
    final dynamic state = tester.state(find.byType(WorkbenchView));
    final primary = FocusManager.instance.primaryFocus;
    Map<String, Object?> node(FocusNode? value) => {
      'kind': value == null
          ? 'none'
          : value is FocusScopeNode
          ? 'scope'
          : 'leaf',
      'identity': value == null ? null : identityHashCode(value),
      'mounted': value?.context?.mounted,
      'requestable': value?.canRequestFocus,
      'hasFocus': value?.hasFocus,
      'primary': value?.hasPrimaryFocus,
    };
    if (paletteFocusTrace.length < 5) {
      paletteFocusTrace.add({
        'phase': phase,
        'origin': node(paletteOrigin),
        'current': node(primary),
        'primaryIsOriginDescendant':
            primary != null && primary.ancestors.contains(paletteOrigin),
        'searchClosed': state.sharedSearch.target == null,
        'originalOwnerActive': identical(model.activeOwner, original),
        'originalVersion': original.version,
        'backendUnchanged': identical(model.backend, backend),
      });
    }
  }

  static Future<FormRouteFixture> mount(
    WidgetTester tester,
    DesktopControls ui, {
    bool compact = false,
    String ownerKind = 'connected',
  }) async {
    late FormRouteFixture fixture;
    if (ui is LinuxControls) {
      installNativeWindowFixture(tester);
      const channel = MethodChannel('busydata/native_menus');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'show') return false;
        if (fixture.nativeSelection == null) throw MissingPluginException();
        final entries = flattenNativeMenu(
          (call.arguments as Map)['entries'] as List,
        );
        final index = entries.indexWhere(
          (e) => e['label'] == fixture.nativeSelection,
        );
        expect(
          index,
          greaterThanOrEqualTo(0),
          reason: 'Choose from the actual GTK menu entries',
        );
        expect(entries[index]['enabled'], isTrue);
        return index;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('connection-menu-intent-'),
    ))!;
    final backend = TestBackend();
    final profile = Profile(
      id: 'a',
      name: 'Connection A',
      host: 'localhost',
      port: 5432,
      user: 'fixture',
      database: 'a_db',
      engine: Engine.POSTGRESQL,
      tls: Tls(mode: TlsMode.VERIFY_FULL),
      connectTimeoutSeconds: 15,
    );
    final model = WorkbenchModel(root)
      ..draftRecovery = false
      ..backend = backend
      ..profiles.add(profile)
      ..newDocument(text: 'SELECT meaningful_offline_draft;');
    var original = model.activeOwner;
    original.profileId = ownerKind == 'unbound' ? null : 'a';
    if (ownerKind == 'table') {
      original = model.openTask(
        WorkbenchDocumentKind.table,
        'Exact table',
        object: const DatabaseObjectIdentity(
          profileId: 'a',
          catalog: 'a_db',
          schema: 'audit',
          name: 'same_name',
          kind: ObjectKind.TABLE,
        ),
      );
    }
    if (ownerKind == 'connected' || ownerKind == 'table') {
      original.sessionId = 'old';
      model.sessions['old'] = session('old', profile);
      model.track(
        JobInfo(
          jobId: 'prior',
          executionId: 'prior',
          sessionId: 'old',
          state: JobState.COMPLETED,
          messages: ['Prior acknowledged output'],
        ),
        documentId: original.id,
      );
    }
    backend.client.profileAction = (r) async => ProfileList(
      profiles: [
        for (final p in model.profiles)
          if (p.id != r.profile.id) p,
        r.profile,
      ],
    );
    backend.client.opening = (r) async => session('replacement', r.profile);
    backend.client.sessionCommand = (r) async => session(
      r.sessionId,
      r.sessionId == 'old' ? profile : model.profiles.last,
      state: r.action == SessionAction.DISCONNECT
          ? TransactionState.DISCONNECTED
          : TransactionState.IDLE,
    );
    await tester.binding.setSurfaceSize(Size(1366, compact ? 600 : 768));
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();
      await tester.binding.setSurfaceSize(null);
      await tester.runAsync(() => root.delete(recursive: true));
    });
    Widget scaled(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
      child: child!,
    );
    final view = WorkbenchView(model: model, controls: ui);
    await tester.pumpWidget(
      ui is LinuxControls
          ? MaterialApp(
              builder: scaled,
              home: Scaffold(body: view),
            )
          : fluent.FluentApp(builder: scaled, home: view),
    );
    await tester.pumpAndSettle();
    fixture = FormRouteFixture(model, backend, original, profile);
    return fixture;
  }

  static SessionInfo session(
    String id,
    Profile p, {
    TransactionState state = TransactionState.IDLE,
  }) => SessionInfo(
    metadataSourceIdentity: fixtureMetadataSourceIdentity,
    sessionId: id,
    profile: p,
    transaction: state,
    autoCommit: true,
    currentCatalog: p.database,
    currentSchema: 'public',
    contextRevision: Int64.ONE,
    sessionRevision: Int64(7),
  );

  Future<void> open(
    WidgetTester tester,
    String route, {
    bool edit = false,
    FocusScopeNode? expectedPaletteOrigin,
  }) async {
    await tester.pumpAndSettle();
    final linux =
        tester.widget<WorkbenchView>(find.byType(WorkbenchView)).controls
            is LinuxControls;
    if (route == 'palette') {
      paletteOrigin = null;
      paletteFocusTrace.clear();
      capturePaletteFocus(tester, 'before-open');
      nativeSelection = 'Commands';
      await tester.tap(
        linux
            ? find.byKey(const ValueKey('workbench-main-menu'))
            : find
                  .descendant(
                    of: find.byKey(const ValueKey('application-menu-bar')),
                    matching: find.text('View'),
                  )
                  .hitTestable(),
      );
      await tester.pumpAndSettle();
      if (nativeSelection != null &&
          find.byType(SearchResultList).evaluate().isEmpty) {
        final commands = find.text('Commands');
        await tester.ensureVisible(commands);
        expect(commands.hitTestable(), findsOneWidget);
        await tester.tap(commands);
        await tester.pumpAndSettle();
      }
      expect(find.byType(SearchResultList), findsOneWidget);
      final dynamic state = tester.state(find.byType(WorkbenchView));
      paletteOrigin = state.sharedSearch.returnFocus as FocusNode?;
      capturePaletteFocus(tester, 'palette-open');
      if (expectedPaletteOrigin != null) {
        expect(
          paletteOrigin,
          same(expectedPaletteOrigin),
          reason: '$paletteFocusTrace',
        );
        expect(paletteOrigin, isA<FocusScopeNode>());
      }
      await enterDesktopText(
        tester,
        find.descendant(
          of: find.byType(SearchHeaderField),
          matching: find.byType(EditableText),
        ),
        'New connection',
      );
      await tester.pumpAndSettle();
      capturePaletteFocus(tester, 'before-submit');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      capturePaletteFocus(tester, 'after-submit-before-pump');
    } else {
      nativeSelection = edit ? 'Edit connection' : 'New connection';
      final trigger = linux && route != 'query'
          ? find.byKey(const ValueKey('workbench-main-menu'))
          : route == 'query'
          ? find
                .text(
                  original.profileId == null ? 'No connection' : profile.name,
                )
                .hitTestable()
          : route == 'compact' && linux
          ? find
                .descendant(
                  of: find.byKey(const ValueKey('workbench-document-tabs')),
                  matching: find.text('More'),
                )
                .hitTestable()
          : find
                .descendant(
                  of: find.byKey(const ValueKey('application-menu-bar')),
                  matching: find.text('Connection'),
                )
                .hitTestable();
      expect(trigger, findsOneWidget);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      if (find.byKey(const ValueKey('connection-name')).evaluate().isEmpty) {
        final action = find.text(edit ? 'Edit connection' : 'New connection');
        await tester.ensureVisible(action);
        expect(action.hitTestable(), findsOneWidget);
        await tester.tap(action);
      }
    }
    await tester.pumpAndSettle();
    if (route == 'palette') capturePaletteFocus(tester, 'after-close');
    expect(
      find.byKey(const ValueKey('connection-name')),
      findsOneWidget,
      reason: route == 'palette' ? '$paletteFocusTrace' : null,
    );
    nativeSelection = null;
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final input = find.descendant(
      of: find.byKey(ValueKey('connection-$key')),
      matching: find.byType(EditableText),
    );
    await tester.ensureVisible(input);
    await enterDesktopText(tester, input, text);
    await tester.pump();
  }

  Future<void> complete(
    WidgetTester tester, {
    String action = 'Save & connect',
  }) async {
    await enter(tester, 'name', 'Connection B');
    await enter(tester, 'user', 'fixture');
    expect(find.text(action).hitTestable(), findsOneWidget);
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }
}

void globalCreationRoutes(DesktopControls ui) {
  testWidgets(
    '${ui.runtimeType} actual palette global creation restores exact scope origin',
    (tester) async {
      final f = await FormRouteFixture.mount(tester, ui, ownerKind: 'table');
      final owner = f.original;
      final oldSession = f.model.sessions['old'];
      final oldJob = f.model.jobForOwner(owner);
      final scope = FocusScope.of(tester.element(find.byType(WorkbenchView)));
      scope.requestScopeFocus();
      FocusManager.instance.applyFocusChangesIfNeeded();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(scope));
      await f.open(tester, 'palette', expectedPaletteOrigin: scope);
      expect(f.paletteOrigin, same(scope));
      expect(f.paletteFocusTrace, hasLength(5));
      expect(f.model.activeOwner, same(owner));
      await f.complete(tester);
      expect(f.model.activeOwner, isNot(same(owner)));
      expect(owner.profileId, 'a');
      expect(owner.sessionId, 'old');
      expect(f.model.sessions['old'], same(oldSession));
      expect(f.model.jobForOwner(owner), oldJob);
      expect(
        f.backend.client.sessionCommands.where((r) => r.sessionId == 'old'),
        isEmpty,
      );
      expect(f.backend.client.executions, isEmpty);
      expect(f.backend.client.reviews, isEmpty);
    },
  );
  for (final route in ['menu', 'compact', 'palette']) {
    for (final ownerKind in ['offline', 'connected', 'table']) {
      testWidgets(
        '${ui.runtimeType} actual $route global creation preserves $ownerKind owner',
        (tester) async {
          final f = await FormRouteFixture.mount(
            tester,
            ui,
            compact: route == 'compact',
            ownerKind: ownerKind,
          );
          final old = f.model.sessions['old'],
              prior = f.model.jobForOwner(f.original);
          final text = f.original.sql?.editor.text;
          await f.open(tester, route);
          // Unrelated background notifications must not alter cached menu intent.
          f.model.updateStatus('Unrelated background status');
          await f.complete(tester);
          final id = f.model.profiles.last.id;
          expect(f.model.explorerSessions[id], 'replacement');
          expect(f.model.documents, hasLength(2));
          expect(f.model.activeOwner, isNot(same(f.original)));
          expect(f.model.activeOwner.profileId, id);
          expect(f.model.activeOwner.sessionId, isNull);
          expect(f.original.profileId, 'a');
          expect(f.original.sessionId, ownerKind == 'offline' ? isNull : 'old');
          expect(f.original.sql?.editor.text, text);
          expect(f.model.sessions['old'], same(old));
          expect(f.model.jobForOwner(f.original), prior);
          expect(
            f.backend.client.sessionCommands.where((r) => r.sessionId == 'old'),
            isEmpty,
          );
          expect(f.backend.client.executions, isEmpty);
          expect(f.backend.client.reviews, isEmpty);
        },
      );
    }
  }
  for (final outcome in ['save', 'cancel', 'failure', 'owner-closed']) {
    testWidgets(
      '${ui.runtimeType} global menu $outcome never retargets the active query',
      (tester) async {
        final f = await FormRouteFixture.mount(tester, ui);
        await f.open(tester, 'menu');
        final old = f.model.sessions['old'];
        if (outcome == 'cancel') {
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        } else {
          if (outcome == 'failure') {
            f.backend.client.opening = (_) async =>
                throw GrpcError.unavailable('safe failure');
          }
          if (outcome == 'owner-closed') {
            f.model.newDocument();
            await f.model.closeDocument(
              f.original.sql!,
              reviewedRevision: f.original.version,
              discardText: true,
            );
          }
          await f.complete(
            tester,
            action: outcome == 'save' ? 'Apply' : 'Save & connect',
          );
        }
        if (outcome != 'owner-closed') {
          expect(f.original.profileId, 'a');
          expect(f.original.sessionId, 'old');
          expect(f.model.sessions['old'], same(old));
          expect(
            f.backend.client.sessionCommands.where((r) => r.sessionId == 'old'),
            isEmpty,
          );
        }
        expect(f.backend.client.executions, isEmpty);
        expect(f.model.documents.length, outcome == 'owner-closed' ? 2 : 1);
        expect(
          f.model.explorerSessions,
          outcome == 'owner-closed' ? isNotEmpty : isEmpty,
        );
        if (outcome == 'failure') {
          expect(
            find.textContaining('Connection saved: Connection B'),
            findsOneWidget,
          );
        }
      },
    );
  }
}

void liveFormReconnectRoutes(DesktopControls ui) {
  for (final scenario in [
    'success',
    'shared',
    'disconnect-failed',
    'cleanup-failed',
    'active',
    'failed',
    'unknown',
    'running',
    'staged',
    'opening-failed',
    'save-only',
    'cancel-after-retirement',
    'sql-after-retirement',
    'scope-after-retirement',
    'closed-after-retirement',
    'rebound-after-retirement',
    'backend-after-retirement',
    'superseded-after-retirement',
    'context-before-retirement',
  ]) {
    testWidgets(
      '${ui.runtimeType} actual Edit connection form reconnect $scenario with nonzero revisions',
      (tester) async {
        final f = await FormRouteFixture.mount(tester, ui);
        final text = f.original.sql!.editor.text,
            prior = f.model.jobForOwner(f.original);
        final target = f.model.captureTarget(owner: f.original);
        final retiring = Completer<SessionInfo>();
        final state = switch (scenario) {
          'active' => TransactionState.ACTIVE,
          'failed' => TransactionState.FAILED_TRANSACTION,
          'unknown' => TransactionState.UNKNOWN_TRANSACTION,
          _ => TransactionState.IDLE,
        };
        f.backend.client.sessionCommand = (r) async {
          if (scenario == 'cleanup-failed' &&
              r.action == SessionAction.DISCONNECT) {
            throw StateError(
              r.sessionId == 'old'
                  ? 'Primary disconnect failure'
                  : 'Cleanup not acknowledged',
            );
          }
          if (r.sessionId == 'old' && r.action == SessionAction.DISCONNECT) {
            if (scenario.endsWith('after-retirement')) return retiring.future;
            if (scenario == 'disconnect-failed') {
              throw StateError('Disconnect not acknowledged');
            }
          }
          final result = FormRouteFixture.session(
            r.sessionId,
            r.sessionId == 'old'
                ? f.profile
                : f.backend.client.opened.last.profile,
            state: r.action == SessionAction.DISCONNECT
                ? TransactionState.DISCONNECTED
                : state,
          );
          if (scenario == 'context-before-retirement' && r.sessionId == 'old') {
            result.contextRevision = Int64(2);
          }
          return result;
        };
        if (scenario == 'opening-failed') {
          f.backend.client.opening = (_) async =>
              throw GrpcError.unavailable('Unavailable endpoint');
        }
        if (scenario == 'shared') {
          f.model.newDocument(text: 'SELECT explicitly_shared;');
          f.model.activeOwner.profileId = 'a';
          f.model.activeOwner.sessionId = 'old';
          f.model.select(0);
        }
        if (scenario == 'running') {
          f.model.jobs['pending'] = JobInfo(
            jobId: 'pending',
            sessionId: 'old',
            state: JobState.EXECUTING,
          );
        }
        if (scenario == 'staged') {
          f.model.stagedSession = 'old';
          f.model.staged.add(StagedChange());
        }
        await f.open(tester, 'menu', edit: true);
        await f.enter(tester, 'password', ' supplied ');
        await tester.tap(
          find.text(scenario == 'save-only' ? 'Apply' : 'Save & connect'),
        );
        await tester.pumpAndSettle();
        if (scenario.endsWith('after-retirement')) {
          expect(
            f.backend.client.sessionCommands.where(
              (r) =>
                  r.sessionId == 'old' && r.action == SessionAction.DISCONNECT,
            ),
            hasLength(1),
          );
          switch (scenario) {
            case 'cancel-after-retirement':
              await tester.tap(find.text('Cancel'));
            case 'sql-after-retirement':
              f.original.sql!.editor.text = 'SELECT changed_while_retiring;';
            case 'scope-after-retirement':
              f.original.sql!.connectionSchema = 'different_scope';
            case 'closed-after-retirement':
              f.model.newDocument();
              unawaited(
                f.model.closeDocument(
                  f.original.sql!,
                  reviewedRevision: f.original.version,
                  discardText: true,
                ),
              );
            case 'rebound-after-retirement':
              f.original.sessionId = null;
              f.model.profiles.add(Profile(id: 'other'));
              f.model.bindUnconnectedProfile(f.original, 'other');
            case 'backend-after-retirement':
              f.model.backend = TestBackend(instanceId: 'replacement-backend');
            case 'superseded-after-retirement':
              unawaited(
                f.model.connect(
                  f.profile,
                  'superseding',
                  targetOwner: f.original,
                ),
              );
          }
          retiring.complete(
            FormRouteFixture.session(
              'old',
              f.profile,
              state: TransactionState.DISCONNECTED,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            f.original.sessionId,
            scenario == 'backend-after-retirement' ? 'old' : isNull,
          );
          expect(
            f.model.sessions,
            scenario == 'backend-after-retirement' ? contains('old') : isEmpty,
          );
          expect(
            f.backend.client.sessionCommands
                .where((r) => r.action == SessionAction.DISCONNECT)
                .map((r) => r.sessionId),
            ['old', 'replacement'],
          );
          if (scenario == 'rebound-after-retirement') {
            expect(f.original.profileId, 'other');
          }
        } else if (scenario == 'success' || scenario == 'shared') {
          expect(find.byKey(const ValueKey('connection-name')), findsNothing);
          expect(f.original.sessionId, 'replacement');
          expect(f.original.profileId, 'a');
          expect(f.original.sql!.editor.text, text);
          expect(f.model.jobForOwner(f.original), prior);
          expect(
            f.model.sessions.keys.toSet(),
            scenario == 'shared' ? {'old', 'replacement'} : {'replacement'},
          );
          expect(f.model.sessions['replacement']!.contextRevision, Int64.ONE);
          expect(f.model.sessions['replacement']!.sessionRevision, Int64(7));
          expect(f.backend.client.opened.single.password, ' supplied ');
          expect(
            f.backend.client.sessionCommands
                .where((r) => r.action == SessionAction.DISCONNECT)
                .map((r) => r.sessionId),
            scenario == 'shared' ? isEmpty : ['old'],
          );
          // Ordinary target validation still rejects the old physical capture.
          expect(() => f.model.requireTarget(target), throwsStateError);
          if (scenario == 'shared') {
            expect(f.model.documents.last.sessionId, 'old');
          }
        } else {
          expect(f.original.sessionId, 'old');
          expect(f.original.profileId, 'a');
          expect(
            f.model.sessions.keys.toSet(),
            scenario == 'cleanup-failed' ? {'old', 'replacement'} : {'old'},
          );
          if (scenario == 'cleanup-failed') {
            expect(
              f.model.sessions['replacement']!.transaction,
              TransactionState.UNKNOWN_TRANSACTION,
            );
          }
          expect(f.original.sql!.editor.text, text);
          expect(f.model.jobForOwner(f.original), prior);
          if (scenario == 'disconnect-failed' || scenario == 'cleanup-failed') {
            expect(
              f.backend.client.sessionCommands
                  .where((r) => r.action == SessionAction.DISCONNECT)
                  .map((r) => r.sessionId),
              ['old', 'replacement'],
            );
          } else if (scenario == 'context-before-retirement') {
            expect(
              f.backend.client.sessionCommands
                  .where((r) => r.action == SessionAction.DISCONNECT)
                  .map((r) => r.sessionId),
              ['replacement'],
            );
          } else {
            expect(
              f.backend.client.opened,
              scenario == 'opening-failed' ? hasLength(1) : isEmpty,
            );
            expect(
              f.backend.client.sessionCommands.where(
                (r) => r.action == SessionAction.DISCONNECT,
              ),
              isEmpty,
            );
          }
        }
        expect(f.model.explorerSessions, isEmpty);
        expect(f.backend.client.executions, isEmpty);
      },
    );
  }
  for (final outcome in ['success', 'closed', 'scope-changed']) {
    final closed = outcome == 'closed';
    testWidgets(
      '${ui.runtimeType} actual query-selector creation captures its offline owner, $outcome',
      (tester) async {
        final f = await FormRouteFixture.mount(
          tester,
          ui,
          ownerKind: 'unbound',
        );
        final text = f.original.sql!.editor.text;
        await f.open(tester, 'query');
        f.model.newDocument(text: 'SELECT unrelated;');
        final unrelated = f.model.activeOwner;
        if (closed) {
          await f.model.closeDocument(
            f.original.sql!,
            reviewedRevision: f.original.version,
            discardText: true,
          );
        }
        if (outcome == 'scope-changed') {
          f.original.sql!.connectionSchema = 'changed_scope';
        }
        await f.complete(tester);
        expect(unrelated.profileId, isNull);
        expect(unrelated.sessionId, isNull);
        expect(f.model.explorerSessions, isEmpty);
        expect(f.model.documents.length, closed ? 1 : 2);
        if (outcome != 'success') {
          expect(f.backend.client.opened, isEmpty);
          if (!closed) expect(f.original.profileId, isNull);
        } else {
          expect(f.original.profileId, f.model.profiles.last.id);
          expect(f.original.sessionId, 'replacement');
          expect(f.original.sql!.editor.text, text);
          expect(f.backend.client.opened, hasLength(1));
        }
        expect(f.backend.client.executions, isEmpty);
      },
    );
  }
  testWidgets(
    '${ui.runtimeType} query selector captures SQL typed after its first render',
    (tester) async {
      final f = await FormRouteFixture.mount(tester, ui, ownerKind: 'unbound');
      final originalRevision = f.original.version;
      const text =
          '-- meaningful offline connection target\nSELECT current_database();';
      f.original.sql!.editor.text = text;
      await tester.pumpAndSettle();
      expect(f.original.version, greaterThan(originalRevision));
      await f.open(tester, 'query');
      await f.complete(tester);
      expect(find.text('Run').hitTestable(), findsOneWidget);
      expect(f.original.profileId, f.model.profiles.last.id);
      expect(f.original.sessionId, 'replacement');
      expect(f.original.sql!.editor.text, text);
      expect(f.model.explorerSessions, isEmpty);
      expect(f.model.documents, hasLength(1));
      expect(f.backend.client.executions, isEmpty);
    },
  );
}
