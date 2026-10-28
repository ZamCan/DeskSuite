import 'package:desksuite/printing/paper_catalog.dart';
import 'package:desksuite/printing/raster_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every paper preset has a bounded lower-DPI raster option', () {
    for (final paper in paperSheetPresets) {
      final dpi = fittingRasterDpi(paper.widthMm, paper.heightMm);
      expect(dpi, isNotNull, reason: paper.label);
      final selectedDpi = dpi!;
      final dimensions = boundedRasterDimensions(
        paper.widthMm,
        paper.heightMm,
        selectedDpi,
      );
      expect(dimensions.width, lessThanOrEqualTo(maxExportSide));
      expect(dimensions.height, lessThanOrEqualTo(maxExportSide));
      expect(
        dimensions.width * dimensions.height,
        lessThanOrEqualTo(maxExportPixels),
      );
      if (selectedDpi < 150) {
        expect(
          () => boundedRasterDimensions(
            paper.widthMm,
            paper.heightMm,
            selectedDpi + 1,
          ),
          throwsFormatException,
          reason: 'Must choose the highest fitting DPI for ${paper.label}',
        );
      }
    }
  });

  test('rejects invalid inputs and does not silently lower requested DPI', () {
    expect(() => boundedRasterDimensions(210, 297, 35), throwsFormatException);
    expect(
      () => boundedRasterDimensions(double.nan, 297, 150),
      throwsFormatException,
    );
    expect(
      () => boundedRasterDimensions(2501, 100, 150),
      throwsFormatException,
    );
    expect(
      () => boundedRasterDimensions(1219.2, 1828.8, 150),
      throwsFormatException,
    );
    expect(fittingRasterDpi(210, 297, preferredDpi: 300), 300);
    final reduced = fittingRasterDpi(1219.2, 1828.8)!;
    expect(reduced, lessThan(150));
    expect(
      () => boundedRasterDimensions(1219.2, 1828.8, reduced),
      returnsNormally,
    );
  });
}
