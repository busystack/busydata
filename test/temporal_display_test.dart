import 'package:busydata/src/backend/generated/busydata.pb.dart' as rpc;
import 'package:busydata/src/features/results/result_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('custom calendar pattern preserves microseconds and original bytes', () {
    final value = rpc.Temporal(iso: '2026-10-24T15:07:09.123456+02:00');
    final bytes = value.writeToBuffer();
    expect(
      TemporalDisplayPattern(
        "dd/MM/yyyy 'at' HH:mm:ss.SSSSSS",
      ).format(value, 'en_US'),
      '24/10/2026 at 15:07:09.123456',
    );
    expect(
      TemporalDisplayPattern(
        'yyyy-MM-dd HH:mm:ss.SSSSSS',
        TemporalDisplayZone.utc,
      ).format(value, 'en_US'),
      '2026-10-24 13:07:09.123456',
    );
    expect(value.writeToBuffer(), orderedEquals(bytes));
  });
  test(
    'fractional widths and quoted literals follow exact retained digits',
    () {
      final value = rpc.Temporal(iso: '2026-01-02T03:04:05.987654');
      expect(
        TemporalDisplayPattern(
          "'fraction='S SS SSS SSSSSS",
        ).format(value, 'en_US'),
        'fraction=9 98 987 987654',
      );
      expect(
        TemporalDisplayPattern("HH 'o''clock'").format(value, 'en_US'),
        "03 o'clock",
      );
    },
  );
  test(
    'localized calendar names are available before History or another date widget opens',
    () {
      final value = rpc.Temporal(iso: '2026-10-24');
      expect(
        TemporalDisplayPattern('d. MMMM yyyy').format(value, 'de_DE'),
        '24. Oktober 2026',
      );
      expect(TemporalDisplayPattern('MMMM').format(value, 'ar'), 'أكتوبر');
    },
  );
  test('display timezone conversion requires an explicit offset', () {
    final local = rpc.Temporal(iso: '2026-10-24T15:07:09.000001');
    expect(
      TemporalDisplayPattern(
        'HH:mm:ss.SSSSSS',
        TemporalDisplayZone.utc,
      ).format(local, 'en_US'),
      isNull,
    );
    expect(
      TemporalDisplayPattern(
        'yyyy-MM-dd',
      ).format(rpc.Temporal(iso: '2026-10-24'), 'en_US'),
      '2026-10-24',
    );
    expect(
      TemporalDisplayPattern(
        'HH:mm:ss.SSSSSS',
      ).format(rpc.Temporal(iso: '12:00:00.000001'), 'en_US'),
      '12:00:00.000001',
    );
    expect(
      TemporalDisplayPattern(
        'yyyy-MM-dd',
      ).format(rpc.Temporal(iso: '12:00:00'), 'en_US'),
      isNull,
    );
  });
  test(
    'overflow, durations, infinity and missing fields remain unavailable',
    () {
      for (final source in [
        '2026-02-30T00:00:00',
        '2026-01-01T24:00:00',
        '-25:00:00',
        'infinity',
        '2026-01-01T',
      ]) {
        expect(
          TemporalDisplayPattern(
            'yyyy-MM-dd HH:mm:ss',
          ).format(rpc.Temporal(iso: source), 'en_US'),
          isNull,
          reason: source,
        );
      }
    },
  );
  test(
    'patterns have bounded explicit syntax and exact persistent encoding',
    () {
      for (final invalid in [
        '',
        'y' * 129,
        "yyyy 'unterminated",
        'yyyy z',
        'yyyy Z',
        'yyyy v',
        'HH:mm:ss.SSSSSSS',
        'yyyy\nMM',
      ]) {
        expect(() => TemporalDisplayPattern(invalid), throwsFormatException);
      }
      final pattern = TemporalDisplayPattern(
        "yyyy-MM-dd 'quoted' HH:mm:ss.SSSSSS",
        TemporalDisplayZone.local,
      );
      final restored = TemporalDisplayPattern.parse(pattern.stored)!;
      expect(restored.pattern, pattern.pattern);
      expect(restored.zone, TemporalDisplayZone.local);
      expect(validResultDisplayFormat(pattern.stored), isTrue);
      expect(
        TemporalDisplayPattern.parse('temporalPattern:["yyyy","forged"]'),
        isNull,
      );
      expect(
        TemporalDisplayPattern.parse('temporalPattern:["yyyy z","source"]'),
        isNull,
      );
    },
  );
}
