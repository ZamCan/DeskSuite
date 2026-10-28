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
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .25),
    child: Image.asset(
      'assets/brand/desksuite-reference-mark.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xff073b91),
          borderRadius: BorderRadius.circular(size * .25),
        ),
        alignment: Alignment.center,
        child: const Text(
          'DS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.5,
          ),
        ),
      ),
    ),
  );
}
