import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import '../images/photo_processor.dart';
import 'document_cleanup_pixels.dart';

export 'document_cleanup_pixels.dart' show DocumentCleanupMode;

class DocumentCleanupRequest {
  const DocumentCleanupRequest(
    this.bytes, {
    required this.mode,
    this.amount = .7,
  });
  final Uint8List bytes;
  final DocumentCleanupMode mode;
  final double amount;
}

/// Runs decoding, cleanup and PNG encoding on a worker isolate on native.
Future<PhotoResult> processDocumentCleanupInBackground(
  DocumentCleanupRequest request,
) => compute(processDocumentCleanup, request);

/// Produces a new PNG and never changes the encoded input. The converted
/// image owns its own pixels; the pixel engine may safely modify that copy.
PhotoResult processDocumentCleanup(DocumentCleanupRequest request) {
  if (!request.amount.isFinite || request.amount < 0 || request.amount > 1) {
    throw const FormatException('Invalid cleanup setting.');
  }
  final decoded = decodeBoundedPhoto(
    request.bytes,
    byteLimit: maxPhotoWorkingBytes,
  );
  final working = decoded.convert(
    format: img.Format.uint8,
    numChannels: 4,
    noAnimation: true,
  );
  cleanDocumentRgbaInPlace(
    working.toUint8List(),
    working.width,
    working.height,
    mode: request.mode,
    amount: request.amount,
  );
  final png = Uint8List.fromList(img.encodePng(working, level: 3));
  return validateEncodedPhoto(
    png,
    working.width,
    working.height,
    PhotoFormat.png,
  );
}
