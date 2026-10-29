import 'package:flutter/material.dart';

/// DeskSuite's shared visual system: warm paper, near-black ink and restrained clay.
/// Individual documents retain their own colors; application chrome stays coherent.
const ink = Color(0xff292721);
const accent = Color(0xffa84f36);
const paper = Color(0xfff6f3ed);
const line = Color(0xffe5ded3);
const deskSuiteBrandAsset = 'assets/brand/desksuite-mark.png';

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  const clay = Color(0xffa84f36);
  final surface = dark ? const Color(0xff24231f) : const Color(0xfffffdf9);
  final background = dark ? const Color(0xff171714) : paper;
  final primary = dark ? const Color(0xffe6a18a) : clay;
  final onPrimary = dark ? const Color(0xff2b1711) : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: clay, brightness: brightness).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: dark ? const Color(0xffd8bba8) : const Color(0xff735d4e),
    surface: surface,
    onSurface: dark ? const Color(0xfff3eee6) : ink,
    outline: dark ? const Color(0xff62594f) : const Color(0xffcfc5b8),
    surfaceContainerHighest: dark ? const Color(0xff302e29) : const Color(0xffeee8de),
  );
  final textTheme = ThemeData(useMaterial3: true, brightness: brightness).textTheme.apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
    fontFamily: 'DeskSuiteSans',
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: background,
    dividerColor: dark ? const Color(0xff3c3932) : line,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dark ? const Color(0xff3c3932) : line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff292823) : const Color(0xfff0ebe2),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? const Color(0xff49443b) : line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: dark ? const Color(0xff62594f) : line),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xff302e29) : const Color(0xff292721),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: dark ? const Color(0xff493027) : const Color(0xfff0dfd5),
      elevation: 0,
    ),
  );
}

/// The owner-selected app icon. Nearby labels supply the accessible app name;
/// the image itself is decorative. A fallback remains usable if loading fails.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .22),
    child: Image.asset(
      deskSuiteBrandAsset,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: size <= 64 ? 128 : null,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stackTrace) => Container(
        width: size,
        height: size,
        color: accent,
        child: Icon(Icons.document_scanner_outlined, size: size * .6, color: Colors.white),
      ),
    ),
  );
}
