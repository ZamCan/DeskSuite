import 'dart:math' as math;
import 'dart:typed_data';

import 'package:desksuite/document_scan/page_corner_pixels.dart';
import 'package:desksuite/document_scan/page_corner_suggestion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'page_corner_pixels_smoke.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('suggests a bright perspective page without mutating the input', () {
    const width = 256, height = 320;
    final expected = <math.Point<int>>[
      const math.Point(34, 33),
      const math.Point(222, 21),
      const math.Point(231, 291),
      const math.Point(22, 299),
    ];
    final pixels = fixture.scene(width, height, expected);
    final source = Uint8List.fromList(pixels);
    final result = suggestPageCornersRgba(pixels, width, height);
    expect(result, isNotNull);
    for (var i = 0; i < 4; i++) {
      expect(result!.points[i].x, closeTo(expected[i].x / (width - 1), .03));
      expect(result.points[i].y, closeTo(expected[i].y / (height - 1), .03));
    }
    expect(pixels, orderedEquals(source));
  });

  test('unsupported dark or border-cut pages fall back to manual corners', () {
    const w = 256, h = 320;
    final corners = <math.Point<int>>[
      const math.Point(34, 33),
      const math.Point(222, 21),
      const math.Point(231, 291),
      const math.Point(22, 299),
    ];
    expect(
      suggestPageCornersRgba(
        fixture.scene(w, h, corners, darkPaper: true),
        w,
        h,
      ),
      isNull,
    );
    final clipped = <math.Point<int>>[
      const math.Point(0, 33),
      const math.Point(222, 21),
      const math.Point(231, 291),
      const math.Point(0, 299),
    ];
    expect(suggestPageCornersRgba(fixture.scene(w, h, clipped), w, h), isNull);
    expect(
      () => suggestPageCornersRgba(Uint8List(4), 2, 1),
      throwsFormatException,
    );
  });

  test(
    'bundled angled practice image suggests the approximate page corners',
    () async {
      final data = await rootBundle.load(
        'assets/samples/angled-practice-page.jpg',
      );
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      final before = Uint8List.fromList(bytes);
      final result = suggestScanCorners(bytes);
      expect(result, isNotNull);
      final expected = [
        (250 / 1499, 195 / 1899),
        (1260 / 1499, 120 / 1899),
        (1322 / 1499, 1724 / 1899),
        (188 / 1499, 1770 / 1899),
      ];
      for (var i = 0; i < 4; i++) {
        expect(result!.points[i].x, closeTo(expected[i].$1, .035));
        expect(result.points[i].y, closeTo(expected[i].$2, .035));
      }
      expect(bytes, orderedEquals(before));
    },
  );
}
