import 'dart:typed_data';

import 'package:desksuite/document_scan/scan_processor.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List coordinateImage() {
  final image = img.Image(width: 101, height: 101, numChannels: 4);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgba(x, y, x * 2, y * 2, 0, 255);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  test(
    'full-page correction preserves dimensions, corner pixels and source',
    () {
      final source = coordinateImage();
      final copy = Uint8List.fromList(source);
      final result = processScan(ScanRequest(source));
      expect([result.width, result.height], [101, 101]);
      final decoded = img.decodePng(result.bytes)!;
      expect([decoded.getPixel(0, 0).r, decoded.getPixel(0, 0).g], [0, 0]);
      expect(
        [decoded.getPixel(100, 100).r, decoded.getPixel(100, 100).g],
        [200, 200],
      );
      expect(source, orderedEquals(copy));
    },
  );

  test('manual crop performs real projective correction of a trapezoid', () {
    final source = coordinateImage();
    const corners = ScanCorners(
      ScanPoint(.2, .1),
      ScanPoint(.8, .1),
      ScanPoint(.9, .9),
      ScanPoint(.1, .9),
    );
    final result = processScan(ScanRequest(source, corners: corners));
    final decoded = img.decodePng(result.bytes)!;
    expect(result.width, 81);
    expect(result.height, greaterThanOrEqualTo(81));
    // Source encodes red = 2*x, green = 2*y. Corners land at the
    // selected source coordinates, and the middle is projective, not a
    // bilinear/affine average of the top and bottom widths.
    expect(decoded.getPixel(0, 0).r, closeTo(40, 2));
    expect(decoded.getPixel(0, 0).g, closeTo(20, 2));
    expect(
      decoded.getPixel(result.width - 1, result.height - 1).r,
      closeTo(180, 2),
    );
    expect(
      decoded.getPixel(result.width - 1, result.height - 1).g,
      closeTo(180, 2),
    );
    final center = decoded.getPixel(result.width ~/ 2, result.height ~/ 2);
    // The trapezoid narrows at the top, so the projective midpoint samples
    // y≈44.3 rather than the affine/bilinear y=50.
    expect(center.g, inInclusiveRange(86, 92));
  });

  test('known A4 proportions are applied without inventing extra detail', () {
    final result = processScan(
      ScanRequest(coordinateImage(), outputAspect: 210 / 297),
    );
    expect(result.width / result.height, closeTo(210 / 297, .01));
    expect(result.width * result.height, closeTo(101 * 101, 150));
    expect(
      () =>
          processScan(ScanRequest(coordinateImage(), outputAspect: double.nan)),
      throwsFormatException,
    );
  });

  test('grayscale and threshold really change output pixels', () {
    final source = coordinateImage();
    final gray = img.decodePng(
      processScan(ScanRequest(source, tone: ScanTone.grayscale)).bytes,
    )!;
    final g = gray.getPixel(70, 20);
    expect(g.r, g.g);
    expect(g.g, g.b);
    final bw = img.decodePng(
      processScan(ScanRequest(source, tone: ScanTone.blackAndWhite)).bytes,
    )!;
    expect(bw.getPixel(0, 0).r, 0);
    expect(bw.getPixel(100, 100).r, 255);
  });

  test(
    'rejects crossed, degenerate, out-of-range and invalid image inputs',
    () {
      final source = coordinateImage();
      const bad = [
        ScanCorners(
          ScanPoint(0, 0),
          ScanPoint(1, 1),
          ScanPoint(1, 0),
          ScanPoint(0, 1),
        ),
        ScanCorners(
          ScanPoint(0, 0),
          ScanPoint(.5, 0),
          ScanPoint(1, 0),
          ScanPoint(0, 1),
        ),
        ScanCorners(
          ScanPoint(-.1, 0),
          ScanPoint(1, 0),
          ScanPoint(1, 1),
          ScanPoint(0, 1),
        ),
        ScanCorners(
          ScanPoint(0, 0),
          ScanPoint(.01, 0),
          ScanPoint(.01, .01),
          ScanPoint(0, .01),
        ),
      ];
      for (final corners in bad) {
        expect(
          () => processScan(ScanRequest(source, corners: corners)),
          throwsFormatException,
        );
      }
      expect(
        () => processScan(ScanRequest(Uint8List.fromList([1, 2, 3]))),
        throwsFormatException,
      );
      final gif = Uint8List.fromList(
        img.encodeGif(img.Image(width: 2, height: 2)),
      );
      expect(
        () => processPhoto(PhotoRequest(gif, PhotoAction.inspect)),
        throwsFormatException,
      );
    },
  );
}
