/// Shared, allocation-free limits for raster exports from every print workflow.
/// Physical media can be large; raster memory is bounded independently.
const int maxExportPixels = 16000000;
const int maxExportSide = 8192;
const int minExportDpi = 36;
const int maxExportDpi = 600;
const double minExportPageMm = 10;
const double maxExportPageMm = 2500;
const double _mmPerInch = 25.4;

class RasterDimensions {
  const RasterDimensions(this.width, this.height);

  final int width;
  final int height;
}

/// Calculate exact requested output dimensions without allocating a raster.
/// Never silently lowers [dpi]; invalid or over-budget requests fail closed.
RasterDimensions boundedRasterDimensions(
  double widthMm,
  double heightMm,
  int dpi,
) {
  if (!widthMm.isFinite ||
      !heightMm.isFinite ||
      widthMm < minExportPageMm ||
      heightMm < minExportPageMm ||
      widthMm > maxExportPageMm ||
      heightMm > maxExportPageMm) {
    throw const FormatException('Page dimensions must be between 10 and 2500 mm.');
  }
  if (dpi < minExportDpi || dpi > maxExportDpi) {
    throw const FormatException('Resolution must be between 36 and 600 dpi.');
  }

  final width = (widthMm * dpi / _mmPerInch).round();
  final height = (heightMm * dpi / _mmPerInch).round();
  if (width < 1 ||
      height < 1 ||
      width > maxExportSide ||
      height > maxExportSide ||
      width * height > maxExportPixels) {
    throw const FormatException(
      'Output is too large for this device. Choose a lower resolution or smaller page.',
    );
  }
  return RasterDimensions(width, height);
}

/// Highest whole-number DPI at or below [preferredDpi] that fits the exact
/// pixel and side limits. Returns null if even the minimum DPI cannot fit.
/// This is a geometry limit, not a promise about device RAM or printer quality.
int? fittingRasterDpi(
  double widthMm,
  double heightMm, {
  int preferredDpi = 150,
}) {
  if (!widthMm.isFinite ||
      !heightMm.isFinite ||
      widthMm < minExportPageMm ||
      heightMm < minExportPageMm ||
      widthMm > maxExportPageMm ||
      heightMm > maxExportPageMm ||
      preferredDpi < minExportDpi ||
      preferredDpi > maxExportDpi) {
    throw const FormatException('Invalid page dimensions or preferred DPI.');
  }

  bool fits(int dpi) {
    try {
      boundedRasterDimensions(widthMm, heightMm, dpi);
      return true;
    } on FormatException {
      return false;
    }
  }

  if (!fits(minExportDpi)) return null;
  var low = minExportDpi;
  var high = preferredDpi;
  while (low < high) {
    final middle = (low + high + 1) ~/ 2;
    if (fits(middle)) {
      low = middle;
    } else {
      high = middle - 1;
    }
  }
  return low;
}
