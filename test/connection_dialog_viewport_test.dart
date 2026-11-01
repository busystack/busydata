import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:busydata/src/app/busydata_yaru_theme.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/workbench_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/native_window.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    testWidgets(
      '${controls.runtimeType} connection keyboard focus reveals the protected field at DPR 2',
      (tester) async {
        if (controls is LinuxControls) installNativeWindowFixture(tester);
        final semantics = tester.ensureSemantics();
        var semanticsDisposed = false;
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-profile-viewport-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = TestBackend()
          ..newDocument();
        tester.view.devicePixelRatio = 2;
        await tester.binding.setSurfaceSize(const Size(640, 400));
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          model.dispose();
          if (!semanticsDisposed) semantics.dispose();
          tester.view.resetDevicePixelRatio();
          await tester.binding.setSurfaceSize(null);
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = WorkbenchView(model: model, controls: controls);
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(
                  theme: BusyDataYaruTheme.build(
                    brightness: Brightness.light,
                    accentColor: Colors.orange,
                  ),
                  home: Scaffold(body: view),
                ),
        );
        final opened = model.commands!.invoke(
          'connection.new',
          model.commandContext,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final nameField = find.descendant(
          of: find.byKey(const ValueKey('connection-name')),
          matching: find.byType(
            controls is LinuxControls ? TextField : fluent.TextBox,
          ),
        );
        // A settled native form must paint at its layout size: shrinking the
        // dialog also shrinks text and misaligns native accessibility bounds.
        expect(tester.getRect(nameField).size, tester.getSize(nameField));
        final fields = tester
            .widgetList<EditableText>(find.byType(EditableText))
            .toList();
        expect(fields, hasLength(7));
        final host = find.descendant(
          of: find.byKey(const ValueKey('connection-host')),
          matching: find.byType(EditableText),
        );
        final hostState = tester.state<EditableTextState>(host);
        final hostEditor = tester.widget<EditableText>(host);
        hostEditor.focusNode.requestFocus();
        final hostEditing = hostEditor.controller.value.copyWith(
          selection: const TextSelection(baseOffset: 1, extentOffset: 4),
          composing: const TextRange(start: 1, end: 4),
        );
        hostEditor.controller.value = hostEditing;
        await tester.pumpAndSettle();
        for (final size in [const Size(1366, 768), const Size(640, 400)]) {
          await tester.binding.setSurfaceSize(size);
          await tester.pumpAndSettle();
          expect(tester.state<EditableTextState>(host), same(hostState));
          expect(hostEditor.focusNode.hasFocus, isTrue);
          expect(hostEditor.controller.value, hostEditing);
        }
        final user = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('connection-user')),
            matching: find.byType(EditableText),
          ),
        );
        user.focusNode.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EditableText>(
                find.descendant(
                  of: find.byKey(const ValueKey('connection-password')),
                  matching: find.byType(EditableText),
                ),
              )
              .focusNode
              .hasFocus,
          isTrue,
          reason: FocusManager.instance.primaryFocus?.debugLabel,
        );
        final password = find.descendant(
          of: find.byKey(const ValueKey('connection-password')),
          matching: find.byType(EditableText),
        );
        expect(password, findsOneWidget);
        final data = tester.getSemantics(password).getSemanticsData();
        expect(data.label, 'Password');
        expect(data.flagsCollection.isObscured, isTrue);
        expect(data.flagsCollection.isFocused, Tristate.isTrue);
        final bounds = tester.getRect(
          controls is LinuxControls
              ? find.descendant(
                  of: find.byKey(const ValueKey('connection-password')),
                  matching: find.byType(TextField),
                )
              : find.descendant(
                  of: find.byKey(const ValueKey('connection-password')),
                  matching: find.byType(fluent.TextBox),
                ),
        );
        final viewports = find.ancestor(
          of: password,
          matching: find.byType(SingleChildScrollView),
        );
        expect(viewports, findsWidgets);
        for (final viewport in viewports.evaluate()) {
          final clip = tester.getRect(find.byWidget(viewport.widget));
          expect(bounds.top, greaterThanOrEqualTo(clip.top));
          expect(bounds.bottom, lessThanOrEqualTo(clip.bottom));
          expect(bounds.left, greaterThanOrEqualTo(clip.left));
          expect(bounds.right, lessThanOrEqualTo(clip.right));
        }
        expect(bounds.top, greaterThanOrEqualTo(0));
        expect(bounds.bottom, lessThanOrEqualTo(400));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel').last);
        await tester.pumpAndSettle();
        await opened;
        semantics.dispose();
        semanticsDisposed = true;
      },
    );
  }
}
