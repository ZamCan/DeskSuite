import 'package:desksuite/printing/image_detail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cover and contain estimate different scale for a wide image', () {
    expect(effectiveImageDpi(4000, 1000, 100, 100), closeTo(1016, 0.0001));
    expect(
      effectiveImageDpi(4000, 1000, 100, 100, fit: ImagePlacementFit.cover),
      closeTo(254, 0.0001),
    );
  });
  test('both fits agree when source and frame proportions match', () {
    expect(effectiveImageDpi(300, 150, 50.8, 25.4), closeTo(150, 0.0001));
    expect(
      effectiveImageDpi(300, 150, 50.8, 25.4, fit: ImagePlacementFit.cover),
      closeTo(150, 0.0001),
    );
  });
  test('rejects invalid physical dimensions', () {
    for (final size in [0.0, -1.0, double.nan, double.infinity, 5e-324]) {
      expect(
        () => effectiveImageDpi(100, 100, size, 100),
        throwsFormatException,
      );
      expect(
        () => effectiveImageDpi(100, 100, 100, size),
        throwsFormatException,
      );
    }
    expect(() => effectiveImageDpi(0, 1, 100, 100), throwsFormatException);
    expect(() => effectiveImageDpi(1, 0, 100, 100), throwsFormatException);
  });
}
