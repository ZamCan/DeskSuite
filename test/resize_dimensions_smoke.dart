// Standalone dependency-free check: dart test/resize_dimensions_smoke.dart
// ignore_for_file: avoid_print, avoid_relative_lib_imports
import '../lib/images/resize_dimensions.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  check(
    percentagePhotoDimensions(
          sourceWidth: 400,
          sourceHeight: 200,
          percent: 25,
        ) ==
        (width: 100, height: 50),
    '25 percent',
  );
  check(
    percentagePhotoDimensions(
          sourceWidth: 3,
          sourceHeight: 1,
          percent: 333.33,
        ) ==
        (width: 10, height: 3),
    'small-image rounding',
  );
  check(
    percentagePhotoDimensions(sourceWidth: 1, sourceHeight: 5, percent: 1) ==
        (width: 1, height: 1),
    'minimum one pixel',
  );
  for (final invalid in [0.0, -1.0, 1001.0, double.nan, double.infinity]) {
    var rejected = false;
    try {
      percentagePhotoDimensions(
        sourceWidth: 100,
        sourceHeight: 200,
        percent: invalid,
      );
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'invalid percentage $invalid');
  }
  for (final input in [
    (width: 0, height: 10, percent: 50.0),
    (width: 8192, height: 100, percent: 101.0),
    (width: 4000, height: 3000, percent: 101.0),
  ]) {
    var rejected = false;
    try {
      percentagePhotoDimensions(
        sourceWidth: input.width,
        sourceHeight: input.height,
        percent: input.percent,
      );
    } on FormatException {
      rejected = true;
    }
    check(rejected, 'invalid or oversized dimensions $input');
  }
  print(
    'PASS: percentage resizing, rounding, invalid inputs and output limits.',
  );
}
