// Standalone dependency-free smoke check: dart test/page_corner_pixels_smoke.dart
// ignore_for_file: avoid_relative_lib_imports, avoid_print
import 'dart:math' as math;
import 'dart:typed_data';

import '../lib/document_scan/page_corner_pixels.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Uint8List scene(
  int width,
  int height,
  List<math.Point<int>> corners, {
  bool darkPaper = false,
}) {
  final data = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var inside = true;
      for (var i = 0; i < 4; i++) {
        final a = corners[i], b = corners[(i + 1) % 4];
        if ((b.x - a.x) * (y - a.y) - (b.y - a.y) * (x - a.x) < 0) {
          inside = false;
          break;
        }
      }
      var value = inside ? 128 + 80 * x ~/ width : 45;
      if (darkPaper) value = inside ? 40 : 220;
      if (inside && x > width ~/ 3 && x < width * 3 ~/ 4 && y % 35 < 3) {
        value = darkPaper ? 30 : 28; // Short text-like marks, not a cut.
      }
      final i = (y * width + x) * 4;
      data[i] = data[i + 1] = data[i + 2] = value;
      data[i + 3] = 255;
    }
  }
  return data;
}

void main() {
  const width = 256, height = 320;
  final corners = <math.Point<int>>[
    const math.Point(34, 33),
    const math.Point(222, 21),
    const math.Point(231, 291),
    const math.Point(22, 299),
  ];
  final pixels = scene(width, height, corners);
  final original = Uint8List.fromList(pixels);
  final result = suggestPageCornersRgba(pixels, width, height);
  check(result != null, 'High-contrast page was not suggested.');
  for (var i = 0; i < 4; i++) {
    check(
      (result!.points[i].x - corners[i].x / (width - 1)).abs() < .03 &&
          (result.points[i].y - corners[i].y / (height - 1)).abs() < .03,
      'Suggested corner $i is too far from the synthetic page.',
    );
  }
  check(
    List.generate(
      pixels.length,
      (i) => pixels[i] == original[i],
    ).every((x) => x),
    'Detector changed the input thumbnail.',
  );
  final blank = Uint8List(width * height * 4);
  for (var i = 0; i < blank.length; i += 4) {
    blank[i] = blank[i + 1] = blank[i + 2] = 180;
    blank[i + 3] = 255;
  }
  check(
    suggestPageCornersRgba(blank, width, height) == null,
    'Blank page matched.',
  );
  check(
    suggestPageCornersRgba(
          scene(width, height, corners, darkPaper: true),
          width,
          height,
        ) ==
        null,
    'Unsupported dark page produced a suggestion.',
  );
  final cutOff = <math.Point<int>>[
    const math.Point(0, 33),
    const math.Point(222, 21),
    const math.Point(231, 291),
    const math.Point(0, 299),
  ];
  check(
    suggestPageCornersRgba(scene(width, height, cutOff), width, height) == null,
    'A page touching the image border produced a suggestion.',
  );
  var rejected = false;
  try {
    suggestPageCornersRgba(Uint8List(4), 2, 1);
  } on FormatException {
    rejected = true;
  }
  check(rejected, 'Invalid thumbnail dimensions were accepted.');
  print('PASS: page-corner suggestion synthetic and fallback smoke checks.');
}
