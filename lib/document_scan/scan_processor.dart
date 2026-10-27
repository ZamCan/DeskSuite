import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../images/photo_processor.dart';

/// Normalized coordinates in an orientation-corrected image, from 0 through 1.
class ScanPoint {
  const ScanPoint(this.x, this.y);
  final double x;
  final double y;
}

/// Corners are ordered clockwise, beginning at the intended top-left corner.
class ScanCorners {
  const ScanCorners(
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
  );

  const ScanCorners.full()
    : topLeft = const ScanPoint(0, 0),
      topRight = const ScanPoint(1, 0),
      bottomRight = const ScanPoint(1, 1),
      bottomLeft = const ScanPoint(0, 1);

  final ScanPoint topLeft, topRight, bottomRight, bottomLeft;

  List<ScanPoint> get points => [topLeft, topRight, bottomRight, bottomLeft];

  void validate() {
    final p = points;
    for (final point in p) {
      if (!point.x.isFinite ||
          !point.y.isFinite ||
          point.x < 0 ||
          point.x > 1 ||
          point.y < 0 ||
          point.y > 1) {
        throw const FormatException('Keep all corners inside the image.');
      }
    }
    // A consistent positive cross product ensures a convex, clockwise
    // quadrilateral in image coordinates (where y increases downwards).
    for (var i = 0; i < 4; i++) {
      final a = p[i], b = p[(i + 1) % 4], c = p[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross <= .00001) {
        throw const FormatException(
          'Corners must form a non-overlapping page in clockwise order.',
        );
      }
    }
    var area = 0.0;
    for (var i = 0; i < 4; i++) {
      final a = p[i], b = p[(i + 1) % 4];
      area += a.x * b.y - b.x * a.y;
    }
    if (area.abs() < .01) {
      throw const FormatException('The selected page is too small.');
    }
  }
}

enum ScanTone { color, grayscale, blackAndWhite }

class ScanRequest {
  const ScanRequest(
    this.bytes, {
    this.corners = const ScanCorners.full(),
    this.tone = ScanTone.color,
    this.outputAspect,
  });
  final Uint8List bytes;
  final ScanCorners corners;
  final ScanTone tone;

  /// Optional output width/height ratio, for known paper proportions.
  final double? outputAspect;
}

Future<PhotoResult> processScanInBackground(ScanRequest request) =>
    compute(processScan, request);

/// Corrects a manually selected quadrilateral with a projective homography,
/// not a perspective-looking visual overlay. Always returns a new PNG.
PhotoResult processScan(ScanRequest request) {
  request.corners.validate();
  final decoded = decodeBoundedPhoto(
    request.bytes,
    byteLimit: maxPhotoWorkingBytes,
  );
  // Linear sampling requires actual color channels rather than palette indices.
  final source = decoded.hasPalette || decoded.format != img.Format.uint8
      ? decoded.convert(format: img.Format.uint8, numChannels: 4)
      : decoded;
  if (source.width < 2 || source.height < 2) {
    throw const FormatException('Page image must be at least 2 × 2 pixels.');
  }
  final p = request.corners.points
      .map(
        (c) => math.Point(c.x * (source.width - 1), c.y * (source.height - 1)),
      )
      .toList(growable: false);
  final p0 = p[0], p1 = p[1], p2 = p[2], p3 = p[3];
  var width = (math.max(p0.distanceTo(p1), p3.distanceTo(p2))).round() + 1;
  var height = (math.max(p0.distanceTo(p3), p1.distanceTo(p2))).round() + 1;
  final aspect = request.outputAspect;
  if (aspect != null) {
    if (!aspect.isFinite || aspect < .2 || aspect > 5) {
      throw const FormatException('Invalid output page proportions.');
    }
    // Preserve approximately the sampled pixel area; one axis can be
    // interpolated when the selected paper ratio differs from the estimate.
    final area = width * height;
    width = math.sqrt(area * aspect).round();
    height = (width / aspect).round();
  }
  if (width < 2 ||
      height < 2 ||
      width > maxPhotoSide ||
      height > maxPhotoSide ||
      width * height > maxPhotoPixels) {
    throw const FormatException(
      'Corrected page exceeds the image dimension limits.',
    );
  }

  // Unit square -> source quadrilateral. This is the inverse mapping needed
  // when sampling each output pixel. For parallelograms, the projective terms
  // are zero; for other convex quadrilaterals they produce true perspective.
  final dx1 = p1.x - p2.x, dx2 = p3.x - p2.x;
  final dy1 = p1.y - p2.y, dy2 = p3.y - p2.y;
  final dx3 = p0.x - p1.x + p2.x - p3.x;
  final dy3 = p0.y - p1.y + p2.y - p3.y;
  var g = 0.0, h = 0.0;
  if (dx3.abs() > 1e-9 || dy3.abs() > 1e-9) {
    final determinant = dx1 * dy2 - dx2 * dy1;
    if (determinant.abs() < 1e-9) {
      throw const FormatException('The selected page cannot be corrected.');
    }
    g = (dx3 * dy2 - dx2 * dy3) / determinant;
    h = (dx1 * dy3 - dx3 * dy1) / determinant;
  }
  final a = p1.x - p0.x + g * p1.x;
  final b = p3.x - p0.x + h * p3.x;
  final d = p1.y - p0.y + g * p1.y;
  final e = p3.y - p0.y + h * p3.y;
  final out = img.Image(width: width, height: height, numChannels: 4);
  for (var y = 0; y < height; y++) {
    final v = y / (height - 1);
    for (var x = 0; x < width; x++) {
      final u = x / (width - 1);
      final denominator = g * u + h * v + 1;
      if (denominator.abs() < 1e-9) {
        throw const FormatException('The selected page cannot be corrected.');
      }
      final sx = ((a * u + b * v + p0.x) / denominator).clamp(
        0,
        source.width - 1,
      );
      final sy = ((d * u + e * v + p0.y) / denominator).clamp(
        0,
        source.height - 1,
      );
      out.setPixel(x, y, source.getPixelInterpolate(sx, sy));
    }
  }
  if (request.tone != ScanTone.color) {
    img.grayscale(out);
    if (request.tone == ScanTone.blackAndWhite) {
      for (final pixel in out) {
        final value = pixel.r >= 160 ? 255 : 0;
        pixel
          ..r = value
          ..g = value
          ..b = value;
      }
    }
  }
  final bytes = Uint8List.fromList(img.encodePng(out, level: 3));
  return validateEncodedPhoto(bytes, width, height, PhotoFormat.png);
}
