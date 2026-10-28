import 'package:desksuite/images/compression_dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wide and tall candidates scale from the same initial dimensions', () {
    expect(compressionDimensionsAtPass(width: 2000, height: 16, pass: 10), (
      width: 697,
      height: 6,
    ));
    expect(compressionDimensionsAtPass(width: 16, height: 2000, pass: 10), (
      width: 6,
      height: 697,
    ));
  });
  test('minimum long side is preserved without enlarging small sources', () {
    expect(compressionDimensionsAtPass(width: 65, height: 1, pass: 1), (
      width: 64,
      height: 1,
    ));
    expect(compressionDimensionsAtPass(width: 10, height: 30, pass: 24), (
      width: 10,
      height: 30,
    ));
  });
  test('rejects invalid dimensions and passes', () {
    expect(
      () => compressionDimensionsAtPass(width: 0, height: 10, pass: 1),
      throwsFormatException,
    );
    expect(
      () => compressionDimensionsAtPass(width: 8193, height: 1, pass: 1),
      throwsFormatException,
    );
    expect(
      () => compressionDimensionsAtPass(width: 1, height: 1, pass: 25),
      throwsFormatException,
    );
  });
}
