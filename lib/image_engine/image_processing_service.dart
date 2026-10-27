import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Formats detected from source bytes. Only PNG/JPEG/BMP/GIF can be encoded
/// by this service; WebP can be reported as an input format when decodable.
enum DeskImageFormat { png, jpeg, bmp, gif, webp, unknown }

const supportedImageOutputFormats = <DeskImageFormat>[
  DeskImageFormat.png,
  DeskImageFormat.jpeg,
  DeskImageFormat.bmp,
  DeskImageFormat.gif,
];

class ImageMetadata {
  const ImageMetadata({
    required this.width,
    required this.height,
    required this.format,
    required this.byteLength,
  });

  final int width;
  final int height;
  final int byteLength;
  final DeskImageFormat format;

  double get megapixels => width * height / 1000000;
}

class ImageProcessingResult {
  const ImageProcessingResult({
    required this.bytes,
    required this.metadata,
    required this.sourceMetadata,
    required this.warnings,
  });

  final Uint8List bytes;
  final ImageMetadata metadata;
  final ImageMetadata sourceMetadata;
  final List<String> warnings;

  int get bytesSaved => sourceMetadata.byteLength - metadata.byteLength;
}

/// Local image operations. Source bytes are never modified or overwritten.
class ImageProcessingService {
  const ImageProcessingService({
    this.maxInputBytes = 40 * 1024 * 1024,
    this.maxPixels = 40000000,
  });

  final int maxInputBytes;
  final int maxPixels;

  ImageMetadata inspect(Uint8List source) =>
      _meta(_decode(source), source.length, _formatFromBytes(source));

  ImageProcessingResult resize({
    required Uint8List source,
    required int width,
    required int height,
    bool preserveAspectRatio = true,
    DeskImageFormat outputFormat = DeskImageFormat.jpeg,
    int quality = 90,
  }) {
    if (width < 1 || height < 1) {
      throw ArgumentError('Target dimensions must be positive.');
    }
    if (width * height > maxPixels) {
      throw ArgumentError('Requested image exceeds the pixel safety limit.');
    }
    _quality(quality);
    final original = _decode(source);
    final output = img.copyResize(
      original,
      width: width,
      height: height,
      maintainAspect: preserveAspectRatio,
      interpolation: img.Interpolation.linear,
    );
    final warning =
        preserveAspectRatio &&
            original.width * height != original.height * width
        ? <String>[
            'Aspect ratio was preserved; output may not fill the requested box.',
          ]
        : <String>[];
    return _result(source, original, output, outputFormat, quality, warning);
  }

  ImageProcessingResult rotate({
    required Uint8List source,
    required int degrees,
    DeskImageFormat outputFormat = DeskImageFormat.jpeg,
    int quality = 90,
  }) {
    if (![0, 90, 180, 270].contains(degrees)) {
      throw ArgumentError('Rotation must be 0, 90, 180 or 270 degrees.');
    }
    _quality(quality);
    final original = _decode(source);
    return _result(
      source,
      original,
      img.copyRotate(original, angle: degrees),
      outputFormat,
      quality,
      const [],
    );
  }

  ImageProcessingResult crop({
    required Uint8List source,
    required int x,
    required int y,
    required int width,
    required int height,
    DeskImageFormat outputFormat = DeskImageFormat.jpeg,
    int quality = 90,
  }) {
    if (x < 0 || y < 0 || width < 1 || height < 1) {
      throw ArgumentError('Crop coordinates and dimensions are invalid.');
    }
    _quality(quality);
    final original = _decode(source);
    if (x + width > original.width || y + height > original.height) {
      throw ArgumentError('Crop rectangle extends beyond source image.');
    }
    return _result(
      source,
      original,
      img.copyCrop(original, x: x, y: y, width: width, height: height),
      outputFormat,
      quality,
      const [],
    );
  }

  img.Image _decode(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException('Selected image is empty.');
    }
    if (bytes.length > maxInputBytes) {
      throw FormatException(
        'Image exceeds processing byte limit: ${maxInputBytes ~/ (1024 * 1024)} MB.',
      );
    }
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Unsupported or invalid image data.');
    }
    if (decoded.width < 1 ||
        decoded.height < 1 ||
        decoded.width * decoded.height > maxPixels) {
      throw const FormatException(
        'Image dimensions exceed processing safety limit.',
      );
    }
    return decoded;
  }

  void _quality(int value) {
    if (value < 1 || value > 100) {
      throw ArgumentError('Quality must be between 1 and 100.');
    }
  }

  ImageProcessingResult _result(
    Uint8List source,
    img.Image original,
    img.Image output,
    DeskImageFormat format,
    int quality,
    List<String> warnings,
  ) {
    final bytes = switch (format) {
      DeskImageFormat.png => Uint8List.fromList(img.encodePng(output)),
      DeskImageFormat.jpeg => Uint8List.fromList(
        img.encodeJpg(output, quality: quality),
      ),
      DeskImageFormat.bmp => Uint8List.fromList(img.encodeBmp(output)),
      DeskImageFormat.gif => Uint8List.fromList(img.encodeGif(output)),
      DeskImageFormat.webp || DeskImageFormat.unknown =>
        throw ArgumentError('The selected output format is not supported.'),
    };
    final verified = img.decodeImage(bytes);
    if (verified == null ||
        verified.width != output.width ||
        verified.height != output.height) {
      throw StateError('Image output failed validation.');
    }
    return ImageProcessingResult(
      bytes: bytes,
      sourceMetadata: _meta(
        original,
        source.length,
        _formatFromBytes(source),
      ),
      metadata: _meta(verified, bytes.length, format),
      warnings: List.unmodifiable(warnings),
    );
  }

  ImageMetadata _meta(
    img.Image image,
    int length,
    DeskImageFormat format,
  ) => ImageMetadata(
    width: image.width,
    height: image.height,
    byteLength: length,
    format: format,
  );

  DeskImageFormat _formatFromBytes(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0d &&
        bytes[5] == 0x0a &&
        bytes[6] == 0x1a &&
        bytes[7] == 0x0a) {
      return DeskImageFormat.png;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return DeskImageFormat.jpeg;
    }
    if (bytes.length >= 6 &&
        String.fromCharCodes(bytes.sublist(0, 3)) == 'GIF') {
      return DeskImageFormat.gif;
    }
    if (bytes.length >= 2 && bytes[0] == 0x42 && bytes[1] == 0x4d) {
      return DeskImageFormat.bmp;
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return DeskImageFormat.webp;
    }
    return DeskImageFormat.unknown;
  }
}
