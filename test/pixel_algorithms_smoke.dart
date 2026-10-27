// Standalone, dependency-free pixel-engine smoke check:
//   dart test/pixel_algorithms_smoke.dart
// This does not replace Flutter widget tests, image-codec tests, or device tests.
import 'dart:math' as math;
import 'dart:typed_data';

import '../lib/document_scan/document_cleanup_pixels.dart';
import '../lib/images/image_cleanup_pixels.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  const width = 128, height = 64;
  final uneven = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final paper = x < 64 ? 120 : 240;
      final value = y == 30 ? paper ~/ 4 : paper;
      uneven[i] = uneven[i + 1] = uneven[i + 2] = value;
      uneven[i + 3] = 255;
    }
  }
  int valueAt(Uint8List data, int x, int y) => data[(y * width + x) * 4];
  final color = Uint8List.fromList(uneven);
  cleanDocumentRgbaInPlace(
    color,
    width,
    height,
    mode: DocumentCleanupMode.evenLighting,
    amount: 1,
  );
  check(valueAt(color, 10, 10) > 225, 'Shaded paper was not lifted.');
  check(
    valueAt(color, 100, 10) == 240,
    'Bright paper was unexpectedly changed.',
  );
  check(valueAt(color, 10, 30) < 35, 'Near-black ink was over-lifted.');
  final bw = Uint8List.fromList(uneven);
  cleanDocumentRgbaInPlace(
    bw,
    width,
    height,
    mode: DocumentCleanupMode.adaptiveBlackAndWhite,
    amount: .7,
  );
  check(
    valueAt(bw, 10, 10) == 255 && valueAt(bw, 100, 10) == 255,
    'Paper did not turn white.',
  );
  check(
    valueAt(bw, 10, 30) == 0 && valueAt(bw, 100, 30) == 0,
    'Ink did not remain black.',
  );
  final transparent = Uint8List.fromList([0, 0, 0, 0]);
  cleanDocumentRgbaInPlace(
    transparent,
    1,
    1,
    mode: DocumentCleanupMode.evenLighting,
    amount: 0,
  );
  check(
    transparent.every((v) => v == 255),
    'Transparent pixel was not composited on white.',
  );

  final invalid = Uint8List.fromList([1, 2, 3, 4]);
  for (final amount in [-1.0, 2.0, double.nan, double.infinity]) {
    var rejected = false;
    try {
      cleanDocumentRgbaInPlace(
        invalid,
        1,
        1,
        mode: DocumentCleanupMode.evenLighting,
        amount: amount,
      );
    } on FormatException {
      rejected = true;
    }
    check(
      rejected && invalid[0] == 1 && invalid[3] == 4,
      'Invalid amount was accepted or mutated.',
    );
  }

  const side = 7;
  final specks = Uint8List(side * side * 4);
  for (var i = 0; i < side * side; i++) {
    specks.setRange(i * 4, i * 4 + 4, [100, 120, 140, 255]);
  }
  final center = (3 * side + 3) * 4;
  specks.setRange(center, center + 3, [255, 255, 255]);
  reduceImpulseNoiseRgbaInPlace(specks, side, side);
  check(
    specks[center] == 100 &&
        specks[center + 1] == 120 &&
        specks[center + 2] == 140,
    'Isolated impulse remained.',
  );
  specks.setRange(center, center + 3, [0, 0, 0]);
  specks[center + 4 + 3] = 0;
  reduceImpulseNoiseRgbaInPlace(specks, side, side);
  check(
    specks[center] == 0 && specks[center + 7] == 0,
    'Transparent neighborhood was changed.',
  );
  var rejected = false;
  try {
    reduceImpulseNoiseRgbaInPlace(invalid, 2001, 2000);
  } on FormatException {
    rejected = true;
  }
  check(
    rejected && invalid[0] == 1 && invalid[3] == 4,
    'Oversized noise request was accepted or mutated.',
  );

  final random = math.Random(42);
  for (var run = 0; run < 40; run++) {
    final w = 1 + random.nextInt(80), h = 1 + random.nextInt(80);
    final pixels = Uint8List(w * h * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = random.nextInt(256);
      pixels[i + 1] = random.nextInt(256);
      pixels[i + 2] = random.nextInt(256);
      pixels[i + 3] = random.nextBool() ? 0 : 255;
    }
    final original = Uint8List.fromList(pixels);
    reduceImpulseNoiseRgbaInPlace(pixels, w, h);
    for (var i = 3; i < pixels.length; i += 4) {
      check(pixels[i] == original[i], 'Noise filter changed alpha.');
    }
    cleanDocumentRgbaInPlace(
      pixels,
      w,
      h,
      mode: DocumentCleanupMode.adaptiveBlackAndWhite,
      amount: .5,
    );
    for (var i = 0; i < pixels.length; i += 4) {
      check(
        (pixels[i] == 0 || pixels[i] == 255) &&
            pixels[i + 1] == pixels[i] &&
            pixels[i + 2] == pixels[i] &&
            pixels[i + 3] == 255,
        'Adaptive output was not opaque binary.',
      );
    }
  }
  print(
    'PASS: document and image cleanup pixel smoke checks (40 randomized images).',
  );
}
