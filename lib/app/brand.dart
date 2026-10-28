import 'package:flutter/material.dart';

/// The ZamCan palette and mark geometry: the only place brand colour is defined.
///
/// Every screen, the boot sequence, the onboarding and the launcher icon draw
/// from these values. A test (`test/brand_palette_test.dart`) parses the widget
/// code and the checked-in SVG and fails if a colour appears that is not one of
/// these tokens, so "close enough" hex values cannot creep back in.
class ZamCanBrand {
  const ZamCanBrand._();

  /// Name on the store listing and the boot wordmark.
  static const String company = 'ZamCan';
  static const String product = 'DeskSuite';
  static const String tagline = 'Documents, photos and print — on your phone';

  /// Warm ink: text, the mark tile and the launcher background.
  static const Color ink = Color(0xFF292824);

  /// Paper: page-like surfaces.
  static const Color paper = Color(0xFFF7F5F0);

  /// Terracotta: the single accent. Buttons, selection, the S sweep of the mark.
  static const Color accent = Color(0xFFB96045);

  /// The accent tint used on ink, where full-strength terracotta is too dark.
  static const Color accentSoft = Color(0xFFED9A7A);

  /// The accent pressed into paper, for small text that must stay legible.
  static const Color accentDeep = Color(0xFF8F4630);

  /// Hairlines and card borders on paper.
  static const Color line = Color(0xFFE6E1D8);

  // Dark-mode surfaces. Same warm family, never neutral grey.
  static const Color inkDark = Color(0xFF191917);
  static const Color surfaceDark = Color(0xFF242321);
  static const Color surfaceLight = Color(0xFFFFFEFA);

  /// Ink that sits on a dark surface.
  static const Color onInk = Color(0xFFF2EDE6);

  /// Hairlines in dark mode: two steps, so borders and dividers stay distinct.
  static const Color lineDark = Color(0xFF403D38);
  static const Color lineSoft = Color(0xFF5B5751);

  /// Hairlines on paper: the filled-field tint and the stronger outline.
  static const Color fieldLight = Color(0xFFF8F6F2);
  static const Color fieldDark = Color(0xFF2D2B28);
  static const Color lineStrong = Color(0xFFC9C1B6);

  /// Quiet text on paper.
  static const Color muted = Color(0xFF777970);

  /// The canvas behind a design being edited, and the tint used where an image
  /// has not loaded yet.
  static const Color canvasLight = Color(0xFFEAE6DF);
  static const Color canvasDark = Color(0xFF302E2A);
  static const Color placeholder = Color(0xFFE7E2DA);
  static const Color swatchRing = Color(0xFFD8D1C8);

  /// 40 % black, for the scrim behind a modal preview.
  static const Color scrim = Color(0x66000000);

  /// Every colour allowed to appear as a literal outside this file. Used by the
  /// palette test as the allowlist.
  static const List<Color> tokens = [
    ink,
    paper,
    accent,
    accentSoft,
    accentDeep,
    line,
    inkDark,
    surfaceDark,
    surfaceLight,
    onInk,
    lineDark,
    lineSoft,
    fieldLight,
    fieldDark,
    lineStrong,
    muted,
    canvasLight,
    canvasDark,
    placeholder,
    swatchRing,
    scrim,
  ];

  // Colours that describe a *document*, not the interface: photo backgrounds a
  // user can choose, PDF page colours and the paper tints in thumbnails. They
  // are content, not chrome, but they are named here rather than scattered
  // through the studios, and the palette test allows them.
  static const Color paperWarm = Color(0xFFF8F3EB);
  static const Color paperShade = Color(0xFFE7DFD4);
  static const Color paperEdge = Color(0xFFD5CBC0);
  static const Color paperRule = Color(0xFFB5A89A);
  static const Color inkSoft = Color(0xFF393630);
  static const Color swatchWhite = Color(0xFFFFFFFF);
  static const Color swatchWarm = Color(0xFFF5F0E6);
  static const Color swatchGrey = Color(0xFFE8E8E8);
  static const Color swatchBlue = Color(0xFFDCEBFA);
  static const Color swatchPink = Color(0xFFF8E3E8);
  static const Color swatchGreen = Color(0xFFE0F0E3);
  static const Color swatchCharcoal = Color(0xFF222222);

  static const Map<String, Color> media = {
    'paperWarm': paperWarm,
    'paperShade': paperShade,
    'paperEdge': paperEdge,
    'paperRule': paperRule,
    'inkSoft': inkSoft,
    'swatchBlue': swatchBlue,
    'swatchPink': swatchPink,
    'swatchGreen': swatchGreen,
    'swatchWhite': swatchWhite,
    'swatchWarm': swatchWarm,
    'swatchGrey': swatchGrey,
    'swatchCharcoal': swatchCharcoal,
  };

