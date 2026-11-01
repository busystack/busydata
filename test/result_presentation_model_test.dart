import 'dart:convert';
import 'dart:io';
import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/result_presentation.dart';
import 'package:busydata/src/features/results/structured_value.dart';
import 'package:busydata/src/features/results/value_assignments.dart';
import 'package:busydata/src/features/results/value_document.dart';
import 'package:busydata/src/features/workspace/workbench_model.dart';
import 'package:busydata/src/ui/common/result_presentations.dart';
import 'package:busydata/src/ui/common/bounded_text_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'assignment intent separates unset, NULL, DEFAULT and literal DEFAULT',
    () {
      expect(
        rpc.ValueAssignment().whichAssignment(),
        rpc.ValueAssignment_Assignment.notSet,
      );
      expect(assignmentNull().hasNullValue(), isTrue);
      expect(assignmentDefault().hasDefaultValue(), isTrue);
      expect(assignmentOf(rpc.Value(text: 'DEFAULT')).value.text, 'DEFAULT');
      expect(assignmentValue(assignmentDefault()), isNull);
      expect(assignmentValue(assignmentNull())!.hasNullValue(), isTrue);
    },
  );
  test('staged defaults coalesce without becoming an unchanged NULL', () {
    final batch = OwnedEditBatch('doc', 'source');
    final original = rpc.Row(values: [rpc.Value(nullValue: rpc.Null())]);
    batch.stage(
      rpc.StagedChange(
        kind: rpc.ChangeKind.UPDATE,
        sourceRow: Int64.ZERO,
        values: {1: assignmentDefault()}.entries,
      ),
      original: original,
    );
    expect(batch.changes.single.values[1]!.hasDefaultValue(), isTrue);
    batch.stage(
      rpc.StagedChange(
        kind: rpc.ChangeKind.UPDATE,
        sourceRow: Int64.ZERO,
        values: {1: assignmentNull()}.entries,
      ),
      original: original,
    );
    expect(batch.changes, isEmpty);
  });
  test('display grouping preserves every integer and decimal digit', () {
    const raw = '-123456789012345678901234567890.00000000000000000001';
    expect(
      groupExactNumber(raw),
      '-123,456,789,012,345,678,901,234,567,890.00000000000000000001',
    );
    expect(groupExactNumber('1.005e+23'), '1.005e+23');
    expect(groupExactNumber('not a number'), 'not a number');
  });
  test(
    'display formats never mutate retained bytes or numeric representations',
    () {
      final value = rpc.Value(binary: List.generate(16, (i) => i));
      final before = value.writeToBuffer();
      expect(
        displayedResultValue(value, ColumnDisplayFormat.uuid),
        '00010203-0405-0607-0809-0a0b0c0d0e0f',
      );
      expect(
        displayedResultValue(value, ColumnDisplayFormat.base64),
        base64Encode(List.generate(16, (i) => i)),
      );
      expect(value.writeToBuffer(), orderedEquals(before));
    },
  );
  test(
    'column preferences use captured stable identity across rename and reject replacement or names-only provenance',
    () {
      final column = rpc.Column(
        name: 'label',
        baseColumn: 'native',
        catalog: 'db',
        schema: 'a',
        table: 't',
        provenanceKnown: true,
        metadataIdentity: 'physical-column-one',
        metadataSnapshotRevision: Int64(7),
      );
      final key = resultColumnPreferenceKey('profile', column);
      expect(key, jsonEncode(['profile', 'physical-column-one']));
      expect(
        resultColumnPreferenceKey(
          'profile',
          column.deepCopy()
            ..name = 'new label'
            ..baseColumn = 'renamed'
            ..table = 'renamed_table'
            ..schema = 'renamed_schema'
            ..metadataSnapshotRevision = Int64(9),
        ),
        key,
      );
      expect(
        resultColumnPreferenceKey(
          'profile',
          column.deepCopy()..metadataIdentity = 'replacement-column',
        ),
        isNot(key),
      );
      expect(resultColumnPreferenceKey('other-profile', column), isNot(key));
      expect(
        resultColumnPreferenceKey(
          'profile',
          column.deepCopy()..provenanceKnown = false,
        ),
        isNull,
      );
      expect(
        resultColumnPreferenceKey(
          'profile',
          column.deepCopy()..metadataIdentity = '',
        ),
        isNull,
      );
      expect(
        resultColumnPreferenceKey(
          'profile',
          column.deepCopy()..metadataSnapshotRevision = Int64.ZERO,
        ),
        isNull,
      );
      expect(resultColumnPreferenceKey(null, column), isNull);
      expect(resultColumnPreferenceKey('', column), isNull);
    },
  );
  test(
    'failed value drafts preserve presentation interpretation and share a bound',
    () {
      final state = ResultPresentationState();
      state.retainDraft(3, 7, 'AA==', 'base64');
      state.mode = ResultPresentation.tree;
      expect(state.draft(3, 7), 'AA==');
      expect(state.draftFormat(3, 7), 'base64');
      expect(() => state.retainDraft(4, 7, 'x' * 262145), throwsStateError);
      for (var i = 0; i < 15; i++) {
        state.retainDraft(i + 10, 7, '$i');
      }
      expect(() => state.retainDraft(100, 7, 'x'), throwsStateError);
      state.clearDraft(3, 7);
      state.retainDraft(100, 7, 'x');
      expect(state.draft(100, 7), 'x');
    },
  );
  test(
    'lossless JSON display preserves huge numeric lexemes and duplicate keys',
    () {
      const raw =
          '{"n":123456789012345678901234567890.00000000000001,"n":1e-400,"s":"\\u263a"}';
      final data = StructuredJson.parse(raw);
      expect(data.root.children.map((c) => c.name), ['n', 'n', 's']);
      expect(
        data.pretty(),
        contains('123456789012345678901234567890.00000000000001'),
      );
      expect(data.pretty(), contains('1e-400'));
      expect(data.raw(data.root.children[2].node), '"\\u263a"');
      expect(StructuredJson.parse(data.pretty()).pretty(), data.pretty());
    },
  );
  for (final invalid in [
    '{"n":01}',
    '{"n":NaN}',
    '[1,]',
    '{"x":}',
    '"bad\\q"',
    '[1] trailing',
    '{"x" 1}',
    '"unterminated',
  ]) {
    test(
      'structured invalid input remains a controlled parse error: $invalid',
      () {
        expect(() => StructuredJson.parse(invalid), throwsFormatException);
      },
    );
  }
  test('structured JSON enforces size, depth and node admission', () {
    expect(
      () => StructuredJson.parse('"${'a' * 262144}"'),
      throwsFormatException,
    );
    expect(
      () => StructuredJson.parse('${'[' * 34}0${']' * 34}'),
      throwsFormatException,
    );
    expect(
      () => StructuredJson.parse('[${List.filled(4096, '0').join(',')}]'),
      throwsFormatException,
    );
  });
  test(
    'XML interpretation refuses declarations and preserves exact text content',
    () {
      expect(
        formatXmlDisplay('<a><b>  exact text  </b></a>'),
        contains('  exact text  '),
      );
      expect(
        () => formatXmlDisplay('<!DOCTYPE x SYSTEM "file:///etc/passwd"><x/>'),
        throwsFormatException,
      );
      expect(() => formatXmlDisplay('<a><b></a>'), throwsFormatException);
      expect(() => formatXmlDisplay('<a>'), throwsFormatException);
    },
  );
  test(
    'value pages accept only bounded complete ownership-consistent ranges',
    () {
      final document = ValueDocument(
        rpc.Value(text: 'preview', truncated: true),
      );
      document.accept(rpc.ValueChunk(data: [1, 2], totalBytes: Int64(4)), 0);
      expect(document.nextOffset, 2);
      document.accept(
        rpc.ValueChunk(data: [3, 4], totalBytes: Int64(4), complete: true),
        2,
      );
      expect(document.chunk, [3, 4]);
      expect(document.complete, isTrue);
      expect(
        () => document.accept(
          rpc.ValueChunk(data: [1], totalBytes: Int64(9), complete: true),
          0,
        ),
        throwsStateError,
      );
      expect(
        () => document.accept(
          rpc.ValueChunk(
            data: List.filled(65537, 0),
            totalBytes: Int64(65537),
            complete: true,
          ),
          0,
        ),
        throwsStateError,
      );
      document.reset();
      expect(document.chunk, isNull);
      expect(document.nextOffset, 0);
    },
  );
  test(
    'binary edit modes decode bytes exactly and never encode through text',
    () {
      final original = rpc.Value(binary: [0, 255]);
      expect(
        editedValue(original, '00ff', ValuePresentation.hexadecimal).binary,
        [0, 255],
      );
      expect(editedValue(original, 'AP8=', ValuePresentation.base64).binary, [
        0,
        255,
      ]);
      expect(
        () => editedValue(original, 'f', ValuePresentation.hexadecimal),
        throwsFormatException,
      );
      expect(
        () => editedValue(original, '00ff', ValuePresentation.uuid),
        throwsFormatException,
      );
      expect(
        editedValue(
          rpc.Value(decimal: '1'),
          '12345678901234567890.0000000001',
          ValuePresentation.raw,
        ).text,
        '12345678901234567890.0000000001',
      );
    },
  );
  test('image admission checks content dimensions rather than claims', () {
    final png = [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
      0,
      0,
      0,
      13,
      73,
      72,
      68,
      82,
      0,
      0,
      0,
      64,
      0,
      0,
      0,
      32,
    ];
    expect(recognizedImageSize(png), (width: 64, height: 32));
    final bomb = List<int>.of(png)..setRange(16, 20, [127, 255, 255, 255]);
    expect(recognizedImageSize(bomb), isNull);
    expect(recognizedImageSize(utf8.encode('image/png')), isNull);
    expect(recognizedImageSize(List.filled(1048577, 0)), isNull);
    expect(recognizedImageSize([255, 216, 255, 192, 0, 1]), isNull);
  });
  test(
    'fixed-scale display rounds huge coefficients without floating point',
    () {
      expect(
        fixedDecimalDisplay('999999999999999999999999.995', 2),
        '1,000,000,000,000,000,000,000,000.00',
      );
      expect(fixedDecimalDisplay('-0.005', 2), '-0.01');
      expect(fixedDecimalDisplay('1.2', 4), '1.2000');
      expect(fixedDecimalDisplay('1e100', 2), '1e100');
    },
  );
  test(
    'timezone presentation requires an explicit offset and keeps local values raw',
    () {
      final local = rpc.Temporal(
        iso: '2026-10-24T01:02:03.123456',
        kind: 'timestamp',
      );
      expect(temporalDisplay(local, ColumnDisplayFormat.utc), local.iso);
      final offset = rpc.Temporal(
        iso: '2026-10-24T01:02:03.123456+02:00',
        kind: 'timestamptz',
      );
      expect(
        temporalDisplay(offset, ColumnDisplayFormat.utc),
        '2026-10-23T23:02:03.123456Z',
      );
      expect(
        temporalDisplay(offset, ColumnDisplayFormat.isoDate),
        '2026-10-24',
      );
      expect(
        temporalDisplay(offset, ColumnDisplayFormat.isoTime),
        '01:02:03.123456+02:00',
      );
      expect(offset.iso, '2026-10-24T01:02:03.123456+02:00');
    },
  );
  test(
    'value input rejects oversized edits before replacing text or selection',
    () {
      var rejected = 0;
      final controller = BoundedTextController(
        text: 'exact',
        maxUnits: 8,
        rejected: () => rejected++,
      );
      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 4,
      );
      final before = controller.value;
      controller.value = const TextEditingValue(
        text: 'oversized value',
        selection: TextSelection.collapsed(offset: 15),
      );
      expect(controller.value, before);
      expect(rejected, 1);
      controller.text = 'new';
      expect(controller.text, 'new');
      controller.dispose();
    },
  );
  test(
    'every display preset persists with the shared stable identity contract',
    () async {
      Map<String, dynamic>? written;
      final model = WorkbenchModel(
        Directory('/unused'),
        presentationWrite: (file, bytes) async {
          written = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        },
      )..newDocument();
      final profile = rpc.Profile(id: 'p');
      final column = rpc.Column(
        name: 'label',
        baseColumn: 'exact',
        metadataIdentity: 'physical-column',
        metadataSnapshotRevision: Int64.ONE,
        catalog: 'db',
        schema: 's',
        table: 't',
        provenanceKnown: true,
      );
      final key = model.resultDisplayFormatKey(profile, column)!;
      for (final preset in ColumnDisplayFormat.values) {
        final stored = preset == ColumnDisplayFormat.temporalPattern
            ? TemporalDisplayPattern(
                'yyyy/MM/dd HH:mm:ss.SSSSSS',
                TemporalDisplayZone.utc,
              ).stored
            : preset.name;
        await model.setResultDisplayFormat(profile, column, stored);
        final formats =
            written!['resultDisplayFormats'] as Map<String, dynamic>;
        expect(
          formats[key],
          preset == ColumnDisplayFormat.canonical ? isNull : stored,
        );
      }
      model.dispose();
    },
  );
}
