import 'dart:convert';
import '../../backend/generated/busydata.pb.dart' as rpc;

String valueText(rpc.Value value) {
  final result = switch (value.whichData()) {
    rpc.Value_Data.nullValue => 'NULL',
    rpc.Value_Data.boolean => '${value.boolean}',
    rpc.Value_Data.signedInteger => value.signedInteger,
    rpc.Value_Data.unsignedInteger => value.unsignedInteger,
    rpc.Value_Data.decimal => value.decimal,
    rpc.Value_Data.real => '${value.real}',
    rpc.Value_Data.text => value.text,
    rpc.Value_Data.binary =>
      value.binary.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    rpc.Value_Data.temporal => value.temporal.iso,
    rpc.Value_Data.json => value.json,
    rpc.Value_Data.engineValue => value.engineValue.text,
    rpc.Value_Data.array => '[${value.array.values.map(valueText).join(', ')}]',
    rpc.Value_Data.notSet => '',
  };
  return value.truncated ? '$result … [preview only]' : result;
}

const resultClipboardByteLimit = 1048576;

/// Filter operands use retained JDBC types and exact scalar representations.
/// SQL values and identifiers remain technical text, never translated labels.
rpc.Value retainedFilterValue(rpc.Column column, String input) {
  if (input.length > 8192) {
    throw const FormatException('Filter operands support at most 8KiB of text');
  }
  if (const [-6, 5, 4, -5, 2, 3, 6, 7, 8].contains(column.jdbcType)) {
    return rpc.Value(decimal: input);
  }
  if (column.jdbcType == 16 ||
      (column.jdbcType == -7 && column.precision <= 1)) {
    if (input != 'true' && input != 'false') {
      throw const FormatException('Boolean operands must be true or false');
    }
    return rpc.Value(boolean: input == 'true');
  }
  if (const [-2, -3, -4, 2004].contains(column.jdbcType) ||
      column.jdbcType == -7) {
    if (input.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(input)) {
      throw const FormatException('Binary operands require complete hex bytes');
    }
    return rpc.Value(
      binary: [
        for (var i = 0; i < input.length; i += 2)
          int.parse(input.substring(i, i + 2), radix: 16),
      ],
    );
  }
  if (const [91, 92, 93, 2013, 2014].contains(column.jdbcType)) {
    return rpc.Value(temporal: rpc.Temporal(iso: input));
  }
  if (const ['json', 'jsonb'].contains(column.typeName.toLowerCase())) {
    return rpc.Value(json: input);
  }
  if (const [1111, 2003, 2002, 2006].contains(column.jdbcType)) {
    throw const FormatException(
      'This retained type has no exact comparison contract',
    );
  }
  return rpc.Value(text: input);
}

class ResultCopyBuffer {
  ResultCopyBuffer({this.limit = resultClipboardByteLimit});
  final int limit;
  final text = StringBuffer();
  int bytes = 0;
  int get remaining => limit - bytes;
  void requireBytes(int additional) {
    if (additional > remaining) {
      throw StateError(
        'Copy exceeds 1MiB of UTF-8; export retained data instead',
      );
    }
  }

  void append(String value) {
    account(value);
    text.write(value);
  }

  void account(String value) {
    if (value.length > remaining) requireBytes(value.length);
    var size = 0;
    for (final rune in value.runes) {
      size += rune <= 0x7f
          ? 1
          : rune <= 0x7ff
          ? 2
          : rune <= 0xffff
          ? 3
          : 4;
      requireBytes(size);
    }
    bytes += size;
  }
}

