import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/printing/photo_specifications.dart';

void main() {
  test('custom photo specification index follows the published profile list', () {
    expect(customPhotoSpecificationIndex, photoSpecifications.length);
  });

  test('authority profiles keep passport and visa scopes separate', () {
    final passport = photoSpecifications.firstWhere((p) => p.id == 'tz-passport');
    final visa = photoSpecifications.firstWhere((p) => p.id == 'tz-evisa');
    final icao = photoSpecifications.firstWhere((p) => p.id == 'icao-mrtd-portrait');
    expect(passport.hasPublishedDimensions, isFalse);
    expect(passport.dimensionRule, PhotoDimensionRule.unspecified);
    expect(visa.dimensionRule, PhotoDimensionRule.maximum);
    expect(icao.hasPublishedDimensions, isFalse);
    expect(icao.dimensionRule, PhotoDimensionRule.unspecified);
    expect(icao.headHeightMinFraction, 0.70);
    expect(icao.headHeightMaxFraction, 0.80);
    expect(visa.maxFileBytes, 500 * 1024);
    expect(visa.fileFormats, contains('JPEG'));
  });
}
