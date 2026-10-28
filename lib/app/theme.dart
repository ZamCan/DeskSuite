import 'package:flutter/material.dart';

/// Shared brand palette. Studio-specific document content keeps its own colors.
const ink = Color(0xff15243a);
const accent = Color(0xff1c58ac);
const paper = Color(0xfff3f7fc);
const line = Color(0xffdce5f1);
const deskSuiteBrandAsset = 'assets/brand/desksuite-mark.png';

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? const Color(0xff19283d) : const Color(0xfffffeff);
  final background = dark ? const Color(0xff0b1423) : paper;
  final primary = dark ? const Color(0xff90d4ff) : accent;
  final onPrimary = dark ? const Color(0xff102840) : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: dark ? const Color(0xfff2f6fd) : ink,
        outline: dark ? const Color(0xff63758e) : const Color(0xffaabbd1),
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: dark ? const Color(0xff33445d) : line,
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
        side: BorderSide(color: dark ? const Color(0xff33445d) : line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff223249) : const Color(0xfff1f5fa),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
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
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: dark ? const Color(0xff63758e) : line),
      ),
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
        color: const Color(0xff0b2d70),
        child: Icon(
          Icons.document_scanner_outlined,
          size: size * .6,
          color: Colors.white,
        ),
      ),
    ),
  );
}
