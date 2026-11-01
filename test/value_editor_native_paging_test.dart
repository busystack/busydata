import 'dart:convert';

import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/paged_selectable_text.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'value_editor_test_actions.dart';

Widget host(
  DesktopControls controls,
  Widget child,
  TextDirection direction,
  double scale,
) {
  Widget builder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(scale),
      highContrast: true,
      disableAnimations: true,
    ),
    child: Directionality(textDirection: direction, child: child!),
  );
  return controls is WindowsControls
      ? fluent.FluentApp(builder: builder, home: child)
      : MaterialApp(
          builder: builder,
          home: Scaffold(body: child),
        );
}

Finder input() => find.byWidgetPredicate(
  (widget) => widget is EditableText && !widget.readOnly,
);

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} complete text pages preserve exact failed '
          'draft and staging ${direction.name} $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            try {
              final complete = '漢' * 30000, bytes = utf8.encode(complete);
              final value = rpc.Value(
                text: '漢' * 16384,
                valueId: 'owned',
                truncated: true,
                originalBytes: Int64(bytes.length),
              );
              final original = value.writeToBuffer(), offsets = <int>[];
              String? draft;
              rpc.Value? staged;
              var attempts = 0;
              final body = Builder(
                builder: (context) => controls.button('Open editor', () {
                  controls.dialog<void>(
                    context,
                    'body · text',
                    ResultValueEditor(
                      controls: controls,
                      value: value,
                      column: rpc.Column(name: 'body', typeName: 'text'),
                      readChunk: (offset) async {
                        offsets.add(offset);
                        final end = (offset + 65536).clamp(0, bytes.length);
                        return rpc.ValueChunk(
                          data: bytes.sublist(offset, end),
                          totalBytes: Int64(bytes.length),
                          complete: end == bytes.length,
                        );
                      },
                      cancelRead: () {},
                      retainDraft: (text, _) => draft = text,
                      stage: (value) async {
                        expect(value.text.length, 30000);
                        if (attempts++ == 0) throw StateError('validation');
                        staged = value;
                      },
                    ),
                    [
                      controls.button(
                        'Close',
                        () => Navigator.of(context).pop(),
                      ),
                    ],
                    bodyScrolls: true,
                  );
                }),
              );
              await tester.pumpWidget(host(controls, body, direction, scale));
              await tester.tap(find.text('Open editor'));
              await tester.pumpAndSettle();
              await valueEditorAction(tester, controls, 'Edit complete value');
              await tester.pumpAndSettle();
              expect(offsets, [0, 65536]);
              expect(find.text('Text page 1 of 2'), findsOneWidget);
              expect(input().hitTestable(), findsOneWidget);
              await tester.tap(input());
              expect(
                tester.widget<EditableText>(input()).controller.text,
                '漢' * 16384,
              );
              final first = 'A${'漢' * 16383}';
              await tester.enterText(input(), first);
              await tester.enterText(input(), 'x' * 16385);
              await tester.pumpAndSettle();
              expect(
                tester.widget<EditableText>(input()).controller.text,
                first,
              );
              expect(
                find.textContaining('invalid or too large'),
                findsOneWidget,
              );
              await tester.tap(find.text('Next text page'));
              await tester.pumpAndSettle();
              expect(find.text('Text page 2 of 2'), findsOneWidget);
              expect(input().hitTestable(), findsOneWidget);
              await tester.tap(input());
              expect(
                tester.widget<EditableText>(input()).controller.text,
                '漢' * 13616,
              );
              await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
              await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
              await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
              await tester.pumpAndSettle();
              expect(
                tester.widget<EditableText>(input()).controller.text,
                '漢' * 13616,
                reason: 'Page navigation must not enter another page in undo',
              );
              final second = '${'漢' * 13615}B';
              await tester.enterText(input(), second);
              final expected = '$first$second';
              expect(draft, expected);
              await tester.tap(find.text('Edit cell'));
              await tester.pumpAndSettle();
              final actions = await valueEditorAction(tester, controls, null);
              if (controls is LinuxControls) {
                expect(actions, isNot(contains('Edit complete value')));
              } else {
                expect(find.text('Edit complete value'), findsNothing);
                await tester.sendKeyEvent(LogicalKeyboardKey.escape);
                await tester.pumpAndSettle();
              }
              await tester.tap(find.text('Edit cell'));
              await tester.pumpAndSettle();
              expect(offsets, [0, 65536]);
              expect(draft, expected);
              expect(
                tester.widget<EditableText>(input()).controller.text,
                second,
              );
              final data = tester.getSemantics(input()).getSemanticsData();
              expect(data.value.length, lessThanOrEqualTo(16384));
              expect(utf8.encode(data.value).length, lessThanOrEqualTo(49152));
              await tester.tap(find.text('Stage change'));
              await tester.pumpAndSettle();
              expect(staged, isNull);
              expect(
                tester.widget<EditableText>(input()).controller.text,
                second,
              );
              await tester.tap(find.text('Previous text page'));
              await tester.pumpAndSettle();
              expect(
                tester.widget<EditableText>(input()).controller.text,
                first,
              );
              await tester.tap(find.text('Next text page'));
              await tester.pumpAndSettle();
              await tester.tap(find.text('Stage change'));
              await tester.pumpAndSettle();
              expect(staged!.text, expected);
              expect(staged!.truncated, isFalse);
              expect(staged!.valueId, isEmpty);
              expect(value.writeToBuffer(), orderedEquals(original));
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
    testWidgets(
      '${controls.runtimeType} text and binary append never pad data',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final binary in [false, true]) {
          rpc.Value? staged;
          final bytes = Uint8List(16384)..fillRange(0, 16384, 7);
          final body = Builder(
            builder: (context) => controls.button('Open', () {
              controls.dialog<void>(
                context,
                'value',
                ResultValueEditor(
                  controls: controls,
                  value: binary
                      ? rpc.Value(binary: bytes)
                      : rpc.Value(text: 'a'),
                  column: rpc.Column(name: 'value'),
                  cancelRead: () {},
                  retainDraft: (_, _) {},
                  retainBinaryDraft: (_) {},
                  stage: (value) async => staged = value,
                ),
                [],
                bodyScrolls: true,
              );
            }),
          );
          await tester.pumpWidget(host(controls, body, TextDirection.ltr, 1));
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Edit cell'));
          await tester.pumpAndSettle();
          await valueEditorAction(tester, controls, 'Add editing page');
          await tester.pumpAndSettle();
          expect(tester.widget<EditableText>(input()).controller.text, isEmpty);
          await tester.enterText(input(), binary ? '00ff' : '😀b');
          await tester.tap(find.text('Stage change'));
          await tester.pumpAndSettle();
          if (binary) {
            expect(staged!.binary, orderedEquals([...bytes, 0, 255]));
          } else {
            expect(staged!.text, 'a😀b');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
    testWidgets(
      '${controls.runtimeType} large complete binary opens, copies and stages every byte',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        String? copied;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copied = (call.arguments as Map)['text'] as String;
              }
              if (call.method == 'Clipboard.getData') return {'text': copied};
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final bytes = List<int>.generate(65537, (index) => index % 251);
        final value = rpc.Value(binary: bytes),
            original = value.writeToBuffer();
        rpc.Value? staged;
        final body = Builder(
          builder: (context) => controls.button('Open', () {
            controls.dialog<void>(
              context,
              'binary',
              ResultValueEditor(
                controls: controls,
                value: value,
                column: rpc.Column(name: 'binary'),
                cancelRead: () {},
                retainDraft: (_, _) {},
                retainBinaryDraft: (_) {},
                stage: (value) async => staged = value,
              ),
              [],
              bodyScrolls: true,
            );
          }),
        );
        await tester.pumpWidget(host(controls, body, TextDirection.ltr, 1));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(find.text('Text page 1 of 17'), findsOneWidget);
        await valueEditorAction(tester, controls, 'Copy displayed text');
        await tester.pumpAndSettle();
        expect(
          copied,
          bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
        );
        await tester.tap(find.text('Edit cell'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<EditableText>(input()).controller.text.length,
          32768,
        );
        for (var page = 0; page < 4; page++) {
          await tester.tap(find.text('Next 16 KiB'));
          await tester.pumpAndSettle();
        }
        expect(
          tester.widget<EditableText>(input()).controller.text,
          bytes.last.toRadixString(16).padLeft(2, '0'),
        );
        await tester.tap(find.text('Stage change'));
        await tester.pumpAndSettle();
        expect(staged!.binary, orderedEquals(bytes));
        expect(value.writeToBuffer(), orderedEquals(original));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '${controls.runtimeType} NUL text stays exact in byte views and rejects native edits',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final failedDraft in [false, true]) {
          final source = rpc.Value(text: 'before\u0000after');
          final original = source.writeToBuffer();
          final drafts = <String>[];
          await tester.pumpWidget(
            host(
              controls,
              SizedBox(
                height: 520,
                child: ResultValueEditor(
                  controls: controls,
                  value: source,
                  column: rpc.Column(name: 'value'),
                  initialDraft: failedDraft ? 'draft\u0000exact' : null,
                  cancelRead: () {},
                  retainDraft: (value, _) => drafts.add(value),
                  stage: (_) async {},
                ),
              ),
              TextDirection.rtl,
              2,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Edit cell'), findsNothing);
          expect(
            find.textContaining('Plain text editing is unavailable'),
            findsOneWidget,
          );
          final shown = tester
              .widget<SelectableText>(find.byType(SelectableText))
              .data!;
          expect(
            shown,
            utf8
                .encode(failedDraft ? 'draft\u0000exact' : source.text)
                .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                .join(),
          );
          expect(shown.contains('\u0000'), isFalse);
          expect(drafts, isEmpty);
          expect(source.writeToBuffer(), orderedEquals(original));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
        await tester.pumpWidget(
          host(
            controls,
            SizedBox(
              height: 520,
              child: ResultValueEditor(
                controls: controls,
                value: rpc.Value(text: 'exact'),
                column: rpc.Column(name: 'value'),
                cancelRead: () {},
                retainDraft: (_, _) {},
                stage: (_) async {},
              ),
            ),
            TextDirection.ltr,
            1,
          ),
        );
        await tester.tap(find.text('Edit cell'));
        await tester.pumpAndSettle();
        await tester.enterText(input(), 'before\u0000after');
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(input()).controller.text, 'exact');
        expect(find.textContaining('invalid or too large'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${controls.runtimeType} retained text NUL has explicit byte presentations',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const text = 'before\u0000漢😀after';
        await tester.pumpWidget(
          host(
            controls,
            PagedSelectableText(controls: controls, text: text),
            TextDirection.rtl,
            2,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Plain text editing is unavailable'),
          findsOneWidget,
        );
        expect(
          tester.widget<SelectableText>(find.byType(SelectableText)).data,
          utf8
              .encode(text)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .join(),
        );
        for (final field in tester.widgetList<EditableText>(
          find.byType(EditableText),
        )) {
          expect(field.controller.text.contains('\u0000'), isFalse);
        }
        expect(tester.takeException(), isNull);
      },
    );
    for (final direction in TextDirection.values) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '${controls.runtimeType} read-only chunk visits every bounded native '
          'window ${direction.name} $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(const Size(1280, 800));
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final semantics = tester.ensureSemantics();
            try {
              final bytes = List<int>.generate(65536, (index) => index % 251);
              final expected = bytes
                  .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
                  .join();
              final value = rpc.Value(
                binary: bytes.take(8).toList(),
                valueId: 'owned-chunk',
                originalBytes: Int64(6000000),
                truncated: true,
              );
              final original = value.writeToBuffer();
              final offsets = <int>[];
              await tester.pumpWidget(
                host(
                  controls,
                  SizedBox(
                    width: 640,
                    height: 620,
                    child: ResultValueEditor(
                      controls: controls,
                      value: value,
                      column: rpc.Column(name: 'exact', typeName: 'bytea'),
                      readChunk: (offset) async {
                        offsets.add(offset);
                        return rpc.ValueChunk(
                          data: bytes,
                          totalBytes: Int64(6000000),
                          complete: false,
                        );
                      },
                      cancelRead: () {},
                      retainDraft: (_, _) {},
                    ),
                  ),
                  direction,
                  scale,
                ),
              );
              await tester.pumpAndSettle();
              await valueEditorAction(tester, controls, 'Load next 64 KiB');
              final shown = StringBuffer();
              for (var page = 0; page < 16; page++) {
                expect(
                  find.text('Text page ${page + 1} of 16'),
                  findsOneWidget,
                );
                final field = find.byWidgetPredicate(
                  (widget) => widget is EditableText && widget.readOnly,
                );
                expect(field, findsOneWidget);
                final native = tester.widget<EditableText>(field);
                expect(native.controller.text.length, 8192);
                expect(
                  native.controller.text,
                  expected.substring(page * 8192, (page + 1) * 8192),
                );
                expect(
                  tester.getSemantics(field).getSemanticsData().value,
                  native.controller.text,
                );
                shown.write(native.controller.text);
                if (page + 1 < 16) {
                  await tester.tap(find.text('Next text page'));
                  await tester.pumpAndSettle();
                }
              }
              expect(shown.toString(), expected);
              expect(offsets, [0]);
              expect(value.writeToBuffer(), orderedEquals(original));
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
    testWidgets(
      '${controls.runtimeType} readonly pages reconstruct the exact represented scope',
      (tester) async {
        final text = '${'x' * 16383}😀\r\n${'漢' * 15000}';
        await tester.pumpWidget(
          host(
            controls,
            PagedSelectableText(controls: controls, text: text),
            TextDirection.rtl,
            2,
          ),
        );
        final pages = <String>[];
        while (true) {
          final shown = tester
              .widget<SelectableText>(find.byType(SelectableText))
              .data!;
          expect(shown.length, lessThanOrEqualTo(16384));
          expect(utf8.encode(shown).length, lessThanOrEqualTo(49152));
          pages.add(shown);
          if (pages.join().length == text.length) break;
          await tester.tap(find.text('Next text page'));
          await tester.pumpAndSettle();
        }
        expect(pages.join(), text);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
