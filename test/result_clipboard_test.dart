import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/l10n/workbench_strings.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/platform/native_menu_service.dart';
import 'package:busydata/src/ui/common/desktop_controls.dart';
import 'package:busydata/src/ui/common/result_grid.dart';
import 'package:busydata/src/ui/linux/linux_controls.dart';
import 'package:busydata/src/ui/windows/windows_controls.dart';
import 'package:fixnum/fixnum.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_backend.dart';

void main() {
  test(
    'retained predicates preserve exact scalar types and reject ambiguous operands',
    () {
      const exact = '90071992547409931234567890.123456789';
      expect(
        retainedFilterValue(rpc.Column(jdbcType: 3), exact).decimal,
        exact,
      );
      expect(
        retainedFilterValue(rpc.Column(jdbcType: 16), 'false').boolean,
        isFalse,
      );
      expect(
        () => retainedFilterValue(rpc.Column(jdbcType: 16), '0'),
        throwsFormatException,
      );
      expect(retainedFilterValue(rpc.Column(jdbcType: -3), '00Ff').binary, [
        0,
        255,
      ]);
      expect(
        () => retainedFilterValue(rpc.Column(jdbcType: -3), '0'),
        throwsFormatException,
      );
      expect(
        retainedFilterValue(
          rpc.Column(jdbcType: 91),
          '2026-10-08',
        ).temporal.iso,
        '2026-10-08',
      );
      expect(
        retainedFilterValue(
          rpc.Column(jdbcType: 1111, typeName: 'jsonb'),
          '{}',
        ).json,
        '{}',
      );
      expect(
        () => retainedFilterValue(rpc.Column(jdbcType: 2003), '[1]'),
        throwsFormatException,
      );
      final empty = retainedFilterValue(rpc.Column(jdbcType: 12), '');
      expect(empty.hasText(), isTrue);
      expect(empty.hasNullValue(), isFalse);
      expect(
        () => retainedFilterValue(rpc.Column(jdbcType: -3), '00' * 5000),
        throwsFormatException,
      );
    },
  );
  test(
    'fetched copy preserves NULL, exact text, quotes, JSON booleans and decimal digits',
    () {
      final rows = [
        [
          rpc.Value(nullValue: rpc.Null()),
          rpc.Value(text: r'\N'),
          rpc.Value(text: '"漢😀\n'),
          rpc.Value(boolean: true),
          rpc.Value(decimal: '9007199254740993.000000001'),
        ],
      ];
      expect(
        copyFetchedValues(rows, 'csv'),
        '\\N,"\\N","""漢😀\n","true","9007199254740993.000000001"',
      );
      expect(jsonDecode(copyFetchedValues(rows, 'json')), [
        [null, r'\N', '"漢😀\n', true, '9007199254740993.000000001'],
      ]);
      expect(
        copyFetchedValues(rows, 'text'),
        'NULL\t\\N\t"漢😀\n\ttrue\t9007199254740993.000000001',
      );
    },
  );
  test(
    'copy admits the exact UTF-8 budget and counts multibyte data and separators',
    () {
      final exact = 'a' * resultClipboardByteLimit;
      expect(
        copyFetchedValues([
          [rpc.Value(text: exact)],
        ], 'text'),
        exact,
      );
      for (final rows in [
        [
          [rpc.Value(text: exact), rpc.Value(text: '')],
        ],
        [
          [rpc.Value(text: '漢' * (resultClipboardByteLimit ~/ 3 + 1))],
        ],
        [
          [rpc.Value(text: '😀' * (resultClipboardByteLimit ~/ 4 + 1))],
        ],
      ]) {
        expect(() => copyFetchedValues(rows, 'text'), throwsStateError);
      }
    },
  );
  test(
    'copy rejects quoting and JSON expansion before allocating encoded payloads',
    () {
      expect(
        () => copyFetchedValues([
          [rpc.Value(text: '"' * (resultClipboardByteLimit ~/ 2))],
        ], 'csv'),
        throwsStateError,
      );
      expect(
        () => copyFetchedValues([
          [rpc.Value(text: '\u0000' * (resultClipboardByteLimit ~/ 6 + 1))],
        ], 'json'),
        throwsStateError,
      );
      expect(
        () => copyFetchedValues([
          [
            rpc.Value(
              binary: List.filled(resultClipboardByteLimit ~/ 2 + 1, 0),
            ),
          ],
        ], 'text'),
        throwsStateError,
      );
    },
  );
  test(
    'copy bounds nested arrays and cumulative cells without flattening them first',
    () {
      var deep = rpc.Value(text: 'n');
      for (var i = 0; i < 18; i++) {
        deep = rpc.Value(array: rpc.ArrayValue(values: [deep]));
      }
      expect(
        () => copyFetchedValues([
          [deep],
        ], 'text'),
        throwsStateError,
      );
      final wide = rpc.Value(
        array: rpc.ArrayValue(
          values: List.generate(1024, (_) => rpc.Value(text: 'a' * 4096)),
        ),
      );
      expect(
        () => copyFetchedValues([
          [wide],
        ], 'text'),
        throwsStateError,
      );
      expect(
        () => copyFetchedValues([
          [
            rpc.Value(
              array: rpc.ArrayValue(
                values: List.generate(1025, (_) => rpc.Value(text: 'n')),
              ),
            ),
          ],
        ], 'text'),
        throwsStateError,
      );
    },
  );
  for (final controls in <DesktopControls>[
    const LinuxControls(),
    const WindowsControls(),
  ]) {
    for (final scenario in [
      'backend replacement',
      'result disposal',
      'oversized reply',
      'embedded NUL reply',
      'ordinary',
    ]) {
      testWidgets('${controls.runtimeType} SQL copy $scenario', (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-sql-copy-'),
        ))!;
        final backend = TestBackend();
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..backend = backend
          ..newDocument();
        final pending = Completer<rpc.CopySqlReply>();
        backend.client.sqlCopy = (_) => pending.future;
        model.cache['retained:0'] = rpc.Row(
          values: [rpc.Value(decimal: '9007199254740993.000000001')],
        );
        final result = rpc.StatementResult(
          resultId: 'retained',
          fetchedRows: Int64.ONE,
          complete: true,
          columns: [rpc.Column(name: 'n')],
        );
        final writes = <String>[];
        const nativeMenu = MethodChannel(nativeMenuChannelName);
        var nativeSelections = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          nativeMenu,
          (call) async {
            if (call.method == 'show') {
              final entries = (call.arguments as Map)['entries'] as List;
              final index = entries.indexWhere(
                (entry) => (entry as Map)['label'] == 'Copy SQL values',
              );
              expect(index, greaterThanOrEqualTo(0));
              nativeSelections++;
              return index;
            }
            return true;
          },
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              writes.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(() async {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            nativeMenu,
            null,
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = SizedBox(
          width: 750,
          height: 400,
          child: ResultGrid(model: model, controls: controls, result: result),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Data grid',
          ),
        );
        await tester.pumpAndSettle();
        if (controls is WindowsControls) {
          await tester.tap(find.text('Copy SQL values').last);
          await tester.pumpAndSettle();
        } else {
          expect(nativeSelections, 1);
        }
        await tester.pump();
        expect(backend.client.sqlCopyRequests, hasLength(1));
        expect(backend.client.sqlCopyRequests.single.resultId, 'retained');
        if (scenario == 'backend replacement') {
          model.backend = TestBackend(instanceId: 'replacement');
        }
        if (scenario == 'result disposal') {
          model.disposedResults.add('retained');
        }
        const literal = '(9007199254740993.000000001)';
        pending.complete(
          rpc.CopySqlReply(
            text: scenario == 'oversized reply'
                ? 'x' * (resultClipboardByteLimit + 1)
                : scenario == 'embedded NUL reply'
                ? "(E'before\u0000after')"
                : literal,
          ),
        );
        await tester.pumpAndSettle();
        if (scenario == 'ordinary') {
          expect(writes, [literal]);
        } else {
          expect(writes, isEmpty);
          expect(
            model.status,
            contains(
              scenario == 'oversized reply'
                  ? 'exceeds 1MiB'
                  : scenario == 'embedded NUL reply'
                  ? strings(
                      tester.element(find.byType(ResultGrid)),
                    ).textClipboardNulUnavailable
                  : strings(
                      tester.element(find.byType(ResultGrid)),
                    ).staleContext,
            ),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
    testWidgets(
      '${controls.runtimeType} retained NUL copy keeps clipboard and original cells',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-nul-copy-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument();
        final value = rpc.Value(text: 'before\u0000after');
        final original = value.writeToBuffer();
        model.cache['result:0'] = rpc.Row(values: [value]);
        final result = rpc.StatementResult(
          resultId: 'result',
          fetchedRows: Int64.ONE,
          complete: true,
          columns: [rpc.Column(name: 'nul')],
        );
        var writes = 0;
        const previous = 'previous clipboard';
        var clipboard = previous;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              writes++;
              clipboard = (call.arguments as Map)['text'] as String;
            }
            if (call.method == 'Clipboard.getData') return {'text': clipboard};
            return null;
          },
        );
        addTearDown(() async {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final grid = SizedBox(
          width: 700,
          height: 400,
          child: ResultGrid(model: model, controls: controls, result: result),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: grid)
              : MaterialApp(home: Scaffold(body: grid)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(value.text));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(writes, 0);
        expect(clipboard, previous);
        expect(
          model.status,
          contains(
            strings(
              tester.element(find.byType(ResultGrid)),
            ).textClipboardNulUnavailable,
          ),
        );
        expect(
          model.cache['result:0']!.values.single.writeToBuffer(),
          orderedEquals(original),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
    testWidgets(
      '${controls.runtimeType} grid reports clipboard denial without losing cells',
      (tester) async {
        final root = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('busydata-copy-'),
        ))!;
        final model = WorkbenchModel(root)
          ..draftRecovery = false
          ..newDocument();
        final value = rpc.Value(text: '漢😀');
        model.cache['result:0'] = rpc.Row(values: [value]);
        final result = rpc.StatementResult(
          resultId: 'result',
          fetchedRows: Int64.ONE,
          complete: true,
          columns: [rpc.Column(name: 'n')],
        );
        var writes = 0;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              writes++;
              throw PlatformException(
                code: 'denied',
                message: 'Clipboard denied',
              );
            }
            return null;
          },
        );
        addTearDown(() async {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
          model.dispose();
          await tester.runAsync(() => root.delete(recursive: true));
        });
        final view = SizedBox(
          width: 700,
          height: 400,
          child: ResultGrid(model: model, controls: controls, result: result),
        );
        await tester.pumpWidget(
          controls is WindowsControls
              ? fluent.FluentApp(home: view)
              : MaterialApp(home: Scaffold(body: view)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('漢😀'));
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(writes, 1);
        expect(model.status, contains('Clipboard denied'));
        expect(model.cache['result:0']!.values.single, value);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
