import 'package:desksuite/printing/paper_catalog.dart';
import 'package:desksuite/printing/raster_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every print preset has a safe raster option at or below 150 dpi', () {
    for (final paper in paperSheetPresets) {
      final dpi = fittingRasterDpi(paper.widthMm, paper.heightMm);
      expect(dpi, isNotNull, reason: paper.label);
      final selected = dpi!;
      final dimensions = boundedRasterDimensions(
        paper.widthMm,
        paper.heightMm,
        selected,
      );
      expect(dimensions.width, lessThanOrEqualTo(maxExportSide), reason: paper.label);
      expect(dimensions.height, lessThanOrEqualTo(maxExportSide), reason: paper.label);
      expect(
        dimensions.width * dimensions.height,
        lessThanOrEqualTo(maxExportPixels),
        reason: paper.label,
      );
      if (selected < 150) {
        expect(
          () => boundedRasterDimensions(paper.widthMm, paper.heightMm, selected + 1),
          throwsFormatException,
          reason: 'Must choose the highest fitting DPI for ${paper.label}',
        );
      }
    }
  });

  test('A4 pixel geometry is exact and requested DPI is preserved', () {
    final dimensions = boundedRasterDimensions(210, 297, 300);
    expect(dimensions.width, 2480);
    expect(dimensions.height, 3508);
    expect(fittingRasterDpi(210, 297, preferredDpi: 300), 300);
  });

  test('rejects invalid dimensions, invalid DPI and oversized rasters', () {
    expect(() => boundedRasterDimensions(210, 297, 35), throwsFormatException);
    expect(() => boundedRasterDimensions(double.nan, 297, 150), throwsFormatException);
    expect(() => boundedRasterDimensions(2501, 100, 150), throwsFormatException);
    expect(() => boundedRasterDimensions(1219.2, 1828.8, 150), throwsFormatException);
    expect(
      () => fittingRasterDpi(210, 297, preferredDpi: 601),
      throwsFormatException,
    );
    final posterDpi = fittingRasterDpi(1219.2, 1828.8);
    expect(posterDpi, isNotNull);
    expect(posterDpi, lessThan(150));
    expect(
      () => boundedRasterDimensions(1219.2, 1828.8, posterDpi!),
      returnsNormally,
    );
  });
}
