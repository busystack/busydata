import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/privileges_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeMenu = MethodChannel('busydata/native_menus');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          nativeMenu,
          (_) async => throw MissingPluginException(),
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeMenu, null);
  });
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '${controls.runtimeType} privilege review remains reachable and safe at $scale text scale',
        (tester) async {
          tester.view.physicalSize = const Size(1366, 768);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final requests = <rpc.PrivilegeRequest>[];
          var accounts = 0;
          final form = PrivilegesForm(
            controls: controls,
            engine: rpc.Engine.POSTGRESQL,
            initial: rpc.PrivilegeReply(
              principals: [rpc.Principal(name: 'reader', kind: 'role')],
            ),
            request: (request) async {
              requests.add(request);
              return rpc.PrivilegeReply();
            },
            openSql: (_) => fail('Uninspected privileges must not become SQL'),
            account: (_) async => accounts++,
          );
          Widget scaled(BuildContext context, Widget? child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
          await tester.pumpWidget(
            controls is WindowsControls
                ? fluent.FluentApp(builder: scaled, home: form)
                : MaterialApp(
                    builder: scaled,
                    home: Scaffold(body: form),
                  ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final review = find.text('Open privilege SQL for review');
          expect(
            review,
            findsOneWidget,
            reason: 'Review stays visible while form fields scroll',
          );
          final bounds = tester.getRect(review);
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(768));
          expect(bounds.width, lessThanOrEqualTo(controls.formContentWidth));
          await tester.tap(review);
          await tester.pumpAndSettle();
          expect(requests, isEmpty);
          expect(accounts, 0);
          expect(
            find.textContaining('Inspect the selected principal'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets(
      '${controls.runtimeType} inspects before drafting native privilege SQL',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final principal = rpc.Principal(
          name: 'reader',
          host: '%',
          kind: 'account',
        );
        final initial = rpc.PrivilegeReply(principals: [principal]);
        final requests = <rpc.PrivilegeRequest>[];
        rpc.PrivilegeReply? draft;
        final form = SizedBox(
          width: 700,
          height: 1200,
          child: PrivilegesForm(
            controls: controls,
            engine: rpc.Engine.MYSQL,
            schema: 'business',
            table: 'orders',
            initial: initial,
            request: (request) async {
              requests.add(request.deepCopy());
              return request.action == rpc.PrivilegeAction.INSPECT_PRIVILEGES
                  ? (initial.deepCopy()
                      ..definition = 'Direct table privileges: SELECT')
                  : rpc.PrivilegeReply(
                      sql: [
                        'REVOKE SELECT ON `business`.`orders` FROM `reader`@`%`;',
                      ],
                    );
            },
            openSql: (reply) => draft = reply,
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: form))
              : MaterialApp(home: Scaffold(body: form)),
        );
        await tester.tap(find.text('Open privilege SQL for review'));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Inspect the selected principal'),
          findsOneWidget,
        );
        expect(requests, isEmpty);

        await tester.tap(find.text('Choose a principal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('reader@% · account').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inspect selected grants'));
        await tester.pumpAndSettle();
        expect(find.text('Direct table privileges: SELECT'), findsOneWidget);
        expect(requests.single.grantee, principal);
        expect(requests.single.action, rpc.PrivilegeAction.INSPECT_PRIVILEGES);

        await tester.tap(find.text('Grant access'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Revoke access').last);
        await tester.pumpAndSettle();
        expect(find.text('Allow recipient to grant to others'), findsNothing);
        await tester.tap(find.text('Open privilege SQL for review'));
        await tester.pumpAndSettle();
        expect(requests.last.action, rpc.PrivilegeAction.DESIGN_PRIVILEGE);
        expect(requests.last.revoke, isTrue);
        expect(requests.last.delegation, isFalse);
        expect(requests.last.schema, 'business');
        expect(requests.last.table, 'orders');
        expect(requests.last.privileges, ['SELECT']);
        expect(draft!.sql.single, startsWith('REVOKE SELECT'));
        expect(
          initial.definition,
          isEmpty,
          reason: 'The form does not mutate its caller\'s inspection data',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
