import 'dart:math' as math;
import 'dart:typed_data';

import '../core/image_limits.dart';

/// Local document treatments, not general photo restoration. Original means
/// the page as it entered the cleanup dialog, not necessarily the imported file.
enum DocumentCleanupMode {
  original,
  lighten,
  evenLighting,
  magicPro,
  grayscale,
  adaptiveBlackAndWhite,
}

const int _maxGridSide = 24;

/// Modifies tightly packed, straight-alpha RGBA pixels in place. The caller
/// must first make a private copy. Original is an exact no-op, including alpha;
/// all other treatments composite transparency onto white. Lost text cannot be
/// inferred.
///
/// Local treatments estimate a 90th-percentile paper luminance in a bounded
/// grid. Magic Pro normalizes that illumination and applies a contrast curve;
/// it is a heuristic, not an AI model or a guarantee of shadow-free output.
/// Dense artwork, severe shadows and faint writing can be altered. [amount]
/// is 0–1 for lightening, color enhancement or B&W sensitivity; it is ignored
/// for Original and Grayscale.
void cleanDocumentRgbaInPlace(
  Uint8List pixels,
  int width,
  int height, {
  required DocumentCleanupMode mode,
  required double amount,
}) {
  // Reject invalid requests before changing a single pixel.
  if (width < 1 ||
      height < 1 ||
      width > maxPhotoSide ||
      height > maxPhotoSide ||
      width * height > maxPhotoPixels ||
      pixels.length != width * height * 4 ||
      !amount.isFinite ||
      amount < 0 ||
      amount > 1) {
    throw const FormatException('Invalid cleanup dimensions or setting.');
  }

  if (mode == DocumentCleanupMode.original) return;

  // Zero-strength color treatments only flatten transparency. Avoid allocating
  // histograms and traversing the page twice when the slider is at zero.
  // Grayscale and B&W are still active at zero: their amount has different
  // semantics, so they must not take this shortcut.
  if (amount == 0 &&
      (mode == DocumentCleanupMode.lighten ||
          mode == DocumentCleanupMode.evenLighting ||
          mode == DocumentCleanupMode.magicPro)) {
    for (var offset = 0; offset < pixels.length; offset += 4) {
      _flattenOnWhite(pixels, offset);
    }
    return;
  }

  // Simple global treatments do not need the local-paper histograms.
  if (mode == DocumentCleanupMode.lighten ||
      mode == DocumentCleanupMode.grayscale) {
    for (var offset = 0; offset < pixels.length; offset += 4) {
      _flattenOnWhite(pixels, offset);
      final r = pixels[offset], g = pixels[offset + 1], b = pixels[offset + 2];
      if (mode == DocumentCleanupMode.grayscale) {
        final luma = (77 * r + 150 * g + 29 * b) >> 8;
        pixels[offset] = pixels[offset + 1] = pixels[offset + 2] = luma;
      } else {
        // A global exposure lift, not shadow removal. Black stays black and
        // bright highlights may clip. Source colors can still be changed.
        final factor = 1 + .45 * amount;
        pixels[offset] = (r * factor).round().clamp(0, 255);
        pixels[offset + 1] = (g * factor).round().clamp(0, 255);
        pixels[offset + 2] = (b * factor).round().clamp(0, 255);
      }
    }
    return;
  }

  // At most 24 * 24 * 256 counters (~576 KiB), regardless of page size.
  final columns = math.min(_maxGridSide, math.max(1, (width + 63) ~/ 64));
  final rows = math.min(_maxGridSide, math.max(1, (height + 63) ~/ 64));
  final tileCount = columns * rows;
  final histograms = Uint32List(tileCount * 256);
  final counts = Uint32List(tileCount);

  for (var y = 0; y < height; y++) {
    final tileRow = ((y * rows) ~/ height) * columns;
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      _flattenOnWhite(pixels, offset);
      final luma =
          (77 * pixels[offset] +
              150 * pixels[offset + 1] +
              29 * pixels[offset + 2]) >>
          8;
      final tile = tileRow + (x * columns) ~/ width;
      histograms[tile * 256 + luma]++;
      counts[tile]++;
    }
  }

  final paper = Uint8List(tileCount);
  for (var tile = 0; tile < tileCount; tile++) {
    final target = (counts[tile] * 9 + 9) ~/ 10;
    var seen = 0;
    for (var value = 0; value < 256; value++) {
      seen += histograms[tile * 256 + value];
      if (seen >= target) {
        // Extremely dark image areas are not allowed to cause unbounded gains.
        paper[tile] = math.max(48, value);
        break;
      }
    }
  }

  // A quantized lookup avoids a costly power operation for every full-size
  // pixel. Background values are rounded to the nearest luminance level.
  final magicCurve = mode == DocumentCleanupMode.magicPro
      ? _makeMagicCurve()
      : null;
  final left = Uint8List(width), right = Uint8List(width);
  final horizontalMix = Float64List(width);
  for (var x = 0; x < width; x++) {
    final location = (x + .5) * columns / width - .5;
    final floor = location.floor();
    left[x] = floor.clamp(0, columns - 1);
    right[x] = (floor + 1).clamp(0, columns - 1);
    horizontalMix[x] = location - floor;
  }

  for (var y = 0; y < height; y++) {
    final location = (y + .5) * rows / height - .5;
    final floor = location.floor();
    final upper = floor.clamp(0, rows - 1) * columns;
    final lower = (floor + 1).clamp(0, rows - 1) * columns;
    final verticalMix = location - floor;
    for (var x = 0; x < width; x++) {
      final mix = horizontalMix[x];
      final top =
          paper[upper + left[x]] * (1 - mix) + paper[upper + right[x]] * mix;
      final bottom =
          paper[lower + left[x]] * (1 - mix) + paper[lower + right[x]] * mix;
      final background = top * (1 - verticalMix) + bottom * verticalMix;
      final offset = (y * width + x) * 4;
      final r = pixels[offset], g = pixels[offset + 1], b = pixels[offset + 2];
      final luma = (77 * r + 150 * g + 29 * b) >> 8;
      if (mode == DocumentCleanupMode.adaptiveBlackAndWhite) {
        // Greater sensitivity keeps more marks, but can also retain shadows.
        final threshold = background * (.55 + .33 * amount);
        final value = luma < threshold ? 0 : 255;
        pixels[offset] = value;
        pixels[offset + 1] = value;
        pixels[offset + 2] = value;
      } else if (mode == DocumentCleanupMode.magicPro) {
        // Illumination normalization followed by a contrast curve. Amplifying
        // each RGB channel equally largely preserves hue until clipping. The
        // background gain is capped; deeply obscured detail remains lost.
        final corrected = magicCurve![background.round() * 256 + luma];
        final factor = luma == 0 ? 1.0 : 1 + (corrected / luma - 1) * amount;
        pixels[offset] = (r * factor).round().clamp(0, 255);
        pixels[offset + 1] = (g * factor).round().clamp(0, 255);
        pixels[offset + 2] = (b * factor).round().clamp(0, 255);
      } else {
        // Do not darken bright pages. Limit amplification and avoid lifting
        // near-black ink as much as paper; RGB scaling retains color where it
        // does not clip. It cannot restore hidden or washed-out writing.
        final gain = (238 / background).clamp(1.0, 2.5);
        final inkProtection = ((luma - 20) / 100).clamp(0.0, 1.0);
        final factor = 1 + (gain - 1) * amount * inkProtection;
        pixels[offset] = (r * factor).round().clamp(0, 255);
        pixels[offset + 1] = (g * factor).round().clamp(0, 255);
        pixels[offset + 2] = (b * factor).round().clamp(0, 255);
      }
    }
  }
}

void _flattenOnWhite(Uint8List pixels, int offset) {
  final alpha = pixels[offset + 3];
  if (alpha == 255) return;
  final white = 255 * (255 - alpha);
  pixels[offset] = (pixels[offset] * alpha + white + 127) ~/ 255;
  pixels[offset + 1] = (pixels[offset + 1] * alpha + white + 127) ~/ 255;
  pixels[offset + 2] = (pixels[offset + 2] * alpha + white + 127) ~/ 255;
  pixels[offset + 3] = 255;
}

Uint8List _makeMagicCurve() {
  final curve = Uint8List(256 * 256);
  for (var paper = 48; paper < 256; paper++) {
    final gain = (255 / paper).clamp(1.0, 2.5);
    for (var luma = 0; luma < 256; luma++) {
      final normalized = (luma * gain / 255).clamp(0.0, 1.0);
      curve[paper * 256 + luma] = (255 * math.pow(normalized, 1.5))
          .round()
          .clamp(0, 255);
    }
  }
  return curve;
}
