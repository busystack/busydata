import 'dart:convert';
import '../../backend/generated/busydata.pb.dart' as rpc;
import 'temporal_display.dart';
import 'complete_value.dart';
export 'temporal_display.dart';

enum ResultPresentation { table, transpose, tree, text }

enum ResultTextScope { selection, window }

enum ColumnDisplayFormat {
  canonical,
  grouped,
  decimal2,
  decimal4,
  isoDate,
  isoTime,
  utc,
  local,
  json,
  hexadecimal,
  base64,
  uuid,
  wrap,
  temporalPattern,
}

/// Flutter-only presentation state. Retained rows, local-view mappings and staged
/// assignments remain with their existing owners; changing a view copies none.
class ResultPresentationState {
  ResultPresentation mode = ResultPresentation.table;
  ResultTextScope textScope = ResultTextScope.selection;
  String extractor = 'text';
  bool recordVisible = false;
  final formats = <int, ColumnDisplayFormat>{};
  final temporalPatterns = <int, TemporalDisplayPattern>{};
  final expanded = <String>{};
  final _drafts = <String, ({String text, String format})>{};
  final _binaryDrafts = <String, BinaryDraftSnapshot>{};
  BinaryDraftSnapshot? binaryDraft(int row, int ordinal) =>
      _binaryDrafts['$row:$ordinal'];

  String? draft(int row, int ordinal) => _drafts['$row:$ordinal']?.text;
  String? draftFormat(int row, int ordinal) => _drafts['$row:$ordinal']?.format;
  void retainDraft(int row, int ordinal, String text, [String format = 'raw']) {
    final key = '$row:$ordinal';
    if (text.length > 262144 ||
        (!_drafts.containsKey(key) &&
            !_binaryDrafts.containsKey(key) &&
            _drafts.length + _binaryDrafts.length >= 16) ||
        _binaryDrafts.entries
                    .where((entry) => entry.key != key)
                    .fold(0, (sum, entry) => sum + entry.value.estimatedBytes) +
                _drafts.entries
                    .where((entry) => entry.key != key)
                    .fold(
                      0,
                      (sum, entry) => sum + entry.value.text.length * 2,
                    ) +
                text.length * 2 >
            2097152 ||
        _drafts.entries.fold<int>(
                  0,
                  (n, e) => n + (e.key == key ? 0 : e.value.text.length),
                ) +
                text.length >
            524288) {
      throw StateError('VALUE_DRAFT_LIMIT');
    }
    _binaryDrafts.remove(key);
    _drafts[key] = (text: text, format: format);
  }

  void retainBinaryDraft(int row, int ordinal, BinaryDraftSnapshot draft) {
    final key = '$row:$ordinal';
    final bytes =
        _drafts.entries
            .where((entry) => entry.key != key)
            .fold(0, (sum, entry) => sum + entry.value.text.length * 2) +
        _binaryDrafts.entries
            .where((entry) => entry.key != key)
            .fold(0, (sum, entry) => sum + entry.value.estimatedBytes) +
        draft.estimatedBytes;
    if (bytes > 2097152 ||
        !_binaryDrafts.containsKey(key) &&
            !_drafts.containsKey(key) &&
            _binaryDrafts.length + _drafts.length >= 16) {
      throw StateError('VALUE_DRAFT_LIMIT');
    }
    _drafts.remove(key);
    _binaryDrafts[key] = draft;
  }

  void clearDraft(int row, int ordinal) {
    final key = '$row:$ordinal';
    _drafts.remove(key);
    _binaryDrafts.remove(key);
  }
}

/// Only Java's captured physical-column identity can own durable preferences.
/// Unknown expressions and names-only provenance keep transient view settings.
String? resultColumnPreferenceKey(String? profileId, rpc.Column column) =>
    profileId == null ||
        profileId.isEmpty ||
        !column.provenanceKnown ||
        column.metadataIdentity.isEmpty ||
        column.metadataSnapshotRevision.toInt() <= 0
    ? null
    : jsonEncode([profileId, column.metadataIdentity]);

bool validResultDisplayFormat(String stored) =>
    ColumnDisplayFormat.values.any(
      (value) =>
          value != ColumnDisplayFormat.temporalPattern && value.name == stored,
    ) ||
    TemporalDisplayPattern.parse(stored) != null;

String groupExactNumber(String source) {
  final match = RegExp(
    r'^([+-]?)([0-9]+)(\.[0-9]+)?([eE][+-]?[0-9]+)?$',
  ).firstMatch(source);
  if (match == null) return source;
  final digits = match[2]!;
  final buffer = StringBuffer(match[1]!);
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '$buffer${match[3] ?? ''}${match[4] ?? ''}';
}

/// Display-only half-away-from-zero rounding over exact decimal digits.
String fixedDecimalDisplay(String source, int scale) {
  final match = RegExp(r'^([+-]?)([0-9]+)(?:\.([0-9]+))?$').firstMatch(source);
  if (match == null || scale < 0 || scale > 12) return source;
  final fraction = match[3] ?? '';
  final retained = fraction.padRight(scale, '0').substring(0, scale);
  var coefficient = BigInt.parse('${match[2]}$retained');
  if (fraction.length > scale && fraction.codeUnitAt(scale) >= 53) {
    coefficient += BigInt.one;
  }
  final digits = coefficient.toString().padLeft(scale + 1, '0');
  final absolute = scale == 0
      ? digits
      : '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}';
  return groupExactNumber(
    '${match[1] == '-' && coefficient != BigInt.zero ? '-' : ''}$absolute',
  );
}

/// An explicit ISO offset establishes an instant. A timezone-less database value
/// remains raw; presentation does not assign it a physical timezone.
String temporalDisplay(rpc.Temporal temporal, ColumnDisplayFormat format) {
  final iso = temporal.iso;
  if (format == ColumnDisplayFormat.isoDate) {
    final date = RegExp(r'^[+-]?[0-9]{4,}-[0-9]{2}-[0-9]{2}').firstMatch(iso);
    return date?[0] ?? iso;
  }
  if (format == ColumnDisplayFormat.isoTime) {
    final at = iso.indexOf('T');
    return at < 0 ? iso : iso.substring(at + 1);
  }
  if (!RegExp(r'T.*(?:Z|[+-][0-9]{2}:[0-9]{2})$').hasMatch(iso)) return iso;
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return (format == ColumnDisplayFormat.utc ? date.toUtc() : date.toLocal())
      .toIso8601String();
}
