// Standalone check: dart test/compression_dimensions_smoke.dart
// ignore_for_file: avoid_print, avoid_relative_lib_imports
import 'dart:math' as math;

import '../lib/images/compression_dimensions.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  check(
    compressionDimensionsAtPass(width: 2000, height: 16, pass: 10) ==
        (width: 697, height: 6),
    'wide image is derived from initial dimensions',
  );
  check(
    compressionDimensionsAtPass(width: 16, height: 2000, pass: 10) ==
        (width: 6, height: 697),
    'tall image is derived from initial dimensions',
  );
  check(
    compressionDimensionsAtPass(width: 65, height: 1, pass: 1) ==
        (width: 64, height: 1),
    'long-side floor',
  );
  check(
    compressionDimensionsAtPass(width: 24, height: 12, pass: 20) ==
        (width: 24, height: 12),
    'small images are not enlarged or reduced',
  );
  final random = math.Random(401);
  for (var i = 0; i < 2000; i++) {
    final width = 1 + random.nextInt(4000), height = 1 + random.nextInt(3000);
    var prior = (width: width, height: height);
    for (var pass = 1; pass <= maxCompressionResizePasses; pass++) {
      final next = compressionDimensionsAtPass(
        width: width,
        height: height,
        pass: pass,
      );
      check(next.width <= prior.width && next.height <= prior.height, 'growth');
      check(next.width >= 1 && next.height >= 1, 'zero side');
      check(
        math.max(next.width, next.height) >=
            math.min(minimumCompressionLongSide, math.max(width, height)),
        'long-side floor',
      );
      prior = next;
    }
  }
  for (final invalid in [
    (width: 0, height: 10, pass: 1),
    (width: 8193, height: 1, pass: 1),
    (width: 4000, height: 3001, pass: 1),
    (width: 10, height: 10, pass: -1),
    (width: 10, height: 10, pass: 25),
  ]) {
    var rejected = false;
    try {
      compressionDimensionsAtPass(
        width: invalid.width,
        height: invalid.height,
        pass: invalid.pass,
      );
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'invalid input $invalid');
  }
  print(
    'PASS: bounded compression geometry, wide/tall cases and 2000 sequences.',
  );
}
