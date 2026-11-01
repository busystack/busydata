import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/features/workspace/documents.dart';
import 'package:busydata/src/platform/common/output_commit.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/schema_tools_view.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const window = MethodChannel('yaru_window');
  const events = EventChannel('yaru_window/events');
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          window,
          (call) async => call.method == 'state' ? <String, Object?>{} : null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          events,
          MockStreamHandler.inline(onListen: (_, _) {}),
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(window, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(events, null);
  });
  for (final native in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final changed in [false, true]) {
      testWidgets(
        '${native.runtimeType} output review ${changed ? 'cannot authorize changed destination' : 'cancel preserves file'}',
        (tester) async {
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('busydata-output-review-'),
          ))!;
          final target = File('${root.path}/diagram 漢.svg');
          await tester.runAsync(() => target.writeAsString('original'));
          addTearDown(
            () => tester.runAsync(() => root.delete(recursive: true)),
          );
          final ui = (await tester.runAsync(
            () async => ObservedControls(native),
          ))!;
          late BuildContext context;
          final body = Builder(
            builder: (value) {
              context = value;
              return const Text('Diagram');
            },
          );
          await tester.pumpWidget(
            native is WindowsControls
                ? fluent.FluentApp(home: fluent.ScaffoldPage(content: body))
                : MaterialApp(home: Scaffold(body: body)),
          );
          late Future<OutputDestination?> review;
          await tester.runAsync(() async {
            review = reviewOutputDestination(context, ui, target.path);
            await ui.entered.future;
          });
          await tester.pumpAndSettle();
          expect(find.text('Replace'), findsNWidgets(2));
          if (changed) {
            await tester.runAsync(
              () => target.writeAsString('external change'),
            );
          }
          await tester.tap(find.text(changed ? 'Replace' : 'Cancel').last);
          await tester.pumpAndSettle();
          final destination = await tester.runAsync(() => review);
          if (changed) {
            expect(destination, isNotNull);
            await tester.runAsync(
              () => expectLater(
                atomicWrite(
                  target,
                  utf8.encode('new diagram'),
                  destination: destination,
                ),
                throwsA(isA<OutputCommitFailure>()),
              ),
            );
          } else {
            expect(destination, isNull);
          }
          expect(
            await tester.runAsync(() => target.readAsString()),
            changed ? 'external change' : 'original',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class ObservedControls extends DesktopControls {
  @override
  DesktopAppearance appearance(BuildContext context) =>
      native.appearance(context);
  @override
  Widget inlineField(
    TextEditingController controller,
    String label, {
    required FocusNode focusNode,
  }) => native.inlineField(controller, label, focusNode: focusNode);

  @override
  Future<T?> formDialog<T>(BuildContext context, WidgetBuilder builder) =>
      native.formDialog<T>(context, builder);
  @override
  Widget formShell(
    String title,
    Widget body,
    List<Widget> actions, {
    bool scrollBody = true,
    double maxWidth = 760,
  }) => native.formShell(
    title,
    body,
    actions,
    scrollBody: scrollBody,
    maxWidth: maxWidth,
  );
  @override
  Widget tooltip(String message, Widget child) =>
      native.tooltip(message, child);
  @override
  Widget contextMenu(Widget child, List<DesktopMenuAction> actions) =>
      native.contextMenu(child, actions);
  @override
  Widget menu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  }) => native.menu(label, actions, compact: compact);

  @override
  Widget splitButton(
    String label,
    VoidCallback? action,
    String optionsLabel,
    List<DesktopMenuAction> options,
  ) => native.splitButton(label, action, optionsLabel, options);
  @override
  Widget menuBar(List<DesktopMenu> menus) => native.menuBar(menus);
  @override
  Widget icon(DesktopIcon icon, {double size = 16}) =>
      native.icon(icon, size: size);
  @override
  Widget iconButton(
    DesktopIcon icon,
    String label,
    VoidCallback? action, {
    bool compact = false,
  }) => native.iconButton(icon, label, action, compact: compact);
  @override
  Widget textButton(
    String label,
    VoidCallback? action, {
    bool compact = false,
  }) => native.textButton(label, action, compact: compact);
  @override
  Widget filterField(
    TextEditingController controller,
    String label, {
    FocusNode? focusNode,
    bool autofocus = false,
    bool clearOnEscape = true,
    ValueChanged<String>? onChanged,
  }) => native.filterField(
    controller,
    label,
    focusNode: focusNode,
    autofocus: autofocus,
    clearOnEscape: clearOnEscape,
    onChanged: onChanged,
  );
  @override
  Widget iconMenu(
    String label,
    List<DesktopMenuAction> actions, {
    bool compact = false,
  }) => native.iconMenu(label, actions, compact: compact);
  ObservedControls(this.native);
  final DesktopControls native;
  final entered = Completer<void>();
  @override
  Future<T?> dialog<T>(
    BuildContext context,
    String title,
    Widget body,
    List<Widget> actions, {
    bool bodyScrolls = false,
  }) {
    entered.complete();
    return native.dialog(
      context,
      title,
      body,
      actions,
      bodyScrolls: bodyScrolls,
    );
  }

  @override
  Widget button(
    String label,
    VoidCallback? action, {
    bool primary = false,
    bool destructive = false,
    FocusNode? focusNode,
  }) =>
      native.button(label, action, primary: primary, destructive: destructive);
  @override
  Widget field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    bool enabled = true,
    FocusNode? focusNode,
    bool showLabel = true,
    bool readOnly = false,
    bool technical = false,
    Widget? trailing,
    String? errorText,
  }) => native.field(
    controller,
    label,
    secret: secret,
    enabled: enabled,
    focusNode: focusNode,
    showLabel: showLabel,
    readOnly: readOnly,
    technical: technical,
    trailing: trailing,
  );
  @override
  Widget choice<T>(
    T value,
    Map<T, String> choices,
    ValueChanged<T> changed, {
    String? label,
    bool enabled = true,
  }) => native.choice(value, choices, changed, label: label, enabled: enabled);
  @override
  double choiceWidth(BuildContext context, String label) =>
      native.choiceWidth(context, label);
  @override
  Widget checkbox(String label, bool value, ValueChanged<bool>? changed) =>
      native.checkbox(label, value, changed);
  @override
  Widget surface(Widget child) => native.surface(child);
  @override
  Color background(BuildContext context) => native.background(context);
  @override
  Color foreground(BuildContext context) => native.foreground(context);
  @override
  Color accent(BuildContext context) => native.accent(context);
  @override
  TextStyle textStyle(BuildContext context) => native.textStyle(context);
}
