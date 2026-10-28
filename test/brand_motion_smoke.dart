// Standalone: dart test/brand_motion_smoke.dart
// ignore_for_file: avoid_relative_lib_imports, avoid_print
import '../lib/app/brand_motion.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  check((brandScanFrameScale(0) - 1).abs() < .000001, 'Initial scale');
  check(brandScanFrameScale(.25) > 1.08, 'Frame did not zoom in');
  check(brandScanFrameScale(.75) < .92, 'Frame did not zoom out');
  check((brandScanFrameScale(1) - 1).abs() < .000001, 'Final scale');
  check(brandArtworkReveal(0) == 0, 'Artwork appeared too early');
  check(
    brandArtworkReveal(.7) > 0 && brandArtworkReveal(.7) < 1,
    'Artwork did not fade in',
  );
  check(brandArtworkReveal(1) == 1, 'Artwork did not fully appear');
  for (var i = -1000; i <= 2000; i++) {
    final t = i / 1000;
    final scale = brandScanFrameScale(t);
    final reveal = brandArtworkReveal(t);
    check(scale >= .909999 && scale <= 1.090001, 'Scale out of bounds');
    check(reveal >= 0 && reveal <= 1, 'Reveal out of bounds');
  }
  check(brandScanFrameScale(double.nan) == 1, 'Invalid progress handling');
  check(brandArtworkReveal(double.infinity) == 0, 'Invalid progress handling');
  print('PASS: branded launch draw/reveal and scan-frame pulse geometry.');
}
