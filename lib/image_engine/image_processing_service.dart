import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum DeskImageFormat { png, jpeg, bmp, gif }

class ImageMetadata {
  const ImageMetadata({required this.width, required this.height, required this.format, required this.byteLength});
  final int width, height, byteLength;
  final DeskImageFormat format;
  double get megapixels => width * height / 1000000;
}

class ImageProcessingResult {
  const ImageProcessingResult({required this.bytes, required this.metadata, required this.sourceMetadata, required this.warnings});
  final Uint8List bytes;
  final ImageMetadata metadata, sourceMetadata;
  final List<String> warnings;
  int get bytesSaved => sourceMetadata.byteLength - metadata.byteLength;
}

/// Local image operations. Source bytes are never modified or overwritten.
class ImageProcessingService {
  const ImageProcessingService({this.maxInputBytes = 40 * 1024 * 1024, this.maxPixels = 40000000});
  final int maxInputBytes, maxPixels;

  ImageMetadata inspect(Uint8List source) => _meta(_decode(source), source.length);

  ImageProcessingResult resize({required Uint8List source, required int width, required int height, bool preserveAspectRatio = true, DeskImageFormat outputFormat = DeskImageFormat.jpeg, int quality = 90}) {
    if (width < 1 || height < 1) throw ArgumentError('Target dimensions must be positive.');
    if (width * height > maxPixels) throw ArgumentError('Requested image exceeds the pixel safety limit.');
    _quality(quality);
    final original = _decode(source);
    final output = img.copyResize(original, width: width, height: height, maintainAspect: preserveAspectRatio, interpolation: img.Interpolation.linear);
    final warning = preserveAspectRatio && original.width * height != original.height * width
        ? <String>['Aspect ratio was preserved; output may not fill the requested box.'] : <String>[];
    return _result(source, original, output, outputFormat, quality, warning);
  }

  ImageProcessingResult rotate({required Uint8List source, required int degrees, DeskImageFormat outputFormat = DeskImageFormat.jpeg, int quality = 90}) {
    if (![0, 90, 180, 270].contains(degrees)) throw ArgumentError('Rotation must be 0, 90, 180 or 270 degrees.');
    _quality(quality); final original = _decode(source);
    return _result(source, original, img.copyRotate(original, angle: degrees), outputFormat, quality, const []);
  }

  ImageProcessingResult crop({required Uint8List source, required int x, required int y, required int width, required int height, DeskImageFormat outputFormat = DeskImageFormat.jpeg, int quality = 90}) {
    if (x < 0 || y < 0 || width < 1 || height < 1) throw ArgumentError('Crop coordinates and dimensions are invalid.');
    _quality(quality); final original = _decode(source);
    if (x + width > original.width || y + height > original.height) throw ArgumentError('Crop rectangle extends beyond source image.');
    return _result(source, original, img.copyCrop(original, x: x, y: y, width: width, height: height), outputFormat, quality, const []);
  }

  img.Image _decode(Uint8List bytes) {
    if (bytes.isEmpty) throw const FormatException('Selected image is empty.');
    if (bytes.length > maxInputBytes) throw FormatException('Image exceeds processing byte limit: ' + (maxInputBytes ~/ (1024 * 1024)).toString() + ' MB.');
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('Unsupported or invalid image data.');
    if (decoded.width < 1 || decoded.height < 1 || decoded.width * decoded.height > maxPixels) throw const FormatException('Image dimensions exceed processing safety limit.');
    return decoded;
  }
  void _quality(int value) { if (value < 1 || value > 100) throw ArgumentError('Quality must be between 1 and 100.'); }

  ImageProcessingResult _result(Uint8List source, img.Image original, img.Image output, DeskImageFormat format, int quality, List<String> warnings) {
    final Uint8List bytes;
    switch (format) {
      case DeskImageFormat.png: bytes = Uint8List.fromList(img.encodePng(output));
      case DeskImageFormat.jpeg: bytes = Uint8List.fromList(img.encodeJpg(output, quality: quality));
      case DeskImageFormat.bmp: bytes = Uint8List.fromList(img.encodeBmp(output));
      case DeskImageFormat.gif: bytes = Uint8List.fromList(img.encodeGif(output));
    }
    final verified = img.decodeImage(bytes);
    if (verified == null || verified.width != output.width || verified.height != output.height) throw StateError('Image output failed validation.');
    return ImageProcessingResult(bytes: bytes, sourceMetadata: _meta(original, source.length), metadata: _meta(verified, bytes.length, format), warnings: List.unmodifiable(warnings));
  }
  ImageMetadata _meta(img.Image image, int length, [DeskImageFormat? forced]) => ImageMetadata(width: image.width, height: image.height, byteLength: length, format: forced ?? _format(image));
  DeskImageFormat _format(img.Image image) {
    switch (image.format) {
      case img.Format.png: return DeskImageFormat.png;
      case img.Format.jpeg: return DeskImageFormat.jpeg;
      case img.Format.bmp: return DeskImageFormat.bmp;
      case img.Format.gif: return DeskImageFormat.gif;
      default: return DeskImageFormat.png;
    }
  }
}