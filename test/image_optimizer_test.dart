import 'dart:typed_data';

import 'package:desksuite/images/image_optimizer.dart';
import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List sample() =>
      Uint8List.fromList(img.encodePng(img.Image(width: 320, height: 400)));

  test('presets resolve pixel sizes and keep proportions by default', () {
    const target = ImageSizeTarget(preset: ImageSizePreset.px120x150);
    expect(target.resolve(320, 400), (width: 120, height: 150));
    const square = ImageSizeTarget(preset: ImageSizePreset.px300x300);
    expect(square.resolve(320, 400), (width: 240, height: 300));
    const forced = ImageSizeTarget(
      preset: ImageSizePreset.px300x300,
      keepAspect: false,
    );
    expect(forced.resolve(320, 400), (width: 300, height: 300));
  });

  test('custom dimensions are validated', () {
    const invalid = ImageSizeTarget(
      preset: ImageSizePreset.custom,
      width: 0,
      height: 120,
    );
    expect(() => invalid.resolve(320, 400), throwsFormatException);
  });

  test('invalid source dimensions are rejected before aspect calculation', () {
    const target = ImageSizeTarget(preset: ImageSizePreset.px120x150);
    expect(() => target.resolve(0, 400), throwsFormatException);
    expect(() => target.resolve(12000, 400), throwsFormatException);
  });

  test('transparent pixels are composited onto white for JPEG', () {
    final image = img.Image(width: 32, height: 32, numChannels: 4);
    img.fill(image, color: img.ColorRgba8(255, 0, 0, 0));
    final input = Uint8List.fromList(img.encodePng(image));
    final before = Uint8List.fromList(input);
    final output = optimizeImage(
      ImageOptimizationRequest(bytes: input, quality: 100),
    );
    final pixel = img.decodeJpg(output.bytes)!.getPixel(16, 16);
    expect(pixel.r, greaterThan(245));
    expect(pixel.g, greaterThan(245));
    expect(pixel.b, greaterThan(245));
    expect(input, orderedEquals(before));
  });

  test('accepts a bounded working PNG larger than an external pick', () {
    final image = img.Image(width: 1450, height: 1450, numChannels: 4);
    final input = Uint8List.fromList(img.encodePng(image, level: 0));
    expect(input.length, greaterThan(maxPhotoInputBytes));
    expect(input.length, lessThan(maxPhotoWorkingBytes));
    final result = optimizeImage(ImageOptimizationRequest(bytes: input));
    expect([result.width, result.height], [1450, 1450]);
    expect(img.decodeJpg(result.bytes), isNotNull);
  });

  test('optimisation returns a decodable JPEG without mutating source', () {
    final bytes = sample();
    final source = Uint8List.fromList(bytes);
    final result = optimizeImage(
      ImageOptimizationRequest(
        bytes: bytes,
        sizeTarget: const ImageSizeTarget(preset: ImageSizePreset.px120x150),
        mode: ImageCompressionMode.quality,
        quality: 90,
      ),
    );
    expect(result.width, 120);
    expect(result.height, 150);
    expect(result.bytes[0], 0xff);
    expect(result.bytes[1], 0xd8);
    expect(bytes, source);
  });

  test('percentage target is validated', () {
    expect(
      () => optimizeImage(
        ImageOptimizationRequest(bytes: sample(), reductionPercent: 0),
      ),
      throwsFormatException,
    );
  });
}
