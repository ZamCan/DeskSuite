import 'package:flutter/material.dart';

/// DeskSuite's shared design tokens: warm paper, ink and a restrained clay accent.
/// Editors may use document colors inside the canvas; app chrome stays consistent.
const ink = Color(0xff292721);
const accent = Color(0xffa84f36);
const paper = Color(0xfff6f3ed);
const line = Color(0xffe5ded3);
const deskSuiteBrandAsset = 'assets/brand/desksuite-mark.png';

const _darkInk = Color(0xfff3eee5);
const _darkSurface = Color(0xff25241f);
const _darkBackground = Color(0xff191916);
const _darkLine = Color(0xff454139);
const _darkAccent = Color(0xffe39a7e);

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? _darkSurface : const Color(0xfffffdfa);
  final background = dark ? _darkBackground : paper;
  final primary = dark ? _darkAccent : accent;
  final onPrimary = dark ? const Color(0xff2b1710) : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: dark ? const Color(0xffd3b98a) : const Color(0xff8a7047),
    surface: surface,
    onSurface: dark ? _darkInk : ink,
    onSurfaceVariant: dark ? const Color(0xffc0b8aa) : const Color(0xff716b60),
    outline: dark ? const Color(0xff71695d) : const Color(0xffc9c0b3),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    dividerColor: dark ? _darkLine : line,
    fontFamily: 'DeskSuiteSans',
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.45,
        color: ink,
      ).copyWith(color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: dark ? _darkLine : line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff302f29) : const Color(0xfff0ece4),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: dark ? _darkLine : line),
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
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: dark ? _darkLine : line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xff39372f) : const Color(0xff302e28),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      indicatorColor: scheme.primary.withValues(alpha: .12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 11,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w700
            : FontWeight.w500,
      )),
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
        child: Icon(
          Icons.document_scanner_outlined,
          size: size * .6,
          color: Colors.white,
        ),
      ),
    ),
  );
}
