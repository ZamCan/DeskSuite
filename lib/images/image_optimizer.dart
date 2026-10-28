import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;

import 'package:image/image.dart' as img;

import 'compression_dimensions.dart';
import 'photo_processor.dart';

enum ImageSizePreset {
  original,
  px120x150,
  px300x300,
  px300x400,
  px600x600,
  px600x800,
  px1200x1500,
  custom,
}

enum ImageCompressionMode { quality, reduceByPercent, targetBytes }

class ImageSizeTarget {
  const ImageSizeTarget({
    required this.preset,
    this.width,
    this.height,
    this.keepAspect = true,
  });
  final ImageSizePreset preset;
  final int? width;
  final int? height;
  final bool keepAspect;

  ({int width, int height}) resolve(int sourceWidth, int sourceHeight) {
    if (sourceWidth < 1 ||
        sourceHeight < 1 ||
        sourceWidth > maxPhotoSide ||
        sourceHeight > maxPhotoSide ||
        sourceWidth * sourceHeight > maxPhotoPixels) {
      throw const FormatException('Invalid or oversized source dimensions.');
    }
    final size = switch (preset) {
      ImageSizePreset.original => null,
      ImageSizePreset.px120x150 => (width: 120, height: 150),
      ImageSizePreset.px300x300 => (width: 300, height: 300),
      ImageSizePreset.px300x400 => (width: 300, height: 400),
      ImageSizePreset.px600x600 => (width: 600, height: 600),
      ImageSizePreset.px600x800 => (width: 600, height: 800),
      ImageSizePreset.px1200x1500 => (width: 1200, height: 1500),
      ImageSizePreset.custom => (width: width ?? 0, height: height ?? 0),
    };
    if (size == null) return (width: sourceWidth, height: sourceHeight);
    if (size.width < 1 ||
        size.height < 1 ||
        size.width > maxPhotoSide ||
        size.height > maxPhotoSide) {
      throw const FormatException('Choose pixel dimensions from 1 to 8192.');
    }
    if (size.width * size.height > maxPhotoPixels) {
      throw const FormatException('Output dimensions exceed 12 megapixels.');
    }
    if (!keepAspect) return size;
    final scale = math.min(
      size.width / sourceWidth,
      size.height / sourceHeight,
    );
    return (
      width: math.max(1, (sourceWidth * scale).round()),
      height: math.max(1, (sourceHeight * scale).round()),
    );
  }
}

class ImageOptimizationRequest {
  const ImageOptimizationRequest({
    required this.bytes,
    this.sizeTarget = const ImageSizeTarget(preset: ImageSizePreset.original),
    this.mode = ImageCompressionMode.quality,
    this.quality = 88,
    this.reductionPercent = 30,
    this.targetBytes = 200 * 1024,
  });
  final Uint8List bytes;
  final ImageSizeTarget sizeTarget;
  final ImageCompressionMode mode;
  final int quality;
  final int reductionPercent;
  final int targetBytes;
}

class ImageOptimizationResult {
  const ImageOptimizationResult({
    required this.bytes,
    required this.width,
    required this.height,
    required this.quality,
    required this.originalBytes,
  });
  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;
  final int originalBytes;
  int get savedBytes => originalBytes - bytes.length;
  double get reductionPercent =>
      originalBytes == 0 ? 0 : savedBytes * 100 / originalBytes;
}

/// Offline JPEG optimisation. The source bytes are never mutated. When a byte
/// target is requested, quality is reduced first; only then is resolution
/// reduced gradually, avoiding unnecessary blur when quality alone is enough.
Future<ImageOptimizationResult> optimizeImageInBackground(
  ImageOptimizationRequest request,
) => compute(optimizeImage, request);

ImageOptimizationResult optimizeImage(ImageOptimizationRequest request) {
  // External picks are limited to 8 MiB by the gateway. The current edited
  // working image may be a larger PNG, but is bounded separately to 16 MiB.
  if (request.bytes.isEmpty || request.bytes.length > maxPhotoWorkingBytes) {
    throw const FormatException(
      'Choose a non-empty working image up to 16 MiB.',
    );
  }
  if (request.quality < 30 || request.quality > 100) {
    throw const FormatException('Choose JPEG quality from 30 to 100.');
  }
  if (request.reductionPercent < 1 || request.reductionPercent > 95) {
    throw const FormatException('Choose a reduction percentage from 1 to 95.');
  }
  if (request.targetBytes < 1024 || request.targetBytes > 20 * 1024 * 1024) {
    throw const FormatException(
      'Target file size must be between 1 KB and 20 MB.',
    );
  }
  final decoded = decodeBoundedPhoto(
    request.bytes,
    byteLimit: maxPhotoWorkingBytes,
  );
  final target = request.sizeTarget.resolve(decoded.width, decoded.height);
  // Flatten before resizing to avoid exposing hidden transparent RGB values or
  // introducing dark fringes. JPEG and its PDF/HTML wrappers cannot store alpha.
  final opaque = photoOnWhite(decoded);
  var working = target.width == opaque.width && target.height == opaque.height
      ? opaque
      : img.copyResize(
          opaque,
          width: target.width,
          height: target.height,
          interpolation: img.Interpolation.cubic,
        );
  final targetBytes = switch (request.mode) {
    ImageCompressionMode.quality => null,
    ImageCompressionMode.reduceByPercent => math.max(
      1,
      (request.bytes.length * (100 - request.reductionPercent) / 100).floor(),
    ),
    ImageCompressionMode.targetBytes => request.targetBytes,
  };
  var quality = request.quality;
  Uint8List encode() =>
      Uint8List.fromList(img.encodeJpg(working, quality: quality));
  var output = encode();
  if (targetBytes != null && output.length > targetBytes) {
    while (quality > 30 && output.length > targetBytes) {
      quality = math.max(30, quality - 5);
      output = encode();
    }
    var passes = 0;
    while (output.length > targetBytes &&
        passes < maxCompressionResizePasses &&
        (working.width > minimumCompressionLongSide ||
            working.height > minimumCompressionLongSide)) {
      passes++;
      final next = compressionDimensionsAtPass(
        width: target.width,
        height: target.height,
        pass: passes,
      );
      // Always sample from the same source rather than repeatedly resampling
      // each compressed candidate, which accumulates blur.
      working = img.copyResize(
        opaque,
        width: next.width,
        height: next.height,
        interpolation: img.Interpolation.cubic,
      );
      output = encode();
    }
    if (output.length > targetBytes) {
      throw const FormatException(
        'This image cannot meet that file-size target within the safe quality and resolution limits. Try a larger target size.',
      );
    }
  }
  final result = validateEncodedPhoto(
    output,
    working.width,
    working.height,
    PhotoFormat.jpeg,
  );
  return ImageOptimizationResult(
    bytes: result.bytes,
    width: result.width,
    height: result.height,
    quality: quality,
    originalBytes: request.bytes.length,
  );
}
