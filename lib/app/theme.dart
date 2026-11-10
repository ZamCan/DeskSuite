import 'package:flutter/material.dart';

/// DeskSuite Dune Phosphate design system.
///
/// Warm dune sand and paper carry the neutrals; phosphate teal is the working
/// accent and date-fruit terracotta is reserved for emphasis. Both palettes are
/// deliberate, and every text pairing here is checked by `brand_theme_test`.
/// The original brand asset and the deskTheme / BrandMark interfaces are kept.
const ink = Color(0xff211d16);
const surface = Color(0xff2a251d);
const elevated = Color(0xff352f25);
const accent = Color(0xff14807a);
const accentDeep = Color(0xff0d5f5a);
const paper = Color(0xfff6f0e4);
const muted = Color(0xff9c9484);
const line = Color(0x1affffff);
const deskSuiteBrandAsset = 'assets/brand/desksuite-mark.png';

const duneGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff2fa79b), accentDeep],
);

/// Studio tones are mixed from the same sand, mineral and clay family so every
/// workspace still reads as one product in light and dark themes.
class SectionTones {
  static const scan = Color(0xffc2601f);
  static const pdf = Color(0xffa84a33);
  static const photo = Color(0xffcf9a3a);
  static const text = Color(0xff14807a);
  static const docs = Color(0xff3f7f93);
  static const create = Color(0xff8b5f96);
  static const print = Color(0xff4f7a5b);
  static const business = Color(0xff8a7b39);
}

BoxDecoration toneChip(Color tone, {double radius = 12}) => BoxDecoration(
  color: tone.withValues(alpha: .16),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: tone.withValues(alpha: .28)),
);

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? const Color(0xff171410) : paper;
  final cardSurface = dark ? surface : const Color(0xfffffdf7);
  final raised = dark ? elevated : const Color(0xffece2cf);
  final foreground = dark ? const Color(0xfff3eada) : ink;
  final subtle = dark ? muted : const Color(0xff6d6555);
  final border = dark ? line : const Color(0xffe2d7c3);
  final primary = dark ? const Color(0xff4fc3b4) : accentDeep;
  final onPrimary = dark ? const Color(0xff10231f) : Colors.white;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness)
      .copyWith(
        primary: primary,
        onPrimary: onPrimary,
        secondary: dark ? elevated : const Color(0xffe7dcc6),
        onSecondary: foreground,
        surface: cardSurface,
        onSurface: foreground,
        outline: border,
        error: dark ? const Color(0xfff08a7a) : const Color(0xffa3341f),
        surfaceContainerHighest: raised,
      );
  final base = ThemeData(useMaterial3: true, brightness: brightness).textTheme;
  final typography = base
      .apply(
        bodyColor: foreground,
        displayColor: foreground,
        fontFamily: 'DeskSuiteSans',
      )
      .copyWith(
        headlineMedium: base.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -.5,
          color: foreground,
        ),
        titleMedium: base.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        labelSmall: base.labelSmall?.copyWith(
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
          color: subtle,
        ),
        bodySmall: base.bodySmall?.copyWith(color: subtle),
      );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    textTheme: typography,
    scaffoldBackgroundColor: background,
    dividerColor: border,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: background.withValues(alpha: .85),
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: typography.titleMedium,
    ),
    cardTheme: CardThemeData(
      color: cardSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: cardSurface,
      surfaceTintColor: Colors.transparent,
      width: 300,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
    ),
    navigationDrawerTheme: NavigationDrawerThemeData(
      backgroundColor: cardSurface,
      indicatorColor: primary.withValues(alpha: .14),
      indicatorShape: rounded,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: subtle,
      textColor: foreground,
      shape: rounded,
      selectedColor: primary,
      selectedTileColor: raised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardSurface,
      hintStyle: TextStyle(color: subtle),
      prefixIconColor: subtle,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        minimumSize: const Size(48, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: rounded,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        minimumSize: const Size(48, 46),
        shape: rounded,
        side: BorderSide(color: border),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        shape: rounded,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: foreground, shape: rounded),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? onPrimary : subtle,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : raised,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: raised,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? raised : ink,
      contentTextStyle: TextStyle(color: dark ? paper : Colors.white),
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardSurface,
      indicatorColor: primary.withValues(alpha: .16),
      elevation: 0,
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .28),
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
        decoration: const BoxDecoration(gradient: duneGradient),
        child: Icon(Icons.description_outlined, size: size * .55, color: ink),
      ),
    ),
  );
}
