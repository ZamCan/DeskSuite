import 'package:flutter/material.dart';

/// Quiet, low-contrast stationery motifs used only as background texture.
class StationeryPattern extends StatelessWidget {
  const StationeryPattern({super.key});

  @override
  Widget build(BuildContext context) => const CustomPaint(
    painter: _StationeryPatternPainter(),
    child: SizedBox.expand(),
  );
}

class _StationeryPatternPainter extends CustomPainter {
  const _StationeryPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = const Color(0xff8d8275).withValues(alpha: .075)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    const stepX = 112.0;
    const stepY = 126.0;
    for (var row = 0; row * stepY < size.height + stepY; row++) {
      for (var col = 0; col * stepX < size.width + stepX; col++) {
        canvas.save();
        canvas.translate(col * stepX + (row.isOdd ? 42 : 0), row * stepY);
        switch ((row * 3 + col) % 7) {
          case 0: _document(canvas, ink); break;
          case 1: _folder(canvas, ink); break;
          case 2: _pencil(canvas, ink); break;
          case 3: _photo(canvas, ink); break;
          case 4: _scanner(canvas, ink); break;
          case 5: _printer(canvas, ink); break;
          default: _signature(canvas, ink); break;
        }
        canvas.restore();
      }
    }
  }

  void _document(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(18, 20, 27, 35), const Radius.circular(3)), p);
    c.drawLine(const Offset(24, 31), const Offset(39, 31), p);
    c.drawLine(const Offset(24, 37), const Offset(39, 37), p);
    c.drawLine(const Offset(24, 43), const Offset(35, 43), p);
  }

  void _folder(Canvas c, Paint p) {
    final path = Path()..moveTo(16, 31)..lineTo(27, 31)..lineTo(31, 35)..lineTo(48, 35)..lineTo(46, 52)..lineTo(17, 52)..close();
    c.drawPath(path, p);
    c.drawLine(const Offset(17, 35), const Offset(46, 35), p);
  }

  void _pencil(Canvas c, Paint p) {
    c.save();
    c.translate(31, 39);
    c.rotate(-.65);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-4, -17, 8, 29), const Radius.circular(2)), p);
    c.drawLine(const Offset(-4, -11), const Offset(4, -11), p);
    c.drawLine(const Offset(-4, 12), const Offset(0, 18), p);
    c.drawLine(const Offset(4, 12), const Offset(0, 18), p);
    c.restore();
  }

  void _photo(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(15, 27, 34, 25), const Radius.circular(4)), p);
    c.drawCircle(const Offset(32, 39), 6, p);
    c.drawCircle(const Offset(42, 33), 1.5, p);
  }

  void _scanner(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(15, 27, 34, 24), const Radius.circular(4)), p);
    c.drawLine(const Offset(20, 34), const Offset(44, 34), p);
    c.drawLine(const Offset(22, 40), const Offset(42, 40), p);
    c.drawLine(const Offset(22, 51), const Offset(22, 57), p);
    c.drawLine(const Offset(42, 51), const Offset(42, 57), p);
  }

  void _printer(Canvas c, Paint p) {
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(15, 31, 34, 20), const Radius.circular(4)), p);
    c.drawRect(const Rect.fromLTWH(22, 20, 20, 14), p);
    c.drawRect(const Rect.fromLTWH(22, 46, 20, 13), p);
    c.drawCircle(const Offset(42, 38), 1.5, p);
  }

  void _signature(Canvas c, Paint p) {
    final path = Path()..moveTo(15, 48)..cubicTo(22, 27, 25, 27, 27, 44)..cubicTo(29, 55, 37, 30, 41, 36)..cubicTo(44, 42, 42, 47, 49, 43);
    c.drawPath(path, p);
    c.drawLine(const Offset(16, 54), const Offset(49, 54), p);
  }

  @override
  bool shouldRepaint(covariant _StationeryPatternPainter oldDelegate) => false;
}