void _copyValue(rpc.Value value, ResultCopyBuffer output, [int depth = 0]) {
  if (depth > 16) throw StateError('Copy array nesting exceeds 16 levels');
  if (value.hasArray()) {
    if (value.array.values.length > 1024) {
      throw StateError(
        'Copy array exceeds 1,024 elements; export the full value',
      );
    }
    output.append('[');
    for (var index = 0; index < value.array.values.length; index++) {
      if (index > 0) output.append(', ');
      _copyValue(value.array.values[index], output, depth + 1);
    }
    output.append(']');
  } else if (value.hasBinary()) {
    output.requireBytes(value.binary.length * 2);
    for (final byte in value.binary) {
      output.append(byte.toRadixString(16).padLeft(2, '0'));
    }
  } else {
    // Reuse the display representation while bounding its source before any
    // quoting/JSON expansion. Arrays and binary take the bounded paths above.
    final plain = value.deepCopy()..truncated = false;
    output.append(valueText(plain));
  }
  if (value.truncated) output.append(' … [preview only]');
}

/// Serialize fetched cells only, never execute SQL or retrieve full values.
/// Admission includes UTF-8, delimiters, quoting and JSON escaping before
/// constructing each encoded string or the complete clipboard payload.
String copyFetchedValues(List<List<rpc.Value>> rows, String format) {
  if (!const ['text', 'csv', 'json'].contains(format)) {
    throw ArgumentError('Choose text, CSV or JSON for fetched-data copy');
  }
  final output = ResultCopyBuffer();
  if (format == 'json') output.append('[');
  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
    if (rowIndex > 0) output.append(format == 'json' ? ',' : '\n');
    if (format == 'json') output.append('[');
    for (var column = 0; column < rows[rowIndex].length; column++) {
      if (column > 0) output.append(format == 'text' ? '\t' : ',');
      final value = rows[rowIndex][column];
      if (format == 'csv' && value.hasNullValue()) {
        output.append(r'\N');
        continue;
      }
      if (format == 'json' && (value.hasNullValue() || value.hasBoolean())) {
        output.append(value.hasNullValue() ? 'null' : '${value.boolean}');
        continue;
      }
      final cell = ResultCopyBuffer(limit: output.remaining);
      _copyValue(value, cell);
      final text = cell.text.toString();
      if (format == 'csv') {
        var quotes = 0;
        for (var index = 0; index < text.length; index++) {
          if (text.codeUnitAt(index) == 34) quotes++;
        }
        output.requireBytes(cell.bytes + quotes + 2);
        output.append('"${text.replaceAll('"', '""')}"');
      } else if (format == 'json') {
        var escapedBytes = 2;
        for (final rune in text.runes) {
          escapedBytes +=
              rune == 34 ||
                  rune == 92 ||
                  const [8, 9, 10, 12, 13].contains(rune)
              ? 2
              : rune < 32
              ? 6
              : rune <= 0x7f
              ? 1
              : rune <= 0x7ff
              ? 2
              : rune <= 0xffff
              ? 3
              : 4;
          output.requireBytes(escapedBytes);
        }
        output.append(jsonEncode(text));
      } else {
        output.append(text);
      }
    }
    if (format == 'json') output.append(']');
  }
  if (format == 'json') output.append(']');
  return output.text.toString();
}

/// Split only backend-generated SQL VALUES tuples. Quoted commas, escaped
/// quotes and nested dialect expressions remain exact; no SQL is executed.
List<String> splitGeneratedSqlCopyRows(String text) {
  final rows = <String>[];
  var depth = 0, start = -1;
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final unit = text.codeUnitAt(i);
    if (quoted) {
      if (unit == 92) {
        i++;
      } else if (unit == 39) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 39) {
          i++;
        } else {
          quoted = false;
        }
      }
    } else if (unit == 39 && depth > 0) {
      quoted = true;
    } else if (unit == 40) {
      if (depth++ == 0) start = i + 1;
    } else if (unit == 41 && depth > 0) {
      if (--depth == 0) rows.add(text.substring(start, i));
    } else if (depth == 0 && ![9, 10, 13, 32, 44].contains(unit)) {
      throw const FormatException('Invalid generated SQL tuple');
    }
  }
  if (depth != 0 || quoted || rows.isEmpty || rows.length > 10000) {
    throw const FormatException('Incomplete generated SQL tuples');
  }
  return rows;
}
