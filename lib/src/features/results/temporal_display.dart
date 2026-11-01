import 'dart:convert';
import 'dart:async' show unawaited;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;

enum TemporalDisplayZone { source, utc, local }

/// Display-only ICU calendar fields. Database values and comparisons stay exact.
class TemporalDisplayPattern {
  static bool _symbolsInitialized = false;
  TemporalDisplayPattern(
    this.pattern, [
    this.zone = TemporalDisplayZone.source,
  ]) {
    _tokens(pattern); // Validate before persisting or building a formatter.
  }
  final String pattern;
  final TemporalDisplayZone zone;
  String get stored => 'temporalPattern:${jsonEncode([pattern, zone.name])}';
  static TemporalDisplayPattern? parse(String stored) {
    if (!stored.startsWith('temporalPattern:') || stored.length > 1024) {
      return null;
    }
    try {
      final decoded = jsonDecode(stored.substring(16));
      if (decoded is! List || decoded.length != 2 || decoded[0] is! String) {
        return null;
      }
      final zone = TemporalDisplayZone.values
          .where((value) => value.name == decoded[1])
          .firstOrNull;
      return zone == null
          ? null
          : TemporalDisplayPattern(decoded[0] as String, zone);
    } on FormatException {
      return null;
    }
  }

  String? format(rpc.Temporal temporal, String locale) {
    // Pinned local intl data registers all symbols synchronously, then returns
    // an already completed acknowledgement; no file/network lookup occurs.
    if (!_symbolsInitialized) {
      unawaited(initializeDateFormatting());
      _symbolsInitialized = true;
    }
    final source = temporal.iso;
    final match = RegExp(
      r'^(?:(\d{4})-(\d{2})-(\d{2})(?:[T ])?)?(?:(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?)?(Z|[+-]\d{2}:\d{2})?$',
    ).firstMatch(source);
    if (match == null || source.isEmpty) return null;
    final hasDate = match[1] != null, hasTime = match[4] != null;
    if (!hasDate && !hasTime ||
        !hasTime && (source.endsWith('T') || source.endsWith(' '))) {
      return null;
    }
    final tokens = _tokens(pattern);
    if (!hasDate &&
            tokens.any(
              (token) => token.field && 'GyMLdcEDQ'.contains(token.text[0]),
            ) ||
        !hasTime &&
            tokens.any(
              (token) => token.field && 'hHmsSakK'.contains(token.text[0]),
            )) {
      return null;
    }
    int component(int index, int fallback) =>
        match[index] == null ? fallback : int.parse(match[index]!);
    final year = component(1, 1970),
        month = component(2, 1),
        day = component(3, 1),
        hour = component(4, 0),
        minute = component(5, 0),
        second = component(6, 0);
    final micros = int.parse((match[7] ?? '').padRight(6, '0'));
    var date = DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
      micros ~/ 1000,
      micros % 1000,
    );
    if (date.year != year ||
        date.month != month ||
        date.day != day ||
        date.hour != hour ||
        date.minute != minute ||
        date.second != second) {
      return null;
    }
    final offset = match[8];
    if (zone != TemporalDisplayZone.source) {
      if (offset == null || zone == TemporalDisplayZone.local && !hasDate) {
        return null;
      }
      if (offset != 'Z') {
        final hours = int.parse(offset.substring(1, 3)),
            minutes = int.parse(offset.substring(4));
        if (hours > 23 || minutes > 59) return null;
        final displacement = Duration(
          minutes: (hours * 60 + minutes) * (offset.startsWith('-') ? -1 : 1),
        );
        date = date.subtract(displacement);
      }
      if (zone == TemporalDisplayZone.local) date = date.toLocal();
    }
    // intl's S uses milliseconds; substitute our exact six retained digits.
    final fraction =
        '${date.millisecond.toString().padLeft(3, '0')}${date.microsecond.toString().padLeft(3, '0')}';
    final resolved = tokens
        .map(
          (token) => token.field && token.text[0] == 'S'
              ? fraction.substring(0, token.text.length)
              : token.text,
        )
        .join();
    try {
      final result = DateFormat(
        resolved,
        Intl.canonicalizedLocale(locale),
      ).format(date);
      return result.length <= 1024 ? result : null;
    } catch (_) {
      return null;
    }
  }

  static List<({String text, bool field})> _tokens(String pattern) {
    if (pattern.isEmpty ||
        pattern.length > 128 ||
        utf8.encode(pattern).length > 512 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(pattern)) {
      throw const FormatException('TEMPORAL_PATTERN_INVALID');
    }
    final result = <({String text, bool field})>[];
    for (var index = 0; index < pattern.length;) {
      final start = index, character = pattern[index++];
      if (character == "'") {
        var closed = false;
        while (index < pattern.length) {
          if (pattern[index++] != "'") continue;
          if (index < pattern.length && pattern[index] == "'") {
            index++;
            continue;
          }
          closed = true;
          break;
        }
        if (!closed) throw const FormatException('TEMPORAL_PATTERN_INVALID');
        result.add((text: pattern.substring(start, index), field: false));
      } else if (RegExp('[A-Za-z]').hasMatch(character)) {
        if (!'GyMLdchHmsSEDakKQ'.contains(character)) {
          throw const FormatException('TEMPORAL_PATTERN_UNSUPPORTED');
        }
        while (index < pattern.length && pattern[index] == character) {
          index++;
        }
        if (character == 'S' && index - start > 6) {
          throw const FormatException('TEMPORAL_PATTERN_UNSUPPORTED');
        }
        result.add((text: pattern.substring(start, index), field: true));
      } else {
        result.add((text: character, field: false));
      }
    }
    return result;
  }
}
