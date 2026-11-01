import 'package:busydata/src/features/workspace/editor/sql_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void expectExact(SqlSource source, String text) {
  expect(source.text, text);
  expect(source.length, text.length);
  for (var offset = 0; offset <= text.length; offset++) {
    expect(
      source.offsetForPosition(source.positionForOffset(offset)),
      offset,
      reason: 'original UTF-16 offset $offset',
    );
  }
  source.dropMaterialization();
  expect(source.materializedUnits, 0);
  expect(source.text, text);
  expect(source.materializedUnits, 0);
}

void main() {
  test(
    'all line endings and every UTF-16 boundary survive materialization',
    () {
      for (final text in [
        '',
        'a\n',
        'a\r\n',
        'a\r',
        'a\r\nb\rc\n😀\r\n',
        '\r\n\r\n',
        'x\r\ny\nz\rfinal',
        'a\r\nb\r\nc',
      ]) {
        final source = SqlSource(text);
        expectExact(source, text);
        expect(source.lines.length, source.endings.length);
        expect(source.lines.last, isNot(contains(RegExp(r'[\r\n]'))));
      }
    },
  );

  test('raw replacements preserve mixed endings including CRLF interiors', () {
    const original = 'a\r\nb\rc\n😀\r\n';
    for (var start = 0; start <= original.length; start++) {
      for (var end = start; end <= original.length; end++) {
        final source = SqlSource(original);
        final changed = source.replace(start, end, 'Q\r\nR\rS\n');
        expectExact(changed, original.replaceRange(start, end, 'Q\r\nR\rS\n'));
        expectExact(source, original);
      }
    }
  });

  test('source positions cannot be adopted by another source revision', () {
    final source = SqlSource('a\r\nb');
    final other = source.replace(0, 1, 'z');
    final inside = source.positionForOffset(2);
    expect(inside.index, 0);
    expect(inside.offset, 1);
    expect(source.offsetForPosition(inside), 2);
    expect(
      () => other.offsetForPosition(inside),
      throwsA(isA<SqlEditorException>()),
    );
  });

  test('immutable projections share unchanged chunks after a local edit', () {
    final text = List.generate(800, (i) => 'row$i\r\n').join();
    final source = SqlSource(text);
    final changed = source.replace(
      source.starts[300] + 1,
      source.starts[300] + 2,
      'X',
    );
    expect(
      identical(
        source.codeLines.segments.first,
        changed.codeLines.segments.first,
      ),
      isTrue,
    );
    expect(
      identical(
        source.codeLines.segments.last,
        changed.codeLines.segments.last,
      ),
      isTrue,
    );
    expect(() => source.lines[0] = 'bad', throwsUnsupportedError);
    expect(() => source.endings[0] = '\n', throwsUnsupportedError);
    expect(() => source.starts[0] = 1, throwsUnsupportedError);
    expect(() => source.codeLines.segments.clear(), throwsUnsupportedError);
    expect(
      () => source.codeLines.segments.first.codeLines.clear(),
      throwsUnsupportedError,
    );
    expectExact(
      changed,
      text.replaceRange(source.starts[300] + 1, source.starts[300] + 2, 'X'),
    );
  });

  test(
    'projection edits preserve existing mixed separators and explicit source is exact',
    () {
      final source = SqlSource('a\r\nb\rc\n');
      final projected = CodeLines.fromText('a\nB\nc\n');
      final changed = source.rewriteProjection(projected);
      expectExact(changed, 'a\r\nB\rc\n');
      expectExact(source.replace(1, 3, '\r'), 'a\rb\rc\n');
    },
  );

  test(
    'line and document limits reject before retaining an invalid source',
    () {
      expect(
        () => SqlSource('a' * (SqlSource.maxUnits + 1)),
        throwsA(
          isA<SqlEditorException>().having(
            (e) => e.code,
            'code',
            SqlEditorFailure.documentLimit,
          ),
        ),
      );
      expect(
        () => SqlSource('\n' * SqlSource.maxLines),
        throwsA(
          isA<SqlEditorException>().having(
            (e) => e.code,
            'code',
            SqlEditorFailure.lineLimit,
          ),
        ),
      );
    },
  );
}
