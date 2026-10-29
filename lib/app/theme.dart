import 'package:flutter/material.dart';

/// DeskSuite's shared palette follows its supplied mark: ink navy, cyan detail,
/// paper-white surfaces and restrained gold accents.
const ink = Color(0xff15243a);
const accent = Color(0xff153b66);
const cyan = Color(0xff26c6da);
const gold = Color(0xfff3bd50);
const paper = Color(0xfff4f7fb);
const line = Color(0xffdae4ef);

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xff17283d) : const Color(0xfffeffff);
  final background = dark ? const Color(0xff0c1727) : paper;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xff83dce7) : accent,
    onPrimary: dark ? const Color(0xff102a45) : Colors.white,
    secondary: dark ? const Color(0xfff3bd50) : const Color(0xff9a6b12),
    surface: surface,
    onSurface: dark ? const Color(0xfff2f7fd) : ink,
    outline: dark ? const Color(0xff4c6178) : const Color(0xffc2d1df),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: dark ? const Color(0xff30445a) : line,
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
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark
              ? const Color(0xff354a60)
              : line.withValues(alpha: .9),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff20344a) : const Color(0xffedf3f8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? cyan : accent,
        foregroundColor: dark ? const Color(0xff102a45) : Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(
          color: dark ? const Color(0xff526a83) : line,
        ),
      ),
    ),
  );
}

/// The canonical in-app mark is the owner-supplied PNG, not an approximated
/// recreation of its letterforms. Labels provide the accessible app name.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .24),
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
          color: accent,
          borderRadius: BorderRadius.circular(size * .24),
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
