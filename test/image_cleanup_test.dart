import 'dart:typed_data';

import 'package:desksuite/images/image_cleanup_pixels.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Uint8List cleanPixels() {
  final pixels = Uint8List(7 * 7 * 4);
  for (var i = 0; i < 49; i++) {
    pixels.setRange(i * 4, i * 4 + 4, [100, 120, 140, 255]);
  }
  return pixels;
}

void main() {
  test('selective median reduces isolated bright and dark specks', () {
    final pixels = cleanPixels();
    final bright = (3 * 7 + 3) * 4;
    final dark = (1 * 7 + 1) * 4;
    pixels.setRange(bright, bright + 3, [255, 255, 255]);
    pixels.setRange(dark, dark + 3, [0, 0, 0]);
    reduceImpulseNoiseRgbaInPlace(pixels, 7, 7);
    expect(pixels.sublist(bright, bright + 4), [100, 120, 140, 255]);
    expect(pixels.sublist(dark, dark + 4), [100, 120, 140, 255]);
  });

  test('borders and neighborhoods with transparency stay unchanged', () {
    final pixels = cleanPixels();
    pixels.setRange(0, 4, [255, 255, 255, 255]);
    final center = (3 * 7 + 3) * 4;
    pixels.setRange(center, center + 4, [0, 0, 0, 255]);
    pixels[center + 4 + 3] = 0;
    final original = Uint8List.fromList(pixels);
    reduceImpulseNoiseRgbaInPlace(pixels, 7, 7);
    expect(pixels.sublist(0, 4), original.sublist(0, 4));
    expect(
      pixels.sublist(center, center + 4),
      original.sublist(center, center + 4),
    );
    expect(pixels[center + 4 + 3], 0);
  });

  test('invalid and oversized buffers fail before modifying pixels', () {
    final bad = Uint8List.fromList([1, 2, 3, 4]);
    expect(
      () => reduceImpulseNoiseRgbaInPlace(bad, 2, 1),
      throwsFormatException,
    );
    expect(
      () => reduceImpulseNoiseRgbaInPlace(bad, 2001, 2000),
      throwsFormatException,
    );
    expect(
      () => reduceImpulseNoiseRgbaInPlace(bad, 8193, 1),
      throwsFormatException,
    );
    expect(bad, [1, 2, 3, 4]);
  });

  test('photo processor refuses speck reduction above four megapixels', () {
    final large = img.Image(width: 2001, height: 2000, numChannels: 3);
    final input = Uint8List.fromList(img.encodePng(large, level: 1));
    final original = Uint8List.fromList(input);
    expect(
      () => processPhoto(PhotoRequest(input, PhotoAction.reduceImpulseNoise)),
      throwsFormatException,
    );
    expect(input, orderedEquals(original));
  });

  test(
    'photo processor returns a real PNG while preserving the source bytes',
    () {
      final pixels = cleanPixels();
      final center = (3 * 7 + 3) * 4;
      pixels.setRange(center, center + 3, [255, 255, 255]);
      final image = img.Image.fromBytes(
        width: 7,
        height: 7,
        bytes: pixels.buffer,
        numChannels: 4,
      );
      final input = Uint8List.fromList(img.encodePng(image));
      final original = Uint8List.fromList(input);
      final result = processPhoto(
        PhotoRequest(input, PhotoAction.reduceImpulseNoise),
      );
      final output = img.decodePng(result.bytes)!;
      final filtered = output.getPixel(3, 3);
      expect(
        [filtered.r, filtered.g, filtered.b, filtered.a],
        [100, 120, 140, 255],
      );
      expect([output.width, output.height], [7, 7]);
      expect(input, orderedEquals(original));
      expect(img.decodePng(input)!.getPixel(3, 3).r, 255);
    },
  );
}
