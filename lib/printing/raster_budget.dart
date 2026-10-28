import '../core/physical_page_limits.dart';

/// Raster output is bounded independently of the physical page size.
/// Lower DPI can make a large page exportable, but cannot create fine detail.
const int maxExportPixels = 16000000;
const int maxExportSide = 8192;
const int minExportDpi = 36;
const int maxExportDpi = 600;
const double _mmPerInch = 25.4;

class ExportDimensions {
  const ExportDimensions(this.width, this.height);
  final int width;
  final int height;
}

/// Calculates pixel dimensions or rejects a page outside the output budget.
/// This function allocates no image and never silently changes the requested DPI.
ExportDimensions boundedRasterDimensions(
  double widthMm,
  double heightMm,
  int dpi,
) {
  if (!widthMm.isFinite ||
      !heightMm.isFinite ||
      widthMm < minPhysicalPageMm ||
      heightMm < minPhysicalPageMm ||
      widthMm > maxPhysicalPageMm ||
      heightMm > maxPhysicalPageMm) {
    throw const FormatException(
      'Page dimensions must be between 10 and 2500 mm.',
    );
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
  return ExportDimensions(width, height);
}

/// Highest whole-number DPI at or below [preferredDpi] that fits the exact
/// side and pixel limits, or null when even [minExportDpi] cannot fit.
///
/// This is a calculation only, not a device-memory or print-quality guarantee.
int? fittingRasterDpi(
  double widthMm,
  double heightMm, {
  int preferredDpi = 150,
}) {
  // Validate the requested page and preferred DPI before the binary search.
  // A low-DPI page that still does not fit is a legitimate null result.
  if (!widthMm.isFinite ||
      !heightMm.isFinite ||
      widthMm < minPhysicalPageMm ||
      heightMm < minPhysicalPageMm ||
      widthMm > maxPhysicalPageMm ||
      heightMm > maxPhysicalPageMm ||
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
  var low = minExportDpi, high = preferredDpi;
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
