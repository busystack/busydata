import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/authentication_form.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} native account form verifies credentials and clears its typed request',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        rpc.AuthenticationRequest? retained, received;
        final form = SizedBox(
          width: 650,
          height: 650,
          child: AuthenticationForm(
            controls: controls,
            engine: rpc.Engine.MYSQL,
            submit: (request) async {
              retained = request;
              received = request.deepCopy();
              return false;
            },
          ),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: fluent.ScaffoldPage(content: form))
              : MaterialApp(home: Scaffold(body: form)),
        );
        await tester.tap(find.text('Review account operation'));
        await tester.pump();
        expect(
          find.text('Enter the same nonempty password twice'),
          findsOneWidget,
        );
        expect(received, isNull);
        final fields = find.byWidgetPredicate(
          (w) => w is EditableText && !w.readOnly,
        );
        expect(fields, findsNWidgets(4));
        await tester.enterText(fields.at(0), 'Exact 漢 account');
        await tester.enterText(fields.at(1), 'localhost');
        await tester.enterText(fields.at(2), 'secret \\ quoted');
        await tester.enterText(fields.at(3), 'secret \\ quoted');
        expect(tester.widget<EditableText>(fields.at(2)).obscureText, isTrue);
        await tester.tap(find.text('Review account operation'));
        await tester.pumpAndSettle();
        expect(received!.principal.name, 'Exact 漢 account');
        expect(received!.principal.host, 'localhost');
        expect(received!.password, 'secret \\ quoted');
        expect(
          retained!.password,
          isEmpty,
          reason:
              'A completed/cancelled review must not retain the password in its command',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
