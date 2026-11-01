import 'dart:convert';

enum JsonValueKind { object, array, scalar }

class JsonValueNode {
  JsonValueNode(this.kind, this.start, this.end, this.children);
  final JsonValueKind kind;
  final int start, end;
  final List<({String name, JsonValueNode node})> children;
  bool get branch => kind != JsonValueKind.scalar;
}

/// A bounded display parser. Numeric tokens remain source slices and never pass
/// through Dart doubles. Duplicate object keys remain visible in source order.
class StructuredJson {
  StructuredJson._(this.source, this.root);
  final String source;
  final JsonValueNode root;
  static StructuredJson parse(String source) {
    if (source.length > 262144) throw const FormatException('JSON_SIZE_LIMIT');
    final reader = _JsonReader(source);
    final root = reader.value(0);
    reader.space();
    if (reader.position != source.length) reader.fail();
    return StructuredJson._(source, root);
  }

  String raw(JsonValueNode node) => source.substring(node.start, node.end);
  String pretty() {
    final output = StringBuffer();
    void write(JsonValueNode node, int depth) {
      if (!node.branch) {
        output.write(raw(node));
        return;
      }
      final object = node.kind == JsonValueKind.object;
      output.write(object ? '{' : '[');
      for (var i = 0; i < node.children.length; i++) {
        if (i > 0) output.write(',');
        output.write('\n${'  ' * (depth + 1)}');
        final child = node.children[i];
        if (object) output.write('${jsonEncode(child.name)}: ');
        write(child.node, depth + 1);
      }
      if (node.children.isNotEmpty) output.write('\n${'  ' * depth}');
      output.write(object ? '}' : ']');
    }

    write(root, 0);
    return output.toString();
  }
}

class _JsonReader {
  _JsonReader(this.source);
  final String source;
  int position = 0, nodes = 0;
  Never fail() => throw FormatException('JSON_PARSE_ERROR', null, position);
  void space() {
    while (position < source.length &&
        const [9, 10, 13, 32].contains(source.codeUnitAt(position))) {
      position++;
    }
  }

  bool take(String char) {
    space();
    if (position < source.length && source[position] == char) {
      position++;
      return true;
    }
    return false;
  }

  String string() {
    space();
    if (position >= source.length || source[position] != '"') fail();
    final start = position++;
    var escaped = false;
    while (position < source.length) {
      final unit = source.codeUnitAt(position++);
      if (unit < 32) fail();
      if (escaped) {
        if (unit == 117) {
          if (position + 4 > source.length ||
              !RegExp(
                r'^[0-9a-fA-F]{4}$',
              ).hasMatch(source.substring(position, position + 4))) {
            fail();
          }
          position += 4;
        } else if (!const [34, 92, 47, 98, 102, 110, 114, 116].contains(unit)) {
          fail();
        }
        escaped = false;
      } else if (unit == 92) {
        escaped = true;
      } else if (unit == 34) {
        return jsonDecode(source.substring(start, position)) as String;
      }
    }
    fail();
  }

  JsonValueNode value(int depth) {
    space();
    if (++nodes > 4096 || depth > 32) {
      throw const FormatException('JSON_STRUCTURE_LIMIT');
    }
    if (position >= source.length) fail();
    final start = position;
    final first = source[position];
    final children = <({String name, JsonValueNode node})>[];
    if (first == '{' || first == '[') {
      final object = first == '{';
      position++;
      final end = object ? '}' : ']';
      if (!take(end)) {
        do {
          final name = object ? string() : '${children.length}';
          if (object && !take(':')) fail();
          children.add((name: name, node: value(depth + 1)));
        } while (take(','));
        if (!take(end)) fail();
      }
      return JsonValueNode(
        object ? JsonValueKind.object : JsonValueKind.array,
        start,
        position,
        List.unmodifiable(children),
      );
    }
    if (first == '"') {
      string();
    } else {
      final token = RegExp(
        r'-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?|true|false|null',
      ).matchAsPrefix(source, position);
      if (token == null) fail();
      position = token.end;
    }
    return JsonValueNode(JsonValueKind.scalar, start, position, const []);
  }
}

/// XML interpretation is display-only and deliberately refuses DTD/entity
/// declarations. It never resolves resources or changes the retained raw value.
String formatXmlDisplay(String source) {
  if (source.length > 262144 ||
      source.contains('<!DOCTYPE') ||
      source.contains('<!ENTITY')) {
    throw const FormatException('XML_STRUCTURE_LIMIT');
  }
  final tags = RegExp(
    r'<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<\?[\s\S]*?\?>|</?[A-Za-z_][^<>]*?>',
  );
  final stack = <String>[];
  final output = StringBuffer();
  var offset = 0, count = 0;
  for (final match in tags.allMatches(source)) {
    if (++count > 4096) throw const FormatException('XML_STRUCTURE_LIMIT');
    final between = source.substring(offset, match.start);
    if (between.contains('<')) throw const FormatException('XML_PARSE_ERROR');
    if (between.trim().isNotEmpty) output.write(between);
    final tag = match[0]!;
    final closing = tag.startsWith('</');
    final special = tag.startsWith('<!') || tag.startsWith('<?');
    final name = special ? '' : RegExp(r'^</?([^\s/>]+)').firstMatch(tag)![1]!;
    if (closing) {
      if (stack.isEmpty || stack.removeLast() != name) {
        throw const FormatException('XML_PARSE_ERROR');
      }
    }
    if (between.trim().isEmpty && output.isNotEmpty) {
      output.write('\n${'  ' * stack.length}');
    }
    output.write(tag);
    if (!special && !closing && !tag.endsWith('/>')) stack.add(name);
    if (stack.length > 32) throw const FormatException('XML_STRUCTURE_LIMIT');
    offset = match.end;
  }
  final remainder = source.substring(offset);
  if (stack.isNotEmpty || remainder.contains('<') || count == 0) {
    throw const FormatException('XML_PARSE_ERROR');
  }
  output.write(remainder);
  return output.toString();
}
