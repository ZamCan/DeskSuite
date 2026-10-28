import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/images/print_dimensions.dart';

void main() {
  group('pixelsFromMillimetres', () {
    test('converts millimetres to pixels using the requested DPI', () {
      expect(pixelsFromMillimetres(25.4, 300), 300);
      expect(pixelsFromMillimetres(50.8, 150), 300);
      expect(pixelsFromMillimetres(210, 300), 2480);
    });

    test('rejects non-finite, non-positive and excessive dimensions', () {
      expect(() => pixelsFromMillimetres(0, 300), throwsFormatException);
      expect(() => pixelsFromMillimetres(-1, 300), throwsFormatException);
      expect(
        () => pixelsFromMillimetres(double.infinity, 300),
        throwsFormatException,
      );
      expect(() => pixelsFromMillimetres(2000, 2400), throwsFormatException);
      expect(() => pixelsFromMillimetres(25.4, 0), throwsFormatException);
      expect(() => pixelsFromMillimetres(25.4, 2401), throwsFormatException);
    });
  });

  group('printDimensionsToPixels', () {
    test('converts both sides and accepts a bounded print output', () {
      expect(printDimensionsToPixels(widthMm: 50.8, heightMm: 25.4, dpi: 300), (
        width: 600,
        height: 300,
      ));
    });

    test('rejects output beyond the shared 12-megapixel budget', () {
      expect(
        () => printDimensionsToPixels(widthMm: 300, heightMm: 300, dpi: 300),
        throwsFormatException,
      );
    });
  });
}
