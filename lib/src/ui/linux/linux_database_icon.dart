import 'package:flutter/widgets.dart';
import '../../app/busydata_surface_colors.dart';
import '../common/desktop_controls.dart';

/// Original BusyData symbolic artwork for database roles absent from Yaru 10.2.
/// Uses the same monochrome 16-unit grid and rounded strokes as native glyphs.
class LinuxDatabaseIcon extends StatelessWidget {
  const LinuxDatabaseIcon(this.kind, {super.key, this.size = 16});
  final DesktopIcon kind;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _DatabaseIconPainter(
          kind,
          IconTheme.of(context).color ??
              BusyDataSurfaceColors.of(context).foreground,
        ),
      ),
    ),
  );
}

class _DatabaseIconPainter extends CustomPainter {
  const _DatabaseIconPainter(this.kind, this.color);
  final DesktopIcon kind;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 16, size.height / 16);
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (kind == DesktopIcon.routine) {
      canvas.drawPath(
        Path()
          ..moveTo(5, 3)
          ..lineTo(2, 8)
          ..lineTo(5, 13)
          ..moveTo(11, 3)
          ..lineTo(14, 8)
          ..lineTo(11, 13)
          ..moveTo(9, 4)
          ..lineTo(7, 12),
        pen,
      );
      return;
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(1.5, 2, 13, 12),
        const Radius.circular(1.5),
      ),
      pen,
    );
    canvas.drawLine(const Offset(1.5, 6), const Offset(14.5, 6), pen);
    if (kind == DesktopIcon.view) {
      canvas.drawOval(const Rect.fromLTWH(4, 8, 8, 4), pen);
      canvas.drawCircle(const Offset(8, 10), 1, pen);
    } else {
      canvas.drawLine(const Offset(6, 6), const Offset(6, 14), pen);
      canvas.drawLine(const Offset(10, 6), const Offset(10, 14), pen);
      if (kind == DesktopIcon.column) {
        canvas.drawRect(
          const Rect.fromLTWH(6, 6, 4, 8),
          Paint()..color = color,
        );
      } else {
        canvas.drawLine(const Offset(1.5, 10), const Offset(14.5, 10), pen);
      }
    }
  }

  @override
  bool shouldRepaint(_DatabaseIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}
