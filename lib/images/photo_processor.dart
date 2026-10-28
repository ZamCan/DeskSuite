import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'image_cleanup_pixels.dart';

const int maxPhotoInputBytes = 8 * 1024 * 1024;
const int maxPhotoWorkingBytes = 16 * 1024 * 1024;
const int maxPhotoPixels = 12000000;
const int maxPhotoSide = 8192;

enum PhotoAction {
  inspect,
  rotate90,
  flipHorizontal,
  resize,
  centerSquareCrop,
  reduceImpulseNoise,
  flattenBackground,
  png,
  jpeg,
}

class PhotoRequest {
  const PhotoRequest(
    this.bytes,
    this.action, {
    this.width,
    this.height,
    this.keepAspect = true,
    this.quality = 90,
    this.backgroundColor = 0xFFFFFFFF,
  });
  final Uint8List bytes;
  final PhotoAction action;
  final int? width;
  final int? height;
  final bool keepAspect;
  final int quality;

  /// Opaque ARGB colour used by [PhotoAction.flattenBackground].
  final int backgroundColor;
}

class PhotoResult {
  const PhotoResult(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

Future<PhotoResult> processPhotoInBackground(PhotoRequest request) =>
    compute(processPhoto, request);

enum PhotoFormat { png, jpeg, webp }

/// Identifies only formats DeskSuite actually supports, independently of the
/// filename. Decoding below still verifies the complete image.
PhotoFormat detectPhotoFormat(Uint8List bytes) {
  const png = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length >= png.length &&
      Iterable<int>.generate(png.length).every((i) => bytes[i] == png[i])) {
    return PhotoFormat.png;
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return PhotoFormat.jpeg;
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return PhotoFormat.webp;
  }
  throw const FormatException('Choose a supported PNG, JPEG or WebP image.');
}

/// Sniff the format and check the first-frame header before allocating pixels.
/// The returned image has camera/EXIF orientation applied. Call from an
/// isolate for user files; it can require substantial CPU and memory.
img.Image decodeBoundedPhoto(Uint8List bytes, {required int byteLimit}) {
  if (bytes.isEmpty || bytes.length > byteLimit) {
    throw const FormatException('Image is empty or exceeds the size limit.');
  }
  detectPhotoFormat(bytes);
  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (decoder == null || info == null) {
    throw const FormatException('Unsupported or damaged image.');
  }
  if (info.width < 1 ||
      info.height < 1 ||
      info.width > maxPhotoSide ||
      info.height > maxPhotoSide ||
      info.width * info.height > maxPhotoPixels) {
    throw const FormatException(
      'Image exceeds the 12-megapixel or 8192-pixel-side limit.',
    );
  }
  final frame = decoder.decodeFrame(0);
  if (frame == null) throw const FormatException('Image could not be decoded.');
  return img.bakeOrientation(frame);
}

/// Returns a new RGB raster on white before JPEG encoding. This also preserves
/// the previous JPEG path's behavior for opaque or indexed input images.
img.Image photoOnWhite(img.Image source) {
  final white = img.Image(
    width: source.width,
    height: source.height,
    numChannels: 3,
  );
  img.fill(white, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(white, source);
  return white;
}

/// Checks the encoded format and dimensions before any output is handed to
/// the save picker. Full independent decoding is also covered by tests.
PhotoResult validateEncodedPhoto(
  Uint8List bytes,
  int width,
  int height,
  PhotoFormat expected,
) {
  if (bytes.isEmpty ||
      bytes.length > maxPhotoWorkingBytes ||
      detectPhotoFormat(bytes) != expected) {
    throw const FormatException(
      'The encoded image is invalid or exceeds the working limit.',
    );
  }
  final info = img.findDecoderForData(bytes)?.startDecode(bytes);
  if (info == null || info.width != width || info.height != height) {
    throw const FormatException(
      'The encoded image dimensions could not be verified.',
    );
  }
  return PhotoResult(bytes, width, height);
}

/// Decode only the first frame and work off the UI isolate via
/// [processPhotoInBackground].
PhotoResult processPhoto(PhotoRequest request) {
  final inputLimit = request.action == PhotoAction.inspect
      ? maxPhotoInputBytes
      : maxPhotoWorkingBytes;
  var image = decodeBoundedPhoto(request.bytes, byteLimit: inputLimit);
  if (request.action == PhotoAction.inspect) {
    return PhotoResult(request.bytes, image.width, image.height);
  }
  switch (request.action) {
    case PhotoAction.rotate90:
      image = img.copyRotate(image, angle: 90);
    case PhotoAction.flipHorizontal:
      image = img.flipHorizontal(image);
    case PhotoAction.centerSquareCrop:
      final size = math.min(image.width, image.height);
      image = img.copyCrop(
        image,
        x: (image.width - size) ~/ 2,
        y: (image.height - size) ~/ 2,
        width: size,
        height: size,
      );
    case PhotoAction.reduceImpulseNoise:
      if (image.width * image.height > maxNoiseReductionPixels) {
        throw const FormatException(
          'Noise reduction supports images up to 4 megapixels. Resize a working copy first.',
        );
      }
      image = image.convert(
        format: img.Format.uint8,
        numChannels: 4,
        noAnimation: true,
      );
      reduceImpulseNoiseRgbaInPlace(
        image.toUint8List(),
        image.width,
        image.height,
      );
    case PhotoAction.resize:
      final requestedWidth = request.width;
      final requestedHeight = request.height;
      if (requestedWidth == null ||
          requestedHeight == null ||
          requestedWidth < 1 ||
          requestedHeight < 1 ||
          requestedWidth > maxPhotoSide ||
          requestedHeight > maxPhotoSide) {
        throw const FormatException(
          'Enter image dimensions from 1 to 8192 pixels.',
        );
      }
      var width = requestedWidth;
      var height = requestedHeight;
      if (request.keepAspect) {
        final scale = math.min(
          requestedWidth / image.width,
          requestedHeight / image.height,
        );
        width = math.max(1, (image.width * scale).round());
        height = math.max(1, (image.height * scale).round());
      }
      if (width * height > maxPhotoPixels) {
        throw const FormatException('Output exceeds 12 megapixels.');
      }
      image = img.copyResize(
        image,
        width: width,
        height: height,
        interpolation: img.Interpolation.linear,
      );
    case PhotoAction.flattenBackground:
      final color = request.backgroundColor;
      if (color < 0 || color > 0xFFFFFFFF || ((color >> 24) & 0xff) != 0xff) {
        throw const FormatException('Choose an opaque background colour.');
      }
      final background = img.Image(
        width: image.width,
        height: image.height,
        numChannels: 3,
      );
      img.fill(
        background,
        color: img.ColorRgb8(
          (color >> 16) & 0xff,
          (color >> 8) & 0xff,
          color & 0xff,
        ),
      );
      img.compositeImage(background, image);
      return validateEncodedPhoto(
        Uint8List.fromList(img.encodePng(background, level: 3)),
        background.width,
        background.height,
        PhotoFormat.png,
      );
    case PhotoAction.png:
      break;
    case PhotoAction.jpeg:
      if (request.quality < 1 || request.quality > 100) {
        throw const FormatException('JPEG quality must be 1–100.');
      }
      // JPEG cannot store transparency; flatten against white deliberately.
      final white = photoOnWhite(image);
      return validateEncodedPhoto(
        Uint8List.fromList(img.encodeJpg(white, quality: request.quality)),
        image.width,
        image.height,
        PhotoFormat.jpeg,
      );
    case PhotoAction.inspect:
      throw StateError('Already handled.');
  }
  final output = Uint8List.fromList(img.encodePng(image, level: 3));
  return validateEncodedPhoto(
    output,
    image.width,
    image.height,
    PhotoFormat.png,
  );
}
