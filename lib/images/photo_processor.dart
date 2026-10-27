import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

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
  });
  final Uint8List bytes;
  final PhotoAction action;
  final int? width;
  final int? height;
  final bool keepAspect;
  final int quality;
}

class PhotoResult {
  const PhotoResult(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

Future<PhotoResult> processPhotoInBackground(PhotoRequest request) =>
    compute(processPhoto, request);

/// Decode only the first frame, check its header before allocating pixels, and
/// perform operations off the UI isolate via [processPhotoInBackground].
PhotoResult processPhoto(PhotoRequest request) {
  final inputLimit = request.action == PhotoAction.inspect
      ? maxPhotoInputBytes
      : maxPhotoWorkingBytes;
  if (request.bytes.isEmpty || request.bytes.length > inputLimit) {
    throw const FormatException('Image is empty or exceeds the size limit.');
  }
  final decoder = img.findDecoderForData(request.bytes);
  final info = decoder?.startDecode(request.bytes);
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
  var image = img.bakeOrientation(frame);
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
    case PhotoAction.png:
      break;
    case PhotoAction.jpeg:
      if (request.quality < 1 || request.quality > 100) {
        throw const FormatException('JPEG quality must be 1–100.');
      }
      // JPEG cannot store transparency; flatten against white deliberately.
      final white = img.Image(
        width: image.width,
        height: image.height,
        numChannels: 3,
      );
      img.fill(white, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(white, image);
      return PhotoResult(
        Uint8List.fromList(img.encodeJpg(white, quality: request.quality)),
        image.width,
        image.height,
      );
    case PhotoAction.inspect:
      throw StateError('Already handled.');
  }
  final output = Uint8List.fromList(img.encodePng(image, level: 3));
  if (output.length > maxPhotoWorkingBytes) {
    throw const FormatException(
      'Processed image exceeds the 16 MB working limit.',
    );
  }
  return PhotoResult(output, image.width, image.height);
}
