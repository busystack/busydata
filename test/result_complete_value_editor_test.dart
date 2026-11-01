import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/complete_value.dart';
import 'package:busydata/src/features/results/value_document.dart';
import 'package:busydata/src/ui/common/result_value_editor.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/paged_selectable_text.dart';
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
    testWidgets(
      '${controls.runtimeType} oversized original binary has an explicit display limit',
      (tester) async {
        final bytes = Uint8List(completeValueByteLimit + 1);
        bytes.first = 0x01;
        bytes.last = 0xff;
        final value = rpc.Value(binary: bytes);
        var reads = 0, staged = 0;
        final editor = ResultValueEditor(
          controls: controls,
          value: value,
          column: rpc.Column(name: 'bytes', typeName: 'bytea'),
          cancelRead: () {},
          retainDraft: (_, _) {},
          readChunk: (_) async {
            reads++;
            throw StateError('No automatic read');
          },
          stage: (_) async {
            staged++;
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
        const scopeLimit =
            'This presentation exceeds its bounded scope. Select fewer cells or use Export.';
        expect(find.text(scopeLimit), findsOneWidget);
        expect(find.text('Edit cell'), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is SelectableText &&
                (widget.data ?? widget.textSpan?.toPlainText()) != scopeLimit,
          ),
          findsNothing,
        );
        expect(find.byType(PagedSelectableText), findsNothing);
        expect(
          find.byWidgetPredicate(
            (widget) => widget is EditableText && !widget.readOnly,
          ),
          findsNothing,
        );
        expect(reads, 0);
        expect(staged, 0);
        expect(value.binary.length, completeValueByteLimit + 1);
        expect(value.binary.first, 0x01);
        expect(value.binary.last, 0xff);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${controls.runtimeType} preserves a newer draft after earlier staging completes',
      (tester) async {
        final gate = Completer<void>();
        final proposals = <String>[];
        String? retained;
        final editor = ResultValueEditor(
          controls: controls,
          value: rpc.Value(text: 'original'),
          column: rpc.Column(name: 'value', typeName: 'text'),
          cancelRead: () {},
          retainDraft: (text, _) => retained = text,
          stage: (value) async {
            proposals.add(value.text);
            await gate.future;
            retained = null;
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
        await tester.tap(find.text('Edit cell'));
        await tester.pumpAndSettle();
        final input = find.byWidgetPredicate(
          (widget) => widget is EditableText && !widget.readOnly,
        );
        await tester.enterText(input, 'first');
        await tester.tap(find.text('Stage change'));
        await tester.pump();
        expect(proposals, ['first']);
        await tester.enterText(input, 'newer');
        gate.complete();
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(input).controller.text, 'newer');
        expect(retained, 'newer');
        expect(
          find.textContaining('The earlier value was staged.'),
          findsOneWidget,
        );
        expect(proposals, ['first']);
        expect(tester.takeException(), isNull);
      },
    );
    testWidgets(
      '${controls.runtimeType} reopens an invalid complete binary draft without rereading its owner',
      (tester) async {
        final complete = BinaryValueDraft(Uint8List(65537))..offset = 65536;
        final snapshot = complete.snapshot('zz', ValuePresentation.hexadecimal);
        var reads = 0;
        rpc.Value? staged;
        final editor = ResultValueEditor(
          controls: controls,
          value: rpc.Value(
            binary: [0],
            truncated: true,
            valueId: 'owned',
            originalBytes: Int64(65537),
          ),
          column: rpc.Column(name: 'bytes', typeName: 'bytea'),
          initialBinaryDraft: snapshot,
          retainDraft: (_, _) {},
          retainBinaryDraft: (_) {},
          cancelRead: () {},
          readChunk: (_) async {
            reads++;
            throw StateError('No automatic read');
          },
          stage: (value) async {
            staged = value;
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
        final input = find.byWidgetPredicate(
          (widget) => widget is EditableText && !widget.readOnly,
        );
        expect(tester.widget<EditableText>(input).controller.text, 'zz');
        await tester.tap(find.text('Stage change'));
        await tester.pumpAndSettle();
        expect(staged, isNull);
        expect(tester.widget<EditableText>(input).controller.text, 'zz');
        await tester.enterText(input, 'ff');
        await tester.tap(find.text('Stage change'));
        await tester.pumpAndSettle();
        expect(staged!.binary.length, 65537);
        expect(staged!.binary.last, 255);
        expect(reads, 0);
        expect(tester.takeException(), isNull);
      },
    );

    for (final scenario in [
      'complete text',
      'complete binary',
      'cancel',
      'stale owner',
      'failed stage',
      'oversized',
    ]) {
      testWidgets(
        '${controls.runtimeType} explicit complete Value Editor $scenario',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(1100, 850));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final binary = scenario == 'complete binary',
              bytes = binary
                  ? Uint8List.fromList(
                      List.generate(65537, (index) => index % 256),
                    )
                  : utf8.encode('exact 😀 ${'n' * 70000}');
          final original = binary
              ? rpc.Value(
                  binary: [0, 1],
                  valueId: 'owned',
                  truncated: true,
                  originalBytes: Int64(bytes.length),
                )
              : rpc.Value(
                  text: 'exact',
                  valueId: 'owned',
                  truncated: true,
                  originalBytes: Int64(
                    scenario == 'oversized' ? 1048577 : bytes.length,
                  ),
                );
          final saved = original.writeToBuffer(),
              offsets = <int>[],
              pending = Completer<rpc.ValueChunk>();
          var cancellations = 0;
          rpc.Value? staged;
          BinaryDraftSnapshot? binarySnapshot;
          String? retained;
          final editor = ResultValueEditor(
            controls: controls,
            value: original,
            column: rpc.Column(
              name: 'value',
              typeName: binary ? 'bytea' : 'text',
            ),
            cancelRead: () => cancellations++,
            retainDraft: (text, mode) => retained = text,
            retainBinaryDraft: (draft) => binarySnapshot = draft,
            readChunk: (offset) async {
              offsets.add(offset);
              if (scenario == 'cancel') return pending.future;
              if (scenario == 'stale owner') {
                throw const RetainedValueOwnerChanged();
              }
              final end = (offset + 65536).clamp(0, bytes.length);
              return rpc.ValueChunk(
                data: bytes.sublist(offset, end),
                totalBytes: Int64(bytes.length),
                complete: end == bytes.length,
              );
            },
            stage: (value) async {
              if (scenario == 'failed stage') throw StateError('synthetic');
              staged = value;
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
          expect(offsets, isEmpty);
          if (scenario == 'oversized') {
            expect(find.text('Edit complete value'), findsNothing);
            expect(
              find.textContaining('Complete editing requires'),
              findsOneWidget,
            );
            return;
          }
          await valueEditorAction(tester, controls, 'Edit complete value');
          await tester.pumpAndSettle();
          if (scenario == 'cancel') {
            await tester.tap(find.text('Cancel'));
            await tester.pump();
            pending.complete(
              rpc.ValueChunk(
                data: bytes.sublist(0, 65536),
                totalBytes: Int64(bytes.length),
              ),
            );
            await tester.pumpAndSettle();
            expect(offsets, [0]);
            expect(
              find.byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              ),
              findsNothing,
            );
            expect(cancellations, greaterThanOrEqualTo(1));
            expect(staged, isNull);
          } else if (scenario == 'stale owner') {
            expect(
              find.byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              ),
              findsNothing,
            );
            expect(find.textContaining('context'), findsOneWidget);
            expect(offsets, [0]);
            expect(staged, isNull);
          } else {
            expect(offsets, [0, 65536]);
            expect(
              find.byWidgetPredicate(
                (widget) => widget is EditableText && !widget.readOnly,
              ),
              findsOneWidget,
            );
            if (binary) {
              for (var page = 0; page < 4; page++) {
                await tester.tap(find.text('Next 16 KiB'));
                await tester.pumpAndSettle();
              }
              expect(
                tester
                    .widget<EditableText>(
                      find.byWidgetPredicate(
                        (widget) => widget is EditableText && !widget.readOnly,
                      ),
                    )
                    .controller
                    .text,
                '00',
              );
              await tester.enterText(
                find.byWidgetPredicate(
                  (widget) => widget is EditableText && !widget.readOnly,
                ),
                'ff',
              );
            } else {
              await tester.enterText(
                find.byWidgetPredicate(
                  (widget) => widget is EditableText && !widget.readOnly,
                ),
                'changed exact 😀',
              );
            }
            await tester.tap(find.text('Stage change'));
            await tester.pumpAndSettle();
            if (scenario == 'failed stage') {
              expect(staged, isNull);
              expect(
                retained,
                'changed exact 😀${utf8.decode(bytes).substring(16384)}',
              );
              expect(
                tester
                    .widget<EditableText>(
                      find.byWidgetPredicate(
                        (widget) => widget is EditableText && !widget.readOnly,
                      ),
                    )
                    .controller
                    .text,
                'changed exact 😀',
              );
            } else if (binary) {
              expect(staged!.binary.length, 65537);
              expect(staged!.binary.last, 255);
              expect(
                staged!.binary.take(65536),
                orderedEquals(bytes.take(65536)),
              );
              expect(binarySnapshot!.offset, 65536);
            } else {
              expect(
                staged!.text,
                'changed exact 😀${utf8.decode(bytes).substring(16384)}',
              );
              expect(staged!.valueId, isEmpty);
              expect(staged!.truncated, isFalse);
            }
          }
          expect(original.writeToBuffer(), orderedEquals(saved));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
}
