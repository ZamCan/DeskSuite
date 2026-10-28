import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/printing/photo_specifications.dart';

void main() {
  test('authority profiles keep passport and visa scopes separate', () {
    final passport = photoSpecifications.firstWhere((p) => p.id == 'tz-passport');
    final visa = photoSpecifications.firstWhere((p) => p.id == 'tz-evisa');
    expect(passport.hasPublishedDimensions, isFalse);
    expect(passport.dimensionRule, PhotoDimensionRule.unspecified);
    expect(visa.dimensionRule, PhotoDimensionRule.maximum);
    expect(visa.maxFileBytes, 500 * 1024);
    expect(visa.fileFormats, contains('JPEG'));
  });
}
