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

/// Shared Dune Phosphate surface tokens. Screens should reach for these instead
/// of mixing one-off neutrals, so a new page cannot drift colder than the shell.
const sandDeep = Color(0xffe7dcc6);
const phosphateWash = Color(0xffdfeee9);

/// Date-fruit terracotta: emphasis only, never a large background.
const clay = Color(0xffb3562f);

const duneRadius = 12.0;
const duneCardRadius = 18.0;
const dunePanelRadius = 24.0;

/// One elevation recipe for the whole suite: a warm ink shadow that is a
/// whisper in light and a deeper pool in dark.
List<BoxShadow> duneShadow(
  Brightness brightness, {
  double blur = 20,
  double y = 8,
  double spread = -3,
}) => [
  BoxShadow(
    color: (brightness == Brightness.dark ? Colors.black : ink).withValues(
      alpha: brightness == Brightness.dark ? .30 : .08,
    ),
    blurRadius: blur,
    spreadRadius: spread,
    offset: Offset(0, y),
  ),
];

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
  // DeskSuiteSans ships two real weights (400 and 700) from Noto Sans. The
  // scale below therefore uses only those, so headings never render as
  // synthesised bold, and it tightens display sizes while relaxing body
  // leading for a calmer, more editorial read.
  final base = ThemeData(useMaterial3: true, brightness: brightness).textTheme;
  TextStyle? sized(
    TextStyle? style,
    double size, {
    FontWeight weight = FontWeight.w400,
    double spacing = 0,
    double height = 1.45,
    Color? color,
  }) => style?.copyWith(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    height: height,
    color: color ?? foreground,
  );
  final applied = base.apply(
    bodyColor: foreground,
    displayColor: foreground,
    fontFamily: 'DeskSuiteSans',
  );
  final typography = applied.copyWith(
    displayLarge: sized(
      applied.displayLarge,
      48,
      weight: FontWeight.w700,
      spacing: -1.5,
      height: 1.06,
    ),
    displayMedium: sized(
      applied.displayMedium,
      38,
      weight: FontWeight.w700,
      spacing: -1.2,
      height: 1.1,
    ),
    displaySmall: sized(
      applied.displaySmall,
      32,
      weight: FontWeight.w700,
      spacing: -.9,
      height: 1.12,
    ),
    headlineLarge: sized(
      applied.headlineLarge,
      30,
      weight: FontWeight.w700,
      spacing: -.8,
      height: 1.16,
    ),
    headlineMedium: sized(
      applied.headlineMedium,
      25,
      weight: FontWeight.w700,
      spacing: -.6,
      height: 1.18,
    ),
    headlineSmall: sized(
      applied.headlineSmall,
      21,
      weight: FontWeight.w700,
      spacing: -.45,
      height: 1.2,
    ),
    titleLarge: sized(
      applied.titleLarge,
      19,
      weight: FontWeight.w700,
      spacing: -.3,
      height: 1.25,
    ),
    titleMedium: sized(
      applied.titleMedium,
      16,
      weight: FontWeight.w700,
      spacing: -.15,
      height: 1.3,
    ),
    titleSmall: sized(
      applied.titleSmall,
      14,
      weight: FontWeight.w700,
      height: 1.32,
    ),
    bodyLarge: sized(applied.bodyLarge, 15.5),
    bodyMedium: sized(applied.bodyMedium, 14),
    bodySmall: sized(applied.bodySmall, 12.5, height: 1.4, color: subtle),
    labelLarge: sized(
      applied.labelLarge,
      13.5,
      weight: FontWeight.w700,
      spacing: .2,
      height: 1.2,
    ),
    labelMedium: sized(
      applied.labelMedium,
      11.5,
      weight: FontWeight.w700,
      spacing: .55,
      height: 1.2,
    ),
    labelSmall: sized(
      applied.labelSmall,
      10.5,
      weight: FontWeight.w700,
      spacing: 1.6,
      height: 1.25,
      color: subtle,
    ),
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(duneRadius),
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
      backgroundColor: cardSurface.withValues(alpha: .92),
      foregroundColor: foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 20,
      titleTextStyle: typography.titleLarge,
      toolbarHeight: 68,
    ),
    cardTheme: CardThemeData(
      color: cardSurface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(duneCardRadius),
        side: BorderSide(color: border),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: cardSurface,
      surfaceTintColor: Colors.transparent,
      scrimColor: ink.withValues(alpha: .42),
      width: 288,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(dunePanelRadius),
        ),
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
      titleTextStyle: typography.headlineSmall,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(dunePanelRadius),
      ),
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
