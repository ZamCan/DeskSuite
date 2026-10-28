import 'dart:typed_data';

import 'package:desksuite/document_scan/document_cleanup.dart';
import 'package:desksuite/document_scan/document_cleanup_pixels.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List unevenPixels() {
  const width = 128, height = 64;
  final pixels = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final offset = (y * width + x) * 4;
      final paper = x < 64 ? 120 : 240;
      final value = y == 30 ? paper ~/ 4 : paper;
      pixels[offset] = value;
      pixels[offset + 1] = value;
      pixels[offset + 2] = value;
      pixels[offset + 3] = 255;
    }
  }
  return pixels;
}

int grayAt(Uint8List pixels, int width, int x, int y) =>
    pixels[(y * width + x) * 4];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('lighting lifts shadowed paper without lifting dark ink as much', () {
    final pixels = unevenPixels();
    cleanDocumentRgbaInPlace(
      pixels,
      128,
      64,
      mode: DocumentCleanupMode.evenLighting,
      amount: 1,
    );
    expect(grayAt(pixels, 128, 10, 10), greaterThan(225));
    expect(grayAt(pixels, 128, 100, 10), 240);
    expect(grayAt(pixels, 128, 10, 30), lessThan(35));
  });

  test('Original preserves bytes and alpha; Lighten is adjustable', () {
    final original = Uint8List.fromList([100, 80, 60, 128, 0, 0, 0, 255]);
    final untouched = Uint8List.fromList(original);
    cleanDocumentRgbaInPlace(
      original,
      2,
      1,
      mode: DocumentCleanupMode.original,
      amount: 1,
    );
    expect(original, orderedEquals(untouched));

    final input = Uint8List.fromList([100, 80, 60, 255, 0, 0, 0, 255]);
    final noLift = Uint8List.fromList(input);
    final bright = Uint8List.fromList(input);
    cleanDocumentRgbaInPlace(
      noLift,
      2,
      1,
      mode: DocumentCleanupMode.lighten,
      amount: 0,
    );
    cleanDocumentRgbaInPlace(
      bright,
      2,
      1,
      mode: DocumentCleanupMode.lighten,
      amount: 1,
    );
    expect(noLift, orderedEquals(input));
    expect(bright, [145, 116, 87, 255, 0, 0, 0, 255]);
  });

  test('zero-strength color modes only flatten transparency', () {
    for (final mode in [
      DocumentCleanupMode.lighten,
      DocumentCleanupMode.evenLighting,
      DocumentCleanupMode.magicPro,
    ]) {
      final pixels = Uint8List.fromList([200, 100, 0, 128, 0, 0, 0, 0]);
      cleanDocumentRgbaInPlace(pixels, 2, 1, mode: mode, amount: 0);
      expect(pixels, [
        227,
        177,
        127,
        255,
        255,
        255,
        255,
        255,
      ], reason: mode.name);
    }
  });

  test('Magic Pro normalizes shaded paper and keeps dark text and color', () {
    final pixels = unevenPixels();
    final chart = (15 * 128 + 15) * 4;
    pixels.setRange(chart, chart + 4, [35, 90, 50, 255]);
    final zero = Uint8List.fromList(pixels);
    final strong = Uint8List.fromList(pixels);
    cleanDocumentRgbaInPlace(
      zero,
      128,
      64,
      mode: DocumentCleanupMode.magicPro,
      amount: 0,
    );
    cleanDocumentRgbaInPlace(
      strong,
      128,
      64,
      mode: DocumentCleanupMode.magicPro,
      amount: 1,
    );
    expect(zero, orderedEquals(pixels));
    expect(grayAt(strong, 128, 10, 10), greaterThan(245));
    expect(grayAt(strong, 128, 100, 10), greaterThan(245));
    expect(grayAt(strong, 128, 10, 30), lessThan(45));
    expect(strong[chart + 1], greaterThan(strong[chart]));
    expect(strong[chart + 1], greaterThan(strong[chart + 2]));
  });

  test('Grayscale uses luminance and flattens transparency', () {
    final pixels = Uint8List.fromList([200, 100, 50, 255, 0, 0, 0, 0]);
    cleanDocumentRgbaInPlace(
      pixels,
      2,
      1,
      mode: DocumentCleanupMode.grayscale,
      amount: .7,
    );
    expect(pixels, [124, 124, 124, 255, 255, 255, 255, 255]);
  });

  test('adaptive B&W uses local paper and adjustable mark sensitivity', () {
    final pixels = unevenPixels();
    cleanDocumentRgbaInPlace(
      pixels,
      128,
      64,
      mode: DocumentCleanupMode.adaptiveBlackAndWhite,
      amount: .7,
    );
    expect(grayAt(pixels, 128, 10, 10), 255);
    expect(grayAt(pixels, 128, 100, 10), 255);
    expect(grayAt(pixels, 128, 10, 30), 0);
    expect(grayAt(pixels, 128, 100, 30), 0);
    for (var i = 0; i < pixels.length; i += 4) {
      expect(pixels[i], anyOf(0, 255));
      expect(pixels[i + 1], pixels[i]);
      expect(pixels[i + 2], pixels[i]);
      expect(pixels[i + 3], 255);
    }

    final paleMark = Uint8List(7 * 7 * 4);
    for (var i = 0; i < 49; i++) {
      paleMark.setRange(i * 4, i * 4 + 4, [200, 200, 200, 255]);
    }
    paleMark.setRange((3 * 7 + 3) * 4, (3 * 7 + 3) * 4 + 4, [
      140,
      140,
      140,
      255,
    ]);
    final low = Uint8List.fromList(paleMark);
    final high = Uint8List.fromList(paleMark);
    cleanDocumentRgbaInPlace(
      low,
      7,
      7,
      mode: DocumentCleanupMode.adaptiveBlackAndWhite,
      amount: 0,
    );
    cleanDocumentRgbaInPlace(
      high,
      7,
      7,
      mode: DocumentCleanupMode.adaptiveBlackAndWhite,
      amount: 1,
    );
    expect(grayAt(low, 7, 3, 3), 255);
    expect(grayAt(high, 7, 3, 3), 0);
  });

  test('transparency flattens to white and invalid requests do not mutate', () {
    final transparent = Uint8List.fromList([0, 0, 0, 0]);
    cleanDocumentRgbaInPlace(
      transparent,
      1,
      1,
      mode: DocumentCleanupMode.evenLighting,
      amount: 0,
    );
    expect(transparent, [255, 255, 255, 255]);
    final invalid = Uint8List.fromList([1, 2, 3, 4]);
    for (final amount in [-1.0, 2.0, double.nan, double.infinity]) {
      expect(
        () => cleanDocumentRgbaInPlace(
          invalid,
          1,
          1,
          mode: DocumentCleanupMode.evenLighting,
          amount: amount,
        ),
        throwsFormatException,
      );
      expect(invalid, [1, 2, 3, 4]);
    }
    expect(
      () => cleanDocumentRgbaInPlace(
        invalid,
        2,
        1,
        mode: DocumentCleanupMode.evenLighting,
        amount: 1,
      ),
      throwsFormatException,
    );
    expect(invalid, [1, 2, 3, 4]);
  });

  test(
    'image wrapper writes a new valid PNG and leaves the encoded source intact',
    () {
      final sourcePixels = unevenPixels();
      final image = img.Image.fromBytes(
        width: 128,
        height: 64,
        bytes: sourcePixels.buffer,
        numChannels: 4,
      );
      final input = Uint8List.fromList(img.encodePng(image));
      final original = Uint8List.fromList(input);
      final unchanged = processDocumentCleanup(
        DocumentCleanupRequest(input, mode: DocumentCleanupMode.original),
      );
      expect(unchanged.bytes, orderedEquals(input));
      expect(identical(unchanged.bytes, input), isFalse);
      final result = processDocumentCleanup(
        DocumentCleanupRequest(
          input,
          mode: DocumentCleanupMode.evenLighting,
          amount: 1,
        ),
      );
      expect(result.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      expect([result.width, result.height], [128, 64]);
      expect(img.decodePng(result.bytes)!.getPixel(10, 10).r, greaterThan(225));
      expect(img.decodePng(input)!.getPixel(10, 10).r, 120);
      expect(input, orderedEquals(original));
      expect(
        () => processDocumentCleanup(
          DocumentCleanupRequest(
            Uint8List.fromList([1, 2, 3]),
            mode: DocumentCleanupMode.evenLighting,
          ),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'background worker produces the same pixels as the synchronous engine',
    () async {
      final input = Uint8List.fromList(
        img.encodePng(
          img.Image.fromBytes(
            width: 128,
            height: 64,
            bytes: unevenPixels().buffer,
            numChannels: 4,
          ),
        ),
      );
      final request = DocumentCleanupRequest(
        input,
        mode: DocumentCleanupMode.adaptiveBlackAndWhite,
      );
      final sync = processDocumentCleanup(request);
      final worker = await processDocumentCleanupInBackground(request);
      expect(worker.bytes, orderedEquals(sync.bytes));
    },
  );
}
