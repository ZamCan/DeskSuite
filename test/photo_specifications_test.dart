import 'package:flutter_test/flutter_test.dart';
import 'package:desksuite/printing/photo_specifications.dart';

void main() {
  test('custom profile index follows the actual registry length', () {
    expect(customPhotoSpecificationIndex, photoSpecifications.length);
  });

  test('source scopes and restrictions are not generalized', () {
    final icao = photoSpecifications.firstWhere(
      (p) => p.id == 'icao-mrtd-portrait',
    );
    final canada = photoSpecifications.firstWhere(
      (p) => p.id == 'canada-passport-paper',
    );
    final us = photoSpecifications.firstWhere(
      (p) => p.id == 'us-passport-paper',
    );
    expect(icao.headHeightMinFraction, isNull);
    expect(icao.notes, contains('portrait zone'));
    expect(icao.sourceUrl, contains('/sites/default/files/'));
    expect(
      canada.notes,
      contains('home printing and any photo editing are not accepted'),
    );
    expect(us.notes, contains('unedited photo'));
  });

  test('authority profiles keep passport and visa scopes separate', () {
    final passport = photoSpecifications.firstWhere(
      (p) => p.id == 'tz-passport',
    );
    final visa = photoSpecifications.firstWhere((p) => p.id == 'tz-evisa');
    expect(passport.hasPublishedDimensions, isFalse);
    expect(passport.dimensionRule, PhotoDimensionRule.unspecified);
    expect(visa.dimensionRule, PhotoDimensionRule.maximum);
    expect(visa.maxFileBytes, 500 * 1024);
    expect(visa.fileFormats, contains('JPEG'));
  });
}
