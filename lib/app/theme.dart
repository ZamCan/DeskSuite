import 'package:flutter/material.dart';

import 'brand.dart';
import 'zamcan_mark.dart';

// The palette is defined once, in `brand.dart`. These aliases keep the existing
// imports working without giving anyone a second place to invent a colour.
const ink = ZamCanBrand.ink;
const accent = ZamCanBrand.accent;
const paper = ZamCanBrand.paper;
const line = ZamCanBrand.line;

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? ZamCanBrand.surfaceDark : ZamCanBrand.surfaceLight;
  final background = dark ? ZamCanBrand.inkDark : paper;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: dark ? ZamCanBrand.accentSoft : accent,
        surface: surface,
        onSurface: dark ? ZamCanBrand.onInk : ink,
        outline: dark ? ZamCanBrand.lineSoft : ZamCanBrand.lineStrong,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    // Brand colours that are not part of ColorScheme (the tile the mark sits
    // on, the document tints) travel with the theme, so a studio never has to
    // hard-code a hex value again.
    extensions: <ThemeExtension<dynamic>>[
      dark ? ZamCanColors.dark : ZamCanColors.light,
    ],
    scaffoldBackgroundColor: background,
    dividerColor: dark ? ZamCanBrand.lineDark : line,
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
        side: BorderSide(color: dark ? ZamCanBrand.lineDark : line),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? ZamCanBrand.fieldDark : ZamCanBrand.fieldLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? ZamCanBrand.accentSoft : ink,
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
        side: BorderSide(color: dark ? ZamCanBrand.lineSoft : line),
      ),
    ),
  );
}

/// The product mark shown in the sidebar and headers.
///
/// Delegates to [ZamCanMark] so the interface, the boot animation and the
/// launcher icon all draw the same geometry and palette.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38});
  final double size;
  @override
  Widget build(BuildContext context) => ZamCanMark(size: size);
}
