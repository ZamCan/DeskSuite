// Standalone dependency-free check: dart test/image_detail_smoke.dart
// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'dart:math' as math;

import '../lib/printing/image_detail.dart';

void check(bool value, String label) {
  if (!value) throw StateError(label);
}

bool close(double actual, double expected) =>
    (actual - expected).abs() <= math.max(1e-9, expected.abs() * 1e-12);

void main() {
  check(close(effectiveImageDpi(4000, 1000, 100, 100), 1016), 'contain wide');
  check(
    close(
      effectiveImageDpi(4000, 1000, 100, 100, fit: ImagePlacementFit.cover),
      254,
    ),
    'cover wide',
  );
  check(
    close(
      effectiveImageDpi(1000, 4000, 100, 100, fit: ImagePlacementFit.cover),
      254,
    ),
    'cover tall',
  );
  final random = math.Random(239);
  for (var i = 0; i < 5000; i++) {
    final width = 1 + random.nextInt(8192);
    final height = 1 + random.nextInt(8192);
    final boxWidth = 1 + random.nextDouble() * 2499;
    final boxHeight = 1 + random.nextDouble() * 2499;
    final widthScale = boxWidth / width;
    final heightScale = boxHeight / height;
    for (final fit in ImagePlacementFit.values) {
      final scale = fit == ImagePlacementFit.contain
          ? math.min(widthScale, heightScale)
          : math.max(widthScale, heightScale);
      final calculated = effectiveImageDpi(
        width,
        height,
        boxWidth,
        boxHeight,
        fit: fit,
      );
      check(close(calculated, 25.4 / scale), '$fit case $i');
    }
  }
  for (final size in [0.0, -1.0, double.nan, double.infinity, 5e-324]) {
    var rejected = false;
    try {
      effectiveImageDpi(100, 100, size, 100);
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'invalid frame $size');
  }
  print(
    'PASS: contain and cropped-cover image DPI, 5000 geometries and invalid bounds.',
  );
}
