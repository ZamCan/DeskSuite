import 'dart:typed_data';

/// Limits memory and running time for the 3 × 3 noise filter on mobile devices.
const int maxNoiseReductionPixels = 4000000;

/// Reduces strong isolated light/dark specks in tightly packed RGBA pixels.
/// The input is changed in place; callers must use a private working copy.
///
/// This is a selective 3 × 3 luminance median, not general photo restoration.
/// Each replacement uses the original RGB of the median-luminance neighbor.
/// Borders and neighborhoods containing transparency are left untouched.
/// Thin details can be mistaken for noise; compare the result before saving.
void reduceImpulseNoiseRgbaInPlace(Uint8List pixels, int width, int height) {
  if (width < 1 ||
      height < 1 ||
      width > 8192 ||
      height > 8192 ||
      width * height > maxNoiseReductionPixels ||
      pixels.length != width * height * 4) {
    throw const FormatException(
      'Noise reduction supports images up to 4 megapixels. Resize a working copy first.',
    );
  }
  if (width < 3 || height < 3) return;

  // Read only from the pre-filter copy so neighboring replacements cannot
  // cascade. The caller's encoded source file is never used as this buffer.
  final source = Uint8List.fromList(pixels);
  final values = List<int>.filled(9, 0);
  final positions = List<int>.filled(9, 0);
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      var n = 0;
      var transparent = false;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final offset = ((y + dy) * width + x + dx) * 4;
          if (source[offset + 3] != 255) transparent = true;
          values[n] =
              (77 * source[offset] +
                  150 * source[offset + 1] +
                  29 * source[offset + 2]) >>
              8;
          positions[n] = offset;
          n++;
        }
      }
      if (transparent) continue;
      final center = values[4];
      // Insertion-sort nine entries while retaining each pixel's color.
      for (var i = 1; i < 9; i++) {
        final value = values[i], position = positions[i];
        var j = i - 1;
        while (j >= 0 && values[j] > value) {
          values[j + 1] = values[j];
          positions[j + 1] = positions[j];
          j--;
        }
        values[j + 1] = value;
        positions[j + 1] = position;
      }
      final median = values[4];
      if ((center - median).abs() < 52 || values[6] - values[2] > 50) {
        continue;
      }
      final destination = (y * width + x) * 4;
      final replacement = positions[4];
      pixels[destination] = source[replacement];
      pixels[destination + 1] = source[replacement + 1];
      pixels[destination + 2] = source[replacement + 2];
    }
  }
}
