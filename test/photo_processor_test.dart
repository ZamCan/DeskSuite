import 'dart:typed_data';

import 'package:desksuite/images/photo_processor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  Uint8List source() {
    final image = img.Image(width: 4, height: 2, numChannels: 4);
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 4; x++) {
        image.setPixelRgba(x, y, x < 2 ? 255 : 0, 0, x >= 2 ? 255 : 0, 255);
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  test(
    'inspect, rotate, flip, crop and aspect-preserving resize pixels locally',
    () {
      final initial = processPhoto(PhotoRequest(source(), PhotoAction.inspect));
      expect([initial.width, initial.height], [4, 2]);
      final rotated = processPhoto(
        PhotoRequest(initial.bytes, PhotoAction.rotate90),
      );
      expect([rotated.width, rotated.height], [2, 4]);
      final flipped = processPhoto(
        PhotoRequest(initial.bytes, PhotoAction.flipHorizontal),
      );
      final flippedImage = img.decodePng(flipped.bytes)!;
      expect(flippedImage.getPixel(0, 0).b, 255);
      expect(flippedImage.getPixel(3, 0).r, 255);
      final crop = processPhoto(
        PhotoRequest(initial.bytes, PhotoAction.centerSquareCrop),
      );
      expect([crop.width, crop.height], [2, 2]);
      final resized = processPhoto(
        PhotoRequest(initial.bytes, PhotoAction.resize, width: 2, height: 2),
      );
      expect([resized.width, resized.height], [2, 1]);
      final stretched = processPhoto(
        PhotoRequest(
          initial.bytes,
          PhotoAction.resize,
          width: 2,
          height: 2,
          keepAspect: false,
        ),
      );
      expect([stretched.width, stretched.height], [2, 2]);
    },
  );

  test(
    'resize resampling changes pixel interpolation without changing the source',
    () {
      final image = img.Image(width: 2, height: 2, numChannels: 4);
      image.setPixelRgba(0, 0, 0, 0, 0, 255);
      image.setPixelRgba(1, 0, 255, 255, 255, 255);
      image.setPixelRgba(0, 1, 255, 255, 255, 255);
      image.setPixelRgba(1, 1, 0, 0, 0, 255);
      final input = Uint8List.fromList(img.encodePng(image));
      final before = Uint8List.fromList(input);
      PhotoResult resize(PhotoResampling method) => processPhoto(
        PhotoRequest(
          input,
          PhotoAction.resize,
          width: 5,
          height: 5,
          keepAspect: false,
          resampling: method,
        ),
      );
      final nearest = img.decodePng(resize(PhotoResampling.nearest).bytes)!;
      final linear = img.decodePng(resize(PhotoResampling.linear).bytes)!;
      final cubic = img.decodePng(resize(PhotoResampling.cubic).bytes)!;
      expect(nearest.getPixel(1, 1).r, 0);
      expect(linear.getPixel(1, 1).r, greaterThan(0));
      expect(linear.getPixel(1, 1).r, lessThan(255));
      expect([cubic.width, cubic.height], [5, 5]);
      expect(input, orderedEquals(before));
    },
  );

  test('linear resize expands a palette instead of forcing nearest pixels', () {
    final image = img.Image(
      width: 2,
      height: 2,
      numChannels: 3,
      withPalette: true,
    );
    image.palette!.setRgb(0, 0, 0, 0);
    image.palette!.setRgb(1, 255, 255, 255);
    image.setPixelIndex(0, 0, 0);
    image.setPixelIndex(1, 0, 1);
    image.setPixelIndex(0, 1, 1);
    image.setPixelIndex(1, 1, 0);
    final bytes = Uint8List.fromList(img.encodePng(image));
    final resized = processPhoto(
      PhotoRequest(
        bytes,
        PhotoAction.resize,
        width: 5,
        height: 5,
        keepAspect: false,
        resampling: PhotoResampling.linear,
      ),
    );
    final pixel = img.decodePng(resized.bytes)!.getPixel(1, 1).r;
    expect(pixel, greaterThan(0));
    expect(pixel, lessThan(255));
  });

  test('converts to real PNG/JPEG, flattening transparency on white', () {
    final transparent = img.Image(width: 3, height: 2, numChannels: 4);
    img.fill(transparent, color: img.ColorRgba8(0, 0, 0, 0));
    final sourceBytes = Uint8List.fromList(img.encodePng(transparent));
    final jpg = processPhoto(
      PhotoRequest(sourceBytes, PhotoAction.jpeg, quality: 90),
    );
    expect(jpg.bytes.take(2), [0xff, 0xd8]);
    final decoded = img.decodeJpg(jpg.bytes)!;
    expect([decoded.width, decoded.height], [3, 2]);
    expect(decoded.getPixel(0, 0).r, greaterThan(240));
    final png = processPhoto(PhotoRequest(jpg.bytes, PhotoAction.png));
    expect(png.bytes.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    expect(img.decodePng(png.bytes), isNotNull);
  });

  test('places a transparent image on the selected solid background', () {
    final transparent = img.Image(width: 2, height: 1, numChannels: 4);
    transparent.setPixelRgba(0, 0, 255, 0, 0, 0);
    transparent.setPixelRgba(1, 0, 255, 0, 0, 255);
    final bytes = Uint8List.fromList(img.encodePng(transparent));

    final result = processPhoto(
      PhotoRequest(
        bytes,
        PhotoAction.flattenBackground,
        backgroundColor: 0xFFDCEBFA,
      ),
    );
    final decoded = img.decodePng(result.bytes)!;
    expect([result.width, result.height], [2, 1]);
    expect(decoded.numChannels, 3);
    expect(decoded.getPixel(0, 0).r, closeTo(220, 1));
    expect(decoded.getPixel(0, 0).g, closeTo(235, 1));
    expect(decoded.getPixel(0, 0).b, closeTo(250, 1));
    expect(decoded.getPixel(1, 0).r, 255);
    expect(decoded.getPixel(1, 0).g, 0);
    expect(decoded.getPixel(1, 0).b, 0);
  });

  test('rejects translucent background colours', () {
    expect(
      () => processPhoto(
        PhotoRequest(
          source(),
          PhotoAction.flattenBackground,
          backgroundColor: 0x80FFFFFF,
        ),
      ),
      throwsFormatException,
    );
  });

  test('rejects damaged data, invalid output and excessive input before processing', () {
    expect(
      () => processPhoto(
        PhotoRequest(Uint8List.fromList([1, 2, 3]), PhotoAction.inspect),
      ),
      throwsFormatException,
    );
    expect(
      () => processPhoto(
        PhotoRequest(Uint8List(maxPhotoInputBytes + 1), PhotoAction.inspect),
      ),
      throwsFormatException,
    );
    expect(
      () => processPhoto(
        PhotoRequest(
          source(),
          PhotoAction.resize,
          width: 8192,
          height: 8192,
          keepAspect: false,
        ),
      ),
      throwsFormatException,
    );
    expect(
      () =>
          processPhoto(PhotoRequest(source(), PhotoAction.jpeg, quality: 101)),
      throwsFormatException,
    );
  });
}
