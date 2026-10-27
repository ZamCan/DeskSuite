import 'package:flutter/material.dart';

const ink = Color(0xff292824);
const accent = Color(0xffb96045);
const paper = Color(0xfff7f5f0);
const line = Color(0xffe6e1d8);

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xff242321) : const Color(0xfffffefa);
  final background = dark ? const Color(0xff191917) : paper;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: dark ? const Color(0xffe6a28b) : accent,
        surface: surface,
        onSurface: dark ? const Color(0xfff2ede6) : ink,
        outline: dark ? const Color(0xff5b5751) : const Color(0xffc9c1b6),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: dark ? const Color(0xff403d38) : line,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: dark ? const Color(0xff403d38) : line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff2d2b28) : const Color(0xfff8f6f2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? const Color(0xffda8a6f) : ink,
        foregroundColor: dark ? ink : Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: dark ? const Color(0xff5b5751) : line),
      ),
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: accent,
      borderRadius: BorderRadius.circular(size * .25),
    ),
    child: CustomPaint(painter: _BrandPainter()),
  );
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    canvas.save();
    canvas.scale(scale, size.height / 100);

    final paperPaint = Paint()
      ..color = const Color(0xfffff8ef)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // A folded page frames the joined D/S monogram.
    final page = Path()
      ..moveTo(24, 16)
      ..lineTo(62, 16)
      ..lineTo(78, 32)
      ..lineTo(78, 84)
      ..quadraticBezierTo(78, 88, 74, 88)
      ..lineTo(28, 88)
      ..quadraticBezierTo(24, 88, 24, 84)
      ..close();
    canvas.drawPath(page, paperPaint);
    canvas.drawLine(const Offset(62, 16), const Offset(62, 32), paperPaint);
    canvas.drawLine(const Offset(62, 32), const Offset(78, 32), paperPaint);

    // D: a strong stem and rounded bowl.
    final d = Path()
      ..moveTo(35, 43)
      ..lineTo(35, 70)
      ..moveTo(35, 43)
      ..lineTo(43, 43)
      ..cubicTo(59, 43, 59, 70, 43, 70)
      ..lineTo(35, 70);
    canvas.drawPath(d, paperPaint);

    // S: compact flowing stroke, visually linked to the D.
    final s = Path()
      ..moveTo(68, 47)
      ..cubicTo(58, 39, 48, 48, 57, 54)
      ..lineTo(66, 59)
      ..cubicTo(76, 66, 66, 76, 56, 68);
    final sPaint = Paint()
      ..color = const Color(0xffffd6a2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(s, sPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
