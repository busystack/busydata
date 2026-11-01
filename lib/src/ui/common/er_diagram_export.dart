import 'dart:typed_data';
import 'dart:ui' as image_ui;
import 'package:flutter/widgets.dart';
import '../../backend/generated/busydata.pb.dart' as rpc;

/// Exports the complete foreign-key graph rather than a screenshot of its viewport.
Future<Uint8List> renderErDiagramPng({
  required List<rpc.SchemaObject> tables,
  required List<rpc.SchemaObject> edges,
  required String notes,
  required Color foreground,
  required Color background,
  required TextStyle style,
  required TextDirection direction,
}) async {
  final height = (tables.length / 4).ceil() * 110.0 + 180;
  if (height > 8192 || 850 * height * 4 > 16000000) {
    throw StateError(
      'Diagram exceeds the PNG size limit. Export SVG for this schema.',
    );
  }
  Offset position(String name) {
    final i = tables.indexWhere((table) => table.name == name);
    return Offset((i % 4) * 210.0 + 15, (i ~/ 4) * 110.0 + 15);
  }

  final recorder = image_ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(2);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, 850, height),
    Paint()..color = background,
  );
  final names = tables.map((table) => table.name).toSet();
  for (final edge in edges) {
    final referenced = edge.properties['referencedTable'];
    if (!names.contains(edge.table) || !names.contains(referenced)) continue;
    canvas.drawLine(
      position(edge.table) + const Offset(90, 30),
      position(referenced!) + const Offset(90, 30),
      Paint()
        ..color = foreground
        ..strokeWidth = 1.5,
    );
  }
  void label(String text, Offset point, double width, {int maxLines = 2}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(color: foreground, fontSize: 14),
      ),
      textDirection: direction,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: width);
    painter.paint(canvas, point);
    painter.dispose();
  }

  for (final table in tables) {
    final point = position(table.name),
        rect = Rect.fromLTWH(
          position(table.name).dx,
          position(table.name).dy,
          180,
          60,
        );
    // Match an inside Flutter Border rather than a centered canvas stroke.
    canvas.drawRect(rect, Paint()..color = foreground);
    canvas.drawRect(rect.deflate(1), Paint()..color = background);
    label(table.name, point + const Offset(8, 10), 164);
  }
  label(notes, Offset(15, height - 145), 820, maxLines: 6);
  final picture = recorder.endRecording();
  try {
    final rendered = await picture.toImage(1700, (height * 2).ceil());
    try {
      final data = await rendered.toByteData(
        format: image_ui.ImageByteFormat.png,
      );
      if (data == null) throw StateError('PNG encoding failed');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      rendered.dispose();
    }
  } finally {
    picture.dispose();
  }
}
