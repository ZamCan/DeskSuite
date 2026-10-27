import 'dart:typed_data';
import 'package:desksuite/image_engine/image_processing_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  const service = ImageProcessingService();
  Uint8List sample() { final image = img.Image(width: 120, height: 80); img.fill(image, color: img.ColorRgb8(220, 80, 40)); return Uint8List.fromList(img.encodePng(image)); }
  test('resize returns validated exact dimensions', () {
    final result = service.resize(source: sample(), width: 60, height: 40, preserveAspectRatio: false, outputFormat: DeskImageFormat.png);
    expect(result.metadata.width, 60); expect(result.metadata.height, 40); expect(img.decodeImage(result.bytes), isNotNull);
  });
  test('resize preserves aspect ratio and warns when box differs', () {
    final result = service.resize(source: sample(), width: 60, height: 60, outputFormat: DeskImageFormat.png);
    expect(result.metadata.width, 60); expect(result.metadata.height, 40); expect(result.warnings, isNotEmpty);
  });
  test('crop bounds are validated', () {
    expect(() => service.crop(source: sample(), x: 100, y: 0, width: 30, height: 20), throwsArgumentError);
  });
  test('crop and rotation output dimensions are correct', () {
    final crop = service.crop(source: sample(), x: 10, y: 5, width: 50, height: 30, outputFormat: DeskImageFormat.png);
    expect(crop.metadata.width, 50); expect(crop.metadata.height, 30);
    final rotated = service.rotate(source: sample(), degrees: 90, outputFormat: DeskImageFormat.png);
    expect(rotated.metadata.width, 80); expect(rotated.metadata.height, 120);
  });
  test('malformed input and excessive output are rejected', () {
    expect(() => service.inspect(Uint8List.fromList([1, 2, 3])), throwsFormatException);
    expect(() => service.resize(source: sample(), width: 100000, height: 100000), throwsArgumentError);
  });
}