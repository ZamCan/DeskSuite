import 'package:flutter/material.dart';

/// DeskSuite Slate Coral design system.
/// The original brand asset and deskTheme / BrandMark interfaces are retained.
const ink = Color(0xff0f172a);
const surface = Color(0xff1e293b);
const elevated = Color(0xff273449);
const accent = Color(0xffff6b5b);
const accentDeep = Color(0xffe8505f);
const paper = Color(0xfff1f5f9);
const muted = Color(0xff94a3b8);
const line = Color(0x14ffffff);
const deskSuiteBrandAsset = 'assets/brand/desksuite-mark.png';

const coralGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xffff8a5b), accentDeep],
);

class SectionTones {
  static const scan = Color(0xffff6b5b);
  static const pdf = Color(0xfff45b78);
  static const photo = Color(0xfff5b84a);
  static const text = Color(0xff3cc6d0);
  static const docs = Color(0xff6aa0ff);
  static const create = Color(0xffe56bd0);
  static const print = Color(0xff4fd09a);
  static const business = Color(0xffc9d860);
}

BoxDecoration toneChip(Color tone, {double radius = 12}) => BoxDecoration(
  color: tone.withValues(alpha: .16),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: tone.withValues(alpha: .28)),
);

ThemeData deskTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final background = dark ? ink : const Color(0xfff8fafc);
  final cardSurface = dark ? surface : Colors.white;
  final raised = dark ? elevated : const Color(0xffe9eef5);
  final foreground = dark ? paper : ink;
  final subtle = dark ? muted : const Color(0xff526174);
  final border = dark ? line : const Color(0xffdbe3ed);
  final primary = dark ? accent : const Color(0xffc43f38);
  final onPrimary = dark ? ink : Colors.white;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: dark ? elevated : const Color(0xffe8edf5),
    onSecondary: foreground,
    surface: cardSurface,
    onSurface: foreground,
    outline: border,
    error: dark ? const Color(0xfff2555a) : const Color(0xffb42332),
    surfaceContainerHighest: raised,
  );
  final base = ThemeData(useMaterial3: true, brightness: brightness).textTheme;
  final typography = base.apply(
    bodyColor: foreground,
    displayColor: foreground,
    fontFamily: 'DeskSuiteSans',
  ).copyWith(
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w700, letterSpacing: -.5, color: foreground),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w700, color: foreground),
    labelSmall: base.labelSmall?.copyWith(
      letterSpacing: 2, fontWeight: FontWeight.w700, color: subtle),
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
        (states) => states.contains(WidgetState.selected) ? onPrimary : subtle),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? primary : raised),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary, linearTrackColor: raised),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? raised : ink,
      contentTextStyle: TextStyle(color: dark ? paper : Colors.white),
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
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
        decoration: const BoxDecoration(gradient: coralGradient),
        child: Icon(Icons.description_outlined,
          size: size * .55, color: ink),
      ),
    ),
  );
}
