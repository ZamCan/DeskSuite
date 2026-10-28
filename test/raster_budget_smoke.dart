// Standalone dependency-free check: dart test/raster_budget_smoke.dart
// ignore_for_file: avoid_print, avoid_relative_lib_imports
import '../lib/printing/paper_catalog.dart';
import '../lib/printing/raster_budget.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  final a4 = boundedRasterDimensions(210, 297, 300);
  check(a4.width == 2480 && a4.height == 3508, 'A4 conversion');
  for (final media in paperSheetPresets) {
    final fit = fittingRasterDpi(media.widthMm, media.heightMm);
    check(
      fit != null && fit >= 36 && fit <= 150,
      'No safe DPI: ${media.label}',
    );
    final pixels = boundedRasterDimensions(media.widthMm, media.heightMm, fit!);
    check(
      pixels.width <= maxExportSide &&
          pixels.height <= maxExportSide &&
          pixels.width * pixels.height <= maxExportPixels,
      'Pixel budget exceeded: ${media.label}',
    );
    if (fit < 150) {
      var rejected = false;
      try {
        boundedRasterDimensions(media.widthMm, media.heightMm, fit + 1);
      } on FormatException {
        rejected = true;
      }
      check(rejected, 'DPI was not the highest fitting value: ${media.label}');
    }
  }
  check(fittingRasterDpi(210, 297, preferredDpi: 300) == 300, 'A4 300 dpi');
  check(
    fittingRasterDpi(1219.2, 1828.8)! < 150,
    'Poster should need reduced DPI',
  );
  final maximum = fittingRasterDpi(2500, 2500)!;
  check(maximum >= 36 && maximum < 150, 'Maximum-size page');
  var rejected = false;
  try {
    boundedRasterDimensions(double.nan, 100, 150);
  } on FormatException {
    rejected = true;
  }
  check(rejected, 'Invalid dimensions accepted');
  print(
    'PASS: ${paperSheetPresets.length} media presets and raster budget boundaries.',
  );
}
