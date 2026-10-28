import 'dart:math' as math;

import '../core/image_limits.dart';

const double minPhotoScalePercent = 1;
const double maxPhotoScalePercent = 1000;

/// Calculates rounded dimensions as a percentage of the current working image.
/// Each side is at least one pixel; rounding can slightly alter proportions on
/// very small images. No pixels are allocated and an over-budget result throws.
({int width, int height}) percentagePhotoDimensions({
  required int sourceWidth,
  required int sourceHeight,
  required double percent,
}) {
  if (sourceWidth < 1 ||
      sourceHeight < 1 ||
      sourceWidth > maxPhotoSide ||
      sourceHeight > maxPhotoSide ||
      sourceWidth * sourceHeight > maxPhotoPixels) {
    throw const FormatException('Invalid or oversized source image.');
  }
  if (!percent.isFinite ||
      percent < minPhotoScalePercent ||
      percent > maxPhotoScalePercent) {
    throw const FormatException('Use a percentage from 1 to 1000.');
  }
  final width = math.max(1, (sourceWidth * percent / 100).round());
  final height = math.max(1, (sourceHeight * percent / 100).round());
  if (width > maxPhotoSide || height > maxPhotoSide) {
    throw const FormatException('Output side exceeds 8192 pixels.');
  }
  if (width * height > maxPhotoPixels) {
    throw const FormatException('Output exceeds 12 megapixels.');
  }
  return (width: width, height: height);
}
