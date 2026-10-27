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
      color: ink,
      borderRadius: BorderRadius.circular(size * .25),
    ),
    child: CustomPaint(painter: _BrandPainter()),
  );
}

class _BrandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Same geometry and palette as assets/brand/desksuite-mark.svg and the
    // Android adaptive icon, drawn locally without an SVG runtime dependency.
    canvas.save();
    canvas.scale(size.width / 512, size.height / 512);
    canvas.translate(256, 256);
    canvas.scale(1.25);
    canvas.translate(-256, -256);
    final d = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(151, 153)
      ..lineTo(207, 153)
      ..cubicTo(279, 153, 326, 192, 326, 256)
      ..cubicTo(326, 320, 279, 359, 207, 359)
      ..lineTo(151, 359)
      ..close()
      ..moveTo(187, 188)
      ..lineTo(187, 324)
      ..lineTo(207, 324)
      ..cubicTo(259, 324, 289, 298, 289, 256)
      ..cubicTo(289, 214, 259, 188, 207, 188)
      ..close();
    canvas.drawPath(d, Paint()..color = const Color(0xfffbf8f1));
    final s = Path()
      ..moveTo(359, 174)
      ..cubicTo(345, 159, 326, 155, 308, 160)
      ..cubicTo(284, 166, 272, 185, 277, 207)
      ..cubicTo(282, 229, 302, 239, 323, 247)
      ..cubicTo(341, 254, 346, 260, 344, 270)
      ..cubicTo(342, 281, 332, 289, 319, 290)
      ..cubicTo(307, 290, 296, 285, 288, 276)
      ..lineTo(267, 294)
      ..cubicTo(278, 310, 297, 320, 318, 319)
      ..cubicTo(347, 318, 370, 300, 371, 272)
      ..cubicTo(373, 248, 359, 232, 333, 222)
      ..cubicTo(315, 215, 305, 210, 306, 200)
      ..cubicTo(307, 190, 315, 185, 326, 184)
      ..cubicTo(339, 183, 348, 189, 354, 197)
      ..close();
    final accentPaint = Paint()..color = const Color(0xffed9a7a);
    canvas.drawPath(s, accentPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(200, 273, 42, 10),
        const Radius.circular(5),
      ),
      accentPaint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
