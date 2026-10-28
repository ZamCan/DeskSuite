import 'dart:math' as math;

/// How a source image is scaled to a physical frame.
/// [ImagePlacementFit.contain] shows the whole image;
/// [ImagePlacementFit.cover] fills the frame and may crop it.
enum ImagePlacementFit { contain, cover }

/// Estimates source pixels per inch at the scale used to place the image.
/// This is not a printer calibration or a guarantee of visible quality.
double effectiveImageDpi(
  int imageWidth,
  int imageHeight,
  double boxWidthMm,
  double boxHeightMm, {
  ImagePlacementFit fit = ImagePlacementFit.contain,
}) {
  if (imageWidth <= 0 ||
      imageHeight <= 0 ||
      !boxWidthMm.isFinite ||
      !boxHeightMm.isFinite ||
      boxWidthMm <= 0 ||
      boxHeightMm <= 0) {
    throw const FormatException('Invalid image or placement dimensions.');
  }
  const millimetresPerInch = 25.4;
  final horizontalDpi = imageWidth * millimetresPerInch / boxWidthMm;
  final verticalDpi = imageHeight * millimetresPerInch / boxHeightMm;
  if (!horizontalDpi.isFinite || !verticalDpi.isFinite) {
    throw const FormatException('Invalid image or placement dimensions.');
  }
  return switch (fit) {
    ImagePlacementFit.contain => math.max(horizontalDpi, verticalDpi),
    ImagePlacementFit.cover => math.min(horizontalDpi, verticalDpi),
  };
}
