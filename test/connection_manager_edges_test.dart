import 'support/windows_secret_input.dart';
import 'package:busydata/src/backend/generated/busydata.pb.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'dart:async';
import 'connection_form_workflow_test.dart' show FormRouteFixture;
import 'support/connection_widgets.dart';

Finder removeSource() => find
    .byWidgetPredicate(
      (widget) =>
          widget is Semantics && widget.properties.label == 'Delete connection',
    )
    .hitTestable();

void main() {
  setUpWindowsSecretInputFixture();
  for (final ui in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets('${ui.runtimeType} host review needs only the SSH endpoint', (
      tester,
    ) async {
      final f = await FormRouteFixture.mount(tester, ui, ownerKind: 'offline');
      f.profile.ssh = Ssh(enabled: true, host: 'jump.example', port: 22);
      await f.open(tester, 'menu', edit: true);
      await f.enter(tester, 'user', '');
      await f.enter(tester, 'host', 'invalid database host');
      await f.enter(tester, 'port', 'malformed');
      await selectConnectionPage(tester, 'SSH/SSL');
      await tester.pumpAndSettle();
      await tester.tap(
        find
            .byWidgetPredicate(
              (w) =>
                  w is Semantics && w.properties.label == 'SSH configuration',
            )
            .hitTestable(),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review SSH host key').last.hitTestable());
      await tester.pumpAndSettle();
      final reviewed = f.backend.client.sshReviews.single.profile;
      expect(reviewed.id, 'a');
      expect(reviewed.ssh.host, 'jump.example');
      expect(reviewed.host, isEmpty);
      expect(reviewed.user, isEmpty);
      expect(reviewed.hasTls(), isFalse);
      expect(f.backend.client.connectionTests, isEmpty);
      await tester.tap(find.text('Cancel').last.hitTestable());
      await tester.pumpAndSettle();
      expect(f.backend.client.sshAccepts, isEmpty);
      expect(
        find.byKey(const ValueKey('connection-sshHost')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel').last.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last.hitTestable());
      await tester.pumpAndSettle();
    });

    for (final generalValid in [false, true]) {
      testWidgets(
        '${ui.runtimeType} SSH editor tests SSH independently of ${generalValid ? 'an unavailable database' : 'an empty database User'}',
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
            user: 'ssh-user',
            knownHosts: '/reviewed/known_hosts',
          );
          f.backend.client.connectionTest = (_) async =>
              throw GrpcError.unavailable('Database is unavailable');
          await f.open(tester, 'menu', edit: true);
          if (!generalValid) await f.enter(tester, 'user', '');
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
          expect(
            f.backend.client.connectionTests,
            isEmpty,
            reason: 'The nested editor must not test a database.',
          );
          expect(f.backend.client.sshTests.single.profileId, 'a');
          expect(
            f.backend.client.sshTests.single.sshPassword,
            ' selected SSH secret ',
          );
          expect(f.backend.client.sshTests.single.keyPassphrase, isEmpty);
          expect(
            find.text('Connected · SSH · ssh-user@jump.example:22'),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('connection-sshHost')).hitTestable(),
            findsOneWidget,
            reason: 'SSH testing must leave this editor open.',
          );
          expect(f.backend.client.opened, isEmpty);
          expect(f.backend.client.executions, isEmpty);
          await tester.tap(find.text('Cancel').last.hitTestable());
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cancel').last.hitTestable());
          await tester.pumpAndSettle();
        },
      );
    }

    testWidgets(
      '${ui.runtimeType} removing the sole saved source applies deletion without a replacement',
      (tester) async {
        final f = await FormRouteFixture.mount(tester, ui);
        final old = f.model.sessions['old'];
        f.backend.client.profileAction = (request) async => ProfileList(
          profiles: [
            for (final p in f.model.profiles)
              if (p.id != request.profile.id) p,
          ],
        );
        await f.open(tester, 'menu', edit: true);
        await tester.tap(removeSource());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply').last.hitTestable());
        await tester.pumpAndSettle();
        expect(f.backend.client.profileRequests.map((r) => r.action), [
          ProfileAction.DELETE_PROFILE,
        ]);
        expect(f.model.profiles, isEmpty);
        expect(f.model.sessions['old'], same(old));
        expect(f.original.sessionId, 'old');
        expect(f.original.sql!.editor.text, 'SELECT meaningful_offline_draft;');
        expect(f.backend.client.opened, isEmpty);
        expect(f.backend.client.executions, isEmpty);
        expect(find.text('New connection *'), findsNothing);
        expect(
          find.byKey(const ValueKey('connection-add-source')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.text('Cancel').last.hitTestable());
        await tester.pumpAndSettle();
        expect(
          f.model.profiles,
          isEmpty,
          reason: 'Cancel cannot reverse Apply.',
        );
      },
    );

    for (final outcome in ['cancel', 'retry', 'cancel-after-request']) {
      testWidgets(
        '${ui.runtimeType} empty-manager deletion $outcome preserves acknowledgements and ownership',
        (tester) async {
          final f = await FormRouteFixture.mount(tester, ui);
          final old = f.model.sessions['old'];
          final pending = Completer<ProfileList>();
          var reject = true;
          f.backend.client.profileAction = (r) async {
            if (outcome == 'cancel-after-request') return pending.future;
            if (outcome == 'retry' && reject) {
              throw GrpcError.unavailable('private deletion diagnostic');
            }
            return ProfileList();
          };
          await f.open(tester, 'menu', edit: true);
          await tester.tap(removeSource());
          await tester.pumpAndSettle();
          if (outcome != 'cancel') {
            await tester.tap(find.text('Apply').last.hitTestable());
            await tester.pumpAndSettle();
          }
          if (outcome == 'retry') {
            expect(f.model.profiles.single.id, 'a');
            expect(find.textContaining('private deletion'), findsNothing);
            expect(find.textContaining('Connection A:'), findsOneWidget);
            reject = false;
            await tester.tap(find.text('Apply').last.hitTestable());
            await tester.pumpAndSettle();
            expect(f.model.profiles, isEmpty);
            expect(f.backend.client.profileRequests.map((r) => r.profile.id), [
              'a',
              'a',
            ]);
          }
          await tester.tap(find.text('Cancel').last.hitTestable());
          await tester.pumpAndSettle();
          if (outcome == 'cancel-after-request') {
            pending.complete(ProfileList());
            await tester.pumpAndSettle();
            expect(f.model.profiles, isEmpty);
          } else if (outcome == 'cancel') {
            expect(f.model.profiles.single.id, 'a');
            expect(f.backend.client.profileRequests, isEmpty);
          }
          expect(f.model.sessions['old'], same(old));
          expect(f.original.sessionId, 'old');
          expect(f.backend.client.opened, isEmpty);
          expect(f.backend.client.executions, isEmpty);
        },
      );
    }

    testWidgets(
      '${ui.runtimeType} removing the sole unsaved source leaves an empty manager',
      (tester) async {
        final f = await FormRouteFixture.mount(
          tester,
          ui,
          ownerKind: 'unbound',
        );
        f.model.profiles.clear();
        await f.open(tester, 'query');
        await tester.tap(removeSource());
        await tester.pumpAndSettle();
        expect(find.text('New connection *'), findsNothing);
        await tester.tap(find.text('Apply').last.hitTestable());
        await tester.pumpAndSettle();
        expect(f.backend.client.profileRequests, isEmpty);
        final name = find.descendant(
          of: find.byKey(const ValueKey('connection-name')),
          matching: find.byType(EditableText),
        );
        expect(tester.widget<EditableText>(name).readOnly, isTrue);
        await tester.tap(find.byKey(const ValueKey('connection-add-source')));
        await tester.pumpAndSettle();
        await f.enter(tester, 'name', 'Configuration only');
        await f.enter(tester, 'user', 'fixture');
        f.backend.client.profileAction = (r) async =>
            ProfileList(profiles: [r.profile]);
        await tester.tap(find.text('Save & connect').last.hitTestable());
        await tester.pumpAndSettle();
        expect(f.model.profiles.single.name, 'Configuration only');
        expect(
          f.original.profileId,
          isNull,
          reason: 'Removing the captured destination cancels that binding.',
        );
        expect(f.model.documents, hasLength(1));
        expect(f.model.explorerSessions, isEmpty);
        expect(f.backend.client.opened, isEmpty);
        expect(f.backend.client.executions, isEmpty);
      },
    );
  }
}
