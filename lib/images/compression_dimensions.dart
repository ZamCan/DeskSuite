import 'dart:math' as math;

import '../core/image_limits.dart';

/// A bounded number of progressively smaller attempts for a byte-size target.
const int maxCompressionResizePasses = 24;
const int minimumCompressionLongSide = 64;

/// Calculates a candidate from the initial target, not the previously rounded
/// candidate. This avoids rounding drift on thin images and allows the pixel
/// processor to resample from its original opaque raster on every attempt. The
/// long side is not reduced below 64 px; a source already smaller is unchanged.
({int width, int height}) compressionDimensionsAtPass({
  required int width,
  required int height,
  required int pass,
}) {
  if (width < 1 ||
      height < 1 ||
      width > maxPhotoSide ||
      height > maxPhotoSide ||
      width * height > maxPhotoPixels ||
      pass < 0 ||
      pass > maxCompressionResizePasses) {
    throw const FormatException('Invalid compression dimensions or pass.');
  }
  final longestSide = math.max(width, height);
  final floor = math.min(1.0, minimumCompressionLongSide / longestSide);
  final scale = math.max(floor, math.pow(.9, pass).toDouble());
  return (
    width: math.max(1, (width * scale).round()),
    height: math.max(1, (height * scale).round()),
  );
}
