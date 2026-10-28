// Standalone smoke check: run with `dart test/pixel_algorithms_smoke.dart`.
// It imports the library relatively because it is executed as a script,
// not through the package resolution used by `flutter test`.
// ignore_for_file: avoid_relative_lib_imports, avoid_print

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
  final magic = Uint8List.fromList(uneven);
  cleanDocumentRgbaInPlace(
    magic,
    width,
    height,
    mode: DocumentCleanupMode.magicPro,
    amount: 1,
  );
  check(
    valueAt(magic, 10, 10) > 245 && valueAt(magic, 100, 10) > 245,
    'Magic Pro did not normalize both synthetic paper areas.',
  );
  check(valueAt(magic, 10, 30) < 45, 'Magic Pro lost dark ink.');
  final original = Uint8List.fromList([100, 80, 60, 128]);
  cleanDocumentRgbaInPlace(
    original,
    1,
    1,
    mode: DocumentCleanupMode.original,
    amount: 1,
  );
  check(
    original[0] == 100 && original[3] == 128,
    'Original changed the page or its alpha.',
  );
  final light = Uint8List.fromList([100, 80, 60, 255]);
  cleanDocumentRgbaInPlace(
    light,
    1,
    1,
    mode: DocumentCleanupMode.lighten,
    amount: 1,
  );
  check(light[0] == 145 && light[1] == 116, 'Lighten did not lift color.');
  final gray = Uint8List.fromList([200, 100, 50, 255]);
  cleanDocumentRgbaInPlace(
    gray,
    1,
    1,
    mode: DocumentCleanupMode.grayscale,
    amount: .5,
  );
  check(
    gray[0] == 124 && gray[1] == 124 && gray[2] == 124,
    'Grayscale did not produce expected luminance.',
  );
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

  for (final mode in [
    DocumentCleanupMode.lighten,
    DocumentCleanupMode.evenLighting,
    DocumentCleanupMode.magicPro,
  ]) {
    final zero = Uint8List.fromList([200, 100, 0, 128, 0, 0, 0, 0]);
    cleanDocumentRgbaInPlace(zero, 2, 1, mode: mode, amount: 0);
    check(
      zero[0] == 227 &&
          zero[1] == 177 &&
          zero[2] == 127 &&
          zero[3] == 255 &&
          zero[4] == 255 &&
          zero[5] == 255 &&
          zero[6] == 255 &&
          zero[7] == 255,
      'Zero-strength $mode must only composite onto white.',
    );
  }
  final zeroGray = Uint8List.fromList([200, 100, 50, 255]);
  cleanDocumentRgbaInPlace(
    zeroGray,
    1,
    1,
    mode: DocumentCleanupMode.grayscale,
    amount: 0,
  );
  check(
    zeroGray[0] == 124 && zeroGray[1] == 124 && zeroGray[2] == 124,
    'Grayscale remains active at zero.',
  );

  final zeroBw = Uint8List.fromList([0, 0, 0, 255, 200, 200, 200, 255]);
  cleanDocumentRgbaInPlace(
    zeroBw,
    2,
    1,
    mode: DocumentCleanupMode.adaptiveBlackAndWhite,
    amount: 0,
  );
  check(zeroBw[0] == 0 && zeroBw[4] == 255, 'B&W remains active at zero.');

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
    for (final mode in DocumentCleanupMode.values) {
      final trial = Uint8List.fromList(original);
      cleanDocumentRgbaInPlace(trial, w, h, mode: mode, amount: .5);
      for (var i = 0; i < trial.length; i += 4) {
        if (mode == DocumentCleanupMode.original) {
          check(
            trial[i] == original[i] && trial[i + 3] == original[i + 3],
            'Original changed a randomized pixel.',
          );
        } else {
          check(trial[i + 3] == 255, 'Cleanup did not flatten alpha.');
          if (mode == DocumentCleanupMode.grayscale ||
              mode == DocumentCleanupMode.adaptiveBlackAndWhite) {
            check(
              trial[i] == trial[i + 1] && trial[i + 1] == trial[i + 2],
              'Gray output changed channel equality.',
            );
          }
        }
      }
    }
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
