import 'dart:async';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'value_editor_test_actions.dart';

void main() {
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      'json',
      'invalid json',
      'binary edit',
      'decimal edit',
      'array tree',
      'array raw edit',
      'engine raw edit',
      'chunk cancellation',
      'offline retained preview',
    ]) {
      testWidgets('${controls.runtimeType} bounded Value Editor $scenario', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(1100, 850));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const decimal = '123456789012345678901234567890.00000000000001';
        final value = switch (scenario) {
          'json' => rpc.Value(json: '{"n":$decimal,"a":[null,"text"]}'),
          'invalid json' => rpc.Value(json: '{"broken":'),
          'binary edit' => rpc.Value(binary: [0, 255]),
          'decimal edit' => rpc.Value(decimal: decimal),
          'engine raw edit' => rpc.Value(
            engineValue: rpc.EngineValue(typeName: 'fixture-domain', text: '7'),
          ),
          'array raw edit' => rpc.Value(
            array: rpc.ArrayValue(nativeLiteral: '{1,2}'),
          ),
          'array tree' => rpc.Value(
            array: rpc.ArrayValue(
              values: [
                rpc.Value(text: 'exact array text'),
                rpc.Value(decimal: decimal),
                rpc.Value(nullValue: rpc.Null()),
              ],
            ),
          ),
          _ => rpc.Value(
            text: 'preview',
            valueId: 'full',
            truncated: true,
            originalBytes: Int64(90000),
          ),
        };
        final original = value.writeToBuffer(),
            drafts = <String>[],
            retained = Completer<rpc.ValueChunk>();
        rpc.Value? staged;
        var cancelCount = 0;
        final offsets = <int>[];
        final mode = scenario.contains('json')
            ? 'json'
            : scenario == 'binary edit'
            ? 'base64'
            : scenario == 'array tree'
            ? 'tree'
            : 'raw';
        final editor = ResultValueEditor(
          controls: controls,
          value: value,
          column: rpc.Column(name: 'value', typeName: scenario),
          initialPresentation: mode,
          retainDraft: (text, format) => drafts.add('$format:$text'),
          retainBinaryDraft: (draft) =>
              drafts.add('${draft.mode.name}:${draft.input}'),
          cancelRead: () => cancelCount++,
          readChunk: scenario == 'offline retained preview'
              ? null
              : (offset) {
                  offsets.add(offset);
                  return retained.future;
                },
          stage: scenario == 'offline retained preview'
              ? null
              : (proposed) async {
                  staged = proposed;
                },
        );
        final body = Center(
          child: SizedBox(width: 780, height: 600, child: editor),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: body)
              : MaterialApp(home: Scaffold(body: body)),
        );
        await tester.pumpAndSettle();
        switch (scenario) {
          case 'json':
            expect(find.textContaining(decimal), findsOneWidget);
            expect(find.textContaining('\n  "n":'), findsOneWidget);
          case 'invalid json':
            expect(
              find.text(
                'Structured interpretation is unavailable; exact raw content remains accessible.',
              ),
              findsOneWidget,
            );
            expect(find.text('{"broken":'), findsOneWidget);
          case 'array tree':
            expect(find.textContaining('exact array text'), findsOneWidget);
            expect(find.textContaining(decimal), findsOneWidget);
            expect(find.textContaining('NULL'), findsOneWidget);
          case 'binary edit':
          case 'decimal edit':
          case 'array raw edit':
          case 'engine raw edit':
            await tester.tap(find.text('Edit cell'));
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byType(EditableText),
              scenario == 'binary edit'
                  ? 'AP8B'
                  : scenario == 'array raw edit'
                  ? '{3,NULL,4}'
                  : scenario == 'engine raw edit'
                  ? '8'
                  : decimal,
            );
            await tester.tap(find.text('Stage change'));
            await tester.pumpAndSettle();
            expect(staged, isNotNull);
            if (scenario == 'binary edit') {
              expect(staged!.binary, [0, 255, 1]);
              expect(drafts.last, 'base64:AP8B');
            } else if (scenario == 'engine raw edit') {
              expect(staged!.text, '8');
              expect(drafts.last, 'raw:8');
            } else if (scenario == 'array raw edit') {
              expect(staged!.text, '{3,NULL,4}');
              expect(drafts.last, 'raw:{3,NULL,4}');
            } else {
              expect(staged!.text, decimal);
              expect(drafts.last, 'raw:$decimal');
            }
          case 'offline retained preview':
            expect(find.text('preview'), findsOneWidget);
            expect(
              find.text(
                'Retained data unavailable. Saved SQL and private recovery remain local.',
              ),
              findsOneWidget,
            );
            expect(find.text('Load next 64 KiB'), findsNothing);
            expect(find.text('Edit cell'), findsNothing);
            expect(offsets, isEmpty);
          case 'chunk cancellation':
            await valueEditorAction(tester, controls, 'Load next 64 KiB');
            await tester.pump();
            expect(offsets, [0]);
            await tester.tap(find.text('Cancel'));
            await tester.pump();
            expect(cancelCount, 1);
            retained.complete(
              rpc.ValueChunk(data: [65], totalBytes: Int64(90000)),
            );
            await tester.pumpAndSettle();
            expect(find.text('preview'), findsOneWidget);
            expect(find.textContaining('Bytes 0'), findsNothing);
        }
        expect(value.writeToBuffer(), orderedEquals(original));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
