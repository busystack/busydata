import 'dart:convert';
import 'package:busydata/src/features/results/text_value_draft.dart';
import 'package:busydata/src/ui/common/bounded_text_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pages preserve exact Unicode, CRLF and JSON lexemes', () {
    final original =
        '${'漢' * 16383}😀\r\n{"n":12345678901234567890.000,"n":-0}';
    final draft = TextValueDraft(original);
    expect(draft.pageCount, 2);
    expect(draft.pageText, '漢' * 16383);
    expect(draft.pageStart, 0);
    expect(draft.pageEnd, 16383);
    draft.move(1, draft.pageText);
    expect(draft.pageText, '😀\r\n{"n":12345678901234567890.000,"n":-0}');
    expect(draft.fullText, original);
    draft.move(-1, draft.pageText);
    expect(draft.text, original);
    expect(draft.hasPrevious, isFalse);
    expect(draft.hasNext, isTrue);
  });

  test(
    'middle-page edits preserve untouched prefix, suffix and page identity',
    () {
      final prefix = 'a' * 16384, middle = 'b' * 16384;
      const suffix = 'exact tail 漢😀\r\n';
      final draft = TextValueDraft('$prefix$middle$suffix');
      draft.move(1, draft.pageText);
      draft.replacePage('replacement 😀');
      expect(draft.pageIndex, 1);
      expect(draft.pageCount, 3);
      expect(draft.pageText, 'replacement 😀');
      expect(draft.fullText, '${prefix}replacement 😀$suffix');
      draft.move(1, draft.pageText);
      expect(draft.pageText, suffix);
      draft.move(-1, draft.pageText);
      expect(draft.pageText, 'replacement 😀');
      draft.move(-1, draft.pageText);
      expect(draft.pageText, prefix);
    },
  );

  test('empty pages keep their identity and can receive text again', () {
    final draft = TextValueDraft('${'a' * 16384}${'b' * 16384}tail');
    draft.replacePage('');
    expect(draft.pageText, isEmpty);
    expect(draft.pageCount, 3);
    draft.move(1, '');
    expect(draft.pageText, 'b' * 16384);
    draft.replacePage('');
    draft.move(-1, '');
    draft.replacePage('new first');
    draft.move(1, draft.pageText);
    expect(draft.pageText, isEmpty);
    draft.move(1, '');
    expect(draft.pageText, 'tail');
    expect(draft.fullText, 'new firsttail');
  });

  test('projection validates without committing pending input', () {
    final draft = TextValueDraft('${'a' * 16384}tail');
    final original = draft.fullText;
    expect(draft.projected('pending 😀'), 'pending 😀tail');
    expect(draft.fullWithPage('pending 😀'), 'pending 😀tail');
    expect(draft.fullText, original);
    expect(draft.pageIndex, 0);
    expect(draft.pageEnd, 16384);
  });

  test(
    'explicit append grows an initial small value and reuses an empty page',
    () {
      final draft = TextValueDraft('first');
      expect(draft.canAppendPage, isTrue);
      draft.appendPage('first changed');
      expect(draft.pageCount, 2);
      expect(draft.pageIndex, 1);
      expect(draft.pageText, isEmpty);
      expect(draft.canAppendPage, isFalse);
      draft.appendPage('');
      expect(draft.pageCount, 2);
      expect(draft.canAppend('second'), isTrue);
      draft.appendPage('second');
      expect(draft.pageCount, 3);
      draft.replacePage('third');
      expect(draft.fullText, 'first changedsecondthird');
      draft.move(-1, draft.pageText);
      expect(draft.pageText, 'second');
      draft.move(-1, draft.pageText);
      expect(draft.pageText, 'first changed');
    },
  );

  test('append remains bounded by whole-value admission', () {
    final full = TextValueDraft('a' * 262144);
    expect(full.canAppendPage, isFalse);
    expect(() => full.appendPage(full.pageText), throwsFormatException);
    expect(full.pageIndex, 0);
    expect(full.fullText, 'a' * 262144);
  });

  test(
    'explicit append repacks eighteen short pages without losing capacity',
    () {
      final draft = TextValueDraft('prefix😀');
      for (var index = 1; index < 17; index++) {
        draft.appendPage(draft.pageText);
        draft.replacePage('[$index漢]');
      }
      expect(draft.pageCount, 17);
      final seventeen = draft.fullText;
      draft.appendPage(draft.pageText);
      expect(draft.pageCount, 18);
      expect(draft.fullText, seventeen);
      draft.replacePage('eighteenth😀');
      final before = draft.fullText;
      expect(draft.canAppendPage, isTrue);
      expect(draft.canAppend('changed eighteenth😀'), isTrue);
      expect(draft.fullText, before);
      expect(draft.pageIndex, 17);
      draft.appendPage('changed eighteenth😀');
      expect(draft.fullText, '${seventeen}changed eighteenth😀');
      expect(draft.pageCount, 2);
      expect(draft.pageIndex, 1);
      expect(draft.pageText, isEmpty);
      draft.replacePage('tail');
      expect(draft.fullText, '${seventeen}changed eighteenth😀tail');
      draft.move(-1, draft.pageText);
      expect(draft.pageText, '${seventeen}changed eighteenth😀');
    },
  );

  test('deleting full pages keeps neighbours stable until explicit append', () {
    final original = '${'a' * 16383}😀${'漢' * (262144 - 16385)}';
    final draft = TextValueDraft(original);
    expect(draft.pageCount, 17);
    draft.replacePage('first');
    for (var index = 1; index < 16; index++) {
      draft.move(1, draft.pageText);
      draft.replacePage('');
      expect(draft.pageCount, 17);
      expect(draft.pageText, isEmpty);
    }
    draft.move(1, '');
    final suffix = draft.pageText;
    final before = draft.fullText;
    expect(before, 'first$suffix');
    draft.appendPage(suffix);
    expect(draft.pageCount, 18);
    expect(draft.fullText, before);
    draft.replacePage('new');
    expect(draft.pageCount, 18);
    expect(draft.canAppendPage, isTrue);
    draft.appendPage('new');
    expect(draft.fullText, '${before}new');
    expect(draft.pageCount, 2);
    draft.replacePage(' suffix😀');
    expect(draft.fullText, '${before}new suffix😀');
  });

  test('oversize page replacement and navigation are atomic failures', () {
    final draft = TextValueDraft('${'a' * 16384}tail');
    final original = draft.fullText;
    for (final edit in <void Function()>[
      () => draft.replacePage('x' * 16385),
      () => draft.projected('x' * 16385),
      () => draft.move(1, 'x' * 16385),
      () => draft.move(-1, 'changed'),
      () => draft.move(0, 'changed'),
      () => draft.move(2, 'changed'),
    ]) {
      expect(edit, throwsA(anyOf(isA<FormatException>(), isA<StateError>())));
      expect(draft.fullText, original);
      expect(draft.pageIndex, 0);
      expect(draft.pageEnd, 16384);
    }
  });

  test(
    'whole-value admission cannot be exceeded by filling a short Unicode page',
    () {
      final original = '${'a' * 16383}😀${'漢' * (262144 - 16385)}';
      final draft = TextValueDraft(original);
      expect(draft.fullText.length, 262144);
      expect(draft.pageText.length, 16383);
      expect(() => draft.replacePage('x' * 16384), throwsFormatException);
      expect(draft.fullText, original);
      expect(draft.pageIndex, 0);
      expect(() => TextValueDraft('x' * 262145), throwsFormatException);
      expect(TextValueDraft('漢' * 262144).fullText.length, 262144);
    },
  );

  test('malformed UTF16 never enters or replaces the exact draft', () {
    final draft = TextValueDraft('exact😀');
    for (final input in <String>[
      String.fromCharCode(0xd800),
      String.fromCharCode(0xdc00),
      '${String.fromCharCode(0xd800)}x',
    ]) {
      expect(() => TextValueDraft(input), throwsFormatException);
      expect(() => draft.replacePage(input), throwsFormatException);
      expect(() => draft.projected(input), throwsFormatException);
      expect(draft.fullText, 'exact😀');
    }
  });

  test(
    'empty value remains one bounded editable page without history growth',
    () {
      final draft = TextValueDraft('');
      expect(draft.pageCount, 1);
      expect(draft.pageText, isEmpty);
      expect(draft.hasPrevious, isFalse);
      expect(draft.hasNext, isFalse);
      for (var index = 0; index < 100; index++) {
        draft.replacePage('edit $index 😀');
      }
      expect(draft.fullText, 'edit 99 😀');
      expect(draft.pageCount, 1);
      expect(draft.estimatedBytes, lessThan(256));
    },
  );

  test(
    'read-only paging accepts larger scope and never splits surrogate pairs',
    () {
      final text = '${'x' * 16383}😀${'漢' * 1048576}';
      final parts = <String>[];
      for (var start = 0; start < text.length;) {
        final end = textValuePageEnd(text, start);
        expect(end - start, lessThanOrEqualTo(16384));
        parts.add(text.substring(start, end));
        start = end;
      }
      expect(parts.join(), text);
      expect(parts.first.length, 16383);
      expect(parts[1].startsWith('😀'), isTrue);
      expect(() => textValuePageEnd(text, 16384), throwsArgumentError);
      expect(() => textValuePageEnd(text, -1), throwsArgumentError);
      expect(() => textValuePageEnd(text, 0, maxUnits: 1), throwsArgumentError);
      expect(textValuePageEnd('', 0), 0);
    },
  );

  test(
    'dynamic native input cap rejects before text, selection or IME notification',
    () {
      var limit = 4, rejected = 0, notified = 0;
      final controller = BoundedTextController(
        text: 'abcd',
        maxUnits: 32768,
        limit: () => limit,
        maxUtf8Bytes: 49152,
        rejected: () => rejected++,
      );
      addTearDown(controller.dispose);
      controller.value = const TextEditingValue(
        text: 'abcd',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
        composing: TextRange(start: 1, end: 3),
      );
      controller.addListener(() => notified++);
      final before = controller.value;
      controller.value = const TextEditingValue(
        text: 'rejected oversized paste',
        selection: TextSelection.collapsed(offset: 24),
      );
      expect(controller.value, before);
      expect(notified, 0);
      expect(rejected, 1);
      limit = 32768;
      controller.text = '00' * 16384;
      expect(controller.text.length, 32768);
      expect(notified, 1);
      expect(rejected, 1);
    },
  );

  test(
    'native UTF8 cap accepts exact boundary and rejects without shortening',
    () {
      var rejected = 0;
      final controller = BoundedTextController(
        maxUnits: 32768,
        maxUtf8Bytes: 49152,
        rejected: () => rejected++,
      );
      addTearDown(controller.dispose);
      controller.text = '漢' * 16384;
      expect(utf8.encode(controller.text).length, 49152);
      final accepted = controller.value;
      controller.text = '${controller.text}x';
      expect(controller.value, accepted);
      expect(rejected, 1);
      expect(
        () => BoundedTextController(text: '漢', maxUnits: 16, maxUtf8Bytes: 2),
        throwsArgumentError,
      );
      expect(
        () => BoundedTextController(text: 'abc', maxUnits: 8, limit: () => 2),
        throwsArgumentError,
      );
    },
  );

  test(
    'controller rejects malformed UTF16 before exposing text or IME state',
    () {
      var rejected = 0, notified = 0;
      final controller = BoundedTextController(
        text: 'safe',
        maxUnits: 16,
        maxUtf8Bytes: 32,
        rejected: () => rejected++,
      );
      addTearDown(controller.dispose);
      controller.value = const TextEditingValue(
        text: 'safe',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
        composing: TextRange(start: 1, end: 3),
      );
      controller.addListener(() => notified++);
      final before = controller.value;
      final high = String.fromCharCode(0xd800);
      final low = String.fromCharCode(0xdc00);
      for (final malformed in <String>[
        high,
        low,
        'x$high',
        '${high}x',
        '$high$high',
        '😀$low',
      ]) {
        controller.value = TextEditingValue(
          text: malformed,
          selection: TextSelection.collapsed(offset: malformed.length),
          composing: TextRange(start: 0, end: malformed.length),
        );
        expect(controller.value, before);
        expect(notified, 0);
      }
      expect(rejected, 6);
      controller.value = const TextEditingValue(
        text: 'a😀z',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 1, end: 3),
      );
      expect(controller.text, 'a😀z');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
      expect(controller.value.composing, const TextRange(start: 1, end: 3));
      expect(notified, 1);
      expect(rejected, 6);
      expect(
        () => BoundedTextController(text: high, maxUnits: 16),
        throwsArgumentError,
      );
    },
  );

  test(
    'controller rejects native NUL without changing retained editing state',
    () {
      var rejected = 0, notified = 0;
      final controller = BoundedTextController(
        text: 'safe',
        maxUnits: 16,
        rejected: () => rejected++,
      );
      addTearDown(controller.dispose);
      controller.value = const TextEditingValue(
        text: 'safe',
        selection: TextSelection(baseOffset: 1, extentOffset: 3),
        composing: TextRange(start: 1, end: 3),
      );
      controller.addListener(() => notified++);
      final before = controller.value;
      for (final text in ['\u0000', 'prefix\u0000', 'a\u0000b']) {
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        expect(controller.value, before);
        expect(notified, 0);
      }
      expect(rejected, 3);
      controller.text = 'ordinary 0';
      expect(controller.text, 'ordinary 0');
      expect(notified, 1);
      expect(TextValueDraft('a\u0000b').fullText, 'a\u0000b');
      expect(
        () => BoundedTextController(text: 'a\u0000b', maxUnits: 16),
        throwsArgumentError,
      );
    },
  );
}
