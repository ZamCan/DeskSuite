import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

enum ImageOutputFormat { png, jpeg }

class ImageDimensions {
  const ImageDimensions(this.width, this.height);
  final int width;
  final int height;
}

class ProcessedImage {
  const ProcessedImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.format,
  });
  final Uint8List bytes;
  final int width;
  final int height;
  final ImageOutputFormat format;
}

class ImageProcessingService {
  static const int maxInputPixels = 20000000;
  static const int maxOutputPixels = 16000000;
  static const int maxOutputSide = 8192;

  ImageDimensions inspect(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('The image is empty.');
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('This image format is not supported or the file is damaged.');
    }
    if (decoded.width * decoded.height > maxInputPixels) {
      throw const FormatException('The image exceeds the 20-megapixel processing limit.');
    }
    return ImageDimensions(decoded.width, decoded.height);
  }

  ProcessedImage resizeAndEncode({
    required Uint8List sourceBytes,
    required int targetWidth,
    required int targetHeight,
    required bool preserveAspectRatio,
    required ImageOutputFormat format,
    int jpegQuality = 85,
  }) {
    if (targetWidth < 1 ||
        targetHeight < 1 ||
        targetWidth > maxOutputSide ||
        targetHeight > maxOutputSide) {
      throw const FormatException('Width and height must be between 1 and 8192 pixels.');
    }
    if (targetWidth * targetHeight > maxOutputPixels) {
      throw const FormatException('The output would exceed 16 megapixels. Choose smaller dimensions.');
    }
    if (jpegQuality < 20 || jpegQuality > 100) {
      throw const FormatException('JPEG quality must be between 20 and 100.');
    }

    final source = img.decodeImage(sourceBytes);
    if (source == null) {
      throw const FormatException('This image format is not supported or the file is damaged.');
    }
    if (source.width * source.height > maxInputPixels) {
      throw const FormatException('The image exceeds the 20-megapixel processing limit.');
    }

    var width = targetWidth;
    var height = targetHeight;
    if (preserveAspectRatio) {
      final scale = math.min(
        targetWidth / source.width,
        targetHeight / source.height,
      );
      width = math.max(1, (source.width * scale).round()).toInt();
      height = math.max(1, (source.height * scale).round()).toInt();
    }

    final resized = img.copyResize(
      source,
      width: width,
      height: height,
      interpolation: img.Interpolation.average,
    );
    final Uint8List output;
    switch (format) {
      case ImageOutputFormat.png:
        output = Uint8List.fromList(img.encodePng(resized, level: 6));
        break;
      case ImageOutputFormat.jpeg:
        final opaque = img.Image(
          width: resized.width,
          height: resized.height,
          numChannels: 3,
        );
        img.fill(opaque, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(opaque, resized);
        output = Uint8List.fromList(
          img.encodeJpg(opaque, quality: jpegQuality),
        );
        break;
    }

    if (output.isEmpty) {
      throw StateError('The image encoder returned an empty file.');
    }
    return ProcessedImage(
      bytes: output,
      width: width,
      height: height,
      format: format,
    );
  }
}
