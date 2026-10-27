import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../images/photo_processor.dart';

/// Recognition is more accurate on a bounded image and cannot exhaust memory on
/// a modest phone. 2600 px on the long edge keeps ordinary A4 text legible
/// while staying well inside the native decoder's budget.
const int ocrMaxDimension = 2600;

class OcrImageRequest {
  const OcrImageRequest(this.bytes, {this.maxDimension = ocrMaxDimension});
  final Uint8List bytes;
  final int maxDimension;
}

/// Normalizes a photo for recognition: verifies the real format, applies the
/// EXIF orientation a camera may have written, and downsamples oversized
/// images. Returns PNG bytes and the exact size the engine will see, so OCR
/// word boxes and the searchable PDF layer stay aligned.
Future<Uint8List> prepareImageForOcrInBackground(OcrImageRequest request) =>
    compute(prepareImageForOcr, request);

Uint8List prepareImageForOcr(OcrImageRequest request) {
  if (!request.maxDimension.isFinite || request.maxDimension < 320) {
    throw const FormatException('Invalid OCR image budget.');
  }
  final decoded = decodeBoundedPhoto(
    request.bytes,
    byteLimit: maxPhotoInputBytes,
  );
  var image = decoded;
  final longEdge = math.max(image.width, image.height);
  if (longEdge > request.maxDimension) {
    final scale = request.maxDimension / longEdge;
    image = img.copyResize(
      image,
      width: math.max(1, (image.width * scale).round()),
      height: math.max(1, (image.height * scale).round()),
      interpolation: img.Interpolation.cubic,
    );
  }
  if (image.width < 16 || image.height < 16) {
    throw const FormatException('The image is too small to recognize text.');
  }
  return Uint8List.fromList(img.encodePng(image, level: 6));
}
