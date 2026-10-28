import '../core/image_limits.dart';

/// Physical image sizing helpers shared by editors and print workflows.
///
/// Pixel dimensions are derived from physical millimetres and dots per inch.
/// This does not embed DPI metadata in the exported image or calibrate a printer.
int pixelsFromMillimetres(double millimetres, int dpi) {
  if (!millimetres.isFinite || millimetres <= 0 || millimetres > 2000) {
    throw const FormatException(
      'Physical size must be greater than 0 and at most 2000 mm.',
    );
  }
  if (dpi < 1 || dpi > 2400) {
    throw const FormatException('Resolution must be between 1 and 2400 DPI.');
  }
  final pixels = (millimetres * dpi / 25.4).round();
  if (pixels < 1 || pixels > maxPhotoSide) {
    throw const FormatException(
      'Output side must be between 1 and 8192 pixels.',
    );
  }
  return pixels;
}

/// Converts a print rectangle to pixels and rejects outputs that exceed the
/// shared image pipeline's 12-megapixel limit.
({int width, int height}) printDimensionsToPixels({
  required double widthMm,
  required double heightMm,
  required int dpi,
}) {
  final width = pixelsFromMillimetres(widthMm, dpi);
  final height = pixelsFromMillimetres(heightMm, dpi);
  if (width * height > maxPhotoPixels) {
    throw const FormatException('Output exceeds 12 megapixels.');
  }
  return (width: width, height: height);
}
