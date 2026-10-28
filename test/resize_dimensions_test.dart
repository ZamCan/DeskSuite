import 'package:desksuite/images/resize_dimensions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'scales current dimensions with fractional percentages and rounding',
    () {
      expect(
        percentagePhotoDimensions(
          sourceWidth: 400,
          sourceHeight: 200,
          percent: 25,
        ),
        (width: 100, height: 50),
      );
      expect(
        percentagePhotoDimensions(
          sourceWidth: 3,
          sourceHeight: 1,
          percent: 333.33,
        ),
        (width: 10, height: 3),
      );
      expect(
        percentagePhotoDimensions(sourceWidth: 1, sourceHeight: 5, percent: 1),
        (width: 1, height: 1),
      );
    },
  );

  test('rejects invalid percentage and over-budget dimensions', () {
    for (final percent in [0.0, -1.0, 1001.0, double.nan, double.infinity]) {
      expect(
        () => percentagePhotoDimensions(
          sourceWidth: 100,
          sourceHeight: 200,
          percent: percent,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => percentagePhotoDimensions(
        sourceWidth: 8192,
        sourceHeight: 100,
        percent: 101,
      ),
      throwsFormatException,
    );
    expect(
      () => percentagePhotoDimensions(
        sourceWidth: 4000,
        sourceHeight: 3000,
        percent: 101,
      ),
      throwsFormatException,
    );
    expect(
      () => percentagePhotoDimensions(
        sourceWidth: 0,
        sourceHeight: 100,
        percent: 50,
      ),
      throwsFormatException,
    );
  });
}