  /// All colours permitted as literals anywhere in `lib/`.
  static List<Color> get allowed =>
      List<Color>.unmodifiable([...tokens, ...media.values]);
}

/// Brand colours that are not part of a [ColorScheme], exposed through the
/// theme so studios read the palette instead of inventing one.
@immutable
class ZamCanColors extends ThemeExtension<ZamCanColors> {
  const ZamCanColors({
    required this.ink,
    required this.paper,
    required this.accent,
    required this.accentSoft,
    required this.accentDeep,
    required this.line,
    required this.tile,
    required this.media,
  });

  final Color ink;
  final Color paper;
  final Color accent;
  final Color accentSoft;
  final Color accentDeep;
  final Color line;

  /// Background of the square the mark is drawn on.
  final Color tile;

  /// Document colours (photo backgrounds, page tints) — content, not chrome.
  final Map<String, Color> media;

  static const ZamCanColors light = ZamCanColors(
    ink: ZamCanBrand.ink,
    paper: ZamCanBrand.paper,
    accent: ZamCanBrand.accent,
    accentSoft: ZamCanBrand.accentSoft,
    accentDeep: ZamCanBrand.accentDeep,
    line: ZamCanBrand.line,
    tile: ZamCanBrand.ink,
    media: ZamCanBrand.media,
  );

  static const ZamCanColors dark = ZamCanColors(
    ink: ZamCanBrand.paper,
    paper: ZamCanBrand.inkDark,
    accent: ZamCanBrand.accentSoft,
    accentSoft: ZamCanBrand.accent,
    accentDeep: ZamCanBrand.accentSoft,
    line: Color(0xFF403D38),
    tile: ZamCanBrand.accentDeep,
    media: ZamCanBrand.media,
  );

  /// Convenience: the brand extension, with a light fallback when a widget is
  /// rendered outside `deskTheme`.
  static ZamCanColors of(BuildContext context) =>
      Theme.of(context).extension<ZamCanColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  ZamCanColors copyWith({
    Color? ink,
    Color? paper,
    Color? accent,
    Color? accentSoft,
    Color? accentDeep,
    Color? line,
    Color? tile,
    Map<String, Color>? media,
  }) => ZamCanColors(
    ink: ink ?? this.ink,
    paper: paper ?? this.paper,
    accent: accent ?? this.accent,
    accentSoft: accentSoft ?? this.accentSoft,
    accentDeep: accentDeep ?? this.accentDeep,
    line: line ?? this.line,
    tile: tile ?? this.tile,
    media: media ?? this.media,
  );

  @override
  ZamCanColors lerp(ThemeExtension<ZamCanColors>? other, double t) {
    if (other is! ZamCanColors) return this;
    return ZamCanColors(
      ink: Color.lerp(ink, other.ink, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      line: Color.lerp(line, other.line, t)!,
      tile: Color.lerp(tile, other.tile, t)!,
      media: t < .5 ? media : other.media,
    );
  }
}

/// The mark's geometry, in the 512 × 512 design box used by the master SVG.
///
/// Kept as paths rather than an image so the boot sequence can trace it stroke
/// by stroke at any size, and so the launcher icon, the sidebar mark and the
/// boot animation can never drift apart.
class ZamCanGeometry {
  const ZamCanGeometry._();

  static const double box = 512;

  /// The master art is scaled by this factor around the centre, matching
  /// `assets/brand/desksuite-mark.svg`.
  static const double scale = 1.25;

  /// Interlocking D, drawn as an even-odd outline (the counter is the hole).
  static Path get dPath => Path()
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

  /// The S sweep that makes the D a monogram.
  static Path get sPath => Path()
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

  /// The open-page crease that doubles as an image horizon.
  static const Rect crease = Rect.fromLTWH(200, 273, 42, 10);
  static const double creaseRadius = 5;

  /// Applies the design box and the master scale to [canvas].
  static void applyBox(Canvas canvas, Size size) {
    canvas.scale(size.width / box, size.height / box);
    canvas.translate(box / 2, box / 2);
    canvas.scale(scale);
    canvas.translate(-box / 2, -box / 2);
  }

  /// The part of [source] that is visible when drawing `t` (0–1) of its length.
  ///
  /// Used by the boot animation to draw the mark for the first time.
  static Path trace(Path source, double t) {
    final clamped = t.clamp(0.0, 1.0);
    final result = Path();
    for (final metric in source.computeMetrics()) {
      result.addPath(
        metric.extractPath(0, metric.length * clamped),
        Offset.zero,
      );
    }
    return result;
  }
}
